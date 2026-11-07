// Production-successor qualification: identical compiled native World for C1024 and C2048.
// Usage: pf_capacity_native CAPACITY SCENE VARIANT WORKERS TICKS [ROOMS] [FIXTURE_CSV] [SAVE_PREFIX]
// SCENE: default, isolated, unseeded, dynamic, atmosphere, my-canvas, bench-canvas, stress-canvas.
// Builtin CSVs are exported *by Godot* from workbench_setup.gd, not hand approximations.
#include "cybersand/default_demo_recipe.hpp"
#include "cybersand/prepared_world.hpp"
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <memory>
#include <sstream>
#include <numeric>
#include <span>
#include <stdexcept>
#include <string>
#include <vector>
#include <array>
#ifdef __linux__
#include <malloc.h>
#endif

using namespace cybersand;

namespace {
struct Fixture { int width = 0, height = 0; };
struct HoleGrid { int w = 0, h = 0, columns = 64, rows = 0; std::vector<std::pair<int,int>> corridors; };
WorldConfig make_config(int capacity,int variant,int workers) {
    WorldConfig cfg;
    cfg.initial_chunk_reserve=256;
    cfg.maximum_chunk_count=512;
    cfg.active_chunk_capacity=512;
    cfg.active_core_capacity=4096;
    cfg.worker_threads=static_cast<std::uint32_t>(workers);
    cfg.parallel_job_threshold=2;
    if(capacity!=1024 && capacity!=2048)throw std::invalid_argument("unsupported capacity");
    cfg.pressure_gas_compartment_capacity=static_cast<std::uint16_t>(capacity);
    cfg.backend=SimulationBackend::PhasedInPlace;
    auto request=LiquidSolverPolicy::default_request();
    request[21]=3;
    request[22]=variant;
    auto p=LiquidSolverPolicy::decode(std::span<const std::int32_t>(request));
    if (!p.accepted()) throw std::runtime_error("PF policy refused: "+p.refusal.message());
    cfg.liquid_solver_policy=*p.policy;
    return cfg;
}
void place(World& w,int x,int y,int material) { w.set(x,y,static_cast<Material>(material)); }
void rectangle(World& w,int x,int y,int width,int height,int material) {
    if(width<0 || height<0) throw std::runtime_error("negative rect");
    for(int yy=y; yy<y+height; ++yy)
        for(int xx=x; xx<x+width; ++xx) place(w,xx,yy,material);
}
Fixture apply_builtin(World& w,const std::string& path) {
    std::ifstream in(path);
    if(!in) throw std::runtime_error("authored fixture CSV missing: "+path);
    Fixture fixture;
    char comma;
    if(!(in>>fixture.width>>comma>>fixture.height) || comma!=',' ||
       fixture.width<1 || fixture.height<1 || fixture.width>2048 || fixture.height>2048)
        throw std::runtime_error("invalid fixture extent");
    std::string line;
    std::getline(in,line);
    unsigned long long records=0;
    while(std::getline(in,line)) {
        if(line.empty()) continue;
        std::replace(line.begin(),line.end(),',',' ');
        std::istringstream row(line);
        int x=0,y=0,a=0,b=0,material=0;
        if(!(row>>x>>y>>a>>b>>material) || x<0 || y<0 ||
           a<=0 || b<=0 || x+a>fixture.width || y+b>fixture.height)
           throw std::runtime_error("invalid authored run");
        rectangle(w,x,y,a,b,material);
        ++records;
    }
    if(records==0) throw std::runtime_error("empty authored fixture");
    std::cerr<<"authored_fixture="<<path<<" rectangles="<<records
             <<" extent="<<fixture.width<<"x"<<fixture.height<<"\n";
    return fixture;
}
Fixture apply_default(World& w) {
    demo::visit_default_demo_recipe([&](auto x,auto y,auto mat){w.set(x,y,mat);});
    w.configure_transient_obstacles({0,0,demo::kWidth,demo::kHeight});
    if(!w.set_transient_obstacle(124,92,1))
        throw std::runtime_error("authored initial demo transient mask refused");
    return {demo::kWidth,demo::kHeight};
}
HoleGrid apply_holes(World& w,int rooms,bool seeded,bool connected) {
    if(rooms<1 || rooms>4097) throw std::runtime_error("rooms out of research range");
    HoleGrid h;
    h.rows=(rooms+63)/64;
    h.w=64*3+3;
    h.h=h.rows*4+5;
    rectangle(w,0,0,h.w,h.h,static_cast<int>(Material::Wall));
    for(int n=0;n<rooms;++n) {
        const int x=2+3*(n%64), y=2+4*(n/64);
        place(w,x,y,static_cast<int>(Material::Empty));
        place(w,x,y+1,seeded?static_cast<int>(Material::Water):static_cast<int>(Material::Wall));
        // Horizontal row connections and vertical spine make a single initially
        // connected sealed region. They are later closed by ordinary owner edits.
        if(connected && (n%64)!=0) {
            place(w,x-1,y,static_cast<int>(Material::Empty));
            place(w,x-2,y,static_cast<int>(Material::Empty));
            h.corridors.emplace_back(x-1,y);
            h.corridors.emplace_back(x-2,y);
        }
    }
    if(connected) {
        for(int r=1;r<h.rows;++r) {
            for(int dy=1;dy<=3;++dy) {
                const int x=2,y=2+4*(r-1)+dy;
                place(w,x,y,static_cast<int>(Material::Empty));
                h.corridors.emplace_back(x,y);
            }
        }
    }
    return h;
}
std::uint64_t linux_kib(const std::string& key) {
    std::ifstream in("/proc/self/status");std::string label;std::uint64_t val=0;
    while(in>>label) {
        if(label==key) {in>>val;return val;}
        std::string rest;std::getline(in,rest);
    }
    return 0;
}
std::uint64_t allocator_used() {
#ifdef __linux__
    return static_cast<std::uint64_t>(mallinfo2().uordblks);
#else
    return 0;
#endif
}
std::uint64_t allocator_arena() {
#ifdef __linux__
    return static_cast<std::uint64_t>(mallinfo2().arena);
#else
    return 0;
#endif
}
std::uint64_t q(const std::vector<std::uint64_t>& s,int percentile) {
    if(s.empty()) return 0;
    return s[std::min(s.size()-1,(s.size()*static_cast<std::size_t>(percentile)+99U)/100U-1U)];
}
struct Sample {
    std::uint64_t n=0,min=0,p50=0,p90=0,p95=0,p99=0,max=0,
                  one=0,two_four=0,five_sixteen=0,other=0,volume=0,max_id=0;
};
Sample describe(const std::vector<GasCompartmentSnapshot>& live) {
    Sample s;std::vector<std::uint64_t> volumes;
    s.n=live.size();volumes.reserve(live.size());
    for(const auto& g:live) {
        volumes.push_back(g.volume);s.volume+=g.volume;
        s.max_id=std::max(s.max_id,static_cast<std::uint64_t>(g.id));
        if(g.volume==1)++s.one;
        else if(g.volume<=4)++s.two_four;
        else if(g.volume<=16)++s.five_sixteen;
        else ++s.other;
    }
    std::sort(volumes.begin(),volumes.end());
    if(!volumes.empty()) {
        s.min=volumes.front();s.max=volumes.back();
        s.p50=q(volumes,50);s.p90=q(volumes,90);s.p95=q(volumes,95);s.p99=q(volumes,99);
    }
    return s;
}

struct Digest final {
    std::uint64_t value = 14695981039346656037ULL;
    void word(std::uint64_t v) noexcept {
        for(int i=0;i<8;++i) {
            value ^= (v >> (i*8)) & 255U;
            value *= 1099511628211ULL;
        }
    }
    void gas(const GasCompartmentSnapshot& g) noexcept {
        word(g.id);word(g.generation);word(g.parent_count);
        for(const auto x:g.parents)word(x);
        word(g.amount);word(g.volume);
        word(static_cast<std::uint64_t>(g.anchor_x));
        word(static_cast<std::uint64_t>(g.anchor_y));
        word(g.created_tick);word(g.revision);
        word(static_cast<std::uint64_t>(g.gauge));
    }
};
std::uint64_t compartment_digest(const std::vector<GasCompartmentSnapshot>& live) noexcept {
    Digest d;d.word(live.size());
    for(const auto& g:live)d.gas(g);
    return d.value;
}
std::uint64_t retirement_digest(const std::vector<GasHistoryRecord>& history) noexcept {
    Digest d;d.word(history.size());
    for(const auto& h:history) {
        d.gas(h.compartment);
        d.word(static_cast<std::uint64_t>(h.reason));
        d.word(h.successor_count);
        for(const auto successor:h.successors)d.word(successor);
        d.word(h.tick);
    }
    return d.value;
}
std::string pipe_parents(const std::array<std::uint32_t,PressureFlowParameters::kMaximumParents>& vals) {
    std::string result;
    for(const auto v:vals) { if(!result.empty())result+="|";result+=std::to_string(v); }
    return result;
}
void dump_gas_records(const World& w,const std::string& prefix) {
    std::ofstream live(prefix+".gas.csv");
    live<<"id,generation,parent_count,parents,amount,volume,anchor_x,anchor_y,created_tick,revision,gauge\n";
    for(const auto& g:w.gas_compartments()) {
        live<<g.id<<','<<g.generation<<','<<static_cast<int>(g.parent_count)<<','
            <<pipe_parents(g.parents)<<','<<g.amount<<','<<g.volume<<','
            <<g.anchor_x<<','<<g.anchor_y<<','<<g.created_tick<<','
            <<g.revision<<','<<g.gauge<<'\n';
    }
    std::ofstream retired(prefix+".history.csv");
    retired<<"id,generation,parent_count,parents,amount,volume,anchor_x,anchor_y,created_tick,revision,gauge,reason,successor_count,successors,retired_tick\n";
    for(const auto& h:w.gas_history()) {
        const auto& g=h.compartment;
        retired<<g.id<<','<<g.generation<<','<<static_cast<int>(g.parent_count)<<','
            <<pipe_parents(g.parents)<<','<<g.amount<<','<<g.volume<<','
            <<g.anchor_x<<','<<g.anchor_y<<','<<g.created_tick<<','
            <<g.revision<<','<<g.gauge<<','<<static_cast<int>(h.reason)<<','
            <<static_cast<int>(h.successor_count)<<','<<pipe_parents(h.successors)<<','<<h.tick<<'\n';
    }
    if(!live || !retired)throw std::runtime_error("gas evidence export failed");
}

void output_header() {
    std::cout<<"capacity,scene,variant,workers,phase,tick,initial_census,live,region_min,region_p50,"
             <<"region_p90,region_p95,region_p99,region_max,one_cell,two_four,five_sixteen,"
             <<"other_regions,region_volume,max_live_id,next_id,topology_rev,gas_created,"
             <<"gas_absorbed,gas_vented,gas_collapsed,gas_live_amount,creations,merges,splits,"
             <<"vents,collapses,ledger_closes,water_quantity,physical_hash,cyps_bytes,"
             <<"pressure_variant_projection,gas_digest,history_digest,history_records,gas_regions,atmosphere_regions,gas_visited,gas_seed_cells,gas_bfs_cells,"
             <<"gas_cache_build_cells,gas_cache_components,gas_cache_reserved_bytes,"
             <<"topology_reserved_bytes,derived_reserved_bytes,vmrss_kib,vmhwm_kib,"
             <<"allocator_inuse_bytes,allocator_arena_bytes,prep_ns,gas_ns,head_ns,"
             <<"native_tick_ns,world_failed,exception\n";
}
void record(const World& w,const Fixture& extent,const std::string& scene,int variant,int workers,
            const std::string& phase,long long tick,long long initial,std::uint64_t tick_ns,
            const PressureOptimizationCounters& earlier,const std::string& failure,
            const std::string& save_path) {
    const auto gas=w.gas_compartments();
    const auto g=w.gas_ledger();
    const auto history=w.gas_history();
    const auto sample=describe(gas);
    const auto diag=w.pressure_flow_diagnostics();
    const auto opt=w.pressure_optimization_snapshot();
    const bool closed=g.amount_live+g.vented+g.collapsed==g.created+g.absorbed;
    std::size_t saved=0;
    if(!save_path.empty() && !w.has_failed()) {
        const auto b=w.save_physical_state();
        saved=b.size();
        std::ofstream out(save_path,std::ios::binary);
        out.write(reinterpret_cast<const char*>(b.data()),static_cast<std::streamsize>(b.size()));
        if(!out)throw std::runtime_error("could not save "+save_path);
        dump_gas_records(w,save_path);
    }
    std::uint64_t water=0,phys=0,projection=0;
    // A failed World rejects publication. Its partial contents are not a completed result.
    if(!w.has_failed()){
        water=w.water_quantity({0,0,extent.width,extent.height});
        phys=w.physical_state_hash();
        projection=w.liquid_comparison_hash(LiquidStateProjection::PressureVariantEquivalenceV1);
    }
    const auto diff=[&](auto a,auto b)->std::uint64_t{return a>=b?a-b:0;};
    std::cout<<w.config().pressure_gas_compartment_capacity<<','<<scene<<','<<variant<<','<<workers<<','
             <<phase<<','<<tick<<','<<initial<<','<<sample.n<<','<<sample.min<<','
             <<sample.p50<<','<<sample.p90<<','<<sample.p95<<','<<sample.p99<<','
             <<sample.max<<','<<sample.one<<','<<sample.two_four<<','<<sample.five_sixteen<<','
             <<sample.other<<','<<sample.volume<<','<<sample.max_id<<','<<w.gas_next_id()<<','
             <<w.gas_topology_revision()<<','<<g.created<<','<<g.absorbed<<','<<g.vented<<','
             <<g.collapsed<<','<<g.amount_live<<','<<g.creations<<','<<g.merges<<','
             <<g.splits<<','<<g.vents<<','<<g.collapses<<','<<closed<<','
             <<water<<','<<phys<<','<<saved<<','<<projection<<','
             <<compartment_digest(gas)<<','<<retirement_digest(history)<<','<<history.size()<<','
             <<diag.gas_regions<<','
             <<diag.atmosphere_regions<<','<<diag.gas_visited<<','
             <<diff(opt.counters.gas_seed_cells,earlier.gas_seed_cells)<<','
             <<diff(opt.counters.gas_bfs_cells,earlier.gas_bfs_cells)<<','
             <<diff(opt.counters.gas_cache_build_cells,earlier.gas_cache_build_cells)<<','
             <<opt.gas_components<<','<<opt.gas_capacity_bytes<<','
             <<0U<<','<<opt.derived_capacity_bytes<<','
             <<linux_kib("VmRSS:")<<','<<linux_kib("VmHWM:")<<','
             <<allocator_used()<<','<<allocator_arena()<<','
             <<diff(opt.counters.preparation_nanoseconds,earlier.preparation_nanoseconds)<<','
             <<diff(opt.counters.gas_nanoseconds,earlier.gas_nanoseconds)<<','
             <<diff(opt.counters.head_nanoseconds,earlier.head_nanoseconds)<<','
             <<tick_ns<<','<<w.has_failed()<<','<<failure<<"\n";
}
int run(int argc,char** argv) {
    if(argc<6) {
        std::cerr<<"usage: CAPACITY SCENE VARIANT WORKERS TICKS [ROOMS] [FIXTURE_CSV] [SAVE_PREFIX]\n";return 2;
    }
    const int capacity=std::stoi(argv[1]);
    const std::string scene=argv[2];
    const int variant=std::stoi(argv[3]),workers=std::stoi(argv[4]),ticks=std::stoi(argv[5]);
    const int rooms=argc>6?std::stoi(argv[6]):1024;
    const std::string fixture=argc>7?argv[7]:"";
    const std::string save_prefix=argc>8?argv[8]:"";
    if(variant<0 || variant>2 || (workers!=1 && workers!=4) || ticks<1 || ticks>1800) return 2;
    auto w=std::make_unique<World>(make_config(capacity,variant,workers));
    Fixture extent;
    HoleGrid holes;
    if(scene=="default")extent=apply_default(*w);
    else if(scene=="isolated"||scene=="unseeded"||scene=="dynamic") {
        holes=apply_holes(*w,rooms,scene!="unseeded",scene=="dynamic");
        extent={holes.w,holes.h};
    } else if(scene=="atmosphere") {
        // Protected 16,384 / 16,385 classification boundary (kept separate).
        rectangle(*w,0,0,132,131,static_cast<int>(Material::Wall));
        rectangle(*w,1,1,128,128,static_cast<int>(Material::Empty));
        place(*w,1,129,static_cast<int>(Material::Water));
        if(rooms==16385)place(*w,129,1,static_cast<int>(Material::Empty));
        extent={132,131};
    } else if(scene=="my-canvas"||scene=="bench-canvas"||scene=="stress-canvas"){
        extent=apply_builtin(*w,fixture);
    } else throw std::runtime_error("unknown scene: "+scene);
    const auto scan=setup::SetupDomain{0,0,static_cast<std::uint32_t>(extent.width),
                                           static_cast<std::uint32_t>(extent.height)};
    long long count=-1;
    try{
        const auto c=initial_pressure_capacity(*w,scan,
            scene=="stress-canvas"?2048:static_cast<std::uint32_t>(std::max(extent.width,extent.height)));
        if(c.applicable) count=static_cast<long long>(c.compartments);
    }catch(const std::exception& e){std::cerr<<"initial_census_error="<<e.what()<<"\n";}
    const auto admission=PreparedWorldBuilder::validate_initial_pressure_capacity(
        *w,scan,static_cast<std::uint32_t>(std::max(extent.width,extent.height)));
    std::cerr<<"case="<<scene<<" variant="<<variant<<" workers="<<workers
             <<" capacity="<<w->config().pressure_gas_compartment_capacity
             <<" initial_census="<<count
             <<" typed_capacity_refusal="<<(admission.has_value()?"yes":"no")<<"\n";
    output_header();
    PressureOptimizationCounters earlier{};
    record(*w,extent,scene,variant,workers,"initial",0,count,0,earlier,"","");
    for(int tick=1;tick<=ticks;++tick){
        if(scene=="dynamic" && tick==2) {
            for(const auto& pt:holes.corridors) place(*w,pt.first,pt.second,static_cast<int>(Material::Wall));
        }
        const auto previous=w->pressure_optimization_snapshot().counters;
        const auto start=std::chrono::steady_clock::now();
        std::string failure;
        try{(void)w->tick();}
        catch(const std::exception& e){failure=e.what();}
        const auto dt=static_cast<std::uint64_t>(
            std::chrono::duration_cast<std::chrono::nanoseconds>(
                std::chrono::steady_clock::now()-start).count());
        std::string path;
        if(!save_prefix.empty() && failure.empty() &&
           (tick==1||tick==10||tick==30||tick==60||tick==120||tick==300||tick==ticks))
            path=save_prefix+"-t"+std::to_string(tick)+".cyps";
        record(*w,extent,scene,variant,workers,
               scene=="dynamic"&&tick>=2?"after_split":"tick",tick,count,dt,previous,failure,path);
        if(!failure.empty() || w->has_failed()) {
            std::cerr<<"refusal_scene="<<scene<<" tick="<<tick<<" failed="<<w->has_failed()
                     <<" error="<<failure<<"\n";
            // Never retry a failed world.
            break;
        }
    }
    return 0;
}
}
int main(int argc,char** argv) {
    if(argc == 6 && std::string(argv[1]) == "--restore") {
        int capacity = -1;
        try {
            capacity = std::stoi(argv[2]);
            const int variant=std::stoi(argv[3]),workers=std::stoi(argv[4]);
            std::ifstream input(argv[5],std::ios::binary);
            if(!input) throw std::runtime_error("restore input missing");
            const std::vector<std::uint8_t> bytes(
                (std::istreambuf_iterator<char>(input)),std::istreambuf_iterator<char>());
            auto restored=World::restore_physical_state(make_config(capacity,variant,workers),bytes);
            std::cout<<"restore_accepted,capacity="<<capacity
                     <<",live="<<restored->gas_compartments().size()
                     <<",hash="<<restored->physical_state_hash()<<"\\n";
            return 0;
        } catch(const std::exception& e) {
            std::cerr<<"restore_refused,capacity="<<capacity
                     <<",error="<<e.what()<<"\\n";return 7;
        }
    }
    try{return run(argc,argv);}
    catch(const std::exception& e){std::cerr<<"apparatus_error="<<e.what()<<"\n";return 1;}
}
