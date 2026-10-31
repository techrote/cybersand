#!/usr/bin/env python3
"""Prepare or reverify a local PLAY desktop checklist; never execute Godot."""
from __future__ import annotations

import argparse
import csv
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shlex
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/ci"))
from execution_policy import watchdog_seconds
SCRIPT = "tools/play/create_manual_packet.py"
GUIDE = "docs/operations/play-desktop-manual-qualification.md"
SCHEMA = "play-desktop-manual-packet-v1"
RIGS = (
    ("stuntbuggy", "Loose Cannon", "W/S drive/reverse; A/D or Q/E lean; Space hops from support; Shift brakes; hold C for recovery."),
    ("trialsbike", "Trials Rat", "W/S throttle/reverse; A/D or Q/E lean; hold Space on support then release to hop; Shift brakes; hold C for recovery."),
    ("acrobat", "Afterimage", "A/D run; Space jump/double jump; Shift slide, tap to roll; Shift+Space bullet jump (mouse aim); Space cancels roll; C brakes, hold airborne to glide."),
    ("arcadelander", "Vector Rush", "W or Space thrust; A/D or Q/E rotate; S reverse thrust; Shift airbrakes; tap C toggles damped/coast flight."),
    ("jetbarrel", "Barrel Rocket", "W or Space body-axis jet; A/D or Q/E rotate; S reverse thrust; Shift brakes; hold C for upright assistance."),
)
PER_RIG_CASES = (
    ("display", "actual display", "Build this rig; observe the real actor and terrain in follow and overview; no blank, stale or mismatched actor."),
    ("keyboard", "physical keyboard", "Use the rig's movement, primary, secondary and auxiliary controls; release and repress each. Record responsiveness, missed/repeated actions and intentional mechanical differences."),
    ("gamepad", "physical gamepad", "Use left stick, A/B/X and both shoulders; compare with keyboard actions; release all controls before handover. Record device model and mapping."),
    ("pause", "keyboard / selected gamepad", "Move, hold a movement control, press P to pause, then P to resume while still held. Repeat with Escape and selected-pad Start. No resumed actuation until release/repress; paused actor and lap remain still."),
    ("focus", "real OS focus", "Hold movement, switch to another application, release there, return; then repeat returning with the control held. No stale actuation; neutral release rearms. Momentum may continue while unfocused."),
    ("modal", "physical keyboard", "While moving, open Play session, change an unsubmitted choice, close; release/repress. UI consumes controls; applied rig/options stay unchanged until Build."),
    ("disconnect", "physical gamepad", "Hold movement/A, unplug the selected controller, reconnect with controls held, then release/repress. No queued action survives disconnect; reconnect requires neutral rearm."),
    ("camera_lap", "physical input / display", "Use F while moving; traverse checkpoints in order using the rig's own motion. Record checkpoint/lap changes, no duplicate crossing credit and timer freeze on P. An incomplete traversal stays untested."),
    ("reset_exit", "physical input / display", "Use R twice and resume after neutral release; accepted rig/policy persist, lap starts fresh. Open Play session and click Return to launcher (F2 is an optional shortcut); re-enter Play session and build a fresh rig."),
)
GLOBAL_CASES = (
    ("startup", "actual display", "Record launch-to-launcher and launcher-to-Main visibility separately. Time Build selected session to visible applied actor/terrain readiness; retain video/log. The automated startup observation runs from Build to the first completed Main callback with that identity ready. Its execution watchdog comes from the source execution policy; elapsed times remain performance observations. Record launcher reading time separately. Manual display timing does not replace the automatic callback receipt; incomplete or failed startup stays failed."),
    ("selection", "keyboard / display", "Select Keyboard only and Free play; connected gamepad cannot drive it, lap UI is absent. Restore keyboard+gamepad/lap and verify actual applied labels."),
    ("policy", "keyboard / display", "Build Current, then an explicitly supported Water pressure choice using the policy editor. Screenshot requested family/variant and applied text; copy the applied native policy_hash and construction receipt_hash from the tooltip. Select Oil and inspect its disabled/unavailable pressure entry and refusal reason; applied state must remain unchanged. Do not inject an unsupported request."),
    ("secondary_device", "physical gamepads", "With two pads, verify only the selected first pad controls the course. An unrelated second-pad disconnect must not revoke the selected pad; record enumeration/order. Untested if unavailable."),
    ("fault", "observed fault only", "If STOPPED/fault occurs, retain exact log and previous applied identity; do not infer recovery from counters. Record whether an explicit R/reset actually recovers or truthfully refuses. Do not inject a fault in this manual packet."),
    ("feel", "human judgment", "Record overall control clarity, actor visibility, responsiveness and worst visible stalls for all five rigs. Record display/refresh/GPU and any independently measured frame times; submission/native tick rates are not displayed FPS."),
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def digest(path: Path, algorithm: str = "sha256") -> str:
    result = hashlib.new(algorithm)
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def git(root: Path, *arguments: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(root), *arguments], timeout=watchdog_seconds("operation_seconds"))


