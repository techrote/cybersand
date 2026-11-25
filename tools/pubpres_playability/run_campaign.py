#!/usr/bin/env python3
"""Run the registered source comparison on Linux or Windows with pinned Godot.

Only new copies beneath --output are modified. Source gameplay runs are serial.
The Windows engine must be the direct Godot executable, not a child launcher.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import uuid

# The owner package is a pristine, inventoried payload. Importing its reader
# must not create an unlisted __pycache__ before verification.
sys.dont_write_bytecode = True
from results import canonical, digest, need, reduce_receipt as reduce_receipt_v2
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "pubpres_playability_build"))
from process_owner import OwnedProcess
import dependency_custody


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + "\n")


DIAGNOSTICS = {
    "observer_calibration": ("calibration", ["full","reduced","reduced","full"]),
    "input_equivalence": ("input_equivalence", ["repeated_callback","once_per_step","once_per_step","repeated_callback"]),
    "render_thread_calibration": ("render_thread_calibration", ["safe","separate","separate","safe"]),
    "native_probe_calibration": ("native_probe_calibration", [False,True,True,False]),
    "same_frame_calibration": ("same_frame_calibration", [False,True,True,False]),
}


def measurement_protocol(campaign):
    """Select an explicit observer/reducer pair; never reinterpret old v2 data."""
    schema = campaign.get("schema")
    if schema == "pubpres-playability-campaign-v2":
        need(all(arm.get("same_frame_continuation") is None for arm in campaign["arms"].values()),
             "V2 cannot select or attest the new continuation treatment")
        return "v2", "tests/pubpres_playability_gameplay.gd", reduce_receipt_v2
    need(schema == "pubpres-playability-campaign-v3", "Unknown measurement protocol")
    need(campaign.get("observer_entrypoint") == "tests/pubpres_same_frame_gameplay.gd",
         "V3 observer entrypoint differs")
    need(campaign["measurement"].get("receipt_schema") == "pubpres-playability-gameplay-v3",
         "V3 receipt schema differs")
    expected_overlay = {"tests/pubpres_same_frame_gameplay.gd", "scripts/engine_lab_reference_fixture.gd",
        "tests/fixtures/engine_lab/setup-gate-canvas.json", "tests/pubpres_playability_compatibility.gd",
        "tests/pubpres_playability_profile.gd"}
    need(set(campaign["overlay_sha256"]) == expected_overlay, "V3 observation overlay inventory differs")
    need(type(campaign["arms"]["C"].get("same_frame_continuation")) is bool
         and campaign["arms"]["C"]["rendezvous"] == "0"
         and all(campaign["arms"][key].get("same_frame_continuation") is None for key in ("M", "I")),
         "V3 must declare the candidate-only continuation and disable rendezvous")
    from results_same_frame import reduce_receipt
    return "v3", campaign["observer_entrypoint"], reduce_receipt


def select_cases(campaign, requested, extended, diagnostic, development=False):
    registered={r["id"] for r in campaign["cases"]}
    need(len(requested)==len(set(requested)) and set(requested)<=registered,"Duplicate or unknown registered case")
    need(not (requested and extended),"Select cases or the extended campaign")
    registration=None
    if diagnostic:
        key,expected=DIAGNOSTICS[diagnostic]
        registration=campaign[key]
        need(registration.get("enabled", True) is True, "Diagnostic was explicitly retired in this protocol")
        need(registration["source"]=="candidate" and registration["order"]==expected,"Diagnostic source/order differs from its registered policy")
        eligible=registration.get("cases",[registration.get("case")])
        need(eligible and None not in eligible and len(eligible)==len(set(eligible)) and set(eligible)<=registered,"Invalid diagnostic case registration")
        need(development or not extended and (not requested or set(requested)<=set(eligible)),"Diagnostic case override requires --development")
        selected=set(requested) if requested else registered if extended else set(eligible)
    else:
        selected=set(requested) if requested else {r["id"] for r in campaign["cases"] if extended or r["primary"]}
    cases=[r for r in campaign["cases"] if r["id"] in selected]
    need(cases,"No registered cases")
    return cases,registration


def engine_command(engine, arguments, wrapper=None):
    command=[str(engine),*arguments]
    need(os.name!="nt" or wrapper is None,"Windows uses the direct Godot process, not an unverified wrapper")
    if wrapper is None:return command
    path=Path(wrapper)
    if not path.is_file():
        located=shutil.which(str(wrapper))
        need(located is not None,"Display wrapper not found")
        path=Path(located)
    path=path.resolve()
    if path.suffix==".py":return [sys.executable,str(path),*command]
    need(os.access(path,os.X_OK),"Display wrapper is not executable")
    if path.name=="xvfb-run":return [str(path),"-a","-s","-screen 0 1920x1080x24",*command]
    return [str(path),*command]


def physical_outcome_parity(arms):
    """Disclose equal-step outcomes separately from a matched initial workload."""
    identities = []
    for arm in arms:
        value=arm["statistics"]
        identities.append({"arm":arm["arm"],"index":arm["index"],"source":value["source"],
            "water_law":value["match"]["water_law"],"water_profile":value["match"]["water_profile"],
            "body_sha256":value["first_144_body_trajectory_sha256"],
            "admitted_moves_sha256":value["first_144_admitted_moves_sha256"],
            "command_counts":value["command_counts"],"command_mode":value["command_mode"]})
    pairs=[]
    for left in range(len(identities)):
        for right in range(left+1,len(identities)):
            a,b=identities[left],identities[right]
            pairs.append({"left_index":a["index"],"right_index":b["index"],
                "same_source":a["source"]==b["source"],"bodies_equal":a["body_sha256"]==b["body_sha256"],
                "admitted_moves_equal":a["admitted_moves_sha256"]==b["admitted_moves_sha256"]})
    same=[p for p in pairs if p["same_source"]]
    equal=all(p["bodies_equal"] and p["admitted_moves_equal"] for p in same) if same else None
    return {"arms":identities,"pairs":pairs,"same_source_pair_count":len(same),"same_source_pairs_equal":equal,
        "disposition":"No same-source repeat available; no paired outcome or causal timing conclusion." if equal is None else
                      "Same-source equal-step body and admitted-move outcomes agree; cross-source outcomes are disclosed, not assumed." if equal else
                      "Divergent same-source experiment: retain raw timing, refuse causal timing attribution.",
        "scope":"Different-source speed deltas are whole-source comparisons. Identical initial workload alone does not establish identical physical outcomes. Repeated input admission counts remain explicit and can differ with cadence."}


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()


def source_identity(root, development=False):
    root = Path(root).resolve()
    need((root / "godot/project.godot").is_file(), f"Missing source project: {root}")
    changed = git(root, "diff", "--name-only", "HEAD", "--", "godot", "native", "third_party").splitlines()
    untracked = git(root,"ls-files","--others","--exclude-standard","--","godot","native","third_party").splitlines()
    generated = {"godot/.godot/global_script_class_cache.cfg", "godot/.godot/extension_list.cfg"}
    need(development or not (set(changed) - generated) and not untracked, f"Application/runtime source is dirty or contains untracked inputs: {root}")
    return {"root": str(root), "source_commit": git(root, "rev-parse", "HEAD"), "source_tree": git(root, "rev-parse", "HEAD^{tree}"),
            "working_tree_changes": changed, "untracked_source_files":untracked,"qualified_exact_head": not bool(set(changed)-generated) and not untracked}


def archive_identities(manifest, expected_candidate, roots, engine, campaign, output):
    """Authenticate a pristine owner package without inventing a Git checkout.

    The package producer binds committed source projections, every shipped file,
    the independently built native closures, Rapier and engine. The caller must
    supply the expected candidate SHA from the handoff, not merely trust a label
    inside the package. Its dedicated verifier remains the authority here.
    """
    import importlib.util
    import hashlib
    manifest = Path(manifest).resolve()
    package = manifest.parent
    need(manifest.name == "PUBPRES-PLAYABILITY-MANIFEST.json", "Unknown archive manifest name")
    need(expected_candidate and len(expected_candidate) == 40 and all(c in "0123456789abcdef" for c in expected_candidate), "Archive mode requires --expected-candidate FULL_SHA from the handoff")
    need(Path(output).resolve() != package and package not in Path(output).resolve().parents, "Evidence output must be outside the pristine package")
    verifier = Path(__file__).resolve().parents[1] / "pubpres_playability_windows/package_windows.py"
    need(verifier.is_file(), "Packaged source verifier missing")
    spec = importlib.util.spec_from_file_location("pubpres_playability_package_verifier", verifier)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    record = module.verify(package, expected_candidate)
    need(Path(engine).resolve() == (package / record["engine"]["gui"]["path"]).resolve(), "Archive mode requires the manifest-bound direct Godot GUI executable")
    need(Path(campaign).resolve() == (package / record["campaign"]).resolve(), "Archive campaign path differs from the frozen package")
    sources = {}
    for letter, entry in record["sources"].items():
        root = (package / entry["root"]).resolve()
        need(Path(roots[letter]).resolve() == root, "Archive source root differs: " + letter)
        receipt = package / entry["native"]["receipt"]
        runtime = json.loads(receipt.read_text(encoding="utf-8"))
        binary = package / entry["native"]["path"]
        sources[letter] = {"root":str(root),"source_commit":entry["source_commit"],"source_tree":entry["source_tree"],
            "source_custody":"pristine inventoried source archive; no live Git checkout assertion",
            "qualified_exact_head":None,"qualified_source_archive":True,
            "archive_manifest_sha256":digest(manifest),"source_projection":entry["source_projection"],
            "native_runtime":{"manifest_path":str(receipt),"manifest_sha256":digest(receipt),
                "binary_path":str(binary),"binary_sha256":entry["native"]["sha256"],
                "staged_relative_path":"addons/cybersand_native/bin/"+runtime["runtime_file"],
                "source_inputs_sha256":hashlib.sha256(canonical(runtime["source_inputs_sha256"]).encode()).hexdigest(),
                "checked_source_files":len(runtime["source_inputs_sha256"]),"build_commit":entry["source_commit"],
                "toolchain":entry["toolchain"],"experimental_build":True}}
    return sources


def copy_project(source, target, imported=False):
    def ignored(folder, names):
        if Path(folder).name == ".godot":
            if imported:
                return {name for name in names if name == "shader_cache"}
            return set(names) - {".gdignore", "extension_list.cfg", "global_script_class_cache.cfg"}
        return {name for name in names if name in {".git", "__pycache__"}}
    shutil.copytree(source, target, ignore=ignored)


def descendant_pids(pid):
    pending, seen = [pid], set()
    while pending:
        value = pending.pop()
        if value in seen:
            continue
        seen.add(value)
        yield value
        try:
            pending.extend(int(x) for x in Path(f"/proc/{value}/task/{value}/children").read_text().split())
        except (OSError, ValueError):
            pass


def memory_sample(pid, elapsed_ms):
    if os.name == "nt":
        import ctypes
        from ctypes import wintypes
        class Counters(ctypes.Structure):
            _fields_ = [("cb",wintypes.DWORD),("PageFaultCount",wintypes.DWORD),
                ("PeakWorkingSetSize",ctypes.c_size_t),("WorkingSetSize",ctypes.c_size_t),
                ("QuotaPeakPagedPoolUsage",ctypes.c_size_t),("QuotaPagedPoolUsage",ctypes.c_size_t),
                ("QuotaPeakNonPagedPoolUsage",ctypes.c_size_t),("QuotaNonPagedPoolUsage",ctypes.c_size_t),
                ("PagefileUsage",ctypes.c_size_t),("PeakPagefileUsage",ctypes.c_size_t)]
        kernel=ctypes.WinDLL("kernel32",use_last_error=True)
        psapi=ctypes.WinDLL("psapi",use_last_error=True)
        kernel.OpenProcess.argtypes=(wintypes.DWORD,wintypes.BOOL,wintypes.DWORD)
        kernel.OpenProcess.restype=wintypes.HANDLE
        kernel.CloseHandle.argtypes=(wintypes.HANDLE,)
        psapi.GetProcessMemoryInfo.argtypes=(wintypes.HANDLE,ctypes.POINTER(Counters),wintypes.DWORD)
        psapi.GetProcessMemoryInfo.restype=wintypes.BOOL
        handle=kernel.OpenProcess(0x1000|0x10,False,pid)
        if not handle:raise OSError(ctypes.get_last_error(),"OpenProcess")
        try:
            value=Counters();value.cb=ctypes.sizeof(value)
            if not psapi.GetProcessMemoryInfo(handle,ctypes.byref(value),value.cb):raise OSError(ctypes.get_last_error(),"GetProcessMemoryInfo")
            return {"pid":pid,"elapsed_ms":elapsed_ms,"rss_bytes":value.WorkingSetSize,
                "peak_rss_bytes":value.PeakWorkingSetSize,"virtual_bytes":None,"commit_bytes":value.PagefileUsage}
        finally:kernel.CloseHandle(handle)
    values = {}
    for line in Path(f"/proc/{pid}/status").read_text().splitlines():
        key, _, value = line.partition(":")
        if key in {"VmRSS", "VmHWM", "VmSize"}:
            values[key] = int(value.split()[0]) * 1024
    return {"pid": pid, "elapsed_ms": elapsed_ms, "rss_bytes": values.get("VmRSS"), "peak_rss_bytes": values.get("VmHWM"), "virtual_bytes": values.get("VmSize")}


def execute(engine, args, folder, source_sha, settings, timeout, wrapper=None):
    folder.mkdir(parents=True, exist_ok=True)
    env = {k: v for k, v in os.environ.items() if not k.startswith("CYBERSAND_")}
    profile_variables=("APPDATA","LOCALAPPDATA") if os.name == "nt" else ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME")
    for name in profile_variables:
        path = folder / "profile" / name
        path.mkdir(parents=True, exist_ok=True)
        env[name] = str(path)
    env.update(settings, CYBERSAND_SOURCE_REVISION=source_sha, CYBERSAND_SOURCE_SHA=source_sha)
    env["PUBPRES_DISPLAY_RECEIPT"] = str(folder / "display-owner.json")
    command = engine_command(engine,args,wrapper)
    clock = time.monotonic()
    samples, child_pid = [], None
    timed_out, surviving_children = False, False
    process, failure, exit_code = None, None, None
    with (folder / "stdout.log").open("w") as out, (folder / "stderr.log").open("w") as err:
        try:
            with OwnedProcess(command, stdout=out, stderr=err, env=env) as owner:
                process = owner.process
                if os.name == "nt":child_pid=process.pid
                while process.poll() is None:
                    if time.monotonic() - clock > timeout:
                        timed_out = True
                        owner.close()
                        break
                    try:
                        if child_pid is None:
                            for pid in descendant_pids(process.pid):
                                executable = Path(f"/proc/{pid}/exe").resolve()
                                if executable == engine:
                                    child_pid = pid
                                    break
                        if child_pid is not None:
                            samples.append(memory_sample(child_pid, (time.monotonic() - clock) * 1000))
                    except (OSError, ValueError):
                        pass
                    time.sleep(0.25)
                exit_code = process.wait(timeout=10)
                surviving_children = owner.close() and not timed_out
        except BaseException as error:
            failure = error
            exit_code = process.returncode if process is not None else None
    result = {"command": command, "source_commit": source_sha, "elapsed_seconds": time.monotonic() - clock, "exit_code": exit_code,
              "timed_out": timed_out, "surviving_children_at_exit": surviving_children,
              "interruption": type(failure).__name__ + ": " + str(failure) if failure else None,
              "wrapper_pid": process.pid if process is not None else None, "observed_application_pid": child_pid,
              "sampled_peak_rss_bytes": max((s["peak_rss_bytes"] for s in samples if s["peak_rss_bytes"] is not None), default=None),
              "memory_scope": "250ms actual Godot process working-set/RSS samples including setup and capture; valid only after receipt PID match. Windows virtual size unavailable; commit reported separately."}
    if wrapper is not None:
        result["display_wrapper_sha256"] = digest(Path(shutil.which(str(wrapper)) or wrapper).resolve())
    if wrapper is not None and Path(wrapper).name == "owned_xvfb.py":
        display_path = folder / "display-owner.json"
        try:
            display = json.loads(display_path.read_text(encoding="utf-8")) if display_path.is_file() else {}
        except (ValueError, OSError) as error:
            display = {}
            result["display_owner_error"] = str(error)
        result["display_owner_sha256"] = digest(display_path) if display_path.is_file() else None
        result["display_owner_verified"] = bool(display.get("schema") == "pubpres-owned-display-v1"
            and display.get("wrapper_pid") == (process.pid if process is not None else None)
            and display.get("server_reaped") is True and display.get("forced_server_kill") is False
            and display.get("server_tree_closed") is True and display.get("unexpected_server_members") is False
            and display.get("server_returncode") in (0, -15)
            and display.get("server_alive_before_requested_shutdown") is True
            and display.get("application_returncode") == 0 and display.get("returncode") == 0
            and display.get("application_timeout") is False and display.get("failure") is None)
    write_json(folder / "process.json", result)
    write_json(folder / "process-memory.json", samples)
    if failure is not None:
        raise failure
    logs = (folder / "stdout.log").read_text() + (folder / "stderr.log").read_text()
    need(not timed_out and not surviving_children and exit_code == 0 and result.get("display_owner_verified", True)
        and not any(x in logs for x in ("SCRIPT ERROR:", "Parse Error:", "Failed to load script", "Failed loading resource:", "Error initializing GLAD", "MakeCurrent failed")), f"Process failed: {folder}")
    return result


def verify_native_runtime(root, manifest_path=None):
    """Fail closed when one source is paired with another source's native DLL/SO."""
    root = Path(root)
    manifest_path = Path(manifest_path) if manifest_path else root / ("godot/addons/cybersand_native/runtime-provenance.json" if os.name == "nt" else "godot/addons/cybersand_native/runtime-provenance.linux.json")
    record = json.loads(manifest_path.read_text())
    artifact = root / record["artifact"]
    need(artifact.is_file() and digest(artifact) == record["sha256"], "Native runtime does not match its build receipt")
    inputs = record.get("source_inputs", {})
    need(inputs, "Native runtime build receipt has no source inputs")
    tracked = git(root, "ls-files", "--", "native/include", "native/src", "godot/native_extension").splitlines()
    compiled = [p for p in tracked if Path(p).suffix in {".hpp", ".h", ".cpp", ".cc", ".c", ".inc", ".gdextension"}]
    need(compiled and all(p in inputs for p in compiled), "Native build receipt does not cover complete tracked implementation")
    checked = {}
    import hashlib
    for relative in compiled:
        raw = (root / relative).read_bytes().replace(b"\r\n", b"\n")
        observed = hashlib.sha256(raw).hexdigest()
        need(observed == inputs[relative], f"Native build/source mismatch: {relative}")
        checked[relative] = observed
    return {"manifest_path":str(manifest_path),"manifest_sha256":digest(manifest_path),"binary_sha256":digest(artifact),
            "binary_path":record["artifact"],"source_inputs_sha256":hashlib.sha256(canonical(checked).encode()).hexdigest(),
            "checked_source_files":len(checked),"build_commit":record.get("build_commit",record.get("source_commit"))}


