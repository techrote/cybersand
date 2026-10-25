#pragma once

#include "cybersand/liquid_policy_catalogue.hpp"
#include "cybersand/sha256.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <type_traits>
#include <utility>
#include <vector>

// LCB-001 (#200) foundation: immutable, versioned per-World/per-material liquid
// solver policy, its wire envelope, validation precedence, canonical identity and
// applied readback. The contract is docs/architecture/liquid-solver-family-policy.md
// ("Request envelope and canonical hash"); tools/lcb/policy_contract.py is its
// executable oracle and the native tests replay its registered vectors.
//
// The running build qualifies Current defaults and explicit opt-in cells;
// every other mapping refuses before World storage is built. Policy admission
// never silently falls back, and no production Cell ABI is frozen here.
namespace cybersand {

namespace liquid_policy_detail {

// Append-only text assembly. GCC 13 inlines `literal + std::string&&` as a
// front insertion that imports basic_string::_M_replace_cold@GLIBCXX_3.4.31,
// above the published Linux runtime floor (tools/check_linux_runtime_floor.sh).
inline void append_part(std::string& out, std::string_view part) { out.append(part.data(), part.size()); }

template <typename Integer>
    requires std::is_integral_v<Integer>
inline void append_part(std::string& out, Integer value) {
    const auto text = std::to_string(value);
    out.append(text.data(), text.size());
}

template <typename... Parts>
[[nodiscard]] std::string concat(const Parts&... parts) {
    std::string out;
    (append_part(out, parts), ...);
    return out;
}

}  // namespace liquid_policy_detail

enum class LiquidSolverFamily : std::uint8_t {
    MaterialDefault = 0, // request-only: never applied, hashed or read back
    FreeMassV1 = 1,
    CellularYieldV1 = 2,
    PressureFlowV1 = 3,
    InertialCellularV1 = 4,
};

enum class LiquidSolverVariant : std::uint8_t {
    Reference = 0,
    Cached = 1,
    CachedDormant = 2,
};

// Append-only; the order follows the oracle's REFUSAL_CODES after None.
enum class LiquidPolicyRefusalCode : std::uint8_t {
    None = 0,
    UnknownMaterial,
    NotALiquid,
    UnknownFamily,
    UnknownVariant,
    FamilyUnavailable,
    CombinationRejected,
    VariantUnsupported,
    WaterSemanticsIncompatible,
    PlatformUnsupported,
    CapacityRefused,
    StaleCapabilityMatrix,
    MalformedPolicy,
    UnknownParameter,
    NotSelectable,
    NormalizationRequired,
};

[[nodiscard]] constexpr std::string_view liquid_policy_refusal_id(LiquidPolicyRefusalCode code) noexcept {
    constexpr std::array<std::string_view, 16> kIds{
        "none", "unknown_material", "not_a_liquid", "unknown_family", "unknown_variant",
        "family_unavailable", "combination_rejected", "variant_unsupported",
        "water_semantics_incompatible", "platform_unsupported", "capacity_refused",
        "stale_capability_matrix", "malformed_policy", "unknown_parameter", "not_selectable",
        "normalization_required"};
    const auto index = static_cast<std::size_t>(code);
    return index < kIds.size() ? kIds[index] : std::string_view{"unknown"};
}

[[nodiscard]] constexpr std::string_view liquid_solver_family_id(LiquidSolverFamily family) noexcept {
    switch (family) {
        case LiquidSolverFamily::MaterialDefault: return "material_default";
        case LiquidSolverFamily::FreeMassV1: return "freemass_v1";
        case LiquidSolverFamily::CellularYieldV1: return "cellular_yield_v1";
        case LiquidSolverFamily::PressureFlowV1: return "pressure_flow_v1";
        case LiquidSolverFamily::InertialCellularV1: return "inertial_cellular_v1";
    }
    return "unknown";
}

[[nodiscard]] constexpr std::string_view liquid_solver_variant_id(LiquidSolverVariant variant) noexcept {
    switch (variant) {
        case LiquidSolverVariant::Reference: return "reference";
        case LiquidSolverVariant::Cached: return "cached";
        case LiquidSolverVariant::CachedDormant: return "cached_dormant";
    }
    return "unknown";
}

struct LiquidPolicyRefusal {
    LiquidPolicyRefusalCode code = LiquidPolicyRefusalCode::None;
    std::optional<std::uint16_t> material;
    std::string detail;

