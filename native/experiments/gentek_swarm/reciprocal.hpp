#pragma once
#include "assembly.hpp"
#include "reciprocal_mosaic.hpp"
#include <optional>
#include <memory>

namespace cybersand::gentek_swarm::assembly004 {
inline constexpr const char* composition_identity = "gentek_swarm_004_reciprocal_assembly_v1";
inline constexpr const char* recovery_identity = "gentek_swarm_006_negotiated_recovery_v1";
struct Options {
    unsigned rounds = 2;
    bool vocabulary = true, hierarchy = true, shared_ownership = true;
    bool frame_adaptation = true, mosaic_adaptation = true, optional_negotiation = true;
    bool final_validation = true;
    bool native_mosaic_bearing = true;
    bool supported_native_receptors = false; // SWARM-005 opt-in; frozen SWARM-004 controls remain off
    bool compact_native_termination = false; // Opt-in genuine pre-freeze authored cap for constrained exits
    bool negotiated_recovery = false; // SWARM-006: independently versioned, never a production default
    bool recovery_offers = true; // matched no-offer scientific control; meaningful only with recovery
    unsigned shared_extent = 13;
    int orientation_preference = -1; // -1 balanced; 0 horizontal; 1 vertical
};
struct Input {
    Request frame, mosaic;
    std::vector<std::uint8_t> shared_zone;
    Options options;
    const std::atomic_bool* cancel = nullptr;
};
enum class CompositionStatus { Complete, Blocked, Unsat, Exhausted, Invalid, Cancelled, Oscillation };
const char* name(CompositionStatus) noexcept;
struct Construction {
    std::uint32_t slot{}, connector{}, base_instance{};
    Point root{}, face{}, facing{};
    std::vector<std::uint32_t> parts;
    std::vector<std::uint32_t> reused_host_components;
    std::string rule;
    Symbol authored_symbol;
    unsigned span{}, rise{};
    int handedness{};
    Family input_family=Family::Frame;
    ExpandedAssembly assembly;
};
struct FrameRevision {
    Result result;
    std::vector<TransitionSlot> slots;
    std::vector<Construction> constructions;
    std::vector<std::string> rejections;
    std::uint32_t local_terminations{};
};
struct Round {
    unsigned number{};
    FrameRevision frame;
    MosaicPlan mosaic;
    Request mosaic_request;
    Result proposed_frame, proposed_mosaic; // retained even when arbitration rolls back
    ResilienceTrace mosaic_trace;
    std::string mosaic_proposal_reason;
    std::uint64_t mosaic_proposal_work{}, mosaic_proposal_solver_debit{};
    std::vector<MosaicBearingReplacement> mosaic_bearing_replacements;
    std::vector<std::string> mosaic_bearing_rejections;
    std::uint64_t mosaic_bearing_work{};
    std::uint64_t mosaic_supported_receptor_work{};
    std::vector<SupportedNativeReceptor> mosaic_supported_receptors;
    bool mosaic_reused = false, frame_reused = false;
    std::vector<RecoveryAttempt> recovery_attempts;
    std::vector<MosaicRecoveryReceipt> mosaic_recovery_receipts;
    std::vector<RecoveryCursor> recovery_frontier;
    std::uint64_t recovery_work{};
    bool recovery_frontier_exhausted = false;
    unsigned mosaic_reuse_round{}, frame_reuse_round{};
    std::uint64_t geometry_digest{}, semantic_digest{};
    std::uint64_t frame_changed{}, mosaic_changed{}, category_changed{};
    std::uint64_t frame_footprint_changed{}, mosaic_footprint_changed{};
    std::uint64_t frame_work{}, mosaic_work{}, solver_work{}, shared_work{};
    bool frame_accepted = true, mosaic_accepted = true;
    std::string reason;
};
struct JointWitness {
    std::uint32_t connector{}, slot{}, frame_instance{}, mosaic_instance{};
    Point root{}, frame_face{}, masonry_face{}, normal{};
    Family family = Family::Frame;
    std::vector<Point> path;
};
struct ObligationReceipt {
    std::uint32_t connector{}, instance{}, slot{};
    Point original{}, facing{};
    bool foreign_joined = false, local_terminated = false;
    std::string origin = "original_frame";
    std::string state = "STILL_REQUIRED", reason;
};
struct CellLedger {
    std::uint8_t owner{}; // 0 empty, 1 FRAME, 2 MOSAIC, 3 immutable environment
    std::uint32_t instance{}, rule{};
    std::uint8_t first_round{}, last_round{}, revision_mask{};
};
struct DamageDerivative {
    FrameRevision frame;
    MosaicPlan mosaic;
    std::uint64_t frame_changed{}, mosaic_changed{}, frame_footprint_changed{}, mosaic_footprint_changed{}, work{};
    std::string reason;
};
class NativeRunAuthority; // opaque: never deserialized, never minted by callers
struct Composition {
    Input input;
    CompositionStatus status = CompositionStatus::Invalid;
    std::string reason, stop_reason;
    FramePlan original_frame;
    std::vector<Round> rounds;
    std::optional<DamageDerivative> damage_derivative;
    std::vector<Material> cells;
    std::vector<CellLedger> ledger;
    std::vector<std::string> rules;
    std::vector<ObligationReceipt> obligations;
    std::vector<JointWitness> joints;
    std::map<std::string, std::uint64_t> metrics;
    std::vector<std::string> rejections;
    std::uint64_t digest{};
    bool can_apply = false;
private:
    std::shared_ptr<const NativeRunAuthority> native_authority_;
    friend Composition assemble(const Input&, bool);
    friend bool validate_composition(Composition&);
};
Profile expression_profile(const std::string&);
Input input_for(const Fixture&, const Profile&, std::uint64_t, const std::string&, Options = {});
Composition assemble(const Input&, bool reverse_evaluation = false);
// Validator never creates/replaces architecture cells. Diagnostic off mode is
// never commit-authorized. Revalidation after mutation is available to tests.
bool validate_composition(Composition&);
void write_composition_json(const std::string&, const Composition&);
} // namespace cybersand::gentek_swarm::assembly004
