#pragma once

// GEN-006 experimental FULL-RESIDENT-SET bundle admission, not selective
// eviction. The unmodified native World remains the physics authority.
// All native scheduler, quantity and activity sidecars are retained through
// a private full-World CYPS restore. No material-only reconstruction.
// The external owner must serialize every tick/input/capture/commit.

#include "cybersand/gen006_dynamic_full_world_stage.hpp"

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <memory>
#include <optional>
#include <span>
#include <stdexcept>
#include <utility>
#include <vector>

namespace cybersand::gen006 {

struct BundleSeam {
    ChunkCoord first;
    ChunkCoord second;
    friend bool operator==(const BundleSeam&, const BundleSeam&) = default;
};

    
// Explicit, canonical, native-owner edit intent inside one attested resident.
// Not a persistence format and not an independently durable edit ACK.
struct BundleMaterialEdit {
    ChunkCoord resident;
    std::int32_t local_x = 0;
    std::int32_t local_y = 0;
    Material material = Material::Empty;
    friend bool operator==(const BundleMaterialEdit&, const BundleMaterialEdit&) = default;
};

enum class BundleAdmissionStatus : std::uint8_t {
    EmptyOrOversizedRoster,
    MissingOrFailedWorld,
    InvalidFence,
    RosterCountMismatch,
    DuplicateChunk,
    InvalidSeam,
    DuplicateSeam,
    UncoveredInternalSeam,
    InvalidCoordinate,
    MissingResident,
    ProbeAlteredAuthority,
    InvalidEditBatch,
    DuplicateEdit,
    EditOutsideResident,
    PrivateMutationFailed,
    EditsAlreadyStaged,
    InvalidTickBatch,
    TicksAlreadyStaged,
    EditsAfterTickBatch,
    PrivateTickFailed,
    PrivateResidentSetExpanded,
    PublicationRequiresTicks,
    PublicationAlreadySealed,
    PublicationSnapshotOversized,
    PublicationSnapshotInvalid,
    InvalidReplayScript,
    ReplayConflictsWithLegacy,
    ReplayAlreadyStaged,
    ReplayPrivateFailed,
};

// Ordered, opt-in cross-resident native command stream. Unlike the legacy
// one-time edit+preview path, this can edit, advance, edit and advance again
// inside ONE private physical World before one fenced publication. Order is
// part of the external verification witness, including re-edits after ticks.
enum class BundleReplayKind : std::uint8_t { MaterialEdit, NativeTicks };
struct BundleReplayStep {
    BundleReplayKind kind = BundleReplayKind::MaterialEdit;
    BundleMaterialEdit edit{};
    std::uint32_t ticks = 0;
    static BundleReplayStep material_edit(BundleMaterialEdit value) {
        return {BundleReplayKind::MaterialEdit, value, 0};
    }
    static BundleReplayStep native_ticks(std::uint32_t count) {
        return {BundleReplayKind::NativeTicks, {}, count};
    }
    friend bool operator==(const BundleReplayStep&, const BundleReplayStep&) = default;
};

struct BundleReplayReceipt {
    std::size_t steps = 0, edits = 0;
    std::uint32_t ticks = 0, observed_workers_max = 0;
    std::uint64_t completed_tick = 0, physical_hash = 0;
    QuantityLedgerSnapshot quantity{};
    std::size_t resident_chunks = 0, resident_cell_bytes = 0;
    friend bool operator==(const BundleReplayReceipt&, const BundleReplayReceipt&) = default;
};

// Native-only, non-durable receipt of actually simulated private ticks.
// The FULL World owns the scheduler, pressure, inertial, ballistic and
// quantity sidecars; this receipt is NOT a replacement for those records.
struct BundleTickReceipt {
    std::uint32_t ticks = 0;
    std::uint32_t observed_workers_max = 0;
    std::uint64_t completed_tick = 0;
    std::uint64_t physical_hash = 0;
    QuantityLedgerSnapshot quantity{};
    std::size_t resident_chunks = 0;
    std::size_t resident_cell_bytes = 0;
    friend bool operator==(const BundleTickReceipt&, const BundleTickReceipt&) = default;
};

// Non-durable complete-World post-execution CYPS readback witness.
struct BundlePublicationReceipt {
    FullWorldFence source_fence{};
    std::uint64_t source_tick = 0, source_physical_hash = 0;
    std::uint64_t completed_tick = 0, physical_hash = 0;
    QuantityLedgerSnapshot quantity{};
    std::size_t resident_chunks = 0, resident_cell_bytes = 0;
    std::size_t snapshot_bytes = 0, edit_count = 0;
    std::uint32_t preview_ticks = 0;
    std::size_t replay_steps = 0;
    friend bool operator==(const BundlePublicationReceipt&,
                           const BundlePublicationReceipt&) = default;
};

class BundleAdmissionError final : public std::runtime_error {
public:
    explicit BundleAdmissionError(BundleAdmissionStatus status)
        : std::runtime_error("GEN006_DYNAMIC_BUNDLE_ADMISSION_REFUSED"), status_(status) {}
    [[nodiscard]] BundleAdmissionStatus status() const noexcept { return status_; }
private:
    BundleAdmissionStatus status_;
};

// This first, conservative bundle interface requires ALL native residents.
// A native-private selective bundle/eviction API remains blocked by #512's
// exclusive protected-source ownership and independently required MAT-AUTH.
class FullResidentBundleStage final {
public:
    static constexpr std::size_t kMaximumResidentChunks = 8;

