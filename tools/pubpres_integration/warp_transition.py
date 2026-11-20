#!/usr/bin/env python3
"""Isolate ANGLE/WARP history-copy costs on the retained 8503 Windows package."""
import argparse
import collections
import datetime
import difflib
import json
import math
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tempfile
import time
import uuid

from package_windows import CONSOLE, GUI, MANIFEST, digest, need, safe_name, verify, write_json


SOURCE = "8503ec19e4d620e125dc6df2c5c6571b1256cb92"
TREE = "ece848ad77c06fafb60d597d87f9f53f7bc211f1"
MANIFEST_SHA256 = "2ddd8ddd29f34b11ae6519b93697e433e0fa7a06daf91223a3ec070b9b9f571c"
PACKAGE_ARTIFACT = "https://github.com/techrote/cybersand/actions/runs/44706204266/artifacts/14616761210"
ORIGINAL_ARTIFACT = "https://github.com/techrote/cybersand/actions/runs/44706204266/artifacts/14617316032"
SWITCH = "CYBERSAND_PUBPRES_PROBE_SKIP_HISTORY"
PUBLISHER = "scripts/blit_material_publisher.gd"
FIXTURE = "tests/pubpres_transition.gd"
ORACLE = "tests/pubpres_warp_transition_oracle.gd"
ORDER = "RABBAR"
PHASES = ("enter_dense", "dense", "enter_sparse", "sparse")
EXPECTED_IMAGE_HASHES = {
    "current_sha256": "14f53c3a4451cdd0b64ae87457c71ae9366cabe609a51be1d180491a4c0011d9",
    "previous_sha256": "75f6f9c13da5687b4c5197741b1e96c3f223a29feaba32d3ff324b92cc8da90f",
}
INITIAL_PLANE = "20ad8501b542f948305b5979ed20180264726a8259766bf5ccd401339fce6959"
SHADER_SOURCE = "b8e5542dae2c36fd6fbef0170a7b537bce5c853fc10920174cefe13dbec78d4f"
SHADER_ANGLE = "6a1b5ea80bb034c41f93bb994e59791d25739c040b35caf2f24aa143cc12f52b"
ERRORS = re.compile(r"(?m)^(?:[ \t]*(?:(?:SCRIPT |USER )?ERROR:|Parse Error:))")
SCOPE = (
    "Windows ANGLE/D3D11 Microsoft Basic Render Driver transition mechanism probe on the retained installed package. "
    "Frame samples end at post-draw, not GPU completion. No native gameplay owner or physical GPU acceptance."
)


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def prepare_project(installed, project, output, manifest, oracle):
    expected = {}
    for name, sha in manifest["files_sha256"].items():
        if not name.startswith("godot/"):
            continue
        path = safe_name(name)
        relative = path.relative_to("godot").as_posix()
        target = project / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(installed / path, target)
        expected[relative] = sha

    publisher = project / PUBLISHER
    original = publisher.read_bytes()
    selector = b"\t\treuse_current = incoming.count(1) <= 4\n"
    new_line = selector.rstrip(b"\n") + f' and OS.get_environment("{SWITCH}") != "1"\n'.encode()
    need(original.count(selector) == 1, "Pinned publisher eligibility gate differs")
    changed = original.replace(selector, new_line)
    publisher.write_bytes(changed)
    expected[PUBLISHER] = digest(publisher)
    overlay = "".join(difflib.unified_diff(
        original.decode().splitlines(keepends=True), changed.decode().splitlines(keepends=True),
        f"a/godot/{PUBLISHER}", f"b/godot/{PUBLISHER}",
    ))
    (output / "publisher-overlay.patch").write_bytes(overlay.encode())

    need(ORACLE not in expected, "The oracle would overwrite a retained package file")
    oracle_source = output / Path(ORACLE).name
    shutil.copyfile(oracle, oracle_source)
    shutil.copyfile(oracle_source, project / ORACLE)
    expected[ORACLE] = digest(oracle_source)
    need(not project_drift(project, expected), "Scratch project failed exact copy verification")
    return expected


