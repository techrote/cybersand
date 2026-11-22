#include "cybersand/object_shard_discovery.hpp"
#include <algorithm>
#include <array>
#include <cstdio>
#include <cstdint>
#include <queue>
#include <set>
#include <vector>
using namespace cybersand;
using namespace cybersand::object_shard;
static unsigned checks=0, failures=0;
static std::uint64_t rng=0x7829ad00cd414311ULL;
static std::uint32_t next(){rng^=rng<<13;rng^=rng>>7;rng^=rng<<17;return static_cast<std::uint32_t>(rng);}
static void check(bool v){++checks;if(!v)++failures;}
static constexpr unsigned W=64,H=64,N=W*H;
static bool cohesive(Material m){return m==Material::Wood||m==Material::RedBrick;}
static std::vector<unsigned> near(unsigned a){std::vector<unsigned> r;if(a%W)r.push_back(a-1);if(a%W+1<W)r.push_back(a+1);if(a>=W)r.push_back(a-W);if(a+W<N)r.push_back(a+W);return r;}
int main(){
 Limits limits;limits.max_area=4096;
 for(unsigned run=0;run<40;++run){
  ComponentDiscovery d({0,0,W,H},limits);std::array<Material,N> world{};
  for(unsigned edit=0;edit<6000;++edit){
   unsigned at=next()%N;Material m=std::array{Material::Empty,Material::Wood,Material::RedBrick,Material::Wall}[next()%4];
   if(world[at]!=m){world[at]=m;d.invalidate(at);}
   auto budget=1U+next()%31;auto used=d.advance(budget,run,[&](unsigned i){return world[i];});check(used<=budget);check(!d.exhausted());
   if(edit%500!=499)continue;
   for(unsigned spins=0;!d.complete()&&spins<20000;++spins)d.advance(17,run,[&](unsigned i){return world[i];});
   check(d.complete());
   std::set<std::vector<unsigned>> expected,actual;std::array<bool,N> seen{};
   for(unsigned start=0;start<N;++start)if(!seen[start]&&cohesive(world[start])){
    std::queue<unsigned> q;q.push(start);seen[start]=true;std::vector<unsigned> component;
    bool anchored=false,boundary=false;
    while(!q.empty()){auto cell=q.front();q.pop();component.push_back(cell);boundary|=cell%W==0||cell%W==W-1||cell/W==0||cell/W==H-1;
     for(auto n:near(cell)){anchored|=world[n]==Material::Wall;if(!seen[n]&&world[n]==world[start]){seen[n]=true;q.push(n);}}
    }
    std::sort(component.begin(),component.end());expected.insert(component);
    bool found=false;for(auto root:d.roots()){const auto& c=d.candidate(root);if(c.canonical!=component[0])continue;found=true;check(c.cells==component.size());check(c.anchored==anchored);check(c.unknown_boundary==boundary);}
    check(found);
   }
   for(auto root:d.roots()){std::vector<unsigned> members;members.reserve(N);check(d.members(root,members));std::sort(members.begin(),members.end());actual.insert(members);}
   check(expected==actual);
  }
 }
 std::printf("%u checks, %u failures\n",checks,failures);return failures?1:0;
}
