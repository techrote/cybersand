#include "resilience.hpp"

#include <algorithm>
#include <array>
#include <functional>
#include <iostream>
#include <set>
#include <stdexcept>
#include <tuple>

using namespace cybersand::gentek_swarm;
using cybersand::Material;

namespace {
std::uint64_t assertions{};
void require(bool value,const std::string& why) {
    ++assertions;
    if(!value)throw std::runtime_error(why);
}
std::uint64_t metric(const NegotiatedResult& n,const std::string& key) {
    const auto it=n.metrics.find(key);return it==n.metrics.end()?0:it->second;
}
ResilienceOptions native(unsigned capacity=4) {
    return {ResilienceAdmission::CompatibilityFour,SolveSchedule::SinglePreferred,
            ResilienceFallback::NativeCore,ReceiverPolicy::RequiredOriginalNative,capacity};
}
ResilienceOptions hard_only() {
    return {ResilienceAdmission::CompatibilityHardOnly,SolveSchedule::SinglePreferred,
            ResilienceFallback::HardOnly,ReceiverPolicy::RequiredOriginalNative};
}
bool same_slot(const TransitionSlot& a,const TransitionSlot& b) {
    return std::tie(a.id,a.instance,a.connector,a.kind,a.a,a.b,a.facing,a.envelope.x,a.envelope.y,a.envelope.w,a.envelope.h,
                    a.clearance,a.required,a.hard,a.strength,a.owner,a.reason)==
           std::tie(b.id,b.instance,b.connector,b.kind,b.a,b.b,b.facing,b.envelope.x,b.envelope.y,b.envelope.w,b.envelope.h,
                    b.clearance,b.required,b.hard,b.strength,b.owner,b.reason);
}
void check(const PreparedAdmission& prepared,const ResilienceResult& r) {
    const auto& original=prepared.prepared;const auto& n=r.candidate;
    const auto& trace=r.trace;
    require(n.mosaic.result.status!=Status::Invalid,"valid registered experiment rejected: "+n.mosaic.result.termination);
    require(n.mosaic.result.implementation=="prepared-regions-resilience-v1","resilient result mislabeled as original C");
    require(n.frame.slots.size()==original.frame.slots.size(),"original reservation universe changed");
    require(n.frame.result.cells==original.frame.result.cells&&n.frame.core.cells==original.frame.core.cells,
            "frozen frame geometry changed");
    require(n.frame.result.digest==original.frame.result.digest&&n.frame.core.digest==original.frame.core.digest,
            "frozen frame graph/provenance changed");
    const std::set<std::uint32_t> authorized(trace.final_authorized_ids.begin(),trace.final_authorized_ids.end());
    std::set<std::uint32_t> decision_ids;
    for(const auto& decision:trace.admission.decisions)require(decision_ids.insert(decision.slot_id).second,"duplicate admission decision");
    require(decision_ids.size()==original.frame.slots.size(),"original reservation lacks an admission receipt");
    require(authorized.size()==trace.final_authorized_ids.size(),"duplicate join authority");
    require(trace.final_authorized_ids==trace.primary_selected_ids,"authority changed after categorical outcome");
    unsigned mandatory=0;
    for(const auto& slot:original.frame.slots) {
        const auto found=std::find_if(n.frame.slots.begin(),n.frame.slots.end(),[&](const auto& s){return s.id==slot.id;});
        require(found!=n.frame.slots.end()&&same_slot(slot,*found),"reservation geometry or obligation changed");
        require(decision_ids.contains(slot.id),"admission receipt uses a foreign reservation ID");
        if(slot.required||slot.hard) {
            ++mandatory;require(authorized.contains(slot.id),"hard obligation lost authority");
            require(std::find(trace.fallback_selected_ids.begin(),trace.fallback_selected_ids.end(),slot.id)!=trace.fallback_selected_ids.end(),
                    "hard obligation lost fallback authority");
        }
    }
    for(auto id:authorized)require(std::any_of(original.frame.slots.begin(),original.frame.slots.end(),
                                               [&](const auto& slot){return slot.id==id;}),"foreign authorized ID");
    const auto capacity=r.options.admission==ResilienceAdmission::Full?8U:
                        r.options.admission==ResilienceAdmission::CompatibilityHardOnly?0U:r.options.optional_capacity;
    require(authorized.size()>=mandatory&&authorized.size()-mandatory<=capacity,"optional capacity exceeded");
    require(n.mosaic_request.eligible==original.mosaic_request.eligible&&
            n.mosaic_request.protected_void==original.mosaic_request.protected_void&&
            n.mosaic_request.neighbors.protected_geometry==original.mosaic_request.neighbors.protected_geometry&&
            n.mosaic_request.context==original.mosaic_request.context&&
            n.mosaic_request.neighbor_cells==original.mosaic_request.neighbor_cells&&
            n.mosaic_request.transition==original.mosaic_request.transition,"counterfactual request masks changed");
    require(n.mosaic_request.seed==original.mosaic_request.seed,"seed changed");
    require(n.frame.result.work<=n.frame_request.limits.max_work&&n.mosaic.result.work<=n.mosaic_request.limits.max_work,
            "generator work exceeded");
    require(r.preparation_work+r.join_work_limit==2'000'000&&n.work<=r.join_work_limit,"shared work ceiling grew");
    require(n.mosaic_request.limits.max_solver_work==4'000'000&&metric(n,"candidate_charged_work_upper_bound")==10'000'000,
            "structural ceiling changed");
    require(trace.solver.attempts.size()<=2,"outcome-driven retry search");
    if(!trace.solver.attempts.empty())require(n.mosaic.result.metrics.at("resilience_solver_receipt_work")==trace.solver.preparation_work,
                                             "solver preparation charge lacks matching result metric");
    std::uint64_t limits=0;
    for(const auto& attempt:trace.solver.attempts) {
        if(attempt.solver.attempted)limits+=attempt.solver.work_limit;
        require(!attempt.solver.work_observed||attempt.solver.work<=attempt.solver.work_limit,"invalid observed work");
        require(!attempt.solver.attempted||attempt.solver.status==Status::Complete||!attempt.solver.work_observed,
                "failed donor work was fabricated");
        require(attempt.categories.size()==attempt.domains.size(),"attempt lacks a complete selected/unselected vector");
        if(attempt.solver.status!=Status::Complete)require(std::all_of(attempt.categories.begin(),attempt.categories.end(),
            [](auto category){return category==-1;}),"failed attempt exposes partial or invented categories");
        if(attempt.solver.status==Status::Complete) {
            require(attempt.categories.size()==attempt.domains.size(),"success lacks full assignment receipt");
            for(std::size_t i=0;i<attempt.categories.size();++i) {
                const auto category=attempt.categories[i];
                require(category>=0&&category<16&&(attempt.domains[i]&(1U<<category)),"category escaped attempted domain");
                const auto x=i%trace.solver.width,y=i/trace.solver.width;
                if(x+1<trace.solver.width) {
                    const auto neighbor=attempt.categories[i+1];
                    require((trace.solver.adjacency[0][category]&(1U<<neighbor))&&
                            (trace.solver.adjacency[2][neighbor]&(1U<<category)),"horizontal grammar violated");
                }
                if(y+1<trace.solver.height) {
                    const auto neighbor=attempt.categories[i+trace.solver.width];
                    require((trace.solver.adjacency[1][category]&(1U<<neighbor))&&
                            (trace.solver.adjacency[3][neighbor]&(1U<<category)),"vertical grammar violated");
                }
            }
        }
    }
    require(limits==trace.solver.attempted_limit&&limits<=4'000'000,"aggregate solver allocation exceeded");
    for(const auto* key:{"protected_violations","illegal_overlaps","frozen_core_changes","mosaic_frozen_changes"})
        require(metric(n,key)==0,key);
    require(n.cells==n.finished_cells,"unregistered residual geometry appeared");
    const auto& f=n.control.fixture;
    std::uint64_t added=0;
    for(std::size_t i=0;i<n.cells.size();++i) {
        const bool a=n.final_frame.cells[i]!=Material::Empty,b=n.final_mosaic.cells[i]!=Material::Empty;
        require(!(a&&b)&&(!a||(f.side[i]==0&&f.context[i]==Material::Empty))&&
                (!b||(f.side[i]==1&&f.context[i]==Material::Empty)),"material escaped ownership");
        require(!f.protected_void[i]||n.cells[i]==Material::Empty,"protected aperture consumed");
        require(n.frame.result.cells[i]==Material::Empty||n.frame.result.cells[i]==n.final_frame.cells[i],"frame material rewritten");
        require(n.mosaic.result.cells[i]==Material::Empty||n.mosaic.result.cells[i]==n.final_mosaic.cells[i],"native material rewritten");
        added+=a&&n.frame.result.cells[i]==Material::Empty;
        added+=b&&n.mosaic.result.cells[i]==Material::Empty;
    }
    require(added==metric(n,"candidate_posthoc_cells"),"postsolve material accounting false");
    for(const auto& original_connector:n.frame.result.connectors)if(original_connector.required) {
        const auto found=std::find_if(n.final_frame.connectors.begin(),n.final_frame.connectors.end(),
                                    [&](const auto& c){return c.id==original_connector.id&&c.instance==original_connector.instance;});
        require(found!=n.final_frame.connectors.end()&&found->required,"required connector deleted or softened");
        if(!original_connector.fulfilled&&found->fulfilled)require(std::any_of(n.frame.slots.begin(),n.frame.slots.end(),[&](const auto& s) {
            return s.connector==found->id&&s.instance==found->instance&&std::any_of(n.seams.begin(),n.seams.end(),
                [&](const auto& seam){return seam.left_affordance==s.id&&seam.joined;});
        }),"mandatory closure lacks a qualified path");
    }
    for(const auto& seam:n.seams)if(seam.joined) {
        require(authorized.contains(seam.left_affordance),"unadmitted reservation joined");
        const auto slot=std::find_if(n.frame.slots.begin(),n.frame.slots.end(),[&](const auto& s){return s.id==seam.left_affordance;});
        const auto response=std::find_if(n.mosaic.responses.begin(),n.mosaic.responses.end(),[&](const auto& s){return s.slot_id==seam.left_affordance;});
        require(slot!=n.frame.slots.end()&&response!=n.mosaic.responses.end()&&response->satisfied,"joined path lacks native response");
        require(seam.cells.size()>=2&&seam.cells.size()<=16,"joint path unbounded");
        require(seam.cells.front()==seam.a&&seam.cells.back()==seam.b&&seam.b==response->contact,"path endpoint receipt false");
        require(n.mosaic.result.cells[index(n.mosaic_request,seam.b)]!=Material::Empty,"joint endpoint is not native material");
        require(Point{seam.cells[1].x-seam.a.x,seam.cells[1].y-seam.a.y}==slot->facing,"path leaves source sideways");
        const auto prior=seam.cells[seam.cells.size()-2];
        require(Point{prior.x-seam.b.x,prior.y-seam.b.y}==response->facing,"path enters receiver sideways");
        for(std::size_t i=0;i<seam.cells.size();++i) {
            const auto p=seam.cells[i];
            require(inside(n.frame_request,p),"path escaped finite canvas");
            const auto at=index(n.frame_request,p);
            require(n.cells[at]!=Material::Empty&&f.transition[at]&&!f.protected_void[at],"path is not legal physical material");
            require(p.x>=slot->envelope.x&&p.x<slot->envelope.x+slot->envelope.w&&
                    p.y>=slot->envelope.y&&p.y<slot->envelope.y+slot->envelope.h,"path escaped immutable envelope");
            if(i)require(std::abs(p.x-seam.cells[i-1].x)+std::abs(p.y-seam.cells[i-1].y)==1,"path is disconnected");
        }
    }
}
} // namespace

