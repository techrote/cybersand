#include "cybersand/generation_typed_fields.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <future>
#include <iostream>
#include <limits>
#include <map>
#include <memory>
#include <new>
#include <numbers>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace typed_allocation_probe {
thread_local bool enabled = false;
thread_local std::size_t count = 0;
}

#if defined(__GNUC__) || defined(__clang__)
#define TYPED_TEST_NOINLINE __attribute__((noinline))
#else
#define TYPED_TEST_NOINLINE
#endif
TYPED_TEST_NOINLINE void* operator new(std::size_t size) {
    if (typed_allocation_probe::enabled) ++typed_allocation_probe::count;
    if (void* result = std::malloc(size == 0 ? 1 : size)) return result;
    throw std::bad_alloc();
}
TYPED_TEST_NOINLINE void operator delete(void* pointer) noexcept { std::free(pointer); }
TYPED_TEST_NOINLINE void operator delete(void* pointer, std::size_t) noexcept { ::operator delete(pointer); }
TYPED_TEST_NOINLINE void* operator new[](std::size_t size) { return ::operator new(size); }
TYPED_TEST_NOINLINE void operator delete[](void* pointer) noexcept { ::operator delete(pointer); }
TYPED_TEST_NOINLINE void operator delete[](void* pointer, std::size_t) noexcept { ::operator delete(pointer); }
#undef TYPED_TEST_NOINLINE

