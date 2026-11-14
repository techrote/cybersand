#!/usr/bin/env bash
# Explicit Stage C source build, resident Q8 evaluation and original evidence.
# This narrow bootstrap repeats Stage A's accepted pins intentionally: changing
# the already-qualified A script or #568-owned build contracts would mix scope.
set -euo pipefail
test -n "${RUNNER_TEMP:-}"
test -n "${GITHUB_SHA:-}"
evidence="${DRIV3R_STAGE_B_EVIDENCE:-evidence/driv3r-stage-c}"
test ! -e "$evidence"
mkdir -p "$evidence/build"
phase="request-and-source"
trap 'result=$?; printf "{\"schema\":\"driv3r-stage-c-bootstrap-exit-v1\",\"exit_code\":%s,\"phase\":\"%s\"}\n" "$result" "$phase" > "$evidence/bootstrap-exit.json"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
test "$(git rev-parse HEAD)" = "$GITHUB_SHA"
python3 -m experiments.driv3r.stage_c.provenance request --source-sha "$GITHUB_SHA" --output "$evidence/request.json"
python3 -m experiments.driv3r.stage_c.provenance source --source-sha "$GITHUB_SHA" --output "$evidence/source-custody.json"
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

phase="offline-contracts"
python3 -m venv "$RUNNER_TEMP/driv3r-stage-c-python"
export DRIV3R_PYTHON="$RUNNER_TEMP/driv3r-stage-c-python/bin/python"
"$DRIV3R_PYTHON" -m pip install --require-hashes -r tools/requirements-build.txt > "$evidence/build/install-scons.log" 2>&1
"$DRIV3R_PYTHON" -m pip install --require-hashes -r tools/requirements-ci-audit.txt > "$evidence/build/install-ci-audit.log" 2>&1
"$DRIV3R_PYTHON" -m pip install 'Pillow==13.0.0' 'jsonschema==4.26.0' > "$evidence/build/install-test-dependencies.log" 2>&1
"$DRIV3R_PYTHON" -m pip freeze > "$evidence/build/python-environment.txt"
"$DRIV3R_PYTHON" -m unittest discover -s experiments/driv3r/tests -p 'test_*.py' -v 2>&1 | tee "$evidence/build/offline-tests.log"
"$DRIV3R_PYTHON" tools/ci/check_ci_scheduling_policy.py --output "$evidence/build/scheduling.json"

phase="frozen-stage-b-eligibility"
# Stage C is conditional on immutable original Stage B native/model evidence.
curl -fsSL --retry 3 --max-time 120 -o "$RUNNER_TEMP/driv3r-stage-b-original.zip" 'https://github.com/techrote/cybersand/releases/download/driv3r-stage-b-2ea0f09c8fbb-43546244572-1/driv3r-stage-b-2ea0f09c8fbb.zip'
"$DRIV3R_PYTHON" -m experiments.driv3r.stage_c.provenance admit-b --archive "$RUNNER_TEMP/driv3r-stage-b-original.zip" --output "$evidence/stage-b-admission.json"

phase="native-source-build"
git lfs install --local
timeout 600 git lfs pull --include='godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so' --exclude='' > "$evidence/build/rapier-acquisition.log" 2>&1
echo '566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a  godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so' | sha256sum -c --strict
export GODOT_CPP_ROOT="$RUNNER_TEMP/driv3r-stage-c-godot-cpp"
export SCONS_PYTHON="$DRIV3R_PYTHON"
export SCONS_JOBS=4
export CYBERSAND_REAL_CXX=/usr/bin/g++-13
export LINUX_CXX=/usr/bin/g++-13
export CYBERSAND_NATIVE_OUTPUT="$RUNNER_TEMP/driv3r-stage-c-native.so"
mkdir -p "$GODOT_CPP_ROOT"
git -C "$GODOT_CPP_ROOT" init
git -C "$GODOT_CPP_ROOT" remote add origin https://github.com/godotengine/godot-cpp.git
timeout 600 git -C "$GODOT_CPP_ROOT" fetch --depth=1 origin 101ae38034304346a46ea9ea84ae156d3e860496 > "$evidence/build/godot-cpp-fetch.log" 2>&1
git -C "$GODOT_CPP_ROOT" checkout --detach FETCH_HEAD
if ! timeout 3600 bash tools/build_pinned_godot_cpp.sh linux > "$evidence/build/godot-cpp.log" 2>&1; then tail -100 "$evidence/build/godot-cpp.log"; exit 1; fi
if ! timeout 3600 bash tools/build_native_extension.sh > "$evidence/build/native.log" 2>&1; then tail -100 "$evidence/build/native.log"; exit 1; fi
cp "$CYBERSAND_NATIVE_OUTPUT" godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so
bash tools/check_linux_runtime_floor.sh > "$evidence/build/abi-floor.log" 2>&1
"$DRIV3R_PYTHON" experiments/agent_painter/native/runtime.py stamp --source-sha "$GITHUB_SHA" --output "$evidence/native-build.json"
mkdir -p "$evidence/build/runtime"
cp "$CYBERSAND_NATIVE_OUTPUT" "$evidence/build/runtime/libcybersand_native.linux.x86_64.so"
sha256sum "$GODOT_CPP_ROOT/bin/libgodot-cpp.linux.template_debug.x86_64.a" > "$evidence/build/godot-cpp-library.sha256"