    [[nodiscard]] std::string message() const {
        return liquid_policy_detail::concat(liquid_policy_refusal_id(code), ": ", detail);
    }
};

// A refused construction. Thrown before any World state is allocated.
class LiquidPolicyRefused final : public std::invalid_argument {
public:
    explicit LiquidPolicyRefused(LiquidPolicyRefusal refusal)
        : std::invalid_argument(liquid_policy_detail::concat("liquid solver policy refused: ", refusal.message())),
          refusal_(std::move(refusal)) {}
    [[nodiscard]] const LiquidPolicyRefusal& refusal() const noexcept { return refusal_; }

private:
    LiquidPolicyRefusal refusal_;
};

struct LiquidParameterField {
    std::string_view name;
    std::int64_t minimum = 0;
    std::int64_t maximum = 0;
};

// A typed parameter block a family (or a material under its applied family)
// declares. Running-build schemas and illustrative contract-test schemas are
// separately registered; matching a block version never changes its meaning.
struct LiquidParameterSchema {
    bool family_owner = true;
    std::uint16_t owner = 0;
    std::uint16_t version = 0;
    bool mandatory = false;
    std::uint8_t requires_family = 0; // material blocks only
    std::vector<LiquidParameterField> fields;
};

// What a running (or contract-test) build compiled and qualified.
struct LiquidPolicyBuild {
    Sha256::Digest catalogue_digest = liquid_policy_catalogue::kCatalogueDigest;
    Sha256::Digest capability_matrix_digest = liquid_policy_catalogue::kCapabilityMatrixDigest;
    std::uint8_t available_families = 0; // bit (family code - 1)
    bool native = true;
    // When set, admission is further limited to these (material, family) cells.
    bool cell_qualified = true;
    std::vector<std::pair<std::uint16_t, std::uint8_t>> qualified_cells;
    // When non-empty, a qualified cell admits only the listed variants (bit =
    // variant code). Contract builds leave it empty: every matrix variant.
    struct QualifiedVariants {
        std::uint16_t material = 0;
        std::uint8_t family = 0;
        std::uint8_t variant_mask = 0;
    };
    std::vector<QualifiedVariants> qualified_variants;
    std::vector<LiquidParameterSchema> schemas;

    // pressure_flow_v1 optional family block v1 (LCB-001 #200): gas topology on/off
    // and the atmospheric pressure expressed in rows of saturated Water head.
    static constexpr std::uint16_t kPressureBlockVersion = 1;
    static constexpr std::int32_t kPressureDefaultGasEnabled = 1;
    static constexpr std::int32_t kPressureDefaultAtmosphericRows = 32;
    static constexpr std::uint16_t kWaterCellularYieldBlockVersion = 2;
    // IN v1 remains the historical illustrative schema; v2 is the native law.
    static constexpr std::uint16_t kInertialBlockVersion = 2;

    // This binary: FreeMass and CellularYield qualified for each liquid's current
    // default, plus Water x pressure_flow_v1/reference and whole-cell
    // cellular_yield_v1/reference (#200), Brine IN/reference (#212), and
    // cached/cached_dormant pressure implementations (#201). Other cells refuse.
    [[nodiscard]] static const LiquidPolicyBuild& running() {
        static const LiquidPolicyBuild build = [] {
            LiquidPolicyBuild result;
            result.available_families = 0x0FU;
            for (const auto& row : liquid_policy_catalogue::kLiquidRows) {
                result.qualified_cells.emplace_back(row.material_id, row.default_family);
                result.qualified_variants.push_back({row.material_id, row.default_family, 0x01U});
            }
            result.qualified_cells.emplace_back(std::uint16_t{3}, std::uint8_t{3});
            result.qualified_variants.push_back({3, 3, 0x07U});
            result.qualified_cells.emplace_back(std::uint16_t{3}, std::uint8_t{2});
            result.qualified_variants.push_back({3, 2, 0x01U});
            result.qualified_cells.emplace_back(std::uint16_t{24},std::uint8_t{4});
            result.qualified_variants.push_back({24,4,0x01U});
            result.qualified_cells.emplace_back(std::uint16_t{3},std::uint8_t{4});
            result.qualified_variants.push_back({3,4,0x01U});
            result.schemas.push_back({true, 3, kPressureBlockVersion, false, 0,
                                      {{"gas_enabled", 0, 1}, {"atmospheric_head_rows", 16, 4096}}});
            result.schemas.push_back({false, 3, kWaterCellularYieldBlockVersion, false, 2,
                                      {{"viscosity_index", 0, 255}}});
            result.schemas.push_back({true, 4, kInertialBlockVersion, false, 0,
                                      {{"damping_numerator", 0, 16}}});
            return result;
        }();
        return build;
    }
};

struct LiquidSolverAssignment {
    std::uint16_t material = 0;
    LiquidSolverFamily requested_family = LiquidSolverFamily::MaterialDefault;
    LiquidSolverFamily family = LiquidSolverFamily::MaterialDefault;
    LiquidSolverVariant variant = LiquidSolverVariant::Reference;

