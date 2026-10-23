#include "candidates.hpp"
#include <iostream>
#include <stdexcept>

void check(bool b) { if (!b) throw std::runtime_error("independent storage model mismatch"); }
template<class R> void exercise() {
    mat003::Cell<R, 16> a;
    std::uint64_t rng = 204;
    for (unsigned i = 0; i < 8192; ++i) {
        rng ^= rng << 13; rng ^= rng >> 7; rng ^= rng << 17;
        const auto high = rng;
        a.storage.upper(high);
        a.material(0xffff); a.a(i & 1 ? 0x8000 : 0xffff); a.b(255); a.epoch(65535);
        check(a.material() == 65535 && a.a() == (i & 1 ? 32768 : 65535) && a.b() == 255 && a.epoch() == 65535);
        check(a.storage.upper() == high);
        a.material(0); // Nonzero Empty state must survive a partial material write.
        check(a.a() != 0 && a.storage.upper() == high);
        auto b = a;
        check(b.storage.upper() == high && b.storage.word() == a.storage.word());
        b.epoch(0); check(b.storage.upper() == high && b.a() == a.a());
        b.extra(0x81a5); check(b.storage.upper() == ((high & ~std::uint64_t{65535}) | 0x81a5));
        std::swap(a, b); check(a.storage.upper() == ((high & ~std::uint64_t{65535}) | 0x81a5));
        auto record = a.read(); check(a.write(record) && a.storage.upper() == ((high & ~std::uint64_t{65535}) | 0x81a5));
    }
}
template<unsigned N> void compact() {
    mat003::Packed<N> old;
    mat003_continuation::MemcpyPacked<N> candidate;
    for (std::uint64_t i = 0; i < 8192; ++i) {
        const auto v = i * 0x8123456789abcdefULL;
        old.word(v); candidate.word(v); old.tail(static_cast<std::uint16_t>(i)); candidate.tail(static_cast<std::uint16_t>(i));
        check(old.bytes == candidate.bytes && candidate.word() == v && old.tail() == candidate.tail());
    }
}
template<unsigned Bits> void wide() {
    using C=mat003_continuation::WideCell<mat003::Aligned<2>,Bits>;
    C c;
    for (std::uint32_t i=0;i<8192;++i) {
        const auto e=static_cast<std::uint32_t>((std::uint64_t{i} * 0x81234567U) & C::epoch_limit);
        const auto payload=Bits==32 ? (i&255U) : (i*7U&65535U);
        c.material(i&65535U); c.a(i&1 ? 32768 : 65535); c.b(255);
        check(c.extra(payload)); c.epoch(e);
        check(c.material()==i && c.a()==(i&1 ? 32768 : 65535) && c.b()==255 && c.epoch()==e && c.extra()==payload);
        // Independent mathematical byte map, including E32 crossing bit64.
        const auto expected_low=std::uint64_t{i} | (std::uint64_t{i&1 ? 32768U : 65535U}<<16) |
            (std::uint64_t{255}<<32) | ((std::uint64_t{e}&0xffffffU)<<40);
        const auto expected_tail=Bits==32 ? ((payload<<8)|(e>>24)) : payload;
        check(c.storage.word()==expected_low && c.storage.tail()==expected_tail);
        const auto lo=c.storage.word(); const auto hi=c.storage.tail();
        check(!c.extra(Bits==32 ? 256U : 65536U) && c.storage.word()==lo && c.storage.tail()==hi);
        c.epoch(static_cast<std::uint32_t>(C::epoch_limit));
        check(c.epoch()==C::epoch_limit && c.extra()==payload);
        c.epoch(0); c.material(0);
        check(c.epoch()==0 && c.a()!=0 && c.b()==255 && c.extra()==payload);
    }
}
int main() {
    compact<1>(); compact<2>(); exercise<mat003_continuation::Dual64>();
    wide<24>(); wide<32>();
#ifdef __SIZEOF_INT128__
    exercise<mat003_continuation::U128>();
    std::cout << "{\"dual_size\":" << sizeof(mat003_continuation::Dual64) << ",\"dual_align\":" << alignof(mat003_continuation::Dual64)
              << ",\"u128_size\":" << sizeof(mat003_continuation::U128) << ",\"u128_align\":" << alignof(mat003_continuation::U128) << ",\"passed\":true}\n";
#else
    throw std::runtime_error("native128 unsupported: qualification incomplete");
#endif
}
