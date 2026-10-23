// Storage-only fixture. Compile only after apparatus source review/admission.
#include "maps.hpp"
#include <fstream>
#include <iostream>
#include <iomanip>
#include <stdexcept>
#ifndef MAT003_CAPACITY
#error "matrix capacity required"
#endif
#ifndef MAT003_EPOCH_BITS
#error "matrix epoch required"
#endif
using Cell=mat003_correctness::Cell<MAT003_CAPACITY,MAT003_EPOCH_BITS>;
static void bytes(const Cell& c) {
    for(auto b:c.canonical())std::cout<<std::hex<<std::setw(2)<<std::setfill('0')<<unsigned(b);
    std::cout<<std::dec;
}
int main(int argc,char** argv) {
    if(argc!=2 || std::string(argv[1])!="--correctness-only")return 2;
    std::array<Cell,1024> cells{};
    // Stable schedule, all primitive setters in ordered pairs plus boundaries.
    constexpr std::uint64_t values[]={0,1,254,255,256,32768,65280,65534,65535,65536,~std::uint64_t{0}};
    for(unsigned i=0;i<65536;++i) {
        auto& c=cells[(i/66)%cells.size()];
        auto v=c.read();auto input=values[(i/6)%11];auto field=i%6;
        std::cout<<i<<' '<<field<<' '<<input<<' ';bytes(c);std::cout<<' ';
        if(field==0)v.material=input;
        if(field==1)v.a=input;
        if(field==2)v.b=input;
        if(field==3)v.epoch=input;
        if(field==4)v.r=input;
        bool ok=true;
        if(field==5)c.clear_epoch();else ok=c.write_raw(v);
        std::cout<<ok<<' ';bytes(c);std::cout<<'\n';
    }
    if(!std::cout)return 3;
}
