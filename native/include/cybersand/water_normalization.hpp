#pragma once

// Construction-time values only: deliberately no World or live-state converter.
#include "cybersand/material.hpp"
#include "cybersand/sha256.hpp"
#include "cybersand/prepared_setup_identity.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <limits>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <type_traits>
#include <utility>
#include <variant>
#include <vector>

namespace cybersand::normalization {

// The caller resolves every rectangle/fill overwrite first. There is exactly
// one tuple per explicit cell; Empty with ambient temperature is canonicalized
// to absence. Empty with a nonambient thermal field remains explicit.
struct FinalSetupCell {
    std::int64_t x = 0, y = 0;
    Material material = Material::Empty;
    std::uint16_t state_a = 0;
    std::uint8_t state_b = 0;
    std::int16_t temperature = 200;
    friend bool operator==(const FinalSetupCell&, const FinalSetupCell&) = default;
};

using SetupDomain = setup::SetupDomain;

// NativeCellFixture means these tuples are the authored input. A registered
// definition digest is only a qualified binding, not evidence of compilation.
struct FinalSetupInput {
    std::uint8_t mass_bits = 8;
    setup::SetupDescriptor setup = [] {
        setup::SetupDescriptor value;
        value.domain = {0,0,1024,1024};
        return value;
    }();
    std::vector<FinalSetupCell> cells;
    // Native temperature lane, exactly -32768..32767 (no floating conversion).
    std::int16_t ambient_temperature = 200;
};

// The admitted native family determines this requirement. Explicit conversion
// is also allowed for a Fractional comparator so both arms share one prepared
// payload. None never normalizes silently. No live World is accepted here.
enum class WaterQuantityRegime : std::uint8_t { Fractional = 0, WholeCell = 1 };
enum class NormalizationOptIn : std::uint8_t { None = 0, WaterNormalizeV1 = 1 };
enum class RefusalCode : std::uint8_t {
    MalformedPolicy, UnknownParameter, CapacityRefused, NormalizationRequired
};
constexpr std::string_view refusal_id(RefusalCode code) noexcept {
    switch (code) {
        case RefusalCode::MalformedPolicy: return "malformed_policy";
        case RefusalCode::UnknownParameter: return "unknown_parameter";
        case RefusalCode::CapacityRefused: return "capacity_refused";
        case RefusalCode::NormalizationRequired: return "normalization_required";
    }
    return "malformed_policy";
}
struct Refusal {
    RefusalCode code = RefusalCode::MalformedPolicy;
    std::optional<std::uint16_t> material;
    std::string detail;
};

// Absolute construction budgets, independent of caller allocation history.
inline constexpr std::uint32_t kMaximumSetupSide = 1024;
inline constexpr std::size_t kMaximumSetupCells = kMaximumSetupSide * kMaximumSetupSide;
struct PreparationLimits {
    std::size_t maximum_cells = kMaximumSetupCells;
};

struct NormalizationTotals {
    std::uint64_t cells_up = 0, cells_down = 0, cells_unchanged = 0;
    std::uint64_t positive_delta = 0, negative_delta = 0;
    std::int64_t net_delta = 0;
    std::uint64_t water_before = 0, water_after = 0;
    friend bool operator==(const NormalizationTotals&, const NormalizationTotals&) = default;
};

namespace detail {
// Checked accumulation also guards future budget changes. These helpers never
// modify the destination on failure.
inline bool add_u64(std::uint64_t& total, std::uint64_t value) noexcept {
    if (value > std::numeric_limits<std::uint64_t>::max() - total) return false;
    total += value;
    return true;
}
inline bool signed_difference(std::uint64_t positive, std::uint64_t negative,
                              std::int64_t& result) noexcept {
    if (positive >= negative) {
        const auto difference = positive - negative;
        if (difference > static_cast<std::uint64_t>(std::numeric_limits<std::int64_t>::max())) return false;
        result = static_cast<std::int64_t>(difference);
    } else {
        const auto difference = negative - positive;
        constexpr auto minimum_magnitude = std::uint64_t{1} << 63U;
        if (difference > minimum_magnitude) return false;
        result = difference == minimum_magnitude ? std::numeric_limits<std::int64_t>::min()
                                                 : -static_cast<std::int64_t>(difference);
    }
    return true;
}

class CanonicalHash {
public:
    template<class Integer> void integer(Integer value) noexcept {
        static_assert(std::is_integral_v<Integer>);
        using Unsigned = std::make_unsigned_t<Integer>;
        const auto unsigned_value = static_cast<std::uint64_t>(static_cast<Unsigned>(value));
        std::array<std::uint8_t, sizeof(Integer)> bytes{};
        for (std::size_t index = 0; index < bytes.size(); ++index)
            bytes[index] = static_cast<std::uint8_t>(unsigned_value >> (8U * index));
        hash_.update(bytes);
    }
    void bytes(std::span<const std::uint8_t> value) noexcept { hash_.update(value); }
    void tag(std::string_view value) noexcept {
        integer(static_cast<std::uint32_t>(value.size()));
        bytes({reinterpret_cast<const std::uint8_t*>(value.data()), value.size()});
    }
    Sha256::Digest finish() noexcept { return hash_.finish(); }
private:
    Sha256 hash_;
};

inline Sha256::Digest native_payload_hash(std::uint8_t mass_bits,
                                std::int16_t ambient_temperature, const SetupDomain& domain,
                                std::span<const FinalSetupCell> row_major_cells) noexcept {
    CanonicalHash out;
    out.tag("cybersand-lcb-final-cell-payload-v1");
    out.integer(std::uint16_t{1});
    out.integer(mass_bits);
    out.integer(ambient_temperature);
    out.integer(domain.x); out.integer(domain.y); out.integer(domain.width); out.integer(domain.height);
    out.integer(static_cast<std::uint64_t>(row_major_cells.size()));
    for (const auto& cell : row_major_cells) {
        out.integer(cell.x); out.integer(cell.y);
        out.integer(static_cast<std::uint8_t>(cell.material));
        out.integer(cell.state_a); out.integer(cell.state_b); out.integer(cell.temperature);
    }
    return out.finish();
}
} // namespace detail

// Exact payload codec for a native capture adapter. Preconditions: validated
// domain/precision, unique row-major cells, canonical ambient Empty omission.
// Prefer PreparedSetup::prepare when those facts are not already established.
inline Sha256::Digest native_payload_digest(std::uint8_t mass_bits, std::int16_t ambient_temperature,
                                           const SetupDomain& domain,
                                           std::span<const FinalSetupCell> row_major_cells) noexcept {
    return detail::native_payload_hash(mass_bits, ambient_temperature, domain, row_major_cells);
}

class Receipt final {
public:
    static constexpr std::uint16_t kSchemaVersion = 1, kRuleVersion = 1;
    static constexpr std::string_view kRule = "water-normalize-v1";
    std::uint8_t mass_bits() const noexcept { return mass_bits_; }
    std::uint64_t seed_before() const noexcept { return seed_; }
    std::uint64_t seed_after() const noexcept { return seed_; }
    const Sha256::Digest& setup_before_hash() const noexcept { return before_; }
    const Sha256::Digest& setup_after_hash() const noexcept { return after_; }
    const Sha256::Digest& payload_before_hash() const noexcept { return payload_before_; }
    const Sha256::Digest& payload_after_hash() const noexcept { return payload_after_; }
    const NormalizationTotals& totals() const noexcept { return totals_; }
    const Sha256::Digest& receipt_hash() const noexcept { return receipt_hash_; }
private:
    friend class PreparedSetup;
    Receipt(std::uint8_t mass_bits, std::uint64_t seed, Sha256::Digest before,
            Sha256::Digest after, Sha256::Digest payload_before, Sha256::Digest payload_after,
            NormalizationTotals totals)
        : mass_bits_(mass_bits), seed_(seed), before_(before), after_(after),
          payload_before_(payload_before), payload_after_(payload_after), totals_(totals) {
        detail::CanonicalHash out;
        out.tag("cybersand-water-normalization-receipt-v1");
        out.integer(kSchemaVersion); out.tag(kRule); out.integer(kRuleVersion);
        out.integer(mass_bits_); out.integer(seed_); out.integer(seed_);
        out.bytes(before_); out.bytes(after_);
        out.bytes(payload_before_); out.bytes(payload_after_);
        out.integer(totals_.cells_up); out.integer(totals_.cells_down); out.integer(totals_.cells_unchanged);
        out.integer(totals_.positive_delta); out.integer(totals_.negative_delta); out.integer(totals_.net_delta);
        out.integer(totals_.water_before); out.integer(totals_.water_after);
        receipt_hash_ = out.finish();
    }
    std::uint8_t mass_bits_ = 0;
    std::uint64_t seed_ = 0;
    Sha256::Digest before_{}, after_{}, receipt_hash_{};
    Sha256::Digest payload_before_{}, payload_after_{};
    NormalizationTotals totals_{};
};

class PreparedSetup final {
public:
    std::uint8_t mass_bits() const noexcept { return mass_bits_; }
    std::uint64_t seed() const noexcept { return descriptor_.seed; }
    std::int16_t ambient_temperature() const noexcept { return ambient_temperature_; }
    const SetupDomain& domain() const noexcept { return descriptor_.domain; }
    const setup::SetupDescriptor& setup_descriptor() const noexcept { return descriptor_; }
    std::span<const FinalSetupCell> final_cells() const noexcept { return cells_; }
    const Sha256::Digest& setup_hash() const noexcept { return setup_hash_; }
    const Sha256::Digest& native_payload_hash() const noexcept { return payload_hash_; }
    const std::optional<Receipt>& normalization_receipt() const noexcept { return receipt_; }
    static std::variant<PreparedSetup, Refusal> prepare(
        const FinalSetupInput& input, WaterQuantityRegime regime, NormalizationOptIn opt_in,
        PreparationLimits limits = {}) {
        const auto refuse = [](RefusalCode code, std::string detail,
                               std::optional<std::uint16_t> material = std::nullopt) {
            return std::variant<PreparedSetup, Refusal>{Refusal{code, material, std::move(detail)}};
        };
        if (input.mass_bits < 3U || input.mass_bits > 8U)
            return refuse(RefusalCode::MalformedPolicy, "Water mass_bits must be 3..8", std::uint16_t{3});
        if (regime != WaterQuantityRegime::Fractional && regime != WaterQuantityRegime::WholeCell)
            return refuse(RefusalCode::UnknownParameter, "unknown Water quantity regime", std::uint16_t{3});
        if (opt_in != NormalizationOptIn::None && opt_in != NormalizationOptIn::WaterNormalizeV1)
            return refuse(RefusalCode::UnknownParameter, "unknown Water setup normalization rule", std::uint16_t{3});
        if (limits.maximum_cells > kMaximumSetupCells || input.cells.size() > limits.maximum_cells)
            return refuse(RefusalCode::CapacityRefused, "final setup exceeds normalization preparation budget");
        try { setup::validate_setup_descriptor(input.setup); }
        catch (const std::invalid_argument& error) {
            return refuse(RefusalCode::MalformedPolicy, error.what());
        }
        const auto& domain = input.setup.domain;
        if (domain.width == 0 || domain.height == 0 || domain.width > kMaximumSetupSide ||
            domain.height > kMaximumSetupSide ||
            domain.x > std::numeric_limits<std::int64_t>::max() - static_cast<std::int64_t>(domain.width - 1U) ||
            domain.y > std::numeric_limits<std::int64_t>::max() - static_cast<std::int64_t>(domain.height - 1U))
            return refuse(RefusalCode::MalformedPolicy, "final setup domain is invalid or exceeds 1024x1024");

        auto cells = input.cells;
        std::sort(cells.begin(), cells.end(), [](const auto& left, const auto& right) {
            return left.y < right.y || (left.y == right.y && left.x < right.x);
        });
        const auto maximum = static_cast<std::uint16_t>((1U << input.mass_bits) - 1U);
        bool fractional_water = false;
        for (std::size_t index = 0; index < cells.size(); ++index) {
            const auto& cell = cells[index];
            const auto material = static_cast<std::uint16_t>(cell.material);
            if (cell.x < domain.x || cell.y < domain.y ||
                static_cast<std::uint64_t>(cell.x) - static_cast<std::uint64_t>(domain.x) >= domain.width ||
                static_cast<std::uint64_t>(cell.y) - static_cast<std::uint64_t>(domain.y) >= domain.height)
                return refuse(RefusalCode::MalformedPolicy, "final setup cell is outside the declared domain", material);
            if (index != 0 && cell.x == cells[index - 1].x && cell.y == cells[index - 1].y)
                return refuse(RefusalCode::MalformedPolicy, "final setup has duplicate coordinates");
            if (!valid_material(material))
                return refuse(RefusalCode::MalformedPolicy, "final setup has an invalid material", material);
            if (cell.material == Material::Empty && (cell.state_a != 0 || cell.state_b != 0))
                return refuse(RefusalCode::MalformedPolicy, "final setup Empty state lanes must be zero", material);
            if (cell.material == Material::Water) {
                if (cell.state_a == 0 || cell.state_a > maximum || cell.state_b > 12U)
                    return refuse(RefusalCode::MalformedPolicy, "final setup Water state is outside its declared domain", std::uint16_t{3});
                fractional_water = fractional_water || cell.state_a != maximum;
            } else if (cell.state_a > 255U) {
                return refuse(RefusalCode::MalformedPolicy, "final setup non-Water state_a exceeds byte domain", material);
            }
        }
        if (regime == WaterQuantityRegime::WholeCell && fractional_water && opt_in == NormalizationOptIn::None)
            return refuse(RefusalCode::NormalizationRequired,
                          "fractional Water setup requires explicit water-normalize-v1 opt-in", std::uint16_t{3});
        std::erase_if(cells, [&](const auto& cell) {
            return cell.material == Material::Empty && cell.temperature == input.ambient_temperature;
        });

        PreparedSetup result;
        result.mass_bits_ = input.mass_bits;
        result.ambient_temperature_ = input.ambient_temperature;
        result.descriptor_ = input.setup;
        const auto payload_before = detail::native_payload_hash(input.mass_bits, result.ambient_temperature_,
                                                               result.descriptor_.domain, cells);
        const auto before = setup::prepared_setup_identity(result.descriptor_, payload_before);
        NormalizationTotals totals;
        const bool apply_rule = opt_in == NormalizationOptIn::WaterNormalizeV1;
        if (apply_rule) {
            result.cells_.reserve(cells.size());
            for (auto cell : cells) {
                if (cell.material != Material::Water) { result.cells_.push_back(cell); continue; }
                if (!detail::add_u64(totals.water_before, cell.state_a))
                    return refuse(RefusalCode::CapacityRefused, "normalization before-quantity overflow", std::uint16_t{3});
                if (cell.state_a == maximum) {
                    if (!detail::add_u64(totals.cells_unchanged, 1) || !detail::add_u64(totals.water_after, maximum))
                        return refuse(RefusalCode::CapacityRefused, "normalization unchanged counter overflow", std::uint16_t{3});
                    result.cells_.push_back(cell);
                } else if (std::uint32_t{2} * cell.state_a >= maximum) {
                    if (!detail::add_u64(totals.cells_up, 1) ||
                        !detail::add_u64(totals.positive_delta, maximum - cell.state_a) ||
                        !detail::add_u64(totals.water_after, maximum))
                        return refuse(RefusalCode::CapacityRefused, "normalization up counter overflow", std::uint16_t{3});
                    cell.state_a = maximum;
                    result.cells_.push_back(cell);
                } else {
                    if (!detail::add_u64(totals.cells_down, 1) || !detail::add_u64(totals.negative_delta, cell.state_a))
                        return refuse(RefusalCode::CapacityRefused, "normalization down counter overflow", std::uint16_t{3});
                    // Empty retains the existing thermal field, exactly as a
                    // native material write does. Canonical ambient Empty is
                    // absent; nonambient Empty is authoritative and explicit.
                    if (cell.temperature != input.ambient_temperature) {
                        cell.material = Material::Empty;
                        cell.state_a = 0;
                        cell.state_b = 0;
                        result.cells_.push_back(cell);
                    }
                }
            }
            if (!detail::signed_difference(totals.positive_delta, totals.negative_delta, totals.net_delta))
                return refuse(RefusalCode::CapacityRefused, "normalization signed delta overflow", std::uint16_t{3});
        } else {
            result.cells_ = std::move(cells);
        }
        result.payload_hash_ = detail::native_payload_hash(input.mass_bits, result.ambient_temperature_,
                                                          result.descriptor_.domain, result.cells_);
        result.setup_hash_ = setup::prepared_setup_identity(result.descriptor_, result.payload_hash_);
        if (apply_rule)
            result.receipt_ = Receipt(input.mass_bits, input.setup.seed, before, result.setup_hash_,
                                      payload_before, result.payload_hash_, totals);
        return result;
    }
private:
    PreparedSetup() = default;
    std::uint8_t mass_bits_ = 0;
    std::int16_t ambient_temperature_ = 200;
    setup::SetupDescriptor descriptor_;
    std::vector<FinalSetupCell> cells_;
    Sha256::Digest setup_hash_{}, payload_hash_{};
    std::optional<Receipt> receipt_;
};

} // namespace cybersand::normalization
