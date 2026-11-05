#pragma once

#include "cybersand/sha256.hpp"

#include <array>
#include <cstddef>
#include <cstdint>

// BW-001 ballistic_water_v1 (experimental, opt-in, #362/#20 bounded prototype).
//
// A bounded, World-owned pool of quantity-denominated Water parcels in flight.
// Bulk Water keeps its selected liquid family (FreeMass, CellularYield,
// PressureFlow or InertialCellular). A serialized owner may atomically move a
// Water cell's exact quantity into one parcel (launch) or inject sourced Water
// (a booked external source). Parcels advance serially at tick entry with
// signed fixed-point velocity, gravity, drag, swept terrain/body/liquid contact
// and bounded deposition back into the grid. Every quantity unit always has
// exactly one owner: grid cells or a live parcel. Disabled by default; a
// disabled World is byte-for-byte unaffected (hash/format/ledger schema).
namespace cybersand {

struct BallisticWaterConfig {
    static constexpr std::uint16_t kVersion = 1;
    static constexpr std::int32_t kQ = 256;  // position and velocity units per cell
    static constexpr std::uint32_t kMaximumCapacity = 65'536;
    static constexpr std::uint32_t kSelfContactGraceTicks = 4;

    bool enabled = false;
    std::uint32_t capacity = 4'096;          // parcel slots reserved at construction
    std::int32_t gravity_q = 18;             // +vy per tick (q / tick^2); ~0.07 cells / tick^2
    std::int32_t max_speed_q = 1'536;        // per-axis |v| cap (6 cells / tick)
    std::int32_t air_drag = 2;               // per-tick drag numerator / 256
    std::int32_t restitution = 72;           // normal rebound on hard contact, / 256
    std::int32_t friction = 128;             // tangential Coulomb coefficient (of the normal impulse), / 256
    std::int32_t settle_speed_q = 64;        // at or below this after contact: deposit
    std::uint32_t maximum_age_ticks = 900;   // forced deposition attempt (no immortal parcels)
    std::int32_t deposit_radius = 2;         // bounded Chebyshev deposition search
    std::uint32_t maximum_contacts = 6;      // rebounds before forced deposition
    // WCX-FR face release (experimental, off by default): a Water cell on a tall
    // vertical face (an Empty side neighbour beside a column of at least
    // face_min_height Water rows) may leave as a parcel at dam-break speed
    // face_speed / 256 * sqrt(2 g h). Serialized, deterministic, budgeted.
    bool face_release = false;
    std::int32_t face_min_height = 6;
    std::uint32_t face_budget = 48;          // releases per tick
    std::int32_t face_speed = 192;           // / 256 of sqrt(2 g h)
    std::uint32_t face_period = 3;           // a column sheds at most once per period ticks
    // A fast grazing parcel meeting a one-cell Water film slides over it
    // (Coulomb contact) instead of merging at once; it merges once slow.
    bool film_skim = true;

