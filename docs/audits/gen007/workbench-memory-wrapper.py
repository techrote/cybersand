#!/usr/bin/env python3
"""Measure the sole Godot child of this process; run this wrapper inside Xvfb."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import resource
import subprocess
import sys
import time

parser = argparse.ArgumentParser()
parser.add_argument('--godot', type=Path, required=True)
parser.add_argument('--project', type=Path, required=True)
parser.add_argument('--probe', type=Path, required=True)
parser.add_argument('--output-dir', type=Path, required=True)
parser.add_argument('--source', required=True)
parser.add_argument('--timeout', type=float, default=180.0)
args = parser.parse_args()
if sys.platform != 'linux':
    parser.error('This receipt uses Linux ru_maxrss units (KiB).')
out = args.output_dir.resolve()
out.mkdir(parents=True, exist_ok=True)
latency_path = out / 'workbench-rss-latency.json'
log_path = out / 'workbench-rss-latency.log'
memory_path = out / 'workbench-memory.json'
environment = os.environ.copy()
environment['CYBERSAND_SOURCE_SHA'] = args.source
environment['CYBERSAND_INPUT_WORKTREE_CHANGES'] = ''
command = [str(args.godot.resolve()), '--path', str(args.project.resolve()),
           '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy',
           '--script', str(args.probe.resolve()), '--', '--output=' + str(latency_path)]
started_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
usage_before = resource.getrusage(resource.RUSAGE_CHILDREN)
started = time.monotonic()
timed_out = False
with log_path.open('w') as log:
    try:
        completed = subprocess.run(command, env=environment, stdout=log,
                                   stderr=subprocess.STDOUT, timeout=args.timeout)
        returncode = completed.returncode
    except subprocess.TimeoutExpired:
        returncode = -124
        timed_out = True
wall_seconds = time.monotonic() - started
usage = resource.getrusage(resource.RUSAGE_CHILDREN)
latency = json.loads(latency_path.read_text()) if latency_path.exists() else {}
peak_rss_bytes = usage.ru_maxrss * 1024
threshold_bytes = 4 * 1024 ** 3
passed = (returncode == 0 and latency.get('failures') == []
          and 0 < peak_rss_bytes <= threshold_bytes)
report = {
    'schema': 1,
    'started_at_utc': started_at,
    'source_commit': args.source,
    'scope': 'One isolated display-backed Godot authoring process running the portable full-recipe Workbench probe; Xvfb and the parent Python process are excluded.',
    'measurement': 'Linux resource.getrusage(RUSAGE_CHILDREN).ru_maxrss after waiting for the sole Godot child; peak resident memory, not virtual address space or aggregate concurrent-process memory.',
    'memory_limit_enforcement': 'No additional RLIMIT or cgroup memory limit was imposed by this wrapper; the observed process high-water RSS is compared with the 4 GiB acceptance bound.',
    'ru_maxrss_units': 'KiB (Linux)',
    'ru_maxrss_before_child': usage_before.ru_maxrss,
    'ru_maxrss': usage.ru_maxrss,
    'peak_rss_bytes': peak_rss_bytes,
    'acceptance_bound_bytes': threshold_bytes,
    'within_4_gib': 0 < peak_rss_bytes <= threshold_bytes,
    'rlimit_as': list(resource.getrlimit(resource.RLIMIT_AS)),
    'wall_seconds': wall_seconds,
    'child_user_seconds': usage.ru_utime - usage_before.ru_utime,
    'child_system_seconds': usage.ru_stime - usage_before.ru_stime,
    'returncode': returncode,
    'timeout_seconds': args.timeout,
    'timed_out': timed_out,
    'passed': passed,
    'command': command,
    'environment': {key: environment.get(key, '') for key in
                    ['LIBGL_ALWAYS_SOFTWARE', 'LP_NUM_THREADS', 'GALLIVM_PERF',
                     'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']},
    'latency_receipt': latency_path.name,
    'latency_receipt_sha256': hashlib.sha256(latency_path.read_bytes()).hexdigest() if latency_path.exists() else '',
    'probe_sha256': hashlib.sha256(args.probe.read_bytes()).hexdigest(),
    'wrapper_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    'recipe_sha256': latency.get('recipe_sha256'),
    'runtime_sha256': latency.get('runtime_sha256'),
    'source_file_sha256': latency.get('source_file_sha256'),
    'probe_failures': latency.get('failures'),
}
memory_path.write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
print('GEN007_WORKBENCH_MEMORY: %s; peak_rss_mib=%.3f; bound_mib=4096; exit=%s; wall_seconds=%.3f'
      % ('PASS' if passed else 'FAIL', peak_rss_bytes / (1024 ** 2), returncode, wall_seconds))
sys.exit(0 if passed else 1)
