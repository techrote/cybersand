#pragma once
#include "mosaic_admission.hpp"
#include "resilience_solver.hpp"

namespace cybersand::gentek_swarm {

enum class ResilienceAdmission { Full, CompatibilityFour, CompatibilityHardOnly };
enum class ResilienceFallback { HardOnly, NativeCore };
enum class ReceiverPolicy { ClosedOnly, RequiredOriginalNative };
const char* name(ResilienceAdmission) noexcept;
const char* name(ResilienceFallback) noexcept;
const char* name(ReceiverPolicy) noexcept;

struct ResilienceOptions {
    ResilienceAdmission admission = ResilienceAdmission::Full;
    SolveSchedule schedule = SolveSchedule::Original;
    ResilienceFallback fallback = ResilienceFallback::HardOnly;
    ReceiverPolicy receivers = ReceiverPolicy::ClosedOnly;
    // Continuation registration: 6/8 are allowed only for the receiver-aware
    // single-attempt native policy. Legacy aggregate initializers remain valid.
    std::uint32_t optional_capacity = 4;
};
bool valid_resilience_options(const ResilienceOptions&) noexcept;

struct ReceiverFaceDecision {
    Point contact{};
    std::uint32_t tile{};
    std::uint16_t original_domain{}, compatible_domain{}, supported_domain{};
    int distance{};
    bool selected = false;
};
struct RequiredReceiverDecision {
    std::uint32_t slot_id{}, original_tile{}, selected_tile{};
    Point original_contact{}, selected_contact{};
    std::uint16_t original_compatible_domain{}, original_supported_domain{};
    std::uint16_t selected_compatible_domain{}, selected_supported_domain{};
    bool original_admitted = false, changed = false;
    std::uint64_t work{}, points_examined{};
    std::vector<ReceiverFaceDecision> faces;
    std::string reason;
};
struct ResilienceTrace {
    NativeAdmissionReceipt admission;
    ResilienceSolverTrace solver;
    // Mechanical authority remains the primary admitted set on every fallback.
    std::vector<std::uint32_t> final_authorized_ids;
    std::vector<std::uint32_t> primary_selected_ids, fallback_selected_ids;
    std::vector<std::uint32_t> dropped_preference_ids;
    std::vector<RequiredReceiverDecision> receivers;
    std::string reason;
};
struct ResilienceResult {
    NegotiatedResult candidate;
    ResilienceOptions options;
    ResilienceTrace trace;
    std::uint64_t digest{}, preparation_work{}, join_work_limit{};
};

MosaicPlan negotiate_mosaic_resilient(const Request&, const std::vector<TransitionSlot>&,
                                    const ResilienceOptions&, ResilienceTrace&);
ResilienceResult negotiate_resilient(const PreparedAdmission&, const ResilienceOptions&,
                                    bool reverse = false);
void write_resilience_json(const std::string&, const ResilienceResult&);

} // namespace cybersand::gentek_swarm
