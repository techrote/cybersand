"""Revalidate resulting-source raw correctness before comparative timing."""
from __future__ import annotations
import importlib.util
import json
from pathlib import Path
import sys

from identity import ROOT, digest
from results import need

WATER_OFF_ADMISSION = 'WATER-OFF-ADMITTED.json'
WATER_GROUPS = {
    'stock-water-correctness', 'atomic-water-safe-0',
    'atomic-water-separate-0', 'atomic-water-separate-4',
}
NON_WATER_GROUPS = {
    'stock-native-owner', 'atomic-native-owner',
    'stock-frozen-correctness', 'atomic-frozen-correctness',
    'atomic-submission-safe-0', 'atomic-submission-separate-0', 'atomic-submission-separate-4',
    'stock-members-correctness', 'atomic-members-safe-0', 'atomic-members-separate-4',
    'atomic-font-and-first-read',
}


def water_only_failures(report):
    """Return the failed Water groups only for a fully executed closure comparison."""
    if (report.get('schema') != 'pubpres-recovery-hosted-v1' or report.get('complete') is not False
            or report.get('closure_members_required') is not True or report.get('closure_native_owner_required') is not True
            or report.get('unexecuted') != [] or 'reduction_failure' in report):
        return []
    rows = report.get('outcomes', [])
    expected = NON_WATER_GROUPS | WATER_GROUPS
    if len(rows) != len(expected) or {row['name'] for row in rows} != expected:
        return []
    if any(type(row.get('returncode')) is not int or type(row.get('timed_out')) is not bool for row in rows):
        return []
    failed = {row['name'] for row in rows if row['returncode'] != 0 or row['timed_out']}
    return sorted(failed) if failed <= WATER_GROUPS else []


def admit_water_off_comparison(path, source, driver, stock, custom):
    path = Path(path).resolve()
    data = json.loads(path.read_bytes())
    failed = water_only_failures(data)
    need(path.name == 'INVENTORY.json' and failed, 'Water-off timing requires an original Water-only failure')
    verified = _replay_inventory(path, data, source, driver, stock, custom, False)
    return {'schema': 'pubpres-water-off-comparison-admission-v1', 'water_composition': 0,
            'source': source['source_commit'], 'run': data['run'], 'attempt': data['attempt'],
            'failed_water_groups': {name: digest(path.parent / (name + '.log')) for name in failed},
            'prerequisites': verified}


def verify_bounded_inventory(path, source, driver, stock, custom, water):
    path = Path(path)
    if path.name != WATER_OFF_ADMISSION:
        return verify_inventory(path, source, driver, stock, custom, water)
    need(water == 0, 'Water-off comparison admission cannot authorize Water composition')
    proof = json.loads(path.read_bytes())
    replay = admit_water_off_comparison(path.with_name('INVENTORY.json'), source, driver, stock, custom)
    need(proof == replay, 'Water-off timing proof differs from original inventory and raw prerequisite replay')
    return replay


def load_qualification():
    spec=importlib.util.spec_from_file_location('recovery_actual_qualification',Path(__file__).with_name('run_qualification.py'))
    module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module


def verify_engine_binding(proof, engine):
    """Bind recorded admission to the actual executable and original payload.

    Full source/API/PE admission remains the existing engine reader's job. This
    replay prevents a modified summary from changing an observation's engine
    role or atomic selector by changing only a truthy metadata field.
    """
    from run_focus import ENGINE_SHA256
    engine=Path(engine)
    engine_sha=digest(engine)
    recorded=proof.get('engine_admission')
    if engine_sha in ENGINE_SHA256.values():
        need(recorded is None,'Official stock observation carries a foreign atomic engine admission')
        return None
    need(isinstance(recorded,dict) and isinstance(recorded.get('admission'),dict)
         and isinstance(recorded.get('build'),dict),'Custom observation lacks its original engine admission')
    build=recorded['build']; admission=recorded['admission']
    gui=Path(build.get('gui_executable',''))
    need(not gui.is_absolute() and len(gui.parts)>=1 and '..' not in gui.parts,
         'Custom engine GUI path differs')
    payload=engine
    for _ in gui.parts:payload=payload.parent
    original=payload/'build-provenance.json'
    need((payload/gui).resolve()==engine.resolve() and original.is_file()
         and digest(original)==admission.get('proof_sha256')
         and json.loads(original.read_bytes())==build
         and build.get('application_source')==admission.get('build_source')
         and str(build.get('workflow_run'))==str(admission.get('build_run'))
         and str(build.get('workflow_attempt'))==str(admission.get('build_attempt'))
         and build.get('executables',{}).get(gui.name,{}).get('sha256')==engine_sha,
         'Custom observation engine source/run/proof or actual executable differs')
    return recorded


