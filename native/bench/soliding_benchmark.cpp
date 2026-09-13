// Diagnostic paired microbenchmark. Build against integrated baseline and current
// source with USE_OBSERVER=0, and current source with USE_OBSERVER=1.
#include "cybersand/world.hpp"
#if USE_OBSERVER
#include "cybersand/soliding.hpp"
#include "cybersand/soliding_session.hpp"
#endif
#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cstdlib>
#include <iostream>
#include <new>
std::atomic<unsigned long long> allocations{0};std::atomic<bool> tracking{false};
void* operator new(std::size_t n){if(tracking)++allocations;if(void* p=std::malloc(n?n:1))return p;throw std::bad_alloc();}
void operator delete(void* p)noexcept{std::free(p);}void operator delete(void* p,std::size_t)noexcept{std::free(p);}
void* operator new[](std::size_t n){return ::operator new(n);}void operator delete[](void* p)noexcept{std::free(p);}void operator delete[](void* p,std::size_t)noexcept{std::free(p);}
using Clock=std::chrono::steady_clock;
int main(int argc,char**){using namespace cybersand;const bool active=argc>1;World w;
 w.reserve_region({0,0,128,128});for(int y=82;y<96;++y)for(int x=36;x<44;++x)w.set(x,y,Material::Wall);
 for(int x=16;x<112;++x)w.set(x,96,Material::GraniteBlock);
#if USE_OBSERVER
 soliding::Observer observer({32,68,32,32});observer.observe(w);
#endif
 std::array<double,1800> total{},scan{};unsigned long long tick_allocs=0,temp_allocs=0;
 for(int t=-120;t<1800;++t){
  if(active){w.set(50,80,Material::Sand);w.set(50,81,Material::Empty);}
  allocations=0;tracking=t>=0;const auto begin=Clock::now();const auto stats=w.tick();const auto middle=Clock::now();
#if USE_OBSERVER
  observer.observe(w);
#endif
  const auto end=Clock::now();tracking=false;
  if(t>=0){total[t]=std::chrono::duration<double,std::micro>(end-begin).count();scan[t]=std::chrono::duration<double,std::micro>(end-middle).count();tick_allocs+=allocations.load();temp_allocs+=stats.temperature_field_allocations;}
 }
 std::sort(total.begin(),total.end());std::sort(scan.begin(),scan.end());
 std::cout<<"{\"active\":"<<(active?"true":"false")<<",\"observer\":"<<USE_OBSERVER<<",\"p50_us\":"<<total[900]<<",\"p95_us\":"<<total[1710]<<",\"max_us\":"<<total.back()<<",\"scan_p50_us\":"<<scan[900]<<",\"scan_p95_us\":"<<scan[1710]<<",\"instrumented_new\":"<<tick_allocs<<",\"temperature_allocations\":"<<temp_allocs<<",\"hash\":"<<w.content_hash();
#if USE_OBSERVER
 const auto& m=observer.metrics();std::cout<<",\"witness_cells\":"<<m.witness_cells<<",\"rebuilds\":"<<m.rebuilds<<",\"geometry_cells\":"<<m.geometry_cells;
 soliding::Session session;for(int t=0;t<310;++t)(void)session.tick();
 if(!session.prepare_promotion()||!session.acknowledge(session.token()))return 2;
 allocations=0;tracking=true;const auto start=Clock::now();const bool committed=session.commit(session.token());const auto stop=Clock::now();tracking=false;
 if(!committed)return 3;
 std::cout<<",\"commit_us\":"<<std::chrono::duration<double,std::micro>(stop-start).count()<<",\"commit_instrumented_new\":"<<allocations.load();
#endif
 std::cout<<"}\n";
}
