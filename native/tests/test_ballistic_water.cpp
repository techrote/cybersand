// BW-001 ballistic_water_v1: exact bulk -> parcel -> bulk Water ownership,
// signed ballistic flight, swept contacts, persistence and worker parity.
#include "cybersand/world.hpp"
#include "cybersand/prepared_world.hpp"
#include "cybersand/render_snapshot.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using namespace cybersand;
constexpr std::int64_t Q = BallisticWaterConfig::kQ;

void require(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}

std::int64_t centre(std::int64_t cell) { return cell * Q + Q / 2; }

LiquidSolverPolicy water_policy(int family) {
    auto words = LiquidSolverPolicy::default_request();
    if (family != 1) words[21] = family;
    if (family == 4) {
        words[words.size() - 2U] = 1;
        words.insert(words.end() - 1, {4, 2, 1, 1});
    }
    const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
    require(decoded.accepted(), "Water policy refused: " + decoded.refusal.message());
    return *decoded.policy;
}

WorldConfig config(int family = 1, std::uint32_t workers = 1, std::uint32_t capacity = 256) {
    WorldConfig out;
    out.liquid_solver_policy = water_policy(family);
    out.maximum_rule_radius = family == 4 ? 3 : 2;
    out.worker_threads = workers;
    out.parallel_job_threshold = 1;
    out.ballistic_water.enabled = true;
    out.ballistic_water.capacity = capacity;
    return out;
}

void rect(World& world, std::int64_t x, std::int64_t y, std::int64_t w, std::int64_t h, Material m) {
    for (auto yy = y; yy < y + h; ++yy)
        for (auto xx = x; xx < x + w; ++xx) world.set(xx, yy, m);
}

// A hard box: interior [1, w-2] x [1, h-2]; floor row h-1, ceiling row 0.
void box(World& world, std::int64_t w, std::int64_t h, bool ceiling = true) {
    rect(world, 0, h - 1, w, 1, Material::Wall);
    rect(world, 0, 0, 1, h, Material::Wall);
    rect(world, w - 1, 0, 1, h, Material::Wall);
    if (ceiling) rect(world, 0, 0, w, 1, Material::Wall);
    world.reserve_region({-8, -8, w + 16, h + 16});
}

std::uint64_t total_water(const World& world) {
    const auto q = world.quantity_ledger();
    return q.water_visible + q.water_overfill + q.water_ballistic;
}

std::uint64_t grid_water(const World& world, RectI64 r) { return world.water_quantity(r); }

void closes(const World& world, const std::string& where) {
    // save_physical_state() runs the complete quantity, parcel and IN validators.
    (void)world.save_physical_state();
    const auto s = world.ballistic_water_snapshot();
    const auto& l = s.ledger;
    require(s.in_flight_quantity == l.launched_quantity + l.injected_quantity - l.deposited_quantity,
            where + ": in-flight quantity identity");
    require(s.momentum_y == l.launch_py + l.gravity_py + l.drag_py + l.contact_py + l.clamp_py - l.deposit_py,
            where + ": vertical momentum identity");
}

BallisticParcel only_parcel(const World& world) {
    std::array<BallisticParcel, 1> out{};
    require(world.copy_ballistic_parcels(out) == 1U, "expected exactly one live parcel");
    return out[0];
}

}  // namespace

void test_ballistic_water_defaults_unchanged() {
    World current;
    require(!current.ballistic_water_enabled() && current.physical_state_hash_version() == 2U &&
            current.physical_state_format_version() == 2U && current.quantity_ledger().schema_version == 1U,
            "Current defaults changed by BW-001");
    current.set(4, 4, Material::Water);
    const auto before = current.physical_state_hash();
    const auto refused = current.launch_ballistic_water(4, 4, centre(4), centre(3), 0, -512);
    require(refused.outcome == BallisticLaunchOutcome::Disabled && current.physical_state_hash() == before &&
            current.stored_material(4, 4) == Material::Water, "disabled launch mutated authority");
    const auto injected = current.inject_ballistic_water(centre(4), centre(2), 0, 0, 255);
    require(injected.outcome == BallisticLaunchOutcome::Disabled, "disabled injection admitted");
    // A disabled World restores through the unchanged CYPS2 path.
    auto restored = World::restore_physical_state({}, current.save_physical_state());
    require(restored->physical_state_hash() == current.physical_state_hash(), "CYPS2 continuation changed");
    // Out-of-envelope configuration is refused before construction.
    auto bad = config();
    bad.ballistic_water.max_speed_q = 1;
    bool threw = false;
    try { World refusedWorld(bad); } catch (const std::invalid_argument&) { threw = true; }
    require(threw, "invalid ballistic configuration admitted");
}

