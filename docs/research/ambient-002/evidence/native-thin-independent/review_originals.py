"""Read retained native-probe originals; perform no engine or actor execution."""
from pathlib import Path
import hashlib
import json
import math
import statistics
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent
ARCHIVE = ROOT / 'originals.zip'
if not ARCHIVE.is_file():
    ARCHIVE = ROOT.parent / 'native-thin-a725' / 'originals.zip'
TEMPORARY_ORIGINALS = tempfile.TemporaryDirectory(prefix='ambient-native-thin-readback-')
ORIGINALS = Path(TEMPORARY_ORIGINALS.name)
with zipfile.ZipFile(ARCHIVE) as archive:
    if any(Path(name).is_absolute() or '..' in Path(name).parts for name in archive.namelist()):
        raise ValueError('unsafe original archive member')
    archive.extractall(ORIGINALS)
ATTEMPT = ORIGINALS / 'attempt-001'
SOURCE = 'a7250e15495667b2fcf564cbed1eaa8dea217c45'
checks = []


def check(value, description):
    if not value:
        raise AssertionError(description)
    checks.append(description)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


report = json.loads((ATTEMPT / 'report.json').read_text())
execution = json.loads((ATTEMPT / 'execution.json').read_text())
verification = json.loads((ATTEMPT / 'verification.json').read_text())
check(sha(ARCHIVE) == 'c565b2e50ad1749decb94b7873167b6608d4bb2789c8d3e541d33391a567d949', 'original ZIP digest')
check(execution['source_revision'] == report['source_revision'] == SOURCE, 'frozen application identity')
check(execution['returncode'] == 0 and report['complete'] and not report['failures'], 'original process and report completed successfully')
check(report['checks'] == verification['checks'] == 228, 'original assertion count')
for name in ('report.json', 'publication.cells.bin'):
    check(sha(ATTEMPT / name) == execution[name + '_sha256'], 'original ' + name + ' hash')
for field, name in [('console_sha256', 'console.log'), ('custody_before_sha256', 'custody-before.json'), ('custody_after_sha256', 'custody-after.json')]:
    check(sha(ATTEMPT / name) == execution[field], 'original ' + name + ' hash')
for name, digest in execution['external_scripts_sha256'].items():
    check(sha(ORIGINALS / name) == digest, 'original external diagnostic hash: ' + name)
check((ATTEMPT / 'custody-before.json').read_bytes() == (ATTEMPT / 'custody-after.json').read_bytes(), 'original recorded custody unchanged')
terminal = [line.removeprefix('AMBIENT2_NATIVE_THIN ') for line in (ATTEMPT / 'console.log').read_text().splitlines() if line.startswith('AMBIENT2_NATIVE_THIN ')]
check(len(terminal) == 1, 'exactly one original terminal result')
terminal = json.loads(terminal[0])
check(all(terminal[key] == report[key] for key in terminal), 'terminal/report agreement')
check(report['physical_ticks'] == report['native_tick'] == report['actual_worlds'] == report['actual_actors'] == 1 and report['behavioral_episodes_added'] == 0, 'one native/physical tick, one real actor, zero behavioral episodes')

