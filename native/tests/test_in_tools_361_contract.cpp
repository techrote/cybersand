// IN-TOOLS #361 preparation only. Exercises CURRENT native primitives.
// Test-side guarded edits below are experimental protocol, not a gameplay API.
#include "cybersand/world.hpp"
#include "cybersand/material_rules.hpp"
#include "cybersand/prepared_world.hpp"
#include <algorithm>
#include <array>
#include <chrono>
#include <iostream>
#include <memory>
#include <numeric>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using namespace cybersand;
std::uint64_t checks = 0;
void require(bool ok, const char* message) { ++checks; if (!ok) throw std::runtime_error(message); }
WorldConfig config(Material m, bool inertial, std::uint32_t workers=1, std::uint8_t bits=8) {
    WorldConfig c;
    auto words=LiquidSolverPolicy::default_request();
    if(inertial) words[m==Material::Water?21U:39U]=4;
    auto decoded=LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
    require(decoded.accepted(), "registered policy refused");
    c.liquid_solver_policy=*decoded.policy;
    c.maximum_rule_radius=3; c.worker_threads=workers; c.parallel_job_threshold=1;
    c.water_experiment_policy=WaterExperimentPolicy(bits,12);
    return c;
}
std::uint64_t quantity(const World& w, Material m) {
    const auto l=w.quantity_ledger();
    return m==Material::Water ? l.water_visible+l.water_overfill : l.material_cells[static_cast<std::uint8_t>(m)];
}
void conservation(const World& w) {
    const auto l=w.quantity_ledger();
    std::uint64_t p=l.baseline_water,c=0;
    for(const auto& flow:l.kinds){p+=flow.produced;c+=flow.consumed;}
    require(p>=c&&p-c==l.water_visible+l.water_overfill,"native water ledger does not close");
}
void rect(World& w, std::int64_t x,std::int64_t y,int width,int height,Material m) {
    for(int dy=0;dy<height;++dy)for(int dx=0;dx<width;++dx)w.set(x+dx,y+dy,m);
}
void ingress() {
    for(auto bits:{std::uint8_t{3},std::uint8_t{8}}){
        auto w=std::make_unique<World>(config(Material::Water,true,1,bits));
        const auto q=w->config().water_experiment_policy.maximum();
        require(w->set_cell_state(5,5,Material::Water,q,0),"full Water refused");
        const auto before=w->save_physical_state();
        const auto l=w->quantity_ledger(); const auto n=w->chunk_count();
        for(const auto amount:{std::uint16_t{1},static_cast<std::uint16_t>(q/2),static_cast<std::uint16_t>(q-1)}){
            require(!w->set_cell_state(5,5,Material::Water,amount,0),"fractional replacement accepted");
            require(!w->set_cell_state(2000,2000,Material::Water,amount,0),"fractional sparse source accepted");
        }
        require(w->save_physical_state()==before&&w->quantity_ledger()==l&&w->chunk_count()==n,"fractional refusal mutated authoritative state");
        require(quantity(*w,Material::Water)==q,"incorrect source quantum");
        require(w->set_cell_state(5,5,Material::Water,0,0),"zero Water should be explicit removal");
        require(quantity(*w,Material::Water)==0,"zero Water failed to remove quantity");
        require(w->quantity_ledger().kinds[static_cast<std::size_t>(QuantityKind::ExternalEdit)].consumed==q,"removal not accounted as ExternalEdit sink");
        conservation(*w);
        normalization::FinalSetupInput input;input.mass_bits=bits;input.setup.domain={0,0,16,16};
        input.cells={{3,3,Material::Water,static_cast<std::uint16_t>(q/2U),0,200},
                     {4,3,Material::Water,static_cast<std::uint16_t>(q/2U+1U),0,200}};
        auto refused=PreparedWorldBuilder::prepare(w->config(),input,normalization::NormalizationOptIn::None);
        require(std::get_if<ConstructionRefusal>(&refused)&&std::get<ConstructionRefusal>(refused).policy_refusal()->code==LiquidPolicyRefusalCode::NormalizationRequired,"prepared fractional Water did not refuse");
        auto admitted=PreparedWorldBuilder::prepare(w->config(),input,normalization::NormalizationOptIn::WaterNormalizeV1);
        require(std::get_if<PreparedWorld>(&admitted)!=nullptr,"explicit setup normalization refused");
        auto& prepared=std::get<PreparedWorld>(admitted);const auto totals=prepared.setup().normalization_receipt()->totals();
        require(totals.cells_up==1&&totals.cells_down==1&&totals.water_before==q&&totals.water_after==q&&totals.positive_delta==q/2U&&totals.negative_delta==q/2U&&totals.net_delta==0,"setup normalization gross ledger mismatch");
        require(quantity(prepared.world(),Material::Water)==q&&quantity(*w,Material::Water)==0,"normalization changed old owner");
        auto limited=PreparedWorldBuilder::prepare(w->config(),input,normalization::NormalizationOptIn::WaterNormalizeV1,{1});
        require(std::get_if<ConstructionRefusal>(&limited)&&std::get<ConstructionRefusal>(limited).policy_refusal()->code==LiquidPolicyRefusalCode::CapacityRefused,"prepared tuple capacity not refused");
    }
    auto brine=std::make_unique<World>(config(Material::Brine,true));
    brine->set(1,1,Material::Brine);
    require(quantity(*brine,Material::Brine)==1&&brine->quantity_ledger().water_visible==0,"Brine quantum incorrectly treated as Water mass");
    auto old=brine->save_physical_state();
    auto request=LiquidSolverPolicy::default_request();request[24]=4; // Oil IN unavailable.
    require(!LiquidSolverPolicy::decode(std::span<const std::int32_t>(request)).accepted(),"Oil admitted IN");
    auto bad=config(Material::Water,true);bad.maximum_rule_radius=2;
    bool refused=false;try{World replacement(bad);}catch(const std::exception&){refused=true;}
    require(refused&&old==brine->save_physical_state(),"invalid construction mutated old owner");
    std::cout<<"{\"case_id\":\"native.ingress.v1\",\"status\":\"pass\",\"water_quanta\":[7,255],\"brine_quantum_cells\":1}";
}
void edit_refusals() {
    auto w=std::make_unique<World>(config(Material::Water,true));
    w->reserve_region({0,0,128,128});w->configure_transient_obstacles({0,0,128,128});
    require(w->set_transient_obstacle(4,4,1),"mask setup failed");
    const auto before=w->save_physical_state();
    require(!w->set_cell_state(4,4,Material::Wall,0,0)&&!w->set_cell_state(4,4,Material::Water,255,0),"occupied mask accepted placement");
    w->set(4,4,Material::Wall);
    require(w->stored_material(4,4)==Material::Empty&&before==w->save_physical_state(),"void set bypassed mask refusal");
    w->set(5,5,Material::Water);require(w->set_transient_obstacle(5,5,2),"stored-cell mask setup failed");
    require(w->set_cell_state(5,5,Material::Empty,0,0),"current erasure-under-mask semantics changed");
    require(quantity(*w,Material::Water)==0,"masked stored erasure lacked accounting");
    w->set(6,6,Material::Wall);
    require(w->set_cell_state(6,6,Material::Water,255,0),"raw setter replacement unexpectedly protected Wall");
    w->set(7,7,Material::Water);w->set(7,7,Material::Wall);
    require(w->stored_material(7,7)==Material::Wall,"raw close-over-Water replacement changed");
    conservation(*w);
    auto fresh=std::make_unique<World>(config(Material::Water,true));fresh->reserve_region({0,0,128,128});fresh->set(20,20,Material::Water);
    (void)fresh->tick();
    const auto v=fresh->inertial_cell(20,20);
    require(v.vy>0,"native gravity did not provide motion witness");
    const auto l=fresh->quantity_ledger();fresh->set(20,20,Material::Water);
    const auto reset=fresh->inertial_cell(20,20);
    require(reset.vx==0&&reset.vy==0&&reset.ax==0&&reset.ay==0&&fresh->quantity_ledger()==l,"same-material paint did not retire motion without quantity change");
    const auto state=fresh->save_physical_state();
    require(!fresh->diagnostic_set_inertial_cell(20,20,0,-1,0,0)&&!fresh->diagnostic_set_inertial_cell(20,20,33,0,0,0)&&fresh->save_physical_state()==state,"diagnostic limits bypassable");
    std::cout<<",{\"case_id\":\"native.edit-refusals.v1\",\"status\":\"pass\",\"raw_erase_under_mask\":true,\"raw_replace_wall\":true,\"guarded_tool_api_exists\":false},"
             <<"{\"case_id\":\"native.nozzle-no-input.v1\",\"status\":\"pass\",\"source_initial_velocity\":[0,0],\"directed_gameplay_inlet_available\":false}";
}
void capacity() {
    auto cfg=config(Material::Water,true);cfg.backend=SimulationBackend::SerialInPlace;
    cfg.chunk_size=8;cfg.initial_chunk_reserve=cfg.maximum_chunk_count=1;
    auto w=std::make_unique<World>(cfg);w->set(4,7,Material::Water);
    const auto old=w->save_physical_state();bool source_refused=false;
    try{w->set(100,100,Material::Water);}catch(const std::exception&){source_refused=true;}
    require(source_refused&&w->save_physical_state()==old,"sparse source capacity changed prior state");
    bool tick_refused=false;
    for(int t=0;t<8&&!tick_refused;++t){try{(void)w->tick();}catch(const std::exception&){tick_refused=true;}}
    require(tick_refused&&w->has_failed()&&w->completed_tick_index()<w->tick_index(),"real gravity capacity failure did not quarantine");
    require(!w->set_cell_state(4,7,Material::Empty,0,0),"failed owner accepted drain");
    bool set_refused=false;try{w->set(4,7,Material::Empty);}catch(const std::exception&){set_refused=true;}
    require(set_refused,"void set did not reject failed World");
    const auto policy=w->config().liquid_solver_policy.policy_hash();w->clear();
    require(!w->has_failed()&&w->completed_tick_index()==0&&quantity(*w,Material::Water)==0&&w->config().liquid_solver_policy.policy_hash()==policy,"clear did not reset owner with immutable policy retained");
    std::cout<<",{\"case_id\":\"native.capacity-quarantine.v1\",\"status\":\"pass\",\"no_diagnostic_velocity_seed\":true}";
}
struct Tank {int x,y;};
constexpr std::array<Tank,8> tanks{{{-8,-8},{120,-8},{248,-8},{376,-8},{-8,120},{120,120},{248,120},{376,120}}};
constexpr RectI64 census_domain{-128,-128,768,512};
constexpr std::size_t census_chunks=24;
constexpr std::array<std::uint64_t,6> census_ticks{{0,8,24,32,64,224}};
void setup(World& w,Material m){
    w.reserve_region(census_domain);w.configure_transient_obstacles({-32,-32,480,256});
    for(const auto t:tanks){
        rect(w,t.x-2,t.y-2,24,1,Material::Wall);rect(w,t.x-2,t.y+48,24,1,Material::Wall);
        rect(w,t.x-2,t.y-2,1,51,Material::Wall);rect(w,t.x+21,t.y-2,1,51,Material::Wall);
        rect(w,t.x,t.y,20,1,Material::Wall);rect(w,t.x,t.y+18,20,1,Material::Wall);
        rect(w,t.x,t.y,1,19,Material::Wall);rect(w,t.x+19,t.y,1,19,Material::Wall);
        rect(w,t.x+1,t.y+9,18,9,m);
    }
}

