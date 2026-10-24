"""Bounded, best-effort live diagnostics; never substitutes for the test oracle."""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile

COMMAND_SECONDS = 12.0
STDOUT_BYTES = 64000
STDERR_BYTES = 16000


def stop_process_tree(process: subprocess.Popen, *, wait_seconds: float = 2.0) -> None:
    """Bound cleanup of an owned diagnostic command, including pipe inheritors."""
    if process.poll() is not None:
        return
    if sys.platform == "win32":
        try:
            killer = subprocess.Popen(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            try:
                killer.wait(timeout=wait_seconds)
            except subprocess.TimeoutExpired:
                killer.kill()
                try:
                    killer.wait(timeout=wait_seconds)
                except subprocess.TimeoutExpired:
                    pass
        except OSError:
            pass
    else:
        try:
            os.killpg(os.getpgid(process.pid), signal.SIGKILL)
        except ProcessLookupError:
            pass
    if process.poll() is None:
        process.kill()
    try:
        process.wait(timeout=wait_seconds)
    except subprocess.TimeoutExpired:
        process.kill()


def _tail(handle, limit: int) -> tuple[bytes, bool]:
    handle.seek(0, os.SEEK_END)
    size = handle.tell()
    handle.seek(max(0, size - limit))
    return handle.read(limit), size > limit


def _command(name: str, command: list[str], output: Path) -> dict:
    """No PIPE/communicate cleanup can wait indefinitely on a descendant."""
    result = {"name": name, "command": command, "timeout_seconds": COMMAND_SECONDS}
    text = f"$ {command!r}\n"
    try:
        with tempfile.TemporaryFile() as stdout, tempfile.TemporaryFile() as stderr:
            options = ({"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP}
                       if sys.platform == "win32" else {"start_new_session": True})
            process = subprocess.Popen(command, stdout=stdout, stderr=stderr, **options)
            try:
                (output / (name + ".command.json")).write_text(json.dumps({
                    "pid": process.pid, "command": command, "active": True,
                }) + "\n", encoding="utf-8")
                try:
                    process.wait(timeout=COMMAND_SECONDS)
                    result["returncode"] = process.returncode
                    text += f"exit={process.returncode}\n"
                except subprocess.TimeoutExpired:
                    result["error"] = f"TimeoutExpired after {COMMAND_SECONDS}s"
                    text += "SNAPSHOT UNAVAILABLE: " + result["error"] + "\n"
            finally:
                if process.poll() is None:
                    stop_process_tree(process)
                try:
                    (output / (name + ".command.json")).write_text(json.dumps({
                        "pid": process.pid, "command": command, "active": False,
                        "returncode": process.poll(),
                    }) + "\n", encoding="utf-8")
                except OSError:
                    pass
            out, out_capped = _tail(stdout, STDOUT_BYTES)
            err, err_capped = _tail(stderr, STDERR_BYTES)
            if out_capped or err_capped:
                text += "[snapshot output capped at 64000 stdout / 16000 stderr bytes]\n"
            text += (out + err).decode("utf-8", errors="replace")
    except OSError as error:
        result["error"] = f"{type(error).__name__}: {error}"
        text += "SNAPSHOT UNAVAILABLE: " + result["error"] + "\n"
    (output / (name + ".txt")).write_text(text, encoding="utf-8")
    return result


def _windows_tree(pid: int) -> str:
    return (f"$rootId={pid}; $procs=Get-CimInstance Win32_Process; $ids=@($rootId); "
            "for($i=0;$i -lt 5;$i++){"
            "$ids=@($ids + @($procs | Where-Object { $ids -contains $_.ParentProcessId }"
            " | ForEach-Object ProcessId)) | Sort-Object -Unique }; ")


def snapshot(pid: int, output: Path) -> None:
    """Capture an owned live engine tree; the monitor imposes a total outer bound."""
    output.mkdir(parents=True, exist_ok=True)
    commands = []
    outcomes = {"pid": pid, "platform": sys.platform, "commands": [], "proc_errors": []}
    if sys.platform == "win32":
        script = _windows_tree(pid) + (
            "$procs | Where-Object { $ids -contains $_.ProcessId }"
            " | Format-List ProcessId,ParentProcessId,Name,CommandLine; "
            "foreach($id in $ids){ $p=Get-Process -Id $id -ErrorAction SilentlyContinue; "
            "if($null -eq $p){continue}; "
            "$p | Select-Object Id,ProcessName,CPU,StartTime | Format-List; "
            "try { foreach($thread in $p.Threads){ $wait='not waiting'; "
            "if($thread.ThreadState -eq [System.Diagnostics.ThreadState]::Wait){ "
            "try {$wait=$thread.WaitReason} catch {$wait='unavailable: '+$_.Exception.Message} }; "
            "[pscustomobject]@{ProcessId=$id;ThreadId=$thread.Id;State=$thread.ThreadState;"
            "WaitReason=$wait;CPU=$thread.TotalProcessorTime} | Format-List "
            "} } catch { Write-Output ('THREAD SNAPSHOT UNAVAILABLE: '+$_.Exception.Message) } }"
        )
        commands.append(("process", ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script]))
        # Windows supplies DbgHelp. A normal minidump retains native contexts
        # without requiring an installed SDK or changing engine execution.
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
        dump_script += "$dumpRoot=$args[0]; " + _windows_tree(pid)
        dump_script += (
            "foreach($id in $ids){ $p=Get-Process -Id $id -ErrorAction SilentlyContinue; "
            "if($null -eq $p){continue}; "
            "$file=[System.IO.File]::Create((Join-Path $dumpRoot ($id.ToString()+'.dmp'))); "
            "try { $ok=[GodotDump]::MiniDumpWriteDump($p.Handle,$id,$file.SafeFileHandle,0,"
            "[IntPtr]::Zero,[IntPtr]::Zero,[IntPtr]::Zero); "
            "if($ok){ Write-Output ('pid='+$id+' dump=True') } "
            "else { Write-Output ('pid='+$id+' dump=False error='+[Runtime.InteropServices.Marshal]::GetLastWin32Error()) } "
            "} catch { Write-Output ('MINIDUMP UNAVAILABLE pid='+$id+': '+$_.Exception.Message) } "
            "finally { $file.Dispose() } }"
        )
        dump_file = output / "capture.ps1"
        dump_file.write_text(dump_script, encoding="utf-8")
        commands.append(("minidump", ["powershell.exe", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
                                      "-File", str(dump_file.resolve()), str(output.resolve())]))
        outcomes["stack_capture"] = "Windows minidump attempted; inspect minidump.txt for per-process success/refusal"
    else:
        commands.extend([
            ("process-tree", ["ps", "--forest", "-s", str(pid), "-o", "pid,ppid,pgid,sid,stat,etime,wchan:32,args"]),
            ("process", ["ps", "-T", "-p", str(pid), "-o", "pid,tid,stat,etime,wchan:32,comm"]),
        ])
        tasks = sorted(Path(f"/proc/{pid}/task").glob("*"))
        if not tasks:
            outcomes["proc_errors"].append(f"No accessible /proc/{pid}/task entries")
        if len(tasks) > 512:
            outcomes["proc_errors"].append("Task enumeration capped at 512 threads")
        for task in tasks[:512]:
            for name in ("wchan", "stack", "status"):
                try:
                    with (task / name).open("rb") as handle:
                        value = handle.read(64001)
                    if len(value) > 64000:
                        outcomes["proc_errors"].append(f"{task}/{name}: capped at 64000 bytes")
                    (output / f"thread-{task.name}-{name}.txt").write_bytes(value[:64000])
                except OSError as error:
                    outcomes["proc_errors"].append(f"{task}/{name}: {type(error).__name__}: {error}")
        if shutil.which("gdb"):
            debugger = ["gdb", "-q", "-n", "-batch", "-p", str(pid), "-ex", "set pagination off",
                        "-ex", "thread apply all bt 12", "-ex", "detach"]
            if shutil.which("sudo"):
                debugger = ["sudo", "-n", *debugger]
            commands.append(("stacks", debugger))
            outcomes["stack_capture"] = "gdb attempted; inspect stacks.txt for frames or debugger/ptrace refusal"
        else:
            outcomes["stack_capture"] = "gdb not installed; process/thread wait channels and explicit proc errors retained"
    for name, command in commands:
        outcomes["commands"].append(_command(name, command, output))
    (output / "snapshot.json").write_text(json.dumps(outcomes, indent=2) + "\n", encoding="utf-8")


def last_progress(output: str) -> dict | None:
    """Read either retained marker protocol without inventing a phase or tick."""
    for line in reversed(output.splitlines()):
        if line.startswith("REGRESSION_PROGRESS "):
            marker = dict(re.findall(r"(\w+)=([^\s]+)", line))
            if "phase" in marker:
                for key in ("tick", "steps", "elapsed_ms"):
                    if marker.get(key, "").isdigit():
                        marker[key] = int(marker[key])
                return marker
        if line.startswith("CYBERSAND_PROGRESS "):
            try:
                marker = json.loads(line.removeprefix("CYBERSAND_PROGRESS "))
                if isinstance(marker, dict) and isinstance(marker.get("phase"), str):
                    return marker
            except ValueError:
                continue
    return None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pid", required=True, type=int)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    snapshot(args.pid, args.output)


if __name__ == "__main__":
    main()
