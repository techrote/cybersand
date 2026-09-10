"""Reduce all registered L2 processes, preserving control bridges and cost flags."""
from __future__ import annotations
import argparse
from collections import defaultdict
import csv
import json
from pathlib import Path
import statistics

from summarize_cell_layout import (sha256, normalized_timing_record, summarize_samples,
                                  epoch_proxy, work_summary, initial_quantities, final_quantities, ratio_summary)


def summarize(directory):
    plan=json.loads((directory/'plan.json').read_text())
    identity=json.loads((directory/'identity.json').read_text())
    rows=json.loads((directory/'results.json').read_text())
    if len(rows)!=448 or len(plan)!=448 or plan!=identity['plan']:
        raise ValueError('Incomplete or changed L2 campaign')
    references,pairs,groups={},defaultdict(dict),defaultdict(list)
    for index,(row,expected) in enumerate(zip(rows,plan)):
        if any(row[k]!=v for k,v in expected.items()): raise ValueError(f'Plan mismatch: {index}')
        prefix=Path(row['prefix'])
        execution=json.loads(prefix.with_suffix('.execution.json').read_text())
        if execution['exit_code']!=0: raise ValueError(f'Failed process: {index}')
        with prefix.with_suffix('.ticks.csv').open() as stream:
            ticks=list(csv.DictReader(stream))
        if len(ticks)!=1920 or any(int(t['sample'])!=i or int(t['tick'])!=int(ticks[0]['tick'])+i for i,t in enumerate(ticks)):
            raise ValueError(f'Incomplete tick sequence: {index}')
        if row['warmup']!=summarize_samples(ticks[:120]) or row['steady']!=summarize_samples(ticks[120:]):
            raise ValueError(f'Raw timing summary mismatch: {index}')
        record=prefix.with_suffix('.records')
        row['work']=work_summary(record,ticks,row['workers'])
        row['epoch_proxy']=epoch_proxy(ticks)
        row['raw_sha256']={suffix:sha256(prefix.with_suffix(suffix)) for suffix in ('.records','.ticks.csv','.log','.execution.json')}
        initial=initial_quantities(row['fixture'],row['extent'])
        final=final_quantities(record,1920)
        if any(initial[k]!=final[k] for k in ('sand_cells','water_mass')):
            raise ValueError(f'Whole-world quantity mismatch: {index}')
        row['quantity_ledger']=dict(initial=initial,final=final,smoke_lifecycle_net_loss=initial['smoke_cells']-final['smoke_cells'],
                                   scope='Final whole-world quantities; no per-tick semantic traversal in timed runs')
        repeat_key=(row['variant'],row['fixture'],row['extent'],row['observer'])
        if repeat_key in references:
            if record.read_bytes()!=references[repeat_key].read_bytes():
                raise ValueError(f'Worker/repeat state/work mismatch: {repeat_key}')
        else: references[repeat_key]=record
        key=(row['comparison'],row['fixture'],row['extent'],row['workers'],row['pair'])
        if row['member'] in pairs[key]: raise ValueError(f'Duplicate member: {key}')
        pairs[key][row['member']]=row
    for key,members in pairs.items():
        if set(members)!={0,1}: raise ValueError(f'Missing pair member: {key}')
        control,candidate=members[0],members[1]
        a,b=(Path(r['prefix']).with_suffix('.records') for r in (control,candidate))
        if key[0].startswith('observer'):
            if normalized_timing_record(a,1920)!=normalized_timing_record(b,1920):
                raise ValueError(f'Observer mismatch: {key}')
        elif a.read_bytes()!=b.read_bytes(): raise ValueError(f'Exact comparison failed: {key}')
        if key[0].startswith('packing') and any(control['startup_and_memory'][k]!=candidate['startup_and_memory'][k] for k in ('cell_size','alignment','stride')):
            raise ValueError(f'Packing comparison layout confound: {key}')
        ratios={phase:{metric:candidate[phase][metric]/control[phase][metric]
                      for metric in ('p50','p95','p99','maximum','total','ns_per_visited')
                      if control[phase][metric] not in (None,0)} for phase in ('warmup','steady')}
        left={e['tick']:e for e in control['epoch_proxy']}
        right={e['tick']:e for e in candidate['epoch_proxy']}
        if left.keys()!=right.keys(): raise ValueError(f'Wrap schedule mismatch: {key}')
        groups[key[:-1]].append(dict(pair=key[-1],control=control,candidate=candidate,ratios=ratios,
            extra_epoch_proxy_ns=[right[t]['excess_ns']-left[t]['excess_ns'] for t in left]))
    reduced=[]
    for key,values in groups.items():
        values.sort(key=lambda r:r['pair'])
        if [v['pair'] for v in values]!=list(range(7)): raise ValueError(f'Incomplete series: {key}')
        metrics={phase:{metric:ratio_summary([v['ratios'][phase][metric] for v in values])
                        for metric in values[0]['ratios'][phase]} for phase in ('warmup','steady')}
        excess=[n for v in values for n in v['extra_epoch_proxy_ns']]
        reduced.append(dict(group=key,metrics=metrics,paired_results=values,
            review_p95_pairs=[v['pair'] for v in values if v['ratios']['steady']['p95']>1.15],
            median_p95_review=metrics['steady']['p95']['median']>1.15,
            extra_epoch_proxy=ratio_summary(excess),extra_epoch_proxy_over_1ms_count=sum(n>1_000_000 for n in excess)))
    if len(reduced)!=32: raise ValueError('Not all registered series are present')
    result=dict(scope='L2 matched-alignment packing and representative retained-control bridges; no migration approval',
        measured_source=identity['source'],raw_results_sha256=sha256(directory/'results.json'),
        plan_sha256=sha256(directory/'plan.json'),processes=448,exact_packing_pairs=140,exact_bridge_pairs=28,
        exact_observer_pairs=56,worker_repeat_equality=True,groups=reduced,
        limitations=['16/40/8 uses legacy IDs and the8-bit Material enum; no end-to-end wider-ID cost or demand is proved.',
                     'Bridge combines shared accessor and type-alignment changes in two representative cases only.',
                     'Wrap figures are source-scheduled whole-tick neighbor-excess proxies, not direct clear observations.',
                     'Process memory includes harness/allocator retention; allocator and PMU gaps remain.',
                     'Paired ratios are descriptive; no confidence interval, production threshold or cross-platform acceptance.'])
    (directory/'reduced.json').write_text(json.dumps(result,indent=2)+'\n')
    lines=['# L2 registered comparisons','','Median candidate/control ratios; all seven pairs retained.','',
           '| Comparison | Fixture | Extent | Workers | p50 | p95 | p99 | Total | p95 review pairs |',
           '|---|---|---:|---:|---:|---:|---:|---:|---|']
    for group in reduced:
        comparison,fixture,extent,workers=group['group']
        metrics=group['metrics']['steady']
        lines.append(f'| {comparison} | {fixture} | {extent} | {workers} | '+
                     ' | '.join(f"{metrics[k]['median']:.4f}" for k in ('p50','p95','p99','total'))+
                     f" | {group['review_p95_pairs']} |")
    (directory/'summary.md').write_text('\n'.join(lines)+'\n')
    print('\n'.join(lines))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory',type=Path)
    summarize(parser.parse_args().directory.resolve())
