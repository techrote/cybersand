#!/usr/bin/env python3
"""Explicit bounded qualification request and current Workbench regression driver.

Heavy qualification starts only when the committed request changes or an owner
explicitly dispatches the workflow. No model training is attached to PR pushes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
BASE = "ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742"
DONOR = "bac120981fdd9aecaab0dc8368c421fa390cc269"


def request(path: Path, source_sha: str) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    expected = {"schema": "agent-painter-qualification-v1", "accepted_base": BASE,
                "historical_donor": DONOR, "families": ["greebles", "pipework", "architecture"],
                "native_cases": 30, "training_profile": "smol", "optimizer_steps": 2,
                "resume_from_step": 1, "resume_target_step": 2, "schedules": False,
                "full_training": False, "publish_research_evidence": True}
    if set(data) != set(expected) | {"sequence"}:
        raise ValueError("Unexpected request fields")
    for key, value in expected.items():
        if type(data[key]) is not type(value) or data[key] != value:
            raise ValueError("Unapproved qualification request: " + key)
    if type(data["sequence"]) is not int or not 1 <= data["sequence"] <= 1000:
        raise ValueError("Request needs a positive bounded sequence")
    if not re.fullmatch(r"[0-9a-f]{40}", source_sha):
        raise ValueError("Full immutable source SHA required")
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    if head != source_sha:
        raise ValueError("Checkout differs from requested source")
    subprocess.run(["git", "merge-base", "--is-ancestor", BASE, head], cwd=ROOT, check=True)
    return {"request": data, "source_sha": head,
            "request_sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def regressions(godot: Path, evidence: Path) -> None:
    # Reuse the current accepted runner's completion/error parsing. These are
    # actual mounted production tests, independent of the new pilot generator.
    sys.path.insert(0, str(ROOT / "tools/ci"))
    from run_workbench_qualification import Runner
    evidence = evidence.resolve()
    runner = Runner(argparse.Namespace(godot=godot.resolve(), evidence=evidence))
    project = ROOT / "godot"
    fixtures = [("art_batch", "test_art_batch_native", "ART_STAGE1_RESULT"),
                ("stored_material", "test_art_stored_material", "ART_STORED_RESULT"),
                ("deferred_manual", "test_art_deferred_manual", "ART_DEFERRED_MANUAL")]
    for label, script, marker in fixtures:
        runner.godot(project, label, script, marker)
    for workers in (1, 4):
        runner.godot(project, f"undo_{workers}", "test_art_undo", "ART_UNDO_RESULT",
                     env={"ART_UNDO_WORKERS": str(workers)})
    for mode in ("author", "reopen"):
        runner.godot(project, "combined_" + mode, "test_workbench_combined_authoring",
                     "WB_COMBINED_AUTHORING",
                     env={"WB_COMBINED_WORKERS": "1", "WB_COMBINED_REOPEN": "1" if mode == "reopen" else "0"})


def package(directory: Path, output: Path, source_sha: str) -> dict:
    """Stable ZIP inventories; do not follow symlinks or include transient caches."""
    if output.exists():
        raise ValueError("Evidence output exists; immutable publication refuses overwrite")
    if not directory.is_dir() or not re.fullmatch(r"[0-9a-f]{40}", source_sha):
        raise ValueError("Missing evidence or immutable source")
    from native.verify import verify as verify_native
    native = verify_native(directory / "native")
    if (native.get("passed") is not True or native.get("development_only") is not False
            or native.get("source_sha") != source_sha or len(native.get("cases", [])) != 30):
        raise ValueError("Publication requires all 30 source-qualified native cases")
    corpus = directory / "native/corpus/admitted-corpus.json"
    corpus_hash = hashlib.sha256(corpus.read_bytes()).hexdigest()
    for name, updates in (("training-fresh", 2), ("training-resume", 1)):
        result = json.loads((directory / name / "summary.json").read_text(encoding="utf-8"))
        config = result.get("config", {})
        if (result.get("status") != "completed" or result.get("actual_training") is not True
                or result.get("global_step") != 2 or result.get("optimizer_steps_this_job") != updates
                or result.get("checkpoint_readback_exact") is not True
                or result.get("adapter_changed") is not True or result.get("frozen_base_unchanged") is not True
                or config.get("source_sha") != source_sha or config.get("native_source_sha") != source_sha
                or config.get("compiler_sha256") != native["compiler_sha256"]
                or config.get("corpus_manifest_sha256") != corpus_hash):
            raise ValueError("Publication requires complete matching real optimizer proof: " + name)
        if name == "training-resume" and (result.get("resume", {}).get("from_step") != 1
                or result["resume"].get("restored_all_state_exactly") is not True):
            raise ValueError("Missing exact pre-update checkpoint restoration")
    comparison = json.loads((directory / "verification/resume-comparison.json").read_text(encoding="utf-8"))
    if comparison.get("passed") is not True or comparison.get("global_step") != 2:
        raise ValueError("Checkpoint continuation comparison failed")
    output.mkdir(parents=True)
    entries = []
    for component in ("native", "training-fresh", "training-resume", "verification"):
        source = directory / component
        if not source.is_dir():
            raise ValueError("Missing required evidence component " + component)
        archive = output / ("agent-painter-" + component + "-" + source_sha[:12] + ".zip")
        count = 0
        with zipfile.ZipFile(archive, "x", zipfile.ZIP_DEFLATED, compresslevel=6) as target:
            for path in sorted(source.rglob("*")):
                if path.is_symlink():
                    raise ValueError("Symlink in evidence")
                if not path.is_file() or any(p in {"__pycache__", "userdata", ".godot"} for p in path.parts):
                    continue
                target.write(path, path.relative_to(source).as_posix())
                count += 1
        if not count:
            raise ValueError("Empty evidence component " + component)
        entries.append({"file": archive.name, "bytes": archive.stat().st_size,
                        "sha256": hashlib.sha256(archive.read_bytes()).hexdigest()})
    # One self-contained HTML asset is also directly downloadable for inspection.
    gallery = output / "agent-painter-gallery.html"
    shutil.copyfile(directory / "native/gallery/index.html", gallery)
    entries.append({"file": gallery.name, "bytes": gallery.stat().st_size,
                    "sha256": hashlib.sha256(gallery.read_bytes()).hexdigest()})
    manifest = {"schema": "agent-painter-release-v1", "source_sha": source_sha,
                "accepted_base": BASE, "historical_donor": DONOR,
                "purpose": "synthetic teacher/native pilot and CPU optimizer infrastructure proof",
                "artistic_model_qualification": False, "draft_hold": True,
                "workflow_run": os.environ.get("GITHUB_RUN_ID"), "assets": entries}
    (output / "MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (output / "SHA256SUMS.txt").write_text("".join(x["sha256"] + "  " + x["file"] + "\n" for x in entries), encoding="utf-8")
    return manifest


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="mode", required=True)
    r = sub.add_parser("request")
    r.add_argument("--path", type=Path, default=Path(__file__).with_name("qualification-request.json"))
    r.add_argument("--source-sha", required=True)
    r.add_argument("--output", type=Path, required=True)
    r = sub.add_parser("regressions")
    r.add_argument("--godot", type=Path, required=True)
    r.add_argument("--evidence", type=Path, required=True)
    r = sub.add_parser("package")
    r.add_argument("--directory", type=Path, required=True)
    r.add_argument("--output", type=Path, required=True)
    r.add_argument("--source-sha", required=True)
    args = p.parse_args()
    if args.mode == "regressions":
        regressions(args.godot, args.evidence)
    elif args.mode == "request":
        result = request(args.path, args.source_sha)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result))
    else:
        print(json.dumps(package(args.directory, args.output, args.source_sha)))


if __name__ == "__main__":
    main()