    [[nodiscard]] friend bool operator==(const BallisticWaterConfig&, const BallisticWaterConfig&) = default;
};

struct BallisticParcel {
    std::int64_t x = 0, y = 0;     // q coordinates; a cell's centre is cell * kQ + kQ / 2
    std::int32_t vx = 0, vy = 0;   // signed q per tick (negative vy is upward)
    std::uint32_t quantity = 0;    // exact Water quantity in the World's mass quantum
    std::uint32_t age = 0;         // completed flight ticks
    std::uint16_t source_body = 0; // launching transient body id; 0 = none
    std::uint8_t contacts = 0;     // hard rebounds so far
    std::uint8_t deferrals = 0;    // saturating deposition refusals
    [[nodiscard]] friend bool operator==(const BallisticParcel&, const BallisticParcel&) = default;
};

enum class BallisticLaunchOutcome : std::uint8_t {
    Launched = 0,
    Disabled,
    WorldFailed,
    TickInProgress,
    InvalidRequest,
    NotWater,
    Masked,
    CapacityFull,
    Pressurized,
    NonResident,
    InsufficientQuantity,
};

struct BallisticLaunchResult {
    BallisticLaunchOutcome outcome = BallisticLaunchOutcome::InvalidRequest;
    std::uint32_t quantity = 0;
    std::uint32_t live = 0;
};

// Exact integer accounting. Quantity closes as
//   in_flight == launched + injected - deposited
// and parcel momentum (quantity * q-velocity) per component closes as
//   sum(q * v) == launch + gravity + drag + contact + clamp - deposit.
// body_* is the part of contact momentum removed from parcels at body contacts
// (the opposite impulse is offered to the body owner); it is included in contact.
struct BallisticLedger {
    std::uint64_t launched_parcels = 0, launched_quantity = 0;
    std::uint64_t injected_parcels = 0, injected_quantity = 0;
    std::uint64_t deposited_parcels = 0, deposited_quantity = 0, deposit_writes = 0;
    std::uint64_t deferred_deposits = 0, refused_launches = 0, forced_deposits = 0;
    std::uint64_t column_deposits = 0; // writes reached through an engulfing Water column
    std::uint64_t face_releases = 0;   // WCX-FR face cells released (a subset of launched)
    std::uint64_t film_skims = 0;      // grazing contacts that slid over a one-cell Water film
    std::uint64_t terrain_contacts = 0, body_contacts = 0, surface_entries = 0;
    std::uint64_t ceiling_contacts = 0, boundary_contacts = 0;
    std::uint64_t parcel_ticks = 0, cell_steps = 0, maximum_live = 0;
    std::int64_t launch_px = 0, launch_py = 0;
    std::int64_t gravity_py = 0;
    std::int64_t drag_px = 0, drag_py = 0;
    std::int64_t contact_px = 0, contact_py = 0;
    std::int64_t body_px = 0, body_py = 0;
    std::int64_t clamp_px = 0, clamp_py = 0;
    std::int64_t deposit_px = 0, deposit_py = 0;
    [[nodiscard]] friend bool operator==(const BallisticLedger&, const BallisticLedger&) = default;
};

struct BallisticWaterSnapshot {
    bool enabled = false;
    // Diagnostic wall time of the last tick's serial parcel pass; never hashed,
    // persisted or used by simulation.
    std::uint64_t last_advance_nanoseconds = 0;
    std::uint32_t live = 0;
    std::uint32_t capacity = 0;
    std::uint64_t in_flight_quantity = 0;
    std::int64_t momentum_x = 0, momentum_y = 0;
    BallisticLedger ledger{};
};

// Binds every law constant and tunable value; canonical LE int32 after a domain.
[[nodiscard]] inline Sha256::Digest ballistic_water_identity(const BallisticWaterConfig& c) noexcept {
    Sha256 hash;
    constexpr char domain[] = "cybersand-ballistic-water-v1-parcel-v1-identity-v1";
    hash.update({reinterpret_cast<const std::uint8_t*>(domain), sizeof(domain) - 1U});
    for (const std::int64_t value :
         {std::int64_t{BallisticWaterConfig::kVersion}, std::int64_t{BallisticWaterConfig::kQ},
          std::int64_t{BallisticWaterConfig::kSelfContactGraceTicks}, std::int64_t{c.capacity},
          std::int64_t{c.gravity_q}, std::int64_t{c.max_speed_q}, std::int64_t{c.air_drag},
          std::int64_t{c.restitution}, std::int64_t{c.friction}, std::int64_t{c.settle_speed_q},
          std::int64_t{c.maximum_age_ticks}, std::int64_t{c.deposit_radius}, std::int64_t{c.maximum_contacts},
          std::int64_t{c.face_release}, std::int64_t{c.face_min_height}, std::int64_t{c.face_budget},
          std::int64_t{c.face_speed}, std::int64_t{c.face_period}, std::int64_t{c.film_skim}}) {
        std::array<std::uint8_t, 8> bytes{};
        for (unsigned i = 0; i < 8; ++i)
            bytes[i] = static_cast<std::uint8_t>(static_cast<std::uint64_t>(value) >> (8U * i));
        hash.update(bytes);
    }
    return hash.finish();
}

} // namespace cybersand
