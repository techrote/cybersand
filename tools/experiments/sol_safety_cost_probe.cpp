// Response-only deterministic cost probe for exact #452 vs composed child.
// Same-host comparative microbenchmark only; not a frame-budget claim.
#include "cybersand/granular_contact_response.hpp"
#include <array>
#include <chrono>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <span>
using namespace cybersand::gcr;
int main() {
    std::array<Bin,4> bins{};
    for(int i=0;i<32;++i) {
        const double q=(i-15.5)/8.;
        bins[0].add({q,-2},{0,1},{0,0}); bins[1].add({q,2},{0,-1},{0,0});
        bins[2].add({-2,q},{1,0},{0,0}); bins[3].add({2,q},{-1,0},{0,0});
    }
    std::array<const Bin*,4> ptrs{&bins[0],&bins[1],&bins[2],&bins[3]};
    const auto span=std::span<const Bin* const>(ptrs);
    constexpr std::uint64_t calls=300000; long double checksum=0;
    const auto start=std::chrono::steady_clock::now();
    for(std::uint64_t i=0;i<calls;++i) {
        Body b{}; b.mass=10.;b.inertia=20.;b.mu=.8;b.com={0,0};
        b.velocity={-4.+static_cast<double>(i%17)*.001,-.2+static_cast<double>(i%11)*.001};
        b.omega=.5+static_cast<double>(i%7)*.0001;
        CompoundWorkspace ws{}; const auto r=solve_compound(b,span,ws,20,1,20,NormalPolicy::ActiveNormal001);
        if(r.passive_rejected) return 2;
        checksum+=r.impulse.x*3.+r.impulse.y*5.+r.torque*7.+r.energy_after*.0001;
    }
    const auto us=std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now()-start).count();
    std::cout<<std::setprecision(20)<<"SOL_SAFETY_COST calls="<<calls<<" checksum="<<checksum<<" elapsed_us="<<us<<"\n";
    return 0;
}
