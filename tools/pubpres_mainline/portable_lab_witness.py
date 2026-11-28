#!/usr/bin/env python3
"""Run the unchanged packaged Materials Lab CLI with pre-execution egress guards."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import tempfile
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT / "tools/pubpres_mainline"), str(ROOT / "tools/ci"),
                str(ROOT / "tools"), str(ROOT / "tools/material_catalogue")]

import portable_authoring

lab = portable_authoring.lab


def generated_world_executable(command, directory: Path, temp_root: Path) -> Path | None:
    if not command:
        return None
    executable = Path(str(command[0]))
    if not executable.is_absolute():
        executable = directory / executable
    if executable.suffix.casefold() != ".exe" or not portable_authoring._under(executable, temp_root):
        return None
    executable = executable.resolve(strict=True)
    selected_compiler = os.environ.get("CYBERSAND_LAB_CXX", "")
    if selected_compiler and os.path.normcase(str(executable)) == os.path.normcase(
            str(Path(selected_compiler).resolve(strict=False))):
        return None
    working = Path(directory).resolve(strict=True)
    world_root = working.parent
    if (not world_root.name.casefold().startswith("cybersand-lab-world-")
            or working.name.casefold() not in ("reference", "candidate")
            or world_root.parent.resolve(strict=True) != temp_root.resolve(strict=True)):
        return None
    if not portable_authoring._under(executable, world_root):
        return None
    if executable.name.casefold() != "lab-world-probe.exe" or executable != working / "lab-world-probe.exe":
        raise RuntimeError("Unexpected executable launch from the registered Materials Lab World stage: " + str(executable))
    return executable


def run(args) -> int:
    registry = args.firewall_registry.resolve()
    scratch = registry.parent
    request, response = args.request.resolve(), args.response.resolve()
    temp_root = Path(tempfile.gettempdir()).resolve()
    original_run = lab._run

    def guarded_run(command, directory, timeout, *, check=True):
        executable = generated_world_executable(command, Path(directory), temp_root)
        if executable is not None:
            rows = json.loads(registry.read_bytes())
            if type(rows) is not list:
                raise RuntimeError("Generated executable firewall registry is not a JSON array")
            role = "reference" if len(rows) == 0 else "candidate" if len(rows) == 1 else None
            if role is None:
                raise RuntimeError("More than two generated World probes were submitted for execution")
            name = (portable_authoring.RULE_PREFIX + args.run_id + "-world-" + str(len(rows)))
            portable_authoring._powershell_block(name, executable)
            rows.append({"name": name, "executable": str(executable), "role": role,
                         "working_directory": str(Path(directory).resolve()),
                         "bytes": executable.stat().st_size, "sha256": portable_authoring.sha(executable)})
            portable_authoring.write_json(registry, rows)
        return original_run(command, directory, timeout, check=check)

    lab._run = guarded_run
    try:
        return lab.main(["--request", str(request), "--response", str(response)])
    finally:
        lab._run = original_run


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--request", required=True, type=Path)
    parser.add_argument("--response", required=True, type=Path)
    parser.add_argument("--firewall-registry", required=True, type=Path)
    parser.add_argument("--run-id", required=True)
    return run(parser.parse_args())


if __name__ == "__main__":
    raise SystemExit(main())
