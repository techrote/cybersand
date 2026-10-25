#include "cybersand/liquid_construction_refusal.hpp"
#include "cybersand/prepared_world.hpp"

#include <algorithm>
#include <memory>
#include <stdexcept>
#include <type_traits>
#include <vector>

namespace {
using namespace cybersand;
void require(bool ok, const char* detail) { if (!ok) throw std::runtime_error(detail); }

// Independent explicit byte construction, not the token's hashing helper.
Sha256::Digest expected_request_hash(ConstructionRequestScope scope,
                                    std::span<const std::int32_t> words) {
    constexpr std::string_view domain="cybersand-construction-request-v1";
    std::vector<std::uint8_t> bytes;
    const auto u32=[&](std::uint32_t word) {
        bytes.push_back(static_cast<std::uint8_t>(word));
        bytes.push_back(static_cast<std::uint8_t>(word>>8U));
        bytes.push_back(static_cast<std::uint8_t>(word>>16U));
        bytes.push_back(static_cast<std::uint8_t>(word>>24U));
    };
    u32(static_cast<std::uint32_t>(domain.size()));
    bytes.insert(bytes.end(),domain.begin(),domain.end());
    bytes.insert(bytes.end(),{1,0,static_cast<std::uint8_t>(scope)});
    u32(static_cast<std::uint32_t>(words.size()));
    for(const auto word:words)u32(static_cast<std::uint32_t>(word));
    return Sha256::of(bytes);
}
} // namespace

static_assert(!std::is_default_constructible_v<cybersand::ConstructionRefusal>);
static_assert(!std::is_aggregate_v<cybersand::ConstructionRefusal>);
static_assert(!std::is_constructible_v<cybersand::ConstructionRefusal,
    std::span<const std::int32_t>,cybersand::ConstructionRequestScope,cybersand::LiquidPolicyRefusal>);
static_assert(std::is_same_v<decltype(std::declval<const cybersand::ConstructionRefusal&>().requested_policy()),
    std::span<const std::int32_t>>);

void test_liquid_construction_refusal_native_issuance() {
    auto valid=LiquidSolverPolicy::default_request();
    require(!validate_liquid_policy_request(valid),"accepted policy minted a refusal");
    auto code_zero=valid;
    for(std::size_t at=LiquidSolverPolicy::kHeaderWords+1U;
        at<LiquidSolverPolicy::kHeaderWords+1U+LiquidSolverPolicy::kLiquidCount*3U;at+=3U)
        code_zero[at+1U]=0;
    require(!validate_liquid_policy_request(code_zero),"accepted default code-zero request minted a refusal");

    std::vector<std::int32_t> malformed{42};
    const auto token=validate_liquid_policy_request(malformed);
    require(token && token->outcome_kind()==ConstructionOutcomeKind::PolicyOrSetupRefused &&
                token->request_scope()==ConstructionRequestScope::ExactRawPolicyRequest &&
                token->policy_refusal() && token->policy_refusal()->code==LiquidPolicyRefusalCode::MalformedPolicy &&
                token->failure_detail().empty(),"actual malformed decode was not a native policy refusal");
    // Frozen Python struct/hashlib vector: tag length+ASCII, schema u16LE1,
    // exact-raw scope u8=1, count u32LE1, signed word i32LE42.
    require(Sha256::hex(token->request_hash())=="b27dff37afcfa2bc807694b4c13119544fc38ec890b5c4271a71c8b6eb6b121e",
            "native request hash disagrees with independent frozen Python bytes");
    malformed[0]=43;
    require(token->requested_policy()[0]==42,"token retained mutable caller request storage");
    require(validate_liquid_policy_request(malformed)->request_hash()!=token->request_hash(),
            "exact raw request change did not change hash");
    const auto empty=validate_liquid_policy_request({});
    require(empty && empty->requested_policy().empty(),"empty malformed request lost exact bounded input");

    auto unsupported=code_zero;unsupported[21]=4;unsupported[22]=1;
    const auto refused=validate_liquid_policy_request(unsupported);
    const auto decoded=LiquidSolverPolicy::decode(std::span<const std::int32_t>(unsupported));
    require(refused && !decoded.accepted() && refused->policy_refusal()->code==decoded.refusal.code &&
                refused->policy_refusal()->material==decoded.refusal.material &&
                refused->policy_refusal()->detail==decoded.refusal.detail &&
                std::equal(refused->requested_policy().begin(),refused->requested_policy().end(),
                           unsupported.begin(),unsupported.end()),"token invented reason or normalized raw code-zero words");

    std::vector<std::int32_t> maximum(ConstructionRefusal::kMaximumRequestWords,0);
    maximum[0]=42;
    const auto bounded=validate_liquid_policy_request(maximum);
    require(bounded && bounded->requested_policy().size()==maximum.size(),"declared request boundary refused or truncated");
    maximum.push_back(0);
    bool oversized=false;
    try { (void)validate_liquid_policy_request(maximum); }
    catch(const std::length_error&) { oversized=true; }
    require(oversized,"oversized input escaped the bound or minted a truncated exact token");

    // The builder receives a normalized policy value, so a setup refusal cannot
    // claim the host's earlier code-zero representation or an exact raw scope.
    auto config=std::make_unique<WorldConfig>();
    normalization::FinalSetupInput input;input.mass_bits=3;
    const auto result=PreparedWorldBuilder::prepare(*config,input,normalization::NormalizationOptIn::None);
    const auto* setup_refusal=std::get_if<ConstructionRefusal>(&result);
    require(setup_refusal && setup_refusal->outcome_kind()==ConstructionOutcomeKind::PolicyOrSetupRefused &&
                setup_refusal->request_scope()==ConstructionRequestScope::NormalizedPolicyEnvelope &&
                setup_refusal->policy_refusal()->code==LiquidPolicyRefusalCode::MalformedPolicy,
            "native setup refusal lost normalized-request scope");
    require(std::equal(setup_refusal->requested_policy().begin(),setup_refusal->requested_policy().end(),
                       valid.begin(),valid.end()),"builder token did not bind applied envelope");
    require(setup_refusal->request_hash()==expected_request_hash(
                ConstructionRequestScope::NormalizedPolicyEnvelope,valid) &&
            setup_refusal->request_hash()!=expected_request_hash(ConstructionRequestScope::ExactRawPolicyRequest,valid),
            "request scope omitted from canonical hash");
}
