#!/usr/bin/env python3
"""Source-bound GEN-006 native, durable recovery and graphical Workbench campaign.

Every application run is a separate real Godot process. The runner measures that
engine's resident memory and CPU time; native completed ticks and useful stepping
microseconds come from its native receipts, never from elapsed waiting time.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

from run_flatten_qualification import ProcessMemory, direct_engine
from run_windows_godot_regressions import (
    GODOT_VERSION, RAPIER_IMPORT_DESCRIPTORS, RAPIER_SHA256, native_input_paths,
)

ROOT = Path(__file__).resolve().parents[2]
SUFFIXES = {".gd", ".tscn", ".tres", ".gdshader"}
RUNTIME_PATHS = {
    "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
    "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
    "godot/addons/cybersand_native/runtime-provenance.linux.json",
    "godot/addons/cybersand_native/runtime-provenance.json",
}
UNIT_CASES = [
    ("regression-desktop-default-water", "test_liquid_desktop_default_host.gd", "LIQUID_DESKTOP_DEFAULT_HOST:"),
    ("regression-f5-water-trial-body", "test_liquid_trial_body.gd", "LIQUID_TRIAL_BODY:"),
    ("native-bridge", "test_persistent_area_native_bridge.gd", "GEN006_NATIVE_BRIDGE"),
    ("clock", "test_persistent_area_clock.gd", "GEN006_CLOCK"),
    ("store-unit", "test_persistent_area_store.gd", "GEN006_STORE"),
    ("owner-adversarial", "test_persistent_area_owner_adversarial.gd", "GEN006_OWNER_ADVERSARIAL"),
    ("owner-timeout", "test_persistent_area_owner_timeout.gd", "GEN006_OWNER_TIMEOUT"),
    ("regression-host-evidence", "test_liquid_host_evidence.gd", "LIQUID_HOST_EVIDENCE:"),
    ("regression-microscenario-controllers", "test_microscenario_controllers.gd", "MICROSCENARIO_CONTROLLERS:"),
    ("regression-host-capacity", "test_workbench_host_claim_capacity.gd", "WORKBENCH_HOST_CLAIMS:"),
    ("regression-workbench-input", "test_workbench_input.gd", "WORKBENCH_INPUT"),
    ("regression-material-baseline", "test_workbench_material_baseline.gd", "WORKBENCH_MATERIAL_BASELINE"),
]
STORAGE_LABELS = {
    "01-seed-native": "store-seed", "02-fresh-process-reopen": "store-verify",
    "03-kill-after-immutable-stage": "store-crash-staged",
    "03-kill-after-immutable-stage-concurrent-lock": "store-lock-staged",
    "04-recover-old-commit": "store-recover-staged",
    "05-kill-after-manifest-publication": "store-crash-published",
    "05-kill-after-manifest-publication-concurrent-lock": "store-lock-published",
    "06-recover-new-commit": "store-recover-published",
    "07-repeat-reopen-no-duplicate-progress": "store-repeat-verify",
}
ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource:|(?m:^ERROR:)")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path: Path, value: object) -> None:
    path.write_bytes((json.dumps(value, indent=2, sort_keys=True) + "\n").encode())


def unchanged_import_descriptor(source_root: Path, relative: str, tracked: set[str]) -> bool:
    """Admit only the known importer's canonical-equal working-copy rewrite."""
    path = source_root / relative
    if relative not in RAPIER_IMPORT_DESCRIPTORS or relative not in tracked \
            or not path.is_file() or path.is_symlink():
        return False
    committed = subprocess.check_output(["git", "show", "HEAD:" + relative], cwd=source_root)
    if path.read_bytes().replace(b"\r\n", b"\n") != committed.replace(b"\r\n", b"\n"):
        return False
    # Canonical bytes alone must not hide a mode or other structural change.
    return subprocess.run(["git", "diff", "--quiet", "--ignore-cr-at-eol", "--no-ext-diff", "--", relative],
                          cwd=source_root, check=False).returncode == 0


