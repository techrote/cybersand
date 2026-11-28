#!/usr/bin/env python3
"""Replay all sixteen retained successor correctness results without Godot."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import zipfile

BASE=Path('/workspace/scratch/0b2a9bdf7883')
ROOT=BASE/'evidence-c/final03-reader-root'
COMMIT='c2f8a73d34448bc1496ecd84bca02f0812c80d27'
ARCHIVE=BASE/'evidence-root/final-03/graphical-linux/original.zip'
ENGINE=BASE/'toolchain/godot47/Godot_v4.7-stable_linux.x86_64'
RAPIER=BASE/'cybersand-physics/godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so'
NATIVE=BASE/'evidence-root/final-03/linux/payload/C/libcybersand_native.linux.x86_64.so'
OUTPUT=BASE/'evidence-c/final03-linux-independent-correctness.json'
sys.path.insert(0,str(ROOT/'tools/pubpres_final'))
import run_qualification as qualifier
from qualification_oracles import ring_result,transition_result,main_recovery_result
from material_deadline_oracle import main_history_result,headless_result
from run_regressions import validate_completion
from results import digest,need

need(not OUTPUT.exists(),'retain original independent correctness replay')
report={'schema':'pubpres-final03-linux-independent-correctness-v1','application_source':COMMIT,
        'program_sha256':digest(Path(__file__)),'executed_qualifier_sha256':digest(Path(qualifier.__file__)),
        'archive_sha256':digest(ARCHIVE),'outcomes':[],'failures':[],
        'scope':'Read-only reconstruction from committed source and actual retained native/Rapier/engine bytes. Independently reconstructs queued and all180 transition histories, Main recovery and both-slot deadline histories/transactions. Synthetic clocks never earn physics/performance credit. No Godot process is rerun.','physical_acceptance':'HOLD'}
with zipfile.ZipFile(ARCHIVE) as z, tempfile.TemporaryDirectory(prefix='pubpres-correctness-replay-',dir=BASE/'evidence-c') as temporary:
    root=Path(temporary);project=root/'godot'
    with tempfile.TemporaryFile() as stream:
        # Hosted qualification archived non-target LFS pointer blobs. The local
        # Git filter can otherwise expand those unrelated platform binaries.
        # Exact staged-input hashes below independently enforce this domain.
        subprocess.run(['git','-C',str(ROOT),'archive','--format=tar',COMMIT,'--','godot'],
                       stdout=stream,check=True,env={**os.environ,'GIT_LFS_SKIP_SMUDGE':'1'})
        stream.seek(0)
        with tarfile.open(fileobj=stream) as source:
            for entry in source:
                if entry.isdir():continue
                need(entry.isfile() and not Path(entry.name).is_absolute() and '..' not in Path(entry.name).parts,'safe exact Git project member')
                target=root/entry.name;target.parent.mkdir(parents=True,exist_ok=True)
                target.write_bytes(source.extractfile(entry).read())
    for actual,relative in [(NATIVE,'addons/cybersand_native/bin/'+NATIVE.name),(RAPIER,'addons/godot-rapier2d/bin/'+RAPIER.name)]:
        target=project/relative;target.unlink();os.link(actual,target)
    original=json.loads(z.read('correctness/SUMMARY.json'))
    need(original['complete'] is True and original['headless_only'] is False and original['source']['source_commit']==COMMIT and not original['import_source_mutations'] and not original['final_source_mutations'],'original complete exact source qualification')
    need(original['engine_sha256']==digest(ENGINE) and original['rapier_sha256']==digest(RAPIER) and original['native']['binary_sha256']==digest(NATIVE),'actual runtime identities')
    actual={p.relative_to(project).as_posix():digest(p) for p in project.rglob('*') if p.is_file()}
    expected=original['staged_input_files_sha256']
    need(actual==expected,'entire actual1030-file source/runtime reconstruction: '+json.dumps({'extra':sorted(actual.keys()-expected.keys()),'missing':sorted(expected.keys()-actual.keys()),'different':[key for key in actual.keys()&expected.keys() if actual[key]!=expected[key]]}))
    bootstrap={'.godot/global_script_class_cache.cfg','.godot/extension_list.cfg'}
    need(all(original['imported_files_sha256'][key]==value for key,value in actual.items() if key not in bootstrap),'original import retained all authored bytes')
    report.update(original_summary_sha256=hashlib.sha256(z.read('correctness/SUMMARY.json')).hexdigest(),
                  staged_input_files=len(actual),imported_files=len(original['imported_files_sha256']),
                  source_mutations=[],engine_sha256=digest(ENGINE),native_sha256=digest(NATIVE),rapier_sha256=digest(RAPIER))
    transition=root/'ring-transition.json';transition.write_bytes(z.read('correctness/ring-transition.json'))
    for item in original['outcomes']:
        label=item['test']+'-slots'+str(item['slots']);folder='correctness/'+label+'/'
        try:
            text=z.read(folder+'stdout.log').decode('utf-8')
            process=json.loads(z.read(folder+'process.json'))
            need(all(item.get(k)==v for k,v in process.items()),'raw process/summary join')
            need(item['valid'] is True and process['returncode']==0 and process['timed_out'] is False and hashlib.sha256(text.encode()).hexdigest()==process['log_sha256'],'actual clean process/log bytes')
            need('ERROR:' not in text and 'SCRIPT ERROR:' not in text,'strict observed diagnostics')
            command=process['command'];engine_at=next(i for i,arg in enumerate(command) if arg.endswith('/Godot_v4.7-stable_linux.x86_64'))
            args=command[engine_at+1:]
            need(args[:4]==['--path','/home/runner/work/cybersand/cybersand/build/pubpres-final/correctness/project','--audio-driver','Dummy'],'actual exact project command')
            if item['graphical']:
                need(args[4:10]==['--rendering-method','gl_compatibility','--rendering-driver','opengl3','--render-thread','safe'],'actual graphical owner command')
                owner_raw=z.read(folder+'display-owner.json');owner=json.loads(owner_raw)
                need(process['display_owner_verified'] is True and hashlib.sha256(owner_raw).hexdigest()==process['display_owner_sha256'] and owner['application_returncode']==0 and owner['application_timeout'] is False and owner['server_tree_closed'] is True and owner['failure'] is None,'actual graphical surface cleanup')
            else:need(args[4]=='--headless','actual headless control')
            test=item['test'];evidence=None
            if test=='test_full_image_ring_publication':evidence=ring_result(text,COMMIT,project,'opengl3',engine_sha256=digest(ENGINE))
            elif test=='pubpres_full_image_ring_oracle':evidence=transition_result(transition,project,source=COMMIT,driver='opengl3',engine_sha256=digest(ENGINE))
            elif test=='test_full_image_ring_main_recovery':evidence=main_recovery_result(text,COMMIT,project,'opengl3',engine_sha256=digest(ENGINE))
            elif test=='test_material_deadline_main_history':evidence=main_history_result(text,COMMIT,project,'opengl3',engine_sha256=digest(ENGINE),slots=item['slots'])
            elif test in ['test_material_publication_deadline','test_material_deadline_main_identity']:evidence=headless_result(test,text,project)
            else:need(validate_completion(test,text,process['returncode'],completion=True)==[],'original exact completion assertions')
            if evidence is not None:need(evidence==item['evidence'],'independent bytes/authority/context reconstruction agrees exactly')
            report['outcomes'].append({'test':test,'slots':item['slots'],'graphical':item['graphical'],'raw_log_sha256':process['log_sha256'],'actual_process_sha256':hashlib.sha256(z.read(folder+'process.json')).hexdigest(),'passed':True,'evidence':evidence})
            print('PASS',label,flush=True)
        except Exception as error:
            report['failures'].append({'test':item['test'],'slots':item['slots'],'reason':repr(error)})
            print('FAILED',label,repr(error),flush=True)
report['complete']=not report['failures'] and len(report['outcomes'])==16
OUTPUT.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'complete':report['complete'],'failures':report['failures'],'output':str(OUTPUT),'sha256':digest(OUTPUT)}))
