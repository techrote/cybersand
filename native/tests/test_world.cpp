#include "cybersand/c_api.h"
#include "cybersand/material_appearance.hpp"
#include "cybersand/material_rules.hpp"
#include "cybersand/render_snapshot.hpp"
#include "cybersand/scheduler_geometry.hpp"
#include "cybersand/world.hpp"

#include <algorithm>
#include <atomic>
#include <cstdint>
#include <exception>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string_view>
#include <thread>
#include <vector>

namespace {

using cybersand::Material;
using cybersand::World;
using cybersand::WorldConfig;

void require(bool condition, std::string_view message) {
    if (!condition) throw std::runtime_error(std::string(message));
}

void add_floor(World& world, std::int64_t y, std::int64_t left, std::int64_t right) {
    for (auto x = left; x <= right; ++x) world.set(x, y, Material::Wall);
}

void populate_deterministic_scene(World& world);

std::uint64_t total_liquid(const World& world, std::int64_t left, std::int64_t top,
                           std::int64_t right, std::int64_t bottom) {
    std::uint64_t result = 0;
    for (auto y = top; y <= bottom; ++y) {
        for (auto x = left; x <= right; ++x) result += world.liquid_mass(x, y);
    }
    return result;
}

void populate_water_fixture(World& world) {
    add_floor(world, 24, 0, 20);
    for (std::int64_t y = 4; y <= 24; ++y) {
        world.set(0, y, Material::Wall);
        world.set(20, y, Material::Wall);
    }
    for (std::int64_t y = 6; y < 14; ++y) {
        for (std::int64_t x = 2; x < 8; ++x) world.set(x, y, Material::Water);
    }
}

void test_negative_coordinates() {
    World world({16, 3, 200});
    world.set(-1, -1, Material::Wall);
    world.set(-17, -33, Material::Sand);
    require(world.get(-1, -1) == Material::Wall, "negative coordinate lookup failed");
    require(world.get(-17, -33) == Material::Sand, "negative multi-chunk lookup failed");
    require(world.chunk_count() == 2, "unexpected negative-coordinate chunk count");
}

void test_scheduler_geometry() {
    const cybersand::SchedulerGeometry geometry(64, 32);
    require(geometry.core_for_cell(0, 0) == cybersand::SchedulingCoreCoord{0, 0},
            "origin core mapping failed");
    require(geometry.core_for_cell(63, 63) == cybersand::SchedulingCoreCoord{0, 0},
            "positive core edge mapping failed");
    require(geometry.core_for_cell(64, 64) == cybersand::SchedulingCoreCoord{1, 1},
            "positive next-core mapping failed");
    require(geometry.core_for_cell(-1, -1) == cybersand::SchedulingCoreCoord{-1, -1},
            "negative floor mapping failed");
    require(geometry.core_for_cell(-64, -64) == cybersand::SchedulingCoreCoord{-1, -1},
            "negative exact-edge mapping failed");
    require(geometry.core_for_cell(-65, -65) == cybersand::SchedulingCoreCoord{-2, -2},
            "negative previous-core mapping failed");

    std::vector<cybersand::SchedulingCoreCoord> cores;
    for (std::int64_t y = -8; y <= 8; ++y) {
        for (std::int64_t x = -8; x <= 8; ++x) cores.push_back({x, y});
    }
    for (std::uint8_t phase = 0; phase < cybersand::SchedulerGeometry::kPhaseCount; ++phase) {
        require(geometry.validate_non_overlapping_phase(cores, phase),
                "same-phase scheduler write domains overlap");
    }

    require(!geometry.same_phase_domains_overlap({0, 0}, {2, 0}),
            "half-core expansion incorrectly overlaps horizontal peer");
    require(!geometry.same_phase_domains_overlap({0, 0}, {0, 2}),
            "half-core expansion incorrectly overlaps vertical peer");
    require(!geometry.same_phase_domains_overlap({0, 0}, {2, 2}),
            "half-core expansion incorrectly overlaps diagonal peer");
    require(geometry.same_phase_domains_overlap({0, 0}, {0, 0}),
            "duplicate scheduling core was not detected");

    bool rejected_oversized_radius = false;
    try {
        (void)cybersand::SchedulerGeometry(64, 33);
    } catch (const std::invalid_argument&) {
        rejected_oversized_radius = true;
    }
    require(rejected_oversized_radius, "unsafe write radius was accepted");
}

void test_sand_falls_and_stops() {
    World world({16, 3, 200});
    add_floor(world, 6, -3, 3);
    world.set(0, 0, Material::Sand);
    for (int tick = 0; tick < 12; ++tick) (void)world.tick();
    require(world.get(0, 5) == Material::Sand, "sand did not settle on floor");
    require(world.get(0, 0) == Material::Empty, "sand source was not emptied");
}

void test_cross_chunk_fall() {
    World world({8, 3, 200});
    add_floor(world, 10, 0, 7);
    world.set(3, 6, Material::Sand);
    for (int tick = 0; tick < 8; ++tick) (void)world.tick();
    require(world.get(3, 9) == Material::Sand, "sand failed to cross a chunk boundary");
    require(world.chunk_count() >= 2, "cross-boundary move did not create destination chunk");
}

void test_cross_scheduler_core_fall() {
    WorldConfig config{};
    config.chunk_size = 128;
    config.backend = cybersand::SimulationBackend::PhasedInPlace;
    World world(config);
    add_floor(world, 70, 4, 10);
    world.set(7, 63, Material::Sand);

    const auto first = world.tick();
    require(first.scheduled_cores >= 2, "scheduler boundary neighbours were not planned");
    require(world.get(7, 64) == Material::Sand,
            "sand failed to cross a 64-cell scheduler-core boundary");
    require(world.get(7, 65) == Material::Empty,
            "cross-core cell was processed twice in one tick");

    for (int tick = 0; tick < 8; ++tick) (void)world.tick();
    require(world.get(7, 69) == Material::Sand,
            "sand did not settle after crossing a scheduler-core boundary");
}

void test_activity_core_sleep_and_wake() {
    WorldConfig config{};
    config.chunk_size = 128;
    config.sleep_after_quiet_ticks = 2;
    config.backend = cybersand::SimulationBackend::PhasedInPlace;
    World world(config);
    add_floor(world, 20, 0, 20);
    world.set(10, 19, Material::Sand);
    cybersand::TickStats stats{};
    for (int tick = 0; tick < 8; ++tick) stats = world.tick();
    require(stats.scheduled_cores == 0, "settled activity blocks continued scheduling cores");
    require(world.active_chunk_count() == 0, "settled activity blocks kept their chunk active");

    world.set(10, 18, Material::Sand);
    require(world.active_chunk_count() == 1, "edit failed to wake its activity block");
    stats = world.tick();
    require(stats.scheduled_cores == 1, "woken local activity scheduled an unexpected core count");
}

void test_serial_and_phased_behavioral_parity() {
    WorldConfig serial_config{};
    serial_config.chunk_size = 128;
    serial_config.backend = cybersand::SimulationBackend::SerialInPlace;
    WorldConfig phased_config = serial_config;
    phased_config.backend = cybersand::SimulationBackend::PhasedInPlace;
    World serial(serial_config);
    World phased(phased_config);
    populate_deterministic_scene(serial);
    populate_deterministic_scene(phased);
    for (int tick = 0; tick < 80; ++tick) {
        (void)serial.tick();
        (void)phased.tick();
    }

    std::uint64_t serial_counts[5]{};
    std::uint64_t phased_counts[5]{};
    for (std::int64_t y = -8; y <= 48; ++y) {
        for (std::int64_t x = -40; x <= 48; ++x) {
            const auto serial_id = static_cast<std::uint8_t>(serial.get(x, y));
            const auto phased_id = static_cast<std::uint8_t>(phased.get(x, y));
            if (serial_id <= static_cast<std::uint8_t>(Material::Smoke)) ++serial_counts[serial_id];
            if (phased_id <= static_cast<std::uint8_t>(Material::Smoke)) ++phased_counts[phased_id];
        }
    }
    for (std::size_t material = 0; material < 5; ++material) {
        require(serial_counts[material] == phased_counts[material],
                "serial and phased backends changed material totals");
    }
}

void test_sand_sinks_through_water() {
    World world({16, 3, 200});
    add_floor(world, 5, -2, 2);
    world.set(-1, 4, Material::Wall);
    world.set(1, 4, Material::Wall);
    world.set(0, 4, Material::Water);
    world.set(0, 3, Material::Sand);
    (void)world.tick();
    require(world.get(0, 4) == Material::Sand, "denser sand did not swap with water");
    require(world.get(0, 3) == Material::Water, "water was not displaced upward");
}

void test_conserved_water_levels_and_sleeps() {
    WorldConfig config{};
    config.chunk_size = 128;
    config.sleep_after_quiet_ticks = 3;
    config.backend = cybersand::SimulationBackend::PhasedInPlace;
    config.worker_threads = 4;
    World world(config);
    populate_water_fixture(world);
    const auto initial_mass = total_liquid(world, 0, 0, 20, 24);
    require(initial_mass == 48U * 255U, "water fixture has unexpected initial mass");

    auto previous_hash = world.content_hash();
    int stable_ticks = 0;
    int settled_at = -1;
    for (int tick = 0; tick < 2'000; ++tick) {
        (void)world.tick();
        require(total_liquid(world, 0, 0, 20, 24) == initial_mass,
                "fixed-point water mass was not conserved");
        const auto current_hash = world.content_hash();
        stable_ticks = current_hash == previous_hash ? stable_ticks + 1 : 0;
        previous_hash = current_hash;
        if (stable_ticks >= 40) {
            settled_at = tick + 1;
            break;
        }
    }
    require(settled_at >= 0, "water failed to settle within the fixture limit");
    std::cout << "[info] water settled after " << settled_at << " ticks\n";
    bool reached_far_side = false;
    for (std::int64_t y = 4; y < 24; ++y) {
        for (std::int64_t x = 14; x < 20; ++x) {
            reached_far_side = reached_far_side || world.liquid_mass(x, y) != 0;
        }
    }
    require(reached_far_side, "water remained in a sand-like heap");

    const auto settled_hash = previous_hash;
    for (int tick = 0; tick < 40; ++tick) {
        (void)world.tick();
        require(total_liquid(world, 0, 0, 20, 24) == initial_mass,
                "settled water lost mass");
    }
    require(world.content_hash() == settled_hash, "settled water continued changing");
    require(world.active_chunk_count() == 0, "settled water did not sleep");
}

void test_water_surface_column_mass_is_level() {
    WorldConfig config{};
    config.sleep_after_quiet_ticks = 3;
    config.backend = cybersand::SimulationBackend::PhasedInPlace;
    config.worker_threads = 4;
    World world(config);
    add_floor(world, 12, 0, 12);
    for (std::int64_t y = 0; y <= 12; ++y) {
        world.set(0, y, Material::Wall);
        world.set(12, y, Material::Wall);
    }
    for (std::int64_t y = 3; y <= 7; ++y) {
        for (std::int64_t x = 5; x <= 7; ++x) world.set(x, y, Material::Water);
    }

    const auto initial_mass = total_liquid(world, 1, 0, 11, 11);
    auto previous_hash = world.content_hash();
    int stable_ticks = 0;
    for (int tick = 0; tick < 2'000 && stable_ticks < 40; ++tick) {
        (void)world.tick();
        require(total_liquid(world, 1, 0, 11, 11) == initial_mass,
                "level-surface fixture lost Water mass");
        const auto current_hash = world.content_hash();
        stable_ticks = current_hash == previous_hash ? stable_ticks + 1 : 0;
        previous_hash = current_hash;
    }
    require(stable_ticks >= 40, "level-surface fixture did not settle");

    std::uint64_t minimum_column_mass = std::numeric_limits<std::uint64_t>::max();
    std::uint64_t maximum_column_mass = 0;
    for (std::int64_t x = 1; x <= 11; ++x) {
        const auto column_mass = total_liquid(world, x, 0, x, 11);
        minimum_column_mass = std::min(minimum_column_mass, column_mass);
        maximum_column_mass = std::max(maximum_column_mass, column_mass);
    }
    // Pairwise integer flux may leave a sub-pixel residual gradient. Keep it
    // below 1/32 of a cell so it cannot form an authoritative or visible heap.
    require(maximum_column_mass - minimum_column_mass <= 8U,
            "free Water settled with a heap-shaped column-mass gradient");
}

void test_water_single_multiworker_parity() {
    WorldConfig single_config{};
    single_config.chunk_size = 128;
    single_config.backend = cybersand::SimulationBackend::PhasedInPlace;
    single_config.worker_threads = 1;
    WorldConfig multi_config = single_config;
    multi_config.worker_threads = 4;
    World single(single_config);
    World multi(multi_config);
    populate_water_fixture(single);
    populate_water_fixture(multi);
    for (int tick = 0; tick < 180; ++tick) {
        (void)single.tick();
        (void)multi.tick();
        require(single.state_hash() == multi.state_hash(),
                "single/multiworker fixed-point water diverged");
    }
}

void test_water_conserves_across_storage_boundaries() {
    WorldConfig config{};
    config.backend = cybersand::SimulationBackend::PhasedInPlace;
    config.worker_threads = 4;
    World world(config);
    add_floor(world, 136, 124, 132);
    for (std::int64_t y = 116; y <= 136; ++y) {
        world.set(124, y, Material::Wall);
        world.set(132, y, Material::Wall);
    }
    for (std::int64_t y = 118; y <= 124; ++y) {
        for (std::int64_t x = 126; x <= 130; ++x) world.set(x, y, Material::Water);
    }
    const auto initial = total_liquid(world, 124, 116, 132, 136);
    for (int tick = 0; tick < 500; ++tick) {
        (void)world.tick();
        require(total_liquid(world, 124, 116, 132, 136) == initial,
                "Water lost mass across a 128-cell storage boundary");
    }
    require(world.get(128, 135) == Material::Water,
            "Water failed to occupy the chunk across the storage boundary");
}

void test_optional_temperature_moves_across_chunk() {
    WorldConfig config{};
    config.chunk_size = 128;
    config.backend = cybersand::SimulationBackend::PhasedInPlace;
    config.worker_threads = 4;
    World world(config);
    add_floor(world, 130, 120, 134);
    world.set(127, 127, Material::Sand);
    const auto bytes_before_temperature = world.resident_cell_bytes();
    world.set_temperature(127, 127, 777);
    require(world.resident_cell_bytes() > bytes_before_temperature,
            "temperature field was not allocated on demand");
    (void)world.tick();
    require(world.get(127, 128) == Material::Sand, "heated sand failed to cross chunk boundary");
    require(world.temperature(127, 128) == 777, "optional temperature did not follow moving cell");
    require(world.temperature(127, 127) == config.ambient_temperature,
            "vacated cell retained moved temperature");
}

void test_preallocated_tick_has_no_owned_allocations() {
    WorldConfig config{};
    config.backend = cybersand::SimulationBackend::PhasedInPlace;
    config.worker_threads = 4;
    config.maximum_chunk_count = 64;
    config.active_chunk_capacity = 64;
    World world(config);
    world.reserve_temperature_region({-2, -2, 260, 260});
    add_floor(world, 132, 120, 136);
    world.set(127, 127, Material::Sand);
    world.set_temperature(127, 127, 777);
    const auto stats = world.tick();
    require(stats.chunk_allocations == 0,
            "preallocated tick lazily allocated a chunk in the hot path");
    require(stats.temperature_field_allocations == 0,
            "preallocated tick lazily allocated a temperature field in the hot path");
}

void test_chunk_capacity_fails_explicitly() {
    WorldConfig config{};
    config.initial_chunk_reserve = 1;
    config.maximum_chunk_count = 1;
    config.active_chunk_capacity = 1;
    World world(config);
    world.set(0, 0, Material::Wall);
    bool exhausted = false;
    try {
        world.set(config.chunk_size, 0, Material::Wall);
    } catch (const std::runtime_error&) {
        exhausted = true;
    }
    require(exhausted, "maximum chunk capacity silently grew");
    require(world.chunk_count() == 1, "failed capacity check partially inserted a chunk");
}

void test_smoke_rises() {
    World world({16, 3, 200});
    world.set(2, 5, Material::Smoke);
    (void)world.tick();
    require(world.get(2, 4) == Material::Smoke, "smoke did not rise");
}

void test_smoke_buoyantly_displaces_water_and_sand() {
    const auto exercise_pair = [](Material upper_material) {
        World world({16, 3, 200});
        for (std::int64_t y = 0; y <= 3; ++y) {
            world.set(-1, y, Material::Wall);
            world.set(1, y, Material::Wall);
        }
        world.set(0, 1, upper_material);
        world.set(0, 2, Material::Smoke);
        const auto water_before = total_liquid(world, 0, 0, 0, 3);
        (void)world.tick();
        require(world.get(0, 1) == Material::Smoke,
                "Smoke did not exchange upward through a denser material");
        require(world.get(0, 2) == upper_material,
                "density exchange did not move the denser material downward");
        require(total_liquid(world, 0, 0, 0, 3) == water_before,
                "Smoke/Water density exchange changed conserved liquid mass");
    };

    exercise_pair(Material::Water);
    exercise_pair(Material::Sand);

    World blocked({16, 3, 200});
    blocked.set(0, 1, Material::Wall);
    blocked.set(0, 2, Material::Smoke);
    (void)blocked.tick();
    require(blocked.get(0, 1) == Material::Wall,
            "opted-out static material accepted a density exchange");

    WorldConfig volume_config{};
    volume_config.backend = cybersand::SimulationBackend::PhasedInPlace;
    volume_config.worker_threads = 4;
    World volume(volume_config);
    add_floor(volume, 32, 0, 4);
    for (std::int64_t y = 10; y <= 32; ++y) {
        volume.set(0, y, Material::Wall);
        volume.set(4, y, Material::Wall);
    }
    for (std::int64_t y = 25; y <= 27; ++y) {
        for (std::int64_t x = 1; x <= 3; ++x) volume.set(x, y, Material::Water);
    }
    for (std::int64_t y = 28; y <= 30; ++y) {
        for (std::int64_t x = 1; x <= 3; ++x) volume.set(x, y, Material::Smoke);
    }
    const auto volume_water_mass = total_liquid(volume, 1, 10, 3, 31);
    for (int tick = 0; tick < 16; ++tick) (void)volume.tick();

    std::size_t smoke_count = 0;
    std::int64_t deepest_smoke = std::numeric_limits<std::int64_t>::min();
    std::int64_t shallowest_water = std::numeric_limits<std::int64_t>::max();
    for (std::int64_t y = 10; y <= 31; ++y) {
        for (std::int64_t x = 1; x <= 3; ++x) {
            if (volume.get(x, y) == Material::Smoke) {
                ++smoke_count;
                deepest_smoke = std::max(deepest_smoke, y);
            }
            if (volume.liquid_mass(x, y) != 0U) {
                shallowest_water = std::min(shallowest_water, y);
            }
        }
    }
    require(smoke_count == 9, "Smoke volume was lost during buoyant displacement");
    require(total_liquid(volume, 1, 10, 3, 31) == volume_water_mass,
            "Water volume changed while Smoke bubbled through it");
    require(deepest_smoke < shallowest_water,
            "Water remained supported on a trapped Smoke volume");

    World sand_volume(volume_config);
    add_floor(sand_volume, 32, 0, 4);
    for (std::int64_t y = 10; y <= 32; ++y) {
        sand_volume.set(0, y, Material::Wall);
        sand_volume.set(4, y, Material::Wall);
    }
    for (std::int64_t y = 25; y <= 27; ++y) {
        for (std::int64_t x = 1; x <= 3; ++x) sand_volume.set(x, y, Material::Sand);
    }
    for (std::int64_t y = 28; y <= 30; ++y) {
        for (std::int64_t x = 1; x <= 3; ++x) sand_volume.set(x, y, Material::Smoke);
    }
    for (int tick = 0; tick < 16; ++tick) (void)sand_volume.tick();

    smoke_count = 0;
    std::size_t sand_count = 0;
    deepest_smoke = std::numeric_limits<std::int64_t>::min();
    std::int64_t shallowest_sand = std::numeric_limits<std::int64_t>::max();
    for (std::int64_t y = 10; y <= 31; ++y) {
        for (std::int64_t x = 1; x <= 3; ++x) {
            if (sand_volume.get(x, y) == Material::Smoke) {
                ++smoke_count;
                deepest_smoke = std::max(deepest_smoke, y);
            }
            if (sand_volume.get(x, y) == Material::Sand) {
                ++sand_count;
                shallowest_sand = std::min(shallowest_sand, y);
            }
        }
    }
    require(smoke_count == 9 && sand_count == 9,
            "Sand/Smoke volume exchange changed material counts");
    require(deepest_smoke < shallowest_sand,
            "Sand remained supported on a trapped Smoke volume");
}

void test_smoke_lifetime_culling_and_fire_exclusion() {
    World lifetimes({16, 3, 200});
    for (const auto centre_x : {std::int64_t{0}, std::int64_t{4}}) {
        for (std::int64_t y = -1; y <= 1; ++y) {
            for (std::int64_t x = centre_x - 1; x <= centre_x + 1; ++x) {
                lifetimes.set(x, y, Material::Wall);
            }
        }
    }
    lifetimes.set(0, 0, Material::Foam);
    lifetimes.set(4, 0, Material::Smoke);
    require(lifetimes.stored_state_a(4, 0) == 240U,
            "Smoke did not receive its bounded initial lifetime");
    for (int tick = 0; tick < 150; ++tick) (void)lifetimes.tick();
    require(lifetimes.get(0, 0) == Material::Empty,
            "Foam did not complete its short collapse lifecycle");
    require(lifetimes.get(4, 0) == Material::Smoke,
            "Smoke did not outlive the short Foam lifecycle");
    for (int tick = 150; tick < 2'100; ++tick) (void)lifetimes.tick();
    require(lifetimes.get(4, 0) == Material::Empty,
            "Smoke did not eventually self-cull");

    World no_host({16, 3, 200});
    for (std::int64_t y = -1; y <= 1; ++y) {
        for (std::int64_t x = -1; x <= 2; ++x) no_host.set(x, y, Material::Wall);
    }
    no_host.set(0, 0, Material::Smoke);
    no_host.set(1, 0, Material::Fire);
    for (int tick = 0; tick < 180; ++tick) (void)no_host.tick();
    require(no_host.get(0, 0) == Material::Smoke,
            "Smoke incorrectly hosted or became Fire");
}

void test_fire_combustion_and_extinguishing() {
    World extinguish({16, 3, 200});
    for (std::int64_t y = -1; y <= 1; ++y) {
        for (std::int64_t x = -1; x <= 2; ++x) {
            if (x != 0 || y != 0) extinguish.set(x, y, Material::Wall);
        }
    }
    extinguish.set(0, 0, Material::Fire);
    extinguish.set(1, 0, Material::Water);
    for (int tick = 0; tick < 8 && extinguish.get(1, 0) != Material::Steam; ++tick) {
        (void)extinguish.tick();
    }
    require(extinguish.get(0, 0) == Material::Smoke,
            "water did not extinguish adjacent fire");
    require(extinguish.get(1, 0) == Material::Steam,
            "extinguishing fire did not turn adjacent water into steam");

    World burn({16, 3, 200});
    burn.set(0, 0, Material::Fire);
    for (std::int64_t y = -1; y <= 1; ++y) {
        for (std::int64_t x = -1; x <= 1; ++x) {
            if (x != 0 || y != 0) burn.set(x, y, Material::Wood);
        }
    }
    for (int tick = 0; tick < 60; ++tick) (void)burn.tick();
    bool wood_consumed_early = false;
    for (std::int64_t y = -1; y <= 1; ++y) {
        for (std::int64_t x = -1; x <= 1; ++x) {
            if (x == 0 && y == 0) continue;
            wood_consumed_early = wood_consumed_early ||
                                  burn.get(x, y) != Material::Wood;
        }
    }
    require(!wood_consumed_early,
            "slow Fire chemistry consumed Wood during its first second");

    for (int tick = 60; tick < 600; ++tick) (void)burn.tick();
    bool wood_consumed = false;
    for (std::int64_t y = -1; y <= 1; ++y) {
        for (std::int64_t x = -1; x <= 1; ++x) {
            wood_consumed = wood_consumed || burn.get(x, y) != Material::Wood;
        }
    }
    require(wood_consumed, "fire failed to ignite and consume wood");
}

void test_lava_ice_dust_and_oil_reactions() {
    World lava_water({16, 3, 200});
    for (std::int64_t y = -1; y <= 1; ++y) {
        for (std::int64_t x = -1; x <= 2; ++x) lava_water.set(x, y, Material::Wall);
    }
    lava_water.set(0, 0, Material::Lava);
    lava_water.set(1, 0, Material::Water);
    for (int tick = 0; tick < 8 && lava_water.get(1, 0) != Material::Steam; ++tick) {
        (void)lava_water.tick();
    }
    require(lava_water.get(0, 0) == Material::Stone,
            "lava touching water did not become stone");
    require(lava_water.get(1, 0) == Material::Steam,
            "lava touching water did not emit steam");

    World melt({16, 3, 200});
    for (std::int64_t y = -1; y <= 1; ++y) {
        for (std::int64_t x = -1; x <= 2; ++x) melt.set(x, y, Material::Wall);
    }
    melt.set(0, 0, Material::Fire);
    melt.set(1, 0, Material::Ice);
    for (int tick = 0; tick < 16 && melt.get(1, 0) != Material::Steam; ++tick) {
        (void)melt.tick();
    }
    require(melt.get(1, 0) == Material::Steam,
            "fire failed to melt and immediately vaporize ice");

    World dust({16, 3, 200});
    for (std::int64_t y = -1; y <= 1; ++y) {
        for (std::int64_t x = -1; x <= 2; ++x) dust.set(x, y, Material::Wall);
    }
    dust.set(0, 0, Material::Fire);
    dust.set(1, 0, Material::Dust);
    for (int tick = 0; tick < 8 && dust.get(1, 0) != Material::Fire; ++tick) {
        (void)dust.tick();
    }
    require(dust.get(1, 0) == Material::Fire, "hot material failed to ignite dust");

    World oil({16, 3, 200});
    for (std::int64_t y = -1; y <= 1; ++y) {
        for (std::int64_t x = -1; x <= 2; ++x) oil.set(x, y, Material::Wall);
    }
    oil.set(0, 0, Material::Fire);
    oil.set(1, 0, Material::Oil);
    for (int tick = 0; tick < 220; ++tick) (void)oil.tick();
    require(oil.get(1, 0) != Material::Oil,
            "ignited oil did not finish its burn countdown");
}

void test_acid_corrosion_and_stone_collapse() {
    World acid({16, 3, 200});
    for (std::int64_t y = -1; y <= 1; ++y) {
        for (std::int64_t x = -1; x <= 1; ++x) acid.set(x, y, Material::Sand);
    }
    acid.set(0, 0, Material::Acid);
    for (int tick = 0; tick < 4; ++tick) (void)acid.tick();
    std::size_t remaining_sand = 0;
    for (std::int64_t y = -1; y <= 1; ++y) {
        for (std::int64_t x = -1; x <= 1; ++x) {
            if (acid.get(x, y) == Material::Sand) ++remaining_sand;
        }
    }
    require(remaining_sand < 8, "trapped acid did not corrode a neighboring material");

    World stone({16, 3, 200});
    add_floor(stone, 6, -2, 2);
    stone.set(0, 0, Material::Stone);
    for (int tick = 0; tick < 10; ++tick) (void)stone.tick();
    require(stone.get(0, 5) == Material::Stone, "collapsible stone failed to fall");
}

void test_water_displaces_oil() {
    World world({16, 3, 200});
    add_floor(world, 4, -1, 1);
    world.set(-1, 3, Material::Wall);
    world.set(1, 3, Material::Wall);
    world.set(0, 3, Material::Oil);
    world.set(0, 2, Material::Water);
    (void)world.tick();
    require(world.get(0, 3) == Material::Water, "water did not sink through lighter oil");
    require(world.get(0, 2) == Material::Oil, "oil was not displaced upward by water");
}

void test_cloner_captures_and_emits() {
    World world({16, 3, 200});
    for (std::int64_t y = -1; y <= 1; ++y) {
        for (std::int64_t x = -1; x <= 2; ++x) world.set(x, y, Material::Wall);
    }
    world.set(0, 0, Material::Cloner);
    world.set(1, 0, Material::Sand);
    world.set(-1, 0, Material::Empty);
    bool emitted = false;
    for (int tick = 0; tick < 12; ++tick) {
        (void)world.tick();
        emitted = emitted || world.get(-1, 0) == Material::Sand;
    }
    require(emitted,
            "cloner failed to capture and emit a neighboring material");
}

std::size_t count_material(const World& world, Material material, std::int64_t left,
                           std::int64_t top, std::int64_t right, std::int64_t bottom) {
    std::size_t count = 0;
    for (auto y = top; y <= bottom; ++y) {
        for (auto x = left; x <= right; ++x) {
            if (world.get(x, y) == material) ++count;
        }
    }
    return count;
}

void add_wall_square(World& world, std::int64_t centre_x, std::int64_t centre_y,
                     std::int64_t radius) {
    for (auto y = centre_y - radius; y <= centre_y + radius; ++y) {
        for (auto x = centre_x - radius; x <= centre_x + radius; ++x) {
            world.set(x, y, Material::Wall);
        }
    }
}

void test_deferred_explosion_and_event_capacity() {
    WorldConfig config{};
    config.deferred_event_capacity = 1;
    config.maximum_explosion_radius = 8;
    World world(config);
    add_wall_square(world, 0, 0, 4);

    auto different_capacity_config = config;
    different_capacity_config.deferred_event_capacity = 2;
    World different_capacity(different_capacity_config);
    add_wall_square(different_capacity, 0, 0, 4);
    require(world.state_hash() != different_capacity.state_hash(),
            "replay state hash omitted an authoritative event-capacity setting");

    require(!world.queue_explosion(0, 0, 0, 255),
            "explosion queue accepted a zero radius");
    require(!world.queue_explosion(0, 0, 9, 255),
            "explosion queue accepted an over-limit radius");
    require(!world.queue_explosion(std::numeric_limits<std::int64_t>::max(), 0, 2, 255),
            "explosion queue accepted a coordinate whose bounded writes overflow");
    const auto hash_before_queue = world.state_hash();
    require(world.queue_explosion(0, 0, 2, 255),
            "valid bounded explosion was rejected");
    require(world.state_hash() != hash_before_queue,
            "replay state hash omitted a queued gameplay event");
    require(!world.queue_explosion(32, 0, 2, 255),
            "deferred event queue silently exceeded configured capacity");

    const auto stats = world.tick();
    require(stats.deferred_events == 1,
            "tick statistics did not report the committed gameplay event");
    require(stats.chunk_allocations == 0,
            "bounded explosion allocated a previously absent chunk during the tick");
    require(world.get(0, 0) == Material::Fire,
            "explosion did not emit its bounded fire centre");
    require(world.get(1, 0) == Material::Empty,
            "explosion did not clear material inside its core radius");
    require(count_material(world, Material::Stone, -4, -4, 4, 4) > 0,
            "explosion did not convert eligible static terrain into collapsible stone");

    for (int tick = 0; tick < 4; ++tick) (void)world.tick();
    require(count_material(world, Material::Stone, -4, 5, 4, 12) > 0,
            "event-converted terrain never entered the falling-material solver");
}

void populate_explosion_fixture(World& world) {
    for (std::int64_t centre_x : {32, 160, 288, 416}) {
        add_wall_square(world, centre_x, 32, 4);
        require(world.queue_explosion(centre_x, 32, 2, 255),
                "failed to queue deterministic explosion fixture");
    }
}

void test_explosion_single_multiworker_parity() {
    WorldConfig single_config{};
    single_config.worker_threads = 1;
    single_config.parallel_job_threshold = 1;
    WorldConfig multi_config = single_config;
    multi_config.worker_threads = 4;
    World single(single_config);
    World multi(multi_config);
    populate_explosion_fixture(single);
    populate_explosion_fixture(multi);

    for (int tick = 0; tick < 12; ++tick) {
        const auto single_stats = single.tick();
        const auto multi_stats = multi.tick();
        require(single_stats.deferred_events == multi_stats.deferred_events,
                "gameplay event counts diverged across worker counts");
        require(single.state_hash() == multi.state_hash(),
                "event-driven terrain collapse diverged across worker counts");
    }
}

void test_growth_and_seed_germination() {
    World plant({32, 3, 200});
    plant.set(0, 0, Material::Plant);
    for (int tick = 0; tick < 10; ++tick) (void)plant.tick();
    require(count_material(plant, Material::Plant, -8, -8, 8, 8) > 1,
            "plant growth energy produced no bounded growth");

    World fungus({32, 3, 200});
    fungus.set(0, 0, Material::Fungus);
    fungus.set(0, 1, Material::Wood);
    for (int tick = 0; tick < 10; ++tick) (void)fungus.tick();
    require(count_material(fungus, Material::Fungus, -8, -8, 8, 8) > 1,
            "fungus failed to colonize local substrate");

    World seed({32, 3, 200});
    add_floor(seed, 4, -3, 3);
    seed.set(0, 3, Material::Sand);
    seed.set(0, 2, Material::Seed);
    for (int tick = 0; tick < 16; ++tick) (void)seed.tick();
    require(count_material(seed, Material::Plant, -4, -4, 4, 3) > 0,
            "supported seed failed to germinate into plant");
}

void test_mite_agent_and_rocket_payload() {
    World mite({32, 3, 200});
    add_floor(mite, 3, -3, 3);
    mite.set(0, 2, Material::Mite);
    mite.set(1, 2, Material::Plant);
    for (int tick = 0; tick < 4 && mite.get(1, 2) != Material::Mite; ++tick) {
        (void)mite.tick();
    }
    require(mite.get(1, 2) == Material::Mite, "mite failed to consume adjacent plant");

    World hazard({32, 3, 200});
    for (std::int64_t y = -1; y <= 1; ++y) {
        for (std::int64_t x = -1; x <= 2; ++x) hazard.set(x, y, Material::Wall);
    }
    hazard.set(0, 0, Material::Mite);
    hazard.set(1, 0, Material::Water);
    (void)hazard.tick();
    require(hazard.get(0, 0) == Material::Empty, "water failed to kill adjacent mite");

    World rocket({32, 3, 200});
    rocket.set(0, 0, Material::Rocket);
    rocket.set_temperature(0, 0, 1'000);
    (void)rocket.tick();
    (void)rocket.tick();
    require(rocket.get(0, 0) == Material::Sand,
            "launched rocket did not deposit its captured/default payload");
    require(count_material(rocket, Material::Rocket, -2, -2, 2, 2) == 1,
            "launched rocket did not advance by its bounded two-cell step");
}

void populate_complete_material_scene(World& world) {
    add_floor(world, 40, -96, 224);
    constexpr Material materials[] = {
        Material::Sand,  Material::Water, Material::Smoke, Material::Cloner,
        Material::Fire,  Material::Wood,  Material::Lava,  Material::Ice,
        Material::Plant, Material::Acid,  Material::Stone, Material::Dust,
        Material::Mite,  Material::Oil,   Material::Rocket, Material::Fungus,
        Material::Seed,
    };
    for (std::size_t index = 0; index < std::size(materials); ++index) {
        const auto x = static_cast<std::int64_t>(index) * 17 - 64;
        world.set(x, 18 + static_cast<std::int64_t>(index % 5), materials[index]);
        world.set(x + 1, 23, Material::Wood);
    }
    world.set_temperature(174, 18 + 14 % 5, 1'000);
}

void test_complete_material_single_multiworker_parity() {
    WorldConfig single_config{};
    single_config.backend = cybersand::SimulationBackend::PhasedInPlace;
    single_config.worker_threads = 1;
    WorldConfig multi_config = single_config;
    multi_config.worker_threads = 4;
    World single(single_config);
    World multi(multi_config);
    populate_complete_material_scene(single);
    populate_complete_material_scene(multi);
    for (int tick = 0; tick < 80; ++tick) {
        (void)single.tick();
        (void)multi.tick();
        require(single.state_hash() == multi.state_hash(),
                "stateful material kernels diverged across worker counts");
    }
}

void populate_deterministic_scene(World& world) {
    add_floor(world, 48, -32, 32);
    for (int y = 0; y < 16; ++y) {
        for (int x = -12; x <= 12; ++x) {
            if ((x + y) % 3 == 0) world.set(x, y, Material::Sand);
            if ((x * 7 + y * 3) % 17 == 0) world.set(x + 20, y + 4, Material::Water);
        }
    }
}

void test_determinism() {
    World first({16, 3, 200});
    World second({16, 3, 200});
    populate_deterministic_scene(first);
    populate_deterministic_scene(second);
    for (int tick = 0; tick < 80; ++tick) {
        (void)first.tick();
        (void)second.tick();
    }
    require(first.state_hash() == second.state_hash(), "identical worlds diverged");
}

void test_single_and_multiworker_determinism() {
    WorldConfig single_config{};
    single_config.chunk_size = 128;
    single_config.backend = cybersand::SimulationBackend::PhasedInPlace;
    single_config.worker_threads = 1;
    WorldConfig multi_config = single_config;
    multi_config.worker_threads = 4;

    World single(single_config);
    World multi(multi_config);
    populate_deterministic_scene(single);
    populate_deterministic_scene(multi);
    for (int tick = 0; tick < 100; ++tick) {
        (void)single.tick();
        (void)multi.tick();
        require(single.state_hash() == multi.state_hash(),
                "single-worker and multiworker phased worlds diverged");
    }
}

void test_sleeping() {
    World world({16, 2, 200});
    add_floor(world, 3, -4, 4);
    world.set(0, 2, Material::Sand);
    for (int tick = 0; tick < 8; ++tick) (void)world.tick();
    require(world.active_chunk_count() == 0, "settled chunks failed to sleep");
    world.set(0, 1, Material::Sand);
    require(world.active_chunk_count() > 0, "external edit failed to wake chunk");
}

// Issue #1: promote the preserved capacity-after-explosion diagnostic into a
// contract regression. The failed attempt is observable, but cannot be retried.
void test_failed_tick_stops_until_clear() {
    for (const auto backend : {cybersand::SimulationBackend::SerialInPlace,
                               cybersand::SimulationBackend::PhasedInPlace}) {
        for (const bool with_event : {false, true}) {
            WorldConfig config{};
            config.backend = backend;
            config.active_core_capacity = 1;
            config.active_chunk_capacity = backend == cybersand::SimulationBackend::SerialInPlace ? 1 : 8;
            config.deferred_event_capacity = 1;
            World world(config);
            // Establish a successful tick, including normal event retirement.
            world.set(20, 20, Material::Sand);
            require(world.tick().tick == 1, "normal tick failed");
            world.set(20, 20, with_event ? Material::Wall : Material::Sand);
            world.set(21, 20, Material::Wall);
            world.set(160, 20, Material::Sand);
            if (with_event) require(world.queue_explosion(20, 20, 1, 0), "event rejected");
            const auto before_content = world.content_hash();
            bool threw = false;
            try { (void)world.tick(); } catch (const std::runtime_error&) { threw = true; }
            require(threw && world.tick_index() == 2, "capacity failure lost attempted identity");
            require(world.has_failed() && world.completed_tick_index() == 1,
                    "partial tick was reported as completed");
            require(with_event ? world.get(20, 20) == Material::Fire &&
                                     world.get(21, 20) == Material::Empty
                               : world.content_hash() == before_content,
                    "failure diagnostic changed: expected partial event, no rollback");
            const auto failed_state = world.state_hash();
            threw = false;
            try { (void)world.tick(); } catch (const std::exception&) { threw = true; }
            require(threw && world.state_hash() == failed_state,
                    "further stepping mutated a failed world");
            require(!world.queue_explosion(20, 20, 1, 0), "failed world accepted a new event");
            require(!world.set_cell_state(40, 20, Material::Water, 255, 0),
                    "failed world accepted gameplay state");
            threw = false;
            try { world.set(40, 20, Material::Sand); } catch (const std::logic_error&) { threw = true; }
            require(threw && world.state_hash() == failed_state, "failed mutation was not rejected");
            world.clear();
            require(!world.has_failed() && world.completed_tick_index() == 0, "clear retained failure");
            world.set(20, 20, Material::Sand);
            const auto recovered = world.tick();
            require(recovered.tick == 1 && recovered.deferred_events == 0 &&
                        world.get(20, 21) == Material::Sand,
                    "clear did not recover cleanly, or replayed an accepted event");
        }
    }
}

void test_failed_tick_after_executed_phase() {
    std::uint64_t expected_hash = 0;
    for (const std::uint32_t workers : {1U, 4U, 4U}) {
        WorldConfig config{};
        config.worker_threads = workers;
        config.parallel_job_threshold = 1;
        config.initial_chunk_reserve = 1;
        config.maximum_chunk_count = 1;
        World world(config);
        world.set(80, 20, Material::Sand); // Phase 1 executes first on attempt 1.
        world.set(10, 127, Material::Sand); // Phase 2 needs an unavailable chunk.
        cybersand::RenderSnapshotExchange exchange(2, 2, 128 * 128 * 2);
        require(exchange.publish(world).status == cybersand::RenderPublishStatus::Published,
                "initial publication failed");
        auto lease = exchange.acquire_latest();
        const std::vector<std::uint8_t> published(lease->cells().begin(), lease->cells().end());
        bool threw = false;
        try { (void)world.tick(); } catch (const std::runtime_error&) { threw = true; }
        require(threw && world.has_failed() && world.completed_tick_index() == 0,
                "late planning failure claimed success");
        require(world.get(80, 21) == Material::Sand && world.get(10, 127) == Material::Sand,
                "late failure no longer reproduces earlier-phase mutation");
        require(count_material(world, Material::Sand, 0, 0, 127, 127) == 2,
                "capacity failure lost conserved Sand");
        const auto dirty = world.dirty_chunk_count();
        threw = false;
        try { (void)exchange.publish(world); } catch (const std::logic_error&) { threw = true; }
        require(threw && exchange.latest_serial() == 1 && world.dirty_chunk_count() == dirty,
                "failed state published or lost diagnostic dirtiness");
        require(std::equal(published.begin(), published.end(), lease->cells().begin()),
                "failed tick changed a retained lease");
        if (expected_hash == 0) expected_hash = world.state_hash();
        require(world.state_hash() == expected_hash, "failure differs by repeat/worker count");
        world.clear();
        world.set(80, 20, Material::Sand);
        require(world.tick().moved_cells == 1, "late failure could not recover by clear");
    }
}

void test_failed_tick_c_api() {
    auto config = cybersand_default_config_v2();
    config.active_core_capacity = 1;
    config.deferred_event_capacity = 1;
    auto* world = cybersand_world_create_v2(&config);
    require(world != nullptr, "C failed-tick fixture construction failed");
    require(cybersand_world_set_v2(world, 20, 20, 1) &&
                cybersand_world_set_v2(world, 160, 20, 2) &&
                cybersand_world_queue_explosion(world, 20, 20, 1, 0), "C fixture setup failed");
    cybersand_tick_stats_v2 stats{};
    stats.tick = 999;
    require(!cybersand_world_tick_v2(world, &stats) && stats.tick == 0 &&
                cybersand_world_has_failed(world) &&
                cybersand_world_completed_tick_index(world) == 0,
                "C API reported a partial tick as successful");
    const auto failed_hash = cybersand_world_hash(world);
    require(!cybersand_world_tick_v2(world, &stats) &&
                !cybersand_world_queue_explosion(world, 20, 20, 1, 0) &&
                !cybersand_world_set_v2(world, 22, 20, 2) &&
                cybersand_world_hash(world) == failed_hash, "C API resumed a failed world");
    require(cybersand_world_clear(world) && !cybersand_world_has_failed(world) &&
                cybersand_world_set_v2(world, 20, 20, 2) &&
                cybersand_world_tick_v2(world, &stats) && stats.tick == 1 &&
                stats.deferred_events == 0, "C API clear replayed or failed");
    cybersand_world_destroy(world);
}

void test_dirty_rectangles() {
    World world({16, 3, 200});
    world.set(2, 3, Material::Wall);
    world.set(6, 9, Material::Sand);
    const auto dirty = world.take_dirty_chunks();
    require(dirty.size() == 1, "edits in one chunk produced wrong dirty chunk count");
    require(dirty[0].local_rect.x == 2 && dirty[0].local_rect.y == 3, "dirty origin is wrong");
    require(dirty[0].local_rect.width == 5 && dirty[0].local_rect.height == 7, "dirty extent is wrong");
    require(world.take_dirty_chunks().empty(), "taking dirty regions did not clear them");
}

void test_immutable_render_snapshot_exchange() {
    World world({16, 3, 200});
    cybersand::RenderSnapshotExchange exchange(2, 4, 256);
    require(exchange.publish(world).status == cybersand::RenderPublishStatus::NoChanges,
            "empty world published a spurious render snapshot");

    world.set(-1, 1, Material::Water);
    world.set(17, 2, Material::Sand);
    const auto first_result = exchange.publish(world);
    require(first_result.status == cybersand::RenderPublishStatus::Published &&
                first_result.snapshot_serial == 1 && first_result.required_patches == 2 &&
                first_result.required_bytes == 4,
            "first dirty snapshot reported incorrect bounds or capacity");
    require(world.dirty_chunk_count() == 0,
            "successful snapshot publication did not acknowledge dirty state");

    auto first = exchange.acquire_latest();
    require(first.has_value() && first->serial() == 1 && first->tick() == 0,
            "latest immutable snapshot could not be leased");
    require(first->patches().size() == 2 && first->cells().size() == 4,
            "snapshot lease omitted patch metadata or compact cells");
    require(first->patches()[0].world_rect.x == -1 &&
                first->patches()[1].world_rect.x == 17,
            "snapshot patches were not published in deterministic chunk order");
    require(first->cells()[0] == static_cast<std::uint8_t>(Material::Water) &&
                first->cells()[1] == 255U,
            "snapshot omitted Water material or fixed-point mass");

    world.set(0, 0, Material::Sand);
    const auto second_result = exchange.publish(world);
    require(second_result.status == cybersand::RenderPublishStatus::Published &&
                second_result.snapshot_serial == 2,
            "second snapshot did not use the remaining reusable slot");
    auto second = exchange.acquire_latest(1);
    require(second.has_value() && second->serial() == 2,
            "serial-filtered snapshot acquisition failed");

    world.set(1, 0, Material::Stone);
    const auto pressure_result = exchange.publish(world);
    require(pressure_result.status == cybersand::RenderPublishStatus::Backpressure,
            "fully leased snapshot slots did not report backpressure");
    require(world.dirty_chunk_count() == 1,
            "snapshot backpressure silently discarded dirty state");
    require(exchange.backpressure_count() == 1,
            "snapshot pressure metric was not incremented");

    first->reset();
    const auto recovered = exchange.publish(world);
    require(recovered.status == cybersand::RenderPublishStatus::Published &&
                recovered.snapshot_serial == 3,
            "released snapshot slot did not recover publication");
    require(world.dirty_chunk_count() == 0,
            "recovered publication failed to acknowledge retained dirty state");
    require(second->cells()[0] == static_cast<std::uint8_t>(Material::Sand),
            "publishing another slot mutated an outstanding immutable lease");
    require(exchange.patch_high_water() == 2 && exchange.byte_high_water() == 4,
            "snapshot high-water observations are incorrect");

    World oversized({16, 3, 200});
    oversized.set(0, 0, Material::Sand);
    oversized.set(15, 15, Material::Sand);
    cybersand::RenderSnapshotExchange constrained(1, 1, 64);
    const auto capacity_result = constrained.publish(oversized);
    require(capacity_result.status == cybersand::RenderPublishStatus::CapacityExceeded &&
                capacity_result.required_patches == 1 &&
                capacity_result.required_bytes == 512,
            "snapshot byte exhaustion did not report its exact requirement");
    require(oversized.dirty_chunk_count() == 1 &&
                constrained.capacity_failure_count() == 1,
            "snapshot capacity failure discarded dirty state or omitted telemetry");

    World lifetime_world({16, 3, 200});
    lifetime_world.set(4, 5, Material::Sand);
    std::optional<cybersand::RenderSnapshotLease> surviving_lease;
    {
        cybersand::RenderSnapshotExchange transient(1, 1, 8);
        require(transient.publish(lifetime_world).status ==
                    cybersand::RenderPublishStatus::Published,
                "transient exchange failed to publish its snapshot");
        surviving_lease = transient.acquire_latest();
    }
    require(surviving_lease.has_value() && surviving_lease->cells().size() == 2 &&
                surviving_lease->cells()[0] == static_cast<std::uint8_t>(Material::Sand),
            "C++ lease did not retain immutable slot ownership after exchange destruction");
}

void test_render_snapshot_concurrent_leases() {
    World world({32, 3, 200});
    cybersand::RenderSnapshotExchange exchange(3, 8, 512);
    std::atomic<bool> producer_done{false};
    std::atomic<bool> lease_valid{true};
    std::atomic<std::uint64_t> observed_snapshots{0};

    std::thread consumer([&] {
        std::uint64_t consumed_serial = 0;
        while (!producer_done.load(std::memory_order_acquire) ||
               consumed_serial < exchange.latest_serial()) {
            auto lease = exchange.acquire_latest(consumed_serial);
            if (!lease.has_value()) {
                std::this_thread::yield();
                continue;
            }
            if (lease->serial() <= consumed_serial || lease->patches().empty() ||
                lease->cells().size() < 2 ||
                lease->cells()[0] == static_cast<std::uint8_t>(Material::Empty)) {
                lease_valid.store(false, std::memory_order_release);
            }
            consumed_serial = lease->serial();
            observed_snapshots.fetch_add(1, std::memory_order_relaxed);
        }
    });

    for (std::int64_t index = 0; index < 64; ++index) {
        world.set(index % 16, index / 16,
                  (index & 1) == 0 ? Material::Sand : Material::Wall);
        const auto result = exchange.publish(world);
        require(result.status == cybersand::RenderPublishStatus::Published,
                "single consumer caused unexpected triple-buffer backpressure");
    }
    producer_done.store(true, std::memory_order_release);
    consumer.join();

    require(lease_valid.load(std::memory_order_acquire) &&
                observed_snapshots.load(std::memory_order_relaxed) > 0,
            "concurrent snapshot consumer observed a torn or empty immutable lease");
}

void test_rgba_copy_and_c_api() {
    cybersand_config config{16, 3, 200};
    auto* world = cybersand_world_create(config);
    require(world != nullptr, "C API failed to create world");
    cybersand_world_set(world, 1, 1, static_cast<std::uint16_t>(Material::Sand));
    std::vector<std::uint8_t> rgba(4U * 4U * 4U);
    require(cybersand_world_copy_rgba(world, 0, 0, 4, 4, rgba.data(), rgba.size(), 16) == 1,
            "C API RGBA copy failed");
    const auto offset = (1U * 4U + 1U) * 4U;
    require(rgba[offset] == 222 && rgba[offset + 1] == 174, "RGBA palette lookup is wrong");
    require(cybersand_world_hash(world) != 0, "C API returned invalid hash");
    require(cybersand_world_resident_cell_bytes(world) > 0, "C API did not expose resident cell memory");
    cybersand_world_destroy(world);

    auto config_v2 = cybersand_default_config_v2();
    config_v2.worker_threads = 4;
    config_v2.maximum_chunk_count = 64;
    config_v2.active_chunk_capacity = 64;
    auto* world_v2 = cybersand_world_create_v2(&config_v2);
    require(world_v2 != nullptr, "versioned C API failed to create phased world");
    require(cybersand_world_reserve_region(world_v2, -2, -2, 260, 260) == 1,
            "versioned C API failed to reserve an interest region");
    require(cybersand_world_set_v2(world_v2, 1, 1,
                                   static_cast<std::uint16_t>(Material::Water)) == 1,
            "versioned C API rejected a valid material edit");
    require(cybersand_world_queue_explosion(world_v2, 100, 100, 2, 255) == 1,
            "versioned C API rejected a bounded gameplay event");
    cybersand_tick_stats_v2 stats_v2{};
    require(cybersand_world_tick_v2(world_v2, &stats_v2) == 1 && stats_v2.tick == 1,
            "versioned C API tick failed");
    require(stats_v2.deferred_events == 1,
            "versioned C API omitted the committed-event count");
    require(stats_v2.chunk_allocations == 0,
            "reserved versioned C API tick allocated a chunk");
    require(cybersand_world_liquid_mass(world_v2, 1, 2) != 0,
            "versioned C API did not expose liquid mass");
    require(cybersand_world_content_hash(world_v2) != 0 &&
                cybersand_world_tick_index(world_v2) == 1 &&
                cybersand_world_chunk_count(world_v2) > 0,
            "versioned C API query surface is incomplete");
    std::vector<std::uint8_t> render_cells(4U * 4U * 2U);
    require(cybersand_world_copy_render_cells(world_v2, 0, 0, 4, 4,
                                              render_cells.data(), render_cells.size(), 8) == 1,
            "versioned C API render-cell copy failed");
    const auto render_offset = (2U * 4U + 1U) * 2U;
    require(render_cells[render_offset] == static_cast<std::uint8_t>(Material::Water) &&
                render_cells[render_offset + 1U] == 255U,
            "render-cell copy omitted material ID or compact state");
    const auto dirty_required = cybersand_world_take_dirty_chunks(world_v2, nullptr, 0);
    require(dirty_required != CYBERSAND_SIZE_ERROR && dirty_required > 0,
            "dirty extraction did not report required capacity");
    require(cybersand_world_take_dirty_chunks(world_v2, nullptr, 0) == dirty_required,
            "dirty capacity query cleared unpublished state");
    std::vector<cybersand_dirty_chunk> dirty_v2(dirty_required);
    require(cybersand_world_take_dirty_chunks(world_v2, dirty_v2.data(), dirty_v2.size()) ==
                dirty_required,
            "dirty extraction failed after capacity query");
    require(cybersand_world_take_dirty_chunks(world_v2, nullptr, 0) == 0,
            "successful dirty extraction did not acknowledge state");
    require(cybersand_world_set_v2(world_v2, 3, 3,
                                   static_cast<std::uint16_t>(Material::Sand)) == 1,
            "versioned C API failed to prepare a snapshot edit");
    auto* render_exchange = cybersand_render_exchange_create(2, 8, 256);
    require(render_exchange != nullptr, "C API failed to create render snapshot exchange");
    cybersand_render_publish_result publish_result{};
    require(cybersand_world_publish_render_snapshot(world_v2, render_exchange,
                                                     &publish_result) == 1 &&
                publish_result.status == CYBERSAND_RENDER_PUBLISHED &&
                publish_result.snapshot_serial == 1,
            "C API failed to publish a bounded immutable snapshot");
    auto* render_lease = cybersand_render_exchange_acquire_latest(render_exchange, 0);
    require(render_lease != nullptr && cybersand_render_lease_patch_count(render_lease) == 1,
            "C API failed to acquire its latest immutable snapshot");
    cybersand_render_patch render_patch{};
    require(cybersand_render_lease_get_patch(render_lease, 0, &render_patch) == 1 &&
                render_patch.x == 3 && render_patch.y == 3 &&
                render_patch.width == 1 && render_patch.height == 1,
            "C API snapshot patch metadata is incorrect");
    std::size_t snapshot_bytes = 0;
    const auto* snapshot_cells = cybersand_render_lease_cells(render_lease, &snapshot_bytes);
    require(snapshot_cells != nullptr && snapshot_bytes == 2 &&
                snapshot_cells[0] == static_cast<std::uint8_t>(Material::Sand),
            "C API snapshot lease omitted its immutable compact payload");
    require(cybersand_render_exchange_patch_high_water(render_exchange) == 1 &&
                cybersand_render_exchange_byte_high_water(render_exchange) == 2,
            "C API snapshot high-water observations are incorrect");
    cybersand_render_exchange_destroy(render_exchange);
    require(snapshot_cells[0] == static_cast<std::uint8_t>(Material::Sand),
            "destroying the C exchange invalidated an outstanding lease");
    cybersand_render_lease_destroy(render_lease);
    cybersand_material_info_v2 material_v2{};
    require(cybersand_material_get_info_v2(
                static_cast<std::uint16_t>(Material::Rocket), &material_v2) == 1 &&
                material_v2.maximum_write_radius == 2,
            "versioned material descriptor omitted bounded-rule metadata");
    cybersand_material_info_v3 material_v3{};
    require(cybersand_material_get_info_v3(
                static_cast<std::uint16_t>(Material::Smoke), &material_v3) == 1 &&
                material_v3.density_motion == CYBERSAND_DENSITY_MOTION_UP &&
                material_v3.accepts_density_exchange == 1,
            "material v3 descriptor omitted buoyancy traits");
    cybersand_material_info_v4 material_v4{};
    require(cybersand_material_get_info_v4(
                static_cast<std::uint16_t>(Material::Water), &material_v4) == 1 &&
                material_v4.viscosity_index == 0,
            "material v4 descriptor omitted normalized viscosity");
    cybersand_world_destroy(world_v2);

    auto invalid_config = cybersand_default_config_v2();
    invalid_config.abi_version = 999;
    require(cybersand_world_create_v2(&invalid_config) == nullptr,
            "versioned C API accepted an incompatible ABI version");
}

void test_extended_material_families() {
    const auto enclose_pair = [](World& world) {
        for (std::int64_t y = -1; y <= 1; ++y) {
            for (std::int64_t x = -1; x <= 2; ++x) {
                world.set(x, y, Material::Wall);
            }
        }
    };

    World dissolve({16, 3, 200});
    enclose_pair(dissolve);
    dissolve.set(0, 0, Material::Water);
    dissolve.set(1, 0, Material::Salt);
    for (int tick = 0; tick < 8 && dissolve.get(0, 0) != Material::Brine; ++tick) {
        (void)dissolve.tick();
    }
    require(dissolve.get(0, 0) == Material::Brine &&
                dissolve.get(1, 0) == Material::Brine,
            "salt and water did not form brine");

    World sodium({16, 3, 200});
    enclose_pair(sodium);
    sodium.set(0, 0, Material::Water);
    sodium.set(1, 0, Material::Sodium);
    for (int tick = 0; tick < 8; ++tick) {
        (void)sodium.tick();
        const auto left = sodium.get(0, 0);
        const auto right = sodium.get(1, 0);
        if ((left == Material::Steam && right == Material::Fire) ||
            (left == Material::Fire && right == Material::Steam)) {
            break;
        }
    }
    const auto sodium_left = sodium.get(0, 0);
    const auto sodium_right = sodium.get(1, 0);
    require((sodium_left == Material::Steam && sodium_right == Material::Fire) ||
                (sodium_left == Material::Fire && sodium_right == Material::Steam),
            "sodium and water did not produce fire and steam");

    World dense_liquid({16, 3, 200});
    for (std::int64_t y = -1; y <= 2; ++y) {
        dense_liquid.set(-1, y, Material::Wall);
        dense_liquid.set(1, y, Material::Wall);
    }
    dense_liquid.set(0, 2, Material::Wall);
    dense_liquid.set(0, 0, Material::Mercury);
    dense_liquid.set(0, 1, Material::Water);
    (void)dense_liquid.tick();
    require(dense_liquid.get(0, 1) == Material::Mercury &&
                dense_liquid.get(0, 0) == Material::Water,
            "dense mercury did not displace water downward");

    World electricity({16, 3, 200});
    enclose_pair(electricity);
    electricity.set(0, 0, Material::Spark);
    electricity.set(1, 0, Material::Metal);
    (void)electricity.tick();
    require(electricity.get(0, 0) == Material::Empty &&
                electricity.stored_state_b(1, 0) != 0U,
            "spark did not charge adjacent metal");

    World curing({16, 3, 200});
    for (std::int64_t y = -1; y <= 1; ++y) {
        for (std::int64_t x = -1; x <= 1; ++x) curing.set(x, y, Material::Wall);
    }
    curing.set(0, -1, Material::Empty);
    curing.set(0, 0, Material::Cement);
    for (int tick = 0; tick < 400; ++tick) (void)curing.tick();
    require(curing.get(0, 0) == Material::Concrete,
            "air-exposed cement did not cure into concrete");

    World hard_surface({16, 3, 200});
    const auto revision_before = hard_surface.hard_surface_revision();
    hard_surface.set(0, 0, Material::Metal);
    require(hard_surface.hard_surface_revision() > revision_before,
            "new structural material did not invalidate hard-surface geometry");
}

void test_sandspiel_material_catalog() {
    constexpr std::uint16_t expected_ids[] = {
        0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  11, 12, 13, 14,
        15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28,
        29, 30, 31, 32, 33, 34, 35, 36, 37,
    };
    require(sizeof(Material) == 1, "material identifier is no longer byte-sized");
    require(!cybersand::valid_material(10), "reserved material slot 10 became valid");
    require(!cybersand::valid_material(81), "out-of-range material became valid");

    for (const auto id : expected_ids) {
        require(cybersand::valid_material(id), "catalog is missing an imported material identifier");
        const auto& definition = cybersand::material_definition(static_cast<Material>(id));
        require(definition.valid, "valid catalog material resolves to invalid descriptor");
        require(!definition.name.empty(), "catalog material has no stable name");
    }

    require(cybersand::material_definition(Material::Smoke).name == "smoke",
            "project-facing Gas/Smoke alias changed");
    require(cybersand::material_definition(Material::Smoke).initial_state_a == 240U,
            "Smoke lost its bounded long-lifetime state");
    require(cybersand::project_visual_state(Material::Smoke, 173, 9) == 173,
            "Smoke lifetime is not projected to the renderer");
    require(cybersand::material_definition(Material::Cloner).current_rule_available,
            "implemented Cloner kernel was not exposed by the runtime catalog");
    require(cybersand::material_definition(Material::Water).current_rule_available,
            "current water prototype was incorrectly removed from the runtime catalog");
    require(cybersand::material_definition(Material::Water).lateral_flow ==
                cybersand::LateralFlowMode::FreeMass,
            "Water is not marked as a free-leveling mass liquid");
    require(cybersand::material_definition(Material::Oil).lateral_flow ==
                cybersand::LateralFlowMode::CellularYield,
            "heap-capable cellular liquid mode is no longer represented");
    require(cybersand::MaterialRules::discrete_lateral_flow_rate(Material::Water) == 24,
            "Water viscosity does not map to the tuned discrete flow rate");
    require(cybersand::MaterialRules::discrete_lateral_flow_rate(Material::Oil) <
                cybersand::MaterialRules::discrete_lateral_flow_rate(Material::Water),
            "viscous Oil is not slower than Water");
    require(cybersand::MaterialRules::apply_lateral_viscosity(Material::Lava, 128) <
                cybersand::MaterialRules::apply_lateral_viscosity(Material::Oil, 128),
            "normalized viscosity does not reduce lateral mass transfer");
    require(cybersand::MaterialRules::can_density_exchange(Material::Smoke, Material::Water, -1),
            "Smoke cannot exchange upward through Water");
    require(!cybersand::MaterialRules::can_density_exchange(Material::Smoke, Material::Wall, -1),
            "Wall unexpectedly accepts buoyancy exchange");
    require(!cybersand::MaterialRules::can_density_exchange(Material::Smoke, Material::Mite, -1),
            "movable agent opt-out from density exchange was ignored");
    for (const auto id : expected_ids) {
        const auto& definition = cybersand::material_definition(static_cast<Material>(id));
        require(definition.current_rule_available,
                "implemented material is missing its executable catalog status");
        require(definition.maximum_write_radius <= 2,
                "material rule exceeds the configured scheduler write radius");
    }

    const auto descriptors = cybersand::MaterialRules::descriptors();
    require(descriptors.size() == 81, "MaterialRules descriptor span has the wrong extent");
    cybersand_material_info info{};
    require(cybersand_material_get_info(static_cast<std::uint16_t>(Material::Lava), &info) == 1,
            "C API could not query imported material information");
    require(info.id == static_cast<std::uint16_t>(Material::Lava) && info.current_rule_available == 1,
            "C API material status is incorrect");
    require(cybersand_material_get_info(10, &info) == 0,
            "C API accepted the reserved material identifier");
}

void test_themed_static_material_catalog() {
    for (std::uint16_t id = static_cast<std::uint16_t>(Material::LimestoneBlock);
         id <= static_cast<std::uint16_t>(Material::LedWhite); ++id) {
        require(cybersand::valid_material(id), "themed material ID is not valid");
        const auto material = static_cast<Material>(id);
        const auto& definition = cybersand::material_definition(material);
        require(definition.state == cybersand::MaterialState::Solid,
                "themed construction material is not a solid");
        require(!definition.movable, "themed construction material unexpectedly moves");
        require(definition.current_rule_available,
                "themed material is unavailable to the executable catalog");
        require(cybersand::MaterialRules::is_hard_surface(material),
                "themed construction material is missing hard-surface collision");
        const bool combustible = material == Material::OakTimber || material == Material::Thatch;
        require(definition.kernel ==
                    (combustible ? cybersand::RuleKernel::Combustible
                                 : cybersand::RuleKernel::None),
                "themed material selected an unexpected active kernel");
        require(definition.maximum_write_radius == (combustible ? 1U : 0U),
                "themed material has an unexpected scheduler write radius");
    }

    require(cybersand::project_visual_state(Material::OakTimber, 7, 91) == 91,
            "oak burn progress is not projected to the renderer");
    require(cybersand::project_visual_state(Material::Thatch, 9, 73) == 73,
            "thatch burn progress is not projected to the renderer");
    require(cybersand::project_visual_state(Material::NeonCyan, 255, 255) == 0,
            "static neon unexpectedly consumes authoritative condition state");

    cybersand_material_info info{};
    require(cybersand_material_get_info(
                static_cast<std::uint16_t>(Material::ReinforcedConcrete), &info) == 1 &&
                info.current_rule_available == 1,
            "C API cannot query the themed material expansion");
}

void test_themed_combustibles_reuse_bounded_kernel() {
    for (const auto combustible : {Material::OakTimber, Material::Thatch}) {
        World world({16, 3, 200});
        for (std::int64_t y = -1; y <= 1; ++y) {
            for (std::int64_t x = -1; x <= 1; ++x) {
                world.set(x, y, (x == 0 && y == 0) ? Material::Lava : combustible);
            }
        }
        (void)world.tick();
        bool ignited = false;
        for (std::int64_t y = -1; y <= 1; ++y) {
            for (std::int64_t x = -1; x <= 1; ++x) {
                if ((x != 0 || y != 0) && world.stored_state_b(x, y) != 0U) ignited = true;
            }
        }
        require(ignited, "themed combustible did not reuse the bounded burn kernel");
    }
}

}  // namespace

int main() {
    struct Test {
        const char* name;
        void (*function)();
    };
    const Test tests[] = {
        {"negative coordinates", test_negative_coordinates},
        {"scheduler geometry", test_scheduler_geometry},
        {"sand fall", test_sand_falls_and_stops},
        {"cross chunk", test_cross_chunk_fall},
        {"cross scheduler core", test_cross_scheduler_core_fall},
        {"activity sleep and wake", test_activity_core_sleep_and_wake},
        {"serial/phased behavioral parity", test_serial_and_phased_behavioral_parity},
        {"density swap", test_sand_sinks_through_water},
        {"conserved water", test_conserved_water_levels_and_sleeps},
        {"level water surface", test_water_surface_column_mass_is_level},
        {"water single/multiworker parity", test_water_single_multiworker_parity},
        {"water storage boundary", test_water_conserves_across_storage_boundaries},
        {"optional temperature movement", test_optional_temperature_moves_across_chunk},
        {"preallocated hot path", test_preallocated_tick_has_no_owned_allocations},
        {"chunk capacity", test_chunk_capacity_fails_explicitly},
        {"smoke", test_smoke_rises},
        {"smoke density displacement", test_smoke_buoyantly_displaces_water_and_sand},
        {"smoke lifecycle and fire exclusion", test_smoke_lifetime_culling_and_fire_exclusion},
        {"fire and extinguishing", test_fire_combustion_and_extinguishing},
        {"hot material reactions", test_lava_ice_dust_and_oil_reactions},
        {"acid and stone", test_acid_corrosion_and_stone_collapse},
        {"water/oil density", test_water_displaces_oil},
        {"cloner", test_cloner_captures_and_emits},
        {"deferred explosion", test_deferred_explosion_and_event_capacity},
        {"explosion worker parity", test_explosion_single_multiworker_parity},
        {"growth and seed", test_growth_and_seed_germination},
        {"mite and rocket", test_mite_agent_and_rocket_payload},
        {"complete material worker parity", test_complete_material_single_multiworker_parity},
        {"determinism", test_determinism},
        {"single/multiworker determinism", test_single_and_multiworker_determinism},
        {"sleeping", test_sleeping},
        {"issue #1 failed tick stop/reset", test_failed_tick_stops_until_clear},
        {"issue #1 late failure and publication", test_failed_tick_after_executed_phase},
        {"issue #1 C API failure/recovery", test_failed_tick_c_api},
        {"dirty rectangles", test_dirty_rectangles},
        {"immutable render snapshots", test_immutable_render_snapshot_exchange},
        {"concurrent render leases", test_render_snapshot_concurrent_leases},
        {"C API and RGBA", test_rgba_copy_and_c_api},
        {"extended material families", test_extended_material_families},
        {"Sandspiel material catalog", test_sandspiel_material_catalog},
        {"themed static material catalog", test_themed_static_material_catalog},
        {"themed combustible kernels", test_themed_combustibles_reuse_bounded_kernel},
    };

    std::size_t passed = 0;
    for (const auto& test : tests) {
        try {
            test.function();
            ++passed;
            std::cout << "[pass] " << test.name << '\n';
        } catch (const std::exception& error) {
            std::cerr << "[fail] " << test.name << ": " << error.what() << '\n';
            return 1;
        }
    }
    std::cout << passed << " tests passed\n";
    return 0;
}