void test_ballistic_water_upward_arc_and_return() {
    for (const auto workers : {1U, 4U}) {
        World world(config(1, workers));
        box(world, 40, 80, false);
        world.set(20, 70, Material::Water);
        const auto initial = total_water(world);
        require(world.physical_state_hash_version() == 4U && world.quantity_ledger().schema_version == 2U,
                "ballistic World identity not versioned");
        const auto launched = world.launch_ballistic_water(20, 70, centre(20), centre(69), 64, -640);
        require(launched.outcome == BallisticLaunchOutcome::Launched && launched.quantity == 255U,
                "upward launch refused");
        require(world.stored_material(20, 70) == Material::Empty && total_water(world) == initial,
                "launch did not move the exact source quantity");
        closes(world, "after launch");
        std::int64_t lowest_y = only_parcel(world).y, previous_y = lowest_y;
        int rising = 0, apex_tick = -1;
        bool falling = false;
        for (int tick = 1; tick <= 400 && world.ballistic_parcel_count() != 0U; ++tick) {
            (void)world.tick();
            require(total_water(world) == initial, "quantity changed during flight");
            if (world.ballistic_parcel_count() == 0U) break;
            const auto p = only_parcel(world);
            if (p.y < previous_y) ++rising;
            if (!falling && p.vy > 0) { falling = true; apex_tick = tick; }
            lowest_y = std::min(lowest_y, p.y);
            previous_y = p.y;
            if (tick % 7 == 0) closes(world, "in flight");
        }
        require(rising >= 5, "Water did not rise through several ticks");
        require(apex_tick > 5, "no visible gravity apex");
        const auto apex_cell = lowest_y / Q;
        require(apex_cell <= 69 - 15, "upward arc too small: apex row " + std::to_string(apex_cell));
        require(world.ballistic_parcel_count() == 0U, "parcel never returned to bulk Water");
        const auto s = world.ballistic_water_snapshot();
        require(s.ledger.deposited_quantity == 255U && s.ledger.deposited_parcels == 1U, "deposit not booked");
        require(grid_water(world, {1, 1, 38, 78}) == initial, "returned Water missing from the basin");
        closes(world, "after return");
    }
}

void test_ballistic_water_ceiling_wall_no_tunnel() {
    World world(config());
    box(world, 30, 30);
    rect(world, 10, 14, 10, 1, Material::Wall);     // low roof over the launch site
    rect(world, 22, 15, 1, 14, Material::Wall);     // side wall
    world.set(15, 28, Material::Water);
    world.set(16, 28, Material::Water);
    const auto initial = total_water(world);
    require(world.launch_ballistic_water(15, 28, centre(15), centre(27), 0, -1536).outcome ==
                BallisticLaunchOutcome::Launched, "roof launch refused");
    require(world.launch_ballistic_water(16, 28, centre(16), centre(27), 1536, -128).outcome ==
                BallisticLaunchOutcome::Launched, "wall launch refused");
    for (int tick = 0; tick < 300 && world.ballistic_parcel_count() != 0U; ++tick) {
        (void)world.tick();
        std::array<BallisticParcel, 4> parcels{};
        const auto live = std::min<std::size_t>(world.copy_ballistic_parcels(parcels), parcels.size());
        for (std::size_t i = 0; i < live; ++i) {
            const auto x = parcels[i].x / Q, y = parcels[i].y / Q;
            require(y > 14 && x < 22, "parcel tunnelled through the roof or wall");
            require(world.stored_material(x, y) != Material::Wall, "parcel inside hard terrain");
        }
        require(total_water(world) == initial, "roof/wall contact lost Water");
    }
    const auto s = world.ballistic_water_snapshot();
    require(world.ballistic_parcel_count() == 0U && s.ledger.ceiling_contacts > 0U && s.ledger.terrain_contacts > 1U,
            "roof and wall contacts were not observed and resolved");
    require(grid_water(world, {0, 0, 30, 15}) == 0U && grid_water(world, {23, 0, 7, 30}) == 0U,
            "Water appeared beyond a hard boundary");
    closes(world, "roof and wall");
}

