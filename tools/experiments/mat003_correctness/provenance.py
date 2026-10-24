"""Independent command/source/binary/budget readback; never executes a candidate."""
import json
from pathlib import Path
import tempfile
from matrix import ARMS,cases,LIMITS

def verify_provenance(root,result,authority,expected_seal,digest,guard,verifier_revision=None):
    if len(expected_seal)!=64 or digest(root/'authority.json')!=expected_seal or result.get('authority_sha256')!=expected_seal:raise ValueError('external authority seal mismatch')
    if result.get('source_commit')!=authority['source_commit'] or result.get('source_tree')!=authority['source_tree']:raise ValueError('source Git identity mismatch')
    if result.get('authority')!=authority:raise ValueError('authority object mismatch')
    built=json.loads((root/'built.json').read_text(encoding='utf-8'))
    admitted=json.loads((root/'binary-admission.json').read_text(encoding='utf-8'))
    build_authority=json.loads((root/'build-authority.json').read_text(encoding='utf-8'))
    if digest(root/'build-authority.json')!=authority['build_authority_sha256'] or built.get('build_authority_sha256')!=authority['build_authority_sha256'] or built.get('status')!='built-execution-held':raise ValueError('separate build checkpoint missing')
    if digest(root/'binary-admission.json')!=authority['binary_admission_sha256'] or admitted.get('built_sha256')!=digest(root/'built.json') or admitted.get('independent_admission')!='admitted' or not admitted.get('independent_review_reference'):raise ValueError('independent binary admission missing')
    if admitted.get('generated_sha256')!=built.get('generated') or admitted.get('binary_sha256')!={b['path']:b['sha256'] for b in built['builds']} or result['builds']!=built['builds']:raise ValueError('built/admitted/executed binary sets differ')
    fixed=('source_commit','source_tree','source_sha256','compiler_sha256','linker_sha256','psutil_source_sha256','normal_flags','sanitizer_flags','platform_identity','sanitizer_environment','linker_selection_flags','toolchain_proof_sha256')
    if any(authority[k]!=build_authority[k] for k in fixed):raise ValueError('execution authority changes build contract')
    previous=json.loads((root/'build-inventory.json').read_text(encoding='utf-8'))
    if any(name.startswith('cases/') or name=='execution-attempt.json' for name in previous):raise ValueError('candidate ran before binary admission checkpoint')
    for name,value in previous.items():
        if digest(root/name)!=value:raise ValueError('pre-execution checkpoint mutated')
    if digest(root/'toolchain-proof.json')!=authority['toolchain_proof_sha256']:raise ValueError('toolchain input receipt seal')
    proof=json.loads((root/'toolchain-proof.json').read_text(encoding='utf-8'))
    if proof.get('status')!='independently-qualified-toolchain-resolution' or proof.get('compiler_sha256')!=authority['compiler_sha256'] or proof.get('resolved_linker_sha256')!=authority['linker_sha256'] or proof.get('selection_flags')!=authority['linker_selection_flags'] or not proof.get('driver_resolution_trace') or not proof.get('input_files'):raise ValueError('compiler/linker resolution not qualified')
    if not authority.get('sanitizer_preflight_reference'):raise ValueError('sanitizer preflight missing')
    for arm,files in built['generated'].items():
        pre=json.loads((root/('generated-'+arm+'-precompile.json')).read_text(encoding='utf-8'))
        if pre!=files:raise ValueError('precompile seal changed')
        for name,value in files.items():
            if digest(root/'generated'/arm/name)!=value:raise ValueError('generated seal changed')
    for relative,value in authority['source_sha256'].items():
        p=root/'source'/relative
        if not p.resolve().is_relative_to(root/'source') or p.is_symlink() or digest(p)!=value:raise ValueError('admitted source snapshot drift')
    source_actual={p.relative_to(root/'source').as_posix() for p in (root/'source').rglob('*') if p.is_file()}
    if source_actual!=set(authority['source_sha256']):raise ValueError('source input inventory drift')
    verifier_sources=authority['source_sha256']
    if verifier_revision is not None:
        from verifier_revision import revision_sources
        verifier_sources=revision_sources(root,authority,result,*verifier_revision,digest)
    for name in ('readback.py','provenance.py','world_oracle.py','oracle.py','matrix.py','storage_oracle.py','negative.py','overlay.py'):
        relative='tools/experiments/mat003_correctness/'+name
        if digest(Path(__file__).parent/name)!=verifier_sources[relative]:raise ValueError('independent verifier source identity mismatch')
    if digest(root/'tools/compiler.bin')!=authority['compiler_sha256'] or digest(root/'tools/linker.bin')!=authority['linker_sha256']:raise ValueError('tool binary seal mismatch')
    for name,value in authority['psutil_source_sha256'].items():
        if digest(root/'monitor'/name)!=value:raise ValueError('resource monitor seal drift')
    if {p.relative_to(root/'monitor').as_posix() for p in (root/'monitor').rglob('*') if p.is_file()}!=set(authority['psutil_source_sha256']):raise ValueError('monitor inventory drift')
    if result.get('wall_watchdog_seconds',float('inf'))>LIMITS['platform_wall_seconds']:raise ValueError('wall budget breached')
    if sum(p.stat().st_size for p in root.rglob('*') if p.is_file())>LIMITS['total_output_bytes']//2:raise ValueError('retained output ceiling breached')
    recorded_root=result['evidence_root'];old=Path(recorded_root.replace(chr(92),'/'))
    def normalized(value):return value.replace(chr(92),'/').replace(old.as_posix(),'$EVIDENCE')
    def command(row,expected,label,timeout,rss):
        receipt=json.loads((root/(label+'.receipt.json')).read_text(encoding='utf-8'))
        if receipt!=row or [normalized(v) for v in receipt['argv']]!=[normalized(str(v)) for v in expected] or receipt['cwd']!=recorded_root or receipt['timeout']!=timeout:raise ValueError('command/cwd/timeout binding drift')
        if receipt['exit_code']!=0 or receipt['stop'] or receipt['stderr_bytes'] or receipt['peak_rss']>rss or receipt['elapsed_watchdog_seconds']>timeout+.25:raise ValueError('failed command/budget retained')
        for suffix in ('stdout','stderr'):
            if digest(root/(label+'.'+suffix))!=receipt[suffix+'_sha256']:raise ValueError('command stream drift')
        if (root/(label+'.stderr')).stat().st_size:raise ValueError('diagnostic stream nonempty')
    compiler=authority['compiler'];is_windows=authority['platform_identity']['system']=='Windows'
    s1='tools/experiments/mat003_prepass'
    reg=json.loads((root/'source'/s1/'world_registration.json').read_text(encoding='utf-8-sig'))
    for name,value in reg['baseline_control_sha256'].items():
        if digest(root/'source'/name)!=value:raise ValueError('accepted baseline source changed')
    # Recreate the generated copies from the sealed inputs, never the mutable working tree.
    from overlay import prepare
    for arm in ARMS:
        guard()
        with tempfile.TemporaryDirectory(prefix='mat003-readback-') as directory:
            generated=Path(directory)/'copy';prepare(root/'source',generated,arm)
            guard()
            expected_files={}
            for p in generated.rglob('*'):
                guard()
                if p.is_file() and p.name not in ('overlay.json','reviewed-overlay.json'):expected_files[p.relative_to(generated).as_posix()]=digest(p)
            actual=root/'generated'/arm
            if {p.relative_to(actual).as_posix() for p in actual.rglob('*') if p.is_file() and p.name not in ('overlay.json','reviewed-overlay.json')}!=set(expected_files):raise ValueError('generated source inventory drift')
            for name,value in expected_files.items():
                guard()
                if digest(actual/name)!=value:raise ValueError('generated source drift: '+name)
    ordered=[(arm,san,kind) for arm in ARMS for san in (False,True) for kind in ('storage','world')]
    if [(b['arm'],b['sanitized'],b['kind']) for b in result['builds']]!=ordered:raise ValueError('build ordering/matrix drift')
    buildmap={}
    for b in result['builds']:
        arm,sanitized,kind=b['arm'],b['sanitized'],b['kind'];capacity=int(arm.split('-')[0][1:]);bits=int(arm.split('E')[1])
        binary=old/b['path'];work=old/'generated'/arm;source=old/'source';flags=authority['sanitizer_flags' if sanitized else 'normal_flags']
        if kind=='storage':expected=[compiler,*flags,'-DCYBERSAND_MASS_BITS=8','-DCYBERSAND_DELAY_BITS=8','-DCYBERSAND_LITERAL_TOLERANCE=0',*authority['linker_selection_flags'],f'-DMAT003_CAPACITY={capacity}',f'-DMAT003_EPOCH_BITS={bits}','-I'+str(source/'tools/experiments/mat003_correctness'),str(source/'tools/experiments/mat003_correctness/storage.cpp'),'-o',str(binary)]
        else:
            representation='word' if capacity==64 else 'packed';extra=0 if capacity==64 else 1 if capacity==72 else 2
            base=next(a for a in reg['arms'] if a['representation']==representation and a['epoch_bits']==bits and a['neutral_extra_bits']==extra*8)
            definitions=[f'-DMAT003_ARM_ID="{base["id"]}"',f'-DMAT003_STORAGE_KIND={1 if capacity==64 else 3}',f'-DMAT003_EPOCH_BITS={bits}',f'-DMAT003_EXTRA_BYTES={extra}','-DMAT003_SPLIT=0','-DMAT003_WORLD_SOURCE="'+(work/'native/src/world.cpp').as_posix()+'"',f'-DMAT003_CAPACITY={capacity}']
            expected=[compiler,*flags,'-DCYBERSAND_MASS_BITS=8','-DCYBERSAND_DELAY_BITS=8','-DCYBERSAND_LITERAL_TOLERANCE=0',*authority['linker_selection_flags'],*definitions,'-I'+str(work/s1),'-I'+str(work/'native/include'),'-I'+str(work/'native/src'),str(work/s1/'reviewed_world.cpp'),*(str(work/p) for p in ('native/src/material_rules.cpp','native/src/scheduler_geometry.cpp','native/src/settled_world_discovery.cpp')),'-o',str(binary)]
        if is_windows:expected+=['-lpsapi']
        command(b['receipt'],expected,f'builds/{arm}-{int(sanitized)}-{kind}',180,3*1024**3)
        buildmap[arm,sanitized,kind]=binary
    for case,row in zip(cases(),result['results']):
        directory=old/'cases'/case['id'];kind='storage' if case['suite']=='storage' else 'world';binary=buildmap[case['arm'],case['sanitized'],kind]
        expected=[str(binary),'--correctness-only'] if kind=='storage' else [str(binary),case['suite'],str(case.get('side',256)),str(case.get('workers',1)),case.get('backend','serial'),case.get('scene','ordinary'),str(directory/'world')]
        command(row['receipt'],expected,'cases/'+case['id']+'/process',case['timeout'],LIMITS['sanitized_rss_bytes' if case['sanitized'] else 'normal_rss_bytes'])
