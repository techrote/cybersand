#!/usr/bin/env python3
"""Offline, bounded side-by-side review of two existing REC-001 v2 sessions.

No native/Godot runtime access, mutation of input recordings, or replay claims.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import struct
from pathlib import Path

SCHEMA = "cybersand-state-recording-v2"
EVIDENCE = "simulation-state-evidence-not-exact-replay"
FRAME = re.compile(r"frame-([0-9]{6})\.json\Z")
MAX_FRAME_COUNT = 2_000
MAX_JSON_TOTAL_BYTES = 64 * 1024 * 1024
MAX_FRAME_BYTES = 2 * 1024 * 1024
MAX_ROI_CELLS = 1024 * 1024
MAX_COPY_BYTES = 64 * 1024 * 1024


class InvalidRecording(ValueError):
    """A recording cannot be represented without misleading the reviewer."""


def read_json(path: Path) -> dict:
    if path.is_symlink() or not path.is_file() or path.stat().st_size > MAX_FRAME_BYTES:
        raise InvalidRecording(f"missing, symlinked or oversized JSON: {path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (UnicodeError, ValueError) as exc:
        raise InvalidRecording(f"invalid JSON: {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise InvalidRecording(f"expected JSON object: {path}")
    return value


def positive_int(value: object, what: str, minimum: int = 0) -> int:
    if type(value) is not int or value < minimum:
        raise InvalidRecording(f"{what} must be integer >= {minimum}")
    return value


def safe_file(directory: Path, name: object, suffix: str) -> Path:
    if not isinstance(name, str) or not re.fullmatch(r"frame-[0-9]{6}" + re.escape(suffix), name):
        raise InvalidRecording(f"invalid frame {suffix} file name: {name!r}")
    path = directory / name
    if path.is_symlink() or not path.is_file():
        raise InvalidRecording(f"missing or symlinked recording file: {path}")
    return path


def session(directory: Path) -> dict:
    directory = directory.resolve(strict=True)
    manifest_path = directory / "recording.json"
    manifest = read_json(manifest_path)
    if manifest.get("schema_id") != SCHEMA or manifest.get("schema_version") != 2:
        raise InvalidRecording(f"unsupported schema in {manifest_path}")
    if manifest.get("evidence_kind") != EVIDENCE:
        raise InvalidRecording(f"not a REC-001 evidence stream: {manifest_path}")
    config = manifest.get("configuration")
    if not isinstance(config, dict) or not isinstance(config.get("roi"), list) or len(config["roi"]) != 4:
        raise InvalidRecording(f"missing fixed ROI in {manifest_path}")
    roi = tuple(config["roi"])
    if any(type(x) is not int for x in roi) or not (1 <= roi[2] and 1 <= roi[3]) or roi[2] * roi[3] > MAX_ROI_CELLS:
        raise InvalidRecording(f"invalid/oversized ROI in {manifest_path}")
    if config.get("retain_raw_ids") is not True:
        raise InvalidRecording(f"raw .ids needed to check material identity: {manifest_path}")
    files = sorted(p for p in directory.iterdir() if FRAME.fullmatch(p.name))
    if not files or len(files) > MAX_FRAME_COUNT:
        raise InvalidRecording(f"empty or excessive frame inventory: {directory}")
    if sum(p.stat().st_size for p in files) > MAX_JSON_TOTAL_BYTES:
        raise InvalidRecording(f"frame metadata inventory exceeds {MAX_JSON_TOTAL_BYTES} bytes: {directory}")
    frames = []
    prior_elapsed = -1
    for path in files:
        frame = read_json(path)
        idx = int(FRAME.fullmatch(path.name).group(1))
        if idx != len(frames) + 1 or frame.get("frame_index") != idx:
            raise InvalidRecording(f"noncontiguous or mismatched frame index: {path}")
        if frame.get("schema_id") != SCHEMA or frame.get("evidence_kind") != EVIDENCE:
            raise InvalidRecording(f"frame schema/evidence mismatch: {path}")
        if frame.get("recording_roi") != list(roi):
            raise InvalidRecording(f"frame ROI differs from session: {path}")
        elapsed = positive_int(frame.get("elapsed_monotonic_usec"), f"{path} elapsed")
        if elapsed < prior_elapsed:
            raise InvalidRecording(f"nonmonotonic capture elapsed time: {path}")
        prior_elapsed = elapsed
        material = frame.get("material_generation")
        actor = frame.get("actor_sample")
        if not isinstance(material, dict) or not isinstance(actor, dict):
            raise InvalidRecording(f"material and actor sample clocks required: {path}")
        material_tick = positive_int(material.get("completed_simulation_tick"), f"{path} material tick")
        actor_tick = positive_int(actor.get("completed_simulation_tick"), f"{path} actor tick")
        serial = positive_int(material.get("render_snapshot_serial"), f"{path} render serial")
        ids = safe_file(directory, frame.get("material_ids_file"), ".ids")
        bmp = safe_file(directory, frame.get("review_bitmap_file"), ".bmp")
        if ids.stem != path.stem or bmp.stem != path.stem:
            raise InvalidRecording(f"frame files do not match metadata index: {path}")
        if ids.stat().st_size != roi[2] * roi[3]:
            raise InvalidRecording(f"incorrect raw material byte count: {ids}")
        # Validate the REC-001 8-bit indexed BMP header without decoding the image.
        with bmp.open("rb") as stream:
            header = stream.read(54)
        if len(header) != 54 or header[:2] != b"BM" or struct.unpack_from("<I", header, 14)[0] != 40 or struct.unpack_from("<iiHH", header, 18) != (roi[2], roi[3], 1, 8):
            raise InvalidRecording(f"invalid REC-001 bitmap header: {bmp}")
        if bmp.stat().st_size != 1078 + ((roi[2] + 3) & ~3) * roi[3]:
            raise InvalidRecording(f"incorrect indexed bitmap size: {bmp}")
        frames.append({"index": idx, "elapsed_usec": elapsed, "material_tick": material_tick,
                       "actor_tick": actor_tick, "render_serial": serial,
                       "scenario": frame.get("scenario", {}), "worker_count": frame.get("worker_count"),
                       "water_policy_hash": frame.get("water_policy_hash"),
                       "transport_profile": frame.get("transport_profile"),
                       "player": frame.get("player", {}), "ids": ids, "bmp": bmp})
    counts = manifest.get("counters", {})
    written = counts.get("written_frames") if isinstance(counts, dict) else None
    if type(written) is not int or written != len(frames):
        raise InvalidRecording(f"manifest written_frames disagrees with frame inventory: {directory}")
    return {"directory": directory, "manifest": manifest, "manifest_sha256": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
            "roi": roi, "frames": frames}


def select(frames: list, limit: int) -> list:
    if len(frames) <= limit:
        return frames
    return [frames[(i * (len(frames) - 1)) // (limit - 1)] for i in range(limit)]


def identity(frame: dict) -> dict:
    scenario = frame["scenario"]
    if not isinstance(scenario, dict):
        return {}
    return {k: scenario.get(k) for k in ("id", "definition_hash", "seed", "mode", "source_recipe_hash")}


def compare(left: Path, right: Path, output: Path, max_frames: int = 96) -> dict:
    if not 2 <= max_frames <= 240:
        raise ValueError("max_frames must be 2..240")
    a, b = session(left), session(right)
    output = output.resolve()
    if output.exists() or any(output == s["directory"] or s["directory"] in output.parents for s in (a, b)):
        raise InvalidRecording("output must be new and outside both input sessions")
    same_roi = a["roi"] == b["roi"]
    same_scenario = identity(a["frames"][0]) == identity(b["frames"][0]) and bool(identity(a["frames"][0]).get("id"))
    stable = all(identity(f) == identity(s["frames"][0]) for s in (a, b) for f in s["frames"])
    comparable = same_roi and same_scenario and stable
    notes = []
    if not same_roi: notes.append("ROI coordinates/dimensions differ; no same-cell comparisons")
    if not same_scenario: notes.append("scenario identity/seed/recipe differs or unavailable")
    if not stable: notes.append("scenario identity changes within a session")
    for name, s in (("A", a), ("B", b)):
        if s["manifest"].get("disposition") != "complete":
            notes.append(f"{name} recording incomplete: {s['manifest'].get('incomplete_reason', 'unspecified')}")
        drops = s["manifest"].get("drops", {})
        if isinstance(drops, dict) and drops.get("omitted_count", 0):
            notes.append(f"{name} has omitted drop records; exact loss timing unavailable")
    selected = {"A": select(a["frames"], max_frames), "B": select(b["frames"], max_frames)}
    total_bytes = sum(f["bmp"].stat().st_size for records in selected.values() for f in records)
    if total_bytes > MAX_COPY_BYTES:
        raise InvalidRecording(f"selected BMP copy bytes {total_bytes} exceeds {MAX_COPY_BYTES} bound")
    # Only compute descriptive material differences at identical generation tick and
    # identical registered scenario/ROI. Capture wall time is NOT a parity clock.
    by_tick_a, by_tick_b = {}, {}
    for target, sess in ((by_tick_a, a), (by_tick_b, b)):
        for f in sess["frames"]:
            target.setdefault(f["material_tick"], []).append(f)
    differences = []
    if comparable:
        for tick, a_frames in by_tick_a.items():
            b_frames = by_tick_b.get(tick, [])
            if not b_frames:
                continue
            # Actor-only samples can repeat one immutable material generation;
            # tick reset can reuse a tick for DIFFERENT generations. Only compare
            # when each session has one unambiguous serial and raw payload.
            def unique_generation(frames):
                return len({(f["render_serial"], hashlib.sha256(f["ids"].read_bytes()).digest()) for f in frames}) == 1
            if not (unique_generation(a_frames) and unique_generation(b_frames)):
                notes.append(f"material tick {tick} ambiguous after a reset/republish; skipped")
                continue
            f, other = a_frames[0], b_frames[0]
            raw_a, raw_b = f["ids"].read_bytes(), other["ids"].read_bytes()
            differing = sum(x != y for x, y in zip(raw_a, raw_b))
            differences.append({"tick": tick, "A_frame": f["index"],
                                "B_frame": other["index"], "differing_material_cells": differing,
                                "total_cells": len(raw_a)})
    report = {
        "schema": "cybersand-rec001-offline-comparison-v1",
        "classification": "descriptive-observational-review-not-deterministic-replay-or-gameplay-acceptance",
        "capture_alignment": "elapsed from independent recording starts; never asserts synchronized control input",
        "same_scenario_and_roi": bool(comparable), "notes": notes,
        "matched_material_generation_ticks": differences,
        "sessions": {},
    }
    for name, s in (("A", a), ("B", b)):
        manifest = s["manifest"]
        report["sessions"][name] = {
            "original_manifest_sha256": s["manifest_sha256"], "identity": manifest.get("identity", {}),
            "disposition": manifest.get("disposition"), "incomplete_reason": manifest.get("incomplete_reason"),
            "configuration": manifest.get("configuration"), "roi": s["roi"],
            "recording_counters": manifest.get("counters", {}), "drops": manifest.get("drops", {}),
            "total_frames": len(s["frames"]), "selected_frames": len(selected[name]),
            "selected": [{"index": f["index"], "elapsed_usec": f["elapsed_usec"],
                           "material_tick": f["material_tick"], "actor_tick": f["actor_tick"],
                           "render_serial": f["render_serial"], "scenario": f["scenario"],
                           "worker_count": f["worker_count"], "water_policy_hash": f["water_policy_hash"],
                           "transport_profile": f["transport_profile"], "player": f["player"],
                           "bitmap": f"{name}/{f['bmp'].name}"} for f in selected[name]],
        }
    output.mkdir(parents=True)
    for name in ("A", "B"):
        (output / name).mkdir()
        for f in selected[name]:
            shutil.copyfile(f["bmp"], output / name / f["bmp"].name)
    (output / "comparison.json").write_text(json.dumps(report, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    (output / "index.html").write_text(render_html(report), encoding="utf-8")
    return report


def render_html(report: dict) -> str:
    serialized = json.dumps(report, ensure_ascii=True).replace("<", "\\u003c").replace(">", "\\u003e").replace("&", "\\u0026")
    return """<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CyberSand REC-001 evidence comparison</title>
