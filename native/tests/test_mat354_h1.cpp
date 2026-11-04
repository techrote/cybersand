// MAT354-B successor apparatus. The angle include is intentional: the builder
// selects the authenticated baseline/successor native/tests directory, so the
// identical apparatus can compile against either untouched production source.
// Reuse Phase A's actual World, const PrecisionProbe and independent census.
#define main mat354_historical_probe_main
#include <material_liveness_probe.cpp>
#undef main

#include <ctime>
#include <filesystem>
#include <fstream>

namespace mat354_h1 {
using namespace mat354;
constexpr unsigned horizon = 1024;

struct Observation {
    TickStats stats{};
    Census cells{};
    std::uint64_t physical = 0, kernel_entries = 0;
};

unsigned phase(Point p, std::uint32_t stream = 192U, unsigned period = 4U) {
    return static_cast<unsigned>(mix_reference(spatial_reference(p.first,p.second,stream)) % period);
}

Observation step(World& world, const Fixture& fixture, const std::string& name,
                 const std::string& replica, Point p, bool emit = true) {
    const auto before = PrecisionProbe::block(world,p.first,p.second);
    const auto material_before = world.stored_material(p.first,p.second);
    const auto state_before = world.stored_state_a(p.first,p.second);
    const auto old_events = events(world,Material::MoltenGlass);
    const bool heat_before = hot(world,p);
    Observation result;
    result.stats = world.tick();
    require(!world.has_failed() && world.completed_tick_index() == world.tick_index(),
            name+": incomplete/quarantined World");
    result.cells = census(world,fixture);
    result.physical = world.physical_state_hash();
    const auto now_events = events(world,Material::MoltenGlass);
    result.kernel_entries = now_events.down-old_events.down +
                            now_events.glass_conversions-old_events.glass_conversions;
    const auto after = PrecisionProbe::block(world,p.first,p.second);
    if (emit) {
        std::cout << "{\"type\":\"h1_tick\",\"case\":" << quoted(name)
                  << ",\"replica\":" << quoted(replica) << ",\"tick\":" << world.tick_index()
                  << ",\"x\":" << p.first << ",\"y\":" << p.second
                  << ",\"material_before\":" << static_cast<unsigned>(material_before)
                  << ",\"state_a_before\":" << state_before
                  << ",\"material\":" << static_cast<unsigned>(world.stored_material(p.first,p.second))
                  << ",\"state_a\":" << world.stored_state_a(p.first,p.second)
                  << ",\"hot_before\":" << (heat_before?"true":"false")
                  << ",\"thermal_phase\":" << phase(p)
                  << ",\"lane_eligible\":" << (world.tick_index()%4U==phase(p)?"true":"false")
                  << ",\"kernel_entries_world\":" << result.kernel_entries
                  << ",\"molten_moves_world\":" << now_events.moves-old_events.moves
                  << ",\"glass_conversions\":" << now_events.glass_conversions-old_events.glass_conversions
                  << ",\"block_before\":";
        print_block(before); std::cout << ",\"block_after\":"; print_block(after);
        std::cout << ",\"scheduled_jobs\":" << result.stats.scheduled_cores
                  << ",\"visited_cells\":" << result.stats.visited_cells
                  << ",\"worker_threads_observed\":" << result.stats.worker_threads_observed
                  << ",\"active_blocks\":" << result.stats.active_blocks_after
                  << ",\"chunk_allocations\":" << result.stats.chunk_allocations
                  << ",\"temperature_allocations\":" << result.stats.temperature_field_allocations
                  << ",\"resident_cell_bytes\":" << world.resident_cell_bytes()
                  << ",\"tuple_hash\":" << quoted(hex(result.cells.hash))
                  << ",\"physical_hash\":" << quoted(hex(result.physical)) << "}\n";
    }
    return result;
}

void passed(const std::string& name) {
    std::cout << "{\"type\":\"h1_case\",\"case\":" << quoted(name) << ",\"status\":\"PASS\"}\n";
}

Args arguments(std::string fixture, unsigned workers = 1, unsigned quiet = 3, Point p = {11,8}) {
    Args a; a.fixture=std::move(fixture);a.workers=workers;a.quiet=quiet;a.x=p.first;a.y=p.second;
    return a;
}

void initialize_molten(World& world, Point p, unsigned value, const std::string& context) {
    // set_cell_state returns whether bytes changed. An already initialized180
    // source legitimately returns false; authoritative readback owns setup.
    require(!world.has_failed() && world.transient_obstacle_at(p.first,p.second)==0,
            context+": invalid/masked setup owner");
    (void)world.set_cell_state(p.first,p.second,Material::MoltenGlass,
                               static_cast<std::uint16_t>(value),0);
    require(world.stored_material(p.first,p.second)==Material::MoltenGlass &&
            world.stored_state_a(p.first,p.second)==value && world.stored_state_b(p.first,p.second)==0,
            context+": cooling state readback mismatch");
}

void isolated(Point p, unsigned initial, unsigned ticks, const std::string& name) {
    auto a=arguments("molten_isolated",1,3,p), b=a, c=a, d=a;
    b.workers=4;c.quiet=1024;d.workers=4;d.quiet=1024;
    World one(config(a)),four(config(b)),awake(config(c)),awake_four(config(d)),repeat(config(a));
    const auto fixture=construct(one,a);
    for (auto* w : {&four,&awake,&awake_four,&repeat}) (void)construct(*w,a);
    for (auto* w : {&one,&four,&awake,&awake_four,&repeat})
        initialize_molten(*w,p,initial,"isolated initial state");
    unsigned expected=initial; bool converted=false;std::uint64_t legitimate=0;
    for (unsigned tick=1;tick<=ticks;++tick) {
        const bool was_molten=!converted;
        if (was_molten && tick%4U==phase(p)) {
            ++legitimate;if (expected>0) --expected;if (expected==0) converted=true;
        }
        const auto o=step(one,fixture,name,"q3-w1",p);
        const auto f=step(four,fixture,name,"q3-w4",p);
        const auto aw=step(awake,fixture,name,"q1024-w1",p);
        const auto af=step(awake_four,fixture,name,"q1024-w4",p);
        const auto rp=step(repeat,fixture,name,"q3-repeat",p,false);
        require(o.physical==f.physical && o.physical==rp.physical && aw.physical==af.physical,
                name+": exact worker/repeat physical hash mismatch");
        require(o.cells.hash==aw.cells.hash,name+": quiet3 differs from awake physical tuples");
        require(one.stored_material(p.first,p.second)==(converted?Material::Glass:Material::MoltenGlass) &&
                    one.stored_state_a(p.first,p.second)==expected,name+": thermal law/lane mismatch");
        if (was_molten && tick%4U==phase(p))
            require(o.kernel_entries==1,name+": required actual singleton kernel entry absent");
        const auto block=PrecisionProbe::block(one,p.first,p.second);
        require(block.due==0 || block.due>one.tick_index(),name+": nonfuture residual deadline");
        if (tick+24U>ticks && converted)
            require(o.stats.scheduled_cores==0 && block.due==0,name+": converted source did not retire");
    }
    require(converted && legitimate==(initial?initial:1U),name+": finite cooling failed");
    passed(name);
}

void hot_controls() {
    for (const std::string fixture_name : {"molten_pair","molten_pool_small","molten_pool_large","molten_hot"}) {
        auto a=arguments(fixture_name),b=a;b.workers=4;
        World one(config(a)),four(config(b));const auto fixture=construct(one,a);(void)construct(four,a);
        bool saw_reset=fixture_name=="molten_pool_large";
        for (unsigned tick=1;tick<=128;++tick) {
            const auto o=step(one,fixture,fixture_name,"w1",{a.x,a.y});
            const auto f=step(four,fixture,fixture_name,"w4",{a.x,a.y});
            require(o.physical==f.physical,fixture_name+": worker mismatch");
            if(one.stored_state_a(a.x,a.y)==180) saw_reset=true;
            require(one.stored_material(a.x,a.y)==Material::MoltenGlass,fixture_name+": H2 law changed");
            if(tick>96) require(o.stats.scheduled_cores==0,fixture_name+": hot fixed point did not sleep");
        }
        require(saw_reset,fixture_name+": hot sub180 reset not executed");passed(fixture_name);
    }
    // The preserved thermal kernel resets every non180 hot countdown, including
    // externally admitted values above180; it does not only handle values below.
    auto high_one=arguments("molten_hot"),high_four=high_one;high_four.workers=4;
    World one_high(config(high_one)),four_high(config(high_four));
    const auto high_fixture=construct(one_high,high_one);(void)construct(four_high,high_one);
    for(auto* w:{&one_high,&four_high})initialize_molten(*w,{11,8},181,"hot181 setup");
    for(unsigned tick=1;tick<=32;++tick) {
        const auto one=step(one_high,high_fixture,"hot-above180-reset","w1",{11,8});
        const auto four=step(four_high,high_fixture,"hot-above180-reset","w4",{11,8});
        require(one.physical==four.physical,"hot181 worker parity");
        require(one_high.stored_state_a(11,8)==(tick<4?181U:180U),"unchanged hot-above180 reset law was not preserved");
        if(tick==1)require(PrecisionProbe::block(one_high,11,8).due==4,"hot181 lost its next thermal obligation");
        if(tick>16)require(one.stats.scheduled_cores==0,"reset hot181 failed to reach a resting fixed point");
    }
    passed("hot-above180-reset");
    // Equal-density MoltenGlass partners stay at each of the eight locations;
    // a Lava-above-source fixture would introduce an unrelated density swap.
    for (const auto& offset : std::array<Point,8>{{{-1,-1},{0,-1},{1,-1},{-1,0},{1,0},{-1,1},{0,1},{1,1}}}) {
        auto a=arguments("molten_isolated");World w(config(a));Fixture fixture;std::set<Point> points;
        room(w,points,a.x-1,a.y-1,3,3);fixture.domain.assign(points.begin(),points.end());
        fixture.allowed={static_cast<unsigned>(Material::Wall),static_cast<unsigned>(Material::MoltenGlass)};
        w.set(a.x,a.y,Material::MoltenGlass);w.set(a.x+offset.first,a.y+offset.second,Material::MoltenGlass);
        initialize_molten(w,{a.x,a.y},7,"hot source setup");
        for(unsigned t=1;t<=32;++t) (void)step(w,fixture,"eight-visible-heat-neighbours","w1",{a.x,a.y});
        require(w.stored_material(a.x,a.y)==Material::MoltenGlass && w.stored_state_a(a.x,a.y)==180,
                "visible heat was missed");
        require(PrecisionProbe::block(w,a.x,a.y).due==0 && w.active_chunk_count()==0,
                "hot neighbour created a perpetual intrinsic deadline");
    }
    passed("eight-visible-heat-neighbours");
    for(const bool masked:{false,true}) {
        auto a=arguments("molten_isolated");World spark(config(a));Fixture fixture;std::set<Point> points;
        room(spark,points,a.x-1,a.y-1,3,3);fixture.domain.assign(points.begin(),points.end());
        fixture.allowed={static_cast<unsigned>(Material::Wall),static_cast<unsigned>(Material::MoltenGlass),static_cast<unsigned>(Material::Spark)};
        spark.set(a.x,a.y,Material::MoltenGlass);spark.set(a.x+1,a.y,Material::Spark);
        if(masked) {spark.configure_transient_obstacles({0,0,32,32});require(spark.set_transient_obstacle(a.x+1,a.y,1),"Spark mask rejected");}
        (void)step(spark,fixture,"spark-is-not-thermal-heat",masked?"masked":"visible",{a.x,a.y});
        require(!hot(spark,{a.x,a.y}) && PrecisionProbe::block(spark,a.x,a.y).due==4,
                "Spark suppressed cold-180 intrinsic obligation");
    }
    passed("spark-is-not-thermal-heat");
    // A first-slot Water pair and last-slot Lava heat source: source chemistry
    // phase0 is due4, thermal phase2 would incorrectly become due2 if the pair
    // loop truncated the heat scan. Water occupies a separate activity block.
    auto a=arguments("molten_isolated",1,3,{0,96});World ordered(config(a));Fixture fixture;std::set<Point> points;
    room(ordered,points,-1,95,3,3);fixture.domain.assign(points.begin(),points.end());
    for(unsigned m=0;m<256;++m)fixture.allowed.insert(m);
    ordered.set(0,96,Material::MoltenGlass);ordered.set(-1,95,Material::Water);ordered.set(1,97,Material::Lava);
    require(phase({0,96},190)==0 && phase({0,96})==2 && phase({-1,95},190)==3,"frozen pair/heat phases changed");
    (void)step(ordered,fixture,"last-heat-after-first-pair","w1",{0,96});
    require(ordered.stored_material(0,96)==Material::MoltenGlass && ordered.stored_state_a(0,96)==180 &&
            PrecisionProbe::block(ordered,0,96).due==4,"pair early exit lost later heat or wrong earliest deadline");
    passed("last-heat-after-first-pair");
}

Fixture shared_fixture(World& w) {
    Fixture f;std::set<Point> points;
    for(const auto& p : std::array<Point,5>{{{8,8},{20,8},{8,16},{20,16},{8,24}}})
        room(w,points,p.first,p.second,p==Point{8,24}?1:2,p==Point{8,24}?2:1);
    w.set(8,8,Material::MoltenGlass);w.set(20,8,Material::MoltenGlass);
    initialize_molten(w,{8,8},4,"shared setup");
    w.set(8,16,Material::Ice);w.set(9,16,Material::Water);
    w.set(20,16,Material::Water);w.set(21,16,Material::Salt);
    w.set(8,24,Material::Mercury);w.set(8,25,Material::Sand);
    f.domain.assign(points.begin(),points.end());
    for(unsigned m=0;m<256;++m) f.allowed.insert(m);
    f.origins={{8,8},{20,8},{8,16},{20,16},{8,24}};return f;
}

void shared_deadlines() {
    auto a=arguments("molten_isolated"),b=a,c=a;b.workers=4;c.quiet=1024;
    World one(config(a)),four(config(b)),awake(config(c));
    const auto fixture=shared_fixture(one);(void)shared_fixture(four);(void)shared_fixture(awake);
    for(unsigned tick=1;tick<=768;++tick) {
        if(tick==2) for(auto* w:{&one,&four,&awake}) w->set(8,8,Material::Wall);
        const auto o=step(one,fixture,"shared-molten-ice-pair-mercury","w1",{20,8});
        const auto f=step(four,fixture,"shared-molten-ice-pair-mercury","w4",{20,8});
        const auto aw=step(awake,fixture,"shared-molten-ice-pair-mercury","awake",{20,8});
        require(o.physical==f.physical,"shared deadlines differ across workers");
        require(o.cells.hash==aw.cells.hash,"removing one source lost a shared obligation");
    }
    require(one.stored_material(20,8)==Material::Glass && one.stored_material(9,16)==Material::Ice &&
            one.stored_material(20,16)==Material::Brine && one.stored_material(21,16)==Material::Brine,
            "shared work did not complete its physical operations");
    passed("shared-molten-ice-pair-mercury");
}

void mask_at_due_and_save() {
    auto a=arguments("molten_isolated");World w(config(a));auto fixture=construct(w,a);
    initialize_molten(w,{a.x,a.y},4,"mask fixture state");
    w.configure_transient_obstacles({0,0,32,32});
    for(unsigned tick=1;tick<=64;++tick) {
        if(tick==4) require(w.set_transient_obstacle(a.x,a.y,1),"due mask rejected");
        if(tick==17) w.clear_transient_obstacles();
        const auto o=step(w,fixture,"source-masked-exactly-at-due","w1",{a.x,a.y});
        if(tick>=4 && tick<17) require(w.stored_state_a(a.x,a.y)==4 && o.kernel_entries==0,
                                     "masked source executed or renewed obsolete thermal work");
        if(tick>=8 && tick<17) require(PrecisionProbe::block(w,a.x,a.y).due==0,"masked stale deadline retained");
    }
    require(w.stored_material(a.x,a.y)==Material::Glass,"unmask did not resume finite cooling");
    passed("source-masked-exactly-at-due");

    World original(config(a));fixture=construct(original,a);
    initialize_molten(original,{a.x,a.y},4,"save fixture state");
    (void)step(original,fixture,"same-source-save-continuation","original",{a.x,a.y});
    (void)step(original,fixture,"same-source-save-continuation","original",{a.x,a.y});
    const auto bytes=original.save_physical_state();
    auto restored=World::restore_physical_state(config(a),bytes);a.workers=4;
    auto four=World::restore_physical_state(config(a),bytes);
    require(original.physical_state_hash()==restored->physical_state_hash() &&
            original.physical_state_hash()==four->physical_state_hash(),"save did not preserve pending physical identity");
    for(unsigned tick=1;tick<=48;++tick) {
        const auto o=step(original,fixture,"same-source-save-continuation","original",{a.x,a.y});
        const auto r=step(*restored,fixture,"same-source-save-continuation","restored-w1",{a.x,a.y});
        const auto f=step(*four,fixture,"same-source-save-continuation","restored-w4",{a.x,a.y});
        require(o.physical==r.physical && o.physical==f.physical,"same-source CYPS continuation diverged");
    }
    passed("same-source-save-continuation");
}

void movement_and_replacement() {
    auto a=arguments("molten_short",1,3,{26,31}),b=a;b.workers=4;
    World one(config(a)),four(config(b));Fixture fixture;std::set<Point> points;
    room(one,points,26,31,1,2);fixture.domain.assign(points.begin(),points.end());
    std::set<Point> other;room(four,other,26,31,1,2);
    fixture.allowed={0,1,35,36};
    for(auto* w:{&one,&four})initialize_molten(*w,{26,31},4,"moving source setup");
    for(unsigned tick=1;tick<=48;++tick) {
        if(tick==2)for(auto* w:{&one,&four})w->set(26,32,Material::Empty);
        const Point watch=tick==1?Point{26,31}:Point{26,32};
        const auto o=step(one,fixture,"source-moves-across-activity-seam","w1",watch);
        const auto f=step(four,fixture,"source-moves-across-activity-seam","w4",watch);
        require(o.physical==f.physical,"moving-source worker parity");
        if(tick==1)require(PrecisionProbe::block(one,26,31).due==4,"moving source lacked initial due4");
        if(tick==2)require(one.stored_material(26,31)==Material::Empty && one.stored_material(26,32)==Material::MoltenGlass &&
                          events(one,Material::MoltenGlass).moves>0,"actual down relocation was not observed");
        if(tick>=4)require(PrecisionProbe::block(one,26,31).due==0,"moved source renewed its obsolete old-block deadline");
        std::cout<<"{\"type\":\"h1_move_deadlines\",\"tick\":"<<tick<<",\"old_block\":";
        print_block(PrecisionProbe::block(one,26,31));std::cout<<",\"new_block\":";
        print_block(PrecisionProbe::block(one,26,32));std::cout<<"}\n";
    }
    require(one.stored_material(26,32)==Material::Glass && one.active_chunk_count()==0,"moved destination failed finite cooling/retirement");
    passed("source-moves-across-activity-seam");

    a=arguments("molten_short");World replaced(config(a));fixture=construct(replaced,a);
    for(unsigned tick=1;tick<=32;++tick) {
        if(tick==2)replaced.set(a.x,a.y,Material::Glass);
        const auto o=step(replaced,fixture,"source-replaced-with-glass","w1",{a.x,a.y});
        if(tick>8)require(o.stats.scheduled_cores==0 && PrecisionProbe::block(replaced,a.x,a.y).due==0,
                         "replacement retained obsolete thermal work");
    }
    require(replaced.stored_material(a.x,a.y)==Material::Glass && events(replaced,Material::MoltenGlass).glass_conversions==0,
            "external replacement was mistaken for a native conversion");
    passed("source-replaced-with-glass");

    a=arguments("molten_short");a.variant="neighbor_mask";World partner(config(a));fixture=construct(partner,a);
    initialize_molten(partner,{a.x+1,a.y},1,"partner short-clock setup");
    require(partner.set_transient_obstacle(a.x,a.y,1),"source mask rejected");
    for(unsigned tick=1;tick<=48;++tick) {
        if(tick==9)partner.clear_transient_obstacles();
        (void)step(partner,fixture,"heat-partner-converts-natively-to-glass","w1",{a.x,a.y});
        if(tick==8)require(partner.stored_material(a.x+1,a.y)==Material::Glass && partner.stored_state_a(a.x,a.y)==4 &&
                           events(partner,Material::MoltenGlass).glass_conversions==1,"masked source did not permit actual partner cooling");
    }
    require(partner.stored_material(a.x,a.y)==Material::Glass && partner.active_chunk_count()==0,
            "cooling did not resume after heat partner became non-heat Glass");
    passed("heat-partner-converts-natively-to-glass");
}

int regression() {
    std::cout<<"{\"type\":\"h1_regression_metadata\",\"kernel_entry_proxy_scope\":\"stationary downward rejections plus Glass conversions; successful motion uses separate actual move counters\"}\n";
    for(const Point& p:std::array<Point,4>{{{11,8},{8,8},{10,8},{26,8}}}) {
        isolated(p,180,768,"phase-"+std::to_string(phase(p)));
        isolated(p,0,48,"zero-phase-"+std::to_string(phase(p)));
    }
    for(const Point& p:std::array<Point,8>{{{31,8},{32,8},{63,8},{64,8},{127,8},{128,8},{-1,8},{-129,-1}}})
        isolated(p,4,48,"boundary-"+std::to_string(p.first)+"-"+std::to_string(p.second));
    hot_controls();shared_deadlines();mask_at_due_and_save();movement_and_replacement();
    std::cout << "{\"type\":\"h1_regression_summary\",\"status\":\"PASS\"}\n";
    return 0;
}

Fixture bench_fixture(World& world, const std::string& name, const Args& a) {
    if(name=="cold1") return construct(world,a);
    if(name=="hot180") {auto p=a;p.fixture="molten_pool_large";return construct(world,p);}
    if(name=="water_fm" || name=="water_cy" || name=="water_pf" || name=="water_in" || name=="paste")
        return construct(world,a);
    Fixture f;std::set<Point> points;
    const unsigned count=name=="cold16"?16U:name=="cold64"?64U:name=="mixed"?32U:8U;
    if(name=="empty") {world.reserve_region({0,0,1024,512});return f;}
    for(unsigned i=0;i<count;++i) {
        const std::int64_t x=11+static_cast<std::int64_t>(i)*128,y=8;
        room(world,points,x,y,2,1);f.origins.push_back({x,y});
        if(name=="inert") continue;
        if(name=="ice_pair" || (name=="mixed" && i%4U==2U)) {
            world.set(x,y,Material::Ice);world.set(x+1,y,Material::Water);
        } else if(name=="compact_pair" || (name=="mixed" && i%4U==3U)) {
            world.set(x,y,Material::Water);world.set(x+1,y,Material::Salt);
        } else {
            world.set(x,y,Material::MoltenGlass);
            if(name=="mixed" && i%4U==1U) world.set(x+1,y,Material::MoltenGlass);
        }
    }
    f.domain.assign(points.begin(),points.end());for(unsigned m=0;m<256;++m) f.allowed.insert(m);return f;
}

struct BenchRow {
    std::uint64_t ns=0,elapsed_ns=0,cpu_ticks=0,hash=0,resident=0,entries=0,conversions=0,deadline_changes=0;
    TickStats stats{};
    std::uint64_t first_due=0;unsigned material=0,a=0;
};

int benchmark(const std::string& name,unsigned workers,bool diagnostics) {
    const std::set<std::string> admitted{"empty","inert","cold1","cold16","cold64","hot180","mixed",
        "ice_pair","compact_pair","water_fm","water_cy","water_pf","water_in","paste"};
    require(admitted.contains(name) && (workers==1 || workers==4),"unknown benchmark workload/configuration");
    auto a=arguments(name.starts_with("water_") || name=="paste"?name:"molten_isolated",workers);
    auto c=config(a,diagnostics);c.maximum_chunk_count=160;c.active_chunk_capacity=160;c.active_core_capacity=512;
    // Throwaway warmup preserves the measured world's full initial countdown.
    {World warm(c);(void)bench_fixture(warm,name,a);for(unsigned i=0;i<32;++i)(void)warm.tick();}
    World world(c);const auto fixture=bench_fixture(world,name,a);const auto initial=census(world,fixture);
    const auto resident_before=world.resident_cell_bytes();
    std::vector<BenchRow> rows;rows.reserve(horizon);
    Events previous{};if(diagnostics)previous=events(world,Material::MoltenGlass);
    std::vector<std::uint64_t> deadlines(fixture.origins.size(),0);
    const auto measured_begin=std::chrono::steady_clock::now();
    for(unsigned tick=1;tick<=horizon;++tick) {
        BenchRow row;
#ifndef _WIN32
        const auto cpu_before=std::clock();
#endif
        const auto begin=std::chrono::steady_clock::now();row.stats=world.tick();
        row.ns=static_cast<std::uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::steady_clock::now()-begin).count());
#ifndef _WIN32
        row.cpu_ticks=static_cast<std::uint64_t>(std::clock()-cpu_before);
#endif
        require(!world.has_failed() && world.completed_tick_index()==world.tick_index(),"benchmark quarantined/incomplete");
        row.resident=world.resident_cell_bytes();row.first_due=PrecisionProbe::block(world,a.x,a.y).due;
        row.material=static_cast<unsigned>(world.stored_material(a.x,a.y));row.a=world.stored_state_a(a.x,a.y);
        row.elapsed_ns=static_cast<std::uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::steady_clock::now()-measured_begin).count());
        if(diagnostics) {
            const auto e=events(world,Material::MoltenGlass);
            row.entries=e.down-previous.down+e.glass_conversions-previous.glass_conversions;
            row.conversions=e.glass_conversions-previous.glass_conversions;previous=e;
        }
        for(std::size_t i=0;i<fixture.origins.size();++i) {
            const auto p=fixture.origins[i];const auto due=PrecisionProbe::block(world,p.first,p.second).due;
            if(due!=deadlines[i]) ++row.deadline_changes;
            deadlines[i]=due;
        }
        // No hashing, census or JSON serialization occurs inside the timed tick.
        rows.push_back(row);
    }
    const auto final=census(world,fixture);
    if(name.starts_with("cold")) require(initial.count[static_cast<unsigned>(Material::MoltenGlass)]==
        final.count[static_cast<unsigned>(Material::MoltenGlass)]+final.count[static_cast<unsigned>(Material::Glass)],"benchmark species loss");
    std::cout << "{\"type\":\"h1_benchmark_metadata\",\"workload\":"<<quoted(name)<<",\"workers\":"<<workers
        <<",\"ticks\":"<<horizon<<",\"warmup_ticks\":32,\"warmup_world\":\"separate throwaway\",\"diagnostics\":"<<(diagnostics?"true":"false")
        <<",\"resident_before\":"<<resident_before<<",\"cpu_clock_ticks_per_second\":"<<CLOCKS_PER_SEC
