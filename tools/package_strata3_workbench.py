#!/usr/bin/env python3
"""Build and verify the frozen portable Strata Optics Lab; Draft/HOLD only.

Both actual optical platforms, both retained native-authoring compatibility
campaigns and two source-preserving predecessor comparisons are required. The
workflow separately executes the actual shipped launcher and pristine payload.
"""
from __future__ import annotations
import argparse
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/ci'))
import qualify_strata3_workbench as optics
import qualify_strata2_workbench as compatibility
import strata3_predecessor_compare as predecessor
import build_strata3_gallery as gallery
import package_strata2_workbench as base
from package_wave_flow_candidate import archive_environment,omit_regenerated_imports,REGENERATED_RAPIER_IMPORTS
from package_explore001_candidate import stage_generator_profiles,verify_vc_runtime
from package_workbench_landscape_review import DEPENDENCIES

require,sha,write_json = optics.require,optics.sha,optics.write_json
MANIFEST='evaluation-manifest.json'
ARCHIVE_INPUTS = [*base.ARCHIVE_INPUTS,'tools/package_strata3_workbench.py','tools/build_strata3_gallery.py',
    'tools/strata3_build_showcases.py','docs/systems/strata-optics.md','docs/systems/strata-workbench.md',
    'docs/systems/strata-authoring.md','docs/systems/strata-environments.md',
    'docs/operations/strata-optical-composition.md','docs/operations/strata-optics-evaluation.md',
    'docs/operations/strata-workbench-evaluation.md','docs/audits/2026-11-25-strata-theatre-003']
FEEDBACK = '''# Strata Optics Lab owner feedback — Draft/HOLD

Package/source identity:

Windows version / GPU / driver / desktop scaling:

Extraction and Open Workbench.cmd:

Scene / camera / profile / edited values:

Physical platform and passage distinction; misleading rear stairs or ladders:

Actor visibility, including movement and multiple actors:

Architecture retained or lost; favourite and rejected profiles:

Lens/focus transitions and preferred optical strength:

Atmosphere, shafts, local light and shadow impressions:

Camera, picking and live authoring:

Scene admission seconds / slider response / physical progression / shutdown:

Named preset and Save start / complete exit / fresh Load start:

Desired further experiments:

Owner disposition: HOLD / request changes / accept for later merge review

Physical acceptance is separate from hosted software-rendered evidence. This
record does not merge, promote, publish or enable the feature automatically.
'''


def payload(folder):
    return {p.relative_to(folder).as_posix():sha(p) for p in sorted(folder.rglob('*')) if p.is_file() and p != folder/MANIFEST}


def owner_text(source):
    guide=compatibility.custody.git('show','HEAD:docs/operations/strata-optics-evaluation.md').decode('utf-8').split('---',2)[-1].lstrip()
    introduction=f"# CyberSand — Strata Theatre003 portable evaluation\n\n**Draft/HOLD.** Application `{source['source_commit']}`; tree `{source['source_tree']}`.\n\nRun **Open Workbench.cmd**. All runtime dependencies and nine native scenes are included. Open **Gallery.html** for actual matched captures.\n\n"
    return introduction+guide


def archive_blobs():
    data=compatibility.custody.git('ls-tree','-rz','HEAD','--',*ARCHIVE_INPUTS)
    result={}
    for row in data.split(b'\0'):
        if not row:continue
        meta,name=row.split(b'\t',1)
        mode,kind,oid=meta.decode().split()
        require(kind=='blob' and mode in ('100644','100755'),'Unexpected linked or non-file archived input')
        result[name.decode()]=oid
    return result


def source_members(runtime):
    blobs=archive_blobs()
    materialized={runtime[k]['path']:runtime[k] for k in ('cybersand_runtime','rapier_runtime')}
    omitted={n:h for n,h in REGENERATED_RAPIER_IMPORTS.items() if n in blobs}
    originals={n:b for n,b in blobs.items() if not n.startswith('godot/.godot/')
               and ('/bin/' not in n or n in materialized) and n not in omitted}
    return originals,materialized,omitted


