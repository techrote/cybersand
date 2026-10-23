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
#include <numeric>
#include <set>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace {
using cybersand::ChunkCoord;
using cybersand::Material;
using namespace cybersand::generation;

void require(bool value, const std::string& message) {
    if (!value) throw std::runtime_error(message);
}

template<class Action>
void rejects(Action&& action, const std::string& message) {
    bool rejected = false;
    try { action(); }
    catch (const std::exception&) { rejected = true; }
    require(rejected, message);
}

void same_cells(const ChunkResult& actual, const ChunkResult& expected,
                const std::string& message) {
    require(actual.state == ResultState::Ready && expected.state == ResultState::Ready,
            message + ": complete proposals");
    require(actual.chunk == expected.chunk && actual.chunk_size == expected.chunk_size &&
                actual.cells == expected.cells && actual.content_hash == expected.content_hash,
            message + ": exact cell identity");
}

Material cell(const ChunkResult& result, std::int32_t x, std::int32_t y) {
    return result.cells.at(static_cast<std::size_t>(y) *
                               static_cast<std::size_t>(result.chunk_size) +
                           static_cast<std::size_t>(x));
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

void add_sampler(ModuleRegistry& registry, std::string id, Sampler::Callback callback,
                 std::uint32_t cost = 1) {
    ModuleFactory factory;
    factory.id = std::move(id);
    factory.operations_per_cell = cost;
    factory.prepare = [callback = std::move(callback)](const ModuleInstance&, std::uint64_t) {
        return std::make_shared<Sampler>(callback);
    };
    registry.add(std::move(factory));
}

ModuleInstance instance(std::string id, std::string module, cybersand::RectI64 bounds) {
    ModuleInstance result;
    result.id = std::move(id);
    result.module = std::move(module);
    result.bounds = bounds;
    return result;
}

Recipe decorated_recipe(Candidate candidate) {
    Recipe recipe;
    recipe.candidate = candidate;
    recipe.seed = UINT64_C(0x416cd08397ad0f23);
    recipe.themes.weights = {{"natural", 2.0}, {"built", 1.0}};
    BrushStroke stroke;
    stroke.id = "garden-ribbon";
    stroke.points = {{-100.0, -30.0}, {80.0, 100.0}};
    stroke.radius = 37.0;
    stroke.strength = 0.7;
    stroke.themes.weights = {{"garden", 1.0}};
    stroke.parameters = {{Parameter::Relief, 19.0}};
    recipe.strokes.push_back(stroke);
    GuidePath path;
    path.id = "crossing";
    path.points = {{-120.0, -64.0}, {0.0, -64.0}, {0.0, 120.0}};
    path.width = 7.0;
    recipe.paths.push_back(path);
    HardOverride override;
    override.id = "glass-inlay";
    override.bounds = {-9, -15, 23, 21};
    override.material = Material::StainedGlass;
    recipe.overrides.push_back(override);
    recipe.modules.push_back(instance("vault", "vault", {-96, -96, 192, 192}));
    return recipe;
}

void deterministic_order_and_partition() {
    constexpr std::array candidates{Candidate::Strata, Candidate::FlowNetwork,
                                    Candidate::DistrictGrammar};
    constexpr std::array chunks{ChunkCoord{-1, -1}, ChunkCoord{0, -1},
                               ChunkCoord{-1, 0}, ChunkCoord{0, 0}};
    for (const auto candidate : candidates) {
        const auto recipe = decorated_recipe(candidate);
        const auto generator = Generator::compile(recipe);
        std::array<ChunkResult, chunks.size()> reference;
        for (std::size_t i = 0; i < chunks.size(); ++i) {
            reference[i] = generator->generate(chunks[i]);
            require(reference[i].state == ResultState::Ready,
                    "decorated candidate must generate a complete reference");
        }
        const auto fresh = Generator::compile(recipe);
        for (std::size_t i = chunks.size(); i-- > 0;) {
            same_cells(fresh->generate(chunks[i]), reference[i],
                       "generation order and fresh compilation cannot change content");
        }
        for (const std::int32_t size : {32, 64}) {
            auto sliced_recipe = recipe;
            sliced_recipe.chunk_size = size;
            const auto sliced = Generator::compile(sliced_recipe);
            const std::int32_t ratio = recipe.chunk_size / size;
            for (std::size_t i = 0; i < chunks.size(); ++i) {
                for (std::int32_t sy = 0; sy < ratio; ++sy) {
                    for (std::int32_t sx = 0; sx < ratio; ++sx) {
                        const auto part = sliced->generate(
                            {chunks[i].x * ratio + sx, chunks[i].y * ratio + sy});
                        require(part.state == ResultState::Ready,
                                "every partition must complete");
                        for (std::int32_t y = 0; y < size; ++y) {
                            for (std::int32_t x = 0; x < size; ++x) {
                                require(cell(part, x, y) == cell(reference[i], sx * size + x,
                                                              sy * size + y),
                                        "chunk size and negative-coordinate partition cannot change a cell");
                            }
                        }
                    }
                }
            }
        }
    }
}

void candidates_seeds_and_compiled_ownership() {
    Recipe recipe;
    recipe.chunk_size = 64;
    const auto first = Generator::compile(recipe);
    const auto before = first->generate({0, 2});
    const auto fingerprint = first->fingerprint();
    recipe.seed = 93041;
    recipe.parameters.surface_y = -300.0;
    require(first->recipe().seed == 1 && first->recipe().parameters.surface_y == 96.0 &&
                first->fingerprint() == fingerprint,
            "compiled generator owns its recipe independently of caller edits");
    same_cells(first->generate({0, 2}), before, "caller mutation cannot alter compiled content");

    std::set<std::vector<Material>> distinct_candidates;
    for (const auto candidate : {Candidate::Strata, Candidate::FlowNetwork,
                                 Candidate::DistrictGrammar}) {
        Recipe selected;
        selected.chunk_size = 64;
        selected.candidate = candidate;
        const auto generator = Generator::compile(selected);
        std::vector<Material> signature;
        for (const auto chunk : {ChunkCoord{0, 2}, ChunkCoord{1, 3}, ChunkCoord{-2, 4}}) {
            const auto result = generator->generate(chunk);
            require(result.state == ResultState::Ready, "candidate fixture completes");
            signature.insert(signature.end(), result.cells.begin(), result.cells.end());
        }
        distinct_candidates.insert(std::move(signature));
    }
    require(distinct_candidates.size() == 3, "three candidates must have distinct generated behavior");
    Recipe alternate;
    alternate.chunk_size = 64;
    alternate.seed = 932474;
    const auto changed_seed = Generator::compile(alternate);
    require(changed_seed->fingerprint() != fingerprint,
            "seed changes compile identity");
    require(changed_seed->generate({0, 2}).cells != before.cells,
            "seed changes content in a terrain fixture");
}

Recipe small_catalogue_recipe() {
    Recipe recipe;
    recipe.chunk_size = 32;
    Theme root;
    root.id = "root";
    Theme natural;
    natural.id = "nature";
    natural.parents = {"root"};
    Theme stone;
    stone.id = "stone";
    stone.parents = {"nature"};
    stone.concrete = true;
    stone.palette.rock = Material::Stone;
    Theme garden;
    garden.id = "garden";
    garden.parents = {"nature"};
    garden.concrete = true;
    garden.palette.rock = Material::MossyCobblestone;
    Theme metal;
    metal.id = "metal";
    metal.parents = {"root"};
    metal.concrete = true;
    metal.palette.rock = Material::SteelPlate;
    recipe.catalogue = {root, natural, stone, garden, metal};
    recipe.themes.weights = {{"root", 1.0}};
    return recipe;
}

double weight(const std::vector<ThemeWeight>& weights, const std::string& id) {
    for (const auto& item : weights) if (item.id == id) return item.weight;
    return 0.0;
}

void normalized_themes_and_global_exclusions() {
    auto recipe = small_catalogue_recipe();
    const auto all = Generator::compile(recipe);
    const auto all_weights = all->theme_weights_at(0, 0);
    require(all_weights.size() == 3, "a superset expands to each concrete descendant");
    double sum = 0.0;
    for (const auto& item : all_weights) {
        require(item.weight > 0.0 && std::isfinite(item.weight), "active theme weights are positive and finite");
        require(item.id != "root" && item.id != "nature", "groups are not emitted as material themes");
        sum += item.weight;
    }
    require(std::abs(sum - 1.0) < 1e-12, "resolved theme weights normalize to one");

    recipe.themes.weights = {{"nature", 3.0}, {"metal", 1.0}};
    const auto weighted_groups = Generator::compile(recipe)->theme_weights_at(0, 0);
    require(std::abs(weight(weighted_groups, "stone") - 0.375) < 1e-12 &&
                std::abs(weight(weighted_groups, "garden") - 0.375) < 1e-12 &&
                std::abs(weight(weighted_groups, "metal") - 0.25) < 1e-12,
            "a group's weight splits across descendants before the weighted union normalizes");
    recipe.themes.weights = {{"nature", 1.0}, {"stone", 1.0}};
    const auto overlapping = Generator::compile(recipe)->theme_weights_at(0, 0);
    require(overlapping.size() == 2 && std::abs(weight(overlapping, "stone") - 0.75) < 1e-12 &&
                std::abs(weight(overlapping, "garden") - 0.25) < 1e-12,
            "overlapping group and leaf selections accumulate mass without duplicate theme instances");

    recipe.themes.weights = {{"nature", 1.0}};
    const auto subset = Generator::compile(recipe)->theme_weights_at(0, 0);
    require(subset.size() == 2 && weight(subset, "metal") == 0.0,
            "selecting a subset excludes unrelated descendants");
    recipe.themes.weights = {{"root", 1.0}};
    recipe.themes.exclude = {"nature"};
    const auto without_nature = Generator::compile(recipe)->theme_weights_at(0, 0);
    require(without_nature.size() == 1 && weight(without_nature, "metal") == 1.0,
            "excluding a superset excludes its descendants");

    BrushStroke stroke;
    stroke.id = "cannot-reintroduce-excluded-descendants";
    stroke.points = {{0.0, 0.0}};
    stroke.radius = 30.0;
    stroke.themes.weights = {{"nature", 5.0}, {"metal", 1.0}};
    recipe.strokes.push_back(stroke);
    const auto brush = Generator::compile(recipe)->theme_weights_at(0, 0);
    require(brush.size() == 1 && weight(brush, "metal") == 1.0,
            "brushes cannot reintroduce a globally excluded theme");
}

void brush_falloff_and_parameter_precedence() {
    auto recipe = small_catalogue_recipe();
    recipe.themes.weights = {{"stone", 1.0}};
    BrushStroke stroke;
    stroke.id = "garden-brush";
    stroke.points = {{0.0, 0.0}};
    stroke.radius = 32.0;
    stroke.themes.weights = {{"garden", 1.0}};
    recipe.strokes.push_back(stroke);
    const auto generator = Generator::compile(recipe);
    const auto centre = generator->theme_weights_at(0, 0);
    const auto edge = generator->theme_weights_at(16, 0);
    const auto outside = generator->theme_weights_at(40, 0);
    require(weight(centre, "garden") == 1.0 && weight(centre, "stone") == 0.0,
            "full-strength brush centre selects its theme");
    require(weight(edge, "garden") > 0.0 && weight(edge, "garden") < 1.0 &&
                weight(edge, "stone") > 0.0,
            "brush falloff produces a blend, not a hard selection boundary");
    require(weight(outside, "stone") == 1.0 && weight(outside, "garden") == 0.0,
            "brush influence is limited to its radius");

    ModuleRegistry registry;
    add_sampler(registry, "parameter-probe", [](const ModuleContext& context, Material) {
        if (context.parameters.relief == 17.0) return Material::Metal;
        if (context.parameters.relief == 9.0) return Material::Water;
        return Material::Sand;
    });
    recipe.parameters.relief = 3.0;
    recipe.strokes[0].themes.weights.clear();
    recipe.strokes[0].parameters = {{Parameter::Relief, 9.0}};
    recipe.modules.push_back(instance("probe", "parameter-probe", {-64, -64, 128, 128}));
    HardOverride override;
    override.id = "precise-relief";
    override.bounds = {0, 0, 4, 4};
    override.parameters = {{Parameter::Relief, 17.0}};
    recipe.overrides.push_back(override);
    const auto parameters = Generator::compile(recipe, registry);
    require(parameters->sample(0, 0) == Material::Metal,
            "hard parameter override wins over broad parameter brush before module sampling");
    require(parameters->sample(0, -1) != Material::Metal && parameters->sample(40, 0) == Material::Sand,
            "hard parameter bounds and brush radius do not leak into surrounding cells");
    recipe.overrides.clear();
    require(Generator::compile(recipe, registry)->sample(0, 0) == Material::Water,
            "parameter-only brush updates the module's effective parameters");
}

void unchanged_theme_parameters_remain_exact() {
    Recipe recipe;
    recipe.chunk_size = 32;
    recipe.parameters.wall_thickness = 1.0;
    recipe.parameters.room_size = 12.0;
    recipe.parameters.feature_scale = 8.0;
    recipe.parameters.strata_period = 2.0;
    Theme root;
    root.id = "root";
    recipe.catalogue.push_back(root);
    for (int i = 0; i < 7; ++i) {
        Theme leaf;
        leaf.id = "leaf" + std::to_string(i);
        leaf.parents = {"root"};
        leaf.concrete = true;
        recipe.catalogue.push_back(leaf);
    }
    recipe.themes.weights = {{"root", 1.0}};
    ModuleRegistry registry;
    add_sampler(registry, "minimum-parameter-probe", [](const ModuleContext& context, Material) {
        return context.parameters.wall_thickness == 1.0 && context.parameters.room_size == 12.0 &&
                       context.parameters.feature_scale == 8.0 && context.parameters.strata_period == 2.0
                   ? Material::Metal : Material::Lava;
    });
    recipe.modules.push_back(instance("probe", "minimum-parameter-probe", {0, 0, 32, 32}));
    const auto generator = Generator::compile(recipe, registry);
    require(generator->sample(0, 0) == Material::Metal,
            "blending seven identical parameter sets preserves exact minima instead of rounding one-cell walls to zero");

    Recipe precise;
    precise.chunk_size = 32;
    precise.parameters.surface_y = 1'000'000.0;
    ModuleRegistry exact_registry;
    add_sampler(exact_registry, "exact-target-probe", [](const ModuleContext& context, Material) {
        return context.parameters.surface_y == 0.1 ? Material::Glass : Material::Lava;
    });
    precise.modules.push_back(instance("probe", "exact-target-probe", {0, 0, 32, 32}));
    HardOverride hard;
    hard.id = "exact-fractional-target";
    hard.bounds = {0, 0, 32, 32};
    hard.parameters = {{Parameter::SurfaceY, 0.1}};
    precise.overrides.push_back(hard);
    require(Generator::compile(precise, exact_registry)->sample(0, 0) == Material::Glass,
            "hard parameter target survives large-to-small interpolation cancellation exactly");
    precise.overrides.clear();
    BrushStroke brush;
    brush.id = "exact-full-strength-centre";
    brush.points = {{0.0, 0.0}};
    brush.parameters = {{Parameter::SurfaceY, 0.1}};
    precise.strokes.push_back(brush);
    require(Generator::compile(precise, exact_registry)->sample(0, 0) == Material::Glass,
            "full-strength parameter brush centre preserves its declared fractional target exactly");
}

void canonical_controls_and_hard_material_precedence() {
    ModuleRegistry registry;
    add_sampler(registry, "fill", [](const ModuleContext&, Material) { return Material::Lava; });
    Recipe recipe;
    recipe.chunk_size = 32;
    recipe.modules.push_back(instance("fill", "fill", {-32, -32, 96, 96}));
    GuidePath path;
    path.id = "cut";
    path.points = {{-20.0, 8.0}, {50.0, 8.0}};
    recipe.paths.push_back(path);
    HardOverride a;
    a.id = "a";
    a.bounds = {4, 4, 8, 8};
    a.material = Material::Glass;
    a.priority = 2;
    auto b = a;
    b.id = "b";
    b.material = Material::Metal;
    auto low = a;
    low.id = "z-lower-priority";
    low.priority = 1;
    low.material = Material::Water;
    recipe.overrides = {b, low, a};
    const auto first = Generator::compile(recipe, registry);
    require(first->sample(8, 8) == Material::Metal,
            "highest priority then lexical ID hard material wins over guides and modules");
    require(first->sample(15, 15) == Material::Lava,
            "hard material does not leak outside its half-open rectangle");
    std::reverse(recipe.overrides.begin(), recipe.overrides.end());
    const auto reordered = Generator::compile(recipe, registry);
    require(reordered->fingerprint() == first->fingerprint(),
            "canonical hard-override order gives the same recipe identity");
    same_cells(reordered->generate({0, 0}), first->generate({0, 0}),
               "declaration order does not replace declared hard-override priority");

    Recipe brushed;
    brushed.chunk_size = 32;
    brushed.themes.weights = {{"dry_cavern", 1.0}};
    BrushStroke early;
    early.id = "a";
    early.points = {{8.0, 8.0}};
    early.parameters = {{Parameter::Relief, 4.0}};
    BrushStroke late = early;
    late.id = "b";
    late.parameters = {{Parameter::Relief, 17.0}};
    brushed.strokes = {late, early};
    ModuleRegistry probes;
    add_sampler(probes, "probe", [](const ModuleContext& context, Material) {
        return context.parameters.relief == 17.0 ? Material::Glass : Material::Stone;
    });
    brushed.modules.push_back(instance("probe", "probe", {0, 0, 32, 32}));
    const auto brush_first = Generator::compile(brushed, probes);
    require(brush_first->sample(8, 8) == Material::Glass,
            "lexical tie ordering also governs full-strength parameter brushes");
    std::reverse(brushed.strokes.begin(), brushed.strokes.end());
    const auto brush_second = Generator::compile(brushed, probes);
    require(brush_first->fingerprint() == brush_second->fingerprint(),
            "canonical brush order gives the same recipe identity");
    same_cells(brush_first->generate({0, 0}), brush_second->generate({0, 0}),
               "brush list order cannot change material proposals");
}

void connected_guides_and_candidate_overrides() {
    for (const auto candidate : {Candidate::Strata, Candidate::FlowNetwork,
                                 Candidate::DistrictGrammar}) {
        Recipe recipe;
        recipe.chunk_size = 32;
        recipe.candidate = candidate;
        GuidePath path;
        path.id = "connected-elbow";
        path.points = {{-60.0, -1.0}, {17.0, -1.0}, {17.0, 63.0}};
        path.width = 5.0;
        recipe.paths.push_back(path);
        const auto generator = Generator::compile(recipe);
        for (std::int64_t x = -60; x <= 17; ++x) {
            require(generator->sample(x, -1) == Material::Empty,
                    "authored horizontal guide stays open through negative and zero chunk seams");
        }
        for (std::int64_t y = -1; y <= 63; ++y) {
            require(generator->sample(17, y) == Material::Empty,
                    "connected guide elbow stays open through vertical chunk seams");
        }
        const auto left = generator->generate({-1, -1});
        const auto right = generator->generate({0, -1});
        require(left.state == ResultState::Ready && right.state == ResultState::Ready &&
                    cell(left, 31, 31) == Material::Empty && cell(right, 0, 31) == Material::Empty,
                "independently generated chunks preserve the authored shared entrance");
    }

    Recipe base;
    base.chunk_size = 32;
    base.themes.weights = {{"industrial", 1.0}};
    const auto untouched = Generator::compile(base);
    auto replacement = base;
    replacement.candidate = Candidate::DistrictGrammar;
    const auto expected = Generator::compile(replacement);
    HardOverride selected;
    selected.id = "structured-subset";
    selected.bounds = {-10, 120, 45, 32};
    selected.candidate = Candidate::DistrictGrammar;
    base.overrides.push_back(selected);
    const auto mixed = Generator::compile(base);
    for (std::int64_t y = 120; y < 152; y += 3) {
        for (std::int64_t x = -10; x < 35; x += 3) {
            require(mixed->sample(x, y) == expected->sample(x, y),
                    "hard candidate selection uses the selected algorithm at the same world coordinate");
        }
    }
    require(mixed->sample(-11, 120) == untouched->sample(-11, 120) &&
                mixed->sample(35, 120) == untouched->sample(35, 120),
            "hard candidate bounds do not affect neighboring regions");
}

void module_order_domain_and_preparation() {
    ModuleRegistry registry;
    add_sampler(registry, "first", [](const ModuleContext&, Material) { return Material::Metal; });
    add_sampler(registry, "second", [](const ModuleContext&, Material previous) {
        return previous == Material::Metal ? Material::Glass : Material::Lava;
    });
    Recipe recipe;
    recipe.chunk_size = 32;
    auto first = instance("z-source", "first", {-4, -4, 12, 12});
    first.priority = 10;
    auto second = instance("a-dependent", "second", {-4, -4, 12, 12});
    second.priority = -10;
    second.after = {"z-source"};
    recipe.modules = {second, first};
    const auto generator = Generator::compile(recipe, registry);
    require(generator->sample(0, 0) == Material::Glass,
            "explicit module dependency order takes precedence over priority and lexical order");
    std::reverse(recipe.modules.begin(), recipe.modules.end());
    const auto reordered = Generator::compile(recipe, registry);
    require(generator->fingerprint() == reordered->fingerprint(),
            "canonical dependency order gives the same module recipe identity");
    same_cells(generator->generate({0, 0}), reordered->generate({0, 0}),
               "module input-list order cannot change compiled feature behavior");

    auto calls = std::make_shared<std::atomic<std::size_t>>(0);
    auto preparations = std::make_shared<std::atomic<std::size_t>>(0);
    ModuleRegistry clipped;
    ModuleFactory factory;
    factory.id = "clipped";
    factory.operations_per_cell = 1;
    factory.prepare = [calls, preparations](const ModuleInstance&, std::uint64_t) {
        ++*preparations;
        return std::make_shared<Sampler>([calls](const ModuleContext& context, Material) {
            require(context.x >= 5 && context.x < 9 && context.y >= 7 && context.y < 10,
                    "module sampler must not observe cells outside its declared domain");
            ++*calls;
            return Material::Copper;
        });
    };
    clipped.add(std::move(factory));
    Recipe bounded;
    bounded.chunk_size = 32;
    bounded.modules.push_back(instance("only-twelve-cells", "clipped", {5, 7, 4, 3}));
    const auto prepared = Generator::compile(bounded, clipped);
    require(*preparations == 1 && *calls == 0, "modules prepare once without sampling during compile");
    const auto result = prepared->generate({0, 0});
    require(result.state == ResultState::Ready && *preparations == 1 && *calls == 12,
            "only cells in a module's clipped domain invoke its prepared sampler");
    require(cell(result, 5, 7) == Material::Copper && cell(result, 8, 9) == Material::Copper,
            "prepared sampler output reaches both ends of its half-open domain");
    require(prepared->generate({1, 1}).state == ResultState::Ready && *calls == 12,
            "disjoint chunks never invoke the module or prepare it again");
}

void macro_routes_survive_structure_modules() {
    ModuleRegistry registry;
    add_sampler(registry, "solid-fill", [](const ModuleContext&, Material) { return Material::Metal; });
    constexpr std::int32_t size = 128;
    constexpr std::int32_t origin = -64;
    for (const auto candidate : {Candidate::FlowNetwork, Candidate::DistrictGrammar}) {
        Recipe recipe;
        recipe.chunk_size = 32;
        recipe.candidate = candidate;
        recipe.parameters.district_size = 64.0;
        recipe.parameters.corridor_width = 5.0;
        recipe.modules.push_back(instance("solid", "solid-fill", {origin, origin, size, size}));
        const auto generator = Generator::compile(recipe, registry);
        std::vector<Material> cells(static_cast<std::size_t>(size * size), Material::Metal);
        for (std::int32_t cy = -2; cy < 2; ++cy) {
            for (std::int32_t cx = -2; cx < 2; ++cx) {
                const auto chunk = generator->generate({cx, cy});
                require(chunk.state == ResultState::Ready, "macro route fixture completes");
                for (std::int32_t y = 0; y < 32; ++y) {
                    for (std::int32_t x = 0; x < 32; ++x) {
                        const auto rx = cx * 32 + x - origin;
                        const auto ry = cy * 32 + y - origin;
                        cells[static_cast<std::size_t>(ry * size + rx)] = cell(chunk, x, y);
                    }
                }
            }
        }
        std::vector<bool> visited(cells.size(), false);
        std::vector<std::size_t> queue;
        bool connected_all_sides = false;
        for (std::size_t seed = 0; seed < cells.size() && !connected_all_sides; ++seed) {
            if (visited[seed] || cells[seed] != Material::Empty) continue;
            unsigned edges = 0;
            queue.clear();
            queue.push_back(seed);
            visited[seed] = true;
            for (std::size_t head = 0; head < queue.size(); ++head) {
                const auto index = queue[head];
                const auto x = static_cast<std::int32_t>(index % size);
                const auto y = static_cast<std::int32_t>(index / size);
                if (x == 0) edges |= 1U;
                if (x == size - 1) edges |= 2U;
                if (y == 0) edges |= 4U;
                if (y == size - 1) edges |= 8U;
                for (const auto& delta : std::array<std::pair<int, int>, 4>{
                         std::pair{-1, 0}, std::pair{1, 0}, std::pair{0, -1}, std::pair{0, 1}}) {
                    const auto nx = x + delta.first;
                    const auto ny = y + delta.second;
                    if (nx < 0 || nx >= size || ny < 0 || ny >= size) continue;
                    const auto neighbor = static_cast<std::size_t>(ny * size + nx);
                    if (visited[neighbor] || cells[neighbor] != Material::Empty) continue;
                    visited[neighbor] = true;
                    queue.push_back(neighbor);
                }
            }
            connected_all_sides = edges == 15U;
        }
        require(connected_all_sides,
                "one four-neighbor open route connects all sides of a 2x2 macroregion after solid module fill");
    }
}

void incremental_jobs_lifetimes_and_stale_results() {
    Recipe recipe;
    recipe.chunk_size = 32;
    auto generator = Generator::compile(recipe);
    const auto expected = generator->generate({-1, 3});
    require(expected.state == ResultState::Ready && generator->accepts(expected),
            "fresh complete proposal is accepted by its compiled identity");
    auto job = generator->begin({-1, 3});
    require(job->state() == ResultState::Pending && job->completed_cells() == 0,
            "new job has no completed cells");
    rejects([&] { (void)job->result(); }, "pending job cannot expose a partial proposal");
    require(job->advance(0) == ResultState::Pending && job->completed_cells() == 0,
            "zero work budget is an exact no-op");
    require(job->advance(7) == ResultState::Pending && job->completed_cells() == 7,
            "incremental job respects a small exact cell budget");
    rejects([&] { (void)job->result(); }, "partially generated cells remain private");
    for (const std::size_t budget : {std::size_t{1}, std::size_t{13}, std::size_t{63}}) {
        const auto before = job->completed_cells();
        require(job->advance(budget) == ResultState::Pending &&
                    job->completed_cells() - before <= budget,
                "varying cell budgets remain bounded and keep partial data private");
    }
    generator.reset();
    while (job->state() == ResultState::Pending) (void)job->advance(31);
    same_cells(job->result(), expected, "job owns generator lifetime and matches synchronous generation");
    require(job->advance(32) == ResultState::Ready, "a completed job does not start generating again");

    generator = Generator::compile(recipe);
    auto cancelled = generator->begin({0, 0});
    (void)cancelled->advance(19);
    cancelled->cancel();
    require(cancelled->state() == ResultState::Cancelled && cancelled->result().cells.empty(),
            "cancelling discards a partially generated payload");
    require(cancelled->advance(10000) == ResultState::Cancelled &&
                !generator->accepts(cancelled->result()),
            "cancelled work cannot resume or be accepted");

    auto wrong_identity = expected;
    ++wrong_identity.fingerprint;
    require(!generator->accepts(wrong_identity), "mismatched recipe fingerprint is rejected");
    wrong_identity = expected;
    ++wrong_identity.revision;
    require(!generator->accepts(wrong_identity), "mismatched recipe revision is rejected");
    wrong_identity = expected;
    ++wrong_identity.chunk.x;
    require(!generator->accepts(wrong_identity),
            "a result from one coordinate cannot authorize another destination after a slot mixup");
    wrong_identity = expected;
    ++wrong_identity.content_hash;
    require(!generator->accepts(wrong_identity), "corrupted content digest is rejected");
    wrong_identity = expected;
    wrong_identity.cells[0] = static_cast<Material>(10);
    require(!generator->accepts(wrong_identity), "corrupted material data is rejected");
    wrong_identity = expected;
    wrong_identity.cells.pop_back();
    require(!generator->accepts(wrong_identity), "incomplete payload shape is rejected");
    auto next_revision = recipe;
    ++next_revision.revision;
    require(!Generator::compile(next_revision)->accepts(expected),
            "a completed old job cannot be installed after a revision change");
    auto changed_same_revision = recipe;
    changed_same_revision.parameters.relief += 1.0;
    require(!Generator::compile(changed_same_revision)->accepts(expected),
            "same revision cannot authorize a result from a different recipe");

    auto parallel_a = std::async(std::launch::async, [generator] { return generator->generate({-1, 3}); });
    auto parallel_b = std::async(std::launch::async, [generator] { return generator->generate({-1, 3}); });
    same_cells(parallel_a.get(), expected, "concurrent immutable generation A");
    same_cells(parallel_b.get(), expected, "concurrent immutable generation B");
}

void module_failures_and_work_budget() {
    for (const bool throws : {false, true}) {
        ModuleRegistry registry;
        add_sampler(registry, "bad", [throws](const ModuleContext& context, Material) -> std::optional<Material> {
            if (context.x < 8) return Material::Metal;
            if (throws) throw std::runtime_error("intentional module failure");
            return static_cast<Material>(10); // reserved/invalid catalogue slot
        });
        Recipe recipe;
        recipe.chunk_size = 32;
        recipe.modules.push_back(instance("failure", "bad", {0, 0, 32, 32}));
        const auto generator = Generator::compile(recipe, registry);
        auto job = generator->begin({0, 0});
        require(job->advance(4) == ResultState::Pending && job->completed_cells() == 4,
                "negative-control module first produces a valid partial prefix");
        require(job->advance(20) == ResultState::Failed, "bad module output fails the whole proposal");
        const auto& result = job->result();
        require(result.cells.empty() && !result.error.empty() && !generator->accepts(result),
                "module failure retains an explicit error and discards every partial cell");
        require(job->advance(100) == ResultState::Failed,
                "failed generation does not retry partial output");
    }

    ModuleRegistry expensive;
    add_sampler(expensive, "expensive", [](const ModuleContext&, Material) { return Material::Metal; }, 1000);
    Recipe enough;
    enough.chunk_size = 32;
    enough.modules.push_back(instance("cost", "expensive", {0, 0, 32, 32}));
    const auto accepted = Generator::compile(enough, expensive)->generate({0, 0});
    require(accepted.state == ResultState::Ready && accepted.operations >= 1'024'000,
            "declared module work is charged to generation accounting");
    auto limited = enough;
    limited.limits.max_operations_per_chunk = accepted.operations - 1;
    const auto generator = Generator::compile(limited, expensive);
    const auto refused = generator->generate({0, 0});
    require(refused.state == ResultState::Failed && refused.cells.empty() &&
                !refused.error.empty() && refused.operations <= limited.limits.max_operations_per_chunk,
            "exhausted logical work budget never publishes a clipped or partial chunk");
}

void validation_rejects_invalid_recipes_and_graphs() {
    const auto invalid = [](const std::function<void(Recipe&)>& mutate, const std::string& reason) {
        Recipe recipe;
        mutate(recipe);
        rejects([&] { (void)Generator::compile(recipe); }, reason);
    };
    invalid([](Recipe& r) { r.schema = kHierarchySchemaVersion + 1; }, "unknown schema rejected");
    invalid([](Recipe& r) { r.revision = 0; }, "zero revision rejected");
    invalid([](Recipe& r) { r.chunk_size = 0; }, "zero chunk size rejected");
    invalid([](Recipe& r) { r.chunk_size = -1; }, "negative chunk size rejected");
    invalid([](Recipe& r) { r.chunk_size = 1 << 20; }, "unbounded chunk allocation rejected");
    invalid([](Recipe& r) { r.candidate = static_cast<Candidate>(255); }, "unknown candidate rejected");
    invalid([](Recipe& r) { r.parameters.relief = std::numeric_limits<double>::quiet_NaN(); },
            "NaN parameter rejected");
    invalid([](Recipe& r) { r.parameters.surface_y = std::numeric_limits<double>::infinity(); },
            "infinite parameter rejected");
    invalid([](Recipe& r) { r.parameters.feature_scale = 0.0; }, "zero feature scale rejected");
    invalid([](Recipe& r) { r.parameters.cave_threshold = -0.01; }, "negative cave threshold rejected");
    invalid([](Recipe& r) { r.parameters.cave_threshold = 1.01; }, "excess cave threshold rejected");
    invalid([](Recipe& r) { r.parameters.strata_period = 0.0; }, "zero strata period rejected");
    invalid([](Recipe& r) { r.parameters.detail = 1.01; }, "excess detail fraction rejected");
    invalid([](Recipe& r) { r.parameters.corridor_width = -1.0; }, "negative corridor width rejected");
    invalid([](Recipe& r) { r.themes.weights = {{"does-not-exist", 1.0}}; }, "unknown theme rejected");
    invalid([](Recipe& r) { r.themes.weights = {{"natural", 0.0}}; }, "empty total theme weight rejected");
    invalid([](Recipe& r) { r.themes.weights = {{"natural", -1.0}}; }, "negative theme weight rejected");
    invalid([](Recipe& r) { r.themes.weights = {{"natural", std::numeric_limits<double>::quiet_NaN()}}; },
            "nonfinite theme weight rejected");
    invalid([](Recipe& r) { r.themes.exclude = {"does-not-exist"}; }, "unknown exclusion rejected");
    invalid([](Recipe& r) { r.themes.exclude = {"world"}; }, "selection with every theme excluded rejected");
    invalid([](Recipe& r) { r.limits.max_operations_per_chunk = 0; }, "zero operation capacity rejected");

    auto catalogue = small_catalogue_recipe();
    catalogue.catalogue.push_back(catalogue.catalogue.back());
    rejects([&] { (void)Generator::compile(catalogue); }, "duplicate theme identity rejected");
    catalogue = small_catalogue_recipe();
    catalogue.catalogue[0].parents = {"stone"};
    rejects([&] { (void)Generator::compile(catalogue); }, "theme ancestry cycle rejected");
    catalogue = small_catalogue_recipe();
    catalogue.catalogue.back().parents = {"missing"};
    rejects([&] { (void)Generator::compile(catalogue); }, "unknown theme parent rejected");
    catalogue = small_catalogue_recipe();
    catalogue.catalogue.back().palette.rock = static_cast<Material>(10);
    rejects([&] { (void)Generator::compile(catalogue); }, "reserved material in a theme palette rejected");
    catalogue = small_catalogue_recipe();
    catalogue.limits.max_themes = catalogue.catalogue.size() - 1;
    rejects([&] { (void)Generator::compile(catalogue); }, "theme catalogue capacity cannot truncate definitions");

    auto decorated = decorated_recipe(Candidate::Strata);
    decorated.strokes.push_back(decorated.strokes.front());
    rejects([&] { (void)Generator::compile(decorated); }, "duplicate brush identity rejected");
    decorated = decorated_recipe(Candidate::Strata);
    decorated.paths.push_back(decorated.paths.front());
    rejects([&] { (void)Generator::compile(decorated); }, "duplicate path identity rejected");
    decorated = decorated_recipe(Candidate::Strata);
    decorated.overrides.push_back(decorated.overrides.front());
    rejects([&] { (void)Generator::compile(decorated); }, "duplicate override identity rejected");
    decorated = decorated_recipe(Candidate::Strata);
    decorated.strokes.front().points.front().x = std::numeric_limits<double>::infinity();
    rejects([&] { (void)Generator::compile(decorated); }, "nonfinite brush point rejected");
    decorated = decorated_recipe(Candidate::Strata);
    decorated.strokes.front().radius = 0.0;
    rejects([&] { (void)Generator::compile(decorated); }, "zero brush radius rejected");
    decorated = decorated_recipe(Candidate::Strata);
    decorated.paths.front().material = static_cast<Material>(255);
    rejects([&] { (void)Generator::compile(decorated); }, "invalid guide material rejected");
    decorated = decorated_recipe(Candidate::Strata);
    decorated.overrides.front().bounds.width = 0;
    rejects([&] { (void)Generator::compile(decorated); }, "empty hard override bounds rejected");
    decorated = decorated_recipe(Candidate::Strata);
    decorated.overrides.front().parameters = {{static_cast<Parameter>(255), 0.0}};
    rejects([&] { (void)Generator::compile(decorated); }, "unknown parameter hook rejected");
    decorated = decorated_recipe(Candidate::Strata);
    decorated.overrides.front().parameters = {{Parameter::DistrictSize, 64.0}};
    rejects([&] { (void)Generator::compile(decorated); },
            "spatial hard overrides cannot change the shared global route-grid topology");
    decorated = decorated_recipe(Candidate::Strata);
    decorated.strokes.front().parameters = {{Parameter::DistrictSize, 64.0}};
    rejects([&] { (void)Generator::compile(decorated); },
            "brushes cannot change the shared global route-grid topology");
    catalogue = small_catalogue_recipe();
    catalogue.catalogue.back().parameters = {{Parameter::DistrictSize, 64.0}};
    rejects([&] { (void)Generator::compile(catalogue); },
            "themes cannot change the shared global route-grid topology");

    constexpr std::array<std::size_t Limits::*, 5> limits{
        &Limits::max_strokes, &Limits::max_paths, &Limits::max_overrides,
        &Limits::max_modules, &Limits::max_points_per_path};
    for (const auto member : limits) {
        decorated = decorated_recipe(Candidate::Strata);
        decorated.limits.*member = member == &Limits::max_points_per_path ? 1U : 0U;
        rejects([&] { (void)Generator::compile(decorated); }, "authoring capacity cannot silently truncate inputs");
    }

    Recipe modules;
    modules.modules = {instance("first", "vault", {0, 0, 32, 32}),
                       instance("second", "vault", {0, 0, 32, 32})};
    modules.modules[0].after = {"second"};
    modules.modules[1].after = {"first"};
    rejects([&] { (void)Generator::compile(modules); }, "module dependency cycle rejected");
    modules.modules[0].after.clear();
    modules.modules[1].after = {"missing"};
    rejects([&] { (void)Generator::compile(modules); }, "unknown module dependency rejected");
    modules.modules[1].after.clear();
    modules.modules[1].id = "first";
    rejects([&] { (void)Generator::compile(modules); }, "duplicate module instance rejected");
    modules.modules.resize(1);
    modules.modules[0].module = "missing";
    rejects([&] { (void)Generator::compile(modules); }, "unavailable module rejected");
    modules.modules[0].module = "vault";
    modules.modules[0].version = 400;
    rejects([&] { (void)Generator::compile(modules); }, "unsupported module version rejected");
}

void registry_refusals_and_coordinate_domain() {
    ModuleRegistry registry;
    add_sampler(registry, "once", [](const ModuleContext&, Material) { return Material::Metal; });
    rejects([&] { add_sampler(registry, "once", [](const ModuleContext&, Material) { return Material::Glass; }); },
            "duplicate module factories rejected");
    rejects([&] { (void)registry.find("missing", 1); }, "missing module lookup rejected");
    rejects([&] { (void)registry.find("once", 2); }, "module version mismatch rejected");
    ModuleFactory no_factory;
    no_factory.id = "missing-prepare";
    rejects([&] { registry.add(no_factory); }, "empty module factory rejected");
    rejects([&] { add_sampler(registry, "", [](const ModuleContext&, Material) { return Material::Metal; }); },
            "empty module identity rejected");
    rejects([&] { add_sampler(registry, "free", [](const ModuleContext&, Material) { return Material::Metal; }, 0); },
            "zero declared module cost rejected");

    ModuleFactory null_factory;
    null_factory.id = "null";
    null_factory.prepare = [](const ModuleInstance&, std::uint64_t) -> std::shared_ptr<const FeatureSampler> {
        return {};
    };
    registry.add(std::move(null_factory));
    Recipe bad;
    bad.modules.push_back(instance("null-instance", "null", {0, 0, 32, 32}));
    rejects([&] { (void)Generator::compile(bad, registry); }, "null prepared sampler rejected");

    Recipe recipe;
    recipe.chunk_size = 32;
    const auto generator = Generator::compile(recipe);
    rejects([&] { (void)generator->sample(kCoordinateLimit + 1, 0); },
            "unsupported large positive coordinate fails explicitly");
    rejects([&] { (void)generator->sample(-kCoordinateLimit - 1, 0); },
            "unsupported large negative coordinate fails explicitly");
    rejects([&] { (void)generator->begin({std::numeric_limits<std::int64_t>::max(), 0}); },
            "overflowing chunk origin is rejected before arithmetic or allocation");
    rejects([&] { (void)generator->begin({std::numeric_limits<std::int64_t>::min(), 0}); },
            "negative overflowing chunk origin is rejected before arithmetic or allocation");
    const auto negative_edge = generator->generate({-kCoordinateLimit / 32, 0});
    const auto positive_edge = generator->generate({kCoordinateLimit / 32 - 1, 0});
    require(negative_edge.state == ResultState::Ready && positive_edge.state == ResultState::Ready,
            "complete chunks within the documented exact geometry domain remain supported");
    Recipe outside;
    HardOverride override;
    override.id = "out-of-range";
    override.bounds = {kCoordinateLimit, 0, 2, 2};
    override.material = Material::Metal;
    outside.overrides.push_back(override);
    rejects([&] { (void)Generator::compile(outside); }, "out-of-range authored rectangle rejected");
}

} // namespace

int main() {
    try {
        deterministic_order_and_partition();
        candidates_seeds_and_compiled_ownership();
        normalized_themes_and_global_exclusions();
        brush_falloff_and_parameter_precedence();
        unchanged_theme_parameters_remain_exact();
        canonical_controls_and_hard_material_precedence();
        connected_guides_and_candidate_overrides();
        module_order_domain_and_preparation();
        macro_routes_survive_structure_modules();
        incremental_jobs_lifetimes_and_stale_results();
        module_failures_and_work_budget();
        validation_rejects_invalid_recipes_and_graphs();
        registry_refusals_and_coordinate_domain();
        std::cout << "PASS procedural generation: candidate/order/partition determinism, signed seams, "
                     "theme hierarchy/exclusions, broad/fine/hard controls, bounded modules, "
                     "incremental ownership/cancel/stale identity, invalid input and capacity controls\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "FAIL procedural generation: " << error.what() << '\n';
        return 1;
    }
}
