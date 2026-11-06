// Workbench pressure-flow column dispatch (reference, cached and cached_dormant)
// must reproduce the serial column pass and its subsequent row repair, wake
// decisions and kernel state.
#include "cybersand/world.hpp"

#include <array>
#include <iostream>
#include <memory>
#include <span>
#include <stdexcept>
#include <tuple>
#include <vector>

namespace {
using namespace cybersand;
unsigned checks = 0;
void require(bool condition, const char* message) {
    ++checks;
    if (!condition) throw std::runtime_error(message);
}

void fill(World& w, int x, int y, int width, int height, Material material) {
    for (int dy = 0; dy < height; ++dy)
        for (int dx = 0; dx < width; ++dx)
            w.set(x+dx, y+dy, material);
}

std::unique_ptr<World> fixture(unsigned workers, bool parallel_heads, int variant) {
    auto words = LiquidSolverPolicy::default_request();
    words[21] = 3; // Water pressure_flow_v1
    words[22] = variant; // 0 reference, 1 cached, 2 cached_dormant
    const auto pf = LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
    require(pf.accepted(), "pressure policy");
    WorldConfig cfg;
    cfg.liquid_solver_policy = *pf.policy;
    cfg.workbench_parallel_pressure_heads = parallel_heads;
    cfg.worker_threads = workers;
    cfg.chunk_size = cfg.scheduling_core_size = 16;
    cfg.activity_block_size = 8;
    cfg.maximum_chunk_count = cfg.active_chunk_capacity = cfg.active_core_capacity = 256;
    cfg.parallel_job_threshold = 2;
    auto w = std::make_unique<World>(cfg);
    w->configure_transient_obstacles({-96,-64,240,128});

    // The tanks cross signed chunk boundaries, with missing chunk columns
    // between tanks. One lid touches Water, one encloses a real air pocket.
    for (const int x : {-83,-29,39,102}) {
        fill(*w,x,14,25,1,Material::Wall);
        fill(*w,x,-16,1,30,Material::Wall);
        fill(*w,x+24,-16,1,30,Material::Wall);
        fill(*w,x+1,-9,23,23,Material::Water);
    }
    fill(*w,-82,-10,10,1,Material::Wall);
    fill(*w,39,-16,25,1,Material::Wall);
    // An unsupported run ending exactly at a chunk edge, above a resident
    // column separated by unallocated y chunks. Include a liquid top load.
    fill(*w,-24,-52,3,4,Material::Water);
    w->set(-23,-53,Material::Oil);
    return w;
}

auto diagnostics(const PressureFlowDiagnostics& d) {
    return std::tie(d.head_cells,d.unknown_heads,d.gas_visited,d.gas_regions,
                    d.atmosphere_regions,d.chunk_allocations,d.woken_blocks);
}

auto work(const PressureOptimizationCounters& c) {
    return std::tie(c.columns_recomputed,c.rows_recomputed,c.base_cells_written,
                    c.final_cells_written,c.gas_reference_passes,c.water_material_calls,c.water_motion_calls,
                    c.certificate_invalidation_cells,c.certificate_attempts,c.certificate_reuses,
                    c.certificate_layer_activations);
}

void compare(const World& reference, const World& candidate) {
    require(reference.physical_state_hash() == candidate.physical_state_hash(), "physical state");
    // Portable state includes pressure flow/overfill, gas compartments and
    // their identities, history and ledger. The derived prepared heads do not.
    require(reference.save_physical_state() == candidate.save_physical_state(), "CYPS physical bytes");
    require(reference.quantity_ledger() == candidate.quantity_ledger(), "quantity ledger");
    require(diagnostics(reference.pressure_flow_diagnostics()) == diagnostics(candidate.pressure_flow_diagnostics()),
            "pressure diagnostics and wakes");
    require(work(reference.pressure_optimization_snapshot().counters) == work(candidate.pressure_optimization_snapshot().counters),
            "pressure preparation work");
    std::vector<ChunkCoord> chunks(reference.chunk_count()), other(candidate.chunk_count());
    require(reference.copy_pressure_head_chunk_coordinates(chunks) == chunks.size() &&
            candidate.copy_pressure_head_chunk_coordinates(other) == other.size() && chunks == other, "chunk roster");
    const int size = reference.config().chunk_size;
    for (const auto coord : chunks) {
        for (int y = 0; y < size; ++y) {
            for (int x = 0; x < size; ++x) {
                const auto cx = coord.x*size+x, cy = coord.y*size+y;
                require(reference.prepared_pressure_head(cx,cy) == candidate.prepared_pressure_head(cx,cy), "column or row head");
            }
        }
    }
}

void run(int variant) {
    std::array<std::unique_ptr<World>,4> worlds{fixture(1,false,variant),fixture(6,false,variant),
                                                fixture(1,true,variant),fixture(6,true,variant)};
    std::uint64_t unknown = 0, wakes = 0, live_gas = 0;
    for (int tick = 0; tick < 160; ++tick) {
        std::array<TickStats,4> stats;
        for (std::size_t arm = 0; arm < worlds.size(); ++arm) {
            auto& w = *worlds[arm];
            // Apply a changed head far above sleeping blocks. Stage two
            // translated rigid masks and retire them without rewriting Water.
            if (tick == 12) fill(w,104,-30,12,21,Material::Water);
            if (tick == 18 || tick == 23) {
                w.clear_transient_obstacles();
                for (int x = 0; x < 6; ++x)
                    require(w.set_transient_obstacle(-25+x+(tick==23 ? 3 : 0),-10,1), "mask installation");
            }
            if (tick == 27) w.clear_transient_obstacles();
            if (tick == 31) w.set(45,-16,Material::Empty); // vent the sealed pocket
            stats[arm] = w.tick();
        }
        const auto d = worlds[0]->pressure_flow_diagnostics();
        unknown += d.unknown_heads;
        wakes += d.woken_blocks;
        live_gas += worlds[0]->gas_compartments().size();
        for (std::size_t arm = 1; arm < worlds.size(); ++arm) {
            compare(*worlds[0], *worlds[arm]);
            require(stats[0].phase_jobs == stats[arm].phase_jobs &&
                    stats[0].active_blocks_after == stats[arm].active_blocks_after &&
                    stats[0].visited_cells == stats[arm].visited_cells, "tick scheduling/active blocks");
        }
    }
    const auto counters = worlds[0]->pressure_optimization_snapshot().counters;
    std::cout << "variant=" << variant << " cert_reuses=" << counters.certificate_reuses
              << " cert_invalidations=" << counters.certificate_invalidation_cells << " unknown=" << unknown << " wakes=" << wakes << " gas_samples=" << live_gas << '\n';
    require(unknown > 0 && live_gas > 0 && wakes > 0, "fixture must exercise lid repair, sealed gas and pressure wake");
}
}

// Part of the native `tests` binary (Makefile TEST_SOURCES), so the normal,
// ASan/UBSan and TSan families all run the parallel head path.
void test_workbench_pressure_heads_parallel_exact() {
    for (const int variant : {0, 1, 2}) run(variant);
    std::cout << "WORKBENCH_PRESSURE_HEADS checks=" << checks << '\n';
}