    static FullResidentBundleStage capture(
            const std::unique_ptr<World>& live,
            FullWorldFence fence,
            std::span<const ChunkCoord> all_residents,
            std::span<const BundleSeam> internal_seams,
            std::size_t maximum_snapshot_bytes) {
        if (!live || live->has_failed())
            throw BundleAdmissionError(BundleAdmissionStatus::MissingOrFailedWorld);
        if (!fence.valid())
            throw BundleAdmissionError(BundleAdmissionStatus::InvalidFence);
        if (all_residents.size() < 2 ||
            all_residents.size() > kMaximumResidentChunks)
            throw BundleAdmissionError(BundleAdmissionStatus::EmptyOrOversizedRoster);
        if (live->chunk_count() != all_residents.size())
            throw BundleAdmissionError(BundleAdmissionStatus::RosterCountMismatch);

        auto roster = std::vector<ChunkCoord>(all_residents.begin(), all_residents.end());
        std::sort(roster.begin(), roster.end());
        if (std::adjacent_find(roster.begin(), roster.end()) != roster.end())
            throw BundleAdmissionError(BundleAdmissionStatus::DuplicateChunk);

        // Sign-correct adjacency, including coordinates close to INT64 limits.
        // Unsigned subtraction cannot trigger signed overflow.
        auto adjacent = [](ChunkCoord a, ChunkCoord b) {
            // Use signed ordering BEFORE unsigned distance: MAX and MIN
            // differ by 2^64-1, not one. A modular +/-1 test would falsely
            // connect them across the signed coordinate seam.
            auto consecutive = [](std::int64_t lhs, std::int64_t rhs) {
                return lhs < rhs
                    ? static_cast<std::uint64_t>(rhs) -
                          static_cast<std::uint64_t>(lhs) == 1U
                    : rhs < lhs &&
                          static_cast<std::uint64_t>(lhs) -
                              static_cast<std::uint64_t>(rhs) == 1U;
            };
            return (a.x == b.x && consecutive(a.y, b.y)) ||
                   (a.y == b.y && consecutive(a.x, b.x));
        };
        auto canonical = [](BundleSeam edge) {
            if (edge.second < edge.first) std::swap(edge.first, edge.second);
            return edge;
        };
        auto edge_less = [](const BundleSeam& a, const BundleSeam& b) {
            return a.first < b.first ||
                   (a.first == b.first && a.second < b.second);
        };
        std::vector<BundleSeam> required;
        for (std::size_t i = 0; i < roster.size(); ++i)
            for (std::size_t j = i + 1; j < roster.size(); ++j)
                if (adjacent(roster[i], roster[j]))
                    required.push_back({roster[i], roster[j]});
        std::sort(required.begin(), required.end(), edge_less);

        std::vector<BundleSeam> supplied;
        supplied.reserve(internal_seams.size());
        for (auto edge : internal_seams) {
            edge = canonical(edge);
            if (!adjacent(edge.first, edge.second) ||
                !std::binary_search(roster.begin(), roster.end(), edge.first) ||
                !std::binary_search(roster.begin(), roster.end(), edge.second))
                throw BundleAdmissionError(BundleAdmissionStatus::InvalidSeam);
            supplied.push_back(edge);
        }
        std::sort(supplied.begin(), supplied.end(), edge_less);
        if (std::adjacent_find(supplied.begin(), supplied.end()) != supplied.end())
            throw BundleAdmissionError(BundleAdmissionStatus::DuplicateSeam);
        if (supplied != required)
            throw BundleAdmissionError(BundleAdmissionStatus::UncoveredInternalSeam);

        // The public World lacks a read-only native-resident enumeration API.
        // Rehydrate a DISPOSABLE native copy and query its authoritative
        // AlreadyResident admission refusal. If a proposed address is missing,
        // the disposable probe may gain a chunk; it is destroyed immediately.
        // The caller's live World and staged commit candidate remain unchanged.
        auto transaction = FullWorldContinuationStage::capture(
            live, fence, maximum_snapshot_bytes);
        auto probe = World::restore_physical_state(live->config(), transaction.bytes());
        if (!probe || probe->has_failed() ||
            probe->chunk_count() != all_residents.size())
            throw BundleAdmissionError(BundleAdmissionStatus::ProbeAlteredAuthority);
        const auto size = live->config().chunk_size;
        if (size <= 0 || size > 256)
            throw BundleAdmissionError(BundleAdmissionStatus::EmptyOrOversizedRoster);
        const auto extent = static_cast<std::size_t>(size);
        const std::vector<Material> empty(extent * extent, Material::Empty);
        for (const auto coord : roster) {
            const auto result = probe->install_generated_chunk(coord, empty);
            if (result == ChunkInstallOutcome::CoordinateOverflow)
                throw BundleAdmissionError(BundleAdmissionStatus::InvalidCoordinate);
            if (result != ChunkInstallOutcome::AlreadyResident)
                throw BundleAdmissionError(BundleAdmissionStatus::MissingResident);
        }
        if (probe->physical_state_hash() != live->physical_state_hash() ||
            probe->completed_tick_index() != live->completed_tick_index() ||
            probe->quantity_ledger() != live->quantity_ledger() ||
            probe->save_physical_state() !=
                std::vector<std::uint8_t>(transaction.bytes().begin(), transaction.bytes().end()))
            throw BundleAdmissionError(BundleAdmissionStatus::ProbeAlteredAuthority);
        return FullResidentBundleStage(std::move(transaction),
                                       std::move(roster), std::move(required), size);
    }

