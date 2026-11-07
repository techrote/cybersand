// #201 on accepted #405: identical-input, full-authored stress-canvas native replay.
// SOURCE and TEST are separate executables built from the SAME driver byte stream.
// The 2048x1024 materials are exported from the actual Godot workbench_setup.gd.
// Body-mask poses, wall edits, jet injection and camera inputs come from a pinned
// tape and are applied at the same completed native tick in both source trees.
// This is a deterministic native-input approximation of the workbench, not a
// captured Rapier dynamics trace, FPS benchmark or synthetic 360-pocket test.
#include "cybersand/world.hpp"
#include <algorithm>
#include <array>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <span>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using namespace cybersand;
void require(bool ok, const std::string& what) {
    if (!ok) throw std::runtime_error(what);
}
struct Hash {
    std::uint64_t v=14695981039346656037ULL;
    void add(std::uint64_t x) {
        for (int i=0;i<8;++i) { v ^= (x>>(i*8)) & 255U; v *= 1099511628211ULL; }
    }
};
std::string hex(std::uint64_t x) {
    std::ostringstream s; s<<std::hex<<std::setfill('0')<<std::setw(16)<<x; return s.str();
}
WorldConfig config(int workers) {
    WorldConfig cfg;
    cfg.worker_threads=static_cast<std::uint32_t>(workers);
    cfg.maximum_chunk_count=512;
    cfg.active_chunk_capacity=512;
    cfg.initial_chunk_reserve=256;
    cfg.active_core_capacity=4096;
    cfg.parallel_job_threshold=2;
    cfg.workbench_parallel_pressure_heads=true;
    cfg.backend=SimulationBackend::PhasedInPlace;
    cfg.pressure_gas_compartment_capacity=2048;
    cfg.ballistic_water.enabled=true;
    cfg.ballistic_water.capacity=8192;
    cfg.ballistic_water.face_release=true;
    cfg.ballistic_water.face_min_height=4;
    cfg.ballistic_water.face_speed=288;
    cfg.ballistic_water.face_period=1;
    auto request=LiquidSolverPolicy::default_request();
    request[21]=3; request[22]=2; // Water: PF cached_dormant
    const auto family_count_at=request.size()-2U;
    request[family_count_at]=1;
    request.insert(request.begin()+static_cast<std::ptrdiff_t>(family_count_at)+1,
                   {3,1,2,1,32}); // PF gas ON, closed family-parameter block
    const auto decoded=LiquidSolverPolicy::decode(std::span<const std::int32_t>(request));
    require(decoded.accepted(),"PF gas policy refused");
    cfg.liquid_solver_policy=*decoded.policy;
    return cfg;
}
void authored(World& w,const std::string& path) {
    std::ifstream in(path);
    require(static_cast<bool>(in),"Godot authored stress CSV missing");
    std::string line;
    require(static_cast<bool>(std::getline(in,line)) && line=="2048,1024",
            "not the exact full 2048x1024 workbench geometry");
    int n=0;
    while(std::getline(in,line)) {
        if(line.empty()) continue;
        std::replace(line.begin(),line.end(),',',' ');
        std::istringstream s(line);
        int x,y,width,height,material,extra=0;
        require(static_cast<bool>(s>>x>>y>>width>>height>>material) && !(s>>extra) &&
            x>=0 && y>=0 && width>0 && height>0 &&
            x+width<=2048 && y+height<=1024,"malformed authored paint run");
        for(int yy=y;yy<y+height;++yy)
            for(int xx=x;xx<x+width;++xx)
                w.set(xx,yy,static_cast<Material>(material));
        ++n;
    }
    require(n>=100 && n<=4096,"authored stress-canvas merged rectangles not present");
    std::cerr<<"REAL_WORKBENCH_AUTHORED_RECTANGLES="<<n<<"\n";
}
struct Input {
    int tick=0, edit_x=-1, edit_y=-1, edit_material=-1;
    bool jet=false;
    int jet_x=0, jet_y=0;
    std::array<int,16> body{};
};
std::vector<Input> tape(const std::string& path) {
    std::ifstream in(path);
    require(static_cast<bool>(in),"identical native input tape missing");
    std::string line;
    require(static_cast<bool>(std::getline(in,line)) &&
        line=="pf201-native-input-v1,2048,1024,8,264","wrong replay tape schema");
    std::vector<Input> out;
    while(std::getline(in,line)) {
        if(line.empty()) continue;
        std::replace(line.begin(),line.end(),',',' ');
        std::istringstream s(line);
        Input row; int jet=0,extra=0;
        require(static_cast<bool>(s>>row.tick>>row.edit_x>>row.edit_y>>row.edit_material
            >>jet>>row.jet_x>>row.jet_y),"invalid replay tick input");
        for(auto& field:row.body) require(static_cast<bool>(s>>field),"incomplete eight-body sample");
        require(!(s>>extra),"extra input beyond eight-body sample");
        row.jet=jet!=0;
        require(row.tick==static_cast<int>(out.size())+1,"discontinuous native input tape");
        out.push_back(row);
    }
    require(out.size()==264,"incomplete 24 warmup + 240 replay native ticks");
    return out;
}
std::uint64_t quantity_digest(const QuantityLedgerSnapshot& q) {
    Hash hash; hash.add(q.schema_version); hash.add(q.mass_bits);
    hash.add(q.baseline_water);hash.add(q.water_visible);hash.add(q.water_overfill);hash.add(q.water_ballistic);
    for(const auto& flow:q.kinds){hash.add(flow.produced);hash.add(flow.consumed);}
    for(const auto& flow:q.pair_rules){hash.add(flow.produced);hash.add(flow.consumed);}
    for(const auto v:q.pair_events)hash.add(v);
    for(const auto& flow:q.kernel_rules){hash.add(flow.produced);hash.add(flow.consumed);}
    for(const auto v:q.material_cells)hash.add(v);
    for(const auto v:q.prepared_material_cells)hash.add(v);
    hash.add(q.construction.has_value()?1U:0U);
    if(q.construction) {
        const auto& c=*q.construction;
        hash.add(c.mass_bits);hash.add(c.baseline_water);
        hash.add(c.normalization_produced);hash.add(c.normalization_consumed);
        hash.add(c.expected_final_water);
        for(auto ch:c.original_setup_identity)hash.add(ch);
        for(auto ch:c.prepared_setup_identity)hash.add(ch);
        for(auto ch:c.original_payload_digest)hash.add(ch);
        for(auto ch:c.prepared_payload_digest)hash.add(ch);
    }
    return hash.v;
}
std::uint64_t gas_digest(const World& w) {
    Hash hash;
    const auto gas=w.gas_compartments();
    hash.add(gas.size());
    for(const auto& c:gas){
        hash.add(c.id);hash.add(c.generation);hash.add(c.parent_count);
        for(const auto v:c.parents)hash.add(v);
        hash.add(c.amount);hash.add(c.volume);hash.add(c.anchor_x);hash.add(c.anchor_y);
        hash.add(c.created_tick);hash.add(c.revision);hash.add(c.gauge);
    }
    return hash.v;
}
void actor_inputs(World& w,const Input& r) {
    w.clear_transient_obstacles();
    for(std::uint16_t i=0;i<8;++i) {
        const int x=r.body[2*i], y=r.body[2*i+1];
        for(int dy=-6;dy<=6;++dy)
            for(int dx=-3;dx<=3;++dx) {
                require(w.set_transient_obstacle(x+dx,y+dy,i+1),
                        "discontinuous or duplicate native body-mask cell");
            }
    }
}
void apply(World& w,const Input& r,bool moving_camera) {
    // Dynamic camera is a separate lane: the #405 selective-core retention
    // stays active without changing the physics semantics of the input trace.
    if(moving_camera) {
        int step=(r.tick-1)%112;
        int offset=step<=56?step:112-step;
        w.set_simulation_region(RectI64{offset*20,240,800,540});
    } else {
        w.set_simulation_region(std::nullopt); // all-World material simulation
    }
    actor_inputs(w,r);
    if(r.edit_x>=0){
        require(r.edit_material==58 || r.edit_material==0,"unknown replay edit material");
        for(int dy=-3;dy<=3;++dy)
            for(int dx=-3;dx<=3;++dx)
                if(dx*dx+dy*dy<=9)
                    w.set(r.edit_x+dx,r.edit_y+dy,static_cast<Material>(r.edit_material));
    }
    if(r.jet){
        const int q=BallisticWaterConfig::kQ;
        const auto shot=w.inject_ballistic_water(r.jet_x*q+q/2,r.jet_y*q+q/2,
                                                0,-(q*4),16);
        // Refusal is a valid physical result and is included in next hash/ledger;
        // do not silently drop or rewrite rejected same-input injections.
        (void)shot;
    }
}
} // namespace
int main(int argc,char** argv) {
    try {
        require(argc==5,"usage: replay fixture.csv input_tape.csv workers(1|4) camera(0|1)");
        const int workers=std::stoi(argv[3]),camera=std::stoi(argv[4]);
        require((workers==1||workers==4)&&(camera==0||camera==1),"unsupported replay lane");
        World world(config(workers));
        world.reserve_region({0,0,2048,1024});
        authored(world,argv[1]);
        world.configure_transient_obstacles({0,0,2048,1024});
        const auto steps=tape(argv[2]);
        require(world.pressure_flow_enabled() && world.pressure_flow_parameters().gas_enabled &&
                world.config().pressure_gas_compartment_capacity==2048,
                "C2048 PF gas not actually applied");
        require(world.physical_state_hash_version()==5U,
                "replay must remain in real C2048 physical hash v5 domain");
        std::cout<<"tick,physical_hash,quantity_digest,gas_digest,water_visible,water_overfill,"
                   "water_ballistic,water_expected,gas_live,gas_created,gas_absorbed,"
                   "gas_vented,gas_collapsed,gas_compartments,gas_reference_passes,"
                   "gas_reuses,seed_cells,bfs_cells,relabel_cells,gas_component_reuses,"
                   "gas_cache_builds,gas_member_validations,gas_cache_build_cells,workers_observed\n";
        for(const auto& r:steps){
            apply(world,r,camera==1);
            const auto stats=world.tick();
            require(!world.has_failed() && world.completed_tick_index()==static_cast<std::uint64_t>(r.tick),
                    "World failed or did not advance the requested tape tick "+std::to_string(r.tick));
            const auto q=world.quantity_ledger();
            std::uint64_t produced=q.baseline_water,consumed=0;
            for(const auto& flow:q.kinds){produced+=flow.produced;consumed+=flow.consumed;}
            const std::uint64_t actual=q.water_visible+q.water_overfill+q.water_ballistic;
            require(produced>=consumed && actual==produced-consumed,
                    "native Water six-cause + ballistic quantity ledger did not close");
            const auto g=world.gas_ledger();
            require(g.amount_live+g.vented+g.collapsed==g.created+g.absorbed,
                    "native gas ledger did not close");
            const auto b=world.ballistic_water_snapshot();
            require(b.enabled && b.in_flight_quantity==q.water_ballistic,
                    "ballistic parcel quantity disagrees with native ledger");
            const auto a=world.pressure_optimization_snapshot().counters;
            require(world.physical_state_hash_version()==5,
                    "physical state identity changed from explicit C2048");
            std::cout<<r.tick<<','<<hex(world.physical_state_hash())<<','
                     <<hex(quantity_digest(q))<<','<<hex(gas_digest(world))<<','
                     <<q.water_visible<<','<<q.water_overfill<<','<<q.water_ballistic<<','
                     <<produced-consumed<<','<<g.amount_live<<','<<g.created<<','
                     <<g.absorbed<<','<<g.vented<<','<<g.collapsed<<','
                     <<world.gas_compartments().size()<<','<<a.gas_reference_passes<<','
                     <<a.gas_reuses<<','<<a.gas_seed_cells<<','<<a.gas_bfs_cells<<','
                     <<a.gas_relabel_cells<<','<<a.gas_component_reuses<<','<<a.gas_cache_builds<<','
                     <<a.gas_member_validations<<','<<a.gas_cache_build_cells<<','<<stats.worker_threads_observed<<'\n';
        }
        std::cerr<<"PF201_IDENTICAL_NATIVE_INPUT_REPLAY_PASS ticks="<<steps.size()
                 <<" workers="<<workers<<" camera="<<camera<<"\n";
    } catch(const std::exception& e) {
        std::cerr<<"PF201_IDENTICAL_NATIVE_INPUT_REPLAY_FAIL "<<e.what()<<'\n';
        return 1;
    }
}