def clean_identity(root: Path, expected: str) -> dict:
    require(re.fullmatch(r"[0-9a-f]{40}", expected) is not None, "--expected-sha must be a full lowercase commit SHA")
    require(git(root, "rev-parse", "HEAD").decode().strip() == expected, "Checkout HEAD differs from the expected source")
    require(not git(root, "status", "--porcelain=v1", "--untracked-files=all").strip(),
            "Checkout is not clean; preserve and reconcile local/untracked files before generating this packet")
    return {"commit": expected, "tree": git(root, "rev-parse", "HEAD^{tree}").decode().strip()}


def verify_engine_files(archive: Path, executable: Path, expected_hash: str,
                        algorithm: str, members: tuple[str, ...], selected_member: str) -> dict:
    """Authenticate bytes against an approved archive without launching any executable."""
    require(archive.is_file() and executable.is_file(), "Godot archive and executable must both exist")
    require(digest(archive, algorithm) == expected_hash, "Godot archive does not match the repository's official pin")
    records = {}
    with zipfile.ZipFile(archive) as bundle:
        require(bundle.testzip() is None, "Godot archive CRC failure")
        for member in members:
            require(bundle.namelist().count(member) == 1, "Missing or duplicate pinned Godot archive member: " + member)
            path = executable if member == selected_member else executable.parent / member
            require(path.is_file(), "Required Godot companion is absent: " + member)
            with bundle.open(member) as stream:
                hasher = hashlib.sha256()
                for block in iter(lambda: stream.read(1024 * 1024), b""):
                    hasher.update(block)
            require(path.stat().st_size == bundle.getinfo(member).file_size and digest(path) == hasher.hexdigest(),
                    "Godot executable differs from authenticated archive: " + member)
            records[member] = {"path": str(path.resolve()), "sha256": hasher.hexdigest(), "bytes": path.stat().st_size}
    return {"archive": str(archive), "archive_algorithm": algorithm, "archive_digest": expected_hash,
            "archive_bytes": archive.stat().st_size, "selected_executable": str(executable),
            "executables": records, "identity_method": "pinned official archive and matching bytes; no executable probe"}


def engine_identity(root: Path, archive: Path, executable: Path, target: str) -> dict:
    sys.path.insert(0, str(root / "tools/ci"))
    import run_windows_godot_regressions as windows
    lock = json.loads((root / "third_party/godot-runtime.lock.json").read_text(encoding="utf-8"))
    require(lock["godot_version"] == windows.GODOT_VERSION, "Godot pins disagree")
    if target == "windows":
        members = ("Godot_v4.7-stable_win64.exe", "Godot_v4.7-stable_win64_console.exe")
        require(executable.name in members, "Select the official Windows executable name; both companion executables are checked")
        identity = verify_engine_files(archive, executable, windows.GODOT_SHA512, "sha512", members, executable.name)
    else:
        require(archive.stat().st_size == lock["editor"]["size"], "Linux Godot archive size differs from the pin")
        require(os.access(executable, os.X_OK), "Pinned Linux Godot file is not executable; restore its archive permissions")
        member = "Godot_v4.7-stable_linux.x86_64"
        identity = verify_engine_files(archive, executable, lock["editor"]["sha256"], "sha256", (member,), member)
    return identity | {"version": lock["godot_version"]}


