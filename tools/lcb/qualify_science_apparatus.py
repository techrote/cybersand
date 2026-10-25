#!/usr/bin/env python3
"""Portable, bounded LCB observation-apparatus qualification; never a campaign.

run prepares three real registered Godot inputs, executes six short Native
children, independently reduces them, then replays hostile raw-report copies.
replay repeats only the read-only reductions/guards from a retained run packet.
No engine build, retry, result overwrite, publication or Web execution occurs.
"""
from __future__ import annotations

import argparse
import contextlib
import copy
import datetime
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import sys
import time
import traceback

import science_apparatus as a

ROOT = a.ROOT
HORIZON = 30
CHILD_TIMEOUT = 120
ARMS = (
    ("water-fm", "lcb.dam.water.freemass.reference.v1.json", [], ""),
    ("water-in", "lcb.dam.water.freemass.reference.v1.json",
     ["3:inertial_cellular_v1:reference"], "water-normalize-v1"),
    ("brine-in", "lcb.mixed.water-oil-brine.v1.json",
     ["24:inertial_cellular_v1:reference"], ""),
)
FIXTURES = ROOT / "godot/tests/fixtures/lcb"
CORE_SOURCES = {"native/bench/lcb_science.cpp", "native/src/world.cpp",
                "native/src/material_rules.cpp", "native/src/scheduler_geometry.cpp",
                "native/src/settled_world_discovery.cpp"}