// The registered 24 chunks are reserved before the first edit. The World does
// not evict chunks during these probes: equality of chunk_count therefore also
// refuses any new resident chunk outside this complete observed domain.
enum class ExpectedCell { Empty, Wall, LiquidOrEmpty };
ExpectedCell expected_cell(std::int64_t x,std::int64_t y,int width,bool port_open) {
    for(const auto t:tanks) {
        if(x<t.x-2||x>t.x+21||y<t.y-2||y>t.y+48)continue;
        const bool outer=x==t.x-2||x==t.x+21||y==t.y-2||y==t.y+48;
        bool inner=((x==t.x||x==t.x+19)&&y>=t.y&&y<=t.y+18)||
                   ((y==t.y||y==t.y+18)&&x>=t.x&&x<=t.x+19);
        if(port_open&&y==t.y+18&&x>=t.x+8&&x<t.x+8+width)inner=false;
        return outer||inner ? ExpectedCell::Wall : ExpectedCell::LiquidOrEmpty;
    }
    return ExpectedCell::Empty;
}
void census(const World& w,Material m,int width,bool port_open,const QuantityLedgerSnapshot& ledger) {
    require(w.config().chunk_size==128&&w.chunk_count()==census_chunks,"census resident domain changed");
    std::array<std::uint64_t,kQuantityMaterialSlots> counts{};
    std::uint64_t water=0;
    const auto maximum=w.config().water_experiment_policy.maximum();
    for(std::int64_t y=census_domain.y;y<census_domain.y+census_domain.height;++y) {
        for(std::int64_t x=census_domain.x;x<census_domain.x+census_domain.width;++x) {
            const auto material=w.stored_material(x,y);
            require(material==Material::Empty||material==Material::Wall||material==m,"census found foreign material");
            const auto expected=expected_cell(x,y,width,port_open);
            if(expected==ExpectedCell::Wall)require(material==Material::Wall,"census barrier changed");
            else if(expected==ExpectedCell::Empty)require(material==Material::Empty,"census material escaped tank");
            else require(material==Material::Empty||material==m,"census unexpected interior Wall");
            if(material!=Material::Empty)++counts[static_cast<std::uint8_t>(material)];
            if(material==Material::Water) {
                const auto mass=w.stored_state_a(x,y);
                require(mass>0&&mass<=maximum,"census invalid Water quantity");
                require(!w.whole_cell_water_enabled()||mass==maximum,"census fractional whole-cell Water");
                water+=mass;
            }
        }
    }
    require(counts==ledger.material_cells,"census disagrees with native material counts");
    require(water==ledger.water_visible&&ledger.water_overfill==0,"census disagrees with native Water quantity");
}
void census(const World& w,Material m,int width,bool port_open) {
    census(w,m,width,port_open,w.quantity_ledger());
}
template<typename Check> void expect_census_refusal(Check check,const char* expected) {
    try {check();}
    catch(const std::runtime_error& error) {
        require(std::string(error.what())==expected,"census control failed for the wrong reason");
        return;
    }
    require(false,"corrupt census control was accepted");
}
void census_controls() {
    auto w=std::make_unique<World>(config(Material::Water,true));setup(*w,Material::Water);
    census(*w,Material::Water,1,false);
    auto wrong=w->quantity_ledger();++wrong.water_visible;
    expect_census_refusal([&]{census(*w,Material::Water,1,false,wrong);},"census disagrees with native Water quantity");
    wrong=w->quantity_ledger();++wrong.material_cells[static_cast<std::uint8_t>(Material::Water)];
    expect_census_refusal([&]{census(*w,Material::Water,1,false,wrong);},"census disagrees with native material counts");
    // The old ledger-closure check still passes after a correctly accounted
    // but spatially forbidden write. The independent census must reject it.
    w->set(600,300,Material::Water);conservation(*w);
    expect_census_refusal([&]{census(*w,Material::Water,1,false);},"census material escaped tank");
    w->set(600,300,Material::Empty);census(*w,Material::Water,1,false);
    w->set(tanks[0].x,tanks[0].y+48,Material::Empty);conservation(*w);
    expect_census_refusal([&]{census(*w,Material::Water,1,false);},"census barrier changed");
    w->set(tanks[0].x,tanks[0].y+48,Material::Wall);census(*w,Material::Water,1,false);
    w->reserve_region({768,0,128,128});
    expect_census_refusal([&]{census(*w,Material::Water,1,false);},"census resident domain changed");
}
std::uint64_t reservoir(const World& w,Material m){
    std::uint64_t n=0;
    for(const auto t:tanks)for(int y=1;y<18;++y)for(int x=1;x<19;++x)
        if(w.stored_material(t.x+x,t.y+y)==m)n+=m==Material::Water?w.stored_state_a(t.x+x,t.y+y):1U;
    return n;
}
// Pure test-side preflight followed by primitive edits on a quiescent owner.
// Empty + unmasked is required for every target before ANY close write.
bool close(World& w,int width){
    for(const auto t:tanks)for(int n=0;n<width;++n)
        if(w.stored_material(t.x+8+n,t.y+18)!=Material::Empty||w.transient_obstacle_at(t.x+8+n,t.y+18)!=0)return false;
    for(const auto t:tanks)rect(w,t.x+8,t.y+18,width,1,Material::Wall);
    return true;
}
void open(World& w,int width){for(const auto t:tanks)rect(w,t.x+8,t.y+18,width,1,Material::Empty);}
std::uint64_t drain(World& w,Material m,int width){
    std::uint64_t removed=0;
    for(const auto t:tanks)for(int n=0;n<width;++n){const auto x=t.x+8+n,y=t.y+17;
        if(w.transient_obstacle_at(x,y)==0&&w.stored_material(x,y)==m){
            const auto q=m==Material::Water?w.stored_state_a(x,y):1U;
            require(w.set_cell_state(x,y,Material::Empty,0,0),"selected drain cell refused");removed+=q;
        }}
    return removed;
}
struct Result {std::vector<std::uint64_t> hashes;std::vector<InertialLedger> inertial_ledgers;std::vector<std::uint64_t> census_completed_ticks;std::uint64_t initial=0,remaining=0,removed=0,phase_jobs=0,closed_tick=0,close_refusals=0,flow_tick=0;std::uint32_t observed=0;std::size_t slot_bytes=0,slot_size=0,total_component_bytes=0,resident_cells_bytes=0;double elapsed_ms=0;};
Result flow(Material m,bool in,std::uint32_t workers,int width,bool sink){
    auto cfg=config(m,in,workers);auto w=std::make_unique<World>(cfg);setup(*w,m);
    Result r;r.initial=quantity(*w,m);auto previous=r.initial;bool port_open=false;
    const auto start=std::chrono::steady_clock::now();
    census(*w,m,width,port_open);r.census_completed_ticks.push_back(w->completed_tick_index());
    for(int tick=0;tick<224;++tick){
        if(!sink&&tick==8){open(*w,width);port_open=true;}
        if(!sink&&tick>=24&&tick<200&&r.closed_tick==0){
            const auto before=w->save_physical_state();
            if(close(*w,width)){r.closed_tick=static_cast<std::uint64_t>(tick);port_open=false;}
            else{++r.close_refusals;require(before==w->save_physical_state(),"test-side closure refusal changed authority");}
        }
        if(!sink&&r.closed_tick!=0&&tick==static_cast<int>(r.closed_tick+8U)){open(*w,width);port_open=true;}
        if(sink&&(tick<16||tick>=24))r.removed+=drain(*w,m,width);
        const auto stats=w->tick();r.observed=std::max(r.observed,stats.worker_threads_observed);
        r.phase_jobs+=std::accumulate(stats.phase_jobs.begin(),stats.phase_jobs.end(),std::uint64_t{0});
        require(!w->has_failed(),"registered flow failed");conservation(*w);
        require(w->completed_tick_index()==static_cast<std::uint64_t>(tick+1),"completed native tick disagrees with probe");
        require(quantity(*w,m)+r.removed==r.initial,"unexplained liquid source/sink");
        const auto stored=reservoir(*w,m);if(stored<previous&&r.flow_tick==0)r.flow_tick=static_cast<std::uint64_t>(tick+1);
        previous=stored;
        // Sump floor and side barriers survive all current motion.
        for(const auto t:tanks){
            for(int x=-2;x<22;++x){require(w->stored_material(t.x+x,t.y+48)==Material::Wall,"floor changed");require(w->stored_material(t.x+x,t.y+49)==Material::Empty&&w->stored_material(t.x+x,t.y+50)==Material::Empty,"liquid crossed sump floor");}
            for(int y=-2;y<=48;++y){require(w->stored_material(t.x-2,t.y+y)==Material::Wall&&w->stored_material(t.x+21,t.y+y)==Material::Wall,"side wall changed");require(w->stored_material(t.x-3,t.y+y)==Material::Empty&&w->stored_material(t.x+22,t.y+y)==Material::Empty,"liquid crossed sump side");}
        }
        if(std::find(census_ticks.begin(),census_ticks.end(),w->completed_tick_index())!=census_ticks.end()) {
            census(*w,m,width,port_open);r.census_completed_ticks.push_back(w->completed_tick_index());
        }
        r.hashes.push_back(w->physical_state_hash());
        r.inertial_ledgers.push_back(w->inertial_ledger());
    }
    r.elapsed_ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();
    r.remaining=quantity(*w,m);const auto usage=w->inertial_storage_usage();r.slot_bytes=usage.slot_bytes;r.slot_size=usage.slot_size;r.total_component_bytes=usage.total_component_bytes;r.resident_cells_bytes=w->resident_cell_bytes();
    if(sink){const auto before=w->physical_state_hash();for(const auto t:tanks)require(w->stored_material(t.x-1,t.y-1)==Material::Empty,"empty sink control occupied");require(before==w->physical_state_hash(),"read-only empty sink preflight mutated owner");}
    auto saved=w->save_physical_state();auto reconstructed=World::restore_physical_state(cfg,saved);
    require(reconstructed->physical_state_hash()==w->physical_state_hash(),"fresh owner restore lost authority");
    require(reconstructed->inertial_ledger()==w->inertial_ledger(),"fresh owner restore lost IN diagnostic ledger");
    // Masks are separately host-owned; this fixture's mask is all zero.
    for(int tick=0;tick<8;++tick){
        (void)w->tick();(void)reconstructed->tick();
        require(w->physical_state_hash()==reconstructed->physical_state_hash(),"fresh owner continuation mismatch");
        require(w->inertial_ledger()==reconstructed->inertial_ledger(),"fresh owner continuation IN diagnostic ledger mismatch");
    }
    require(w->completed_tick_index()==232&&reconstructed->completed_tick_index()==232,"restored census tick mismatch");
    census(*w,m,width,port_open);census(*reconstructed,m,width,port_open);
    for(int reset=0;reset<3;++reset){auto a=std::make_unique<World>(cfg);setup(*a,m);auto b=std::make_unique<World>(cfg);setup(*b,m);require(a->physical_state_hash()==b->physical_state_hash(),"fresh setup nondeterministic");}
    return r;
}