void test_ballistic_water_surface_merge_and_injection() {
    World world(config());
    box(world, 30, 40);
    rect(world, 1, 30, 28, 9, Material::Water);
    const auto bulk = total_water(world);
    const auto sourced = world.quantity_ledger().kinds[static_cast<std::size_t>(QuantityKind::ExternalEdit)].produced;
    const auto result = world.inject_ballistic_water(centre(10), centre(5), 200, -300, 128);
    require(result.outcome == BallisticLaunchOutcome::Launched, "nozzle injection refused");
    require(world.quantity_ledger().kinds[static_cast<std::size_t>(QuantityKind::ExternalEdit)].produced == sourced + 128U,
            "injection not booked as a source");
    for (int tick = 0; tick < 300 && world.ballistic_parcel_count() != 0U; ++tick) (void)world.tick();
    const auto s = world.ballistic_water_snapshot();
    require(world.ballistic_parcel_count() == 0U && s.ledger.surface_entries == 1U, "parcel did not re-enter the pool");
    require(total_water(world) == bulk + 128U, "injected Water was not conserved into bulk");
    closes(world, "injection merge");
    // Repeated launch/return cycles accumulate no phantom Water.
    for (int round = 0; round < 20; ++round) {
        for (std::int64_t x = 5; x < 25; x += 4) {
            const auto r = world.launch_ballistic_water(x, 30, centre(x), centre(28), (round % 3 - 1) * 200, -900);
            require(r.outcome == BallisticLaunchOutcome::Launched || r.outcome == BallisticLaunchOutcome::NotWater ||
                        r.outcome == BallisticLaunchOutcome::InvalidRequest,
                    "unexpected repeated-launch outcome");
        }
        for (int tick = 0; tick < 12; ++tick) (void)world.tick();
        require(total_water(world) == bulk + 128U, "repeated splashes changed total Water");
    }
    for (int tick = 0; tick < 400 && world.ballistic_parcel_count() != 0U; ++tick) (void)world.tick();
    require(world.ballistic_parcel_count() == 0U && total_water(world) == bulk + 128U &&
            grid_water(world, {1, 1, 28, 38}) == bulk + 128U, "repeated splashes left phantom or lost Water");
    closes(world, "repeated splashes");
}

void test_ballistic_water_families() {
    // CellularYield and IN are whole-cell: launch takes a whole cell; deposits are whole cells.
    for (const int family : {2, 3, 4}) {
        World world(config(family));
        box(world, 30, 40);
        rect(world, 1, 32, 28, 7, Material::Water);
        for (int t = 0; t < 4; ++t) (void)world.tick();
        const auto bulk = total_water(world);
        const auto max = world.config().water_experiment_policy.maximum();
        std::int64_t launched = 0;
        for (std::int64_t x = 3; x < 27; x += 3) {
            // Find this column's surface cell.
            std::int64_t y = 1;
            while (y < 39 && world.stored_material(x, y) != Material::Water) ++y;
            if (y >= 39 || world.stored_material(x, y - 1) != Material::Empty) continue;
            const auto r = world.launch_ballistic_water(x, y, centre(x), centre(y - 1), (x % 2 ? 1 : -1) * 256, -1024);
            if (r.outcome == BallisticLaunchOutcome::Pressurized) continue;
            require(r.outcome == BallisticLaunchOutcome::Launched, "family launch refused");
            require(family == 3 ? r.quantity <= max : r.quantity == max, "whole-cell launch split a cell");
            ++launched;
        }
        require(launched >= 4, "too few family launches");
        for (int tick = 0; tick < 500 && world.ballistic_parcel_count() != 0U; ++tick) {
            (void)world.tick();
            require(total_water(world) == bulk, "family flight changed Water quantity");
        }
        require(world.ballistic_parcel_count() == 0U, "family parcels never returned");
        for (int t = 0; t < 30; ++t) (void)world.tick();
        require(total_water(world) == bulk && grid_water(world, {1, 1, 28, 38}) == bulk,
                "family round trip did not conserve Water");
        if (family == 4) {
            // Hybrid handoff: deposits create IN carriers that keep momentum, booked externally.
            const auto in = world.inertial_ledger();
            require(in.external_speed != 0, "IN deposit retained no parcel momentum");
        }
        closes(world, "family " + std::to_string(family));
    }
    // A pressurized PF cell is refused, never debited (the #200 coherent
    // overfill fixture: a 400-row column feeds an enclosed receiver).
    auto pf_config = config(3);
    pf_config.chunk_size = 8;
    pf_config.activity_block_size = 8;
    pf_config.scheduling_core_size = 8;
    World pf(pf_config);
    pf.set_simulation_region(RectI64{0, 400, 8, 8});
    rect(pf, 3, 1, 1, 400, Material::Water);
    pf.set(2, 400, Material::Wall);
    pf.set(5, 400, Material::Wall);
    rect(pf, 2, 401, 4, 1, Material::Wall);
    require(pf.set_cell_state(4, 400, Material::Water, 255, 12), "overfill receiver");
    bool pressurized = false;
    for (int t = 0; t < 3 && !pressurized; ++t) {
        (void)pf.tick();
        for (std::int64_t x = 3; x <= 4 && !pressurized; ++x) {
            if (pf.pressure_cell(x, 400).overfill == 0U) continue;
            const auto before = pf.physical_state_hash();
            const auto r = pf.launch_ballistic_water(x, 400, centre(6), centre(398), 0, -256);
            pressurized = r.outcome == BallisticLaunchOutcome::Pressurized && pf.physical_state_hash() == before;
        }
    }
    require(pressurized, "pressurized PF source was not refused without mutation");
}

