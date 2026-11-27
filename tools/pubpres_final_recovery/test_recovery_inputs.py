from __future__ import annotations
import copy
from pathlib import Path
import tempfile
import unittest
import zipfile

import recovery_request as request
from restore_inputs import extract


class RecoveryRequest(unittest.TestCase):
    def valid(self):
        return {'schema':'pubpres-recovery-request-v1','phase':'stock','purpose':'Resulting-source stock graphical correctness',
            'frozen_reference':request.FROZEN,'payload_sha256':'a'*64,'engine_artifact':None,'physical_acceptance':'HOLD'}

    def test_stock_and_atomic_inputs_are_disjoint_and_exact(self):
        value=self.valid()
        self.assertEqual(request.validate_record(value),value)
        atomic=copy.deepcopy(value)
        atomic.update(phase='integration',engine_artifact={'id':1,'name':'pubpres-recovery-atomic-engine-2-1',
            'sha256':'b'*64,'source':'c'*40,'run':2,'attempt':1,'proof_sha256':'d'*64})
        self.assertEqual(request.validate_record(atomic),atomic)
        for field,bad in (('name','pubpres-bounded-engine-2-1'),('proof_sha256',''),('attempt',True),('sha256','x'*64)):
            changed=copy.deepcopy(atomic); changed['engine_artifact'][field]=bad
            with self.assertRaises(ValueError): request.validate_record(changed)
        for field,bad in (('engine_artifact',atomic['engine_artifact']),('physical_acceptance','PASS'),
                          ('frozen_reference','e'*40),('phase','final'),('payload_sha256','a'*40)):
            changed=copy.deepcopy(value); changed[field]=bad
            with self.assertRaises(ValueError): request.validate_record(changed)

    def test_artifact_extraction_refuses_ambiguous_or_escaping_paths(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            cases=[['../outside'],['/absolute'],['folder\\file'],['x','X'],['CON'],['folder/x.']]
            for index,names in enumerate(cases):
                archive=root/(str(index)+'.zip')
                with zipfile.ZipFile(archive,'w') as bundle:
                    for name in names:
                        # ZipInfo normalizes OS separators on Windows. Write the
                        # fixture's literal filename on every producer platform.
                        member = zipfile.ZipInfo(name)
                        member.filename = name
                        bundle.writestr(member,b'preserved original')
                with self.assertRaises((ValueError,RuntimeError,FileExistsError)):
                    extract(archive,root/('out'+str(index)))
            archive=root/'valid.zip'
            with zipfile.ZipFile(archive,'w') as bundle: bundle.writestr('C/PUBPRES-RUNTIME.json',b'original')
            result=extract(archive,root/'valid')
            self.assertTrue(result['crc_checked'])
            self.assertEqual((root/'valid/C/PUBPRES-RUNTIME.json').read_bytes(),b'original')

if __name__=='__main__': unittest.main()
