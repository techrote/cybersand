#!/usr/bin/env python3
"""Paired, source-authenticated real-Main Control/R publication qualification.

Derived from #335's corrected monotonic graphical apparatus. No E policy and no
runtime selector: the driver installs a separately built library only between
fresh engine processes, then restores the original library even after failures.
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
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
BASE = "25ce0731d89b9540c2d95cfa8bae321c37e6e118"
HISTORICAL_APPARATUS = "902fc5b518855911c1b6761a7165573843e567ed"
GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
NATIVE_SUFFIXES = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".tpp"}
sys.path.insert(0, str(ROOT / "tools" / "ci"))
from execution_policy import identity as execution_policy_identity, watchdog_seconds
import render_copy_runtime_publication as publication

# The publisher remains unchanged and still requires an armed request. Only
# this graphical verifier admits its absence for a prepublication R build.
CONTROL_ABSENT_BUILD_INPUTS = {
    ".github/workflows/render-copy-runtime-publication.yml",
    "tools/ci/render_copy_publish_request.json",
    "docs/audits/2026-11-01-render-copy-production-reconciliation.md",
    "tools/ci/render_copy_runtime_publication.py",
    "tools/ci/test_render_copy_runtime_publication.py",
    "native/bench/render_copy.cpp",
}
COMPARABLE_BUILD_INPUTS = {
    ".gitattributes",
    "tools/build_native_extension.sh", "tools/build_native_extension_windows.sh",
    "tools/build_pinned_godot_cpp.sh", "tools/requirements-build.txt",
    "tools/toolchains/g++", "tools/check_linux_runtime_floor.sh",
    "tools/verify_pinned_source_tree.py", "third_party/native-toolchain.lock.json",
    "third_party/godot-runtime.lock.json", "godot/third_party/rapier2d.lock.json",
    "third_party/rapier-bvh-build.lock.json",
    "third_party/patches/rapier-0.35.1-cooperative-bvh-join.patch",
    "godot/addons/cybersand_native/cybersand_native.gdextension",
}
GRAPHICAL_HELPER_INPUTS = {
    "tools/ci/execution_policy.py", "tools/ci/execution_telemetry.py",
    "tools/ci/render_copy_runtime_publication.py",
    "tools/ci/lcb001_shared_contract_runtime_publication.py",
    "tools/ci/run_godot_regressions.py", "tools/ci/run_windows_godot_regressions.py",
    "tools/ci/godot_timeout_diagnostics.py", "tools/ci/godot_process_monitor.py",
    "tools/ci/physical_progress_watchdog.py", "tools/ci/godot_scheduling.py",
    "tools/ci/godot_scheduling_profile.json",
}


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "duplicate JSON key: " + key)
        result[key] = value
    return result


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"), object_pairs_hook=unique_object)


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], timeout=watchdog_seconds("operation_seconds"))


def git_value(value):
    return git("rev-parse", "--verify", value).decode().strip()


def commit_blobs(commit, paths):
    require(bool(re.fullmatch(r"[0-9a-f]{40}", commit)), "source commit must be a full Git SHA")
    paths = sorted(paths)
    for path in paths:
        require(not Path(path).is_absolute() and ".." not in Path(path).parts and "\n" not in path,
                "invalid source input path")
    result = subprocess.check_output(["git", "-C", str(ROOT), "cat-file", "--batch"],
        input="".join(f"{commit}:{path}\n" for path in paths).encode(), timeout=watchdog_seconds("operation_seconds"))
    output, offset = {}, 0
    for path in paths:
        end = result.index(b"\n", offset)
        fields = result[offset:end].split()
        require(len(fields) == 3 and fields[1] == b"blob", "missing source blob: " + path)
        size = int(fields[2])
        output[path] = result[end+1:end+1+size]
        require(len(output[path]) == size and result[end+1+size:end+2+size] == b"\n", "truncated Git blob")
        offset = end + 2 + size
    require(offset == len(result), "unexpected Git blob response tail")
    return output


def native_roster(commit):
    paths = git("ls-tree", "-rz", "--name-only", commit).decode().split("\0")
    return {p for p in paths if p.startswith(("native/include/", "native/src/", "godot/native_extension/"))
            and Path(p).suffix in NATIVE_SUFFIXES}


def canonical_input_ledgers(source, candidate):
    """Public producer/verifier API: exact canonical Git-blob input hashes.

    BUILD_EXACT comes from the approved R publication profile. Dynamic selectors
    match its shared engine.input_ledgers: native sources, all native tests,
    worldgen examples, Godot fixtures and .gd/.tscn/.tres/.gdshader resources.
    No manifest-provided list determines what must be verified.
    """
    require(candidate in ["control", "R"], "unknown runtime candidate")
    require(bool(re.fullmatch(r"[0-9a-f]{40}", source)), "source commit must be a full Git SHA")
    if candidate == "control":
        require(source == BASE, "Control must be built from the exact frozen main commit")
    tracked = {}
    for entry in git("ls-tree", "-rz", "--full-tree", source).split(b"\0"):
        if not entry:
            continue
        metadata, raw_path = entry.split(b"\t", 1)
        mode, kind, _oid = metadata.split()
        tracked[raw_path.decode("utf-8")] = (mode, kind)
    exact = set(publication.engine.BUILD_EXACT)
    permitted_absent = CONTROL_ABSENT_BUILD_INPUTS if candidate == "control" else {publication.engine.REQUEST}
    require((exact - set(tracked)).issubset(permitted_absent), "missing required canonical build input")
    require(COMPARABLE_BUILD_INPUTS.issubset(tracked), "missing core compiler/build/lock input")
    native = native_roster(source)
    require(bool(native), "empty native source roster")
    selected = {
        path for path in tracked if path in native or path in exact
        or path.startswith(("native/tests/", "examples/worldgen/", "godot/tests/fixtures/"))
        or (path.startswith("godot/") and Path(path).suffix in {".gd", ".tscn", ".tres", ".gdshader"})
    }
    for path in selected:
        mode, kind = tracked[path]
        require(kind == b"blob" and mode in (b"100644", b"100755"), "non-file canonical input: " + path)
    blobs = commit_blobs(source, selected)
    hashes = {path: hashlib.sha256(data).hexdigest() for path, data in blobs.items()}
    return {"source_inputs": {path: hashes[path] for path in sorted(native)},
            "build_inputs": {path: hashes[path] for path in sorted(selected - native)}}


def normalized_toolchain(manifest):
    """Keep compiler/linker/dependency facts; normalize only host/path context."""
    value = manifest.get("toolchain")
    require(isinstance(value, str) and bool(value.strip()), "runtime toolchain record missing")
    target = manifest.get("platform", platform_paths()["platform"])
    require(target in ["linux", "windows"], "unrecognized toolchain target")
    expected_archive = "libgodot-cpp." + target + ".template_debug.x86_64.a"
    archive_count = 0
    lines = []
    for line in value.replace("\r\n", "\n").splitlines():
        line = line.strip()
        if not line or line.startswith("Build host:"):
            # Build location is recorded verbatim in both manifests, but is not
            # compiler identity; local and hosted receipts may name it differently.
            continue
        match = re.fullmatch(r"([0-9a-f]{64})[ \t]+\*?(.+)", line)
        if match:
            name = match[2].replace("\\", "/").rsplit("/", 1)[-1]
            require(name == expected_archive, "unrecognized toolchain archive identity")
            archive_count += 1
            line = match[1] + "  " + name
        lines.append(line)
    normalized = "\n".join(lines)
    require(archive_count == 1, "exactly one godot-cpp archive hash is required")
    require(re.search(r"(?m)^godot-cpp=[0-9a-f]{40}; SCons=[0-9]+\.[0-9]+\.[0-9]+$", normalized) is not None,
            "godot-cpp source or SCons identity missing")
    if target == "linux":
        require(re.search(r"(?m)^(?:g\+\+|c\+\+|gcc)(?:-[0-9]+)? .*\d+\.\d+\.\d+", normalized) is not None
                and re.search(r"(?m)^GNU ld .*\d+\.\d+", normalized) is not None,
                "Linux compiler/linker identity missing")
    else:
        require(re.search(r"(?m)^clang version \d+\.\d+\.\d+", normalized) is not None
                and re.search(r"(?m)^LLD \d+\.\d+", normalized) is not None
                and re.search(r"(?m)^LLVM-MinGW=.+archive SHA-256=[0-9a-f]{64}$", normalized) is not None,
                "Windows compiler/linker/toolchain archive identity missing")
    return normalized


def comparable_builds(control_manifest, r_manifest):
    """Require equal compiled inputs; deliberately allow host/test-source drift."""
    require(control_manifest.get("platform", platform_paths()["platform"]) ==
            r_manifest.get("platform", platform_paths()["platform"]), "paired runtime platforms differ")
    control_toolchain = normalized_toolchain(control_manifest)
    require(control_toolchain == normalized_toolchain(r_manifest), "Control/R compiler or dependency identities differ")
    selected = {}
    for path in sorted(COMPARABLE_BUILD_INPUTS):
        expected = control_manifest["build_inputs"].get(path)
        require(isinstance(expected, str) and bool(re.fullmatch(r"[0-9a-f]{64}", expected)),
                "Control compiler/build input missing: " + path)
        require(expected == r_manifest["build_inputs"].get(path), "Control/R compiler/build input differs: " + path)
        selected[path] = expected
    return {"normalized_toolchain": control_toolchain, "compiled_build_input_hashes": selected,
            "scope": "Equal compiler/linker/SCons/godot-cpp archive and runtime build scripts/locks; host/test resources may differ."}


def platform_paths():
    require(platform.system() in ["Linux", "Windows"], "only Linux/Windows desktop runtimes are qualified")
    windows = platform.system() == "Windows"
    return {
        "platform": "windows" if windows else "linux",
        "artifact": "godot/addons/cybersand_native/bin/" + ("cybersand_native.windows.x86_64.dll" if windows else "libcybersand_native.linux.x86_64.so"),
        "manifest": "godot/addons/cybersand_native/" + ("runtime-provenance.json" if windows else "runtime-provenance.linux.json"),
        "rapier_manifest": "godot/addons/godot-rapier2d/runtime-provenance." + ("windows" if windows else "linux") + ".json",
    }


def authenticate_runtime(manifest_path, runtime, candidate, head):
    manifest = read_json(manifest_path)
    paths = platform_paths()
    require(manifest["artifact"] == paths["artifact"], "runtime manifest selects the wrong platform library")
    require(manifest.get("platform", paths["platform"]) == paths["platform"], "wrong manifest platform")
    source = manifest["source_commit"]
    require(bool(re.fullmatch(r"[0-9a-f]{40}", source)), "runtime source commit must be a full Git SHA")
    require(manifest["source_tree"] == git_value(source + "^{tree}"), "runtime source tree differs from Git")
    roster = native_roster(head)
    require(set(manifest["source_inputs"]) == roster == native_roster(source), "incomplete native input roster")
    ledgers = canonical_input_ledgers(source, candidate)
    require(manifest["source_inputs"] == ledgers["source_inputs"], "runtime native source hashes differ from canonical Git inputs")
    require(manifest.get("build_inputs") == ledgers["build_inputs"], "runtime build input ledger is incomplete or differs from canonical Git inputs")
    normalized_toolchain(manifest)
    require(digest(runtime) == manifest["sha256"] and runtime.stat().st_size == manifest["size"], "runtime artifact bytes differ")
    require(not runtime.read_bytes().startswith(b"version https://git-lfs.github.com/spec/v1"), "runtime is an LFS pointer")
    if candidate == "R":
        for path, expected in manifest["source_inputs"].items():
            require(hashlib.sha256((ROOT/path).read_bytes().replace(b"\r\n", b"\n")).hexdigest() == expected,
                    "R source differs from current candidate: " + path)
    else:
        expected_world = hashlib.sha256(commit_blobs(BASE, ["native/src/world.cpp"])["native/src/world.cpp"]).hexdigest()
        require(manifest["source_inputs"]["native/src/world.cpp"] == expected_world, "Control is not frozen-main World source")
    request_present = publication.engine.REQUEST in ledgers["build_inputs"]
    return {"candidate": candidate, "manifest": manifest, "manifest_path": str(manifest_path.resolve()),
            "publication_request_present": request_present,
            "provenance_scope": "graphical-source-authentication; does not authorize runtime publication",
            "manifest_sha256": digest(manifest_path), "runtime_path": str(runtime.resolve()), "runtime_sha256": digest(runtime)}


def source_identity(engine, expected_head):
    head = git_value("HEAD")
    require(head == expected_head, "campaign checkout advanced from expected candidate")
    paths = git("ls-tree", "-rz", "--name-only", head).decode().split("\0")
    required_identity = GRAPHICAL_HELPER_INPUTS | {
        "godot/project.godot", "godot/tests/support/ci_execution_policy.json",
        "third_party/godot-runtime.lock.json", platform_paths()["rapier_manifest"],
    }
    require(required_identity.issubset(paths), "required graphical identity input is untracked or missing")
    selected = [p for p in paths if (p.startswith("godot/") and Path(p).suffix in
        {".gd", ".tscn", ".tres", ".gdshader", ".gdextension"}) or p.startswith("tools/render_copy/")
        or p in required_identity]
    required_harness = {"godot/tests/bench_render_copy_publication.gd",
                        "godot/tests/support/render_copy_worker.gd",
                        "godot/tests/support/render_copy_consumer.gd",
                        "godot/tests/support/render_copy_trace.gd",
                        "tools/render_copy/run_graphical_campaign.py"}
    require(required_harness.issubset(selected), "graphical apparatus must be committed before qualification")
    blobs = commit_blobs(head, selected)
    for path, data in blobs.items():
        require((ROOT/path).read_bytes().replace(b"\r\n", b"\n") == data, "dirty host/harness source: " + path)
    version = subprocess.check_output([str(engine), "--version"], timeout=watchdog_seconds("operation_seconds"), text=True).strip()
    require(version == GODOT_VERSION, "wrong Godot runtime version")
    rapier_path = ROOT/platform_paths()["rapier_manifest"]
    rapier = read_json(rapier_path)
    require(digest(ROOT/rapier["artifact"]) == rapier["sha256"], "installed Rapier differs from provenance")
    return {"frozen_main": BASE, "head": head, "tree": git_value("HEAD^{tree}"),
            "historical_apparatus_source": HISTORICAL_APPARATUS,
            "source_hashes": {p: hashlib.sha256(data).hexdigest() for p,data in blobs.items()},
            "engine_sha256": digest(engine), "engine_path": str(engine), "engine_version": version,
            "rapier_sha256": rapier["sha256"], "rapier_manifest_sha256": digest(rapier_path),
            "platform": platform.platform(), "machine": platform.machine(), "logical_cpus": os.cpu_count(),
            "render_environment": {key: os.environ.get(key) for key in ["DISPLAY", "LIBGL_ALWAYS_SOFTWARE", "LP_NUM_THREADS", "GALLIVM_PERF"]}}


def percentiles(values):
    require(all(isinstance(value, (int, float)) and math.isfinite(value) for value in values),
            "non-finite timing value")
    values = sorted(values)
    if not values:
        return {"n": 0}
    return {"n": len(values), **{label: values[min(len(values)-1, math.ceil(len(values)*q)-1)]
        for label, q in [("p50", .5), ("p95", .95), ("p99", .99), ("max", 1)]}}

def reduce_trace(data):
    events = data["events"]
    if data.get("schema_version") != 1 or not data.get("display") or data.get("display") == "headless":
        raise ValueError("unrecognized or non-graphical receipt")
    if data["arm"] not in ["N", "W"] or data["candidate"] not in ["control", "R"]:
        raise ValueError("unknown arm or candidate")
    if not re.fullmatch(r"[0-9a-f]{64}", data["runtime_sha256"]):
        raise ValueError("runtime hash missing")
    if [e["event_sequence"] for e in events] != list(range(1, len(events)+1)):
        raise ValueError("event sequence is incomplete or reordered")
    if any(not isinstance(e["usec"], (int, float)) or not math.isfinite(e["usec"]) or e["usec"] < 0 for e in events):
        raise ValueError("invalid event clock")
    if data["dropped"] or data["failures"]:
        raise ValueError("failed/truncated graphical trace")
    counts = data["counts"]
    if Counter(e["event"] for e in events) != counts:
        raise ValueError("event/counter mismatch")
    if data["png_error"] != 0 or counts.get("texture_success", 0) <= 20 or counts.get("reject", 0):
        raise ValueError("missing successful graphical consumer activity")
    if "candidate" in data:
        if not data["final_cpu_native_equal"] or not data["final_texture_image_equal"]:
            raise ValueError("final CPU/native/texture parity failed")
        if data["candidate"] not in ["control", "R"]: raise ValueError("unknown candidate")
        expected_script="res://tests/support/render_copy_worker.gd"
        if data.get("owner_script",expected_script) != expected_script: raise ValueError("wrong candidate owner")
    def select(kind): return [e for e in events if e["event"] == kind]
    if data.get("accepted_pulses") != 120 or data.get("post_reset_cells_correct") != 60:
        raise ValueError("emission workload was refused or under-applied after reset")
    emissions, resets = select("emission_queued"), select("reset_request")
    if len(emissions) != 120 or len(resets) != 1 or resets[0].get("frame") != 120:
        raise ValueError("incomplete emission/reset event population")
    for pulse, event in enumerate(emissions):
        frame = pulse * 2
        # CyberCellWorld's stable material IDs: Water=3, Sand=2.
        material = 3 if pulse % 2 == 0 else 2
        if (event.get("frame") != frame or event.get("x") != 400 + pulse or event.get("y") != 250
                or event.get("material") != material or event.get("accepted") is not True):
            raise ValueError("emission event differs from registered workload")
    if resets[0]["event_sequence"] >= emissions[60]["event_sequence"]:
        raise ValueError("reset was not queued before the frame120 emission")
    tail_summary={}
    if "tail_drained" in data:
        starts=select("tail_begin")
        ends=select("tail_caught_up")
        if (not data["tail_drained"] or len(starts)!=1 or len(ends)!=1
                or ends[0]["owner_count"]-starts[0]["owner_count"]<2
                or ends[0]["generation"]!=2 or ends[0]["revision"]!=ends[0]["simulation_revision"]):
            raise ValueError("ordinary publication tail did not catch up")
        tail_summary={"duration_usec":data["tail_elapsed_usec"],
            "counts":dict(Counter(e["event"] for e in events if e["usec"]>=starts[0]["usec"])),
            "frame_intervals_exclude_tail":True}
    calls = select("native_end")
    begins = select("native_begin")
    call_keys=[(e["refresh"],e["call"]) for e in calls]
    if (len(call_keys)!=len(set(call_keys)) or sorted(call_keys)!=sorted((e["refresh"],e["call"]) for e in begins)
            or any(e["call"] not in [1,2] or e["duration_usec"]<0 or e["end_usec"]-e["start_usec"]!=e["duration_usec"] for e in calls)):
        raise ValueError("invalid native call pairing or duration")
    owner_ends=select("owner_end")
    for refresh in {e["refresh"] for e in calls}:
        if sum(e["refresh"]==refresh for e in owner_ends)!=1:
            raise ValueError("missing/duplicate owner publication")
    retry_causes = []
    for retry in [e for e in calls if e["call"] == 2]:
        first = [e for e in events if e["event"] == "dirty_onto_full" and e["refresh"] == retry["refresh"]]
        if len(first) != 1 or not first[0]["before"]["full"] or not first[0]["byte_overflow"]:
            raise ValueError("unexplained retry")
        retry_causes.append({"refresh": retry["refresh"], "byte": first[0]["byte_overflow"],
            "rectangles": first[0]["rectangle_overflow"], "status": next(e["status"] for e in calls
                if e["refresh"] == retry["refresh"] and e["call"] == 1)})
    durations = {}
    for begin, end, name in [("validation_begin", "validation_end", "validation_usec"),
            ("patch_begin", "patch_end", "patch_including_validation_usec"),
            ("texture_update_begin", "texture_update_end", "texture_update_call_usec"),
            ("texture_begin", "texture_success", "texture_submission_usec")]:
        starts = select(begin)
        ends = select(end)
        if len(starts) != len(ends): raise ValueError("unpaired consumer events")
        if any(a.get("serial") != b.get("serial") or a.get("generation") != b.get("generation") for a,b in zip(starts,ends)):
            raise ValueError("consumer identity changed inside operation")
        values = [b["usec"]-a["usec"] for a,b in zip(starts, ends)]
        if any(value < 0 for value in values): raise ValueError("negative consumer duration")
        durations[name] = percentiles(values)
    # CPU image work excludes the nested complete-payload validation interval.
    patches, validations = select("patch_begin"), select("validation_begin")
    if len(patches) != len(validations): raise ValueError("patch/validation populations differ")
    for a,b,c,d in zip(patches, select("patch_end"), validations, select("validation_end")):
        if (not a["usec"] <= c["usec"] <= d["usec"] <= b["usec"]
                or a.get("serial") != c.get("serial") or a.get("generation") != c.get("generation")):
            raise ValueError("validation is not nested in the matching CPU patch")
    patch_values = [(b["usec"]-a["usec"])-(d["usec"]-c["usec"])
        for a,b,c,d in zip(patches,select("patch_end"),validations,select("validation_end"))]
    if any(value < 0 for value in patch_values): raise ValueError("negative exclusive patch duration")
    durations["cpu_patch_usec"] = percentiles(patch_values)
    clears = select("ack_clear")
    ack_latency = []
    for clear in clears:
        eligible = [e for e in select("ack_issue") if e["serial"] == clear["ack_serial"] and e["usec"] <= clear["usec"]]
        if not eligible or clear["ack_serial"] < clear["pending_serial"]:
            raise ValueError("clear without a covering ACK")
        ack_latency.append(clear["usec"] - eligible[-1]["usec"])
    # Verify every observed World generation starts with a complete replacement.
    seen_generations = set()
    for e in calls:
        if e["generation"] not in seen_generations:
            if not e["complete_full"]: raise ValueError("new generation did not start with an exact complete full packet")
            seen_generations.add(e["generation"])
    if seen_generations != {1,2}: raise ValueError("missing reset generation")
    successes = select("texture_success") + select("texture_create_success")
    for ack in select("ack_issue") + select("ack_withheld"):
        if not any(e["serial"] == ack["serial"] and e["usec"] < ack["usec"] for e in successes):
            raise ValueError("ACK before successful upload")
    if data["arm"] == "W" and (select("ack_issue") or clears): raise ValueError("withheld control acknowledged")
    if data["arm"] == "N" and not select("ack_issue"): raise ValueError("normal arm has no ACK")
    first_calls = [e for e in calls if e["call"] == 1]
    retries = {e["refresh"] for e in calls if e["call"] == 2}
    chains, chain = [], 0
    for call in first_calls:
        if call["refresh"] in retries:
            chain += 1
        elif chain:
            chains.append(chain)
            chain = 0
    if chain: chains.append(chain)
    frames, frame_starts = select("frame_end"), select("frame_begin")
    if len(frames) != 240 or len(frame_starts) != 240 or len(data["frame_usec"]) != 240:
        raise ValueError("incomplete frame population")
    for index, (begin, frame, duration) in enumerate(zip(frame_starts, frames, data["frame_usec"])):
        if (begin["frame"] != index or frame["frame"] != index
                or begin["start_usec"] != frame["start_usec"]
                or frame["end_usec"]-frame["start_usec"] != duration
                or frame["duration_usec"] != duration or duration < 0):
            raise ValueError("invalid frame pairing or duration")
    retry_calls = [e for e in calls if e["call"] == 2]
    overlap = [frame["duration_usec"] for frame in frames if any(
        e["start_usec"] < frame["end_usec"] and e["end_usec"] > frame["start_usec"] for e in retry_calls)]
    rates = {key: counts.get(key, 0)/max(1,counts.get("refresh", 0))
             for key in ["dirty_onto_full", "forced_retry", "full_publication", "ack_clear"]}
    return {"counts": counts, "retry_causes": retry_causes, "tail":tail_summary,
        "native_exchange_usec": percentiles([e["duration_usec"] for e in calls]),
        "native_first_usec": percentiles([e["duration_usec"] for e in calls if e["call"] == 1]),
        "native_retry_usec": percentiles([e["duration_usec"] for e in calls if e["call"] == 2]),
        "worker_publication_usec": percentiles([e["duration_usec"] for e in select("owner_end") if e["calls"] > 0]),
        "ack_to_clear_usec": percentiles(ack_latency), "frame_usec": percentiles(data["frame_usec"]),
        "retry_chain_lengths": chains, "max_consecutive_retry_refreshes": max(chains, default=0),
        "counts_per_refresh": rates, "frame_overlapping_retry_usec": percentiles(overlap),
        "native_full_usec": percentiles([e["duration_usec"] for e in calls if e["packet_full"]]),
        "native_bytes_per_refresh": sum(e["packet_bytes"] for e in calls)/max(1,counts.get("refresh",0)),
        "pending_high_water": data["pending_high_water"], "generations": sorted(seen_generations), **durations}


def cohort_summaries(rows):
    """Retain process variability; never substitute pooled percentiles for it."""
    output = {}
    for candidate in ["control", "R"]:
        for arm in ["N", "W"]:
            selected = [row["summary"] for row in rows if row["candidate"] == candidate
                        and row["arm"] == arm and row.get("exit") == 0
                        and "summary" in row and "reader_failure" not in row]
            counts = Counter()
            for summary in selected:
                counts.update(summary["counts"])
            timing_keys = ["native_exchange_usec", "native_full_usec", "native_retry_usec",
                          "worker_publication_usec", "cpu_patch_usec", "texture_submission_usec",
                          "texture_update_call_usec", "ack_to_clear_usec", "frame_usec"]
            distributions = {}
            for key in timing_keys:
                distributions[key] = {
                    label: percentiles([s[key][label] for s in selected if label in s[key]])
                    for label in ["p50", "p95", "p99", "max"]
                }
            output[f"{candidate}-{arm}"] = {
                "successful_processes": len(selected), "counts": dict(counts),
                "counts_per_refresh": {key: counts[key]/max(1, counts["refresh"])
                    for key in ["dirty_onto_full", "forced_retry", "full_publication", "ack_clear"]},
                "max_consecutive_retry_refreshes": max(
                    [s["max_consecutive_retry_refreshes"] for s in selected], default=0),
                "per_process_timing_distributions": distributions,
                "timing_aggregation": "Distributions of process percentiles; each process remains individually reported.",
            }
    return output


class CampaignBudgetExhausted(RuntimeError):
    """A fresh process cannot receive its complete unchanged allowance."""


def campaign_plan(repeats):
    """Keep the registered candidate/ACK order explicit in incomplete receipts."""
    cells = []
    for repeat in range(repeats):
        candidates = ["control", "R"] if repeat % 2 == 0 else ["R", "control"]
        arms = ["N", "W"] if repeat % 2 == 0 else ["W", "N"]
        for arm in arms:
            for candidate in candidates:
                cells.append({"candidate": candidate, "arm": arm, "repeat": repeat,
                              "campaign_sequence": len(cells)+1})
    return cells


def process_admission(execution_seconds, elapsed_seconds, policy):
    """Reserve a complete process, its two actual waits, readback and final evidence.

    This is admission accounting only. No remaining-budget value is passed into
    run_process, and an admitted process retains its full policy watchdog.
    Explicit elapsed inputs make the boundary testable without fake engine runs.
    """
    require(math.isfinite(elapsed_seconds) and elapsed_seconds >= 0, "invalid campaign elapsed time")
    require(execution_seconds is None or (math.isfinite(execution_seconds) and execution_seconds > 0),
            "execution seconds must be finite and positive")
    values = policy["watchdogs"]
    reserved = {
        "case_watchdog_seconds": values["graphical_case_seconds"],
        "terminate_wait_seconds": values["terminate_grace_seconds"],
        "kill_wait_seconds": values["terminate_grace_seconds"],
        "readback_seconds": values["operation_seconds"],
        "final_evidence_seconds": values["aggregate_headroom_seconds"],
    }
    required = sum(reserved.values())
    remaining = None if execution_seconds is None else execution_seconds-elapsed_seconds
    admitted = remaining is None or remaining >= required
    return {"admitted": admitted, "execution_seconds": execution_seconds,
            "elapsed_seconds": elapsed_seconds, "remaining_seconds": remaining,
            "required_seconds": required, "reserved_seconds": reserved,
            "reason": "complete_case_allowance_available" if admitted else "aggregate_allowance_exhausted"}


def run_process(engine, receipt, candidate, arm, runtime_identity, engine_args):
    installed = ROOT/platform_paths()["artifact"]
    argv = [str(engine), "--audio-driver", "Dummy", "--path", str(ROOT/"godot"),
            "--resolution", "960x540", *engine_args, "--script",
            "res://tests/bench_render_copy_publication.gd", "--", f"--arm={arm}",
            f"--receipt={receipt}", f"--candidate={candidate}",
            f"--runtime-path={installed}", f"--runtime-sha256={runtime_identity['runtime_sha256']}"]
    log_path = receipt.with_suffix(".log")
    started = time.monotonic()
    with log_path.open("xb") as log:
        process = subprocess.Popen(argv, stdout=log, stderr=subprocess.STDOUT)
        try:
            code = process.wait(timeout=watchdog_seconds("graphical_case_seconds"))
        except subprocess.TimeoutExpired:
            process.terminate()
            try:
                process.wait(timeout=watchdog_seconds("terminate_grace_seconds"))
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=watchdog_seconds("terminate_grace_seconds"))
            code = "timeout"
    row = {"candidate": candidate, "arm": arm, "argv": argv, "exit": code,
           "seconds": time.monotonic()-started, "process_id": process.pid,
           "log_path": str(log_path), "log_sha256": digest(log_path),
           "runtime_sha256": runtime_identity["runtime_sha256"],
           "runtime_source_commit": runtime_identity["manifest"]["source_commit"]}
    log_text = log_path.read_text(encoding="utf-8", errors="replace")
    failures = []
    if "SCRIPT ERROR:" in log_text or "ERROR:" in log_text:
        failures.append("engine error in retained log")
    if receipt.is_file():
        row.update(raw_path=str(receipt), raw_sha256=digest(receipt))
        png = Path(str(receipt)+".png")
        if png.is_file():
            row.update(png_path=str(png), png_sha256=digest(png))
        else:
            failures.append("framebuffer witness missing")
        try:
            raw = read_json(receipt)
            require(raw["arm"] == arm and raw["candidate"] == candidate, "launched arm/candidate mismatch")
            require(raw["process_id"] == process.pid, "receipt belongs to a different process")
            require(raw["runtime_sha256"] == runtime_identity["runtime_sha256"], "loaded runtime hash mismatch")
            row["summary"] = reduce_trace(raw)
            row["graphics"] = {key: raw[key] for key in ["display", "renderer", "adapter", "os", "engine"]}
        except (ValueError, KeyError, TypeError, StopIteration) as error:
            failures.append(str(error))
    else:
        failures.append("fresh graphical receipt missing")
    if failures:
        row["reader_failure"] = failures
    return row


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--expected-candidate-sha", required=True)
    parser.add_argument("--control-runtime", required=True, type=Path)
    parser.add_argument("--control-manifest", required=True, type=Path)
    parser.add_argument("--r-runtime", required=True, type=Path)
    parser.add_argument("--r-manifest", required=True, type=Path)
    parser.add_argument("--repeats", type=int, default=5)
    parser.add_argument("--execution-seconds", type=float,
                        help="Optional aggregate admission budget, including source checks and evidence; admitted case watchdogs are never shortened.")
    parser.add_argument("--engine-arg", action="append", default=[],
                        help="Extra actual graphical engine argument; use --engine-arg=--display-driver syntax.")
    args = parser.parse_args()
    require(3 <= args.repeats <= 10, "require 3–10 fresh processes per candidate/cohort")
    require("--headless" not in args.engine_arg, "headless execution is not graphical qualification")
    campaign_started = time.monotonic()
    budget_policy = execution_policy_identity()
    initial_allowance = process_admission(args.execution_seconds, 0, budget_policy)
    plan = campaign_plan(args.repeats)
    args.engine = args.engine.resolve()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=False)
    identity = source_identity(args.engine, args.expected_candidate_sha)
    runtimes = {
        "control": authenticate_runtime(args.control_manifest, args.control_runtime, "control", identity["head"]),
        "R": authenticate_runtime(args.r_manifest, args.r_runtime, "R", identity["head"]),
    }
    delta = [path for path, value in runtimes["control"]["manifest"]["source_inputs"].items()
             if value != runtimes["R"]["manifest"]["source_inputs"][path]]
    require(delta == ["native/src/world.cpp"], "Control/R native delta is not exclusively World render-copy source")
    require(runtimes["control"]["runtime_sha256"] != runtimes["R"]["runtime_sha256"], "Control and R runtime bytes are identical")
    build_comparison = comparable_builds(runtimes["control"]["manifest"], runtimes["R"]["manifest"])
    installed = ROOT/platform_paths()["artifact"]
    for runtime in runtimes.values():
        require(Path(runtime["runtime_path"]).resolve() != installed.resolve(), "candidate runtime must be a separate immutable file")
    original = args.output/"original-installed-runtime.bin"
    shutil.copy2(installed, original)
    original_hash = digest(original)
    inputs = {"identity": identity, "runtimes": runtimes, "original_installed_runtime_sha256": original_hash,
              "native_source_delta": delta, "comparable_builds": build_comparison, "repeats": args.repeats,
              "planned_processes": plan, "execution_allowance": initial_allowance,
              "execution_policy": budget_policy,
              "ordering": "Each repeat alternates candidate and ACK order; candidates run sequentially on the same host.",
              "scope": "Real Main graphical submission/readback; CPU frame intervals, not GPU completion or human pacing."}
    (args.output/"inputs.json").write_text(json.dumps(inputs, indent=2)+"\n", encoding="utf-8")
    rows, fatal_error = [], None
    admissions, unstarted = [], []
    final_source_verified = False
    try:
        for index, cell in enumerate(plan):
            candidate, arm, repeat = cell["candidate"], cell["arm"], cell["repeat"]
            runtime = runtimes[candidate]
            require(digest(runtime["runtime_path"]) == runtime["runtime_sha256"], "candidate runtime changed during campaign")
            shutil.copyfile(runtime["runtime_path"], installed)
            require(digest(installed) == runtime["runtime_sha256"], "runtime installation hash mismatch")
            receipt = args.output/f"{repeat:02d}-{candidate}-{arm}.json"
            # Account for source checks and installation before admitting this
            # fresh engine process; no remaining-budget value alters its waits.
            allowance = process_admission(args.execution_seconds, time.monotonic()-campaign_started, budget_policy)
            admissions.append({**cell, **allowance})
            if not allowance["admitted"]:
                unstarted = [{**pending, "status": "not_started", "reason": allowance["reason"]}
                             for pending in plan[index:]]
                raise CampaignBudgetExhausted(
                    f"Cannot start {candidate}/{arm}/repeat{repeat}: "
                    f"{allowance['remaining_seconds']:.3f}s remain, "
                    f"{allowance['required_seconds']:.3f}s required for the complete case, "
                    f"cleanup, readback and final evidence; {len(unstarted)} named cells were not started")
            row = run_process(args.engine, receipt, candidate, arm, runtime, args.engine_arg)
            row.update(repeat=repeat, campaign_sequence=cell["campaign_sequence"])
            rows.append(row)
            (args.output/"processes.json").write_text(json.dumps(rows, indent=2)+"\n", encoding="utf-8")
            print(candidate, arm, repeat, row["exit"], row.get("summary", {}).get("counts", {}), flush=True)
            require(digest(installed) == runtime["runtime_sha256"], "installed runtime changed during process")
        require(source_identity(args.engine, args.expected_candidate_sha) == identity, "host/harness source changed during campaign")
        for candidate, runtime in runtimes.items():
            checked = authenticate_runtime(Path(runtime["manifest_path"]), Path(runtime["runtime_path"]), candidate, identity["head"])
            require(checked == runtime, "runtime source manifest changed during campaign")
        final_source_verified = True
    except Exception as error:
        fatal_error = f"{type(error).__name__}: {error}"
        raise
    finally:
        shutil.copyfile(original, installed)
        restored = digest(installed) == original_hash
        elapsed = time.monotonic()-campaign_started
        if args.execution_seconds is not None and elapsed > args.execution_seconds and fatal_error is None:
            fatal_error = "CampaignBudgetExhausted: aggregate allowance exceeded during readback/final evidence"
        matrix_complete = len(rows) == len(plan) and not unstarted
        passed = (restored and final_source_verified and matrix_complete and fatal_error is None
                  and all(row["exit"] == 0 and "summary" in row and "reader_failure" not in row for row in rows))
        report = {**inputs, "processes": rows, "cohorts": cohort_summaries(rows),
                  "admissions": admissions, "unstarted_processes": unstarted,
                  "elapsed_seconds": elapsed, "process_matrix_complete": matrix_complete,
                  "final_source_verified": final_source_verified, "status": "passed" if passed else "failed",
                  "original_runtime_restored": restored, "fatal_error": fatal_error}
        (args.output/"report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
        require(restored, "original installed runtime was not restored")
    require(len(rows) == args.repeats*4, "campaign process matrix incomplete")
    require(report["status"] == "passed", "campaign source/evidence/aggregate allowance qualification failed")
    require(all(row["exit"] == 0 and "summary" in row and "reader_failure" not in row for row in rows),
            "graphical campaign contains failed processes; originals remain retained")


if __name__ == "__main__":
    main()