#ifdef _WIN32
        <<",\"cpu_clock_available\":false"
#else
        <<",\"cpu_clock_available\":true"
#endif
        <<",\"initial_molten\":"<<initial.count[static_cast<unsigned>(Material::MoltenGlass)]<<"}\n";
    std::uint64_t ns=0,cpu=0,jobs=0,visits=0,entries=0,conversions=0,allocations=0,late_jobs=0;
    unsigned observed=0;
    for(std::size_t i=0;i<rows.size();++i) {
        const auto& r=rows[i];ns+=r.ns;cpu+=r.cpu_ticks;jobs+=r.stats.scheduled_cores;visits+=r.stats.visited_cells;
        entries+=r.entries;conversions+=r.conversions;allocations+=r.stats.chunk_allocations+r.stats.temperature_field_allocations;
        observed=std::max(observed,r.stats.worker_threads_observed);if(i>=768)late_jobs+=r.stats.scheduled_cores;
        std::cout<<"{\"type\":\"h1_benchmark_tick\",\"tick\":"<<i+1<<",\"tick_ns\":"<<r.ns
            <<",\"elapsed_to_observation_ns\":"<<r.elapsed_ns
            <<",\"cpu_clock_ticks\":"<<r.cpu_ticks<<",\"jobs\":"<<r.stats.scheduled_cores<<",\"visited_cells\":"<<r.stats.visited_cells
            <<",\"active_blocks\":"<<r.stats.active_blocks_after<<",\"observed_workers\":"<<r.stats.worker_threads_observed
            <<",\"chunk_allocations\":"<<r.stats.chunk_allocations<<",\"temperature_allocations\":"<<r.stats.temperature_field_allocations
            <<",\"resident_cell_bytes\":"<<r.resident<<",\"observed_deadline_changes\":"<<r.deadline_changes
            <<",\"first_source_due\":"<<r.first_due<<",\"first_source_material\":"<<r.material<<",\"first_source_a\":"<<r.a
            <<",\"kernel_entries_world\":"<<(diagnostics?std::to_string(r.entries):"null")
            <<",\"glass_conversions\":"<<(diagnostics?std::to_string(r.conversions):"null")<<"}\n";
    }
    std::cout<<"{\"type\":\"h1_benchmark_summary\",\"tick_ns_total\":"<<ns<<",\"cpu_clock_ticks_total\":"<<cpu
        <<",\"jobs\":"<<jobs<<",\"visited_cells\":"<<visits<<",\"max_workers_observed\":"<<observed
        <<",\"tail_769_1024_jobs\":"<<late_jobs<<",\"chunk_and_temperature_allocations\":"<<allocations
        <<",\"resident_after\":"<<world.resident_cell_bytes()<<",\"final_molten\":"<<final.count[static_cast<unsigned>(Material::MoltenGlass)]
        <<",\"final_glass\":"<<final.count[static_cast<unsigned>(Material::Glass)]
        <<",\"kernel_entries_world\":"<<(diagnostics?std::to_string(entries):"null")
        <<",\"glass_conversions\":"<<(diagnostics?std::to_string(conversions):"null")
        <<",\"tuple_hash\":"<<quoted(hex(final.hash))<<",\"physical_hash\":"<<quoted(hex(world.physical_state_hash()))<<"}\n";
    return 0;
}

