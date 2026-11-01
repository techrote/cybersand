#include "cybersand/world.hpp"
#include <array>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>
#include <set>
#include <stdexcept>
#include <string>
#include <utility>

namespace granular_admission_tests {
using W=cybersand::World;
using M=cybersand::Material;
using R=W::GranularAdmissionRefusal;
using Point=std::pair<int,int>;
void require(bool condition,const char* message) { if(!condition) throw std::runtime_error(message); }
void bounds(const W::GranularContactAdmission& r) {
    require(r.source_candidates==1 && r.geometry_mask_checks<=24 && r.mask_checks<=31 &&
        r.path_checks<=7 && r.shared_witness_calls<=1 && r.selected_depth<=2,"A1 probe bound");
    require(r.mask_checks==r.geometry_mask_checks+r.path_checks,"A1 mask accounting");
}
W box(M material=M::Sand,std::uint8_t state=0,std::int64_t sx=0,std::int64_t sy=0,unsigned workers=1) {
    cybersand::WorldConfig config;config.worker_threads=workers;config.parallel_job_threshold=1;
    W world(config);
    for(int y=-8;y<=8;++y) for(int x=-8;x<=8;++x)
        require(world.set_cell_state(sx+x,sy+y,material,0,state),"A1 box setup");
    world.configure_transient_obstacles({sx-12,sy-12,25,25});
    return world;
}
W plane(int qx,int qy,M material,std::uint8_t state,std::int64_t sx,std::int64_t sy,unsigned workers) {
    cybersand::WorldConfig config;config.worker_threads=workers;config.parallel_job_threshold=1;
    W world(config); world.configure_transient_obstacles({sx-12,sy-12,25,25});
    for(int y=-8;y<=8;++y) for(int x=-8;x<=8;++x) {
        if(qx*x+qy*y>=0) require(world.set_cell_state(sx+x,sy+y,material,0,state),"A1 plane setup");
        else require(world.set_transient_obstacle(sx+x,sy+y,1),"A1 own mask setup");
    }
    return world;
}
// Independent closed-square slab clipping; no integer crossing/DDA code.
std::set<Point> cover(int dx,int dy) {
    std::set<Point> result;
    for(int y=std::min(0,dy);y<=std::max(0,dy);++y)
    for(int x=std::min(0,dx);x<=std::max(0,dx);++x) {
        double first=0,last=1;bool hit=true;
        const auto clip=[&](int direction,int center) {
            if(direction==0) return center==0;
            double low=(center-.5)/direction,high=(center+.5)/direction;
            if(low>high) std::swap(low,high);
            first=std::max(first,low);last=std::min(last,high);return first<=last;
        };
        hit=clip(dx,x) && clip(dy,y);
        if(hit) result.emplace(x,y);
    }
    return result;
}
std::set<Point> footprint(int x,int y) {
    std::set<Point> result;
    for(int oy=-1;oy<=2;++oy) for(int ox=-1;ox<=1;++ox) result.emplace(x+ox,y+oy);
    return result;
}
Point first_only_mask(int dx,int dy) {
    const auto path=cover(dx,dy),selected=footprint(dx,dy);
    const double extent=std::max(std::abs(dx),std::abs(dy));
    const auto first=footprint(static_cast<int>(std::round(dx/extent)),static_cast<int>(std::round(dy/extent)));
    for(const auto& p:first) if(!selected.contains(p) && !path.contains(p)) return p;
    throw std::runtime_error("A1 oracle cannot force outer witness");
}
void force_depth2(W& world,int dx,int dy,std::int64_t sx=0,std::int64_t sy=0) {
    const auto mask=first_only_mask(dx,dy);
    require(world.set_transient_obstacle(sx+mask.first,sy+mask.second,2),"A1 outer mask setup");
}
bool path_refusal(R r) {return r==R::PathNonCapable || r==R::SourceNonCapable || r==R::PathMasked || r==R::SourceMasked;}

void interfaces() {
    constexpr std::array<M,9> materials{{M::Sand,M::Stone,M::Dust,M::Seed,M::Salt,M::Sodium,M::Gunpowder,M::Coal,M::Rust}};
    constexpr std::array<Point,8> normals{{{1,0},{-1,0},{0,-1},{0,1},{1,1},{-1,1},{1,-1},{-1,-1}}};
    constexpr std::array<Point,4> translations{{{0,0},{-64,-64},{63,63},{64,64}}};
    for(const unsigned workers:{1U,4U}) for(const auto material:materials) for(const std::uint8_t state:std::array<std::uint8_t,2>{{0,1}})
    for(const auto& origin:translations) for(const auto& q:normals) {
        auto world=plane(q.first,q.second,material,state,origin.first,origin.second,workers);
        world.set_temperature(origin.first,origin.second,273);
        const auto content=world.content_hash(),full=world.state_hash();
        const auto admitted=world.granular_contact_admission_at(origin.first,origin.second,q.first,q.second);
        bounds(admitted);
        const int expected=q.second<0 ? 2:1;
        require(admitted.admitted && admitted.selected_depth==expected,"A1 half-plane depth/admission");
        require(admitted.witness_dx==expected*q.first && admitted.witness_dy==expected*q.second,"A1 half-plane witness location");
        require(admitted.path_checks==cover(admitted.witness_dx,admitted.witness_dy).size(),"A1 half-plane supercover count");
        require(admitted.shared_witness_calls==1,"A1 packing call count");
        require(world.content_hash()==content && world.state_hash()==full && world.stored_temperature(origin.first,origin.second)==273,
            "A1 query mutated material/state/temperature/hash");
        require(!world.granular_support_at(origin.first,origin.second,true,false),"A1 failed to reproduce R2 clean-side refusal");
        if(q.first==0 && q.second==1) require(world.granular_support_at(origin.first,origin.second,false,false),"A1 downward reference changed");
    }
}
void supercover_oracle() {
    for(int dy=-2;dy<=2;++dy) for(int dx=-2;dx<=2;++dx) {
        const int extent=std::max(std::abs(dx),std::abs(dy));if(!extent) continue;
        const auto path=cover(dx,dy);
        auto world=box();if(extent==2) force_depth2(world,dx,dy);
        auto result=world.granular_contact_admission_at(0,0,dx,dy);bounds(result);
        require(result.admitted && result.selected_depth==extent && result.witness_dx==dx && result.witness_dy==dy,
            "A1 all-offset geometry oracle");
        require(result.path_checks==path.size(),"A1 straight closed-square oracle count");
        for(int y=std::min(0,dy);y<=std::max(0,dy);++y) for(int x=std::min(0,dx);x<=std::max(0,dx);++x) {
            auto altered=box();if(extent==2) force_depth2(altered,dx,dy);
            altered.set(x,y,M::Empty);
            result=altered.granular_contact_admission_at(0,0,dx,dy);bounds(result);
            require(path.contains({x,y}) ? path_refusal(result.refusal_reason):!path_refusal(result.refusal_reason),
                "A1 supercover missing corner touch or spurious polyline cell");
        }
        for(const auto& cell:path) for(const auto replacement:{M::Empty,M::Wall,M::Water,M::Plant}) {
            auto altered=box();if(extent==2) force_depth2(altered,dx,dy);
            altered.set(cell.first,cell.second,replacement);
            result=altered.granular_contact_admission_at(0,0,dx,dy);bounds(result);
            require(!result.admitted && path_refusal(result.refusal_reason),"A1 crossed void/hard/liquid/Plant path");
        }
        for(const auto& cell:path) for(const std::uint16_t id:std::array<std::uint16_t,2>{{1,2}}) {
            auto altered=box();if(extent==2) force_depth2(altered,dx,dy);
            require(altered.set_transient_obstacle(cell.first,cell.second,id),"A1 path mask setup");
            result=altered.granular_contact_admission_at(0,0,dx,dy);bounds(result);
            require(!result.admitted,"A1 borrowed own/foreign masked material");
        }
    }
    require(cover(1,1).size()==4 && cover(2,2).size()==7 && cover(2,1).size()==4,"A1 oracle named count");
    // Half ties at k1 and k2, mirrored in all quadrants. Sparse masks are chosen
    // analytically in the first-only footprint to select k2 without packing search.
    for(const double ratio:{.25,.5,.75}) for(const int sx:{-1,1}) for(const int sy:{-1,1}) {
        auto world=box();const int dx=2*sx,dy=static_cast<int>(std::round(2*ratio))*sy;
        const int fx=sx,fy=static_cast<int>(std::round(ratio))*sy;
        const auto first=footprint(fx,fy),second=footprint(dx,dy),path=cover(dx,dy);
        bool placed=false;
        for(const auto& p:first) if(!second.contains(p) && !path.contains(p)) {require(world.set_transient_obstacle(p.first,p.second,2),"A1 tie mask");placed=true;break;}
        require(placed,"A1 tie oracle setup");
        const auto result=world.granular_contact_admission_at(0,0,sx,sy*ratio);bounds(result);
        require(result.admitted && result.selected_depth==2 && result.witness_dx==dx && result.witness_dy==dy,"A1 rounding tie");
    }
}
void negatives_and_selection() {
    // k1 has a packing hole outside the path, while k2 is fully packed.
    auto no_retry=box();no_retry.set(0,-1,M::Empty);
    require(no_retry.granular_support_at(2,0,true,false),"A1 no-deeper fixture k2 is packed");
    const auto rejected=no_retry.granular_contact_admission_at(0,0,1,0);bounds(rejected);
    require(!rejected.admitted && rejected.selected_depth==1 && rejected.shared_witness_calls==1 && rejected.refusal_reason==R::Packing,
        "A1 searched deeper on packing failure");
    for(const auto material:{M::Empty,M::Wall,M::Water,M::Plant}) {
        auto world=box();world.set(0,0,material);const auto r=world.granular_contact_admission_at(0,0,1,0);bounds(r);
        require(!r.admitted && r.refusal_reason==R::SourceNonCapable,"A1 non-capable source");
    }
    for(const int width:{1,2}) {
        W world;for(int y=-8;y<=8;++y) for(int x=0;x<width;++x) world.set(x,y,M::Sand);
        world.configure_transient_obstacles({-12,-12,25,25});
        for(int y=-8;y<=8;++y) require(world.set_transient_obstacle(-1,y,1),"A1 film mask");
        const auto r=world.granular_contact_admission_at(0,0,1,0);bounds(r);require(!r.admitted,"A1 thin film wall");
    }
    for(const int height:{1,2,3}) {
        W world;for(int y=1-height;y<=0;++y) for(int x=-8;x<=8;++x) world.set(x,y,M::Sand);
        world.configure_transient_obstacles({-12,-12,25,25});
        for(int x=-8;x<=8;++x) require(world.set_transient_obstacle(x,1,1),"A1 upcap mask");
        const auto r=world.granular_contact_admission_at(0,0,0,-1);bounds(r);require(!r.admitted,"A1 thin cap ceiling");
    }
    auto masks=box();require(masks.set_transient_obstacle(1,0,1),"A1 exhaustion mask1");
    require(masks.set_transient_obstacle(3,0,2),"A1 exhaustion mask2");
    const auto exhausted=masks.granular_contact_admission_at(0,0,1,0);bounds(exhausted);
    require(!exhausted.admitted && exhausted.refusal_reason==R::NoMaskFreeWitness && !exhausted.path_checks && !exhausted.shared_witness_calls,
        "A1 geometry exhaustion searched material");
    for(const double invalid:{0.,std::numeric_limits<double>::quiet_NaN(),std::numeric_limits<double>::infinity()}) {
        auto world=box();const auto r=world.granular_contact_admission_at(0,0,invalid,0);bounds(r);
        require(!r.admitted && r.refusal_reason==R::Invalid,"A1 invalid normal");
    }
    auto world=box();for(const auto edge:{std::numeric_limits<std::int64_t>::min(),std::numeric_limits<std::int64_t>::max()}) {
        const auto r=world.granular_contact_admission_at(edge,edge,1,0);bounds(r);
        require(!r.admitted && r.refusal_reason==R::Invalid,"A1 unsafe integer endpoint");
    }
}
void lifecycle_and_stability() {
    // Frozen remote region advances epoch without transporting this active bed.
    auto excluded=box();excluded.set_simulation_region(cybersand::RectI64{400,400,32,32});(void)excluded.tick();
    auto r=excluded.granular_contact_admission_at(0,0,1,0);bounds(r);
    require(!r.admitted && r.refusal_reason==R::SourceUnstable,"A1 excluded active source");
    excluded.set_simulation_region(std::nullopt);
    require(excluded.granular_contact_admission_at(0,0,1,0).admitted,"A1 fresh region reentry");
    // A real payload relocation writes the current epoch, which must not bear.
    auto moved=box();moved.set_simulation_region(cybersand::RectI64{400,400,32,32});(void)moved.tick();
    moved.set_simulation_region(std::nullopt);moved.set(0,0,M::Empty);
    require(moved.relocate_stored_cell(-1,0,0,0),"A1 real relocation setup");
    r=moved.granular_contact_admission_at(0,0,1,0);bounds(r);
    require(!r.admitted && r.refusal_reason==R::SourceUnstable,"A1 just-moved source");
    auto path=box();path.set_simulation_region(cybersand::RectI64{400,400,32,32});(void)path.tick();path.set_simulation_region(std::nullopt);
    path.set(1,0,M::Seed);r=path.granular_contact_admission_at(0,0,1,0);bounds(r);
    require(!r.admitted && r.refusal_reason==R::PathUnstable,"A1 just-transformed path");
    auto release=plane(1,0,M::Seed,0,0,0,1);require(release.granular_contact_admission_at(0,0,1,0).admitted,"A1 release positive");
    release.set(0,0,M::Plant);r=release.granular_contact_admission_at(0,0,1,0);bounds(r);
    require(!r.admitted && r.refusal_reason==R::SourceNonCapable,"A1 Seed-Plant source removal");
    release.set(0,0,M::Seed);require(release.granular_contact_admission_at(0,0,1,0).admitted,"A1 fresh rebearing");
    for(int y=-3;y<=3;++y) for(int x=0;x<=4;++x) release.set(x,y,M::Empty);
    require(!release.granular_contact_admission_at(0,0,1,0).admitted,"A1 excavation retained support");
    release.clear();require(!release.granular_contact_admission_at(0,0,1,0).admitted,"A1 reset retained witness");
    auto germination=box();require(germination.set_cell_state(0,0,M::Seed,0,1),"A1 germination setup");
    require(germination.granular_contact_admission_at(0,0,1,0).admitted,"A1 Seed pretick positive");
    (void)germination.tick();
    require(germination.stored_material(0,0)==M::Plant,"A1 actual Seed kernel did not transform");
    r=germination.granular_contact_admission_at(0,0,1,0);bounds(r);
    require(!r.admitted && r.refusal_reason==R::SourceNonCapable,"A1 actual germination retained support");
    auto reactive=box();reactive.set(0,0,M::Dust);reactive.set(-1,0,M::Lava);
    // Ordinary hot-neighbour Dust ignition is a known capable->Fire kernel
    // transition. Confine transport without masking the actual source/path.
    for(int x=-2;x<=1;++x) {reactive.set(x,1,M::Wall);reactive.set(x,-1,M::Wall);}
    require(reactive.granular_contact_admission_at(0,0,1,0).admitted,"A1 reactive pretick positive");
    (void)reactive.tick();
    require(reactive.stored_material(0,0)==M::Fire,"A1 actual hot-neighbour Dust ignition absent");
    r=reactive.granular_contact_admission_at(0,0,1,0);bounds(r);
    require(!r.admitted && r.refusal_reason==R::SourceNonCapable,"A1 actual reaction retained capable source");
    cybersand::WorldConfig config;config.active_core_capacity=1;config.active_chunk_capacity=8;
    W failed(config);failed.set(20,20,M::Sand);(void)failed.tick();failed.set(160,20,M::Sand);
    try { (void)failed.tick(); } catch(const std::runtime_error&) {}
    require(failed.has_failed(),"A1 failed World fixture did not fail");
    const auto failed_hash=failed.state_hash();r=failed.granular_contact_admission_at(20,20,1,0);bounds(r);
    require(!r.admitted && r.refusal_reason==R::FailedWorld && failed.state_hash()==failed_hash,
        "A1 failed World query admitted or mutated");

}
} // namespace granular_admission_tests