def verify_archived_bytes(folder,record,runtime):
    originals,materialized,omitted=source_members(runtime)
    require(record.get('archived_git_blobs')==originals and record.get('regenerated_imports_sha256')==omitted,
            'Archived source inventory differs from committed source')
    for name,oid in originals.items():
        path=folder/name
        require(path.is_file() and not path.is_symlink(),'Missing or linked archived source: '+name)
        data=path.read_bytes()
        if name in materialized:
            item=materialized[name]
            require(len(data)==item['size'] and hashlib.sha256(data).hexdigest()==item['sha256'],
                    'Materialized runtime differs from source-matched retained bytes: '+name)
        else:
            observed=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
            require(observed==oid,'Archived source differs directly from Git, even if payload rehashed: '+name)
    # Staged profile copies are checked against the independently Git-verified originals.
    base.verify_generator_profiles(folder,record,set(originals),record['files_sha256'])


def copy_evidence(origin,target):
    for path in sorted(origin.rglob('*')):
        if not path.is_file() or any(part in ('userdata','bootstrap-userdata') for part in path.relative_to(origin).parts):continue
        require(not path.is_symlink(),'Linked campaign evidence is refused')
        dest=target/path.relative_to(origin);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,dest)


def verify_evidence(folder,source,previous_source):
    receipts={}
    for platform,dirname in (('linux','linux'),('win32','windows')):
        actual=optics.verify_campaign(folder/'qualification'/dirname,source)
        require(actual['platform']==platform,'Optical campaign platform differs from package location')
        old=compatibility.verify_campaign(folder/'qualification'/('compatibility-'+dirname),previous_source)
        require(old['platform']==platform,'Authoring compatibility platform differs from package location')
        comparison_folder=folder/'qualification'/('predecessor-'+dirname)
        summary=predecessor.verify(comparison_folder)
        comparison=json.loads((comparison_folder/'comparison.json').read_text(encoding='utf-8'))
        require(comparison.get('candidate_source')==previous_source and comparison.get('runtime')==compatibility.retained_runtime_manifest(platform)
                and comparison.get('host',{}).get('platform')==platform,
                'Paired predecessor comparison differs from exact application/platform/runtime')
        receipts[dirname]={'optical_campaign_sha256':sha(folder/'qualification'/dirname/'campaign.json'),
            'compatibility_campaign_sha256':sha(folder/'qualification'/('compatibility-'+dirname)/'qualification.json'),
            'predecessor_comparison_sha256':sha(comparison_folder/'comparison.json'),
            'predecessor_summary':summary}
    return receipts


def verify_gallery(folder,record):
    output=folder/'Gallery.html';inputs=output.with_suffix('.inputs.json')
    data=gallery.prepare(folder/'qualification/windows',output)
    require(output.read_bytes()==gallery.render(data).encode('utf-8')
            and inputs.read_bytes()==(json.dumps(data,ensure_ascii=False,sort_keys=True,indent=2)+'\n').encode('utf-8'),
            'Optical gallery differs from admitted original native captures')
    expected={'schema':'strata3-gallery-build-v1','source_commit':data['source_commit'],'platform':data['platform'],
        'html_sha256':sha(output),'inputs_sha256':sha(inputs),'scenes':len(data['scenes']),
        'matched_profile_captures':sum(len(s['views']) for s in data['scenes']),
        'additional_captures':sum(len(s['additional_views']) for s in data['scenes'])}
    require(record.get('gallery')==expected,'Gallery receipt differs from reproduced bytes')


