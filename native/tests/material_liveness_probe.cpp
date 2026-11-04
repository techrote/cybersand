// MAT-AUTH-002 Phase A: compile the real, unchanged World exactly once.
// Existing PrecisionProbe friendship permits copied, read-only observations.
// Do not also compile world.cpp as a separate translation unit.
#include "../src/world.cpp"

#include <iomanip>
#include <iostream>
#include <map>
#include <set>
#include <sstream>
#include <string>

namespace cybersand {
class PrecisionProbe {
public:
    struct Block { bool active; std::uint32_t quiet; std::uint64_t due; };
    static Block block(const World& world, std::int64_t x, std::int64_t y) {
        const auto at = world.address(x,y);
        const auto* chunk = world.find_chunk(at.chunk);
        if (chunk == nullptr) return {false,0,0};
        const auto b = world.config_.activity_block_size;
        const auto index = static_cast<std::size_t>((at.local_y/b)*chunk->activity_blocks_per_axis + at.local_x/b);
        const auto& value = chunk->activity_blocks.at(index);
        return {value.active,value.quiet_ticks,value.next_interaction_tick};
    }
    static std::uint8_t random(const World& world, std::int64_t x, std::int64_t y, std::uint32_t stream) {
        return world.deterministic_random(x,y,stream);
    }
};
}

