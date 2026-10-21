#pragma once

#include "cybersand/generation_fields.hpp"
#include "cybersand/generation_spatial.hpp"

#include <array>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace cybersand::generation {

inline constexpr std::uint32_t kSpatialAlgorithmVersion = 1;
inline constexpr std::size_t kMaxSpatialNodes = 64;
inline constexpr std::size_t kSpatialCacheSlots = 256;

enum class SpatialType : std::uint8_t {
    Normalized,
    Scalar,
    SignedDistance,
    Distance,
    Vector2,
    Category,
    Boolean
};
// Cells^power for scalar/vector values; angles are radians and dimensionless.
// Categorical/boolean values have power zero and never interpolate numerically.
struct SpatialCategory {
    std::int64_t x{}, y{};
    std::uint64_t domain{};
    bool operator==(const SpatialCategory &) const = default;
};
struct SpatialValue {
    SpatialType type = SpatialType::Scalar;
    double x{}, y{};
    SpatialCategory category{};
    bool operator==(const SpatialValue &) const = default;
};

enum class SpatialKind : std::uint8_t {
    Constant,
    Parameter,
    Identity,
    Position,
    CoordinateX,
    CoordinateY,
    CircleDistance,
    BoxDistance,
    Noise,
    Add,
    Subtract,
    Multiply,
    Minimum,
    Maximum,
    Mix,
    ToMask,
    ComposeVector,
    ComponentX,
    ComponentY,
    Length,
    UnitVector,
    Dot,
    Equal,
    Less,
    Select,
    Transform,
    TransformVector,
    Polar,
    LogPolar,
    Repeat,
    Mirror,
    Warp,
    Gradient,
    Slope,
    Aspect,
    Divergence,
    Curl,
    Ridge,
    Valley,
    LocalMinimum,
    LocalMaximum,
    Curvature,
    Peano,
    VoronoiRegion,
    VoronoiDistance,
    VoronoiBoundary,
    DelaunayDegree,
    PoissonDistance,
    PoissonRegion,
    PoissonFound,
    GeometryDistance,
    AssignedRegion,
    CategoryIs
};

struct SpatialNode {
    std::string id;
    SpatialKind kind = SpatialKind::Constant;
    std::vector<std::string> inputs;
    std::map<std::string, double> parameters;
    std::uint32_t sampling_scale = 1; // 1,4,16,64; absolute-world anchored
    SpatialValue value{};             // Constant only
    std::int32_t unit_power = 0;      // Constant only; parameter units come from SpatialParameter
    std::string reference;            // parameter / geometry / assignment ID
    // In a named subgraph only: numeric operator parameter -> typed parameter.
    std::map<std::string, std::string> parameter_bindings;
};

struct SpatialParameter {
    std::string id;
    SpatialType type = SpatialType::Scalar;
    std::int32_t unit_power = 0;
    std::optional<SpatialValue> default_value;
};
struct SpatialInstance {
    std::string id;
    std::string subgraph;
    std::map<std::string, SpatialValue> bindings;
    // Nested instance parameter -> enclosing subgraph parameter.
    std::map<std::string, std::string> parameter_bindings;
};
struct SpatialSubgraph {
    std::string id;
    std::vector<SpatialParameter> parameters;
    std::vector<SpatialNode> nodes;
    std::vector<SpatialInstance> instances;
    std::map<std::string, std::string> outputs;
};
struct SpatialGeometry {
    std::string id;
    std::vector<spatial::Point> points;
    bool closed = false;
};
struct SpatialAssignment {
    std::string id;
    spatial::RegionAssignment specification;
    spatial::RegionSolverLimits limits;
};
struct SpatialDefinition {
    std::vector<SpatialNode> nodes;
    std::vector<SpatialSubgraph> subgraphs;
    std::vector<SpatialInstance> instances;
    std::vector<SpatialGeometry> geometries;
    std::vector<SpatialAssignment> assignments;
    [[nodiscard]] bool empty() const noexcept {
        return nodes.empty() && subgraphs.empty() && instances.empty() && geometries.empty() &&
               assignments.empty();
    }
};
struct SpatialLimits {
    std::size_t max_nodes = kMaxSpatialNodes;
    std::size_t max_depth = 16;
    std::uint64_t max_operations_per_sample = 1'000'000;
    std::uint64_t max_preparation_operations = 16'000'000;
    std::size_t max_preparation_bytes = 16 * 1024 * 1024;
};
struct SpatialInfo {
    SpatialType type = SpatialType::Scalar;
    std::int32_t unit_power = 0;
    // Conservative component range; category/boolean have their exact contract.
    double minimum{}, maximum{};
    // Signed-distance transform qualifiers. One/one is exact, zero/zero general.
    double distance_min_factor{}, distance_max_factor{};
    std::uint64_t fingerprint{}, operations{};
    std::uint32_t sampling_scale = 1;
    bool operator==(const SpatialInfo &) const = default;
};
struct SpatialKindSpec {
    SpatialKind kind;
    const char *name;
    std::size_t input_count;
    std::span<const FieldParameterSpec> parameters;
};
[[nodiscard]] const char *spatial_type_name(SpatialType) noexcept;
[[nodiscard]] std::optional<SpatialType> parse_spatial_type(const std::string &) noexcept;
[[nodiscard]] std::span<const SpatialKindSpec> spatial_kind_specs() noexcept;
[[nodiscard]] const SpatialKindSpec &spatial_kind_spec(SpatialKind);
[[nodiscard]] std::optional<SpatialKind> parse_spatial_kind(const std::string &) noexcept;

struct SpatialValues {
    std::array<SpatialValue, kMaxSpatialNodes> values{};
    std::size_t size{};
};
// Caller-owned, bounded cache; no mutable state in the compiled graph. Keys bind
// the transitive node identity, exact double coordinates and sampling mode.
struct SpatialScratch {
    struct Entry {
        std::uint64_t fingerprint{}, x{}, y{};
        SpatialValue value{};
        bool valid = false;
    };
    std::array<Entry, kSpatialCacheSlots> cache{};
    std::uint64_t hits{}, misses{};
    void clear() noexcept {
        for (auto &entry : cache)
            entry.valid = false;
        hits = misses = 0;
    }
};

class SpatialGraph final {
  public:
    [[nodiscard]] static std::shared_ptr<const SpatialGraph>
    compile(SpatialDefinition definition, std::uint64_t seed, SpatialLimits limits = {});
    [[nodiscard]] const std::vector<SpatialNode> &nodes() const noexcept;
    [[nodiscard]] const SpatialInfo &info(std::size_t index) const;
    [[nodiscard]] std::size_t index(const std::string &id) const;
    [[nodiscard]] std::uint64_t fingerprint() const noexcept;
    [[nodiscard]] std::uint64_t operations_per_sample() const noexcept;
    [[nodiscard]] std::uint64_t preparation_operations() const noexcept;
    [[nodiscard]] std::size_t preparation_bytes() const noexcept;
    // Transactional; absolute coordinates, no initial-context or live World
    // access. Derivatives sample the same immutable function at every stencil.
    void evaluate(std::int64_t x, std::int64_t y, SpatialValues &output,
                  SpatialScratch *scratch = nullptr) const;
    [[nodiscard]] SpatialValue sample(const std::string &id, std::int64_t x, std::int64_t y,
                                      SpatialScratch *scratch = nullptr) const;
    ~SpatialGraph();

  private:
    struct Impl;
    explicit SpatialGraph(std::unique_ptr<Impl>);
    std::unique_ptr<Impl> impl_;
};

} // namespace cybersand::generation
