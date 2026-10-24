// LCB-005 (#212) inertial_cellular_v1/reference native regressions: admission,
// parity with the inertial-update-v1 contract oracle's worked examples in a real
// World, exact momentum/speed ledgers, static rest, no wall/mask tunnelling,
// Brine chemistry lifecycle, 1/4-worker parity, three families executing in one
// World (and the pressure-Water substitution) and exact persistence.
#include "cybersand/liquid_solver_policy.hpp"
#include "cybersand/world.hpp"

#include "cybersand/liquid_run_receipt_native_capture.hpp"
#include <array>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <memory>
#include <optional>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace {

using cybersand::InertialParameters;
using cybersand::LiquidPolicyRefusalCode;
using cybersand::LiquidSolverFamily;
using cybersand::LiquidSolverPolicy;
using cybersand::Material;
using cybersand::RectI64;
using cybersand::World;
using cybersand::WorldConfig;

void require(bool condition, const std::string &message) {
    if (!condition)
        throw std::runtime_error(message);
}

// Rows of the default request: Water is row 0, Oil row 3, Brine row 6.
constexpr std::size_t kFamilyWord(std::size_t row) { return 20U + row * 3U + 1U; }

LiquidSolverPolicy policy(bool water_pressure, bool brine_inertial) {
    auto words = LiquidSolverPolicy::default_request();
    if (water_pressure)
        words[kFamilyWord(0)] = 3;
    if (brine_inertial)
        words[kFamilyWord(6)] = 4;
    auto result = LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
    require(result.accepted(), "policy refused: " + result.refusal.message());
    return *result.policy;
}

WorldConfig config(std::uint32_t workers, bool water_pressure = false) {
    WorldConfig out;
    out.liquid_solver_policy = policy(water_pressure, true);
    out.worker_threads = workers;
    out.maximum_rule_radius = InertialParameters::kExecutionRadius;
    return out;
}

void rect(World &world, std::int64_t x, std::int64_t y, std::int64_t w, std::int64_t h, Material m) {
    for (auto yy = y; yy < y + h; ++yy)
        for (auto xx = x; xx < x + w; ++xx) {
            if (m == Material::Empty)
                (void)world.set_cell_state(xx, yy, Material::Empty, 0, 0);
            else
                world.set(xx, yy, m);
        }
}

cybersand::TickStats tick(World &world, int count = 1) {
    cybersand::TickStats last;
    for (int i = 0; i < count; ++i)
        last = world.tick();
    return last;
}

struct Totals {
    std::int64_t vx = 0;
    std::int64_t vy = 0;
    std::int64_t speed = 0;
    std::int64_t brine = 0;
};

Totals totals(const World &world, RectI64 r) {
    Totals out;
    for (auto y = r.y; y < r.y + r.height; ++y)
        for (auto x = r.x; x < r.x + r.width; ++x) {
            if (world.stored_material(x, y) == Material::Brine)
                ++out.brine;
            const auto s = world.inertial_cell(x, y);
            out.vx += s.vx;
            out.vy += s.vy;
            out.speed += std::abs(s.vx) + std::abs(s.vy);
        }
    return out;
}

// Contract worked examples (tools/lcb/inertial_contract.py, Params(vmax=32)).
// '#' Wall, 'W' the inertial cell (Brine), 'o' a lighter exchangeable powder
// (Dust), 'M' a transient body mask, '.' Empty; outside the rows is Wall.
struct Example {
    std::string_view name;
    std::array<std::string_view, 6> rows;
    int x, y, vx, vy, ax, ay;
    int end_x, end_y, end_vx, end_vy, end_ax, end_ay;
    bool sleep;
};
constexpr std::array<Example, 11> kExamples{{
    {"deflect-right", {"#####", "##W..", "#####"}, 2, 1, 0, 32, 0, 0, 3, 1, 23, 0, 7, 0, false},
    {"deflect-left", {"#####", "..W##", "#####"}, 2, 1, 0, 32, 0, 0, 1, 1, -23, 0, -7, 0, false},
    {"deflect-right-aligned-vx", {"#####", "##W..", "#####"}, 2, 1, 10, 32, 0, 0, 3, 1, 30, 0, 14, 0, false},
    {"deflect-right-opposing-vx",
     {"#####", "##W..", "#####"},
     2,
     1,
     -10,
     32,
     0,
     0,
     2,
     1,
     14,
     0,
     14,
     0,
     false},
    {"deflect-left-aligned-vx",
     {"#####", "..W##", "#####"},
     2,
     1,
     -10,
     32,
     0,
     0,
     1,
     1,
     -30,
     0,
     -14,
     0,
     false},
    {"supported-rest-free-side", {"#####", "#.W..", "#####"}, 2, 1, 0, 0, 0, 0, 2, 1, 0, 0, 0, 0, true},
    {"reaim-from-rest", {"#####", "#.W..", "###.."}, 2, 1, 0, 0, 0, 0, 2, 1, 2, 2, 2, 2, false},
    {"body-mask-landing", {"#####", "##W.M", "##M##"}, 2, 1, 0, 32, 0, 0, 3, 1, 23, 0, 7, 0, false},
    {"drag-density-swap",
     {".....", "..W..", "..o..", "..o..", "#####"},
     2,
     1,
     0,
     20,
     0,
     0,
     2,
     2,
     0,
     18,
     0,
     7,
     false},
    {"no-horizontal-swap", {"#####", "#Wo.#", "#####"}, 1, 1, 20, 0, 0, 0, 1, 1, 0, 0, 0, 0, true},
    {"no-deflection-into-lighter", {"#####", "#oW##", "#####"}, 2, 1, 0, 32, 0, 0, 2, 1, 0, 0, 0, 0, true},
}};

