#!/usr/bin/env python3
"""Executable qualification for the unattended world-art capture mode (#498).

Unit tests need only Python. GraphicalCaptureTests drive the real CLI against a real
Godot 4.7 desktop renderer and FAIL (never silently skip) when WORLD_ART_REQUIRE_GRAPHICAL=1.

Environment
  WORLD_ART_GODOT              Godot 4.7 executable                    (graphical tests)
  WORLD_ART_ART_ROOT           checkout dir holding <collection>/pack.json for all 15 collections
  WORLD_ART_RENDER_DRIVER      opengl3 (Linux X11/llvmpipe) | opengl3_angle (Windows)
  WORLD_ART_EXPECT_ADAPTER     optional substring the GPU adapter name must contain (e.g. llvmpipe)
  WORLD_ART_EVIDENCE_DIR       where PNGs/manifests/logs are retained (default: a temp dir)
  WORLD_ART_REQUIRE_GRAPHICAL  1 = missing graphical prerequisites are failures, not skips
Run:  python tools/test_world_art_capture.py -v
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import world_art_capture_support as support  # noqa: E402
import world_art_preview_launcher as launcher  # noqa: E402

LAUNCHER = HERE / "world_art_preview_launcher.py"
GODOT = os.environ.get("WORLD_ART_GODOT", "")
ART_ROOT = os.environ.get("WORLD_ART_ART_ROOT", "")
DRIVER = os.environ.get("WORLD_ART_RENDER_DRIVER", "")
EXPECT_ADAPTER = os.environ.get("WORLD_ART_EXPECT_ADAPTER", "")
REQUIRE = os.environ.get("WORLD_ART_REQUIRE_GRAPHICAL", "") == "1"
EVIDENCE = Path(os.environ.get("WORLD_ART_EVIDENCE_DIR") or tempfile.mkdtemp(prefix="world-art-evidence-")).resolve()
SOURCE_REPORT: list[dict] = []


def make_png(width: int, height: int, pixel) -> bytes:
    rows = b"".join(b"\x00" + b"".join(bytes(pixel(x, y)) for x in range(width)) for y in range(height))

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    return (support.PNG_SIGNATURE + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))


class UnitTests(unittest.TestCase):
    """No Godot required."""

    def test_collection_order_matches_the_godot_viewer(self):
        source = (ROOT / "godot/tools/world_art_preview.gd").read_text(encoding="utf-8")
        block = source.split("const COLLECTION_ORDER = [", 1)[1].split("]", 1)[0]
        names = tuple(part.strip().strip('"') for part in block.replace("\n", " ").split(",") if part.strip())
        self.assertEqual(names, support.COLLECTION_ORDER)

    def test_launcher_ships_every_godot_file_the_capture_runner_needs(self):
        for name in ("tools/world_art_capture.gd", "tools/world_art_full_export.gd", "tools/world_art_render_rig.gd",
                     "shaders/material_palette.gdshader", "shaders/material_emission.gdshader",
                     "shaders/glow_composite.gdshader"):
            self.assertIn(name, launcher.FILES)
            self.assertTrue((ROOT / "godot" / name).is_file(), name)

    def test_png_validator_accepts_real_png_and_rejects_damage(self):
        good = make_png(32, 16, lambda x, y: (x * 7 % 256, y * 15 % 256, (x + y) * 3 % 256))
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "a.png"
            path.write_bytes(good)
            info = support.inspect_png(path)
            self.assertEqual((info["width"], info["height"]), (32, 16))
            self.assertGreater(info["raw_byte_diversity"], 8)
            path.write_bytes(b"not a png")
            with self.assertRaises(ValueError):
                support.inspect_png(path)
            damaged = bytearray(good)
            damaged[40] ^= 0xFF
            path.write_bytes(bytes(damaged))
            with self.assertRaises((ValueError, zlib.error)):
                support.inspect_png(path)
            path.write_bytes(good[:-20])
            with self.assertRaises((ValueError, zlib.error)):
                support.inspect_png(path)

    def test_png_validator_flags_a_uniform_image(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "blank.png"
            path.write_bytes(make_png(64, 64, lambda x, y: (8, 11, 18)))
            self.assertLessEqual(support.inspect_png(path)["raw_byte_diversity"], 4)

    def test_manifest_seal_detects_edits(self):
        manifest = support.seal_manifest({"a": 1, "nested": {"b": [1, 2]}})
        self.assertTrue(support.manifest_is_sealed(manifest))
        manifest["nested"]["b"].append(3)
        self.assertFalse(support.manifest_is_sealed(manifest))

    def test_log_scanner_finds_shader_and_script_errors_only(self):
        noisy = "Godot Engine v4.7\nSHADER ERROR: line 3: bad\nSCRIPT ERROR: Parse Error: x\nOpenGL API ok\n"
        self.assertEqual(len(support.scan_log(noisy)), 2)
        self.assertEqual(support.scan_log("Godot Engine v4.7\nOpenGL API OpenGL ES 3.0\nWORLD_ART_CAPTURE {}\n"), [])
        self.assertTrue(support.scan_log("WORLD_ART_CAPTURE_ERROR job failed"))

    def test_argument_parsers_fail_closed(self):
        for bad in ("0x10", "100", "axb", "99999x10", "10000x10000"):
            with self.assertRaises(support.CaptureError, msg=bad):
                support.parse_resolution(bad)
        self.assertEqual(support.parse_resolution("1920x1080"), [1920, 1080])
        with self.assertRaises(support.CaptureError):
            support.parse_rect("1,2,3", "--crop", True)
        with self.assertRaises(support.CaptureError):
            support.parse_rect("1,2,0,5", "--crop", True)
        with self.assertRaises(support.CaptureError):
            support.check_zoom(0.001, "--zoom")

    def _args(self, *extra):
        return launcher.build_parser().parse_args(["--capture", *extra])

    def test_shot_plan_defaults_and_feature_only_mode(self):
        kinds = [s["kind"] for s in support.build_shots(self._args())]
        self.assertEqual(kinds, ["full", "viewport", "detail"])
        kinds = [s["kind"] for s in support.build_shots(self._args("--feature", "a:b", "--all-features"))]
        self.assertEqual(kinds, ["feature", "features"])
        explicit = support.build_shots(self._args("--shots", "viewport", "--zoom", "4", "--center", "10,20"))
        self.assertEqual(explicit[0]["framing"], {"mode": "zoom", "zoom": 4.0, "center": [10.0, 20.0]})
        with self.assertRaises(support.CaptureError):
            support.build_shots(self._args("--view", "0,0,10,10", "--zoom", "2"))
        with self.assertRaises(support.CaptureError):
            support.build_shots(self._args("--shots", "none"))
        with self.assertRaises(support.CaptureError):
            support.build_shots(self._args("--shots", "full,full"))

    def test_source_guard_reports_added_modified_and_removed_files(self):
        before = {"d": {"pack.json": "1", "gone.txt": "2"}}
        after = {"d": {"pack.json": "9", "new.png": "3"}}
        self.assertEqual(sorted(support.diff_snapshots(before, after)),
                         ["added: d/new.png", "modified: d/pack.json", "removed: d/gone.txt"])
        self.assertEqual(support.diff_snapshots(before, before), [])

    def test_usage_errors_are_nonzero_with_diagnostics(self):
        def run(*extra):
            return subprocess.run([sys.executable, str(LAUNCHER), "--capture", "--godot", sys.executable, *extra],
                                  capture_output=True, text=True, encoding="utf-8", errors="replace")

        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            art = tmp / "art" / "demo"
            art.mkdir(parents=True)
            (art / "pack.json").write_text("{}", encoding="utf-8")
            out = tmp / "out"
            cases = {
                "missing pack": (["--pack", str(tmp / "nope.json"), "--output-dir", str(out)], "pack not found"),
                "no output dir": (["--pack", str(art / "pack.json")], "--output-dir is required"),
                "output inside art": (["--pack", str(art / "pack.json"), "--output-dir", str(art / "captures")], "overlaps the read-only art source"),
                "bad resolution": (["--pack", str(art / "pack.json"), "--output-dir", str(out), "--resolution", "0x0"], "--resolution"),
                "no inputs": (["--output-dir", str(out)], "needs --pack and/or --art-root"),
                "collection without root": (["--pack", str(art / "pack.json"), "--collection", "x", "--output-dir", str(out)], "requires --art-root"),
            }
            for label, (extra, message) in cases.items():
                done = run(*extra)
                self.assertEqual(done.returncode, support.EXIT_USAGE, label + done.stderr)
                self.assertIn(message, done.stderr, label)
            (tmp / "busy").mkdir()
            (tmp / "busy" / "earlier.txt").write_text("evidence", encoding="utf-8")
            done = run("--pack", str(art / "pack.json"), "--output-dir", str(tmp / "busy"))
            self.assertEqual(done.returncode, support.EXIT_USAGE)
            self.assertIn("not empty", done.stderr)
            self.assertTrue((tmp / "busy" / "earlier.txt").is_file(), "earlier evidence must never be touched")
            self.assertFalse(out.exists(), "usage errors must not create the output directory")

    def test_missing_engine_is_reported(self):
        done = subprocess.run([sys.executable, str(LAUNCHER), "--capture", "--godot", "definitely-not-godot-4.7",
                               "--pack", str(LAUNCHER), "--output-dir", str(EVIDENCE / "never")],
                              capture_output=True, text=True)
        self.assertEqual(done.returncode, support.EXIT_ENGINE)
        self.assertIn("Godot executable not found", done.stderr)

    def test_verify_bundle_rejects_a_directory_without_a_manifest(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(support.CaptureError) as caught:
                support.verify_bundle(Path(tmp))
            self.assertEqual(caught.exception.code, support.EXIT_EVIDENCE)


def pack_inventory(path: Path) -> dict:
    document = json.loads(path.read_text(encoding="utf-8"))
    scene = document.get("scene") or document["combined_scene"]
    return {"document": document, "scene": scene, "size": scene["size"]}


def edge_cells_authored(path: Path, strip: int) -> bool:
    """True when the pack's own geometry paints a non-Empty cell in the last `strip` columns."""
    inventory = pack_inventory(path)
    width, height = inventory["size"]
    scene, document = inventory["scene"], inventory["document"]
    first = width - strip
    grid = [[0] * height for _ in range(strip)]

    def paint(rect, dx, dy, swap):
        x, y, w, h, material = rect
        material = int(swap.get(str(material), material))
        for column in range(max(x + dx, first), min(x + dx + w, width)):
            for row in range(max(y + dy, 0), min(y + dy + h, height)):
                grid[column - first][row] = material

    for rect in scene.get("rectangles", scene.get("terrain_rectangles", [])):
        paint(rect, 0, 0, {})
    features = {f["id"]: f for f in document["features"]}
    for placement in scene["placements"]:
        feature = features[placement.get("feature", placement.get("feature_id"))]
        ox, oy = (placement["x"], placement["y"]) if "x" in placement else placement["origin"]
        variant = placement.get("variant")
        swap = {}
        for candidate in feature.get("variants", []):
            if candidate["id"] == variant:
                swap = candidate.get("swap", {})
        for rect in feature["rectangles"]:
            paint(rect, ox, oy, swap)
    return any(cell for column in grid for cell in column)


