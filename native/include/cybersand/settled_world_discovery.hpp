#pragma once

#include "cybersand/settled_discovery.hpp"
#include "cybersand/settled_regions.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <optional>

namespace cybersand::soliding {

inline constexpr std::size_t kMaximumWorldDiscoveryTiles = 16'384;
inline constexpr std::size_t kMaximumIntegratedRegionTiles = 4'096;

enum class ProducerReason : std::uint8_t {
    DirectMutation,
    WorkerMutation,
    ActivityOrDeadline,
    TransientMask,
    PendingEvent,
    InclusionFence,
    SemanticFence,
    Registration,
    Count,
};

enum class DiscoveryCoverageState : std::uint8_t {
    NotResident,
    ResidentUntracked,
    RegisteredUnknown,
    Ready,
    Excluded,
    Blocked,
    CapacityRefused,
    Failed,
};

struct WorldDiscoveryMetrics {
    std::array<std::uint64_t, static_cast<std::size_t>(ProducerReason::Count)> notifications{};
    std::array<std::uint64_t, static_cast<std::size_t>(ProducerReason::Count)> invalidated_tiles{};
    std::uint64_t registration_work{};
    std::uint64_t registration_refusals{};
    std::uint64_t index_probes{};
    std::uint64_t signal_observations{};
    std::uint64_t global_fences{};
    std::uint64_t mapped_tiles{};
    std::uint64_t capacity_halts{};
    std::uint64_t payload_mutations{};
    std::uint64_t payload_work_enqueued{};
    std::uint64_t payload_work_coalesced{};
    std::uint64_t payload_work_serviced{};
    std::uint64_t payload_queue_high_water{};
    std::uint64_t worker_report_records{};
    std::uint64_t worker_report_overflows{};
    std::uint64_t observation_fences{};
    std::uint64_t activity_witnesses{};
    std::uint64_t activity_transitions{};
    std::uint64_t deadline_insertions{};
    std::uint64_t deadline_replacements{};
    std::uint64_t deadline_cancellations{};
    std::uint64_t deadline_consumptions{};
    std::uint64_t deadline_parks{};
    std::uint64_t deadline_reentries{};
    std::uint64_t deadline_ready{};
    std::uint64_t deadline_heap_high_water{};
    std::uint64_t deadline_generation_exhaustions{};
    std::uint64_t signal_report_records{};
    std::uint64_t signal_report_overflows{};
    std::uint64_t mask_witnesses{};
    std::uint64_t mask_reconfigurations{};
    std::uint64_t mask_occupancy_high_water{};
    std::uint64_t event_witnesses{};
    std::uint64_t event_pending_high_water{};
    std::uint64_t inclusion_requests{};
    std::uint64_t inclusion_applications{};
    std::uint64_t inclusion_witnesses{};
    std::uint64_t nonpayload_generation_exhaustions{};
    std::uint64_t coverage_notifications{};
    std::uint64_t coverage_unknown_revocations{};
    std::uint64_t coverage_state_transitions{};
};

struct WorldDiscoveryTileHandle {
    std::uint64_t world_incarnation{};
    std::uint32_t slot{};
    bool operator==(const WorldDiscoveryTileHandle&) const = default;
};

struct WorldDiscoveryTileSnapshot {
    DiscoveryTileKey key{};
    DiscoverySignals signals{};
    DiscoverySummary summary{};
    DiscoveryCoverageState coverage{DiscoveryCoverageState::RegisteredUnknown};
    std::uint64_t mask_occupancy_count{};
    std::uint64_t pending_event_count{};
    std::uint64_t mask_revision{};
    std::uint64_t event_revision{};
    std::uint64_t requested_inclusion_epoch{};
    std::uint64_t applied_inclusion_epoch{};
};

struct DiscoveryParentKey {
    std::uint64_t world_incarnation{};
    std::int64_t chunk_y{}, chunk_x{};
    std::int32_t activity_y{}, activity_x{};
    bool operator==(const DiscoveryParentKey&) const = default;
};

struct DiscoveryParentKeyLess {
    bool operator()(const DiscoveryParentKey& a, const DiscoveryParentKey& b) const noexcept {
        if (a.world_incarnation != b.world_incarnation)
            return a.world_incarnation < b.world_incarnation;
        if (a.chunk_y != b.chunk_y) return a.chunk_y < b.chunk_y;
        if (a.chunk_x != b.chunk_x) return a.chunk_x < b.chunk_x;
        if (a.activity_y != b.activity_y) return a.activity_y < b.activity_y;
        return a.activity_x < b.activity_x;
    }
};

struct DiscoveryDeadlineSnapshot {
    DiscoveryParentKey parent{};
    std::uint64_t due_tick{};
    std::uint64_t generation{};
    bool parked{};
    bool ready{};
};

struct WorldDiscoveryStorageLayout {
    std::size_t effective_tile_capacity{};
    std::size_t journal_capacity{};
    std::size_t owner_record_capacity{};
    std::size_t key_index_capacity{};
    std::size_t journal_storage_bytes{};
    std::size_t owner_record_storage_bytes{};
    std::size_t key_index_storage_bytes{};
    std::size_t payload_queue_capacity{};
    std::size_t payload_queue_storage_bytes{};
    std::size_t activity_parent_capacity{};
    std::size_t activity_parent_index_capacity{};
    std::size_t deadline_heap_capacity{};
    std::size_t activity_parent_storage_bytes{};
    std::size_t activity_parent_index_storage_bytes{};
    std::size_t deadline_heap_storage_bytes{};
    std::size_t sparse_witness_record_capacity{};
    std::size_t sparse_witness_record_storage_bytes{};
    std::size_t region_tile_capacity{};
    std::size_t region_edge_capacity{};
    std::size_t region_frontier_capacity{};
    std::size_t region_seen_capacity{};
    std::size_t region_member_capacity{};
    std::size_t region_dependency_capacity{};
    std::size_t region_revision_capacity{};
    std::size_t region_key_index_capacity{};
    std::size_t region_row_interval_capacity{};
    std::size_t region_tile_cell_capacity{};
    std::size_t region_components_per_tile{};
    std::size_t region_boundary_slots_per_tile{};
    std::size_t publication_capacity{};
    std::size_t region_storage_bytes{};
    bool regions_enabled{};
};

// Narrow deterministic fault-injection seam for lifecycle ordering tests.
// It only affects the next coordinator construction and never simulation state.
namespace testing {
void fail_next_settled_world_discovery_construction() noexcept;
void set_next_deadline_generation_limit(std::uint64_t limit) noexcept;
void set_next_nonpayload_generation_limit(std::uint64_t limit) noexcept;
}

class SettledWorldDiscoveryCoordinator final {
public:
    using ReadCellFunction = DiscoveryCell (*)(const void*, std::int64_t, std::int64_t);
    using ReadSignalsFunction = DiscoverySignals (*)(
        const void*, DiscoveryTileKey, DiscoveryBounds, DiscoverySignals);

