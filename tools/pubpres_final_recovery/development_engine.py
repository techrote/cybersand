"""Explicit local Linux development custody; never a qualified Windows engine."""
from __future__ import annotations
import json
from pathlib import Path
import sys

from identity import ROOT, digest
from results import need
from engine_admission import load_bounded_payload
from qualification_gate import load_qualification


def admit_build(binary,proof_path):
    """Admit build custody for executing the still-required application gates."""
    need(sys.platform.startswith('linux'),'Local development engine is registered only on Linux')
    binary,proof_path=map(lambda p:Path(p).resolve(),(binary,proof_path))
    proof=json.loads(proof_path.read_bytes())
    contract=load_bounded_payload().contract
    lock=json.loads((ROOT/contract.DIRECTORY/'engine.lock.json').read_bytes())
    expected={}
    for patch in lock['patches']:
        expected.update({name:record['after_sha256'] for name,record in patch['files'].items()})
    need(proof.get('schema')=='pubpres-recovery-local-engine-v1' and proof.get('build_exit_code')==0
         and proof.get('binary_sha256')==digest(binary) and proof.get('source_commit')==lock['source_commit']
         and proof.get('patch_sha256')==contract.PATCH_SHA256 and proof.get('combined_patch_sha256')==contract.COMBINED_SHA256
         and proof.get('patched_source_files_sha256')==expected
         and proof.get('build_log_sha256')==digest(Path(proof['build_log'])),
         'Local engine binary, actual patched source or retained build log differs')
    flags=proof.get('scons_command')
    need(isinstance(flags,list) and all(isinstance(item,str) for item in flags)
         and all(flag in flags for flag in ('platform=linuxbsd','arch=x86_64','threads=yes','disable_path_overrides=no')),
         'Local engine did not preserve actual script dispatch or CPU owners')
    return {'proof':proof,'proof_sha256':digest(proof_path),'engine_qualified':False,
        'disposition':'DEVELOPMENT_BUILD_ONLY / APPLICATION_GATES_PENDING',
        'scope':'Exact Linux build/source/binary custody only; this admits execution of application qualification, never comparison or Windows/device acceptance.'}


def admit(binary,proof_path,gates_path,source,water):
    build=admit_build(binary,proof_path)
    binary,proof_path,gates_path=map(lambda p:Path(p).resolve(),(binary,proof_path,gates_path))
    proof=build['proof']
    gates=json.loads(gates_path.read_bytes())
    need(gates.get('schema')=='pubpres-recovery-local-integration-gates-v1'
         and gates.get('source_commit')==source['source_commit'] and gates.get('engine_sha256')==digest(binary)
         and isinstance(gates.get('transactions'),list) and len(gates['transactions'])==3
         and {(row.get('thread'),row.get('lookahead')) for row in gates['transactions']}=={('safe',0),('separate',0),('separate',4)},
         'Local comparison lacks actual resulting-source Safe0/Separate0/4 transaction gates')
    qualification=load_qualification(); verified=[]
    for row in gates['transactions']:
        receipt=Path(row['receipt']);log=Path(row['stdout'])
        result=qualification.supplemental_result('test_workbench_presentation_submission',
            log.read_text(encoding='utf-8',errors='replace'),receipt.parent,source,Path(source['root'])/'godot',
            engine_sha=digest(binary),expected_inline=row['thread']=='safe',expected_lookahead=row['lookahead'],receipt_path=receipt)
        need('ERROR:' not in log.read_text(encoding='utf-8',errors='replace'),'Local transaction gate has strict runtime errors')
        verified.append({'thread':row['thread'],'lookahead':row['lookahead'],'receipt_sha256':result['receipt_sha256'],'stdout_sha256':digest(log)})
    # Local Water requires the same exact native graphical receipt and terminal
    # as hosted qualification. No headless-only proof can enable the selector.
    if water:
        row=gates.get('water_native',{});receipt=Path(row.get('receipt',''));log=Path(row.get('stdout',''))
        result=qualification.supplemental_result('test_workbench_water_composition_native',
            log.read_text(encoding='utf-8',errors='replace'),receipt.parent,source,Path(source['root'])/'godot',receipt_path=receipt)
        need('ERROR:' not in log.read_text(encoding='utf-8',errors='replace'),'Local Water gate has strict runtime errors')
        verified.append({'water_native_receipt_sha256':result['receipt_sha256'],'stdout_sha256':digest(log)})
    return {'proof':proof,'proof_sha256':digest(proof_path),'gates_sha256':digest(gates_path),'verified':verified,
        'engine_qualified':False,'disposition':'DEVELOPMENT_ONLY / HOLD',
        'scope':'Local Linux development build with real source-bound graphical transaction gates and original physical capture oracle; not the Windows compiler/API/PE qualification, not hosted or physical-device acceptance.'}