    FullResidentBundleStage(const FullResidentBundleStage&) = delete;
    FullResidentBundleStage& operator=(const FullResidentBundleStage&) = delete;
    FullResidentBundleStage(FullResidentBundleStage&&) noexcept = default;
    FullResidentBundleStage& operator=(FullResidentBundleStage&&) noexcept = default;

    [[nodiscard]] std::span<const std::uint8_t> bytes() const noexcept {
        return transaction_.bytes();
    }
    [[nodiscard]] std::span<const ChunkCoord> residents() const noexcept {
        return residents_;
    }
    [[nodiscard]] std::span<const BundleSeam> internal_seams() const noexcept {
        return seams_;
    }

    // One-shot bounded material input into the PRIVATE native candidate only.
    // Every command is validated before any candidate mutation. No live World
    // edit occurs until the single owner swap. This remains a full-World
    // transaction and requires external storage to persist BASE + EDITS.
    static constexpr std::size_t kMaximumStagedEdits = 64;
    void stage_material_edits(std::span<const BundleMaterialEdit> changes) {
        if (publication_) throw BundleAdmissionError(BundleAdmissionStatus::PublicationAlreadySealed);
        if (replay_receipt_)
            throw BundleAdmissionError(BundleAdmissionStatus::ReplayConflictsWithLegacy);
        if (tick_receipt_)
            throw BundleAdmissionError(BundleAdmissionStatus::EditsAfterTickBatch);
        if (!edits_.empty())
            throw BundleAdmissionError(BundleAdmissionStatus::EditsAlreadyStaged);
        if (changes.empty() || changes.size() > kMaximumStagedEdits)
            throw BundleAdmissionError(BundleAdmissionStatus::InvalidEditBatch);
        const auto size = static_cast<std::int64_t>(chunk_size_);
        if (size <= 0 || size > 256)
            throw BundleAdmissionError(BundleAdmissionStatus::InvalidEditBatch);
        auto ordered = std::vector<BundleMaterialEdit>(changes.begin(), changes.end());
        auto less = [](const BundleMaterialEdit& a, const BundleMaterialEdit& b) {
            if (a.resident != b.resident) return a.resident < b.resident;
            if (a.local_y != b.local_y) return a.local_y < b.local_y;
            return a.local_x < b.local_x;
        };
        std::sort(ordered.begin(), ordered.end(), less);
        for (std::size_t i = 0; i < ordered.size(); ++i) {
            const auto& edit = ordered[i];
            if (!std::binary_search(residents_.begin(), residents_.end(), edit.resident))
                throw BundleAdmissionError(BundleAdmissionStatus::EditOutsideResident);
            if (edit.local_x < 0 || edit.local_y < 0 ||
                edit.local_x >= size || edit.local_y >= size ||
                (edit.material != Material::Empty && edit.material != Material::Wall &&
                 edit.material != Material::Sand && edit.material != Material::Water))
                throw BundleAdmissionError(BundleAdmissionStatus::InvalidEditBatch);
            if (i && edit.resident == ordered[i-1].resident &&
                edit.local_x == ordered[i-1].local_x &&
                edit.local_y == ordered[i-1].local_y)
                throw BundleAdmissionError(BundleAdmissionStatus::DuplicateEdit);
        }
        try {
            // Every resident coordinate was previously preflighted by the
            // canonical native install_generated_chunk() signed-range check.
            transaction_.mutate_private([&](World& candidate) {
                for (const auto& edit : ordered) {
                    const auto x = edit.resident.x * size + edit.local_x;
                    const auto y = edit.resident.y * size + edit.local_y;
                    candidate.set(x, y, edit.material);
                    if (candidate.stored_material(x, y) != edit.material)
                        throw std::runtime_error("GEN006_DYNAMIC_PRIVATE_EDIT_READBACK");
                }
            });
        } catch (const std::exception&) {
            throw BundleAdmissionError(BundleAdmissionStatus::PrivateMutationFailed);
        }
        edits_ = std::move(ordered);
    }

