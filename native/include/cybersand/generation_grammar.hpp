#pragma once

#include "cybersand/world.hpp"
#include "cybersand/generation_typed_fields.hpp"

#include <cstdint>
#include <map>
#include <memory>
#include <optional>
#include <span>
#include <string>
#include <vector>

// GEN-004 owns immutable semantic planning, never mutable World/storage. The
// finite window is an explicit request, not part of a regional semantic ID.
namespace cybersand::generation {

inline constexpr std::uint32_t kGrammarSchemaVersion = 1;
inline constexpr std::uint32_t kGrammarAlgorithmVersion = 1;

enum class SemanticKind : std::uint8_t { Region, District, Complex, Room, Apparatus, Detail };
enum class GrammarCurve : std::uint8_t { Hilbert, Morton, Peano };
enum class SocketDirection : std::uint8_t { West, East, North, South };
enum class GrammarFallback : std::uint8_t { Reject, Omit };

struct GrammarTheme { std::string id; double weight = 1; };
struct GrammarCandidate {
    std::string id;
    RectI64 bounds; // half-open integer coordinates relative to the parent
    // A finite curve orders candidates independently of declaration order.
    std::uint32_t order_x{}, order_y{};
};
struct GrammarSocket {
    std::string id;
    std::string type = "passage";
    SocketDirection direction = SocketDirection::West;
    std::int64_t offset = 0; // along the declared feature edge, in cells
    std::uint32_t width = 5; // odd integer aperture
    bool required = true;
    bool attach_to_route = true; // explicit orthogonal connector to primary route
};
struct GrammarConstraints {
    bool intersects_route = false;
    double minimum_separation = 0; // between sibling feature boxes, in cells
    bool floor = false, ceiling = false, wall = false;
    bool open_volume = false; // siblings may not overlap (ancestors are excluded)
    std::string service; // named route type: "service" or "liquid"
    std::vector<std::string> required_neighbors; // sibling tags, final-plan check
    std::vector<std::string> forbidden_neighbors;
    double neighbor_distance = 32;
    std::string exclusive_family; // at most one sibling in this family
    std::uint32_t minimum_sockets = 0;
    std::uint32_t maximum_sockets = 16;
    bool connected = false; // at least one compatible attached passage socket
    double occupancy_min = 0, occupancy_max = 1; // sum of this rule's sibling areas / parent area
};
struct GrammarPreference {
    std::string id;
    // "route", "theme_boundary", "floor", "ceiling", "wall", "curve_density"
    std::string kind = "route";
    double weight = 1;
    std::vector<std::string> themes; // theme_boundary requires two declared theme IDs
};
struct GrammarRule {
    std::string id;
    SemanticKind kind = SemanticKind::Room;
    std::uint32_t count = 1; // exact multiplicity per parent; stable numeric slots
    int priority = 0;       // higher priority first; lexical rule ID breaks ties
    std::vector<std::string> tags;
    std::vector<GrammarTheme> themes;
    std::map<std::string, SpatialValue> parameters;
    std::vector<Material> allowed_materials;
    std::vector<GrammarCandidate> candidates;
    std::vector<std::string> children; // rule references, acyclic
    std::vector<GrammarSocket> sockets;
    GrammarConstraints constraints;
    std::vector<GrammarPreference> preferences;
    GrammarFallback fallback = GrammarFallback::Reject; // Omit records unsatisfied requirements
    std::optional<Material> material = Material::Concrete;
    std::optional<Material> interior = Material::Empty;
    std::uint32_t wall_thickness = 2;
    std::string aggregate; // optional existing material aggregate, integration-owned
    std::string application, exclusion; // existing normalized field references
};
struct GrammarLimits {
    std::size_t max_regions = 16, max_rules = 64, max_depth = 8;
    std::size_t max_children = 32, max_candidates = 64, max_features = 2048;
    std::size_t max_sockets = 4096, max_routes = 4096;
    std::uint64_t max_work = 16'000'000;
    std::size_t max_prepared_bytes = 16 * 1024 * 1024;
    std::uint64_t max_raster_cells = 4'194'304;
    std::uint64_t max_raster_operations = 1'000'000'000;
};
struct GrammarDefinition {
    std::uint32_t schema = kGrammarSchemaVersion;
    std::string id = "world";
    // Up to 16 finite, world-zero-anchored regions. Window is in region units.
    RectI64 region_window{0, 0, 1, 1};
    std::int32_t region_size = 256;
    std::vector<std::string> roots;
    std::vector<GrammarRule> rules;
    GrammarCurve curve = GrammarCurve::Hilbert;
    std::uint32_t curve_order = 2;
    std::uint32_t route_width = 7;
    std::uint32_t clearance = 3; // declared square floating clearance, odd cells
    bool secondary_loop = true;
    bool service_trunk = true;
    bool curve_services = false; // <=16 finite curve sites joined by explicit orthogonal utility edges
    bool liquid_trunk = false;
    Material service_material = Material::Copper;
    Material liquid_material = Material::Water;
    // Optional GEN-003 discrete assignment for region theme selection. Its
    // immutable finite tile repeats; use wrap constraints for edge adjacency.
    std::optional<spatial::RegionAssignment> district_assignment;
    spatial::RegionSolverLimits assignment_limits;
    std::map<std::uint64_t, std::vector<GrammarTheme>> district_themes;
    std::map<std::string, std::string> geometry_exports; // alias -> exact semantic route/feature ID; <=16
    GrammarLimits limits;
    [[nodiscard]] bool empty() const noexcept { return roots.empty() && rules.empty(); }
};
struct ConstraintReceipt {
    std::string feature_id, rule_id, constraint, detail;
    bool passed = false, fallback = false;
};
struct SemanticFeature {
    std::string id, parent, rule_id, candidate_id;
    SemanticKind kind = SemanticKind::Region;
    RectI64 bounds;
    spatial::RegionId owner;
    std::uint64_t seed{}, revision{}, order{};
    int priority = 0;
    std::vector<std::string> children, tags;
    std::vector<GrammarTheme> themes;
    std::map<std::string, SpatialValue> parameters;
    std::vector<Material> allowed_materials;
    std::vector<std::string> sockets;
    GrammarConstraints constraints;
    std::optional<Material> material, interior;
    std::uint32_t wall_thickness = 0;
    std::string aggregate, application, exclusion;
};
struct SemanticSocket {
    std::string id, feature_id, type, matched;
    spatial::RegionId owner;
    std::int64_t x{}, y{};
    SocketDirection direction = SocketDirection::West;
    std::uint32_t width{};
    bool required = false, shared = false;
};
struct SemanticRoute {
    std::string id, type, from_socket, to_socket;
    spatial::RegionId owner;
    std::vector<spatial::Point> points; // explicit rectilinear geometry
    std::uint32_t width{};
    bool required = false;
    Material material = Material::Empty;
};
struct GenerationIndexInfo {
    std::int64_t bin_size = 64;
    std::size_t bins = 0, entries = 0, maximum_candidates = 0;
};
struct SemanticProposal {
    std::optional<Material> material;
    const SemanticFeature* feature = nullptr;
    const SemanticRoute* route = nullptr;
    bool interior = false;
};

class GrammarPlan final {
public:
    [[nodiscard]] static std::shared_ptr<const GrammarPlan> compile(GrammarDefinition, std::uint64_t seed);
    // Complete executable native example shared by focused tests and clients.
    [[nodiscard]] static GrammarDefinition example();
    [[nodiscard]] const GrammarDefinition& definition() const noexcept;
    [[nodiscard]] const std::vector<SemanticFeature>& features() const noexcept;
    [[nodiscard]] const std::vector<SemanticSocket>& sockets() const noexcept;
    [[nodiscard]] const std::vector<SemanticRoute>& routes() const noexcept;
    [[nodiscard]] const std::vector<ConstraintReceipt>& receipts() const noexcept;
    [[nodiscard]] RectI64 bounds() const noexcept;
    [[nodiscard]] std::uint64_t fingerprint() const noexcept;
    [[nodiscard]] std::uint64_t preparation_work() const noexcept;
    [[nodiscard]] std::uint64_t operations_per_sample() const noexcept;
    [[nodiscard]] GenerationIndexInfo index_info() const noexcept;
    [[nodiscard]] std::size_t storage_bytes() const noexcept;
    [[nodiscard]] const SemanticFeature* feature(const std::string& id) const noexcept;
    [[nodiscard]] std::vector<const SemanticFeature*> query(RectI64 bounds) const;
    [[nodiscard]] std::vector<std::string> ancestry(const std::string& id) const;
    [[nodiscard]] SemanticProposal proposal(std::int64_t x, std::int64_t y) const noexcept;
    // Optional trusted, bounded eligibility over immutable caller values.
    // The index addresses features(); rejected children reveal eligible parents.
    // Callback cost belongs to the integrating caller's raster work bound.
    // No per-cell vector or function-object allocation is performed. Callback
    // exceptions propagate so the generation job can fail transactionally.
    using FeatureEligibility = bool (*)(std::size_t, const SemanticFeature&, const void*);
    [[nodiscard]] SemanticProposal proposal(std::int64_t x, std::int64_t y,
        FeatureEligibility eligible, const void* context) const;
    [[nodiscard]] const SemanticRoute* route_at(std::int64_t x, std::int64_t y) const noexcept;
    // <=16 explicitly named immutable route polylines or closed feature boxes.
    // Independent geometries are never concatenated into artificial segments.
    [[nodiscard]] std::vector<SpatialGeometry> geometry_inputs() const;
    ~GrammarPlan();
private:
    struct Impl;
    explicit GrammarPlan(std::unique_ptr<Impl>);
    std::unique_ptr<Impl> impl_;
};
[[nodiscard]] const char* semantic_kind_name(SemanticKind) noexcept;
[[nodiscard]] std::optional<SemanticKind> parse_semantic_kind(const std::string&) noexcept;
[[nodiscard]] const char* grammar_curve_name(GrammarCurve) noexcept;
[[nodiscard]] std::optional<GrammarCurve> parse_grammar_curve(const std::string&) noexcept;
[[nodiscard]] const char* socket_direction_name(SocketDirection) noexcept;
[[nodiscard]] std::optional<SocketDirection> parse_socket_direction(const std::string&) noexcept;

} // namespace cybersand::generation
