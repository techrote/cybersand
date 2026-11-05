// Source-bounded producer arithmetic qualification for #452's mean/extrema guard.
// Exercises actual project()->Bin::add over the live 2048-cell workbench envelope,
// plus a separately labelled copied-value +/-1e6 arithmetic stress bound.
#include "cybersand/granular_contact_response.hpp"
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <limits>
using namespace cybersand::gcr;
struct Stats { std::uint64_t additions=0, failures=0; double max_overshoot=0, max_tolerance=0, max_magnitude=0; };
static void observe(const Bin& b, Stats& s) {
    if(!b.count) return;
    const double magnitude=std::max({1.,std::abs(b.tangent_min),std::abs(b.tangent_mean),std::abs(b.tangent_max)});
    const double tolerance=8.*std::numeric_limits<double>::epsilon()*magnitude;
    const double overshoot=std::max({0.,b.tangent_min-b.tangent_mean,b.tangent_mean-b.tangent_max});
    ++s.additions; s.max_overshoot=std::max(s.max_overshoot,overshoot);
    s.max_tolerance=std::max(s.max_tolerance,tolerance); s.max_magnitude=std::max(s.max_magnitude,magnitude);
    if(!std::isfinite(b.tangent_mean)||!std::isfinite(b.tangent_min)||!std::isfinite(b.tangent_max)||
       b.tangent_mean<b.tangent_min-tolerance||b.tangent_mean>b.tangent_max+tolerance) ++s.failures;
}
int main() {
    Stats live{},copied{};
    constexpr std::array<double,4> centres{64.5,512.5,1024.5,1980.5};
    constexpr std::array<double,11> rotations{0.,.03125,.125,.25,.5,.7853981633974483,1.,1.25,1.5707963267948966,2.,3.};
    for(double cx:centres) for(double cy:centres) for(double rotation:rotations) {
        const Vec center{cx,cy},half{63.5,63.5},com{cx+31.75,cy-31.75};
        std::array<Bin,8> bins{};
        for(int k=-63;k<=63;++k) {
            const double q=static_cast<double>(k)+.5;
            for(Vec point:std::array<Vec,4>{{{cx+64.,cy+q},{cx-64.,cy+q},{cx+q,cy+64.},{cx+q,cy-64.}}}) {
                const auto p=project(center,half,rotation,point);
                bins[p.bin].add(p.point,p.inward,com); observe(bins[p.bin],live);
            }
        }
    }
    constexpr double r=.707106781186547524400844362104849039;
    const std::array<Vec,4> normals{{{1,0},{0,1},{r,r},{-r,r}}};
    for(const Vec n:normals) {
        Bin b{}; const Vec t{-n.y,n.x};
        for(int i=0;i<4096;++i) {
            const double a=(i&1)?999999.75:-999999.75;
            const double q=static_cast<double>((i%257)-128);
            b.add(t*a+n*q,n,{0,0}); observe(b,copied);
        }
    }
    std::cout<<std::setprecision(17)<<"SOL_PRODUCER_MEAN_RANGE live_additions="<<live.additions
      <<" live_max_overshoot="<<live.max_overshoot<<" live_max_tolerance="<<live.max_tolerance
      <<" live_max_magnitude="<<live.max_magnitude<<" copied_additions="<<copied.additions
      <<" copied_max_overshoot="<<copied.max_overshoot<<" copied_max_tolerance="<<copied.max_tolerance
      <<" copied_max_magnitude="<<copied.max_magnitude<<" failures="<<(live.failures+copied.failures)<<"\n";
    return (live.failures||copied.failures)?1:0;
}
