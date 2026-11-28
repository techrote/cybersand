#!/usr/bin/env python3
"""Independently inspect a source-bound ObjectShard native evidence archive.

No producer/verifier module is imported. No compiler, native test or application
is executed. External GitHub artifact metadata, exact Git inputs, retained raw
logs, actual executable bytes and registered budgets must all agree. The caller
separately joins the artifact to terminal workflow/job/attempt metadata.
"""
from __future__ import annotations

import argparse
import ast
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re
import shlex
import subprocess
import zipfile


NATIVE_RUNNER = "tools/objectshard/run_native_tests.py"
BENCHMARK_RUNNER = "tools/objectshard/run_benchmarks.py"
BUDGET_PATH = "tools/objectshard/native_budgets.json"
EXPECTED_CHECKS = {"storage": 8271, "contact": 46037, "coordinator": 5945,
                   "admission": 28092, "external_fire": 3683, "chemistry": 4472, "world": 192}
EXPECTED_WORKLOADS = {"empty_lab", "inert_stationary", "inert_moving", "reacting_one", "reacting_three",
                      "perforated_reacting", "saturated_world_destinations", "dormant_twelve", "wake_burst_twelve",
                      "compact_vs_tuned_serial_miniature"}


def need(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git(repo: Path, *parts: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(repo), *parts], timeout=120)


def source(repo: Path, ref: str, path: str) -> bytes:
    return git(repo, "show", ref + ":" + path)


def expected_inventory(repo: Path, ref: str) -> tuple[dict[str, set[str]], set[str]]:
    """Derive complete registries from Git and literal source, never a report map."""
    paths = set(git(repo, "ls-tree", "-r", "--name-only", "-z", ref).decode().split("\0")) - {""}
    syntax = ast.parse(source(repo, ref, NATIVE_RUNNER).decode())
    suite_nodes = [node.value for node in syntax.body if isinstance(node, ast.Assign)
                   and any(isinstance(target, ast.Name) and target.id == "SUITES" for target in node.targets)]
    need(len(suite_nodes) == 1 and isinstance(suite_nodes[0], ast.Dict), "Native SUITES registry is not one literal dictionary")
    suite_names = [ast.literal_eval(key) for key in suite_nodes[0].keys]
    need(len(suite_names) == len(set(suite_names)) and set(suite_names) == set(EXPECTED_CHECKS),
         "Registered native suite inventory changed; independent review update required")
    base = {path for path in paths if path.startswith(("native/include/", "native/src/"))} | {NATIVE_RUNNER}
    makefile = source(repo, ref, "Makefile").decode().replace("\\\n", " ")
    declarations = re.findall(r"^TEST_SOURCES\s*[:+?]?=\s*(.*)$", makefile, re.M)
    need(len(declarations) == 1, "World inventory requires one explicit TEST_SOURCES declaration")
    world = shlex.split(declarations[0])
    need(bool(world) and len(world) == len(set(world)) and
         all(re.fullmatch(r"native/tests/[A-Za-z0-9_]+\.cpp", path) for path in world),
         "World source inventory is not a unique bounded literal list")
    test_headers = {path for path in paths if path.startswith("native/tests/") and Path(path).suffix in {".hpp", ".h", ".inc"}}
    native = base | set(world) | test_headers | {"Makefile", "docs/reference/liquid-solver-capability-matrix.json"}
    native |= {"native/tests/test_object_shard_" + suite + ".cpp" for suite in suite_names if suite != "world"}
    benchmark = base | {"native/tests/benchmark_object_shard.cpp", BUDGET_PATH, BENCHMARK_RUNNER}
    need(native <= paths and benchmark <= paths, "Registered source input is absent from exact Git tree")
    return {"native": native, "retained-lab-native-budgets": benchmark}, set(suite_names)


def require_keys(record: dict, expected: set[str], label: str) -> None:
    actual = record.get("sources")
    need(isinstance(actual, dict) and set(actual) == expected,
         label + " incomplete or unexpected source-input inventory")


def passed_command(record: dict, label: str) -> None:
    need(isinstance(record, dict) and type(record.get("returncode")) is int and record["returncode"] == 0
         and record.get("timed_out") is False and isinstance(record.get("command"), list)
         and bool(record["command"]), label + " did not complete successfully")


def archive_digest(archive: zipfile.ZipFile, name: str) -> str:
    with archive.open(name) as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def strict_json(raw: bytes):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            need(key not in result, "Duplicate JSON key: " + key)
            result[key] = value
        return result
    return json.loads(raw, object_pairs_hook=unique,
                      parse_constant=lambda value: (_ for _ in ()).throw(ValueError("Nonfinite JSON: " + value)))