<style>body{font:14px system-ui;background:#15191d;color:#e5e8ea;margin:24px}h1{font-size:22px}label{display:block;margin:14px 0}input{width:100%}
main{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:16px}section{background:#252b31;padding:14px;border-radius:6px}
img{width:100%;max-height:460px;object-fit:contain;image-rendering:pixelated;background:#080a0d}
pre{white-space:pre-wrap;overflow-wrap:anywhere;line-height:1.5}.note{color:#f1c37b}small{color:#adb8c4}</style>
<h1>REC-001 v2: independent session A/B review</h1>
<p class="note">Observational simulation-state evidence only; not deterministic replay, synchronized input, physical correctness or gameplay acceptance.
The slider selects the latest captured frame not later than elapsed time from EACH session's own start; it cannot correct startup phase, dropped captures or simulation drift.</p>
<label for="time">Elapsed recording time: <output id="seconds"></output> s<input id="time" type="range" min="0" step="0.001" value="0"></label>
<p id="warnings" class="note"></p><main><section><h2>Session A</h2><img id="imageA" alt="A captured material state"><pre id="metaA"></pre></section>
<section><h2>Session B</h2><img id="imageB" alt="B captured material state"><pre id="metaB"></pre></section></main>
<p><a href="comparison.json" style="color:#a9d4ff">Full source, configuration, drop and same-tick material-difference record (JSON)</a></p>
<script>const data=""" + serialized + """;
const sessions=data.sessions;const timeline=document.getElementById('time');
const ends=['A','B'].map(k=>sessions[k].selected.at(-1).elapsed_usec/1e6);timeline.max=Math.min(...ends).toFixed(3);
document.getElementById('warnings').textContent=data.notes.join(' | ')||'No structural mismatch detected. Source/runtime/profile differences still require experimental control.';
function paint(){const t=Number(timeline.value);document.getElementById('seconds').value=t.toFixed(3);
for(const k of ['A','B']){const frames=sessions[k].selected;let f=null;
for(const candidate of frames){if(candidate.elapsed_usec/1e6<=t+1e-9)f=candidate;else break;}
const image=document.getElementById('image'+k),label=document.getElementById('meta'+k);
if(!f){image.removeAttribute('src');label.textContent='No retained frame yet at this elapsed time';continue;}
image.src=f.bitmap;
const age=t-f.elapsed_usec/1e6;
label.textContent='Frame '+f.index+' | capture age '+age.toFixed(3)+'s (may include drops/downsampling)'
+'\\nActor sample tick '+f.actor_tick+' | material generation tick '+f.material_tick+' | render serial '+f.render_serial
+'\\nWorker capacity hint '+f.worker_count+' | scenario '+(f.scenario?.id||'unavailable')
+'\\nDisposition '+sessions[k].disposition+' | captured '+sessions[k].total_frames+', selected '+sessions[k].selected_frames+' | dropped '+(sessions[k].recording_counters?.dropped_frames??'unavailable');
}}
timeline.addEventListener('input',paint);paint();</script></html>"""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("session_a", type=Path)
    ap.add_argument("session_b", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument("--max-frames", type=int, default=96)
    args = ap.parse_args()
    try:
        result = compare(args.session_a, args.session_b, args.output, args.max_frames)
    except (InvalidRecording, OSError, ValueError) as exc:
        ap.error(str(exc))
    print(json.dumps({"output": str(args.output), "matched_generation_ticks": len(result["matched_material_generation_ticks"]),
                      "notes": result["notes"]}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
