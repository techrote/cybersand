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
import ctypes
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
import threading
import time
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/ci"))
from execution_policy import identity as execution_identity, watchdog_seconds
from execution_telemetry import observe_process

VERSION = "4.7.stable.official.5b4e0cb0f"
VARIANTS = ("R", "ER")
PUBLISHED_R_RUNTIME_SHA256 = {
    "Linux": "0f60213c7fc3f9a1b1d7ad5143fdb22d453a452cddefd3fe4d7a7cb4d7b6cf45",
    "Windows": "ee09f7ab485f817b5f58e767ddb26f2e430439bb3dd4f185019eda028f47199a",
}
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
DEFAULT_COHORTS = ("paused:N:0", "play:N:0", "play:D:0", "play:W:0", "play:N:50000")
ACK_MODES = {"N": "normal", "W": "withheld", "D": "delayed"}
ACK_DELAY_USEC = 100000
PROCESS_MEMORY_SAMPLE_SECONDS = 0.5


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
    require(manifest["sha256"] == PUBLISHED_R_RUNTIME_SHA256[platform.system()],
            "resumed R/ER comparison requires the same published R runtime")
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
            "tools/ci/execution_policy.py", "tools/ci/execution_telemetry.py",
            "tools/ci/run_windows_godot_regressions.py"}}
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
    require(all(type(v) in (int, float) and math.isfinite(v) and v >= 0 for v in values), "invalid measurement population")
    values = sorted(values)
    return {"n": len(values), **({label: values[min(len(values)-1, math.ceil(len(values)*q)-1)]
        for label, q in (("p50", .5), ("p95", .95), ("p99", .99), ("max", 1))} if values else {})}


def graphics_classification(adapter):
    if re.search(r"llvmpipe|softpipe|swiftshader|basic render|software|GDI Generic|lavapipe", adapter, re.I):
        return "software"
    if re.search(r"NVIDIA|GeForce|Quadro|TITAN|Radeon|Intel.*(?:Arc|Iris|UHD|HD Graphics)", adapter, re.I):
        return "hardware_adapter_reported"
    return "unclassified"


def event_rows(events, kind):
    return [event for event in events if event["event"] == kind]


def integer(value, label, minimum=0):
    require(type(value) is int and value >= minimum, "invalid " + label)
    return value


