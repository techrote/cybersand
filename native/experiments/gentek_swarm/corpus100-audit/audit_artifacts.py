#!/usr/bin/env python3
"""Verify exact retained execution receipts and rendered native-cell artifacts."""
from pathlib import Path
from collections import Counter
import hashlib,json,re,struct,subprocess
from PIL import Image

OUT=Path('/workspace/scratch/3a7df071dddd/corpus100-qualified')
REPO=Path('/workspace/scratch/3a7df071dddd/cybersand')
REVIEW=Path('/workspace/scratch/3a7df071dddd/review')
COUNT=Counter()
def sha(b):return hashlib.sha256(b).hexdigest()
def check(ok,message):
    COUNT['assertions']+=1
    if not ok:raise AssertionError(message)
def binary(record,expected):
    b=(OUT/record['file']).read_bytes()
    check(sha(b)==record['sha256'],record['file']+' sha256')
    check(b==struct.pack('<'+'H'*len(expected),*expected),record['file']+' exact material bytes')
    check(record['retained_cell_count']==len(expected),record['file']+' retained count')
    COUNT['binary_arrays']+=1

run=json.loads((OUT/'manifest.json').read_text())
check(run['result']=='PASS' and run['clean_source'],'exact source qualification did not pass')
check(run['source_commit']=='c02b8bdb3541999fb49f86c98a66706a09e59e96','source HEAD drift')
check(run['registration_commit']=='759a2ae0b354ad2ead83929a6e854607e058defa','registration commit drift')
check(sha((OUT/'registration.json').read_bytes())==run['registration_sha256'],'registration content drift')
for path,digest in run['source_inputs'].items():
    b=subprocess.check_output(['git','-C',str(REPO),'show',run['source_commit']+':'+path])
    check(sha(b)==digest,path+' committed-source hash');COUNT['source_inputs']+=1
for command in run['commands']:
    check(command.get('exit_code')==0 and not command.get('timed_out'),command['label']+' command failure')
    check(sha((OUT/command['log']).read_bytes())==command['log_sha256'],command['label']+' log hash');COUNT['command_receipts']+=1
for name,digest in run['binaries'].items():
    check(sha((Path(run['fresh_build_directory'])/name).read_bytes())==digest,name+' compiled binary hash');COUNT['binaries']+=1
for label in ('native-tests','sanitizer-tests'):
    c=next(c for c in run['commands'] if c['label']==label)
    log=(OUT/c['log']).read_text()
    check(len(re.findall(r'^PASS ',log,re.M))==23,label+' named test groups')
    check(not re.search(r'^FAIL |ERROR: AddressSanitizer|runtime error:',log,re.M),label+' diagnostic failure')

