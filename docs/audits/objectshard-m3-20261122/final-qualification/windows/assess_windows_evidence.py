"""Read-only assessment of downloaded exact-source Windows qualification evidence."""
from __future__ import annotations
import argparse
import hashlib
import json
import subprocess
import sys
import zipfile
from pathlib import Path

SOURCE = 'e034f2294663e0485cfb9adcc8ada46a6e977cee'
TREE = '246e7324ca618d98c43a0ed54fe19bc86a155877'
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools/objectshard'))
import qualify_lab
RAPIER = 'b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7'

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--evidence', type=Path, required=True)
    p.add_argument('--owner-zip', type=Path)
    p.add_argument('--candidate', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    result = {'schema': 'objectshard-m3-repair-windows-delivery-assessment-v1', 'source_commit': SOURCE,
              'source_tree': TREE, 'failures': [], 'scope': 'Downloaded actual Windows qualification and immutable delivered ZIP evidence; no local Windows or physical GPU acceptance claim.'}
    def require(ok, message):
        if not ok:
            result['failures'].append(message)
    def read(relative):
        path = args.evidence / relative
        if not path.is_file():
            result['failures'].append('Missing evidence: ' + relative)
            return {}
        return json.loads(path.read_text(encoding='utf-8'))
    candidate = json.loads(args.candidate.read_text())
    require(candidate.get('source_commit') == SOURCE and candidate.get('build_commit') == SOURCE and candidate.get('source_tree') == TREE, 'Fresh compiled candidate source identity')
    require(candidate.get('kind') == 'source-built-windows-candidate', 'Source-built Windows candidate receipt required')
    native_hash = candidate['sha256']
    result['candidate_provenance'] = {'path': str(args.candidate), 'sha256': hashlib.sha256(args.candidate.read_bytes()).hexdigest(), 'native_sha256': native_hash, 'source_commit': candidate.get('source_commit')}
    for directory in ['windows-lab', 'package-replay']:
        q = read(directory + '/qualification.json')
        require(q.get('status') == 'passed', directory + ' did not pass')
        require(q.get('source_commit') == SOURCE and q.get('source_tree') == TREE, directory + ' source identity')
        require(q.get('runtime', {}).get('native_sha256') == native_hash, directory + ' fresh native hash')
        require(q.get('runtime', {}).get('rapier_sha256') == RAPIER, directory + ' selected Rapier hash')
        cases = q.get('cases', [])
        names = {x.get('name') for x in cases}
        require(len(cases) == (41 if directory == 'windows-lab' else 32), directory + ' exact expanded case count')
        require(all(x.get('status') == 'passed' for x in cases), directory + ' individual case status')
        require(not q.get('failures'), directory + ' recorded failures')
        input_counts = {}
        for category in ('native_source_inputs', 'lab_source_inputs', 'qualification_tool_inputs'):
            values = q.get(category, {})
            require(bool(values), directory + ' missing source inputs: ' + category)
            for name, expected in values.items():
                committed = subprocess.check_output(['git', '-C', str(ROOT), 'show', SOURCE + ':' + name])
                require(hashlib.sha256(committed).hexdigest() == expected, directory + ' source input mismatch: ' + name)
            input_counts[category] = len(values)
        require('godot/scripts/feature_navigation.gd' in q.get('lab_source_inputs', {}), 'Navigation autoload omitted from source binding')
        nav = read(directory + '/worker-navigation.json')
        nav_validation = qualify_lab.validate_navigation_receipt(nav, SOURCE)
        child = read(directory + '/worker-navigation-quit-child.json')
        require(child.get('schema') == 'objectshard-worker-navigation-quit-child-v1' and child.get('source_revision') == SOURCE and child.get('checks') == 18 and child.get('failures') == 0, directory + ' actual child sidecar')
        for case in cases:
            path = args.evidence / directory / case.get('log', '')
            require(path.is_file(), directory + ' missing actual case log: ' + str(case.get('name')))
            if path.is_file() and case.get('log_sha256'):
                require(hashlib.sha256(path.read_bytes()).hexdigest() == case['log_sha256'], directory + ' actual case log hash: ' + str(case.get('name')))
        required = {'objectshard_worker_navigation', 'objectshard_worker_recovery', 'objectshard_worker_replay_admission',
                    'objectshard_continuous_play', 'objectshard_continuous_replay',
                    'objectshard_continuous_physics', 'objectshard_worker_scene', 'objectshard_worker_replay'}
        require(required <= names, directory + ' required M3 case inventory')
        result[directory] = {'source_input_counts': input_counts, 'navigation_lifecycle': nav_validation, 'case_count': len(cases), 'cases': [
            {'name': x.get('name'), 'status': x.get('status'),
             'checks': x.get('completion_receipt', {}).get('checks'),
             'failures': x.get('completion_receipt', {}).get('failures'),
             'budget': x.get('budget_qualification')} for x in cases],
             'scheduling_comparison': q.get('worker_scheduling_comparison')}
        if directory == 'windows-lab':
            require({'objectshard_continuous_play_rendered', 'objectshard_continuous_rendered_replay', 'objectshard_worker_render'} <= names,
                    'Windows actual rendered case inventory')
            timing = next((x.get('rendered_ui_timing') for x in cases if x.get('name') == 'objectshard_continuous_play_rendered'), None)
            require(bool(timing), 'Actual rendered UI timing is absent')
            result['rendered_ui_timing'] = timing
        long = read(directory + '/continuous-physics.json')
        require(long.get('failures') == 0 and long.get('tick') == 3600, directory + ' 3600 tick endpoint')
        require(long.get('moving_owners') == 3 and long.get('sleeping_owners') == 3 and long.get('actions_queued', 0) >= 300,
                directory + ' long run must contain live motion, natural sleep and many edits')
        result[directory]['long_play'] = {key: long.get(key) for key in ['checks', 'tick', 'completed_ticks', 'actions_queued',
             'moving_owners', 'sleeping_owners', 'maximum_displacements', 'physics_steps', 'real_contacts',
             'fire_seen', 'smoke_seen', 'post_settle_edit_tick', 'post_erosion_maximum_rotation', 'post_erosion_maximum_translation', 'timing']}
    matrix = read('launcher-matrix/result.json')
    require(matrix.get('status') == 'passed', 'Delivered Windows launch matrix did not pass')
    rows = matrix.get('cases', [])
    require({x.get('case') for x in rows} == {'spaces', 'parentheses', 'nested', 'unicode'}, 'Missing extracted path case')
    for row in rows:
        require(row.get('source_commit') == SOURCE and len(row.get('commands', [])) == 3, 'Incomplete launch/verify case ' + str(row.get('case')))
        require(all(x.get('exit_code') == 0 for x in row.get('commands', [])), 'Launch failure ' + str(row.get('case')))
        require(row.get('preflight_launch_receipt', {}).get('failures') == 0, 'M3 launch receipt failed ' + str(row.get('case')))
    adversaries = next((x.get('verifier_adversaries', {}) for x in rows if x.get('case') == 'spaces'), {})
    require(adversaries.get('specific_hash_failure_observed') is True and adversaries.get('after_restoration_inventory_verified') is True,
            'Specific immutable-package tamper refusal or restoration evidence missing')
    result['launcher_matrix'] = matrix
    campaign = read('windows-lab/frames-worker/render-campaign.json')
    require(campaign.get('failures') == 0 and campaign.get('captures') == 7, 'Seven distinct real M3 screenshots not established')
    pictures = []
    for row in campaign.get('observations', []):
        path = args.evidence / 'windows-lab/frames-worker' / row.get('image', '')
        require(row.get('premise_passed') is True, 'Physical screenshot premise failed: ' + str(row.get('image')))
        require(path.is_file() and path.read_bytes()[:8] == b'\x89PNG\r\n\x1a\n', 'Missing PNG: ' + str(path))
        if path.is_file():
            pictures.append({'image': str(path), 'sha256': hashlib.file_digest(path.open('rb'), 'sha256').hexdigest(),
                             'preset': row.get('preset'), 'detail': row.get('detail')})
    require(len({x['image'] for x in pictures}) == 7, 'Screenshot filenames must be distinct')
    result['screenshots'] = pictures
    if args.owner_zip:
        with args.owner_zip.open('rb') as f:
            digest = hashlib.file_digest(f, 'sha256').hexdigest()
        require(digest == matrix.get('zip_sha256'), 'Owner ZIP differs from actual launched archive')
        result['owner_zip'] = {'path': str(args.owner_zip.resolve()), 'bytes': args.owner_zip.stat().st_size, 'sha256': digest}
        with zipfile.ZipFile(args.owner_zip) as zipped:
            names = [m.filename for m in zipped.infolist() if not m.is_dir()]
            require(len(names) == len(set(x.casefold() for x in names)), 'ZIP member names collide')
            manifest = json.loads(zipped.read('objectshard-lab-manifest.json'))
            require(manifest.get('source_commit') == SOURCE and manifest.get('source_tree') == TREE, 'Immutable ZIP manifest source identity')
            inventory = manifest.get('files_sha256', {})
            require(bool(inventory), 'Immutable ZIP member inventory missing')
            for member, expected in inventory.items():
                with zipped.open(member) as stream:
                    actual = hashlib.file_digest(stream, 'sha256').hexdigest()
                require(actual == expected, 'Immutable ZIP member hash: ' + member)
            required_scripts = ['godot/scripts/feature_navigation.gd', 'godot/scripts/object_shard_worker_rehearsal.gd',
                                'godot/tests/test_object_shard_worker_navigation.gd']
            for member in required_scripts:
                committed = subprocess.check_output(['git', '-C', str(ROOT), 'show', SOURCE + ':' + member])
                require(zipped.read(member) == committed, 'Repair source differs inside owner ZIP: ' + member)
            guide = subprocess.check_output(['git', '-C', str(ROOT), 'show', SOURCE + ':docs/operations/objectshard-m3-preflight-playtest.md'])
            require(zipped.read('READ-ME.md') == guide, 'Delivered owner guide is not the repaired source guide')
            require('Open ObjectShard Lab.cmd' in inventory and 'Open ObjectShard M3 Preflight.cmd' in inventory,
                    'Both ordinary and M3 launch shortcuts must remain')
            result['owner_zip']['verified_manifest_member_count'] = len(inventory)
            result['owner_zip']['manifest_sha256'] = hashlib.sha256(zipped.read('objectshard-lab-manifest.json')).hexdigest()
            result['owner_zip']['repaired_navigation_scripts_match_commit'] = True
            result['owner_zip']['source_guide_matches'] = True

    result['status'] = 'passed' if not result['failures'] else 'failed'
    args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(json.dumps({'status': result['status'], 'failures': result['failures'], 'source': SOURCE}))
    raise SystemExit(0 if result['status'] == 'passed' else 1)

if __name__ == '__main__':
    main()