def validate_ack_evidence(data):
    """Require delayed ACKs to originate in actual completed Main uploads."""
    events, arm = data["events"], data["arm"]
    for name in ("ack_delay_usec", "ack_queue_capacity", "ack_queue_high_water", "ack_queue_overflows", "ack_queue_errors", "ack_queue_remaining"):
        integer(data.get(name), name)
    require(data.get("ack_mode") == ACK_MODES[arm]
            and data.get("ack_delay_usec") == (ACK_DELAY_USEC if arm == "D" else 0), "ACK mode/delay differs from registered arm")
    require(data.get("ack_queue_capacity") == 256 and data.get("ack_queue_overflows") == 0
            and data.get("ack_queue_errors") == 0 and data.get("ack_queue_remaining") == 0,
            "ACK queue overflow, observer error or undrained delayed ACK")
    successes = event_rows(events, "texture_success") + event_rows(events, "texture_create_success")
    issued, withheld = event_rows(events, "ack_issue"), event_rows(events, "ack_withheld")
    visible, observed, clears = (event_rows(events, kind) for kind in ("ack_visible", "ack_observed", "ack_clear"))
    queued, released = event_rows(events, "ack_queued"), event_rows(events, "ack_delay_release")
    joins = event_rows(events, "owner_joined")
    require(len(joins) == 1 and all(e["event_sequence"] < joins[0]["event_sequence"]
            for e in issued + withheld + queued + released), "ACK transport continued after owner joined")
    for ack in issued + withheld + queued:
        integer(ack["serial"], "ACK serial", 1)
        require(any(e["serial"] == ack["serial"] and e["usec"] <= ack["usec"]
                    and e["event_sequence"] < ack["event_sequence"] for e in successes),
                "ACK issued or queued before successful upload")
    require(len(visible) == len(issued), "ordinary ACK visibility population incomplete")
    for issue, publication in zip(issued, visible):
        require(issue["serial"] == publication["serial"] and issue["usec"] <= publication["usec"]
                and issue["event_sequence"] < publication["event_sequence"], "ordinary ACK visibility is not paired")
    for observation in observed:
        serial = integer(observation["ack_serial"], "observed ACK serial")
        if serial:
            require(any(e["serial"] == serial and e["usec"] <= observation["usec"]
                        and e["event_sequence"] < observation["event_sequence"] for e in issued),
                    "worker observed an unissued ACK")
    if arm == "W":
        require(not issued and not visible and not clears and withheld
                and not queued and not released and all(e["ack_serial"] == 0 for e in observed),
                "withheld arm issued, observed or cleared an ACK")
    else:
        require(issued and not withheld, "ACK arm differs from declared control")
    queue_delays = []
    if arm == "D":
        require(len(queued) == len(released) == len(issued) and queued, "delayed ACK population incomplete")
        require([e["queue_sequence"] for e in queued] == list(range(1, len(queued)+1)), "ACK queue sequence gap")
        require([e["serial"] for e in queued] == sorted({e["serial"] for e in queued}), "delayed ACK serial duplicated or regressed")
        by_sequence = {e["queue_sequence"]: e for e in queued}
        active, peak = set(), 0
        for event in events:
            if event["event"] not in ("ack_queued", "ack_delay_release"):
                continue
            sequence = event["queue_sequence"]
            require(sequence in by_sequence, "release has no real queued ACK")
            source = by_sequence[sequence]
            require(all(event.get(k) == source.get(k) for k in
                        ("serial", "queue_sequence", "queued_usec", "due_usec", "delay_usec")), "delayed ACK identity changed")
            queued_at = integer(source["queued_usec"], "ACK queue timestamp")
            require(source["delay_usec"] == ACK_DELAY_USEC and source["due_usec"] == queued_at + ACK_DELAY_USEC
                    and queued_at <= source["usec"], "delayed ACK deadline differs from fixed 100ms")
            if event["event"] == "ack_queued":
                require(sequence not in active, "ACK queued twice")
                require(any(e["serial"] == source["serial"] and e["usec"] <= queued_at
                            and e["event_sequence"] < source["event_sequence"] for e in successes),
                        "delayed ACK clock predates successful upload")
                active.add(sequence)
                peak = max(peak, len(active))
            else:
                require(sequence in active, "duplicate or out-of-order delayed ACK release")
                released_at = integer(event["released_usec"], "ACK release timestamp")
                require(source["due_usec"] <= released_at <= event["usec"], "delayed ACK released early")
                matching = [e for e in issued if e["serial"] == event["serial"]]
                require(len(matching) == 1 and event["usec"] <= matching[0]["usec"]
                        and event["event_sequence"] < matching[0]["event_sequence"],
                        "delayed ACK did not use the subsequent ordinary ACK method")
                queue_delays.append(matching[0]["usec"]-queued_at)
                active.remove(sequence)
            require(integer(event["queue_count"], "ACK queue count") == len(active) and len(active) <= 256,
                    "delayed ACK queue count/capacity mismatch")
        require(not active and data["ack_queue_high_water"] == peak, "delayed ACK queue high-water differs from events")
        tails = event_rows(events, "tail_caught_up")
        require(len(tails) == 1, "delayed ACK tail missing")
        tail = tails[0]
        require(tail.get("ack_queue_remaining") == 0
                and integer(tail.get("ack_empty_owner_count"), "ACK-empty owner counter") + 2 <= tail["owner_count"],
                "delayed ACK tail did not allow two ordinary owner completions")
        last_release = released[-1]
        require(sum(last_release["event_sequence"] < e["event_sequence"] < tail["event_sequence"]
                    for e in event_rows(events, "owner_end")) >= 2,
                "delayed ACK queue was drained after ordinary owner completion")
    else:
        require(not queued and not released and data.get("ack_queue_high_water") == 0, "normal/withheld arm contains delayed ACK transport")
    observations, clear_latencies, censored = [], [], 0
    for ack in issued:
        later = [e for e in observed if e["ack_serial"] >= ack["serial"] and e["usec"] >= ack["usec"]]
        if later:
            observations.append(later[0]["usec"]-ack["usec"])
        else:
            censored += 1
    for clear in clears:
        eligible = [e for e in issued if e["serial"] == clear["ack_serial"] and e["usec"] <= clear["usec"]
                    and e["event_sequence"] < clear["event_sequence"]]
        require(eligible and clear["ack_serial"] >= clear["pending_serial"], "clear lacks ordinary covering ACK")
        clear_latencies.append(clear["usec"]-eligible[-1]["usec"])
    return {"ack_delay_usec": data["ack_delay_usec"], "ack_queue_high_water": data["ack_queue_high_water"],
            "ack_queue_to_issue_usec": percentiles(queue_delays),
            "ack_issue_to_observation_usec": percentiles(observations),
            "ack_issue_to_clear_usec": percentiles(clear_latencies), "ack_unobserved_at_end": censored,
            "ack_nonclearing_observations": sum(not e["will_clear"] for e in observed)}


