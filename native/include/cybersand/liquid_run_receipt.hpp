#pragma once
// LCB-001 typed tick-zero construction receipts. Native facts are captured by
// the exclusive owner; host claims remain explicitly unverified.
#include "cybersand/prepared_setup_identity.hpp"
#include "cybersand/water_normalization.hpp"
#include "cybersand/world.hpp"
#include "cybersand/liquid_construction_refusal.hpp"
#include <algorithm>
#include <string>

namespace cybersand::receipt {
using setup::Digest;
using setup::SetupDescriptor;
using setup::validate_setup_descriptor;
using setup::prepared_setup_identity;
using setup::encode_setup_descriptor;
namespace encoding = setup::encoding;
enum class RunIntent : std::uint8_t { Controlled = 1, Exploratory = 2 };
enum class PlaneActivity : std::uint8_t { Active = 1, ConfiguredInactive = 2 };
enum class Pacing : std::uint8_t { FixedSteps = 1, HostPaced = 2 };
enum class Platform : std::uint8_t { Linux = 1, Windows = 2, Web = 3 };
enum class Architecture : std::uint8_t { X86_64 = 1, Wasm32 = 2 };
enum class ClaimOrigin : std::uint8_t { CallerClaim = 1 };
inline ClaimOrigin parse_claim_origin(std::string_view value) {
    if (value != "caller_claim") throw std::invalid_argument("verified provenance is unavailable to claim inputs");
    return ClaimOrigin::CallerClaim;
}
enum Qualification : std::uint32_t {
    SetupCoverageIncomplete = 1U, SourceClaimUnverified = 2U, RuntimeClaimUnverified = 4U,
    HostExecutionUnverified = 8U, QuantityAccountingUnavailable = 32U,
};
struct SourceClaim {
    // Claims only: a correct shape or hash never supplies provenance verification.
    std::string commit;
    std::optional<std::string> tree;
    std::optional<Digest> local_delta;
    ClaimOrigin origin = ClaimOrigin::CallerClaim;
};
struct RuntimeClaim {
    Digest artifact_sha256{};
    Platform platform = static_cast<Platform>(0);
    Architecture architecture = static_cast<Architecture>(0);
    std::string engine;
    ClaimOrigin origin = ClaimOrigin::CallerClaim;
};
struct ProvenanceClaims { std::optional<SourceClaim> source; std::optional<RuntimeClaim> runtime; };
struct HostExecution {
    Pacing pacing = Pacing::FixedSteps;
    bool simulation_window_enabled = false, cadence_lod_enabled = false;
    std::uint32_t tick_rate_numerator = 60, tick_rate_denominator = 1;
};
struct SolverStateExtension {
    std::uint8_t family = 0;
    std::uint16_t state_contract_version = 0, extension_identity_version = 0;
    std::optional<Digest> extension_digest;
};
struct NativeFactValues {
    WorldConfig config;
    SetupDescriptor setup;
    Digest prepared_native_payload{};
    std::optional<RectI64> selected_region;
    bool adhesion = true;
    std::uint64_t attempted_tick = 0, completed_tick = 0, physical_hash = 0;
    std::uint32_t physical_hash_version = 0;
    std::optional<SimulationCoreRange> selected_cores, applied_cores;
    std::vector<SolverStateExtension> solver_state_extensions;
    std::optional<PressureFlowParameters> effective_pressure;
    QuantityLedgerSnapshot quantity; // Native schema and exact aggregates, not an ordered replay.
};
class NativeFacts;
NativeFacts capture_native_facts(const World&, const SetupDescriptor&);
class NativeFacts final {
public:
    const NativeFactValues& values() const noexcept { return values_; }
private:
    friend NativeFacts capture_native_facts(const World&, const SetupDescriptor&);
    explicit NativeFacts(NativeFactValues values) : values_(std::move(values)) {}
    NativeFactValues values_;
};
// Owned values expose no mutable canonical bytes or qualifications. A failed
// construction has a distinct type and cannot be installed as an applied run.
class ReceiptEncoding {
public:
    std::span<const std::uint8_t> canonical_bytes() const noexcept { return bytes_; }
    const Digest& receipt_hash() const noexcept { return hash_; }
    std::uint32_t qualifications() const noexcept { return qualifications_; }
    // Full host setup, execution fences and provenance verification are #202.
    bool eligible_for_full_matched_evidence() const noexcept { return false; }
protected:
    ReceiptEncoding(std::vector<std::uint8_t> bytes, std::uint32_t qualifications)
        : bytes_(std::move(bytes)), hash_(Sha256::of(bytes_)), qualifications_(qualifications) {}
private:
    std::vector<std::uint8_t> bytes_;
    Digest hash_{};
    std::uint32_t qualifications_;
};
class AppliedRunReceipt final : public ReceiptEncoding {
private:
    friend AppliedRunReceipt build_applied_run_receipt(const NativeFacts&, const SetupDescriptor&,
        std::span<const std::int32_t>, RunIntent, PlaneActivity, const HostExecution&,
        const ProvenanceClaims&, std::uint64_t, const std::optional<normalization::Receipt>&);
    AppliedRunReceipt(std::vector<std::uint8_t> bytes, std::uint32_t qualifications)
        : ReceiptEncoding(std::move(bytes), qualifications) {}
};
class ConstructionAttemptReceipt final : public ReceiptEncoding {
private:
    friend ConstructionAttemptReceipt build_construction_attempt_receipt(const NativeFacts&, const NativeFacts&,
        const ConstructionRefusal&, std::uint64_t, std::uint64_t);
    ConstructionAttemptReceipt(std::vector<std::uint8_t> bytes, std::uint32_t qualifications)
        : ReceiptEncoding(std::move(bytes), qualifications) {}
};
namespace detail {
inline void boolean(encoding::Writer& out, bool value) { out.integer(static_cast<std::uint8_t>(value)); }
inline bool lowercase_hex(std::string_view value, std::size_t length) {
    return value.size() == length && std::all_of(value.begin(), value.end(), [](char c) {
        return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f');
    });
}
inline void claims(encoding::Writer& out, const ProvenanceClaims& value) {
    boolean(out, value.source.has_value());
    if (value.source) {
        const auto& s = *value.source;
        if (s.origin != ClaimOrigin::CallerClaim)
            throw std::invalid_argument("source claim cannot select verified provenance");
        if (!lowercase_hex(s.commit, 40) || (s.tree && !lowercase_hex(*s.tree, 40)))
            throw std::invalid_argument("invalid source identity shape");
        out.integer(std::uint8_t{1}); // caller claim; never upgraded to verified
        out.text(s.commit); boolean(out, s.tree.has_value()); if (s.tree) out.text(*s.tree);
        out.optional_digest(s.local_delta);
    }
    boolean(out, value.runtime.has_value());
    if (value.runtime) {
        const auto& r = *value.runtime;
        if (r.origin != ClaimOrigin::CallerClaim)
            throw std::invalid_argument("runtime claim cannot select verified provenance");
        const bool web = r.platform == Platform::Web;
        if ((r.platform != Platform::Linux && r.platform != Platform::Windows && !web) ||
            r.architecture != (web ? Architecture::Wasm32 : Architecture::X86_64) ||
            r.engine.empty() || r.engine.size() > 64 ||
            !std::all_of(r.engine.begin(), r.engine.end(), [](char c) { return c >= 32 && c <= 126; }))
            throw std::invalid_argument("invalid runtime identity shape");
        out.integer(std::uint8_t{1}); out.digest(r.artifact_sha256);
        out.integer(static_cast<std::uint8_t>(r.platform)); out.integer(static_cast<std::uint8_t>(r.architecture));
        out.text(r.engine);
    }
}
inline void policy_words(encoding::Writer& out, std::span<const std::int32_t> words) {
    if (words.size() > 4096) throw std::invalid_argument("policy request exceeds receipt bound");
    out.integer(static_cast<std::uint32_t>(words.size()));
    for (const auto word : words) out.integer(word);
}
inline Digest transport_identity(const TransportPolicy& p) {
    encoding::Writer out; out.text("cybersand-transport-receipt-v1");
    out.integer(std::uint16_t{1}); boolean(out, p.configured);
    for (const auto n : p.horizontal) out.integer(n);
    for (const auto n : p.cadence) out.integer(n);
    for (const auto& pair : p.pairs)
        for (const auto n : {pair.mixing, pair.carrying, pair.pickup, pair.packing, pair.erosion, pair.permeability})
            out.integer(n);
    return Sha256::of(out.bytes);
}
inline void region(encoding::Writer& out, const std::optional<RectI64>& value, std::int32_t core_size,
                   std::int32_t rule_radius) {
    // 0 unavailable (used for applied below), 1 unrestricted, 2 finite.
    out.integer(value ? std::uint8_t{2} : std::uint8_t{1});
    if (!value) return;
    const auto& r = *value;
    out.integer(r.x); out.integer(r.y); out.integer(r.width); out.integer(r.height);
    SchedulerGeometry geometry(core_size, rule_radius);
    const auto first = geometry.core_for_cell(r.x, r.y);
    const auto last = geometry.core_for_cell(r.x + (r.width - 1), r.y + (r.height - 1));
    out.integer(first.x); out.integer(first.y); out.integer(last.x); out.integer(last.y);
}
inline void cores(encoding::Writer& out, const std::optional<SimulationCoreRange>& value) {
    out.integer(value ? std::uint8_t{2} : std::uint8_t{1});
    if (!value) return;
    out.integer(value->min_x); out.integer(value->min_y);
    out.integer(value->max_x); out.integer(value->max_y);
}
inline void quantity_facts(encoding::Writer& out, const QuantityLedgerSnapshot& value) {
    if (value.schema_version != kQuantityLedgerSchemaVersion)
        throw std::invalid_argument("unsupported native quantity accounting schema");
    out.integer(value.schema_version); out.integer(value.mass_bits);
    out.integer(value.baseline_water); out.integer(value.water_visible); out.integer(value.water_overfill);
    const auto flow = [&](const WaterQuantityFlow& item) {
        out.integer(item.produced); out.integer(item.consumed);
    };
    out.integer(static_cast<std::uint16_t>(value.kinds.size()));
    for (const auto& item : value.kinds) flow(item);
    out.integer(static_cast<std::uint16_t>(value.pair_rules.size()));
    for (std::size_t i=0; i<value.pair_rules.size(); ++i) {
        flow(value.pair_rules[i]); out.integer(value.pair_events[i]);
    }
    out.integer(static_cast<std::uint16_t>(value.kernel_rules.size()));
    for (const auto& item : value.kernel_rules) flow(item);
    out.integer(static_cast<std::uint16_t>(value.material_cells.size()));
    for (const auto item : value.material_cells) out.integer(item);
    for (const auto item : value.prepared_material_cells) out.integer(item);
    boolean(out, value.construction.has_value());
    if (value.construction) {
        const auto& c = *value.construction;
        out.integer(c.mass_bits); out.integer(c.baseline_water);
        out.integer(c.normalization_produced); out.integer(c.normalization_consumed); out.integer(c.expected_final_water);
        out.digest(c.original_setup_identity); out.digest(c.prepared_setup_identity);
        out.digest(c.original_payload_digest); out.digest(c.prepared_payload_digest);
        out.optional_digest(c.normalization_receipt_digest);
    }
}
inline void native_facts(encoding::Writer& out, const NativeFacts& facts) {
    const auto& v = facts.values(); const auto& c = v.config;
    out.integer(std::uint8_t{1}); // native capture origin, inaccessible to claim inputs
    const auto& policy = c.liquid_solver_policy;
    out.digest(policy.policy_hash()); out.digest(policy.catalogue_digest()); out.digest(policy.capability_matrix_digest());
    policy_words(out, policy.envelope());
    out.integer(c.water_experiment_policy.version()); out.integer(c.water_experiment_policy.mass_bits());
    out.integer(c.water_experiment_policy.coherence_ticks());
    out.integer(static_cast<std::uint8_t>(c.water_experiment_policy.rest_policy()));
    out.digest(transport_identity(c.transport_policy));
    out.integer(InteractionPolicy::version); out.integer(c.interaction_policy.downward_support_cells);
    out.integer(c.interaction_policy.side_support_cells); out.integer(c.interaction_policy.mercury_exchange_period);
    out.integer(c.chunk_size); out.integer(c.activity_block_size); out.integer(c.scheduling_core_size);
    out.integer(c.maximum_rule_radius); out.integer(c.sleep_after_quiet_ticks); out.integer(c.ambient_temperature);
    out.integer(static_cast<std::uint8_t>(c.backend)); out.integer(c.worker_threads);
    for (const auto n : {c.initial_chunk_reserve, c.parallel_job_threshold, c.active_core_capacity,
                        c.active_chunk_capacity, c.maximum_chunk_count, c.deferred_event_capacity})
        out.integer(static_cast<std::uint64_t>(n));
    out.integer(c.maximum_explosion_radius); boolean(out, c.settled_discovery_enabled);
    out.integer(static_cast<std::uint64_t>(c.settled_discovery_tile_capacity));
    out.integer(static_cast<std::uint64_t>(c.settled_discovery_tick_budget));
    boolean(out, c.settled_region_connectivity_enabled); out.integer(static_cast<std::uint64_t>(c.settled_region_tick_budget));
    boolean(out, c.physics_diagnostics.enabled); boolean(out, c.physics_diagnostics.disable_powder_exchange_targets);
    out.integer(c.physics_diagnostics.mercury_viscosity); boolean(out, v.adhesion);
    region(out, v.selected_region, c.scheduling_core_size, c.maximum_rule_radius);
    cores(out, v.selected_cores); cores(out, v.applied_cores);
    out.integer(v.attempted_tick); out.integer(v.completed_tick);
    out.integer(std::uint8_t{1}); // current complete physical hash algorithm FNV-1a64
    out.integer(v.physical_hash_version); out.integer(v.physical_hash);
    if (v.solver_state_extensions.size() > 11U)
        throw std::invalid_argument("too many solver-owned state extensions");
    out.integer(static_cast<std::uint8_t>(v.solver_state_extensions.size()));
    std::uint8_t previous_family = 0;
    for (const auto& extension : v.solver_state_extensions) {
        if (extension.family <= previous_family || extension.family > 4U || extension.state_contract_version == 0U ||
            (extension.extension_digest.has_value() != (extension.extension_identity_version != 0U)))
            throw std::invalid_argument("invalid solver-owned state extension schema/order");
        previous_family = extension.family;
        out.integer(extension.family); out.integer(extension.state_contract_version);
        out.integer(extension.extension_identity_version); out.optional_digest(extension.extension_digest);
    }
    boolean(out, v.effective_pressure.has_value());
    if (v.effective_pressure) {
        out.integer(static_cast<std::uint16_t>(PressureFlowParameters::kVersion));
        boolean(out, v.effective_pressure->gas_enabled); out.integer(v.effective_pressure->atmospheric_head_rows);
    }
    quantity_facts(out, v.quantity);
}
inline void normalization(encoding::Writer& out, const std::optional<normalization::Receipt>& value,
                          const NativeFacts& facts, const SetupDescriptor& setup) {
    const auto& construction = facts.values().quantity.construction;
    const bool attached = construction && construction->normalization_receipt_digest.has_value();
    if (value.has_value() != attached)
        throw std::invalid_argument("normalization presence does not match the native construction ledger");
    boolean(out, value.has_value()); if (!value) return;
    const auto& n = *value;
    const auto& seed = *construction;
    if (seed.normalization_receipt_digest != n.receipt_hash() ||
        seed.original_payload_digest != n.payload_before_hash() ||
        seed.prepared_payload_digest != n.payload_after_hash() ||
        seed.original_setup_identity != n.setup_before_hash() ||
        seed.prepared_setup_identity != n.setup_after_hash() ||
        seed.baseline_water != n.totals().water_before ||
        seed.expected_final_water != n.totals().water_after ||
        seed.normalization_produced != n.totals().positive_delta ||
        seed.normalization_consumed != n.totals().negative_delta)
        throw std::invalid_argument("normalization is not the one installed in the native construction ledger");
    if (n.mass_bits() != facts.values().config.water_experiment_policy.mass_bits() ||
        n.seed_before() != setup.seed || n.seed_after() != setup.seed ||
        n.payload_after_hash() != facts.values().prepared_native_payload ||
        n.setup_before_hash() != prepared_setup_identity(setup, n.payload_before_hash()) ||
        n.setup_after_hash() != prepared_setup_identity(setup, facts.values().prepared_native_payload))
        throw std::invalid_argument("normalization is not bound to this actual prepared payload/setup");
    out.integer(normalization::Receipt::kSchemaVersion); out.text(normalization::Receipt::kRule);
    out.integer(normalization::Receipt::kRuleVersion); out.digest(n.receipt_hash());
    out.digest(n.payload_before_hash()); out.digest(n.payload_after_hash());
    out.digest(n.setup_before_hash()); out.digest(n.setup_after_hash());
    out.integer(n.seed_before()); out.integer(n.seed_after()); out.integer(n.mass_bits());
    const auto& t = n.totals();
    out.integer(t.cells_up); out.integer(t.cells_down); out.integer(t.cells_unchanged);
    out.integer(t.positive_delta); out.integer(t.negative_delta); out.integer(t.net_delta);
    out.integer(t.water_before); out.integer(t.water_after);
}
} // namespace detail

inline AppliedRunReceipt build_applied_run_receipt(const NativeFacts& native, const SetupDescriptor& setup,
    std::span<const std::int32_t> requested_policy, RunIntent intent, PlaneActivity activity,
    const HostExecution& execution, const ProvenanceClaims& provenance, std::uint64_t committed_generation,
    const std::optional<normalization::Receipt>& normalized = std::nullopt) {
    validate_setup_descriptor(setup);
    if (setup != native.values().setup || native.values().completed_tick != 0 || native.values().attempted_tick != 0 ||
        committed_generation == 0)
        throw std::invalid_argument("applied construction receipt requires this native tick-zero setup and committed generation");
    if ((intent != RunIntent::Controlled && intent != RunIntent::Exploratory) ||
        (activity != PlaneActivity::Active && activity != PlaneActivity::ConfiguredInactive) ||
        (execution.pacing != Pacing::FixedSteps && execution.pacing != Pacing::HostPaced) ||
        execution.tick_rate_numerator == 0 || execution.tick_rate_denominator == 0)
        throw std::invalid_argument("unknown execution schema/value");
    if (requested_policy.size() > 4096U) throw std::invalid_argument("policy request exceeds receipt bound");
    const auto decoded = LiquidSolverPolicy::decode(requested_policy);
    if (!decoded.accepted() || decoded.policy->policy_hash() != native.values().config.liquid_solver_policy.policy_hash())
        throw std::invalid_argument("requested policy was not the applied native policy");
    constexpr auto qualifications = SetupCoverageIncomplete | SourceClaimUnverified | RuntimeClaimUnverified |
                                    HostExecutionUnverified;
    encoding::Writer out; out.text("cybersand-run-receipt-v1"); out.integer(std::uint16_t{1});
    out.integer(static_cast<std::uint8_t>(intent)); out.integer(static_cast<std::uint8_t>(activity));
    out.integer(static_cast<std::uint32_t>(qualifications)); out.integer(committed_generation); out.integer(std::uint64_t{0});
    detail::policy_words(out, requested_policy); detail::native_facts(out, native);
    encode_setup_descriptor(out, setup); out.digest(native.values().prepared_native_payload);
    out.digest(prepared_setup_identity(setup, native.values().prepared_native_payload));
    detail::normalization(out, normalized, native, setup);
    out.integer(static_cast<std::uint8_t>(execution.pacing)); detail::boolean(out, execution.simulation_window_enabled);
    detail::boolean(out, execution.cadence_lod_enabled); out.integer(execution.tick_rate_numerator);
    out.integer(execution.tick_rate_denominator); detail::claims(out, provenance);
    return AppliedRunReceipt(std::move(out.bytes), qualifications);
}

inline ConstructionAttemptReceipt build_construction_attempt_receipt(const NativeFacts& retained_before, const NativeFacts& retained_after,
    const ConstructionRefusal& refusal, std::uint64_t generation_before, std::uint64_t generation_after) {
    encoding::Writer before, after; detail::native_facts(before, retained_before); detail::native_facts(after, retained_after);
    if (generation_before == 0 || generation_before != generation_after || before.bytes != after.bytes ||
        retained_before.values().setup != retained_after.values().setup ||
        retained_before.values().prepared_native_payload != retained_after.values().prepared_native_payload)
        throw std::invalid_argument("refused attempt must preserve the captured live receipt and generation");
    encoding::Writer out; out.text("cybersand-construction-attempt-v1"); out.integer(std::uint16_t{1});
    out.integer(generation_before);
    out.integer(static_cast<std::uint8_t>(refusal.request_scope()));
    out.integer(static_cast<std::uint8_t>(refusal.outcome_kind()));
    out.digest(refusal.request_hash());
    detail::policy_words(out, refusal.requested_policy());
    detail::boolean(out, refusal.policy_refusal().has_value());
    if (refusal.policy_refusal()) {
        const auto& reason = *refusal.policy_refusal();
        out.integer(static_cast<std::uint8_t>(reason.code)); detail::boolean(out, reason.material.has_value());
        if (reason.material) out.integer(*reason.material);
        out.text(reason.detail);
    }
    out.text(refusal.failure_detail());
    detail::native_facts(out, retained_after);
    encode_setup_descriptor(out, retained_after.values().setup);
    out.digest(retained_after.values().prepared_native_payload);
    out.digest(prepared_setup_identity(retained_after.values().setup, retained_after.values().prepared_native_payload));
    return ConstructionAttemptReceipt(std::move(out.bytes), 0);
}
} // namespace cybersand::receipt
