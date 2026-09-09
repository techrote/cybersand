#include "cybersand/world.hpp"
#include "cybersand/material_rules.hpp"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <iostream>
#include <string>
#include <vector>

// Machine-readable bounded fresh-world P1/P2 harness. Arguments are recorded
// verbatim by tools/physics/run.py. Fixture seed translates coordinates, varying
// the existing coordinate/tick streams without adding a simulation RNG.
int main(int argc, char** argv) {
    using namespace cybersand;
    if (argc != 12) {
        std::cerr << "top bottom layout depth seed ticks workers variant telemetry serial width\n";
        return 2;
    }
    try {
        const auto top = static_cast<Material>(std::stoi(argv[1]));
        const auto bottom = static_cast<Material>(std::stoi(argv[2]));
        const std::string layout = argv[3], variant = argv[8];
        const int depth = std::stoi(argv[4]), seed = std::stoi(argv[5]), ticks = std::stoi(argv[6]);
        const int width = std::stoi(argv[11]);
        if (!valid_material(static_cast<std::uint8_t>(top)) || !valid_material(static_cast<std::uint8_t>(bottom)) ||
            width < 1 || width > 128 || depth < 1 || depth > 128 || seed < 0 || seed > 100 || ticks < 1 || ticks > 7200)
            throw std::invalid_argument("fixture bounds");
        WorldConfig config;
        config.active_core_capacity = 512;
        config.active_chunk_capacity = 64;
        config.maximum_chunk_count = 64;
        config.parallel_job_threshold = 1;
        config.worker_threads = static_cast<std::uint32_t>(std::stoi(argv[7]));
        config.physics_diagnostics.enabled = std::stoi(argv[9]) != 0;
        if (std::stoi(argv[10])) config.backend = SimulationBackend::SerialInPlace;
        config.physics_diagnostics.disable_powder_exchange_targets = variant == "exchange_off";
        if (variant.starts_with("viscosity_")) config.physics_diagnostics.mercury_viscosity = static_cast<std::int16_t>(std::stoi(variant.substr(10)));
        if (variant.starts_with("period_")) config.interaction_policy.mercury_exchange_period = static_cast<std::uint32_t>(std::stoi(variant.substr(7)));
        World world(config);
        const int left = 64 + seed * 3, surface = 96 + (seed * 7 % 20), floor = surface + depth;
        const int upper_height = 16;
        const int box_left = layout == "open" ? left - 16 : left;
        const int box_right = layout == "open" ? left + width + 16 : left + width;
        world.reserve_region({box_left - 128, -128, 512, 512});
        world.set_simulation_region(RectI64{box_left - 2, 0, box_right - box_left + 4, floor + 16});
        for (int y = 0; y <= floor; ++y) { world.set(box_left-1,y,Material::Wall); world.set(box_right,y,Material::Wall); }
        for (int x = box_left-1; x <= box_right; ++x) { world.set(x,0,Material::Wall); world.set(x,floor,Material::Wall); }
        for (int x = left; x < left + width; ++x) {
            const int slope = layout == "slope" ? (x-left)/4 : 0;
            for (int y = surface; y < floor; ++y) {
                const bool pore = (layout == "holes" || layout == "saturated") && ((x*17+y*31+seed*13)%11 == 0);
                if (y >= surface+slope && !pore) world.set(x,y,bottom);
                else if (pore && layout == "saturated") world.set(x,y,Material::Water);
            }
            for (int y = surface-upper_height; y < surface; ++y) {
                if (layout == "granular") (void)world.set_cell_state(x,y,top,MaterialRules::descriptor(top).initial_state_a,1);
                else world.set(x,y,top);
            }
        }
        if (layout == "unsupported") {
            for (int x = left; x < left+width; ++x) for (int y = surface; y < surface+4; ++y) world.set(x,y,Material::Empty);
        }
        std::vector<double> times(static_cast<std::size_t>(ticks));
        std::uint64_t allocations=0, max_cores=0, max_chunks=0;
        int breakthrough=-1;
        auto snapshot = [&](int tick) {
            std::array<std::uint64_t,81> counts{}, sums{};
            int top_min=floor, top_max=0, bottom_min=floor, bottom_max=0;
            std::uint64_t water=0, below=0;
            for(int y=0;y<=floor+2;++y) for(int x=box_left-2;x<=box_right+2;++x) {
                const auto m=world.stored_material(x,y); const auto id=static_cast<std::size_t>(m);
                ++counts[id]; sums[id]+=static_cast<std::uint64_t>(y);
                water+=world.liquid_mass(x,y);
                if(m==top){top_min=std::min(top_min,y);top_max=std::max(top_max,y);if(y>=surface)++below;}
                if(m==bottom){bottom_min=std::min(bottom_min,y);bottom_max=std::max(bottom_max,y);}
            }
            std::cout << "{\"type\":\"sample\",\"tick\":"<<tick<<",\"hash\":\""<<std::hex<<world.state_hash()<<std::dec
                <<"\",\"top_front\":"<<top_max-surface+1<<",\"top_below\":"<<below
                <<",\"interface_width\":"<<std::max(0,std::min(top_max,bottom_max)-std::max(top_min,bottom_min)+1)
                <<",\"water_mass\":"<<water<<",\"active_chunks\":"<<world.active_chunk_count()<<",\"counts\":[";
            for(std::size_t i=0;i<81;++i)std::cout<<(i?",":"")<<counts[i];
            std::cout<<"],\"sum_y\":[";for(std::size_t i=0;i<81;++i)std::cout<<(i?",":"")<<sums[i];
            std::cout<<"]}\n";
        };
        snapshot(0);
        for(int tick=1;tick<=ticks;++tick){
            if(layout=="reentry" && tick==120)world.set_simulation_region(RectI64{768,768,64,64});
            if(layout=="reentry" && tick==600)world.set_simulation_region(RectI64{box_left-2,0,box_right-box_left+4,floor+16});
            if(layout=="excavate" && tick==600)for(int x=left+width/2-4;x<left+width/2+4;++x)world.set(x,floor,Material::Empty);
            const auto start=std::chrono::steady_clock::now();const auto stats=world.tick();
            times[static_cast<std::size_t>(tick-1)]=std::chrono::duration<double,std::micro>(std::chrono::steady_clock::now()-start).count();
            allocations+=stats.chunk_allocations;max_cores=std::max(max_cores,stats.scheduled_cores);
            max_chunks=std::max(max_chunks,static_cast<std::uint64_t>(world.chunk_count()));
            if(breakthrough<0)for(int x=left;x<left+width;++x)if(world.stored_material(x,floor-1)==top){breakthrough=tick;break;}
            if(tick%60==0||tick==ticks)snapshot(tick);
        }
        std::sort(times.begin(),times.end());
        std::cout<<"{\"type\":\"result\",\"completed_ticks\":"<<world.completed_tick_index()<<",\"breakthrough_tick\":"<<breakthrough
            <<",\"surface_y\":"<<surface<<",\"floor_y\":"<<floor<<",\"left_x\":"<<left
            <<",\"tick_us_p50\":"<<times[times.size()/2]<<",\"tick_us_p95\":"<<times[times.size()*95/100]<<",\"tick_us_max\":"<<times.back()
            <<",\"chunk_allocations\":"<<allocations<<",\"max_cores\":"<<max_cores<<",\"max_chunks\":"<<max_chunks;
        if(const auto* d=world.physics_diagnostics()){
            std::cout<<",\"overflow\":"<<d->overflow<<",\"histogram_used\":"<<d->used<<",\"histogram\":[";
            bool first=true;for(const auto& entry:d->entries)if(entry.key){std::cout<<(first?"":",")<<"["<<entry.key<<","<<entry.count<<"]";first=false;}
            std::cout<<"]";
        }
        std::cout<<"}\n";
    }catch(const std::exception& error){std::cerr<<error.what()<<'\n';return 1;}
}
