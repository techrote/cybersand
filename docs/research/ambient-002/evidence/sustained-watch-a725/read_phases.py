"""Independent phase/drive interpretation of the original ordinary Workbench watch.

Usage: python read_phases.py /path/to/original/graphical-watch /path/to/output.json
This reads copied diagnostic snapshots; it neither runs the engine nor substitutes
sampled phase occupancy for complete ten-Hz transitions or physical stillness.
"""
from pathlib import Path
from collections import Counter, defaultdict
import hashlib
import json
import math
import sys

root, output = map(Path, sys.argv[1:])
source = 'a7250e15495667b2fcf564cbed1eaa8dea217c45'
cases = [('ambient2-courtyard', 1), ('ambient2-refinery', 5), ('ambient2-settlement', 7)]
viewed = {
    'ambient2-courtyard': ['frames/frame-0010.png','frames/frame-0036.png','media/ambient2-courtyard-contact-sheet.png'],
    'ambient2-refinery': ['frames/frame-0038.png','frames/frame-0055.png','media/ambient2-refinery-contact-sheet.png'],
    'ambient2-settlement': ['frames/frame-0024.png','frames/frame-0044.png','frames/frame-0050.png','media/ambient2-settlement-contact-sheet.png'],
}
results = {}
for scene, selected in cases:
    path = root / scene / 'frames/watch-report.json'
    data = path.read_bytes()
    report = json.loads(data)
    assert report['source_revision'] == source and report['status'] == 'passed' and not report['failures']
    assert report['follow_actor'] == selected and len(report['samples']) == 61
    rows = []
    for sample in report['samples']:
        actors = [a for a in sample['actors'] if a['instance_id'] == selected]
        assert len(actors) == 1
        rows.append((sample, actors[0]))
    assert [s['requested_simulation_second'] for s, _ in rows] == list(range(61))
    active = rows[1:]
    categories = Counter()
    keys = defaultdict(set)
    timeline = []
    previous = None
    memory_changes = []
    previous_memory = None
    for sample, actor in active:
        intent = actor['intent']
        label = (intent.get('active_override',''), intent.get('selected_goal',''), intent.get('goal_phase',''))
        categories[label] += 1
        if intent.get('selected_goal'):
            keys[intent['selected_goal']].add(str(intent.get('goal_key','')))
        identity = label + (str(intent.get('goal_key','')),)
        if identity != previous or sample['requested_simulation_second'] % 5 == 0:
            timeline.append({'requested_second':sample['requested_simulation_second'],'copied_simulation_seconds':sample['simulation_seconds_since_play'],'override':label[0],'selected_goal':label[1],'phase':label[2],'goal_key':identity[-1],'target':intent.get('goal_target'),'position':actor['observation']['position'],'pace':intent.get('pace'),'phase_selected_seconds':intent.get('phase_selected_seconds'),'drives':actor['drives'],'reason':intent.get('reason')})
        previous = identity
        memory = actor['memory']
        state = (memory.get('failure_events'), memory.get('forgotten'), memory.get('obstructions_count'))
        if state != previous_memory:
            memory_changes.append({'requested_second':sample['requested_simulation_second'],'failure_events':state[0],'forgotten':state[1],'obstructions_count':state[2],'copied_obstructions':memory.get('obstructions_tail',[])})
        previous_memory = state
    results[scene] = {
        'original_watch_report_sha256':hashlib.sha256(data).hexdigest(),
        'selected_instance_id':selected,
        'internal_actor_id':active[-1][1]['actor_id'],
        'profile_id':active[-1][1]['profile_id'],
        'copied_samples':len(rows),
        'post_start_sample_count':len(active),
        'actual_simulation_seconds':report['actual_simulation_seconds'],
        'physical_ticks':report['physical_ticks'],
        'native_ticks':report['native_ticks'],
        'sampled_selection_counts':[{'override':key[0],'goal':key[1],'phase':key[2],'samples':value} for key,value in sorted(categories.items())],
        'sampled_goal_keys_by_module':{key:sorted(value) for key,value in keys.items()},
        'timeline':timeline,
        'memory_changes':memory_changes,
        'first_post_start_drives':active[0][1]['drives'],
        'final_drives':active[-1][1]['drives'],
        'viewed_original_graphics_sha256':{name:hashlib.sha256((root/scene/name).read_bytes()).hexdigest() for name in viewed[scene]},
    }
    if scene == 'ambient2-settlement':
        # Independently checked against exact source godot/examples/workbench/
        # ambient2-settlement.json actor7: home region310,290,110,130 and
        # seek_home_drive arrival_radius20/rest_seconds4. No scene retuning.
        home = [365.0,355.0]
        detail = []
        for sample, actor in rows[43:54]:
            i = actor['intent']
            detail.append({'requested_second':sample['requested_simulation_second'],'selected_goal':i.get('selected_goal'),'phase':i.get('goal_phase'),'goal_key':i.get('goal_key'),'position':actor['observation']['position'],'distance_to_authored_home':math.dist(actor['observation']['position'],home),'exploration_drive':actor['drives']['exploration'],'selected_phase_seconds':i.get('phase_selected_seconds'),'pace':i.get('pace')})
        rests = [entry for entry in detail if entry['phase'] == 'home_rest']
        assert [entry['requested_second'] for entry in rests] == [48,49,50,51]
        assert all(16 < entry['distance_to_authored_home'] <= 20 and entry['pace'] == 0 for entry in rests)
        assert all(a['exploration_drive'] > b['exploration_drive'] for a,b in zip(rests,rests[1:]))
        results[scene]['home_rest_negative'] = {'authored_home':home,'verified_arrival_radius':20.0,'frozen_engine_ordinary_recharge_radius':16.0,'verified_rest_seconds':4.0,'sampled_details':detail,'drive_change_48_to_51':rests[-1]['exploration_drive']-rests[0]['exploration_drive'],'interpretation':'The selected home-rest phase is physically inside its authored20-cell arrival region but outside the engine16-cell recharge region. Drive declines during the observed rest. This is a visible finite homeward/rest sequence, not successful recharge or a16-cell geometric-return result.'}

