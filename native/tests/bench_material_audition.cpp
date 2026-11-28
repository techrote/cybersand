// Compile this identical probe against accepted main and the candidate.  The
// accepted-main build has no audition header and runs only the default arm.
// Timing is advisory; native state/count equality is checked by the reducer.
#include "cybersand/world.hpp"
#include "cybersand/interaction_rules.hpp"
#if __has_include("cybersand/material_audition.hpp")
#include "cybersand/material_audition.hpp"
#define CYBERSAND_AUDITION_BENCH 1
#else
#define CYBERSAND_AUDITION_BENCH 0
#endif

#include <algorithm>
#include <array>
#include <chrono>
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace {
using namespace cybersand;
using Clock = std::chrono::steady_clock;

void fill(World& world, int side) {
    world.reserve_region({0, 0, side, side});
    // Repeated ordinary contained apparatus: a granular/oil sorting bay, a
    // Paste reservoir with a low aperture, and confined Salt/Water contacts.
    // Coordinates, construction, tick budget and worker settings are identical
    // in both sources and all profile arms. No input is injected during timing.
    for (int oy = 0; oy < side; oy += 128) for (int ox = 0; ox < side; ox += 128) {
        for (int y = 1; y < 126; ++y) for (int x = 1; x < 126; ++x) {
            Material material = Material::Empty;
            if (x == 1 || x == 125 || y == 125 || x == 62 || y == 64) material = Material::Wall;
            else if (x > 4 && x < 58 && y > 4 && y < 25) material = Material::Sand;
            else if (x > 4 && x < 58 && y >= 25 && y < 59) material = Material::Oil;
            else if (x > 67 && x < 93 && y > 8 && y < 61) material = Material::Paste;
            else if (y > 68 && x > 4 && x < 121) {
                if (x % 4 == 0 || y % 4 == 0) material = Material::Wall;
                else if (y % 4 == 1) material = Material::Salt;
                else material = Material::Water;
            }
            if (material != Material::Empty) world.set(ox + x, oy + y, material);
        }
    }
}

#if CYBERSAND_AUDITION_BENCH
MaterialAuditionProfile profile(std::string_view mode) {
    MaterialAuditionProfile value;
    value.profile_id = std::string(mode);
    if (mode == "equivalent") {
        for (std::size_t id = 0; id < kMaterialDefinitions.size(); ++id) {
            const auto material = static_cast<Material>(id);
            if (material_audition_supports_density(material)) value.density[id] = kMaterialDefinitions[id].density;
            if (material_audition_supports_viscosity(material)) value.viscosity[id] = kMaterialDefinitions[id].viscosity_index;
        }
        for (std::size_t slot = 0; slot < kPairInteractionRules.size(); ++slot)
            value.probability_threshold[slot] = kPairInteractionRules[slot].probability;
    } else if (mode == "modified") {
        value.density[static_cast<std::size_t>(Material::Sand)] = 500;
        value.viscosity[static_cast<std::size_t>(Material::Paste)] = 0;
        value.probability_threshold[2] = 0;
    }
    return value;
}
#endif

void sample(int side, int workers, int ticks, int repeat, std::string_view mode) {
    WorldConfig config;
    config.worker_threads = static_cast<std::uint32_t>(workers);
    World world(config);
    fill(world, side);
    const auto initial_content = world.content_hash();
    const auto initial_tick = world.tick_index();
    const auto initial_hard_revision = world.hard_surface_revision();
    std::uint64_t scanned_cells = 0, woken_blocks = 0;
    double activation_ms = 0.0;
#if CYBERSAND_AUDITION_BENCH
    if (mode != "default") {
        const auto identity = world.material_audition_world_id();
        const auto proposed = profile(mode);
        const auto activation_begin = Clock::now();
        const auto result = world.apply_material_audition(identity, 0, proposed);
        activation_ms = std::chrono::duration<double, std::milli>(Clock::now() - activation_begin).count();
        if (!result.applied() || world.material_audition_world_id() != identity ||
            world.content_hash() != initial_content || world.tick_index() != initial_tick ||
            world.hard_surface_revision() != initial_hard_revision)
            throw std::runtime_error("profile activation changed live World identity/content/tick/collision state");
        scanned_cells = result.scanned_cells;
        woken_blocks = result.woken_blocks;
    }
#else
    (void)initial_tick;
    (void)initial_hard_revision;
#endif
    std::uint64_t moved = 0, visited = 0;
    std::uint32_t observed_workers = 0;
    std::vector<double> timings;
    timings.reserve(static_cast<std::size_t>(ticks));
    for (int tick = 0; tick < ticks; ++tick) {
        const auto begin = Clock::now();
        const auto result = world.tick();
        timings.push_back(std::chrono::duration<double, std::milli>(Clock::now() - begin).count());
        moved += result.moved_cells;
        visited += result.visited_cells;
        observed_workers = std::max(observed_workers, result.worker_threads_observed);
    }
    std::array<std::uint64_t, kMaterialDefinitions.size()> counts{};
    for (int y=0; y<side; ++y) for (int x=0; x<side; ++x)
        ++counts[static_cast<std::size_t>(world.stored_material(x,y))];
    double elapsed = 0;
    for (const auto duration : timings) elapsed += duration;
    std::sort(timings.begin(), timings.end());
    const auto median = timings[timings.size()/2];
    const auto p95 = timings[std::min(timings.size()-1, timings.size()*95/100)];
    std::cout << "{\"schema\":\"material-audition-performance-v1\",\"candidate_api\":"
              << (CYBERSAND_AUDITION_BENCH ? "true" : "false") << ",\"side\":" << side
              << ",\"workers\":" << workers << ",\"observed_workers\":" << observed_workers
              << ",\"ticks\":" << ticks << ",\"repeat\":" << repeat << ",\"profile\":\"" << mode
              << "\",\"activation_ms\":" << activation_ms << ",\"scanned_cells\":" << scanned_cells
              << ",\"woken_blocks\":" << woken_blocks << ",\"elapsed_ms\":" << elapsed
              << ",\"tick_median_ms\":" << median << ",\"tick_p95_ms\":" << p95
              << ",\"visited_cells\":" << visited << ",\"moved_cells\":" << moved
              << ",\"initial_content_hash\":\"" << initial_content << "\",\"content_hash\":\""
              << world.content_hash() << "\",\"physical_hash\":\"" << world.physical_state_hash()
              << "\",\"physical_hash_version\":" << world.physical_state_hash_version()
              << ",\"counts\":{";
    bool comma = false;
    for (std::size_t id=0; id<counts.size(); ++id) if (counts[id] != 0) {
        if (comma) std::cout << ',';
        comma = true;
        std::cout << '"' << id << "\":" << counts[id];
    }
    std::cout << "}}\n" << std::flush;
}
}

int main(int argc, char** argv) try {
    const int ticks = argc > 1 ? std::stoi(argv[1]) : 96;
    const int repeats = argc > 2 ? std::stoi(argv[2]) : 5;
    if (ticks < 1 || ticks > 600 || repeats < 1 || repeats > 20) throw std::runtime_error("bounded ticks/repeats required");
    for (int repeat=0; repeat<repeats; ++repeat) for (const int side : {256, 1024}) for (const int workers : {1, 4}) {
        std::vector<std::string_view> modes{"default"};
#if CYBERSAND_AUDITION_BENCH
        modes = {"default", "equivalent", "modified"};
        if (repeat % 2) std::reverse(modes.begin(), modes.end());
#endif
        for (const auto mode : modes) sample(side, workers, ticks, repeat, mode);
    }
    return 0;
} catch (const std::exception& error) {
    std::cerr << "MATERIAL_AUDITION_BENCH_FAILED " << error.what() << '\n';
    return 1;
}
