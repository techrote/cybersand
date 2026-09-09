"""Issue #10 fresh-world screening; use after rebuilding the native CLI/adapter.

Raw logs/manifests belong in validation/local. No published runtime attestation.
"""
import argparse
import json
from pathlib import Path
import subprocess
from run import ROOT, identity, POWDERS, MATERIALS

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('suite', choices=['permeability', 'pairs', 'player'])
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
out = a.output.resolve()
out.mkdir(parents=True, exist_ok=True)
exe = ROOT / 'build/physics_characterisation.exe'
godot = Path('C:/Godot47/Godot_v4.7-stable_win64_console.exe')
artifacts = [exe, godot, ROOT/'godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll']
(out/'manifest.json').write_text(json.dumps(identity(artifacts), indent=2), encoding='utf-8')
specs = []
if a.suite in ('permeability','pairs'):
    for period in [1,10,30,60]:
        for width in [1,32]:
            for seed in range(5):
                specs.append(dict(id=f'period-{period}-w{width}-s{seed}',top=33,bottom=2,
                    layout='packed',depth=32,seed=seed,ticks=2400,workers=1,variant=f'period_{period}',width=width))
    for seed in range(5):
        for layout in ['open','saturated','reentry','excavate']:
            specs.append(dict(id=f'{layout}-s{seed}',top=33,bottom=2,layout=layout,
                depth=32,seed=seed,ticks=2400,workers=1,variant='baseline',width=32))
    for workers in [1,4]:
        specs.append(dict(id=f'parity-{workers}',top=33,bottom=2,layout='packed',depth=32,
            seed=0,ticks=2400,workers=workers,variant='baseline',width=32))
    if a.suite == 'pairs':
        specs = []
        for liquid in [3,8,12,16,20,21,24,30,32,33,36]:
            for powder in [2,13,14,19,23,25,26,27,29]:
                for top,bottom in [(liquid,powder),(powder,liquid)]:
                    specs.append(dict(id=f'pair-{top}-{bottom}',top=top,bottom=bottom,
                        layout='packed',depth=32,seed=0,ticks=1800,workers=1,variant='baseline',width=32))
    (out/'cases.json').write_text(json.dumps(specs,indent=2),encoding='utf-8')
    for spec in specs:
        cmd = [str(exe), str(spec['top']), str(spec['bottom']), spec['layout'], str(spec['depth']),
            str(spec['seed']), str(spec['ticks']), str(spec['workers']), spec['variant'], '1','0',str(spec['width'])]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=180, cwd=ROOT)
        (out/(spec['id']+'.jsonl')).write_text(result.stdout,encoding='utf-8')
        (out/(spec['id']+'.execution.json')).write_text(json.dumps(dict(command=cmd,exit=result.returncode,stderr=result.stderr)),encoding='utf-8')
        if result.returncode: raise RuntimeError(spec['id'])
else:
    for material in POWDERS:
        for seed in range(5):
            specs.append(dict(material=MATERIALS[material],layout='flat',seed=seed))
    for material in ['Sand','Dust','Rust']:
        for layout in ['walk','slope','side','film','falling','enclosed','excavate','reentry']:
            for seed in range(5):
                specs.append(dict(material=MATERIALS[material],layout=layout,seed=seed))
    for minimum in [6,9]: # ceil(0.65 * 9), ceil(0.95 * 9); baseline is eight
        for material in ['Sand','Dust','Rust']:
            for layout in ['flat','slope','side']:
                for seed in range(5):
                    specs.append(dict(material=MATERIALS[material],layout=layout,seed=seed,support_cells=minimum))
    for workers in [1,4]:
        specs.append(dict(material=14,layout='walk',seed=0,workers=workers))
    specs = [s | dict(mode='player',ticks=1800,id=f'player-{i:03d}') for i,s in enumerate(specs)]
    (out/'cases.json').write_text(json.dumps(specs,indent=2),encoding='utf-8')
    for offset in range(0,len(specs),50):
        batch = out/f'batch-{offset}.json'
        batch.write_text(json.dumps(specs[offset:offset+50]),encoding='utf-8')
        cmd = [str(godot),'--headless','--path',str(ROOT/'godot'),'--script','res://tests/test_physics_characterisation.gd','--',str(batch),str(out)]
        (out/f'batch-{offset}.manifest.json').write_text(json.dumps(identity(artifacts),indent=2),encoding='utf-8')
        with (out/f'batch-{offset}.log').open('w',encoding='utf-8') as log:
            log.write(json.dumps(cmd)+'\n'); log.flush()
            result = subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=3600)
        log_text = (out/f'batch-{offset}.log').read_text(encoding='utf-8')
        if result.returncode or 'SCRIPT ERROR' in log_text or 'ERROR:' in log_text: raise RuntimeError(f'batch {offset}')
        print(f'Player {min(offset+50,len(specs))}/{len(specs)}',flush=True)
print(f'Completed {len(specs)} {a.suite} cases',flush=True)
