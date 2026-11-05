#!/usr/bin/env python3
"""Source-locked LA-SOL-SURROGATE-001 host runner and evidence custody.

Uses copied projects and retained, independently authenticated #394 runtimes.
Never builds into a tracked runtime, changes modes in flight, or composes SOL.
Run from the source root on Windows with WSL Ubuntu-24.04 installed.
"""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/la-selective"
BASE = "f44488e9b24c61db3924685ef3723296ab768533"
ENGINES = {
    "windows": "C:/Godot47/Godot_v4.7-stable_win64_console.exe",
    "linux": "/home/i/cybersand-play-auto004-tools/Godot_v4.7-stable_linux.x86_64",
}
SCOPED = ["fleet_session", "pilot_ui", "desktop_interest", "physics_play", "hard_placement",
          "input", "live_liquid_edit", "retained_pressure", "failure_recovery", "liquid_edges",
          "boundary_retention", "canvas"]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args])


def wsl_path(path):
    s = str(path).replace("\\", "/")
    return "/mnt/" + s[0].lower() + s[2:]


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def command(name, argv, folder, env=None, timeout=180):
    folder.mkdir(parents=True, exist_ok=True)
    log = folder / (name + ".log")
    if log.exists():
        raise RuntimeError("Refuse overwriting retained run: " + str(log))
    start = time.monotonic()
    effective_argv = list(argv)
    # Bound the real Linux process group inside WSL, as well as its Windows
    # client. Killing wsl.exe alone does not prove that Linux work has stopped.
    is_wsl = Path(argv[0]).name.lower() in {"wsl", "wsl.exe"}
    if is_wsl:
        delimiter = effective_argv.index("--") + 1
        effective_argv[delimiter:delimiter] = ["timeout", "--signal=TERM", "--kill-after=5s", str(timeout)+"s"]
    with log.open("wb") as handle:
        process = subprocess.Popen(effective_argv, cwd=ROOT, env=env, stdout=handle, stderr=subprocess.STDOUT,
                                   start_new_session=os.name != "nt")
        try:
            code = process.wait(timeout=timeout+10 if is_wsl else timeout)
        except subprocess.TimeoutExpired:
            code = 124
            if os.name == "nt":
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                               stdout=handle, stderr=subprocess.STDOUT, timeout=10)
            else:
                import signal
                os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=10)
    text = log.read_text(encoding="utf-8", errors="replace")
    clean = code == 0 and not any(s in text for s in
        ["SCRIPT ERROR:", "ERROR:", "ObjectDB instances leaked", "resources still in use",
         "runtime error:", "AddressSanitizer:"])
    result = dict(name=name, command=effective_argv, requested_command=argv, exit=code, clean=clean, timeout_seconds=timeout,
                  seconds=time.monotonic()-start, log=str(log.relative_to(ROOT)),
                  log_sha256=sha(log.read_bytes()), markers=[line for line in text.splitlines()
                  if "checks=" in line or "failures=" in line or "assertions" in line][-5:])
    write(folder / (name + ".receipt.json"), result)
    print(name, code, clean, result["markers"], flush=True)
    return result


