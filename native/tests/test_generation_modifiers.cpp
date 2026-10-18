#include "cybersand/world_generation.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <functional>
#include <future>
#include <iostream>
#include <limits>
#include <memory>
#include <set>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace {
using cybersand::ChunkCoord;
using cybersand::Material;
using cybersand::RectI64;
using namespace cybersand::generation;

void require(bool value, const char* message) {
    if (!value) throw std::runtime_error(message);
}
template<class Action> void rejects(Action&& action, const char* message) {
    bool rejected = false;
    try { action(); } catch (const std::exception&) { rejected = true; }
    require(rejected, message);
}
void near(float actual, double expected, const char* message) {
    require(std::isfinite(actual) && std::abs(static_cast<double>(actual) - expected) <= 1e-7, message);
}
FieldNode field(std::string id, FieldKind kind,
                std::map<std::string, double> parameters = {},
                std::vector<std::string> inputs = {}) {
    FieldNode result;
    result.id = std::move(id); result.kind = kind;
    result.parameters = std::move(parameters); result.inputs = std::move(inputs);
    return result;
}
FieldNode constant(std::string id, double value) {
    return field(std::move(id), FieldKind::Constant, {{"value", value}});
}
FieldNode context_field(std::string id, std::string channel, double low = 0, double high = 1) {
    auto result = field(std::move(id), FieldKind::Context, {{"low", low}, {"high", high}});
    result.context = std::move(channel);
    return result;
}
Modifier paint(std::string id, Material material) {
    Modifier result; result.id = std::move(id); result.material = material; return result;
}
Recipe flat_recipe(Material material = Material::GraniteBlock) {
    Recipe recipe;
    recipe.chunk_size = 32;
    recipe.seed = 927541;
    recipe.parameters.surface_y = -1000;
    recipe.parameters.relief = 0;
    recipe.parameters.cave_threshold = 1;
    recipe.parameters.detail = 0;
    recipe.catalogue = {{"base", {}, true, {material, material, material, material}, {}}};
    recipe.themes.weights = {{"base", 1}};
    return recipe;
}
Material cell(const ChunkResult& result, std::int32_t x, std::int32_t y) {
    return result.cells.at(static_cast<std::size_t>(y) * static_cast<std::size_t>(result.chunk_size) +
                           static_cast<std::size_t>(x));
}
float diagnostic(const ChunkResult& result, std::int32_t x, std::int32_t y) {
    return result.diagnostics.at(static_cast<std::size_t>(y) * static_cast<std::size_t>(result.chunk_size) +
                                 static_cast<std::size_t>(x));
}
void ready(const ChunkResult& result) {
    require(result.state == ResultState::Ready &&
                result.cells.size() == static_cast<std::size_t>(result.chunk_size) * static_cast<std::size_t>(result.chunk_size),
            "valid recipe produces a complete owned chunk");
}
void all_material(const ChunkResult& result, Material material, const char* message) {
    ready(result);
    require(std::all_of(result.cells.begin(), result.cells.end(), [&](Material m) { return m == material; }), message);
}
class Sampler final : public FeatureSampler {
public:
    using Callback = std::function<std::optional<Material>(const ModuleContext&, Material)>;
    explicit Sampler(Callback callback) : callback_(std::move(callback)) {}
    std::optional<Material> sample(const ModuleContext& context, Material previous) const override {
        return callback_(context, previous);
    }
private:
    Callback callback_;
};
void add_sampler(ModuleRegistry& registry, std::string id, Sampler::Callback callback, std::uint32_t cost = 1) {
    ModuleFactory factory;
    factory.id = std::move(id); factory.operations_per_cell = cost;
    factory.prepare = [callback = std::move(callback)](const ModuleInstance&, std::uint64_t) {
        return std::make_shared<Sampler>(callback);
    };
    registry.add(std::move(factory));
}
ModuleInstance module(std::string id, std::string factory, RectI64 bounds) {
    ModuleInstance result;
    result.id = std::move(id); result.module = std::move(factory); result.bounds = bounds;
    return result;
}

Recipe legacy_recipe(Candidate candidate) {
    // This recipe is the exact decorated_recipe fixture from GEN-001 commit
    // 54d455ca3157ecc3dbf9be2be2a5778567ec3311, test_world_generation.cpp.
    Recipe recipe;
    recipe.candidate = candidate;
    recipe.seed = UINT64_C(0x416cd08397ad0f23);
    recipe.themes.weights = {{"natural", 2.0}, {"built", 1.0}};
    BrushStroke stroke;
    stroke.id = "garden-ribbon";
    stroke.points = {{-100.0, -30.0}, {80.0, 100.0}};
    stroke.radius = 37.0; stroke.strength = 0.7;
    stroke.themes.weights = {{"garden", 1.0}};
    stroke.parameters = {{Parameter::Relief, 19.0}};
    recipe.strokes.push_back(stroke);
    GuidePath path;
    path.id = "crossing"; path.points = {{-120.0, -64.0}, {0.0, -64.0}, {0.0, 120.0}};
    path.width = 7.0; recipe.paths.push_back(path);
    HardOverride hard;
    hard.id = "glass-inlay"; hard.bounds = {-9, -15, 23, 21}; hard.material = Material::StainedGlass;
    recipe.overrides.push_back(hard);
    recipe.modules.push_back(module("vault", "vault", {-96, -96, 192, 192}));
    return recipe;
}

