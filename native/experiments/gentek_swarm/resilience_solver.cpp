#include "resilience_solver.hpp"

#include <algorithm>
#include <set>

namespace cybersand::gentek_swarm {
namespace spatial = generation::spatial;

const char* name(SolveSchedule value) noexcept {
    switch (value) {
    case SolveSchedule::Original: return "original";
    case SolveSchedule::BalancedRecovery: return "balanced-recovery";
    case SolveSchedule::PreferredHeavy: return "preferred-heavy";
    case SolveSchedule::FallbackHeavy: return "fallback-heavy";
    case SolveSchedule::SinglePreferred: return "single-preferred";
    }
    return "invalid";
}

namespace {
bool canonical_ids(const std::vector<std::uint32_t>& ids) {
    return ids.size() <= max_transition_slots && std::is_sorted(ids.begin(), ids.end()) &&
        std::adjacent_find(ids.begin(), ids.end()) == ids.end() &&
        std::none_of(ids.begin(), ids.end(), [](auto id) { return id == 0; });
}
std::uint16_t compose(const DomainDecision& decision, const std::vector<std::uint32_t>& optional) {
    auto domain = decision.original_domain;
    const auto retained = [&](const DomainInfluence& influence) {
        return influence.hard || std::binary_search(optional.begin(), optional.end(), influence.slot_id);
    };
    for (const auto& influence : decision.influences)
        if (retained(influence)) domain |= influence.compatible_domain;
    for (const auto& influence : decision.influences)
        if (retained(influence)) domain &= influence.compatible_domain;
    return domain;
}
} // namespace

std::shared_ptr<const spatial::PreparedRegions> solve_mosaic_resilient(
    const Request& req, Result& result, MosaicPlan& plan,
    const spatial::RegionAssignment& definition, const ResilienceSolvePolicy& policy,
    ResilienceSolverTrace& trace) {
    const auto fail = [&](Status status, const std::string& reason) {
        result.status = status; result.termination = reason;
        return std::shared_ptr<const spatial::PreparedRegions>{};
    };
    if (static_cast<unsigned>(policy.schedule) > static_cast<unsigned>(SolveSchedule::SinglePreferred) ||
        req.gentek != Kind::Mosaic || req.limits.max_solver_work > 4'000'000 ||
        definition.seed != req.seed || definition.width == 0 || definition.width > 16 ||
        definition.height == 0 || definition.height > 16 || definition.categories.empty() ||
        definition.categories.size() > 16 || definition.wrap_x || definition.wrap_y)
        return fail(Status::Invalid, "invalid bounded MOSAIC resilience solver policy or definition");
    const auto count = static_cast<std::size_t>(definition.width) * definition.height;
    if (definition.domains.size() != count || plan.domains.size() != count ||
        policy.fallback_domains.size() != count || plan.responses.size() > max_transition_slots || !plan.attempts.empty() ||
        trace.width != 0 || trace.height != 0 || !trace.attempts.empty() ||
        !canonical_ids(policy.primary_optional_ids) || !canonical_ids(policy.fallback_optional_ids) ||
        !std::includes(policy.primary_optional_ids.begin(), policy.primary_optional_ids.end(),
                       policy.fallback_optional_ids.begin(), policy.fallback_optional_ids.end()))
        return fail(Status::Invalid, "malformed or reused resilience domain/attempt receipts");
    std::size_t influence_count = 0;
    for (const auto& decision : plan.domains) {
        if (decision.influences.size() > max_transition_slots)
            return fail(Status::Invalid, "unbounded resilience domain influence receipt");
        influence_count += decision.influences.size();
    }
    if (influence_count > max_transition_slots)
        return fail(Status::Invalid, "resilience influence IDs exceed the original eight reservations");
    if (req.limits.max_bytes < spatial::kRegionSolverScratchBytes + count * 128U)
        return fail(Status::Exhausted, "resilience solver receipt and fixed scratch memory bound");

    // Finite receipt validation/copy reserve, before copying any domain arrays.
    const auto before = result.work;
    const auto preparation = UINT64_C(256) + count * 32U + influence_count * 64U + definition.categories.size() * 32U;
    if (!charge(req, result, preparation)) {
        trace.preparation_work = result.work - before;
        return {};
    }
    trace.preparation_work = result.work - before;
    trace.width = definition.width; trace.height = definition.height; trace.seed = definition.seed;
    trace.aggregate_limit = req.limits.max_solver_work;
    trace.category_ids = definition.categories; trace.adjacency = definition.adjacency;
    trace.primary_optional_ids = policy.primary_optional_ids;
    trace.fallback_optional_ids = policy.fallback_optional_ids;
    const auto mask = static_cast<std::uint16_t>((UINT32_C(1) << definition.categories.size()) - 1U);
    std::set<std::uint32_t> seen;
    std::vector<std::uint32_t> actual_optional;
    bool soft = false;
    for (std::size_t i = 0; i < count; ++i) {
        const auto& decision = plan.domains[i];
        if (decision.tile != i || decision.original_domain == 0 ||
            (decision.original_domain & static_cast<std::uint16_t>(~mask)) != 0 ||
            decision.selected != -1 || decision.fallback ||
            decision.modified_domain != decision.preferred_domain ||
            definition.domains[i] != decision.preferred_domain)
            return fail(Status::Invalid, "domain receipt does not match its original/preferred logical tile");
        for (const auto& influence : decision.influences) {
            if (!influence.admitted || influence.slot_id == 0 || influence.compatible_domain == 0 ||
                (influence.compatible_domain & static_cast<std::uint16_t>(~mask)) != 0 ||
                !seen.insert(influence.slot_id).second)
                return fail(Status::Invalid, "invalid or duplicate admitted native influence receipt");
            if (!influence.hard) actual_optional.push_back(influence.slot_id);
        }
        if (compose(decision, {}) != decision.hard_domain ||
            compose(decision, policy.primary_optional_ids) != decision.preferred_domain ||
            compose(decision, policy.fallback_optional_ids) != policy.fallback_domains[i])
            return fail(Status::Invalid, "resilience attempt masks do not preserve their declared hard/optional influences");
        soft = soft || decision.preferred_domain != decision.hard_domain;
    }
    std::sort(actual_optional.begin(), actual_optional.end());
    if (!std::includes(policy.primary_optional_ids.begin(), policy.primary_optional_ids.end(),
                       actual_optional.begin(), actual_optional.end()))
        return fail(Status::Invalid, "optional selection receipt omits a domain-affecting native influence");
    for (const auto id : policy.primary_optional_ids) {
        if (std::binary_search(actual_optional.begin(), actual_optional.end(), id)) continue;
        // Full forwarding retains declared optional authority even when native
        // geometry found no face. That is a known non-influencing offer, not
        // permission to invent a domain constraint or an arbitrary identifier.
        const auto response = std::find_if(plan.responses.begin(), plan.responses.end(),
            [&](const auto& value) { return value.slot_id == id; });
        if (response == plan.responses.end() || response->admitted || response->compatible_domain != 0)
            return fail(Status::Invalid, "optional selection receipt invents an ID or omits its admitted native influence");
    }

    auto assignment = definition;
    std::shared_ptr<const spatial::PreparedRegions> prepared;
    result.metrics["solver_attempted"] = 0;
    result.metrics["solver_work_observed"] = 1;
    result.metrics["solver_work_upper_bound"] = 0;
    result.solver_work = 0;
    plan.categories.assign(count, -1);
    std::uint64_t first = req.limits.max_solver_work, reserve = 0;
    if (soft && policy.schedule != SolveSchedule::SinglePreferred) {
        switch (policy.schedule) {
        case SolveSchedule::Original: case SolveSchedule::BalancedRecovery: first /= 2; break;
        case SolveSchedule::PreferredHeavy: first = first * 3 / 4; break;
        case SolveSchedule::FallbackHeavy: first /= 4; break;
        case SolveSchedule::SinglePreferred: break;
        }
        reserve = req.limits.max_solver_work - first;
    }
    trace.allocated_limit = first + reserve;
    const auto attempt = [&](bool fallback, std::uint64_t limit, const std::string& trigger) {
        ResilienceAttempt receipt;
        receipt.fallback = fallback; receipt.trigger = trigger;
        receipt.optional_ids = fallback ? policy.fallback_optional_ids : policy.primary_optional_ids;
        receipt.domains = fallback ? policy.fallback_domains : definition.domains;
        assignment.domains = receipt.domains;
        for (std::size_t i = 0; i < count; ++i) {
            plan.domains[i].modified_domain = receipt.domains[i];
            plan.domains[i].fallback = fallback;
        }
        auto& solver = receipt.solver;
        solver.work_limit = limit;
        solver.policy = fallback ? "reserved-fallback" : (soft ? "preferred-domains" : "hard-or-unoffered-domains");
        if (std::any_of(receipt.domains.begin(), receipt.domains.end(), [](auto domain) { return domain == 0; })) {
            solver.status = Status::Unsat; solver.work_observed = true;
            solver.reason = "explicit empty domain intersection; GEN-003 not invoked";
        } else if (limit == 0) {
            solver.status = Status::Exhausted; solver.work_observed = true;
            solver.reason = "zero predeclared categorical allocation; GEN-003 not invoked";
        } else {
            solver.attempted = true;
            ++result.metrics["solver_attempted"];
            trace.attempted_limit += limit;
            result.metrics["solver_work_upper_bound"] += limit;
            try {
                prepared = spatial::PreparedRegions::compile(assignment, {limit, spatial::kRegionSolverScratchBytes});
                solver.status = Status::Complete; solver.work_observed = true;
                solver.work = prepared->preparation_work();
                solver.reason = "unchanged GEN-003 completed with this predeclared domain set and allocation";
                for (auto category : prepared->cells()) {
                    const auto found = std::find(definition.categories.begin(), definition.categories.end(), category);
                    receipt.categories.push_back(static_cast<int>(found - definition.categories.begin()));
                }
            } catch (const spatial::RegionAssignmentUnsatisfiable& error) {
                solver.status = Status::Unsat; solver.reason = error.what();
            } catch (const spatial::RegionAssignmentExhausted& error) {
                solver.status = Status::Exhausted; solver.reason = error.what();
            } catch (const std::invalid_argument& error) {
                solver.status = Status::Invalid; solver.reason = error.what();
            }
        }
        result.solver_work += solver.work;
        result.metrics["solver_work_observed"] &= static_cast<std::uint64_t>(solver.work_observed);
        if (solver.status != Status::Complete) receipt.categories.assign(count, -1);
        plan.attempts.push_back(solver);
        const auto status = solver.status;
        trace.attempts.push_back(std::move(receipt));
        return status;
    };
    auto status = attempt(false, first, "initial predeclared attempt");
    const auto initial = status;
    const bool retry = soft && policy.schedule != SolveSchedule::SinglePreferred &&
        (status == Status::Unsat || (status == Status::Exhausted && policy.schedule != SolveSchedule::Original));
    if (retry) {
        trace.fallback_used = true;
        status = attempt(true, reserve, initial == Status::Unsat ? "preferred attempt proved UNSAT" : "preferred attempt exhausted; satisfiability remains unknown");
        ++result.metrics[initial == Status::Unsat ? "soft_preference_unsat_fallback" : "soft_preference_exhausted_fallback"];
    }
    if (status == Status::Complete) {
        result.status = Status::Complete;
        result.metrics["solver_successful_attempt_work"] = prepared->preparation_work();
        plan.categories = trace.attempts.back().categories;
        for (std::size_t i = 0; i < count; ++i) plan.domains[i].selected = plan.categories[i];
        result.termination = "predeclared bounded resilience schedule completed";
        return prepared;
    }
    // Offer removal is nonmonotone: it can remove native categories added by
    // the offer. A fallback UNSAT proof cannot erase an earlier unknown result.
    if (status != Status::Invalid && (initial == Status::Exhausted || status == Status::Exhausted))
        status = Status::Exhausted;
    result.status = status;
    result.termination = status == Status::Exhausted ?
        "configured domain sets remain unknown after bounded exhaustion; a later nonmonotone fallback does not prove the preferred problem UNSAT" :
        (status == Status::Unsat ? "all attempted predeclared domain sets proved UNSAT" : trace.attempts.back().solver.reason);
    result.notes.push_back("No partial categorical assignment is rasterised; failed donor work is unavailable, not fabricated.");
    return {};
}

} // namespace cybersand::gentek_swarm