def authenticate():
    subprocess.run(["git", "-C", str(ROOT), "merge-base", "--is-ancestor", BASE, "HEAD"], check=True)
    source = git("rev-parse", "HEAD").decode().strip()
    inventories = {}
    suffixes = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".tpp"}
    paths = {p.relative_to(ROOT).as_posix() for d in ["native/include", "native/src", "godot/native_extension"]
             for p in (ROOT/d).rglob("*") if p.is_file() and p.suffix in suffixes}
    for platform, filename in [("windows", "runtime-provenance.json"), ("linux", "runtime-provenance.linux.json")]:
        manifest_path = "godot/addons/cybersand_native/"+filename
        manifest_bytes = (ROOT/manifest_path).read_bytes().replace(b"\r\n", b"\n")
        assert manifest_bytes == git("show", source+":"+manifest_path), "mutable runtime provenance"
        manifest = json.loads(manifest_bytes)
        assert paths == set(manifest["source_inputs"]), "incomplete runtime inventory"
        for path, digest in manifest["source_inputs"].items():
            assert sha((ROOT/path).read_bytes().replace(b"\r\n", b"\n")) == digest, path
            assert git("show", BASE+":"+path) == git("show", source+":"+path), path
        assert sha((ROOT/manifest["artifact"]).read_bytes()) == manifest["sha256"]
        rapier_path = "godot/addons/godot-rapier2d/runtime-provenance."+platform+".json"
        rapier_bytes = (ROOT/rapier_path).read_bytes().replace(b"\r\n", b"\n")
        assert rapier_bytes == git("show",source+":"+rapier_path), "mutable Rapier provenance"
        rapier = json.loads(rapier_bytes)
        assert sha((ROOT/rapier["artifact"]).read_bytes()) == rapier["sha256"]
        for path,digest in rapier["source_inputs"].items():
            assert sha((ROOT/path).read_bytes().replace(b"\r\n",b"\n")) == digest, path
        if platform == "windows":
            launcher_hash = sha(Path(ENGINES[platform]).read_bytes())
            # The official Windows console launcher starts the sibling engine.
            engine_hash = sha(Path(ENGINES[platform].replace("_console.exe",".exe")).read_bytes())
            version = subprocess.check_output([ENGINES[platform],"--version"]).decode().strip()
        else:
            engine_hash = subprocess.check_output(["wsl","-d","Ubuntu-24.04","--","sha256sum",ENGINES[platform]]).decode().split()[0]
            version = subprocess.check_output(["wsl","-d","Ubuntu-24.04","--",ENGINES[platform],"--version"]).decode().strip()
        assert engine_hash == manifest["godot_executable_sha256"] and version == manifest["godot_version"]
        manifest["authenticated_engine"] = dict(path=ENGINES[platform],sha256=engine_hash,version=version,
            launcher_sha256=launcher_hash if platform=="windows" else engine_hash)
        manifest["authenticated_rapier"] = rapier
        inventories[platform] = manifest
    dependencies = {p: sha((ROOT/p).read_bytes()) for p in git("ls-files", "godot/addons", "third_party").decode().splitlines()
                    if (ROOT/p).is_file() and ("/bin/" in p or p.endswith("lock.json"))}
    result = dict(source=source, tree=git("rev-parse", "HEAD^{tree}").decode().strip(), base=BASE,
                  branch=git("branch", "--show-current").decode().strip(), runtimes=inventories,
                  dependencies=dependencies,
                  local_delta=git("status", "--short").decode(),
                  profile_sha256=sha((ROOT/"godot/tests/fixtures/la_selective/registration.json").read_bytes()))
    result["test_inputs"] = {p:sha((ROOT/p).read_bytes()) for p in [
        "native/tests/test_la_selective_experiment.cpp","godot/tests/test_la_selective_experiment.gd",
        "godot/tests/fixtures/la_selective/registration.json","godot/tests/fixtures/la_selective/registration-full-path.json",
        "godot/tests/fixtures/la_selective/registration-primed.json",
        "tools/experiments/la_selective_experiment.py"]}
    return result


def hosts(scope):
    identity = authenticate()
    names = git("ls-files", "godot").decode().splitlines()
    inputs = {n: sha((ROOT/n).read_bytes()) for n in names if (ROOT/n).is_file()}
    assert "godot/tests/test_la_selective_experiment.gd" in inputs, "commit fixture before execution"

    def platform_run(platform):
        folder = OUT / ("hosts-"+scope) / platform
        project = folder / "godot"
        if project.exists():
            raise RuntimeError("New output scope required; preserve old runs")
        for name in inputs:
            target = project/Path(name).relative_to("godot")
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT/name, target)
        rows = []
        env = dict(os.environ, CYBERSAND_SOURCE_REVISION=identity["source"])
        tests = [("import", None)]
        if scope in ["comparison","comparison-full","comparison-primed"]: tests += [("experiment-w1", 1), ("experiment-w4", 4)]
        elif scope == "scoped": tests += [("workbench_"+s, None) for s in SCOPED]
        else: raise ValueError(scope)
        for name, workers in tests:
            args = [ENGINES[platform], "--headless", "--audio-driver", "Dummy", "--path",
                    str(project) if platform == "windows" else wsl_path(project)]
            current_env = env.copy()
            if name == "import": args += ["--editor", "--quit"]
            else:
                script = "la_selective_experiment" if workers else name
                args += ["--max-fps", "120", "--script", "res://tests/test_"+script+".gd"]
            if workers:
                result_path = folder/(name+".json")
                current_env["LA_EXPERIMENT_WORKERS"] = str(workers)
                current_env["LA_EXPERIMENT_OUTPUT"] = str(result_path) if platform == "windows" else wsl_path(result_path)
                suffix={"comparison":"","comparison-full":"-full-path","comparison-primed":"-primed"}[scope]
                current_env["LA_EXPERIMENT_PROFILE"] = "res://tests/fixtures/la_selective/registration"+suffix+".json"
            if platform == "linux":
                forwarded = ["CYBERSAND_SOURCE_REVISION="+identity["source"]]
                if workers: forwarded += [k+"="+current_env[k] for k in ["LA_EXPERIMENT_WORKERS", "LA_EXPERIMENT_OUTPUT","LA_EXPERIMENT_PROFILE"]]
                args = ["wsl", "-d", "Ubuntu-24.04", "--", "env", *forwarded, *args]
            row = command(name, args, folder, current_env, 300 if workers else 180)
            if workers:
                assert result_path.exists(), "missing experiment observations"
                data=json.loads(result_path.read_text())
                assert data["source"] == identity["source"] and data["failures"] == [] and len(data["episodes"])==32
                assert all(e["workers"]==workers and len(e["steps"])==24 for e in data["episodes"])
                row["data_sha256"] = sha(result_path.read_bytes())
            rows.append(row)
            write(folder/"receipt.json", dict(identity=identity, inputs=inputs, results=rows))
            if name=="import" and not row["clean"]: break
        return rows
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = dict(zip(ENGINES, pool.map(platform_run, ENGINES)))
    assert all(sha((ROOT/n).read_bytes()) == h for n,h in inputs.items()), "source mutated during execution"
    write(OUT/("hosts-"+scope)/"result.json", dict(source=identity["source"], results=results))
    return all(r["clean"] for rows in results.values() for r in rows)


