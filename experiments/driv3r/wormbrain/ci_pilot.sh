#!/usr/bin/env bash
# Owner-authorised WORMBRAIN 36-choice pilot, native d1-2B steering, no route objective.
# The pinned resident Q8 is acquired only after exact-source request admission.
set -euo pipefail
test -n "${RUNNER_TEMP:-}"
test -n "${GITHUB_SHA:-}"
test "${DRIV3R_WORM_MODE:-}" = "free" -o "${DRIV3R_WORM_MODE:-}" = "soft"
evidence="evidence/driv3r-worm-${DRIV3R_WORM_MODE}"
test ! -e "$evidence"
mkdir -p "$evidence/build"
trap 'result=$?; printf "{\"exit_code\":%s,\"phase\":\"bootstrap-or-qualification\"}\n" "$result" > "$evidence/bootstrap-exit.json"' EXIT
test "$(git rev-parse HEAD)" = "$GITHUB_SHA"
python3 - "$evidence/request.json" "$GITHUB_SHA" <<'PY'
import json,os,pathlib,sys
r=json.loads(pathlib.Path("experiments/driv3r/wormbrain/qualification-request.json").read_text())
assert r["schema"]=="driv3r-wormbrain-pilot-request/1"
assert r["owner_gate"]=="Owner-approved eccentric line-steering wormbrain native pilot"
assert r["max_model_decisions_per_arm"]==36 and r["max_native_material_edits_per_arm"]==36
assert r["max_recoveries_per_arm"]==8 and r["allow_model_and_native"] is True
assert r["allow_training"] is False and r["eligible_arms"]==["free","soft"]
assert r["allow_paid_external_api"] is False and r["allow_merge"] is False
pathlib.Path(sys.argv[1]).write_text(json.dumps({"request":r,"source_sha":sys.argv[2],
 "github_run_id":os.getenv("GITHUB_RUN_ID"),"github_run_attempt":os.getenv("GITHUB_RUN_ATTEMPT")},
 indent=2)+"\n")
PY
python3 - "$GITHUB_SHA" "$evidence/source-custody.json" <<'PY'
import hashlib,json,pathlib,subprocess,sys
commit=subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip()
assert commit==sys.argv[1]
schema=pathlib.Path("experiments/driv3r/d_common/v1/interface.schema.json")
expected="ebe2fa211148602c614cba0f0a40f285cba797784b70efa035832d833877f80d"
assert hashlib.sha256(schema.read_bytes()).hexdigest()==expected
subprocess.run(["git","merge-base","--is-ancestor",
 "8fa90de6be209ed0b7bd125039e6ec8b332fb1a6","HEAD"],check=True)
pathlib.Path(sys.argv[2]).write_text(json.dumps({
 "source_sha":commit,
 "source_tree":subprocess.check_output(["git","rev-parse","HEAD^{tree}"],text=True).strip(),
 "m1_source_sha":"8fa90de6be209ed0b7bd125039e6ec8b332fb1a6",
 "m1_schema_sha256":expected,
 "source_native_backend":"source-matched Linux CyberNativeCellWorld"},indent=2)+"\n")
PY
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
"$DRIV3R_PYTHON" -m pip install 'Pillow==13.0.0' 'jsonschema==4.26.0' > "$evidence/build/install-pillow-and-jsonschema.log" 2>&1
"$DRIV3R_PYTHON" -c 'import jsonschema; from experiments.driv3r.d_common.v1.verify import validate_bundle; print("M1 validator available")' > "$evidence/build/validator-import-preflight.log" 2>&1
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


# One real resident d1-2B Q8 per worm mode; strict native PAINT custody and replay.
phase="wormbrain-source-fenced-native"
set +e
"$DRIV3R_PYTHON" -m experiments.driv3r.backend acquire \
  --runtime-dir "$RUNNER_TEMP/driv3r-worm-q8-runtime" \
  --evidence "$evidence/model-acquisition" --timeout-seconds 1200
timeout --signal=TERM --kill-after=45 5200 "$DRIV3R_PYTHON" -m experiments.driv3r.wormbrain.pilot --mode "$DRIV3R_WORM_MODE" \
  --godot "$GODOT_BIN" --runtime-manifest "$evidence/native-build.json" \
  --source-sha "$GITHUB_SHA" --model-runtime-manifest "$RUNNER_TEMP/driv3r-worm-q8-runtime/runtime-manifest.json" --output "$evidence/execution" \
  > "$evidence/native-qualification.log" 2>&1
status=$?
set -e
cat "$evidence/native-qualification.log"
printf '{"schema":"driv3r-worm-comparative-bootstrap-v1","source_sha":"%s","exit_code":%s,"phase":"%s"}\n' \
    "$GITHUB_SHA" "$status" "$phase" > "$evidence/qualification-exit.json"
exit "$status"
