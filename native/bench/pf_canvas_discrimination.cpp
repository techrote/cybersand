// PF-V2 #481 current-main named-canvas bottleneck discrimination.
// Tooling only: no engine source is changed by this apparatus.
#include "cybersand/liquid_solver_policy.hpp"
#include "cybersand/material_rules.hpp"
#include "cybersand/transport_policy.hpp"
#include "cybersand/water_experiment_policy.hpp"
#include "cybersand/world.hpp"

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <span>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

using namespace cybersand;
using Clock = std::chrono::steady_clock;

struct Rect { std::int64_t x=0,y=0,w=0,h=0; std::int32_t material=0; };
struct Scene { std::int32_t width=0,height=0; std::vector<Rect> rects; };

static void require(bool value, const char* message) {
    if (!value) throw std::runtime_error(message);
}
static std::string escape_json(std::string_view value) {
    std::string out;
    for (char c : value) {
        if (c == '"' || c == '\\') { out.push_back('\\'); out.push_back(c); }
        else if (c == '\n') out += "\\n";
        else if (static_cast<unsigned char>(c) >= 0x20U) out.push_back(c);
    }
    return out;
}
static std::string hex64(std::uint64_t value) {
    std::ostringstream out; out << std::hex << std::setfill('0') << std::setw(16) << value;
    return out.str();
}
static Scene read_scene(const std::string& path) {
    std::ifstream in(path);
    if (!in) throw std::runtime_error("scene file unavailable");
    Scene s; std::size_t count=0;
    if (!(in >> s.width >> s.height >> count) || s.width < 256 || s.height < 256 ||
        s.width > 2048 || s.height > 2048 || s.width % 64 || s.height % 64)
        throw std::runtime_error("invalid scene header");
    s.rects.reserve(count);
    Rect r;
    while (in >> r.x >> r.y >> r.w >> r.h >> r.material) {
        if (r.x < 0 || r.y < 0 || r.w < 1 || r.h < 1 ||
            r.x + r.w > s.width || r.y + r.h > s.height ||
            r.material < 0 || r.material > 255)
            throw std::runtime_error("invalid scene rectangle");
        s.rects.push_back(r);
    }
    if (!in.eof() || s.rects.size() != count) throw std::runtime_error("scene rectangle count mismatch");
    return s;
}

static LiquidSolverPolicy pressure_policy(int variant, bool gas) {
    auto words = LiquidSolverPolicy::default_request();
    require(words.size() > 24U, "default liquid policy envelope too small");
    words[21] = 3;
    words[22] = variant;
    // Mirror the admitted bridge family-parameter encoding: remove the default
    // empty family/material block tails and append one PF v1 block {gas,rows}.
    words.resize(words.size() - 2U);
    words.insert(words.end(), {1, 3, 1, 2, gas ? 1 : 0, 32, 0});
    const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
    if (!decoded.accepted())
        throw std::runtime_error("PressureFlow policy refused: " + decoded.refusal.message());
    return *decoded.policy;
}

static WorldConfig config_for(const Scene& scene, int variant, bool gas,
                              std::uint32_t workers, bool face) {
    WorldConfig cfg;
    cfg.worker_threads = workers;
    cfg.backend = SimulationBackend::PhasedInPlace;
    cfg.parallel_job_threshold = 2;
    cfg.workbench_parallel_pressure_heads = true;
    const auto halo_columns = static_cast<std::size_t>((scene.width + cfg.chunk_size - 1) / cfg.chunk_size + 2);
    const auto halo_rows = static_cast<std::size_t>((scene.height + cfg.chunk_size - 1) / cfg.chunk_size + 2);
    cfg.maximum_chunk_count = std::max<std::size_t>(128U, halo_columns * halo_rows);
    cfg.active_chunk_capacity = cfg.maximum_chunk_count;
    cfg.initial_chunk_reserve = std::min<std::size_t>(64U, cfg.maximum_chunk_count);
    cfg.active_core_capacity = std::max<std::size_t>(1024U,
        halo_columns * static_cast<std::size_t>(cfg.chunk_size / cfg.scheduling_core_size) *
        halo_rows * static_cast<std::size_t>(cfg.chunk_size / cfg.scheduling_core_size));
    TransportPolicy transport;
    transport.configured = true;
    cfg.transport_policy = transport;
    cfg.water_experiment_policy = WaterExperimentPolicy(8,12);
    cfg.liquid_solver_policy = pressure_policy(variant,gas);
    cfg.maximum_rule_radius = 2;
    cfg.interaction_policy = {};
    cfg.physics_diagnostics = {};
    cfg.physics_diagnostics.enabled = true;
    if (face) {
        cfg.ballistic_water.enabled = true;
        cfg.ballistic_water.face_release = true;
        cfg.ballistic_water.face_budget = 320;
        cfg.ballistic_water.face_speed = 288;
        cfg.ballistic_water.face_period = 1;
        cfg.ballistic_water.face_min_height = 4;
    }
    return cfg;
}

