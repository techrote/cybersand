#include "cybersand/world.hpp"
#ifndef PRECISION_BASELINE
#include "cybersand/precision_storage.hpp"
#else
namespace cybersand::precision {
constexpr unsigned maximum=255, film=48, tolerance=1;
constexpr unsigned quantize(unsigned n,unsigned d=255) { return (2*n*maximum+d)/(2*d); }
}
#endif
#include <algorithm>
#include <array>
#include <chrono>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

using namespace cybersand;
using Clock=std::chrono::steady_clock;
struct Frame {
    std::uint64_t quantity=0, occupied=0, tiny=0, below=0, hash=14695981039346656037ULL;
    unsigned front=0;
    std::vector<std::uint64_t> columns;
    std::vector<unsigned> cells;
};
int run(int argc,char** argv) {
    if(argc!=8) throw std::invalid_argument("fixture shift mirror workers observer mode horizon");
    const std::string fixture=argv[1],mode=argv[6];
    const int shift=std::stoi(argv[2]),mirror=std::stoi(argv[3]),workers=std::stoi(argv[4]);
    const bool observe=std::stoi(argv[5])!=0,timing=mode=="timing";
    const int horizon=std::stoi(argv[7]),width=fixture=="basin96"?96:48;
    Clock::time_point startup;
    if(timing) startup=Clock::now();
    WorldConfig c;c.worker_threads=static_cast<unsigned>(workers);c.parallel_job_threshold=1;
    c.maximum_chunk_count=64;c.active_chunk_capacity=64;c.active_core_capacity=512;
    c.physics_diagnostics.enabled=observe;
    World w(c);w.reserve_region({shift-128,shift-128,512,512});
    w.set_simulation_region(RectI64{shift-128,shift-128,512,512});
    auto px=[&](int x){return shift+(mirror?width+1-x:x);};
    auto put=[&](int x,int y,Material m){w.set(px(x),shift+y,m);};
    std::uint64_t initial=0;
    // Requested physical amount is accumulated as numerator / (255*M).
    std::uint64_t requested_numerator=0;
    auto water=[&](int x,int y,unsigned n,unsigned delay=0,bool lattice=false){
        auto q=lattice?n:precision::quantize(n);
        requested_numerator+=lattice?n*255ULL:n*static_cast<std::uint64_t>(precision::maximum);
        if(q) { (void)w.set_cell_state(px(x),shift+y,Material::Water,static_cast<std::uint16_t>(q),static_cast<std::uint8_t>(delay));initial+=q; }
    };
    for(int x=0;x<=width+1;++x){put(x,0,Material::Wall);put(x,47,Material::Wall);}
    for(int y=0;y<48;++y){put(0,y,Material::Wall);put(width+1,y,Material::Wall);}
    if(fixture=="basin48"||fixture=="basin96") {
        for(int x=1;x<=12;++x)for(int y=15;y<=46;++y)water(x,y,255);
    } else if(fixture=="film") water(12,46,48);
    else if(fixture=="support") {
        for(int x=1;x<=width;++x)put(x,23,Material::Wall);
        water(12,22,255);
    } else if(fixture=="ledge"||fixture=="coherent") {
        for(int x=1;x<=24;++x)put(x,23,Material::Wall);
        for(int x=17;x<=24;++x)for(int y=15;y<=22;++y)water(x,y,255,fixture=="coherent"?12:0);
    } else if(fixture=="low") {
        w.set_liquid_surface_adhesion_enabled(false);
        const unsigned pairs[5][2]={{128,127},{2,1},{1,0},{2,1},{1,0}};
        for(int i=0;i<5;++i){int x=3+8*i;
            for(int dx=-1;dx<=2;++dx){put(x+dx,43,Material::Wall);put(x+dx,45,Material::Wall);}
            put(x-1,44,Material::Wall);put(x+2,44,Material::Wall);
            water(x,44,pairs[i][0],0,i>=3);water(x+1,44,pairs[i][1],0,i>=3);
        }
    } else if(fixture=="delay") {
        w.set_liquid_surface_adhesion_enabled(false);
        for(unsigned d=0;d<=12;++d){int y=2+3*static_cast<int>(d);
            for(int x=1;x<=4;++x){put(x,y-1,Material::Wall);put(x,y+1,Material::Wall);}
            put(1,y,Material::Wall);put(4,y,Material::Wall);
            water(2,y,200,d);water(3,y,55,12-d);
        }
    } else throw std::invalid_argument("fixture");
    const double startup_us=timing?std::chrono::duration<double,std::micro>(Clock::now()-startup).count():0;
    auto scan=[&](){
        Frame f;f.columns.resize(static_cast<std::size_t>(width));
        auto hash=[&](unsigned v,unsigned bytes){for(unsigned i=0;i<bytes;++i){f.hash^=(v>>(8*i))&255U;f.hash*=1099511628211ULL;}};
        for(int y=0;y<=47;++y)for(int x=0;x<=width+1;++x){
            auto m=w.stored_material(px(x),shift+y);auto a=w.stored_state_a(px(x),shift+y);auto b=w.stored_state_b(px(x),shift+y);
            hash(static_cast<unsigned>(m),2);hash(a,2);hash(b,1);hash(static_cast<unsigned>(w.temperature(px(x),shift+y)),2);
            if(m==Material::Water){
                if(!a||a>precision::maximum||b>12)throw std::runtime_error("invalid Water state");
                f.quantity+=a;++f.occupied;f.tiny+=a<=precision::quantize(1);if(y>23)f.below+=a;
                if(x<1||x>width||y<1||y>46)throw std::runtime_error("escaped closed fixture");
                f.columns[static_cast<std::size_t>(x-1)]+=a;
                f.cells.insert(f.cells.end(),{static_cast<unsigned>(x),static_cast<unsigned>(y),static_cast<unsigned>(a),b});
            }else if(m!=Material::Empty&&m!=Material::Wall)throw std::runtime_error("conversion");
        }
        if(f.quantity!=initial)throw std::runtime_error("exact quantity failure");
        for(int x=1;x<=width;++x)if(f.columns[static_cast<std::size_t>(x-1)]>=(128*precision::maximum+254)/255)f.front=static_cast<unsigned>(x);
        return f;
    };
    auto output_frame=[&](const Frame& f,bool snapshot){
        auto mm=std::minmax_element(f.columns.begin(),f.columns.end());
        std::cout<<",\"quantity\":"<<f.quantity<<",\"occupied\":"<<f.occupied<<",\"tiny\":"<<f.tiny
          <<",\"below\":"<<f.below<<",\"front\":"<<f.front<<",\"spread\":"<<*mm.second-*mm.first
          <<",\"semantic\":\""<<std::hex<<f.hash<<std::dec<<"\",\"columns\":[";
        for(std::size_t i=0;i<f.columns.size();++i)std::cout<<(i?",":"")<<f.columns[i];std::cout<<"]";
        if(snapshot){std::cout<<",\"cells\":[";for(std::size_t i=0;i<f.cells.size();++i)std::cout<<(i?",":"")<<f.cells[i];std::cout<<"]";}
    };
    std::cout<<"{\"metadata\":true,\"fixture\":\""<<fixture<<"\",\"maximum\":"<<precision::maximum
      <<",\"film\":"<<precision::film<<",\"tolerance\":"<<precision::tolerance<<",\"initial\":"<<initial
      <<",\"requested_numerator\":"<<requested_numerator<<",\"requested_denominator\":"<<255*precision::maximum
      <<",\"startup_us\":"<<startup_us<<",\"resident_bytes\":"<<w.resident_cell_bytes()<<"}\n";
    auto first=scan();std::cout<<"{\"tick\":0";output_frame(first,true);std::cout<<"}\n";
    std::uint64_t previous=first.hash,visits=0,blocks=0,moves=0;
    int last_change=0,last_active=0,arrival=0,level=0;
    for(int tick=1;tick<=horizon;++tick){
        if(fixture=="support"&&tick==601){for(int x=1;x<=width;++x)put(x,23,Material::Empty);if(!timing)previous=scan().hash;}
        Clock::time_point start;if(timing)start=Clock::now();
        const auto s=w.tick();
        const double elapsed=timing?std::chrono::duration<double,std::micro>(Clock::now()-start).count():0;
        if(s.chunk_allocations||s.temperature_field_allocations)throw std::runtime_error("unprepared allocation");
        visits+=s.visited_cells;blocks+=s.active_blocks_after;moves+=s.moved_cells;if(s.visited_cells)last_active=tick;
        std::cout<<"{\"tick\":"<<tick<<",\"visited\":"<<s.visited_cells<<",\"moved\":"<<s.moved_cells
          <<",\"active\":"<<s.active_blocks_after<<",\"cores\":"<<s.scheduled_cores<<",\"phase_jobs\":[";
        for(std::size_t i=0;i<s.phase_jobs.size();++i)std::cout<<(i?",":"")<<s.phase_jobs[i];std::cout<<"]";
        if(!timing){auto f=scan();if(f.hash!=previous)last_change=tick;previous=f.hash;
            auto mm=std::minmax_element(f.columns.begin(),f.columns.end());
            if(!arrival&&f.front>=static_cast<unsigned>(width*3/4))arrival=tick;
            if(!level&&*mm.second-*mm.first<=precision::maximum)level=tick;
            output_frame(f,tick==60||tick==120||tick==300||tick==600||tick==1200||tick==1800||tick==horizon);
        }
        if(observe){std::array<std::uint64_t,18> events{};const auto* totals=w.physics_diagnostics();
            if(!totals||totals->overflow)throw std::runtime_error("histogram overflow");
            for(const auto& e:totals->entries)if((e.key>>24)<events.size())events[e.key>>24]+=e.count;
            std::cout<<",\"events\":[";for(std::size_t i=0;i<events.size();++i)std::cout<<(i?",":"")<<events[i];std::cout<<"]";
        }
        if(timing)std::cout<<",\"tick_us\":"<<elapsed;
        std::cout<<"}\n";
    }
    auto final=scan();std::cout<<"{\"result\":true,\"visits\":"<<visits<<",\"block_ticks\":"<<blocks
      <<",\"moves\":"<<moves<<",\"last_active\":"<<last_active<<",\"last_change\":"<<(timing?-1:last_change)
      <<",\"arrival\":"<<arrival<<",\"level\":"<<level;output_frame(final,true);std::cout<<"}\n";
    return 0;
}
int main(int argc,char** argv){try{return run(argc,argv);}catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}}