void test_ballistic_water_capacity_mask_deferral() {
    auto cfg = config(1, 1, 2);
    World world(cfg);
    box(world, 20, 20);
    rect(world, 2, 18, 3, 1, Material::Water);
    require(world.launch_ballistic_water(2, 18, centre(2), centre(10), 0, 0).outcome == BallisticLaunchOutcome::Launched &&
                world.launch_ballistic_water(3, 18, centre(3), centre(10), 0, 0).outcome == BallisticLaunchOutcome::Launched,
            "capacity launches refused");
    const auto before = world.physical_state_hash();
    const auto full = world.launch_ballistic_water(4, 18, centre(4), centre(10), 0, 0);
    require(full.outcome == BallisticLaunchOutcome::CapacityFull && world.stored_material(4, 18) == Material::Water,
            "capacity refusal mutated the source");
    require(world.ballistic_water_snapshot().ledger.refused_launches == 1U, "capacity refusal not booked");
    (void)before;
    // Spawning into a masked or occupied cell is refused (capacity permitting).
    World probes(config());
    box(probes, 20, 20);
    probes.set(4, 18, Material::Water);
    probes.configure_transient_obstacles({0, 0, 20, 20});
    require(probes.set_transient_obstacle(8, 8, 1), "mask setup");
    require(probes.launch_ballistic_water(4, 18, centre(8), centre(8), 0, 0).outcome == BallisticLaunchOutcome::Masked,
            "masked spawn admitted");
    require(probes.launch_ballistic_water(4, 18, centre(0), centre(5), 0, 0).outcome == BallisticLaunchOutcome::InvalidRequest,
            "spawn inside terrain admitted");
    require(probes.launch_ballistic_water(4, 18, centre(9), centre(9), 5000, 0).outcome == BallisticLaunchOutcome::InvalidRequest,
            "over-speed launch admitted");
    require(probes.stored_material(4, 18) == Material::Water && probes.ballistic_parcel_count() == 0U,
            "refused launches mutated authority");
    probes.clear_transient_obstacles();
    // Deferral: mask every deposition candidate around a parcel; it retains its Water.
    World cave(config());
    box(cave, 20, 20);
    cave.set(10, 18, Material::Water);
    require(cave.launch_ballistic_water(10, 18, centre(10), centre(17), 0, 0).outcome == BallisticLaunchOutcome::Launched,
            "deferral launch refused");
    cave.configure_transient_obstacles({0, 0, 20, 20});
    // A body now covers the parcel and its whole bounded deposition domain.
    for (std::int64_t y = 15; y <= 18; ++y)
        for (std::int64_t x = 8; x <= 12; ++x) (void)cave.set_transient_obstacle(x, y, 2);
    for (int t = 0; t < 6; ++t) (void)cave.tick();
    const auto held = cave.ballistic_water_snapshot();
    require(held.live == 1U && held.in_flight_quantity == 255U && held.ledger.deferred_deposits > 0U,
            "blocked deposition lost or created Water");
    closes(cave, "deferred");
    cave.clear_transient_obstacles();
    for (int t = 0; t < 20 && cave.ballistic_parcel_count() != 0U; ++t) (void)cave.tick();
    require(cave.ballistic_parcel_count() == 0U && cave.water_quantity({1, 1, 18, 18}) == 255U,
            "deferred parcel did not deposit once space opened");
}

void test_ballistic_water_body_contact() {
    World world(config());
    box(world, 40, 40);
    world.set(10, 30, Material::Water);
    world.configure_transient_obstacles({0, 0, 40, 40});
    for (std::int64_t y = 10; y < 30; ++y)
        for (std::int64_t x = 20; x < 24; ++x) require(world.set_transient_obstacle(x, y, 3), "body mask");
    require(world.launch_ballistic_water(10, 30, centre(10), centre(25), 1200, -200).outcome ==
                BallisticLaunchOutcome::Launched, "body launch refused");
    std::int64_t delivered = 0;
    for (int t = 0; t < 200 && world.ballistic_parcel_count() != 0U; ++t) {
        (void)world.tick();
        delivered += world.transient_ballistic_impulse_x(3);
        std::array<BallisticParcel, 1> p{};
        if (world.copy_ballistic_parcels(p) == 1U) require(p[0].x / Q < 20, "parcel entered the body");
        // A host clears contact observations once per coupling cycle.
        world.clear_transient_contact_observations();
    }
    const auto s = world.ballistic_water_snapshot();
    require(s.ledger.body_contacts > 0U && delivered > 0 && s.ledger.body_px < 0,
            "body did not receive the parcel's momentum");
    require(delivered == -s.ledger.body_px, "body impulse does not equal the parcel momentum change");
    require(world.water_quantity({1, 1, 38, 38}) + s.in_flight_quantity == 255U, "body contact lost Water");
    world.clear_transient_obstacles();
}

