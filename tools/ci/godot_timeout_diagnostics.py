"""Bounded, best-effort live diagnostics; never substitutes for the test oracle."""

import json
from pathlib import Path
import shutil
import subprocess
import sys


def snapshot(pid: int, output: Path) -> None:
    """Called before killing the child (Windows pid may be the console wrapper)."""
    output.mkdir(parents=True, exist_ok=True)
    commands = []
    if sys.platform == "win32":
        # Include the wrapper's engine child. Threads include wait reasons and
        # CPU times even when no optional debugger is installed on the host.
        script = (
            f"$targetId = {pid}; "
            "$items = Get-CimInstance Win32_Process; "
            "$items | Where-Object { $_.ProcessId -eq $targetId -or $_.ParentProcessId -eq $targetId } | "
            "ForEach-Object { $_ | Select-Object ProcessId,ParentProcessId,Name,CommandLine | Format-List; "
            "Get-Process -Id $_.ProcessId | Select-Object Id,CPU,StartTime,Responding | Format-List; "
            "(Get-Process -Id $_.ProcessId).Threads | "
            "Select-Object Id,ThreadState,WaitReason,TotalProcessorTime | Format-Table -AutoSize }"
        )
        commands.append(("process", ["powershell.exe", "-NoProfile", "-Command", script]))
        # DbgHelp is supplied by Windows. A normal minidump retains native
        # thread contexts/stacks without needing an optional SDK installation.
        dump_script = r'''Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class GodotDump {
  [DllImport("Dbghelp.dll", SetLastError=true)]
  public static extern bool MiniDumpWriteDump(IntPtr process, uint pid,
    SafeFileHandle file, uint flags, IntPtr exception, IntPtr user, IntPtr callback);
}
"@
'''
        dump_script += "$dumpRoot = $args[0]; " + script[:script.index("$items |")]
        dump_script += ("$items | Where-Object { $_.ProcessId -eq $targetId -or $_.ParentProcessId -eq $targetId } | "
                        "ForEach-Object { $p = Get-Process -Id $_.ProcessId; "
                        "$file = [System.IO.File]::Create((Join-Path $dumpRoot ($p.Id.ToString() + '.dmp'))); "
                        "try { $ok = [GodotDump]::MiniDumpWriteDump($p.Handle, $p.Id, $file.SafeFileHandle, 0, "
                        "[IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero); "
                        "Write-Output ('pid=' + $p.Id + ' dump=' + $ok + ' error=' + [Runtime.InteropServices.Marshal]::GetLastWin32Error()) "
                        "} finally { $file.Dispose() } }")
        dump_file = output / "capture.ps1"
        # A script file also preserves the exact diagnostic command for replay.
        dump_file.write_text(dump_script, encoding="utf-8")
        commands.append(("minidump", ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(dump_file.resolve()), str(output.resolve())]))

    else:
        commands.append(("process", ["ps", "-L", "-p", str(pid), "-o",
                                      "pid,ppid,tid,stat,pcpu,time,wchan:40,comm"]))
        proc = Path(f"/proc/{pid}")
        for task in (proc / "task").glob("*"):
            for name in ("wchan", "stack", "status"):
                try:
                    (output / f"thread-{task.name}-{name}.txt").write_text(
                        (task / name).read_text(), encoding="utf-8")
                except OSError:
                    pass
        if shutil.which("gdb"):
            commands.append(("stacks", ["gdb", "--batch", "-nx", "-p", str(pid),
                                         "-ex", "set pagination off", "-ex", "thread apply all bt",
                                         "-ex", "detach"]))
    outcomes = {"pid": pid, "platform": sys.platform, "commands": []}
    for name, command in commands:
        try:
            with (output / (name + ".txt")).open("w", encoding="utf-8") as log:
                result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=8)
            outcomes["commands"].append({"command": command, "returncode": result.returncode})
        except (OSError, subprocess.TimeoutExpired) as error:
            outcomes["commands"].append({"command": command, "error": str(error)})
    outcomes["stack_capture"] = "gdb attempted" if any(n == "stacks" for n, _ in commands) else "Windows minidump attempted" if sys.platform == "win32" else "debugger unavailable; process/thread snapshot only"
    (output / "snapshot.json").write_text(json.dumps(outcomes, indent=2) + "\n", encoding="utf-8")


def last_progress(output: str) -> dict | None:
    for line in reversed(output.splitlines()):
        if line.startswith("CYBERSAND_PROGRESS "):
            try:
                marker = json.loads(line.removeprefix("CYBERSAND_PROGRESS "))
                if isinstance(marker, dict) and isinstance(marker.get("phase"), str):
                    return marker
            except ValueError:
                continue
    return None