header=(REPO/'native/include/cybersand/material.hpp').read_text()
entries=re.findall(r'\{"([^\"]+)", MaterialState::\w+, [^,]+, \{(\d+), (\d+), (\d+), (\d+)\}',header)
check(len(entries)==132,'native material palette shape')
palette=[tuple(map(int,(r,g,b))) for _,r,g,b,_ in entries]
bg=(13,18,25);base={'FRAMEWEAVER':(113,176,220),'MOSAIC':(220,175,111),'RECEPTOR':(135,195,151)}
reg=json.loads((OUT/'registration.json').read_text())
for c in reg['cases']:
    cid=c['case_id'];p=OUT/'native'/(cid+'.json');raw=p.read_bytes();d=json.loads(raw)
    for replay in ('replay','sanitized'):
        check((OUT/replay/p.name).read_bytes()==raw,cid+' '+replay+' independent byte replay');COUNT[replay+'_raw_matches']+=1
    rec=json.loads((OUT/'case_records'/p.name).read_text())
    check(rec['raw_sha256']==sha(raw),cid+' case-record raw binding')
    pair=d['type']=='pair';q=d['left_request'] if pair else d['request'];rs=[d['left'],d['right']] if pair else [d['result']]
    cells=d['cells'] if pair else rs[0]['cells'];w,h=q['width'],q['height'];n=w*h
    binary(rec['native_material_array'],cells)
    if cells:
        expected=[palette[m or q['context'][i]] if m or q['context'][i] else bg for i,m in enumerate(cells)]
        im=Image.open(OUT/rec['images']['native_material_png']).convert('RGB')
        check(im.size==(w,h) and list(im.getdata())==expected,cid+' exact native PNG palette/cells')
        COUNT['native_png_pixel_matches']+=1;COUNT['native_png_pixels']+=n
    else:
        check(rec['native_image_is_refusal_placeholder'] and not rec['native_material_array_emitted'],cid+' missing-array semantics')
        COUNT['labelled_refusal_placeholders']+=1
    generated=[0]*n;cohesion=[0]*n;shared=[0]*n;adapters=[0]*n;late_cohesion=[0]*n;late=[0]*n
    sem=[(67,72,80) if m else bg for m in q['context']]
    for side,r in enumerate(rs):
        old=d['initial_left' if side==0 else 'initial_right']['cells'] if pair else r['cells']
        instances={p['id']:p for p in r['instances']}
        for i,m in enumerate(r['cells']):
            if not m:continue
            generated[i]=m;role=r['roles'][i];owner=r['provenance'][i]
            is_bridge=instances[owner]['kind']=='typed-seam-joint'
            is_late=pair and not old[i]
            if is_late:late[i]=m
            if role==4:cohesion[i]=m
            if is_late and role==4:late_cohesion[i]=m
            if is_bridge:shared[i]=m;colour=(81,221,191)
            elif role==4:colour=(222,111,190)
            elif is_late:adapters[i]=m;colour=(195,145,255)
            else:
                shift=owner*17%37-18;colour=tuple(max(0,min(255,v+shift)) for v in base[r['gentek']])
            sem[i]=colour
    im=Image.open(OUT/rec['images']['semantic_provenance_overlay']).convert('RGB')
    if cells:
        check(im.size==(w,h) and list(im.getdata())==sem,cid+' semantic owner/role/bridge/adapter PNG')
        COUNT['semantic_png_pixel_matches']+=1;COUNT['semantic_png_pixels']+=n
    else:
        check(list(im.getdata())==list(Image.open(OUT/rec['images']['native_material_png']).convert('RGB').getdata()),cid+' semantic refusal placeholder')
    for key,expected in (('generated_union',generated),('cohesion_cells',cohesion)):
        binary(rec['attribution_arrays'][key],expected if cells else [])
    if pair:
        arrays={'clipped_cells':d['clipped_cells'],'initial_cells':d['initial_cells'],
                'shared_bridge_cells':shared,'late_adapter_cells_excluding_cohesion':adapters,
                'late_cohesion_cells':late_cohesion,'total_late_additions':late,
                'native_architecture_without_shared_bridges':[0 if shared[i] else v for i,v in enumerate(generated)]}
        for key,expected in arrays.items():binary(rec['control_arrays'][key],expected)
        shared_png=OUT/'images'/(cid+'-shared-bridges.png')
        with Image.open(shared_png) as im:
            im.verify()
        im=Image.open(shared_png).convert('RGB')
        check(im.size==(w,h) and list(im.getdata())==[palette[m] if m else bg for m in shared],cid+' exact shared-bridge PNG')
        COUNT['shared_bridge_png_pixel_matches']+=1;COUNT['shared_bridge_png_pixels']+=n;COUNT['png_files_verified']+=1
        for key,expected in (('late_shared_bridge_cells',shared),('late_adapter_cells_excluding_cohesion',adapters),('late_cohesion_cells',late_cohesion),('total_late_additions',late)):
            check(rec[key]==sum(bool(x) for x in expected),cid+' exact attribution '+key)
    for key,path in rec['images'].items():
        if path:
            check((OUT/path).is_file(),cid+' required image '+key)
            with Image.open(OUT/path) as im:im.verify()
            COUNT['png_files_verified']+=1
    check(rec['mandatory_unresolved']==sum(r['unresolved_joints'] for r in rs),cid+' derived mandatory count')
    check(rec['cohesion_cells']==sum(bool(v) for v in cohesion),cid+' cohesion count')
    COUNT['cases']+=1

report={'result':'PASS','source_commit':run['source_commit'],'registration_commit':run['registration_commit'],
        'counts':dict(sorted(COUNT.items())),'audit_sha256':sha(Path(__file__).read_bytes()),
        'limitations':['99 material PNGs reproduce exact cells and palette; C098 is explicitly a labelled refusal placeholder.',
                       '99 semantic PNGs independently match owner/provenance and separated late geometry; C098 repeats the labelled refusal placeholder.',
                       'Boundary/control/detail images passed PNG decode and selected human visual spot-review; no physics/traversal claim.']}
(REVIEW/'artifact-audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
