#include "reciprocal_mosaic.hpp"

#include <algorithm>
#include <atomic>
#include <functional>
#include <iostream>
#include <stdexcept>

using namespace cybersand;
using namespace cybersand::gentek_swarm;
using namespace cybersand::gentek_swarm::assembly004;

namespace {
std::uint64_t checks = 0;
void require(bool condition, const std::string& message) {
    ++checks;
    if (!condition) throw std::runtime_error(message);
}
struct Case {
    Fixture fixture;
    Request request;
    FramePlan frame;
};
Case make_case(const char* fixture_name = "stepped_diagonal", const char* profile_name = "branching_irregular",
               std::uint64_t seed = 605) {
    Case out;
    out.fixture = fixture(fixture_name);
    const auto parameters = profile(profile_name);
    const auto frame_request = request_for(out.fixture, Kind::Frameweaver, 0, parameters, seed, "swarm004-mosaic-tests");
    out.request = request_for(out.fixture, Kind::Mosaic, 1, parameters, seed, "swarm004-mosaic-tests");
    out.frame = plan_frameweaver(frame_request, out.request);
    return out;
}
void audit(const Case& c, const MosaicRevision& revision) {
    const auto& result = revision.plan.result;
    require(revision.status != MosaicRevisionStatus::Invalid, revision.reason);
    require(revision.wrapper_work + revision.generator_work <= 2'000'000, "aggregate generator debit exceeds contract");
    require(revision.solver_debit <= 4'000'000, "categorical debit exceeds contract");
    require(revision.request.seed == c.request.seed, "MOSAIC changed seed identity");
    require(result.protected_violations == 0 && result.illegal_overlaps == 0, "native masonry violates protected space");
    for (std::size_t i = 0; i < result.cells.size(); ++i) {
        if (result.cells[i] == Material::Empty) continue;
        require(c.frame.result.cells[i] == Material::Empty, "MOSAIC rewrote immutable peer material");
        require(!c.fixture.protected_void[i] && c.fixture.context[i] == Material::Empty, "MOSAIC rewrote immutable environment");
        require(revision.request.eligible[i] != 0, "masonry escaped its own proposed claim mask");
        require(result.provenance[i] != 0, "material has no authored motif identity");
    }
    for (const auto& slot : c.frame.slots) if (slot.required || slot.hard) {
        require(std::find(revision.trace.primary_selected_ids.begin(), revision.trace.primary_selected_ids.end(), slot.id) !=
            revision.trace.primary_selected_ids.end(), "required FRAME reservation was softened or omitted");
    }
    for (const auto& change : revision.geometry_changes)
        require(change.before != change.after, "provenance-only change falsely counted as native geometry revision");
    for (const auto& change : revision.provenance_changes)
        require(change.before == change.after && change.before_part != change.after_part, "invalid provenance-only revision");
}
} // namespace

