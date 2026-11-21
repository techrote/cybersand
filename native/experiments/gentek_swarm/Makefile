ROOT := ../../..
CXX ?= g++
BUILD ?= /tmp/gentek-swarm-build
DEFINITION_HASH := $(shell python3 -c 'import hashlib; from pathlib import Path; paths=sorted(Path(".").glob("*.cpp"))+sorted(Path(".").glob("*.hpp"))+[Path("../../../native/src/generation_spatial.cpp"),Path("../../../native/include/cybersand/material.hpp"),Path("../../../native/include/cybersand/generation_spatial.hpp"),Path("../../../native/include/cybersand/generation_numeric.hpp")]; print(hashlib.sha256(b"".join(str(p).encode()+b"\0"+p.read_bytes() for p in paths)).hexdigest())')
FLAGS := -std=c++20 -Wall -Wextra -Wpedantic -Werror -I$(ROOT)/native/include -DGENTEK_DEFINITION_SHA256=\"$(DEFINITION_HASH)\"
SOURCES := common.cpp fixtures.cpp meshing.cpp io.cpp frameweaver.cpp mosaic.cpp receptor.cpp negotiated.cpp mosaic_admission.cpp resilience_solver.cpp $(ROOT)/native/src/generation_spatial.cpp
HEADERS := swarm.hpp negotiated.hpp mosaic_admission.hpp resilience_solver.hpp resilience.hpp $(wildcard $(ROOT)/native/include/cybersand/*.hpp)

.PHONY: all test sanitize admission test-admission sanitize-admission resilience test-resilience sanitize-resilience clean
all: $(BUILD)/gentek_swarm $(BUILD)/test_gentek_swarm $(BUILD)/gentek_negotiated $(BUILD)/test_gentek_negotiated
admission: $(BUILD)/gentek_admission $(BUILD)/test_gentek_admission
resilience: $(BUILD)/gentek_resilience $(BUILD)/test_mosaic_admission $(BUILD)/test_resilience_solver $(BUILD)/test_gentek_resilience

$(BUILD)/gentek_resilience: $(SOURCES) resilience_main.cpp $(HEADERS) | $(BUILD)
	$(CXX) $(FLAGS) -O2 $(SOURCES) resilience_main.cpp -o $@

$(BUILD)/test_mosaic_admission: $(SOURCES) admission_resilience_tests.cpp $(HEADERS) | $(BUILD)
	$(CXX) $(FLAGS) -O2 $(SOURCES) admission_resilience_tests.cpp -o $@

$(BUILD)/test_resilience_solver: $(SOURCES) resilience_solver_tests.cpp $(HEADERS) | $(BUILD)
	$(CXX) $(FLAGS) -O2 $(SOURCES) resilience_solver_tests.cpp -o $@

$(BUILD)/test_gentek_resilience: $(SOURCES) resilience_tests.cpp $(HEADERS) | $(BUILD)
	$(CXX) $(FLAGS) -O2 $(SOURCES) resilience_tests.cpp -o $@

$(BUILD)/test_mosaic_admission_sanitized: $(SOURCES) admission_resilience_tests.cpp $(HEADERS) | $(BUILD)
	$(CXX) $(FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined $(SOURCES) admission_resilience_tests.cpp -o $@

$(BUILD)/test_resilience_solver_sanitized: $(SOURCES) resilience_solver_tests.cpp $(HEADERS) | $(BUILD)
	$(CXX) $(FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined $(SOURCES) resilience_solver_tests.cpp -o $@

$(BUILD)/test_gentek_resilience_sanitized: $(SOURCES) resilience_tests.cpp $(HEADERS) | $(BUILD)
	$(CXX) $(FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined $(SOURCES) resilience_tests.cpp -o $@

test-resilience: $(BUILD)/test_mosaic_admission $(BUILD)/test_resilience_solver $(BUILD)/test_gentek_resilience
	$(BUILD)/test_mosaic_admission
	$(BUILD)/test_resilience_solver
	$(BUILD)/test_gentek_resilience

sanitize-resilience: $(BUILD)/test_mosaic_admission_sanitized $(BUILD)/test_resilience_solver_sanitized $(BUILD)/test_gentek_resilience_sanitized
	ASAN_OPTIONS=detect_leaks=0:halt_on_error=1 UBSAN_OPTIONS=halt_on_error=1 $(BUILD)/test_mosaic_admission_sanitized
	ASAN_OPTIONS=detect_leaks=0:halt_on_error=1 UBSAN_OPTIONS=halt_on_error=1 $(BUILD)/test_resilience_solver_sanitized
	ASAN_OPTIONS=detect_leaks=0:halt_on_error=1 UBSAN_OPTIONS=halt_on_error=1 $(BUILD)/test_gentek_resilience_sanitized

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/gentek_swarm: $(SOURCES) main.cpp $(HEADERS) | $(BUILD)
	$(CXX) $(FLAGS) -O2 $(SOURCES) main.cpp -o $@

$(BUILD)/test_gentek_swarm: $(SOURCES) tests.cpp $(HEADERS) | $(BUILD)
	$(CXX) $(FLAGS) -O2 $(SOURCES) tests.cpp -o $@

$(BUILD)/gentek_negotiated: $(SOURCES) negotiated_main.cpp $(HEADERS) | $(BUILD)
	$(CXX) $(FLAGS) -O2 $(SOURCES) negotiated_main.cpp -o $@

$(BUILD)/test_gentek_negotiated: $(SOURCES) negotiated_tests.cpp $(HEADERS) | $(BUILD)
	$(CXX) $(FLAGS) -O2 $(SOURCES) negotiated_tests.cpp -o $@

$(BUILD)/test_gentek_negotiated_sanitized: $(SOURCES) negotiated_tests.cpp $(HEADERS) | $(BUILD)
	$(CXX) $(FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined $(SOURCES) negotiated_tests.cpp -o $@

$(BUILD)/gentek_admission: $(SOURCES) admission_main.cpp $(HEADERS) | $(BUILD)
	$(CXX) $(FLAGS) -O2 $(SOURCES) admission_main.cpp -o $@

$(BUILD)/test_gentek_admission: $(SOURCES) admission_tests.cpp $(HEADERS) | $(BUILD)
	$(CXX) $(FLAGS) -O2 $(SOURCES) admission_tests.cpp -o $@

$(BUILD)/test_gentek_admission_sanitized: $(SOURCES) admission_tests.cpp $(HEADERS) | $(BUILD)
	$(CXX) $(FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined $(SOURCES) admission_tests.cpp -o $@

test-admission: $(BUILD)/test_gentek_admission
	$(BUILD)/test_gentek_admission

sanitize-admission: $(BUILD)/test_gentek_admission_sanitized
	ASAN_OPTIONS=detect_leaks=0:halt_on_error=1 UBSAN_OPTIONS=halt_on_error=1 $(BUILD)/test_gentek_admission_sanitized

test: $(BUILD)/test_gentek_swarm
	$(BUILD)/test_gentek_swarm

$(BUILD)/test_gentek_swarm_sanitized: $(SOURCES) tests.cpp $(HEADERS) | $(BUILD)
	$(CXX) $(FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined $(SOURCES) tests.cpp -o $@

sanitize: $(BUILD)/test_gentek_swarm_sanitized
	ASAN_OPTIONS=detect_leaks=0:halt_on_error=1 UBSAN_OPTIONS=halt_on_error=1 $(BUILD)/test_gentek_swarm_sanitized

clean:
	rm -f $(BUILD)/gentek_swarm $(BUILD)/test_gentek_swarm $(BUILD)/test_gentek_swarm_sanitized $(BUILD)/gentek_negotiated $(BUILD)/test_gentek_negotiated $(BUILD)/test_gentek_negotiated_sanitized $(BUILD)/gentek_admission $(BUILD)/test_gentek_admission $(BUILD)/test_gentek_admission_sanitized
	rm -f $(BUILD)/gentek_resilience $(BUILD)/test_mosaic_admission $(BUILD)/test_resilience_solver $(BUILD)/test_gentek_resilience $(BUILD)/test_mosaic_admission_sanitized $(BUILD)/test_resilience_solver_sanitized $(BUILD)/test_gentek_resilience_sanitized
