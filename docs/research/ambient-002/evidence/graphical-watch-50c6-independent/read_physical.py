"""Independent read-only physical comparison of the two original Foundry reports.

No engine execution, behavioural episode credit, or claim about unobserved motion.
"""
from pathlib import Path
import hashlib
import json
import math

ROOT = Path('/tmp/ambient-002/evidence/authoring')
SOURCES = {
    'baseline': ('graphical-watch-2eea3dbb', 'a7250e15495667b2fcf564cbed1eaa8dea217c45',
                 '241b442f92b4564b844b47c2c0f4d09ec6ddc42c940f6a8322a6b4890d3db466'),
    'current': ('graphical-watch-52900f9d', '50c6df89528dc9ecdc5316d8c67abf203e192254',
                '8099576e84f310ae99a0bc5e0390eed20c3606a7007bc27a8b60281692bf8c47'),
}
def sha(data):
    return hashlib.sha256(data).hexdigest()

def analyze(label, data):
    folder, source, expected = SOURCES[label]
    raw = data.read_bytes()
    assert sha(raw) == expected
    report = json.loads(raw)
    assert report['source_revision'] == source and report['status'] == 'passed' and not report['failures']
    assert report['native_ticks'] == report['physical_ticks'] == 3601
    assert report['engine_sha256'] == 'f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75'
    assert report['observer_script_sha256'] == 'aac731d1d44fcc46beca22ea6b0ee84e1acfe4c09ad51cc47bd52abb8c922379'
    assert [s['requested_simulation_second'] for s in report['samples']] == list(range(61))
    starts = []
    for a in sorted(report['samples'][0]['actors'], key=lambda a:a['instance_id']):
        starts.append({k:a[k] for k in ('instance_id','actor_id','model','profile_id','observation')})
    assert len(starts) == 8
    rows = []
    for sample in report['samples']:
        actors = sample['actors']
        assert {a['instance_id'] for a in actors} == set(range(1,9))
        actor = next(a for a in actors if a['instance_id'] == 7)
        assert not actor['error'] and actor['rejected'] == 0
        pos = actor['observation']['position']
        assert len(pos)==2 and all(math.isfinite(v) for v in pos)
        intent = actor['intent']
        rows.append({
            'second':sample['requested_simulation_second'], 'position':pos,
            'velocity':actor['observation']['velocity'],
            'selected_goal':intent.get('selected_goal'), 'phase':intent.get('goal_phase'),
            'goal_key':intent.get('goal_key'), 'pace':intent.get('pace'),
            'exploration_drive':actor['drives'].get('exploration'),
            'home_distance':math.dist(pos,[365,355]),
        })
    positions = [r['position'] for r in rows]
    images = []
    for relative in ['media/ambient2-settlement-contact-sheet.png', 'frames/frame-0050.png']:
        path = data.parent.parent / relative
        content = path.read_bytes()
        images.append({'path':relative, 'sha256':sha(content), 'bytes':len(content)})
    return {
        'source_revision':source, 'report_sha256':sha(raw), 'actual_simulation_seconds':report['actual_simulation_seconds'],
        'native_ticks':report['native_ticks'], 'physical_ticks':report['physical_ticks'],
        'renderer':report['renderer'], 'framebuffer':report['actual_framebuffer_size'],
        'initial_copied_actor_states':starts, 'focus_actor':7,
        'x_range_cells':max(p[0] for p in positions)-min(p[0] for p in positions),
        'y_range_cells':max(p[1] for p in positions)-min(p[1] for p in positions),
        'net_horizontal_displacement_cells':positions[-1][0]-positions[0][0],
        'sampled_center_path_cells':sum(math.dist(a,b) for a,b in zip(positions,positions[1:])),
        'sampled_path_seconds49_through52_cells':sum(math.dist(positions[i],positions[i+1]) for i in range(49,52)),
        'sampled_path_seconds50_through52_cells':sum(math.dist(positions[i],positions[i+1]) for i in range(50,52)),
        'rows':rows, 'visual_source_files':images,
    }

def main():
    outcomes = {}
    for label,(folder,_,_) in SOURCES.items():
        outcomes[label] = analyze(label, ROOT/folder/'original/graphical-watch/ambient2-settlement/frames/watch-report.json')
    baseline,current = outcomes['baseline'],outcomes['current']
    equal = [a['second'] for a,b in zip(baseline['rows'],current['rows']) if a['position']==b['position']]
    assert baseline['initial_copied_actor_states'] == current['initial_copied_actor_states']
    assert equal == list(range(53))
    result = {
        'status':'PASS', 'scope':'Independent original-report physical and sampled-image readback; zero new engine executions or registered episodes.',
        'reader_sha256':sha(Path(__file__).read_bytes()),
        'initial_all_eight_copied_states_equal':True, 'focus_exact_position_sample_seconds':equal,
        'baseline':baseline, 'current':current,
        'findings':[
            'The selected flyer has identical copied physical positions at all requested seconds0 through52 in these two executions.',
            'The current home_rest samples48 through51 remain within authored20-cell arrival, outside the separate16-cell geometric return metric, while exploration drive rises.',
            'Neutral pace does not imply exact stillness: the identical sampled center path49 through52 is0.004209446600414067cells, and the larger residual arrival motion48 through49 is retained in the rows.',
            'The two later sampled trajectories diverge; this readback does not attribute every later difference uniquely to recharge across separate hosted executions.',
            'The inspected new contact sheet and original frame50 show the ordinary Follow view and home-rest label with visible intent/perception/memory overlays.',
        ],
        'limits':[
            'One-Hz sampled path underestimates unobserved intervening path and cannot establish continuous physical stillness or containment.',
            'Initial copied states match; this observer does not separately hash the initial native material publication.',
            'Only the new contact sheet and original frame50 were directly viewed for this supplement; all61 PNGs are covered by C artifact custody, not by a claim that B viewed every frame.',
            'Hosted llvmpipe software presentation is not physical NVIDIA playfeel acceptance.',
        ],
    }
    out = Path(__file__).with_name('physical-readback.json')
    out.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'status':result['status'],'sha256':sha(out.read_bytes()),'initial_states_equal':True,
                      'equal_focus_position_samples':len(equal),'current_x_range':current['x_range_cells']}))

if __name__ == '__main__':
    main()
