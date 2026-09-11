// Issue16 L4: synthetic neutral-payload carrier; no World solver or physics.
#include "cybersand/cell_layout_storage.hpp"
#include <algorithm>
#include <array>
#include <atomic>
#include <barrier>
#include <chrono>
#include <cstdlib>
#include <exception>
#include <fstream>
#include <iostream>
#include <malloc.h>
#include <memory>
#include <new>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>
#include <windows.h>
#include <psapi.h>

std::atomic<std::uint64_t> allocations{0};
void* operator new(std::size_t n) { allocations.fetch_add(1,std::memory_order_relaxed); if(auto p=std::malloc(n?n:1))return p;throw std::bad_alloc(); }
void* operator new[](std::size_t n){return ::operator new(n);}
void operator delete(void* p) noexcept {std::free(p);}
void operator delete[](void* p) noexcept {::operator delete(p);}
void operator delete(void* p,std::size_t) noexcept {::operator delete(p);}
void operator delete[](void* p,std::size_t) noexcept {::operator delete(p);}
void* operator new(std::size_t n,std::align_val_t a){allocations.fetch_add(1,std::memory_order_relaxed);if(auto p=_aligned_malloc(n?n:1,static_cast<std::size_t>(a)))return p;throw std::bad_alloc();}
void* operator new[](std::size_t n,std::align_val_t a){return ::operator new(n,a);}
void operator delete(void* p,std::align_val_t) noexcept {_aligned_free(p);}
void operator delete[](void* p,std::align_val_t a) noexcept {::operator delete(p,a);}
void operator delete(void* p,std::size_t,std::align_val_t a) noexcept {::operator delete(p,a);}
void operator delete[](void* p,std::size_t,std::align_val_t a) noexcept {::operator delete(p,a);}

