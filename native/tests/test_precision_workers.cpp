#include "cybersand/world.hpp"
#include "cybersand/precision_storage.hpp"
#include <array>
#include <iostream>
#include <stdexcept>
#include <vector>
using namespace cybersand;
struct Row {
    std::uint64_t hash,visited,moved,active,cores;
    bool operator==(const Row&) const = default;
};
int main(){try{
    std::vector<Row> reference;
    for(unsigned workers:{1U,4U,1U,4U}){
        WorldConfig c;c.worker_threads=workers;c.parallel_job_threshold=1;
        c.maximum_chunk_count=64;c.active_chunk_capacity=64;c.active_core_capacity=512;c.physics_diagnostics.enabled=true;
        World w(c);w.reserve_region({-128,-128,768,512});
        for(int offset:{0,128,256,384}){
            for(int x=0;x<=49;++x){w.set(offset+x,0,Material::Wall);w.set(offset+x,47,Material::Wall);}
            for(int y=0;y<48;++y){w.set(offset,y,Material::Wall);w.set(offset+49,y,Material::Wall);}
            for(int x=1;x<=12;++x)for(int y=15;y<=46;++y)w.set(offset+x,y,Material::Water);
        }
        std::vector<Row> rows;bool concurrent=false;
        for(int tick=1;tick<=1800;++tick){
            auto s=w.tick();for(auto n:s.phase_jobs)concurrent|=n>=4;
            std::uint64_t hash=14695981039346656037ULL;
            for(int offset:{0,128,256,384}){
                std::uint64_t quantity=0;
                for(int y=1;y<=46;++y)for(int x=1;x<=48;++x){
                    auto a=w.liquid_mass(offset+x,y);quantity+=a;
                    for(unsigned v:{static_cast<unsigned>(w.stored_material(offset+x,y)),static_cast<unsigned>(a),static_cast<unsigned>(w.stored_state_b(offset+x,y))}){
                        hash^=v&255;hash*=1099511628211ULL;hash^=v>>8;hash*=1099511628211ULL;
                    }
                }
                if(quantity!=384ULL*precision::maximum)throw std::runtime_error("closed basin conservation");
            }
            if(s.chunk_allocations||s.temperature_field_allocations||w.physics_diagnostics()->overflow)throw std::runtime_error("allocation/overflow");
            rows.push_back({hash,s.visited_cells,s.moved_cells,s.active_blocks_after,s.scheduled_cores});
        }
        if(!concurrent)throw std::runtime_error("four same-phase jobs not exercised");
        if(reference.empty())reference=rows;else if(reference!=rows)throw std::runtime_error("worker/repeat divergence");
    }
    std::cout<<"PASS four simultaneous phase jobs; workers1/4 twice;1800 exact ticks;four closed basins\n";
    return 0;
}catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}}