void retained_gen001_material_oracle() {
    // Captured by compiling the exact historical header/source/test fixture in
    // a separate /tmp include tree, never from GEN-002 output. These are material
    // hashes, not new fingerprint/receipt identities (algorithm version is 2).
    constexpr std::array<std::array<std::uint64_t, 4>, 3> expected{{
        {{UINT64_C(0x3aa8e7812c4c46aa), UINT64_C(0x674c7e8c09bb9d1f), UINT64_C(0x031bffb3dd2e81d2), UINT64_C(0xcba20a0a240408da)}},
        {{UINT64_C(0x3aa8e7812c4c46aa), UINT64_C(0x674c7e8c09bb9d1f), UINT64_C(0x6a09cee13286e2e4), UINT64_C(0xcba20a0a240408da)}},
        {{UINT64_C(0x6159bcb98c8db89e), UINT64_C(0x1ba53b231d1a3912), UINT64_C(0xea038ba7c39d3ce2), UINT64_C(0x0da1c9523b6a06ed)}}
    }};
    constexpr std::array candidates{Candidate::Strata, Candidate::FlowNetwork, Candidate::DistrictGrammar};
    constexpr std::array chunks{ChunkCoord{-1, -1}, ChunkCoord{0, -1}, ChunkCoord{-1, 0}, ChunkCoord{0, 0}};
    for (std::size_t c = 0; c < candidates.size(); ++c) {
        const auto generator = Generator::compile(legacy_recipe(candidates[c]));
        for (std::size_t i = 0; i < chunks.size(); ++i) {
            const auto result = generator->generate(chunks[i]); ready(result);
            require(result.content_hash == expected[c][i],
                    "field-free legacy recipe retains exact independently frozen GEN-001 material output");
        }
    }
}

void application_exclusion_and_shape() {
    auto recipe = flat_recipe();
    recipe.fields = {constant("application", .5), constant("exclusion", .25)};
    auto modifier = paint("paint", Material::Copper);
    modifier.application = "application"; modifier.exclusion = "exclusion"; modifier.strength = .8;
    recipe.modifiers.push_back(modifier);
    auto generator = Generator::compile(recipe);
    auto result = generator->generate({0, 0}, "modifier:paint"); ready(result);
    for (const auto value : result.diagnostics) near(value, .3, "application*(1-exclusion)*strength is the effective mask");
    require(generator->accepts(result), "normal paced influence diagnostic has a valid receipt");

    recipe.modifiers[0].points = {{0, 0}}; recipe.modifiers[0].radius = 10;
    generator = Generator::compile(recipe); result = generator->generate({0, 0}, "modifier:paint");
    near(diagnostic(result, 0, 0), .3, "brush centre preserves its effective strength");
    near(diagnostic(result, 5, 0), .15, "brush half-radius has analytic smoothstep influence");
    require(diagnostic(result, 10, 0) == 0, "modifier brush boundary is exactly excluded");

    recipe = flat_recipe(); recipe.fields = {constant("zero", 0), constant("one", 1)};
    recipe.modifiers = {paint("paint", Material::Water)};
    recipe.modifiers[0].application = "zero";
    all_material(Generator::compile(recipe)->generate({0, 0}), Material::GraniteBlock, "zero application is an exact no-op");
    recipe.modifiers[0].application = "one"; recipe.modifiers[0].exclusion = "one";
    all_material(Generator::compile(recipe)->generate({0, 0}), Material::GraniteBlock, "full exclusion wins over full application");
    recipe.modifiers[0].exclusion.clear(); recipe.modifiers[0].strength = 0;
    all_material(Generator::compile(recipe)->generate({0, 0}), Material::GraniteBlock, "zero strength is an exact no-op");
    recipe.modifiers[0].strength = 1;
    all_material(Generator::compile(recipe)->generate({0, 0}), Material::Water, "full influence emits its requested material exactly");
    recipe.modifiers[0].bounds = RectI64{-4, -4, 8, 8};
    generator = Generator::compile(recipe);
    for (std::int64_t y = -5; y <= 4; ++y) for (std::int64_t x = -5; x <= 4; ++x)
        require(generator->sample(x, y) == (x >= -4 && x < 4 && y >= -4 && y < 4 ? Material::Water : Material::GraniteBlock),
                "modifier bounds are half-open across signed chunk edges");
}

