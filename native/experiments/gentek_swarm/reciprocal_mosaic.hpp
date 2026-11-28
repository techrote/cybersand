#pragma once

#include "resilience.hpp"

#include <atomic>

namespace cybersand::gentek_swarm::assembly004 {

// One aggregate allowance is shared by every initial/revised MOSAIC proposal.
// Failed GEN-003 calls whose actual work is unavailable consume their complete
// allowance. A cancellation never returns those already consumed resources.
struct MosaicBudget {
    std::uint64_t generator_remaining = 2'000'000;
    std::uint64_t solver_remaining = 4'000'000;
    std::size_t max_bytes = 16U * 1024U * 1024U;
    std::uint32_t proposals_remaining = 5; // initial plus at most four rounds
    const std::atomic_bool* cancelled = nullptr;
};

enum class MosaicRevisionStatus { Complete, Blocked, Exhausted, Unsat, Invalid, Cancelled };
const char* name(MosaicRevisionStatus) noexcept;

struct MosaicCellRevision {
    std::uint32_t cell{};
    Material before = Material::Empty, after = Material::Empty;
    std::uint32_t before_part{}, after_part{};
};
struct MosaicCategoryRevision {
    std::uint32_t tile{};
    int before = -1, after = -1;
};
struct MosaicBearingReplacement {
    std::uint32_t slot{}, instance{};
    Point point{};
    Material before = Material::Stone, after = Material::LimestoneBlock;
    std::string rule = "swarm004/mosaic_native_bearing_v1";
};

struct SupportedNativeReceptor {
    std::uint32_t slot{}, connector{}, source_instance{}, receiving_instance{}, port_id{};
    Point root{}, contact{}, backing{}, facing{};
};

// SWARM-006 receipts describe actual MOSAIC-authored, source-bound native
// bearing variants. A proposal is never a joint. The original connector and
// categorical assignment remain immutable; every transition is replayed before
// final material-path validation. No candidate or debit is refunded on failure.
struct RecoveryAttempt {
    std::uint32_t slot{}, connector{}, ordinal{}, round{}, source_instance{}, host_instance{};
    Point root{}, contact{}, axis{};
    unsigned length{}, variant{};
    std::uint64_t work{};
    std::string phase = "receiver_bid", outcome, reason;
    bool operator==(const RecoveryAttempt&) const = default;
};
struct RecoveryCursor {
    std::uint32_t slot{}, next{};
    std::uint64_t observation{};
    bool exhausted = false;
    bool operator==(const RecoveryCursor&) const = default;
};
struct RecoveryEdit {
    Point point{};
    Material before = Material::Empty, after = Material::LimestoneBlock;
    Role before_role = Role::Empty, after_role = Role::Structure;
    std::uint32_t before_owner{}, after_owner{};
    bool operator==(const RecoveryEdit&) const = default;
};
struct MosaicRecoveryReceipt {
    std::uint32_t slot{}, connector{}, source_instance{}, host_instance{}, receiving_instance{}, port_id{};
    std::uint32_t round{}, candidate{};
    Point root{}, contact{}, backing{}, axis{}, cross{}, host{};
    unsigned length{}, variant{};
    Family source_family = Family::Frame, receiving_family = Family::Frame;
    std::uint64_t source_digest{}, prior_digest{}, work{};
    std::vector<RecoveryEdit> edits;
    bool operator==(const MosaicRecoveryReceipt&) const = default;
};

struct MosaicRevision {
    Request request; // exact immutable input used by the unchanged native donor
    MosaicPlan plan;
    ResilienceTrace trace;
    MosaicRevisionStatus status = MosaicRevisionStatus::Invalid;
    std::uint32_t round{};
    // Actual material-ID differences only. Reidentified unchanged material is
    // reported separately and cannot establish architectural revision.
    std::vector<MosaicCellRevision> geometry_changes;
    std::vector<MosaicCellRevision> provenance_changes;
    std::vector<MosaicCategoryRevision> category_changes;
    std::vector<MosaicBearingReplacement> bearing_replacements;
    std::vector<SupportedNativeReceptor> supported_receptors;
    std::vector<RecoveryAttempt> recovery_attempts;
    std::vector<MosaicRecoveryReceipt> recovery_receipts;
    std::vector<RecoveryCursor> recovery_frontier;
    std::uint64_t recovery_work{};
    std::uint64_t recovery_raster_work{}; // actual native finalization debit, included in recovery_work
    bool recovery_frontier_exhausted = false;
    std::uint64_t supported_receptor_work{};
    std::vector<std::string> bearing_rejections;
    std::uint64_t bearing_work{}; // included in wrapper_work; never double debit
    std::uint64_t wrapper_work{}, generator_work{}, solver_debit{};
    std::uint64_t peer_material_digest{}, previous_material_digest{};
    std::size_t memory_bound{};
    bool solver_work_observed = true;
    std::string reason;
};

// MOSAIC owns this response: it constructs admitted contour spans from its own
// territory plus the explicitly supplied shared zone, excluding immutable peer
// material and all protected cells, then selects its own GEN-003 categories.
// No World writes, late bridge construction or peer mutation occur here.
// Destruction is a separate post-composition operation; proposal inputs must be
// intact. Round 0 is the initial proposal; rounds 1..4 are reciprocal revisions.
MosaicRevision propose_mosaic_revision(
    const Request& base, const Result& peer,
    const std::vector<TransitionSlot>& slots,
    const std::vector<std::uint8_t>& shared_zone,
    MosaicBudget& budget, std::uint32_t round,
    const Result* previous = nullptr,
    const std::vector<int>* previous_categories = nullptr,
    bool optional_negotiation = true, bool native_bearing = false, bool supported_native_receptors = false);

// Proposed MOSAIC native receiver authoring, opt-in only. Does not create
// material or independently certify a joint. Source and native backing must exist.
bool author_supported_native_receptors(MosaicRevision&, const Result& immutable_frame,
    const std::vector<TransitionSlot>&, MosaicBudget&);

// Retains the solved native masonry/categories and searches finite authored
// bearing/corbel alternatives. Only MOSAIC writes its own provisional cells.
// Original source slots, current peer occupancy and immutable World masks are
// distinct inputs. Limits: <=8 reservations, <=64 candidates per slot per round,
// <=2 source-face endpoints, 14 forward positions, 10 authored alternatives.
MosaicRevision propose_mosaic_recovery(
    const Request& base, const Request& frame_request, const Result& peer,
    const Result& original_source, const std::vector<TransitionSlot>& original_slots,
    const std::vector<std::uint8_t>& shared_zone, const MosaicPlan& previous,
    const std::vector<MosaicRecoveryReceipt>& receipts,
    const std::vector<RecoveryCursor>& frontier,
    MosaicBudget&, unsigned round, bool optional_negotiation = true);

} // namespace cybersand::gentek_swarm::assembly004