    [[nodiscard]] friend bool operator==(const LiquidSolverAssignment& a, const LiquidSolverAssignment& b) noexcept {
        return a.material == b.material && a.family == b.family && a.variant == b.variant;
    }
};

struct LiquidParameterBlock {
    std::uint16_t owner = 0;
    std::uint16_t version = 0;
    std::vector<std::int32_t> values;

    [[nodiscard]] friend bool operator==(const LiquidParameterBlock&, const LiquidParameterBlock&) = default;
};

class LiquidSolverPolicy;
struct LiquidPolicyDecodeResult;
template <typename Word>
class LiquidPolicyDecoder;

// Immutable once constructed. Only the running-build default constructor and a
// successful decode produce one, so every instance is a validated, normalized
// applied policy. Equality is canonical identity (requested codes excluded).
class LiquidSolverPolicy final {
public:
    static constexpr std::int32_t kMagic = 0x4C435057; // "LCPW"
    static constexpr std::int32_t kEnvelopeVersion = 1;
    static constexpr std::uint16_t kPolicyVersion = 1;
    static constexpr std::size_t kDigestWords = 8;
    static constexpr std::size_t kHeaderWords = 3 + 2 * kDigestWords;
    static constexpr std::size_t kMaximumBlockWords = 64;
    static constexpr std::uint16_t kReservedMaterial = 10;
    static constexpr std::size_t kFamilyCount = 4;
    static constexpr std::size_t kVariantCount = 3;
    static constexpr std::size_t kLiquidCount = liquid_policy_catalogue::kLiquidRows.size();

    // Every liquid on its current default family/reference variant for this binary.
    LiquidSolverPolicy() : LiquidSolverPolicy(running_default()) {}

    template <typename Word>
    [[nodiscard]] static LiquidPolicyDecodeResult decode(
        std::span<const Word> words, const LiquidPolicyBuild& build = LiquidPolicyBuild::running());

    // The explicit default request envelope for a build (what a host sends to
    // ask for "current defaults" with the build's own identity).
    [[nodiscard]] static std::vector<std::int32_t> default_request(
        const LiquidPolicyBuild& build = LiquidPolicyBuild::running()) {
        return default_for(build).envelope();
    }

    [[nodiscard]] std::uint16_t policy_version() const noexcept { return policy_version_; }
    [[nodiscard]] const Sha256::Digest& catalogue_digest() const noexcept { return catalogue_digest_; }
    [[nodiscard]] const Sha256::Digest& capability_matrix_digest() const noexcept { return capability_matrix_digest_; }
    [[nodiscard]] std::span<const LiquidSolverAssignment> assignments() const noexcept { return assignments_; }
    [[nodiscard]] std::span<const LiquidParameterBlock> family_blocks() const noexcept { return family_blocks_; }
    [[nodiscard]] std::span<const LiquidParameterBlock> material_blocks() const noexcept { return material_blocks_; }
    [[nodiscard]] const Sha256::Digest& policy_hash() const noexcept { return hash_; }
    [[nodiscard]] std::string policy_hash_hex() const { return Sha256::hex(hash_); }

    [[nodiscard]] std::optional<LiquidSolverAssignment> assignment(std::uint16_t material) const noexcept {
        for (const auto& item : assignments_)
            if (item.material == material) return item;
        return std::nullopt;
    }

    // The exact bytes hashed into policy_hash (all integers little-endian).
    [[nodiscard]] std::vector<std::uint8_t> canonical_bytes() const {
        return canonical_bytes_impl(false);
    }

