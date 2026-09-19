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
CORE_HEADERS := $(wildcard native/include/cybersand/*.hpp native/include/cybersand/*.h native/src/*.hpp)
TEST_SOURCES := native/tests/test_world.cpp
BENCH_SOURCES := native/bench/benchmark.cpp

.PHONY: all soliding-test soliding-sanitize soliding-benchmark-smoke soliding-stage3-cost-smoke soliding-stage3b-validation-apparatus-test soliding-stage3b-runtime-storage-test soliding-stage3b-spatial-index-test test c-header-check benchmark shared debug sanitize thread-sanitize clean

all: test benchmark shared

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/tests: $(CORE_SOURCES) $(CORE_HEADERS) $(TEST_SOURCES) | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(DEBUG_FLAGS) $(CORE_SOURCES) $(TEST_SOURCES) -o $@

$(BUILD_DIR)/benchmark: $(SIMULATION_SOURCES) $(CORE_HEADERS) $(BENCH_SOURCES) | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(RELEASE_FLAGS) $(SIMULATION_SOURCES) $(BENCH_SOURCES) -o $@

$(BUILD_DIR)/libcybersand.so: $(CORE_SOURCES) $(CORE_HEADERS) | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(RELEASE_FLAGS) -DCYBERSAND_BUILD_SHARED -fPIC -shared $(CORE_SOURCES) -o $@

$(BUILD_DIR)/tests_sanitized: $(CORE_SOURCES) $(CORE_HEADERS) $(TEST_SOURCES) | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined $(CORE_SOURCES) $(TEST_SOURCES) -o $@

$(BUILD_DIR)/tests_tsan: $(CORE_SOURCES) $(CORE_HEADERS) $(TEST_SOURCES) | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=thread $(CORE_SOURCES) $(TEST_SOURCES) -o $@

$(BUILD_DIR)/test_soliding_lifecycle: native/tests/test_soliding_lifecycle.cpp native/include/cybersand/soliding_lifecycle.hpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(DEBUG_FLAGS) native/tests/test_soliding_lifecycle.cpp -o $@

$(BUILD_DIR)/test_settled_discovery: $(CORE_SOURCES) $(CORE_HEADERS) native/tests/test_settled_discovery.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(DEBUG_FLAGS) $(CORE_SOURCES) native/tests/test_settled_discovery.cpp -o $@

$(BUILD_DIR)/test_settled_regions: native/tests/test_settled_regions.cpp native/include/cybersand/settled_regions.hpp native/include/cybersand/settled_discovery.hpp native/include/cybersand/bounded_ordered_index.hpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(DEBUG_FLAGS) native/tests/test_settled_regions.cpp -o $@

$(BUILD_DIR)/test_settled_world_discovery: $(CORE_SOURCES) $(CORE_HEADERS) native/tests/test_settled_world_discovery.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(DEBUG_FLAGS) $(CORE_SOURCES) native/tests/test_settled_world_discovery.cpp -o $@

$(BUILD_DIR)/test_stage3b_runtime_storage: $(CORE_SOURCES) $(CORE_HEADERS) native/tests/test_stage3b_runtime_storage.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(DEBUG_FLAGS) $(CORE_SOURCES) native/tests/test_stage3b_runtime_storage.cpp -o $@

soliding-stage3b-runtime-storage-test: $(BUILD_DIR)/test_stage3b_runtime_storage
	./$(BUILD_DIR)/test_stage3b_runtime_storage

$(BUILD_DIR)/test_stage3b_bounded_spatial_index: $(CORE_SOURCES) $(CORE_HEADERS) native/tests/test_stage3b_bounded_spatial_index.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(DEBUG_FLAGS) $(CORE_SOURCES) native/tests/test_stage3b_bounded_spatial_index.cpp -o $@

soliding-stage3b-spatial-index-test: $(BUILD_DIR)/test_stage3b_bounded_spatial_index
	./$(BUILD_DIR)/test_stage3b_bounded_spatial_index

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

soliding-test: $(BUILD_DIR)/test_soliding_lifecycle $(BUILD_DIR)/test_settled_discovery $(BUILD_DIR)/test_settled_regions $(BUILD_DIR)/test_settled_world_discovery $(BUILD_DIR)/test_stage3b_runtime_storage $(BUILD_DIR)/test_stage3b_bounded_spatial_index
	./$(BUILD_DIR)/test_soliding_lifecycle
	./$(BUILD_DIR)/test_settled_discovery
	./$(BUILD_DIR)/test_settled_regions
	./$(BUILD_DIR)/test_settled_world_discovery
	./$(BUILD_DIR)/test_stage3b_runtime_storage
	./$(BUILD_DIR)/test_stage3b_bounded_spatial_index

$(BUILD_DIR)/test_soliding_lifecycle_sanitized: native/tests/test_soliding_lifecycle.cpp native/include/cybersand/soliding_lifecycle.hpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined native/tests/test_soliding_lifecycle.cpp -o $@

$(BUILD_DIR)/test_settled_discovery_sanitized: $(CORE_SOURCES) $(CORE_HEADERS) native/tests/test_settled_discovery.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined $(CORE_SOURCES) native/tests/test_settled_discovery.cpp -o $@

$(BUILD_DIR)/test_settled_regions_sanitized: native/tests/test_settled_regions.cpp native/include/cybersand/settled_regions.hpp native/include/cybersand/settled_discovery.hpp native/include/cybersand/bounded_ordered_index.hpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined native/tests/test_settled_regions.cpp -o $@

$(BUILD_DIR)/test_settled_world_discovery_sanitized: $(CORE_SOURCES) $(CORE_HEADERS) native/tests/test_settled_world_discovery.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined $(CORE_SOURCES) native/tests/test_settled_world_discovery.cpp -o $@

$(BUILD_DIR)/test_stage3b_runtime_storage_sanitized: $(CORE_SOURCES) $(CORE_HEADERS) native/tests/test_stage3b_runtime_storage.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined $(CORE_SOURCES) native/tests/test_stage3b_runtime_storage.cpp -o $@

$(BUILD_DIR)/test_stage3b_bounded_spatial_index_sanitized: $(CORE_SOURCES) $(CORE_HEADERS) native/tests/test_stage3b_bounded_spatial_index.cpp | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined $(CORE_SOURCES) native/tests/test_stage3b_bounded_spatial_index.cpp -o $@

soliding-sanitize: $(BUILD_DIR)/test_soliding_lifecycle_sanitized $(BUILD_DIR)/test_settled_discovery_sanitized $(BUILD_DIR)/test_settled_regions_sanitized $(BUILD_DIR)/test_settled_world_discovery_sanitized $(BUILD_DIR)/test_stage3b_runtime_storage_sanitized $(BUILD_DIR)/test_stage3b_bounded_spatial_index_sanitized
	./$(BUILD_DIR)/test_soliding_lifecycle_sanitized
	./$(BUILD_DIR)/test_settled_discovery_sanitized
	./$(BUILD_DIR)/test_settled_regions_sanitized
	./$(BUILD_DIR)/test_settled_world_discovery_sanitized
	./$(BUILD_DIR)/test_stage3b_runtime_storage_sanitized
	./$(BUILD_DIR)/test_stage3b_bounded_spatial_index_sanitized

test: c-header-check $(BUILD_DIR)/tests soliding-test
	./$(BUILD_DIR)/tests

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
	rm -f $(BUILD_DIR)/settled_discovery $(BUILD_DIR)/stage3_cost $(BUILD_DIR)/test_soliding_lifecycle_sanitized $(BUILD_DIR)/test_settled_discovery_sanitized $(BUILD_DIR)/test_settled_regions_sanitized $(BUILD_DIR)/test_settled_world_discovery_sanitized $(BUILD_DIR)/test_stage3b_runtime_storage_sanitized $(BUILD_DIR)/test_stage3b_bounded_spatial_index_sanitized $(BUILD_DIR)/test_soliding_lifecycle $(BUILD_DIR)/test_settled_discovery $(BUILD_DIR)/test_settled_regions $(BUILD_DIR)/test_settled_world_discovery $(BUILD_DIR)/test_stage3b_runtime_storage $(BUILD_DIR)/test_stage3b_bounded_spatial_index $(BUILD_DIR)/tests $(BUILD_DIR)/tests_sanitized $(BUILD_DIR)/tests_tsan $(BUILD_DIR)/benchmark $(BUILD_DIR)/libcybersand.so