def project_drift(project, expected):
    return [name for name, sha in expected.items() if not (project / name).is_file() or digest(project / name) != sha]


def capture(installed, project, folder, profiles, script=None, material="blit", skip=False):
    folder.mkdir()
    created = datetime.datetime.now(datetime.timezone.utc)
    nonce = uuid.uuid4().hex
    env = {key: value for key, value in os.environ.items() if not key.upper().startswith("CYBERSAND_")}
    settings = {
        "CYBERSAND_SOURCE_REVISION": SOURCE,
        "CYBERSAND_MATERIAL_PUBLICATION": material,
        "CYBERSAND_SHADER_NONCE": nonce,
        "CYBERSAND_SHADER_CACHE_STATE": "isolated-process-profile",
        SWITCH: str(int(skip)),
    }
    profile = profiles / folder.name
    for key in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
        target = profile / key
        target.mkdir(parents=True)
        settings[key] = str(target)
    env.update(settings)
    command = [str(installed / CONSOLE), "--path", str(project), "--audio-driver", "Dummy",
               "--log-file", str(folder / "godot.log")]
    if script is None:
        command += ["--headless", "--editor", "--import"]
    else:
        command += ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3_angle",
                    "--render-thread", "safe", "--script", "res://" + script, "--",
                    f"--material={material}", f"--receipt={folder / 'receipt.json'}"]
    record = {"command": command, "environment": settings, "started_utc": created.isoformat(),
              "timeout_seconds": 480, "timed_out": False}
    started = time.monotonic()
    try:
        with (folder / "stdout.log").open("wb") as stdout, (folder / "stderr.log").open("wb") as stderr:
            with subprocess.Popen(command, cwd=installed, env=env, stdout=stdout, stderr=stderr,
                                  creationflags=subprocess.CREATE_NO_WINDOW) as process:
                record["console_wrapper_pid"] = process.pid
                try:
                    process.wait(timeout=record["timeout_seconds"])
                except subprocess.TimeoutExpired:
                    record["timed_out"] = True
                    kill = str(Path(os.environ["SystemRoot"]) / "System32/taskkill.exe")
                    subprocess.run([kill, "/PID", str(process.pid), "/T", "/F"], capture_output=True, timeout=15, check=False)
                    process.wait(timeout=15)
                record["exit"] = process.returncode
    except (OSError, subprocess.SubprocessError) as error:
        record["process_error"] = str(error)
    finally:
        if script != ORACLE:
            record["process_wall_seconds"] = time.monotonic() - started
        write_json(folder / "process.json", record)
    return record


def check_process(folder, record):
    need(not record["timed_out"] and record.get("exit") == 0, "Godot did not complete within its process limit")
    lines = []
    for name in ("stdout.log", "stderr.log", "godot.log"):
        text = (folder / name).read_text(encoding="utf-8-sig", errors="replace")
        lines.extend(re.sub(r"\x1b\[[0-9;]*m", "", text).splitlines())
    need(not any(ERRORS.match(line) for line in lines), "Godot diagnostics include runtime errors")
    return next((line for line in lines if line.startswith("OpenGL API")), "")


