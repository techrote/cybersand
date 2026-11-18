// WAVE-WATERWALL-001: deterministic native boundary stress. This drives the
// native APIs used around body occupancy; it is not a Rapier/Midge playtest.
#include "cybersand/world.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <exception>
#include <memory>
#include <random>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using namespace cybersand;
constexpr RectI64 kBounds{-128, -64, 320, 224};
enum class Mode { Original, Spill, Hybrid };

void require(bool condition, const std::string& text) {
    if (!condition) throw std::runtime_error(text);
}

struct Metrics {
    std::uint64_t ticks = 0, scripted_waterline_crossings = 0, relocations = 0, launches = 0;
    std::uint64_t masked_refusals = 0, capacity_refusals = 0, paused_refusals = 0;
    std::uint64_t region_changes = 0, overfill_edits = 0, drains = 0, maximum_live = 0;
    void add(const Metrics& other) {
        ticks += other.ticks; scripted_waterline_crossings += other.scripted_waterline_crossings;
        relocations += other.relocations; launches += other.launches;
        masked_refusals += other.masked_refusals;
        capacity_refusals += other.capacity_refusals; paused_refusals += other.paused_refusals;
        region_changes += other.region_changes; overfill_edits += other.overfill_edits;
        drains += other.drains; maximum_live = std::max(maximum_live, other.maximum_live);
    }
};

struct Result {
    std::vector<std::uint64_t> checkpoints;
    QuantityLedgerSnapshot ledger;
    Metrics metrics;
};

bool inside(int x, int y) {
    return x > kBounds.x && x < kBounds.x + kBounds.width - 1 &&
           y > kBounds.y && y < kBounds.y + kBounds.height - 1;
}

void rect(World& world, int x, int y, int width, int height, Material material) {
    for (int yy = y; yy < y + height; ++yy)
        for (int xx = x; xx < x + width; ++xx) world.set(xx, yy, material);
}

WorldConfig configuration(Mode mode, unsigned workers, unsigned substeps,
                          unsigned seed, int body_push = 0, int by_mass = 0) {
    WorldConfig cfg;
    cfg.worker_threads = workers;
    cfg.parallel_job_threshold = 1;
    cfg.maximum_chunk_count = 64;
    cfg.active_chunk_capacity = 64;
    cfg.wave_flow.enabled = true;
    cfg.wave_flow.substeps = static_cast<std::uint8_t>(substeps);
    cfg.wave_flow.body_push = body_push;
    cfg.wave_flow.body_push_by_mass = by_mass;
    cfg.wave_flow.spill.enabled = mode != Mode::Original;
    // Default seeds exercise the owner's preferred blobs-on/stream-off look
    // with both pool capacities; extended seeds also vary the look controls.
    cfg.wave_flow.spill.catch_falling = seed % 4U == 2U ? 0 : 1;
    cfg.wave_flow.spill.stream_share = seed % 4U == 3U ? 64 : 0;
    cfg.ballistic_water.enabled = mode == Mode::Hybrid;
    cfg.ballistic_water.capacity = seed % 2U == 0U ? 32 : 4096;
    return cfg;
}

void fixture(World& world) {
    world.reserve_region(kBounds);
    rect(world, -128, -64, 320, 1, Material::Wall);
    rect(world, -128, 159, 320, 1, Material::Wall);
    rect(world, -128, -64, 1, 224, Material::Wall);
    rect(world, 191, -64, 1, 224, Material::Wall);
    rect(world, -127, 50, 318, 109, Material::Water);
    // An exposed reservoir above the pool keeps spill and body contacts active.
    rect(world, -127, 35, 88, 3, Material::Wall);
    rect(world, -127, -5, 88, 40, Material::Water);
    // A thin partition crosses a chunk seam and creates confined Water.
    rect(world, -20, 100, 21, 2, Material::Wall);
    rect(world, -20, 100, 2, 42, Material::Wall);
    rect(world, -1, 100, 2, 42, Material::Wall);
    rect(world, -20, 140, 21, 2, Material::Wall);
    require(world.set_cell_state(-10, 116, Material::Water, 65535, 0), "fixture overfill refused");
    world.configure_transient_obstacles(kBounds, true);
}

