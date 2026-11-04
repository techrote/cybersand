#include "cybersand/world.hpp"
#include <cstdint>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>

namespace cybersand {
// Isolated mechanism probes supplement, rather than impersonate, scheduler runs.
class PrecisionProbe {
public:
    static void move(World& w,std::int64_t ax,std::int64_t ay,std::int64_t bx,std::int64_t by,bool swap) {
        w.tick_index_=1; w.tick_in_progress_=true;
        w.move_cell(ax,ay,bx,by,swap,nullptr);
        w.tick_in_progress_=false; w.tick_index_=2;
    }
    static void contact(World& w,Material m,std::int64_t x,std::int64_t y,std::int64_t dx,std::int64_t dy) {
        w.record_transient_contact(1,m,dx,dy,x,y);
    }
    static void exhaust(World& w) { w.tick_index_=(std::numeric_limits<std::uint64_t>::max()>>4)+1; }
    static void write(World& w,int x,int y) { (void)w.write_cell(x,y,Material::Sand,0,0,nullptr,true); }
};
}
namespace {
using namespace cybersand;
int checks=0;
void check(bool value,const char* msg) { ++checks; if(!value) throw std::runtime_error(msg); }
WorldConfig configuration(int workers) {
    WorldConfig c; c.worker_threads=static_cast<std::uint32_t>(workers); c.backend=SimulationBackend::PhasedInPlace;
    return c;
}
void mask(World& w) {
    w.clear_transient_obstacles();
    for(int x=9;x<=11;++x) check(w.set_transient_obstacle(x,11,1),"mask setup");
}
std::uint64_t quantity(const World& w,Material m) {
    std::uint64_t q=0; for(int y=0;y<32;++y) for(int x=0;x<32;++x) q+=w.stored_material(x,y)==m;
    return q;
}
void actual(int workers,bool paint,bool relocate,bool write) {
    World w(configuration(workers));
    w.configure_transient_obstacles({0,0,32,32});
    w.set(10,9,Material::Sand);
    check(w.granular_arrival_storage_bytes()==0,"ordinary construction allocates no arrival storage");
    w.enable_granular_arrival_witness(true); w.enable_transient_granular_wrenches(true);
    check(w.granular_arrival_storage_bytes()>=32U*32U*8U,"eight-byte stamps cover resident chunks");
    (void)w.tick();
    check(w.stored_material(10,10)==Material::Sand,"real scheduled native fall");
    if(paint) w.set(10,10,Material::Sand); // Deliberately identical paint.
    if(write) PrecisionProbe::write(w,10,10);
    if(relocate) {
        check(w.relocate_stored_cell(10,10,10,9),"external relocation out");
        check(w.relocate_stored_cell(10,9,10,10),"external relocation back");
    }
    mask(w); // Ordinary mask refresh must retain genuine transport provenance.
    (void)w.tick();
    check(w.transient_contact_count(1)>=3,"raw blocked alternatives retained");
    check(w.transient_arrival_count(1)==(paint||relocate||write?0U:1U),"only real unmodified arrival admitted once");
    if(!paint && !relocate && !write) {
        check(w.transient_arrival_impulse_y(1)>0 && w.transient_arrival_impulse_x(1)==0,"downward arrival wrench");
        check(w.transient_arrival_moment2(1)==21*w.transient_arrival_impulse_y(1),"source-centre torque exact");
    }
    check(quantity(w,Material::Sand)==1,"material conserved");
    mask(w); (void)w.tick();
    check(w.transient_arrival_count(1)==0,"repeated blocked contact has no renewed witness");
    bool refused=false; try { w.enable_granular_arrival_witness(false); } catch(const std::logic_error&) { refused=true; }
    check(refused,"live configuration refused");
    w.clear(); check(w.granular_arrival_storage_bytes()==0,"reset retires all history");
    w.set(10,10,Material::Sand); mask(w); (void)w.tick();
    check(w.transient_arrival_count(1)==0,"new painted grain after reset has no witness");
}
void mask_reservation() {
    World world;
    constexpr int side=256;
    world.configure_transient_obstacles({0,0,side,side},true);
    const auto capacity=world.transient_occupancy_capacity();
    check(capacity>=side*side,"workbench reserves all distinct native mask indices at setup");
    for (int y=0; y<side; ++y) for(int x=0; x<side; ++x)
        if(!world.set_transient_obstacle(x,y,1)) throw std::runtime_error("first mask writer refused");
    check(world.transient_occupancy_capacity()==capacity,"full canvas occupancy never grows reserved scratch");
    world.clear_transient_obstacles();
    check(world.transient_occupancy_capacity()==capacity,"clearing occupancy preserves reusable scratch");
}
void separated(int workers) {
    World world(configuration(workers));
    world.configure_transient_obstacles({0,0,2048,2048});
    world.set(25,40,Material::Sand);
    world.set(1920,1660,Material::Dust);
    world.enable_transient_granular_wrenches(true);
    world.enable_granular_arrival_witness(true);
    (void)world.tick();
    check(world.stored_material(25,41)==Material::Sand, "near body transported Sand");
    check(world.stored_material(1920,1661)==Material::Dust, "distant body transported Dust");
    for (int dx=-1; dx<=1; ++dx) {
        check(world.set_transient_obstacle(25+dx,42,1),"near mask");
        check(world.set_transient_obstacle(1920+dx,1662,31),"distant mask");
    }
    (void)world.tick();
    check(world.transient_arrival_count(1)==1 && world.transient_arrival_count(31)==1,
          "distinct proxies receive their own once-only transport event");
    check(world.transient_arrival_count(2)==0 && world.transient_arrival_count(32)==0,"other slots stay empty");
    check(world.transient_arrival_moment2(1)==51*world.transient_arrival_impulse_y(1) &&
          world.transient_arrival_moment2(31)==3841*world.transient_arrival_impulse_y(31),
          "source moments retain distant geometry and body identity");
    check(world.transient_arrival_impulse_y(1)!=world.transient_arrival_impulse_y(31),
          "distinct density impulses are independent");
}
void probes() {
    World w; w.configure_transient_obstacles({0,0,32,32});
    w.set(10,9,Material::Sand); w.set(10,10,Material::Salt);
    w.enable_granular_arrival_witness(true); w.enable_transient_granular_wrenches(true);
    PrecisionProbe::move(w,10,9,10,10,true);
    PrecisionProbe::contact(w,Material::Sand,10,10,0,-1);
    check(w.transient_arrival_count(1)==0 && w.transient_arrival_misaligned(1)==1,"opposing attempt refused");
    PrecisionProbe::contact(w,Material::Sand,10,10,1,0);
    check(w.transient_arrival_count(1)==0 && w.transient_arrival_misaligned(1)==2,"perpendicular attempt refused");
    PrecisionProbe::contact(w,Material::Sand,10,10,0,1);
    check(w.transient_arrival_count(1)==1,"aligned attempt retains witness after mismatch");
    PrecisionProbe::contact(w,Material::Salt,10,9,0,-1);
    check(w.transient_arrival_count(1)==2,"reverse swapped tuple has reverse transport witness");
    PrecisionProbe::contact(w,Material::Sand,10,10,1,1);
    check(w.transient_arrival_count(1)==2,"consumed source cannot charge another alternative");
    check(quantity(w,Material::Sand)==1 && quantity(w,Material::Salt)==1,"swap quantities conserved");
    PrecisionProbe::contact(w,Material::Water,10,10,0,1);
    check(w.transient_arrival_count(1)==2,"Water never enters arrival channel");
    PrecisionProbe::exhaust(w); PrecisionProbe::contact(w,Material::Sand,10,10,0,1);
    check(w.transient_granular_wrench_refused(1),"stamp tick exhaustion refuses rather than wraps");
    World disabled; disabled.set(0,0,Material::Sand); disabled.enable_granular_arrival_witness(true);
    disabled.enable_granular_arrival_witness(false);
    check(disabled.granular_arrival_storage_bytes()==0,"pre-tick disable releases storage");
}
}
int main() {
    try {
        mask_reservation();
        for(int workers:{1,4}) {
            separated(workers);
            actual(workers,false,false,false); actual(workers,true,false,false);
            actual(workers,false,true,false); actual(workers,false,false,true);
        }
        probes(); std::cout<<"GRANULAR_ARRIVALS checks="<<checks<<" failures=0\n"; return 0;
    } catch(const std::exception& e) { std::cerr<<"GRANULAR_ARRIVALS failure after "<<checks<<": "<<e.what()<<'\n'; return 1; }
}