def validate_baseline_lifetimes(data):
    events = data["events"]
    require(integer(data.get("baseline_observer_errors"), "baseline observer error count") == 0, "baseline observer error")
    require(data.get("baseline_timing_scope") == "post-operation owner observer timestamps; not allocator lifetime",
            "baseline lifetime has an unsupported allocation scope")
    accepted = [e for e in event_rows(events, "production_append_end") if e["accepted"] and e["packet_full"]]
    begins = event_rows(events, "baseline_begin")
    require(len(begins) == len(accepted) and begins, "accepted full baseline lifetime population incomplete")
    active, last_serial = None, 0
    completed, owner_turns, censored = [], [], []
    reasons = Counter()
    for event in events:
        kind = event["event"]
        if kind not in ("baseline_begin", "baseline_end", "baseline_censored"):
            continue
        if kind == "baseline_begin":
            require(active is None and not censored and event["serial"] > last_serial, "baseline replaced without observed retirement")
            require(event["channels"] in (1, 2) and event["bytes"] == 1024*1024*event["channels"]
                    and event["birth_refresh"] == event["refresh"] and event["accept_usec"] <= event["usec"],
                    "baseline begin is not a complete frame")
            matching = [e for e in accepted if e["refresh"] == event["refresh"]
                        and e["after"]["pending_serial"] == event["serial"]]
            require(len(matching) == 1 and matching[0]["packet_bytes"] == event["bytes"]
                    and matching[0]["after"]["generation"] == event["generation"],
                    "baseline lifetime is not tied to actual accepted full pixels")
            active, last_serial = event, event["serial"]
            continue
        require(active is not None and all(event.get(k) == active.get(k) for k in
                    ("serial", "generation", "channels", "bytes", "accept_usec", "birth_refresh")),
                "baseline retirement/censor identity changed")
        if kind == "baseline_censored":
            require(not censored and event["censor_usec"] <= event["usec"]
                    and event["age_usec"] == event["censor_usec"]-active["accept_usec"] >= 0
                    and event["pending_serial"] >= active["serial"], "invalid right-censored baseline age")
            joins = event_rows(events, "owner_joined")
            require(len(joins) == 1 and joins[0]["event_sequence"] < event["event_sequence"],
                    "baseline censored before owner joined")
            censored.append(event["age_usec"])
        else:
            require(event["end_usec"] <= event["usec"]
                    and event["lifetime_usec"] == event["end_usec"]-active["accept_usec"] >= 0
                    and event["refresh"] >= active["birth_refresh"]
                    and event["pending_serial_at_retirement"] >= active["serial"], "invalid baseline lifetime")
            reason = event["reason"]
            require(reason in ("ack", "full_replacement"), "baseline retirement has no production cause")
            if reason == "ack":
                matching = [e for e in event_rows(events, "ack_clear")
                            if e["refresh"] == event["refresh"] and e["pending_serial"] == event["pending_serial_at_retirement"]
                            and e["ack_serial"] == event["covering_ack_serial"]]
                require(len(matching) == 1 and event["covering_ack_serial"] >= event["pending_serial_at_retirement"]
                        and event["replacement_serial"] == event["replacement_generation"] == 0,
                        "baseline ACK retirement lacks actual covering clear")
            else:
                require(event["covering_ack_serial"] == 0 and event["replacement_serial"] > active["serial"],
                        "full replacement pretends to be an ACK")
                matching = [e for e in begins if e["serial"] == event["replacement_serial"]
                            and e["generation"] == event["replacement_generation"] and e["refresh"] == event["refresh"]
                            and e["event_sequence"] > event["event_sequence"]]
                require(len(matching) == 1, "baseline replacement has no accepted full successor")
            completed.append(event["lifetime_usec"])
            owner_turns.append(event["refresh"]-active["birth_refresh"])
            reasons[reason] += 1
        active = None
    require(active is None, "final retained baseline has no right-censored lifetime")
    return {"baseline_count": len(begins), "baseline_retirement_reasons": dict(reasons),
            "baseline_completed_lifetime_usec": percentiles(completed),
            "baseline_completed_owner_turns": percentiles(owner_turns),
            "baseline_right_censored_age_usec": percentiles(censored),
            "baseline_lifetime_scope": "Observed accepted-full lifetime; final retained baseline is right-censored, not a fabricated ACK retirement."}


