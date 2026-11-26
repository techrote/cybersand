#!/usr/bin/env python3
"""Read the two retained 7919 hosted archives without extracting or executing them.

This verifies recorded facts against original artifacts and committed inputs;
it does not turn the failed aggregate run into a pass or rerun Windows locally.
Run from a checkout containing the preserved source commit:
  python path/to/verify-overnight.py --root . --output /tmp/overnight-readback.json
"""
from pathlib import Path
import argparse
import ast
import hashlib
import json
import re
import subprocess
import zipfile

HEAD = "7919e8a752e87e68c4193b3a04960164ab62e117"
TREE = "f3dc13c5c7143c4bff1b7875d445486290869576"
KINDS = ("persistence", "microscenario-capture", "recorder-storage", "profile-save",
         "art-storage", "diagnostic-storage", "tower-observation")
COUNTS = {"linux": (13, 6, 2, 16, 13, 12, 6), "windows": (10, 4, 2, 12, 9, 8, 4)}
DESCRIPTORS = {"godot/addons/godot-rapier2d/" + p for p in (
    "Radial2D.svg.import", "icons/Fluid2D.svg.import", "icons/StateManager2D.svg.import",
    "logo_square_2d.png.import")}
ERROR = re.compile(r"^(?:SCRIPT ERROR:|ERROR:)|Parse Error|Compile Error", re.M)


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def pairs(items):
    result = {}
    for key, value in items:
        require(key not in result, f"duplicate JSON key: {key}")
        result[key] = value
    return result


def parse(data):
    return json.loads(data, object_pairs_hook=pairs)


def git(root, *args, data=None):
    return subprocess.check_output(["git", "-C", str(root), *args], input=data)