def collect(root: Path, expected: str, archive: Path, executable: Path) -> tuple[dict, dict]:
    target = "windows" if sys.platform == "win32" else "linux" if sys.platform.startswith("linux") else ""
    require(bool(target) and platform.machine().lower() in ("x86_64", "amd64"), "Use the actual x86_64 Windows or Linux target host")
    source = clean_identity(root, expected)
    require(git(root, "show", "HEAD:" + SCRIPT) == Path(__file__).read_bytes(),
            "Packet generator is not the exact generator committed at the selected source")
    sys.path.insert(0, str(root / "tools/ci"))
    import check_repository
    import run_windows_godot_regressions as windows
    # Preserve the complete existing gate, including all retained LFS runtimes.
    preflight = check_repository.check(root, require_materialized=True)
    require(preflight.get("status") == "passed" and not preflight.get("errors"),
            "Repository materialized-provenance gate failed: " + "; ".join(preflight.get("errors", [])))
    native_name = "runtime-provenance.json" if target == "windows" else "runtime-provenance.linux.json"
    native_path = root / "godot/addons/cybersand_native" / native_name
    native = json.loads(native_path.read_text(encoding="utf-8"))
    require(set(native["source_inputs"]) == windows.native_input_paths(root),
            "Native provenance does not cover the complete current source/header inventory")
    rapier_path = root / f"godot/addons/godot-rapier2d/runtime-provenance.{target}.json"
    rapier = json.loads(rapier_path.read_text(encoding="utf-8"))
    runtimes = {}
    for label, manifest, manifest_path in (("native", native, native_path), ("rapier", rapier, rapier_path)):
        artifact = root / manifest["artifact"]
        require(artifact.is_file() and digest(artifact) == manifest["sha256"] and artifact.stat().st_size == manifest["size"],
                "Missing or stale selected " + label + " runtime")
        runtimes[label] = {"path": manifest["artifact"], "sha256": manifest["sha256"], "bytes": manifest["size"],
                           "source_commit": manifest.get("source_commit"), "build_commit": manifest.get("build_commit"),
                           "provenance_path": manifest_path.relative_to(root).as_posix(), "provenance_sha256": digest(manifest_path)}
    engine = engine_identity(root, archive, executable, target)
    require(clean_identity(root, expected) == source, "Source changed during preflight")
    identity = {"schema": SCHEMA, "created_utc": datetime.now(timezone.utc).isoformat(), "source": source,
                "checkout": str(root), "platform": target, "engine": engine, "runtimes": runtimes,
                "host": {"system": platform.platform(), "architecture": platform.machine(),
                         "processor": platform.processor(), "logical_cpus": os.cpu_count(), "python": sys.version},
                "qualification": "identity/preflight only; all physical, actual-display and human cases start untested"}
    return identity, preflight


def cases() -> list[dict]:
    rows = []
    for rig, _name, _controls in RIGS:
        for kind, device, procedure in PER_RIG_CASES:
            rows.append({"case_id": rig + "/" + kind, "rig": rig, "device": device, "procedure_and_expected": procedure})
    rows += [{"case_id": "shared/" + kind, "rig": "all", "device": device, "procedure_and_expected": procedure}
             for kind, device, procedure in GLOBAL_CASES]
    return [row | {"status": "untested", "observed_at_utc": "", "operator": "", "observations": "", "evidence_files": ""} for row in rows]


