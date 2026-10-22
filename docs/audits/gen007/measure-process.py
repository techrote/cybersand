import datetime, hashlib, json, os, pathlib, platform, resource, subprocess, sys, time

prefix, *command = sys.argv[1:]
limit = int(os.environ['GEN007_RSS_LIMIT_BYTES'])
repo = pathlib.Path.cwd()
recipe = repo / 'examples/worldgen/gen007-deepworks.json'
library = repo / 'godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so'
def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()
initial = {'recipe_sha256': sha(recipe), 'native_library_sha256': sha(library)}
started = datetime.datetime.now(datetime.timezone.utc).isoformat()
start = time.monotonic()
timed_out = False
with open(prefix + '.log', 'w') as output:
    try:
        result = subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, timeout=180)
        returncode = result.returncode
    except subprocess.TimeoutExpired:
        returncode, timed_out = 124, True
elapsed = time.monotonic() - start
usage = resource.getrusage(resource.RUSAGE_CHILDREN)
final = {'recipe_sha256': sha(recipe), 'native_library_sha256': sha(library)}
cpu_model = ''
for line in pathlib.Path('/proc/cpuinfo').read_text().splitlines():
    if line.startswith('model name'):
        cpu_model = line.partition(':')[2].strip()
        break
environment_names = ['CYBERSAND_SOURCE_REVISION', 'LIBGL_ALWAYS_SOFTWARE', 'LP_NUM_THREADS', 'GALLIVM_PERF', 'MESA_SHADER_CACHE_DIR', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'CYBERSAND_GEN007_QUALIFICATION_REPORT', 'CYBERSAND_GEN007_REACTIONS_REPORT']
report = {
    'schema': 1, 'started_utc': started, 'command': command, 'cwd': str(repo),
    'returncode': returncode, 'timed_out': timed_out, 'timeout_seconds': 180,
    'elapsed_seconds': elapsed, 'process_peak_rss_bytes': usage.ru_maxrss * 1024,
    'process_rss_limit_bytes': limit, 'within_process_rss_limit': usage.ru_maxrss * 1024 <= limit,
    'source_revision': os.environ.get('CYBERSAND_SOURCE_REVISION', ''),
    'identities_before': initial, 'identities_after': final, 'identities_unchanged': initial == final,
    'environment': {key: os.environ.get(key, '') for key in environment_names},
    'cache_state': os.environ.get('GEN007_CACHE_STATE', ''),
    'platform': platform.platform(), 'python': platform.python_version(),
    'cpu_model': cpu_model, 'logical_cpus_visible': os.cpu_count(),
    'scope': 'Isolated local GEN007 qualification process; no other native builds or Godot test processes running. Linux getrusage(RUSAGE_CHILDREN) maximum resident set of child/descendant processes, not simultaneous aggregate process-tree memory. Native prepared bytes and Godot static peak are separate report fields.'
}
with open(prefix + '.time.json', 'w') as output:
    json.dump(report, output, indent=2)
    output.write('\n')
print(json.dumps(report), flush=True)
raise SystemExit(returncode if returncode else (0 if report['within_process_rss_limit'] and report['identities_unchanged'] else 3))
