"""Package existing admission evidence; never runs simulation or changes registration."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import zipfile

ROOT=Path(__file__).resolve().parents[2]
SOURCE='3d0b1ed72e55ba6a644b28f77e5fc2eae8ad67ba'
PUBLICATION='162d11b4'
PHASE_COUNTS={'primary':156,'async':18,'controls':9,'replay':9,'timing':45}
COPIES={
 'admission-evidence-readonly/primary-summary.json':'primary-summary.json',
 'admission-evidence-readonly/primary-selected-traces.json':'primary-selected-traces.json',
 'admission-evidence-readonly/async-summary.json':'async-summary.json',
 'admission-evidence-readonly/async-selected-traces.json':'async-selected-traces.json',
 'admission-extra-evidence-readonly/controls-summary.json':'controls-summary.json',
 'admission-extra-evidence-readonly/replay-summary.json':'replay-summary.json',
 'admission-extra-evidence-readonly/timing-summary.json':'timing-summary.json',
 'admission-timing-detail.json':'timing-detail.json',
 'admission-replay-comparison.json':'replay-comparison.json',
 'admission-controls-comparison.json':'controls-comparison.json',
 'admission-R2-retention.json':'R2-retention.json',
 'admission-R2-heavy-stream-retention.json':'R2-heavy-stream-retention.json',
 'admission-heavy-allocation.json':'heavy-allocation.json',
 'admission-async-applications.json':'async-applications.json',
 'mechanical-gate.json':'mechanical-gate.json',
 'frozen-scope.json':'frozen-scope.json',
 'adapter-mechanical-windows.json':'adapter-mechanical-windows.json',
 'adapter-mechanical-linux.json':'adapter-mechanical-linux.json',
 'admission-native/focused-receipt.json':'focused-native-qualification.json',
 'admission-native-full/receipt.json':'native-qualification.json',
 'admission-native-full/input-manifest.json':'native-input-manifest.json',
 'admission-native-full/tool-identities.json':'native-tool-identities.json',
 'admission-host-qualification/receipt.json':'host-qualification.json',
 'host-publication-delta.json':'host-publication-delta.json',
 'extension-builds.json':'extension-builds.json',
 'admission-linux-floor.json':'linux-runtime-floor.json',
 'admission-qualification-review.md':'independent-qualification-review.md',
 'gcr-a1-independent-audit-notes.md':'independent-audit-notes.md',
 'admission-native/trial1-failure.json':'failed-native-trial1.json',
 'mechanical-seal-preflight.json':'failed-mechanical-seal-preflight.json',
}


def sha(path):
    value=hashlib.sha256()
    with Path(path).open('rb')as handle:
        for block in iter(lambda:handle.read(1024*1024),b''):value.update(block)
    return value.hexdigest()


def read(path):return json.loads(Path(path).read_text(encoding='utf-8'))
def write(path,value):Path(path).write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-dir',type=Path,default=ROOT/'build')
    parser.add_argument('--output',type=Path,default=ROOT/'docs/audits/gcr-admission-2026-11-01/evidence')
    parser.add_argument('--archive',type=Path,required=True)
    parser.add_argument('--historical-campaign',type=Path,required=True,help='Original retained GCR001 primary campaign; read-only')
    args=parser.parse_args();build=args.build_dir.resolve();output=args.output.resolve();archive=args.archive.resolve()
    archive.relative_to(build)
    if archive.exists():raise RuntimeError('Preserve existing archive; choose a fresh name')
    output.mkdir(parents=True,exist_ok=True)
    members={};raw=[];identities={}
    def member(path,name=None,expected=None,kind='qualification'):
        path=Path(path).resolve();name=name or path.relative_to(ROOT).as_posix()
        if name in members:return
        members[name]={'path':path,'expected':expected,'kind':kind}
    for phase,count in PHASE_COUNTS.items():
        path=build/f'admission-{phase}'/'campaign.json';campaign=read(path)
        if not campaign['complete']or len(campaign['captures'])!=count:raise RuntimeError('Incomplete phase '+phase)
        if campaign['identity']['source']!=SOURCE:raise RuntimeError('Unexpected capture source '+phase)
        identities[phase]={k:v for k,v in campaign['identity'].items()if k!='project_inputs'}
        member(path,kind='campaign')
        for cap in campaign['captures']:
            if cap['status']!='captured':raise RuntimeError('Unsuccessful capture '+str(cap))
            for field in ['raw','log']:member(path.parent/cap[field],expected=cap[field+'_sha256'],kind='capture-'+field)
            raw.append(dict(phase=phase,**{k:cap[k]for k in ['case','arm','repeat','mode','status','raw','raw_sha256','log','log_sha256']}))
    if len(raw)!=237:raise RuntimeError('Expected all237 captures')
    for relative,target in COPIES.items():
        src=build/relative
        if not src.exists():raise RuntimeError('Required evidence missing '+str(src))
        shutil.copyfile(src,output/target);member(src)
    for folder in ['admission-native','admission-native-full','admission-host-qualification']:
        for path in sorted((build/folder).glob('*')):
            if path.is_file()and path.suffix in ['.json','.txt','.log','.cpp']:member(path)
    for path in sorted(build.glob('*')):
        if path.is_file()and (path.suffix in ['.py','.json','.log','.md'])and path.stat().st_size<8*1024*1024:member(path)
    for path in sorted((ROOT/'tools/experiments').glob('*gcr*admission*.py')):member(path,kind='portable-analysis-tool')
    member(ROOT/'docs/audits/gcr-admission-2026-11-01/protocol.json',kind='frozen-registration')
    old=read(args.historical_campaign);lookup={(r['case'],r['arm']):r for r in old['captures']}
    selected={r['case']for r in raw if r['phase']=='primary'and r['arm']=='GCR'}|{'heavy-90','sand-stream'}
    historical=[]
    member(args.historical_campaign,'historical/gcr001-final-primary/campaign.json',kind='historical-reference-manifest')
    for case in sorted(selected):
        cap=lookup[case,'GCR'];historical.append({k:cap[k]for k in ['case','arm','raw','raw_sha256','log','log_sha256']})
        for field in ['raw','log']:member(args.historical_campaign.parent/cap[field],'historical/gcr001-final-primary/'+cap[field],cap[field+'_sha256'],'historical-reference-'+field)
    member_manifest=[]
    archive.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=6,allowZip64=True)as bundle:
        for index,(name,entry)in enumerate(sorted(members.items())):
            actual=sha(entry['path'])
            if entry['expected']and actual!=entry['expected']:raise RuntimeError('Original raw/log hash changed '+str(entry['path']))
            bundle.write(entry['path'],name)
            member_manifest.append({'path':name,'sha256':actual,'size':entry['path'].stat().st_size,'kind':entry['kind']})
            if index%100==0:print('Archived',index,'of',len(members),flush=True)
        bundle.writestr('archive-member-manifest.json',json.dumps({'schema':1,'members':member_manifest},indent=2))
    archive_record={'schema':1,'path':str(archive),'sha256':sha(archive),'size':archive.stat().st_size,
                    'capture_count':237,'historical_reference_count':len(historical),'member_count':len(member_manifest)+1,
                    'scope':'Local ignored archive; all237 original capture JSON/logs, qualification logs/failures/scripts, plus explicitly separate oldR2 references. No native binaries, caches or toolchains included.'}
    write(output/'raw-archive.json',archive_record)
    write(output/'raw-receipt-manifest.json',{'schema':1,'identities':identities,'captures':raw,'historical_reference_identity':{k:v for k,v in old['identity'].items()if k!='project_inputs'},'historical_references':historical})
    write(output/'archive-member-manifest.json',{'schema':1,'members':member_manifest})
    late={phase:read(build/f'admission-{phase}-late-motion.json')for phase in ['primary','async']}
    write(output/'late-motion-summary.json',{'schema':1,'scope':'Descriptive last300 native ticks; no new acceptance/rest/sleep gate.','phases':late})
    host=[]
    for platform in ['windows','linux']:
        path=build/'admission-host-qualification'/f'actual-playground-{platform}.json';value=read(path);reports=[]
        for report in value['reports']:
            poses=report['poses'];indices=sorted({0,len(poses)//4,len(poses)//2,3*len(poses)//4,len(poses)-1})
            reports.append({**{k:v for k,v in report.items()if k!='poses'},'selected_pose_samples':[{'sample':i,'poses':poses[i]}for i in indices]})
        host.append({'platform':platform,'source':value['source'],'failures':value['failures'],'raw_sha256':sha(path),'reports':reports})
    write(output/'host-physical-summary.json',{'schema':1,'publication_commit':PUBLICATION,'source_scope':'Recorded source3d plus the four explicit runtime/provenance publication deltas. Not a new physical matrix or human verdict.','platforms':host})
    write(output/'scope-and-limitations.json',{'schema':1,'capture_source':SOURCE,'runtime_publication_commit':PUBLICATION,
        'captures':237,'capture_platform':'Windows ONLY; Linux is native/query/adapter and17 scoped host tests, not a full physical matrix','native_and_host_platforms':['Windows','Linux'],
        'hard_floor_measurement':'Fixture geometric clearance flag, not a Rapier contact callback.',
        'timing_reference_identity':'Timing and telemetry-on primary reference both record source3d and matching native/Rapier/engine/protocol hashes; the generic different-GDScript sentence in unchanged timing-detail.json is not applicable to this pair.',
        'telemetry_comparison':'39 supported telemetry-on/off comparisons exact;6 R2 heavy/stream pairs unsupported because no same-source telemetry-on primary reference was registered.',
        'historical_R2':'24 retainedR2 primary projections and6 heavy/stream timing projections compare explicitly different source/native identities; not same-runtime or full cell-state equivalence.',
        'heavy_allocation':'R2 full bin ledger is retained source73 evidence; A1 ledger source3d. Current R2 timing has selected trajectory equivalence, not a newly measured full bin ledger. No counterfactual or dominant-cause claim.',
        'mechanics':'Source3d native query/oracle and290 adapter assertions per OS pass; physical and performance adequacy remain NO-GO. No full per-query success trace was persisted beyond source-backed fixture/oracle tests and logs.',
        'owner_feel':'Not supplied by automated host motion; no default/merge acceptance.',
        'raw_archive':'Local ignored archive. Original failures and their hashes retained; no raw per-event corpus or binaries committed.'})
    failures=[]
    for relative in ['admission-native/trial1-failure.json','admission-native/windows-result.txt','admission-native/linux-result.txt','mechanical-seal-preflight.json','mechanical-input-identity-linux.json']:
        path=build/relative
        if path.exists():failures.append({'path':'build/'+relative,'sha256':sha(path),'size':path.stat().st_size})
    write(output/'failed-preflight-index.json',{'schema':1,'files':failures,'scope':'Retained failed mechanical fixture/schema/preflight evidence; not waived or relabelled as final passing qualification.'})
    write(output/'artifact-manifest.json',{'schema':1,'files':[{'path':p.name,'canonical_sha256':hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest(),'working_raw_sha256':sha(p),'canonical_size':len(p.read_bytes().replace(b'\r\n',b'\n')),'working_raw_size':p.stat().st_size}for p in sorted(output.iterdir())if p.is_file()and p.name!='artifact-manifest.json']})
    print(json.dumps(archive_record,indent=2))


if __name__=='__main__':main()