def sources(root):
    require(git(root, "rev-parse", HEAD + "^{tree}").decode().strip() == TREE, "source tree")
    listing = git(root, "ls-tree", "-r", "-z", HEAD).split(b"\0")
    paths = {}
    for row in listing:
        if not row:
            continue
        meta, path = row.split(b"\t", 1)
        mode, kind, oid = meta.split()
        if kind == b"blob" and not path.startswith(b"godot/.godot/"):
            paths[path.decode()] = oid.decode()
    # Only attributes from the recorded source may establish a newline route.
    require(git(root, "show", HEAD + ":.gitattributes") == (root / ".gitattributes").read_bytes(),
            "checkout attributes differ from recorded source")
    raw = git(root, "check-attr", "-z", "--stdin", "text", "eol", "filter",
              data=b"\0".join(p.encode() for p in paths) + b"\0").split(b"\0")
    attributes = {}
    for i in range(0, len(raw)-1, 3):
        attributes.setdefault(raw[i].decode(), {})[raw[i+1].decode()] = raw[i+2].decode()
    proc = subprocess.Popen(["git", "-C", str(root), "cat-file", "--batch"],
                            stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    blobs = {}
    try:
        for oid in sorted(set(paths.values())):
            proc.stdin.write((oid + "\n").encode()); proc.stdin.flush()
            header = proc.stdout.readline().split()
            require(len(header) == 3 and header[1] == b"blob", "missing source blob")
            blobs[oid] = proc.stdout.read(int(header[2]))
            require(proc.stdout.read(1) == b"\n", "cat-file framing")
    finally:
        proc.stdin.close(); proc.wait()
    return {p: blobs[oid] for p, oid in paths.items()}, attributes


def walk(value):
    if isinstance(value, dict):
        yield value
        for item in value.values():
            yield from walk(item)
    elif isinstance(value, list):
        for item in value:
            yield from walk(item)


def verify_cases(kind, cases, host):
    for c in cases:
        if kind == "persistence":
            if c["kind"] == "shared-helper":
                require(c["result"]["checks"] == (84 if host == "linux" else 75)
                        and not c["result"]["failures"], "helper assertions")
                for fault in c["result"]["cases"]:
                    require(fault["old_sha256"] == fault["after_sha256"], "injected old bytes")
                continue
            if "first" in c:
                require(all(not c[n]["error"] and c[n]["readable"] for n in ("first", "second", "final")),
                        "concurrent success/loadability")
                require(c["final"]["value"] in ("first", "second"), "whole concurrent value")
                continue
            old, new = c["before"], c.get("retry", c.get("replacement"))
            require(old["readable"] and new["readable"] and not new["error"], "save normal/retry")
            field, before, after = (("seed", 123, 456) if c["kind"] == "project" else
                ("material", 2, 14) if c["kind"] in ("ordinary", "generated") else ("value", "old", "new"))
            require(old[field] == before and new[field] == after, "save actual values")
            if "refusal" in c or "after" in c:
                refused = c.get("refusal", c.get("after"))
                require(refused["after_sha256"] == old["after_sha256"] and refused[field] == before,
                        "save previous digest/value")
                if "refusal" in c:
                    require(bool(refused["error"]), "save refusal message")
                else:
                    require(c["exit_code"] != 0 and c["staging_sha256"] == new["after_sha256"],
                            "terminated precommit staging/recovery")
            continue
        if kind in ("microscenario-capture", "profile-save", "diagnostic-storage", "tower-observation"):
            old, new = c["before"], c.get("retry", c.get("replacement"))
            field = "value" if kind in ("microscenario-capture", "diagnostic-storage") else "loaded_value"
            before, after = (("old", "new") if kind == "microscenario-capture" and c["kind"] == "controller"
                             else (11, 12) if kind == "microscenario-capture" else (7, 8))
            require(old[field] == before and new[field] == after and old["sha256"] != new["sha256"],
                    kind + " actual normal/retry values")
            readable = {"microscenario-capture":"json_valid", "profile-save":"format_loadable",
                        "diagnostic-storage":"json_valid", "tower-observation":"json_loadable"}[kind]
            require(old[readable] and new[readable], kind + " format reload")
            if "refusal" in c:
                r = c["refusal"]
                require(r["sha256"] == old["sha256"] and r[field] == before and r[readable],
                        kind + " refused preservation/reload")
                if kind == "microscenario-capture":
                    require(bool(r["error"]), "capture error")
                    if c["kind"] == "controller":
                        require(r["acknowledgements"] == 0, "capture false acknowledgement")
                else:
                    require(r["acknowledged"] is False, kind + " false acknowledgement")
            if kind == "tower-observation":
                for phase in (old, new, c.get("refusal", old)):
                    require(phase["context_unchanged"] and phase["unrelated_error"] == "Unrelated retained diagnostic",
                            "Tower unrelated state")
                    require(phase["blind_mapping_size"] > 0 if c["kind"] == "water-blind"
                            else phase["blind_mapping_size"] == 0, "Tower original schema boundary")
            continue
        require(c["passed"] and c["natural_completion"] and c["exit_code"] == 0
                and c["engine_error_detected"] is False, kind + " process result")
        r = c["result"]
        if kind == "recorder-storage":
            if c["fault"] == "none":
                require(not r["status"]["failed"] and r["status"]["written_frames"] == 1
                        and r["frame_bytes"] == 1024 and r["manifest_disposition"] == "complete", "recorder normal")
            else:
                require(r["status"]["failed"] and r["prior_manifest_preserved"]
                        and r["manifest_sha256"] == c["ready"]["sha256"], "recorder refusal")
                require(r["status"]["written_frames"] == (0 if host == "linux" else 1), "recorder counted frame")
        elif c["operation"] in ("settings", "pending-history"):
            require(r["guards_preserved"] and r["stale_preserved"] and not r["partial_files"], "Art guards/cleanup")
            require(r["retry"]["success"] and r["retry"]["loadable"], "Art retry")
            if c["operation"] == "settings":
                require(r["retry"]["value"] == 8 and r["retry"]["roundtrip"], "typed settings retry")
            else:
                require(r["retry"]["values"] == [7, 8] and r["retry"]["frozen_projection"], "receipt projection")
            if c["fault"] != "none":
                require(not r["first"]["success"] and r["first"]["old_preserved"]
                        and r["first"]["clock_unchanged"], "Art refusal preserved state")
        else:
            require(r["source_unchanged"] and not r["partial_files"], "Art source/cleanup")
            require(r["success"] == (c["fault"] == "none"), "Art actual ACK")
            if c["fault"] != "none":
                require(r["old_prefix_preserved"] and not r["last_event_stored"], "Art complete prior prefix")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(); root = args.root.resolve(); base = Path(__file__).resolve().parent
    source, attrs = sources(root)
    runner = ast.parse(source["tools/ci/run_ultima_qualification.py"])
    plans = [ast.literal_eval(node.value) for node in ast.walk(runner)
             if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "plan" for t in node.targets)]
    require(len(plans) == 1, "single recorded workflow plan")
    planned = [name + ("-reopen" if extra else "") for name, extra in plans[0]]
    metadata = parse((base / "overnight-github-metadata.json").read_bytes())
    report = {"schema":1, "authority":"historical-non-authoritative", "source_head":HEAD,
              "source_tree":TREE, "scope":"independent readback of existing hosted execution; not a new OS run",
              "hosts":{}}
    for host in ("linux", "windows"):
        data = (base / f"ultima-overnight-{host}.zip").read_bytes()
        m = next(a for a in metadata["artifacts"] if f"ultima-{host}-" in a["name"])
        require(sha(data) == m["digest"].removeprefix("sha256:") and len(data) == m["size_in_bytes"], "remote archive digest/size")
        with zipfile.ZipFile(base / f"ultima-overnight-{host}.zip") as z:
            require(z.testzip() is None and len(z.namelist()) == len(set(z.namelist())), "archive CRC/unique members")
            q = parse(z.read("qualification.json")); inputs = parse(z.read("source-inputs.json"))
            require(q["source_head"] == HEAD and q["source_tree"] == TREE, "qualified source")
            require(q["status"] == "failed" and q["completed"] is False, "failed aggregate retained")
            require(q["source_inputs_sha256"] == sha(z.read("source-inputs.json")), "input map hash")
            require(set(source) == set(inputs), "complete source path set")
            newline_paths, materialized = [], []
            for p, raw in source.items():
                pointer = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize [0-9]+\n", raw)
                if pointer:
                    require(inputs[p] == pointer[1].decode(), "materialized LFS identity: " + p); materialized.append(p)
                elif sha(raw.replace(b"\r\n", b"\n") if p in DESCRIPTORS else raw) != inputs[p]:
                    a = attrs[p]
                    require(a.get("text") != "unset" and a.get("eol") != "lf"
                            and sha(raw.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")) == inputs[p], "unexplained source drift: " + p)
                    newline_paths.append(p)
            logs = {n: z.read(n) for n in z.namelist() if n.endswith(".log")}
            log_hashes = {sha(raw) for raw in logs.values()}
            error_logs = {n:[line for line in raw.decode(errors="replace").splitlines() if ERROR.search(line)]
                          for n, raw in logs.items() if ERROR.search(raw.decode(errors="replace"))}
            require(set(error_logs) == {"test_water_feel_controller.log"}, "unexpected engine/script errors")
            require(any('tower_observation() -> bool' in line for line in error_logs["test_water_feel_controller.log"]), "actual inheritance failure")
            for node in walk(q):
                if "log_sha256" in node:
                    require(node["log_sha256"] in log_hashes, "case log digest missing")
            matrices = {}
            for kind, count in zip(KINDS, COUNTS[host]):
                r = parse(z.read(kind + "/report.json"))
                require(q[kind.replace("-", "_")] == r, "aggregate/subreport identity")
                require(r["source_head"] == HEAD and r["status"] == "passed" and r["completed"] is True
                        and len(r["cases"]) == count, kind + " source/count/status")
                require(r["engine_sha256"] == q["engine"].get("console_sha256", q["engine"]["runtime_sha256"]),
                        kind + " engine identity")
                for p, digest in r.get("input_sha256", r.get("inputs", {})).items():
                    path = p if p in inputs else "godot/" + p
                    require(inputs[path] == digest, "matrix source drift: " + path)
                for node in walk(r):
                    if "log_sha256" in node:
                        require(node["log_sha256"] in log_hashes, "matrix log digest missing")
                    if "delete_access_probe_error" in node:
                        require(host == "windows" and node["delete_access_probe_error"] == 32, "actual Windows sharing probe")
                verify_cases(kind, r["cases"], host)
                matrices[kind] = {"cases":count, "status":"verified-recorded-pass", "report_sha256":sha(z.read(kind + "/report.json")),
                    "tuples":[[c.get("kind",c.get("operation","recorder")), c.get("fault","none"), c.get("evidence_class", "recorder-public-caller")] for c in r["cases"]]}
            require(len(materialized) == 18, "all retained runtime objects materialized")
            normal = q["cases"]; require(len(normal) == 11, "actual aggregate progress")
            require([c["name"] for c in normal[1:]] == planned[:len(normal)-1], "actual plan prefix")
            require(all(c["status"] == "passed" and c["natural_completion"] and c["returncode"] == 0 for c in normal[:-1]), "completed normal results")
            failed = normal[-1]; require(failed["name"] == "test_water_feel_controller" and failed["status"] == "timeout"
                                       and not failed["natural_completion"] and failed["seconds"] == 3940.0, "Water failure scope")
            report["hosts"][host] = {"artifact_id":m["id"], "archive_sha256":sha(data), "archive_bytes":len(data),
                "source_inputs":len(inputs), "materialized_lfs_objects":len(materialized), "newline_checkout_paths":newline_paths,
                "raw_log_files":len(logs), "engine_error_logs":error_logs, "matrices":matrices,
                "aggregate_status":"failed", "import_passed":True, "normal_passed":9, "normal_failed":1,
                "normal_not_reached":len(planned) - (len(normal)-1), "unexecuted_workflows":planned[len(normal)-1:],
                "failure":failed, "engine":q["engine"]}
    report["status"] = "readback-passed-aggregate-remains-failed"
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status":report["status"], "counts":COUNTS, "source_head":HEAD}, sort_keys=True))


if __name__ == "__main__":
    main()