def check_context(context, record, script, script_sha, manifest, renderer):
    settings = record["environment"]
    need(context["source_revision"] == SOURCE and context["engine_sha256"] == manifest["engine"]["gui_sha256"]
         and context["godot"]["hash"] == "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"
         and context["fixture"] == "res://" + script and context["fixture_sha256"] == script_sha
         and context["nonce"] == settings["CYBERSAND_SHADER_NONCE"] and context["cache_state"] == settings["CYBERSAND_SHADER_CACHE_STATE"]
         and context["execution_policy"]["ok"], "Recorded source/engine/fixture/process identity differs")
    need(context["platform"] == "Windows" and context["display_server"] == "Windows"
         and context["backend"] == "opengl3_angle", "A fresh real Windows ANGLE device is required")
    adapter = context["video_adapter"]
    need("Microsoft Basic Render Driver (0x0000008C)" in adapter and "Direct3D11" in adapter
         and adapter in renderer and "ANGLE" in renderer,
         "Microsoft Basic Render Driver on ANGLE D3D11/WARP was not observed")
    need(Path(context["engine_path"]).resolve() == Path(record["command"][0]).with_name(GUI).resolve()
         and Path(settings["APPDATA"]).resolve() in Path(context["user_data_dir"]).resolve().parents
         and context["process_id"] > 0, "Wrong engine location, process or isolated profile")
    shader = context["shader"]
    need(shader["variant"] == "angle_bounded_crossfade" and shader["source_bound"] and shader["source_file_bound"]
         and shader["source_file_sha256"] == SHADER_SOURCE and shader["source_sha256"] == SHADER_SOURCE
         and shader["variant_sha256"] == SHADER_ANGLE, "Expected retained ANGLE palette shader was not observed")


def distribution(values):
    values = sorted(value for value in values if value is not None)
    if not values:
        return None
    result = {"count": len(values), "max": values[-1]}
    for quantile in (50, 95, 99):
        index = (len(values) - 1) * quantile / 100
        low = math.floor(index)
        high = math.ceil(index)
        result[f"p{quantile}"] = values[low] + (values[high] - values[low]) * (index - low)
    return result


def timing_statistics(rows):
    result = {name: distribution(row[name] for row in rows)
              for name in ("frame_ms", "publication_ms", "godot_static_memory_peak_bytes", "reported_video_memory_bytes")}
    for name in ("staging_upload_usec", "atlas_assembly_usec", "history_copy_usec",
                 "gpu_blit_submit_usec", "backend_submit_usec", "image_patch_usec", "content_cache_usec",
                 "submitted_bytes", "allocated_gpu_bytes", "estimated_history_read_bytes"):
        result[name] = distribution(row["material"].get(name) for row in rows)
    result["history_copy_count"] = sum(bool(row["material"].get("history_copy")) for row in rows)
    result["history_staging_count"] = sum(bool(row["material"].get("history_staging")) for row in rows)
    result["direct_whole_count"] = sum(bool(row["material"].get("direct_whole")) for row in rows)
    result["frames_at_least_30ms"] = sum(row["frame_ms"] >= 30 for row in rows)
    result["outside_publication_ms"] = distribution(row["frame_ms"] - row["publication_ms"] for row in rows)
    return result


