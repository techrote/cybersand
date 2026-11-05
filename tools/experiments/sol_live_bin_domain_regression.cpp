// Copied granular contact-bin domain checks, independent of engine/World.
// RED on #433 (body-guarded parent); GREEN on bin-domain guarded candidate.
#include "cybersand/granular_contact_response.hpp"
#include <array>
#include <cmath>
#include <iostream>
#include <limits>
#include <span>
using namespace cybersand::gcr;

static bool zero(Vec v) {
    return std::isfinite(v.x) && std::isfinite(v.y) && v.x==0 && v.y==0;
}
static bool clean(const Result& r) {
    return r.passive_rejected && r.scale==0 && zero(r.impulse) &&
        zero(r.normal_impulse) && zero(r.tangent_impulse) && zero(r.raw_impulse) &&
        r.torque==0 && r.raw_torque==0 && r.normal==0 && r.tangent==0 &&
        r.raw_normal==0 && r.raw_tangent==0 && r.energy_before==0 &&
        r.energy_after==0 && r.capacity==0 && r.bins==0 && r.nodes==0 &&
        r.updates==0 && r.normal_cap_hits==0 && r.tangent_cap_hits==0;
}
int main() {
    Body body{};
    body.mass=2.; body.inertia=5.; body.mu=.7;
    body.velocity={0.,3.};
    Bin valid{};
    valid.add({0.,1.},{0.,-1.},body.com);
    valid.add({1.,1.},{0.,-1.},body.com);
    const double nan=std::numeric_limits<double>::quiet_NaN();
    const double inf=std::numeric_limits<double>::infinity();
    int failures=0,invalid=0,controls=0;
    auto check=[&](const char* name, Bin bin, bool refuse) {
        const std::array<const Bin*,1> ptrs{&bin};
        for(const auto policy:{NormalPolicy::Original,NormalPolicy::ActiveNormal001}) {
            CompoundWorkspace scratch{};
            const Result r=solve_compound(body,{ptrs.data(),ptrs.size()},scratch,20,1,20,policy);
            if(refuse) {
                ++invalid;
                if(!clean(r)) {
                    ++failures;
                    std::cerr<<"INVALID_FAIL "<<name<<" mode="<<static_cast<int>(policy)
                             <<" rejected="<<r.passive_rejected<<" scale="<<r.scale
                             <<" raw="<<r.raw_impulse.x<<","<<r.raw_impulse.y<<"\n";
                }
            } else {
                ++controls;
                if(r.passive_rejected || !std::isfinite(r.energy_after) ||
                   !std::isfinite(r.raw_impulse.x) || !std::isfinite(r.raw_impulse.y)) {
                    ++failures;
                    std::cerr<<"VALID_FAIL "<<name<<" mode="<<static_cast<int>(policy)<<"\n";
                }
            }
        }
    };
    Bin b=valid;
    check("valid",b,false);
    b=Bin{};check("empty_bin_ignored",b,false);
    b=valid;b.normal={.6,-.8};check("valid_unit_normal",b,false);
    b=valid;b.normal.x=nan;check("nan_normal",b,true);
    b=valid;b.normal.y=inf;check("inf_normal",b,true);
    b=valid;b.normal={0,0};check("zero_normal",b,true);
    b=valid;b.normal={0,-.5};check("nonunit_normal",b,true);
    b=valid;b.normal={1e300,1e300};check("overflow_normal_norm",b,true);
    b=valid;b.position_sum.x=nan;check("nan_position_sum",b,true);
    b=valid;b.position_sum.y=inf;check("inf_position_sum",b,true);
    b=valid;b.maximum_radius=nan;check("nan_radius",b,true);
    b=valid;b.maximum_radius=inf;check("inf_radius",b,true);
    b=valid;b.maximum_radius=-1;check("negative_radius",b,true);
    b=valid;b.tangent_mean=nan;check("nan_mean",b,true);
    b=valid;b.tangent_m2=inf;check("inf_m2",b,true);
    b=valid;b.tangent_m2=-1;check("negative_m2",b,true);
    b=valid;b.tangent_min=nan;check("nan_min",b,true);
    b=valid;b.tangent_max=inf;check("inf_max",b,true);
    b=valid;b.tangent_min=5;b.tangent_max=-5;check("reversed_bounds",b,true);
    std::cout<<"SOL_LIVE_BIN_DOMAIN invalid_checks="<<invalid<<" valid_controls="<<controls
             <<" failures="<<failures<<"\n";
    return failures?1:0;
}
