#pragma once

#include <algorithm>
#include <cmath>

namespace cybersand::generation::detail {

// Internal two-component magnitude for the bounded finite spatial evaluator.
// Scaling keeps tiny gradients and subnormal axes from disappearing when
// squared. Admitted component magnitudes are at most 1e100, so the final product
// cannot overflow. Use sqrt rather than hypot to retain the Linux GLIBC 2.34
// runtime floor; std::hypot on the build host imports a newer symbol version.
[[nodiscard]] inline double magnitude(double x, double y) noexcept {
    const double scale = std::max(std::abs(x), std::abs(y));
    if (scale == 0) return 0;
    x /= scale;
    y /= scale;
    return scale * std::sqrt(x * x + y * y);
}

} // namespace cybersand::generation::detail
