#!/usr/bin/env python3
import argparse
import json
import re
from pathlib import Path

LOD_RE = re.compile(r'^(?P<base>.+?)_(?P<lod>LOD\d|LODHDR)$', re.IGNORECASE)


def classify_effect(base_name: str) -> str:
    lower = base_name.lower()
    if 'buff' in lower:
        return 'BuffAura'
    if 'hurt' in lower or 'explosion' in lower:
        return 'ImpactOrExplosion'
    if 'spell02' in lower or 'spell03' in lower:
        return 'SkillCore'
    if 'attack' in lower:
        return 'Attack'
    return 'Unknown'


def build_report(prefab_dir: Path):
    groups = {}
    for prefab in sorted(prefab_dir.glob('*.prefab')):
        stem = prefab.stem
        match = LOD_RE.match(stem)
        if match:
            base_name = match.group('base')
            lod = match.group('lod').upper()
        else:
            base_name = stem
            lod = 'NONE'

        info = groups.setdefault(base_name, {
            'base_name': base_name,
            'classification': classify_effect(base_name),
            'lods': {},
        })
        info['lods'][lod] = {
            'file_name': prefab.name,
            'size_bytes': prefab.stat().st_size,
        }

    result = []
    for base_name in sorted(groups):
        row = groups[base_name]
        row['preferred_source_lod'] = 'LOD1' if 'LOD1' in row['lods'] else sorted(row['lods'])[0]
        row['lod_count'] = len(row['lods'])
        result.append(row)
    return result


def main():
    parser = argparse.ArgumentParser(description='Group Unity VFX prefabs by LOD family.')
    parser.add_argument('prefab_dir', help='Directory containing Unity VFX prefabs.')
    parser.add_argument('--out', required=True, help='Output JSON path.')
    args = parser.parse_args()

    prefab_dir = Path(args.prefab_dir)
    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    report = {
        'prefab_dir': str(prefab_dir),
        'families': build_report(prefab_dir),
    }
    out_path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')
    print(f'Wrote {out_path}')


if __name__ == '__main__':
    main()
