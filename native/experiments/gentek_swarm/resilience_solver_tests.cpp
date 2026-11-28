#include "resilience.hpp"

#include <algorithm>
#include <functional>
#include <iostream>
#include <stdexcept>

using namespace cybersand::gentek_swarm;
namespace spatial = cybersand::generation::spatial;

namespace {
void check(bool value, const char* reason) {
    if (!value) throw std::runtime_error(reason);
}
struct Case {
    Request request;
    MosaicPlan plan;
    spatial::RegionAssignment assignment;
    ResilienceSolvePolicy policy;
    ResilienceSolverTrace trace;
};
Case problem(const std::vector<std::uint16_t>& original,
             const std::vector<std::uint16_t>& offered) {
    Case c;
    c.request.gentek=Kind::Mosaic; c.request.width=static_cast<int>(original.size())*16;c.request.height=16;
    c.assignment.width=static_cast<std::uint32_t>(original.size());c.assignment.height=1;
    c.assignment.seed=c.request.seed;c.assignment.categories={41,53};
    for (auto& direction:c.assignment.adjacency) {direction[0]=1;direction[1]=2;}
    for (std::size_t i=0;i<original.size();++i) {
        DomainDecision d;
        d.tile=static_cast<std::uint32_t>(i);d.original_domain=d.hard_domain=original[i];
        d.modified_domain=d.preferred_domain=offered[i] ? offered[i] : original[i];
        if (offered[i]) {
            const auto id=static_cast<std::uint32_t>(101+i);
            d.influences.push_back({id,offered[i],false,true,{},"synthetic native receiving preference"});
            c.policy.primary_optional_ids.push_back(id);
        }
        c.assignment.domains.push_back(d.preferred_domain);
        c.policy.fallback_domains.push_back(d.hard_domain);
        c.plan.domains.push_back(d);
    }
    return c;
}
auto solve(Case& c) {
    return solve_mosaic_resilient(c.request,c.plan.result,c.plan,c.assignment,c.policy,c.trace);
}
void unavailable_failed_work(const Case& c) {
    for (const auto& a:c.trace.attempts)
        if (a.solver.attempted && a.solver.status!=Status::Complete)
            check(!a.solver.work_observed && a.solver.work==0,"failed donor work was fabricated");
    check(c.trace.attempted_limit<=c.request.limits.max_solver_work,"aggregate invocation budget exceeded");
}
}