    [[nodiscard]] std::span<const BundleMaterialEdit> staged_edits() const noexcept {
        return edits_;
    }

    // Speculatively advance the REAL privately restored World. This is
    // native physical simulation (not a material-only predictor); all CYPS
    // scheduler and solver sidecars continue in the private owner. The
    // original World does not tick, lose a resident or change its clock.
    // If a native tick discovers an additional chunk, discard the private
    // World: this complete-resident-set contract cannot authorize its halo.
    static constexpr std::uint32_t kMaximumStagedTicks = 16;
    [[nodiscard]] BundleTickReceipt stage_native_ticks(std::uint32_t ticks) {
        if (publication_) throw BundleAdmissionError(BundleAdmissionStatus::PublicationAlreadySealed);
        if (replay_receipt_)
            throw BundleAdmissionError(BundleAdmissionStatus::ReplayConflictsWithLegacy);
        if (tick_receipt_)
            throw BundleAdmissionError(BundleAdmissionStatus::TicksAlreadyStaged);
        if (ticks == 0 || ticks > kMaximumStagedTicks ||
            transaction_.source_tick() >
                std::numeric_limits<std::uint64_t>::max() - ticks)
            throw BundleAdmissionError(BundleAdmissionStatus::InvalidTickBatch);
        BundleTickReceipt receipt{};
        receipt.ticks = ticks;
        try {
            transaction_.mutate_private([&](World& candidate) {
                if (candidate.chunk_count() != residents_.size())
                    throw BundleAdmissionError(BundleAdmissionStatus::PrivateResidentSetExpanded);
                for (std::uint32_t index = 0; index < ticks; ++index) {
                    const auto stats = candidate.tick();
                    receipt.observed_workers_max =
                        std::max(receipt.observed_workers_max, stats.worker_threads_observed);
                    if (candidate.chunk_count() != residents_.size())
                        throw BundleAdmissionError(BundleAdmissionStatus::PrivateResidentSetExpanded);
                    if (candidate.has_failed() ||
                        candidate.completed_tick_index() !=
                            transaction_.source_tick() + index + 1U)
                        throw BundleAdmissionError(BundleAdmissionStatus::PrivateTickFailed);
                }
                receipt.completed_tick = candidate.completed_tick_index();
                receipt.physical_hash = candidate.physical_state_hash();
                receipt.quantity = candidate.quantity_ledger();
                receipt.resident_chunks = candidate.chunk_count();
                receipt.resident_cell_bytes = candidate.resident_cell_bytes();
            });
        } catch (const BundleAdmissionError&) {
            // mutate_private discarded a partially advanced candidate.
            throw;
        } catch (const std::exception&) {
            throw BundleAdmissionError(BundleAdmissionStatus::PrivateTickFailed);
        }
        tick_receipt_ = receipt;
        return receipt;
    }