def validate_worker_memory(data):
    events = data["events"]
    mode = data.get("native_workers_mode")
    require(mode in ("auto", "1"), "unknown native worker selection")
    request = 0 if mode == "auto" else 1
    require(integer(data.get("native_worker_request"), "native worker request") == request
            and data.get("native_worker_config_source") ==
            ("project-default-auto" if mode == "auto" else "explicit-test-override-1"),
            "native worker configuration differs from declared default/override")
    require(data.get("native_worker_count_scope") == "configured native pool capacity; not observed task participation or concurrency",
            "native worker count claims unmeasured participation")
    configs = event_rows(events, "worker_config")
    require(configs and len({e["generation"] for e in configs}) == len(configs), "native worker configuration population incomplete")
    native_generations = {e["generation"] for e in event_rows(events, "native_end")}
    require({e["generation"] for e in configs} == native_generations, "a World generation lacks actual native worker readback")
    for config in configs:
        logical = integer(config["logical_processors"], "logical processor readback", 1)
        automatic = 2 if logical < 4 else 4 if logical < 12 else 6
        require(integer(config["requested_native_workers"], "configured native worker request") == request
                and integer(config["actual_native_workers"], "configured native worker capacity", 1) == (automatic if mode == "auto" else 1),
                "actual native worker count differs from current source selection")
    require(integer(data.get("actual_native_workers"), "final native worker capacity", 1) == configs[-1]["actual_native_workers"], "final native worker readback differs from owner events")

    memory = event_rows(events, "memory_sample")
    require(data.get("memory_scope") == "Godot tracked allocator only; excludes untracked native allocations and GPU/driver memory",
            "memory counters have an unsupported allocation/process scope")
    require(data.get("memory_window") == "process allocator peak observed through oracles_complete; before trace export and receipt serialization",
            "memory sampling window has an unsupported final-lifetime claim")
    require(data.get("memory_sample_count") == len(memory) and memory, "memory sample population incomplete")
    frame_samples = [e for e in memory if e["stage"] == "frame"]
    require([e["frame"] for e in frame_samples] == list(range(data["frame_count"])), "memory frame population incomplete")
    extra_stages = {"before_host", "startup", "before_reset", "measurement_end", "tail_drained", "owner_joined", "oracles_complete"}
    if data["workload"] == "play":
        extra_stages |= {"play_installed", "after_reset"}
    extras = [e["stage"] for e in memory if e["stage"] != "frame"]
    require(len(extras) == len(extra_stages) and set(extras) == extra_stages, "memory lifecycle sampling differs from registration")
    previous_peak = 0
    for sample in memory:
        used = integer(sample["godot_static_bytes"], "Godot allocator bytes")
        peak = integer(sample["godot_static_peak_bytes"], "Godot allocator peak bytes")
        require(peak >= used and peak >= previous_peak, "Godot allocator peak regressed or is below use")
        previous_peak = peak
    peak = integer(data.get("godot_static_peak_bytes"), "final Godot allocator peak bytes")
    require(peak == previous_peak, "final Godot allocator peak differs from recorded samples")

    payloads, owners = event_rows(events, "owner_payload_bytes"), event_rows(events, "owner_end")
    require(data.get("payload_memory_scope") == "logical array lengths; may share COW storage; not unique allocated bytes or capacity",
            "logical payload lengths claim unique allocations")
    require(data.get("ack_queue_logical_storage_bytes") == (256*4*8 if data["arm"] == "D" else 0),
            "ACK queue logical storage differs from registered bounded arrays")
    require(len(payloads) == len(owners) and payloads, "logical owner payload population incomplete")
    lengths = ("pending_bytes", "pending_rectangles", "published_bytes", "published_rectangles", "legacy_full_bytes")
    for payload, owner in zip(payloads, owners):
        require(payload["refresh"] == owner["refresh"] and payload["generation"] == owner["generation"]
                and payload["pending_bytes"] == owner["bytes"] and payload["pending_rectangles"] == owner["rectangles"]
                and owner["event_sequence"] < payload["event_sequence"], "owner payload lengths are not paired to actual completion")
        for name in lengths:
            integer(payload[name], "logical " + name)
    require(data.get("published_high_water") == max(e["published_bytes"] for e in payloads)
            and data.get("legacy_full_high_water") == max(e["legacy_full_bytes"] for e in payloads),
            "logical payload high-water differs from owner observations")
    return {"native_workers_mode": mode, "native_worker_request": request,
            "actual_native_workers": data["actual_native_workers"], "worker_configurations": configs,
            "native_worker_count_scope": data["native_worker_count_scope"],
            "godot_allocator_scope": data["memory_scope"], "godot_tracked_allocator_available": peak > 0,
            "memory_window": data["memory_window"],
            "godot_tracked_allocator_frame_bytes": percentiles([e["godot_static_bytes"] for e in frame_samples]),
            "godot_tracked_allocator_all_samples_bytes": percentiles([e["godot_static_bytes"] for e in memory]),
            "godot_static_peak_bytes": peak, "memory_sample_count": len(memory),
            "logical_payload_scope": "Array lengths only; shared/COW storage cannot be summed as unique heap allocations. No allocation count measured.",
            "logical_owner_payload_lengths": {name: percentiles([e[name] for e in payloads]) for name in lengths},
            "logical_ack_queue_storage_bytes": data["ack_queue_logical_storage_bytes"],
            "published_high_water": data["published_high_water"], "legacy_full_high_water": data["legacy_full_high_water"]}