def verify_summary(path,source,driver,engine,focus,thread='safe',budget=0):
    path=Path(path); proof=json.loads(path.read_bytes())
    need(proof.get('schema')=='pubpres-recovery-correctness-v1' and proof.get('complete') is True
         and proof.get('headless_only') is False and proof.get('physical_acceptance')=='HOLD'
         and proof.get('focus')==focus and proof.get('render_thread')==thread and proof.get('lookahead')==budget,
         'Exact requested graphical correctness scope did not pass')
    need(all(proof['source'][key]==source[key] for key in ('source_commit','source_tree'))
         and proof['driver']==driver and proof['engine_sha256']==digest(engine)
         and proof['native']['manifest_sha256']==source['native_runtime']['manifest_sha256']
         and proof['native']['binary_sha256']==source['native_runtime']['binary_sha256']
         and proof['import_source_mutations']==proof['final_source_mutations']==[],
         'Correctness source, driver, native, engine or authored bytes differ')
    verify_engine_binding(proof,engine)
    expected={'frozen':19,'submission':2,'held-placement':2,'water':4,'members':4}[focus]
    need(len(proof['outcomes'])==expected and len({(row['test'],row['slots']) for row in proof['outcomes']})==expected,
         'Correctness inventory is incomplete or duplicated')
    module=load_qualification()
    project=path.parent/'project'
    need(project.is_dir(),'Retained actual correctness project is required for raw input replay')
    for name,sha in proof['staged_input_files_sha256'].items():
        if name not in {'.godot/global_script_class_cache.cfg','.godot/extension_list.cfg'}:
            need(digest(project/name)==sha,'Correctness staged input changed: '+name)
    for row in proof['outcomes']:
        folder=path.parent/(row['test']+'-slots'+str(row['slots']))
        log=folder/'stdout.log';text=log.read_text(encoding='utf-8',errors='replace')
        need(row.get('valid') is True and row.get('returncode')==0 and row.get('timed_out') is False
             and row.get('log_sha256')==digest(log) and 'ERROR:' not in text
             and row.get('display_owner_verified',True) is True,'Correctness actual process/log failed or changed')
        if row['test'] in module.SUPPLEMENTAL:
            if focus=='held-placement':
                need(row['test']=='test_workbench_presentation_submission' and '--stock-held-limb-placement' in row['command']
                     and '--headless' not in row['command'], 'Stock held-placement graphical invocation differs')
            actual=module.supplemental_result(row['test'],text,folder,source,project,engine_sha=digest(engine),
                expected_inline=thread=='safe',expected_lookahead=budget,expected_atomic=bool(proof.get('engine_admission')),
                stock_held=focus=='held-placement')
            need(actual==row['evidence'],'Supplemental raw evidence no longer reproduces its exact original result')
        elif row['test']=='import':
            need('--import' in row['command'] and '--editor' in row['command'],'Import did not execute actual editor import')
        else:
            test=row['test']; backend='opengl3_angle' if __import__('os').name=='nt' else 'opengl3'
            evidence=None
            if test=='test_full_image_ring_publication':
                evidence=module.ring_result(text,source['source_commit'],project,backend,engine_sha256=digest(engine))
            elif test=='pubpres_full_image_ring_oracle':
                evidence=module.transition_result(path.parent/'ring-transition.json',project,source=source['source_commit'],driver=backend,engine_sha256=digest(engine))
            elif test=='test_full_image_ring_main_recovery':
                evidence=module.main_recovery_result(text,source['source_commit'],project,backend,engine_sha256=digest(engine))
            elif test=='test_material_deadline_main_history':
                evidence=module.deadline_history_result(text,source['source_commit'],project,backend,engine_sha256=digest(engine),slots=row['slots'])
            elif test in ('test_material_publication_deadline','test_material_deadline_main_identity'):
                evidence=module.deadline_headless_result(test,text,project)
            elif test=='test_material_steps_main_history':
                evidence=module.steps_history_result(text,source['source_commit'],project,backend,engine_sha256=digest(engine))
            elif test in ('test_material_publication_steps','test_material_steps_main_identity'):
                evidence=module.steps_headless_result(test,text,project)
            else:
                need(not module.validate_completion(test,text,row['returncode'],completion=True),'Frozen actual completion did not reproduce')
            if evidence is not None: need(evidence==row['evidence'],'Frozen raw oracle no longer reproduces original result')
    return {'path':str(path),'sha256':digest(path),'outcomes':expected,'focus':focus,
            'source':source['source_commit'],'engine_sha256':digest(engine),'raw_inputs_and_supplemental_replayed':True}


