#include "cybersand/world.hpp"
#include "cybersand/material_rules.hpp"
#ifndef OBJECTSHARD_BASELINE_ORACLE
#include "cybersand/material_lifecycle.hpp"
#endif

#include <array>
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <string_view>
#include <type_traits>

namespace cybersand {
class PrecisionProbe {
public:
    static void chemical_clock(World& world, std::uint64_t tick, std::uint8_t epoch) {
        world.tick_index_ = tick;
        world.completed_tick_index_ = tick;
        world.update_epoch_ = epoch;
    }
};
}

namespace {
using namespace cybersand;
constexpr std::uint64_t kFnv = 14695981039346656037ULL;
std::uint64_t checks = 0;
void require(bool condition, const char* message) {
    ++checks;
    if (!condition) throw std::runtime_error(message);
}
template<class T> void append(std::uint64_t& digest, T value) {
    using U = std::make_unsigned_t<T>;
    auto bits = static_cast<U>(value);
    for (std::size_t byte = 0; byte < sizeof(T); ++byte) {
        digest ^= static_cast<std::uint8_t>(bits & 255U);
        digest *= 1099511628211ULL;
        bits = static_cast<U>(bits >> 8U);
    }
}

WorldConfig config(SimulationBackend backend) {
    WorldConfig c;
    c.chunk_size = 16;
    c.backend = backend;
    c.activity_block_size = 8;
    c.scheduling_core_size = 8;
    c.initial_chunk_reserve = 16;
    c.active_core_capacity = 64;
    c.active_chunk_capacity = 16;
    c.maximum_chunk_count = 64;
    c.deferred_event_capacity = 16;
    c.worker_threads = 1;
    return c;
}

struct Fixture {
    std::string_view name;
    int recipe;
    int ticks;
    int offset;
    std::uint64_t clock;
    std::uint8_t epoch;
};
constexpr std::array<Fixture, 8> kFixtures{{
    {"sealed_wood_countdown", 0, 90, 0, 0, 0},
    {"wood_emission_and_products", 1, 192, 0, 0, 0},
    {"water_extinguishes_wood", 2, 32, 0, 0, 0},
    {"fire_expiry", 3, 160, 0, 0, 0},
    {"crowded_smoke", 4, 192, 0, 0, 0},
    {"pair_precedence", 5, 96, 0, 0, 0},
    {"negative_logical_coordinates", 1, 192, -32, 0, 0},
    {"burn_across_epoch_wrap", 6, 520, 0, 250, 250},
}};

void populate(World& world, const Fixture& f) {
    const int ox = f.offset, oy = f.offset;
    world.reserve_region({ox - 16, oy - 16, 64, 64});
    world.reserve_temperature_region({ox, oy, 32, 32});
    world.set_simulation_region(RectI64{ox, oy, 32, 32});
    for (int y = 0; y < 32; ++y) for (int x = 0; x < 32; ++x) {
        if (x == 0 || y == 0 || x == 31 || y == 31)
            world.set(ox + x, oy + y, Material::Wall);
    }
    const auto cell = [&](int x, int y, Material m, std::uint16_t a, std::uint8_t b,
                          std::int16_t temperature = 200) {
        (void)world.set_cell_state(ox + x, oy + y, m, a, b);
        world.set_temperature(ox + x, oy + y, temperature);
    };
    const auto seal = [&](int x, int y) {
        for (int dy = -1; dy <= 1; ++dy) for (int dx = -1; dx <= 1; ++dx)
            if (dx || dy) world.set(ox + x + dx, oy + y + dy, Material::Wall);
    };
    switch (f.recipe) {
        case 0:
            seal(11, 11);
            cell(11, 11, Material::Wood, 213, 35, 417);
            break;
        case 1:
            for (int y = 10; y <= 20; y += 5) for (int x = 8; x <= 23; x += 5)
                cell(x, y, Material::Wood, static_cast<std::uint16_t>(100 + x), 64,
                     static_cast<std::int16_t>(300 + y));
            break;
        case 2:
            seal(11, 11);
            cell(11, 11, Material::Wood, 225, 8, 617);
            cell(10, 11, Material::Water, 255, 9);
            world.set(ox + 9, oy + 10, Material::Wall);
            world.set(ox + 9, oy + 11, Material::Wall);
            world.set(ox + 9, oy + 12, Material::Wall);
            break;
        case 3:
            seal(11, 11);
            cell(11, 11, Material::Fire, 1, 23, 91);
            break;
        case 4:
            for (int y = 8; y <= 12; ++y) for (int x = 8; x <= 12; ++x)
                cell(x, y, Material::Smoke, static_cast<std::uint16_t>((x + y) % 3 == 0 ? 0 : 13), 4);
            break;
        case 5:
            cell(10, 10, Material::Fire, 8, 99, 501);
            cell(11, 10, Material::Water, 255, 0);
            cell(10, 11, Material::Wood, 211, 24, 401);
            cell(11, 11, Material::Wood, 17, 0, 411);
            cell(12, 10, Material::Wood, 25, 16, 421);
            break;
        case 6:
            seal(11, 11);
            seal(21, 11);
            cell(11, 11, Material::Wood, 255, 255, -120);
            cell(21, 11, Material::Fire, 255, 255, 1800);
            break;
        default: throw std::runtime_error("unknown fixture");
    }
    PrecisionProbe::chemical_clock(world, f.clock, f.epoch);
}

struct Record {
    std::uint64_t tuples = kFnv, accounting = kFnv, physical = kFnv;
    std::uint64_t fire_samples = 0, smoke_samples = 0, wood_samples = 0;
    std::uint64_t water_pair_events = 0;
};

void capture(World& world, const Fixture& f, Record& result) {
    append(result.tuples, world.tick_index());
    for (int y = 0; y < 32; ++y) for (int x = 0; x < 32; ++x) {
        const auto wx = f.offset + x, wy = f.offset + y;
        const auto m = world.stored_material(wx, wy);
        append(result.tuples, static_cast<std::uint8_t>(m));
        append(result.tuples, world.stored_state_a(wx, wy));
        append(result.tuples, world.stored_state_b(wx, wy));
        append(result.tuples, world.stored_temperature(wx, wy));
        result.fire_samples += m == Material::Fire;
        result.smoke_samples += m == Material::Smoke;
        result.wood_samples += m == Material::Wood;
    }
    const auto q = world.quantity_ledger();
    append(result.accounting, world.tick_index());
    append(result.accounting, q.baseline_water);
    append(result.accounting, q.water_visible);
    append(result.accounting, q.water_overfill);
    for (const auto count : q.material_cells) append(result.accounting, count);
    for (const auto count : q.prepared_material_cells) append(result.accounting, count);
    for (const auto& flow : q.kinds) {
        append(result.accounting, flow.produced); append(result.accounting, flow.consumed);
    }
    for (std::size_t i = 0; i < q.pair_rules.size(); ++i) {
        append(result.accounting, q.pair_rules[i].produced);
        append(result.accounting, q.pair_rules[i].consumed);
        append(result.accounting, q.pair_events[i]);
    }
    for (const auto& flow : q.kernel_rules) {
        append(result.accounting, flow.produced); append(result.accounting, flow.consumed);
    }
    append(result.physical, world.physical_state_hash());
    result.water_pair_events = 0;
    for (const auto events : q.pair_events) result.water_pair_events += events;
}

Record execute(const Fixture& f, SimulationBackend backend) {
    World world(config(backend));
    populate(world, f);
    Record result;
    capture(world, f, result);
    for (int tick = 0; tick < f.ticks; ++tick) {
        (void)world.tick();
        require(!world.has_failed(), "actual World fixture failed");
        capture(world, f, result);
    }
    if (f.recipe == 1) {
        require(result.fire_samples != 0, "Wood fixture produced no real Fire");
        require(result.smoke_samples != 0, "Fire fixture produced no real Smoke");
    }
    if (f.recipe == 2) {
        require(world.stored_material(f.offset + 11, f.offset + 11) == Material::Wood &&
                world.stored_state_b(f.offset + 11, f.offset + 11) == 0,
                "actual neighboring Water did not extinguish Wood");
        require(world.stored_state_a(f.offset + 11, f.offset + 11) == 225 &&
                world.stored_temperature(f.offset + 11, f.offset + 11) == 617,
                "extinguishing reset material state or temperature");
    }
    return result;
}

struct Oracle { std::uint64_t tuples, accounting, physical; };
// Frozen from unchanged source 30e1cddd3d678456df10f52f7a2fb2210a9daaad.
// Hashes cover every intermediate tuple/tick, all ledger counters and complete
// physical state; serial and phased executions have separate original oracles.
constexpr std::array<Oracle, 16> kOracle{{
    {696560134201903317ULL, 8478589081798612443ULL, 7495025039529568421ULL},
    {5839831428092041478ULL, 4357082588986299519ULL, 18079868852383678880ULL},
    {13278900821021796051ULL, 4429197230748566275ULL, 9811387371455260284ULL},
    {4777073293096219322ULL, 10581633867887538112ULL, 15193295293428992889ULL},
    {8369273419383457497ULL, 13351936969552617926ULL, 17328091190029446653ULL},
    {16039525658929031671ULL, 16666702268689922910ULL, 1986010265946479235ULL},
    {260832018664934841ULL, 9230241232283154301ULL, 9908478963579571654ULL},
    {12695958861557438906ULL, 16895749110581388086ULL, 10437447394126641309ULL},
    {696560134201903317ULL, 8478589081798612443ULL, 11192219377850141224ULL},
    {14379627785132089748ULL, 4357082588986299519ULL, 10651387148093695520ULL},
    {13278900821021796051ULL, 4429197230748566275ULL, 18130917225667177167ULL},
    {4777073293096219322ULL, 10581633867887538112ULL, 16804675019495133161ULL},
    {6121205645387371745ULL, 1117234305621800906ULL, 4405116412261868900ULL},
    {10267702091617186240ULL, 16666702268689922910ULL, 1834804824362245059ULL},
    {11600240701383245702ULL, 4064363662676547356ULL, 16398493659801937234ULL},
    {12695958861557438906ULL, 16895749110581388086ULL, 8166614909325151134ULL},
}};

#ifndef OBJECTSHARD_BASELINE_ORACLE
void shared_decisions_match_actual_stationary_world() {
    using namespace material_lifecycle;
    const auto wait = combustible(Material::Wood, 211, 1, false, true);
    require(!wait.write && wait.keep_active && wait.state_b == 1,
            "off-lane Water must not add a combustion opportunity");
    const auto wet = combustible(Material::Wood, 211, 1, true, true);
    require(wet.write && wet.material == Material::Wood && wet.state_a == 211 &&
            wet.state_b == 0 && !wet.sample_fire_emission,
            "Water extinction must precede last-burn consumption");
    const auto consumed = combustible(Material::Wood, 211, 1, true, false);
    require(consumed.material == Material::Empty && consumed.state_a == 0 && consumed.state_b == 0,
            "last burn consumes Wood without a synthetic Smoke product");
    const auto emits = combustible(Material::Wood, 211, 8, true, false);
    require(emits.material == Material::Wood && emits.state_b == 7 && emits.sample_fire_emission &&
            kWoodFireLifetime == 32, "Wood emission follows the pre-decrement eight-step cadence");
    const auto sparse = smoke_lifetime(Material::Smoke, 2, 4, true);
    const auto crowded = smoke_lifetime(Material::Smoke, 2, 5, true);
    require(sparse.material == Material::Smoke && sparse.state_a == 1 &&
            crowded.material == Material::Empty, "Smoke crowding threshold changed");
    const auto pair = MaterialRules::pair_reaction(Material::Fire, Material::Water, 0);
    require(pair && pair->source_product == Material::Smoke && pair->target_product == Material::Steam,
            "shared source still uses the original oriented pair resolver");

    for (const auto material : {Material::Wood, Material::Fire, Material::Smoke}) {
        World world(config(SimulationBackend::SerialInPlace));
        constexpr std::int64_t x = -11, y = 7;
        world.reserve_region({-32, -16, 64, 64});
        for (std::int64_t dy = -1; dy <= 1; ++dy)
            for (std::int64_t dx = -1; dx <= 1; ++dx)
                if (dx || dy) world.set(x + dx, y + dy, Material::Wall);
        std::uint16_t a = material == Material::Wood ? 211 : 17;
        std::uint8_t b = material == Material::Wood ? 64 : 0;
        (void)world.set_cell_state(x, y, material, a, b);
        world.set_temperature(x, y, 417);
        PrecisionProbe::chemical_clock(world, 250, 250);
        Material current = material;
        for (std::uint64_t tick = 251; tick <= 550; ++tick) {
            Transition next{current, a, b};
            if (current == Material::Wood)
                next = combustible(current, a, b, lane_due(tick, x, y, kCombustionPeriod,
                                                          kCombustionStream), false);
            else if (current == Material::Fire) next = fire_lifetime(a);
            else if (current == Material::Smoke)
                next = smoke_lifetime(current, a, 0, lane_due(tick, x, y, kSmokePeriod, kSmokeStream));
            if (next.write) { current = next.material; a = next.state_a; b = next.state_b; }
            (void)world.tick();
            require(world.stored_material(x, y) == current && world.stored_state_a(x, y) == a &&
                    world.stored_state_b(x, y) == b,
                    "shared selected decisions differ from actual World execution");
            // Temperature is a wrapper/storage responsibility, not a new helper law.
            if (current != Material::Empty)
                require(world.stored_temperature(x, y) == 417,
                        "state-only lifecycle update altered retained temperature");
        }
    }
}
#endif
}

