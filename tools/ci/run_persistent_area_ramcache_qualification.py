#!/usr/bin/env python3
"""Extend all donor gates with actual native residency, writeback and prefetch.

Thirty zero-debt HOT and WARM samples run per configured worker count. Wall
duration, native stepping, frame gaps and filesystem calls remain distinct.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys

import run_persistent_areas_qualification as donor

ROOT = Path(__file__).resolve().parents[2]
EXTRA_INPUTS = {
    "godot/project.godot",
    "tools/ci/run_persistent_area_ramcache_qualification.py",
    "tools/ci/run_persistent_area_writeback_faults.py",
    "tools/ci/run_persistent_area_residency_memory.py",
    "tools/ci/run_persistent_area_recovery.py",
    "tools/ci/run_persistent_area_travel_benchmark.py",
    "tools/ci/benchmark_persistent_area_travel.gd",
}
_donor_source_identity = donor.source_identity


def source_identity(project: Path) -> dict:
    value = _donor_source_identity(project)
    paths = EXTRA_INPUTS | {path.relative_to(project.parent).as_posix()
        for path in project.rglob("*.gdextension") if ".godot" not in path.parts}
    for relative in sorted(paths):
        path = project.parent / relative
        if not path.is_file():
            value["missing_source_inputs"].append(relative)
        else:
            value["source_inputs_sha256"][relative] = hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
    return value


donor.source_identity = source_identity


def statistics(rows: list[dict]) -> dict:
    values = sorted(float(row["elapsed_ms"]) for row in rows)
    if not values:
        return {"samples": 0}
    n = len(values)
    return {"samples": n, "p50_ms": (values[(n-1)//2]+values[n//2])/2,
            "p95_ms": values[math.ceil(n*0.95)-1], "worst_ms": values[-1],
            "maximum_correlated_main_frame_ms": max(float(row["max_main_frame_ms"]) for row in rows),
            "native_ticks": sum(int(row["native_ticks_executed"]) for row in rows)}


class Campaign(donor.Campaign):
    def __init__(self, args: argparse.Namespace):
        super().__init__(args)
        self.env["CYBERSAND_SOURCE_REVISION"] = self.identity["source_commit"]

    def command(self, script: str, arguments: list[str] = [], graphical: bool = False) -> list[str]:
        # These unchanged donor fixtures qualify the private-candidate COLD
        # lifecycle (including an unchanged live World before publication).
        # The explicit cache fixtures independently qualify retained HOT
        # authority and its synchronous/asynchronous storage recovery.
        if script in ("test_persistent_area_owner_timeout.gd", "test_persistent_areas_workbench.gd"):
            arguments = [*arguments, "--persistent-cache-off"]
        return super().command(script, arguments, graphical)

    def additional_cases(self) -> None:
        self.report["ramcache_schema"] = "gen006-ramcache-qualification-v1"
        self.report["ramcache"] = {}
        self.report["ramcache_performance"] = {}
        units = [
            ("ramcache-clock", "test_persistent_area_background_clock.gd", "GEN006_RAMCACHE_BACKGROUND_CLOCK"),
            ("ramcache-ledger", "test_persistent_area_cache.gd", "GEN006_RAMCACHE_CACHE"),
            ("ramcache-writeback", "test_persistent_area_writeback.gd", "GEN006_RAMCACHE_WRITEBACK"),
            ("ramcache-metadata-bounds", "test_persistent_area_metadata_bounds.gd", "GEN006_RAMCACHE_METADATA_BOUNDS"),
            ("ramcache-owner-review", "test_persistent_area_residency_owner_review.gd", "GEN006_RAMCACHE_OWNER_REVIEW"),
            ("ramcache-prefetch-concurrency", "test_persistent_area_prefetch_concurrency.gd", "GEN006_RAMCACHE_PREFETCH_CONCURRENCY"),
        ]
        for label, script, marker in units:
            self.run(label, self.command(script), marker=marker, timeout=300)
        for mode in ("healthy", "missing_setup", "wrong_setup_types", "wrong_execution_type", "missing_worker_type", "stop",
            "runtime_mismatch", "session_mismatch", "source_identity_mismatch", "physics_mismatch", "policy_mismatch",
            "authoring_changed", "warm_corruption", "warm_wrong_tick", "short_native_reservation",
            "short_transient_reservation", "wrong_incarnation", "oversized_metadata"):
            self.run("ramcache-independent-"+mode, self.command("test_persistent_area_independent_native_review.gd",
                ["--independent-mode="+mode]), marker="GEN006_INDEPENDENT_NATIVE_REVIEW", timeout=180)
        row = self.run("ramcache-native", self.command("test_persistent_area_residency_native.gd"), timeout=300)
        receipts = [json.loads(line.partition(" ")[2]) for line in (self.output/row["log"]).read_text().splitlines()
                    if line.startswith("GEN006_NATIVE_RESIDENCY_RESULT ")]
        if len(receipts) != 1 or receipts[0].get("failures") != [] or receipts[0].get("assertions", 0) < 1:
            raise RuntimeError("Missing or failing actual native residency receipt")
        row["completion"] = receipts[0]
        self.cross_authoring()
        self.writeback_faults()
        self.healthy_recovery()
        self.recovery_workbench()
        self.resident_storage_recovery()
        self.resident_advance_recovery()
        self.native_memory()
        for workers in (1, 4):
            self.ramcache_workbench("write", workers)
            self.ramcache_workbench("reopen", workers)
        self.responsiveness()
        self.cold_comparison()

    def cross_authoring(self) -> None:
        folder = self.output / "cross-authoring"
        writer_pid = None
        for mode in ("write", "reopen"):
            arguments = [f"--persistent-profile={folder / 'profile'}", f"--persistent-evidence={folder}",
                         f"--persistent-test-mode={mode}", "--persistent-test-workers=1", "--persistent-start-paused"]
            if not self.args.headless:
                arguments.append("--persistent-require-graphics")
            command = self.command("fixtures/persistent_area_cross_authoring.gd", arguments, not self.args.headless)
            row = self.run(f"ramcache-cross-authoring-{mode}", command, marker="PERSISTENT_AREAS_WORKBENCH", timeout=420)
            receipt = json.loads((folder / f"workbench-{mode}.json").read_text(encoding="utf-8"))
            # The donor serializes its assertion count before checking the receipt file opened successfully.
            if receipt["process_id"] != row["pid"] or row["completion"]["pid"] != row["pid"] \
                    or receipt["mode"] != mode or receipt["assertions"] + 1 != row["completion"]["checks"] \
                    or receipt["failures"] or receipt["graphical"] != (not self.args.headless):
                raise RuntimeError("Cross-authoring receipt differs from its measured process")
            if mode == "write":
                writer_pid = row["pid"]
            elif row["pid"] == writer_pid:
                raise RuntimeError("Cross-authoring recovery requires a fresh process")

    def responsiveness(self) -> None:
        self.report["ramcache_responsiveness"] = {}
        for workers in (1, 4):
            group = {}
            for variant in ("control", "prefetch", "reversal"):
                label = f"ramcache-responsiveness-{variant}-w{workers}"
                folder = self.output/label
                arguments = [f"--persistent-profile={folder/'profile'}", f"--persistent-evidence={folder}",
                    "--persistent-start-paused", "--persistent-test-mode=write", f"--persistent-test-workers={workers}",
                    "--responsiveness-variant="+variant, "--responsiveness-window-ms=10000"]
                if not self.args.headless: arguments.append("--persistent-require-graphics")
                row = self.run(label, self.command("test_persistent_area_responsiveness.gd", arguments,
                    not self.args.headless), marker="GEN006_RAMCACHE_RESPONSIVENESS", timeout=300)
                proof = json.loads((folder/("responsiveness-"+variant+".json")).read_text())
                if proof.get("failures") != [] or proof.get("process_id") != row["pid"] \
                        or proof.get("variant") != variant or proof.get("completed") is not True:
                    raise RuntimeError("Responsiveness receipt differs from actual completed graphical process")
                group[variant] = proof
            comparable = lambda proof: {key:value for key,value in proof["initial"].items()
                if key not in ("active_handle", "world_generation")}
            if comparable(group["control"]) != comparable(group["prefetch"]) \
                    or comparable(group["control"]) != comparable(group["reversal"]):
                raise RuntimeError("Active-play control and speculation did not start from identical native/authoring state")
            self.report["ramcache_responsiveness"][str(workers)] = group

    def healthy_recovery(self) -> None:
        folder = self.output/"ramcache-healthy-recovery"
        arguments = ["--godot", str(self.engine), "--repo", str(self.project.parent), "--output", str(folder)]
        if not self.args.require_clean_source: arguments.append("--diagnostic")
        self.helper("tools/ci/run_persistent_area_recovery.py", arguments, "ramcache-healthy-recovery.log", 600)
        proof = json.loads((folder/"report.json").read_text())
        if not proof.get("passed") or not proof.get("inputs_unchanged") or len(proof.get("runs", [])) != 2:
            raise RuntimeError("Failed-active native recovery did not pass independent process restoration")
        for child in proof["runs"]:
            self.results.append(dict(child, label="ramcache-healthy-"+child["mode"],
                log="ramcache-healthy-recovery/"+child["log"], status="passed"))
        self.report["ramcache_healthy_recovery"] = proof

    def recovery_workbench(self) -> None:
        self.report["ramcache_recoverable_workbench"] = {}
        for case in ("deferred", "strict", "first", "ahead"):
            folder = self.output/("ramcache-recoverable-"+case)
            for mode in ("write", "reopen"):
                arguments = [f"--persistent-profile={folder/'profile'}", f"--persistent-evidence={folder}",
                    "--persistent-start-paused", "--persistent-test-mode="+mode]
                if case == "strict": arguments.append("--recoverable-strict-exit")
                if case == "first": arguments.append("--recoverable-first-area")
                if case == "ahead": arguments.append("--recoverable-during-ahead")
                if not self.args.headless: arguments.append("--persistent-require-graphics")
                label = "ramcache-recoverable-"+case+"-"+mode
                row = self.run(label, self.command("test_persistent_area_recoverable_workbench.gd", arguments,
                    not self.args.headless), marker="GEN006_RAMCACHE_RECOVERABLE_WORKBENCH", timeout=300)
                proof = json.loads((folder/("recoverable-workbench-"+mode+".json")).read_text())
                if proof.get("failures") != [] or proof.get("process_id") != row["pid"]:
                    raise RuntimeError("Recoverable Workbench receipt differs from its actual process")
                self.report["ramcache_recoverable_workbench"][case+"-"+mode] = proof
        folder = self.output/"ramcache-hot-recovery"
        arguments = [f"--persistent-profile={folder/'profile'}", f"--persistent-evidence={folder}",
            "--persistent-start-paused"]
        if not self.args.headless: arguments.append("--persistent-require-graphics")
        row = self.run("ramcache-hot-recovery", self.command("test_persistent_area_hot_recovery.gd", arguments,
            not self.args.headless), marker="GEN006_RAMCACHE_HOT_RECOVERY", timeout=360)
        proof = json.loads((folder/"hot-recovery.json").read_text())
        if proof.get("failures") != [] or proof.get("process_id") != row["pid"]:
            raise RuntimeError("Late handoff receipt differs from its actual process")
        self.report["ramcache_late_handoff"] = proof

    def resident_storage_recovery(self) -> None:
        self.report["ramcache_resident_storage_recovery"] = {}
        folder = self.output/"ramcache-resident-storage"
        pids = []
        for mode in ("write", "reopen"):
            arguments = [f"--persistent-profile={folder/'profile'}", f"--persistent-evidence={folder}",
                "--persistent-start-paused", "--persistent-test-mode="+mode, "--persistent-test-workers=1"]
            if not self.args.headless: arguments.append("--persistent-require-graphics")
            label = "ramcache-resident-storage-"+mode
            row = self.run(label, self.command("test_persistent_area_resident_storage_recovery.gd", arguments,
                not self.args.headless), marker="GEN006_RAMCACHE_RESIDENT_STORAGE_RECOVERY", timeout=420)
            proof = json.loads((folder/("resident-storage-recovery-"+mode+".json")).read_text())
            if proof.get("schema") != "gen006-resident-storage-recovery-v1" or proof.get("failures") != [] \
                    or proof.get("mode") != mode or proof.get("process_id") != row["pid"] \
                    or proof.get("graphical") != (not self.args.headless) or proof.get("completed") is not True:
                raise RuntimeError("Resident storage recovery differs from its actual completed application process")
            self.report["ramcache_resident_storage_recovery"][mode] = proof
            pids.append(row["pid"])
        if pids[0] == pids[1]:
            raise RuntimeError("Resident storage recovery did not reopen in a genuinely new process")

    def resident_advance_recovery(self) -> None:
        self.report["ramcache_advance_recovery"] = {}
        folder = self.output/"ramcache-advance-recovery"
        pids = []
        for mode in ("write", "reopen"):
            arguments = [f"--persistent-profile={folder/'profile'}", f"--persistent-evidence={folder}",
                "--persistent-start-paused", "--persistent-test-mode="+mode, "--persistent-test-workers=1"]
            if not self.args.headless: arguments.append("--persistent-require-graphics")
            label = "ramcache-advance-recovery-"+mode
            row = self.run(label, self.command("test_persistent_area_advance_recovery.gd", arguments,
                not self.args.headless), marker="GEN006_RAMCACHE_ADVANCE_RECOVERY", timeout=420)
            proof = json.loads((folder/("advance-recovery-"+mode+".json")).read_text())
            if proof.get("schema") != "gen006-resident-advance-recovery-v1" or proof.get("failures") != [] \
                    or proof.get("mode") != mode or proof.get("process_id") != row["pid"] \
                    or proof.get("graphical") != (not self.args.headless) or proof.get("completed") is not True:
                raise RuntimeError("Late resident advancement recovery differs from its actual application process")
            self.report["ramcache_advance_recovery"][mode] = proof
            pids.append(row["pid"])
        if pids[0] == pids[1]:
            raise RuntimeError("Resident advancement recovery did not reopen in a genuinely new process")

    def cold_comparison(self) -> None:
        donor_project = Path(os.environ.get("CYBERSAND_GEN006_DONOR", ""))/"godot"
        if not donor_project.is_dir():
            raise RuntimeError("Set CYBERSAND_GEN006_DONOR to the isolated exact #725 checkout")
        baseline_sha = "1198c1a252cba4ae9ee14371f7b386f685155438bd3556b8640f04f9253ea977" if self.platform == "linux" else "408283d6a5cf4db3830a20b971eb614f17161890bf268c63c405bdc2d219479f"
        self.report["ramcache_cold_comparison"] = {}
        for label, project, source, native in (
            ("donor-cold", donor_project, "d0d043f4740ffed5f0dbb4120e437458d7a9bd57", baseline_sha),
            ("successor-cold", self.project, self.identity["source_commit"], self.report["native_sha256"])):
            output = self.output/label
            arguments = ["--godot", str(self.engine), "--project", str(project), "--output", str(output),
                "--expected-source", source, "--expected-native", native, "--workers", "1", "--samples", "30"]
            if self.args.headless: arguments.append("--headless")
            if not self.args.require_clean_source: arguments.append("--diagnostic")
            self.helper("tools/ci/run_persistent_area_travel_benchmark.py", arguments, label+"-runner.log", 2100)
            proof = json.loads((output/"benchmark.json").read_text())
            if proof.get("status") != "passed" or proof.get("statistics", {}).get("samples") != 30:
                raise RuntimeError("Controlled donor/successor cold benchmark did not pass")
            self.results.append({"label": label, "pid": proof["pid"], "status": "passed", "exit_code": proof["exit_code"],
                "log": label+"/execution.log", "statistics": proof["statistics"]})
            self.report["ramcache_cold_comparison"][label] = proof

    def helper(self, script: str, arguments: list[str], log: str, timeout: int = 1800) -> None:
        result = subprocess.run([sys.executable, str(ROOT/script), *arguments], env=self.env,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        (self.output/log).write_bytes(result.stdout)
        if result.returncode:
            raise RuntimeError("Independent native subprocess campaign failed: "+log)

    def writeback_faults(self) -> None:
        folder = self.output/"ramcache-writeback-faults"
        arguments = ["--godot", str(self.engine), "--project", str(self.project), "--evidence", str(folder)]
        if not self.args.require_clean_source:
            arguments.append("--diagnostic")
        self.helper("tools/ci/run_persistent_area_writeback_faults.py", arguments, "ramcache-writeback-faults.log")
        proof = json.loads((folder/"results.json").read_text())
        if not proof.get("ok") or not proof.get("source_unchanged") or len(proof.get("rows", [])) != 27:
            raise RuntimeError("Nine genuine OS process-death boundaries and eighteen fresh native restores did not pass")
        if self.args.require_clean_source and not proof.get("qualified_source"):
            raise RuntimeError("Diagnostic writeback recovery cannot qualify publication")
        boundaries = ["before_capture", "before_snapshot", "queued_dirty", "after_checkpoint", "after_stage", "after_previous", "before_publish", "after_publish", "newer_dirty_after_durable"]
        for index, original in enumerate(proof["rows"]):
            boundary, position = boundaries[index//3], index % 3
            label = "ramcache-crash-"+boundary if position == 0 else f"ramcache-recover-{boundary}-{position}"
            log = f"ramcache-writeback-faults/{boundary}/" + ("killed.log" if position == 0 else "reopen.log" if position == 1 else "repeat/reopen.log")
            self.results.append(dict(original, label=label, log=log, status="passed"))
        self.report["ramcache_recovery"] = proof

    def native_memory(self) -> None:
        folder = self.output/"ramcache-memory"
        self.helper("tools/ci/run_persistent_area_residency_memory.py",
            ["--repo", str(self.project.parent), "--godot", str(self.engine), "--native", str(self.native),
             "--output", str(folder)], "ramcache-memory.log", 600)
        self.report["ramcache_memory"] = {}
        for workers in (1, 4):
            proof = json.loads((folder/f"native-memory-w{workers}.json").read_text())
            if not proof.get("ok") or proof.get("native_sha256") != self.report["native_sha256"] \
                    or proof.get("godot_sha256") != self.report["engine_sha256"]:
                raise RuntimeError("Actual native memory evidence differs from this runtime")
            label = f"ramcache-memory-w{workers}"
            self.results.append({"label": label, "pid": proof["pid"], "status": "passed", "exit_code": proof["exit_code"],
                "log": f"ramcache-memory/native-memory-w{workers}.log", "peak_sampled_rss_bytes": proof["peak_sampled_rss_bytes"]})
            self.report["ramcache_memory"][str(workers)] = proof

    def ramcache_workbench(self, mode: str, workers: int) -> None:
        folder = self.output/f"ramcache-w{workers}"
        label = f"ramcache-{mode}-w{workers}"
        arguments = [f"--persistent-profile={folder/'profile'}", f"--persistent-evidence={folder}",
            f"--persistent-test-mode={mode}", f"--persistent-test-workers={workers}", "--persistent-start-paused",
            "--ramcache-hot-samples=30", "--ramcache-warm-samples=30"]
        if not self.args.headless:
            arguments.append("--persistent-require-graphics")
        row = self.run(label, self.command("test_persistent_area_ramcache.gd", arguments, not self.args.headless),
            marker="GEN006_RAMCACHE", timeout=1800)
        receipt = json.loads((folder/f"ramcache-{mode}.json").read_text())
        if receipt.get("failures") != [] or receipt.get("process_id") != row["pid"] \
                or receipt.get("graphical") != (not self.args.headless):
            raise RuntimeError("RAM-cache Workbench receipt differs from its actual measured process")
        self.report["ramcache"][label] = receipt
        if mode == "write":
            if len(receipt.get("hot_samples", [])) != 30 or len(receipt.get("warm_samples", [])) != 30:
                raise RuntimeError("Thirty qualified samples per residency path are mandatory")
            self.report["ramcache_performance"][str(workers)] = {
                "hot_zero_debt": statistics(receipt["hot_samples"]),
                "warm_zero_debt": statistics(receipt["warm_samples"]),
                "whole_process_peak_rss_bytes": row["os_peak_rss_bytes"],
                "whole_process_cpu_seconds": row["sampled_cpu_seconds"],
                "cpu_and_memory_scope": "Whole actual graphical process; not incremental per-World cost"}
        elif self.report["ramcache"][f"ramcache-write-w{workers}"]["process_id"] == receipt["process_id"]:
            raise RuntimeError("RAM-cache reopening did not use a genuinely independent process")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=ROOT/"godot")
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--headless", action="store_true", help="Diagnostic only")
    parser.add_argument("--require-clean-source", action="store_true")
    parser.add_argument("--native-build-ledger", type=Path)
    args = parser.parse_args()
    report = Campaign(args).execute()
    print(json.dumps({"status": report["status"], "evidence": str(args.evidence)}))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
