#!/usr/bin/env python3
"""Gallery custody regressions using labelled synthetic one-pixel fixtures.

These fixtures exercise the offline document builder only. They are not Godot
execution, framebuffer evidence or an admitted evaluation campaign.
"""
from __future__ import annotations

import base64
import copy
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("strata2_gallery", ROOT / "tools/build_strata2_gallery.py")
gallery = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(gallery)
PIXEL = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")
SOURCE = "a" * 40
HASH = "b" * 64


class GalleryCustody(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix="strata2-gallery-contract-")
        self.root = Path(self.scratch.name)
        self.package = self.root / "package"
        self.campaign = self.package / "qualification/windows"
        self.campaign.mkdir(parents=True)
        self.output = self.package / "Gallery.html"
        self.original_root = gallery.ROOT
        gallery.ROOT = self.root
        script = self.root / gallery.GENERATOR
        script.parent.mkdir(parents=True)
        script.write_bytes((ROOT / gallery.GENERATOR).read_bytes())
        self.report = {"schema": "strata2-workbench-qualification-v1", "status": "passed", "completed": True,
                       "input_custody": "passed", "local_delta": [], "platform": "win32", "source_commit": SOURCE,
                       "source_tree": "c" * 40, "selected_scenes": list(gallery.SCENES), "source_inputs_sha256": {},
                       "evidence_sha256": {}, "scenes": [], "godot": {"version": "4.7.synthetic-test-only", "sha256": HASH},
                       "runtime": {"cybersand_runtime": {"path": "fixture-native.dll", "sha256": HASH},
                                   "rapier_runtime": {"path": "fixture-rapier.dll", "sha256": HASH}}}
        self.report["source_inputs_sha256"][gallery.GENERATOR] = gallery.sha(script.read_bytes())
        for index, identity in enumerate(gallery.SCENES):
            source_name = "godot/data/strata2/" + identity + ".json"
            metadata = {"id": identity, "title": "Synthetic <native> fixture " + identity,
                        "description": "Unit fixture only; no execution or appearance claim.", "extent": [512, 512],
                        "provenance": {"plane_roles": {plane: plane + " role" for plane in gallery.PLANES}}}
            path = self.root / source_name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(metadata))
            self.report["source_inputs_sha256"][source_name] = gallery.sha(path.read_bytes())
            entry = {"name": identity, "status": "passed", "phases": {}}
            native = {plane: HASH for plane in gallery.PLANES}
            for phase in ("install", "reopen"):
                result = {"schema": "strata2-workbench-execution-v1", "completed": True, "failures": [],
                          "scene": identity, "phase": phase, "source_revision": SOURCE, "display_server": "Windows",
                          "rendering_method": "gl_compatibility", "ordinary_workbench": True, "diagnostic_headless": False,
                          "document_version": 2, "process_id": 100 + 2 * index + (phase == "reopen"), "extent": [512, 512],
                          "plane_native_hashes": native, "showcase_native_hashes": native,
                          "authored_settings_sha256": HASH, "fresh_process_reopen": phase == "reopen",
                          "gallery": {"isolated_planes": "native material surfaces; atmosphere disabled"},
                          "atmosphere": {"native_hashes_before": native, "native_hashes_after": native,
                                         "solo_leakage": {"changed_samples": 0}},
                          "detail_views": [{"id": "synthetic-detail", "camera_origin": [0, 0], "view_size": [1, 1]}],
                          "native_grid_details": [{"plane": "play", "pixels_per_cell_x": 1.0, "pixels_per_cell_y": 1.0,
                                                   "framebuffer_crop": [0, 0, 1, 1]}]}
                data = (json.dumps(result, sort_keys=True) + "\n").encode()
                name = identity + "/" + phase + ".json"
                self.write_evidence(name, data)
                entry["phases"][phase] = {"report_sha256": gallery.sha(data), "result": result}
            self.report["scenes"].append(entry)
            for filename in ("reference-composite.png", *("reference-plane-" + plane + ".png" for plane in gallery.PLANES),
                             "atmosphere-off.png", "atmosphere-on.png", "detail-synthetic-detail.png", "native-grid-play.png"):
                self.write_evidence(identity + "/" + filename, PIXEL)
        self.save_report()

    def tearDown(self):
        gallery.ROOT = self.original_root
        self.scratch.cleanup()

    def write_evidence(self, name, data):
        path = self.campaign / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        self.report["evidence_sha256"][name] = gallery.sha(data)

    def save_report(self):
        (self.campaign / "qualification.json").write_text(json.dumps(self.report, sort_keys=True))

    def prepare(self):
        return gallery.prepare(self.campaign, self.output, SOURCE)

    def test_deterministic_build_and_receipt(self):
        data = self.prepare()
        self.assertEqual(data, self.prepare())
        result = gallery.build(self.campaign, self.output, SOURCE)
        self.assertEqual(json.loads(self.output.with_suffix(".inputs.json").read_text()), data)
        self.assertEqual(self.output.read_text(), gallery.render(data))
        self.assertEqual(gallery.sha(self.output.read_bytes()), result["html_sha256"])
        self.assertEqual(result["displayed_capture_count"], 45)

    def test_html_escapes_qualified_metadata(self):
        data = self.prepare()
        data["scenes"][0]["title"] = '</script><img src="outside.png" onerror="alert(1)">'
        output = gallery.render(data)
        self.assertNotIn('</script><img src="outside.png"', output)
        self.assertIn("\\u003c/script>", output)
        self.assertIn("&lt;/script&gt;", output)
        self.assertNotIn("fetch(", output)

    def test_failed_campaign_never_becomes_gallery(self):
        self.report["status"] = "failed"
        self.save_report()
        with self.assertRaisesRegex(ValueError, "passing clean-source"):
            self.prepare()
        self.assertFalse(self.output.exists())

    def test_linux_campaign_is_not_windows_delivery(self):
        self.report["platform"] = "linux"
        self.save_report()
        with self.assertRaisesRegex(ValueError, "Windows source"):
            self.prepare()

    def test_exact_source_is_required(self):
        with self.assertRaisesRegex(ValueError, "Windows source"):
            gallery.prepare(self.campaign, self.output, "d" * 40)

    def test_local_delta_refuses(self):
        self.report["local_delta"] = ["godot/scripts/changed.gd"]
        self.save_report()
        with self.assertRaisesRegex(ValueError, "clean-source"):
            self.prepare()

    def test_changed_image_bytes_refuse(self):
        path = self.campaign / gallery.SCENES[0] / "reference-composite.png"
        path.write_bytes(path.read_bytes() + b"changed")
        with self.assertRaisesRegex(ValueError, "evidence bytes changed"):
            self.prepare()

    def test_missing_recorded_image_refuses(self):
        del self.report["evidence_sha256"][gallery.SCENES[0] + "/reference-plane-effects.png"]
        self.save_report()
        with self.assertRaisesRegex(ValueError, "not recorded"):
            self.prepare()

    def test_changed_scene_report_refuses(self):
        path = self.campaign / gallery.SCENES[0] / "install.json"
        path.write_text(path.read_text() + " ")
        with self.assertRaisesRegex(ValueError, "evidence bytes changed"):
            self.prepare()

    def test_changed_recipe_title_refuses(self):
        path = self.root / "godot/data/strata2" / (gallery.SCENES[0] + ".json")
        path.write_text(path.read_text().replace("Synthetic", "Unqualified"))
        with self.assertRaisesRegex(ValueError, "differs from qualified source"):
            self.prepare()

    def test_output_cannot_reference_images_outside_package(self):
        elsewhere = self.root / "elsewhere"
        elsewhere.mkdir()
        with self.assertRaisesRegex(ValueError, "inside the package"):
            gallery.prepare(self.campaign, elsewhere / "Gallery.html", SOURCE)

    def test_false_one_to_one_detail_refuses(self):
        entry = self.report["scenes"][0]["phases"]["install"]
        result = copy.deepcopy(entry["result"])
        result["native_grid_details"][0]["pixels_per_cell_x"] = 1.25
        data = (json.dumps(result, sort_keys=True) + "\n").encode()
        self.write_evidence(gallery.SCENES[0] + "/install.json", data)
        entry.update(report_sha256=gallery.sha(data), result=result)
        self.save_report()
        with self.assertRaisesRegex(ValueError, "one captured framebuffer pixel"):
            self.prepare()

    def test_malformed_or_oversized_png_refuses(self):
        with self.assertRaisesRegex(ValueError, "PNG"):
            gallery.png_extent(b"not an image")
        oversized = bytearray(PIXEL)
        oversized[16:20] = (9000).to_bytes(4, "big")
        with self.assertRaisesRegex(ValueError, "budget"):
            gallery.png_extent(bytes(oversized))


if __name__ == "__main__":
    unittest.main()
