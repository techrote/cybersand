// PR #406 exact native regression for incremental per-run head repair.
// This is linked against production World and runs in the native test suite.
// Compare three Worlds: PF reference, PF cached_dormant with normal index, and
// PF cached_dormant forced into reference fallback by index_chunk_capacity=1.
// The last two have the SAME physical family/variant policy, so full hashes and
// saved CYPS bytes may be compared, unlike raw hashes across variant0/2.
#include "cybersand/world.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <iostream>
#include <memory>
#include <span>
#include <stdexcept>
#include <string>
#include <tuple>
#include <vector>

namespace {
using namespace cybersand;

void require(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}

WorldConfig config_for(int variant, bool force_reference, unsigned workers, bool parallel_heads, bool gas) {
    auto request = LiquidSolverPolicy::default_request();
    // Exact Water assignment positions are fixed in the current envelope,
    // as exercised by native/tests/test_workbench_pressure_heads.cpp.
    require(request.size() > 22U, "policy envelope unexpectedly short");
    request[21] = 3; // pressure_flow_v1
    request[22] = variant;
    if (!gas) {
        const auto at = request.size() - 2U;
        request[at] = 1;
        request.insert(request.begin()+static_cast<std::ptrdiff_t>(at)+1, {3,1,2,0,32});
    }
    const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(request));
    require(decoded.accepted(), "pressure family/variant not admitted");
    WorldConfig cfg;
    cfg.liquid_solver_policy = *decoded.policy;
    cfg.chunk_size = cfg.scheduling_core_size = 16;
    cfg.activity_block_size = 8;
    cfg.maximum_chunk_count = cfg.active_chunk_capacity = cfg.active_core_capacity = 256;
    cfg.worker_threads = workers;
    cfg.parallel_job_threshold = 2;
    cfg.workbench_parallel_pressure_heads = parallel_heads;
    if (force_reference) cfg.pressure_optimization.index_chunk_capacity = 1;
    return cfg;
}

void rect(World& w, int x, int y, int sx, int sy, Material m) {
    for (int dy=0; dy<sy; ++dy) for (int dx=0; dx<sx; ++dx) w.set(x+dx,y+dy,m);
}

std::unique_ptr<World> make_world(int variant, bool force_reference, unsigned workers, bool parallel_heads, bool gas) {
    auto w = std::make_unique<World>(config_for(variant,force_reference,workers,parallel_heads,gas));
    w->configure_transient_obstacles({-96,-96,240,208});
    for (int x : {-82,-28,39,102}) {
        rect(*w,x,-16,1,31,Material::Wall);
        rect(*w,x+24,-16,1,31,Material::Wall);
        rect(*w,x,14,25,1,Material::Wall);
        rect(*w,x+1,-9,23,23,Material::Water);
    }
    // Two-sided lidded interpolation, an isolated upper Water/Oil load,
    // nonresident gaps and a sealed pocket.
    rect(*w,-82,-10,10,1,Material::Wall);
    rect(*w,39,-16,25,1,Material::Wall);
    rect(*w,-24,-52,3,4,Material::Water);
    w->set(-23,-53,Material::Oil);
    require(w->chunk_count()>1U, "force-reference control requires >1 resident chunk");
    return w;
}

std::vector<ChunkCoord> roster(const World& w) {
    std::vector<ChunkCoord> out(w.chunk_count());
    const auto got=w.copy_pressure_head_chunk_coordinates(out);
    require(got==out.size(), "resident roster copy count");
    std::sort(out.begin(),out.end());
    return out;
}

void assert_heads(const World& a, const World& b, const std::string& stage) {
    const auto ar=roster(a), br=roster(b);
    require(ar==br,stage+": resident chunk roster differs");
    const int size=a.config().chunk_size;
    for (const auto coord : ar)
        for (int y=0;y<size;++y) for (int x=0;x<size;++x) {
            const auto wx=coord.x*size+x, wy=coord.y*size+y;
            require(a.prepared_pressure_head(wx,wy)==b.prepared_pressure_head(wx,wy),
                stage+": prepared head status/value at "+std::to_string(wx)+","+std::to_string(wy));
        }
}

