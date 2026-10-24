#pragma once
// Versioned construction-time identity for a finite native cell setup.
// This binds the declared definition and canonical payload; matching a caller's
// definition digest never proves that the payload was compiled from it.
#include "cybersand/sha256.hpp"
#include <cstdint>
#include <limits>
#include <optional>
#include <span>
#include <stdexcept>
#include <string_view>
#include <type_traits>
#include <vector>

namespace cybersand::setup {
using Digest = Sha256::Digest;
enum class SetupKind : std::uint8_t { NativeCellFixture = 1, MicroScenario = 2 };
enum class SetupCoverage : std::uint8_t { NativePayloadOnly = 1, RegisteredDefinitionAndPayload = 2 };
enum SetupGap : std::uint32_t {
    Schedule = 1U << 0U, ActorsLoadout = 1U << 1U, PlanesClocks = 1U << 2U,
    RetainedEditsImport = 1U << 3U, PresentationInputs = 1U << 4U,
    HostCollectionUnverified = 1U << 5U,
};
inline constexpr std::uint32_t kKnownSetupGaps = (1U << 6U) - 1U;
struct SetupDomain {
    std::int64_t x = 0, y = 0;
    std::uint32_t width = 0, height = 0;
    friend bool operator==(const SetupDomain&, const SetupDomain&) = default;
};
struct SetupDescriptor {
    SetupKind kind = SetupKind::NativeCellFixture;
    std::uint16_t definition_schema = 1;
    std::optional<Digest> definition_digest;
    std::uint64_t seed = 0;
    SetupDomain domain;
    SetupCoverage coverage = SetupCoverage::NativePayloadOnly;
    std::uint32_t gaps = kKnownSetupGaps;
    friend bool operator==(const SetupDescriptor&, const SetupDescriptor&) = default;
};
namespace encoding {
struct Writer {
    std::vector<std::uint8_t> bytes;
    template<class T> void integer(T value) {
        using U = std::make_unsigned_t<T>;
        auto bits = static_cast<std::uint64_t>(static_cast<U>(value));
        for (std::size_t i = 0; i < sizeof(T); ++i) {
            bytes.push_back(static_cast<std::uint8_t>(bits & 255U));
            bits >>= 8U;
        }
    }
    void digest(const Digest& value) { bytes.insert(bytes.end(), value.begin(), value.end()); }
    void text(std::string_view value) {
        if (value.size() > 4096U) throw std::invalid_argument("receipt text exceeds 4096 bytes");
        integer(static_cast<std::uint32_t>(value.size()));
        bytes.insert(bytes.end(), value.begin(), value.end());
    }
    void optional_digest(const std::optional<Digest>& value) {
        integer(static_cast<std::uint8_t>(value.has_value()));
        if (value) digest(*value);
    }
};
} // namespace encoding
inline void validate_setup_descriptor(const SetupDescriptor& value) {
    const auto& d = value.domain;
    if (d.width == 0 || d.width > 1024 || d.height == 0 || d.height > 1024 ||
        d.x > std::numeric_limits<std::int64_t>::max() - (d.width - 1U) ||
        d.y > std::numeric_limits<std::int64_t>::max() - (d.height - 1U))
        throw std::invalid_argument("invalid finite setup domain");
    if ((value.kind != SetupKind::NativeCellFixture && value.kind != SetupKind::MicroScenario) ||
        value.definition_schema != (value.kind == SetupKind::MicroScenario ? 2U : 1U))
        throw std::invalid_argument("unknown setup kind/schema");
    if (value.coverage != SetupCoverage::NativePayloadOnly &&
        value.coverage != SetupCoverage::RegisteredDefinitionAndPayload)
        throw std::invalid_argument("unknown setup coverage");
    if (value.coverage == SetupCoverage::RegisteredDefinitionAndPayload && !value.definition_digest)
        throw std::invalid_argument("registered definition coverage requires a definition digest");
    if ((value.gaps & ~kKnownSetupGaps) != 0U)
        throw std::invalid_argument("unknown setup coverage gap");
    constexpr auto structural_gaps = Schedule | ActorsLoadout | PlanesClocks |
        RetainedEditsImport | PresentationInputs;
    if (value.coverage == SetupCoverage::NativePayloadOnly &&
        (value.gaps & structural_gaps) != structural_gaps)
        throw std::invalid_argument("native payload alone must retain non-cell setup gaps");
    // Registered definition binding remains host-unverified until the native
    // setup compiler can prove the final overlay. A caller cannot remove this
    // qualifier merely by supplying matching digest bytes.
    if ((value.kind == SetupKind::MicroScenario ||
         value.coverage == SetupCoverage::RegisteredDefinitionAndPayload) &&
        (value.gaps & HostCollectionUnverified) == 0U)
        throw std::invalid_argument("registered definition collection remains host-unverified");
}
inline void encode_setup_descriptor(encoding::Writer& out, const SetupDescriptor& value) {
    validate_setup_descriptor(value);
    out.integer(static_cast<std::uint8_t>(value.kind));
    out.integer(value.definition_schema);
    out.optional_digest(value.definition_digest);
    out.integer(value.seed);
    out.integer(value.domain.x); out.integer(value.domain.y);
    out.integer(value.domain.width); out.integer(value.domain.height);
    out.integer(static_cast<std::uint8_t>(value.coverage)); out.integer(value.gaps);
}
inline Digest prepared_setup_identity(const SetupDescriptor& descriptor, const Digest& native_payload_digest) {
    encoding::Writer out;
    out.text("cybersand-prepared-setup-v1");
    out.integer(std::uint16_t{1});
    encode_setup_descriptor(out, descriptor);
    out.digest(native_payload_digest);
    return Sha256::of(out.bytes);
}
} // namespace cybersand::setup
