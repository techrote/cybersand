"""Capture-bundle adapter for the #498 unattended Godot renderer.

Contract consumed (docs/tools/world-art-capture.md on PR #506): the launcher exits
0/2/3/4/5/6/7, prints ``WORLD_ART_CAPTURE_RESULT {json}`` last on stdout and writes
``batch-manifest.json`` sealed by ``manifest_sha256`` plus per-job manifests and PNGs.
This module re-verifies bundles independently (seal, hashes, PNG structure) and
classifies their evidence so a flat fixture raster is never mistaken for Godot output.
"""
from __future__ import annotations

import hashlib
import json
import struct
import zlib
from pathlib import Path

from .errors import ConfigError, ToolError
from .procs import run_allowlisted
from .sandbox import sha256_bytes, sha256_file

SCHEMA_BATCH = "cybersand.world_art_capture.batch-manifest/1"
SCHEMA_JOB = "cybersand.world_art_capture.job-manifest/1"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
LAUNCHER_NAME = "world_art_preview_launcher.py"
LAUNCHER_EXIT = {0: "completed", 2: "usage", 3: "engine_unusable", 4: "render_failed", 5: "evidence_invalid",
                 6: "source_changed", 7: "no_display"}


def canonical_json(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def seal(manifest: dict) -> dict:
    body = {k: v for k, v in manifest.items() if k != "manifest_sha256"}
    manifest["manifest_sha256"] = sha256_bytes(canonical_json(body))
    return manifest


def is_sealed(manifest: dict) -> bool:
    body = {k: v for k, v in manifest.items() if k != "manifest_sha256"}
    return manifest.get("manifest_sha256") == sha256_bytes(canonical_json(body))


def inspect_png(path: Path) -> dict:
    """Independent PNG structure/CRC check; raises ValueError when invalid."""
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError("not a PNG (bad signature)")
    position, header, compressed, ended = len(PNG_SIGNATURE), None, bytearray(), False
    while position < len(data):
        if position + 12 > len(data):
            raise ValueError("truncated PNG chunk header")
        length, kind = struct.unpack(">I4s", data[position:position + 8])
        end = position + 8 + length
        if end + 4 > len(data):
            raise ValueError("truncated PNG chunk")
        chunk = data[position + 8:end]
        (crc,) = struct.unpack(">I", data[end:end + 4])
        if zlib.crc32(kind + chunk) & 0xFFFFFFFF != crc:
            raise ValueError(f"PNG chunk {kind!r} CRC mismatch")
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", chunk)
        elif kind == b"IDAT":
            compressed += chunk
        elif kind == b"IEND":
            ended = True
            break
        position = end + 4
    if header is None or not ended or not compressed:
        raise ValueError("PNG lacks IHDR/IDAT/IEND")
    width, height, depth, colour, _, _, interlace = header
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(colour)
    if channels is None or interlace != 0 or depth != 8:
        raise ValueError(f"unsupported PNG layout (colour type {colour}, depth {depth}, interlace {interlace})")
    raw = zlib.decompress(bytes(compressed))
    if len(raw) != height * (1 + width * channels):
        raise ValueError("PNG pixel stream has the wrong length")
    diversity = len(set(raw[::max(1, len(raw) // 1_000_000)]))
    return {"width": width, "height": height, "bytes": len(data), "sha256": sha256_bytes(data),
            "raw_byte_diversity": diversity}


def _read_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise ToolError("evidence_unreadable", f"cannot read {path.name}: {exc}") from None
    if not isinstance(value, dict):
        raise ToolError("evidence_unreadable", f"{path.name} is not a JSON object")
    return value


def classify(batch: dict) -> str:
    """godot-capture | fixture | unclassified. Only godot-capture may support a visual-cycle claim."""
    if batch.get("fixture") is True:
        return "fixture"
    engine = batch.get("engine") or {}
    if engine.get("executable_sha256") and (engine.get("display") or {}).get("rendering_driver"):
        return "godot-capture"
    return "unclassified"


def verify_bundle(bundle: Path) -> tuple[dict, list[dict], list[str]]:
    """Return (batch manifest, shots, problems). ``shots`` rows are verified PNG records."""
    path = Path(bundle) / "batch-manifest.json"
    if not path.is_file():
        raise ToolError("bundle_missing", f"{path.name} not found; not a capture bundle")
    batch = _read_json(path)
    problems: list[str] = []
    if batch.get("schema") != SCHEMA_BATCH:
        problems.append("wrong batch manifest schema")
    if not is_sealed(batch):
        problems.append("batch manifest_sha256 does not match its content")
    if batch.get("status") != "completed":
        problems.append(f"batch status is {batch.get('status')!r}")
    shots: list[dict] = []
    for entry in batch.get("jobs", []):
        manifest_path = Path(bundle) / str(entry.get("manifest", ""))
        if not manifest_path.is_file():
            problems.append(f"{entry.get('id')}: job manifest missing")
            continue
        if sha256_file(manifest_path) != entry.get("manifest_sha256"):
            problems.append(f"{entry.get('id')}: job manifest differs from the batch record")
        job = _read_json(manifest_path)
        if job.get("status") != "complete":
            problems.append(f"{entry.get('id')}: job status {job.get('status')!r}")
        for shot in job.get("shots", []):
            png = manifest_path.parent / str(shot.get("file", ""))
            row = {"collection": entry.get("collection"), "shot_id": shot.get("id"), "kind": shot.get("kind"),
                   "path": png, "png_sha256": shot.get("png_sha256"), "width": shot.get("width"),
                   "height": shot.get("height"), "pack_sha256": (job.get("input_pack") or {}).get("sha256"),
                   "camera": shot.get("camera"), "rg8_sha256": (shot.get("source") or {}).get("rg8_sha256"),
                   "verified": False}
            try:
                info = inspect_png(png)
            except (OSError, ValueError, zlib.error) as exc:
                problems.append(f"{entry.get('id')}/{shot.get('file')}: invalid PNG: {exc}")
                shots.append(row)
                continue
            if info["sha256"] != shot.get("png_sha256"):
                problems.append(f"{entry.get('id')}/{shot.get('file')}: PNG SHA-256 differs from the manifest")
            elif (info["width"], info["height"]) != (shot.get("width"), shot.get("height")):
                problems.append(f"{entry.get('id')}/{shot.get('file')}: PNG size differs from the manifest")
            elif info["raw_byte_diversity"] < 4:
                problems.append(f"{entry.get('id')}/{shot.get('file')}: image is blank")
            else:
                row["verified"] = True
                row["bytes"] = info["bytes"]
            shots.append(row)
    if not batch.get("jobs") or not shots:
        problems.append("bundle records no jobs/shots")
    return batch, shots, problems


def summarize_bundle(bundle: Path, label: str = "input") -> dict:
    batch, shots, problems = verify_bundle(bundle)
    return {"label": label, "batch_manifest_sha256": batch.get("manifest_sha256"), "evidence_class": classify(batch),
            "verified": not problems, "problems": problems,
            "renderer": ((batch.get("engine") or {}).get("display") or {}).get("rendering_driver"),
            "art_revision": (batch.get("art_source") or {}).get("revision"),
            "shots": [{"shot_id": s["shot_id"], "collection": s["collection"], "kind": s["kind"],
                       "width": s["width"], "height": s["height"], "png_sha256": s["png_sha256"],
                       "pack_sha256": s["pack_sha256"], "verified": s["verified"]} for s in shots]}


def compare_bundles(before: Path, after: Path) -> dict:
    """Per-shot comparison with the same equivalence notion as the #498 tool."""
    b_batch, b_shots, b_problems = verify_bundle(before)
    a_batch, a_shots, a_problems = verify_bundle(after)
    left = {(s["collection"], s["shot_id"]): s for s in b_shots}
    right = {(s["collection"], s["shot_id"]): s for s in a_shots}
    rows = []
    for key in sorted(set(left) | set(right), key=str):
        if key not in left or key not in right:
            rows.append({"collection": key[0], "shot_id": key[1], "comparable": False, "note": "in one bundle only"})
            continue
        s1, s2 = left[key], right[key]
        same_frame = s1["camera"] == s2["camera"] and (s1["width"], s1["height"]) == (s2["width"], s2["height"])
        rows.append({"collection": key[0], "shot_id": key[1], "comparable": same_frame,
                     "pack_changed": s1["pack_sha256"] != s2["pack_sha256"],
                     "rg8_changed": s1["rg8_sha256"] != s2["rg8_sha256"],
                     "png_changed": s1["png_sha256"] != s2["png_sha256"],
                     "before_png_sha256": s1["png_sha256"], "after_png_sha256": s2["png_sha256"]})
    classes = (classify(b_batch), classify(a_batch))
    ok = bool(rows) and all(r["comparable"] for r in rows) and not b_problems and not a_problems
    return {"comparable": ok, "evidence_classes": list(classes), "before_problems": b_problems,
            "after_problems": a_problems, "shots": rows,
            "godot_to_godot": classes == ("godot-capture", "godot-capture"),
            "visual_change_observed": ok and any(r.get("png_changed") and r.get("pack_changed") for r in rows)}


def load_shot_for_model(shot: dict, max_bytes: int, max_edge: int) -> tuple[bytes, dict]:
    """Re-read a verified PNG, enforcing size limits. Returns (bytes, record)."""
    if not shot.get("verified"):
        raise ToolError("image_unverified", "that shot failed bundle verification and will not be sent")
    data = Path(shot["path"]).read_bytes()
    info = inspect_png_bytes_guard(data, shot)
    if info["bytes"] > max_bytes:
        raise ToolError("image_too_large", f"PNG is {info['bytes']} bytes (limit {max_bytes}); capture a smaller "
                                           "viewport/detail shot")
    if max(info["width"], info["height"]) > max_edge:
        raise ToolError("image_too_large", f"PNG is {info['width']}x{info['height']} (edge limit {max_edge})")
    return data, info


def inspect_png_bytes_guard(data: bytes, shot: dict) -> dict:
    if hashlib.sha256(data).hexdigest() != shot["png_sha256"]:
        raise ToolError("image_changed", "PNG bytes changed since bundle verification")
    return {"bytes": len(data), "width": shot["width"], "height": shot["height"], "sha256": shot["png_sha256"]}


# ------------------------------------------------------------------ launcher adapter

def run_capture(launcher: Path, godot: str, pack_dir: Path, output_dir: Path, timeout: float,
                executables: dict[str, str], extra: list[str] | None = None) -> dict:
    """Invoke the #498 launcher on a workspace pack copy; map its documented contract."""
    launcher = Path(launcher)
    if launcher.name != LAUNCHER_NAME or not launcher.is_file():
        raise ConfigError(f"capture launcher must be an existing {LAUNCHER_NAME}", "launcher_unavailable")
    if not godot or not Path(godot).is_file():
        raise ConfigError("a Godot 4.7 executable path (task.godot) is required for rendering", "godot_unavailable")
    argv = [executables["python"], str(launcher), "--capture", f"--godot={godot}", "--pack", str(pack_dir),
            "--output-dir", str(output_dir), *(extra or [])]
    done = run_allowlisted(argv, pack_dir, timeout, 200_000, executables)
    result = None
    for line in done["stdout"].splitlines():
        if line.startswith("WORLD_ART_CAPTURE_RESULT "):
            try:
                result = json.loads(line.split(" ", 1)[1])
            except ValueError:
                result = None
    code = done["exit_code"]
    outcome = {"exit_code": code, "reason": LAUNCHER_EXIT.get(code, "unknown_exit"), "timed_out": done["timed_out"],
               "result_line_present": result is not None, "stderr_tail": done["stderr"][-600:]}
    if code != 0 or result is None or result.get("status") != "completed":
        outcome["status"] = "failed"
        return outcome
    outcome["status"] = "completed"
    outcome["bundle"] = result.get("bundle")
    return outcome