    SettledWorldDiscoveryCoordinator(std::uint64_t incarnation, std::size_t tile_capacity,
                                     bool regions_enabled = false);
    ~SettledWorldDiscoveryCoordinator();
    SettledWorldDiscoveryCoordinator(const SettledWorldDiscoveryCoordinator&) = delete;
    SettledWorldDiscoveryCoordinator& operator=(const SettledWorldDiscoveryCoordinator&) = delete;
    SettledWorldDiscoveryCoordinator(SettledWorldDiscoveryCoordinator&&) noexcept;
    SettledWorldDiscoveryCoordinator& operator=(SettledWorldDiscoveryCoordinator&&) noexcept;

    DiscoveryOutcome register_tile(DiscoveryTileKey key, DiscoveryBounds bounds,
                                   std::int16_t ambient_temperature,
                                   DiscoverySignals signals, std::uint64_t tick,
                                   std::uint64_t mask_occupancy_count = 0,
                                   std::uint64_t pending_event_count = 0,
                                   bool requested_included = true,
                                   bool applied_included = true) noexcept;
    DiscoveryOutcome dirty(DiscoveryTileKey key, ProducerReason reason,
                           std::uint64_t tick) noexcept;
    DiscoveryOutcome dirty(WorldDiscoveryTileHandle handle, ProducerReason reason,
                           std::uint64_t tick) noexcept;
    DiscoveryOutcome notify_payload(DiscoveryTileKey key, ProducerReason reason,
                                    std::uint64_t tick,
                                    std::uint64_t mutation_count = 1) noexcept;
    DiscoveryOutcome notify_payload(WorldDiscoveryTileHandle handle, ProducerReason reason,
                                    std::uint64_t tick,
                                    std::uint64_t mutation_count = 1) noexcept;
    DiscoveryOutcome observe(DiscoveryTileKey key, DiscoverySignals signals,
                             ProducerReason reason, std::uint64_t tick) noexcept;
    DiscoveryOutcome observe(WorldDiscoveryTileHandle handle, DiscoverySignals signals,
                             ProducerReason reason, std::uint64_t tick) noexcept;

