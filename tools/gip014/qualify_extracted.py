#!/usr/bin/env python3
"""Bound the fixed extracted Windows evaluator self-test and its owned children."""
import argparse
import hashlib
import json
import os
from pathlib import Path

from owned_process import execute, read_log_prefix


# The unchanged SelfTest admits one import (240), authored-lineage (300),
# three campaigns (180 each), portable replay (at most 1200), three memory
# admissions (60 each), and graphical smoke (180). The parent must permit
# every child's full existing allowance, plus hashing/reporting and cleanup.
SELFTEST_CHILD_SECONDS = 240 + 300 + 3 * 180 + 1200 + 3 * 60 + 180
SELFTEST_PARENT_RESERVE_SECONDS = 120
SELFTEST_WALL_SECONDS = SELFTEST_CHILD_SECONDS + SELFTEST_PARENT_RESERVE_SECONDS


MODULE_PROBE = r'''$ErrorActionPreference = 'Stop'
try {
    $command = Get-Command -Name Get-FileHash -CommandType Function,Cmdlet -ErrorAction Stop
    $hash = & $command -LiteralPath $PSCommandPath -Algorithm SHA256 -ErrorAction Stop
    if ($command.ModuleName -ne 'Microsoft.PowerShell.Utility' -or $hash.Hash -notmatch '^[0-9A-Fa-f]{64}$') {
        throw 'Unexpected Get-FileHash module or result'
    }
    [Console]::WriteLine('GOBLIN_POWERSHELL_PROBE_PASS ' + $PSVersionTable.PSVersion.ToString() + ' ' +
        $command.ModuleName + ' ' + $command.CommandType.ToString() + ' ' + $hash.Hash.ToLowerInvariant())
    exit 0
} catch {
    [Console]::WriteLine('GOBLIN_POWERSHELL_PROBE_REFUSED ' + $_.Exception.GetType().FullName)
    exit 3
}
'''


def windows_powershell_environment(environment: dict[str, str]) -> dict[str, str]:
    """Let Windows PowerShell rebuild its own module path, preserving other input.

    PowerShell 7's direct Windows PowerShell launcher adjusts PSModulePath, but
    that adjustment does not cross an intermediate Python process. Microsoft
    documents this exact boundary and recommends dropping only this variable:
    https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_psmodulepath#starting-windows-powershell-from-powershell-7
    Windows environment names are case-insensitive; a copied dict is not.
    """
    return {key: value for key, value in environment.items() if key.upper() != "PSMODULEPATH"}


def probe_powershell(root: Path, log: Path, environment: dict[str, str]) -> dict:
    """Retain bounded inherited/clean diagnostics without recording environment values."""
    log.parent.mkdir(parents=True, exist_ok=True)
    script = log.with_suffix(".powershell-probe.ps1")
    script.write_bytes(MODULE_PROBE.encode("utf-8"))
    digest = hashlib.sha256(script.read_bytes()).hexdigest()
    command = ["powershell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", str(script.resolve())]
    report = {"schema_version": 1, "environment_policy": "remove only case-insensitive PSMODULEPATH from Windows PowerShell child",
              "inherited_module_path_present": any(key.upper() == "PSMODULEPATH" for key in environment),
              "probe_sha256": digest, "attempts": []}
    for label, child_environment in (("inherited", dict(environment)),
                                      ("clean", windows_powershell_environment(environment))):
        child_log = log.with_suffix(".powershell-" + label + ".log")
        process = execute(command, child_environment, child_log, 30, cwd=root, memory_limit_mib=512)
        if process.get("interrupted"):
            report["attempts"].append({"environment": label, "process": process,
                                       "get_file_hash_available": False, "observed_command": None})
            report.update(status="cancelled", operator_cancelled=True)
            break
        markers = [line for line in read_log_prefix(child_log).splitlines()
                   if line.startswith("GOBLIN_POWERSHELL_PROBE_PASS ")]
        fields = markers[0].split() if len(markers) == 1 else []
        available = (process["status"] == "pass" and len(fields) == 5
                     and fields[2] == "Microsoft.PowerShell.Utility"
                     and fields[3] in ("Function", "Cmdlet") and fields[4] == digest)
        observed = {"version": fields[1], "module": fields[2], "command_type": fields[3]} if available else None
        report["attempts"].append({"environment": label, "process": process,
                                   "get_file_hash_available": available, "observed_command": observed})
    if not report.get("operator_cancelled"):
        report["status"] = "pass" if report["attempts"][-1]["get_file_hash_available"] else "powershell_environment_failure"
    log.with_suffix(".powershell-environment.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--log", type=Path, required=True)
    args = parser.parse_args(argv)
    root = args.package.resolve(strict=True)
    if os.name != "nt" or not (root / "Open goblin.ps1").is_file():
        parser.error("Extracted qualification requires the actual Windows package")
    environment = dict(os.environ)
    preflight = probe_powershell(root, args.log, environment)
    if preflight["status"] != "pass":
        print(json.dumps({"status": preflight["status"], "retained_log": str(args.log.with_suffix(".powershell-environment.json"))}))
        return 130 if preflight.get("operator_cancelled") else 2
    command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(root / "Open goblin.ps1"),
               "-Mode", "SelfTest", "-GraphicalSmoke"]
    result = execute(command, windows_powershell_environment(environment), args.log, SELFTEST_WALL_SECONDS,
                     cwd=root, memory_limit_mib=3072)
    result["selftest_envelope"] = {"child_allowance_seconds": SELFTEST_CHILD_SECONDS,
                                   "parent_reserve_seconds": SELFTEST_PARENT_RESERVE_SECONDS,
                                   "wall_limit_seconds": SELFTEST_WALL_SECONDS}
    args.log.with_suffix(".process.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    if result.get("interrupted"):
        print(json.dumps({"status": "cancelled", "operator_cancelled": True, "retained_log": str(args.log)}))
        return 130
    markers = [line for line in read_log_prefix(args.log).splitlines()
               if line.startswith("GOBLIN_PACKAGE_SELFTEST_PASS ")]
    if result["status"] != "pass" or len(markers) != 1:
        print(json.dumps({"status": result["status"], "completion_markers": len(markers), "retained_log": str(args.log)}))
        return 2
    print(markers[0])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
