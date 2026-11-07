// Water-specific IN admission, actual carrier ownership and material obligations.
// Brine's independent arithmetic/parameter oracles remain separate controls.
#include "cybersand/world.hpp"
#include "cybersand/demo_snapshot.hpp"
#include "cybersand/prepared_world.hpp"
#include "cybersand/material_rules.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <type_traits>

namespace {
using namespace cybersand;
void require(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}
LiquidSolverPolicy policy(int damping = 1, bool brine = false) {
    auto request = LiquidSolverPolicy::default_request();
    request[21] = 4;
    if (brine) request[39] = 4;
    request[request.size()-2U] = 1;
    request.insert(request.end()-1, {4,2,1,damping});
    const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(request));
    require(decoded.accepted(), "Water IN policy refused: " + decoded.refusal.message());
    return *decoded.policy;
}
WorldConfig config(std::uint32_t workers = 1, std::uint8_t bits = 8, int damping = 1) {
    WorldConfig out;
    out.liquid_solver_policy = policy(damping);
    out.maximum_rule_radius = 3;
    out.worker_threads = workers;
    out.parallel_job_threshold = 1;
    out.water_experiment_policy = WaterExperimentPolicy(bits,12);
    return out;
}
void rect(World& world, std::int64_t x, std::int64_t y, int width, int height, Material material) {
    for (int yy=0; yy<height; ++yy) for (int xx=0; xx<width; ++xx)
        world.set(x+xx,y+yy,material);
}
void closed(const World& world, RectI64 domain) {
    std::int64_t vx=0,vy=0,speed=0;
    for (auto y=domain.y;y<domain.y+domain.height;++y) for (auto x=domain.x;x<domain.x+domain.width;++x) {
        const auto slot=world.inertial_cell(x,y);
        if (world.stored_material(x,y)==Material::Water)
            require(world.stored_state_a(x,y)==world.config().water_experiment_policy.maximum(),"Water became fractional");
        if (!world.inertial_family(world.stored_material(x,y)))
            require(!slot.vx&&!slot.vy&&!slot.ax&&!slot.ay,"IN state on a vacancy or foreign carrier");
        require(slot.ax>-16&&slot.ax<16&&slot.ay>-16&&slot.ay<16,"IN remainder outside q16");
        vx+=slot.vx;vy+=slot.vy;speed+=std::abs(slot.vx)+std::abs(slot.vy);
    }
    const auto l=world.inertial_ledger();
    require(vx==l.impulse_x+l.external_x-l.retired_x && vy==l.gravity_y+l.impulse_y+l.external_y-l.retired_y,
            "Water signed momentum does not close");
    require(speed==l.gravity_y-l.loss+l.external_speed-static_cast<std::int64_t>(l.velocity_retired),
            "Water L1 speed ledger does not close");
    require(l.maximum_read_reach<=3&&l.maximum_write_reach<=2,"complete original-owner footprint exceeded");
}
std::uint64_t events(const World& world, PhysicsEvent event) {
    std::uint64_t n=0;
    for (const auto& entry:world.physics_diagnostics()->entries)
        if ((entry.key>>24U)==static_cast<std::uint32_t>(event)) n+=entry.count;
    return n;
}
void reseal(std::vector<std::uint8_t>& bytes) {
    const auto digest=Sha256::of(std::span<const std::uint8_t>(bytes).first(bytes.size()-32U));
    std::copy(digest.begin(),digest.end(),bytes.end()-32);
}
void precision_ingress(std::uint8_t bits) {
    auto world=std::make_unique<World>(config(1,bits));
    require(world->whole_cell_water_enabled()&&!world->water_cellular_yield_enabled()&&
                world->inertial_family(Material::Water),"Water did not dispatch a distinct IN law");
    const auto maximum=world->config().water_experiment_policy.maximum();
    world->set(9,9,Material::Water);world->set_temperature(9,9,777);
    require(world->diagnostic_set_inertial_cell(9,9,-17,23,-7,9),"Water retained state seed");
    const auto before=world->save_physical_state();const auto quantity=world->quantity_ledger();
    const auto chunks=world->chunk_count();
    for (const auto mass:std::array<std::uint16_t,3>{1,static_cast<std::uint16_t>(maximum/2U),static_cast<std::uint16_t>(maximum-1U)})
        require(!world->set_cell_state(9,9,Material::Water,mass,0)&&
                    !world->set_cell_state(1000,1000,Material::Water,mass,0),"fractional live Water accepted");
    require(world->save_physical_state()==before&&world->quantity_ledger()==quantity&&world->chunk_count()==chunks,
            "fractional ingress refusal changed authority or allocated storage");
    bool invalid_coherence=false;
    try {(void)world->set_cell_state(9,9,Material::Water,maximum,13);}
    catch(const std::invalid_argument&) {invalid_coherence=true;}
    require(invalid_coherence&&world->save_physical_state()==before,"invalid coherence accepted or changed authority");
    std::vector<std::uint8_t> payload(demo::kPayloadBytes,0);
    payload[0]=static_cast<std::uint8_t>(Material::Water);payload[1]=static_cast<std::uint8_t>(maximum-1U);
    bool rejected=false;
    try {(void)demo::reconstruct(world->config(),payload);} catch(const LiquidPolicyRefused& error) {
        rejected=error.refusal().code==LiquidPolicyRefusalCode::NormalizationRequired;
    }
    require(rejected&&world->save_physical_state()==before,"CYSD helper silently omitted fractional IN Water");
    // Corrupt an actual encoded cell and reseal the digest: whole-cell admission
    // must reject independently of the checksum and retain the exposed World.
    auto corrupted=before;
    const std::array<std::uint8_t,6> marker{3,0,static_cast<std::uint8_t>(maximum),0,0,0};
    const auto at=std::search(corrupted.begin(),corrupted.end()-32,marker.begin(),marker.end());
    require(at!=corrupted.end()-32,"CYPS3 Water marker absent");at[2]=static_cast<std::uint8_t>(maximum-1U);reseal(corrupted);
    rejected=false;
    try {(void)World::restore_physical_state(world->config(),corrupted);} catch(const std::invalid_argument& error) {
        rejected=std::string(error.what()).find("whole-cell Water")!=std::string::npos;
    }
    require(rejected&&world->save_physical_state()==before,"valid-digest fractional CYPS3 Water admitted");
    require(world->set_cell_state(9,9,Material::Water,0,0)&&world->stored_material(9,9)==Material::Empty,
            "zero Water no longer erases");
    const auto slot=world->inertial_cell(9,9);require(!slot.vx&&!slot.vy&&!slot.ax&&!slot.ay,"erase retained Water motion");
}
void normalization_case(std::uint8_t bits) {
    using namespace cybersand::normalization;
    auto cfg=config(1,bits);const auto maximum=cfg.water_experiment_policy.maximum();
    FinalSetupInput input;input.mass_bits=bits;input.setup.domain={0,0,16,16};
    input.cells={{3,3,Material::Water,static_cast<std::uint16_t>(maximum/2U),12,777},
                 {4,3,Material::Water,static_cast<std::uint16_t>(maximum/2U+1U),7,888}};
    auto refusal=PreparedWorldBuilder::prepare(cfg,input,NormalizationOptIn::None);
    require(std::get_if<ConstructionRefusal>(&refusal)&&
                std::get<ConstructionRefusal>(refusal).policy_refusal()->code==LiquidPolicyRefusalCode::NormalizationRequired,
            "fractional prepared Water IN did not require explicit normalization");
    auto result=PreparedWorldBuilder::prepare(cfg,input,NormalizationOptIn::WaterNormalizeV1);
    require(std::get_if<PreparedWorld>(&result),"explicit IN normalization refused");
    auto& prepared=std::get<PreparedWorld>(result);
    const auto& receipt=*prepared.setup().normalization_receipt();const auto totals=receipt.totals();
    require(totals.cells_up==1&&totals.cells_down==1&&totals.water_before==maximum&&totals.water_after==maximum&&
                totals.positive_delta==maximum/2U&&totals.negative_delta==maximum/2U&&totals.net_delta==0,
            "IN normalization lost explicit gross source/sink ledger");
    const auto& world=prepared.world();
    require(world.stored_material(3,3)==Material::Empty&&world.stored_material(4,3)==Material::Water&&
                world.stored_state_a(4,3)==maximum&&world.stored_state_b(4,3)==7&&world.stored_temperature(4,3)==888,
            "normalization changed nonquantity state or failed threshold");
    const auto ledger=world.quantity_ledger();
    require(ledger.construction&&ledger.construction->normalization_receipt_digest==receipt.receipt_hash(),"IN setup ledger lost normalization digest");
}
struct QuantityFixtureEncoder {
    std::vector<std::uint8_t> bytes;
    template<class Integer> void put(Integer value) {
        const auto word=static_cast<std::make_unsigned_t<Integer>>(value);
        for(std::size_t i=0;i<sizeof(Integer);++i)bytes.push_back(static_cast<std::uint8_t>(word>>(8U*i)));
    }
};
// Independently spell the public ledger snapshot encoding only to locate the
// unique prepared-count field. No fixed absolute CYPS offset or blind byte
// search may accidentally mutate another metadata field instead.
std::pair<std::vector<std::uint8_t>,std::size_t> encoded_quantity(const QuantityLedgerSnapshot& v) {
    QuantityFixtureEncoder e;e.put(v.schema_version);e.put(v.mass_bits);e.put(v.baseline_water);
    e.put(v.water_visible);e.put(v.water_overfill);
    const auto flows=[&](const auto& rows){for(const auto& f:rows){e.put(f.produced);e.put(f.consumed);}};
    flows(v.kinds);flows(v.pair_rules);for(auto n:v.pair_events)e.put(n);flows(v.kernel_rules);
    for(auto n:v.material_cells)e.put(n);
    const auto prepared_offset=e.bytes.size();for(auto n:v.prepared_material_cells)e.put(n);
    e.put(static_cast<std::uint8_t>(v.construction.has_value()));
    require(v.construction.has_value(),"forged prepared-population fixture needs actual construction binding");
    const auto& seed=*v.construction;e.put(seed.mass_bits);e.put(seed.baseline_water);e.put(seed.normalization_produced);
    e.put(seed.normalization_consumed);e.put(seed.expected_final_water);
    for(const auto* digest:{&seed.original_setup_identity,&seed.prepared_setup_identity,&seed.original_payload_digest,&seed.prepared_payload_digest})
        for(auto b:*digest)e.put(b);
    e.put(static_cast<std::uint8_t>(seed.normalization_receipt_digest.has_value()));
    if(seed.normalization_receipt_digest)for(auto b:*seed.normalization_receipt_digest)e.put(b);
    return {std::move(e.bytes),prepared_offset};
}
void prepared_restore_population(std::uint8_t bits) {
    for(int family:{2,4}) {
        auto cfg=config(1,bits);auto request=LiquidSolverPolicy::default_request();request[21]=family;
        const auto decoded=LiquidSolverPolicy::decode(std::span<const std::int32_t>(request));
        require(decoded.accepted(),"prepared-population family admission");cfg.liquid_solver_policy=*decoded.policy;
        normalization::FinalSetupInput input;input.mass_bits=bits;input.setup.domain={0,0,16,16};
        input.cells={{3,3,Material::Water,cfg.water_experiment_policy.maximum(),0,300}};
        auto result=PreparedWorldBuilder::prepare(cfg,input,normalization::NormalizationOptIn::None);
        require(std::get_if<PreparedWorld>(&result),"already-full unnormalized prepared fixture refused");
        const auto& world=std::get<PreparedWorld>(result).world();const auto original=world.save_physical_state();
        const auto valid_restore=World::restore_physical_state(cfg,original);
        require(valid_restore->save_physical_state()==original,"valid prepared-population capture does not round trip");
        const auto ledger=world.quantity_ledger();require(ledger.prepared_material_cells[3]==1&&
            !ledger.construction->normalization_receipt_digest,"control must exercise unnormalized full Water setup");
        auto bytes=original;const auto [encoded,relative]=encoded_quantity(ledger);
        const auto at=std::search(bytes.begin(),bytes.end()-32,encoded.begin(),encoded.end());
        require(at!=bytes.end()-32&&std::search(at+1,bytes.end()-32,encoded.begin(),encoded.end())==bytes.end()-32,
                "prepared-population ledger encoding not unique in actual capture");
        const auto offset=static_cast<std::size_t>(at-bytes.begin())+relative+8U*static_cast<unsigned>(Material::Water);
        require(bytes[offset]==1,"prepared-population counterexample field not selected");bytes[offset]=2;reseal(bytes);
        bool refused=false;std::string detail;try{(void)World::restore_physical_state(cfg,bytes);}
        catch(const std::invalid_argument& error){detail=error.what();refused=detail.find("invalid quantity ledger")!=std::string::npos;}
        require(refused&&world.save_physical_state()==original,
                "valid-digest forged prepared Water population admitted for family"+std::to_string(family)+" mass"+std::to_string(bits)+" detail="+detail);
    }
}
void coherence_case(std::uint8_t delay, int vx) {
    auto cfg=config(1,8,0);cfg.sleep_after_quiet_ticks=1;cfg.physics_diagnostics.enabled=true;
    auto world=std::make_unique<World>(cfg);world->reserve_temperature_region({0,0,64,64});
    rect(*world,0,11,64,1,Material::Wall);
    require(world->set_cell_state(20,10,Material::Water,255,delay),"coherence fixture");
    require(world->diagnostic_set_inertial_cell(20,10,static_cast<std::int16_t>(vx),0,7,0),"coherence retained impulse");
    (void)world->tick();
    const auto destination=delay?20:20+(7+vx)/16;
    require(world->stored_material(destination,10)==Material::Water&&world->stored_state_b(destination,10)==(delay?delay-1:0),
            "original coherence did not gate only lateral travel");
    const auto slot=world->inertial_cell(destination,10);
    require(slot.vx==vx&&slot.vy==0&&slot.ax==(7+vx)%16&&slot.ay==0,
            "suppressed opportunity changed retained velocity or bounded phase");
    require(events(*world,PhysicsEvent::WaterUpdate)==1,"mandatory WaterUpdate omitted");
    if (delay) {
        for (int i=1;i<=delay;++i) (void)world->tick();
        require(world->stored_material(20,10)!=Material::Water,"coherence expiration failed to retain future IN work");
    }
    closed(*world,{0,0,64,64});
}
void body_contacts() {
    for (const auto workers:{1U,4U}) for (const auto normal:std::array<std::pair<int,int>,3>{{{0,1},{-1,1},{1,1}}}) {
        auto cfg=config(workers,8,16);cfg.chunk_size=cfg.activity_block_size=cfg.scheduling_core_size=8;
        auto world=std::make_unique<World>(cfg);world->reserve_region({0,0,40,40});
        world->configure_transient_obstacles({0,0,40,40});
        for (const auto [x,y]:std::array<std::pair<int,int>,4>{{{11,11},{27,11},{11,27},{27,27}}}) {
            rect(*world,x-2,y-2,5,5,Material::Wall);world->set(x,y,Material::Water);
            world->set(x+normal.first,y+normal.second,Material::Empty);
        }
        const auto density=MaterialRules::descriptor(Material::Water).density;
        for (int t=0;t<16;++t) {
            world->clear_transient_obstacles();std::uint16_t body=0;
            for (const auto [x,y]:std::array<std::pair<int,int>,4>{{{11,11},{27,11},{11,27},{27,27}}})
                require(world->set_transient_obstacle(x+normal.first,y+normal.second,++body),"Water rest mask");
            const auto stats=world->tick();require(stats.visited_cells>=4&&!world->has_failed(),"rest probes not executed");
            for (body=1;body<=4;++body)
                require(world->transient_contact_count(body)==1&&
                            world->transient_contact_impulse_x(body)==normal.first*density&&
                            world->transient_contact_impulse_y(body)==normal.second*density,
                        "zero-travel Water lost mandatory signed body feedback or duplicate-booked it");
        }
        closed(*world,{0,0,40,40});
    }
}
void carrying(bool enabled, std::uint32_t workers, std::uint8_t bits, int x, int y, bool no_motion=false) {
    auto cfg=config(workers,bits,0);cfg.physics_diagnostics.enabled=true;cfg.transport_policy.configured=true;
    cfg.chunk_size=cfg.activity_block_size=cfg.scheduling_core_size=8;
    auto& p=cfg.transport_policy.pairs[3U*TransportPolicy::materials+2U];
    p.carrying=enabled?255:0;p.pickup=p.packing=0;p.erosion=1;
    auto world=std::make_unique<World>(cfg);world->reserve_temperature_region({x-16,y-16,64,64});
    rect(*world,x-2,y+3,5,1,Material::Wall);
    world->set(x-1,y+2,Material::Wall);world->set(x+1,y+2,Material::Wall);
    for (int dy=1;dy<=2;++dy) {
        require(world->set_cell_state(x,y+dy,Material::Sand,static_cast<std::uint8_t>(16+dy),static_cast<std::uint8_t>(22+dy)),"grain tuple");
        world->set_temperature(x,y+dy,static_cast<std::int16_t>(666+111*dy));
    }
    world->set(x,y,Material::Water);world->set_temperature(x,y,333);
    require(world->diagnostic_set_inertial_cell(x,y,no_motion?0:32,no_motion?0:32,no_motion?0:15,no_motion?0:-15),"carrier state");
    const auto quantity=world->water_quantity({x-16,y-16,64,64});
    const auto stats=world->tick();
    require(!world->has_failed()&&stats.chunk_allocations==0&&stats.temperature_field_allocations==0,"prepared carrying allocated or failed");
    const auto transported=events(*world,PhysicsEvent::GrainTransport);
    if (!enabled||no_motion) require(transported==0,"carrying-off/zero-real-motion control picked up grain");
    if (enabled&&!no_motion&&transported==2) {
        require(world->stored_material(x,y+2)==Material::Water&&world->stored_temperature(x,y+2)==333,
                "two pickups lost actual Water carrier/temperature");
        const auto slot=world->inertial_cell(x,y+2);
        require(slot.vx==30&&slot.vy==30&&slot.ax==13&&slot.ay==15,"motion state stored on nominal grain destination");
        for (int dy=0;dy<2;++dy)
            require(world->stored_material(x+1,y+dy)==Material::Sand&&world->stored_state_a(x+1,y+dy)==17+dy&&
                        world->stored_state_b(x+1,y+dy)==23+dy&&world->stored_temperature(x+1,y+dy)==777+111*dy,
                    "carried grain lost compact tuple or temperature");
        require(world->inertial_ledger().maximum_read_reach==3&&world->inertial_ledger().maximum_write_reach==2,
                "second carrying packing census did not witness actual complete read3/write2");
    }
    require(world->water_quantity({x-16,y-16,64,64})==quantity,"carrying changed exact maximum Water quantity");
    closed(*world,{x-16,y-16,64,64});
    std::cout<<"Water IN carry x="<<x<<" y="<<y<<" bits="<<unsigned(bits)<<" workers="<<workers<<" enabled="<<enabled
             <<" no_motion="<<no_motion<<" pickups="<<transported<<'\n';
    // The preregistered lane coordinates below require two actual pickups.
    if (enabled&&!no_motion) require(transported==2,"registered two-carry lane did not execute both hooks");
}
void oblique_contact(std::uint32_t workers) {
    auto cfg=config(workers);cfg.chunk_size=cfg.activity_block_size=cfg.scheduling_core_size=8;
    auto world=std::make_unique<World>(cfg);world->reserve_region({0,0,40,40});
    world->configure_transient_obstacles({0,0,40,40});
    rect(*world,9,9,7,7,Material::Wall);world->set(11,11,Material::Water);
    world->set(12,12,Material::Empty);world->set(11,12,Material::Empty);
    require(world->set_transient_obstacle(11,12,1)&&world->diagnostic_set_inertial_cell(11,11,32,32,15,15),"oblique Water contact fixture");
    (void)world->tick();const auto density=MaterialRules::descriptor(Material::Water).density;
    require(world->stored_material(12,12)==Material::Water&&world->transient_contact_count(1)==2&&
                world->transient_contact_impulse_x(1)==-density&&world->transient_contact_impulse_y(1)==density,
            "after-travel Water different normal was discarded or repeated normal double-booked");
    const auto slot=world->inertial_cell(12,12);
    require(slot.vx==29&&slot.vy==0&&slot.ax==12&&slot.ay==0,"contact bookkeeping retuned Water IN numerical law");
    closed(*world,{0,0,40,40});
}
void compare_material_cells(const World& a,const World& b) {
    for(int y=7;y<10;++y) for(int x=7;x<11;++x)
        require(a.stored_material(x,y)==b.stored_material(x,y)&&a.stored_state_a(x,y)==b.stored_state_a(x,y)&&
                    a.stored_state_b(x,y)==b.stored_state_b(x,y)&&a.stored_temperature(x,y)==b.stored_temperature(x,y),
                "shared material stages changed under Water IN");
}
void enclose_pair(World& w,Material a,Material b) {rect(w,7,7,4,3,Material::Wall);w.set(8,8,a);w.set(9,8,b);}
void material_hooks(std::uint32_t workers) {
    struct Pair {Material a,b,after_a,after_b;int horizon;};
    for(const auto item:std::array<Pair,3>{{
        {Material::Water,Material::Salt,Material::Brine,Material::Brine,1024},
        {Material::Lava,Material::Water,Material::Stone,Material::Steam,1024},
        {Material::Fire,Material::Water,Material::Smoke,Material::Steam,8}}}) {
        auto cfg=config(workers);auto current_cfg=cfg;current_cfg.liquid_solver_policy=LiquidSolverPolicy{};
        auto candidate=std::make_unique<World>(cfg),current=std::make_unique<World>(current_cfg);
        enclose_pair(*candidate,item.a,item.b);enclose_pair(*current,item.a,item.b);
        bool completed=false;
        for(int t=0;t<item.horizon;++t) {
            (void)candidate->tick();(void)current->tick();compare_material_cells(*candidate,*current);
            if(candidate->stored_material(8,8)==item.after_a&&candidate->stored_material(9,8)==item.after_b) {completed=true;break;}
        }
        require(completed,"Water IN shared pair never executed");closed(*candidate,{0,0,128,128});
    }
    auto cfg=config(workers,3);auto current_cfg=cfg;current_cfg.liquid_solver_policy=LiquidSolverPolicy{};
    auto candidate=std::make_unique<World>(cfg),current=std::make_unique<World>(current_cfg);
    for(auto* w:{candidate.get(),current.get()}) {
        enclose_pair(*w,Material::Oil,Material::Water);
        require(w->set_cell_state(8,8,Material::Oil,0,120),"burning Oil fixture");
    }
    for(int t=0;t<16;++t) {(void)candidate->tick();(void)current->tick();compare_material_cells(*candidate,*current);}
    require(candidate->stored_state_b(8,8)==0,"Water IN identity did not extinguish Oil");
    for(auto* w:{candidate.get(),current.get()}) {w->clear();enclose_pair(*w,Material::Cement,Material::Water);}
    for(int t=0;t<400;++t) {(void)candidate->tick();(void)current->tick();}
    compare_material_cells(*candidate,*current);require(candidate->stored_material(8,8)==Material::Concrete,"Water IN Cement did not cure");
    for(auto* w:{candidate.get(),current.get()}) {
        w->clear();enclose_pair(*w,Material::Steam,Material::Wall);
        require(w->set_cell_state(8,8,Material::Steam,1,0),"Steam product fixture");
    }
    for(int t=0;t<16&&candidate->stored_material(8,8)!=Material::Water;++t) {
        (void)candidate->tick();(void)current->tick();compare_material_cells(*candidate,*current);
    }
    const auto product=candidate->inertial_cell(8,8);
    require(candidate->stored_material(8,8)==Material::Water&&candidate->stored_state_a(8,8)==7&&
                !product.vx&&!product.vy&&!product.ax&&!product.ay,"new full Water product retained old family motion");
    require(candidate->diagnostic_set_inertial_cell(8,8,17,23,7,-9),"paint seed");
    const auto prior=candidate->inertial_ledger().velocity_retired;
    candidate->set(8,8,Material::Water);
    const auto painted=candidate->inertial_cell(8,8);
    require(!painted.vx&&!painted.vy&&!painted.ax&&!painted.ay&&candidate->inertial_ledger().velocity_retired==prior+40,
            "same-visible Water paint failed family retirement");
    std::vector<Material> generated(128U*128U,Material::Empty);generated[5]=Material::Water;
    require(candidate->install_generated_chunk({2,0},generated)==ChunkInstallOutcome::Installed,"generated Water ingress failed");
    const auto generated_slot=candidate->inertial_cell(261,0);
    require(candidate->stored_state_a(261,0)==7&&!generated_slot.vx&&!generated_slot.vy&&!generated_slot.ax&&!generated_slot.ay,
            "generated Water did not use whole quantity/default sidecar");
    candidate->clear();require(candidate->inertial_ledger()==InertialLedger{}&&candidate->inertial_storage_usage().slot_bytes==0,
            "clear retained Water motion storage or ledger");
}
void parity(std::uint8_t bits) {
    auto a=config(1,bits),b=config(4,bits);a.liquid_solver_policy=b.liquid_solver_policy=policy(1,true);
    a.chunk_size=b.chunk_size=32;a.activity_block_size=b.activity_block_size=8;
    a.scheduling_core_size=b.scheduling_core_size=8;
    auto one=std::make_unique<World>(a),four=std::make_unique<World>(b);
    for (auto* w:{one.get(),four.get()}) {
        w->reserve_temperature_region({-64,-64,192,192});
        rect(*w,-32,90,144,1,Material::Wall);rect(*w,-32,-16,1,106,Material::Wall);rect(*w,111,-16,1,106,Material::Wall);
        rect(*w,-20,-8,80,12,Material::Water);rect(*w,65,20,10,10,Material::Oil);rect(*w,80,20,10,10,Material::Brine);
        for (int x=-20;x<60;++x) (void)w->set_cell_state(x,-8,Material::Water,w->config().water_experiment_policy.maximum(),12);
    }
    const auto quantity=one->water_quantity({-64,-64,192,192});std::uint64_t participants=0;
    for(int t=0;t<48;++t) {
        const auto sa=one->tick(),sb=four->tick();participants=std::max(participants,static_cast<std::uint64_t>(sb.worker_threads_observed));
        require(sa.chunk_allocations+sb.chunk_allocations+sa.temperature_field_allocations+sb.temperature_field_allocations==0,
                "Water-IN prepared real-worker tick allocated");
        require(one->physical_state_hash()==four->physical_state_hash()&&one->inertial_ledger()==four->inertial_ledger(),
                "Water/Brine IN with Oil CY diverged between actual worker counts");
        require(one->water_quantity({-64,-64,192,192})==quantity&&four->water_quantity({-64,-64,192,192})==quantity,
                "mixed-family whole Water quantity drift");
    }
    require(participants>1,"configured-four Water fixture did not execute multiple worker participants");
    auto restored=World::restore_physical_state(b,one->save_physical_state());
    require(restored->save_physical_state()==one->save_physical_state(),"Water IN CYPS3 restore changed canonical state");
    for(int t=0;t<16;++t) {(void)one->tick();(void)restored->tick();require(one->physical_state_hash()==restored->physical_state_hash(),"Water IN continuation diverged");}
    closed(*one,{-64,-64,192,192});
}
void cadence_case(std::uint32_t workers) {
    auto cfg=config(workers,8,0);cfg.sleep_after_quiet_ticks=1;
    cfg.transport_policy.configured=true;cfg.transport_policy.cadence[3]=60;
    auto world=std::make_unique<World>(cfg);world->reserve_region({0,0,128,128});rect(*world,0,61,128,1,Material::Wall);
    world->set(40,60,Material::Water);require(world->diagnostic_set_inertial_cell(40,60,32,0,7,0),"cadence retained seed");
    bool waited=false,moved=false;int previous=40;
    for(int t=0;t<70;++t) {
        (void)world->tick();int current=-1;
        for(int x=0;x<128;++x) if(world->stored_material(x,60)==Material::Water) current=x;
        require(current>=previous&&current<=previous+2,"cadence accumulated catch-up travel or lost Water");
        const auto slot=world->inertial_cell(current,60);require(slot.vx==32&&slot.vy==0&&slot.ax==7,"cadence discarded retained momentum/phase");
        waited|=current==previous;moved|=current>previous;previous=current;
    }
    require(waited&&moved,"cadence did not preserve both refusal and future eligibility");closed(*world,{0,0,128,128});
}
void powder_control(int backend,bool telemetry,bool disabled) {
    auto cfg=config(backend==2?4:1);if(backend==0)cfg.backend=SimulationBackend::SerialInPlace;
    cfg.physics_diagnostics.enabled=telemetry;cfg.physics_diagnostics.disable_powder_exchange_targets=disabled;
    auto world=std::make_unique<World>(cfg);world->reserve_region({0,0,64,64});rect(*world,20,20,7,6,Material::Wall);
    world->set(23,21,Material::Water);world->set(23,22,Material::Empty);world->set(23,23,Material::Dust);
    require(world->diagnostic_set_inertial_cell(23,21,0,32,0,15),"powder causal seed");
    (void)world->tick();const auto ledger=world->inertial_ledger();
    require(world->stored_material(23,disabled?22:23)==Material::Water&&ledger.unit_moves==(disabled?1U:2U)&&
                ledger.density_swaps==(disabled?0U:1U),"Water U6 failed to recheck powder denial after Empty move");
    if(disabled)require(world->stored_material(23,23)==Material::Dust&&world->inertial_cell(23,22).vy==0,
                       "denied powder was displaced despite causal control");
    closed(*world,{0,0,64,64});
}
void storage_case(int size) {
    auto cfg=config();auto both_cfg=cfg;both_cfg.liquid_solver_policy=policy(1,true);
    auto water=std::make_unique<World>(cfg),both=std::make_unique<World>(both_cfg);
    for(auto* w:{water.get(),both.get()})w->reserve_region({0,0,size,size});
    const auto before=water->inertial_storage_usage(),other=both->inertial_storage_usage();
    const auto cells=static_cast<std::size_t>(size)*static_cast<std::size_t>(size);
    require(before.slot_size==6&&before.slot_alignment==2&&before.slot_capacity==cells&&before.slot_bytes==6U*cells&&
                before.nonzero_slots==0&&other.slot_bytes==before.slot_bytes&&other.total_component_bytes==before.total_component_bytes,
            "Water/Brine IN allocated per-material state or changed C64-E8 sidecar layout");
    water->set(5,5,Material::Water);require(water->diagnostic_set_inertial_cell(5,5,17,23,7,-9),"storage sparse state");
    const auto sparse=water->inertial_storage_usage();
    require(sparse.nonzero_slots==1&&sparse.slot_bytes==before.slot_bytes&&sparse.total_component_bytes==before.total_component_bytes,
            "sparse nonzero Water silently changed dense optional storage accounting");
    std::cout<<"Water IN storage side="<<size<<" slot="<<sparse.slot_size<<" alignment="<<sparse.slot_alignment
             <<" slot_capacity="<<sparse.slot_capacity<<" array_bytes="<<sparse.slot_bytes<<" owner_bytes="<<sparse.owner_bytes
             <<" job_ledger_bytes="<<sparse.job_ledger_bytes<<" world_members="<<sparse.world_state_bytes
             <<" total_components="<<sparse.total_component_bytes<<" simultaneous_world_components="
             <<sparse.total_component_bytes+other.total_component_bytes<<" legacy_resident_bytes="<<water->resident_cell_bytes()<<'\n';
}
void pause_and_capacity() {
    auto cfg=config();auto world=std::make_unique<World>(cfg);world->reserve_region({0,0,128,128});world->set(9,9,Material::Water);
    require(world->diagnostic_set_inertial_cell(9,9,17,23,7,-9),"pause retained state");
    const auto saved=world->inertial_cell(9,9);const auto ledger=world->inertial_ledger();
    world->set_simulation_region(RectI64{768,768,64,64});
    for(int t=0;t<40;++t)(void)world->tick();
    const auto paused=world->inertial_cell(9,9);
    require(world->stored_material(9,9)==Material::Water&&paused.vx==saved.vx&&paused.vy==saved.vy&&paused.ax==saved.ax&&
                paused.ay==saved.ay&&world->inertial_ledger()==ledger,"excluded Water accumulated motion or discarded retained state");
    world->set_simulation_region(std::nullopt);(void)world->tick();
    require(world->inertial_ledger().updates==ledger.updates+1&&world->inertial_ledger().unit_moves-ledger.unit_moves<=2,
            "Water re-entry replayed missed work or failed to resume");closed(*world,{0,0,128,128});
    auto limit=config();limit.backend=SimulationBackend::SerialInPlace;limit.chunk_size=8;
    limit.initial_chunk_reserve=limit.maximum_chunk_count=1;auto failed=std::make_unique<World>(limit);
    failed->set(4,7,Material::Water);require(failed->diagnostic_set_inertial_cell(4,7,0,32,0,15),"capacity moving seed");
    bool refused=false;try{(void)failed->tick();}catch(const std::runtime_error&){refused=true;}
    require(refused&&failed->has_failed()&&failed->completed_tick_index()==0&&failed->chunk_count()==1&&
                failed->stored_material(4,7)==Material::Water&&failed->stored_state_a(4,7)==255,
            "IN allocation capacity silently fell back or exposed a completed tick");
    require(!failed->set_cell_state(4,7,Material::Water,255,0),"quarantined Water accepted a live edit");
}

