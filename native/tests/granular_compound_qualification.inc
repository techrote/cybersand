#include "cybersand/granular_contact_response.hpp"
#include <array>
#include <cmath>
#include <stdexcept>
#include <iostream>
#include <memory>
namespace granular_compound_tests {
using namespace cybersand::gcr;
void require(bool value,const char* message){if(!value)throw std::runtime_error(message);}
bool near(double a,double b){return std::abs(a-b)<=1e-8*std::max({1.,std::abs(a),std::abs(b)});}
struct Node {double x{},y{},nx{},ny{};};
struct Wrench {double x{},y{},torque{};};
// Independent full-node scalar implementation. No production quadrature,
// contact evaluation, Vec operations or kinetic helper calculates this oracle.
Wrench oracle(const Body& b,const Node* nodes,std::size_t count,double available=20){
    std::array<double,kCompoundNodes> normal{},tangent{},delta{};
    double vx=b.velocity.x,vy=b.velocity.y,omega=b.omega;
    const double capacity=std::min(std::clamp(available,0.,20.),2.*static_cast<double>(count));
    for(int pass=0;pass<4;++pass)for(int axis=0;axis<2;++axis){
        for(std::size_t i=0;i<count;++i){
            const auto& p=nodes[i];const double rx=p.x-b.com.x,ry=p.y-b.com.y;
            const double dx=axis ? -p.ny:p.nx,dy=axis ? p.nx:p.ny;
            const double lever=rx*dy-ry*dx;
            const double speed=(vx-omega*ry)*dx+(vy+omega*rx)*dy;
            const double change=-speed/(1/b.mass+lever*lever/b.inertia)/static_cast<double>(count);
            if(axis){const double next=std::clamp(tangent[i]+change,-b.mu*normal[i],b.mu*normal[i]);delta[i]=next-tangent[i];tangent[i]=next;}
            else {const double next=std::clamp(normal[i]+change,0.,capacity/static_cast<double>(count));delta[i]=next-normal[i];normal[i]=next;}
        }
        for(std::size_t i=0;i<count;++i){
            const auto& p=nodes[i];const double dx=axis ? -p.ny:p.nx,dy=axis ? p.nx:p.ny;
            vx+=dx*delta[i]/b.mass;vy+=dy*delta[i]/b.mass;
            omega+=((p.x-b.com.x)*dy-(p.y-b.com.y)*dx)*delta[i]/b.inertia;
        }
    }
    Wrench out;
    for(std::size_t i=0;i<count;++i){const auto& p=nodes[i];const double x=p.nx*normal[i]-p.ny*tangent[i],y=p.ny*normal[i]+p.nx*tangent[i];out.x+=x;out.y+=y;out.torque+=(p.x-b.com.x)*y-(p.y-b.com.y)*x;}
    const double before=.5*b.mass*(b.velocity.x*b.velocity.x+b.velocity.y*b.velocity.y)+.5*b.inertia*b.omega*b.omega;
    const double after_x=b.velocity.x+out.x/b.mass,after_y=b.velocity.y+out.y/b.mass,after_w=b.omega+out.torque/b.inertia;
    const double after=.5*b.mass*(after_x*after_x+after_y*after_y)+.5*b.inertia*after_w*after_w;
    if(!std::isfinite(after)||after>before+1e-6*std::max(1.,before))return {};
    return out;
}
void wrapper_equivalence(){
    auto workspace=std::make_unique<CompoundWorkspace>();
    for(const double mass:{.5,1.,520.})for(const double mu:{0.,.78,16.})for(unsigned populated=0;populated<=8;++populated){
        Body b; b.velocity={3,7};b.omega=.3;b.mass=mass;b.inertia=mass*12;b.mu=mu;b.com={.25,-.5};
        std::array<Bin,8> bins{};std::array<const Bin*,8> pointers{};
        for(std::size_t i=0;i<8;++i){pointers[i]=&bins[i];if(i>=populated)continue;
            const Vec n=i%2 ? Vec{-1,0}:Vec{0,-1},t{-n.y,n.x};const Vec center{static_cast<double>(i)-3.,2};
            bins[i].add(center-t*.25,n,b.com);bins[i].add(center+t*.25,n,b.com);
        }
        const auto original=solve(b,bins),compound=solve_compound(b,pointers,*workspace);
        require(original.impulse.x==compound.impulse.x && original.impulse.y==compound.impulse.y && original.torque==compound.torque &&
            original.capacity==compound.capacity && original.energy_after==compound.energy_after && original.nodes==compound.nodes && original.updates==compound.updates,
            "compound single-rectangle wrapper arithmetic drift");
    }
}
void full_node_oracle(){
    auto workspace=std::make_unique<CompoundWorkspace>();
    for(const bool mirror:{false,true})for(const double angle:{0.,.7853981633974483})for(const double mass:{.5,1.,520.}){
        const double c=std::cos(angle),s=std::sin(angle),sign=mirror ? -1.:1.;
        const Vec com{11,-4};
        Body b;b.com=com;b.mass=mass;b.inertia=mass*32;b.mu=.78;b.velocity={3*sign*c-7*s,3*sign*s+7*c};b.omega=.4*sign;
        std::array<Bin,48> bins{};std::array<const Bin*,48> pointers{};std::array<Node,96> nodes{};std::size_t node_count=0;
        for(std::size_t i=0;i<48;++i){
            const double px=(static_cast<double>(i%7)-2.5)*sign,py=static_cast<double>(i/7)*.5+1;
            const Vec base=com+Vec{c*px-s*py,s*px+c*py};
            const Vec original=i%4==0 ? Vec{1,0}:i%4==1 ? Vec{0,1}:i%4==2 ? Vec{-1,0}:Vec{0,-1};
            const Vec n{c*original.x*sign-s*original.y,s*original.x*sign+c*original.y},t{-n.y,n.x};
            pointers[i]=&bins[i];
            for(const double offset:{-.25,.25}){const Vec point=base+t*offset;bins[i].add(point,n,com);nodes[node_count++]={point.x,point.y,n.x,n.y};}
        }
        const auto expected=oracle(b,nodes.data(),node_count);const auto actual=solve_compound(b,pointers,*workspace);
        require(near(expected.x,actual.impulse.x)&&near(expected.y,actual.impulse.y)&&near(expected.torque,actual.torque),"compound full96-node independent oracle");
        require(actual.normal<=20+1e-10 && actual.tangent<=b.mu*actual.normal+1e-10 && actual.updates<=768,"compound common budget/work bound");
        require(actual.energy_after<=actual.energy_before+1e-6*std::max(1.,actual.energy_before),"compound passive energy injection");
    }
}
void splitting_and_capacity(){
    auto workspace=std::make_unique<CompoundWorkspace>();Body b;b.velocity={0,30};b.mass=520;b.inertia=70453.64935897436;b.mu=.78;
    std::array<Bin,1> combined{};combined[0].add({-1,1},{0,-1},{});combined[0].add({1,1},{0,-1},{});
    std::array<Bin,2> split{};split[0].add({-1,1},{0,-1},{});split[1].add({1,1},{0,-1},{});
    std::array<const Bin*,1> one{{&combined[0]}};std::array<const Bin*,2> two{{&split[0],&split[1]}};
    const auto a=solve_compound(b,one,*workspace),d=solve_compound(b,two,*workspace);
    require(a.impulse.x==d.impulse.x && a.impulse.y==d.impulse.y && a.torque==d.torque && a.capacity==d.capacity,"quadrature-equivalent proxy split changed wrench/capacity");
    std::array<Bin,kCompoundBins> full{};std::array<const Bin*,kCompoundBins> pointers{};
    for(std::size_t i=0;i<full.size();++i){pointers[i]=&full[i];full[i].add({-1,1},{0,-1},{});full[i].add({1,1},{0,-1},{});}
    const auto maximum=solve_compound(b,pointers,*workspace);
    require(maximum.nodes==1024 && maximum.updates==8192 && maximum.capacity==20 && maximum.normal<=20+1e-9,"compound maximum1024-node/one20-budget bound");
    require(b.velocity.y+maximum.impulse.y/b.mass>=b.velocity.y-20/b.mass-1e-10,"compound mass520 was silently normalized");
    const auto limited=solve_compound(b,pointers,*workspace,7),exhausted=solve_compound(b,pointers,*workspace,0);
    require(limited.capacity==7 && limited.normal<=7+1e-9 && exhausted.normal==0 && exhausted.torque==0,"compound event-first remaining capacity renewed");
    std::array<const Bin*,kCompoundBins+1> overflow{};const auto refused=solve_compound(b,overflow,*workspace);
    require(refused.passive_rejected && refused.impulse.x==0 && refused.impulse.y==0 && refused.torque==0,"compound oversized scratch input did not refuse");
    std::cout<<"compound fixed workspace bytes "<<sizeof(CompoundWorkspace)<<'\n';
}
} // namespace granular_compound_tests