    [[nodiscard]] const std::optional<BundleTickReceipt>&
    staged_tick_receipt() const noexcept { return tick_receipt_; }

    // Replay a bounded chronological sequence of native edits AND native ticks
    // against the actual private World. All commands are preflighted before
    // the first mutation; a failure consumes the PRIVATE candidate only.
    // Within each tick epoch, a cell may be edited once, but later epochs may
    // edit that same cell again. Native sidecars never leave the full World.
    static constexpr std::size_t kMaximumReplaySteps = 64;
    static constexpr std::size_t kMaximumReplayEdits = 32;
    [[nodiscard]] BundleReplayReceipt stage_replay_script(
            std::span<const BundleReplayStep> input) {
        if (publication_)
            throw BundleAdmissionError(BundleAdmissionStatus::PublicationAlreadySealed);
        if (replay_receipt_)
            throw BundleAdmissionError(BundleAdmissionStatus::ReplayAlreadyStaged);
        if (!edits_.empty() || tick_receipt_)
            throw BundleAdmissionError(BundleAdmissionStatus::ReplayConflictsWithLegacy);
        if (input.size() < 3 || input.size() > kMaximumReplaySteps)
            throw BundleAdmissionError(BundleAdmissionStatus::InvalidReplayScript);
        const auto size = static_cast<std::int64_t>(chunk_size_);
        if (size <= 0 || size > 256)
            throw BundleAdmissionError(BundleAdmissionStatus::InvalidReplayScript);
        std::size_t edit_count = 0;
        std::uint32_t tick_count = 0;
        std::vector<BundleMaterialEdit> epoch_edits;
        for (const auto& step : input) {
            if (step.kind == BundleReplayKind::MaterialEdit) {
                const auto& edit = step.edit;
                if (step.ticks != 0 || ++edit_count > kMaximumReplayEdits ||
                    edit.local_x < 0 || edit.local_y < 0 ||
                    edit.local_x >= size || edit.local_y >= size ||
                    (edit.material != Material::Empty &&
                     edit.material != Material::Wall &&
                     edit.material != Material::Sand &&
                     edit.material != Material::Water))
                    throw BundleAdmissionError(BundleAdmissionStatus::InvalidReplayScript);
                if (!std::binary_search(residents_.begin(), residents_.end(), edit.resident))
                    throw BundleAdmissionError(BundleAdmissionStatus::EditOutsideResident);
                if (std::any_of(epoch_edits.begin(), epoch_edits.end(),
                        [&](const BundleMaterialEdit& previous) {
                            return previous.resident == edit.resident &&
                                   previous.local_x == edit.local_x &&
                                   previous.local_y == edit.local_y;
                        }))
                    throw BundleAdmissionError(BundleAdmissionStatus::DuplicateEdit);
                epoch_edits.push_back(edit);
            } else if (step.kind == BundleReplayKind::NativeTicks) {
                if (step.ticks == 0 ||
                    step.ticks > kMaximumStagedTicks - tick_count ||
                    step.edit != BundleMaterialEdit{})
                    throw BundleAdmissionError(BundleAdmissionStatus::InvalidReplayScript);
                tick_count += step.ticks;
                epoch_edits.clear();
            } else {
                throw BundleAdmissionError(BundleAdmissionStatus::InvalidReplayScript);
            }
        }
        if (!edit_count || !tick_count ||
            transaction_.source_tick() >
                std::numeric_limits<std::uint64_t>::max() - tick_count)
            throw BundleAdmissionError(BundleAdmissionStatus::InvalidReplayScript);

        auto script = std::vector<BundleReplayStep>(input.begin(), input.end());
        BundleReplayReceipt receipt{};
        receipt.steps = script.size();
        receipt.edits = edit_count;
        receipt.ticks = tick_count;
        try {
            transaction_.mutate_private([&](World& candidate) {
                auto expected_tick = transaction_.source_tick();
                for (const auto& step : script) {
                    if (candidate.chunk_count() != residents_.size())
                        throw BundleAdmissionError(BundleAdmissionStatus::PrivateResidentSetExpanded);
                    if (step.kind == BundleReplayKind::MaterialEdit) {
                        const auto& edit = step.edit;
                        const auto x = edit.resident.x * size + edit.local_x;
                        const auto y = edit.resident.y * size + edit.local_y;
                        candidate.set(x, y, edit.material);
                        if (candidate.stored_material(x, y) != edit.material ||
                            candidate.has_failed())
                            throw BundleAdmissionError(BundleAdmissionStatus::ReplayPrivateFailed);
                    } else {
                        for (std::uint32_t i = 0; i < step.ticks; ++i) {
                            const auto stats = candidate.tick();
                            receipt.observed_workers_max = std::max(
                                receipt.observed_workers_max, stats.worker_threads_observed);
                            ++expected_tick;
                            if (candidate.has_failed() ||
                                candidate.completed_tick_index() != expected_tick)
                                throw BundleAdmissionError(BundleAdmissionStatus::ReplayPrivateFailed);
                            if (candidate.chunk_count() != residents_.size())
                                throw BundleAdmissionError(
                                    BundleAdmissionStatus::PrivateResidentSetExpanded);
                        }
                    }
                }
                receipt.completed_tick = candidate.completed_tick_index();
                receipt.physical_hash = candidate.physical_state_hash();
                receipt.quantity = candidate.quantity_ledger();
                receipt.resident_chunks = candidate.chunk_count();
                receipt.resident_cell_bytes = candidate.resident_cell_bytes();
            });
        } catch (const BundleAdmissionError&) {
            throw;
        } catch (const std::exception&) {
            throw BundleAdmissionError(BundleAdmissionStatus::ReplayPrivateFailed);
        }
        script_ = std::move(script);
        replay_receipt_ = receipt;
        return receipt;
    }