void same_diagnostics(const World& one, const World& four) {
    const auto* a=one.physics_diagnostics();const auto* b=four.physics_diagnostics();
    require(a&&b&&a->overflow==0&&b->overflow==0,"activity diagnostics overflowed");
    require(a->used==b->used,"activity diagnostics lost a worker event");
    for(const auto& entry:a->entries) {
        if(entry.key==0)continue;
        const auto found=std::find_if(b->entries.begin(),b->entries.end(),
            [&](const auto& other){return other.key==entry.key;});
        require(found!=b->entries.end()&&found->count==entry.count,
                "worker activity transition was lost or counted twice");
    }
}

void dense_activity(bool discovery) {
    auto a=config(),b=config(4);
    for(auto* cfg:{&a,&b}) {
        cfg->chunk_size=64;cfg->scheduling_core_size=16;cfg->activity_block_size=1;
        // gather_active_cores reserves one entry per awake block before its
        // existing deduplication: four256-cell chambers plus their wall seams.
        cfg->active_core_capacity=4096;cfg->sleep_after_quiet_ticks=1;
        cfg->physics_diagnostics.enabled=true;cfg->settled_discovery_enabled=discovery;
    }
    auto one=std::make_unique<World>(a),four=std::make_unique<World>(b);
    for(auto* world:{one.get(),four.get()}) {
        world->reserve_region({-64,-64,256,192});
        for(int origin:{0,32,64,96}) {
            rect(*world,origin-1,-1,18,18,Material::Wall);
            for(int y=0;y<16;++y)for(int x=origin;x<origin+16;++x)
                require(world->set_cell_state(x,y,Material::Water,255,12),"dense activity seed");
        }
    }
    const auto quantity=one->water_quantity({-64,-64,256,192});
    std::uint32_t participants=0;
    for(int tick=1;tick<=20;++tick) {
        const auto sa=one->tick(),sb=four->tick();
        participants=std::max(participants,sb.worker_threads_observed);
        require(sa.chunk_allocations+sb.chunk_allocations+
                    sa.temperature_field_allocations+sb.temperature_field_allocations==0,
                "dense authoritative activity allocated during a tick");
        require(one->state_hash()==four->state_hash()&&
                    one->physical_state_hash()==four->physical_state_hash()&&
                    (discovery||one->save_physical_state()==four->save_physical_state()),
                "dense activity/deadline metadata diverged across real workers");
        same_diagnostics(*one,*four);
        require(!one->has_failed()&&!four->has_failed()&&
                    four->water_quantity({-64,-64,256,192})==quantity,
                "optional discovery loss suppressed authoritative scheduling");
        for(int origin:{0,32,64,96})for(int y=0;y<16;++y)for(int x=origin;x<origin+16;++x)
            require(four->stored_state_b(x,y)==std::max(12-tick,0),
                    "more than64 activity targets lost future Water work");
    }
    require(participants>1,"dense activity did not execute genuine workers");
    if(discovery)
        require(four->settled_discovery_halted()!=soliding::DiscoveryHalt::None,
                "dense fixture did not exercise optional observer report overflow");
    closed(*four,{-64,-64,256,192});
}