void immutable_initial_context() {
    auto recipe = flat_recipe();
    recipe.fields = {context_field("occupied", "occupied"), context_field("solid", "solid"),
                     context_field("fluid", "fluid"), field("granite", FieldKind::Material, {{"material", 40}})};
    auto carve = paint("a_carve", Material::Empty);
    auto fill = paint("z_fill_empty", Material::Water); fill.context = ContextPredicate::Empty;
    recipe.modifiers = {carve, fill};
    auto generator = Generator::compile(recipe);
    auto result = generator->generate({0, 0}, "modifier:z_fill_empty");
    all_material(result, Material::Empty, "an earlier carve cannot make an initially occupied cell match Empty context");
    require(std::all_of(result.diagnostics.begin(), result.diagnostics.end(), [](float v) { return v == 0; }),
            "modifier diagnostics read immutable initial context, not prior modifier output");
    auto hard = HardOverride{}; hard.id = "hard-glass"; hard.bounds = {0, 0, 32, 32}; hard.material = Material::Glass;
    recipe.overrides.push_back(hard);
    result = Generator::compile(recipe)->generate({0, 0}, "field:granite");
    all_material(result, Material::Glass, "hard material remains final even after context-aware edits");
    require(std::all_of(result.diagnostics.begin(), result.diagnostics.end(), [](float v) { return v == 1; }),
            "context material precedes hard material output");

    recipe = flat_recipe(Material::Empty);
    auto add = paint("a_add", Material::Copper);
    auto remove = paint("z_remove_occupied", Material::Empty); remove.context = ContextPredicate::Occupied;
    recipe.modifiers = {add, remove};
    all_material(Generator::compile(recipe)->generate({0, 0}), Material::Copper,
                 "an earlier fill cannot make initial Empty context become occupied");

    for (const auto material : {Material::Empty, Material::Sand, Material::Water, Material::GraniteBlock}) {
        recipe = flat_recipe(material);
        recipe.fields = {context_field("occupied", "occupied"), context_field("solid", "solid"), context_field("fluid", "fluid")};
        generator = Generator::compile(recipe);
        for (const auto& [name, expected] : std::array<std::pair<const char*, bool>, 3>{{
                {"occupied", material != Material::Empty}, {"solid", material == Material::GraniteBlock}, {"fluid", material == Material::Water}}}) {
            result = generator->generate({0, 0}, std::string("field:") + name);
            for (const auto v : result.diagnostics) require(v == static_cast<float>(expected),
                    "context distinguishes Empty, Powder, Liquid and MaterialState::Solid");
        }
    }
    recipe = flat_recipe(); recipe.parameters.surface_y = 0;
    recipe.fields = {context_field("depth", "depth", -16, 16), context_field("slope", "slope")};
    generator = Generator::compile(recipe);
    result = generator->generate({0, 0}, "field:depth");
    for (std::int32_t y = 0; y < 32; ++y) near(diagnostic(result, 7, y), std::clamp((y + 16.0) / 32.0, 0.0, 1.0),
            "flat pre-field surface yields analytic signed depth");
    result = generator->generate({0, 0}, "field:slope");
    require(std::all_of(result.diagnostics.begin(), result.diagnostics.end(), [](float v) { return v == 0; }),
            "flat pre-field surface has zero analytic slope");

    BrushStroke surface_brush;
    surface_brush.id = "legacy-surface"; surface_brush.points = {{0, 0}}; surface_brush.radius = 16;
    surface_brush.parameters = {{Parameter::SurfaceY, 40}};
    recipe.strokes = {surface_brush}; recipe.fields[1].parameters = {{"low", 0}, {"high", 8}};
    result = Generator::compile(recipe)->generate({0, 0}, "field:slope");
    const auto authored_height = [](double x) {
        const auto t = 1 - x / 16;
        return 40 * t * t * (3 - 2 * t);
    };
    near(diagnostic(result, 8, 0), std::abs(authored_height(9) - authored_height(7)) / 16,
         "slope includes the actual pre-field surface brush at neighboring coordinates");
    recipe.strokes.clear();
    result = Generator::compile(recipe)->generate({kCoordinateLimit / 32 - 1, 0}, "field:slope");
    ready(result);
    require(diagnostic(result, 31, 0) == 0,
            "one-sided surface derivative remains defined at the admitted coordinate edge");

    recipe = flat_recipe(); recipe.candidate = Candidate::FlowNetwork;
    recipe.parameters.district_size = 64; recipe.parameters.corridor_width = 2;
    recipe.chunk_size = 128;
    const auto narrow = Generator::compile(recipe)->generate({-1, -1});
    recipe.fields = {context_field("route", "route")};
    Modifier widen; widen.id = "widen"; widen.parameters = {{Parameter::CorridorWidth, 64}};
    recipe.modifiers = {widen};
    result = Generator::compile(recipe)->generate({-1, -1}, "field:route");
    std::size_t newly_empty = 0;
    for (std::size_t i = 0; i < result.cells.size(); ++i) {
        require(result.diagnostics[i] == (narrow.cells[i] == Material::Empty ? 1.0F : 0.0F),
                "route context uses initial topology and width before guidance");
        if (narrow.cells[i] != Material::Empty && result.cells[i] == Material::Empty) ++newly_empty;
    }
    require(newly_empty > 0, "route-context fixture actually changes final corridor width");
}

