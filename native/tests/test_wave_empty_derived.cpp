// PUBPRES derived-Empty lifecycle adversaries. Compile this exact apparatus
// against both the occupied-bounds control and candidate native source; compare
// every complete semantic checkpoint, not only final material images. The
// candidate is also built with CYBERSAND_WAVE_VERIFY_EMPTY_DERIVED so actual
// cells/weight/meta are checked before reuse and after certification.
#include "cybersand/world.hpp"

#include <array>
#include <cstdint>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using namespace cybersand;

void require(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}

void rect(World& world, int x, int y, int width, int height, Material material) {
    for (int yy = y; yy < y + height; ++yy)
        for (int xx = x; xx < x + width; ++xx) world.set(xx, yy, material);
}

WorldConfig configuration(unsigned workers) {
    WorldConfig cfg;
    cfg.chunk_size = 64;
    cfg.activity_block_size = 16;
    cfg.scheduling_core_size = 16;
    cfg.worker_threads = workers;
    cfg.parallel_job_threshold = 2;
    cfg.maximum_chunk_count = 512;
    cfg.active_chunk_capacity = 512;
    cfg.active_core_capacity = 4096;
    cfg.wave_flow.enabled = true;
    cfg.wave_flow.sleep_after = 90;
    return cfg;
}

void checkpoint(World& world, std::vector<std::uint64_t>& values) {
    require(!world.has_failed(), "lifecycle World failed");
    values.push_back(world.physical_state_hash()); // includes clean/dry/flux/weight/meta
    values.push_back(world.state_hash());
    values.push_back(world.content_hash());
    const auto ledger = world.quantity_ledger();
    values.push_back(ledger.water_visible + ledger.water_overfill + ledger.water_ballistic);
    values.push_back(ledger.water_ballistic);
    values.push_back(world.transient_contact_count(1));
    values.push_back(static_cast<std::uint64_t>(world.transient_contact_impulse_x(1)));
    values.push_back(static_cast<std::uint64_t>(world.transient_contact_impulse_y(1)));
}

void authoring_and_reentry(unsigned workers, bool hybrid, std::vector<std::uint64_t>& values) {
    auto cfg = configuration(workers);
    cfg.wave_flow.substeps = hybrid ? 3 : 1;
    cfg.wave_flow.flux_smoothing = hybrid ? 16 : 0;
    cfg.wave_flow.spill.enabled = hybrid;
    cfg.wave_flow.spill.full_face = hybrid ? 1 : 0;
    cfg.wave_flow.spill.fall = hybrid ? 3 : 1;
    cfg.ballistic_water.enabled = hybrid;
    const RectI64 bounds{-128, -192, 256, 384};
    auto world = std::make_unique<World>(cfg);
    world->reserve_region(bounds);
    world->configure_transient_obstacles(bounds, true);
    rect(*world, -128, -192, 256, 1, Material::Wall);
    rect(*world, -128, 191, 256, 1, Material::Wall);
    rect(*world, -128, -192, 1, 384, Material::Wall);
    rect(*world, 127, -192, 1, 384, Material::Wall);
    rect(*world, -127, 96, 64, 95, Material::Water);
    rect(*world, -63, 176, 190, 15, Material::Water);
    require(world->set_transient_obstacle(112, -160, 1), "initial body refused");
    for (int tick = 0; tick < 52; ++tick) {
        if (tick == 4) {
            // These writes enter previously Empty halves. Generic material
            // workers subsequently move/react them and merge their effects.
            rect(*world, -110, -150, 3, 3, Material::Sand);
            rect(*world, -70, -150, 3, 3, Material::Oil);
            rect(*world, -30, -150, 3, 3, Material::Wall);
            rect(*world, 10, -150, 3, 3, Material::Wood);
            rect(*world, 11, -153, 1, 3, Material::Fire);
            rect(*world, 70, -150, 3, 3, Material::Acid);
            rect(*world, 70, -147, 3, 1, Material::Metal);
        }
        if (tick == 8) {
            world->clear_transient_obstacles();
            require(world->set_transient_obstacle(-48, -96, 1), "entered body refused");
            require(world->set_cell_state(-48, -97, Material::Water, 255, 0), "body pressure seed refused");
        }
        if (tick == 12) {
            world->clear_transient_obstacles();
            require(world->set_transient_obstacle(112, -160, 1), "moved body refused");
        }
        // X begins inside the first half; Y begins inside a chunk. Neither
        // partial selection may recertify cells skipped by the old dry path.
        if (tick == 16) world->set_simulation_region(RectI64{-112, -176, 208, 288});
        if (tick == 18) {
            world->set(-120, -180, Material::Stone); // outside selected cores
            world->set(108, -178, Material::Oil);
        }
        if (tick == 20) world->set_simulation_region(std::nullopt);
        if (tick == 24) {
            // Descending Water crosses the negative chunk seam into a half
            // that previously certified zero storage; keep vertical settling.
            require(world->set_cell_state(-16, -65, Material::Water, 765, 0), "seam inflow refused");
            require(world->set_cell_state(-15, -65, Material::Water, 255, 0), "lateral inflow refused");
        }
        if (tick == 28) {
            rect(*world, -32, -80, 32, 64, Material::Empty); // formerly wet derived heads
            world->set(48, -80, Material::Sand);
            require(world->relocate_stored_cell(48, -80, 80, -80), "owner relocation refused");
        }
        if (tick == 32) world->set_simulation_region(RectI64{-112, -144, 16, 96});
        if (tick == 36) world->set_simulation_region(std::nullopt);
        if (tick == 40) {
            // Ordinary authored save/reopen recreates cell authority in a new
            // World. It does not pretend Wave's unsupported physical-state
            // serialization can preserve retained momentum.
            auto reopened = std::make_unique<World>(cfg);
            reopened->reserve_region(bounds);
            reopened->configure_transient_obstacles(bounds, true);
            for (int y = -192; y < 192; ++y)
                for (int x = -128; x < 128; ++x) {
                    const auto material = world->stored_material(x, y);
                    if (material != Material::Empty)
                        require(reopened->set_cell_state(x, y, material, world->stored_state_a(x, y),
                                                        world->stored_state_b(x, y)), "authored reopen refused");
                    reopened->set_temperature(x, y, world->stored_temperature(x, y));
                }
            require(reopened->set_transient_obstacle(112, -160, 1), "reopened body refused");
            world = std::move(reopened);
        }
        (void)world->tick();
        checkpoint(*world, values);
    }
}

