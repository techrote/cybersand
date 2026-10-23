#pragma once

#include "cybersand/world_generation.hpp"

#include <array>
#include <cstdint>
#include <memory>
#include <optional>
#include <string>
#include <vector>

// GEN-005: immutable semantic projections. This API has no World pointer,
// simulation clock, renderer, camera, actor object or mutable registration owner.
namespace cybersand::generation {

inline constexpr std::uint32_t kPlaneSchemaVersion = 1;
inline constexpr std::uint32_t kPlaneAlgorithmVersion = 1;
enum class Plane : std::uint8_t { Play, Scripted, Effects, Background };
enum class ProjectionShape : std::uint8_t { Fill, Shell, Omit, Native };
enum class LinkFamily : std::uint8_t { Explosion, Vent, Window, Pipe, Waterfall, Machinery };
enum class LinkClass : std::uint8_t { Static, Presentation, Runtime };
enum class FixtureMode : std::uint8_t { Source, Drain, Setup };

struct PlanePolicy {
    Plane plane = Plane::Play;
    Material material = Material::Empty; // explicit uncovered-space composition
    bool base_generator = false; // permitted only on play
    std::uint32_t rate = 0;      // owner clock metadata; background must be zero
    std::string omission;      // why uncovered space is intentionally empty
};
struct PlaneProjectionTemplate {
    std::string id, rule; // rule ID, or "$region" for canonical regions
    Plane plane = Plane::Scripted;
    std::string geometry = "feature"; // feature rectangle or "routes"
    std::string route_type;           // routes: passage/service/liquid
    std::optional<RectI64> bounds;     // feature-relative override; omitted = feature box
    ProjectionShape shape = ProjectionShape::Shell;
    std::optional<Material> material, interior; // absent inherits canonical material intent
    std::uint32_t wall_thickness = 1;
    std::uint32_t route_width = 0; // 0 inherits the canonical route width
    double density = 1;           // deterministic coordinate/feature mask, never camera-relative
    std::string application, exclusion; // shared immutable normalized/boolean spatial:<id> masks
    int priority = 0;
    std::string omission;         // required for Omit
};
struct PlaneFixtureTemplate {
    std::string id, rule;
    Plane plane = Plane::Scripted;
    RectI64 bounds; // relative to the feature, strictly contained
    Material material = Material::Water;
    FixtureMode mode = FixtureMode::Source;
    std::uint64_t first_tick = 1, period = 1, repeat = 1;
    std::uint64_t cleanup_tick = 0; // 0 = finite feed expires; positive = clear its source box
    std::vector<Material> expected_products; // diagnostic expectations, never painted products
};
struct PlaneLinkTemplate {
    std::string id, rule, target_rule; // empty target_rule selects the same feature
    std::uint32_t target_slot = 0;    // named rule slot in the source canonical region
    LinkFamily family = LinkFamily::Machinery;
    LinkClass classification = LinkClass::Static;
    Plane source_plane = Plane::Play, target_plane = Plane::Scripted;
    std::string effect = "correspondence";
    RectI64 bounds; // relative to target feature; permitted effect/composition zone
    Material material = Material::Empty;
    std::uint32_t radius = 0;
    std::uint32_t max_events_per_tick = 1;
    std::string fixture; // optional target-owned fixture template ID for declarative correspondence
};
struct PlaneActorTemplate {
    std::string id, rule, model;
    std::string producer = "policy"; // existing play actor producer, never a worker-owned actor
    Plane plane = Plane::Play;
    std::int64_t x = 0, y = 0; // integer placement point relative to the feature
};
struct PlaneLimits {
    std::size_t max_templates = 128, max_projections = 8192;
    std::size_t max_fixtures = 1024, max_links = 2048;
    std::size_t max_actors = 8;
    std::uint64_t max_cells_per_plane = 1'048'576;
    std::uint64_t max_operations = 250'000'000;
    std::size_t max_prepared_bytes = 16 * 1024 * 1024;
    std::size_t max_publication_bytes = 64 * 1024 * 1024;
    std::size_t max_diagnostic_bytes = 4 * 1024 * 1024;
    std::uint32_t max_events_per_tick = 256;
    std::uint64_t max_fixture_cell_writes = 4'194'304;
};
struct PlaneDefinition {
    std::uint32_t schema = kPlaneSchemaVersion;
    std::string id = "semantic-place";
    std::uint64_t revision = 1;
    std::array<PlanePolicy, 4> policies{{
        {Plane::Play, Material::Empty, true, 30, "native play proposal"},
        {Plane::Scripted, Material::Empty, false, 20, "open service void"},
        {Plane::Effects, Material::Empty, false, 15, "clear atmosphere"},
        {Plane::Background, Material::Empty, false, 0, "distant open sky"}}};
    std::vector<PlaneProjectionTemplate> projections;
    std::vector<PlaneFixtureTemplate> fixtures;
    std::vector<PlaneLinkTemplate> links;
    std::vector<PlaneActorTemplate> actors;
    PlaneLimits limits;
};
struct PlaneProjection {
    std::string id, adapter, feature_id, geometry_ref, omission, application, exclusion;
    Plane plane = Plane::Play;
    ProjectionShape shape = ProjectionShape::Fill;
    RectI64 bounds;
    spatial::RegionId owner;
    std::uint64_t revision{}, seed{}, fields_fingerprint{};
    Material material = Material::Empty, interior = Material::Empty;
    std::uint32_t wall_thickness = 0, route_width = 0;
    std::vector<spatial::Point> points; // canonical route geometry when not empty
    double density = 1;
    int priority = 0;
};
struct PlaneFixture {
    std::string id, adapter, feature_id, clock, lifecycle = "finite-owner-v1";
    Plane plane = Plane::Scripted;
    RectI64 bounds;
    spatial::RegionId owner;
    std::uint64_t revision{}, first_tick{}, period{}, repeat{}, cleanup_tick{};
    Material material = Material::Water;
    FixtureMode mode = FixtureMode::Source;
    std::vector<Material> expected_products;
};
struct PlaneLink {
    std::string id, adapter, source_feature, target_feature, effect, fixture_id;
    std::string lifecycle = "bundle-generation-v1";
    LinkFamily family = LinkFamily::Machinery;
    LinkClass classification = LinkClass::Static;
    Plane source_plane = Plane::Play, target_plane = Plane::Scripted;
    RectI64 bounds;
    spatial::RegionId owner;
    std::uint64_t revision{};
    Material material = Material::Empty;
    std::uint32_t radius{}, max_events_per_tick{};
};
struct PlaneActor {
    std::string id, adapter, feature_id, model, producer;
    std::string lifecycle = "play-owner-v1";
    Plane plane = Plane::Play;
    std::int64_t x = 0, y = 0;
    spatial::RegionId owner;
    std::uint64_t revision{};
};
struct PlaneStages {
    Material policy = Material::Empty, base = Material::Empty, projections = Material::Empty, final = Material::Empty;
    GenerationStages source;
    bool has_source = false;
    std::size_t projection_checks = 0; // actual inspected index entries, not elapsed time
};
struct PlaneCellProvenance {
    Plane plane = Plane::Play;
    std::int64_t x{}, y{};
    Material material = Material::Empty;
    std::vector<std::string> features, projections, fixtures, links, actors;
    std::optional<CellProvenance> source;
    PlaneStages stages;
    std::vector<EvaluationDecision> decisions;
    std::vector<MaterialContribution> contributions;
    bool truncated = false;
    std::size_t omitted_entries = 0;
    std::uint64_t proposal_hash = 0;
};
struct PlaneResult {
    ResultState state = ResultState::Pending;
    RectI64 bounds;
    std::uint64_t revision{}, fingerprint{}, receipt_hash{}, operations{};
    std::array<std::uint64_t, 4> content_hashes{};
    std::array<std::vector<Material>, 4> cells;
    // Registration ownership is canonical region ownership, never request order.
    // Tiled requests contain only records whose anchor cell lies in the tile;
    // full-region generation contains each registration exactly once.
    std::vector<std::string> fixture_ids, link_ids, actor_ids;
    std::string error;
};

class PlaneGenerationJob;
class PlanePlan final : public std::enable_shared_from_this<PlanePlan> {
public:
    [[nodiscard]] static std::shared_ptr<const PlanePlan> compile(
        std::shared_ptr<const Generator>, PlaneDefinition);
    [[nodiscard]] const PlaneDefinition& definition() const noexcept;
    [[nodiscard]] const Generator& generator() const noexcept;
    [[nodiscard]] const std::vector<PlaneProjection>& projections() const noexcept;
    [[nodiscard]] const std::vector<PlaneFixture>& fixtures() const noexcept;
    [[nodiscard]] const std::vector<PlaneLink>& links() const noexcept;
    [[nodiscard]] const std::vector<PlaneActor>& actors() const noexcept;
    [[nodiscard]] RectI64 bounds() const noexcept;
    [[nodiscard]] std::uint64_t fingerprint() const noexcept;
    [[nodiscard]] std::uint64_t preparation_work() const noexcept;
    [[nodiscard]] std::uint64_t operations_per_cell() const noexcept;
    [[nodiscard]] GenerationIndexInfo index_info() const noexcept;
    [[nodiscard]] std::size_t storage_bytes() const noexcept;
    [[nodiscard]] Material sample(Plane, std::int64_t, std::int64_t) const;
    [[nodiscard]] PlaneCellProvenance explain(Plane, std::int64_t, std::int64_t) const;
    [[nodiscard]] PlaneStages stages(Plane, std::int64_t, std::int64_t) const;
    [[nodiscard]] std::unique_ptr<PlaneGenerationJob> begin(RectI64) const;
    [[nodiscard]] PlaneResult generate(RectI64) const;
    [[nodiscard]] bool accepts(const PlaneResult&) const noexcept;
    ~PlanePlan();
private:
    struct Impl;
    explicit PlanePlan(std::unique_ptr<Impl>);
    std::unique_ptr<Impl> impl_;
    friend class PlaneGenerationJob;
};
class PlaneGenerationJob final {
public:
    ~PlaneGenerationJob();
    [[nodiscard]] ResultState advance(std::size_t cell_budget);
    void cancel() noexcept;
    [[nodiscard]] ResultState state() const noexcept;
    [[nodiscard]] std::size_t completed_cells() const noexcept;
    [[nodiscard]] const PlaneResult& result() const;
private:
    PlaneGenerationJob(std::shared_ptr<const PlanePlan>, RectI64);
    std::shared_ptr<const PlanePlan> plan_;
    PlaneResult result_;
    std::size_t cursor_{};
    friend class PlanePlan;
};

[[nodiscard]] const char* plane_name(Plane) noexcept;
[[nodiscard]] std::optional<Plane> parse_plane(const std::string&) noexcept;
[[nodiscard]] const char* projection_shape_name(ProjectionShape) noexcept;
[[nodiscard]] std::optional<ProjectionShape> parse_projection_shape(const std::string&) noexcept;
[[nodiscard]] const char* link_family_name(LinkFamily) noexcept;
[[nodiscard]] std::optional<LinkFamily> parse_link_family(const std::string&) noexcept;
[[nodiscard]] const char* link_class_name(LinkClass) noexcept;
[[nodiscard]] std::optional<LinkClass> parse_link_class(const std::string&) noexcept;
[[nodiscard]] const char* fixture_mode_name(FixtureMode) noexcept;
[[nodiscard]] std::optional<FixtureMode> parse_fixture_mode(const std::string&) noexcept;

} // namespace cybersand::generation
