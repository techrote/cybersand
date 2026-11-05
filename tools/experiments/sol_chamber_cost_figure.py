#!/usr/bin/env python3
"""Standalone scientific cost plot from all registered episode means."""
import argparse
import json
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('summary',type=Path);parser.add_argument('output',type=Path);args=parser.parse_args()
    assert not args.output.exists()
    data=json.loads(args.summary.read_text(encoding='utf-8'));assert data['full_registered_matrix'] and data['all_pairs_equivalent']
    groups=[(p,o) for p in ['windows','linux'] for o in ['full','minimal']]
    stages=['preparation_us','native_tick_us','response_generation_us','application_us','rapier_us','statistics_us']
    fig,(left,right)=plt.subplots(1,2,figsize=(12,4.7),gridspec_kw={'width_ratios':[1.6,1]},layout='constrained')
    labels=[]
    for row,(platform,observer) in enumerate(groups):
        episodes=[e for e in data['episodes'] if e['platform']==platform and e['observer']==observer];assert len(episodes)==12
        mean=lambda key:sum(e['timings'][key]['mean_us'] for e in episodes)/len(episodes)
        core=sum(mean(k) for k in stages);observer_us=mean('observer_us');export=mean('export_us');other=mean('elapsed_us')-core-observer_us-export
        cursor=0
        for name,value,color in [('Six timed API stages',core,'#236c9b'),('Five-boundary observation',observer_us,'#d0a750'),('Scheduled CYPS export',export,'#68977f'),('Other step work',other,'#a4a8ad')]:
            left.barh(row,value/1000,left=cursor,color=color,label=name if row==0 else None);cursor+=value/1000
        right.scatter([e['timings']['response_generation_us']['mean_us'] for e in episodes],[row]*len(episodes),s=22,alpha=.7,color='#236c9b' if observer=='full' else '#68977f')
        labels.append(platform.title()+' / '+observer)
    left.set_yticks(range(4),labels);left.invert_yaxis();right.set_yticks(range(4),labels);right.invert_yaxis()
    left.set_xlabel('Mean recorded step (ms; 12 episodes per row)');right.set_xlabel('Response generation mean (microseconds)')
    left.set_title('Observation dominates this apparatus');right.set_title('Getter includes passive solve + packet')
    left.legend(loc='upper left',bbox_to_anchor=(0,-.21),ncol=2,fontsize=8,frameon=False)
    for ax in [left,right]:ax.grid(axis='x',alpha=.2);ax.set_axisbelow(True)
    fig.suptitle('48 matched sessions / 24 equivalent observer pairs — shared host, one actual participant\nSingle-body surrogate; not original SOL CPU qualification',fontsize=11)
    fig.savefig(args.output,dpi=160);plt.close(fig)
    print(json.dumps(dict(matplotlib=matplotlib.__version__,source=str(args.summary),output=str(args.output))))

if __name__=='__main__':main()
