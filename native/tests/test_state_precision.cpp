#include "cybersand/world.hpp"
#include "cybersand/precision_storage.hpp"
#include <algorithm>
#include <iostream>
#include <stdexcept>
namespace cybersand {
class PrecisionProbe {
public:
    static unsigned transfer(World& w,unsigned amount) { return w.transfer_water(0,0,1,0,static_cast<std::uint16_t>(amount),nullptr); }
};
}
using namespace cybersand;
void require(bool b,const char* s){if(!b)throw std::runtime_error(s);}
int main(){try{
    for(unsigned a=0;a<=255;++a)for(unsigned b=0;b<=255;++b){
        auto c=detail::PrecisionStorage::for_material(Material::Wall);
        c.set_state_a(static_cast<std::uint16_t>(a));c.set_state_b(static_cast<std::uint8_t>(b));c.set_epoch(251);
        require(c.state_a_value()==a&&c.state_b_value()==b&&c.epoch_value()==251&&c.material_value()==Material::Wall,"byte preservation");
    }
    for(unsigned q=0;q<=precision::maximum;++q)for(unsigned d=0;d<=12;++d){
        auto c=detail::PrecisionStorage::for_material(Material::Water);c.set_epoch(253);
        c.set_state_a(static_cast<std::uint16_t>(q));c.set_state_b(static_cast<std::uint8_t>(d));
        require(c.state_a_value()==q&&c.state_b_value()==d&&c.epoch_value()==253,"mass/delay storage");
    }
    for(unsigned a=0;a<=12;++a)for(unsigned b=0;b<=12;++b){
        World w;const auto left=precision::maximum/2,right=precision::maximum/3;
        (void)w.set_cell_state(0,0,Material::Water,static_cast<std::uint16_t>(left),static_cast<std::uint8_t>(a));
        (void)w.set_cell_state(1,0,Material::Water,static_cast<std::uint16_t>(right),static_cast<std::uint8_t>(b));
        require(PrecisionProbe::transfer(w,1)==1,"merge transfer");
        require(w.stored_state_b(1,0)==std::max(a,b)&&w.liquid_mass(0,0)+w.liquid_mass(1,0)==left+right,"max merge/accounting");
        (void)PrecisionProbe::transfer(w,precision::maximum);
        require(w.get(0,0)==Material::Empty&&w.stored_state_b(0,0)==0&&w.stored_state_b(1,0)==std::max(a,b),"empty reset/repeated transfer");
    }
    for(unsigned delay=0;delay<=12;++delay){
        World w;w.set_liquid_surface_adhesion_enabled(false);
        for(int x=-2;x<=2;++x)w.set(x,1,Material::Wall);
        w.set(-2,0,Material::Wall);w.set(2,0,Material::Wall);
        (void)w.set_cell_state(0,0,Material::Water,static_cast<std::uint16_t>(precision::maximum),static_cast<std::uint8_t>(delay));
        for(unsigned t=1;t<=delay;++t){(void)w.tick();require(w.liquid_mass(0,0)==precision::maximum,"pre-decrement suppression");require(w.stored_state_b(0,0)==delay-t,"countdown");}
        (void)w.tick();require(w.liquid_mass(0,0)<precision::maximum,"expiry lateral release");
    }
    World w;(void)w.set_cell_state(-1,-1,Material::Water,static_cast<std::uint16_t>(precision::maximum),12);
    w.set_temperature(-1,-1,777);(void)w.tick();
    require(w.liquid_mass(-1,0)==precision::maximum&&w.stored_state_b(-1,0)==11&&w.temperature(-1,0)==777,"movement state transfer");
    std::cout<<"PASS storage,169 merges,countdowns0..12,movement,reset\n";
    return 0;
}catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}}
