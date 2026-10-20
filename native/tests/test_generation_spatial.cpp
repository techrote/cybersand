#include "cybersand/generation_spatial.hpp"
#include "cybersand/generation_numeric.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <bit>
#include <cmath>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <new>
#include <random>
#include <set>
#include <stdexcept>
#include <thread>
#include <vector>

namespace allocation_probe {
thread_local bool enabled = false;
thread_local std::size_t count = 0;
}
void* operator new(std::size_t size) {
    if (allocation_probe::enabled) ++allocation_probe::count;
    if (auto* pointer = std::malloc(size == 0 ? 1 : size)) return pointer;
    throw std::bad_alloc();
}
void operator delete(void* pointer) noexcept { std::free(pointer); }
void operator delete(void* pointer, std::size_t) noexcept { std::free(pointer); }
void* operator new[](std::size_t size) { return ::operator new(size); }
void operator delete[](void* pointer) noexcept { std::free(pointer); }
void operator delete[](void* pointer, std::size_t) noexcept { std::free(pointer); }

namespace {
using namespace cybersand::generation::spatial;
void require(bool ok, const char* reason) { if (!ok) throw std::runtime_error(reason); }
void near(double actual, double expected, double tolerance, const char* reason) {
    if (std::abs(actual - expected) > tolerance) {
        std::cerr << reason << ": actual=" << actual << " expected=" << expected << '\n';
        throw std::runtime_error(reason);
    }
}
template <class Exception = std::invalid_argument, class Function>
void rejects(Function&& fn, const char* reason) {
    try { fn(); } catch (const Exception&) { return; }
    throw std::runtime_error(reason);
}

void bounded_finite_magnitude() {
    using cybersand::generation::detail::magnitude;
    const auto subnormal = std::numeric_limits<double>::denorm_min();
    const auto normal = std::numeric_limits<double>::min();
    const std::array<Point, 18> cases{{
        {0, 0}, {-0.0, -0.0}, {3, 4}, {-3, 4}, {1e100, 1e100}, {3e99, -4e99},
        {1e-200, 1e-200}, {3e-200, 4e-200}, {1e100, 1e-200}, {1e-200, 0},
        {subnormal, 0}, {0, -subnormal}, {subnormal, subnormal},
        {3 * subnormal, 4 * subnormal}, {normal, subnormal}, {normal, normal},
        {std::nextafter(normal, 0.0), subnormal}, {0x1.0p-1023, 0x1.0p-1023},
    }};
    const auto check_reference = [&](double x, double y) {
        const auto actual = magnitude(x, y), expected = std::hypot(x, y);
        require(std::isfinite(actual) && actual >= 0 && !std::signbit(actual),
                "bounded magnitude is finite, nonnegative, and canonicalizes zero");
        require(expected == 0 || actual > 0, "nonzero tiny vectors retain a nonzero magnitude");
        const auto a = std::bit_cast<std::uint64_t>(actual);
        const auto e = std::bit_cast<std::uint64_t>(expected);
        require((a > e ? a - e : e - a) <= 4,
                "scaled magnitude agrees with independent std::hypot within four representable steps");
        require(actual == magnitude(y, x) && actual == magnitude(-x, -y),
                "magnitude is symmetric in axes and signs");
    };
    for (const auto point : cases) check_reference(point.x, point.y);
    for (int exponent = -1074; exponent <= 328; exponent += 47) {
        const auto scale = std::ldexp(1.0, exponent);
        check_reference(3 * scale, 4 * scale);
        require(magnitude(-scale, 0) == scale && magnitude(0, -scale) == scale,
                "axis magnitude retains exact finite and subnormal values");
    }
    require(magnitude(3, 4) == 5 && magnitude(3 * subnormal, 4 * subnormal) == 5 * subnormal,
            "analytic 3-4-5 triangles remain exact at ordinary and subnormal scales");
}

void peano_inverses_and_locality() {
    constexpr std::array<PeanoPoint, 9> base{{{0,0},{0,1},{0,2},{1,2},{1,1},{1,0},{2,0},{2,1},{2,2}}};
    for (std::uint32_t i = 0; i < 9; ++i) {
        const auto p = peano_point(1, i);
        require(p.x == base[i].x && p.y == base[i].y, "Peano base orientation is documented");
    }
    for (std::uint32_t order = 1; order <= 5; ++order) {
        const auto side = peano_side(order);
        std::vector<bool> seen(static_cast<std::size_t>(side) * side);
        PeanoPoint previous;
        for (std::uint64_t i = 0; i < static_cast<std::uint64_t>(side) * side; ++i) {
            const auto p = peano_point(order, i);
            require(p.x < side && p.y < side, "Peano point stays inside declared tile");
            const auto linear = static_cast<std::size_t>(p.y) * side + p.x;
            require(!seen[linear], "finite Peano traversal visits each cell only once");
            seen[linear] = true;
            require(peano_index(order, p.x, p.y) == i, "independent Peano inverse retains every rank");
            if (i != 0) {
                const auto distance = std::abs(static_cast<int>(p.x) - static_cast<int>(previous.x)) +
                    std::abs(static_cast<int>(p.y) - static_cast<int>(previous.y));
                require(distance == 1, "consecutive Peano cells share an edge including recursive seams");
            }
            previous = p;
        }
        require(std::all_of(seen.begin(), seen.end(), [](bool v) { return v; }), "Peano exhausts finite tile");
    }
    for (const auto xy : {Point{-0.25, -36.0}, Point{-36.0, 35.999}, Point{36, 36}}) {
        const auto a = peano_address(xy.x, xy.y, 2, 4);
        const auto recovered_x = (a.tile_x * 9 + a.local_x) * 4;
        const auto recovered_y = (a.tile_y * 9 + a.local_y) * 4;
        require(recovered_x == static_cast<std::int64_t>(std::floor(xy.x / 4) * 4) &&
                recovered_y == static_cast<std::int64_t>(std::floor(xy.y / 4) * 4), "signed Peano cell ownership uses floor");
    }
    const auto maximum = peano_side(kMaxPeanoOrder);
    const auto last = peano_point(kMaxPeanoOrder, static_cast<std::uint64_t>(maximum) * maximum - 1);
    require(last.x == maximum - 1 && last.y == maximum - 1, "maximum order does not overflow rank/address");
    rejects([] { (void)peano_side(0); }, "zero Peano order rejects");
    rejects([] { (void)peano_side(13); }, "excessive Peano order rejects");
    rejects([] { (void)peano_point(1, 9); }, "rank past tile rejects");
    rejects([] { (void)peano_index(1, 3, 0); }, "coordinate past tile rejects");
    rejects([] { (void)peano_address(0, 0, 1, 0); }, "zero Peano cell size rejects");
    rejects([] { (void)peano_address(kSampleCoordinateLimit, 0, 1); }, "sample coordinate ceiling is exclusive");
}

void voronoi_analytic_and_large_neighborhood_oracle() {
    LatticeSpec grid; grid.spacing = 8; grid.jitter = 0;
    validate(grid);
    auto seed = nearest_seed_unchecked(grid, {4,4});
    require(seed.id == RegionId{0,0} && seed.distance == 0, "regular-grid seed identity/position are exact");
    near(voronoi_boundary_unchecked(grid, {4,4}), 4, 0, "grid cell center has exact 4-cell boundary distance");
    seed = nearest_seed_unchecked(grid, {8,4});
    require(seed.id == RegionId{0,0}, "Voronoi equal-distance tie selects lexicographically smaller signed ID");
    near(voronoi_boundary_unchecked(grid, {8,4}), 0, 0, "categorical boundary has zero Euclidean distance");
    seed = nearest_seed_unchecked(grid, {-8,-4});
    require(seed.id == RegionId{-2,-1}, "negative Voronoi tie is signed and world anchored");
    near(voronoi_boundary_unchecked(grid, {-8,-4}), 0, 0, "negative boundary exact");
    seed = nearest_seed_unchecked(grid, {kSampleCoordinateLimit - 1, -kSampleCoordinateLimit});
    require(std::isfinite(seed.distance), "extended internal coordinate limit remains finite");
    near(voronoi_boundary_unchecked(grid, {kSampleCoordinateLimit - 1, -kSampleCoordinateLimit}), 0, 0,
         "large exact grid boundary is stable without world squared-distance cancellation");

    LatticeSpec jittered{123456789, 987654321, 13, 1};
    validate(jittered);
    for (int iy = -9; iy <= 9; ++iy) for (int ix = -9; ix <= 9; ++ix) {
        const Point query{static_cast<double>(ix) * 7.3125 + .125, static_cast<double>(iy) * 11.15625 + .75};
        const auto observed = nearest_seed_unchecked(jittered, query);
        const auto bx = static_cast<std::int64_t>(std::floor(query.x / jittered.spacing));
        const auto by = static_cast<std::int64_t>(std::floor(query.y / jittered.spacing));
        double best = std::numeric_limits<double>::infinity(); RegionId best_id{}; Point best_point{};
        // Independent broad exhaustive search; no query uses the implementation's
        // 5x5 seed or 7x7 face neighborhood as the reference.
        for (std::int64_t y = by - 12; y <= by + 12; ++y) for (std::int64_t x = bx - 12; x <= bx + 12; ++x) {
            const RegionId id{x,y}; const auto point = lattice_seed_unchecked(jittered, id);
            require(static_cast<std::int64_t>(std::floor(point.x / jittered.spacing)) == x &&
                    static_cast<std::int64_t>(std::floor(point.y / jittered.spacing)) == y, "seed belongs to exactly its declared tile");
            const auto distance = std::hypot(point.x - query.x, point.y - query.y);
            if (distance < best || (distance == best && id < best_id)) { best = distance; best_id = id; best_point = point; }
        }
        require(observed.id == best_id, "bounded nearest seed matches broad independent oracle");
        near(observed.distance, best, 1e-12, "nearest Euclidean distance matches broad independent oracle");
        double edge = std::numeric_limits<double>::infinity();
        for (std::int64_t y = by - 12; y <= by + 12; ++y) for (std::int64_t x = bx - 12; x <= bx + 12; ++x) {
            if (RegionId{x,y} == best_id) continue;
            const auto point = lattice_seed_unchecked(jittered, {x,y});
            const auto qx = point.x - query.x, qy = point.y - query.y;
            const auto length = std::hypot(point.x - best_point.x, point.y - best_point.y);
            edge = std::min(edge, (qx*qx + qy*qy - best*best) / (2 * length));
        }
        near(voronoi_boundary_unchecked(jittered, query), edge, 2e-12,
             "bounded exact face distance matches broad bisector-plane oracle");
    }
}

void delaunay_dual_structure() {
    LatticeSpec grid; grid.spacing = 8; grid.jitter = 0;
    const auto graph = delaunay_unchecked(grid, {4,4});
    require(graph.owner.id == RegionId{0,0} && graph.size == 4, "co-circular grid has four positive-length Voronoi-face neighbors");
    const std::set<RegionId> expected{{-1,0},{0,-1},{0,1},{1,0}};
    require(std::set<RegionId>(graph.neighbors.begin(), graph.neighbors.begin() + static_cast<std::ptrdiff_t>(graph.size)) == expected,
            "Delaunay dual omits zero-length diagonal faces deterministically");
    near(graph.incident_distance, 0, 0, "incident structure passes through its seed");
    near(delaunay_unchecked(grid, {6,6}).incident_distance, 2, 1e-14, "distance is to actual incident seed segments");
    LatticeSpec jittered{31,92,8,0.8};
    for (std::int64_t y = -3; y <= 3; ++y) for (std::int64_t x = -3; x <= 3; ++x) {
        const RegionId id{x,y};
        const auto current = delaunay_unchecked(jittered, lattice_seed_unchecked(jittered, id));
        require(current.owner.id == id && current.size >= 3 && current.size <= 48, "bounded planar cell has a finite enclosing dual");
        for (std::size_t i = 0; i < current.size; ++i) {
            const auto reverse = delaunay_unchecked(jittered, current.positions[i]);
            require(reverse.owner.id == current.neighbors[i], "neighbor geometry resolves back to exact identity");
            require(std::find(reverse.neighbors.begin(), reverse.neighbors.begin() + static_cast<std::ptrdiff_t>(reverse.size), id) !=
                    reverse.neighbors.begin() + static_cast<std::ptrdiff_t>(reverse.size), "positive Voronoi faces produce reciprocal Delaunay adjacency");
        }
    }
}

void poisson_spacing_ownership_and_truncated_distance() {
    PoissonSpec spec; spec.lattice = {47, 19, 16, 1}; spec.radius = 24; spec.search_cells = 3;
    validate(spec);
    std::vector<std::pair<RegionId, Point>> accepted;
    for (std::int64_t y = -16; y <= 16; ++y) for (std::int64_t x = -16; x <= 16; ++x)
        if (poisson_seed_accepted_unchecked(spec, {x,y})) accepted.push_back({{x,y}, lattice_seed_unchecked(spec.lattice, {x,y})});
    require(accepted.size() > 60 && accepted.size() < 700, "priority rejection produces nontrivial deterministic feature selection");
    for (std::size_t i = 0; i < accepted.size(); ++i) for (std::size_t j = 0; j < i; ++j)
        require(std::hypot(accepted[i].second.x - accepted[j].second.x, accepted[i].second.y - accepted[j].second.y) >= spec.radius - 1e-12,
                "all independently enumerated accepted seeds meet global hard separation");
    for (int y = -48; y <= 48; y += 3) for (int x = -48; x <= 48; x += 5) {
        const Point query{static_cast<double>(x) + .125, static_cast<double>(y) + .375};
        const auto observed = poisson_unchecked(spec, query);
        auto expected = spec.lattice.spacing * spec.search_cells; RegionId id{}; bool found = false;
        for (const auto& [candidate_id, position] : accepted) {
            const auto distance = std::hypot(query.x - position.x, query.y - position.y);
            if (distance < expected || (found && distance == expected && candidate_id < id)) {
                expected = distance; id = candidate_id; found = true;
            }
        }
        near(observed.distance, expected, 2e-13, "bounded Poisson distance matches independently selected wide feature set");
        require(observed.found == found && (!found || observed.nearest.id == id), "Poisson feature identity remains exact across chunk-like seams");
    }
    spec.radius = 32; spec.search_cells = 1;
    bool witnessed_missing = false;
    for (int y = -40; y < 40 && !witnessed_missing; ++y) for (int x = -40; x < 40; ++x) {
        const auto sample = poisson_unchecked(spec, {static_cast<double>(x), static_cast<double>(y)});
        if (!sample.found) { require(sample.distance == 16, "no local feature returns explicit bounded cap"); witnessed_missing = true; break; }
    }
    require(witnessed_missing, "fixture exercises explicit absent-feature result rather than inventing a seed");
    require(poisson_work_bound(spec) > kNearestSeedWork, "nested rejection fan-out is charged");
}

void geometry_distance_and_identity() {
    Geometry route{"route", {{-10,0},{10,0},{10,10}}, false};
    const auto prepared = PreparedGeometry::compile(route);
    near(prepared->distance({0,3}), 3, 0, "route distance uses nearest segment interior");
    near(prepared->distance({13,14}), 5, 0, "route distance includes endpoint caps");
    const auto copy = PreparedGeometry::compile(prepared->geometry());
    require(copy->fingerprint() == prepared->fingerprint(), "immutable route input roundtrips canonically");
    route.points[1].y = 2;
    require(PreparedGeometry::compile(route)->fingerprint() != prepared->fingerprint(), "geometry changes invalidate identity");
    near(prepared->distance({0,3}), 3, 0, "compiled route does not observe subsequent input mutation");
    const auto boundary = PreparedGeometry::compile({"district", {{0,0},{8,0},{8,8},{0,8}}, true});
    near(boundary->distance({4,4}), 4, 0, "closed boundary distance measures inner region to boundary");
    near(boundary->distance({-3,4}), 3, 0, "closing segment participates in declared boundary");
    near(PreparedGeometry::compile({"point", {{1,2}}, false})->distance({4,6}), 5, 0, "single feature point has analytic distance");
    rejects([] { (void)PreparedGeometry::compile({"empty", {}, false}); }, "empty geometry rejects");
    rejects([] { (void)PreparedGeometry::compile({"closed", {{0,0},{1,0}}, true}); }, "invalid closed boundary rejects");
    rejects([] { (void)PreparedGeometry::compile({"nan", {{0,std::numeric_limits<double>::quiet_NaN()}}, false}); }, "nonfinite geometry rejects");
    auto oversized = route; oversized.points.resize(kMaxGeometryPoints + 1);
    rejects([&] { (void)PreparedGeometry::compile(oversized); }, "excessive geometry neighborhood refuses compilation");
}

RegionAssignment checkerboard(std::uint32_t width, std::uint32_t height, bool wrap) {
    RegionAssignment def; def.width = width; def.height = height; def.cell_size = 4;
    def.seed = 814; def.categories = {UINT64_C(0xf123456789abcdef), UINT64_C(0xfedcba9876543210)};
    def.wrap_x = wrap; def.wrap_y = wrap;
    for (auto& direction : def.adjacency) { direction[0] = 2; direction[1] = 1; }
    return def;
}
void bounded_region_solver() {
    auto def = checkerboard(4,4,true); def.domains.assign(16, 3); def.domains[0] = 1;
    const auto prepared = PreparedRegions::compile(def);
    for (std::uint32_t y = 0; y < 4; ++y) for (std::uint32_t x = 0; x < 4; ++x)
        require(prepared->cells()[y * 4 + x] == def.categories[(x + y) % 2], "bounded region propagation satisfies independently known pinned checkerboard");
    for (int y = -36; y <= 36; ++y) for (int x = -36; x <= 36; ++x) {
        const auto cx = static_cast<std::int64_t>(std::floor(static_cast<double>(x) / 4));
        const auto cy = static_cast<std::int64_t>(std::floor(static_cast<double>(y) / 4));
        const auto category = static_cast<std::size_t>((cx + cy) % 2 != 0);
        require(prepared->sample({static_cast<double>(x),static_cast<double>(y)}) == def.categories[category],
                "negative coarse boundaries select exact category identities with tiled wrap constraints");
    }
    require(prepared->preparation_work() <= prepared->declared_preparation_work(), "solver retained complete work accounting");
    RegionSolverLimits exact{prepared->preparation_work(), kRegionSolverScratchBytes};
    require(PreparedRegions::compile(def, exact)->fingerprint() == prepared->fingerprint(), "exact execution budget admits same immutable assignment");
    --exact.max_work;
    rejects<RegionAssignmentExhausted>([&] { (void)PreparedRegions::compile(def, exact); }, "one fewer preparation operation rejects transactionally");
    auto roundtrip = PreparedRegions::compile(prepared->definition());
    require(std::equal(roundtrip->cells().begin(), roundtrip->cells().end(), prepared->cells().begin()) &&
            roundtrip->fingerprint() == prepared->fingerprint(), "subsequent immutable preparation reproduces exact categories");
    def.domains.clear();
    auto implicit = PreparedRegions::compile(def);
    def.domains.assign(16,3);
    require(PreparedRegions::compile(def)->fingerprint() == implicit->fingerprint(), "default domains canonicalize identically to explicit full domains");
    def.seed++;
    require(PreparedRegions::compile(def)->fingerprint() != implicit->fingerprint(), "solver seed participates in identity even if a solution coincides");
    rejects<RegionAssignmentUnsatisfiable>([] { (void)PreparedRegions::compile(checkerboard(3,3,true)); }, "odd wrapped checkerboard is proven unsatisfiable rather than silently violating seam");
    rejects<RegionAssignmentUnsatisfiable>([] { (void)PreparedRegions::compile(checkerboard(1,1,true)); }, "wrapped singleton checks self adjacency");
    require(PreparedRegions::compile(checkerboard(3,3,false))->cells().size() == 9, "finite nonwrapped solver has no invented cross-tile guarantee");
    rejects<RegionAssignmentExhausted>([] { (void)PreparedRegions::compile(checkerboard(4,4,true), {1,kRegionSolverScratchBytes}); }, "insufficient preparation work is distinct from UNSAT");
    rejects([] { (void)PreparedRegions::compile(checkerboard(4,4,true), {1'000'000,kRegionSolverScratchBytes-1}); }, "solver memory refusal precedes storage preparation");
    def = checkerboard(17,1,false);
    rejects([&] { (void)PreparedRegions::compile(def); }, "unbounded region dimensions reject");
    def = checkerboard(2,2,false); def.adjacency[0][0] = 1;
    rejects([&] { (void)PreparedRegions::compile(def); }, "asymmetric directional adjacency rejects");
    def = checkerboard(2,2,false); def.adjacency[0][15] = 1;
    rejects([&] { (void)PreparedRegions::compile(def); }, "unused invalid adjacency declaration still rejects");
    def = checkerboard(2,2,false); def.domains = {0,3,3,3};
    rejects([&] { (void)PreparedRegions::compile(def); }, "empty input domain rejects as malformed declaration");
    def = checkerboard(2,2,false); def.categories[1] = def.categories[0];
    rejects([&] { (void)PreparedRegions::compile(def); }, "exact category identity collision rejects");
}

void region_solver_exhaustive_reference() {
    // Independent complete enumeration of all assignments on 2x2 tiles for
    // every pair of binary directional relation tables, with and without wrap.
    // This checks satisfiable/UNSAT disposition as well as the actual returned
    // assignment, instead of duplicating the solver's propagation algorithm.
    for (unsigned relation = 0; relation < 256; ++relation) for (const bool wrap : {false, true}) {
        auto definition = checkerboard(2,2,wrap);
        definition.seed = relation * 7129U + 17U;
        definition.adjacency = {};
        for (std::size_t from = 0; from < 2; ++from) for (std::size_t to = 0; to < 2; ++to) {
            const auto bit = static_cast<unsigned>(from * 2 + to);
            if ((relation & (1U << bit)) != 0) {
                definition.adjacency[0][from] |= static_cast<std::uint16_t>(1U << to);
                definition.adjacency[2][to] |= static_cast<std::uint16_t>(1U << from);
            }
            if ((relation & (1U << (bit + 4))) != 0) {
                definition.adjacency[1][from] |= static_cast<std::uint16_t>(1U << to);
                definition.adjacency[3][to] |= static_cast<std::uint16_t>(1U << from);
            }
        }
        auto allowed = [&](unsigned assignment) {
            for (unsigned y = 0; y < 2; ++y) for (unsigned x = 0; x < 2; ++x) {
                const auto from = (assignment >> (y * 2 + x)) & 1U;
                if (x == 0 || wrap) {
                    const auto to = (assignment >> (y * 2 + (1 - x))) & 1U;
                    if ((definition.adjacency[0][from] & (1U << to)) == 0) return false;
                }
                if (y == 0 || wrap) {
                    const auto to = (assignment >> ((1 - y) * 2 + x)) & 1U;
                    if ((definition.adjacency[1][from] & (1U << to)) == 0) return false;
                }
            }
            return true;
        };
        bool satisfiable = false;
        for (unsigned assignment = 0; assignment < 16; ++assignment) satisfiable = satisfiable || allowed(assignment);
        try {
            const auto solution = PreparedRegions::compile(definition);
            require(satisfiable, "finite solver cannot invent a solution to an independently proven UNSAT relation");
            unsigned assignment = 0;
            for (unsigned i = 0; i < 4; ++i) {
                require(solution->cells()[i] == definition.categories[0] || solution->cells()[i] == definition.categories[1],
                        "solver output is one declared exact category");
                if (solution->cells()[i] == definition.categories[1]) assignment |= 1U << i;
            }
            require(allowed(assignment), "solver output satisfies every independent horizontal/vertical/seam rule");
        } catch (const RegionAssignmentUnsatisfiable&) {
            require(!satisfiable, "finite solver must not reject an independently enumerated valid assignment");
        }
    }
}

void purity_work_and_allocation_bounds() {
    const auto route = PreparedGeometry::compile({"route", {{-10,0},{10,0}}, false});
    const auto regions = PreparedRegions::compile(checkerboard(4,4,true));
    const LatticeSpec lattice{138,42,16,.8};
    const PoissonSpec poisson{lattice,16,2};
    std::array<std::uint64_t, 128> expected{};
    for (std::size_t i = 0; i < expected.size(); ++i) {
        const Point p{static_cast<double>(i) - 64.0, static_cast<double>(i % 13) - 6.0};
        const auto a = nearest_seed_unchecked(lattice,p);
        expected[i] = static_cast<std::uint64_t>(a.id.x) ^ static_cast<std::uint64_t>(a.id.y) ^ regions->sample(p);
    }
    std::atomic<bool> matched = true;
    std::vector<std::thread> workers;
    for (std::size_t worker = 0; worker < 4; ++worker) workers.emplace_back([&] {
        for (std::size_t reverse = expected.size(); reverse > 0; --reverse) {
            const auto i = reverse - 1;
            const Point p{static_cast<double>(i) - 64.0, static_cast<double>(i % 13) - 6.0};
            const auto a = nearest_seed_unchecked(lattice,p);
            if ((static_cast<std::uint64_t>(a.id.x) ^ static_cast<std::uint64_t>(a.id.y) ^ regions->sample(p)) != expected[i]) matched = false;
        }
    });
    for (auto& worker : workers) worker.join();
    require(matched, "immutable spatial inputs are order/worker independent");
    volatile double sink = 0;
    allocation_probe::count = 0; allocation_probe::enabled = true;
    for (int i = 0; i < 200; ++i) {
        const Point p{static_cast<double>(i)-100.0, -0.5};
        sink = nearest_seed_unchecked(lattice,p).distance + voronoi_boundary_unchecked(lattice,p) +
            delaunay_unchecked(lattice,p).incident_distance + poisson_unchecked(poisson,p).distance +
            route->distance(p) + static_cast<double>(regions->sample(p)) +
            static_cast<double>(peano_address_unchecked(p.x,p.y,3).index);
    }
    allocation_probe::enabled = false;
    require(allocation_probe::count == 0 && std::isfinite(sink), "all successful spatial samples use bounded scratch without ordinary allocation");
    rejects([] { LatticeSpec s; s.spacing = 0; validate(s); }, "zero seed spacing rejects");
    rejects([] { LatticeSpec s; s.jitter = std::numeric_limits<double>::infinity(); validate(s); }, "nonfinite feature declaration rejects");
    rejects([] { PoissonSpec s; s.radius = 129; validate(s); }, "unbounded Poisson rejection radius rejects");
    rejects([] { PoissonSpec s; s.search_cells = 5; validate(s); }, "unbounded Poisson query footprint rejects");
}
} // namespace

int main() {
    try {
        bounded_finite_magnitude();
        peano_inverses_and_locality();
        voronoi_analytic_and_large_neighborhood_oracle();
        delaunay_dual_structure();
        poisson_spacing_ownership_and_truncated_distance();
        geometry_distance_and_identity();
        bounded_region_solver();
        region_solver_exhaustive_reference();
        purity_work_and_allocation_bounds();
        std::cout << "PASS generation spatial: finite Peano coverage/inverses/locality; independent broad Voronoi/Poisson controls; "
                     "Delaunay ties and reciprocal structure; exact geometry/categories; bounded UNSAT/exhaustion; negative boundaries; concurrent allocation-free sampling\n";
    } catch (const std::exception& error) {
        allocation_probe::enabled = false;
        std::cerr << "FAIL generation spatial: " << error.what() << '\n';
        return 1;
    }
}