def ps_quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def packet_text(identity: dict) -> str:
    sha = identity["source"]["commit"]
    rows = "\n".join(f"| {name} / `{rig}` | {controls} |" for rig, name, controls in RIGS)
    return f"""# CyberSand PLAY: physical desktop record

Source `{sha}` / tree `{identity['source']['tree']}`; actual host `{identity['platform']}`.
Engine `{identity['engine']['version']}`. Exact runtime hashes and local host paths are in IDENTITY.json.
This packet has not tested a device, display or human judgment. RESULTS.csv starts entirely `untested`.

## Launch and select

Run `launch.ps1` from PowerShell on Windows, or `bash launch.sh` on Linux. The script first
repeats the unchanged full repository/materialized-runtime gate and exact engine/source checks.
It then opens the existing feature launcher and preserves a new console log. The generator
itself never executes Godot, including a version probe. Do not move this packet or checkout
between generation and launch; create another packet for another machine/source instead.
Finish feasible rig checks within that engine process. A later launch deliberately refuses
new untracked metadata (including Godot-generated `.gd.uid` files); retain the first log and
`git status` output, preserve that checkout, and prepare a fresh dedicated checkout and packet
at the same reviewed SHA. Any required editor import remains a separate recorded operation
under its 240-second bound; do not discard generated files or ignore source changes to pass.

Choose **Play session — shared desktop course, five mechanical players and solver choices**.
In **Player**, choose a row below; select **Keyboard + standard gamepad**, **Four-checkpoint lap**,
**Close follow** and **Current** liquid policy. **Build selected session**; wait for the applied
actor/policy, release movement/action controls, then **Play / resume**. Reopen the in-host
**Play session** panel for each rig. **Player playground** is a separate scene and does not
qualify this shared asynchronous host. The shared selector does not use standalone 1–7/Tab switching.

| Player selection | Primary keyboard controls |
|---|---|
{rows}

Arrows duplicate WASD. Gamepad: first connected pad; left stick = WASD, A = Space,
B = Shift, X = C, shoulders = Q/E. **P**, **Escape**, or the selected pad's **Start**
pause/resume. **R** restarts the applied session,
**F** (the letter) toggles follow/overview. Open **Play session** and click **Return to
launcher**; **F2** remains an optional shortcut. The same panel provides visible **Play /
resume** and **Restart applied session** buttons. Exercise each pause route separately;
a UI modal must consume these controls instead of changing gameplay state. Checkpoint rings
show the next target, future gates and completed gates. With details expanded using F3,
read requested worker capacity separately from observed task participants and sample age.
Neither figure is displayed FPS or utilization; F3 is optional when unavailable.

## Execute and record

Follow the procedure/expected column of RESULTS.csv for every rig and shared case. Use only
`untested`, `pass` or `fail`. Enter UTC time, operator, actual observations and relative evidence
filenames for executed rows; do not turn unavailable hardware, an incomplete lap, a timeout or
a skipped case into a pass. Record GPU/driver, display resolution/refresh and physical keyboard/
controller model, connection type and mapping in observations. Keep the natural mechanical
differences: no physics tuning or injected poses/actions are part of this packet.

Record startup and worst stalls. Record launch-to-launcher and launcher-to-Main visibility
separately from **Build selected session** to visible applied actor/terrain readiness.
The automated construction acknowledgement starts at Build and ends at the first completed
Main callback with the selected actor/native identity and terrain ready; human display
timing is a separate observation and cannot replace that source-bound callback receipt.
The existing 30-second Main acknowledgement, 180-second
graphical case, 240-second import and applicable 15-second operation/150-second fixture limits
remain unchanged. A late Windows shader-bound startup stays failed; any later manual observations
must be labelled separately. Do not repeat imports/warmups to relabel that original attempt.
No import is launched by this packet. If an import is separately required, retain its original
command, exit/log and 240-second outcome before proceeding.

Focus loss cancels input but need not stop momentum/material physics; P is the pause check.
An open selector must consume gameplay controls. Reset/build/connection changes require neutral
rearm. Retain requested family/variant and applied text in a screenshot; copy the applied
native policy_hash and construction receipt_hash from the tooltip. Unsupported families
are disabled with an explanation; inspect that refusal without injecting requests.
Never substitute target publication rate or native ticks for
displayed FPS. Human feel and actual display observations are distinct from automated counters.

## Failures and evidence custody

Retain the first failing console log, timestamp, case ID, exact reproduction steps and screenshot/
video if available. Record STOPPED/fault text verbatim and whether explicit recovery succeeds or
refuses; do not provoke a native fault here. Keep all earlier failures when making a new attempt.
Share a reviewed copy of IDENTITY.json, PRECHECK.json, RESULTS.csv and relevant logs/screenshots;
the identity file contains local paths/host details. Do not commit machine-specific results.
The immutable-file manifest excludes the intentionally editable RESULTS.csv.

The source-pinned [full guide](https://github.com/techrote/cybersand/blob/{sha}/{GUIDE}) explains
the acceptance boundary. A completed sheet does not itself close #270 or promote #263; review
the actual physical/display/human evidence and outstanding automated contracts together.
"""


