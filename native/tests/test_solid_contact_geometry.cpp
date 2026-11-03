#include "cybersand/solid_contact_geometry.hpp"

#include <array>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <new>
#include <numbers>
#include <stdexcept>
#include <vector>

// Geometry may run in the native contact loop. Any accidental heap allocation
// during a query fails, independently of its numerical result.
static std::atomic<bool> forbid_allocation{false};
void* operator new(std::size_t n) {
    if (forbid_allocation.load()) throw std::bad_alloc();
    if (auto* p = std::malloc(n == 0 ? 1 : n)) return p;
    throw std::bad_alloc();
}
void* operator new[](std::size_t n) { return ::operator new(n); }
void operator delete(void* p) noexcept { std::free(p); }
void operator delete[](void* p) noexcept { std::free(p); }
void operator delete(void* p, std::size_t) noexcept { std::free(p); }
void operator delete[](void* p, std::size_t) noexcept { std::free(p); }

namespace sc = cybersand::solid_contact;
static unsigned groups = 0, checks = 0;
void expect(bool condition, const char* message) {
    ++checks;
    if (!condition) throw std::runtime_error(message);
}
void near(double actual, double expected, double tolerance, const char* message) {
    if (!std::isfinite(actual) || std::abs(actual - expected) > tolerance) {
        std::cerr << message << ": actual=" << actual << " expected=" << expected << '\n';
        expect(false, message);
    }
    expect(true, message);
}
sc::Intersection query(const sc::OrientedRect& r, double x = 0.0, double y = 0.0) {
    struct Guard {
        Guard() { forbid_allocation = true; }
        ~Guard() { forbid_allocation = false; }
    } guard;
    return sc::intersect_unit_square(r, x, y);
}

void analytic_axis_aligned() {
    auto r = query({{0.5, 0.5}, {0.5, 0.5}, 0.0});
    expect(r.outcome == sc::Outcome::Overlap && r.vertex_count == 4, "identical unit squares overlap");
    near(r.area, 1.0, 1e-14, "identical square area");
    near(r.depth, 1.0, 1e-14, "identical square separation depth");
    near(r.normal.x, 1.0, 1e-14, "centered tie selects positive world X");
    near(r.normal.y, 0.0, 1e-14, "centered tie normal Y");
    near(r.centroid.x, 0.5, 1e-14, "identical square centroid X");
    near(r.centroid.y, 0.5, 1e-14, "identical square centroid Y");

    r = query({{0.5, 0.5}, {2.0, 2.0}, 0.0});
    near(r.area, 1.0, 1e-14, "contained cell keeps complete area");
    near(r.depth, 2.5, 1e-14, "contained cell depth is not intersection length");
    r = query({{1.25, 0.5}, {2.0, 3.0}, 0.0});
    near(r.depth, 1.75, 1e-14, "off-center containment depth");
    near(r.normal.x, -1.0, 1e-14, "off-center containment chooses nearest exit");
    r = query({{0.5, 0.5}, {0.25, 0.125}, 0.0});
    near(r.area, 0.125, 1e-14, "contained rectangle area");
    near(r.depth, 0.625, 1e-14, "contained rectangle separation depth");
    near(r.normal.y, 1.0, 1e-14, "contained rectangle closest axis");
    r = query({{0.75, 0.5}, {0.5, 0.5}, 0.0});
    near(r.area, 0.75, 1e-14, "partial overlap area");
    near(r.depth, 0.75, 1e-14, "partial overlap depth");
    near(r.centroid.x, 0.625, 1e-14, "partial overlap centroid");
    near(r.normal.x, -1.0, 1e-14, "partial overlap direction");
    r = query({{-0.25, 0.5}, {0.5, 0.5}, 0.0});
    near(r.area, 0.25, 1e-14, "opposite partial overlap area");
    near(r.depth, 0.25, 1e-14, "opposite partial overlap depth");
    near(r.centroid.x, 0.125, 1e-14, "opposite partial overlap centroid");
    near(r.normal.x, 1.0, 1e-14, "opposite partial overlap direction");
    ++groups;
}

