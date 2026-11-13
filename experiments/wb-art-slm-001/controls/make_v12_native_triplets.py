"""Generate 48 matched v1/v1.1/v1.2 coral inputs for REAL native replay.

Compiler-only. Does not run Godot, infer a model response, or claim native pass.
The companion sidecar preserves original IDs and all compiler identities.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import pattern_compiler as v1
import pattern_compiler_v11 as v11
import pattern_compiler_v12 as v12


def build_triplets() -> tuple[dict, dict]:
    cases, aliases = [], {}
    for variant in range(8):
        program = v1.make_program('coral', variant)
        for seed in (17, 73):
            group = {}
            for tag, compiler in (('c10', v1), ('c11', v11), ('c12', v12)):
                report = compiler.compile_with_report(program, 96, 96, seed)
                case_id = f'{tag}-coral-v{variant}-s{seed}'
                if len(case_id) > 38:
                    raise ValueError('native save-name budget exceeded')
                operations = report['operations']
                operation_sha = hashlib.sha256(v1.canonical_json(operations).encode()).hexdigest()
                cases.append({'id': case_id, 'theme': 'coral', 'width': 96,
                              'height': 96, 'seed': seed, 'program_sha256': report['program_sha256'],
                              'operations_sha256': operation_sha, 'operations': operations})
                group[tag] = {'id': case_id, 'compiler_version': report['compiler_version'],
                              'operation_count': report['operation_count'],
                              'estimated_cell_work': report['estimated_cell_work'],
                              'operations_sha256': operation_sha}
            aliases[f'original-coral-v{variant}-s{seed}'] = group
    if len(cases) != 48 or len(aliases) != 16 or len({c['id'] for c in cases}) != 48:
        raise ValueError('incomplete or duplicate native triplet cohort')
    return {'cases': cases}, {'schema_version': 1, 'native_executed': False,
                              'required_history_mode': 'each',
                              'parent_compiler_sha256': v12.BASE_COMPILER_SHA256,
                              'candidate_compiler_version': v12.COMPILER_VERSION,
                              'aliases': aliases}


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out', type=Path, required=True, help='new JSON native case file')
    p.add_argument('--aliases-out', type=Path, required=True, help='new provenance sidecar JSON')
    a = p.parse_args()
    if a.out.resolve() == a.aliases_out.resolve():
        p.error('outputs must be distinct')
    cases, sidecar = build_triplets()
    case_bytes = (json.dumps(cases, separators=(',', ':'), allow_nan=False) + '\n').encode()
    sidecar['native_case_file_sha256'] = hashlib.sha256(case_bytes).hexdigest()
    # Exclusive create: never silently replace previously run or sealed inputs.
    with a.out.open('xb') as f:
        f.write(case_bytes)
    with a.aliases_out.open('xb') as f:
        f.write((json.dumps(sidecar, indent=2, allow_nan=False) + '\n').encode())
    print(json.dumps({'cases': len(cases['cases']), 'pairs': len(sidecar['aliases']),
                      'sha256': sidecar['native_case_file_sha256'], 'native_executed': False}))


if __name__ == '__main__':
    main()
