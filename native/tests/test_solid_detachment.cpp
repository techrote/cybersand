#include "cybersand/world.hpp"
#include <atomic>
#include <cmath>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <new>
#include <stdexcept>
#include <string>
#include <vector>

// Allocation refusal is scoped ONLY after World and feature configuration.
static std::atomic<bool> forbid_allocation{false};
void* operator new(std::size_t n) {
    if (forbid_allocation.load()) throw std::bad_alloc();
    if (auto* p = std::malloc(n == 0 ? 1 : n)) return p;
    throw std::bad_alloc();
}
void* operator new[](std::size_t n) { return ::operator new(n); }
void operator delete(void* p) noexcept { std::free(p); }
void operator delete[](void* p) noexcept { std::free(p); }
void operator delete(void* p, std::size_t) noexcept { std::free(p); }
void operator delete[](void* p, std::size_t) noexcept { std::free(p); }

namespace cybersand {
// Existing narrow test friend; no production failure-injection flag is added.
class PrecisionProbe {
public:
    static void fail(World& world) { world.tick_failed_ = true; }
    static void terrain_revision(World& world, std::uint64_t n) { world.hard_surface_revision_ = n; }
};
}
using namespace cybersand;
using namespace cybersand::soliding;
static unsigned cases = 0, checks = 0;
void expect(bool condition, const char* message) {
    ++checks;
    if (!condition) throw std::runtime_error(message);
}
template<class F> void throws(F&& fn, const char* message) {
    bool caught = false;
    try { fn(); } catch (const std::logic_error&) { caught = true; }
    expect(caught, message);
}
WorldConfig config(std::uint32_t workers) {
    WorldConfig c;
    c.worker_threads = workers;
    c.parallel_job_threshold = 1;
    c.maximum_chunk_count = 64;
    c.active_chunk_capacity = 64;
    c.active_core_capacity = 512;
    c.sleep_after_quiet_ticks = 1;
    return c;
}
struct Fixture {
    World world;
    std::int64_t ox{}, oy{};
    explicit Fixture(std::uint32_t workers = 1, std::int64_t x = 0, std::int64_t y = 0)
        : world(config(workers)), ox(x), oy(y) {
        world.reserve_region({ox, oy, 128, 128});
        const auto fill = [&](int x0, int y0, int width, int height, Material m) {
            for (int yy = y0; yy < y0 + height; ++yy)
                for (int xx = x0; xx < x0 + width; ++xx) world.set(ox + xx, oy + yy, m);
        };
        fill(0, 72, 128, 4, Material::Wall);
        fill(50, 40, 4, 32, Material::RedBrick);
        fill(44, 27, 29, 13, Material::RedBrick);
        fill(54, 40, 11, 4, Material::RedBrick);
        fill(88, 45, 3, 27, Material::RedBrick); // Nearby tree must stay native.
        world.set(ox + 60, oy + 32, Material::Empty); // A real geometric hole.
    }
    SolidRequest request() const {
        return {{ox + 32, oy + 16, 64, 64}, {ox, oy + 67, 128, 13}, ox + 51, oy + 34};
    }
    void cut() {
        for (int y = 65; y <= 66; ++y)
            for (int x = 50; x <= 53; ++x) world.set(ox + x, oy + y, Material::Empty);
    }
    void enable(SolidLimits limits = {}) {
        expect(world.configure_solid_detachment(limits) == SolidOutcome::Accepted, "configure");
    }
    void prepare() {
        expect(world.prepare_solid_detachment(request()) == SolidOutcome::Accepted, "prepare actual tree cells");
    }
    SolidBodyReservation synthetic_reservation() const {
        const auto s = world.inspect_solid_detachment();
        return {s.token, 1, 91, s.payload_digest, s.shape_digest, s.shape_count};
    }
    void acknowledge() {
        expect(world.acknowledge_solid_detachment(synthetic_reservation()) == SolidOutcome::Accepted, "native receipt binding");
    }
    SolidCollisionReceipt synthetic_contact_receipt() const {
        const auto s = world.inspect_solid_detachment();
        return {s.token, s.body_id, s.body_generation, s.committed_terrain_revision, 73};
    }
    std::vector<SolidMember> members() const {
        const auto count = world.copy_solid_detachment_members({});
        std::vector<SolidMember> result(count);
        expect(world.copy_solid_detachment_members(result) == count, "copy member count");
        return result;
    }
};
void payload_equal(const World& world, const std::vector<SolidMember>& members) {
    for (const auto& m : members) {
        expect(world.stored_material(m.x, m.y) == m.material, "exact material");
        expect(world.stored_state_a(m.x, m.y) == m.state_a, "exact state a");
        expect(world.stored_state_b(m.x, m.y) == m.state_b, "exact state b");
        expect(world.stored_temperature(m.x, m.y) == m.temperature, "exact temperature");
    }
}
void default_off_and_intact_anchor() {
    Fixture f;
    expect(f.world.solid_detachment_storage_bytes() == 0, "default allocation neutrality");
    expect(f.world.prepare_solid_detachment(f.request()) == SolidOutcome::Disabled, "default disabled");
    const auto before = f.world.content_hash();
    f.enable();
    expect(f.world.prepare_solid_detachment(f.request()) == SolidOutcome::Anchored, "intact support not released");
    expect(f.world.content_hash() == before, "anchor refusal preserves exact source");
    f.world.set(51, 65, Material::Empty);
    expect(f.world.prepare_solid_detachment(f.request()) == SolidOutcome::Anchored, "partial trunk cut still anchored");
}
void actual_transfer_and_owner_fences() {
    Fixture f;
    f.enable(); f.cut();
    expect(f.world.set_cell_state(51, 34, Material::RedBrick, 23, 17), "author exact inert state");
    f.prepare();
    const auto original = f.members();
    const auto before = f.world.inspect_solid_detachment();
    expect(before.member_count > 300 && before.shape_count > 1, "irregular source, not prefab rectangle");
    expect(before.aggregate_owned_count == 0, "prepared copies do not own material");
    payload_equal(f.world, original);
    expect(f.world.solid_detachment_fenced(), "prepare fences mutation");
    const auto tick = f.world.tick_index();
    throws([&] { (void)f.world.tick(); }, "tick must refuse while prepared");
    expect(f.world.tick_index() == tick && !f.world.has_failed(), "refused tick has not started or poisoned World");
    throws([&] { f.world.set(51, 34, Material::Empty); }, "edit fenced");
    throws([&] { f.world.set_temperature(51, 34, 999); }, "heat fenced");
    throws([&] { f.world.set_simulation_region(RectI64{0, 0, 64, 64}); }, "inclusion fenced");
    expect(!f.world.set_cell_state(51, 34, Material::Wall, 0, 0), "direct state mutation fenced");
    expect(!f.world.queue_explosion(51, 34, 3), "queued event fenced");
    expect(!f.world.relocate_stored_cell(51, 34, 5, 5), "relocation fenced");
    expect(f.world.commit_solid_detachment(before.token) == SolidOutcome::Stale, "commit before ack refused");
    auto bad = f.synthetic_reservation(); ++bad.shape_digest;
    expect(f.world.acknowledge_solid_detachment(bad) == SolidOutcome::Invalid, "wrong geometry ack refused");
    f.acknowledge();
    expect(f.world.commit_solid_detachment(before.token) == SolidOutcome::Accepted, "actual native cell retirement");
    const auto committed = f.world.inspect_solid_detachment();
    expect(committed.aggregate_owned_count == original.size(), "exact single owner after commit");
    for (const auto& m : original)
        expect(f.world.stored_material(m.x, m.y) == Material::Empty, "source actually empty after transfer");
    expect(f.members() == original, "native aggregate retains exact original payload");
    expect(f.world.stored_material(51, 70) == Material::RedBrick, "stump untouched");
    expect(f.world.stored_material(89, 50) == Material::RedBrick, "other tree untouched");
    expect(f.world.stored_material(80, 73) == Material::Wall, "ground untouched");
    expect(f.world.solid_detachment_fenced(), "commit alone cannot resume native simulation");
    // Read/render access must remain available for post-commit terrain repair.
    std::array<std::uint8_t, 16 * 16> pixels{};
    f.world.copy_material_cells({44, 27, 16, 16}, pixels, 16);
    auto wrong = f.synthetic_contact_receipt(); --wrong.terrain_revision;
    expect(f.world.finalize_solid_detachment(wrong) == SolidOutcome::Stale, "old static geometry receipt refused");
    expect(f.world.finalize_solid_detachment(f.synthetic_contact_receipt()) == SolidOutcome::Accepted, "finalize exact owner epoch");
    expect(!f.world.solid_detachment_fenced(), "native releases only after contact receipt");
    expect(f.world.inspect_solid_detachment().phase == SolidPhase::Active, "aggregate active");
    throws([&] { (void)f.world.save_physical_state(); }, "no silent aggregate omission from save");
    throws([&] { (void)f.world.physical_state_hash(); }, "no false full physical-state hash");
    expect(f.world.rollback_solid_detachment(before.token) == SolidOutcome::Stale, "active body not rasterized blindly");
    (void)f.world.tick();
    expect(f.members() == original, "active inert payload retained across native tick");
}
void exact_geometry_and_mass() {
    Fixture f; f.enable(); f.cut(); f.prepare();
    const auto members = f.members();
    const auto snap = f.world.inspect_solid_detachment();
    std::vector<SolidShape> shapes(snap.shape_count);
    (void)f.world.copy_solid_detachment_shapes(shapes);
    std::size_t area = 0;
    for (const auto& shape : shapes) area += static_cast<std::size_t>(shape.width) * shape.height;
    expect(area == members.size(), "shape union exactly equals payload area");
    for (std::int64_t y = 16; y < 80; ++y) for (std::int64_t x = 32; x < 96; ++x) {
        unsigned coverage = 0;
        for (const auto& shape : shapes)
            coverage += x >= shape.x && x < shape.x + shape.width && y >= shape.y && y < shape.y + shape.height;
        bool member = false;
        for (const auto& m : members) member = member || (m.x == x && m.y == y);
        expect(coverage == (member ? 1U : 0U), "no hole filling, overlap, or false collider pixel");
    }
    expect(snap.mass == static_cast<double>(members.size()) && snap.inertia > 0, "positive unit mass/inertia");
    SolidMember untouched{999, 999, Material::Sand, 77, 19, 200};
    std::array<SolidMember, 1> short_output{untouched};
    expect(f.world.copy_solid_detachment_members(short_output) == members.size(), "short copy reports required size");
    expect(short_output[0] == untouched, "short copy never publishes a prefix");
    expect(f.world.cancel_solid_detachment(snap.token) == SolidOutcome::Accepted, "cancel prepared");
}
void cancellation_rollback_and_token_aba() {
    Fixture f; f.enable(); f.cut(); f.prepare();
    const auto first = f.world.inspect_solid_detachment();
    const auto old_reservation = f.synthetic_reservation();
    const auto original = f.members();
    f.acknowledge();
    expect(f.world.cancel_solid_detachment(first.token) == SolidOutcome::Accepted, "cancel acked without removal");
    payload_equal(f.world, original);
    f.world.set(51, 34, Material::Empty); f.world.set(51, 34, Material::RedBrick);
    f.prepare();
    expect(f.world.inspect_solid_detachment().token != first.token, "fresh sequence after source ABA");
    expect(f.world.acknowledge_solid_detachment(old_reservation) == SolidOutcome::Stale, "old source/body acknowledgement rejected");
    f.acknowledge();
    const auto token = f.world.inspect_solid_detachment().token;
    expect(f.world.commit_solid_detachment(token) == SolidOutcome::Accepted, "commit for rollback");
    expect(f.world.rollback_solid_detachment(token) == SolidOutcome::Accepted, "restore only inactive staged source");
    payload_equal(f.world, original);
    expect(f.world.inspect_solid_detachment().aggregate_owned_count == 0, "restored cells own payload");
    expect(f.world.solid_detachment_fenced(), "rollback cannot reopen simulation before static repair");
    expect(f.world.complete_solid_rollback(f.synthetic_contact_receipt()) == SolidOutcome::Accepted, "rollback static repair handshake");
    expect(!f.world.solid_detachment_fenced(), "rollback fully finished");
    f.prepare();
    const auto pre_reset = f.world.inspect_solid_detachment().token;
    f.world.clear();
    expect(f.world.inspect_solid_detachment().phase == SolidPhase::Disabled, "reset retires pending ownership");
    f.enable();
    expect(f.world.inspect_solid_detachment().token.incarnation != pre_reset.incarnation, "non-reused incarnation");
    expect(f.world.commit_solid_detachment(pre_reset) == SolidOutcome::Stale, "reset cannot revive old transfer");
}
void honest_refusals() {
    for (const auto limits : {SolidLimits{8, 128}, SolidLimits{1024, 1}}) {
        Fixture f; f.enable(limits); f.cut();
        const auto before = f.world.content_hash();
        const auto result = f.world.prepare_solid_detachment(f.request());
        expect(result == (limits.members == 8 ? SolidOutcome::MemberCapacity : SolidOutcome::ShapeCapacity), "bounded resource refusal");
        expect(f.world.content_hash() == before && !f.world.solid_detachment_fenced(), "refusal preserves native terrain");
    }
    Fixture f; f.enable(); f.cut();
    auto request = f.request(); request.domain.x = 48; request.domain.width = 24;
    expect(f.world.prepare_solid_detachment(request) == SolidOutcome::UnknownBoundary, "truncated structure not promoted");
    request = f.request(); request.domain.x = 120; request.seed_x = 130;
    expect(f.world.prepare_solid_detachment(request) == SolidOutcome::NotResident, "unseen space not air");
    f.world.set_temperature(51, 34, 201);
    expect(f.world.prepare_solid_detachment(f.request()) == SolidOutcome::Thermal, "hot material not silently frozen");
    f.world.set_temperature(51, 34, 200);
    f.world.set(51, 34, Material::Sand);
    expect(f.world.prepare_solid_detachment(f.request()) == SolidOutcome::Ineligible, "sand never gains cohesion");
    f.world.set(51, 34, Material::RedBrick);
    f.world.configure_transient_obstacles({0, 0, 128, 128});
    expect(f.world.set_transient_obstacle(51, 34, 1), "mask setup");
    expect(f.world.prepare_solid_detachment(f.request()) == SolidOutcome::Occupied, "masked source refused");
    f.world.clear_transient_obstacles();
    expect(f.world.queue_explosion(110, 15, 1), "event setup");
    expect(f.world.prepare_solid_detachment(f.request()) == SolidOutcome::PendingEvent, "pending event admission refused");
    Fixture excluded; excluded.enable(); excluded.cut();
    excluded.world.set_simulation_region(RectI64{0, 0, 32, 32});
    expect(excluded.world.prepare_solid_detachment(excluded.request()) == SolidOutcome::Excluded, "pending inclusion not rest");
    Fixture failed; failed.enable(); failed.cut();
    PrecisionProbe::fail(failed.world);
    expect(failed.world.prepare_solid_detachment(failed.request()) == SolidOutcome::WorldFailed, "failed World stays quarantined");
}
void no_heap_allocation_during_handoff() {
    Fixture f; f.enable(); f.cut();
    struct Guard { Guard() { forbid_allocation = true; } ~Guard() { forbid_allocation = false; } } guard;
    f.prepare(); f.acknowledge();
    const auto token = f.world.inspect_solid_detachment().token;
    expect(f.world.commit_solid_detachment(token) == SolidOutcome::Accepted, "commit allocation-free");
    expect(f.world.rollback_solid_detachment(token) == SolidOutcome::Accepted, "rollback allocation-free");
    expect(f.world.complete_solid_rollback(f.synthetic_contact_receipt()) == SolidOutcome::Accepted, "completion allocation-free");
}
void signed_seams_and_worker_configuration_parity() {
    for (const auto x : {std::int64_t{-48}, std::int64_t{64}}) {
        Fixture one(1, x, 96), four(4, x, 96);
        (void)one.world.tick(); (void)four.world.tick();
        one.enable(); four.enable(); one.cut(); four.cut(); one.prepare(); four.prepare();
        const auto a = one.world.inspect_solid_detachment(), b = four.world.inspect_solid_detachment();
        expect(a.member_count == b.member_count && a.payload_digest == b.payload_digest &&
            a.shape_digest == b.shape_digest && a.inertia == b.inertia, "signed seams/configured worker parity");
        expect(one.members() == four.members(), "exact payload parity not only hash");
        one.acknowledge(); four.acknowledge();
        expect(one.world.commit_solid_detachment(a.token) == SolidOutcome::Accepted, "one-worker seam transfer");
        expect(four.world.commit_solid_detachment(b.token) == SolidOutcome::Accepted, "four-worker seam transfer");
        expect(one.world.content_hash() == four.world.content_hash(), "exact source content parity after transfer");
    }
}
void generation_and_failed_world_safety() {
    Fixture f; f.enable(); f.cut(); f.prepare();
    const auto first = f.world.inspect_solid_detachment();
    const auto original = f.members();
    expect(f.world.cancel_solid_detachment(first.token) == SolidOutcome::Accepted, "cancel reference capture");
    const auto maximum = std::numeric_limits<std::uint64_t>::max();
    PrecisionProbe::terrain_revision(f.world, maximum - 2U * original.size() + 1U);
    expect(f.world.prepare_solid_detachment(f.request()) == SolidOutcome::GenerationExhausted,
        "admission reserves rollback revision headroom, not only commit");
    payload_equal(f.world, original);
    PrecisionProbe::terrain_revision(f.world, maximum - 2U * original.size());
    f.prepare(); f.acknowledge();
    const auto token = f.world.inspect_solid_detachment().token;
    expect(f.world.commit_solid_detachment(token) == SolidOutcome::Accepted, "last safe commit revision");
    expect(f.world.rollback_solid_detachment(token) == SolidOutcome::Accepted, "reserved rollback reaches maximum without wrapping");
    expect(f.world.hard_surface_revision() == maximum, "revision does not wrap");
    expect(f.world.complete_solid_rollback(f.synthetic_contact_receipt()) == SolidOutcome::Accepted, "finish exhausted revision rollback");
    expect(f.world.prepare_solid_detachment(f.request()) == SolidOutcome::GenerationExhausted, "exhausted world cannot start another transfer");
    Fixture failed; failed.enable(); failed.cut(); failed.prepare(); failed.acknowledge();
    expect(failed.world.commit_solid_detachment(failed.world.inspect_solid_detachment().token) == SolidOutcome::Accepted, "commit before external failure");
    const auto owned = failed.world.inspect_solid_detachment().aggregate_owned_count;
    PrecisionProbe::fail(failed.world);
    expect(failed.world.finalize_solid_detachment(failed.synthetic_contact_receipt()) == SolidOutcome::WorldFailed, "failed World cannot activate staged body");
    expect(failed.world.inspect_solid_detachment().aggregate_owned_count == owned, "failure retains aggregate-owned material");
}

int main() {
    try {
        const auto run = [](const char* name, auto test) { test(); ++cases; std::cout << "PASS " << name << '\n'; };
        run("default-off/intact/partial anchor", default_off_and_intact_anchor);
        run("real World transfer/fences/serialization refusal", actual_transfer_and_owner_fences);
        run("exact compound geometry/hole/mass", exact_geometry_and_mass);
        run("cancel/rollback/static-repair/token/reset ABA", cancellation_rollback_and_token_aba);
        run("capacity/unknown/heat/sand/mask/event/exclusion/failure", honest_refusals);
        run("allocation-free prepare/commit/rollback", no_heap_allocation_during_handoff);
        run("signed chunk seams/configured workers1/4 parity", signed_seams_and_worker_configuration_parity);
        run("revision exhaustion/rollback headroom/failed World", generation_and_failed_world_safety);
        std::cout << "SOL-DETACH-001 A1 native precursor: " << cases << " groups, " << checks << " checks passed.\n"
                  << "Actual native World exercised; bridge receipts are synthetic. Rapier motion and async host NOT qualified.\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "FAIL after " << cases << " groups: " << error.what() << '\n';
        return 1;
    }
}
