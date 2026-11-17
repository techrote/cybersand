ROOT := ../../..
CXX ?= g++
BUILD ?= /tmp/gentek-swarm-build
DEFINITION_HASH := $(shell python3 -c 'import hashlib; from pathlib import Path; paths=sorted(Path(".").glob("*.cpp"))+[Path("swarm.hpp"),Path("../../../native/src/generation_spatial.cpp"),Path("../../../native/include/cybersand/material.hpp"),Path("../../../native/include/cybersand/generation_spatial.hpp"),Path("../../../native/include/cybersand/generation_numeric.hpp")]; print(hashlib.sha256(b"".join(str(p).encode()+b"\0"+p.read_bytes() for p in paths)).hexdigest())')
FLAGS := -std=c++20 -Wall -Wextra -Wpedantic -Werror -I$(ROOT)/native/include -DGENTEK_DEFINITION_SHA256=\"$(DEFINITION_HASH)\"
SOURCES := common.cpp fixtures.cpp meshing.cpp io.cpp frameweaver.cpp mosaic.cpp receptor.cpp $(ROOT)/native/src/generation_spatial.cpp
HEADERS := swarm.hpp $(wildcard $(ROOT)/native/include/cybersand/*.hpp)

.PHONY: all test sanitize clean
all: $(BUILD)/gentek_swarm $(BUILD)/test_gentek_swarm

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/gentek_swarm: $(SOURCES) main.cpp $(HEADERS) | $(BUILD)
	$(CXX) $(FLAGS) -O2 $(SOURCES) main.cpp -o $@

$(BUILD)/test_gentek_swarm: $(SOURCES) tests.cpp $(HEADERS) | $(BUILD)
	$(CXX) $(FLAGS) -O2 $(SOURCES) tests.cpp -o $@

test: $(BUILD)/test_gentek_swarm
	$(BUILD)/test_gentek_swarm

$(BUILD)/test_gentek_swarm_sanitized: $(SOURCES) tests.cpp $(HEADERS) | $(BUILD)
	$(CXX) $(FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined $(SOURCES) tests.cpp -o $@

sanitize: $(BUILD)/test_gentek_swarm_sanitized
	ASAN_OPTIONS=detect_leaks=0:halt_on_error=1 UBSAN_OPTIONS=halt_on_error=1 $(BUILD)/test_gentek_swarm_sanitized

clean:
	rm -f $(BUILD)/gentek_swarm $(BUILD)/test_gentek_swarm $(BUILD)/test_gentek_swarm_sanitized