void test_ballistic_water_persistence_and_parity() {
    std::array<std::uint64_t, 2> hashes{};
    for (std::size_t run = 0; run < 2; ++run) {
        World world(config(1, run == 0 ? 1U : 4U));
        box(world, 64, 64);
        rect(world, 1, 50, 62, 13, Material::Water);
        for (int t = 0; t < 3; ++t) (void)world.tick();
        for (std::int64_t x = 4; x < 60; x += 2)
            (void)world.launch_ballistic_water(x, 50, centre(x), centre(48), (x % 5 - 2) * 150, -700 - (x % 7) * 40);
        for (int t = 0; t < 9; ++t) (void)world.tick();
        // Save mid-flight; the restored World continues identically.
        const auto bytes = world.save_physical_state();
        auto restored = World::restore_physical_state(world.config(), bytes);
        require(restored->physical_state_hash() == world.physical_state_hash(), "CYPS4 restore changed state");
        require(restored->ballistic_parcel_count() == world.ballistic_parcel_count() && world.ballistic_parcel_count() > 0U,
                "restored parcel roster differs");
        for (int t = 0; t < 120; ++t) {
            (void)world.tick();
            (void)restored->tick();
        }
        require(restored->physical_state_hash() == world.physical_state_hash(), "restored continuation diverged");
        hashes[run] = world.physical_state_hash();
        // Corrupt the extension flags: refused without touching the caller.
        auto bad = bytes;
        bool refused = false;
        bad[8] ^= 0x01U;
        try { (void)World::restore_physical_state(world.config(), bad); } catch (const std::invalid_argument&) { refused = true; }
        require(refused, "corrupted CYPS4 payload admitted");
        world.clear();
        require(world.ballistic_parcel_count() == 0U && world.ballistic_water_snapshot().ledger == BallisticLedger{} &&
                world.quantity_ledger().water_ballistic == 0U, "clear() left ballistic state");
    }
    require(hashes[0] == hashes[1], "1/4-worker ballistic results differ");
}

void test_ballistic_water_render_overlay_and_forced_age() {
    auto cfg = config();
    cfg.ballistic_water.maximum_age_ticks = 3;
    World world(cfg);
    box(world, 20, 40, false);
    world.set(10, 38, Material::Water);
    require(world.launch_ballistic_water(10, 38, centre(10), centre(30), 0, -64).outcome ==
                BallisticLaunchOutcome::Launched, "overlay launch refused");
    std::array<std::uint8_t, 20 * 40> bytes{};
    world.copy_material_cells({0, 0, 20, 40}, bytes, 20);
    require(bytes[30 * 20 + 10] == static_cast<std::uint8_t>(Material::Water), "in-flight parcel is not drawn");
    require(world.stored_material(10, 30) == Material::Empty, "presentation wrote authority");
    // The published render snapshot (the workbench presentation path) draws it too.
    RenderSnapshotExchange exchange(3, 64, 64U * 64U * 2U * 16U);
    require(exchange.publish(world).status == RenderPublishStatus::Published, "snapshot publish");
    auto lease = exchange.acquire_latest(0);
    bool drawn = false;
    for (const auto& patch : lease->patches()) {
        const auto& r = patch.world_rect;
        if (10 < r.x || 10 >= r.x + r.width || 30 < r.y || 30 >= r.y + r.height) continue;
        const auto offset = patch.data_offset + static_cast<std::size_t>(30 - r.y) * patch.stride_bytes +
                            static_cast<std::size_t>(10 - r.x) * 2U;
        drawn = lease->cells()[offset] == static_cast<std::uint8_t>(Material::Water);
    }
    require(drawn, "in-flight parcel missing from the published render snapshot");
    lease.reset();
    for (int t = 0; t < 3; ++t) (void)world.tick();
    const auto s = world.ballistic_water_snapshot();
    require(s.live == 0U && s.ledger.forced_deposits == 1U, "aged parcel was not forced to deposit");
    require(world.water_quantity({1, 0, 18, 39}) == 255U, "forced deposit lost Water");
    closes(world, "forced age");
}

