#pragma once

#include "cybersand/material.hpp"
#include "cybersand/sha256.hpp"

#include <array>
#include <cstddef>
#include <cstdint>

// BS-001 ballistic_solids_v1 (experimental, opt-in, #361 follow-up). "Solids"
// covers every whole-cell material that can fly: powders, breakable solids and
// non-Water liquids.
//
// A bounded, World-owned pool of whole solid/powder cells in flight, the
// granular counterpart of BW-001 ballistic Water. A serialized owner may move
// one admitted grid cell (material and state) into a flying solid (launch) or
// inject one from an external stock such as workbench equipment. Solids advance
// serially at tick entry with gravity, drag, swept terrain/body/liquid contact
// and land back in the grid as ordinary cells. On reaching a liquid they settle
// on its free surface, so the material's own native density exchange then makes
// it sink. Body contacts add to the same per-body impulse counters as ballistic
// Water. Every cell always has exactly one owner: the grid or a live solid.
// Requires ballistic Water in the same World. Disabled by default; a World
// without it keeps its hash, persistence and ledger bytes unchanged.
namespace cybersand {

struct BallisticSolidsConfig {
    static constexpr std::uint16_t kVersion = 1;
    static constexpr std::uint32_t kMaximumCapacity = 65'536;
    static constexpr std::int32_t kWaterDensity = 1'000;
    static constexpr std::int32_t kWaterMass = 255;

    bool enabled = false;
    std::uint32_t capacity = 4'096;          // solid slots reserved at construction
    std::int32_t gravity_q = 22;             // +vy per tick (q / tick^2), a little heavier than Water
    std::int32_t max_speed_q = 1'536;        // per-axis |v| cap (6 cells / tick)
    std::int32_t air_drag = 1;               // per-tick drag numerator / 256
    std::int32_t restitution = 56;           // normal rebound on hard contact, / 256
    std::int32_t friction = 160;             // tangential Coulomb coefficient, / 256
    std::int32_t settle_speed_q = 72;        // at or below this after contact: land
    std::uint32_t maximum_age_ticks = 900;   // forced landing attempt
    std::uint32_t maximum_contacts = 4;      // rebounds before forced landing

    [[nodiscard]] friend bool operator==(const BallisticSolidsConfig&, const BallisticSolidsConfig&) = default;
};

struct BallisticSolid {
    std::int64_t x = 0, y = 0;     // q256 coordinates (BallisticWaterConfig::kQ)
    std::int32_t vx = 0, vy = 0;   // signed q per tick (negative vy is upward)
    std::uint16_t material = 0;    // admitted Material identifier
    std::uint16_t state_a = 0;     // the cell's own state, restored on landing
    std::uint8_t state_b = 0;
    std::uint8_t contacts = 0;     // hard rebounds so far
    std::uint8_t deferrals = 0;    // saturating landing refusals
    std::uint16_t source_body = 0; // launching transient body id; 0 = none
    std::uint32_t age = 0;         // completed flight ticks
    [[nodiscard]] friend bool operator==(const BallisticSolid&, const BallisticSolid&) = default;
};

// Cell accounting: in_flight == launched + injected - landed. Per-material
// in-flight counts are recomputed from the live solids by the validator.
struct BallisticSolidsLedger {
    std::uint64_t launched = 0, injected = 0, landed = 0;
    std::uint64_t deferred_landings = 0, refused_launches = 0, forced_landings = 0;
    std::uint64_t surface_landings = 0; // landed on a liquid's free surface
    std::uint64_t terrain_contacts = 0, body_contacts = 0, liquid_contacts = 0, boundary_contacts = 0;
    std::uint64_t solid_ticks = 0, cell_steps = 0, maximum_live = 0;
    std::int64_t body_px = 0, body_py = 0; // mass * q-velocity offered to bodies
    [[nodiscard]] friend bool operator==(const BallisticSolidsLedger&, const BallisticSolidsLedger&) = default;
};

struct BallisticSolidsSnapshot {
    bool enabled = false;
    std::uint64_t last_advance_nanoseconds = 0; // diagnostic only, never hashed or persisted
    std::uint32_t live = 0;
    std::uint32_t capacity = 0;
    BallisticSolidsLedger ledger{};
};

// Powders always; other solids unless they are structural walls; and every
// non-Water liquid (Oil, Lava, Acid, Brine, Mercury, ...), which are whole-cell
// materials and fly as their cell. Water flies through BW-001 parcels instead.
// Gases, agents and Empty never fly.
[[nodiscard]] constexpr bool ballistic_solid_admitted(Material material) noexcept {
    const auto id = static_cast<std::size_t>(material);
    if (id >= kMaterialDefinitions.size()) return false;
    const auto& d = kMaterialDefinitions[id];
    if (!d.valid) return false;
    if (material == Material::Wall || material == Material::ReinforcedConcrete) return false;
    if (d.state == MaterialState::Powder) return true;
    if (d.state == MaterialState::Liquid) return material != Material::Water;
    return d.state == MaterialState::Solid && d.density < 65'535;
}

// Momentum weight of one flying cell, density-scaled so a Water-density cell
// weighs exactly one full ballistic Water parcel (255).
[[nodiscard]] constexpr std::int64_t ballistic_solid_mass(Material material) noexcept {
    const auto id = static_cast<std::size_t>(material);
    const auto density = id < kMaterialDefinitions.size() ? kMaterialDefinitions[id].density : 0U;
    const auto mass = static_cast<std::int64_t>(density) * BallisticSolidsConfig::kWaterMass /
                      BallisticSolidsConfig::kWaterDensity;
    return mass < 1 ? 1 : (mass > 4'096 ? 4'096 : mass);
}

[[nodiscard]] inline Sha256::Digest ballistic_solids_identity(const BallisticSolidsConfig& c) noexcept {
    Sha256 hash;
    constexpr char domain[] = "cybersand-ballistic-solids-v1-identity-v1";
    hash.update({reinterpret_cast<const std::uint8_t*>(domain), sizeof(domain) - 1U});
    for (const std::int64_t value :
         {std::int64_t{BallisticSolidsConfig::kVersion}, std::int64_t{c.capacity}, std::int64_t{c.gravity_q},
          std::int64_t{c.max_speed_q}, std::int64_t{c.air_drag}, std::int64_t{c.restitution},
          std::int64_t{c.friction}, std::int64_t{c.settle_speed_q}, std::int64_t{c.maximum_age_ticks},
          std::int64_t{c.maximum_contacts}}) {
        std::array<std::uint8_t, 8> bytes{};
        for (unsigned i = 0; i < 8; ++i)
            bytes[i] = static_cast<std::uint8_t>(static_cast<std::uint64_t>(value) >> (8U * i));
        hash.update(bytes);
    }
    return hash.finish();
}

} // namespace cybersand
