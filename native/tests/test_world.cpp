#include "cybersand/c_api.h"
#include "cybersand/interaction_rules.hpp"
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
#include <utility>
#include <vector>

namespace cybersand {
class PrecisionProbe {
public:
    static std::uint16_t transfer(World& world, std::int64_t from_x, std::int64_t from_y,
                                  std::int64_t to_x, std::int64_t to_y,
                                  std::uint16_t requested) {
        return world.transfer_water(from_x, from_y, to_x, to_y, requested, nullptr);
    }
};
}  // namespace cybersand

namespace {

using cybersand::Material;
using cybersand::World;
using cybersand::WorldConfig;
using cybersand::WaterExperimentPolicy;

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

void test_water_lateral_front_and_leveling_speed() {
    for(int width:{48,96})for(bool mirror:{false,true})for(int workers:{1,4}) {
        WorldConfig c;c.worker_threads=workers;c.parallel_job_threshold=1;
        c.maximum_chunk_count=64;c.active_chunk_capacity=64;c.active_core_capacity=512;
        World w(c);w.reserve_region({-193,-193,512,512});
        auto put=[&](int x,int y,Material m){w.set(x-65,y-65,m);};
        for(int x=0;x<=width+1;++x){put(x,0,Material::Wall);put(x,47,Material::Wall);}
        for(int y=0;y<48;++y){put(0,y,Material::Wall);put(width+1,y,Material::Wall);}
        for(int x=1;x<=12;++x)for(int y=15;y<=46;++y)put(mirror ? width+1-x:x,y,Material::Water);
        for(int tick=1;tick<=600;++tick) {
            const auto stats=w.tick();
            require(stats.chunk_allocations==0&&stats.temperature_field_allocations==0,"leveling allocated prepared storage");
            require(total_liquid(w,-64,-64,width-65,-19)==12U*32U*255U,"leveling lost mass");
            if(tick==300&&width==96) {
                const auto start=mirror ? 1 : 72;
                require(total_liquid(w,start-65,-64,(mirror ? 25 : 96)-65,-19)>=128,"Water lateral front is too slow");
            }
        }
        if(width==48) {
            std::uint64_t low=std::numeric_limits<std::uint64_t>::max(),high=0;
            for(int x=1;x<=width;++x) {
                const auto mass=total_liquid(w,x-65,-64,x-65,-19);
                low=std::min(low,mass);high=std::max(high,mass);
            }
            require(high-low<=255,"Water basin leveling is too slow");
        }
    }
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
WorldConfig transport_config(int mode,int workers=1) {
    WorldConfig c;c.worker_threads=workers;c.parallel_job_threshold=1;
    c.active_core_capacity=512;c.maximum_chunk_count=64;c.active_chunk_capacity=64;
    c.physics_diagnostics.enabled=true;c.transport_policy.configured=true;
    for(auto a: {2,13,14,19,23,25,26,27,29}) {
        for(auto b: {2,13,14,19,23,25,26,27,29})
            c.transport_policy.pairs[a*81+b].mixing=mode ? 96 : 0;
        c.transport_policy.pairs[33*81+a].permeability=30;
        c.transport_policy.pairs[a*81+33].permeability=30;
    }
    for(auto grain:{2,14,29}) {
        auto& p=c.transport_policy.pairs[3*81+grain];p.carrying=mode ? 255 : 0;p.erosion=mode==2;
    }
    return c;
}


void test_failed_tick_stops_until_clear() {
    for (const auto backend : {cybersand::SimulationBackend::SerialInPlace,
                               cybersand::SimulationBackend::PhasedInPlace}) {
        for (const bool with_event : {false, true}) for (bool tuned : {false,true}) {
            WorldConfig config=tuned ? transport_config(2,1) : WorldConfig{};
            if(tuned) {config.transport_policy.horizontal[3]=1;config.transport_policy.cadence[3]=60;}
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

// Issue #2: re-entry must resume movable content without a neighboring write.
// Core-level selection deliberately permits a step beyond the exact rectangle.
void test_interest_resume_boundaries() {
    for (const std::uint32_t workers : {1U, 4U}) {
        for (const auto point : {cybersand::ChunkCoord{400, 32}, {63, 63}, {127, 127},
                                  {-1, -1}, {-65, -65}, {-129, -129}}) {
            WorldConfig config{};
            config.worker_threads = workers;
            config.parallel_job_threshold = 1;
            World world(config);
            world.set(point.x, point.y, Material::Sand);
            world.set_temperature(point.x, point.y, 777);
            world.set_simulation_region(cybersand::RectI64{1024, 1024, 64, 64});
            const auto content = world.content_hash();
            for (int tick = 0; tick < 8; ++tick) {
                require(world.tick().scheduled_cores == 0, "excluded core scheduled");
                require(world.content_hash() == content, "excluded Sand advanced");
            }
            world.set_simulation_region(cybersand::RectI64{point.x, point.y, 1, 1});
            const auto resumed = world.tick();
            require(resumed.scheduled_cores > 0 && world.get(point.x, point.y) == Material::Empty &&
                        world.get(point.x, point.y + 1) == Material::Sand &&
                        world.temperature(point.x, point.y + 1) == 777,
                    "region re-entry left Sand frozen or lost retained temperature");
            require(count_material(world, Material::Sand, point.x - 2, point.y - 2,
                                   point.x + 2, point.y + 10) == 1,
                    "re-entry lost conserved Sand or performed elapsed-time catch-up");
        }
    }
    WorldConfig serial_config{};
    serial_config.backend = cybersand::SimulationBackend::SerialInPlace;
    World serial(serial_config);
    serial.set(400, 32, Material::Sand);
    serial.set_simulation_region(cybersand::RectI64{0, 0, 64, 64});
    (void)serial.tick();
    require(serial.get(400, 33) == Material::Sand,
            "SerialInPlace's deliberate whole-active-chunk semantics changed");
}

// Settled blocks are rechecked once, including newly selected portions of an
// overlapping window. Unchanged/equivalent/coalesced windows stay asleep.
void test_interest_sleep_transitions() {
    for (const std::uint32_t workers : {1U, 4U}) {
        WorldConfig config{};
        config.worker_threads = workers;
        config.parallel_job_threshold = 1;
        World world(config);
        for (const auto x : {20, 84, 148, 276}) world.set(x, 20, Material::Wall);
        for (int i = 0; i < 4; ++i) (void)world.tick();
        require(world.active_chunk_count() == 0, "fixture did not sleep");
        world.set_simulation_region(cybersand::RectI64{0, 0, 128, 64});
        require(world.tick().scheduled_cores == 0, "shrinking unbounded interest woke settled work");
        world.set_simulation_region(cybersand::RectI64{64, 0, 128, 64});
        auto stats = world.tick();
        require(stats.scheduled_cores == 1, "overlap woke old cores or missed newly included core");
        for (int i = 0; i < 4; ++i) (void)world.tick();
        for (int i = 0; i < 6; ++i) {
            world.set_simulation_region(cybersand::RectI64{65, 1, 126, 62});
            require(world.tick().scheduled_cores == 0, "equivalent region repeatedly woke sleeping work");
        }
        world.set_simulation_region(cybersand::RectI64{256, 0, 64, 64});
        world.set_simulation_region(cybersand::RectI64{64, 0, 128, 64});
        require(world.tick().scheduled_cores == 0, "unobserved region excursion woke work");
        world.set_simulation_region(cybersand::RectI64{256, 0, 64, 64});
        require(world.tick().scheduled_cores == 1, "disjoint move missed sleeping resident core");
        for (int i = 0; i < 4; ++i) (void)world.tick();
        world.set(275, 20, Material::Wall);
        require(world.tick().scheduled_cores == 1, "neighbor write no longer wakes sleeping core");
        for (int i = 0; i < 4; ++i) (void)world.tick();
        world.set_simulation_region(std::nullopt);
        require(world.tick().scheduled_cores > 0, "removing region did not wake newly eligible blocks");
    }
    // A custom single-worker block may span several cores. Partial inclusion
    // must never age away the unsimulated part of that shared activity record.
    WorldConfig custom{};
    custom.activity_block_size = 128;
    World straddling(custom);
    straddling.set(90, 20, Material::Sand);
    straddling.set_simulation_region(cybersand::RectI64{0, 0, 64, 64});
    for (int i = 0; i < 8; ++i) (void)straddling.tick();
    require(straddling.active_chunk_count() > 0 && straddling.get(90, 20) == Material::Sand,
            "partly excluded activity record lost pending work");
    straddling.set_simulation_region(cybersand::RectI64{64, 0, 64, 64});
    (void)straddling.tick();
    require(straddling.get(90, 21) == Material::Sand, "straddling activity did not resume");
}

void test_interest_conservation_and_worker_determinism() {
    std::vector<std::uint64_t> expected;
    for (const std::uint32_t workers : {1U, 4U, 4U}) {
        WorldConfig config{};
        config.worker_threads = workers;
        config.parallel_job_threshold = 1;
        World world(config);
        world.reserve_region({-128, -128, 640, 512});
        world.reserve_temperature_region({-128, -128, 640, 512});
        add_floor(world, 100, 0, 319);
        for (const auto x : {20, 84, 148, 276}) {
            world.set(x, 20, Material::Sand);
            world.set(x + 4, 30, Material::Water);
        }
        std::vector<std::uint64_t> observed;
        const auto water = total_liquid(world, 0, 0, 319, 100);
        const cybersand::RectI64 regions[] = {{0, 0, 128, 128}, {64, 0, 128, 128},
            {256, 0, 64, 128}, {0, 0, 128, 128}, {0, 0, 320, 128}};
        for (const auto region : regions) {
            world.set_simulation_region(region);
            for (int tick = 0; tick < 8; ++tick) {
                const auto stats = world.tick();
                require(stats.chunk_allocations == 0 && stats.temperature_field_allocations == 0,
                        "preallocated region transition allocated native storage");
                require(total_liquid(world, 0, 0, 319, 100) == water &&
                            count_material(world, Material::Sand, 0, 0, 319, 100) == 4,
                        "interest transition lost conserved material");
                observed.push_back(world.state_hash());
            }
        }
        if (expected.empty()) expected = observed;
        else require(observed == expected, "region transition changed across workers/repeated run");
    }
}

void test_interest_failed_tick_recovery() {
    for (const std::uint32_t workers : {1U, 4U}) {
        for (const bool with_event : {false, true}) for (bool tuned : {false,true}) {
            WorldConfig config=tuned ? transport_config(2,1) : WorldConfig{};
            if(tuned) {config.transport_policy.horizontal[3]=1;config.transport_policy.cadence[3]=60;}
            config.worker_threads = workers;
            config.parallel_job_threshold = 1;
            config.active_core_capacity = 1;
            World world(config);
            world.set(20, 20, Material::Wall);
            world.set(400, 20, Material::Sand);
            world.set_simulation_region(cybersand::RectI64{0, 0, 64, 64});
            for (int i = 0; i < 5; ++i) (void)world.tick();
            require(world.get(400, 20) == Material::Sand && world.active_chunk_count() > 0,
                    "excluded pending activity lost before fault");
            if (with_event) require(world.queue_explosion(20, 20, 1), "combined event rejected");
            world.set_simulation_region(cybersand::RectI64{0, 0, 448, 64});
            bool threw = false;
            try { (void)world.tick(); } catch (const std::runtime_error&) { threw = true; }
            require(threw && world.has_failed() && world.completed_tick_index() == 5,
                    "re-entry capacity failure reported success");
            require(world.get(20, 20) == (with_event ? Material::Fire : Material::Wall),
                    "combined event ordering changed");
            world.set_simulation_region(cybersand::RectI64{384, 0, 64, 64});
            const auto frozen = world.state_hash();
            try { (void)world.tick(); } catch (const std::logic_error&) {}
            require(world.state_hash() == frozen && world.get(400, 20) == Material::Sand,
                    "region change resumed partial world");
            world.clear();
            world.set(400, 20, Material::Sand);
            const auto resumed = world.tick();
            require(resumed.tick == 1 && resumed.deferred_events == 0 &&
                        world.get(400, 21) == Material::Sand && world.get(20, 20) == Material::Empty,
                    "clear lost latest region or replayed failed event");
        }
    }
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

    for (const auto bits : {std::uint8_t{3}, std::uint8_t{4}}) {
        WorldConfig water_config{};
        water_config.water_experiment_policy = WaterExperimentPolicy(bits, 12U);
        World water_world(water_config);
        cybersand::RenderSnapshotExchange water_exchange(2, 1, 8);
        const auto& policy = water_world.config().water_experiment_policy;
        require(water_world.set_cell_state(3, 4, Material::Water,
                                           policy.maximum(), 0U),
                "nondefault Water full-publication setup failed");
        require(water_exchange.publish(water_world).status ==
                    cybersand::RenderPublishStatus::Published,
                "nondefault Water initial publication failed");
        auto full_mass = water_exchange.acquire_latest();
        require(full_mass.has_value() && full_mass->cells().size() == 2 &&
                    full_mass->cells()[0] == static_cast<std::uint8_t>(Material::Water) &&
                    full_mass->cells()[1] == 255U,
                "nondefault Water initial publication was not normalized");
        full_mass->reset();

        const auto candidate_mass = static_cast<std::uint16_t>(
            policy.maximum() / 2U);
        require(water_world.set_cell_state(3, 4, Material::Water,
                                           candidate_mass, 0U),
                "nondefault Water dirty-patch mutation failed");
        require(water_exchange.publish(water_world).status ==
                    cybersand::RenderPublishStatus::Published,
                "nondefault Water dirty-patch publication failed");
        auto dirty_mass = water_exchange.acquire_latest(1U);
        require(dirty_mass.has_value() && dirty_mass->cells().size() == 2 &&
                    dirty_mass->cells()[0] == static_cast<std::uint8_t>(Material::Water) &&
                    dirty_mass->cells()[1] == policy.normalized_mass(candidate_mass),
                "nondefault Water dirty patch used the default mass lattice");
    }
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

void test_physics_diagnostics_observational() {
    cybersand::WorldConfig base;
    base.parallel_job_threshold = 1;
    base.active_core_capacity = 1024;
    auto observed = base;
    observed.physics_diagnostics.enabled = true;
    auto multi = observed;
    multi.worker_threads = 4;
    cybersand::World plain(base), diagnostic(observed), workers(multi);
    for (auto* world : {&plain, &diagnostic, &workers}) {
        world->reserve_region({-128, -128, 384, 384});
        for (int x = 48; x < 145; ++x) {
            world->set(x, 96, cybersand::Material::Wall);
            for (int y = 48; y < 96; ++y)
                world->set(x, y, y < 64 ? cybersand::Material::Sand : cybersand::Material::Dust);
        }
        world->set(70, 30, cybersand::Material::Water);
        world->set(71, 30, cybersand::Material::Salt);
    }
    for (int tick = 0; tick < 240; ++tick) {
        (void)plain.tick(); (void)diagnostic.tick(); (void)workers.tick();
        require(plain.state_hash() == diagnostic.state_hash(), "telemetry changed cellular state");
        require(plain.state_hash() == workers.state_hash(), "telemetry changed worker parity");
        for (int y = 28; y <= 100; ++y) for (int x = 44; x <= 149; ++x) {
            require(plain.stored_material(x,y) == workers.stored_material(x,y) &&
                    plain.stored_state_a(x,y) == workers.stored_state_a(x,y) &&
                    plain.stored_state_b(x,y) == workers.stored_state_b(x,y),
                    "diagnostic exact cell/state comparison failed");
        }
    }
    require(plain.physics_diagnostics() == nullptr, "default telemetry allocated");
    const auto& one = *diagnostic.physics_diagnostics();
    const auto& four = *workers.physics_diagnostics();
    require(one.overflow == 0 && four.overflow == 0, "fixture histogram overflow");
    bool swap = false, conversion = false;
    for (const auto& entry : one.entries) {
        if (!entry.key) continue;
        bool found = false;
        for (const auto& other : four.entries) if (entry.key == other.key) {
            require(entry.count == other.count, "worker histogram mismatch"); found = true; break;
        }
        require(found, "worker histogram missing key");
        swap |= (entry.key >> 24U) == static_cast<unsigned>(cybersand::PhysicsEvent::DensitySwap);
        conversion |= (entry.key >> 24U) == static_cast<unsigned>(cybersand::PhysicsEvent::Conversion);
    }
    require(swap && conversion, "fixture did not exercise transport and chemistry");
    diagnostic.clear();
    require(diagnostic.physics_diagnostics()->used == 0, "clear retained diagnostic counters");
    cybersand::PhysicsHistogram<2> bounded;
    bounded.add(1); bounded.add(2); bounded.add(3);
    require(bounded.used == 2 && bounded.overflow == 1, "telemetry overflow is not explicit");
}

void test_physics_diagnostic_controls() {
    cybersand::WorldConfig config;
    // Keep the full-rate baseline as an explicit viscosity isolation control.
    config.interaction_policy.mercury_exchange_period = 1;
    config.active_core_capacity = 1024;
    config.physics_diagnostics.enabled = true;
    auto viscous = config; viscous.physics_diagnostics.mercury_viscosity = 248;
    auto off = config; off.physics_diagnostics.disable_powder_exchange_targets = true;
    cybersand::World baseline(config), viscosity(viscous), blocked(off);
    for (auto* world : {&baseline, &viscosity, &blocked}) {
        for (int y = 0; y <= 64; ++y) {
            world->set(0,y,cybersand::Material::Wall); world->set(2,y,cybersand::Material::Wall);
            if (y >= 16) world->set(1,y,cybersand::Material::Sand);
        }
        world->set(1,64,cybersand::Material::Wall);
        world->set(1,15,cybersand::Material::Mercury);
    }
    for (int tick = 0; tick < 120; ++tick) {
        (void)baseline.tick(); (void)viscosity.tick(); (void)blocked.tick();
        require(baseline.state_hash() == viscosity.state_hash(), "viscosity affected confined vertical penetration");
    }
    require(baseline.get(1,63) == cybersand::Material::Mercury, "Mercury did not penetrate packed Sand");
    require(blocked.get(1,15) == cybersand::Material::Mercury, "target diagnostic switch did not isolate exchange");
}

void test_physics_masked_source_characterisation() {
    // A measured baseline, not a desired rule: retained Sand selects a powder
    // kernel, but get() returns the body's Wall proxy inside that kernel.
    // Successors #10/#11 must update this fixture if they change that policy.
    cybersand::WorldConfig config;
    config.physics_diagnostics.enabled = true;
    cybersand::World world(config);
    world.set(100,100,cybersand::Material::Sand);
    world.configure_transient_obstacles({96,96,16,16});
    for (int y=99;y<=102;++y) for(int x=98;x<=102;++x)
        require(world.set_transient_obstacle(x,y,1), "body fixture mask failed");
    (void)world.tick();
    require(world.stored_material(100,100)==cybersand::Material::Sand, "masked grain was lost");
    require(world.transient_contact_count(1)==3, "masked source baseline contact opportunities changed");
    require(world.transient_contact_impulse_y(1)==4800, "masked Wall proxy baseline weighting changed");
    std::cout << "masked-Sand baseline: 3 downward contact attempts, raw y=4800; stored Sand retained\n";
}

void test_granular_player_support_policy() {
    for (const auto& definition : cybersand::MaterialRules::descriptors()) {
        const auto material = static_cast<Material>(&definition - cybersand::kMaterialDefinitions.data());
        if (!cybersand::MaterialRules::supports_granular_load(material)) continue;
        World world;
        for (int x=48; x<80; ++x) {
            world.set(x,104,Material::Wall);
            for (int y=100; y<104; ++y) world.set(x,y,material);
        }
        (void)world.tick();
        require(world.granular_support_at(64,100), "packed powder must bear sampled player");
        require(!world.granular_support_at(64,100,true), "surface must permit a one-cell step");
        require(world.granular_support_at(64,101,true), "packed interior must resist side approach");
        for(int x=62;x<=66;++x) for(int y=101;y<=104;++y) world.set(x,y,Material::Empty);
        require(!world.granular_support_at(64,100), "excavation must remove sampled support immediately");
        (void)world.tick();
        require(!world.granular_support_at(64,101), "falling grains must not bear sampled load");
    }
    World film;
    for(int x=48;x<80;++x) film.set(x,100,Material::Dust);
    require(!film.granular_support_at(64,100), "airborne Dust film is not a wall");
}

void test_powder_pair_and_void_policy() {
    constexpr Material powders[] = {Material::Sand,Material::Stone,Material::Dust,
        Material::Seed,Material::Salt,Material::Sodium,Material::Gunpowder,Material::Coal,Material::Rust};
    for (auto top : powders) for(auto bottom : powders) {
        if(top==bottom) continue;
        World world;
        for(int x=60;x<69;++x) for(int y=60;y<70;++y)
            world.set(x,y,(x==60||x==68||y==69)?Material::Wall:y<64?top:bottom);
        for(int tick=0;tick<60;++tick) (void)world.tick();
        for(int x=61;x<68;++x) for(int y=60;y<69;++y)
            require(world.get(x,y)==(y<64?top:bottom) ||
                (top==Material::Seed && bottom==Material::Sand && y<64 && world.get(x,y)==Material::Plant),
                "resting powder pair reordered: " +
                std::to_string(static_cast<int>(top)) + "/" + std::to_string(static_cast<int>(bottom)) +
                " at " + std::to_string(x) + "," + std::to_string(y) + " now " +
                std::to_string(static_cast<int>(world.get(x,y))));
        world.set(64,69,Material::Empty);
        (void)world.tick();
        if(bottom!=Material::Stone)
            require(world.get(64,69)==bottom,"powder failed to collapse into a real void");
    }
}

void test_mercury_lanes_wake_and_reentry() {
    WorldConfig free_config; free_config.interaction_policy.mercury_exchange_period=60;
    World free_fall(free_config); free_fall.set(64,64,Material::Mercury);
    (void)free_fall.tick();
    require(free_fall.get(64,65)==Material::Mercury,"permeability throttled genuine void fall");
    WorldConfig brace_config; brace_config.interaction_policy.mercury_exchange_period=1;
    World brace(brace_config);
    for(int x=61;x<=67;++x) for(int y=61;y<=67;++y) brace.set(x,y,Material::Wall);
    brace.set(64,63,Material::Mercury); brace.set(64,64,Material::Stone);
    brace.set(63,63,Material::Stone); brace.set(65,63,Material::Stone);
    (void)brace.tick();
    require(brace.get(64,63)==Material::Mercury,"liquid displaced a braced Stone target");
    require(brace.set_cell_state(64,64,Material::Stone,0,1),"granular Stone setup");
    (void)brace.tick();
    require(brace.get(64,64)==Material::Mercury,"granular Stone failed to yield to permitted exchange");
    for(int dx=-1;dx<=1;++dx) for(int seam : {-65,-1,63,127}) {
        World world;
        for(int x=seam-2;x<=seam+2;++x) for(int y=seam-2;y<=seam+3;++y) world.set(x,y,Material::Wall);
        world.set(seam,seam,Material::Mercury);
        world.set(seam+dx,seam+1,Material::Sand);
        for(int t=1;t<30;++t) {
            (void)world.tick();
            require(world.get(seam,seam)==Material::Mercury,"alternative attempts multiplied Mercury rate");
        }
        require(world.active_chunk_count()==0,"waiting exchange should let blocks sleep");
        (void)world.tick();
        require(world.get(seam+dx,seam+1)==Material::Mercury,"sleeping diagonal/seam exchange failed to wake");
        require(world.get(seam,seam)==Material::Sand,"exchange lost displaced grain");
    }
    for(std::uint32_t period : {10U,30U,60U}) {
        WorldConfig config; config.interaction_policy.mercury_exchange_period=period;
        config.parallel_job_threshold=1;
        World single(config); config.worker_threads=4; World parallel(config);
        for(auto* world : {&single,&parallel}) {
            for(int x=60;x<=100;++x) for(int y=62;y<=100;++y)
                world->set(x,y,(x==60||x==100||y==100)?Material::Wall:Material::Sand);
            for(int x=61;x<100;++x) world->set(x,62,Material::Mercury);
        }
        for(int t=1;t<=180;++t) {
            auto a=single.tick();auto b=parallel.tick();
            require(a.chunk_allocations==b.chunk_allocations,"worker allocation disparity");
            require(single.state_hash()==parallel.state_hash(),"permeability worker parity");
            const auto front=62+t/static_cast<int>(period);
            require(single.get(80,front)==Material::Mercury,"configured lane did not make exactly bounded progress");
        }
    }
    World paused;
    for(int x=60;x<69;++x) for(int y=60;y<100;++y)
        paused.set(x,y,(x==60||x==68||y==99)?Material::Wall:Material::Sand);
    paused.set(64,60,Material::Mercury);
    (void)paused.tick();
    paused.set_simulation_region(cybersand::RectI64{768,768,64,64});
    for(int t=2;t<=200;++t) (void)paused.tick();
    require(paused.get(64,60)==Material::Mercury,"excluded region accrued motion");
    paused.set_simulation_region(std::nullopt);
    for(int t=201;t<210;++t) (void)paused.tick();
    require(paused.get(64,60)==Material::Mercury,"reentry replayed missed lanes");
    (void)paused.tick();
    require(paused.get(64,61)==Material::Mercury,"reentry lost the pending exchange wake");
}

std::uint64_t transport_events(const World& world,cybersand::PhysicsEvent kind) {
    std::uint64_t count=0;
    for(const auto& e:world.physics_diagnostics()->entries)if((e.key>>24U)==static_cast<unsigned>(kind))count+=e.count;
    return count;
}


void test_flow_rest_films_and_barriers() {
    for(int mode:{1,2})for(int shift:{-129,-65,-33,0,31,63,127}) {
        World w(transport_config(mode));
        w.reserve_region({shift-64,shift-64,256,256});
        // Fully confined, resting layered powders plus a calm full Water layer.
        for(int y=0;y<24;++y)for(int x=0;x<24;++x)
            w.set(x+shift,y+shift,(x==0||x==23||y==0||y==23)?Material::Wall:
                y<8?Material::Water:y<16?Material::Sand:Material::Dust);
        const auto before=w.content_hash();
        for(int tick=0;tick<180;++tick)(void)w.tick();
        require(w.content_hash()==before,"optional motion reordered a resting packed bed/pool");
        require(transport_events(w,cybersand::PhysicsEvent::PowderMix)==0,"rest mixed powders");
        require(transport_events(w,cybersand::PhysicsEvent::GrainTransport)==0,"rest eroded grains");
        // A supported low-fill film cannot create strong transport or pickup.
        w.clear();w.reserve_region({shift-64,shift-64,256,256});
        for(int x=0;x<24;++x) {
            w.set(x+shift,shift+10,Material::Wall);
            (void)w.set_cell_state(x+shift,shift+9,Material::Water,32,0);
            w.set(x+shift,shift+11,Material::Sand);
            w.set(x+shift,shift+12,Material::Wall);
        }
        for(int y=0;y<13;++y) {
            w.set(shift,shift+y,Material::Wall);
            w.set(shift+23,shift+y,Material::Wall);
        }
        const auto mass=total_liquid(w,shift-30,shift-30,shift+60,shift+60);
        for(int tick=0;tick<90;++tick)(void)w.tick();
        require(total_liquid(w,shift-30,shift-30,shift+60,shift+60)==mass,"film mass changed");
        require(transport_events(w,cybersand::PhysicsEvent::GrainTransport)==0,"film bypassed hard separator");
    }
}

void test_flow_conservation_state_and_workers() {
    for(int mode:{1,2}) for(int policy:{0,1,2}) {
        auto a_config=transport_config(mode,1), b_config=transport_config(mode,4);
        if(policy) { a_config.transport_policy.horizontal[3]=1;b_config.transport_policy.horizontal[3]=1; }
        if(policy==2) { a_config.transport_policy.cadence[3]=60;b_config.transport_policy.cadence[3]=60; }
        World one(a_config),four(b_config);
        for(auto* w:{&one,&four}) {
            w->reserve_region({-192,-192,384,384});
            w->reserve_temperature_region({-192,-192,384,384});
            w->set_simulation_region(cybersand::RectI64{-132,-68,164,164});
            for(int y=0;y<160;++y)for(int x=0;x<160;++x) {
                if(x==0||x==159||y==0||y==159)w->set(x-130,y-66,Material::Wall);
                if(x>=5&&x<40&&y>=5&&y<95)w->set(x-130,y-66,Material::Water);
                if(x==40&&y>=5&&y<87)w->set(x-130,y-66,Material::Wall);
                if(x>=3&&x<113&&y>=108+(x-3)/4&&y<159) {
                    (void)w->set_cell_state(x-130,y-66,Material::Sand,17,23);
                    w->set_temperature(x-130,y-66,315);
                }
            }
        }
        const auto water=total_liquid(one,-130,-66,29,93);
        for(int tick=1;tick<=300;++tick) {
            auto a=one.tick();auto b=four.tick();
            require(a.chunk_allocations+a.temperature_field_allocations+b.chunk_allocations+b.temperature_field_allocations==0,"prepared flow allocated");
            if(tick%30==0) {
                require(one.state_hash()==four.state_hash(),"flow worker state mismatch");
                require(total_liquid(one,-130,-66,29,93)==water,"flow lost Water mass");
            }
        }
        if(mode==2 && policy==0)require(transport_events(one,cybersand::PhysicsEvent::GrainTransport)>0,"strong flow did not erode grains");
        for(int y=-66;y<=93;++y)for(int x=-130;x<=29;++x)if(one.stored_material(x,y)==Material::Sand) {
            require(one.stored_state_a(x,y)==17&&one.stored_state_b(x,y)==23,"pickup changed compact grain state");
            require(one.temperature(x,y)==315,"pickup lost grain temperature");
        }
        require(one.physics_diagnostics()->overflow==0&&four.physics_diagnostics()->overflow==0,"flow telemetry overflow");
        // Existing region exclusion contract: no flow debt accumulates offscreen.
        const auto before=one.content_hash();one.set_simulation_region(cybersand::RectI64{768,768,64,64});
        for(int tick=0;tick<60;++tick)(void)one.tick();
        require(one.content_hash()==before,"excluded flow accumulated movement");
    }
}

void test_water_experiment_policy_runtime() {
    for (std::uint8_t bits = 3; bits <= 8; ++bits) {
        const WaterExperimentPolicy policy(bits, 12);
        const auto maximum = static_cast<std::uint16_t>((1U << bits) - 1U);
        const auto quantize = [maximum](std::uint32_t numerator, std::uint32_t denominator) {
            return static_cast<std::uint16_t>(
                (2U * numerator * maximum + denominator) / (2U * denominator));
        };
        require(policy.version() == 1U && policy.mass_bits() == bits,
                "Water policy identity changed");
        require(policy.maximum() == maximum && policy.film() == quantize(48U, 255U) &&
                    policy.tolerance() == quantize(1U, 255U),
                "Water policy derived lattice values are wrong");
        require(policy.normalized_mass(0U) == 0U &&
                    policy.normalized_mass(maximum) == 255U,
                "Water RG8 endpoints are not normalized");
        for (std::uint16_t mass = 0; mass <= maximum; ++mass) {
            const auto expected = static_cast<std::uint8_t>(
                (2U * mass * 255U + maximum) / (2U * maximum));
            require(policy.normalized_mass(mass) == expected,
                    "Water RG8 nearest-half-up projection changed");
        }

        WorldConfig config{};
        config.water_experiment_policy = policy;
        World world(config);
        world.set(0, 0, Material::Water);
        require(world.liquid_mass(0, 0) == maximum &&
                    world.stored_state_b(0, 0) == 0U,
                "Water set did not use candidate maximum with legacy calm state");

        bool threw = false;
        try {
            (void)world.set_cell_state(0, 0, Material::Water,
                                       static_cast<std::uint16_t>(maximum + 1U), 0U);
        } catch (const std::invalid_argument&) {
            threw = true;
        }
        require(threw, "Water accepted mass above candidate maximum");

        std::array<std::uint8_t, 2> render{};
        for (const auto mass : {std::uint16_t{1},
                                quantize(1U, 2U),
                                static_cast<std::uint16_t>(maximum - 1U), maximum}) {
            require(world.set_cell_state(0, 0, Material::Water, mass, 0U),
                    "Water candidate mass setup was not applied");
            world.copy_render_cells({0, 0, 1, 1}, render, 2U);
            require(render[0] == static_cast<std::uint8_t>(Material::Water) &&
                        render[1] == policy.normalized_mass(mass),
                    "World RG8 Water condition is not normalized");
        }

        require(world.set_cell_state(0, 0, Material::Water, maximum, 12U),
                "Water source setup failed");
        require(world.set_cell_state(1, 0, Material::Water,
                                     static_cast<std::uint16_t>(maximum - 1U), 7U),
                "Water destination setup failed");
        const auto before = world.liquid_mass(0, 0) + world.liquid_mass(1, 0);
        require(cybersand::PrecisionProbe::transfer(
                    world, 0, 0, 1, 0, maximum) == 1U,
                "Water transfer ignored candidate capacity");
        require(world.liquid_mass(0, 0) == maximum - 1U &&
                    world.liquid_mass(1, 0) == maximum &&
                    world.stored_state_b(1, 0) == 12U &&
                    world.liquid_mass(0, 0) + world.liquid_mass(1, 0) == before,
                "Water capacity, max merge, or integer accounting changed");
        require(cybersand::PrecisionProbe::transfer(
                    world, 1, 0, 2, 0, maximum) == maximum,
                "Water repeated transfer did not move the full candidate cell");
        require(world.get(1, 0) == Material::Empty &&
                    world.liquid_mass(2, 0) == maximum &&
                    world.stored_state_b(2, 0) == 12U,
                "Water repeated transfer lost mass or coherence");
        require(world.set_cell_state(2, 0, Material::Water, 0U, 0U),
                "zero Water did not canonicalize an occupied cell");
        require(world.get(2, 0) == Material::Empty,
                "zero Water is not represented as Empty");
    }
}

void test_water_experiment_odd_lattice_boundaries() {
    for (const auto bits : {std::uint8_t{3}, std::uint8_t{5}, std::uint8_t{7}}) {
        const WaterExperimentPolicy policy(bits, 12U);
        const auto maximum = policy.maximum();
        const auto quantize = [maximum](std::uint32_t numerator, std::uint32_t denominator) {
            return static_cast<std::uint16_t>(
                (2U * numerator * maximum + denominator) / (2U * denominator));
        };
        const auto first_nonzero = static_cast<std::uint32_t>(
            (255U + 2U * maximum - 1U) / (2U * maximum));
        require(quantize(first_nonzero - 1U, 255U) == 0U &&
                    quantize(first_nonzero, 255U) == 1U,
                "odd Water lattice low-quantity rounding boundary changed");
        require(quantize(1U, 2U) == static_cast<std::uint16_t>((maximum + 1U) / 2U),
                "odd Water lattice half is not nearest-half-up");

        WorldConfig ledger_config{};
        ledger_config.water_experiment_policy = policy;
        World ledger(ledger_config);
        const std::array<std::uint32_t, 3> physical_numerators{
            first_nonzero - 1U, first_nonzero, 48U};
        std::array<std::uint16_t, physical_numerators.size()> lattice_masses{};
        std::uint64_t initial_integer_ledger = 0U;
        std::int64_t initial_physical_error_numerator = 0;
        for (std::size_t index = 0; index < physical_numerators.size(); ++index) {
            const auto lattice_mass = quantize(physical_numerators[index], 255U);
            lattice_masses[index] = lattice_mass;
            initial_integer_ledger += lattice_mass;
            initial_physical_error_numerator +=
                static_cast<std::int64_t>(lattice_mass) * 255 -
                static_cast<std::int64_t>(physical_numerators[index]) * maximum;
            const auto x = static_cast<std::int64_t>(index * 3U);
            (void)ledger.set_cell_state(x, 0, Material::Water, lattice_mass, 0U);
            require(ledger.liquid_mass(x, 0) == lattice_mass,
                    "initial physical quantity was not represented on the candidate lattice");
        }
        require(initial_physical_error_numerator != 0,
                "initial physical quantization error control became vacuous");
        require(total_liquid(ledger, 0, 0, 7, 0) == initial_integer_ledger,
                "initial candidate integer ledger is wrong");
        for (std::size_t index = 0; index < lattice_masses.size(); ++index) {
            if (lattice_masses[index] == 0U) continue;
            const auto x = static_cast<std::int64_t>(index * 3U);
            require(cybersand::PrecisionProbe::transfer(
                        ledger, x, 0, x + 1, 0, lattice_masses[index]) ==
                        lattice_masses[index],
                    "candidate low quantity did not transfer exactly");
        }
        const auto final_integer_ledger = total_liquid(ledger, 0, 0, 7, 0);
        const auto runtime_integer_drift = static_cast<std::int64_t>(final_integer_ledger) -
                                           static_cast<std::int64_t>(initial_integer_ledger);
        require(runtime_integer_drift == 0,
                "runtime integer drift was confused with initial physical quantization error");

        const auto run_lateral = [bits](std::uint16_t source_mass,
                                        std::uint16_t target_mass,
                                        bool adhesion_enabled) {
            WorldConfig config{};
            config.water_experiment_policy = WaterExperimentPolicy(bits, 12U);
            World world(config);
            world.set_liquid_surface_adhesion_enabled(adhesion_enabled);
            for (std::int64_t x = -1; x <= 2; ++x) world.set(x, 1, Material::Wall);
            world.set(-1, 0, Material::Wall);
            world.set(2, 0, Material::Wall);
            require(world.set_cell_state(0, 0, Material::Water, source_mass, 0U),
                    "lateral source setup failed");
            if (target_mass != 0U) {
                require(world.set_cell_state(1, 0, Material::Water, target_mass, 1U),
                        "lateral target setup failed");
            }
            const auto before = world.liquid_mass(0, 0) + world.liquid_mass(1, 0);
            (void)world.tick();
            require(world.liquid_mass(0, 0) + world.liquid_mass(1, 0) == before,
                    "lateral rounding boundary changed the integer ledger");
            return std::pair{world.liquid_mass(0, 0), world.liquid_mass(1, 0)};
        };

        const auto retained_film = run_lateral(policy.film(), 0U, true);
        require(retained_film.first == policy.film() && retained_film.second == 0U,
                "supported Water film moved at the registered threshold");
        const auto above_film_mass = static_cast<std::uint16_t>(policy.film() + 1U);
        const auto above_film = run_lateral(above_film_mass, 0U, true);
        const auto above_film_request = static_cast<std::uint16_t>(above_film_mass * 3U / 4U);
        require(above_film.first == above_film_mass - above_film_request &&
                    above_film.second == above_film_request,
                "Water did not cross the registered film boundary with exact lateral rounding");

        require(policy.tolerance() == 0U,
                "odd Water lattice tolerance should quantize to zero");
        require(run_lateral(1U, 1U, false) ==
                    std::pair{std::uint16_t{1}, std::uint16_t{1}},
                "equal odd-lattice Water moved across its tolerance boundary");
        require(run_lateral(2U, 1U, false) ==
                    std::pair{std::uint16_t{2}, std::uint16_t{1}},
                "three-quarter lateral request no longer rounds one-unit imbalance to zero");
        require(run_lateral(3U, 1U, false) ==
                    std::pair{std::uint16_t{2}, std::uint16_t{2}},
                "three-quarter lateral request no longer rounds two-unit imbalance to one");
    }
}

void test_water_experiment_policy_validation_and_coherence() {
    for (const auto invalid_policy : {
             std::pair{std::uint8_t{2}, std::uint8_t{0}},
             std::pair{std::uint8_t{9}, std::uint8_t{0}},
             std::pair{std::uint8_t{8}, std::uint8_t{13}}}) {
        bool threw = false;
        try {
            (void)WaterExperimentPolicy(invalid_policy.first, invalid_policy.second);
        } catch (const std::invalid_argument&) {
            threw = true;
        }
        require(threw, "invalid Water experiment policy was accepted");
    }
    bool rest_threw = false;
    try {
        (void)WaterExperimentPolicy(
            8U, 12U, static_cast<cybersand::WaterRestPolicy>(1U));
    } catch (const std::invalid_argument&) {
        rest_threw = true;
    }
    require(rest_threw, "unregistered Water rest policy was accepted");

    WorldConfig mass_identity{};
    mass_identity.water_experiment_policy = WaterExperimentPolicy(3U, 12U);
    WorldConfig coherence_identity = mass_identity;
    coherence_identity.water_experiment_policy = WaterExperimentPolicy(3U, 7U);
    require(World(mass_identity).state_hash() != World(coherence_identity).state_hash(),
            "authoritative Water policy is absent from state identity");

    for (std::uint8_t delay = 0; delay <= 12; ++delay) {
        WorldConfig config{};
        config.water_experiment_policy = WaterExperimentPolicy(8U, delay);
        World world(config);
        world.set_liquid_surface_adhesion_enabled(false);
        for (std::int64_t x = -2; x <= 2; ++x) world.set(x, 1, Material::Wall);
        world.set(-2, 0, Material::Wall);
        world.set(2, 0, Material::Wall);
        require(world.set_cell_state(0, 0, Material::Water, 255U, delay),
                "coherent Water setup failed");
        for (std::uint8_t tick = 1; tick <= delay; ++tick) {
            (void)world.tick();
            require(world.liquid_mass(0, 0) == 255U &&
                        world.stored_state_b(0, 0) == delay - tick,
                    "Water coherence no longer uses pre-decrement suppression");
        }
        (void)world.tick();
        require(world.liquid_mass(0, 0) < 255U,
                "Water did not resume lateral flow after coherence expiry");
        if (delay < 12U) {
            bool threw = false;
            try {
                (void)world.set_cell_state(0, 0, Material::Water, 1U,
                                           static_cast<std::uint8_t>(delay + 1U));
            } catch (const std::invalid_argument&) {
                threw = true;
            }
            require(threw, "Water accepted coherence above the selected policy");
        }
    }
}

void test_water_experiment_coherence_propagation() {
    for (std::uint8_t delay = 0; delay <= 12; ++delay) {
        WorldConfig config{};
        config.water_experiment_policy = WaterExperimentPolicy(8U, delay);
        World falling(config);
        require(falling.set_cell_state(0, 0, Material::Water, 255U, delay) &&
                    falling.stored_state_b(0, 0) == delay,
                "Water coherence creation did not retain the configured value");
        (void)falling.tick();
        require(falling.get(0, 0) == Material::Empty &&
                    falling.liquid_mass(0, 1) == 255U &&
                    falling.stored_state_b(0, 1) == (delay == 0U ? 0U : delay - 1U),
                "Water coherence did not pre-decrement and travel with gravity movement");

        WorldConfig merge_config{};
        merge_config.water_experiment_policy = WaterExperimentPolicy(3U, delay);
        World merge(merge_config);
        for (std::uint8_t source = 0; source <= delay; ++source) {
            for (std::uint8_t destination = 0; destination <= delay; ++destination) {
                require(merge.set_cell_state(0, 0, Material::Water, 1U, source),
                        "coherence merge source setup failed");
                require(merge.set_cell_state(1, 0, Material::Water, 1U, destination),
                        "coherence merge destination setup failed");
                require(cybersand::PrecisionProbe::transfer(
                            merge, 0, 0, 1, 0, 1U) == 1U,
                        "coherence merge transfer failed");
                require(merge.get(0, 0) == Material::Empty &&
                            merge.liquid_mass(1, 0) == 2U &&
                            merge.stored_state_b(1, 0) == std::max(source, destination),
                        "Water coherence max-on-merge changed for a valid configured pair");
            }
        }
    }
}

void test_water_experiment_policy_worker_parity() {
    for (std::uint8_t bits = 3; bits <= 8; ++bits) {
        WorldConfig one_config{};
        one_config.worker_threads = 1U;
        one_config.parallel_job_threshold = 1U;
        one_config.water_experiment_policy = WaterExperimentPolicy(bits, 12U);
        WorldConfig four_config = one_config;
        four_config.worker_threads = 4U;
        World one(one_config);
        World four(four_config);
        for (auto* world : {&one, &four}) {
            world->reserve_region({0, 0, 128, 128});
            world->set_simulation_region(cybersand::RectI64{0, 0, 64, 64});
            for (std::int64_t x = 0; x <= 24; ++x) world->set(x, 24, Material::Wall);
            for (std::int64_t y = 0; y <= 24; ++y) {
                world->set(0, y, Material::Wall);
                world->set(24, y, Material::Wall);
            }
            for (std::int64_t y = 8; y < 16; ++y) {
                for (std::int64_t x = 3; x < 10; ++x) {
                    world->set(x, y, Material::Water);
                }
            }
        }
        const auto expected_mass = total_liquid(one, 0, 0, 63, 63);
        for (std::uint32_t tick = 0; tick < 60U; ++tick) {
            (void)one.tick();
            (void)four.tick();
            require(one.state_hash() == four.state_hash(),
                    "Water candidate differs across worker counts");
            require(total_liquid(one, 0, 0, 63, 63) == expected_mass &&
                        total_liquid(four, 0, 0, 63, 63) == expected_mass,
                    "Water candidate lost integer mass");
        }
    }
}

void test_water_experiment_default_state_hash_correspondence() {
    World implicit_default;
    WorldConfig explicit_config{};
    explicit_config.water_experiment_policy = WaterExperimentPolicy(8U, 12U);
    World explicit_default(explicit_config);
    populate_water_fixture(implicit_default);
    populate_water_fixture(explicit_default);
    require(implicit_default.set_cell_state(10, 6, Material::Water, 128U, 12U) &&
                explicit_default.set_cell_state(10, 6, Material::Water, 128U, 12U),
            "default correspondence coherent fixture setup failed");
    const auto initial_default_hash = implicit_default.state_hash();
    require(initial_default_hash == explicit_default.state_hash(),
            "implicit default and explicit mass8/coherence12 state hashes differ");
    for (std::uint32_t tick = 0; tick < 24U; ++tick) {
        (void)implicit_default.tick();
        (void)explicit_default.tick();
        require(implicit_default.state_hash() == explicit_default.state_hash(),
                "implicit default and explicit mass8/coherence12 behavior diverged");
    }
}


void test_int000_sparse_schema_shadow_equivalence() {
    using cybersand::InteractionRules;
    struct FrozenPairRule {
        Material first;
        Material second;
        Material first_product;
        Material second_product;
        std::uint8_t probability;
    };
    constexpr std::array<FrozenPairRule, 14> frozen_current{{
        {Material::Lava, Material::Water, Material::Stone, Material::Steam, 255U},
        {Material::Fire, Material::Water, Material::Smoke, Material::Steam, 255U},
        {Material::Water, Material::Salt, Material::Brine, Material::Brine, 255U},
        {Material::Water, Material::Sodium, Material::Steam, Material::Fire, 255U},
        {Material::Brine, Material::Sodium, Material::Steam, Material::Fire, 255U},
        {Material::Water, Material::ToxicSludge, Material::Water, Material::Water, 255U},
        {Material::Steam, Material::Ice, Material::Water, Material::Ice, 32U},
        {Material::Water, Material::MoltenGlass, Material::Steam, Material::Glass, 255U},
        {Material::Lava, Material::Glass, Material::Lava, Material::MoltenGlass, 255U},
        {Material::Acid, Material::Metal, Material::Smoke, Material::Rust, 96U},
        {Material::Fire, Material::Gunpowder, Material::Fire, Material::Fire, 255U},
        {Material::Spark, Material::Gunpowder, Material::Empty, Material::Fire, 255U},
        {Material::Spark, Material::Oil, Material::Empty, Material::Fire, 255U},
        {Material::Fire, Material::Brine, Material::Steam, Material::Salt, 64U},
    }};

    const auto frozen_resolve = [&frozen_current](
        Material source, Material target, std::uint8_t roll)
        -> std::optional<cybersand::PairReactionResult> {
        for (const auto& rule : frozen_current) {
            if (roll > rule.probability) continue;
            if (source == rule.first && target == rule.second) {
                return cybersand::PairReactionResult{rule.first_product, rule.second_product};
            }
            if (source == rule.second && target == rule.first) {
                return cybersand::PairReactionResult{rule.second_product, rule.first_product};
            }
        }
        return std::nullopt;
    };

    require(cybersand::kInteractionSchemaId == "cybersand.interactions",
            "INT schema identity changed");
    require(cybersand::kInteractionSchemaVersion == 1U,
            "INT schema version changed");
    require(cybersand::kInteractionProfileId == "int.current-behaviour" &&
                cybersand::kInteractionProfileVersion == 1U,
            "INT current profile identity changed");
    require(InteractionRules::channels().size() == 7U,
            "INT channel catalogue is incomplete");
    require(InteractionRules::pair_rules().size() == frozen_current.size(),
            "INT compact Current rule inventory changed");
    require(InteractionRules::specialized_rules().size() == 19U,
            "INT specialized Current inventory is incomplete");
    require(InteractionRules::layer_kinds().size() == 5U &&
                InteractionRules::authored_layers().empty(),
            "INT Current layering contract changed");
    const auto catalogue_validation = InteractionRules::validate_catalogue();
    require(catalogue_validation.ok &&
                catalogue_validation.duplicate_rule_ids == 0U &&
                catalogue_validation.conflicting_pair_overrides == 0U &&
                catalogue_validation.invalid_family_memberships == 0U &&
                catalogue_validation.unresolved_layer_conflicts == 0U &&
                catalogue_validation.invalid_supersession_links == 0U,
            "INT Current catalogue has unresolved conflicts");
    require(InteractionRules::layer_precedence(cybersand::InteractionLayerKind::ChannelDefault) <
                InteractionRules::layer_precedence(cybersand::InteractionLayerKind::FamilyDefault) &&
                InteractionRules::layer_precedence(cybersand::InteractionLayerKind::FamilyDefault) <
                InteractionRules::layer_precedence(cybersand::InteractionLayerKind::MaterialAdjustment) &&
                InteractionRules::layer_precedence(cybersand::InteractionLayerKind::MaterialAdjustment) <
                InteractionRules::layer_precedence(cybersand::InteractionLayerKind::PairOverride) &&
                InteractionRules::layer_precedence(cybersand::InteractionLayerKind::PairOverride) <
                InteractionRules::layer_precedence(cybersand::InteractionLayerKind::ContextModifier),
            "INT layer precedence changed");
    constexpr std::array<cybersand::InteractionLayerDefinition, 3> synthetic_layers{{
        {"test.family", 1U, "", cybersand::InteractionChannel::Electrical,
         cybersand::InteractionLayerKind::FamilyDefault,
         {cybersand::InteractionParticipantRole::Either,
          "int.family.conductive-base-metal", false, Material::Empty, ""},
         "test.family.effect", "test.pass"},
        {"test.material", 1U, "", cybersand::InteractionChannel::Electrical,
         cybersand::InteractionLayerKind::MaterialAdjustment,
         {cybersand::InteractionParticipantRole::Source,
          "", true, Material::Metal, ""},
         "test.material.effect", "test.pass"},
        {"test.context", 1U, "", cybersand::InteractionChannel::Electrical,
         cybersand::InteractionLayerKind::ContextModifier,
         {cybersand::InteractionParticipantRole::Either,
          "", false, Material::Empty, "wet"},
         "test.context.effect", "test.pass"},
    }};
    const auto material_layer = InteractionRules::compile_layer_from(
        synthetic_layers, cybersand::InteractionChannel::Electrical,
        Material::Metal, Material::Water);
    require(material_layer.matched && !material_layer.conflict &&
                material_layer.layer_index == 1U,
            "INT material adjustment did not override family default");
    const auto context_layer = InteractionRules::compile_layer_from(
        synthetic_layers, cybersand::InteractionChannel::Electrical,
        Material::Metal, Material::Water, "wet");
    require(context_layer.matched && !context_layer.conflict &&
                context_layer.layer_index == 2U,
            "INT context modifier did not override lower-precedence layers");
    constexpr std::array<cybersand::InteractionLayerDefinition, 2> conflicting_layers{{
        {"test.conflict-a", 1U, "", cybersand::InteractionChannel::Combustion,
         cybersand::InteractionLayerKind::FamilyDefault,
         {cybersand::InteractionParticipantRole::Either,
          "int.family.combustible-kernel", false, Material::Empty, ""},
         "test.a", "test.pass"},
        {"test.conflict-b", 1U, "", cybersand::InteractionChannel::Combustion,
         cybersand::InteractionLayerKind::FamilyDefault,
         {cybersand::InteractionParticipantRole::Either,
          "int.family.combustible-kernel", false, Material::Empty, ""},
         "test.b", "test.pass"},
    }};
    const auto conflict = InteractionRules::compile_layer_from(
        conflicting_layers, cybersand::InteractionChannel::Combustion,
        Material::Wood, Material::Fire);
    require(conflict.matched && conflict.conflict,
            "INT equal-precedence matching layers did not report conflict");

    constexpr std::array<cybersand::PairInteractionRule, 2> direction_rules{{
        {"test.ordered", cybersand::interaction_channel_bit(cybersand::InteractionChannel::Electrical),
         cybersand::InteractionTriggerKind::PairContact, cybersand::InteractionMatchKind::Ordered,
         Material::Water, Material::Salt, Material::Brine, Material::Salt, 255U,
         "ordered test", 0U, 1U, "", "test.pass"},
        {"test.symmetric", cybersand::interaction_channel_bit(cybersand::InteractionChannel::Combustion),
         cybersand::InteractionTriggerKind::PairContact, cybersand::InteractionMatchKind::Symmetric,
         Material::Fire, Material::Oil, Material::Smoke, Material::Smoke, 255U,
         "symmetric test", 0U, 1U, "", "test.pass"},
    }};
    const auto ordered_forward = InteractionRules::resolve_pair_from(
        direction_rules, Material::Water, Material::Salt, 0U);
    const auto ordered_reverse = InteractionRules::resolve_pair_from(
        direction_rules, Material::Salt, Material::Water, 0U);
    require(ordered_forward.selected &&
                ordered_forward.source_product == Material::Brine &&
                ordered_forward.target_product == Material::Salt &&
                !ordered_reverse.matched,
            "INT ordered pair semantics are not explicit/testable");
    const auto symmetric_forward = InteractionRules::resolve_pair_from(
        direction_rules, Material::Fire, Material::Oil, 0U);
    const auto symmetric_reverse = InteractionRules::resolve_pair_from(
        direction_rules, Material::Oil, Material::Fire, 0U);
    require(symmetric_forward.selected && symmetric_reverse.selected &&
                symmetric_forward.source_product == Material::Smoke &&
                symmetric_forward.target_product == Material::Smoke &&
                symmetric_reverse.source_product == Material::Smoke &&
                symmetric_reverse.target_product == Material::Smoke,
            "INT symmetric pair semantics are not orientation-independent");

    for (std::size_t index = 0; index < frozen_current.size(); ++index) {
        const auto& expected = frozen_current[index];
        const auto& rule = InteractionRules::pair_rules()[index];
        require(!rule.id.empty() && rule.channels != 0U,
                "INT compact rule lacks stable identity/channel");
        require(rule.trigger == cybersand::InteractionTriggerKind::PairContact,
                "INT compact rule changed trigger class");
        require(rule.match == cybersand::InteractionMatchKind::UnorderedRolePreserving,
                "INT compact rule lost role-preserving unordered matching");
        require(rule.first == expected.first && rule.second == expected.second &&
                    rule.first_product == expected.first_product &&
                    rule.second_product == expected.second_product &&
                    rule.probability == expected.probability,
                "INT authored compact rule differs from frozen pre-migration Current");
        for (std::size_t right = index + 1U; right < InteractionRules::pair_rules().size(); ++right) {
            require(rule.id != InteractionRules::pair_rules()[right].id,
                    "INT compact rule IDs are not unique");
        }
    }

    constexpr std::array<std::uint8_t, 12> rolls{
        0U, 31U, 32U, 33U, 63U, 64U, 65U, 95U, 96U, 97U, 254U, 255U};
    for (std::uint16_t source_id = 0; source_id < cybersand::kMaterialDefinitions.size(); ++source_id) {
        const auto source = static_cast<Material>(source_id);
        bool frozen_has_pair = false;
        for (const auto& rule : frozen_current) {
            frozen_has_pair = frozen_has_pair || rule.first == source || rule.second == source;
        }
        require(cybersand::MaterialRules::has_pair_reactions(source) == frozen_has_pair &&
                    InteractionRules::has_pair_rule(source) == frozen_has_pair,
                "INT migrated pair-participant inventory differs from frozen Current");
        for (std::uint16_t target_id = 0; target_id < cybersand::kMaterialDefinitions.size(); ++target_id) {
            const auto target = static_cast<Material>(target_id);
            for (const auto roll : rolls) {
                const auto expected = frozen_resolve(source, target, roll);
                const auto public_api = cybersand::MaterialRules::pair_reaction(source, target, roll);
                const auto resolved = InteractionRules::resolve_pair(source, target, roll);
                require(expected.has_value() == resolved.selected &&
                            expected.has_value() == public_api.has_value(),
                        "INT compact resolver selection differs from frozen Current");
                if (!expected.has_value()) continue;
                require(resolved.matched &&
                            expected->source_product == resolved.source_product &&
                            expected->target_product == resolved.target_product &&
                            expected->source_product == public_api->source_product &&
                            expected->target_product == public_api->target_product,
                        "INT compact resolver products/roles differ from frozen Current");
            }
        }
    }

    const auto salt_forward =
        InteractionRules::resolve_pair(Material::Water, Material::Salt, 255U);
    const auto salt_reverse =
        InteractionRules::resolve_pair(Material::Salt, Material::Water, 255U);
    require(salt_forward.selected && salt_reverse.selected &&
                salt_forward.source_product == Material::Brine &&
                salt_forward.target_product == Material::Brine &&
                salt_reverse.source_product == Material::Brine &&
                salt_reverse.target_product == Material::Brine,
            "Water/Salt role-preserving unordered resolution changed");

    const auto acid_forward =
        InteractionRules::resolve_pair(Material::Acid, Material::Metal, 96U);
    const auto acid_reverse =
        InteractionRules::resolve_pair(Material::Metal, Material::Acid, 96U);
    require(acid_forward.selected && acid_reverse.selected &&
                acid_forward.source_product == Material::Smoke &&
                acid_forward.target_product == Material::Rust &&
                acid_reverse.source_product == Material::Rust &&
                acid_reverse.target_product == Material::Smoke,
            "Acid/Metal reverse roles were collapsed into symmetric effects");
    require(!InteractionRules::resolve_pair(Material::Acid, Material::Metal, 97U).selected,
            "Acid/Metal probability boundary changed");

    require(!InteractionRules::match_pair(Material::Water, Material::Sand).matched,
            "Water/Sand transport control gained an INT conversion rule");
    require(InteractionRules::in_family("int.family.conductive-base-metal", Material::Metal),
            "base Metal lost explicit conductive membership");
    for (const auto themed : {Material::WroughtIron, Material::Bronze, Material::Copper,
                              Material::SteelPlate, Material::CopperPipe}) {
        require(!InteractionRules::in_family("int.family.conductive-base-metal", themed),
                "themed metal inherited base Metal INT semantics");
    }
    require(InteractionRules::in_family("int.family.reactive-base-glass", Material::Glass),
            "base Glass lost explicit reactive membership");
    for (const auto themed : {Material::StainedGlass, Material::ChemicalGlass, Material::DarkGlass}) {
        require(!InteractionRules::in_family("int.family.reactive-base-glass", themed),
                "themed glass inherited base Glass INT semantics");
    }
    require(InteractionRules::coverage().size() >= 7U &&
                InteractionRules::tuning_passes().size() == 1U,
            "INT coverage/pass metadata is incomplete");
}

int main() {
    struct Test {
        const char* name;
        void (*function)();
    };
    const Test tests[] = {
        {"INT-000 sparse schema shadow equivalence", test_int000_sparse_schema_shadow_equivalence},
        {"flow resting packing, films, barriers and signed seams", test_flow_rest_films_and_barriers},
        {"flow conserved state, temperature, workers and exclusion", test_flow_conservation_state_and_workers},
        {"powder pairs and void-driven rearrangement", test_powder_pair_and_void_policy},
        {"Mercury lanes, sleeping wakes, seams and worker parity", test_mercury_lanes_wake_and_reentry},
        {"granular sampled support policy", test_granular_player_support_policy},
        {"physics diagnostic observer and worker parity", test_physics_diagnostics_observational},
        {"physics diagnostic isolated controls", test_physics_diagnostic_controls},
        {"physics masked source characterisation", test_physics_masked_source_characterisation},
        {"negative coordinates", test_negative_coordinates},
        {"scheduler geometry", test_scheduler_geometry},
        {"sand fall", test_sand_falls_and_stops},
        {"cross chunk", test_cross_chunk_fall},
        {"cross scheduler core", test_cross_scheduler_core_fall},
        {"activity sleep and wake", test_activity_core_sleep_and_wake},
        {"serial/phased behavioral parity", test_serial_and_phased_behavioral_parity},
        {"density swap", test_sand_sinks_through_water},
        {"conserved water", test_conserved_water_levels_and_sleeps},
        {"Water lateral speed", test_water_lateral_front_and_leveling_speed},
        {"level water surface", test_water_surface_column_mass_is_level},
        {"water single/multiworker parity", test_water_single_multiworker_parity},
        {"water storage boundary", test_water_conserves_across_storage_boundaries},
        {"runtime Water experiment policy", test_water_experiment_policy_runtime},
        {"odd-lattice Water boundaries and ledgers", test_water_experiment_odd_lattice_boundaries},
        {"Water experiment validation and coherence", test_water_experiment_policy_validation_and_coherence},
        {"Water coherence gravity and exhaustive merge", test_water_experiment_coherence_propagation},
        {"Water experiment worker parity", test_water_experiment_policy_worker_parity},
        {"default Water experiment state-hash correspondence", test_water_experiment_default_state_hash_correspondence},
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
        {"issue #2 interest resume boundaries", test_interest_resume_boundaries},
        {"issue #2 sleeping region transitions", test_interest_sleep_transitions},
        {"issue #2 conservation and worker determinism", test_interest_conservation_and_worker_determinism},
        {"issues #1/#2 failed re-entry and recovery", test_interest_failed_tick_recovery},
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
