#!/usr/bin/env python3
"""Adversarial readback tests. All fixtures here are synthetic, never evidence."""
import copy
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("mixed", ROOT / "run_mixed_workbench.py")
mixed = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mixed)
DRIVER = ROOT / "mixed_gentek_workbench.gd"
RUNTIME = "a" * 64


def fixture(phase="author", graphical=True):
    display = "Windows" if os.name == "nt" else "X11"
    if not graphical:
        display = "headless"
    value = {"schema": "gentek80-mixed-workbench-phase-v1", "phase": phase, "complete": True, "completed": True,
             "failures": 0, "checks": 100, "mixtures": 3, "catalogue_choices": 93, "source_commit": mixed.FINAL,
             "native_build_commit": mixed.BUILT, "runtime_sha256": RUNTIME, "driver_sha256": mixed.sha(DRIVER),
             "driver_path": str(DRIVER), "process_id": 101 if phase == "author" else 202,
             "graphical": graphical, "display": display, "godot": "4.7-stable (official)",
             "os": "Windows" if os.name == "nt" else "Linux", "cases": []}
    for identity, (seed, modules) in mixed.MIXTURES.items():
        styles, events = [], []
        for slot, module in enumerate(modules):
            preset = {"module": module, "id": module.replace("_", "-"), "geometry": {"room_size": 64},
                      "materials": {"wall": 5, "floor": 5, "window": 12}}
            styles.append({"enabled": True, "share": 20, "preset": preset})
            events.append({"slot": slot, "catalogue_index": 13 + slot, "module": module,
                           "preset": preset, "signal": "OptionButton.item_selected"})
        row = {"case": "mixed-" + phase, "mixture_id": identity, "modules": modules, "seed": seed,
               "extent": [512, 512], "origin": [0, 0], "zone_scale": 64, "display": display,
               "source_sha256": "1" * 64, "recipe_sha256": "2" * 64, "edits_sha256": "3" * 64,
               "expected_edited_material_sha256": "4" * 64, "installed_material_sha256": "1" * 64,
               "restored_material_sha256": "4" * 64, "native_receipt_hashes": ["e" * 16],
               "construction_receipt": {"generated_source_sha256": "1" * 64},
               "edits": [[101, 99, 2, 58], [111, 99, 2, 0]], "tick_before": 0, "tick_after": 1,
               "selected_project": {"seed": seed, "extent": [512, 512], "origin": [0, 0], "zone_scale": 64,
                                    "automatic_tunnels": True, "automatic_doors": True, "automatic_windows": True,
                                    "styles": styles}, "selection_events": events,
               "initial": {"material_sha256": "1" * 64, "recipe_sha256": "2" * 64},
               "replay": {"material_sha256": "1" * 64, "recipe_sha256": "2" * 64},
               "saved_start": "gentek80-mixed-" + identity}
        value["cases"].append(row)
    for _ in range(6 if phase == "author" else 3):
        value["cases"].append({"case": "ui-preview-latency", "display": display, "extent": [512, 512],
                               "request_to_ready_us": 100, "request_to_first_drawn_frame_us": 120 if graphical else None})
    return value


