#!/usr/bin/env python3
"""Fail-closed source-contract guards for HS-PKT #470 publisher."""
import unittest

import hs_pkt470_runtime_publication as subject


class PublisherProfileTests(unittest.TestCase):
    def test_branch_lease_source_and_scope(self):
        e = subject.engine
        self.assertEqual(e.BRANCH, "gpt/hard-surface-dirty-tiles-20261106")
        self.assertEqual(e.WORKFLOW, ".github/workflows/hs-pkt470-runtime-publication.yml")
        self.assertEqual(e.REQUEST, "tools/ci/hs_pkt470_publish_request.json")
        self.assertEqual(e.REQUEST_VALUE["intent"], "publish-source-matched-runtimes")
        self.assertEqual(e.REQUEST_VALUE["schema"], "hs-pkt470-runtime-publication-request-v1")
        self.assertIn(e.WORKFLOW, e.BUILD_EXACT)
        self.assertIn(e.REQUEST, e.BUILD_EXACT)
        self.assertIn("native/src/world.cpp", e.windows.native_input_paths(e.ROOT))
        self.assertEqual(set(e.RUNTIMES), {"linux", "windows"})
        self.assertEqual(set(e.MANIFESTS), {"linux", "windows"})

    def test_exactness_lockstep_render_case_gates(self):
        e = subject.engine
        for name in ("test_hard_surface_incremental_packet",
                     "test_coupling_lockstep", "test_coupling_lockstep_semantics",
                     "test_render_patch_handoff_regression",
                     "test_simulation_worker_interest_ownership",
                     "test_workbench_canvas"):
            self.assertIn(name, e.CASE_MARKERS)
            self.assertTrue((e.ROOT / "godot/tests" / (name + ".gd")).is_file())
        self.assertTrue(all("skipped" not in marker for marker in e.CASE_MARKERS.values()))
        self.assertEqual(set(subject.NATIVE_REQUIRED), {"Hard-surface"})
        self.assertEqual(len(subject.NATIVE_REQUIRED["Hard-surface"]), 3)
        self.assertIs(e.verify_case_results, subject.verify_case_results)
        self.assertIsNot(e.verify_case_results, e._shared_verify_case_results)

    def test_publisher_never_retargets_canonical_rapier(self):
        e = subject.engine
        self.assertEqual(e.RAPIER["linux"][1],
                         "566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a")
        self.assertEqual(e.RAPIER["windows"][1],
                         "b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7")
        self.assertTrue(e.EXECUTION_SCOPE.find("Import") >= 0)
        self.assertEqual(e.BUNDLE_PREFIX.startswith("hs-pkt470-runtime-attempt-"), True)


if __name__ == "__main__":
    unittest.main()
