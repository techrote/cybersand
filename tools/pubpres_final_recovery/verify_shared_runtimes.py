#!/usr/bin/env python3
"""Preserve all frozen cross-source toolchain predicates before final comparison."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import sys

from identity import ROOT
from run_campaign import source_identity
from runtime_replay import verify_recorded_runtime
from run_source_abba import TOOLCHAIN_FIELDS
from results import need
from run_focus import write_json


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for key in ('root','main-source','donor-source'):parser.add_argument('--'+key,type=Path,required=True)
    parser.add_argument('--platform',choices=('linux','windows'),required=True)
    args=parser.parse_args();roles={'M':args.main_source,'C':ROOT,'D':args.donor_source};records={}
    for role,root in roles.items():
        source=source_identity(root)
        records[role]={'source':source,'runtime':verify_recorded_runtime(root,source,args.root/role,target_platform=args.platform)}
    for key in TOOLCHAIN_FIELDS:
        need(all(value['runtime']['toolchain'][key]==records['C']['runtime']['toolchain'][key] for value in records.values()),
             'Frozen comparison toolchain field differs: '+key)
    result={'schema':'pubpres-recovery-shared-native-custody-v1','platform':args.platform,'roles':records,
        'matched_toolchain_fields':list(TOOLCHAIN_FIELDS),'complete':True,'physical_acceptance':'HOLD',
        'scope':'Independent source-exact M/C/D native builds sharing one exact dependency per platform. Binary custody only, no inherited gameplay or package acceptance.'}
    write_json(args.root/'SHARED-NATIVE-CUSTODY.json',result)
    print(json.dumps({'complete':True,'roles':list(records),'platform':args.platform,'physical_acceptance':'HOLD'}))

if __name__=='__main__':main()
