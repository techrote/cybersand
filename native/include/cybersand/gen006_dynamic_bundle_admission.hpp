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
#include <memory>
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

    // The legacy unedited commit refuses to publish an edited private World
    // without an independently supplied, exact edit-list witness.
    [[nodiscard]] FullWorldCommitStatus commit(
            std::unique_ptr<World>& live, FullWorldFence current,
            std::span<const std::uint8_t> verified_copy) {
        if (!edits_.empty()) return FullWorldCommitStatus::UnverifiedCopy;
        return transaction_.commit(live, current, verified_copy);
    }
    [[nodiscard]] FullWorldCommitStatus commit(
            std::unique_ptr<World>& live, FullWorldFence current,
            std::span<const std::uint8_t> verified_base_copy,
            std::span<const BundleMaterialEdit> verified_edits) {
        if (verified_edits.size() != edits_.size() ||
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
    std::int32_t chunk_size_ = 0;
};

} // namespace cybersand::gen006
