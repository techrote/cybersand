"""Fly the two owner starts in the already admitted Stock Safe Windows project."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/pubpres_playability_build"))
from process_owner import bounded_process


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contact", action="store_true", help="Use the live thruster Fire, wall and Water course")
    parser.add_argument("--thruster-fire", action="store_true", help="Enable the live thrusters during the 90-second patrol")
    for name in ("qualified", "engine", "output"):
        parser.add_argument("--" + name, required=True, type=Path)
    args = parser.parse_args()
    project = (args.qualified / "project").resolve()
    summary = json.loads((args.qualified / "SUMMARY.json").read_bytes())
    source = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    engine = args.engine.resolve()
    if (os.name != "nt" or not summary["complete"] or summary["focus"] != "held-placement"
            or summary["source"]["source_commit"] != source or digest(engine) != summary["engine_sha256"]):
        raise ValueError("Expected the exact, qualified Windows Stock Safe project and engine")
    for fixture, target in [(ROOT / "tools/pubpres_final_recovery/flight_visibility.gd", "flight_visibility.gd"),
                            (Path(__file__).with_name("owner_start.gd"), "pubpres_playability_owner_start.gd")]:
        shutil.copyfile(fixture, project / "tests" / target)
    script = "flight_fire_contact.gd" if args.contact else "flight_visibility.gd"
    if args.contact:
        shutil.copyfile(ROOT / "tools/pubpres_final_recovery" / script, project / "tests" / script)
    environment = {k: v for k, v in os.environ.items() if not k.startswith(("CYBERSAND_", "WB_COMBINED_"))}
    settings = {"SOURCE_REVISION": source, "MATERIAL_PUBLICATION": "full", "DIAG_FULL_IMAGE_SLOTS": "2",
                "DIAG_MATERIAL_DEADLINE_HZ": "0", "DIAG_MATERIAL_STEP_INTERVAL": "0",
                "DIAG_PHYSICS_PUBLICATION": "early", "DIAG_PRESENTATION": "coherent",
                "DIAG_SAME_FRAME_CONTINUATION": "0", "MATERIAL_QUEUE_THREAD": "safe", "DIAG_WATER_COMPOSITION": "1",
                "DIAG_ACTUAL_SUBMISSION": "0", "DIAG_MATERIAL_TIMING": "measured", "DIAG_RENDER_CADENCE": "repaired",
                "DIAG_NATIVE_RENDEZVOUS": "0", "PLAYABILITY_TASK_COMPLETION_BARRIER": "0",
                "WORKBENCH_FLIGHT_PACING": "1", "WORKBENCH_COUPLING_CLOCK": "1", "WORKBENCH_EMPTY_EFFECTS": "1",
                "FLIGHT_SECONDS": "90", "FLIGHT_FRAMEBUFFER": "1"}
    environment.update({"CYBERSAND_" + k: v for k, v in settings.items()})
    if args.thruster_fire:
        environment["CYBERSAND_FLIGHT_THRUSTER_FIRE"] = "1"
    passed = True
    for scene in ("wave512", "mixed2048"):
        folder = (args.output / scene).resolve()
        profile = folder / "flight-profile"
        profile.mkdir(parents=True)
        startup = folder / "startup.json"
        env = dict(environment, APPDATA=str(profile), LOCALAPPDATA=str(profile), CYBERSAND_FINAL_SCENE=scene,
                   CYBERSAND_PLAYABILITY_OWNER_RECEIPT=str(startup))
        cmd = [str(engine), "--path", str(project), "--resolution", "1280x720", "--audio-driver", "Dummy",
               "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3_angle",
               "--render-thread", "safe", "--script", "res://tests/" + script]
        with (folder / "stdout.log").open("x", encoding="utf-8") as stream:
            code, timeout = bounded_process(cmd, cwd=ROOT, env=env, stdout=stream, timeout=480)
        for segment in profile.rglob("pubpres-gameplay/segment-*.jsonl"):
            shutil.copyfile(segment, folder / segment.name)
        report = folder / ("fire-contact.json" if args.contact else "flight.json")
        if code or timeout or not startup.is_file() or not report.is_file():
            print(f"{scene} failed: exit={code} timeout={timeout}", flush=True)
            passed = False
            continue
        ready = json.loads(startup.read_bytes())
        flight = json.loads(report.read_bytes())
        expected = {"display_server": "Windows", "platform": "Windows", "scene": scene, "source_commit": source,
                    "engine_sha256": summary["engine_sha256"], "native_sha256": summary["native"]["binary_sha256"],
                    "rapier_sha256": summary["rapier_sha256"], "flight_pacing_enabled": True,
                    "coupling_clock_enabled": True, "empty_effects_enabled": True}
        ok = (all(ready.get(k) == v for k, v in expected.items()) and flight["source"] == source
              and any(folder.glob("segment-*.jsonl")))
        if args.contact:
            ok &= (flight["pass"] and flight["fire"] and flight["fire_writes"] > 0 and flight["fire_skin_draws"] > 0
                   and all(flight["contact_draws"][kind] > 0 for kind in ("wall", "water"))
                   and not any(flight["missing"].values())
                   and all(digest(folder / f"{kind}-moving.png") == flight["witnesses"][kind]["sha256"]
                           for kind in ("wall", "water", "fire")))
        else:
            ok &= (flight["elapsed_usec"] >= 90_000_000 and flight["hidden_draws"] == 0
                   and digest(folder / "moving-flyer.png") == flight["moving_pixels"]["sha256"])
            if args.thruster_fire:
                ok &= flight["thruster_fire"] and flight["observed_fire_writes"] > 0
        print(f"{scene} {script} passed={ok}", flush=True)
        passed &= ok
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