def file_sha(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def sha_text(value: object, label: str) -> str:
    a.require(type(value) is str and len(value) == 64 and all(c in "0123456789abcdef" for c in value),
              "invalid SHA256: " + label)
    return value


def source_map(value: object) -> dict[str, str]:
    a.require(type(value) is dict and bool(value), "nonempty complete compiler source map required")
    result = {}
    for name, digest in value.items():
        a.require(type(name) is str and "\\" not in name, "source path must use repository-relative POSIX spelling")
        path = PurePosixPath(name)
        a.require(not path.is_absolute() and ".." not in path.parts and name == path.as_posix(), "unsafe compiler source path")
        a.require((ROOT / name).is_file(), "missing compiler source: " + name)
        result[name] = sha_text(digest, name)
    return result


def build_binding(args: argparse.Namespace) -> dict:
    """Two explicit receipt shapes; complete path/hash equality, never subsets.

    The original object receipt has objects[*].compiled_inputs. The portable
    flat receipt must declare schema lcb-science-consumer-build-v1/source_inputs.
    Both use exactly exe_sha256/compiler_sha256/flags, not hash-name aliases.
    """
    receipt = a.load(args.build_receipt)
    supplied = source_map(a.load(args.compiler_source_map))
    a.require(type(receipt) is dict, "consumer build receipt object")
    a.require(("objects" in receipt) != ("source_inputs" in receipt), "exactly one build receipt source container required")
    if "objects" in receipt:
        a.require("schema" not in receipt and type(receipt["objects"]) is dict and receipt["objects"],
                  "original object-compile receipt shape")
        complete: dict[str, str] = {}
        for obj in receipt["objects"].values():
            a.require(type(obj) is dict, "compiled object record")
            sha_text(obj["object_sha256"], "object")
            for name, digest in source_map(obj["compiled_inputs"]).items():
                a.require(name not in complete or complete[name] == digest, "inconsistent repeated compiled input")
                complete[name] = digest
        shape = "original-object-compile-receipt-v1"
    else:
        a.require(receipt.get("schema") == "lcb-science-consumer-build-v1", "portable flat build receipt schema")
        complete = source_map(receipt["source_inputs"])
        shape = "flat-source-build-receipt-v1"
    a.require(complete == supplied and CORE_SOURCES <= complete.keys(), "complete build receipt/source-map equality required")
    flags = receipt["flags"]
    a.require(type(flags) is list and flags and all(type(v) is str for v in flags), "explicit compiler flags required")
    binary = sha_text(receipt["exe_sha256"], "consumer")
    compiler = sha_text(receipt["compiler_sha256"], "compiler")
    a.require(file_sha(args.consumer) == binary and file_sha(args.compiler) == compiler, "actual consumer/compiler identity mismatch")
    for name, digest in complete.items():
        a.require(file_sha(ROOT / name) == digest, "compiled source mismatch: " + name)
    return {"shape": shape, "consumer_sha256": binary, "compiler_sha256": compiler,
            "flags": flags, "source_inputs": complete,
            "build_receipt_sha256": file_sha(args.build_receipt),
            "compiler_source_map_sha256": file_sha(args.compiler_source_map)}


def tracked_source_fence() -> dict[str, str]:
    # Bind executable/apparatus source, not concurrently edited prose or ignored
    # imports. Runtime payloads are separately bound by actual bytes/manifests.
    names = subprocess.check_output(["git", "ls-files", "--cached", "--others", "--exclude-standard",
                                    "native", "godot", "examples", "tools/lcb", "tools/ci"], cwd=ROOT).decode().splitlines()
    return {name: file_sha(ROOT / name) for name in sorted(set(names))}


def input_fence(args: argparse.Namespace) -> dict:
    libraries = {}
    for path in args.consumer_library:
        a.require(path.is_file() and path.name not in libraries, "unique explicit consumer-library basenames required")
        libraries[path.name] = {"path": str(path), "sha256": file_sha(path)}
    platform = "windows" if sys.platform == "win32" else "linux" if sys.platform.startswith("linux") else "unsupported"
    a.require(platform != "unsupported", "qualification supports actual Windows/Linux only")
    manifest = ROOT / "godot/addons/cybersand_native" / ("runtime-provenance.json" if platform == "windows" else "runtime-provenance.linux.json")
    native = a.load(manifest)
    a.require(file_sha(args.native_runtime) == native["sha256"], "actual published Native runtime required")
    for name, digest in native["source_inputs"].items():
        a.require(a.sha((ROOT / name).read_bytes().replace(b"\r\n", b"\n")) == digest, "published Native source mismatch: " + name)
    lock = a.load(ROOT / "godot/third_party/rapier2d.lock.json")
    rapier_path = ROOT / lock["runtime_overrides"][platform]
    rapier = a.load(rapier_path)
    a.require(file_sha(args.rapier_runtime) == rapier["sha256"], "selected actual Rapier runtime required")
    return {"head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT).decode().strip(),
            "source": tracked_source_fence(), "build": build_binding(args), "platform": platform,
            "files": {str(p): file_sha(p) for p in [args.godot, args.native_runtime, args.rapier_runtime,
                       args.consumer, args.compiler, args.build_receipt, args.compiler_source_map, manifest, rapier_path]},
            "consumer_libraries": libraries, "native_source_inputs": native["source_inputs"]}


def new_out(path: Path) -> Path:
    out = path.resolve()
    a.require(not out.exists() and not out.is_relative_to(ROOT), "output must be new and outside source checkout")
    out.mkdir(parents=True)
    return out


def child(args: argparse.Namespace, command: list[str], out: Path, label: str) -> dict:
    directories = list(dict.fromkeys(str(p.parent) for p in args.consumer_library))
    environment = dict(os.environ)
    if directories:
        key = "PATH" if sys.platform == "win32" else "LD_LIBRARY_PATH"
        environment[key] = os.pathsep.join(directories + [environment.get(key, "")])
    start = time.monotonic()
    timed_out = False
    launch_error = None
    # Files exist before spawn, so launch failures and partial/timed-out output
    # remain reviewable. subprocess.run kills/waits its sole Native process.
    with (out / (label + ".stdout")).open("xb") as stdout, (out / (label + ".stderr")).open("xb") as stderr:
        try:
            result = subprocess.run(command, cwd=ROOT, env=environment, stdout=stdout, stderr=stderr,
                                    timeout=CHILD_TIMEOUT, check=False)
            code = result.returncode
        except subprocess.TimeoutExpired:
            code, timed_out = None, True
        except OSError as error:
            code, launch_error = None, str(error)
    record = {"command": command, "timeout_seconds": CHILD_TIMEOUT, "seconds": time.monotonic() - start,
              "returncode": code, "timed_out": timed_out, "launch_error": launch_error,
              "wrapper_timeout_exit": 124 if timed_out else None,
              "stdout_sha256": file_sha(out / (label + ".stdout")),
              "stderr_sha256": file_sha(out / (label + ".stderr"))}
    a.save_new(out / (label + "-process.json"), record)
    a.require(not timed_out and code == 0 and (out / (label + ".stdout")).stat().st_size == 0
              and (out / (label + ".stderr")).stat().st_size == 0, "strict Native child failure: " + label)
    return record


def failure(out: Path, stage: str, error: BaseException) -> None:
    a.save_new(out / "FAILURE.json", {"schema": "lcb-science-qualification-failure-v1", "status": "failed",
              "stage": stage, "error_type": type(error).__name__, "error": str(error),
              "traceback": traceback.format_exc(), "partial_outputs_retained": True,
              "retry": False, "successful_qualification": False})


def write_raw(path: Path, rows: list[dict]) -> None:
    with path.open("x", encoding="utf8", newline="\n") as stream:
        for row in rows:
            stream.write(json.dumps(row, separators=(",", ":"), allow_nan=False) + "\n")


def replay_cases(packet: Path, out: Path) -> dict:
    """Real positive controls first; mutations must fail the intended check."""
    index = a.load(packet / "RAW-REPORTS.json")
    a.require(index["schema"] == "lcb-science-raw-reports-v1" and len(index["reports"]) == 6, "complete six-report packet")
    expected = {(arm, workers) for arm, *_ in ARMS for workers in (1, 4)}
    actual = {(r["arm"], a.integer(r["workers"], 1, 4, "replay workers")) for r in index["reports"]}
    a.require(actual == expected, "six unique actual report identities required")
    positive = []
    by_arm = {}
    for item in index["reports"]:
        paths = {key: packet / item[key] for key in ("report", "precursor", "events")}
        a.require(file_sha(paths["report"]) == item["report_sha256"]
                  and file_sha(paths["precursor"] / "precursor.json") == item["precursor_sha256"]
                  and file_sha(paths["precursor"] / "initial.cyps") == item["snapshot_sha256"]
                  and file_sha(paths["events"]) == item["events_sha256"], "retained raw-report input identity drift")
        result = a.validate_native_report(paths["report"], paths["precursor"], paths["events"], item["workers"], HORIZON)
        a.require(result["raw_sha256"] == item["report_sha256"], "raw positive-control identity")
        positive.append({"arm": item["arm"], "workers": item["workers"], "reduction": result})
        by_arm[item["arm"], item["workers"]] = (item, paths)
    # Do not begin a negative if any original same-input positive failed.
    for arm, *_ in ARMS:
        pair = [v["reduction"]["worker_parity_projection_sha256"] for v in positive if v["arm"] == arm]
        a.require(len(pair) == 2 and pair[0] == pair[1], "raw positive worker-parity mismatch: " + arm)
    a.save_new(out / "POSITIVE-CONTROLS.json", positive)
    item, paths = by_arm["water-in", 1]
    original = [a.loads(line) for line in paths["report"].read_text(encoding="utf8").splitlines()]
    observation = next(i for i, row in enumerate(original) if row["type"] == "observation")
    negatives = []

    def reject(name: str, reason: str, mutate, sidecar_mutate=None, wire_mutate=None) -> None:
        folder = out / name
        folder.mkdir()
        rows = copy.deepcopy(original)
        mutate(rows, observation)
        raw = folder / "report.ndjson"
        write_raw(raw, rows)
        precursor = paths["precursor"]
        events = paths["events"]
        if sidecar_mutate is not None:
            precursor = folder / "precursor"
            precursor.mkdir()
            # Structural byte identity of the snapshot stays exact. Copy only
            # the small sidecar; link or copy snapshot without rewriting it.
            try:
                os.link(paths["precursor"] / "initial.cyps", precursor / "initial.cyps")
            except OSError:
                (precursor / "initial.cyps").write_bytes((paths["precursor"] / "initial.cyps").read_bytes())
            sidecar = copy.deepcopy(a.load(paths["precursor"] / "precursor.json"))
            sidecar_mutate(sidecar)
            a.save_new(precursor / "precursor.json", sidecar)
        if wire_mutate is not None:
            events = folder / "events.txt"
            with events.open("xb") as stream:
                stream.write(wire_mutate(paths["events"].read_bytes()))
        try:
            a.validate_native_report(raw, precursor, events, 1, HORIZON)
        except ValueError as error:
            a.require(reason in str(error), "mutation refused for unrelated reason: " + name + ": " + str(error))
            negatives.append({"name": name, "expected_reason": reason, "actual_reason": str(error),
                              "report_sha256": file_sha(raw), "status": "refused_as_expected"})
        else:
            raise ValueError("adversarial raw report accepted: " + name)

    # P2: preserve original text/SHA, native setup identity and snapshot; replace
    # only the normalized event program under its old definition hash.
    def substitute(sidecar):
        definition = a.loads(sidecar["normalized_definition_json"])
        a.require(definition["events"], "P2 positive fixture must contain an action")
        definition["events"][0]["tick"] += 1
        sidecar["normalized_definition_json"] = json.dumps(definition, separators=(",", ":"))
    reject("p2-event-substitution-old-definition-hash", "original definition differs", lambda r, i: None, substitute)
    def substitute_both(sidecar, update_hash=False):
        definition = a.loads(sidecar["normalized_definition_json"])
        definition["events"][0]["tick"] += 1
        text = json.dumps(definition, separators=(",", ":"))
        sidecar["normalized_definition_json"] = sidecar["definition_text"] = text
        sidecar["definition_file_sha256"] = a.sha(text.encode("utf8"))
        if update_hash:
            sidecar["definition_hash"] = a.sha(a.canonical_definition(definition))
    reject("p2-both-texts-old-hash", "independent canonical definition hash mismatch", lambda r, i: None, substitute_both)
    reject("p2-new-hash-old-native-setup", "differs from native prepared setup identity", lambda r, i: None,
           lambda sidecar: substitute_both(sidecar, True))
    for key, values in (("workers", (True, 1.0)), ("backend", (True, 1.0)), ("cyps_version", (True, 3.0))):
        for value in values:
            reject("p3-header-" + key + "-" + type(value).__name__, "invalid integer",
                   lambda r, i, k=key, v=value: r[0].__setitem__(k, v))
    reject("p3-unknown-schema", "native schema", lambda r, i: r[0].__setitem__("schema", "lcb-native-science-v0"))
    reject("p3-coverage-chunk-side-float", "invalid integer census chunk side",
           lambda r, i: r[0]["coverage"].__setitem__("chunk_side", 128.0))
    for key in ("schema_version", "mass_bits"):
        for value in (True, 1.0):
            reject("p3-quantity-" + key + "-" + type(value).__name__, "invalid integer",
                   lambda r, i, k=key, v=value: r[i]["quantity"].__setitem__(k, v))
    reject("missing-ledger-field", "incomplete nineteen-field ledger", lambda r, i: r[i]["ledger"].pop("gravity_y"))
    reject("wrong-phase", "native action/completed phase sequence", lambda r, i: r[i].__setitem__("phase", "post_event"))
    reject("missing-phase", "native action/completed phase sequence", lambda r, i: r.pop(i + 1))
    reject("missing-footer", "missing native completion header/footer", lambda r, i: r.pop())
    reject("false-footer-closure", "incomplete native footer", lambda r, i: r[-1].__setitem__("closure", False))
    reject("quantity-census-mismatch", "independent census/quantity mismatch", lambda r, i: r[i]["quantity"].__setitem__("water_visible", "1"))
    reject("worker-participation-bound", "actual maximum participants in one dispatch", lambda r, i: r[i]["stats"].__setitem__("observed_workers", "2"))
    reject("worker-count-identity", "actual workers/allocation readback", lambda r, i: r[i]["stats"].__setitem__("configured_workers", "4"))
    reject("post-footer-data", "native data after footer", lambda r, i: r.append(copy.deepcopy(r[i])))
    reject("event-wire-substitution", "events differ from prepared definition", lambda r, i: None,
           wire_mutate=lambda data: data.replace(b"\n0 ", b"\n1 ", 1))
    result = {"schema": "lcb-science-raw-report-guards-v1", "status": "completed",
              "positive_actual_reports": len(positive), "negative_mutations": len(negatives),
              "negatives": negatives, "same_input_positive_controls_first": True,
              "scope": "Raw-report/precursor admission guards only; no new physics, Godot or campaign execution"}
    a.save_new(out / "REPLAY-RECEIPT.json", result)
    return result


def run(args: argparse.Namespace) -> None:
    out = new_out(args.out)
    stage = "prospective inputs"
    try:
        before = input_fence(args)
        plan = {"schema": "lcb-science-bounded-qualification-plan-v1", "utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                "inputs": before, "radius": 3, "horizon": HORIZON, "host_qualification_ticks": HORIZON,
                "native_workers": [1, 4], "native_child_timeout_seconds": CHILD_TIMEOUT,
                "godot_import_timeout_seconds": 240, "godot_preparation_timeout_seconds": 180,
                "arms": [{"arm": name, "definition": str(FIXTURES / fixture), "definition_sha256": file_sha(FIXTURES / fixture),
                          "assignments": assignments, "normalization": normalization} for name, fixture, assignments, normalization in ARMS],
                "scope": "Three real actor-free precursors and six30tick Native children; bounded apparatus qualification only, no full scientific campaign or Web"}
        a.save_new(out / "PROSPECTIVE-PLAN.json", plan)
        reports = []
        processes = []
        for arm, fixture, assignments, normalization in ARMS:
            stage = "Godot preparation " + arm
            folder = out / arm
            preparation_args = argparse.Namespace(godot=args.godot, native_runtime=args.native_runtime,
                rapier_runtime=args.rapier_runtime, definition=FIXTURES / fixture, out=folder,
                horizon=HORIZON, radius=3, qualification_ticks=HORIZON, normalization=normalization, assign=assignments)
            with (out / (arm + "-preparation.stdout")).open("x", encoding="utf8") as stdout, \
                    (out / (arm + "-preparation.stderr")).open("x", encoding="utf8") as stderr, \
                    contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                a.prepare(preparation_args)
            a.require((out / (arm + "-preparation.stderr")).stat().st_size == 0, "preparation wrapper stderr")
            a.require(input_fence(args) == before, "source/runtime/compiler inputs changed during preparation")
            sidecar, definition = a.read_precursor(folder / "prepared")
            a.require(sidecar["qualification_ticks"] == "30" and sidecar["prepared_receipt"]["maximum_rule_radius"] == "3", "strong actual30tick radius3 precursor required")
            wire, _ = a.event_wire(definition, HORIZON)
            a.require((folder / "events.txt").read_bytes() == wire, "prepared wire identity")
            immutable = {str(p): file_sha(p) for p in [folder / "prepared/initial.cyps", folder / "prepared/precursor.json", folder / "events.txt"]}
            for workers in (1, 4):
                stage = "Native " + arm + " workers" + str(workers)
                label = arm + "-w" + str(workers)
                raw = out / (label + ".ndjson")
                command = [str(args.consumer), str(folder / "prepared/initial.cyps"), str(folder / "events.txt"), str(workers), str(HORIZON), str(raw)]
                processes.append(child(args, command, out, label))
                a.require(input_fence(args) == before and immutable == {p: file_sha(Path(p)) for p in immutable}, "source or Native child inputs changed")
                reduction = a.validate_native_report(raw, folder / "prepared", folder / "events.txt", workers, HORIZON)
                a.save_new(out / (label + "-reduction.json"), reduction)
                reports.append({"arm": arm, "workers": workers, "report": raw.relative_to(out).as_posix(),
                    "precursor": (folder / "prepared").relative_to(out).as_posix(), "events": (folder / "events.txt").relative_to(out).as_posix(),
                    "report_sha256": file_sha(raw), "snapshot_sha256": sidecar["snapshot_sha256"],
                    "precursor_sha256": immutable[str(folder / "prepared/precursor.json")], "events_sha256": a.sha(wire)})
        a.save_new(out / "RAW-REPORTS.json", {"schema": "lcb-science-raw-reports-v1", "reports": reports})
        stage = "raw-report positive controls and adversarial replays"
        replay = out / "raw-replay"
        replay.mkdir()
        replay_result = replay_cases(out, replay)
        a.require(input_fence(args) == before, "final source/runtime/compiler fence changed")
        a.save_new(out / "QUALIFICATION-RECEIPT.json", {"schema": "lcb-science-bounded-qualification-v1", "status": "completed",
            "prospective_plan_sha256": file_sha(out / "PROSPECTIVE-PLAN.json"), "raw_reports_sha256": file_sha(out / "RAW-REPORTS.json"),
            "processes": processes, "positive_native_children": len(reports), "raw_guard_replay": replay_result,
            "source_runtime_compiler_inputs_held": True,
            "scope": "Bounded30tick apparatus qualification; precursor receipt remains workers1, actual module/script bindings unverified, no scientific/full-host/Web acceptance"})
        print(json.dumps({"status": "completed", "out": str(out), "children": len(reports), "raw_negative_guards": replay_result["negative_mutations"]}))
    except Exception as error:
        failure(out, stage, error)
        raise


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("run")
    for name in ("godot", "native-runtime", "rapier-runtime", "consumer", "build-receipt", "compiler-source-map", "compiler", "out"):
        p.add_argument("--" + name, type=Path, required=True)
    p.add_argument("--consumer-library", type=Path, action="append", default=[], help="explicit hashed shared library; parent directory added to child loader path")
    r = sub.add_parser("replay", help="positive and hostile raw-report replay only; no engine execution")
    r.add_argument("--packet", type=Path, required=True)
    r.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    for key, value in vars(args).items():
        if isinstance(value, Path):
            setattr(args, key, value.resolve())
    if hasattr(args, "consumer_library"):
        args.consumer_library = [p.resolve() for p in args.consumer_library]
    try:
        if args.command == "run":
            run(args)
        else:
            out = new_out(args.out)
            try:
                a.save_new(out / "PROSPECTIVE-REPLAY.json", {"packet": str(args.packet), "raw_index_sha256": file_sha(args.packet / "RAW-REPORTS.json"),
                    "reader_sha256": file_sha(Path(a.__file__)), "harness_sha256": file_sha(Path(__file__)), "no_engine_execution": True})
                result = replay_cases(args.packet, out)
                print(json.dumps({"status": result["status"], "positive": result["positive_actual_reports"], "negative": result["negative_mutations"]}))
            except Exception as error:
                failure(out, "raw-report replay", error)
                raise
    except (ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError) as error:
        print("LCB bounded apparatus qualification refused: " + str(error), file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