def validate_startup(data):
    times = data.get("startup_times_usec", {})
    required = {"harness_entry", "host_begin", "host_ready", "play_ready", "measurement_begin", "first_frame_submitted"}
    require(isinstance(times, dict) and set(times) == required, "startup milestone population incomplete")
    for name, value in times.items():
        integer(value, "startup " + name)
    require(data.get("startup_timing_scope") == "harness-entry-relative CPU/host milestones and first frame_post_draw observation; not process-launch or GPU completion latency",
            "startup timing claims an unmeasured process/GPU boundary")
    require(times["harness_entry"] <= times["host_begin"] <= times["host_ready"] <= times["measurement_begin"], "startup milestones reordered")
    require(times["first_frame_submitted"] >= times["host_ready"], "first frame observation precedes host readiness")
    if data["workload"] == "play":
        require(times["host_ready"] <= times["play_ready"] <= times["measurement_begin"], "PLAY installation missing from startup")
    else:
        require(times["play_ready"] == 0, "paused startup claims PLAY installation")
    measurements = event_rows(data["events"], "measurement_begin")
    submitted = event_rows(data["events"], "startup_first_frame_submitted")
    require(len(measurements) == len(submitted) == 1
            and measurements[0].get("start_usec") == times["measurement_begin"] <= measurements[0]["usec"]
            and submitted[0].get("submitted_usec") == times["first_frame_submitted"] <= submitted[0]["usec"],
            "startup summary differs from actual milestone events")
    return {"milestones_usec": times, "scope": data["startup_timing_scope"],
            "harness_to_host_ready_usec": times["host_ready"]-times["harness_entry"],
            "host_construction_and_initialization_usec": times["host_ready"]-times["host_begin"],
            "host_ready_to_play_ready_usec": times["play_ready"]-times["host_ready"] if data["workload"] == "play" else None,
            "harness_to_measurement_begin_usec": times["measurement_begin"]-times["harness_entry"],
            "harness_to_first_frame_post_draw_usec": times["first_frame_submitted"]-times["harness_entry"],
            "host_initialization_and_play_installation_excluded_from_frame_distribution": True,
            "first_frame_post_draw_within_measurement_window": times["first_frame_submitted"] >= times["measurement_begin"]}


