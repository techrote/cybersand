#pragma once
#include "swarm.hpp"

namespace cybersand::gentek_swarm {

// SWARM-002-only finite interchange. No production schema or universal part IR.
inline constexpr const char* swarm001_predecessor = "345ecc3ef939523f247b3eb192aa7502bd4d83ca";
inline constexpr std::size_t max_transition_slots = 8;
enum class SlotKind { PointSocket, BearingSegment, PassageOpening };
struct TransitionSlot {
    std::uint32_t id{}, instance{}, connector{};
    SlotKind kind = SlotKind::PointSocket;
    Point a{}, b{}, facing{};
    Rect envelope{};
    std::vector<Point> clearance;
    bool required = false; // original mechanical obligation, never silently relaxed
    bool hard = false;     // hard categorical condition versus explicit preference
    double strength = 1.0;
    std::string owner = "FRAMEWEAVER", reason;
};
struct FramePlan {
    Result core, result; // core is the immutable accepted macrostructure snapshot
    std::vector<TransitionSlot> slots;
    std::vector<std::string> reservation_rejections;
};
struct DomainInfluence {
    std::uint32_t slot_id{};
    std::uint16_t compatible_domain{};
    bool hard = false, admitted = false;
    Point contact{};
    std::string reason;
};
struct DomainDecision {
    std::uint32_t tile{};
    Point origin{};
    std::uint16_t original_domain{}, modified_domain{}, hard_domain{}, preferred_domain{};
    int selected = -1;
    bool preference_satisfied = false, fallback = false;
    std::vector<DomainInfluence> influences;
};
struct SolverAttempt {
    std::string policy, reason;
    Status status = Status::Invalid;
    bool attempted = false, work_observed = false;
    std::uint64_t work{}, work_limit{};
};
struct SlotResponse {
    std::uint32_t slot_id{}, tile{};
    bool admitted = false, satisfied = false;
    Point contact{}, facing{};
    std::uint16_t compatible_domain{};
    std::string reason;
};
struct MosaicPlan {
    Result result;
    std::vector<DomainDecision> domains;
    std::vector<int> categories;
    std::vector<SolverAttempt> attempts;
    std::vector<SlotResponse> responses;
};
FramePlan plan_frameweaver(const Request& own, const Request& peer);
MosaicPlan negotiate_mosaic(const Request&, const std::vector<TransitionSlot>&);
const char* name(SlotKind) noexcept;
const char* mosaic_category_name(unsigned) noexcept;

struct NegotiatedResult {
    PairResult control;
    std::string offer_policy = "required-hard_optional-soft";
    Request frame_request, mosaic_request, residual_request;
    FramePlan frame;
    MosaicPlan mosaic, no_offers;
    Result final_frame, final_mosaic, residual;
    std::vector<Material> planned_cells, cells, finished_cells, no_offer_cells;
    std::vector<Seam> seams;
    std::map<std::string, std::uint64_t> metrics;
    std::vector<std::string> notes;
    std::uint64_t digest{}, work{};
};

// Optional-offer admission is a separate bounded experiment. The original C
// result and its serializer/digest remain unchanged. A preparation is one frozen
// matched case; ranking never reads a categorical assignment or solver outcome.
enum class AdmissionMode { Full, OptionalCap, LeaveOneOut };
struct AdmissionPolicy {
    AdmissionMode mode = AdmissionMode::Full;
    std::uint32_t optional_cap{}, omitted_optional_id{};
};
struct SlotAdmission {
    std::uint32_t slot_id{};
    bool mandatory = false, selected = false, witness_found = false;
    int rank = -1, nearest_forward_distance = -1; // optional ranks are zero-based
    Point witness_source{}, witness_peer{};
    std::string reason;
};
struct AdmissionSelection {
    AdmissionPolicy policy;
    Status status = Status::Complete;
    std::vector<std::uint32_t> selected_ids;
    std::vector<SlotAdmission> decisions;
    std::uint64_t work{}, work_limit = 2'000'000, digest{};
    std::uint64_t ranking_work{}, selection_work{}, join_work_limit{};
    std::uint64_t structural_work_upper_bound{}, solver_work_limit{};
    bool diagnostic = false;
    std::string reason;
};
struct PreparedAdmission {
    NegotiatedResult prepared;
    std::vector<SlotAdmission> ranking;
    std::uint64_t ranking_work{}, ranking_digest{}, input_digest{};
    Status status = Status::Complete;
    std::string reason;
};
struct AdmissionResult {
    NegotiatedResult candidate;
    AdmissionSelection admission;
    std::uint64_t digest{};
};
PreparedAdmission prepare_admission(const Fixture&, const Profile&, std::uint64_t,
                                    const std::string&, bool reverse = false);
AdmissionResult negotiate_admission(const PreparedAdmission&, const AdmissionPolicy&,
                                    bool reverse = false, bool finish = false,
                                    // Zero: original ceiling; 2M: registered lower-only diagnostic.
                                    std::uint64_t diagnostic_solver_ceiling = 0);
const char* name(AdmissionMode) noexcept;
void write_admission_json(const std::string&, const AdmissionResult&);

NegotiatedResult negotiate(const Fixture&, const Profile&, std::uint64_t,
                           const std::string&, bool reverse = false,
                           bool force_hard = false, bool finish = true);
void write_negotiated_json(const std::string&, const NegotiatedResult&);
} // namespace cybersand::gentek_swarm
