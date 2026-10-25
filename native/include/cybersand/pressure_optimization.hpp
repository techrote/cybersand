#pragma once

#include <cstddef>
#include <cstdint>

namespace cybersand {

// Execution v3's deterministic certificate work budget is not a wall-clock
// break-even model. Fixed weights and windows are bound by execution identity.
inline constexpr std::uint64_t kPressureOptimizationExecutionVersion = 3;
inline constexpr std::uint8_t kPressureCertificateWarmupVisits = 1;
inline constexpr std::uint8_t kPressureCertificateBackoffVisits = 8;
inline constexpr std::uint8_t kPressureCertificateTrialTicks = 8;
inline constexpr std::uint8_t kPressureCertificateSuspensionTicks = 32;
inline constexpr std::uint64_t kPressureCertificateInvalidationCharge = 1;
inline constexpr std::uint64_t kPressureCertificateProofCharge = 40;
inline constexpr std::uint64_t kPressureCertificateReuseCharge = 1;
inline constexpr std::uint64_t kPressureCertificateSavedCallCredit = 8;

// Execution budgets, not different pressure physics. Incomplete derived state
// selects the complete admitted reference operator, charged in the counters.
struct PressureOptimizationConfig {
    std::size_t index_chunk_capacity = 4096;
    std::uint64_t head_repair_cell_budget = 4U << 20U;
    std::size_t gas_member_capacity = 1U << 20U;
    std::uint64_t gas_invalidation_pair_budget = 4U << 20U;
};

enum class PressureOptimizationStatus : std::uint8_t {
    Disabled = 0, Cold = 1, Pending = 2, Ready = 3,
    ReferenceCapacityFallback = 4, ReferenceBudgetFallback = 5,
};

// Cumulative, owner-reduced work. Per-tick or campaign work is a snapshot
// difference. No per-cell atomics, no serialized cache or certificate authority.
struct PressureKernelWork {
    std::uint64_t water_material_calls = 0;
    std::uint64_t water_motion_calls = 0;
    std::uint64_t other_liquid_calls = 0;
    std::uint64_t certificate_attempts = 0;
    std::uint64_t certificate_reuses = 0;
    std::uint64_t certificate_saved_calls = 0;
    // Includes warmup/backoff and obligation deferrals as well as failed proofs;
    // attempts counts only the actual complete local proof evaluation.
    std::uint64_t certificate_declines = 0;
};

struct PressureOptimizationCounters : PressureKernelWork {
    // Owner-only work-budget bookkeeping; worker scratch stays seven words.
    std::uint64_t certificate_work_charged = 0, certificate_work_credited = 0;
    std::uint64_t certificate_work_windows = 0, certificate_work_suspensions = 0;
    std::uint64_t certificate_unavailable_ticks = 0, certificate_suspended_ticks = 0;
    std::uint64_t certificate_cold_resets = 0, certificate_cold_reset_cells = 0;
    std::uint64_t certificate_layer_activations = 0;
    std::uint64_t index_rebuilds = 0;
    std::uint64_t invalidation_rects = 0;
    std::uint64_t columns_recomputed = 0;
    std::uint64_t rows_recomputed = 0;
    std::uint64_t base_cells_written = 0;
    std::uint64_t final_cells_written = 0;
    std::uint64_t gas_reuses = 0;
    std::uint64_t gas_reference_passes = 0;
    std::uint64_t reference_fallbacks = 0;
    std::uint64_t fallback_resident_cells = 0;
    std::uint64_t certificate_invalidation_cells = 0;
    std::uint64_t preparation_nanoseconds = 0;
    std::uint64_t gas_nanoseconds = 0;
    std::uint64_t head_nanoseconds = 0;
    std::uint64_t gas_seed_cells = 0, gas_seed_probes = 0;
    std::uint64_t gas_bfs_cells = 0, gas_bfs_probes = 0, gas_bfs_nodes = 0;
    std::uint64_t gas_member_validations = 0, gas_member_stamps = 0, gas_component_reuses = 0;
    std::uint64_t gas_index_chunks = 0, gas_cache_build_cells = 0, gas_cache_builds = 0;
    std::uint64_t gas_component_proof_checks = 0, gas_member_initializations = 0, gas_member_builds = 0;
    std::uint64_t gas_invalidation_pairs = 0, gas_component_invalidations = 0, gas_dirty_chunks_queued = 0;
    std::uint64_t gas_capacity_fallbacks = 0, gas_budget_fallbacks = 0, gas_restart_fallbacks = 0;
    std::uint64_t gas_relabel_cells = 0, gas_identity_nodes = 0, gas_stamp_clear_cells = 0;
};

struct PressureOptimizationSnapshot {
    bool certificate_layer_enabled = false, certificate_contents_cold = false;
    std::uint8_t certificate_window_ticks = 0, certificate_suspend_remaining = 0;
    std::uint64_t certificate_window_charge = 0, certificate_window_credit = 0;
    std::uint64_t certificate_last_window_charge = 0, certificate_last_window_credit = 0;
    std::size_t certificate_buffer_capacity_bytes = 0;
    PressureOptimizationStatus status = PressureOptimizationStatus::Disabled;
    bool cached = false;
    bool dormant = false;
    bool gas_pending = false;
    std::uint64_t index_incarnation = 0;
    std::size_t indexed_chunks = 0;
    std::size_t column_groups = 0;
    std::size_t row_groups = 0;
    std::size_t dirty_column_groups = 0;
    std::size_t dirty_row_groups = 0;
    std::size_t index_chunk_capacity = 0;
    std::uint64_t head_repair_cell_budget = 0;
    std::size_t derived_capacity_bytes = 0;
    std::size_t worker_counter_capacity_bytes = 0;
    std::size_t common_counter_bytes = 0;
    std::size_t gas_components = 0, gas_valid_components = 0, gas_members = 0, gas_member_capacity = 0;
    std::size_t gas_dirty_chunks = 0, gas_capacity_bytes = 0;
    std::uint64_t gas_invalidation_pair_budget = 0;
    PressureOptimizationCounters counters{};
};

} // namespace cybersand
