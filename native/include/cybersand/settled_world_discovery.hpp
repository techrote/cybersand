#pragma once

#include "cybersand/settled_discovery.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <optional>

namespace cybersand::soliding {

inline constexpr std::size_t kMaximumWorldDiscoveryTiles = 16'384;

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
};

struct WorldDiscoveryTileSnapshot {
    DiscoveryTileKey key{};
    DiscoverySignals signals{};
    DiscoverySummary summary{};
};

class SettledWorldDiscoveryCoordinator final {
public:
    using ReadCellFunction = DiscoveryCell (*)(const void*, std::int64_t, std::int64_t);

    SettledWorldDiscoveryCoordinator(std::uint64_t incarnation, std::size_t tile_capacity);
    ~SettledWorldDiscoveryCoordinator();
    SettledWorldDiscoveryCoordinator(const SettledWorldDiscoveryCoordinator&) = delete;
    SettledWorldDiscoveryCoordinator& operator=(const SettledWorldDiscoveryCoordinator&) = delete;
    SettledWorldDiscoveryCoordinator(SettledWorldDiscoveryCoordinator&&) noexcept;
    SettledWorldDiscoveryCoordinator& operator=(SettledWorldDiscoveryCoordinator&&) noexcept;

    DiscoveryOutcome register_tile(DiscoveryTileKey key, DiscoveryBounds bounds,
                                   DiscoverySignals signals, std::uint64_t tick) noexcept;
    DiscoveryOutcome dirty(DiscoveryTileKey key, ProducerReason reason,
                           std::uint64_t tick) noexcept;
    DiscoveryOutcome observe(DiscoveryTileKey key, DiscoverySignals signals,
                             ProducerReason reason, std::uint64_t tick) noexcept;
    std::size_t advance(std::uint64_t tick, std::size_t budget,
                        const void* context, ReadCellFunction read);
    void fail() noexcept;
    void note_global_fence() noexcept;

    [[nodiscard]] std::optional<WorldDiscoveryTileSnapshot> tile(std::size_t index) const noexcept;
    [[nodiscard]] std::optional<std::size_t> find(DiscoveryTileKey key) const noexcept;
    [[nodiscard]] std::size_t size() const noexcept;
    [[nodiscard]] std::size_t capacity() const noexcept;
    [[nodiscard]] std::size_t pending() const noexcept;
    [[nodiscard]] std::uint64_t incarnation() const noexcept;
    [[nodiscard]] bool capacity_blocked() const noexcept;
    [[nodiscard]] DiscoveryHalt halted() const noexcept;
    [[nodiscard]] WorldDiscoveryMetrics producer_metrics() const noexcept;
    [[nodiscard]] DiscoveryMetrics journal_metrics() const noexcept;
    [[nodiscard]] std::size_t storage_bytes() const noexcept;

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace cybersand::soliding
