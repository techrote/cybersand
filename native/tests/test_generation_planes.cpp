#include "cybersand/generation_planes.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <iostream>
#include <limits>
#include <map>
#include <random>
#include <set>
#include <source_location>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

namespace {
using namespace cybersand;
using namespace cybersand::generation;
std::uint64_t assertions = 0;
void require(bool ok, const std::string& message) { ++assertions; if (!ok) throw std::runtime_error(message); }
template<class F> std::string reject(F&& f, std::source_location where = std::source_location::current()) {
    try { f(); } catch (const std::exception& e) { ++assertions; return e.what(); }
    throw std::runtime_error("expected rejection at line " + std::to_string(where.line()));
}
bool same_rect(RectI64 a, RectI64 b) {
    return a.x == b.x && a.y == b.y && a.width == b.width && a.height == b.height;
}
Recipe recipe() {
    Recipe r; r.schema = 3; r.seed = 192; r.chunk_size = 16;
    r.grammar.id = "plane-test"; r.grammar.region_size = 64;
    r.grammar.region_window = {-1, -1, 2, 2}; r.grammar.roots = {"hall"};
    GrammarRule hall; hall.id = "hall"; hall.kind = SemanticKind::Complex;
    hall.candidates = {{"one", {2, 2, 60, 60}, 0, 0}};
    hall.material = Material::ReinforcedConcrete; hall.interior = Material::Empty;
    hall.wall_thickness = 2; r.grammar.rules = {hall}; return r;
}
PlaneProjectionTemplate projection(std::string id, std::string rule, Plane plane, ProjectionShape shape,
    Material material = Material::Empty, std::optional<RectI64> bounds = {}) {
    PlaneProjectionTemplate p; p.id = std::move(id); p.rule = std::move(rule); p.plane = plane;
    p.shape = shape; p.material = material; p.interior = Material::Empty;
    p.bounds = bounds; if (shape == ProjectionShape::Omit) p.omission = "deliberate open composition"; return p;
}
PlaneFixtureTemplate fixture(std::string id, Plane plane, RectI64 box, Material material, FixtureMode mode = FixtureMode::Source) {
    PlaneFixtureTemplate f; f.id = std::move(id); f.rule = "hall"; f.plane = plane; f.bounds = box;
    f.material = material; f.mode = mode; f.first_tick = mode == FixtureMode::Setup ? 0 : 1;
    f.repeat = mode == FixtureMode::Setup ? 1 : 3; f.period = 8; return f;
}
PlaneLinkTemplate link(std::string id, LinkFamily family, LinkClass classification,
    Plane from, Plane to, std::string effect, RectI64 bounds = {4, 4, 40, 40}) {
    PlaneLinkTemplate l; l.id = std::move(id); l.rule = "hall"; l.family = family;
    l.classification = classification; l.source_plane = from; l.target_plane = to;
    l.effect = std::move(effect); l.bounds = bounds; return l;
}
PlaneDefinition definition() {
    PlaneDefinition d; d.id = "coherent-test"; d.policies[0].base_generator = false;
    d.projections = {
        projection("play-hall", "hall", Plane::Play, ProjectionShape::Shell, Material::Concrete),
        projection("rear-hall", "hall", Plane::Scripted, ProjectionShape::Shell, Material::SteelPlate),
        projection("rear-apparatus", "hall", Plane::Scripted, ProjectionShape::Fill, Material::Salt, RectI64{10, 24, 8, 4}),
        projection("atmosphere", "hall", Plane::Effects, ProjectionShape::Fill, Material::Steam, RectI64{12, 12, 8, 8}),
        projection("distant-hall", "hall", Plane::Background, ProjectionShape::Shell, Material::BasaltColumns),
        projection("clear-air", "$region", Plane::Effects, ProjectionShape::Omit),
        projection("far-open-space", "$region", Plane::Background, ProjectionShape::Omit)
    };
    d.projections[2].priority = 2; d.projections[3].density = 0.5;
    for (auto plane : {Plane::Play, Plane::Scripted}) {
        auto p = projection(plane == Plane::Play ? "play-service" : "rear-service", "$region", plane,
            ProjectionShape::Fill, Material::CopperPipe);
        p.geometry = "routes"; p.route_type = "service"; p.priority = 4; d.projections.push_back(p);
    }
    d.fixtures = {
        fixture("play-water", Plane::Play, {10, 10, 2, 2}, Material::Water),
        fixture("rear-water", Plane::Scripted, {10, 20, 2, 2}, Material::Water),
        fixture("spray", Plane::Effects, {12, 12, 2, 2}, Material::Steam),
        fixture("drain", Plane::Effects, {20, 20, 2, 2}, Material::Empty, FixtureMode::Drain),
        fixture("one-time-salt", Plane::Scripted, {12, 20, 2, 2}, Material::Salt, FixtureMode::Setup)
    };
    d.fixtures[1].expected_products = {Material::Brine};
    d.fixtures[2].cleanup_tick = 30;
    auto explosion = link("breach", LinkFamily::Explosion, LinkClass::Runtime, Plane::Play, Plane::Scripted, "blast");
    explosion.material = Material::Fire; explosion.radius = 4;
    auto vent = link("vent-source", LinkFamily::Vent, LinkClass::Static, Plane::Scripted, Plane::Effects, "source");
    vent.fixture = "spray";
    auto drain = link("vent-drain", LinkFamily::Vent, LinkClass::Static, Plane::Play, Plane::Effects, "drain");
    drain.fixture = "drain";
    auto burst = link("vent-burst", LinkFamily::Vent, LinkClass::Runtime, Plane::Scripted, Plane::Effects, "burst");
    burst.material = Material::Spark; burst.radius = 2;
    auto waterfall = link("waterfall", LinkFamily::Waterfall, LinkClass::Static, Plane::Play, Plane::Effects, "source_and_spray");
    waterfall.fixture = "spray";
    d.links = {explosion, vent, drain, burst,
        link("window", LinkFamily::Window, LinkClass::Presentation, Plane::Play, Plane::Background, "visibility"),
        link("pipe", LinkFamily::Pipe, LinkClass::Static, Plane::Play, Plane::Scripted, "correspondence"), waterfall,
        link("machine", LinkFamily::Machinery, LinkClass::Static, Plane::Play, Plane::Scripted, "correspondence")};
    PlaneActorTemplate actor; actor.id = "inspection"; actor.rule = "hall";
    actor.model = "skimmer"; actor.producer = "policy"; actor.x = 30; actor.y = 30;
    d.actors = {actor};
    return d;
}
std::shared_ptr<const PlanePlan> compiled(PlaneDefinition d = definition(), Recipe r = recipe()) {
    return PlanePlan::compile(Generator::compile(std::move(r)), std::move(d));
}

void semantic_correspondence_and_provenance() {
    auto plan = compiled();
    require(plan->fixtures().size() == 20 && plan->links().size() == 32, "all regional fixtures and links accounted for");
    require(plan->actors().size() == 4, "one canonical actor placement per region");
    for (const auto& a : plan->actors()) require(a.plane == Plane::Play && a.lifecycle == "play-owner-v1" &&
        a.model == "skimmer" && a.revision != 0, "actor descriptor targets only existing play owner");
    std::set<LinkFamily> families;
    for (const auto& link : plan->links()) {
        families.insert(link.family);
        require(plan->generator().semantic_plan()->feature(link.source_feature) != nullptr &&
            plan->generator().semantic_plan()->feature(link.target_feature) != nullptr, "link endpoints retain canonical feature identity");
        require(!link.lifecycle.empty() && link.revision != 0, "link carries applicable revision and lifecycle");
    }
    require(families.size() == 6, "all six requested link families exist");
    for (const auto& f : plan->fixtures()) {
        require(f.clock == plane_name(f.plane) && f.plane != Plane::Background && f.revision != 0,
            "fixtures have independent owned clock and revision");
        require(f.feature_id == plan->generator().semantic_plan()->feature(f.feature_id)->id,
            "fixtures have canonical feature owner");
        if (f.adapter == "rear-water") require(f.material == Material::Water && f.expected_products == std::vector<Material>{Material::Brine},
            "reagent is separate from expected native product");
    }
    auto inspected = plan->explain(Plane::Scripted, -52, -38);
    require(inspected.material == Material::Salt && !inspected.features.empty() && !inspected.projections.empty(),
        "material provenance resolves the native rear apparatus projection");
    auto fixture_inspection = plan->explain(Plane::Scripted, -52, -42);
    require(!fixture_inspection.fixtures.empty() && !fixture_inspection.links.empty(), "fixture and link provenance is available");
    std::set<std::string> routes;
    for (const auto& p : plan->projections()) if (p.adapter == "play-service") routes.insert(p.geometry_ref);
    require(!routes.empty(), "pipe projections consume explicit canonical service geometry");
    for (const auto& p : plan->projections()) if (p.adapter == "rear-service") require(routes.contains(p.geometry_ref),
        "play and rear pipe projections share the same route geometry IDs");
    require(plan->preparation_work() > 0 && plan->storage_bytes() > 0 && plan->operations_per_cell() > 0,
        "bounded semantic compiler reports nonzero real work/storage");
    const auto full = plan->generate(plan->bounds());
    require(full.state == ResultState::Ready && plan->accepts(full), "complete immutable four-plane result accepted");
    require(full.fixture_ids.size() == plan->fixtures().size() && full.link_ids.size() == plan->links().size(),
        "whole-region registration manifest is complete");
    require(full.actor_ids.size() == plan->actors().size(), "complete bundle registers every actor once");
    for (auto h : full.content_hashes) require(h != 0, "every material plane has a content hash");
    auto changed = definition(); changed.projections[2].material = Material::Copper;
    const auto rear_changed = compiled(changed)->generate(plan->bounds());
    require(rear_changed.cells[0] == full.cells[0] && rear_changed.cells[2] == full.cells[2] && rear_changed.cells[3] == full.cells[3],
        "rear-only projection changes preserve all other plane cells");
    require(rear_changed.cells[1] != full.cells[1], "rear change is effective; no-op control fails");
}

void tiled_order_workers_and_budget_slices() {
    const auto plan = compiled(); const auto whole = plan->generate(plan->bounds());
    std::mt19937 random(192);
    for (const int size : {8, 16, 32}) {
        std::vector<RectI64> tiles;
        for (std::int64_t y = -64; y < 64; y += size) for (std::int64_t x = -64; x < 64; x += size)
            tiles.push_back({x, y, size, size});
        std::shuffle(tiles.begin(), tiles.end(), random);
        std::vector<PlaneResult> outputs(tiles.size());
        std::atomic<std::size_t> next{0}; std::atomic<bool> failed{false};
        const auto worker = [&] {
            try {
                for (;;) {
                    const auto i = next.fetch_add(1); if (i >= tiles.size()) break;
                    auto job = plan->begin(tiles[i]);
                    while (job->state() == ResultState::Pending) (void)job->advance(i % 2 ? 7 : 53);
                    outputs[i] = job->result(); if (!plan->accepts(outputs[i])) failed = true;
                }
            } catch (...) { failed = true; }
        };
        std::array<std::thread, 4> threads;
        for (auto& thread : threads) thread = std::thread(worker);
        for (auto& thread : threads) thread.join();
        require(!failed, "parallel budget-sliced tile jobs completed");
        std::map<std::string, unsigned> fixture_counts, link_counts, actor_counts;
        for (std::size_t i = 0; i < outputs.size(); ++i) {
            const auto& r = outputs[i]; require(plan->accepts(r), "tile carries canonical bundle receipt");
            for (const auto& id : r.fixture_ids) ++fixture_counts[id];
            for (const auto& id : r.link_ids) ++link_counts[id];
            for (const auto& id : r.actor_ids) ++actor_counts[id];
            for (unsigned p = 0; p < 4; ++p) for (std::int64_t y = 0; y < size; ++y) for (std::int64_t x = 0; x < size; ++x) {
                const auto local = static_cast<std::size_t>(y * size + x);
                const auto global = static_cast<std::size_t>((tiles[i].y + y + 64) * 128 + tiles[i].x + x + 64);
                require(r.cells[p][local] == whole.cells[p][global], "independent tile equals whole region on every plane");
            }
        }
        require(fixture_counts.size() == whole.fixture_ids.size() && link_counts.size() == whole.link_ids.size(),
            "partitioned registration union is complete");
        for (const auto& [id, count] : fixture_counts) { (void)id; require(count == 1, "cross-chunk fixture owner occurs exactly once"); }
        for (const auto& [id, count] : link_counts) { (void)id; require(count == 1, "cross-chunk link owner occurs exactly once"); }
        require(actor_counts.size() == whole.actor_ids.size(), "partitioned actor registration union is complete");
        for (const auto& [id, count] : actor_counts) { (void)id; require(count == 1, "cross-chunk actor placement occurs exactly once"); }
    }
    auto reconfigured = recipe(); reconfigured.chunk_size = 64;
    auto budgeted = definition(); budgeted.limits.max_operations = 1'000'000'000;
    const auto alternative = compiled(budgeted, reconfigured)->generate(plan->bounds());
    require(alternative.cells == whole.cells && alternative.fixture_ids == whole.fixture_ids && alternative.link_ids == whole.link_ids &&
        alternative.actor_ids == whole.actor_ids,
        "storage chunk size and admitted budget do not change semantic generation");
}

void regional_identity_and_declaration_order() {
    const auto plan = compiled();
    auto reversed = definition(); std::reverse(reversed.projections.begin(), reversed.projections.end());
    std::reverse(reversed.fixtures.begin(), reversed.fixtures.end()); std::reverse(reversed.links.begin(), reversed.links.end());
    std::reverse(reversed.policies.begin(), reversed.policies.end());
    const auto reordered = compiled(reversed);
    require(reordered->fingerprint() == plan->fingerprint(), "declaration order does not change bundle identity");
    require(reordered->generate(plan->bounds()).cells == plan->generate(plan->bounds()).cells, "reordered declarations have exact materials");
    auto one_region = recipe(); one_region.grammar.region_window = {-1, -1, 1, 1};
    const auto independent = compiled(definition(), one_region);
    for (const auto& p : independent->projections()) {
        const auto found = std::find_if(plan->projections().begin(), plan->projections().end(), [&](const auto& q) { return p.id == q.id; });
        require(found != plan->projections().end() && p.revision == found->revision && same_rect(p.bounds, found->bounds),
            "independent region retains projection identity, geometry and revision");
    }
    for (const auto& f : independent->fixtures()) {
        const auto found = std::find_if(plan->fixtures().begin(), plan->fixtures().end(), [&](const auto& q) { return f.id == q.id; });
        require(found != plan->fixtures().end() && f.revision == found->revision, "independent fixture registration is identical");
    }
    for (const auto& l : independent->links()) {
        const auto found = std::find_if(plan->links().begin(), plan->links().end(), [&](const auto& q) { return l.id == q.id; });
        require(found != plan->links().end() && l.revision == found->revision, "independent semantic link is identical");
    }
    for (const auto& a : independent->actors()) {
        const auto found = std::find_if(plan->actors().begin(), plan->actors().end(), [&](const auto& q) { return a.id == q.id; });
        require(found != plan->actors().end() && a.revision == found->revision && a.x == found->x && a.y == found->y,
            "independent actor placement retains identity and position");
    }
    const auto region = independent->generate(independent->bounds());
    const auto queried = plan->generate(independent->bounds());
    require(region.cells == queried.cells && region.fixture_ids == queried.fixture_ids && region.link_ids == queried.link_ids,
        "one-region discovery matches a query from the complete window");
    auto changed = definition(); changed.projections[2].material = Material::Copper;
    const auto edited = compiled(changed);
    for (const auto& p : plan->projections()) if (p.adapter != "rear-apparatus") {
        const auto found = std::find_if(edited->projections().begin(), edited->projections().end(), [&](const auto& q) { return p.id == q.id; });
        require(found != edited->projections().end() && found->revision == p.revision, "unrelated adapter edit preserves projection revisions");
    }
    auto new_revision = definition(); ++new_revision.revision;
    const auto renewed = compiled(new_revision);
    require(renewed->fixtures()[0].id == plan->fixtures()[0].id && renewed->fixtures()[0].revision != plan->fixtures()[0].revision,
        "applicable revision changes without renaming fixture identity");
}

void validation_atomicity_and_link_families() {
    auto retained = compiled(); const auto before = retained->fingerprint();
    const auto try_bad = [&](PlaneDefinition d) {
        const auto a = reject([&] { retained = compiled(d); });
        const auto b = reject([&] { (void)compiled(d); });
        require(a == b && retained->fingerprint() == before, "deterministic rejection preserves previously compiled bundle");
    };
    auto d = definition(); d.schema = 2; try_bad(d);
    d = definition(); d.projections[0].rule = "missing"; try_bad(d);
    d = definition(); d.projections[0].bounds = RectI64{-1, 0, 8, 8}; try_bad(d);
    d = definition(); d.projections[0].material = static_cast<Material>(10); try_bad(d);
    d = definition(); d.projections[0].density = std::numeric_limits<double>::quiet_NaN(); try_bad(d);
    d = definition(); d.projections[5].omission.clear(); try_bad(d);
    d = definition(); d.projections.erase(d.projections.begin() + 6); try_bad(d);
    d = definition(); d.policies[3].rate = 1; try_bad(d);
    d = definition(); d.policies[1].base_generator = true; try_bad(d);
    d = definition(); d.policies[2].material = Material::Lava; try_bad(d);
    d = definition(); d.fixtures[0].plane = Plane::Background; try_bad(d);
    d = definition(); d.fixtures[0].repeat = 10001; try_bad(d);
    d = definition(); d.fixtures[0].first_tick = 360000; try_bad(d);
    d = definition(); d.fixtures[0].cleanup_tick = 4; try_bad(d);
    d = definition(); d.fixtures[0].bounds = {58, 58, 4, 4}; try_bad(d);
    d = definition(); d.fixtures[1].material = static_cast<Material>(10); try_bad(d);
    d = definition(); d.fixtures[1].expected_products = {Material::Water}; try_bad(d);
    d = definition(); d.fixtures[1].expected_products = {Material::Empty}; try_bad(d);
    d = definition(); d.fixtures[3].material = Material::Water; try_bad(d);
    d = definition(); d.fixtures[4].repeat = 2; try_bad(d);
    d = definition(); d.links[0].radius = 3; try_bad(d);
    d = definition(); d.links[0].bounds = {0, 0, 4, 4}; try_bad(d);
    d = definition(); d.links[0].target_rule = "missing"; try_bad(d);
    d = definition(); d.links[0].material = Material::Water; try_bad(d);
    d = definition(); d.links[1].fixture = "missing"; try_bad(d);
    d = definition(); d.links[1].fixture = "drain"; try_bad(d);
    d = definition(); d.links[2].bounds = {0, 0, 4, 4}; try_bad(d);
    d = definition(); d.links[3].material = Material::Fire; try_bad(d);
    d = definition(); d.fixtures.erase(d.fixtures.begin()); try_bad(d);
    d = definition(); d.actors[0].plane = Plane::Scripted; try_bad(d);
    d = definition(); d.actors[0].x = 60; try_bad(d);
    d = definition(); d.actors[0].producer = "direct-rapier"; try_bad(d);
    d = definition(); d.actors[0].model.clear(); try_bad(d);
    d = definition(); d.actors[0].rule = "missing"; try_bad(d);
    d = definition(); d.limits.max_actors = 3; try_bad(d);
    d = definition(); d.limits.max_actors = 9; try_bad(d);
    for (std::size_t i = 0; i < definition().links.size(); ++i) {
        d = definition(); d.links[i].target_plane = Plane::Play; try_bad(d);
        d = definition(); d.links[i].family = static_cast<LinkFamily>(255); try_bad(d);
        d = definition(); d.links[i].classification = static_cast<LinkClass>(255); try_bad(d);
        d = definition(); d.links[i].effect = "arbitrary-mutation"; try_bad(d);
    }
    d = definition(); d.links[4].classification = LinkClass::Runtime; try_bad(d);
    d = definition(); d.projections.erase(d.projections.begin() + 4); try_bad(d);
    d = definition(); d.projections.push_back(d.projections[0]); try_bad(d);
    d = definition(); d.limits.max_templates = 1; try_bad(d);
    d = definition(); d.limits.max_projections = 1; try_bad(d);
    d = definition(); d.limits.max_fixtures = 1; try_bad(d);
    d = definition(); d.limits.max_links = 1; try_bad(d);
    d = definition(); d.limits.max_cells_per_plane = 100; try_bad(d);
    d = definition(); d.limits.max_operations = 1; try_bad(d);
    d = definition(); d.limits.max_prepared_bytes = 1; try_bad(d);
    d = definition(); d.limits.max_publication_bytes = 1; try_bad(d);
    d = definition(); d.limits.max_diagnostic_bytes = 1; try_bad(d);
    d = definition(); d.limits.max_events_per_tick = 1; try_bad(d);
    d = definition(); d.limits.max_fixture_cell_writes = 1; try_bad(d);
}

void receipts_cancellation_and_late_failure() {
    const auto plan = compiled(); auto job = plan->begin(plan->bounds());
    require(job->advance(0) == ResultState::Pending && job->completed_cells() == 0, "zero slice does no work");
    reject([&] { (void)job->result(); });
    require(job->advance(9) == ResultState::Pending && job->completed_cells() == 9, "bounded slice has real progress");
    job->cancel(); require(job->state() == ResultState::Cancelled && job->advance(1000) == ResultState::Cancelled,
        "cancelled generation cannot restart");
    for (const auto& cells : job->result().cells) require(cells.empty(), "cancellation drops all unpublished planes");
    require(job->result().fixture_ids.empty() && job->result().link_ids.empty(), "cancellation publishes no registrations");
    auto good = plan->generate(plan->bounds()); auto bad = good;
    bad.cells[2][0] = Material::Spark; require(!plan->accepts(bad), "tampered plane rejected");
    bad = good; bad.fixture_ids.pop_back(); require(!plan->accepts(bad), "missing fixture registration rejected");
    bad = good; bad.link_ids.push_back(bad.link_ids[0]); require(!plan->accepts(bad), "duplicate link registration rejected");
    bad = good; bad.actor_ids.pop_back(); require(!plan->accepts(bad), "missing actor registration rejected");
    bad = good; ++bad.revision; require(!plan->accepts(bad), "stale semantic revision rejected");
    bad = good; ++bad.bounds.x; require(!plan->accepts(bad), "coordinate-shifted receipt rejected");
    bad = good; ++bad.operations; require(!plan->accepts(bad), "forged work receipt rejected");
    auto changed = definition(); ++changed.revision;
    require(!compiled(changed)->accepts(good), "prior bundle generation cannot publish into replacement");
    reject([&] { (void)plan->begin({-65, -64, 8, 8}); });
    reject([&] { (void)plan->sample(static_cast<Plane>(255), 0, 0); });
    std::atomic<bool> armed{false};
    struct Throwing final : FeatureSampler {
        const std::atomic<bool>& armed;
        explicit Throwing(const std::atomic<bool>& a) : armed(a) {}
        std::optional<Material> sample(const ModuleContext&, Material previous) const override {
            if (armed.load()) throw std::runtime_error("intentional sampler abort");
            return previous;
        }
    };
    ModuleRegistry registry;
    registry.add({"fault", 1, 4, [&](const auto&, auto) { return std::make_shared<Throwing>(armed); }});
    auto r = recipe(); ModuleInstance instance; instance.id = "fault-instance"; instance.module = "fault";
    instance.bounds = {-64, -64, 128, 128}; r.modules.push_back(instance);
    auto base = Generator::compile(r, registry); auto native = definition(); native.policies[0].base_generator = true;
    const auto fault_plan = PlanePlan::compile(base, native);
    armed = true; auto fault = fault_plan->begin(fault_plan->bounds());
    require(fault->advance(50) == ResultState::Failed && fault->result().error.find("intentional sampler abort") != std::string::npos,
        "late native helper failure is a failed complete bundle");
    for (const auto& cells : fault->result().cells) require(cells.empty(), "late failure cannot leak another plane");
    require(fault->result().fixture_ids.empty() && fault->result().link_ids.empty() && !fault_plan->accepts(fault->result()),
        "helper abort registers no fixture/link and cannot count as pass");
    require(fault->result().actor_ids.empty(), "helper abort publishes no actor placements");
}

void native_play_and_final_overrides() {
    auto r = recipe(); HardOverride hard; hard.id = "final-authority"; hard.bounds = {-10, -10, 5, 5};
    hard.material = Material::Glass; r.overrides.push_back(hard);
    auto d = definition();
    d.projections.push_back(projection("attempt-cover", "$region", Plane::Play, ProjectionShape::Fill, Material::Concrete));
    d.projections.back().priority = 100;
    const auto overlaid = compiled(d, r);
    require(overlaid->sample(Plane::Play, -8, -8) == Material::Glass, "final authored hard material overrides survive plane projection");
    d = definition(); d.policies[0].base_generator = true;
    d.projections.erase(std::remove_if(d.projections.begin(), d.projections.end(), [](const auto& p) { return p.plane == Plane::Play; }), d.projections.end());
    const auto native = compiled(d, r);
    for (std::int64_t y = -64; y < 64; y += 3) for (std::int64_t x = -64; x < 64; x += 3)
        require(native->sample(Plane::Play, x, y) == native->generator().sample(x, y), "native play policy preserves prior generation exactly");
    require(std::any_of(native->projections().begin(), native->projections().end(), [](const auto& p) {
        return p.plane == Plane::Play && p.shape == ProjectionShape::Native && p.adapter == "native-play";
    }), "native play carries copied canonical feature provenance");
    // Camera and parallax are absent from the API; repeated reordered plane
    // reads are the native control for their presentation-only owner contract.
    const auto before = native->generate(native->bounds());
    for (auto p : {Plane::Background, Plane::Play, Plane::Effects, Plane::Scripted}) (void)native->explain(p, 0, 0);
    const auto after = native->generate(native->bounds());
    require(before.content_hashes == after.content_hashes && before.receipt_hash == after.receipt_hash,
        "inspection and presentation-style reads cannot change cells, ownership or identity");
}

void shared_spatial_projection_masks() {
    auto r = recipe();
    SpatialNode x; x.id = "world-x"; x.kind = SpatialKind::CoordinateX;
    SpatialNode y; y.id = "world-y"; y.kind = SpatialKind::CoordinateY;
    SpatialNode zero; zero.id = "zero"; zero.kind = SpatialKind::Constant;
    zero.value = {SpatialType::Scalar, 0}; zero.unit_power = 1;
    SpatialNode west; west.id = "west"; west.kind = SpatialKind::Less; west.inputs = {"world-x", "zero"};
    SpatialNode north; north.id = "north"; north.kind = SpatialKind::Less; north.inputs = {"world-y", "zero"};
    SpatialNode half; half.id = "half"; half.kind = SpatialKind::Constant; half.value = {SpatialType::Normalized, 0.5};
    SpatialNode vector; vector.id = "vector"; vector.kind = SpatialKind::Constant; vector.value = {SpatialType::Vector2, 1, 2};
    r.spatial.nodes = {x, y, zero, west, north, half, vector};
    auto d = definition();
    auto mask = projection("shared-west-south", "hall", Plane::Scripted, ProjectionShape::Fill, Material::Copper);
    mask.priority = 100; mask.application = "spatial:west"; mask.exclusion = "spatial:north";
    d.projections.push_back(mask);
    auto far = mask; far.id = "shared-far-west-south"; far.plane = Plane::Background; d.projections.push_back(far);
    const auto plan = compiled(d, r);
    const auto unmasked = compiled(definition(), r);
    for (std::int64_t py = -60; py <= 60; py += 4) for (std::int64_t px = -60; px <= 60; px += 4) {
        const bool hall = ((px >= -62 && px < -2) || (px >= 2 && px < 62)) &&
            ((py >= -62 && py < -2) || (py >= 2 && py < 62));
        const bool active = hall && px < 0 && py >= 0;
        for (auto plane : {Plane::Scripted, Plane::Background}) {
            const auto expected = active ? Material::Copper : unmasked->sample(plane, px, py);
            require(plan->sample(plane, px, py) == expected,
                "shared boolean fields apply analytical world-space application/exclusion on both planes");
        }
    }
    require(plan->operations_per_cell() > unmasked->operations_per_cell(), "shared graph evaluation is charged to work budget");
    for (const auto& p : plan->projections()) if (!p.application.empty()) require(p.fields_fingerprint != 0,
        "projection provenance binds transitive field identity");
    const auto whole = plan->generate(plan->bounds());
    const auto tiled = plan->generate({-64, 0, 64, 64});
    for (unsigned p = 0; p < 4; ++p) for (std::size_t i = 0; i < 4096; ++i)
        require(tiled.cells[p][i] == whole.cells[p][(i / 64 + 64) * 128 + i % 64],
            "field masks are invariant under independently partitioned negative-coordinate requests");
    auto related = r; related.spatial.nodes[2].value.x = 10;
    const auto changed = compiled(d, related);
    for (const auto& p : plan->projections()) if (!p.application.empty()) {
        const auto found = std::find_if(changed->projections().begin(), changed->projections().end(), [&](const auto& q) { return p.id == q.id; });
        require(found != changed->projections().end() && p.revision != found->revision,
            "shared field edit updates affected projection revision without renaming identity");
    }
    auto unrelated = r; SpatialNode extra; extra.id = "unrelated"; extra.value = {SpatialType::Normalized, 0.1};
    unrelated.spatial.nodes.push_back(extra); const auto extended = compiled(d, unrelated);
    for (const auto& p : plan->projections()) if (!p.application.empty()) {
        const auto found = std::find_if(extended->projections().begin(), extended->projections().end(), [&](const auto& q) { return p.id == q.id; });
        require(found != extended->projections().end() && p.revision == found->revision,
            "unrelated field addition preserves transitive projection revisions");
    }
    for (const auto& bad : {"world-x", "spatial:missing", "spatial:world-x", "spatial:vector"}) {
        auto invalid = d; invalid.projections.back().application = bad;
        reject([&] { (void)compiled(invalid, r); });
    }
    auto partial = d; partial.projections.back().application = "spatial:half"; partial.projections.back().exclusion.clear();
    const auto density = compiled(partial, r); std::size_t changed_cells = 0;
    for (std::int64_t py = 4; py < 60; ++py) for (std::int64_t px = 4; px < 60; ++px)
        changed_cells += density->sample(Plane::Background, px, py) == Material::Copper ? 1 : 0;
    require(changed_cells > 500 && changed_cells < 2600, "normalized masks cause an effective bounded deterministic density");
}
void indexed_plane_raster_and_stages_match_bruteforce() {
    auto r=recipe(); auto d=definition();
    r.grammar.region_size=128; r.grammar.rules.front().candidates.front().bounds={2,2,124,124};
    auto patch=projection("index-boundary", "hall", Plane::Background, ProjectionShape::Shell, Material::Copper,
        RectI64{58,58,14,14}); patch.wall_thickness=2; patch.density=0.43; patch.priority=10;
    d.projections.push_back(patch);
    r.overrides={{"last", {-65,-65,2,2}, Material::SteelPlate, {}, {}, 0}};
    const auto plan=compiled(d,r);
    const auto within=[](RectI64 b,std::int64_t x,std::int64_t y){return x>=b.x&&y>=b.y&&x<b.x+b.width&&y<b.y+b.height;};
    const auto hash_word=[](std::uint64_t& hash,std::uint64_t value){for(unsigned byte=0;byte<8;++byte){hash^=(value>>(byte*8))&255;hash*=UINT64_C(1099511628211);}};
    for (std::int64_t y=-128;y<128;++y) for (std::int64_t x=-128;x<128;++x) {
        for (unsigned plane=0;plane<4;++plane) {
            const auto kind=static_cast<Plane>(plane);
            Material expected=d.policies[plane].material;
            std::size_t applied=0;
            for (const auto& p:plan->projections()) {
                if(p.plane!=kind||p.shape==ProjectionShape::Omit||p.shape==ProjectionShape::Native||!within(p.bounds,x,y))continue;
                if(!p.points.empty()) {
                    bool hit=false;const auto half=static_cast<double>(p.route_width/2);
                    for(std::size_t i=1;i<p.points.size();++i) {
                        const auto a=p.points[i-1],b=p.points[i];
                        if(static_cast<double>(x)>=std::min(a.x,b.x)-half&&static_cast<double>(x)<=std::max(a.x,b.x)+half&&
                           static_cast<double>(y)>=std::min(a.y,b.y)-half&&static_cast<double>(y)<=std::max(a.y,b.y)+half)hit=true;
                    }
                    if(!hit)continue;
                }
                auto h=p.seed;hash_word(h,static_cast<std::uint64_t>(x));hash_word(h,static_cast<std::uint64_t>(y));
                if(p.density!=1&&static_cast<double>(h>>32)>=p.density*4294967296.0)continue;
                const auto wall=static_cast<std::int64_t>(p.wall_thickness);
                const bool inner=within({p.bounds.x+wall,p.bounds.y+wall,p.bounds.width-2*wall,p.bounds.height-2*wall},x,y);
                expected=p.shape==ProjectionShape::Shell&&inner?p.interior:p.material; ++applied;
            }
            const auto projected=expected;
            if(kind==Plane::Play&&within(r.overrides.front().bounds,x,y))expected=*r.overrides.front().material;
            require(plan->sample(kind,x,y)==expected,
                "indexed planes equal independent full projection scan across negative coordinates, density and bin halos");
            const auto stages=plan->stages(kind,x,y);
            require(!stages.has_source&&stages.policy==d.policies[plane].material&&stages.base==stages.policy&&
                stages.projections==projected&&stages.final==expected&&stages.projection_checks>=applied,
                "plane stages are actual policy/base/projection/override values and observed candidate counts");
        }
    }
    const auto trace=plan->explain(Plane::Play,-65,-65);
    require(trace.material==Material::SteelPlate&&!trace.source&&trace.stages.final==Material::SteelPlate&&trace.proposal_hash!=0,
        "plane trace attributes final authored override and does not fabricate unused base generator");
    require(!trace.contributions.empty()&&trace.contributions.back().stage=="hard_override",
        "plane override is reported after exact projection precedence");
    const auto stage_identity=trace.proposal_hash;
    (void)plan->stages(Plane::Background,3,3);
    require(plan->explain(Plane::Play,-65,-65).proposal_hash==stage_identity,
        "diagnostics and stage snapshots never mutate accepted plane result identity");
    auto small=d; small.limits.max_prepared_bytes=plan->storage_bytes()-1;
    require(reject([&]{(void)compiled(small,r);}).find("memory")!=std::string::npos,
        "projection index storage participates in bounded preparation accounting");
}

void projection_trace_truncation_does_not_truncate_materials() {
    auto r=recipe();r.grammar.region_window={0,0,1,1};
    PlaneDefinition d; d.policies[0].base_generator=false; d.limits.max_templates=300;
    d.projections={projection("air", "$region", Plane::Effects, ProjectionShape::Omit),
        projection("far", "$region", Plane::Background, ProjectionShape::Omit)};
    for(unsigned i=0;i<270;++i) {
        auto p=projection("layer-"+std::to_string(i),"hall",Plane::Scripted,ProjectionShape::Fill,Material::Copper);
        p.priority=static_cast<int>(i);d.projections.push_back(p);
    }
    d.projections.back().material=Material::SteelPlate;
    const auto plan=compiled(d,r);
    const auto trace=plan->explain(Plane::Scripted,5,5);
    require(trace.material==Material::SteelPlate&&plan->sample(Plane::Scripted,5,5)==Material::SteelPlate,
        "trace output limit never truncates generation or final precedence");
    require(trace.truncated&&trace.omitted_entries>0&&trace.decisions.size()==kMaxTraceEntries&&
        trace.contributions.size()==kMaxTraceEntries,
        "bounded trace declares omitted decisions and contributions explicitly");
}

void co_located_plane_work_bound() {
    auto r=recipe(); r.grammar.region_size=128; r.grammar.region_window={-1,-1,1,1};
    r.grammar.rules.front().candidates.front().bounds={2,2,124,124};
    PlaneDefinition d; d.policies[0].base_generator=false;
    d.projections={projection("air", "$region", Plane::Effects, ProjectionShape::Omit),
        projection("far", "$region", Plane::Background, ProjectionShape::Omit),
        projection("near", "hall", Plane::Play, ProjectionShape::Fill, Material::Copper, RectI64{0,0,32,32}),
        projection("remote", "hall", Plane::Scripted, ProjectionShape::Fill, Material::SteelPlate, RectI64{92,92,20,20})};
    const auto separated=compiled(d,r);
    // Two region omissions cost 4 each in every bin. These material patches
    // occupy opposite bins, hence at most one 64-work patch is ever examined
    // alongside the fixed 128-work four-plane sampling/receipt allowance.
    constexpr std::uint64_t independent_bound=128+4+4+64;
    require(separated->operations_per_cell()==independent_bound,
        "bundle bound is the largest co-located four-plane cost, not unrelated plane maxima");
    for(std::int64_t y=-128;y<0;++y)for(std::int64_t x=-128;x<0;++x) {
        const bool near=x>=-126&&x< -94&&y>=-126&&y< -94;
        const bool remote=x>=-34&&x< -14&&y>=-34&&y< -14;
        require(separated->sample(Plane::Play,x,y)==(near?Material::Copper:Material::Empty)&&
            separated->sample(Plane::Scripted,x,y)==(remote?Material::SteelPlate:Material::Empty),
            "analytical separate-bin patch oracle preserves all negative-coordinate cells");
        std::uint64_t observed_checks=0;
        for(unsigned plane=0;plane<4;++plane) {
            const auto sampled=separated->stages(static_cast<Plane>(plane),x,y);
            observed_checks+=sampled.projection_checks;
        }
        require(observed_checks<=3,
            "actual all-plane candidate checks never exceed two omissions and one local patch");
    }
    const auto whole=separated->generate(separated->bounds());
    require(separated->accepts(whole)&&whole.operations==128*128*independent_bound+128,
        "whole bundle receipt charges the conservative per-cell bound plus publication exactly");
    auto exact=d; exact.limits.max_operations=whole.operations;
    require(compiled(exact,r)->generate(separated->bounds()).state==ResultState::Ready,
        "exact co-located logical budget is admitted");
    --exact.limits.max_operations;
    require(reject([&]{(void)compiled(exact,r);}).find("complete bundle raster")!=std::string::npos,
        "one operation below the complete co-located bound is refused");
    d.projections.back().bounds=RectI64{0,0,20,20};
    const auto together=compiled(d,r);
    require(together->operations_per_cell()==independent_bound+64,
        "co-located cross-plane patches add their complete work rather than taking one plane maximum");
}

} // namespace

int main() {
    try {
        indexed_plane_raster_and_stages_match_bruteforce();
        projection_trace_truncation_does_not_truncate_materials();
        co_located_plane_work_bound();
        semantic_correspondence_and_provenance();
        tiled_order_workers_and_budget_slices();
        regional_identity_and_declaration_order();
        validation_atomicity_and_link_families();
        receipts_cancellation_and_late_failure();
        native_play_and_final_overrides();
        shared_spatial_projection_masks();
        std::cout << "GEN-005 native semantic planes: " << assertions << " assertions, 0 failures\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "GEN-005 native semantic planes FAILED after " << assertions << " assertions: " << e.what() << '\n';
        return 1;
    }
}
