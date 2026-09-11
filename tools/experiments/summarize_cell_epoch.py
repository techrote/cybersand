"""Reduce all registered L3 processes, preserving control bridges and cost flags."""
from __future__ import annotations
import argparse
from collections import defaultdict
import csv
import json
from pathlib import Path
import statistics

from summarize_cell_layout import (sha256, summarize_samples,
                                  work_summary, initial_quantities, final_quantities, ratio_summary)

from cell_epoch import normalized_timing as normalized_timing_record, read_clears, wrap_ticks
import struct, math

def tick_excess(ticks,index):
    neighbors=[int(ticks[j]['ns']) for j in range(max(0,index-2),min(len(ticks),index+3)) if j!=index]
    return int(ticks[index]['ns'])-statistics.median(neighbors)

def epoch_proxy(ticks,bits):
    expected=set(wrap_ticks(bits,int(ticks[-1]['tick']),int(ticks[0]['tick'])))
    return [dict(tick=int(r['tick']),sample=i,tick_ns=int(r['ns']),excess_ns=tick_excess(ticks,i))
            for i,r in enumerate(ticks) if int(r['tick']) in expected]

def durations(values):
    if not values:return None
    ordered=sorted(values)
    return dict(count=len(values),p50=ordered[math.ceil(len(values)*.5)-1],p95=ordered[math.ceil(len(values)*.95)-1],p99=ordered[math.ceil(len(values)*.99)-1],maximum=max(values),total=sum(values))


