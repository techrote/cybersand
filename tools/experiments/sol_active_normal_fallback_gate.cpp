// SOL #418 dependent: provenance of passivity-safe historical fallback.
// The flag is true *only* when the opt-in solver retries historical weighting.
// Synthetic value-only tests; not a World/Rapier integration test.
#include "cybersand/granular_contact_response.hpp"
#include <array>
#include <cmath>
#include <iostream>
#include <span>
#include <stdexcept>
using namespace cybersand::gcr;
namespace {
void require(bool yes,const char* message){if(!yes) throw std::runtime_error(message);}
bool eq(double x,double y){return x==y;}
}
int main(){
 try {
  Body b{};b.com={-1.4195430398533806,-2.7136736178847585};
  b.velocity={-0.58616276243848997,-3.7709171712154204};
  b.omega=0.056246956519351077;b.mass=0.17070580363413845;
  b.inertia=0.11577601712073203;b.mu=1.0654374005661249;
  Bin a{},c{};for(int k=0;k<2;++k){
   a.add({5.337703599147325,3.4500393107188909},{-1,0},b.com);
   c.add({-4.5370859607039051,1.275386235532995},{1,0},b.com);
  }
  std::array<const Bin*,2> bins{&a,&c};const std::span<const Bin* const> s{bins.data(),bins.size()};
  CompoundWorkspace old_w{},new_w{},again_w{};
  const auto old=solve_compound(b,s,old_w,20,1,20,false);
  const auto candidate=solve_compound(b,s,new_w,20,1,20,true);
  const auto repeated=solve_compound(b,s,again_w,20,1,20,true);
  require(!old.historical_fallback_used,"default response must never claim fallback");
  require(candidate.historical_fallback_used && repeated.historical_fallback_used,"registered refusal must report fallback");
  require(!candidate.passive_rejected && !old.passive_rejected,"historical response is passive");
  require(eq(old.impulse.x,candidate.impulse.x)&&eq(old.impulse.y,candidate.impulse.y)&&eq(old.torque,candidate.torque)
    &&eq(old.energy_after,candidate.energy_after),"fallback must return bit-exact historical result");
  require(eq(candidate.impulse.x,repeated.impulse.x)&&eq(candidate.torque,repeated.torque)
    &&eq(candidate.energy_after,repeated.energy_after),"fallback must be deterministic");
  Body b2{};b2.velocity={0,1};b2.mass=1;b2.inertia=1;b2.mu=0;
  Bin d{},e{};d.add({0,0},{0,-1},{0,0});e.add({0,0},{1,0},{0,0});
  std::array<const Bin*,2> support{&d,&e};CompoundWorkspace w{};
  const auto accepted=solve_compound(b2,{support.data(),support.size()},w,20,1,20,true);
  require(!accepted.historical_fallback_used && !accepted.passive_rejected && accepted.impulse.y==-1,
    "accepted normalized response must not claim fallback");
  CompoundWorkspace no_contacts{};
  std::span<const Bin* const> empty{};
  const auto zero=solve_compound(b2,empty,no_contacts,20,1,20,true);
  require(!zero.historical_fallback_used && zero.nodes==0 && zero.impulse.x==0,
    "empty response must not claim fallback");
  const auto invalid=solve_compound(b2,empty,no_contacts,20,-1,20,true);
  require(!invalid.historical_fallback_used && invalid.passive_rejected,
    "preflight refusal must not claim fallback");
  std::cout<<"SOL418_FALLBACK_PROVENANCE checks=9 failures=0 witness_after="<<candidate.energy_after<<"\n";
  return 0;
 }catch(const std::exception& ex){std::cerr<<"SOL418_FALLBACK_PROVENANCE failure: "<<ex.what()<<"\n";return 1;}
}
