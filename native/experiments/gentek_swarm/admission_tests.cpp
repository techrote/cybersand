#include "negotiated.hpp"

#include <algorithm>
#include <array>
#include <iostream>
#include <set>
#include <stdexcept>
#include <tuple>

using namespace cybersand::gentek_swarm;

namespace {
void require(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}
std::uint64_t metric(const NegotiatedResult& n, const std::string& key) {
    const auto at = n.metrics.find(key);
    return at == n.metrics.end() ? 0 : at->second;
}
std::uint64_t first_invoked_limit(const MosaicPlan& plan) {
    for (const auto& attempt : plan.attempts)
        if (attempt.attempted) return attempt.work_limit;
    return 0;
}
bool same_slot(const TransitionSlot& a, const TransitionSlot& b) {
    return std::tie(a.id, a.instance, a.connector, a.kind, a.a, a.b, a.facing,
                    a.envelope.x, a.envelope.y, a.envelope.w, a.envelope.h,
                    a.clearance, a.required, a.hard, a.strength, a.owner, a.reason) ==
           std::tie(b.id, b.instance, b.connector, b.kind, b.a, b.b, b.facing,
                    b.envelope.x, b.envelope.y, b.envelope.w, b.envelope.h,
                    b.clearance, b.required, b.hard, b.strength, b.owner, b.reason);
}
bool same_limits(const Limits& a, const Limits& b, bool solver = true) {
    return std::tie(a.max_instances, a.max_frontier, a.max_candidates, a.max_connectors_per_instance,
                    a.max_affordances, a.max_cohesion_patches, a.max_cohesion_cells_per_patch,
                    a.max_work, a.max_bytes) ==
           std::tie(b.max_instances, b.max_frontier, b.max_candidates, b.max_connectors_per_instance,
                    b.max_affordances, b.max_cohesion_patches, b.max_cohesion_cells_per_patch,
                    b.max_work, b.max_bytes) && (!solver || a.max_solver_work == b.max_solver_work);
}
bool same_request(const Request& a, const Request& b, bool solver = true) {
    const auto& ap = a.profile; const auto& bp = b.profile;
    return a.gentek == b.gentek && a.version == b.version && a.definition_fingerprint == b.definition_fingerprint &&
           a.source_identity == b.source_identity && a.fixture == b.fixture && a.seed == b.seed &&
           a.width == b.width && a.height == b.height && a.origin == b.origin && a.activation == b.activation &&
           a.eligible == b.eligible && a.protected_void == b.protected_void && a.transition == b.transition &&
           a.context == b.context && a.neighbor_cells == b.neighbor_cells &&
           a.neighbors.protected_geometry == b.neighbors.protected_geometry &&
           a.neighbors.transition == b.neighbors.transition &&
           a.neighbors.hard.size() == b.neighbors.hard.size() && a.neighbors.soft.size() == b.neighbors.soft.size() &&
           std::tie(ap.name, ap.variation, ap.irregularity, ap.clutter, ap.destruction, ap.branching, ap.environment_affinity, ap.cohesion) ==
           std::tie(bp.name, bp.variation, bp.irregularity, bp.clutter, bp.destruction, bp.branching, bp.environment_affinity, bp.cohesion) &&
           same_limits(a.limits, b.limits, solver);
}
std::set<std::uint32_t> selected(const AdmissionResult& n) {
    return {n.admission.selected_ids.begin(), n.admission.selected_ids.end()};
}
const SlotAdmission& decision(const AdmissionResult& n, std::uint32_t id) {
    const auto at = std::find_if(n.admission.decisions.begin(), n.admission.decisions.end(),
                                 [&](const auto& d) { return d.slot_id == id; });
    require(at != n.admission.decisions.end(), "missing admission decision");
    return *at;
}
void check(const PreparedAdmission& prepared, const AdmissionResult& admitted) {
    const auto& original = prepared.prepared;
    const auto& n = admitted.candidate;
    require(admitted.admission.status != Status::Invalid, "valid policy rejected: " + admitted.admission.reason);
    const auto ids = selected(admitted);
    require(ids.size() == admitted.admission.selected_ids.size(), "duplicate selected ID");
    require(n.frame.slots.size() == original.frame.slots.size() && n.frame.slots.size() <= max_transition_slots,
            "admission deleted a reservation from frozen frame plan");
    require(n.frame.result.digest == original.frame.result.digest && n.frame.core.digest == original.frame.core.digest &&
            n.frame.result.cells == original.frame.result.cells && n.frame.core.cells == original.frame.core.cells,
            "admission changed frozen FRAMEWEAVER");
    for (const auto& slot : original.frame.slots) {
        const auto same = std::find_if(n.frame.slots.begin(), n.frame.slots.end(), [&](const auto& x) { return x.id == slot.id; });
        require(same != n.frame.slots.end() && same_slot(slot, *same), "admission altered reservation semantics");
        const auto& d = decision(admitted, slot.id);
        const bool mandatory = slot.required || slot.hard;
        require(d.mandatory == mandatory && d.selected == ids.contains(slot.id), "selection receipt disagrees with original semantics");
        require(!mandatory || d.selected, "mandatory/hard slot dropped");
        require(!slot.required || slot.hard, "required slot became soft");
        require(!d.reason.empty(), "admission decision has no reason");
        require(mandatory ? d.rank == -1 : d.rank >= 0, "invalid mandatory/optional rank");
        const auto frozen_rank = std::find_if(prepared.ranking.begin(), prepared.ranking.end(), [&](const auto& r) { return r.slot_id == slot.id; });
        require(frozen_rank != prepared.ranking.end() &&
                std::tie(d.rank, d.witness_found, d.nearest_forward_distance, d.witness_source, d.witness_peer) ==
                std::tie(frozen_rank->rank, frozen_rank->witness_found, frozen_rank->nearest_forward_distance,
                         frozen_rank->witness_source, frozen_rank->witness_peer), "selection changed pre-solve ranking witness");
        if (d.witness_found) {
            const auto source_segment = line(slot.a, slot.b);
            require(std::find(source_segment.begin(), source_segment.end(), d.witness_source) != source_segment.end(), "ranking witness source escaped its slot");
            require(allowed(n.mosaic_request, d.witness_peer) && transition_at(n.mosaic_request, d.witness_peer), "ranking witness peer is not admissible transition space");
            const Point delta{d.witness_peer.x - d.witness_source.x, d.witness_peer.y - d.witness_source.y};
            require(delta.x * slot.facing.x + delta.y * slot.facing.y > 0 &&
                    d.nearest_forward_distance == std::abs(delta.x) + std::abs(delta.y), "ranking distance/facing witness is false");
            require(d.witness_peer.x >= slot.envelope.x && d.witness_peer.x < slot.envelope.x + slot.envelope.w &&
                    d.witness_peer.y >= slot.envelope.y && d.witness_peer.y < slot.envelope.y + slot.envelope.h,
                    "ranking witness escaped immutable envelope");
            require(!allowed(n.mosaic_request, {d.witness_peer.x - slot.facing.x, d.witness_peer.y - slot.facing.y}),
                    "ranking witness is not a receiving ownership face");
        }
    }
    require(admitted.admission.decisions.size() == original.frame.slots.size(), "extra/missing admission records");
    require(same_request(n.frame_request, original.frame_request), "FRAMEWEAVER request changed");
    require(same_request(n.mosaic_request, original.mosaic_request, !admitted.admission.diagnostic), "MOSAIC masks/materials/profile changed");
    require(n.mosaic_request.limits.max_solver_work == admitted.admission.solver_work_limit, "solver limit receipt mismatch");
    require(admitted.admission.solver_work_limit == (admitted.admission.diagnostic ? 2'000'000 : 4'000'000), "unregistered solver budget");
    require(n.work <= admitted.admission.join_work_limit, "shared join work exceeded remaining original budget");
    require(admitted.admission.ranking_work + admitted.admission.selection_work + admitted.admission.join_work_limit <= 2'000'000,
            "admission silently enlarged original shared work ceiling");
    require(admitted.admission.structural_work_upper_bound <= 10'000'000, "structural upper bound grew");
    require(n.frame.result.work <= n.frame_request.limits.max_work && n.mosaic.result.work <= n.mosaic_request.limits.max_work,
            "generator work ceiling exceeded");

    std::uint64_t solver_limits = 0;
    for (const auto& attempt : n.mosaic.attempts) {
        solver_limits += attempt.work_limit;
        require(!attempt.work_observed || attempt.work <= attempt.work_limit, "solver work exceeds attempt bound");
    }
    require(n.mosaic.attempts.size() <= 2 && solver_limits <= n.mosaic_request.limits.max_solver_work,
            "unbounded retries or aggregate solver work");
    for (const auto& d : n.mosaic.domains) {
        if (d.selected >= 0) require((d.modified_domain & (1U << d.selected)) != 0, "selected category outside final domain");
        for (const auto& influence : d.influences) {
            require(ids.contains(influence.slot_id), "dropped slot changed a domain");
            const auto slot = std::find_if(n.frame.slots.begin(), n.frame.slots.end(), [&](const auto& s) { return s.id == influence.slot_id; });
            require(slot != n.frame.slots.end() && influence.hard == slot->hard, "categorical influence softened its original condition");
        }
    }
    for (const auto& response : n.mosaic.responses) require(ids.contains(response.slot_id), "dropped slot received a solver response");
    if (n.mosaic.result.status == Status::Complete) for (const auto& slot : n.frame.slots) {
        if (!slot.required && !slot.hard) continue;
        const auto response = std::find_if(n.mosaic.responses.begin(), n.mosaic.responses.end(), [&](const auto& r) { return r.slot_id == slot.id; });
        require(response != n.mosaic.responses.end() && response->satisfied, "complete solve evaded mandatory material response");
    }
    for (const auto* key : {"protected_violations", "illegal_overlaps", "frozen_core_changes", "mosaic_frozen_changes"})
        require(metric(n, key) == 0, key);
    require(n.cells == n.finished_cells, "residual finish unexpectedly enabled");
    require(std::none_of(n.residual.cells.begin(), n.residual.cells.end(), [](auto m) { return m != cybersand::Material::Empty; }),
            "residual cells appeared in admission comparison");

    const auto& f = n.control.fixture;
    std::uint64_t additions = 0;
    for (std::size_t i = 0; i < n.cells.size(); ++i) {
        const auto frame_cell = n.final_frame.cells[i], mosaic_cell = n.final_mosaic.cells[i];
        require(!(frame_cell != cybersand::Material::Empty && mosaic_cell != cybersand::Material::Empty), "cross-owner overlap");
        if (frame_cell != cybersand::Material::Empty) require(f.side[i] == 0 && f.context[i] == cybersand::Material::Empty, "frame escaped ownership");
        if (mosaic_cell != cybersand::Material::Empty) require(f.side[i] == 1 && f.context[i] == cybersand::Material::Empty, "mosaic escaped ownership");
        if (f.protected_void[i]) require(n.cells[i] == cybersand::Material::Empty, "fixture protected passage consumed");
        if (n.frame.result.cells[i] != cybersand::Material::Empty)
            require(frame_cell == n.frame.result.cells[i], "reserved frame material rewritten");
        if (n.mosaic.result.cells[i] != cybersand::Material::Empty)
            require(mosaic_cell == n.mosaic.result.cells[i], "solved MOSAIC material rewritten");
        additions += frame_cell != cybersand::Material::Empty && n.frame.result.cells[i] == cybersand::Material::Empty;
        additions += mosaic_cell != cybersand::Material::Empty && n.mosaic.result.cells[i] == cybersand::Material::Empty;
    }
    require(additions == metric(n, "candidate_posthoc_cells"), "post-hoc geometry not honestly counted");
    for (const auto& source : n.frame.result.connectors) if (source.required) {
        const auto final = std::find_if(n.final_frame.connectors.begin(), n.final_frame.connectors.end(), [&](const auto& c) { return c.id == source.id; });
        require(final != n.final_frame.connectors.end() && final->required, "mandatory connector removed or downgraded");
        if (!source.fulfilled && final->fulfilled) {
            const bool joined = std::any_of(n.frame.slots.begin(), n.frame.slots.end(), [&](const auto& slot) {
                return slot.connector == source.id && slot.instance == source.instance &&
                    std::any_of(n.seams.begin(), n.seams.end(), [&](const auto& seam) { return seam.left_affordance == slot.id && seam.joined; });
            });
            require(joined, "mandatory connector fulfilled without its actual recorded joint");
        }
    }
    for (const auto& seam : n.seams) {
        if (!seam.joined) continue;
        require(ids.contains(seam.left_affordance), "dropped reservation joined");
        require(seam.cells.size() >= 2 && seam.cells.size() <= 16, "unbounded final joint");
        const auto slot = std::find_if(n.frame.slots.begin(), n.frame.slots.end(), [&](const auto& s) { return s.id == seam.left_affordance; });
        const auto response = std::find_if(n.mosaic.responses.begin(), n.mosaic.responses.end(), [&](const auto& r) { return r.slot_id == seam.left_affordance; });
        require(slot != n.frame.slots.end() && response != n.mosaic.responses.end() && response->satisfied, "joint has no reservation/selected motif witness");
        require(seam.cells.front() == seam.a && seam.cells.back() == seam.b, "joint endpoints disagree");
        require(Point{seam.cells[1].x - seam.a.x, seam.cells[1].y - seam.a.y} == slot->facing, "joint leaves frame sideways");
        const auto penultimate = seam.cells[seam.cells.size() - 2];
        require(Point{penultimate.x - seam.b.x, penultimate.y - seam.b.y} == response->facing, "joint enters masonry sideways");
        for (std::size_t at = 0; at < seam.cells.size(); ++at) {
            const auto point = seam.cells[at];
            require(inside(n.frame_request, point), "joint outside canvas");
            const auto index_ = index(n.frame_request, point);
            require(n.cells[index_] != cybersand::Material::Empty && f.transition[index_] && !f.protected_void[index_], "joint lacks legal material path");
            require(point.x >= slot->envelope.x && point.x < slot->envelope.x + slot->envelope.w &&
                    point.y >= slot->envelope.y && point.y < slot->envelope.y + slot->envelope.h, "joint escaped slot envelope");
            if (at) require(std::abs(point.x - seam.cells[at - 1].x) + std::abs(point.y - seam.cells[at - 1].y) == 1, "disconnected material joint");
        }
    }
}
AdmissionPolicy cap_policy(unsigned cap) {
    AdmissionPolicy policy; policy.mode = AdmissionMode::OptionalCap; policy.optional_cap = cap; return policy;
}
AdmissionPolicy drop_policy(std::uint32_t id) {
    AdmissionPolicy policy; policy.mode = AdmissionMode::LeaveOneOut; policy.omitted_optional_id = id; return policy;
}
} // namespace