void assert_parity(const World& reference, const World& candidate, const World& forced, int tick) {
    const std::string stage="tick="+std::to_string(tick);
    // Reference variant0 and cached variants have different policy bytes:
    // use the canonically normalized pressure-variant projection, not raw hash.
    const auto projection=LiquidStateProjection::PressureVariantEquivalenceV1;
    require(reference.liquid_comparison_hash(projection)==candidate.liquid_comparison_hash(projection),
        stage+": reference/candidate normalized physical projection");
    require(reference.liquid_comparison_hash(projection)==forced.liquid_comparison_hash(projection),
        stage+": reference/forced normalized physical projection");
    // Same cached policy: optimization index budget is execution metadata, not
    // physical authority, so these full hashes and portable saves must agree.
    require(candidate.physical_state_hash()==forced.physical_state_hash(),stage+": full physical hash");
    require(candidate.save_physical_state()==forced.save_physical_state(),stage+": exact CYPS payload");
    require(reference.quantity_ledger()==candidate.quantity_ledger() &&
            candidate.quantity_ledger()==forced.quantity_ledger(),stage+": quantity ledger");
    require(reference.pressure_flow_diagnostics().woken_blocks==candidate.pressure_flow_diagnostics().woken_blocks &&
            candidate.pressure_flow_diagnostics().woken_blocks==forced.pressure_flow_diagnostics().woken_blocks,
            stage+": same-tick wake events");
    // CYPS contains gas label/compartment table; also compare separately to
    // detect a gas-identity mismatch if a format or hash changes in the future.
    require(reference.gas_topology_revision()==candidate.gas_topology_revision() &&
            candidate.gas_topology_revision()==forced.gas_topology_revision(), stage+": gas topology revision");
    require(reference.gas_next_id()==candidate.gas_next_id() &&
            candidate.gas_next_id()==forced.gas_next_id(),stage+": gas next id");
    const auto ah=reference.gas_history(), bh=candidate.gas_history(), ch=forced.gas_history();
    require(ah.size()==bh.size() && bh.size()==ch.size(),stage+": gas retirement history size");
    assert_heads(reference,candidate,stage+" reference -> candidate");
    assert_heads(candidate,forced,stage+" candidate -> forced fallback");
}

void apply_edits(World& w,int t) {
    if(t==6 || t==30) rect(w,104,-30,12,21,Material::Water);
    if(t==12 || t==15) {
        w.clear_transient_obstacles();
        for(int i=0;i<6;++i)
            require(w.set_transient_obstacle(-25+i+(t==15 ? 3 : 0),-10,1),"mask install");
    }
    if(t==21 || t==69) w.clear_transient_obstacles();
    if(t==36) w.set(45,-16,Material::Empty); // vent a pocket
    if(t==42) w.set(-23,-53,Material::Water); // remove foreign-liquid weight
    if(t==49) w.set(-23,-53,Material::Oil);
    if(t==56) require(w.set_cell_state(-22,-50,Material::Water,140,0),"fractional Water top");
    if(t==63) w.set(1,11,Material::Water); // isolated/seam-edit
    if(t==73) w.set(1,11,Material::Empty);
    if(t==81) w.set(44,-8,Material::Wall);
    if(t==85) w.set(44,-8,Material::Water);
    // Reversible and stochastic deterministic mutations across multiple phase
    // barriers, with foreign-liquid loads, support edits and chunk seams.
    if(t%7==0) {
        std::uint32_t r = static_cast<std::uint32_t>(t)*747796405U+2891336453U;
        for(int n=0;n<4;++n) {
            r = r*1664525U+1013904223U;
            const int x = (n%2 ? -79 : 41)+static_cast<int>(r%18U);
            r = r*1664525U+1013904223U;
            const int y = -12+static_cast<int>(r%23U);
            const auto material = n==0 ? Material::Water : n==1 ? Material::Empty : n==2 ? Material::Oil : Material::Wall;
            w.set(x,y,material);
        }
    }
}

void run(unsigned workers, bool parallel_heads, bool gas, int variant) {
    auto reference=make_world(0,false,workers,parallel_heads,gas);
    auto candidate=make_world(variant,false,workers,parallel_heads,gas);
    auto forced=make_world(variant,true,workers,parallel_heads,gas);
    for(int tick=0;tick<100;++tick) {
        for(World* w:{reference.get(),candidate.get(),forced.get()}) {
            apply_edits(*w,tick);
            (void)w->tick();
        }
        assert_parity(*reference,*candidate,*forced,tick);
    }
    require(forced->pressure_optimization_snapshot().counters.reference_fallbacks>0U,
        "the forced same-variant control never executed reference fallback");
    std::cout<<"PASS native_probe workers="<<workers<<" parallel="<<parallel_heads
             <<" gas="<<gas<<" variant="<<variant
             <<" ticks=100 repaired_fallbacks="
             <<candidate->pressure_optimization_snapshot().counters.reference_fallbacks
             <<" forced_fallbacks="<<forced->pressure_optimization_snapshot().counters.reference_fallbacks
             <<'\n';
}
} // namespace

void test_pressure_run_repair() {
    for (const auto gas : {false,true})
        for (const auto variant : {1,2})
            for (const unsigned workers : {1U,4U,6U})
                for (const bool parallel : {false,true})
                    run(workers,parallel,gas,variant);
}