int main() {
    unsigned passed = 0, failed = 0;
    const auto test = [&](const char* label, const std::function<void()>& run) {
        try { run(); ++passed; std::cout << "PASS " << label << '\n'; }
        catch (const std::exception& e) { ++failed; std::cerr << "FAIL " << label << ": " << e.what() << '\n'; }
    };
    test("empty shared zone preserves the unchanged E8 native solve, categories and hard obligations", [] {
        auto c = make_case();
        auto direct_request = c.request;
        direct_request.neighbor_cells = c.frame.result.cells;
        direct_request.neighbors = c.frame.result.boundary;
        ResilienceTrace direct_trace;
        const ResilienceOptions e8{ResilienceAdmission::CompatibilityFour, SolveSchedule::SinglePreferred,
            ResilienceFallback::NativeCore, ReceiverPolicy::RequiredOriginalNative, 8};
        const auto direct = negotiate_mosaic_resilient(direct_request, c.frame.slots, e8, direct_trace);
        const auto immutable_cells = c.frame.result.cells;
        MosaicBudget budget;
        const auto revised = propose_mosaic_revision(c.request, c.frame.result, c.frame.slots, {}, budget, 1);
        audit(c, revised);
        require(revised.plan.result.cells == direct.result.cells, "wrapper changed E8 native geometry without a shared zone");
        require(revised.plan.categories == direct.categories, "wrapper changed E8 category selection");
        require(revised.trace.final_authorized_ids == direct_trace.final_authorized_ids, "wrapper changed hard authority");
        require(c.frame.result.cells == immutable_cells, "MOSAIC mutated the peer proposal");
        require(budget.proposals_remaining == 4, "proposal was not charged once");
        require(budget.generator_remaining + revised.wrapper_work + revised.generator_work == 2'000'000,
            "generator debit does not reconcile");
        require(budget.solver_remaining + revised.solver_debit == 4'000'000, "solver debit does not reconcile");
    });
    test("same-mask no-offer controls distinguish authored category and native geometry revisions", [] {
        std::uint64_t changed_cases = 0, changed_cells = 0, changed_categories = 0;
        // Fixed development witnesses, not holdout selection or a best-of-N
        // runtime policy. Every case, including UNSAT, is inspected and counted.
        for (const auto* fixture_name : {"stepped_diagonal", "concave_intrusion", "island"}) {
            const auto c = make_case(fixture_name);
            MosaicBudget no_offer_budget;
            const auto initial = propose_mosaic_revision(c.request, c.frame.result, {}, {}, no_offer_budget, 0);
            require(initial.status != MosaicRevisionStatus::Invalid, initial.reason);
            MosaicBudget budget;
            const auto revised = propose_mosaic_revision(c.request, c.frame.result, c.frame.slots, {}, budget, 1,
                &initial.plan.result, &initial.plan.categories);
            audit(c, revised);
            require(initial.request.eligible == revised.request.eligible, "no-offer comparison changed territory");
            require(initial.request.neighbor_cells == revised.request.neighbor_cells, "no-offer comparison changed peer native cells");
            if (initial.status == MosaicRevisionStatus::Complete && revised.status == MosaicRevisionStatus::Complete) {
                changed_cases += !revised.geometry_changes.empty() && !revised.category_changes.empty();
                changed_cells += revised.geometry_changes.size();
                changed_categories += revised.category_changes.size();
            }
        }
        require(changed_cases > 0 && changed_cells > 0 && changed_categories > 0,
            "registered witnesses did not establish a real same-mask authored masonry response");
    });
    test("shared-zone responses preserve context, protected passages and independent ownership", [] {
        for (const auto* fixture_name : {"protected_corridor", "foreign_solid", "narrow_neck"}) {
            const auto c = make_case(fixture_name, "sparse_regular", 1701);
            MosaicBudget budget;
            const auto revised = propose_mosaic_revision(c.request, c.frame.result, c.frame.slots,
                c.fixture.transition, budget, 1);
            audit(c, revised);
            for (std::size_t i = 0; i < revised.plan.result.cells.size(); ++i)
                require(revised.plan.result.cells[i] == Material::Empty || c.request.eligible[i] || c.fixture.transition[i],
                    "masonry claimed unrelated foreign territory");
        }
    });
    test("reverse input offer order preserves material, categories, receipts and charged work", [] {
        const auto c = make_case("concave_intrusion", "dense_cohesive", 1701);
        MosaicBudget a_budget, b_budget;
        const auto a = propose_mosaic_revision(c.request, c.frame.result, c.frame.slots, {}, a_budget, 1);
        auto reversed = c.frame.slots;
        std::reverse(reversed.begin(), reversed.end());
        const auto b = propose_mosaic_revision(c.request, c.frame.result, reversed, {}, b_budget, 1);
        require(a.status == b.status && a.plan.result.cells == b.plan.result.cells && a.plan.categories == b.plan.categories,
            "offer order changed native proposal");
        require(a.plan.result.digest == b.plan.result.digest && a.trace.final_authorized_ids == b.trace.final_authorized_ids,
            "offer order changed semantic receipt");
        require(a_budget.generator_remaining == b_budget.generator_remaining && a_budget.solver_remaining == b_budget.solver_remaining,
            "offer order changed resource debit");
    });
    test("all rounds share one allowance and unknown failed donor work cannot be recovered", [] {
        bool unknown_failure_seen = false;
        for (const auto* fixture_name : {"stepped_diagonal", "concave_intrusion", "island"}) {
            const auto c = make_case(fixture_name);
            MosaicBudget budget;
            std::uint64_t work = 0, solver = 0;
            for (std::uint32_t round = 0; round <= 4; ++round) {
                const auto revision = propose_mosaic_revision(c.request, c.frame.result, c.frame.slots, {}, budget, round);
                work += revision.wrapper_work + revision.generator_work;
                solver += revision.solver_debit;
                require(work + budget.generator_remaining == 2'000'000, "aggregate work drifted across revisions");
                require(solver + budget.solver_remaining == 4'000'000, "aggregate solver work drifted across revisions");
                if (!revision.solver_work_observed) {
                    unknown_failure_seen = true;
                    for (const auto& attempt : revision.plan.attempts)
                        if (attempt.attempted && !attempt.work_observed)
                            require(revision.solver_debit >= attempt.work_limit, "unknown failed work was returned to budget");
                }
            }
        }
        require(unknown_failure_seen, "fixed negative witnesses did not exercise unavailable failed solver work");
    });
    test("hard-only ablation retains every required reservation and uses zero optional capacity", [] {
        const auto c = make_case();
        MosaicBudget budget;
        const auto revision = propose_mosaic_revision(c.request, c.frame.result, c.frame.slots, {}, budget, 1, nullptr, nullptr, false);
        audit(c, revision);
        require(revision.trace.admission.optional_capacity == 0, "hard-only path still admitted optional offers");
        for (const auto id : revision.trace.primary_selected_ids) {
            const auto slot = std::find_if(c.frame.slots.begin(), c.frame.slots.end(), [&](const auto& value) { return value.id == id; });
            require(slot != c.frame.slots.end() && (slot->required || slot->hard), "hard-only path invented optional authority");
        }
    });
    test("opt-in native bearings change only authored Stone material and keep solved motif footprints", [] {
        std::uint64_t changed = 0;
        for (const auto* fixture_name : {"stepped_diagonal", "concave_intrusion", "island"}) {
            const auto c = make_case(fixture_name);
            const auto original_peer = c.frame.result.cells;
            MosaicBudget plain_budget, bearing_budget;
            const auto plain = propose_mosaic_revision(c.request, c.frame.result, c.frame.slots, {}, plain_budget, 1);
            const auto bearing = propose_mosaic_revision(c.request, c.frame.result, c.frame.slots, {}, bearing_budget, 1,
                nullptr, nullptr, true, true);
            require(bearing.status == plain.status, "bearing variant changed solvability in finite witness");
            require(bearing.plan.categories == plain.plan.categories && bearing.trace.final_authorized_ids == plain.trace.final_authorized_ids,
                "material variant altered GEN-003 categories or slot authority");
            require(bearing.plan.result.cells.size() == plain.plan.result.cells.size(), "bearing changed native canvas");
            require(bearing.plan.result.instances.size() == plain.plan.result.instances.size() &&
                bearing.plan.result.provenance == plain.plan.result.provenance, "material variant invented a part or changed ownership");
            std::uint64_t material_changes = 0;
            for (std::size_t i = 0; i < plain.plan.result.cells.size(); ++i) {
                const auto before = plain.plan.result.cells[i], after = bearing.plan.result.cells[i];
                require((before == Material::Empty) == (after == Material::Empty), "bearing material variant changed occupied footprint");
                if (before != after) {
                    ++material_changes;
                    require(before == Material::Stone && after == Material::LimestoneBlock, "unauthored bearing material conversion");
                    const auto witness = std::find_if(bearing.bearing_replacements.begin(), bearing.bearing_replacements.end(), [&](const auto& receipt) {
                        return index(c.request, receipt.point) == i && receipt.instance == bearing.plan.result.provenance[i] &&
                            receipt.before == before && receipt.after == after && receipt.rule == "swarm004/mosaic_native_bearing_v1";
                    });
                    require(witness != bearing.bearing_replacements.end(), "bearing replacement lacks exact rule/part/cell receipt");
                    require(allowed(bearing.request, witness->point), "bearing escaped existing allowed motif territory");
                }
            }
            require(material_changes == bearing.bearing_replacements.size(), "bearing receipts duplicate or omit changed native cells");
            require(bearing_budget.generator_remaining + bearing.wrapper_work + bearing.generator_work == 2'000'000,
                "bearing debit not included in aggregate generator allowance");
            require(bearing.solver_debit == plain.solver_debit, "material variant changed categorical work");
            require(c.frame.result.cells == original_peer, "bearing response modified immutable FRAME cells");
            if (material_changes) {
                changed += material_changes;
                require(bearing.bearing_work > 0 && bearing.plan.result.material_digest != plain.plan.result.material_digest,
                    "bearing work or native material fingerprint stale");
                auto reversed = c.frame.slots;
                std::reverse(reversed.begin(), reversed.end());
                MosaicBudget reverse_budget;
                const auto reverse = propose_mosaic_revision(c.request, c.frame.result, reversed, {}, reverse_budget, 1,
                    nullptr, nullptr, true, true);
                require(reverse.plan.result.digest == bearing.plan.result.digest && reverse_budget.generator_remaining == bearing_budget.generator_remaining,
                    "bearing response depends on offer evaluation order");
                MosaicBudget limited;
                limited.generator_remaining = plain.wrapper_work + plain.generator_work + 32'000;
                const auto limited_result = propose_mosaic_revision(c.request, c.frame.result, c.frame.slots, {}, limited, 1,
                    nullptr, nullptr, true, true);
                require(limited_result.status == MosaicRevisionStatus::Exhausted, "bearing fingerprint work bypassed remaining allowance");
                require(limited_result.bearing_replacements.empty() && limited_result.plan.result.cells == plain.plan.result.cells,
                    "unfunded bearing revision partially modified native cells");
            }
        }
        require(changed > 0, "fixed native witnesses did not exercise actual Stone-to-Limestone receiving material");
        const auto c = make_case();
        MosaicBudget plain_budget, bearing_budget;
        const auto plain = propose_mosaic_revision(c.request, c.frame.result, {}, {}, plain_budget, 0);
        const auto bearing = propose_mosaic_revision(c.request, c.frame.result, {}, {}, bearing_budget, 0, nullptr, nullptr, true, true);
        require(plain.plan.result.digest == bearing.plan.result.digest && bearing.bearing_work == 0 &&
            plain_budget.generator_remaining == bearing_budget.generator_remaining,
            "no-offer initial proposal paid hidden bearing work or changed material");
    });
    test("cancellation, memory, rounds and malformed proposals reject without usable output", [] {
        const auto c = make_case();
        std::atomic_bool cancelled{true};
        MosaicBudget cancelled_budget;
        cancelled_budget.cancelled = &cancelled;
        const auto cancellation = propose_mosaic_revision(c.request, c.frame.result, c.frame.slots, {}, cancelled_budget, 1);
        require(cancellation.status == MosaicRevisionStatus::Cancelled && cancellation.plan.result.cells.empty(), "cancelled geometry escaped");
        require(cancelled_budget.generator_remaining == 2'000'000 && cancelled_budget.proposals_remaining == 5, "pre-cancelled request consumed work");
        MosaicBudget memory;
        memory.max_bytes = 1;
        require(propose_mosaic_revision(c.request, c.frame.result, c.frame.slots, {}, memory, 1).status == MosaicRevisionStatus::Exhausted,
            "memory limit bypassed");
        MosaicBudget round_budget;
        require(propose_mosaic_revision(c.request, c.frame.result, c.frame.slots, {}, round_budget, 5).status == MosaicRevisionStatus::Invalid,
            "unbounded revision round admitted");
        auto damaged_request = c.request;
        damaged_request.profile.destruction = 0.5;
        MosaicBudget damaged_budget;
        require(propose_mosaic_revision(damaged_request, c.frame.result, c.frame.slots, {}, damaged_budget, 1).status == MosaicRevisionStatus::Invalid,
            "destruction silently entered reciprocal solve");
        auto malformed = c.frame.result;
        malformed.provenance.clear();
        MosaicBudget malformed_budget;
        const auto rejection = propose_mosaic_revision(c.request, malformed, c.frame.slots, {}, malformed_budget, 1);
        require(rejection.status == MosaicRevisionStatus::Invalid && rejection.plan.result.cells.empty(), "malformed peer provenance accepted");
        auto escaped_shared = c.fixture.transition;
        const auto outside = std::find(escaped_shared.begin(), escaped_shared.end(), 0);
        require(outside != escaped_shared.end(), "fixture lacks an outside-zone cell");
        *outside = 1;
        MosaicBudget mask_budget;
        require(propose_mosaic_revision(c.request, c.frame.result, c.frame.slots, escaped_shared, mask_budget, 1).status == MosaicRevisionStatus::Invalid,
            "shared claim escaped negotiated zone");
    });
    std::cout << "reciprocal MOSAIC tests: " << passed << " passed, " << failed << " failed, " << checks << " checks\n";
    return failed ? 1 : 0;
}
