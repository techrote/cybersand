#!/usr/bin/env python3
"""Source-authenticated ordinary render production qualification.

Each invocation uses one source-selected policy and its installed published
runtime. It never swaps libraries, selects an E policy, edits manifests or ACKs
on the consumer's behalf. A declared, hashed test/seam overlay is permitted for
paired controls and is always reported as a local source delta.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import signal
import subprocess
import sys
import time
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/ci"))
from execution_policy import identity as execution_identity, watchdog_seconds

VERSION = "4.7.stable.official.5b4e0cb0f"
VARIANTS = ("control", "E", "R", "ER")
NATIVE_SUFFIXES = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".tpp"}
HARNESS_PATHS = {
    "godot/tests/bench_render_production.gd",
    "godot/tests/support/render_production_consumer.gd",
    "godot/tests/support/render_production_worker.gd",
    "tools/render_copy/run_production_campaign.py", "tools/render_copy/test_production_reader.py",
    "godot/tests/support/render_copy_consumer.gd", "godot/tests/support/render_copy_worker.gd",
    "godot/tests/support/render_copy_trace.gd",
}
SEAM_PATHS = {"godot/scripts/main.gd", "godot/scripts/simulation_worker.gd"}
DEFAULT_COHORTS = ("paused:N:0", "play:N:0", "play:W:0", "play:N:50000")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "duplicate JSON key: " + key)
        result[key] = value
    return result


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"), object_pairs_hook=unique_object)


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2, allow_nan=False) + "\n", encoding="utf-8")


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], timeout=watchdog_seconds("operation_seconds"))


def git_value(ref):
    return git("rev-parse", "--verify", ref).decode().strip()


def blobs(commit, paths):
    require(bool(re.fullmatch(r"[0-9a-f]{40}", commit)), "full source SHA required")
    paths = sorted(paths)
    require(all(not Path(p).is_absolute() and ".." not in Path(p).parts and "\n" not in p for p in paths), "unsafe Git input path")
    raw = subprocess.check_output(["git", "-C", str(ROOT), "cat-file", "--batch"],
        input="".join(f"{commit}:{p}\n" for p in paths).encode(), timeout=watchdog_seconds("operation_seconds"))
    output, offset = {}, 0
    for path in paths:
        end = raw.index(b"\n", offset)
        fields = raw[offset:end].split()
        require(len(fields) == 3 and fields[1] == b"blob", "missing canonical blob: " + path)
        size = int(fields[2])
        output[path] = raw[end + 1:end + 1 + size]
        require(len(output[path]) == size and raw[end + size + 1:end + size + 2] == b"\n", "truncated canonical blob")
        offset = end + size + 2
    require(offset == len(raw), "unexpected Git response tail")
    return output


def tracked(commit):
    return set(filter(None, git("ls-tree", "-rz", "--name-only", commit).decode().split("\0")))


def native_roster(commit):
    return {p for p in tracked(commit) if p.startswith(("native/include/", "native/src/", "godot/native_extension/"))
            and Path(p).suffix in NATIVE_SUFFIXES}


def authenticate_engine(engine, archive):
    require(platform.system() in ("Linux", "Windows"), "only actual Linux/Windows hosts supported")
    version = subprocess.check_output([str(engine), "--version"], text=True,
        timeout=watchdog_seconds("operation_seconds")).strip()
    require(version == VERSION, "engine version differs from pinned Godot")
    if platform.system() == "Linux":
        lock = read_json(ROOT / "third_party/godot-runtime.lock.json")["editor"]
        require(digest(archive) == lock["sha256"] and archive.stat().st_size == lock["size"], "Linux engine archive differs from lock")
    else:
        # Use the canonical Windows runner pin, not a second handwritten hash.
        import run_windows_godot_regressions as windows
        require(hashlib.sha512(archive.read_bytes()).hexdigest() == windows.GODOT_SHA512, "Windows engine archive differs from canonical runner pin")
    with zipfile.ZipFile(archive) as bundle:
        require(bundle.testzip() is None, "engine archive CRC failed")
        matches = [name for name in bundle.namelist() if Path(name).name == engine.name]
        require(len(matches) == 1 and hashlib.sha256(bundle.read(matches[0])).hexdigest() == digest(engine),
                "executed engine bytes differ from authenticated archive")
        runtime_executable = engine
        if platform.system() == "Windows":
            runtime_executable = engine.with_name("Godot_v4.7-stable_win64.exe")
            names = [name for name in bundle.namelist() if Path(name).name == runtime_executable.name]
            require(len(names) == 1 and hashlib.sha256(bundle.read(names[0])).hexdigest() == digest(runtime_executable),
                    "Windows engine runtime differs from authenticated archive")
    return {"version": version, "path": str(engine), "sha256": digest(engine),
            "runtime_executable_path": str(runtime_executable), "runtime_executable_sha256": digest(runtime_executable),
            "archive_path": str(archive), "archive_sha256": digest(archive)}


def authenticate_runtime(head):
    suffix = "windows" if platform.system() == "Windows" else "linux"
    manifest_path = "godot/addons/cybersand_native/" + ("runtime-provenance.json" if suffix == "windows" else "runtime-provenance.linux.json")
    committed = blobs(head, [manifest_path])[manifest_path]
    require((ROOT / manifest_path).read_bytes().replace(b"\r\n", b"\n") == committed, "published runtime manifest has local edits")
    manifest = json.loads(committed, object_pairs_hook=unique_object)
    source = manifest["source_commit"]
    require(manifest["source_tree"] == git_value(source + "^{tree}"), "runtime source tree differs from Git")
    roster = native_roster(head)
    require(roster and set(manifest["source_inputs"]) == roster == native_roster(source), "runtime native source roster incomplete")
    historical = blobs(source, roster | set(manifest.get("build_inputs", {})))
    current = blobs(head, roster)
    for path, expected in manifest["source_inputs"].items():
        require(hashlib.sha256(historical[path]).hexdigest() == expected, "runtime historical native input mismatch: " + path)
        require(hashlib.sha256(current[path]).hexdigest() == expected, "runtime requires rebuild for proposed native source: " + path)
        require((ROOT / path).read_bytes().replace(b"\r\n", b"\n") == current[path], "dirty native source: " + path)
    for path, expected in manifest.get("build_inputs", {}).items():
        require(hashlib.sha256(historical[path]).hexdigest() == expected, "historical build ledger mismatch: " + path)
    artifact = ROOT / manifest["artifact"]
    require(digest(artifact) == manifest["sha256"] and artifact.stat().st_size == manifest["size"], "installed runtime bytes differ from published manifest")
    pointer = blobs(head, [manifest["artifact"]])[manifest["artifact"]]
    require(pointer == f"version https://git-lfs.github.com/spec/v1\noid sha256:{manifest['sha256']}\nsize {manifest['size']}\n".encode(), "published native LFS pointer mismatch")
    rapier_path = f"godot/addons/godot-rapier2d/runtime-provenance.{suffix}.json"
    rapier_blob = blobs(head, [rapier_path])[rapier_path]
    require((ROOT / rapier_path).read_bytes().replace(b"\r\n", b"\n") == rapier_blob, "dirty Rapier provenance")
    rapier = json.loads(rapier_blob, object_pairs_hook=unique_object)
    require(digest(ROOT / rapier["artifact"]) == rapier["sha256"], "installed Rapier bytes differ from provenance")
    return {"path": str(artifact), "sha256": manifest["sha256"], "size": manifest["size"],
            "source_commit": source, "source_tree": manifest["source_tree"],
            "manifest_sha256": hashlib.sha256(committed).hexdigest(),
            "complete_native_inputs": manifest["source_inputs"],
            "historical_build_input_count": len(manifest.get("build_inputs", {})),
            "historical_build_scope": "Original source execution only; changed host/tests are qualified by this campaign.",
            "toolchain": manifest.get("toolchain"), "rapier_sha256": rapier["sha256"],
            "rapier_manifest_sha256": hashlib.sha256(rapier_blob).hexdigest()}


def source_identity(expected, overlay_path=None):
    head = git_value("HEAD")
    require(head == expected, "checkout advanced from expected source")
    paths = tracked(head)
    selected = {p for p in paths if (p.startswith("godot/") and Path(p).suffix in
        {".gd", ".tscn", ".tres", ".gdshader", ".gdextension", ".json", ".svg", ".png", ".jpg", ".jpeg"}) or p.startswith("tools/render_copy/")
        or p in {"godot/project.godot", "godot/tests/support/ci_execution_policy.json",
            "third_party/godot-runtime.lock.json", "third_party/native-toolchain.lock.json",
            "tools/ci/execution_policy.py", "tools/ci/run_windows_godot_regressions.py"}}
    canonical = blobs(head, selected)
    overlay = {}
    if overlay_path:
        document = read_json(overlay_path)
        require(document.get("schema") == "render-production-harness-overlay-v1" and document.get("source_sha") == head,
                "overlay is not bound to exact production source")
        overlay = document.get("files", {})
        require(isinstance(overlay, dict) and overlay and set(overlay).issubset(HARNESS_PATHS | SEAM_PATHS), "overlay includes non-harness/non-seam paths")
        require(bool(document.get("reviewed_scope")), "overlay must declare reviewed observation-seam scope")
    hashes, deltas = {}, {}
    for path in sorted(selected | HARNESS_PATHS):
        require((ROOT / path).is_file(), "required source/harness path missing: " + path)
        data = (ROOT / path).read_bytes()
        if Path(path).suffix not in {".png", ".jpg", ".jpeg"}:
            data = data.replace(b"\r\n", b"\n")
        value = hashlib.sha256(data).hexdigest()
        hashes[path] = value
        if path in overlay:
            require(value == overlay[path], "sealed overlay changed: " + path)
            if canonical.get(path) != data:
                deltas[path] = {"base_sha256": hashlib.sha256(canonical[path]).hexdigest() if path in canonical else None,
                                "tested_sha256": value}
        else:
            require(path in canonical and canonical[path] == data, "undeclared host/harness source delta: " + path)
    require(set(overlay).issubset(hashes), "unused overlay path")
    return {"head": head, "tree": git_value(head + "^{tree}"), "source_hashes": hashes,
            "declared_test_overlay": deltas, "overlay_manifest_sha256": digest(overlay_path) if overlay_path else None,
            "source_scope": "exact committed source" if not deltas else "exact production source plus explicitly declared qualification overlay",
            "platform": platform.platform(), "machine": platform.machine(), "logical_cpus": os.cpu_count(),
            "environment": {k: os.environ.get(k) for k in ("DISPLAY", "LIBGL_ALWAYS_SOFTWARE", "LP_NUM_THREADS", "GALLIVM_PERF")}}


def percentiles(values):
    require(all(isinstance(v, (int, float)) and math.isfinite(v) and v >= 0 for v in values), "invalid timing population")
    values = sorted(values)
    return {"n": len(values), **({label: values[min(len(values)-1, math.ceil(len(values)*q)-1)]
        for label, q in (("p50", .5), ("p95", .95), ("p99", .99), ("max", 1))} if values else {})}


def graphics_classification(adapter):
    if re.search(r"llvmpipe|softpipe|swiftshader|basic render|software|GDI Generic|lavapipe", adapter, re.I):
        return "software"
    if re.search(r"NVIDIA|GeForce|Quadro|TITAN|Radeon|Intel.*(?:Arc|Iris|UHD|HD Graphics)", adapter, re.I):
        return "hardware_adapter_reported"
    return "unclassified"


def reduce_trace(data):
    require(data.get("schema") == "render-production-graphical-v1" and data.get("schema_version") == 1, "unknown receipt schema")
    require(data.get("variant") in VARIANTS and data.get("workload") in ("paused", "play") and data.get("arm") in ("N", "W"), "unknown source/workload/ACK label")
    require(data.get("display") not in (None, "", "headless"), "non-graphical process")
    require(re.fullmatch(r"[0-9a-f]{64}", data.get("runtime_sha256", "")), "missing runtime identity")
    require(data.get("owner_script") == "res://tests/support/render_production_worker.gd"
            and data.get("consumer_script") == "res://tests/support/render_production_consumer.gd", "wrong owner/consumer")
    require(data.get("failures") == 0 and data.get("assertions", 0) > 0 and data.get("dropped") == 0, "failed or truncated process")
    require(data.get("final_cpu_native_equal") is True and data.get("final_texture_image_equal") is True
            and data.get("final_marker_equal") is True, "final native/CPU/texture/marker mismatch")
    require(data.get("final_oracle_after_join") is True and data.get("post_join_consumer_calls") == 0, "post-join consumer repair is forbidden")
    require(data.get("gpu_completion_latency_measured") is False and data.get("human_pacing_qualified") is False,
            "unsupported GPU-completion or human claim")
    events, counts = data["events"], data["counts"]
    require([e["event_sequence"] for e in events] == list(range(1, len(events)+1)), "event sequence gap/reorder")
    require(all(isinstance(e["usec"], (int, float)) and math.isfinite(e["usec"]) and e["usec"] >= 0 for e in events), "invalid event clock")
    require(Counter(e["event"] for e in events) == counts, "event/counter mismatch")
    def select(kind):
        return [e for e in events if e["event"] == kind]
    require(data.get("png_error") == 0 and counts.get("texture_success", 0) > 10 and counts.get("reject", 0) == 0, "unexpected rejection or missing upload population")
    frames = data["frame_count"]
    require(type(frames) is int and 120 <= frames <= 600 and frames % 4 == 0, "invalid measured window")
    starts, ends = select("frame_begin"), select("frame_end")
    require(len(starts) == len(ends) == len(data["frame_usec"]) == frames, "incomplete measured frames")
    for i, (start, end, duration) in enumerate(zip(starts, ends, data["frame_usec"])):
        require(start["frame"] == end["frame"] == i and start["start_usec"] == end["start_usec"]
                and end["end_usec"] - end["start_usec"] == end["duration_usec"] == duration and duration >= 0,
                "unpaired frame duration")
    emissions, resets = select("emission_queued"), select("reset_request")
    require(len(emissions) == data["accepted_pulses"] == frames//2 and len(resets) == 1
            and resets[0]["frame"] == frames//2, "incomplete registered mutation/reset workload")
    for i, event in enumerate(emissions):
        require(event.get("frame") == i*2 and event.get("x") == 400+i%120 and event.get("y") == 250
                and event.get("material") == (3 if i%2 == 0 else 2) and event.get("accepted") is True,
                "mutation differs from registered workload")
    require(resets[0]["event_sequence"] < emissions[frames//4]["event_sequence"], "reset ordering incorrect")
    markers = select("tail_marker_queued")
    require(len(markers) == 1 and markers[0].get("accepted") is True
            and (markers[0].get("x"), markers[0].get("y"), markers[0].get("material")) == (900, 32, 31), "final marker missing")
    tail_starts, tails, joins = select("tail_begin"), select("tail_caught_up"), select("owner_joined")
    require(data.get("tail_drained") is True and len(tail_starts) == len(tails) == len(joins) == 1, "ordinary tail missing")
    tail = tails[0]
    require(tail["owner_count"] >= tail_starts[0]["owner_count"]+2
            and tail["revision"] == tail["simulation_revision"] == tail["uploaded_revision"]
            and tail["generation"] == tail["uploaded_generation"]
            and tail["uploaded_serial"] >= tail["render_serial"]
            and tail["event_sequence"] < joins[0]["event_sequence"] and joins[0].get("thread_started") is False,
            "worker joined before ordinary consumer catch-up")
    require(not any(e["event_sequence"] > joins[0]["event_sequence"] for e in select("render_consume")), "consumer repaired image after owner join")
    native, begins, owner_ends = select("native_end"), select("native_begin"), select("owner_end")
    keys = [(e["refresh"], e["call"]) for e in native]
    require(keys and len(keys) == len(set(keys)) and sorted(keys) == sorted((e["refresh"], e["call"]) for e in begins), "native call pairing incomplete")
    for call in native:
        require(call["call"] in (1, 2) and call["end_usec"] - call["start_usec"] == call["duration_usec"]
                and call["duration_usec"] >= 0, "invalid native call timing")
        require(sum(e["refresh"] == call["refresh"] for e in owner_ends) == 1, "missing owner completion")
    generations = []
    for call in native:
        if call["generation"] not in generations:
            require(call["complete_full"] is True, "new World did not begin with complete full packet")
            require(not generations or call["generation"] > generations[-1], "World generation regressed")
            generations.append(call["generation"])
    require(len(generations) >= (3 if data["workload"] == "play" else 2), "missing startup/replacement generation")
    require(tail["generation"] == generations[-1] and generations[-1] > resets[0]["generation"], "reset never reached final consumer")
    append_ends = select("production_append_end")
    append_begins = select("production_append_begin")
    require(len(append_begins) == len(append_ends) == len(native), "append observation population incomplete")
    for begin, end in zip(append_begins, append_ends):
        require(all(begin.get(key) == end.get(key) for key in begin if key not in ("event", "event_sequence", "usec")),
                "append observation identity changed")
        if end.get("observer_accounting") == "constant-time-full-tag-v2":
            before = end["before"]
            raw_bytes = int(before["bytes"]) + end["packet_bytes"]
            raw_rectangles = int(before["rectangles"]) + end["packet_rectangles"]
            baseline = 1024*1024*int(before["channels"]) if end["observed_complete_baseline"] else 0
            if baseline:
                require(before["channels"] in (1, 2) and before["full"] is True
                        and before["generation"] == before["render_generation"] and before["bytes"] >= baseline,
                        "observer full tag contradicts retained state")
            require(end["predicted_raw_bytes"] == raw_bytes and end["predicted_raw_rectangles"] == raw_rectangles
                    and end["predicted_e_charged_bytes"] == raw_bytes-baseline
                    and end["predicted_e_charged_rectangles"] == raw_rectangles-int(bool(baseline)),
                    "observer capacity accounting differs from packet and retained state")
        else:
            # Retained pre-correction smoke receipts remain readable with their
            # explicitly source-bound older observation cost, never relabeled v2.
            require("observer_accounting" not in end, "unknown observer accounting schema")
    retry_causes = []
    for call in [e for e in native if e["call"] == 2]:
        attempts = [e for e in append_ends if e["refresh"] == call["refresh"]]
        require(len(attempts) == 2 and not attempts[0]["packet_full"] and call["force_full"] is True,
                "unexplained full retry")
        attempt = attempts[0]
        if attempt.get("observer_accounting") == "constant-time-full-tag-v2":
            # The same observer computes both costs in every source arm. Only
            # readback selects the declared source's accounting interpretation.
            prefix = "predicted_e_charged_" if data["variant"] in ("E", "ER") else "predicted_raw_"
            byte_overflow = attempt[prefix + "bytes"] > 2097152
            rect_overflow = attempt[prefix + "rectangles"] > 256
            preflight = not attempt["accepted"]
            require(byte_overflow or rect_overflow, "retry has no independently observed budget cause")
        else:
            byte_overflow = attempt["predicted_charged_bytes"] > 2097152
            rect_overflow = attempt["predicted_charged_rectangles"] > 256
            preflight = attempt["recovery_required"]
            require(byte_overflow or rect_overflow or preflight, "retry has no retained-capacity/recovery cause")
        retry_causes.append({"refresh": call["refresh"], "byte": byte_overflow,
                             "rectangles": rect_overflow, "preflight": preflight})
    full_count = sum(e["packet_full"] and e["packet_bytes"] > 0 for e in native)
    require(counts.get("refresh", 0) == sum(e["call"] == 1 for e in native)
            and counts.get("forced_retry", 0) == len(retry_causes)
            and counts.get("full_publication", 0) == full_count, "native/full/retry counters disagree")
    observed_high = max((int(e["after"]["bytes"]) for e in append_ends), default=0)
    observed_rect_high = max((int(e["after"]["rectangles"]) for e in append_ends), default=0)
    require(observed_high == data["pending_high_water"] and observed_rect_high == data["pending_rectangle_high_water"], "pending high-water differs from events")
    if data["variant"] in ("E", "ER"):
        require(observed_high <= 4194304 and observed_rect_high <= 257, "E retained storage exceeds baseline-plus-dirty bound")
    durations = {}
    for begin, end, label in (("validation_begin", "validation_end", "validation_usec"),
            ("patch_begin", "patch_end", "patch_including_validation_usec"),
            ("texture_update_begin", "texture_update_end", "texture_update_call_usec"),
            ("texture_begin", "texture_success", "texture_submission_usec")):
        a, b = select(begin), select(end)
        require(len(a) == len(b), "unpaired consumer timing: " + label)
        require(all(x.get("serial") == y.get("serial") and x.get("generation") == y.get("generation") for x, y in zip(a, b)), "consumer identity changed during operation")
        durations[label] = percentiles([y["usec"]-x["usec"] for x, y in zip(a, b)])
    a, b, c, d = select("patch_begin"), select("patch_end"), select("validation_begin"), select("validation_end")
    require(len(a) == len(c) and all(x["usec"] <= z["usec"] <= w["usec"] <= y["usec"]
            and x["serial"] == z["serial"] and x["generation"] == z["generation"] for x, y, z, w in zip(a, b, c, d)), "patch/validation nesting invalid")
    durations["cpu_patch_usec"] = percentiles([(y["usec"]-x["usec"])-(w["usec"]-z["usec"]) for x, y, z, w in zip(a, b, c, d)])
    successes = select("texture_success") + select("texture_create_success")
    issued, withheld, observed, clears = select("ack_issue"), select("ack_withheld"), select("ack_observed"), select("ack_clear")
    for ack in issued + withheld:
        require(any(e["serial"] == ack["serial"] and e["usec"] < ack["usec"] for e in successes), "ACK issued before successful upload")
    require((not issued and not clears and bool(withheld)) if data["arm"] == "W" else bool(issued), "ACK arm differs from declared control")
    observations, clear_latencies, censored = [], [], 0
    for ack in issued:
        later = [e for e in observed if e["ack_serial"] >= ack["serial"] and e["usec"] >= ack["usec"]]
        if later:
            observations.append(later[0]["usec"]-ack["usec"])
        else:
            censored += 1
    for clear in clears:
        eligible = [e for e in issued if e["serial"] == clear["ack_serial"] and e["usec"] <= clear["usec"]]
        require(eligible and clear["ack_serial"] >= clear["pending_serial"], "clear lacks ordinary covering ACK")
        clear_latencies.append(clear["usec"]-eligible[-1]["usec"])
    lifecycle = data["lifecycle"]
    require([{k: v for k, v in e.items() if k not in ("event", "usec", "event_sequence")} for e in select("play_lifecycle")] == lifecycle, "PLAY lifecycle summary differs from events")
    if data["workload"] == "play":
        require([r["kind"] for r in lifecycle] == ["installed", "before_reset", "reset_installed", "active_end"], "incomplete active PLAY lifecycle")
        for start, end in (lifecycle[:2], lifecycle[2:]):
            require(end["native_tick"] > start["native_tick"] and end["physics_tick"] > start["physics_tick"]
                    and start["generation"] == end["generation"] and start["epoch"] == end["epoch"], "PLAY native/Rapier clocks did not both progress")
        require(lifecycle[2]["generation"] > lifecycle[0]["generation"] and lifecycle[2]["epoch"] > lifecycle[0]["epoch"], "PLAY reset did not replace owners")
        require(all(r["rig"] == "jetbarrel" and r["recipe_hash"] for r in lifecycle)
                and len({r["recipe_hash"] for r in lifecycle}) == 1, "authored PLAY identity drift")
    else:
        require(not lifecycle, "paused workload contains unregistered PLAY lifecycle")
    cadence = data["consumer_interval_usec"]
    require(cadence in (0, 50000), "unknown consumer cadence")
    if cadence:
        require(counts.get("consumer_delayed", 0) > 0, "slow-consumer arm never delayed consumption")
    refreshes = counts["refresh"]
    return {"counts": counts, "retry_causes": retry_causes, "generations": generations,
            "counts_per_refresh": {"forced_retry": len(retry_causes)/refreshes,
                "full_publication": full_count/refreshes, "ack_clear": len(clears)/refreshes},
            "native_exchanged_bytes": sum(e["packet_bytes"] for e in native),
            "native_bytes_per_refresh": sum(e["packet_bytes"] for e in native)/refreshes,
            "pending_high_water": observed_high, "pending_rectangle_high_water": observed_rect_high,
            "native_exchange_usec": percentiles([e["duration_usec"] for e in native]),
            "native_full_usec": percentiles([e["duration_usec"] for e in native if e["packet_full"]]),
            "worker_publication_usec": percentiles([e["duration_usec"] for e in owner_ends if e["calls"] > 0]),
            "frame_usec": percentiles(data["frame_usec"]), "ack_issue_to_observation_usec": percentiles(observations),
            "ack_issue_to_clear_usec": percentiles(clear_latencies), "ack_unobserved_at_end": censored,
            "ack_nonclearing_observations": sum(not e["will_clear"] for e in observed),
            "ack_stale_observations": counts.get("ack_stale", 0), "rejected_snapshots": counts.get("reject", 0),
            "tail_usec": data["tail_elapsed_usec"], "frame_intervals_exclude_tail": True,
            "graphics_classification": graphics_classification(data["adapter"]), **durations}


def parse_cohort(value):
    fields = value.split(":")
    require(len(fields) == 3 and fields[0] in ("paused", "play") and fields[1] in ("N", "W")
            and fields[2] in ("0", "50000"), "cohort must be paused/play:N/W:0/50000")
    return {"workload": fields[0], "arm": fields[1], "consumer_usec": int(fields[2])}


class CampaignInterrupted(BaseException):
    """An actually started cell, with retained evidence and completed cleanup."""
    def __init__(self, row, cause):
        self.row = row
        self.cause = cause
        super().__init__(f"{type(cause).__name__}: {cause}")


def terminate_process_tree(process):
    """Retire only this campaign's separately grouped child and descendants."""
    grace = watchdog_seconds("terminate_grace_seconds")
    result = {"required": True, "forced": False, "pid": process.pid, "errors": []}
    # A second Ctrl-C must not interrupt the bounded reap and leave the engine
    # alive. Restore the caller's handler as soon as cleanup completes.
    old_handler = signal.signal(signal.SIGINT, signal.SIG_IGN)
    try:
        def send(force):
            if os.name == "nt":
                # The Godot console executable can own a separate runtime EXE.
                argv = ["taskkill", "/PID", str(process.pid), "/T"] + (["/F"] if force else [])
                try:
                    killed = subprocess.run(argv, capture_output=True, text=True, timeout=grace)
                    if killed.returncode != 0:
                        result["errors"].append(killed.stderr.strip() or killed.stdout.strip())
                except (OSError, subprocess.TimeoutExpired) as error:
                    result["errors"].append(f"{type(error).__name__}: {error}")
            else:
                try:
                    os.killpg(process.pid, signal.SIGKILL if force else signal.SIGTERM)
                except ProcessLookupError:
                    pass
        send(False)
        try:
            process.wait(timeout=grace)
        except subprocess.TimeoutExpired:
            result["forced"] = True
            send(True)
            process.wait(timeout=grace)
        # A console wrapper or helper may exit before its descendants. The
        # separately owned POSIX group remains safe to retire after its leader.
        if os.name != "nt":
            send(True)
        result["returncode"] = process.poll()
        require(result["returncode"] is not None, "campaign child was not reaped")
        return result
    finally:
        signal.signal(signal.SIGINT, old_handler)


