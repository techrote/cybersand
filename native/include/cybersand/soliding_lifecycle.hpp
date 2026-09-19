#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <span>

// Executable Stage 2 contract model only. This header is not connected to World,
// Godot, Rapier, runtime queues, payload storage, rendering, or level saves.
namespace cybersand::soliding::model {

enum class Representation : std::uint8_t {
    ActiveCells, SleepingCells, SettledSummary, StationaryCells,
    StationaryPayload, DynamicAggregate
};
enum class Owner : std::uint8_t { Cells, StationaryStore, AggregateStore };
enum class Phase : std::uint8_t { Stable, Prepared, Acknowledged, Committed, Quarantine };
enum class Outcome : std::uint8_t {
    Accepted, Stale, Invalid, Capacity, Exhausted, Ineligible, Refused, Quarantined
};
enum class MaterialClass : std::uint8_t {
    Unclassified, IntrinsicCohesive, LooseGranular, StatefulGranular, Reactive, Mixed
};
enum class Invalidation : std::uint8_t {
    Edit, Reaction, Heat, BodyContact, Support, Topology, Activity, PendingEvent,
    Exclusion, ObservationGap
};

struct Handle {
    std::uint64_t incarnation{};
    std::uint32_t slot{};
    std::uint64_t generation{};
    bool operator==(const Handle&) const = default;
};
struct Token {
    Handle handle{};
    std::uint64_t sequence{};
    std::uint64_t revision{};
    Representation target{Representation::ActiveCells};
    bool operator==(const Token&) const = default;
};
// Identity is a synthetic globally unique membership key, not a world coordinate.
// State width is the public native value width; this does not repack Current Cell.
struct Member {
    std::uint64_t identity{};
    std::uint8_t material{};
    std::uint16_t state_a{};
    std::uint8_t state_b{};
    std::int16_t temperature{};
    bool operator==(const Member&) const = default;
};
struct Eligibility {
    MaterialClass material_class{MaterialClass::Unclassified};
    bool stable_witness{};
    bool boundary_preserved{};
    bool prompt_local_invalidation{};
    bool cohesion_policy_authorized{};
    bool geometry_admitted{};
    bool mass_units_and_motion_admitted{};

