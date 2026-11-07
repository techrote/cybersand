"""Separate exact-head repository gates for the fixed-action ordering campaign."""
import argparse
import sys
from pathlib import Path

import structure_cut as p
import workbench_order_common as w


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--run', required=True)
    args = parser.parse_args()
    assert Path(args.run).name == args.run
    identity = w.identity()
    folder = w.OUT / args.run
    assert not folder.exists()
    folder.mkdir()
    commands = [
        ('docs', ['tools/ci/check_docs.py', '--json', str(folder / 'docs.json')]),
        ('m11', ['tools/ci/check_m11_consistency.py', '--json', str(folder / 'm11.json')]),
        ('repository', ['tools/ci/check_repository.py', '--require-materialized', '--json', str(folder / 'repository.json')]),
        ('material-guard', ['tools/material_catalogue/compatibility.py', '--check']),
        ('material-generated', ['tools/material_catalogue/compiler.py', '--check']),
        ('state-admission', ['tools/sol281/test_order_reduction.py']),
        ('geometry-controls', ['tools/sol281/test_structure_reducer.py']),
        ('workbench-admission', ['tools/sol281/test_workbench_reducer.py']),
        ('ordering-admission', ['tools/sol281/test_workbench_order_reduce.py']),
        ('runtime-roster', ['tools/sol281/workbench_check.py', '--runtime-only']),
    ]
    for index, name in enumerate([
        'retrieval-questions.json', 'retrieval-questions-sol-order.json',
        'retrieval-questions-sol-workbench.json', 'retrieval-questions-sol-workbench-order.json',
    ]):
        commands.append(('retrieval' + str(index), [
            'tools/docs/retrieval_eval.py', '--queries', 'docs/reference/' + name,
            '--output', str(folder / ('retrieval' + str(index) + '.json')),
        ]))
    rows = [p.command(name, [sys.executable, '-B', *argv], folder, timeout=180)
            for name, argv in commands]
    rows.append(p.command('diff-check', ['git', 'diff', '--check'], folder, timeout=120))
    assert identity == w.identity()
    p.write(folder / 'receipt.json', dict(
        identity=identity, commands=rows, post_source_equality=True, resource=w.resource(),
        scope='Exact-head docs/identity/adverse-observer gates; physical and Linux-floor decisions remain separate.',
    ))
    return int(not all(row['clean'] for row in rows))


if __name__ == '__main__':
    raise SystemExit(main())
