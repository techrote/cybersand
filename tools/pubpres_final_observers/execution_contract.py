#!/usr/bin/env python3
"""Admit one explicit CPU-accounting extension of the frozen process runner."""
from __future__ import annotations

import ast
import hashlib
from pathlib import Path

FROZEN_RUNNER_SHA256 = "8cc11d567101c518d13776781aa0e644546b6c69b1535e9669a103fdf05dfd84"
ROOT = Path(__file__).resolve().parents[2]


def function_source(source: str, name: str) -> str:
    rows = source.splitlines(keepends=True)
    functions = [node for node in ast.parse(source).body if isinstance(node, ast.FunctionDef) and node.name == name]
    if len(functions) != 1:
        raise ValueError("Expected one process execution function")
    node = functions[0]
    return "".join(rows[node.lineno-1:node.end_lineno]).rstrip() + "\n"


def replace_once(text: str, old: str, new: str) -> str:
    if text.count(old) != 1:
        raise ValueError("Frozen execution boundary differs: " + old[:70])
    return text.replace(old, new)


def expected_execution(frozen: bytes) -> str:
    if hashlib.sha256(frozen).hexdigest() != FROZEN_RUNNER_SHA256:
        raise ValueError("Frozen process runner bytes changed")
    code = function_source(frozen.decode("utf-8"), "execute")
    code = replace_once(code, "def execute(", "def execute_with_resources(")
    code = replace_once(code, "    folder.mkdir(parents=True, exist_ok=True)",
                        "    verify_execution_derivation()\n    resource_samples, resource_errors, resource_dropped = [], [], 0\n    application_discovery = None\n    folder.mkdir(parents=True, exist_ok=True)")
    code = replace_once(code, '''                            for pid in descendant_pids(process.pid):
                                executable = Path(f"/proc/{pid}/exe").resolve()
                                if executable == engine:
                                    child_pid = pid
                                    break''', '''                            application_discovery = discover_application(process.pid, engine)
                            if application_discovery is not None:
                                child_pid = application_discovery["pid"]''')
    original = "                            samples.append(memory_sample(child_pid, (time.monotonic() - clock) * 1000))"
    replacement = original + '''
                            if len(resource_samples) >= 4096:
                                resource_dropped += 1
                            else:
                                try:
                                    resource_samples.append(process_cpu_sample(child_pid, (time.monotonic() - clock) * 1000))
                                except (OSError, ValueError) as error:
                                    if len(resource_errors) < 4096:
                                        resource_errors.append({"elapsed_ms": (time.monotonic() - clock) * 1000, "error": str(error),
                                                                "sampler_elapsed_usec": getattr(error,"sampler_elapsed_usec",None)})'''
    code = replace_once(code, original, replacement)
    original = '    write_json(folder / "process.json", result)'
    replacement = '''    resource_summary = summarize_cpu(resource_samples, expected_pid=child_pid, errors=resource_errors, dropped=resource_dropped)
    result["application_discovery"] = application_discovery
    if os.name != "nt" and resource_summary["complete"]:
        validate_discovery(application_discovery, owner_pid=result["wrapper_pid"], pid=child_pid,
                           creation_identity=resource_summary["creation_identity"], executable=engine)
    resource_trace = {"schema": "pubpres-final-process-cpu-v1", "source_commit": source_sha,
                      "frozen_runner_sha256": FROZEN_RUNNER_SHA256,
                      "runner_sha256": digest(Path(__file__)), "summary": resource_summary,
                      "samples": resource_samples, "errors": resource_errors}
    write_json(folder / "process-cpu.json", resource_trace)
    result["process_cpu"] = {"path": str(folder / "process-cpu.json"),
                             "sha256": digest(folder / "process-cpu.json"), "summary": resource_summary}
''' + original
    code = replace_once(code, original, replacement)
    return code


def verify_execution_derivation(root: Path = ROOT) -> dict:
    base = root / "tools/pubpres_playability/run_campaign.py"
    current = root / "tools/pubpres_final_observers/execute_with_resources.py"
    if function_source(current.read_text(), "execute_with_resources") != expected_execution(base.read_bytes()):
        raise ValueError("CPU observer changed an undeclared ownership, timeout, cancellation, sampling or process gate")
    return {"frozen_runner_sha256": FROZEN_RUNNER_SHA256,
            "runner_sha256": hashlib.sha256(current.read_bytes()).hexdigest(),
            "process_discovery_sha256": hashlib.sha256((root / "tools/pubpres_final_observers/process_discovery.py").read_bytes()).hexdigest(),
            "scope": "Additive same-iteration CPU reads, bounded sidecar and exact executable/ancestry/creation discovery when Linux task/children is unavailable; all frozen process lifetime and completion gates remain exact."}
