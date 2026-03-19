#!/usr/bin/env python3
import argparse
import json
import re
from pathlib import Path

HEADER_RE = re.compile(r'^--- !u!(?P<class_id>\d+) &(?P<object_id>\d+)$')
KEY_VALUE_RE = re.compile(r'^(?P<indent>\s*)(?P<key>[A-Za-z0-9_]+):\s*(?P<value>.*)$')
GUID_RE = re.compile(r'guid:\s*([0-9a-f]{32})')

CLASS_NAMES = {
    1: 'GameObject',
    4: 'Transform',
    23: 'MeshRenderer',
    33: 'MeshFilter',
    1001: 'Prefab',
    114: 'MonoBehaviour',
    198: 'ParticleSystem',
    199: 'ParticleSystemRenderer',
}

PARTICLE_RENDER_MODES = {
    0: 'Billboard',
    1: 'StretchBillboard',
    2: 'HorizontalBillboard',
    3: 'VerticalBillboard',
    4: 'Mesh',
    5: 'None',
}


def parse_blocks(text: str):
    blocks = []
    current = None
    current_lines = []

    for line in text.splitlines():
        match = HEADER_RE.match(line)
        if match:
            if current is not None:
                blocks.append((current, current_lines))
            current = {
                'class_id': int(match.group('class_id')),
                'object_id': match.group('object_id'),
            }
            current_lines = []
        elif current is not None:
            current_lines.append(line)

    if current is not None:
        blocks.append((current, current_lines))
    return blocks


def extract_first_scalar(lines, key):
    for line in lines:
        m = KEY_VALUE_RE.match(line)
        if m and m.group('key') == key:
            return m.group('value').strip()
    return None


def extract_guid_after_key(lines, key):
    for i, line in enumerate(lines):
        m = KEY_VALUE_RE.match(line)
        if m and m.group('key') == key:
            guid_match = GUID_RE.search(line)
            if guid_match:
                return guid_match.group(1)
            if i + 1 < len(lines):
                guid_match = GUID_RE.search(lines[i + 1])
                if guid_match:
                    return guid_match.group(1)
    return None


def extract_gameobject_ref(lines):
    for line in lines:
        if 'm_GameObject:' in line:
            ref = re.search(r'fileID:\s*(\d+)', line)
            if ref:
                return ref.group(1)
    return None


def extract_particle_summary(lines):
    result = {
        'duration': extract_first_scalar(lines, 'lengthInSec'),
        'looping': extract_first_scalar(lines, 'looping'),
        'prewarm': extract_first_scalar(lines, 'prewarm'),
        'start_lifetime': extract_first_scalar(lines, 'startLifetime'),
        'start_speed': extract_first_scalar(lines, 'startSpeed'),
        'start_size': extract_first_scalar(lines, 'startSize'),
        'start_color': extract_first_scalar(lines, 'startColor'),
        'gravity_modifier': extract_first_scalar(lines, 'gravityModifier'),
        'max_particles': extract_first_scalar(lines, 'maxParticles'),
        'play_on_awake': extract_first_scalar(lines, 'playOnAwake'),
    }

    shape_index = next((i for i, line in enumerate(lines) if line.strip() == 'shape:'), None)
    if shape_index is not None:
        for line in lines[shape_index + 1: shape_index + 12]:
            m = KEY_VALUE_RE.match(line)
            if not m:
                continue
            if m.group('key') == 'type':
                result['shape_type'] = m.group('value').strip()
            if m.group('key') == 'radius':
                result['shape_radius'] = m.group('value').strip()
            if m.group('key') == 'angle':
                result['shape_angle'] = m.group('value').strip()

    emission_index = next((i for i, line in enumerate(lines) if line.strip() == 'emission:'), None)
    if emission_index is not None:
        burst_count = 0
        for line in lines[emission_index + 1: emission_index + 30]:
            if 'count:' in line:
                burst_count += 1
            m = KEY_VALUE_RE.match(line)
            if m and m.group('key') == 'rateOverTime':
                result['rate_over_time'] = m.group('value').strip()
        result['burst_entries'] = burst_count

    return result