    [[nodiscard]] bool summary() const noexcept { return stable_witness; }
    [[nodiscard]] bool stationary() const noexcept {
        return summary() && boundary_preserved && prompt_local_invalidation;
    }
    [[nodiscard]] bool dynamic() const noexcept {
        return stationary() && material_class == MaterialClass::IntrinsicCohesive &&
               cohesion_policy_authorized && geometry_admitted && mass_units_and_motion_admitted;
    }
};
// Values are evidence supplied by a future exclusive runtime owner. Boolean
// assertions in this model cannot establish actual queue/resource reservations.
struct Preflight {
    bool healthy{};
    bool included_with_halo{};
    bool exclusive_fence{};
    bool complete_membership{};
    bool payload_reserved{};
    bool shape_reserved{};
    bool body_reserved{};
    bool acknowledgement_reserved{};
    bool result_reserved{};
    bool destinations_reserved{};
    bool topology_current{};
    bool no_pending_events{};
    bool safe_motion_return{};
    [[nodiscard]] bool complete() const noexcept {
        return healthy && included_with_halo && exclusive_fence && complete_membership &&
               payload_reserved && shape_reserved && body_reserved && acknowledgement_reserved &&
               result_reserved && destinations_reserved && topology_current && no_pending_events;
    }
};
struct Topology {
    bool healthy{};
    bool included_with_halo{};
    bool no_pending_events{};
    bool exclusive_fence{};
    bool target_collision_ready{};
    bool old_collision_retired{};
    bool occupancy_complete{};
    bool immutable_publication_ready{};
    [[nodiscard]] bool complete() const noexcept {
        return healthy && included_with_halo && no_pending_events && exclusive_fence &&
               target_collision_ready && old_collision_retired &&
               occupancy_complete && immutable_publication_ready;
    }
};
struct Accounting {
    std::size_t cells{};
    std::size_t stationary_store{};
    std::size_t aggregate_store{};
    [[nodiscard]] std::size_t total() const noexcept { return cells + stationary_store + aggregate_store; }
};
[[nodiscard]] constexpr Owner owner_of(Representation representation) noexcept {
    if (representation == Representation::DynamicAggregate) return Owner::AggregateStore;
    if (representation == Representation::StationaryPayload) return Owner::StationaryStore;
    return Owner::Cells;
}

// All storage and loop bounds are compile-time finite. These are model bounds,
// not selected production capacities or claims about future amortized cost.
template<std::size_t Slots, std::size_t MembersPerSlot, std::size_t PendingCapacity,
         std::uint64_t GenerationLimit = std::numeric_limits<std::uint64_t>::max(),
         std::uint64_t SequenceLimit = std::numeric_limits<std::uint64_t>::max(),
         std::uint64_t RevisionLimit = std::numeric_limits<std::uint64_t>::max()>
class Registry {
    static_assert(Slots > 0 && Slots <= std::numeric_limits<std::uint32_t>::max());
    static_assert(MembersPerSlot > 0 && PendingCapacity > 0);
    static_assert(GenerationLimit > 0 && SequenceLimit > 0 && RevisionLimit > 0);
public:
    struct Snapshot {
        Handle handle{};
        Representation representation{Representation::ActiveCells};
        Owner owner{Owner::Cells};
        Phase phase{Phase::Stable};
        std::uint64_t revision{1};
        std::uint64_t quiet_observations{};
        bool excluded{};
        bool revision_exhausted{};
        std::size_t count{};
        std::array<Member, MembersPerSlot> members{};
        [[nodiscard]] bool publishable() const noexcept { return phase == Phase::Stable; }
        [[nodiscard]] bool cell_save_admissible() const noexcept {
            return phase == Phase::Stable && owner == Owner::Cells && !excluded;
        }
    };

    // Runtime incarnation allocation and durable world identity remain Planned.
    // Caller must supply a unique nonzero incarnation; zero refuses all creation.
    explicit Registry(std::uint64_t incarnation) noexcept : incarnation_(incarnation) {}
    Registry(const Registry&) = delete;
    Registry& operator=(const Registry&) = delete;
    Registry(Registry&&) = delete;
    Registry& operator=(Registry&&) = delete;

    Outcome create(std::span<const Member> members, Handle& output) noexcept {
        if (incarnation_ == 0 || members.empty()) return Outcome::Invalid;
        if (members.size() > MembersPerSlot) return Outcome::Capacity;
        for (std::size_t i = 0; i < members.size(); ++i) {
            if (members[i].identity == 0 || members[i].material == 0) return Outcome::Invalid;
            for (std::size_t j = 0; j < i; ++j)
                if (members[i].identity == members[j].identity) return Outcome::Invalid;
            for (const auto& slot : slots_) if (slot.used)
                for (std::size_t j = 0; j < slot.value.count; ++j)
                    if (members[i].identity == slot.value.members[j].identity) return Outcome::Invalid;
        }
        bool exhausted = false;
        for (std::size_t i = 0; i < Slots; ++i) {
            auto& slot = slots_[i];
            if (slot.used) continue;
            if (slot.generation == GenerationLimit) { exhausted = true; continue; }
            ++slot.generation;
            slot.used = true;
            slot.value = Snapshot{};
            slot.value.handle = {incarnation_, static_cast<std::uint32_t>(i), slot.generation};
            slot.value.count = members.size();
            for (std::size_t j = 0; j < members.size(); ++j) slot.value.members[j] = members[j];
            output = slot.value.handle;
            return Outcome::Accepted;
        }
        return exhausted ? Outcome::Exhausted : Outcome::Capacity;
    }