void touching_and_separation() {
    auto r = query({{-0.5, 0.5}, {0.5, 0.5}, 0.0});
    expect(r.outcome == sc::Outcome::Touching && r.vertex_count == 2,
           "edge touch is distinct from positive area");
    near(r.area, 0.0, 0.0, "edge touch has zero area");
    near(r.depth, 0.0, 0.0, "edge touch has zero depth");
    near(r.centroid.x, 0.0, 0.0, "edge touch point X");
    near(r.centroid.y, 0.5, 0.0, "edge touch mean Y");
    r = query({{-0.5, -0.5}, {0.5, 0.5}, 0.0});
    expect(r.outcome == sc::Outcome::Touching && r.vertex_count == 1,
           "point touch is distinct from positive area");
    near(r.centroid.x, 0.0, 0.0, "point touch centroid X");
    near(r.centroid.y, 0.0, 0.0, "point touch centroid Y");
    r = query({{-0.500000001, 0.5}, {0.5, 0.5}, 0.0});
    expect(r.outcome == sc::Outcome::Separated, "a positive gap is not inflated into contact");
    r = query({{-0.499999999, 0.5}, {0.5, 0.5}, 0.0});
    expect(r.outcome == sc::Outcome::Overlap, "a shallow positive overlap is retained");
    near(r.area, 1e-9, 1e-16, "shallow overlap area");
    const sc::OrientedRect diagonal{{1.2, 1.2}, {1.0, 0.05}, -std::numbers::pi / 4.0};
    const double radius = 1.05 / std::sqrt(2.0);
    expect(diagonal.center.x - radius < 1.0 && diagonal.center.y - radius < 1.0,
           "rotated negative really has AABB overlap");
    expect(query(diagonal).outcome == sc::Outcome::Separated,
           "rotated diagonal excludes false AABB contact");
    ++groups;
}

void rotated_analytic_and_symmetry() {
    const auto quarter_turn = std::numbers::pi / 2.0;
    const auto eighth_turn = std::numbers::pi / 4.0;
    auto r = query({{0.0, 0.0}, {1.0 / std::sqrt(2.0), 1.0 / std::sqrt(2.0)}, eighth_turn});
    expect(r.outcome == sc::Outcome::Overlap, "diamond corner overlaps");
    near(r.area, 0.5, 2e-14, "diamond triangle analytic area");
    near(r.centroid.x, 1.0 / 3.0, 2e-14, "diamond triangle centroid X");
    near(r.centroid.y, 1.0 / 3.0, 2e-14, "diamond triangle centroid Y");
    near(r.depth, 1.0 / std::sqrt(2.0), 2e-14, "diamond separation depth");
    near(r.normal.x, 1.0 / std::sqrt(2.0), 2e-14, "diamond normal X");
    near(r.normal.y, 1.0 / std::sqrt(2.0), 2e-14, "diamond normal Y");
    r = query({{0.0, 0.0}, {0.5, 0.5}, eighth_turn});
    expect(r.outcome == sc::Outcome::Overlap, "cell with center outside still has overlap");
    near(r.area, 0.25, 2e-14, "center-outside triangle exact area");
    near(r.centroid.x, std::sqrt(0.5) / 3.0, 2e-14, "center-outside centroid");

    const sc::OrientedRect rectangle{{0.2, 0.7}, {0.8, 0.35}, 0.37};
    const auto original = query(rectangle);
    const auto translated = query({{rectangle.center.x + 1000.0, rectangle.center.y - 300.0},
                                    rectangle.half_size, rectangle.rotation}, 1000.0, -300.0);
    const auto reflected = query({{rectangle.center.x, -rectangle.center.y},
                                  rectangle.half_size, -rectangle.rotation}, 0.0, -1.0);
    near(translated.area, original.area, 1e-12, "large world translation preserves area");
    near(translated.depth, original.depth, 1e-12, "large world translation preserves depth");
    near(translated.centroid.x - 1000.0, original.centroid.x, 1e-12, "translated centroid X");
    near(translated.centroid.y + 300.0, original.centroid.y, 1e-12, "translated centroid Y");
    near(reflected.area, original.area, 1e-13, "negative-angle reflection area");
    near(reflected.depth, original.depth, 1e-13, "negative-angle reflection depth");
    near(reflected.centroid.x, original.centroid.x, 1e-13, "reflection centroid X");
    near(reflected.centroid.y, -original.centroid.y, 1e-13, "reflection centroid Y");
    const auto axis = query({{0.2, 0.7}, {0.8, 0.35}, 0.0});
    const auto half = query({{0.2, 0.7}, {0.8, 0.35}, std::numbers::pi});
    const auto quarter = query({{0.2, 0.7}, {0.35, 0.8}, quarter_turn});
    near(axis.area, half.area, 1e-14, "pi symmetry area");
    near(axis.area, quarter.area, 1e-14, "quarter-turn swapped dimensions area");
    near(axis.depth, half.depth, 1e-14, "pi symmetry depth");
    near(axis.depth, quarter.depth, 1e-14, "quarter-turn swapped dimensions depth");
    ++groups;
}

