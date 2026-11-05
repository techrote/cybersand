// Exact #413 candidate regression: energy-unsafe normalized proposal must not
// suppress a historical passive response. Synthetic value-only; no World claim.
#include "cybersand/granular_contact_response.hpp"
#include <array>
#include <cmath>
#include <iostream>
#include <span>
#include <stdexcept>

using namespace cybersand::gcr;
static void demand(bool ok, const char* message) { if(!ok) throw std::runtime_error(message); }
static bool close(double a,double b) {return std::abs(a-b)<1e-12;}
int main() {
    try {
        Body b{};
        b.com={-1.4195430398533806,-2.7136736178847585};
        b.velocity={-0.58616276243848997,-3.7709171712154204};
        b.omega=0.056246956519351077;
        b.mass=0.17070580363413845;
        b.inertia=0.11577601712073203;
        b.mu=1.0654374005661249;
        Bin a{},c{};
        for(int i=0;i<2;++i) {
            a.add({5.337703599147325,3.4500393107188909},{-1,0},b.com);
            c.add({-4.5370859607039051,1.275386235532995},{1,0},b.com);
        }
        std::array<const Bin*,2> ps{&a,&c};
        auto bins=std::span<const Bin* const>{ps.data(),ps.size()};
        CompoundWorkspace w0{},w1{},w2{};
        const auto old=solve_compound(b,bins,w0,20,1,20,false);
        const auto fixed=solve_compound(b,bins,w1,20,1,20,true);
        const auto again=solve_compound(b,bins,w2,20,1,20,true);
        demand(!old.passive_rejected && !fixed.passive_rejected,"both contact responses should be passive");
        demand(close(old.impulse.x,fixed.impulse.x) && close(old.impulse.y,fixed.impulse.y) &&
               close(old.torque,fixed.torque) && close(old.energy_after,fixed.energy_after),
               "unsafe opt-in candidate must use unchanged historical response");
        demand(close(fixed.energy_after,again.energy_after) && close(fixed.torque,again.torque),
               "fallback is deterministic across fresh workspaces");
        demand(fixed.energy_after<fixed.energy_before && fixed.energy_after<=
               fixed.energy_before+1e-6*std::max(1.,fixed.energy_before),
               "fallback must dissipate and pass unmodified passivity limit");
        demand(close(fixed.energy_before,1.2432118560527596) &&
               close(fixed.energy_after,1.2235598165052963),"source-matched witness energies");
        std::cout<<"SOL_ACTIVE_NORMAL_FALLBACK checks=5 failures=0\n";
        return 0;
    } catch(const std::exception& e) {
        std::cerr <<"SOL_ACTIVE_NORMAL_FALLBACK failure: "<<e.what()<<'\n';
        return 1;
    }
}
