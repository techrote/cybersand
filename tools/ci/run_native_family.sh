#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: run_native_family.sh SUITE OUTPUT_DIRECTORY" >&2
  exit 2
fi
suite="$1"
output_directory="$2"
case "$suite" in
  tsan|native-normal|asan-ubsan|worldgen|soliding-normal|soliding-asan) ;;
  *) echo "Unknown suite: $suite" >&2; exit 2 ;;
esac
mkdir -p "$output_directory/commands"

# Keep every original invocation and sanitizer environment. Only execution
# watchdogs change; native sample counts, fixtures and gate holds stay intact.
# The workflow wraps this complete family with native_suite_seconds as well.
native_command() {
  local label="$1"
  local policy_key="$2"
  local timeout_seconds
  shift 2
  timeout_seconds="$(python3 tools/ci/native_execution_policy.py command-seconds "$suite" "$label")"
  python3 tools/ci/run_timed_command.py \
    --policy-key "$policy_key" --label "$suite-$label" \
    --timeout-seconds "$timeout_seconds" \
    --output-dir "$output_directory/commands/$label" -- "$@"
}

case "$suite" in
  tsan)
    native_command build-tests-tsan native_compile_seconds make build/tests_tsan
    native_command tests-tsan native_case_seconds env TSAN_OPTIONS=halt_on_error=1 ./build/tests_tsan
    ;;
  native-normal)
    native_command c-header-check operation_seconds make c-header-check
    native_command build-tests native_compile_seconds make build/tests
    native_command tests native_case_seconds ./build/tests
    native_command shared native_compile_seconds make shared
    native_command build-benchmark native_compile_seconds make build/benchmark
    native_command benchmark native_case_seconds ./build/benchmark
    ;;
  asan-ubsan)
    native_command build-tests-sanitized native_compile_seconds make build/tests_sanitized
    native_command tests-sanitized native_case_seconds env ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1 UBSAN_OPTIONS=halt_on_error=1 ./build/tests_sanitized
    ;;
  worldgen)
    python3 tools/ci/check_worldgen_build_inventory.py --output "$output_directory/build-inventory.json"
    # Read-only host context; no compilation or test prebuild.
    nproc
    awk '/^MemTotal:/ { print }' /proc/meminfo
    mkdir -p build/physics-cli-validation
    native_command physics-characterisation-sanitize native_case_seconds env ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1 UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1 make physics-characterisation-sanitize 2>&1 | tee build/physics-cli-validation/validation.log
    # Two prerequisite jobs; the nine test recipe lines remain serial.
    # time reports max-child RSS, not concurrent aggregate RSS.
    native_command worldgen-test native_case_seconds /usr/bin/time -v make -j2 worldgen-test
    native_command worldgen-sanitize native_case_seconds env ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1 UBSAN_OPTIONS=halt_on_error=1 /usr/bin/time -v make -j2 worldgen-sanitize
    ;;
  soliding-normal)
    native_command soliding-test native_case_seconds make soliding-test
    native_command soliding-benchmark-smoke native_case_seconds make soliding-benchmark-smoke
    native_command soliding-stage3b-validation-apparatus-test native_case_seconds make soliding-stage3b-validation-apparatus-test
    native_command soliding-stage3-cost-smoke native_case_seconds make soliding-stage3-cost-smoke
    ;;
  soliding-asan)
    # Preserve the resource-characterised settled-region build, followed by
    # the full eight-binary sanitizer contract suite.
    native_command build-settled-regions-sanitized native_compile_seconds /usr/bin/time -v make build/test_settled_regions_sanitized
    native_command build-soliding-sanitized native_compile_seconds make \
      build/test_soliding_lifecycle_sanitized \
      build/test_settled_discovery_sanitized \
      build/test_settled_regions_sanitized \
      build/test_settled_world_discovery_sanitized \
      build/test_stage3b_runtime_storage_sanitized \
      build/test_stage3b_bounded_spatial_index_sanitized \
      build/test_stage3b_sparse_mutation_witness_sanitized \
      build/test_stage3b_sparse_activity_deadline_sanitized
    native_command soliding-sanitize native_case_seconds env ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1 UBSAN_OPTIONS=halt_on_error=1 make soliding-sanitize
    ;;
esac
