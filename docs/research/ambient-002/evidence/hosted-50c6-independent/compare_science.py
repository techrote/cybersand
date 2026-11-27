"""Compact old-to-new tables from original source-bound summaries and shards.

Run only after audit_hosted_50c6.py succeeds. No engine execution. Quantities
retain the frozen reducer's definitions; repeated runs do not add replicates.
"""
from collections import defaultdict
from pathlib import Path
import argparse
import hashlib
import json
import math
import statistics
import zipfile

ARMS = ['legacy','random','random_hold','scripted','stateful','no_memory','no_traits','coarse_only']
RIGS = ['runner','monowheel','4ly_trainer']

def sha(data):
    return hashlib.sha256(data).hexdigest()

def read(z,path):
    return json.loads(z.read(path))

def med(values):
    values = [v for v in values if v is not None]
    return statistics.median(values) if values else None

def distance(a,b,flight):
    return math.dist(a,b) if flight else abs(a[0]-b[0])

def recovery_times(row):
    # This is the unchanged reducer's sampled horizontal-obstruction window,
    # with the time endpoints retained; it does not require movement away.
    flight = row['model']=='4ly_trainer'
    previous_blocked = False
    recovery = None
    windows=[]
    for prior,sample in zip(row['trace'],row['trace'][1:]):
        point = sample['position']
        move_x = prior['action_move'][0]
        wall = prior.get('wall_right' if move_x>=0 else 'wall_left')
        progress = (point[0]-prior['position'][0])*(1 if move_x>=0 else -1)
        blocked = abs(move_x)>.05 and isinstance(wall,(int,float)) and 0<=wall<=10 and progress<.25
        if blocked and not previous_blocked and recovery is None:
            recovery = (sample['seconds'],point)
        previous_blocked = blocked
        if recovery is not None:
            elapsed = sample['seconds']-recovery[0]
            if elapsed>5:
                recovery = None
            elif distance(point,recovery[1],flight)>=8:
                windows.append({'start_seconds':recovery[0],'recovery_seconds':sample['seconds'],
                                'elapsed_seconds':elapsed,'displacement_cells':distance(point,recovery[1],flight)})
                recovery = None
    return windows

def selected_windows(row,needle):
    found=[]
    start=None
    for sample in row['trace']:
        active=sample['selection']==needle
        if active and start is None:
            start=sample['seconds']
        if not active and start is not None:
            found.append([start,sample['seconds']]);start=None
    if start is not None:
        found.append([start,row['trace'][-1]['seconds']+.1])
    return found

def load_dataset(z,audit,label):
    summary_raw=z.read('analysis/summary.json')
    summary=json.loads(summary_raw)
    expected_source=audit['source_revision'] if label=='current' else audit['baseline_source']
    assert summary['source_identity']['source_revision']==expected_source
    episode_index={e['episode_id']:e for e in summary['episodes']}
    additions={}
    campaign_extra={}
    for case in audit['baseline_comparison_cases']:
        raw=z.read(case['original_report_path'])
        assert sha(raw)==case['current_report_sha256' if label=='current' else 'baseline_report_sha256']
        campaign=json.loads(raw)['campaigns'][0]
        assert campaign['id']==case['campaign_id']
        campaign_extra[campaign['id']]={
            'group':campaign['group'],'layout':campaign['layout'],'model':campaign['model'],
            'seed':campaign['seed'],'arm':campaign['arm'],'seconds':campaign['seconds'],
            'actual_actors':campaign['actor_count'],'events':campaign['events'],
            'native_step_ms_per_step':campaign['native_step_usec']/1000/campaign['native_ticks'],
            'rapier_step_ms_per_step':campaign['physics_step_usec']/1000/campaign['physical_ticks'],
            'production_advance_ms_per_simulated_second':campaign['production_advance_usec']/1000/campaign['seconds'],
            'sensor_ms_per_simulated_second':sum(r['sensor_usec_total'] for r in campaign['episodes'])/1000/campaign['seconds'],
            'core_adapter_ms_per_simulated_second':sum(r['total_decision_usec'] for r in campaign['episodes'])/1000/campaign['seconds'],
        }
        for row in campaign['episodes']:
            reduced=episode_index[row['episode_id']]
            recovery=recovery_times(row)
            assert len(recovery)==reduced['eight_cell_recoveries_within_five_seconds']
            additions[row['episode_id']]={
                'failure_events':row['final_memory'].get('failure_events'),
                'final_drives':row['final_drives'],
                'obstructions':row['final_memory'].get('obstructions'),
                'withdraw_windows_seconds':selected_windows(row,'withdraw_obstruction'),
                'recovery_windows':recovery,
            }
    return {'summary_sha256':sha(summary_raw),'summary':summary,'extra':additions,'campaigns':campaign_extra}

