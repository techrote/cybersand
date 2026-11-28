"""Read-only, source-bound audit of the new full hosted physical programme.

Uses the unchanged, SHA-pinned frozen reducer and independent reader. All
runtime claims come from retained original receipts, never this local checkout.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import sys
import zipfile

SOURCE = '50c6df89528dc9ecdc5316d8c67abf203e192254'
TREE = 'd9740be7cafb8ac7b7d6eee4a16219989745fd95'
BASELINE = 'a7250e15495667b2fcf564cbed1eaa8dea217c45'
BASELINE_ARTIFACT_SHA = 'eac23768f3b18dc95a35554328f700daa8a81fa9920bab39fa7148aca1958e30'
ENGINE = 'f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75'
TOOLS = {
    'run_episodes.py':'5fe1e7cd6e2c7ac03d4e03ddc3175f82436e2f1dc36817754f6db8f21572b62c',
    'analyze_episodes.py':'9f7b72d6976b28888e8e7423b048d8a771a576bdb14197af6aae41a34b0e7301',
    'review_episodes.py':'c2e0608aff1eebd6a656ace312b6ff41f2fba4d1f0940c2a5219dddb9d55801f',
}
ALLOWED = {
    'scripts/ambient/ambient_engine.gd':('68081cf688e329284a3eed6dafbc136c04f66699', 'a406e33433327229c077dc8cfdb065196c4eecea70a51752c2cc9120adc60ab7'),
    'tests/test_ambient_living_engine.gd':('33248ba63eb849f4654982b52dd008741fbd170c','a48857d610fe2a630e3a5e3ee6fc1f4319847c5809325cdad5c595a72768fee2'),
    'scripts/ambient/ambient_profile_editor.gd':('0193879f2232de2659af5734a9aeb9be74577385', None),
}
SOURCE_ONLY = {'tools/fixtures/ambient-002-qualification-request.json':'d474b02bcc32f089fe9e5d01288570322028f0c9'}

def sha(data):
    return hashlib.sha256(data).hexdigest()

def stream_sha(stream):
    h = hashlib.sha256()
    while block := stream.read(65536):
        h.update(block)
    return h.hexdigest()

def file_sha(path):
    with Path(path).open('rb') as stream:
        return stream_sha(stream)

def member_sha(z, path):
    with z.open(path) as stream:
        return stream_sha(stream)

def read(z, path):
    with z.open(path) as stream:
        return json.load(stream)

def git_blob(data):
    return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()

class Console:
    def __init__(self, name, data):
        self.name, self.data = name, data
    def read_text(self, **kwargs):
        return self.data.decode('utf-8', errors='replace')
    def __str__(self):
        return self.name

def headings(row):
    return sum(a['has_procedural_intent'] and b['has_procedural_intent']
               and a['intent_pace']>.05 and b['intent_pace']>.05
               and abs(a['intent_direction'][0])>.05 and abs(b['intent_direction'][0])>.05
               and a['intent_direction'][0]*b['intent_direction'][0]<0
               for a,b in zip(row['trace'], row['trace'][1:]))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--artifact', type=Path, required=True)
    parser.add_argument('--artifact-sha256', required=True)
    parser.add_argument('--artifact-id', type=int, required=True)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--tools-root', type=Path, required=True)
    parser.add_argument('--published-inputs', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    assert file_sha(args.artifact) == args.artifact_sha256
    assert file_sha(args.baseline) == BASELINE_ARTIFACT_SHA
    tool_root = args.tools_root / 'tools/ambient'
    for name,expected in TOOLS.items():
        assert file_sha(tool_root/name) == expected, name
    sys.path.insert(0, str(tool_root))
    import run_episodes as runner
    import analyze_episodes as reducer
    import review_episodes as independent
    replacements = {}
    for path,(blob,expected) in ALLOWED.items():
        data = (args.published_inputs/'godot'/path).read_bytes()
        assert git_blob(data) == blob, path
        actual = sha(data)
        assert expected is None or actual == expected, path
        replacements[path] = actual
    source_only = {}
    for path,blob in SOURCE_ONLY.items():
        data = (args.published_inputs/path).read_bytes()
        assert git_blob(data) == blob, path
        source_only[path] = sha(data)
    out = args.output
    out.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.artifact) as z, zipfile.ZipFile(args.baseline) as base:
        assert len(z.namelist()) == len(set(z.namelist())), 'Duplicate archive member'
        assert z.testzip() is None, 'Original artifact CRC mismatch'
        receipt = read(z, 'episodes-full/runner-receipt.json')
        custody = read(z, 'episodes-full/custody.json')
        prior = read(base, 'episodes-full/custody.json')
        assert prior['source']['source_commit'] == BASELINE
        assert receipt['complete'] and receipt['campaigns']==122 and receipt['actual_actor_episodes']==194
        assert receipt['source_revision'] == custody['source']['source_commit'] == SOURCE
        assert receipt['source_tree'] == custody['source']['source_tree'] == TREE
        assert not custody['source']['local_delta']
        assert receipt['godot_sha256'] == custody['engine']['sha256'] == prior['engine']['sha256'] == ENGINE
        assert custody['runtime'] == prior['runtime'], 'Native/Rapier provenance changed'
        assert custody['experiment_tools_sha256'] == prior['experiment_tools_sha256']
        current_project, prior_project = custody['loaded_project_sha256'], prior['loaded_project_sha256']
        assert set(current_project) == set(prior_project)
        changed = {p for p in current_project if current_project[p] != prior_project[p]}
        assert changed == set(ALLOWED), ('Unapproved loaded-project delta', sorted(changed))
        assert all(current_project[p] == h for p,h in replacements.items())
        source_map, old_source_map = custody['source']['source_inputs_sha256'], prior['source']['source_inputs_sha256']
        assert set(source_map) == set(old_source_map), 'Qualified source inventory changed'
        source_changes = {p for p in source_map if source_map[p] != old_source_map[p]}
        assert source_changes == {'godot/'+p for p in ALLOWED} | set(SOURCE_ONLY), sorted(source_changes)
        for p,digest in replacements.items():
            assert source_map['godot/'+p] == digest
        assert all(source_map[p] == h for p,h in source_only.items())
        qualifications = []
        assert file_sha(args.tools_root/'tools/qualify_ambient_living.py') == source_map['tools/qualify_ambient_living.py']
        qualification = runner.qualification
        headless_completions = []
        graphical_readback = None
        for name in ['ambient/qualification.json', 'ambient-graphical/qualification.json']:
            q = read(z, name)
            assert q['status']=='passed' and q['input_custody']=='passed' and not q['local_delta']
            assert q['source_commit']==SOURCE and q['source_tree']==TREE
            assert q['source_inputs_sha256']==source_map
            assert q['project_inputs_sha256']==current_project and q['runtime']==custody['runtime']
            assert q['godot']['sha256']==ENGINE
            qualifications.append({'path':name,'sha256':member_sha(z,name),'cases':len(q['cases'])})
            folder = name.rsplit('/',1)[0]
            stages = [('import',q['import'])]+[(v['name'],v) for v in q['cases']]
            if name.startswith('ambient/'):
                assert q['complete_campaign'] is True
                assert len(q['cases']) == len({v['name'] for v in q['cases']}) == 24
                assert {v['name'] for v in q['cases']} == {v[0] for v in qualification.CASES}
            else:
                stages.append(('graphical',q['graphical']['process']))
            for stage,record in stages:
                prefix = folder+'/'+stage+'/'
                assert record['process_sha256'] == member_sha(z,prefix+'process.json')
                assert record['log_sha256'] == member_sha(z,prefix+'process.log')
                process = read(z,prefix+'process.json')
                assert process['exit_code']==record['exit_code']==0
                assert process['status']==record['status']=='passed'
                assert process['log_sha256']==record['log_sha256']
                assert process['command']==record['command'] and process['pid']==record['pid']
                if stage not in {'import','graphical'}:
                    completion=qualification.completion(stage,Console(prefix+'process.log',z.read(prefix+'process.log')))
                    assert completion==record['completion']
                    if 'report_sha256' in record:
                        assert record['report_sha256']==member_sha(z,prefix+'report.json')
                        result=read(z,prefix+'report.json')
                        assert result['checks']==completion['checks']
                        failures=result.get('failures')
                        assert (len(failures) if isinstance(failures,list) else failures)==completion['failures']==0
                    headless_completions.append({'name':stage,**completion})
            if not name.startswith('ambient/'):
                g=q['graphical']; report_path=folder+'/captures/capture-report.json'
                assert member_sha(z,report_path)==g['report_sha256']
                report=read(z,report_path)
                assert report['source_revision']==SOURCE and report['engine_sha256']==ENGINE
                assert not report['failures'] and report['physical_display_acceptance'] is False
                assert set(g['images_sha256'])==set(qualification.CAPTURES)
                capture_names=[Path(v['path']).name for v in report['captures']]
                assert len(capture_names)==len(set(capture_names))==29
                assert set(capture_names)==set(g['images_sha256'])
                for capture in report['captures']:
                    material=capture['material_display']; displayed=capture['rendered_actor_frame']
                    assert all(type(material.get(k)) is int and material[k]>=0 for k in ['generation','render_serial','revision'])
                    assert type(displayed.get('available')) is bool and displayed.get('mode')
                    if displayed['available']:
                        assert displayed['world_generation']==material['generation'] and displayed['revision']==material['revision']
                        assert type(displayed.get('epoch')) is int and displayed['epoch']>=0
                dimensions=[]
                for image_name,digest in g['images_sha256'].items():
                    image_path=folder+'/captures/'+image_name
                    assert member_sha(z,image_path)==digest
                    header=z.read(image_path)[:24]
                    assert header[:8]==b'\x89PNG\r\n\x1a\n'
                    dimensions.append([int.from_bytes(header[16:20],'big'),int.from_bytes(header[20:24],'big')])
                assert len(report['phases'])==11
                assert {p['example'] for p in report['phases']}==set(qualification.EXAMPLES)
                assert all(p['passed'] and p['physical_ticks']>=120 and p['native_ticks']>=119 for p in report['phases'])
                graphical_readback={'report_sha256':g['report_sha256'],'images':29,
                    'image_dimensions':sorted({tuple(v) for v in dimensions}),
                    'renderer':report['renderer'],'rendering_method':report['rendering_method'],
                    'phases':report['phases'],'scope':'Original graphical receipt/hash readback; not a claim that every image was visually inspected.'}
        assert receipt['custody_sha256'] == member_sha(z,'episodes-full/custody.json')
        assert receipt['report_sha256'] == member_sha(z,'episodes-full/episodes.json')
        assert receipt['runner_sha256'] == TOOLS['run_episodes.py']
        assert receipt['analyzer_sha256'] == TOOLS['analyze_episodes.py']
        registry_name = 'episodes-full/'+receipt['registry']
        registry = read(z, registry_name)
        registry_prefix = registry_name.rsplit('/',1)[0]+'/'
        registration_receipt = read(z, registry_prefix+'execution.json')
        assert registry['case'] == 'AMBIENT-002 physical campaign registry'
        assert receipt['registry_sha256'] == member_sha(z,registry_name)
        assert receipt['registration_receipt_sha256'] == member_sha(z,registry_prefix+'execution.json')
        assert registration_receipt['console_sha256'] == member_sha(z,registry_prefix+'console.log')
        assert registration_receipt['report_sha256'] == member_sha(z,registry_name)
        assert registration_receipt['custody_sha256'] == receipt['custody_sha256']
        runner.check_terminal(Console(registry_prefix+'console.log',z.read(registry_prefix+'console.log')),
                              registry,registration_receipt,'',SOURCE,'registry')
        aggregate = read(z,'episodes-full/episodes.json')
        rows = reducer.validate(aggregate)
        identity = aggregate['source_identity']
        assert identity['source_revision']==SOURCE and identity['godot_executable_sha256']==ENGINE
        assert all(current_project[p]==h for p,h in identity['sha256'].items())
        assert all(current_project[p]==h for p,h in identity['runtime_sha256'].items())
        assert runner.identity_key(registry['source_identity']) == runner.identity_key(identity)
        assert aggregate['registration'] == registry['registration']
        assert len(aggregate['shard_receipts']) == 122
        campaigns = {c['id']:c for c in aggregate['campaigns']}
        cases = []
        joined_cases = set()
        for retained in aggregate['shard_receipts']:
            report_name = 'episodes-full/'+retained['report']
            execution_name = 'episodes-full/'+retained['execution_receipt']
            console_name = 'episodes-full/'+retained['console']
            assert retained['report_sha256'] == member_sha(z,report_name)
            assert retained['execution_receipt_sha256'] == member_sha(z,execution_name)
            assert retained['console_sha256'] == member_sha(z,console_name)
            shard,execution = read(z,report_name),read(z,execution_name)
            assert execution['report_sha256']==retained['report_sha256']
            assert execution['console_sha256']==retained['console_sha256']
            assert execution['custody_sha256']==receipt['custody_sha256']
            assert runner.identity_key(shard['source_identity']) == runner.identity_key(identity)
            reducer.validate(shard)
            current = shard['campaigns'][0]
            cid = current['id']
            assert retained['case_id'] == cid and cid not in joined_cases
            joined_cases.add(cid)
            runner.check_terminal(Console(console_name,z.read(console_name)),shard,execution,cid,SOURCE,'full')
            assert current == campaigns[cid]
            old = read(base,report_name)['campaigns'][0]
            for key in ('id','initial_materials','initial_pose_sha256','geometry','model','seed','seconds','actor_count'):
                assert current[key] == old[key],(cid,key)
            assert len(current['episodes']) == len(old['episodes'])
            actors = []
            for final,prior_row in zip(current['episodes'],old['episodes']):
                assert final['episode_id'] == prior_row['episode_id'] and final['profile'] == prior_row['profile']
                assert len(final['trace']) == len(prior_row['trace'])
                differences = [math.dist(a['position'],b['position']) for a,b in zip(final['trace'],prior_row['trace'])]
                actors.append({'episode_id':final['episode_id'],'model':final['model'],
                    'position_samples':len(differences),'exact_position_samples':sum(d==0 for d in differences),
                    'maximum_position_difference_cells':max(differences),
                    'exact_complete_trace':final['trace']==prior_row['trace'],
                    'baseline_heading_reversals':headings(prior_row),'current_heading_reversals':headings(final),
                    'baseline_failure_events':prior_row['final_memory'].get('failure_events'),
                    'current_failure_events':final['final_memory'].get('failure_events')})
            cases.append({'campaign_id':cid,'group':current['group'],'arm':current['arm'],'model':current['model'],
                'seed':current['seed'],'seconds':current['seconds'],'initial_materials_pose_geometry_and_profiles_match':True,
                'original_report_path':report_name,
                'current_report_sha256':retained['report_sha256'],'baseline_report_sha256':member_sha(base,report_name),
                'actors':actors})
        assert joined_cases == set(campaigns), 'Aggregate case lacks its unique original shard chain'
        summary = reducer.summarize(aggregate,rows)
        summary['raw_report_sha256'] = receipt['report_sha256']
        summary['analyzer_sha256'] = receipt['analyzer_sha256']
        summary_bytes = (json.dumps(summary,indent=2)+'\n').encode()
        assert sha(summary_bytes) == member_sha(z,'analysis/summary.json')
        reviewed = independent.audit(aggregate,summary)
        reviewed['raw_report_sha256'] = receipt['report_sha256']
        reviewed['reducer_summary_sha256'] = sha(summary_bytes)
        reviewed['reviewer_sha256'] = TOOLS['review_episodes.py']
        reviewed_bytes = (json.dumps(reviewed,indent=2)+'\n').encode()
        assert sha(reviewed_bytes) == member_sha(z,'independent-review/independent-review.json')
        (out/'summary.json').write_bytes(summary_bytes)
        (out/'independent-review.json').write_bytes(reviewed_bytes)
        (out/'independent-review.md').write_text(independent.markdown(reviewed))
        result = {'status':'PASS','source_revision':SOURCE,'source_tree':TREE,
            'baseline_source':BASELINE,'artifact_id':args.artifact_id,'artifact_sha256':args.artifact_sha256,
            'artifact_bytes':args.artifact.stat().st_size,'artifact_members':len(z.infolist()),
            'raw_report_sha256':receipt['report_sha256'],'summary_sha256':sha(summary_bytes),
            'independent_review_sha256':sha(reviewed_bytes),'runner_receipt_sha256':member_sha(z,'episodes-full/runner-receipt.json'),
            'custody_sha256':receipt['custody_sha256'],'qualifications':qualifications,
            'original_headless_case_completions':headless_completions,'original_graphical_readback':graphical_readback,
            'source_inputs':len(source_map),'loaded_project_inputs':len(current_project),
            'campaigns':122,'actor_episodes':len(rows),'subject_actor_episodes':summary['subject_actor_episodes'],
            'auxiliary_actor_episodes':summary['auxiliary_actor_episodes'],
            'world_simulation_seconds':sum(c['seconds'] for c in aggregate['campaigns']),
            'actor_simulation_seconds':sum(c['seconds']*c['actor_count'] for c in aggregate['campaigns']),
            'native_steps':sum(c['native_ticks'] for c in aggregate['campaigns']),
            'physical_steps':sum(c['physical_ticks'] for c in aggregate['campaigns']),
            'accepted_commands':sum(r['accepted_commands'] for c,r in rows),
            'rejected_commands':sum(r['rejected_commands'] for c,r in rows),
            'canvas_center_incidents':sum(r['canvas_center_incidents'] for c,r in rows),
            'independently_checked_metrics':reviewed['independently_checked_episode_metrics'],
            'copied_peer_samples_checked':reviewed['copied_peer_samples_checked'],
            'exact_ablation_groups':len(reviewed['ablation_pairs']),
            'reduction_byte_identical_to_hosted':True,'independent_review_byte_identical_to_hosted':True,
            'loaded_project_changes_from_baseline':[{'path':p,'old_sha256':prior_project[p],'new_sha256':current_project[p]} for p in sorted(changed)],
            'source_input_changed_paths':sorted(source_changes),'baseline_comparison_cases':cases,
            'auditor_sha256':file_sha(Path(__file__)),
            'limits':[
                'Separate hosted re-executions of the same registered cases do not add independent treatment registrations.',
                'The complete loaded project differs only at the three independently approved source/test/help paths.',
                'The qualified source inventory also contains the separately pinned new qualification-request marker; it is not a loaded Godot application input.',
                'Pose/trajectory differences after re-execution are descriptive and are not all uniquely attributable to the recharge change.',
                'Elapsed-call timings depend on the hosted machine and are not CPU utilization or physical presentation acceptance.',
                'This local readback uses exact pinned analysis bytes, not a claim that the local mutable source checkout is a clean qualified execution.',
            ]}
        (out/'receipt-chain-and-science.json').write_text(json.dumps(result,indent=2)+'\n')
        figures=[]
        for item in z.infolist():
            if item.filename.startswith('analysis/') and item.filename.endswith('.png'):
                target=out/Path(item.filename).name
                target.write_bytes(z.read(item.filename))
                figures.append({'path':target.name,'sha256':file_sha(target),'bytes':target.stat().st_size})
        (out/'figures.json').write_text(json.dumps(figures,indent=2)+'\n')
        print(json.dumps({k:v for k,v in result.items() if k not in {'baseline_comparison_cases','limits'}},indent=2))

if __name__ == '__main__':
    main()
