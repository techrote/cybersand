#include "cybersand/generation_spatial.hpp"
#include "cybersand/generation_numeric.hpp"

#include <algorithm>
#include <bit>
#include <cmath>
#include <limits>
#include <utility>

namespace cybersand::generation::spatial {
namespace {

constexpr double kSqrtTwo = 1.41421356237309504880;
constexpr std::uint64_t kFnvOffset = UINT64_C(14695981039346656037);
constexpr std::uint64_t kFnvPrime = UINT64_C(1099511628211);

void require(bool condition, const char* message) {
    if (!condition) throw std::invalid_argument(message);
}
void coordinate(double value) {
    require(std::isfinite(value) && value >= -kSampleCoordinateLimit && value < kSampleCoordinateLimit,
            "spatial coordinate must be finite and within [-2^44,2^44)");
}
void identifier(const std::string& id) {
    require(!id.empty() && id.size() <= 96, "spatial input ID must have 1..96 characters");
    for (const auto c : id) require((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') || c == '_' || c == '-' || c == '.', "invalid spatial input ID");
}
std::uint64_t mix(std::uint64_t v) noexcept {
    v += UINT64_C(0x9e3779b97f4a7c15);
    v = (v ^ (v >> 30U)) * UINT64_C(0xbf58476d1ce4e5b9);
    v = (v ^ (v >> 27U)) * UINT64_C(0x94d049bb133111eb);
    return v ^ (v >> 31U);
}
std::uint64_t random_bits(const LatticeSpec& spec, RegionId id) noexcept {
    return mix(spec.seed ^ mix(static_cast<std::uint64_t>(id.x)) ^
               std::rotl(mix(static_cast<std::uint64_t>(id.y)), 27) ^ mix(spec.salt));
}
double unit(std::uint64_t hash) noexcept { return static_cast<double>(hash >> 11U) * 0x1.0p-53; }
Point local_seed(const LatticeSpec& spec, RegionId id) noexcept {
    const auto hash = random_bits(spec, id);
    // unit is [0,1). A candidate can lie on its tile's lower boundary but never
    // on the upper boundary; ownership therefore stays exact at jitter==1.
    return {0.5 + spec.jitter * (unit(hash) - 0.5),
            0.5 + spec.jitter * (unit(mix(hash ^ UINT64_C(0x4a36b17f85e269d3))) - 0.5)};
}
Point subtract(Point a, Point b) noexcept { return {a.x - b.x, a.y - b.y}; }
double dot(Point a, Point b) noexcept { return a.x * b.x + a.y * b.y; }
double squared(Point a) noexcept { return dot(a, a); }
double segment_distance(Point query, Point a, Point b) noexcept {
    const auto direction = subtract(b, a);
    const auto offset = subtract(query, a);
    const auto denominator = squared(direction);
    const auto t = denominator == 0 ? 0 : std::clamp(dot(offset, direction) / denominator, 0.0, 1.0);
    return detail::magnitude(offset.x - t * direction.x, offset.y - t * direction.y);
}
std::int64_t floor_div(std::int64_t a, std::int64_t b) noexcept {
    return a / b - static_cast<std::int64_t>(a % b < 0);
}
std::uint32_t unchecked_side(std::uint32_t order) noexcept {
    std::uint32_t side = 1;
    for (std::uint32_t i = 0; i < order; ++i) side *= 3;
    return side;
}
std::uint64_t unchecked_peano_index(std::uint32_t order, std::uint32_t x, std::uint32_t y) noexcept {
    std::uint64_t result = 0;
    auto size = unchecked_side(order);
    while (size > 1) {
        size /= 3;
        const auto column = x / size, row = y / size;
        const auto digit = column * 3 + ((column & 1U) != 0 ? 2U - row : row);
        result = result * 9 + digit;
        x %= size; y %= size;
        if ((row & 1U) != 0) x = size - 1 - x;
        if ((column & 1U) != 0) y = size - 1 - y;
    }
    return result;
}
void hash_u64(std::uint64_t& hash, std::uint64_t v) noexcept {
    for (int shift = 0; shift < 64; shift += 8) { hash ^= (v >> shift) & 255U; hash *= kFnvPrime; }
}
void hash_double(std::uint64_t& hash, double v) noexcept {
    // -0 and +0 have the same mathematical/canonical identity.
    hash_u64(hash, std::bit_cast<std::uint64_t>(v == 0 ? 0.0 : v));
}
void hash_string(std::uint64_t& hash, const std::string& value) noexcept {
    hash_u64(hash, value.size());
    for (const auto c : value) { hash ^= static_cast<unsigned char>(c); hash *= kFnvPrime; }
}

struct LocalNearest {
    RegionId id{};
    Point relative{}, query_fraction{};
    double distance_squared = std::numeric_limits<double>::infinity();
};
LocalNearest nearest(const LatticeSpec& spec, Point query) noexcept {
    const auto qx = query.x / spec.spacing, qy = query.y / spec.spacing;
    const auto bx = static_cast<std::int64_t>(std::floor(qx));
    const auto by = static_cast<std::int64_t>(std::floor(qy));
    const Point fraction{qx - static_cast<double>(bx), qy - static_cast<double>(by)};
    LocalNearest result; result.query_fraction = fraction;
    // A containing-tile seed is no farther than sqrt(2). Outside this 5x5
    // stencil every seed is at least 2 away. Exact ties use signed (x,y).
    for (std::int64_t dy = -2; dy <= 2; ++dy) for (std::int64_t dx = -2; dx <= 2; ++dx) {
        const RegionId id{bx + dx, by + dy};
        const auto position = local_seed(spec, id);
        const Point relative{static_cast<double>(dx) + position.x - fraction.x,
                             static_cast<double>(dy) + position.y - fraction.y};
        const auto d2 = squared(relative);
        if (d2 < result.distance_squared || (d2 == result.distance_squared && id < result.id)) {
            result.id = id; result.relative = relative; result.distance_squared = d2;
        }
    }
    return result;
}
SeedSample export_seed(const LatticeSpec& spec, Point query, const LocalNearest& value) noexcept {
    const Point displacement{value.relative.x * spec.spacing, value.relative.y * spec.spacing};
    return {value.id, {query.x + displacement.x, query.y + displacement.y}, displacement,
            std::sqrt(value.distance_squared) * spec.spacing};
}
std::uint32_t poisson_halo(const PoissonSpec& spec) noexcept {
    return static_cast<std::uint32_t>(std::ceil(spec.radius / spec.lattice.spacing)) + 1;
}
bool priority_before(const LatticeSpec& spec, RegionId a, RegionId b) noexcept {
    const auto pa = random_bits(spec, a), pb = random_bits(spec, b);
    return pa < pb || (pa == pb && a < b);
}

class WorkBudget {
public:
    explicit WorkBudget(std::uint64_t maximum) : maximum_(maximum) {}
    void charge(std::uint64_t amount) {
        if (amount > maximum_ - used_) throw RegionAssignmentExhausted("region solver exhausted declared preparation work; increase max_work or simplify constraints");
        used_ += amount;
    }
    [[nodiscard]] std::uint64_t used() const noexcept { return used_; }
private:
    std::uint64_t maximum_{}, used_{};
};
using Domains = std::array<std::uint16_t, kMaxRegionCells>;
struct SolverFrame {
    std::array<std::pair<std::uint64_t, std::uint16_t>, kMaxRegionCategories> choices{};
    std::size_t chosen{}, size{}, next{};
    bool entered = false;
};
struct SolverScratch {
    std::array<Domains, kMaxRegionCells + 1> snapshots{};
    std::array<SolverFrame, kMaxRegionCells + 1> frames{};
};
static_assert(sizeof(SolverScratch) + 4096 <= kRegionSolverScratchBytes);

std::size_t neighbor(const RegionAssignment& definition, std::size_t cell, std::size_t direction) noexcept {
    auto x = static_cast<int>(cell % definition.width), y = static_cast<int>(cell / definition.width);
    constexpr std::array<int, 4> dx{1, 0, -1, 0}, dy{0, 1, 0, -1};
    x += dx[direction]; y += dy[direction];
    const auto width = static_cast<int>(definition.width), height = static_cast<int>(definition.height);
    if (x < 0 || x >= width) {
        if (!definition.wrap_x) return kMaxRegionCells;
        x = (x + width) % width;
    }
    if (y < 0 || y >= height) {
        if (!definition.wrap_y) return kMaxRegionCells;
        y = (y + height) % height;
    }
    return static_cast<std::size_t>(y * width + x);
}
bool propagate(const RegionAssignment& definition, Domains& domains, WorkBudget& work) {
    const auto count = static_cast<std::size_t>(definition.width) * definition.height;
    bool changed = true;
    while (changed) {
        changed = false;
        for (std::size_t cell = 0; cell < count; ++cell) for (std::size_t direction = 0; direction < 4; ++direction) {
            work.charge(16 + definition.categories.size() * 4);
            const auto adjacent = neighbor(definition, cell, direction);
            if (adjacent == kMaxRegionCells) continue;
            std::uint16_t allowed = 0;
            for (std::size_t category = 0; category < definition.categories.size(); ++category)
                if ((domains[cell] & (UINT16_C(1) << category)) != 0) allowed |= definition.adjacency[direction][category];
            const auto reduced = static_cast<std::uint16_t>(domains[adjacent] & allowed);
            if (reduced == 0) return false;
            if (reduced != domains[adjacent]) { domains[adjacent] = reduced; changed = true; }
        }
    }
    return true;
}
bool solve(const RegionAssignment& definition, SolverScratch& scratch, WorkBudget& work) {
    const auto count = static_cast<std::size_t>(definition.width) * definition.height;
    std::size_t depth = 0;
    for (;;) {
        auto& domains = scratch.snapshots[depth];
        auto& frame = scratch.frames[depth];
        if (!frame.entered) {
            frame.entered = true;
            frame.size = 0; frame.next = 0;
            if (propagate(definition, domains, work)) {
                work.charge(count * 8 + 32);
                frame.chosen = count;
                auto smallest = static_cast<int>(kMaxRegionCategories + 1);
                for (std::size_t cell = 0; cell < count; ++cell) {
                    const auto size = std::popcount(domains[cell]);
                    if (size > 1 && size < smallest) { smallest = size; frame.chosen = cell; }
                }
                if (frame.chosen == count) {
                    bool compatible = true;
                    for (std::size_t cell = 0; cell < count; ++cell) for (std::size_t direction = 0; direction < 4; ++direction) {
                        work.charge(16);
                        const auto adjacent = neighbor(definition, cell, direction);
                        if (adjacent == kMaxRegionCells) continue;
                        const auto category = static_cast<std::size_t>(std::countr_zero(domains[cell]));
                        compatible = compatible && (definition.adjacency[direction][category] & domains[adjacent]) != 0;
                    }
                    if (compatible) { scratch.snapshots[0] = domains; return true; }
                } else {
                    for (std::size_t category = 0; category < definition.categories.size(); ++category) {
                        work.charge(16);
                        const auto mask = static_cast<std::uint16_t>(UINT16_C(1) << category);
                        if ((domains[frame.chosen] & mask) != 0) frame.choices[frame.size++] = {
                            mix(definition.seed ^ mix(frame.chosen) ^ mix(definition.categories[category])), mask};
                    }
                    // A fixed <=16-entry sort; no heap or recursive solver calls.
                    work.charge(frame.size * frame.size * 4);
                    std::sort(frame.choices.begin(), frame.choices.begin() + static_cast<std::ptrdiff_t>(frame.size));
                }
            }
        }
        if (frame.next < frame.size) {
            work.charge(kMaxRegionCells + 16);
            scratch.snapshots[depth + 1] = domains;
            scratch.snapshots[depth + 1][frame.chosen] = frame.choices[frame.next++].second;
            ++depth;
            scratch.frames[depth].entered = false;
        } else {
            if (depth == 0) return false;
            --depth;
        }
    }
}

} // namespace

std::uint32_t peano_side(std::uint32_t order) {
    require(order >= 1 && order <= kMaxPeanoOrder, "Peano order must be 1..12");
    return unchecked_side(order);
}
std::uint64_t peano_index(std::uint32_t order, std::uint32_t x, std::uint32_t y) {
    const auto side = peano_side(order);
    require(x < side && y < side, "Peano local coordinates lie outside the finite tile");
    return unchecked_peano_index(order, x, y);
}
PeanoPoint peano_point(std::uint32_t order, std::uint64_t index) {
    const auto side = peano_side(order);
    require(index < static_cast<std::uint64_t>(side) * side, "Peano rank lies outside the finite tile");
    PeanoPoint result;
    for (std::uint32_t size = 1; size < side; size *= 3) {
        const auto digit = static_cast<std::uint32_t>(index % 9); index /= 9;
        const auto column = digit / 3;
        const auto row = (column & 1U) != 0 ? 2U - digit % 3 : digit % 3;
        if ((row & 1U) != 0) result.x = size - 1 - result.x;
        if ((column & 1U) != 0) result.y = size - 1 - result.y;
        result.x += column * size; result.y += row * size;
    }
    return result;
}
PeanoAddress peano_address(double x, double y, std::uint32_t order, std::uint32_t cell_size,
                           double origin_x, double origin_y) {
    coordinate(x); coordinate(y); coordinate(origin_x); coordinate(origin_y);
    (void)peano_side(order);
    require(cell_size >= 1 && cell_size <= 4096, "Peano cell size must be 1..4096");
    return peano_address_unchecked(x, y, order, cell_size, origin_x, origin_y);
}
PeanoAddress peano_address_unchecked(double x, double y, std::uint32_t order, std::uint32_t cell_size,
                                     double origin_x, double origin_y) noexcept {
    const auto side = static_cast<std::int64_t>(unchecked_side(order));
    const auto gx = static_cast<std::int64_t>(std::floor((x - origin_x) / cell_size));
    const auto gy = static_cast<std::int64_t>(std::floor((y - origin_y) / cell_size));
    PeanoAddress result; result.tile_x = floor_div(gx, side); result.tile_y = floor_div(gy, side);
    result.local_x = static_cast<std::uint32_t>(gx - result.tile_x * side);
    result.local_y = static_cast<std::uint32_t>(gy - result.tile_y * side);
    result.index = unchecked_peano_index(order, result.local_x, result.local_y);
    return result;
}

void validate(const LatticeSpec& spec) {
    require(std::isfinite(spec.spacing) && spec.spacing >= 1 && spec.spacing <= 1'048'576,
            "feature lattice spacing must be finite and within 1..1048576 cells");
    require(std::isfinite(spec.jitter) && spec.jitter >= 0 && spec.jitter <= 1,
            "feature lattice jitter must be finite and within [0,1]");
}
Point lattice_seed_unchecked(const LatticeSpec& spec, RegionId id) noexcept {
    const auto local = local_seed(spec, id);
    return {(static_cast<double>(id.x) + local.x) * spec.spacing,
            (static_cast<double>(id.y) + local.y) * spec.spacing};
}
SeedSample nearest_seed_unchecked(const LatticeSpec& spec, Point query) noexcept {
    return export_seed(spec, query, nearest(spec, query));
}
double voronoi_boundary_unchecked(const LatticeSpec& spec, Point query) noexcept {
    const auto owner = nearest(spec, query);
    const auto a = local_seed(spec, owner.id);
    auto boundary = std::numeric_limits<double>::infinity();
    // A Voronoi cell is contained in the radius-sqrt(2) disk around its seed,
    // because a seed exists in every tile. Every true face therefore joins
    // sites at distance <=2*sqrt(2), all in these 7x7 owner-centered tiles.
    for (std::int64_t dy = -3; dy <= 3; ++dy) for (std::int64_t dx = -3; dx <= 3; ++dx) {
        if (dx == 0 && dy == 0) continue;
        const auto b = local_seed(spec, {owner.id.x + dx, owner.id.y + dy});
        const Point direction{static_cast<double>(dx) + b.x - a.x, static_cast<double>(dy) + b.y - a.y};
        const auto length = detail::magnitude(direction.x, direction.y);
        // Stable plane distance, avoiding subtraction of large world squares.
        const auto distance = length * 0.5 + dot(owner.relative, direction) / length;
        boundary = std::min(boundary, std::max(0.0, distance));
    }
    return boundary * spec.spacing;
}
DelaunayNeighborhood delaunay_unchecked(const LatticeSpec& spec, Point query) noexcept {
    const auto owner = nearest(spec, query);
    DelaunayNeighborhood result; result.owner = export_seed(spec, query, owner);
    const auto a = local_seed(spec, owner.id);
    std::array<Point, 48> offsets{};
    std::array<RegionId, 48> ids{};
    std::size_t count = 0;
    for (std::int64_t dy = -3; dy <= 3; ++dy) for (std::int64_t dx = -3; dx <= 3; ++dx) {
        if (dx == 0 && dy == 0) continue;
        const RegionId id{owner.id.x + dx, owner.id.y + dy};
        const auto b = local_seed(spec, id);
        offsets[count] = {static_cast<double>(dx) + b.x - a.x, static_cast<double>(dy) + b.y - a.y};
        ids[count++] = id;
    }
    result.incident_distance = std::numeric_limits<double>::infinity();
    for (std::size_t candidate = 0; candidate < count; ++candidate) {
        const auto direction = offsets[candidate];
        const auto length = detail::magnitude(direction.x, direction.y);
        if (length > 2 * kSqrtTwo) continue;
        const Point midpoint{direction.x * 0.5, direction.y * 0.5};
        const Point tangent{-direction.y / length, direction.x / length};
        auto low = -kSqrtTwo, high = kSqrtTwo;
        for (std::size_t constraint = 0; constraint < count && low <= high; ++constraint) {
            if (constraint == candidate) continue;
            const auto normal = offsets[constraint];
            const auto rhs = squared(normal) * 0.5 - dot(midpoint, normal);
            const auto coefficient = dot(tangent, normal);
            if (coefficient > 0) high = std::min(high, rhs / coefficient);
            else if (coefficient < 0) low = std::max(low, rhs / coefficient);
            else if (rhs < 0) { low = 1; high = -1; }
        }
        // The convention excludes zero-length faces (regular-grid diagonals).
        // No epsilon changes near-degenerate topology; floating arithmetic is
        // qualified to the actual platform, as with other spatial primitives.
        if (!(high > low)) continue;
        const auto index = result.size++;
        result.neighbors[index] = ids[candidate];
        result.positions[index] = {result.owner.position.x + direction.x * spec.spacing,
                                   result.owner.position.y + direction.y * spec.spacing};
        const Point relative_query{-owner.relative.x, -owner.relative.y};
        result.incident_distance = std::min(result.incident_distance,
            segment_distance(relative_query, {}, direction) * spec.spacing);
    }
    return result;
}

void validate(const PoissonSpec& spec) {
    validate(spec.lattice);
    require(std::isfinite(spec.radius) && spec.radius > 0 && spec.radius <= 2 * spec.lattice.spacing,
            "Poisson exclusion radius must be finite, positive and at most twice lattice spacing");
    require(spec.search_cells >= 1 && spec.search_cells <= 4, "Poisson search_cells must be 1..4");
}
bool poisson_seed_accepted_unchecked(const PoissonSpec& spec, RegionId id) noexcept {
    const auto a = local_seed(spec.lattice, id);
    const auto radius = spec.radius / spec.lattice.spacing;
    const auto radius2 = radius * radius;
    const auto halo = static_cast<std::int64_t>(poisson_halo(spec));
    for (std::int64_t dy = -halo; dy <= halo; ++dy) for (std::int64_t dx = -halo; dx <= halo; ++dx) {
        if (dx == 0 && dy == 0) continue;
        const RegionId competitor{id.x + dx, id.y + dy};
        if (!priority_before(spec.lattice, competitor, id)) continue;
        const auto b = local_seed(spec.lattice, competitor);
        const Point offset{static_cast<double>(dx) + b.x - a.x, static_cast<double>(dy) + b.y - a.y};
        if (squared(offset) < radius2) return false;
    }
    return true;
}
PoissonSample poisson_unchecked(const PoissonSpec& spec, Point query) noexcept {
    const auto qx = query.x / spec.lattice.spacing, qy = query.y / spec.lattice.spacing;
    const auto bx = static_cast<std::int64_t>(std::floor(qx)), by = static_cast<std::int64_t>(std::floor(qy));
    const Point fraction{qx - static_cast<double>(bx), qy - static_cast<double>(by)};
    const auto search = static_cast<std::int64_t>(spec.search_cells);
    const auto radius = static_cast<double>(spec.search_cells);
    LocalNearest winner; winner.distance_squared = radius * radius;
    PoissonSample result; result.distance = radius * spec.lattice.spacing;
    for (std::int64_t dy = -search; dy <= search; ++dy) for (std::int64_t dx = -search; dx <= search; ++dx) {
        const RegionId id{bx + dx, by + dy};
        const auto point = local_seed(spec.lattice, id);
        const Point offset{static_cast<double>(dx) + point.x - fraction.x,
                           static_cast<double>(dy) + point.y - fraction.y};
        const auto d2 = squared(offset);
        if (d2 >= radius * radius) continue;
        if ((d2 < winner.distance_squared || (d2 == winner.distance_squared && id < winner.id)) &&
            poisson_seed_accepted_unchecked(spec, id)) {
            winner.id = id; winner.relative = offset; winner.distance_squared = d2; result.found = true;
        }
    }
    if (result.found) { result.nearest = export_seed(spec.lattice, query, winner); result.distance = result.nearest.distance; }
    return result;
}
std::uint64_t poisson_work_bound(const PoissonSpec& spec) noexcept {
    const auto query_side = 2 * static_cast<std::uint64_t>(spec.search_cells) + 1;
    const auto reject_side = 2 * static_cast<std::uint64_t>(poisson_halo(spec)) + 1;
    return 128 + query_side * query_side * (128 + reject_side * reject_side * 128);
}

void validate(const Geometry& geometry) {
    identifier(geometry.id);
    require(!geometry.points.empty() && geometry.points.size() <= kMaxGeometryPoints,
            "feature geometry requires 1..256 points");
    require(!geometry.closed || geometry.points.size() >= 3, "closed feature geometry requires at least three points");
    for (const auto point : geometry.points) { coordinate(point.x); coordinate(point.y); }
}
PreparedGeometry::PreparedGeometry(Geometry geometry) : geometry_(std::move(geometry)), fingerprint_(kFnvOffset) {
    hash_u64(fingerprint_, 1); hash_string(fingerprint_, geometry_.id);
    hash_u64(fingerprint_, geometry_.closed); hash_u64(fingerprint_, geometry_.points.size());
    for (const auto point : geometry_.points) { hash_double(fingerprint_, point.x); hash_double(fingerprint_, point.y); }
}
std::shared_ptr<const PreparedGeometry> PreparedGeometry::compile(Geometry geometry) {
    validate(geometry);
    return std::shared_ptr<const PreparedGeometry>(new PreparedGeometry(std::move(geometry)));
}
double PreparedGeometry::distance(Point query) const noexcept {
    if (geometry_.points.size() == 1) return detail::magnitude(query.x - geometry_.points[0].x, query.y - geometry_.points[0].y);
    auto result = std::numeric_limits<double>::infinity();
    for (std::size_t i = 1; i < geometry_.points.size(); ++i)
        result = std::min(result, segment_distance(query, geometry_.points[i - 1], geometry_.points[i]));
    if (geometry_.closed) result = std::min(result, segment_distance(query, geometry_.points.back(), geometry_.points.front()));
    return result;
}
const Geometry& PreparedGeometry::geometry() const noexcept { return geometry_; }
std::uint64_t PreparedGeometry::fingerprint() const noexcept { return fingerprint_; }
std::uint64_t PreparedGeometry::work_bound() const noexcept { return 64 + 64 * geometry_.points.size(); }
std::size_t PreparedGeometry::storage_bytes() const noexcept {
    return sizeof(*this) + geometry_.id.capacity() + 1 + geometry_.points.capacity() * sizeof(Point);
}

void validate(const RegionAssignment& definition, RegionSolverLimits limits) {
    require(definition.width >= 1 && definition.width <= 16 && definition.height >= 1 && definition.height <= 16,
            "region assignment dimensions must each be 1..16 cells");
    require(definition.cell_size >= 1 && definition.cell_size <= 4096, "region assignment cell_size must be 1..4096");
    coordinate(definition.origin_x); coordinate(definition.origin_y);
    require(!definition.categories.empty() && definition.categories.size() <= kMaxRegionCategories,
            "region assignment requires 1..16 exact categories");
    for (std::size_t i = 0; i < definition.categories.size(); ++i)
        for (std::size_t j = 0; j < i; ++j) require(definition.categories[i] != definition.categories[j], "region assignment category IDs must be unique");
    const auto mask = static_cast<std::uint16_t>((UINT32_C(1) << definition.categories.size()) - 1U);
    for (std::size_t direction = 0; direction < 4; ++direction) for (std::size_t from = 0; from < kMaxRegionCategories; ++from) {
        const auto allowed = definition.adjacency[direction][from];
        require((allowed & ~mask) == 0, "region adjacency references an undeclared category");
        if (from >= definition.categories.size()) { require(allowed == 0, "unused region adjacency rows must be zero"); continue; }
        for (std::size_t to = 0; to < definition.categories.size(); ++to) {
            const bool forward = (allowed & (UINT16_C(1) << to)) != 0;
            const bool reverse = (definition.adjacency[(direction + 2) % 4][to] & (UINT16_C(1) << from)) != 0;
            require(forward == reverse, "region adjacency must be reciprocal across opposite directions");
        }
    }
    const auto count = static_cast<std::size_t>(definition.width) * definition.height;
    require(definition.domains.empty() || definition.domains.size() == count,
            "region domains must be absent or have exactly width*height entries");
    for (const auto domain : definition.domains) require(domain != 0 && (domain & ~mask) == 0,
            "region domains must contain nonempty masks of declared categories");
    require(limits.max_work >= 1 && limits.max_work <= kMaxRegionSolverWork,
            "region solver work limit must be 1..64000000");
    require(limits.max_scratch_bytes >= kRegionSolverScratchBytes,
            "region solver scratch budget is smaller than declared fixed preparation storage");
}
std::shared_ptr<const PreparedRegions> PreparedRegions::compile(RegionAssignment definition, RegionSolverLimits limits) {
    require(limits.max_work >= 1 && limits.max_work <= kMaxRegionSolverWork,
            "region solver work limit must be 1..64000000");
    WorkBudget work(limits.max_work);
    // Charge validation, final canonical hashing and bounded result allocation
    // before doing them; a tiny work request never begins solver preparation.
    work.charge(32'768);
    validate(definition, limits);
    work.charge(sizeof(SolverScratch));
    auto scratch = std::make_unique<SolverScratch>();
    const auto count = static_cast<std::size_t>(definition.width) * definition.height;
    const auto all = static_cast<std::uint16_t>((UINT32_C(1) << definition.categories.size()) - 1U);
    for (std::size_t i = 0; i < count; ++i) scratch->snapshots[0][i] = definition.domains.empty() ? all : definition.domains[i];
    if (!solve(definition, *scratch, work)) throw RegionAssignmentUnsatisfiable("region adjacency/domain constraints are unsatisfiable within the declared finite tile");
    work.charge(count * 8 + 512);
    std::vector<std::uint64_t> cells(count);
    for (std::size_t i = 0; i < count; ++i) cells[i] = definition.categories[static_cast<std::size_t>(std::countr_zero(scratch->snapshots[0][i]))];
    return std::shared_ptr<const PreparedRegions>(new PreparedRegions(std::move(definition), std::move(cells), work.used(), limits.max_work));
}
PreparedRegions::PreparedRegions(RegionAssignment definition, std::vector<std::uint64_t> cells,
                                 std::uint64_t work, std::uint64_t declared_work)
    : definition_(std::move(definition)), cells_(std::move(cells)), fingerprint_(kFnvOffset), work_(work), declared_work_(declared_work) {
    hash_u64(fingerprint_, 1); hash_u64(fingerprint_, definition_.width); hash_u64(fingerprint_, definition_.height);
    hash_u64(fingerprint_, definition_.cell_size); hash_double(fingerprint_, definition_.origin_x); hash_double(fingerprint_, definition_.origin_y);
    hash_u64(fingerprint_, definition_.seed); hash_u64(fingerprint_, definition_.wrap_x); hash_u64(fingerprint_, definition_.wrap_y);
    hash_u64(fingerprint_, definition_.categories.size());
    for (const auto id : definition_.categories) hash_u64(fingerprint_, id);
    for (const auto& direction : definition_.adjacency) for (const auto row : direction) hash_u64(fingerprint_, row);
    // Omitted domains canonicalize to the all-category mask.
    const auto all = static_cast<std::uint16_t>((UINT32_C(1) << definition_.categories.size()) - 1U);
    for (std::size_t i = 0; i < cells_.size(); ++i) hash_u64(fingerprint_, definition_.domains.empty() ? all : definition_.domains[i]);
}
std::uint64_t PreparedRegions::sample(Point query) const noexcept {
    const auto x = static_cast<std::int64_t>(std::floor((query.x - definition_.origin_x) / definition_.cell_size));
    const auto y = static_cast<std::int64_t>(std::floor((query.y - definition_.origin_y) / definition_.cell_size));
    const auto local_x = x - floor_div(x, definition_.width) * definition_.width;
    const auto local_y = y - floor_div(y, definition_.height) * definition_.height;
    return cells_[static_cast<std::size_t>(local_y * definition_.width + local_x)];
}
std::span<const std::uint64_t> PreparedRegions::cells() const noexcept { return cells_; }
const RegionAssignment& PreparedRegions::definition() const noexcept { return definition_; }
std::uint64_t PreparedRegions::fingerprint() const noexcept { return fingerprint_; }
std::uint64_t PreparedRegions::preparation_work() const noexcept { return work_; }
std::uint64_t PreparedRegions::declared_preparation_work() const noexcept { return declared_work_; }
std::size_t PreparedRegions::storage_bytes() const noexcept {
    return sizeof(*this) + definition_.categories.capacity() * sizeof(std::uint64_t) +
        definition_.domains.capacity() * sizeof(std::uint16_t) + cells_.capacity() * sizeof(std::uint64_t);
}

} // namespace cybersand::generation::spatial
