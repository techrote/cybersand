#!/usr/bin/env python3
"""Adversarial manifest tests. Synthetic PE bytes never qualify a runtime."""
from __future__ import annotations

import copy
import ast
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock

import package_windows as package

spec = importlib.util.spec_from_file_location("frozen_package_tests", package.ROOT / package.LEGACY / "test_package_windows.py")
fixtures = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixtures)


class PowerShellManifestTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('powershell') or shutil.which('pwsh'), 'PowerShell is required')
    def test_flight_pacing_is_selected_local_retest_only(self):
        command = r'''
            $ErrorActionPreference='Stop'
            . ./Start-PUBPRES-Final.ps1 -Library
            $m=[pscustomobject]@{schema='pubpres-local-owner-retest-v1'}
            $r=[pscustomobject]@{source='C';recovery_mode='Selected';settings=[pscustomobject]@{}}
            Remove-Item Env:CYBERSAND_WORKBENCH_FLIGHT_PACING -ErrorAction SilentlyContinue
            Remove-Item Env:CYBERSAND_WORKBENCH_EMPTY_EFFECTS -ErrorAction SilentlyContinue
            Remove-Item Env:CYBERSAND_WORKBENCH_COUPLING_CLOCK -ErrorAction SilentlyContinue
            Assert-PP ((Get-PFOwnerLaunchSettings $m $r).CYBERSAND_WORKBENCH_FLIGHT_PACING -ceq '1') 'Local selected default'
            Assert-PP ((Get-PFOwnerLaunchSettings $m $r).CYBERSAND_WORKBENCH_EMPTY_EFFECTS -ceq '1') 'Local effects default'
            Assert-PP ((Get-PFOwnerLaunchSettings $m $r).CYBERSAND_WORKBENCH_COUPLING_CLOCK -ceq '1') 'Local coupling default'
            $env:CYBERSAND_WORKBENCH_FLIGHT_PACING='0'
            $env:CYBERSAND_WORKBENCH_COUPLING_CLOCK='0'
            Assert-PP ((Get-PFOwnerLaunchSettings $m $r).CYBERSAND_WORKBENCH_FLIGHT_PACING -ceq '0') 'Explicit comparator'
            Assert-PP ((Get-PFOwnerLaunchSettings $m $r).CYBERSAND_WORKBENCH_COUPLING_CLOCK -ceq '0') 'Explicit coupling comparator'
            $r.recovery_mode='Fallback'
            Assert-PP ((Get-PFOwnerLaunchSettings $m $r).Count -eq 0) 'Fallback leaked local selectors'
            $r.recovery_mode='Selected'; $m.schema='pubpres-playability-recovery-windows-v1'
            Assert-PP ((Get-PFOwnerLaunchSettings $m $r).Count -eq 0) 'Formal package leaked local selectors'
        '''
        subprocess.run([shutil.which('powershell') or shutil.which('pwsh'), '-NoProfile','-ExecutionPolicy','Bypass',
                        '-Command',command],cwd=package.ROOT/package.TOOLS,check=True,timeout=30)

    @unittest.skipUnless(os.name == 'nt', 'Requires the shipped Windows CMD interpreter')
    def test_collector_reports_destination_retains_interactive_result_and_propagates_failure(self):
        candidate = 'a' * 40
        with tempfile.TemporaryDirectory(prefix='PUBPRES collector test ') as temporary:
            root = Path(temporary) / 'Package'
            target = root / package.TOOLS / 'Collect-Results.ps1'
            target.parent.mkdir(parents=True)
            (root / 'Collect Results.cmd').write_bytes(package.command(candidate, collector=True))
            # A v7 shell launching cmd can pass incompatible Utility modules to
            # Windows PowerShell. Check the actual 5.1 cmdlet behind the shipped verifier.
            target.write_text("param($PackageRoot,$ExpectedCandidate)\n"
                              "$ErrorActionPreference='Stop'\n"
                              "$null = Get-FileHash -LiteralPath $PSCommandPath\n"
                              "Write-Output ('Result path: '+[IO.Path]::GetFullPath($PackageRoot))\n")
            def invoke(*arguments):
                return subprocess.run(['cmd.exe', '/d', '/c', 'call', 'Collect Results.cmd', *arguments], cwd=root,
                                      env={**os.environ, 'PSModulePath':str(root / 'unrelated modules')},
                                      input=b'\r\n', stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
            for arguments in ((), ('--hosted-smoke',)):
                result = invoke(*arguments)
                self.assertEqual(result.returncode, 0, result.stdout)
                self.assertIn(os.fsencode(str(root.parent / 'Runs' / 'Reports')), result.stdout)
                self.assertIn(b'Result path:', result.stdout)
                self.assertEqual(b'Press any key' in result.stdout, not arguments)
            target.write_text("throw 'Deliberate collector error'\n")
            result = invoke()
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b'Deliberate collector error', result.stdout)
            self.assertIn(b'Collection failed with exit code', result.stdout)
            self.assertIn(b'Press any key', result.stdout)

    @unittest.skipUnless(shutil.which('powershell') or shutil.which('pwsh'), 'PowerShell is required')
    def test_flat_policy_equality_checks_typed_fields_in_any_order(self):
        command = r'''
            $ErrorActionPreference = 'Stop'
            . ./Start-PUBPRES-Final.ps1 -Library
            $policy = [pscustomobject][ordered]@{ architecture='stock_safe'; water=1 }
            Assert-PP (Test-PFFlatRecord ([pscustomobject][ordered]@{ water=1; architecture='stock_safe' }) $policy) 'Reordering changed policy'
            foreach($other in @(@{ architecture='stock_safe'; water='1' }, @{ architecture='stock_safe'; water=0 },
                                  @{ architecture='stock_safe' }, @{ architecture='stock_safe'; water=1; extra=0 })) {
                Assert-PP (-not (Test-PFFlatRecord ([pscustomobject]$other) $policy)) 'Changed policy accepted'
            }
        '''
        subprocess.run([shutil.which('powershell') or shutil.which('pwsh'), '-NoProfile', '-ExecutionPolicy', 'Bypass',
                        '-Command', command], cwd=package.ROOT / package.TOOLS, check=True, timeout=30)


