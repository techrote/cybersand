#!/usr/bin/env python3
"""Read-only full source/dependency inventory; never produce a composition."""
import argparse
import ast
from collections import Counter
import hashlib
import json
from pathlib import Path
import subprocess
import la_selective_experiment as p

ROOT=Path(__file__).resolve().parents[2]
REG=ROOT/'native/tests/fixtures/sol_authority_contract_001.json'
OLD=ROOT/'docs/audits/la-selective-20261105/composition-map.json'
BUILD=ROOT/'docs/audits/sol-active-normal-live-20261105/build.json'
def digest(raw):return hashlib.sha256(raw).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def write(path,value):path.write_bytes((json.dumps(value,indent=2)+'\n').encode('utf-8'))
def owner(path):
    if path.startswith('native/src/world'):return 'Native World authority and protected material owner'
    if path.startswith('native/'):return 'Native contracts/tests owner'
    if path.startswith('godot/native_extension/'):return 'Native facade/worker boundary owner'
    if path.startswith('godot/scripts/simulation_worker'):return 'Exclusive desktop native worker owner'
    if path.startswith('godot/scripts/'):return 'Godot session/main-thread or copied-value adapter owner'
    if path.startswith(('godot/addons/','third_party/')):return 'Dependency/runtime provenance owner'
    if path.startswith(('materials/','tools/material_catalogue/')):return 'MAT-AUTH catalogue owner'
    return 'Build/test/documentation owner'