namespace {
using U=std::uint32_t;using Q=std::uint64_t;using L=cybersand::detail::CellLayoutStorage;
using M=cybersand::Material;using Clock=std::chrono::steady_clock;
constexpr U N=16384,C=16,T=N*C;constexpr std::uint16_t none=65535;
void check(bool v,const char* why){if(!v)throw std::runtime_error(why);}
struct Value {std::uint8_t m=0,a=0,b=0;std::int16_t temp=0;U tag=0;bool operator==(const Value&)const=default;};
Q water(Value v){return v.m==static_cast<std::uint8_t>(M::Water)?v.a:0;}
struct Inline {L cell{};U tag=0;};
struct Slot {U value=0;std::uint16_t owner=none,next=none;};
static_assert(sizeof(L)==4&&alignof(L)==4&&sizeof(Inline)==8&&sizeof(Slot)==8);
#if SIDECAR_LAYOUT == 0
using Hot=Inline;
#else
using Hot=L;
#endif
struct Chunk {
 std::vector<Hot> hot=std::vector<Hot>(N);
 std::vector<std::int16_t> temp=std::vector<std::int16_t>(N);
#if SIDECAR_LAYOUT == 1
 std::vector<U> tags;
#elif SIDECAR_LAYOUT == 2
 std::vector<std::uint16_t> index;
 std::vector<Slot> slots;
 std::uint16_t head=none;
#endif
 U cap=0,count=0,high=0;
 void prepare(U capacity){cap=capacity;
#if SIDECAR_LAYOUT == 1
 if(cap)tags.resize(N);
#elif SIDECAR_LAYOUT == 2
 if(cap){index.assign(N,none);slots.resize(cap);for(U i=0;i<cap;++i)slots[i].next=i+1<cap?static_cast<std::uint16_t>(i+1):none;head=0;}
#endif
 }
 L& legacy(U i){
#if SIDECAR_LAYOUT == 0
 return hot[i].cell;
#else
 return hot[i];
#endif
 }
 U tag(U i)const {
#if SIDECAR_LAYOUT == 0
 return hot[i].tag;
#elif SIDECAR_LAYOUT == 1
 return cap?tags[i]:0;
#else
 return cap&&index[i]!=none?slots[index[i]].value:0;
#endif
 }
 Value get(U i){auto& l=legacy(i);return {static_cast<std::uint8_t>(l.material_value()),l.state_a_value(),l.state_b_value(),temp[i],tag(i)};}
 void erase_tag(U i){if(!tag(i))return;--count;
#if SIDECAR_LAYOUT == 0
 hot[i].tag=0;
#elif SIDECAR_LAYOUT == 1
 tags[i]=0;
#else
 auto j=index[i];slots[j]={0,none,head};head=j;index[i]=none;
#endif
 }
 void set(U i,Value v){erase_tag(i);auto& l=legacy(i);l.set_material(static_cast<M>(v.m));l.set_state_a(v.a);l.set_state_b(v.b);l.set_epoch(0);temp[i]=v.temp;
 if(!v.tag)return;check(count<cap,"unpreflighted capacity");++count;high=std::max(high,count);
#if SIDECAR_LAYOUT == 0
 hot[i].tag=v.tag;
#elif SIDECAR_LAYOUT == 1
 tags[i]=v.tag;
#else
 check(head!=none,"free list empty");auto j=head;head=slots[j].next;slots[j]={v.tag,static_cast<std::uint16_t>(i),none};index[i]=j;
#endif
 }
 void validate(){U observed=0;for(U i=0;i<N;++i){if(tag(i))++observed;check(legacy(i).epoch_value()==0,"epoch changed");}
 check(observed==count&&count<=cap,"count invariant");
#if SIDECAR_LAYOUT == 2
 if(!cap){check(index.empty()&&slots.empty(),"absent allocations");return;}
 std::array<bool,N> seen{};U live=0,free=0;
 for(U i=0;i<N;++i)if(index[i]!=none){U j=index[i];check(j<cap&&!seen[j]&&slots[j].owner==i&&slots[j].value!=0,"inverse owner");seen[j]=true;++live;}
 for(auto j=head;j!=none;j=slots[j].next){check(j<cap&&!seen[j]&&slots[j].owner==none&&slots[j].value==0,"free list");seen[j]=true;++free;}
 check(live==count&&live+free==cap,"lost slot");
#endif
 }
 Q bytes()const {Q b=hot.capacity()*sizeof(Hot)+temp.capacity()*2;
#if SIDECAR_LAYOUT == 1
 b+=tags.capacity()*4;
#elif SIDECAR_LAYOUT == 2
 b+=index.capacity()*2+slots.capacity()*sizeof(Slot);
#endif
 return b;}
};
bool present(U i,U density,U seed,bool dispersed){U rank=dispersed?((i-131*seed)*196609U)&(T-1):i;return rank<T*density/100;}
Value initial(U i,U density,U seed,bool dispersed){U k=(i+seed)%3;Value v;v.m=static_cast<std::uint8_t>(k==0?M::Water:k==1?M::Sand:M::Fire);v.a=static_cast<std::uint8_t>(k==0?1+(i+seed)%255:k==1?17:48);v.b=static_cast<std::uint8_t>(k==0?(i+seed)%13:k==1?23:0);v.temp=static_cast<std::int16_t>(200+(i+seed)%17);v.tag=present(i,density,seed,dispersed)?(0x80000001U+2*i):0;return v;}
struct Store {std::array<Chunk,C> chunks;
 Value get(U i){return chunks[i/N].get(i%N);}void set(U i,Value v){chunks[i/N].set(i%N,v);}
 void init(U d,U seed,bool dispersed,bool force){for(U c=0;c<C;++c){U count=0;for(U i=0;i<N;++i)count+=present(c*N+i,d,seed,dispersed);chunks[c].prepare(count?std::min(N,count+64):force?64:0);for(U i=0;i<N;++i)set(c*N+i,initial(c*N+i,d,seed,dispersed));}}
 bool replace(U a,U b,Value x,Value y){U ca=a/N,cb=b/N;auto olda=get(a),oldb=get(b);
 auto delta=[](Value v){return v.tag?1:0;};
 int da=delta(x)-delta(olda),db=delta(y)-delta(oldb);
 if(ca==cb){if(static_cast<int>(chunks[ca].count)+da+db>static_cast<int>(chunks[ca].cap))return false;}
 else if(static_cast<int>(chunks[ca].count)+da>static_cast<int>(chunks[ca].cap)||static_cast<int>(chunks[cb].count)+db>static_cast<int>(chunks[cb].cap))return false;
 chunks[ca].erase_tag(a%N);chunks[cb].erase_tag(b%N);set(a,x);set(b,y);return true;}
 void validate(){for(auto& c:chunks)c.validate();}
};
struct Oracle {std::vector<Value> values=std::vector<Value>(T);std::array<U,C> counts{},caps{};
 void init(U d,U seed,bool dispersed,bool force){for(U i=0;i<T;++i){values[i]=initial(i,d,seed,dispersed);counts[i/N]+=values[i].tag!=0;}for(U c=0;c<C;++c)caps[c]=counts[c]?std::min(N,counts[c]+64):force?64:0;}
 Value get(U i){return values[i];}
 bool replace(U a,U b,Value x,Value y){U ca=a/N,cb=b/N;
 int da=int(x.tag!=0)-int(values[a].tag!=0),db=int(y.tag!=0)-int(values[b].tag!=0);
 int na=static_cast<int>(counts[ca])+da+(ca==cb?db:0),nb=static_cast<int>(counts[cb])+db;
 if(na>static_cast<int>(caps[ca])||(ca!=cb&&nb>static_cast<int>(caps[cb])))return false;
 counts[ca]=static_cast<U>(na);if(ca!=cb)counts[cb]=static_cast<U>(nb);values[a]=x;values[b]=y;return true;}
};
// 0..7 accepted,8..15 invalid,16..23 capacity;24/25 Water source/sink,
// 26/27 tag source/sink (split clones included),28 checksum,29 attempts,30/31 split clones/reclaims.
using Work=std::array<Q,32>;
template<class S> void operation(S& s,U a,U b,U op,U createTag,Work& w){++w[29];auto x=s.get(a),y=s.get(b),oldx=x,oldy=y;bool valid=true;
 switch(op){
 case 0:valid=x.m!=0&&y.m==0;if(valid){y=x;x={};}break;
 case 1:std::swap(x,y);break;
 case 2:valid=water(x)>1&&y.m==0;if(valid){y=x;y.a=static_cast<std::uint8_t>(x.a/2);x.a=static_cast<std::uint8_t>(x.a-y.a);}break;
 case 3:valid=water(x)>0&&water(y)>0&&water(x)+water(y)<=255;if(valid){y.a=static_cast<std::uint8_t>(x.a+y.a);y.b=std::max(x.b,y.b);if(!y.tag)y.tag=x.tag;x={};}break;
 case 4:x={};break;
 case 5:valid=x.m==0;if(valid)x={static_cast<std::uint8_t>(M::Water),127,12,211,createTag};break;
 case 6:x={};break;
 case 7:w[28]+=Q(x.tag)+y.tag+x.m+y.m+x.a+y.a;break;
 default:throw std::runtime_error("invalid op");
 }
 if(!valid){++w[8+op];return;}if(op!=7&&!s.replace(a,b,x,y)){++w[16+op];return;}++w[op];
 Q before=water(oldx)+water(oldy),after=water(x)+water(y);if(after>before)w[24]+=after-before;else w[25]+=before-after;
 Q tb=(oldx.tag!=0)+(oldy.tag!=0),ta=(x.tag!=0)+(y.tag!=0);if(ta>tb)w[26]+=ta-tb;else w[27]+=tb-ta;
 if(op==2&&x.tag)++w[30];if(op==6)w[31]+=oldx.tag!=0;
}
U location(U pair,U x,U y){return (2*pair+x/128)*N+y*128+x%128;}
struct alignas(64) Domain {Work work{},reference{};Q mass=0,tags=0;};
struct Fixture {Store store;std::unique_ptr<Oracle> oracle;std::array<Domain,8> domains{};U density,seed;bool dispersed;int mode;
 Fixture(U d,U s,bool pattern,int m,bool correctness):density(d),seed(s),dispersed(pattern),mode(m){store.init(d,s,pattern,m==1&&d==0);if(correctness){oracle=std::make_unique<Oracle>();oracle->init(d,s,pattern,m==1&&d==0);}for(U i=0;i<T;++i){auto v=store.get(i);domains[i/(2*N)].mass+=water(v);domains[i/(2*N)].tags+=v.tag!=0;}}
 void batch(U batch,U worker,U workers){for(U pair=worker;pair<8;pair+=workers){auto& d=domains[pair];d.work={};d.reference={};if(mode!=2){for(U j=0;j<1024;++j){U local=(batch*1024+j)%(2*N),i=pair*2*N+local;auto& l=store.chunks[i/N].legacy(i%N);d.work[28]+=Q(l.state_a_value())+l.state_b_value()+static_cast<std::uint8_t>(l.material_value())+i;++d.work[29];}continue;}
 constexpr std::array<U,8> order{4,6,5,2,3,0,1,7};
 for(U j=0;j<64;++j){U k=batch*8+j/8;U x=(k*73+seed*19)%255,y=(k*37+seed*11)%128;if(j/8==0)x=127;U a=location(pair,x,y),b=location(pair,x+1,y),op=order[j%8];if(op==6||op==3)std::swap(a,b);U tag=present(a,density,seed,dispersed)?0x80000001U+2*a:0;
 operation(store,a,b,op,tag,d.work);if(oracle){operation(*oracle,a,b,op,tag,d.reference);check(d.work==d.reference&&store.get(a)==oracle->get(a)&&store.get(b)==oracle->get(b),"operation oracle mismatch");}}
 check(d.mass+d.work[24]>=d.work[25]&&d.tags+d.work[26]>=d.work[27],"ledger underflow");d.mass+=d.work[24];d.mass-=d.work[25];d.tags+=d.work[26];d.tags-=d.work[27];}}
 Work work(){Work r{};for(auto& d:domains)for(U j=0;j<32;++j)r[j]+=d.work[j];return r;}
 void validate(){store.validate();std::array<Q,8> mass{},tags{};for(U i=0;i<T;++i){auto v=store.get(i);if(oracle)check(v==oracle->get(i),"full oracle mismatch");mass[i/(2*N)]+=water(v);tags[i/(2*N)]+=v.tag!=0;}for(U p=0;p<8;++p)check(mass[p]==domains[p].mass&&tags[p]==domains[p].tags,"full quantity ledger");}
};
struct Pool {Fixture& f;U workers,batchIndex=0;bool stop=false,prime=false;std::barrier<> start,done;std::vector<std::thread> threads;std::array<std::exception_ptr,4> errors{};
 Pool(Fixture& v,U w):f(v),workers(w),start(w),done(w){threads.reserve(w-1);for(U i=1;i<w;++i)threads.emplace_back([this,i]{for(;;){start.arrive_and_wait();if(stop)return;run(i);done.arrive_and_wait();}});}
 void run(U i)noexcept{try{if(!prime)f.batch(batchIndex,i,workers);}catch(...){errors[i]=std::current_exception();}}
 void batch(U b,bool p=false){batchIndex=b;prime=p;start.arrive_and_wait();run(0);done.arrive_and_wait();for(auto& e:errors)if(e)std::rethrow_exception(e);}
 ~Pool(){stop=true;start.arrive_and_wait();for(auto& t:threads)t.join();}
};
void focused(){Store s;for(auto& c:s.chunks)c.prepare(2);Value w{static_cast<std::uint8_t>(M::Water),200,12,315,0xffffffffU},empty{};Work r{};
 U a=127,b=N;s.set(a,w);operation(s,a,b,0,0,r);check(s.get(a)==empty&&s.get(b)==w&&r[0]==1,"seam move");
 operation(s,b,a,2,0,r);check(water(s.get(a))==100&&water(s.get(b))==100&&s.get(a).tag==w.tag&&r[30]==1,"split expected");
 operation(s,b,a,3,0,r);check(s.get(b)==empty&&s.get(a)==w&&r[27]==1,"merge expected");
 Value fire{static_cast<std::uint8_t>(M::Fire),48,0,222,0x80000001U};s.set(b,fire);operation(s,a,b,1,0,r);check(s.get(a)==fire&&s.get(b)==w,"swap expected");
 operation(s,a,b,6,0,r);check(s.get(a)==empty&&r[31]==1,"reclaim expected");operation(s,a,b,5,1,r);check(s.get(a).tag==1&&water(s.get(a))==127&&r[24]==127,"create expected");operation(s,a,b,4,0,r);check(s.get(a)==empty&&r[25]==127,"clear expected");
 Store unprepared;unprepared.chunks[0].prepare(2);unprepared.set(a,w);check(!unprepared.replace(a,N,{},w)&&unprepared.get(a)==w&&unprepared.get(N)==empty,"unprepared refusal");unprepared.validate();auto before=s.get(b);
 s.set(0,fire);s.set(1,w);auto old=s.get(0);check(!s.replace(b,2,{},before)&&s.get(b)==before&&s.get(0)==old&&s.get(2)==empty,"saturation refusal");
 check(s.replace(0,2,{},old)&&s.get(2)==old,"full capacity move");s.set(2,{});s.set(3,fire);s.validate();
 std::cout<<"{\"focused\":true,\"hot_stride\":"<<sizeof(Hot)<<",\"alignment\":"<<alignof(Hot)<<",\"chunk_object\":"<<sizeof(Chunk)<<",\"slot\":"<<sizeof(Slot)<<"}\n";
}
void integer(std::ostream& s,Q v,unsigned bytes){for(unsigned j=0;j<bytes;++j)s.put(static_cast<char>((v>>(j*8))&255));}
}
int main(int argc,char** argv){try{if(argc==2&&std::string(argv[1])=="selftest"){focused();return 0;}check(argc==12,"mode density pattern workers batches seed x y correctness prefix observer");
 int mode=std::stoi(argv[1]);U density=static_cast<U>(std::stoul(argv[2])),workers=static_cast<U>(std::stoul(argv[4])),batches=static_cast<U>(std::stoul(argv[5])),seed=static_cast<U>(std::stoul(argv[6]));bool dispersed=std::string(argv[3])=="dispersed",correctness=std::stoi(argv[9])!=0;auto ox=std::stoll(argv[7]),oy=std::stoll(argv[8]);std::string prefix=argv[10];check(std::stoi(argv[11])==0,"no timed observer");check((workers==1||workers==4)&&density<=100&&batches>0&&mode>=0&&mode<=2,"arguments");
 auto begin=Clock::now();Fixture f(density,seed,dispersed,mode,correctness);std::vector<Q> ns(batches);std::vector<Work> work(batches);Q newCount=0;
 {Pool pool(f,workers);for(U i=0;i<100;++i)pool.batch(0,true);auto prepared=Clock::now();
 for(U i=0;i<batches;++i){auto a=allocations.load();auto t=Clock::now();pool.batch(i);auto end=Clock::now();newCount+=allocations.load()-a;ns[i]=static_cast<Q>(std::chrono::duration_cast<std::chrono::nanoseconds>(end-t).count());work[i]=f.work();if(correctness&&i%64==63)f.validate();}
 auto finished=Clock::now();f.validate();check(newCount==0,"C++ allocation during batch");
 PROCESS_MEMORY_COUNTERS_EX memory{};memory.cb=sizeof(memory);check(GetProcessMemoryInfo(GetCurrentProcess(),reinterpret_cast<PROCESS_MEMORY_COUNTERS*>(&memory),sizeof(memory))!=0,"memory query");
 std::ofstream raw(prefix+".records",std::ios::binary);for(auto& row:work)for(auto v:row)integer(raw,v,8);for(U i=0;i<T;++i){auto v=f.store.get(i);U c=i/N,local=i%N;integer(raw,static_cast<Q>(ox+(c%4)*128+local%128),8);integer(raw,static_cast<Q>(oy+(c/4)*128+local/128),8);integer(raw,v.m,2);integer(raw,v.a,1);integer(raw,v.b,1);integer(raw,static_cast<std::uint16_t>(v.temp),2);integer(raw,v.tag,4);}check(raw.good(),"record write");
 std::ofstream csv(prefix+".samples.csv");csv<<"sample,ns,units\n";for(U i=0;i<batches;++i)csv<<i<<','<<ns[i]<<','<<work[i][29]<<'\n';check(csv.good(),"sample write");
 Q bytes=0,capacity=0,high=0;U preparedChunks=0;for(auto& c:f.store.chunks){bytes+=c.bytes();capacity+=c.cap;high+=c.high;preparedChunks+=c.cap!=0;}
 std::cout<<"{\"layout\":"<<SIDECAR_LAYOUT<<",\"hot_stride\":"<<sizeof(Hot)<<",\"alignment\":"<<alignof(Hot)<<",\"chunk_object_bytes\":"<<sizeof(Chunk)*C<<",\"store_object_bytes\":"<<sizeof(Store)<<",\"fixture_object_bytes\":"<<sizeof(Fixture)<<",\"pool_object_bytes\":"<<sizeof(Pool)<<",\"buffer_bytes\":"<<ns.capacity()*8+work.capacity()*sizeof(Work)<<",\"resident_array_bytes\":"<<bytes<<",\"prepared_chunks\":"<<preparedChunks<<",\"logical_capacity\":"<<capacity<<",\"sum_chunk_high_water\":"<<high<<",\"batch_cpp_allocations\":"<<newCount<<",\"working_set\":"<<memory.WorkingSetSize<<",\"private_bytes\":"<<memory.PrivateUsage<<",\"peak_working_set\":"<<memory.PeakWorkingSetSize<<",\"startup_ns\":"<<std::chrono::duration_cast<std::chrono::nanoseconds>(prepared-begin).count()<<",\"campaign_wall_ns\":"<<std::chrono::duration_cast<std::chrono::nanoseconds>(finished-prepared).count()<<",\"chunks\":[";
 for(U c=0;c<C;++c){if(c)std::cout<<',';auto& v=f.store.chunks[c];U initialCount=0;for(U i=0;i<N;++i)initialCount+=present(c*N+i,density,seed,dispersed);std::cout<<"{\"initial\":"<<initialCount<<",\"final\":"<<v.count<<",\"cap\":"<<v.cap<<",\"high\":"<<v.high<<",\"arrays\":"<<v.bytes()<<'}';}std::cout<<"]}\n";}
 return 0;}catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}}
