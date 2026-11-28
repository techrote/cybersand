#!/usr/bin/env python3
"""Focused actual-Windows preview observation of an immutable application.

This observer imports the candidate's existing strict runner and completion
parser. It never modifies candidate scripts, tests, clocks or assertions.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys

APPLICATION = "ace52bc6e9b3b958ed164f3328d02b07cf2d5c50"
PRODUCER_RUN = 46118132005
ARTIFACT = 15252652797
ARTIFACT_BYTES = 2742556
ARTIFACT_DIGEST = "sha256:d46252d62f2abdd76d7da2c37ff8bc39355b7fee992b40e5c26b940b6fb27875"
TEST = "test_object_shard_m4_edit_preview_render"
CAPTURES = {"structural-eraser", "precision-cell", "drill-opening", "weathering-extent",
            "area-ignition", "ordinary-unified-eraser", "slice-preview", "zoomed-eraser",
            "panned-drill", "resized-weathering", "structures-controls-top", "structures-weathering-controls"}


def qualify(args):
    root = args.application.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    sys.path.insert(0, str(root / "tools/objectshard"))
    import qualify_workbench as q

    report = {"schema": "objectshard-m4-live-edit-preview-observer-v1", "status": "incomplete",
              "observer_commit": os.environ.get("GITHUB_SHA", ""),
              "observer_script_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              "producer_run_id": PRODUCER_RUN, "artifact_id": ARTIFACT,
              "cases": [], "failures": [],
              "scope": "isolated hosted Windows ANGLE observation of the exact committed production preview fixture; full qualification, extracted package and physical owner evaluation remain separate"}
    try:
        if sys.platform != "win32" or q.ROOT.resolve() != root:
            raise ValueError("Observer requires actual Windows and the requested application root")
        metadata = json.loads(args.artifact_metadata.read_text(encoding="utf-8-sig"))
        if (metadata.get("id") != ARTIFACT or metadata.get("expired") is not False
                or metadata.get("size_in_bytes") != ARTIFACT_BYTES or metadata.get("digest") != ARTIFACT_DIGEST
                or metadata.get("workflow_run", {}).get("id") != PRODUCER_RUN
                or metadata.get("workflow_run", {}).get("head_sha") != APPLICATION):
            raise ValueError("Provider artifact metadata differs from the immutable producer")
        commit, tree, inputs = q.native.source(root)
        if commit != APPLICATION:
            raise ValueError("Application source differs from the immutable candidate")
        candidate = q.native.verify(root, args.native_candidate.resolve())
        native_path, rapier_path = q.runner.runtime_paths()
        if q.runner.sha256(native_path) != candidate["sha256"]:
            raise ValueError("Installed native DLL differs from the source-bound producer")
        if q.runner.sha256(rapier_path) != q.RAPIER_HASHES["win32"]:
            raise ValueError("Rapier differs from the admitted dependency")
        engine = args.godot.resolve()
        version = subprocess.check_output([str(engine), "--version"], text=True, timeout=30).strip()
        if version != q.VERSION or q.runner.sha256(engine) != "d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c":
            raise ValueError("Godot version or console binary differs from the pinned 4.7 runtime")
        scripts = q.committed_inputs()
        report.update(source_commit=commit, source_tree=tree, native_source_inputs=inputs,
                      executed_script_inputs=scripts, producer_artifact=metadata,
                      runtime={"godot_version": version, "godot_sha256": q.runner.sha256(engine),
                               "native_sha256": candidate["sha256"], "native_bytes": candidate["size"],
                               "rapier_sha256": q.runner.sha256(rapier_path)})
        env = dict(os.environ, CYBERSAND_SOURCE_REVISION=commit)
        env.pop("CYBERSAND_PACKAGE_MANIFEST", None)
        flags = ("--rendering-driver", "opengl3_angle") + q.runner.script_case_flags(TEST)
        if "--objectshard-m4-workbench" not in flags:
            raise ValueError("Committed runner does not register the production Workbench input path")
        flags += ("--output=" + str(output / "captures"),)
        cases = [(q.runner.Case("preview_observer_import", ("--editor", "--quit"),
                  int(q.execution_policy.watchdog_seconds("godot_import_seconds")), 0), None),
                 (q.runner.Case(TEST, flags, int(q.execution_policy.watchdog_seconds("graphical_case_seconds")),
                                0, True), "objectshard-m4-edit-preview-render-v1")]
        for case, schema in cases:
            user_root = output / "isolated-user-data" / case.name
            user_root.mkdir(parents=True)
            case_env = dict(env, APPDATA=str(user_root), LOCALAPPDATA=str(user_root), XDG_DATA_HOME=str(user_root))
            record, failed = q.run_observed_case(q.runner, str(engine), case, output,
                                                "objectshard-live-edit-preview-observer", env=case_env)
            if schema and not failed:
                try:
                    receipt = q.completion(output / record["log"], schema)
                    if receipt.get("source_commit") != commit or receipt.get("display_driver") != "Windows":
                        raise ValueError("Preview did not execute against the expected Windows source")
                    if receipt.get("rendered_frames", 0) < 1 or receipt.get("injected_events", 0) < 1:
                        raise ValueError("Missing actual rendered frames or production input events")
                    captures = receipt.get("captures", [])
                    if len(captures) != len(CAPTURES) or {c.get("label") for c in captures} != CAPTURES:
                        raise ValueError("Missing or duplicated mandatory preview/control captures")
                    for capture in captures:
                        path = Path(capture["path"]).resolve()
                        if not path.is_relative_to(output / "captures"):
                            raise ValueError("Capture escaped its evidence directory")
                        data = path.read_bytes()
                        if (data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR"
                                or list(struct.unpack(">II", data[16:24])) != capture["size"]
                                or hashlib.sha256(data).hexdigest() != capture["sha256"]):
                            raise ValueError("Capture PNG bytes differ from the fixture receipt")
                    if len(receipt.get("previews", [])) != 10:
                        raise ValueError("Preview fixture did not complete all tool and camera probes")
                    for preview in receipt["previews"]:
                        if preview.get("render_control", {}).get("changed_samples", 0) < 3:
                            raise ValueError("Preview is missing its actual framebuffer outline control")
                    record["receipt"] = receipt
                except (KeyError, OSError, ValueError, struct.error) as error:
                    record["receipt_error"] = str(error)
                    failed = True
            report["cases"].append(record)
            if failed:
                report["failures"].append(case.name)
            q.save(output / "summary.json", report)
            if failed and schema is None:
                break
        if q.committed_inputs() != scripts or q.native.source(root) != (commit, tree, inputs):
            raise ValueError("Application source changed during observation")
        report["status"] = "passed" if not report["failures"] else "failed"
    except Exception as error:
        report["status"] = "failed"
        report["failures"].append(str(error))
    finally:
        q.save(output / "summary.json", report)
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--application", type=Path, required=True)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--native-candidate", type=Path, required=True)
    parser.add_argument("--artifact-metadata", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    result = qualify(parser.parse_args())
    print(json.dumps({key: result[key] for key in ("status", "failures")}))
    raise SystemExit(0 if result["status"] == "passed" else 1)