def main_medians(dataset):
    rows=dataset['summary']['episodes'];out=[]
    for rig in RIGS:
        for arm in ARMS:
            selected=[r for r in rows if r['group']=='main' and r['model']==rig and r['arm']==arm]
            assert len(selected)==3
            out.append({'model':rig,'arm':arm,'worlds':3,
                **{k:med(r[k] for r in selected) for k in ['x_range_cells','y_range_cells','stable_territory_cells',
                    'stalled_active_fraction','intention_transitions','decision_core_adapter_usec_per_decision',
                    'sensor_usec_per_decision']}})
    return out

def paired_ablations(dataset):
    rows=dataset['summary']['episodes'];out=[]
    for rig in RIGS:
        index={(r['seed'],r['arm']):r for r in rows if r['group']=='main' and r['model']==rig}
        for ablation in ['no_memory','no_traits','coarse_only']:
            pairs=[{'seed':seed, 'delta_x_range_cells':index[seed,'stateful']['x_range_cells']-index[seed,ablation]['x_range_cells'],
                    'delta_stall_fraction':index[seed,'stateful']['stalled_active_fraction']-index[seed,ablation]['stalled_active_fraction']}
                   for seed in [605,1701,2909]]
            out.append({'model':rig,'ablation':ablation,'pairs':pairs,
                        'median_paired_x_delta_cells':med(p['delta_x_range_cells'] for p in pairs),
                        'median_paired_stall_delta':med(p['delta_stall_fraction'] for p in pairs)})
    return out

def details(dataset,group):
    out=[]
    for row in dataset['summary']['episodes']:
        if row['group']!=group or row['controller']=='passive_companion':continue
        keys=['episode_id','campaign_id','model','profile_id','layout','arm','seed','seconds','x_range_cells','y_range_cells',
              'stable_territory_cells','stalled_active_fraction','home_departures_40_cells','home_returns_16_cells',
              'intentions_seconds','phases_seconds','intention_transitions','eight_cell_recoveries_within_five_seconds',
              'minimum_oil_sample_distance','minimum_water_sample_distance','water_within20_seconds',
              'peer_observed_seconds','peer_distance_median','intentional_idle_seconds']
        out.append({**{k:row[k] for k in keys},**dataset['extra'][row['episode_id']],
                    'campaign_events':dataset['campaigns'][row['campaign_id']]['events']})
    return out

def social(dataset):
    out=[]
    for row in dataset['summary']['social']:
        c=dataset['campaigns'][row['campaign_id']]
        if c['group'] not in ['social','capacity','departure']:continue
        out.append({**{k:v for k,v in row.items() if k!='timeline'},'group':c['group']})
    return out

def costs(dataset):
    groups=defaultdict(list)
    for row in dataset['campaigns'].values():
        if row['group'] not in ['main','social','capacity'] or row['arm'] not in ['legacy','stateful','no_social']:continue
        if row['group']=='main' and row['model']!='runner':continue
        groups[row['group'],row['arm'],row['actual_actors']].append(row)
    metrics=['native_step_ms_per_step','rapier_step_ms_per_step','production_advance_ms_per_simulated_second',
             'sensor_ms_per_simulated_second','core_adapter_ms_per_simulated_second']
    return [{'group':key[0],'arm':key[1],'actual_actors':key[2],'worlds':len(rows),
             **{m:med(r[m] for r in rows) for m in metrics}} for key,rows in sorted(groups.items())]

