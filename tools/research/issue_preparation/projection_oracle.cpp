// Independent C++20 arithmetic oracle for research preparation, not engine code.
#include <algorithm>
#include <cstdint>
#include <iostream>
#include <stdexcept>

std::uint32_t q(std::uint32_t n, std::uint32_t d, std::uint32_t maximum) {
    if (d == 0 || n > d || maximum == 0 || maximum > 255)
        throw std::invalid_argument("normalized rational or maximum outside contract");
    // Widen BEFORE multiplication: all valid uint32 numerators fit this product.
    return static_cast<std::uint32_t>((2ULL * n * maximum + d) / (2ULL * d));
}

std::uint32_t coverage(std::uint32_t m, std::uint32_t maximum, unsigned mode) {
    if (mode == 2) return (4 * m + maximum - 1) / maximum;
    const auto v = q(m, maximum, 4);
    return mode == 1 && m != 0 ? std::max(1U, v) : v;
}

int main() {
    try {
        std::cout << "mass_bits,states,roundtrip_failures,coverage_mismatches,full_condition_byte\n";
        for (unsigned bits = 3; bits <= 8; ++bits) {
            const std::uint32_t maximum = (1U << bits) - 1;
            unsigned roundtrip = 0, mismatch = 0;
            for (std::uint32_t m = 0; m <= maximum; ++m) {
                const auto byte = q(m, maximum, 255);
                roundtrip += q(byte, 255, maximum) != m;
                for (unsigned mode = 0; mode < 3; ++mode)
                    mismatch += coverage(m, maximum, mode) != coverage(byte, 255, mode);
            }
            std::cout << bits << ',' << maximum + 1 << ',' << roundtrip << ','
                      << mismatch << ',' << q(maximum, maximum, 255) << '\n';
            if (roundtrip != 0 || q(maximum, maximum, 255) != 255)
                throw std::runtime_error("projection endpoint/round-trip failure");
        }
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
