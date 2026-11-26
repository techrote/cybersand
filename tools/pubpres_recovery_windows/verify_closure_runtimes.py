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
    result={'schema':'pubpres-closure-shared-native-custody-v1','platform':args.platform,'roles':records,
        'matched_toolchain_fields':list(TOOLCHAIN_FIELDS),'complete':True,'physical_acceptance':'HOLD',
        'scope':'Four independent source-exact native builds share one dependency and toolchain. Historical M and accepted-main N retain separate identities; no gameplay or performance acceptance.'}
    (args.root/'CLOSURE-NATIVE-CUSTODY.json').write_text(json.dumps(result,indent=2)+'\n')


if __name__=='__main__':main()
