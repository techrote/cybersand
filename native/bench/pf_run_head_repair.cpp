// Source-matched native-harness (NOT Godot application or the historical canvas):
// exact width, deterministically edited x count, fixed fill/worker/policy.
#include "cybersand/world.hpp"
#include <algorithm>
#include <array>
#include <chrono>
#include <cstdint>
#include <iostream>
#include <memory>
#include <span>
#include <stdexcept>
#include <string_view>
#include <vector>

using namespace cybersand;
using Clock = std::chrono::steady_clock;
template <typename C>
std::uint64_t metric(const C& c, const char* name) {
    if constexpr (requires {c.head_preflight_nanoseconds;}) {
        const std::string_view key{name};
        if(key=="preflight") return c.head_preflight_nanoseconds;
        if(key=="columns") return c.head_columns_nanoseconds;
        if(key=="rows") return c.head_interpolation_nanoseconds;
        if(key=="wake") return c.head_wake_nanoseconds;
        if(key=="probes") return c.head_preflight_probes;
        if(key=="spans") return c.head_repair_spans;
        if(key=="selected") return c.head_repair_selected_cells;
        if(key=="runs") return c.head_repair_runs;
    }
    return 0;
}
struct Profile { const char* name; int width, height, dirty_x; };
constexpr std::array<Profile,3> kProfiles{{
    {"my-canvas",512,512,457},{"bench-canvas",1024,768,979},{"stress-canvas",2048,1024,2039}
}};
int main(int argc,char**argv) {
    try {
        if(argc<2) throw std::runtime_error("usage: <profile> [gas=0] [workers=6] [ticks=8]");
        const std::string_view selected{argv[1]};
        const bool gas=argc>2 && std::stoi(argv[2])!=0;
        const unsigned workers=argc>3 ? static_cast<unsigned>(std::stoi(argv[3])) : 6U;
        const int samples=argc>4 ? std::stoi(argv[4]) : 8;
        const auto it=std::find_if(kProfiles.begin(),kProfiles.end(),[&](const auto& p){return selected==p.name;});
        if(it==kProfiles.end()) throw std::runtime_error("unknown profile");
        const auto& p=*it;
        auto words=LiquidSolverPolicy::default_request();
        words[21]=3; words[22]=2;
        if(!gas) {
            const auto at=words.size()-2U; words[at]=1;
            words.insert(words.begin()+static_cast<std::ptrdiff_t>(at)+1,{3,1,2,0,32});
        }
        const auto decoded=LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
        if(!decoded.accepted()) throw std::runtime_error("pressure policy refused");
        WorldConfig cfg;
        cfg.liquid_solver_policy=*decoded.policy;
        cfg.chunk_size=128; cfg.activity_block_size=32; cfg.scheduling_core_size=64;
        cfg.worker_threads=workers; cfg.parallel_job_threshold=2;
        cfg.maximum_chunk_count=cfg.active_chunk_capacity=cfg.active_core_capacity=256;
        cfg.workbench_parallel_pressure_heads=true;
        cfg.initial_chunk_reserve=128;
        auto world=std::make_unique<World>(cfg);
        const int y0=p.height/3, y1=y0+64;
        for(int x=0;x<p.width;++x) {
            world->set(x,y1,Material::Wall);
            for(int y=y0;y<y1;++y) world->set(x,y,Material::Water);
        }
        // Persistent active-Water edit pattern, matched between versions.
        constexpr int warm=4;
        for(int tick=0;tick<samples+warm;++tick) {
            for(int x=0;x<p.dirty_x;++x)
                (void)world->set_cell_state(x,y0+32,Material::Water,
                    static_cast<std::uint16_t>((tick%2)==0 ? 254 : 255),0);
            const auto before=world->pressure_optimization_snapshot().counters;
            const auto start=Clock::now();
            (void)world->tick();
            const auto total=std::chrono::duration_cast<std::chrono::nanoseconds>(Clock::now()-start).count();
            const auto after=world->pressure_optimization_snapshot().counters;
            if(world->has_failed()) throw std::runtime_error("failed tick");
            if(tick<warm) continue;
            auto diff=[&](auto field){return after.*field-before.*field;};
            auto extra=[&](const char* name){return metric(after,name)-metric(before,name);};
            std::cout<<p.name<<','<<p.width<<','<<p.height<<','<<p.dirty_x<<','<<gas<<','<<workers
                     <<','<<tick-warm<<','<<total<<','<<diff(&PressureOptimizationCounters::head_nanoseconds)
                     <<','<<diff(&PressureOptimizationCounters::gas_nanoseconds)
                     <<','<<extra("preflight")<<','<<extra("columns")<<','<<extra("rows")<<','<<extra("wake")
                     <<','<<extra("probes")<<','<<extra("spans")<<','<<extra("selected")<<','<<extra("runs")
                     <<','<<diff(&PressureOptimizationCounters::reference_fallbacks)
                     <<','<<diff(&PressureOptimizationCounters::columns_recomputed)
                     <<','<<diff(&PressureOptimizationCounters::base_cells_written)
                     <<','<<diff(&PressureOptimizationCounters::rows_recomputed)
                     <<','<<diff(&PressureOptimizationCounters::final_cells_written)<<'\n';
        }
        return 0;
    }catch(const std::exception& err) {std::cerr<<err.what()<<'\n';return 1;}
}
