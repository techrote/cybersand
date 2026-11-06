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

std::unique_ptr<World> fixture(unsigned workers, bool parallel_heads, int variant,
                               bool force_reference = false, bool gas_enabled = true) {
    auto words = LiquidSolverPolicy::default_request();
    words[21] = 3; // Water pressure_flow_v1
    words[22] = variant; // 0 reference, 1 cached, 2 cached_dormant
    if (!gas_enabled) {
        const auto count_at=words.size()-2U;
        words[count_at]=1;
        words.insert(words.begin()+static_cast<std::ptrdiff_t>(count_at)+1,
                     {3, 1, 2, 0, 64}); // accepted pressure block: gas=off
    }
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
    if (force_reference) cfg.pressure_optimization.index_chunk_capacity = 1;
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
                    c.certificate_layer_activations,
                    // The pooled gas seed pre-pass and label pass book the same work.
                    c.gas_seed_cells,c.gas_seed_probes,c.gas_bfs_cells,c.gas_bfs_probes,c.gas_bfs_nodes,
                    c.gas_relabel_cells,c.gas_identity_nodes,c.gas_restart_fallbacks,
                    c.gas_component_reuses,c.gas_member_validations,c.gas_reuses);
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

void compare_run_repair_arms(const World& reference, const World& candidate,
                             const World& forced, const TickStats& a,
                             const TickStats& b, const TickStats& c) {
    const auto projection = LiquidStateProjection::PressureVariantEquivalenceV1;
    require(reference.liquid_comparison_hash(projection) ==
            candidate.liquid_comparison_hash(projection), "reference versus repaired physical projection");
    require(candidate.liquid_comparison_hash(projection) ==
            forced.liquid_comparison_hash(projection), "repaired versus forced physical projection");
    require(candidate.physical_state_hash()==forced.physical_state_hash(),
            "same variant raw complete physical hash");
    require(candidate.save_physical_state()==forced.save_physical_state(),
            "same variant exact CYPS continuation bytes");
    require(reference.quantity_ledger()==candidate.quantity_ledger() &&
            candidate.quantity_ledger()==forced.quantity_ledger(), "quantity ledgers");
    require(reference.gas_next_id()==candidate.gas_next_id() &&
            candidate.gas_next_id()==forced.gas_next_id(), "gas next identity");
    require(reference.gas_topology_revision()==candidate.gas_topology_revision() &&
            candidate.gas_topology_revision()==forced.gas_topology_revision(),
            "gas topology revisions");
    require(reference.gas_history().size()==candidate.gas_history().size() &&
            candidate.gas_history().size()==forced.gas_history().size(), "gas history sizes");
    require(reference.gas_compartments().size()==candidate.gas_compartments().size() &&
            candidate.gas_compartments().size()==forced.gas_compartments().size(),
            "gas compartment counts");
    require(reference.pressure_flow_diagnostics().woken_blocks ==
            candidate.pressure_flow_diagnostics().woken_blocks &&
            candidate.pressure_flow_diagnostics().woken_blocks ==
            forced.pressure_flow_diagnostics().woken_blocks, "wake decisions");
    require(a.phase_jobs==b.phase_jobs && b.phase_jobs==c.phase_jobs &&
            a.visited_cells==b.visited_cells && b.visited_cells==c.visited_cells &&
            a.active_blocks_after==b.active_blocks_after &&
            b.active_blocks_after==c.active_blocks_after, "phase and activity scheduling");

    std::vector<ChunkCoord> coords(reference.chunk_count()), repaired(candidate.chunk_count()), full(forced.chunk_count());
    require(reference.copy_pressure_head_chunk_coordinates(coords)==coords.size() &&
            candidate.copy_pressure_head_chunk_coordinates(repaired)==repaired.size() &&
            forced.copy_pressure_head_chunk_coordinates(full)==full.size(), "head roster copied");
    require(coords==repaired && coords==full, "resident chunk coordinates exact");
    const int size=reference.config().chunk_size;
    for (const auto coord:coords) for (int y=0;y<size;++y) for(int x=0;x<size;++x) {
        const auto wx=coord.x*size+x, wy=coord.y*size+y;
        const auto head=reference.prepared_pressure_head(wx,wy);
        require(head==candidate.prepared_pressure_head(wx,wy) &&
                head==forced.prepared_pressure_head(wx,wy),
                "every resident prepared head status and signed value");
    }
}