void holes_and_compound_area() {
    const std::array<sc::OrientedRect, 4> ring{{
        {{4.0, 1.0}, {4.0, 1.0}, 0.0}, {{4.0, 7.0}, {4.0, 1.0}, 0.0},
        {{1.0, 4.0}, {1.0, 2.0}, 0.0}, {{7.0, 4.0}, {1.0, 2.0}, 0.0}
    }};
    for (const auto angle : {0.0, 0.37, -0.79, std::numbers::pi / 2.0, std::numbers::pi}) {
        auto compound = ring;
        const auto c = std::cos(angle), s = std::sin(angle);
        double total = 0.0, hole = 0.0;
        for (auto& rectangle : compound) {
            const auto x = rectangle.center.x - 4.0, y = rectangle.center.y - 4.0;
            rectangle.center = {4.0 + c * x - s * y, 4.0 + s * x + c * y};
            rectangle.rotation = angle;
            hole += query(rectangle, 3.0, 3.0).area;
        }
        near(hole, 0.0, 0.0, "compound hole never becomes filled AABB material");
        for (int y = -4; y < 12; ++y) for (int x = -4; x < 12; ++x) {
            double cell_area = 0.0;
            for (const auto& rectangle : compound) {
                const auto contact = query(rectangle, static_cast<double>(x), static_cast<double>(y));
                // At exactly coincident floating-point boundaries, Invalid is
                // a declared safe refusal. It may not discard positive area.
                if (contact.outcome == sc::Outcome::Overlap) cell_area += contact.area;
            }
            expect(cell_area >= 0.0 && cell_area <= 1.0 + 1e-12,
                   "disjoint proxy union counts each square area at most once");
            total += cell_area;
        }
        near(total, 48.0, 2e-11, "rotated compound exact occupied area conserved");
    }
    ++groups;
}