void theme_guidance_and_hard_authority() {
    auto recipe = flat_recipe();
    recipe.catalogue = {
        {"world", {}, false, {}, {}},
        {"a", {"world"}, true, {Material::GraniteBlock, Material::GraniteBlock, Material::GraniteBlock, Material::GraniteBlock}, {{Parameter::WallThickness, 1}}},
        {"b", {"world"}, true, {Material::Glass, Material::Glass, Material::Glass, Material::Glass}, {{Parameter::WallThickness, 4}}}
    };
    recipe.themes.weights = {{"a", 1}};
    Modifier select; select.id = "z_select"; select.themes.weights = {{"b", 1}};
    recipe.modifiers = {select};
    auto generator = Generator::compile(recipe);
    all_material(generator->generate({0, 0}), Material::Glass, "full masked theme guidance selects its eligible target palette");
    const auto weights = generator->theme_weights_at(0, 0);
    require(weights.size() == 1 && weights[0].id == "b" && weights[0].weight == 1,
            "effective theme query includes new modifier guidance");
    recipe.themes.exclude = {"b"};
    rejects([&] { (void)Generator::compile(recipe); }, "global exclusion cannot be reintroduced by modifier theme guidance");
    recipe.modifiers[0].themes.weights = {{"world", 1}};
    all_material(Generator::compile(recipe)->generate({0, 0}), Material::GraniteBlock,
                 "group guidance expands only globally eligible concrete themes");

    recipe.themes.exclude.clear(); recipe.modifiers[0] = select;
    Modifier parameters; parameters.id = "a_parameters"; parameters.parameters = {{Parameter::WallThickness, 2}};
    recipe.modifiers.push_back(parameters);
    ModuleRegistry registry;
    add_sampler(registry, "parameter_probe", [](const ModuleContext& context, Material) {
        if (context.parameters.wall_thickness == 2) return Material::Copper;
        if (context.parameters.wall_thickness == 5) return Material::Metal;
        return Material::Water;
    });
    recipe.modules = {module("probe", "parameter_probe", {0, 0, 32, 32})};
    all_material(Generator::compile(recipe, registry)->generate({0, 0}), Material::Copper,
                 "all theme blends precede direct parameter guidance even when modifier priorities interleave");
    HardOverride hard; hard.id = "hard-wall"; hard.bounds = {0, 0, 32, 32}; hard.parameters = {{Parameter::WallThickness, 5}};
    recipe.overrides.push_back(hard);
    all_material(Generator::compile(recipe, registry)->generate({0, 0}), Material::Metal,
                 "hard parameter assignment is reapplied after all soft guidance");

    recipe = flat_recipe(); recipe.fields = {constant("quarter", .25)};
    Modifier mapping; mapping.id = "mapped-surface";
    mapping.mappings = {{Parameter::SurfaceY, "quarter", 1000, -1000}};
    recipe.modifiers = {mapping}; generator = Generator::compile(recipe);
    require(generator->sample(0, 499) == Material::Empty && generator->sample(0, 500) == Material::GraniteBlock,
            "descending parameter mapping has an exact independent surface-height witness");
    recipe.modifiers[0].parameters = {{Parameter::Relief, 0}};
    recipe.overrides = {hard}; recipe.overrides[0].parameters = {{Parameter::SurfaceY, -1000}};
    all_material(Generator::compile(recipe)->generate({0, 0}), Material::GraniteBlock,
                 "hard parameters override mapped guidance inside their bounds");
}