def derive_freshness(data):
    """Identity-bound CPU handoff ages, with the actual visibility bracket.

    A snapshot can become visible before its owner's return observation. That
    race is legitimate; clamp only the lower bound to zero, never a bad upper
    bound. The first publication of each render serial also prevents a fresh
    status wrapper from hiding older retained render data.
    """
    events = data["events"]
    owners = event_rows(events, "owner_end")
    by_snapshot, first_packet = {}, {}
    previous_snapshot, previous_packet = 0, 0
    for owner in owners:
        serial = integer(owner["snapshot_serial"], "published snapshot serial", 1)
        packet = integer(owner["pending_serial"], "published render serial")
        published = integer(owner["published_usec"], "publication timestamp")
        end = integer(owner["end_usec"], "owner completion timestamp")
        duration = integer(owner["duration_usec"], "owner publication duration")
        require(serial > previous_snapshot and packet >= previous_packet
                and end-duration <= published <= end <= owner["usec"], "publication identity or visibility bracket regressed")
        previous_snapshot, previous_packet = serial, packet
        by_snapshot[serial] = owner
        first_packet.setdefault((owner["render_generation"], packet), owner)
    require(by_snapshot, "no owner publication for freshness")

    def owner_for(event):
        owner = by_snapshot.get(event.get("snapshot_serial"))
        require(owner is not None and owner["pending_serial"] == event.get("serial")
                and owner["render_generation"] == event.get("generation"), "consumer identity has no exact owner publication")
        require(owner["published_usec"] <= event["usec"], "consumer precedes its publication timestamp")
        if owner["generation"] == owner["render_generation"]:
            require(integer(event["revision"], "consumed render revision") <= owner["revision"], "consumer revision exceeds its authoritative owner")
        return owner

    def age(owner, event):
        require(owner["published_usec"] <= event["usec"], "negative publication age")
        return (max(0, event["usec"]-owner["end_usec"]), event["usec"]-owner["published_usec"])

    def distribution(pairs):
        return {"lower_bound": percentiles([p[0] for p in pairs]),
                "upper_bound": percentiles([p[1] for p in pairs])}

    consumes = event_rows(events, "render_consume")
    successes = event_rows(events, "texture_success")
    creates = event_rows(events, "texture_create_success")
    completed = event_rows(events, "consumer_displayed")
    require(consumes and successes and completed, "freshness population incomplete")
    matched_consumes, status_ages, payload_ages, races = {}, [], [], 0
    for event in consumes:
        owner = owner_for(event)
        key = (event["snapshot_serial"], event["serial"], event["generation"])
        require(key not in matched_consumes, "snapshot consumed more than once in freshness population")
        matched_consumes[key] = event
        status_ages.append(age(owner, event))
        payload_ages.append(age(first_packet[(event["generation"], event["serial"])], event))
        races += event["usec"] < owner["end_usec"]
    full_refreshes = {e["refresh"] for e in event_rows(events, "native_end") if e["packet_full"]}
    submission_ages, full_payload_ages, dirty_payload_ages, new_full_ages, operation_times = [], [], [], [], []
    new_payload_consume_ages = []
    submission_by_packet = {}
    for event in successes + creates:
        owner = owner_for(event)
        first = first_packet[(event["generation"], event["serial"])]
        observed_age = age(first, event)
        submission_ages.append(observed_age)
        (full_payload_ages if first["full"] else dirty_payload_ages).append(observed_age)
        if first["refresh"] in full_refreshes:
            new_full_ages.append(observed_age)
        if event["event"] == "texture_success":
            consume = matched_consumes.get((event["snapshot_serial"], event["serial"], event["generation"]))
            require(consume is not None and consume["revision"] == event["revision"]
                    and consume["usec"] <= event["usec"] and consume["event_sequence"] < event["event_sequence"],
                    "texture submission has no prior matching consumer")
            operation_times.append(event["usec"]-consume["usec"])
            new_payload_consume_ages.append(age(first, consume))
            key = (event["serial"], event["generation"], event["revision"])
            require(key not in submission_by_packet, "render serial submitted more than once")
            submission_by_packet[key] = event
    completed_ages, submission_to_completion = [], []
    require(len(completed) == len(successes), "consumer completion/submission population differs")
    seen = set()
    for event in completed:
        key = (event["serial"], event["generation"], event["revision"])
        submission = submission_by_packet.get(key)
        require(submission is not None and key not in seen and submission["usec"] <= event["usec"]
                and submission["event_sequence"] < event["event_sequence"], "consumer completion has no matching successful submission")
        seen.add(key)
        completed_ages.append(age(first_packet[(event["generation"], event["serial"])], event))
        submission_to_completion.append(event["usec"]-submission["usec"])

    resets = event_rows(events, "reset_request")
    require(len(resets) == 1, "freshness reset population differs from registration")
    reset = resets[0]
    newer_consumes = [e for e in consumes if e["generation"] > reset["generation"] and e["usec"] >= reset["usec"]]
    newer_submissions = [e for e in successes if e["generation"] > reset["generation"] and e["usec"] >= reset["usec"]]
    require(newer_consumes and newer_submissions, "reset never reached an actual new-generation consumer/submission")
    first_consume, first_submission = newer_consumes[0], newer_submissions[0]
    frames = event_rows(events, "frame_end")
    reset_frames = [e for e in frames if e["start_usec"] <= first_submission["usec"] and e["end_usec"] >= reset["usec"]]
    full_calls = [e for e in event_rows(events, "native_end") if e["packet_full"]]
    full_frames = [e for e in frames if any(call["start_usec"] < e["end_usec"]
                   and call["end_usec"] > e["start_usec"] for call in full_calls)]
    return {"scope": "CPU publication visibility brackets to consumer/submission/bookkeeping; not GPU completion or displayed-frame latency",
            "status_publication_to_consume_usec": distribution(status_ages),
            "render_publication_to_consume_usec": distribution(new_payload_consume_ages),
            "retained_payload_to_all_consume_usec": distribution(payload_ages),
            "unchanged_payload_consume_count": len(consumes)-len(successes),
            "unchanged_payload_scope": "All-consume retained age includes unchanged pixels; successful new-upload handoff is reported separately.",
            "render_publication_to_texture_submission_usec": distribution(submission_ages),
            "render_publication_to_consumer_completion_usec": distribution(completed_ages),
            "retained_full_payload_submission_age_usec": distribution(full_payload_ages),
            "dirty_only_payload_submission_age_usec": distribution(dirty_payload_ages),
            "new_native_full_submission_age_usec": distribution(new_full_ages),
            "consume_to_texture_submission_usec": percentiles(operation_times),
            "submission_to_consumer_completion_usec": percentiles(submission_to_completion),
            "consumers_before_owner_return_observation": races,
            "native_full_overlap_frame_usec": percentiles([e["duration_usec"] for e in full_frames]),
            "native_full_overlap_frames": [e["frame"] for e in full_frames],
            "reset_to_first_new_generation_consume_usec": first_consume["usec"]-reset["usec"],
            "reset_to_first_new_generation_submission_usec": first_submission["usec"]-reset["usec"],
            "reset_overlap_frame_usec": percentiles([e["duration_usec"] for e in reset_frames]),
            "reset_overlap_frames": [e["frame"] for e in reset_frames]}


def reduce_trace(data):
    require(data.get("schema") == "render-production-graphical-v2" and data.get("schema_version") == 2, "unknown receipt schema")
    require(data.get("variant") in VARIANTS and data.get("workload") in ("paused", "play") and data.get("arm") in ACK_MODES, "unknown source/workload/ACK label")
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
        require(end.get("observer_accounting") == "constant-time-full-tag-v2", "v2 requires the authenticated constant-time observer")
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
    retry_causes = []
    for call in [e for e in native if e["call"] == 2]:
        attempts = [e for e in append_ends if e["refresh"] == call["refresh"]]
        require(len(attempts) == 2 and not attempts[0]["packet_full"] and call["force_full"] is True,
                "unexplained full retry")
        attempt = attempts[0]
        # Both source arms record both costs; readback uses the declared source.
        prefix = "predicted_e_charged_" if data["variant"] == "ER" else "predicted_raw_"
        byte_overflow = attempt[prefix + "bytes"] > 2097152
        rect_overflow = attempt[prefix + "rectangles"] > 256
        preflight = not attempt["accepted"]
        require(byte_overflow or rect_overflow, "retry has no independently observed budget cause")
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
    ack_summary = validate_ack_evidence(data)
    baseline_summary = validate_baseline_lifetimes(data)
    memory_summary = validate_worker_memory(data)
    startup_summary = validate_startup(data)
    freshness_summary = derive_freshness(data)
    clears = select("ack_clear")
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
            "frame_usec": percentiles(data["frame_usec"]),
            "ack_stale_observations": counts.get("ack_stale", 0), "rejected_snapshots": counts.get("reject", 0),
            "tail_usec": data["tail_elapsed_usec"], "frame_intervals_exclude_tail": True,
            "graphics_classification": graphics_classification(data["adapter"]),
            "startup": startup_summary, "freshness": freshness_summary,
            **ack_summary, **baseline_summary, **memory_summary, **durations}


