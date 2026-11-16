#!/usr/bin/env python3
"""One-shot, source-bound Deepworks diagnostic. Completion is not acceptance."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import struct
import subprocess
import sys
import time

SOURCE = "93a5e85dc9d5459a5f9cce00839b64090a1a0573"
TREE = "1035c8ae3c30fb50dafd483916f1c21b59200e2d"
GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
GODOT_SHA256 = "f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75"
PROBES = {
    "native_packet_probe.gd": "9ef13adda62b828a7679bff40d2ea3608fd4861c27946fb0248bfe22662072e9",
    "renderer_time_probe.gd": "47cb3ce1162597d075b6f780e53519566f1c13fa676e90da21877f9e8b0bacfe",
}
RUNTIMES = {
    "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so": "787b23a8fb6ea732dc02243aa7097b21ace222dba5914ad67b41769fc1d1fe5f",
    "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so": "566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a",
}
PACKETS = {
    "play": "eb6aeb8255fd298d8408869dc687480a5d59f96d38d7cefe3eb69d3746c67e86",
    "scripted": "7d2b2ac02bd9f47f952c81113dba0f1470c4a278345b3e970c830a09b93c7953",
    "effects": "fce342d9416c3f01b7be762fc402238a6933a830763cd599c64d3f2176875d29",
    "background": "0649a8edcde12cfebade2af77eab30c8ceb2b8d6a22eb799737f98008ec95c79",
}
VARIANTS = {
    "authored_q": {
        "counterfactual": False,
        "recipe_hash": "828f5174b41aa5fa3ed693dae9bb463f24c49d8ce18b506af7573152afd83caa",
        "effects_sha256": PACKETS["effects"],
        "smoke": {(235, 929), (236, 929), (234, 930), (237, 930), (234, 931), (237, 931)},
    },
    "d1_x238_counterfactual": {
        "counterfactual": True,
        "recipe_hash": "ec7d8a8988883446028a3b08cb4d2f9e00b59eec656409fd6b38a0dad06e4648",
        "effects_sha256": "135f4e1119c7f7f46ac0a88f80fd3af90d9a15af9a17766331b8d1a50589d51e",
        "smoke": {(238, 929), (239, 929), (237, 930), (240, 930), (237, 931), (240, 931)},
    },
}


def sha256(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def git(project, *args):
    return subprocess.check_output(["git", "-C", str(project), *args], text=True, timeout=30).strip()


def save(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def run_once(argv, name, limit, output, executions):
    log = output / (name + ".log")
    started = time.monotonic()
    record = {"name": name, "argv": list(map(str, argv)), "timeout_seconds": limit, "attempts": 1}
    with log.open("wb") as stream:
        process = subprocess.Popen(record["argv"], stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            code = process.wait(timeout=limit)
            record["natural_completion"] = True
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait(timeout=5)
            code = process.returncode
            record["natural_completion"] = False
    record.update(returncode=code, seconds=round(time.monotonic() - started, 3), log=log.name, log_sha256=sha256(log))
    executions.append(record)
    require(record["natural_completion"] and code == 0, f"{name} did not complete successfully: {record}")
    text = log.read_text(encoding="utf-8", errors="replace")
    require(not any(token in text for token in ("SCRIPT ERROR:", "Parse Error:", "ERROR:", "CRASH:")), f"{name} contains an engine/script error")
    return text


def marker(text, prefix):
    matches = [line[len(prefix):] for line in text.splitlines() if line.startswith(prefix)]
    require(len(matches) == 1, f"Expected one {prefix} marker")
    return json.loads(matches[0])


def verify_variant_identity(receipt, variant):
    expected = VARIANTS[variant]
    require(receipt.get("scene_variant") == variant and receipt.get("counterfactual") is expected["counterfactual"] and receipt.get("recipe_hash") == expected["recipe_hash"], "Diagnostic variant identity differs")


def verify_packets(output, text, variant):
    directory = output / "Q-packet"
    receipt = json.loads((directory / "native-packet-diagnostic.json").read_text())
    terminal = marker(text, "DEEPWORKS_NATIVE_PACKET_DIAGNOSTIC ")
    verify_variant_identity(receipt, variant)
    verify_variant_identity(terminal, variant)
    packets = {**PACKETS, "effects": VARIANTS[variant]["effects_sha256"]}
    require(terminal.get("ok") is True and terminal.get("incremental_equals_full") is True, "Packet diagnostic marker failed")
    require(receipt.get("errors") == [] and receipt.get("incremental_equals_full_at_46") is True, "Packet diagnostic errors or incremental/full mismatch")
    require(receipt.get("final_layer_ticks") == {"play": 0, "scripted": 0, "effects": 46, "background": 0}, "Unexpected native layer tick schedule")
    require(set(receipt["initial_wave"]) == set(PACKETS) and all(v.get("enabled") is False for v in receipt["initial_wave"].values()), "Wave unexpectedly enabled in Deepworks")
    require(receipt.get("packet_sha256") == packets, "Packet receipt identities differ")
    for layer, expected in packets.items():
        path = directory / (layer + "-tick46.rg8")
        require(path.stat().st_size == 2097152 and sha256(path) == expected, f"Unauthenticated {layer} packet")
    return {"status": "authenticated", "packet_sha256": packets, "final_layer_ticks": receipt["final_layer_ticks"], "terminal": terminal}


def verify_render(output, text, variant):
    directory = output / "render-time-sweep"
    receipt = json.loads((directory / "renderer-time-diagnostic.json").read_text())
    terminal = marker(text, "DEEPWORKS_CAUSAL_RENDER_DIAGNOSTIC ")
    verify_variant_identity(receipt, variant)
    verify_variant_identity(terminal, variant)
    packets = {**PACKETS, "effects": VARIANTS[variant]["effects_sha256"]}
    smoke = VARIANTS[variant]["smoke"]
    require(receipt.get("status") == "diagnostic_complete" and receipt.get("errors") == [], "Renderer capture is incomplete or contains errors")
    require(receipt.get("source_commit") == SOURCE and receipt.get("probe_sha256") == PROBES["renderer_time_probe.gd"], "Render source/probe identity differs")
    require(receipt.get("packet_sha256") == packets and receipt.get("packet_bytes_unchanged") is True, "Render mutated packet identity")
    require(receipt.get("phases") == list(range(61)) and receipt.get("arms") == ["hybrid", "stack_no_relief"], "Predeclared experiment scope changed")
    require(receipt.get("pixel_channel_threshold") == 4 and receipt.get("minimum_native_air_pixels_per_source") == 4, "Original visibility thresholds changed")
    require(receipt.get("display") != "headless", "Actual display was not used")
    require({tuple(c["position"]) for c in receipt["native_smoke"]} == smoke, "Native smoke positions differ")
    records = receipt.get("captures", [])
    require(len(records) == 122, "Missing capture records")
    seen = set()
    images = {}
    negatives = {"hybrid": 0, "stack_no_relief": 0}
    phase_logs = [json.loads(line.split(" ", 1)[1]) for line in text.splitlines() if line.startswith("DEEPWORKS_PHASE_RECORD ")]
    require(len(phase_logs) == 122, "Missing or duplicate raw phase markers")
    for index, record in enumerate(records):
        require(record.get("scene_variant") == variant and record.get("counterfactual") is VARIANTS[variant]["counterfactual"], "Capture variant identity differs")
        phase, arm = record["phase_seconds"], record["arm"]
        key = (phase, arm)
        require(key in {(p, a) for p in range(61) for a in negatives} and key not in seen, "Unexpected or duplicate phase/arm")
        seen.add(key)
        cells = record.get("cells", [])
        require(len(cells) == 6 and {tuple(c["position"]) for c in cells} == smoke and record.get("native_mask_cells") == 6, "Missing native cell samples")
        visible = 0
        for cell in cells:
            for field in ("air_on_rgba8", "air_off_rgba8", "effects_surface_rgba8"):
                rgba = cell[field]
                require(isinstance(rgba, list) and len(rgba) == 4 and all(type(v) is int and 0 <= v <= 255 for v in rgba), "Invalid RGBA sample")
            delta = max(abs(cell["air_on_rgba8"][i] - cell["air_off_rgba8"][i]) for i in range(3))
            require(cell["maximum_rgb_channel_delta"] == delta and cell["passes_original_channel_threshold"] == (delta >= 4), "Inconsistent recorded pixel contrast")
            visible += delta >= 4
        require(record["visible_native_air_pixels"] == visible and record["meets_original_minimum"] == (visible >= 4), "Visibility receipt arithmetic differs")
        negatives[arm] += visible < 4
        expected_log = {"scene_variant": variant, "counterfactual": VARIANTS[variant]["counterfactual"], "phase_seconds": phase, "arm": arm, "visible_native_air_pixels": visible, "meets_original_minimum": visible >= 4}
        require(all(phase_logs[index].get(k) == v for k, v in expected_log.items()), "Raw phase log differs from receipt")
        for state in ("air_on", "air_off"):
            expected_name = f"phase-{int(phase):02d}-{arm}-{state.replace('_', '-')}.png"
            require(record[state] == expected_name and expected_name not in images, "Unexpected or duplicate image path")
            path = directory / expected_name
            with path.open("rb") as stream:
                header = stream.read(24)
            require(header[:8] == b"\x89PNG\r\n\x1a\n" and header[12:16] == b"IHDR" and struct.unpack(">II", header[16:24]) == (1024, 1024), "Invalid PNG dimensions/header")
            digest = sha256(path)
            require(digest == record[state + "_sha256"], "PNG bytes differ from original capture receipt")
            images[expected_name] = digest
    require(set(p.name for p in directory.glob("*.png")) == set(images) and len(images) == 244, "Incomplete or extra PNG inventory")
    require(receipt.get("visibility_failures_by_arm") == negatives, "Negative observations were omitted")
    expected_terminal = {"status": "diagnostic_complete", "phases": 61, "arms": 2, "captured_pairs": 122, "visibility_failures_by_arm": negatives, "packet_bytes_unchanged": True}
    require(all(terminal.get(k) == v for k, v in expected_terminal.items()), "Terminal diagnostic marker differs")
    save(output / "image-inventory.json", images)
    return {"status": "diagnostic_complete", "records": 122, "pngs": 244, "visibility_failures_by_arm": negatives, "image_inventory": "image-inventory.json", "rgba_scope": "Recorded six-cell samples checked for shape and contrast arithmetic; original PNG pixels remain available for independent readback."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.project, args.godot, args.output = args.project.resolve(), args.godot.resolve(), args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    inputs = Path(__file__).resolve().parent
    result = {"schema": "deepworks-one-shot-hosted-diagnostic-v1", "status": "incomplete", "qualification": "HOLD: original mandatory Deepworks failure remains; this run is diagnostic only", "project_source": SOURCE, "project_tree": TREE, "diagnostic_commit": os.environ.get("GITHUB_SHA", ""), "run_id": os.environ.get("GITHUB_RUN_ID", ""), "run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT", ""), "executions": [], "errors": []}
    try:
        require(git(args.project, "rev-parse", "HEAD") == SOURCE and git(args.project, "rev-parse", "HEAD^{tree}") == TREE, "Exact project source/tree mismatch")
        require(not git(args.project, "status", "--porcelain", "--untracked-files=no"), "Project has tracked changes")
        require(result["run_attempt"] in ("", "1"), "A rerun is outside this one-shot diagnostic registration")
        result["input_sha256"] = {p.name: sha256(p) for p in [Path(__file__), *(inputs / n for n in PROBES)]}
        for name, expected in PROBES.items():
            require(result["input_sha256"][name] == expected, f"Diagnostic probe changed: {name}")
        result["runtime_sha256"] = {name: sha256(args.project / name) for name in RUNTIMES}
        require(result["runtime_sha256"] == RUNTIMES, "Published runtime bytes differ")
        require(sha256(args.godot) == GODOT_SHA256, "Godot executable differs")
        result["godot_sha256"] = GODOT_SHA256
        version = subprocess.check_output([str(args.godot), "--version"], text=True, timeout=30).strip()
        require(version == GODOT_VERSION, "Godot version differs")
        result["godot_version"] = version
        save(args.output / "execution.json", result)
        common = [str(args.godot), "--path", str(args.project / "godot")]
        run_once(common + ["--headless", "--editor", "--import"], "import", 180, args.output, result["executions"])
        result["variants"] = {}
        for variant in VARIANTS:
            destination = args.output / variant
            destination.mkdir()
            result["variants"][variant] = {"status": "incomplete"}
            try:
                text = run_once(common + ["--headless", "--script", str(inputs / "native_packet_probe.gd"), "--", "--scene-variant=" + variant, "--probe-output=" + str(destination / "Q-packet")], variant + "-native-packet", 90, args.output, result["executions"])
                result["variants"][variant]["native_packets"] = verify_packets(destination, text, variant)
                text = run_once(common + ["--display-driver", "x11", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--script", str(inputs / "renderer_time_probe.gd"), "--", "--scene-variant=" + variant, "--packet-root=" + str(destination / "Q-packet"), "--capture-output=" + str(destination / "render-time-sweep")], variant + "-renderer-time-sweep", 600, args.output, result["executions"])
                result["variants"][variant]["render"] = verify_render(destination, text, variant)
                result["variants"][variant]["status"] = "diagnostic_complete"
            except Exception as error:
                result["errors"].append(variant + ": " + str(error))
                print(variant + ": " + str(error), file=sys.stderr)
            save(args.output / "execution.json", result)
        require(not git(args.project, "status", "--porcelain", "--untracked-files=no"), "Tracked project source changed during diagnostic")
        require({name: sha256(args.project / name) for name in RUNTIMES} == RUNTIMES, "Runtime changed during diagnostic")
        if not result["errors"]:
            result["status"] = "diagnostic_complete"
    except Exception as error:
        result["errors"].append(str(error))
        print(str(error), file=sys.stderr)
    finally:
        save(args.output / "execution.json", result)
        manifest = {str(p.relative_to(args.output)): sha256(p) for p in sorted(args.output.rglob("*")) if p.is_file() and p.name not in {"files.sha256.json"}}
        save(args.output / "files.sha256.json", manifest)
    print("DEEPWORKS_HOSTED_DIAGNOSTIC " + json.dumps({"status": result["status"], "errors": result["errors"], "variants": result.get("variants"), "qualification": result["qualification"]}, sort_keys=True))
    return 0 if result["status"] == "diagnostic_complete" else 1


if __name__ == "__main__":
    raise SystemExit(main())
