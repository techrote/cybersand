#include "recovery_admission.hpp"
#include <algorithm>
#include <cmath>
#include <limits>

namespace cybersand::gentek_swarm::assembly004 {
namespace {
constexpr std::uint64_t memory_ceiling = 16ULL * 1024ULL * 1024ULL;
constexpr std::uint64_t generator_ceiling = 2'000'000, solver_ceiling = 4'000'000;
constexpr std::size_t part_capacity = 256, connector_capacity = 2048;
constexpr std::size_t alternatives_per_slot = 262; // 2 * (14 + 3 * 13 * 3)
constexpr std::size_t attempts_per_round = 8 * (64 + 1); // bids plus withdrawals

template<class E> bool enum_value(E value, E last) {
    return static_cast<std::uint64_t>(value) <= static_cast<std::uint64_t>(last);
}
bool material(Material value) {
    const auto id = static_cast<std::uint64_t>(value);
    return id <= 131 && id != 10;
}
bool direction(Point p) { return p.x >= -1 && p.x <= 1 && p.y >= -1 && p.y <= 1; }
bool cardinal(Point p) {
    return direction(p) && std::abs(p.x) + std::abs(p.y) == 1;
}
bool fraction(double value) { return std::isfinite(value) && value >= 0 && value <= 1; }

class Admission {
public:
    Admission(const Composition& c, std::string& reason, std::uint64_t& bytes)
        : composition(c), why(reason), used(bytes) {}

    bool run() {
        why.clear(); used = 0;
        const auto& in = composition.input;
        width = in.frame.width; height = in.frame.height;
        if (width < 1 || width > 256 || height < 1 || height > 128 ||
            in.options.rounds > 4 || in.options.shared_extent > 13 ||
            in.options.orientation_preference < -1 || in.options.orientation_preference > 1 ||
            !enum_value(composition.status, CompositionStatus::Oscillation))
            return fail("invalid history dimensions, options or status");
        count = static_cast<std::size_t>(width) * static_cast<std::size_t>(height);
        tiles = static_cast<std::size_t>((width + 15) / 16) * static_cast<std::size_t>((height + 15) / 16);
        if (in.frame.limits.max_bytes > memory_ceiling || in.mosaic.limits.max_bytes > memory_ceiling)
            return fail("history exceeds registered memory allowance");
        allowance = std::min<std::uint64_t>({memory_ceiling, in.frame.limits.max_bytes, in.mosaic.limits.max_bytes});
        // Retained arrays are counted below. This reserve covers the final BFS
        // depth/parent/queue, temporary masks and final material/ownership planes,
        // plus <=1 KiB of streaming hash/diagnostic state. A private native-run
        // capsule may retain a second bounded metrics map/stop string; reserve
        // 128 KiB for it without dereferencing caller-inaccessible authority.
        // No replay copy exists.
        if (!add(sizeof(Composition) + count * 64ULL + 1024 + 128ULL * 1024ULL)) return false;
        if (!request(in.frame, Kind::Frameweaver) || !request(in.mosaic, Kind::Mosaic) ||
            !mask(in.shared_zone, false)) return false;
        if (in.frame.eligible.size() != count || in.mosaic.eligible.size() != count)
            return fail("history lacks complete source territory planes");
        if (!text(composition.reason, 4096) || !text(composition.stop_reason, 128) ||
            !frame_plan(composition.original_frame) || !vector(composition.rounds, 5)) return false;
        if (composition.rounds.empty() || composition.rounds.size() > in.options.rounds + 1)
            return fail("missing or excessive revision history");
        for (std::size_t i = 0; i < composition.rounds.size(); ++i) {
            if (composition.rounds[i].number != i) return fail("invalid revision ordinal");
            if (!round(composition.rounds[i])) return false;
        }
        if (composition.damage_derivative) {
            const auto& damage = *composition.damage_derivative;
            if (!frame(damage.frame) || !mosaic(damage.mosaic) || !text(damage.reason, 2048)) return false;
            if (damage.frame_changed > count || damage.mosaic_changed > count ||
                damage.frame_footprint_changed > count || damage.mosaic_footprint_changed > count ||
                damage.work > 2 * generator_ceiling) return fail("invalid damage receipt bounds");
        }
        if (!materials(composition.cells, true) || !vector(composition.ledger, count) ||
            !strings(composition.rules, 1024, 256) || !vector(composition.obligations, 4096) ||
            !vector(composition.joints, 256) || !dictionary(composition.metrics) ||
            !strings(composition.rejections, 8192, 2048)) return false;
        if (!composition.ledger.empty() && composition.ledger.size() != count)
            return fail("invalid ownership ledger plane");
        for (const auto& cell : composition.ledger)
            if (cell.owner > 3 || cell.instance > part_capacity || cell.rule > composition.rules.size() ||
                cell.first_round > 4 || cell.last_round > 4 || cell.revision_mask > 31)
                return fail("invalid ownership ledger metadata");
        for (const auto& obligation : composition.obligations) {
            if (!canvas(obligation.original) || !direction(obligation.facing) || obligation.instance > part_capacity ||
                !text(obligation.origin, 128) || !text(obligation.state, 128) || !text(obligation.reason, 2048))
                return fail_if_empty("invalid obligation metadata");
        }
        for (const auto& joint : composition.joints) {
            if (!canvas(joint.root) || !canvas(joint.frame_face) || !canvas(joint.masonry_face) ||
                !cardinal(joint.normal) || !enum_value(joint.family, Family::Passage) ||
                joint.frame_instance > part_capacity || joint.mosaic_instance > part_capacity ||
                !points(joint.path, count, true)) return fail_if_empty("invalid joint witness metadata");
        }
        return true;
    }

private:
    const Composition& composition;
    std::string& why;
    std::uint64_t& used;
    std::uint64_t allowance = memory_ceiling;
    int width{}, height{};
    std::size_t count{}, tiles{};

