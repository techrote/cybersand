#!/usr/bin/env python3
"""A new execution qualifier for one retained, exact application/runtime cohort.

The original same-head qualifiers remain unchanged. Only their source/driver
join is derived here: an explicitly pinned older application is executed by a
new, fully identified driver. This is not an offline replay or pass override.
"""
from __future__ import annotations

import ast
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
DIRECTORY = "tools/pubpres_final_requalification"
REQUEST = ".github/pubpres-font-requalification-run.json"
WORKFLOW = ".github/workflows/pubpres-font-requalification.yml"
BRANCH = "codex/pubpres-playability-final-001-20261124"
APPLICATION = "c2f8a73d34448bc1496ecd84bca02f0812c80d27"
APPLICATION_TREE = "351b947a50ce054361660eba9379006122527547"
RUNTIME_SHA = "1cdcbf4f72204d79b22d1a9551e46f9ccf02f6785d3141503e90e27feda28f1b"
RUNTIME_MANIFEST_SHA = "f1d8e97e923eb8c03a9ae3592bd9a45b2784ca70eee2cdd15e0a85cd63f51be1"
ENGINE_IDENTITY = {
    "build_source": APPLICATION, "build_run": 45452580606, "build_attempt": 1,
    "proof_sha256": "0f1d6059578d4505043fe11f1286cd7395c5cc64df7aa379106f7a0bcafdf1c5"}
FROZEN = {
    "font": {"path": "tools/pubpres_final_engine/run_font_qualification.py",
             "sha256": "3094d8b5d9284a3b6ce54a4d6c43363c14f53858b0c6181dce902254cf48f613",
             "functions": {"main": "3005f4daff3017d72bb6a6c95dc105569ecef16ce3efadb35754e587c68cc042",
                           "verify_qualification": "4213f8aef098087db385492fdf8044a6cfe7414fd7736aca911423047771804f"}},
    "renderer": {"path": "tools/pubpres_final/run_font_renderer_comparison.py",
                 "sha256": "de1fd27a2ed5fb2deff34cbc4592c1a34526aa33391b48e739918afc0feebf90",
                 "functions": {"main": "4fbfaa0e68629d7bfb428341ce144ced747a1a20aff5bb80bebdfa5666adb1ca"}}}


def need(ok, message):
    if not ok:
        raise ValueError(message)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git(*args: str, root: Path = ROOT) -> str:
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()


def registration() -> dict:
    value = json.loads((HERE / "registration.json").read_bytes())
    need(value.get("schema") == "pubpres-retained-font-new-execution-v1"
         and value.get("application") == {"source_commit": APPLICATION, "source_tree": APPLICATION_TREE}
         and value.get("engine_identity") == ENGINE_IDENTITY
         and value.get("native_binary_sha256") == RUNTIME_SHA
         and value.get("native_manifest_sha256") == RUNTIME_MANIFEST_SHA
         and value.get("same_head_qualifiers") == FROZEN
         and value.get("physical_acceptance") == "HOLD", "Detached execution registration differs")
    return value


def fingerprint(root: Path = ROOT, ref: str = "HEAD") -> str:
    rows = subprocess.check_output(["git", "-C", str(root), "ls-tree", "-r", "-z", ref]).split(b"\0")
    selected = [row for row in rows if row and row.split(b"\t", 1)[1].decode() != REQUEST]
    return sha(b"\0".join(selected) + b"\0")


def validate_request(root: Path = ROOT) -> dict:
    value = json.loads((root / REQUEST).read_bytes())
    need(set(value) == {"schema", "application", "purpose", "payload_sha256"}
         and value["schema"] == "pubpres-font-new-execution-request-v1"
         and value["application"] == APPLICATION
         and isinstance(value["purpose"], str) and value["purpose"].strip()
         and value["payload_sha256"] == fingerprint(root), "New execution request does not bind this complete driver tree")
    if os.environ.get("GITHUB_ACTIONS") == "true":
        need(os.environ.get("GITHUB_REF") == "refs/heads/" + BRANCH
             and os.environ.get("GITHUB_EVENT_NAME") == "push"
             and os.environ.get("GITHUB_SHA") == git("rev-parse", "HEAD", root=root),
             "Only the exact dedicated PUBPRES push may execute the retained cohort")
    return value


def registered_source(source: dict, driver: dict) -> None:
    need(source.get("source_commit") == APPLICATION and source.get("source_tree") == APPLICATION_TREE,
         "Application is not the exact retained c2 source/tree")
    need(driver.get("source_commit") == git("rev-parse", "HEAD")
         and driver.get("source_tree") == git("rev-parse", "HEAD^{tree}")
         and driver["source_commit"] != APPLICATION,
         "Qualifier is not the separately committed current driver")


def registered_runtime(source: dict) -> None:
    runtime = source.get("native_runtime", {})
    need(runtime.get("binary_sha256") == RUNTIME_SHA and runtime.get("manifest_sha256") == RUNTIME_MANIFEST_SHA,
         "Retained native binary/receipt differs from independently built c2 runtime")


def registered_engine(identity: dict) -> None:
    need(identity == ENGINE_IDENTITY and type(identity.get("build_run")) is int
         and type(identity.get("build_attempt")) is int,
         "Retained engine build/source/run/attempt/proof differs")


