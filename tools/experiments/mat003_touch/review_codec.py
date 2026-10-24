"""Reproduce narrow #230 fixture limitations from its immutable Git source.

This executes only the experimental Python codec tests and synthetic inputs.
It does not implement a native loader or alter #230.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest

REVISION='0d6d71301c5ce24d2dd1a80fe99cb1ac11bfb5a4'
SOURCE='tools/experiments/mat003_gen006_codec_fixture.py'


def review(output):
    output=Path(output);output.mkdir(parents=True,exist_ok=False)
    data=subprocess.check_output(['git','show',REVISION+':'+SOURCE])
    path=output/'original_codec.py';path.write_bytes(data)
    spec=importlib.util.spec_from_file_location('mat003_codec_reference',path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    argv=[sys.executable,'-B',str(path.resolve())]
    with (output/'tests.stdout').open('xb') as stdout,(output/'tests.stderr').open('xb') as stderr:
        code=subprocess.run(argv,stdout=stdout,stderr=stderr,timeout=60).returncode
    result={'source_commit':REVISION,'source_path':SOURCE,'source_sha256':hashlib.sha256(data).hexdigest(),
            'test_cases':unittest.defaultTestLoader.loadTestsFromModule(module).countTestCases(),
            'argv':argv,'timeout_seconds':60,'exit_code':code,'timing':False,
            'scope':'unmodified nonproduction fixture review, no native acceptance','probes':[]}
    if code:
        (output/'review.json').write_text(json.dumps(result,indent=2)+'\n')
        raise ValueError('original codec tests failed')
    for name,receipt,live in (('missing-all',{},{}),('missing-session-and-job',{'world_id':'same'},{'world_id':'same'})):
        result['probes'].append({'name':name,'accepted':module.admitted_result(receipt,live)})
    record=module.sample();record['version']=True
    result['probes'].append({'name':'boolean-schema-version','roundtrip_version':module.decode(module.encode(record))['version']})
    (output/'review.json').write_text(json.dumps(result,indent=2)+'\n')
    seals={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in output.iterdir() if p.is_file()}
    (output/'inventory.json').write_text(json.dumps(seals,indent=2)+'\n')
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    print(json.dumps(review(args.output),indent=2))
