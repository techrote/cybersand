#include "cybersand/granular_contact_response.hpp"
#include <iostream>
#include <memory>
#include <stdexcept>
using namespace cybersand::gcr;
void check(bool value,const char* why){if(!value)throw std::runtime_error(why);}
bool near(double a,double b){return std::abs(a-b)<1e-8*std::max({1.,std::abs(a),std::abs(b)});}
int main(){
 try{
  auto workspace=std::make_unique<CompoundWorkspace>();
  std::array<Bin,8> bins{};
  for(int x=-5;x<5;++x)bins[x<0?0:1].add({double(x)+.5,7},{0,-1},{0,0});
  std::array<const Bin*,8> refs{};for(int i=0;i<8;++i)refs[i]=&bins[i];
  for(double mass:{.5,1.,2.,8.,520.})for(double vx:{-30.,0.,30.})for(double vy:{1.535333333,30.,90.}){
   Body body{{vx,vy},{0,0},.1,mass,mass*65./3.,.78};
   double scale=load_scale(mass);
   auto old=solve(body,bins);auto la=solve(body,bins,20*scale,scale);
   auto compound=solve_compound(body,refs,*workspace,20*scale,scale);
   check(near(la.impulse.x,compound.impulse.x)&&near(la.impulse.y,compound.impulse.y)&&near(la.torque,compound.torque),"one shape compound equality");
   check(la.energy_after<=la.energy_before+1e-6*std::max(1.,la.energy_before),"passivity");
   check(la.normal<=20*scale+1e-7&&la.tangent<=body.mu*la.normal+1e-7,"capacity and friction cone");
   check(la.updates==old.updates,"work unchanged");
   if(mass<=1)check(old.impulse.x==la.impulse.x&&old.impulse.y==la.impulse.y&&old.torque==la.torque,"barrel exact preservation");
  }
  std::array<Bin,8> empty{};Body heavy{{30,90},{0,0},0,520,70453.649,.78};
  check(solve(heavy,empty,10400,520).normal==0,"no support no response");
  std::array<Bin,8> narrow{};narrow[0].add({0,7},{0,-1},{0,0});
  auto patch=solve(heavy,narrow,10400,520);
  check(near(patch.capacity,1040),"one source remains one tenth full capacity");
  check(solve(heavy,bins,20,NAN).passive_rejected,"invalid scale refuses");
  check(load_scale(INFINITY)==0&&load_scale(-1)==0&&load_scale(1e12)==4096,"finite bounded scale");
  std::cout<<"GCR-LA math preservation/passivity/cone/work checks PASS\n";
 }catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}
}
