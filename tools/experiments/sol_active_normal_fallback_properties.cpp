// SOL #418 deterministic opt-in fallback property qualification. Synthetic only.
#include "cybersand/granular_contact_response.hpp"
#include <array>
#include <cassert>
#include <cmath>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <limits>
#include <random>
#include <span>
using namespace cybersand::gcr;
#ifndef SOL_PROPERTY_CASES
#define SOL_PROPERTY_CASES 1000000
#endif
int main() {
 std::mt19937_64 rng(0x53534F4C343138ULL);
 auto U=[&](double l,double h){return std::uniform_real_distribution<double>(l,h)(rng);};
 auto I=[&](int l,int h){return std::uniform_int_distribution<int>(l,h)(rng);};
 constexpr Vec normals[]={{1,0},{-1,0},{0,1},{0,-1}};
 uint64_t n=0,fail=0,ref0=0,ref1=0,candidate_only=0,baseline_only=0, changed=0, same=0, energy_fail=0, nonfinite=0;
 double worst_positive_energy=0,worst_diff=0,max_rel_impulse=0;
 for(int scenario=0;scenario<4;++scenario) for(int k=0;k<SOL_PROPERTY_CASES/4;++k) {
  Body b{}; b.com={U(-4,4),U(-4,4)};
  b.velocity={U(-8,8),U(-8,8)};b.omega=U(-4,4);
  b.mass=std::exp(U(-5,5));b.inertia=std::exp(U(-5,7));b.mu=U(0,2);
  std::array<Bin,12> bins{};
  std::array<const Bin*,12> bp{};
  const int nc=I(1,scenario==0?4:12);
  for(int j=0;j<nc;++j){
   const auto r=U(0.001,scenario==3?100.:15.);
   const Vec p{b.com.x+U(-r,r),b.com.y+U(-r,r)};
   const Vec dir=normals[I(0,3)];
   for(int z=0,total=I(1,scenario>=2?16:3);z<total;++z) bins[j].add(p+Vec{U(-.1,.1),U(-.1,.1)},dir,b.com);
   bp[j]=&bins[j];
  }
  const std::span<const Bin* const> s(bp.data(),(std::size_t)nc);
  CompoundWorkspace x{},y{};
  const Result a=solve_compound(b,s,x,20,1,20,false),t=solve_compound(b,s,y,20,1,20,true);
  ++n;ref0+=a.passive_rejected;ref1+=t.passive_rejected;
  if(t.passive_rejected && !a.passive_rejected) ++candidate_only;
  if(a.passive_rejected && !t.passive_rejected) ++baseline_only;
  const double lim=t.energy_before+1e-6*std::max(1.,t.energy_before);
  if (!std::isfinite(t.energy_after)||!std::isfinite(t.impulse.x)||!std::isfinite(t.impulse.y)||!std::isfinite(t.torque)) {++nonfinite; if(fail<5)std::cout<<"NONFINITE "<<scenario<<"/"<<k<<"\n"; ++fail;}
  else if(t.energy_after>lim+1e-9*std::max(1.,lim)) {++energy_fail; if(fail<5)std::cout<<"ENERGY "<<scenario<<"/"<<k<<"\n"; ++fail;}
  const double diff=std::hypot(a.impulse.x-t.impulse.x,a.impulse.y-t.impulse.y)+std::abs(a.torque-t.torque);
  const double tol=1e-10*(1+std::hypot(a.impulse.x,a.impulse.y)+std::abs(a.torque));
  if(diff>tol){++changed;worst_diff=std::max(worst_diff,diff);}else ++same;
  max_rel_impulse=std::max(max_rel_impulse,std::hypot(t.impulse.x,t.impulse.y));
  worst_positive_energy=std::max(worst_positive_energy,t.energy_after-t.energy_before);
 }
 std::cout<<std::setprecision(17)<<"SOL418_PROPERTIES cases="<<n<<" baseline_rejected="<<ref0<<" candidate_rejected="<<ref1<<" candidate_only="<<candidate_only<<" baseline_only="<<baseline_only<<" changed="<<changed<<" same="<<same<<" energy_fail="<<energy_fail<<" nonfinite="<<nonfinite<<" worst_positive_energy="<<worst_positive_energy<<" worst_diff="<<worst_diff<<" max_rel_impulse="<<max_rel_impulse<<"\n";
 return fail||candidate_only?1:0;
}