void test_inertial_admission() {
    const auto &running = cybersand::LiquidPolicyBuild::running();
    require(running.available_families == 0x0FU, "running build compiles four families");
    const auto applied = policy(false, true);
    require(applied.assignment(24)->family == LiquidSolverFamily::InertialCellularV1,
            "Brine inertial applied");
    const auto refused = [](std::size_t row, int family) {
        auto words = LiquidSolverPolicy::default_request();
        words[kFamilyWord(row)] = family;
        return LiquidSolverPolicy::decode(std::span<const std::int32_t>(words)).refusal.code;
    };
    require(refused(0, 4) == LiquidPolicyRefusalCode::FamilyUnavailable,
            "Water inertial needs whole-cell Water");
    require(refused(3, 4) == LiquidPolicyRefusalCode::CombinationRejected, "Oil inertial rejected (NC-1)");
    require(refused(8, 4) == LiquidPolicyRefusalCode::NotSelectable, "Toxic Sludge alternate not selectable");
    World world(config(1));
    World current;
    require(world.inertial_enabled() && world.inertial_family(Material::Brine) &&
                !world.inertial_family(Material::Water) && !world.inertial_family(Material::Oil),
            "per-material dispatch identity");
    require(!current.inertial_enabled() && !current.inertial_cell(0, 0).available,
            "default World has no state");
}

