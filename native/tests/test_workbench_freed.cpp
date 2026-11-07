#include "cybersand/world.hpp"
#include <cmath>
#include <iostream>
#include <stdexcept>
#include <vector>
using namespace cybersand;
using namespace cybersand::soliding;
static unsigned checks=0;
static void expect(bool ok,const char* message) {++checks;if(!ok)throw std::runtime_error(message);}
template<class F> static void refuses_serialization(F&& call) {
    bool refused=false;try{call();}catch(const std::logic_error&){refused=true;}
    expect(refused,"active custody must refuse unsupported persistence");
}
static WorldConfig config(unsigned workers) {
    WorldConfig c;c.worker_threads=workers;c.parallel_job_threshold=1;c.maximum_chunk_count=64;
    c.active_chunk_capacity=64;c.active_core_capacity=512;return c;
}
static void exercise(unsigned workers) {
    World w(config(workers));w.reserve_region({0,0,128,128});
    expect(w.solid_detachment_storage_bytes()==0,"default storage neutrality");
    expect(w.configure_workbench_solids({0,0,512,512})==SolidOutcome::Accepted,"normal canvas configure");
    const auto fill=[&](int x,int y,int width,int height,Material m) {
        for(int yy=y;yy<y+height;++yy)for(int xx=x;xx<x+width;++xx)w.set(xx,yy,m);
    };
    fill(0,72,128,4,Material::Wall);fill(50,40,4,32,Material::RedBrick);
    fill(44,27,29,13,Material::RedBrick);fill(54,40,11,4,Material::RedBrick);w.set(60,32,Material::Empty);
    expect(w.prepare_workbench_solid(51,34)==SolidOutcome::Anchored,"tree anchored by actual Wall");
    fill(50,65,4,2,Material::Empty);
    expect(w.prepare_workbench_solid(51,64)==SolidOutcome::Accepted,"cut tree discovered from cut edge");
    auto s=w.inspect_solid_detachment();
    expect(s.member_count==520 && s.shape_count==6 && s.mass==520,"actual tree full tuple geometry and mass");
    std::vector<SolidMember> members(s.member_count);expect(w.copy_solid_detachment_members(members)==members.size(),"full tuple copy");
    expect(w.acknowledge_solid_detachment({s.token,1,2,s.payload_digest,s.shape_digest,s.shape_count})==SolidOutcome::Accepted,"inactive receipt");
    expect(w.commit_solid_detachment(s.token)==SolidOutcome::Accepted,"source retirement");
    const auto committed=w.inspect_solid_detachment();
    expect(w.finalize_solid_detachment({s.token,1,2,committed.committed_terrain_revision,2})==SolidOutcome::Accepted,"exact terrain receipt");
    expect(w.archive_workbench_solid(s.token)==SolidOutcome::Accepted,"archive ownership");
    expect(w.inspect_solid_detachment().phase==SolidPhase::Idle && w.workbench_solid_count()==1,"next transaction available");
    for(const auto& m:members)expect(w.stored_material(m.x,m.y)==Material::Empty,"no duplicate native owner");
    expect(w.workbench_solid_record(0).payload_digest==s.payload_digest,"archive retains payload identity");
    refuses_serialization([&]{(void)w.physical_state_hash();});
    refuses_serialization([&]{(void)w.save_physical_state();});
    expect(w.rollback_solid_detachment(s.token)==SolidOutcome::Stale,"no active restoration");
    for(int i=1;i<8;++i) {
        fill(10+i*4,10,2,2,Material::RedBrick);
        expect(w.prepare_workbench_solid(10+i*4,10)==SolidOutcome::Accepted,"sequential disjoint cut");
        const auto p=w.inspect_solid_detachment();
        expect(p.token.sequence>s.token.sequence,"monotonic transaction sequence");
        expect(w.acknowledge_solid_detachment({p.token,1,2,p.payload_digest,p.shape_digest,p.shape_count})==SolidOutcome::Occupied,"overlapping owner refuses before source retirement");
        expect(w.inspect_solid_detachment().phase==SolidPhase::Prepared && w.stored_material(10+i*4,10)==Material::RedBrick,"overlap refusal retains source and pending payload");
        expect(w.acknowledge_solid_detachment({p.token,static_cast<std::uint16_t>(6+i),2,p.payload_digest,p.shape_digest,p.shape_count})==SolidOutcome::Accepted,"disjoint owner reservation");
        expect(w.commit_solid_detachment(p.token)==SolidOutcome::Accepted,"sequential commit");
        expect(w.finalize_solid_detachment({p.token,static_cast<std::uint16_t>(6+i),2,w.hard_surface_revision(),2})==SolidOutcome::Accepted,"sequential finalize");
        expect(w.archive_workbench_solid(p.token)==SolidOutcome::Accepted,"sequential archive");
    }
    fill(100,10,2,2,Material::RedBrick);
    expect(w.prepare_workbench_solid(100,10)==SolidOutcome::MemberCapacity,"ninth refuses before removal");
    expect(w.stored_material(100,10)==Material::RedBrick,"capacity retains source");
    expect(w.prepare_workbench_solid(100,10,16)==SolidOutcome::Accepted,"small debris remains available with eight occupied rigid slots");
    const auto debris=w.inspect_solid_detachment();
    expect(debris.granular_piece,"small representation selected before body capacity");
    expect(w.crumble_workbench_solid(debris.token)==SolidOutcome::Accepted,"native conversion with full roster");
    expect(w.finalize_workbench_crumble(debris.token,w.hard_surface_revision())==SolidOutcome::Accepted,"full-roster terrain receipt");
    expect(w.workbench_solid_count()==8 && w.workbench_debris_ledger()==std::array<std::uint64_t,4>{1,4,2,2},"no additional body slot, exact material ledger");
    expect(w.rebind_workbench_solids(99,3)==SolidOutcome::Stale,"stale epoch refused");
    expect(w.rebind_workbench_solids(2,3)==SolidOutcome::Accepted,"held explicit epoch rebind");
    w.clear();expect(w.workbench_solid_count()==0 && w.solid_detachment_storage_bytes()==0,"whole owner reset retires custody");
}
static void refusals() {
    World w(config(1));w.reserve_region({1024,1024,128,128});
    expect(w.configure_workbench_solids({0,0,2048,2048})==SolidOutcome::Accepted,"2048 actual extent");
    w.set(1100,1100,Material::RedBrick);w.set(1101,1101,Material::RedBrick);
    expect(w.prepare_workbench_solid(1100,1100)==SolidOutcome::Accepted,"diagonal is separate");
    auto s=w.inspect_solid_detachment();expect(s.member_count==1,"no diagonal bond");
    expect(w.cancel_solid_detachment(s.token)==SolidOutcome::Accepted,"precommit cancel");
    w.set(1100,1101,Material::ReinforcedConcrete);
    expect(w.prepare_workbench_solid(1100,1100)==SolidOutcome::Anchored,"Hard wall is an anchor");
    w.set(1100,1101,Material::Water);w.set(1099,1100,Material::Sand);
    expect(w.prepare_workbench_solid(1100,1100)==SolidOutcome::Accepted,"ordinary Sand/Water don't bond");
    s=w.inspect_solid_detachment();expect(w.cancel_solid_detachment(s.token)==SolidOutcome::Accepted,"cancel contact observation");
    w.set(1100,1101,Material::Wood);
    expect(w.prepare_workbench_solid(1100,1100)==SolidOutcome::Ineligible,"foreign material refusal");
    expect(w.prepare_workbench_solid(900,900)==SolidOutcome::NotResident,"unknown residency refuses");
    w.set(1100,1101,Material::Empty);w.set_temperature(1100,1100,201);
    expect(w.prepare_workbench_solid(1100,1100)==SolidOutcome::Thermal,"hot source refuses");
    w.set_temperature(1100,1100,200);
    w.configure_transient_obstacles({1024,1024,128,128});
    expect(w.set_transient_obstacle(1100,1100,1),"mask setup");
    expect(w.prepare_workbench_solid(1100,1100)==SolidOutcome::Occupied,"masked source refuses");
    w.clear_transient_obstacles();
    expect(w.queue_explosion(1120,1120,1),"pending event setup");
    expect(w.prepare_workbench_solid(1100,1100)==SolidOutcome::PendingEvent,"pending event refuses");
    World span(config(1));span.reserve_region({0,0,128,128});
    expect(span.configure_workbench_solids({0,0,512,512})==SolidOutcome::Accepted,"span fixture");
    for(int x=10;x<72;++x)span.set(x,20,Material::RedBrick);
    expect(span.prepare_workbench_solid(10,20)==SolidOutcome::Accepted,"62-cell span fits padded scope");
    expect(span.cancel_solid_detachment(span.inspect_solid_detachment().token)==SolidOutcome::Accepted,"span cancel");
    span.set(72,20,Material::RedBrick);
    expect(span.prepare_workbench_solid(10,20)==SolidOutcome::MemberCapacity,"63-cell span refuses before removal");
    expect(span.workbench_solid_discovery_work()[0]<=kSolidMembers && span.workbench_solid_discovery_work()[1]<=4*kSolidMembers,"refused work remains bounded and counted");
    span.set_simulation_region(RectI64{0,0,128,128});
    expect(span.prepare_workbench_solid(10,20)==SolidOutcome::Excluded,"unapplied region is excluded, not clearance");
}
static void brush_geometry(unsigned workers) {
    World w(config(workers));w.reserve_region({0,0,128,128});
    expect(w.configure_workbench_solids({0,0,512,512})==SolidOutcome::Accepted,"brush configure");
    for(int y=-8;y<=8;++y)for(int x=-8;x<=8;++x)
        if(x*x+y*y<=64)w.set(35+x,35+y,Material::RedBrick);
    expect(w.prepare_workbench_solid(35,35)==SolidOutcome::Accepted,"default round brush must fit");
    auto s=w.inspect_solid_detachment();
    expect(s.member_count==197 && s.shape_count==11 && s.mass==197,"exact brush cells, not AABB or splinters");
    expect(w.cancel_solid_detachment(s.token)==SolidOutcome::Accepted,"brush cancel");
    w.clear();w.reserve_region({0,0,128,128});
    expect(w.configure_workbench_solids({0,0,512,512})==SolidOutcome::Accepted,"ring configure");
    std::size_t count=0;
    for(int y=10;y<=60;++y)for(int x=10;x<=60;++x)
        if((x-35)*(x-35)+(y-35)*(y-35)>24*24){w.set(x,y,Material::RedBrick);++count;}
    expect(count==808,"ring member oracle");
    expect(w.prepare_workbench_solid(10,10)==SolidOutcome::Accepted,"64 exact proxies fit");
    s=w.inspect_solid_detachment();expect(s.member_count==808 && s.shape_count==64,"ring endpoint");
    expect(w.acknowledge_solid_detachment({s.token,1,2,s.payload_digest,s.shape_digest,s.shape_count})==SolidOutcome::Accepted,"64-proxy receipt");
    expect(w.commit_solid_detachment(s.token)==SolidOutcome::Accepted,"64-proxy source retirement");
    expect(w.finalize_solid_detachment({s.token,1,2,w.hard_surface_revision(),2})==SolidOutcome::Accepted,"64-proxy finalize");
    expect(w.archive_workbench_solid(s.token)==SolidOutcome::Accepted,"64-proxy archive");
    w.set(80,20,Material::RedBrick);
    expect(w.prepare_workbench_solid(80,20)==SolidOutcome::ShapeCapacity,"shared total 65 refuses before commit");
    expect(w.stored_material(80,20)==Material::RedBrick && w.inspect_solid_detachment().phase==SolidPhase::Idle,"shared capacity retains source and usable transaction");
    w.clear();w.reserve_region({0,0,128,128});
    expect(w.configure_workbench_solids({0,0,512,512})==SolidOutcome::Accepted,"detailed comb configure");
    for(int y=10;y<=70;++y){w.set(10,y,Material::RedBrick);w.set(13,y,Material::RedBrick);
        if(y%2==0){w.set(11,y,Material::RedBrick);w.set(14,y,Material::RedBrick);}}
    w.set(12,10,Material::RedBrick);
    expect(w.prepare_workbench_solid(10,10)==SolidOutcome::ShapeCapacity,"over-64 exact geometry refuses");
    expect(w.stored_material(10,10)==Material::RedBrick,"no geometry fallback or source retirement");
}
#include "workbench_small_debris_cases.inc"
#include "workbench_rectangle_core_cases.inc"
int main() {try{exercise(1);exercise(4);refusals();brush_geometry(1);brush_geometry(4);small_debris(1);small_debris(4);rectangle_core(1);rectangle_core(4);std::cout<<"workbench freed native: "<<checks<<" checks passed\n";return 0;}
catch(const std::exception& e){std::cerr<<"FAIL "<<checks<<": "<<e.what()<<'\n';return 1;}}
