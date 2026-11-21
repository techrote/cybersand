#!/usr/bin/env python3
"""Build and execute the seven Gentek showcase suites with retained Linux receipts.

--include-worldgen adds the nine ordinary generation suites, including Cathedral
and the repaired CLASSIC oracle. All binaries are compiled into a fresh, private
BUILD_DIR; every test gets the existing repository watchdog and its own log.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import shlex
import subprocess
import sys

import execution_policy
import run_timed_command

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/architecture"))
from compiler_cache import compiler_identity  # noqa: E402

SHOWCASES = (
    "test_megatruss_station", "test_seeded_typology_megablock",
    "test_metabolist_spine", "test_interlaced_viaduct",
    "test_rosework_gatehouse", "test_interlock_brutalism",
    "test_suspended_arcology",
)
WORLDGEN = (
    "test_world_generation", "test_world_generation_install", "test_generation_fields",
    "test_generation_modifiers", "test_generation_typed", "test_generation_typed_integration",
    "test_generation_spatial", "test_generation_grammar", "test_generation_planes",
)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inputs() -> dict[str, str]:
    suffixes = {".cpp", ".c", ".h", ".hpp", ".inc", ".inl", ".tpp"}
    paths = {ROOT / "Makefile", Path(__file__),
             ROOT / "tools/architecture/compiler_cache.py"}
    for folder in ("native/include", "native/src", "native/tests"):
        paths.update(p for p in (ROOT / folder).rglob("*")
                     if p.is_file() and p.suffix in suffixes)
    return {p.relative_to(ROOT).as_posix(): digest(p) for p in sorted(paths)}


def git(*args: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), *args],
                                   text=True, timeout=60).strip()


def save(path: Path, value: dict) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
    temporary.replace(path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", default="g++-13")
    parser.add_argument("--output", type=Path, required=True,
                        help="New evidence directory; existing directories are refused")
    parser.add_argument("--include-worldgen", action="store_true")
    parser.add_argument("--sanitize", action="store_true")
    parser.add_argument("--jobs", type=int, choices=(1, 2), default=2)
    parser.add_argument("--timeout", type=float,
                        help="Per-command seconds; may only enlarge repository watchdogs")
    args = parser.parse_args()
    if not sys.platform.startswith("linux"):
        parser.error("This runner uses the Linux native command owner; Windows has separate runtime gates")
    compile_limit = execution_policy.watchdog_seconds("native_compile_seconds")
    case_limit = execution_policy.watchdog_seconds("native_case_seconds")
    if args.timeout is not None:
        if not math.isfinite(args.timeout) or args.timeout < max(compile_limit, case_limit):
            parser.error("--timeout must be finite and at least the repository compile/case watchdogs")
        compile_limit = case_limit = args.timeout
    output = args.output.resolve()
    if output.exists():
        parser.error("--output must be a new directory so previous failures and logs remain intact")
    output.mkdir(parents=True)
    report = {"schema": "gentek80-native-campaign-v1", "status": "running",
              "complete": False, "started_utc": datetime.now(timezone.utc).isoformat(),
              "include_worldgen": args.include_worldgen, "sanitizers": args.sanitize,
              "cases": [], "errors": []}
    receipt_path = output / "native-report.json"
    exit_code = 1
    try:
        before = inputs()
        compiler = compiler_identity(args.compiler, ROOT)
        source = {"commit": git("rev-parse", "HEAD"), "tree": git("rev-parse", "HEAD^{tree}"),
                  "tracked_delta": git("status", "--porcelain", "--untracked-files=no"),
                  "inputs_sha256": before}
        report.update(source=source, compiler_identity=compiler,
                      source_clean=not source["tracked_delta"])
        key = hashlib.sha256(json.dumps({"compiler": compiler, "source": before,
                                        "sanitizers": args.sanitize},
                                       sort_keys=True).encode()).hexdigest()[:20]
        build = output / ("native-build-" + key)
        suites = (*WORLDGEN, *SHOWCASES) if args.include_worldgen else SHOWCASES
        suffix = "_sanitized" if args.sanitize else ""
        binaries = [(name, build / (name + suffix)) for name in suites]
        report["expected_suites"] = list(suites)
        report["build_directory"] = str(build)
        save(receipt_path, report)
        command = ["make", "-k", "-j" + str(args.jobs),
                   "CXX=" + shlex.join(compiler["argv"]), "BUILD_DIR=" + str(build),
                   *(str(binary) for _, binary in binaries)]
        built = run_timed_command.run(command, timeout_seconds=compile_limit,
                                      label="gentek80-native-build",
                                      output_dir=output / "build-command", root=ROOT)
        report["build"] = built
        if built["status"] != "passed":
            report["errors"].append("Native compilation did not pass; available binaries are diagnostic only")
        if inputs() != before or compiler_identity(args.compiler, ROOT) != compiler:
            raise RuntimeError("Native source or compiler changed during build; refusing test admission")
        for name, binary in binaries:
            if not binary.is_file():
                report["cases"].append({"suite": name, "status": "not_built",
                                        "reason": "Expected binary is absent after failed compilation"})
                save(receipt_path, report)
                continue
            argv = [str(binary)]
            if args.sanitize:
                argv = ["env", "ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1",
                        "UBSAN_OPTIONS=halt_on_error=1", *argv]
            tested = run_timed_command.run(argv, timeout_seconds=case_limit, label=name,
                                           output_dir=output / name, root=ROOT)
            report["cases"].append({"suite": name, "binary_sha256": digest(binary), **tested})
            save(receipt_path, report)
        after = inputs()
        report["source_unchanged"] = before == after
        report["compiler_unchanged"] = compiler_identity(args.compiler, ROOT) == compiler
        report["passed_suites"] = sum(case["status"] == "passed" for case in report["cases"])
        passed = (built["status"] == "passed" and report["source_unchanged"]
                  and report["compiler_unchanged"] and report["passed_suites"] == len(suites))
        report.update(status="passed" if passed else "failed", complete=True)
        exit_code = 0 if passed else 1
    except Exception as error:
        report.update(status="failed", complete=False)
        report["errors"].append(f"{type(error).__name__}: {error}")
    except KeyboardInterrupt:
        report.update(status="interrupted", complete=False)
        report["errors"].append("Interrupted before complete qualification")
        exit_code = 130
    finally:
        report["finished_utc"] = datetime.now(timezone.utc).isoformat()
        save(receipt_path, report)
    print(f"GENTEK80_NATIVE status={report['status']} "
          f"passed={report.get('passed_suites', 0)}/{len(report.get('expected_suites', []))} "
          f"report={receipt_path}", flush=True)
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
