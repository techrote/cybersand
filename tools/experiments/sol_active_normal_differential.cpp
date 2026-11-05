// SOL bounded differential: fixed-seed synthetic axis-normal value inputs.
// The opt-in response must never introduce NEW passivity refusals vs default.
// This is not a Godot/World/Rapier qualification.
#include "cybersand/granular_contact_response.hpp"
#include <array>
#include <cmath>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <random>
#include <span>
#include <vector>
using namespace cybersand::gcr;
static bool finite(const Result& x) { return std::isfinite(x.impulse.x)&&std::isfinite(x.impulse.y)&&std::isfinite(x.torque)&&std::isfinite(x.energy_after); }
int main(){
    std::mt19937_64 rng{0x534f4c343133ULL};
    auto U=[&](double lo,double hi){return std::uniform_real_distribution<double>(lo,hi)(rng);};
    auto I=[&](int lo,int hi){return std::uniform_int_distribution<int>(lo,hi)(rng);};
    constexpr Vec normals[]={{1,0},{-1,0},{0,1},{0,-1}};
    std::size_t cases=0, baseline_refusals=0,candidate_refusals=0, baseline_only=0,candidate_only=0;
    double max_extra_energy=0, max_normal_impulse=0;
    for(int k=0;k<300000;++k){
        std::array<Bin,8> bins{};
        std::array<const Bin*,8> ptrs{};
        const int count=I(1,8);
        Body b{};
        b.com={U(-3,3),U(-3,3)};
        b.velocity={U(-5,5),U(-5,5)};
        b.omega=U(-2,2);
        b.mass=std::pow(10.,U(-1,1.));
        b.inertia=std::pow(10.,U(-1,2.));
        b.mu=U(0,1.5);
        for(int i=0;i<count;++i){
            Vec p{U(-7,7),U(-7,7)};
            Vec n=normals[I(0,3)];
            for(int j=0;j<I(1,3);++j) bins[i].add(p,n,b.com);
            ptrs[i]=&bins[i];
        }
        auto span=std::span<const Bin* const>{ptrs.data(),(std::size_t)count};
        CompoundWorkspace wo{},wn{};
        const auto old=solve_compound(b,span,wo,20,1,20,false);
        const auto next=solve_compound(b,span,wn,20,1,20,true);
        ++cases;
        if(old.passive_rejected) ++baseline_refusals;
        if(next.passive_rejected) ++candidate_refusals;
        if(old.passive_rejected&&!next.passive_rejected) ++baseline_only;
        if(next.passive_rejected&&!old.passive_rejected) {
            ++candidate_only;
            if(candidate_only<=8){
                std::cout << std::setprecision(17) << "NEW_REFUSAL index=" << k << " count=" << count << " vel=" << b.velocity.x << "," << b.velocity.y << " omega=" << b.omega
                          << " mass=" << b.mass << " inertia=" << b.inertia << " mu=" << b.mu << " before=" << next.energy_before
                          << " old_after=" << old.energy_after << " next_raw=" << next.raw_impulse.x << "," << next.raw_impulse.y
                          << " next_raw_torque=" << next.raw_torque << " next_actual_proposal_energy=" << kinetic(b,b.velocity+next.raw_impulse*(1./b.mass), b.omega+next.raw_torque/b.inertia) << " com="<<b.com.x<<","<<b.com.y<<"\n";
                for(int i=0;i<count;++i) std::cout << " BIN "<<i<<" count="<<bins[i].count<<" pos=" << bins[i].position_sum.x/bins[i].count << ","<<bins[i].position_sum.y/bins[i].count<<" normal="<<bins[i].normal.x<<","<<bins[i].normal.y<<"\n";
            }
        }
        if(!finite(old)||!finite(next)){std::cerr<<"NONFINITE_RESULT k="<<k<<"\n";return 2;}
        const auto limit=next.energy_before+1e-6*std::max(1.,next.energy_before);
        if(next.energy_after>limit+1e-10 || old.energy_after>limit+1e-10) { std::cerr<<"ENERGY_VIOLATION k="<<k<<"\n"; return 3;}
        const double net_length=std::hypot(next.normal_impulse.x,next.normal_impulse.y);
        if(net_length>max_normal_impulse) max_normal_impulse=net_length;
        if(!next.passive_rejected) max_extra_energy=std::max(max_extra_energy,next.energy_after-next.energy_before);
    }
    std::cout<<"SUMMARY seed=0x534f4c343133 cases="<<cases<<" baseline_refusals="<<baseline_refusals<<" candidate_refusals="<<candidate_refusals
             <<" baseline_only="<<baseline_only<<" candidate_only="<<candidate_only<<" max_extra_energy="<<std::setprecision(17)<<max_extra_energy
             <<" max_normal_impulse="<<max_normal_impulse<<"\n";
    if(candidate_only != 0 || candidate_refusals > baseline_refusals) {
        std::cerr << "SOL_ACTIVE_NORMAL_DIFFERENTIAL failure: candidate-only refusal\n";
        return 4;
    }
    return 0;
}
