#!/usr/bin/env python3
"""Read-only independent reduction of the seven preserved Windows startup arms.

No Godot or model is run. Original ZIP members, compact custody, source objects,
reported measurements and arithmetic are checked; causal mechanisms are not tested.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess
import zipfile

APP = "bcc92927ce3894a16d5544923cfbf7b1d0339fda"
TREE = "517164084860a19f18b36cb94f77597eb3220578"
APPARATUS = {
    ".github/workflows/art-startup-phase-windows.yml",
    "docs/audits/2026-11-25-art-startup-phase-probe/windows-bcc.md",
    "tools/ci/run_art_startup_phase_probe.py",
    "tools/fixtures/art_startup_phase_probe.gd",
}
ENGINE = {
    "Godot_v4.7-stable_win64.exe": "b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8",
    "Godot_v4.7-stable_win64_console.exe": "d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c",
}
RUNTIME = {
    "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll": "668f2dd094fca611a97c2b6aa38c4cd072179fe9cf591e53578ef57c7db1625e",
    "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll": "b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7",
}
CASES = [
    ("four-arm", "original-artifact.zip", 4981131,
     "c79ffd7960cb02c66d66e1e09d3c6fc167aa288d101b748771b5af2def7ffe1f",
     "original-measurements.zip", "original-measurements-manifest.json", "omitted",
     "four-arm-summary.json", 0),
    ("render-profile", "render-profile-artifact.zip", 619916,
     "8515813ed298f3d1aa5eba9c4eea7456e36af6b96eeb86307495d63b9ebfaf4d",
     "render-profile-measurements.zip", "render-profile-manifest.json", "omitted_reproducible_shader_cache",
     "render-profile-summary.json", 1),
]


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--evidence-dir", type=Path, required=True)
    parser.add_argument("--source-repo", type=Path, required=True)
    parser.add_argument("--source-provenance", type=Path, required=True)
    args = parser.parse_args()
    totals: Counter[str] = Counter()
    failures: list[str] = []

    def check(category: str, condition: bool, detail: str) -> None:
        totals[category] += 1
        if not condition:
            failures.append(f"{category}: {detail}")

    def git(*argv: str) -> bytes:
        return subprocess.check_output(["git", "-C", str(args.source_repo), *argv])

    provenance = json.loads(args.source_provenance.read_text())
    check("source", git("rev-parse", f"{APP}^{{tree}}").decode().strip() == TREE, "application tree")
    check("source", provenance["sources"][0]["parents"] == [APP], "first diagnostic ancestry")
    check("source", provenance["sources"][1]["parents"] == [provenance["sources"][0]["sha"]], "follow-up ancestry")
    for path, item in provenance["pinned_evidence"].items():
        original = (args.evidence_dir / path).read_bytes()
        check("pinned_evidence", item["encoding"] == "utf-8" and original == item["content"].encode(), path)
        git_blob = hashlib.sha1(b"blob " + str(len(original)).encode() + b"\0" + original).hexdigest()
        check("pinned_evidence", git_blob == item["git_blob_sha"], path + " Git blob")
    for path, sha in RUNTIME.items():
        pointer = git("show", f"{APP}:{path}").decode()
        check("source", f"oid sha256:{sha}\n" in pointer, path + " source LFS identity")

    reports = []
    all_contexts = []
    all_inputs = []
    fixture_count = 0
    original_file_count = 0
    for label, full_name, full_bytes, full_sha, compact_name, manifest_name, omit_key, summary_name, source_index in CASES:
        source = provenance["sources"][source_index]
        changed = set(git("diff", "--name-only", APP, source["tree"]).decode().splitlines())
        check("source", changed == APPARATUS, label + " exact four-file apparatus delta")
        apparatus_hashes = {p: digest(git("show", f"{source['tree']}:{p}")) for p in APPARATUS}
        full_raw = (args.evidence_dir / full_name).read_bytes()
        compact_raw = (args.evidence_dir / compact_name).read_bytes()
        check("archive", len(full_raw) == full_bytes and digest(full_raw) == full_sha, full_name + " fixed outer identity")
        if source_index == 0:
            check("archive", len(compact_raw) == 55211 and digest(compact_raw) == "fcd42328682e977c4d6422a7ae6f5bd5da8d0e87ced0ef7cb460f3303c43717b", "corrected compact first archive")
        manifest = json.loads((args.evidence_dir / manifest_name).read_bytes())
        summary = json.loads((args.evidence_dir / summary_name).read_bytes())
        check("derived_index", summary["artifact_sha256"] == full_sha and summary["application_source"] == APP and summary["diagnostic_source"] == source["sha"], label + " index identity")
        with zipfile.ZipFile(args.evidence_dir / full_name) as full, zipfile.ZipFile(args.evidence_dir / compact_name) as compact:
            names = full.namelist()
            check("archive", len(names) == len(set(names)) and all(not PurePosixPath(p).is_absolute() and ".." not in PurePosixPath(p).parts for p in names), full_name + " unique confined member names")
            check("archive", full.testzip() is None and compact.testzip() is None, label + " all member CRCs")
            included = {r["path"]: r for r in manifest["included"]}
            omitted = {r["path"]: r for r in manifest[omit_key]}
            check("archive", len(included) == len(manifest["included"]) and len(omitted) == len(manifest[omit_key]), label + " manifest unique paths")
            check("archive", set(included).isdisjoint(omitted) and set(names) == set(included) | set(omitted), label + " complete manifest partition")
            check("archive", set(compact.namelist()) == set(included) | {"MANIFEST.json"}, label + " compact exact members")
            check("archive", json.loads(compact.read("MANIFEST.json")) == manifest, label + " compact manifest equality")
            for p in names:
                raw = full.read(p)
                item = included.get(p, omitted.get(p))
                check("original_bytes", len(raw) == item["bytes"] and digest(raw) == item["sha256"], p)
                if p in included:
                    check("compact_bytes", compact.read(p) == raw, p)
                else:
                    check("omissions", "/shader_cache/" in p or "editor_doc_cache" in p or p.endswith("debug.keystore"), p + " permitted omission type")
                    if source_index == 0:
                        check("omissions", bool(item.get("reason")), p + " explicit reason")
            original_file_count += len(names)
            check("omissions", not any(p.endswith("debug.keystore") for p in compact.namelist()), label + " no generated signing key in compact archive")
            arms = []
            arm_records = {}
            arm_inputs = {}
            for derived in summary["arms"]:
                name = derived["label"]
                inp = json.loads(full.read(f"{name}/inputs.json"))
                result_raw = full.read(f"{name}/result.json")
                result = json.loads(result_raw)
                fixture = result["fixture"]
                phase_file = json.loads(full.read(f"{name}/phases.json"))
                process_log = full.read(f"{name}/process.log")
                arm_records[name], arm_inputs[name] = result, inp
                all_inputs.append(inp)
                fixture_count += 1
                check("measurements", phase_file == fixture, label + "/" + name + " phase/result identity")
                printed = [s.removeprefix("ART_STARTUP_PHASE_RESULT ") for s in process_log.decode().splitlines() if s.startswith("ART_STARTUP_PHASE_RESULT ")]
                check("measurements", len(printed) == 1 and json.loads(printed[0]) == fixture, name + " process-log complete fixture identity")
                assertions = [s for s in process_log.decode().splitlines() if s.startswith("ART_STARTUP_PHASE_CHECK ")]
                check("measurements", len(assertions) == 27 and all(s.endswith(" true") for s in assertions) and fixture["checks"] == 27 and fixture["failures"] == [], name + " 27 actual original checks")
                check("measurements", result["passed"] is True and result["process"]["returncode"] == 0 and result["process"]["timeout"] is False, name + " process outcome")
                check("measurements", digest(process_log) == result["process"]["log_sha256"], name + " original process-log hash")
                check("measurements", fixture["model_calls"] == result["model_calls"] == fixture["provider_requests"] == 0, name + " no model/provider admission")
                check("source", inp["source"] == result["source"] == result["source_after"] and result["source_unchanged"] and result["source"]["tracked_source_clean"], name + " source custody")
                src = result["source"]
                check("source", src["application_source"] == APP and src["application_tree"] == TREE and src["commit"] == source["sha"] and src["tree"] == source["tree"], name + " canonical diagnostic identity")
                check("source", src["apparatus_sha256"] == apparatus_hashes and src["runtime_sha256"] == RUNTIME and inp["engine_payloads"] == ENGINE, name + " apparatus/recorded runtime identities")
                check("source", fixture["application_source"] == APP and fixture["source_revision"] == source["sha"], name + " fixture source identity")
                check("host", fixture["platform"] == "Windows" and fixture["display"] == ("Windows" if inp["graphical"] else "headless"), name + " actual platform/display")
                check("host", inp["host_before"]["logical_cpus"] == 4 and inp["host_before"]["runner_image_version"] == "20261116.370.1", name + " host allocation")
                check("host", inp["fresh_profile"] == (name != "graphical-reused-profile"), name + " profile scope")
                phases = fixture["phases"]
                phase_sum = sum(phases[k] for k in ("resource_load_main_usec", "scene_instantiate_usec", "add_child_and_synchronous_ready_usec", "remaining_native_install_wait_usec"))
                overhead = phases["workbench_ready_elapsed_usec"] - phase_sum
                check("timing", 0 <= overhead < 10000, name + " phase nesting/positive fixture overhead")
                check("timing", phases["workbench_ready_elapsed_usec"] < fixture["elapsed_usec"] <= result["process"]["wall_seconds"] * 1e6, name + " fixture clock inside process wall")
                check("measurements", phases["native_world_extent"] == [2048, 2048] and phases["configured_native_worker_threads"] == phases["engine_max_fps"] == 0, name + " World/policy unchanged")
                check("derived_index", derived["original_result_sha256"] == digest(result_raw) and derived["phases"] == phases and derived["maximum_observed_frame_gap_usec"] == fixture["maximum_observed_frame_gap_usec"] and derived["host"] == inp["host_before"], name + " derived index original mapping")
                captures = fixture["captures"]
                check("native_context", len(captures) == 3, name + " complete three captures")
                context_record = []
                for capture, size in zip(captures, [64, 256, 512]):
                    check("native_context", capture["region"] == [0, 0, size, size] and capture["cells"] == size * size, name + " observed native extent")
                    check("native_context", capture["source_before"] == capture["source_after"] == {"authoring_generation": 1, "generation": 2, "revision": 2, "tick": 0}, name + " read-only native source")
                    builds = capture["builds"]
                    check("native_context", len(builds) == 3 and len({(b["context_sha256"], b["wire_bytes"]) for b in builds}) == 1, name + " repeated context identity")
                    check("timing", all(0 < b["internal_elapsed_usec"] <= b["wall_usec"] for b in builds), name + " context timer nesting")
                    check("timing", capture["admission_usec"] <= capture["admission_to_callback_usec"] and sum(b["wall_usec"] for b in builds) <= capture["callback_to_observation_usec"], name + " capture/observation timer scope")
                    context_record.append({"region": capture["region"], "context_sha256": builds[0]["context_sha256"], "wire_bytes": builds[0]["wire_bytes"]})
                all_contexts.append(context_record)
                arm = {"label": name, "checks": fixture["checks"], "workbench_ready_usec": phases["workbench_ready_elapsed_usec"], "phase_sum_usec": phase_sum, "unallocated_fixture_overhead_usec": overhead, "maximum_frame_gap_usec": fixture["maximum_observed_frame_gap_usec"], "process_wall_seconds": result["process"]["wall_seconds"], "original_result_sha256": digest(result_raw)}
                if source_index == 0:
                    check("derived_index", derived["captures"] == captures and derived["source"] == src and derived["original_process_log_sha256"] == digest(process_log) and derived["fresh_profile"] == inp["fresh_profile"] and derived["import_before"] == inp["explicit_import_before"], name + " complete four-arm index")
                else:
                    intervals = fixture["render_intervals"]
                    check("timing", len(intervals) == fixture["render_count"] < 128, name + " render interval array complete within cap")
                    for index, interval in enumerate(intervals):
                        check("timing", interval["index"] == index and interval["end_elapsed_usec"] - interval["start_elapsed_usec"] == interval["wall_usec"] and interval["wall_usec"] >= 0, name + " render interval arithmetic")
                    maximum = max(intervals, key=lambda v: v["wall_usec"]) if intervals else {}
                    check("timing", fixture["maximum_render_interval"] == maximum, name + " original maximum from all intervals")
                    check("derived_index", derived["maximum_render_interval"] == maximum and derived["first_render_interval"] == (intervals[0] if intervals else None), name + " indexed interval extrema")
                    frames = fixture["startup_frames"]
                    check("timing", len(frames) == min(fixture["frames"], 64), name + " bounded frame array extent")
                    gaps = [frames[0]["elapsed_usec"]] + [b["elapsed_usec"] - a["elapsed_usec"] for a, b in zip(frames, frames[1:])]
                    check("timing", all(g >= 0 for g in gaps) and max(gaps) == fixture["maximum_observed_frame_gap_usec"], name + " reported maximum reproduced by stored frames")
                    before = inp["profile_shader_cache_before"]
                    after = result["profile_shader_cache_after"]
                    check("derived_index", derived["profile_shader_cache_before"] == len(before) and derived["profile_shader_cache_after"] == len(after), name + " cache count index")
                    arm.update({"first_render_interval": intervals[0] if intervals else None, "maximum_render_interval": maximum, "stored_render_intervals": len(intervals), "stored_startup_frames": len(frames), "cache_before": len(before), "cache_after": len(after)})
                arms.append(arm)
            cache_chain = None
            if source_index == 1:
                first = arm_records["graphical-first"]
                warm = arm_records["graphical-reused-profile"]
                warm_input = arm_inputs["graphical-reused-profile"]
                original_cache = first["profile_shader_cache_after"]
                check("cache_chain", len(original_cache) == 34 and original_cache == warm_input["profile_shader_cache_before"], "complete 34-file output-to-input identity")
                check("cache_chain", warm_input["profile_from"] == "evidence\\graphical-first" and not warm_input["fresh_profile"], "owned same-source sibling profile")
                check("cache_chain", len(warm["profile_shader_cache_after"]) == 35, "retained subsequent extra cache file")
                for p, row in warm["profile_shader_cache_after"].items():
                    raw = full.read("graphical-first/profile/" + p)
                    check("cache_chain", len(raw) == row["bytes"] and digest(raw) == row["sha256"], p + " final actual archive bytes")
                check("cache_chain", all(warm["profile_shader_cache_after"].get(p) == row for p, row in original_cache.items()), "first 34 cache files preserved in final profile")
                fresh_frames = first["fixture"]["startup_frames"]
                draw = first["fixture"]["render_intervals"][0]
                before = draw["start_elapsed_usec"] - fresh_frames[0]["elapsed_usec"]
                after = fresh_frames[1]["elapsed_usec"] - draw["end_elapsed_usec"]
                check("timing", before == 2394 and after == 559 and before + draw["wall_usec"] + after == first["fixture"]["maximum_observed_frame_gap_usec"], "exact first-draw localization bracket")
                cache_chain = {"identical_cache_input_files": len(original_cache), "before_draw_gap_usec": before, "first_draw_usec": draw["wall_usec"], "after_draw_gap_usec": after, "outside_draw_interval_usec": before + after, "whole_profile_reused": True, "os_cache_controlled": False}
            reports.append({"label": label, "source": source, "original_archive": {"file": full_name, "bytes": len(full_raw), "sha256": digest(full_raw), "members_verified": len(names)}, "compact_archive": {"file": compact_name, "bytes": len(compact_raw), "sha256": digest(compact_raw), "original_members": len(included), "omitted_members": len(omitted)}, "arms": arms, "profile_chain": cache_chain})
    check("native_context", len(all_contexts) == 7 and all(x == all_contexts[0] for x in all_contexts), "all seven arms same three model-context identities")
    check("host", all_inputs[0]["host_before"]["processor_identifier"] != all_inputs[4]["host_before"]["processor_identifier"], "four-arm and follow-up different CPU allocations")
    output = {"schema": "art-independent-startup-original-review-v1", "evidence_source": provenance["evidence_ref"], "application_source": APP, "application_tree": TREE, "reviewer": "Specialist B; independent read-only Python/source review of lead-authored diagnostic", "script_sha256": digest(Path(__file__).read_bytes()), "checks": sum(totals.values()), "checks_by_category": dict(totals), "failures": failures, "passed": not failures, "original_fixture_arms": fixture_count, "original_archive_members_verified": original_file_count, "context_identities": all_contexts[0], "campaigns": reports, "limits": ["No application, native World or model rerun was performed by this verifier.", "Native context digest equality concerns three bounded disclosed contexts, not every hidden World byte.", "Recorded runtime hashes are joined to source LFS identities; executable binaries are not present in these measurement archives.", "Diagnostic elapsed time begins after engine bootstrap; process wall is a separate clock.", "The first-draw bracket localizes wall time, not GPU-only execution or a shader function.", "Profile reuse is one fixed-order pair of whole generated profiles; OS caches and host contention are uncontrolled.", "Different AMD and Intel allocations do not support a cross-host causal source comparison.", "Neither production startup repair nor physical Windows/NVIDIA acceptance is claimed."]}
    print(json.dumps(output, indent=2, ensure_ascii=False))
    raise SystemExit(0 if not failures else 1)


if __name__ == "__main__":
    main()
