#include "cybersand/generation_fields.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdlib>
#include <cstdint>
#include <future>
#include <iostream>
#include <limits>
#include <memory>
#include <new>
#include <set>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace allocation_probe {
thread_local bool enabled = false;
thread_local std::size_t count = 0;
}

// Count ordinary C++ allocation at the public sampling boundary. Compilation,
// futures and assertion diagnostics are deliberately outside the measured block.
#if defined(__GNUC__) || defined(__clang__)
#define GENERATION_TEST_NOINLINE __attribute__((noinline))
#else
#define GENERATION_TEST_NOINLINE
#endif
GENERATION_TEST_NOINLINE void* operator new(std::size_t size) {
    if (allocation_probe::enabled) ++allocation_probe::count;
    if (void* result = std::malloc(size == 0 ? 1 : size)) return result;
    throw std::bad_alloc();
}
GENERATION_TEST_NOINLINE void operator delete(void* pointer) noexcept { std::free(pointer); }
GENERATION_TEST_NOINLINE void operator delete(void* pointer, std::size_t) noexcept {
    ::operator delete(pointer);
}
GENERATION_TEST_NOINLINE void* operator new[](std::size_t size) { return ::operator new(size); }
GENERATION_TEST_NOINLINE void operator delete[](void* pointer) noexcept { ::operator delete(pointer); }
GENERATION_TEST_NOINLINE void operator delete[](void* pointer, std::size_t) noexcept {
    ::operator delete(pointer);
}
#undef GENERATION_TEST_NOINLINE