    // Comparison-only identity: exactly the canonical policy with PressureFlowV1
    // implementation variants normalized to Reference. Every family assignment,
    // parameter, material and catalogue/capability identity remains significant.
    [[nodiscard]] Sha256::Digest pressure_variant_equivalence_hash() const {
        return Sha256::of(canonical_bytes_impl(true));
    }

private:
    [[nodiscard]] std::vector<std::uint8_t> canonical_bytes_impl(bool pressure_reference) const {
        std::vector<std::uint8_t> out;
        constexpr std::string_view kDomain{"lcb-liquid-policy\0", 18};
        out.insert(out.end(), kDomain.begin(), kDomain.end());
        put_le(out, policy_version_, 2);
        out.insert(out.end(), catalogue_digest_.begin(), catalogue_digest_.end());
        out.insert(out.end(), capability_matrix_digest_.begin(), capability_matrix_digest_.end());
        put_le(out, assignments_.size(), 2);
        for (const auto& item : assignments_) {
            put_le(out, item.material, 2);
            out.push_back(static_cast<std::uint8_t>(item.family));
            out.push_back(static_cast<std::uint8_t>(pressure_reference &&
                item.family == LiquidSolverFamily::PressureFlowV1
                    ? LiquidSolverVariant::Reference : item.variant));
        }
        put_le(out, family_blocks_.size(), 1);
        for (const auto& block : family_blocks_) put_block(out, block, 1);
        put_le(out, material_blocks_.size(), 2);
        for (const auto& block : material_blocks_) put_block(out, block, 2);
        return out;
    }

public:
    // The normalized applied policy as the single flat int32 wire form.
    [[nodiscard]] std::vector<std::int32_t> envelope() const {
        std::vector<std::int32_t> words{kMagic, kEnvelopeVersion, static_cast<std::int32_t>(policy_version_)};
        for (const auto* digest : {&catalogue_digest_, &capability_matrix_digest_}) {
            for (std::size_t i = 0; i < kDigestWords; ++i) {
                const auto value = (static_cast<std::uint32_t>((*digest)[i * 4U]) << 24U) |
                                   (static_cast<std::uint32_t>((*digest)[i * 4U + 1U]) << 16U) |
                                   (static_cast<std::uint32_t>((*digest)[i * 4U + 2U]) << 8U) |
                                   static_cast<std::uint32_t>((*digest)[i * 4U + 3U]);
                words.push_back(static_cast<std::int32_t>(value));
            }
        }
        words.push_back(static_cast<std::int32_t>(assignments_.size()));
        for (const auto& item : assignments_) {
            words.push_back(item.material);
            words.push_back(static_cast<std::int32_t>(item.family));
            words.push_back(static_cast<std::int32_t>(item.variant));
        }
        for (const auto* blocks : {&family_blocks_, &material_blocks_}) {
            words.push_back(static_cast<std::int32_t>(blocks->size()));
            for (const auto& block : *blocks) {
                words.push_back(block.owner);
                words.push_back(block.version);
                words.push_back(static_cast<std::int32_t>(block.values.size()));
                words.insert(words.end(), block.values.begin(), block.values.end());
            }
        }
        return words;
    }

    // Non-null when this applied policy may not construct a World in `build`.
    // Re-validates the normalized envelope, so a policy admitted only by a
    // hypothetical contract build can never reach this binary's kernels.
    [[nodiscard]] std::optional<LiquidPolicyRefusal> admission_refusal(
        const LiquidPolicyBuild& build = LiquidPolicyBuild::running()) const;

    [[nodiscard]] friend bool operator==(const LiquidSolverPolicy& a, const LiquidSolverPolicy& b) noexcept {
        return a.hash_ == b.hash_ && a.policy_version_ == b.policy_version_ &&
               a.catalogue_digest_ == b.catalogue_digest_ &&
               a.capability_matrix_digest_ == b.capability_matrix_digest_ &&
               a.assignments_ == b.assignments_ && a.family_blocks_ == b.family_blocks_ &&
               a.material_blocks_ == b.material_blocks_;
    }

private:
    struct Construct {};
    LiquidSolverPolicy(Construct, Sha256::Digest catalogue, Sha256::Digest capability,
                       std::vector<LiquidSolverAssignment> assignments,
                       std::vector<LiquidParameterBlock> family_blocks,
                       std::vector<LiquidParameterBlock> material_blocks)
        : catalogue_digest_(catalogue), capability_matrix_digest_(capability),
          assignments_(std::move(assignments)), family_blocks_(std::move(family_blocks)),
          material_blocks_(std::move(material_blocks)) {
        const auto bytes = canonical_bytes();
        hash_ = Sha256::of(bytes);
    }

