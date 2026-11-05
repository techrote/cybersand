// SOL-DIAG-001: source-pinned value-only feasibility discriminator.
// Experimental two-solve per-face closing envelope, never a production policy.
// Does not claim World/Rapier motion, displacement or material ownership safety.
#include "cybersand/granular_contact_response.hpp"
#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <span>
using namespace cybersand::gcr;
namespace {
constexpr std::array<Vec,4> inward={{{0,1},{0,-1},{1,0},{-1,0}}};
constexpr std::array<Vec,4> centers={{{0,-2},{0,2},{-2,0},{2,0}}};
struct Score { std::array<double,4> face{}; double sum=0, mx=0, energy=0; };
struct Counters {
 uint64_t cases=0, act_better_sum=0, act_worse_sum=0, act_tied_sum=0;
 uint64_t act_worse_any_face=0, act_better_all_faces=0, act_lower_energy=0;
 uint64_t envelope_use_active=0, envelope_keep_original=0, envelope_improved_sum=0;
 uint64_t original_refusals=0, active_refusals=0, invalid=0;
 double total_original_sum=0, total_active_sum=0, total_selected_sum=0;
 double worst_active_face_increase=0, worst_selected_face_increase=0;
};
std::array<Bin,4> bins_for(int mask,int bottom,int top){
 std::array<Bin,4> bins{};
 for(int f=0;f<4;++f){
  if(!(mask&(1<<f)))continue;
  const int n=f==0?bottom:f==1?top:2;
  const Vec normal=inward[f],tangent{-normal.y,normal.x};
  for(int i=0;i<n;++i){
   const double offset=n==1?0.:(static_cast<double>(i)-(n-1.)/2.)*1.5/(n-1.);
   bins[f].add(centers[f]+tangent*offset,normal,Vec{});
  }
 }
 return bins;
}
Score score(const Body& b,const Result& r,const std::array<Bin,4>& bins){
 const Vec v=b.velocity+r.impulse*(1./b.mass);
 const double w=b.omega+r.torque/b.inertia;
 Score s; s.energy=kinetic(b,v,w);
 for(int f=0;f<4;++f){
  const Bin& bin=bins[f]; if(!bin.count)continue;
  const Vec x=bin.position_sum*(1./bin.count)-b.com;
  const Vec velocity=v+Vec{-w*x.y,w*x.x};
  s.face[f]=std::max(0.,-dot(velocity,bin.normal));
  s.sum+=s.face[f];s.mx=std::max(s.mx,s.face[f]);
 }
 return s;
}
bool good(const Body& b,const Result& r,const Score& s){
 const double start=kinetic(b,b.velocity,b.omega);
 return !r.passive_rejected && std::isfinite(r.impulse.x)&&std::isfinite(r.impulse.y)
  && std::isfinite(r.torque) && std::isfinite(s.energy) && std::isfinite(s.sum)
  && std::isfinite(s.mx) && std::isfinite(r.energy_before) && std::isfinite(r.energy_after)
  && s.energy<=start+1e-6*std::max(1.,start)+1e-9
  && std::abs(s.energy-r.energy_after)<=1e-8*std::max(1.,start);
}
void account(Counters& c,const Body& body,const std::array<Bin,4>& bins,
             const Result& original,const Result& active,bool verbose=false){
 const Score a=score(body,original,bins),b=score(body,active,bins);
 ++c.cases;
 if(original.passive_rejected) ++c.original_refusals;
 if(active.passive_rejected) ++c.active_refusals;
 if(!good(body,original,a)||!good(body,active,b)) {++c.invalid;return;}
 bool face_regression=false,face_improvement=false;
 for(int f=0;f<4;++f){
  const double diff=b.face[f]-a.face[f];
  c.worst_active_face_increase=std::max(c.worst_active_face_increase,diff);
  if(diff>1e-8)face_regression=true;
  if(diff<-1e-8)face_improvement=true;
 }
 if(face_regression) ++c.act_worse_any_face;
 if(face_improvement&&!face_regression) ++c.act_better_all_faces;
 if(b.energy<a.energy-1e-8) ++c.act_lower_energy;
 if(b.sum>a.sum+1e-8)++c.act_worse_sum;
 else if(b.sum<a.sum-1e-8)++c.act_better_sum;
 else ++c.act_tied_sum;
 // Refuse to accept active-normal when ANY recorded face's residual approach
 // is greater. Also require an actual face improvement to avoid needless switch.
 // This is a post-hoc, expensive *diagnostic envelope*, not a proposed native
 // handoff: bin centroids are an incomplete geometric proxy, and both solves
 // may share upstream work or race state when integrated into the real engine.
 const bool choose_active=!face_regression&&face_improvement;
 const Score& selected=choose_active?b:a;
 if(choose_active){++c.envelope_use_active;if(selected.sum<a.sum-1e-8)++c.envelope_improved_sum;}
 else ++c.envelope_keep_original;
 c.total_original_sum+=a.sum;c.total_active_sum+=b.sum;c.total_selected_sum+=selected.sum;
 for(int f=0;f<4;++f)c.worst_selected_face_increase=std::max(c.worst_selected_face_increase,selected.face[f]-a.face[f]);
 if(verbose){
  std::cout<<"witness original_sum="<<a.sum<<" active_sum="<<b.sum
     <<" chosen_sum="<<selected.sum<<" candidate_energy="<<b.energy
     <<" base_energy="<<a.energy<<" chose_active="<<choose_active<<'\n';
  for(int f=0;f<4;++f)if(bins[f].count)std::cout<<"witness face="<<f
    <<" original="<<a.face[f]<<" active="<<b.face[f]<<" selected="<<selected.face[f]<<'\n';
 }
}
}
int main(){
 std::cout<<std::setprecision(17);
 std::cout<<"SOL_CONSERVATIVE_FACE_ENVELOPE experimental_only=1 face_centroid_metric=1\n";
 Counters counts;
 {
  const Body body{{-4,-.2},{0,0},.5,10,20,.8};
  const auto bins=bins_for(11,8,2);
  std::array<const Bin*,3> ptrs{&bins[0],&bins[1],&bins[3]};
  CompoundWorkspace wo{},wa{};
  const auto span=std::span<const Bin* const>(ptrs);
  account(counts,body,bins,solve_compound(body,span,wo,20,1,20,NormalPolicy::Original),
      solve_compound(body,span,wa,20,1,20,NormalPolicy::ActiveNormal001),true);
 }
 // Keep witness out of population statistics.
 counts=Counters{};
 const auto begin=std::chrono::steady_clock::now();
 for(double vx:{-4.,-2.,-1.,-.2,0.,.2,1.,2.,4.})
 for(double vy:{-4.,-2.,-1.,-.2,0.,.2,1.,2.,4.})
 for(double omega:{-2.,-.5,0.,.5,2.})
 for(double mu:{0.,.3,.8})
 for(int mask=3;mask<16;++mask)
 for(int n0:{1,2,4,8})
 for(int n1:{1,2,4,8}){
  const Body body{{vx,vy},{0,0},omega,10,20,mu};
  const auto bins=bins_for(mask,n0,n1);
  std::array<const Bin*,4> ptrs{};size_t n=0;
  for(int f=0;f<4;++f)if(bins[f].count)ptrs[n++]=&bins[f];
  const auto span=std::span<const Bin* const>(ptrs.data(),n);
  CompoundWorkspace wo{},wa{};
  const Result original=solve_compound(body,span,wo,20,1,20,NormalPolicy::Original);
  const Result active=solve_compound(body,span,wa,20,1,20,NormalPolicy::ActiveNormal001);
  account(counts,body,bins,original,active);
 }
 const double ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-begin).count();
 std::cout<<"cases="<<counts.cases<<" improved_sum="<<counts.act_better_sum
   <<" worsened_sum="<<counts.act_worse_sum<<" tied_sum="<<counts.act_tied_sum
   <<" active_worsens_any_face="<<counts.act_worse_any_face
   <<" active_improves_some_no_face_worse="<<counts.act_better_all_faces<<'\n';
 std::cout<<"envelope_use_active="<<counts.envelope_use_active
  <<" envelope_keep_original="<<counts.envelope_keep_original
  <<" envelope_improves_sum="<<counts.envelope_improved_sum<<'\n';
 std::cout<<"aggregate_closing_orig="<<counts.total_original_sum
  <<" aggregate_closing_active="<<counts.total_active_sum
  <<" aggregate_closing_selected="<<counts.total_selected_sum<<'\n';
 std::cout<<"active_lower_energy="<<counts.act_lower_energy
  <<" worst_active_face_increase="<<counts.worst_active_face_increase
  <<" worst_selected_face_increase="<<counts.worst_selected_face_increase<<'\n';
 std::cout<<"original_refusals="<<counts.original_refusals
  <<" active_refusals="<<counts.active_refusals
  <<" invariant_failures="<<counts.invalid
  <<" elapsed_includes_two_solves_ms="<<ms<<'\n';
 const bool ok=counts.cases==252720 && counts.act_better_sum==53802
  && counts.act_worse_sum==22096 && counts.act_tied_sum==176822
  && counts.envelope_use_active>0 && counts.envelope_use_active<counts.act_better_sum
  && counts.worst_selected_face_increase<=1e-8
  && counts.total_selected_sum<=counts.total_original_sum+1e-6
  && counts.invalid==0 && counts.original_refusals==0 && counts.active_refusals==0;
 std::cout<<(ok?"PASS":"FAIL")<<" signed_source_value_only_envelope\n";
 return ok?0:1;
}
