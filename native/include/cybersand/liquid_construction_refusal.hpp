#pragma once

#include "cybersand/liquid_solver_policy.hpp"
#include "cybersand/sha256.hpp"

#include <array>
#include <cstdint>
#include <optional>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <type_traits>
#include <utility>
#include <vector>

namespace cybersand {

class PreparedWorldBuilder;
class ConstructionRefusal;
std::optional<ConstructionRefusal> validate_liquid_policy_request(std::span<const std::int32_t>);

enum class ConstructionOutcomeKind : std::uint8_t {
    PolicyOrSetupRefused = 1,
    NativePreparationFailed = 2,
};
enum class ConstructionRequestScope : std::uint8_t {
    ExactRawPolicyRequest = 1,
    NormalizedPolicyEnvelope = 2,
};

// An immutable native-issued outcome. Caller-provided refusal text cannot mint
// one. ExactRawPolicyRequest retains code-zero words verbatim. A builder that
// receives an already decoded WorldConfig can bind only its normalized envelope,
// and never claims to recover a host's original raw request.
class ConstructionRefusal final {
public:
    static constexpr std::size_t kMaximumRequestWords = 4096;
    static constexpr std::size_t kMaximumDetailBytes = 512;
    static constexpr std::uint16_t kRequestHashSchemaVersion = 1;
    static constexpr std::string_view kRequestHashDomain = "cybersand-construction-request-v1";

    ConstructionOutcomeKind outcome_kind() const noexcept { return outcome_kind_; }
    ConstructionRequestScope request_scope() const noexcept { return request_scope_; }
    std::span<const std::int32_t> requested_policy() const noexcept { return request_; }
    const Sha256::Digest& request_hash() const noexcept { return request_hash_; }
    const std::optional<LiquidPolicyRefusal>& policy_refusal() const noexcept { return refusal_; }
    std::string_view failure_detail() const noexcept { return failure_detail_; }

private:
    friend class PreparedWorldBuilder;
    friend std::optional<ConstructionRefusal> validate_liquid_policy_request(std::span<const std::int32_t>);

    static ConstructionRefusal for_setup(const LiquidSolverPolicy& policy, LiquidPolicyRefusal refusal) {
        const auto envelope = policy.envelope();
        return ConstructionRefusal(envelope, ConstructionRequestScope::NormalizedPolicyEnvelope,
                                   std::move(refusal));
    }
    static ConstructionRefusal for_native_failure(const LiquidSolverPolicy& policy, std::string detail) {
        const auto envelope = policy.envelope();
        return ConstructionRefusal(envelope, std::move(detail));
    }
    ConstructionRefusal(std::span<const std::int32_t> request, ConstructionRequestScope scope,
                        LiquidPolicyRefusal refusal)
        : outcome_kind_(ConstructionOutcomeKind::PolicyOrSetupRefused), request_scope_(scope),
          request_(bounded_request(request)), refusal_(std::move(refusal)) {
        if (refusal_->code == LiquidPolicyRefusalCode::None ||
            static_cast<std::uint8_t>(refusal_->code) >
                static_cast<std::uint8_t>(LiquidPolicyRefusalCode::NormalizationRequired) ||
            refusal_->detail.size() > kMaximumDetailBytes)
            throw std::invalid_argument("invalid native construction refusal");
        request_hash_ = hash_request(request_scope_, request_);
    }
    ConstructionRefusal(std::span<const std::int32_t> request, std::string detail)
        : outcome_kind_(ConstructionOutcomeKind::NativePreparationFailed),
          request_scope_(ConstructionRequestScope::NormalizedPolicyEnvelope),
          request_(bounded_request(request)), failure_detail_(std::move(detail)) {
        if (failure_detail_.empty() || failure_detail_.size() > kMaximumDetailBytes)
            throw std::invalid_argument("invalid native preparation failure detail");
        request_hash_ = hash_request(request_scope_, request_);
    }
    static std::vector<std::int32_t> bounded_request(std::span<const std::int32_t> request) {
        if (request.size() > kMaximumRequestWords)
            throw std::length_error("construction request exceeds 4096 words");
        return {request.begin(), request.end()};
    }
    template<class T> static void integer(Sha256& hash, T value) noexcept {
        using Unsigned = std::make_unsigned_t<T>;
        const auto bits = static_cast<std::uint64_t>(static_cast<Unsigned>(value));
        std::array<std::uint8_t, sizeof(T)> bytes{};
        for (std::size_t i = 0; i < bytes.size(); ++i)
            bytes[i] = static_cast<std::uint8_t>(bits >> (8U * i));
        hash.update(bytes);
    }
    static Sha256::Digest hash_request(ConstructionRequestScope scope,
                                      std::span<const std::int32_t> request) noexcept {
        Sha256 hash;
        integer(hash, static_cast<std::uint32_t>(kRequestHashDomain.size()));
        hash.update({reinterpret_cast<const std::uint8_t*>(kRequestHashDomain.data()), kRequestHashDomain.size()});
        integer(hash, kRequestHashSchemaVersion);
        integer(hash, static_cast<std::uint8_t>(scope));
        integer(hash, static_cast<std::uint32_t>(request.size()));
        for (const auto word : request) integer(hash, word);
        return hash.finish();
    }

    ConstructionOutcomeKind outcome_kind_;
    ConstructionRequestScope request_scope_;
    std::vector<std::int32_t> request_;
    Sha256::Digest request_hash_{};
    std::optional<LiquidPolicyRefusal> refusal_;
    std::string failure_detail_;
};

// Bounded native validator, not a factory for caller-invented reasons. A request
// beyond the declared bound throws length_error before parsing or allocation;
// no truncated request is ever labeled exact. Allocation failure also remains
// an exception for the owner's transactional construction boundary to handle.
inline std::optional<ConstructionRefusal> validate_liquid_policy_request(std::span<const std::int32_t> request) {
    if (request.size() > ConstructionRefusal::kMaximumRequestWords)
        throw std::length_error("construction request exceeds 4096 words");
    const auto decoded = LiquidSolverPolicy::decode(request);
    if (!decoded.accepted())
        return ConstructionRefusal(request, ConstructionRequestScope::ExactRawPolicyRequest, decoded.refusal);
    if (const auto refused = decoded.policy->admission_refusal())
        return ConstructionRefusal(request, ConstructionRequestScope::ExactRawPolicyRequest, *refused);
    return std::nullopt;
}

} // namespace cybersand
