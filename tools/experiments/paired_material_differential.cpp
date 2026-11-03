#include "cybersand/world.hpp"
#include "cybersand/material_rules.hpp"
#include <cstdint>
#include <iostream>
#include <string_view>

// Source-neutral, read-only cell oracle. Compile the identical bytes against
// starting main and the candidate; never compare policy/catalogue hash metadata
// as if it were physical behavior. Output is bounded to eight361-sample traces.
using namespace cybersand;
static std::uint64_t fold(std::uint64_t h, std::uint64_t n) {
    for (unsigned b=0;b<8;++b) { h^=(n>>(b*8))&255U; h*=1099511628211ULL; }
    return h;
}
int main() {
    for (unsigned id=0;id<132;++id) {
        const auto m=static_cast<Material>(id); const auto& d=material_definition(m);
        std::cout<<"descriptor,"<<id<<','<<d.name<<','<<unsigned(d.state)<<','<<d.density
                 <<','<<d.movable<<','<<d.valid<<','<<d.current_rule_available<<','<<unsigned(d.kernel)
                 <<','<<unsigned(d.initial_state_a)<<','<<unsigned(d.initial_state_b)
                 <<','<<unsigned(d.maximum_write_radius)<<','<<unsigned(d.density_motion)
                 <<','<<d.accepts_density_exchange<<','<<unsigned(d.lateral_flow)<<','<<unsigned(d.viscosity_index)
                 <<','<<MaterialRules::is_hard_surface(m)<<','<<MaterialRules::supports_granular_load(m);
        for (const auto c:d.rgba) std::cout<<','<<unsigned(c);
        std::cout<<'\n';
    }
    for (const unsigned workers:{1U,4U}) {
        for (const auto agent:{Material::Empty,Material::Water,Material::Brine,Material::Concrete}) {
            WorldConfig c;c.chunk_size=64;c.worker_threads=workers;c.parallel_job_threshold=1;
            c.sleep_after_quiet_ticks=1;c.initial_chunk_reserve=8;c.maximum_chunk_count=64;
            World w(c);
            for (int y=8;y<=36;++y) { w.set(8,y,Material::Wall);w.set(72,y,Material::Wall); }
            for (int x=8;x<=72;++x) w.set(x,36,Material::Wall);
            for (int y=28;y<34;++y) for(int x=24;x<48;++x) w.set(x,y,Material::Cement);
            for (int x=24;x<48;++x) w.set(x,34,agent);
            for (int tick=0;tick<=360;++tick) {
                auto h=std::uint64_t{1469598103934665603ULL};
                unsigned cement=0,concrete=0;
                for (int y=0;y<48;++y) for(int x=0;x<80;++x) {
                    auto m=w.stored_material(x,y); cement+=m==Material::Cement;concrete+=m==Material::Concrete;
                    h=fold(h,unsigned(m));h=fold(h,w.stored_state_a(x,y));h=fold(h,w.stored_state_b(x,y));
                    h=fold(h,static_cast<std::uint16_t>(w.stored_temperature(x,y)));
                }
                std::cout<<"cement,"<<workers<<','<<unsigned(agent)<<','<<tick<<','<<h<<','<<cement<<','<<concrete<<'\n';
                if(tick<360) (void)w.tick();
            }
        }
    }
}
