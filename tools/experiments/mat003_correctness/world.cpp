#include "probe.hpp"
int main(int argc,char** argv) {
    try {
        fixture::require(argc==7,"usage: world suite side workers serial|phased scene output");
        using namespace cybersand;
        const std::string suite=argv[1],scene=argv[5];const unsigned side=std::stoul(argv[2]),workers=std::stoul(argv[3]);
        fixture::require((side==128||side==256||side==512||side==2048)&&(workers==1||workers==4),"unregistered size/workers");
        fixture::require(suite=="small"||suite=="natural"||suite=="resident","unknown suite");
        fixture::require(suite!="resident" || MAT003_EPOCH_BITS==16,"resident requires E16");
        const std::filesystem::path output=argv[6];fixture::require(!std::filesystem::exists(output),"output exists");
        for(const std::string role: suite=="resident"?std::vector<std::string>{"event","reference"}:std::vector<std::string>{"ordinary"}) {
            WorldConfig config;config.worker_threads=workers;config.parallel_job_threshold=1;
            config.backend=std::string(argv[4])=="serial"?SimulationBackend::SerialInPlace:SimulationBackend::PhasedInPlace;
            config.settled_discovery_enabled=false;config.physics_diagnostics.enabled=true;
            World world(config);world.reserve_region({0,0,side,side});world.reserve_temperature_region({0,0,128,128});
            if(suite=="resident")world.set_simulation_region(RectI64{0,0,side/2,side});
            for(unsigned y=0;y<side;y+=128)for(unsigned x=0;x<side;x+=128)world.set(x+3,y+3,Material::Wall);
            world.set(20,20,Material::Sand);world.set(side-8,8,Material::Sand);
            TickStats stats;
            const unsigned horizon=suite=="natural"?65540:(suite=="resident"?255:2048);
            std::filesystem::create_directories(output/role);
            std::ofstream ticks(output/role/"ticks.txt");
            for(unsigned tick=0;tick<=horizon;++tick) {
                if(tick) {
                    if(scene=="active-window-excluded" || suite=="small")
                        for(unsigned x=16;x<side/2;x+=64){world.set(x,8,Material::Water);world.set(x+8,8,Material::Sand);}
                    stats=world.tick();
                    ticks<<stats.tick<<' '<<stats.visited_cells<<' '<<stats.moved_cells<<' '<<stats.scheduled_cores;
                    for(auto jobs:stats.phase_jobs)ticks<<' '<<jobs;ticks<<'\n';
                }
                if(suite!="resident" && (tick==0||tick==1||tick==255||tick==256||tick==257||tick==horizon||tick==65534||tick==65535||tick==65536||tick==65537))
                    PrecisionProbe::canonical_endpoint(world,stats,output/role/("tick-"+std::to_string(tick)));
            }
            if(suite=="resident") {
                PrecisionProbe::canonical_endpoint(world,stats,output/role/"B");
                PrecisionProbe::prepare_clear(world,role=="event"?65535:128);
                PrecisionProbe::canonical_endpoint(world,stats,output/role/"P");
                stats=world.tick();PrecisionProbe::canonical_endpoint(world,stats,output/role/"Q");
                world.set_simulation_region(RectI64{0,0,side,side});
                for(unsigned i=0;i<4;++i)stats=world.tick();
                PrecisionProbe::canonical_endpoint(world,stats,output/role/"R");
            }
            fixture::require(bool(ticks),"tick receipt write failed");
        }
        return 0;
    }catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}
}