def analyze_prefab(prefab_path: Path):
    text = prefab_path.read_text(encoding='utf-8', errors='ignore')
    blocks = parse_blocks(text)

    game_objects = {}
    particle_systems = []
    particle_renderers = []
    mesh_renderers = []
    mesh_filters = []
    mono_behaviours = []

    for header, lines in blocks:
        class_id = header['class_id']
        object_id = header['object_id']

        if class_id == 1:
            game_objects[object_id] = {
                'object_id': object_id,
                'name': extract_first_scalar(lines, 'm_Name'),
                'layer': extract_first_scalar(lines, 'm_Layer'),
                'active': extract_first_scalar(lines, 'm_IsActive'),
            }
        elif class_id == 198:
            particle_systems.append({
                'object_id': object_id,
                'game_object_id': extract_gameobject_ref(lines),
                **extract_particle_summary(lines),
            })
        elif class_id == 199:
            render_mode_raw = extract_first_scalar(lines, 'm_RenderMode')
            render_mode = None
            if render_mode_raw is not None:
                try:
                    render_mode = PARTICLE_RENDER_MODES.get(int(render_mode_raw), render_mode_raw)
                except ValueError:
                    render_mode = render_mode_raw
            particle_renderers.append({
                'object_id': object_id,
                'game_object_id': extract_gameobject_ref(lines),
                'render_mode': render_mode,
                'material_guid': extract_guid_after_key(lines, 'm_Materials'),
                'mesh_guid': extract_guid_after_key(lines, 'm_Mesh'),
            })
        elif class_id == 23:
            mesh_renderers.append({
                'object_id': object_id,
                'game_object_id': extract_gameobject_ref(lines),
                'material_guid': extract_guid_after_key(lines, 'm_Materials'),
            })
        elif class_id == 33:
            mesh_filters.append({
                'object_id': object_id,
                'game_object_id': extract_gameobject_ref(lines),
                'mesh_guid': extract_guid_after_key(lines, 'm_Mesh'),
            })
        elif class_id == 114:
            mono_behaviours.append({
                'object_id': object_id,
                'game_object_id': extract_gameobject_ref(lines),
                'script_guid': extract_guid_after_key(lines, 'm_Script'),
            })

    for item in particle_systems + particle_renderers + mesh_renderers + mesh_filters + mono_behaviours:
        go = game_objects.get(item.get('game_object_id'))
        item['game_object_name'] = go['name'] if go else None

    material_guids = sorted({
        item['material_guid']
        for item in particle_renderers + mesh_renderers
        if item.get('material_guid')
    })
    mesh_guids = sorted({
        item['mesh_guid']
        for item in particle_renderers + mesh_filters
        if item.get('mesh_guid')
    })
    script_guids = sorted({
        item['script_guid']
        for item in mono_behaviours
        if item.get('script_guid')
    })

    summary = {
        'prefab_name': prefab_path.stem,
        'prefab_path': str(prefab_path),
        'game_object_count': len(game_objects),
        'particle_system_count': len(particle_systems),
        'particle_renderer_count': len(particle_renderers),
        'mesh_renderer_count': len(mesh_renderers),
        'mesh_filter_count': len(mesh_filters),
        'mono_behaviour_count': len(mono_behaviours),
        'particle_render_modes': sorted({item['render_mode'] for item in particle_renderers if item.get('render_mode')}),
        'material_guid_count': len(material_guids),
        'mesh_guid_count': len(mesh_guids),
        'script_guid_count': len(script_guids),
        'material_guids': material_guids,
        'mesh_guids': mesh_guids,
        'script_guids': script_guids,
        'particle_systems': particle_systems,
        'particle_renderers': particle_renderers,
        'mesh_renderers': mesh_renderers,
        'mesh_filters': mesh_filters,
        'mono_behaviours': mono_behaviours,
    }
    return summary


def main():
    parser = argparse.ArgumentParser(description='Analyze Unity text prefab VFX and produce a Roblox migration summary.')
    parser.add_argument('input', help='Path to a Unity prefab file or directory.')
    parser.add_argument('--glob', default='*.prefab', help='Glob used when input is a directory.')
    parser.add_argument('--out', required=True, help='Output JSON path.')
    args = parser.parse_args()

    input_path = Path(args.input)
    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    prefabs = []
    if input_path.is_dir():
        prefabs = sorted(input_path.glob(args.glob))
    else:
        prefabs = [input_path]

    report = {
        'input': str(input_path),
        'prefabs': [analyze_prefab(prefab) for prefab in prefabs],
    }

    out_path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')
    print(f'Wrote {out_path}')


if __name__ == '__main__':
    main()