def read_timed(receipt, arm, folder):
    material = "full" if arm == "R" else "blit"
    rows = receipt["samples"]
    need(receipt["schema"] == "pubpres-transition-v1" and receipt["case"] == "transition_2048_w1"
         and receipt["complete"] and not receipt["failures"] and len(rows) == 180 and receipt["warmup_frames"] == 30
         and receipt["material_strategy"] == material and receipt["size"] == [2048, 2048] and receipt["channels"] == 2
         and receipt["initial_plane_sha256"] == INITIAL_PLANE, "Timed fixture closure, geometry or input drift")
    need(receipt["display"] == {"max_fps": 0, "vsync_mode": 0, "window": [960, 720]}, "Expected uncapped display and VSync off")
    need(receipt["history"] == {"current_matches": True, "previous_matches": True, **EXPECTED_IMAGE_HASHES},
         "Final exact current or previous GPU material history differs from retained tape")
    need(digest(folder / "receipt-after.png") == receipt["screenshot_sha256"], "Original screenshot missing or changed")

    phases = collections.defaultdict(list)
    entry_followers = collections.defaultdict(list)
    targets = None
    for index, row in enumerate(rows, start=30):
        offset = index % 12
        phase = PHASES[min(offset, 3)]
        dense = offset < 2
        need(row["sequence"] == index and row["sample"] == index - 30 and row["accepted"] is True
             and row["accepted_revision"] == index + 1 and row["dense"] == dense and row["phase"] == phase
             and row["patch_bytes"] == (8388608 if dense else 128), f"Revision {index + 1} input or acceptance differs")
        need(math.isfinite(row["frame_ms"]) and row["frame_ms"] > 0
             and math.isfinite(row["publication_ms"]) and row["publication_ms"] >= 0
             and row["publish_end_usec"] >= row["publish_begin_usec"]
             and math.isclose(row["publication_ms"], (row["publish_end_usec"] - row["publish_begin_usec"]) / 1000),
             f"Revision {index + 1} timeline is invalid")
        update = row["material"]
        cloned = arm == "A" and offset == 2
        compact = arm == "B" and offset == 2
        whole = arm != "R" and (dense or compact)
        need(update["requested_mode"] == material and update["backend"] == material and update["driver"] == "opengl3_angle"
             and not update["fallback_reason"] and bool(update.get("history_copy")) == cloned
             and bool(update.get("history_staging")) == cloned
             and bool(update.get("direct_whole")) == whole and bool(update.get("whole_gpu_copy")) == whole,
             f"Revision {index + 1} used a different publisher or copy mechanism")
        need(update["submitted_bytes"] == (8388608 if whole or arm == "R" else 32768),
             f"Revision {index + 1} staged unexpected bytes")
        if arm != "R":
            pair = (update["current_texture_rid"], update["previous_texture_rid"])
            need(pair[0] > 0 and pair[1] > 0 and pair[0] != pair[1]
                 and (targets is None or pair == targets[::-1]), f"Revision {index + 1} did not reuse the two alternating draw targets")
            targets = pair
        if cloned:
            need(update["atlas_capacity"] == 1 and update["estimated_history_read_bytes"] == 16777216
                 and update["history_copy_usec"] >= 0, f"Revision {index + 1} is missing the GPU history clone receipt")
        phases[phase].append(row)
        if 2 <= offset <= 5:
            entry_followers[f"entry_plus_{offset - 2}"].append(row)
    need({name: len(phases[name]) for name in PHASES} == dict(zip(PHASES, (15, 15, 15, 135))),
         "Missing first-sparse, dense or ordinary sparse revisions")
    return {
        "accepted_revisions": len(rows), "accepted_updates_per_second": 1000 * len(rows) / sum(row["frame_ms"] for row in rows),
        "setup_usec": receipt["setup_usec"], "overall": timing_statistics(rows),
        "phases": {phase: timing_statistics(group) for phase, group in phases.items()},
        "first_sparse_and_following_callbacks": {name: timing_statistics(group) for name, group in entry_followers.items()},
        "history": receipt["history"], "screenshot_sha256": receipt["screenshot_sha256"],
    }


def read_oracle(receipt, arm):
    need(receipt["schema"] == "pubpres-warp-history-oracle-v1" and receipt["case"] == "transition_2048_w1"
         and receipt["complete"] and not receipt["failures"] and receipt["mode"] == ("clone" if arm == "A" else "compact")
         and receipt["frames_checked"] == 180 and receipt["current_matches"] == 180 and receipt["previous_matches"] == 180
         and receipt["sparse_entries"] == 15, "Untimed all-revision GPU or first-sparse mechanism oracle failed")
    entries = receipt["entry_history"]
    need([entry["sequence"] for entry in entries] == [i for i in range(30, 210) if i % 12 == 2],
         "Oracle sparse-entry sequence differs")
    for entry in entries:
        need(all(re.fullmatch("[0-9a-f]{64}", entry[key]) for key in EXPECTED_IMAGE_HASHES),
             "Missing first-sparse per-plane history hash")
    return {key: receipt[key] for key in ("mode", "frames_checked", "current_matches", "previous_matches", "entry_history")}


