#pragma once
// Experimental only: included in generated overlays, never production.
#include "carriers.hpp"
#include <bit>
#include <cstring>

namespace mat003_continuation {
template<unsigned Extra> struct MemcpyPacked : mat003::Packed<Extra> {
    std::uint64_t word() const noexcept {
        std::uint64_t value;
        std::memcpy(&value, this->bytes.data(), sizeof(value));
        if constexpr (std::endian::native == std::endian::little) return value;
        // The accepted byte representation has an explicit LE logical map.
        // A big/mixed-endian host keeps the defined bytewise implementation.
        return mat003::Packed<Extra>::word();
    }
    void word(std::uint64_t value) noexcept {
        if constexpr (std::endian::native == std::endian::little)
            std::memcpy(this->bytes.data(), &value, sizeof(value));
        else mat003::Packed<Extra>::word(value);
    }
};

struct Dual64 {
    std::uint64_t low = 0, high = 0;
    static constexpr unsigned extra_bytes = 2; // S1 API exercises low16 of high64.
    static constexpr bool is_source = false;
    std::uint64_t word() const noexcept { return low; }
    void word(std::uint64_t v) noexcept { low = v; }
    std::uint64_t upper() const noexcept { return high; }
    void upper(std::uint64_t v) noexcept { high = v; }
    std::uint16_t tail() const noexcept { return static_cast<std::uint16_t>(high); }
    void tail(std::uint16_t v) noexcept { high = (high & ~std::uint64_t{65535}) | v; }
};
#if defined(__SIZEOF_INT128__)
struct U128 {
    __extension__ using Value = unsigned __int128;
    Value bits = 0;
    static constexpr unsigned extra_bytes = 2;
    static constexpr bool is_source = false;
    std::uint64_t word() const noexcept { return static_cast<std::uint64_t>(bits); }
    void word(std::uint64_t v) noexcept { bits = (bits & (~Value{0} << 64)) | v; }
    std::uint64_t upper() const noexcept { return static_cast<std::uint64_t>(bits >> 64); }
    void upper(std::uint64_t v) noexcept { bits = static_cast<std::uint64_t>(bits) | (Value{v} << 64); }
    std::uint16_t tail() const noexcept { return static_cast<std::uint16_t>(upper()); }
    void tail(std::uint16_t v) noexcept { upper((upper() & ~std::uint64_t{65535}) | v); }
};
#endif

// Raw representational diagnostic only. This span deliberately crosses bit64
// and overlaps the experimental epoch; it defines no material field and is
// never invoked by World. Compare the native mask with an explicit lane split.
inline void raw_cross16(Dual64& c, std::uint16_t v) noexcept {
    c.low = (c.low & 0x0fffffffffffffffULL) | (std::uint64_t{v & 15U} << 60);
    c.high = (c.high & ~std::uint64_t{4095}) | (v >> 4);
}
#if defined(__SIZEOF_INT128__)
inline void raw_cross16(U128& c, std::uint16_t v) noexcept {
    const auto mask = U128::Value{65535} << 60;
    c.bits = (c.bits & ~mask) | (U128::Value{v} << 60);
}
#endif

// WCLEAR E24/E32 only. 40 semantic low bits are unchanged. E32 consumes the
// first tail byte, leaving the second tail byte neutral. No signed shifts or
// width-sized shifts; tail access always uses the representation's safe API.
template<class R, unsigned Bits> struct WideCell {
    static_assert(Bits == 24 || Bits == 32);
    static_assert(R::extra_bytes == 2, "WCLEAR prototype is qualified only with a two-byte tail");
    R storage{};
    static constexpr unsigned epoch_bits = Bits;
    static constexpr std::uint64_t epoch_limit = (std::uint64_t{1} << Bits) - 1;
    void field(std::uint64_t mask, unsigned shift, std::uint32_t v) noexcept {
        storage.word((storage.word() & ~mask) | ((std::uint64_t{v} << shift) & mask));
    }
    std::uint16_t material() const noexcept { return static_cast<std::uint16_t>(storage.word()); }
    std::uint16_t a() const noexcept { return static_cast<std::uint16_t>(storage.word() >> 16); }
    std::uint8_t b() const noexcept { return static_cast<std::uint8_t>(storage.word() >> 32); }
    std::uint32_t epoch() const noexcept {
        auto result = static_cast<std::uint32_t>(storage.word() >> 40);
        if constexpr (Bits == 32) result |= std::uint32_t{storage.tail() & 255U} << 24;
        return result;
    }
    void material(std::uint32_t v) noexcept { field(65535, 0, v); }
    void a(std::uint32_t v) noexcept { field(std::uint64_t{65535} << 16, 16, v); }
    void b(std::uint32_t v) noexcept { field(std::uint64_t{255} << 32, 32, v); }
    void epoch(std::uint32_t v) noexcept {
        field(~std::uint64_t{0} << 40, 40, v);
        if constexpr (Bits == 32)
            storage.tail(static_cast<std::uint16_t>((storage.tail() & 0xff00U) | (v >> 24)));
    }
    std::uint16_t extra() const noexcept {
        if constexpr (Bits == 32) return static_cast<std::uint16_t>(storage.tail() >> 8);
        return storage.tail();
    }
    bool extra(std::uint32_t v) noexcept {
        if constexpr (Bits == 32) {
            if (v > 255) return false;
            storage.tail(static_cast<std::uint16_t>((storage.tail() & 255U) | (v << 8)));
        } else {
            if (v > 65535) return false;
            storage.tail(static_cast<std::uint16_t>(v));
        }
        return true;
    }
};
static_assert(sizeof(MemcpyPacked<1>) == 9 && alignof(MemcpyPacked<1>) == 1);
static_assert(sizeof(MemcpyPacked<2>) == 10 && alignof(MemcpyPacked<2>) == 1);
static_assert(sizeof(Dual64) == 16 && offsetof(Dual64, high) == 8);
#if defined(__SIZEOF_INT128__)
static_assert(sizeof(U128) == 16);
#endif
} // namespace mat003_continuation