int snapshot(const std::string& mode,const std::filesystem::path& path) {
    auto a=arguments("molten_isolated");auto world=std::make_unique<World>(config(a));const auto fixture=construct(*world,a);
    if(mode=="--snapshot-out") {
        require(!std::filesystem::exists(path),"snapshot output exists");
        for(unsigned tick=1;tick<=8;++tick)(void)step(*world,fixture,"cross-source-snapshot-export","source",{a.x,a.y});
        const auto bytes=world->save_physical_state();std::ofstream file(path,std::ios::binary);
        file.write(reinterpret_cast<const char*>(bytes.data()),static_cast<std::streamsize>(bytes.size()));
        require(static_cast<bool>(file),"snapshot write failed");file.close();
        std::cout<<"{\"type\":\"h1_snapshot_export\",\"bytes\":"<<bytes.size()<<",\"state_a\":"<<world->stored_state_a(a.x,a.y)
            <<",\"due\":"<<PrecisionProbe::block(*world,a.x,a.y).due<<"}\n";return 0;
    }
    require(std::filesystem::file_size(path)<64U*1024U*1024U,"snapshot exceeds bound");
    std::ifstream file(path,std::ios::binary);std::vector<std::uint8_t> bytes((std::istreambuf_iterator<char>(file)),{});
    try {world=World::restore_physical_state(config(a),bytes);}
    catch(const std::invalid_argument& e) {std::cout<<"{\"type\":\"h1_cross_source_import\",\"accepted\":false,\"reason\":"<<quoted(e.what())<<"}\n";return 0;}
    const auto initial_a=world->stored_state_a(a.x,a.y);const auto initial_due=PrecisionProbe::block(*world,a.x,a.y).due;
    std::uint64_t jobs=0;
    for(unsigned t=1;t<=1024;++t)jobs+=step(*world,fixture,"cross-source-unaltered-import","successor",{a.x,a.y}).stats.scheduled_cores;
    const auto unchanged_material=world->stored_material(a.x,a.y);const auto unchanged_a=world->stored_state_a(a.x,a.y);
    // A separately labelled existing intervention, never an automatic migration.
    world->set_simulation_region(RectI64{32768,32768,64,64});(void)world->tick();world->set_simulation_region(std::nullopt);
    for(unsigned t=1;t<=768;++t)(void)step(*world,fixture,"cross-source-explicit-region-reentry","successor",{a.x,a.y});
    std::cout<<"{\"type\":\"h1_cross_source_import\",\"accepted\":true,\"initial_a\":"<<initial_a<<",\"initial_due\":"<<initial_due
        <<",\"unaltered_1024_jobs\":"<<jobs<<",\"unaltered_material\":"<<static_cast<unsigned>(unchanged_material)<<",\"unaltered_a\":"<<unchanged_a
        <<",\"after_explicit_reentry_material\":"<<static_cast<unsigned>(world->stored_material(a.x,a.y))<<"}\n";return 0;
}
}

int main(int argc,char** argv) {
    try {
        if(argc>=2 && std::string(argv[1])=="--fixture") return mat354::run(mat354::parse(argc,argv));
        if(argc>=2 && std::string(argv[1])=="--phase-a") return mat354::run(mat354::parse(argc-1,argv+1));
        if(argc==2 && std::string(argv[1])=="--regress") return mat354_h1::regression();
        if(argc==5 && std::string(argv[1])=="--bench") return mat354_h1::benchmark(argv[2],static_cast<unsigned>(std::stoul(argv[3])),std::string(argv[4])=="1");
        if(argc==3 && (std::string(argv[1])=="--snapshot-out" || std::string(argv[1])=="--snapshot-in")) return mat354_h1::snapshot(argv[1],argv[2]);
        throw std::invalid_argument("expected --regress, --phase-a FLAGS, --bench WORKLOAD WORKERS DIAGNOSTICS, or --snapshot-in/out PATH");
    } catch(const std::exception& e) {
        std::cout<<"{\"type\":\"h1_failure\",\"message\":"<<mat354::quoted(e.what())<<"}\n";
        std::cerr<<e.what()<<'\n';return 1;
    }
}
