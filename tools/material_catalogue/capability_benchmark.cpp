// Small advisory hot-query timing; exact native results remain the acceptance.
#include "cybersand/material_rules.hpp"
#include <chrono>
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <string>

int main(int argc, char** argv) {
    if (argc != 2) return 2;
    const auto iterations = std::stoull(argv[1]);
    if (iterations < 256 || iterations > 1000000000ULL) return 2;
    std::uint64_t checksum = 0;
    const auto start = std::chrono::steady_clock::now();
    for (std::uint64_t index = 0; index < iterations; ++index) {
        const auto material = static_cast<cybersand::Material>((index * 197U + 101U) & 255U);
        checksum += static_cast<unsigned>(cybersand::MaterialRules::is_hard_surface(material));
        checksum += 2U * static_cast<unsigned>(cybersand::MaterialRules::supports_granular_load(material));
    }
    const auto elapsed = std::chrono::duration_cast<std::chrono::nanoseconds>(
        std::chrono::steady_clock::now() - start).count();
    std::cout << "{\"query_calls\":" << iterations * 2U << ",\"checksum\":" << checksum
              << ",\"nanoseconds\":" << elapsed << "}\n";
}
