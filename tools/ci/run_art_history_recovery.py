#!/usr/bin/env python3
"""Qualify Art durability and preserve the original Art regression processes.

Adversarial restart phases run in separate Godot processes sharing one isolated
profile. Original provider, lazy-loading, archive-integrity and mounted-panel
tests retain their own profiles, as does the actor-equipment exit regression.
Printed passing assertions never override an actual process crash.
"""
from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

from run_flatten_qualification import direct_engine
from run_windows_godot_regressions import RAPIER_IMPORT_DESCRIPTORS

ROOT = Path(__file__).resolve().parents[2]
GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource:")
CASES = (
    ("test_art_provider", "ART_PROVIDER_KEYLESS", "text"),
    ("test_art_lazy_traffic", "ART_LAZY_TRAFFIC", "json"),
    ("test_art_traffic_integrity", "ART_TRAFFIC_INTEGRITY", "json"),
    ("test_art_traffic_panel_safety", "ART_TRAFFIC_PANEL", "json"),
    ("test_art_history_receipt_identity", "ART_HISTORY_RECEIPT_IDENTITY_RESULT", "json"),
    ("test_workbench_actor_equipment_extent", "Workbench actor equipment extent:", "text"),
)
DURABILITY_PHASES = (
    "suite", "restart-seed", "restart-recover", "crash-seed", "crash-recover",
    "secret-turn-seed", "secret-turn-recover", "secret-raw-seed", "secret-raw-recover",
)
HARD_KILL_PHASES = frozenset(("crash-seed", "secret-turn-seed"))


def durability_phases(platform: str) -> tuple[str, ...]:
    """POSIX mode-bit failures supplement, rather than replace, shared cases."""
    return DURABILITY_PHASES + (("posix-listing", "listing-clock-seed", "listing-clock-recover") if platform == "linux" else ())


def profile_for_phase(phase: str) -> str:
    group = phase if phase in ("suite", "posix-listing") else phase.rsplit("-", 1)[0]
    return "art-durability-" + group


def digest(path: Path, *, canonical: bool = False) -> str:
    data = path.read_bytes()
    return hashlib.sha256(data.replace(b"\r\n", b"\n") if canonical else data).hexdigest()


def git(*arguments: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), *arguments], text=True, timeout=60).rstrip("\r\n")


def import_descriptors(root: Path) -> dict[str, bytes]:
    result = {}
    for path in sorted(RAPIER_IMPORT_DESCRIPTORS):
        source = root / path
        if source.is_symlink():
            raise ValueError("An import descriptor is unexpectedly a symbolic link: " + path)
        result[path] = source.read_bytes()
    return result


def other_tracked_diff(root: Path) -> bytes:
    """Keep every other tracked path strict, including pre-existing local edits."""
    return subprocess.check_output(
        ["git", "-C", str(root), "diff", "--binary", "HEAD", "--", ".",
         *(":(exclude)" + path for path in sorted(RAPIER_IMPORT_DESCRIPTORS))], timeout=60)


