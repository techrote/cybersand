#!/usr/bin/env bash
# Explicit Stage A source build and resident CPU inference; never training.
set -euo pipefail
test -n "${RUNNER_TEMP:-}"
test -n "${GITHUB_SHA:-}"
evidence="${DRIV3R_EVIDENCE:-evidence/driv3r}"
test ! -e "$evidence"
mkdir -p "$evidence/build"
trap 'result=$?; printf "{\"exit_code\":%s,\"phase\":\"bootstrap-or-qualification\"}\n" "$result" > "$evidence/bootstrap-exit.json"' EXIT
test "$(git rev-parse HEAD)" = "$GITHUB_SHA"
python3 -m experiments.driv3r.provenance request --source-sha "$GITHUB_SHA" --output "$evidence/request.json"
python3 -m experiments.driv3r.provenance source --source-sha "$GITHUB_SHA" --output "$evidence/source-custody.json"
python3 tools/ci/check_ci_provider_policy.py > "$evidence/build/ci-provider.json"
python3 - "$evidence/build/host.json" <<'PY'
import json, os, pathlib, platform, subprocess, sys
data = {"platform": platform.platform(), "python": sys.version,
        "cpu_count": os.cpu_count(), "affinity": sorted(os.sched_getaffinity(0)),
        "cpuinfo": pathlib.Path('/proc/cpuinfo').read_text(),
        "meminfo": pathlib.Path('/proc/meminfo').read_text(),
        "compiler": subprocess.check_output(['/usr/bin/g++-13', '--version'], text=True),
        "linker": subprocess.check_output(['ld', '--version'], text=True),
        "workflow_run": os.environ.get('GITHUB_RUN_ID'),
        "workflow_attempt": os.environ.get('GITHUB_RUN_ATTEMPT')}
pathlib.Path(sys.argv[1]).write_text(json.dumps(data, indent=2) + '\n')
PY

git lfs install --local
timeout 600 git lfs pull --include='godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so' --exclude='' > "$evidence/build/rapier-acquisition.log" 2>&1
echo '566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a  godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so' | sha256sum -c --strict

python3 -m venv "$RUNNER_TEMP/driv3r-python"
export DRIV3R_PYTHON="$RUNNER_TEMP/driv3r-python/bin/python"
"$DRIV3R_PYTHON" -m pip install --require-hashes -r tools/requirements-build.txt > "$evidence/build/install-scons.log" 2>&1
"$DRIV3R_PYTHON" -m pip install 'Pillow==13.0.0' > "$evidence/build/install-pillow.log" 2>&1
"$DRIV3R_PYTHON" -m pip freeze > "$evidence/build/python-environment.txt"
export GODOT_CPP_ROOT="$RUNNER_TEMP/driv3r-godot-cpp"
export SCONS_PYTHON="$DRIV3R_PYTHON"
export SCONS_JOBS=4
export CYBERSAND_REAL_CXX=/usr/bin/g++-13
export LINUX_CXX=/usr/bin/g++-13
export CYBERSAND_NATIVE_OUTPUT="$RUNNER_TEMP/driv3r-native.so"
mkdir -p "$GODOT_CPP_ROOT"
git -C "$GODOT_CPP_ROOT" init
git -C "$GODOT_CPP_ROOT" remote add origin https://github.com/godotengine/godot-cpp.git
timeout 600 git -C "$GODOT_CPP_ROOT" fetch --depth=1 origin 101ae38034304346a46ea9ea84ae156d3e860496 > "$evidence/build/godot-cpp-fetch.log" 2>&1
git -C "$GODOT_CPP_ROOT" checkout --detach FETCH_HEAD
if ! timeout 3600 bash tools/build_pinned_godot_cpp.sh linux > "$evidence/build/godot-cpp.log" 2>&1; then tail -100 "$evidence/build/godot-cpp.log"; exit 1; fi
if ! timeout 3600 bash tools/build_native_extension.sh > "$evidence/build/native.log" 2>&1; then tail -100 "$evidence/build/native.log"; exit 1; fi
cp "$CYBERSAND_NATIVE_OUTPUT" godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so
bash tools/check_linux_runtime_floor.sh > "$evidence/build/abi-floor.log" 2>&1
python3 experiments/agent_painter/native/runtime.py stamp --source-sha "$GITHUB_SHA" --output "$evidence/native-build.json"
mkdir -p "$evidence/build/runtime"
cp "$CYBERSAND_NATIVE_OUTPUT" "$evidence/build/runtime/libcybersand_native.linux.x86_64.so"
sha256sum "$GODOT_CPP_ROOT/bin/libgodot-cpp.linux.template_debug.x86_64.a" > "$evidence/build/godot-cpp-library.sha256"

timeout 600 curl -fsSL --retry 3 -o "$RUNNER_TEMP/driv3r-godot.zip" 'https://downloads.godotengine.org/?flavor=stable&platform=linux.64&slug=linux.x86_64.zip&version=4.7'
echo "0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c  $RUNNER_TEMP/driv3r-godot.zip" | sha256sum -c --strict
mkdir -p "$RUNNER_TEMP/driv3r-godot"
unzip -q "$RUNNER_TEMP/driv3r-godot.zip" -d "$RUNNER_TEMP/driv3r-godot"
export GODOT_BIN="$RUNNER_TEMP/driv3r-godot/Godot_v4.7-stable_linux.x86_64"
chmod +x "$GODOT_BIN"
"$GODOT_BIN" --version > "$evidence/build/godot-version.txt"
if ! timeout 1200 "$GODOT_BIN" --headless --path godot --editor --quit > "$evidence/build/import.log" 2>&1; then tail -100 "$evidence/build/import.log"; exit 1; fi

# The Q8 weights and resident runtime stay in temporary storage. Original
# acquisition, model identity, questions and outcomes remain in evidence.
"$DRIV3R_PYTHON" -m experiments.driv3r.backend acquire --runtime-dir "$RUNNER_TEMP/driv3r-runtime" --evidence "$evidence/acquisition" --timeout-seconds 1200
timeout 2700 "$DRIV3R_PYTHON" -m experiments.driv3r.qualify --godot "$GODOT_BIN" --runtime-manifest "$evidence/native-build.json" --source-sha "$GITHUB_SHA" --runtime-dir "$RUNNER_TEMP/driv3r-runtime" --output "$evidence/execution"