    [[nodiscard]] std::span<const BundleReplayStep> replay_script() const noexcept {
        return script_;
    }
    [[nodiscard]] const std::optional<BundleReplayReceipt>&
    replay_receipt() const noexcept { return replay_receipt_; }

    // Snapshot actual post-edit/post-native-tick private authority, then
    // round-trip via a distinct real native World. Cannot prove disk fsync,
    // selective release or a pre-serialization memory-allocation bound.
    [[nodiscard]] BundlePublicationReceipt seal_publication(std::size_t limit) {
        if (publication_)
            throw BundleAdmissionError(BundleAdmissionStatus::PublicationAlreadySealed);
        if (!tick_receipt_ && !replay_receipt_)
            throw BundleAdmissionError(BundleAdmissionStatus::PublicationRequiresTicks);
        const auto expected_tick = replay_receipt_
            ? replay_receipt_->completed_tick : tick_receipt_->completed_tick;
        const auto expected_hash = replay_receipt_
            ? replay_receipt_->physical_hash : tick_receipt_->physical_hash;
        const auto expected_quantity = replay_receipt_
            ? replay_receipt_->quantity : tick_receipt_->quantity;
        const auto expected_bytes = replay_receipt_
            ? replay_receipt_->resident_cell_bytes : tick_receipt_->resident_cell_bytes;
        if (!limit)
            throw BundleAdmissionError(BundleAdmissionStatus::PublicationSnapshotOversized);
        try {
            const auto receipt = transaction_.inspect_private([&](const World& candidate) {
                auto image = candidate.save_physical_state();
                if (image.empty() || image.size() > limit)
                    throw BundleAdmissionError(BundleAdmissionStatus::PublicationSnapshotOversized);
                auto restored = World::restore_physical_state(candidate.config(), image);
                if (!restored || restored->has_failed() ||
                    restored->completed_tick_index() != candidate.completed_tick_index() ||
                    restored->physical_state_hash() != candidate.physical_state_hash() ||
                    restored->quantity_ledger() != candidate.quantity_ledger() ||
                    restored->resident_cell_bytes() != candidate.resident_cell_bytes() ||
                    restored->chunk_count() != residents_.size() ||
                    restored->save_physical_state() != image ||
                    restored->completed_tick_index() != expected_tick ||
                    restored->physical_state_hash() != expected_hash ||
                    restored->quantity_ledger() != expected_quantity ||
                    restored->resident_cell_bytes() != expected_bytes)
                    throw BundleAdmissionError(BundleAdmissionStatus::PublicationSnapshotInvalid);
                BundlePublicationReceipt result{};
                result.source_fence = transaction_.fence();
                result.source_tick = transaction_.source_tick();
                result.source_physical_hash = transaction_.physical_hash();
                result.completed_tick = restored->completed_tick_index();
                result.physical_hash = restored->physical_state_hash();
                result.quantity = restored->quantity_ledger();
                result.resident_chunks = restored->chunk_count();
                result.resident_cell_bytes = restored->resident_cell_bytes();
                result.snapshot_bytes = image.size();
                result.edit_count = replay_receipt_ ? replay_receipt_->edits : edits_.size();
                result.preview_ticks = replay_receipt_ ? replay_receipt_->ticks : tick_receipt_->ticks;
                result.replay_steps = replay_receipt_ ? script_.size() : 0;
                publication_bytes_ = std::move(image);
                return result;
            });
            publication_ = receipt;
            return receipt;
        } catch (const BundleAdmissionError&) {
            throw;
        } catch (const std::exception&) {
            throw BundleAdmissionError(BundleAdmissionStatus::PublicationSnapshotInvalid);
        }
    }
    [[nodiscard]] std::span<const std::uint8_t> publication_bytes() const noexcept {
        return publication_bytes_;
    }
    // Verify source+edits+tick receipts and independently re-read POST bytes.
    // The publication layer, not this in-memory API, must prove durability.
    [[nodiscard]] FullWorldCommitStatus commit_published(
            std::unique_ptr<World>& live, FullWorldFence current,
            std::span<const std::uint8_t> base_copy,
            std::span<const BundleMaterialEdit> edit_copy,
            const BundleTickReceipt& tick_copy,
            std::span<const std::uint8_t> post_copy,
            const BundlePublicationReceipt& post_receipt) {
        if (replay_receipt_ || !publication_ || *publication_ != post_receipt ||
            !tick_receipt_ || *tick_receipt_ != tick_copy ||
            edit_copy.size() != edits_.size() ||
            !std::equal(edits_.begin(), edits_.end(), edit_copy.begin()) ||
            post_copy.size() != publication_bytes_.size() ||
            !std::equal(publication_bytes_.begin(), publication_bytes_.end(), post_copy.begin()))
            return FullWorldCommitStatus::UnverifiedCopy;
        return transaction_.commit(live, current, base_copy);
    }