def verify(folder,*,pristine=False):
    folder=folder.resolve(strict=True)
    record=json.loads((folder/MANIFEST).read_text(encoding='utf-8'))
    source=optics.identity();previous_source=compatibility.identity();runtime=compatibility.retained_runtime_manifest('win32')
    require(record.get('schema')=='strata3-workbench-evaluation-v1' and record.get('draft_hold') is True
            and record.get('source_identity')==source and record.get('runtime')==runtime
            and record.get('source_commit')==source['source_commit'] and record.get('source_tree')==source['source_tree']
            and record.get('godot_version')==compatibility.custody.windows.GODOT_VERSION
            and record.get('scene_admission_target_ms')==45000
            and record.get('original_extracted_windows_target_misses_ms')==[51619,66316,66200,59958,54804],
            'Evaluator differs from the frozen optical source/runtime or Draft disposition')
    names=record.get('files_sha256',{})
    require(isinstance(names,dict) and names,'Missing complete payload ledger')
    for name,digest in names.items():
        path=folder/optics.safe_relative(name)
        require(path.is_file() and not path.is_symlink() and sha(path)==digest,'Changed packaged file: '+name)
    required={'Open Workbench.cmd','READ-ME.md','OWNER-EVALUATION.md','OWNER-FEEDBACK.md','Gallery.html','Gallery.inputs.json',
              'godot/project.godot','godot/shaders/strata_optical_plane.gdshader',
              'godot/scripts/depth/workbench_strata_optics_panel.gd','docs/operations/strata-optics-evaluation.md',
              'tools/package_strata3_workbench.py',*DEPENDENCIES,'vcruntime140.dll','vc-runtime-provenance.json'}
    require(required<=set(names),'Incomplete interactive optics evaluator payload')
    compatibility.custody.project_identity(folder/'godot',source,runtime)
    compatibility.project_assets_identity(folder/'godot',source)
    verify_archived_bytes(folder,record,runtime)
    require(record.get('qualification')==verify_evidence(folder,source,previous_source),
            'Packaged qualification receipt differs from original evidence')
    verify_gallery(folder,record)
    require((folder/'Open Workbench.cmd').read_text(encoding='utf-8')==base.launcher_text(source),
            'Ordinary Workbench launcher differs from admitted command')
    require((folder/'OWNER-FEEDBACK.md').read_text(encoding='utf-8')==FEEDBACK,'Owner feedback contract changed')
    require(all((folder/name).read_text(encoding='utf-8')==owner_text(source) for name in ('READ-ME.md','OWNER-EVALUATION.md')),
            'Generated owner guidance differs from frozen source and application identity')
    for name,digest in DEPENDENCIES.items():require(names.get(name)==digest,'Pinned portable dependency changed: '+name)
    vc=verify_vc_runtime(folder)
    require(record.get('vc_runtime_sha256')==vc['files_sha256']['vcruntime140.dll']==names['vcruntime140.dll'],
            'VC runtime differs from original licensed staging receipt')
    require(names.get('Godot_v4.7-stable_win64.exe')==compatibility.GODOT_GUI_SHA256
            and names.get('Godot_v4.7-stable_win64_console.exe')==compatibility.GODOT_SHA256['win32'],
            'Portable engine differs from official pinned Godot4.7')
    if pristine:require(payload(folder)==names,'Pristine extracted package has missing or extra files')
    return record