def qualify_import_transition(before: dict, after: dict, original: dict[str, bytes],
                              imported: dict[str, bytes], original_diff: bytes,
                              imported_diff: bytes, evidence: Path) -> dict:
    """Permit only the established four-descriptor CRLF/LF import rewrite.

    Full bytes and diffs remain evidence. The post-import identity becomes the
    strict test baseline; even these descriptors may not change during tests.
    """
    folder = evidence / "editor-import"
    folder.mkdir(exist_ok=True)
    report = {"passed": False, "scope": "Exact four Rapier descriptors; line endings only",
              "working_status_before": before["working_status"],
              "working_status_after": after["working_status"], "descriptors": {},
              "other_tracked_diff_sha256_before": hashlib.sha256(original_diff).hexdigest(),
              "other_tracked_diff_sha256_after": hashlib.sha256(imported_diff).hexdigest()}
    (folder / "other-tracked-before.diff").write_bytes(original_diff)
    (folder / "other-tracked-after.diff").write_bytes(imported_diff)
    try:
        if set(original) != RAPIER_IMPORT_DESCRIPTORS or set(imported) != RAPIER_IMPORT_DESCRIPTORS:
            raise ValueError("Editor import did not retain the exact declared descriptor inventory")
        for path in sorted(RAPIER_IMPORT_DESCRIPTORS):
            old, new = original[path], imported[path]
            for phase, data in (("before", old), ("after", new)):
                target = folder / phase / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
            diff = b"".join(difflib.diff_bytes(difflib.unified_diff, old.splitlines(keepends=True),
                                             new.splitlines(keepends=True),
                                             fromfile=("before/" + path).encode(),
                                             tofile=("after/" + path).encode()))
            target = folder / (Path(path).name + ".diff")
            target.write_bytes(diff)
            report["descriptors"][path] = {
                "before_sha256": hashlib.sha256(old).hexdigest(),
                "after_sha256": hashlib.sha256(new).hexdigest(),
                "canonical_sha256_before": hashlib.sha256(old.replace(b"\r\n", b"\n")).hexdigest(),
                "canonical_sha256_after": hashlib.sha256(new.replace(b"\r\n", b"\n")).hexdigest(),
                "diff_sha256": hashlib.sha256(diff).hexdigest(),
                "before_size": len(old), "after_size": len(new), "changed": old != new,
            }
        if any(original[path].replace(b"\r\n", b"\n") != imported[path].replace(b"\r\n", b"\n")
               for path in RAPIER_IMPORT_DESCRIPTORS):
            raise ValueError("Editor import changed descriptor content beyond permitted line endings")
        if original_diff != imported_diff:
            raise ValueError("Editor import changed another tracked input")
        excluded = {"working_status", "rapier_import_metadata_sha256"}
        if ({key: value for key, value in before.items() if key not in excluded}
                != {key: value for key, value in after.items() if key not in excluded}):
            raise ValueError("Editor import changed source, image, runtime or executable identity")
        for snapshot, values in ((before, original), (after, imported)):
            expected = {path: hashlib.sha256(data).hexdigest() for path, data in values.items()}
            if snapshot.get("rapier_import_metadata_sha256") != expected:
                raise ValueError("Descriptor evidence differs from its captured input identity")
        report["passed"] = True
        return report
    except Exception as error:
        report["error"] = str(error)
        raise
    finally:
        (folder / "transition.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


def identity(project: Path, engine: Path) -> dict:
    platform = "windows" if sys.platform == "win32" else "linux"
    name = "runtime-provenance.json" if platform == "windows" else "runtime-provenance.linux.json"
    manifest_path = project / "addons/cybersand_native" / name
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    runtime = ROOT / manifest["artifact"]
    if (manifest.get("platform") != platform or manifest.get("status") != "validated-development-runtime"
            or runtime.parent != project / "addons/cybersand_native/bin"
            or runtime.stat().st_size != manifest["size"] or digest(runtime) != manifest["sha256"]):
        raise ValueError("The committed native runtime does not match its platform provenance")
    subprocess.run(["git", "-C", str(ROOT), "merge-base", "--is-ancestor", manifest["source_commit"], "HEAD"], check=True)
    subprocess.run(["git", "-C", str(ROOT), "diff", "--exit-code", manifest["source_commit"], "HEAD", "--",
                    "native/include", "native/src", "godot/native_extension"], check=True)
    native = {path: digest(ROOT / path, canonical=True) for path in manifest["source_inputs"]}
    if native != manifest["source_inputs"]:
        raise ValueError("Actual compiled native input bytes differ from the published runtime")
    scripts = {path.relative_to(project).as_posix(): digest(path, canonical=True)
               for path in sorted(project.rglob("*.gd")) if ".godot" not in path.parts}
    return {"source_commit": git("rev-parse", "HEAD"), "source_tree": git("rev-parse", "HEAD^{tree}"),
            "working_status": git("status", "--porcelain", "--untracked-files=no"),
            "platform": platform, "godot_version": GODOT_VERSION,
            "engine_executable": str(engine), "engine_sha256": digest(engine),
            "native_sha256": manifest["sha256"], "native_size": manifest["size"],
            "native_build_commit": manifest["source_commit"],
            "native_provenance_sha256": digest(manifest_path),
            "native_source_inputs": native, "project_script_sha256": scripts,
            "rapier_import_metadata_sha256": {path: digest(ROOT / path) for path in sorted(RAPIER_IMPORT_DESCRIPTORS)},
            "rapier_import_source_sha256": {path.removesuffix(".import"): digest(ROOT / path.removesuffix(".import"))
                                             for path in sorted(RAPIER_IMPORT_DESCRIPTORS)},
            "runner_sha256": digest(Path(__file__))}


def completion(text: str, marker: str, kind: str) -> dict:
    lines = [line for line in text.splitlines() if line.startswith(marker + " ")]
    if len(lines) != 1:
        raise ValueError(f"Expected exactly one completion marker {marker!r}; found {len(lines)}")
    if kind == "json":
        result = json.loads(lines[0][len(marker) + 1:])
        if not isinstance(result, dict):
            raise ValueError("Completion is not an object")
    else:
        match = re.fullmatch(re.escape(marker) + r" (\d+) checks, (\d+) failures", lines[0])
        if match is None:
            raise ValueError("Malformed assertion completion: " + lines[0])
        result = {"checks": int(match[1]), "failures": int(match[2])}
    if type(result.get("checks")) is not int or result["checks"] <= 0:
        raise ValueError("The original test reported no positive assertions")
    failures = result.get("failures")
    if not ((type(failures) is int and failures == 0) or (type(failures) is list and not failures)):
        raise ValueError("The original test reported failed assertions")
    return result


def profile_files(profile: Path) -> dict:
    """Hash only this runner's isolated fixtures, never a real owner profile."""
    result = {}
    for path in sorted(profile.rglob("*")):
        if path.is_symlink():
            raise ValueError("An isolated fixture unexpectedly contains a symbolic link")
        if path.is_file():
            result[path.relative_to(profile).as_posix()] = {"size": path.stat().st_size, "sha256": digest(path)}
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=ROOT / "godot")
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--allow-dirty", action="store_true", help="Record a development-only working delta; CI must not use this")
    args = parser.parse_args()
    evidence, project = args.evidence.resolve(), args.project.resolve()
    evidence.mkdir(parents=True, exist_ok=True)
    if (evidence / "qualification.json").exists():
        parser.error("Choose a fresh evidence directory; original qualification logs must not be overwritten")
    phases = durability_phases(sys.platform)
    expected = [row[0] for row in CASES] + ["art-durability-" + phase for phase in phases]
    report = {"schema": "gentek691-art-durability-qualification-v1", "passed": False, "status": "running",
              "cases": [], "errors": [], "expected_cases": expected}

    def save() -> None:
        (evidence / "qualification.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    def run_case(name: str, command: list[str], marker: str = "", kind: str = "json", *,
                 profile_name: str = "", extra_env: dict | None = None, kill_at_boundary: bool = False) -> None:
        row = {"name": name, "command": command, "status": "running", "returncode": None}
        report["cases"].append(row)
        save()
        started = time.monotonic()
        log = evidence / (name + ".log")
        profile = evidence / ((profile_name or name) + "-userdata")
        profile.mkdir(exist_ok=True)
        env = dict(os.environ, XDG_DATA_HOME=str(profile), APPDATA=str(profile), GODOT_SILENCE_ROOT_WARNING="1",
                   **(extra_env or {}))
        row["profile_before"] = profile_files(profile)
        process = None
        try:
            if (extra_env or {}).get("ART_HISTORY_DURABILITY_CASE") == "posix-listing" and os.geteuid() == 0:
                raise RuntimeError("The supplementary POSIX permission test requires an unprivileged process")
            with log.open("wb") as stream:
                process = subprocess.Popen(command, cwd=evidence, env=env, stdout=stream,
                                           stderr=subprocess.STDOUT)
                row["pid"] = process.pid
                if kill_at_boundary:
                    boundary = None
                    while process.poll() is None and time.monotonic() - started < 600:
                        paths = list(profile.rglob("art-durability-crash-boundary.json"))
                        if len(paths) > 1:
                            raise ValueError("Ambiguous persisted crash boundary")
                        if paths:
                            try:
                                boundary = json.loads(paths[0].read_text(encoding="utf-8"))
                            except (OSError, ValueError):
                                time.sleep(0.02)
                                continue
                            row["completion"] = completion(
                                "ART_HISTORY_DURABILITY_CRASH_BOUNDARY " + json.dumps(boundary),
                                "ART_HISTORY_DURABILITY_CRASH_BOUNDARY", "json")
                            if boundary.get("case") != (extra_env or {}).get("ART_HISTORY_DURABILITY_CASE"):
                                raise ValueError("Persisted crash boundary has the wrong phase")
                            receipt_id = boundary.get("receipt_id", "")
                            if not isinstance(receipt_id, str) or re.fullmatch(r"[A-Za-z0-9_-]{1,200}", receipt_id) is None:
                                raise ValueError("Persisted crash boundary has no safe receipt identity")
                            candidates = [path for path in profile.rglob("*.json")
                                          if path.parent.name == "art-pending-history"]
                            if len(candidates) > 4096:
                                raise ValueError("Crash journal exceeds the bounded receipt capacity")
                            pending = []
                            for path in candidates:
                                if path.is_symlink() or path.stat().st_size > 262144:
                                    raise ValueError("Crash journal has an aliased or oversized receipt")
                                item = json.loads(path.read_text(encoding="utf-8"))
                                if item.get("id") != receipt_id:
                                    continue
                                expected_name = receipt_id + ".json"
                                if item.get("schema") == 2:
                                    order = item.get("order", "")
                                    if not isinstance(order, str) or re.fullmatch(r"[0-9]{20}", order) is None:
                                        raise ValueError("Crash receipt has no valid publication order")
                                    expected_name = order + "_" + expected_name
                                elif item.get("schema") != 1:
                                    raise ValueError("Crash receipt has an unsupported schema")
                                if path.name != expected_name:
                                    raise ValueError("Crash receipt filename differs from its identity/order")
                                pending.append(path)
                            if len(pending) != 1:
                                raise ValueError("Committed conversation boundary has no matching durable pending receipt")
                            row.update(boundary_sha256=digest(paths[0]), pending_at_kill_sha256=digest(pending[0]),
                                       kill_requested=True, interruption="TerminateProcess" if sys.platform == "win32" else "SIGKILL")
                            process.kill()
                            break
                        time.sleep(0.02)
                    if not row.get("kill_requested"):
                        raise RuntimeError("Godot never reached the persisted conversation-commit crash boundary")
                process.wait(timeout=10 if kill_at_boundary else 600)
            row["returncode"] = process.returncode
            text = log.read_text(encoding="utf-8", errors="replace")
            if kill_at_boundary:
                if process.returncode == 0 or (sys.platform != "win32" and process.returncode != -signal.SIGKILL):
                    raise RuntimeError("The crash fixture did not exit through the requested hard termination")
                if "ART_HISTORY_DURABILITY_RESULT " in text:
                    raise RuntimeError("The crash fixture completed normally before interruption")
            elif process.returncode != 0:
                raise RuntimeError(f"Real Godot process exited with {process.returncode}")
            if ERRORS.search(text):
                raise RuntimeError("The Godot log contains a script or resource error")
            if marker and not kill_at_boundary:
                row["completion"] = completion(text, marker, kind)
            if name.startswith("art-durability-") and row["completion"].get("case") != extra_env["ART_HISTORY_DURABILITY_CASE"]:
                raise ValueError("Durability completion does not identify the executed phase")
            row["status"] = "passed"
            print(f"PASS {name}: {row.get('completion', {}).get('checks', 'import')} checks; exit={process.returncode}", flush=True)
        except Exception as error:
            row.update(status="failed", error=f"{type(error).__name__}: {error}")
            report["errors"].append(name + ": " + row["error"])
            print("FAIL " + name + ": " + row["error"], flush=True)
        finally:
            if process is not None:
                if process.poll() is None:
                    process.kill()
                    process.wait(timeout=10)
                row["returncode"] = process.returncode
            row.update(elapsed_seconds=time.monotonic() - started,
                       log_sha256=digest(log) if log.exists() else None,
                       profile_after=profile_files(profile))
            save()

    try:
        engine = direct_engine(args.godot, sys.platform)
        version = subprocess.run([str(engine), "--version"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                 cwd=evidence, text=True, encoding="utf-8", timeout=60)
        (evidence / "godot-version.log").write_text(version.stdout, encoding="utf-8")
        if version.returncode != 0 or version.stdout.strip() != GODOT_VERSION:
            raise ValueError("The focused suite requires the exact pinned Godot 4.7 engine")
        report["checkout_identity"] = identity(project, engine)
        if report["checkout_identity"]["working_status"] and not args.allow_dirty:
            raise ValueError("Source has tracked working changes; commit first or record a development-only --allow-dirty run")
        report["development_only"] = bool(args.allow_dirty)
        save()
        base = [str(engine), "--audio-driver", "Dummy", "--headless", "--path", str(project)]
        original_imports = import_descriptors(ROOT)
        original_diff = other_tracked_diff(ROOT)
        run_case("import", [*base, "--editor", "--quit"])
        if report["errors"]:
            raise RuntimeError("Import failed; the original tests cannot be qualified")
        report["identity_before"] = identity(project, engine)
        report["editor_import"] = qualify_import_transition(
            report["checkout_identity"], report["identity_before"], original_imports,
            import_descriptors(ROOT), original_diff, other_tracked_diff(ROOT), evidence)
        save()
        for name, marker, kind in CASES:
            run_case(name, [*base, "--script", "res://tests/" + name + ".gd"], marker, kind)
        for phase in phases:
            run_case("art-durability-" + phase,
                     [*base, "--script", "res://tests/test_art_history_durability.gd"],
                     "ART_HISTORY_DURABILITY_RESULT", profile_name=profile_for_phase(phase),
                     extra_env={"ART_HISTORY_DURABILITY_CASE": phase}, kill_at_boundary=phase in HARD_KILL_PHASES)
        report["identity_after"] = identity(project, engine)
        if report["identity_before"] != report["identity_after"]:
            raise RuntimeError("Source, runtime, Godot or test input identity changed during the focused suite")
        report["passed"] = not report["errors"] and [row["name"] for row in report["cases"]] == ["import", *expected]
        report["positive_assertions"] = sum(row.get("completion", {}).get("checks", 0) for row in report["cases"])
        report["status"] = "passed" if report["passed"] else "failed"
    except Exception as error:
        report["errors"].append(f"{type(error).__name__}: {error}")
        report["status"] = "failed"
    finally:
        save()
    print(json.dumps({key: report[key] for key in ("passed", "status", "errors")}), flush=True)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
