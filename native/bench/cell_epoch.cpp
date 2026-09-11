#include "cybersand/cell_layout_experiment.hpp"
#include "cybersand/world.hpp"
#include "cybersand/material_rules.hpp"
#include <set>
#include <tuple>
#include <algorithm>
#include <array>
#include <chrono>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#include <psapi.h>
#endif

using namespace cybersand;
using Clock = std::chrono::steady_clock;
static std::int64_t nanos(Clock::duration d) {
    return std::chrono::duration_cast<std::chrono::nanoseconds>(d).count();
}
static void require(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}
static void put(std::ostream& out, std::uint64_t value) {
    for (int i = 0; i < 8; ++i) out.put(static_cast<char>((value >> (8 * i)) & 255));
}
static void work_record(std::ostream& out, const TickStats& s) {
    for (auto v : {s.tick, s.visited_cells, s.moved_cells, s.active_chunks_before,
         s.active_chunks_after, s.active_blocks_after, s.dirty_chunks, s.scheduled_cores,
         s.chunk_allocations, s.temperature_field_allocations, s.deferred_events}) put(out,v);
    for (auto v : s.phase_jobs) put(out,v);
}
static void semantic_record(std::ostream& out, const World& world, const TickStats& stats) {
    const auto records = CellLayoutExperiment::semantic_records(world);
    put(out, records.size());
    out.write(reinterpret_cast<const char*>(records.data()), static_cast<std::streamsize>(records.size()));
    work_record(out, stats);
    put(out, world.state_hash()); // L1 same ABI/schema only, independent of padding.
    if (const auto* events = world.physics_diagnostics()) {
        require(events->overflow == 0, "diagnostic overflow");
        std::vector<std::pair<std::uint32_t,std::uint64_t>> sorted;
        for (const auto& e : events->entries) if (e.key) sorted.emplace_back(e.key,e.count);
        std::sort(sorted.begin(),sorted.end());
        put(out,sorted.size());
        for (auto [key,count] : sorted) { put(out,key); put(out,count); }
    } else put(out,0);
}
static void box(World& w, int x, int y, int width, int height) {
    for (int i=0;i<width;++i) { w.set(x+i,y,Material::Wall); w.set(x+i,y+height-1,Material::Wall); }
    for (int i=0;i<height;++i) { w.set(x,y+i,Material::Wall); w.set(x+width-1,y+i,Material::Wall); }
}
static std::array<std::uint64_t,2> quantities(const World& w,int x,int y) {
    std::array<std::uint64_t,2> totals{};
    for (int dy=0;dy<64;++dy) for (int dx=0;dx<64;++dx) {
        const auto m=w.stored_material(x+dx,y+dy);
        if(m==Material::Water) totals[0]+=w.liquid_mass(x+dx,y+dy);
        if(m==Material::Sand) ++totals[1];
    }
    return totals;
}
static bool wrap_tick(std::uint64_t tick,unsigned bits){const auto m=(1ULL<<bits)-1;return tick>=m+1&&(tick-m-1)%m==0;}
static void export_clears(const World& w,const std::string& prefix){
 std::ofstream a(prefix+".clears.csv"),b(prefix+".clear-chunks.csv");
 a<<"tick,ns,chunks,cells\n";b<<"tick,x,y,cells,active_blocks,selection,active\n";
 if(const auto* t=CellLayoutExperiment::epochs(w)){
  std::size_t expected=0;for(std::uint64_t k=1;k<=w.tick_index();++k)expected+=wrap_tick(k,CYBERSAND_CELL_LAYOUT_EPOCH_BITS);
  require(t->used==expected,"clear schedule count");
  for(std::size_t i=0;i<t->used;++i){const auto& e=t->samples[i];require(wrap_tick(e.tick,CYBERSAND_CELL_LAYOUT_EPOCH_BITS),"clear schedule tick");
   std::vector<EpochClearChunk> chunks(t->chunks.begin()+static_cast<std::ptrdiff_t>(e.first),t->chunks.begin()+static_cast<std::ptrdiff_t>(e.first+e.count));
   std::sort(chunks.begin(),chunks.end(),[](const auto& x,const auto& y){return std::tie(x.x,x.y)<std::tie(y.x,y.y);});
   std::uint64_t cells=0;std::set<std::pair<std::int64_t,std::int64_t>> unique;
   for(const auto& c:chunks){require(unique.emplace(c.x,c.y).second,"duplicate clear chunk");cells+=c.cells;b<<e.tick<<','<<c.x<<','<<c.y<<','<<c.cells<<','<<c.active_blocks<<','<<unsigned(c.selection)<<','<<c.active<<'\n';}
   a<<e.tick<<','<<e.ns<<','<<e.count<<','<<cells<<'\n';
  }
 }
 require(a.good()&&b.good(),"clear records write");
}
struct MotionCheck{
 std::array<int,16> positions{};std::array<unsigned,16> ages{};bool initialized=false;
 std::uint64_t injected=0,reclaimed=0,events=0,moved=0;
 void before(World& w,int i,int x,int y){
  const bool paused=(i>=60&&i<130)||(i>=240&&i<300);
  w.set_simulation_region(paused?std::optional<RectI64>{{x+4096LL,y+4096LL,64,64}}:std::nullopt);
  if(i%32==0){for(int j=0;j<16;++j){const int px=x+j*128;
   if(initialized){w.set(px,positions[j],Material::Empty);w.set_temperature(px,positions[j],200);++reclaimed;}
   positions[j]=y+(j%2?64:128);ages[j]=255;require(w.set_cell_state(px,positions[j],Material::Foam,255,0),"Foam injection");w.set_temperature(px,positions[j],315);++injected;
  }initialized=true;}
  require(w.set_cell_state(x-64,y+128,Material::Wall,static_cast<std::uint8_t>(i&255),255),"sentinel stamp");
  if(wrap_tick(static_cast<std::uint64_t>(i+1),6)||wrap_tick(static_cast<std::uint64_t>(i+1),8)){require(w.queue_explosion(x+2130,y+30,2,0),"wrap event");++events;}
 }
 void after(const World& w,int i,int x,int y){
  const bool paused=(i>=60&&i<130)||(i>=240&&i<300);
  for(int j=0;j<16;++j){const int px=x+j*128;if(!paused){require(w.stored_material(px,positions[j])==Material::Empty&&w.temperature(px,positions[j])==200,"Foam source clear");--positions[j];--ages[j];++moved;}
   require(w.stored_material(px,positions[j])==Material::Foam&&w.stored_state_a(px,positions[j])==ages[j]&&w.temperature(px,positions[j])==315,"Foam double update/state transfer");}
  if(wrap_tick(static_cast<std::uint64_t>(i+1),CYBERSAND_CELL_LAYOUT_EPOCH_BITS))require(CellLayoutExperiment::epoch_at(w,x-64,y+128)==0,"sentinel epoch reset");
  if(wrap_tick(static_cast<std::uint64_t>(i+1),6)||wrap_tick(static_cast<std::uint64_t>(i+1),8))require(w.stored_material(x+2130,y+30)==Material::Fire&&w.stored_state_a(x+2130,y+30)==MaterialRules::descriptor(Material::Fire).initial_state_a,"prewritten event double update");
  require(injected-reclaimed==16,"Foam source/sink ledger");
 }
};
static void fixture(World& w, const std::string& name, int extent, int seed,int x,int y) {
    if(name=="epoch") {
        w.reserve_region({x-128LL,y-128LL,2560,512});
        w.reserve_temperature_region({x-128LL,y-128LL,2560,512});
        box(w,x+2112,y,64,64);w.set(x-64,y+128,Material::Wall);return;
    }
    if(name=="behavior") {
        box(w,x,y,64,64);
        for(int j=2;j<18;++j) for(int i=2;i<36;++i) {
            if ((i*17+j*31+seed)%5==0) {
                require(w.set_cell_state(x+i,y+j,Material::Sand,17,23),"Sand setup");
                w.set_temperature(x+i,y+j,315);
            } else require(w.set_cell_state(x+i,y+j,Material::Water,128+(i+j+seed)%128,12),"Water setup");
        }
        // Isolated reactive chamber; its species changes are not conservation failures.
        box(w,x+80,y,64,64);
        const std::array materials{Material::Smoke,Material::Fire,Material::Wood,Material::Lava,
            Material::Ice,Material::Acid,Material::Oil,Material::Plant,Material::Fungus,
            Material::Metal,Material::Spark,Material::Cement,Material::MoltenGlass,Material::Foam};
        for(std::size_t i=0;i<materials.size();++i)
            w.set(x+84+static_cast<int>(i%7)*7,y+4+static_cast<int>(i/7)*8,materials[i]);
        // Full-state compatibility counterexample, never executed as a Rocket heading.
        require(w.set_cell_state(x-4,y,Material::Wall,255,255),"byte range setup");
        return;
    }
    w.reserve_region({-128,-128,extent+256LL,extent+256LL});
    if(name=="dense") {
        for(int i=0;i<extent;++i) w.set(i,extent-1,Material::Wall);
        for(int j=0;j<extent/2;++j) for(int i=0;i<extent;++i) {
            const auto selector=(i*17+j*31)%13;
            if(selector<7) w.set(i,j,Material::Sand);
            else if(selector<10) w.set(i,j,Material::Water);
            else if(selector==10) w.set(i,j,Material::Smoke);
        }
    } else {
        for(int j=0;j<extent;j+=128) for(int i=0;i<extent;i+=128) w.set(i,j,Material::Wall);
        for(int i=0;i<4;++i) (void)w.tick(); // Existing sparse fixture settling.
        const int c=extent/2;
        for(int i=c-64;i<=c+64;++i) w.set(i,c+80,Material::Wall);
        for(int j=c-64;j<c;++j) for(int i=c-64;i<c+64;++i) {
            const auto selector=(i*17+j*31)%13;
            if(selector<7) w.set(i,j,Material::Sand);
            else if(selector<10) w.set(i,j,Material::Water);
            else if(selector==10) w.set(i,j,Material::Smoke);
        }
        if(name=="sleeping") w.set_simulation_region(RectI64{c-128,c-128,256,256});
    }
    (void)w.take_dirty_chunks();
}
int main(int argc,char** argv) {
    try {
        require(argc==11,"usage: mode fixture extent workers ticks seed x y observer output-prefix");
        const std::string mode=argv[1], name=argv[2], prefix=argv[10];
        const bool timing=mode=="timing";
        require(timing || mode=="correctness","invalid mode");
        require(name=="epoch"||name=="behavior"||name=="dense"||name=="sparse"||name=="sleeping","invalid fixture");
        const int extent=std::stoi(argv[3]), workers=std::stoi(argv[4]),ticks=std::stoi(argv[5]);
        const int seed=std::stoi(argv[6]),x=std::stoi(argv[7]),y=std::stoi(argv[8]);
        require((workers==1||workers==4)&&ticks>0&&ticks<=10000,"invalid run bounds");
        require(extent==512||extent==1024||extent==4096,"invalid extent");
        require(!timing || (name!="behavior"&&name!="epoch"),"behavior is a correctness fixture");
        WorldConfig config{};
        config.worker_threads=static_cast<std::uint32_t>(workers);
        config.physics_diagnostics.enabled=(std::stoi(argv[9])&1)!=0;
        const auto startup=timing ? Clock::now() : Clock::time_point{};
        World world(config);
        if((std::stoi(argv[9])&2)!=0) CellLayoutExperiment::configure_epochs(world);
        fixture(world,name,extent,seed,x,y);
        MotionCheck motion;
        const auto startup_ns=timing ? nanos(Clock::now()-startup) : 0;
        const auto initial=quantities(world,x,y);
        const auto identity=CellLayoutExperiment::footprint(world);
        constexpr std::size_t expected_alignment =
#ifdef CYBERSAND_CELL_LAYOUT_ALIGNMENT
            CYBERSAND_CELL_LAYOUT_ALIGNMENT;
#else
            1;
#endif
        require(identity.cell_size==CYBERSAND_CELL_LAYOUT_EXPERIMENT && identity.alignment==expected_alignment &&
                identity.stride==identity.cell_size,"layout mismatch");
        require(world.resident_cell_bytes()==identity.cells+identity.temperatures+identity.activity,"aggregate mismatch");
        std::ofstream records(prefix+".records",std::ios::binary);
        require(records.good(),"cannot write semantic records");
        std::vector<std::int64_t> durations;
        std::vector<TickStats> stats_rows;
        durations.reserve(static_cast<std::size_t>(ticks)); stats_rows.reserve(static_cast<std::size_t>(ticks));
        if(!timing) semantic_record(records,world,{});
        for(int i=0;i<ticks;++i) {
            if(name=="epoch")motion.before(world,i,x,y);
            if(name=="behavior") {
                if(i==256) world.set_simulation_region(RectI64{x+512,y+512,64,64});
                if(i==511) world.set_simulation_region(std::nullopt);
                if(i==765) require(world.queue_explosion(x+110,y+30,4),"event enqueue");
            }
            const auto start=timing ? Clock::now() : Clock::time_point{};
            const auto stats=world.tick();
            if(timing) durations.push_back(nanos(Clock::now()-start));
            stats_rows.push_back(stats);
            if(name=="epoch")motion.after(world,i,x,y);
            if(!timing) {
                if(name=="behavior") require(quantities(world,x,y)==initial,"closed Water/Sand accounting");
                semantic_record(records,world,stats);
            }
        }
        if(timing) {
            // Full work history and final exact semantic state, outside timed sections.
            for(const auto& s:stats_rows) work_record(records,s);
            semantic_record(records,world,stats_rows.back());
            std::ofstream csv(prefix+".ticks.csv");
            csv<<"sample,tick,ns,visited\n";
            for(std::size_t i=0;i<durations.size();++i)
                csv<<i<<','<<stats_rows[i].tick<<','<<durations[i]<<','<<stats_rows[i].visited_cells<<'\n';
            require(csv.good(),"timing write failed");
        }
        require(records.good(),"semantic write failed");
        export_clears(world,prefix);
        const auto f=CellLayoutExperiment::footprint(world);
        std::uint64_t working_set=0,private_bytes=0,peak_working_set=0;
#ifdef _WIN32
        PROCESS_MEMORY_COUNTERS_EX memory{};
        if(GetProcessMemoryInfo(GetCurrentProcess(),reinterpret_cast<PROCESS_MEMORY_COUNTERS*>(&memory),sizeof(memory))) {
            working_set=memory.WorkingSetSize;private_bytes=memory.PrivateUsage;peak_working_set=memory.PeakWorkingSetSize;
        }
#endif
        std::cout<<"{\"cell_size\":"<<f.cell_size<<",\"alignment\":"<<f.alignment<<",\"stride\":"<<f.stride
            <<",\"epoch_bits\":"<<CYBERSAND_CELL_LAYOUT_EPOCH_BITS<<",\"epoch_trace_bytes\":"<<CellLayoutExperiment::epoch_trace_bytes(world)
            <<",\"injected\":"<<motion.injected<<",\"reclaimed\":"<<motion.reclaimed<<",\"motion_steps\":"<<motion.moved<<",\"wrap_events\":"<<motion.events
            <<",\"cells\":"<<f.cells<<",\"temperatures\":"<<f.temperatures<<",\"activity\":"<<f.activity
            <<",\"chunk_objects\":"<<f.chunk_objects<<",\"map_buckets_estimate\":"<<f.map_buckets
            <<",\"coordinator_vectors\":"<<f.coordinator_vectors<<",\"parallel_vectors\":"<<f.parallel_vectors
            <<",\"legacy_aggregate\":"<<world.resident_cell_bytes()<<",\"startup_ns\":"<<startup_ns
            <<",\"working_set\":"<<working_set<<",\"private_bytes\":"<<private_bytes<<",\"peak_working_set\":"<<peak_working_set
            <<",\"state_hash\":"<<world.state_hash()<<",\"content_hash\":"<<world.content_hash()<<"}\n";
    } catch(const std::exception& error) { std::cerr<<error.what()<<'\n';return 1; }
}