void shared_activity_halo() {
    auto a=config(1,8,0),b=config(4,8,0);
    for(auto* cfg:{&a,&b}) {
        cfg->chunk_size=64;cfg->scheduling_core_size=16;cfg->activity_block_size=16;
        cfg->active_core_capacity=128;cfg->sleep_after_quiet_ticks=1;
        cfg->physics_diagnostics.enabled=true;
    }
    auto one=std::make_unique<World>(a),four=std::make_unique<World>(b);
    for(auto* world:{one.get(),four.get()}) {
        world->reserve_region({-128,-64,384,192});
        for(int origin:{-64,0,64,128}) {
            rect(*world,origin,8,48,1,Material::Wall);
            world->set(origin+15,7,Material::Water);world->set(origin+32,7,Material::Water);
            require(world->diagnostic_set_inertial_cell(origin+15,7,32,0,0,0)&&
                        world->diagnostic_set_inertial_cell(origin+32,7,-32,0,0,0),"shared block seed");
        }
    }
    std::uint32_t participants=0;
    for(int tick=0;tick<8;++tick) {
        (void)one->tick();const auto stats=four->tick();
        participants=std::max(participants,stats.worker_threads_observed);
        require(one->state_hash()==four->state_hash()&&
                    one->inertial_ledger()==four->inertial_ledger(),"shared halo block changed worker outcome");
        same_diagnostics(*one,*four);
        if(tick==0)for(int origin:{-64,0,64,128})
            require(four->stored_material(origin+17,7)==Material::Water&&
                        four->stored_material(origin+30,7)==Material::Water,
                    "same-phase carriers did not reach the shared middle activity block");
    }
    require(participants>1,"shared activity block did not execute genuine workers");
    closed(*four,{-128,-64,384,192});
}