// Independent long-double oracle: collect contained vertices and segment
// intersections, then form a convex hull. It uses neither production clipping
// nor the four-axis formula. A separate Minkowski hull gives separation depth.
namespace oracle {
struct Point { long double x{}, y{}; };
Point operator+(Point a, Point b) { return {a.x + b.x, a.y + b.y}; }
Point operator-(Point a, Point b) { return {a.x - b.x, a.y - b.y}; }
Point operator*(Point a, long double k) { return {a.x * k, a.y * k}; }
long double dot(Point a, Point b) { return a.x * b.x + a.y * b.y; }
long double cross(Point a, Point b) { return a.x * b.y - a.y * b.x; }
using Quad = std::array<Point, 4>;
Quad corners(const sc::OrientedRect& r) {
    const long double c = std::cos(static_cast<long double>(r.rotation));
    const long double s = std::sin(static_cast<long double>(r.rotation));
    const auto hx = static_cast<long double>(r.half_size.x), hy = static_cast<long double>(r.half_size.y);
    Quad result{{{-hx,-hy},{hx,-hy},{hx,hy},{-hx,hy}}};
    for (auto& p : result) p = {r.center.x + c * p.x - s * p.y, r.center.y + s * p.x + c * p.y};
    return result;
}
template<typename Polygon>
bool inside(Point p, const Polygon& polygon) {
    for (std::size_t i = 0; i < polygon.size(); ++i)
        if (cross(polygon[(i + 1) % polygon.size()] - polygon[i], p - polygon[i]) < -1e-18L) return false;
    return true;
}
std::vector<Point> hull(std::vector<Point> points) {
    std::sort(points.begin(), points.end(), [](Point a, Point b) {
        return a.x == b.x ? a.y < b.y : a.x < b.x;
    });
    points.erase(std::unique(points.begin(), points.end(), [](Point a, Point b) {
        return std::abs(a.x - b.x) < 1e-17L && std::abs(a.y - b.y) < 1e-17L;
    }), points.end());
    if (points.size() < 3) return points;
    std::vector<Point> result(points.size() * 2);
    std::size_t size = 0;
    for (const auto p : points) {
        while (size >= 2 && cross(result[size - 1] - result[size - 2], p - result[size - 1]) <= 0.0L) --size;
        result[size++] = p;
    }
    const auto lower = size + 1;
    for (std::size_t i = points.size() - 1; i > 0; --i) {
        const auto p = points[i - 1];
        while (size >= lower && cross(result[size - 1] - result[size - 2], p - result[size - 1]) <= 0.0L) --size;
        result[size++] = p;
    }
    result.resize(size - 1);
    return result;
}
struct Result { long double area{}, depth{}; Point centroid{}; };
Result intersect(const sc::OrientedRect& r) {
    const auto rectangle = corners(r);
    const Quad square{{{0.0L,0.0L},{1.0L,0.0L},{1.0L,1.0L},{0.0L,1.0L}}};
    std::vector<Point> points;
    for (const auto p : rectangle) if (inside(p, square)) points.push_back(p);
    for (const auto p : square) if (inside(p, rectangle)) points.push_back(p);
    for (std::size_t i = 0; i < 4; ++i) for (std::size_t j = 0; j < 4; ++j) {
        const auto a = rectangle[i], b = square[j];
        const auto u = rectangle[(i + 1) % 4] - a, v = square[(j + 1) % 4] - b;
        const auto denominator = cross(u, v);
        if (std::abs(denominator) < 1e-18L) continue;
        const auto t = cross(b - a, v) / denominator, w = cross(b - a, u) / denominator;
        if (t >= 0.0L && t <= 1.0L && w >= 0.0L && w <= 1.0L) points.push_back(a + u * t);
    }
    const auto polygon = hull(points);
    Result result;
    if (polygon.size() < 3) return result;
    long double twice_area = 0.0L;
    Point numerator;
    for (std::size_t i = 0; i < polygon.size(); ++i) {
        const auto a = polygon[i], b = polygon[(i + 1) % polygon.size()];
        const auto weight = cross(a, b);
        twice_area += weight;
        numerator = numerator + (a + b) * weight;
    }
    result.area = twice_area / 2.0L;
    result.centroid = numerator * (1.0L / (3.0L * twice_area));
    points.clear();
    for (const auto a : rectangle) for (const auto b : square) points.push_back(b - a);
    const auto minkowski = hull(points);
    expect(inside(Point{}, minkowski), "oracle Minkowski polygon contains origin for overlap");
    result.depth = std::numeric_limits<long double>::infinity();
    for (std::size_t i = 0; i < minkowski.size(); ++i) {
        const auto a = minkowski[i], delta = minkowski[(i + 1) % minkowski.size()] - a;
        const auto t = std::clamp(-dot(a, delta) / dot(delta, delta), 0.0L, 1.0L);
        const auto nearest = a + delta * t;
        result.depth = std::min(result.depth, std::sqrt(dot(nearest, nearest)));
    }
    return result;
}
} // namespace oracle

