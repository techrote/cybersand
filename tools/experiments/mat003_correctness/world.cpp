#include "resource.hpp"
#include "probe.hpp"
#include "lifecycle.hpp"
int main(int argc,char** argv) {
    ResourceReceipt resource;
    try {
        fixture::require(argc==7,"usage: world suite side workers serial|phased scene output");
        using namespace cybersand;
        const std::string suite=argv[1],scene=argv[5],backend=argv[4];const unsigned side=std::stoul(argv[2]),workers=std::stoul(argv[3]);
        fixture::require((side==128||side==256||side==512||side==2048)&&(workers==1||workers==4),"unregistered size/workers");
        fixture::require(backend=="serial"||backend=="phased","unknown backend");
        fixture::require(suite=="small"||suite=="natural"||suite=="resident"||suite=="refusal","unknown suite");
        fixture::require((suite!="natural"&&suite!="resident")||MAT003_EPOCH_BITS==16,"wide suite requires E16");
        const std::filesystem::path output=argv[6];fixture::require(!std::filesystem::exists(output),"output exists");
        for(const std::string& role: suite=="resident"?std::vector<std::string>{"event","reference"}:suite=="natural"?std::vector<std::string>{"ordinary","prepared"}:std::vector<std::string>{"ordinary"}) {
            mat003_world::reset_dispatch_observations();mat003_correctness::trace_size=0;mat003_correctness::trace_overflow=false;
            mat003_correctness::trace_enabled=false;
            WorldConfig config;config.worker_threads=workers;config.parallel_job_threshold=1;
            config.backend=backend=="serial"?SimulationBackend::SerialInPlace:SimulationBackend::PhasedInPlace;
            config.maximum_chunk_count=side*side/(128*128);config.initial_chunk_reserve=config.maximum_chunk_count;config.active_core_capacity=128;config.active_chunk_capacity=64;
            if(suite=="resident") {
                fixture::require((side==512||side==2048)&&backend=="phased"&&
                    (scene=="sleeping-excluded"||scene=="active-window-excluded"),"unreviewed resident fixture");
                // begin_tick retains active excluded chunks. gather_active_cores
                // appends up to four aligned 32-cell blocks per 64-cell core
                // BEFORE deduplication. Provision both lists, not just jobs.
                fixture::require(config.chunk_size==128&&config.activity_block_size==32&&
                    config.scheduling_core_size==64&&config.maximum_rule_radius==2,"unreviewed resident geometry");
                config.active_chunk_capacity=config.maximum_chunk_count;
                config.active_core_capacity=256; // 64 unique cores * 4 block entries
            }
            config.settled_discovery_enabled=false;config.physics_diagnostics.enabled=true;
            World world(config);world.reserve_region({0,0,side,side});world.reserve_temperature_region({0,0,128,128});
            // Keep moving cells outside the scheduler's outer write-radius strip.
            // A simulation-interest rectangle alone does not bound destinations.
            if(suite=="small") {
                fixture::require(side==256,"unreviewed containment extent");
                fixture::require(config.maximum_rule_radius==2,"unreviewed containment radius");
                const unsigned border=static_cast<unsigned>(config.maximum_rule_radius);
                for(unsigned y=0;y<side;++y)for(unsigned x=0;x<side;++x)
                    if(x<border||y<border||x>=side-border||y>=side-border)
                        world.set(x,y,Material::Wall);
            }
            if(suite=="resident")world.set_simulation_region(RectI64{0,0,256,512});
            // Excluded walls retain nonempty resident chunks without unbounded selected work.
            if(suite=="resident")for(unsigned x=256;x<side;x+=128)world.set(x+3,3,Material::Wall);
            if(suite=="resident")world.set(504,8,Material::Sand);
            world.set(3,3,Material::Wall);world.set(20,20,Material::Sand);world.set(40,40,Material::Water);
            for(unsigned x=0;x<side;++x)world.set(x,side-4,Material::Wall);
            if(suite=="natural"||suite=="resident"){
                for(int y=39;y<=41;++y)for(int x=39;x<=41;++x)if(x!=40||y!=40)world.set(x,y,Material::Wall);
                world.set(20,21,Material::Wall);
            }
            PrecisionProbe::seed(world);
            TickStats stats;std::filesystem::create_directories(output/role);
            std::ofstream ticks(output/role/"ticks.txt"),transitions(output/role/"transitions.txt"),inputs(output/role/"inputs.txt");
            // Registry used for transition addresses is retained without a fifth endpoint.
            PrecisionProbe::registry(world,output/role/"registry.txt");
            mat003_correctness::trace_enabled=true;
            if(suite=="refusal") {
                mat003_correctness::trace_enabled=false;
                std::ofstream attempts(output/role/"attempts.txt");
                PrecisionProbe::canonical_endpoint(world,stats,output/role/"before");
                for(unsigned i=0;i<224;++i){const unsigned kind=i%7;const auto before=PrecisionProbe::raw_at(world,7,7);
                    PrecisionProbe::canonical_endpoint(world,stats,output/role/("attempt-"+std::to_string(i)+"-pre"),true);
                    const bool ok=PrecisionProbe::admit(world,kind==5?side+1:7,7,kind==4?2:1,kind==6?10:0,kind==3?65536:1,0,kind==1?65536:kind==2?-1:kind==0?65535:0);
                    const auto after=PrecisionProbe::raw_at(world,7,7);
                    PrecisionProbe::canonical_endpoint(world,stats,output/role/("attempt-"+std::to_string(i)+"-post"),true);
                    attempts<<i<<' '<<kind<<' '<<ok<<' ';
                    constexpr char h[]="0123456789abcdef";for(auto b:before)attempts<<h[b>>4]<<h[b&15];attempts<<' ';for(auto b:after)attempts<<h[b>>4]<<h[b&15];attempts<<'\n';
                    fixture::require(ok||before==after,"record refusal mutated cells");
                }
                PrecisionProbe::canonical_endpoint(world,stats,output/role/"after");
                fixture::require(bool(attempts),"attempt output failure");
                mat003_correctness::trace_enabled=false;continue;
            }
            const unsigned horizon=suite=="natural"?(role=="prepared"?65535:65540):(suite=="resident"?255:2048);
            const auto advance=[&](){stats=world.tick();PrecisionProbe::tick_receipt(world,stats,ticks);mat003_correctness::flush_trace(transitions,MAT003_CAPACITY/8,world.completed_tick_index());};
            for(unsigned tick=0;tick<=horizon;++tick) {
                if(tick) {
                    if(suite=="small"&&tick==1)fixture::operations(world,output/role/"operations.txt");
                    // Bounded eight input pulses; later ticks test retention/sleep/reentry.
                    if((suite=="small"&&tick<=8)||(suite=="resident"&&scene=="active-window-excluded"&&tick>=248))
                        for(unsigned x=16;x<(suite=="resident"?256:side/2);x+=64){fixture::input(world,tick,x,8,Material::Water,inputs);fixture::input(world,tick,x+8,8,Material::Sand,inputs);}
                    advance();
                }
                if(suite!="resident" && role!="prepared" && (tick==0||tick==1||tick==255||tick==256||tick==257||tick==horizon||tick==65534||tick==65535||tick==65536||tick==65537))
                    PrecisionProbe::canonical_endpoint(world,stats,output/role/("tick-"+std::to_string(tick)));
            }
            if(suite=="resident"||role=="prepared") {
                PrecisionProbe::canonical_endpoint(world,stats,output/role/"B");
                if(role=="prepared")PrecisionProbe::prepare_clear(world,128);
                PrecisionProbe::prepare_clear(world,role=="event"||role=="prepared"?65535:128);
                PrecisionProbe::canonical_endpoint(world,stats,output/role/"P");
                advance();PrecisionProbe::canonical_endpoint(world,stats,output/role/"Q");
                // Bounded reentry: full interest for 512, a 512-square window
                // for 2048. All resident cells still take the actual clear.
                if(suite=="resident")world.set_simulation_region(RectI64{0,0,512,512});
                for(unsigned i=0;i<4;++i)advance();
                PrecisionProbe::canonical_endpoint(world,stats,output/role/"R");
            }
            mat003_correctness::trace_enabled=false;fixture::require(bool(ticks)&&bool(transitions)&&bool(inputs),"receipt write failed");
        }
        if(suite=="refusal")fixture::quarantine(output/"ordinary");
        return 0;
    }catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}
}
