"""Exact recovered build02 custody for optional atomic owner configurations.

The unchanged engine payload verifier runs in the source checkout during build
and independent archive verification. The shipped PowerShell launcher verifies
the same pinned proof and complete payload without requiring Git or Python.
"""
from __future__ import annotations
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
PIN_PATH=HERE/'atomic-engine.json'
ENGINE_ROOT='engines/atomic'
GUI='Godot-PUBPRES-Atomic-4.7.exe'


def need(condition,message):
    if not condition: raise ValueError(message)


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream,'sha256').hexdigest()


def pin():
    return json.loads(PIN_PATH.read_bytes())


def verify_payload(directory):
    location=ROOT/'tools/pubpres_final_recovery/engine_admission.py'
    spec=importlib.util.spec_from_file_location('owner_atomic_engine_admission',location)
    admission=importlib.util.module_from_spec(spec);spec.loader.exec_module(admission)
    wanted=pin()
    proof=admission.load_bounded_payload().verify_payload(directory,build_source=wanted['source'],
        build_run=wanted['run'],build_attempt=wanted['attempt'],proof_sha256=wanted['proof_sha256'])
    need(proof['executables'][Path(proof['gui_executable']).name]['sha256']==wanted['gui_sha256'],
         'Atomic GUI differs from independently recovered build02')
    return proof


def stage(directory,output,*,selected=False):
    proof=verify_payload(directory)
    destination=Path(output)/ENGINE_ROOT
    need(not destination.exists(),'Atomic package destination must be fresh')
    shutil.copytree(directory,destination)
    shutil.copyfile(destination/proof['gui_executable'],Path(output)/GUI)
    record={'root':ENGINE_ROOT,'gui':{'path':GUI,'sha256':pin()['gui_sha256']},
        'version':proof['version'],'artifact':pin(),'provenance_sha256':pin()['proof_sha256'],
        'default':bool(selected)}
    verify(output,record,selected=selected)
    return record


def verify(output,record,*,selected=False):
    output=Path(output)
    need(isinstance(record,dict) and set(record)=={'root','gui','version','artifact','provenance_sha256','default'}
         and record['root']==ENGINE_ROOT and record['artifact']==pin()
         and record['provenance_sha256']==pin()['proof_sha256']
         and record['gui']=={'path':GUI,'sha256':pin()['gui_sha256']}
         and type(record['default']) is bool and record['default']==selected,
         'Atomic engine role, exact build02 custody or selection differs')
    proof=verify_payload(output/ENGINE_ROOT)
    need(record['version']==proof['version'] and digest(output/GUI)==pin()['gui_sha256'],
         'Atomic engine version or executable copy differs')
    return proof


def verify_gate(gate,record,candidate,source,water,*,safe_water=False):
    need(isinstance(gate,dict) and gate.get('source_commit')==candidate
         and gate.get('source_tree')==source['source_tree']
         and gate.get('native_sha256')==source['native']['sha256']
         and gate.get('engine_sha256')==record['gui']['sha256']
         and isinstance(gate.get('correctness'),list)
         and len(gate['correctness'])==(8 if water else 5)
         and all(len(gate.get(key,''))==64 for key in ('inventory_sha256','graphical_controls_sha256')),
         'Atomic owner configuration lacks exact resulting-source Windows application custody')
    expected={'frozen':2,'submission':3,'water':3 if water else 0}
    counts={key:0 for key in expected}
    for row in gate['correctness']:
        focus=row.get('focus')
        need(focus in counts and row.get('outcomes')=={'frozen':19,'submission':2,'water':4}[focus]
             and row.get('source')==candidate and row.get('raw_inputs_and_supplemental_replayed') is True,
             'Atomic raw correctness inventory is incomplete or unreplayed')
        counts[focus]+=1
    need(counts==expected,'Atomic correctness roles differ')
    members=gate.get('members')
    need(isinstance(members,list) and len(members)==3 and all(row.get('outcomes')==4 and row.get('focus')=='members'
         and row.get('source')==candidate and row.get('raw_inputs_and_supplemental_replayed') is True for row in members),
         'Atomic owner configuration lacks ordinary multipart picking and ownership qualification')
    native=gate.get('native_owner')
    need(isinstance(native,list) and len(native)==2
         and all(row.get('source_commit')==candidate and row.get('checks')==150
             and row.get('native_sha256')==source['native']['sha256']
             and row.get('raw_inputs_and_native_receipt_replayed') is True for row in native),
         'Atomic owner configuration lacks actual mounted native World/task ownership qualification')
    if safe_water:
        row=gate.get('safe_water',{})
        need(row.get('outcomes')==4 and row.get('focus')=='water' and row.get('source')==candidate
             and row.get('engine_sha256')==record['gui']['sha256']
             and row.get('raw_inputs_and_supplemental_replayed') is True,
             'Atomic Safe0 selected Water lacks its own actual framebuffer qualification')
