"""Verify/reduce issue #10 evidence, retaining reaction and ROI accounting limits."""
import argparse
import csv
import hashlib
import json
from pathlib import Path

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('raw',type=Path)
p.add_argument('output',type=Path)
p.add_argument('--browser-suffix',default='accepted',help='Raw browser result series, preserved separately for each export')
p.add_argument('--async-result',default='desktop-player-async-final.json',help='Raw desktop trace filename')
a=p.parse_args(); out=a.output; out.mkdir(parents=True,exist_ok=True)
errors=[]; checks=0
def require(ok,message):
    global checks
    checks+=1
    if not ok: errors.append(message)
def read(path): return json.loads(path.read_text(encoding='utf-8'))
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
powders={2,13,14,19,23,25,26,27,29}
native=[]; data_by_id={}; water_controls=0; reactive_water=0
for group in ['native-expanded','permeability','pairs']:
    folder=a.raw/group
    for spec in read(folder/'cases.json'):
        path=folder/(spec['id']+'.jsonl')
        data=[json.loads(l) for l in path.read_text(encoding='utf-8').splitlines()]
        first,last,result=data[0],data[-2],data[-1]
        require(read(folder/(spec['id']+'.execution.json'))['exit']==0,f'{path}: execution')
        require(result['completed_ticks']==spec['ticks'],f'{path}: incomplete')
        require(result['overflow']==0,f'{path}: telemetry overflow')
        delta=[0]*81; conversions=0; water_reacts=False; swaps=0
        for key,n in result['histogram']:
            kind=key>>24; source=(key>>16)&255; target=(key>>8)&255
            if kind==2:
                swaps+=n
                require(not(source in powders and target in powders),f'{path}: powder swap')
            if kind==3:
                delta[source]-=n; delta[target]+=n; conversions+=n
                water_reacts |= source==3 or target==3
        # Native FreeMass changes occupied Water cell count during transport.
        # Its mass is tested separately; reaction counts are not SI mass units.
        if spec['layout']=='packed':
            for material in range(1,81):
                if material!=3:
                    require(first['counts'][material]+delta[material]==last['counts'][material],f'{path}: material {material} accounting')
        if spec['layout']!='excavate' and first['water_mass'] and not water_reacts:
            water_controls+=1
            require(all(d['water_mass']==first['water_mass'] for d in data[:-1]),f'{path}: nonreactive Water mass')
        reactive_water+=int(water_reacts)
        row=dict(group=group,id=spec['id'],top=spec['top'],bottom=spec['bottom'],layout=spec['layout'],
            seed=spec['seed'],workers=spec.get('workers',1),variant=spec['variant'],ticks=spec['ticks'],
            breakthrough=result['breakthrough_tick'],swaps=swaps,conversions=conversions,
            initial_water_mass=first['water_mass'],final_water_mass=last['water_mass'],
            chunk_allocations=result['chunk_allocations'],max_cores=result['max_cores'],
            histogram_used=result['histogram_used'],tick_us_p95=result['tick_us_p95'],sha256=sha(path))
        native.append(row);data_by_id[(group,spec['id'])]=data
for period in [1,10,30,60]:
    for width in [1,32]:
        for seed in range(5):
            d=data_by_id['permeability',f'period-{period}-w{width}-s{seed}']
            require(d[-1]['breakthrough_tick']==32*period,f'period {period}/width {width}/seed {seed}')
one=data_by_id['permeability','parity-1']; four=data_by_id['permeability','parity-4']
require(one[:-1]==four[:-1],'native matching-worker state/sample parity')
require(sorted(one[-1]['histogram'])==sorted(four[-1]['histogram']),'native histogram parity')
require(one[:-1]==data_by_id['permeability','period-30-w32-s0'][:-1],'native repeated configuration')
players=[]; player_data=[]
for spec in read(a.raw/'player/cases.json'):
    path=a.raw/'player'/(spec['id']+'.json'); d=read(path);player_data.append(d)
    require(d['ok'] and d['completed_ticks']==1800,f'{path}: completion')
    require(d['final']['overflow']==0,f'{path}: overflow')
    if spec['layout'] in ('flat','walk','reentry','enclosed'):
        require(d['final_depth']<=1 and d['floor_contact_tick']<0,f'{path}: ordinary support')
    if spec['layout']=='excavate': require(d['final_depth']>20,f'{path}: excavation')
    if spec['layout'] in ('falling','film'): require(d['final_depth']>100,f'{path}: loose powder blocks descent')
    if spec['layout']=='slope' and spec.get('support_cells',8)==8:
        require(d['max_overlap']==0 and d['grounded_ticks']>1400,f'{path}: slope support')
    players.append(dict(id=spec['id'],material=spec['material'],layout=spec['layout'],seed=spec['seed'],
        support_cells=spec.get('support_cells',8),workers=spec.get('workers',1),
        peak_depth=d['peak_depth'],final_depth=d['final_depth'],grounded_ticks=d['grounded_ticks'],
        max_overlap=d['max_overlap'],floor_tick=d['floor_contact_tick'],sha256=sha(path)))