def source_identity(project: Path) -> dict:
    source_root = project.parent
    def git(*args: str) -> str:
        # Porcelain's leading status column is meaningful (" M path").
        return subprocess.check_output(["git", *args], cwd=source_root, text=True).rstrip("\n")
    paths = native_input_paths(source_root)
    paths |= {p.relative_to(source_root).as_posix() for p in project.rglob("*")
              if p.is_file() and p.suffix in SUFFIXES and ".godot" not in p.parts}
    paths |= {"Makefile", "tools/build_native_extension.sh", "tools/build_native_extension_windows.sh",
              "tools/ci/run_persistent_areas_qualification.py", "tools/ci/run_gen006_storage_recovery.py"}
    paths |= {p for p in RAPIER_IMPORT_DESCRIPTORS if (source_root / p).is_file()}
    hashes = {p: hashlib.sha256((source_root / p).read_bytes().replace(b"\r\n", b"\n")).hexdigest()
              for p in sorted(paths) if (source_root / p).is_file()}
    tracked = set(git("ls-files", "-z").split("\0"))
    delta = []
    for line in git("status", "--porcelain=v1", "--untracked-files=all").splitlines():
        path = line[3:]
        # A clean Godot import generates these resource UID sidecars. Only
        # ignore a new sidecar for an existing tracked source; modifications to
        # tracked UIDs and new/untracked source remain source-custody failures.
        generated_uid = (line.startswith("?? ")
                         and path.endswith((".gd.uid", ".gdshader.uid"))
                         and path[:-4] in tracked)
        # Windows imports re-save these four text files from CRLF to LF. A
        # porcelain M alone can survive that canonical no-op. Do not suppress
        # semantic edits, staged changes, symlinks, deletions or unknown files.
        imported_canonical_noop = (line.startswith(" M ")
                                  and unchanged_import_descriptor(source_root, path, tracked))
        if path not in RUNTIME_PATHS and not generated_uid and not imported_canonical_noop:
            delta.append(line)
    return {"source_commit":git("rev-parse", "HEAD"), "source_tree":git("rev-parse", "HEAD^{tree}"),
            "source_inputs_sha256":hashes, "missing_source_inputs":sorted(paths - hashes.keys()),
            "local_delta":delta}


def custody_difference(before: dict, after: dict, binaries_before: dict, binaries_after: dict) -> dict:
    first, last = before.get("source_inputs_sha256", {}), after.get("source_inputs_sha256", {})
    return {
        "unchanged":before == after and binaries_before == binaries_after,
        "source_identity_changed":{key:{"before":before.get(key), "after":after.get(key)}
            for key in ("source_commit", "source_tree", "missing_source_inputs") if before.get(key) != after.get(key)},
        "source_added":{p:last[p] for p in sorted(last.keys() - first.keys())},
        "source_removed":{p:first[p] for p in sorted(first.keys() - last.keys())},
        "source_changed":{p:{"before":first[p], "after":last[p]}
            for p in sorted(first.keys() & last.keys()) if first[p] != last[p]},
        "git_status_before":before.get("local_delta", []),
        "git_status_after":after.get("local_delta", []),
        "binaries_before":binaries_before, "binaries_after":binaries_after,
    }


def completion(text: str, marker: str) -> dict:
    lines = [line[len(marker):].strip() for line in text.splitlines() if line.startswith(marker + " ")]
    if len(lines) != 1:
        raise RuntimeError("Missing or ambiguous completion: " + marker)
    line = lines[0]
    if line.startswith("{"):
        value = json.loads(line)
    else:
        match = re.search(r"(?:checks|assertions)=(\d+)\s+failures=(\d+)", line)
        if not match:
            match = re.search(r"(\d+) assertions[;,] (\d+) failures", line)
        if not match:
            raise RuntimeError("Malformed native completion: " + line)
        value = {"checks":int(match[1]), "failures":int(match[2]), "original":line}
    if not isinstance(value.get("checks"), int) or value["checks"] < 1 or value.get("failures") not in (0, []):
        raise RuntimeError("Incomplete or failing native checks: " + marker)
    return value