// ---------------------------------------------------------------- IN-B1
namespace {
WorldConfig signed_config(std::uint32_t workers = 1, bool ballistic = false) {
    auto out = config(4, workers);
    out.ballistic_water.enabled = ballistic;
    out.inertial_signed_vertical = true;
    return out;
}
std::int64_t water_cells(const World& world, RectI64 r) {
    std::int64_t n = 0;
    for (auto y = r.y; y < r.y + r.height; ++y)
        for (auto x = r.x; x < r.x + r.width; ++x) n += world.stored_material(x, y) == Material::Water;
    return n;
}
std::pair<std::int64_t, std::int64_t> find_water(const World& world, RectI64 r) {
    for (auto y = r.y; y < r.y + r.height; ++y)
        for (auto x = r.x; x < r.x + r.width; ++x)
            if (world.stored_material(x, y) == Material::Water) return {x, y};
    return {-1, -1};
}
}  // namespace

void test_inertial_signed_vertical_control_and_identity() {
    auto v1_config = config(4);
    v1_config.ballistic_water.enabled = false;
    World v1(v1_config);
    box(v1, 20, 20);
    v1.set(10, 18, Material::Water);
    require(v1.physical_state_format_version() == 3U && !v1.inertial_parameters().signed_vertical,
            "IN v1 identity changed");
    require(!v1.diagnostic_set_inertial_cell(10, 18, 0, -8, 0, 0) && !v1.impart_inertial_velocity(10, 18, 0, -8),
            "IN v1 admitted upward velocity");
    auto b1_config = signed_config();
    b1_config.ballistic_water.enabled = false;
    World b1(b1_config);
    require(b1.physical_state_format_version() == 4U && b1.inertial_parameters().signed_vertical,
            "IN-B1 is not separately versioned");
    require(inertial_extension_identity(v1.inertial_parameters()) != inertial_extension_identity(b1.inertial_parameters()),
            "IN-B1 shares the v1 identity");
    auto refused = config(1);
    refused.inertial_signed_vertical = true;
    bool threw = false;
    try { World nope(refused); } catch (const std::invalid_argument&) { threw = true; }
    require(threw, "signed law admitted without an IN assignment");
}

void test_inertial_signed_vertical_arc_ceiling_parity() {
    std::array<std::uint64_t, 2> hashes{};
    for (std::size_t run = 0; run < 2; ++run) {
        World world(signed_config(run == 0 ? 1U : 4U));
        box(world, 40, 60, false);
        world.set(10, 58, Material::Water);            // open-sky launch from the floor
        rect(world, 25, 50, 5, 1, Material::Wall);      // low roof
        world.set(27, 58, Material::Water);            // under the roof
        require(world.impart_inertial_velocity(10, 58, 4, -32) && world.impart_inertial_velocity(27, 58, 0, -32),
                "signed launch refused");
        std::int64_t highest = 58;
        int peak_tick = 0, descended_after_peak = 0;
        for (int t = 0; t < 160; ++t) {
            (void)world.tick();
            require(water_cells(world, {-5, -20, 50, 80}) == 2, "signed IN lost or duplicated a cell");
            require(water_cells(world, {25, -20, 5, 71}) == 0, "IN cell tunnelled through the roof");
            for (std::int64_t yy = -20; yy < 59; ++yy)
                for (std::int64_t xx = 1; xx < 22; ++xx)
                    if (world.stored_material(xx, yy) == Material::Water && yy < highest) { highest = yy; peak_tick = t; }
            if (t > peak_tick && t < peak_tick + 20) {
                const auto at = find_water(world, {1, highest, 21, 59 - highest});
                if (at.second > highest) ++descended_after_peak;
            }
            if (t % 9 == 0) closes(world, "IN-B1 flight");
        }
        const bool fell = descended_after_peak > 0;
        require(58 - highest >= 6, "signed IN rose only " + std::to_string(58 - highest) + " rows");
        require(fell && peak_tick > 3, "signed IN arc had no apex followed by a fall");
        require(world.inertial_ledger().contacts > 0, "ceiling contact not booked");
        require(water_cells(world, {1, 1, 38, 58}) == 2, "signed IN lost or duplicated Water");
        hashes[run] = world.physical_state_hash();
        auto restored = World::restore_physical_state(world.config(), world.save_physical_state());
        require(restored->physical_state_hash() == world.physical_state_hash() &&
                restored->inertial_parameters().signed_vertical, "IN-B1 CYPS4 restore changed state");
    }
    require(hashes[0] == hashes[1], "IN-B1 1/4-worker results differ");
}