def native():
    identity = authenticate()
    folder = OUT/"native-qualified"
    write(folder/"identity-at-start.json",identity)
    linux_root = wsl_path(ROOT)
    sources = ["world", "material_rules", "scheduler_geometry", "settled_world_discovery"]
    results = []
    for variant in ["opt", "san"]:
        flags = ["-O3", "-DNDEBUG"] if variant == "opt" else ["-O1", "-g1", "-fno-omit-frame-pointer", "-fsanitize=address,undefined"]
        prefix = ["wsl", "-d", "Ubuntu-24.04", "--cd", linux_root, "--"]
        objects = []
        for name in sources:
            target = (folder/(variant+"-"+name+".o")).relative_to(ROOT).as_posix()
            row = command("compile-"+variant+"-"+name, prefix+["g++", "-std=c++20", "-pthread", "-Inative/include", *flags,
                          "-c", "native/src/"+name+".cpp", "-o", target], folder, timeout=900)
            results.append(row)
            if not row["clean"]: return False
            objects.append(target)
        for test in ["la_selective_experiment", "workbench_arrivals", "workbench_pressure_heads"]:
            binary = (folder/(variant+"-"+test)).relative_to(ROOT).as_posix()
            row = command("link-"+variant+"-"+test,prefix+["g++", "-std=c++20", "-pthread", "-Inative/include", *flags,
                          *objects, "native/tests/test_"+test+".cpp", "-o", binary],folder,timeout=180)
            results.append(row)
            if not row["clean"]: return False
            extra = ["env", "ASAN_OPTIONS=detect_leaks=1:halt_on_error=1", "UBSAN_OPTIONS=halt_on_error=1"] if variant=="san" else []
            row = command("run-"+variant+"-"+test,prefix+extra+[binary],folder,timeout=180)
            row["binary_sha256"]=sha((ROOT/binary).read_bytes())
            results.append(row)
            write(folder/"receipt.json", dict(source=identity["source"],results=results))
            if not row["clean"]: return False
    after=authenticate()
    assert after["test_inputs"]==identity["test_inputs"] and after["runtimes"]==identity["runtimes"]
    write(folder/"identity-at-finish.json",after)
    return True


def main():
    global OUT
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("stage", choices=["identity", "comparison", "comparison-full", "comparison-primed", "scoped", "native"])
    parser.add_argument("--run", default="la-selective", help="new bounded output directory name under build")
    args = parser.parse_args()
    assert Path(args.run).name==args.run and args.run not in [".",".."]
    OUT=ROOT/"build"/args.run
    OUT.mkdir(parents=True, exist_ok=True)
    if args.stage=="identity": write(OUT/"identity.json",authenticate()); return 0
    return int(not (native() if args.stage=="native" else hosts(args.stage)))


if __name__ == "__main__":
    raise SystemExit(main())