def summarize(directory):
    plan=json.loads((directory/'plan.json').read_text())
    identity=json.loads((directory/'identity.json').read_text())
    rows=json.loads((directory/'results.json').read_text())
    if len(rows)!=280 or len(plan)!=280 or plan!=identity['plan']:
        raise ValueError('Incomplete or changed L3 campaign')
    references,pairs,groups={},defaultdict(dict),defaultdict(list)
    for index,(row,expected) in enumerate(zip(rows,plan)):
        if any(row[k]!=v for k,v in expected.items()): raise ValueError(f'Plan mismatch: {index}')
        prefix=Path(row['prefix'])
        execution=json.loads(prefix.with_suffix('.execution.json').read_text())
        if execution['exit_code']!=0: raise ValueError(f'Failed process: {index}')
        with prefix.with_suffix('.ticks.csv').open() as stream:
            ticks=list(csv.DictReader(stream))
        if len(ticks)!=2048 or any(int(t['sample'])!=i or int(t['tick'])!=int(ticks[0]['tick'])+i for i,t in enumerate(ticks)):
            raise ValueError(f'Incomplete tick sequence: {index}')
        if row['warmup']!=summarize_samples(ticks[:120]) or row['steady']!=summarize_samples(ticks[120:]):
            raise ValueError(f'Raw timing summary mismatch: {index}')
        record=prefix.with_suffix('.records')
        row['work']=work_summary(record,ticks,row['workers'])
        bits=6 if row['variant']=='e6' else 8
        row['epoch_proxy']=epoch_proxy(ticks,bits)
        row['tick_excess']={str(int(t['tick'])):tick_excess(ticks,i) for i,t in enumerate(ticks)}
        if row['variant']!='legacy8':
            clears,chunks=read_clears(prefix,bits,row['observer']==2,int(ticks[-1]['tick']))
            with record.open('rb') as stream: work=list(struct.iter_unpack('<15Q',stream.read(2048*120)))
            final_chunks=row['startup_and_memory']['cells']//(16384*4)
            for clear in clears:
                expected=final_chunks-sum(w[8] for w in work if w[0]>=clear['tick'])
                if clear['chunks']!=expected:raise ValueError('Clear omitted resident chunks')
            row['direct_clears']=clears
            row['clear_identity_summary']=dict(records=len(chunks),excluded=sum(c['selection']==0 for c in chunks),partial=sum(c['selection']==1 for c in chunks),sleeping=sum(c['active']==0 for c in chunks))
            row['direct_duration_ns']=durations([c['ns'] for c in clears])
            row['clear_records_sha256']={suffix:sha256(prefix.with_suffix(suffix)) for suffix in ('.clears.csv','.clear-chunks.csv')}
        else:row['direct_clears']=[]
        row['raw_sha256']={suffix:sha256(prefix.with_suffix(suffix)) for suffix in ('.records','.ticks.csv','.log','.execution.json')}
        initial=initial_quantities(row['fixture'],row['extent'])
        final=final_quantities(record,2048)
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
            if normalized_timing_record(a,2048)!=normalized_timing_record(b,2048):
                raise ValueError(f'Observer mismatch: {key}')
        elif normalized_timing_record(a,2048)!=normalized_timing_record(b,2048): raise ValueError(f'Exact comparison failed: {key}')
        if key[0]!='epoch' and a.read_bytes()!=b.read_bytes():raise ValueError('Same-schema raw record mismatch')
        if key[0]=='epoch' and any(control['startup_and_memory'][k]!=candidate['startup_and_memory'][k] for k in ('cell_size','alignment','stride')):
            raise ValueError(f'Packing comparison layout confound: {key}')
        ratios={phase:{metric:candidate[phase][metric]/control[phase][metric]
                      for metric in ('p50','p95','p99','maximum','total','ns_per_visited')
                      if control[phase][metric] not in (None,0)} for phase in ('warmup','steady')}
        left={e['tick']:e for e in control['epoch_proxy']}
        right={e['tick']:e for e in candidate['epoch_proxy']}
        # Candidate wrap events versus control excess at the same World tick.
        groups[key[:-1]].append(dict(pair=key[-1],control=control,candidate=candidate,ratios=ratios,
            extra_epoch_proxy_ns=[right[t]['excess_ns']-control['tick_excess'][str(t)] for t in right]))
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
    if len(reduced)!=20: raise ValueError('Not all registered series are present')
    result=dict(scope='L3 epoch-width isolation, direct clear observations and retained-control bridges; no migration approval',
        measured_source=identity['source'],raw_results_sha256=sha256(directory/'results.json'),
        plan_sha256=sha256(directory/'plan.json'),processes=280,exact_epoch_pairs=70,exact_bridge_pairs=14,
        exact_observer_pairs=56,worker_repeat_equality=True,groups=reduced,
        limitations=['Same-schema records retain raw hash equality; cross-epoch comparisons omit only raw state_hash.',
                     'Primary timings have recorders off. Direct on-mode widths occupy separate observer blocks, not interleaved width pairs.',
                     'Extra whole-tick proxy uses candidate wrap ticks and control ordinary-neighbor excess at the same World tick.',
                     'Direct time excludes metadata prepass; whole-tick time includes it. Recorder allocation is reported separately.',
                     'Allocator/PMU and cross-platform gaps remain; no production selection.'])
    (directory/'reduced.json').write_text(json.dumps(result,indent=2)+'\n')
    lines=['# L3 registered comparisons','','Median candidate/control ratios; all seven pairs retained.','',
           '| Comparison | Fixture | Extent | Workers | p50 | p95 | p99 | Total | p95 review pairs |',
           '|---|---|---:|---:|---:|---:|---:|---:|---|']
    for group in reduced:
        comparison,fixture,extent,workers=group['group']
        metrics=group['metrics']['steady']
        lines.append(f'| {comparison} | {fixture} | {extent} | {workers} | '+
                     ' | '.join(f"{metrics[k]['median']:.4f}" for k in ('p50','p95','p99','total'))+
                     f" | {group['review_p95_pairs']} |")
    lines += ['', '| Recorder case | Workers | Width | Clears | Direct p50 ms | Direct p95 ms | Max ms |', '|---|---:|---:|---:|---:|---:|---:|']
    for g in reduced:
        if not g['group'][0].startswith('observer'):continue
        values=[c['ns'] for p in g['paired_results'] for c in p['candidate']['direct_clears']]
        d=durations(values)
        lines.append(f"| {g['group'][1]} | {g['group'][3]} | {g['group'][0]} | {d['count']} | {d['p50']/1e6:.4f} | {d['p95']/1e6:.4f} | {d['maximum']/1e6:.4f} |")
    (directory/'summary.md').write_text('\n'.join(lines)+'\n')
    print('\n'.join(lines))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory',type=Path)
    summarize(parser.parse_args().directory.resolve())