phase="godot-acquisition-and-import"
timeout 600 curl -fsSL --retry 3 -o "$RUNNER_TEMP/driv3r-stage-c-godot.zip" 'https://downloads.godotengine.org/?flavor=stable&platform=linux.64&slug=linux.x86_64.zip&version=4.7'
echo "0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c  $RUNNER_TEMP/driv3r-stage-c-godot.zip" | sha256sum -c --strict
mkdir -p "$RUNNER_TEMP/driv3r-stage-c-godot"
unzip -q "$RUNNER_TEMP/driv3r-stage-c-godot.zip" -d "$RUNNER_TEMP/driv3r-stage-c-godot"
export GODOT_BIN="$RUNNER_TEMP/driv3r-stage-c-godot/Godot_v4.7-stable_linux.x86_64"
chmod +x "$GODOT_BIN"
"$GODOT_BIN" --version > "$evidence/build/godot-version.txt"
if ! timeout 1200 "$GODOT_BIN" --headless --path godot --editor --quit > "$evidence/build/import.log" 2>&1; then tail -100 "$evidence/build/import.log"; exit 1; fi

phase="graphical-headless-display"
# Real software-rendered Godot framebuffer, not headless material PNGs.
sudo apt-get update -qq > "$evidence/build/apt-update.log" 2>&1
sudo apt-get install -y xvfb xauth libgl1-mesa-dri > "$evidence/build/apt-xvfb.log" 2>&1
command -v xvfb-run

phase="model-runtime-acquisition"
# Reuse the exact official Q8 weights/runtime pins and acquisition receipts.
# Neither model payload nor the runtime bundle is included in research artifacts.
"$DRIV3R_PYTHON" -m experiments.driv3r.backend acquire --runtime-dir "$RUNNER_TEMP/driv3r-stage-c-runtime" --evidence "$evidence/acquisition" --timeout-seconds 1200
phase="stage-c-qualification"
set +e
timeout --signal=TERM --kill-after=60 5400 xvfb-run -a -s "-screen 0 1280x720x24 -nolisten tcp" env LIBGL_ALWAYS_SOFTWARE=1 "$DRIV3R_PYTHON" -m experiments.driv3r.stage_c.qualify --godot "$GODOT_BIN" --runtime-manifest "$evidence/native-build.json" --source-sha "$GITHUB_SHA" --runtime-dir "$RUNNER_TEMP/driv3r-stage-c-runtime" --output "$evidence/execution" 2>&1 | tee "$evidence/execution-driver.log"
statuses=("${PIPESTATUS[@]}")
set -e
"$DRIV3R_PYTHON" - "$evidence/qualification-exit.json" "$GITHUB_SHA" "${statuses[0]}" "${statuses[1]}" <<'PY'
import json, pathlib, sys
pathlib.Path(sys.argv[1]).write_text(json.dumps({
    "schema": "driv3r-stage-c-qualification-exit-v1", "source_sha": sys.argv[2],
    "exit_code": int(sys.argv[3]), "log_capture_exit_code": int(sys.argv[4]),
    "qualification_timeout_seconds": 5400, "kill_grace_seconds": 60,
    "claim": "Exit receipt is infrastructure status; original summary records behavioral failures and usefulness"
}, indent=2) + "\n")
PY
test "${statuses[1]}" -eq 0
exit "${statuses[0]}"
