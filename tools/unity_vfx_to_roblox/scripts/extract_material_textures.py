#!/usr/bin/env python3
import argparse
import json
import re
import shutil
from pathlib import Path

GUID_RE = re.compile(r'guid:\s*([0-9a-f]{32})')
TEXTURE_REF_RE = re.compile(r'm_Texture:\s*\{fileID:\s*\d+, guid:\s*([0-9a-f]{32}), type:\s*3\}')
NAME_RE = re.compile(r'm_Name:\s*(.+)')

IMAGE_EXTS = ['.png', '.tga', '.jpg', '.jpeg', '.psd', '.tif', '.tiff', '.exr']


def build_guid_index(assets_root: Path):
    index = {}
    for meta in assets_root.rglob('*.meta'):
        try:
            text = meta.read_text(encoding='utf-8', errors='ignore')
        except OSError:
            continue
        match = GUID_RE.search(text)
        if not match:
            continue
        index[match.group(1)] = meta
    return index


def parse_material(mat_path: Path):
    text = mat_path.read_text(encoding='utf-8', errors='ignore')
    name_match = NAME_RE.search(text)
    texture_guids = sorted(set(TEXTURE_REF_RE.findall(text)))
    return {
        'material_name': name_match.group(1).strip() if name_match else mat_path.stem,
        'texture_guids': texture_guids,
    }


def find_asset_from_meta(meta_path: Path):
    base = meta_path.with_suffix('')
    if base.exists():
        return base
    for ext in IMAGE_EXTS:
        candidate = base.with_suffix(ext)
        if candidate.exists():
            return candidate
    return None


def copy_asset(src: Path, dest_dir: Path):
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / src.name
    shutil.copy2(src, dest)
    meta_src = Path(str(src) + '.meta')
    if meta_src.exists():
        shutil.copy2(meta_src, dest_dir / (src.name + '.meta'))
    return dest


def main():
    parser = argparse.ArgumentParser(description='Extract texture assets referenced by Unity material files.')
    parser.add_argument('--assets-root', required=True)
    parser.add_argument('--material', action='append', required=True, help='Path to a Unity .mat file. Can be repeated.')
    parser.add_argument('--out-dir', required=True)
    parser.add_argument('--report', required=True)
    args = parser.parse_args()

    assets_root = Path(args.assets_root)
    out_dir = Path(args.out_dir)
    report_path = Path(args.report)
    report_path.parent.mkdir(parents=True, exist_ok=True)

    guid_index = build_guid_index(assets_root)

    report = {
        'assets_root': str(assets_root),
        'materials': [],
        'copied_assets': [],
        'missing_texture_guids': [],
    }

    copied = set()

    for mat_arg in args.material:
        mat_path = Path(mat_arg)
        mat_info = parse_material(mat_path)
        mat_entry = {
            'material_path': str(mat_path),
            'material_name': mat_info['material_name'],
            'textures': [],
        }

        material_dest_dir = out_dir / 'materials'
        copied_mat = copy_asset(mat_path, material_dest_dir)
        mat_entry['copied_material'] = str(copied_mat)

        for tex_guid in mat_info['texture_guids']:
            meta_path = guid_index.get(tex_guid)
            if not meta_path:
                report['missing_texture_guids'].append(tex_guid)
                mat_entry['textures'].append({'guid': tex_guid, 'status': 'missing_meta'})
                continue

            asset_path = find_asset_from_meta(meta_path)
            if not asset_path:
                report['missing_texture_guids'].append(tex_guid)
                mat_entry['textures'].append({'guid': tex_guid, 'status': 'missing_asset', 'meta_path': str(meta_path)})
                continue

            texture_dest_dir = out_dir / 'textures'
            copied_asset = copy_asset(asset_path, texture_dest_dir)
            copied.add(str(copied_asset))
            mat_entry['textures'].append({
                'guid': tex_guid,
                'source_asset': str(asset_path),
                'copied_asset': str(copied_asset),
                'status': 'copied',
            })

        report['materials'].append(mat_entry)

    report['copied_assets'] = sorted(copied)
    report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')
    print(f'Wrote {report_path}')


if __name__ == '__main__':
    main()