std::uint64_t scan_water(const World& world, std::uint64_t& population) {
    std::uint64_t quantity = 0;
    population = 0;
    for (auto y = kBounds.y; y < kBounds.y + kBounds.height; ++y) {
        for (auto x = kBounds.x; x < kBounds.x + kBounds.width; ++x) {
            if (world.stored_material(x, y) != Material::Water) continue;
            const auto mass = world.stored_state_a(x, y);
            require(mass != 0U, "zero-mass stored Water");
            require(world.stored_state_b(x, y) == 0U, "Wave acquired coherent Water");
            quantity += mass;
            ++population;
        }
    }
    return quantity;
}

void check(const World& world, std::uint64_t expected, bool scan) {
    require(!world.has_failed(), "World quarantined");
    const auto ledger = world.quantity_ledger();
    const auto flight = world.ballistic_water_snapshot();
    require(ledger.water_visible + ledger.water_overfill + ledger.water_ballistic == expected,
            "quantity ledger differs from independently booked initial quantity/edits");
    require(ledger.water_ballistic == flight.in_flight_quantity,
            "parcel and World quantities disagree");
    require(flight.ledger.launched_quantity + flight.ledger.injected_quantity ==
                flight.ledger.deposited_quantity + flight.in_flight_quantity,
            "ballistic transfer ledger does not close");
    std::uint64_t produced = ledger.baseline_water, consumed = expected;
    for (const auto& flow : ledger.kinds) { produced += flow.produced; consumed += flow.consumed; }
    require(produced == consumed, "external source/sink accounting does not close");
    if (scan) {
        std::uint64_t population = 0;
        const auto quantity = scan_water(world, population);
        require(quantity + flight.in_flight_quantity == expected, "stored plus in-flight quantity changed");
        require(quantity == ledger.water_visible + ledger.water_overfill,
                "ledger differs from full stored-cell scan");
        require(population == ledger.material_cells[static_cast<std::size_t>(Material::Water)],
                "Water cell population drifted");
        std::vector<BallisticParcel> parcels(world.ballistic_parcel_count());
        require(world.copy_ballistic_parcels(parcels) == parcels.size(), "parcel snapshot truncated");
        std::uint64_t in_flight = 0;
        for (const auto& parcel : parcels) {
            require(parcel.quantity > 0U && parcel.quantity <= 255U, "parcel quantity outside admitted range");
            in_flight += parcel.quantity;
        }
        require(in_flight == flight.in_flight_quantity, "parcel vector differs from in-flight ledger");
    }
}

int triangle(unsigned tick, unsigned period) {
    const auto phase = tick % period;
    return static_cast<int>(phase <= period / 2U ? phase : period - phase);
}

struct Pose { int x, y; double angle; int half_x, half_y; };
Pose pose(unsigned tick, unsigned body, unsigned seed) {
    if (body == 1U) return {54 + triangle(tick + seed * 7U, 180),
                           20 + triangle(tick * 4U, 120), double(tick) * 0.13, 9, 5};
    return {-24 + triangle(tick * 2U + seed * 3U, 96),
            36 + triangle(tick * 3U, 96), -double(tick) * 0.19, 5, 4};
}

struct Occupied { int x, y; unsigned body; };

void raster(World& world, const Pose& p, unsigned body, std::vector<Occupied>& cells) {
    const auto cosine = std::cos(p.angle), sine = std::sin(p.angle);
    const int radius = p.half_x + p.half_y + 1;
    for (int y = p.y - radius; y <= p.y + radius; ++y) {
        for (int x = p.x - radius; x <= p.x + radius; ++x) {
            if (!inside(x, y)) continue;
            const auto dx = double(x - p.x), dy = double(y - p.y);
            if (std::abs(cosine * dx + sine * dy) > p.half_x ||
                std::abs(-sine * dx + cosine * dy) > p.half_y) continue;
            if (world.set_transient_obstacle(x, y, static_cast<std::uint16_t>(body)))
                cells.push_back({x, y, body});
        }
    }
}