def write_packet(output: Path, identity: dict, preflight: dict) -> None:
    require(not output.exists(), "Packet output already exists; retain it and select a new directory")
    root = Path(identity["checkout"])
    require(not output.is_relative_to(root), "Keep local machine/results packets outside the source checkout")
    output.mkdir(parents=True)
    for name, data in (("IDENTITY.json", identity), ("PRECHECK.json", preflight)):
        (output / name).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (output / "CHECKLIST.md").write_text(packet_text(identity), encoding="utf-8")
    with (output / "RESULTS.csv").open("w", encoding="utf-8", newline="") as stream:
        rows = cases()
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    verify = [sys.executable, str(root / SCRIPT), "--verify-packet", str(output)]
    source = identity["source"]["commit"]
    executable = identity["engine"]["selected_executable"]
    if identity["platform"] == "windows":
        command = "& " + " ".join(ps_quote(x) for x in verify)
        script = ("$ErrorActionPreference = 'Stop'\n" + command + "\nif ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }\n"
                  + "$log = Join-Path $PSScriptRoot ('session-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '.log')\n"
                  + "& " + ps_quote(str(root / "tools/launch_desktop.ps1")) + " -Godot " + ps_quote(executable)
                  + " 2>&1 | Tee-Object -FilePath $log\nexit $LASTEXITCODE\n")
        # Windows PowerShell5.1 needs a BOM to preserve non-ASCII local paths.
        (output / "launch.ps1").write_text(script, encoding="utf-8-sig")
    else:
        script = ("#!/usr/bin/env bash\nset -euo pipefail\n" + shlex.join(verify) + "\n"
                  + "export CYBERSAND_SOURCE_REVISION=" + shlex.quote(source) + "\n"
                  + "log=" + shlex.quote(str(output)) + '/session-$(date -u +%Y%m%dT%H%M%S%NZ).log\n'
                  + shlex.join([executable, "--path", str(root / "godot")]) + ' 2>&1 | tee "$log"\n')
        (output / "launch.sh").write_text(script, encoding="utf-8")
    manifest = {path.name: digest(path) for path in sorted(output.iterdir()) if path.name != "RESULTS.csv"}
    (output / "MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def verify_packet(output: Path) -> None:
    manifest = json.loads((output / "MANIFEST.json").read_text(encoding="utf-8"))
    identity = json.loads((output / "IDENTITY.json").read_text(encoding="utf-8"))
    require(identity.get("schema") == SCHEMA, "Unsupported manual packet schema")
    expected_files = {"IDENTITY.json", "PRECHECK.json", "CHECKLIST.md",
                      "launch.ps1" if identity["platform"] == "windows" else "launch.sh"}
    require(set(manifest) == expected_files, "Incomplete immutable packet manifest")
    for name, expected in manifest.items():
        path = output / name
        require(path.is_file() and not path.is_symlink() and digest(path) == expected, "Packet file changed: " + name)
    fresh, _preflight = collect(Path(identity["checkout"]), identity["source"]["commit"],
                                Path(identity["engine"]["archive"]), Path(identity["engine"]["selected_executable"]))
    require(all(fresh[key] == identity[key] for key in ("source", "checkout", "platform", "engine", "runtimes", "host")),
            "Source, engine, runtime or recorded host identity changed since packet creation")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expected-sha")
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--godot-archive", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--verify-packet", type=Path)
    args = parser.parse_args()
    try:
        if args.verify_packet:
            require(not any((args.expected_sha, args.godot, args.godot_archive, args.output)), "Verification does not accept replacement identities")
            verify_packet(args.verify_packet.resolve())
            print("Manual packet identity reverified. No engine or physical test was executed.")
        else:
            require(all((args.expected_sha, args.godot, args.godot_archive, args.output)),
                    "Creation requires --expected-sha, --godot, --godot-archive and --output")
            identity, preflight = collect(ROOT, args.expected_sha, args.godot_archive.resolve(), args.godot.resolve())
            write_packet(args.output.resolve(), identity, preflight)
            print(f"Created {args.output.resolve()}; {len(cases())} manual cases remain untested. No engine was executed.")
        return 0
    except (OSError, ValueError, KeyError, subprocess.SubprocessError, zipfile.BadZipFile) as error:
        print("Manual packet refused: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
