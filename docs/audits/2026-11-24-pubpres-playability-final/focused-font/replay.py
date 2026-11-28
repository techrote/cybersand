#!/usr/bin/env python3
"""Read-only replay of the exact retained c2/d4 font and render-owner experiment."""
from __future__ import annotations

import argparse
import atexit
from functools import lru_cache
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PureWindowsPath
import shutil
import subprocess
import sys
import tempfile
import zipfile


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--workspace-root', type=Path, default=Path('/workspace/scratch/0b2a9bdf7883'))
parser.add_argument('--output', type=Path)
args = parser.parse_args()
BASE = args.workspace_root.resolve()
ROOT = BASE / 'evidence-c/font-reader-root'
DRIVER = 'd4f4afe93d02192d9165622b78b762d9fbf8dc3e'
APPLICATION = 'c2f8a73d34448bc1496ecd84bca02f0812c80d27'
ARCHIVE = BASE / 'evidence-root/font-requalification-01/original.zip'
ARCHIVE_SHA = '3dc89e83a4757c860a7f7f645b165eb948d3bfb1a12c294596b524f802464b5d'
ENGINE_ARCHIVE = BASE / 'evidence-root/final-03/font-engine/original.zip'
OLD_ENGINE_ARCHIVE = BASE / 'evidence-b/engine609/original.zip'
RUNTIME = BASE / 'evidence-root/final-03/windows/payload/C'
RAPIER = BASE / 'evidence-root/development-02/evaluator-package/replay-runtime/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll'
OUTPUT = args.output.resolve() if args.output else BASE / 'evidence-c/focused-font-complete-independent-replay.json'
sys.path.insert(0, str(ROOT / 'tools/pubpres_final'))
sys.path.insert(0, str(ROOT / 'tools/pubpres_final_windows'))

from run_comparison import driver_identity
from replay_extent_check import verify_retained_runtime
from results import digest, need
from results_registered_renderer import reduce_receipt
from renderer_contract import verify_renderer_reducer
from run_font_renderer_comparison import (verify_driver, validate_cohort, validate_deadline_off,
                                         validate_requested_renderer)
from run_renderer_comparison import validate_draw_identity
from observer_support import validate_observers
from metrics import supplementary_metrics, validate_slot_treatment
from run_focus import observed_gap_counts
from two_slot_oracle import validate as validate_gpu
import independent_reduction as independent


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


@lru_cache(maxsize=512)
def committed(source, name):
    return subprocess.check_output(['git', '-C', str(ROOT), 'show', source + ':' + name])


OVERLAYS = {
    'tests/pubpres003_causal_gameplay.gd': 'tools/pubpres003/pubpres_causal_gameplay.gd',
    'tests/pubpres_final_gameplay.gd': 'tools/pubpres_final/pubpres_final_gameplay.gd',
    'tests/pubpres_final_font_gameplay.gd': 'tools/pubpres_final/pubpres_final_font_gameplay.gd',
    'tests/pubpres_final_presentation_probe.gd': 'tools/pubpres_final_observers/presentation_probe.gd',
}


def reconstruct(project, data, campaign, native):
    for resource, expected in data['source_identity']['files'].items():
        need(resource.startswith('res://'), 'Unexpected resource scheme')
        name = resource.removeprefix('res://')
        need('..' not in Path(name).parts and not Path(name).is_absolute(), 'Unsafe source path')
        if expected is None:
            continue
        target = project / name
        target.parent.mkdir(parents=True, exist_ok=True)
        if name.endswith('/' + native.name):
            need(digest(native) == expected, 'Actual native runtime bytes differ')
            os.link(native, target)
        elif name.endswith('/' + RAPIER.name):
            need(digest(RAPIER) == expected, 'Actual Rapier runtime bytes differ')
            os.link(RAPIER, target)
        else:
            raw = committed(DRIVER, OVERLAYS.get(name, 'godot/' + name)) if name in campaign['overlay_sha256'] \
                else committed(APPLICATION, 'godot/' + name)
            need(sha(raw) == expected, 'Actual committed application/driver input differs: ' + name)
            target.write_bytes(raw)


def extract_direct(bundle, prefix, target):
    target.mkdir(parents=True, exist_ok=True)
    count = 0
    for member in bundle.namelist():
        if member.startswith(prefix + '/') and '/' not in member[len(prefix) + 1:] and not member.endswith('/'):
            (target / Path(member).name).write_bytes(bundle.read(member))
            count += 1
    return count