Result run(Mode mode, unsigned workers, unsigned substeps, unsigned seed,
           unsigned ticks, int push = 0, int by_mass = 0) {
    World world(configuration(mode, workers, substeps, seed, push, by_mass));
    fixture(world);
    Result result;
    std::uint64_t population = 0, expected = scan_water(world, population);
    // Fill both a deliberately small pool and the ordinary 4096-slot pool.
    if (mode == Mode::Hybrid) {
        // Prove both the spawn-side and donor-side pause gates before capacity
        // saturation can hide either outcome behind CapacityFull.
        world.set_simulation_region(RectI64{-128, -64, 256, 224});
        const auto before_paused_requests = world.quantity_ledger();
        require(world.launch_ballistic_water(80, 50, 160 * 256 + 128, 40 * 256 + 128,
                    0, -256, 0, 255).outcome == BallisticLaunchOutcome::Paused,
                "paused spawn was not explicitly refused");
        require(world.launch_ballistic_water(160, 50, 120 * 256 + 128, 40 * 256 + 128,
                    0, -256, 0, 255).outcome == BallisticLaunchOutcome::Paused,
                "paused donor was not explicitly refused");
        require(world.quantity_ledger() == before_paused_requests && world.ballistic_parcel_count() == 0U,
                "paused request changed ownership");
        result.metrics.paused_refusals += 2;
        world.set_simulation_region(std::nullopt);
        result.metrics.region_changes += 2;
        const auto capacity = world.config().ballistic_water.capacity;
        for (unsigned i = 0; i < capacity; ++i) {
            const auto injected = world.inject_ballistic_water(64 * 256 + 128, -48 * 256 + 128,
                static_cast<int>(i % 7U) * 64 - 192, 0, 1U + i % 17U);
            require(injected.outcome == BallisticLaunchOutcome::Launched, "pool saturation injection refused");
            expected += injected.quantity;
        }
        require(world.inject_ballistic_water(64 * 256 + 128, -48 * 256 + 128, 0, 0, 1).outcome ==
                    BallisticLaunchOutcome::CapacityFull, "full pool accepted another parcel");
        ++result.metrics.capacity_refusals;
        result.metrics.maximum_live = capacity;
    }
    check(world, expected, true);
    std::mt19937 random(seed);
    std::vector<Occupied> occupied;
    occupied.reserve(1024);
    for (unsigned t = 0; t < ticks; ++t) {
        try {
            world.clear_transient_obstacles();
            occupied.clear();
            if (t % 40U == 0U) {
                if (t % 120U == 40U) world.set_simulation_region(RectI64{-128, -64, 256, 224});
                else if (t % 120U == 80U) world.set_simulation_region(RectI64{0, -64, 192, 224});
                else world.set_simulation_region(std::nullopt);
                ++result.metrics.region_changes;
            }
            if (t % 29U == 0U) {
                int x = 80 + static_cast<int>(random() % 40U);
                int y = 42 + static_cast<int>(random() % 12U);
                const bool overfilled = t % 58U == 0U;
                if (!overfilled && world.liquid_mass(x, y) <= 1U) {
                    bool found = false;
                    for (int yy = 102; yy < 140 && !found; ++yy) {
                        for (int xx = -18; xx < -1 && !found; ++xx) {
                            if (world.liquid_mass(xx, yy) > 1U) { x = xx; y = yy; found = true; }
                        }
                    }
                    require(found, "fixture has no actual Water to drain");
                }
                const auto before = world.liquid_mass(x, y);
                const auto mass = overfilled
                    ? (before == 65535U ? std::uint16_t{65534} : std::uint16_t{65535})
                    : std::uint16_t{1};
                require(world.set_cell_state(x, y, Material::Water, mass, 0), "intended quantity edit was refused");
                require(world.liquid_mass(x, y) == mass, "quantity edit did not install its requested mass");
                require(overfilled || before > mass, "drain did not actually remove Water");
                expected = expected - before + mass;
                if (overfilled) ++result.metrics.overfill_edits;
                else ++result.metrics.drains;
                world.set_temperature(x, y, 31);
            }
            for (unsigned body = 1; body <= 2; ++body) {
                const auto now = pose(t, body, seed), prior = pose(t == 0U ? 0U : t - 1U, body, seed);
                // This is the initial reference plane, not an evolving liquid
                // surface or a measured Midge/Rapier breach.
                if (prior.y >= 50 && now.y < 50) ++result.metrics.scripted_waterline_crossings;
                // A swept occupancy union, then displacement before native tick.
                for (int step = 0; step <= 4; ++step) {
                    Pose sample = now;
                    sample.x = prior.x + (now.x - prior.x) * step / 4;
                    sample.y = prior.y + (now.y - prior.y) * step / 4;
                    sample.angle = prior.angle + (now.angle - prior.angle) * double(step) / 4.0;
                    raster(world, sample, body, occupied);
                }
            }
            require(!occupied.empty(), "body raster produced no occupied cells");
            const auto& blocked = occupied.front();
            const auto blocked_mass = world.liquid_mass(blocked.x, blocked.y);
            require(!world.set_cell_state(blocked.x, blocked.y, Material::Water, 17, 0),
                    "masked nonempty write admitted");
            require(world.liquid_mass(blocked.x, blocked.y) == blocked_mass, "masked refusal changed Water");
            ++result.metrics.masked_refusals;
            for (const auto& cell : occupied) {
                if (world.stored_material(cell.x, cell.y) != Material::Water) continue;
                const auto p = pose(t, cell.body, seed);
                const int side = cell.x < p.x ? -1 : 1;
                bool moved = false;
                for (int distance = 1; distance <= 20 && !moved; ++distance) {
                    const std::array<std::array<int, 2>, 3> candidates{{
                        {{cell.x, cell.y - distance}}, {{cell.x + side * distance, cell.y}},
                        {{cell.x - side * distance, cell.y + distance / 2}}}};
                    for (const auto& target : candidates) {
                        const auto x = target[0], y = target[1];
                        if (!inside(x, y) || world.transient_obstacle_at(x, y) != 0U ||
                            world.stored_material(x, y) != Material::Empty) continue;
                        if (mode == Mode::Hybrid && (t + cell.body) % 3U != 0U) {
                            const auto launched = world.launch_ballistic_water(cell.x, cell.y,
                                x * 256 + 128, y * 256 + 128, side * 256, -384,
                                static_cast<std::uint16_t>(cell.body), 255);
                            if (launched.outcome == BallisticLaunchOutcome::Launched) {
                                ++result.metrics.launches;
                                moved = true;
                                break;
                            }
                            if (launched.outcome == BallisticLaunchOutcome::CapacityFull)
                                ++result.metrics.capacity_refusals;
                            if (launched.outcome == BallisticLaunchOutcome::Paused)
                                ++result.metrics.paused_refusals;
                        }
                        if (world.relocate_stored_cell(cell.x, cell.y, x, y)) {
                            ++result.metrics.relocations;
                            moved = true;
                            break;
                        }
                    }
                }
            }
            (void)world.tick();
            ++result.metrics.ticks;
            result.metrics.maximum_live = std::max<std::uint64_t>(result.metrics.maximum_live, world.ballistic_parcel_count());
            require(world.ballistic_parcel_count() <= world.config().ballistic_water.capacity, "parcel capacity exceeded");
            check(world, expected, t % 24U == 0U || t + 1U == ticks);
            if (t % 40U == 39U || t + 1U == ticks) result.checkpoints.push_back(world.physical_state_hash());
        } catch (const std::exception& error) {
            throw std::runtime_error("mode=" + std::to_string(static_cast<int>(mode)) +
                " seed=" + std::to_string(seed) + " workers=" + std::to_string(workers) +
                " substeps=" + std::to_string(substeps) + " tick=" + std::to_string(t) + ": " + error.what());
        }
    }
    world.clear_transient_obstacles();
    result.checkpoints.push_back(world.physical_state_hash());
    result.ledger = world.quantity_ledger();
    require(result.metrics.scripted_waterline_crossings > 0 && result.metrics.relocations > 0,
            "fixture missed scripted waterline crossings or overlap displacement");
    require(result.metrics.overfill_edits > 0 && result.metrics.drains > 0, "fixture missed overfilled edits or drains");
    if (mode == Mode::Hybrid) {
        require(result.metrics.launches > 0, "fixture missed body-sourced ballistic launch");
        require(result.metrics.paused_refusals >= 2U, "fixture missed explicit paused launch refusals");
    }
    return result;
}
} // namespace

