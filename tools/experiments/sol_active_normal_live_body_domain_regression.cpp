// Red on live #429's header, green on the dependent guarded header. Copied SOL inputs only.
#include "cybersand/granular_contact_response.hpp"
#include <array>
#include <cmath>
#include <iostream>
#include <limits>
#include <span>
using namespace cybersand::gcr;

static bool zero(Vec v) { return std::isfinite(v.x) && std::isfinite(v.y) && v.x==0 && v.y==0; }
static bool clean(const Result& r) {
    return r.passive_rejected && r.scale==0 && zero(r.impulse) && zero(r.normal_impulse) && zero(r.tangent_impulse) && zero(r.raw_impulse) &&
        r.torque==0 && r.raw_torque==0 && r.normal==0 && r.tangent==0 &&
        r.energy_before==0 && r.energy_after==0 && r.capacity==0 &&
        r.bins==0 && r.nodes==0 && r.updates==0;
}
int main() {
    Bin bin{}; bin.add({0,0},{1,0},{0,0});
    const std::array<const Bin*,1> ptrs{&bin};
    const std::span<const Bin* const> nodes(ptrs.data(),ptrs.size());
    Body valid{}; valid.velocity={-1,0}; valid.mu=.3;
    int failures=0, invalid_checks=0, valid_checks=0;
    const auto check=[&](const char* name, Body state, bool should_refuse) {
        for(const auto policy : {NormalPolicy::Original,NormalPolicy::ActiveNormal001}) {
            CompoundWorkspace scratch{};
            const auto r=solve_compound(state,nodes,scratch,20,1,20,policy);
            if(should_refuse) {
                ++invalid_checks;
                if(!clean(r)) { ++failures; std::cerr<<"FAIL "<<name<<" mode="<<static_cast<int>(policy)
                    <<" rejected="<<r.passive_rejected<<" raw="<<r.raw_impulse.x<<","<<r.raw_impulse.y<<"\n"; }
            } else {
                ++valid_checks;
                if(r.passive_rejected || !std::isfinite(r.energy_after)) {
                    ++failures; std::cerr<<"VALID_FAIL "<<name<<" mode="<<static_cast<int>(policy)<<"\n";
                }
            }
        }
    };
    const double nan=std::numeric_limits<double>::quiet_NaN();
    const double inf=std::numeric_limits<double>::infinity();
    const double tiny=std::numeric_limits<double>::denorm_min();
    Body b=valid;
    check("valid",b,false);
    b=valid; b.mu=0; check("valid_frictionless",b,false);
    b=valid; b.mu=-1; check("negative_mu",b,true);
    b=valid; b.mu=nan; check("nan_mu",b,true);
    b=valid; b.mu=inf; check("infinite_mu",b,true);
    b=valid; b.mass=0; check("zero_mass",b,true);
    b=valid; b.mass=-1; check("negative_mass",b,true);
    b=valid; b.mass=inf; check("infinite_mass",b,true);
    b=valid; b.mass=tiny; check("nonrepresentable_inverse_mass",b,true);
    b=valid; b.inertia=0; check("zero_inertia",b,true);
    b=valid; b.inertia=-1; check("negative_inertia",b,true);
    b=valid; b.inertia=tiny; check("nonrepresentable_inverse_inertia",b,true);
    b=valid; b.omega=inf; check("infinite_omega",b,true);
    b=valid; b.velocity.x=nan; check("nan_velocity",b,true);
    b=valid; b.com.y=nan; check("nan_com",b,true);
    b=valid; b.velocity.x=1e250; check("nonrepresentable_energy",b,true);
    b=valid; b.mass=nan; check("nan_mass",b,true);
    std::cout<<"SOL_LIVE_BODY_DOMAIN invalid_checks="<<invalid_checks<<" valid_checks="<<valid_checks
             <<" failures="<<failures<<"\n";
    return failures?1:0;
}