def parse_cohort(value):
    fields = value.split(":")
    require(len(fields) == 3 and fields[0] in ("paused", "play") and fields[1] in ACK_MODES
            and fields[2] in ("0", "50000"), "cohort must be paused/play:N/W/D:0/50000; D is a fixed 100ms ACK delay")
    return {"workload": fields[0], "arm": fields[1], "consumer_usec": int(fields[2])}


class CampaignInterrupted(BaseException):
    """An actually started cell, with retained evidence and completed cleanup."""
    def __init__(self, row, cause):
        self.row = row
        self.cause = cause
        super().__init__(f"{type(cause).__name__}: {cause}")


def observe_windows_process(pid):
    """Read only the owned engine PID using documented Win32 process counters.

    https://learn.microsoft.com/en-us/windows/win32/api/psapi/nf-psapi-getprocessmemoryinfo
    https://learn.microsoft.com/en-us/windows/win32/api/psapi/ns-psapi-process_memory_counters_ex
    Limited query permission suffices on the supported modern Windows hosts.
    Working-set and private-commit bytes are not native heap allocation counts.
    """
    result = {"scope": "direct_process_only", "available": False,
              "observer": "Win32 GetProcessMemoryInfo/PROCESS_MEMORY_COUNTERS_EX", "process_id": pid}

    class Counters(ctypes.Structure):
        _fields_ = [("cb", ctypes.c_uint32), ("PageFaultCount", ctypes.c_uint32)] + [
            (name, ctypes.c_size_t) for name in ("PeakWorkingSetSize", "WorkingSetSize",
                "QuotaPeakPagedPoolUsage", "QuotaPagedPoolUsage", "QuotaPeakNonPagedPoolUsage",
                "QuotaNonPagedPoolUsage", "PagefileUsage", "PeakPagefileUsage", "PrivateUsage")]

    handle = None
    try:
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        psapi = ctypes.WinDLL("psapi", use_last_error=True)
        kernel.OpenProcess.argtypes = [ctypes.c_uint32, ctypes.c_int32, ctypes.c_uint32]
        kernel.OpenProcess.restype = ctypes.c_void_p
        kernel.CloseHandle.argtypes = [ctypes.c_void_p]
        kernel.CloseHandle.restype = ctypes.c_int32
        psapi.GetProcessMemoryInfo.argtypes = [ctypes.c_void_p, ctypes.POINTER(Counters), ctypes.c_uint32]
        psapi.GetProcessMemoryInfo.restype = ctypes.c_int32
        handle = kernel.OpenProcess(0x1000, False, pid)  # PROCESS_QUERY_LIMITED_INFORMATION
        if not handle:
            return {**result, "reason": "OpenProcess refused or process exited", "win32_error": ctypes.get_last_error()}
        counters = Counters()
        counters.cb = ctypes.sizeof(Counters)
        if not psapi.GetProcessMemoryInfo(handle, ctypes.byref(counters), counters.cb):
            return {**result, "reason": "GetProcessMemoryInfo failed", "win32_error": ctypes.get_last_error()}
        return {**result, "available": True, "peak_rss_bytes": int(counters.PeakWorkingSetSize),
                "peak_working_set_bytes": int(counters.PeakWorkingSetSize),
                "working_set_bytes": int(counters.WorkingSetSize),
                "private_commit_bytes": int(counters.PrivateUsage),
                "peak_private_commit_bytes": int(counters.PeakPagefileUsage)}
    except (AttributeError, OSError, ValueError) as error:
        return {**result, "reason": f"{type(error).__name__}: {error}"}
    finally:
        if handle:
            kernel.CloseHandle(handle)


def observe_campaign_process(pid):
    return observe_windows_process(pid) if platform.system() == "Windows" else observe_process(pid)


