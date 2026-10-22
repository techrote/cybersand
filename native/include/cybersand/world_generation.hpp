#pragma once

#include "cybersand/world.hpp"
#include "cybersand/generation_fields.hpp"
#include "cybersand/generation_typed_fields.hpp"
#include "cybersand/generation_grammar.hpp"

#include <cstdint>
#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <vector>

// Opt-in CPU generation. No World pointer, Godot call, clock, mutable shared RNG,
// neighbor request, or simulation tick is reachable through the module context.
namespace cybersand::generation {

inline constexpr std::uint32_t kSchemaVersion = 1;
inline constexpr std::uint32_t kAlgorithmVersion = 2;
inline constexpr std::uint32_t kTypedSchemaVersion = 2;
inline constexpr std::uint32_t kTypedAlgorithmVersion = 3;
inline constexpr std::uint32_t kHierarchySchemaVersion = 3;
inline constexpr std::uint32_t kHierarchyAlgorithmVersion = 4;
// Brush geometry uses doubles; reject coordinates beyond the exact integer range
// deliberately rather than silently aliasing distant chunks.
inline constexpr std::int64_t kCoordinateLimit = (INT64_C(1) << 40);

enum class Candidate : std::uint8_t { Strata, FlowNetwork, DistrictGrammar };
enum class Parameter : std::uint8_t {
    SurfaceY, Relief, FeatureScale, CaveThreshold, StrataPeriod, Warp,
    CorridorWidth, DistrictSize, RoomSize, WallThickness, Detail, FluidLevel
};

struct Parameters {
    double surface_y = 96.0;
    double relief = 48.0;
    double feature_scale = 96.0;
    double cave_threshold = 0.60;
    double strata_period = 18.0;
    double warp = 12.0;
    double corridor_width = 7.0;
    double district_size = 256.0;
    double room_size = 48.0;
    double wall_thickness = 3.0;
    double detail = 0.32;
    double fluid_level = 224.0;
};

struct ParameterEdit { Parameter parameter{}; double value{}; };
struct Point { double x{}, y{}; };

struct Palette {
    Material rock = Material::GraniteBlock;
    Material surface = Material::PackedEarth;
    Material accent = Material::Copper;
    Material fluid = Material::Water;
};

struct Theme {
    std::string id;
    std::vector<std::string> parents;
    bool concrete = false; // groups expand to their concrete descendants
    Palette palette;
    std::vector<ParameterEdit> parameters;
};

struct ThemeWeight { std::string id; double weight = 1.0; };
struct ThemeSelection {
    std::vector<ThemeWeight> weights{{"natural", 1.0}};
    std::vector<std::string> exclude;
};

struct BrushStroke {
    std::string id;
    std::vector<Point> points;
    double radius = 96.0;
    double strength = 1.0;
    double falloff = 1.0;
    int priority = 0;
    // An empty weights list changes only the supplied parameters.
    ThemeSelection themes{{}, {}};
    std::vector<ParameterEdit> parameters;
};

struct GuidePath {
    std::string id;
    std::vector<Point> points;
    double width = 10.0;
    Material material = Material::Empty;
    int priority = 0;
};

struct HardOverride {
    std::string id;
    RectI64 bounds;
    std::optional<Material> material;
    std::optional<Candidate> candidate;
    std::vector<ParameterEdit> parameters;
    int priority = 0;
};

struct ModuleInstance {
    std::string id; // unique instance identity
    std::string module; // registry factory identity
    std::uint32_t version = 1;
    RectI64 bounds;
    std::map<std::string, double> parameters;
    std::vector<std::string> after; // explicit instance dependencies
    int priority = 0;
    std::string application{}; // named field; empty is one
    std::string exclusion{}; // named field; empty is zero
    double strength = 1.0;
};

enum class ContextPredicate : std::uint8_t { Any, Empty, Occupied, Solid, Fluid, Material };

struct AggregateComponent { Material material = Material::GraniteBlock; double weight = 1.0; };
// An authoring recipe which emits ordinary material IDs, not a physics material.
struct Aggregate {
    std::string id;
    std::vector<AggregateComponent> components;
    std::int32_t grain_size = 4;
    std::string variation; // optional normalized selector field; not an area quota
};

struct ParameterMapping {
    Parameter parameter{};
    std::string field;
    double low{}, high{}; // both are valid spatial values; descending maps allowed
};

struct Modifier {
    std::string id;
    int priority = 0;
    std::optional<RectI64> bounds; // exclusive with points; absent means global
    std::vector<Point> points;
    double radius = 96.0;
    double falloff = 1.0;
    double strength = 1.0;
    std::string application;
    std::string exclusion;
    ContextPredicate context = ContextPredicate::Any;
    std::optional<Material> context_material;
    ThemeSelection themes{{}, {}};
    std::vector<ParameterEdit> parameters;
    std::vector<ParameterMapping> mappings;
    std::optional<Material> material; // Empty carves; exclusive with aggregate
    std::string aggregate;
};

struct Limits {
    std::size_t max_themes = 64;
    std::size_t max_strokes = 64;
    std::size_t max_points_per_path = 128;
    std::size_t max_paths = 64;
    std::size_t max_overrides = 64;
    std::size_t max_modules = 32;
    std::size_t max_fields = 64;
    std::size_t max_aggregates = 32;
    std::size_t max_modifiers = 64;
    std::uint64_t max_operations_per_chunk = 64'000'000;
};

struct Recipe {
    std::uint32_t schema = kSchemaVersion;
    std::uint64_t seed = 1;
    std::uint64_t revision = 1;
    std::int32_t chunk_size = 128;
    Candidate candidate = Candidate::Strata;
    Parameters parameters;
    std::vector<Theme> catalogue; // empty selects the built-in catalogue
    ThemeSelection themes;
    std::vector<BrushStroke> strokes;
    std::vector<GuidePath> paths;
    std::vector<HardOverride> overrides;
    std::vector<ModuleInstance> modules;
    std::vector<FieldNode> fields;
    SpatialDefinition spatial;
    SpatialLimits spatial_limits;
    GrammarDefinition grammar;
    std::vector<Aggregate> aggregates;
    std::vector<Modifier> modifiers;
    Limits limits;
};

struct ModuleContext {
    std::int64_t x{}, y{};
    std::uint64_t seed{};
    const Parameters& parameters;
    const Palette& palette;
};

// A prepared sampler is owned by the immutable compiled generator and must be
// const/thread-safe. It may only return one material for the current cell. The
// engine clips its domain, validates output and charges the declared logical
// work cost. C++ callbacks are trusted cooperative code, not sandboxed plugins.
class FeatureSampler {
public:
    virtual ~FeatureSampler() = default;
    [[nodiscard]] virtual std::optional<Material> sample(
        const ModuleContext&, Material previous) const = 0;
};

struct ModuleFactory {
    std::string id;
    std::uint32_t version = 1;
    std::uint32_t operations_per_cell = 16;
    std::function<std::shared_ptr<const FeatureSampler>(
        const ModuleInstance&, std::uint64_t)> prepare;
};

class ModuleRegistry {
public:
    void add(ModuleFactory factory); // duplicates and invalid declarations throw
    [[nodiscard]] const ModuleFactory& find(const std::string&, std::uint32_t) const;
    [[nodiscard]] static ModuleRegistry builtins();
private:
    std::vector<ModuleFactory> factories_;
};

enum class ResultState : std::uint8_t { Pending, Ready, Cancelled, Failed };
struct ChunkResult {
    ResultState state = ResultState::Pending;
    ChunkCoord chunk;
    std::int32_t chunk_size = 0;
    std::uint64_t revision = 0;
    std::uint64_t fingerprint = 0;
    std::uint64_t content_hash = 0;
    std::uint64_t receipt_hash = 0; // binds payload to coordinates and recipe
    std::uint64_t operations = 0;
    std::string error;
    std::vector<Material> cells; // never published before Ready
    std::string diagnostic; // empty or field:<id>, modifier:<id>, module:<id>
    std::vector<float> diagnostics; // optional [0,1] channel, paced with cells
    // Stage diagnostics retain final cells and a separate actual intermediate payload.
    std::vector<Material> stage_cells;
    SpatialInfo diagnostic_info;
    std::vector<SpatialValue> typed_diagnostics; // exclusive with legacy diagnostics
};

struct MaterialContribution {
    std::string stage, id;
    Material before{}, after{};
    double influence = 1;
};
inline constexpr std::size_t kMaxTraceEntries = 256;
enum class GenerationStage : std::uint8_t { Candidate, GuidedCandidate, Grammar, Modifiers, Connectivity, Final };
inline constexpr std::size_t kGenerationStageCount = 6;
struct GenerationStages {
    std::array<Material, kGenerationStageCount> materials{};
    [[nodiscard]] Material at(GenerationStage stage) const noexcept { return materials[static_cast<std::size_t>(stage)]; }
};
struct EvaluationDecision {
    std::string stage, id, application, exclusion, predicate, detail;
    double application_value = 1, exclusion_value = 0, strength = 1, shape = 1, influence = 1, draw = 0;
    bool context_passed = true, draw_used = false, accepted = false;
};
struct AggregateSelection {
    std::string id, source;
    double selector = 0;
    Material material = Material::Empty;
    std::vector<AggregateComponent> components; // normalized realized-choice weights
};
struct CellProvenance {
    std::int64_t x{}, y{};
    Material material{}, initial_material{};
    Candidate initial_candidate = Candidate::Strata, effective_candidate = Candidate::Strata;
    Parameters initial_parameters, effective_parameters;
    FieldContext context;
    bool context_evaluated = false;
    std::uint64_t revision{}, fingerprint{}, proposal_hash{}, logical_cost{};
    bool truncated = false;
    std::size_t omitted_entries = 0;
    std::string accepted_feature_id;
    GenerationStages stages;
    std::vector<EvaluationDecision> decisions;
    std::vector<AggregateSelection> aggregates;
    std::vector<std::string> ancestry;
    std::vector<ConstraintReceipt> constraints;
    std::vector<MaterialContribution> contributions;
    std::vector<std::pair<std::string, double>> scalar_fields;
    std::vector<std::pair<std::string, SpatialValue>> typed_fields;
};
struct RouteOutcome {
    std::string id, detail;
    bool passed = false;
    std::uint64_t checked_centres = 0, blocked_centres = 0;
    std::int64_t first_block_x{}, first_block_y{};
};
struct SupportOutcome {
    std::string feature_id, constraint, detail;
    bool passed = false;
    std::uint64_t checked_cells = 0, missing_cells = 0;
    std::int64_t first_missing_x{}, first_missing_y{};
};
struct RouteValidation {
    bool passed = true;
    std::string profile = "floating-square-v1";
    std::uint32_t clearance = 1;
    std::uint64_t cells = 0, operations = 0;
    // Footprints at the finite window boundary are clipped to its shared
    // aperture. Independently planned opposite halves complete that aperture.
    bool boundary_apertures = true;
    std::vector<RouteOutcome> routes;
    // Separate final-cell qualification of semantic support requirements:
    // at least one static solid contact on each requested boundary side.
    // This is neither structural stability nor simulated gravity behavior.
    bool supports_passed = true;
    std::string support_profile = "static-solid-contact-v1";
    std::vector<SupportOutcome> supports;
};

class GenerationJob;
class Generator final : public std::enable_shared_from_this<Generator> {
public:
    // Validate/compile off the simulation tick. All invalid, ambiguous and
    // over-capacity inputs throw; callers retain the last valid generator.
    [[nodiscard]] static std::shared_ptr<const Generator> compile(
        Recipe recipe, const ModuleRegistry& registry = ModuleRegistry::builtins());
    [[nodiscard]] static std::vector<Theme> builtin_themes();
    [[nodiscard]] static std::vector<std::string> builtin_modules();
    [[nodiscard]] const Recipe& recipe() const noexcept;
    [[nodiscard]] const SpatialGraph& spatial_graph() const noexcept;
    [[nodiscard]] const GrammarPlan* semantic_plan() const noexcept;
    [[nodiscard]] const RouteValidation& validate_routes() const noexcept;
    [[nodiscard]] CellProvenance explain(std::int64_t x, std::int64_t y) const;
    [[nodiscard]] GenerationStages stages(std::int64_t x, std::int64_t y) const;
    [[nodiscard]] std::uint64_t fingerprint() const noexcept;
    // Conservative logical work charged by ordinary generation jobs per cell.
    [[nodiscard]] std::uint64_t operations_per_cell() const noexcept;
    [[nodiscard]] std::vector<ThemeWeight> theme_weights_at(std::int64_t x, std::int64_t y) const;
    [[nodiscard]] Material sample(std::int64_t x, std::int64_t y) const;
    [[nodiscard]] std::unique_ptr<GenerationJob> begin(ChunkCoord chunk, const std::string& diagnostic = {}) const;
    [[nodiscard]] ChunkResult generate(ChunkCoord chunk, const std::string& diagnostic = {}) const;
    [[nodiscard]] bool accepts(const ChunkResult& result) const noexcept;
    ~Generator();

private:
    struct Impl;
    explicit Generator(std::unique_ptr<Impl> impl);
    std::unique_ptr<Impl> impl_;
    friend class GenerationJob;
};

class GenerationJob final {
public:
    ~GenerationJob();
    GenerationJob(const GenerationJob&) = delete;
    GenerationJob& operator=(const GenerationJob&) = delete;
    // Zero is a no-op. Work is capped by cells and the recipe's logical cost
    // bound. No partial cells are returned on error/cancellation.
    [[nodiscard]] ResultState advance(std::size_t cell_budget);
    void cancel() noexcept;
    [[nodiscard]] ResultState state() const noexcept;
    [[nodiscard]] std::size_t completed_cells() const noexcept;
    [[nodiscard]] const ChunkResult& result() const; // Pending throws
private:
    GenerationJob(std::shared_ptr<const Generator>, ChunkCoord, const std::string&);
    std::shared_ptr<const Generator> generator_;
    ChunkResult result_;
    std::size_t cursor_ = 0;
    std::int64_t origin_x_ = 0, origin_y_ = 0;
    unsigned diagnostic_kind_ = 0;
    std::size_t diagnostic_index_ = 0;
    SpatialScratch spatial_scratch_;
    friend class Generator;
};

[[nodiscard]] const char* generation_stage_name(GenerationStage) noexcept;
[[nodiscard]] std::optional<GenerationStage> parse_generation_stage(const std::string&) noexcept;

[[nodiscard]] const char* candidate_name(Candidate candidate) noexcept;
[[nodiscard]] std::optional<Candidate> parse_candidate(const std::string& name) noexcept;
[[nodiscard]] const char* parameter_name(Parameter parameter) noexcept;
[[nodiscard]] std::optional<Parameter> parse_parameter(const std::string& name) noexcept;
[[nodiscard]] const char* context_predicate_name(ContextPredicate predicate) noexcept;
[[nodiscard]] std::optional<ContextPredicate> parse_context_predicate(const std::string& name) noexcept;

} // namespace cybersand::generation