static std::unique_ptr<World> build(const Scene& scene, int variant, bool gas,
                                    std::uint32_t workers, bool face) {
    auto world = std::make_unique<World>(config_for(scene,variant,gas,workers,face));
    world->reserve_region({0,0,scene.width,scene.height});
    world->configure_transient_obstacles({0,0,scene.width,scene.height});
    for (const auto& r : scene.rects)
        for (std::int64_t y=r.y; y<r.y+r.h; ++y)
            for (std::int64_t x=r.x; x<r.x+r.w; ++x)
                world->set(x,y,static_cast<Material>(r.material));
    world->set_simulation_region(RectI64{0,0,scene.width,scene.height});
    world->set_liquid_surface_adhesion_enabled(true);
    return world;
}

struct Sums {
    std::uint64_t ticks=0, wall=0, prep=0, gas=0, head=0, ballistic=0;
    std::uint64_t columns=0, rows=0, base=0, finals=0, fallbacks=0, invalidations=0;
    std::uint64_t seed_cells=0, seed_probes=0, bfs_cells=0, bfs_probes=0, bfs_nodes=0, relabel=0;
    std::uint64_t water_calls=0, water_motion=0, visited=0, moved=0, cores=0, active=0;
    std::uint64_t max_participants=0;
};
static std::uint64_t sub(std::uint64_t a, std::uint64_t b) {
    return a >= b ? a-b : 0U;
}
static const char* variant_name(int v) { return v==0 ? "reference" : v==1 ? "cached" : "cached_dormant"; }