    bool fail(const char* message) { why = message; return false; }
    bool fail_if_empty(const char* message) { return why.empty() ? fail(message) : false; }
    bool add(std::uint64_t bytes) {
        if (used > allowance || bytes > allowance - used) {
            used = allowance + 1;
            return fail("history memory admission exceeds registered allowance");
        }
        used += bytes; return true;
    }
    template<class T> bool vector(const std::vector<T>& values, std::size_t maximum) {
        if (values.size() > maximum) return fail("unbounded history vector");
        // Capacity is observable without dereferencing elements and includes
        // hostile reserve/shrink cases, not only the payload a copy would use.
        if (values.capacity() > allowance / sizeof(T)) {
            used = allowance + 1;
            return fail("history vector capacity exceeds registered allowance");
        }
        return values.capacity() == 0 || add(values.capacity() * sizeof(T) + 64ULL);
    }
    bool text(const std::string& value, std::size_t maximum) {
        if (value.size() > maximum) return fail("unbounded history string");
        if (value.capacity() >= allowance) {
            used = allowance + 1;
            return fail("history string capacity exceeds registered allowance");
        }
        if (!add(value.capacity() + 1ULL + 64ULL)) return false;
        // Existing JSON output normalizes control bytes. Reject them before
        // hashing so different native strings cannot acquire the same encoding.
        for (const unsigned char c : value)
            if (c < 0x20 || c == 0x7f) return fail("ASCII control byte in history string");
        return true;
    }
    bool strings(const std::vector<std::string>& values, std::size_t maximum, std::size_t length) {
        if (!vector(values, maximum)) return false;
        for (const auto& value : values) if (!text(value, length)) return false;
        return true;
    }
    bool dictionary(const std::map<std::string, std::uint64_t>& values) {
        if (values.size() > 256) return fail("unbounded history dictionary");
        if (!add(values.size() * (sizeof(std::map<std::string, std::uint64_t>::value_type) + 4 * sizeof(void*) + 64ULL))) return false;
        for (const auto& [key, value] : values) { (void)value; if (!text(key, 128)) return false; }
        return true;
    }
    bool canvas(Point p) const { return p.x >= 0 && p.y >= 0 && p.x < width && p.y < height; }
    bool bounded(Point p) const { return p.x >= -512 && p.x <= 512 && p.y >= -512 && p.y <= 512; }
    bool points(const std::vector<Point>& values, std::size_t maximum, bool inside) {
        if (!vector(values, maximum)) return false;
        for (const auto p : values) if (!(inside ? canvas(p) : bounded(p)))
            return fail("history geometry outside bounded coordinates");
        return true;
    }
    bool mask(const std::vector<std::uint8_t>& values, bool empty) {
        if (!vector(values, count)) return false;
        if (values.size() != count && !(empty && values.empty())) return fail("invalid history mask dimensions");
        for (const auto value : values) if (value > 1) return fail("non-binary history mask");
        return true;
    }
    bool materials(const std::vector<Material>& values, bool empty) {
        if (!vector(values, count)) return false;
        if (values.size() != count && !(empty && values.empty())) return fail("invalid material plane dimensions");
        for (const auto value : values) if (!material(value)) return fail("invalid native material enum");
        return true;
    }
    bool boundary(const Boundary& b) {
        if (!vector(b.hard, 256) || !vector(b.soft, 256) ||
            !mask(b.protected_geometry, true) || !mask(b.transition, true)) return false;
        for (const auto& port : b.hard) {
            if (!canvas(port.a) || !canvas(port.b) || !direction(port.facing) ||
                !enum_value(port.family, Family::Passage) || !fraction(port.strength) ||
                !text(port.tag, 96)) return fail_if_empty("invalid typed boundary metadata");
        }
        for (const auto& port : b.soft) {
            if (!canvas(port.point) || !direction(port.direction) || !fraction(port.strength) ||
                !text(port.preference, 96)) return fail_if_empty("invalid soft boundary metadata");
        }
        return true;
    }
    bool request(const Request& q, Kind owner) {
        if (q.gentek != owner || q.version != 0 || q.width != width || q.height != height ||
            q.origin.x < -1'000'000 || q.origin.x > 1'000'000 || q.origin.y < -1'000'000 || q.origin.y > 1'000'000)
            return fail("invalid native request identity or geometry");
        const auto& limits = q.limits;
        if (limits.max_instances > (owner == Kind::Frameweaver ? 64U : 192U) || limits.max_frontier > 256 ||
            limits.max_candidates > 8192 || limits.max_connectors_per_instance > 8 || limits.max_affordances > 256 ||
            limits.max_cohesion_patches > 8 || limits.max_cohesion_cells_per_patch > 512 ||
            limits.max_work > generator_ceiling || limits.max_solver_work > solver_ceiling || limits.max_bytes > memory_ceiling)
            return fail("native request exceeds registered capacities");
        if (!text(q.definition_fingerprint, 128) || !text(q.source_identity, 128) || !text(q.fixture, 96) ||
            !text(q.profile.name, 96) || !mask(q.eligible, true) || !mask(q.protected_void, true) ||
            !mask(q.transition, true) || !materials(q.context, true) || !materials(q.neighbor_cells, true) ||
            !points(q.activation, 16, true) || !boundary(q.neighbors)) return false;
        for (const auto value : {q.profile.variation, q.profile.irregularity, q.profile.clutter, q.profile.destruction,
                q.profile.branching, q.profile.environment_affinity, q.profile.cohesion})
            if (!fraction(value)) return fail("invalid profile scalar in native history");
        return true;
    }
    bool result(const Result& r, Kind owner, bool empty = false) {
        if ((!empty || !r.cells.empty()) && (r.gentek != owner || r.width != width || r.height != height))
            return fail("invalid native result identity or dimensions");
        if (empty && r.cells.empty() && !((r.width == 0 && r.height == 0) || (r.width == width && r.height == height)))
            return fail("invalid absent native result dimensions");
        if (!enum_value(r.gentek, Kind::Receptor) || !enum_value(r.status, Status::Damaged) ||
            r.work > generator_ceiling || r.solver_work > solver_ceiling || r.candidates > 8192 ||
            r.backtracks < -1 || r.backtracks > static_cast<std::int64_t>(solver_ceiling))
            return fail("invalid native result status or counters");
        if (!text(r.implementation, 128) || !text(r.definition_fingerprint, 128) || !text(r.source_identity, 128) ||
            !text(r.termination, 2048) || !materials(r.cells, empty) || !vector(r.roles, count) ||
            !vector(r.provenance, count) || !vector(r.instances, part_capacity) ||
            !vector(r.connectors, connector_capacity) || !vector(r.attachments, connector_capacity) ||
            !boundary(r.boundary) || !dictionary(r.metrics) || !dictionary(r.rejected) || !strings(r.notes, 64, 4096)) return false;
        if (r.roles.size() != r.cells.size() || r.provenance.size() != r.cells.size()) return fail("mismatched native result planes");
        for (const auto role : r.roles) if (!enum_value(role, Role::Transition)) return fail("invalid native role enum");
        for (const auto id : r.provenance) if (id > part_capacity) return fail("unbounded native owner identity");
        std::size_t footprint = 0;
        for (const auto& part : r.instances) {
            if (part.id == 0 || part.id > part_capacity || !bounded(part.origin) || part.orientation < -8 || part.orientation > 8 ||
                part.cells.size() > count || footprint > count * 8ULL - part.cells.size()) return fail("invalid native part bounds");
            footprint += part.cells.size();
            if (!text(part.kind, 128) || !text(part.reason, 1024) || !points(part.cells, count, true)) return false;
        }
        for (const auto& connector : r.connectors) {
            if (!enum_value(connector.family, Family::Passage) || !canvas(connector.a) || !canvas(connector.b) ||
                !direction(connector.facing) || connector.instance > part_capacity || !text(connector.state, 128))
                return fail_if_empty("invalid native connector metadata");
        }
        for (const auto& attachment : r.attachments) {
            if (attachment.instance > part_capacity || !canvas(attachment.point) || !canvas(attachment.target) ||
                !text(attachment.kind, 128) || !text(attachment.reason, 1024)) return fail_if_empty("invalid attachment metadata");
        }
        return true;
    }
    bool slots(const std::vector<TransitionSlot>& values) {
        if (!vector(values, max_transition_slots)) return false;
        for (const auto& slot : values) {
            const auto& box = slot.envelope;
            if (!enum_value(slot.kind, SlotKind::PassageOpening) || !canvas(slot.a) || !canvas(slot.b) || !cardinal(slot.facing) ||
                slot.instance > part_capacity || !fraction(slot.strength) || box.x < 0 || box.y < 0 || box.w < 0 || box.h < 0 ||
                static_cast<std::int64_t>(box.x) + box.w > width || static_cast<std::int64_t>(box.y) + box.h > height ||
                !points(slot.clearance, count, true) || !text(slot.owner, 128) || !text(slot.reason, 2048))
                return fail_if_empty("invalid transition reservation metadata");
        }
        return true;
    }
    bool frame_plan(const FramePlan& plan) {
        if (!result(plan.core, Kind::Frameweaver, true) || !result(plan.result, Kind::Frameweaver) || !slots(plan.slots) ||
            !strings(plan.reservation_rejections, 8192, 2048) || !vector(plan.source_feasibility, 512)) return false;
        for (const auto& decision : plan.source_feasibility) {
            if (decision.instance > part_capacity || !canvas(decision.source) || !canvas(decision.face) ||
                !cardinal(decision.facing) || !canvas(decision.contact) || !canvas(decision.backing) ||
                decision.work > generator_ceiling || !text(decision.part, 128) || !text(decision.reason, 2048))
                return fail_if_empty("invalid source opportunity metadata");
        }
        return true;
    }
    bool transform(const Transform& t) { return bounded(t.translation) && t.quarter_turns <= 3; }
    bool socket(const PlacedSocket& s) {
        return s.instance <= part_capacity && bounded(s.a) && bounded(s.b) && direction(s.facing) &&
            enum_value(s.family, Family::Passage) && enum_value(s.obligation, Obligation::ForeignRequired);
    }
    bool expansion(const ExpandedAssembly& a) {
        if (!enum_value(a.outcome, Outcome::Cancelled) || (a.owner != Owner::Frameweaver && a.owner != Owner::Mosaic) ||
            a.round > 4 || a.revision > 4 || a.declared_cells > count * 8ULL || a.shared_joint_cells > count * 8ULL ||
            !text(a.reason, 2048) || !vector(a.nodes, 64) || !vector(a.instances, 64) ||
            !vector(a.claims, std::min<std::size_t>(8192, count * 8)) || !vector(a.sockets, 512) ||
            !vector(a.joints, 512) || !vector(a.rejections, 8192)) return fail_if_empty("invalid authored expansion bounds");
        for (const auto& node : a.nodes)
            if (node.depth > 6 || !transform(node.transform) || !text(node.rule, 256)) return fail_if_empty("invalid authored node");
        for (const auto& part : a.instances) {
            if (part.instance > part_capacity || part.depth > 6 || !transform(part.transform) ||
                !text(part.name, 128) || !text(part.rule, 256) || !vector(part.sockets, 8)) return fail_if_empty("invalid authored part");
            for (const auto& s : part.sockets) if (!socket(s)) return fail("invalid authored part socket");
        }
        for (const auto& claim : a.claims) {
            if (!bounded(claim.point) || !material(claim.material) || !enum_value(claim.role, Role::Transition) ||
                (claim.owner != Owner::Frameweaver && claim.owner != Owner::Mosaic) || claim.instance > part_capacity ||
                claim.round > 4 || claim.revision > 4 || !text(claim.rule, 256)) return fail_if_empty("invalid authored material claim");
        }
        for (const auto& s : a.sockets) if (!socket(s)) return fail("invalid authored exported socket");
        for (const auto& joint : a.joints)
            if (!enum_value(joint.family, Family::Passage) || joint.instance_a > part_capacity || joint.instance_b > part_capacity ||
                !points(joint.cells, count, false)) return fail_if_empty("invalid authored joint metadata");
        for (const auto& rejection : a.rejections) if (!text(rejection.reason, 2048)) return false;
        return true;
    }
    bool frame(const FrameRevision& value) {
        if (!result(value.result, Kind::Frameweaver) || !slots(value.slots) || !vector(value.constructions, 8) ||
            !strings(value.rejections, 8192, 2048)) return false;
        if (value.local_terminations > connector_capacity) return fail("invalid local termination count");
        for (const auto& part : value.constructions) {
            if (part.base_instance > part_capacity || !canvas(part.root) || !canvas(part.face) || !cardinal(part.facing) ||
                part.span > 24 || part.rise > 16 || part.handedness < -1 || part.handedness > 1 ||
                !enum_value(part.input_family, Family::Passage) || !vector(part.parts, 64) ||
                !vector(part.reused_host_components, part_capacity) || !text(part.rule, 256) || !expansion(part.assembly))
                return fail_if_empty("invalid FRAME construction metadata");
            for (auto id : part.parts) if (id > part_capacity) return fail("invalid FRAME part identity");
            for (auto id : part.reused_host_components) if (id > part_capacity) return fail("invalid reused host identity");
        }
        return true;
    }
    bool solver_attempt(const SolverAttempt& a) {
        if (!enum_value(a.status, Status::Damaged) || a.work > solver_ceiling || a.work_limit > solver_ceiling)
            return fail("invalid categorical attempt scalar");
        return text(a.policy, 128) && text(a.reason, 2048);
    }
    bool categories(const std::vector<int>& values) {
        if (!vector(values, tiles)) return false;
        for (auto value : values) if (value < -1 || value > 15) return fail("invalid native category identity");
        return true;
    }
    bool mosaic(const MosaicPlan& value) {
        if (!result(value.result, Kind::Mosaic) || !vector(value.domains, tiles) || !categories(value.categories) ||
            !vector(value.attempts, 16) || !vector(value.responses, max_transition_slots)) return false;
        for (const auto& domain : value.domains) {
            if (domain.tile >= tiles || !canvas(domain.origin) || domain.selected < -1 || domain.selected > 15 ||
                !vector(domain.influences, max_transition_slots)) return fail_if_empty("invalid category domain metadata");
            for (const auto& influence : domain.influences)
                if (!canvas(influence.contact) || !text(influence.reason, 2048)) return fail_if_empty("invalid domain influence");
        }
        for (const auto& attempt : value.attempts) if (!solver_attempt(attempt)) return false;
        for (const auto& response : value.responses)
            if (response.tile >= tiles || !canvas(response.contact) || !direction(response.facing) ||
                !text(response.reason, 2048)) return fail_if_empty("invalid categorical response metadata");
        return true;
    }
    bool native_admission(const NativeAdmissionReceipt& value) {
        if (!enum_value(value.status, Status::Damaged) || value.work > generator_ceiling ||
            value.optional_capacity > 8 || value.fallback_optional_capacity > 8 || !text(value.reason, 2048) ||
            !vector(value.selected_ids, 8) || !vector(value.fallback_ids, 8) || !vector(value.decisions, 8) ||
            !vector(value.original_domains, tiles) || !vector(value.hard_domains, tiles) ||
            !vector(value.preferred_domains, tiles) || !vector(value.fallback_domains, tiles))
            return fail_if_empty("invalid native admission trace");
        for (const auto& decision : value.decisions) {
            if (decision.tile < -1 || decision.tile >= static_cast<std::int32_t>(tiles) || decision.rank < -1 || decision.rank > 8 ||
                decision.distance < -1 || decision.distance > width + height || decision.neighbor_support > 4 * 16 * 16 ||
                !canvas(decision.contact) || !text(decision.disposition, 128) || !text(decision.reason, 2048))
                return fail_if_empty("invalid native admission decision");
        }
        return true;
    }
    bool solver_trace(const ResilienceSolverTrace& value) {
        if (value.width > static_cast<unsigned>((width + 15) / 16) || value.height > static_cast<unsigned>((height + 15) / 16) ||
            value.aggregate_limit > solver_ceiling || value.allocated_limit > solver_ceiling ||
            value.attempted_limit > solver_ceiling || value.preparation_work > solver_ceiling ||
            !vector(value.category_ids, 16) || !vector(value.attempts, 16) ||
            !vector(value.primary_optional_ids, 8) || !vector(value.fallback_optional_ids, 8))
            return fail_if_empty("invalid categorical solver trace");
        for (const auto& attempt : value.attempts)
            if (!solver_attempt(attempt.solver) || !vector(attempt.domains, tiles) || !vector(attempt.optional_ids, 8) ||
                !categories(attempt.categories) || !text(attempt.trigger, 2048)) return false;
        return true;
    }
    bool trace(const ResilienceTrace& value) {
        if (!native_admission(value.admission) || !solver_trace(value.solver) || !vector(value.final_authorized_ids, 8) ||
            !vector(value.primary_selected_ids, 8) || !vector(value.fallback_selected_ids, 8) ||
            !vector(value.dropped_preference_ids, 8) || !vector(value.receivers, 8) || !text(value.reason, 2048)) return false;
        for (const auto& receiver : value.receivers) {
            if (receiver.original_tile >= tiles || receiver.selected_tile >= tiles || !canvas(receiver.original_contact) ||
                !canvas(receiver.selected_contact) || receiver.work > generator_ceiling || receiver.points_examined > count ||
                !vector(receiver.faces, 64) || !text(receiver.reason, 2048)) return fail_if_empty("invalid receiver trace");
            for (const auto& face : receiver.faces)
                if (!canvas(face.contact) || face.tile >= tiles || face.distance < 0 || face.distance > width + height)
                    return fail("invalid receiver face trace");
        }
        return true;
    }
    bool recovery(const Round& value) {
        if (!vector(value.recovery_attempts, attempts_per_round) || !vector(value.mosaic_recovery_receipts, 8) ||
            !vector(value.recovery_frontier, 8)) return false;
        for (const auto& attempt : value.recovery_attempts) {
            if (attempt.ordinal >= alternatives_per_slot || attempt.round < 1 || attempt.round > 4 ||
                attempt.source_instance > part_capacity || attempt.host_instance > part_capacity || !canvas(attempt.root) ||
                !bounded(attempt.contact) || !direction(attempt.axis) || attempt.length > 6 || attempt.variant > 3 ||
                attempt.work > generator_ceiling || !text(attempt.phase, 128) || !text(attempt.outcome, 128) ||
                !text(attempt.reason, 2048)) return fail_if_empty("invalid recovery attempt metadata");
        }
        for (const auto& receipt : value.mosaic_recovery_receipts) {
            if (receipt.source_instance > part_capacity || receipt.host_instance > part_capacity || receipt.receiving_instance > part_capacity ||
                receipt.round < 1 || receipt.round > 4 || receipt.candidate >= alternatives_per_slot || receipt.length > 6 || receipt.variant > 3 ||
                !canvas(receipt.root) || !canvas(receipt.contact) || !canvas(receipt.backing) || !canvas(receipt.host) ||
                !direction(receipt.axis) || !direction(receipt.cross) || !enum_value(receipt.source_family, Family::Passage) ||
                !enum_value(receipt.receiving_family, Family::Passage) || receipt.work > generator_ceiling || !vector(receipt.edits, 14))
                return fail_if_empty("invalid recovery receipt metadata");
            for (const auto& edit : receipt.edits)
                if (!canvas(edit.point) || !material(edit.before) || !material(edit.after) ||
                    !enum_value(edit.before_role, Role::Transition) || !enum_value(edit.after_role, Role::Transition) ||
                    edit.before_owner > part_capacity || edit.after_owner > part_capacity) return fail("invalid recovery material edit");
        }
        for (const auto& cursor : value.recovery_frontier)
            if (cursor.next > alternatives_per_slot) return fail("invalid recovery frontier bound");
        return true;
    }
    bool round(const Round& value) {
        if (value.number > 4 || value.mosaic_reuse_round > 4 || value.frame_reuse_round > 4 ||
            value.mosaic_proposal_work > generator_ceiling || value.mosaic_proposal_solver_debit > solver_ceiling ||
            value.mosaic_bearing_work > generator_ceiling || value.mosaic_supported_receptor_work > generator_ceiling ||
            value.recovery_work > generator_ceiling || value.frame_work > generator_ceiling || value.mosaic_work > generator_ceiling ||
            value.solver_work > solver_ceiling || value.shared_work > generator_ceiling || value.frame_changed > count ||
            value.mosaic_changed > count || value.category_changed > tiles || value.frame_footprint_changed > count ||
            value.mosaic_footprint_changed > count) return fail("invalid revision scalar bounds");
        if (!frame(value.frame) || !mosaic(value.mosaic) || !request(value.mosaic_request, Kind::Mosaic) ||
            !result(value.proposed_frame, Kind::Frameweaver, true) || !result(value.proposed_mosaic, Kind::Mosaic, true) ||
            !trace(value.mosaic_trace) || !text(value.mosaic_proposal_reason, 2048) ||
            !vector(value.mosaic_bearing_replacements, 16) || !strings(value.mosaic_bearing_rejections, 8192, 2048) ||
            !vector(value.mosaic_supported_receptors, 8) || !recovery(value) || !text(value.reason, 4096)) return false;
        for (const auto& replacement : value.mosaic_bearing_replacements)
            if (replacement.instance > part_capacity || !canvas(replacement.point) || !material(replacement.before) ||
                !material(replacement.after) || !text(replacement.rule, 256)) return fail_if_empty("invalid native bearing receipt");
        for (const auto& receptor : value.mosaic_supported_receptors)
            if (receptor.source_instance > part_capacity || receptor.receiving_instance > part_capacity || !canvas(receptor.root) ||
                !canvas(receptor.contact) || !canvas(receptor.backing) || !cardinal(receptor.facing))
                return fail("invalid supported receptor metadata");
        return true;
    }
};
} // namespace

bool admit_recovery_history(const Composition& composition, std::string& reason,
                            std::uint64_t& conservative_bytes) {
    return Admission(composition, reason, conservative_bytes).run();
}

} // namespace cybersand::gentek_swarm::assembly004