def run_process(engine, output, variant, cohort, frames, runtime, engine_args):
    receipt = output.with_suffix(".json")
    log_path = output.with_suffix(".log")
    argv = [str(engine), "--audio-driver", "Dummy", "--path", str(ROOT / "godot"), "--resolution", "960x540",
        *engine_args, "--script", "res://tests/bench_render_production.gd", "--", f"--receipt={receipt}",
        f"--variant={variant}", f"--workload={cohort['workload']}", f"--arm={cohort['arm']}",
        f"--consumer-usec={cohort['consumer_usec']}", f"--frames={frames}",
        f"--runtime-path={runtime['path']}", f"--runtime-sha256={runtime['sha256']}"]
    started = time.monotonic()
    interruption = None
    cleanup = {"required": False}
    state_path = Path(str(output) + ".process.json")
    with log_path.open("xb") as log:
        options = {"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP} if os.name == "nt" else {"start_new_session": True}
        process = subprocess.Popen(argv, stdout=log, stderr=subprocess.STDOUT, **options)
        try:
            write_json(state_path, {"state": "started", "process_started": True, "process_id": process.pid,
                "variant": variant, **cohort, "argv": argv, "log_path": str(log_path)})
            code = process.wait(timeout=watchdog_seconds("graphical_case_seconds"))
        except subprocess.TimeoutExpired:
            code = "timeout"
            cleanup = terminate_process_tree(process)
        except BaseException as error:
            interruption = error
            code = "interrupted"
            cleanup = terminate_process_tree(process)
        finally:
            if process.poll() is None:
                cleanup = terminate_process_tree(process)
    row = {"variant": variant, **cohort, "argv": argv, "exit": code, "process_id": process.pid,
        "seconds": time.monotonic()-started, "log_path": str(log_path), "log_sha256": digest(log_path),
        "process_started": True, "state": "interrupted" if interruption else "timeout" if code == "timeout" else "completed",
        "cleanup": cleanup, "process_record": str(state_path)}
    errors = []
    log_text = log_path.read_text(encoding="utf-8", errors="replace")
    if "SCRIPT ERROR:" in log_text or "ERROR:" in log_text:
        errors.append("engine error in original log")
    if receipt.is_file():
        row.update(receipt_path=str(receipt), receipt_sha256=digest(receipt))
        try:
            raw = read_json(receipt)
            require(raw["variant"] == variant and raw["workload"] == cohort["workload"] and raw["arm"] == cohort["arm"]
                    and raw["consumer_interval_usec"] == cohort["consumer_usec"] and raw["frame_count"] == frames, "process differs from registered cell")
            require(raw["process_id"] == process.pid and raw["runtime_sha256"] == runtime["sha256"], "process/runtime receipt identity mismatch")
            row["summary"] = reduce_trace(raw)
            row["graphics"] = {k: raw[k] for k in ("display", "renderer", "adapter", "os", "engine")}
        except (ValueError, KeyError, TypeError, StopIteration) as error:
            errors.append(str(error))
        png = Path(str(receipt) + ".png")
        if png.is_file():
            row.update(png_path=str(png), png_sha256=digest(png))
        else:
            errors.append("framebuffer witness missing")
    else:
        errors.append("fresh receipt missing")
    if errors:
        row["reader_failure"] = errors
    if interruption is not None:
        row["interruption"] = f"{type(interruption).__name__}: {interruption}"
    write_json(state_path, row)
    if interruption is not None:
        raise CampaignInterrupted(row, interruption) from interruption
    return row


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--engine-archive", type=Path, required=True)
    parser.add_argument("--expected-source", required=True)
    parser.add_argument("--variant", choices=VARIANTS, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--overlay-manifest", type=Path)
    parser.add_argument("--cohort", action="append", help="Repeat for explicit workload:ACK:consumer-usec cells.")
    parser.add_argument("--repeats", type=int, default=3)
    parser.add_argument("--frames", type=int, default=240)
    parser.add_argument("--require-hardware", action="store_true")
    parser.add_argument("--engine-arg", action="append", default=[])
    args = parser.parse_args()
    require(1 <= args.repeats <= 5, "require one to five explicit fresh-process repeats")
    require(120 <= args.frames <= 600 and args.frames % 4 == 0, "invalid frame window")
    forbidden = ("--headless", "--script", "--path", "--editor", "--quit")
    require(not any(a == flag or a.startswith(flag + "=") for a in args.engine_arg for flag in forbidden),
            "engine arguments cannot replace the graphical fixture, project or execution mode")
    args.engine, args.engine_archive, args.output = args.engine.resolve(), args.engine_archive.resolve(), args.output.resolve()
    cohorts = [parse_cohort(value) for value in (args.cohort or DEFAULT_COHORTS)]
    require(len({tuple(c.values()) for c in cohorts}) == len(cohorts), "duplicate cohort")
    plan = [{**cell, "repeat": repeat, "sequence": repeat*len(cohorts)+i+1}
        for repeat in range(args.repeats) for i, cell in enumerate(cohorts if repeat%2 == 0 else list(reversed(cohorts)))]
    args.output.mkdir(parents=True, exist_ok=False)
    rows, fatal = [], None
    report = {"schema": "render-production-campaign-v1", "variant": args.variant, "planned_processes": plan,
        "status": "failed", "execution_policy": execution_identity(), "require_hardware": args.require_hardware,
        "gpu_completion_latency_measured": False, "human_pacing_qualified": False,
        "scope": "Ordinary source-selected production path; actual graphical submission/readback and CPU frame intervals."}
    try:
        identity = source_identity(args.expected_source, args.overlay_manifest)
        engine = authenticate_engine(args.engine, args.engine_archive)
        runtime = authenticate_runtime(args.expected_source)
        report.update(source=identity, engine=engine, runtime=runtime)
        write_json(args.output / "inputs.json", report)
        for cell in plan:
            name = f"{cell['sequence']:02d}-{args.variant}-{cell['workload']}-{cell['arm']}-{cell['consumer_usec']}"
            try:
                row = run_process(args.engine, args.output / name, args.variant, cell, args.frames, runtime, args.engine_arg)
            except CampaignInterrupted as error:
                error.row.update(repeat=cell["repeat"], sequence=cell["sequence"])
                rows.append(error.row)
                write_json(args.output / "processes.json", rows)
                raise
            row.update(repeat=cell["repeat"], sequence=cell["sequence"])
            if args.require_hardware and row.get("summary", {}).get("graphics_classification") != "hardware_adapter_reported":
                row.setdefault("reader_failure", []).append("required hardware adapter was not reported")
            rows.append(row)
            write_json(args.output / "processes.json", rows)
            print(name, row["exit"], row.get("reader_failure", []), flush=True)
            require(digest(runtime["path"]) == runtime["sha256"], "runtime changed during campaign")
        require(source_identity(args.expected_source, args.overlay_manifest) == identity, "source/harness changed during campaign")
        require(authenticate_runtime(args.expected_source) == runtime, "runtime provenance changed during campaign")
        require(authenticate_engine(args.engine, args.engine_archive) == engine, "engine changed during campaign")
        report["final_source_verified"] = True
    except BaseException as error:
        fatal = str(error) if isinstance(error, CampaignInterrupted) else f"{type(error).__name__}: {error}"
        raise
    finally:
        passed = fatal is None and len(rows) == len(plan) and report.get("final_source_verified") is True \
            and all(r["exit"] == 0 and "summary" in r and not r.get("reader_failure") for r in rows)
        report.update(processes=rows, unstarted_processes=plan[len(rows):], fatal_error=fatal,
            status="passed" if passed else "failed")
        write_json(args.output / "report.json", report)
    require(report["status"] == "passed", "campaign incomplete or failed; original evidence retained")


if __name__ == "__main__":
    main()
