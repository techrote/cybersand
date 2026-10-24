#pragma once
#include <cstdint>
struct Action {unsigned op,left,right,field;bool negative;std::uint64_t value;};
inline Action action(unsigned index) {
    const unsigned group=index/128,offset=index%128;
    Action a{0,group%1024,(group+1)%1024,offset%2?(offset/10)%5:(offset/2)%5,false,0};
    const unsigned v=group%35;
    constexpr std::uint64_t boundary[]={0,1,254,255,256,32767,32768,65534,65535,65536,~std::uint64_t{0},0xaaaa,0x5555,0xff00,0x00ff,0x0100,0x8000,0xffff};
    a.value=v<18?boundary[v]:(std::uint64_t{1}<<(v-18));
    if(offset==96){a.op=5;a.value=std::uint64_t{1}<<(group%64);}
    if(offset==100)a.op=2; // swap distinct records before copying
    if(offset==101)a.op=1; // complete copy
    if(offset==102)a.op=4; // clear a populated epoch
    if(offset==103)a.op=3; // declared replacement after populated state
    if(offset>=104&&offset<120){a.op=5;a.value=std::uint64_t{1}<<((group+offset)%64);}
    if(offset==120){a.negative=true;a.value=1;}
    if(offset==121){a.op=6;} // unknown schema refuses
    if(offset==122){a.op=7;} // unavailable capacity refuses
    return a;
}
