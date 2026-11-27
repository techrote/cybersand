#!/usr/bin/env python3
"""Observe the frozen ordinary Workbench with a separately identified script.

No application source is copied or modified. The frozen application's own
qualifier authenticates its source, all project inputs, engine and runtimes.
Each scene uses a fresh real graphical Godot process and retains original logs,
partial reports and images on failure. Optional movies are labelled sampled
timelapses, never continuous video or hardware frame-rate measurements.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib
import json
import math
from pathlib import Path
import struct
import subprocess
import sys
import time

FROZEN_APPLICATION = "a7250e15495667b2fcf564cbed1eaa8dea217c45"
SCENES = {"ambient2-courtyard": 1, "ambient2-refinery": 5, "ambient2-settlement": 7}
SCHEMA = "ambient-living-sustained-watch/v1"
OBSERVER_FILES = ("watch_ambient_living.gd", "run_graphical_watch.py", "test_graphical_watch.py")


def require(condition, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def full_application_revision(value: str) -> str:
    """Accept only an explicit immutable lower-case Git SHA, never a branch name."""
    if type(value) is not str or len(value) != 40 or any(c not in "0123456789abcdef" for c in value):
        raise argparse.ArgumentTypeError("Application revision must be a full 40-character lower-case Git SHA")
    return value


def admit_application_revision(identity: dict, expected: str) -> str:
    revision = full_application_revision(expected)
    require(identity.get("source_commit") == revision,
            "Application checkout must match explicitly pinned revision " + revision)
    return revision


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def finite(value) -> bool:
    return type(value) in (int, float) and math.isfinite(value)


def png_dimensions(path: Path) -> list[int]:
    header = path.read_bytes()[:24]
    require(len(header) == 24 and header[:8] == b"\x89PNG\r\n\x1a\n" and header[12:16] == b"IHDR",
            "Missing actual PNG header: " + path.name)
    width, height = struct.unpack(">II", header[16:24])
    require(0 < width <= 8192 and 0 < height <= 8192, "Invalid captured framebuffer dimensions")
    return [width, height]


def validate_watch(folder: Path, report: dict, scene: str, seconds: int,
                   source: str, observer_sha: str, engine_sha: str, driver: str) -> dict:
    """Strict readback of the real process report; also unit-testable with fixtures."""
    require(report.get("schema") == SCHEMA and report.get("status") == "passed"
            and report.get("failures") == [], "Incomplete or failed sustained observation")
    require(report.get("scene") == scene and report.get("follow_actor") == SCENES[scene]
            and report.get("requested_simulation_seconds") == seconds,
            "Sustained observation request differs from the admitted run")
    require(report.get("source_revision") == source and report.get("observer_script_sha256") == observer_sha
            and report.get("engine_sha256") == engine_sha, "Application/observer/engine identity mismatch")
    require(report.get("display") not in (None, "", "headless") and report.get("renderer")
            and report.get("rendering_method") == "gl_compatibility"
            and report.get("rendering_driver") == driver, "Actual supported graphical backend required")
    rate = report.get("physics_ticks_per_second")
    require(type(rate) is int and 1 <= rate <= 240, "Invalid physical clock rate")
    require(finite(report.get("actual_simulation_seconds")) and report["actual_simulation_seconds"] + 1e-6 >= seconds
            and report.get("physical_ticks", 0) >= seconds * rate - 1
            and report.get("native_ticks", 0) >= seconds * rate - 1,
            "The requested real physical/native horizon did not complete")
    samples = report.get("samples", [])
    require(len(samples) == seconds + 1 <= 121, "Missing or excessive sustained samples")
    images = {}
    previous_time = -1.0
    previous_tick = -1
    previous_native = -1
    roster = None
    admitted_generations = {}
    for second, row in enumerate(samples):
        require(row.get("requested_simulation_second") == second, "Missing or duplicate requested sample second")
        observed_time = row.get("simulation_seconds_since_play")
        tick, native = row.get("diagnostics_physical_tick"), row.get("diagnostics_native_tick")
        require(finite(observed_time) and observed_time >= previous_time and observed_time + 1e-6 >= second
                and type(tick) is int and tick >= previous_tick
                and type(native) is int and native >= previous_native,
                "Sample time or owned progression regressed or overstated its horizon")
        if second:
            require(tick > previous_tick and native > previous_native, "Repeated frozen frame cannot stand in for progression")
        previous_time, previous_tick, previous_native = observed_time, tick, native
        capture = row.get("capture", {})
        path = Path(capture.get("path", "")).resolve()
        require(path.parent == folder.resolve() and path.name == f"frame-{second:04d}.png"
                and path.is_file() and not path.is_symlink(), "Captured image escaped its owned output or has wrong identity")
        require(capture.get("paused") is (second == 0), "Authored and actual Play captures must remain distinct")
        material = capture.get("material_display", {})
        require(all(type(material.get(k)) is int and material[k] >= 0 for k in ("generation", "render_serial", "revision")),
                "Captured pixels lack an uploaded material identity")
        displayed = capture.get("rendered_actor_frame", {})
        require(type(displayed.get("available")) is bool and displayed.get("mode"), "Displayed actor-frame availability is not explicit")
        if displayed["available"]:
            require(displayed.get("world_generation") == material["generation"]
                    and displayed.get("revision") == material["revision"], "Rendered actors and native material identities differ")
        actors = row.get("actors", [])
        require(1 <= len(actors) <= 8, "Authoritative physical actor limit exceeded or actor data absent")
        ids = [actor.get("instance_id") for actor in actors]
        require(len(set(ids)) == len(ids) and SCENES[scene] in ids, "Duplicate or absent physical actor identity")
        if roster is None:
            roster = ids
        require(ids == roster, "Unexpected physical roster change during read-only observation")
        for actor in actors:
            position = actor.get("observation", {}).get("position")
            require(isinstance(position, list) and len(position) == 2 and all(finite(x) for x in position),
                    "Actor position is not an actual finite copied physical observation")
            require(actor.get("tick") == tick, "Copied actor pose belongs to another physical tick")
            if second:
                require(actor.get("decisions", 0) > 0 and actor.get("status") == "policy"
                        and not actor.get("error"), "Playing physical actor has no admitted procedural decision")
                identity = (actor.get("run_id"), actor.get("epoch"), actor.get("generation"))
                if second == 1:
                    admitted_generations[actor["instance_id"]] = identity
                require(identity == admitted_generations[actor["instance_id"]], "Observer unexpectedly changed actor authority")
            memory = actor.get("memory", {})
            require(all(len(memory.get(key + "_tail", [])) <= 8 for key in ("visited", "interests", "obstructions"))
                    and len(actor.get("recent_decisions_tail", [])) <= 8, "Copied diagnostic budget exceeded")
        images[path.name] = {"sha256": digest(path), "bytes": path.stat().st_size, "dimensions": png_dimensions(path),
                             "requested_simulation_second": second, "actual_simulation_seconds": observed_time,
                             "physical_tick": tick, "native_tick": native, "camera_mode": row.get("camera_mode")}
    return {"images": images, "actor_count": len(roster), "samples": len(samples),
            "actual_simulation_seconds": report["actual_simulation_seconds"],
            "physical_ticks": report["physical_ticks"], "native_ticks": report["native_ticks"]}


def observer_identity(allow_delta: bool = False) -> dict:
    parent = Path(__file__).resolve().parent
    root = parent.parents[1]
    commit = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
    result = {"commit": commit, "files_sha256": {}, "local_delta": []}
    for name in OBSERVER_FILES:
        path = parent / name
        relative = path.relative_to(root).as_posix()
        require(path.is_file() and not path.is_symlink(), "Missing external observer input: " + relative)
        result["files_sha256"][relative] = digest(path)
        try:
            original = subprocess.check_output(["git", "-C", str(root), "show", "HEAD:" + relative], stderr=subprocess.DEVNULL)
        except subprocess.CalledProcessError:
            original = None
        if original != path.read_bytes():
            result["local_delta"].append(relative)
    require(allow_delta or not result["local_delta"], "Commit external observer inputs before actual graphical observation")
    return result


def make_media(ffmpeg: Path, folder: Path, scene: str, seconds: int) -> dict:
    """Derivative presentation only; original PNGs and their hashes stay intact."""
    media = folder.parent / "media"
    media.mkdir()
    caption = ("SAMPLED TIMELAPSE - approximately one frame per simulation second; playback six samples per second.\n"
               "Not continuous video or hardware FPS. Actual tick and wall timestamps are in watch-report.json.")
    (media / "TIMELAPSE.txt").write_text(caption + "\n", encoding="utf-8")
    video = media / (scene + "-sampled-timelapse.mp4")
    # A padded banner is part of the derivative movie, never the raw evidence.
    video_filter = ("pad=ceil(iw/2)*2:ceil((ih+72)/2)*2:0:0:black,"
                    "drawtext=text='SAMPLED TIMELAPSE - 1 sample per simulated second - playback 6 samples per second':"
                    "fontcolor=white:fontsize=15:x=12:y=h-60,"
                    "drawtext=text='Not continuous video or hardware FPS - actual times in watch-report.json':"
                    "fontcolor=white:fontsize=15:x=12:y=h-34")
    commands = [([str(ffmpeg), "-hide_banner", "-loglevel", "error", "-nostdin", "-n", "-framerate", "6",
                  "-i", str(folder / "frame-%04d.png"), "-vf", video_filter,
                  "-c:v", "libx264", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(video)], "video.log")]
    sheet = media / (scene + "-contact-sheet.png")
    selected = [0, seconds // 5, seconds * 2 // 5, seconds * 3 // 5, seconds * 4 // 5, seconds]
    selection = "+".join(f"eq(n\\,{n})" for n in selected)
    sheet_filter = (f"select='{selection}',scale=512:-1,pad=iw:ih+26:0:0:black,"
                    "drawtext=text='Requested simulation second %{pts\\:hms}':fontcolor=white:fontsize=13:x=8:y=h-22,"
                    "tile=3x2")
    commands.append(([str(ffmpeg), "-hide_banner", "-loglevel", "error", "-nostdin", "-n", "-framerate", "1",
                      "-i", str(folder / "frame-%04d.png"), "-vf", sheet_filter, "-frames:v", "1", str(sheet)], "contact-sheet.log"))
    records = []
    for command, log_name in commands:
        started = time.monotonic()
        with (media / log_name).open("wb") as log:
            process = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        records.append({"command": command, "exit_code": process.returncode,
                        "wall_seconds": round(time.monotonic() - started, 3), "log_sha256": digest(media / log_name)})
        require(process.returncode == 0, "Derivative media conversion failed; original samples retained")
    return {"semantics": caption, "playback_samples_per_second": 6,
            "requested_sample_interval_simulation_seconds": 1, "contact_sheet_requested_seconds": selected,
            "processes": records, "files_sha256": {p.name: digest(p) for p in sorted(media.iterdir()) if p.is_file()}}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--application", type=Path, required=True)
    parser.add_argument("--application-revision", type=full_application_revision, default=FROZEN_APPLICATION,
                        help="Exact immutable application commit; defaults to the retained a725 baseline")
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--scene", action="append", choices=list(SCENES), dest="scenes")
    parser.add_argument("--seconds", type=int, default=60)
    parser.add_argument("--timeout-seconds", type=int, default=1800)
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--ffmpeg", type=Path, help="Optional media converter; exact hash/version recorded, raw PNGs remain authoritative")
    args = parser.parse_args()
    require(10 <= args.seconds <= 120 and 120 <= args.timeout_seconds <= 1800, "Invalid bounded observation allowance")
    application = args.application.resolve(strict=True)
    binary = args.godot.resolve(strict=True)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    sys.path.insert(0, str(application / "tools"))
    q = importlib.import_module("qualify_ambient_living")
    require(q.ROOT.resolve() == application, "Qualification helpers did not come from the frozen application")
    script = Path(__file__).resolve().with_name("watch_ambient_living.gd")
    require(not script.is_relative_to(application / "godot"), "Observer must remain outside the frozen Godot project")
    report = {"schema": "ambient-living-sustained-watch-campaign/v1", "status": "running",
              "compile_only": args.check_only, "graphical_observation": False, "cases": [],
              "input_custody": "pending", "platform": sys.platform, "owner_playfeel_accepted": False,
              "requested_application_revision": args.application_revision}
    started = time.monotonic()
    try:
        identity = q.source_identity()
        application_revision = admit_application_revision(identity, args.application_revision)
        runtime = q.verify_runtime_identity()
        project = application / "godot"
        project_inputs = q.project_identity(project, identity, runtime)
        engine = q.engine_identity(binary)
        version = subprocess.check_output([str(binary), "--version"], text=True, timeout=30).strip()
        require(version == q.GODOT_VERSION, "Official engine version mismatch")
        observer = observer_identity(allow_delta=args.check_only)
        report.update({"application": identity, "admitted_application_revision": application_revision,
                       "project_inputs_sha256": project_inputs,
                       "project_input_count": len(project_inputs), "runtime": runtime, "engine": engine,
                       "godot_version": version, "observer": observer})
        q.write_json(output / "watch-campaign.json", report)
        env = q.case_environment(output / "userdata" / "import")
        imported = q.execute([str(binary), "--headless", "--path", str(project), "--editor", "--quit"],
                             output / "import", env, q.execution_policy.watchdog_seconds("godot_import_seconds"))
        imported["process_sha256"] = digest(output / "import/process.json")
        report["import"] = imported
        require(imported["status"] == "passed", "Frozen application import failed")
        if args.check_only:
            checked = q.execute([str(binary), "--headless", "--path", str(project), "--script", str(script), "--check-only"],
                                output / "compile", env, 120)
            checked["process_sha256"] = digest(output / "compile/process.json")
            report["compile"] = checked
            require(checked["status"] == "passed", "External observer compile-only check failed")
        else:
            ffmpeg = args.ffmpeg.resolve(strict=True) if args.ffmpeg else None
            if ffmpeg:
                report["media_converter"] = {"path": str(ffmpeg), "sha256": digest(ffmpeg),
                    "version": subprocess.check_output([str(ffmpeg), "-version"], text=True, timeout=30).splitlines()[0]}
            for scene in args.scenes or SCENES:
                destination = output / scene
                destination.mkdir()
                frames = destination / "frames"
                environment = q.case_environment(output / "userdata" / scene)
                environment.update({"CYBERSAND_SOURCE_REVISION": application_revision,
                                    "CYBERSAND_AMBIENT_LIVING_WATCH": str(frames),
                                    "CYBERSAND_AMBIENT_WATCH_SCENE": scene,
                                    "CYBERSAND_AMBIENT_WATCH_SECONDS": str(args.seconds)})
                command = [str(binary), "--audio-driver", "Dummy", "--path", str(project), "--rendering-method", "gl_compatibility"]
                command += ["--rendering-driver", "opengl3_angle"] if sys.platform == "win32" else ["--display-driver", "x11"]
                command += ["--script", str(script)]
                print("AMBIENT sustained graphical observation:", scene, args.seconds, "simulation seconds", flush=True)
                record = q.execute(command, destination / "process", environment, args.timeout_seconds)
                record["process_sha256"] = digest(destination / "process/process.json")
                row = {"scene": scene, "status": record["status"], "process": record}
                try:
                    require(record["status"] == "passed", "Actual graphical observer process failed")
                    text = (destination / "process/process.log").read_text(encoding="utf-8")
                    terminal = [line.split(" ", 1)[1] for line in text.splitlines() if line.startswith("AMBIENT_LIVING_WATCH ")]
                    require(len(terminal) == 1 and json.loads(terminal[0]).get("failures") == [], "Missing or failing sustained terminal")
                    detail = frames / "watch-report.json"
                    row["observation"] = validate_watch(frames, json.loads(detail.read_text()), scene, args.seconds,
                        application_revision, digest(script), q.GODOT_WINDOWS_GUI_SHA256 if sys.platform == "win32" else q.GODOT_LINUX_SHA256,
                        "opengl3_angle" if sys.platform == "win32" else "opengl3")
                    row["report_sha256"] = digest(detail)
                    if ffmpeg:
                        row["media"] = make_media(ffmpeg, frames, scene, args.seconds)
                except Exception as error:
                    row["status"] = "failed"
                    row["error"] = str(error)
                report["cases"].append(row)
                q.write_json(output / "watch-campaign.json", report)
            report["graphical_observation"] = bool(report["cases"]) and all(c["status"] == "passed" for c in report["cases"])
            require(report["graphical_observation"], "At least one sustained scene failed; original evidence retained")
        require(q.source_identity() == identity and q.project_identity(project, identity, runtime) == project_inputs,
                "Frozen application/project changed during external observation")
        require(q.verify_runtime_identity() == runtime and q.engine_identity(binary) == engine,
                "Official engine or retained runtime changed during observation")
        require(observer_identity(allow_delta=args.check_only) == observer, "External observer bytes changed during execution")
        report["input_custody"] = "passed"
        report["status"] = "passed"
    except Exception as error:
        report["status"] = "failed"
        report["error"] = str(error)
        print(str(error), file=sys.stderr, flush=True)
    finally:
        report["elapsed_wall_seconds"] = round(time.monotonic() - started, 3)
        q.write_json(output / "watch-campaign.json", report)
    print("AMBIENT_GRAPHICAL_WATCH", json.dumps({"status": report["status"], "compile_only": args.check_only,
          "graphical_observation": report["graphical_observation"], "scenes": len(report["cases"])}), flush=True)
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())

