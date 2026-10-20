#pragma once

#include <array>
#include <compare>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <span>
#include <stdexcept>
#include <string>
#include <vector>

// GEN-003 bounded spatial primitives. These value interfaces cannot reach a
// World, resident chunks, callbacks, or mutable random streams. Call validate
// during graph compilation; the *_unchecked sampling paths allocate nothing.
namespace cybersand::generation::spatial {

inline constexpr double kSampleCoordinateLimit = 0x1.0p44;
inline constexpr std::uint32_t kMaxPeanoOrder = 12;
inline constexpr std::size_t kMaxGeometryPoints = 256;
inline constexpr std::size_t kMaxRegionCells = 256;
inline constexpr std::size_t kMaxRegionCategories = 16;

struct Point { double x{}, y{}; };
// The field/node namespace lives beside this pair in the typed field value.
// Retaining both signed coordinates avoids collisions from hashing/packing an
// 88-bit lattice address into one 64-bit categorical identity.
struct RegionId {
    std::int64_t x{}, y{};
    auto operator<=>(const RegionId&) const = default;
};
struct PeanoPoint { std::uint32_t x{}, y{}; };
struct PeanoAddress {
    std::int64_t tile_x{}, tile_y{};
    std::uint32_t local_x{}, local_y{};
    std::uint64_t index{};
};

// Ternary Peano traversal: a 3^order square, order-1 path
// (0,0),(0,1),(0,2),(1,2),(1,1),(1,0),(2,0),(2,1),(2,2).
// Consecutive ranks share an edge inside one tile. No between-tile route
// continuity is asserted. Addressing uses mathematical floor at negatives.
[[nodiscard]] std::uint32_t peano_side(std::uint32_t order);
[[nodiscard]] std::uint64_t peano_index(std::uint32_t order, std::uint32_t x, std::uint32_t y);
[[nodiscard]] PeanoPoint peano_point(std::uint32_t order, std::uint64_t index);
[[nodiscard]] PeanoAddress peano_address(double x, double y, std::uint32_t order,
                                        std::uint32_t cell_size = 1,
                                        double origin_x = 0, double origin_y = 0);
[[nodiscard]] PeanoAddress peano_address_unchecked(double x, double y, std::uint32_t order,
                                                  std::uint32_t cell_size = 1,
                                                  double origin_x = 0, double origin_y = 0) noexcept;
[[nodiscard]] constexpr std::uint64_t peano_work_bound(std::uint32_t order) noexcept {
    return 32 + 32 * static_cast<std::uint64_t>(order);
}

struct LatticeSpec {
    std::uint64_t seed{}, salt{};
    double spacing = 64;
    double jitter = 1; // centered, one seed strictly owned by each lattice tile
};
void validate(const LatticeSpec& spec);
struct SeedSample {
    RegionId id{};
    Point position{}, displacement{}; // displacement = seed - query, cells
    double distance{}; // exact Euclidean distance for the declared lattice
};
inline constexpr std::uint64_t kNearestSeedWork = 25 * 64 + 64;
inline constexpr std::uint64_t kVoronoiBoundaryWork = kNearestSeedWork + 49 * 96 + 64;
inline constexpr std::uint64_t kDelaunayWork = kNearestSeedWork + 49 * 49 * 128 + 256;
[[nodiscard]] Point lattice_seed_unchecked(const LatticeSpec& spec, RegionId id) noexcept;
[[nodiscard]] SeedSample nearest_seed_unchecked(const LatticeSpec& spec, Point query) noexcept;
[[nodiscard]] double voronoi_boundary_unchecked(const LatticeSpec& spec, Point query) noexcept;

struct DelaunayNeighborhood {
    SeedSample owner{};
    std::array<RegionId, 48> neighbors{};
    std::array<Point, 48> positions{};
    std::size_t size{};
    // Distance to this owner's incident seed-to-seed segments, not a global
    // nearest-edge distance. The graph is the positive-length Voronoi-face
    // dual: co-circular zero-length diagonal edges are deliberately omitted.
    double incident_distance{};
};
[[nodiscard]] DelaunayNeighborhood delaunay_unchecked(const LatticeSpec& spec, Point query) noexcept;

struct PoissonSpec {
    LatticeSpec lattice{};
    double radius = 32; // minimum separation, 0 < radius <= 2*spacing
    std::uint32_t search_cells = 2; // 1..4; R=search_cells*spacing
};
void validate(const PoissonSpec& spec);
struct PoissonSample {
    bool found{}; // accepted seed strictly within R
    SeedSample nearest{};
    double distance{}; // min(R, true nearest accepted distance), always finite
};
// Matérn-II-style deterministic priority rejection, one candidate per tile.
// Candidate A survives iff no lower (priority, ID) candidate is closer than
// radius. Rejected candidates still compete; no recursive acceptance queries.
[[nodiscard]] bool poisson_seed_accepted_unchecked(const PoissonSpec& spec, RegionId id) noexcept;
[[nodiscard]] PoissonSample poisson_unchecked(const PoissonSpec& spec, Point query) noexcept;
[[nodiscard]] std::uint64_t poisson_work_bound(const PoissonSpec& spec) noexcept;

struct Geometry {
    std::string id;
    std::vector<Point> points; // a single point, open polyline or closed boundary
    bool closed = false;
};
void validate(const Geometry& geometry);
// Compiled geometry owns an immutable copy, bounds every segment query and
// hashes actual geometry. It is suitable for routes/feature boundaries supplied
// by GEN-004 without depending on any grammar or live-world implementation.
class PreparedGeometry final {
public:
    [[nodiscard]] static std::shared_ptr<const PreparedGeometry> compile(Geometry geometry);
    [[nodiscard]] double distance(Point query) const noexcept;
    [[nodiscard]] const Geometry& geometry() const noexcept;
    [[nodiscard]] std::uint64_t fingerprint() const noexcept;
    [[nodiscard]] std::uint64_t work_bound() const noexcept;
    [[nodiscard]] std::size_t storage_bytes() const noexcept;
private:
    explicit PreparedGeometry(Geometry geometry);
    Geometry geometry_;
    std::uint64_t fingerprint_{};
};

enum class Direction : std::uint8_t { Right, Down, Left, Up };
struct RegionAssignment {
    std::uint32_t width = 1, height = 1; // finite tile, each <=16, product<=256
    std::uint32_t cell_size = 16; // 1..4096 world cells
    double origin_x{}, origin_y{};
    std::uint64_t seed{};
    std::vector<std::uint64_t> categories; // 1..16 exact identities, authored order
    // Per direction, category -> allowed neighboring category bit mask.
    // All active categories must be declared and reverse edges reciprocal.
    std::array<std::array<std::uint16_t, kMaxRegionCategories>, 4> adjacency{};
    // Empty means all categories; otherwise exactly width*height nonempty masks.
    std::vector<std::uint16_t> domains;
    bool wrap_x = false, wrap_y = false; // enable constraints across tile edges
};
struct RegionSolverLimits {
    std::uint64_t max_work = 1'000'000;
    std::size_t max_scratch_bytes = 256 * 1024;
};
inline constexpr std::uint64_t kMaxRegionSolverWork = 64'000'000;
// Fixed domain snapshots and explicit decision frames, including 4 KiB local
// margin; no solver recursion or unbounded stack. Checked against sizeof in C++.
inline constexpr std::size_t kRegionSolverScratchBytes = 256 * 1024;
void validate(const RegionAssignment& definition, RegionSolverLimits limits = {});
class RegionAssignmentUnsatisfiable final : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};
class RegionAssignmentExhausted final : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};
class PreparedRegions final {
public:
    // Bounded propagation and deterministic backtracking. UNSAT and exhausted
    // configured work are distinct exceptions; neither returns partial state.
    [[nodiscard]] static std::shared_ptr<const PreparedRegions> compile(
        RegionAssignment definition, RegionSolverLimits limits = {});
    // Tile repeats with floor semantics. Cross-tile adjacency is guaranteed
    // only for axes whose corresponding wrap constraint was enabled.
    [[nodiscard]] std::uint64_t sample(Point query) const noexcept;
    [[nodiscard]] std::span<const std::uint64_t> cells() const noexcept;
    [[nodiscard]] const RegionAssignment& definition() const noexcept;
    [[nodiscard]] std::uint64_t fingerprint() const noexcept;
    [[nodiscard]] std::uint64_t preparation_work() const noexcept;
    [[nodiscard]] std::uint64_t declared_preparation_work() const noexcept;
    [[nodiscard]] std::size_t storage_bytes() const noexcept;
    [[nodiscard]] static constexpr std::uint64_t sample_work_bound() noexcept { return 64; }
private:
    PreparedRegions(RegionAssignment definition, std::vector<std::uint64_t> cells,
                    std::uint64_t work, std::uint64_t declared_work);
    RegionAssignment definition_;
    std::vector<std::uint64_t> cells_;
    std::uint64_t fingerprint_{}, work_{}, declared_work_{};
};

} // namespace cybersand::generation::spatial