def assert_process(process, data, arguments, engine, thread):
    need(process['exit_code'] == 0 and process['timed_out'] is False
         and process['surviving_children_at_exit'] is False and process['interruption'] is None,
         'Actual child failed, timed out or survived cleanup')
    need(process['source_commit'] == APPLICATION and process['wrapper_pid'] == process['observed_application_pid']
         == data['process_id'] and process.get('app_sampler_pid_matched', True) is True,
         'Actual child source or process owner differs')
    command = process['command']
    need(command[1:] == arguments and command[0] == engine
         and PureWindowsPath(command[0]).is_absolute()
         and command[command.index('--render-thread') + 1] == thread
         and command[command.index('--rendering-driver') + 1] == 'opengl3_angle',
         'Actual command differs from retained exact owner/engine/arguments')


need(not OUTPUT.exists(), 'Preserve original independent replay')
need(digest(ARCHIVE) == ARCHIVE_SHA, 'Exact original focused artifact differs')
need(subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip() == DRIVER,
     'Replay checkout is not the exact separately committed execution driver')
contract = load_module('focused_execution_contract', ROOT / 'tools/pubpres_final_requalification/contract.py')
font_main, renderer_main, verify_font = contract.qualified_functions()
# The source-locked execution derivation is retained unchanged. Only its
# read-only verify_qualification entry point is called; no engine is executed.
registered = contract.registration()
identity = registered['engine_identity']
driver = contract.augment_driver(verify_driver())
execution_binding = contract.execution_registration(driver)
old_restore = load_module('focused_original_engine_reader', ROOT / 'tools/ci/restore_workbench_godot.py')
payload_temporary = tempfile.TemporaryDirectory(prefix='pubpres-font-runtime-peer-', dir=BASE / 'evidence-c')
atexit.register(payload_temporary.cleanup)
OLD_PAYLOAD = Path(payload_temporary.name) / 'original'
old_build = old_restore.restore(OLD_ENGINE_ARCHIVE, OLD_PAYLOAD)
old_build = old_restore.verify_payload(OLD_PAYLOAD)
shutil.rmtree(OLD_PAYLOAD)
PAYLOAD = Path(payload_temporary.name) / 'repaired'
payload = sys.modules['payload']
repaired_build = payload.restore(ENGINE_ARCHIVE, PAYLOAD,
    archive_sha256=registered['artifacts']['engine']['sha256'], **identity)
engine = PAYLOAD / 'bin/godot.windows.editor.x86_64.exe'
need(digest(engine) == registered['engine_gui_sha256'], 'Actual repaired executable differs')
rapier_proof = json.loads(committed(APPLICATION, 'godot/addons/godot-rapier2d/runtime-provenance.windows.json'))
need(digest(RAPIER) == rapier_proof['sha256'], 'Actual Windows Rapier differs from committed provenance')
report = {
    'schema': 'pubpres-focused-font-independent-replay-v1', 'archive_sha256': ARCHIVE_SHA,
    'reader_sha256': digest(Path(__file__)), 'independent_physical_reader_sha256': digest(Path(independent.__file__)),
    'driver': driver, 'application': registered['application'], 'execution_registration': execution_binding,
    'engine_sha256': digest(engine), 'engine_proof_sha256': identity['proof_sha256'],
    'engine_archive_sha256': digest(ENGINE_ARCHIVE), 'original_engine_archive_sha256': digest(OLD_ENGINE_ARCHIVE),
    'original_engine_sha256': old_build['executables'][Path(old_build['gui_executable']).name]['sha256'],
    'rapier': rapier_proof, 'native_runtime': None, 'font_and_startup': None, 'gpu_histories': [],
    'cases': [], 'failures': [], 'complete': False, 'physical_acceptance': 'HOLD',
    'scope': 'Read-only replay of original Windows/ANGLE execution. Every frozen renderer-derived V3 native, terrain, callback, Water, body, input and GPU predicate is retained. Actual source/runtime/driver, submitted pose/geometry/Follow/CPU and raw font/startup/180-admission histories are revalidated. Original red predecessor and all negative controls are unchanged. No new Godot execution, physical NVIDIA acceptance or default promotion.',
}

