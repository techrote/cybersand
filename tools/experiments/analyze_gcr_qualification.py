"""Compact paired GCR receipts; a capture completion is separate from efficacy."""
import argparse
import hashlib
import json
import math
from pathlib import Path


def percentile(values, q):
    ordered = sorted(values)
    return ordered[min(len(ordered)-1, max(0, math.ceil(q*len(ordered))-1))] if ordered else None


def timings(values):
    return {name: percentile(values, q) for name, q in [('p50', .5), ('p95', .95), ('p99', .99), ('max', 1)]}


def summarize(report):
    rows = report['rows']
    warm = [row for row in rows if row['tick'] >= 120]
    pre_hard = []
    for row in rows:
        if row.get('hard_floor_contact'): break
        pre_hard.append(row)
    def peak(name, population=None):
        return max((row.get(name, 0) for row in (rows if population is None else population)), default=0)
    totals = [0., 0., 0.]
    for row in rows:
        result = row.get('result', [])
        if len(result) >= 9:
            totals[0] += result[1]
            totals[1] += result[2]
        if len(result) >= 13: totals[2] += result[9]
    result = {'case': report['case']['id'], 'candidate': report['candidate'],
              'mode': report['mode'], 'complete': bool(report.get('ok')) and (int(report.get('completed_ticks',0)) >= 1800 if report['mode']=='desktop-asynchronous' else len(rows) == 1800*int(report['case'].get('body_count', 1))),
              'conserved': all(row.get('conserved', False) for row in rows),
              'peak_horizontal_entry': peak('horizontal_depth', pre_hard), 'peak_vertical_entry': peak('vertical_depth', pre_hard),
              'total_peak_horizontal_entry': peak('horizontal_depth'), 'total_peak_vertical_entry': peak('vertical_depth'),
              'peak_pre_overlap': peak('pre_overlap'), 'peak_post_overlap': peak('post_overlap'),
              'peak_tick_overlap': peak('tick_overlap'),
              'first_unresolved_tick': next((row['tick'] for row in rows if len(row.get('result', [])) >= 9 and row['result'][7] > 0), None),
              'first_hard_floor_tick': next((row['tick'] for row in rows if row.get('hard_floor_contact')), None),
              'pre_hard_peak_abs_omega': max((abs(row['out'][5]) for row in pre_hard), default=0),
              'total_applied_result_Jx_Jy_L': totals,
              'late_peak_speed': max((math.hypot(row['out'][3], row['out'][4]) for row in rows if row['tick'] >= 1500), default=0),
              'late_peak_abs_omega': max((abs(row['out'][5]) for row in rows if row['tick'] >= 1500), default=0),
              'age_histogram': {str(age): sum(row.get('age') == age for row in rows) for age in range(10)},
              'timing_us': {name: timings([row['times_us'][i] for row in warm if 'times_us' in row]) for i, name in enumerate(['rapier', 'coupling', 'native_tick', 'main_application'])},
              'work': {name: timings([row['work'][i] for row in warm if 'work' in row]) for i, name in enumerate(['scanned', 'moves', 'active_blocks'])},
              'edits': report.get('edits', []), 'final': report.get('final', {})}
    # Preserve compact diagnostic extrema without presuming unknown fields to
    # be calibrated physical quantities. Raw signed traces remain in the bundle.
    support = [row.get('support', {}) for row in rows]
    keys = sorted({key for d in support if isinstance(d, dict) for key, value in d.items() if isinstance(value, (int, float))})
    result['diagnostic_extrema'] = {key: {'min': min(d[key] for d in support if isinstance(d, dict) and key in d),
                                                'max': max(d[key] for d in support if isinstance(d, dict) and key in d)} for key in keys}
    gcr = [row['gcr'] for row in rows if 'gcr' in row]
    result['gcr_ledger_totals'] = {key: sum(d.get(key, 0) for d in gcr) for key in
                                 ['normal_raw','normal_accepted','normal_rejected','tangent_raw','tangent_accepted','tangent_rejected','passive_torque','event_torque','torque','bins','updates']}
    result['peak_abs_local_slip'] = max((abs(v) for row in rows for v in row.get('local_slip',[])), default=None)
    result['passivity_rejections'] = sum(bool(d.get('passivity_rejected')) for d in gcr)
    result['timing_us']['total_measured_components'] = timings([sum(row['times_us']) for row in warm if 'times_us' in row])
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('campaign', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    campaign = json.loads(args.campaign.read_text())
    receipts, failures = [], []
    for capture in campaign['captures']:
        if capture['status'] != 'captured':
            failures.append(capture)
            continue
        path = args.campaign.parent / capture['raw']
        if hashlib.sha256(path.read_bytes()).hexdigest() != capture['raw_sha256']:
            raise RuntimeError('Raw receipt changed: ' + str(path))
        report = json.loads(path.read_text())
        if report['protocol_sha256'] != campaign['identity']['protocol_sha256'] or report['input_identity'] != campaign['identity']['input_identity']:
            raise RuntimeError('Mixed source/protocol inputs: ' + str(path))
        row = summarize(report)
        row['repeat'] = capture['repeat']
        row['raw_sha256'] = capture['raw_sha256']
        receipts.append(row)
    pairs = []
    grouped = {(row['case'], row['candidate'], row['repeat']): row for row in receipts}
    for (case, arm, repeat), y1 in grouped.items():
        if arm != 'Y1' or (case, 'GCR', repeat) not in grouped: continue
        gcr = grouped[(case, 'GCR', repeat)]
        yentry, gentry = y1['peak_horizontal_entry'], gcr['peak_horizontal_entry']
        pair = {'case': case, 'repeat': repeat, 'horizontal_improvement_fraction': (yentry-gentry)/yentry if yentry else None,
                'horizontal_nonworsening': gentry-yentry <= max(.5, .1*yentry),
                'vertical_nonworsening': gcr['peak_vertical_entry']-y1['peak_vertical_entry'] <= max(.5, .1*y1['peak_vertical_entry']),
                'pre_overlap_nonworsening': gcr['peak_pre_overlap']-y1['peak_pre_overlap'] <= max(1, .1*y1['peak_pre_overlap']),
                'post_overlap_nonworsening': gcr['peak_post_overlap']-y1['peak_post_overlap'] <= max(1, .1*y1['peak_post_overlap'])}
        if case in {'sand-horizontal', 'dust-horizontal', 'rust-horizontal'}:
            pair['registered_25percent_horizontal_gate'] = pair['horizontal_improvement_fraction'] is not None and pair['horizontal_improvement_fraction'] >= .25
        before = y1['timing_us']['coupling']['p95']
        after = gcr['timing_us']['coupling']['p95']
        pair['timing_investigation_required'] = before is not None and after is not None and after > before*1.25 and after-before > 25
        work_before, work_after = y1['work']['scanned']['p95'], gcr['work']['scanned']['p95']
        pair['scanned_work_investigation_required'] = work_before is not None and work_after is not None and work_after > work_before*2
        pairs.append(pair)
    summary = {'schema': 1, 'identity': campaign['identity'], 'capture_complete': campaign['complete'],
               'failures': failures, 'receipts': receipts, 'pairs': pairs,
               'disposition': 'MEASURED ONLY; owner feel, torque causality, category/state and platform gates require separate review',
               'gaps': ['Local contact slip and separate normal/tangent/moment ledgers depend on native diagnostic fields.',
                        'Moving-grain feedback is not physical parcel momentum conservation.',
                        'Automated trajectories do not establish owner gameplay preference.']}
    args.output.write_text(json.dumps(summary, indent=2))
    print(f'{len(receipts)} captures, {len(pairs)} pairs, {len(failures)} failures; {args.output}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