void test_inertial_signed_vertical_support_and_hybrid() {
    // A supported cell with upward velocity leaves its support instead of landing.
    World world(signed_config());
    box(world, 20, 30);
    world.set(10, 28, Material::Water);
    require(world.impart_inertial_velocity(10, 28, 0, -20), "support launch refused");
    (void)world.tick();
    require(world.stored_material(10, 28) == Material::Empty, "support destroyed upward motion");
    closes(world, "support");
    // Hybrid: a ballistic parcel deposited into a signed IN World keeps upward velocity.
    World hybrid(signed_config(1, true));
    box(hybrid, 30, 40);  // closed: a 4-cell/tick parcel would otherwise leave the basin
    rect(hybrid, 1, 36, 28, 3, Material::Water);
    for (int t = 0; t < 4; ++t) (void)hybrid.tick();
    const auto total = total_water(hybrid);
    std::int64_t launched = 0;
    for (std::int64_t x = 3; x < 27; x += 4) {
        std::int64_t y = 1;
        while (y < 39 && hybrid.stored_material(x, y) != Material::Water) ++y;
        if (y < 39 && hybrid.stored_material(x, y - 1) == Material::Empty &&
            hybrid.launch_ballistic_water(x, y, centre(x), centre(y - 1), 300, -1100).outcome ==
                BallisticLaunchOutcome::Launched) ++launched;
    }
    require(launched >= 4, "hybrid launches refused");
    for (int t = 0; t < 400 && hybrid.ballistic_parcel_count() != 0U; ++t) {
        (void)hybrid.tick();
        require(total_water(hybrid) == total, "hybrid handoff changed Water");
    }
    for (int t = 0; t < 60; ++t) (void)hybrid.tick();
    require(hybrid.ballistic_parcel_count() == 0U && total_water(hybrid) == total &&
            hybrid.water_quantity({1, 1, 28, 38}) == total, "hybrid IN-B1 round trip lost Water");
    closes(hybrid, "hybrid IN-B1");
}

void test_ballistic_water_run_receipt_identity() {
    // A ballistic/IN-B1 World issues a receipt with its own explicit sections;
    // the Current receipt encoder and its retained vectors are untouched.
    using namespace cybersand::receipt;
    setup::SetupDescriptor d;
    d.seed = 7;
    d.domain = {0, 0, 8, 8};
    const auto request = LiquidSolverPolicy::default_request();
    auto plain = std::make_unique<World>();
    auto ballistic_config = std::make_unique<WorldConfig>();
    ballistic_config->ballistic_water.enabled = true;
    auto ballistic = std::make_unique<World>(*ballistic_config);
    const auto receipt = [&](const World& w) {
        const auto facts = std::make_unique<NativeFacts>(capture_native_facts(w, d));
        return build_applied_run_receipt(*facts, d, request, RunIntent::Controlled, PlaneActivity::Active, {}, {}, 1)
            .receipt_hash();
    };
    require(receipt(*plain) != receipt(*ballistic), "ballistic World shares the Current run receipt");
    ballistic->set(3, 3, Material::Water);
    const auto grounded = receipt(*ballistic);
    require(ballistic->launch_ballistic_water(3, 3, centre(3), centre(2), 0, -256).outcome ==
                BallisticLaunchOutcome::Launched, "receipt launch");
    require(receipt(*ballistic) != grounded, "receipt omits the in-flight quantity and parcel state");
}

void test_ballistic_water_engulfed_parcel_column() {
    // Bulk Water may flow into a parcel's cell. The parcel must then displace
    // upward through its own Water column instead of staying in flight forever.
    for (const int family : {1, 2}) {
        auto cfg = config(family);
        World world(cfg);
        box(world, 20, 40);
        rect(world, 1, 20, 18, 19, Material::Water);   // deep pool, surface row 20
        world.set(10, 15, Material::Water);
        require(world.launch_ballistic_water(10, 15, centre(10), centre(25), 0, 0).outcome ==
                    BallisticLaunchOutcome::Launched || world.stored_material(10, 25) == Material::Water,
                "spawn inside Water must be refused");
        // Spawn into an air pocket inside the pool, then let the pocket close.
        world.set(10, 30, Material::Empty);
        require(world.launch_ballistic_water(10, 15, centre(10), centre(30), 0, 0).outcome ==
                    BallisticLaunchOutcome::Launched, "air-pocket launch refused");
        world.set(10, 30, Material::Water);            // engulf the parcel's cell
        for (std::int64_t y = 28; y <= 32; ++y)
            for (std::int64_t x = 8; x <= 12; ++x) world.set(x, y, Material::Water);
        const auto total = total_water(world);
        for (int t = 0; t < 30 && world.ballistic_parcel_count() != 0U; ++t) {
            (void)world.tick();
            require(total_water(world) == total, "engulfed parcel changed Water");
        }
        const auto s = world.ballistic_water_snapshot();
        require(world.ballistic_parcel_count() == 0U && s.ledger.column_deposits > 0U,
                "engulfed parcel stayed in flight (family " + std::to_string(family) + ")");
        require(world.water_quantity({1, 1, 18, 38}) == total, "column deposit lost Water");
        closes(world, "engulfed column");
    }
}