require(player_data[-1]['rows']==player_data[-2]['rows'] and player_data[-1]['final']['hash']==player_data[-2]['final']['hash'],'sampled player worker parity')
browsers=[]
for profile in ['compat','threaded']:
    d=read(a.raw/f'browser-{profile}-{a.browser_suffix}/browser-result.json')
    require(d['isolated'] and d['result']['ok'],f'browser {profile}')
    r=d['result']['results'][0]
    require(r['fault']['ok'] and r['regions']['ok'] and not r['failures'],f'browser {profile} F01/F02/policy')
    require(r['mercury_front']==list(range(1,33)),f'browser {profile} Mercury')
    browsers.append(d)
for field in ['cell_hash','mercury_front','player','pairs']:
    require(browsers[0]['result']['results'][0][field]==browsers[1]['result']['results'][0][field],f'Web profile equality: {field}')
async_data=read(a.raw/a.async_result)
require(async_data['ok'] and len(async_data['results'])==3,'desktop asynchronous players')
for r in async_data['results']:
    require(r['completed_ticks']==240 and r['ok'],'async completion/support/walk/excavation')
def write_csv(name,rows):
    with (out/name).open('w',newline='',encoding='utf-8') as file:
        writer=csv.DictWriter(file,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
write_csv('native-results.csv',native);write_csv('player-results.csv',players)
summary=dict(ok=not errors,checks=checks,errors=errors,native_runs=len(native),player_runs=len(players),
    native_ticks=sum(r['ticks'] for r in native),player_ticks=1800*len(players),
    nonreactive_water_controls=water_controls,reactive_water_runs=reactive_water,
    max_chunk_allocations=max(r['chunk_allocations'] for r in native),max_cores=max(r['max_cores'] for r in native),
    max_histogram_used=max(r['histogram_used'] for r in native),
    max_native_tick_us_p95=max(r['tick_us_p95'] for r in native),
    mercury_breakthrough_ticks={str(p):32*p for p in [1,10,30,60]},
    browser_profiles=browsers,async_results=[{k:v for k,v in r.items() if k!='trace'} for r in async_data['results']],
    limits=['Water occupied-cell counts are not mass; reactive Water has explicit material conversion, not a Water-mass conservation claim.',
        'Excavation/open geometry uses a finite observation ROI; escaped counts are not deletion evidence.',
        'Native/Web hashes are compared within their platform/configuration, not across native-size_t and Wasm-size_t widths.',
        'The moving-barrel player probe drives copied occupancy samples, not calibrated Rapier player pushing/carrying.'])
(out/'results.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
fig,ax=plt.subplots(figsize=(8,4.3))
for period in [1,10,30,60]:
    data=data_by_id['permeability',f'period-{period}-w32-s0'][:-1]
    ax.plot([d['tick']/60 for d in data],[d['top_front'] for d in data],label=f'{period} tick opportunity')
ax.set(xlabel='Simulation time at 60 ticks/s (seconds)',ylabel='Mercury front into 32-cell Sand bed (cells)',ylim=(0,34),xlim=(0,40))
ax.set_title('Version 1 permeability screening · five seeds agree on breakthrough')
ax.legend();ax.grid(alpha=.2);fig.tight_layout();fig.savefig(out/'mercury-front.png',dpi=160);plt.close(fig)
print(json.dumps({k:v for k,v in summary.items() if k not in ['browser_profiles','limits']},indent=2))
raise SystemExit(bool(errors))
