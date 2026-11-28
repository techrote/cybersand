CXX ?= g++
CC ?= gcc
BUILD_DIR := build
INCLUDE_DIR := native/include
COMMON_FLAGS := -std=c++20 -Wall -Wextra -Wpedantic -Wconversion -Wshadow -I$(INCLUDE_DIR)
RELEASE_FLAGS := -O3 -DNDEBUG -flto
DEBUG_FLAGS := -O0 -g3

SIMULATION_SOURCES := native/src/world.cpp native/src/material_rules.cpp native/src/scheduler_geometry.cpp native/src/settled_world_discovery.cpp
BRIDGE_SOURCES := native/src/render_snapshot.cpp native/src/c_api.cpp
CORE_SOURCES := $(SIMULATION_SOURCES) $(BRIDGE_SOURCES)
GENERATION_SOURCES := native/src/world_generation.cpp native/src/generation_fields.cpp native/src/generation_typed_fields.cpp native/src/generation_spatial.cpp native/src/generation_grammar.cpp native/src/generation_planes.cpp
GENERATION_OPT_OBJECTS := $(patsubst native/src/%.cpp,$(BUILD_DIR)/worldgen-objects/normal/%.o,$(GENERATION_SOURCES))
GENERATION_OPT_THREADED_OBJECTS := $(patsubst native/src/%.cpp,$(BUILD_DIR)/worldgen-objects/normal-threaded/%.o,$(GENERATION_SOURCES))
GENERATION_SAN_OBJECTS := $(patsubst native/src/%.cpp,$(BUILD_DIR)/worldgen-objects/sanitized/%.o,$(GENERATION_SOURCES))
GENERATION_SAN_THREADED_OBJECTS := $(patsubst native/src/%.cpp,$(BUILD_DIR)/worldgen-objects/sanitized-threaded/%.o,$(GENERATION_SOURCES))
CORE_HEADERS := $(wildcard native/include/cybersand/*.hpp native/include/cybersand/*.h native/src/*.hpp native/src/*.inc)
TEST_SOURCES := native/tests/test_lcb_inertial.cpp native/tests/test_water_inertial.cpp native/tests/test_world.cpp native/tests/test_liquid_solver_policy.cpp native/tests/test_lcb_pressure.cpp native/tests/test_pressure_moving_mask.cpp native/tests/test_pressure_setup_capacity.cpp native/tests/test_water_cellular_yield.cpp native/tests/test_water_normalization.cpp native/tests/test_liquid_run_receipt.cpp native/tests/test_liquid_construction_refusal.cpp native/tests/test_quantity_ledger.cpp native/tests/test_ballistic_water.cpp native/tests/test_workbench_pressure_heads.cpp
TEST_HEADERS := $(wildcard native/tests/*.inc native/tests/*.hpp)
# Soliding's six core-linked fixtures share only exact-configuration objects.
# No compiled artifacts or previous test outcomes are restored between CI jobs.
SOLIDING_NORMAL_OBJECTS := $(patsubst native/src/%.cpp,$(BUILD_DIR)/soliding-objects/normal/%.o,$(CORE_SOURCES))
SOLIDING_SAN_OBJECTS := $(patsubst native/src/%.cpp,$(BUILD_DIR)/soliding-objects/sanitized/%.o,$(CORE_SOURCES))
SOLIDING_SAN_FLAGS := -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined

BENCH_SOURCES := native/bench/benchmark.cpp
PHYSICS_CHARACTERISATION_SOURCES := $(SIMULATION_SOURCES) native/src/render_snapshot.cpp native/bench/physics_characterisation.cpp

.PHONY: all soliding-test soliding-sanitize soliding-benchmark-smoke soliding-stage3-cost-smoke soliding-stage3b-validation-apparatus-test soliding-stage3b-runtime-storage-test soliding-stage3b-spatial-index-test soliding-stage3b-sparse-mutation-witness-test test c-header-check benchmark shared debug sanitize thread-sanitize clean

all: test benchmark shared

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/tests: $(CORE_SOURCES) $(CORE_HEADERS) $(TEST_SOURCES) $(TEST_HEADERS) | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(DEBUG_FLAGS) $(CORE_SOURCES) $(TEST_SOURCES) -o $@

$(BUILD_DIR)/benchmark: $(SIMULATION_SOURCES) $(CORE_HEADERS) $(BENCH_SOURCES) | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(RELEASE_FLAGS) $(SIMULATION_SOURCES) $(BENCH_SOURCES) -o $@

# Match the runtime's -O3 build without cross-translation-unit LTO. The test-only
# literal oracle remains independent from the production chunk-run function.
$(BUILD_DIR)/render_copy_benchmark: $(CORE_SOURCES) $(CORE_HEADERS) native/bench/render_copy.cpp native/tests/render_copy_reference.hpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O3 -DNDEBUG $(CORE_SOURCES) native/bench/render_copy.cpp -o $@

$(BUILD_DIR)/libcybersand.so: $(CORE_SOURCES) $(CORE_HEADERS) | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(RELEASE_FLAGS) -DCYBERSAND_BUILD_SHARED -fPIC -shared $(CORE_SOURCES) -o $@

$(BUILD_DIR)/tests_sanitized: $(CORE_SOURCES) $(CORE_HEADERS) $(TEST_SOURCES) $(TEST_HEADERS) | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined $(CORE_SOURCES) $(TEST_SOURCES) -o $@

# WAVE-MT-001 wave_flow_v1: standalone regressions (own main; not part of TEST_SOURCES).
.PHONY: wave-flow-test wave-flow-sanitize wave-flow-thread-sanitize wave-mt-matrix

$(BUILD_DIR)/test_wave_flow: $(CORE_SOURCES) $(CORE_HEADERS) native/tests/test_wave_flow.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -pthread $(CORE_SOURCES) native/tests/test_wave_flow.cpp -o $@

$(BUILD_DIR)/test_wave_flow_sanitized: $(CORE_SOURCES) $(CORE_HEADERS) native/tests/test_wave_flow.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=address,undefined $(CORE_SOURCES) native/tests/test_wave_flow.cpp -o $@

$(BUILD_DIR)/test_wave_flow_tsan: $(CORE_SOURCES) $(CORE_HEADERS) native/tests/test_wave_flow.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=thread $(CORE_SOURCES) native/tests/test_wave_flow.cpp -o $@

$(BUILD_DIR)/wave_mt_matrix: $(SIMULATION_SOURCES) $(CORE_HEADERS) native/bench/wave_mt_matrix.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O3 -DNDEBUG -pthread $(SIMULATION_SOURCES) native/bench/wave_mt_matrix.cpp -o $@

wave-mt-matrix: $(BUILD_DIR)/wave_mt_matrix

wave-flow-test: $(BUILD_DIR)/test_wave_flow
	./$(BUILD_DIR)/test_wave_flow

wave-flow-sanitize: $(BUILD_DIR)/test_wave_flow_sanitized
	UBSAN_OPTIONS=halt_on_error=1 ./$(BUILD_DIR)/test_wave_flow_sanitized

wave-flow-thread-sanitize: $(BUILD_DIR)/test_wave_flow_tsan
	TSAN_OPTIONS=halt_on_error=1 ./$(BUILD_DIR)/test_wave_flow_tsan

# WAVE-WATERWALL-001 exposed-face spill and hybrid ballistic release: standalone
# regressions (own main) and the authored-map apparatus.
.PHONY: wave-spill-test wave-spill-sanitize wave-spill-thread-sanitize wave-waterwall

$(BUILD_DIR)/test_wave_spill: $(CORE_SOURCES) $(CORE_HEADERS) native/tests/test_wave_spill.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -pthread $(CORE_SOURCES) native/tests/test_wave_spill.cpp -o $@

$(BUILD_DIR)/test_wave_spill_sanitized: $(CORE_SOURCES) $(CORE_HEADERS) native/tests/test_wave_spill.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=address,undefined $(CORE_SOURCES) native/tests/test_wave_spill.cpp -o $@

$(BUILD_DIR)/test_wave_spill_tsan: $(CORE_SOURCES) $(CORE_HEADERS) native/tests/test_wave_spill.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=thread $(CORE_SOURCES) native/tests/test_wave_spill.cpp -o $@

$(BUILD_DIR)/wave_waterwall: $(SIMULATION_SOURCES) $(CORE_HEADERS) native/bench/wave_waterwall.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O3 -DNDEBUG -pthread $(SIMULATION_SOURCES) native/bench/wave_waterwall.cpp -o $@

wave-waterwall: $(BUILD_DIR)/wave_waterwall

wave-spill-test: $(BUILD_DIR)/test_wave_spill
	./$(BUILD_DIR)/test_wave_spill

wave-spill-sanitize: $(BUILD_DIR)/test_wave_spill_sanitized
	UBSAN_OPTIONS=halt_on_error=1 ./$(BUILD_DIR)/test_wave_spill_sanitized

wave-spill-thread-sanitize: $(BUILD_DIR)/test_wave_spill_tsan
	TSAN_OPTIONS=halt_on_error=1 ./$(BUILD_DIR)/test_wave_spill_tsan

# Body-occupancy boundary stress combines moving masks, external displacement,
# Wave overfill, ballistic saturation, paused cores and exact worker parity.
.PHONY: wave-body-boundary-test wave-body-boundary-sanitize wave-body-boundary-thread-sanitize

$(BUILD_DIR)/test_wave_body_boundary: $(CORE_SOURCES) $(CORE_HEADERS) native/tests/test_wave_body_boundary.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -pthread $(CORE_SOURCES) native/tests/test_wave_body_boundary.cpp -o $@

$(BUILD_DIR)/test_wave_body_boundary_sanitized: $(CORE_SOURCES) $(CORE_HEADERS) native/tests/test_wave_body_boundary.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=address,undefined $(CORE_SOURCES) native/tests/test_wave_body_boundary.cpp -o $@

$(BUILD_DIR)/test_wave_body_boundary_tsan: $(CORE_SOURCES) $(CORE_HEADERS) native/tests/test_wave_body_boundary.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=thread $(CORE_SOURCES) native/tests/test_wave_body_boundary.cpp -o $@

wave-body-boundary-test: $(BUILD_DIR)/test_wave_body_boundary
	./$(BUILD_DIR)/test_wave_body_boundary

wave-body-boundary-sanitize: $(BUILD_DIR)/test_wave_body_boundary_sanitized
	UBSAN_OPTIONS=halt_on_error=1 ./$(BUILD_DIR)/test_wave_body_boundary_sanitized

wave-body-boundary-thread-sanitize: $(BUILD_DIR)/test_wave_body_boundary_tsan
	TSAN_OPTIONS=halt_on_error=1 ./$(BUILD_DIR)/test_wave_body_boundary_tsan

.PHONY: material-baseline-test material-baseline-sanitize

# GEN-006 opt-in full-area continuation; no default native law changes.
.PHONY: persistent-area-test persistent-area-sanitize
$(BUILD_DIR)/test_persistent_area_continuation: $(SIMULATION_SOURCES) native/src/render_snapshot.cpp $(CORE_HEADERS) native/tests/test_persistent_area_continuation.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -pthread $(SIMULATION_SOURCES) native/src/render_snapshot.cpp native/tests/test_persistent_area_continuation.cpp -o $@

$(BUILD_DIR)/test_persistent_area_continuation_sanitized: $(SIMULATION_SOURCES) native/src/render_snapshot.cpp $(CORE_HEADERS) native/tests/test_persistent_area_continuation.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=address,undefined $(SIMULATION_SOURCES) native/src/render_snapshot.cpp native/tests/test_persistent_area_continuation.cpp -o $@

persistent-area-test: $(BUILD_DIR)/test_persistent_area_continuation
	./$(BUILD_DIR)/test_persistent_area_continuation

persistent-area-sanitize: $(BUILD_DIR)/test_persistent_area_continuation_sanitized
	UBSAN_OPTIONS=halt_on_error=1 ./$(BUILD_DIR)/test_persistent_area_continuation_sanitized

.PHONY: persistent-area-residency-test persistent-area-residency-sanitize
$(BUILD_DIR)/test_persistent_area_residency_lifetime: $(SIMULATION_SOURCES) native/src/render_snapshot.cpp $(CORE_HEADERS) native/tests/test_persistent_area_residency_lifetime.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -pthread $(SIMULATION_SOURCES) native/src/render_snapshot.cpp native/tests/test_persistent_area_residency_lifetime.cpp -o $@

$(BUILD_DIR)/test_persistent_area_residency_lifetime_sanitized: $(SIMULATION_SOURCES) native/src/render_snapshot.cpp $(CORE_HEADERS) native/tests/test_persistent_area_residency_lifetime.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=address,undefined $(SIMULATION_SOURCES) native/src/render_snapshot.cpp native/tests/test_persistent_area_residency_lifetime.cpp -o $@

persistent-area-residency-test: $(BUILD_DIR)/test_persistent_area_residency_lifetime
	./$(BUILD_DIR)/test_persistent_area_residency_lifetime

persistent-area-residency-sanitize: $(BUILD_DIR)/test_persistent_area_residency_lifetime_sanitized
	UBSAN_OPTIONS=halt_on_error=1 ./$(BUILD_DIR)/test_persistent_area_residency_lifetime_sanitized

# MAT-AUDITION-LIVE-001: scene-local profile transactions and actual consumers.
.PHONY: material-audition-test material-audition-sanitize material-audition-thread-sanitize

$(BUILD_DIR)/test_material_audition: $(SIMULATION_SOURCES) $(CORE_HEADERS) native/tests/test_material_audition.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -pthread $(SIMULATION_SOURCES) native/tests/test_material_audition.cpp -o $@

$(BUILD_DIR)/test_material_audition_sanitized: $(SIMULATION_SOURCES) $(CORE_HEADERS) native/tests/test_material_audition.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=address,undefined $(SIMULATION_SOURCES) native/tests/test_material_audition.cpp -o $@

$(BUILD_DIR)/test_material_audition_tsan: $(SIMULATION_SOURCES) $(CORE_HEADERS) native/tests/test_material_audition.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=thread $(SIMULATION_SOURCES) native/tests/test_material_audition.cpp -o $@

material-audition-test: $(BUILD_DIR)/test_material_audition
	./$(BUILD_DIR)/test_material_audition

material-audition-sanitize: $(BUILD_DIR)/test_material_audition_sanitized
	UBSAN_OPTIONS=halt_on_error=1 ./$(BUILD_DIR)/test_material_audition_sanitized

material-audition-thread-sanitize: $(BUILD_DIR)/test_material_audition_tsan
	TSAN_OPTIONS=halt_on_error=1 ./$(BUILD_DIR)/test_material_audition_tsan

$(BUILD_DIR)/test_material_baseline: $(SIMULATION_SOURCES) $(CORE_HEADERS) native/tests/test_material_baseline.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -pthread $(SIMULATION_SOURCES) native/tests/test_material_baseline.cpp -o $@

$(BUILD_DIR)/test_material_baseline_sanitized: $(SIMULATION_SOURCES) $(CORE_HEADERS) native/tests/test_material_baseline.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=address,undefined $(SIMULATION_SOURCES) native/tests/test_material_baseline.cpp -o $@

material-baseline-test: $(BUILD_DIR)/test_material_baseline
	./$(BUILD_DIR)/test_material_baseline

material-baseline-sanitize: $(BUILD_DIR)/test_material_baseline_sanitized
	ASAN_OPTIONS=$${ASAN_OPTIONS:-detect_leaks=1:strict_string_checks=1} UBSAN_OPTIONS=$${UBSAN_OPTIONS:-halt_on_error=1} ./$(BUILD_DIR)/test_material_baseline_sanitized

# The experimental authoring patch is strict-warning checked independently;
# unchanged simulation translation units retain the repository warning policy.
.PHONY: workbench-authoring-patch-test workbench-authoring-patch-sanitize

$(BUILD_DIR)/test_workbench_authoring_patch: $(SIMULATION_SOURCES) $(CORE_HEADERS) native/tests/test_workbench_authoring_patch.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -Werror -fsyntax-only native/tests/test_workbench_authoring_patch.cpp
	$(CXX) $(COMMON_FLAGS) -O2 -g -pthread $(SIMULATION_SOURCES) native/tests/test_workbench_authoring_patch.cpp -o $@

$(BUILD_DIR)/test_workbench_authoring_patch_sanitized: $(SIMULATION_SOURCES) $(CORE_HEADERS) native/tests/test_workbench_authoring_patch.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -Werror -fsyntax-only native/tests/test_workbench_authoring_patch.cpp
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=address,undefined $(SIMULATION_SOURCES) native/tests/test_workbench_authoring_patch.cpp -o $@

workbench-authoring-patch-test: $(BUILD_DIR)/test_workbench_authoring_patch
	./$(BUILD_DIR)/test_workbench_authoring_patch

workbench-authoring-patch-sanitize: $(BUILD_DIR)/test_workbench_authoring_patch_sanitized
	ASAN_OPTIONS=$${ASAN_OPTIONS:-detect_leaks=1:strict_string_checks=1} UBSAN_OPTIONS=$${UBSAN_OPTIONS:-halt_on_error=1} ./$(BUILD_DIR)/test_workbench_authoring_patch_sanitized

$(BUILD_DIR)/workbench_process_fixture: native/tests/workbench_process_fixture.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -pthread -Werror $< -o $@

.PHONY: test-workbench-actor-capacity test-workbench-actor-capacity-sanitize

$(BUILD_DIR)/test_workbench_actor_capacity: $(SIMULATION_SOURCES) $(CORE_HEADERS) native/tests/test_workbench_actor_capacity.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -pthread $(SIMULATION_SOURCES) native/tests/test_workbench_actor_capacity.cpp -o $@

$(BUILD_DIR)/test_workbench_actor_capacity_sanitized: $(SIMULATION_SOURCES) $(CORE_HEADERS) native/tests/test_workbench_actor_capacity.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=address,undefined $(SIMULATION_SOURCES) native/tests/test_workbench_actor_capacity.cpp -o $@

test-workbench-actor-capacity: $(BUILD_DIR)/test_workbench_actor_capacity
	$<

test-workbench-actor-capacity-sanitize: $(BUILD_DIR)/test_workbench_actor_capacity_sanitized
	ASAN_OPTIONS=$${ASAN_OPTIONS:-detect_leaks=1:strict_string_checks=1} UBSAN_OPTIONS=$${UBSAN_OPTIONS:-halt_on_error=1} $<

.PHONY: physics-characterisation-test physics-characterisation-sanitize

$(BUILD_DIR)/physics_characterisation: $(PHYSICS_CHARACTERISATION_SOURCES) $(CORE_HEADERS) | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(DEBUG_FLAGS) -pthread $(PHYSICS_CHARACTERISATION_SOURCES) -o $@

$(BUILD_DIR)/physics_characterisation_sanitized: $(PHYSICS_CHARACTERISATION_SOURCES) $(CORE_HEADERS) | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined -pthread $(PHYSICS_CHARACTERISATION_SOURCES) -o $@

physics-characterisation-test: $(BUILD_DIR)/physics_characterisation
	python3 tools/physics/test_characterisation_cli.py --executable $< --output $(BUILD_DIR)/physics-cli-validation/normal

physics-characterisation-sanitize: $(BUILD_DIR)/physics_characterisation_sanitized
	python3 tools/physics/test_characterisation_cli.py --executable $< --output $(BUILD_DIR)/physics-cli-validation/sanitized

$(BUILD_DIR)/tests_tsan: $(CORE_SOURCES) $(CORE_HEADERS) $(TEST_SOURCES) $(TEST_HEADERS) | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=thread $(CORE_SOURCES) $(TEST_SOURCES) -o $@

.PHONY: soliding-configuration-force
soliding-configuration-force:

# The forced recipe retains its timestamp when the compiler/flags identity is
# unchanged. A failed identity query blocks reuse; make -n executes no compiler.
$(BUILD_DIR)/soliding-objects/normal/configuration.json: export CYBERSAND_BUILD_CXX = $(CXX)
$(BUILD_DIR)/soliding-objects/normal/configuration.json: export CYBERSAND_BUILD_FLAGS = $(COMMON_FLAGS) $(DEBUG_FLAGS)
$(BUILD_DIR)/soliding-objects/sanitized/configuration.json: export CYBERSAND_BUILD_CXX = $(CXX)
$(BUILD_DIR)/soliding-objects/sanitized/configuration.json: export CYBERSAND_BUILD_FLAGS = $(COMMON_FLAGS) $(SOLIDING_SAN_FLAGS)
$(BUILD_DIR)/soliding-objects/normal/configuration.json $(BUILD_DIR)/soliding-objects/sanitized/configuration.json: export CYBERSAND_BUILD_INPUTS = $(CORE_SOURCES) $(CORE_HEADERS) Makefile tools/ci/native_build_configuration.py
$(BUILD_DIR)/soliding-objects/normal/configuration.json $(BUILD_DIR)/soliding-objects/sanitized/configuration.json: soliding-configuration-force
	python3 tools/ci/native_build_configuration.py --output $@

# Atomic object publication prevents a failed/interrupted compiler from leaving
# a partial .o that a subsequent invocation could treat as complete.
$(BUILD_DIR)/soliding-objects/normal/%.o: native/src/%.cpp $(CORE_HEADERS) Makefile tools/ci/native_build_configuration.py $(BUILD_DIR)/soliding-objects/normal/configuration.json
	@set -eu; temporary="$@.tmp.$$$$"; trap 'rm -f "$$temporary"' EXIT; trap 'exit 129' HUP; trap 'exit 130' INT; trap 'exit 143' TERM; \
	  $(CXX) $(COMMON_FLAGS) $(DEBUG_FLAGS) -c $< -o "$$temporary"; \
	  mv -f "$$temporary" "$@"

$(BUILD_DIR)/soliding-objects/sanitized/%.o: native/src/%.cpp $(CORE_HEADERS) Makefile tools/ci/native_build_configuration.py $(BUILD_DIR)/soliding-objects/sanitized/configuration.json
	@set -eu; temporary="$@.tmp.$$$$"; trap 'rm -f "$$temporary"' EXIT; trap 'exit 129' HUP; trap 'exit 130' INT; trap 'exit 143' TERM; \
	  $(CXX) $(COMMON_FLAGS) $(SOLIDING_SAN_FLAGS) -c $< -o "$$temporary"; \
	  mv -f "$$temporary" "$@"

$(BUILD_DIR)/test_soliding_lifecycle: native/tests/test_soliding_lifecycle.cpp native/include/cybersand/soliding_lifecycle.hpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(DEBUG_FLAGS) native/tests/test_soliding_lifecycle.cpp -o $@

$(BUILD_DIR)/test_settled_discovery: $(SOLIDING_NORMAL_OBJECTS) $(CORE_HEADERS) native/tests/test_settled_discovery.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(DEBUG_FLAGS) $(SOLIDING_NORMAL_OBJECTS) native/tests/test_settled_discovery.cpp -o $@

$(BUILD_DIR)/test_settled_regions: native/tests/test_settled_regions.cpp native/include/cybersand/settled_regions.hpp native/include/cybersand/settled_discovery.hpp native/include/cybersand/bounded_ordered_index.hpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(DEBUG_FLAGS) native/tests/test_settled_regions.cpp -o $@

$(BUILD_DIR)/test_settled_world_discovery: $(SOLIDING_NORMAL_OBJECTS) $(CORE_HEADERS) native/tests/test_settled_world_discovery.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(DEBUG_FLAGS) $(SOLIDING_NORMAL_OBJECTS) native/tests/test_settled_world_discovery.cpp -o $@

$(BUILD_DIR)/test_stage3b_runtime_storage: $(SOLIDING_NORMAL_OBJECTS) $(CORE_HEADERS) native/tests/test_stage3b_runtime_storage.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(DEBUG_FLAGS) $(SOLIDING_NORMAL_OBJECTS) native/tests/test_stage3b_runtime_storage.cpp -o $@

soliding-stage3b-runtime-storage-test: $(BUILD_DIR)/test_stage3b_runtime_storage
	./$(BUILD_DIR)/test_stage3b_runtime_storage

$(BUILD_DIR)/test_stage3b_bounded_spatial_index: $(SOLIDING_NORMAL_OBJECTS) $(CORE_HEADERS) native/tests/test_stage3b_bounded_spatial_index.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(DEBUG_FLAGS) $(SOLIDING_NORMAL_OBJECTS) native/tests/test_stage3b_bounded_spatial_index.cpp -o $@

soliding-stage3b-spatial-index-test: $(BUILD_DIR)/test_stage3b_bounded_spatial_index
	./$(BUILD_DIR)/test_stage3b_bounded_spatial_index

$(BUILD_DIR)/test_stage3b_sparse_mutation_witness: $(SOLIDING_NORMAL_OBJECTS) $(CORE_HEADERS) native/tests/test_stage3b_sparse_mutation_witness.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(DEBUG_FLAGS) $(SOLIDING_NORMAL_OBJECTS) native/tests/test_stage3b_sparse_mutation_witness.cpp -o $@

soliding-stage3b-sparse-mutation-witness-test: $(BUILD_DIR)/test_stage3b_sparse_mutation_witness
	./$(BUILD_DIR)/test_stage3b_sparse_mutation_witness

$(BUILD_DIR)/test_stage3b_sparse_activity_deadline: $(SOLIDING_NORMAL_OBJECTS) $(CORE_HEADERS) native/tests/test_stage3b_sparse_activity_deadline.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(DEBUG_FLAGS) $(SOLIDING_NORMAL_OBJECTS) native/tests/test_stage3b_sparse_activity_deadline.cpp -o $@

soliding-stage3b-sparse-activity-deadline-test: $(BUILD_DIR)/test_stage3b_sparse_activity_deadline
	./$(BUILD_DIR)/test_stage3b_sparse_activity_deadline

$(BUILD_DIR)/settled_discovery: native/bench/settled_discovery.cpp native/include/cybersand/settled_discovery.hpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O3 -DNDEBUG -Werror native/bench/settled_discovery.cpp -o $@

soliding-benchmark-smoke: $(BUILD_DIR)/settled_discovery
	./$(BUILD_DIR)/settled_discovery 128 64 16 2

$(BUILD_DIR)/stage3_cost: $(CORE_SOURCES) $(CORE_HEADERS) native/bench/stage3_cost.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(RELEASE_FLAGS) $(CORE_SOURCES) native/bench/stage3_cost.cpp -o $@

soliding-stage3-cost-smoke: $(BUILD_DIR)/stage3_cost
	./$(BUILD_DIR)/stage3_cost connectivity bridge 64 1 2 2 -32 0

soliding-stage3b-validation-apparatus-test: | $(BUILD_DIR)
	python3 tools/experiments/test_stage3b_validation.py
	python3 tools/experiments/stage3b_validation.py synthetic-smoke --apparatus-source-commit=$$(git rev-parse HEAD) --output $(BUILD_DIR)/stage3b-validation-synthetic-smoke.json
	python3 tools/experiments/stage3b_validation.py generate-plan --apparatus-source-commit=$$(git rev-parse HEAD) --profile smoke --output $(BUILD_DIR)/stage3b-validation-plan-smoke.json
	python3 tools/experiments/stage3b_validation.py validate-plan $(BUILD_DIR)/stage3b-validation-plan-smoke.json

soliding-test: $(BUILD_DIR)/test_soliding_lifecycle $(BUILD_DIR)/test_settled_discovery $(BUILD_DIR)/test_settled_regions $(BUILD_DIR)/test_settled_world_discovery $(BUILD_DIR)/test_stage3b_runtime_storage $(BUILD_DIR)/test_stage3b_bounded_spatial_index $(BUILD_DIR)/test_stage3b_sparse_mutation_witness $(BUILD_DIR)/test_stage3b_sparse_activity_deadline
	./$(BUILD_DIR)/test_soliding_lifecycle
	./$(BUILD_DIR)/test_settled_discovery
	./$(BUILD_DIR)/test_settled_regions
	./$(BUILD_DIR)/test_settled_world_discovery
	./$(BUILD_DIR)/test_stage3b_runtime_storage
	./$(BUILD_DIR)/test_stage3b_bounded_spatial_index
	./$(BUILD_DIR)/test_stage3b_sparse_mutation_witness
	./$(BUILD_DIR)/test_stage3b_sparse_activity_deadline

$(BUILD_DIR)/test_soliding_lifecycle_sanitized: native/tests/test_soliding_lifecycle.cpp native/include/cybersand/soliding_lifecycle.hpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined native/tests/test_soliding_lifecycle.cpp -o $@

$(BUILD_DIR)/test_settled_discovery_sanitized: $(SOLIDING_SAN_OBJECTS) $(CORE_HEADERS) native/tests/test_settled_discovery.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(SOLIDING_SAN_FLAGS) $(SOLIDING_SAN_OBJECTS) native/tests/test_settled_discovery.cpp -o $@

$(BUILD_DIR)/test_settled_regions_sanitized: native/tests/test_settled_regions.cpp native/include/cybersand/settled_regions.hpp native/include/cybersand/settled_discovery.hpp native/include/cybersand/bounded_ordered_index.hpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined native/tests/test_settled_regions.cpp -o $@

$(BUILD_DIR)/test_settled_world_discovery_sanitized: $(SOLIDING_SAN_OBJECTS) $(CORE_HEADERS) native/tests/test_settled_world_discovery.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(SOLIDING_SAN_FLAGS) $(SOLIDING_SAN_OBJECTS) native/tests/test_settled_world_discovery.cpp -o $@

$(BUILD_DIR)/test_stage3b_runtime_storage_sanitized: $(SOLIDING_SAN_OBJECTS) $(CORE_HEADERS) native/tests/test_stage3b_runtime_storage.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(SOLIDING_SAN_FLAGS) $(SOLIDING_SAN_OBJECTS) native/tests/test_stage3b_runtime_storage.cpp -o $@

$(BUILD_DIR)/test_stage3b_bounded_spatial_index_sanitized: $(SOLIDING_SAN_OBJECTS) $(CORE_HEADERS) native/tests/test_stage3b_bounded_spatial_index.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(SOLIDING_SAN_FLAGS) $(SOLIDING_SAN_OBJECTS) native/tests/test_stage3b_bounded_spatial_index.cpp -o $@

$(BUILD_DIR)/test_stage3b_sparse_mutation_witness_sanitized: $(SOLIDING_SAN_OBJECTS) $(CORE_HEADERS) native/tests/test_stage3b_sparse_mutation_witness.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(SOLIDING_SAN_FLAGS) $(SOLIDING_SAN_OBJECTS) native/tests/test_stage3b_sparse_mutation_witness.cpp -o $@

$(BUILD_DIR)/test_stage3b_sparse_activity_deadline_sanitized: $(SOLIDING_SAN_OBJECTS) $(CORE_HEADERS) native/tests/test_stage3b_sparse_activity_deadline.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(SOLIDING_SAN_FLAGS) $(SOLIDING_SAN_OBJECTS) native/tests/test_stage3b_sparse_activity_deadline.cpp -o $@

soliding-sanitize: $(BUILD_DIR)/test_soliding_lifecycle_sanitized $(BUILD_DIR)/test_settled_discovery_sanitized $(BUILD_DIR)/test_settled_regions_sanitized $(BUILD_DIR)/test_settled_world_discovery_sanitized $(BUILD_DIR)/test_stage3b_runtime_storage_sanitized $(BUILD_DIR)/test_stage3b_bounded_spatial_index_sanitized $(BUILD_DIR)/test_stage3b_sparse_mutation_witness_sanitized $(BUILD_DIR)/test_stage3b_sparse_activity_deadline_sanitized
	./$(BUILD_DIR)/test_soliding_lifecycle_sanitized
	./$(BUILD_DIR)/test_settled_discovery_sanitized
	./$(BUILD_DIR)/test_settled_regions_sanitized
	./$(BUILD_DIR)/test_settled_world_discovery_sanitized
	./$(BUILD_DIR)/test_stage3b_runtime_storage_sanitized
	./$(BUILD_DIR)/test_stage3b_bounded_spatial_index_sanitized
	./$(BUILD_DIR)/test_stage3b_sparse_mutation_witness_sanitized
	./$(BUILD_DIR)/test_stage3b_sparse_activity_deadline_sanitized

test: c-header-check $(BUILD_DIR)/tests soliding-test worldgen-test material-baseline-test
	./$(BUILD_DIR)/tests

.PHONY: worldgen-test worldgen-sanitize worldgen-demo

# Reuse generation compilation within each existing flag contract. Threaded,
# plain and sanitized objects remain distinct; Makefile changes invalidate them.
$(BUILD_DIR)/worldgen-objects/normal $(BUILD_DIR)/worldgen-objects/normal-threaded $(BUILD_DIR)/worldgen-objects/sanitized $(BUILD_DIR)/worldgen-objects/sanitized-threaded:
	mkdir -p $@

$(BUILD_DIR)/worldgen-objects/normal/%.o: native/src/%.cpp $(CORE_HEADERS) Makefile | $(BUILD_DIR)/worldgen-objects/normal
	$(CXX) $(COMMON_FLAGS) -O2 -g -Werror -c $< -o $@

$(BUILD_DIR)/worldgen-objects/normal-threaded/%.o: native/src/%.cpp $(CORE_HEADERS) Makefile | $(BUILD_DIR)/worldgen-objects/normal-threaded
	$(CXX) $(COMMON_FLAGS) -O2 -g -pthread -Werror -c $< -o $@

$(BUILD_DIR)/worldgen-objects/sanitized/%.o: native/src/%.cpp $(CORE_HEADERS) Makefile | $(BUILD_DIR)/worldgen-objects/sanitized
	$(CXX) $(COMMON_FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined -c $< -o $@

$(BUILD_DIR)/worldgen-objects/sanitized-threaded/%.o: native/src/%.cpp $(CORE_HEADERS) Makefile | $(BUILD_DIR)/worldgen-objects/sanitized-threaded
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=address,undefined -c $< -o $@

$(BUILD_DIR)/test_world_generation: $(GENERATION_OPT_OBJECTS) $(CORE_HEADERS) native/tests/test_world_generation.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -Werror $(GENERATION_OPT_OBJECTS) native/tests/test_world_generation.cpp -o $@

$(BUILD_DIR)/test_world_generation_install: $(CORE_SOURCES) $(CORE_HEADERS) native/tests/test_world_generation_install.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g $(CORE_SOURCES) native/tests/test_world_generation_install.cpp -o $@

$(BUILD_DIR)/test_generation_fields: $(BUILD_DIR)/worldgen-objects/normal/generation_fields.o $(CORE_HEADERS) native/tests/test_generation_fields.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -Werror $(BUILD_DIR)/worldgen-objects/normal/generation_fields.o native/tests/test_generation_fields.cpp -o $@

$(BUILD_DIR)/test_generation_modifiers: $(GENERATION_OPT_OBJECTS) $(CORE_HEADERS) native/tests/test_generation_modifiers.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -Werror $(GENERATION_OPT_OBJECTS) native/tests/test_generation_modifiers.cpp -o $@

worldgen-test: $(BUILD_DIR)/test_generation_planes $(BUILD_DIR)/test_generation_grammar $(BUILD_DIR)/test_generation_typed_integration $(BUILD_DIR)/test_generation_typed $(BUILD_DIR)/test_generation_spatial $(BUILD_DIR)/test_world_generation $(BUILD_DIR)/test_world_generation_install $(BUILD_DIR)/test_generation_fields $(BUILD_DIR)/test_generation_modifiers
	./$(BUILD_DIR)/test_world_generation
	./$(BUILD_DIR)/test_world_generation_install
	./$(BUILD_DIR)/test_generation_fields
	./$(BUILD_DIR)/test_generation_modifiers
	./$(BUILD_DIR)/test_generation_typed
	./$(BUILD_DIR)/test_generation_typed_integration
	./$(BUILD_DIR)/test_generation_spatial
	./$(BUILD_DIR)/test_generation_grammar
	./$(BUILD_DIR)/test_generation_planes

$(BUILD_DIR)/test_world_generation_sanitized: $(GENERATION_SAN_OBJECTS) $(CORE_HEADERS) native/tests/test_world_generation.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined $(GENERATION_SAN_OBJECTS) native/tests/test_world_generation.cpp -o $@

$(BUILD_DIR)/test_world_generation_install_sanitized: $(CORE_SOURCES) $(CORE_HEADERS) native/tests/test_world_generation_install.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined $(CORE_SOURCES) native/tests/test_world_generation_install.cpp -o $@

$(BUILD_DIR)/test_generation_fields_sanitized: $(BUILD_DIR)/worldgen-objects/sanitized/generation_fields.o $(CORE_HEADERS) native/tests/test_generation_fields.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined $(BUILD_DIR)/worldgen-objects/sanitized/generation_fields.o native/tests/test_generation_fields.cpp -o $@

$(BUILD_DIR)/test_generation_modifiers_sanitized: $(GENERATION_SAN_OBJECTS) $(CORE_HEADERS) native/tests/test_generation_modifiers.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined $(GENERATION_SAN_OBJECTS) native/tests/test_generation_modifiers.cpp -o $@

worldgen-sanitize: $(BUILD_DIR)/test_generation_planes_sanitized $(BUILD_DIR)/test_generation_grammar_sanitized $(BUILD_DIR)/test_generation_typed_integration_sanitized $(BUILD_DIR)/test_generation_typed_sanitized $(BUILD_DIR)/test_generation_spatial_sanitized $(BUILD_DIR)/test_world_generation_sanitized $(BUILD_DIR)/test_world_generation_install_sanitized $(BUILD_DIR)/test_generation_fields_sanitized $(BUILD_DIR)/test_generation_modifiers_sanitized
	./$(BUILD_DIR)/test_world_generation_sanitized
	./$(BUILD_DIR)/test_world_generation_install_sanitized
	./$(BUILD_DIR)/test_generation_fields_sanitized
	./$(BUILD_DIR)/test_generation_modifiers_sanitized
	./$(BUILD_DIR)/test_generation_typed_sanitized
	./$(BUILD_DIR)/test_generation_typed_integration_sanitized
	./$(BUILD_DIR)/test_generation_spatial_sanitized
	./$(BUILD_DIR)/test_generation_grammar_sanitized
	./$(BUILD_DIR)/test_generation_planes_sanitized

$(BUILD_DIR)/worldgen_demo: $(GENERATION_SOURCES) $(CORE_HEADERS) native/bench/worldgen_demo.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -Werror $(GENERATION_SOURCES) native/bench/worldgen_demo.cpp -o $@

worldgen-demo: $(BUILD_DIR)/worldgen_demo
	./$(BUILD_DIR)/worldgen_demo --output $(BUILD_DIR)/worldgen-preview.ppm

c-header-check: | $(BUILD_DIR)
	$(CC) -std=c11 -Wall -Wextra -Wpedantic -I$(INCLUDE_DIR) -fsyntax-only native/tests/test_c_header.c

benchmark: $(BUILD_DIR)/benchmark
	./$(BUILD_DIR)/benchmark

shared: $(BUILD_DIR)/libcybersand.so

debug: $(BUILD_DIR)/tests

sanitize: $(BUILD_DIR)/tests_sanitized
	ASAN_OPTIONS=detect_leaks=1:strict_string_checks=1 ./$(BUILD_DIR)/tests_sanitized

thread-sanitize: $(BUILD_DIR)/tests_tsan
	TSAN_OPTIONS=halt_on_error=1 ./$(BUILD_DIR)/tests_tsan

clean:
	rm -f $(BUILD_DIR)/test_material_baseline $(BUILD_DIR)/test_material_baseline_sanitized
	rm -f $(BUILD_DIR)/settled_discovery $(BUILD_DIR)/stage3_cost $(BUILD_DIR)/test_soliding_lifecycle_sanitized $(BUILD_DIR)/test_settled_discovery_sanitized $(BUILD_DIR)/test_settled_regions_sanitized $(BUILD_DIR)/test_settled_world_discovery_sanitized $(BUILD_DIR)/test_stage3b_runtime_storage_sanitized $(BUILD_DIR)/test_stage3b_bounded_spatial_index_sanitized $(BUILD_DIR)/test_stage3b_sparse_mutation_witness_sanitized $(BUILD_DIR)/test_stage3b_sparse_activity_deadline_sanitized $(BUILD_DIR)/test_soliding_lifecycle $(BUILD_DIR)/test_settled_discovery $(BUILD_DIR)/test_settled_regions $(BUILD_DIR)/test_settled_world_discovery $(BUILD_DIR)/test_stage3b_runtime_storage $(BUILD_DIR)/test_stage3b_bounded_spatial_index $(BUILD_DIR)/test_stage3b_sparse_mutation_witness $(BUILD_DIR)/test_stage3b_sparse_activity_deadline $(BUILD_DIR)/tests $(BUILD_DIR)/tests_sanitized $(BUILD_DIR)/tests_tsan $(BUILD_DIR)/benchmark $(BUILD_DIR)/libcybersand.so
	rm -rf $(BUILD_DIR)/worldgen-objects $(BUILD_DIR)/soliding-objects

$(BUILD_DIR)/test_generation_typed: $(BUILD_DIR)/worldgen-objects/normal-threaded/generation_typed_fields.o $(BUILD_DIR)/worldgen-objects/normal-threaded/generation_spatial.o $(CORE_HEADERS) native/tests/test_generation_typed.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -pthread -Werror $(BUILD_DIR)/worldgen-objects/normal-threaded/generation_typed_fields.o $(BUILD_DIR)/worldgen-objects/normal-threaded/generation_spatial.o native/tests/test_generation_typed.cpp -o $@

$(BUILD_DIR)/test_generation_spatial: $(BUILD_DIR)/worldgen-objects/normal-threaded/generation_spatial.o $(CORE_HEADERS) native/tests/test_generation_spatial.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -pthread -Werror $(BUILD_DIR)/worldgen-objects/normal-threaded/generation_spatial.o native/tests/test_generation_spatial.cpp -o $@

$(BUILD_DIR)/test_generation_typed_sanitized: $(BUILD_DIR)/worldgen-objects/sanitized-threaded/generation_typed_fields.o $(BUILD_DIR)/worldgen-objects/sanitized-threaded/generation_spatial.o $(CORE_HEADERS) native/tests/test_generation_typed.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=address,undefined $(BUILD_DIR)/worldgen-objects/sanitized-threaded/generation_typed_fields.o $(BUILD_DIR)/worldgen-objects/sanitized-threaded/generation_spatial.o native/tests/test_generation_typed.cpp -o $@

$(BUILD_DIR)/test_generation_spatial_sanitized: $(BUILD_DIR)/worldgen-objects/sanitized-threaded/generation_spatial.o $(CORE_HEADERS) native/tests/test_generation_spatial.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=address,undefined $(BUILD_DIR)/worldgen-objects/sanitized-threaded/generation_spatial.o native/tests/test_generation_spatial.cpp -o $@

$(BUILD_DIR)/test_generation_typed_integration: $(GENERATION_OPT_THREADED_OBJECTS) $(CORE_HEADERS) native/tests/test_generation_typed_integration.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -pthread -Werror $(GENERATION_OPT_THREADED_OBJECTS) native/tests/test_generation_typed_integration.cpp -o $@

$(BUILD_DIR)/test_generation_typed_integration_sanitized: $(GENERATION_SAN_THREADED_OBJECTS) $(CORE_HEADERS) native/tests/test_generation_typed_integration.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=address,undefined $(GENERATION_SAN_THREADED_OBJECTS) native/tests/test_generation_typed_integration.cpp -o $@

$(BUILD_DIR)/test_generation_grammar: $(GENERATION_OPT_THREADED_OBJECTS) $(CORE_HEADERS) native/tests/test_generation_grammar.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -pthread -Werror $(GENERATION_OPT_THREADED_OBJECTS) native/tests/test_generation_grammar.cpp -o $@

$(BUILD_DIR)/test_generation_grammar_sanitized: $(GENERATION_SAN_THREADED_OBJECTS) $(CORE_HEADERS) native/tests/test_generation_grammar.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=address,undefined $(GENERATION_SAN_THREADED_OBJECTS) native/tests/test_generation_grammar.cpp -o $@

$(BUILD_DIR)/test_generation_planes: $(GENERATION_OPT_THREADED_OBJECTS) $(CORE_HEADERS) native/tests/test_generation_planes.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -pthread -Werror $(GENERATION_OPT_THREADED_OBJECTS) native/tests/test_generation_planes.cpp -o $@

$(BUILD_DIR)/test_generation_planes_sanitized: $(GENERATION_SAN_THREADED_OBJECTS) $(CORE_HEADERS) native/tests/test_generation_planes.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=address,undefined $(GENERATION_SAN_THREADED_OBJECTS) native/tests/test_generation_planes.cpp -o $@

# GENTEK-SHOWCASE-INTEGRATION-001. All seven dedicated native suites are
# built from the *same* combined GEN-007 source; Cathedral-specific assertions
# remain in native/tests/test_world_generation.cpp.
.PHONY: gentek-showcases-test gentek-showcases-sanitize
GENTEK_SHOWCASE_TEST_BINS := $(BUILD_DIR)/test_megatruss_station $(BUILD_DIR)/test_seeded_typology_megablock $(BUILD_DIR)/test_metabolist_spine $(BUILD_DIR)/test_interlaced_viaduct $(BUILD_DIR)/test_rosework_gatehouse $(BUILD_DIR)/test_interlock_brutalism $(BUILD_DIR)/test_suspended_arcology
GENTEK_SHOWCASE_SANITIZED_BINS := $(BUILD_DIR)/test_megatruss_station_sanitized $(BUILD_DIR)/test_seeded_typology_megablock_sanitized $(BUILD_DIR)/test_metabolist_spine_sanitized $(BUILD_DIR)/test_interlaced_viaduct_sanitized $(BUILD_DIR)/test_rosework_gatehouse_sanitized $(BUILD_DIR)/test_interlock_brutalism_sanitized $(BUILD_DIR)/test_suspended_arcology_sanitized
$(BUILD_DIR)/test_megatruss_station: $(GENERATION_OPT_OBJECTS) $(CORE_HEADERS) native/tests/test_megatruss_station.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -pthread -Werror $(GENERATION_OPT_OBJECTS) native/tests/test_megatruss_station.cpp -o $@

$(BUILD_DIR)/test_megatruss_station_sanitized: $(GENERATION_SAN_OBJECTS) $(CORE_HEADERS) native/tests/test_megatruss_station.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=address,undefined $(GENERATION_SAN_OBJECTS) native/tests/test_megatruss_station.cpp -o $@

$(BUILD_DIR)/test_seeded_typology_megablock: $(GENERATION_OPT_OBJECTS) $(CORE_HEADERS) native/tests/test_seeded_typology_megablock.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -pthread -Werror $(GENERATION_OPT_OBJECTS) native/tests/test_seeded_typology_megablock.cpp -o $@

$(BUILD_DIR)/test_seeded_typology_megablock_sanitized: $(GENERATION_SAN_OBJECTS) $(CORE_HEADERS) native/tests/test_seeded_typology_megablock.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=address,undefined $(GENERATION_SAN_OBJECTS) native/tests/test_seeded_typology_megablock.cpp -o $@

$(BUILD_DIR)/test_metabolist_spine: $(GENERATION_OPT_OBJECTS) $(CORE_HEADERS) native/tests/test_metabolist_spine.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -pthread -Werror $(GENERATION_OPT_OBJECTS) native/tests/test_metabolist_spine.cpp -o $@

$(BUILD_DIR)/test_metabolist_spine_sanitized: $(GENERATION_SAN_OBJECTS) $(CORE_HEADERS) native/tests/test_metabolist_spine.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=address,undefined $(GENERATION_SAN_OBJECTS) native/tests/test_metabolist_spine.cpp -o $@

$(BUILD_DIR)/test_interlaced_viaduct: $(GENERATION_OPT_OBJECTS) $(CORE_HEADERS) native/tests/test_interlaced_viaduct.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -pthread -Werror $(GENERATION_OPT_OBJECTS) native/tests/test_interlaced_viaduct.cpp -o $@

$(BUILD_DIR)/test_interlaced_viaduct_sanitized: $(GENERATION_SAN_OBJECTS) $(CORE_HEADERS) native/tests/test_interlaced_viaduct.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=address,undefined $(GENERATION_SAN_OBJECTS) native/tests/test_interlaced_viaduct.cpp -o $@

$(BUILD_DIR)/test_rosework_gatehouse: $(GENERATION_OPT_OBJECTS) $(CORE_HEADERS) native/tests/test_rosework_gatehouse.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -pthread -Werror $(GENERATION_OPT_OBJECTS) native/tests/test_rosework_gatehouse.cpp -o $@

$(BUILD_DIR)/test_rosework_gatehouse_sanitized: $(GENERATION_SAN_OBJECTS) $(CORE_HEADERS) native/tests/test_rosework_gatehouse.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=address,undefined $(GENERATION_SAN_OBJECTS) native/tests/test_rosework_gatehouse.cpp -o $@

$(BUILD_DIR)/test_interlock_brutalism: $(GENERATION_OPT_OBJECTS) $(CORE_HEADERS) native/tests/test_interlock_brutalism.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -pthread -Werror $(GENERATION_OPT_OBJECTS) native/tests/test_interlock_brutalism.cpp -o $@

$(BUILD_DIR)/test_interlock_brutalism_sanitized: $(GENERATION_SAN_OBJECTS) $(CORE_HEADERS) native/tests/test_interlock_brutalism.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=address,undefined $(GENERATION_SAN_OBJECTS) native/tests/test_interlock_brutalism.cpp -o $@

$(BUILD_DIR)/test_suspended_arcology: $(GENERATION_OPT_OBJECTS) $(CORE_HEADERS) native/tests/test_suspended_arcology.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -pthread -Werror $(GENERATION_OPT_OBJECTS) native/tests/test_suspended_arcology.cpp -o $@

$(BUILD_DIR)/test_suspended_arcology_sanitized: $(GENERATION_SAN_OBJECTS) $(CORE_HEADERS) native/tests/test_suspended_arcology.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -pthread -fno-omit-frame-pointer -fsanitize=address,undefined $(GENERATION_SAN_OBJECTS) native/tests/test_suspended_arcology.cpp -o $@

# Independent no-argument suites share make's existing jobserver with builds.
# Phony executions also run for warm binaries; every showcase must pass before
# the nine ordered worldgen tests. Write raw output before grouped replay so a
# watchdog kill retains flushed diagnostics even while make buffers the target.
GENTEK_SHOWCASE_TEST_RUNS := $(addsuffix .run,$(GENTEK_SHOWCASE_TEST_BINS))
GENTEK_SHOWCASE_SANITIZED_RUNS := $(addsuffix .run,$(GENTEK_SHOWCASE_SANITIZED_BINS))
.PHONY: $(GENTEK_SHOWCASE_TEST_RUNS) $(GENTEK_SHOWCASE_SANITIZED_RUNS)

$(GENTEK_SHOWCASE_TEST_RUNS): %.run: %
	@echo "Running $<"
	@set -eu; log="$(BUILD_DIR)/worldgen-showcase-logs/$(notdir $<).log"; mkdir -p "$${log%/*}"; printf 'source_sha=%s run_id=%s run_attempt=%s binary=%s\n' "$${GITHUB_SHA:-unqualified}" "$${GITHUB_RUN_ID:-unqualified}" "$${GITHUB_RUN_ATTEMPT:-unqualified}" "$(notdir $<)" > "$$log"; status=0; "$<" >> "$$log" 2>&1 || status=$$?; capture=0; cat "$$log" || capture=$$?; if [ "$$status" -ne 0 ]; then exit "$$status"; fi; exit "$$capture"

$(GENTEK_SHOWCASE_SANITIZED_RUNS): %.run: %
	@echo "Running sanitized $<"
	@set -eu; log="$(BUILD_DIR)/worldgen-showcase-logs/$(notdir $<).log"; mkdir -p "$${log%/*}"; printf 'source_sha=%s run_id=%s run_attempt=%s binary=%s\n' "$${GITHUB_SHA:-unqualified}" "$${GITHUB_RUN_ID:-unqualified}" "$${GITHUB_RUN_ATTEMPT:-unqualified}" "$(notdir $<)" > "$$log"; status=0; ASAN_OPTIONS=$${ASAN_OPTIONS:-detect_leaks=1:strict_string_checks=1} UBSAN_OPTIONS=$${UBSAN_OPTIONS:-halt_on_error=1} "$<" >> "$$log" 2>&1 || status=$$?; capture=0; cat "$$log" || capture=$$?; if [ "$$status" -ne 0 ]; then exit "$$status"; fi; exit "$$capture"

gentek-showcases-test: $(GENTEK_SHOWCASE_TEST_RUNS)

gentek-showcases-sanitize: $(GENTEK_SHOWCASE_SANITIZED_RUNS)

# Include every showcase-specific native test in the ordinary generation gate.
worldgen-test: gentek-showcases-test
worldgen-sanitize: gentek-showcases-sanitize

# SCRIPT-HOTPATH-001: isolated pure-C++ kernel qualification (no Godot required).
$(BUILD_DIR)/test_paint_fill_planner: native/tests/test_paint_fill_planner.cpp native/include/cybersand/paint_fill_planner.hpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O2 -g -Werror $< -o $@

.PHONY: script-hotpath-native-test
script-hotpath-native-test: $(BUILD_DIR)/test_paint_fill_planner
	./$(BUILD_DIR)/test_paint_fill_planner
