#pragma once

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <limits>

namespace cybersand::solid_contact {

// Geometry only: no material mutation, contact impulse, tolerance inflation or
// compound ownership policy. Coordinates use simulation cells; angles radians.
struct Vec2 { double x{}, y{}; };
struct OrientedRect {
    Vec2 center{}, half_size{};
    double rotation{};
};
enum class Outcome { Invalid, Separated, Touching, Overlap };
struct Intersection {
    Outcome outcome{Outcome::Invalid};
    // Minimum translation along normal that separates the cell from this
    // rectangle (to touching). Unlike projection-intersection length, this
    // remains correct when one projected interval contains the other.
    double depth{};
    double area{};
    // Unit normal points from rectangle towards cell. A body resistance acts
    // in the opposite direction. Ties use world X,Y, then rectangle X,Y.
    Vec2 normal{};
    // Area centroid in world coordinates; no contact-point meaning is implied
    // for Invalid/Separated. A touching segment/point uses its vertex mean.
    Vec2 centroid{};
    std::size_t vertex_count{};
};

namespace detail {
[[nodiscard]] inline bool finite(Vec2 p) noexcept {
    return std::isfinite(p.x) && std::isfinite(p.y);
}
[[nodiscard]] inline double dot(Vec2 a, Vec2 b) noexcept {
    return a.x * b.x + a.y * b.y;
}
[[nodiscard]] inline Vec2 sub(Vec2 a, Vec2 b) noexcept {
    return {a.x - b.x, a.y - b.y};
}
[[nodiscard]] inline double cross(Vec2 a, Vec2 b) noexcept {
    return a.x * b.y - a.y * b.x;
}
[[nodiscard]] inline bool equal(Vec2 a, Vec2 b) noexcept {
    return a.x == b.x && a.y == b.y;
}

// A rectangle clipped by four halfplanes has at most eight distinct vertices.
// Every intermediate remains convex. Capacity failures refuse, never truncate.
struct Polygon {
    std::array<Vec2, 8> points{};
    std::size_t count{};
    [[nodiscard]] bool append(Vec2 p) noexcept {
        if (!finite(p)) return false;
        if (count != 0 && equal(points[count - 1], p)) return true;
        if (count == points.size()) return false;
        points[count++] = p;
        return true;
    }
};

[[nodiscard]] inline bool clip(Polygon& polygon, Vec2 axis, double limit) noexcept {
    if (!std::isfinite(limit)) return false;
    Polygon output;
    if (polygon.count == 0) return true;
    auto previous = polygon.points[polygon.count - 1];
    auto previous_distance = dot(previous, axis) - limit;
    for (std::size_t i = 0; i < polygon.count; ++i) {
        const auto current = polygon.points[i];
        const auto distance = dot(current, axis) - limit;
        if (!std::isfinite(distance) || !std::isfinite(previous_distance)) return false;
        const bool inside = distance <= 0.0;
        const bool previous_inside = previous_distance <= 0.0;
        if (inside != previous_inside) {
            Vec2 crossing;
            // Use an exact endpoint at a touching vertex, preventing duplicate
            // vertices introduced by interpolation rounding at t=0 or t=1.
            if (distance == 0.0) crossing = current;
            else if (previous_distance == 0.0) crossing = previous;
            else {
                const auto denominator = previous_distance - distance;
                const auto t = previous_distance / denominator;
                if (!std::isfinite(denominator) || denominator == 0.0 ||
                    !std::isfinite(t) || t < 0.0 || t > 1.0) return false;
                crossing = {previous.x + t * (current.x - previous.x),
                            previous.y + t * (current.y - previous.y)};
            }
            if (!output.append(crossing)) return false;
        }
        if (inside && !output.append(current)) return false;
        previous = current;
        previous_distance = distance;
    }
    if (output.count > 1 && equal(output.points[0], output.points[output.count - 1]))
        --output.count;
    polygon = output;
    return true;
}
} // namespace detail

// Exact polygon intersection in double precision, rather than a centre mask or
// AABB estimate. The unit square is [cell_x,cell_x+1] x [cell_y,cell_y+1]. No heap
// allocation; four SAT axes, four clips, at most eight vertices. No epsilon is
// silently added: the contact policy must name its own admission tolerance.
[[nodiscard]] inline Intersection intersect_unit_square(
        const OrientedRect& rectangle, double cell_x, double cell_y) noexcept {
    using namespace detail;
    if (!finite(rectangle.center) || !finite(rectangle.half_size) ||
        rectangle.half_size.x <= 0.0 || rectangle.half_size.y <= 0.0 ||
        !std::isfinite(rectangle.rotation) || !std::isfinite(cell_x) ||
        !std::isfinite(cell_y) || cell_x + 1.0 == cell_x || cell_y + 1.0 == cell_y)
        return {};

    const Vec2 cell_center{cell_x + 0.5, cell_y + 0.5};
    const auto delta = sub(cell_center, rectangle.center);
    if (!finite(cell_center) || !finite(delta)) return {};
    const auto c = std::cos(rectangle.rotation), s = std::sin(rectangle.rotation);
    const Vec2 u{c, s}, v{-s, c};
    if (!finite(u) || !finite(v)) return {};
    const std::array<Vec2, 4> axes{{{1.0, 0.0}, {0.0, 1.0}, u, v}};
    Intersection result;
    result.depth = std::numeric_limits<double>::infinity();
    for (const auto axis : axes) {
        const auto center_projection = dot(delta, axis);
        const auto rectangle_radius = rectangle.half_size.x * std::abs(dot(u, axis)) +
                                      rectangle.half_size.y * std::abs(dot(v, axis));
        const auto cell_radius = 0.5 * (std::abs(axis.x) + std::abs(axis.y));
        const auto depth = rectangle_radius + cell_radius - std::abs(center_projection);
        if (!std::isfinite(depth)) return {};
        if (depth < 0.0) {
            result = {};
            result.outcome = Outcome::Separated;
            return result;
        }
        if (depth < result.depth) {
            result.depth = depth;
            const auto sign = center_projection < 0.0 ? -1.0 : 1.0;
            result.normal = {sign * axis.x, sign * axis.y};
        }
    }

    // Keep polygon arithmetic close to the unit cell, avoiding subtraction of
    // large world-coordinate area products for thin partial overlaps.
    Polygon polygon{{{{-0.5, -0.5}, {0.5, -0.5}, {0.5, 0.5}, {-0.5, 0.5}}}, 4};
    const auto center_u = -dot(delta, u), center_v = -dot(delta, v);
    if (!clip(polygon, u, center_u + rectangle.half_size.x) ||
        !clip(polygon, {-u.x, -u.y}, -center_u + rectangle.half_size.x) ||
        !clip(polygon, v, center_v + rectangle.half_size.y) ||
        !clip(polygon, {-v.x, -v.y}, -center_v + rectangle.half_size.y)) return {};
    if (polygon.count == 0) {
        // SAT and clipping disagree only at an unresolved floating-point edge.
        // Refuse the geometry rather than manufacture a contact or clearance.
        return {};
    }
    result.vertex_count = polygon.count;
    const auto origin = polygon.points[0];
    double twice_area = 0.0;
    Vec2 centroid_sum{};
    for (std::size_t i = 1; i + 1 < polygon.count; ++i) {
        const auto a = sub(polygon.points[i], origin);
        const auto b = sub(polygon.points[i + 1], origin);
        const auto weight = cross(a, b);
        twice_area += weight;
        centroid_sum.x += (a.x + b.x) * weight;
        centroid_sum.y += (a.y + b.y) * weight;
    }
    if (!std::isfinite(twice_area) || twice_area < 0.0 || !finite(centroid_sum)) return {};
    if (twice_area == 0.0) {
        if (result.depth != 0.0) return {};
        Vec2 mean{};
        for (std::size_t i = 0; i < polygon.count; ++i) {
            mean.x += polygon.points[i].x;
            mean.y += polygon.points[i].y;
        }
        result.centroid = {cell_center.x + mean.x / static_cast<double>(polygon.count),
                           cell_center.y + mean.y / static_cast<double>(polygon.count)};
        result.outcome = Outcome::Touching;
    } else {
        result.area = 0.5 * twice_area;
        result.centroid = {cell_center.x + origin.x + centroid_sum.x / (3.0 * twice_area),
                           cell_center.y + origin.y + centroid_sum.y / (3.0 * twice_area)};
        result.outcome = Outcome::Overlap;
    }
    if (!finite(result.centroid)) return {};
    return result;
}

} // namespace cybersand::solid_contact
