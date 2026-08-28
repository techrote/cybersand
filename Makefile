CXX ?= g++
CC ?= gcc
BUILD_DIR := build
INCLUDE_DIR := native/include
COMMON_FLAGS := -std=c++20 -Wall -Wextra -Wpedantic -Wconversion -Wshadow -I$(INCLUDE_DIR)
RELEASE_FLAGS := -O3 -DNDEBUG -flto
DEBUG_FLAGS := -O0 -g3

CORE_SOURCES := native/src/world.cpp native/src/material_rules.cpp native/src/scheduler_geometry.cpp native/src/render_snapshot.cpp native/src/c_api.cpp
CORE_HEADERS := $(wildcard native/include/cybersand/*.hpp native/include/cybersand/*.h native/src/*.hpp)
TEST_SOURCES := native/tests/test_world.cpp
BENCH_SOURCES := native/bench/benchmark.cpp

.PHONY: all test c-header-check benchmark shared debug sanitize thread-sanitize clean

all: test benchmark shared

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/tests: $(CORE_SOURCES) $(CORE_HEADERS) $(TEST_SOURCES) | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(DEBUG_FLAGS) $(CORE_SOURCES) $(TEST_SOURCES) -o $@

$(BUILD_DIR)/benchmark: native/src/world.cpp native/src/material_rules.cpp native/src/scheduler_geometry.cpp $(CORE_HEADERS) $(BENCH_SOURCES) | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(RELEASE_FLAGS) native/src/world.cpp native/src/material_rules.cpp native/src/scheduler_geometry.cpp $(BENCH_SOURCES) -o $@

$(BUILD_DIR)/libcybersand.so: $(CORE_SOURCES) $(CORE_HEADERS) | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) $(RELEASE_FLAGS) -DCYBERSAND_BUILD_SHARED -fPIC -shared $(CORE_SOURCES) -o $@

$(BUILD_DIR)/tests_sanitized: $(CORE_SOURCES) $(CORE_HEADERS) $(TEST_SOURCES) | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined $(CORE_SOURCES) $(TEST_SOURCES) -o $@

$(BUILD_DIR)/tests_tsan: $(CORE_SOURCES) $(CORE_HEADERS) $(TEST_SOURCES) | $(BUILD_DIR)
	$(CXX) $(COMMON_FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=thread $(CORE_SOURCES) $(TEST_SOURCES) -o $@

test: c-header-check $(BUILD_DIR)/tests
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
	rm -f $(BUILD_DIR)/tests $(BUILD_DIR)/tests_sanitized $(BUILD_DIR)/tests_tsan $(BUILD_DIR)/benchmark $(BUILD_DIR)/libcybersand.so