def derive(role: str, function: str, raw: bytes) -> str:
    frozen = FROZEN[role]
    need(sha(raw) == frozen["sha256"], "Original same-head qualifier file changed")
    source = raw.decode("utf-8")
    nodes = [node for node in ast.parse(source).body if isinstance(node, ast.FunctionDef) and node.name == function]
    need(len(nodes) == 1, "Original qualifier function is missing or ambiguous")
    body = ast.get_source_segment(source, nodes[0])
    need(sha(body.encode()) == frozen["functions"][function], "Original qualifier function changed")
    if role == "font":
        label = ("Ordinary application must be the exact qualification driver source" if function == "main"
                 else "Timed application and font/startup qualification source differ")
        old = ('need(source["source_commit"] == driver["source_commit"] and source["source_tree"] == driver["source_tree"],\n'
               '         "' + label + '")')
        new = "_registered_source(source, driver)"
        if function == "verify_qualification":
            new += ('\n    _registered_runtime(source)\n    _registered_engine(identity)\n'
                    '    need(report.get("execution_registration") == _execution_registration(driver),\n'
                    '         "Retained font report belongs to a different registered execution driver")')
        edits = [(old, new)]
        if function == "main":
            original = 'source["native_runtime"] = validate_runtime(source_root, source, args.runtime.resolve(), False)'
            edits += [(original, original + "\n    _registered_runtime(source)"),
                      ("new_identity = payload.identity_arguments(args)",
                       "new_identity = payload.identity_arguments(args)\n    _registered_engine(new_identity)"),
                      ('def save(): write_json(output / "SUMMARY.json", report)',
                       'report["execution_registration"] = _execution_registration(driver)\n    def save(): write_json(output / "SUMMARY.json", report)')]
    else:
        edits = [('validate_registered_sources({"C":source},driver,base,"single")',
                  '_registered_source(source,driver)\n    _registered_runtime(source)'),
                 ('identity=payload.identity_arguments(args)',
                  'identity=payload.identity_arguments(args)\n    _registered_engine(identity)'),
                 ('def save(): write_json(output/"SUMMARY.json",report)',
                  'report["execution_registration"]=_execution_registration(driver)\n    def save(): write_json(output/"SUMMARY.json",report)')]
    for old, new in edits:
        need(body.count(old) == 1, "Registered derivation no longer has one exact source location")
        body = body.replace(old, new)
    return body + "\n"


def derivations() -> dict:
    result = {}
    for role, frozen in FROZEN.items():
        raw = (ROOT / frozen["path"]).read_bytes()
        result[role] = {name: {"original_function_sha256": expected,
                              "derived_function_sha256": sha(derive(role, name, raw).encode())}
                        for name, expected in frozen["functions"].items()}
    return result


def augment_driver(original: dict) -> dict:
    result = copy.deepcopy(original)
    wanted = {path.relative_to(ROOT).as_posix() for path in HERE.iterdir()
              if path.is_file() and path.suffix in (".py", ".json", ".md")}
    tracked = set(git("ls-tree", "-r", "--name-only", "HEAD", "--", DIRECTORY).splitlines())
    need(wanted == tracked and wanted, "Detached qualifier has uncommitted or missing inputs")
    wanted.update((REQUEST, WORKFLOW))
    for name in sorted(wanted):
        raw = subprocess.check_output(["git", "-C", str(ROOT), "show", "HEAD:" + name])
        need((ROOT / name).read_bytes() == raw, "Detached qualifier input differs: " + name)
        result["files_sha256"][name] = sha(raw)
    result["detached_execution"] = {"registration_sha256": sha((HERE / "registration.json").read_bytes()),
                                    "request": validate_request(), "derivations": derivations()}
    return result


def execution_registration(driver: dict) -> dict:
    return {"schema": "pubpres-retained-font-execution-binding-v1", "registration": registration(),
            "registration_sha256": sha((HERE / "registration.json").read_bytes()),
            "driver_source": driver["source_commit"], "driver_tree": driver["source_tree"],
            "complete_driver_payload_sha256": fingerprint(), "derivations": derivations(),
            "scope": "New actual Windows execution of fixed c2 application/native/engine with separately committed qualifier; original failed attempt is unchanged. No physical NVIDIA acceptance."}


def qualified_functions():
    """Compile only SHA-pinned repository bodies and declared exact join edits."""
    sys.path.insert(0, str(ROOT / "tools/pubpres_final_engine"))
    sys.path.insert(0, str(ROOT / "tools/pubpres_final"))
    import run_font_qualification as font
    import run_font_renderer_comparison as renderer
    common = {"_registered_source": registered_source, "_registered_runtime": registered_runtime,
              "_registered_engine": registered_engine, "_execution_registration": execution_registration}
    spaces = {}
    for role, module in (("font", font), ("renderer", renderer)):
        need(Path(module.__file__).resolve() == ROOT / FROZEN[role]["path"], "Qualifier imported from an unexpected path")
        spaces[role] = {**vars(module), **common}
    spaces["font"]["driver_identity"] = lambda: augment_driver(font.driver_identity())
    spaces["renderer"]["verify_driver"] = lambda: augment_driver(renderer.verify_driver())
    for name in ("verify_qualification", "main"):
        body = derive("font", name, (ROOT / FROZEN["font"]["path"]).read_bytes())
        exec(compile(body, str(HERE / "contract.py") + ":registered-font-" + name, "exec"), spaces["font"])
    spaces["renderer"]["verify_qualification"] = spaces["font"]["verify_qualification"]
    body = derive("renderer", "main", (ROOT / FROZEN["renderer"]["path"]).read_bytes())
    exec(compile(body, str(HERE / "contract.py") + ":registered-renderer", "exec"), spaces["renderer"])
    return spaces["font"]["main"], spaces["renderer"]["main"], spaces["font"]["verify_qualification"]


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fingerprint", action="store_true")
    args = parser.parse_args()
    if args.fingerprint:
        print(fingerprint())
    else:
        registration()
        print(json.dumps({"request": validate_request(), "derivations": derivations(), "physical_acceptance": "HOLD"}, indent=2))