def fmt(value,digits=3):
    return '—' if value is None else f'{value:.{digits}f}'

def joined(old,new,key):
    before={key(row):row for row in old}
    assert set(before)=={key(row) for row in new}
    return [(before[key(row)],row) for row in new]

def markdown(data):
    old,new=data['baseline'],data['current']
    lines=['# AMBIENT-002 — a725 to 50c6 physical-programme comparison','',
           'This is a descriptive comparison of fresh hosted executions of the same 122 registered Worlds and 194 actual actor episodes. '
           'It adds no independent treatment registrations. All 122 initial native material hashes, full initial pose hashes, geometry, '
           'seeds, observation scope and authored profiles match; only the approved three loaded source/test/help files differ. '
           'Rapier trajectories and hosted elapsed-call timings are not assumed identical across executions.','',
           'Values are **a725 → 50c6**. Ranges and distances are native cells. A profile with no home module or no qualifying departure '
           'does not fail merely because its geometric home-return count is zero.','',
           '## Main 30-second programme','',
           'Each cell is the median of three matched World seeds. Ground horizontal extent excludes vertical gait. '
           'Stable bins require 0.5 seconds cumulative occupancy, including the starting bin only if it qualifies.','',
           '| Rig | Arm | X range | Y range | Stable bins | Active stall fraction | Selection-label changes |',
           '| --- | --- | ---: | ---: | ---: | ---: | ---: |']
    for a,b in joined(old['main'],new['main'],lambda r:(r['model'],r['arm'])):
        cells=[f'{fmt(a[k])} → {fmt(b[k])}' for k in ['x_range_cells','y_range_cells','stable_territory_cells','stalled_active_fraction','intention_transitions']]
        lines.append('| '+b['model']+' | '+b['arm']+' | '+' | '.join(cells)+' |')
    lines+=['','## Within-seed ablations','',
            'These are medians of **paired differences** (stateful minus the stated ablation), not differences between cohort medians. '
            'The memory ablation disables spatial memory while preserving module latches; no_traits jointly disables personalities and drives.','',
            '| Rig | Ablation | Paired X-range delta | Paired active-stall delta |', '| --- | --- | ---: | ---: |']
    for a,b in joined(old['paired_ablations'],new['paired_ablations'],lambda r:(r['model'],r['ablation'])):
        lines.append(f"| {b['model']} | {b['ablation']} | {fmt(a['median_paired_x_delta_cells'])} → {fmt(b['median_paired_x_delta_cells'])} | {fmt(a['median_paired_stall_delta'])} → {fmt(b['median_paired_stall_delta'])} |")
    for group,title in [('adverse','Adversarial 30-second episodes'),('sustained','Sustained 120/300-second episodes')]:
        lines+=['','## '+title,'','| Layout / rig | Arm / seed | X range | Active stall | Internal failures | Withdrawal seconds | Eight-cell windows | Geometric home returns |',
                '| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |']
        for a,b in joined(old[group],new[group],lambda r:r['episode_id']):
            values=[]
            for k in ['x_range_cells','stalled_active_fraction','failure_events']:
                values.append(fmt(a[k])+' → '+fmt(b[k]))
            values.append(fmt(a['intentions_seconds'].get('withdraw_obstruction',0))+' → '+fmt(b['intentions_seconds'].get('withdraw_obstruction',0)))
            for k in ['eight_cell_recoveries_within_five_seconds','home_returns_16_cells']:
                values.append(fmt(a[k],0)+' → '+fmt(b[k],0))
            lines.append(f"| {b['layout']} / {b['model']} ({b['seconds']}s) | {b['arm']} / {b['seed']} | "+' | '.join(values)+' |')
    lines+=['','### Adverse recovery and withdrawal timing','',
            'Recovery is the frozen sampled proxy: at least 8 cells displacement from a blocked-approach point within 5 seconds. '
            'It does not require movement away or certify that the original target became reachable. Exact sampled window endpoints '
            'and obstruction last-seen records are retained in the JSON.','',
            '| Layout | Arm / seed | Old recovery elapsed seconds | New recovery elapsed seconds | New withdrawal windows |',
            '| --- | --- | --- | --- | --- |']
    for a,b in joined(old['adverse'],new['adverse'],lambda r:r['episode_id']):
        oldt=', '.join(fmt(v['elapsed_seconds'],1) for v in a['recovery_windows']) or 'none'
        newt=', '.join(fmt(v['elapsed_seconds'],1) for v in b['recovery_windows']) or 'none'
        withdraw=', '.join(f"[{fmt(x,1)}, {fmt(y,1)})" for x,y in b['withdraw_windows_seconds']) or 'none'
        lines.append(f"| {b['layout']} | {b['arm']} / {b['seed']} | {oldt} | {newt} | {withdraw} |")
    lines+=['','## Social spacing and sampled groups','',
            'Forty-cell connected components are a spatial proximity measure. Exact-membership set changes and threshold crossings '
            'can produce formation/dissolution counts; these are not persistent social identities. Initial groups are reported separately.','',
            '| World family / actors | Arm / seed | Grouped actor fraction | Initial components | Later formation events | Dissolution events |',
            '| --- | --- | ---: | --- | ---: | ---: |']
    for a,b in joined(old['social'],new['social'],lambda r:r['campaign_id']):
        lines.append(f"| {b['group']} / {b['actual_actors']} | {b['arm']} / {b['seed']} | {fmt(a['mean_grouped_fraction'])} → {fmt(b['mean_grouped_fraction'])} | {a['initial_proximity_components']} → {b['initial_proximity_components']} | {a['formation_events_after_initial']} → {b['formation_events_after_initial']} | {a['dissolution_events']} → {b['dissolution_events']} |")
    lines+=['','## Production elapsed-call costs','',
            'These are medians across the listed Worlds. Sensor and core/adapter calls are disjoint subsets of production advance; '
            'they must not be added again to advance. Native and Rapier costs are per physical tick. One-actor pockets and four/eight-actor '
            'courtyards differ in geometry, so this table is not a controlled actor-count-only scaling experiment. Separate hosted '
            'wall-time changes are not evidence of a performance benefit from the recharge repair.','',
            '| Family / actors | Arm / Worlds | Sensor ms/sim-s | Core ms/sim-s | Advance ms/sim-s | Native ms/tick | Rapier ms/tick |',
            '| --- | --- | ---: | ---: | ---: | ---: | ---: |']
    for a,b in joined(old['costs'],new['costs'],lambda r:(r['group'],r['arm'],r['actual_actors'])):
        vals=[fmt(a[k])+' → '+fmt(b[k]) for k in ['sensor_ms_per_simulated_second','core_adapter_ms_per_simulated_second',
                 'production_advance_ms_per_simulated_second','native_step_ms_per_step','rapier_step_ms_per_step']]
        lines.append(f"| {b['group']} / {b['actual_actors']} | {b['arm']} / {b['worlds']} | "+' | '.join(vals)+' |')
    lines+=['','### Main stateful sensor/core costs per decision','',
            '| Rig | Sensor microseconds/decision | Core/adapter microseconds/decision |', '| --- | ---: | ---: |']
    for a,b in joined(old['main'],new['main'],lambda r:(r['model'],r['arm'])):
        if b['arm']=='stateful':
            lines.append(f"| {b['model']} | {fmt(a['sensor_usec_per_decision'])} → {fmt(b['sensor_usec_per_decision'])} | {fmt(a['decision_core_adapter_usec_per_decision'])} → {fmt(b['decision_core_adapter_usec_per_decision'])} |")
    lines+=['','## Catalogue descriptive subjects','',
            'One ordinary editable personality per 30-second World, each with one real passive companion. These sixteen subjects are '
            'descriptive demonstrations, not replicated estimates of personality-wide tendencies. Companions are excluded below.','',
            '| Profile | Rig | X range | Active stall | Selection-label changes | New selected-module seconds |',
            '| --- | --- | ---: | ---: | ---: | --- |']
    for a,b in joined(old['catalogue'],new['catalogue'],lambda r:r['episode_id']):
        labels=', '.join(f'{k or "none"}: {v:.1f}' for k,v in sorted(b['intentions_seconds'].items(),key=lambda kv:-kv[1]))
        lines.append(f"| {b['profile_id']} | {b['model']} | {fmt(a['x_range_cells'])} → {fmt(b['x_range_cells'])} | {fmt(a['stalled_active_fraction'])} → {fmt(b['stalled_active_fraction'])} | {a['intention_transitions']} → {b['intention_transitions']} | {labels} |")
    lines+=['','## Exact identities','',
            f"- Current application: `{data['current_source']}`.",
            f"- Baseline application: `{data['baseline_source']}`.",
            f"- Current original artifact SHA-256: `{data['artifact_sha256']}`.",
            f"- Current raw report SHA-256: `{data['raw_report_sha256']}`.",
            f"- Current summary SHA-256: `{new['summary_sha256']}`.",
            f"- Baseline summary SHA-256: `{old['summary_sha256']}`.",
            f"- Complete receipt-chain audit SHA-256: `{data['audit_sha256']}`.",
            f"- Comparison reader SHA-256: `{data['reader_sha256']}`.",
            f"- Current source inputs / loaded project inputs: {data['source_inputs']} / {data['loaded_project_inputs']}.",
            '', 'Every table is backed by unrounded values and sampled recovery/withdrawal endpoints in `old-to-new-comparison.json`. '
            'The full original Actions artifact remains the authoritative source.']
    return '\n'.join(lines)+'\n'

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--artifact',type=Path,required=True)
    parser.add_argument('--baseline',type=Path,required=True)
    parser.add_argument('--audit',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    audit_raw=args.audit.read_bytes();audit=json.loads(audit_raw)
    assert audit['status']=='PASS' and audit['campaigns']==122 and audit['actor_episodes']==194
    datasets={}
    for label,path in [('baseline',args.baseline),('current',args.artifact)]:
        with zipfile.ZipFile(path) as z:
            loaded=load_dataset(z,audit,label)
            datasets[label]={'summary_sha256':loaded['summary_sha256'],'main':main_medians(loaded),
                'paired_ablations':paired_ablations(loaded),'adverse':details(loaded,'adverse'),
                'sustained':details(loaded,'sustained'),'catalogue':details(loaded,'catalogue'),
                'social':social(loaded),'costs':costs(loaded)}
    result={'current_source':audit['source_revision'],'baseline_source':audit['baseline_source'],
            'artifact_sha256':audit['artifact_sha256'],'raw_report_sha256':audit['raw_report_sha256'],
            'source_inputs':audit['source_inputs'],'loaded_project_inputs':audit['loaded_project_inputs'],
            'reader_sha256':sha(Path(__file__).read_bytes()),'audit_sha256':sha(audit_raw),**datasets}
    args.output.mkdir(parents=True,exist_ok=True)
    (args.output/'old-to-new-comparison.json').write_text(json.dumps(result,indent=2)+'\n')
    (args.output/'old-to-new-comparison.md').write_text(markdown(result))
    print(json.dumps({'status':'PASS','summary_sha256':datasets['current']['summary_sha256'],
                      'comparison_sha256':sha((args.output/'old-to-new-comparison.json').read_bytes())}))

if __name__=='__main__':
    main()