void test_inertial_contract_examples() {
    for (const auto &example : kExamples) {
        auto example_config = config(1);
        example_config.sleep_after_quiet_ticks = 1;
        World world(example_config);
        world.reserve_region({0, 0, 64, 64});
        world.configure_transient_obstacles({0, 0, 64, 64});
        constexpr std::int64_t ox = 20;
        constexpr std::int64_t oy = 20;
        rect(world, ox - 4, oy - 4, 14, 16, Material::Wall);
        std::size_t height = 0;
        for (const auto row : example.rows)
            if (!row.empty())
                ++height;
        for (std::size_t r = 0; r < height; ++r) {
            for (std::size_t c = 0; c < example.rows[r].size(); ++c) {
                const auto x = ox + static_cast<std::int64_t>(c);
                const auto y = oy + static_cast<std::int64_t>(r);
                switch (example.rows[r][c]) {
                case '#':
                    break;
                case 'W':
                    rect(world, x, y, 1, 1, Material::Brine);
                    break;
                case 'o':
                    rect(world, x, y, 1, 1, Material::Dust);
                    break;
                case 'M':
                    rect(world, x, y, 1, 1, Material::Empty);
                    require(world.set_transient_obstacle(x, y, 1), "mask");
                    break;
                default:
                    rect(world, x, y, 1, 1, Material::Empty);
                    break;
                }
            }
        }
        // Keep the static lighter neighbours of the swap example at rest (the
        // contract's neighbourhood is static; Dust beside Empty would slide).
        if (example.name == "drag-density-swap") {
            rect(world, ox + 1, oy + 3, 1, 1, Material::Wall);
            rect(world, ox + 3, oy + 3, 1, 1, Material::Wall);
        }
        const auto sx = ox + example.x;
        const auto sy = oy + example.y;
        require(world.diagnostic_set_inertial_cell(
                    sx, sy, static_cast<std::int16_t>(example.vx), static_cast<std::int16_t>(example.vy),
                    static_cast<std::int8_t>(example.ax), static_cast<std::int8_t>(example.ay)),
                std::string(example.name) + ": start state");
        const auto stats = tick(world);
        if (!example.sleep)
            require(stats.active_blocks_after != 0U, std::string(example.name) + ": active eligibility");
        const auto ex = ox + example.end_x;
        const auto ey = oy + example.end_y;
        require(world.stored_material(ex, ey) == Material::Brine,
                std::string(example.name) + ": cell not at the contract end position");
        const auto s = world.inertial_cell(ex, ey);
        require(s.vx == example.end_vx && s.vy == example.end_vy && s.ax == example.end_ax &&
                    s.ay == example.end_ay,
                std::string(example.name) + ": end state (" + std::to_string(s.vx) + "," +
                    std::to_string(s.vy) + "," + std::to_string(s.ax) + "," + std::to_string(s.ay) + ")");
        if (example.name == "drag-density-swap")
            require(world.stored_material(sx, sy) == Material::Dust,
                    "density swap moved the lighter cell up");
        const auto ledger = world.inertial_ledger();
        // Signed per-component identity and the separate L1 speed identity.
        require(s.vx == example.vx + ledger.impulse_x - (ledger.external_x - example.vx) &&
                    s.vy ==
                        example.vy + ledger.gravity_y + ledger.impulse_y - (ledger.external_y - example.vy),
                std::string(example.name) + ": momentum ledger");
        require(std::abs(s.vx) + std::abs(s.vy) ==
                    std::abs(example.vx) + example.vy + ledger.gravity_y - ledger.loss,
                std::string(example.name) + ": speed-loss ledger");
        if (example.sleep) {
            // A final state write keeps its activity block alive for that tick;
            // the next unchanged update must allow the block to sleep.
            const auto quiet = tick(world);
            require(quiet.active_blocks_after == 0U,
                    std::string(example.name) + ": sleep after final dirty publication");
            const auto rest = world.inertial_cell(ex, ey);
            require(rest.vx == 0 && rest.vy == 0 && rest.ax == 0 && rest.ay == 0,
                    "sleep must retain exact zero state");
        }
    }
}

void build_basin(World &world) {
    rect(world, 8, 100, 112, 2, Material::Wall);
    rect(world, 8, 20, 2, 80, Material::Wall);
    rect(world, 118, 20, 2, 80, Material::Wall);
    rect(world, 40, 20, 2, 80, Material::Wall); // gate
    rect(world, 10, 50, 30, 50, Material::Brine);
}

void test_inertial_ledgers_rest_and_parity() {
    World one(config(1));
    World four(config(4));
    for (World *w : {&one, &four}) {
        w->reserve_region({0, 0, 128, 128});
        build_basin(*w);
    }
    const RectI64 all{0, 0, 128, 128};
    const auto start = totals(one, all);
    rect(one, 40, 20, 2, 80, Material::Empty);
    rect(four, 40, 20, 2, 80, Material::Empty);
    std::int64_t far = 0;
    bool moving_after_release = false;
    for (int t = 1; t <= 400; ++t) {
        tick(one);
        tick(four);
        require(one.physical_state_hash() == four.physical_state_hash(),
                "1/4-worker divergence at t" + std::to_string(t));
        {
            const auto now = totals(one, all);
            const auto ledger = one.inertial_ledger();
            require(now.brine == start.brine, "whole-cell Brine count drifted at t" + std::to_string(t));
            require(now.vx - start.vx == ledger.impulse_x + ledger.external_x - ledger.retired_x &&
                        now.vy - start.vy ==
                            ledger.gravity_y + ledger.impulse_y + ledger.external_y - ledger.retired_y,
                    "momentum ledger does not close at t" + std::to_string(t));
            require(now.speed - start.speed == ledger.gravity_y - ledger.loss -
                                                   static_cast<std::int64_t>(ledger.velocity_retired) +
                                                   ledger.external_speed,
                    "speed-loss ledger does not close at t" + std::to_string(t));
            moving_after_release = moving_after_release || now.speed > 0;
        }
    }
    for (std::int64_t x = 117; x >= 42; --x)
        if (one.stored_material(x, 99) == Material::Brine) {
            far = x;
            break;
        }
    require(moving_after_release && far > 60, "released Brine travels (front " + std::to_string(far) + ")");
    // Static rest: a fully supported closed column keeps every velocity at
    // exactly zero and its physical hash changes only through the clock.
    World pool(config(1));
    pool.reserve_region({0, 0, 64, 64});
    rect(pool, 8, 40, 20, 2, Material::Wall);
    rect(pool, 8, 20, 2, 20, Material::Wall);
    rect(pool, 26, 20, 2, 20, Material::Wall);
    rect(pool, 10, 30, 16, 10, Material::Brine);
    tick(pool, 30);
    const auto settled = totals(pool, {0, 0, 64, 64});
    const auto hash_free = pool.content_hash();
    const auto full_hash = pool.physical_state_hash();
    tick(pool, 30);
    for (std::int64_t y = 0; y < 64; ++y)
        for (std::int64_t x = 0; x < 64; ++x) {
            const auto s = pool.inertial_cell(x, y);
            require(s.vx == 0 && s.vy == 0 && s.ax == 0 && s.ay == 0,
                    "all four components stay zero at rest");
        }
    require(pool.physical_state_hash() != full_hash, "complete hash retains advancing clocks");
    require(settled.speed == 0 && totals(pool, {0, 0, 64, 64}).speed == 0 && pool.content_hash() == hash_free,
            "a supported closed pool must stay exactly at rest");
    require(pool.tick().active_blocks_after == 0U, "a rested inertial pool sleeps");
}