void run_run_repair_differential(int variant, unsigned workers, bool parallel_heads, bool gas) {
    auto reference=fixture(workers,parallel_heads,0,false,gas);
    auto repaired=fixture(workers,parallel_heads,variant,false,gas);
    auto forced=fixture(workers,parallel_heads,variant,true,gas);
    require(forced->chunk_count()>1U, "force-reference arm has multiple chunks");
    for (int tick=0;tick<96;++tick) {
        std::array<TickStats,3> observations{};
        std::array<World*,3> worlds{reference.get(),repaired.get(),forced.get()};
        for(std::size_t arm=0;arm<worlds.size();++arm) {
            auto& w=*worlds[arm];
            // Deterministic sparse/high-churn edits at signed positions, run
            // floors, foreign-liquid interfaces and chunk-Y seams.
            if ((tick%7)==0) {
                const auto x=-79+(tick*11)%17, y=-8+(tick*13)%20;
                if ((tick&1)!=0) w.set(x,y,Material::Empty);
                else (void)w.set_cell_state(x,y,Material::Water,125,0);
            }
            if ((tick%9)==0) {
                const auto x=40+(tick*5)%22, y=-13+(tick*7)%24;
                w.set(x,y,(tick%3)==0 ? Material::Oil : Material::Water);
            }
            if ((tick%11)==0) w.set(-23,-53,(tick&1) ? Material::Oil : Material::Water);
            if ((tick%13)==0) {
                w.clear_transient_obstacles();
                for(int i=0;i<5;++i)
                    require(w.set_transient_obstacle(-25+i+(tick%3),-10,1), "moving transient mask");
            }
            if (tick==36) w.set(45,-16,Material::Empty); // sealed vent
            if (tick==51) w.set(45,-16,Material::Wall); // reseal
            if (tick==73) w.set(1,11,Material::Water); // cold sparse island
            if (tick==79) w.set(1,11,Material::Empty);
            observations[arm]=w.tick();
        }
        compare_run_repair_arms(*reference,*repaired,*forced,
                                observations[0],observations[1],observations[2]);
    }
    const auto rc=repaired->pressure_optimization_snapshot().counters;
    const auto fc=forced->pressure_optimization_snapshot().counters;
    require(fc.reference_fallbacks>0U, "same-variant forced reference fallback executed");
    require(rc.head_preflight_probes>0U, "new native run preflight executed");
    std::cout << "RUN_REPAIR_DIFF variant=" << variant << " workers=" << workers
              << " pooled=" << parallel_heads << " gas=" << gas
              << " probes=" << rc.head_preflight_probes
              << " selected_runs=" << rc.head_preflight_runs
              << " repairs=" << rc.base_cells_written
              << " fallback=" << rc.reference_fallbacks << '\n';
}
}

// Part of the native `tests` binary (Makefile TEST_SOURCES), so the normal,
// ASan/UBSan and TSan families all run the parallel head path.
void test_workbench_pressure_heads_parallel_exact() {
    for (const int variant : {0, 1, 2}) run(variant);
    for (const int variant : {1, 2})
        for (const auto workers : {1U,4U,6U})
            for (const bool pooled : {false,true})
                for (const bool gas : {false,true})
                    run_run_repair_differential(variant,workers,pooled,gas);
    std::cout << "WORKBENCH_PRESSURE_HEADS checks=" << checks << '\n';
}
