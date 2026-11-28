#!/usr/bin/env python3
"""Independent read-only joins of the retained third evaluator evidence."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--workspace-root', type=Path, default=Path('/workspace/scratch/0b2a9bdf7883'),
                    help='Root containing retained evidence-root and evidence-c directories')
parser.add_argument('--output', type=Path, help='New peer report path; defaults to evidence-c under workspace root')
args = parser.parse_args()
BASE = args.workspace_root.resolve()
E = BASE / 'evidence-root/final-03/evaluator-evidence/payload'
Q = BASE / 'evidence-root/final-03/evaluator-package/qualified'
OUT = args.output.resolve() if args.output else BASE / 'evidence-c/final03-evaluator-independent-peer-review.json'
C = 'c2f8a73d34448bc1496ecd84bca02f0812c80d27'
D = 'c90dbc46e1f57f28e06b1f4205b83467335ff657'

def need(value, label):
    if not value:
        raise ValueError(label)

def sha(data):
    return hashlib.sha256(data).hexdigest()

def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def load(path):
    return json.loads(path.read_bytes())

def norm(path):
    return str(path).replace('\\', '/')

def local(recorded):
    return E / norm(recorded).split('/build/pubpres-evaluator/', 1)[1]

def terminal(path, prefix):
    lines = [line[len(prefix):] for line in path.read_text().splitlines() if line.startswith(prefix)]
    need(len(lines) == 1, 'unique terminal ' + str(path))
    return json.loads(lines[0])

def owner(process, folder, *, ready):
    need(process['exit_code'] == 0 and process['termination_reason'] == 'completed', 'process outcome')
    need(all(process[k] is False for k in ['timed_out', 'cancelled', 'cancelled_or_failed']), 'process failure flags')
    need(process['readiness_observed'] is ready and not process['failure'] and not process['cleanup_failure'], 'process readiness/cleanup')
    observed = load(folder / 'process-owner.json')
    need(observed == process['ownership'], 'raw ownership join')
    need(observed['process_id'] == process['process_id'] and observed['root_exit_code'] == 0, 'owned actual PID')
    for key in ['creation_time_job_list', 'standard_handle_allowlist', 'kill_on_close', 'assigned_before_resume',
                'initial_thread_resumed', 'console_hook_installed', 'parent_exited_before_cleanup', 'cleanup_established']:
        need(observed[key] is True, 'owner invariant ' + key)
    for key in ['breakaway_allowed', 'cancellation_requested', 'had_survivors', 'zero_exit_with_descendants']:
        need(observed[key] is False, 'owner invariant ' + key)
    need(observed['active_before_cleanup'] == observed['active_after_cleanup'] == 0 and not observed['failure'], 'empty owned process tree')
    need(process['process_owner_sha256'] == digest(Q / 'tools/pubpres_playability_windows/process_owner.cs'), 'process-owner source')
    samples = load(folder / 'process-memory.json')
    need(len(samples) == process['samples'] > 0, 'memory sample count')
    need(all(s['pid'] == process['process_id'] for s in samples), 'memory PID join')
    need(all(a['elapsed_ms'] < b['elapsed_ms'] and a['cpu_ms'] <= b['cpu_ms'] for a,b in zip(samples,samples[1:])), 'memory/CPU monotonic clocks')


manifest_path = Q / 'PUBPRES-PLAYABILITY-MANIFEST.json'
m = load(manifest_path)
ms = digest(manifest_path)
need(ms == '0288861763665cd40f2b3c950536d5aa3ccb6ffa2ad60420b6e2b7b230b56abe', 'exact package manifest')
need(m['candidate_commit'] == C and m['physical_acceptance'] == 'HOLD' and m['production_defaults_changed'] is False, 'package authority')
need(m['patched_engine'] is None and m['defaults'] == {'engine':'stock','full_image_slots':2,'material':'full','render_thread':'safe','same_frame_continuation':'off','scene':'ordinary','source':'C'}, 'ordinary defaults')
for source, commit in [('C', C), ('D', D)]:
    need(m['sources'][source]['source_commit'] == commit, 'source identity')
    for kind in ['native', 'rapier']:
        rec = m['sources'][source][kind]
        need(digest(Q / rec['path']) == rec['sha256'] and (Q / rec['path']).stat().st_size == rec['bytes'], 'actual runtime bytes')
need(digest(Q / m['engine']['gui']['path']) == m['engine']['gui']['sha256'], 'actual GUI bytes')
summary = load(E / 'checks/SUMMARY.json')
need(summary['complete'] is True and summary['failure'] is None and summary['candidate'] == C, 'launch summary')
need(len(summary['checks']) == 10 and all(x['passed'] is True for x in summary['checks']), 'ten extraction/refusal/collector checks')
expected_labels = ['ordinary-open','ordinary-reopen','mixed2048','wave1024','wave2048','wave512','donor-ordinary-open','donor-ordinary-reopen','explicit-three-slots']
need([x['label'] for x in summary['launches']] == expected_labels, 'all nine registered startup launches')
launches = []
for row in summary['launches']:
    path = local(row['receipt'])
    d = load(path)
    runpath = path.parents[2] / 'run.json'
    run = load(runpath)
    source = m['sources'][row['source']]
    p = load(path.parent / 'process.json')
    need(digest(path) == row['receipt_sha256'], 'startup bytes ' + row['label'])
    need(d == terminal(path.parent / 'stdout.log', 'PUBPRES_PLAYABILITY_OWNER_READY '), 'actual emitted startup')
    need(d['source_commit'] == row['source_commit'] == source['source_commit'] == p['source_commit'] == run['source_commit'], 'startup source join')
    need(d['process_id'] == row['pid'] == p['process_id'], 'startup PID join')
    need(d['ready'] is True and d['schema'] == 'pubpres-final-owner-start-v1' and d['physical_acceptance'] == 'HOLD', 'startup receipt authority')
    need(d['engine_sha256'] == row['engine_sha256'] == m['engine']['gui']['sha256'] and d['native_sha256'] == source['native']['sha256'] and d['rapier_sha256'] == source['rapier']['sha256'], 'startup runtime join')
    need(d['observer_sha256'] == digest(Q / m['owner_observer']), 'actual source-bound startup observer')
    need(d['main_sha256'] == digest(Q / source['project'] / 'scripts/main.gd') and d['project_sha256'] == digest(Q / source['project'] / 'project.godot'), 'actual project/main source')
    need(d['render_driver'] == 'opengl3_angle' and d['render_thread_inline'] is True and 'Microsoft Basic Render Driver' in d['adapter'], 'actual hosted rendering owner')
    need(d['material_publication'] == row['material'] and d['material_publication']['backend'] == 'full' and d['material_publication']['requested_mode'] == 'full', 'actual Full publication')
    need(d['same_frame_continuation']['enabled'] is False and d['same_frame_continuation']['new_physics_callbacks'] == 0 and d['same_frame_continuation']['wait_usec'] == 0, 'no continuation credit')
    need(d['scene'] == row['scene'] == run['scene'] and run['package_manifest_sha256'] == ms and run['candidate_commit'] == C, 'launch scene/run custody')
    need(run['settings']['CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ'] == '0', 'requested disabled deadline')
    if row['source'] == 'C':
        st = d['material_deadline']
        need(st['enabled'] is False and st['physical_credit'] is False and st['requested_hz'] == st['interval_usec'] == 0, 'live deadline disabled')
        need(all(st[k] == 0 for k in ['accepted_uploads','cancellations','consumptions','offers','pending_count','replaced_offers']), 'zero deadline activity')
        need(all(st[k] == -1 for k in ['deadline_usec','next_upload_usec','pending_generation','pending_serial']), 'no hidden pending deadline')
    else:
        need(d['material_deadline'] is None, 'donor absent deadline explicit')
    prefix = source['root'] + '/'
    # Launcher source ledger intentionally excludes Godot's regenerated import
    # cache. These are exactly the three portable bootstrap entries in package.
    bootstrap = {k[len(prefix):] for k in m['files_sha256'] if k.startswith(prefix+'godot/.godot/')}
    need(bootstrap == {'godot/.godot/.gdignore','godot/.godot/extension_list.cfg','godot/.godot/global_script_class_cache.cfg'}, 'only declared portable bootstrap exclusions')
    projected = {k[len(prefix):]:v for k,v in m['files_sha256'].items() if k.startswith(prefix) and k[len(prefix):] not in bootstrap}
    projected['godot/tests/pubpres_playability_owner_start.gd'] = digest(Q / m['owner_observer'])
    projected['godot/override.cfg'] = d['override_sha256']
    need(run['files_sha256'] == projected, 'entire per-launch source projection')
    need(d['override_sha256'] == 'a2ba52038035d59f4e02f5d0b59315284830d6cd4978fe4752b6ed921dc5e1e5', 'registered override')
    owner(p, path.parent, ready=True)
    command = [norm(x) for x in p['command']]
    project = norm(row['receipt']).rsplit('/launches/',1)[0] + '/source/godot'
    need(command == [command[0],'--path',project,'--rendering-method','gl_compatibility','--rendering-driver','opengl3_angle','--render-thread','safe','--audio-driver','Dummy','--script','res://tests/pubpres_playability_owner_start.gd'], 'exact GUI command')
    need(command[0].endswith('/checks/extracted/' + m['engine']['gui']['path']), 'shipped GUI command')
    impfolder = path.parent.with_name(path.parent.name + '-import')
    imp = load(impfolder / 'process.json')
    owner(imp, impfolder, ready=False)
    need([norm(x) for x in imp['command']] == [command[0],'--headless','--path',project,'--editor','--import','--audio-driver','Dummy','--quit'] and imp['source_commit'] == source['source_commit'], 'exact import command/source')
    if row['scene'] != 'ordinary':
        size = 1024 if row['scene'] == 'wave1024' else (512 if row['scene'] == 'wave512' else 2048)
        need(d['extent'] == [size,size] and d['authored_actor_count'] == (4 if row['scene'] in ['mixed2048','wave1024'] else 1), 'representative actual scene/actors')
    if row['scene'] == 'mixed2048':
        need(d['scene_material_witness']['observed_material'] == 2, 'actual authored Sand witness')
    slots = 3 if row['label'] == 'explicit-three-slots' else 2
    need(run['full_image_slots'] == slots, 'registered slot selection')
    if row['source'] == 'C':
        need(d['material_publication']['full_image_slots'] == slots, 'actual slot selection')
    launches.append({'label':row['label'],'source':row['source'],'scene':row['scene'],'pid':p['process_id'],'native_tick':d['native_tick'],'startup_sha256':digest(path),'process_sha256':digest(path.parent/'process.json'),'run_sha256':digest(runpath),'source_files':len(projected),'native_sha256':d['native_sha256'],'actual_render_owner':'safe','render_driver':'opengl3_angle','physical_acceptance':'HOLD'})
for labels in [('ordinary-open','ordinary-reopen'),('donor-ordinary-open','donor-ordinary-reopen')]:
    a,b = [x for x in launches if x['label'] in labels]
    need(a['pid'] != b['pid'] and a['run_sha256'] == b['run_sha256'], 'fresh process same run/profile reopen')

tests = load(E / 'checks/process-owner/process-owner-tests.json')
need(tests['failures'] == [] and tests['powershell'] == '5.1.20348.5773', 'actual PS5.1 owner controls')
need(tests['helper_sha256'] == digest(Q / 'tools/pubpres_playability_windows/process_owner.cs'), 'owner control source')
for case in tests['checks']:
    need(case['passed'] is True and case['ownership']['cleanup_established'] is True and case['ownership']['active_after_cleanup'] == 0, 'negative owner cleanup')
    folder = E / 'checks/process-owner' / case['case'] / 'process'
    need(load(folder / 'process-owner.json') == case['ownership'], 'negative owner raw join')
    if case['case'] != 'clean-zero-exit':
        need(case['refused'] is True and case['leaf_exited'] is True, 'actual orphan/timeout/cancel refusal')
for case in tests['json_array_writer']:
    p = E / 'checks/process-owner' / case['path']
    need(case['passed'] is True and digest(p) == case['sha256'] and len(load(p)) == case['expected_samples'], 'actual empty/single/multiple array serialization')

archive = next((E / 'checks/Runs/Reports').glob('*.zip'))
need(digest(archive) == '4a4288a38c28af284a831e3eb5d734ffd1043c422b2f3c55021afb9ac80af008', 'actual collector archive bytes')
with zipfile.ZipFile(archive) as z:
    index = json.loads(z.read('INDEX.json'))
    need(index['candidate_commit'] == C and index['package_manifest_sha256'] == ms and index['physical_acceptance'] == 'HOLD' and index['omitted'] == [], 'collector identity/omissions')
    need(set(z.namelist()) == {x['file'] for x in index['files']} | {'INDEX.json'} and len(z.namelist()) == len(set(z.namelist())) == 126, 'complete unique collector archive')
    total, duplicate_joins, profile_logs = 0, 0, []
    for record in index['files']:
        data = z.read(record['file'])  # verifies member CRC
        need(sha(data) == record['sha256'] and len(data) == record['bytes'], 'collector CRC/hash/size')
        actual = manifest_path if record['file'] == manifest_path.name else E / 'checks/Runs' / record['file'].removeprefix('runs/')
        if actual.exists():
            need(actual.read_bytes() == data, 'collector actual retained evidence join')
            duplicate_joins += 1
        else:
            need('/profile/APPDATA/Godot/app_userdata/Cyber Sand Reference Sandbox/logs/' in record['file'] and record['file'].endswith('.log'), 'only collector-owned profile log absence')
            terminal_lines = [line.split('PUBPRES_PLAYABILITY_OWNER_READY ',1)[1] for line in data.decode('utf-8').splitlines() if 'PUBPRES_PLAYABILITY_OWNER_READY ' in line]
            need(len(terminal_lines) == 1, 'collector profile log actual startup terminal')
            startup = json.loads(terminal_lines[0])
            match = [row for row in summary['launches'] if row['pid'] == startup['process_id']]
            need(len(match) == 1 and startup == load(local(match[0]['receipt'])), 'collector-only log independently joins exact process startup')
            profile_logs.append({'file':record['file'],'sha256':record['sha256'],'pid':startup['process_id']})
        total += len(data)
    need(total == index['total_bytes'] and len(index['matched_runs']) == 7, 'bounded collector totals')
    need(duplicate_joins == 116 and len(profile_logs) == len({x['pid'] for x in profile_logs}) == 9, 'all collector evidence and profile log joins')

auth = load(E / 'authoring/SUMMARY.json')
need(auth['complete'] is True and auth['failure'] is None and auth['candidate'] == C and auth['manifest_sha256'] == ms, 'installed authoring summary')
authrows = []
for n, name in enumerate(['import','author','reopen']):
    folder = E / 'authoring' / name
    p = load(folder / 'process.json')
    # run_regressions writes the import process receipt before its caller adds
    # validation_errors to the summary. All original process fields must match.
    if name == 'import':
        need(set(auth['outcomes'][n]) - set(p) == {'validation_errors'} and auth['outcomes'][n]['validation_errors'] == [], 'only declared post-import validation addition')
        need(all(auth['outcomes'][n][k] == v for k,v in p.items()), 'raw import process join')
    else:
        need(p == auth['outcomes'][n] and p['validation_errors'] == [], 'raw authoring outcome')
    need(p['returncode'] == 0 and p['timed_out'] is False, 'authoring process success')
    need(digest(folder / 'stdout.log') == p['log_sha256'], 'authoring log bytes')
    command = [norm(x) for x in p['command']]
    suffix = ['--headless','--editor','--import','--quit'] if name == 'import' else ['--rendering-method','gl_compatibility','--rendering-driver','opengl3_angle','--render-thread','safe','--script','res://tests/pubpres_final_authoring.gd']
    need(command == [command[0],'--path',command[2],'--audio-driver','Dummy',*suffix] and command[0].endswith('/checks/extracted/'+m['engine']['gui']['path']) and command[2].endswith('/authoring/source/godot'), 'actual authoring command')
    if name == 'import':
        continue
    raw = terminal(folder / 'stdout.log', 'WB_COMBINED_EVIDENCE ')
    need(raw['schema'] == 'workbench-combined-authoring-v2' and raw['failures'] == [] and raw['checks'] == (208 if name == 'author' else 65), 'actual functional checks')
    need(raw['prepared_sha256'] == p['authoring_evidence']['prepared_sha256'] == '3f36a472fc70c61c9df71f965f6d5ba061ede71633fb79af31ea6fc9c203be2e', 'whole prepared native material join')
    need(raw['source_identity'] == p['authoring_evidence']['source_identity'] and raw['phases'] == p['authoring_evidence']['phases'], 'actual authoring receipt join')
    for key, value in raw['source_identity'].items():
        if key.startswith(('scripts/','tests/')):
            target = Q / m['sources']['C']['project'] / key
            if key == 'tests/pubpres_final_authoring.gd':
                target = Q / 'tools/pubpres_final_windows/authoring.gd'
            need(digest(target) == value, 'authoring source closure ' + key)
    for state in raw['same_frame_continuation']['before'],raw['same_frame_continuation']['after']:
        need(state['status']['enabled'] is False and state['status']['new_physics_callbacks'] == 0 and state['material']['backend'] == 'full' and state['material']['full_image_slots'] == 2, 'authoring actual unchanged policy')
    for image, expected in p['authoring_evidence']['screenshots_sha256'].items():
        data = (folder / 'screenshots' / image).read_bytes()
        need(sha(data) == expected and data[:8] == b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',data[16:24]) == (1440,810), 'actual authored framebuffer bytes')
    authrows.append({'phase':name,'checks':raw['checks'],'log_sha256':p['log_sha256'],'process_sha256':digest(folder/'process.json'),'prepared_sha256':raw['prepared_sha256'],'phases':raw['phases'],'screenshots_sha256':p['authoring_evidence']['screenshots_sha256']})

expect_path = next((E / 'authoring/profile').rglob('wb-combined-native-expectation.json'))
expect = load(expect_path)
saved_path = next((E / 'authoring/profile').rglob('setup-wb-combined-generated-acceptance.json'))
saved = load(saved_path)
need(saved['format'] == 'cybersand-generated-start-v1' and saved['version'] == 1 and saved['generation'] == expect['generation'], 'saved generated start')
for key in ['actors','brush','edits','equipment','liquid_policy','response','rule_radius','selected']:
    need(saved['starting_setup'][key] == expect[key], 'saved authored value ' + key)
need(expect['prepared_sha256'] == authrows[0]['prepared_sha256'] and len(expect['author_instance']) == 32
     and type(expect['author_pid']) in (int,float) and expect['author_pid'] > 0 and expect['author_pid'] % 1 == 0,
     'fresh author/reopen identity and material')
audit = expect_path.parent / expect['closed_art_audit']['path'].removeprefix('user://')
need(digest(audit) == expect['closed_art_audit']['sha256'], 'closed authoring traffic audit preserved after reopen')

report = {'schema':'pubpres-final03-evaluator-independent-peer-review-v1','complete':True,'application_source':C,'application_tree':m['sources']['C']['source_tree'],'package_manifest_sha256':ms,'engine':m['engine'],'sources':{k:{'source':v['source_commit'],'native_sha256':v['native']['sha256'],'rapier_sha256':v['rapier']['sha256']} for k,v in m['sources'].items()},'launches':launches,'process_owner_controls':{'tests_sha256':digest(E/'checks/process-owner/process-owner-tests.json'),'powershell':tests['powershell'],'cases':[x['case'] for x in tests['checks']],'all_raw_ownership_and_array_joins_passed':True},'collector':{'archive_sha256':digest(archive),'indexed_files':len(index['files']),'archive_members':126,'indexed_bytes':total,'matched_runs':7,'omissions':[],'all_CRC_SHA_size_and_retained_bytes_joins_passed':True},'authoring':authrows,'save_reopen':{'expectation_sha256':digest(expect_path),'saved_start_sha256':digest(saved_path),'prepared_sha256':expect['prepared_sha256'],'closed_audit_sha256':digest(audit),'author_pid':expect['author_pid'],'author_instance':expect['author_instance']},'independent_scope':['Actual raw nine startup receipts and exact GUI/import commands joined to packaged source/runtime and seven run manifests','Creation-time Job ownership, cleanup, memory PID joins and four retained negative-control outcomes','Collector member CRC/hash/size and all125 actual retained evidence bytes','Real installed authoring and fresh-process reopen terminal results, source scripts, saved start and full prepared native-material digest','Retained framebuffer dimensions/hash; two representative stills separately visually inspected'],'limitations':['Hosted smoke commands selected ANGLE on Microsoft Basic Render Driver; default WGL and physical NVIDIA remain unqualified.','Startup native_tick=0 is not physical progression or sustained playability evidence.','Static screenshots cannot establish input latency, temporal trails or pose freshness.','Authoring uses a deterministic provider fixture; it is not live model-provider qualification.','Authoring wrapper records continuation/full2 policy; deadline-off follows cleared environment and source default, whereas nine startup receipts separately observe live disabled deadline status.','Root separately verified full package ZIP/source projections; this peer report consumes and independently checks raw process/collector/authoring joins rather than claiming a new native build.'],'physical_acceptance':'HOLD'}
report['audit_program_sha256'] = digest(Path(__file__))
report['workspace_root'] = str(BASE)
report['collector'].pop('all_CRC_SHA_size_and_retained_bytes_joins_passed')
report['collector'].update(all_member_CRC_SHA_size_checks_passed=True,
                         exact_duplicate_evidence_file_joins=duplicate_joins,
                         collector_only_profile_logs=profile_logs,
                         collector_only_log_terminals_join_all_nine_actual_startups=True)
report['independent_scope'][2] = 'All125 collector member CRC/hash/size checks,116 duplicate evidence byte joins and9 collector-only profile log terminals joined to actual startup receipts'
OUT.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'complete':True,'output':str(OUT),'sha256':digest(OUT),'launches':len(launches),'collector_files':len(index['files']),'functional_checks':[x['checks'] for x in authrows]}))
