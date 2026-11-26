#!/usr/bin/env python3
"""Discover the owned Linux application without requiring CONFIG_PROC_CHILDREN.

The fallback is a parent-PID graph inside the current /proc namespace. A name
match is insufficient: every ancestor, start tick and the exact executable are
read again before admission. The existing CPU samples then retain that same
creation identity throughout the observed lifetime.
"""
from __future__ import annotations

from pathlib import Path


def process_identity(pid: int, proc: Path = Path("/proc")) -> dict:
    fields = {}
    for row in (proc / str(pid) / "status").read_text().splitlines():
        key, separator, value = row.partition(":")
        if separator and key in ("Pid", "PPid"):
            if key in fields:
                raise ValueError("Duplicate process identity field")
            fields[key] = int(value.strip())
    prefix, suffix = (proc / str(pid) / "stat").read_text().rsplit(")", 1)
    values = suffix.split()
    if (fields.get("Pid") != pid or int(prefix.split("(", 1)[0]) != pid
            or len(values) < 20 or int(values[1]) != fields.get("PPid")
            or fields["PPid"] < 0 or int(values[19]) < 0):
        raise ValueError("Process status/stat identity changed or is incomplete")
    return {"pid": pid, "parent_pid": fields["PPid"],
            "creation_identity": "linux-start-ticks:" + values[19],
            "start_ticks": int(values[19])}


def discover_application(owner_pid: int, executable: Path, proc: Path = Path("/proc")) -> dict | None:
    if type(owner_pid) is not int or owner_pid <= 0:
        raise ValueError("Invalid owned process PID")
    executable = executable.resolve(strict=True)
    owner = process_identity(owner_pid, proc)
    pending = [(owner, [])]
    seen = set()
    used_status_fallback = False
    while pending:
        current, ancestors = pending.pop()
        pid = current["pid"]
        if pid in seen:
            continue
        seen.add(pid)
        chain = ancestors + [current]
        try:
            if (proc / str(pid) / "exe").resolve(strict=True) == executable:
                # Refuse parent changes, PID reuse and exec races across lookup.
                if any(process_identity(row["pid"], proc) != row for row in chain):
                    continue
                if (proc / str(pid) / "exe").resolve(strict=True) != executable:
                    continue
                return {"schema": "pubpres-owned-application-discovery-v1",
                        "method": "owned_root" if pid == owner_pid else
                                  "status_parent_graph" if used_status_fallback else "task_children",
                        "owner_pid": owner_pid, "pid": pid, "executable": str(executable),
                        "creation_identity": current["creation_identity"], "ancestry": chain}
            children_file = proc / str(pid) / "task" / str(pid) / "children"
            try:
                children = [int(value) for value in children_file.read_text().split()]
            except FileNotFoundError:
                # A missing task/children file is a supported kernel setting.
                # Permission errors are not converted into broader discovery.
                if process_identity(pid, proc) != current:
                    continue
                used_status_fallback = True
                children = []
                for path in proc.iterdir():
                    if not path.name.isdecimal():
                        continue
                    try:
                        candidate = process_identity(int(path.name), proc)
                        if candidate["parent_pid"] == pid:
                            children.append(candidate["pid"])
                    except (OSError, ValueError):
                        continue
            for child in children:
                try:
                    identity = process_identity(child, proc)
                    if identity["parent_pid"] == pid and identity["start_ticks"] >= current["start_ticks"]:
                        pending.append((identity, chain))
                except (OSError, ValueError):
                    continue
        except (OSError, ValueError):
            # Exit/reparent/exec races never create an ownership assertion.
            continue
    return None


def validate_discovery(record: dict, *, owner_pid: int, pid: int,
                       creation_identity: str, executable: Path) -> None:
    if not (isinstance(record, dict) and record.get("schema") == "pubpres-owned-application-discovery-v1"
            and record.get("method") in ("owned_root", "task_children", "status_parent_graph")
            and record.get("owner_pid") == owner_pid and record.get("pid") == pid
            and record.get("creation_identity") == creation_identity
            and record.get("executable") == str(executable.resolve(strict=True))):
        raise ValueError("Actual application discovery differs from process/CPU identity")
    chain = record.get("ancestry")
    if not (isinstance(chain, list) and chain and all(isinstance(row, dict) for row in chain)
            and chain[0].get("pid") == owner_pid
            and chain[-1].get("pid") == pid and chain[-1].get("creation_identity") == creation_identity
            and len({row.get("pid") for row in chain}) == len(chain)):
        raise ValueError("Application ancestry is empty, cyclic or belongs to another owner")
    if (record["method"] == "owned_root") != (pid == owner_pid and len(chain) == 1):
        raise ValueError("Discovery method disagrees with actual root/descendant ownership")
    for index, row in enumerate(chain):
        if not (type(row.get("pid")) is int and row["pid"] > 0
                and type(row.get("parent_pid")) is int and row["parent_pid"] >= 0
                and type(row.get("start_ticks")) is int and row["start_ticks"] >= 0
                and row.get("creation_identity") == "linux-start-ticks:" + str(row["start_ticks"])
                and (index == 0 or row["parent_pid"] == chain[index-1]["pid"]
                     and row["start_ticks"] >= chain[index-1]["start_ticks"])):
            raise ValueError("Application ancestry edge or creation identity differs")
