#!/usr/bin/env python3
"""CI-OPT-002 structural safety contracts; source-linked test inventory."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PublisherSafetyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.publisher = (ROOT / ".github/workflows/gentek80-water-merged-requalification.yml").read_text()
        cls.docs = (ROOT / ".github/workflows/documentation.yml").read_text()
        cls.shader = (ROOT / ".github/workflows/palette-shader-qualification.yml").read_text()

    def test_full_campaign_requires_explicit_request(self):
        trigger = self.publisher.split("on:\n", 1)[1].split("permissions:\n", 1)[0]
        self.assertIn("branches: [integration/gentek80-water-conflict-reconcile]", trigger)
        self.assertIn("'tools/ci/gentek80_water_publish_request.json'", trigger)
        self.assertNotIn("workflow_dispatch:", trigger)
        for invalid in ("native/**", "godot/**", "Makefile", "tools/architecture/**"):
            self.assertNotIn(invalid, trigger)

    def test_serial_branch_owner_never_cancels_active_publisher(self):
        self.assertIn("group: gentek80-final-${{ github.ref }}", self.publisher)
        self.assertIn("cancel-in-progress: false", self.publisher)
        self.assertNotIn("group: gentek80-${{ github.run_id }}", self.publisher)

    def test_remote_head_lease_between_expensive_phases(self):
        text = self.publisher
        self.assertGreaterEqual(text.count("gentek80_water_runtime_publication.py check-source --source-sha"), 17)
        for phase in ("Existing native generation and hierarchy suites",
                      "Build exact-source native extension",
                      "All 80 real Workbench selections, material edits and separate-process reopen",
                      "Qualify all 80 catalogue styles in native materials and ordinary Windows Workbench",
                      "Package source-matched Windows owner candidate"):
            self.assertIn(phase, text)
            self.assertIn("Refuse superseded", text.split("- name: " + phase)[0][-500:])

    def test_four_file_publisher_and_all_owner_checks_preserved(self):
        for marker in ("needs: [publisher-guards, linux, windows-build, windows]",
                       "git push --force-with-lease=",
                       "runtime-provenance.linux.json", "runtime-provenance.json",
                       "libcybersand_native.linux.x86_64.so",
                       "cybersand_native.windows.x86_64.dll",
                       "All-80 extracted Windows package replay failed"):
            self.assertIn(marker, self.publisher)

    def test_palette_fails_before_matrix_and_docs_before_deep_history(self):
        self.assertLess(self.shader.index("ci_opt_runtime_preflight.py"),
                        self.shader.index("Derive complete registered inventory"))
        self.assertLess(self.docs.index("ci_opt_runtime_preflight.py"), self.docs.index("git lfs pull"))
        self.assertIn("lfs: false", self.docs)
        self.assertIn("check_repository.py --require-materialized", self.docs)

    def test_original_native_and_godot_shards_stay_present(self):
        native = (ROOT / ".github/workflows/native.yml").read_text()
        ext = (ROOT / ".github/workflows/gdextension.yml").read_text()
        for marker in ("native-shards:", "asan-ubsan", "tsan", "worldgen"):
            self.assertIn(marker, native)
        for marker in ("linux-regression:", "windows-regression:",
                       "linux-regression-gate:", "windows-coverage:"):
            self.assertIn(marker, ext)


if __name__ == "__main__":
    unittest.main()
