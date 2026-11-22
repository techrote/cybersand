#pragma once

#include "cybersand/object_shard_coordinator.hpp"
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <limits>
#include <memory>
#include <thread>

// OBJECTSHARD-M4-NATIVE-001. Owner-local, opt-in *admission* protocol only.
// This does not attach a second World, perform a World tick, own RIDs, or
// replace ordinary immutable GCR. A real same-World coordinator and composite
// occupancy mask are prerequisites to enabling it in the desktop Workbench.
namespace cybersand::object_shard::m4 {

inline constexpr std::size_t kBodyLimit = 3;
inline constexpr std::uint32_t kSegmentLimit = 16;
inline constexpr std::size_t kShapeLimit = 512;

enum class Verdict : std::uint8_t {
    Accepted, WrongOwner, WrongWorld, Stale, Invalid, Capacity, Busy,
    Fenced, Held, Retired
};
[[nodiscard]] inline const char* verdict_name(Verdict v) noexcept {
    switch (v) {
        case Verdict::Accepted: return "Accepted";
        case Verdict::WrongOwner: return "WrongOwner";
        case Verdict::WrongWorld: return "WrongWorld";
        case Verdict::Stale: return "Stale";
        case Verdict::Invalid: return "Invalid";
        case Verdict::Capacity: return "Capacity";
        case Verdict::Busy: return "Busy";
        case Verdict::Fenced: return "Fenced";
        case Verdict::Held: return "Held";
        case Verdict::Retired: return "Retired";
    }
    return "Invalid";
}

// The first three counters belong to the host's current World/session lease.
// The latter two are observed from the native Coordinator. Never substitute
// transport enqueue sequence for either identity.
struct OwnerIdentity {
    std::uint64_t session{}, epoch{}, world_generation{};
    std::uint64_t shard_session{}, world_incarnation{};
    bool operator==(const OwnerIdentity&) const = default;
};

struct BodyRevision {
    Handle shard{};
    std::uint64_t body_generation{}, geometry_revision{}, material_revision{};
    std::uint64_t pose_serial{}, mask_digest{}, shape_digest{};
    std::uint32_t shape_count{}, structural{}, product{}, cargo{};
    double mass{}, com_x{}, com_y{}, inertia{};
    bool operator==(const BodyRevision&) const = default;
};

struct GeometryTicket {
    OwnerIdentity owner{};
    BodyRevision body{};
    std::uint64_t sequence{}, completed_tick{};
    bool operator==(const GeometryTicket&) const = default;
};

// One ticket covers the *entire* active body roster, not just one body:
// Coordinator::accept_motion requires a complete pose inventory.
struct MotionTicket {
    OwnerIdentity owner{};
    std::uint64_t completed_tick{}, sequence{};
    std::uint32_t count{};
    std::array<BodyRevision, kBodyLimit> bodies{};
    bool operator==(const MotionTicket&) const = default;
};

class MutableBodyGate final {
public:
    // The World is passed again on every operation. The saved address is used
    // ONLY for equality, never dereferenced, even after owner replacement.
    // Both references must be live at entry; no operation accepts a raw pointer
    // or makes a borrowed World outlive its authoritative native owner.
    MutableBodyGate(World& world, Coordinator& coordinator, OwnerIdentity owner)
        : identity_(owner), world_address_(std::addressof(world)),
          owner_thread_(std::this_thread::get_id()) {
        if (!coordinator.world_available()) return;
        const auto& snapshot = coordinator.m4_owner_readback();
        valid_ = owner.session != 0 && owner.epoch != 0 &&
            owner.world_generation != 0 && owner.shard_session != 0 &&
            owner.world_incarnation != 0 &&
            snapshot.session == owner.shard_session &&
            snapshot.world_incarnation == owner.world_incarnation &&
            std::addressof(coordinator.world()) == world_address_ &&
            !world.has_failed() && !world.is_tick_in_progress();
        baseline_tick_ = world.completed_tick_index();
    }

    MutableBodyGate(const MutableBodyGate&) = delete;
    MutableBodyGate& operator=(const MutableBodyGate&) = delete;
    MutableBodyGate(MutableBodyGate&&) = delete;
    MutableBodyGate& operator=(MutableBodyGate&&) = delete;

    [[nodiscard]] bool initially_bound() const noexcept {
        return on_owner_thread() && valid_;
    }
    [[nodiscard]] std::size_t registered_bodies() const noexcept {
        // Even diagnostics must not race with an exclusive owner mutation.
        if (!on_owner_thread()) return 0;
        std::size_t count = 0;
        for (const auto& slot : slots_) if (slot.used) ++count;
        return count;
    }
    [[nodiscard]] bool motion_outstanding() const noexcept {
        return on_owner_thread() && awaiting_motion_;
    }