void paused_flux_and_reentry(unsigned workers, std::vector<std::uint64_t>& values) {
    auto cfg = configuration(workers);
    cfg.chunk_size = 128;
    cfg.scheduling_core_size = 64;
    World world(cfg);
    world.reserve_region({0, 0, 192, 192});
    rect(world, 0, 0, 192, 1, Material::Wall);
    rect(world, 0, 191, 192, 1, Material::Wall);
    rect(world, 0, 0, 1, 192, Material::Wall);
    rect(world, 191, 0, 1, 192, Material::Wall);
    world.configure_transient_obstacles({0, 0, 192, 192}, true);
    require(world.set_transient_obstacle(180, 10, 1), "paused body refused");
    for (int tick = 0; tick < 4; ++tick) { (void)world.tick(); checkpoint(world, values); }
    require(world.set_cell_state(63, 20, Material::Water, 192, 0), "paused source refused");
    require(world.set_cell_state(64, 20, Material::Water, 64, 0), "paused receiver refused");
    (void)world.tick();
    const auto flux = world.wave_flow_flux(63, 21);
    const auto receiver = world.stored_state_a(64, 21);
    const auto quantity = world.water_quantity({0, 0, 192, 192});
    require(flux != 0 && receiver != 0, "paused fixture produced no retained face");
    checkpoint(world, values);
    world.set_simulation_region(RectI64{0, 0, 64, 192});
    for (int tick = 0; tick < 24; ++tick) {
        (void)world.tick();
        require(world.wave_flow_flux(63, 21) == flux && world.stored_state_a(64, 21) == receiver,
                "empty cache retired a paused authoritative face");
        require(world.water_quantity({0, 0, 192, 192}) == quantity, "paused Water disappeared");
        checkpoint(world, values);
    }
    world.set_simulation_region(std::nullopt);
    for (int tick = 0; tick < 4; ++tick) { (void)world.tick(); checkpoint(world, values); }
    require(world.water_quantity({0, 0, 192, 192}) == quantity, "reentry changed conserved Water");
}