class BoundaryTests(unittest.TestCase):
    def test_synthetic_valid_phase_pair(self):
        author = mixed.validate_phase(fixture(), "author", DRIVER, RUNTIME, True)
        reopen = mixed.validate_phase(fixture("reopen"), "reopen", DRIVER, RUNTIME, True)
        mixed.compare_phases(author, reopen)

    def test_reject_wrong_source_driver_runtime_schema_and_display(self):
        for key, replacement in (("source_commit", mixed.BUILT), ("native_build_commit", mixed.FINAL),
                                 ("driver_sha256", "0" * 64), ("runtime_sha256", "0" * 64),
                                 ("schema", "gentek80-workbench-phase-v1"), ("graphical", False),
                                 ("display", "headless"), ("mixtures", 2), ("failures", 1), ("completed", False)):
            with self.subTest(key=key):
                value = fixture()
                value[key] = replacement
                with self.assertRaises(ValueError):
                    mixed.validate_phase(value, "author", DRIVER, RUNTIME, True)

    def test_reject_catalogue_recipe_material_or_native_receipt_substitution(self):
        def wrong_module(row):
            row["modules"] = ["legacy"] * 5
        def wrong_parameters(row):
            row["selected_project"]["styles"][0]["preset"] = {"module": row["modules"][0]}
        def wrong_recipe(row):
            row["replay"]["recipe_sha256"] = "e" * 64
        def wrong_material(row):
            row["installed_material_sha256"] = "e" * 64
        def wrong_receipt(row):
            row["construction_receipt"]["generated_source_sha256"] = "e" * 64
        def tunnels_disabled(row):
            row["selected_project"]["automatic_tunnels"] = False
        for mutate in (wrong_module, wrong_parameters, wrong_recipe, wrong_material, wrong_receipt, tunnels_disabled):
            with self.subTest(mutate=mutate.__name__):
                value = fixture()
                mutate(value["cases"][0])
                with self.assertRaises(ValueError):
                    mixed.validate_phase(value, "author", DRIVER, RUNTIME, True)

    def test_reject_duplicate_mixture(self):
        value = fixture()
        value["cases"][1] = copy.deepcopy(value["cases"][0])
        with self.assertRaises(ValueError):
            mixed.validate_phase(value, "author", DRIVER, RUNTIME, True)

    def test_reject_restored_material_change(self):
        value = fixture("reopen")
        value["cases"][0]["restored_material_sha256"] = "f" * 64
        with self.assertRaises(ValueError):
            mixed.validate_phase(value, "reopen", DRIVER, RUNTIME, True)

    def test_reject_cross_process_recipe_or_edit_mismatch(self):
        author = mixed.validate_phase(fixture(), "author", DRIVER, RUNTIME, True)
        reopen = mixed.validate_phase(fixture("reopen"), "reopen", DRIVER, RUNTIME, True)
        for key, replacement in (("recipe_sha256", "f" * 64), ("edits", [[101, 99, 2, 58]]),
                                 ("expected_edited_material_sha256", "f" * 64)):
            changed = copy.deepcopy(reopen)
            changed["a"][key] = replacement
            with self.subTest(key=key), self.assertRaises(ValueError):
                mixed.compare_phases(author, changed)

    def test_headless_cannot_pass_graphical_readback(self):
        with self.assertRaises(ValueError):
            mixed.validate_phase(fixture(graphical=False), "author", DRIVER, RUNTIME, True)
        mixed.validate_phase(fixture(graphical=False), "author", DRIVER, RUNTIME, False)

    def test_candidate_or_package_shadowing_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with self.assertRaises(ValueError):
                mixed.outside(root / "godot" / DRIVER.name, root, "External driver")
            mixed.outside(root.parent / "separate-driver.gd", root, "External driver")

    def test_changed_reviewed_helper_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for filename in mixed.HELPERS:
                (root / filename).write_text("# substituted helper\n")
            with self.assertRaisesRegex(ValueError, "Reviewed R helper changed"):
                mixed.load_harness(root)

    def test_headless_native_previews_never_count_as_framebuffers(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for identity in mixed.MIXTURES:
                (root / ("author-mixed-" + identity + "-native-materials.png")).write_bytes(b"\x89PNG\r\n\x1a\nsynthetic-test-only")
            phases = {"author": {"captures": []}, "reopen": {"captures": []}}
            inventory = mixed.png_evidence(root, phases, False)
            self.assertEqual(inventory["framebuffer_png_sha256"], {})
            self.assertEqual(len(inventory["native_material_preview_png_sha256"]), 3)

    def test_graphical_inventory_separates_24_frames_and_3_material_previews(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            phases = {"author": {"captures": []}, "reopen": {"captures": []}}
            for identity in mixed.MIXTURES:
                for phase, suffixes in (("author", ("form", "preview", "zone-overlay", "replay", "installed-world", "edited-world")),
                                        ("reopen", ("preview", "restored-world"))):
                    for suffix in suffixes:
                        name = phase + "-mixed-" + identity + "-" + suffix + ".png"
                        phases[phase]["captures"].append(name)
                        (root / name).write_bytes(b"\x89PNG\r\n\x1a\nsynthetic-test-only")
                (root / ("author-mixed-" + identity + "-native-materials.png")).write_bytes(b"\x89PNG\r\n\x1a\nsynthetic-test-only")
            inventory = mixed.png_evidence(root, phases, True)
            self.assertEqual(len(inventory["framebuffer_png_sha256"]), 24)
            self.assertEqual(len(inventory["native_material_preview_png_sha256"]), 3)
            self.assertFalse(set(inventory["framebuffer_png_sha256"]) & set(inventory["native_material_preview_png_sha256"]))
            phases["author"]["captures"].append("author-mixed-a-native-materials.png")
            with self.assertRaises(ValueError):
                mixed.png_evidence(root, phases, True)

    def test_png_inventory_rejects_missing_extra_and_invalid_originals(self):
        for mutation in ("missing", "extra", "invalid"):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                for identity in mixed.MIXTURES:
                    (root / ("author-mixed-" + identity + "-native-materials.png")).write_bytes(b"\x89PNG\r\n\x1a\nsynthetic-test-only")
                target = root / "author-mixed-a-native-materials.png"
                if mutation == "missing":
                    target.unlink()
                elif mutation == "extra":
                    (root / "unlabelled.png").write_bytes(b"\x89PNG\r\n\x1a\nsynthetic-test-only")
                else:
                    target.write_bytes(b"not-a-PNG")
                with self.assertRaises(ValueError):
                    mixed.png_evidence(root, {"author": {"captures": []}, "reopen": {"captures": []}}, False)


if __name__ == "__main__":
    unittest.main(verbosity=2)