void mask_barrier() {
    for(const auto m:{Material::Water,Material::Brine})for(const bool in:{false,true}){
        auto w=std::make_unique<World>(config(m,in));w->reserve_region({0,0,128,128});w->configure_transient_obstacles({0,0,128,128});
        rect(*w,0,0,33,1,Material::Wall);rect(*w,0,32,33,1,Material::Wall);rect(*w,0,0,1,33,Material::Wall);rect(*w,32,0,1,33,Material::Wall);
        for(int x=1;x<32;++x)require(w->set_transient_obstacle(x,16,1),"mask barrier setup failed");
        rect(*w,10,8,12,8,m);const auto amount=quantity(*w,m);
        for(int tick=0;tick<64;++tick){(void)w->tick();require(quantity(*w,m)==amount,"mask barrier lost quantity");conservation(*w);
            for(int y=17;y<32;++y)for(int x=1;x<32;++x)require(w->stored_material(x,y)==Material::Empty,"liquid crossed body-mask barrier");
        }
    }
    std::cout<<",{\"case_id\":\"native.mask-barrier.v1\",\"status\":\"pass\",\"barrier_kind\":\"transient-native-mask-not-Rapier\",\"ticks_per_arm\":64}";
}
void exhaustion() {
    for(const auto m:{Material::Water,Material::Brine}){
        auto w=std::make_unique<World>(config(m,true));setup(*w,m);
        // Each registered sink location is read before the primitive removal.
        const auto before=quantity(*w,m);const auto removed=drain(*w,m,1);
        require(removed==8U*(m==Material::Water?255U:1U)&&quantity(*w,m)+removed==before,"explicit drain quantity mismatch");
        const auto snapshot=w->save_physical_state();require(drain(*w,m,1)==0&&w->save_physical_state()==snapshot,"empty sink mutated state");
        open(*w,1);require(w->set_transient_obstacle(tanks[0].x+8,tanks[0].y+18,1),"closure mask setup");
        const auto masked=w->save_physical_state();require(!close(*w,1)&&masked==w->save_physical_state(),"guarded test closure bypassed mask");
    }
    std::cout<<",{\"case_id\":\"native.sink-exhaustion.v1\",\"status\":\"pass\",\"zero_removal_on_second_call\":true}";
}