int main(int argc, char** argv) {
    unsigned seeds = 2, ticks = 120;
    for (int i = 1; i < argc; i += 2) {
        if (i + 1 == argc) { std::fprintf(stderr, "usage: test_wave_body_boundary [--seeds 1..16] [--ticks 120..2400]\n"); return 2; }
        const auto value = std::string(argv[i + 1]);
        if (value.empty() || value.find_first_not_of("0123456789") != std::string::npos || value.size() > 4U) return 2;
        const auto number = static_cast<unsigned>(std::stoul(value));
        if (std::string(argv[i]) == "--seeds" && number >= 1U && number <= 16U) seeds = number;
        else if (std::string(argv[i]) == "--ticks" && number >= 120U && number <= 2400U) ticks = number;
        else { std::fprintf(stderr, "unsupported stress argument\n"); return 2; }
    }
    Metrics total;
    unsigned runs = 0;
    try {
        for (unsigned seed = 0; seed < seeds; ++seed) {
            for (const auto mode : {Mode::Original, Mode::Spill, Mode::Hybrid}) {
                for (const auto substeps : {1U, 3U}) {
                    const auto serial = run(mode, 1, substeps, seed, ticks);
                    total.add(serial.metrics); ++runs;
                    for (const auto workers : {2U, 4U, 6U}) {
                        const auto parallel = run(mode, workers, substeps, seed, ticks);
                        require(serial.checkpoints == parallel.checkpoints && serial.ledger == parallel.ledger,
                            "worker parity differs: mode=" + std::to_string(static_cast<int>(mode)) +
                            " seed=" + std::to_string(seed) + " workers=" + std::to_string(workers) +
                            " substeps=" + std::to_string(substeps));
                        total.add(parallel.metrics); ++runs;
                    }
                    std::printf("PASS boundary mode=%u seed=%u substeps=%u workers=1,2,4,6 ticks=%u\n",
                                static_cast<unsigned>(mode), seed, substeps, ticks);
                    std::fflush(stdout);
                }
            }
        }
        // Prescribed body paths isolate the observation-only push setting from
        // Rapier's response. The native Water trajectory must remain identical.
        const auto zero = run(Mode::Hybrid, 1, 8, 0, 120);
        const auto scaled = run(Mode::Hybrid, 6, 8, 0, 120, 1024, 1);
        require(zero.checkpoints == scaled.checkpoints && zero.ledger == scaled.ledger,
                "body push changed prescribed-path Water state at eight substeps");
        total.add(zero.metrics); total.add(scaled.metrics); runs += 2;
        std::printf("PASS push-observation-only substeps=8 workers=1,6 push=0,1024 by_mass=0,1\n");
    } catch (const std::exception& error) {
        std::printf("FAIL WAVE_BODY_BOUNDARY: %s\n", error.what());
        return 1;
    }
    std::printf("WAVE_BODY_BOUNDARY: seeds=%u runs=%u ticks=%llu scripted_waterline_crossings=%llu relocations=%llu launches=%llu "
                "masked_refusals=%llu capacity_refusals=%llu paused_refusals=%llu region_changes=%llu "
                "overfill_edits=%llu drains=%llu maximum_live=%llu parity=checkpoints failures=0\n",
        seeds, runs, static_cast<unsigned long long>(total.ticks), static_cast<unsigned long long>(total.scripted_waterline_crossings),
        static_cast<unsigned long long>(total.relocations), static_cast<unsigned long long>(total.launches),
        static_cast<unsigned long long>(total.masked_refusals), static_cast<unsigned long long>(total.capacity_refusals),
        static_cast<unsigned long long>(total.paused_refusals), static_cast<unsigned long long>(total.region_changes),
        static_cast<unsigned long long>(total.overfill_edits), static_cast<unsigned long long>(total.drains),
        static_cast<unsigned long long>(total.maximum_live));
    return 0;
}