def review(args: argparse.Namespace) -> dict:
    metadata = strict_json(args.metadata.read_bytes())
    matched = [row for row in metadata["artifacts"] if row["id"] == args.artifact_id]
    need(len(matched) == 1, "External artifact identity is missing or duplicated")
    artifact = matched[0]
    with args.archive.open("rb") as stream:
        actual_digest = hashlib.file_digest(stream, "sha256").hexdigest()
    need(args.archive.stat().st_size == artifact["size_in_bytes"] and "sha256:" + actual_digest == artifact["digest"],
         "Native archive differs from external GitHub size or digest")
    need(artifact["workflow_run"]["head_sha"] == args.source_sha, "External artifact source differs")
    tree = git(args.repo, "rev-parse", args.git_ref + "^{tree}").decode().strip()
    need(tree == git(args.repo, "rev-parse", args.source_sha + "^{tree}").decode().strip(),
         "Reviewed Git tree differs from published candidate tree")
    expected, suites = expected_inventory(args.repo, args.git_ref)
    result = {"schema": "objectshard-m4-independent-native-candidate-review-v1",
              "source_commit": args.source_sha, "reviewed_git_ref": args.git_ref, "source_tree": tree,
              "artifact": {"id": args.artifact_id, "bytes": args.archive.stat().st_size, "sha256": actual_digest},
              "workflow_run": artifact["workflow_run"], "source_inputs": [], "executables": [], "budgets": [],
              "limitations": ["This reads retained native evidence; it performs no new execution or build.",
                  "Caller must independently join terminal job/run/attempt metadata; a retained artifact alone is not a complete campaign PASS.",
                  "Native benchmark poses and acknowledgements are synthetic; they do not establish Rapier, rendering, monitor presentation or physical NVIDIA performance.",
                  "C++ requested allocations are not process RSS. LeakSanitizer is disabled by the registered native runner.",
                  "Application, package and material parity qualification remain separate from these seven native suites and ten benchmark workloads."]}
    with zipfile.ZipFile(args.archive) as archive:
        names = archive.namelist()
        need(len(names) == len(set(names)), "Duplicate archive members")
        need(all(not PurePosixPath(name).is_absolute() and ".." not in PurePosixPath(name).parts and "\\" not in name for name in names),
             "Unsafe archive member path")
        result["archive_members"] = len(names)
        input_paths = [name for name in names if name.endswith("/inputs.json")]
        need(len(input_paths) == 2 and {name.split("/", 1)[0] for name in input_paths} == set(expected),
             "Missing, duplicate or unexpected native input records")
        captured = {}
        for name in sorted(input_paths):
            group = name.split("/", 1)[0]
            raw = archive.read(name)
            record = strict_json(raw)
            need(type(record.get("schema")) is int and record["schema"] == 1, "Unknown native input schema")
            need(record.get("git_head") == args.source_sha, "Frozen input source differs from candidate")
            require_keys(record, expected[group], group)
            specification = {key: value for key, value in record.items()
                             if key not in {"git_head", "git_status", "source_root", "input_digest"}}
            recalculated = digest(json.dumps(specification, sort_keys=True).encode())
            need(record.get("input_digest") == recalculated, "Input specification digest differs")
            prefix = name.rsplit("/", 1)[0]
            for path, expected_digest in sorted(record["sources"].items()):
                frozen = archive.read(prefix + "/source/" + path)
                need(digest(frozen) == expected_digest and digest(source(args.repo, args.git_ref, path)) == expected_digest,
                     "Frozen source differs from exact Git: " + path)
            captured[group] = (record, prefix)
            result["source_inputs"].append({"path": name, "sha256": digest(raw), "count": len(record["sources"]),
                                            "input_digest": recalculated, "sources": record["sources"]})

        native_inputs, prefix = captured["native"]
        need(set(native_inputs.get("suites", [])) == suites and len(native_inputs["suites"]) == len(suites)
             and native_inputs.get("world_filter") == "", "Native suite selection is incomplete or filtered")
        need("-fsanitize=address,undefined" in native_inputs["flags"], "Native sanitizer flags missing")
        native = strict_json(archive.read("native/summary.json"))
        need(native == strict_json(archive.read(prefix + "/summary.json")), "Native summary copies disagree")
        need(native.get("schema") == 1 and native.get("git_head") == args.source_sha
             and native.get("input_digest") == native_inputs["input_digest"], "Native summary source/input binding differs")
        need(native.get("status") == "passed" and native.get("counts_complete") is True
             and native.get("sanitizers") is True and native.get("leak_sanitizer") is False
             and native.get("failures_reported") == 0 and set(native.get("suites", {})) == suites,
             "Native summary is incomplete or unsuccessful")
        checks = cases = 0
        for suite in sorted(suites):
            entry = native["suites"][suite]
            need(entry.get("status") == "passed" and entry.get("failures") == 0, "Unsuccessful native suite: " + suite)
            passed_command(entry.get("link"), suite + " link")
            passed_command(entry.get("execution"), suite + " execution")
            need("-fsanitize=address,undefined" in entry["link"]["command"], "Suite link lacks sanitizer flags: " + suite)
            need(len(entry["execution"]["command"]) == 1, "Native executable invocation is filtered or augmented")
            binary_name = "test_object_shard_" + suite
            need(PurePosixPath(entry["execution"]["command"][0]).name == binary_name, "Unexpected native executable identity")
            binary_sha = archive_digest(archive, prefix + "/" + binary_name)
            need(binary_sha == entry.get("binary_sha256"), "Actual native executable hash differs: " + suite)
            raw_log = archive.read(prefix + "/logs/test-" + suite + ".log")
            log = raw_log.decode("utf-8", errors="strict")
            need(not re.search(r"ERROR: AddressSanitizer|AddressSanitizer:DEADLYSIGNAL|SUMMARY: (?:AddressSanitizer|UndefinedBehaviorSanitizer)|runtime error:", log),
                 "Raw native log contains sanitizer diagnostics: " + suite)
            if suite == "world":
                footers = re.findall(r"^(\d+) tests passed$", log, re.M)
                need(len(footers) == 1 and int(footers[0]) == EXPECTED_CHECKS[suite], "World completion inventory differs")
                need(len(re.findall(r"^\[pass\]", log, re.M)) == EXPECTED_CHECKS[suite], "World raw passed-case inventory differs")
                observed = int(footers[0])
                need(entry.get("name_filter") is None and entry.get("count_unit") == "test_cases", "World filter or count unit differs")
                cases += observed
            else:
                footers = [(int(a), int(b)) for a, b in re.findall(r"(\d+) checks, (\d+) failures", log)]
                for line in log.splitlines():
                    try:
                        footer = strict_json(line.encode())
                    except (ValueError, TypeError):
                        continue
                    if isinstance(footer, dict) and type(footer.get("checks")) is int and type(footer.get("failures")) is int:
                        footers.append((footer["checks"], footer["failures"]))
                need(footers == [(EXPECTED_CHECKS[suite], 0)], "Missing, duplicate or changed native completion counts: " + suite)
                observed = footers[0][0]
                need(entry.get("count_unit") == "checks", "Native suite count unit differs")
                checks += observed
            need(type(entry.get("checks")) is int and entry["checks"] == observed, "Native report count disagrees with raw log")
            result["executables"].append({"suite": suite, "sha256": binary_sha, "checks": observed,
                                          "count_unit": entry["count_unit"], "log_sha256": digest(raw_log)})
        need(checks == native["checks_reported"] == 96500 and cases == native["test_cases_reported"] == 192,
             "Native aggregate counts differ")
        result["native"] = {key: native[key] for key in ("status", "checks_reported", "test_cases_reported", "failures_reported",
                                                        "counts_complete", "sanitizers", "leak_sanitizer")}

        benchmark_inputs, prefix = captured["retained-lab-native-budgets"]
        summary = strict_json(archive.read("retained-lab-native-budgets/summary.json"))
        need(summary == strict_json(archive.read(prefix + "/summary.json")), "Benchmark summary copies disagree")
        need(summary.get("schema") == 1 and summary.get("git_head") == args.source_sha
             and summary.get("input_digest") == benchmark_inputs["input_digest"] and summary.get("status") == "qualified",
             "Benchmark source binding or qualification differs")
        need(benchmark_inputs.get("case") is None, "Benchmark selected a partial workload")
        passed_command(summary.get("link"), "benchmark link")
        passed_command(summary.get("execution"), "benchmark execution")
        need(type(benchmark_inputs.get("ticks")) is int and benchmark_inputs["ticks"] > 0
             and type(benchmark_inputs.get("repetitions")) is int and benchmark_inputs["repetitions"] > 0,
             "Benchmark sample configuration is invalid")
        invocation = summary["execution"]["command"]
        need(PurePosixPath(invocation[0]).name == "benchmark_object_shard"
             and invocation[1:] == ["--ticks", str(benchmark_inputs["ticks"]),
                                    "--repetitions", str(benchmark_inputs["repetitions"])],
             "Benchmark executable or exact unfiltered sample arguments differ")
        binary_sha = archive_digest(archive, prefix + "/benchmark_object_shard")
        need(binary_sha == summary.get("binary_sha256"), "Benchmark executable hash differs")
        benchmark_raw = archive.read(prefix + "/benchmark.json")
        benchmark = strict_json(benchmark_raw)
        need(type(benchmark.get("schema")) is int and benchmark["schema"] == 1
             and benchmark.get("physics") == "synthetic_pose_and_ACK_no_Rapier"
             and benchmark.get("allocation_scope") == "requested_C++_new_bytes_not_RSS",
             "Benchmark schema, physics or allocation scope differs")
        raw_log = archive.read(prefix + "/logs/benchmark.log")
        need(strict_json(raw_log) == benchmark, "Raw benchmark output differs from report")
        need(benchmark.get("checks") == summary.get("checks") == 4276351 and benchmark.get("failures") == summary.get("failures") == 0,
             "Benchmark completion checks differ")
        workloads = benchmark.get("cases", [])
        need(len(workloads) == len(EXPECTED_WORKLOADS) and {row["name"] for row in workloads} == EXPECTED_WORKLOADS,
             "Benchmark workload inventory differs")
        budget = strict_json(source(args.repo, args.git_ref, BUDGET_PATH))
        limits = budget["integrated_limits"]
        for case in workloads:
            observed = []
            if case["name"] == "compact_vs_tuned_serial_miniature":
                observed.extend((key + "_steady_allocations", case["memory"][key + "_steady_allocations"],
                                 budget["comparison_requirements"]["steady_cpp_allocations_each_candidate"]) for key in ("compact", "miniature"))
            else:
                need(case.get("ticks_per_repetition") == benchmark_inputs["ticks"]
                     and case.get("repetitions") == benchmark_inputs["repetitions"],
                     "Benchmark regular workload sample counts differ from actual invocation")
                frame = case["timings"]["native_frame_including_snapshot_receipt"]
                need(type(frame["samples"]) is int and frame["samples"] >= budget["minimum_frame_samples_per_workload"], "Insufficient benchmark samples")
                observed.extend(("native_frame_" + key + "_us", frame[key + "_us"], limits["native_frame_" + key + "_us"]) for key in ("p95", "p99", "max"))
                observed.extend((key, case["memory"][key], limits[key]) for key in
                                ("cpp_live_max_bytes", "cpp_peak_max_bytes", "registry_retained_max_bytes"))
                observed.extend((("steady_cpp_allocations", case["memory"]["steady_allocations"], limits["steady_cpp_allocations"]),
                                 ("geometry_age_max_ticks", case["observations"]["geometry_age_max_ticks"], limits["geometry_age_max_ticks"])))
            for metric, actual, limit in observed:
                need(type(actual) in (int, float) and math.isfinite(actual) and 0 <= actual <= limit, "Native budget exceeded: " + case["name"] + "." + metric)
                result["budgets"].append({"case": case["name"], "metric": metric, "actual": actual, "limit": limit, "margin": limit - actual})
        need(len(result["budgets"]) == summary["budget_qualification"]["limits_checked"] == 74
             and summary["budget_qualification"]["status"] == "passed" and summary["budget_qualification"]["failures"] == [],
             "Benchmark independent budget verdict differs")
        result["benchmark"] = {"checks": benchmark["checks"], "limits": len(result["budgets"]), "binary_sha256": binary_sha,
                                "report_sha256": digest(benchmark_raw), "log_sha256": digest(raw_log),
                                "cpu_model": benchmark_inputs.get("cpu_model"), "platform": benchmark_inputs.get("platform"),
                                "ticks": benchmark_inputs["ticks"], "repetitions": benchmark_inputs["repetitions"]}
    result["status"] = "passed-independent-native-archive"
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("archive", "metadata", "repo", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--git-ref", required=True)
    parser.add_argument("--artifact-id", type=int, required=True)
    args = parser.parse_args()
    result = review(args)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(json.dumps({"status": result["status"], "source": args.source_sha,
                      "input_counts": [row["count"] for row in result["source_inputs"]],
                      "native_checks": result["native"]["checks_reported"], "world_cases": result["native"]["test_cases_reported"],
                      "benchmark_checks": result["benchmark"]["checks"], "budget_limits": len(result["budgets"])}))


if __name__ == "__main__":
    main()