namespace {
using namespace cybersand::generation;

void require(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}
template<class Action> void rejects(Action&& action, const char* message) {
    bool rejected = false;
    try { action(); } catch (const std::exception&) { rejected = true; }
    require(rejected, message);
}
void near(double actual, double expected, const char* message) {
    require(std::isfinite(actual) && std::abs(actual - expected) <= 1e-12, message);
}
FieldNode node(std::string id, FieldKind kind,
               std::map<std::string, double> parameters = {},
               std::vector<std::string> inputs = {}) {
    FieldNode result;
    result.id = std::move(id); result.kind = kind;
    result.parameters = std::move(parameters); result.inputs = std::move(inputs);
    return result;
}
FieldNode constant(std::string id, double value) {
    return node(std::move(id), FieldKind::Constant, {{"value", value}});
}
double sample(const FieldGraph& graph, const std::string& id, std::int64_t x = 0,
              std::int64_t y = 0, FieldContext context = {}) {
    FieldValues values;
    graph.evaluate(x, y, context, values);
    return values.values.at(graph.index(id));
}

void finite_curve_bijection_and_locality() {
    const std::array<CurvePoint, 4> first_order{{{0, 0}, {0, 1}, {1, 1}, {1, 0}}};
    for (std::uint64_t rank = 0; rank < first_order.size(); ++rank) {
        const auto p = curve_point(FieldKind::Hilbert, 1, rank);
        require(p.x == first_order[rank].x && p.y == first_order[rank].y,
                "Hilbert order-one orientation is an explicit independent fixture");
    }
    for (const auto kind : {FieldKind::Hilbert, FieldKind::Morton}) {
        for (std::uint32_t order = 1; order <= 6; ++order) {
            const auto side = UINT32_C(1) << order;
            const auto count = static_cast<std::uint64_t>(side) * side;
            std::vector<bool> seen(static_cast<std::size_t>(count));
            for (std::uint32_t y = 0; y < side; ++y) {
                for (std::uint32_t x = 0; x < side; ++x) {
                    const auto rank = curve_index(kind, order, x, y);
                    require(rank < count && !seen[rank], "each finite cell has one unique bounded curve rank");
                    seen[rank] = true;
                    const auto inverse = curve_point(kind, order, rank);
                    require(inverse.x == x && inverse.y == y, "curve inverse returns the original cell");
                    if (kind == FieldKind::Morton) {
                        std::uint64_t independent = 0;
                        for (std::uint32_t bit = 0; bit < order; ++bit) {
                            independent |= static_cast<std::uint64_t>((x >> bit) & 1U) << (2 * bit);
                            independent |= static_cast<std::uint64_t>((y >> bit) & 1U) << (2 * bit + 1);
                        }
                        require(rank == independent, "Morton uses x-even/y-odd bit lanes");
                    }
                }
            }
            require(std::all_of(seen.begin(), seen.end(), [](bool v) { return v; }),
                    "finite curve covers its complete square without holes");
            if (kind == FieldKind::Hilbert) {
                for (std::uint64_t rank = 1; rank < count; ++rank) {
                    const auto a = curve_point(kind, order, rank - 1);
                    const auto b = curve_point(kind, order, rank);
                    const auto distance = std::abs(static_cast<std::int64_t>(a.x) - b.x) +
                                          std::abs(static_cast<std::int64_t>(a.y) - b.y);
                    require(distance == 1, "consecutive Hilbert ranks share an edge inside their tile");
                }
            }
        }
        constexpr auto side = UINT32_C(1) << 20;
        constexpr auto count = UINT64_C(1) << 40;
        for (const CurvePoint point : {CurvePoint{0, 0}, CurvePoint{side - 1, 0},
                                      CurvePoint{0, side - 1}, CurvePoint{side - 1, side - 1},
                                      CurvePoint{side / 2, side / 2 - 1}}) {
            const auto rank = curve_index(kind, 20, point.x, point.y);
            const auto decoded = curve_point(kind, 20, rank);
            require(rank < count && decoded.x == point.x && decoded.y == point.y,
                    "maximum order uses wide rank arithmetic without aliasing");
        }
    }
    const auto a = curve_point(FieldKind::Morton, 2, 1);
    const auto b = curve_point(FieldKind::Morton, 2, 2);
    require(std::abs(static_cast<int>(a.x) - static_cast<int>(b.x)) +
                std::abs(static_cast<int>(a.y) - static_cast<int>(b.y)) == 2,
            "Morton has a deliberate nonadjacent control; it is not a connected route");
}

void signed_curve_tiles_and_bounds() {
    for (const auto kind : {FieldKind::Hilbert, FieldKind::Morton}) {
        const auto corner = curve_address(kind, 4, -8, 2, 3, 5, -7);
        require(corner.tile_x == -1 && corner.tile_y == -1 &&
                    corner.local_x == 3 && corner.local_y == 3,
                "negative curve tiles use mathematical floor, not truncation or unsigned wrap");
        const auto origin = curve_address(kind, 5, -7, 2, 3, 5, -7);
        require(origin.tile_x == 0 && origin.tile_y == 0 && origin.local_x == 0 && origin.local_y == 0,
                "authored origin is the lower inclusive tile corner");
        const auto next = curve_address(kind, 17, 5, 2, 3, 5, -7);
        require(next.tile_x == 1 && next.tile_y == 1 && next.local_x == 0 && next.local_y == 0,
                "upper tile boundary belongs exactly to the next tile");
        for (std::int64_t y = -3; y < 0; ++y) for (std::int64_t x = -3; x < 0; ++x) {
            const auto cell = curve_address(kind, 5 + x, -7 + y, 2, 3, 5, -7);
            require(cell.index == corner.index && cell.tile_x == -1 && cell.tile_y == -1,
                    "all positions in a negative coarse curve cell share its rank");
        }
        const auto huge = curve_address(kind, kFieldCoordinateLimit - 1, kFieldCoordinateLimit - 1,
                                        20, 4096, -kFieldCoordinateLimit, -kFieldCoordinateLimit);
        require(huge.tile_x == 511 && huge.tile_y == 511 &&
                    huge.local_x == (UINT32_C(1) << 20) - 1 &&
                    huge.local_y == (UINT32_C(1) << 20) - 1,
                "maximum cell size/order and signed origin difference retain 64-bit arithmetic");
        rejects([&] { (void)curve_index(kind, 0, 0, 0); }, "curve order zero is refused");
        rejects([&] { (void)curve_index(kind, 21, 0, 0); }, "curve order above the supported rank budget is refused");
        rejects([&] { (void)curve_index(kind, 2, 4, 0); }, "curve x is bounded by its finite square");
        rejects([&] { (void)curve_index(kind, 2, 0, 4); }, "curve y is bounded by its finite square");
        rejects([&] { (void)curve_point(kind, 2, 16); }, "curve inverse refuses a rank beyond its square");
        rejects([&] { (void)curve_point(kind, 20, UINT64_MAX); }, "large inverse rank cannot wrap");
        for (const auto size : {INT64_C(-1), INT64_C(0), INT64_C(4097)})
            rejects([&] { (void)curve_address(kind, 0, 0, 3, size); }, "curve cell size is explicitly bounded");
    }
    rejects([] { (void)curve_index(FieldKind::Constant, 2, 0, 0); }, "noncurve kind cannot use curve mapping");
    rejects([] { (void)curve_address(FieldKind::Hilbert, kFieldCoordinateLimit, 0, 2); },
            "out-of-domain curve world position is refused");
}

void analytic_fields_and_sidechains() {
    auto graph = FieldGraph::compile({
        constant("z_quarter", .25), constant("y_three_quarters", .75), constant("one", 1), constant("zero", 0),
        node("a_inverse", FieldKind::Invert, {}, {"z_quarter"}),
        node("b_square", FieldKind::Multiply, {}, {"z_quarter", "z_quarter"}),
        node("sum", FieldKind::Add, {}, {"y_three_quarters", "y_three_quarters"}),
        node("minimum", FieldKind::Minimum, {}, {"z_quarter", "y_three_quarters"}),
        node("maximum", FieldKind::Maximum, {}, {"z_quarter", "y_three_quarters"}),
        node("mix", FieldKind::Mix, {}, {"z_quarter", "y_three_quarters", "z_quarter"}),
        node("mix_zero", FieldKind::Mix, {}, {"z_quarter", "y_three_quarters", "zero"}),
        node("mix_one", FieldKind::Mix, {}, {"z_quarter", "y_three_quarters", "one"}),
        node("remap", FieldKind::Remap, {{"low", 0}, {"high", .5}}, {"z_quarter"}),
        node("smooth", FieldKind::Smoothstep, {{"low", 0}, {"high", 1}}, {"z_quarter"}),
        node("band", FieldKind::Band, {{"low", .25}, {"high", .75}}, {"z_quarter"})
    }, 731);
    near(sample(*graph, "a_inverse"), .75, "inversion has an independent arithmetic oracle");
    near(sample(*graph, "b_square"), .0625, "a repeated input is valid and evaluated as x*x");
    near(sample(*graph, "sum"), 1, "Add saturates to the normalized scalar domain");
    near(sample(*graph, "minimum"), .25, "minimum sidechain");
    near(sample(*graph, "maximum"), .75, "maximum sidechain");
    near(sample(*graph, "mix"), .375, "mix uses the third scalar as its blend weight");
    require(sample(*graph, "mix_zero") == .25 && sample(*graph, "mix_one") == .75,
            "mix retains exact zero/one endpoints");
    near(sample(*graph, "remap"), .5, "remap normalizes the authored interval");
    near(sample(*graph, "smooth"), .15625, "smoothstep follows its cubic analytic definition");
    require(sample(*graph, "band") == 1, "hard band includes its lower endpoint");
    require(graph->index("a_inverse") < graph->index("z_quarter"),
            "public values use canonical IDs independently of dependency execution order");

    const auto tiny = std::numeric_limits<double>::denorm_min();
    const auto narrow_interval = FieldGraph::compile({constant("tiny", 2 * tiny),
        node("remap", FieldKind::Remap, {{"low", 0}, {"high", 4 * tiny}}, {"tiny"})}, 1);
    near(sample(*narrow_interval, "remap"), .5, "valid subnormal normalization interval retains its finite midpoint");
    const auto canonical = FieldGraph::compile(graph->nodes(), 731);
    require(canonical->fingerprint() == graph->fingerprint(),
            "canonical defaults can be recompiled without changing field identity");

    graph = FieldGraph::compile({
        node("circle", FieldKind::Circle, {{"x", -8}, {"y", -4}, {"radius", 4}}),
        node("circle_soft", FieldKind::Circle, {{"x", -8}, {"y", -4}, {"radius", 4}, {"feather", 2}}),
        node("box", FieldKind::Box, {{"x", -8}, {"y", -4}, {"width", 8}, {"height", 8}}),
        node("box_soft", FieldKind::Box, {{"x", -8}, {"y", -4}, {"width", 8}, {"height", 8}, {"feather", 2}}),
        node("outside", FieldKind::Invert, {}, {"circle"}),
        node("cut", FieldKind::Multiply, {}, {"box", "outside"})
    }, 9);
    require(sample(*graph, "circle", -8, -4) == 1 && sample(*graph, "circle", -4, -4) == 0,
            "circle centre is inside and its exact radius is outside");
    near(sample(*graph, "circle_soft", -5, -4), .5, "circle feather has the analytic half-influence witness");
    require(sample(*graph, "box", -8, -4) == 1 && sample(*graph, "box", 0, -4) == 0 &&
                sample(*graph, "box", -8, 4) == 0,
            "hard box lower bounds are inclusive and upper bounds are exclusive");
    near(sample(*graph, "box_soft", -7, 0), .5, "box feather is based on its nearest edge");
    require(sample(*graph, "cut", -8, -4) == 0 && sample(*graph, "cut", -1, 3) == 1,
            "a mask sidechain composes geometry without mutating its source");
}

void context_fields_are_copied_inputs() {
    std::vector<FieldNode> nodes;
    for (const auto* channel : field_context_names()) {
        auto field = node(channel, FieldKind::Context);
        field.context = channel;
        if (field.context == "depth") field.parameters = {{"low", -10}, {"high", 10}};
        nodes.push_back(std::move(field));
    }
    nodes.push_back(node("is_water", FieldKind::Material, {{"material", 3}}));
    const auto graph = FieldGraph::compile(nodes, 1);
    FieldContext context;
    context.occupied = .25; context.solid = .5; context.fluid = .75;
    context.depth = -5; context.slope = .125; context.route = 1; context.material = 3;
    near(sample(*graph, "occupied", 0, 0, context), .25, "occupied context uses the supplied immutable scalar");
    near(sample(*graph, "solid", 0, 0, context), .5, "solid context uses the supplied scalar");
    near(sample(*graph, "fluid", 0, 0, context), .75, "fluid context uses the supplied scalar");
    near(sample(*graph, "depth", 0, 0, context), .25, "signed depth uses explicit low/high normalization");
    near(sample(*graph, "slope", 0, 0, context), .125, "slope context retains fractional input");
    require(sample(*graph, "route", 0, 0, context) == 1 && sample(*graph, "is_water", 0, 0, context) == 1,
            "route and material predicates retain exact binary endpoints");
    context.material = 2;
    require(sample(*graph, "is_water", 0, 0, context) == 0, "material predicate distinguishes valid existing IDs");
}

std::vector<FieldNode> noise_nodes() {
    return {
        node("value", FieldKind::ValueNoise), node("gradient", FieldKind::GradientNoise),
        node("fbm", FieldKind::Fbm, {{"octaves", 1}}),
        node("ridged", FieldKind::Ridged, {{"octaves", 1}}),
        node("cellular", FieldKind::CellularDistance), node("gap", FieldKind::CellularGap),
        node("hilbert", FieldKind::Hilbert, {{"order", 4}, {"cell_size", 3}}),
        node("morton", FieldKind::Morton, {{"order", 4}, {"cell_size", 3}})
    };
}

void reproducibility_warp_and_purity() {
    auto nodes = noise_nodes();
    const auto graph = FieldGraph::compile(nodes, UINT64_C(0x631834fe041926b7));
    std::reverse(nodes.begin(), nodes.end());
    const auto reordered = FieldGraph::compile(nodes, UINT64_C(0x631834fe041926b7));
    require(graph->fingerprint() == reordered->fingerprint(), "manifest insertion order cannot change compiled field identity");
    const auto changed_seed = FieldGraph::compile(nodes, 12345);
    std::array<std::set<double>, 8> observed;
    bool changed = false;
    for (std::int64_t y = -64; y < 64; y += 13) for (std::int64_t x = -64; x < 64; x += 11) {
        FieldValues first, second, other;
        graph->evaluate(x, y, {}, first); reordered->evaluate(x, y, {}, second);
        changed_seed->evaluate(x, y, {}, other);
        require(first.size == 8 && first.size == second.size && first.values == second.values,
                "absolute-coordinate fields are deterministic under fresh compilation and reordered declarations");
        changed = changed || first.values != other.values;
        for (std::size_t i = 0; i < first.size; ++i) {
            require(std::isfinite(first.values[i]) && first.values[i] >= 0 && first.values[i] <= 1,
                    "every noise/curve output is finite and normalized");
            observed[i].insert(first.values[i]);
        }
        for (std::size_t i = first.size; i < first.values.size(); ++i)
            require(first.values[i] == 0, "unused public field slots are zeroed");
    }
    require(changed, "a seed change must affect a nontrivial noise fixture");
    for (const auto& values : observed) require(values.size() > 4, "each structured field varies over the independent sample grid");

    const auto octave_control = FieldGraph::compile({
        node("gradient", FieldKind::GradientNoise, {{"scale", 64}}),
        node("one_octave", FieldKind::Fbm, {{"scale", 64}, {"octaves", 1}}),
        node("full_fbm", FieldKind::Fbm), node("full_ridged", FieldKind::Ridged)
    }, 417);
    for (const auto x : {INT64_C(-47), INT64_C(-1), INT64_C(0), INT64_C(17)}) {
        FieldValues values;
        octave_control->evaluate(x, 23, {}, values);
        require(values.values[octave_control->index("gradient")] == values.values[octave_control->index("one_octave")],
                "one-octave fBm equals its gradient primitive at the same scale and salt");
    }

    auto plain = node("terrain", FieldKind::ValueNoise, {{"scale", 32}, {"warp", 8}});
    auto warped = plain; warped.warp_x = "drive";
    auto drive = node("drive", FieldKind::Circle, {{"radius", 1}});
    const auto base = FieldGraph::compile({plain, drive}, 391);
    const auto shifted = FieldGraph::compile({warped, drive}, 391);
    require(sample(*shifted, "terrain", 0, 0) == sample(*base, "terrain", 8, 0),
            "warp consumes displacement sampled at the original coordinate, without recursive feedback");
    require(sample(*shifted, "terrain", 5, 0) == sample(*base, "terrain", -3, 0),
            "zero displacement-field value means negative authored amplitude");
    warped.parameters["warp"] = 0;
    const auto disabled = FieldGraph::compile({warped, drive}, 391);
    for (const auto x : {INT64_C(-47), INT64_C(-1), INT64_C(0), INT64_C(17)})
        require(sample(*disabled, "terrain", x, 9) == sample(*base, "terrain", x, 9),
                "zero warp is exactly the unwarped primitive");

    std::array<FieldValues, 32> expected;
    for (std::size_t i = 0; i < expected.size(); ++i)
        graph->evaluate(static_cast<std::int64_t>(i) - 17, static_cast<std::int64_t>(i * 3) - 49, {}, expected[i]);
    auto evaluate_concurrently = [graph, expected] {
        for (std::size_t i = expected.size(); i-- > 0;) {
            FieldValues actual;
            graph->evaluate(static_cast<std::int64_t>(i) - 17, static_cast<std::int64_t>(i * 3) - 49, {}, actual);
            require(actual.size == expected[i].size && actual.values == expected[i].values,
                    "shared const field graph has no mutable evaluation scratch or random stream");
        }
    };
    auto first = std::async(std::launch::async, evaluate_concurrently);
    auto second = std::async(std::launch::async, evaluate_concurrently);
    first.get(); second.get();
    FieldValues scratch;
    allocation_probe::count = 0; allocation_probe::enabled = true;
    try {
        for (std::int64_t i = 0; i < 64; ++i) graph->evaluate(i - 31, i * 7 - 63, {}, scratch);
    } catch (...) { allocation_probe::enabled = false; throw; }
    allocation_probe::enabled = false;
    require(allocation_probe::count == 0, "successful field evaluation performs no ordinary C++ allocation");
}

void invalid_graphs_and_atomic_output() {
    const auto good = constant("source", .25);
    rejects([&] { (void)FieldGraph::compile({good, good}, 1); }, "duplicate field IDs reject before evaluation");
    rejects([] { (void)FieldGraph::compile({constant("bad id", .2)}, 1); }, "invalid field identifier rejects");
    rejects([] { (void)FieldGraph::compile({node("unknown", static_cast<FieldKind>(255))}, 1); }, "unknown field kind rejects");
    rejects([] { (void)FieldGraph::compile({node("dead", FieldKind::Invert, {}, {"missing"})}, 1); }, "unused node with missing dependency still rejects");
    rejects([] { (void)FieldGraph::compile({node("self", FieldKind::Invert, {}, {"self"})}, 1); }, "self sidechain rejects");
    rejects([] { (void)FieldGraph::compile({node("a", FieldKind::Invert, {}, {"b"}), node("b", FieldKind::Invert, {}, {"a"})}, 1); }, "indirect sidechain cycle rejects");
    auto warp = node("warp", FieldKind::ValueNoise); warp.warp_x = "warp";
    rejects([&] { (void)FieldGraph::compile({warp}, 1); }, "warp dependency participates in cycle detection");
    warp.warp_x = "missing";
    rejects([&] { (void)FieldGraph::compile({warp}, 1); }, "missing warp field rejects");
    auto unsupported = good; unsupported.warp_x = "source";
    rejects([&] { (void)FieldGraph::compile({unsupported}, 1); }, "warp is restricted to declared primitives");
    for (const auto kind : {FieldKind::Invert, FieldKind::Multiply, FieldKind::Mix})
        rejects([&] { (void)FieldGraph::compile({good, node("wrong_arity", kind, {}, {"source", "source", "source", "source"})}, 1); }, "operator arity cannot be guessed or truncated");
    for (const double value : {-1.0, 1.01, std::numeric_limits<double>::infinity(), std::numeric_limits<double>::quiet_NaN()})
        rejects([&] { (void)FieldGraph::compile({constant("bad", value)}, 1); }, "constant validates finite normalized input");
    rejects([] { (void)FieldGraph::compile({node("bad", FieldKind::Circle, {{"unknown", 1}})}, 1); }, "unknown parameter cannot be silently ignored");
    rejects([] { (void)FieldGraph::compile({node("bad", FieldKind::Circle, {{"radius", 2}, {"feather", 3}})}, 1); }, "circle feather must fit radius");
    rejects([] { (void)FieldGraph::compile({node("bad", FieldKind::Box, {{"width", 4}, {"height", 8}, {"feather", 3}})}, 1); }, "box feather must fit both dimensions");
    rejects([&] { (void)FieldGraph::compile({good, node("bad", FieldKind::Remap, {{"low", .5}, {"high", .5}}, {"source"})}, 1); }, "remap rejects zero interval");
    rejects([&] { (void)FieldGraph::compile({good, node("bad", FieldKind::Band, {{"low", .2}, {"high", .4}, {"feather", .2}}, {"source"})}, 1); }, "band feather must fit its interval");
    for (const auto order : {0.0, 1.5, 21.0})
        rejects([&] { (void)FieldGraph::compile({node("bad", FieldKind::Hilbert, {{"order", order}})}, 1); }, "curve field order is finite integer and bounded");
    for (const auto octaves : {0.0, 2.5, 7.0})
        rejects([&] { (void)FieldGraph::compile({node("bad", FieldKind::Fbm, {{"octaves", octaves}})}, 1); }, "fractal iteration count is bounded and integral");
    rejects([] { (void)FieldGraph::compile({node("bad", FieldKind::Material, {{"material", 10}})}, 1); }, "unused historical material ID is invalid");
    rejects([] { (void)FieldGraph::compile({node("a", FieldKind::CellularDistance), node("b", FieldKind::CellularGap),
                                          node("c", FieldKind::CellularDistance)}, 1); },
            "a small declaration count can still exceed the conservative field work bound");
    auto context = node("bad", FieldKind::Context); context.context = "live_world";
    rejects([&] { (void)FieldGraph::compile({context}, 1); }, "context cannot request unowned live state");

    std::vector<FieldNode> many;
    for (std::size_t i = 0; i <= kMaxFieldNodes; ++i) many.push_back(constant("node" + std::to_string(i), 0));
    rejects([&] { (void)FieldGraph::compile(many, 1); }, "field count cannot exceed fixed scratch storage");
    std::vector<FieldNode> chain{constant("node0", .25)};
    for (std::size_t i = 1; i <= kMaxFieldDepth; ++i)
        chain.push_back(node("node" + std::to_string(i), FieldKind::Invert, {}, {"node" + std::to_string(i - 1)}));
    rejects([&] { (void)FieldGraph::compile(chain, 1); }, "sidechain depth cannot exceed the compiled bound");
    auto graph = FieldGraph::compile({good, node("inverse", FieldKind::Invert, {}, {"source"})}, 1);
    FieldLimits exact; exact.max_operations_per_sample = graph->operations_per_sample();
    require(FieldGraph::compile(graph->nodes(), 1, exact)->operations_per_sample() == exact.max_operations_per_sample,
            "exact declared operation budget admits the graph");
    --exact.max_operations_per_sample;
    rejects([&] { (void)FieldGraph::compile(graph->nodes(), 1, exact); }, "one less operation than declared refuses compilation");
    rejects([&] { (void)graph->index("missing"); }, "unknown diagnostic field ID refuses lookup");

    FieldValues output; output.size = 31; output.values.fill(.375);
    const auto before = output;
    auto failed_sample = [&](std::int64_t x, std::int64_t y, FieldContext c) {
        rejects([&] { graph->evaluate(x, y, c, output); }, "invalid sampling input must reject");
        require(output.size == before.size && output.values == before.values,
                "failed evaluation leaves caller-owned output completely unchanged");
    };
    failed_sample(kFieldCoordinateLimit, 0, {});
    failed_sample(-kFieldCoordinateLimit - 1, 0, {});
    failed_sample(0, kFieldCoordinateLimit, {});
    FieldContext bad; bad.occupied = -0.01; failed_sample(0, 0, bad);
    bad = {}; bad.route = 1.01; failed_sample(0, 0, bad);
    bad = {}; bad.depth = std::numeric_limits<double>::infinity(); failed_sample(0, 0, bad);
    bad = {}; bad.slope = -1; failed_sample(0, 0, bad);
    bad = {}; bad.solid = std::numeric_limits<double>::quiet_NaN(); failed_sample(0, 0, bad);
    graph->evaluate(-kFieldCoordinateLimit, kFieldCoordinateLimit - 1, {}, output);
    require(output.size == 2, "supported coordinate extremes remain valid");
}
} // namespace

int main() {
    try {
        finite_curve_bijection_and_locality();
        signed_curve_tiles_and_bounds();
        analytic_fields_and_sidechains();
        context_fields_are_copied_inputs();
        reproducibility_warp_and_purity();
        invalid_graphs_and_atomic_output();
        std::cout << "PASS generation fields: finite curve bijection/locality, signed tiles, analytic masks/sidechains, "
                     "structured noise/warp, immutable context, canonical identity, concurrent purity, allocation and rejection bounds\n";
    } catch (const std::exception& error) {
        allocation_probe::enabled = false;
        std::cerr << "FAIL generation fields: " << error.what() << '\n';
        return 1;
    }
}