def verify_inventory(path,source,driver,stock,custom,water):
    path=Path(path).resolve(); data=json.loads(path.read_bytes())
    need(data.get('complete') is True,'Timed atomic Windows integration requires complete exact hosted correctness')
    return _replay_inventory(path,data,source,driver,stock,custom,water)


def _replay_inventory(path,data,source,driver,stock,custom,water):
    need(data.get('schema')=='pubpres-recovery-hosted-v1'
         and data.get('source')==source['source_commit'] and data.get('driver')==driver
         and data.get('platform')=='windows' and data['request']['phase']=='integration'
         and data.get('unexecuted')==[],'Timed atomic Windows integration requires complete exact hosted correctness')
    required=[('stock-frozen-correctness',stock,'frozen','safe',0),
        ('atomic-frozen-correctness',custom,'frozen','safe',0),
        ('atomic-submission-safe-0',custom,'submission','safe',0),
        ('atomic-submission-separate-0',custom,'submission','separate',0),
        ('atomic-submission-separate-4',custom,'submission','separate',4)]
    if water:
        required += [('stock-water-correctness',stock,'water','safe',0),
            ('atomic-water-separate-0',custom,'water','separate',0),
            ('atomic-water-separate-4',custom,'water','separate',4)]
    verified=[]
    for name,engine,focus,thread,budget in required:
        verified.append(verify_summary(path.parent/name/'SUMMARY.json',source,driver,engine,focus,thread,budget))
    graph=path.parent/'atomic-font-and-first-read/SUMMARY.json'
    proof=json.loads(graph.read_bytes())
    need(proof.get('schema')=='pubpres-recovery-graphical-controls-v1' and proof.get('complete') is True
         and proof.get('failures')==[] and proof.get('driver')==driver
         and proof['source']['source_commit']==source['source_commit']
         and len(proof['font'])==3 and len(proof['startup'])==len(proof['two_slot'])==2
         and all(row.get('passed') is True for key in ('font','startup','two_slot') for row in proof[key]),
         'Required font, ordinary startup or original-size GPU first-read qualification is incomplete')
    original_engine=verify_engine_binding({'engine_admission':proof.get('engine')},custom)
    pin=data['request']['engine_artifact']
    need(original_engine['admission']=={'build_source':pin['source'],'build_run':pin['run'],
         'build_attempt':pin['attempt'],'proof_sha256':pin['proof_sha256']},
         'Hosted application observations differ from their registered original engine')
    from run_graphical_controls import load_font_controls
    font=load_font_controls()
    build=proof['engine']['build']
    original={'upstream_commit':build['upstream_commit'],'build_name':'official'}
    for row in proof['font']:
        folder=graph.parent/'font'/(row['engine']+'-'+row['render_thread'])
        raw=folder/'receipt.json'; observed=json.loads(raw.read_bytes()); process=json.loads((folder/'process.json').read_bytes())
        need(digest(raw)==row['receipt_sha256'] and observed==row['receipt'] and process==row['process'],
             'Raw font receipt/process changed')
        selected=stock if row['engine']=='stock' else custom
        font.validate_font(observed,process,source=source['source_commit'],nonce=row['nonce'],thread=row['render_thread'],
            build=original if row['engine']=='stock' else build,engine_sha=digest(selected))
        font.validate_process_command(process,source=source['source_commit'],engine=selected,
            project=graph.parent/'font-projects'/(row['engine']+'-'+row['render_thread']),
            thread=row['render_thread'],script='res://font_probe.gd')
    reference=proof['font'][0]['receipt']
    need(all(row['receipt']['framebuffer_sha256']==reference['framebuffer_sha256']
             and row['receipt']['adapter']==reference['adapter'] for row in proof['font']),
         'New engine font pixels or adapter differ from stock Safe')
    source_custody=json.loads((graph.parent/'template/source-custody.json').read_bytes())
    need(source_custody['source_commit']==source['source_commit'] and source_custody['authored_mutations']==[],
         'Graphical source custody changed')
    project=graph.parent/'template/project'
    authored={name:sha for name,sha in source_custody['authored_files_sha256'].items()
        if name not in {'.godot/global_script_class_cache.cfg','.godot/extension_list.cfg'}}
    need(all(digest(project/name)==sha for name,sha in authored.items()),'Graphical original project inputs changed')
    custody={'authored':authored,'rapier':source_custody['rapier']}
    for row in proof['startup']:
        folder=graph.parent/'startup'/row['render_thread'];raw=folder/'receipt.json'
        observed=json.loads(raw.read_bytes());process=json.loads((folder/'process.json').read_bytes())
        need(digest(raw)==row['receipt_sha256'] and observed==row['receipt'] and process==row['process'],
             'Raw ordinary startup receipt/process changed')
        font.validate_startup(observed,process,source=source,build=build,engine_sha=digest(custom),thread=row['render_thread'],custody=custody)
        font.validate_process_command(process,source=source['source_commit'],engine=custom,
            project=graph.parent/'startup-projects'/row['render_thread'],thread=row['render_thread'],script='res://'+font.OBSERVER)
    sys.path.insert(0,str(ROOT/'tools/pubpres_final_windows'))
    from two_slot_oracle import validate as two_slot
    fixture=project/'tests/pubpres_final_two_slot_oracle.gd'
    need(not fixture.exists(),'Unexpected first-read replay overlay collision')
    fixture.write_bytes((ROOT/'tools/pubpres_final_windows/two_slot_oracle.gd').read_bytes())
    try:
        for row in proof['two_slot']:
            folder=graph.parent/'two-slot'/row['thread'];raw=folder/'receipt.json'
            process=json.loads((folder/'process.json').read_bytes())
            need(digest(raw)==row['receipt_sha256'] and process==row['process'],'Raw first-read receipt/process changed')
            font.process_clean(process,zero=True)
            observed=two_slot(raw,project,source=source['source_commit'],driver='opengl3_angle',engine_sha256=digest(custom),separate=row['thread']=='separate')
            need(observed==row['receipt'] and process['observed_application_pid']==observed['context']['process_id'],
                 'Original-size first GPU reads do not reproduce')
    finally: fixture.unlink()
    members=[]
    if data.get('closure_members_required') is True:
        for name,engine,thread,budget in (
            ('stock-members-correctness',stock,'safe',0),
            ('atomic-members-safe-0',custom,'safe',0),
            ('atomic-members-separate-4',custom,'separate',4)):
            members.append(verify_summary(path.parent/name/'SUMMARY.json',source,driver,engine,'members',thread,budget))
    native_owner=[]
    if data.get('closure_native_owner_required') is True:
        sys.path.insert(0,str(ROOT/'tools/pubpres_recovery_windows'))
        from native_owner_receipt import verify_summary as verify_native
        for name,engine in (('stock-native-owner',stock),('atomic-native-owner',custom)):
            native_owner.append(verify_native(path.parent/name/'SUMMARY.json',source=source,driver=driver,
                engine=engine,native=source['native_runtime']))
    return {'inventory_sha256':digest(path),'correctness':verified,'members':members,'native_owner':native_owner,'graphical_controls_sha256':digest(graph),
            'scope':'Exact resulting source and raw prerequisite custody; timing remains separately qualified.'}
