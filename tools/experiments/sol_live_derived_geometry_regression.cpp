// Regression for finite copied Body/Bin values whose derived lever arms or
// angular contact velocity cannot be represented in binary64.
#include "cybersand/granular_contact_response.hpp"
#include <array>
#include <cmath>
#include <iostream>
#include <limits>
using namespace cybersand::gcr;
static bool zero(Vec v) { return std::isfinite(v.x) && std::isfinite(v.y) && v.x==0 && v.y==0; }
static bool clean(const Result& r) {
  return r.passive_rejected && r.scale==0 && zero(r.impulse) && zero(r.normal_impulse) &&
     zero(r.tangent_impulse) && zero(r.raw_impulse) && r.torque==0 && r.raw_torque==0 &&
     r.normal==0 && r.tangent==0 && r.raw_normal==0 && r.raw_tangent==0 &&
     r.energy_before==0 && r.energy_after==0 && r.capacity==0 &&
     r.bins==0 && r.nodes==0 && r.updates==0;
}
int main() {
 Body base{};base.velocity={1.,3.};base.mass=2.;base.inertia=5.;base.mu=.7;
 Bin original{};original.add({1.,1.},{0.,-1.},base.com);
 int invalid=0,controls=0,failures=0;
 auto check=[&](const char* name,Body b,Bin bin,bool invalid_case) {
   const std::array<const Bin*,1> one{&bin};
   for(auto policy:{NormalPolicy::Original,NormalPolicy::ActiveNormal001}) {
     CompoundWorkspace workspace{};
     const auto r=solve_compound(b,one,workspace,20,1,20,policy);
     if(invalid_case) {
       ++invalid;
       if(!clean(r)) {++failures;std::cerr<<"INVALID_FAIL "<<name<<" policy="<<int(policy)<<" raw="<<r.raw_impulse.x<<","<<r.raw_impulse.y<<" rejected="<<r.passive_rejected<<"\n";}
     }else{
       ++controls;
       if(r.passive_rejected || !std::isfinite(r.energy_after) ||
         !std::isfinite(r.raw_impulse.x) || !std::isfinite(r.raw_impulse.y))
       {++failures;std::cerr<<"VALID_FAIL "<<name<<" policy="<<int(policy)<<"\n";}
     }
   }
 };
 const double enormous=1e308;
 auto bin=original;auto b=base;
 b.com={enormous,0};bin.position_sum={-enormous,0};check("opposing_x_left",b,bin,true);
 b=base;bin=original;b.com={-enormous,0};bin.position_sum={enormous,0};check("opposing_x_right",b,bin,true);
 b=base;bin=original;b.com={0,enormous};bin.position_sum={0,-enormous};check("opposing_y_above",b,bin,true);
 b=base;bin=original;b.com={0,-enormous};bin.position_sum={0,enormous};check("opposing_y_below",b,bin,true);
 b=base;bin=original;b.inertia=1e-300;b.omega=1e153;bin.position_sum={enormous,0};check("angular_contact_velocity_overflow",b,bin,true);
 b=base;bin=original;check("ordinary_bin",b,bin,false);
 b=base;bin=Bin{};check("empty_bin",b,bin,false);
 std::cout<<"SOL_DERIVED_GEOMETRY invalid_checks="<<invalid<<" valid_controls="<<controls<<" failures="<<failures<<"\n";
 return failures?1:0;
}
