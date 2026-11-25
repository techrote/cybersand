#!/usr/bin/env python3
"""Resulting atomic-engine fonts, ordinary startup and immutable GPU first reads.

All original finite font/startup and two-slot byte/owner oracles are called
unchanged. These controls qualify rendering correctness, not physical progress.
"""
from __future__ import annotations
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys

from identity import ROOT, HERE, driver_identity, digest
from retained_runtime import validate_runtime
from run_campaign import source_identity, execute, copy_project
from run_focus import selectors
from results import need
import engine_admission


def load_font_controls():
    folder=ROOT/'tools/pubpres_final_engine'
    previous={key:sys.modules.get(key) for key in ('engine_contract','payload')}
    try:
        for name in ('engine_contract','payload'):
            spec=importlib.util.spec_from_file_location(name,folder/(name+'.py'))
            module=importlib.util.module_from_spec(spec)
            sys.modules[name]=module
            spec.loader.exec_module(module)
        spec=importlib.util.spec_from_file_location('recovery_frozen_font_controls',folder/'run_font_qualification.py')
        module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        return module
    finally:
        for name,old in previous.items():
            if old is None: sys.modules.pop(name,None)
            else: sys.modules[name]=old


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=ROOT)
    for name in ('runtime','stock-engine','output'):
        parser.add_argument('--'+name,type=Path,required=True)
    engine_admission.add_arguments(parser,required=True)
    args=parser.parse_args()
    need(os.name=='nt','This finite font/first-read gate preserves its original Windows/ANGLE contract')
    root,output=args.source.resolve(),args.output.resolve()
    need(not output.exists(),'Preserve previous graphical evidence')
    source=source_identity(root)
    driver=driver_identity()
    need(source['source_commit']==driver['source_commit'],'Graphical driver differs from resulting application')
    source['native_runtime']=validate_runtime(root,source,args.runtime,False)
    custom,admission=engine_admission.admit(args)
    build=admission['build']; stock=args.stock_engine.resolve()
    from run_focus import ENGINE_SHA256
    need(digest(stock)==ENGINE_SHA256['windows'],'Stock font reference executable differs')
    output.mkdir(parents=True)
    font=load_font_controls()
    report={'schema':'pubpres-recovery-graphical-controls-v1','source':source,'driver':driver,
        'engine':admission,'font':[],'startup':[],'two_slot':[],'failures':[],
        'complete':False,'physical_acceptance':'HOLD',
        'scope':'Actual source-exact finite graphical first reads and ordinary startup; no performance, GPU completion or scanout acceptance.'}
    def save(): font.write_json(output/'SUMMARY.json',report)
    save()
    original={'upstream_commit':build['upstream_commit'],'build_name':'official'}
    # Historical unpatched Separate was already falsified; this cohort adds a
    # new actual engine and retains its same-host official Safe pixel reference.
    for role,thread,engine,identity in (('stock','safe',stock,original),
            ('atomic','safe',custom,build),('atomic','separate',custom,build)):
        report['font'].append(font.font_arm(role,thread,engine,identity,source['source_commit'],output)); save()
    if all(row['passed'] for row in report['font']):
        reference=report['font'][0]['receipt']
        for row in report['font'][1:]:
            if row['receipt']['framebuffer_sha256'] != reference['framebuffer_sha256'] or row['receipt']['adapter'] != reference['adapter']:
                report['failures'].append('New-engine complete font framebuffer or adapter differs from stock Safe')
    else: report['failures'].append('A required font arm failed')
    template=None
    try:
        template,custody=font.prepare_startup(root,source,custom,output/'template',None)
        for thread in ('safe','separate'):
            report['startup'].append(font.startup_arm(thread,custom,build,source,template,custody,output)); save()
        if not all(row['passed'] for row in report['startup']): report['failures'].append('Ordinary native startup failed')
    except Exception as error:
        report['failures'].append('Ordinary startup: '+str(error)); save()
    if template is not None:
        sys.path.insert(0,str(ROOT/'tools/pubpres_final_windows'))
        from two_slot_oracle import validate as validate_two_slot
        for thread in ('safe','separate'):
            folder=output/'two-slot'/thread
            project=output/'two-slot-projects'/thread
            project.parent.mkdir(parents=True,exist_ok=True)
            row={'thread':thread,'passed':False}
            report['two_slot'].append(row); save()
            try:
                copy_project(template,project,imported=True)
                fixture=project/'tests/pubpres_final_two_slot_oracle.gd'
                original_fixture=ROOT/'tools/pubpres_final_windows/two_slot_oracle.gd'
                need(not fixture.exists(),'Unexpected two-slot overlay collision')
                shutil.copyfile(original_fixture,fixture)
                receipt=folder/'receipt.json'
                settings=selectors({'material':'full','same_frame_continuation':False,'wave_column_probe':False,'causal':False},'recovery-two-slot-'+thread)
                settings.update(CYBERSAND_DIAG_FULL_IMAGE_SLOTS='2',CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ='0',
                    CYBERSAND_DIAG_MATERIAL_STEP_INTERVAL='0',CYBERSAND_DIAG_ACTUAL_SUBMISSION='0',
                    CYBERSAND_DIAG_WATER_COMPOSITION='0',CYBERSAND_ENGINE_RENDER_LOOKAHEAD='0',
                    CYBERSAND_MATERIAL_QUEUE_THREAD=thread,CYBERSAND_PLAYABILITY_RENDER_THREAD=thread)
                command=['--path',str(project),'--audio-driver','Dummy','--rendering-method','gl_compatibility',
                    '--rendering-driver','opengl3_angle','--render-thread',thread,'--script',
                    'res://tests/pubpres_final_two_slot_oracle.gd','--','--material=full','--receipt='+str(receipt)]
                process=execute(custom,command,folder,source['source_commit'],settings,900)
                font.process_clean(process,zero=True)
                need('ERROR:' not in font.logs(folder),'Strict first-read diagnostics failed')
                data=validate_two_slot(receipt,project,source=source['source_commit'],driver='opengl3_angle',
                    engine_sha256=digest(custom),separate=thread=='separate')
                need(process['observed_application_pid']==data['context']['process_id'],'First-read receipt belongs to another process')
                need(digest(fixture)==digest(original_fixture),'Two-slot fixture mutated')
                need(all(digest(project/name)==sha for name,sha in custody['authored'].items()),'First reads mutated authored inputs')
                row.update(passed=True,process=process,fixture_sha256=digest(fixture),receipt_sha256=digest(receipt),receipt=data)
                shutil.rmtree(project)
            except Exception as error: row['failure']=str(error)
            save()
        if not all(row['passed'] for row in report['two_slot']): report['failures'].append('Exact immutable two-slot first reads failed')
    else: report['failures'].append('First reads unexecuted because source-exact startup staging failed')
    report['complete']=not report['failures']
    save()
    print(json.dumps({'complete':report['complete'],'failures':report['failures'],'physical_acceptance':'HOLD'}))
    return 0 if report['complete'] else 1

if __name__=='__main__': sys.exit(main())
