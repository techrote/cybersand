"""Reduce the registered finite Y1 envelope. Raw events are descriptive attempts.

Only JSON copied observations are consumed; no simulation implementation import.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
from collections import Counter
from pathlib import Path


def quantiles(values):
    ordered = sorted(values)
    if not ordered:
        return None
    return {name: ordered[min(len(ordered)-1, math.ceil(q*len(ordered))-1)]
            for name, q in [('p50', .5), ('p95', .95), ('p99', .99), ('max', 1)]}


def clearance(rows, consecutive=60):
    contact = next((i for i, r in enumerate(rows) if r['pre_overlap'] or r['support']['raw_support']), None)
    if contact is None:
        return {'contact': None, 'status': 'no-contact'}
    run = 0
    start = None
    for i in range(contact, len(rows)):
        if rows[i]['post_overlap'] == 0 and rows[i]['tick_overlap'] == 0:
            run += 1
        else:
            run = 0
        if run == consecutive:
            start = i-consecutive+1
            break
    last_overlap = max((i for i in range(contact,len(rows)) if rows[i]['post_overlap'] or rows[i]['tick_overlap']),default=contact-1)
    terminal = last_overlap+1 if len(rows)-last_overlap-1 >= consecutive else None
    return {'terminal_start':rows[terminal]['tick'] if terminal is not None else None,
            'terminal_latency_samples':terminal-contact if terminal is not None else None,
            'contact': rows[contact]['tick'], 'sustained_start': rows[start]['tick'] if start is not None else None,
            'latency_samples': start-contact if start is not None else None,
            'status': 'cleared' if start is not None else 'right-censored',
            'recurrence': sum(bool(r['tick_overlap'] or r['post_overlap']) for r in rows[start+consecutive:]) if start is not None else None}


def excursions(values, amplitude=1.0):
    """Count alternating excursions exceeding the registered amplitude."""
    if not values:
        return 0
    low = high = values[0]
    direction = 0
    count = 0
    for value in values[1:]:
        low, high = min(low,value), max(high,value)
        if direction >= 0 and high-value > amplitude:
            count += 1
            direction, low = -1, value
        elif direction <= 0 and value-low > amplitude:
            count += 1
            direction, high = 1, value
    return count


def registered_spec_equal(actual, expected):
    # Godot JSON prints the original angle to fewer decimal digits. The body
    # input ABI is float32: require identical carrier bits AND only decimal
    # formatting-sized drift. Never apply this rule to physical observations.
    if set(actual) != set(expected):
        return False
    return all((struct.pack('<f', actual[key]) == struct.pack('<f', expected[key])
                and abs(actual[key]-expected[key]) <= 1e-14)
               if key == 'angle' else actual[key] == expected[key] for key in expected)


def reduce_capture(capture, protocol):
    spec = capture['case']
    registered = next(s for s in protocol['cases'] if s['id'] == spec['id'])
    if not registered_spec_equal(spec, registered) or capture['candidate'] not in protocol['arms'] or not capture['ok']:
        raise ValueError('capture identity/registration failure')
    if not capture['telemetry']:
        raise ValueError('primary reduction needs diagnostic channels')
    rows = capture['rows']
    if len(rows) != int(spec['ticks'])*int(spec['body_count']):
        raise ValueError('incomplete population')
    result = {'case': spec['id'], 'group': spec['group'], 'candidate': capture['candidate'],
              'source': capture['source'], 'runtime': capture['runtime'], 'bodies': [],
              'conservation_failures': sum(not r['conserved'] for r in rows), 'edits': capture['edits']}
    for body in range(1, int(spec['body_count'])+1):
        selected = [r for r in rows if r['body'] == body]
        if [r['tick'] for r in selected] != list(range(int(spec['ticks']))):
            raise ValueError('missing, duplicated or reordered body boundary')
        if any(r['support']['candidate'] != capture['candidate'] or r['support']['yield_factor'] != protocol['arms'][capture['candidate']] for r in selected):
            raise ValueError('selector receipt mismatch')
        impact = selected[:600]
        late = selected[-300:]
        size_x, size_y = 8*spec['size'], 14*spec['size']
        def entry(row):
            x,y,a,*_ = row['in']
            reference = 192
            if spec['layout'] in ('slope','slope-slide'):
                reference += math.floor((x-spec.get('left',96))/4)
            return max(0, y + abs(math.cos(a))*size_y/2 + abs(math.sin(a))*size_x/2-reference)
        ys = [r['out'][1] for r in late]
        contact = next((i for i,r in enumerate(impact) if r['support']['raw_support']),None)
        stop = next((i for i,r in enumerate(impact) if contact is not None and i>=contact and r['out'][4]<=4),None)
        phases = {}
        for name, pred in [('descent-fast',lambda v:v>4),('settling',lambda v:0<v<=4),('rising-or-zero',lambda v:v<=0)]:
            values = [r for r in selected if pred(r['in'][4])]
            phases[name] = {field:sum(r['support'][field] for r in values) for field in ['attempts','no_target','relocation_refused']}
            phases[name]['direct_success'] = sum(r['result'][6] for r in values)
            phases[name]['endpoints'] = [sum(r['support']['endpoints'][i] for r in values) for i in range(5)]
        limiters = Counter()
        for r in selected:
            vy = r['in'][4]
            raw = r['support']['raw_support']
            if vy <= 0 or not raw:
                limiters['inactive'] += 1
                continue
            terms = {'arrest':vy*spec['mass'], 'yield':92/60*spec['mass'] + max(0,vy-92/60)*spec['mass']*protocol['arms'][capture['candidate']],
                     'sample-capacity':2*raw, 'global-cap':20}
            minimum = min(terms.values())
            limiters['+'.join(k for k,v in terms.items() if abs(v-minimum)<1e-8)] += 1
        clear = clearance(selected)
        rest = {'x_span':max(r['out'][0] for r in late)-min(r['out'][0] for r in late),
                'net_x_drift':late[-1]['out'][0]-late[0]['out'][0],
                'y_span':max(ys)-min(ys),'net_y_drift':ys[-1]-ys[0],
                'abs_vy':quantiles([abs(r['out'][4]) for r in late]),
                'correction_active_fraction':sum(r['result'][4]!=0 for r in late)/len(late),
                'overlap_frames':sum(bool(r['tick_overlap']) for r in late),'post_ejection_overlap_frames':sum(bool(r['post_overlap']) for r in late),
                'support':quantiles([r['support']['raw_support'] for r in late])}
        applicable = spec['group'] in ['anchor','mass','scale','orientation','material','historical']
        limits = protocol['decisions']['credible_rest']
        rest['applicable'] = applicable
        rest['within_registered_bounds'] = (rest['y_span']<=limits['y_span_px'] and abs(rest['net_y_drift'])<=limits['abs_net_y_drift_px']
            and rest['abs_vy']['p95']<=limits['p95_abs_vy'] and rest['abs_vy']['max']<=limits['max_abs_vy']
            and rest['correction_active_fraction']<=limits['correction_active_fraction'] and rest['overlap_frames']==0
            and clear.get('recurrence')==0 and clear.get('latency_samples') is not None and clear['latency_samples']<=limits['clearance_latency_max_samples']) if applicable else None
        asym = [r for r in selected if r['support']['raw_support'] and abs(r['support']['left_support']-r['support']['right_support'])>r['support']['raw_support']*.5]
        release = None
        if spec['layout'] in ['excavate','side-excavate','collapse']:
            after = selected[600:]
            release = {'first_post_edit_support':after[0]['support']['raw_support'],'first_post_edit_bearing':after[0]['bearing_y'],
                       'first_post_edit_correction':after[0]['result'][4],'fall_60':after[59]['out'][1]-selected[599]['out'][1],
                       'first_rebearing':next((r['tick'] for r in after if r['support']['raw_support']),None),
                       'response_without_raw_support':sum((r['bearing_y']!=0 or r['result'][4]!=0) and not r['support']['raw_support'] for r in after)}
        hover = longest_hover = 0
        for r in selected:
            above = r['out'][1]+abs(math.cos(r['out'][2]))*size_y/2+abs(math.sin(r['out'][2]))*size_x/2 < 192
            hover = hover+1 if above and not r['support']['raw_support'] and abs(r['out'][4])<.5 else 0
            longest_hover = max(longest_hover,hover)
        result['bodies'].append({'body':body,'peak_entry':max(map(entry,impact)),
            'peak_pre_overlap':max(r['pre_overlap'] for r in impact),'peak_post_overlap':max(r['post_overlap'] for r in impact),
            'stopping_distance':impact[stop]['out'][1]-impact[0]['in'][1] if stop is not None else None,
            'first_no_target':next((r['tick'] for r in selected if r['support']['no_target']),None),
            'clearance':clear,'peak_upward_speed':max(0,-min(r['out'][4] for r in impact[contact:] if contact is not None)) if contact is not None else None,
            'bearing_request_sum':-sum(r['bearing_y'] for r in selected),'accepted_total_coupling_impulse_y':sum(r['result'][2] for r in selected),'limiters':dict(limiters),
            'rest':rest,'release':release,'ejection':phases,
            'lateral_travel_120_479':selected[479]['out'][0]-selected[119]['out'][0],
            'angle_change':selected[-1]['out'][2]-selected[0]['in'][2],
            'peak_abs_omega':max(abs(r['out'][5]) for r in selected),'strong_asymmetry_frames':len(asym),
            'asymmetric_zero_spin_frames':sum(abs(r['out'][5])<1e-5 for r in asym),
            'unsupported_hover_longest':longest_hover,'late_excursions_over_1px':excursions(ys),
            'post_arrest_excursions_over_1px':excursions([r['out'][1] for r in impact[stop:]]) if stop is not None else None,
            'area':size_x*size_y,'perimeter':2*(size_x+size_y),'initial_momentum':spec['mass']*spec['speed'],
            'boundaries':quantiles([r['support']['boundaries'] for r in selected]),'sample_capacity':2,'response_without_current_support':sum((r['bearing_y']!=0 or r['result'][4]!=0) and not r['support']['raw_support'] for r in selected),
            'support_distribution':dict(Counter(r['support']['raw_support'] for r in selected)),
            'late_angle_span':max(r['out'][2] for r in late)-min(r['out'][2] for r in late)})
    first = [r for r in rows if r['body']==1]
    result['timing_us'] = {name:quantiles([r['times_us'][i] for r in first]) for i,name in enumerate(['rapier-and-control','coupling','cellular','application'])}
    result['work'] = {name:{'total':sum(r['work'][i] for r in first),'max':max(r['work'][i] for r in first)} for i,name in enumerate(['scanned','moves','active-blocks'])}
    result['relocation_refusals'] = sum(r['support']['relocation_refused'] for r in rows)
    result['maximum_search_candidates_per_attempt_observed'] = max((sum(r['support']['endpoints'])/r['support']['attempts'] for r in rows if r['support']['attempts']),default=0)
    return result


def physical_rows(capture):
    return [{k:v for k,v in row.items() if k not in ['times_us','support']} for row in capture['rows']]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--protocol', type=Path,required=True)
    parser.add_argument('--input',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args = parser.parse_args()
    protocol = json.loads(args.protocol.read_text(encoding='utf-8-sig'))
    captures = []
    for spec in protocol['cases']:
        for arm in protocol['arms']:
            path = args.input/f'{spec["id"]}-{arm}.json'
            capture = json.loads(path.read_text())
            if capture['protocol_sha256'] != hashlib.sha256(args.protocol.read_bytes()).hexdigest():
                raise ValueError('protocol byte hash mismatch')
            result = reduce_capture(capture,protocol)
            result['raw_sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
            captures.append(result)
    comparisons = []
    for spec in protocol['cases']:
        b,y = [next(r for r in captures if r['case']==spec['id'] and r['candidate']==a) for a in ['B0','Y1']]
        bb,yy = b['bodies'][0],y['bodies'][0]
        comparison = {'case':spec['id'],'group':spec['group'],
            'entry_reduction_fraction':1-yy['peak_entry']/bb['peak_entry'] if bb['peak_entry'] else None,
            'pre_overlap_B0_Y1':[bb['peak_pre_overlap'],yy['peak_pre_overlap']],
            'post_overlap_B0_Y1':[bb['peak_post_overlap'],yy['peak_post_overlap']],
            'rest_B0_Y1':[bb['rest']['within_registered_bounds'],yy['rest']['within_registered_bounds']],
            'coupling_p95_ratio':y['timing_us']['coupling']['p95']/max(1,b['timing_us']['coupling']['p95']),
            'scanned_ratio':y['work']['scanned']['total']/max(1,b['work']['scanned']['total'])}
        if spec['group']=='negative':
            raw = [json.loads((args.input/f'{spec["id"]}-{arm}.json').read_text()) for arm in ['B0','Y1']]
            comparison['exact_physical_equivalence'] = physical_rows(raw[0])==physical_rows(raw[1])
            comparison['zero_bearing'] = all(r['bearing_y']==0 and r['support']['raw_support']==0 for c in raw for r in c['rows'])
        comparisons.append(comparison)
    result = {'schema':1,'protocol_sha256':hashlib.sha256(args.protocol.read_bytes()).hexdigest(),
              'captures':captures,'comparisons':comparisons,
              'status':'AWAITING OWNER GAMEPLAY ACCEPTANCE','owner_verdict':None}
    args.output.write_text(json.dumps(result,indent=2)+'\n')


if __name__=='__main__':
    main()
