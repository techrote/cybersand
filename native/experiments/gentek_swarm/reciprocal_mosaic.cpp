#include "reciprocal_mosaic.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <set>
#include <tuple>

namespace cybersand::gentek_swarm::assembly004 {
namespace {
constexpr std::uint64_t generator_ceiling = 2'000'000;
constexpr std::uint64_t solver_ceiling = 4'000'000;
constexpr std::size_t memory_ceiling = 16U * 1024U * 1024U;

bool cancellation_requested(const MosaicBudget& budget) noexcept {
    return budget.cancelled && budget.cancelled->load(std::memory_order_relaxed);
}

MosaicRevisionStatus revision_status(Status status) noexcept {
    switch (status) {
    case Status::Complete: return MosaicRevisionStatus::Complete;
    case Status::Blocked: case Status::Damaged: return MosaicRevisionStatus::Blocked;
    case Status::Exhausted: return MosaicRevisionStatus::Exhausted;
    case Status::Unsat: return MosaicRevisionStatus::Unsat;
    case Status::Invalid: return MosaicRevisionStatus::Invalid;
    }
    return MosaicRevisionStatus::Invalid;
}

bool valid_material(Material value) noexcept {
    return static_cast<unsigned>(value) <= 131U && static_cast<unsigned>(value) != 10U;
}

std::uint64_t material_digest(int width, int height, const std::vector<Material>& cells) noexcept {
    // Same material-only FNV receipt as the donor, recomputed from the immutable
    // arrays instead of trusting a caller's possibly stale cached digest.
    std::uint64_t digest = UINT64_C(14695981039346656037);
    const auto add = [&](std::uint64_t value) {
        for (unsigned i = 0; i < 8; ++i) {
            digest ^= value & 255U;
            digest *= UINT64_C(1099511628211);
            value >>= 8U;
        }
    };
    add(static_cast<std::uint64_t>(width));
    add(static_cast<std::uint64_t>(height));
    for (const auto cell : cells) add(static_cast<unsigned>(cell));
    return digest;
}

// Reject malformed immutable proposals before installing them as neighbour
// masks. This intentionally validates native cells/provenance, not a solver's
// assertion that some receptor is satisfied. The coordinator owns final joints.
bool validate_peer(const Request& base, const Result& peer, std::size_t count,
                   std::string& reason) {
    const auto fail = [&](const char* message) { reason = message; return false; };
    if (peer.gentek != Kind::Frameweaver || peer.width != base.width || peer.height != base.height ||
        peer.seed != base.seed || peer.source_identity != base.source_identity ||
        peer.cells.size() != count || peer.roles.size() != count || peer.provenance.size() != count)
        return fail("peer identity, dimensions or native cell/provenance arrays do not match this composition");
    if (peer.status == Status::Invalid || peer.status == Status::Exhausted || peer.status == Status::Unsat ||
        peer.status == Status::Damaged)
        return fail("MOSAIC requires an intact, admitted immutable FRAME proposal");
    if (peer.instances.size() > 256 || peer.boundary.hard.size() > 256 || peer.boundary.soft.size() > 256)
        return fail("peer proposal exceeds finite instance or boundary capacities");
    for (const auto* mask : {&peer.boundary.protected_geometry, &peer.boundary.transition}) {
        if ((!mask->empty() && mask->size() != count) ||
            std::any_of(mask->begin(), mask->end(), [](auto value) { return value > 1; }))
            return fail("peer proposal has a malformed protected or transition mask");
    }
    for (const auto& offer : peer.boundary.hard) {
        if (!inside(base, offer.a) || !inside(base, offer.b) || offer.tag.size() > 96 ||
            static_cast<unsigned>(offer.family) > static_cast<unsigned>(Family::Passage) ||
            std::abs(static_cast<std::int64_t>(offer.facing.x)) > 1 ||
            std::abs(static_cast<std::int64_t>(offer.facing.y)) > 1)
            return fail("peer proposal has a malformed typed offer");
    }
    for (const auto& preference : peer.boundary.soft)
        if (!inside(base, preference.point) || preference.preference.size() > 96)
            return fail("peer proposal has a malformed architectural preference");
    std::set<std::uint32_t> instances;
    std::size_t footprint_count = 0;
    for (const auto& instance : peer.instances) {
        if (instance.id == 0 || !instances.insert(instance.id).second ||
            instance.kind.size() > 128 || instance.reason.size() > 2048 ||
            instance.cells.size() > count || footprint_count > count * 8U - instance.cells.size())
            return fail("peer proposal has invalid or unbounded part provenance");
        footprint_count += instance.cells.size();
        for (const auto point : instance.cells)
            if (!inside(base, point)) return fail("peer part footprint escaped its declared canvas");
    }
    for (std::size_t i = 0; i < count; ++i) {
        if (!valid_material(peer.cells[i]) || static_cast<unsigned>(peer.roles[i]) > static_cast<unsigned>(Role::Transition))
            return fail("peer proposal contains an invalid material or role");
        if (peer.cells[i] == Material::Empty) {
            if (peer.provenance[i] != 0 || peer.roles[i] != Role::Empty)
                return fail("empty peer cell retains structural provenance");
        } else {
            if (peer.provenance[i] == 0 || !instances.contains(peer.provenance[i]) || peer.roles[i] == Role::Empty)
                return fail("peer native material has no owning structural instance");
            if ((!base.protected_void.empty() && base.protected_void[i]) ||
                (!base.context.empty() && base.context[i] != Material::Empty) ||
                (!peer.boundary.protected_geometry.empty() && peer.boundary.protected_geometry[i]))
                return fail("peer material occupies immutable context or protected space");
        }
    }
    return true;
}

bool author_native_bearings(MosaicRevision& revision, const std::vector<TransitionSlot>& slots, MosaicBudget& budget) {
    auto& result = revision.plan.result;
    const auto& request = revision.request;
    if (slots.empty() || (revision.status != MosaicRevisionStatus::Complete && revision.status != MosaicRevisionStatus::Blocked))
        return true;
    const auto debit = [&](std::uint64_t work) {
        if (work > budget.generator_remaining) {
            revision.status = MosaicRevisionStatus::Exhausted;
            revision.reason = "authored MOSAIC bearing response exhausted the existing aggregate generator allowance";
            return false;
        }
        budget.generator_remaining -= work;
        revision.wrapper_work += work;
        revision.bearing_work += work;
        return true;
    };
    // At most eight response scans over the already bounded authored parts and
    // receptors. A material variant consumes no new part or occupied cell.
    const auto scan_work = UINT64_C(512) + slots.size() *
        (UINT64_C(1024) + result.boundary.hard.size() * 8U + result.instances.size() * 4U);
    if (!debit(scan_work)) return false;
    std::vector<MosaicBearingReplacement> replacements;
    std::set<Point> replaced;
    auto responses = revision.plan.responses;
    std::sort(responses.begin(), responses.end(), [](const auto& a, const auto& b) {
        return std::tie(a.slot_id, a.contact) < std::tie(b.slot_id, b.contact);
    });
    for (const auto& response : responses) {
        if (!response.admitted || !response.satisfied ||
            std::find(revision.trace.final_authorized_ids.begin(), revision.trace.final_authorized_ids.end(), response.slot_id) ==
                revision.trace.final_authorized_ids.end()) continue;
        const auto reject = [&](const char* why) {
            revision.bearing_rejections.push_back("slot " + std::to_string(response.slot_id) + ": " + why);
        };
        const auto source = std::find_if(slots.begin(), slots.end(), [&](const auto& slot) { return slot.id == response.slot_id; });
        const Point inward{response.contact.x - response.facing.x, response.contact.y - response.facing.y};
        if (source == slots.end() || std::abs(response.facing.x) + std::abs(response.facing.y) != 1 ||
            source->facing != Point{-response.facing.x, -response.facing.y} ||
            !allowed(request, response.contact) || !allowed(request, inward)) {
            reject("no exact own allowed contact/backing and opposed source");
            continue;
        }
        const auto contact_index = index(request, response.contact), backing_index = index(request, inward);
        if (contact_index >= result.cells.size() || backing_index >= result.cells.size()) {
            reject("incomplete native motif arrays");
            continue;
        }
        const auto owner = result.provenance[contact_index];
        const auto structural = [](Role role) { return role == Role::Structure || role == Role::Transition || role == Role::Brace; };
        if (owner == 0 || result.provenance[backing_index] != owner ||
            !structural(result.roles[contact_index]) || !structural(result.roles[backing_index])) {
            reject("contact and backing do not belong to one existing structural motif");
            continue;
        }
        const auto part = std::find_if(result.instances.begin(), result.instances.end(), [&](const auto& instance) { return instance.id == owner; });
        const bool footprint = part != result.instances.end() &&
            std::find(part->cells.begin(), part->cells.end(), response.contact) != part->cells.end() &&
            std::find(part->cells.begin(), part->cells.end(), inward) != part->cells.end();
        const bool receptor = std::any_of(result.boundary.hard.begin(), result.boundary.hard.end(), [&](const auto& port) {
            return port.instance == owner && port.family == Family::Frame && port.facing == response.facing &&
                (port.a.x == port.b.x || port.a.y == port.b.y) &&
                response.contact.x >= std::min(port.a.x, port.b.x) && response.contact.x <= std::max(port.a.x, port.b.x) &&
                response.contact.y >= std::min(port.a.y, port.b.y) && response.contact.y <= std::max(port.a.y, port.b.y);
        });
        if (!footprint || !receptor) {
            reject("native motif footprint or exact typed receptor missing");
            continue;
        }
        const auto acceptable = [&](std::size_t i) {
            return result.cells[i] == Material::Stone || material_definition(result.cells[i]).state == MaterialState::Solid;
        };
        if (!acceptable(contact_index) || !acceptable(backing_index)) {
            reject("bearing would require new occupancy or an unauthored material conversion");
            continue;
        }
        for (const auto point : {response.contact, inward}) {
            if (result.cells[index(request, point)] == Material::Stone && replaced.insert(point).second)
                replacements.push_back({response.slot_id, owner, point, Material::Stone, Material::LimestoneBlock,
                    "swarm004/mosaic_native_bearing_v1"});
        }
    }
    if (replacements.empty()) return true;
    // A complete new native fingerprint and validation pass is explicitly paid
    // from the same 2M allowance. Later rounds may honestly exhaust this budget.
    const auto finalization_work = result.cells.size() * UINT64_C(24) + result.instances.size() * 64U +
        result.boundary.hard.size() * 32U + replacements.size() * 32U;
    if (!debit(finalization_work)) return false;
    if (cancellation_requested(budget)) {
        revision.status = MosaicRevisionStatus::Cancelled;
        revision.reason = "cancelled before authored native bearing material revision";
        return false;
    }
    std::set<std::uint32_t> changed_parts, changed_slots;
    for (const auto& replacement : replacements) {
        const auto i = index(request, replacement.point);
        // Occupancy and ownership are unchanged; this is an authored material
        // variant inside a solved motif, never a bridge or category rewrite.
        result.cells[i] = replacement.after;
        changed_parts.insert(replacement.instance);
        changed_slots.insert(replacement.slot);
    }
    for (auto& part : result.instances) if (changed_parts.contains(part.id))
        part.reason += "; swarm004/mosaic_native_bearing_v1: existing Stone contact/backing to native LimestoneBlock";
    result.implementation += "+swarm004-native-bearing-v1";
    result.notes.emplace_back("MOSAIC authored native bearing material variant: unchanged GEN-003 assignment, occupied footprint, instance ownership and typed faces; not a physical stability certificate.");
    result.metrics["native_bearing_changed_cells"] = replacements.size();
    result.metrics["native_bearing_changed_slots"] = changed_slots.size();
    result.metrics["native_bearing_work"] = revision.bearing_work;
    const auto occupied_before = result.metrics["occupied_cells"];
    finish_result(request, result);
    if (result.metrics["occupied_cells"] != occupied_before) {
        result.status = Status::Invalid;
        result.termination = "native bearing material variant altered the solved occupied footprint";
    }
    revision.bearing_replacements = std::move(replacements);
    revision.status = revision_status(result.status);
    revision.reason = result.termination;
    return true;
}
} // namespace

const char* name(MosaicRevisionStatus status) noexcept {
    switch (status) {
    case MosaicRevisionStatus::Complete: return "complete";
    case MosaicRevisionStatus::Blocked: return "blocked";
    case MosaicRevisionStatus::Exhausted: return "exhausted";
    case MosaicRevisionStatus::Unsat: return "unsat";
    case MosaicRevisionStatus::Invalid: return "invalid";
    case MosaicRevisionStatus::Cancelled: return "cancelled";
    }
    return "invalid";
}

MosaicRevision propose_mosaic_revision(
    const Request& base, const Result& peer, const std::vector<TransitionSlot>& slots,
    const std::vector<std::uint8_t>& shared_zone, MosaicBudget& budget,
    std::uint32_t round, const Result* previous,
    const std::vector<int>* previous_categories, bool optional_negotiation, bool native_bearing) {
    MosaicRevision out;
    out.round = round;
    const auto fail = [&](MosaicRevisionStatus status, const std::string& why) {
        out.status = status;
        out.reason = why;
    };
    if (cancellation_requested(budget)) {
        fail(MosaicRevisionStatus::Cancelled, "MOSAIC proposal cancelled before native preparation");
        return out;
    }
    std::string reason;
    const bool base_valid = validate_request(base, reason);
    if (base.gentek != Kind::Mosaic || !base_valid || round > 4 ||
        budget.generator_remaining > generator_ceiling || budget.solver_remaining > solver_ceiling ||
        budget.max_bytes > memory_ceiling || budget.proposals_remaining > 5 ||
        base.limits.max_work > generator_ceiling || base.limits.max_solver_work > solver_ceiling ||
        base.limits.max_bytes > memory_ceiling || base.profile.destruction != 0) {
        fail(reason.starts_with("capacity:") ? MosaicRevisionStatus::Exhausted : MosaicRevisionStatus::Invalid, reason.empty() ?
            "invalid SWARM-004 MOSAIC input, aggregate ceiling, round or intact-proposal contract" : reason);
        return out;
    }
    const auto count = static_cast<std::size_t>(base.width) * static_cast<std::size_t>(base.height);
    const auto tile_count = static_cast<std::size_t>((base.width + 15) / 16) * static_cast<std::size_t>((base.height + 15) / 16);
    if ((!shared_zone.empty() && shared_zone.size() != count) ||
        std::any_of(shared_zone.begin(), shared_zone.end(), [](auto value) { return value > 1; }) ||
        slots.size() > max_transition_slots ||
        (previous_categories && (!previous || previous_categories->size() != tile_count ||
            std::any_of(previous_categories->begin(), previous_categories->end(), [](int category) { return category < -1 || category >= 16; }))) ||
        (previous && (previous->gentek != Kind::Mosaic || previous->width != base.width || previous->height != base.height ||
            previous->seed != base.seed || previous->source_identity != base.source_identity ||
            (!previous->cells.empty() && (previous->cells.size() != count || previous->provenance.size() != count))))) {
        fail(MosaicRevisionStatus::Invalid, "malformed shared mask, previous proposal/category receipt or slot capacity");
        return out;
    }
    for (const auto& slot : slots) {
        if (slot.clearance.size() > 4096 || slot.reason.size() > 512 || slot.owner != "FRAMEWEAVER") {
            fail(MosaicRevisionStatus::Invalid, "unbounded or foreign-authored transition reservation");
            return out;
        }
    }
    if (peer.instances.size() > 256 || peer.boundary.hard.size() > 256 || peer.boundary.soft.size() > 256) {
        fail(MosaicRevisionStatus::Invalid, "peer instance or boundary capacity exceeds the bounded immutable protocol");
        return out;
    }
    std::size_t peer_footprints = 0, slot_clearance = 0;
    for (const auto& instance : peer.instances) {
        if (instance.cells.size() > count || peer_footprints > count * 8U - instance.cells.size()) {
            fail(MosaicRevisionStatus::Invalid, "peer footprint receipts exceed the bounded immutable protocol");
            return out;
        }
        peer_footprints += instance.cells.size();
    }
    for (const auto& slot : slots) slot_clearance += slot.clearance.size();
    // Count fixed-size cell visits/copies as one operation each. The donor's
    // existing candidate/predicate accounting remains separate and unchanged.
    // This prepaid reserve includes peer checks, masks, output comparisons and
    // bounded receipt construction, even if a subsequent validation rejects.
    const auto wrapper_reserve = UINT64_C(512) + count * 8U + tile_count * 8U + slots.size() * 128U +
        peer_footprints + peer.instances.size() * 16U + peer.boundary.hard.size() * 32U +
        peer.boundary.soft.size() * 8U + slot_clearance * 4U;
    out.memory_bound = count * 160U + static_cast<std::size_t>(base.limits.max_instances) * 8192U + 1024U * 1024U;
    if (budget.proposals_remaining == 0 || budget.generator_remaining < wrapper_reserve ||
        budget.solver_remaining == 0 || budget.max_bytes < out.memory_bound || base.limits.max_bytes < out.memory_bound) {
        fail(MosaicRevisionStatus::Exhausted, "MOSAIC aggregate proposal, operation, solver or memory allowance exhausted");
        return out;
    }
    --budget.proposals_remaining;
    budget.generator_remaining -= wrapper_reserve;
    out.wrapper_work = wrapper_reserve;
    if (!validate_peer(base, peer, count, reason)) {
        fail(MosaicRevisionStatus::Invalid, reason);
        return out;
    }
    for (std::size_t i = 0; i < count; ++i) {
        if (!shared_zone.empty() && shared_zone[i] && (base.transition.empty() || !base.transition[i])) {
            fail(MosaicRevisionStatus::Invalid, "shared construction claim escaped the declared finite transition zone");
            return out;
        }
    }
    out.peer_material_digest = material_digest(peer.width, peer.height, peer.cells);
    out.previous_material_digest = previous && !previous->cells.empty() ?
        material_digest(previous->width, previous->height, previous->cells) : 0;
    out.request = base;
    out.request.neighbor_cells = peer.cells;
    out.request.neighbors = peer.boundary;
    out.request.eligible.assign(count, 0);
    out.request.neighbors.protected_geometry.assign(count, 0);
    for (std::size_t i = 0; i < count; ++i) {
        const bool protected_cell = (!base.protected_void.empty() && base.protected_void[i]) ||
            (!base.neighbors.protected_geometry.empty() && base.neighbors.protected_geometry[i]) ||
            (!peer.boundary.protected_geometry.empty() && peer.boundary.protected_geometry[i]);
        out.request.neighbors.protected_geometry[i] = static_cast<std::uint8_t>(protected_cell);
        out.request.eligible[i] = static_cast<std::uint8_t>(
            (base.eligible.empty() || base.eligible[i] || (!shared_zone.empty() && shared_zone[i])) &&
            !protected_cell && peer.cells[i] == Material::Empty &&
            (base.context.empty() || base.context[i] == Material::Empty));
    }
    out.request.limits.max_work = std::min(base.limits.max_work, budget.generator_remaining);
    out.request.limits.max_solver_work = std::min(base.limits.max_solver_work, budget.solver_remaining);
    out.request.limits.max_bytes = std::min(base.limits.max_bytes, budget.max_bytes);
    if (cancellation_requested(budget)) {
        out.request = {};
        fail(MosaicRevisionStatus::Cancelled, "MOSAIC proposal cancelled before categorical solve");
        return out;
    }
    auto ordered_slots = slots;
    std::sort(ordered_slots.begin(), ordered_slots.end(), [](const auto& a, const auto& b) {
        return std::tie(a.id, a.a, a.b, a.facing) < std::tie(b.id, b.a, b.b, b.facing);
    });
    const ResilienceOptions options = optional_negotiation ?
        ResilienceOptions{ResilienceAdmission::CompatibilityFour, SolveSchedule::SinglePreferred,
            ResilienceFallback::NativeCore, ReceiverPolicy::RequiredOriginalNative, 8} :
        ResilienceOptions{ResilienceAdmission::CompatibilityHardOnly, SolveSchedule::SinglePreferred,
            ResilienceFallback::HardOnly, ReceiverPolicy::RequiredOriginalNative, 4};
    out.plan = negotiate_mosaic_resilient(out.request, ordered_slots, options, out.trace);
    out.generator_work = out.plan.result.work;
    if (out.generator_work > budget.generator_remaining) {
        fail(MosaicRevisionStatus::Invalid, "native MOSAIC exceeded its aggregate operation allocation");
        budget.generator_remaining = 0;
        out.plan.result.cells.clear();
        return out;
    }
    budget.generator_remaining -= out.generator_work;
    for (const auto& attempt : out.plan.attempts) {
        const auto debit = attempt.work_observed ? attempt.work : (attempt.attempted ? attempt.work_limit : 0);
        if (debit > budget.solver_remaining || out.solver_debit > solver_ceiling - debit) {
            fail(MosaicRevisionStatus::Invalid, "native MOSAIC exceeded its aggregate categorical allocation");
            budget.solver_remaining = 0;
            out.plan.result.cells.clear();
            return out;
        }
        budget.solver_remaining -= debit;
        out.solver_debit += debit;
        out.solver_work_observed = out.solver_work_observed && attempt.work_observed;
    }
    if (cancellation_requested(budget)) {
        // The donor has a deterministic finite work bound, but no cancellation
        // hook. It is checked immediately on return, never published or applied.
        // Retained charge receipts account for the discarded computation.
        out.request = {};
        out.plan = {};
        out.trace = {};
        fail(MosaicRevisionStatus::Cancelled, "MOSAIC proposal cancelled after bounded native solve; output discarded");
        return out;
    }
    out.status = revision_status(out.plan.result.status);
    out.reason = out.plan.result.termination;
    if (native_bearing && !author_native_bearings(out, ordered_slots, budget)) {
        if (out.status == MosaicRevisionStatus::Cancelled) {
            out.request = {};
            out.plan = {};
            out.trace = {};
            out.bearing_replacements.clear();
        }
        return out;
    }
    if (cancellation_requested(budget)) {
        out.request = {};
        out.plan = {};
        out.trace = {};
        out.bearing_replacements.clear();
        fail(MosaicRevisionStatus::Cancelled, "MOSAIC proposal cancelled after native bearing response; output discarded");
        return out;
    }
    if (out.plan.result.cells.size() == count) {
        for (std::size_t i = 0; i < count; ++i) {
            const auto before = previous && !previous->cells.empty() ? previous->cells[i] : Material::Empty;
            const auto before_part = previous && !previous->cells.empty() ? previous->provenance[i] : 0;
            const auto after = out.plan.result.cells[i];
            const auto after_part = out.plan.result.provenance[i];
            if (before != after)
                out.geometry_changes.push_back({static_cast<std::uint32_t>(i), before, after, before_part, after_part});
            else if (before_part != after_part)
                out.provenance_changes.push_back({static_cast<std::uint32_t>(i), before, after, before_part, after_part});
        }
    }
    for (std::size_t i = 0; i < out.plan.categories.size(); ++i) {
        const auto before = previous_categories ? (*previous_categories)[i] : -1;
        if (before != out.plan.categories[i])
            out.category_changes.push_back({static_cast<std::uint32_t>(i), before, out.plan.categories[i]});
    }
    return out;
}

} // namespace cybersand::gentek_swarm::assembly004