namespace mat354 {
using namespace cybersand;
using Point = std::pair<std::int64_t,std::int64_t>;
void require(bool condition, const std::string& reason) {
    if (!condition) throw std::runtime_error(reason);
}
std::string quoted(const std::string& text) {
    std::string out = "\"";
    for (const unsigned char c : text) {
        if (c=='"' || c=='\\') { out += '\\'; out += static_cast<char>(c); }
        else if (c=='\n') out += "\\n";
        else if (c=='\r') out += "\\r";
        else if (c=='\t') out += "\\t";
        else if (c<32) out += '?';
        else out += static_cast<char>(c);
    }
    return out+'"';
}
std::string hex(std::uint64_t value) {
    std::ostringstream out; out << std::hex << std::setfill('0') << std::setw(16) << value; return out.str();
}
std::uint64_t mix_reference(std::uint64_t v) {
    v=(v^(v>>30U))*0xbf58476d1ce4e5b9ULL;
    v=(v^(v>>27U))*0x94d049bb133111ebULL;
    return v^(v>>31U);
}
std::uint64_t spatial_reference(std::int64_t x,std::int64_t y,std::uint32_t stream) {
    return static_cast<std::uint64_t>(x)*0x9e3779b185ebca87ULL ^
        std::rotl(static_cast<std::uint64_t>(y),23) ^ static_cast<std::uint64_t>(stream)*0xa0761d6478bd642fULL;
}
unsigned draw_reference(std::int64_t x,std::int64_t y,std::uint64_t tick,std::uint32_t stream) {
    return static_cast<unsigned>(mix_reference(spatial_reference(x,y,stream)^tick*0xd6e8feb86659fd93ULL)&255U);
}
std::int64_t core_floor(std::int64_t n) { return n>=0 ? n/64 : (n-63)/64; }

struct Args {
    std::string fixture,variant="baseline";
    std::int64_t x=8,y=8;
    unsigned quiet=3,workers=1,ticks=64,repeat=0;
    bool busy=false;
    std::string id() const {
        return fixture+"__"+variant+"__x"+std::to_string(x)+"_y"+std::to_string(y)+
            "__q"+std::to_string(quiet)+"__busy"+std::to_string(busy?1:0)+
            "__w"+std::to_string(workers)+"__r"+std::to_string(repeat);
    }
};
Args parse(int argc,char** argv) {
    Args a; std::set<std::string> seen;
    for(int i=1;i<argc;i+=2) {
        require(i+1<argc,"option requires value");
        const std::string key=argv[i],value=argv[i+1];
        require(seen.insert(key).second,"duplicate option");
        if(key=="--fixture") a.fixture=value;
        else if(key=="--variant") a.variant=value;
        else {
            std::size_t end=0; const auto n=std::stoll(value,&end);
            require(end==value.size(),"noninteger option");
            if(key=="--x") a.x=n;
            else if(key=="--y") a.y=n;
            else {
                require(n>=0 && n<=100000,"option outside apparatus bound");
                if(key=="--quiet") a.quiet=static_cast<unsigned>(n);
                else if(key=="--workers") a.workers=static_cast<unsigned>(n);
                else if(key=="--ticks") a.ticks=static_cast<unsigned>(n);
                else if(key=="--repeat") a.repeat=static_cast<unsigned>(n);
                else if(key=="--active-neighbour") { require(n<=1,"busy flag");a.busy=n!=0; }
                else throw std::runtime_error("unknown option "+key);
            }
        }
    }
    require(!a.fixture.empty() && (a.quiet==3 || a.quiet==1024) &&
        (a.workers==1 || a.workers==4) && a.ticks>=1 && a.ticks<=1024,"invalid campaign bounds");
    require(a.x>=-16384 && a.x<=16384 && a.y>=-16384 && a.y<=16384,"coordinate bound");
    const std::set<std::string> variants{"baseline","left_only","right_only","blocked","source_mask",
        "neighbor_mask","destination_mask","region","owner_pause","source_edit","neighbor_edit","reset"};
    require(variants.contains(a.variant),"unknown variant"); return a;
}
bool molten(const Args& a) { return a.fixture.starts_with("molten_") || a.fixture=="distributed_molten"; }
bool generic(const Args& a) {
    return a.fixture=="paste" || a.fixture=="slush" || a.fixture=="brine" || a.fixture=="mercury" || a.fixture=="distributed_paste";
}
bool distributed(const Args& a) { return a.fixture.starts_with("distributed_"); }
Material subject(const Args& a) {
    if(molten(a)) return a.fixture=="molten_converted"?Material::Glass:Material::MoltenGlass;
    const std::map<std::string,Material> ids{{"paste",Material::Paste},{"distributed_paste",Material::Paste},
        {"slush",Material::Slush},{"brine",Material::Brine},{"mercury",Material::Mercury},
        {"water_fm",Material::Water},{"water_cy",Material::Water},{"water_pf",Material::Water},{"water_in",Material::Water},
        {"oil",Material::Oil},{"lava",Material::Lava},{"acid",Material::Acid},{"cement",Material::Cement},
        {"ice_contact",Material::Ice},{"inert",Material::Wall}};
    require(ids.contains(a.fixture),"unknown fixture"); return ids.at(a.fixture);
}
WorldConfig config(const Args& a,bool diagnostics=true) {
    WorldConfig c; c.worker_threads=a.workers;c.sleep_after_quiet_ticks=a.quiet;c.parallel_job_threshold=1;
    c.initial_chunk_reserve=8;c.maximum_chunk_count=distributed(a)?160:32;
    c.active_chunk_capacity=c.maximum_chunk_count;c.active_core_capacity=distributed(a)?512:64;
    c.physics_diagnostics.enabled=diagnostics;
    if(a.fixture=="water_cy" || a.fixture=="water_pf" || a.fixture=="water_in") {
        auto request=LiquidSolverPolicy::default_request();
        request[21]=a.fixture=="water_cy"?2:a.fixture=="water_pf"?3:4;
        const auto decoded=LiquidSolverPolicy::decode(std::span<const std::int32_t>(request));
        require(decoded.accepted(),"registered Water policy refused: "+decoded.refusal.message());
        c.liquid_solver_policy=*decoded.policy;
        if(a.fixture=="water_in") c.maximum_rule_radius=3;
    }
    return c;
}
struct Fixture {
    std::vector<Point> domain,origins;
    std::set<unsigned> allowed;
};
void room(World& w,std::set<Point>& points,std::int64_t x,std::int64_t y,int width,int height) {
    w.reserve_region({x-1,y-1,width+2,height+2});
    for(auto yy=y-1;yy<=y+height;++yy) for(auto xx=x-1;xx<=x+width;++xx) {
        points.insert({xx,yy});w.set(xx,yy,Material::Wall);
    }
}
Fixture construct(World& w,const Args& a) {
    Fixture f;std::set<Point> points;const auto mat=subject(a);
    f.allowed={static_cast<unsigned>(mat),static_cast<unsigned>(Material::Wall),static_cast<unsigned>(Material::Empty)};
    if(molten(a)) f.allowed.insert(static_cast<unsigned>(Material::Glass));
    if(a.fixture=="cement") f.allowed.insert(static_cast<unsigned>(Material::Concrete));
    if(a.fixture=="ice_contact") f.allowed.insert(static_cast<unsigned>(Material::Water));
    if(a.busy) f.allowed.insert(static_cast<unsigned>(Material::Smoke));
    for(int i=0;i<(distributed(a)?64:1);++i) {
        const auto x=a.x+128*i,y=a.y;f.origins.push_back({x,y});
        if(molten(a)) {
            const int width=a.fixture=="molten_pool_small"?3:a.fixture=="molten_pool_large"?12:
                (a.fixture=="molten_pair" || a.fixture=="molten_hot" || a.fixture=="molten_lost_neighbor" || a.fixture=="molten_heterogeneous" || a.variant=="neighbor_mask")?2:1;
            const int enclosure_width=a.variant=="neighbor_edit"?std::max(width,2):width;
            const int height=a.fixture=="molten_pool_small"?3:a.fixture=="molten_pool_large"?12:1;
            room(w,points,x,y,enclosure_width,height);
            const unsigned state=a.fixture=="molten_short"?4U:
                (a.fixture=="molten_pair" || a.fixture=="molten_pool_small" || a.fixture=="molten_hot" || a.fixture=="molten_heterogeneous")?7U:180U;
            for(int dy=0;dy<height;++dy) for(int dx=0;dx<width;++dx) {
                const auto m=(dx==1 && (a.fixture=="molten_hot" || a.fixture=="molten_heterogeneous"))?Material::Lava:mat;
                w.set(x+dx,y+dy,m);
                if(m==Material::MoltenGlass) {
                    (void)w.set_cell_state(x+dx,y+dy,m,static_cast<std::uint16_t>(state),0);
                    require(w.stored_material(x+dx,y+dy)==m && w.stored_state_a(x+dx,y+dy)==state && w.stored_state_b(x+dx,y+dy)==0,
                        "MoltenGlass initial state readback mismatch");
                }
                f.allowed.insert(static_cast<unsigned>(m));
            }
            if(a.fixture=="molten_cold" || a.fixture=="molten_heterogeneous") {
                w.set_temperature(x,y,-300); w.set_temperature(x-1,y,-300);
            }
            if(a.fixture=="molten_hot" || a.fixture=="molten_heterogeneous") w.set_temperature(x+1,y,2000);
        } else if(a.fixture=="ice_contact") {
            room(w,points,x,y,2,1);w.set(x,y,Material::Ice);w.set(x+1,y,Material::Water);
        } else {
            room(w,points,x-1,y,3,1);w.set(x,y,mat);
            if(a.fixture!="inert") {
                if(a.variant!="right_only" && a.variant!="blocked" && a.variant!="neighbor_edit" && a.variant!="destination_mask") w.set(x-1,y,Material::Empty);
                if(a.variant!="left_only" && a.variant!="blocked" && a.variant!="neighbor_edit") w.set(x+1,y,Material::Empty);
            }
        }
    }
    if(a.busy) {
        std::set<Point> core_origins;
        for(const auto& p:points) if(w.stored_material(p.first,p.second)==mat)
            core_origins.insert({core_floor(p.first)*64,core_floor(p.second)*64});
        for(const auto& [cx,cy]:core_origins) {
            bool found=false;
            for(const int oy:{48,40,16}) for(const int ox:{48,40,16}) {
                if(found) continue;
                const auto x=cx+ox,y=cy+oy;
                bool clear=true;
                for(int dy=-3;dy<=3;++dy) for(int dx=-3;dx<=3;++dx)
                    if(points.contains({x+dx,y+dy})) clear=false;
                if(!clear) continue;
                room(w,points,x,y,1,1);w.set(x,y,Material::Smoke);
                require(w.set_cell_state(x,y,Material::Smoke,255,0),"Smoke state rejected");found=true;
            }
            require(found,"no separated active-neighbor chamber in source core");
        }
    }
    f.domain.assign(points.begin(),points.end());
    if(a.variant=="source_mask" || a.variant=="destination_mask" || a.variant=="neighbor_mask")
        w.configure_transient_obstacles({a.x-3,a.y-3,20,20});
    return f;
}
struct Events {
    std::uint64_t down=0,down_all=0,lateral=0,moves=0,conversions=0,glass_conversions=0,wakes=0,sleeps=0,water_updates=0;
};
Events events(const World& w,Material m) {
    Events e; const auto* p=w.physics_diagnostics();require(p!=nullptr && p->overflow==0,"diagnostic overflow or unavailable");
    for(const auto& row:p->entries) {
        if(!row.key) continue;
        const auto event=row.key>>24U,source=(row.key>>16U)&255U,target=(row.key>>8U)&255U,dir=row.key&255U;
        if(event==static_cast<unsigned>(PhysicsEvent::BlockWake)) e.wakes+=row.count;
        if(event==static_cast<unsigned>(PhysicsEvent::BlockSleep)) e.sleeps+=row.count;
        if(source!=static_cast<unsigned>(m)) continue;
        if(event==static_cast<unsigned>(PhysicsEvent::RejectedMove) && dir==7) e.down+=row.count;
        if(event==static_cast<unsigned>(PhysicsEvent::RejectedMove) && dir>=6 && dir<=8) e.down_all+=row.count;
        if(event==static_cast<unsigned>(PhysicsEvent::LateralProbe)) e.lateral+=row.count;
        if(event==static_cast<unsigned>(PhysicsEvent::EmptyMove) || event==static_cast<unsigned>(PhysicsEvent::DensitySwap)) e.moves+=row.count;
        if(event==static_cast<unsigned>(PhysicsEvent::Conversion)) {
            e.conversions+=row.count;
            if(m==Material::MoltenGlass && target==static_cast<unsigned>(Material::Glass)) e.glass_conversions+=row.count;
        }
        if(event==static_cast<unsigned>(PhysicsEvent::WaterUpdate)) e.water_updates+=row.count;
    }
    return e;
}
struct Census {
    std::array<std::uint64_t,256> count{};
    std::uint64_t water=0,hash=14695981039346656037ULL;
};
void hash_value(std::uint64_t& h,std::uint64_t n) { for(int i=0;i<8;++i) { h^=n&255U;h*=1099511628211ULL;n>>=8U; } }
Census census(const World& w,const Fixture& f) {
    Census c;
    for(const auto& [x,y]:f.domain) {
        const auto m=w.stored_material(x,y);const auto id=static_cast<unsigned>(m);
        require(f.allowed.contains(id),"unexpected material product "+std::to_string(id));
        if(m!=Material::Empty) ++c.count[id];
        hash_value(c.hash,static_cast<std::uint64_t>(x));hash_value(c.hash,static_cast<std::uint64_t>(y));
        hash_value(c.hash,id);hash_value(c.hash,w.stored_state_a(x,y));hash_value(c.hash,w.stored_state_b(x,y));
        hash_value(c.hash,static_cast<std::uint16_t>(w.stored_temperature(x,y)));
        if(m==Material::Water) c.water+=w.stored_state_a(x,y)+w.pressure_cell(x,y).overfill;
    }
    const auto ledger=w.quantity_ledger();
    require(c.count==ledger.material_cells,"independent domain census disagrees with material ledger (escape or accounting)");
    require(c.water==ledger.water_visible+ledger.water_overfill,"independent Water census disagrees with ledger");
    std::uint64_t produced=ledger.baseline_water,consumed=0;
    for(const auto flow:ledger.kinds) {produced+=flow.produced;consumed+=flow.consumed;}
    require(produced>=consumed && produced-consumed==c.water,"Water sources/sinks do not close");
    return c;
}
std::array<std::uint64_t,256> conserved_species(const Census& c,const Args& a) {
    auto values=c.count;
    const auto id=[](Material m){return static_cast<unsigned>(m);};
    if(molten(a)) {values[id(Material::MoltenGlass)]+=values[id(Material::Glass)];values[id(Material::Glass)]=0;}
    if(a.fixture=="cement") {values[id(Material::Cement)]+=values[id(Material::Concrete)];values[id(Material::Concrete)]=0;}
    if(a.fixture=="ice_contact") {values[id(Material::Ice)]+=values[id(Material::Water)];values[id(Material::Water)]=0;}
    // FreeMass can split one carrier into several cells. Its exact independent
    // Water-quantity invariant below replaces a false cell-count invariant.
    if(a.fixture.starts_with("water_")) values[id(Material::Water)]=0;
    return values;
}
Point carrier(const World& w,const Fixture& f,const Args& a) {
    if(generic(a) && !distributed(a)) {
        for(const auto& p:f.domain) if(w.stored_material(p.first,p.second)==subject(a)) return p;
    }
    return {a.x,a.y};
}
bool hot(const World& w,Point p) {
    for(int dy=-1;dy<=1;++dy) for(int dx=-1;dx<=1;++dx) if(dx || dy) {
        const auto m=w.get(p.first+dx,p.second+dy);
        if(m==Material::MoltenGlass || m==Material::Lava || m==Material::Fire) return true;
    }
    return false;
}
void print_block(const PrecisionProbe::Block& b) {
    std::cout<<"{\"active\":"<<(b.active?"true":"false")<<",\"quiet\":"<<b.quiet<<",\"due\":"<<b.due<<'}';
}
std::string edit(World& w,const Args& a,unsigned step,Point current_source) {
    std::string cause="none";
    if(step==9 && (a.variant=="source_mask" || a.variant=="destination_mask" || a.variant=="neighbor_mask")) {
        const auto target=a.variant=="source_mask"?current_source:Point{a.x+1,a.y};
        require(w.set_transient_obstacle(target.first,target.second,1),"mask insertion rejected");cause="mask_insert";
    }
    if(step==17 && (a.variant=="source_mask" || a.variant=="destination_mask" || a.variant=="neighbor_mask")) {
        w.clear_transient_obstacles();cause="mask_remove";
    }
    if(a.variant=="region") {
        if(step==9) {w.set_simulation_region(RectI64{32768,32768,64,64});cause="region_exclude";}
        if(step==17) {w.set_simulation_region(std::nullopt);cause="region_reenter";}
    }
    if(step==17) {
        if(a.fixture=="molten_lost_neighbor") {w.set(a.x+1,a.y,Material::Wall);cause="partner_remove";}
        if(a.fixture=="molten_removed") {w.set(a.x,a.y,Material::Wall);cause="source_remove";}
        if(a.variant=="source_edit") {
            (void)w.set_cell_state(current_source.first,current_source.second,subject(a),molten(a)?4:9,0);
            require(w.stored_material(current_source.first,current_source.second)==subject(a) &&
                w.stored_state_a(current_source.first,current_source.second)==(molten(a)?4:9),"source edit readback mismatch");cause="source_edit";
        }
        if(a.variant=="neighbor_edit") {
            w.set(a.x+1,a.y,molten(a)?Material::MoltenGlass:Material::Empty);cause="neighbor_edit";
        }
    }
    return cause;
}
int run(const Args& a) {
    auto w=std::make_unique<World>(config(a)); auto f=construct(*w,a);const auto mat=subject(a);
    const auto initial=census(*w,f);
    auto expected_species=conserved_species(initial,a);
    const unsigned viscosity=MaterialRules::descriptor(mat).viscosity_index;
    if(a.fixture=="paste") require(viscosity==240,"Paste descriptor drift");
    if(a.fixture=="slush") require(viscosity==192,"Slush descriptor drift");
    if(a.fixture=="brine") require(viscosity==32,"Brine descriptor drift");
    if(a.fixture=="mercury") require(viscosity==96,"Mercury descriptor drift");
    std::cout<<"{\"type\":\"metadata\",\"schema\":\"mat354.probe.v1\",\"case_id\":"<<quoted(a.id())
        <<",\"fixture\":"<<quoted(a.fixture)<<",\"variant\":"<<quoted(a.variant)<<",\"x\":"<<a.x<<",\"y\":"<<a.y
        <<",\"quiet\":"<<a.quiet<<",\"workers\":"<<a.workers<<",\"horizon\":"<<a.ticks<<",\"repeat\":"<<a.repeat
        <<",\"active_neighbour\":"<<(a.busy?"true":"false")<<",\"rng_seed\":null,\"rng_identity\":\"native-coordinate-tick-stream\""
        <<",\"material\":"<<static_cast<unsigned>(mat)<<",\"descriptor_viscosity\":"<<viscosity
        <<",\"initial_state_a\":"<<w->stored_state_a(a.x,a.y)<<",\"initial_temperature\":"<<w->stored_temperature(a.x,a.y)
        <<",\"chunk_size\":128,\"activity_block_size\":32,\"scheduling_core_size\":64,\"parallel_job_threshold\":1"
        <<",\"maximum_rule_radius\":"<<w->config().maximum_rule_radius<<",\"active_core_capacity\":"<<w->config().active_core_capacity
        <<",\"maximum_chunk_count\":"<<w->config().maximum_chunk_count<<",\"domain_cells\":"<<f.domain.size()
        <<",\"origin_count\":"<<f.origins.size()<<",\"kernel_counter_scope\":\"whole-world subject material; singleton only is cell-specific\""
        <<",\"physical_hash_version\":"<<w->physical_state_hash_version()<<"}\n";
    Events previous=events(*w,mat);std::uint64_t first=0,last=0,first_move=0,first_glass=0,total_visits=0,total_jobs=0;
    unsigned max_workers=0,reset_epoch=0;std::unique_ptr<World> fresh;
    std::uint64_t tick_ns_total=0,last_hash=w->physical_state_hash();
    for(unsigned step=1;step<=a.ticks;++step) {
        std::string cause=edit(*w,a,step,carrier(*w,f,a));
        const auto wall=static_cast<unsigned>(Material::Wall),mg=static_cast<unsigned>(Material::MoltenGlass);
        if(cause=="partner_remove" || cause=="source_remove") {require(expected_species[mg]>0,"unexpected removal");--expected_species[mg];++expected_species[wall];}
        if(cause=="neighbor_edit") {require(expected_species[wall]>0,"unexpected neighbor edit");--expected_species[wall];if(molten(a))++expected_species[mg];}
        if(a.variant=="reset" && step==17) {
            w->clear();w->set_simulation_region(std::nullopt);f=construct(*w,a);previous=events(*w,mat);
            expected_species=conserved_species(census(*w,f),a);
            fresh=std::make_unique<World>(config(a));(void)construct(*fresh,a);++reset_epoch;cause="reset";
        }
        const bool paused=a.variant=="owner_pause" && step>=9 && step<=16;
        if(paused) cause="owner_pause";
        if(a.variant=="owner_pause" && step==17) cause="owner_resume";
        const auto p=carrier(*w,f,a);const auto before=PrecisionProbe::block(*w,p.first,p.second);
        const auto material_before=w->stored_material(p.first,p.second);
        const auto a_before=w->stored_state_a(p.first,p.second);
        const auto phase=mix_reference(spatial_reference(p.first,p.second,192U))%4U;
        const auto next=w->tick_index()+(paused?0U:1U);
        const auto random_stream=molten(a)?127U:a.fixture=="cement"?124U:91U;
        const bool mobility_applicable=(generic(a) || (molten(a) && mat==Material::MoltenGlass) || a.fixture=="cement" || a.fixture=="water_cy");
        const auto draw=draw_reference(p.first,p.second,next,random_stream);
        const bool lateral=(w->get(p.first-1,p.second)==Material::Empty || w->get(p.first+1,p.second)==Material::Empty);
        const bool hot_before=hot(*w,p),masked=w->transient_obstacle_at(p.first,p.second)!=0;
        TickStats stats{};const auto start=std::chrono::steady_clock::now();
        if(!paused) stats=w->tick();
        const auto tick_ns=paused?0ULL:static_cast<std::uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::steady_clock::now()-start).count());
        tick_ns_total+=tick_ns;
        require(!w->has_failed() && w->completed_tick_index()==w->tick_index(),"World failed or incomplete tick");
        if(!paused) require(PrecisionProbe::random(*w,p.first,p.second,random_stream)==draw,"reference random identity mismatch");
        const auto after=PrecisionProbe::block(*w,p.first,p.second);const auto e=events(*w,mat);
        const auto actual_visits=e.down-previous.down+e.glass_conversions-previous.glass_conversions;
        const bool visit_observable=(generic(a) || (molten(a) && mat==Material::MoltenGlass));
        if(visit_observable && actual_visits) {if(first==0) first=step;last=step;}
        if(e.moves>previous.moves && first_move==0) first_move=step;
        if(e.glass_conversions>previous.glass_conversions && first_glass==0) first_glass=step;
        const auto c=census(*w,f);const auto current=carrier(*w,f,a);
        require(conserved_species(c,a)==expected_species,"independent species invariant violated (creation/deletion/unexpected conversion)");
        if(a.fixture.starts_with("water_")) require(c.water==initial.water,"closed protected Water quantity changed");
        bool reset_fresh_equal=true;
        if(fresh) {
            const auto fresh_stats=fresh->tick();const auto fresh_c=census(*fresh,f);
            const auto fresh_b=PrecisionProbe::block(*fresh,current.first,current.second);
            reset_fresh_equal=fresh_c.hash==c.hash && fresh_b.active==after.active && fresh_b.quiet==after.quiet && fresh_b.due==after.due &&
                fresh_stats.visited_cells==stats.visited_cells && fresh_stats.scheduled_cores==stats.scheduled_cores;
            require(reset_fresh_equal,"reset reconstruction differs from fresh physical/scheduling state");
        }
        last_hash=w->physical_state_hash();total_visits+=stats.visited_cells;total_jobs+=stats.scheduled_cores;
        max_workers=std::max(max_workers,stats.worker_threads_observed);
        std::cout<<"{\"type\":\"tick\",\"tick\":"<<step<<",\"world_tick\":"<<w->tick_index()<<",\"reset_epoch\":"<<reset_epoch
            <<",\"paused\":"<<(paused?"true":"false")<<",\"wake_cause\":"<<quoted(cause)<<",\"source_x\":"<<p.first<<",\"source_y\":"<<p.second
            <<",\"carrier_x\":"<<current.first<<",\"carrier_y\":"<<current.second<<",\"material_before\":"<<static_cast<unsigned>(material_before)
            <<",\"state_a_before\":"<<a_before<<",\"material\":"<<static_cast<unsigned>(w->stored_material(current.first,current.second))
            <<",\"state_a\":"<<w->stored_state_a(current.first,current.second)<<",\"state_b\":"<<static_cast<unsigned>(w->stored_state_b(current.first,current.second))
            <<",\"temperature\":"<<w->stored_temperature(current.first,current.second)<<",\"thermal_phase\":"<<phase
            <<",\"cooling_due\":"<<(!paused && next%4U==phase?"true":"false")<<",\"hot_neighbor_before\":"<<(hot_before?"true":"false")
            <<",\"source_masked\":"<<(masked?"true":"false")<<",\"mobility_applicable\":"<<(mobility_applicable?"true":"false")
            <<",\"rng_stream\":"<<random_stream<<",\"mobility_draw\":"<<draw
            <<",\"mobility_threshold\":"<<(a.fixture=="water_cy"?256U:256U-viscosity)<<",\"lateral_eligible\":"<<(lateral?"true":"false")
            <<",\"block_before\":";print_block(before);std::cout<<",\"block_after\":";print_block(after);
        std::cout<<",\"visited_cells\":"<<stats.visited_cells<<",\"kernel_visits\":";
        if(visit_observable) std::cout<<actual_visits;else std::cout<<"null";
        std::cout<<",\"down_rejections\":"<<e.down-previous.down<<",\"down_all_rejections\":"<<e.down_all-previous.down_all
            <<",\"lateral_probes\":"<<e.lateral-previous.lateral<<",\"subject_moves\":"<<e.moves-previous.moves
            <<",\"subject_conversions\":"<<e.conversions-previous.conversions<<",\"glass_conversions\":"<<e.glass_conversions-previous.glass_conversions
            <<",\"block_wakes\":"<<e.wakes-previous.wakes<<",\"block_sleeps\":"<<e.sleeps-previous.sleeps
            <<",\"water_updates\":"<<e.water_updates-previous.water_updates<<",\"scheduled_cores\":"<<stats.scheduled_cores<<",\"phase_jobs\":[";
        for(std::size_t i=0;i<stats.phase_jobs.size();++i) {if(i)std::cout<<',';std::cout<<stats.phase_jobs[i];}
        std::cout<<"],\"worker_threads_observed\":"<<stats.worker_threads_observed<<",\"active_blocks_after\":"<<stats.active_blocks_after
            <<",\"active_chunks_after\":"<<stats.active_chunks_after<<",\"chunk_allocations\":"<<stats.chunk_allocations
            <<",\"temperature_field_allocations\":"<<stats.temperature_field_allocations<<",\"resident_cell_bytes\":"<<w->resident_cell_bytes()
            <<",\"water_quantity\":"<<c.water<<",\"subject_count\":"<<c.count[static_cast<unsigned>(mat)]
            <<",\"glass_count\":"<<c.count[static_cast<unsigned>(Material::Glass)]<<",\"tick_ns\":"<<tick_ns
            <<",\"has_failed\":false,\"quantity_ok\":true,\"reset_fresh_equal\":"<<(reset_fresh_equal?"true":"false")
            <<",\"physical_hash\":"<<quoted(hex(last_hash))<<",\"tuple_hash\":"<<quoted(hex(c.hash))<<"}\n";
        previous=e;
    }
    const auto final=census(*w,f);const auto l=w->quantity_ledger();
    std::cout<<"{\"type\":\"summary\",\"case_id\":"<<quoted(a.id())<<",\"has_failed\":false,\"quantity_ok\":true"
        <<",\"physical_hash\":"<<quoted(hex(last_hash))<<",\"tuple_hash\":"<<quoted(hex(final.hash))
        <<",\"first_kernel_visit\":"<<first<<",\"last_kernel_visit\":"<<last<<",\"first_move\":"<<first_move<<",\"first_glass\":"<<first_glass
        <<",\"selected_visits\":"<<total_visits<<",\"scheduled_jobs\":"<<total_jobs<<",\"max_workers_observed\":"<<max_workers
        <<",\"tick_ns_total\":"<<tick_ns_total<<",\"final_world_tick\":"<<w->tick_index()<<",\"final_subject_count\":"<<final.count[static_cast<unsigned>(mat)]
        <<",\"final_glass_count\":"<<final.count[static_cast<unsigned>(Material::Glass)]<<",\"source_sink_kinds\":[";
    for(std::size_t i=0;i<l.kinds.size();++i) {if(i)std::cout<<',';std::cout<<"{\"produced\":"<<l.kinds[i].produced<<",\"consumed\":"<<l.kinds[i].consumed<<'}';}
    std::cout<<"],\"material_counts\":[";
    bool comma=false;for(std::size_t i=1;i<final.count.size();++i) if(final.count[i]) {if(comma)std::cout<<',';comma=true;std::cout<<"["<<i<<','<<final.count[i]<<']';}
    std::cout<<"]}\n";return 0;
}
}

int main(int argc,char** argv) {
    try {return mat354::run(mat354::parse(argc,argv));}
    catch(const std::exception& e) {
        std::cout<<"{\"type\":\"failure\",\"message\":"<<mat354::quoted(e.what())<<"}\n";
        std::cerr<<e.what()<<'\n';return 1;
    }
}