int main() {
    unsigned passed=0,failed=0;
    const auto test=[&](const char* label,const auto& run) {
        try {run();++passed;std::cout<<"PASS "<<label<<'\n';}
        catch(const std::exception& e){++failed;std::cerr<<"FAIL "<<label<<": "<<e.what()<<'\n';}
    };
    test("36 known cases x E4/E6/E8/matched-hard-only: immutable geometry, bounds, native assignment and physical joints",[] {
        unsigned cases=0,complete=0,unsat=0,exhausted=0;
        std::uint64_t joints=0,late=0,open=0;
        for(const auto& fn:fixture_names())for(const auto* pn:{"sparse_regular","branching_irregular","dense_cohesive"})
            for(auto seed:{605ULL,1701ULL}) {
                const auto prepared=prepare_admission(fixture(fn),profile(pn),seed,"resilience-tests");
                require(prepared.status==Status::Complete,"known preparation invalid");
                for(const auto& options:{native(4),native(6),native(8),hard_only()}) {
                    const auto r=negotiate_resilient(prepared,options);check(prepared,r);++cases;
                    if(options.admission==ResilienceAdmission::CompatibilityFour&&options.optional_capacity==4) {
                        complete+=r.candidate.mosaic.result.status==Status::Complete;
                        unsat+=r.candidate.mosaic.result.status==Status::Unsat;
                        exhausted+=r.candidate.mosaic.result.status==Status::Exhausted;
                        joints+=metric(r.candidate,"joined_slots");late+=metric(r.candidate,"candidate_posthoc_cells");
                        open+=metric(r.candidate,"unresolved_mandatory_connectors");
                    }
                }
            }
        require(cases==144,"incomplete registered policy matrix");
        require(complete==26&&unsat==10&&exhausted==0,"reconstructed E4 completion differs from historical evidence");
        require(joints==90&&late==388&&open==68,"reconstructed E4 physical totals differ from historical evidence");
    });
    test("reverse reservation/control traversal produces identical E4/E6/E8 receipts",[] {
        for(const auto& fn:fixture_names())for(auto capacity:{4U,6U,8U}) {
            const auto prepared=prepare_admission(fixture(fn),profile("branching_irregular"),1701,"reverse-resilience");
            const auto a=negotiate_resilient(prepared,native(capacity));
            const auto b=negotiate_resilient(prepared,native(capacity),true);
            require(a.digest==b.digest&&a.candidate.cells==b.candidate.cells,"reverse traversal changed deterministic result");
        }
    });
    test("five solver schedules retain limits and mechanical authority",[] {
        const auto prepared=prepare_admission(fixture("concave_intrusion"),profile("branching_irregular"),1701,"schedule-resilience");
        for(auto schedule:{SolveSchedule::Original,SolveSchedule::BalancedRecovery,SolveSchedule::PreferredHeavy,
                           SolveSchedule::FallbackHeavy,SolveSchedule::SinglePreferred}) {
            const ResilienceOptions options{ResilienceAdmission::CompatibilityFour,schedule,
                schedule==SolveSchedule::Original?ResilienceFallback::HardOnly:ResilienceFallback::NativeCore};
            check(prepared,negotiate_resilient(prepared,options));
        }
    });
    test("36 full-forwarding cases retain every admission and optional identity even without a receiving face",[] {
        unsigned missing_faces=0;
        for(const auto& fn:fixture_names())for(const auto* pn:{"sparse_regular","branching_irregular","dense_cohesive"})
            for(auto seed:{605ULL,1701ULL}) {
                const auto prepared=prepare_admission(fixture(fn),profile(pn),seed,"full-receipt-resilience");
                const ResilienceOptions options{ResilienceAdmission::Full,SolveSchedule::SinglePreferred,ResilienceFallback::HardOnly};
                const auto r=negotiate_resilient(prepared,options);check(prepared,r);
                std::vector<std::uint32_t> optional;
                for(const auto& slot:prepared.prepared.frame.slots)if(!slot.required&&!slot.hard)optional.push_back(slot.id);
                std::sort(optional.begin(),optional.end());
                if(!r.trace.solver.attempts.empty())require(r.trace.solver.primary_optional_ids==optional,"full forwarding lost selected optional IDs");
                for(const auto& response:r.candidate.mosaic.responses)missing_faces+=!response.admitted;
            }
        require(missing_faces>0,"full identity test did not exercise unadmitted geometry");
    });
    test("required original-native receiver repairs preserve aperture and original category vocabulary",[] {
        unsigned repairs=0;
        for(const auto* pn:{"branching_irregular","dense_cohesive"}) {
            const auto prepared=prepare_admission(fixture("stepped_diagonal"),profile(pn),605,"receiver-resilience");
            const auto r=negotiate_resilient(prepared,native());check(prepared,r);
            for(const auto& decision:r.trace.receivers)if(decision.changed) {
                ++repairs;require(decision.selected_supported_domain!=0,"repaired receiver has no native support");
                require(decision.selected_contact!=decision.original_contact,"repair did not move unsupported face");
                require(std::any_of(decision.faces.begin(),decision.faces.end(),[&](const auto& face) {
                    return face.selected&&face.contact==decision.selected_contact&&face.tile==decision.selected_tile;
                }),"repair has no selected bounded face receipt");
            }
        }
        require(repairs==2,"known required-face repair witnesses differ");
    });
    test("frozen-input tampering and unregistered policies reject before donor or joins",[] {
        const auto prepared=prepare_admission(fixture("island"),profile("branching_irregular"),605,"tamper-resilience");
        const std::array<std::function<void(PreparedAdmission&)>,11> changes{{
            [](auto& p){++p.ranking_work;},
            [](auto& p){p.ranking.front().rank=123;},
            [](auto& p){p.prepared.frame.slots.front().required=false;},
            [](auto& p){p.prepared.frame.slots.front().hard=false;},
            [](auto& p){++p.prepared.frame.slots.front().a.x;},
            [](auto& p){p.prepared.frame.result.cells.front()=Material::Stone;},
            [](auto& p){p.prepared.mosaic_request.seed^=1;},
            [](auto& p){p.prepared.mosaic_request.eligible.front()^=1;},
            [](auto& p){p.prepared.mosaic_request.neighbors.protected_geometry.front()^=1;},
            [](auto& p){++p.prepared.mosaic_request.limits.max_solver_work;},
            [](auto& p){p.prepared.frame.result.connectors.front().required^=true;}
        }};
        for(const auto& change:changes) {
            auto altered=prepared;change(altered);const auto r=negotiate_resilient(altered,native());
            require(r.candidate.mosaic.result.status==Status::Invalid&&r.trace.solver.attempts.empty()&&r.candidate.seams.empty(),
                    "tampered frozen preparation reached solver or shared joins");
        }
        for(auto capacity:{0U,1U,2U,3U,5U,7U,9U}) {
            const auto r=negotiate_resilient(prepared,native(capacity));
            require(r.candidate.mosaic.result.status==Status::Invalid&&r.trace.solver.attempts.empty(),"unregistered capacity accepted");
        }
        auto options=native(8);options.receivers=ReceiverPolicy::ClosedOnly;
        require(negotiate_resilient(prepared,options).candidate.mosaic.result.status==Status::Invalid,"unregistered widened policy accepted");
    });
    std::cout<<"resilience tests: "<<passed<<" passed, "<<failed<<" failed, "<<assertions<<" assertions\n";
    return failed?1:0;
}
