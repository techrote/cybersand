#include "cybersand/granular_contact_response.hpp"
#include <iostream>
#include <memory>
#include <stdexcept>
using namespace cybersand::gcr;
unsigned assertions=0;
void check(bool yes,const char* message){++assertions;if(!yes)throw std::runtime_error(message);}
bool near(double a,double b){return std::abs(a-b)<=1e-8*std::max({1.,std::abs(a),std::abs(b)});}
std::array<Bin,8> ground(unsigned count=4){
    std::array<Bin,8> bins{};
    for(unsigned i=0;i<count;++i)bins[0].add({static_cast<double>(i)-(count-1)*.5,7},{0,-1},{0,0});
    return bins;
}
int main(){try{
    auto workspace=std::make_unique<CompoundWorkspace>();auto cache=std::make_unique<RestCache>();
    auto bins=ground(32);Body b{{.01,.02},{0,0},0,1,65./3.,.78};
    for(double budget:{5.,10.,20.,40.,80.}){
        auto result=solve(b,bins,budget,1,budget);
        check(near(result.capacity,std::min(budget,64.)),"global/source capacity census");
        check(result.normal<=result.capacity+1e-8,"global capacity bound");
        check(result.tangent<=b.mu*result.normal+1e-8,"friction cone");
    }
    for(double mass:{.5,1.,2.,520.,33280.})for(double vx:{-.1,0.,.1}){
        b={{vx,1.535333333333},{0,0},0,mass,mass*65./3.,.78};
        const double scale=load_scale(mass);std::array<const Bin*,8> refs{};for(unsigned i=0;i<8;++i)refs[i]=&bins[i];
        auto plain=solve(b,bins,20*scale,scale);RestOptions none;
        auto control=solve(b,bins,20*scale,scale,20,&none);
        auto compound=solve_compound(b,refs,*workspace,20*scale,scale,20,&none);
        check(plain.impulse.x==control.impulse.x&&plain.impulse.y==control.impulse.y&&plain.torque==control.torque,"disabled-rest exact arithmetic");
        check(near(compound.impulse.x,control.impulse.x)&&near(compound.impulse.y,control.impulse.y)&&near(compound.torque,control.torque),"one geometry compound equality");
        check(control.energy_after<=control.energy_before+1e-6*std::max(1.,control.energy_before),"passive guard");
        check(control.updates==plain.updates&&none.cache==nullptr,"control work unchanged");
    }
    bins=ground();b={{.0001,.01},{0,0},0,1,65./3.,.78};
    RestOptions arrest;arrest.catch_requested=true;arrest.gravity=92.12;
    const auto caught=solve(b,bins,20,1,20,&arrest);
    check(caught.gravity_certified,"gravity wrench independently certified");
    check(caught.catch_applied,"balanced quiet patch supports residual catch");
    check(length(b.velocity+caught.impulse*(1/b.mass))<1e-8&&std::abs(b.omega+caught.torque/b.inertia)<1e-8,"catch actually arrests full residual");
    check(caught.catch_removed_energy>=0&&caught.energy_after<=caught.energy_before,"catch dissipates kinetic energy");
    check(caught.rest_scans<=4&&caught.updates<=16,"bounded certificate scans");
    auto pivot=ground(1);const auto one=solve(b,pivot,20,1,20,&arrest);
    check(!one.catch_applied&&one.catch_refusal==CatchRefusal::NoContacts,"one-node pivot cannot freeze full body");
    arrest.gravity=1000;const auto weak=solve(b,bins,20,1,20,&arrest);
    check(!weak.catch_applied&&!weak.gravity_certified,"cannot arrest when gravity support infeasible");
    arrest.gravity=92.12;b.velocity={.01,.00001};const auto glide=solve(b,bins,20,1,20,&arrest);
    check(!glide.catch_applied,"catch cannot manufacture a friction load");
    std::array<Bin,8> empty{};check(!solve(b,empty,20,1,20,&arrest).catch_applied,"no material no catch");
    b.velocity={.0001,.01};RestOptions warm{cache.get(),false,false,92.12,1./60.};
    auto cold=solve(b,bins,20,1,20,&warm);warm.warm_start=true;
    auto retained=solve(b,bins,20,1,20,&warm);
    check(cold.rest_scans==1&&retained.warm_started,"persistence stores and seeds same node loads once");
    check(retained.energy_after<=retained.energy_before+1e-6,"warmstart remains passive");
    warm.catch_requested=true;const auto together=solve(b,bins,20,1,20,&warm);
    check(together.rest_scans<=6,"combined rest work fixed six scans");
    check(solve(b,bins,20,NAN).passive_rejected&&solve(b,bins,20,1,81).passive_rejected,"invalid scaling/budget finite refusal");
    check(load_scale(33280)==4096,"mass64 leaves normalization ceiling unchanged");
    std::cout<<"GCR REST assertions="<<assertions<<" PASS\n";
}catch(const std::exception& e){std::cerr<<"GCR REST FAIL "<<e.what()<<'\n';return 1;}}