def run_arm(installed, project, folder, profiles, manifest, project_hashes, arm, oracle=False):
    fixture = ORACLE if oracle else FIXTURE
    record = capture(installed, project, folder, profiles, fixture, "full" if arm == "R" else "blit", arm == "B")
    result = {"arm": arm, "status": "FAIL", "process": record}
    try:
        renderer = check_process(folder, record)
        result["renderer"] = renderer
        receipt = load_json(folder / "receipt.json")
        result["context"] = receipt["context"]
        check_context(receipt["context"], record, fixture, project_hashes[fixture], manifest, renderer)
        result["analysis"] = read_oracle(receipt, arm) if oracle else read_timed(receipt, arm, folder)
        result["status"] = "PASS"
    except (KeyError, TypeError, ValueError, OSError) as error:
        result["failure"] = str(error)
    write_json(folder / "analysis.json", result)
    print(folder.name, result["status"], result.get("failure", ""), flush=True)
    return result


def check_campaign(timed, oracles):
    runs = timed + oracles
    need("".join(run["arm"] for run in timed) == ORDER and "".join(run["arm"] for run in oracles) == "AB"
         and all(run["status"] == "PASS" for run in runs), "A timed or oracle arm was missing or failed")
    for identity in ("process_id", "nonce", "user_data_dir"):
        need(len({arm["context"][identity] for arm in runs}) == len(runs), "Reused process, receipt identity or user profile")
    ignored = {"process_id", "nonce", "user_data_dir", "fixture", "fixture_sha256"}
    known = {key: value for key, value in runs[0]["context"].items() if key not in ignored}
    need(all(
        {key: value for key, value in arm["context"].items() if key not in ignored} == known
        and arm["renderer"] == runs[0]["renderer"] for arm in runs
    ), "Renderer or fixture context changed between fresh-process captures")
    need(oracles[0]["analysis"]["entry_history"] == oracles[1]["analysis"]["entry_history"],
         "Untimed clone and bypass first-sparse GPU history hashes differ")


def compare_arms(timed):
    comparisons = []
    for left, right in ((2, 1), (3, 4), (2, 0), (3, 5), (1, 0), (4, 5)):
        trial, control = (timed[index]["analysis"] for index in (left, right))
        scopes = {"overall": trial["overall"], **trial["first_sparse_and_following_callbacks"]}
        controls = {"overall": control["overall"], **control["first_sparse_and_following_callbacks"]}
        comparisons.append({
            "trial": f"{left}-{timed[left]['arm']}", "control": f"{right}-{timed[right]['arm']}",
            "accepted_updates_per_second_delta": trial["accepted_updates_per_second"] - control["accepted_updates_per_second"],
            "trial_minus_control_ms": {
                scope: {metric: {quantile: values[metric][quantile] - controls[scope][metric][quantile]
                                 for quantile in ("p50", "p95", "p99", "max")}
                        for metric in ("frame_ms", "publication_ms", "outside_publication_ms")}
                for scope, values in scopes.items()
            },
        })
    return comparisons


def host_identity(output):
    data = {"platform": platform.platform(), "processor": platform.processor(), "logical_processors": os.cpu_count(),
            "runner_os": os.environ.get("RUNNER_OS"), "runner_image_os": os.environ.get("ImageOS"),
            "runner_image_version": os.environ.get("ImageVersion")}
    try:
        command = ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command",
                   "@{gpu=@(Get-CimInstance Win32_VideoController | Select Name,DriverVersion); "
                   "cpu=@(Get-CimInstance Win32_Processor | Select Name,NumberOfCores,NumberOfLogicalProcessors); "
                   "os=Get-CimInstance Win32_OperatingSystem | Select Caption,Version,BuildNumber} | ConvertTo-Json -Depth 4"]
        result = subprocess.run(command, capture_output=True, text=True, timeout=20, check=True)
        data["windows"] = json.loads(result.stdout)
    except (OSError, subprocess.SubprocessError, ValueError) as error:
        data["cim_unavailable"] = str(error)
    write_json(output / "hardware.json", data)


