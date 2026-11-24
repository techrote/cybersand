#!/usr/bin/env python3
"""Package the completed read-only replays; do not execute a gameplay arm."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--workspace-root', type=Path, default=Path('/workspace/scratch/0b2a9bdf7883'))
parser.add_argument('--output-directory', type=Path)
args = parser.parse_args()
base = args.workspace_root
evidence = base/'evidence-c'
destination = args.output_directory or Path(__file__).resolve().parent.parent
destination.mkdir(parents=True, exist_ok=True)
(destination/'readers').mkdir(exist_ok=True)
sha = lambda data: hashlib.sha256(data).hexdigest()
reports = {
    'final03-linux-independent-physical.json': '6844bd5f227ef833ef7763278ee0503d9c1e3ec746a7dd3a0006ef5c2b7ac803',
    'final03-linux-complete-frozen-replay.json': '7a07c5f2ed98d41b25d7ab4bc87d2787d949d796210b603ae2d2014131fe6e8d',
    'final03-linux-independent-correctness.json': '32c03eee14b916671f6171e464923216986a77bc5a0eba04502db9fba6c25427',
    'final03-linux-mixed-hidden-positions.json': 'ba06c52d30cc1e89d9b82e15ef501073cde67b331892e170ed7d3e3f6aa2af5b',
    'final03-linux-hidden-frame-samples.json': 'a492737b1ee306b58ef653d27051a4bccc163a2f8c57fb49eee33e0456651fa8',
    'historical-c90-causal-stage-recovery.json': 'c9eeaf9dfcca0e0cb7bde6b8fe56de2081fd1eef890c3a3475b0a32b94cb6b0c',
}
for name, expected in reports.items():
    raw = (evidence/name).read_bytes()
    assert sha(raw) == expected, name
    (destination/name).write_bytes(raw)
for name in ('reduce_final03_zip.py', 'replay_final03_linux.py', 'replay_final03_correctness.py',
             'extract_final03_hidden_samples.py', 'recover_historical_causal_stages.py'):
    shutil.copyfile(evidence/name, destination/'readers'/name)

physical = json.loads((evidence/'final03-linux-independent-physical.json').read_text())
frozen = json.loads((evidence/'final03-linux-complete-frozen-replay.json').read_text())
by_member = {a['member']: a for group in frozen['comparisons'] for a in group['arms']}
resources = []
with zipfile.ZipFile(base/'evidence-root/final-03/graphical-linux/original.zip') as z:
    for row in physical['receipts']:
        prefix = row['member'].removesuffix('receipt.json')
        process_raw = z.read(prefix+'process.json')
        memory_raw = z.read(prefix+'process-memory.json')
        process, memory = json.loads(process_raw), json.loads(memory_raw)
        cpu = by_member[row['member']]['observers']['cpu']
        assert process['exit_code'] == 0 and not process['timed_out']
        assert process['observed_application_pid'] == cpu['expected_pid']
        assert all(m['pid'] == cpu['expected_pid'] for m in memory)
        assert all(m['rss_bytes'] is None or type(m['rss_bytes']) is int and m['rss_bytes'] >= 0 for m in memory)
        assert all(m['peak_rss_bytes'] is None or type(m['peak_rss_bytes']) is int and m['peak_rss_bytes'] >= 0 for m in memory)
        observed = [m['rss_bytes'] for m in memory if m['rss_bytes'] is not None]
        high_water = [m['peak_rss_bytes'] for m in memory if m['peak_rss_bytes'] is not None]
        assert observed and high_water
        peak = max(high_water)
        assert peak == process['sampled_peak_rss_bytes']
        resources.append({
            'member': row['member'], 'process_sha256': sha(process_raw), 'memory_sha256': sha(memory_raw),
            'owned_pid': cpu['expected_pid'], 'memory_samples': len(memory),
            'memory_samples_without_rss': len(memory)-len(observed),
            'memory_samples_without_high_water': len(memory)-len(high_water),
            'maximum_sampled_current_rss_bytes': max(observed),
            'sampled_peak_rss_bytes': peak, 'sampled_peak_rss_mib': peak/1048576, 'cpu': cpu,
        })
resource_report = {
    'schema': 'pubpres-final03-linux-resource-custody-v1', 'archive_sha256': physical['archive_sha256'],
    'reader_sha256': sha(Path(__file__).read_bytes()), 'arms': resources,
    'scope': 'Every memory sample PID and queried kernel RSS high-water maximum is rejoined to the actual owned process and replayed CPU sidecar. Maximum sampled instantaneous RSS is retained separately; missing queries remain explicit. Samples include scene setup; they are not aligned to capture clocks, CPU per physical step, or GPU residency.',
}
(destination/'process-resources.json').write_text(json.dumps(resource_report, indent=2)+'\n')
lines = [
    '---', 'title: PUBPRES final03 Linux physical timing tables', 'status: Historical', 'document-kind: audit',
    'scope: Every retained Linux03 timing arm with independent real-step reduction and explicit capture windows',
    'canonical-for: []', 'last-reviewed: 2026-11-24', 'related-documents: [../final03-linux-decision.md]',
    '---', '', '# Final03 Linux physical timing tables', '',
    'Every row is recomputed from independently witnessed completed Rapier steps. Fixed-step comparisons use capture start through the 144th completion. The three sustained ordinary captures use the complete recorded window. Quantiles use within-run linear interpolation; runs are never pooled. Threshold counts describe exposure, not an owner-approved acceptance threshold. Exact unrounded values, whole-capture alternatives, input witnesses, and all identities are in `final03-linux-independent-physical.json`.', '',
    'Source comparisons use D = frozen c90 and C = c2. Calibration uses C in every arm, with presentation probe OFF/ON/ON/OFF; its D-like comparison labels are statistical roles, not a different application source. Deadline arms use the same C source/runtime and 0/30/60/60/30/0 Hz.', '',
]
groups = {}
for row in physical['receipts']:
    groups.setdefault(row['member'].split('/')[0], []).append(row)
for group, rows in groups.items():
    lines += ['## '+group, '', '| Case / arm | Window | Steps/s | p50 ms | p95 ms | p99 ms | Max ms | Gaps >100 / >250 / >500 ms |',
              '| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |']
    for row in rows:
        whole = group in ('mixed-eight-actor', 'sustained-slots2')
        window = row['windows']['whole_capture' if whole else 'first_144_steps']
        gaps, counts = window['physical_gap_ms'], window['gaps_above_ms']
        label = row['member'].removeprefix(group+'/').removesuffix('/receipt.json')
        span = f"{window['completed_rapier_steps']} steps / {window['duration_seconds']:.3f} s"
        lines.append(f"| {label} | {span} | {window['rapier_steps_per_second']:.4f} | {gaps['p50']:.3f} | {gaps['p95']:.3f} | {gaps['p99']:.3f} | {gaps['max']:.3f} | {counts['100']} / {counts['250']} / {counts['500']} |")
    lines.append('')
(destination/'physical-tables.md').write_text('\n'.join(lines).rstrip()+'\n')
index = {
    'schema': 'pubpres-final03-linux-decision-evidence-index-v1',
    'application_source': frozen['application_source'], 'application_tree': frozen['application_tree'],
    'run': 45452580606, 'artifact': 14954600370, 'artifact_sha256': physical['archive_sha256'],
    'artifact_bytes': 131344255, 'files': [],
    'scope': 'Copied original independent replay receipts preserve their bytes and reader identities. Raw hosted archive remains the authoritative source; no timing process was re-executed for this packet.',
}
for path in sorted(destination.rglob('*')):
    if path.is_file() and path.name != 'INDEX.json' and '__pycache__' not in path.parts:
        index['files'].append({'path': path.relative_to(destination).as_posix(),
                               'bytes': path.stat().st_size, 'sha256': sha(path.read_bytes())})
(destination/'INDEX.json').write_text(json.dumps(index, indent=2)+'\n')
print(json.dumps({'files': len(index['files']), 'bytes': sum(row['bytes'] for row in index['files']),
                  'resource_arms': len(resources), 'index_sha256': sha((destination/'INDEX.json').read_bytes())}))