void test_inertial_no_tunnelling() {
    for (const bool mask : {false, true}) {
        auto example_config = config(1);
        example_config.sleep_after_quiet_ticks = 1;
        World world(example_config);
        world.reserve_region({0, 0, 64, 64});
        world.configure_transient_obstacles({0, 0, 64, 64});
        rect(world, 0, 50, 64, 2, Material::Wall);
        for (std::int64_t x = 0; x < 64; ++x) {
            if (mask)
                require(world.set_transient_obstacle(x, 30, 1), "mask");
            else
                rect(world, x, 30, 1, 1, Material::Wall);
        }
        rect(world, 20, 10, 10, 10, Material::Brine);
        for (int t = 0; t < 120; ++t) {
            tick(world);
            for (std::int64_t y = 31; y < 50; ++y)
                for (std::int64_t x = 0; x < 64; ++x)
                    require(world.stored_material(x, y) != Material::Brine,
                            std::string("Brine tunnelled through a ") + (mask ? "body mask" : "wall"));
        }
        if (mask)
            require(world.transient_contact_count(1) > 0U, "body-mask landings record contacts");
    }
}

void test_inertial_lifecycle_chemistry() {
    World world(config(1));
    world.reserve_region({0, 0, 64, 64});
    rect(world, 0, 50, 64, 2, Material::Wall);
    // Water + Salt -> Brine: products start at the inertial default (zero).
    rect(world, 10, 40, 10, 10, Material::Water);
    rect(world, 10, 30, 10, 10, Material::Salt);
    bool produced = false;
    for (int t = 0; t < 200 && !produced; ++t) {
        tick(world);
        for (std::int64_t y = 0; y < 50 && !produced; ++y)
            for (std::int64_t x = 0; x < 64 && !produced; ++x)
                produced = world.stored_material(x, y) == Material::Brine;
    }
    require(produced, "Water+Salt produced no Brine");
    // Velocity never sits on a non-inertial or Empty cell.
    tick(world, 50);
    for (std::int64_t y = 0; y < 64; ++y)
        for (std::int64_t x = 0; x < 64; ++x) {
            const auto s = world.inertial_cell(x, y);
            if (world.stored_material(x, y) != Material::Brine)
                require(s.vx == 0 && s.vy == 0 && s.ax == 0 && s.ay == 0,
                        "inertial state left on a non-Brine cell or vacancy");
            require(s.vy >= 0 && std::abs(s.vx) <= InertialParameters::kVmax &&
                        s.vy <= InertialParameters::kVmax,
                    "inertial state outside its declared range");
        }
    // Painting over a moving Brine cell retires its velocity with a ledger entry.
    World falling(config(1));
    falling.reserve_region({0, 0, 64, 64});
    rect(falling, 0, 60, 64, 2, Material::Wall);
    rect(falling, 30, 5, 1, 1, Material::Brine);
    tick(falling, 5);
    std::optional<std::pair<std::int64_t, std::int64_t>> cell;
    for (std::int64_t y = 0; y < 60 && !cell; ++y)
        if (falling.stored_material(30, y) == Material::Brine)
            cell = std::pair{std::int64_t{30}, y};
    require(cell && falling.inertial_cell(cell->first, cell->second).vy > 0, "falling Brine carries vy");
    const auto before = falling.inertial_ledger().velocity_retired;
    rect(falling, cell->first, cell->second, 1, 1, Material::Sand);
    require(falling.inertial_ledger().velocity_retired > before &&
                falling.inertial_cell(cell->first, cell->second).vy == 0,
            "paint retires velocity with a ledger entry");
}