void unaligned_and_serial_activity() {
    for(const auto [chunk,block]:std::array<std::pair<int,int>,2>{{{10,3},{34,33}}})
    for(bool serial:{false,true}) {
        auto cfg=config();cfg.chunk_size=chunk;cfg.scheduling_core_size=8;cfg.activity_block_size=block;
        // Coarse unaligned blocks wake every intersecting small core, including
        // the partial tail blocks of the preallocated negative chunk seams.
        cfg.active_core_capacity=512;cfg.sleep_after_quiet_ticks=1;
        if(serial)cfg.backend=SimulationBackend::SerialInPlace;
        auto world=std::make_unique<World>(cfg);world->reserve_region({-40,-40,80,80});
        rect(*world,-12,-12,20,20,Material::Wall);
        for(int y=-11;y<7;++y)for(int x=-11;x<7;++x)
            require(world->set_cell_state(x,y,Material::Water,255,12),"unaligned activity seed");
        for(int tick=1;tick<=16;++tick) {
            (void)world->tick();
            require(world->stored_state_b(-1,-1)==std::max(12-tick,0),
                    "unaligned negative chunk seam or serial activity lost future work");
        }
        auto restored=World::restore_physical_state(cfg,world->save_physical_state());
        for(int tick=0;tick<3;++tick) {
            (void)world->tick();(void)restored->tick();
            require(world->save_physical_state()==restored->save_physical_state(),"unaligned activity continuation changed");
        }
    }
}

