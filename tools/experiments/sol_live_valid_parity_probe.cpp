// Independent deterministic valid-Body differential for exact #429 vs #433 headers.
// Diagnostic-only: no production fixtures or solver source are changed.
#include "cybersand/granular_contact_response.hpp"
#include <array>
#include <bit>
#include <cstdint>
#include <cmath>
#include <iostream>
#include <span>
using namespace cybersand::gcr;
static std::uint64_t seed=0x76AB01E89C112D07ULL;
static std::uint64_t next() {seed ^= seed>>12;seed^=seed<<25;seed^=seed>>27;return seed*2685821657736338717ULL;}
static double uniform(double lo,double hi){return lo+(hi-lo)*static_cast<double>((next()>>11))/9007199254740992.;}
static std::uint64_t hash=0xcbf29ce484222325ULL;
static void feed(std::uint64_t x){hash^=x;hash*=1099511628211ULL;}
static void feed(double v){feed(std::bit_cast<std::uint64_t>(v));}
static void feed(Vec v){feed(v.x);feed(v.y);}
static void feed(const Result& r){
 feed(r.impulse);feed(r.normal_impulse);feed(r.tangent_impulse);feed(r.raw_impulse);
 feed(r.torque);feed(r.raw_torque);feed(r.normal);feed(r.tangent);feed(r.raw_normal);feed(r.raw_tangent);
 feed(r.capacity);feed(r.energy_before);feed(r.energy_after);feed(r.scale);feed(r.max_radius);
 feed(std::uint64_t(r.bins));feed(std::uint64_t(r.nodes));feed(std::uint64_t(r.quadrature_clamps));feed(std::uint64_t(r.updates));feed(std::uint64_t(r.normal_cap_hits));feed(std::uint64_t(r.tangent_cap_hits));feed(std::uint64_t(r.passive_rejected));
}
int main(){
 std::uint64_t rejected=0,nonfinite=0,nonpassive=0;
 constexpr unsigned cases=120000;
 for(unsigned k=0;k<cases;++k){
   Body b{};b.mass=uniform(.2,120.);b.inertia=uniform(.1,300.);b.mu=uniform(0.,1.5);
   b.com={uniform(-2,2),uniform(-2,2)};b.velocity={uniform(-6,6),uniform(-6,6)};b.omega=uniform(-3,3);
   std::array<Bin,4> bins{};std::array<const Bin*,4> ptrs{};
   for(int i=0;i<4;++i){
     const Vec p={uniform(-5,5),uniform(-5,5)};
     const double angle=uniform(-3.141592653589793,3.141592653589793);
     bins[i].add(p,{std::cos(angle),std::sin(angle)},b.com);
     if(i%3==0)bins[i].add(p+Vec{uniform(-.7,.7),uniform(-.7,.7)},{std::cos(angle),std::sin(angle)},b.com);
     ptrs[i]=&bins[i];
   }
   const int size=1+int(next()%4);
   const std::span<const Bin* const> samples(ptrs.data(),size);
   const auto policy=(k%2==0)?NormalPolicy::Original:NormalPolicy::ActiveNormal001;
   CompoundWorkspace scratch{};
   const Result r=solve_compound(b,samples,scratch,uniform(5,40),1.,20.,policy);
   feed(r);
   if(r.passive_rejected)++rejected;
   if(!std::isfinite(r.impulse.x)||!std::isfinite(r.impulse.y)||!std::isfinite(r.energy_before)||!std::isfinite(r.energy_after))++nonfinite;
   if(!r.passive_rejected && r.energy_after>r.energy_before+1e-6*std::max(1.,r.energy_before))++nonpassive;
 }
 std::cout<<"VALID_PARITY cases="<<cases<<" rejected="<<rejected<<" nonfinite="<<nonfinite<<" nonpassive="<<nonpassive<<" hash="<<std::hex<<hash<<std::dec<<"\n";
 return nonfinite||nonpassive?1:0;
}