namespace {
using namespace cybersand::generation;

std::size_t assertions = 0;
void require(bool condition, const char* message) {
    ++assertions;
    if (!condition) throw std::runtime_error(message);
}
void near(double actual, double expected, const char* message, double tolerance = 1e-10) {
    require(std::isfinite(actual) && std::abs(actual - expected) <= tolerance, message);
}
template<class Action> void rejects(Action&& action, const char* message) {
    bool rejected = false;
    try { action(); } catch (const std::exception&) { rejected = true; }
    require(rejected, message);
}
SpatialNode node(std::string id, SpatialKind kind,
                 std::vector<std::string> inputs = {},
                 std::map<std::string, double> parameters = {}) {
    SpatialNode result;
    result.id = std::move(id);
    result.kind = kind;
    result.inputs = std::move(inputs);
    result.parameters = std::move(parameters);
    return result;
}
SpatialValue value(SpatialType type, double x, double y = 0) {
    SpatialValue result;
    result.type = type; result.x = x; result.y = y;
    return result;
}
SpatialNode constant(std::string id, double x, std::int32_t units = 0,
                     SpatialType type = SpatialType::Scalar) {
    auto result = node(std::move(id), SpatialKind::Constant);
    result.value = value(type, x); result.unit_power = units;
    return result;
}
SpatialNode category(std::string id, SpatialCategory identity) {
    auto result = node(std::move(id), SpatialKind::Constant);
    result.value.type = SpatialType::Category; result.value.category = identity;
    return result;
}
std::shared_ptr<const SpatialGraph> compile(std::vector<SpatialNode> nodes,
                                           std::uint64_t seed = 17,
                                           SpatialLimits limits = {}) {
    SpatialDefinition definition; definition.nodes = std::move(nodes);
    return SpatialGraph::compile(std::move(definition), seed, limits);
}
SpatialValue sample(const SpatialGraph& graph, const std::string& id,
                    std::int64_t x = 0, std::int64_t y = 0,
                    SpatialScratch* scratch = nullptr) {
    return graph.sample(id, x, y, scratch);
}
const SpatialInfo& info(const SpatialGraph& graph, const std::string& id) {
    return graph.info(graph.index(id));
}
void same(const SpatialValues& actual, const SpatialValues& expected, const char* message) {
    require(actual.size == expected.size && actual.values == expected.values, message);
}

void signed_values_types_and_units() {
    auto graph = compile({
        constant("negative", -7), constant("two", 2),
        constant("normalized", .25, 0, SpatialType::Normalized),
        node("sum", SpatialKind::Add, {"negative", "two"}),
        node("product", SpatialKind::Multiply, {"negative", "two"}),
        node("mask", SpatialKind::ToMask, {"negative"}, {{"low", -10}, {"high", 0}}),
        node("x", SpatialKind::CoordinateX), node("y", SpatialKind::CoordinateY),
        node("xy", SpatialKind::Multiply, {"x", "y"}),
        node("position", SpatialKind::ComposeVector, {"x", "y"}),
        node("length", SpatialKind::Length, {"position"}),
        node("unit", SpatialKind::UnitVector, {"position"}),
        node("dot", SpatialKind::Dot, {"position", "position"})
    });
    near(sample(*graph, "negative").x, -7, "general scalar retains a negative constant without clamping");
    near(sample(*graph, "sum").x, -5, "signed addition preserves a signed result");
    near(sample(*graph, "product").x, -14, "signed product is not a normalized-mask operation");
    near(sample(*graph, "mask").x, .3, "normalization requires an explicit low/high conversion");
    require(info(*graph, "mask").type == SpatialType::Normalized, "to_mask declares normalized output");
    require(info(*graph, "x").unit_power == 1 && info(*graph, "xy").unit_power == 2,
            "coordinates have cell units and multiplication adds unit powers");
    require(info(*graph, "position").type == SpatialType::Vector2 && info(*graph, "length").unit_power == 1,
            "vector composition and length retain coordinate units");
    require(info(*graph, "unit").unit_power == 0 && info(*graph, "dot").unit_power == 2,
            "normalization removes units and dot product combines them");
    near(sample(*graph, "length", 3, 4).x, 5, "vector length matches the independent 3-4-5 triangle");
    const auto unit = sample(*graph, "unit", 3, 4);
    near(unit.x, .6, "unit-vector x component"); near(unit.y, .8, "unit-vector y component");
    near(sample(*graph, "dot", 3, 4).x, 25, "dot product is squared length");
    const auto zero = sample(*graph, "unit", 0, 0);
    near(zero.x, 0, "zero-length vector normalization has a finite explicit zero x");
    near(zero.y, 0, "zero-length vector normalization has a finite explicit zero y");

    rejects([] { (void)compile({constant("bad", -0.1, 0, SpatialType::Normalized)}); }, "normalized constants reject negative input");
    rejects([] { (void)compile({constant("bad", 1.1, 0, SpatialType::Normalized)}); }, "normalized constants reject values above one");
    rejects([] { (void)compile({node("x", SpatialKind::CoordinateX), constant("unitless", 1),
                               node("bad", SpatialKind::Add, {"x", "unitless"})}); }, "addition rejects incompatible units");
    rejects([] { (void)compile({node("x", SpatialKind::CoordinateX), constant("unitless", 1),
                               node("bad", SpatialKind::ComposeVector, {"x", "unitless"})}); }, "vector components require the same units");
}

std::vector<SpatialNode> polynomial_nodes() {
    return {
        node("x", SpatialKind::CoordinateX), node("y", SpatialKind::CoordinateY),
        constant("negative_one", -1),
        node("xx", SpatialKind::Multiply, {"x", "x"}),
        node("yy", SpatialKind::Multiply, {"y", "y"}),
        node("bowl", SpatialKind::Add, {"xx", "yy"}),
        node("gradient", SpatialKind::Gradient, {"bowl"}, {{"spacing", 1}}),
        node("slope", SpatialKind::Slope, {"bowl"}, {{"spacing", 1}}),
        node("aspect", SpatialKind::Aspect, {"bowl"}, {{"spacing", 1}}),
        node("position", SpatialKind::Position),
        node("divergence", SpatialKind::Divergence, {"position"}, {{"spacing", 1}}),
        node("radial_curl", SpatialKind::Curl, {"position"}, {{"spacing", 1}}),
        node("negative_y", SpatialKind::Multiply, {"y", "negative_one"}),
        node("rotation", SpatialKind::ComposeVector, {"negative_y", "x"}),
        node("rotational_divergence", SpatialKind::Divergence, {"rotation"}, {{"spacing", 1}}),
        node("rotational_curl", SpatialKind::Curl, {"rotation"}, {{"spacing", 1}})
    };
}

void subnormal_vector_normalization() {
    const double least = std::numeric_limits<double>::denorm_min();
    for (const double y_factor : {-1.0, -2.0}) {
        auto input = constant("input", least, 1, SpatialType::Vector2);
        input.value.y = least * y_factor;
        const auto graph = compile({input, node("unit", SpatialKind::UnitVector, {"input"})});
        const auto actual = sample(*graph, "unit");
        const double divisor = std::sqrt(1 + y_factor * y_factor);
        near(actual.x, 1 / divisor,
             "normalization scales the smallest subnormal axis before dividing by its magnitude", 1e-14);
        near(actual.y, y_factor / divisor,
             "normalization preserves the direction of signed unequal subnormal components", 1e-14);
        near(std::hypot(actual.x, actual.y), 1,
             "nonzero subnormal vectors normalize to unit length despite rounded physical magnitude", 1e-14);
    }
}

void analytic_derivatives() {
    const auto graph = compile(polynomial_nodes());
    for (const auto point : std::array<std::array<std::int64_t, 2>, 7>{{
            {{3, 4}}, {{-3, 4}}, {{3, -4}}, {{-3, -4}}, {{0, 0}}, {{-16, 31}}, {{64, -65}}
        }}) {
        const auto x = point[0], y = point[1];
        const auto gradient = sample(*graph, "gradient", x, y);
        near(gradient.x, static_cast<double>(2 * x), "central x derivative of x²+y² is exactly 2x");
        near(gradient.y, static_cast<double>(2 * y), "central y derivative of x²+y² is exactly 2y");
        near(sample(*graph, "slope", x, y).x, 2 * std::hypot(static_cast<double>(x), static_cast<double>(y)),
             "slope is the magnitude of the scalar gradient");
        if (x != 0 || y != 0)
            near(sample(*graph, "aspect", x, y).x, std::atan2(static_cast<double>(y), static_cast<double>(x)),
                 "aspect retains atan2 quadrant and signed radians");
        near(sample(*graph, "divergence", x, y).x, 2, "divergence of (x,y) is two");
        near(sample(*graph, "radial_curl", x, y).x, 0, "curl of (x,y) is zero");
        near(sample(*graph, "rotational_divergence", x, y).x, 0, "divergence of (-y,x) is zero");
        near(sample(*graph, "rotational_curl", x, y).x, 2, "curl convention is dVy/dx minus dVx/dy");
    }
    require(info(*graph, "gradient").unit_power == 1 && info(*graph, "slope").unit_power == 1,
            "a derivative reduces cell-unit power by one");
    require(info(*graph, "aspect").unit_power == 0 && info(*graph, "divergence").unit_power == 0,
            "angles and derivatives of cell-valued vectors are dimensionless");

    auto wide_nodes = polynomial_nodes();
    for (auto& item : wide_nodes) if (item.parameters.contains("spacing")) item.parameters["spacing"] = 4;
    const auto wide = compile(wide_nodes);
    for (const auto& name : {"gradient", "slope", "aspect", "divergence", "radial_curl", "rotational_curl"}) {
        const auto a = sample(*graph, name, -13, 19), b = sample(*wide, name, -13, 19);
        near(a.x, b.x, "quadratic/linear analytic derivatives are invariant to admitted stencil spacing");
        near(a.y, b.y, "vector derivative y component is invariant to admitted stencil spacing");
    }
    rejects([] { (void)compile({constant("a", 1), node("bad", SpatialKind::Gradient, {"a"}, {{"spacing", 0}})}); },
            "zero derivative spacing rejects before evaluation");
}

void signed_distance_and_transform_conventions() {
    const auto graph = compile({
        node("circle", SpatialKind::CircleDistance, {}, {{"x", 0}, {"y", 0}, {"radius", 5}}),
        node("circle_gradient", SpatialKind::Gradient, {"circle"}, {{"spacing", 1}}),
        node("shifted", SpatialKind::Transform, {"circle"}, {{"tx", 10}, {"ty", -4}}),
        node("uniform", SpatialKind::Transform, {"circle"}, {{"sx", 2}, {"sy", 2}}),
        node("anisotropic", SpatialKind::Transform, {"circle"}, {{"sx", 2}, {"sy", 1}}),
        node("position", SpatialKind::Position),
        node("translated_position", SpatialKind::Transform, {"position"}, {{"tx", 10}, {"ty", -4}}),
        node("rotated_position", SpatialKind::Transform, {"position"}, {{"angle", std::numbers::pi / 2}}),
        node("scaled_position", SpatialKind::Transform, {"position"}, {{"sx", 2}, {"sy", 4}}),
        node("sheared_position", SpatialKind::Transform, {"position"}, {{"shear_x", 2}})
    });
    require(info(*graph, "circle").type == SpatialType::SignedDistance && info(*graph, "circle").unit_power == 1,
            "circle distance is signed distance in cells");
    near(sample(*graph, "circle", 0, 0).x, -5, "circle interior is negative");
    near(sample(*graph, "circle", 3, 4).x, 0, "circle boundary distance is exactly zero");
    near(sample(*graph, "circle", 6, 8).x, 5, "circle exterior is positive Euclidean distance");
    const auto radial = sample(*graph, "circle_gradient", 10, 0);
    near(radial.x, 1, "circle radial derivative points outward");
    near(radial.y, 0, "circle symmetry cancels the tangential derivative");
    near(sample(*graph, "shifted", 10, -4).x, -5, "translation acts on geometry through inverse sampling");
    near(sample(*graph, "shifted", 13, 0).x, 0, "translated circle retains exact distance");
    near(sample(*graph, "uniform", 0, 0).x, -10, "uniform scaling rescales signed-distance magnitude");
    near(sample(*graph, "uniform", 6, 8).x, 0, "uniform scaling rescales the zero set");
    near(sample(*graph, "uniform", 12, 16).x, 10, "uniform scaling retains exterior Euclidean distance");
    require(info(*graph, "uniform").type == SpatialType::SignedDistance,
            "uniform similarity transformations preserve the exact SDF qualification");
    require(info(*graph, "anisotropic").type != SpatialType::SignedDistance ||
                info(*graph, "anisotropic").distance_min_factor != 1 ||
                info(*graph, "anisotropic").distance_max_factor != 1,
            "anisotropic SDF is not advertised as unqualified exact Euclidean distance");
    near(sample(*graph, "anisotropic", 10, 0).x, 0, "anisotropic transformed implicit field preserves ellipse x intercept");
    near(sample(*graph, "anisotropic", 0, 5).x, 0, "anisotropic transformed implicit field preserves ellipse y intercept");
    const auto translated = sample(*graph, "translated_position", 13, 0);
    near(translated.x, 3, "inverse translation of sampling position x"); near(translated.y, 4, "inverse translation of sampling position y");
    const auto rotated = sample(*graph, "rotated_position", 0, 7);
    near(rotated.x, 7, "inverse positive-angle rotation sends world +y to local +x");
    near(rotated.y, 0, "inverse rotation second coordinate");
    const auto scaled = sample(*graph, "scaled_position", 6, 20);
    near(scaled.x, 3, "anisotropic inverse x scale"); near(scaled.y, 5, "anisotropic inverse y scale");
    const auto sheared = sample(*graph, "sheared_position", 11, 4);
    near(sheared.x, 3, "inverse x shear subtracts shear_x times y"); near(sheared.y, 4, "x shear preserves y");
    rejects([] { (void)compile({node("p", SpatialKind::Position), node("bad", SpatialKind::Transform, {"p"}, {{"sx", 0}})}); },
            "zero-scale transform rejects before sampling");
    rejects([] { (void)compile({node("p", SpatialKind::Position), node("bad", SpatialKind::Transform, {"p"}, {{"shear_x", 1}, {"shear_y", 1}})}); },
            "singular shear determinant rejects before sampling");
}

void exact_categorical_and_boolean_values() {
    constexpr SpatialCategory first{INT64_C(9007199254740993), INT64_C(-9007199254740991), UINT64_C(0xfedcba9876543210)};
    auto different = first; ++different.x;
    const auto graph = compile({
        category("first", first), category("same", first), category("different", different),
        node("equal", SpatialKind::Equal, {"first", "same"}),
        node("unequal", SpatialKind::Equal, {"first", "different"}),
        node("mask", SpatialKind::ToMask, {"equal"})
    });
    require(sample(*graph, "first").category == first, "categorical tuple preserves integers beyond double's exact range");
    require(sample(*graph, "equal").type == SpatialType::Boolean && sample(*graph, "equal").x == 1,
            "categorical equality produces exact true");
    require(sample(*graph, "unequal").x == 0, "adjacent large categorical integers remain distinguishable");
    near(sample(*graph, "mask").x, 1, "explicit boolean-to-mask conversion uses exact one");
    rejects([&] { (void)compile({category("a", first), category("b", different), node("bad", SpatialKind::Add, {"a", "b"})}); },
            "category IDs do not participate in arithmetic");
    rejects([&] { (void)compile({category("a", first), node("bad", SpatialKind::ToMask, {"a"}, {{"low", 0}, {"high", 1}})}); },
            "categories cannot silently become normalized numeric masks");
    auto bad = constant("bad", .5, 0, SpatialType::Boolean);
    rejects([&] { (void)compile({bad}); }, "boolean constants reject fractional values");

    auto local = node("local", SpatialKind::CategoryIs, {"first"});
    local.value.type = SpatialType::Category; local.value.category = first; local.value.category.domain = 0;
    auto exact = local; exact.id = "exact"; exact.value.category.domain = first.domain;
    auto wrong_domain = exact; wrong_domain.id = "wrong_domain"; ++wrong_domain.value.category.domain;
    const auto comparison = compile({category("first", first), local, exact, wrong_domain});
    require(sample(*comparison, "local").x == 1 && sample(*comparison, "exact").x == 1,
            "category_is supports an explicit within-input-domain ID selector and exact complete selector");
    require(sample(*comparison, "wrong_domain").x == 0,
            "nonzero category_is domain remains an exact namespace constraint");
}

void polar_logpolar_and_box_geometry() {
    const auto graph = compile({
        node("position", SpatialKind::Position),
        node("polar", SpatialKind::Polar, {"position"}, {{"radial_scale", 2}, {"angular_scale", .5}}),
        node("log", SpatialKind::LogPolar, {"position"}, {{"radial_scale", 2}, {"min_radius", .25}}),
        node("box", SpatialKind::BoxDistance, {}, {{"width", 8}, {"height", 6}})
    });
    const auto polar = sample(*graph, "polar", 6, 8);
    near(polar.x, 5, "polar source radius divides by radial_scale");
    near(polar.y, 2 * std::atan2(8.0, 6.0), "polar source angle divides by angular_scale");
    const auto log = sample(*graph, "log", 6, 8);
    near(log.x, std::log(5.0), "log-polar radius uses natural logarithm after radial scaling");
    near(log.y, std::atan2(8.0, 6.0), "log-polar angle retains signed radians");
    const auto origin = sample(*graph, "log", 0, 0);
    near(origin.x, std::log(.125), "log-polar origin has an explicit minimum-radius clamp");
    near(origin.y, 0, "polar origin angle is explicitly zero");
    near(sample(*graph, "polar", -8, 0).y, 2 * std::numbers::pi,
         "atan2 branch seam has an explicit positive-pi value at negative x and zero y");
    require(sample(*graph, "polar", -8, -1).y < 0,
            "the lower side of the polar seam retains its signed angle");
    near(sample(*graph, "box", 0, 0).x, -3, "box x/y are its center and interior distance is to nearest edge");
    near(sample(*graph, "box", 4, 0).x, 0, "box distance has zero on its geometric boundary");
    near(sample(*graph, "box", 6, 5).x, std::sqrt(8.0), "outside a box corner distance is Euclidean");
}

void derived_geometry_and_bounded_coordinate_maps() {
    auto nodes = polynomial_nodes();
    nodes.push_back(node("inverted_bowl", SpatialKind::Multiply, {"bowl", "negative_one"}));
    nodes.push_back(node("curvature", SpatialKind::Curvature, {"bowl"}, {{"spacing", 1}}));
    nodes.push_back(node("ridge", SpatialKind::Ridge, {"inverted_bowl"}, {{"spacing", 1}}));
    nodes.push_back(node("valley", SpatialKind::Valley, {"bowl"}, {{"spacing", 1}}));
    nodes.push_back(node("not_ridge", SpatialKind::Ridge, {"bowl"}, {{"spacing", 1}}));
    nodes.push_back(node("minimum", SpatialKind::LocalMinimum, {"bowl"}, {{"spacing", 1}}));
    nodes.push_back(node("maximum", SpatialKind::LocalMaximum, {"inverted_bowl"}, {{"spacing", 1}}));
    const auto derivatives = compile(nodes);
    near(sample(*derivatives, "curvature", 3, 4).x, .2,
         "level-set curvature of x²+y² at radius five is 1/5");
    near(sample(*derivatives, "curvature", 0, 0).x, 0,
         "zero-gradient curvature has an explicit finite zero convention");
    require(info(*derivatives, "curvature").unit_power == -1, "level-set curvature has reciprocal-cell units");
    near(sample(*derivatives, "ridge", -9, 11).x, 4, "ridge is the positive negative-Laplacian part");
    near(sample(*derivatives, "valley", -9, 11).x, 4, "valley is the positive Laplacian part");
    near(sample(*derivatives, "not_ridge", -9, 11).x, 0, "positive Laplacian does not become a ridge");
    require(sample(*derivatives, "minimum", 0, 0).type == SpatialType::Boolean &&
                sample(*derivatives, "minimum", 0, 0).x == 1 &&
                sample(*derivatives, "maximum", 0, 0).x == 1,
            "strict four-axis extrema recognize the independent quadratic critical point");
    require(sample(*derivatives, "minimum", 1, 0).x == 0 && sample(*derivatives, "maximum", -1, 0).x == 0,
            "off-center samples cannot pass the extrema witness");
    auto tiny_nodes = polynomial_nodes();
    tiny_nodes.push_back(constant("tiny", 1e-200));
    tiny_nodes.push_back(node("tiny_bowl", SpatialKind::Multiply, {"bowl", "tiny"}));
    tiny_nodes.push_back(node("tiny_curvature", SpatialKind::Curvature, {"tiny_bowl"}, {{"spacing", 1}}));
    const auto tiny = compile(tiny_nodes);
    near(sample(*tiny, "tiny_curvature", 3, 4).x, .2,
         "level-set curvature is invariant to a very small positive scalar multiple without squared-gradient underflow");

    auto vector = node("vector", SpatialKind::Constant); vector.value = value(SpatialType::Vector2, 30, 40); vector.unit_power = 1;
    const auto transforms = compile({
        node("position", SpatialKind::Position), vector,
        node("repeat", SpatialKind::Repeat, {"position"}, {{"period_x", 8}, {"period_y", 4}}),
        node("mirror", SpatialKind::Mirror, {"position"}, {{"period_x", 8}, {"period_y", 4}}),
        node("warp", SpatialKind::Warp, {"position", "vector"}, {{"max_displacement", 5}}),
        node("zero_warp", SpatialKind::Warp, {"position", "vector"}, {{"max_displacement", 0}}),
        node("composite", SpatialKind::Transform, {"position"}, {
            {"tx", 10}, {"ty", -4}, {"origin_x", 1}, {"origin_y", 2},
            {"angle", std::numbers::pi / 2}, {"sx", 2}, {"sy", 3}, {"shear_x", .5}, {"shear_y", -.25}}),
        node("transformed_vector", SpatialKind::TransformVector, {"vector"}, {
            {"tx", 100}, {"ty", -200}, {"origin_x", 7}, {"origin_y", -3},
            {"angle", std::numbers::pi / 2}, {"sx", 2}, {"sy", 4}})
    });
    for (const auto xx : {-17, -16, -9, -8, -1, 0, 1, 7, 8, 9, 16, 17}) {
        const auto r = sample(*transforms, "repeat", xx, -1);
        const auto expected_repeat = ((xx % 8) + 8) % 8;
        near(r.x, expected_repeat, "repeat uses mathematical floor and half-open seams at signed boundaries");
        near(r.y, 3, "repeat y has its independent period");
        const auto m = sample(*transforms, "mirror", xx, -1);
        const auto twice = ((xx % 16) + 16) % 16;
        near(m.x, twice <= 8 ? twice : 16 - twice, "mirror uses a triangular map including its peak boundary");
        near(m.y, 1, "mirror is symmetric around a signed seam");
    }
    const auto warped = sample(*transforms, "warp", -10, 11);
    near(warped.x, -7, "bounded warp radially caps the 30-40 displacement to 3-4");
    near(warped.y, 15, "radial warp cap preserves direction");
    const auto unwarped = sample(*transforms, "zero_warp", -10, 11);
    near(unwarped.x, -10, "zero warp is an exact coordinate no-op");
    near(unwarped.y, 11, "zero warp retains both axes");
    const auto composite = sample(*transforms, "composite", 18, -1);
    near(composite.x, 3, "composite inverse follows origin + T + R*H*S*(local-origin), x");
    near(composite.y, 0, "composite inverse follows origin + T + R*H*S*(local-origin), y");
    const auto transformed_vector = sample(*transforms, "transformed_vector");
    near(transformed_vector.x, -160, "vectors use forward linear transform, with no position translation");
    near(transformed_vector.y, 60, "vector transform respects scale then rotation");
    constexpr double far_origin = -16989048053376.074;
    constexpr double tiny_period = 0.00011242942691270495;
    const auto narrow = compile({node("x", SpatialKind::CoordinateX),
        node("repeated", SpatialKind::Repeat, {"x"}, {{"origin_x", far_origin}, {"period_x", tiny_period}}),
        node("mirrored", SpatialKind::Mirror, {"x"}, {{"origin_x", far_origin}, {"period_x", tiny_period}})});
    for (const auto name : {"repeated", "mirrored"}) {
        const double coordinate = sample(*narrow, name, 0, 0).x;
        require(coordinate >= 0 && coordinate <= tiny_period,
                "tiny periods at large phase origins remain inside the folded local interval instead of cancellation-folding below zero");
    }
}

void coarse_discrete_selection() {
    constexpr SpatialCategory a{INT64_C(9007199254740993), -7, 99}, b{INT64_C(9007199254740994), -7, 99};
    auto selected = node("selected", SpatialKind::Select, {"left", "a", "b"}); selected.sampling_scale = 4;
    auto flag = node("flag", SpatialKind::Identity, {"left"}); flag.sampling_scale = 4;
    const auto graph = compile({
        node("x", SpatialKind::CoordinateX), constant("zero", 0, 1),
        node("left", SpatialKind::Less, {"x", "zero"}), category("a", a), category("b", b), selected, flag
    });
    for (const auto px : {-5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5}) {
        // At -2, anchors are -4 and 0; the exact half tie belongs to -4.
        const bool left = px <= -2;
        const auto actual = sample(*graph, "selected", px, 0);
        require(actual.type == SpatialType::Category && actual.category == (left ? a : b),
                "coarse categorical selection chooses an exact nearest anchor and lower half-tie");
        const auto boolean = sample(*graph, "flag", px, 0);
        require(boolean.type == SpatialType::Boolean && boolean.x == (left ? 1 : 0),
                "coarse boolean fields select exact values without interpolation");
    }
}

SpatialDefinition reusable_definition() {
    SpatialSubgraph source;
    source.id = "offset_source";
    source.parameters.push_back({"offset", SpatialType::Scalar, 1, value(SpatialType::Scalar, 3)});
    auto parameter = node("parameter", SpatialKind::Parameter); parameter.reference = "offset";
    source.nodes = {parameter}; source.outputs = {{"out", "parameter"}};
    SpatialSubgraph wrapper;
    wrapper.id = "wrapper";
    wrapper.parameters.push_back({"outer", SpatialType::Scalar, 1, value(SpatialType::Scalar, 5)});
    SpatialInstance nested; nested.id = "child"; nested.subgraph = "offset_source";
    nested.parameter_bindings = {{"offset", "outer"}};
    wrapper.instances = {nested}; wrapper.outputs = {{"out", "child.out"}};
    SpatialDefinition result;
    result.subgraphs = {source, wrapper};
    SpatialInstance west; west.id = "west"; west.subgraph = "offset_source"; west.bindings = {{"offset", value(SpatialType::Scalar, 8)}};
    SpatialInstance east; east.id = "east"; east.subgraph = "offset_source";
    SpatialInstance nested_instance; nested_instance.id = "wrapped"; nested_instance.subgraph = "wrapper";
    result.instances = {west, east, nested_instance};
    result.nodes = {constant("unrelated", 17), node("sum", SpatialKind::Add, {"west.out", "east.out"})};
    return result;
}

void reusable_graphs_and_precise_cache_invalidation() {
    auto definition = reusable_definition();
    const auto graph = SpatialGraph::compile(definition, 771);
    near(sample(*graph, "west.out").x, 8, "explicit typed instance binding overrides its parameter default");
    near(sample(*graph, "east.out").x, 3, "missing optional binding uses its typed default");
    near(sample(*graph, "wrapped.out").x, 5, "nested instance bindings refer to the enclosing typed parameter");
    near(sample(*graph, "sum").x, 11, "root graph consumes separately namespaced subgraph outputs");
    require(info(*graph, "west.out").unit_power == 1, "subgraph parameter output retains declared units");
    std::reverse(definition.subgraphs.begin(), definition.subgraphs.end());
    std::reverse(definition.instances.begin(), definition.instances.end());
    std::reverse(definition.nodes.begin(), definition.nodes.end());
    require(SpatialGraph::compile(definition, 771)->fingerprint() == graph->fingerprint(),
            "subgraph and instance declaration order cannot alter canonical identity");

    auto changed = reusable_definition();
    changed.instances[0].bindings["offset"] = value(SpatialType::Scalar, -4);
    const auto updated = SpatialGraph::compile(changed, 771);
    require(updated->fingerprint() != graph->fingerprint(), "a bound parameter change changes the graph identity");
    require(info(*updated, "west.out").fingerprint != info(*graph, "west.out").fingerprint &&
                info(*updated, "sum").fingerprint != info(*graph, "sum").fingerprint,
            "parameter changes invalidate the affected output and its transitive consumers");
    require(info(*updated, "east.out").fingerprint == info(*graph, "east.out").fingerprint &&
                info(*updated, "unrelated").fingerprint == info(*graph, "unrelated").fingerprint,
            "unrelated instance and node cache identities survive a local parameter edit");
    SpatialScratch scratch;
    SpatialValues original, cold, warm;
    graph->evaluate(-23, 41, original, &scratch);
    const auto hits = scratch.hits;
    updated->evaluate(-23, 41, warm, &scratch);
    updated->evaluate(-23, 41, cold);
    same(warm, cold, "reusing bounded scratch after a parameter change cannot expose stale values");
    require(scratch.hits > hits, "unchanged transitive node identities can reuse cached work across compilation");
    near(sample(*updated, "sum").x, -1, "edited parameter affects the actual sampled result");
    near(sample(*graph, "sum").x, 11, "compiled graph retains an immutable copy after authoring input mutation");

    auto missing = reusable_definition(); missing.subgraphs[0].parameters[0].default_value.reset();
    rejects([&] { (void)SpatialGraph::compile(missing, 1); }, "missing required instance binding rejects");
    auto wrong = reusable_definition(); wrong.instances[0].bindings["offset"] = value(SpatialType::Boolean, 1);
    rejects([&] { (void)SpatialGraph::compile(wrong, 1); }, "wrong typed instance binding rejects");
    auto unknown = reusable_definition(); unknown.instances[0].bindings["misspelled"] = value(SpatialType::Scalar, 1);
    rejects([&] { (void)SpatialGraph::compile(unknown, 1); }, "unknown binding is not silently ignored");
    auto duplicate = reusable_definition(); duplicate.instances.push_back(duplicate.instances.front());
    rejects([&] { (void)SpatialGraph::compile(duplicate, 1); }, "duplicate instance namespaces reject");
    auto collision = reusable_definition(); collision.nodes.push_back(constant("west", 2));
    rejects([&] { (void)SpatialGraph::compile(collision, 1); }, "node and instance namespace collision rejects");
    auto ambiguous = reusable_definition(); ambiguous.nodes.push_back(constant("west.out", 2));
    rejects([&] { (void)SpatialGraph::compile(ambiguous, 1); }, "authored dotted names cannot collide with generated subgraph output aliases");
    auto unused_invalid = reusable_definition();
    SpatialSubgraph unused; unused.id = "unused"; unused.nodes = {node("bad", SpatialKind::Identity, {"missing"})}; unused.outputs = {{"out", "bad"}};
    unused_invalid.subgraphs.push_back(unused);
    rejects([&] { (void)SpatialGraph::compile(unused_invalid, 1); }, "unused subgraph declarations still validate references");
    auto recursive = reusable_definition();
    SpatialInstance self; self.id = "loop"; self.subgraph = "offset_source";
    recursive.subgraphs[0].instances.push_back(self);
    rejects([&] { (void)SpatialGraph::compile(recursive, 1); }, "recursive instance expansion rejects before allocation grows");
    auto wrong_units = reusable_definition(); wrong_units.subgraphs[1].parameters[0].unit_power = 0;
    rejects([&] { (void)SpatialGraph::compile(wrong_units, 1); }, "nested parameter forwarding rejects matching types with incompatible units");
    auto namespace_output = reusable_definition(); namespace_output.subgraphs[1].outputs = {{"child", "child"}};
    rejects([&] { (void)SpatialGraph::compile(namespace_output, 1); }, "an instance namespace alone is not a valid subgraph field output");
    auto invalid_unused_parameter = reusable_definition();
    SpatialSubgraph unused_parameter; unused_parameter.id = "unused_parameter";
    unused_parameter.parameters.push_back({"bad", static_cast<SpatialType>(255), 0, std::nullopt});
    invalid_unused_parameter.subgraphs.push_back(unused_parameter);
    rejects([&] { (void)SpatialGraph::compile(invalid_unused_parameter, 1); }, "unused unbound parameters still reject an invalid type enum");
    invalid_unused_parameter.subgraphs.back().parameters[0].type = SpatialType::Boolean;
    invalid_unused_parameter.subgraphs.back().parameters[0].unit_power = 1;
    rejects([&] { (void)SpatialGraph::compile(invalid_unused_parameter, 1); }, "unused unbound boolean parameters still reject nonzero units");
    for (unsigned ignored = 0; ignored < 5; ++ignored) {
        auto parameter_override = reusable_definition();
        auto& parameter = parameter_override.subgraphs[0].nodes[0];
        if (ignored == 0) parameter.value = value(SpatialType::Scalar, 1);
        if (ignored == 1) parameter.unit_power = 1;
        if (ignored == 2) parameter.inputs = {"missing"};
        if (ignored == 3) parameter.parameters = {{"ignored", 1}};
        if (ignored == 4) parameter.parameter_bindings = {{"ignored", "offset"}};
        rejects([&] { (void)SpatialGraph::compile(parameter_override, 1); },
                "parameter nodes reject ignored authored values, units, inputs, numeric parameters and bindings");
    }
    SpatialDefinition empty_expansion;
    for (unsigned level = 0; level < 5; ++level) {
        SpatialSubgraph empty; empty.id = "empty" + std::to_string(level);
        if (level != 0) for (unsigned child = 0; child < 8; ++child) {
            SpatialInstance branch; branch.id = "branch" + std::to_string(child); branch.subgraph = "empty" + std::to_string(level - 1);
            empty.instances.push_back(branch);
        }
        empty_expansion.subgraphs.push_back(empty);
    }
    SpatialInstance empty_root; empty_root.id = "root"; empty_root.subgraph = "empty4"; empty_expansion.instances.push_back(empty_root);
    rejects([&] { (void)SpatialGraph::compile(empty_expansion, 1); }, "empty subgraphs still consume the finite expansion ledger and cannot cause unbounded traversal");
}

void numeric_parameter_binding_units() {
    SpatialSubgraph reusable;
    reusable.id = "reusable";
    reusable.parameters = {{"length", SpatialType::Scalar, 1, value(SpatialType::Scalar, 16)},
                           {"turn", SpatialType::Scalar, 0, value(SpatialType::Scalar, 0)}};
    auto noise = node("noise", SpatialKind::Noise); noise.parameter_bindings = {{"scale", "length"}};
    auto mask = node("mask", SpatialKind::ToMask, {"x"}); mask.parameter_bindings = {{"high", "length"}};
    auto rotate = node("rotate", SpatialKind::Transform, {"x"}); rotate.parameter_bindings = {{"angle", "turn"}};
    reusable.nodes = {node("x", SpatialKind::CoordinateX), noise, mask, rotate};
    reusable.outputs = {{"noise_out", "noise"}, {"mask_out", "mask"}, {"rotated", "rotate"}};
    SpatialDefinition definition; definition.subgraphs = {reusable};
    SpatialInstance instance; instance.id = "a"; instance.subgraph = "reusable";
    definition.instances = {instance};
    const auto bound = SpatialGraph::compile(definition, 71);
    near(sample(*bound, "a.mask_out", 8, -4).x, .5,
         "numeric mask threshold binding uses the input field's cell exponent");
    near(sample(*bound, "a.rotated", 8, -4).x, 8,
         "dimensionless angular parameter binds without changing coordinate units");
    auto literal = definition;
    literal.subgraphs[0].nodes[1].parameter_bindings.clear();
    literal.subgraphs[0].nodes[1].parameters = {{"scale", 16}};
    require(sample(*bound, "a.noise_out", -19, 37) ==
                sample(*SpatialGraph::compile(literal, 71), "a.noise_out", -19, 37),
            "length-typed noise scale binding has the same value as the corresponding literal");
    auto wrong_length = definition; wrong_length.subgraphs[0].parameters[0].unit_power = 0;
    rejects([&] { (void)SpatialGraph::compile(wrong_length, 71); },
            "dimensionless numeric binding cannot silently become a cell-unit noise scale or mask threshold");
    auto wrong_angle = definition; wrong_angle.subgraphs[0].parameters[1].unit_power = 1;
    rejects([&] { (void)SpatialGraph::compile(wrong_angle, 71); },
            "cell-unit numeric binding cannot silently become a dimensionless rotation angle");
    auto wrong_mask = definition; wrong_mask.subgraphs[0].nodes[2].parameter_bindings = {{"high", "turn"}};
    wrong_mask.subgraphs[0].parameters[1].default_value = value(SpatialType::Scalar, 16);
    rejects([&] { (void)SpatialGraph::compile(wrong_mask, 71); },
            "numeric mask bounds must match input units even when the bound value is valid");
    wrong_length.instances.clear();
    rejects([&] { (void)SpatialGraph::compile(wrong_length, 71); },
            "unused subgraph validation still checks numeric operator binding units");
}

void canonical_zero_cache_parity() {
    auto negative_vector = constant("vector", -0.0, 0, SpatialType::Vector2);
    negative_vector.value.y = -0.0;
    auto positive_vector = negative_vector; positive_vector.value.x = positive_vector.value.y = 0.0;
    const auto negative = compile({constant("scalar", -0.0), negative_vector});
    const auto positive = compile({constant("scalar", 0.0), positive_vector});
    require(negative->fingerprint() == positive->fingerprint(),
            "signed zeros share one canonical graph and cache identity");
    SpatialScratch scratch;
    for (const auto& graph : {negative, positive, negative}) {
        for (const std::string id : {"scalar", "vector"}) {
            const auto cold = sample(*graph, id, -11, 23);
            const auto warm = sample(*graph, id, -11, 23, &scratch);
            require(std::bit_cast<std::uint64_t>(cold.x) == 0 && std::bit_cast<std::uint64_t>(cold.y) == 0,
                    "authored scalar/vector negative zero returns canonical positive-zero component bits");
            require(std::bit_cast<std::uint64_t>(cold.x) == std::bit_cast<std::uint64_t>(warm.x) &&
                        std::bit_cast<std::uint64_t>(cold.y) == std::bit_cast<std::uint64_t>(warm.y),
                    "cache reuse across signed-zero-equivalent graphs preserves exact component bits");
        }
    }
    require(scratch.hits >= 4, "signed-zero-equivalent recompilations actually reuse cached results");
}

void deterministic_instance_seed_domains() {
    SpatialSubgraph texture;
    texture.id = "texture";
    texture.nodes = {node("value", SpatialKind::Noise, {}, {{"scale", 16}, {"salt", 29}})};
    texture.outputs = {{"out", "value"}};
    SpatialDefinition definition; definition.subgraphs = {texture};
    SpatialInstance left; left.id = "left"; left.subgraph = "texture";
    SpatialInstance right; right.id = "right"; right.subgraph = "texture";
    definition.instances = {left, right};
    const auto graph = SpatialGraph::compile(definition, 719);
    std::reverse(definition.instances.begin(), definition.instances.end());
    const auto reordered = SpatialGraph::compile(definition, 719);
    const auto other_seed = SpatialGraph::compile(definition, 720);
    require(reordered->fingerprint() == graph->fingerprint(), "instance array order does not change seed-domain identity");
    bool distinct_instances = false, distinct_seed = false;
    for (std::int64_t i = 0; i < 20; ++i) {
        const auto x = i * 7 - 63, y = 47 - i * 5;
        const auto a = sample(*graph, "left.out", x, y), b = sample(*graph, "right.out", x, y);
        require(a == sample(*reordered, "left.out", x, y) && b == sample(*reordered, "right.out", x, y),
                "canonical named instances reproduce noise at negative and positive absolute coordinates");
        distinct_instances = distinct_instances || a != b;
        distinct_seed = distinct_seed || a != sample(*other_seed, "left.out", x, y);
    }
    require(distinct_instances, "distinct stable instance paths derive distinct nontrivial seed domains");
    require(distinct_seed, "recipe seed changes affect instantiated noise");
    auto extra = left; extra.id = "third"; definition.instances.push_back(extra);
    const auto extended = SpatialGraph::compile(definition, 719);
    require(info(*graph, "left.out").fingerprint == info(*extended, "left.out").fingerprint &&
                info(*graph, "right.out").fingerprint == info(*extended, "right.out").fingerprint,
            "adding an unrelated named instance preserves existing noise/cache identities");
}

void scale_partition_order_cache_and_allocation() {
    auto x = node("x", SpatialKind::CoordinateX); x.sampling_scale = 64;
    auto y = node("y", SpatialKind::CoordinateY); y.sampling_scale = 16;
    auto noise = node("noise", SpatialKind::Noise, {}, {{"scale", 16}, {"salt", 91}}); noise.sampling_scale = 4;
    const auto graph = compile({x, y, noise,
        node("position", SpatialKind::ComposeVector, {"x", "y"}),
        node("gradient", SpatialKind::Gradient, {"noise"}, {{"spacing", 1}})
    });
    constexpr std::int64_t origin_x = -24, origin_y = -24;
    constexpr std::size_t side = 48;
    std::vector<SpatialValues> expected(side * side);
    for (std::size_t offset = 0; offset < expected.size(); ++offset) {
        const auto px = origin_x + static_cast<std::int64_t>(offset % side);
        const auto py = origin_y + static_cast<std::int64_t>(offset / side);
        graph->evaluate(px, py, expected[offset]);
        near(expected[offset].values[graph->index("x")].x, static_cast<double>(px),
             "world-anchored bilinear interpolation reproduces an affine x field across negative coarse boundaries");
        near(expected[offset].values[graph->index("y")].x, static_cast<double>(py),
             "world-anchored bilinear interpolation reproduces an affine y field across negative coarse boundaries");
    }
    for (const std::size_t chunk : {8, 16, 24, 48}) {
        const auto chunks_per_axis = side / chunk;
        SpatialScratch scratch;
        for (std::size_t index = chunks_per_axis * chunks_per_axis; index-- > 0;) {
            const auto left = (index % chunks_per_axis) * chunk;
            const auto top = (index / chunks_per_axis) * chunk;
            for (std::size_t yy = 0; yy < chunk; ++yy) for (std::size_t xx = 0; xx < chunk; ++xx) {
                const auto offset = (top + yy) * side + left + xx;
                SpatialValues actual;
                graph->evaluate(origin_x + static_cast<std::int64_t>(left + xx),
                                origin_y + static_cast<std::int64_t>(top + yy), actual, &scratch);
                same(actual, expected[offset], "partition size, reversed chunk requests and warm cache cannot change typed values");
            }
        }
    }
    std::array<std::future<void>, 4> workers;
    for (std::size_t worker = 0; worker < workers.size(); ++worker) {
        workers[worker] = std::async(std::launch::async, [&, worker] {
            SpatialScratch scratch;
            for (std::size_t index = worker; index < expected.size(); index += workers.size()) {
                // Multiplication by a number coprime to 2304 permutes the rectangle.
                const auto offset = (index * 947) % expected.size();
                SpatialValues actual;
                graph->evaluate(origin_x + static_cast<std::int64_t>(offset % side),
                                origin_y + static_cast<std::int64_t>(offset / side), actual, &scratch);
                if (actual.size != expected[offset].size || actual.values != expected[offset].values)
                    throw std::runtime_error("four independent worker scratches disagree on randomized absolute-coordinate requests");
            }
        });
    }
    for (auto& worker : workers) worker.get();
    require(true, "four workers preserve the reference rectangle");
    SpatialScratch scratch;
    SpatialValues output;
    graph->evaluate(-17, 9, output, &scratch);
    const auto misses = scratch.misses, hits = scratch.hits;
    graph->evaluate(-17, 9, output, &scratch);
    require(scratch.hits > hits && scratch.misses >= misses, "caller-owned bounded cache records actual reuse");
    typed_allocation_probe::count = 0; typed_allocation_probe::enabled = true;
    try {
        for (std::int64_t i = 0; i < 128; ++i) graph->evaluate(i - 63, 31 - i, output, &scratch);
    } catch (...) { typed_allocation_probe::enabled = false; throw; }
    typed_allocation_probe::enabled = false;
    require(typed_allocation_probe::count == 0, "successful transformed/coarse/derivative evaluation performs no ordinary heap allocation");
}

void validation_bounds_and_transactional_outputs() {
    const auto one = constant("one", 1);
    rejects([&] { (void)compile({one, one}); }, "duplicate nodes reject");
    rejects([] { (void)compile({node("unused", SpatialKind::Identity, {"missing"})}); }, "all declarations are validated, including unused missing references");
    rejects([] { (void)compile({node("a", SpatialKind::Identity, {"b"}), node("b", SpatialKind::Identity, {"a"})}); }, "indirect graph cycles reject");
    rejects([] { (void)compile({node("unused", SpatialKind::Constant, {}, {{"unknown", 1}})}); }, "unknown operator parameters reject");
    rejects([] { (void)compile({node("bad", static_cast<SpatialKind>(255))}); }, "invalid kind declarations reject");
    rejects([&] { (void)compile({one, node("bad", SpatialKind::Add, {"one"})}); }, "wrong arity rejects");
    for (const auto number : {std::numeric_limits<double>::infinity(), -std::numeric_limits<double>::infinity(),
                              std::numeric_limits<double>::quiet_NaN()}) {
        rejects([&] { (void)compile({constant("bad", number)}); }, "nonfinite values reject at compile time");
    }
    for (const auto scale : {0U, 2U, 8U, 65U}) {
        auto bad = one; bad.sampling_scale = scale;
        rejects([&] { (void)compile({bad}); }, "only declared sampling scales are accepted");
    }
    std::vector<SpatialNode> excessive;
    for (std::size_t i = 0; i <= kMaxSpatialNodes; ++i) excessive.push_back(constant("n" + std::to_string(i), 0));
    rejects([&] { (void)compile(excessive); }, "expanded node storage has an enforced capacity");
    const auto graph = compile(polynomial_nodes());
    SpatialLimits exact; exact.max_operations_per_sample = graph->operations_per_sample();
    require(compile(polynomial_nodes(), 17, exact)->operations_per_sample() == exact.max_operations_per_sample,
            "exact conservative declared work budget admits the graph");
    --exact.max_operations_per_sample;
    rejects([&] { (void)compile(polynomial_nodes(), 17, exact); }, "one less than recursive sampling cost refuses compilation");
    require(graph->preparation_bytes() > 0, "compiled graph accounts for owned immutable state");
    SpatialLimits memory; memory.max_preparation_bytes = graph->preparation_bytes() - 1;
    rejects([&] { (void)compile(polynomial_nodes(), 17, memory); }, "insufficient preparation memory refuses compilation");
    auto ordered = polynomial_nodes(); std::reverse(ordered.begin(), ordered.end());
    require(compile(ordered)->fingerprint() == graph->fingerprint(), "canonical graph identity ignores authored node order");

    SpatialValues output; output.size = 37; output.values.fill(value(SpatialType::Scalar, -917));
    const auto sentinel = output;
    for (const auto point : std::array<std::array<std::int64_t, 2>, 4>{{
            {{kFieldCoordinateLimit, 0}}, {{-kFieldCoordinateLimit - 1, 0}},
            {{0, kFieldCoordinateLimit}}, {{0, -kFieldCoordinateLimit - 1}}
        }}) {
        rejects([&] { graph->evaluate(point[0], point[1], output); }, "outside-domain samples reject explicitly");
        same(output, sentinel, "failed sample leaves the complete caller payload unchanged");
    }
    const auto linear = compile({node("x", SpatialKind::CoordinateX),
                                 node("gradient", SpatialKind::Gradient, {"x"}, {{"spacing", 1}})});
    for (const auto px : {-kFieldCoordinateLimit, kFieldCoordinateLimit - 1}) {
        const auto gradient = sample(*linear, "gradient", px, 0);
        near(gradient.x, 1, "absolute-world derivative halo remains correct at admitted coordinate limits");
        near(gradient.y, 0, "coordinate-limit halo has no artificial y component");
    }
}
} // namespace

int main() {
    try {
        signed_values_types_and_units();
        subnormal_vector_normalization();
        analytic_derivatives();
        signed_distance_and_transform_conventions();
        exact_categorical_and_boolean_values();
        polar_logpolar_and_box_geometry();
        derived_geometry_and_bounded_coordinate_maps();
        coarse_discrete_selection();
        reusable_graphs_and_precise_cache_invalidation();
        numeric_parameter_binding_units();
        canonical_zero_cache_parity();
        deterministic_instance_seed_domains();
        scale_partition_order_cache_and_allocation();
        validation_bounds_and_transactional_outputs();
        std::cout << "PASS typed generation fields: " << assertions
                  << " analytical, type/unit, transform/distance, exact-category, partition/cache/worker, allocation and rejection assertions\n";
    } catch (const std::exception& error) {
        typed_allocation_probe::enabled = false;
        std::cerr << "FAIL typed generation fields: " << error.what() << '\n';
        return 1;
    }
}