    // Only this entry point can publish a post-simulation ORDERED replay.
    // The external reader must provide the exact complete chronological
    // command list, receipt and POST-CYPS image. In-memory readback is not fsync.
    [[nodiscard]] FullWorldCommitStatus commit_replay_published(
            std::unique_ptr<World>& live, FullWorldFence current,
            std::span<const std::uint8_t> base_copy,
            std::span<const BundleReplayStep> script_copy,
            const BundleReplayReceipt& replay_copy,
            std::span<const std::uint8_t> post_copy,
            const BundlePublicationReceipt& post_receipt) {
        if (!publication_ || !replay_receipt_ ||
            *publication_ != post_receipt ||
            *replay_receipt_ != replay_copy ||
            script_copy.size() != script_.size() ||
            !std::equal(script_.begin(), script_.end(), script_copy.begin()) ||
            post_copy.size() != publication_bytes_.size() ||
            !std::equal(publication_bytes_.begin(), publication_bytes_.end(), post_copy.begin()))
            return FullWorldCommitStatus::UnverifiedCopy;
        return transaction_.commit(live, current, base_copy);
    }

    // The legacy unedited commit refuses to publish an edited private World
    // without an independently supplied, exact edit-list witness.
    [[nodiscard]] FullWorldCommitStatus commit(
            std::unique_ptr<World>& live, FullWorldFence current,
            std::span<const std::uint8_t> verified_copy) {
        if (!edits_.empty() || tick_receipt_ || replay_receipt_)
            return FullWorldCommitStatus::UnverifiedCopy;
        return transaction_.commit(live, current, verified_copy);
    }
    [[nodiscard]] FullWorldCommitStatus commit(
            std::unique_ptr<World>& live, FullWorldFence current,
            std::span<const std::uint8_t> verified_base_copy,
            std::span<const BundleMaterialEdit> verified_edits) {
        if (tick_receipt_ || replay_receipt_)
            return FullWorldCommitStatus::UnverifiedCopy;
        if (verified_edits.size() != edits_.size() ||
            !std::equal(edits_.begin(), edits_.end(), verified_edits.begin()))
            return FullWorldCommitStatus::UnverifiedCopy;
        return transaction_.commit(live, current, verified_base_copy);
    }