class FinalPackageTests(unittest.TestCase):
    def test_complete_native_dependency_verifier_is_frozen(self):
        def function(path,name):
            return next(node for node in ast.parse(path.read_text()).body if isinstance(node,ast.FunctionDef) and node.name==name)
        old=package.ROOT/'tools/pubpres_final_windows/package_windows.py'
        new=package.ROOT/package.TOOLS/'package_windows.py'
        self.assertEqual(ast.dump(function(old,'verify_sources')),ast.dump(function(new,'verify_sources')))

    def setUp(self):
        # This synthetic PE/native fixture exercises the complete stock-only
        # package verifier. Keep its declared policy independent of the real
        # evaluator's subsequently selected optional engine: a fake atomic
        # payload would defeat the actual build02 custody gate. All real policy
        # configurations are covered separately, and hosted application/package
        # qualification still reads the unpatched committed selection.
        synthetic_selection=copy.deepcopy(package.recovery_policy.selection())
        synthetic_selection.update(architecture='stock_safe',water_composition=0,
            actual_submission=0,render_lookahead=0,experimental_architecture='none',task_completion=0)
        selection_patch=mock.patch.object(package.recovery_policy,'selection',return_value=synthetic_selection)
        selection_patch.start()
        self.addCleanup(selection_patch.stop)
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.record = fixtures.fixture(self.root)
        self.candidate = self.record["candidate_commit"]
        self.record["sources"] = {"C": self.record["sources"]["C"]}
        for key in ("M", "I"):
            shutil.rmtree(self.root / "sources" / key)
        self.record.update(schema=package.SCHEMA, mission=package.MISSION, defaults=copy.deepcopy(package.DEFAULTS),
                           package_filename=f"CyberSand-{package.MISSION}-{self.candidate[:12]}-Windows.zip",
                           patched_engine=None, owner_launcher=package.TOOLS + "/Start-PUBPRES-Final.ps1",
                           owner_observer=package.TOOLS + "/owner_start.gd",
                           owner_results_collector=package.TOOLS + "/Collect-Results.ps1",
                           owner_commands={"Open Workbench.cmd": "ordinary", "Open Wave 512.cmd": "wave512",
                                           "Open Wave 1024.cmd": "wave1024", "Open Wave 2048.cmd": "wave2048",
                                           "Open Mixed 2048.cmd": "mixed2048"})
        for name, scene in self.record["owner_commands"].items():
            fixtures.put(self.root, name, package.command(self.candidate, scene))
        fixtures.put(self.root, "Collect Results.cmd", package.command(self.candidate, collector=True))
        fixtures.put(self.root,package.recovery_policy.FALLBACK_COMMAND,package.command(self.candidate,mode='Fallback'))
        configured=package.recovery_policy.selection()
        self.record['comparison_commands']=package.recovery_policy.scene_comparison_commands(configured)
        for name,value in self.record['comparison_commands'].items():
            fixtures.put(self.root,name,package.command(self.candidate,value['scene'],mode=value['mode']))
        fixtures.put(self.root,package.TOOLS+'/selection.json',json.dumps(configured))
        self.record.update(recovery_selection=configured,recovery_selection_sha256=package.digest(self.root/package.TOOLS/'selection.json'))
        fixtures.put(self.root,'qualification/recovery-correctness.json',json.dumps({
            'schema':'pubpres-recovery-owner-correctness-v1','source_commit':self.candidate,
            'source_tree':self.record['sources']['C']['source_tree'],'selection':configured,
            'engine_sha256':self.record['engine']['gui']['sha256'],
            'native_sha256':self.record['sources']['C']['native']['sha256'],'physical_acceptance':'HOLD',
            'stock':{'outcomes':19,'raw_inputs_and_supplemental_replayed':True},'water':None,
            'members':{'outcomes':4,'raw_inputs_and_supplemental_replayed':True},
            'native_owner':{'checks':150,'raw_inputs_and_native_receipt_replayed':True}}))
        for name in ("Start-PUBPRES-Final.ps1", "owner_start.gd", "Collect-Results.ps1", "ACCEPTANCE.md"):
            fixtures.put(self.root, package.TOOLS + "/" + name, "synthetic source-only " + name + "\n")
        fixtures.put(self.root, "ACCEPTANCE.md", (self.root / package.TOOLS / "ACCEPTANCE.md").read_bytes())
        fixtures.put(self.root, "tools/pubpres_final/registration.json", json.dumps({
            "schema": "pubpres-playability-final-registration-v1", "predecessor": {"source": package.DONOR}}))
        self.pins = mock.patch.dict(package.base.GODOT_EXECUTABLE_SHA256,
            {entry["path"]: entry["sha256"] for entry in (self.record["engine"]["gui"], self.record["engine"]["console"])}, clear=True)
        self.pins.start()
        self.save()

    def tearDown(self):
        self.pins.stop()
        self.temp.cleanup()

    def save(self):
        fixtures.save(self.root, self.record)

    def verify(self):
        return package.verify(self.root, self.candidate)

    def test_source_and_dependency_closure_admitted_with_test_only_pins(self):
        self.assertEqual(set(self.verify()["sources"]), {"C"})

    def test_rehashed_unselected_water_and_fallback_substitution_refused(self):
        changed=copy.deepcopy(self.record['recovery_selection']);changed['water_composition']=1-changed['water_composition']
        fixtures.put(self.root,package.TOOLS+'/selection.json',json.dumps(changed))
        self.record.update(recovery_selection=changed,recovery_selection_sha256=package.digest(self.root/package.TOOLS/'selection.json'))
        self.save()
        with self.assertRaisesRegex(ValueError,'Source-pinned recovery'):self.verify()

    def test_replay_uses_executed_path_and_refuses_a_different_packaged_engine(self):
        original = self.root / "observed.exe"
        packaged = self.root / "duplicate.exe"
        original.write_bytes(b"observed executable")
        packaged.write_bytes(original.read_bytes())
        self.assertEqual(package.qualified_engine(original, packaged), original.resolve())
        packaged.write_bytes(b"substituted executable")
        with self.assertRaisesRegex(ValueError, "executable used for qualification"):
            package.qualified_engine(original, packaged)

    def test_missing_graphical_gate_cannot_be_rehashed_into_qualification(self):
        path=self.root/'qualification/recovery-correctness.json';value=json.loads(path.read_bytes())
        value['stock']['outcomes']=18;fixtures.put(self.root,'qualification/recovery-correctness.json',json.dumps(value));self.save()
        with self.assertRaisesRegex(ValueError,'graphical correctness'):self.verify()

    def test_missing_mounted_native_gate_cannot_be_rehashed_into_qualification(self):
        path=self.root/'qualification/recovery-correctness.json';value=json.loads(path.read_bytes())
        value['native_owner']['checks']=149
        fixtures.put(self.root,'qualification/recovery-correctness.json',json.dumps(value));self.save()
        with self.assertRaisesRegex(ValueError,'graphical correctness'):self.verify()

    def test_fallback_is_explicit_and_cannot_enable_a_treatment(self):
        path=self.root/package.recovery_policy.FALLBACK_COMMAND
        path.write_bytes(path.read_bytes().replace(b'-RecoveryMode Fallback',b'-RecoveryMode Selected'))
        self.save()
        with self.assertRaisesRegex(ValueError,'fallback command'):self.verify()

    def test_fallback_scene_cannot_be_relabelled_or_switched_to_selected(self):
        name='Open Wave 2048 - Stock Safe Fallback.cmd'
        path=self.root/name;path.write_bytes(path.read_bytes().replace(b'-RecoveryMode Fallback',b'-RecoveryMode Selected'))
        self.save()
        with self.assertRaisesRegex(ValueError,'Matched scene comparison command differs'):self.verify()

    def test_self_consistent_changed_defaults_remain_refused(self):
        for key, value in (("engine", "egl"), ("render_thread", "separate"), ("full_image_slots", 3),
                           ("material", "blit"), ("same_frame_continuation", "on")):
            with self.subTest(key=key):
                original = self.record["defaults"][key]
                self.record["defaults"][key] = value
                self.save()
                with self.assertRaisesRegex(ValueError, "identity/default/HOLD"):
                    self.verify()
                self.record["defaults"][key] = original

    def test_source_substitution_fails_even_after_inventory_rehash(self):
        source = self.record["sources"]["C"]
        receipt = self.root / source["native"]["receipt"]
        native = json.loads(receipt.read_text())
        native["source_commit"] = "f" * 40
        package.write_json(receipt, native)
        source["native"]["receipt_sha256"] = package.digest(receipt)
        self.save()
        with self.assertRaisesRegex(ValueError, "native receipt substitution"):
            self.verify()

    def test_extra_compiled_input_not_in_native_closure_is_rejected(self):
        fixtures.put(self.root, "sources/C/native/src/undeclared.cpp", "unregistered native input\n")
        self.save()
        with self.assertRaisesRegex(ValueError, "closure set"):
            self.verify()

    def test_source_binary_and_command_corruption_are_rejected(self):
        for relative in (self.record["sources"]["C"]["native"]["path"], "Open Workbench.cmd"):
            with self.subTest(path=relative):
                path = self.root / relative
                original = path.read_bytes()
                path.write_bytes(original + b"changed")
                with self.assertRaisesRegex(ValueError, "missing, changed or unexpected"):
                    self.verify()
                path.write_bytes(original)

    def test_rehashed_default_launcher_cannot_select_experiment(self):
        path = self.root / "Open Workbench.cmd"
        path.write_bytes(path.read_bytes().replace(b" -Action Open", b" -FullImageSlots 3 -Action Open"))
        self.save()
        with self.assertRaisesRegex(ValueError, "Owner command differs"):
            self.verify()

    def test_new_candidate_cannot_masquerade_as_frozen_donor(self):
        self.record["sources"]["D"] = copy.deepcopy(self.record["sources"]["C"])
        self.save()
        with self.assertRaisesRegex(ValueError, "Frozen donor"):
            self.verify()

    def test_patched_engine_requires_exact_original_artifact(self):
        self.record["patched_engine"] = {"root": "engines/egl", "gui": {"path": package.PATCHED_GUI, "sha256": "0" * 64}, "default": False}
        self.save()
        with self.assertRaisesRegex(ValueError, "unqualified optional engine"):
            self.verify()

    def test_held_artifact_cannot_claim_acceptance(self):
        self.record["physical_acceptance"] = "PASS"
        self.save()
        with self.assertRaisesRegex(ValueError, "HOLD"):
            self.verify()

    def test_default_commands_are_explicit_source_and_never_experimental(self):
        for scene in package.SCENES:
            text = package.command(self.candidate, scene).decode("ascii")
            self.assertIn("-ExpectedCandidate " + self.candidate, text)
            self.assertIn("-Scene " + scene, text)
            self.assertNotIn("-FullImageSlots 3", text)
            self.assertNotIn("-Engine Egl", text)
        with self.assertRaises(ValueError):
            package.command(self.candidate, "unknown")

    def test_commands_target_the_shipped_manifest_entrypoints(self):
        # Resolve the actual CMD -File operand against the package's declared
        # source paths. Comparing only command() with itself missed a stale
        # predecessor directory that was never included in the new archive.
        import re
        for collector, field in ((False, "owner_launcher"), (True, "owner_results_collector")):
            cmd = package.command(self.candidate, collector=collector).decode("ascii")
            operand = re.search(r'-File "%~dp0([^"\r\n]+)"', cmd).group(1).replace("\\", "/")
            self.assertEqual(operand, self.record[field])
            self.assertTrue((self.root / operand).is_file())
            self.assertTrue((package.ROOT / operand).is_file())
            self.assertNotIn("tools/pubpres_final_windows/", operand)


if __name__ == "__main__":
    unittest.main()
