#include "cybersand/world.hpp"
#include <algorithm>
#include <chrono>
#include <iostream>
#include <numeric>
#include <vector>

// Closed flat basins, fixed ticks: measure fronts and leveling independently
// from rendering or wall-clock simulation pacing.
int main(int argc,char** argv) {
    using namespace cybersand;
    if(argc!=5)return 2;
    const int width=std::stoi(argv[1]),shift=std::stoi(argv[2]),workers=std::stoi(argv[3]),mirror=std::stoi(argv[4]);
    WorldConfig c;c.worker_threads=workers;c.parallel_job_threshold=1;
    c.maximum_chunk_count=64;c.active_chunk_capacity=64;c.active_core_capacity=512;
    World w(c);w.reserve_region({shift-128,shift-128,512,512});
    auto put=[&](int x,int y,Material m){w.set(shift+x,shift+y,m);};
    for(int x=0;x<=width+1;++x){put(x,0,Material::Wall);put(x,47,Material::Wall);}
    for(int y=0;y<48;++y){put(0,y,Material::Wall);put(width+1,y,Material::Wall);}
    for(int x=1;x<=12;++x)for(int y=15;y<=46;++y)put(mirror ? width+1-x:x,y,Material::Water);
    std::vector<double> times;std::uint64_t visited=0,blocks=0,allocations=0;
    int arrival=0,level=0;
    for(int tick=0;tick<=1800;++tick){
        if(tick){const auto start=std::chrono::steady_clock::now();auto s=w.tick();
            times.push_back(std::chrono::duration<double,std::micro>(std::chrono::steady_clock::now()-start).count());
            visited+=s.visited_cells;blocks+=s.active_blocks_after;allocations+=s.chunk_allocations+s.temperature_field_allocations;}
        std::vector<std::uint64_t> columns(width,0);
        for(int x=1;x<=width;++x)for(int y=1;y<47;++y)columns[x-1]+=w.liquid_mass(shift+x,shift+y);
        const auto mass=std::accumulate(columns.begin(),columns.end(),std::uint64_t{0});
        if(mass!=12U*32U*255U)return 3;
        const auto spread=*std::max_element(columns.begin(),columns.end())-*std::min_element(columns.begin(),columns.end());
        int front=0;for(int x=1;x<=width;++x)if(columns[(mirror ? width+1-x:x)-1]>=128)front=x;
        if(tick && !arrival && front>=width*3/4)arrival=tick;
        if(tick && !level && spread<=255)level=tick;
        if(tick==0||tick==60||tick==120||tick==300||tick==600||tick==1200||tick==1800)
            std::cout<<"{\"tick\":"<<tick<<",\"front\":"<<front<<",\"column_spread\":"<<spread<<",\"mass\":"<<mass<<",\"content\":\""<<std::hex<<w.content_hash()<<std::dec<<"\"}\n";
    }
    const auto total=std::accumulate(times.begin(),times.end(),0.0);std::sort(times.begin(),times.end());
    std::cout<<"{\"result\":true,\"arrival_tick\":"<<arrival<<",\"one_cell_level_tick\":"<<level<<",\"visited\":"<<visited<<",\"blocks\":"<<blocks<<",\"allocations\":"<<allocations<<",\"total_us\":"<<total<<",\"p50_us\":"<<times[900]<<",\"p95_us\":"<<times[1710]<<"}\n";
}
