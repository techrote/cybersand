#include "cybersand/object_shard_coordinator.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdio>
#include <deque>
#include <limits>
#include <random>
#include <vector>

namespace cybersand::object_shard {
struct CoordinatorTestAccess {
    static const ComponentDiscovery& discovery(const Coordinator& coordinator) { return *coordinator.discovery_; }
    static World& world(Coordinator& coordinator) { return *coordinator.world_; }
};
}

// Independent reference: a fresh row-major World image, a deque flood fill and
// a separate visited bitmap. It does not read the production discovery cache,
// mutation journal, masks, candidate labels or rectangle decomposition.
namespace {
using namespace cybersand;
using namespace cybersand::object_shard;
std::uint64_t checks{}, failures{};
void check(bool pass, const char* expression, int line) {
    ++checks;
    if (!pass) { ++failures; std::fprintf(stderr, "FAIL %d: %s\n", line, expression); }
}
#define CHECK(value) check((value), #value, __LINE__)
struct ReferenceComponent {
    Material material{};
    std::vector<std::uint32_t> cells;
    bool anchored{}, unknown_boundary{};
};
std::vector<ReferenceComponent> reference_components(const Coordinator& coordinator) {
    const auto bounds = coordinator.config().world_bounds;
    std::vector<Material> image(bounds.area());
    std::vector<bool> visited(image.size());
    for (std::size_t index = 0; index < image.size(); ++index)
        image[index] = coordinator.inspect_world(bounds.x + static_cast<std::int64_t>(index % bounds.width),
            bounds.y + static_cast<std::int64_t>(index / bounds.width)).material;
    std::vector<ReferenceComponent> result;
    for (std::uint32_t root = 0; root < image.size(); ++root) {
        if (visited[root] || (image[root] != Material::Wood && image[root] != Material::RedBrick)) continue;
        ReferenceComponent component;
        component.material = image[root];
        std::deque<std::uint32_t> frontier{root};
        visited[root] = true;
        while (!frontier.empty()) {
            const auto at = frontier.front(); frontier.pop_front();
            component.cells.push_back(at);
            const auto x = static_cast<int>(at % bounds.width), y = static_cast<int>(at / bounds.width);
            for (const auto& [dx, dy] : std::array<std::pair<int, int>, 4>{{{0,-1},{1,0},{0,1},{-1,0}}}) {
                const auto nx = x + dx, ny = y + dy;
                if (nx < 0 || ny < 0 || nx >= bounds.width || ny >= bounds.height) {
                    component.unknown_boundary = true; continue;
                }
                const auto neighbour = static_cast<std::uint32_t>(ny * bounds.width + nx);
                component.anchored = component.anchored || image[neighbour] == Material::Wall;
                if (image[neighbour] == component.material && !visited[neighbour]) {
                    visited[neighbour] = true; frontier.push_back(neighbour);
                }
            }
        }
        std::sort(component.cells.begin(), component.cells.end());
        result.push_back(std::move(component));
    }
    return result;
}
Config config() {
    Config result; result.scenario = 0; result.world_bounds = {0, 0, 128, 96}; return result;
}
void rectangle(Coordinator& coordinator, int x, int y, int width, int height,
               Material material = Material::Wood) {
    for (int row = 0; row < height; ++row) for (int column = 0; column < width; ++column)
        CHECK(coordinator.edit(x + column, y + row, {material, 0, 0, 200}).outcome == Outcome::Accepted);
}
Result await_preparation(Coordinator& coordinator, unsigned limit = 4096) {
    Result result;
    for (unsigned attempt = 0; attempt < limit; ++attempt) {
        result = coordinator.prepare_next();
        if (result.outcome == Outcome::Accepted) return result;
        if (result.outcome != Outcome::Busy && result.outcome != Outcome::Anchored && result.outcome != Outcome::Capacity)
            return result;
    }
    return result;
}
bool activate(Coordinator& coordinator, Handle handle) {
    for (const auto kind : {AckKind::PhysicsReserved, AckKind::TerrainInstalled, AckKind::BodyActivated}) {
        const auto snapshot = coordinator.snapshot();
        const auto* shard = coordinator.registry().find(handle);
        if (!shard) return false;
        const auto& geometry = shard->geometry();
        Acknowledgement receipt{handle, snapshot.promotion.transaction, handle.generation,
            snapshot.promotion.payload_digest, geometry.revision, geometry.mask_digest, geometry.shape_digest,
            kind, kind == AckKind::TerrainInstalled ? snapshot.promotion.terrain : std::span<const TerrainReceipt>{}};
        if (coordinator.acknowledge(receipt).outcome != Outcome::Accepted) return false;
    }
    return true;
}
void simultaneous_fragments_prefer_large_structure() {
    Coordinator coordinator(config());
    rectangle(coordinator, 8, 8, 1, 1);
    rectangle(coordinator, 18, 8, 2, 2);
    rectangle(coordinator, 28, 8, 3, 3);
    rectangle(coordinator, 55, 30, 20, 20);
    const auto oracle = reference_components(coordinator);
    CHECK(oracle.size() == 4);
    CHECK(std::count_if(oracle.begin(), oracle.end(), [](const auto& c) { return !c.anchored && !c.unknown_boundary; }) == 4);
    std::vector<std::uint32_t> admitted;
    for (unsigned slot = 0; slot < 3; ++slot) {
        const auto prepared = await_preparation(coordinator);
        CHECK(prepared.outcome == Outcome::Accepted);
        if (prepared.outcome != Outcome::Accepted) break;
        const auto* shard = coordinator.registry().find(prepared.shard);
        admitted.push_back(shard->counts().structural);
        CHECK(activate(coordinator, prepared.shard));
    }
    std::printf("Admission ordering: [%u,%u,%u], expected first=400\n",
        admitted.size() > 0 ? admitted[0] : 0, admitted.size() > 1 ? admitted[1] : 0,
        admitted.size() > 2 ? admitted[2] : 0);
    CHECK(admitted.size() == 3 && admitted.front() == 400);
    const auto remaining = reference_components(coordinator);
    CHECK(std::none_of(remaining.begin(), remaining.end(), [](const auto& c) { return c.cells.size() == 400; }));
    for (unsigned attempt = 0; attempt < 128; ++attempt) (void)coordinator.prepare_next();
    const auto before = coordinator.metrics().discovered_cells;
    for (unsigned attempt = 0; attempt < 128; ++attempt) (void)coordinator.prepare_next();
    const auto repeated = coordinator.metrics().discovered_cells - before;
    std::printf("Unchanged full-slot rediscovery over 128 calls: %llu cells\n", static_cast<unsigned long long>(repeated));
    CHECK(repeated == 0);
}
void discovery_budget_is_resumable() {
    auto settings = config(); settings.discovery_budget = 32;
    Coordinator coordinator(settings);
    rectangle(coordinator, 30, 25, 20, 20);
    const auto prepared = await_preparation(coordinator, 2048);
    std::printf("400-cell component with 32-work budget: %s (%s)\n", outcome_name(prepared.outcome), prepared.detail);
    CHECK(prepared.outcome == Outcome::Accepted);
    if (prepared.outcome == Outcome::Accepted) {
        CHECK(coordinator.registry().find(prepared.shard)->counts().structural == 400);
        CHECK(activate(coordinator, prepared.shard));
    }
}
Result finish_census(Coordinator& coordinator, unsigned limit = 8192) {
    Result result;
    for (unsigned attempt=0;attempt<limit;++attempt) {
        result=coordinator.prepare_next();
        CHECK(coordinator.snapshot().admission.work_last<=coordinator.config().discovery_budget);
        if (result.outcome==Outcome::Accepted || coordinator.snapshot().admission.census_complete) return result;
    }
    CHECK(false);
    return result;
}
void compare_reference_catalogue(Coordinator& coordinator) {
    const auto oracle=reference_components(coordinator);
    const auto& catalogue=CoordinatorTestAccess::discovery(coordinator);
    CHECK(catalogue.complete());CHECK(catalogue.roots().size()==oracle.size());
    std::vector<std::uint32_t> members;members.reserve(coordinator.config().world_bounds.area());
    std::vector<bool> matched(oracle.size());
    for (const auto root:catalogue.roots()) {
        const auto& c=catalogue.candidate(root);
        CHECK(catalogue.members(root,members));
        std::sort(members.begin(),members.end());
        std::size_t found=oracle.size();
        for (std::size_t i=0;i<oracle.size();++i) if (oracle[i].cells==members) {found=i;break;}
        CHECK(found<oracle.size());
        if (found==oracle.size()) continue;
        CHECK(!matched[found]);matched[found]=true;
        CHECK(c.cells==oracle[found].cells.size());CHECK(c.material==oracle[found].material);
        CHECK(c.anchored==oracle[found].anchored);CHECK(c.unknown_boundary==oracle[found].unknown_boundary);
    }
}
void ordinary_irregular_edits_match_independent_connectivity() {
    auto settings=config();settings.discovery_budget=37;
    Coordinator coordinator(settings);
    std::mt19937 random(0x001001U);
    for (unsigned revision=0;revision<80;++revision) {
        // Horizontal, diagonal and irregular cuts, hard replacements and
        // distinct cohesion materials all use the ordinary committed edit API.
        for (unsigned mutation=0;mutation<9;++mutation) {
            const auto x=20+static_cast<int>(random()%14),y=20+static_cast<int>(random()%14);
            const std::array<Material,5> choices{Material::Empty,Material::Wood,Material::Wood,Material::RedBrick,Material::Wall};
            CHECK(coordinator.edit(x,y,{choices[random()%choices.size()],0,0,200}).outcome==Outcome::Accepted);
        }
        const auto result=finish_census(coordinator);
        compare_reference_catalogue(coordinator);
        if (result.outcome==Outcome::Accepted) CHECK(coordinator.cancel(result.transaction).outcome==Outcome::Cancelled);
    }
    // A material at the resident edge is unknown, even if it also touches the
    // authored Wall frame. Diagonal Wall near-contact does not anchor Wood.
    CHECK(coordinator.edit(0,40,{Material::Wood,0,0,200}).outcome==Outcome::Accepted);
    CHECK(coordinator.edit(80,40,{Material::Wood,0,0,200}).outcome==Outcome::Accepted);
    CHECK(coordinator.edit(81,41,{Material::Wall,0,0,200}).outcome==Outcome::Accepted);
    const auto result=finish_census(coordinator);compare_reference_catalogue(coordinator);
    CHECK(coordinator.snapshot().admission.unknown_boundary>=1);
    if (result.outcome==Outcome::Accepted) CHECK(coordinator.cancel(result.transaction).outcome==Outcome::Cancelled);
}
void mutation_interrupts_and_resumes_large_component_without_loss() {
    auto settings=config();settings.discovery_budget=16;
    Coordinator coordinator(settings);
    rectangle(coordinator,25,20,40,30);
    bool partial=false;
    for (unsigned call=0;call<2048;++call) {
        const auto result=coordinator.prepare_next();
        CHECK(result.outcome!=Outcome::Accepted);
        if (coordinator.snapshot().admission.frontier_cells>0) {partial=true;break;}
    }
    CHECK(partial);
    // Touch the known first visited cell as well as the far cut: an edit
    // wholly ahead of the frontier is correctly incorporated without restart.
    CHECK(coordinator.edit(25,20,{Material::Empty,0,0,200}).outcome==Outcome::Accepted);
    for (int y=20;y<50;++y) CHECK(coordinator.edit(40,y,{Material::Empty,0,0,200}).outcome==Outcome::Accepted);
    const auto prepared=finish_census(coordinator);
    CHECK(prepared.outcome==Outcome::Accepted);compare_reference_catalogue(coordinator);
    CHECK(coordinator.snapshot().admission.interrupted_searches>0);
    if (prepared.outcome==Outcome::Accepted) {
        CHECK(coordinator.registry().find(prepared.shard)->counts().structural==24*30);
        CHECK(activate(coordinator,prepared.shard));
    }
    CHECK(reference_components(coordinator).size()==1);
}
void independent_capacity_reasons_do_not_hide_an_admissible_component() {
    auto settings=config();settings.limits.max_area=64;settings.limits.max_total_area=192;
    Coordinator coordinator(settings);
    rectangle(coordinator,12,12,8,8); // Count fits; padded bbox does not.
    rectangle(coordinator,35,12,9,9); // Count does not fit either.
    rectangle(coordinator,70,30,3,3); // Independently admissible.
    const auto prepared=finish_census(coordinator);
    CHECK(prepared.outcome==Outcome::Accepted);compare_reference_catalogue(coordinator);
    CHECK(coordinator.snapshot().admission.refused_geometry==2);
    bool count_reason=false,bbox_reason=false;
    for (const auto root:CoordinatorTestAccess::discovery(coordinator).roots()) {
        const auto reason=CoordinatorTestAccess::discovery(coordinator).candidate(root).reason;
        count_reason=count_reason || reason==AdmissionReason::ComponentCells;
        bbox_reason=bbox_reason || reason==AdmissionReason::BoundingBox;
    }
    CHECK(count_reason);CHECK(bbox_reason);
    if (prepared.outcome==Outcome::Accepted) {
        CHECK(coordinator.registry().find(prepared.shard)->counts().structural==9);
        CHECK(activate(coordinator,prepared.shard));
    }
    CHECK(reference_components(coordinator).size()==2);
}
ShardEditRequest erase_request(Coordinator& coordinator,Handle handle,std::uint32_t cell) {
    const auto* shard=coordinator.registry().find(handle);CHECK(shard!=nullptr);
    for (const auto& body:coordinator.snapshot().bodies) if (body.shard==handle)
        return {handle,coordinator.next_transaction(),body.body_generation,shard->geometry().revision,
            body.pose.pose_serial,shard->material_revision(),cell,shard->schedule(cell).incarnation,shard->payload(cell)};
    CHECK(false);return {};
}
bool acknowledge_cut(Coordinator& coordinator,Handle handle) {
    const auto* shard=coordinator.registry().find(handle);CHECK(shard!=nullptr);
    for (const auto& body:coordinator.snapshot().bodies) if (body.shard==handle) {
        const auto& geometry=shard->geometry();
        const auto kind=shard->counts().structural ? AckKind::GeometryInstalled : AckKind::BodyRetired;
        return coordinator.acknowledge({handle,body.transaction,body.body_generation,shard->payload_digest(),
            geometry.revision,geometry.mask_digest,geometry.shape_digest,kind,{}}).outcome==Outcome::Accepted;
    }
    return false;
}
void exact_owned_erasure_and_geometry_capacity() {
    auto settings=config();
    Coordinator coordinator(settings);rectangle(coordinator,30,30,5,5);
    const auto prepared=await_preparation(coordinator);CHECK(prepared.outcome==Outcome::Accepted);
    if (prepared.outcome!=Outcome::Accepted) return;
    CHECK(activate(coordinator,prepared.shard));
    const auto* shard=coordinator.registry().find(prepared.shard);
    const auto origin=shard->bounds();const auto cell=3U*origin.width+3U;
    auto request=erase_request(coordinator,prepared.shard,cell);
    const auto revision=shard->geometry().revision;
    CHECK(coordinator.erase_shard(request).outcome==Outcome::Accepted);
    CHECK(coordinator.paused());CHECK(shard->counts().structural==24);
    CHECK(shard->geometry().revision==revision+1);CHECK(shard->geometry().shapes.size()==4);
    CHECK(shard->bounds().x==origin.x && shard->bounds().y==origin.y);
    const auto accounted=coordinator.accounting().authored_destroyed[static_cast<std::uint8_t>(Material::Wood)];
    CHECK(coordinator.erase_shard(request).outcome==Outcome::Accepted); // Receipt while ACK barrier is closed.
    CHECK(coordinator.accounting().authored_destroyed[static_cast<std::uint8_t>(Material::Wood)]==accounted);
    auto changed=request;++changed.incarnation;
    CHECK(coordinator.erase_shard(changed).outcome==Outcome::Stale);
    CHECK(acknowledge_cut(coordinator,prepared.shard));CHECK(!coordinator.paused());
    for (unsigned i=0;i<70;++i) {
        auto stale=erase_request(coordinator,prepared.shard,1U*origin.width+1U);++stale.body_generation;
        CHECK(coordinator.erase_shard(stale).outcome==Outcome::Stale);
    }
    CHECK(coordinator.erase_shard(request).outcome==Outcome::Expired);
    CHECK(shard->counts().structural==24);
    CHECK(coordinator.reset(0,19).outcome==Outcome::Accepted);
    CHECK(coordinator.erase_shard(request).outcome==Outcome::Retired);

    settings.limits.max_shapes=1;
    Coordinator limited(settings);rectangle(limited,30,30,5,5);
    const auto next=await_preparation(limited);CHECK(next.outcome==Outcome::Accepted);
    if (next.outcome!=Outcome::Accepted) return;
    CHECK(activate(limited,next.shard));
    const auto* exact=limited.registry().find(next.shard);
    const auto digest=exact->payload_digest(),geometry=exact->geometry().revision;
    const auto refused=erase_request(limited,next.shard,3U*exact->bounds().width+3U);
    CHECK(limited.erase_shard(refused).outcome==Outcome::Capacity);
    CHECK(limited.erase_shard(refused).outcome==Outcome::Capacity);
    CHECK(exact->payload_digest()==digest);CHECK(exact->geometry().revision==geometry);
    CHECK(exact->counts().structural==25);CHECK(!limited.paused());
    CHECK(limited.accounting().authored_destroyed[static_cast<std::uint8_t>(Material::Wood)]==0);
}
void remove_owned_structure(Coordinator& coordinator,Handle handle) {
    const auto* shard=coordinator.registry().find(handle);CHECK(shard!=nullptr);
    for (std::uint32_t cell=0;cell<shard->area();++cell) if (shard->structural(cell)) {
        const auto request=erase_request(coordinator,handle,cell);
        CHECK(coordinator.erase_shard(request).outcome==Outcome::Accepted);
        CHECK(acknowledge_cut(coordinator,handle));
    }
    CHECK(coordinator.step().outcome==Outcome::Accepted);
    CHECK(coordinator.registry().find(handle)==nullptr);
}
void admission_age_prevents_small_component_starvation_and_reuses_released_slot() {
    auto settings=config();settings.limits.max_shards=1;
    Coordinator coordinator(settings);
    rectangle(coordinator,8,8,1,1);
    for (unsigned round=0;round<4;++round) {
        const auto side=static_cast<int>(round)+3;
        rectangle(coordinator,30+static_cast<int>(round)*18,25,side,side);
        const auto prepared=await_preparation(coordinator);CHECK(prepared.outcome==Outcome::Accepted);
        if (prepared.outcome!=Outcome::Accepted) return;
        const auto expected=round==3 ? 1U : static_cast<unsigned>(side*side);
        CHECK(coordinator.registry().find(prepared.shard)->counts().structural==expected);
        CHECK(activate(coordinator,prepared.shard));
        for (unsigned call=0;call<16;++call) (void)coordinator.prepare_next();
        CHECK(coordinator.snapshot().admission.slots_used==1);
        CHECK(coordinator.snapshot().admission.deferred>=1);
        remove_owned_structure(coordinator,prepared.shard);
    }
    const auto remaining=reference_components(coordinator);
    CHECK(remaining.size()==1);CHECK(remaining[0].cells.size()==36);
}
void exact_shape_refusal_does_not_starve_other_eligible_geometry() {
    auto settings=config();settings.limits.max_shapes=2;
    Coordinator coordinator(settings);
    for (int y=10;y<20;++y) {
        CHECK(coordinator.edit(10,y,{Material::Wood,0,0,200}).outcome==Outcome::Accepted);
        if ((y&1)==0) for (int x=11;x<20;++x)
            CHECK(coordinator.edit(x,y,{Material::Wood,0,0,200}).outcome==Outcome::Accepted);
    }
    rectangle(coordinator,60,30,5,5);
    const auto prepared=await_preparation(coordinator);CHECK(prepared.outcome==Outcome::Accepted);
    if (prepared.outcome!=Outcome::Accepted) return;
    CHECK(coordinator.registry().find(prepared.shard)->counts().structural==25);
    bool exact_refusal=false;
    for (const auto root:CoordinatorTestAccess::discovery(coordinator).roots())
        exact_refusal=exact_refusal || CoordinatorTestAccess::discovery(coordinator).candidate(root).reason==AdmissionReason::ShapeLimit;
    CHECK(exact_refusal);CHECK(activate(coordinator,prepared.shard));
    const auto census=finish_census(coordinator);CHECK(census.outcome==Outcome::Capacity);
    const auto work=coordinator.metrics().discovered_cells;
    for (unsigned call=0;call<1000;++call) (void)coordinator.prepare_next();
    CHECK(coordinator.metrics().discovered_cells==work);
    CHECK(reference_components(coordinator)[0].cells.size()==55);
}
void session_metrics_are_distinct_from_process_history() {
    Coordinator coordinator(config());
    for (unsigned i=0;i<12;++i) CHECK(coordinator.step().outcome==Outcome::Accepted);
    const auto previous=coordinator.snapshot().metrics;
    CHECK(previous.steps==12);CHECK(previous.peak_bytes>0);
    CHECK(coordinator.reset(0,24).outcome==Outcome::Accepted);
    const auto reset=coordinator.snapshot();
    CHECK(reset.metrics.steps==0);CHECK(reset.metrics.promotions==0);CHECK(reset.metrics.maximum_pause_ns==0);
    CHECK(reset.lifetime_metrics.steps==12);CHECK(reset.lifetime_metrics.peak_bytes>=previous.peak_bytes);
    CHECK(coordinator.step().outcome==Outcome::Accepted);
    CHECK(coordinator.snapshot().metrics.steps==1);CHECK(coordinator.snapshot().lifetime_metrics.steps==13);
}
void ordinary_tree_trunk_horizontal_and_diagonal_cuts() {
    for (unsigned pattern=0;pattern<5;++pattern) {
        Config settings;settings.scenario=2;
        Coordinator coordinator(settings);
        const auto floor=settings.world_bounds.height-18;
        const auto trunk=settings.world_bounds.width/2;
        // Let the reference supported structure enter the catalogue first.
        const auto supported=finish_census(coordinator);CHECK(supported.outcome!=Outcome::Accepted);
        if (pattern==0) {
            for (int y=floor-31;y<floor;++y) for (int x=trunk-2;x<=trunk+1;++x)
                CHECK(coordinator.edit(x,y,{Material::Empty,0,0,200}).outcome==Outcome::Accepted);
        } else if (pattern<4) {
            const auto height=floor-6-static_cast<int>(pattern)*9;
            for (int x=trunk-14;x<trunk+18;++x)
                CHECK(coordinator.edit(x,height,{Material::Empty,0,0,200}).outcome==Outcome::Accepted);
        } else {
            // A two-cell staircase cut is a genuine four-connected separator;
            // diagonal visual proximity alone is not assumed to sever a bond.
            for (int x=trunk-14;x<trunk+18;++x) {
                const auto y=floor-48+(x-(trunk-14))/2;
                CHECK(coordinator.edit(x,y,{Material::Empty,0,0,200}).outcome==Outcome::Accepted);
                CHECK(coordinator.edit(x,y+1,{Material::Empty,0,0,200}).outcome==Outcome::Accepted);
            }
        }
        auto oracle=reference_components(coordinator);
        std::size_t largest=0;
        for (const auto& c:oracle) if (!c.anchored && !c.unknown_boundary) largest=std::max(largest,c.cells.size());
        CHECK(largest>=100);
        const auto prepared=finish_census(coordinator);CHECK(prepared.outcome==Outcome::Accepted);
        compare_reference_catalogue(coordinator);
        if (prepared.outcome==Outcome::Accepted) {
            CHECK(coordinator.registry().find(prepared.shard)->counts().structural==largest);
            CHECK(activate(coordinator,prepared.shard));
        }
    }
}
void transient_refusals_skip_large_candidate_and_retry_without_topology_change() {
    Coordinator coordinator(config());
    rectangle(coordinator,30,25,10,10);rectangle(coordinator,65,30,3,3);
    // Fault injection through the real World occupancy API: a host footprint
    // temporarily covers one exact source cell. It does not change inventory.
    auto& world=CoordinatorTestAccess::world(coordinator);
    CHECK(world.set_transient_obstacle(34,29,1));
    const auto blocked=finish_census(coordinator);
    CHECK(blocked.outcome==Outcome::Unsupported);
    CHECK(coordinator.registry().inventory_counts().total()==0);
    const auto blocked_work=coordinator.metrics().discovered_cells;
    const auto smaller=await_preparation(coordinator,16);
    CHECK(smaller.outcome==Outcome::Accepted);
    if (smaller.outcome!=Outcome::Accepted) return;
    CHECK(coordinator.registry().find(smaller.shard)->counts().structural==9);
    CHECK(coordinator.metrics().discovered_cells==blocked_work);
    CHECK(activate(coordinator,smaller.shard));
    // The real postcommit mask install clears the injected absent-body mask;
    // no source-material topology edit authorizes the subsequent retry.
    CHECK(world.transient_obstacle_at(34,29)==0);
    const auto larger=await_preparation(coordinator,32);
    CHECK(larger.outcome==Outcome::Accepted);
    if (larger.outcome==Outcome::Accepted) {
        CHECK(coordinator.registry().find(larger.shard)->counts().structural==100);
        CHECK(activate(coordinator,larger.shard));
    }
    CHECK(coordinator.registry().inventory_counts().structural==109);
}
void pending_relevant_work_stays_with_world_without_blocking_unrelated_component() {
    Coordinator coordinator(config());
    rectangle(coordinator,30,25,10,10);rectangle(coordinator,70,35,3,3);
    CHECK(CoordinatorTestAccess::world(coordinator).queue_explosion(34,29,2));
    const auto blocked=finish_census(coordinator);CHECK(blocked.outcome==Outcome::PendingEvent);
    CHECK(coordinator.registry().inventory_counts().total()==0);
    const auto unrelated=await_preparation(coordinator,16);CHECK(unrelated.outcome==Outcome::Accepted);
    if (unrelated.outcome!=Outcome::Accepted) return;
    CHECK(coordinator.registry().find(unrelated.shard)->counts().structural==9);
    // Preparation and commit use the same conservative affected bounds. The
    // queued event cannot become an unresolvable paused-state deadlock.
    CHECK(activate(coordinator,unrelated.shard));
    CHECK(coordinator.world().quantity_ledger().material_cells[static_cast<std::uint8_t>(Material::Wood)]==100);
    const auto before=coordinator.metrics().discovered_cells;
    for (unsigned call=0;call<64;++call) {
        const auto retry=coordinator.prepare_next();
        CHECK(retry.outcome==Outcome::Busy || retry.outcome==Outcome::PendingEvent);
    }
    // One postcommit invalidation pass is permitted; repeated live refusals
    // themselves never rerun the complete large-component connectivity search.
    const auto cached=coordinator.metrics().discovered_cells;
    for (unsigned call=0;call<64;++call) (void)coordinator.prepare_next();
    CHECK(coordinator.metrics().discovered_cells==cached);CHECK(cached>=before);
    CHECK(coordinator.registry().inventory_counts().structural==9);
}
}
int main() {
    simultaneous_fragments_prefer_large_structure();
    discovery_budget_is_resumable();
    ordinary_irregular_edits_match_independent_connectivity();
    mutation_interrupts_and_resumes_large_component_without_loss();
    independent_capacity_reasons_do_not_hide_an_admissible_component();
    exact_owned_erasure_and_geometry_capacity();
    admission_age_prevents_small_component_starvation_and_reuses_released_slot();
    exact_shape_refusal_does_not_starve_other_eligible_geometry();
    session_metrics_are_distinct_from_process_history();
    ordinary_tree_trunk_horizontal_and_diagonal_cuts();
    transient_refusals_skip_large_candidate_and_retry_without_topology_change();
    pending_relevant_work_stays_with_world_without_blocking_unrelated_component();
    std::printf("ObjectShard admission: %llu checks, %llu failures\n",
        static_cast<unsigned long long>(checks), static_cast<unsigned long long>(failures));
    return failures == 0 ? 0 : 1;
}
