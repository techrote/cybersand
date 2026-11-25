#!/usr/bin/env python3
"""Source-bound iterative tests; never a substitute for final qualification."""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import subprocess
import time
from pathlib import Path
from qualify_ambient import (source_identity, engine_identity, GODOT_VERSION,
                            verify_runtime_identity, project_identity,
                            execute, case_environment, execution_policy,
                            write_json, sha, ROOT, require, git)

OWN = ("tools/qualify_ambient_iteration.py",
       ".github/workflows/ambient-002-smoke.yml",
       "tools/fixtures/ambient-002-smoke-request.json")

def identity():
    result = source_identity()
    for path in OWN:
        data = (ROOT/path).read_bytes().replace(b"\r\n", b"\n")
        require(git("show", "HEAD:"+path).replace(b"\r\n", b"\n") == data,
                "Uncommitted iteration input: "+path)
        result["source_inputs_sha256"][path] = hashlib.sha256(data).hexdigest()
    return result

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    report = {"kind":"ambient-002-source-iteration", "status":"running",
              "complete_qualification":False, "cases":[]}
    started = time.monotonic()
    try:
        before = identity()
        report.update(before)
        runtime = verify_runtime_identity()
        report["runtime"] = runtime
        project = ROOT/"godot"
        report["project_inputs_sha256"] = project_identity(project, before, runtime)
        binary = args.godot.resolve(strict=True)
        report["engine"] = engine_identity(binary)
        require(subprocess.check_output([str(binary),"--version"],text=True,timeout=60).strip() == GODOT_VERSION, "Engine version mismatch")
        request = json.loads((ROOT/OWN[2]).read_text())
        cases = request["cases"]
        require(isinstance(cases,list) and 0 < len(cases) <= 40, "Invalid finite case list")
        names = [row["script"] for row in cases]
        require(len(names) == len(set(names)), "Duplicate test scripts")
        import_result = execute([str(binary),"--headless","--path",str(project),"--editor","--quit"],
            output/"import",case_environment(output/"userdata/import"),
            execution_policy.watchdog_seconds("godot_import_seconds"))
        report["import"] = import_result
        require(import_result["status"] == "passed","Godot import failed; read retained process.log")
        for row in cases:
            script = row["script"]
            require(re.fullmatch(r"test_[a-z0-9_]+",script) is not None, "Invalid test path")
            environment = case_environment(output/"userdata"/script)
            environment["CYBERSAND_SOURCE_REVISION"] = before["source_commit"]
            if row.get("report_env"):
                require(re.fullmatch(r"CYBERSAND_[A-Z0-9_]+",row["report_env"]) is not None,"Invalid report variable")
                environment[row["report_env"]] = str(output/script/"report.json")
            command = [str(binary),"--headless","--path",str(project),
                       "--script","res://tests/"+script+".gd","--","--ci",*row.get("arguments",[])]
            print("ITERATION "+script,flush=True)
            result = execute(command,output/script,environment,execution_policy.complex_process_seconds())
            result["script"] = script
            report["cases"].append(result)
            log = (output/script/"process.log").read_text(errors="replace")
            print(log[-16000:],flush=True)
            require(result["status"] == "passed","Failed actual case: "+script)
            terminal = row.get("terminal","")
            pattern = row.get("terminal_pattern","")
            require(bool(terminal) != bool(pattern),"Exactly one completed-test terminal contract is required")
            if pattern:
                require(pattern.startswith("^") and pattern.endswith("$"),"Text completion must match a complete line")
                matches = re.findall(pattern,log,flags=re.MULTILINE)
                require(len(matches) == 1 and isinstance(matches[0],tuple) and len(matches[0]) == 2,
                        "Missing/repeated/malformed text completion: "+script)
                completed = dict(zip(("checks","failures"),map(int,matches[0])))
            else:
                matches = [line[len(terminal)+1:] for line in log.splitlines() if line.startswith(terminal+" ")]
                require(len(matches) == 1,"Missing/repeated completion: "+script)
                completed = json.loads(matches[0])
            require(type(completed.get("checks")) is int and completed["checks"] > 0 and completed.get("failures") in (0,[]),"Incomplete/failing assertions: "+script)
            result["completion"] = completed
            result["log_sha256"] = sha(output/script/"process.log")
            write_json(output/"iteration.json",report)
        require(identity() == before,"Source changed during execution")
        require(project_identity(project,before,runtime) == report["project_inputs_sha256"],"Project changed during execution")
        require(verify_runtime_identity() == runtime,"Native runtime changed during execution")
        report["status"] = "passed"
    except Exception as error:
        report["status"] = "failed"
        report["error"] = str(error)
        print(str(error),flush=True)
        if (output/"import/process.log").is_file():
            print((output/"import/process.log").read_text(errors="replace")[-20000:],flush=True)
    finally:
        report["elapsed_seconds"] = round(time.monotonic()-started,3)
        write_json(output/"iteration.json",report)
    return 0 if report["status"] == "passed" else 1

if __name__ == "__main__":
    raise SystemExit(main())
