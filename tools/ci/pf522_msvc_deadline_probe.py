#!/usr/bin/env python3
"""Bounded #522 Windows MSVC failure attribution: unmodified binaries + test-only probe.

Runs original Current worker deadline fixture, with strict unchanged assertions;
the probe is applied only to temporary checkout test files AFTER compiling the
unmodified executable and is NEVER committed as a physics/test source change.
No retries turn a failed required gate into a pass.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

BASE = "81bbd5ff5cf366159e2b8a630609359c13560080"
TEST = "native/tests/test_water_inertial.cpp"
FILTER = "worker activity publication and observer independence"
ORDER = ("baseline", "candidate", "candidate", "baseline")

def git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(root), *args], text=True, timeout=45).strip()

def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def only(source: str, needle: str, replacement: str, scope: str) -> str:
    n=source.count(needle)
    if n!=1:
        raise ValueError(f"Unexpected {scope} occurrence {n}: {needle[:115]!r}")
    return source.replace(needle, replacement)

def instrument(text: str) -> str:
    marker="void current_deadline_activity() {"
    left, sep, rest = text.partition(marker)
    if not sep:
        raise ValueError("Current deadline regression missing")
    body, end, right = rest.partition("\n} // namespace")
    if not end: raise ValueError("Cannot find end of deadline fixture")
    body=only(body,
        "    std::uint32_t participants=0;\n    bool slept=false,reacted=false;",
        """    std::uint32_t participants=0;
    bool slept=false,reacted=false;
    int first_worker_tick=-1, first_sleep_tick=-1, first_reaction_tick=-1;
    std::uint32_t sleep_ticks=0, actual_worker_tick_count=0;
    std::uint64_t max_scheduled=0;""", "predicate initialization")
    body=only(body,
        "        participants=std::max(participants,stats.worker_threads_observed);\n"
        "        slept|=stats.scheduled_cores==0;",
        """        participants=std::max(participants,stats.worker_threads_observed);
        max_scheduled=std::max(max_scheduled,stats.scheduled_cores);
        if (stats.worker_threads_observed > 1U) {
            ++actual_worker_tick_count;
            if (first_worker_tick<0) first_worker_tick=tick;
        }
        if (stats.scheduled_cores == 0U) {
            ++sleep_ticks;
            if (first_sleep_tick<0) first_sleep_tick=tick;
        }
        slept|=stats.scheduled_cores==0;""", "worker/sleep observation")
    body=only(body,
        "            reacted|=actual==Material::Ice;",
        """            if (actual==Material::Ice && first_reaction_tick<0) first_reaction_tick=tick;
            reacted|=actual==Material::Ice;""", "reaction observation")
    body=only(body,
        "    require(participants>1&&slept&&reacted,\n",
        """    std::cerr << "PF522_DEADLINE_PREDICATES"
              << " workers_ok=" << (participants>1)
              << " slept_ok=" << slept
              << " reacted_ok=" << reacted
              << " actual_max_workers=" << participants
              << " worker_tick_count=" << actual_worker_tick_count
              << " first_worker_tick=" << first_worker_tick
              << " quiet_tick_count=" << sleep_ticks
              << " first_quiet_tick=" << first_sleep_tick
              << " first_reaction_tick=" << first_reaction_tick
              << " max_scheduled_cores=" << max_scheduled
              << " checked_ticks=128" << '\\n';
    require(participants>1&&slept&&reacted,
""", "original fail-closed assertion")
    return left+marker+body+end+right

def stage(args: argparse.Namespace) -> None:
    base=Path(args.base).resolve()
    cand=Path(args.candidate).resolve()
    out=Path(args.out).resolve()
    out.mkdir(parents=True,exist_ok=True)
    if git(base, "rev-parse", "HEAD")!=BASE:
        raise RuntimeError("Wrong accepted #405 control source")
    csha=git(cand, "rev-parse", "HEAD")
    if not re.fullmatch(r"[0-9a-f]{40}",csha) or csha==BASE:
        raise RuntimeError("Missing final candidate source")
    details={}
    for role,root in (("baseline",base),("candidate",cand)):
        path=root/TEST
        if git(root,"status","--porcelain","--untracked-files=no"):
            raise RuntimeError("Source checkout dirty before overlay")
        raw=path.read_bytes()
        if b"\r\n" in raw:
            raise RuntimeError("Expected LF source checkout; turn off core.autocrlf")
        text=raw.decode("utf-8")
        probe=instrument(text).encode("utf-8")
        path.write_bytes(probe)
        altered=git(root,"diff","--name-only")
        if altered!=TEST:
            raise RuntimeError("Unexpected changed path in temporary diagnostic checkout: "+altered)
        details[role]={"source_commit":git(root,"rev-parse","HEAD"),
                       "original_test_sha256":sha(raw),
                       "diagnostic_test_sha256":sha(probe),
                       "unchanged_required_predicates":["participants>1","slept","reacted"],
                       "test_only":True}
    if details["baseline"]["original_test_sha256"]!=details["candidate"]["original_test_sha256"]:
        raise RuntimeError("Baseline/current exact test fixture differs")
    if details["baseline"]["diagnostic_test_sha256"]!=details["candidate"]["diagnostic_test_sha256"]:
        raise RuntimeError("Probe differs between sources")
    (out/"instrumentation.json").write_text(json.dumps({
        "schema":"pf522-windows-msvc-current-deadline-probe-v1",
        "scope":"temporary test-only overlay; original test assertions unchanged",
        "original_binary_pass_not_derived_from_probe":True,
        "description":"print each of worker/quiet/reaction, actual max participants, first tick and counts, before original strict require",
        "roles":details,
    },indent=2,sort_keys=True)+"\n")
    print("PF522_MSVC_STRICT_PREDICATE_PROBE_STAGED "+json.dumps(details,sort_keys=True),flush=True)

def run(args: argparse.Namespace) -> None:
    out=Path(args.out).resolve()
    (out/"logs").mkdir(parents=True,exist_ok=True)
    base=Path(args.base).resolve()
    cand=Path(args.candidate).resolve()
    binaries={role:{"original":root/f"build/{role}-original.exe",
                    "probe":root/f"build/{role}-probe.exe"} for role,root in
              (("baseline",base),("candidate",cand))}
    details={}
    for role in ORDER:
        for typ in ("focused","full","diagnostic"):
            repeat=sum(k.startswith(f"{role}-{typ}-") for k in details)
            stem=f"{role}-{typ}-{repeat+1}"
            binary=binaries[role]["probe" if typ=="diagnostic" else "original"]
            if not binary.is_file():raise FileNotFoundError(str(binary))
            command=[str(binary)]+([FILTER] if typ!="full" else [])
            result=subprocess.run(command,capture_output=True,text=True,encoding="utf-8",
                                  errors="replace",timeout=800,check=False,
                                  cwd=binary.parent.parent)
            content=result.stdout+"\n"+result.stderr
            (out/"logs"/f"{stem}.log").write_text(content,encoding="utf-8")
            relevant=[line.strip() for line in content.splitlines()
                      if "PF522_DEADLINE_PREDICATES" in line]
            final=re.findall(r"(?m)^(\d+) tests passed\s*$",content)
            details[stem]={
                "role":role,"type":typ,
                "exe_sha256":sha(binary.read_bytes()),
                "returncode":result.returncode,"pass_summary":final,
                "probe_lines":relevant,
                "required_original_filter":FILTER if typ!="full" else "complete 191/192-test suite",
                "log_sha256":sha(content.encode("utf-8")),
            }
            print("PF522_MSVC_OBSERVED "+json.dumps({ "name":stem,**details[stem]},sort_keys=True),flush=True)
    (out/"executions.json").write_text(json.dumps({
        "schema":"pf522-msvc-bccb-strict-source-execution-v1",
        "actual_order":list(ORDER),"records":details},indent=2,sort_keys=True)+"\n")
    require=[]
    for stem,entry in details.items():
        if entry["returncode"]!=0 or len(entry["pass_summary"])!=1:
            require.append(f"Original strict required test failed or unavailable: {stem}")
        if entry["type"]=="diagnostic":
            if len(entry["probe_lines"])!=1 or not all(k in entry["probe_lines"][0]
                for k in ("workers_ok=1","slept_ok=1","reacted_ok=1",
                          "first_worker_tick=","first_quiet_tick=","first_reaction_tick=")):
                require.append("Separate required predicates not independently verified: "+stem)
    summary={
        "schema":"pf522-msvc-deadline-attribution-v1",
        "status":"PASS" if not require else "HOLD",
        "original_unmodified_source_gate":"PASS" if not require else "NOT_QUALIFIED",
        "failures":require,"original_full_test_suites":4,
        "original_focused_test_runs":4,
        "diagnostic_temporary_probes":4,
        "strict_condition_preserved":"participants>1 && slept && reacted",
        "inference":"Any failures are retained. No retry converts a failed required gate into PASS.",
        "records":details,
    }
    (out/"attribution.json").write_text(json.dumps(summary,indent=2,sort_keys=True)+"\n")
    print("PF522_MSVC_PREDICATE_AND_REQUIRED_GATE "+json.dumps({
        k:v for k,v in summary.items() if k!="records"},sort_keys=True),flush=True)
    if require: raise RuntimeError("Windows strict predicate gate not qualified; see attribution.json")

def main():
    parser=argparse.ArgumentParser()
    group=parser.add_subparsers(dest="action",required=True)
    for cmd in ("stage","run"):
        p=group.add_parser(cmd)
        p.add_argument("--base",required=True)
        p.add_argument("--candidate",required=True)
        p.add_argument("--out",required=True)
    a=parser.parse_args()
    {"stage":stage,"run":run}[a.action](a)
if __name__=="__main__":
    main()
