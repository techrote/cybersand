#include "cybersand/world.hpp"
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <iostream>
#include <string_view>
#include <vector>
using namespace cybersand;
static double quantile(std::vector<double> v, unsigned p) {
    std::sort(v.begin(),v.end());
    return v[(static_cast<std::size_t>(p)*(v.size()-1U)+99U)/100U];
}
int main() {
    for (const auto id:{2U,135U}) {
        if(!valid_material(static_cast<std::uint16_t>(id))) continue;
        for(const bool dose:{false,true}) {
            if(id==2U&&dose) continue;
            WorldConfig config;config.chunk_size=64;config.initial_chunk_reserve=8;
            config.maximum_chunk_count=64;config.worker_threads=1;
            World world(config);
            for(int y=0;y<49;++y){world.set(0,y,Material::Wall);world.set(65,y,Material::Wall);}
            for(int x=0;x<66;++x)world.set(x,48,Material::Wall);
            for(int y=16;y<48;++y)for(int x=1;x<=64;++x)world.set(x,y,static_cast<Material>(id));
            if(dose)for(int x=1;x<=64;++x)world.set(x,15,Material::Water);
            for(int tick=0;tick<60;++tick)(void)world.tick();
            std::vector<double> ms;std::uint64_t visited=0,moved=0,max_visited=0;
            for(int tick=0;tick<300;++tick){
                const auto start=std::chrono::steady_clock::now();
                const auto stats=world.tick();
                const auto end=std::chrono::steady_clock::now();
                ms.push_back(std::chrono::duration<double,std::milli>(end-start).count());
                visited+=stats.visited_cells;moved+=stats.moved_cells;
                max_visited=std::max(max_visited,stats.visited_cells);
            }
            std::uint64_t free=0,bound=0,active=0,crust=0;
            for(int y=0;y<50;++y)for(int x=0;x<66;++x){
                const auto m=world.stored_material(x,y);
                if(m==Material::Water)free+=world.stored_state_a(x,y);
                if(static_cast<unsigned>(m)==136U||static_cast<unsigned>(m)==137U)bound+=world.stored_state_b(x,y);
                active+=static_cast<unsigned>(m)==136U;crust+=static_cast<unsigned>(m)==137U;
            }
            std::cout<<"{\"material\":"<<id<<",\"dose\":"<<(dose?"true":"false")
                <<",\"warmup\":60,\"ticks\":300,\"p50_ms\":"<<quantile(ms,50)
                <<",\"p95_ms\":"<<quantile(ms,95)<<",\"p99_ms\":"<<quantile(ms,99)
                <<",\"max_ms\":"<<*std::max_element(ms.begin(),ms.end())
                <<",\"visited\":"<<visited<<",\"max_visited\":"<<max_visited<<",\"moved\":"<<moved
                <<",\"free_water\":"<<free<<",\"bound_water\":"<<bound
                <<",\"active\":"<<active<<",\"crust\":"<<crust<<"}\n";
        }
    }
}
