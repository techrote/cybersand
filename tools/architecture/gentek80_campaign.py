#!/usr/bin/env python3
"""Run and retain the actual-Godot/native 80-Gentek visual campaign.

The GDScript uses the ordinary ArchitecturalProject compiler and native chunk
API. This wrapper verifies every original PNG against raw native material bytes,
records source/runtime identities, runs a separate reverse/sliced reload process,
and derives labelled contact sheets without synthesizing architectural pixels.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import statistics
import subprocess
import sys
import time

from PIL import Image, ImageDraw, ImageFont, __version__ as pillow_version

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = "godot/tools/capture_gentek80.gd"
PALETTE = "godot/scripts/material_appearance_lut.gd"
EXTENSION = "godot/addons/cybersand_native/cybersand_native.gdextension"


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def save(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def source_identity(require_clean: bool) -> dict:
    head, tree = git("rev-parse", "HEAD", "HEAD^{tree}").splitlines()
    paths: set[Path] = set()
    for folder in ("native/include", "native/src", "godot/native_extension"):
        paths.update(p for p in (ROOT / folder).rglob("*")
                     if p.is_file() and p.suffix in {".hpp", ".h", ".cpp", ".inc"})
    paths.update((ROOT / "godot/scripts").glob("*.gd"))
    paths.update((ROOT / "examples/worldgen/architectural").glob("*.json"))
    paths.update(ROOT / p for p in [SCRIPT, PALETTE, EXTENSION, "godot/project.godot", "Makefile",
                 "tools/architecture/gentek80_campaign.py", "tools/build_native_extension.sh",
                 "tools/build_native_extension.ps1", "tools/architecture/requirements-render-linux.txt"]
                 if (ROOT / p).is_file())
    # Git's text contract deliberately checks PowerShell out as CRLF. Bind both
    # its canonical source identity and exact executed working bytes explicitly.
    inputs = {p.relative_to(ROOT).as_posix(): sha(p.read_bytes().replace(b"\r\n", b"\n")) for p in sorted(paths)}
    working_bytes = {p.relative_to(ROOT).as_posix(): sha(p.read_bytes()) for p in sorted(paths)}
    dirty = []
    for path, digest in inputs.items():
        committed = subprocess.run(["git", "show", f"{head}:{path}"], cwd=ROOT, capture_output=True)
        if committed.returncode or sha(committed.stdout.replace(b"\r\n", b"\n")) != digest:
            dirty.append(path)
    index = git("ls-files", "--stage", "--", *inputs)
    dirty.extend(git("diff", "--cached", "--name-only", head, "--", *inputs).splitlines())
    if require_clean and dirty:
        raise RuntimeError("Campaign inputs must be committed before qualification: " + ", ".join(sorted(set(dirty))))
    return {"commit": head, "tree": tree, "inputs": inputs, "working_bytes_sha256": working_bytes,
            "input_sha256": sha(json.dumps(inputs, sort_keys=True, separators=(",", ":")).encode()),
            "index_sha256": sha(index.encode()), "uncommitted_source_paths": sorted(set(dirty))}


def palette() -> list[tuple[int, int, int, int]]:
    body = (ROOT / PALETTE).read_text(encoding="utf-8").split("const BASE_RGBA8: Array[int] = [", 1)[1].split("]", 1)[0]
    values = [int(v, 16) for v in re.findall(r"0x[0-9a-fA-F]{8}", body)]
    if len(values) != 132:
        raise RuntimeError("Expected the accepted 132-slot preview palette")
    return [((v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, 255) for v in values]


def verify_build_ledger(record: dict, source: dict, runtime_hash: str) -> None:
    """Join separately recorded compilation to the exact execution inputs."""
    if record.get("schema") != "gentek80-native-build-v1":
        raise RuntimeError("Unsupported native build-ledger schema")
    if record.get("source_commit") != source["commit"] or record.get("source_tree") != source["tree"]:
        raise RuntimeError("Native build ledger names a different source commit/tree")
    if record.get("returncode") != 0 or record.get("runtime_sha256") != runtime_hash:
        raise RuntimeError("Native build did not succeed or runtime bytes differ from the build ledger")
    inputs = record.get("source_inputs_sha256")
    if not isinstance(inputs, dict):
        raise RuntimeError("Native build ledger omits its source-input map")
    expected = {path for path in source["inputs"]
                if path.startswith(("native/include/", "native/src/", "godot/native_extension/"))}
    missing = expected - inputs.keys()
    mismatch = [path for path in expected & inputs.keys()
                if inputs[path] != sha((ROOT / path).read_bytes().replace(b"\r\n", b"\n"))]
    if missing or mismatch:
        raise RuntimeError("Native build/source input mismatch: " + ", ".join(sorted(missing | set(mismatch))))


def reference_gallery_comparison(reference: dict, source: dict, report: dict, verified: list[dict]) -> dict:
    """Compare fresh native/pixel evidence with a differently committed public gallery."""
    failures = []
    if reference.get("schema") != "gentek80-public-gallery-v1":
        failures.append("unsupported public gallery schema")
    if not re.fullmatch(r"[0-9a-f]{40}", str(reference.get("source_commit", ""))):
        failures.append("reference gallery omits its exact source commit")
    # These are canonical LF source hashes, so Linux and Windows compare the
    # same inputs. Commit/tree changes for gallery/docs/CI publication are fine.
    expected_inputs = reference.get("rendering_inputs_sha256")
    if not source.get("inputs") or expected_inputs != source["inputs"]:
        failures.append("rendering source inputs differ from the public gallery")
    old = reference.get("defaults", [])
    current = [case for case in report.get("cases", [])
               if case.get("profile") == "default" and case.get("status") == "pass"]
    checked = [case for case in verified if case.get("profile") == "default"]
    groups = [("reference", old), ("fresh native", current), ("fresh pixel", checked)]
    for label, records in groups:
        if not isinstance(records, list) or len(records) != 80:
            failures.append(label + " must contain exactly 80 defaults")
        elif len({row.get("module") for row in records}) != 80 or any(not row.get("module") for row in records):
            failures.append(label + " contains missing or duplicate module identities")
    if not isinstance(old, list):
        old = []
    old_by_module = {case.get("module"): case for case in old if isinstance(case, dict)}
    current_by_module = {case.get("module"): case for case in current}
    checked_by_module = {case.get("module"): case for case in checked}
    if set(old_by_module) != set(current_by_module) or set(old_by_module) != set(checked_by_module):
        failures.append("the 80 public/native/pixel style identities differ")
    for label, records in (("reference", old), ("fresh native", current)):
        if len({row.get("preset_id") for row in records}) != 80 or any(not row.get("preset_id") for row in records):
            failures.append(label + " contains missing or duplicate preset identities")
    comparisons = []
    fields = ("preset_id", "extent", "seed", "material_sha256", "occupancy_sha256", "recipe_sha256", "project_sha256")
    for module in sorted(set(old_by_module) & set(current_by_module) & set(checked_by_module)):
        previous, fresh, pixels = old_by_module[module], current_by_module[module], checked_by_module[module]
        differences = [field for field in fields if field not in previous or previous[field] != fresh.get(field)]
        if not previous.get("rgba_sha256") or previous["rgba_sha256"] != pixels.get("rgba_sha256"):
            differences.append("rgba_sha256")
        if pixels.get("native_pixels_verified") is not True or pixels.get("material_sha256") != fresh.get("material_sha256"):
            differences.append("fresh native/pixel verification")
        if differences:
            failures.append(str(module) + ": " + ", ".join(differences))
        comparisons.append({"module": module, "preset_id": fresh.get("preset_id"),
                            "material_sha256": fresh.get("material_sha256"), "rgba_sha256": pixels.get("rgba_sha256"),
                            "matches": not differences})
    return {"schema": "gentek80-reference-comparison-v1", "status": "fail" if failures else "pass",
            "reference_source_commit": reference.get("source_commit"), "candidate_source_commit": source["commit"],
            "reference_source_tree": reference.get("source_tree"), "candidate_source_tree": source["tree"],
            "rendering_inputs_equal": expected_inputs == source.get("inputs"),
            "reference_defaults": len(old), "fresh_defaults": len(current),
            "matched_defaults": sum(case["matches"] for case in comparisons), "cases": comparisons, "failures": failures,
            "scope": "Fresh native material bytes and decoded RGBA pixels for all 80 defaults; exact rendering inputs with independently named source commits. PNG compression bytes may differ across platforms."}


def verify_reference_gallery_images(manifest_path: Path, reference: dict) -> None:
    """Bind the checked-in public PNGs themselves to their reference receipts."""
    directory = manifest_path.resolve().parent
    defaults = reference.get("defaults")
    if not isinstance(defaults, list) or len(defaults) != 80 or not all(isinstance(case, dict) for case in defaults):
        raise RuntimeError("Public gallery must contain exactly 80 default image receipts")
    if len({case.get("module") for case in defaults}) != 80 or any(not case.get("module") for case in defaults):
        raise RuntimeError("Public gallery must contain 80 unique default module identities")
    for case in defaults:
        relative = case.get("png")
        if not isinstance(relative, str):
            raise RuntimeError("Public default gallery image path is missing")
        path = (directory / relative).resolve()
        if not path.is_relative_to(directory) or not path.is_file():
            raise RuntimeError("Public default gallery image is missing or outside its gallery: " + relative)
        if sha(path.read_bytes()) != case.get("png_sha256"):
            raise RuntimeError("Public default PNG bytes differ from its reference receipt: " + relative)
        with Image.open(path) as original:
            if list(original.size) != case.get("extent") or sha(original.convert("RGBA").tobytes()) != case.get("rgba_sha256"):
                raise RuntimeError("Public default PNG pixels differ from its reference receipt: " + relative)


def configured_runtime() -> Path:
    descriptor = (ROOT / EXTENSION).read_text(encoding="utf-8")
    target = "windows" if os.name == "nt" else "linux"
    matches = re.findall(r"^" + target + r"\.(?:debug|release)\.x86_64\s*=\s*\"([^\"]+)\"", descriptor, re.M)
    if len(matches) != 2 or len(set(matches)) != 1 or not matches[0].startswith("res://"):
        raise RuntimeError("Native runtime descriptor must resolve both desktop targets to one inspected library")
    path = (ROOT / "godot" / matches[0][6:]).resolve()
    if not path.is_relative_to((ROOT / "godot").resolve()):
        raise RuntimeError("Native runtime descriptor leaves the inspected Godot project")
    return path


def process_memory(pid: int, handle: object = None) -> int | None:
    """Observed process working set. It does not include an unmeasured GPU heap."""
    if sys.platform == "linux":
        try:
            status = Path(f"/proc/{pid}/status").read_text()
            value = re.search(r"^VmHWM:\s+(\d+)\s+kB$", status, re.M)
            return int(value.group(1)) * 1024 if value else None
        except (FileNotFoundError, ProcessLookupError):
            return None
    if sys.platform == "win32":
        import ctypes
        from ctypes import wintypes

        class Counters(ctypes.Structure):
            _fields_ = [("cb", wintypes.DWORD), ("PageFaultCount", wintypes.DWORD),
                        *[(name, ctypes.c_size_t) for name in ["PeakWorkingSetSize", "WorkingSetSize",
                        "QuotaPeakPagedPoolUsage", "QuotaPagedPoolUsage", "QuotaPeakNonPagedPoolUsage",
                        "QuotaNonPagedPoolUsage", "PagefileUsage", "PeakPagefileUsage"]]]

        counters = Counters()
        counters.cb = ctypes.sizeof(counters)
        fn = ctypes.windll.psapi.GetProcessMemoryInfo
        fn.argtypes = [wintypes.HANDLE, ctypes.POINTER(Counters), wintypes.DWORD]
        if fn(wintypes.HANDLE(int(handle)), ctypes.byref(counters), counters.cb):
            return int(counters.PeakWorkingSetSize)
    return None


def execute(godot: Path, output: Path, phase: str, modules: str | None, timeout: int) -> dict:
    command = [str(godot), "--headless", "--path", str(ROOT / "godot"), "--script", "res://" + Path(SCRIPT).relative_to("godot").as_posix(),
               "--", "--phase", phase, "--output", str(output)]
    if modules:
        command += ["--modules", modules]
    environment = os.environ.copy()
    environment["XDG_DATA_HOME"] = str(output / "isolated-user")
    began = time.monotonic()
    peak = None
    timed_out = False
    log_path = output / (phase + ".log")
    with log_path.open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, cwd=ROOT, env=environment, stdout=log, stderr=subprocess.STDOUT)
        while process.poll() is None:
            observed = process_memory(process.pid, getattr(process, "_handle", None))
            if observed is not None:
                peak = max(peak or 0, observed)
            if time.monotonic() - began > timeout:
                timed_out = True
                process.kill()
                break
            time.sleep(0.2)
        result = process.wait()
    text = log_path.read_text(encoding="utf-8", errors="replace")
    diagnostics = [line for line in text.splitlines()
                   if re.search(r"(?:SCRIPT ERROR:|Parse Error:|ERROR:|FATAL:)", line)]
    record = {"phase": phase, "command": command, "returncode": result,
              "elapsed_seconds": time.monotonic() - began, "timed_out": timed_out,
              "observed_peak_process_rss_bytes": peak, "unexpected_diagnostics": diagnostics,
              "log_sha256": sha(log_path.read_bytes())}
    save(output / (phase + "-process.json"), record)
    print(json.dumps({k: record[k] for k in ["phase", "returncode", "elapsed_seconds", "observed_peak_process_rss_bytes"]}), flush=True)
    return record


def component_metrics(mask: bytes, width: int, height: int, value: int) -> dict:
    """Exact cardinal components using row runs; no SciPy/native dependency.

    Touching the crop boundary is reported separately. It does not establish
    physical load bearing, player clearance or connection beyond the crop.
    """
    parents: list[int] = []
    areas: list[int] = []
    borders: list[bool] = []
    extents: list[list[int]] = []

    def root(label: int) -> int:
        while parents[label] != label:
            parents[label] = parents[parents[label]]
            label = parents[label]
        return label

    def union(first: int, second: int) -> int:
        a, b = root(first), root(second)
        if a != b:
            if areas[a] < areas[b]:
                a, b = b, a
            parents[b] = a
            areas[a] += areas[b]
            borders[a] = borders[a] or borders[b]
            extents[a] = [min(extents[a][0], extents[b][0]), min(extents[a][1], extents[b][1]),
                          max(extents[a][2], extents[b][2]), max(extents[a][3], extents[b][3])]
        return a

    previous: list[tuple[int, int, int]] = []
    desired, other = bytes([value]), bytes([1 - value])
    for y in range(height):
        row = mask[y * width:(y + 1) * width]
        current = []
        offset = 0
        old_index = 0
        while offset < width:
            start = row.find(desired, offset)
            if start < 0:
                break
            end = row.find(other, start)
            if end < 0:
                end = width
            label = len(parents)
            parents.append(label)
            areas.append(end - start)
            borders.append(y in (0, height - 1) or start == 0 or end == width)
            extents.append([start, y, end, y + 1])
            while old_index < len(previous) and previous[old_index][1] <= start:
                old_index += 1
            j = old_index
            while j < len(previous) and previous[j][0] < end:
                label = union(label, previous[j][2])
                j += 1
            current.append((start, end, label))
            offset = end
        previous = current
    identities = [i for i, parent in enumerate(parents) if i == parent]
    sizes = sorted((areas[i] for i in identities), reverse=True)
    largest = max(identities, key=lambda i: areas[i]) if identities else None
    return {"count": len(identities), "largest_cells": sizes[0] if sizes else 0,
            "total_cells": sum(sizes), "largest_fraction": sizes[0] / sum(sizes) if sizes else 0,
            "isolated_single_cells": sum(size == 1 for size in sizes),
            "touching_crop_boundary_cells": sum(areas[i] for i in identities if borders[i]),
            "largest_bounds": extents[largest] if largest is not None else None,
            "largest_ten_component_cells": sizes[:10]}


def verify_originals(output: Path, report: dict, colours: list) -> list[dict]:
    results = []
    channels = [bytes(colour[channel] for colour in colours).ljust(256, b"\0") for channel in range(4)]
    for case in report["cases"]:
        if case.get("status") != "pass":
            continue
        raw = (output / case["raw"]).read_bytes()
        if len(raw) != case["extent"][0] * case["extent"][1] or sha(raw) != case["material_sha256"]:
            raise RuntimeError("Native payload hash/extent mismatch: " + case["name"])
        if max(raw) >= len(colours):
            raise RuntimeError("Native material is outside the actual preview palette: " + case["name"])
        # Byte-channel lookup avoids allocating one Python tuple per pixel.
        expected = Image.merge("RGBA", tuple(Image.frombytes("L", tuple(case["extent"]), raw.translate(channel)) for channel in channels))
        with Image.open(output / case["png"]) as original:
            if original.size != tuple(case["extent"]) or original.convert("RGBA").tobytes() != expected.tobytes():
                raise RuntimeError("PNG pixels differ from native material bytes: " + case["name"])
        counts = Counter(raw)
        if {str(k): v for k, v in counts.items()} != case["material_counts"]:
            raise RuntimeError("Native material distribution mismatch: " + case["name"])
        mask = raw.translate(bytes([0] + [1] * 255))
        if sha(mask) != case["occupancy_sha256"]:
            raise RuntimeError("Occupied/empty hash mismatch: " + case["name"])
        occupied = component_metrics(mask, *case["extent"], 1)
        empty = component_metrics(mask, *case["extent"], 0)
        results.append({"name": case["name"], "module": case["module"], "profile": case["profile"],
                        "extent": case["extent"], "material_sha256": sha(raw),
                        "rgba_sha256": sha(expected.tobytes()),
                        "png_sha256": sha((output / case["png"]).read_bytes()),
                        "native_pixels_verified": True, "occupied": occupied, "empty": empty,
                        "empty_fraction": counts.get(0, 0) / len(raw)})
    save(output / "pixel-and-connectivity-verification.json", {
        "schema": 1, "palette_sha256": sha((ROOT / PALETTE).read_bytes()), "cases": results,
        "scope": "Exact native materials and cardinal cell connectivity inside the crop; no structural-stability or player-traversability claim."})
    return results


def font(size: int) -> ImageFont.ImageFont:
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "C:/Windows/Fonts/arial.ttf"):
        if Path(path).is_file():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def short_label(value: str, limit: int = 31) -> str:
    return value if len(value) <= limit else value[:limit - 1] + "…"


def sheet(output: Path, cases: list[dict], name: str, columns: int, tile: int = 240) -> dict:
    header, footer = 46, 36
    rows = (len(cases) + columns - 1) // columns
    result = Image.new("RGB", (columns * tile, rows * (tile + header + footer)), "#101722")
    draw = ImageDraw.Draw(result)
    for index, case in enumerate(cases):
        x, y = index % columns * tile, index // columns * (tile + header + footer)
        draw.text((x + 7, y + 6), short_label(case["label"], 28), fill="#eef4fa", font=font(13))
        draw.text((x + 7, y + 25), f"{case['index']:02d} · {case['profile']}", fill="#9fb3c8", font=font(11))
        with Image.open(output / case["png"]) as original:
            original = original.convert("RGB")
            scale = min((tile - 8) / original.width, (tile - 8) / original.height)
            preview = original.resize((round(original.width * scale), round(original.height * scale)), Image.Resampling.NEAREST)
            result.paste(preview, (x + (tile - preview.width) // 2, y + header + (tile - preview.height) // 2))
        g = case["geometry"]
        draw.text((x + 7, y + header + tile + 3), f"seed {case['seed']} · {g['room_size']}/{g['floor_height']}/{g['wall_thickness']}",
                  fill="#aebfd1", font=font(10))
        draw.text((x + 7, y + header + tile + 18), "bay / floor / wall · native cells", fill="#778da6", font=font(10))
    target = output / name
    result.save(target)
    return {"file": name, "sha256": sha(target.read_bytes()), "kind": "labelled nearest-neighbour contact sheet",
            "sources": [case["png"] for case in cases]}


def detail_sheet(output: Path, cases: list[dict]) -> dict:
    columns, size = 4, 384
    result = Image.new("RGB", (columns * size, 2 * (size + 56)), "#101722")
    draw = ImageDraw.Draw(result)
    sources = []
    for index, case in enumerate(cases[:8]):
        x, y = index % columns * size, index // columns * (size + 56)
        with Image.open(output / case["png"]) as original:
            crop = original.convert("RGB").crop((96, 96, 288, 288))
            result.paste(crop.resize((size, size), Image.Resampling.NEAREST), (x, y + 56))
        draw.text((x + 8, y + 8), short_label(case["label"], 37), fill="#eef4fa", font=font(16))
        draw.text((x + 8, y + 31), "Native crop [96,96–288,288] · 2× nearest", fill="#aebfd1", font=font(12))
        sources.append({"file": case["png"], "crop": [96, 96, 288, 288], "scale": 2})
    path = output / "showcase-details.png"
    result.save(path)
    return {"file": path.name, "sha256": sha(path.read_bytes()), "kind": "unaltered native detail crops, 2x nearest-neighbour", "sources": sources}


def failure_gallery(output: Path, report: dict) -> dict:
    rejected = report.get("rejections", [])
    unexpected = report.get("failures", [])
    result = Image.new("RGB", (1600, 620), "#101722")
    draw = ImageDraw.Draw(result)
    draw.text((30, 24), "REFUSALS AND FAILURES — NO ARCHITECTURAL PIXELS SYNTHESIZED", fill="#eef4fa", font=font(23))
    draw.text((30, 70), f"Expected invalid-input refusals: {len(rejected)}   |   Unexpected failures: {len(unexpected)}",
              fill="#aebfd1", font=font(20))
    samples = []
    for kind in ("room-outside-bounds", "door-does-not-fit", "reserved-material-10"):
        found = next((case for case in rejected if case["profile"] == kind), None)
        if found:
            samples.append(found)
    for index, case in enumerate(samples):
        y = 128 + index * 110
        draw.rectangle((24, y, 1576, y + 94), outline="#344a62", width=2)
        draw.text((42, y + 12), f"{case['module']} · {case['profile']} · {case['stage']} refusal", fill="#dfb970", font=font(18))
        draw.text((42, y + 48), short_label(str(case["error"]), 133), fill="#d5dfeb", font=font(15))
    draw.text((30, 490), "All original requests and exact error messages are retained in native-campaign.json.", fill="#aebfd1", font=font(17))
    draw.text((30, 528), "These cards document rejected requests; no generated geometry is represented.", fill="#aebfd1", font=font(17))
    if unexpected:
        draw.text((30, 572), short_label(str(unexpected[0]), 135), fill="#f28d85", font=font(16))
    target = output / "failure-and-rejection-index.png"
    result.save(target)
    return {"file": target.name, "sha256": sha(target.read_bytes()), "kind": "text-only diagnostic cards; not native terrain",
            "unexpected_failures": unexpected, "expected_refusals": len(rejected)}


def summarize(output: Path, report: dict, verification: list[dict], processes: list[dict]) -> list[dict]:
    passed = [case for case in report["cases"] if case.get("status") == "pass"]
    defaults = [case for case in passed if case["profile"] == "default"]
    derived = [sheet(output, defaults, "all-80-index.png", 8)]
    for offset in range(0, len(defaults), 20):
        derived.append(sheet(output, defaults[offset:offset + 20], f"catalogue-page-{offset // 20 + 1:02d}.png", 5, 256))
    for default in defaults:
        variants = [case for case in passed if case["module"] == default["module"]]
        derived.append(sheet(output, variants, default["module"] + "--variations.png", 4 if len(variants) > 6 else 3, 256))
    showcases = [case for case in defaults if case["family"] == "showcase"]
    if len(showcases) == 8:
        derived.append(sheet(output, showcases, "eight-showcases.png", 4, 384))
        derived.append(detail_sheet(output, showcases))
    derived.append(failure_gallery(output, report))
    save(output / "derived-images.json", derived)
    timings = []
    control_effects = []
    for module in dict.fromkeys(case["module"] for case in passed):
        samples = [case for case in passed if case["module"] == module]
        timings.append({"module": module, "cases": len(samples),
                        "native_raster_ms_min": min(case["native_raster_us"] for case in samples) / 1000,
                        "native_raster_ms_median": statistics.median(case["native_raster_us"] for case in samples) / 1000,
                        "native_raster_ms_max": max(case["native_raster_us"] for case in samples) / 1000,
                        "cases_by_extent": dict(Counter("x".join(map(str, case["extent"])) for case in samples))})
        baseline = next(case for case in samples if case["profile"] == "default")
        baseline_raw = (output / baseline["raw"]).read_bytes()
        for case in samples:
            if case["profile"] == "default" or case["extent"] != baseline["extent"]:
                continue
            raw = (output / case["raw"]).read_bytes()
            control_effects.append({"module": module, "profile": case["profile"],
                                   "changed_material_cells": sum(a != b for a, b in zip(baseline_raw, raw)),
                                   "changed_occupied_empty_cells": sum((a == 0) != (b == 0) for a, b in zip(baseline_raw, raw))})
    save(output / "control-effects.json", {"schema": 1, "cases": control_effects,
        "seed_variant_changes_materials": sum(case["profile"] == "seed-1701" and case["changed_material_cells"] > 0 for case in control_effects),
        "seed_variant_unchanged_materials": [case["module"] for case in control_effects if case["profile"] == "seed-1701" and case["changed_material_cells"] == 0],
        "scope": "Measured control deltas against each default. Seed-independent structural patterns are reported explicitly; a new seed need not change a deterministic unseeded sampler."})
    comparable: dict[str, dict[str, list[str]]] = {}
    for profile in ("default", "compact", "tall"):
        grouped: dict[str, list[str]] = {}
        for case in passed:
            if case["profile"] == profile:
                grouped.setdefault(case["occupancy_sha256"], []).append(case["module"])
        comparable[profile] = grouped
    paired: dict[str, list[str]] = {}
    for default in defaults:
        samples = {case["profile"]: case for case in passed if case["module"] == default["module"]}
        if "compact" in samples and "tall" in samples:
            key = samples["compact"]["occupancy_sha256"] + ":" + samples["tall"]["occupancy_sha256"]
            paired.setdefault(key, []).append(default["module"])
    save(output / "structural-distinctness.json", {
        "schema": 1, "profiles": {profile: {"unique_occupied_empty_hashes": len(grouped),
            "collision_groups": [modules for modules in grouped.values() if len(modules) > 1]}
            for profile, grouped in comparable.items()},
        "combined_common_parameter_signatures": len(paired),
        "common_parameter_collision_groups": [modules for modules in paired.values() if len(modules) > 1],
        "scope": "Default silhouettes plus two common geometry configurations per module, ignoring material colours. Finite parameter coincidences are disclosed; this metric does not replace visual review."})
    save(output / "performance-and-memory.json", {"schema": 1, "modules": timings, "processes": processes,
        "scope": "Native configuration/chunk timings and process peak RSS; mixed parameter sizes, one trial per variant. Advisory observations, not a stable benchmark or physical display latency claim."})
    metrics = {case["name"]: case for case in verification}
    lines = ["# GENTEK-80 native material gallery", "",
             "Every original image is an actual native chunk material map produced through the ordinary Architectural Generator project compiler. The complete `.cells` payload, project/recipe identities and pixel checks accompany the PNGs in the full evidence artifact. Labels and contact sheets are derived previews.", "",
             "**80 Genteks = 72 repaired CLASSIC samplers + eight advanced showcases.** The existing 13 legacy presets remain separately selectable in Workbench.", "",
             "![All 80 native Genteks](all-80-index.png)", "",
             "[Native report](native-campaign.json) · [Independent process reload](process-reload.json) · [Pixel/connectivity checks](pixel-and-connectivity-verification.json) · [Structural distinctness](structural-distinctness.json) · [Control effects](control-effects.json) · [Performance/memory](performance-and-memory.json) · [Execution/source identity](campaign-identity.json)", "",
             "| # | Gentek | Family | Native default | Variants | Empty | Solid components | Largest solid fraction |", "| --- | --- | --- | --- | --- | ---: | ---: | ---: |"]
    for case in defaults:
        measured = metrics[case["name"]]
        lines.append(f"| {case['index']:02d} | {case['label']} | {case['family']} | [PNG]({case['png']}) | [Sheet]({case['module']}--variations.png) | {measured['empty_fraction']:.1%} | {measured['occupied']['count']} | {measured['occupied']['largest_fraction']:.1%} |")
    lines += ["", "## Advanced structural details", "", "![Eight showcases](eight-showcases.png)", "",
              "![Selected native detail crops](showcase-details.png)", "", "## Failure and rejection record", "",
              "![Explicit failure and rejection index](failure-and-rejection-index.png)", "",
              "The complete invalid requests and exact diagnostics are retained. A component count describes face-connected occupied cells within a finite crop. Glazing also occupies cells. Cropping, apertures, shafts, clipping and deliberate disconnected architectural ornament can change this measurement. These statistics do not establish physical load bearing or player traversal.", "",
              "## Performance interpretation", "",
              "Per-case native configure/raster times, logical work, material payload bytes and Godot allocator counters are recorded alongside observed whole-process peak resident memory. Every Gentek is also rendered at the ordinary maximum 1024-square project extent. Timings are advisory single observations across different parameter variants; they are not interchangeable benchmark trials or Windows GPU frame measurements.", ""]
    (output / "README.md").write_text("\n".join(lines), encoding="utf-8")
    return derived


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--output", type=Path, default=ROOT / "build/gentek80-campaign")
    parser.add_argument("--runtime", type=Path)
    parser.add_argument("--runtime-build-ledger", type=Path, help="retain independently produced build provenance with the execution receipt")
    parser.add_argument("--reference-gallery", type=Path, help="require fresh all-80 default native/pixel identity with an explicitly sourced public-gallery manifest")
    parser.add_argument("--require-clean-source", action="store_true")
    parser.add_argument("--modules", help="comma-separated subset for iteration; never a complete-catalogue qualification")
    parser.add_argument("--timeout", type=int, default=5400)
    parser.add_argument("--verify-only", action="store_true", help="verify retained native captures and regenerate derived sheets; no execution claim")
    args = parser.parse_args()
    if args.reference_gallery and (args.modules or args.verify_only):
        raise RuntimeError("Reference gallery qualification requires a fresh complete-catalogue capture")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    colours = palette()
    if args.verify_only:
        report = json.loads((output / "native-campaign.json").read_text(encoding="utf-8"))
        processes = [json.loads(path.read_text(encoding="utf-8")) for path in output.glob("*-process.json")]
        verified = verify_originals(output, report, colours)
        summarize(output, report, verified, processes)
        print(json.dumps({"verified_originals": len(verified), "execution": False}))
        return 0 if not report.get("failures") else 1
    if (output / "native-campaign.json").exists() or (output / "campaign-identity.json").exists():
        raise RuntimeError("Retained campaign evidence already exists; use a fresh output directory for a new attempt")
    before = source_identity(args.require_clean_source)
    save(output / "source-inputs.json", before)
    reference = None
    reference_hash = None
    if args.reference_gallery:
        reference_bytes = args.reference_gallery.read_bytes()
        reference_hash = sha(reference_bytes)
        reference = json.loads(reference_bytes)
        (output / "reference-gallery.json").write_bytes(reference_bytes)
        try:
            if reference.get("schema") != "gentek80-public-gallery-v1" or not re.fullmatch(r"[0-9a-f]{40}", str(reference.get("source_commit", ""))):
                raise RuntimeError("Public gallery needs its schema and exact source commit")
            if reference.get("rendering_inputs_sha256") != before["inputs"]:
                raise RuntimeError("Rendering source inputs differ from the public gallery")
            verify_reference_gallery_images(args.reference_gallery, reference)
        except (RuntimeError, OSError, ValueError) as error:
            save(output / "reference-gallery-comparison.json", {
                "schema": "gentek80-reference-comparison-v1", "status": "fail",
                "reference_source_commit": reference.get("source_commit"), "candidate_source_commit": before["commit"],
                "reference_manifest_sha256": reference_hash, "failures": [str(error)]})
            raise
    godot_name = shutil.which(args.godot) or args.godot
    godot = Path(godot_name).resolve()
    if not godot.is_file():
        raise RuntimeError("Godot executable is unavailable: " + str(godot))
    godot_hash = sha(godot.read_bytes())
    godot_version = subprocess.check_output([str(godot), "--version"], text=True).strip()
    loaded_runtime = configured_runtime()
    runtime = args.runtime or loaded_runtime
    runtime = runtime.resolve()
    if not runtime.is_file() or runtime.read_bytes().startswith(b"version https://git-lfs.github.com/spec/"):
        raise RuntimeError("Materialized source-built native runtime is required: " + str(runtime))
    runtime_hash = sha(runtime.read_bytes())
    if not loaded_runtime.is_file() or sha(loaded_runtime.read_bytes()) != runtime_hash:
        raise RuntimeError("Supplied runtime bytes differ from the library actually configured for this Godot project")
    build_ledger = None
    if args.runtime_build_ledger:
        build_ledger = json.loads(args.runtime_build_ledger.read_text(encoding="utf-8"))
        verify_build_ledger(build_ledger, before, runtime_hash)
        save(output / "runtime-build-ledger.json", build_ledger)
    elif args.require_clean_source:
        raise RuntimeError("--require-clean-source also requires --runtime-build-ledger for source/runtime qualification")
    processes = [execute(godot, output, "capture", args.modules, args.timeout)]
    if (output / "native-campaign.json").is_file():
        processes.append(execute(godot, output, "replay", args.modules, args.timeout))
    report = json.loads((output / "native-campaign.json").read_text(encoding="utf-8")) if (output / "native-campaign.json").is_file() else {"cases": [], "failures": ["capture report missing"]}
    verified = verify_originals(output, report, colours)
    derived = summarize(output, report, verified, processes) if verified else []
    after = source_identity(args.require_clean_source)
    unchanged = (before == after and runtime_hash == sha(runtime.read_bytes())
                 and loaded_runtime == configured_runtime() and runtime_hash == sha(loaded_runtime.read_bytes())
                 and godot_hash == sha(godot.read_bytes()))
    successful = unchanged and not report.get("failures") and all(not p["returncode"] and not p["unexpected_diagnostics"] for p in processes)
    defaults = [case for case in report.get("cases", []) if case.get("profile") == "default" and case.get("status") == "pass"]
    if not args.modules:
        successful = successful and len(defaults) == 80 and len(verified) == 520
    replay = json.loads((output / "process-reload.json").read_text(encoding="utf-8")) if (output / "process-reload.json").is_file() else {}
    successful = successful and not replay.get("failures", ["missing replay"]) and len(replay.get("cases", [])) == len(defaults)
    if reference is not None:
        comparison = reference_gallery_comparison(reference, before, report, verified)
        comparison["reference_manifest_sha256"] = reference_hash
        comparison["candidate_runtime_sha256"] = runtime_hash
        save(output / "reference-gallery-comparison.json", comparison)
        successful = successful and comparison["status"] == "pass"
        with (output / "README.md").open("a", encoding="utf-8") as readme:
            readme.write("\n## Public gallery source equivalence\n\n"
                         "[Exact source/native/pixel comparison](reference-gallery-comparison.json) names both source commits and checks all 80 fresh default renders against the checked-in gallery.\n")
    identity = {"schema": 1, "recorded_at": datetime.now(timezone.utc).isoformat(),
                "source": before, "source_and_runtime_unchanged": unchanged,
                "runtime": {"path": str(runtime), "sha256": runtime_hash, "configured_path": str(loaded_runtime)},
                "runtime_build_ledger": "runtime-build-ledger.json" if build_ledger else None,
                "reference_gallery_comparison": "reference-gallery-comparison.json" if reference is not None else None,
                "runtime_build_provenance_note": "The independent build ledger was matched to the executed source commit/tree, all native input hashes, successful build result and actual binary hash." if build_ledger else "Provisional execution binding only; no independent source/runtime build provenance was supplied.",
                "godot": {"path": str(godot), "sha256": godot_hash, "version": godot_version},
                "platform": platform.platform(), "python": sys.version, "pillow": pillow_version,
                "scope": "subset iteration" if args.modules else "complete 80-Gentek catalogue",
                "original_native_pngs": len(verified), "distinct_default_genteks": len(defaults),
                "replayed_default_genteks": len(replay.get("cases", [])), "processes": processes,
                "derived_images": derived, "status": "pass" if successful else "fail",
                "physical_windows_gpu_acceptance": "not established by this headless material campaign"}
    save(output / "campaign-identity.json", identity)
    save(output / "artifact-hashes.json", {path.relative_to(output).as_posix(): sha(path.read_bytes())
         for path in sorted(output.rglob("*")) if path.is_file() and "isolated-user" not in path.parts and path.name != "artifact-hashes.json"})
    print(json.dumps({key: identity[key] for key in ["status", "scope", "original_native_pngs", "distinct_default_genteks", "replayed_default_genteks"]}), flush=True)
    return 0 if successful else 1


if __name__ == "__main__":
    raise SystemExit(main())
