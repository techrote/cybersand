// GENTEK-SWARM-005 experimental native assertions. These tests use the frozen
// SWARM-004 donor and a separately opt-in source-feasibility/receiver programme.
#include "reciprocal.hpp"
#include <algorithm>
#include <functional>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

using namespace cybersand::gentek_swarm;
namespace a=cybersand::gentek_swarm::assembly004;
namespace {
std::uint64_t assertions{};
void require(bool okay,const std::string& description) {
    ++assertions;
    if (!okay) throw std::runtime_error(description);
}
a::Composition sample(const char* id, const char* style, std::uint64_t seed,
                      bool feasible=false, bool receptors=false) {
    auto in=a::input_for(fixture(id),profile(style),seed,"swarm005-experimental-native-regression");
    in.options.compact_native_termination=feasible;
    in.options.supported_native_receptors=receptors;
    return a::assemble(in);
}
std::size_t supported_count(const a::Composition& c) {
    std::size_t total{};
    for(const auto& round:c.rounds)total+=round.mosaic_supported_receptors.size();
    return total;
}
struct ReceptorScan {
    a::MosaicRevision revision;
    Result frame;
    std::vector<TransitionSlot> slots;
};
ReceptorScan maximum_scan(bool large_footprint) {
    ReceptorScan out;
    auto& q = out.revision.request;
    q.gentek = Kind::Mosaic;
    q.width = 256;
    q.height = 128;
    q.limits.max_instances = 192;
    out.revision.status = a::MosaicRevisionStatus::Complete;
    auto& m = out.revision.plan.result;
    m = begin_result(q, "bounded-receptor-scan-test");
    auto fq = q;
    fq.gentek = Kind::Frameweaver;
    out.frame = begin_result(fq, "bounded-source-scan-test");
    Instance part;
    part.id = 1;
    part.kind = "native-test-motif";
    for (int y = 0; y < q.height; ++y) for (int x = 0; x < q.width; ++x) {
        // The native gap and all 33 roots are identical in both controls. The
        // large motif approaches the maximum single-part footprint (32,768).
        const bool gap = y >= 16 && y <= 48 && x >= 64 && x <= 67;
        const bool bearing = y >= 16 && y <= 48 && (x == 68 || x == 69);
        const bool port = x == 0 && y < 8;
        if ((!large_footprint && !bearing && !port) || gap) continue;
        const Point p{x, y};
        const auto i = index(q, p);
        m.cells[i] = cybersand::Material::SteelPlate;
        m.roles[i] = Role::Structure;
        m.provenance[i] = part.id;
        part.cells.push_back(p);
    }
    m.instances.push_back(std::move(part));
    for (int y = 16; y <= 48; ++y) {
        const auto i = index(q, {64, y});
        out.frame.cells[i] = cybersand::Material::SteelPlate;
        out.frame.roles[i] = Role::Structure;
        out.frame.provenance[i] = 1;
    }
    for (std::uint32_t i = 1; i <= max_transition_slots; ++i) {
        out.frame.connectors.push_back({i, 1, Family::Frame, {64,16}, {64,48}, {1,0}, true});
        TransitionSlot slot;
        slot.id = slot.connector = i;
        slot.instance = 1;
        slot.a = {64,16}; slot.b = {64,48}; slot.facing = {1,0};
        slot.envelope = {64,16,32,33};
        slot.required = slot.hard = true;
        out.slots.push_back(slot);
        const Point p{0, static_cast<int>(i - 1)};
        m.boundary.hard.push_back({i, 1, p, p, {-1,0}, Family::Frame, false, 1.0, "existing"});
    }
    return out;
}
}
int main() {
    unsigned passed{}, failed{};
    const auto test=[&](const char* label,const std::function<void()>& run) {
        try{run();++passed;std::cout<<"PASS "<<label<<'\n';}
        catch(const std::exception& e){++failed;std::cerr<<"FAIL "<<label<<": "<<e.what()<<'\n';}
    };
    test("opt-in off is deterministic and leaves SWARM004 source authority unchanged",[]{
        const auto a=sample("narrow_neck","sparse_regular",605);
        const auto b=sample("narrow_neck","sparse_regular",605);
        require(a.status==b.status&&a.can_apply==b.can_apply&&a.cells==b.cells&&
            a.joints.size()==b.joints.size()&&a.original_frame.result.digest==b.original_frame.result.digest,
            "frozen unselected source drifted between identical calls");
        require(a.original_frame.result.metrics.count("swarm005_source_compact_terminations")==0,
            "opt-in work leaked into source control");
        for(const auto& round:a.rounds)require(round.mosaic_supported_receptors.empty(),"opt-in ports leaked to off control");
    });
    test("source-time real part choices rescue a blocked case without waiving foreign sockets",[]{
        const auto off=sample("narrow_neck","sparse_regular",605);
        const auto on=sample("narrow_neck","sparse_regular",605,true,true);
        require(off.status==a::CompositionStatus::Blocked&&!off.can_apply,
                "frozen source no longer has the original blocked result");
        require(on.status==a::CompositionStatus::Complete&&on.can_apply,
                "native source alternative did not achieve true full Apply authorization");
        require(on.original_frame.result.material_digest!=off.original_frame.result.material_digest,
                "preflight claimed success without different actual native geometry");
        require(on.original_frame.result.rejected.count("swarm005_unserviceable_required_exit_preflight")>0||
                on.original_frame.result.metrics.count("swarm005_source_compact_terminations")>0,
                "no explicit source-generation authoring action recorded");
        require(std::none_of(on.obligations.begin(),on.obligations.end(),[](const auto& o){
            return o.state=="STILL_REQUIRED";}),"foreign-required obligations were silently waived");
        for(const auto& part:on.original_frame.result.instances)if(part.kind=="swarm005/compact_native_terminal") {
            require(!part.cells.empty()&&part.structural,"compact authored terminal has no native structural footprint");
            for(const auto cell:part.cells)require(inside(on.input.frame,cell),"compact native part escaped its finite source");
        }
    });
    test("real dual-MOSAIC native backing creates a qualified joint but leaves hard deficits visible",[]{
        const auto off=sample("protected_corridor","sparse_regular",605);
        const auto on=sample("protected_corridor","sparse_regular",605,true,true);
        require(off.status==a::CompositionStatus::Blocked&&on.status==a::CompositionStatus::Blocked&&
                !on.can_apply,"candidate improperly authorized the still-incomplete source");
        require(on.joints.size()>off.joints.size()&&supported_count(on)>0,
                "source-bound bearing failed to produce a qualified physical material joint");
        require(std::any_of(on.obligations.begin(),on.obligations.end(),[](const auto& o){
                return o.state=="FOREIGN_JOINED";}),"no original required source actually joined");
        require(std::any_of(on.obligations.begin(),on.obligations.end(),[](const auto& o){
                return o.state=="STILL_REQUIRED";}),"remaining required obligations were erased");
        const auto duplicate=sample("protected_corridor","sparse_regular",605,true,true);
        require(on.cells==duplicate.cells&&on.joints.size()==duplicate.joints.size()&&
                on.metrics.at("total_charged_work")==duplicate.metrics.at("total_charged_work"),
                "new authoring path changed with identical source/seed/limits");
        for(const auto& round:on.rounds)for(const auto& r:round.mosaic_supported_receptors){
            const auto& m=round.mosaic.result;const auto i=index(on.input.mosaic,r.contact),j=index(on.input.mosaic,r.backing);
            require(r.receiving_instance!=0&&m.provenance[i]==r.receiving_instance&&m.provenance[j]==r.receiving_instance,
                "supported receiver lacks stable same-part native cell ownership");
        }
    });
    test("forged native source-bound bearing identities are rejected before Apply",[]{
        const auto original=sample("protected_corridor","sparse_regular",605,true,true);
        require(supported_count(original)>0,"tamper fixture contains no supported source-bound receptors");
        for(unsigned attack=0;attack<5;++attack) {
            auto candidate=original;
            auto& round=candidate.rounds[1];
            require(!round.mosaic_supported_receptors.empty(),"tamper round did not retain its native source receipt");
            auto& witness=round.mosaic_supported_receptors.front();
            switch(attack) {
                case 0: witness.slot++;break;
                case 1: witness.connector++;break;
                case 2: witness.receiving_instance++;break;
                case 3: witness.backing.x++;break;
                default: {
                    auto& ports=round.mosaic.result.boundary.hard;
                    auto port=std::find_if(ports.begin(),ports.end(),[&](const auto& p){return p.id==witness.port_id;});
                    require(port!=ports.end(),"missing tamper port");
                    port->tag="forged-receptor";break;
                }
            }
            require(!a::validate_composition(candidate)&&!candidate.can_apply&&
                candidate.status==a::CompositionStatus::Invalid,
                "tampered supported receiver gained Apply authority");
        }
    });
    test("cancelled or unfunded supported receptor authoring is atomic",[]{
        const auto c=sample("protected_corridor","sparse_regular",605,true,true);
        require(c.rounds.size()>1,"source fixture has no reciprocal round");
        a::MosaicRevision attempt;
        attempt.request=c.rounds[1].mosaic_request;
        attempt.plan=c.rounds[1].mosaic;
        attempt.status=a::MosaicRevisionStatus::Complete;
        const auto before=attempt.plan.result.digest;
        a::MosaicBudget insufficient;
        insufficient.generator_remaining=1;
        require(!a::author_supported_native_receptors(attempt,c.rounds[0].frame.result,
                c.rounds[0].frame.slots,insufficient),"unfunded native authoring accepted");
        require(attempt.status==a::MosaicRevisionStatus::Exhausted&&
                attempt.plan.result.digest==before&&attempt.supported_receptors.empty(),
                "unfunded source receptor mutated an accepted native result");
        attempt.status=a::MosaicRevisionStatus::Complete;
        attempt.plan=c.rounds[1].mosaic;
        a::MosaicBudget no_offer_budget;
        const auto baseline=attempt.plan.result.digest;
        require(a::author_supported_native_receptors(attempt,c.rounds[0].frame.result,{},no_offer_budget) &&
                attempt.plan.result.digest==baseline&&attempt.supported_receptors.empty(),
                "no-source call published a synthetic receiver");
    });
    test("rescuing an additional native source with real joints",[]{
        const auto off=sample("narrow_neck","dense_cohesive",19457);
        const auto on=sample("narrow_neck","dense_cohesive",19457,true,true);
        require(off.status==a::CompositionStatus::Blocked&&!off.can_apply,
                "additional baseline is no longer blocked");
        require(on.status==a::CompositionStatus::Complete&&on.can_apply&&on.joints.size()>=1,
                "source selection failed to produce truly applicable native joint construction");
    });
    test("maximum native footprint scans are charged and refuse atomically before overspending",[]{
        auto small = maximum_scan(false);
        a::MosaicBudget small_budget;
        require(a::author_supported_native_receptors(small.revision, small.frame, small.slots, small_budget),
                "bounded small-footprint control unexpectedly exhausted");
        require(small.revision.supported_receptors.empty(), "at-capacity native motif gained a ninth port");
        auto large = maximum_scan(true);
        const auto before = large.revision.plan.result;
        a::MosaicBudget budget;
        require(!a::author_supported_native_receptors(large.revision, large.frame, large.slots, budget),
                "nested 8-slot/33-root/14-distance/maximum-footprint scan escaped work accounting");
        require(large.revision.status == a::MosaicRevisionStatus::Exhausted &&
                large.revision.supported_receptor_work > small.revision.supported_receptor_work,
                "larger footprint searches did not consume their actual allowance");
        require(budget.generator_remaining + large.revision.supported_receptor_work == 2'000'000 &&
                large.revision.wrapper_work == large.revision.supported_receptor_work,
                "refused scan lost or double-charged generator work");
        require(large.revision.plan.result.cells == before.cells &&
                large.revision.plan.result.provenance == before.provenance &&
                large.revision.plan.result.digest == before.digest &&
                large.revision.plan.result.boundary.hard.size() == before.boundary.hard.size() &&
                large.revision.supported_receptors.empty(), "exhausted scan partially published a receptor");
        auto cancelled = maximum_scan(true);
        std::atomic_bool stop{true};
        a::MosaicBudget cancelled_budget;
        cancelled_budget.cancelled = &stop;
        require(!a::author_supported_native_receptors(cancelled.revision, cancelled.frame, cancelled.slots, cancelled_budget) &&
                cancelled.revision.status == a::MosaicRevisionStatus::Cancelled &&
                cancelled.revision.supported_receptors.empty() && cancelled_budget.generator_remaining == 2'000'000,
                "pre-cancelled receptor scan performed or published work");
        std::cout << "RECEPTOR_SCAN_BOUND small_work=" << small.revision.supported_receptor_work
                  << " maximum_footprint=" << before.instances.front().cells.size()
                  << " charged=" << large.revision.supported_receptor_work
                  << " remaining=" << budget.generator_remaining << '\n';
    });
    std::cout<<"SWARM005_NATIVE_PILOT: "<<(failed?"FAIL":"PASS")<<" tests="<<passed<<"/"<<(passed+failed)
             <<" assertions="<<assertions<<'\n';
    return failed?1:0;
}