def verify_experimental_runtime(root, source, folder):
    root, folder = Path(root), Path(folder).resolve()
    path = folder / "PUBPRES-RUNTIME.json"
    record = json.loads(path.read_text())
    need(record["schema"] == "pubpres-playability-native-build-v1" and record["returncode"] == 0, "Failed or unknown experimental native build")
    need(record.get("production_runtime_promotion") is False and record.get("toolchain_drift_allowed") is False, "Experimental build claims production promotion or unregistered toolchain drift")
    need(record["source_commit"] == source["source_commit"] and record["source_tree"] == source["source_tree"], "Native build identifies another source HEAD/tree")
    need(record["platform"] == ("windows" if os.name == "nt" else "linux"), "Native build platform differs from executing host")
    expected_runtime = "cybersand_native.windows.x86_64.dll" if os.name == "nt" else "libcybersand_native.linux.x86_64.so"
    expected_script = "tools/build_native_extension_windows.sh" if os.name == "nt" else "tools/build_native_extension.sh"
    need(record["runtime_file"] == expected_runtime and record["build_script"] == expected_script, "Wrong native runtime or build script path")
    binary = folder / record["runtime_file"]
    need(binary.is_file() and binary.stat().st_size == record["runtime_bytes"] and digest(binary) == record["runtime_sha256"], "Experimental native binary hash/size differs")
    import hashlib
    dirs = ("native/include","native/src","godot/native_extension")
    suffixes = {".c",".cc",".cpp",".cxx",".h",".hh",".hpp",".hxx",".inc",".inl",".tpp"}
    tracked = git(root,"ls-tree","-r","--name-only",source["source_commit"],"--",*dirs).splitlines()
    expected = {p for p in tracked if Path(p).suffix in suffixes}
    actual = {p.relative_to(root).as_posix() for d in dirs for p in (root/d).rglob("*") if p.is_file() and p.suffix in suffixes}
    inputs = record["source_inputs_sha256"]
    need(expected == actual == set(inputs), "Native build source closure differs")
    for relative, wanted in inputs.items():
        need(hashlib.sha256((root/relative).read_bytes().replace(b"\r\n",b"\n")).hexdigest() == wanted, "Native runtime source differs: "+relative)
    need(hashlib.sha256((root/record["build_script"]).read_bytes().replace(b"\r\n",b"\n")).hexdigest() == record["build_script_sha256"], "Native build script differs")
    driver = Path(__file__).resolve().parents[1] / "pubpres_playability_build/build_runtime.py"
    need(driver.is_file() and hashlib.sha256(driver.read_bytes().replace(b"\r\n",b"\n")).hexdigest() == record["driver_sha256"], "Native build driver differs")
    need((folder/"build.log").is_file() and digest(folder/"build.log") == record["log_sha256"], "Native build log missing or changed")
    dependency = dependency_custody.verify(folder, record)
    dependency_custody.verify_driver(driver.parent, record)
    return {"manifest_path":str(path),"manifest_sha256":digest(path),"binary_sha256":digest(binary),"binary_path":str(binary),
            "staged_relative_path":"addons/cybersand_native/bin/"+record["runtime_file"],"checked_source_files":len(inputs),
            "build_commit":record["source_commit"],"source_inputs_sha256":hashlib.sha256(canonical(inputs).encode()).hexdigest(),
            "dependency_builder_commit":dependency["builder_commit"],
            "toolchain":{k:record[k] for k in ("godot_cpp_commit","godot_cpp_library_sha256","godot_cpp_dependency_sha256","compiler_command","compiler_version","toolchain_drift_allowed")},
            "experimental_build":True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("main", "integration", "candidate", "engine", "output"):
        parser.add_argument("--"+name, type=Path, required=True)
    parser.add_argument("--campaign", type=Path, default=Path(__file__).with_name("campaign.json"))
    parser.add_argument("--display-wrapper", type=Path)
    parser.add_argument("--driver", choices=("opengl3", "opengl3_angle"), default="opengl3")
    parser.add_argument("--render-thread", choices=("safe", "separate"), default="safe")
    parser.add_argument("--case", action="append", default=[])
    parser.add_argument("--extended", action="store_true")
    parser.add_argument("--timeout", type=int, default=900)
    parser.add_argument("--development", action="store_true", help="Retain dirty source hashes and label result unqualified")
    parser.add_argument("--order", choices=("MICCIM","C","CC","CIIC"), default="MICCIM", help="Short orders require --development")
    parser.add_argument("--candidate-pool", choices=("eager","reachable"))
    parser.add_argument("--archive-manifest", type=Path, help="Verified pristine owner package; use its exact source roots, GUI engine and campaign")
    parser.add_argument("--expected-candidate", help="Full candidate SHA from owner handoff, mandatory for archive mode")
    parser.add_argument("--native-manifest", action="append", default=[], metavar="M=PATH")
    for letter in ("M","I","C"):
        parser.add_argument("--runtime-"+letter, type=Path, help="Exact-source experimental build directory with PUBPRES-RUNTIME.json")
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--observer-calibration", action="store_true", help="C-only full/reduced/reduced/full diagnostic")
    modes.add_argument("--input-equivalence", action="store_true", help="C-only repeated/once/once/repeated input diagnostic")
    modes.add_argument("--thread-calibration", action="store_true", help="C-only safe/separate/separate/safe diagnostic")
    modes.add_argument("--native-probe-calibration", action="store_true", help="C-only native stage probe off/on/on/off diagnostic")
    modes.add_argument("--same-frame-calibration", action="store_true", help="C-only same-frame continuation off/on/on/off diagnostic")
    args = parser.parse_args()
    campaign = json.loads(args.campaign.read_text())
    protocol, observer_script, reduce_receipt = measurement_protocol(campaign)
    need(campaign["order"] == list("MICCIM"), "Unbalanced source campaign")
    need(not args.same_frame_calibration or protocol == "v3", "Same-frame treatment requires the explicit V3 protocol")
    need(protocol != "v3" or args.render_thread == "safe" and not args.thread_calibration,
         "V3 continuation qualification uses Safe; retain Separate diagnostics under their original protocol")
    need(not args.output.exists(), "Output already exists; retain original evidence and choose a new directory")
    need(not (args.case and args.extended), "Select cases or the extended campaign")
    need(args.development or (args.order == "MICCIM" and args.candidate_pool is None), "Unregistered treatment override requires development label")
    diagnostic = "observer_calibration" if args.observer_calibration else "input_equivalence" if args.input_equivalence else "render_thread_calibration" if args.thread_calibration else "native_probe_calibration" if args.native_probe_calibration else "same_frame_calibration" if args.same_frame_calibration else None
    need(not diagnostic or args.order=="MICCIM","--order selects source comparisons; diagnostic order comes from registration")
    cases,diagnostic_registration=select_cases(campaign,args.case,args.extended,diagnostic,args.development)
    roots = {"M":args.main,"I":args.integration,"C":args.candidate}
    if args.archive_manifest:
        need(not args.native_manifest and all(getattr(args,"runtime_"+letter) is None for letter in roots), "Archive mode already binds all runtimes; do not mix external runtime overrides")
        sources = archive_identities(args.archive_manifest,args.expected_candidate,roots,args.engine,args.campaign,args.output)
    else:
        need(args.expected_candidate is None,"--expected-candidate requires --archive-manifest")
        sources = {letter:source_identity(root,args.development) for letter,root in roots.items()}
    need(sources["M"]["source_commit"] == campaign["source_commits"]["main"] and sources["I"]["source_commit"] == campaign["source_commits"]["integration"], "Registered historical source changed")
    manifests = dict(s.split("=",1) for s in args.native_manifest)
    need(set(manifests) <= {"M","I","C"}, "Unknown native manifest source")
    for letter, source in sources.items():
        if args.archive_manifest:continue
        runtime = getattr(args,"runtime_"+letter)
        need(runtime is not None or args.development, "Final campaign requires each source's newly built --runtime-"+letter)
        source["native_runtime"] = verify_experimental_runtime(source["root"],source,runtime) if runtime else verify_native_runtime(source["root"],manifests.get(letter))
    if not args.development:
        need(all(s["native_runtime"]["toolchain"] == sources["M"]["native_runtime"]["toolchain"] for s in sources.values()), "Source arms were built with different native toolchains")
        if not args.archive_manifest:
            need(all(s["native_runtime"]["dependency_builder_commit"] == sources["C"]["source_commit"] for s in sources.values()),
                 "Dependency builder source differs from the exact candidate")
    engine = args.engine.resolve()
    need(engine.is_file(), "Pinned Godot executable missing")
    order = list("CCCC") if diagnostic else list(args.order)
    arms_config = json.loads(json.dumps(campaign["arms"]))
    if args.candidate_pool is not None: arms_config["C"]["material_pool_policy"] = args.candidate_pool
    need(not arms_config["C"].get("wave_column_tiles"),"Retired four-column experiment cannot be scheduled in delivery campaign")
    applied_campaign = {**campaign,"arms":arms_config}
    output = args.output.resolve()
    projects = output / "project"
    projects.mkdir(parents=True)
    overlay = args.candidate.resolve()/"godot"
    overlay_hashes = {}
    for relative, expected in campaign["overlay_sha256"].items():
        actual = digest(overlay/relative)
        need(actual == expected, f"Frozen observation overlay changed: {relative}; version registration before running")
        overlay_hashes[relative] = actual
    shutil.copyfile(args.campaign, output/"campaign.json")
    case_orders = {c["id"]:(order if diagnostic or args.order != "MICCIM" else c.get("arm_order",order)) for c in cases}
    template_letters = set(letter for case_order in case_orders.values() for letter in case_order)
    if any(c.get("compatibility_preflight") for c in cases):template_letters.add("I")
    request = {"schema":"pubpres-playability-request-"+protocol,"sources":sources,"engine":str(engine),"engine_sha256":digest(engine),"order":order,"case_orders":case_orders,"cases":cases,
               "arms":arms_config,"campaign_sha256":digest(args.campaign),"overlay_sha256":overlay_hashes,"diagnostic":diagnostic,
               "observer_entrypoint":observer_script,
               "diagnostic_registration":diagnostic_registration,
               "development":args.development,"rendering_driver":args.driver,"render_thread":args.render_thread,"measurement":campaign["measurement"],
               "cache_policy":"Fresh source copy, process and profile per arm; driver-global caches uncontrolled and order-balanced"}
    write_json(output/"request.json",request)
    results,failures,templates = [],[],{}
    try:
        for letter in sorted(template_letters):
            project=projects/("template-"+letter)
            copy_project(Path(sources[letter]["root"])/"godot",project)
            runtime = sources[letter]["native_runtime"]
            if runtime.get("experimental_build"):
                target = project/runtime["staged_relative_path"]
                target.parent.mkdir(parents=True,exist_ok=True)
                shutil.copyfile(runtime["binary_path"],target)
                need(digest(target) == runtime["binary_sha256"], "Staged native binary differs")
            for relative, expected in overlay_hashes.items():
                target=project/relative
                target.parent.mkdir(parents=True,exist_ok=True)
                shutil.copyfile(overlay/relative,target)
                need(digest(target)==expected,"Overlay copy changed")
            print(f"Importing {letter} {sources[letter]['source_commit']}",flush=True)
            execute(engine,["--headless","--audio-driver","Dummy","--path",str(project),"--editor","--import"],output/("import-"+letter),sources[letter]["source_commit"],{},300)
            folder=output/("mailbox-identity-"+letter)
            receipt=folder/"receipt.json"
            execute(engine,["--headless","--audio-driver","Dummy","--path",str(project),
                "--script","res://tests/pubpres_playability_compatibility.gd","--","--mailbox-test",f"--receipt={receipt}"],
                folder,sources[letter]["source_commit"],{},120)
            mailbox=json.loads(receipt.read_text())
            expected_cases=(["actual_legacy_snapshot_type"] if letter=="M" else
                            ["actual_early_bootstrap","actual_early_completion","no_fallback_for_invalid_physics_owner"])
            need(mailbox.get("schema")=="pubpres-playability-mailbox-identity-v1" and mailbox.get("complete") is True
                 and mailbox.get("source_sha")==sources[letter]["source_commit"] and mailbox.get("engine_sha256")==digest(engine)
                 and mailbox.get("early_mailbox_available") is (letter!="M")
                 and [case.get("name") for case in mailbox.get("cases",[])]==expected_cases
                 and all(case.get("passed") is True for case in mailbox["cases"]),"Actual source mailbox identity contract failed")
            native_relative="addons/cybersand_native/bin/"+("cybersand_native.windows.x86_64.dll" if os.name=="nt" else "libcybersand_native.linux.x86_64.so")
            for relative in ("scripts/simulation_worker.gd","scripts/simulation_snapshot.gd",
                             "tests/pubpres_playability_compatibility.gd","tests/pubpres_playability_profile.gd",native_relative):
                need(mailbox["files"].get("res://"+relative)==digest(project/relative),"Actual mailbox source/runtime bytes differ")
            templates[letter]=project
        for case in cases:
            arms=[]
            case_order=case_orders[case["id"]]
            compatibility=None
            if case.get("compatibility_preflight"):
                folder=output/case["id"]/"I-compatibility"
                receipt=folder/"compatibility.json"
                execute(engine,["--headless","--audio-driver","Dummy","--path",str(templates["I"]),
                    "--script","res://tests/pubpres_playability_compatibility.gd","--",f"--receipt={receipt}"],
                    folder,sources["I"]["source_commit"],{},120)
                compatibility=json.loads(receipt.read_text())
                need(compatibility["complete"] and not compatibility["compatible"] and not compatibility["performance_capture_attempted"],"Historical gameplay compatibility changed; re-register comparison")
                need(compatibility["source_sha"]==sources["I"]["source_commit"] and compatibility["engine_sha256"]==digest(engine),"Compatibility source/runtime identity differs")
                runtime_resource="res://addons/cybersand_native/bin/"+("cybersand_native.windows.x86_64.dll" if os.name == "nt" else "libcybersand_native.linux.x86_64.so")
                need(compatibility["files"].get(runtime_resource)==sources["I"]["native_runtime"]["binary_sha256"],"Compatibility runtime differs")
                for relative in ("tests/pubpres_playability_compatibility.gd","tests/pubpres_playability_profile.gd"):
                    need(compatibility["files"].get("res://"+relative)==overlay_hashes[relative],"Compatibility observer changed")
                need(sorted(compatibility["unavailable_native_readback_fields"])==sorted(case["compatibility_preflight"]["unavailable_native_readback_fields"]),"Historical unsupported field set changed")
            for index,letter in enumerate(case_order):
                source,arm=sources[letter],dict(arms_config[letter])
                if args.native_probe_calibration:arm["wave_column_probe"]=diagnostic_registration["order"][index]
                if args.same_frame_calibration:arm["same_frame_continuation"]=diagnostic_registration["order"][index]
                folder=output/case["id"]/f"{index}-{letter}"
                project=projects/f"{case['id']}-{index}-{letter}"
                nonce=uuid.uuid4().hex
                observer=diagnostic_registration["order"][index] if args.observer_calibration else "full"
                command=diagnostic_registration["order"][index] if args.input_equivalence else campaign["measurement"]["command_mode"]
                render_thread=diagnostic_registration["order"][index] if args.thread_calibration else args.render_thread
                print(f"{case['id']} | {letter} ({index+1}/{len(case_order)}) | {observer} | {command} | {render_thread}",flush=True)
                try:
                    copy_project(templates[letter],project,imported=True)
                    receipt=folder/"receipt.json"
                    settings={"CYBERSAND_MATERIAL_PUBLICATION":arm["material"],"CYBERSAND_DIAG_PHYSICS_PUBLICATION":arm["physics"],
                        "CYBERSAND_DIAG_PRESENTATION":arm["presentation"],"CYBERSAND_DIAG_MATERIAL_TIMING":arm["timing"],
                        "CYBERSAND_DIAG_NATIVE_RENDEZVOUS":arm["rendezvous"],"CYBERSAND_DIAG_COMMON_OBSERVER":"0",
                        "CYBERSAND_PLAYABILITY_RENDER_THREAD":render_thread,"CYBERSAND_SHADER_NONCE":nonce,"CYBERSAND_SHADER_CACHE_STATE":"isolated-project-and-profile"}
                    if arm["cadence"]!="source-default":settings["CYBERSAND_DIAG_RENDER_CADENCE"]=arm["cadence"]
                    for key,field in (("CYBERSAND_PLAYABILITY_WAVE_COLUMN_TILES","wave_column_tiles"),("CYBERSAND_PLAYABILITY_WAVE_COLUMN_PROBE","wave_column_probe")):
                        if arm.get(field) is not None:settings[key]="1" if arm[field] else "0"
                    if arm.get("material_pool_policy") is not None:settings["CYBERSAND_DIAG_MATERIAL_POOL_POLICY"]=arm["material_pool_policy"]
                    if arm.get("same_frame_continuation") is not None:
                        need(letter == "C" and type(arm["same_frame_continuation"]) is bool,
                             "Same-frame treatment requires the candidate and an explicit boolean")
                        settings["CYBERSAND_DIAG_SAME_FRAME_CONTINUATION"]="1" if arm["same_frame_continuation"] else "0"
                    arguments=["--path",str(project),"--rendering-method","gl_compatibility","--rendering-driver",args.driver,
                        "--render-thread",render_thread,"--audio-driver","Dummy","--log-file",str(folder/"godot.log"),
                        "--script","res://"+observer_script,"--",f"--receipt={receipt}",f"--fixture={case['fixture']}",
                        f"--camera={case['camera']}",f"--workers={case['workers']}",f"--water-law={case['water_law']}",f"--water-variant={case.get('water_variant','reference')}",
                        f"--water-profile={case.get('water_profile',campaign['measurement']['water_profile'])}",
                        f"--input-mode={case.get('input_mode','tape')}",f"--command-mode={command}",f"--observer-mode={observer}"]
                    folder.mkdir(parents=True)
                    write_json(folder/"arm.json",{"source":source,"scenario":case,"arm":arm,"order_index":index,"nonce":nonce,"selectors":settings,"arguments":arguments})
                    process=execute(engine,arguments,folder,source["source_commit"],settings,args.timeout,args.display_wrapper)
                    data=json.loads(receipt.read_text())
                    need(data["source_identity"]["source_sha"]==source["source_commit"] and data["case_nonce"]==nonce and data["renderer"]==args.driver,"Source, nonce or driver changed")
                    need(data["render_thread"]=={"requested":render_thread,"runtime":render_thread},"Runtime rendering owner differs")
                    need(data["water_profile"]==case.get("water_profile",campaign["measurement"]["water_profile"]) and data["water_variant"]==case.get("water_variant","reference") and data["input_mode"]==case.get("input_mode","tape"),"Registered Water/input profile differs")
                    for key in ("fixture","camera","workers","water_law"):
                        observed=data[key]["name"] if key=="fixture" else data[key]
                        need(observed==case[key],"Registered case changed: "+key)
                    effective_campaign={**applied_campaign,"arms":{**arms_config,letter:arm}}
                    stats=reduce_receipt(receipt,effective_campaign,project,engine,letter)
                    process["app_sampler_pid_matched"]=process["observed_application_pid"]==data["process_id"]
                    if not process["app_sampler_pid_matched"]:process["sampled_peak_rss_bytes"]=None
                    write_json(folder/"process.json",process)
                    write_json(folder/"analysis.json",stats)
                    arms.append({"arm":letter,"index":index,"nonce":nonce,"process":process,"statistics":stats,"receipt_sha256":digest(receipt)})
                    shutil.rmtree(project)
                except Exception as error:
                    failures.append({"scenario":case["id"],"index":index,"reason":str(error)})
                    print(f"Arm incomplete; originals retained: {error}",flush=True)
            parity=physical_outcome_parity(arms)
            if parity["same_source_pairs_equal"] is False:
                failures.append({"scenario":case["id"],"reason":"Same-source paired physical outcomes diverged; timing retained, causal attribution refused"})
            if len(arms)!=len(case_order):failures.append({"scenario":case["id"],"reason":"Incomplete registered comparison"})
            if len(arms)==len(case_order):
                matches=[dict(r["statistics"]["match"]) for r in arms]
                if args.input_equivalence:
                    for m in matches:m.pop("command_mode",None)
                if args.observer_calibration:
                    for m in matches:m.pop("worker_capacities",None)
                if args.thread_calibration:
                    for m in matches:m.pop("render_thread",None)
                if any(canonical(m)!=canonical(matches[0]) for m in matches):failures.append({"scenario":case["id"],"reason":"Unmatched hardware, rendering owner, fixture or workload"})
            results.append({"scenario":case["id"],"arms":arms,"order":case_order,"compatibility_preflight":compatibility,"physical_outcome_parity":parity})
            write_json(output/"summary.json",{"complete":False,"physical_acceptance":"HOLD","cases":results,"failures":failures})
    except Exception as error:failures.append({"reason":str(error)})
    finally:
        complete=not failures and len(results)==len(cases)
        write_json(output/"summary.json",{"schema":"pubpres-playability-comparison-"+protocol,"complete":complete,"physical_acceptance":"HOLD","development":args.development,
            "diagnostic":diagnostic,"cases":results,"failures":failures,"sources":sources,"order":order,
            "meaning":"Capture completion is not a performance win or owner NVIDIA acceptance. Retain both repeats, all failures and tail/freshness distributions."})
        print(f"Results: {output} | complete={complete} | HOLD",flush=True)
    return 0 if complete else 1


if __name__=="__main__":
    sys.exit(main())