def build(args):
    source=optics.identity();previous_source=compatibility.identity()
    runtime=compatibility.custody.windows.verify_retained_runtime(ROOT)
    output=args.output.resolve();require(not output.exists(),'Refusing to overwrite an evaluator')
    dependencies=args.dependencies.resolve(strict=True)
    for name,digest in DEPENDENCIES.items():require(sha(dependencies/name)==digest,'Pinned dependency mismatch: '+name)
    vc=verify_vc_runtime(dependencies)
    # Validate the six independent campaigns before allocating the package tree.
    origins={name:getattr(args,name.replace('-','_')).resolve(strict=True) for name in
             ('linux','windows','compatibility-linux','compatibility-windows','predecessor-linux','predecessor-windows')}
    require(len(set(origins.values()))==6,'All platform and comparison evidence must be independently retained')
    for dirname,origin in origins.items():
        if dirname.startswith('compatibility'):compatibility.verify_campaign(origin,previous_source)
        elif dirname.startswith('predecessor'):predecessor.verify(origin)
        else:optics.verify_campaign(origin,source)
    output.mkdir(parents=True)
    originals,materialized,omitted=source_members(runtime)
    archive=subprocess.check_output(['git','archive','HEAD','--',*ARCHIVE_INPUTS],cwd=ROOT,env=archive_environment(),timeout=90)
    with tarfile.open(fileobj=io.BytesIO(archive)) as tree:
        for member in tree:
            if not member.isfile() or member.name not in originals and member.name not in omitted:continue
            require(not Path(member.name).is_absolute() and '..' not in Path(member.name).parts,'Unsafe archive input')
            data=(ROOT/member.name).read_bytes() if member.name in materialized else tree.extractfile(member).read()
            require(not data.startswith(b'version https://git-lfs.github.com/spec/v1\n'),'Unmaterialized required payload: '+member.name)
            dest=output/member.name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
    profiles=stage_generator_profiles(output);actual_omitted=omit_regenerated_imports(output)
    require(actual_omitted==omitted,'Regenerated import omission differs from reviewed source')
    for name in [*DEPENDENCIES,'vcruntime140.dll','vc-runtime-provenance.json']:shutil.copyfile(dependencies/name,output/name)
    (output/'Open Workbench.cmd').write_text(base.launcher_text(source),encoding='utf-8',newline='\r\n')
    (output/'OWNER-FEEDBACK.md').write_text(FEEDBACK,encoding='utf-8',newline='\n')
    for name in ('READ-ME.md','OWNER-EVALUATION.md'):
        (output/name).write_text(owner_text(source),encoding='utf-8',newline='\n')
    for dirname,origin in origins.items():copy_evidence(origin,output/'qualification'/dirname)
    qualification=verify_evidence(output,source,previous_source)
    gallery_receipt=gallery.build(output/'qualification/windows',output/'Gallery.html')
    record={'schema':'strata3-workbench-evaluation-v1','draft_hold':True,'source_identity':source,
        'source_commit':source['source_commit'],'source_tree':source['source_tree'],
        'runtime':runtime,'godot_version':compatibility.custody.windows.GODOT_VERSION,
        'qualification':qualification,'gallery':gallery_receipt,'generator_profiles_sha256':profiles,
        'archived_git_blobs':originals,'regenerated_imports_sha256':omitted,
        'vc_runtime_sha256':vc['files_sha256']['vcruntime140.dll'],'files_sha256':payload(output),
        'owner_acceptance':'pending physical Windows11/NVIDIA and artistic adjudication',
        'scene_admission_target_ms':45000,'original_extracted_windows_target_misses_ms':[51619,66316,66200,59958,54804]}
    write_json(output/MANIFEST,record);verify(output,pristine=True)
    require(optics.identity()==source,'Source changed during evaluator assembly')
    if args.archive:
        require(not args.archive.exists(),'Refusing to overwrite an evaluator archive')
        args.archive.parent.mkdir(parents=True,exist_ok=True)
        with zipfile.ZipFile(args.archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as bundle:
            for path in sorted(output.rglob('*')):
                if path.is_file():bundle.write(path,path.relative_to(output).as_posix())
        args.archive.with_suffix(args.archive.suffix+'.sha256').write_text(sha(args.archive)+'  '+args.archive.name+'\n')
        write_json(args.archive.with_suffix('.manifest.json'),record)
    return output


def main():
    parser=argparse.ArgumentParser(description=__doc__);commands=parser.add_subparsers(dest='command',required=True)
    make=commands.add_parser('build')
    for name in ('dependencies','linux','windows','compatibility-linux','compatibility-windows','predecessor-linux','predecessor-windows','output'):
        make.add_argument('--'+name,type=Path,required=True)
    make.add_argument('--archive',type=Path)
    check=commands.add_parser('verify');check.add_argument('package',type=Path);check.add_argument('--pristine',action='store_true')
    args=parser.parse_args()
    if args.command=='build':print(build(args))
    else:print(json.dumps({'verified':str(args.package),'source_commit':verify(args.package,pristine=args.pristine)['source_commit']}))
    return 0


if __name__=='__main__':raise SystemExit(main())