void flows(){
    census_controls();
    for(const auto m:{Material::Water,Material::Brine})for(const bool in:{false,true})for(const int width:{1,4})for(const bool sink:{false,true}){
        const auto one=flow(m,in,1,width,sink);const auto four=flow(m,in,4,width,sink);
        require(one.hashes==four.hashes,"one/four complete-state trace differs");
        require(one.inertial_ledgers==four.inertial_ledgers,"one/four IN diagnostic-ledger trace differs");
        const std::vector<std::uint64_t> expected_censuses(census_ticks.begin(),census_ticks.end());
        require(one.census_completed_ticks==expected_censuses&&four.census_completed_ticks==expected_censuses,"independent census checkpoints incomplete");
        require(one.phase_jobs>0&&four.phase_jobs>0,"no native phase participation");
        require(one.remaining==four.remaining&&one.removed==four.removed,"one/four quantities differ");
        std::cout<<",{\"case_id\":\"native."<<(sink?"drain-active-stopped-empty":"leak-closure-reopen")<<".v1\",\"status\":\"pass\",\"material\":\""<<(m==Material::Water?"Water":"Brine")<<"\",\"family\":\""<<(in?"inertial_cellular_v1":m==Material::Water?"freemass_v1":"cellular_yield_v1")<<"\",\"width\":"<<width<<",\"ticks\":224,\"initial_quantity\":"<<one.initial<<",\"remaining_quantity\":"<<one.remaining<<",\"removed_quantity\":"<<one.removed<<",\"first_reservoir_depletion_tick\":"<<one.flow_tick<<",\"close_applied_tick\":"<<one.closed_tick<<",\"close_refusals\":"<<one.close_refusals<<",\"phase_jobs\":"<<one.phase_jobs<<",\"workers1_observed\":"<<one.observed<<",\"workers4_observed\":"<<four.observed<<",\"parity\":true,\"inertial_ledger_parity\":true,\"census_completed_ticks\":[0,8,24,32,64,224],\"census_cells\":393216,\"census_chunks\":24,\"restored_census_completed_tick\":232,\"inertial_slot_bytes\":"<<one.slot_bytes<<",\"inertial_slot_size\":"<<one.slot_size<<",\"inertial_total_component_bytes\":"<<one.total_component_bytes<<",\"resident_cells_bytes\":"<<one.resident_cells_bytes<<",\"instrumented_elapsed_ms_workers1\":"<<one.elapsed_ms<<",\"instrumented_elapsed_ms_workers4\":"<<four.elapsed_ms<<"}";
    }
    std::cout<<",{\"case_id\":\"native.owner-reconstruction.v1\",\"status\":\"pass\",\"restore_and_continue_ticks_per_arm\":8,\"fresh_setup_pairs_per_arm\":3,\"restore_inertial_ledger_parity\":true}";
}
}
int main(){
    try{std::cout<<"{\"schema\":\"in-tools-native-primitives-v2\",\"scope\":\"native-core-only\",\"production_tool_implemented\":false,\"cases\":[";ingress();edit_refusals();capacity();mask_barrier();exhaustion();flows();std::cout<<"],\"census_negative_controls\":[\"water-quantity-mismatch\",\"material-count-mismatch\",\"escaped-liquid\",\"missing-wall\",\"extra-chunk\"],\"checks\":"<<checks<<",\"status\":\"pass\"}\n";return 0;}
    catch(const std::exception& e){std::cerr<<"IN-TOOLS native primitive failure: "<<e.what()<<"\n";return 1;}
}
