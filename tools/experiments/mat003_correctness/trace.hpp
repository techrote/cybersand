#pragma once
#include <array>
#include <atomic>
#include <cstdint>
#include <fstream>
#include <stdexcept>
namespace mat003_correctness {
struct TraceEvent {unsigned kind;std::uintptr_t destination,source;std::array<unsigned char,16> before{},input{},after{};std::uint64_t value;bool accepted;};
inline constexpr std::size_t trace_capacity=262144;
inline std::array<TraceEvent,trace_capacity> trace_buffer{};
inline std::atomic<std::size_t> trace_size{0};
inline std::atomic<bool> trace_overflow{false};
inline bool trace_enabled=false;
template<class C> void trace(unsigned kind,const C& destination,const C* source,const C& before,std::uint64_t value=0,bool accepted=true) noexcept {
    if(!trace_enabled)return;
    auto a=before.read(),b=destination.read();
    if(kind==0 && !(a.r||a.u||b.r||b.u))return; // Zero-payload copies cannot alter the tracked logical state.
    auto i=trace_size.fetch_add(1,std::memory_order_relaxed);
    if(i>=trace_capacity){trace_overflow=true;return;}
    auto& e=trace_buffer[i];e.kind=kind;e.destination=reinterpret_cast<std::uintptr_t>(&destination);e.source=reinterpret_cast<std::uintptr_t>(source);e.value=value;e.accepted=accepted;e.input.fill(0);
    const auto x=before.canonical(),y=destination.canonical();
    for(unsigned n=0;n<x.size();++n){e.before[n]=x[n];e.after[n]=y[n];}
    if(source){auto z=source->canonical();for(unsigned n=0;n<z.size();++n)e.input[n]=z[n];}
}
inline void flush_trace(std::ostream& out,unsigned bytes,std::uint64_t tick) {
    if(trace_overflow)throw std::runtime_error("bounded transition trace overflow");
    const auto count=trace_size.load();
    const auto hex=[&](const auto& data){constexpr char digits[]="0123456789abcdef";for(unsigned i=0;i<bytes;++i)out<<digits[data[i]>>4]<<digits[data[i]&15];};
    for(std::size_t i=0;i<count;++i){const auto& e=trace_buffer[i];out<<tick<<' '<<i<<' '<<e.kind<<' '<<e.destination<<' '<<e.source<<' '<<e.value<<' '<<e.accepted<<' ';hex(e.before);out<<' ';hex(e.input);out<<' ';hex(e.after);out<<'\n';}
    trace_size=0;if(!out)throw std::runtime_error("transition trace output failure");
}
}
