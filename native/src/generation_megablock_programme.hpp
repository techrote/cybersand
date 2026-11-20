#pragma once
#include <cstdint>

// Private to this exemplar and its qualification tools; not a recipe/runtime API.
namespace cybersand::generation::megablock {
constexpr std::uint64_t hash_lane = 0x4d454741U;
enum class Typology { Core, Atrium, Bridge, Buttress, Arcade, OpenFrame, Cantilever, Habitation, Crown };
struct Programme {
    int core, atrium, support, spare, bridge_band;
    std::uint64_t choices;
};
inline Programme programme(std::uint64_t hash) noexcept {
    const auto core = static_cast<int>(hash & 3U);
    const int atrium = (core == 0 || core == 2) ? 1 : 2;
    const int support = 2 * atrium - core;
    return {core, atrium, support, 6 - core - atrium - support,
        1 + static_cast<int>((hash >> 2U) & 1U), hash >> 3U};
}
inline Typology typology(const Programme& p, int column, int band) noexcept {
    // Outside this supercell is an intentionally terminated interface. The lower
    // transfer slab alone is universal across supercells; no recursive lookup.
    if (column < 0 || column > 3) return Typology::Atrium;
    if (column == p.core) return Typology::Core;
    if (column == p.atrium) {
        if (band == 3) return Typology::Arcade;
        return band == p.bridge_band ? Typology::Bridge : Typology::Atrium;
    }
    if (band == 0) return Typology::Crown;
    if (band == 3) return column == p.support || (p.choices & 4U) ? Typology::Buttress : Typology::Arcade;
    if (column == p.support)
        return band != p.bridge_band || (p.choices & 1U) ? Typology::Habitation : Typology::OpenFrame;
    if (band == p.bridge_band) return (p.choices & 2U) ? Typology::OpenFrame : Typology::Cantilever;
    return (p.choices & 8U) ? Typology::Habitation : Typology::OpenFrame;
}
inline const char* name(Typology t) noexcept {
    switch (t) {
        case Typology::Core: return "core";
        case Typology::Atrium: return "atrium";
        case Typology::Bridge: return "bridge";
        case Typology::Buttress: return "buttress";
        case Typology::Arcade: return "arcade";
        case Typology::OpenFrame: return "open_frame";
        case Typology::Cantilever: return "cantilever";
        case Typology::Habitation: return "habitation";
        case Typology::Crown: return "crown";
    }
    return "invalid";
}
} // namespace cybersand::generation::megablock
