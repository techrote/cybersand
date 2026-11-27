#!/usr/bin/env python3
"""Synthetic package integrity attacks; never runtime or owner acceptance."""
from __future__ import annotations
import copy
import json
from pathlib import Path
import tempfile
import unittest
import zipfile
import seal_owner as owner

SOURCE='a'*40

def fixture(root: Path) -> dict:
    for name in owner.REQUIRED:
        path=root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(b'synthetic integrity fixture\n')
    runtime={'schema':1,'programme':'GENTEK-SWARM-006','draft_hold':True,'source':SOURCE,
             'platform':'windows','artifact':'godot/tools/gentek_reciprocal.exe',
             'sha256':owner.sha(root/'godot/tools/gentek_reciprocal.exe')}
    (root/'godot/tools/swarm004-runtime.json').write_text(json.dumps(runtime),encoding='utf-8')
    (root/'godot/tools/swarm004-runtime.windows.json').write_text(json.dumps(runtime),encoding='utf-8')
    manifest={'schema':1,'programme':'GENTEK-SWARM-006','draft_hold':True,'source_commit':SOURCE,
              'native_sha256':owner.sha(root/'godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll'),
              'reciprocal_cli_sha256':runtime['sha256'],
              'files_sha256':{p.relative_to(root).as_posix():owner.sha(p) for p in root.rglob('*') if p.is_file()}}
    save(root,manifest);return manifest

def save(root: Path,manifest:dict)->None:
    (root/'candidate-manifest.json').write_text(json.dumps(manifest),encoding='utf-8')

class PackageIntegrity(unittest.TestCase):
    def test_source_bound_archive_sidecar_and_launcher(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)/'package';manifest=fixture(root)
            self.assertEqual(manifest,owner.validate_package(root,SOURCE))
            output=Path(temp)/'sealed';seal=owner.seal(root,output,SOURCE)
            archive=output/seal['archive'];self.assertEqual(owner.sha(archive),seal['archive_sha256'])
            self.assertEqual(f"{seal['archive_sha256']}  {archive.name}\n",Path(str(archive)+'.sha256').read_text())
            script=(output/'CyberSand-SWARM006-Windows-Owner-Acceptance.ps1').read_text(encoding='utf-8-sig')
            for value in (SOURCE,seal['archive_sha256'],seal['manifest_sha256'],archive.name):self.assertIn(value,script)
            self.assertNotIn('__SOURCE_COMMIT__',script)
            with zipfile.ZipFile(archive) as package:self.assertEqual(set(manifest['files_sha256'])|{'candidate-manifest.json'},set(package.namelist()))
            with self.assertRaisesRegex(ValueError,'overwrite'):owner.seal(root,output,SOURCE)

    def test_changed_binary_unlisted_stale_and_missing_files_refused(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);manifest=fixture(root)
            binary=root/'godot/tools/gentek_reciprocal.exe';old=binary.read_bytes();binary.write_bytes(old+b'changed')
            with self.assertRaisesRegex(ValueError,'Changed'):owner.validate_package(root,SOURCE)
            binary.write_bytes(old);(root/'stale-output.json').write_text('{}')
            with self.assertRaisesRegex(ValueError,'unlisted'):owner.validate_package(root,SOURCE)
            (root/'stale-output.json').unlink();binary.unlink()
            with self.assertRaisesRegex(ValueError,'Changed'):owner.validate_package(root,SOURCE)

    def test_bad_source_programme_capacity_and_path_fail_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);manifest=fixture(root)
            for key,value in [('source_commit','b'*40),('programme','GENTEK-SWARM-005'),('draft_hold',False)]:
                bad=copy.deepcopy(manifest);bad[key]=value;save(root,bad)
                with self.assertRaises(ValueError):owner.validate_package(root,SOURCE)
            for name in ['../escape','/escape','C:/escape','godot/../escape','godot\\escape','godot//escape']:
                bad=copy.deepcopy(manifest);bad['files_sha256'][name]='a'*64;save(root,bad)
                with self.assertRaises(ValueError):owner.validate_package(root,SOURCE)
            bad=copy.deepcopy(manifest);del bad['files_sha256']['Open Workbench.cmd'];save(root,bad)
            with self.assertRaisesRegex(ValueError,'Incomplete'):owner.validate_package(root,SOURCE)
            bad=copy.deepcopy(manifest);bad['files_sha256']['GODOT/PROJECT.GODOT']=bad['files_sha256']['godot/project.godot'];save(root,bad)
            with self.assertRaises(ValueError):owner.validate_package(root,SOURCE)

    def test_runtime_cannot_borrow_another_binary_or_source(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);manifest=fixture(root)
            for key,value in [('source','b'*40),('sha256','0'*64),('programme','GENTEK-SWARM-004')]:
                runtime={'source':SOURCE,'sha256':manifest['reciprocal_cli_sha256'],'programme':'GENTEK-SWARM-006'}
                runtime[key]=value;(root/'godot/tools/swarm004-runtime.json').write_text(json.dumps(runtime))
                manifest['files_sha256']['godot/tools/swarm004-runtime.json']=owner.sha(root/'godot/tools/swarm004-runtime.json');save(root,manifest)
                with self.assertRaisesRegex(ValueError,'Runtime'):owner.validate_package(root,SOURCE)

    def test_preferred_platform_binding_cannot_be_stale_or_foreign(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);original=fixture(root)
            preferred=root/'godot/tools/swarm004-runtime.windows.json'
            binding=json.loads(preferred.read_text())
            for field,value in [('source','b'*40),('platform','linux'),('sha256','0'*64)]:
                manifest=copy.deepcopy(original)
                preferred.write_text(json.dumps({**binding,field:value}))
                manifest['files_sha256']['godot/tools/swarm004-runtime.windows.json']=owner.sha(preferred)
                save(root,manifest)
                with self.assertRaisesRegex(ValueError,'Runtime'):owner.validate_package(root,SOURCE)

if __name__=='__main__':unittest.main(verbosity=2)