def run(installed, output, oracle):
    summary = {"scope": SCOPE, "source": SOURCE, "tree": TREE, "package_artifact": PACKAGE_ARTIFACT,
               "original_evidence_artifact": ORIGINAL_ARTIFACT, "timed": [], "untimed_oracles": [],
               "status": "HOLD", "complete": False, "performance_status": "MEASUREMENTS_ONLY"}
    host_identity(output)
    try:
        need(digest(installed / MANIFEST) == MANIFEST_SHA256, "Extract the exact hosted package artifact from run 44706204266")
        manifest = verify(installed, SOURCE)
        need(manifest["source_tree"] == TREE, "Retained package tree differs")
        shutil.copyfile(installed / MANIFEST, output / "package-manifest.json")
        with tempfile.TemporaryDirectory(prefix="pubpres-warp-") as scratch:
            project = Path(scratch) / "project"
            profiles = Path(scratch) / "profiles"
            expected = prepare_project(installed, project, output, manifest, oracle)
            plan = {"order": list(ORDER), "arms": {"R": "retained full reference", "A": "blit history copy",
                    "B": "blit compact full fallback on sparse entry"}, "oracle_order": ["A", "B"],
                    "manifest_sha256": MANIFEST_SHA256, "source_publisher_sha256": manifest["files_sha256"]["godot/" + PUBLISHER],
                    "probe_publisher_sha256": expected[PUBLISHER], "oracle_sha256": expected[ORACLE],
                    "publisher_overlay_sha256": digest(output / "publisher-overlay.patch"),
                    "project_inputs_sha256": expected}
            write_json(output / "probe-plan.json", plan)
            folder = output / "import"
            check_process(folder, capture(installed, project, folder, profiles))
            drift = project_drift(project, expected)
            mutable = [name for name in drift if name == ".godot/global_script_class_cache.cfg" or name.endswith(".import")]
            summary["import_changed_metadata"] = mutable
            need(set(drift) == set(mutable), "Editor import changed a pinned source, oracle or runtime")
            for name in mutable:
                expected[name] = digest(project / name)
            for index, arm in enumerate(ORDER):
                folder = output / f"timed-{index}-{arm}"
                summary["timed"].append(run_arm(installed, project, folder, profiles, manifest, expected, arm))
            for arm in ("A", "B"):
                folder = output / f"oracle-{arm}"
                summary["untimed_oracles"].append(run_arm(installed, project, folder, profiles, manifest, expected, arm, oracle=True))
            summary["scratch_final_drift"] = project_drift(project, expected)
            need(not summary["scratch_final_drift"], "Scratch source or runtime changed during the replay")
        verify(installed, SOURCE)
        need(digest(installed / MANIFEST) == MANIFEST_SHA256, "Installed package identity changed on disk")
        check_campaign(summary["timed"], summary["untimed_oracles"])
        summary["paired_comparisons"] = compare_arms(summary["timed"])
        summary["complete"] = True
        summary["status"] = "PASS"
    except (KeyError, TypeError, ValueError, OSError) as error:
        summary["failure"] = str(error)
    finally:
        write_json(output / "summary.json", summary)
    print("WARP transition", summary["status"], summary.get("failure", ""), flush=True)
    return int(summary["status"] != "PASS")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--installed", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--oracle", required=True, type=Path)
    args = parser.parse_args()
    if os.name != "nt":
        parser.error("Windows ANGLE/D3D11 WARP is required")
    installed = args.installed.resolve(strict=True)
    oracle = args.oracle.resolve(strict=True)
    output = args.output.resolve()
    if not installed.is_dir() or not oracle.is_file() or oracle.suffix != ".gd":
        parser.error("Expected a fresh installed package directory and a GDScript oracle file")
    if output.exists() or installed in output.parents:
        parser.error("Expected a new artifact directory outside the installed package")
    output.mkdir(parents=True)
    return run(installed, output, oracle)


if __name__ == "__main__":
    raise SystemExit(main())