void independent_random_oracle() {
    std::uint64_t state = 0x429f8ad3f17b0205ULL;
    const auto random = [&state]() {
        state ^= state << 13U; state ^= state >> 7U; state ^= state << 17U;
        return static_cast<double>(state >> 11U) / 9007199254740992.0;
    };
    unsigned overlaps = 0, separated = 0;
    for (unsigned i = 0; i < 1200; ++i) {
        const sc::OrientedRect rectangle{{-2.0 + 5.0 * random(), -2.0 + 5.0 * random()},
                                        {0.01 + 2.0 * random(), 0.01 + 2.0 * random()},
                                        (2.0 * random() - 1.0) * std::numbers::pi};
        const auto expected = oracle::intersect(rectangle);
        const auto actual = query(rectangle);
        if (expected.area == 0.0L) {
            ++separated;
            expect(actual.outcome == sc::Outcome::Separated, "independent random separation classification");
            continue;
        }
        ++overlaps;
        expect(actual.outcome == sc::Outcome::Overlap, "independent random positive intersection classification");
        expect(actual.vertex_count >= 3 && actual.vertex_count <= 8, "intersection vertex capacity");
        near(actual.area, static_cast<double>(expected.area), 2e-12, "independent hull area");
        near(actual.depth, static_cast<double>(expected.depth), 2e-12, "independent Minkowski separation depth");
        near(actual.centroid.x, static_cast<double>(expected.centroid.x), 2e-11, "independent hull centroid X");
        near(actual.centroid.y, static_cast<double>(expected.centroid.y), 2e-11, "independent hull centroid Y");
        near(std::hypot(actual.normal.x, actual.normal.y), 1.0, 1e-14, "unit contact normal");
        auto escaped = rectangle;
        escaped.center.x -= actual.normal.x * (actual.depth + 1e-8);
        escaped.center.y -= actual.normal.y * (actual.depth + 1e-8);
        expect(query(escaped).outcome == sc::Outcome::Separated, "reported normal/depth actually separates polygons");
        if (actual.depth > 1e-7) {
            auto incomplete = rectangle;
            incomplete.center.x -= actual.normal.x * (actual.depth - 1e-8);
            incomplete.center.y -= actual.normal.y * (actual.depth - 1e-8);
            expect(query(incomplete).outcome == sc::Outcome::Overlap, "insufficient translation leaves overlap");
        }
    }
    expect(overlaps > 300 && separated > 300, "independent oracle exercises both dense and separated cases");
    ++groups;
}

void invalid_inputs() {
    const auto nan = std::numeric_limits<double>::quiet_NaN();
    const auto inf = std::numeric_limits<double>::infinity();
    const std::array<sc::OrientedRect, 9> rectangles{{
        {{0.5,0.5},{0.0,1.0},0.0}, {{0.5,0.5},{1.0,-1.0},0.0},
        {{nan,0.5},{1.0,1.0},0.0}, {{0.5,inf},{1.0,1.0},0.0},
        {{0.5,0.5},{nan,1.0},0.0}, {{0.5,0.5},{1.0,inf},0.0},
        {{0.5,0.5},{1.0,1.0},nan}, {{0.5,0.5},{1.0,1.0},inf},
        {{0.5,0.5},{1.7e308,1.7e308},0.37}
    }};
    for (const auto& rectangle : rectangles)
        expect(query(rectangle).outcome == sc::Outcome::Invalid, "invalid or overflowing geometry refuses");
    const sc::OrientedRect valid{{0.5,0.5},{1.0,1.0},0.0};
    expect(query(valid, nan).outcome == sc::Outcome::Invalid, "NaN cell refuses");
    expect(query(valid, 0.0, inf).outcome == sc::Outcome::Invalid, "infinite cell refuses");
    expect(query(valid, 1e300).outcome == sc::Outcome::Invalid, "unrepresentable unit cell refuses");
    ++groups;
}

int main() {
    try {
        analytic_axis_aligned();
        touching_and_separation();
        rotated_analytic_and_symmetry();
        holes_and_compound_area();
        independent_random_oracle();
        invalid_inputs();
        std::cout << "SOL281_CONTACT_GEOMETRY " << groups << " groups / " << checks << " checks passed\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "FAIL SOL281_CONTACT_GEOMETRY after " << checks << " checks: " << error.what() << '\n';
        return 1;
    }
}
