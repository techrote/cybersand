"""Early actual-Windows causal gate for the #361 current-main successor.

Runs only test_liquid_desktop_default_host with natural process completion. A
successful assertion footer never overrides a non-zero process exit.
"""
from __future__ import annotations

import argparse
import json
import os
import platform
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/ci"))

import run_godot_regressions as runner
import run_windows_godot_regressions as windows

FIXTURE = "test_liquid_desktop_default_host"
HISTORICAL_EXIT = 0xC0000005
HISTORICAL_PR = 379
HISTORICAL_RUN = 41920193030
HISTORICAL_HEAD = "e7e404b696fb9fc48cdadc95a69baf3a6f5fc6d1"
ADOPTED_MAIN = "24a8bbe8ccf0d17196ebbab580b924930a964584"


def git(*args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(ROOT), *args], stderr=subprocess.STDOUT, text=True
    ).strip()


def write(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def assertion_footer(log: str) -> dict[str, int] | None:
    matches = list(re.finditer(r"(\d+)\s+assertions?\s*;\s*(\d+)\s+failures?", log, re.I))
    if not matches:
        return None
    m = matches[-1]
    return {"assertions": int(m.group(1)), "failures": int(m.group(2))}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot-archive", required=True, type=Path)
    parser.add_argument("--expected-source-sha", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    report: dict[str, object] = {
        "schema": "in-tools-361-windows-causal-gate-v1",
        "status": "failed",
        "completed": False,
        "fixture": FIXTURE,
        "actual_windows": sys.platform == "win32",
        "platform": platform.platform(),
        "historical": {
            "pr": HISTORICAL_PR,
            "run_id": HISTORICAL_RUN,
            "head": HISTORICAL_HEAD,
            "fixture_assertions": 86,
            "fixture_failures": 0,
            "process_exit": HISTORICAL_EXIT,
            "process_exit_hex": "0xC0000005",
        },
        "adopted_main": ADOPTED_MAIN,
        "errors": [],
    }

    try:
        if sys.platform != "win32":
            raise RuntimeError("actual Windows is required")
        source = git("rev-parse", "HEAD")
        tree = git("rev-parse", "HEAD^{tree}")
        report["source_commit"] = source
        report["source_tree"] = tree
        if source != args.expected_source_sha:
            raise RuntimeError("checkout differs from requested successor head")
        if not subprocess.run(
            ["git", "-C", str(ROOT), "merge-base", "--is-ancestor", ADOPTED_MAIN, source],
            check=False,
        ).returncode == 0:
            raise RuntimeError("successor head is not descended from adopted main")

        report["runtime_identity"] = windows.verify_retained_runtime(ROOT)
        godot, identity = windows.prepare_godot(args.godot_archive.resolve())
        report["godot_identity"] = identity
        report["godot_version"] = identity["version"]

        cases = {case.name: case for case in runner.discover_cases()}
        if FIXTURE not in cases:
            raise RuntimeError(f"{FIXTURE} is not a discovered current regression")
        case = cases[FIXTURE]

        env = dict(os.environ)
        env["CYBERSAND_SOURCE_REVISION"] = source
        record, failed = runner.run_case(str(godot), case, output, "causal_gate", env=env)
        report["process"] = record

        log_path = output / record["log"]
        log = log_path.read_text(encoding="utf-8", errors="replace")
        report["assertion_footer"] = assertion_footer(log)

        code = record.get("returncode")
        unsigned = (int(code) & 0xFFFFFFFF) if isinstance(code, int) else None
        report["process_exit_unsigned"] = unsigned
        report["process_exit_hex"] = f"0x{unsigned:08X}" if unsigned is not None else None
        report["historical_signature_match"] = unsigned == HISTORICAL_EXIT
        report["fixture_completed_naturally"] = bool(record.get("natural_completion"))
        report["timeout"] = record.get("status") == "timeout"
        report["wrapper_exit"] = 1 if failed else 0

        if unsigned == HISTORICAL_EXIT:
            report["causal_disposition"] = "historical_crash_reproduced"
        elif failed:
            report["causal_disposition"] = "different_failure_observed"
        else:
            report["causal_disposition"] = "historical_crash_not_reproduced_causality_unresolved"

        report["completed"] = True
        report["status"] = "passed" if not failed else "failed"
    except (OSError, RuntimeError, ValueError, KeyError, subprocess.SubprocessError) as exc:
        report["errors"].append(f"{type(exc).__name__}: {exc}")
    finally:
        report["seconds"] = round(time.monotonic() - started, 3)
        write(output / "windows-causal-gate.json", report)
        print(json.dumps(report, indent=2, sort_keys=True), flush=True)

    return int(report["status"] != "passed")


if __name__ == "__main__":
    raise SystemExit(main())
