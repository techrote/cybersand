"""Source/attempt transport regression for the ObjectShard production profile."""

import json
import os
from pathlib import Path
import re
import unittest
from unittest.mock import patch

import production_runtime as profile


class ObjectShardPublicationTests(unittest.TestCase):
    def test_named_physical_oracles_require_clean_nonempty_original_receipts(self):
        for name, pattern in profile.engine.CASE_MARKERS.items():
            path = profile.engine.ROOT / "godot/tests" / (name + ".gd")
            schema, = re.findall(r'"schema":\s*"([^"]+)"', path.read_text(encoding="utf-8"))
            for checks, failures, success in ((1, [], True), (0, [], False), (1, ["failure"], False)):
                result = json.dumps({"schema": schema, "checks": checks, "failures": failures},
                                    separators=(",", ":"))
                self.assertEqual(bool(re.fullmatch(pattern, result)), success, (name, result))

    def test_ordinary_discovery_admits_only_mounted_workbench_fixtures(self):
        runner = profile.engine.runner
        cases = {c.name: c for c in runner.discover_cases()}
        aimed = {name for name, case in cases.items() if "--objectshard-m4-workbench" in case.flags}
        # Live mouse tests compose the same mounted Main fixture through a
        # narrowly named input adapter; it adds event delivery, not a different
        # World owner. Keep this dependency explicit instead of accepting every
        # script whose name happens to mention ObjectShard.
        input_fixture = profile.engine.ROOT / "godot/tests/support/object_shard_m4_live_input_fixture.gd"
        input_source = input_fixture.read_text(encoding="utf-8")
        self.assertIn('preload("res://tests/support/object_shard_m4_workbench_fixture.gd")', input_source)
        self.assertIn("f = Fixture.new(tree)", input_source)
        mounted = {path.stem for path in (profile.engine.ROOT / "godot/tests").glob("test_object_shard_m4*.gd")
                   if any(helper in path.read_text(encoding="utf-8") for helper in
                          ("object_shard_m4_workbench_fixture.gd", "object_shard_m4_live_input_fixture.gd"))}
        self.assertEqual(aimed, mounted | {"test_object_shard_m4_workbench_scene_refusal",
                                          "test_object_shard_m4_material_only_workbench"})
        for name in aimed:
            self.assertEqual(cases[name].flags[-2:], ("--", "--objectshard-m4-workbench"))
        self.assertNotIn("--objectshard-m4-workbench", cases["test_object_shard_m4_workbench_port"].flags)
        self.assertNotIn("--objectshard-m4-workbench", cases["test_object_shard_m4_disabled_input"].flags)
        overlay = cases["test_object_shard_m4_overlay_identity"]
        self.assertTrue(overlay.requires_display)
        self.assertTrue(profile.engine.runner.architecture_context.windows_applicable(overlay))
        for platform in ("linux", "win32"):
            self.assertNotIn("--headless", profile.engine.runner.case_command("godot", overlay, platform))

    def test_partial_retry_requires_actual_build_and_validation_attempts(self):
        bundle = Path("unused")
        manifest = {"build_attempt": "1", "workflow_attempt": "2"}
        with patch.object(profile, "verify_original", return_value=manifest), patch.dict(
                os.environ, {"GITHUB_RUN_ATTEMPT": "3", "OBJECTSHARD_BUILT_WINDOWS_ATTEMPT": "1",
                             "OBJECTSHARD_VALIDATED_WINDOWS_ATTEMPT": "2"}):
            self.assertIs(profile.verify_bundle(bundle, "windows", "source", False), manifest)
            self.assertIs(profile.verify_bundle(bundle, "windows", "source", True), manifest)
            with self.assertRaisesRegex(RuntimeError, "producer attempt mismatch"):
                profile.verify_bundle(bundle, "linux", "source", True)
            with patch.dict(os.environ, {"OBJECTSHARD_BUILT_WINDOWS_ATTEMPT": "2"}), \
                    self.assertRaisesRegex(RuntimeError, "producer attempt mismatch"):
                profile.verify_bundle(bundle, "windows", "source", False)

    def test_shared_publisher_forbids_main_and_unregistered_requests(self):
        self.assertEqual(profile.engine.BRANCH, "integration/objectshard-m4-mainline-20261122")
        request = json.loads((profile.engine.ROOT / profile.engine.REQUEST).read_bytes())
        self.assertGreater(request.pop("request_sequence"), 0)
        self.assertEqual(request, profile.engine.REQUEST_VALUE)
        self.assertTrue({profile.engine.WORKFLOW, profile.engine.REQUEST,
                         "tools/objectshard/production_runtime.py"}.issubset(profile.engine.BUILD_EXACT))
        self.assertEqual(len(set(profile.engine.RUNTIMES.values()) | set(profile.engine.MANIFESTS.values())), 4)


if __name__ == "__main__":
    unittest.main()