with zipfile.ZipFile(ARCHIVE) as bundle, tempfile.TemporaryDirectory(prefix='pubpres-font-peer-', dir=BASE / 'evidence-c') as temporary:
    temp = Path(temporary)
    summary_raw = bundle.read('execution/comparison/SUMMARY.json')
    summary = json.loads(summary_raw)
    need(summary['complete'] is True and summary['failures'] == [] and summary['driver'] == driver
         and summary['execution_registration'] == execution_binding, 'Original comparison driver/completion differs')
    source = summary['source']
    contract.registered_source(source, driver)
    contract.registered_runtime(source)
    verified = verify_retained_runtime(source, RUNTIME, target_platform='windows')
    need(all(verified[key] == source['native_runtime'][key] for key in
             ('manifest_sha256', 'binary_sha256', 'source_inputs_sha256', 'toolchain', 'build_commit')),
         'Complete native source/build/dependency custody differs')
    report['native_runtime'] = verified
    need(summary['reducer'] == verify_renderer_reducer(ROOT), 'Explicit frozen render-owner derivation differs')
    font = temp / 'font'
    # Keep only actual replay inputs, never shader caches or duplicated projects.
    for member in bundle.namelist():
        if not member.startswith('execution/font/') or member.endswith('/'):
            continue
        relative = member.removeprefix('execution/font/')
        if '/profile/' in relative or relative.startswith(('font-projects/', 'startup-projects/', 'startup-template/examples/')):
            continue
        target = font / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(bundle.read(member))
    gate = verify_font(font / 'SUMMARY.json', source=source, repaired_payload=PAYLOAD, **identity)
    need(gate == summary['font_qualification'], 'Original raw font/startup gate differs')
    font_summary = json.loads((font / 'SUMMARY.json').read_bytes())
    report['font_and_startup'] = {
        'verification': gate, 'font_arms': font_summary['font_arms'],
        'font_comparison': font_summary['font_comparison'], 'startup_arms': font_summary['startup_arms'],
    }
    campaign_raw = bundle.read('execution/comparison/campaign.json')
    campaign = json.loads(campaign_raw)
    need(sha(campaign_raw) == summary['campaign_sha256'], 'Original campaign bytes differ')
    report['campaign_sha256'] = sha(campaign_raw)
    report['original_summary_sha256'] = sha(summary_raw)
    for row in summary['qualification']:
        thread = row['render_thread']
        folder = temp / ('gpu-' + thread)
        extract_direct(bundle, 'execution/comparison/qualification/' + thread, folder)
        receipt = folder / 'receipt.json'
        need(digest(receipt) == row['receipt_sha256'] and row['complete'] is True,
             'Original per-owner GPU receipt differs')
        project = folder / 'project'
        for name in ('scripts/main.gd', 'scripts/full_image_ring_publisher.gd', 'shaders/material_palette.gdshader',
                     'tests/support/ci_execution_policy.json'):
            target = project / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(committed(APPLICATION, 'godot/' + name))
        (project / 'tests/pubpres_final_two_slot_oracle.gd').write_bytes(
            committed(DRIVER, 'tools/pubpres_final_windows/two_slot_oracle.gd'))
        process = json.loads((folder / 'process.json').read_bytes())
        need(process == row['process'] and process['exit_code'] == 0 and process['timed_out'] is False
             and process['surviving_children_at_exit'] is False and process['interruption'] is None,
             'GPU process or cleanup differs')
        need(process['command'][0] == font_summary['engine_paths']['repaired']
             and process['source_commit'] == APPLICATION
             and process['command'][process['command'].index('--render-thread') + 1] == thread
             and process['command'][process['command'].index('--script') + 1] == 'res://tests/pubpres_final_two_slot_oracle.gd',
             'GPU command source/engine/owner/fixture differs')
        need(not any('ERROR:' in (folder / name).read_text(errors='replace') for name in ('stdout.log', 'stderr.log')),
             'GPU strict diagnostics failed')
        evidence = validate_gpu(receipt, project, source=APPLICATION, driver='opengl3_angle',
                                engine_sha256=digest(engine), separate=thread == 'separate')
        need(evidence == row['evidence'] and evidence['context']['process_id'] == process['observed_application_pid'],
             'Independent first-read GPU history or actual process differs')
        report['gpu_histories'].append({'render_thread': thread, 'receipt_sha256': digest(receipt),
                                       'process_id': process['observed_application_pid'],
                                       'independent_validation': evidence['independent_validation']})
        print('PASS', 'GPU', thread, flush=True)

    for case in summary['cases']:
        actual_arms, compact_arms = [], []
        scenario = next(value for value in campaign['cases'] if value['id'] == case['case'])
        for arm in case['arms']:
            thread = arm['treatment']['render_thread']
            member = 'execution/comparison/' + case['case'] + '/' + str(arm['index']) + '-repaired-' + thread
            with tempfile.TemporaryDirectory(prefix='pubpres-font-arm-', dir=temp) as local:
                folder = Path(local)
                extract_direct(bundle, member, folder)
                receipt = folder / 'receipt.json'
                data = json.loads(receipt.read_bytes())
                need(digest(receipt) == arm['receipt_sha256'] and data['source_identity']['source_sha'] == APPLICATION,
                     'Original physical receipt/application differs')
                plan = json.loads((folder / 'arm.json').read_bytes())
                process = json.loads((folder / 'process.json').read_bytes())
                need(process == arm['process'] and plan['source'] == source and plan['treatment'] == arm['treatment'],
                     'Timed original source/treatment/process differs')
                assert_process(process, data, plan['arguments'], font_summary['engine_paths']['repaired'], thread)
                need(not any('ERROR:' in (folder / name).read_text(errors='replace') for name in ('stdout.log', 'stderr.log')),
                     'Timed strict diagnostics failed')
                validate_requested_renderer(data, scenario, campaign, APPLICATION, plan['nonce'], digest(engine), thread)
                validate_deadline_off(data)
                project = folder / 'project'
                project.mkdir()
                reconstruct(project, data, campaign, Path(verified['binary_path']))
                analysis = reduce_receipt(receipt, campaign, project, engine, 'C', expected_render_thread=thread)
                analysis['physical_gap_counts_above_ms'] = observed_gap_counts(
                    folder / 'receipt-events.jsonl', analysis['windows'], [100, 250, 500, 1000])
                need(analysis == arm['statistics'], 'Complete frozen physical/GPU/Water reduction differs')
                events = [json.loads(line) for line in (folder / 'receipt-events.jsonl').read_text().splitlines()]
                validate_draw_identity(events, thread)
                slots = validate_slot_treatment(data, events, 2, True,
                                                expected_extent=campaign['fixtures'][scenario['fixture']]['extent'])
                need(slots == arm['slots'], 'Actual Full2 slot proof differs')
                observers = validate_observers(receipt, process, project, True)
                need(observers == arm['observers'], 'Independent actual submitted pose/geometry/Follow/CPU proof differs')
                supplementary = supplementary_metrics(receipt)
                need(supplementary == arm['supplementary'], 'Supplementary actual material/draw metrics differ')
                need(thread != 'separate' or all(not value['material_draw_identity_available']
                     for value in supplementary['windows'].values()), 'Separate acquired an invented draw/material association')
                physical = independent.reduce(receipt)
                for window, result in physical['windows'].items():
                    expected = analysis['windows'][window]
                    need(abs(expected['rapier_steps_per_second'] - result['rapier_steps_per_second']) < 1e-10
                         and expected['completed_rapier_steps'] == result['completed_rapier_steps']
                         and all(abs(expected['physical_gap_ms'][key] - result['physical_gap_ms'][key]) < 1e-8
                                 for key in ('p50', 'p95', 'p99', 'max')),
                         'Independent callback/native/terrain/input witness or quantiles differ')
                memory = json.loads((folder / 'process-memory.json').read_bytes())
                report_memory = {'sampled_peak_rss_bytes': process['sampled_peak_rss_bytes'],
                                 'scope': process['memory_scope'], 'retained_trace_sha256': digest(folder / 'process-memory.json')}
                actual_arms.append(dict(arm, statistics=analysis, slots=slots, observers=observers, supplementary=supplementary))
                compact_arms.append({'index': arm['index'], 'render_thread': thread, 'member': member,
                                     'receipt_sha256': digest(receipt), 'trace_sha256': data['trace_sha256'],
                                     'physical_witness': physical['physical_witness'], 'windows': physical['windows'],
                                     'observers': observers, 'memory': report_memory,
                                     'host': {'cpu': data['cpu'], 'adapter': data['adapter'], 'logical_processors': data['logical_processors']},
                                     'supplementary': supplementary, 'all_frozen_predicates_passed': True})
                print('PASS', member, flush=True)
        cohort = validate_cohort(actual_arms, summary['registration'], digest(engine), True)
        need({key: case[key] for key in cohort} == cohort, 'Same-engine complete matched cohort/parity differs')
        report['cases'].append({'case': case['case'], 'arms': compact_arms, 'cohort': cohort})
        OUTPUT.write_text(json.dumps(report, indent=2) + '\n')
report['complete'] = len(report['gpu_histories']) == 2 and sum(len(case['arms']) for case in report['cases']) == 8
OUTPUT.write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({'complete': report['complete'], 'output': str(OUTPUT), 'sha256': digest(OUTPUT)}))
