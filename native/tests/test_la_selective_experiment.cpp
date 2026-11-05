#include "cybersand/world.hpp"
#include <algorithm>
#include <iostream>
#include <stdexcept>

// Independent integer-wrench witness. This does not implement a response mode
// or stand in for Rapier; the companion Godot fixture exercises application.
using namespace cybersand;
static int checks = 0;
static void require(bool value, const char* message) {
    ++checks; if (!value) throw std::runtime_error(message);
}
int main() {
    try {
        for (int workers : {1,4}) for (Material material : {Material::Sand, Material::Dust, Material::Water}) {
            WorldConfig config; config.worker_threads=static_cast<unsigned>(workers);
            config.parallel_job_threshold=2;
            World world(config);
            world.configure_transient_obstacles({0,0,512,512});
            world.enable_granular_arrival_witness(true);
            world.enable_transient_granular_wrenches(true);
            // Separated active cores make participation measurable rather than
            // inferring it from the requested thread count.
            for (int y=0;y<8;++y) for(int x=0;x<8;++x)
                world.set(12+x*64,12+y*64,material);
            auto first=world.tick();
            require(world.stored_material(12,13)==material,"actual scheduled transport");
            for(int x=11;x<=13;++x) require(world.set_transient_obstacle(x,14,1),"mask");
            auto second=world.tick();
            auto arrival=world.transient_arrival_count(1);
            require(arrival==(material==Material::Water ? 0U:1U),"material-qualified arrival");
            auto impulse=world.transient_arrival_impulse_y(1);
            auto all=world.transient_granular_impulse_y(1);
            if(material!=Material::Water) require(impulse>0 && all>=impulse,"raw selected versus all-event wrench");
            std::cout<<"{\"workers\":"<<workers<<",\"material\":"<<static_cast<int>(material)
                <<",\"observed\":"<<std::max(first.worker_threads_observed,second.worker_threads_observed)
                <<",\"arrival\":"<<arrival<<",\"all_y\":"<<all<<",\"arrival_y\":"<<impulse
                <<",\"arrival_moment2\":"<<world.transient_arrival_moment2(1)
                <<",\"missing\":"<<world.transient_arrival_missing(1)
                <<",\"misaligned\":"<<world.transient_arrival_misaligned(1)
                <<",\"sidecar_bytes\":"<<world.granular_arrival_storage_bytes()<<"}\n";
            world.clear_transient_obstacles();
            for(int x=11;x<=13;++x) require(world.set_transient_obstacle(x,14,1),"repeat mask");
            (void)world.tick();
            require(world.transient_arrival_count(1)==0,"stopped contact cannot replenish provenance");
            unsigned count=0, water_quantity=0;
            for(int y=0;y<512;++y) for(int x=0;x<512;++x) if(world.stored_material(x,y)==material) {
                ++count; water_quantity+=world.stored_state_a(x,y);
            }
            require(material==Material::Water ? water_quantity==64U*255U : count==64,
                    "native granular count / Water FreeMass quantity conserved");
            world.clear(); require(world.granular_arrival_storage_bytes()==0,"reset retires history");
        }
        std::cout<<"LA_SELECTIVE_NATIVE checks="<<checks<<" failures=0\n";
    } catch(const std::exception& e) { std::cerr<<e.what()<<'\n'; return 1; }
}
