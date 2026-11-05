#include "cybersand/world.hpp"
#include <iostream>
#include <stdexcept>

namespace cybersand {
// A deliberately isolated attempted-contact probe following real transport.
// Advancing this test clock is not a live body/scheduler execution claim.
class PrecisionProbe {
public:
    static void attempted_contact(World& world,Material material,int dx,int dy) {
        world.tick_index_=2;
        world.record_transient_contact(1,material,dx,dy,10,10);
    }
};
}
int main() {
    using namespace cybersand;
    int checks=0;
    try {
        for(unsigned workers:{1U,4U}) for(auto material:{Material::Sand,Material::Dust}) {
            for(bool diagonal:{false,true}) {
                WorldConfig config;config.worker_threads=workers;
                World world(config);
                world.configure_transient_obstacles({0,0,32,32});
                world.enable_granular_arrival_witness(true);world.enable_transient_granular_wrenches(true);
                world.set(10,9,material);(void)world.tick();
                ++checks;if(world.stored_material(10,10)!=material)throw std::runtime_error("actual fall absent");
                PrecisionProbe::attempted_contact(world,material,diagonal?1:0,1);
                const auto x=world.transient_arrival_impulse_x(1),y=world.transient_arrival_impulse_y(1);
                ++checks;if(world.transient_arrival_count(1)!=1)throw std::runtime_error("prior aligned witness absent");
                ++checks;if(y<=0 || x!=(diagonal?y:0))throw std::runtime_error("attempt-direction arithmetic changed");
                const auto first=world.transient_arrival_count(1);
                PrecisionProbe::attempted_contact(world,material,1,1);
                ++checks;if(world.transient_arrival_count(1)!=first)throw std::runtime_error("witness consumed twice");
                std::cout<<"{\"workers\":"<<workers<<",\"material\":"<<int(material)
                    <<",\"actual_transport\":[0,1],\"attempt\":["<<(diagonal?1:0)<<",1],\"Jraw\":["
                    <<x<<','<<y<<"],\"moment2\":"<<world.transient_arrival_moment2(1)<<"}\n";
            }
        }
        std::cout<<"LA_ARRIVAL_DIRECTION checks="<<checks<<" failures=0\n";
    } catch(const std::exception& error) {std::cerr<<error.what()<<'\n';return 1;}
}
