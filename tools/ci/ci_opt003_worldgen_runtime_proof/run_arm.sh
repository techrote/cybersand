#!/usr/bin/env bash
set -euo pipefail
arm="$1"
suite="$2"
controller="$PWD/tools/ci/ci_opt003_worldgen_runtime_proof/proof.py"
python3 "$controller" start --suite "$suite" --arm "$arm"
cd "build/proof/$suite/$arm/source"
source_sha="$(git rev-parse HEAD)"
export GITHUB_SHA="$source_sha"
family_seconds="$(python3 tools/ci/native_execution_policy.py family-seconds "$suite")"
mkdir -p "build/native-parallel/$suite"
set +e
(
  set -euo pipefail
  echo "source_sha=$source_sha suite=$suite run=$GITHUB_RUN_ID attempt=$GITHUB_RUN_ATTEMPT"
  echo "compiler=$(g++-13 --version | head -n 1)"
  python3 tools/ci/run_timed_command.py \
    --policy-key native_suite_seconds --label "native-family-$suite" \
    --timeout-seconds "$family_seconds" --output-dir "build/native-parallel/$suite/family" -- \
    bash tools/ci/run_native_family.sh "$suite" "build/native-parallel/$suite"
  echo "Native family passed: $suite"
) 2>&1 | tee "build/native-parallel/$suite/run.log"
original_status=("${PIPESTATUS[@]}")
set -e
printf '%s\n' "${original_status[0]}" > "build/native-parallel/$suite/family-exit-code.txt"
printf '%s\n' "${original_status[1]}" > "build/native-parallel/$suite/log-capture-exit-code.txt"
if [ "${original_status[0]}" -ne 0 ]; then exit "${original_status[0]}"; fi
exit "${original_status[1]}"