int main(int argc, char** argv) {
    try {
        if (argc != 8)
            throw std::invalid_argument("usage: pf_canvas_discrimination SCENE LABEL VARIANT GAS WORKERS FACE TICKS");
        const std::string path=argv[1], label=argv[2];
        const int variant=std::stoi(argv[3]), gas_i=std::stoi(argv[4]);
        const auto workers=static_cast<std::uint32_t>(std::stoul(argv[5]));
        const int face_i=std::stoi(argv[6]), ticks=std::stoi(argv[7]);
        if (variant<0 || variant>2 || (gas_i!=0 && gas_i!=1) || (face_i!=0 && face_i!=1) ||
            (workers!=1 && workers!=6) || ticks<90 || ticks>600)
            throw std::invalid_argument("invalid variant/gas/workers/face/ticks");
        const bool gas=gas_i!=0, face=face_i!=0;
        if (face && gas) throw std::invalid_argument("face-release discrimination is gas-off only");
        const Scene scene=read_scene(path);
        auto world=build(scene,variant,gas,workers,face);
        constexpr int warm=60;
        Sums sums;
        auto prior=world->pressure_optimization_snapshot().counters;
        for (int t=1; t<=ticks; ++t) {
            const auto start=Clock::now();
            const auto stats=world->tick();
            const auto elapsed=static_cast<std::uint64_t>(
                std::chrono::duration_cast<std::chrono::nanoseconds>(Clock::now()-start).count());
            const auto now=world->pressure_optimization_snapshot().counters;
            if (t>warm) {
                ++sums.ticks; sums.wall+=elapsed;
                sums.prep+=sub(now.preparation_nanoseconds,prior.preparation_nanoseconds);
                sums.gas+=sub(now.gas_nanoseconds,prior.gas_nanoseconds);
                sums.head+=sub(now.head_nanoseconds,prior.head_nanoseconds);
                sums.columns+=sub(now.columns_recomputed,prior.columns_recomputed);
                sums.rows+=sub(now.rows_recomputed,prior.rows_recomputed);
                sums.base+=sub(now.base_cells_written,prior.base_cells_written);
                sums.finals+=sub(now.final_cells_written,prior.final_cells_written);
                sums.fallbacks+=sub(now.reference_fallbacks,prior.reference_fallbacks);
                sums.invalidations+=sub(now.invalidation_rects,prior.invalidation_rects);
                sums.seed_cells+=sub(now.gas_seed_cells,prior.gas_seed_cells);
                sums.seed_probes+=sub(now.gas_seed_probes,prior.gas_seed_probes);
                sums.bfs_cells+=sub(now.gas_bfs_cells,prior.gas_bfs_cells);
                sums.bfs_probes+=sub(now.gas_bfs_probes,prior.gas_bfs_probes);
                sums.bfs_nodes+=sub(now.gas_bfs_nodes,prior.gas_bfs_nodes);
                sums.relabel+=sub(now.gas_relabel_cells,prior.gas_relabel_cells);
                sums.water_calls+=sub(now.water_material_calls,prior.water_material_calls);
                sums.water_motion+=sub(now.water_motion_calls,prior.water_motion_calls);
                sums.visited+=stats.visited_cells; sums.moved+=stats.moved_cells;
                sums.cores+=stats.scheduled_cores; sums.active+=stats.active_blocks_after;
                sums.max_participants=std::max(sums.max_participants,
                    static_cast<std::uint64_t>(stats.worker_threads_observed));
                sums.ballistic+=world->ballistic_water_snapshot().last_advance_nanoseconds;
            }
            prior=now;
        }
        const double n=static_cast<double>(sums.ticks);
        const auto ms=[n](std::uint64_t v) { return static_cast<double>(v)/1e6/n; };
        const auto per=[n](std::uint64_t v) { return static_cast<double>(v)/n; };
        const double residual=std::max(0.0,ms(sums.wall)-ms(sums.prep));
        std::cout << std::fixed << std::setprecision(6)
          << "{\"status\":\"PASS\",\"scene\":\"" << escape_json(label)
          << "\",\"extent\":\"" << scene.width << "x" << scene.height
          << "\",\"rectangles\":" << scene.rects.size()
          << ",\"variant\":\"" << variant_name(variant)
          << "\",\"gas\":" << (gas?"true":"false")
          << ",\"workers\":" << workers << ",\"face\":" << (face?"true":"false")
          << ",\"ticks_measured\":" << sums.ticks
          << ",\"tick_ms\":" << ms(sums.wall)
          << ",\"preparation_ms\":" << ms(sums.prep)
          << ",\"gas_ms\":" << ms(sums.gas)
          << ",\"head_ms\":" << ms(sums.head)
          << ",\"residual_ms\":" << residual
          << ",\"ballistic_ms\":" << ms(sums.ballistic)
          << ",\"columns_per_tick\":" << per(sums.columns)
          << ",\"rows_per_tick\":" << per(sums.rows)
          << ",\"base_writes_per_tick\":" << per(sums.base)
          << ",\"final_writes_per_tick\":" << per(sums.finals)
          << ",\"fallbacks_per_tick\":" << per(sums.fallbacks)
          << ",\"invalidations_per_tick\":" << per(sums.invalidations)
          << ",\"gas_seed_cells_per_tick\":" << per(sums.seed_cells)
          << ",\"gas_seed_probes_per_tick\":" << per(sums.seed_probes)
          << ",\"gas_bfs_cells_per_tick\":" << per(sums.bfs_cells)
          << ",\"gas_bfs_probes_per_tick\":" << per(sums.bfs_probes)
          << ",\"gas_bfs_nodes_per_tick\":" << per(sums.bfs_nodes)
          << ",\"gas_relabel_cells_per_tick\":" << per(sums.relabel)
          << ",\"water_calls_per_tick\":" << per(sums.water_calls)
          << ",\"water_motion_per_tick\":" << per(sums.water_motion)
          << ",\"visited_per_tick\":" << per(sums.visited)
          << ",\"moved_per_tick\":" << per(sums.moved)
          << ",\"cores_per_tick\":" << per(sums.cores)
          << ",\"active_blocks_per_tick\":" << per(sums.active)
          << ",\"max_workers_observed\":" << sums.max_participants
          << ",\"projection\":\"" << hex64(world->liquid_comparison_hash(LiquidStateProjection::PressureVariantEquivalenceV1))
          << "\",\"physical\":\"" << hex64(world->physical_state_hash())
          << "\",\"gas_compartments\":" << world->gas_compartments().size()
          << "}\n";
        return 0;
    } catch (const std::exception& error) {
        std::cout << "{\"status\":\"REFUSED_OR_FAILED\",\"error\":\""
                  << escape_json(error.what()) << "\"}\n";
        return 0;
    }
}