int main() try {
    unsigned groups=0;
    const auto run=[&](const char* label,const std::function<void()>& test) {
        test();++groups;std::cout<<"PASS "<<label<<'\n';
    };
    run("fixed schedules preserve the 4M aggregate",[]{
        for (auto schedule:{SolveSchedule::Original,SolveSchedule::BalancedRecovery,SolveSchedule::PreferredHeavy,
                            SolveSchedule::FallbackHeavy,SolveSchedule::SinglePreferred}) {
            auto c=problem({3,3},{1,2});c.policy.schedule=schedule;
            const auto solved=solve(c);
            const auto expected=schedule==SolveSchedule::PreferredHeavy ? 3'000'000ULL :
                schedule==SolveSchedule::FallbackHeavy ? 1'000'000ULL :
                schedule==SolveSchedule::SinglePreferred ? 4'000'000ULL : 2'000'000ULL;
            check(c.trace.attempts.front().solver.work_limit==expected,"wrong primary allocation");
            check(c.trace.allocated_limit==4'000'000,"allocation reserve missing");
            if (schedule==SolveSchedule::SinglePreferred) check(!solved && c.trace.attempts.size()==1,"single schedule retried");
            else {
                check(solved && c.trace.attempts.size()==2,"proven-UNSAT fallback did not solve");
                check(c.trace.attempts[1].solver.work_limit==4'000'000-expected,"fallback stole unused primary work");
                check(c.trace.attempts[0].solver.status==Status::Unsat,"preferred contradiction was not proven");
            }
            unavailable_failed_work(c);
        }
    });
    run("bounded exhaustion can recover while retaining an optional condition",[]{
        auto c=problem({1,3,3},{2,2,0});
        c.request.limits.max_solver_work=625'000;c.policy.schedule=SolveSchedule::FallbackHeavy;
        c.policy.fallback_optional_ids={101};c.policy.fallback_domains={2,3,3};
        check(solve(c)!=nullptr,"reserved fallback did not recover");
        check(c.trace.attempts.size()==2 && c.trace.attempts[0].solver.status==Status::Exhausted,"preferred did not exhaust");
        check(c.trace.attempts[1].optional_ids==std::vector<std::uint32_t>{101},"retained optional receipt missing");
        check(c.trace.attempts[1].categories==std::vector<int>({1,1,1}),"retained optional mask was not enforced");
        unavailable_failed_work(c);
    });
    run("original schedule never retries unknown preferred feasibility",[]{
        auto c=problem({1,1,1},{2,2,2});c.request.limits.max_solver_work=1;
        c.policy.schedule=SolveSchedule::Original;
        check(!solve(c) && c.plan.result.status==Status::Exhausted && c.trace.attempts.size()==1,"original retried exhaustion");
        check(!c.trace.fallback_used,"unused fallback marked used");
    });
    run("two exhausted attempts remain unknown without invented work",[]{
        auto c=problem({1,1,1},{2,2,2});c.request.limits.max_solver_work=2;c.policy.schedule=SolveSchedule::BalancedRecovery;
        check(!solve(c) && c.trace.attempts.size()==2 && c.plan.result.status==Status::Exhausted,"double exhaustion misclassified");
        unavailable_failed_work(c);
    });
    run("nonmonotone fallback UNSAT cannot erase preferred unknown",[]{
        auto c=problem({1,2,1},{2,0,2});c.request.limits.max_solver_work=625'000;c.policy.schedule=SolveSchedule::FallbackHeavy;
        check(!solve(c) && c.trace.attempts.size()==2,"missing nonmonotone attempts");
        check(c.trace.attempts[0].solver.status==Status::Exhausted && c.trace.attempts[1].solver.status==Status::Unsat,
              "adversarial exhausted/UNSAT outcomes changed");
        check(c.plan.result.status==Status::Exhausted,"fallback proof falsely classified preferred problem");
        auto witness=problem({1,2,1},{2,0,2});witness.request.limits.max_solver_work=625'000;
        witness.policy.schedule=SolveSchedule::SinglePreferred;
        check(solve(witness)!=nullptr && witness.trace.attempts[0].categories==std::vector<int>({1,1,1}),"same preferred SAT witness missing");
    });
    run("no effective optional restriction gets one full allowance",[]{
        auto c=problem({3,3},{0,0});c.policy.schedule=SolveSchedule::FallbackHeavy;
        check(solve(c)!=nullptr && c.trace.attempts.size()==1 && c.trace.attempts[0].solver.work_limit==4'000'000,
              "hard/unoffered solve incorrectly split");
    });
    run("empty preferred intersection is a truthful zero-work proof",[]{
        auto c=problem({3},{1});
        c.plan.domains[0].influences.push_back({102,2,false,true,{},"incompatible second optional response"});
        c.plan.domains[0].preferred_domain=c.plan.domains[0].modified_domain=c.assignment.domains[0]=0;
        c.policy.primary_optional_ids.push_back(102);c.policy.schedule=SolveSchedule::BalancedRecovery;
        check(solve(c)!=nullptr,"hard-only solve after explicit empty intersection failed");
        const auto& first=c.trace.attempts.front().solver;
        check(first.status==Status::Unsat && !first.attempted && first.work_observed && first.work==0,"empty mask invoked donor or invented unknown work");
    });
    run("altered hard receipt rejected before search",[]{
        auto c=problem({3,3},{1,2});c.plan.domains[0].hard_domain=2;
        check(!solve(c) && c.plan.result.status==Status::Invalid && c.trace.attempts.empty(),"tampered hard mask accepted");
    });
    run("fallback cannot introduce an unselected optional ID",[]{
        auto c=problem({3,3},{1,2});c.policy.fallback_optional_ids={999};
        check(!solve(c) && c.plan.result.status==Status::Invalid,"invented fallback optional accepted");
    });
    run("retained optional ID must actually constrain its domain",[]{
        auto c=problem({1,3,3},{2,2,0});c.policy.fallback_optional_ids={101};
        check(!solve(c) && c.plan.result.status==Status::Invalid && c.trace.attempts.empty(),"fabricated retained preference receipt accepted");
    });
    run("known geometry-unadmitted full offer retains its declared ID",[]{
        auto c=problem({3},{0});c.policy.schedule=SolveSchedule::SinglePreferred;
        c.policy.primary_optional_ids={999};
        SlotResponse missing;missing.slot_id=999;missing.reason="explicitly forwarded offer with no native receiving face";
        c.plan.responses.push_back(missing);
        check(solve(c)!=nullptr && c.trace.attempts[0].optional_ids==std::vector<std::uint32_t>{999},
              "known forwarded optional ID was silently erased");
        check(c.trace.attempts[0].domains==std::vector<std::uint16_t>{3},"geometry-unadmitted offer invented a native influence");
    });
    run("foreign optional ID without a response or influence is rejected",[]{
        auto c=problem({3},{0});c.policy.primary_optional_ids={999};
        check(!solve(c) && c.plan.result.status==Status::Invalid && c.trace.attempts.empty(),"unknown optional ID accepted");
    });
    run("unknown schedule and excessive categorical ceiling rejected",[]{
        auto c=problem({3},{1});c.policy.schedule=static_cast<SolveSchedule>(99);
        check(!solve(c) && c.plan.result.status==Status::Invalid,"unknown schedule accepted");
        auto d=problem({3},{1});d.request.limits.max_solver_work=4'000'001;
        check(!solve(d) && d.plan.result.status==Status::Invalid,"raised categorical budget accepted");
    });
    run("malformed tile order and reused attempts rejected",[]{
        auto c=problem({3,3},{1,2});c.plan.domains[0].tile=1;
        check(!solve(c) && c.plan.result.status==Status::Invalid,"repeated tile identity accepted");
        auto d=problem({3},{0});check(solve(d)!=nullptr,"initial reuse witness failed");
        check(!solve(d) && d.plan.result.status==Status::Invalid,"attempt history silently reused");
    });
    run("native bookkeeping exhaustion prevents donor invocation",[]{
        auto c=problem({3,3},{1,2});c.request.limits.max_work=1;
        check(!solve(c) && c.plan.result.status==Status::Exhausted && c.trace.attempts.empty(),"uncharged preparation reached donor");
        check(c.plan.result.work<=1,"native preparation exceeded allowance");
    });
    run("fixed scratch memory failure precedes solve",[]{
        auto c=problem({3,3},{1,2});c.request.limits.max_bytes=spatial::kRegionSolverScratchBytes-1;
        check(!solve(c) && c.plan.result.status==Status::Exhausted && c.trace.attempts.empty(),"undersized scratch entered donor");
    });
    run("deterministic replay preserves native category IDs and masks",[]{
        auto a=problem({3,3},{0,0});auto b=a;
        check(solve(a)!=nullptr && solve(b)!=nullptr,"replay failed");
        check(a.trace.attempts[0].categories==b.trace.attempts[0].categories &&
              a.trace.attempts[0].solver.work==b.trace.attempts[0].solver.work &&
              a.trace.category_ids==a.assignment.categories && a.trace.adjacency==a.assignment.adjacency,
              "seed/category/grammar or deterministic result changed");
    });
    std::cout<<"PASS resilience solver: "<<groups<<" focused groups\n";
    return 0;
} catch (const std::exception& error) {
    std::cerr<<"FAIL resilience solver: "<<error.what()<<'\n';return 1;
}
