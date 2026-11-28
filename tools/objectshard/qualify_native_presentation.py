#!/usr/bin/env python3
"""Early exact-source Windows native camera, brush and live-preview witnesses.

This short parallel lane does not replace the complete Workbench matrix,
package replay or guarded runtime publication. It executes the retained camera
and brush fixtures plus the new live-preview fixture against the same Windows
producer artifact as the full campaign.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys

import qualify_workbench as q


def qualify(args: argparse.Namespace) -> dict:
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    report = {"schema": "objectshard-m4-native-presentation-smoke-v1",
              "status": "incomplete", "cases": [], "failures": [],
              "scope": "retained camera/brush and live-edit preview renderer fixtures; full source, package and physical-owner qualification remain separate"}
    try:
        if sys.platform != "win32" or not re.fullmatch(r"[0-9a-f]{40}", args.expected_source_sha):
            raise ValueError("This early lane requires actual Windows and a complete source commit")
        commit, tree, inputs = q.native.source(q.ROOT)
        if commit != args.expected_source_sha:
            raise ValueError("Source differs from the requested application")
        candidate = q.native.verify(q.ROOT, args.native_candidate)
        native_path, rapier_path = q.runner.runtime_paths()
        if q.runner.sha256(native_path) != candidate["sha256"]:
            raise ValueError("Loaded native DLL differs from this source's producer artifact")
        if q.runner.sha256(rapier_path) != q.RAPIER_HASHES["win32"]:
            raise ValueError("Rapier differs from the admitted dependency")
        engine = args.godot.resolve()
        version = subprocess.check_output([str(engine), "--version"], text=True, timeout=30).strip()
        if version != q.VERSION:
            raise ValueError("Godot differs from the qualified 4.7 version")
        script_inputs = q.committed_inputs()
        report.update(source_commit=commit, source_tree=tree, native_source_inputs=inputs,
                      executed_script_inputs=script_inputs,
                      runtime={"godot_version": version, "godot_sha256": q.runner.sha256(engine),
                               "native_sha256": candidate["sha256"], "rapier_sha256": q.runner.sha256(rapier_path)})
        env = dict(os.environ, CYBERSAND_SOURCE_REVISION=commit)
        env.pop("CYBERSAND_PACKAGE_MANIFEST", None)
        cases = [(q.runner.Case("native_presentation_import", ("--editor", "--quit"),
                  int(q.execution_policy.watchdog_seconds("godot_import_seconds")), 0), None)]
        for name, schema in (("test_object_shard_m4_camera_lifecycle", "objectshard-m4-camera-lifecycle-v1"),
                             ("test_object_shard_m4_brush_revision", "objectshard-m4-brush-revision-v1"),
                             ("test_object_shard_m4_edit_preview_render", "objectshard-m4-edit-preview-render-v1")):
            flags = ("--rendering-driver", "opengl3_angle") + q.runner.script_case_flags(name)
            if name.endswith("camera_lifecycle"):
                flags += ("--output=" + str(output / "camera-lifecycle-captures"),)
            elif name.endswith("edit_preview_render"):
                flags += ("--output=" + str(output / "edit-preview-captures"),)
            cases.append((q.runner.Case(name, flags,
                          int(q.execution_policy.watchdog_seconds("graphical_case_seconds")), 0, True), schema))
        for case, schema in cases:
            user_root = output / "isolated-user-data" / case.name
            user_root.mkdir(parents=True)
            case_env = dict(env, APPDATA=str(user_root), LOCALAPPDATA=str(user_root), XDG_DATA_HOME=str(user_root))
            record, failed = q.run_observed_case(q.runner, str(engine), case, output, "objectshard-native-presentation", env=case_env)
            if schema and not failed:
                try:
                    receipt = q.completion(output / record["log"], schema)
                    if receipt.get("source_commit") != commit:
                        raise ValueError("Fixture source identity differs from the native producer")
                    if schema == "objectshard-m4-edit-preview-render-v1":
                        if receipt.get("display_driver") != "Windows" or receipt.get("rendered_frames", 0) < 1 \
                                or receipt.get("injected_events", 0) < 1:
                            raise ValueError("Missing actual Windows preview rendering and input")
                        previews, captures = receipt.get("previews", []), receipt.get("captures", [])
                        expected = {"structural-eraser", "precision-cell", "drill-opening", "weathering-extent",
                                    "area-ignition", "ordinary-unified-eraser", "slice-preview", "zoomed-eraser",
                                    "panned-drill", "resized-weathering", "structures-controls-top", "structures-weathering-controls"}
                        if len(previews) != 10 or len(captures) != len(expected) \
                                or {capture.get("label") for capture in captures} != expected:
                            raise ValueError("Incomplete tool, camera or controls preview evidence")
                        if any(preview.get("render_control", {}).get("changed_samples", 0) < 3 for preview in previews):
                            raise ValueError("Missing actual framebuffer outline control")
                        for capture in captures:
                            path = Path(capture["path"]).resolve()
                            if not path.is_relative_to(output / "edit-preview-captures"):
                                raise ValueError("Preview capture escaped its evidence directory")
                            data = path.read_bytes()
                            if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR" \
                                    or list(struct.unpack(">II", data[16:24])) != capture["size"] \
                                    or q.runner.sha256(path) != capture["sha256"]:
                                raise ValueError("Actual preview PNG differs from its receipt")
                    else:
                        display = receipt.get("display", receipt.get("evidence", {}).get("display_coherence", {}))
                        if display.get("draw_observations", 0) <= 0 or display.get("foreign_draw_callbacks") != 0 \
                                or display.get("incoherent_observations") != 0:
                            raise ValueError("Missing actual Main-thread renderer publication observations")
                    record["receipt"] = receipt
                except (KeyError, OSError, ValueError, struct.error) as error:
                    record["receipt_error"] = str(error)
                    failed = True
            report["cases"].append(record)
            if failed:
                report["failures"].append(case.name)
            q.save(output / "summary.json", report)
        if q.committed_inputs() != script_inputs or q.native.source(q.ROOT) != (commit, tree, inputs):
            raise ValueError("Source changed during early renderer qualification")
        report["status"] = "passed" if not report["failures"] else "failed"
    except Exception as error:
        report["status"] = "failed"
        report["failures"].append(str(error))
    finally:
        q.save(output / "summary.json", report)
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--native-candidate", type=Path, required=True)
    parser.add_argument("--expected-source-sha", required=True)
    parser.add_argument("--output", type=Path, required=True)
    result = qualify(parser.parse_args())
    print(json.dumps({key: result[key] for key in ("status", "failures")}))
    raise SystemExit(0 if result["status"] == "passed" else 1)