void current_deadline_activity() {
    WorldConfig a;a.chunk_size=64;a.scheduling_core_size=16;a.activity_block_size=16;
    a.active_core_capacity=128;a.sleep_after_quiet_ticks=1;a.parallel_job_threshold=1;
    a.physics_diagnostics.enabled=true;auto b=a;b.worker_threads=4;
    auto awake_config=a;awake_config.backend=SimulationBackend::SerialInPlace;
    awake_config.sleep_after_quiet_ticks=1024;
    auto one=std::make_unique<World>(a),four=std::make_unique<World>(b);
    auto awake=std::make_unique<World>(awake_config);
    for(auto* world:{one.get(),four.get(),awake.get()}) {
        world->reserve_region({-64,-64,256,192});
        for(int origin:{0,32,64,96})for(int row:{0,8}) {
            rect(*world,origin+3,row+3,4,3,Material::Wall);
            world->set(origin+4,row+4,Material::Ice);world->set(origin+5,row+4,Material::Water);
        }
    }
    std::uint32_t participants=0;
    bool slept=false,reacted=false;
    for(int tick=0;tick<128;++tick) {
        (void)one->tick();const auto stats=four->tick();(void)awake->tick();
        participants=std::max(participants,stats.worker_threads_observed);
        slept|=stats.scheduled_cores==0;
        require(one->state_hash()==four->state_hash()&&
                    one->save_physical_state()==four->save_physical_state(),
                "Current earliest block deadlines diverged across workers");
        same_diagnostics(*one,*four);
        for(int origin:{0,32,64,96})for(int row:{0,8}) {
            const auto actual=four->stored_material(origin+5,row+4);
            require(actual==awake->stored_material(origin+5,row+4),
                    "Current pending contact missed its awake serial reference opportunity");
            reacted|=actual==Material::Ice;
        }
    }
    require(participants>1&&slept&&reacted,
            "Current deadline fixture missed real workers, quiet sleep or a future reaction");
}
} // namespace

