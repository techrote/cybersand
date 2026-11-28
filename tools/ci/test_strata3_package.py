#!/usr/bin/env python3
"""Adverse portable source-byte controls using explicitly synthetic fixtures."""
import copy
import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import package_strata3_workbench as package


def git_blob(data):return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()


class OpticalPackageCustody(unittest.TestCase):
    def setUp(self):
        self.temporary=tempfile.TemporaryDirectory(prefix='strata3-package-unit-');self.addCleanup(self.temporary.cleanup)
        self.root=Path(self.temporary.name)
        self.data={'examples/worldgen/unit.json':b'{"unit_fixture":true}\n',
                   'godot/shaders/unit.gdshader':b'SYNTHETIC SOURCE ONLY\n',
                   'docs/operations/guide.md':b'SYNTHETIC GUIDE ONLY\n',
                   'godot/addons/native/bin/unit.dll':b'not a runtime, synthetic unit fixture'}
        self.originals={n:git_blob(b) for n,b in self.data.items()}
        self.materialized={'godot/addons/native/bin/unit.dll':{'sha256':hashlib.sha256(self.data['godot/addons/native/bin/unit.dll']).hexdigest(),'size':len(self.data['godot/addons/native/bin/unit.dll'])}}
        for name,data in self.data.items():self.put(name,data)
        self.put('godot/authoring/worldgen/unit.json',self.data['examples/worldgen/unit.json'])
        self.record={'archived_git_blobs':self.originals.copy(),'regenerated_imports_sha256':{},
                     'generator_profiles_sha256':{'unit.json':package.sha(self.root/'examples/worldgen/unit.json')},
                     'files_sha256':package.payload(self.root)}
        self.mock=patch.object(package,'source_members',return_value=(self.originals,self.materialized,{}))
        self.mock.start();self.addCleanup(self.mock.stop)

    def put(self,name,data):
        p=self.root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)

    def verify(self):package.verify_archived_bytes(self.root,self.record,{})

    def test_original_exact_bytes_and_staged_copy_accept(self):self.verify()

    def test_rehashed_payload_cannot_replace_immutable_source(self):
        for name in ('examples/worldgen/unit.json','godot/shaders/unit.gdshader','docs/operations/guide.md'):
            with self.subTest(path=name):
                self.put(name,self.data[name]+b'changed')
                self.record['files_sha256']=package.payload(self.root)
                with self.assertRaisesRegex(RuntimeError,'directly from Git'):self.verify()
                self.put(name,self.data[name]);self.record['files_sha256']=package.payload(self.root)

    def test_rehashed_runtime_cannot_replace_retained_native(self):
        self.put('godot/addons/native/bin/unit.dll',b'changed runtime')
        self.record['files_sha256']=package.payload(self.root)
        with self.assertRaisesRegex(RuntimeError,'source-matched retained'):self.verify()

    def test_inventory_cannot_omit_original_or_invent_blob(self):
        self.record['archived_git_blobs'].pop('docs/operations/guide.md')
        with self.assertRaisesRegex(RuntimeError,'inventory'):self.verify()

    def test_staged_profile_cannot_disagree_with_git_verified_original(self):
        self.put('godot/authoring/worldgen/unit.json',b'changed profile')
        self.record['files_sha256']=package.payload(self.root)
        with self.assertRaisesRegex(RuntimeError,'generator profiles'):self.verify()

    def test_missing_original_refuses(self):
        (self.root/'docs/operations/guide.md').unlink()
        with self.assertRaisesRegex(RuntimeError,'Missing or linked'):self.verify()

    def test_owner_document_comes_from_git_not_uncommitted_local_file(self):
        source={'source_commit':'a'*40,'source_tree':'b'*40}
        with patch.object(package.compatibility.custody,'git',return_value=b'---\ntitle: fixture\n---\n# Committed owner guide\n') as git:
            result=package.owner_text(source)
            self.assertIn('# Committed owner guide',result);self.assertIn('a'*40,result)
            git.assert_called_once_with('show','HEAD:docs/operations/strata-optics-evaluation.md')


if __name__=='__main__':unittest.main()
