#!/usr/bin/env python3
"""Read retained hosted causal bytes against their exact Git source; no execution.

Run with --root pointing to a repository retaining fe24da6f. This is artifact
readback, not local Windows execution or proof of a historical crash's cause.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

HEAD = "fe24da6fc790a38760de28a0ef08c3f5904cd3a6"
TREE = "9c14659bc6a57c1f1e28b71e10c504b184078d63"
ARCHIVE_SHA256 = "bcce7d7a60984734573eb8244b3093b6d5da8dc71eccde65e9be0fec01117405"


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def pairs(items):
    result = {}
    for key, value in items:
        require(key not in result, "duplicate JSON key: " + key)
        result[key] = value
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    args = parser.parse_args()
    def git(*arguments):
        return subprocess.check_output(["git", "-C", str(args.root), *arguments])
    def blob(path):
        return git("show", HEAD + ":" + path)
    require(git("rev-parse", HEAD + "^{tree}").decode().strip() == TREE, "exact source tree")
    archive = Path(__file__).parent / "hosted-fe24/fe24-causal-windows.zip"
    data = archive.read_bytes()
    require(len(data) == 13713 and sha(data) == ARCHIVE_SHA256, "original GitHub archive identity")
    with zipfile.ZipFile(archive) as z:
        require(z.testzip() is None, "archive CRC")
        require(len(set(z.namelist())) == len(z.namelist()), "duplicate archive member")
        def record(name):
            return json.loads(z.read(name), object_pairs_hook=pairs)
        result = record("windows-causal-gate.json")
        admission = record("source-admission.json")
        materialization = record("materialization/receipt.json")
        performance = record("performance.jsonl")
        process = result["process"]
        require(result["source_commit"] == HEAD and result["source_tree"] == TREE, "result source")
        require(result["status"] == "passed" and result["completed"] is True and
                result["actual_windows"] is True and not result["errors"], "completed actual Windows")
        require(result["fixture_completed_naturally"] is True and result["process_exit_unsigned"] == 0 and
                result["wrapper_exit"] == 0 and result["timeout"] is False, "natural process and wrapper success")
        require(process["status"] == "passed" and process["natural_completion"] is True and
                process["returncode"] == 0 and not process["skip_messages"] and
                not process["launch_error"] and not process["capture_error"], "process outcome")
        log = z.read(process["log"])
        require(sha(log) == process["log_sha256"], "raw process log identity")
        text = log.decode()
        require(text.count("LIQUID_DESKTOP_DEFAULT_HOST: 86 assertions; 0 failures") == 1,
                "actual assertion footer")
        require(not re.search(r"^(?:SCRIPT ERROR:|ERROR:)|Parse Error|Compile Error", text, re.M),
                "engine error in log")
        require(result["assertion_footer"] == {"assertions": 86, "failures": 0}, "footer receipt")
        require(z.read("wrapper-exit.txt").decode().strip() == "0", "wrapper exit witness")
        require(admission == result["source_admission"] and
                admission["schema"] == "in-tools-current-main-admission-result-v4" and
                admission["status"] == "admitted", "source admission binding")
        require(admission["source_commit"] == HEAD and admission["source_tree"] == TREE and
                admission["adopted_main"] == "67c1413a2a84077b47fa542cf91d2bd6ba5520ee", "adopted source")
        require(admission["runtime_qualified"] is False and admission["gameplay_qualified"] is False and
                admission["planned_execution"] == "NOT_RUN", "source-only qualification limits")
        require(len(admission["authority"]) == admission["authority_count"] == 13, "authority count")
        for item in admission["authority"] + [admission["causal_fixture"]]:
            require(git("rev-parse", HEAD + ":" + item["path"]).decode().strip() == item["git_blob"],
                    "authority Git blob: " + item["path"])
        controls = z.read("source-admission-tests.log").decode()
        require(re.search(r"Ran 21 tests", controls) and re.search(r"^OK\s*$", controls, re.M),
                "21 adversarial controls")
        identity = result["runtime_identity"]
        require(len(identity["native_source_inputs"]) == 105, "native input count")
        for path, digest in identity["native_source_inputs"].items():
            require(sha(blob(path)) == digest, "native source bytes: " + path)
        for kind in ("cybersand_runtime", "rapier_runtime"):
            item = identity[kind]
            pointer = blob(item["path"]).decode()
            require(re.search(r"^oid sha256:" + item["sha256"] + "$", pointer, re.M) and
                    re.search(r"^size " + str(item["size"]) + "$", pointer, re.M), "retained runtime pointer")
            actual = next(x for x in materialization["objects"] if x["path"] == item["path"])
            require(actual["actual_sha256"] == actual["sha256"] == item["sha256"] and
                    actual["actual_bytes"] == actual["bytes"] == item["size"], "materialized library identity")
        provenance = identity["runtime_provenance"]
        require(sha(blob(provenance["path"])) == provenance["sha256"], "runtime provenance bytes")
        for command in materialization["commands"]:
            raw = z.read("materialization/" + command["log"])
            require(sha(raw) == command["log_sha256"] and len(raw) == command["log_bytes"], "acquisition log")
            require(command["returncode"] == 0 and not command["timed_out"] and command["joined"],
                    "acquisition completion")
        require(materialization["source_commit"] == HEAD and materialization["status"] == "passed",
                "materialization source")
        require(performance["source"]["commit"] == HEAD and performance["source"]["tree"] == TREE and
                performance["result"] == "passed" and performance["natural_completion"] is True and
                performance["watchdog_reached"] is False, "performance completion/source")
        require(performance["fixture_sha256"] == sha(blob(admission["causal_fixture"]["path"])),
                "fixture bytes")
        require(result["causal_disposition"] == "historical_crash_not_reproduced_causality_unresolved",
                "bounded causal disposition")
    print(json.dumps({"status": "independent-readback-passed", "source": HEAD,
                      "authority_paths": 13, "native_source_inputs": 105,
                      "controls": 21, "assertions": 86, "failures": 0,
                      "scope": "Retained actual hosted Windows receipt; no local Windows or physical acceptance"}))


if __name__ == "__main__":
    main()