    // Retires tracking only; payload must already belong to cells. This operation
    // cannot destroy aggregate-owned material or cancel an in-flight transaction.
    Outcome untrack(Handle handle) noexcept {
        auto* slot = find(handle);
        if (!slot) return Outcome::Stale;
        if (slot->value.phase != Phase::Stable || slot->value.owner != Owner::Cells)
            return Outcome::Refused;
        slot->used = false;
        return Outcome::Accepted;
    }

    [[nodiscard]] bool snapshot(Handle handle, Snapshot& output) const noexcept {
        const auto* slot = find(handle);
        if (!slot) return false;
        output = slot->value; // Value copy: never a borrow of mutable model storage.
        return true;
    }

    Outcome prepare(Handle handle, Representation target, std::uint64_t expected_revision,
                    const Eligibility& eligibility, const Preflight& guards, Token& output) noexcept {
        auto* slot = find(handle);
        if (!slot) return Outcome::Stale;
        auto& value = slot->value;
        if (value.phase == Phase::Quarantine) return Outcome::Quarantined;
        if (value.phase != Phase::Stable || value.representation == target) return Outcome::Refused;
        if (expected_revision != value.revision) return Outcome::Stale;
        if (value.revision_exhausted) return Outcome::Exhausted;
        if (value.excluded || !guards.complete()) return Outcome::Refused;
        if (!eligible(target, eligibility)) return Outcome::Ineligible;
        if (value.representation == Representation::DynamicAggregate && !guards.safe_motion_return)
            return Outcome::Refused;
        if (pending_ == PendingCapacity) return Outcome::Capacity;
        if (sequence_ == SequenceLimit) return Outcome::Exhausted;
        slot->token = {handle, ++sequence_, value.revision, target};
        value.phase = Phase::Prepared;
        ++pending_;
        output = slot->token;
        return Outcome::Accepted;
    }

    Outcome acknowledge(const Token& token, const Preflight& guards) noexcept {
        auto* slot = matching(token, Phase::Prepared);
        if (!slot) return Outcome::Stale;
        if (!guards.complete() || slot->value.excluded) return Outcome::Refused;
        if (slot->value.representation == Representation::DynamicAggregate && !guards.safe_motion_return)
            return Outcome::Refused;
        slot->value.phase = Phase::Acknowledged;
        return Outcome::Accepted;
    }

    Outcome commit(const Token& token, const Preflight& guards) noexcept {
        auto* slot = matching(token, Phase::Acknowledged);
        if (!slot) return Outcome::Stale;
        if (!guards.complete() || slot->value.excluded) return Outcome::Refused;
        if (slot->value.representation == Representation::DynamicAggregate && !guards.safe_motion_return)
            return Outcome::Refused;
        // One logical owner switch. No live world write or cross-thread atomicity
        // is claimed: the only payload here is the synthetic immutable tuple list.
        slot->value.representation = token.target;
        slot->value.owner = owner_of(token.target);
        slot->value.phase = Phase::Committed;
        return Outcome::Accepted;
    }

    Outcome finalize(const Token& token, const Topology& topology) noexcept {
        auto* slot = matching(token, Phase::Committed);
        if (!slot) return Outcome::Stale;
        if (!topology.complete()) {
            slot->value.phase = Phase::Quarantine;
            return Outcome::Quarantined; // Reservation and committed owner retained.
        }
        slot->value.phase = Phase::Stable;
        --pending_;
        return Outcome::Accepted;
    }

    Outcome cancel(const Token& token) noexcept {
        auto* slot = find(token.handle);
        if (!slot || slot->token != token) return Outcome::Stale;
        if (slot->value.phase != Phase::Prepared && slot->value.phase != Phase::Acknowledged)
            return Outcome::Refused;
        slot->value.phase = Phase::Stable;
        --pending_;
        return Outcome::Accepted;
    }

