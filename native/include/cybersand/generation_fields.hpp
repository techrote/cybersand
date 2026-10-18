#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <map>
#include <memory>
#include <optional>
#include <span>
#include <string>
#include <vector>

// Independent, immutable procedural fields. No World, Godot, material storage,
// shared random stream, neighbor request, or callback is reachable here.
namespace cybersand::generation {

inline constexpr std::size_t kMaxFieldNodes = 64;
inline constexpr std::size_t kMaxFieldDepth = 16;
inline constexpr std::uint64_t kMaxFieldOperations = 4096;
inline constexpr std::int64_t kFieldCoordinateLimit = INT64_C(1) << 40;
inline constexpr std::uint32_t kFieldAlgorithmVersion = 1;

enum class FieldKind : std::uint8_t {
    Constant, ValueNoise, GradientNoise, Fbm, Ridged, CellularDistance,
    CellularGap, Hilbert, Morton, Circle, Box, Band, Remap, Invert, Add,
    Multiply, Minimum, Maximum, Mix, Smoothstep, Context, Material
};

struct FieldNode {
    std::string id;
    FieldKind kind = FieldKind::Constant;
    std::vector<std::string> inputs;
    std::map<std::string, double> parameters;
    // Noise primitives may use either or both displacement fields. A missing
    // axis means zero displacement; a supplied axis displaces by warp*(2*v-1).
    // Dependencies are evaluated once at the original sample coordinate.
    std::string warp_x;
    std::string warp_y;
    std::string context; // only Context nodes: one of field_context_names()
};

struct FieldLimits {
    std::size_t max_nodes = kMaxFieldNodes;
    std::size_t max_depth = kMaxFieldDepth;
    std::uint64_t max_operations_per_sample = kMaxFieldOperations;
};

// Captured before any field/modifier is applied. The owner defines the raster
// and derivative policy; these values never query or track live cell storage.
struct FieldContext {
    double occupied = 0; // [0,1], non-Empty occupancy
    double solid = 0;    // [0,1], owner's solid predicate
    double fluid = 0;    // [0,1], owner's liquid predicate
    double depth = 0;    // signed cells below the pre-field surface
    double slope = 0;    // nonnegative absolute pre-field surface gradient
    double route = 0;    // [0,1], pre-field shared-network membership
    std::uint16_t material = 0;
};

struct FieldValues {
    // Indexed by canonical ID order, independently of topological evaluation.
    // Every published value is finite and in [0,1]; unused slots are zero.
    std::array<double, kMaxFieldNodes> values{};
    std::size_t size = 0;
};

struct FieldParameterSpec {
    const char* name;
    double default_value;
    double minimum;
    double maximum;
    bool integer = false;
};

struct FieldKindSpec {
    FieldKind kind;
    const char* name;
    std::size_t input_count;
    bool supports_warp;
    bool requires_context;
    std::span<const FieldParameterSpec> parameters;
};

[[nodiscard]] std::span<const FieldKindSpec> field_kind_specs() noexcept;
[[nodiscard]] const FieldKindSpec& field_kind_spec(FieldKind kind);
[[nodiscard]] const char* field_kind_name(FieldKind kind) noexcept;
[[nodiscard]] std::optional<FieldKind> parse_field_kind(const std::string& name) noexcept;
[[nodiscard]] std::span<const char* const> field_context_names() noexcept;

struct CurvePoint { std::uint32_t x{}, y{}; };
struct CurveAddress {
    std::int64_t tile_x{}, tile_y{};
    std::uint32_t local_x{}, local_y{};
    std::uint64_t index{};
};

// Finite curves: order 1..20, side 2^order. Morton places x in even bit lanes.
// Order-1 Hilbert visits (0,0),(0,1),(1,1),(1,0). Consecutive Hilbert ranks
// share an edge within one tile; neither API promises continuity between tiles.
[[nodiscard]] std::uint64_t curve_index(FieldKind kind, std::uint32_t order,
                                       std::uint32_t x, std::uint32_t y);
[[nodiscard]] CurvePoint curve_point(FieldKind kind, std::uint32_t order,
                                     std::uint64_t index);
[[nodiscard]] CurveAddress curve_address(FieldKind kind, std::int64_t x,
                                         std::int64_t y, std::uint32_t order,
                                         std::int64_t cell_size = 1,
                                         std::int64_t origin_x = 0,
                                         std::int64_t origin_y = 0);

class FieldGraph final {
public:
    // Validates every declaration, including unused nodes. IDs, parameters and
    // defaults are canonicalized before fingerprinting; all references/cycles,
    // arity, numeric domains, depth and conservative work bounds are checked.
    [[nodiscard]] static std::shared_ptr<const FieldGraph> compile(
        std::vector<FieldNode> nodes, std::uint64_t seed, FieldLimits limits = {});
    [[nodiscard]] const std::vector<FieldNode>& nodes() const noexcept;
    [[nodiscard]] std::size_t index(const std::string& id) const;
    [[nodiscard]] std::uint64_t fingerprint() const noexcept;
    [[nodiscard]] std::uint64_t operations_per_sample() const noexcept;
    // One evaluation of each declared node, even when a consumer is masked.
    // Successful calls allocate nothing. Invalid coordinates/context throw;
    // the caller's output remains unchanged on failure. No recursive resampling.
    void evaluate(std::int64_t x, std::int64_t y, const FieldContext& context,
                  FieldValues& output) const;
    ~FieldGraph();

private:
    struct Impl;
    explicit FieldGraph(std::unique_ptr<Impl> impl);
    std::unique_ptr<Impl> impl_;
};

} // namespace cybersand::generation