int main() {
    try {
#ifndef OBJECTSHARD_BASELINE_ORACLE
        shared_decisions_match_actual_stationary_world();
#endif
        std::size_t index = 0;
        std::cout << "{\"source_baseline\":\"30e1cddd3d678456df10f52f7a2fb2210a9daaad\",\"fixtures\":[";
        for (const auto backend : {SimulationBackend::SerialInPlace, SimulationBackend::PhasedInPlace}) {
            for (const auto& f : kFixtures) {
                const auto r = execute(f, backend);
#ifndef OBJECTSHARD_BASELINE_ORACLE
                require(r.tuples == kOracle[index].tuples, "World tuple/timing parity failed");
                require(r.accounting == kOracle[index].accounting, "World accounting parity failed");
                require(r.physical == kOracle[index].physical, "World activity/traversal parity failed");
#endif
                if (index) std::cout << ',';
                std::cout << "{\"name\":\"" << f.name << "\",\"backend\":" << static_cast<int>(backend)
                          << ",\"ticks\":" << f.ticks << ",\"tuples\":" << r.tuples
                          << ",\"accounting\":" << r.accounting << ",\"physical\":" << r.physical
                          << ",\"fire_samples\":" << r.fire_samples << ",\"smoke_samples\":" << r.smoke_samples
                          << ",\"wood_samples\":" << r.wood_samples << ",\"pair_events\":" << r.water_pair_events << '}';
                ++index;
            }
        }
        std::cout << "],\"checks\":" << checks << ",\"failures\":0}\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "FAIL: " << error.what() << '\n';
        return 1;
    }
}