    // A new version must be explicitly proposed and installed. Native-owned
    // material remains exclusively in Registry; this ticket owns no cells.
    Verdict stage_geometry(World& world, Coordinator& coordinator, OwnerIdentity owner,
                           Handle handle, GeometryTicket& out) {
        const auto check = verify(world, coordinator, owner);
        if (check != Verdict::Accepted) return check;
        if (awaiting_motion_) return Verdict::Held;
        const auto& snap = coordinator.m4_owner_readback();
        if (snap.quarantined || snap.promotion_pending) return Verdict::Fenced;
        const auto* shard = coordinator.registry().find(handle);
        const BodyView* body = view(snap, handle);
        if (!body && snap.truncated) return Verdict::Capacity;
        if (!shard || !body || !body->has_body || !shard->owns_inventory() ||
            shard->phase() != Phase::Active) return Verdict::Fenced;
        const auto candidate = revision(*shard, *body);
        if (!credible(candidate, coordinator.config().limits.max_shapes)) return Verdict::Capacity;

        Slot* slot = locate(handle);
        if (!slot) {
            for (auto& candidate_slot : slots_)
                if (!candidate_slot.used) { slot = &candidate_slot; break; }
            if (!slot) return Verdict::Capacity;
        } else {
            if (!slot->ready) return Verdict::Held; // Never replace an unacknowledged install.
            if (candidate == slot->revision) return Verdict::Busy;
            if (candidate.geometry_revision < slot->revision.geometry_revision ||
                candidate.material_revision < slot->revision.material_revision ||
                (candidate.geometry_revision == slot->revision.geometry_revision &&
                 candidate.material_revision == slot->revision.material_revision) ||
                candidate.pose_serial < slot->revision.pose_serial) return Verdict::Stale;
            // State-only material changes may increment material revision with
            // unchanged collider geometry: they still require a fresh ticket.
            // But changed mass/COM/inertia/shape with an unchanged geometry
            // revision could be smuggled past the installed-geometry witness.
            if (candidate.geometry_revision == slot->revision.geometry_revision &&
                (candidate.shape_count != slot->revision.shape_count ||
                 candidate.mask_digest != slot->revision.mask_digest ||
                 candidate.shape_digest != slot->revision.shape_digest ||
                 candidate.mass != slot->revision.mass ||
                 candidate.com_x != slot->revision.com_x ||
                 candidate.com_y != slot->revision.com_y ||
                 candidate.inertia != slot->revision.inertia)) return Verdict::Stale;
        }
        if (next_sequence_ == std::numeric_limits<std::uint64_t>::max())
            return Verdict::Capacity;
        const GeometryTicket ticket{identity_, candidate, ++next_sequence_,
                                    world.completed_tick_index()};
        slot->used = true;
        slot->ready = false;
        slot->revision = candidate;
        slot->ticket = ticket;
        // A post-tick authoring change voids the former physical-time permit.
        // It cannot be re-granted for the same semantic tick.
        permit_armed_ = false;
        out = ticket;
        return Verdict::Accepted;
    }

    // Requires *both* the exact external installation ticket and the current
    // native-applied geometry revision. A queued or fabricated acknowledgement
    // cannot turn geometry_pending into physically usable authority.
    Verdict acknowledge_geometry(World& world, Coordinator& coordinator, OwnerIdentity owner,
                                 const GeometryTicket& ticket) {
        const auto check = verify(world, coordinator, owner);
        if (check != Verdict::Accepted) return check;
        Slot* slot = locate(ticket.body.shard);
        if (!slot || slot->ready || ticket != slot->ticket || awaiting_motion_)
            return Verdict::Stale;
        const auto& snap = coordinator.m4_owner_readback();
        const auto* shard = coordinator.registry().find(ticket.body.shard);
        const BodyView* body = view(snap, ticket.body.shard);
        if (!shard || !body || !body->has_body || !shard->owns_inventory() ||
            shard->phase() != Phase::Active || body->geometry_pending)
            return Verdict::Fenced;
        if (ticket.completed_tick != world.completed_tick_index() ||
            revision(*shard, *body) != ticket.body ||
            shard->applied_physics_revision() != ticket.body.geometry_revision ||
            body->pose.geometry_revision != ticket.body.geometry_revision)
            return Verdict::Stale;
        slot->ready = true;
        return Verdict::Accepted;
    }

