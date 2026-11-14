#!/usr/bin/env python3
"""Verify genuine C2048 baseline/candidate Windows GDExtension identity before Godot A/B.

Only writes source-build manifests for the existing independent #505 runner.
Never overwrites any Git LFS runtime or commits publication metadata.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

MAIN = "24a8bbe8ccf0d17196ebbab580b924930a964584"
BASE_BUILD = "3b41f020a8616052d72666ed65624d9b1447a419"
CANDIDATE_BUILD = "b7f151f85676ffc6b2ea87f3e5c6165b890727e0"
CANDIDATE_PR = "186452b9f035961325ad71917a76ba8834e30bcf"
LLVM_SHA = "cee8d2ce3da5145ce4dc882e70d0b0719a783d53a99752c60948fc0659975a65"
GODOT_CPP = "101ae38034304346a46ea9ea84ae156d3e860496"
WINDOWS_DLL = "cybersand_native.windows.x86_64.dll"

def run(*args: str) -> str:
    return subprocess.check_output(args, text=True, timeout=45).strip()

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def stop_unless(condition: bool, msg: str) -> None:
    if not condition:
        raise RuntimeError(msg)

def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--app", required=True)
    p.add_argument("--candidate", required=True)
    p.add_argument("--out", required=True)
    args = p.parse_args()
    app = Path(args.app).resolve()
    cand = Path(args.candidate).resolve()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    baseline = app / "godot/addons/cybersand_native/bin" / WINDOWS_DLL
    pvd = app / "godot/addons/cybersand_native/runtime-provenance.json"
    artifact = cand / WINDOWS_DLL
    for f in (baseline, pvd, artifact, cand/"source-sha.txt", cand/"toolchain.txt", cand/"runtime.sha256"):
        stop_unless(f.is_file(), "Missing source/runtime artifact: " + str(f))
    stop_unless(run("git", "-C", str(app), "rev-parse", "HEAD") == MAIN,
                "Host application must be exact accepted C2048 main")
    provenance = json.loads(pvd.read_text(encoding="utf-8"))
    stop_unless(provenance["source_commit"] == BASE_BUILD and provenance["build_commit"] == BASE_BUILD,
                "Accepted baseline runtime provenance does not attest exact source")
    stop_unless(provenance["sha256"] == sha(baseline),
                "Baseline native DLL does not match production C2048 SHA")
    stop_unless(provenance["size"] == baseline.stat().st_size, "Baseline DLL size mismatch")
    stop_unless(LLVM_SHA in provenance["toolchain"] and GODOT_CPP in provenance["toolchain"],
                "Baseline compiler is not pinned LLVM-MinGW / godot-cpp")
    stop_unless((cand/"source-sha.txt").read_text().strip() == CANDIDATE_BUILD,
                "Candidate DLL was not built from the pinned PR merge source")
    toolchain = (cand/"toolchain.txt").read_text()
    stop_unless("llvm_mingw_sha256="+LLVM_SHA in toolchain and
                "godot_cpp_commit="+GODOT_CPP in toolchain,
                "Candidate and baseline LLVM-MinGW/godot-cpp pin mismatch")
    cand_hash = sha(artifact)
    checksums = (cand/"runtime.sha256").read_text()
    stop_unless(cand_hash in checksums and WINDOWS_DLL in checksums,
                "Candidate archive did not bind its DLL SHA to source build")
    stop_unless(cand_hash != sha(baseline), "The two native runtimes are byte-identical")
    # The accepted runtime was source-built immediately before production publication,
    # which only updated the two native LFS pointers and provenance ledgers.
    prior_diff = run("git", "-C", str(app), "diff", "--name-only", BASE_BUILD, MAIN, "--",
                     "native/src", "native/include", "godot/native_extension", "godot/scripts",
                     "tools/build_native_extension_windows.sh", "tools/build_pinned_godot_cpp.sh")
    stop_unless(not prior_diff, "Baseline source/runtime diverged after publication: "+prior_diff)
    # Candidate is a synthetic two-parent PR merge; build source is pinned to its
    # exact merge commit, not its PR head or a mutable branch ref.
    parentage = run("git", "-C", str(app), "rev-list", "--parents", "-n", "1", CANDIDATE_BUILD).split()
    stop_unless(len(parentage) == 3 and MAIN in parentage and CANDIDATE_PR in parentage,
                "Candidate artifact source does not merge pinned PR head into accepted main")
    core_diff = run("git", "-C", str(app), "diff", "--name-only", MAIN, CANDIDATE_BUILD, "--",
                    "native/src", "native/include", "godot/native_extension", "godot/scripts",
                    "godot/main.tscn", "godot/project.godot",
                    "tools/build_native_extension_windows.sh", "tools/build_pinned_godot_cpp.sh")
    stop_unless(core_diff.strip() == "native/src/world_pressure.inc",
                "Uncontrolled production or host difference: "+core_diff)
    tree = lambda rev: run("git", "-C", str(app), "rev-parse", rev+"^{tree}")
    profile = "Godot 4.7/template_debug; pinned godot-cpp="+GODOT_CPP
    compiler = "LLVM-MinGW 20260826 UCRT; sha256="+LLVM_SHA
    flags = "-std=c++20 -O3 -DNDEBUG -DWINDOWS_ENABLED -shared -pthread; SCons=4.10.1"
    records = [
        ("baseline", BASE_BUILD, baseline, provenance.get("workflow_run", "")),
        ("candidate", CANDIDATE_BUILD, artifact, "42333533378"),
    ]
    for role, commit, dll, run_id in records:
        manifest = {
            "source_commit": commit, "source_tree_sha": tree(commit),
            "native_sha256": sha(dll),
            "compiler": compiler, "build_flags": flags, "build_profile": profile,
            "build_job_url": "https://github.com/techrote/cybersand/actions/runs/"+str(run_id),
            "application_source_commit": MAIN,
            "candidate_pr_head": CANDIDATE_PR,
            "source_runtime_verification": "PASS; exact single protected native operator changed",
        }
        (out/(role+".json")).write_text(json.dumps(manifest, indent=2, sort_keys=True)+"\n", encoding="utf-8")
        print(role+" source="+commit+" native_sha256="+sha(dll)+" tree="+tree(commit))
    (out/"provenance-comparison.json").write_text(json.dumps({
        "baseline_app_source": MAIN, "baseline_runtime_build_source": BASE_BUILD,
        "candidate_runtime_build_source": CANDIDATE_BUILD,
        "candidate_pr_head": CANDIDATE_PR, "only_production_source_difference": core_diff,
        "compiler": compiler, "build_flags": flags, "build_profile": profile,
        "baseline_binary_sha256": sha(baseline), "candidate_binary_sha256": cand_hash,
        "status": "source/runtime provenance qualified, before gameplay execution"
    },indent=2,sort_keys=True)+"\n",encoding="utf-8")

if __name__ == "__main__":
    main()
