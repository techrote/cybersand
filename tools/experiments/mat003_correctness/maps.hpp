#pragma once
// Isolated reviewed map implementation. Never included by production.
#include <array>
#include <bit>
#include <stdexcept>
#include <cstdint>
#include <cstring>
#include <type_traits>
namespace mat003_correctness {
struct Record { std::uint64_t material=0,a=0,b=0,epoch=0,r=0; };
template<unsigned Bytes> struct Compact {
    std::array<unsigned char,Bytes> bytes{};
    std::uint64_t lane(unsigned n) const noexcept {
        std::uint64_t v=0;
        if(n==0 && std::endian::native==std::endian::little) {std::memcpy(&v,bytes.data(),8);return v;}
        for(unsigned i=0;i<8 && n*8+i<Bytes;++i) v|=std::uint64_t(bytes[n*8+i])<<(i*8);
        return v;
    }
    void lane(unsigned n,std::uint64_t v) noexcept {
        if(n==0 && std::endian::native==std::endian::little) {std::memcpy(bytes.data(),&v,8);return;}
        for(unsigned i=0;i<8 && n*8+i<Bytes;++i) bytes[n*8+i]=static_cast<unsigned char>(v>>(i*8));
    }
};
struct Word { std::uint64_t low=0;
    std::uint64_t lane(unsigned n) const noexcept { return n==0?low:0; }
    void lane(unsigned n,std::uint64_t v) noexcept { if(n==0) low=v; }
};
struct Dual { std::uint64_t low=0,high=0;
    std::uint64_t lane(unsigned n) const noexcept {return n==0?low:high;}
    void lane(unsigned n,std::uint64_t v) noexcept {if(n==0)low=v;else high=v;}
};
template<unsigned Capacity,unsigned Epoch> struct Cell {
    static_assert((Capacity==64||Capacity==72||Capacity==80||Capacity==128)&&(Epoch==8||Epoch==16));
    using Storage=std::conditional_t<Capacity==64,Word,std::conditional_t<Capacity==128,Dual,Compact<Capacity/8>>>;
    Storage storage{};
    static constexpr unsigned epoch_start=Epoch==8?56:(Capacity==64?48:40);
    static constexpr unsigned r_start=Epoch==8?40:56;
    static constexpr bool supports_r=!(Capacity==64&&Epoch==16);
    std::uint64_t get(unsigned start,unsigned width) const noexcept {
        std::uint64_t result=0;
        for(unsigned i=0;i<width;++i) result|=((storage.lane((start+i)/64)>>((start+i)%64))&1)<<i;
        return result;
    }
    void put(unsigned start,unsigned width,std::uint64_t value) noexcept {
        for(unsigned i=0;i<width;++i) {unsigned bit=start+i,n=bit/64; auto mask=std::uint64_t{1}<<(bit%64);
            storage.lane(n,(storage.lane(n)&~mask)|(((value>>i)&1)<<(bit%64)));}
    }
    std::array<unsigned char,Capacity/8> canonical() const noexcept {
        std::array<unsigned char,Capacity/8> out{};
        for(unsigned i=0;i<Capacity/8;++i) out[i]=static_cast<unsigned char>(storage.lane(i/8)>>((i%8)*8));
        return out;
    }
    Record read() const noexcept {return {get(0,16),get(16,16),get(32,8),get(epoch_start,Epoch),supports_r?get(r_start,16):0};}
    // Raw representational admission only: public semantic domains need a separate boundary.
    bool write_raw(const Record& v) noexcept {
        if(v.material>65535||v.a>65535||v.b>255||v.epoch>((std::uint64_t{1}<<Epoch)-1)||v.r>65535||(!supports_r&&v.r))return false;
        put(0,16,v.material);put(16,16,v.a);put(32,8,v.b);put(epoch_start,Epoch,v.epoch);
        if constexpr(supports_r)put(r_start,16,v.r);
        return true;
    }
    void clear_epoch() noexcept {put(epoch_start,Epoch,0);}
};
static_assert(sizeof(Cell<72,8>)==9 && alignof(Cell<72,8>)==1);
static_assert(sizeof(Cell<80,16>)==10 && alignof(Cell<80,16>)==1);
static_assert(sizeof(Cell<128,16>)==16 && alignof(Cell<128,16>)==8);
static_assert(sizeof(Cell<64,8>)==8 && alignof(Cell<64,8>)==8);
}
