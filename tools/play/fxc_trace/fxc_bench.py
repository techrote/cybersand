"""Interleaved offline FXC benchmark: rounds x labelled HLSL files, rotating order, one process per compile.
usage: fxc_bench.py <rounds> <out.jsonl> label=path [label=path ...]"""
import json, os, subprocess, sys, pathlib, statistics

TOOLS = pathlib.Path(__file__).parent
rounds = int(sys.argv[1])
out = pathlib.Path(sys.argv[2])
items = [arg.split('=', 1) for arg in sys.argv[3:]]
rows = []
for r in range(rounds):
    order = items[r % len(items):] + items[:r % len(items)]
    for label, path in order:
        dxbc = out.parent / f'{label}.dxbc'
        line = subprocess.check_output([sys.executable, str(TOOLS / 'fxc_compile.py'), path, '--out', str(dxbc)], text=True).strip()
        row = json.loads(line)
        row.update(label=label, round=r)
        rows.append(row)
        with out.open('a') as f:
            f.write(json.dumps(row) + '\n')
        print(label, r, row['wall'], row['cpu'], flush=True)
summary = {}
for label, path in items:
    walls = [x['wall'] for x in rows if x['label'] == label]
    cpus = [x['cpu'] for x in rows if x['label'] == label]
    stats = json.loads(subprocess.check_output([sys.executable, str(TOOLS / 'dxbc_stats.py'), str(out.parent / f'{label}.dxbc')], text=True))
    summary[label] = {'n': len(walls), 'wall_median': statistics.median(walls), 'wall_min': min(walls), 'cpu_median': statistics.median(cpus),
                      'cpu_min': min(cpus), 'hlsl_bytes': rows[[x['label'] for x in rows].index(label)]['bytes'], 'dxbc': stats}
print(json.dumps(summary, indent=1))
(out.parent / (out.stem + '.summary.json')).write_text(json.dumps(summary, indent=1))
