"""M3 custody/adversarial fixtures; actual Windows execution remains a separate gate."""
import copy
import unittest

import package_windows_lab
import qualify_windows_zip
import test_package_verifier
import verify_package


class M3PackageContracts(unittest.TestCase):
    def fixture(self):
        fixture = test_package_verifier.PackageVerifierTests()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        for name in verify_package.PREFLIGHT_REQUIRED:
            path = fixture.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(("synthetic M3 custody fixture: " + name).encode())
            fixture.manifest["files_sha256"][name] = verify_package.digest(path)
        fixture.manifest["preflight"] = dict(verify_package.PREFLIGHT)
        fixture.write_manifest()
        return fixture

    def test_m3_inventory_is_explicit_and_source_verified(self):
        fixture = self.fixture()
        self.assertEqual(verify_package.verify(fixture.root)["preflight"], verify_package.PREFLIGHT)

    def test_m3_scene_cannot_silently_lose_host_scope(self):
        fixture = self.fixture()
        del fixture.manifest["preflight"]
        fixture.write_manifest()
        with self.assertRaisesRegex(ValueError, "M3 preflight"):
            verify_package.verify(fixture.root)

    def test_m3_launcher_and_guide_cannot_disappear_from_inventory(self):
        for name in (verify_package.PREFLIGHT["launcher"], "docs/operations/objectshard-m3-preflight-playtest.md"):
            fixture = self.fixture()
            del fixture.manifest["files_sha256"][name]
            fixture.write_manifest()
            with self.assertRaisesRegex(ValueError, "M3 preflight"):
                verify_package.verify(fixture.root)

    def test_production_integration_claim_is_rejected(self):
        fixture = self.fixture()
        fixture.manifest["preflight"]["production_workbench"] = True
        fixture.write_manifest()
        with self.assertRaisesRegex(ValueError, "M3 preflight"):
            verify_package.verify(fixture.root)

    def test_development_launcher_preserves_separate_control_scene(self):
        launchers = package_windows_lab.launchers("1" * 40, preflight=True)
        self.assertIn("res://object_shard_lab.tscn", launchers["Open ObjectShard Lab.cmd"])
        rehearsal = launchers[verify_package.PREFLIGHT["launcher"]]
        self.assertIn("res://object_shard_worker_rehearsal.tscn", rehearsal)
        self.assertIn("probe_object_shard_worker_package_boot.gd", rehearsal)
        self.assertIn('set "OBJECTSHARD_PACKAGE_ROOT=%~dp0."', rehearsal)
        self.assertNotIn("res://object_shard_lab.tscn", rehearsal)

    def test_wrong_host_or_source_cannot_pass_actual_launch_receipt(self):
        identity = {"source_commit": "1" * 40}
        receipt = {"schema": "objectshard-worker-package-launch-v1", "source_commit": "1" * 40,
                   "checks": 15, "failures": 0, "host": "standalone-exclusive-worker-rehearsal", "production_workbench": False}
        qualify_windows_zip.validate_launch_receipt(receipt, identity, preflight=True)
        for delta in ({"source_commit": "2" * 40}, {"host": "production-workbench"}, {"production_workbench": True},
                      {"failures": False}, {"checks": 14}, {"schema": "objectshard-package-launch-v1"}):
            altered = copy.deepcopy(receipt)
            altered.update(delta)
            with self.assertRaises(ValueError):
                qualify_windows_zip.validate_launch_receipt(altered, identity, preflight=True)


if __name__ == "__main__":
    unittest.main()
