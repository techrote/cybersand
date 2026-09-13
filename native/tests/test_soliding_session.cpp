#include "cybersand/soliding_session.hpp"
#include <iostream>
#include <stdexcept>
using namespace cybersand;using namespace cybersand::soliding;
void check(bool v,const char* text){if(!v)throw std::runtime_error(text);}
namespace cybersand::soliding {
struct SessionTestAccess {
 static void failed(Session& s){s.world_.tick_failed_=true;}
 static void exhausted(Session& s){s.generation_=static_cast<std::uint64_t>(INT64_MAX);}
 static PayloadCell at(const Session& s,int x,int y){return s.world_.soliding_read(x,y);}
 static void vary(Session& s){
  for(int y=82;y<96;++y)for(int x=36;x<44;++x){(void)s.world_.set_cell_state(x,y,Material::Wall,static_cast<std::uint16_t>((x+y)%255),static_cast<std::uint8_t>(x));s.world_.set_temperature(x,y,static_cast<std::int16_t>(300+x+y));}
 }
};
}
void settle(Session& s){for(int t=0;t<310;++t)check(s.tick(),"settle");}
void promote(Session& s){check(s.prepare_promotion(),"fault prepare");auto t=s.token();check(s.acknowledge(t)&&s.commit(t),"fault commit");auto r=s.status().rectangle;check(s.occupancy({r.x+r.width*.5,r.y+r.height*.5,0,0,0,0}).complete&&s.finalize(t,true),"fault finalize");}
void motion_rest(Session& s,const Motion& m){for(unsigned t=1;t<=301;++t)check(s.observe_motion(m,t),"rest sample");}
void faults(){
 {Session s;check(s.edit(44,82,Material::Wall),"attached extension");
  for(int y=82;y<96;++y)for(int x=48;x<56;++x)check(s.edit(x,y,Material::Wall),"separate candidate");
  settle(s);check(!s.prepare_promotion()&&s.status().cell_members==225&&s.status().slot_members==0,"different candidate cannot authorize incomplete source");}

 {bool refused=false;try{Session s(32,32);}catch(const std::invalid_argument&){refused=true;}check(refused,"oversize admission");}
 {Session s;settle(s);check(s.prepare_promotion(),"reset old prepare");auto old=s.token();check(s.cancel(old),"reset cancel");Session replacement;settle(replacement);check(replacement.prepare_promotion()&&!replacement.acknowledge(old),"incarnation rejects reset ABA");}
 for(int stage=0;stage<3;++stage){Session s;settle(s);const auto hash=s.status().payload_hash;
  if(stage>0)check(s.prepare_promotion(),"failure prepared");if(stage>1)check(s.acknowledge(s.token()),"failure acknowledged");
  SessionTestAccess::failed(s);check(!s.prepare_promotion()&&!s.acknowledge(s.token())&&!s.commit(s.token())&&!s.tick(),"failed world blocks all transition");
  check(s.status().cell_members==112&&s.status().slot_members==0&&s.status().payload_hash==hash,"failed precommit owner");}
 {Session s;settle(s);SessionTestAccess::exhausted(s);check(!s.prepare_promotion()&&s.status().cell_members==112,"token saturation refuses intact");}
 {Session s;settle(s);check(s.prepare_promotion()&&s.acknowledge(s.token())&&s.commit(s.token()),"postcommit injection");check(!s.finalize(s.token(),false)&&!s.tick()&&!s.persistence_allowed()&&s.status().slot_members==112&&s.status().cell_members==0,"postcommit quarantine retains slot");}
 {Session s;check(s.edit(80,50,Material::Empty,900),"hot empty fixture");settle(s);promote(s);
  Motion hot{80,50,0,0,0,0};motion_rest(s,hot);check(!s.prepare_reversal(hot)&&s.status().slot_members==112,"hot empty refusal");
  Motion blocked{60,96,0,0,0,0};motion_rest(s,blocked);check(!s.prepare_reversal(blocked)&&s.status().slot_members==112,"blocked full destination refusal");
  Motion off{1,1,0,0,0,0};check(!s.occupancy(off).complete&&!s.tick()&&s.status().slot_members==112,"partial occupancy freezes");
  Motion m{60,89,0,0,0,0};motion_rest(s,m);check(s.prepare_reversal(m),"legal reversal after refusal");auto token=s.token();check(s.cancel(token)&&s.status().slot_members==112,"reverse cancel retains");
  check(s.prepare_reversal(m)&&s.acknowledge(s.token())&&s.commit(s.token()),"reverse commit");check(!s.finalize(s.token(),false)&&s.status().cell_members==112&&s.status().slot_members==0,"postreverse quarantine retains cells");}
 {Session s;SessionTestAccess::vary(s);settle(s);std::array<PayloadCell,112> old{};
  for(int j=0;j<14;++j)for(int i=0;i<8;++i)old[j*8+i]=SessionTestAccess::at(s,36+i,82+j);
  promote(s);for(int j=0;j<14;++j)for(int i=0;i<8;++i){auto v=SessionTestAccess::at(s,36+i,82+j);check(v.material==Material::Empty&&v.a==0&&v.b==0&&v.temperature==200,"canonical source empty");}
  Motion m{60,92,1.5707963267948966,.02,0,.001};motion_rest(s,m);check(s.prepare_reversal(m)&&s.acknowledge(s.token())&&s.commit(s.token())&&s.finalize(s.token(),true),"varied quarter turn");
  for(int j=0;j<14;++j)for(int i=0;i<8;++i){auto v=SessionTestAccess::at(s,53+13-j,88+i);auto expected=old[j*8+i];expected.x=v.x;expected.y=v.y;check(v==expected,"exact mapped tuple");}
  check(s.status().discarded_energy>0&&s.status().speed_bound<.03,"explicit residual motion bound");}
 std::cout<<"{\"fault_suite\":true,\"mapped_temperature_state\":true,\"blocked_and_hot_empty\":true,\"quarantine_both_owners\":true}\n";
}
int main(){try{faults();
for(unsigned workers:{1U,4U})for(unsigned height:{8U,14U}){
 Session s(8,height,workers);for(int t=0;t<310;++t)check(s.tick(),"initial tick");
 auto before=s.status();check(before.rest>=300,"rest");
 for(unsigned cycle=0;cycle<4;++cycle){
  check(s.prepare_promotion(),"prepare promotion");auto token=s.token(),stale=token;++stale[0];
  check(!s.acknowledge(stale)&&!s.tick()&&!s.persistence_allowed(),"stale/phase/save");
  check(s.cancel(token),"cancel");check(s.status().cell_members==8*height,"cancel owns cells");
  check(s.prepare_promotion(),"reprepare");token=s.token();check(s.acknowledge(token)&&!s.acknowledge(token),"ack exactly once");check(s.commit(token)&&!s.commit(token),"commit once");
  auto a=s.status();check(a.slot_members==8*height&&a.cell_members==0,"singular slot");
  Motion m{a.rectangle.x+a.rectangle.width*.5,a.rectangle.y+a.rectangle.height*.5,0,0,0,0};
  check(s.occupancy(m).complete&&s.finalize(token,true),"promotion topology");
  check(!s.edit(10,10,Material::Wall)&&!s.persistence_allowed(),"event/save rejection");
  check(s.set_excluded(true)&&!s.tick()&&!s.observe_motion(m,1),"exclude");check(s.set_excluded(false),"reentry");
  // Rotate 90 degrees and place exactly on the same floor, inside the fixed patch.
  m={60,96-a.rectangle.width*.5,1.5707963267948966,0,0,0};
  check(s.occupancy(m).complete,"rotated mask");
  for(unsigned t=1;t<=301;++t)check(s.observe_motion(m,t),"motion witness");
  Motion fast=m;fast.vx=1;check(!s.prepare_reversal(fast),"energetic refusal");
  check(s.prepare_reversal(m),"prepare reversal");token=s.token();check(s.acknowledge(token)&&s.commit(token)&&s.finalize(token,true),"reverse transaction");
  auto after=s.status();check(after.slot_members==0&&after.cell_members==8*height&&after.payload_hash==before.payload_hash,"conservation");
  for(int t=0;t<310;++t)check(s.tick(),"repeat rest");
 }
 std::cout<<"{\"ok\":true,\"workers\":"<<workers<<",\"height\":"<<height<<",\"cycles\":4,\"session_bytes\":"<<sizeof(Session)<<"}\n";
}
return 0;}catch(const std::exception& e){std::cerr<<e.what()<<"\n";return 1;}}