void aggregate_realization_and_grains() {
    auto recipe = flat_recipe();
    Aggregate aggregate;
    aggregate.id = "rubble"; aggregate.grain_size = 7;
    aggregate.components = {{Material::Sand, 1}, {Material::GraniteBlock, 3}};
    recipe.aggregates = {aggregate};
    Modifier modifier; modifier.id = "rubble"; modifier.aggregate = "rubble"; recipe.modifiers = {modifier};
    auto generator = Generator::compile(recipe);
    const auto reference = generator->generate({-1, -1}); ready(reference);
    const auto recompiled = Generator::compile(generator->recipe());
    require(recompiled->fingerprint() == generator->fingerprint() &&
                recompiled->generate({-1, -1}).cells == reference.cells,
            "compiled aggregate recipe can be recompiled without renormalization identity drift");
    std::set<Material> emitted(reference.cells.begin(), reference.cells.end());
    require(emitted == std::set<Material>{Material::Sand, Material::GraniteBlock},
            "aggregate realizes only its authored positive existing material choices");
    for (const auto material : reference.cells)
        require(cybersand::valid_material(static_cast<std::uint16_t>(material)), "aggregate output never creates a new simulation material ID");
    const auto grain = generator->sample(-7, -7);
    for (std::int64_t y = -7; y < 0; ++y) for (std::int64_t x = -7; x < 0; ++x)
        require(generator->sample(x, y) == grain, "hashed aggregate realization is constant within its signed world-aligned grain");
    std::reverse(recipe.aggregates[0].components.begin(), recipe.aggregates[0].components.end());
    const auto reordered = Generator::compile(recipe);
    require(reordered->fingerprint() == generator->fingerprint() && reordered->generate({-1, -1}).cells == reference.cells,
            "aggregate component insertion order does not change semantic identity or content");

    recipe.aggregates[0].grain_size = 64;
    recipe.fields = {field("selector", FieldKind::Circle, {{"radius", 2}})};
    recipe.aggregates[0].variation = "selector"; generator = Generator::compile(recipe);
    require(generator->sample(0, 0) == Material::GraniteBlock && generator->sample(3, 0) == Material::Sand,
            "named variation selects per cell, with exact one/zero endpoints even inside one hashed grain");
    recipe.aggregates[0].variation.clear(); recipe.aggregates[0].components = {{Material::Water, 2}};
    all_material(Generator::compile(recipe)->generate({0, 0}), Material::Water,
                 "single eligible aggregate component realizes exactly its ordinary material");
}

void masked_modules_and_final_precedence() {
    auto recipe = flat_recipe();
    recipe.fields = {constant("zero", 0), constant("one", 1), constant("half", .5)};
    auto calls = std::make_shared<std::atomic<std::size_t>>(0);
    ModuleRegistry registry;
    add_sampler(registry, "counted", [calls](const ModuleContext&, Material) {
        ++*calls; return Material::Metal;
    }, 23);
    auto instance = module("hook", "counted", {0, 0, 32, 32}); instance.application = "zero";
    recipe.modules = {instance};
    all_material(Generator::compile(recipe, registry)->generate({0, 0}), Material::GraniteBlock,
                 "zero field application disables a custom feature hook");
    require(calls->load() == 0, "masked-out hook does not execute");
    recipe.modules[0].application = "one"; recipe.modules[0].exclusion = "one";
    all_material(Generator::compile(recipe, registry)->generate({0, 0}), Material::GraniteBlock,
                 "module exclusion is authoritative over application");
    require(calls->load() == 0, "excluded hook does not execute");
    recipe.modules[0].exclusion.clear();
    auto generator = Generator::compile(recipe, registry);
    auto result = generator->generate({0, 0}, "module:hook");
    all_material(result, Material::Metal, "full module application executes the clipped hook");
    require(calls->load() == 1024, "full module influence invokes one hook per in-bounds cell");
    for (auto value : result.diagnostics) require(value == 1, "module diagnostic exposes effective application influence");
    recipe.modules[0].application = "half"; recipe.modules[0].strength = .5;
    result = Generator::compile(recipe, registry)->generate({0, 0}, "module:hook");
    for (auto value : result.diagnostics) near(value, .25, "module diagnostic reports continuous influence before material selection");
    recipe.modules[0].application = "one"; recipe.modules[0].strength = 1;
    recipe.modifiers = {paint("paint-after-module", Material::Copper)};
    GuidePath path; path.id = "guide"; path.points = {{0, 16}, {31, 16}}; path.width = 3;
    recipe.paths = {path};
    HardOverride hard; hard.id = "block"; hard.bounds = {12, 15, 5, 3}; hard.material = Material::Glass;
    recipe.overrides = {hard}; generator = Generator::compile(recipe, registry);
    require(generator->sample(5, 5) == Material::Copper, "material modifiers run after feature modules");
    require(generator->sample(5, 16) == Material::Empty, "explicit guide path reserves its result after modifiers");
    require(generator->sample(14, 16) == Material::Glass, "hard material override remains the final authority");
}

