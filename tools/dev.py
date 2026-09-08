#!/usr/bin/env python3
"""Small, logged wrappers around the source project's existing build tools."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "source"
WINDOWS = os.name == "nt"
ENV = os.environ.copy()
CONFIG = ROOT / ".local/dev-config.json"
if CONFIG.exists():
    for key, value in json.loads(CONFIG.read_text()).items():
        ENV.setdefault(key, str(value))

def setting(key: str, default: str) -> str:
    value = ENV.get(key, default)
    path = Path(value).expanduser()
    if not path.is_absolute() and (ROOT / path).exists():
        value = str((ROOT / path).resolve())
    return value.replace("\\", "/")

GODOT = setting("GODOT_BIN", ".local/godot-4.7/Godot_v4.7-stable_win64_console.exe" if WINDOWS else "godot")
SDK = Path(setting("EMSDK", ".local/emsdk"))
CPP_WEB = setting("GODOT_CPP_WEB", ".local/godot-cpp-web")
CPP_NATIVE = setting("GODOT_CPP_NATIVE", ".local/godot-cpp-native")
LLVM = Path(setting("LLVM_MINGW_ROOT", ".local/llvm-mingw-20260826-ucrt-x86_64"))
GIT = Path(setting("GIT_ROOT", ".local/git"))
TEMPLATES = setting("WEB_TEMPLATE_ROOT", ".local/web-templates")
ENV.setdefault("EMSDK", str(SDK))
ENV.setdefault("EM_CONFIG", str(SDK / ".emscripten"))
if WINDOWS:
    ENV.setdefault("EMSDK_PYTHON", str(SDK / "python/3.13.3_64bit/python.exe"))
ENV.setdefault("SCONS_JOBS", "6")
ENV["PATH"] = os.pathsep.join(map(str, [Path(sys.executable).parent, LLVM / "bin", GIT / "cmd", GIT / "usr/bin", GIT / "mingw64/bin", SDK / "upstream/emscripten"])) + os.pathsep + ENV.get("PATH", "")
# Codex's sandbox and the normal Windows account have different owners. Trust
# only our two explicit local bindings checkouts in this child environment;
# do not change global Git configuration or disable revision/dirty checks.
config_count = int(ENV.get("GIT_CONFIG_COUNT", "0"))
for checkout in (CPP_NATIVE, CPP_WEB):
    path = Path(checkout).resolve()
    if path.is_relative_to((ROOT / ".local").resolve()):
        ENV[f"GIT_CONFIG_KEY_{config_count}"] = "safe.directory"
        ENV[f"GIT_CONFIG_VALUE_{config_count}"] = path.as_posix()
        config_count += 1
ENV["GIT_CONFIG_COUNT"] = str(config_count)
STAMP = time.strftime("%Y%m%d-%H%M%S")
LOGS = ROOT / "validation/local" / STAMP

def run(name: str, command: list[str], cwd: Path = SOURCE, timeout: int = 1200, godot: bool = False) -> dict:
    command = list(map(str, command))
    executable = shutil.which(command[0], path=ENV["PATH"])
    if executable is None:
        raise RuntimeError(f"Executable not found: {command[0]}")
    command[0] = executable
    LOGS.mkdir(parents=True, exist_ok=True)
    log = LOGS / f"{name}.log"
    print("+", subprocess.list2cmdline(command), flush=True)
    start = time.perf_counter()
    with log.open("w", encoding="utf-8") as stream:
        stream.write("COMMAND: " + json.dumps(command) + "\n")
        stream.flush()
        process = subprocess.Popen(command, cwd=cwd, env=ENV, stdout=stream, stderr=subprocess.STDOUT)
        try:
            code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            if WINDOWS:
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True)
            else:
                process.kill()
            process.wait()
            code = 124
    output = log.read_text(encoding="utf-8", errors="replace")
    passed = code == 0 and (not godot or "ERROR:" not in output)
    result = dict(command=command, cwd=str(cwd), exit_code=code, passed=passed, elapsed_seconds=round(time.perf_counter()-start, 3), log=str(log.relative_to(ROOT)))
    if name == "native-test":
        result["passed_tests"] = len(re.findall(r"^\[pass\]", output, re.M | re.I))
    log.with_suffix(".json").write_text(json.dumps(result, indent=2) + "\n")
    print("\n".join(output.splitlines()[-8:]), flush=True)
    print(json.dumps(result), flush=True)
    if not passed:
        raise RuntimeError(f"{name} failed; inspect {log}")
    return result

def native_environment() -> None:
    if Path(CPP_WEB).resolve() == Path(CPP_NATIVE).resolve():
        raise RuntimeError("Native and Web godot-cpp checkouts must be separate")
    ENV["GODOT_CPP_ROOT"] = CPP_NATIVE
    ENV["SCONS_PYTHON"] = Path(sys.executable).as_posix()
    if WINDOWS:
        ENV["LLVM_MINGW_ROOT"] = LLVM.as_posix()
        ENV["WINDOWS_CXX"] = (LLVM / "bin/x86_64-w64-mingw32-g++.exe").as_posix()

def web_command() -> list[str]:
    base = json.loads((ROOT / "SOURCE-PROVENANCE.json").read_text())["commit"]
    return [sys.executable, "tools/build_web.py", "--cpp", CPP_WEB, "--godot", GODOT, "--templates", TEMPLATES, "--source-commit", base]

def clean() -> None:
    # Build/cache artifacts only; never source, SDKs, native DLLs or user saves.
    base = (SOURCE / "build").resolve()
    if not base.is_relative_to(SOURCE.resolve()) or base.name != "build":
        raise RuntimeError("Refusing unsafe clean target")
    if base.exists():
        print("Removing generated directory:", base)
        shutil.rmtree(base)

def http_smoke(url: str, profile: str = "compat") -> None:
    results = []
    variant = "threads" if profile == "threaded" else "nothreads"
    with urllib.request.urlopen(url.rstrip("/") + "/build-info.json", timeout=30) as response:
        identity = json.load(response)
    assert identity["profile"] == profile, "Served profile differs from requested profile"
    names = ["index.html", "index.js", "index.wasm", "index.side.wasm", "index.pck", f"libcybersand_native.web.{variant}.wasm"]
    if identity["rapier"] != "disabled":
        names += ["godot_rapier.wasm", "RAPIER_LICENSE.txt", "RAPIER_THIRDPARTY.txt"]
    for name in names:
        with urllib.request.urlopen(url.rstrip("/") + "/" + name, timeout=60) as response:
            data = response.read()
            assert response.status == 200 and len(data) > 100, name
            assert response.headers["Cross-Origin-Opener-Policy"] == "same-origin"
            assert response.headers["Cross-Origin-Embedder-Policy"] == "require-corp"
            if name.endswith(".wasm"):
                assert data[:8] == b"\x00asm\x01\x00\x00\x00", name
                assert response.headers.get_content_type() == "application/wasm"
            if name == "godot_rapier.wasm":
                assert hashlib.sha256(data).hexdigest() == identity["rapier_sha256"], name
            results.append(dict(file=name, bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))
    LOGS.mkdir(parents=True, exist_ok=True)
    (LOGS / "http-smoke.json").write_text(json.dumps(results, indent=2) + "\n")
    print(f"{len(results)}/{len(results)} HTTP payload checks passed. This does not test browser execution.")

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["doctor", "native-test", "native-bindings", "native-build", "godot-test", "benchmark", "stress-test", "web-build", "web-export", "web", "clean", "rebuild", "preview", "http-smoke"])
    parser.add_argument("--url", default="http://127.0.0.1:8000/")
    parser.add_argument("--open", action="store_true")
    parser.add_argument("--profile", choices=["compat", "threaded"], default="compat")
    args = parser.parse_args()
    action = args.action
    if action == "doctor":
        for name, cmd in [("python", [sys.executable, "--version"]), ("godot", [GODOT, "--version"]), ("emcc", ["emcc", "--version"]), ("em++", ["em++", "--version"]), ("scons", [sys.executable, "-m", "SCons", "--version"]), ("compiler", ["clang++" if WINDOWS else "g++", "--version"])]:
            run(name, cmd, ROOT)
    elif action == "native-test":
        (SOURCE / "build").mkdir(exist_ok=True)
        run(action, ["mingw32-make" if WINDOWS else "make", "test", "CXX=" + ENV.get("CXX", "clang++" if WINDOWS else "g++"), "CC=" + ENV.get("CC", "clang" if WINDOWS else "gcc")])
    elif action in ("native-bindings", "native-build"):
        native_environment()
        script = "tools/build_pinned_godot_cpp.sh" if action == "native-bindings" else "tools/build_native_extension_windows.sh" if WINDOWS else "tools/build_native_extension.sh"
        cmd = [str(GIT / "usr/bin/bash.exe") if WINDOWS else "bash", script]
        if action == "native-bindings":
            cmd.append("windows" if WINDOWS else "linux")
        run(action, cmd, timeout=3600)
    elif action == "godot-test":
        project = SOURCE / "godot"
        run("godot-import", [GODOT, "--headless", "--editor", "--path", project, "--import"], timeout=240, godot=True)
        results = []
        for fixture in sorted((project / "tests").glob("test_*.gd")):
            results.append(run(fixture.stem, [GODOT, "--headless", "--path", project, "--script", "res://tests/" + fixture.name], timeout=180, godot=True))
        (LOGS / "godot-fixtures.json").write_text(json.dumps(results, indent=2) + "\n")
        print(f"{len(results)}/{len(results)} Godot fixtures passed")
    elif action in ("benchmark", "stress-test"):
        LOGS.mkdir(parents=True, exist_ok=True)
        command = [GODOT, "--headless", "--path", SOURCE / "godot", "--script", "res://tests/run_worker_benchmark.gd", "--", "--report=" + str(LOGS / (action + "-results.json"))]
        if action == "stress-test":
            command.append("--stress")
        run(action, command, timeout=1200, godot=True)
    elif action in ("web-build", "web-export", "web", "rebuild"):
        if action == "rebuild":
            clean()
        cmd = web_command()
        cmd += ["--profile", args.profile]
        if action == "web-build":
            cmd.append("--compile-only")
        if action == "web-export":
            cmd.append("--export-only")
        run(action, cmd)
    elif action == "clean":
        clean()
    elif action == "preview":
        subprocess.run([sys.executable, ROOT / "preview.py", *(["--open"] if args.open else [])], cwd=ROOT, check=True)
    elif action == "http-smoke":
        http_smoke(args.url, args.profile)

if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.SubprocessError, AssertionError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1)
