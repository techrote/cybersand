"""Compare retained hosted observations; does not execute or change the product."""
from pathlib import Path
import collections
import copy
import datetime
import hashlib
import itertools
import json
import struct
import zipfile

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / 'build/m3-platform'
OUT = BASE / 'repair-windows'
OLD_SOURCE = '68235b12d7f41f7b590456971f21dfc3f5c6d701'
NEW_SOURCE = 'e034f2294663e0485cfb9adcc8ada46a6e977cee'
OLD_ARCHIVE = BASE / 'windows/objectshard-m3-artifact-14744390583.zip'
NEW = OUT / '14745662483'


def hash_file(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def delta(old, new):
    return {'baseline': old, 'repair': new, 'delta': new - old,
            'ratio': new / old if old else None}


def distribution(value):
    fields = {'count': ('count',), 'p50': ('p50', 'p50_usec'), 'p95': ('p95', 'p95_usec'),
              'p99': ('p99', 'p99_usec'), 'maximum': ('maximum', 'maximum_usec')}
    return {name: next((value[k] for k in keys if k in value), None) for name, keys in fields.items()}


def stage_comparison(old, new):
    output = {}
    for stage in sorted(set(old) | set(new)):
        a, b = distribution(old.get(stage, {})), distribution(new.get(stage, {}))
        output[stage] = {'baseline': a, 'repair': b, 'deltas': {
            key: delta(a[key], b[key]) for key in ['p50', 'p95', 'p99', 'maximum']
            if a[key] is not None and b[key] is not None}}
    return output


def canonical(data):
    return json.dumps(data, sort_keys=True, separators=(',', ':')).encode()


def steps(stream):
    for line in stream:
        row = json.loads(line)
        if row.get('kind') == 'step_completed':
            # Exclude exactly one measured observational duration; every other
            # ordered field, including sequence/tick, pose, geometry and motion,
            # remains part of the comparison.
            for body in row['detail']['physics']['bodies']:
                body.pop('last_geometry_usec', None)
            yield row


with zipfile.ZipFile(OLD_ARCHIVE) as archived:
    def old_json(relative):
        return json.loads(archived.read(relative))

    def new_json(relative):
        return json.loads((NEW / relative).read_text())

    old_q, new_q = old_json('windows-lab/qualification.json'), new_json('windows-lab/qualification.json')
    assert old_q['source_commit'] == OLD_SOURCE and new_q['source_commit'] == NEW_SOURCE
    result = {
        'schema': 'objectshard-m3-hosted-baseline-repair-timing-comparison-v1',
        'observed_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'baseline_source': OLD_SOURCE, 'repair_source': NEW_SOURCE,
        'baseline_archive': {'path': str(OLD_ARCHIVE), 'sha256': hash_file(OLD_ARCHIVE)},
        'repair_archive': {'path': str(OUT / 'objectshard-m3-repair-artifact-14745662483.zip'),
                           'sha256': hash_file(OUT / 'objectshard-m3-repair-artifact-14745662483.zip')},
        'native_source_inputs_identical': old_q['native_source_inputs'] == new_q['native_source_inputs'],
        'new_campaigns_executed_for_this_analysis': 0,
        'scope': 'Two retained hosted Windows campaigns, not a same-machine randomized timing experiment. Baseline has superseded lifecycle defects. Timing distributions are observations and their quantiles must not be added across nested stages.',
        'profiles': {},
    }
    for pump in [0, 4000]:
        name = f'windows-lab/objectshard_worker_profile_{pump}.json'
        old, new = old_json(name), new_json(name)
        source_files = old['identity']['files']
        changed = {key: {'baseline': source_files.get(key), 'repair': new['identity']['files'].get(key)}
                   for key in set(source_files) | set(new['identity']['files'])
                   if source_files.get(key) != new['identity']['files'].get(key)}
        result['profiles'][str(pump)] = {
            'baseline_receipt_sha256': hashlib.sha256(archived.read(name)).hexdigest(),
            'repair_receipt_sha256': hash_file(NEW / name),
            'workload_equal_fields': {key: old[key] == new[key] for key in
                ['publication_digests', 'native_accounting', 'completed_intervals', 'actual_live_inputs',
                 'actual_physics_steps', 'maximum_displacements', 'contact_owners', 'sleeping_owners']},
            'publication_count': len(old['publication_digests']),
            'publication_digest_list_sha256': hashlib.sha256(canonical(old['publication_digests'])).hexdigest(),
            'observed_input_and_solver_counts': {key: new[key] for key in
                ['completed_intervals', 'actual_live_inputs', 'actual_physics_steps']},
            'changed_execution_input_hashes': changed,
            'engine_hash_identical': old['identity']['engine_sha256'] == new['identity']['engine_sha256'],
            'semantic_hz': delta(old['semantic_ticks_per_wall_second'], new['semantic_ticks_per_wall_second']),
            'play_elapsed_usec': delta(old['play_elapsed_usec'], new['play_elapsed_usec']),
            'host_stages_usec': stage_comparison(old['host_stages_usec'], new['host_stages_usec']),
            'outer_measurements_usec': stage_comparison(
                {k: old[k] for k in ['pump_call_usec', 'semantic_interval_and_input_usec', 'process_callback_interval_usec']},
                {k: new[k] for k in ['pump_call_usec', 'semantic_interval_and_input_usec', 'process_callback_interval_usec']}),
        }
    relative = 'windows-lab/continuous-physics-session-1.jsonl'
    a_hash, b_hash = hashlib.sha256(), hashlib.sha256()
    count = mismatches = 0
    with archived.open(relative) as a, (NEW / relative).open('rb') as b:
        for left, right in itertools.zip_longest(steps(a), steps(b)):
            count += 1
            mismatches += left != right
            a_hash.update(canonical(left) + b'\n')
            b_hash.update(canonical(right) + b'\n')
    old_long, new_long = old_json('windows-lab/continuous-physics.json'), new_json('windows-lab/continuous-physics.json')
    result['long_physics'] = {
        'intervals': count, 'mismatches': mismatches,
        'only_excluded_field': 'step_completed.detail.physics.bodies[].last_geometry_usec',
        'baseline_physical_records_sha256': a_hash.hexdigest(), 'repair_physical_records_sha256': b_hash.hexdigest(),
        'native_accounting_identical': old_long['native_accounting'] == new_long['native_accounting'],
        'work_equal_fields': {key: old_long[key] == new_long[key] for key in
            ['checks', 'tick', 'completed_ticks', 'actions_queued', 'moving_owners', 'sleeping_owners', 'physics_steps',
             'maximum_displacements', 'post_settle_edit_tick', 'post_erosion_maximum_rotation', 'post_erosion_maximum_translation']},
        'interval_timing_usec': stage_comparison({'interval': old_long['timing']}, {'interval': new_long['timing']}),
    }
    name = 'windows-lab/continuous-play-rendered.json'
    old, new = old_json(name), new_json(name)
    def actions_without_observer_time(rows):
        return [{k: v for k, v in row.items() if k not in ['admitted_usec', 'captured_usec', 'completed_usec']}
                for row in rows]
    result['rendered'] = {
        'baseline_receipt_sha256': hashlib.sha256(archived.read(name)).hexdigest(),
        'repair_receipt_sha256': hash_file(NEW / name),
        'pointer_work': new['pointer_input'], 'pointer_work_identical': old['pointer_input'] == new['pointer_input'],
        'native_accounting_identical': old['accounting'] == new['accounting'],
        'tick': {'baseline': old['tick'], 'repair': new['tick']},
        'action_results_identical_except_observer_timestamps': actions_without_observer_time(old['action_results']) == actions_without_observer_time(new['action_results']),
        'host_stages_usec': stage_comparison(old['timings_usec'], new['timings_usec']),
        'presentation_stages_usec': stage_comparison(old['presentation_timing']['stages'], new['presentation_timing']['stages']),
        'scope': 'Same153 scene intents including96-input burst;38 completed ticks after initial tick1. Scene queue and host stages include the full original timestamp. Presentation callback is observed, not monitor scanout; hosted renderer is not owner NVIDIA performance.',
    }

old_binary = (BASE / 'windows/14743743167/cybersand_native.windows.x86_64.dll').read_bytes()
new_binary = (OUT / '14745122677/cybersand_native.windows.x86_64.dll').read_bytes()
positions = [i for i, (a, b) in enumerate(zip(old_binary, new_binary)) if a != b]
ranges = []
for index in positions:
    if ranges and index == ranges[-1][1]:
        ranges[-1][1] += 1
    else:
        ranges.append([index, index + 1])
pe = struct.unpack_from('<I', old_binary, 0x3c)[0]
count = struct.unpack_from('<H', old_binary, pe + 6)[0]
start = pe + 24 + struct.unpack_from('<H', old_binary, pe + 20)[0]
sections = []
for index in range(count):
    offset = start + 40 * index
    name = old_binary[offset:offset + 8].rstrip(b'\0').decode()
    size, position = struct.unpack_from('<II', old_binary, offset + 16)
    sections.append({'name': name, 'offset': position, 'bytes': size,
        'identical': old_binary[position:position + size] == new_binary[position:position + size],
        'baseline_sha256': hashlib.sha256(old_binary[position:position + size]).hexdigest(),
        'repair_sha256': hashlib.sha256(new_binary[position:position + size]).hexdigest()})
result['fresh_binary_comparison'] = {
    'baseline_sha256': hashlib.sha256(old_binary).hexdigest(), 'repair_sha256': hashlib.sha256(new_binary).hexdigest(),
    'sizes': [len(old_binary), len(new_binary)], 'different_bytes': len(positions), 'ranges': ranges,
    'sections': sections,
    'difference_observations': ['Six randomized atomic linker output basename characters in .rdata: partial.2kcN6P versus partial.Vzaadq.',
                                'Eight bytes in RSDS/LLD PDB identifier within .buildid.'],
    'scope': 'Read-only comparison of independently fresh source-built binaries. No byte normalization, substitution, reused qualification, or package mutation. Executable .text and all other section bytes outside the two identified metadata ranges are identical.',
}
result['interpretation'] = [
    'Fresh candidate observed slower pump4000 progression and longer burst input-to-presentation latency than the superseded candidate. Preserve these negative comparisons.',
    'The unpumped control retains virtually the same cadence while native, snapshot and value-accounting durations increase. The pump can therefore fit fewer completed receipts into its unchanged soft budget; more delivery waits and callbacks are observed.',
    'This is consistent with broader hosted execution throughput variation. It does not prove the host caused every difference, and the rendered UI has a real navigation/input guard source delta. Do not label the regression repaired or purely environmental.',
    'The same-source fresh pump4000 versus pump0 comparison remains the direct scheduling evidence: identical workload/state,17.1382 versus8.2561semanticHz. These are hosted observations, not production responsiveness or target GPU acceptance.',
    'All existing qualification limits remain unchanged. This report adds no new threshold and executes no rerun. Independent review and owner physical playtesting remain separate gates.',
]
result['status'] = 'observed_slowdown_investigated_and_retained'
assert result['native_source_inputs_identical'] and count > 0
assert result['long_physics']['intervals'] == 3599 and result['long_physics']['mismatches'] == 0
for profile in result['profiles'].values():
    assert all(profile['workload_equal_fields'].values())
output = OUT / 'baseline-repair-timing-comparison.json'
output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({'path': str(output), 'sha256': hash_file(output), 'status': result['status'],
                  'long_intervals_identical': result['long_physics']['intervals'],
                  'profile_digests_identical_each': 240, 'binary_differing_bytes': len(positions),
                  'rendered_action_results_identical': result['rendered']['action_results_identical_except_observer_timestamps']}))