def cpu_seconds(process: subprocess.Popen) -> float | None:
    if os.name == "nt":
        from ctypes import wintypes
        times = [wintypes.FILETIME() for _ in range(4)]
        function = ctypes.windll.kernel32.GetProcessTimes
        function.argtypes = [wintypes.HANDLE, *[ctypes.POINTER(wintypes.FILETIME)] * 4]
        if function(int(process._handle), *[ctypes.byref(t) for t in times]):
            return sum((t.dwHighDateTime << 32) + t.dwLowDateTime for t in times[2:]) / 10_000_000
    else:
        try:
            fields = Path(f"/proc/{process.pid}/stat").read_text().rsplit(")", 1)[1].split()
            return (int(fields[11]) + int(fields[12])) / os.sysconf("SC_CLK_TCK")
        except (FileNotFoundError, ProcessLookupError):
            pass
    return None


class Campaign:
    def __init__(self, args: argparse.Namespace):
        self.args = args
        self.project = args.project.resolve()
        self.output = args.evidence.resolve()
        if self.output.exists() and any(self.output.iterdir()):
            raise RuntimeError("Use a fresh evidence directory; failed evidence is retained.")
        self.output.mkdir(parents=True, exist_ok=True)
        self.engine = direct_engine(args.godot, sys.platform)
        self.platform = "windows" if os.name == "nt" else "linux"
        self.env = dict(os.environ, GODOT_SILENCE_ROOT_WARNING="1", PYTHONUTF8="1",
                        XDG_DATA_HOME=str(self.output / "userdata"), APPDATA=str(self.output / "userdata"),
                        LOCALAPPDATA=str(self.output / "localdata"))
        native_name = "cybersand_native.windows.x86_64.dll" if os.name == "nt" else "libcybersand_native.linux.x86_64.so"
        rapier_name = "libgodot_rapier.windows.x86_64-pc-windows-msvc.dll" if os.name == "nt" else "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"
        self.native = self.project / "addons/cybersand_native/bin" / native_name
        self.rapier = self.project / "addons/godot-rapier2d/bin" / rapier_name
        self.identity = source_identity(self.project)
        self.custody_checks: list[dict] = []
        self.results: list[dict] = []
        self.report = {"schema":"gen006-persistent-areas-qualification-v1", "status":"running", "completed":False,
                       "platform":self.platform, **self.identity, "native_sha256":sha(self.native),
                       "rapier_sha256":sha(self.rapier), "engine_sha256":sha(self.engine),
                       "engine_version":subprocess.check_output([str(self.engine), "--version"], text=True).strip(),
                       "graphical":not args.headless, "results":self.results, "workbench":{}, "store_recovery":[],
                       "native_build_ledger_sha256":"", "input_custody":"pending"}
        if self.identity["missing_source_inputs"]:
            raise RuntimeError("Qualification is missing source inputs: " + str(self.identity["missing_source_inputs"]))
        if self.report["engine_version"] != GODOT_VERSION:
            raise RuntimeError("Unpinned Godot engine.")
        expected_rapier = RAPIER_SHA256 if os.name == "nt" else "566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a"
        if self.report["rapier_sha256"] != expected_rapier:
            raise RuntimeError("Unpinned Rapier runtime.")
        if args.require_clean_source and self.identity["local_delta"]:
            raise RuntimeError("Qualification source is dirty: " + str(self.identity["local_delta"]))
        if args.native_build_ledger:
            ledger = json.loads(args.native_build_ledger.read_text())
            inputs = {p:self.identity["source_inputs_sha256"][p] for p in native_input_paths(self.project.parent)}
            if ledger.get("returncode") != 0 or ledger.get("platform") != self.platform \
                    or ledger.get("source_commit") != self.identity["source_commit"] \
                    or ledger.get("source_tree") != self.identity["source_tree"] \
                    or ledger.get("runtime_sha256") != self.report["native_sha256"] \
                    or ledger.get("source_inputs_sha256") != inputs:
                raise RuntimeError("Actual native build custody differs from this source/runtime.")
            self.report["native_build_ledger_sha256"] = sha(args.native_build_ledger)
            write(self.output / "native-build-ledger.json", ledger)

    def record_custody(self, phase: str) -> bool:
        before = {name:self.report[name] for name in ("native_sha256", "rapier_sha256", "engine_sha256")}
        after = {}
        errors = {}
        for name, path in (("native_sha256", self.native), ("rapier_sha256", self.rapier), ("engine_sha256", self.engine)):
            try:
                after[name] = sha(path)
            except OSError as error:
                after[name] = None
                errors[name] = str(error)
        try:
            identity = source_identity(self.project)
            observation = {"phase":phase, "source_after":identity,
                           **custody_difference(self.identity, identity, before, after)}
        except Exception as error:
            observation = {"phase":phase, "unchanged":False, "source_observation_error":str(error),
                           "binaries_before":before, "binaries_after":after}
        if errors:
            observation["binary_observation_errors"] = errors
        self.custody_checks.append(observation)
        self.report["custody_checks"] = self.custody_checks
        if not observation["unchanged"]:
            self.report["input_custody"] = "failed"
        write(self.output / "source-custody.json", {"schema":"gen006-source-custody-v1",
              "source_before":self.identity, "checks":self.custody_checks})
        return bool(observation["unchanged"])

    def command(self, script: str, arguments: list[str] = [], graphical: bool = False) -> list[str]:
        command = [str(self.engine), "--path", str(self.project), "--audio-driver", "Dummy"]
        command += ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3"] if graphical else ["--headless"]
        if script:
            command += ["--script", "res://tests/" + script]
        return command + (["--", *arguments] if arguments else [])

    def run(self, label: str, command: list[str], marker: str = "", crash_marker: str = "", timeout: int = 240) -> dict:
        log = self.output / (label + ".log")
        row = {"label":label, "status":"running", "command":command, "log":log.name,
               "engine_executable":str(self.engine), "engine_sha256":self.report["engine_sha256"],
               "measurement_target":"godot-engine-process", "memory_sample_interval_ms":20,
               "phase_samples":[]}
        self.results.append(row)
        started = time.monotonic()
        process = None
        try:
            with log.open("w", encoding="utf-8") as stream:
                process = subprocess.Popen(command, cwd=self.output, env=self.env, stdout=stream, stderr=subprocess.STDOUT)
                row["pid"] = process.pid
                memory = ProcessMemory(process)
                peak = os_peak = 0
                cpu = 0.0
                observed_markers = set()
                while process.poll() is None:
                    sampled = memory.sample()
                    if sampled:
                        peak, os_peak = max(peak, sampled[0]), max(os_peak, sampled[1])
                    used = cpu_seconds(process)
                    if used is not None: cpu = max(cpu, used)
                    if label.startswith("workbench-"):
                        # Sample the real process near declared fixture phases.
                        # These elapsed/CPU/RSS observations are not native tick
                        # throughput and do not attribute the entire process to
                        # one retained area.
                        for index, line in enumerate(log.read_text(errors="replace").splitlines(keepends=True)):
                            if not line.endswith("\n"):
                                continue  # The engine may still be writing this receipt.
                            prefix = line.split(" ", 1)[0]
                            if index in observed_markers or prefix not in {
                                    "PERSISTENT_AREAS_TEST_PHASE", "GEN006_RETAINED_AREAS_RESOURCE"}:
                                continue
                            receipt = json.loads(line.split(" ", 1)[1])
                            if "process_id" in receipt and receipt["process_id"] != process.pid:
                                raise RuntimeError("Resource observation belongs to a different process.")
                            row["phase_samples"].append({"marker":prefix, "receipt":receipt,
                                "sample_elapsed_seconds":time.monotonic()-started,
                                "sample_cpu_seconds":used,
                                "sample_rss_bytes":sampled[0] if sampled else None})
                            observed_markers.add(index)
                    if crash_marker:
                        lines = [s for s in log.read_text(errors="replace").splitlines(keepends=True)
                                 if s.endswith("\n") and s.startswith(crash_marker + " ")]
                        if lines:
                            if len(lines) != 1: raise RuntimeError("Ambiguous crash boundary.")
                            row["boundary"] = json.loads(lines[0].split(" ", 1)[1])
                            if int(row["boundary"].get("pid", -1)) != process.pid:
                                raise RuntimeError("Crash marker belongs to a different engine process.")
                            process.kill()
                            process.wait(timeout=15)
                            row["forced_termination"] = True
                            break
                    if time.monotonic() - started > timeout:
                        raise TimeoutError(f"{label} exceeded {timeout} seconds")
                    time.sleep(0.02)
                row.update(exit_code=process.returncode, sampled_peak_rss_bytes=peak, os_peak_rss_bytes=os_peak,
                           sampled_cpu_seconds=cpu, elapsed_seconds=time.monotonic()-started)
            text = log.read_text(errors="replace")
            if ERRORS.search(text):
                errors = [line[:400] for line in text.splitlines() if ERRORS.search(line)]
                raise RuntimeError(f"Engine/script error in {label}: " + " | ".join(errors[:3]) + f"; see {log}")
            if crash_marker:
                if not row.get("forced_termination") or process.returncode == 0:
                    raise RuntimeError("Expected actual abrupt termination did not occur.")
            elif process.returncode != 0:
                raise RuntimeError("Nonzero engine exit; see " + str(log))
            if marker: row["completion"] = completion(text, marker)
            if peak <= 0: raise RuntimeError("No real engine memory sample was collected.")
            row["status"] = "passed"
            print("PASS", label, "RSS MiB", round(os_peak/1048576, 2), flush=True)
            return row
        except Exception as error:
            row.update(status="failed", error=str(error))
            raise
        finally:
            if process is not None and process.poll() is None:
                process.kill(); process.wait(timeout=15)
            row["elapsed_seconds"] = time.monotonic()-started
            write(self.output / "results.json", self.results)

    def workbench(self, label: str, mode: str, workers: int, phase: str = "") -> None:
        folder = self.output / f"workbench-w{workers}"
        args = [f"--persistent-profile={folder / 'profile'}", f"--persistent-evidence={folder}",
                f"--persistent-test-mode={mode}", f"--persistent-test-workers={workers}", "--persistent-start-paused"]
        if not self.args.headless: args.append("--persistent-require-graphics")
        if phase: args.append("--persistent-crash-phase=" + phase)
        row = self.run(label, self.command("test_persistent_areas_workbench.gd", args, not self.args.headless),
                       marker="" if phase else "PERSISTENT_AREAS_WORKBENCH",
                       crash_marker="GEN006_TRANSITION_CRASH_READY" if phase else "", timeout=420)
        files = [{"name":path.name, "bytes":path.stat().st_size}
                 for path in sorted((folder / "profile").iterdir()) if path.is_file()]
        row["profile_disk"] = {"file_count":len(files), "bytes":sum(item["bytes"] for item in files),
                               "files":files, "journal":"No journal; immutable checkpoints and current/previous manifests"}
        if not phase:
            receipt = json.loads((folder / f"workbench-{mode}.json").read_text())
            if receipt.get("failures") != [] or receipt.get("process_id") != row["pid"] \
                    or receipt.get("graphical") != (not self.args.headless):
                raise RuntimeError("Workbench receipt differs from the measured process.")
            self.report["workbench"][label] = receipt
            # Reopen is repeated after crashes: retain each original receipt.
            write(self.output / (label + ".json"), receipt)

    def additional_cases(self) -> None:
        """An isolated successor may extend, never replace, the donor gates."""

    def execute(self) -> dict:
        try:
            self.run("import", [str(self.engine), "--headless", "--path", str(self.project), "--editor", "--import", "--quit"], timeout=120)
            if not self.record_custody("after-import"):
                raise RuntimeError("Source or executed binary changed during import; see source-custody.json.")
            for label, script, marker in UNIT_CASES:
                arguments = (["--persistent-start-paused",
                              f"--persistent-profile={self.output / 'owner-timeout' / 'profile'}",
                              f"--persistent-evidence={self.output / 'owner-timeout'}"]
                             if label == "owner-timeout" else [])
                self.run(label, self.command(script, arguments), marker=marker)
            self.run("ordinary-workbench-launcher",
                     self.command("test_persistent_areas_ordinary_launcher.gd", ["--workbench"], not self.args.headless),
                     marker="GEN006_ORDINARY_WORKBENCH")
            recovery = self.output / "storage-recovery"
            command = [sys.executable, str(ROOT / "tools/ci/run_gen006_storage_recovery.py"),
                       "--godot", str(self.engine), "--project", str(self.project), "--output", str(recovery)]
            completed = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=600, env=self.env)
            (self.output / "storage-recovery-runner.log").write_text(completed.stdout, encoding="utf-8")
            proof = json.loads((recovery / "recovery-report.json").read_text())
            if completed.returncode or not proof.get("passed") or proof.get("native_sha256") != self.report["native_sha256"]:
                raise RuntimeError("Independent-process storage recovery failed.")
            if {r["label"] for r in proof["runs"]} != set(STORAGE_LABELS):
                raise RuntimeError("Storage crash/lock/reopen matrix is incomplete.")
            for original in proof["runs"]:
                row = dict(original, label=STORAGE_LABELS[original["label"]], status="passed",
                           log="storage-recovery/" + original["log"])
                self.results.append(row)
            self.report["store_recovery"] = proof
            for workers in (1, 4):
                self.workbench(f"workbench-write-w{workers}", "write", workers)
                self.workbench(f"workbench-reopen-w{workers}", "reopen", workers)
                if workers == 1:
                    for phase in ("source_durable", "candidate_durable"):
                        self.workbench("workbench-crash-"+phase, "crash", workers, phase)
                        self.workbench("workbench-recover-"+phase, "reopen", workers)
            self.additional_cases()
            if not self.record_custody("after-campaign"):
                raise RuntimeError("Source or executed binary changed during the campaign; see source-custody.json.")
            self.report.update(status="passed", completed=True, input_custody="passed")
        except Exception as error:
            self.report.update(status="failed", error=str(error))
            print("FAIL", error, flush=True)
        finally:
            if not self.custody_checks or self.custody_checks[-1]["phase"] != "after-campaign":
                self.record_custody("after-failure")
            write(self.output / "results.json", self.results)
            self.report["files_sha256"] = {p.relative_to(self.output).as_posix():sha(p)
                for p in sorted(self.output.rglob("*")) if p.is_file() and p.suffix in {".json", ".log", ".png"}
                and p.name != "qualification.json"}
            write(self.output / "qualification.json", self.report)
        return self.report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=ROOT / "godot")
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--headless", action="store_true", help="Diagnostic only; cannot qualify graphical publication")
    parser.add_argument("--require-clean-source", action="store_true")
    parser.add_argument("--native-build-ledger", type=Path)
    args = parser.parse_args()
    report = Campaign(args).execute()
    print(json.dumps({"status":report["status"], "evidence":str(args.evidence)}))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