Recipe decorated_recipe() {
    Recipe recipe; recipe.chunk_size = 64; recipe.seed = 512394;
    recipe.candidate = Candidate::FlowNetwork;
    recipe.parameters.surface_y = -32; recipe.parameters.relief = 15;
    recipe.parameters.district_size = 64;
    recipe.themes.weights = {{"natural", 2}, {"built", 1}};
    recipe.fields = {
        field("circle", FieldKind::Circle, {{"x", -9}, {"y", 6}, {"radius", 44}, {"feather", 9}}),
        field("noise", FieldKind::ValueNoise, {{"scale", 17}}),
        field("band", FieldKind::Band, {{"low", .2}, {"high", .8}, {"feather", .1}}, {"noise"}),
        field("curve", FieldKind::Hilbert, {{"order", 5}, {"cell_size", 3}, {"origin_x", -7}, {"origin_y", 11}})
    };
    Aggregate aggregate; aggregate.id = "mix"; aggregate.grain_size = 7; aggregate.variation = "curve";
    aggregate.components = {{Material::LimestoneBlock, 2}, {Material::Copper, 1}, {Material::GraniteBlock, 1}};
    recipe.aggregates = {aggregate};
    Modifier guidance; guidance.id = "guidance"; guidance.application = "circle"; guidance.strength = .7;
    guidance.themes.weights = {{"garden", 1}}; guidance.parameters = {{Parameter::Detail, .8}};
    guidance.mappings = {{Parameter::CaveThreshold, "noise", .2, .9}};
    Modifier deposit; deposit.id = "deposit"; deposit.priority = 1; deposit.application = "band";
    deposit.context = ContextPredicate::Occupied; deposit.aggregate = "mix"; deposit.strength = .8;
    recipe.modifiers = {guidance, deposit};
    auto vault = module("vault", "vault", {-64, -64, 128, 128}); vault.application = "circle"; vault.strength = .8;
    recipe.modules = {vault};
    return recipe;
}

void order_partition_and_diagnostic_identity() {
    auto recipe = decorated_recipe();
    const auto generator = Generator::compile(recipe);
    constexpr std::array chunks{ChunkCoord{-1, -1}, ChunkCoord{0, -1}, ChunkCoord{-1, 0}, ChunkCoord{0, 0}};
    std::array<ChunkResult, 4> reference;
    for (std::size_t i = 0; i < chunks.size(); ++i) {
        reference[i] = generator->generate(chunks[i], "modifier:deposit"); ready(reference[i]);
    }
    std::reverse(recipe.fields.begin(), recipe.fields.end());
    std::reverse(recipe.modifiers.begin(), recipe.modifiers.end());
    std::reverse(recipe.aggregates[0].components.begin(), recipe.aggregates[0].components.end());
    const auto reordered = Generator::compile(recipe);
    require(reordered->fingerprint() == generator->fingerprint(), "declaration order is not a hidden field/modifier priority");
    for (std::size_t i = chunks.size(); i-- > 0;) {
        const auto result = reordered->generate(chunks[i], "modifier:deposit");
        require(result.cells == reference[i].cells && result.diagnostics == reference[i].diagnostics &&
                    result.receipt_hash == reference[i].receipt_hash,
                "fresh compilation and request order preserve exact cells, diagnostic bytes and receipt");
    }
    for (const auto size : {16, 32}) {
        recipe.chunk_size = size; const auto sliced = Generator::compile(recipe);
        const auto ratio = 64 / size;
        for (std::size_t i = 0; i < chunks.size(); ++i) for (int by = 0; by < ratio; ++by) for (int bx = 0; bx < ratio; ++bx) {
            const auto part = sliced->generate({chunks[i].x * ratio + bx, chunks[i].y * ratio + by}, "modifier:deposit"); ready(part);
            for (int y = 0; y < size; ++y) for (int x = 0; x < size; ++x) {
                require(cell(part, x, y) == cell(reference[i], bx * size + x, by * size + y),
                        "masked structured output is independent of signed chunk partitioning");
                require(diagnostic(part, x, y) == diagnostic(reference[i], bx * size + x, by * size + y),
                        "context and mask diagnostics use absolute coordinates across partitions");
            }
        }
    }
    auto job = generator->begin(chunks[0], "modifier:deposit");
    require(job->advance(0) == ResultState::Pending && job->completed_cells() == 0, "zero budget cannot advance a diagnostic job");
    rejects([&] { (void)job->result(); }, "Pending diagnostics cannot be published");
    constexpr std::array<std::size_t, 4> budgets{1, 7, 113, 19};
    for (std::size_t turn = 0; job->state() == ResultState::Pending; ++turn) (void)job->advance(budgets[turn % budgets.size()]);
    require(job->result().cells == reference[0].cells && job->result().diagnostics == reference[0].diagnostics &&
                job->result().receipt_hash == reference[0].receipt_hash,
            "incremental cell budgets preserve the normal sampling and diagnostic result");
    auto concurrent = std::async(std::launch::async, [generator] { return generator->generate({-1, -1}, "modifier:deposit"); });
    const auto again = generator->generate({0, 0}, "modifier:deposit");
    require(concurrent.get().receipt_hash == reference[0].receipt_hash && again.receipt_hash == reference[3].receipt_hash,
            "concurrent jobs retain private masks/context/scratch");

    const auto plain = generator->generate(chunks[0]);
    const auto field_result = generator->generate(chunks[0], "field:circle");
    require(plain.cells == field_result.cells && plain.content_hash == field_result.content_hash &&
                plain.receipt_hash != field_result.receipt_hash,
            "diagnostics leave materials unchanged while extending receipt identity");
    require(generator->accepts(field_result), "complete field diagnostic is accepted");
    auto corrupted = field_result; corrupted.diagnostics[0] = .375F;
    if (corrupted.diagnostics[0] == field_result.diagnostics[0]) corrupted.diagnostics[0] = .625F;
    require(!generator->accepts(corrupted), "changed diagnostic bytes invalidate their receipt");
    corrupted = field_result; corrupted.diagnostic = "field:noise";
    require(!generator->accepts(corrupted), "changed diagnostic channel invalidates its receipt");
    corrupted = field_result; corrupted.diagnostics.pop_back();
    require(!generator->accepts(corrupted), "truncated diagnostic payload is rejected");
    corrupted = field_result; corrupted.diagnostics[0] = std::numeric_limits<float>::quiet_NaN();
    require(!generator->accepts(corrupted), "non-finite diagnostic value is rejected");
    corrupted = plain; corrupted.diagnostics = field_result.diagnostics;
    require(!generator->accepts(corrupted), "unnamed diagnostic bytes cannot attach to an ordinary result");
    auto changed = generator->recipe(); changed.fields[0].parameters["low"] = .1;
    // 'band' is the first canonical field and has a low endpoint.
    require(!Generator::compile(changed)->accepts(reference[0]), "edited field configuration rejects stale material/diagnostic proposals");
}

