#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <optional>

namespace cybersand {

// Native accounting schema. Quantities use the World's Water mass quantum;
// material populations are separate cell counts, never mass estimates.
inline constexpr std::uint16_t kQuantityLedgerSchemaVersion = 1;
inline constexpr std::size_t kQuantityMaterialSlots = 256;
inline constexpr std::size_t kQuantityPairRuleSlots = 56;
inline constexpr std::size_t kQuantityKernelRuleSlots = 19;
using QuantityDigest = std::array<std::uint8_t, 32>;

enum class QuantityKind : std::uint8_t {
    SetupNormalization = 0,
    ExternalEdit = 1,
    GeneratedChunk = 2,
    DeferredEvent = 3,
    PairReaction = 4,
    KernelConversion = 5,
    Count = 6,
};
inline constexpr std::size_t kQuantityKindCount = static_cast<std::size_t>(QuantityKind::Count);
inline constexpr std::uint16_t kQuantityNoRule = std::numeric_limits<std::uint16_t>::max();

struct WaterQuantityFlow {
    std::uint64_t produced = 0;
    std::uint64_t consumed = 0;
    friend bool operator==(const WaterQuantityFlow&, const WaterQuantityFlow&) = default;
};

struct QuantityCause {
    QuantityKind kind = QuantityKind::KernelConversion;
    std::uint16_t rule = kQuantityNoRule;
};

// Only the private World initializer accepts this value. PreparedWorldBuilder
// verifies its digests against the actual unexposed candidate before calling.
struct QuantityConstructionSeed {
    std::uint8_t mass_bits = 0;
    std::uint64_t baseline_water = 0;
    std::uint64_t normalization_produced = 0;
    std::uint64_t normalization_consumed = 0;
    std::uint64_t expected_final_water = 0;
    QuantityDigest original_setup_identity{};
    QuantityDigest prepared_setup_identity{};
    QuantityDigest original_payload_digest{};
    QuantityDigest prepared_payload_digest{};
    std::optional<QuantityDigest> normalization_receipt_digest;
    friend bool operator==(const QuantityConstructionSeed&, const QuantityConstructionSeed&) = default;
};

struct QuantityLedgerSnapshot {
    std::uint16_t schema_version = kQuantityLedgerSchemaVersion;
    std::uint8_t mass_bits = 0;
    std::uint64_t baseline_water = 0;
    std::uint64_t water_visible = 0;
    std::uint64_t water_overfill = 0;
    std::array<WaterQuantityFlow, kQuantityKindCount> kinds{};
    std::array<WaterQuantityFlow, kQuantityPairRuleSlots> pair_rules{};
    std::array<std::uint64_t, kQuantityPairRuleSlots> pair_events{};
    std::array<WaterQuantityFlow, kQuantityKernelRuleSlots> kernel_rules{};
    // Empty (0) and invalid catalogue slots remain zero. Stored cells under
    // transient body masks and outside the simulation region still count.
    std::array<std::uint64_t, kQuantityMaterialSlots> material_cells{};
    std::array<std::uint64_t, kQuantityMaterialSlots> prepared_material_cells{};
    std::optional<QuantityConstructionSeed> construction;
    friend bool operator==(const QuantityLedgerSnapshot&, const QuantityLedgerSnapshot&) = default;
};

namespace quantity_ledger_detail {
// Fixed scratch stored once per admitted scheduling slot, never allocated by a
// kernel. Only the owning job writes it; the owner merges after its barrier.
struct JobDelta {
    std::int64_t visible = 0;
    std::int64_t overfill = 0;
    std::array<std::int64_t, kQuantityMaterialSlots> material_cells{};
    std::array<WaterQuantityFlow, kQuantityKindCount> kinds{};
    std::array<WaterQuantityFlow, kQuantityPairRuleSlots> pair_rules{};
    std::array<std::uint64_t, kQuantityPairRuleSlots> pair_events{};
    std::array<WaterQuantityFlow, kQuantityKernelRuleSlots> kernel_rules{};
    bool overflow = false;
};
} // namespace quantity_ledger_detail

} // namespace cybersand