review = {
    'scope':'Independent phase/drive/memory interpretation of three selected actors in original ordinary Workbench graphical observation. No runtime rerun, no new physical episode count, and no replacement for the authoring lane full artifact/frame/custody audit.',
    'application_source':source,'observer_source':'2eea3dbb921058db418fbb243b4abc493cddbdb9','workflow_run':45544614719,'artifact_id':14992866806,'original_artifact_sha256':'907f8bcdd11ef4c7150dc252844ec8545a0a7a46e66abf41ff10e889ad868cef','reader_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    'scenes':results,
    'qualitative_review':{
        'ambient2-courtyard':'The original Follow frames show a visible small group with readable body silhouettes. Copied phases show repeated approach/watch, regroup and three sampled dispersal goal keys. This is the clearest social activity of the three watched selections. The same peer observation can switch approach/watch as distance changes; sampled counts are not a complete transition history or evidence of coordinated planning.',
        'ambient2-refinery':'The original Follow frames make the sealed attraction and adjacent accessible pocket legible. The selected actor repeatedly returns, records failures and withdraws; an accessible second patch receives an inspection phase at sampled37-39s. The loop remains confined and repetitive. Historical target962.5,526.5 is retained while current nearest observations often differ; its current material occupancy is unconfirmed, not inferred from rendered colors. One earlier obstruction record expires by sampled40s before seven further failures accumulate.',
        'ambient2-settlement':'The flyer moves around the visible canopy and support geometry, retains temporary destinations, selects a homeward/rest interval, then resumes its prior exploration goal key5. Local approaches are visibly constrained by the supports. The sampled home-rest interval exposes a real arrival/recharge radius mismatch. The selected body and diagnostic overlay are readable in the original Follow frame; this does not establish hardware playfeel.',
    },
    'limits':['Samples are approximately1Hz and their copied physical times differ from rendered-frame stamps. Counts are sampled selections, not exact durations or complete10Hz transitions.','Goal keys are scoped to module instances; regroup key0 is continuous guidance and must not be counted as a sequence of new goals.','A zero sampled pace does not prove uninterrupted zero commands between samples or physical stillness.','Original images support qualitative scene/body legibility; material identity and behavioral state come from copied diagnostics, not image colors.','All a725 originals remain an unfavorable baseline for the newly proposed shared recharge correction.']
}
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps(review,indent=2)+'\n')
print(json.dumps({'source':source,'scenes':list(results),'home_rest_drive_change':results['ambient2-settlement']['home_rest_negative']['drive_change_48_to_51'],'output':str(output)}))