class GraphicalCaptureTests(unittest.TestCase):
    """Real Godot 4.7 rendering through the public CLI contract."""

    @classmethod
    def setUpClass(cls):
        missing = [name for name, value in (("WORLD_ART_GODOT", GODOT), ("WORLD_ART_ART_ROOT", ART_ROOT),
                                            ("WORLD_ART_RENDER_DRIVER", DRIVER)) if not value]
        if not missing and not Path(GODOT).is_file():
            missing.append("WORLD_ART_GODOT file")
        if not missing and not Path(ART_ROOT).is_dir():
            missing.append("WORLD_ART_ART_ROOT directory")
        if missing:
            message = "graphical prerequisites missing: " + ", ".join(missing)
            if REQUIRE:
                raise AssertionError(message + " (WORLD_ART_REQUIRE_GRAPHICAL=1: this is a failure, not a skip)")
            raise unittest.SkipTest(message)
        cls.art = Path(ART_ROOT).resolve()
        cls.git_head = support.git_identity(cls.art)
        cls.art_status_before = subprocess.run(
            ["git", "-C", str(cls.art), "status", "--porcelain", "--untracked-files=all"],
            capture_output=True, text=True).stdout
        cls.pack_hashes = {p.parent.name: support.sha256_file(p) for p in cls.art.glob("*/pack.json")}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        cls.scratch = Path(tempfile.mkdtemp(prefix="world-art-qual-"))

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(getattr(cls, "scratch", ""), ignore_errors=True)

    # ------------------------------------------------------------------ helpers
    def capture(self, name, *extra, expect=0, art_root=True, driver=True, env=None, launcher_path=None):
        out = EVIDENCE / name
        shutil.rmtree(out, ignore_errors=True)
        command = [sys.executable, str(launcher_path or LAUNCHER), "--capture", "--godot", GODOT]
        if driver:
            command += ["--rendering-driver", DRIVER]
        if art_root:
            command += ["--art-root", str(self.art)]
        command += [*extra, "--output-dir", str(out)]
        done = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=1700, env=env)
        (EVIDENCE / f"{name}.stdout.log").write_text(done.stdout, encoding="utf-8")
        (EVIDENCE / f"{name}.stderr.log").write_text(done.stderr, encoding="utf-8")
        allowed = expect if isinstance(expect, tuple) else (expect,)
        self.assertIn(done.returncode, allowed, f"{name}: exit {done.returncode}\n{done.stderr[-2000:]}")
        result = None
        for line in done.stdout.splitlines():
            if line.startswith("WORLD_ART_CAPTURE_RESULT "):
                result = json.loads(line.split(" ", 1)[1])
        if done.returncode not in (support.EXIT_USAGE, support.EXIT_ENGINE):
            self.assertIsNotNone(result, f"{name}: no WORLD_ART_CAPTURE_RESULT line")
            self.assertEqual(result["exit_code"], done.returncode)
        return out, result, done

    def manifests(self, out):
        batch = json.loads((out / "batch-manifest.json").read_text(encoding="utf-8"))
        jobs = {}
        for entry in batch["jobs"]:
            jobs[entry["collection"]] = json.loads((out / entry["manifest"]).read_text(encoding="utf-8"))
        return batch, jobs

    def assert_good_bundle(self, out, expected_jobs):
        batch, problems = support.verify_bundle(out)
        self.assertEqual(problems, [])
        self.assertEqual(batch["status"], "completed")
        self.assertEqual(len(batch["jobs"]), expected_jobs)
        self.assertEqual(batch["art_source"]["revision"], self.git_head["revision"],
                         "manifest must record the CURRENT art checkout revision")
        self.assertTrue(batch["source_guard"]["unchanged"])
        display = batch["engine"]["display"]
        self.assertTrue(display["godot"].startswith("4.7"))
        self.assertEqual(display["rendering_method"], "gl_compatibility")
        self.assertEqual(display["rendering_driver"], DRIVER)
        self.assertNotEqual(display["display_server"], "headless")
        if EXPECT_ADAPTER:
            self.assertIn(EXPECT_ADAPTER.lower(), display["graphics_adapter"].lower())
        return batch

    # -------------------------------------------------------------------- tests
    def test_01_flagship_renders_unattended_with_source_matched_evidence(self):
        out, result, _ = self.capture("flagship-lumen-fault", "--collection", "lumen-fault")
        batch = self.assert_good_bundle(out, 1)
        manifest = json.loads((out / "01-lumen-fault" / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["input_pack"]["sha256"], self.pack_hashes["lumen-fault"])
        self.assertEqual(manifest["art_source"]["revision"], self.git_head["revision"])
        shots = {s["id"]: s for s in manifest["shots"]}
        self.assertEqual(set(shots), {"full", "viewport", "detail"})
        native = manifest["native"]
        self.assertEqual((shots["full"]["width"], shots["full"]["height"]), (native["width"] * 2, native["height"] * 2))
        for shot in shots.values():
            png = support.inspect_png(out / "01-lumen-fault" / shot["file"])
            self.assertEqual((png["width"], png["height"]), (shot["width"], shot["height"]))
            self.assertGreaterEqual(shot["stats"]["distinct_colours"], 200, shot["id"])
            self.assertGreater(shot["stats"]["non_background_fraction"], 0.2, shot["id"])
            self.assertGreater(png["raw_byte_diversity"], 16)
        renderer = manifest["renderer"]
        self.assertTrue(renderer["palette"]["source_bound"] and renderer["palette"]["source_file_bound"])
        for key in ("shaders/material_palette.gdshader", "shaders/material_emission.gdshader",
                    "shaders/glow_composite.gdshader"):
            self.assertEqual(renderer["shader_file_sha256"][key], manifest["viewer"]["files"][key])
        self.assertEqual(len(renderer["palette_lut"]["atlas_sha256"]), 64)
        self.assertIn("SYNTHETIC", manifest["synthetic_condition_notice"])
        self.assertIn("SYNTHETIC", batch["synthetic_condition_notice"])
        self.assertTrue(result["jobs"][0]["images"])

    def test_02_batch_renders_all_fifteen_collections_and_leaves_art_unchanged(self):
        out, result, _ = self.capture("batch-all-15", "--scale", "1")
        batch = self.assert_good_bundle(out, 15)
        self.assertEqual([j["collection"] for j in batch["jobs"]], list(support.COLLECTION_ORDER))
        full_hashes = set()
        for entry in batch["jobs"]:
            manifest = json.loads((out / entry["manifest"]).read_text(encoding="utf-8"))
            self.assertEqual(manifest["input_pack"]["sha256"], self.pack_hashes[entry["collection"]])
            self.assertEqual(manifest["viewer"], batch["viewer"])
            self.assertEqual({s["id"] for s in manifest["shots"]}, {"full", "viewport", "detail"})
            for shot in manifest["shots"]:
                self.assertTrue(shot["stats"]["nonblank"], f"{entry['collection']}/{shot['id']}")
            full = next(s for s in manifest["shots"] if s["id"] == "full")
            self.assertEqual((full["width"], full["height"]), (manifest["native"]["width"], manifest["native"]["height"]))
            full_hashes.add(full["png_sha256"])
        self.assertEqual(len(full_hashes), 15, "every collection must produce a distinct image")
        status_after = subprocess.run(["git", "-C", str(self.art), "status", "--porcelain", "--untracked-files=all"],
                                      capture_output=True, text=True).stdout
        self.assertEqual(status_after, self.art_status_before, "art checkout git status changed")
        self.assertEqual({p.parent.name: support.sha256_file(p) for p in self.art.glob("*/pack.json")}, self.pack_hashes)
        self.assertFalse(support.is_inside(EVIDENCE, self.art), "evidence must live outside the art checkout")
        self.assertEqual(len(result["jobs"]), 15)

    def test_03_feature_and_variant_selection_from_the_inventory(self):
        packs = sorted(self.art.glob("*/pack.json"))
        expected_features = sum(len(json.loads(p.read_text(encoding="utf-8"))["features"]) for p in packs)
        out, _, _ = self.capture("features-all-120", "--shots", "none", "--all-features", "--feature-scale", "1")
        batch = self.assert_good_bundle(out, 15)
        total = 0
        for entry in batch["jobs"]:
            manifest = json.loads((out / entry["manifest"]).read_text(encoding="utf-8"))
            document = json.loads(Path(manifest["input_pack"]["path"]).read_text(encoding="utf-8"))
            ids = [f["id"] for f in document["features"]]
            self.assertEqual([s["selection"]["feature"] for s in manifest["shots"]], ids)
            total += len(manifest["shots"])
        self.assertEqual(total, expected_features)
        self.assertEqual(total, 120, "the 15-collection atlas inventory is 120 reusable features")
        # Every authored variant of one collection, plus an explicit FEATURE:VARIANT selection.
        collection = "dust-meridian"
        document = json.loads((self.art / collection / "pack.json").read_text(encoding="utf-8"))
        variant_count = sum(len(f.get("variants", [])) for f in document["features"])
        self.assertGreater(variant_count, 0)
        out, _, _ = self.capture("features-all-variants-dust-meridian", "--collection", collection, "--shots", "none",
                                 "--all-variants", "--feature-scale", "2")
        self.assert_good_bundle(out, 1)
        manifest = json.loads((out / f"01-{collection}" / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(len(manifest["shots"]), len(document["features"]) + variant_count)
        by_feature: dict = {}
        for shot in manifest["shots"]:
            by_feature.setdefault(shot["selection"]["feature"], {})[shot["selection"]["variant"]] = shot
        differing = 0
        for feature in document["features"]:
            base = by_feature[feature["id"]][""]
            for variant in feature.get("variants", []):
                chosen = by_feature[feature["id"]][variant["id"]]
                self.assertEqual(chosen["selection"]["variant"], variant["id"])
                differing += chosen["source"]["rg8_sha256"] != base["source"]["rg8_sha256"]
        self.assertGreater(differing, 0, "at least one authored variant must change the rendered cells")
        feature = next(f for f in document["features"] if f.get("variants"))
        spec = f"{feature['id']}:{feature['variants'][0]['id']}"
        out, _, _ = self.capture("feature-explicit-selection", "--collection", collection, "--shots", "none",
                                 "--feature", spec, "--feature-scale", "3")
        manifest = json.loads((out / f"01-{collection}" / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(len(manifest["shots"]), 1)
        self.assertEqual(manifest["shots"][0]["selection"], {"feature": feature["id"], "variant": feature["variants"][0]["id"]})
        self.assertEqual(manifest["shots"][0]["camera"]["scale"], 3)

    def test_04_wide_map_framing_and_right_edge(self):
        out, _, _ = self.capture("wide-coral-telegraph", "--collection", "coral-telegraph")
        self.assert_good_bundle(out, 1)
        manifest = json.loads((out / "01-coral-telegraph" / "manifest.json").read_text(encoding="utf-8"))
        native = manifest["native"]
        self.assertGreater(native["width"], 1024, "Coral Telegraph is a wide (>1024 cell) map")
        shots = {s["id"]: s for s in manifest["shots"]}
        self.assertEqual(shots["full"]["width"], native["width"] * 2, "right-most cells are exported, not clipped")
        right = shots["full"]["edge_stats"]["right"]
        self.assertTrue(edge_cells_authored(self.art / "coral-telegraph" / "pack.json", 8))
        self.assertGreater(right["distinct_colours"], 1, "authored right-edge cells must appear in the export")
        camera = shots["viewport"]["camera"]
        self.assertTrue(camera["map_fully_visible"])
        self.assertFalse(any(camera["clips"].values()))
        self.assertLessEqual(native["width"] * camera["zoom"], camera["resolution"][0])
        width, height = native["width"], native["height"]
        out, _, _ = self.capture("wide-coral-right-edge-crop", "--collection", "coral-telegraph", "--shots", "detail",
                                 "--crop", f"{width - 96},0,96,{height}", "--detail-zoom", "4")
        manifest = json.loads((out / "01-coral-telegraph" / "manifest.json").read_text(encoding="utf-8"))
        detail = manifest["shots"][0]
        self.assertEqual((detail["width"], detail["height"]), (96 * 4, height * 4))
        self.assertEqual(detail["camera"]["crop"], [width - 96, 0, 96, height])
        self.assertTrue(detail["stats"]["nonblank"])
        # Every map: authored content in the last 8 columns must be visible in the exported edge strip.
        out, _, _ = self.capture("wide-all-maps-edges", "--shots", "full", "--scale", "1")
        batch, jobs = self.manifests(out)
        for collection, job in jobs.items():
            full = job["shots"][0]
            self.assertEqual(full["width"], job["native"]["width"], collection)
            if edge_cells_authored(self.art / collection / "pack.json", 8):
                self.assertGreater(full["edge_stats"]["right"]["distinct_colours"], 1,
                                   f"{collection}: authored right-edge cells missing from the export")

    def test_05_camera_framing_options_are_explicit_and_recorded(self):
        out, _, _ = self.capture("framing-explicit", "--collection", "lumen-fault", "--shots", "viewport",
                                 "--resolution", "800x450", "--zoom", "4", "--center", "320,128")
        manifest = json.loads((out / "01-lumen-fault" / "manifest.json").read_text(encoding="utf-8"))
        shot = manifest["shots"][0]
        self.assertEqual((shot["width"], shot["height"]), (800, 450))
        camera = shot["camera"]
        self.assertAlmostEqual(camera["zoom"], 4.0)
        self.assertEqual(camera["visible_native_rect"], [220.0, 128 - 450 / 8, 200.0, 112.5])
        self.assertFalse(camera["map_fully_visible"])
        out, _, _ = self.capture("framing-view-rect", "--collection", "lumen-fault", "--shots", "viewport",
                                 "--resolution", "1000x500", "--view", "0,0,160,64")
        camera = json.loads((out / "01-lumen-fault" / "manifest.json").read_text(encoding="utf-8"))["shots"][0]["camera"]
        self.assertAlmostEqual(camera["zoom"], 6.25)
        self.assertEqual(camera["visible_native_rect"], [0.0, -8.0, 160.0, 80.0])
        out, _, _ = self.capture("framing-native", "--collection", "lumen-fault", "--shots", "viewport",
                                 "--resolution", "1280x720", "--framing", "native")
        camera = json.loads((out / "01-lumen-fault" / "manifest.json").read_text(encoding="utf-8"))["shots"][0]["camera"]
        self.assertAlmostEqual(camera["zoom"], 1.0)

    def test_06_fixed_presentation_time_is_repeatable_and_changes_animation(self):
        args = ("--collection", "emberglass-fumaroles", "--shots", "viewport,detail", "--resolution", "960x540")
        first, _, _ = self.capture("repeat-a", *args, "--time", "21.33")
        second, _, _ = self.capture("repeat-b", *args, "--time", "21.33")
        other, _, _ = self.capture("repeat-other-time", *args, "--time", "2.5")
        hashes = lambda out: {s["id"]: s["png_sha256"] for s in json.loads(
            (out / "01-emberglass-fumaroles" / "manifest.json").read_text(encoding="utf-8"))["shots"]}
        self.assertEqual(hashes(first), hashes(second), "same source + same time + same renderer must repeat")
        self.assertNotEqual(hashes(first)["viewport"], hashes(other)["viewport"], "shader animation must follow --time")
        batch_a = json.loads((first / "batch-manifest.json").read_text(encoding="utf-8"))
        batch_b = json.loads((second / "batch-manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(batch_a["manifest_sha256"], batch_b["manifest_sha256"], "manifests are deterministic")
        glow_off, _, _ = self.capture("presentation-no-glow", *args, "--time", "21.33", "--no-glow")
        self.assertNotEqual(hashes(first)["viewport"], hashes(glow_off)["viewport"], "--no-glow must change pixels")

    def test_07_before_after_capture_at_equivalent_framing(self):
        work = self.scratch / "writable-art" / "lumen-fault"
        work.mkdir(parents=True)
        pack = work / "pack.json"
        shutil.copyfile(self.art / "lumen-fault" / "pack.json", pack)
        document = json.loads(pack.read_text(encoding="utf-8"))
        scene = document.get("scene") or document["combined_scene"]
        key = "rectangles" if "rectangles" in scene else "terrain_rectangles"
        rect = scene[key][0]
        # The detail crop is pinned to the region that will be edited so all three shots must change.
        crop = f"{rect[0]},{rect[1]},{rect[2]},{rect[3]}"
        args = ("--pack", str(pack), "--shots", "full,viewport,detail", "--scale", "1", "--time", "1.37",
                "--crop", crop, "--detail-zoom", "2")
        before, _, _ = self.capture("compare-before", *args, art_root=False)
        rect[4] = 78 if rect[4] != 78 else 62
        pack.write_text(json.dumps(document), encoding="utf-8")
        after, _, _ = self.capture("compare-after", *args, art_root=False)
        done = subprocess.run([sys.executable, str(LAUNCHER), "--compare-bundles", str(before), str(after)],
                              capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)
        report = json.loads(done.stdout)
        self.assertTrue(report["comparable"])
        self.assertEqual({row["shot"] for row in report["shots"]}, {"full", "viewport", "detail"})
        for row in report["shots"]:
            self.assertTrue(row["framing_equivalent"] and row["pack_changed"] and row["rg8_changed"], row)
            self.assertTrue(row["png_changed"], row)
        # Re-verification notices when the source is edited after capture.
        batch, problems = support.verify_bundle(before)
        self.assertTrue(any("no longer match" in p for p in problems), problems)
        # A different framing is flagged as not comparable.
        other, _, _ = self.capture("compare-other-framing", "--pack", str(pack), "--shots", "full,viewport,detail",
                                   "--scale", "1", "--resolution", "800x600", "--crop", crop, "--detail-zoom", "2",
                                   art_root=False)
        done = subprocess.run([sys.executable, str(LAUNCHER), "--compare-bundles", str(after), str(other)],
                              capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(done.returncode, support.EXIT_EVIDENCE)
        self.assertFalse(json.loads(done.stdout)["comparable"])

    def test_08_bad_inputs_and_render_failures_fail_closed_with_diagnostics(self):
        bad = self.scratch / "bad"
        sources = {}
        for name, text in {
            "malformed": "{ not json",
            "bounds": json.dumps({"features": [{"id": "a", "size": [4, 4], "rectangles": [[0, 0, 9, 9, 1]]}],
                                  "scene": {"size": [8, 8], "rectangles": [], "placements": []}}),
            "blank": json.dumps({"features": [{"id": "a", "size": [4, 4], "rectangles": [[0, 0, 4, 4, 1]]}],
                                 "scene": {"size": [64, 48], "rectangles": [], "placements": []}}),
        }.items():
            folder = bad / name
            folder.mkdir(parents=True)
            (folder / "pack.json").write_text(text, encoding="utf-8")
            sources[name] = folder / "pack.json"
        failures = [
            ("fail-malformed-json", ["--pack", str(sources["malformed"])], support.EXIT_RENDER, "invalid pack JSON"),
            ("fail-out-of-bounds", ["--pack", str(sources["bounds"])], support.EXIT_RENDER, "invalid world-design pack"),
            ("fail-blank-render", ["--pack", str(sources["blank"]), "--shots", "viewport"], support.EXIT_RENDER, "blank"),
            ("fail-unknown-feature", ["--collection", "lumen-fault", "--shots", "none", "--feature", "no-such-feature"],
             support.EXIT_RENDER, "unknown feature"),
            ("fail-unknown-variant", ["--collection", "lumen-fault", "--shots", "none", "--feature",
                                      self.first_feature("lumen-fault") + ":no-such-variant"],
             support.EXIT_RENDER, "no variant"),
            ("fail-crop-outside", ["--collection", "lumen-fault", "--shots", "detail", "--crop", "600,0,200,50"],
             support.EXIT_RENDER, "outside"),
            ("fail-resolution-too-large", ["--collection", "lumen-fault", "--shots", "viewport", "--framing", "native",
                                   "--resolution", "16384x16384"], support.EXIT_USAGE, "--resolution"),
            ("fail-headless-display", ["--collection", "lumen-fault", "--display-driver", "headless"],
             support.EXIT_NO_DISPLAY, "no graphical display"),
        ]
        for name, extra, code, message in failures:
            with self.subTest(name):
                out, result, done = self.capture(name, *extra, expect=code, art_root=not any(e == "--pack" for e in extra))
                self.assertIn(message, " ".join((result or {}).get("failures", [])) + done.stderr, name)
                if (out / "batch-manifest.json").exists():
                    batch = json.loads((out / "batch-manifest.json").read_text(encoding="utf-8"))
                    self.assertEqual(batch["status"], "failed", name)
                    self.assertTrue(batch["failures"])
                    self.assertTrue(support.verify_bundle(out)[1], name + ": a failed bundle must not verify")
                else:
                    self.assertEqual(code, support.EXIT_USAGE, name + ": only usage errors may omit the failed manifest")
        # The blank-render gate is explicit: --allow-blank renders (still real pixels) and succeeds.
        out, _, _ = self.capture("blank-allowed", "--pack", str(sources["blank"]), "--shots", "viewport",
                                 "--allow-blank", art_root=False)
        self.assertEqual(json.loads((out / "batch-manifest.json").read_text(encoding="utf-8"))["status"], "completed")
        # A missing pack is rejected before any renderer starts and creates no output.
        out, _, _ = self.capture_missing("fail-missing-pack")
        if sys.platform.startswith("linux"):
            clean = {k: v for k, v in os.environ.items() if k not in ("DISPLAY", "WAYLAND_DISPLAY")}
            self.capture("fail-no-display-server", "--collection", "lumen-fault",
                         expect=(support.EXIT_RENDER, support.EXIT_NO_DISPLAY, support.EXIT_ENGINE), env=clean)

    def first_feature(self, collection):
        return json.loads((self.art / collection / "pack.json").read_text(encoding="utf-8"))["features"][0]["id"]

    def capture_missing(self, name):
        out = EVIDENCE / name
        shutil.rmtree(out, ignore_errors=True)
        done = subprocess.run([sys.executable, str(LAUNCHER), "--capture", "--godot", GODOT, "--pack",
                               str(self.scratch / "missing" / "pack.json"), "--output-dir", str(out)],
                              capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(done.returncode, support.EXIT_USAGE)
        self.assertIn("pack not found", done.stderr)
        self.assertFalse(out.exists())
        return out, None, done

    def test_09_shader_failure_is_detected(self):
        """A corrupted production shader must produce a nonzero exit and a shader diagnostic."""
        mini = self.scratch / "mini-repo"
        (mini / "tools").mkdir(parents=True)
        for name in ("world_art_preview_launcher.py", "world_art_capture_support.py"):
            shutil.copyfile(HERE / name, mini / "tools" / name)
        for name in launcher.FILES:
            target = mini / "godot" / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / "godot" / name, target)
        shader = mini / "godot" / "shaders" / "material_palette.gdshader"
        shader.write_text(shader.read_text(encoding="utf-8") + "\nthis is not valid shader code;\n", encoding="utf-8")
        out = EVIDENCE / "fail-shader-error"
        shutil.rmtree(out, ignore_errors=True)
        done = subprocess.run(
            [sys.executable, str(mini / "tools" / "world_art_preview_launcher.py"), "--capture", "--godot", GODOT,
             "--rendering-driver", DRIVER, "--art-root", str(self.art), "--collection", "lumen-fault",
             "--output-dir", str(out)], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=900)
        (EVIDENCE / "fail-shader-error.stdout.log").write_text(done.stdout, encoding="utf-8")
        (EVIDENCE / "fail-shader-error.stderr.log").write_text(done.stderr, encoding="utf-8")
        self.assertNotEqual(done.returncode, 0, "corrupt shader must never exit successfully")
        self.assertIn(done.returncode, (support.EXIT_RENDER, support.EXIT_ENGINE, support.EXIT_EVIDENCE))
        batch = json.loads((out / "batch-manifest.json").read_text(encoding="utf-8")) if (out / "batch-manifest.json").exists() else {"status": "failed"}
        self.assertEqual(batch["status"], "failed")

    def test_10_tampering_with_retained_evidence_is_detected(self):
        out, _, _ = self.capture("tamper-source", "--collection", "lumen-fault", "--scale", "1")
        copy = self.scratch / "tamper"
        shutil.copytree(out, copy)
        self.assertEqual(support.verify_bundle(copy)[1], [])
        png = copy / "01-lumen-fault" / "viewport.png"
        raw = bytearray(png.read_bytes())
        raw[len(raw) // 2] ^= 0x55
        png.write_bytes(bytes(raw))
        self.assertTrue(support.verify_bundle(copy)[1])
        shutil.rmtree(copy)
        shutil.copytree(out, copy)
        document = json.loads((copy / "batch-manifest.json").read_text(encoding="utf-8"))
        document["art_source"]["revision"] = "0" * 40
        (copy / "batch-manifest.json").write_text(json.dumps(document), encoding="utf-8")
        self.assertTrue(any("manifest_sha256" in p for p in support.verify_bundle(copy)[1]))

    def test_11_interactive_viewer_entry_points_still_work(self):
        done = subprocess.run([sys.executable, str(LAUNCHER), "--godot", GODOT, "--adapter-oracle"],
                              capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=600)
        self.assertEqual(done.returncode, 0, done.stdout[-1500:] + done.stderr[-1500:])
        done = subprocess.run([sys.executable, str(LAUNCHER), "--godot", GODOT, "--rendering-driver", DRIVER,
                               "--art-root", str(self.art), "--quit-after", "60"],
                              capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=600)
        self.assertEqual(done.returncode, 0, done.stdout[-1500:] + done.stderr[-1500:])
        self.assertNotRegex(done.stdout + done.stderr, r"SCRIPT ERROR|Parse Error")


class _Recorder(unittest.TextTestResult):
    def addSuccess(self, test):
        super().addSuccess(test)
        SOURCE_REPORT.append({"test": test.id(), "status": "pass"})

    def addFailure(self, test, err):
        super().addFailure(test, err)
        SOURCE_REPORT.append({"test": test.id(), "status": "fail"})

    def addError(self, test, err):
        super().addError(test, err)
        SOURCE_REPORT.append({"test": test.id(), "status": "error"})

    def addSkip(self, test, reason):
        super().addSkip(test, reason)
        SOURCE_REPORT.append({"test": test.id(), "status": "skipped", "reason": reason})


def main() -> int:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("-v", "--verbose", action="store_true")
    args, rest = parser.parse_known_args()
    suite = unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2 if args.verbose else 1, resultclass=_Recorder)
    result = runner.run(suite)
    graphical = [r for r in SOURCE_REPORT if "GraphicalCaptureTests" in r["test"]]
    graphical_pass = sum(1 for r in graphical if r["status"] == "pass")
    summary = {"ok": result.wasSuccessful(), "tests": len(SOURCE_REPORT), "skipped": len(result.skipped),
               "graphical_tests_passed": graphical_pass,
               "graphical_qualification": bool(graphical_pass) and graphical_pass == len(graphical) and not result.skipped
               and bool(GODOT), "godot": GODOT, "render_driver": DRIVER, "art_root": ART_ROOT,
               "platform": sys.platform, "results": SOURCE_REPORT}
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "qualification-summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print("WORLD_ART_QUALIFICATION " + json.dumps({k: summary[k] for k in summary if k != "results"}))
    if REQUIRE and summary["graphical_tests_passed"] == 0:
        print("graphical qualification did not run", file=sys.stderr)
        return 1
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())