    Outcome invalidate(Handle handle, Invalidation reason) noexcept {
        auto* slot = find(handle);
        if (!slot) return Outcome::Stale;
        auto& value = slot->value;
        value.quiet_observations = 0;
        slot->last_invalidation = reason;
        if (value.phase == Phase::Quarantine) return Outcome::Quarantined;
        if (value.phase == Phase::Committed) {
            value.phase = Phase::Quarantine;
            return Outcome::Quarantined;
        }
        if (value.phase == Phase::Prepared || value.phase == Phase::Acknowledged) {
            value.phase = Phase::Stable;
            --pending_;
        }
        if (value.revision == RevisionLimit) value.revision_exhausted = true;
        else ++value.revision;
        // Cells remain present, so invalidated derived stationary/summary state
        // can drop to active cells. Stored payload cannot silently dissolve.
        if (value.owner == Owner::Cells) value.representation = Representation::ActiveCells;
        return value.revision_exhausted ? Outcome::Exhausted : Outcome::Accepted;
    }

    Outcome observe(Handle handle, bool included, bool healthy, bool contiguous_quiet) noexcept {
        auto* slot = find(handle);
        if (!slot) return Outcome::Stale;
        if (!healthy) {
            slot->value.quiet_observations = 0;
            slot->value.phase = Phase::Quarantine;
            return Outcome::Quarantined;
        }
        if (slot->value.phase == Phase::Quarantine) return Outcome::Quarantined;
        if (!included || slot->value.excluded || !contiguous_quiet) {
            const auto result = invalidate(handle, !included ? Invalidation::Exclusion : Invalidation::ObservationGap);
            slot->value.excluded = !included;
            return result;
        }
        if (slot->value.phase != Phase::Stable) return Outcome::Refused;
        if (slot->value.revision_exhausted) return Outcome::Exhausted;
        if (slot->value.quiet_observations != std::numeric_limits<std::uint64_t>::max())
            ++slot->value.quiet_observations; // Saturation cannot create a fresh identity.
        return Outcome::Accepted;
    }

    [[nodiscard]] Accounting accounting() const noexcept {
        Accounting result;
        for (const auto& slot : slots_) if (slot.used) {
            switch (slot.value.owner) {
            case Owner::Cells: result.cells += slot.value.count; break;
            case Owner::StationaryStore: result.stationary_store += slot.value.count; break;
            case Owner::AggregateStore: result.aggregate_store += slot.value.count; break;
            }
        }
        return result;
    }
    [[nodiscard]] std::size_t pending() const noexcept { return pending_; }

private:
    struct Slot {
        bool used{};
        std::uint64_t generation{};
        Snapshot value{};
        Token token{};
        Invalidation last_invalidation{Invalidation::Activity};
    };
    static bool eligible(Representation target, const Eligibility& e) noexcept {
        switch (target) {
        case Representation::ActiveCells: case Representation::SleepingCells: return true;
        case Representation::SettledSummary: return e.summary();
        case Representation::StationaryCells: case Representation::StationaryPayload: return e.stationary();
        case Representation::DynamicAggregate: return e.dynamic();
        }
        return false;
    }
    Slot* find(Handle handle) noexcept {
        if (handle.incarnation != incarnation_ || handle.slot >= Slots) return nullptr;
        auto& slot = slots_[handle.slot];
        return slot.used && slot.generation == handle.generation ? &slot : nullptr;
    }
    const Slot* find(Handle handle) const noexcept {
        if (handle.incarnation != incarnation_ || handle.slot >= Slots) return nullptr;
        const auto& slot = slots_[handle.slot];
        return slot.used && slot.generation == handle.generation ? &slot : nullptr;
    }
    Slot* matching(const Token& token, Phase phase) noexcept {
        auto* slot = find(token.handle);
        return slot && slot->token == token && slot->value.phase == phase &&
               slot->value.revision == token.revision && !slot->value.revision_exhausted ? slot : nullptr;
    }
    std::uint64_t incarnation_{};
    std::uint64_t sequence_{};
    std::size_t pending_{};
    std::array<Slot, Slots> slots_{};
};
} // namespace cybersand::soliding::model
