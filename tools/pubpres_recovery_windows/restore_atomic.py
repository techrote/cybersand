#!/usr/bin/env python3
"""Download and re-admit original build02 using retained artifact acquisition."""
import argparse
import json
from pathlib import Path
import sys
import atomic_delivery

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/pubpres_final_recovery'))
from restore_inputs import download
from engine_admission import load_bounded_payload


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();output=args.output.resolve()
    atomic_delivery.need(not output.exists(),'Preserve original engine restore results')
    output.mkdir(parents=True)
    pin=atomic_delivery.pin();archive=output/'original-build02.zip'
    metadata=download(pin,archive)
    proof=load_bounded_payload().restore(archive,output/'payload',archive_sha256=pin['sha256'],
        build_source=pin['source'],build_run=pin['run'],build_attempt=pin['attempt'],proof_sha256=pin['proof_sha256'])
    result={'schema':'pubpres-closure-original-engine-v1','pin':pin,'metadata':metadata,
        'version':proof['version'],'complete':True,'physical_acceptance':'HOLD'}
    (output/'ADMISSION.json').write_text(json.dumps(result,indent=2)+'\n')


if __name__=='__main__':main()