    // Called only by the exclusive native owner *after* the one established
    // CyberSimulationWorker semantic tick successfully completes. The gate
    // never advances World and never grants time from an enqueue receipt.
    Verdict grant_completed_tick(World& world, Coordinator& coordinator,
                                 OwnerIdentity owner, std::uint64_t tick) {
        const auto check = verify(world, coordinator, owner);
        if (check != Verdict::Accepted) return check;
        if (awaiting_motion_) return Verdict::Held;
        if (!tick || tick <= baseline_tick_ || tick <= permitted_tick_ ||
            tick != world.completed_tick_index()) return Verdict::Stale;
        const auto& snapshot = coordinator.m4_owner_readback();
        if (snapshot.tick != tick || snapshot.quarantined) return Verdict::Fenced;
        // Native semantic-step pose application is not a Rapier substep.
        // Refresh only serials proven by the *one* completed World tick.
        // Reject all geometry/material/body changes before changing any slot.
        for (const auto& slot : slots_) if (slot.used && slot.ready) {
            const auto* shard = coordinator.registry().find(slot.revision.shard);
            const BodyView* body = view(snapshot, slot.revision.shard);
            if (!shard || !body || !body->has_body || body->geometry_pending)
                return Verdict::Fenced;
            auto current = revision(*shard, *body);
            const auto serial = current.pose_serial;
            current.pose_serial = slot.revision.pose_serial;
            if (!(current == slot.revision) || serial < slot.revision.pose_serial)
                return Verdict::Fenced;
        }
        for (auto& slot : slots_) if (slot.used && slot.ready) {
            const BodyView* body = view(snapshot, slot.revision.shard);
            slot.revision.pose_serial = body->pose.pose_serial;
        }
        permitted_tick_ = tick;
        permit_armed_ = true;
        segments_ = 0;
        return Verdict::Accepted;
    }

    // Only a full, current, installed body roster may start ONE physical
    // substep. The caller still must perform the genuine main-thread Rapier
    // action; this ticket alone is not an applied-pose acknowledgement.
    Verdict issue_motion(World& world, Coordinator& coordinator, OwnerIdentity owner,
                         MotionTicket& out) {
        const auto check = verify(world, coordinator, owner);
        if (check != Verdict::Accepted) return check;
        if (awaiting_motion_) return Verdict::Held;
        if (!permit_armed_ || !permitted_tick_ ||
            world.completed_tick_index() != permitted_tick_ ||
            coordinator.paused() || coordinator.m4_owner_readback().quarantined)
            return Verdict::Fenced;
        const auto& snapshot = coordinator.m4_owner_readback();
        std::size_t actual = 0;
        for (const auto& b : snapshot.bodies) if (b.has_body) {
            ++actual;
            const Slot* s = locate(b.shard);
            const auto* shard = coordinator.registry().find(b.shard);
            if (!s || !s->ready || !shard || !shard->owns_inventory() ||
                shard->phase() != Phase::Active || b.geometry_pending ||
                shard->applied_physics_revision() != s->revision.geometry_revision ||
                revision(*shard, b) != s->revision) return Verdict::Fenced;
        }
        if (!actual || actual != registered_bodies() || actual > kBodyLimit ||
            actual != snapshot.active_count || snapshot.truncated)
            return Verdict::Capacity;
        // Report mutated native material/geometry before ordinary quota
        // exhaustion. A stale body remains fenced regardless of headroom.
        if (segments_ >= kSegmentLimit ||
            next_sequence_ == std::numeric_limits<std::uint64_t>::max())
            return Verdict::Capacity;
        MotionTicket candidate{};
        candidate.owner = identity_;
        candidate.completed_tick = permitted_tick_;
        candidate.sequence = next_sequence_ + 1;
        for (const auto& s : slots_) if (s.used)
            candidate.bodies[candidate.count++] = s.revision;
        issued_ = candidate;
        awaiting_motion_ = true;
        ++next_sequence_;
        ++segments_;
        out = candidate;
        return Verdict::Accepted;
    }

    // The actual Coordinator::accept_motion(full_pose_roster) must already have
    // succeeded and updated EVERY body's authoritative pose serial. Rejection,
    // duplicates, stale geometry or a changed World tick retain the fence.
    Verdict accept_applied_motion(World& world, Coordinator& coordinator, OwnerIdentity owner,
                                  const MotionTicket& ticket) {
        const auto check = verify(world, coordinator, owner);
        if (check != Verdict::Accepted) return check;
        if (!awaiting_motion_ || !(ticket == issued_) ||
            ticket.completed_tick != world.completed_tick_index())
            return Verdict::Stale;
        const auto& snapshot = coordinator.m4_owner_readback();
        if (snapshot.quarantined || coordinator.paused()) return Verdict::Fenced;
        std::array<BodyRevision, kBodyLimit> latest{};
        for (std::uint32_t i = 0; i < ticket.count; ++i) {
            const auto& former = ticket.bodies[i];
            const auto* shard = coordinator.registry().find(former.shard);
            const BodyView* body = view(snapshot, former.shard);
            if (!shard || !body || !body->has_body || body->geometry_pending ||
                shard->phase() != Phase::Active ||
                shard->applied_physics_revision() != former.geometry_revision)
                return Verdict::Fenced;
            latest[i] = revision(*shard, *body);
            auto no_new_pose = latest[i];
            no_new_pose.pose_serial = former.pose_serial;
            if (!(no_new_pose == former) || latest[i].pose_serial <= former.pose_serial)
                return Verdict::Stale;
        }
        for (std::uint32_t i = 0; i < ticket.count; ++i) {
            Slot* slot = locate(ticket.bodies[i].shard);
            if (!slot || !slot->ready) return Verdict::Fenced;
            slot->revision = latest[i];
        }
        awaiting_motion_ = false;
        issued_ = {};
        return Verdict::Accepted;
    }