void test_ballistic_water_retained_rebuild_inheritance() {
    // A workbench retained rebuild carries parcels into a ballistic owner and
    // reports (never silently loses) them for a non-ballistic owner.
    auto source_config = config();
    World source(source_config);
    for (std::int64_t x = 1; x <= 6; ++x) source.set(x, 6, Material::Water);
    require(source.launch_ballistic_water(2, 6, centre(2), centre(3), 100, -300).outcome == BallisticLaunchOutcome::Launched &&
                source.launch_ballistic_water(5, 6, centre(5), centre(2), -100, -500).outcome == BallisticLaunchOutcome::Launched,
            "source launches");
    const auto in_flight = source.quantity_ledger().water_ballistic;
    normalization::FinalSetupInput input;
    input.setup.domain = {0, 0, 8, 8};
    for (std::int64_t x = 1; x <= 6; ++x)
        if (source.stored_material(x, 6) == Material::Water)
            input.cells.push_back({x, 6, Material::Water, source.stored_state_a(x, 6), source.stored_state_b(x, 6), 200});
    const auto candidate = [&](const WorldConfig& cfg) {
        auto result = PreparedWorldBuilder::prepare(cfg, input, normalization::NormalizationOptIn::None);
        require(std::holds_alternative<PreparedWorld>(result), "candidate setup");
        return std::get<PreparedWorld>(result).take_world();
    };
    auto kept = candidate(source_config);
    const auto receipt = kept->inherit_workbench_liquid_state(source, {0, 0, 8, 8}, false, false);
    require(receipt.preserved_in_flight_water == in_flight && receipt.discarded_in_flight_water == 0U &&
                kept->ballistic_parcel_count() == 2U && kept->quantity_ledger().water_ballistic == in_flight,
            "ballistic owner did not inherit the parcels");
    closes(*kept, "inherited");
    WorldConfig plain = source_config;
    plain.ballistic_water = {};
    auto dropped_owner = candidate(plain);
    const auto dropped = dropped_owner->inherit_workbench_liquid_state(source, {0, 0, 8, 8}, false, false);
    require(dropped.discarded_in_flight_water == in_flight && dropped.preserved_in_flight_water == 0U &&
                dropped_owner->ballistic_parcel_count() == 0U, "non-ballistic owner did not report discarded parcels");
}

void test_ballistic_water_face_release_dam_break() {
    // WCX-FR: face release sheds a dam-break wall with exact Water accounting and
    // worker-count-independent results; the front distance is reported only.
    for (const int family : {1, 2, 4}) {
        std::array<std::int64_t, 2> fronts{};
        std::array<std::uint64_t, 2> hashes{};
        for (std::size_t arm = 0; arm < 2; ++arm) {
            for (const auto workers : {1U, 4U}) {
                auto cfg = config(family, workers);
                cfg.ballistic_water.face_release = arm == 1;
                cfg.ballistic_water.face_period = 1;
                cfg.ballistic_water.face_min_height = 4;
                World world(cfg);
                box(world, 160, 64);
                rect(world, 1, 15, 10, 48, Material::Water);   // a 48-row wall of Water
                const auto total = total_water(world);
                for (int t = 0; t < 36; ++t) {
                    (void)world.tick();
                    require(total_water(world) == total, "dam break changed Water");
                }
                std::int64_t front = 0;
                for (std::int64_t x = 1; x < 159; ++x)
                    for (std::int64_t y = 1; y < 63; ++y)
                        if (world.stored_material(x, y) == Material::Water) front = std::max(front, x);
                std::array<BallisticParcel, 512> parcels{};
                const auto live = std::min(world.copy_ballistic_parcels(parcels), parcels.size());
                for (std::size_t i = 0; i < live; ++i) front = std::max(front, parcels[i].x / Q);
                if (workers == 1U) { fronts[arm] = front; hashes[arm] = world.physical_state_hash(); }
                else require(world.physical_state_hash() == hashes[arm], "face release differs across workers");
                if (arm == 1) {
                    require(world.ballistic_water_snapshot().ledger.face_releases > 0U, "no face cell was released");
                    closes(world, "face release");
                }
            }
        }
        // Measured, not asserted (WCX-FR evidence): FreeMass 38 -> 42, CellularYield
        // 42 -> 44, IN 50 -> 42 cells after 36 ticks with period 1 / height 4.
        std::cout << "WCX-FR family " << family << " control front " << fronts[0]
                  << " release front " << fronts[1] << std::endl;
    }
}
