#include "cybersand/world.hpp"
#include <algorithm>
#include <chrono>
#include <iostream>
#include <string>
#include <vector>

// Fresh deterministic controls. Seed translates the entire recipe, including
// negative coordinates and storage seams. No per-tick input depends on timing.
int main(int argc, char** argv) {
    using namespace cybersand;
    try {
        if (argc != 5) throw std::invalid_argument("layout seed workers ticks");
        const std::string layout = argv[1];
        const int seed = std::stoi(argv[2]), workers = std::stoi(argv[3]), ticks = std::stoi(argv[4]);
        if (seed < 0 || seed > 4 || ticks < 1 || ticks > 7200) throw std::invalid_argument("bounds");
        WorldConfig c;
        c.worker_threads = workers; c.parallel_job_threshold = 1;
        c.active_core_capacity = 512; c.maximum_chunk_count = 64; c.active_chunk_capacity = 64;
        c.physics_diagnostics.enabled = true;
        World w(c);
        const int ox = -130 + seed * 63, oy = -66 + seed * 31;
        w.reserve_region({ox-128,oy-128,512,512});
        w.set_simulation_region(RectI64{ox-2,oy-2,164,164});
        auto rect = [&](int x,int y,int width,int height,Material m) {
            for(int j=y;j<y+height;++j) for(int i=x;i<x+width;++i) w.set(ox+i,oy+j,m);
        };
        rect(0,0,160,1,Material::Wall); rect(0,159,160,1,Material::Wall);
        rect(0,0,1,160,Material::Wall); rect(159,0,1,160,Material::Wall);
        if(layout=="packed") {
            rect(63,1,1,158,Material::Wall);rect(96,1,1,158,Material::Wall);
            rect(64,127,32,32,Material::Sand);rect(64,111,32,16,Material::Mercury);
        } else if(layout=="poured") {
            rect(35,5,18,70,Material::Sand);
            for(int i=0;i<90;++i) rect(10+i,100+i/3,1,3,Material::Wall);
        } else if(layout=="powder") {
            rect(55,5,20,70,Material::Sand);rect(75,5,20,70,Material::Dust);
            for(int i=0;i<45;++i) rect(40+i,110+i/3,1,3,Material::Wall);
        } else if(layout=="erosion" || layout=="loose" || layout=="film") {
            rect(5,5,35,90,Material::Water);rect(40,5,2,91,Material::Wall);
            for(int i=0;i<110;++i) rect(3+i,108+i/4,1,51-i/4,Material::Sand);
            if(layout=="loose") for(int i=45;i<130;i+=2) rect(i,103,1,1,Material::Sand);
            if(layout=="film") {
                rect(5,5,35,90,Material::Empty);
                for(int i=4;i<112;++i) (void)w.set_cell_state(ox+i,oy+107+i/4,Material::Water,32,0);
            }
        } else throw std::invalid_argument("layout");
        std::vector<double> times;
        std::uint64_t visited=0, active=0, moves=0, allocations=0, late=0;
        auto sample = [&](int tick) {
            std::array<std::uint64_t,81> counts{};
            std::uint64_t water=0, contacts=0, deposited=0, eroded=0;
            int front=0;
            for(int y=0;y<160;++y) for(int x=0;x<160;++x) {
                auto m=w.stored_material(ox+x,oy+y);++counts[static_cast<unsigned>(m)];
                if(m==Material::Water)water+=w.stored_state_a(ox+x,oy+y);
                if(m==Material::Mercury)front=std::max(front,y-127+1);
                if(m==Material::Sand) {
                    if(w.stored_material(ox+x+1,oy+y)==Material::Dust)++contacts;
                    if(w.stored_material(ox+x,oy+y+1)==Material::Dust)++contacts;
                    if(x>115)++deposited;
                }
                if((layout=="erosion"||layout=="loose") && x>=3 && x<113 && y>=108+(x-3)/4 && m!=Material::Sand)++eroded;
            }
            std::cout<<"{\"tick\":"<<tick<<",\"content\":\""<<std::hex<<w.content_hash()<<std::dec
                <<"\",\"water\":"<<water<<",\"interface_contacts\":"<<contacts<<",\"deposited\":"<<deposited
                <<",\"eroded_sites\":"<<eroded<<",\"front\":"<<front<<",\"counts\":[";
            for(int i=0;i<81;++i)std::cout<<(i?",":"")<<counts[i];
            std::cout<<"]}\n";
        };
        sample(0);
        for(int tick=1;tick<=ticks;++tick) {
            if(layout=="poured" && tick==300) rect(55,5,18,60,Material::Mercury);
            if((layout=="erosion"||layout=="loose") && tick==30)rect(40,87,2,9,Material::Empty);
            const auto begin=std::chrono::steady_clock::now();auto stats=w.tick();
            times.push_back(std::chrono::duration<double,std::micro>(std::chrono::steady_clock::now()-begin).count());
            visited+=stats.visited_cells;active+=stats.scheduled_cores;moves+=stats.moved_cells;
            allocations+=stats.chunk_allocations+stats.temperature_field_allocations;
            if(tick>ticks-120)late+=stats.moved_cells;
            if(tick%60==0||tick==ticks)sample(tick);
        }
        std::sort(times.begin(),times.end());
        std::cout<<"{\"result\":true,\"visited\":"<<visited<<",\"active_cores_sum\":"<<active<<",\"moves\":"<<moves
            <<",\"late_moves\":"<<late<<",\"allocations\":"<<allocations<<",\"p50_us\":"<<times[times.size()/2]
            <<",\"p95_us\":"<<times[times.size()*95/100]<<",\"max_us\":"<<times.back()<<",\"events\":[";
        bool first=true;for(auto& e:w.physics_diagnostics()->entries)if(e.key){std::cout<<(first?"":",")<<"["<<e.key<<","<<e.count<<"]";first=false;}
        std::cout<<"],\"overflow\":"<<w.physics_diagnostics()->overflow<<"}\n";
    } catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}
}