    [[nodiscard]] static LiquidSolverPolicy default_for(const LiquidPolicyBuild& build) {
        std::vector<LiquidSolverAssignment> assignments;
        assignments.reserve(kLiquidCount);
        for (const auto& row : liquid_policy_catalogue::kLiquidRows) {
            const auto family = static_cast<LiquidSolverFamily>(row.default_family);
            assignments.push_back({row.material_id, family, family, LiquidSolverVariant::Reference});
        }
        return {Construct{}, build.catalogue_digest, build.capability_matrix_digest,
                std::move(assignments), {}, {}};
    }

    [[nodiscard]] static const LiquidSolverPolicy& running_default() {
        static const LiquidSolverPolicy policy = default_for(LiquidPolicyBuild::running());
        return policy;
    }

    static void put_le(std::vector<std::uint8_t>& out, std::uint64_t value, std::size_t bytes) {
        for (std::size_t i = 0; i < bytes; ++i) out.push_back(static_cast<std::uint8_t>(value >> (8U * i)));
    }

    static void put_block(std::vector<std::uint8_t>& out, const LiquidParameterBlock& block,
                          std::size_t owner_bytes) {
        put_le(out, block.owner, owner_bytes);
        put_le(out, block.version, 2);
        put_le(out, 4U * block.values.size(), 4);
        for (const auto value : block.values) put_le(out, static_cast<std::uint32_t>(value), 4);
    }

    template <typename Word>
    friend class LiquidPolicyDecoder;

    std::uint16_t policy_version_ = kPolicyVersion;
    Sha256::Digest catalogue_digest_{};
    Sha256::Digest capability_matrix_digest_{};
    std::vector<LiquidSolverAssignment> assignments_;
    std::vector<LiquidParameterBlock> family_blocks_;
    std::vector<LiquidParameterBlock> material_blocks_;
    Sha256::Digest hash_{};
};

struct LiquidPolicyDecodeResult {
    std::optional<LiquidSolverPolicy> policy;
    LiquidPolicyRefusal refusal;

    [[nodiscard]] bool accepted() const noexcept { return policy.has_value(); }
};

namespace liquid_policy_detail {

struct Failure {
    LiquidPolicyRefusal refusal;
};

[[noreturn]] inline void refuse(LiquidPolicyRefusalCode code, std::string detail,
                                std::optional<std::uint16_t> material = std::nullopt) {
    throw Failure{{code, material, std::move(detail)}};
}

inline const liquid_policy_catalogue::LiquidRow* liquid_row(std::uint64_t material) noexcept {
    for (const auto& row : liquid_policy_catalogue::kLiquidRows)
        if (row.material_id == material) return &row;
    return nullptr;
}

inline std::string family_name(std::uint64_t code) {
    return std::string(liquid_solver_family_id(static_cast<LiquidSolverFamily>(code)));
}

}  // namespace liquid_policy_detail

// Matrix descriptor name of a liquid, or nullptr for any other material.
[[nodiscard]] inline const char* liquid_policy_material_name(std::uint16_t material) noexcept {
    const auto* row = liquid_policy_detail::liquid_row(material);
    return row == nullptr ? nullptr : row->name;
}

// Validation precedence follows the contract exactly; the first failure wins.
// Construction-time only: it may allocate, and never touches a World.
template <typename Word>
class LiquidPolicyDecoder final {
    static_assert(std::is_integral_v<Word> && std::is_signed_v<Word> && sizeof(Word) >= 4);
    using Failure = liquid_policy_detail::Failure;
    using Code = LiquidPolicyRefusalCode;
    template <typename... Parts>
    [[nodiscard]] static std::string concat(const Parts&... parts) {
        return liquid_policy_detail::concat(parts...);
    }

public:
    LiquidPolicyDecoder(std::span<const Word> words, const LiquidPolicyBuild& build)
        : words_(words), build_(build) {}

    [[nodiscard]] LiquidPolicyDecodeResult run() {
        try {
            return {decode(), {}};
        } catch (const Failure& failure) {
            return {std::nullopt, failure.refusal};
        }
    }

private:
    [[noreturn]] static void refuse(Code code, std::string detail,
                                    std::optional<std::uint16_t> material = std::nullopt) {
        liquid_policy_detail::refuse(code, std::move(detail), material);
    }

    std::int64_t take(std::string_view what) {
        if (position_ >= words_.size())
            refuse(Code::MalformedPolicy, concat("truncated at word ", position_, " (", what, ")"));
        return static_cast<std::int64_t>(words_[position_++]);
    }

