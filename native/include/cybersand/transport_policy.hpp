#pragma once

#include <array>
#include <cstdint>
#include <span>
#include <stdexcept>

namespace cybersand {

// Resolved construction-only descriptor/pair parameters. No strings, parsing,
// lookup allocation, velocity field or mutable per-cell tuning in native jobs.
struct TransportPair {
    std::uint8_t mixing = 0;       // 0..255 successful-motion opportunity fraction
    std::uint8_t carrying = 0;     // 0..255 multiplier of successfully moved Water mass
    std::uint8_t pickup = 64;      // disturbance units
    std::uint8_t packing = 8;      // disturbance units per occupied neighbour (0..32)
    std::uint8_t erosion = 0;      // explicitly allow packed pickup (0/1)
    std::uint8_t permeability = 1; // opportunity period, ticks (1..60)
};

struct TransportPolicy {
    static constexpr std::int32_t version = 1;
    static constexpr std::size_t materials = 81;
    static constexpr std::size_t packed_size = 1 + materials * 2 + materials * materials * 6;
    bool configured = false;
    std::array<std::uint8_t,materials> horizontal{}; // 2 existing, 1 sampled lateral candidate
    std::array<std::uint8_t,materials> cadence{}; // lateral eligibility period, separate from strength
    std::array<TransportPair,materials*materials> pairs{};

    TransportPolicy() { horizontal.fill(2); cadence.fill(1); }
    const TransportPair& pair(std::uint8_t source,std::uint8_t target) const noexcept {
        return pairs[static_cast<std::size_t>(source)*materials+target];
    }
    void validate() const {
        for(auto n:horizontal)if(n<1||n>2)throw std::invalid_argument("Horizontal sampling range");
        for(auto n:cadence)if(n<1||n>60)throw std::invalid_argument("Horizontal cadence range");
        for(std::size_t s=0;s<materials;++s)for(std::size_t t=0;t<materials;++t) {
            const auto& p=pairs[s*materials+t];
            if(p.packing>32||p.erosion>1||p.permeability<1||p.permeability>60)
                throw std::invalid_argument("Transport pair range");
            if(p.carrying && (s!=3 || (t!=2 && t!=14 && t!=29)))
                throw std::invalid_argument("Unscreened liquid/grain carrier pair");
        }
    }
    static TransportPolicy unpack(std::span<const std::int32_t> values) {
        if(values.size()!=packed_size || values[0]!=version) throw std::invalid_argument("Transport profile version/length");
        TransportPolicy p; p.configured=true;
        std::size_t at=1;
        auto take=[&](int minimum,int maximum) {
            const auto value=values[at++];
            if(value<minimum||value>maximum)throw std::invalid_argument("Transport profile value out of range");
            return static_cast<std::uint8_t>(value);
        };
        for(auto& n:p.horizontal)n=take(1,2);
        for(auto& n:p.cadence)n=take(1,60);
        for(auto& pair:p.pairs) {
            pair.mixing=take(0,255);pair.carrying=take(0,255);
            pair.pickup=take(0,255);pair.packing=take(0,32);
            pair.erosion=take(0,1);pair.permeability=take(1,60);
        }
        // Only screened carriers can be enabled in schema v1. Other materials
        // remain editable for non-carrying settings without silently opting in.
        p.validate();
        return p;
    }
};
static_assert(sizeof(TransportPair)==6);
} // namespace cybersand