    // Explicit release only when NO material remains in the native registry.
    // A draining product-only shard is still owned material and blocks release.
    Verdict release_when_empty(World& world, Coordinator& coordinator, OwnerIdentity owner) {
        const auto check = verify(world, coordinator, owner);
        if (check != Verdict::Accepted) return check;
        if (awaiting_motion_) return Verdict::Held;
        for (const auto& shard : coordinator.registry().shards())
            if (shard.owns_inventory()) return Verdict::Held;
        // Native body retirement acknowledgement must precede release; the
        // absence of material alone is not proof of RID/collider disposal.
        if (coordinator.m4_owner_readback().active_count != 0) return Verdict::Held;
        slots_ = {};
        valid_ = false;
        world_address_ = nullptr;
        return Verdict::Accepted;
    }

private:
    struct Slot {
        bool used{}, ready{};
        BodyRevision revision{};
        GeometryTicket ticket{};
    };

    OwnerIdentity identity_{};
    const World* world_address_{};
    std::thread::id owner_thread_{};
    std::array<Slot, kBodyLimit> slots_{};
    MotionTicket issued_{};
    std::uint64_t next_sequence_{}, permitted_tick_{}, baseline_tick_{};
    std::uint32_t segments_{};
    bool valid_{}, awaiting_motion_{}, permit_armed_{};

    [[nodiscard]] bool on_owner_thread() const noexcept {
        return owner_thread_ == std::this_thread::get_id();
    }
    [[nodiscard]] Verdict verify(World& world, Coordinator& coordinator,
                                 OwnerIdentity owner) const {
        // Thread check must precede ANY native World/coordinator observation.
        if (!on_owner_thread()) return Verdict::WrongOwner;
        if (!valid_) return Verdict::Retired;
        if (!coordinator.world_available()) return Verdict::WrongWorld;
        if (owner != identity_ || std::addressof(world) != world_address_ ||
            std::addressof(coordinator.world()) != world_address_)
            return Verdict::WrongWorld;
        if (world.has_failed() || world.is_tick_in_progress())
            return Verdict::Fenced;
        const auto& snap = coordinator.m4_owner_readback();
        if (snap.session != identity_.shard_session ||
            snap.world_incarnation != identity_.world_incarnation)
            return Verdict::WrongWorld;
        return Verdict::Accepted;
    }
    [[nodiscard]] static const BodyView* view(const OwnerReadback& snap, Handle h) {
        for (const auto& body : snap.bodies) if (body.shard == h) return &body;
        return nullptr;
    }
    [[nodiscard]] Slot* locate(Handle h) noexcept {
        for (auto& slot : slots_) if (slot.used && slot.revision.shard == h) return &slot;
        return nullptr;
    }
    [[nodiscard]] const Slot* locate(Handle h) const noexcept {
        for (const auto& slot : slots_) if (slot.used && slot.revision.shard == h) return &slot;
        return nullptr;
    }
    [[nodiscard]] static BodyRevision revision(const Shard& shard, const BodyView& body) {
        const auto& geometry = shard.geometry();
        const auto counts = shard.counts();
        return {shard.handle(), body.body_generation, geometry.revision, shard.material_revision(),
                body.pose.pose_serial, geometry.mask_digest, geometry.shape_digest,
                static_cast<std::uint32_t>(geometry.shapes.size()), counts.structural,
                counts.products, counts.cargo, geometry.mass.mass, geometry.mass.com_x,
                geometry.mass.com_y, geometry.mass.inertia};
    }
    [[nodiscard]] static bool credible(const BodyRevision& rev, std::uint32_t native_shape_limit) {
        return rev.shard.session != 0 && rev.shard.id != 0 && rev.body_generation != 0 &&
            rev.geometry_revision != 0 && rev.material_revision != 0 &&
            rev.shape_count != 0 && rev.shape_count <= kShapeLimit &&
            rev.shape_count <= native_shape_limit && rev.structural != 0 &&
            std::isfinite(rev.mass) && rev.mass > 0 &&
            std::isfinite(rev.inertia) && rev.inertia >= 0 &&
            std::isfinite(rev.com_x) && std::isfinite(rev.com_y);
    }
};

} // namespace cybersand::object_shard::m4