void tall_group_fallback(unsigned workers, std::vector<std::uint64_t>& values) {
    auto cfg = configuration(workers);
    cfg.chunk_size = 8;
    cfg.activity_block_size = 8;
    cfg.scheduling_core_size = 8;
    cfg.maximum_chunk_count = 512;
    cfg.wave_flow.substeps = 3;
    World world(cfg);
    const RectI64 bounds{-8, -16, 16, 560}; // 70 chunks crosses the 64-entry scratch-cache boundary
    world.reserve_region(bounds);
    world.configure_transient_obstacles(bounds, true);
    rect(world, -8, -16, 16, 1, Material::Wall);
    rect(world, -8, 543, 16, 1, Material::Wall);
    rect(world, -8, -16, 1, 560, Material::Wall);
    rect(world, 7, -16, 1, 560, Material::Wall);
    require(world.set_transient_obstacle(0, 0, 1), "tall body refused");
    for (int tick = 0; tick < 16; ++tick) {
        if (tick == 4) {
            require(world.set_cell_state(1, 493, Material::Water, 1020, 0), "tall boundary inflow refused");
            world.set(-2, 516, Material::Sand);
        }
        if (tick == 7) world.set_simulation_region(RectI64{-8, 8, 16, 536});
        if (tick == 10) world.set_simulation_region(std::nullopt);
        (void)world.tick();
        checkpoint(world, values);
    }
}

void mask_absence_and_return(unsigned workers, std::vector<std::uint64_t>& values) {
    auto cfg = configuration(workers);
    cfg.wave_flow.substeps = 3;
    cfg.wave_flow.spill.enabled = true;
    cfg.wave_flow.spill.fall = 3;
    World world(cfg);
    world.reserve_region({-64, -64, 192, 256});
    world.configure_transient_obstacles({-64, -64, 192, 256}, true);
    rect(world, -64, 191, 192, 1, Material::Wall);
    rect(world, -64, -64, 1, 256, Material::Wall);
    rect(world, 127, -64, 1, 256, Material::Wall);
    require(world.set_transient_obstacle(112, -32, 1), "applicability initial body refused");
    for (int tick = 0; tick < 24; ++tick) {
        if (tick == 4) world.clear_transient_obstacles();
        if (tick == 6) {
            require(world.set_cell_state(-16, -1, Material::Water, 1020, 0), "no-mask inflow refused");
            world.set(40, -32, Material::Oil);
            world.set(48, -32, Material::Sand);
            world.set(56, -32, Material::Wall);
        }
        if (tick == 8) world.set_simulation_region(RectI64{-48, -48, 144, 192});
        if (tick == 10) {
            world.set(-60, -60, Material::Stone); // paused owner edit
            require(world.set_transient_obstacle(32, 96, 1), "returning mask refused");
        }
        if (tick == 12) world.set_simulation_region(std::nullopt);
        if (tick == 14) {
            world.clear_transient_obstacles();
            world.configure_transient_obstacles({-16, -16, 32, 32});
            require(world.set_transient_obstacle(0, 0, 1), "small configured mask refused");
        }
        if (tick == 16) {
            world.clear_transient_obstacles();
            world.configure_transient_obstacles({-64, -64, 192, 256}, true);
            require(world.set_transient_obstacle(112, -32, 1), "expanded mask refused");
        }
        (void)world.tick();
        checkpoint(world, values);
    }
}
} // namespace

int main(int argc, char** argv) {
    try {
        const auto workers = argc == 2 ? static_cast<unsigned>(std::stoul(argv[1])) : 1U;
        require(argc <= 2 && (workers == 1U || workers == 4U), "expected one or four workers");
        std::vector<std::uint64_t> values;
        authoring_and_reentry(workers, false, values);
        authoring_and_reentry(workers, true, values);
        paused_flux_and_reentry(workers, values);
        tall_group_fallback(workers, values);
        mask_absence_and_return(workers, values);
        std::cout << "{\"schema\":\"pubpres-empty-derived-lifecycle-v2\",\"workers\":" << workers
                  << ",\"checkpoint_fields\":[\"physical\",\"state\",\"content\",\"water\",\"ballistic\",\"contacts\",\"impulse_x\",\"impulse_y\"],\"checkpoints\":[";
        for (std::size_t i = 0; i < values.size(); ++i) std::cout << (i == 0 ? "" : ",") << values[i];
        std::cout << "]}\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
