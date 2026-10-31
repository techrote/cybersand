#pragma once

// The rectangle adapter's production search, shared with its read-only capsule
// replay. Candidate construction stays with the adapter so Godot real_t
// rounding is identical before and after this extraction.
#include <algorithm>
#include <cmath>
#include <cstdint>

namespace cybersand::ejection {
struct Point { std::int32_t x = -1, y = -1; };
struct Cell {
    bool in_bounds = false;
    bool empty = false;
    bool hard = false;
    std::uint16_t body = 0;
};
enum class Reason { Accepted, Bounds, SourceBody, ForeignBody, NonEmpty,
                    PathHard, PathForeign, PathBounds };
inline const char* reason_name(Reason reason) {
    switch (reason) {
    case Reason::Accepted: return "accepted";
    case Reason::Bounds: return "bounds";
    case Reason::SourceBody: return "source_body";
    case Reason::ForeignBody: return "foreign_body";
    case Reason::NonEmpty: return "non_empty";
    case Reason::PathHard: return "path_hard";
    case Reason::PathForeign: return "path_foreign";
    case Reason::PathBounds: return "path_bounds";
    }
    return "invalid";
}
inline std::int32_t symmetric_offset(std::int32_t probe) {
    if (probe == 0) return 0;
    const auto magnitude = (probe + 1) / 2;
    return (probe & 1) != 0 ? magnitude : -magnitude;
}
template<class Read>
Reason path_reason(Point source, Point target, std::uint16_t source_body, Read&& read) {
    const auto dx = target.x - source.x, dy = target.y - source.y;
    const auto samples = std::max(std::abs(dx), std::abs(dy)) * 2;
    for (std::int32_t sample = 1; sample < samples; ++sample) {
        const Point p{source.x + static_cast<std::int32_t>(std::floor(
                          static_cast<double>(dx * sample) / samples + 0.5)),
                      source.y + static_cast<std::int32_t>(std::floor(
                          static_cast<double>(dy * sample) / samples + 0.5))};
        const auto cell = read(p);
        if (!cell.in_bounds) return Reason::PathBounds;
        if (cell.body != 0 && cell.body != source_body) return Reason::PathForeign;
        if (cell.hard) return Reason::PathHard;
    }
    return Reason::Accepted;
}
template<class Read, class Candidate, class Observe>
Point search(Point source, std::uint16_t source_body, std::int32_t first_distance,
             Read&& read, Candidate&& candidate, Observe&& observe) {
    // The inclusive 8-distance extension and nine tangent probes are unchanged.
    for (auto distance = first_distance; distance <= first_distance + 8; ++distance) {
        for (std::int32_t probe = 0; probe < 9; ++probe) {
            const auto point = candidate(distance, symmetric_offset(probe));
            const auto cell = read(point);
            auto reason = Reason::Accepted;
            if (!cell.in_bounds) reason = Reason::Bounds;
            else if (cell.body != 0) reason = cell.body == source_body ? Reason::SourceBody : Reason::ForeignBody;
            else if (!cell.empty) reason = Reason::NonEmpty;
            else reason = path_reason(source, point, source_body, read);
            observe(point, reason);
            if (reason == Reason::Accepted) return point;
        }
    }
    return {};
}
} // namespace cybersand::ejection