int main() {
    unsigned passed = 0, failed = 0;
    const auto test = [&](const char* label, const auto& run) {
        try { run(); ++passed; std::cout << "PASS " << label << '\n'; }
        catch (const std::exception& error) { ++failed; std::cerr << "FAIL " << label << ": " << error.what() << '\n'; }
    };

    test("36 matched cases x four caps: frozen inputs, mandatory retention, safety and no dropped-slot authority", [] {
        unsigned cases = 0, variants = 0, mandatory_seen = 0, dropped_seen = 0;
        for (const auto& fn : fixture_names())
            for (const auto* pn : {"sparse_regular", "branching_irregular", "dense_cohesive"})
                for (auto seed : {605ULL, 1701ULL}) {
                    const auto prepared = prepare_admission(fixture(fn), profile(pn), seed, "admission-tests");
                    ++cases;
                    std::set<std::uint32_t> previous;
                    std::map<std::uint32_t, int> ranks;
                    for (auto cap : {0U, 1U, 2U, 4U}) {
                        const auto result = negotiate_admission(prepared, cap_policy(cap));
                        check(prepared, result); ++variants;
                        const auto ids = selected(result);
                        require(std::includes(ids.begin(), ids.end(), previous.begin(), previous.end()), "optional cap sets are not nested");
                        unsigned optional_selected = 0;
                        std::set<int> optional_ranks;
                        for (const auto& d : result.admission.decisions) {
                            if (d.mandatory) { mandatory_seen += d.selected; continue; }
                            require(optional_ranks.insert(d.rank).second, "duplicate optional rank");
                            require(d.selected == (static_cast<unsigned>(d.rank) < cap), "cap did not choose fixed rank prefix");
                            optional_selected += d.selected; dropped_seen += !d.selected;
                            if (ranks.contains(d.slot_id)) require(ranks[d.slot_id] == d.rank, "ranking changed after observing a candidate");
                            ranks[d.slot_id] = d.rank;
                        }
                        if (!optional_ranks.empty())
                            require(*optional_ranks.begin() == 0 && *optional_ranks.rbegin() == static_cast<int>(optional_ranks.size()) - 1,
                                    "optional ranks are not a contiguous zero-based order");
                        require(optional_selected <= cap, "optional cap exceeded");
                        previous = ids;
                    }
                }
        require(cases == 36 && variants == 144 && mandatory_seen && dropped_seen, "incomplete matched corpus or unexercised semantics");
    });

    test("all-offer wrapper reproduces exact full C across all 36 matched cases", [] {
        for (const auto& fn : fixture_names())
            for (const auto* pn : {"sparse_regular", "branching_irregular", "dense_cohesive"})
                for (auto seed : {605ULL, 1701ULL}) {
                    const auto f = fixture(fn); const auto p = profile(pn);
                    const auto prepared = prepare_admission(f, p, seed, "full-equivalence");
                    AdmissionPolicy policy; policy.mode = AdmissionMode::Full;
                    const auto actual = negotiate_admission(prepared, policy);
                    const auto expected = negotiate(f, p, seed, "full-equivalence", false, false, false);
                    check(prepared, actual);
                    require(actual.candidate.digest == expected.digest && actual.candidate.cells == expected.cells &&
                            actual.candidate.mosaic.result.digest == expected.mosaic.result.digest &&
                            actual.candidate.mosaic.categories == expected.mosaic.categories,
                            "all-offer selection changed full-C behavior or receipt");
                }
    });

    test("nested admission replay and reverse preparation/evaluation order", [] {
        for (const auto& fn : fixture_names()) {
            const auto f = fixture(fn); const auto p = profile("branching_irregular");
            const auto forward = prepare_admission(f, p, 605, "admission-replay");
            const auto reverse = prepare_admission(f, p, 605, "admission-replay", true);
            require(forward.ranking_digest == reverse.ranking_digest, "ranking depends on evaluation order");
            for (auto cap : {0U, 1U, 2U, 4U}) {
                const auto a = negotiate_admission(forward, cap_policy(cap));
                const auto b = negotiate_admission(forward, cap_policy(cap));
                const auto c = negotiate_admission(reverse, cap_policy(cap), true);
                require(a.digest == b.digest && a.digest == c.digest && a.candidate.cells == c.candidate.cells &&
                        a.admission.selected_ids == c.admission.selected_ids, "replay/reverse changed admission result");
            }
        }
    });

    test("leave-one-out diagnoses every optional offer in original full-C failures only", [] {
        unsigned omissions = 0;
        for (const auto& fn : fixture_names())
            for (const auto* pn : {"sparse_regular", "branching_irregular", "dense_cohesive"})
                for (auto seed : {605ULL, 1701ULL}) {
                    const auto f = fixture(fn); const auto p = profile(pn);
                    const auto prepared = prepare_admission(f, p, seed, "leave-one-out");
                    const auto full = negotiate(f, p, seed, "leave-one-out", false, false, false);
                    if (full.mosaic.result.status == Status::Complete) continue;
                    for (const auto& slot : full.frame.slots) {
                        if (slot.required || slot.hard) continue;
                        const auto result = negotiate_admission(prepared, drop_policy(slot.id));
                        check(prepared, result);
                        const auto ids = selected(result);
                        require(ids.size() + 1 == full.frame.slots.size() && !ids.contains(slot.id), "LOO omitted more or less than one optional slot");
                        ++omissions;
                    }
                }
        require(omissions > 0, "no registered failure LOO diagnostics exercised");
    });

    test("malformed policies and removal of mandatory conditions are rejected before solving", [] {
        const auto prepared = prepare_admission(fixture("stepped_diagonal"), profile("branching_irregular"), 605, "admission-invalid");
        const auto invalid = [&](const AdmissionPolicy& policy) {
            const auto result = negotiate_admission(prepared, policy);
            require(result.admission.status == Status::Invalid && result.candidate.mosaic.attempts.empty(), "invalid selection reached solver");
        };
        invalid(cap_policy(9)); invalid(drop_policy(0));
        std::uint32_t absent = 1;
        while (std::any_of(prepared.prepared.frame.slots.begin(), prepared.prepared.frame.slots.end(), [&](const auto& s) { return s.id == absent; })) ++absent;
        invalid(drop_policy(absent));
        AdmissionPolicy contradictory = cap_policy(1); contradictory.omitted_optional_id = absent; invalid(contradictory);
        AdmissionPolicy unknown; unknown.mode = static_cast<AdmissionMode>(99); invalid(unknown);
        bool mandatory_tested = false;
        for (const auto& slot : prepared.prepared.frame.slots) if (slot.required || slot.hard) { invalid(drop_policy(slot.id)); mandatory_tested = true; }
        require(mandatory_tested, "mandatory removal negative fixture lost its condition");
        for (auto ceiling : {1ULL, 1'000'000ULL, 4'000'001ULL, 3'000'000ULL}) {
            const auto result = negotiate_admission(prepared, cap_policy(0), false, false, ceiling);
            require(result.admission.status == Status::Invalid && result.candidate.mosaic.attempts.empty(), "diagnostic enlarged/evaded lower-only ceiling");
        }
    });

    test("malformed frozen reservation sets are rejected before solving", [] {
        const auto original = prepare_admission(fixture("island"), profile("branching_irregular"), 605, "admission-invalid-set");
        require(!original.prepared.frame.slots.empty() && original.prepared.frame.slots.size() < max_transition_slots,
                "negative fixture needs nonempty slots below cap");
        for (auto mode : {0, 1, 2, 3, 4, 5}) {
            auto malformed = original;
            if (mode == 0) while (malformed.prepared.frame.slots.size() <= max_transition_slots)
                malformed.prepared.frame.slots.push_back(malformed.prepared.frame.slots.front());
            if (mode == 1) malformed.prepared.frame.slots.push_back(malformed.prepared.frame.slots.front());
            if (mode == 2) { malformed.prepared.frame.slots.front().required = true; malformed.prepared.frame.slots.front().hard = false; }
            if (mode == 3) malformed.prepared.mosaic_request.protected_void.front() ^= 1;
            if (mode == 4) malformed.prepared.mosaic_request.limits.max_solver_work += 1;
            if (mode == 5) {
                // Mutate both mutually checked material snapshots at a cell
                // outside exported sockets. Shape checks alone cannot detect
                // this: the true input digest must reject the altered bytes.
                bool changed = false;
                auto& frame = malformed.prepared.frame;
                for (std::size_t i = 0; i < frame.result.cells.size() && !changed; ++i) {
                    if (frame.result.cells[i] == cybersand::Material::Empty) continue;
                    const Point point{static_cast<int>(i % frame.result.width), static_cast<int>(i / frame.result.width)};
                    const bool exported = std::any_of(frame.slots.begin(), frame.slots.end(), [&](const auto& slot) {
                        const auto points = line(slot.a, slot.b);
                        return std::find(points.begin(), points.end(), point) != points.end();
                    });
                    if (exported) continue;
                    frame.result.cells[i] = cybersand::Material::Empty;
                    malformed.prepared.mosaic_request.neighbor_cells[i] = cybersand::Material::Empty;
                    changed = true; // deliberately leave cached Result digests untouched
                }
                require(changed, "negative fixture lacks non-socket frame material");
            }
            const auto result = negotiate_admission(malformed, cap_policy(1));
            require(result.admission.status == Status::Invalid && result.candidate.mosaic.attempts.empty(), "malformed frame reservations reached solver");
        }
    });

    test("equal-first-budget diagnostic keeps ranking/frame/selection fixed and lowers only solver ceiling", [] {
        unsigned diagnostic_count = 0;
        for (const auto& fn : fixture_names()) {
            const auto f = fixture(fn); const auto p = profile("branching_irregular");
            const auto prepared = prepare_admission(f, p, 605, "budget-diagnostic");
            const auto full = negotiate(f, p, 605, "budget-diagnostic", false, false, false);
            if (full.mosaic.result.status == Status::Complete || first_invoked_limit(full.mosaic) != 2'000'000) continue;
            for (auto cap : {0U, 1U, 2U, 4U}) {
                const auto primary = negotiate_admission(prepared, cap_policy(cap));
                if (primary.candidate.mosaic.result.status != Status::Complete || first_invoked_limit(primary.candidate.mosaic) != 4'000'000) continue;
                const auto diagnostic = negotiate_admission(prepared, cap_policy(cap), false, false, 2'000'000);
                check(prepared, diagnostic);
                require(diagnostic.admission.diagnostic && diagnostic.admission.selected_ids == primary.admission.selected_ids &&
                        same_request(primary.candidate.mosaic_request, diagnostic.candidate.mosaic_request, false),
                        "budget diagnostic changed admission or other request fields");
                require(first_invoked_limit(diagnostic.candidate.mosaic) == 2'000'000, "diagnostic did not match original first budget");
                ++diagnostic_count;
            }
        }
        if (diagnostic_count == 0) {
            // A research test must not require the hypothesis to win. Exercise
            // lower-only budgeting even when no registered recovery triggers it;
            // this fallback probe is not emitted as experimental evidence.
            const auto prepared = prepare_admission(fixture("island"), profile("branching_irregular"), 605, "budget-api-probe");
            const auto primary = negotiate_admission(prepared, cap_policy(0));
            const auto diagnostic = negotiate_admission(prepared, cap_policy(0), false, false, 2'000'000);
            check(prepared, diagnostic);
            require(diagnostic.admission.diagnostic && diagnostic.admission.selected_ids == primary.admission.selected_ids,
                    "lower-only diagnostic changed selection");
        }
    });

    std::cout << "ADMISSION TESTS " << passed << " passed, " << failed << " failed\n";
    return failed ? 1 : 0;
}