    DiscoveryOutcome witness_mask(WorldDiscoveryTileHandle handle, bool add,
                                  std::uint64_t tick) noexcept;
    DiscoveryOutcome witness_mask_reconfiguration(WorldDiscoveryTileHandle handle,
                                                  std::uint64_t tick) noexcept;
    DiscoveryOutcome witness_event(WorldDiscoveryTileHandle handle, bool add,
                                   std::uint64_t tick) noexcept;
    DiscoveryOutcome begin_inclusion_request() noexcept;
    DiscoveryOutcome apply_inclusion_request() noexcept;
    DiscoveryOutcome witness_inclusion(WorldDiscoveryTileHandle handle,
                                       bool requested_included,
                                       bool applied_included,
                                       std::uint64_t tick) noexcept;
    [[nodiscard]] std::uint64_t requested_inclusion_epoch() const noexcept;
    [[nodiscard]] std::uint64_t applied_inclusion_epoch() const noexcept;
    [[nodiscard]] DiscoveryCoverageState coverage_state(
        WorldDiscoveryTileHandle handle) const noexcept;

    DiscoveryOutcome register_activity_parent(DiscoveryParentKey key, bool active,
                                              std::uint64_t deadline_due) noexcept;
    DiscoveryOutcome witness_activity(DiscoveryParentKey key, bool active) noexcept;
    DiscoveryOutcome schedule_deadline(DiscoveryParentKey key, std::uint64_t due_tick) noexcept;
    DiscoveryOutcome cancel_deadline(DiscoveryParentKey key) noexcept;
    DiscoveryOutcome mark_deadline_ready(DiscoveryParentKey key) noexcept;
    DiscoveryOutcome park_deadline(DiscoveryParentKey key) noexcept;
    DiscoveryOutcome consume_deadline(DiscoveryParentKey key) noexcept;
    [[nodiscard]] std::optional<DiscoveryDeadlineSnapshot> next_deadline() const noexcept;
    [[nodiscard]] std::optional<DiscoveryDeadlineSnapshot> deadline_state(
        DiscoveryParentKey key) const noexcept;
    [[nodiscard]] std::size_t activity_parent_count() const noexcept;
    [[nodiscard]] std::size_t deadline_heap_size() const noexcept;
    [[nodiscard]] std::size_t deadline_ready_count() const noexcept;

    std::size_t advance(std::uint64_t tick, std::size_t budget,
                        const void* context, ReadCellFunction read);
    std::size_t advance(std::uint64_t tick, std::size_t budget,
                        const void* context, ReadCellFunction read,
                        ReadSignalsFunction read_signals);
    std::size_t advance_regions(std::size_t budget) noexcept;
    void fail() noexcept;
    void note_global_fence() noexcept;
    void note_worker_report_records(std::size_t records) noexcept;
    void note_signal_report_records(std::size_t records) noexcept;
    void fence_lost_payload_report() noexcept;
    void fence_lost_signal_report() noexcept;

    [[nodiscard]] std::optional<WorldDiscoveryTileSnapshot> tile(std::size_t index) const noexcept;
    [[nodiscard]] std::optional<WorldDiscoveryTileSnapshot> tile(
        WorldDiscoveryTileHandle handle) const noexcept;
    [[nodiscard]] std::optional<std::size_t> find(DiscoveryTileKey key) const noexcept;
    [[nodiscard]] std::optional<WorldDiscoveryTileHandle> find_handle(
        DiscoveryTileKey key) const noexcept;
    [[nodiscard]] std::optional<WorldDiscoveryTileHandle> handle_at(
        std::size_t index) const noexcept;
    [[nodiscard]] std::size_t size() const noexcept;
    [[nodiscard]] std::size_t capacity() const noexcept;
    [[nodiscard]] std::size_t pending() const noexcept;
    [[nodiscard]] std::size_t pending_payload_work() const noexcept;
    [[nodiscard]] bool payload_refresh_pending(WorldDiscoveryTileHandle handle) const noexcept;
    [[nodiscard]] std::uint64_t incarnation() const noexcept;
    [[nodiscard]] bool capacity_blocked() const noexcept;
    [[nodiscard]] DiscoveryHalt halted() const noexcept;
    [[nodiscard]] WorldDiscoveryMetrics producer_metrics() const noexcept;
    [[nodiscard]] DiscoveryMetrics journal_metrics() const noexcept;
    [[nodiscard]] std::size_t storage_bytes() const noexcept;
    [[nodiscard]] WorldDiscoveryStorageLayout storage_layout() const noexcept;
    [[nodiscard]] bool regions_enabled() const noexcept;
    [[nodiscard]] std::size_t region_count() const noexcept;
    [[nodiscard]] std::optional<SettledRegionSnapshot> region(std::size_t slot) const noexcept;
    [[nodiscard]] SettledRegionMetrics region_metrics() const noexcept;
    [[nodiscard]] RegionRefusal region_refusal() const noexcept;
    [[nodiscard]] std::size_t region_storage_bytes() const noexcept;

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace cybersand::soliding
