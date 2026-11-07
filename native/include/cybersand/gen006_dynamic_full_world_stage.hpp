#pragma once

// GEN-006 opt-in owner-side FULL-WORLD dynamic continuation stage.
// This is intentionally NOT a selective chunk eviction API. It uses the
// existing source-matched native CYPS World serializer as the only physical
// authority until a future, separately admitted atomic multi-chunk API exists.
// No default World, material, scheduler, ABI or storage format is changed.

#include "cybersand/world.hpp"

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <span>
#include <stdexcept>
#include <utility>
#include <vector>

namespace cybersand::gen006 {

// Allocated, retained and advanced by the serialized external owner. In
// particular, a new residency or clear/reload must not reuse incarnation.
// The World itself cannot verify session, recipe or storage durability.
struct FullWorldFence {
    std::uint64_t session = 0;
    std::uint64_t recipe = 0;
    std::uint64_t incarnation = 0;
    std::uint64_t generation = 0;
    friend bool operator==(const FullWorldFence&, const FullWorldFence&) = default;
    [[nodiscard]] bool valid() const noexcept {
        return session && recipe && incarnation && generation;
    }
};

enum class FullWorldCommitStatus : std::uint8_t {
    Committed,
    AlreadyCommitted,
    NoLiveOwner,
    StaleOwner,
    StaleFence,
    StaleSource,
    UnverifiedCopy,
    SnapshotFailure,
};

// Exclusive-owner transaction with private native restore and a single
// no-throw unique_ptr swap at commit. The caller must supply an independently
// re-read exact byte copy from its publication layer; bytes alone do not prove
// fsync, crash durability or correct external recipe fencing.
//
// Staging does not free a selected chunk. It deliberately snapshots every
// native chunk/sidecar so active cross-chunk Sand/Water is never misrepresented
// as safely evictable by the Wall/Empty-only G6KC1 per-chunk contract.
class FullWorldContinuationStage final {
public:
    static FullWorldContinuationStage capture(const std::unique_ptr<World>& live,
                                               FullWorldFence fence,
                                               std::size_t maximum_snapshot_bytes) {
        if (!live || live->has_failed() || !fence.valid() || maximum_snapshot_bytes == 0)
            throw std::invalid_argument("GEN006_DYNAMIC_STAGE_PRECONDITION");
        const auto tick = live->completed_tick_index();
        const auto hash = live->physical_state_hash();
        auto bytes = live->save_physical_state();
        // The budget is enforced after the existing World serializer returns;
        // this is NOT a preallocation guarantee for serialization scratch.
        if (bytes.empty() || bytes.size() > maximum_snapshot_bytes)
            throw std::length_error("GEN006_DYNAMIC_STAGE_SNAPSHOT_BUDGET");
        auto candidate = World::restore_physical_state(live->config(), bytes);
        if (!candidate || candidate->has_failed() ||
            candidate->completed_tick_index() != tick ||
            candidate->physical_state_hash() != hash ||
            candidate->quantity_ledger() != live->quantity_ledger() ||
            candidate->chunk_count() != live->chunk_count())
            throw std::runtime_error("GEN006_DYNAMIC_STAGE_RESTORE_PARITY");
        return FullWorldContinuationStage(live.get(), fence, tick, hash,
                                          std::move(bytes), std::move(candidate));
    }

    FullWorldContinuationStage(const FullWorldContinuationStage&) = delete;
    FullWorldContinuationStage& operator=(const FullWorldContinuationStage&) = delete;
    FullWorldContinuationStage(FullWorldContinuationStage&&) noexcept = default;
    FullWorldContinuationStage& operator=(FullWorldContinuationStage&&) noexcept = default;

    [[nodiscard]] std::span<const std::uint8_t> bytes() const noexcept { return bytes_; }
    [[nodiscard]] std::uint64_t source_tick() const noexcept { return tick_; }
    [[nodiscard]] std::uint64_t physical_hash() const noexcept { return hash_; }
    [[nodiscard]] FullWorldFence fence() const noexcept { return fence_; }

    // The serialized exclusive owner must prevent concurrent tick/input while
    // this method executes. No live mutation occurs on any refusal. A new
    // World/session incarnation MUST be advanced by the host after a swap.
    [[nodiscard]] FullWorldCommitStatus commit(std::unique_ptr<World>& live,
                                                FullWorldFence current,
                                                std::span<const std::uint8_t> verified_copy) {
        if (!candidate_) return FullWorldCommitStatus::AlreadyCommitted;
        if (!live) return FullWorldCommitStatus::NoLiveOwner;
        if (live.get() != original_) return FullWorldCommitStatus::StaleOwner;
        if (current != fence_ || !current.valid()) return FullWorldCommitStatus::StaleFence;
        if (verified_copy.size() != bytes_.size() ||
            !std::equal(bytes_.begin(), bytes_.end(), verified_copy.begin()))
            return FullWorldCommitStatus::UnverifiedCopy;
        try {
            if (live->has_failed() || live->completed_tick_index() != tick_ ||
                live->physical_state_hash() != hash_ ||
                live->save_physical_state() != bytes_)
                return FullWorldCommitStatus::StaleSource;
        } catch (const std::exception&) {
            return FullWorldCommitStatus::SnapshotFailure;
        }
        // No allocation, throwing validation or partial update after here.
        // The old complete World remains owned by candidate_ until destruction.
        live.swap(candidate_);
        candidate_.reset();
        return FullWorldCommitStatus::Committed;
    }

private:
    FullWorldContinuationStage(const World* original, FullWorldFence fence,
                               std::uint64_t tick, std::uint64_t hash,
                               std::vector<std::uint8_t> bytes,
                               std::unique_ptr<World> candidate)
        : original_(original), fence_(fence), tick_(tick), hash_(hash),
          bytes_(std::move(bytes)), candidate_(std::move(candidate)) {}

    const World* original_;
    FullWorldFence fence_;
    std::uint64_t tick_;
    std::uint64_t hash_;
    std::vector<std::uint8_t> bytes_;
    std::unique_ptr<World> candidate_;
};

} // namespace cybersand::gen006