    // An actual private native-tick batch requires BOTH exact canonical
    // input evidence and the independently checked intended tick receipt.
    // No legacy call may publish a speculative future World without them.
    [[nodiscard]] FullWorldCommitStatus commit(
            std::unique_ptr<World>& live, FullWorldFence current,
            std::span<const std::uint8_t> verified_base_copy,
            std::span<const BundleMaterialEdit> verified_edits,
            const BundleTickReceipt& verified_ticks) {
        if (publication_ || replay_receipt_ || !tick_receipt_ ||
            *tick_receipt_ != verified_ticks ||
            verified_edits.size() != edits_.size() ||
            !std::equal(edits_.begin(), edits_.end(), verified_edits.begin()))
            return FullWorldCommitStatus::UnverifiedCopy;
        return transaction_.commit(live, current, verified_base_copy);
    }

private:
    FullResidentBundleStage(FullWorldContinuationStage stage,
                            std::vector<ChunkCoord> roster,
                            std::vector<BundleSeam> seams,
                            std::int32_t chunk_size)
        : transaction_(std::move(stage)), residents_(std::move(roster)),
          seams_(std::move(seams)), chunk_size_(chunk_size) {}

    FullWorldContinuationStage transaction_;
    std::vector<ChunkCoord> residents_;
    std::vector<BundleSeam> seams_;
    std::vector<BundleMaterialEdit> edits_;
    std::vector<BundleReplayStep> script_;
    std::optional<BundleTickReceipt> tick_receipt_;
    std::optional<BundleReplayReceipt> replay_receipt_;
    std::optional<BundlePublicationReceipt> publication_;
    std::vector<std::uint8_t> publication_bytes_;
    std::int32_t chunk_size_ = 0;
};

} // namespace cybersand::gen006
