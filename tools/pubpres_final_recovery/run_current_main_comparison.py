#!/usr/bin/env python3
"""Current accepted-main N/C/C/N comparison with unchanged physical predicates."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import shutil
import uuid

from identity import ROOT, HERE, driver_identity, digest
from retained_runtime import validate_runtime
from run_campaign import source_identity, copy_project, physical_outcome_parity
from run_comparison import campaign_settings, prepare, validate_task_completion
from run_focus import ENGINE_SHA256, selectors, observed_gap_counts, write_json
from results import canonical, need
from renderer_contract import verify_renderer_reducer
from results_registered_renderer import reduce_receipt
from run_source_abba import compare_registered_direction
from observer_support import execute_with_resources, validate_observers, SELECTOR
from requested_capture import validate_requested_renderer
from run_renderer_comparison import strict_logs, validate_draw_identity
from run_bounded_comparison import OBSERVER, validate_selectors
from qualification_gate import verify_summary, verify_inventory
from engine_trace import validate_files as validate_engine_trace
import engine_admission

REGISTRATION = HERE / 'current-main-registration.json'
ARCHITECTURES = {
    'stock_safe': {'engine': 'stock', 'render_thread': 'safe', 'lookahead': 0},
    'atomic_safe0': {'engine': 'bounded', 'render_thread': 'safe', 'lookahead': 0},
    'atomic_separate0': {'engine': 'bounded', 'render_thread': 'separate', 'lookahead': 0},
    'atomic_separate4': {'engine': 'bounded', 'render_thread': 'separate', 'lookahead': 4},
}


def validate_control(data, case, campaign, source, nonce, engine, backend):
    """Missing legacy APIs stay unavailable, never relabelled as candidate APIs."""
    need(data['source_identity']['source_sha'] == source['source_commit']
         and data['source_identity']['engine_sha256'] == digest(engine)
         and data['case_nonce'] == nonce, 'Current-main source/engine/nonce differs')
    expected = {'renderer': backend, 'render_thread': {'requested': 'safe', 'runtime': 'safe'},
                'camera': case['camera'], 'workers': case['workers'], 'water_law': case['water_law'],
                'water_variant': case.get('water_variant', 'reference'),
                'water_profile': case.get('water_profile', campaign['measurement']['water_profile']),
                'input_mode': case.get('input_mode', 'tape'), 'command_mode': 'repeated_callback',
                'observer_mode': 'full'}
    need(data['fixture']['name'] == case['fixture'] and all(data[k] == v for k, v in expected.items()),
         'Current-main workload, renderer or observation differs')
    for phase in ('selectors_before', 'selectors_after'):
        state = data[phase]
        need(all(state[key] is None for key in ('material', 'physics', 'presentation', 'cadence', 'rendezvous')),
             'Current-main control unexpectedly acquired candidate APIs')
        wanted = {'CYBERSAND_DIAG_PHYSICS_PUBLICATION': 'combined', 'CYBERSAND_DIAG_PRESENTATION': 'legacy',
                  'CYBERSAND_DIAG_RENDER_CADENCE': 'source-default', 'CYBERSAND_DIAG_ACTUAL_SUBMISSION': '0',
                  'CYBERSAND_DIAG_WATER_COMPOSITION': '0', 'CYBERSAND_PLAYABILITY_TASK_COMPLETION_BARRIER': '0', SELECTOR: '0'}
        need(all(state['requested'].get(k) == v for k, v in wanted.items()), 'Current-main control policy differs')


def validate_cohort(arms, sources, engines, treatment):
    need(len(arms) == 4 and [row['arm'] for row in arms] == ['N', 'C', 'C', 'N']
         and [row['index'] for row in arms] == list(range(4)), 'Incomplete current-main ABBA cohort')
    comparable = []
    for row in arms:
        role = row['arm']; stats = row['statistics']; match = dict(stats['match'])
        selected = treatment if role == 'C' else ARCHITECTURES['stock_safe']
        need(stats['source'] == sources[role]['source_commit']
             and stats['registered_material_treatment'] == {'backend': 'full', 'policy': ''}
             and stats['same_frame_continuation']['enabled'] is False
             and row['observers']['presentation_enabled'] is False,
             'Wrong source/material/physical continuation or asymmetric observer')
        need(match['engine'] == digest(engines[selected['engine']])
             and match['render_thread'] == {'requested': selected['render_thread'], 'runtime': selected['render_thread']},
             'Actual engine/owner differs from the declared whole architecture')
        del match['engine'], match['render_thread']
        comparable.append(match)
    need(all(canonical(value) == canonical(comparable[0]) for value in comparable),
         'Hardware, fixture, Water, workers, camera or physical workload differs')
    parity = physical_outcome_parity(arms)
    need(len(parity['pairs']) == 6 and all(row['bodies_equal'] and row['admitted_moves_equal'] for row in parity['pairs']),
         'Current-main equal-step physical outcomes or admitted inputs diverged')
    return {'physical_outcome_parity': parity, 'registered_direction': compare_registered_direction(arms, reference='N')}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=ROOT)
    for name in ('current-main-source', 'current-main-runtime', 'runtime', 'stock-engine', 'stock-correctness', 'output'):
        parser.add_argument('--'+name, type=Path, required=True)
    parser.add_argument('--stock-water-correctness', type=Path)
    parser.add_argument('--architecture', choices=tuple(ARCHITECTURES), required=True)
    parser.add_argument('--water-composition', type=int, choices=(0, 1), required=True)
    parser.add_argument('--task-completion', type=int, choices=(0, 1), required=True)
    parser.add_argument('--case', action='append', required=True)
    parser.add_argument('--display-wrapper', type=Path)
    parser.add_argument('--rapier-runtime', type=Path)
    for name in ('development-engine', 'development-engine-proof', 'development-gates', 'correctness-inventory'):
        parser.add_argument('--'+name, type=Path)
    engine_admission.add_arguments(parser)
    args = parser.parse_args()
    need(not any(key.startswith('WB_COMBINED_') for key in os.environ), 'Inherited unregistered combined treatment')
    output = args.output.resolve(); need(not output.exists(), 'Preserve every original comparison attempt')
    registered = json.loads(REGISTRATION.read_bytes())
    need(registered['schema'] == 'pubpres-closure-current-main-comparison-v1'
         and registered['order'] == ['N', 'C', 'C', 'N'] and set(args.case) <= set(registered['cases'])
         and len(args.case) == len(set(args.case)), 'Unregistered or repeated current-main comparison')
    roots = {'N': args.current_main_source.resolve(), 'C': args.source.resolve()}
    runtime_paths = {'N': args.current_main_runtime.resolve(), 'C': args.runtime.resolve()}
    driver = driver_identity(); sources = {}
    for role, root in roots.items():
        source = source_identity(root)
        source['native_runtime'] = validate_runtime(root, source, runtime_paths[role], False)
        sources[role] = source
    need(sources['N']['source_commit'] == registered['current_main']
         and sources['C']['source_commit'] == driver['source_commit']
         and sources['C']['source_tree'] == driver['source_tree'], 'Exact N/C source registration differs')
    need(sources['N']['native_runtime']['toolchain'] == sources['C']['native_runtime']['toolchain'],
         'Current-main and candidate native dependency/toolchain cohort differs')
    platform = 'windows' if os.name == 'nt' else 'linux'; backend = 'opengl3_angle' if os.name == 'nt' else 'opengl3'
    stock = args.stock_engine.resolve(); need(digest(stock) == ENGINE_SHA256[platform], 'Stock executable bytes differ')
    treatment = ARCHITECTURES[args.architecture]; engines = {'stock': stock}
    prerequisites = [verify_summary(args.stock_correctness, sources['C'], driver, stock, 'frozen')]
    if args.water_composition:
        need(args.stock_water_correctness is not None, 'Selected Water needs exact resulting graphical qualification')
        prerequisites.append(verify_summary(args.stock_water_correctness, sources['C'], driver, stock, 'water'))
    if treatment['engine'] == 'bounded':
        if args.development_engine:
            need(args.engine_payload is None and args.development_engine_proof and args.development_gates,
                 'Explicit local engine and all resulting graphical transaction gates required')
            from development_engine import admit
            custom = args.development_engine.resolve()
            admission = admit(custom, args.development_engine_proof, args.development_gates, sources['C'], args.water_composition)
        else:
            need(os.name == 'nt' and args.correctness_inventory is not None, 'Qualified Windows integration inventory required')
            custom, admission = engine_admission.admit(args)
            prerequisites.append(verify_inventory(args.correctness_inventory, sources['C'], driver, stock, custom, args.water_composition))
        engines['bounded'] = custom; prerequisites.append(admission)
    else:
        need(args.development_engine is None and args.engine_payload is None, 'Stock comparison cannot carry a custom engine')
    base = json.loads((ROOT/'tools/pubpres_final/registration.json').read_bytes())
    need(all(base[key] == registered[key] for key in ('minimum_capture_usec', 'minimum_real_steps', 'maximum_capture_usec', 'reported_gap_thresholds_ms')),
         'Original observation windows or reported tails changed')
    campaign = campaign_settings(base, args.case, False)
    campaign['source_commits']['main'] = registered['current_main']
    campaign['closure_current_main_registration_sha256'] = digest(REGISTRATION)
    campaign['overlay_sha256'][OBSERVER] = digest(HERE/'pubpres_recovery_gameplay.gd')
    campaign['observer_entrypoint'] = OBSERVER
    output.mkdir(parents=True); write_json(output/'campaign.json', campaign)
    report = {'schema': 'pubpres-closure-current-main-result-v1', 'registration': registered,
              'registration_sha256': digest(REGISTRATION), 'sources': sources, 'driver': driver,
              'architecture': args.architecture, 'water_composition': args.water_composition,
              'task_completion': args.task_completion, 'prerequisites': prerequisites,
              'reducer': verify_renderer_reducer(ROOT), 'cases': [], 'failures': [], 'complete': False,
              'physical_acceptance': 'HOLD', 'scope': registered['scope']}
    def save(): write_json(output/'SUMMARY.json', report)
    save(); templates = {}
    for role in ('N', 'C'):
        templates[role] = prepare(roots[role], sources[role], output/('template-'+role), campaign, stock,
                                  args.rapier_runtime, overlay_sources={OBSERVER: HERE/'pubpres_recovery_gameplay.gd'})
        strict_logs(output/('template-'+role)/'import')
    for case in campaign['cases']:
        arms = []
        for index, role in enumerate(registered['order']):
            selected = treatment if role == 'C' else ARCHITECTURES['stock_safe']
            source = sources[role]; engine = engines[selected['engine']]; thread = selected['render_thread']
            folder = output/case['id']/(str(index)+'-'+role); folder.mkdir(parents=True)
            project = output/'projects'/(case['id']+'-'+str(index)); project.parent.mkdir(parents=True, exist_ok=True)
            copy_project(templates[role], project, imported=True)
            receipt = folder/'receipt.json'; nonce = uuid.uuid4().hex
            settings = selectors({'material': 'full', 'same_frame_continuation': False, 'wave_column_probe': False, 'causal': False}, nonce)
            water = args.water_composition if role == 'C' else 0
            task = args.task_completion if role == 'C' else 0
            settings.update(CYBERSAND_DIAG_FULL_IMAGE_SLOTS='2', CYBERSAND_PLAYABILITY_RENDER_THREAD=thread,
                CYBERSAND_MATERIAL_QUEUE_THREAD=thread, CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ='0', CYBERSAND_DIAG_MATERIAL_STEP_INTERVAL='0',
                CYBERSAND_DIAG_ACTUAL_SUBMISSION='1' if selected['engine'] == 'bounded' else '0', CYBERSAND_DIAG_WATER_COMPOSITION=str(water),
                CYBERSAND_ENGINE_RENDER_LOOKAHEAD=str(selected['lookahead']) if selected['engine'] == 'bounded' else '',
                CYBERSAND_ENGINE_RENDER_LOOKAHEAD_TRACE=str(folder/'engine-draws.json') if selected['engine'] == 'bounded' else '',
                CYBERSAND_PLAYABILITY_TASK_COMPLETION_BARRIER=str(task))
            settings[SELECTOR] = '0'
            if role == 'N':
                settings.update(CYBERSAND_DIAG_PHYSICS_PUBLICATION='combined', CYBERSAND_DIAG_PRESENTATION='legacy',
                                CYBERSAND_DIAG_RENDER_CADENCE='source-default', CYBERSAND_DIAG_MATERIAL_TIMING='legacy')
                # These policies never existed on accepted main. V3 distinguishes absent requests from OFF.
                for key in ('CYBERSAND_DIAG_SAME_FRAME_CONTINUATION', 'CYBERSAND_PLAYABILITY_WAVE_COLUMN_TILES',
                            'CYBERSAND_PLAYABILITY_WAVE_COLUMN_PROBE'):
                    settings.pop(key)
            arguments = ['--path', str(project), '--rendering-method', 'gl_compatibility', '--rendering-driver', backend,
                         '--render-thread', thread, '--audio-driver', 'Dummy', '--log-file', str(folder/'godot.log'),
                         '--script', 'res://'+OBSERVER, '--', '--receipt='+str(receipt), '--fixture='+case['fixture'],
                         '--camera='+case['camera'], '--workers='+str(case['workers']), '--water-law='+case['water_law'],
                         '--water-variant='+case.get('water_variant', 'reference'),
                         '--water-profile='+case.get('water_profile', campaign['measurement']['water_profile']),
                         '--input-mode='+case.get('input_mode', 'tape'), '--command-mode=repeated_callback', '--observer-mode=full']
            write_json(folder/'arm.json', {'source': source, 'scenario': case, 'nonce': nonce, 'selectors': settings,
                                          'treatment': selected, 'arguments': arguments})
            print(case['id'], index, role, selected, flush=True)
            try:
                process = execute_with_resources(engine, arguments, folder, source['source_commit'], settings, 420, args.display_wrapper)
                strict_logs(folder); data = json.loads(receipt.read_bytes())
                if role == 'N': validate_control(data, case, campaign, source, nonce, engine, backend)
                else:
                    validate_requested_renderer(data, case, campaign, source['source_commit'], nonce, digest(engine), thread, expected_driver=backend)
                    validate_selectors(data, selected, water, False)
                    validate_task_completion(data, bool(task))
                analysis = reduce_receipt(receipt, campaign, project=project, engine=engine,
                                          arm_letter='M' if role == 'N' else 'C', expected_render_thread=thread)
                observers = validate_observers(receipt, process, project, False)
                events = [json.loads(line) for line in receipt.with_name('receipt-events.jsonl').read_text().splitlines()]
                validate_draw_identity(events, thread)
                analysis['physical_gap_counts_above_ms'] = observed_gap_counts(receipt.with_name('receipt-events.jsonl'), analysis['windows'], registered['reported_gap_thresholds_ms'])
                need(process['observed_application_pid'] == data['process_id'], 'Actual observed application PID differs')
                trace = validate_engine_trace(folder, data, thread=thread, budget=selected['lookahead'], presentation_enabled=False) if selected['engine'] == 'bounded' else None
                row = {'arm': role, 'index': index, 'statistics': analysis, 'observers': observers,
                       'process': process, 'engine_trace': trace, 'receipt_sha256': digest(receipt)}
                arms.append(row); write_json(folder/'analysis.json', row); shutil.rmtree(project)
            except Exception as error:
                report['failures'].append({'case': case['id'], 'index': index, 'role': role, 'reason': str(error)})
            save()
        result = {'case': case['id'], 'arms': arms}
        try: result.update(validate_cohort(arms, sources, engines, treatment))
        except Exception as error: report['failures'].append({'case': case['id'], 'reason': str(error)})
        report['cases'].append(result); save()
    report['complete'] = not report['failures']; save()
    print(json.dumps({'complete': report['complete'], 'failures': report['failures'], 'physical_acceptance': 'HOLD'}))
    return 0 if report['complete'] else 1


if __name__ == '__main__': raise SystemExit(main())