void test_water_inertial_admission() {
    auto current=std::make_unique<World>();
    require(!current->whole_cell_water_enabled()&&!current->inertial_enabled()&&current->physical_state_hash_version()==2,
            "protected Current defaults changed");
    for(std::uint8_t bits=3;bits<=8;++bits) {precision_ingress(bits);normalization_case(bits);prepared_restore_population(bits);}
}
void test_water_inertial_coherence_contact() {
    for(std::uint8_t delay=0;delay<=12;++delay) for(int vx:{-32,32}) coherence_case(delay,vx);
    body_contacts();
    for(const auto workers:{1U,4U}) oblique_contact(workers);
}
void test_water_inertial_carrying() {
    // Coordinates supplied by the exact shared hash's tick-one four-lane
    // selection, not by retrying a failed physical fixture.
    for(const auto workers:{1U,4U}) for(const auto bits:std::array<std::uint8_t,2>{3,8}) {
        for(const auto [x,y]:std::array<std::pair<int,int>,2>{{{55,40},{10,-24}}}) {
            carrying(true,workers,bits,x,y);
            carrying(false,workers,bits,x,y);
            carrying(true,workers,bits,x,y,true);
        }
    }
}
void test_water_inertial_workers_continuation() {for(std::uint8_t bits=3;bits<=8;++bits) parity(bits);}
void test_water_inertial_material_hooks() {for(const auto workers:{1U,4U}) material_hooks(workers);}
void test_water_inertial_cadence_exchange() {
    for(const auto workers:{1U,4U}) cadence_case(workers);
    for(int backend:{0,1,2}) for(bool telemetry:{false,true}) for(bool disabled:{false,true}) powder_control(backend,telemetry,disabled);
}
void test_water_inertial_storage_pause_capacity() {for(int size:{128,1024,2048})storage_case(size);pause_and_capacity();}
void test_worker_activity_publication() {
    dense_activity(false);std::cout<<"activity:256 targets/job without discovery passed\n";
    dense_activity(true);std::cout<<"activity:optional discovery overflow independent passed\n";
    shared_activity_halo();std::cout<<"activity:same-phase shared middle block passed\n";
    unaligned_and_serial_activity();std::cout<<"activity:unaligned negative seams and serial passed\n";
    current_deadline_activity();std::cout<<"activity:Current deadlines and diagnostics passed\n";
}