void build_three(World &world) {
    rect(world, 8, 120, 112, 2, Material::Wall);
    rect(world, 8, 20, 2, 100, Material::Wall);
    rect(world, 118, 20, 2, 100, Material::Wall);
    rect(world, 30, 40, 20, 20, Material::Brine); // heavy, inertial
    rect(world, 30, 60, 20, 20, Material::Oil);   // light, cellular_yield
    rect(world, 30, 80, 20, 40, Material::Water); // freemass or pressure
}

std::array<std::int64_t, 3> counts(const World &world) {
    std::array<std::int64_t, 3> out{};
    for (std::int64_t y = 0; y < 128; ++y)
        for (std::int64_t x = 0; x < 128; ++x) {
            const auto m = world.stored_material(x, y);
            if (m == Material::Brine)
                ++out[0];
            if (m == Material::Oil)
                ++out[1];
            if (m == Material::Water)
                ++out[2];
        }
    return out;
}

double mean_y(const World &world, Material material) {
    double sum = 0;
    double n = 0;
    for (std::int64_t y = 0; y < 128; ++y)
        for (std::int64_t x = 0; x < 128; ++x)
            if (world.stored_material(x, y) == material) {
                sum += static_cast<double>(y);
                n += 1;
            }
    return n == 0 ? 0 : sum / n;
}

void closed(const World &, RectI64);

void test_three_families_one_world() {
    for (const bool pressure : {false, true}) {
        World one(config(1, pressure));
        World four(config(4, pressure));
        for (World *w : {&one, &four}) {
            w->reserve_region({0, 0, 128, 128});
            build_three(*w);
        }
        const auto policy_water = one.liquid_solver_policy().assignment(3)->family;
        require(
            policy_water ==
                    (pressure ? LiquidSolverFamily::PressureFlowV1 : LiquidSolverFamily::FreeMassV1) &&
                one.liquid_solver_policy().assignment(16)->family == LiquidSolverFamily::CellularYieldV1 &&
                one.liquid_solver_policy().assignment(24)->family == LiquidSolverFamily::InertialCellularV1,
            "three distinct families assigned in one World");
        const auto start = counts(one);
        const auto water = one.water_quantity({0, 0, 128, 128});
        for (int t = 1; t <= 600; ++t) {
            tick(one);
            tick(four);
            require(counts(one)[0] == start[0] && counts(one)[1] == start[1] &&
                        one.water_quantity({0, 0, 128, 128}) == water,
                    "three-family quantity closes each tick");
            require(one.inertial_ledger() == four.inertial_ledger(), "three-family ledgers match each tick");
            closed(one, {0, 0, 128, 128});
            require(one.physical_state_hash() == four.physical_state_hash(),
                    std::string(pressure ? "pressure" : "freemass") + " three-family 1/4 divergence at t" +
                        std::to_string(t));
        }
        require(counts(one)[0] == start[0] && counts(one)[1] == start[1],
                "Brine/Oil whole-cell counts conserved");
        require(one.water_quantity({0, 0, 128, 128}) == water, "Water quantity conserved");
        // Density ordering emerges from real cross-family exchanges: Brine sinks
        // through Oil and Water; Oil rises above Water.
        require(mean_y(one, Material::Brine) > mean_y(one, Material::Water) &&
                    mean_y(one, Material::Water) > mean_y(one, Material::Oil),
                std::string(pressure ? "pressure" : "freemass") + " layering Brine > Water > Oil (depth)");
        require(one.inertial_ledger().density_swaps > 0U, "inertial Brine exchanged with lighter liquids");
        if (pressure)
            require(one.pressure_flow_enabled() && one.inertial_enabled(), "pressure + inertial active");
        // Persistence carries both sidecars exactly, and continues identically.
        auto restored = World::restore_physical_state(WorldConfig{}, one.save_physical_state());
        require(restored->physical_state_hash() == one.physical_state_hash(), "three-family restore hash");
        for (int t = 0; t < 30; ++t) {
            tick(one);
            tick(*restored);
        }
        require(restored->physical_state_hash() == one.physical_state_hash(),
                "three-family exact continuation");
    }
}