class ProcessMemorySamples:
    """Bounded sampling of the existing direct-process OS observer.

    Linux reports VmHWM as observed while the process is alive. It is not a
    process-tree measurement or a guaranteed final lifetime maximum. The
    Windows uses the documented read-only process counters above. Failures are
    explicit; Godot allocator counters remain a separate measurement.
    """
    def __init__(self, pid):
        self.pid = pid
        self.started = time.monotonic()
        self.samples = []
        self.limit = max(2, math.ceil(watchdog_seconds("graphical_case_seconds")
                                     / PROCESS_MEMORY_SAMPLE_SECONDS) + 2)
        self.stop = threading.Event()
        self.thread = None

    def sample(self):
        try:
            observation = observe_campaign_process(self.pid)
        except Exception as error:
            observation = {"available": False, "scope": "direct_process_only",
                           "reason": f"{type(error).__name__}: {error}"}
        self.samples.append({"elapsed_seconds": time.monotonic()-self.started, **observation})

    def start(self):
        self.sample()

        def collect():
            while len(self.samples) < self.limit and not self.stop.wait(PROCESS_MEMORY_SAMPLE_SECONDS):
                self.sample()

        self.thread = threading.Thread(target=collect, name="render-process-memory", daemon=True)
        self.thread.start()

    def finish(self):
        self.stop.set()
        if self.thread is not None:
            self.thread.join(timeout=1.0)
        joined = self.thread is None or not self.thread.is_alive()
        samples = list(self.samples)
        peaks = [row["peak_rss_bytes"] for row in samples
                 if row.get("available") is True and type(row.get("peak_rss_bytes")) is int
                 and row["peak_rss_bytes"] >= 0]
        return {"scope": "direct_process_only",
                "observer": "Win32 GetProcessMemoryInfo" if platform.system() == "Windows" else "tools/ci/execution_telemetry.py:observe_process",
                "metric": "OS VmHWM on Linux / PeakWorkingSetSize on Windows; no process-tree or allocation-count claim",
                "sample_interval_seconds": PROCESS_MEMORY_SAMPLE_SECONDS,
                "sample_limit": self.limit, "sample_limit_reached": len(samples) == self.limit,
                "sampler_joined": joined, "samples": samples,
                "observed_peak_rss_bytes": max(peaks) if peaks and joined else None,
                "sampled_working_set_bytes": percentiles([row["working_set_bytes"] for row in samples if row.get("available") and "working_set_bytes" in row]),
                "sampled_private_commit_bytes": percentiles([row["private_commit_bytes"] for row in samples if row.get("available") and "private_commit_bytes" in row]),
                "observed_peak_private_commit_bytes": max((row["peak_private_commit_bytes"] for row in samples
                    if row.get("available") and "peak_private_commit_bytes" in row), default=None),
                "available": bool(peaks) and joined, "final_lifetime_peak_guaranteed": False,
                "unavailable_scope": "Godot tracked-allocator receipt metrics remain separate proxies for total process memory."}


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
    native_workers = cohort.get("native_workers", "auto")
    require(native_workers in ("auto", "1"), "native workers must be auto or the explicit one-worker control")
    argv = [str(engine), "--audio-driver", "Dummy", "--path", str(ROOT / "godot"), "--resolution", "960x540",
        *engine_args, "--script", "res://tests/bench_render_production.gd", "--", f"--receipt={receipt}",
        f"--variant={variant}", f"--workload={cohort['workload']}", f"--arm={cohort['arm']}",
        f"--consumer-usec={cohort['consumer_usec']}", f"--frames={frames}",
        f"--native-workers={native_workers}",
        f"--runtime-path={runtime['path']}", f"--runtime-sha256={runtime['sha256']}"]
    started = time.monotonic()
    interruption = None
    cleanup = {"required": False}
    state_path = Path(str(output) + ".process.json")
    with log_path.open("xb") as log:
        options = {"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP} if os.name == "nt" else {"start_new_session": True}
        process = subprocess.Popen(argv, stdout=log, stderr=subprocess.STDOUT, **options)
        memory = ProcessMemorySamples(process.pid)
        try:
            write_json(state_path, {"state": "started", "process_started": True, "process_id": process.pid,
                "variant": variant, **cohort, "argv": argv, "log_path": str(log_path)})
            memory.start()
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
            process_memory = memory.finish()
    row = {"variant": variant, **cohort, "native_workers": native_workers,
        "argv": argv, "exit": code, "process_id": process.pid, "process_memory": process_memory,
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
                    and raw["consumer_interval_usec"] == cohort["consumer_usec"] and raw["frame_count"] == frames
                    and raw["native_workers_mode"] == native_workers, "process differs from registered cell")
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
    parser.add_argument("--native-workers", choices=("auto", "1"), default="auto",
                        help="Ordinary automatic native workers by default; 1 is an explicit diagnostic control.")
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
    plan = [{**cell, "native_workers": args.native_workers, "repeat": repeat, "sequence": repeat*len(cohorts)+i+1}
        for repeat in range(args.repeats) for i, cell in enumerate(cohorts if repeat%2 == 0 else list(reversed(cohorts)))]
    args.output.mkdir(parents=True, exist_ok=False)
    rows, fatal = [], None
    report = {"schema": "render-production-campaign-v2", "variant": args.variant, "planned_processes": plan,
        "native_workers_mode": args.native_workers,
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
