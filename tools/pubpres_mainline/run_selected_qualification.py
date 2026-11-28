#!/usr/bin/env python3
"""Repeat unchanged graphical fixtures with the evaluated Workbench owner flags.

The original legacy arms remain separate. This adapter changes exactly three
process environment values, preserves the complete case population, semantic readers and watchdogs, and
requires actual Main/worker readback in the graphical receipt.
"""
from __future__ import annotations
import argparse
import importlib.util
import json
from pathlib import Path
import sys
import campaign_request
import common

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/pubpres_final_recovery'))
from identity import digest

spec = importlib.util.spec_from_file_location('pubpres_mainline_original_qualification',
    ROOT / 'tools/pubpres_final_recovery/run_qualification.py')
original = importlib.util.module_from_spec(spec)
spec.loader.exec_module(original)
FLAGS = {key: common.SELECTORS[key] for key in (
    'CYBERSAND_WORKBENCH_FLIGHT_PACING', 'CYBERSAND_WORKBENCH_COUPLING_CLOCK',
    'CYBERSAND_WORKBENCH_EMPTY_EFFECTS')}
READBACK = {'flight_pacing': True, 'coupling_clock': True, 'empty_effects': True}
TESTS = {'water': 'test_workbench_water_composition_native',
         'members': 'test_workbench_member_presentation',
         'held-placement': 'test_workbench_presentation_submission'}


def main():
    if '--help' in sys.argv:
        return original.main()
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--focus', choices=tuple(TESTS), required=True)
    args, _ = parser.parse_known_args()
    selected = campaign_request.validate()
    common.require(selected['phase'] in ('qualify', 'delivery'), 'Selected owner runs need a sealed source campaign')
    output = args.output.resolve()
    common.require(not output.exists(), 'Preserve original evidence in a fresh directory')
    processes = []
    inherited_run = original.run

    def run(command, environment, folder, timeout):
        before = dict(environment)
        environment = dict(before, **FLAGS)
        common.require({key for key in set(before) | set(environment) if before.get(key) != environment.get(key)} <= set(FLAGS),
                       'Owner adapter changed an unrelated fixture environment')
        processes.append({'folder': folder.relative_to(output).as_posix(),
                          'owner_flags': {key: environment[key] for key in FLAGS},
                          'full_image_slots': environment.get('CYBERSAND_DIAG_FULL_IMAGE_SLOTS'),
                          'registered_timeout_seconds': timeout})
        return inherited_run(command, environment, folder, timeout)

    original.run = run
    try:
        code = original.main()
    finally:
        original.run = inherited_run
    path = output / 'SUMMARY.json'
    proof = json.loads(path.read_bytes())
    readback = None
    problem = None
    try:
        native = output / (TESTS[args.focus] + '-slots2') / 'receipt.json'
        raw = json.loads(native.read_bytes())
        readback = raw.get('selected_owner_readback')
        common.require(readback == READBACK, 'Actual Main/worker did not instantiate the selected Workbench owner')
        common.require(len(processes) == len(proof['outcomes'])
                       and all(row['owner_flags'] == FLAGS for row in processes), 'Incomplete selected owner process population')
    except (OSError, ValueError, KeyError, TypeError) as error:
        problem = str(error)
        proof['complete'] = False
        code = 1
    proof['selected_workbench_owner'] = {
        'schema': 'pubpres-mainline-selected-owner-v1', 'owner_flags': FLAGS,
        'actual_readback': readback, 'adapter_sha256': digest(Path(__file__)),
        'original_driver_sha256': digest(Path(original.__file__)),
        'processes': processes, 'failure': problem,
        'legacy_arms_preserved_separately': True,
        'case_population_readers_and_timeouts_unchanged': True,
        'source_owned_observation_fields_added': True}
    common.write_json(path, proof)
    print(json.dumps({'complete': proof['complete'], 'selected_owner_readback': readback, 'failure': problem}))
    return code


if __name__ == '__main__':
    raise SystemExit(main())
