#!/usr/bin/env python3
"""Fresh historical M/current N/candidate C/frozen D native input custody."""
import argparse
import json
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/pubpres_final_recovery'))
from identity import ROOT as DRIVER_ROOT
from run_campaign import source_identity
from runtime_replay import verify_recorded_runtime
from run_source_abba import TOOLCHAIN_FIELDS
from results import need


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ('root','historical-main','current-main','donor'):parser.add_argument('--'+name,type=Path,required=True)
    parser.add_argument('--platform',choices=('linux','windows'),required=True)
    args=parser.parse_args()
    records={}
    for role,path in {'M':args.historical_main,'N':args.current_main,'C':ROOT,'D':args.donor}.items():
        source=source_identity(path)
        records[role]={'source':source,'runtime':verify_recorded_runtime(path,source,args.root/role,target_platform=args.platform)}
    for field in TOOLCHAIN_FIELDS:
        need(all(row['runtime']['toolchain'][field]==records['C']['runtime']['toolchain'][field] for row in records.values()),
             'Fresh comparison toolchain field differs: '+field)
    # Report which source bytes changed, even when two same-sized inventories
    # contain different code. The verifier above already bound each build to
    # its own Git tree, compiler, library and complete dependency receipt.
    runtime_inputs = {}
    dependencies = {}
    for role in records:
        directory = args.root / role
        runtime = json.loads((directory / 'PUBPRES-RUNTIME.json').read_bytes())
        runtime_inputs[role] = runtime['source_inputs_sha256']
        dependency = json.loads((directory / 'GODOT-CPP-DEPENDENCY.json').read_bytes())
        dependencies[role] = dependency['source_inputs_sha256']
    need(all(entries == dependencies['C'] for entries in dependencies.values()),
         'Native roles used different generated or authored godot-cpp inputs')
    base, candidate = runtime_inputs['N'], runtime_inputs['C']
    native_delta = {path: {'current_main': base.get(path), 'candidate': candidate.get(path)}
                    for path in sorted(base.keys() | candidate.keys()) if base.get(path) != candidate.get(path)}
    result={'schema':'pubpres-closure-shared-native-custody-v1','platform':args.platform,'roles':records,
        'current_main_candidate_native_input_changes': native_delta,
        'all_roles_dependency_inputs_identical': True,
        'matched_toolchain_fields':list(TOOLCHAIN_FIELDS),'complete':True,'physical_acceptance':'HOLD',
        'scope':'Four independent source-exact native builds share one dependency and toolchain. Historical M and accepted-main N retain separate identities; no gameplay or performance acceptance.'}
    (args.root/'CLOSURE-NATIVE-CUSTODY.json').write_text(json.dumps(result,indent=2)+'\n')


if __name__=='__main__':main()
