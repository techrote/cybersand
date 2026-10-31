#!/usr/bin/env python3
"""Bounded real Windows/Linux headless PLAY-LIFE-009 execution and original-log readback."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import time
import zipfile

from life009_contract import RIGS, extract, number, require, verify_inventory, verify_process, verify_result

from execution_policy import case_seconds, identity, watchdog_seconds
from play_execution_contract import policy_matches, process_policy_matches, verify_log_policy, verify_source_policy

ROOT = Path(__file__).resolve().parents[2]
BASE = "0bf28d5760aed989a79386de03ef4fc6171fef42"
VERSION = "4.7.stable.official.5b4e0cb0f"
WORKFLOW = ".github/workflows/play-life009.yml"
ORIGINAL_PARSER_SHA256 = "eb5cd7163f2672bcd8d9a41c063d9e102d71185713b3ab3f31185e5123f29191"
PROTECTED = ("native", "godot/scripts", "godot/shaders", "godot/addons", "godot/main.tscn",
             "godot/project.godot", "third_party", ".github/workflows/native.yml",
             ".github/workflows/gdextension.yml")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n", encoding="utf-8")


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(ROOT), *args], timeout=watchdog_seconds("operation_seconds"))


def safe_child(root: Path, name: str) -> Path:
    require(isinstance(name, str) and name and not name.startswith(("/", "\\"))
            and "\\" not in name and ":" not in name and ".." not in Path(name).parts,
            "Unsafe evidence path")
    p = root / name
    require(p.is_file() and not p.is_symlink() and p.resolve().is_relative_to(root.resolve()),
            "Missing/unsafe original evidence file: " + name)
    return p


def verify_parser_controls(output: Path, records: dict) -> None:
    """Authenticate the registered parser failure, not merely an exit or log hash."""
    require(records.get("original_source_sha256") == ORIGINAL_PARSER_SHA256
            and sha(safe_child(output, "original-584b-helper.gd")) == ORIGINAL_PARSER_SHA256,
            "Frozen parser source changed")
    logs = {}
    for label in ("original", "current"):
        item = records[label]
        process = item["process"]
        require(process.get("name") == "parser-" + label
                and process.get("log") == "parser-" + label + ".log", "Wrong parser process identity")
        receipt = json.loads(safe_child(output, "parser-" + label + ".process.json").read_text(encoding="utf-8"))
        require(receipt == process, "Parser process receipt changed")
        log = safe_child(output, process["log"])
        require(sha(log) == item["log_sha256"], "Parser original log changed")
        logs[label] = log.read_text(encoding="utf-8")
        require(not process.get("timeout_kind") and not process.get("timeout_diagnostic_error")
                and not process.get("launch_error") and not process.get("capture_error")
                and not process.get("skip_messages"), "Parser control was interrupted or skipped")
    old = records["original"]["process"]
    require(old.get("status") == "failed" and type(old.get("returncode")) is int
            and old["returncode"] == 1 and old.get("diagnostic_error") is True
            and old.get("timeout_seconds") == watchdog_seconds("operation_seconds")
            and number(old.get("seconds"), "parser.seconds") <= watchdog_seconds("operation_seconds")
            and process_policy_matches(old),
            "Original parser negative control did not fail as expected")
    expected = (r'SCRIPT ERROR: Parse Error: Expected closing "\)" after call arguments\.\n'
                r'\s+at: GDScript::reload \([^\r\n]*original-584b-helper\.gd:205\)')
    require(len(re.findall(r"SCRIPT ERROR:", logs["original"])) == 1
            and re.search(expected, logs["original"]) is not None,
            "Original parser failed for a different reason")
    verify_process(records["current"]["process"], watchdog_seconds("operation_seconds"))
    require(not re.search(r"SCRIPT ERROR:|ERROR:|\bskipped\b|^\s*SKIP\b", logs["current"], re.M | re.I),
            "Current parser log contains a failure or skip")


def parser_checks(binary: str, output: Path, runner, environment: dict) -> dict:
    """The frozen malformed predecessor must fail; current helper must parse."""
    original = git("show", "584b9c35085e45a0ab911730965b3cc30474dfd0:godot/tests/play_life009_same_owner_case.gd")
    old_path = output / "original-584b-helper.gd"
    old_path.write_bytes(original)
    records = {}
    for label, script in (("original", str(old_path)),
                          ("current", "res://tests/play_life009_same_owner_case.gd")):
        record, _ = runner.run_case(binary, runner.Case("parser-" + label,
            ("--check-only", "--script", script), watchdog_seconds("operation_seconds"), 0), output,
            "parser control only; does not execute gameplay", env=environment)
        write(output / ("parser-" + label + ".process.json"), record)
        records[label] = {"process": record, "log_sha256": sha(output / record["log"])}
    records["original_source_sha256"] = hashlib.sha256(original).hexdigest()
    write(output / "parser-controls.json", records)
    verify_parser_controls(output, records)
    return records


def verify_directory(output: Path) -> dict:
    report = json.loads((output / "campaign.json").read_text(encoding="utf-8"))
    require(report.get("schema") == "play-life009-campaign-v2", "Wrong campaign schema")
    require(policy_matches(report.get("execution_policy")), "Campaign execution policy changed")
    verify_source_policy(report["source_commit"])
    verify_inventory([r.get("rig") for r in report.get("rows", [])])
    require(report.get("completed") is True and report.get("errors") == [], "Incomplete/failed campaign")
    require(report.get("source_unchanged") is True and report.get("runtimes_unchanged") is True,
            "Source/runtime postflight failed")
    require(report.get("production_paths_unchanged_from_base") is True, "Production scope changed")
    require(report.get("godot_identity", {}).get("version") == VERSION, "Wrong Godot version")
    parser_controls = json.loads(safe_child(output, "parser-controls.json").read_text())
    require(parser_controls == report.get("parser_controls"), "Parser controls changed")
    verify_parser_controls(output, parser_controls)
    verify_process(report["import"], watchdog_seconds("godot_import_seconds"))
    require(sha(safe_child(output, report["import"]["log"])) == report["import_log_sha256"],
            "Import log changed")
    results = []
    for row in report["rows"]:
        process = row["process"]
        verify_process(process, case_seconds("test_play_life009_" + row["rig"]))
        require(number(row["observed_total_seconds"], "observed_total_seconds") <= case_seconds("test_play_life009_" + row["rig"]), "Late total process observation")
        require(process["name"] == "test_play_life009_" + row["rig"], "Wrong process/rig")
        log = safe_child(output, process["log"])
        require(sha(log) == row["log_sha256"], "Original case log changed")
        raw = json.loads(safe_child(output, row["process_record"]).read_text(encoding="utf-8"))
        require(raw == process, "Process receipt differs from original")
        text = log.read_text(encoding="utf-8")
        verify_log_policy(text, report["source_commit"])
        result = extract(text)
        require(result == row["result"], "Reported result differs from engine log")
        summary = verify_result(result, row["rig"], report["source_commit"])
        require(summary == row["summary"], "Reduction differs from observations")
        results.append(summary)
    return {"status": "passed", "execution_policy": identity(), "source_commit": report["source_commit"],
            "source_tree": report["source_tree"], "platform": report["platform"],
            "rows": results, "qualification": "headless LIFE009 only; no graphical/physical/manual acceptance"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot-archive", type=Path)
    parser.add_argument("--expected-source-sha")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    if args.verify_only:
        print(json.dumps(verify_directory(output), sort_keys=True))
        return 0
    require(args.godot_archive is not None and args.expected_source_sha is not None,
            "Execution needs authenticated archive and source SHA")
    output.mkdir(parents=True, exist_ok=False)
    sys.path.insert(0, str(ROOT / "tools/ci"))
    import run_godot_regressions as runner
    import run_windows_godot_regressions as windows
    report = {"schema": "play-life009-campaign-v2", "status": "failed", "completed": False,
              "platform": sys.platform, "host": platform.platform(), "python": sys.version,
              "execution_policy": identity(),
              "run_id": os.getenv("GITHUB_RUN_ID"), "run_attempt": os.getenv("GITHUB_RUN_ATTEMPT"),
              "rows": [], "errors": [], "base_commit": BASE,
              "scope": "actual headless Main/native/Rapier; focus seam; no shader/graphical/human acceptance"}
    paths: list[str] = []
    before: dict = {}
    runtimes: dict = {}

    def inputs() -> dict:
        return {p: windows.content_digest(ROOT, p) for p in paths}

    def runtime_ids() -> dict:
        result = {}
        for path in runner.runtime_paths():
            relative = path.relative_to(ROOT).as_posix()
            pointer = git("show", "HEAD:" + relative)
            match = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", pointer)
            require(match is not None, "Noncanonical runtime LFS pointer")
            data = path.read_bytes()
            require(len(data) == int(match[2]) and hashlib.sha256(data).hexdigest() == match[1].decode(),
                    "Runtime LFS identity mismatch: " + relative)
            require(data.startswith(b"MZ" if sys.platform == "win32" else b"\x7fELF"), "Runtime not materialized")
            result[relative] = {"sha256": sha(path), "bytes": len(data), "pointer": pointer.decode()}
        return result

    try:
        source = git("rev-parse", "HEAD").decode().strip()
        require(source == args.expected_source_sha, "Unexpected executed source")
        report.update(source_commit=source, source_tree=git("rev-parse", "HEAD^{tree}").decode().strip())
        require(not git("diff", "--name-only", BASE, "HEAD", "--", *PROTECTED).strip(),
                "Out-of-scope production/native/runtime change")
        report["production_paths_unchanged_from_base"] = True
        scopes = ("godot", "native", "third_party", "tools/ci", "tools/play", WORKFLOW)
        paths = [p for p in git("ls-files", "-z", "--", *scopes).decode().split("\0")
                 if p and not p.startswith("godot/.godot/")]
        require(bool(paths), "Empty execution input inventory")
        git("diff", "--exit-code", "HEAD", "--", *scopes, ":!godot/.godot")
        before, runtimes = inputs(), runtime_ids()
        report["execution_inputs"], report["runtimes"] = before, runtimes
        if sys.platform == "win32":
            report["native_runtime_provenance"] = windows.verify_retained_runtime(ROOT)
            binary, report["godot_identity"] = windows.prepare_godot(args.godot_archive.resolve())
        else:
            require(sys.platform.startswith("linux"), "Only actual Windows/Linux admitted")
            lock = json.loads((ROOT / "third_party/godot-runtime.lock.json").read_text())
            archive = args.godot_archive.resolve()
            require(archive.stat().st_size == lock["editor"]["size"]
                    and sha(archive) == lock["editor"]["sha256"], "Linux engine archive mismatch")
            directory = archive.parent / "life009-engine"
            with zipfile.ZipFile(archive) as bundle:
                require(bundle.testzip() is None, "Engine archive CRC failed")
                bundle.extractall(directory)
            binary = directory / "Godot_v4.7-stable_linux.x86_64"
            binary.chmod(0o755)
            version = subprocess.check_output([str(binary), "--version"], text=True, timeout=watchdog_seconds("operation_seconds")).strip()
            report["godot_identity"] = {"version": version, "binary_sha256": sha(binary),
                                        "archive_sha256": sha(archive)}
        require(report["godot_identity"]["version"] == VERSION, "Wrong engine version")
        # Exact tracked source only, with LFS smudge disabled. Keep runtime
        # identities separate; never package credentials or generated caches.
        with (output / "executed-source.tar").open("wb") as handle:
            subprocess.run(["git", "archive", "--format=tar", "HEAD"], cwd=ROOT,
                           stdout=handle, check=True, timeout=watchdog_seconds("operation_seconds"),
                           env=os.environ | {"GIT_LFS_SKIP_SMUDGE": "1"})
        report["executed_source_archive_sha256"] = sha(output / "executed-source.tar")
        environment = os.environ | {"CYBERSAND_SOURCE_REVISION": source, "GODOT_SILENCE_ROOT_WARNING": "1"}
        report["import"], failed = runner.run_case(str(binary), runner.Case("import", ("--editor", "--quit"), watchdog_seconds("godot_import_seconds"), 0),
                                                 output, "ordinary headless import", env=environment)
        report["import_log_sha256"] = sha(output / report["import"]["log"])
        write(output / "campaign.json", report)
        if not failed:
            verify_process(report["import"], watchdog_seconds("godot_import_seconds"))
            report["parser_controls"] = parser_checks(str(binary), output, runner, environment)
            for rig in RIGS:
                name = "test_play_life009_" + rig
                start = time.perf_counter()
                process, failed = runner.run_case(str(binary), runner.Case(name,
                    ("--script", "res://tests/" + name + ".gd"), case_seconds(name), 0), output,
                    "original first-attempt automatic-callback behavior", env=environment)
                observed = time.perf_counter() - start
                # Retain the real process outcome before parsing or postflight can fail.
                record_name = name + ".process.json"
                write(output / record_name, process)
                row = {"rig": rig, "process": process, "process_record": record_name,
                       "observed_total_seconds": observed, "log_sha256": sha(output / process["log"]),
                       "errors": []}
                report["rows"].append(row)
                try:
                    verify_process(process, case_seconds(name))
                    require(observed <= case_seconds(name), "Late observed case completion")
                    row["result"] = extract((output / process["log"]).read_text(encoding="utf-8"))
                    row["summary"] = verify_result(row["result"], rig, source)
                except Exception as error:
                    row["errors"].append(f"{type(error).__name__}: {error}")
                    report["errors"].append(rig + ": " + row["errors"][-1])
                write(output / "campaign.json", report)
            report["completed"] = True
        else:
            report["errors"].append("Original import failed; no fixture execution credited")
    except Exception as error:
        report["errors"].append(f"{type(error).__name__}: {error}")
    finally:
        try:
            report["source_unchanged"] = bool(before) and inputs() == before
            report["runtimes_unchanged"] = bool(runtimes) and runtime_ids() == runtimes
        except Exception as error:
            report["errors"].append("Postflight: " + repr(error))
        write(output / "campaign.json", report)
    try:
        reduction = verify_directory(output)
        report["status"] = "passed"
        write(output / "campaign.json", report)
        write(output / "readback.json", reduction)
    except Exception as error:
        report["errors"].append("Final readback: " + str(error))
        write(output / "campaign.json", report)
    inventory = {p.relative_to(output).as_posix(): {"bytes": p.stat().st_size, "sha256": sha(p)}
                 for p in sorted(output.rglob("*")) if p.is_file()}
    write(output / "manifest.json", {"source_commit": report.get("source_commit"), "files": inventory})
    print("PLAY_LIFE009_CAMPAIGN " + json.dumps({k: report[k] for k in ("status", "completed", "errors")}))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