void bounded_failures_and_invalid_recipes() {
    auto recipe = flat_recipe(); recipe.fields = {constant("one", 1)};
    recipe.modifiers = {paint("paint", Material::Copper)}; recipe.modifiers[0].application = "one";
    const auto generator = Generator::compile(recipe);
    auto job = generator->begin({0, 0}, "modifier:paint"); (void)job->advance(7); job->cancel();
    const auto& cancelled = job->result();
    require(cancelled.state == ResultState::Cancelled && cancelled.cells.empty() && cancelled.diagnostics.empty() &&
                cancelled.content_hash == 0 && cancelled.receipt_hash == 0,
            "cancellation discards both partial payloads and their hashes");
    const auto full = generator->generate({0, 0}, "modifier:paint");
    recipe.limits.max_operations_per_chunk = full.operations - 1;
    const auto failed = Generator::compile(recipe)->generate({0, 0}, "modifier:paint");
    require(failed.state == ResultState::Failed && failed.cells.empty() && failed.diagnostics.empty() &&
                failed.content_hash == 0 && failed.receipt_hash == 0,
            "one-less-than-complete work budget discards partial material and diagnostic output");
    require(failed.operations <= recipe.limits.max_operations_per_chunk, "logical work cannot overshoot the configured budget");
    for (const auto* name : {"field:missing", "modifier:missing", "module:missing", "world:one", "field:", "one"})
        rejects([&] { (void)generator->begin({0, 0}, name); }, "unknown or malformed diagnostic request rejects before work");
    ModuleRegistry registry;
    add_sampler(registry, "bad", [](const ModuleContext& context, Material) -> std::optional<Material> {
        if (context.x == 7) throw std::runtime_error("deliberate field-aware module failure");
        return Material::Copper;
    });
    recipe = flat_recipe(); recipe.fields = {constant("one", 1)};
    recipe.modules = {module("bad", "bad", {0, 0, 32, 32})}; recipe.modules[0].application = "one";
    const auto callback_failure = Generator::compile(recipe, registry)->generate({0, 0}, "module:bad");
    require(callback_failure.state == ResultState::Failed && callback_failure.cells.empty() && callback_failure.diagnostics.empty(),
            "callback failure does not expose a diagnostic/material prefix");

    const auto rejects_recipe = [](const std::function<void(Recipe&)>& edit) {
        auto invalid = flat_recipe(); invalid.fields = {constant("one", 1)};
        invalid.modifiers = {paint("paint", Material::Copper)};
        edit(invalid);
        rejects([&] { (void)Generator::compile(invalid); }, "invalid new recipe declaration rejects before job creation");
    };
    rejects_recipe([](auto& r) { r.modifiers[0].application = "missing"; });
    rejects_recipe([](auto& r) { r.modifiers[0].exclusion = "missing"; });
    rejects_recipe([](auto& r) { r.modifiers.push_back(r.modifiers[0]); });
    rejects_recipe([](auto& r) { r.modifiers[0].strength = 1.01; });
    rejects_recipe([](auto& r) { r.modifiers[0].strength = std::numeric_limits<double>::quiet_NaN(); });
    rejects_recipe([](auto& r) { r.modifiers[0].bounds = RectI64{0, 0, 4, 4}; r.modifiers[0].points = {{0, 0}}; });
    rejects_recipe([](auto& r) { r.modifiers[0].bounds = RectI64{0, 0, 0, 4}; });
    rejects_recipe([](auto& r) { r.modifiers[0].context = static_cast<ContextPredicate>(255); });
    rejects_recipe([](auto& r) { r.modifiers[0].context = ContextPredicate::Material; });
    rejects_recipe([](auto& r) { r.modifiers[0].context = ContextPredicate::Material; r.modifiers[0].context_material = static_cast<Material>(10); });
    rejects_recipe([](auto& r) { r.modifiers[0].context_material = Material::Water; });
    rejects_recipe([](auto& r) { r.modifiers[0].material = static_cast<Material>(10); });
    rejects_recipe([](auto& r) { r.modifiers[0].parameters = {{Parameter::DistrictSize, 64}}; });
    rejects_recipe([](auto& r) { r.modifiers[0].mappings = {{Parameter::DistrictSize, "one", 64, 128}}; });
    rejects_recipe([](auto& r) { r.modifiers[0].mappings = {{Parameter::FeatureScale, "missing", 16, 32}}; });
    rejects_recipe([](auto& r) { r.modifiers[0].mappings = {{Parameter::FeatureScale, "one", 1, 32}}; });
    rejects_recipe([](auto& r) { r.modifiers[0].mappings = {{Parameter::FeatureScale, "one", 16, std::numeric_limits<double>::infinity()}}; });
    rejects_recipe([](auto& r) { r.modifiers[0].mappings = {{Parameter::Detail, "one", 0, 1}, {Parameter::Detail, "one", 0, 1}}; });
    rejects_recipe([](auto& r) { r.modifiers[0].material.reset(); r.modifiers[0].aggregate = "missing"; });
    rejects_recipe([](auto& r) {
        Aggregate a; a.id = "mix"; a.components = {{Material::Sand, 1}};
        r.aggregates = {a}; r.modifiers[0].aggregate = "mix";
    });
    rejects_recipe([](auto& r) { r.modifiers[0].material.reset(); });
    rejects_recipe([](auto& r) { r.limits.max_fields = 0; });
    rejects_recipe([](auto& r) { r.limits.max_modifiers = 0; });
    rejects_recipe([](auto& r) { r.fields.push_back(field("unused", FieldKind::Invert, {}, {"missing"})); r.modifiers[0].strength = 0; });

    const auto rejects_aggregate = [](const std::function<void(Aggregate&)>& edit) {
        auto r = flat_recipe(); Aggregate a; a.id = "mix"; a.components = {{Material::Sand, 1}, {Material::GraniteBlock, 1}};
        edit(a); r.aggregates = {a}; Modifier m; m.id = "aggregate"; m.aggregate = "mix"; r.modifiers = {m};
        rejects([&] { (void)Generator::compile(r); }, "invalid aggregate must not silently realize a fallback material");
    };
    rejects_aggregate([](auto& a) { a.components.clear(); });
    rejects_aggregate([](auto& a) { a.components[0].weight = 0; });
    rejects_aggregate([](auto& a) { for (auto& c : a.components) c.weight = 0; });
    rejects_aggregate([](auto& a) { a.components[0].weight = -1; });
    rejects_aggregate([](auto& a) { a.components[0].weight = std::numeric_limits<double>::infinity(); });
    rejects_aggregate([](auto& a) {
        a.components[0].weight = std::numeric_limits<double>::denorm_min(); a.components[1].weight = 1'000'000;
    });
    rejects_aggregate([](auto& a) { a.components[0].material = static_cast<Material>(10); });
    rejects_aggregate([](auto& a) { a.components.push_back(a.components.front()); });
    rejects_aggregate([](auto& a) { a.grain_size = 0; });
    rejects_aggregate([](auto& a) { a.grain_size = 4097; });
    rejects_aggregate([](auto& a) { a.variation = "missing"; });
}
} // namespace

int main() {
    try {
        retained_gen001_material_oracle();
        application_exclusion_and_shape();
        immutable_initial_context();
        theme_guidance_and_hard_authority();
        aggregate_realization_and_grains();
        masked_modules_and_final_precedence();
        order_partition_and_diagnostic_identity();
        bounded_failures_and_invalid_recipes();
        std::cout << "PASS generation modifiers: retained GEN-001 oracle, masked guidance/exclusion, immutable context, "
                     "hard authority, aggregate material/grains, hook masks, signed partitioning, diagnostic receipts and bounded failure\n";
    } catch (const std::exception& error) {
        std::cerr << "FAIL generation modifiers: " << error.what() << '\n';
        return 1;
    }
}