    std::uint64_t take_unsigned(std::string_view what, std::uint64_t maximum) {
        const auto value = take(what);
        if (value < 0 || static_cast<std::uint64_t>(value) > maximum)
            refuse(Code::MalformedPolicy,
                   concat(what, "=", value, " outside 0..", maximum, " at word ", position_ - 1U));
        return static_cast<std::uint64_t>(value);
    }

    Sha256::Digest take_digest(std::string_view what) {
        Sha256::Digest digest{};
        for (std::size_t i = 0; i < LiquidSolverPolicy::kDigestWords; ++i) {
            const auto value = static_cast<std::uint32_t>(take(what));
            for (std::size_t b = 0; b < 4U; ++b)
                digest[i * 4U + b] = static_cast<std::uint8_t>(value >> (24U - 8U * b));
        }
        return digest;
    }

    const LiquidParameterSchema* schema(bool family_owner, std::uint64_t owner, std::uint64_t version) const {
        for (const auto& item : build_.schemas)
            if (item.family_owner == family_owner && item.owner == owner && item.version == version) return &item;
        return nullptr;
    }

    LiquidSolverPolicy decode() {
        using liquid_policy_detail::family_name;
        using liquid_policy_detail::liquid_row;
        constexpr std::int64_t kInt32Min = -2'147'483'648LL;
        constexpr std::int64_t kInt32Max = 2'147'483'647LL;
        // 1. Transport integrity.
        for (std::size_t i = 0; i < words_.size(); ++i) {
            const auto value = static_cast<std::int64_t>(words_[i]);
            if (value < kInt32Min || value > kInt32Max)
                refuse(Code::MalformedPolicy, concat("word ", i, " is not a signed 32-bit integer"));
        }
        // 2. Header.
        constexpr auto kMinimum = LiquidSolverPolicy::kHeaderWords + 3U;
        if (words_.size() < kMinimum)
            refuse(Code::MalformedPolicy, concat("envelope has ", words_.size(), " words; minimum ", kMinimum));
        if (take("magic") != LiquidSolverPolicy::kMagic) refuse(Code::MalformedPolicy, "bad magic");
        if (take("envelope_version") != LiquidSolverPolicy::kEnvelopeVersion)
            refuse(Code::MalformedPolicy, "unknown envelope_version");
        if (take("policy_version") != LiquidSolverPolicy::kPolicyVersion)
            refuse(Code::MalformedPolicy, "unknown policy_version");
        const auto catalogue = take_digest("catalogue_digest");
        const auto capability = take_digest("capability_matrix_digest");
        // 3. Identity, before any catalogue-dependent interpretation.
        if (catalogue != build_.catalogue_digest)
            refuse(Code::StaleCapabilityMatrix, "catalogue_digest differs from the running build");
        if (capability != build_.capability_matrix_digest)
            refuse(Code::StaleCapabilityMatrix, "capability_matrix_digest differs from the running build");
        // 4. Section structure and exact consumption.
        struct Raw {
            std::uint64_t material;
            std::uint64_t family;
            std::uint64_t variant;
        };
        struct RawBlock {
            std::uint64_t owner;
            std::uint64_t version;
            std::vector<std::int32_t> values;
        };
        const auto count = take_unsigned("assignment_count", LiquidSolverPolicy::kLiquidCount);
        std::vector<Raw> raw;
        raw.reserve(count);
        for (std::uint64_t i = 0; i < count; ++i) {
            const auto material = take_unsigned("material_id", 0xFFFFU);
            const auto family = take_unsigned("family_code", 0xFFU);
            raw.push_back({material, family, take_unsigned("variant_code", 0xFFU)});
        }
        std::array<std::vector<RawBlock>, 2> blocks;
        for (std::size_t kind = 0; kind < 2U; ++kind) {
            const std::string prefix = kind == 0U ? "family" : "material";
            const auto block_count = take_unsigned(concat(prefix, "_block_count"), kind == 0U
                                                                                ? LiquidSolverPolicy::kFamilyCount
                                                                                : LiquidSolverPolicy::kLiquidCount);
            for (std::uint64_t i = 0; i < block_count; ++i) {
                RawBlock block;
                block.owner = take_unsigned(concat(prefix, "_block_owner"), kind == 0U ? 0xFFU : 0xFFFFU);
                block.version = take_unsigned(concat(prefix, "_block_version"), 0xFFFFU);
                const auto length = take_unsigned(concat(prefix, "_block_word_length"), LiquidSolverPolicy::kMaximumBlockWords);
                for (std::uint64_t v = 0; v < length; ++v)
                    block.values.push_back(static_cast<std::int32_t>(take(concat(prefix, "_block_value"))));
                blocks[kind].push_back(std::move(block));
            }
        }
        if (position_ != words_.size())
            refuse(Code::MalformedPolicy, concat(words_.size() - position_, " trailing words"));
        // 5. Assignment identity and order.
        for (const auto& item : raw) {
            const auto material = static_cast<std::uint16_t>(item.material);
            if (item.material >= liquid_policy_catalogue::kMaterialDescriptorCount ||
                item.material == LiquidSolverPolicy::kReservedMaterial)
                refuse(Code::UnknownMaterial, "material id outside the catalogue or reserved", material);
            if (liquid_row(item.material) == nullptr)
                refuse(Code::NotALiquid, "assignment to a non-liquid descriptor", material);
            if (item.family > LiquidSolverPolicy::kFamilyCount)
                refuse(Code::UnknownFamily, concat("family_code ", item.family), material);
            if (item.variant >= LiquidSolverPolicy::kVariantCount)
                refuse(Code::UnknownVariant, concat("variant_code ", item.variant), material);
        }
        for (std::size_t i = 1; i < raw.size(); ++i) {
            if (raw[i].material <= raw[i - 1U].material)
                refuse(Code::MalformedPolicy, "material ids not strictly ascending (duplicate or unsorted)");
        }
        std::vector<std::uint16_t> missing;
        for (const auto& row : liquid_policy_catalogue::kLiquidRows) {
            if (std::none_of(raw.begin(), raw.end(), [&](const Raw& item) { return item.material == row.material_id; }))
                missing.push_back(row.material_id);
        }
        if (!missing.empty()) {
            std::string list = "[";
            for (std::size_t i = 0; i < missing.size(); ++i) list += concat(i ? ", " : "", missing[i]);
            refuse(Code::MalformedPolicy, concat("incomplete assignments; missing ", list, "]"), missing.front());
        }
        // 6. Normalization of the request-only material-default code.
        std::vector<LiquidSolverAssignment> assignments;
        assignments.reserve(raw.size());
        for (const auto& item : raw) {
            const auto material = static_cast<std::uint16_t>(item.material);
            auto family = static_cast<std::uint8_t>(item.family);
            if (family == 0U) {
                if (item.variant != 0U)
                    refuse(Code::MalformedPolicy, "material-default family requires reference variant", material);
                family = liquid_row(item.material)->default_family;
            }
            assignments.push_back({material, static_cast<LiquidSolverFamily>(item.family),
                                   static_cast<LiquidSolverFamily>(family),
                                   static_cast<LiquidSolverVariant>(item.variant)});
        }
        // 7. Matrix and build qualification.
        using liquid_policy_catalogue::CellStatus;
        for (const auto& item : assignments) {
            const auto& row = *liquid_row(item.material);
            const auto family = static_cast<std::size_t>(item.family);
            const auto variant = static_cast<std::size_t>(item.variant);
            const auto status = row.status[family - 1U];
            const auto variants = row.variant_mask[family - 1U];
            const std::string cell = concat(row.name, " x ", family_name(family));
            if (status == CellStatus::Rejected) refuse(Code::CombinationRejected, cell, item.material);
            if (status == CellStatus::ProposedAlternate || variants == 0U)
                refuse(Code::NotSelectable, cell, item.material);
            if ((variants & (1U << variant)) == 0U)
                refuse(Code::VariantUnsupported,
                       concat(liquid_solver_variant_id(item.variant), " for ", family_name(family)),
                       item.material);
            const bool is_default = family == row.default_family && item.variant == LiquidSolverVariant::Reference;
            if (!build_.native && !is_default)
                refuse(Code::PlatformUnsupported, "host has no native policy handshake", item.material);
            if ((build_.available_families & (1U << (family - 1U))) == 0U)
                refuse(Code::FamilyUnavailable, concat(family_name(family), " is not compiled/qualified in this build"),
                       item.material);
            if (build_.cell_qualified &&
                std::find(build_.qualified_cells.begin(), build_.qualified_cells.end(),
                          std::pair<std::uint16_t, std::uint8_t>{item.material, static_cast<std::uint8_t>(family)}) ==
                    build_.qualified_cells.end())
                refuse(Code::FamilyUnavailable,
                       concat(family_name(family), " is not qualified for material ", item.material, " in this build"),
                       item.material);
            if (!build_.qualified_variants.empty()) {
                const auto found = std::find_if(
                    build_.qualified_variants.begin(), build_.qualified_variants.end(),
                    [&](const LiquidPolicyBuild::QualifiedVariants& qualified) {
                        return qualified.material == item.material && qualified.family == family;
                    });
                if (found == build_.qualified_variants.end() || (found->variant_mask & (1U << variant)) == 0U)
                    refuse(Code::FamilyUnavailable,
                           concat(family_name(family), "/", liquid_solver_variant_id(item.variant),
                                  " is not compiled/qualified for material ", item.material, " in this build"),
                           item.material);
            }
        }
        // 8. Parameter blocks, family then material.
        auto family_of = [&](std::uint64_t material) -> std::optional<std::uint8_t> {
            for (const auto& item : assignments)
                if (item.material == material) return static_cast<std::uint8_t>(item.family);
            return std::nullopt;
        };
        auto used = [&](std::uint64_t family) {
            return std::any_of(assignments.begin(), assignments.end(), [&](const LiquidSolverAssignment& item) {
                return static_cast<std::uint64_t>(item.family) == family;
            });
        };
        std::array<std::vector<LiquidParameterBlock>, 2> applied;
        for (std::size_t kind = 0; kind < 2U; ++kind) {
            const std::string name = kind == 0U ? "family" : "material";
            const auto& list = blocks[kind];
            for (std::size_t i = 1; i < list.size(); ++i) {
                if (list[i].owner <= list[i - 1U].owner)
                    refuse(Code::MalformedPolicy, concat(name, " blocks not strictly ascending (duplicate or unsorted)"));
            }
            for (const auto& block : list) {
                const auto label = concat(name, " block (", block.owner, ", v", block.version, ")");
                const auto* found = schema(kind == 0U, block.owner, block.version);
                if (found == nullptr) refuse(Code::UnknownParameter, concat("unknown ", label));
                if (block.values.size() != found->fields.size())
                    refuse(Code::UnknownParameter, concat(label, " has ", block.values.size(), " words; schema has ",
                                                          found->fields.size()));
                if (kind == 0U && !used(block.owner))
                    refuse(Code::MalformedPolicy, concat("extra family block for unassigned ", family_name(block.owner)));
                if (kind == 1U && family_of(block.owner) != std::optional<std::uint8_t>{found->requires_family})
                    refuse(Code::MalformedPolicy, concat(label, " not declared by the material's applied family"),
                           static_cast<std::uint16_t>(block.owner));
                for (std::size_t f = 0; f < found->fields.size(); ++f) {
                    const auto& field = found->fields[f];
                    const auto value = static_cast<std::int64_t>(block.values[f]);
                    if (value < field.minimum || value > field.maximum)
                        refuse(Code::MalformedPolicy,
                               concat(field.name, "=", value, " outside ", field.minimum, "..", field.maximum));
                }
                applied[kind].push_back({static_cast<std::uint16_t>(block.owner),
                                         static_cast<std::uint16_t>(block.version), block.values});
            }
        }
        for (const auto& item : build_.schemas) {
            if (!item.family_owner || !item.mandatory || !used(item.owner)) continue;
            if (std::none_of(applied[0].begin(), applied[0].end(),
                             [&](const LiquidParameterBlock& block) { return block.owner == item.owner; }))
                refuse(Code::UnknownParameter, concat("missing mandatory family block for ", family_name(item.owner)));
        }
        return {LiquidSolverPolicy::Construct{}, catalogue, capability, std::move(assignments),
                std::move(applied[0]), std::move(applied[1])};
    }

    std::span<const Word> words_;
    const LiquidPolicyBuild& build_;
    std::size_t position_ = 0;
};

template <typename Word>
LiquidPolicyDecodeResult LiquidSolverPolicy::decode(std::span<const Word> words, const LiquidPolicyBuild& build) {
    return LiquidPolicyDecoder<Word>(words, build).run();
}

inline std::optional<LiquidPolicyRefusal> LiquidSolverPolicy::admission_refusal(
    const LiquidPolicyBuild& build) const {
    const auto words = envelope();
    auto result = decode(std::span<const std::int32_t>(words), build);
    if (!result.accepted()) return result.refusal;
    if (!(*result.policy == *this))
        return LiquidPolicyRefusal{LiquidPolicyRefusalCode::MalformedPolicy, std::nullopt,
                                   "applied policy does not re-validate to itself"};
    return std::nullopt;
}

}  // namespace cybersand
