#include "cybersand/soliding.hpp"
#include <chrono>
#include <iostream>
#include <string>
#include <vector>
#include <cmath>
using namespace cybersand;
using namespace cybersand::soliding;
void check(bool b,const char* message){if(!b)throw std::runtime_error(message);}
WorldConfig config(unsigned workers=1){WorldConfig c;c.worker_threads=workers;c.initial_chunk_reserve=16;c.maximum_chunk_count=64;c.parallel_job_threshold=1;return c;}
void fill(World& w,int x,int y,int sx,int sy,Material m){for(int yy=y;yy<y+sy;++yy)for(int xx=x;xx<x+sx;++xx)w.set(xx,yy,m);}
const Candidate* find(const Observer& o,Material m,unsigned area=0){for(const auto& c:o.candidates())if(c.material==m&&(!area||c.area==area))return &c;return nullptr;}
void advance(World& w,Observer& o,unsigned ticks){for(unsigned t=0;t<ticks;++t){(void)w.tick();o.observe(w);}}
void geometry(const Observer& o,const World& w){const auto p=o.patch();for(const auto& c:o.candidates()){
 if(c.capacity)continue;std::array<unsigned,1024> coverage{};
 for(std::size_t j=0;j<c.shape_count;++j){const auto r=c.shapes[j];for(int y=r.y;y<r.y+r.h;++y)for(int x=r.x;x<r.x+r.w;++x){
 check(x>=0&&x<p.width&&y>=0&&y<p.height,"shape out of patch");++coverage[static_cast<std::size_t>(y*p.width+x)];
 check(w.stored_material(p.x+x,p.y+y)==c.material,"shape bridges hole or seam");}}
 unsigned total=0;for(auto n:coverage){check(n<=1,"duplicate shape coverage");total+=n;}check(total==c.area,"shape membership mismatch");
 for(unsigned j=0;j<c.area;++j)check(coverage[static_cast<std::size_t>(c.members[j].y*p.width+c.members[j].x)]==1,"member omitted");
}}
void transitions(){World w(config());w.reserve_region({-32,-32,96,96});fill(w,4,4,8,8,Material::Wall);fill(w,4,12,8,2,Material::GraniteBlock);
 Observer o({0,0,32,32});o.observe(w);advance(w,o,310);check(find(o,Material::Wall)->eligible(300,.98,64),"coherent island never rests");
 auto old_id=find(o,Material::Wall)->id;auto old_rev=find(o,Material::Wall)->revision;
 o.observe(w);check(find(o,Material::Wall)->rest_ticks<312,"same tick earned rest");
 // ABA between observations must reset even with identical payload and no tick.
 w.set(5,5,Material::Empty);w.set(5,5,Material::Wall);o.observe(w);
 check(find(o,Material::Wall)->rest_ticks==0,"ABA earned rest");check(find(o,Material::Wall)->id==old_id&&find(o,Material::Wall)->revision>old_rev,"unstable identity/revision");
 advance(w,o,130);w.set_temperature(5,5,350);o.observe(w);check(find(o,Material::Wall)->rest_ticks==0,"heat missed");
 advance(w,o,130);(void)w.set_cell_state(5,5,Material::Wall,7,4);o.observe(w);check(find(o,Material::Wall)->rest_ticks==0,"compact state mutation missed");
 advance(w,o,130);w.set_simulation_region(RectI64{256,256,32,32});advance(w,o,400);check(find(o,Material::Wall)->rest_ticks==0,"offscreen rest");
 w.set_simulation_region(std::nullopt);advance(w,o,5);check(!find(o,Material::Wall)->eligible(),"reentry inherited rest");
 advance(w,o,130);(void)w.tick();(void)w.tick();o.observe(w);check(find(o,Material::Wall)->rest_ticks==0,"observation gap earned rest");
 advance(w,o,130);fill(w,4,12,8,2,Material::Empty);o.observe(w);check(!find(o,Material::Wall)->eligible(0,.8,16),"support excavation missed");
 fill(w,4,12,8,2,Material::GraniteBlock);advance(w,o,130);w.configure_transient_obstacles({0,0,32,32});check(w.set_transient_obstacle(6,6,1),"mask setup");o.observe(w);check(find(o,Material::Wall)->rest_ticks==0,"masked source candidate");
 w.clear_transient_obstacles();advance(w,o,130);
 check(find(o,Material::Wall)->eligible(),"mask ABA setup did not rest");
 check(w.set_transient_obstacle(6,6,1),"mask ABA setup");w.clear_transient_obstacles();
 (void)w.tick();o.observe(w);check(find(o,Material::Wall)->rest_ticks==0,"transient mask ABA earned rest");
 advance(w,o,130);check(w.set_transient_obstacle(31,31,1),"halo mask setup");
 w.configure_transient_obstacles({0,0,32,32});o.observe(w);
 check(find(o,Material::Wall)->rest_ticks==0,"mask reconfigure ABA earned rest");
 w.clear();o.observe(w);check(!find(o,Material::Wall),"clear retained candidate");
 auto c=config();c.active_chunk_capacity=1;World bad(c);fill(bad,4,4,4,4,Material::Wall);bad.set(260,4,Material::Sand);Observer q({0,0,32,32});
 try{(void)bad.tick();}catch(const std::exception&){}check(bad.has_failed(),"fault setup");q.observe(bad);check(q.metrics().failed==1,"failed witness missing");check(!find(q,Material::Wall)->eligible(1,.8,16),"quarantine earned rest");
 std::cout<<"{\"test\":\"transitions\",\"ok\":true}\n";
}
void fixture(World& w,const std::string& name,int ox,int oy){
 auto put=[&](int x,int y,int sx,int sy,Material m){fill(w,ox+x,oy+y,sx,sy,m);};
 put(0,28,32,2,Material::GraniteBlock);
 if(name=="solid4")put(4,24,4,4,Material::Wall);
 else if(name=="solid8")put(4,20,8,8,Material::Wall);
 else if(name=="solid16")put(4,12,16,16,Material::Wall);
 else if(name=="dense-powder")put(4,12,16,16,Material::Sand);
 else if(name=="loose-powder"){for(int y=3;y<12;y+=2)for(int x=8;x<20;x+=2)put(x,y,1,1,Material::Sand);}
 else if(name=="hole"){put(4,20,8,8,Material::Wall);put(6,22,4,4,Material::Empty);}
 else if(name=="diagonal"){put(4,20,4,4,Material::Wall);put(8,24,4,4,Material::Wall);}
 else if(name=="neck"){put(4,24,6,4,Material::Wall);put(14,24,6,4,Material::Wall);put(10,25,4,1,Material::Wall);}
 else if(name=="seam"){put(4,20,4,8,Material::Wall);put(8,20,4,8,Material::RedBrick);}
 else if(name=="clipped")put(0,20,8,8,Material::Wall);
 else if(name=="member-cap")put(2,10,18,18,Material::Wall);
 else if(name=="component-cap"){for(int y=2;y<20;y+=2)for(int x=2;x<20;x+=2)put(x,y,1,1,Material::Wall);}
 else if(name=="shape-cap"){for(int y=4;y<20;++y){if(y%2==0)put(4,y,15,1,Material::Wall);else for(int x=4;x<19;x+=2)put(x,y,1,1,Material::Wall);}put(4,20,1,8,Material::Wall);}
}
int main(int argc,char** argv){try{
 transitions();
 const int ticks=argc>1?std::stoi(argv[1]):1800;
 const std::array<std::pair<int,int>,5> offsets={{{0,0},{-143,-141},{20,20},{52,52},{116,116}}};
 const std::vector<std::string> names={"solid4","solid8","solid16","dense-powder","loose-powder","hole","diagonal","neck","seam","clipped","member-cap","component-cap","shape-cap"};
 unsigned cases=0;
 for(unsigned workers:{1U,4U})for(const auto [ox,oy]:offsets)for(const auto& name:names){
  World w(config(workers)),control(config(workers));w.reserve_region({ox-32,oy-32,96,96});control.reserve_region({ox-32,oy-32,96,96});
  fixture(w,name,ox,oy);fixture(control,name,ox,oy);Observer o({ox,oy,32,32});o.observe(w);
  std::vector<double> costs;costs.reserve(static_cast<std::size_t>(ticks));
  for(int t=0;t<ticks;++t){const auto stats=w.tick();const auto expected=control.tick();
   auto start=std::chrono::steady_clock::now();o.observe(w);auto end=std::chrono::steady_clock::now();costs.push_back(std::chrono::duration<double,std::micro>(end-start).count());
   check(w.content_hash()==control.content_hash(),"observer perturbed authority");check(stats.moved_cells==expected.moved_cells,"observer perturbed work");
   geometry(o,w);
   for(const auto& c:o.candidates())if(c.material==Material::Sand)check(!c.eligible(0,0,0),"false powder cohesion");
  }
  const auto* wall=find(o,Material::Wall);if(name.rfind("solid",0)==0){check(wall&&wall->eligible(300,.98,16),"positive screen failed");check(wall->shape_count==1,"solid shape not merged");}
  if(name=="hole")check(wall&&wall->area==48&&wall->shape_count>1,"hole topology");
  if(name=="diagonal"){unsigned n=0;for(const auto& c:o.candidates())n+=c.material==Material::Wall;check(n==2,"diagonal glue");}
  if(name=="clipped"||name=="member-cap"||name=="component-cap"||name=="shape-cap")for(const auto& c:o.candidates())check(!c.eligible(0,0,0),"capacity/clipped candidate escaped");
  std::array<unsigned,27> screens{};std::size_t k=0;for(unsigned rest:{30U,120U,300U})for(double packing:{.8,.9,.98})for(unsigned area:{16U,64U,256U}){for(const auto& c:o.candidates())screens[k]+=c.eligible(rest,packing,area);++k;}
  std::sort(costs.begin(),costs.end());const auto& m=o.metrics();
  std::cout<<"{\"fixture\":\""<<name<<"\",\"workers\":"<<workers<<",\"x\":"<<ox<<",\"y\":"<<oy<<",\"ticks\":"<<ticks<<",\"witness_cells\":"<<m.witness_cells<<",\"geometry_cells\":"<<m.geometry_cells<<",\"rebuilds\":"<<m.rebuilds<<",\"births\":"<<m.births<<",\"invalidations\":"<<m.invalidations<<",\"topology_changes\":"<<m.topology_changes<<",\"support_changes\":"<<m.support_changes<<",\"component_high_water\":"<<m.component_high_water<<",\"member_high_water\":"<<m.member_high_water<<",\"shape_high_water\":"<<m.shape_high_water<<",\"saturations\":"<<m.saturations<<",\"observer_us_p50\":"<<costs[costs.size()/2]<<",\"observer_us_p95\":"<<costs[costs.size()*95/100]<<",\"observer_us_max\":"<<costs.back()<<",\"screens\":[";
  for(std::size_t j=0;j<screens.size();++j)std::cout<<(j?",":"")<<screens[j];std::cout<<"],\"ok\":true}\n";++cases;
 }
 std::cout<<"{\"ok\":true,\"cases\":"<<cases<<",\"observer_bytes\":"<<sizeof(Observer)<<",\"candidate_bytes\":"<<sizeof(Candidate)<<"}\n";
}catch(const std::exception& e){std::cerr<<"FAIL: "<<e.what()<<'\n';return 1;}}