payload = (ATTEMPT / 'publication.cells.bin').read_bytes()
pub = report['publication']
check(len(payload) == pub['bytes'] == 131072 and pub['channels'] == 2, 'complete publication length and channel interpretation')
check(hashlib.sha256(payload).hexdigest() == pub['sha256'], 'publication report digest')
check(pub['rectangles'] == [0, 0, 256, 256, 0, 512], 'one complete non-overlapping publication rectangle')
positions = {str(material): [[i % 256, i // 256] for i, value in enumerate(payload[::2]) if value == material] for material in (3, 16)}
check(positions == {'16': [[129, 94]], '3': [[169, 94]]} == pub['verification_scan']['positions'], 'independent exhaustive native-ID payload scan')

pose = report['actor_observation']['centre']
parts = report['actor_observation']['parts']
check(len(parts) == 1 and all(p['shape'] == 'rectangle' and p['native_mask'] == 'matching_rectangle' and not p['detached'] for p in parts), 'copied shape and native-mask assumptions')
margins = {}
for label in ('near', 'far'):
    cell = report[label]['cell']
    check(positions[str(report[label]['material_id'])] == [cell], label + ' cell is the sole actual material location')
    point = [v + 0.5 for v in cell]
    distance = math.dist(pose, point)
    check(abs(distance - report[label]['distance_cells']) < 3e-6, label + ' independent center distance')
    margins[label] = []
    for part, recorded in zip(parts, report[label]['outside_parts'], strict=True):
        angle = part['rotation']
        u = (math.cos(angle), math.sin(angle))
        v = (-math.sin(angle), math.cos(angle))
        # Project all four corners of each polygon onto the four possible
        # separating axes, independently of the diagnostic's radius formula.
        hull = [(part['position'][0] + sx*part['size'][0]/2*u[0] + sy*part['size'][1]/2*v[0], part['position'][1] + sx*part['size'][0]/2*u[1] + sy*part['size'][1]/2*v[1]) for sx in (-1, 1) for sy in (-1, 1)]
        square = [(cell[0]+dx, cell[1]+dy) for dx in (0, 1) for dy in (0, 1)]
        separation = []
        for axis in ((1, 0), (0, 1), u, v):
            h = [x*axis[0]+y*axis[1] for x, y in hull]
            c = [x*axis[0]+y*axis[1] for x, y in square]
            separation.append(max(min(h)-max(c), min(c)-max(h)))
        margin = max(separation)
        check(margin > 0 and abs(margin-recorded['separating_axis_margin_cells']) < 1e-9, label + ' whole material cell lies outside complete copied hull')
        margins[label].append(margin)

coarse = {(x, y) for y in range(0, 256, 4) for x in range(0, 256, 4) if math.dist(pose, (x+0.5, y+0.5)) <= 50}
near = {(x, y) for y in range(256) for x in range(256) if math.dist(pose, (x+0.5, y+0.5)) <= 8}
patch = {(x, y) for y in range(92, 97) for x in range(127, 132)}
adaptive = coarse | near | patch
check(len(coarse) == 489 and len(near) == 194 and len(adaptive) == 677 and len(patch-(coarse|near)) == 4, 'independent admitted-site union and refinement counts')
check((129, 94) not in coarse and (129, 94) in adaptive and (169, 94) not in (coarse|adaptive), 'near thin feature gained; far thin feature remains unsampled')
profile_a = dict(report['profile'])
profile_c = dict(report['coarse_profile'])
check(profile_a.pop('perception') == {'spacing_cells':4,'near_radius_cells':8,'refine_boundaries':True} and profile_c.pop('perception') == {'spacing_cells':4,'near_radius_cells':0,'refine_boundaries':False} and profile_a == profile_c, 'only declared sensing settings differ')
for name, expected_sites in [('coarse', coarse), ('adaptive', adaptive)]:
    materials = report[name]['materials']
    check(materials['status'] == 'fresh' and materials['sample_count'] == len(expected_sites) and not materials['coverage_complete'] and not materials['budget_exhausted'], name + ' fresh bounded incomplete sensor result')
    check(materials['targets']['16']['present'] == (name == 'adaptive'), name + ' actual near Oil observation')
    target = materials['targets']['3']
    check(not target['present'] and target['status'] == 'unobserved_in_incomplete_coverage' and target['absence_scope'] == 'admitted_samples_only', name + ' far Water miss remains explicitly unknown')
    counts = report['warm_repeated_read_counts'][name]
    check(len(counts) == 100 and set(counts) == {len(expected_sites)}, name + ' repeated admitted read counts')

receipt = {
    'pass': True,
    'review_scope': 'Independent readback of original retained native bytes, original process/report chain, unchanged recorded custody, complete-cell hull separation, and sensor sample counts. No application execution and no behavioral episodes added.',
    'reviewer_source_sha256': sha(Path(__file__)),
    'frozen_application_source': SOURCE,
    'original_zip_sha256': sha(ARCHIVE),
    'original_report_sha256': sha(ATTEMPT / 'report.json'),
    'original_execution_sha256': sha(ATTEMPT / 'execution.json'),
    'checks': len(checks),
    'check_descriptions': checks,
    'actual_material_positions': positions,
    'whole_cell_separation_margin_cells': margins,
    'recomputed_sample_counts': {'coarse':len(coarse),'near_disk':len(near),'adaptive_union':len(adaptive),'refinement_new_reads':len(patch-(coarse|near))},
    'warm_owner_sensor_median_usec': {arm:statistics.median(samples) for arm, samples in report['warm_repeated_owner_sensor_usec'].items()},
    'warm_outer_call_median_usec': {arm:statistics.median(samples) for arm, samples in report['warm_repeated_query_elapsed_usec'].items()},
    'limits': ['Recorded custody is verified internally and against the frozen source identity; this readback does not recreate the original process or native World.', 'One near and one far thin cell establish these particular observations, not general complete coverage.', 'Warm repeated call timings are elapsed local measurements and do not establish production cadence, isolated CPU cost or real-device playfeel.']
}
(ROOT / 'independent-readback.json').write_text(json.dumps(receipt, indent=2)+'\n')
print(json.dumps({k:receipt[k] for k in ('pass','checks','whole_cell_separation_margin_cells','recomputed_sample_counts','warm_owner_sensor_median_usec','warm_outer_call_median_usec')}, indent=2))
