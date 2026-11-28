#include "cybersand/object_shard.hpp"

#include <array>
#include <atomic>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <limits>
#include <new>

namespace {
std::atomic<std::uint64_t> allocations{};
std::uint64_t checks{}, failures{};
void check(bool pass, const char* what, int line) {
    ++checks;
    if (!pass) { ++failures; std::fprintf(stderr, "FAIL line %d: %s\n", line, what); }
}
#define CHECK(expression) check((expression), #expression, __LINE__)
using namespace cybersand;
using namespace cybersand::object_shard;

Payload wood(std::uint8_t burn = 0, std::int16_t temperature = 200) {
    return {Material::Wood, 0, burn, temperature};
}
Payload empty(std::int16_t temperature = 200) { return {Material::Empty, 0, 0, temperature}; }
void exact_cover(const Shard& shard) {
    std::array<std::uint16_t, 4'096> coverage{};
    CHECK(shard.area() <= coverage.size());
    if (shard.area() > coverage.size()) return;
    const auto bounds = shard.bounds();
    for (const auto& rect : shard.geometry().shapes) {
        CHECK(rect.width != 0 && rect.height != 0);
        CHECK(static_cast<std::size_t>(rect.x) + rect.width <= bounds.width);
        CHECK(static_cast<std::size_t>(rect.y) + rect.height <= bounds.height);
        for (std::size_t y = rect.y; y < static_cast<std::size_t>(rect.y) + rect.height; ++y)
            for (std::size_t x = rect.x; x < static_cast<std::size_t>(rect.x) + rect.width; ++x)
                ++coverage[y * bounds.width + x];
    }
    for (std::size_t i = 0; i < shard.area(); ++i)
        CHECK(coverage[i] == (shard.structural(i) ? 1 : 0));
}
void activate(Registry& registry, Handle handle) {
    auto* shard = registry.find(handle);
    CHECK(shard != nullptr);
    if (!shard) return;
    CHECK(registry.finish_preparation(handle) == Outcome::Accepted);
    CHECK(registry.reserve_physics(handle) == Outcome::Accepted);
    CHECK(registry.commit(handle) == Outcome::Accepted);
    CHECK(!shard->chemistry_allowed());
    CHECK(registry.advance(handle, Phase::CommittedInactive, Phase::TerrainInstalled) == Outcome::Accepted);
    CHECK(registry.advance(handle, Phase::TerrainInstalled, Phase::MaskApplied) == Outcome::Accepted);
    CHECK(registry.advance(handle, Phase::MaskApplied, Phase::ReadyToActivate) == Outcome::Accepted);
    CHECK(!shard->chemistry_allowed());
    CHECK(registry.advance(handle, Phase::ReadyToActivate, Phase::Active) == Outcome::Fenced);
    const auto& geometry = shard->geometry();
    CHECK(shard->acknowledge_geometry(geometry.revision, geometry.mask_digest, geometry.shape_digest) == Outcome::Accepted);
    CHECK(registry.advance(handle, Phase::ReadyToActivate, Phase::Active) == Outcome::Accepted);
    CHECK(shard->chemistry_allowed());
}

void payload_identity_and_activation() {
    Registry registry;
    Handle handle;
    CHECK(registry.prepare({-64, -128, 8, 8}, 255, handle) == Outcome::Accepted);
    auto* shard = registry.find(handle);
    CHECK(shard != nullptr);
    CHECK(shard->set_cell(27, {Material::Wood, 65'535, 211, -1'234}, Role::Structural, 255) == Outcome::Accepted);
    CHECK((shard->payload(27) == Payload{Material::Wood, 65'535, 211, -1'234}));
    CHECK(shard->schedule(27).birth_tick == 255);
    CHECK(shard->schedule(27).next_due_tick == 256);
    CHECK(registry.inventory_counts().total() == 0); // Staging is not ownership.
    const auto incarnation = shard->schedule(27).incarnation;
    const auto anchor = shard->bounds();
    const auto digest = shard->payload_digest();
    CHECK(shard->set_cell(27, {Material::Wood, 65'535, 210, -1'233}, Role::Structural, 255) == Outcome::Accepted);
    CHECK(shard->payload_digest() != digest);
    CHECK(shard->schedule(27).incarnation == incarnation);
    CHECK(shard->set_due(27, 255) == Outcome::Stale);
    CHECK(shard->set_due(27, 257) == Outcome::Accepted);
    CHECK(registry.finish_preparation(handle) == Outcome::Accepted);
    CHECK(registry.reserve_physics(handle) == Outcome::Accepted);
    CHECK(shard->set_cell(27, wood(20), Role::Structural, 256) == Outcome::Fenced);
    CHECK(shard->validate_cell_write(27, wood(20), Role::Structural, 256) == Outcome::Fenced);
    CHECK(registry.commit(handle) == Outcome::Accepted);
    CHECK(registry.inventory_counts().structural == 1);
    CHECK(registry.commit(handle) == Outcome::Stale);
    CHECK(registry.cancel_precommit(handle) == Outcome::Fenced);
    CHECK(shard->set_cell(27, wood(20), Role::Structural, 256) == Outcome::Fenced);
    CHECK(registry.advance(handle, Phase::CommittedInactive, Phase::Active) == Outcome::Stale);
    CHECK(registry.advance(handle, Phase::CommittedInactive, Phase::TerrainInstalled) == Outcome::Accepted);
    CHECK(registry.advance(handle, Phase::TerrainInstalled, Phase::MaskApplied) == Outcome::Accepted);
    CHECK(registry.advance(handle, Phase::MaskApplied, Phase::ReadyToActivate) == Outcome::Accepted);
    const auto geometry = shard->geometry();
    CHECK(shard->acknowledge_geometry(geometry.revision, geometry.mask_digest ^ 1U, geometry.shape_digest) == Outcome::Stale);
    CHECK(shard->acknowledge_geometry(geometry.revision, geometry.mask_digest, geometry.shape_digest) == Outcome::Accepted);
    CHECK(registry.advance(handle, Phase::ReadyToActivate, Phase::Active) == Outcome::Accepted);
    CHECK(shard->set_cell(27, {Material::Wood, 65'535, 209, -1'233}, Role::Structural, 256) == Outcome::Accepted);
    CHECK(shard->schedule(27).incarnation == incarnation);
    CHECK(shard->set_cell(27, {Material::RedBrick, 0, 0, -1'233}, Role::Structural, 257) == Outcome::Accepted);
    CHECK(shard->schedule(27).incarnation == incarnation + 1);
    CHECK(shard->bounds() == anchor);
    CHECK(!shard->geometry_dirty()); // Same unit-mass occupied rigid cell.
    CHECK(shard->set_cell(27, empty(), Role::Empty, 258) == Outcome::Accepted);
    CHECK(shard->phase() == Phase::Draining);
    CHECK(shard->bounds() == anchor);
    CHECK(registry.rebuild_geometry(handle, 258) == Outcome::Accepted);
    CHECK(shard->geometry().shapes.empty());
    CHECK(shard->geometry().mass.mass == 0.0);
    CHECK(std::isfinite(shard->geometry().mass.com_x));
    CHECK(registry.retire(handle) == Outcome::Accepted);
    CHECK(registry.find(handle) == nullptr);
    CHECK(registry.retire(handle) == Outcome::Stale);
}

void exact_geometry_holes_and_islands() {
    Registry registry;
    Handle handle;
    CHECK(registry.prepare({100, -200, 17, 17}, 7, handle) == Outcome::Accepted);
    auto* shard = registry.find(handle);
    for (std::size_t y = 1; y < 16; ++y)
        for (std::size_t x = 1; x < 16; ++x)
            CHECK(shard->set_cell(y * 17 + x, wood(), Role::Structural, 7) == Outcome::Accepted);
    activate(registry, handle);
    CHECK(shard->geometry().shapes.size() == 1);
    CHECK(shard->geometry().mass.mass == 225.0);
    CHECK(shard->geometry().mass.com_x == 8.5 && shard->geometry().mass.com_y == 8.5);
    CHECK(!shard->surface(8 * 17 + 8));
    const auto initial_geometry = shard->geometry();
    const auto origin = shard->bounds();
    // Multiple internal holes must remain holes and exceed the historical
    // eight-rectangle/body envelope without fragmenting the material owner.
    for (std::size_t y = 3; y <= 13; y += 2)
        for (std::size_t x = 3; x <= 13; x += 2)
            CHECK(shard->set_cell(y * 17 + x, empty(), Role::Empty, 8) == Outcome::Accepted);
    CHECK(shard->geometry_dirty());
    CHECK(shard->acknowledge_geometry(initial_geometry.revision, initial_geometry.mask_digest,
        initial_geometry.shape_digest) == Outcome::Stale);
    CHECK(registry.rebuild_geometry(handle, 8) == Outcome::Accepted);
    CHECK(shard->geometry().shapes.size() > 8);
    CHECK(shard->geometry().islands == 1);
    CHECK(shard->geometry().mass.mass == 189.0);
    CHECK(shard->surface(3 * 17 + 2));
    CHECK(shard->bounds() == origin);
    exact_cover(*shard);
    // Sever the centre. Chemistry remains permitted in the exact compound;
    // the approximation is explicitly split_pending, not silently filled.
    for (std::size_t y = 1; y < 16; ++y)
        CHECK(shard->set_cell(y * 17 + 8, empty(), Role::Empty, 9) == Outcome::Accepted);
    CHECK(registry.rebuild_geometry(handle, 9) == Outcome::Accepted);
    CHECK(shard->geometry().islands == 2);
    CHECK(shard->geometry().split_pending);
    CHECK(shard->chemistry_allowed());
    exact_cover(*shard);
    const auto revision = shard->geometry().revision;
    CHECK(registry.rebuild_geometry(handle, 10) == Outcome::Accepted);
    CHECK(shard->geometry().revision == revision); // Coalesces clean rebuilds.
}

void products_cargo_and_draining() {
    Registry registry;
    Handle handle;
    CHECK(registry.prepare({0, 0, 7, 7}, 40, handle) == Outcome::Accepted);
    auto* shard = registry.find(handle);
    CHECK(shard->set_cell(24, wood(80), Role::Structural, 40) == Outcome::Accepted);
    activate(registry, handle);
    CHECK(shard->set_cell(17, {Material::Fire, 32, 0, 700}, Role::Product, 41) == Outcome::Accepted);
    CHECK(shard->occupied(17) && !shard->structural(17));
    CHECK(!shard->geometry_dirty());
    const auto pre_cargo_shapes = shard->geometry().shapes;
    const auto pre_cargo_digest = shard->geometry().shape_digest;
    CHECK(shard->set_cell(25, {Material::Sand, 31'337, 217, -400}, Role::Cargo, 41) == Outcome::Accepted);
    CHECK(shard->occupied(25) && !shard->structural(25));
    CHECK(registry.rebuild_geometry(handle, 41) == Outcome::Accepted);
    CHECK(shard->geometry().mass.mass == 2.0);
    CHECK(shard->geometry().shapes.size() == 1);
    CHECK(shard->geometry().shapes == pre_cargo_shapes);
    CHECK(shard->geometry().shape_digest != pre_cargo_digest);
    CHECK(shard->geometry().mass.com_x == 4.0);
    CHECK(shard->set_cell(24, empty(), Role::Empty, 42) == Outcome::Accepted);
    CHECK(shard->phase() == Phase::Draining);
    CHECK(shard->chemistry_allowed());
    CHECK(registry.retire(handle) == Outcome::Busy);
    CHECK(registry.inventory_counts().structural == 0);
    CHECK(registry.inventory_counts().products == 1 && registry.inventory_counts().cargo == 1);
    const auto fire_incarnation = shard->schedule(17).incarnation;
    CHECK(shard->set_cell(17, {Material::Smoke, 240, 0, 700}, Role::Product, 43) == Outcome::Accepted);
    CHECK(shard->schedule(17).incarnation == fire_incarnation + 1);
    CHECK((shard->payload(25) == Payload{Material::Sand, 31'337, 217, -400}));
    CHECK(registry.rebuild_geometry(handle, 43) == Outcome::Accepted);
    CHECK(shard->geometry().shapes.empty());
    CHECK(shard->geometry().mass.mass == 1.0); // Cargo is retained; no body is implied.
    CHECK(registry.advance(handle, Phase::Draining, Phase::Active) == Outcome::Stale);
    CHECK(shard->set_cell(17, empty(), Role::Empty, 44) == Outcome::Accepted);
    CHECK(shard->set_cell(25, empty(), Role::Empty, 44) == Outcome::Accepted);
    CHECK(registry.retire(handle) == Outcome::Accepted);
    CHECK(registry.inventory_counts().total() == 0);
}

void capacity_refusal_and_quarantine() {
    Limits limits;
    limits.max_shards = 3; limits.max_area = 64; limits.max_total_area = 128; limits.max_shapes = 1;
    Registry registry(limits);
    Handle a, b, c;
    CHECK(registry.prepare({0, 0, 9, 9}, 0, a) == Outcome::Capacity);
    CHECK(registry.prepare({0, 0, 8, 8}, 0, a) == Outcome::Accepted);
    CHECK(registry.prepare({20, 0, 8, 8}, 0, b) == Outcome::Accepted);
    CHECK(registry.prepare({40, 0, 1, 1}, 0, c) == Outcome::Capacity);
    auto* shard = registry.find(a);
    CHECK(shard->set_cell(9, wood(), Role::Structural, 0) == Outcome::Accepted);
    CHECK(shard->set_cell(10, wood(), Role::Structural, 0) == Outcome::Accepted);
    CHECK(shard->set_cell(11, wood(), Role::Structural, 0) == Outcome::Accepted);
    activate(registry, a);
    const auto geometry = shard->geometry();
    CHECK(shard->set_cell(10, empty(), Role::Empty, 1) == Outcome::Accepted);
    CHECK(registry.rebuild_geometry(a, 1) == Outcome::Capacity);
    CHECK(shard->phase() == Phase::Suspended);
    CHECK(shard->owns_inventory());
    CHECK(shard->counts().structural == 2);
    CHECK(shard->geometry().revision == geometry.revision);
    CHECK(shard->geometry_dirty());
    CHECK(!shard->chemistry_allowed());
    CHECK(shard->acknowledge_geometry(geometry.revision, geometry.mask_digest, geometry.shape_digest) == Outcome::Stale);
    CHECK(registry.advance(a, Phase::Suspended, Phase::Active) == Outcome::Fenced);
    CHECK(registry.quarantine(a) == Outcome::Quarantined);
    CHECK(shard->set_cell(9, empty(), Role::Empty, 2) == Outcome::Quarantined);
    CHECK(registry.inventory_counts().structural == 2);
    CHECK(registry.cancel_precommit(b) == Outcome::Cancelled);
    CHECK(registry.cancel_precommit(b) == Outcome::Stale);
    CHECK(registry.prepare({40, 0, 8, 8}, 0, c) == Outcome::Accepted);
    CHECK(c.id != b.id && c.generation > b.generation);
    CHECK(registry.find(b) == nullptr);
    const auto live_before = registry.memory_usage().retained_bytes;
    CHECK(registry.cancel_precommit(c) == Outcome::Cancelled);
    CHECK(registry.memory_usage().retained_bytes < live_before);
    Counts disposed;
    CHECK(registry.reset(2, 91, disposed) == Outcome::Accepted);
    CHECK(disposed.structural == 2);
    CHECK(registry.inventory_counts().total() == 0);
    CHECK(registry.find(a) == nullptr);
    CHECK(registry.reset(2, 92, disposed) == Outcome::Stale);
    CHECK(registry.prepare({-10, 40, 8, 8}, 0, c) == Outcome::Accepted);
    CHECK(c.session == 2 && c.id > a.id);
    CHECK(registry.find(c)->world_incarnation() == 91);
}

void explicit_capabilities_and_optional_temperature() {
    Limits limits; limits.temperature_storage = false;
    Registry registry(limits);
    Handle handle;
    CHECK(registry.prepare({0, 0, 5, 5}, 0, handle) == Outcome::Accepted);
    auto* shard = registry.find(handle);
    const auto digest = shard->payload_digest();
    CHECK(shard->set_cell(12, {Material::Sand, 0, 0, 200}, Role::Structural, 0) == Outcome::Unsupported);
    CHECK(shard->set_cell(12, {Material::Plant, 0, 0, 200}, Role::Structural, 0) == Outcome::Unsupported);
    CHECK(shard->set_cell(12, {Material::Water, 255, 0, 200}, Role::Cargo, 0) == Outcome::Unsupported);
    CHECK(shard->set_cell(12, wood(3, 201), Role::Structural, 0) == Outcome::Unsupported);
    CHECK(shard->validate_cell_write(12, wood(3, 201), Role::Structural, 0) == Outcome::Unsupported);
    CHECK(shard->payload_digest() == digest);
    CHECK(shard->set_cell(12, wood(3), Role::Structural, 0) == Outcome::Accepted);
    CHECK(shard->payload(12).temperature == 200);
    CHECK(!valid_bounds({std::numeric_limits<std::int64_t>::max(), 0, 2, 1}));
    CHECK(!valid_bounds({0, 0, 0, 1}));
    CHECK(valid_bounds({std::numeric_limits<std::int64_t>::min(), -1, 1, 1}));
}

void destination_preflight_is_nonmutating_and_matches_commit() {
    Registry registry;
    Handle handle;
    CHECK(registry.prepare({0, 0, 5, 5}, 7, handle) == Outcome::Accepted);
    auto* shard = registry.find(handle);
    CHECK(shard->set_cell(12, wood(3, 420), Role::Structural, 7) == Outcome::Accepted);
    activate(registry, handle);
    const auto attempt = [&](std::size_t index, Payload payload, Role role,
                             std::uint64_t tick, Outcome expected, bool replace_identity = false) {
        const auto digest = shard->payload_digest();
        const auto material_revision = shard->material_revision();
        const auto topology_revision = shard->topology_revision();
        const auto allocation_count = allocations.load();
        CHECK(shard->validate_cell_write(index, payload, role, tick, replace_identity) == expected);
        CHECK(shard->payload_digest() == digest);
        CHECK(shard->material_revision() == material_revision && shard->topology_revision() == topology_revision);
        CHECK(allocations.load() == allocation_count);
        CHECK(shard->set_cell(index, payload, role, tick, replace_identity) == expected);
        if (expected != Outcome::Accepted) CHECK(shard->payload_digest() == digest);
    };
    attempt(25, wood(), Role::Structural, 8, Outcome::Unsupported);
    attempt(7, {Material::Water, 255, 0, 200}, Role::Cargo, 8, Outcome::Unsupported);
    attempt(7, {Material::Plant, 0, 0, 200}, Role::Structural, 8, Outcome::Unsupported);
    attempt(7, {Material::Empty, 1, 0, 200}, Role::Empty, 8, Outcome::Invalid);
    attempt(7, wood(), Role::Structural, 6, Outcome::Stale);
    attempt(7, wood(), Role::Structural, std::numeric_limits<std::uint64_t>::max(), Outcome::Stale);
    attempt(12, wood(3, 420), Role::Structural, 8, Outcome::Accepted);
    attempt(12, wood(2, 419), Role::Structural, 8, Outcome::Accepted);
    attempt(7, {Material::Sand, 211, 19, -470}, Role::Cargo, 8, Outcome::Accepted);
    attempt(12, wood(2, 419), Role::Structural, 8, Outcome::Accepted, true);
    CHECK(registry.quarantine(handle) == Outcome::Quarantined);
    attempt(7, empty(), Role::Empty, 9, Outcome::Quarantined);
}

void partial_commit_retains_exact_debited_inventory() {
    Registry registry;
    Handle handle;
    CHECK(registry.prepare({-4, 8, 6, 6}, 90, handle) == Outcome::Accepted);
    auto* shard = registry.find(handle);
    for (std::size_t index : {14U, 15U, 16U})
        CHECK(shard->set_cell(index, wood(static_cast<std::uint8_t>(index),
            static_cast<std::int16_t>(300 + index)), Role::Structural, 90) == Outcome::Accepted);
    CHECK(registry.finish_preparation(handle) == Outcome::Accepted);
    CHECK(registry.reserve_physics(handle) == Outcome::Accepted);
    CHECK(registry.commit(handle) == Outcome::Accepted);
    const auto digest = shard->payload_digest();
    const std::array<std::uint32_t, 2> duplicates{14, 14};
    CHECK(registry.quarantine_partial_commit(handle, duplicates) == Outcome::Invalid);
    CHECK(shard->payload_digest() == digest);
    const std::array<std::uint32_t, 2> actual_debits{14, 16};
    const auto allocations_before = allocations.load();
    CHECK(registry.quarantine_partial_commit(handle, actual_debits) == Outcome::Quarantined);
    CHECK(allocations.load() == allocations_before);
    CHECK(shard->counts().structural == 2);
    CHECK(shard->payload(14) == wood(14, 314));
    CHECK(shard->payload(16) == wood(16, 316));
    CHECK(shard->payload(15).material == Material::Empty);
    CHECK(!shard->occupied(15));
    CHECK(shard->owns_inventory() && !shard->chemistry_allowed());
    CHECK(shard->geometry_dirty());
    CHECK(registry.quarantine_partial_commit(handle, actual_debits) == Outcome::Fenced);
    CHECK(registry.inventory_counts().structural == 2);
}

void three_owners_and_no_tick_allocations() {
    Registry registry;
    std::array<Handle, 3> handles;
    for (std::size_t n = 0; n < handles.size(); ++n) {
        CHECK(registry.prepare({static_cast<std::int64_t>(n * 20), -20, 10, 10}, 255, handles[n]) == Outcome::Accepted);
        auto* shard = registry.find(handles[n]);
        for (std::size_t y = 1; y < 9; ++y)
            for (std::size_t x = 1; x < 9; ++x)
                CHECK(shard->set_cell(y * 10 + x, wood(90), Role::Structural, 255) == Outcome::Accepted);
        activate(registry, handles[n]);
    }
    CHECK(handles[0].id != handles[1].id && handles[1].id != handles[2].id);
    Handle refused;
    CHECK(registry.prepare({100, 0, 1, 1}, 255, refused) == Outcome::Capacity);
    const auto before = allocations.load();
    const auto retained_before = registry.memory_usage().retained_bytes;
    for (std::uint64_t tick = 256; tick < 768; ++tick) {
        for (const auto handle : handles) {
            auto* shard = registry.find(handle);
            CHECK(shard->set_cell(44, wood(static_cast<std::uint8_t>(tick & 255U)), Role::Structural, tick) == Outcome::Accepted);
            CHECK(shard->set_cell(45, tick % 2 == 0 ? empty() : wood(),
                tick % 2 == 0 ? Role::Empty : Role::Structural, tick) == Outcome::Accepted);
            CHECK(registry.rebuild_geometry(handle, tick) == Outcome::Accepted);
            const auto& geometry = shard->geometry();
            CHECK(shard->acknowledge_geometry(geometry.revision, geometry.mask_digest,
                geometry.shape_digest) == Outcome::Accepted);
        }
    }
    CHECK(allocations.load() == before);
    CHECK(registry.memory_usage().retained_bytes == retained_before);
    CHECK(registry.inventory_counts().structural == 192);
    for (const auto handle : handles) exact_cover(*registry.find(handle));
    const auto memory = registry.memory_usage();
    std::printf("STORAGE memory live=%zu retained=%zu peak=%zu construction_allocations=%llu steady_allocations=%llu\n",
        memory.live_bytes, memory.retained_bytes, memory.peak_bytes,
        static_cast<unsigned long long>(memory.construction_allocations),
        static_cast<unsigned long long>(allocations.load() - before));
}
void fragments_preserve_carriers_clocks_and_refuse_without_debit() {
    for (const auto capacity:{1U,3U}) {
        Limits limits;limits.max_shards=capacity;
        Registry registry(limits);Handle parent_handle;
        CHECK(registry.prepare({-64,-32,8,6},255,parent_handle)==Outcome::Accepted);
        auto* parent=registry.find(parent_handle);
        CHECK(parent->set_cell(9,wood(200,400),Role::Structural,255)==Outcome::Accepted);
        for (const auto at:{13U,14U,21U,22U})
            CHECK(parent->set_cell(at,{Material::Concrete},Role::Structural,255)==Outcome::Accepted);
        activate(registry,parent_handle);
        CHECK(parent->set_cell(8,{Material::Fire,180,0,450},Role::Product,256)==Outcome::Accepted);
        CHECK(parent->set_due(8,300)==Outcome::Accepted);
        CHECK(parent->set_cell(17,{Material::Sand,33,2,350},Role::Cargo,256)==Outcome::Accepted);
        CHECK(parent->set_due(17,301)==Outcome::Accepted);
        CHECK(registry.rebuild_geometry(parent_handle,256)==Outcome::Accepted);
        const auto& geometry=parent->geometry();
        CHECK(parent->acknowledge_geometry(geometry.revision,geometry.mask_digest,geometry.shape_digest)==Outcome::Accepted);
        const auto digest=parent->payload_digest();
        Handle child_handle;const auto ready=registry.prepare_fragment(parent_handle,260,child_handle);
        CHECK(ready==(capacity==1 ? Outcome::Capacity : Outcome::Accepted));
        CHECK(parent->payload_digest()==digest && registry.inventory_counts().total()==7);
        if (capacity==1) continue;
        auto* child=registry.find(child_handle);
        CHECK(child && child->counts().structural==1 && child->counts().products==1 && child->counts().cargo==1);
        const auto dx=child->bounds().x-parent->bounds().x,dy=child->bounds().y-parent->bounds().y;
        for (std::size_t at=0;at<child->area();++at) if (child->occupied(at)) {
            const auto source=static_cast<std::size_t>(dy+at/child->bounds().width)*8+dx+at%child->bounds().width;
            CHECK(child->payload(at)==parent->payload(source));
            CHECK(child->role(at)==parent->role(source));
            CHECK(child->schedule(at).birth_tick==parent->schedule(source).birth_tick);
            CHECK(child->schedule(at).next_due_tick==parent->schedule(source).next_due_tick);
            CHECK(child->schedule(at).incarnation==parent->schedule(source).incarnation);
        }
        CHECK(registry.reserve_physics(child_handle)==Outcome::Accepted);
        const auto allocations_before=allocations.load();
        CHECK(registry.commit_fragment(parent_handle,child_handle,260)==Outcome::Accepted);
        CHECK(allocations.load()==allocations_before);
        CHECK(registry.inventory_counts().total()==7);
        CHECK(parent->counts().structural==4 && parent->counts().products==0 && parent->counts().cargo==0);
        CHECK(child->owns_inventory() && child->geometry().islands==1);
        CHECK(registry.commit_fragment(parent_handle,child_handle,260)==Outcome::Fenced);
        CHECK(registry.inventory_counts().total()==7);
        exact_cover(*parent);exact_cover(*child);
    }
}

void batched_erase_is_atomic_bounded_and_rebuilds_once() {
    Registry registry;
    Handle handle;
    CHECK(registry.prepare({10,20,20,20},5,handle)==Outcome::Accepted);
    auto* shard=registry.find(handle);
    for (std::uint32_t y=1;y<19;++y) for (std::uint32_t x=1;x<19;++x)
        CHECK(shard->set_cell(y*20+x,wood(),Role::Structural,5)==Outcome::Accepted);
    activate(registry,handle);
    std::array<std::uint32_t,100> cells{};
    std::size_t count=0;
    for (int y=6;y<=12;++y) for (int x=6;x<=12;++x)
        if ((x-9)*(x-9)+(y-9)*(y-9)<=9) cells[count++]=static_cast<std::uint32_t>(y*20+x);
    const auto unique=count;
    cells[count++]=cells[0];cells[count++]=cells[2];
    const auto revision=shard->geometry().revision, material=shard->material_revision();
    const auto allocated=allocations.load();
    CHECK(registry.erase_structural_batch(handle,{cells.data(),count},6)==Outcome::Accepted);
    CHECK(allocations.load()==allocated);
    CHECK(shard->geometry().revision==revision+1);
    CHECK(shard->material_revision()==material+unique);
    CHECK(shard->counts().structural==324-unique);
    CHECK(shard->geometry().mass.mass==324-unique);
    exact_cover(*shard);
    double cx=0,cy=0,inertia=0;
    for (std::size_t at=0;at<shard->area();++at) if (shard->structural(at)) {
        cx+=at%20+0.5;cy+=at/20+0.5;
    }
    cx/=shard->counts().structural;cy/=shard->counts().structural;
    for (std::size_t at=0;at<shard->area();++at) if (shard->structural(at)) {
        const auto dx=at%20+0.5-cx,dy=at/20+0.5-cy;inertia+=dx*dx+dy*dy+1.0/6.0;
    }
    CHECK(shard->geometry().mass.com_x==cx && shard->geometry().mass.com_y==cy);
    CHECK(shard->geometry().mass.inertia==inertia);
    CHECK(shard->acknowledge_geometry(shard->geometry().revision,shard->geometry().mask_digest,shard->geometry().shape_digest)==Outcome::Accepted);
    const auto digest=shard->payload_digest(),before_noop=shard->geometry().revision;
    CHECK(registry.erase_structural_batch(handle,{},6)==Outcome::Accepted);
    CHECK(shard->payload_digest()==digest && shard->geometry().revision==before_noop);
    std::vector<std::uint32_t> oversized(kMaximumEditCells+1,21);
    CHECK(registry.erase_structural_batch(handle,oversized,6)==Outcome::Capacity);
    CHECK(shard->payload_digest()==digest && shard->geometry().revision==before_noop);
    const std::array<std::uint32_t,2> invalid{{21,401}};
    CHECK(registry.erase_structural_batch(handle,invalid,6)==Outcome::Unsupported);
    CHECK(shard->payload_digest()==digest && shard->geometry().revision==before_noop);
    std::vector<std::uint32_t> all;
    for (std::uint32_t at=0;at<shard->area();++at) if (shard->structural(at)) all.push_back(at);
    CHECK(registry.erase_structural_batch(handle,all,7)==Outcome::Accepted);
    CHECK(shard->phase()==Phase::Draining && shard->counts().total()==0);
    CHECK(shard->geometry().shapes.empty() && shard->geometry().mass.mass==0 && shard->geometry().islands==0);
    exact_cover(*shard);

    Limits tight;tight.max_shapes=1;
    Registry capacity(tight);Handle small;
    CHECK(capacity.prepare({0,0,7,7},0,small)==Outcome::Accepted);
    auto* body=capacity.find(small);
    for (std::uint32_t y=1;y<6;++y) for (std::uint32_t x=1;x<6;++x)
        CHECK(body->set_cell(y*7+x,wood(),Role::Structural,0)==Outcome::Accepted);
    activate(capacity,small);
    const auto original=body->payload_digest();const auto shape_revision=body->geometry().revision;
    const std::array<std::uint32_t,3> hole{{24,24,25}};
    CHECK(capacity.erase_structural_batch(small,hole,1)==Outcome::Capacity);
    CHECK(body->payload_digest()==original && body->geometry().revision==shape_revision);
    CHECK(body->phase()==Phase::Active && body->counts().structural==25);
}

void maximum_batch_and_single_cell_equivalence() {
    Limits limits;limits.max_area=4356;limits.max_total_area=4356;limits.max_shards=1;limits.max_shapes=512;
    Registry registry(limits);Handle handle;
    CHECK(registry.prepare({0,0,66,66},0,handle)==Outcome::Accepted);
    auto* shard=registry.find(handle);
    std::array<std::uint32_t,kMaximumEditCells> cells{};
    for (std::uint32_t y=1;y<=64;++y) for (std::uint32_t x=1;x<=64;++x) {
        const auto cell=y*66+x;cells[(y-1)*64+x-1]=cell;
        CHECK(shard->set_cell(cell,wood(),Role::Structural,0)==Outcome::Accepted);
    }
    activate(registry,handle);
    const auto before=shard->geometry().revision;
    CHECK(registry.erase_structural_batch(handle,cells,1)==Outcome::Accepted);
    CHECK(shard->counts().total()==0 && shard->geometry().revision==before+1);
    CHECK(shard->geometry().mass.mass==0 && shard->geometry().shapes.empty());

    Registry single,batch;Handle a,b;
    CHECK(single.prepare({3,7,5,5},0,a)==Outcome::Accepted);
    CHECK(batch.prepare({3,7,5,5},0,b)==Outcome::Accepted);
    for (std::uint32_t cell=6;cell<19;++cell) if (cell%5>0 && cell%5<4) {
        CHECK(single.find(a)->set_cell(cell,wood(),Role::Structural,0)==Outcome::Accepted);
        CHECK(batch.find(b)->set_cell(cell,wood(),Role::Structural,0)==Outcome::Accepted);
    }
    activate(single,a);activate(batch,b);
    const std::uint32_t cell=12;
    CHECK(single.erase_structural(a,cell,1)==Outcome::Accepted);
    CHECK(batch.erase_structural_batch(b,{&cell,1},1)==Outcome::Accepted);
    CHECK(single.find(a)->payload_digest()==batch.find(b)->payload_digest());
    CHECK(single.find(a)->geometry().mask_digest==batch.find(b)->geometry().mask_digest);
    CHECK(single.find(a)->geometry().shape_digest==batch.find(b)->geometry().shape_digest);
    CHECK(single.find(a)->geometry().revision==batch.find(b)->geometry().revision);
}
} // namespace

void* operator new(std::size_t size) {
    if (void* pointer = std::malloc(size == 0 ? 1 : size)) { ++allocations; return pointer; }
    throw std::bad_alloc();
}
void* operator new[](std::size_t size) { return ::operator new(size); }
void operator delete(void* pointer) noexcept { std::free(pointer); }
void operator delete[](void* pointer) noexcept { std::free(pointer); }
void operator delete(void* pointer, std::size_t) noexcept { std::free(pointer); }
void operator delete[](void* pointer, std::size_t) noexcept { std::free(pointer); }

int main() {
    batched_erase_is_atomic_bounded_and_rebuilds_once();
    maximum_batch_and_single_cell_equivalence();
    fragments_preserve_carriers_clocks_and_refuse_without_debit();
    payload_identity_and_activation();
    exact_geometry_holes_and_islands();
    products_cargo_and_draining();
    capacity_refusal_and_quarantine();
    explicit_capabilities_and_optional_temperature();
    destination_preflight_is_nonmutating_and_matches_commit();
    partial_commit_retains_exact_debited_inventory();
    three_owners_and_no_tick_allocations();
    std::printf("ObjectShard storage: %llu checks, %llu failures\n",
        static_cast<unsigned long long>(checks), static_cast<unsigned long long>(failures));
    return failures == 0 ? 0 : 1;
}