def transitions(raw):
    for node in ast.parse(raw.decode('utf-8')).body:
        if isinstance(node,ast.AnnAssign) and isinstance(node.target,ast.Name) and node.target.id=='REVIEWED_TRANSITIONS':return ast.literal_eval(node.value)
    return []

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    output=args.output.resolve();assert not output.exists();output.mkdir(parents=True)
    head=p.git('rev-parse','HEAD').decode().strip();registration=read(REG);sources=registration['sources'];old=read(OLD)
    paths={r['path'] for r in old['files']};protected={r['path'] for r in old['files'] if r['protected']}
    tables={};records={};manifests={};native_union=set()
    for label,commit in sources.items():
        assert len(commit)==40 and p.git('rev-parse',commit).decode().strip()==commit
        table={}
        for line in p.git('ls-tree','-rlz',commit).split(b'\0'):
            if not line:continue
            metadata,path=line.split(b'\t',1);mode,kind,blob,size=metadata.split()
            table[path.decode('utf-8')]=dict(mode=mode.decode(),kind=kind.decode(),blob=blob.decode(),bytes=None if size==b'-' else int(size))
        tables[label]=table
        paths.update(path for path in table if path.startswith(('native/','godot/','tools/','materials/','third_party/','.github/')) or path in ['AGENTS.md','Makefile','.gitattributes','.gitmodules','README.md'])
        platforms={}
        for platform,filename in [('windows','runtime-provenance.json'),('linux','runtime-provenance.linux.json')]:
            path='godot/addons/cybersand_native/'+filename;raw=p.git('show',commit+':'+path);manifest=json.loads(raw)
            paths.update(manifest['source_inputs']);paths.update(manifest.get('build_inputs',{}));native_union.update(manifest['source_inputs'])
            platforms[platform]=dict(manifest_path=path,manifest_sha256=digest(raw),native_inputs=manifest['source_inputs'],build_inputs=manifest.get('build_inputs',{}),
                artifact=manifest.get('artifact'),declared_sha256=manifest.get('sha256'),toolchain=manifest.get('toolchain',manifest.get('compiler')),bindings=manifest.get('bindings',manifest.get('godot_cpp_library_sha256')),qualification=manifest.get('acceptance'))
        manifests[label]=platforms
        records[label]=dict(commit=commit,tree=p.git('rev-parse',commit+'^{tree}').decode().strip(),merge_base_with_live=p.git('merge-base',commit,sources['live429']).decode().strip())
    objects=sorted({table[path]['blob'] for table in tables.values() for path in paths if path in table and table[path]['kind']=='blob'})
    retained={table[path]['blob'] for table in tables.values() for path in ['tools/material_catalogue/compatibility.py','materials/catalogue/compatibility-lock.json']}
    hashes={};blobs={}
    with subprocess.Popen(['git','cat-file','--batch'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,cwd=ROOT) as proc:
        for expected in objects:
            proc.stdin.write((expected+'\n').encode());proc.stdin.flush();blob,kind,size=proc.stdout.readline().split();size=int(size)
            assert blob.decode()==expected and kind==b'blob';raw=proc.stdout.read(size);assert len(raw)==size and proc.stdout.read(1)==b'\n'
            item=dict(raw_sha256=digest(raw),lf_sha256=None if b'\0' in raw else digest(raw.replace(b'\r\n',b'\n')))
            if raw.startswith(b'version https://git-lfs.github.com/spec/v1\n'):
                fields=dict(line.split(' ',1) for line in raw.decode().splitlines()[1:]);item['lfs_pointer']=dict(oid=fields['oid'],size=int(fields['size']),materialized_verification='UNAVAILABLE from Git blob inventory')
            hashes[expected]=item
            if expected in retained:blobs[expected]=raw
        proc.stdin.close();assert proc.wait()==0
    rows=[]
    for path in sorted(paths):
        present={label:dict(table[path],**hashes.get(table[path]['blob'],{})) if path in table else None for label,table in tables.items()}
        variants={r['blob'] for r in present.values() if r};live=present['live429'];sol=present['energy407']
        same=(live is None and sol is None) or (live is not None and sol is not None and live['blob']==sol['blob'])
        category='identical' if len(variants)==1 and all(present.values()) else ('source-specific-presence' if len(variants)==1 else 'source-divergence')
        if not same:category='protected-conflict' if path in protected else ('shared-writer-conflict' if live and sol else 'source-specific-addition')
        rows.append(dict(path=path,protected=path in protected,owner=owner(path),classification=category,live_vs_SOL_equal=same,
            admission_required='Protected transition, ownership and oracles; unchanged lock is not admission' if path in protected and not same else ('Explicit owner/lifetime/runtime composition review' if not same else 'No identity conflict; permission not inferred'),sources=present))
    for label,table in tables.items():
        lock=blobs[table['materials/catalogue/compatibility-lock.json']['blob']];guard=blobs[table['tools/material_catalogue/compatibility.py']['blob']]
        records[label]['material']=dict(lock_sha256=digest(lock),guard_sha256=digest(guard),protected_consumers=json.loads(lock)['source_locks'],reviewed_transitions=transitions(guard),qualifier='Inventory only; unchanged compatibility checker owns authentication')
        for platform,manifest in manifests[label].items():
            manifest['native_input_count']=len(manifest['native_inputs'])
            manifest['source_mismatches']=[path for path,value in manifest['native_inputs'].items() if path not in table or hashes[table[path]['blob']]['lf_sha256']!=value]
    build=read(BUILD)
    result=dict(registration=registration['registration'],analysis_source=head,registration_sha256=digest(REG.read_bytes()),sources=records,
        historical_map=dict(path=str(OLD.relative_to(ROOT)),sha256=digest(OLD.read_bytes()),rows=len(old['files']),unchanged=True),
        scope='Complete listed prefix trees plus full runtime source/build inventories and retained historical/protected union; Git blobs distinct from execution and LFS materialization.',
        files=rows,file_count=len(rows),classification_counts=dict(Counter(r['classification'] for r in rows)),native_input_union=sorted(native_union),native_input_union_count=len(native_union),runtime_inventories=manifests,
        experimental_runtime=dict(receipt_path=str(BUILD.relative_to(ROOT)),receipt_sha256=digest(BUILD.read_bytes()),build_source=build['identity']['source'],outputs={host:dict(sha256=v['output_sha256'],path=v['output'],clean=v['clean']) for host,v in build['platforms'].items()}),
        composed_tree=None,admitted=False,live_authority=False,actuation_permitted=False,decision='NO-GO for composition or original SOL actuation; inventory only')
    assert protected=={r['path'] for r in rows if r['protected']};assert head==p.git('rev-parse','HEAD').decode().strip()
    write(output/'source-map.json',result);print(json.dumps(dict(files=len(rows),native_union=len(native_union),classifications=result['classification_counts'])))

if __name__=='__main__':main()
