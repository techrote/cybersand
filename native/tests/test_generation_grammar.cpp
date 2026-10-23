#include "cybersand/generation_grammar.hpp"
#include "cybersand/world_generation.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <deque>
#include <iostream>
#include <limits>
#include <map>
#include <random>
#include <set>
#include <source_location>
#include <stdexcept>
#include <string>
#include <string_view>
#include <thread>
#include <vector>

namespace {
using namespace cybersand;
using namespace cybersand::generation;

std::uint64_t assertions = 0;
void require(bool value, const std::string& reason) {
    ++assertions;
    if (!value) throw std::runtime_error(reason);
}
template<class Action>
std::string rejection(Action&& action, std::source_location location = std::source_location::current()) {
    try { action(); }
    catch (const std::exception& error) { return error.what(); }
    throw std::runtime_error("expected deterministic rejection at line " + std::to_string(location.line()));
}

GrammarCandidate candidate(std::string id, RectI64 bounds, std::uint32_t ox = 0, std::uint32_t oy = 0) {
    GrammarCandidate value;
    value.id = std::move(id);
    value.bounds = bounds;
    value.order_x = ox;
    value.order_y = oy;
    return value;
}
GrammarRule room(std::string id, RectI64 bounds) {
    GrammarRule value;
    value.id = std::move(id);
    value.kind = SemanticKind::Room;
    value.candidates = {candidate("fixed", bounds)};
    value.material = Material::Concrete;
    value.interior = Material::Empty;
    value.wall_thickness = 1;
    return value;
}
GrammarDefinition flat() {
    GrammarDefinition result;
    result.id = "acceptance";
    result.region_size = 64;
    result.region_window = {0, 0, 1, 1};
    result.roots = {"hall"};
    result.rules = {room("hall", {2, 2, 60, 60})};
    return result;
}
bool contains(RectI64 a, RectI64 b) {
    return b.x >= a.x && b.y >= a.y && b.width <= a.width && b.height <= a.height &&
           b.x - a.x <= a.width - b.width && b.y - a.y <= a.height - b.height;
}
bool intersects(RectI64 a, RectI64 b) {
    return a.x < b.x + b.width && b.x < a.x + a.width &&
           a.y < b.y + b.height && b.y < a.y + a.height;
}
bool same_bounds(RectI64 a, RectI64 b) {
    return a.x == b.x && a.y == b.y && a.width == b.width && a.height == b.height;
}
const SemanticFeature& by_rule(const GrammarPlan& plan, std::string_view id) {
    auto found = std::find_if(plan.features().begin(), plan.features().end(),
                              [&](const auto& value) { return value.rule_id == id; });
    if (found == plan.features().end()) throw std::runtime_error("missing feature for rule " + std::string(id));
    return *found;
}
void same_feature(const SemanticFeature& a, const SemanticFeature& b) {
    require(a.id == b.id && a.parent == b.parent && a.rule_id == b.rule_id &&
                a.candidate_id == b.candidate_id && a.kind == b.kind &&
                same_bounds(a.bounds, b.bounds) && a.owner == b.owner &&
                a.seed == b.seed && a.revision == b.revision && a.order == b.order &&
                a.priority == b.priority && a.children == b.children && a.tags == b.tags &&
                a.parameters == b.parameters && a.allowed_materials == b.allowed_materials &&
                a.sockets == b.sockets && a.material == b.material && a.interior == b.interior &&
                a.wall_thickness == b.wall_thickness && a.aggregate == b.aggregate &&
                a.application == b.application && a.exclusion == b.exclusion,
            "semantic record changed with declaration or planning partition");
    require(a.themes.size() == b.themes.size(), "theme count is stable");
    for (std::size_t i = 0; i < a.themes.size(); ++i)
        require(a.themes[i].id == b.themes[i].id && a.themes[i].weight == b.themes[i].weight,
                "theme blend record is stable");
}
std::size_t count_rule(const GrammarPlan& plan, const std::string& id) {
    return static_cast<std::size_t>(std::count_if(plan.features().begin(), plan.features().end(),
        [&](const auto& value) { return value.rule_id == id; }));
}

void hierarchy_queries_and_stable_identity() {
    auto definition = flat();
    auto chamber = room("chamber", {4, 4, 40, 40});
    chamber.kind = SemanticKind::Complex;
    chamber.tags = {"habitat", "industrial"};
    chamber.themes = {{"foundry", 3}, {"garden", 1}};
    chamber.parameters["pressure"] = {SpatialType::Scalar, 2.5};
    chamber.allowed_materials = {Material::Concrete, Material::Empty};
    auto apparatus = room("apparatus", {4, 4, 8, 8});
    apparatus.kind = SemanticKind::Apparatus;
    apparatus.material = Material::Copper;
    definition.rules[0].kind = SemanticKind::District;
    definition.rules[0].children = {"chamber"};
    chamber.children = {"apparatus"};
    definition.rules.push_back(chamber);
    definition.rules.push_back(apparatus);
    definition.region_window = {-1, -1, 2, 2};
    const auto plan = GrammarPlan::compile(definition, 191);
    require(plan->features().size() >= 16, "multiple regions contain all nested places");
    require(count_rule(*plan, "hall") == 4 && count_rule(*plan, "chamber") == 4 &&
                count_rule(*plan, "apparatus") == 4, "each canonical region has exactly one nested rule instance");
    std::set<std::string> identities;
    for (const auto& feature : plan->features()) {
        require(identities.insert(feature.id).second, "feature has exactly one semantic owner");
        require(plan->feature(feature.id) == &feature, "query returns immutable owned feature");
        if (!feature.parent.empty()) {
            const auto* parent = plan->feature(feature.parent);
            require(parent && contains(parent->bounds, feature.bounds), "child lies within its parent");
            require(std::find(parent->children.begin(), parent->children.end(), feature.id) != parent->children.end(),
                    "parent/child links are reciprocal");
        }
        const auto ancestry = plan->ancestry(feature.id);
        require(!ancestry.empty() && std::find(ancestry.begin(), ancestry.end(), feature.id) != ancestry.end(),
                "ancestry preserves the queried identity");
        if (feature.rule_id == "apparatus") require(ancestry.size() >= 4, "nested apparatus exposes complete ancestry");
    }
    for (RectI64 query : {RectI64{-64, -64, 32, 32}, RectI64{-1, -1, 2, 2}, RectI64{127, 127, 1, 1}}) {
        std::set<std::string> expected, observed;
        for (const auto& feature : plan->features()) if (intersects(query, feature.bounds)) expected.insert(feature.id);
        for (const auto* feature : plan->query(query)) observed.insert(feature->id);
        require(observed == expected, "bounded semantic query equals independent rectangle overlap");
    }
    require(plan->feature("missing") == nullptr, "unknown feature lookup is explicit");
    auto reordered = definition;
    std::reverse(reordered.roots.begin(), reordered.roots.end());
    std::reverse(reordered.rules.begin(), reordered.rules.end());
    for (auto& rule : reordered.rules) {
        std::reverse(rule.tags.begin(), rule.tags.end());
        std::reverse(rule.themes.begin(), rule.themes.end());
        std::reverse(rule.children.begin(), rule.children.end());
        std::reverse(rule.candidates.begin(), rule.candidates.end());
    }
    const auto reordered_plan = GrammarPlan::compile(reordered, 191);
    require(reordered_plan->fingerprint() == plan->fingerprint(), "declaration reorder preserves canonical receipt");
    for (const auto& feature : plan->features()) same_feature(feature, *reordered_plan->feature(feature.id));
    auto unrelated = definition;
    auto extra = room("unrelated", {48, 48, 8, 8});
    extra.kind = SemanticKind::Detail;
    unrelated.rules.push_back(extra);
    unrelated.roots.push_back("unrelated");
    const auto enlarged = GrammarPlan::compile(unrelated, 191);
    require(enlarged->fingerprint() != plan->fingerprint(), "new authored feature changes recipe receipt");
    for (const auto& feature : plan->features()) {
        const auto* retained = enlarged->feature(feature.id);
        require(retained && retained->seed == feature.seed, "unrelated feature does not renumber existing identities/seeds");
        if (feature.kind != SemanticKind::Region) same_feature(feature, *retained);
    }
    auto renamed = definition;
    renamed.rules[2].id = "new-apparatus";
    renamed.rules[1].children = {"new-apparatus"};
    const auto replaced = GrammarPlan::compile(renamed, 191);
    require(!replaced->feature(by_rule(*plan, "apparatus").id), "authored rule rename deliberately replaces identity");
    definition.rules[2].material = Material::Metal;
    const auto edited = GrammarPlan::compile(definition, 191);
    const auto& original = by_rule(*plan, "apparatus");
    const auto* changed = edited->feature(original.id);
    require(changed && changed->seed == original.seed && changed->revision != original.revision,
            "material edit changes revision while preserving semantic identity/seed");
    require(plan->feature(original.id)->material == Material::Copper, "compiled plan is immutable after caller mutation");
    auto regridded = definition; regridded.region_size = 128;
    const auto new_grid = GrammarPlan::compile(regridded, 191);
    require(!new_grid->feature(original.id), "ownership-grid change deliberately replaces affected semantic identities");
}

void independent_regions_and_boundaries() {
    auto definition = flat();
    definition.region_window = {-1, -1, 2, 2};
    const auto whole = GrammarPlan::compile(definition, 334);
    std::set<std::string> owners;
    for (std::int64_t ry = -1; ry <= 0; ++ry) for (std::int64_t rx = -1; rx <= 0; ++rx) {
        auto part = definition;
        part.region_window = {rx, ry, 1, 1};
        const auto region = GrammarPlan::compile(part, 334);
        for (const auto& feature : region->features()) {
            require(feature.owner == spatial::RegionId{rx, ry}, "finite request does not adopt a neighboring owner");
            require(owners.insert(feature.id).second, "partition has no duplicate feature owners");
            const auto* expected = whole->feature(feature.id);
            require(expected != nullptr, "independent request discovers canonical feature without owner chunk");
            same_feature(*expected, feature);
        }
        for (const auto& route : region->routes()) {
            auto found = std::find_if(whole->routes().begin(), whole->routes().end(),
                                     [&](const auto& other) { return other.id == route.id; });
            require(found != whole->routes().end() && found->type == route.type && found->width == route.width &&
                        found->owner == route.owner && found->from_socket == route.from_socket &&
                        found->to_socket == route.to_socket && found->points.size() == route.points.size(),
                    "route topology agrees across independent planning windows");
            for (std::size_t i = 0; i < route.points.size(); ++i)
                require(route.points[i].x == found->points[i].x && route.points[i].y == found->points[i].y,
                        "route geometry agrees across planning windows");
        }
    }
    require(owners.size() == whole->features().size(), "independent partitions cover the whole semantic plan exactly");
    for (const auto shift : {std::int64_t{-1}, std::int64_t{0}, std::int64_t{1}, std::int64_t{-131072}}) {
        auto left = flat(), right = flat();
        left.region_window = {shift, -1, 1, 1}; right.region_window = {shift + 1, -1, 1, 1};
        const auto a = GrammarPlan::compile(left, 991), b = GrammarPlan::compile(right, 991);
        std::size_t matches = 0;
        const auto edge_x = (shift + 1) * 64;
        for (const auto& port : a->sockets()) {
            if (!port.shared || port.x != edge_x) continue;
            const auto counterpart = std::find_if(b->sockets().begin(), b->sockets().end(), [&](const auto& other) {
                return other.shared && other.id == port.id && other.x == port.x && other.y == port.y &&
                       other.type == port.type && other.width == port.width && other.direction == port.direction &&
                       other.owner == port.owner;
            });
            require(counterpart != b->sockets().end(), "neighbor alone discovers identical canonical shared port record");
            ++matches;
        }
        require(matches > 0, "negative and positive shared boundaries have actual canonical ports");
    }
}

void bounded_constraints_and_failures() {
    // Two independently declared neighboring features require one another;
    // declaration/priority order must not turn final-plan checks into partial observations.
    auto neighbors = flat();
    neighbors.roots = {"a", "b"};
    auto a = room("a", {8, 8, 8, 8}), b = room("b", {20, 8, 8, 8});
    a.tags = {"first"}; b.tags = {"second"};
    a.constraints.required_neighbors = {"second"};
    b.constraints.required_neighbors = {"first"};
    a.constraints.neighbor_distance = 8; b.constraints.neighbor_distance = 8;
    neighbors.rules = {a, b};
    require(count_rule(*GrammarPlan::compile(neighbors, 191), "a") == 1,
            "mutual required neighbors validate against complete immutable plan");
    auto impossible = neighbors;
    impossible.rules[0].constraints.forbidden_neighbors = {"second"};
    const auto contradiction = rejection([&] { (void)GrammarPlan::compile(impossible, 191); });
    require(!contradiction.empty() && rejection([&] { (void)GrammarPlan::compile(impossible, 191); }) == contradiction,
            "contradictory neighborhood constraints reject deterministically");
    impossible = neighbors;
    impossible.rules[0].constraints.neighbor_distance = 1;
    (void)rejection([&] { (void)GrammarPlan::compile(impossible, 191); });
    ++assertions;

    auto quota = flat();
    quota.rules[0] = room("hall", {8, 8, 8, 8});
    quota.rules[0].count = 2;
    quota.rules[0].candidates.push_back(candidate("second", {24, 8, 8, 8}, 1, 0));
    quota.rules[0].constraints.open_volume = true;
    quota.rules[0].constraints.minimum_separation = 4;
    quota.rules[0].constraints.occupancy_min = 0.03;
    quota.rules[0].constraints.occupancy_max = 0.04;
    const auto occupied = GrammarPlan::compile(quota, 191);
    require(count_rule(*occupied, "hall") == 2, "exact multiplicity emits two distinct slots");
    std::set<std::pair<std::int64_t, std::int64_t>> boxes;
    double area = 0;
    for (const auto& feature : occupied->features()) if (feature.rule_id == "hall") {
        boxes.emplace(feature.bounds.x, feature.bounds.y);
        area += static_cast<double>(feature.bounds.width * feature.bounds.height);
    }
    require(boxes.size() == 2 && area / (64 * 64) == 0.03125,
            "occupancy is measured from actual selected areas and distinct geometry");
    impossible = quota; impossible.rules[0].constraints.occupancy_min = 0.05;
    impossible.rules[0].constraints.occupancy_max = 0.1;
    (void)rejection([&] { (void)GrammarPlan::compile(impossible, 191); }); ++assertions;
    impossible = quota; impossible.rules[0].constraints.minimum_separation = 9;
    (void)rejection([&] { (void)GrammarPlan::compile(impossible, 191); }); ++assertions;
    impossible = quota; impossible.rules[0].count = 3;
    (void)rejection([&] { (void)GrammarPlan::compile(impossible, 191); }); ++assertions;

    auto competing = flat();
    a = room("alpha", {8, 8, 8, 8}); b = room("beta", {8, 8, 8, 8});
    a.priority = 10; b.priority = 1;
    a.constraints.open_volume = b.constraints.open_volume = true;
    a.constraints.exclusive_family = b.constraints.exclusive_family = "exclusive";
    b.fallback = GrammarFallback::Omit;
    competing.rules = {b, a}; competing.roots = {"beta", "alpha"};
    const auto chosen = GrammarPlan::compile(competing, 191);
    require(count_rule(*chosen, "alpha") == 1 && count_rule(*chosen, "beta") == 0,
            "higher priority wins constrained placement competition");
    require(std::any_of(chosen->receipts().begin(), chosen->receipts().end(), [](const auto& receipt) {
        return receipt.rule_id == "beta" && receipt.fallback && !receipt.passed;
    }), "authored omission retains failed hard-constraint receipt");
    impossible = competing; impossible.rules[0].fallback = GrammarFallback::Reject;
    (void)rejection([&] { (void)GrammarPlan::compile(impossible, 191); }); ++assertions;
    std::reverse(competing.rules.begin(), competing.rules.end());
    std::reverse(competing.roots.begin(), competing.roots.end());
    const auto chosen_again = GrammarPlan::compile(competing, 191);
    require(chosen->fingerprint() == chosen_again->fingerprint(), "competition and fallback are independent of declaration order");
    for (const auto& feature : chosen->features()) same_feature(feature, *chosen_again->feature(feature.id));

    auto supported = flat();
    supported.rules[0].children = {"supported"};
    auto child = room("supported", {4, 51, 8, 8});
    child.kind = SemanticKind::Apparatus;
    child.constraints.floor = true;
    supported.rules.push_back(child);
    require(count_rule(*GrammarPlan::compile(supported, 191), "supported") == 1,
            "floor requirement accepts contact with declared parent solid shell");
    impossible = supported; impossible.rules[1].candidates[0].bounds.y -= 1;
    (void)rejection([&] { (void)GrammarPlan::compile(impossible, 191); }); ++assertions;
    supported.rules[1].constraints.floor = false;
    supported.rules[1].constraints.ceiling = true;
    supported.rules[1].candidates[0].bounds.y = 1;
    require(count_rule(*GrammarPlan::compile(supported, 191), "supported") == 1, "ceiling support is geometric");
    supported.rules[1].constraints.ceiling = false;
    supported.rules[1].constraints.wall = true;
    supported.rules[1].candidates[0].bounds.x = 1;
    supported.rules[1].candidates[0].bounds.y = 12;
    require(count_rule(*GrammarPlan::compile(supported, 191), "supported") == 1, "wall support is geometric");
    impossible = supported; impossible.rules[1].candidates[0].bounds.x = 2;
    (void)rejection([&] { (void)GrammarPlan::compile(impossible, 191); }); ++assertions;

    auto sockets = flat();
    sockets.rules[0].candidates[0].bounds = {4, 4, 56, 56};
    GrammarSocket west;
    west.id = "west"; west.direction = SocketDirection::West; west.offset = 28;
    GrammarSocket east = west; east.id = "east"; east.direction = SocketDirection::East;
    sockets.rules[0].sockets = {west, east};
    sockets.rules[0].constraints.minimum_sockets = 2;
    sockets.rules[0].constraints.maximum_sockets = 2;
    sockets.rules[0].constraints.connected = true;
    const auto attached = GrammarPlan::compile(sockets, 191);
    const auto& hall = by_rule(*attached, "hall");
    require(hall.sockets.size() == 2, "required socket count comes from emitted feature sockets");
    for (const auto& socket : attached->sockets()) if (socket.feature_id == hall.id) {
        require(!socket.matched.empty() && socket.width >= sockets.clearance,
                "attached passage sockets expose compatible matching and clearance");
    }
    impossible = sockets; impossible.rules[0].sockets.pop_back();
    (void)rejection([&] { (void)GrammarPlan::compile(impossible, 191); }); ++assertions;
    impossible = sockets; impossible.rules[0].sockets[0].offset = 60;
    (void)rejection([&] { (void)GrammarPlan::compile(impossible, 191); }); ++assertions;
    impossible = sockets; impossible.rules[0].sockets[0].width = 1;
    (void)rejection([&] { (void)GrammarPlan::compile(impossible, 191); }); ++assertions;
    impossible = sockets; impossible.rules[0].sockets[0].type = "unregistered-connector";
    (void)rejection([&] { (void)GrammarPlan::compile(impossible, 191); }); ++assertions;
    impossible = sockets; impossible.rules[0].sockets[0].attach_to_route = false;
    (void)rejection([&] { (void)GrammarPlan::compile(impossible, 191); }); ++assertions;

    auto service = flat();
    service.rules[0].constraints.service = "service";
    service.rules[0].constraints.neighbor_distance = 0;
    require(count_rule(*GrammarPlan::compile(service, 191), "hall") == 1,
            "service requirement consumes declared immutable service geometry");
    service.service_trunk = false;
    (void)rejection([&] { (void)GrammarPlan::compile(service, 191); }); ++assertions;
    service.rules[0].constraints.service = "liquid";
    service.liquid_trunk = true;
    require(count_rule(*GrammarPlan::compile(service, 191), "hall") == 1,
            "liquid requirement consumes separately typed declared geometry");

    auto valid = flat();
    std::vector<GrammarDefinition> invalid;
    invalid.push_back(valid); invalid.back().schema = 99;
    invalid.push_back(valid); invalid.back().id.clear();
    invalid.push_back(valid); invalid.back().region_size = 0;
    invalid.push_back(valid); invalid.back().region_window.width = 0;
    invalid.push_back(valid); invalid.back().region_window.width = 17;
    invalid.push_back(valid); invalid.back().roots = {"absent"};
    invalid.push_back(valid); invalid.back().rules.push_back(valid.rules[0]);
    invalid.push_back(valid); invalid.back().rules[0].children = {"hall"};
    invalid.push_back(valid); invalid.back().rules[0].children = {"absent"};
    invalid.push_back(valid); invalid.back().rules[0].candidates[0].bounds.width = 0;
    invalid.push_back(valid); invalid.back().rules[0].candidates[0].bounds = {-1, 2, 8, 8};
    invalid.push_back(valid); invalid.back().rules[0].constraints.occupancy_min = 0.5;
    invalid.back().rules[0].constraints.occupancy_max = 0.25;
    invalid.push_back(valid); invalid.back().rules[0].constraints.minimum_separation = -1;
    invalid.push_back(valid); invalid.back().rules[0].constraints.minimum_sockets = 3;
    invalid.back().rules[0].constraints.maximum_sockets = 2;
    invalid.push_back(valid); invalid.back().rules[0].candidates.push_back(valid.rules[0].candidates[0]);
    invalid.push_back(valid); invalid.back().rules[0].kind = static_cast<SemanticKind>(255);
    invalid.push_back(valid); invalid.back().curve = static_cast<GrammarCurve>(255);
    invalid.push_back(valid); invalid.back().clearance = valid.route_width + 2;
    invalid.push_back(valid); invalid.back().rules[0].material = static_cast<Material>(255);
    invalid.push_back(valid); invalid.back().rules[0].allowed_materials = {Material::Copper};
    invalid.push_back(valid); invalid.back().limits.max_features = 1;
    invalid.push_back(valid); invalid.back().limits.max_routes = 1;
    invalid.push_back(valid); invalid.back().limits.max_sockets = 1;
    invalid.push_back(valid); invalid.back().limits.max_depth = 0;
    invalid.push_back(valid); invalid.back().limits.max_prepared_bytes = 1;
    invalid.push_back(valid); invalid.back().limits.max_work = 1;
    for (std::size_t i = 0; i < invalid.size(); ++i) {
        const auto error = rejection([&] { (void)GrammarPlan::compile(invalid[i], 191); });
        require(!error.empty() && error == rejection([&] { (void)GrammarPlan::compile(invalid[i], 191); }),
                "invalid or exhausted grammar deterministically rejects, case " + std::to_string(i));
    }
    auto unreachable_cycle = flat();
    auto unused = room("unused", {1, 1, 4, 4}); unused.children = {"unused"};
    unreachable_cycle.rules.push_back(unused);
    (void)rejection([&] { (void)GrammarPlan::compile(unreachable_cycle, 191); });
    ++assertions;
}

Recipe integration_recipe(Candidate kind = Candidate::Strata) {
    Recipe recipe;
    recipe.schema = kHierarchySchemaVersion;
    recipe.seed = 191;
    recipe.chunk_size = 16;
    recipe.candidate = kind;
    recipe.grammar = flat();
    recipe.grammar.region_window = {-1, -1, 2, 2};
    auto apparatus = room("machine", {8, 8, 8, 8});
    apparatus.kind = SemanticKind::Apparatus;
    apparatus.material = Material::Copper;
    recipe.grammar.rules[0].children = {"machine"};
    recipe.grammar.rules.push_back(apparatus);
    recipe.parameters.surface_y = 0;
    recipe.parameters.relief = 0;
    return recipe;
}
using CellKey = std::pair<std::int64_t, std::int64_t>;
using CellMap = std::map<CellKey, Material>;
CellMap generate_rectangle(const Generator& generator, int size, bool reverse, std::size_t budget) {
    std::vector<ChunkCoord> coordinates;
    for (std::int64_t y = -64 / size; y < 64 / size; ++y)
        for (std::int64_t x = -64 / size; x < 64 / size; ++x) coordinates.push_back({x, y});
    if (reverse) std::reverse(coordinates.begin(), coordinates.end());
    else std::shuffle(coordinates.begin(), coordinates.end(), std::mt19937(191));
    CellMap output;
    for (const auto& coord : coordinates) {
        auto job = generator.begin(coord);
        while (job->state() == ResultState::Pending) (void)job->advance(budget);
        const auto& packet = job->result();
        require(packet.state == ResultState::Ready && generator.accepts(packet), "complete chunk receipt accepts after paced generation");
        for (std::int64_t y = 0; y < size; ++y) for (std::int64_t x = 0; x < size; ++x)
            output.emplace(CellKey{coord.x * size + x, coord.y * size + y},
                           packet.cells[static_cast<std::size_t>(y * size + x)]);
    }
    return output;
}
std::set<CellKey> clear_centres(const CellMap& cells, int width) {
    const auto half = width / 2;
    std::set<CellKey> result;
    for (const auto& [position, material] : cells) {
        if (material != Material::Empty) continue;
        bool clear = true;
        for (int y = -half; y <= half && clear; ++y) for (int x = -half; x <= half; ++x) {
            const auto found = cells.find({position.first + x, position.second + y});
            if (found != cells.end() && found->second != Material::Empty) { clear = false; break; }
        }
        if (clear) result.insert(position);
    }
    return result;
}
void native_raster_invariance_and_clearance() {
    for (const auto kind : {Candidate::Strata, Candidate::FlowNetwork, Candidate::DistrictGrammar}) {
        auto recipe = integration_recipe(kind);
        const auto generator = Generator::compile(recipe);
        require(generator->semantic_plan() != nullptr, "schema 3 retains immutable semantic plan");
        const auto reference = generate_rectangle(*generator, 16, false, 17);
        for (int size : {8, 32, 64}) {
            auto partition = recipe;
            partition.chunk_size = size;
            const auto other = Generator::compile(partition);
            require(reference == generate_rectangle(*other, size, true, size == 8 ? 1U : 31U),
                    "complete material rectangle is invariant under chunks, negative coordinates, order and budgets");
            for (const auto& feature : generator->semantic_plan()->features())
                same_feature(feature, *other->semantic_plan()->feature(feature.id));
        }
        // The source field/budget/placement mechanisms are exercised through all
        // three candidate strategies; worker queries share only immutable inputs.
        std::atomic<bool> success{true};
        std::array<std::thread, 4> workers;
        for (std::size_t w = 0; w < workers.size(); ++w) workers[w] = std::thread([&, w] {
            for (std::size_t i = w; i < 64; i += workers.size()) {
                const ChunkCoord coord{static_cast<std::int64_t>(i % 8) - 4, static_cast<std::int64_t>(i / 8) - 4};
                const auto packet = generator->generate(coord);
                if (packet.state != ResultState::Ready || !generator->accepts(packet)) { success = false; continue; }
                for (std::int64_t y = 0; y < 16; ++y) for (std::int64_t x = 0; x < 16; ++x)
                    if (packet.cells[static_cast<std::size_t>(y * 16 + x)] != reference.at({coord.x * 16 + x, coord.y * 16 + y}))
                        success = false;
            }
        });
        for (auto& worker : workers) worker.join();
        require(success, "four-worker material requests match single-worker full rectangle");
        const auto centres = clear_centres(reference, static_cast<int>(recipe.grammar.clearance));
        const auto& validation = generator->validate_routes();
        require(validation.passed && validation.profile == "floating-square-v1" &&
                    validation.clearance == recipe.grammar.clearance && !validation.routes.empty(),
                "native final-raster traversal is explicitly qualified for a geometric profile");
        std::set<CellKey> required;
        for (const auto& route : generator->semantic_plan()->routes()) {
            if (!route.required || route.type != "passage") continue;
            for (std::size_t i = 1; i < route.points.size(); ++i) {
                auto x = static_cast<std::int64_t>(route.points[i - 1].x);
                auto y = static_cast<std::int64_t>(route.points[i - 1].y);
                const auto tx = static_cast<std::int64_t>(route.points[i].x);
                const auto ty = static_cast<std::int64_t>(route.points[i].y);
                require(x == tx || y == ty, "physical routes use explicit orthogonal edges");
                const auto dx = (tx > x) - (tx < x), dy = (ty > y) - (ty < y);
                for (;;) {
                    if (reference.contains({x, y})) {
                        require(centres.contains({x, y}), "independent square-footprint oracle clears every required route centre");
                        required.emplace(x, y);
                    }
                    if (x == tx && y == ty) break;
                    x += dx; y += dy;
                }
            }
        }
        require(!required.empty(), "fixture contains physically rasterized required routes");
        std::set<CellKey> reached{*required.begin()};
        std::deque<CellKey> queue{*required.begin()};
        while (!queue.empty()) {
            const auto [x, y] = queue.front(); queue.pop_front();
            for (const auto& step : {CellKey{-1, 0}, CellKey{1, 0}, CellKey{0, -1}, CellKey{0, 1}}) {
                const CellKey next{x + step.first, y + step.second};
                if (centres.contains(next) && reached.insert(next).second) queue.push_back(next);
            }
        }
        for (const auto& position : required) require(reached.contains(position),
            "independent flood fill connects primary routes and secondary loops through shared region boundaries");
    }
}

void override_provenance_and_transactionality() {
    auto recipe = integration_recipe();
    FieldNode one; one.id = "one"; one.kind = FieldKind::Constant; one.parameters = {{"value", 1}};
    recipe.fields = {one};
    SpatialNode position; position.id = "absolute-x"; position.kind = SpatialKind::CoordinateX;
    SpatialNode routes; routes.id = "route-distance"; routes.kind = SpatialKind::GeometryDistance; routes.reference = "route-fixture";
    recipe.spatial.nodes = {position, routes};
    const auto declared = GrammarPlan::compile(recipe.grammar, recipe.seed);
    const auto exported = std::find_if(declared->routes().begin(), declared->routes().end(), [](const auto& r) {
        return r.required && r.type == "passage" && r.points.size() >= 2;
    });
    require(exported != declared->routes().end(), "fixture declares an exportable route");
    recipe.grammar.geometry_exports["route-fixture"] = exported->id;
    auto generator = Generator::compile(recipe);
    const auto canonical = Generator::compile(generator->recipe());
    require(canonical->fingerprint() == generator->fingerprint(), "canonical recipe recompiles without duplicating semantic geometry inputs");
    const auto& plan = *generator->semantic_plan();
    auto route = std::find_if(plan.routes().begin(), plan.routes().end(), [](const auto& r) {
        return r.required && r.type == "passage" && r.points.size() >= 2;
    });
    require(route != plan.routes().end(), "provenance fixture has explicit required route");
    auto x = static_cast<std::int64_t>(route->points.front().x);
    auto y = static_cast<std::int64_t>(route->points.front().y);
    // Select a known in-window centre, independent of implementation failure
    // diagnostics, then deliberately replace it using final material authority.
    const auto bounds = plan.bounds();
    for (const auto& point : route->points) {
        if (point.x >= static_cast<double>(bounds.x) && point.y >= static_cast<double>(bounds.y) &&
            point.x < static_cast<double>(bounds.x + bounds.width) && point.y < static_cast<double>(bounds.y + bounds.height)) {
            x = static_cast<std::int64_t>(point.x); y = static_cast<std::int64_t>(point.y); break;
        }
    }
    const auto before = generator->explain(x, y);
    require(before.material == Material::Empty && before.material == generator->sample(x, y),
            "material provenance matches final output on a route");
    require(std::find_if(before.scalar_fields.begin(), before.scalar_fields.end(), [](const auto& value) {
        return value.first == "one" && value.second == 1;
    }) != before.scalar_fields.end(), "provenance exports scalar field inputs");
    require(std::find_if(before.typed_fields.begin(), before.typed_fields.end(), [&](const auto& value) {
        return value.first == "absolute-x" && value.second.type == SpatialType::Scalar && value.second.x == static_cast<double>(x);
    }) != before.typed_fields.end(), "provenance exports typed field inputs");
    require(generator->spatial_graph().sample("route-distance", x, y).x == 0,
            "typed geometry input comes from pre-raster semantic route geometry");
    HardOverride final;
    final.id = "deliberate-blocker"; final.bounds = {x, y, 1, 1}; final.material = Material::Metal;
    recipe.overrides = {final};
    const auto blocked = Generator::compile(recipe);
    require(blocked->sample(x, y) == Material::Metal, "final override is preserved even when it blocks a required route");
    const auto& report = blocked->validate_routes();
    require(!report.passed && std::any_of(report.routes.begin(), report.routes.end(), [](const auto& row) {
        return !row.passed && row.blocked_centres > 0;
    }), "required route conflict is explicit after final override");
    const auto explanation = blocked->explain(x, y);
    require(explanation.material == Material::Metal && std::any_of(explanation.contributions.begin(), explanation.contributions.end(), [](const auto& c) {
        return c.id == "deliberate-blocker" && c.after == Material::Metal;
    }), "cell provenance identifies final override decision");
    require(!explanation.contributions.empty() && explanation.contributions.back().after == Material::Metal,
            "last provenance contribution agrees with final material authority");
    const auto& apparatus = by_rule(*generator->semantic_plan(), "machine");
    auto feature_trace = generator->explain(apparatus.bounds.x, apparatus.bounds.y);
    require(std::find(feature_trace.ancestry.begin(), feature_trace.ancestry.end(), apparatus.id) != feature_trace.ancestry.end(),
            "feature provenance retains apparatus ancestry");
    require(!feature_trace.constraints.empty(), "feature provenance retains constraint outcomes");

    auto job = generator->begin({0, 0});
    (void)job->advance(3);
    (void)rejection([&] { (void)job->result(); }); ++assertions;
    job->cancel();
    require(job->result().state == ResultState::Cancelled && job->result().cells.empty() &&
                job->result().content_hash == 0 && job->result().receipt_hash == 0,
            "cancelled material preparation publishes no partial packet");
    auto exhausted = recipe; exhausted.grammar.limits.max_raster_cells = 1;
    (void)rejection([&] { (void)Generator::compile(exhausted); }); ++assertions;
    exhausted = recipe; exhausted.limits.max_operations_per_chunk = 1;
    auto tiny = Generator::compile(exhausted)->begin({0, 0});
    require(tiny->state() == ResultState::Failed && tiny->result().cells.empty() && tiny->completed_cells() == 0,
            "insufficient chunk budget fails before partial material publication");
    auto invalid_schema = recipe; invalid_schema.schema = kTypedSchemaVersion;
    (void)rejection([&] { (void)Generator::compile(invalid_schema); }); ++assertions;
    require(generator->validate_routes().passed && generator->sample(x, y) == Material::Empty,
            "failed/replacement compiles do not mutate retained valid plan/raster");
}

void structural_curves_assignment_and_example() {
    std::set<std::vector<std::string>> orders;
    for (const auto curve : {GrammarCurve::Hilbert, GrammarCurve::Morton, GrammarCurve::Peano}) {
        auto definition = flat();
        definition.curve = curve; definition.curve_order = 1;
        auto& rule = definition.rules[0];
        rule.count = 4;
        rule.constraints.open_volume = true;
        rule.candidates = {
            candidate("reverse-d", {8, 8, 8, 8}, 0, 0),
            candidate("reverse-c", {8, 24, 8, 8}, 0, 1),
            candidate("reverse-b", {24, 8, 8, 8}, 1, 0),
            candidate("reverse-a", {24, 24, 8, 8}, 1, 1),
        };
        const auto plan = GrammarPlan::compile(definition, 191);
        std::vector<std::pair<std::uint64_t, std::string>> ordered;
        for (const auto& feature : plan->features()) if (feature.rule_id == "hall") {
            const auto input = std::find_if(rule.candidates.begin(), rule.candidates.end(), [&](const auto& value) {
                return value.id == feature.candidate_id;
            });
            require(input != rule.candidates.end(), "curve placement traces its authored candidate");
            const auto rank = curve == GrammarCurve::Peano ? spatial::peano_index(1, input->order_x, input->order_y) :
                curve_index(curve == GrammarCurve::Hilbert ? FieldKind::Hilbert : FieldKind::Morton,
                            1, input->order_x, input->order_y);
            require(feature.order == rank, "inspection order is actual finite curve rank rather than declaration position");
            ordered.emplace_back(feature.order, feature.candidate_id);
        }
        std::sort(ordered.begin(), ordered.end());
        std::vector<std::string> sequence;
        for (const auto& value : ordered) sequence.push_back(value.second);
        orders.insert(sequence);
        std::reverse(rule.candidates.begin(), rule.candidates.end());
        const auto reordered = GrammarPlan::compile(definition, 191);
        require(reordered->fingerprint() == plan->fingerprint(), "candidate declaration order does not change structural curve placement");
    }
    require(orders.size() >= 2, "different finite curve orderings affect structural traversal order");

    auto assigned = flat();
    spatial::RegionAssignment assignment;
    assignment.width = 2; assignment.height = 1; assignment.cell_size = 64;
    assignment.categories = {11, 22};
    assignment.domains = {1, 2};
    for (auto& direction : assignment.adjacency) { direction[0] = 3; direction[1] = 3; }
    assigned.region_window = {0, 0, 2, 1};
    assigned.district_assignment = assignment;
    assigned.district_themes = {{11, {{"foundry", 1}}}, {22, {{"garden", 1}}}};
    const auto plan = GrammarPlan::compile(assigned, 191);
    std::set<std::string> themes;
    for (const auto& feature : plan->features()) if (feature.kind == SemanticKind::Region) {
        require(feature.themes.size() == 1, "region assignment selects exact declared theme blend");
        themes.insert(feature.themes.front().id);
    }
    require(themes == std::set<std::string>{"foundry", "garden"}, "GEN003 assignment is consumed by actual semantic regions");
    auto capacity = assigned;
    for (std::uint64_t category = 100; category < 114; ++category)
        capacity.district_themes.emplace(category, std::vector<GrammarTheme>{{"unused", 1}});
    require(GrammarPlan::compile(capacity, 191)->definition().district_themes.size() == 16,
            "district theme declarations admit the documented sixteen-entry boundary");
    capacity.district_themes.emplace(114, std::vector<GrammarTheme>{{"unused", 1}});
    (void)rejection([&] { (void)GrammarPlan::compile(capacity, 191); }); ++assertions;
    assigned.assignment_limits.max_work = 1;
    (void)rejection([&] { (void)GrammarPlan::compile(assigned, 191); }); ++assertions;
    assigned.assignment_limits.max_work = 1'000'000;
    assigned.district_assignment->adjacency[0][0] = 1;
    assigned.district_assignment->adjacency[2][1] = 2;
    (void)rejection([&] { (void)GrammarPlan::compile(assigned, 191); }); ++assertions;

    const auto example = GrammarPlan::compile(GrammarPlan::example(), 191);
    require(example->definition().region_window.width * example->definition().region_window.height > 1,
            "executable fixture is multi-district");
    std::set<SemanticKind> kinds;
    bool spans_chunks = false;
    for (const auto& feature : example->features()) {
        kinds.insert(feature.kind);
        if (feature.kind == SemanticKind::Complex)
            spans_chunks |= feature.bounds.width > 64 && feature.bounds.height > 64;
    }
    require(spans_chunks && kinds.contains(SemanticKind::District) && kinds.contains(SemanticKind::Complex) &&
                kinds.contains(SemanticKind::Room) && kinds.contains(SemanticKind::Apparatus) && kinds.contains(SemanticKind::Detail),
            "example has cross-chunk complexes, rooms and nested apparatus/detail children");
    require(std::any_of(example->routes().begin(), example->routes().end(), [](const auto& r) { return r.type == "service"; }),
            "example declares real service trunks");
    require(example->definition().secondary_loop && example->routes().size() > 4,
            "example contains explicit secondary loop routes");
    require(example->preparation_work() > 0 && example->preparation_work() <= example->definition().limits.max_work &&
                example->storage_bytes() > 0 && example->storage_bytes() <= example->definition().limits.max_prepared_bytes,
            "prepared semantic work and storage have bounded receipts");
    require(example->geometry_inputs().size() <= 16, "immutable field geometry export is bounded");
    for (const auto& route : example->routes()) {
        const auto endpoint = [&](const std::string& id, const spatial::Point& point) -> const SemanticSocket* {
            if (id.empty()) return nullptr;
            const auto found = std::find_if(example->sockets().begin(), example->sockets().end(), [&](const auto& socket) { return socket.id == id; });
            require(found != example->sockets().end(), "route endpoint names an actual immutable socket");
            require(static_cast<double>(found->x) == point.x && static_cast<double>(found->y) == point.y && found->type == route.type && found->width >= route.width,
                    "route endpoint position/type/aperture agrees with socket geometry");
            return &*found;
        };
        const auto* from = endpoint(route.from_socket, route.points.front());
        const auto* to = endpoint(route.to_socket, route.points.back());
        if (route.id.find("/connection/") != std::string::npos && from && to) {
            const auto direction = [](const spatial::Point& a, const spatial::Point& b) {
                if (b.x < a.x) return SocketDirection::West;
                if (b.x > a.x) return SocketDirection::East;
                return b.y < a.y ? SocketDirection::North : SocketDirection::South;
            };
            require(from->direction == direction(route.points.front(), route.points[1]),
                    "authored attachment exits along its declared socket normal");
            std::size_t previous = route.points.size() - 2;
            while (previous > 0 && route.points[previous].x == route.points.back().x && route.points[previous].y == route.points.back().y) --previous;
            require(to->direction == direction(route.points.back(), route.points[previous]),
                    "bent attachment arrives along the actual destination socket normal");
        }
    }

}

void priority_preferences_and_fallback_ghosts() {
    auto definition = flat();
    auto high = room("alpha", {8, 8, 8, 8});
    auto low = room("beta", {8, 8, 8, 8});
    high.priority = 10; high.material = Material::Copper; high.interior = Material::Copper;
    low.priority = -10; low.material = Material::Metal; low.interior = Material::Metal;
    definition.roots = {"alpha", "beta"}; definition.rules = {low, high};
    const auto priority = GrammarPlan::compile(definition, 191);
    require(priority->proposal(9, 9).material == Material::Copper &&
                priority->proposal(9, 9).feature->rule_id == "alpha",
            "overlapping semantic material proposals honor priority before lexical identity");

    // A failed authored occupancy fallback is absent, and cannot occupy space
    // or provide a support surface to later features during bounded placement.
    high.constraints.occupancy_min = 0.5;
    high.constraints.occupancy_max = 1;
    high.fallback = GrammarFallback::Omit;
    high.constraints.open_volume = true;
    low.constraints.open_volume = true;
    definition.rules = {low, high};
    const auto omitted = GrammarPlan::compile(definition, 191);
    require(count_rule(*omitted, "alpha") == 0 && count_rule(*omitted, "beta") == 1,
            "occupancy fallback leaves no ghost blocker for subsequent lower-priority placement");
    low.constraints.floor = true;
    low.candidates[0].bounds = {8, 0, 8, 8};
    definition.rules = {low, high};
    (void)rejection([&] { (void)GrammarPlan::compile(definition, 191); }); ++assertions;

    auto left = room("left-theme", {4, 4, 8, 40});
    left.priority = 10; left.themes = {{"industrial", 1}};
    auto right = room("right-theme", {44, 4, 8, 40});
    right.priority = 9; right.themes = {{"garden", 1}};
    auto boundary = room("boundary-device", {12, 16, 8, 8});
    boundary.kind = SemanticKind::Apparatus;
    boundary.constraints.open_volume = true;
    boundary.candidates = {candidate("near-left", {12, 16, 8, 8}, 0, 0),
                           candidate("central", {24, 16, 8, 8}, 0, 1)};
    boundary.preferences = {{"between-themes", "theme_boundary", 1, {"garden", "industrial"}}};
    definition.rules = {boundary, right, left};
    definition.roots = {boundary.id, right.id, left.id};
    const auto preferred = GrammarPlan::compile(definition, 191);
    require(by_rule(*preferred, "boundary-device").candidate_id == "central",
            "weighted theme-boundary preference uses declared theme geometry to choose central candidate");
    definition.rules[0].preferences[0].weight = 0;
    require(by_rule(*GrammarPlan::compile(definition, 191), "boundary-device").candidate_id == "near-left",
            "zero preference restores stable curve-order tie breaking");
    definition.rules[0].preferences[0].weight = 1'000'000;
    definition.rules[0].constraints.minimum_separation = 13;
    (void)rejection([&] { (void)GrammarPlan::compile(definition, 191); }); ++assertions;

    auto supported = flat();
    supported.rules[0].interior = Material::Metal;
    supported.rules[0].children = {"requires-open"};
    auto open = room("requires-open", {8, 8, 8, 8});
    open.constraints.open_volume = true;
    supported.rules.push_back(open);
    (void)rejection([&] { (void)GrammarPlan::compile(supported, 191); }); ++assertions;
}

void independent_window_material_and_provenance() {
    auto recipe = integration_recipe();
    recipe.grammar.liquid_trunk = true;
    recipe.grammar.curve_services = true;
    recipe.grammar.rules[0].candidates[0].bounds = {4, 4, 56, 56};
    recipe.grammar.rules[0].sockets = {{"west", "passage", SocketDirection::West, 28, 5, true, true}};
    recipe.grammar.rules[0].constraints.connected = true;
    const auto whole = Generator::compile(recipe);
    require(whole->validate_routes().passed, "whole connected fixture qualifies final material geometry");
    for (std::int64_t ry = -1; ry <= 0; ++ry) for (std::int64_t rx = -1; rx <= 0; ++rx) {
        auto part = recipe;
        part.grammar.region_window = {rx, ry, 1, 1};
        const auto independently_requested = Generator::compile(part);
        require(independently_requested->validate_routes().passed, "neighbor-alone final geometry qualifies its half aperture");
        for (std::int64_t y = ry * 64; y < (ry + 1) * 64; ++y)
            for (std::int64_t x = rx * 64; x < (rx + 1) * 64; ++x) {
                require(whole->sample(x, y) == independently_requested->sample(x, y),
                        "independently planned owning region produces the same cell as whole-window planning");
                const auto all = whole->semantic_plan()->proposal(x, y);
                const auto one = independently_requested->semantic_plan()->proposal(x, y);
                require(all.material == one.material && ((all.feature == nullptr) == (one.feature == nullptr)) &&
                            ((all.route == nullptr) == (one.route == nullptr)),
                        "semantic contribution kind/material independent of requested planning window");
                if (all.feature) require(all.feature->id == one.feature->id,
                        "semantic material contribution has stable feature owner across windows");
                if (all.route) require(all.route->id == one.route->id,
                        "service/liquid contribution has stable route owner at shared boundaries");
                const auto* all_route = whole->semantic_plan()->route_at(x, y);
                const auto* one_route = independently_requested->semantic_plan()->route_at(x, y);
                require((all_route == nullptr) == (one_route == nullptr), "route membership independent of requested planning window");
                if (all_route) require(all_route->id == one_route->id,
                        "passage provenance has stable canonical cell owner at shared boundaries");
            }
    }
    auto near_edge = flat();
    near_edge.rules[0].sockets = {{"west", "passage", SocketDirection::West, 30, 5, true, true}};
    (void)rejection([&] { (void)GrammarPlan::compile(near_edge, 191); }); ++assertions;
    near_edge.rules[0].fallback = GrammarFallback::Omit;
    const auto fallback = GrammarPlan::compile(near_edge, 191);
    require(count_rule(*fallback, "hall") == 0 && std::any_of(fallback->receipts().begin(), fallback->receipts().end(), [](const auto& receipt) {
        return receipt.fallback && !receipt.passed;
    }), "cross-owner attachment failure can use an explicit omission receipt");
}

void typed_parameters_and_bound_controls() {
    auto definition = flat();
    const std::array<double, 7> weights{759.1992752506993,787.0867812001934,871.4264168830628,
        513.354106291798,145.07069131097478,403.11292446113225,639.508862881271};
    for (std::size_t i = 0; i < weights.size(); ++i)
        definition.rules[0].themes.push_back({"theme-" + std::to_string(i), weights[i]});
    const auto authored = GrammarPlan::compile(definition, 191);
    const auto canonical = GrammarPlan::compile(authored->definition(), 191);
    require(canonical->fingerprint() == authored->fingerprint(), "canonical grammar recompiles without normalizing theme weights twice");
    for (const auto& feature : authored->features()) same_feature(feature, *canonical->feature(feature.id));
    auto underflow = flat();
    underflow.rules[0].themes = {{"tiny", std::numeric_limits<double>::denorm_min()}, {"large", 1e6}};
    (void)rejection([&] { (void)GrammarPlan::compile(underflow, 191); }); ++assertions;
    definition = flat();
    std::vector<SpatialValue> invalid_values;
    invalid_values.push_back({SpatialType::Scalar, 1, 2});
    invalid_values.push_back({SpatialType::Distance, -1});
    invalid_values.push_back({SpatialType::Normalized, 2});
    invalid_values.push_back({SpatialType::Boolean, 0.5});
    invalid_values.push_back({SpatialType::Category, 1});
    SpatialValue malformed;
    malformed.type = SpatialType::Scalar; malformed.category.domain = 1;
    invalid_values.push_back(malformed);
    malformed = {}; malformed.x = std::numeric_limits<double>::infinity();
    invalid_values.push_back(malformed);
    for (const auto& value : invalid_values) {
        auto bad = definition;
        bad.rules[0].parameters["payload"] = value;
        (void)rejection([&] { (void)GrammarPlan::compile(bad, 191); }); ++assertions;
    }
    const auto bound = kCoordinateLimit / 64 - 2;
    definition.region_window = {-bound, -bound, 1, 1};
    require(GrammarPlan::compile(definition, 191)->bounds().x == -bound * 64,
            "minimum admitted canonical region uses exact negative coordinates");
    definition.region_window = {bound - 1, bound - 1, 1, 1};
    require(GrammarPlan::compile(definition, 191)->bounds().x == (bound - 1) * 64,
            "maximum admitted canonical region uses exact positive coordinates");
    definition.region_window.x = std::numeric_limits<std::int64_t>::max();
    (void)rejection([&] { (void)GrammarPlan::compile(definition, 191); }); ++assertions;
    definition.region_window.x = std::numeric_limits<std::int64_t>::min();
    (void)rejection([&] { (void)GrammarPlan::compile(definition, 191); }); ++assertions;
    const auto plan = GrammarPlan::compile(flat(), 191);
    require(!plan->proposal(-1, -1).material && plan->route_at(-1, -1) == nullptr,
            "out-of-window samples publish no borrowed neighboring ownership");
    (void)rejection([&] { (void)plan->query({0, 0, 0, 1}); }); ++assertions;
    (void)rejection([&] { (void)plan->ancestry("absent"); }); ++assertions;
    auto exported = flat(); exported.geometry_exports["missing"] = "absent";
    (void)rejection([&] { (void)GrammarPlan::compile(exported, 191); }); ++assertions;
}

void semantic_mask_aggregate_and_module_composition() {
    auto recipe = integration_recipe();
    recipe.grammar.region_window = {0, 0, 1, 1};
    recipe.grammar.rules[0].material = Material::Metal;
    recipe.grammar.rules[0].interior = Material::Metal;
    recipe.grammar.rules[1].wall_thickness = 0;
    recipe.grammar.rules[1].material = Material::Copper;
    recipe.grammar.rules[1].interior = Material::Copper;
    FieldNode zero; zero.id = "zero"; zero.kind = FieldKind::Constant; zero.parameters = {{"value", 0}};
    FieldNode one = zero; one.id = "one"; one.parameters = {{"value", 1}};
    recipe.fields = {zero, one};
    recipe.grammar.rules[1].application = "zero";
    const auto suppressed = Generator::compile(recipe);
    require(suppressed->sample(10, 10) == Material::Metal,
            "zero child mask suppresses only child contribution and retains parent material");
    recipe.grammar.rules[1].application = "one";
    const auto active = Generator::compile(recipe);
    require(active->sample(10, 10) == Material::Copper, "full child mask selects child material over parent");
    recipe.grammar.rules[1].exclusion = "one";
    require(Generator::compile(recipe)->sample(10, 10) == Material::Metal,
            "child exclusion restores the underlying parent contribution");
    recipe.grammar.rules[1].exclusion.clear();
    recipe.grammar.rules[1].wall_thickness = 1;
    recipe.grammar.rules[1].aggregate = "structural-mix";
    Aggregate aggregate;
    aggregate.id = "structural-mix"; aggregate.grain_size = 1;
    aggregate.components = {{Material::Copper, 1}, {Material::Metal, 1}};
    recipe.aggregates = {aggregate};
    const auto mixed = Generator::compile(recipe);
    std::set<Material> observed;
    for (std::int64_t x = 10; x < 18; ++x) {
        const auto material = mixed->sample(x, 10);
        require(material == Material::Copper || material == Material::Metal,
                "semantic aggregate emits only ordinary declared materials on shell");
        observed.insert(material);
    }
    require(observed.size() == 2, "semantic shell uses real aggregate variation");
    const auto trace = mixed->explain(10, 10);
    require(std::any_of(trace.contributions.begin(), trace.contributions.end(), [](const auto& c) {
        return c.stage == "semantic_aggregate";
    }), "semantic aggregate material decision is inspectable");
    recipe.grammar.rules[1].allowed_materials = {Material::Copper};
    (void)rejection([&] { (void)Generator::compile(recipe); }); ++assertions;

    recipe = integration_recipe();
    recipe.grammar.region_window = {0, 0, 1, 1};
    ModuleInstance vault;
    vault.id = "native-vault"; vault.module = "vault"; vault.bounds = {8, 8, 16, 16};
    vault.parameters = {{"cell_size", 16}};
    recipe.modules = {vault};
    const auto module = Generator::compile(recipe);
    require(module->validate_routes().passed, "registered native module composes beneath restored semantic routes");
    const auto module_trace = module->explain(8, 8);
    require(std::any_of(module_trace.contributions.begin(), module_trace.contributions.end(), [](const auto& c) {
        return c.stage == "module" && c.id == "native-vault";
    }), "registered module material contribution remains in semantic cell provenance");
}

void final_support_qualification() {
    auto recipe = integration_recipe();
    recipe.grammar.region_window = {0, 0, 1, 1};
    auto& apparatus = recipe.grammar.rules[1];
    apparatus.candidates = {candidate("on-floor", {4, 51, 8, 8})};
    apparatus.constraints.floor = true;
    const auto supported = Generator::compile(recipe);
    const auto& feature = by_rule(*supported->semantic_plan(), "machine");
    require(same_bounds(feature.bounds, {6, 53, 8, 8}), "support fixture has independently specified contact geometry");
    for (std::int64_t x = 6; x < 14; ++x)
        require(supported->sample(x, 61) == Material::Concrete, "parent floor contact consists of final solid cells");
    const auto& before = supported->validate_routes();
    require(before.passed && before.supports_passed && before.support_profile == "static-solid-contact-v1",
            "unmodified declared floor qualifies against final raster independently of route clearance");
    const auto original = std::find_if(before.supports.begin(), before.supports.end(), [&](const auto& row) {
        return row.feature_id == feature.id && row.constraint == "floor";
    });
    require(original != before.supports.end() && original->passed && original->checked_cells == 8 && original->missing_cells == 0,
            "support receipt counts the independently known floor contact line");

    HardOverride removal;
    removal.id = "remove-floor"; removal.bounds = {6, 61, 7, 1}; removal.material = Material::Empty;
    recipe.overrides = {removal};
    const auto partial = Generator::compile(recipe);
    require(partial->validate_routes().supports_passed && partial->sample(13, 61) == Material::Concrete,
            "declared static-contact profile permits one remaining solid contact");
    removal.bounds.width = 8;
    recipe.overrides = {removal};
    const auto unsupported = Generator::compile(recipe);
    const auto& after = unsupported->validate_routes();
    require(after.passed && !after.supports_passed, "lost floor support is reported separately from still-valid routes");
    const auto failed = std::find_if(after.supports.begin(), after.supports.end(), [&](const auto& row) {
        return row.feature_id == feature.id && row.constraint == "floor";
    });
    require(failed != after.supports.end() && !failed->passed && failed->checked_cells == 8 && failed->missing_cells == 8 &&
                failed->first_missing_x == 6 && failed->first_missing_y == 61 && !failed->detail.empty(),
            "final support failure names the feature and exact missing contact geometry");
    same_feature(feature, by_rule(*unsupported->semantic_plan(), "machine"));
    for (std::int64_t x = 6; x < 14; ++x)
        require(unsupported->sample(x, 61) == Material::Empty, "support qualification preserves authoritative final material override");
    const auto trace = unsupported->explain(6, 61);
    require(!trace.contributions.empty() && trace.contributions.back().stage == "hard_override" &&
                trace.contributions.back().id == "remove-floor" && trace.material == Material::Empty,
            "missing floor material remains attributable to the final authored override");
}

void unused_and_omitted_external_bindings() {
    for (const bool omitted : {false, true}) {
        auto recipe = integration_recipe();
        recipe.grammar.region_window = {0, 0, 1, 1};
        FieldNode one; one.id = "one"; one.kind = FieldKind::Constant; one.parameters = {{"value", 1}};
        recipe.fields = {one};
        SpatialNode coordinate; coordinate.id = "absolute-x"; coordinate.kind = SpatialKind::CoordinateX;
        recipe.spatial.nodes = {coordinate};
        Aggregate aggregate; aggregate.id = "declared-mix"; aggregate.components = {{Material::Copper, 1}};
        recipe.aggregates = {aggregate};
        auto unused = room("unbound", {4, 4, 8, 8});
        unused.application = "one"; unused.exclusion = "one"; unused.aggregate = "declared-mix";
        unused.allowed_materials = {Material::Concrete, Material::Empty, Material::Copper};
        if (omitted) {
            unused.constraints.floor = true; // A root region has no declared solid floor.
            unused.fallback = GrammarFallback::Omit;
            recipe.grammar.roots.push_back(unused.id);
        }
        recipe.grammar.rules.push_back(unused);
        const auto valid = Generator::compile(recipe);
        require(count_rule(*valid->semantic_plan(), "unbound") == 0,
                "valid external bindings compile even when their rule emits no feature");
        if (omitted) require(std::any_of(valid->semantic_plan()->receipts().begin(), valid->semantic_plan()->receipts().end(), [](const auto& row) {
            return row.rule_id == "unbound" && row.fallback && !row.passed;
        }), "omitted external-binding control exercises a real recorded placement fallback");

        std::vector<Recipe> invalid(6, recipe);
        invalid[0].grammar.rules.back().application = "missing-mask";
        invalid[1].grammar.rules.back().exclusion = "missing-mask";
        invalid[2].grammar.rules.back().application = "absolute-x";
        invalid[3].grammar.rules.back().exclusion = "absolute-x";
        invalid[4].grammar.rules.back().aggregate = "missing-aggregate";
        invalid[5].grammar.rules.back().allowed_materials = {Material::Concrete, Material::Empty};
        for (const auto& broken : invalid) {
            const auto error = rejection([&] { (void)Generator::compile(broken); });
            require(!error.empty() && error == rejection([&] { (void)Generator::compile(broken); }),
                    "every declared external binding validates deterministically before emitted-feature selection");
        }
    }
}

void manually_joined_socket_materials() {
    struct Case {
        std::string type;
        Material default_material, configured_material;
    };
    const std::array<Case, 3> cases{{
        {"passage", Material::Empty, Material::Empty},
        {"service", Material::Copper, Material::Metal},
        {"liquid", Material::Water, Material::Acid},
    }};
    for (const bool configured : {false, true}) for (const auto& test : cases) {
        auto recipe = integration_recipe();
        auto& definition = recipe.grammar;
        definition = GrammarDefinition{};
        definition.id = "manual-joins"; definition.region_size = 64;
        definition.secondary_loop = false; definition.service_trunk = false; definition.liquid_trunk = false;
        if (configured) {
            definition.service_material = Material::Metal;
            definition.liquid_material = Material::Acid;
        }
        auto left = room("left", {4, 4, 8, 8});
        auto right = room("right", {12, 4, 8, 8});
        left.interior = right.interior = Material::Concrete;
        left.constraints.open_volume = right.constraints.open_volume = true;
        left.constraints.minimum_sockets = left.constraints.maximum_sockets = 1;
        right.constraints.minimum_sockets = right.constraints.maximum_sockets = 1;
        GrammarSocket east;
        east.id = "east"; east.type = test.type; east.direction = SocketDirection::East;
        east.offset = 4; east.width = 3; east.required = true; east.attach_to_route = false;
        auto west = east; west.id = "west"; west.direction = SocketDirection::West;
        left.sockets = {east}; right.sockets = {west};
        definition.roots = {"right", "left"}; definition.rules = {right, left};
        const auto generator = Generator::compile(recipe);
        const auto& plan = *generator->semantic_plan();
        const std::string left_id = "manual-joins/grid64/region(0,0)/left/0/socket/east";
        const std::string right_id = "manual-joins/grid64/region(0,0)/right/0/socket/west";
        const auto socket = [&](const std::string& id) -> const SemanticSocket& {
            const auto found = std::find_if(plan.sockets().begin(), plan.sockets().end(), [&](const auto& value) {
                return value.id == id;
            });
            require(found != plan.sockets().end(), "manual socket retains its authored feature and port identity");
            return *found;
        };
        const auto& a = socket(left_id);
        const auto& b = socket(right_id);
        require(a.matched == right_id && b.matched == left_id && a.type == test.type && b.type == test.type &&
                    a.direction == SocketDirection::East && b.direction == SocketDirection::West &&
                    a.width == 3 && b.width == 3 && !a.shared && !b.shared,
                "manual adjoining sockets match each other reciprocally with the authored type and aperture");
        require(a.x == 11 && a.y == 8 && b.x == 12 && b.y == 8,
                "manual join endpoints are the independently specified neighboring feature edges");
        const auto joined = std::find_if(plan.routes().begin(), plan.routes().end(), [&](const auto& route) {
            return route.from_socket == left_id && route.to_socket == right_id;
        });
        require(joined != plan.routes().end(), "manual compatible pair emits an explicit route between the two ports");
        const auto expected = configured ? test.configured_material : test.default_material;
        require(joined->material == expected,
                "manual " + test.type + " join selects its " + (configured ? "configured" : "default") + " material");
        require(joined->id == left_id + "/join" && joined->type == test.type && joined->width == 3 &&
                    joined->required == (test.type == "passage") && joined->owner == spatial::RegionId{0, 0},
                "manual route has stable identity, owner, type, and traversal requirement");
        require(joined->points.size() == 2 && joined->points[0].x == 11 && joined->points[0].y == 8 &&
                    joined->points[1].x == 12 && joined->points[1].y == 8,
                "manual route geometry directly joins adjacent ports without a regional trunk attachment");
        require(std::count_if(plan.routes().begin(), plan.routes().end(), [](const auto& route) {
            return route.id.ends_with("/join");
        }) == 1, "one socket pair emits exactly one manual join");

        // Explicit width-three centre, side, and end-cap cells; these locations
        // are far from every primary regional route and utility trunks are off.
        const std::array<CellKey, 6> inside_cells{{{11, 8}, {12, 8}, {11, 7}, {12, 9}, {10, 8}, {13, 8}}};
        for (const auto& [x, y] : inside_cells) {
            require(generator->sample(x, y) == expected, "manual join raster preserves the declared material at centre and corridor edges");
            if (test.type == "passage") {
                const auto* route = plan.route_at(x, y);
                require(route && route->id == joined->id, "manual passage owns its explicit restoration footprint");
            } else {
                const auto proposal = plan.proposal(x, y);
                require(proposal.route && proposal.route->id == joined->id && proposal.material == expected,
                        "manual utility material proposal comes from the paired socket route");
            }
        }
        const std::array<CellKey, 4> outside_cells{{{11, 6}, {11, 10}, {9, 8}, {14, 8}}};
        for (const auto& [x, y] : outside_cells)
            require(generator->sample(x, y) == Material::Concrete, "manual join stops at its declared corridor footprint");
        const auto trace = generator->explain(11, 8);
        require(trace.material == expected && std::any_of(trace.contributions.begin(), trace.contributions.end(), [&](const auto& value) {
            return value.id == joined->id && value.after == expected;
        }), "manual socket join material is attributable in final cell provenance");
        auto reordered = definition;
        std::reverse(reordered.rules.begin(), reordered.rules.end());
        std::reverse(reordered.roots.begin(), reordered.roots.end());
        require(GrammarPlan::compile(reordered, recipe.seed)->fingerprint() == plan.fingerprint(),
                "manual pairing identities and materials are independent of declaration order");
    }
}

void omitted_manual_peer_removes_join() {
    auto recipe = integration_recipe();
    auto& definition = recipe.grammar;
    definition = GrammarDefinition{};
    definition.id = "omitted-peer"; definition.region_size = 64;
    definition.secondary_loop = false; definition.service_trunk = false; definition.liquid_trunk = false;
    definition.service_material = Material::Metal; definition.liquid_material = Material::Acid;
    auto survivor = room("left", {4, 4, 8, 8});
    auto omitted = room("right", {12, 4, 8, 8});
    survivor.interior = omitted.interior = Material::Concrete;
    GrammarSocket east;
    east.id = "east"; east.type = "liquid"; east.direction = SocketDirection::East;
    east.offset = 4; east.width = 3; east.required = false; east.attach_to_route = false;
    auto west = east; west.id = "west"; west.direction = SocketDirection::West; west.required = true;
    auto unmatched = east; unmatched.id = "unmatched"; unmatched.direction = SocketDirection::North; unmatched.required = true;
    survivor.sockets = {east}; omitted.sockets = {west, unmatched};
    omitted.constraints.minimum_sockets = 1;
    omitted.fallback = GrammarFallback::Omit;
    definition.roots = {"left", "right"}; definition.rules = {survivor, omitted};
    auto control_recipe = recipe;
    control_recipe.grammar.roots = {"left"}; control_recipe.grammar.rules = {survivor};
    const auto control = Generator::compile(control_recipe);
    const auto generator = Generator::compile(recipe);
    const auto& plan = *generator->semantic_plan();
    const std::string deleted_id = "omitted-peer/grid64/region(0,0)/right/0";
    const std::string surviving_socket = "omitted-peer/grid64/region(0,0)/left/0/socket/east";
    require(count_rule(plan, "left") == 1 && count_rule(plan, "right") == 0 && plan.feature(deleted_id) == nullptr,
            "optional-port survivor remains when its peer is omitted for another unmatched required port");
    const auto socket = std::find_if(plan.sockets().begin(), plan.sockets().end(), [&](const auto& value) {
        return value.id == surviving_socket;
    });
    require(socket != plan.sockets().end() && socket->matched.empty() && !socket->required,
            "surviving optional socket becomes unmatched after its peer is removed");
    require(std::all_of(plan.routes().begin(), plan.routes().end(), [&](const auto& route) {
        return !route.id.starts_with(deleted_id) && !route.from_socket.starts_with(deleted_id) &&
               !route.to_socket.starts_with(deleted_id);
    }), "omitting a manual peer removes every route that references its deleted socket");
    require(std::none_of(plan.routes().begin(), plan.routes().end(), [](const auto& route) {
        return route.id.ends_with("/join");
    }), "a join owned by the surviving feature is also removed when its opposite endpoint disappears");
    for (const auto& route : plan.routes()) for (const auto& endpoint : {route.from_socket, route.to_socket}) {
        if (endpoint.empty()) continue;
        require(std::any_of(plan.sockets().begin(), plan.sockets().end(), [&](const auto& value) {
            return value.id == endpoint;
        }), "every remaining explicit route endpoint resolves to a published socket");
    }
    same_feature(by_rule(plan, "left"), by_rule(*control->semantic_plan(), "left"));
    const auto omission = std::find_if(plan.receipts().begin(), plan.receipts().end(), [&](const auto& row) {
        return row.feature_id == deleted_id && row.rule_id == "right" && row.constraint == "sockets" &&
               row.fallback && !row.passed;
    });
    require(omission != plan.receipts().end() && !omission->detail.empty(),
            "removed peer retains a meaningful failed socket constraint and authored fallback receipt");
    auto reordered = definition;
    std::reverse(reordered.rules.begin(), reordered.rules.end());
    std::reverse(reordered.roots.begin(), reordered.roots.end());
    const auto replay = GrammarPlan::compile(reordered, recipe.seed);
    require(replay->fingerprint() == plan.fingerprint() && std::any_of(replay->receipts().begin(), replay->receipts().end(), [&](const auto& row) {
        return row.feature_id == omission->feature_id && row.constraint == omission->constraint &&
               row.detail == omission->detail && row.fallback && !row.passed;
    }), "peer omission and its receipt remain stable under declaration reordering");
    const auto proposal = plan.proposal(11, 8);
    require(!proposal.route && proposal.material == Material::Concrete && generator->sample(11, 8) == Material::Concrete,
            "deleted join leaves no utility material over the surviving feature edge");
    const std::array<CellKey, 6> former_join{{{11, 8}, {12, 8}, {11, 7}, {12, 9}, {10, 8}, {13, 8}}};
    for (const auto& [x, y] : former_join)
        require(generator->sample(x, y) == control->sample(x, y), "omitted peer leaves no ghost join material at either former endpoint or corridor edge");
    const auto trace = generator->explain(11, 8);
    require(std::none_of(trace.contributions.begin(), trace.contributions.end(), [](const auto& value) {
        return value.id.ends_with("/join");
    }), "final material provenance contains no contribution from the removed join");
}

void native_stage_replay_and_bounded_inspection() {
    Recipe r; r.schema = 3; r.seed = 193; r.chunk_size = 8;
    r.grammar = flat(); r.grammar.rules.front().interior = Material::Concrete;
    FieldNode one; one.id = "one"; one.parameters["value"] = 1; r.fields = {one};
    Aggregate mixture; mixture.id = "grit"; mixture.components = {{Material::Sand, 5}};
    r.aggregates = {mixture};
    Modifier apply; apply.id = "apply"; apply.aggregate = "grit"; apply.application = "one";
    Modifier excluded = apply; excluded.id = "excluded"; excluded.exclusion = "one"; excluded.aggregate.clear(); excluded.material = Material::Water;
    Modifier predicate = excluded; predicate.id = "predicate"; predicate.exclusion.clear(); predicate.context = ContextPredicate::Occupied;
    r.modifiers = {predicate, excluded, apply};
    r.paths = {{"clearance", {{4, 6}, {12, 6}}, 1, Material::Empty, 0}};
    r.overrides = {{"final-authored", {6, 6, 1, 1}, Material::SteelPlate, {}, {}, 0}};
    const auto generator = Generator::compile(r);
    const auto before = generator->generate({0, 0});
    const auto trace = generator->explain(6, 6);
    const std::array<Material, kGenerationStageCount> expected{Material::Empty, Material::Empty, Material::Concrete,
        Material::Sand, Material::Empty, Material::SteelPlate};
    require(trace.stages.materials == expected && generator->stages(6, 6).materials == expected,
        "actual stages independently witness candidate, grammar, aggregate, clearance and last override");
    require(trace.material == generator->sample(6, 6) && trace.initial_material == Material::Empty &&
        trace.context_evaluated && trace.context.material == 0 && trace.context.occupied == 0,
        "inspector context is original analytic candidate, not earlier material modifiers");
    require(trace.revision == r.revision && trace.fingerprint == generator->fingerprint() && trace.proposal_hash != 0,
        "cell replay binds recipe identity, absolute coordinate and final material");
    require(trace.aggregates.size() == 1 && trace.aggregates[0].id == "grit" && trace.aggregates[0].material == Material::Sand &&
        trace.aggregates[0].components.size() == 1 && trace.aggregates[0].components[0].weight == 1,
        "aggregate trace exposes canonical normalized weights and realized ordinary material");
    bool saw_exclusion = false, saw_predicate = false;
    for (const auto& d : trace.decisions) {
        if (d.id == "excluded" && d.stage == "modifier_mask") saw_exclusion = !d.accepted && d.exclusion_value == 1 && d.influence == 0;
        if (d.id == "predicate" && d.stage == "modifier_mask") saw_predicate = !d.accepted && !d.context_passed && d.predicate == "occupied";
    }
    require(saw_exclusion && saw_predicate, "rejected alternatives identify actual exclusion and immutable context predicate");
    require(!trace.truncated && trace.accepted_feature_id.ends_with("/hall/0") && !trace.ancestry.empty(),
        "accepted semantic producer is identified without invented detail");
    for (std::size_t stage = 0; stage < kGenerationStageCount; ++stage) {
        const auto name = std::string("stage:") + generation_stage_name(static_cast<GenerationStage>(stage));
        auto job = generator->begin({0, 0}, name);
        while (job->state() == ResultState::Pending) (void)job->advance(3);
        auto result = job->result();
        require(generator->accepts(result) && result.cells == before.cells && result.stage_cells[6*8+6] == expected[stage],
            "stage job publishes actual intermediate plus invariant final baseline under sliced budgets");
        result.stage_cells[6*8+6] = Material::Fire;
        require(!generator->accepts(result), "stage material tamper invalidates native receipt");
    }
    auto cancelled = generator->begin({0, 0}, "stage:grammar"); (void)cancelled->advance(7); cancelled->cancel();
    require(cancelled->result().stage_cells.empty() && cancelled->result().cells.empty(), "cancelled stage job publishes no partial buffers");
    require(rejection([&] { (void)generator->begin({0, 0}, "stage:imagined"); }).find("stage") != std::string::npos,
        "unimplemented stage is explicit failure");
    const auto after = generator->generate({0, 0});
    require(before.cells == after.cells && before.receipt_hash == after.receipt_hash,
        "all inspection and stage replay leave subsequent generation untouched");
    auto changed = r; changed.seed += 1;
    require(Generator::compile(changed)->explain(6, 6).proposal_hash != trace.proposal_hash,
        "same final authored cell under different seed cannot reuse prior proposal identity");
}

void indexed_grammar_matches_independent_bruteforce() {
    auto d = flat(); d.id = "index-control"; d.region_size = 128; d.region_window = {-1, -1, 2, 2};
    d.rules.front().candidates.front().bounds = {2, 2, 124, 124};
    auto child = room("child", {30, 30, 64, 64}); child.interior = Material::RedBrick; child.material = Material::Metal;
    d.rules.front().children = {"child"}; d.rules.push_back(child);
    const auto plan = GrammarPlan::compile(d, 193);
    const auto hit = [](RectI64 b, std::int64_t x, std::int64_t y) { return x >= b.x && y >= b.y && x < b.x+b.width && y < b.y+b.height; };
    const auto route_hit = [](const SemanticRoute& route, std::int64_t x, std::int64_t y) {
        const auto half = static_cast<std::int64_t>(route.width / 2);
        for (std::size_t i=1;i<route.points.size();++i) {
            const auto a=route.points[i-1], b=route.points[i];
            if (static_cast<double>(x) >= std::min(a.x,b.x)-static_cast<double>(half) &&
                static_cast<double>(x) <= std::max(a.x,b.x)+static_cast<double>(half) &&
                static_cast<double>(y) >= std::min(a.y,b.y)-static_cast<double>(half) &&
                static_cast<double>(y) <= std::max(a.y,b.y)+static_cast<double>(half)) return true;
        }
        return false;
    };
    for (std::int64_t y=-128;y<128;++y) for (std::int64_t x=-128;x<128;++x) {
        const SemanticFeature* winner=nullptr; std::optional<Material> material; bool inner=false;
        for (const auto& f:plan->features()) {
            if (!hit(f.bounds,x,y)) continue;
            const auto depth=std::count(f.id.begin(),f.id.end(),'/');
            const auto old_depth=winner ? std::count(winner->id.begin(),winner->id.end(),'/') : 0;
            if (winner && (depth<old_depth || (depth==old_depth && f.priority<winner->priority))) continue;
            const auto w=static_cast<std::int64_t>(f.wall_thickness);
            const bool interior=f.wall_thickness==0 || hit({f.bounds.x+w,f.bounds.y+w,f.bounds.width-2*w,f.bounds.height-2*w},x,y);
            const auto proposed=interior ? f.interior : f.material;
            if (!proposed && (interior || f.aggregate.empty())) continue;
            winner=&f; material=proposed; inner=interior;
        }
        const auto owner=spatial::RegionId{static_cast<std::int64_t>(std::floor(static_cast<double>(x)/128)),
            static_cast<std::int64_t>(std::floor(static_cast<double>(y)/128))};
        const SemanticRoute* structural=nullptr; const SemanticRoute* clearance=nullptr;
        for (const auto& route:plan->routes()) if (route.owner==owner && route_hit(route,x,y)) {
            if (route.type=="passage") { if (!clearance) clearance=&route; }
            else { structural=&route; material=route.material; winner=nullptr; inner=false; }
        }
        const auto actual=plan->proposal(x,y);
        require(actual.feature==winner && actual.route==structural && actual.material==material && actual.interior==inner,
            "bounded grammar index equals full independent hierarchy/route scan, including negative bins and halos");
        require(plan->route_at(x,y)==clearance, "indexed clearance equals full route scan at every boundary and seam cell");
    }
    std::uint64_t old_cost=64+plan->features().size()*64;
    for (const auto& route:plan->routes()) old_cost+=32+32*route.points.size();
    require(plan->operations_per_sample()<old_cost, "local candidate upper bound is smaller than scanning the entire finite window");
    auto memory=d; memory.limits.max_prepared_bytes=plan->storage_bytes()-1;
    require(rejection([&]{(void)GrammarPlan::compile(memory,193);}).find("memory")!=std::string::npos,
        "index allocations obey declared prepared memory budget");
}

} // namespace
int main() {
    try {
        native_stage_replay_and_bounded_inspection();
        indexed_grammar_matches_independent_bruteforce();
        hierarchy_queries_and_stable_identity();
        independent_regions_and_boundaries();
        bounded_constraints_and_failures();
        structural_curves_assignment_and_example();
        priority_preferences_and_fallback_ghosts();
        independent_window_material_and_provenance();
        typed_parameters_and_bound_controls();
        native_raster_invariance_and_clearance();
        semantic_mask_aggregate_and_module_composition();
        override_provenance_and_transactionality();
        final_support_qualification();
        unused_and_omitted_external_bindings();
        omitted_manual_peer_removes_join();
        manually_joined_socket_materials();
        std::cout << "PASS semantic grammar: " << assertions << " assertions\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "FAIL semantic grammar: " << error.what() << '\n';
        return 1;
    }
}