void closed(const World &world, RectI64 region) {
    const auto total = totals(world, region);
    const auto l = world.inertial_ledger();
    require(total.vx == l.impulse_x + l.external_x - l.retired_x &&
                total.vy == l.gravity_y + l.impulse_y + l.external_y - l.retired_y,
            "per-component IN closure");
    require(total.speed ==
                l.gravity_y - l.loss + l.external_speed - static_cast<std::int64_t>(l.velocity_retired),
            "L1 IN closure (external changes are summed before cancellation)");
}
void test_inertial_boundary_workers() {
    auto narrow = config(1);
    narrow.maximum_rule_radius = 2;
    bool refused = false;
    try {
        World invalid(narrow);
    } catch (const std::invalid_argument &) {
        refused = true;
    }
    require(refused, "radius-two IN was admitted");
    for (const auto core : {8, 64})
        for (const auto x : {-1, 63, 127}) {
            auto c = config(4);
            c.chunk_size = 128;
            c.scheduling_core_size = core;
            c.activity_block_size = 8;
            c.parallel_job_threshold = 1;
            World seam(c);
            seam.reserve_region({-128, -128, 512, 384});
            seam.set(x, core - 3, Material::Brine);
            require(seam.diagnostic_set_inertial_cell(x, core - 3, 0, 32, 0, 15), "seam initial motion");
            const auto s = tick(seam);
            require(seam.stored_material(x, core - 1) == Material::Brine &&
                        seam.inertial_cell(x, core - 1).vy == 30,
                    "two-cell travel at signed seam");
            require(seam.inertial_ledger().maximum_read_reach == 3 &&
                        seam.inertial_ledger().maximum_write_reach == 2,
                    "observed complete read/write reach");
            require(s.chunk_allocations == 0 && s.temperature_field_allocations == 0,
                    "prepared seam allocated during tick");
        }
    World one(config(1)), four(config(4));
    for (auto *w : {&one, &four}) {
        w->reserve_region({0, 0, 512, 512});
        for (int gy = 0; gy < 4; ++gy)
            for (int gx = 0; gx < 4; ++gx) {
                const auto ox = gx * 128, oy = gy * 128;
                rect(*w, ox + 4, oy + 112, 120, 2, Material::Wall);
                rect(*w, ox + 4, oy + 4, 2, 108, Material::Wall);
                rect(*w, ox + 122, oy + 4, 2, 108, Material::Wall);
                rect(*w, ox + 16, oy + 16, 88, 64, Material::Brine);
            }
    }
    std::uint32_t observed = 0;
    for (int i = 0; i < 32; ++i) {
        const auto a = tick(one), b = tick(four);
        observed = std::max(observed, b.worker_threads_observed);
        require(one.physical_state_hash() == four.physical_state_hash() &&
                    one.inertial_ledger() == four.inertial_ledger(),
                "genuine multi-core 1/4-worker divergence");
        require(a.chunk_allocations == 0 && b.chunk_allocations == 0, "prepared four-worker World allocated");
        closed(one, {0, 0, 512, 512});
    }
    require(observed == 4U, "four configured workers did not all execute tasks");
    std::cout << "IN worker observation: configured=4 observed=" << observed << "\n";
}
void test_inertial_reset_products() {
    World w(config(1));
    w.reserve_region({0, 0, 256, 128});
    w.set_simulation_region(RectI64{0, 0, 64, 64});
    w.set(64, 20, Material::Brine);
    const auto seed = [&] {
        require(w.diagnostic_set_inertial_cell(64, 20, 17, 23, 7, -9), "reset initial motion");
    };
    const auto zero = [&] {
        const auto s = w.inertial_cell(64, 20);
        return !s.vx && !s.vy && !s.ax && !s.ay;
    };
    seed();
    (void)w.take_dirty_chunks();
    const auto before = w.physical_state_hash();
    w.set(64, 20, Material::Brine);
    require(zero() && w.dirty_chunk_count() != 0 && w.physical_state_hash() != before,
            "same-material paint reset was invisible");
    seed();
    (void)w.take_dirty_chunks();
    require(w.set_cell_state(64, 20, Material::Brine, 0, 0) && zero() && w.dirty_chunk_count() != 0,
            "same-visible tuple reset was invisible");
    seed();
    w.configure_transient_obstacles({0, 0, 256, 128});
    require(w.set_transient_obstacle(64, 20, 1), "reset mask");
    const auto masked = w.physical_state_hash();
    require(!w.set_cell_state(64, 20, Material::Brine, 0, 0) && w.physical_state_hash() == masked,
            "masked rejected edit changed stored motion");
    w.clear_transient_obstacles();
    require(w.set_cell_state(64, 20, Material::Empty, 0, 0) && zero(), "erase retained IN state");
    // Brine is the active initiator; unchanged BareIron has no active kernel.
    // Pin its geometry and seed before each declared attempt. A successful pair
    // returns before motion, so retirement distinguishes a fresh Brine product
    // from an ordinary contact that dissipates velocity through the loss ledger.
    rect(w, 61, 18, 5, 5, Material::Wall);
    w.set(63, 20, Material::Brine);
    w.set(64, 20, Material::BareIron);
    std::uint64_t retired = 0;
    for (int i = 0; i < 512 && w.stored_material(64, 20) == Material::BareIron; ++i) {
        require(w.diagnostic_set_inertial_cell(63, 20, 17, 23, 7, -9), "reaction moving reagent");
        retired = w.inertial_ledger().velocity_retired;
        tick(w);
    }
    require(w.stored_material(64, 20) == Material::RustedSteel, "Brine/BareIron reaction did not execute");
    const auto product = w.inertial_cell(63, 20);
    require(w.stored_material(63, 20) == Material::Brine && !product.vx && !product.vy && !product.ax &&
                !product.ay && w.inertial_ledger().velocity_retired == retired + 40U,
            "same-material Brine product retained old velocity");
    closed(w, {0, 0, 256, 128});
    std::vector<Material> generated(128U * 128U, Material::Empty);
    generated[5] = Material::Brine;
    require(w.install_generated_chunk({2, 0}, generated) == cybersand::ChunkInstallOutcome::Installed,
            "generated Brine installation");
    require(w.inertial_cell(261, 0).vx == 0 && w.inertial_cell(261, 0).ay == 0, "generated default motion");
    w.clear();
    require(w.inertial_ledger() == cybersand::InertialLedger{} && w.inertial_storage_usage().slot_bytes == 0,
            "clear retained IN storage or ledger");
}
void reseal(std::vector<std::uint8_t> &bytes) {
    const auto digest = cybersand::Sha256::of(std::span<const std::uint8_t>(bytes).first(bytes.size() - 32U));
    std::copy(digest.begin(), digest.end(), bytes.end() - 32);
}
void test_inertial_storage_capture() {
    World w(config(1));
    w.reserve_region({0, 0, 1024, 1024});
    w.set(600, 600, Material::Brine);
    require(w.diagnostic_set_inertial_cell(600, 600, 17, 23, 7, -9), "capture seed");
    const auto storage = w.inertial_storage_usage();
    require(storage.slot_size == 6U && storage.slot_alignment == 2U && storage.resident_chunks == 64U &&
                storage.slot_bytes == 6U * 1024U * 1024U && storage.nonzero_slots == 1U,
            "actual IN array accounting");
    require(storage.total_component_bytes == storage.slot_bytes + storage.owner_bytes +
                                                 storage.job_ledger_bytes + storage.world_state_bytes,
            "IN accounting does not sum");
    const auto start = std::chrono::steady_clock::now();
    const auto saved = w.save_physical_state();
    auto restored = World::restore_physical_state(config(1), saved);
    const auto duration = std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count();
    require(w.physical_state_hash_version() == 3U && w.physical_state_format_version() == 3U &&
                saved[4] == 3U,
            "IN explicit hash3/CYPS3 identity");
    require(restored->save_physical_state() == saved &&
                restored->physical_state_hash() == w.physical_state_hash() &&
                restored->inertial_ledger() == w.inertial_ledger(),
            "canonical IN capture/restore");
    cybersand::setup::SetupDescriptor setup;
    setup.domain = {0, 0, 1024, 1024};
    const auto facts = cybersand::receipt::capture_native_facts(w, setup);
    require(facts.values().physical_hash_version == 3 && facts.values().solver_state_extensions.size() == 1 &&
                facts.values().solver_state_extensions[0].family == 4 &&
                facts.values().solver_state_extensions[0].extension_digest ==
                    cybersand::inertial_extension_identity(),
            "native-owned IN state and parameter identity missing");
    const auto applied = cybersand::receipt::build_applied_run_receipt(
        facts, setup, w.liquid_solver_policy().envelope(), cybersand::receipt::RunIntent::Exploratory,
        cybersand::receipt::PlaneActivity::Active, {}, {}, 1);
    require(!applied.canonical_bytes().empty() && !applied.eligible_for_full_matched_evidence(),
            "native IN receipt encoding or provenance qualification");
    const auto refusal = [&](std::vector<std::uint8_t> bytes) {
        reseal(bytes);
        bool failed = false;
        try {
            (void)World::restore_physical_state(config(1), bytes);
        } catch (const std::invalid_argument &) {
            failed = true;
        }
        require(failed && w.save_physical_state() == saved, "invalid IN capture admitted or changed source");
    };
    auto old = saved;
    old[4] = 2;
    refusal(std::move(old));
    auto identity = saved;
    const auto id = cybersand::inertial_extension_identity();
    const auto at = std::search(identity.begin(), identity.end() - 32, id.begin(), id.end());
    require(at != identity.end() - 32, "IN identity record missing");
    *at ^= 1U;
    refusal(std::move(identity));
    const std::array<std::uint8_t, 6> motion{17, 0, 23, 0, 7, 247};
    const auto slot = std::search(saved.begin(), saved.end() - 32, motion.begin(), motion.end());
    require(slot != saved.end() - 32, "distinct IN slot encoding missing");
    const auto offset = static_cast<std::size_t>(slot - saved.begin());
    auto bad = saved;
    bad[saved.size() - 32U - 152U + 8U] ^= 1U;
    refusal(std::move(bad));
    bad = saved;
    bad[offset] = 33;
    refusal(std::move(bad));
    bad = saved;
    bad[offset + 4] = 16;
    refusal(std::move(bad));
    bad = saved;
    std::copy(motion.begin(), motion.end(), bad.begin() + static_cast<std::ptrdiff_t>(offset + 6U));
    refusal(std::move(bad));
    for (int i = 0; i < 270; ++i) {
        tick(w);
        tick(*restored);
        require(w.physical_state_hash() == restored->physical_state_hash(), "IN epoch-wrap continuation");
    }
    World plain;
    require(plain.physical_state_hash_version() == 2 && plain.save_physical_state()[4] == 2,
            "non-IN formats changed");
    std::cout << "IN storage 1024: slot=" << storage.slot_size << " align=" << storage.slot_alignment
              << " bytes=" << storage.slot_bytes << " owners=" << storage.owner_bytes
              << " worker_ledgers=" << storage.job_ledger_bytes << " world=" << storage.world_state_bytes
              << " total_components=" << storage.total_component_bytes << " serialized=" << saved.size()
              << " capture_restore_seconds=" << duration << "\n";
}
void test_inertial_residual_motion() {
    World w(config(1));
    w.reserve_region({0, 0, 128, 128});
    rect(w, 0, 30, 128, 2, Material::Wall);
    w.set(10, 29, Material::Brine);
    require(w.diagnostic_set_inertial_cell(10, 29, 0, 32, 0, 0), "bounded initial falling impulse");
    tick(w); // Single landing deflection is the bounded lateral source.
    std::int64_t previous = 0;
    for (std::int64_t x = 0; x < 128; ++x)
        if (w.stored_material(x, 29) == Material::Brine)
            previous = x;
    const auto direction = previous > 10 ? 1 : -1;
    require(previous != 10, "landing did not create lateral motion");
    constexpr int N = 3;
    for (int i = 0; i < N; ++i) {
        const auto before = previous;
        tick(w);
        for (std::int64_t x = 0; x < 128; ++x)
            if (w.stored_material(x, 29) == Material::Brine)
                previous = x;
        require((previous - before) * direction > 0, "retained lateral motion ended before declared N=3");
        closed(w, {0, 0, 128, 128});
    }
    require((previous - 10) * direction >= 4, "no over-run beyond stationary gravity-only supported path");
}

} // namespace

void test_lcb_inertial_admission() { test_inertial_admission(); }
void test_lcb_inertial_contract_examples() { test_inertial_contract_examples(); }
void test_lcb_inertial_ledgers_rest_parity() { test_inertial_ledgers_rest_and_parity(); }
void test_lcb_inertial_no_tunnelling() { test_inertial_no_tunnelling(); }
void test_lcb_inertial_lifecycle() { test_inertial_lifecycle_chemistry(); }
void test_lcb_inertial_three_families() { test_three_families_one_world(); }

void test_lcb_inertial_boundary_workers() { test_inertial_boundary_workers(); }

void test_lcb_inertial_reset_products() { test_inertial_reset_products(); }

void test_lcb_inertial_storage_capture() { test_inertial_storage_capture(); }

void test_lcb_inertial_residual_motion() { test_inertial_residual_motion(); }
