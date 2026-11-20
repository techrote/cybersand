#include "reciprocal.hpp"
#include <algorithm>
#include <iostream>
#include <limits>
#include <stdexcept>

using namespace cybersand::gentek_swarm;
using cybersand::Material;
namespace a=cybersand::gentek_swarm::assembly004;
namespace {
unsigned checks=0;
void require(bool yes,const std::string& why){++checks;if(!yes)throw std::runtime_error(why);}
std::uint64_t occupied_changes(const Result& before,const Result& after) {
    require(before.cells.size()==after.cells.size(),"footprint comparison requires same native grid");
    std::uint64_t count=0;
    for(std::size_t i=0;i<before.cells.size();++i)count+=(before.cells[i]==Material::Empty)!=(after.cells[i]==Material::Empty);
    return count;
}
void audit(const a::Composition& c) {
    require(c.metrics.find("hard_violations")==c.metrics.end()||c.metrics.at("hard_violations")==0,"hard invariant failure");
    require(!c.can_apply||c.status==a::CompositionStatus::Complete,"invalid application authority");
    if(c.cells.empty()){require(!c.can_apply,"empty result applied");return;}
    require(c.cells.size()==c.ledger.size(),"unaccounted native cell");
    const auto& q=c.input.frame;
    for(std::size_t i=0;i<c.cells.size();++i) {
        if(!q.protected_void.empty()&&q.protected_void[i])require(c.cells[i]==Material::Empty,"protected passage changed");
        if(!q.context.empty()&&q.context[i]!=Material::Empty)require(c.cells[i]==q.context[i]&&c.ledger[i].owner==3,"foreign context changed");
        if(c.cells[i]!=Material::Empty)require(c.ledger[i].owner>0&&c.ledger[i].rule<c.rules.size(),"missing provenance");
        if(c.ledger[i].owner==1&&!q.eligible[i])require(c.input.options.shared_ownership&&c.input.shared_zone[i],"FRAME escaped own/shared territory");
        if(c.ledger[i].owner==2&&!c.input.mosaic.eligible[i])require(c.input.options.shared_ownership&&c.input.shared_zone[i],"MOSAIC escaped own/shared territory");
    }
    for(const auto& o:c.obligations) {
        require(o.state==(o.foreign_joined?"FOREIGN_JOINED":"STILL_REQUIRED"),"local ending downgraded foreign obligation");
        if(o.foreign_joined)require(std::any_of(c.joints.begin(),c.joints.end(),[&](const auto& j){
            return o.origin=="original_frame"?j.connector==o.connector:j.slot==o.slot&&j.frame_face==o.original&&j.frame_instance==o.instance;}),"required joined without path");
    }
    for(const auto& j:c.joints) {
        require(j.path.size()>=2&&j.path.size()<=32,"unbounded joint path");
        require(j.path.front()==j.root&&j.path.back()==j.masonry_face,"joint path endpoints");
        require(j.masonry_face==Point{j.frame_face.x+j.normal.x,j.frame_face.y+j.normal.y},"joint facing mismatch");
        for(std::size_t k=0;k<j.path.size();++k) {
            const auto p=j.path[k];require(inside(q,p),"joint outside canvas");
            const auto i=index(q,p);require(c.cells[i]!=Material::Empty,"joint path has empty native cell");
            require(c.ledger[i].owner==(k+1==j.path.size()?2:1),"path authority mismatch");
            if(k)require(std::abs(p.x-j.path[k-1].x)+std::abs(p.y-j.path[k-1].y)==1,"discontinuous material path");
        }
    }
    require(c.metrics.at("coordinator_created_cells")==0,"coordinator manufactured architecture");
    require(c.metrics.at("total_charged_work")<=10'000'000,"aggregate work ceiling changed");
}

// Synthetic *validator unit control*, never a reciprocal-generation or corpus
// success claim. The three cells provide a real solid contact and backing.
a::Composition validator_control() {
    static_assert(static_cast<unsigned>(Material::RedBrick)==43);
    a::Composition c;c.status=a::CompositionStatus::Blocked;c.input.options.rounds=0;
    for(auto* q:{&c.input.frame,&c.input.mosaic}) {
        q->width=32;q->height=16;q->seed=605;q->source_identity="swarm004-validator-unit-control";
        q->fixture="synthetic-validator-control";
        q->eligible.assign(512,0);q->protected_void.assign(512,0);q->transition.assign(512,0);
        q->context.assign(512,Material::Empty);
        for(int y=7;y<=9;++y)for(int x=7;x<=11;++x)q->transition[static_cast<std::size_t>(y*32+x)]=1;
    }
    c.input.frame.gentek=Kind::Frameweaver;c.input.mosaic.gentek=Kind::Mosaic;
    c.input.mosaic.limits.max_instances=192;c.input.shared_zone.assign(512,0);
    for(int y=0;y<16;++y)for(int x=0;x<32;++x)
        (x<9?c.input.frame.eligible:c.input.mosaic.eligible)[static_cast<std::size_t>(y*32+x)]=1;
    a::Round r;r.number=0;r.mosaic_request=c.input.mosaic;
    r.frame.result=begin_result(c.input.frame,"validator-only-frame");
    r.mosaic.result=begin_result(c.input.mosaic,"validator-only-masonry");
    Instance f;f.id=1;f.kind="steel_control";f.origin={8,8};f.reason="synthetic validator original frame part";f.cells={{8,8}};
    Instance m;m.id=2;m.kind="brick_control";m.origin={9,8};m.reason="synthetic validator solid receiving part";m.cells={{9,8},{10,8}};
    r.frame.result.instances.push_back(f);r.mosaic.result.instances.push_back(m);
    r.frame.result.cells[264]=Material::SteelPlate;r.frame.result.roles[264]=Role::Structure;r.frame.result.provenance[264]=1;
    for(std::size_t i:{265U,266U}) {r.mosaic.result.cells[i]=Material::RedBrick;r.mosaic.result.roles[i]=Role::Structure;r.mosaic.result.provenance[i]=2;}
    Connector obligation;obligation.id=77;obligation.instance=1;obligation.a=obligation.b={8,8};
    obligation.facing={1,0};obligation.family=Family::Frame;obligation.required=true;obligation.state="unresolved";
    r.frame.result.connectors.push_back(obligation);r.frame.result.status=Status::Blocked;
    r.frame.result.boundary.hard.push_back({1,1,{8,8},{8,8},{1,0},Family::Frame,true,1.,"frame_control"});
    r.mosaic.result.boundary.hard.push_back({1,2,{9,8},{9,8},{-1,0},Family::Frame,false,1.,"solid_bearing_control"});
    TransitionSlot slot;slot.id=1;slot.instance=1;slot.connector=77;slot.required=slot.hard=true;
    slot.a=slot.b={8,8};slot.facing={1,0};slot.envelope={8,7,4,3};slot.reason="synthetic validator source-bound slot";
    r.frame.slots.push_back(slot);
    finish_result(c.input.frame,r.frame.result);finish_result(c.input.mosaic,r.mosaic.result);
    c.original_frame.result=r.frame.result;c.original_frame.core=r.frame.result;c.original_frame.slots=r.frame.slots;
    r.proposed_frame=r.frame.result;r.proposed_mosaic=r.mosaic.result;
    c.rounds.push_back(std::move(r));
    require(a::validate_composition(c)&&c.can_apply&&c.status==a::CompositionStatus::Complete,
            "valid solid validator control must authorize Apply: "+c.reason);
    require(c.joints.size()==1&&c.obligations.size()==1&&c.obligations[0].state=="FOREIGN_JOINED",
            "validator control requires its exact original obligation and native contact");
    return c;
}

a::Composition validator_bearing_control() {
    auto c=validator_control();auto& r=c.rounds.back();
    a::Budget budget;auto expansion=a::expand(a::bearing_grammar(),{a::backward_bearing,true},{{8,8},0},0,0,budget);
    require(expansion.outcome==a::Outcome::Complete,"validator bearing control requires a real expanded grammar");
    a::Construction construction;construction.slot=1;construction.connector=77;construction.base_instance=1;
    construction.root=construction.face={8,8};construction.facing={1,0};
    construction.rule="FRAMEWEAVER/assemblies/v1/backward_bearing/upper";
    construction.authored_symbol={a::backward_bearing,true};construction.span=construction.rise=2;construction.handedness=-1;construction.input_family=Family::Frame;
    for(const auto& part:expansion.instances) {
        const auto id=part.instance+10;construction.parts.push_back(id);
        Instance instance;instance.id=id;instance.kind="swarm004/"+part.name;instance.reason=part.rule;
        instance.origin=part.transform.translation;instance.orientation=static_cast<int>(part.transform.quarter_turns);
        for(const auto& claim:expansion.claims)if(claim.instance==part.instance) {
            instance.cells.push_back(claim.point);
            const auto i=index(c.input.frame,claim.point);
            if(r.frame.result.cells[i]!=Material::Empty)continue;
            r.frame.result.cells[i]=claim.material;r.frame.result.roles[i]=claim.role;r.frame.result.provenance[i]=id;
        }
        r.frame.result.instances.push_back(std::move(instance));
    }
    construction.assembly=std::move(expansion);r.frame.constructions.push_back(std::move(construction));
    finish_result(c.input.frame,r.frame.result);r.proposed_frame=r.frame.result;c.metrics["frame_work"]=budget.work;
    require(a::validate_composition(c)&&c.can_apply,"source-bound backward-bearing validator control: "+c.reason);
    require(c.metrics.at("new_assembly_required")==1&&c.obligations.size()==2,
            "real assembly foreign output must be counted separately from the original socket");
    return c;
}

void validator_authorization_regressions() {
    const auto control=validator_control();
    const auto reject=[&](const std::string& label,const auto& mutate) {
        auto c=control; // Includes previously granted Apply authority: revalidation must revoke it.
        mutate(c);a::validate_composition(c);
        require(!c.can_apply,"authorization regression "+label+": Apply remained enabled; "+c.reason);
    };
    reject("incompatible Brace receptor",[](auto& c){c.rounds.back().mosaic.result.boundary.hard[0].family=Family::Brace;});
    reject("invalid receptor family",[](auto& c){c.rounds.back().mosaic.result.boundary.hard[0].family=static_cast<Family>(255);});
    reject("passage is not structural",[](auto& c){c.rounds.back().mosaic.result.boundary.hard[0].family=Family::Passage;});
    reject("same-facing receiver",[](auto& c){c.rounds.back().mosaic.result.boundary.hard[0].facing={1,0};});
    reject("FRAME claim outside named footprint",[](auto& c){c.rounds.back().frame.result.instances[0].cells={{1,1}};});
    reject("MOSAIC claim outside named footprint",[](auto& c){c.rounds.back().mosaic.result.instances[0].cells={{1,1}};});
    reject("missing material owner",[](auto& c){c.rounds.back().frame.result.instances.clear();});
    reject("duplicate named part identity",[](auto& c){c.rounds.back().frame.result.instances.push_back(c.rounds.back().frame.result.instances[0]);});
    reject("unbounded part footprint",[](auto& c){c.rounds.back().frame.result.instances[0].cells.assign(513,{8,8});});
    reject("part index beyond ledger",[](auto& c){c.rounds.back().frame.result.instances[0].id=257;c.rounds.back().frame.result.provenance[264]=257;});
    reject("Water cannot supply backing",[](auto& c){c.rounds.back().mosaic.result.cells[266]=Material::Water;});
    reject("Detail cannot supply backing",[](auto& c){c.rounds.back().mosaic.result.roles[266]=Role::Detail;});
    reject("powder Stone cannot supply backing",[](auto& c){c.rounds.back().mosaic.result.cells[266]=Material::Stone;});
    reject("nonstructural receiving face",[](auto& c){c.rounds.back().mosaic.result.roles[265]=Role::Cohesion;});
    reject("different peer dimensions",[](auto& c){c.input.mosaic.width=16;c.input.mosaic.height=32;});
    reject("wrong peer Gentek identity",[](auto& c){c.input.mosaic.gentek=Kind::Frameweaver;});
    reject("peer-only protected contact",[](auto& c){c.input.mosaic.protected_void[265]=1;});
    reject("protected native contact",[](auto& c){c.input.frame.protected_void[265]=c.input.mosaic.protected_void[265]=1;});
    reject("untyped extra native cell",[](auto& c){c.rounds.back().frame.result.cells[0]=Material::Water;c.rounds.back().frame.result.provenance[0]=1;});
    reject("short shared mask",[](auto& c){c.input.shared_zone.resize(1);});
    reject("nonbinary shared mask",[](auto& c){c.input.shared_zone[0]=2;});
    reject("shared claim outside registered band",[](auto& c){c.input.shared_zone[0]=1;});
    reject("short native protection mask",[](auto& c){auto& mask=c.rounds.back().mosaic.result.boundary.protected_geometry;mask.resize(1);mask.shrink_to_fit();});
    reject("nonbinary native protection mask",[](auto& c){c.rounds.back().mosaic.result.boundary.protected_geometry[0]=2;});
    reject("empty earlier accepted snapshot",[](auto& c){
        auto later=c.rounds.back();later.number=1;c.input.options.rounds=1;
        c.rounds[0].frame.result.cells.clear();c.rounds[0].frame.result.cells.shrink_to_fit();c.rounds.push_back(std::move(later));
    });
    reject("malformed earlier accepted mask",[](auto& c){
        auto later=c.rounds.back();later.number=1;c.input.options.rounds=1;
        c.rounds[0].mosaic.result.boundary.protected_geometry.assign(1,1);c.rounds[0].mosaic.result.boundary.protected_geometry.shrink_to_fit();c.rounds.push_back(std::move(later));
    });
    reject("earlier material outside its footprint",[](auto& c){
        auto later=c.rounds.back();later.number=1;c.input.options.rounds=1;
        c.rounds[0].frame.result.instances[0].cells={{1,1}};c.rounds.push_back(std::move(later));
    });
    reject("duplicate round ordinal",[](auto& c){c.input.options.rounds=1;c.rounds.push_back(c.rounds[0]);});
    reject("skipped round ordinal",[](auto& c){c.input.options.rounds=2;auto later=c.rounds[0];later.number=2;c.rounds.push_back(std::move(later));});
    reject("round count beyond chosen protocol",[](auto& c){auto later=c.rounds[0];later.number=1;c.rounds.push_back(std::move(later));});
    reject("unbounded revision history",[](auto& c){const auto round=c.rounds[0];c.rounds.assign(6,round);});
    reject("unbounded round input",[](auto& c){c.input.options.rounds=5;});
    reject("expanded shared extent",[](auto& c){c.input.options.shared_extent=14;});
    reject("expanded FRAME work budget",[](auto& c){c.input.frame.limits.max_work=2'000'001;});
    reject("expanded categorical budget",[](auto& c){c.input.mosaic.limits.max_solver_work=4'000'001;});
    reject("expanded FRAME instances",[](auto& c){c.input.frame.limits.max_instances=65;});
    reject("expanded candidates",[](auto& c){c.input.frame.limits.max_candidates=8193;});
    reject("expanded memory",[](auto& c){c.input.frame.limits.max_bytes=16U*1024U*1024U+1;});
    reject("unbounded input dimensions",[](auto& c){c.input.frame.width=std::numeric_limits<int>::max();});
    reject("unbounded final slots",[](auto& c){c.rounds.back().frame.slots.assign(9,c.rounds.back().frame.slots[0]);});
    reject("forged original connector id binding",[](auto& c){
        auto source=begin_result(c.input.frame,"synthetic unrelated source");
        Instance p;p.id=55;p.kind="unrelated_original";p.origin={1,1};p.cells={{1,1}};p.reason="different genuine source geometry";
        source.instances.push_back(p);source.cells[33]=Material::SteelPlate;source.roles[33]=Role::Structure;source.provenance[33]=55;
        Connector socket;socket.id=77;socket.instance=55;socket.a=socket.b={1,1};socket.facing={0,1};socket.required=true;
        source.connectors.push_back(socket);source.status=Status::Blocked;finish_result(c.input.frame,source);
        c.original_frame.result=source;c.original_frame.core=source;c.original_frame.slots.clear();
    });
    reject("original source footprint lost",[](auto& c){c.original_frame.result.instances[0].cells={{1,1}};});
    reject("unbounded original connector segment",[](auto& c){
        c.original_frame.result.connectors[0].a={std::numeric_limits<int>::min(),8};
        c.original_frame.result.connectors[0].b={std::numeric_limits<int>::max(),8};
    });
    reject("unbounded connector normal",[](auto& c){
        c.original_frame.result.connectors[0].facing=c.rounds.back().frame.slots[0].facing={std::numeric_limits<int>::min(),0};
    });
    reject("undeclared damage repaint",[](auto& c){
        a::DamageDerivative damage;damage.frame=c.rounds.back().frame;damage.mosaic=c.rounds.back().mosaic;
        damage.mosaic.result.cells[265]=Material::SteelPlate;c.damage_derivative=std::move(damage);
    });
    reject("past promised void cannot be filled",[](auto& c){
        c.input.options.rounds=1;auto later=c.rounds[0];later.number=1;
        c.rounds[0].mosaic.result.boundary.protected_geometry[267]=1;
        later.mosaic.result.cells[267]=Material::RedBrick;later.mosaic.result.roles[267]=Role::Structure;later.mosaic.result.provenance[267]=2;
        later.mosaic.result.instances[0].cells.push_back({11,8});c.rounds.push_back(std::move(later));
    });
    const auto bearing=validator_bearing_control();
    auto downgraded=bearing;downgraded.rounds.back().frame.constructions[0].assembly.sockets[1].obligation=a::Obligation::Optional;
    a::validate_composition(downgraded);
    require(!downgraded.can_apply,"foreign-required root export cannot be downgraded while its authored part remains");
    auto hidden=bearing;
    auto& leaf=hidden.rounds.back().frame.constructions[0].assembly.instances[0];
    auto missing=leaf.sockets[0];missing.id=missing.source_socket=99;missing.a=missing.b={8,6};
    missing.family=Family::Frame;missing.facing={-1,0};missing.obligation=a::Obligation::ForeignRequired;
    leaf.sockets.push_back(missing);a::validate_composition(hidden);
    require(!hidden.can_apply,"new leaf foreign-required socket cannot disappear from assembly exports/obligation ledger");
    auto orphan=bearing;orphan.rounds.back().frame.constructions.push_back(a::Construction{});a::validate_composition(orphan);
    require(!orphan.can_apply,"orphan constructions cannot bypass their authored certificates");
    auto wrong_rule=bearing;wrong_rule.rounds.back().frame.result.instances[1].reason="forged unrelated author";a::validate_composition(wrong_rule);
    require(!wrong_rule.can_apply,"installed native parts require exact authored rule provenance");
    auto wrong_revision=bearing;wrong_revision.rounds.back().frame.constructions[0].assembly.claims[0].revision=99;a::validate_composition(wrong_revision);
    require(!wrong_revision.can_apply,"individual claim revisions require the authored certificate");
    for(const auto* kind:{"claims","instances","nodes","joints"}) {
        auto missing=bearing;auto& assembly=missing.rounds.back().frame.constructions[0].assembly;
        const std::string field=kind;
        if(field=="claims")assembly.claims.clear();else if(field=="instances")assembly.instances.clear();
        else if(field=="nodes")assembly.nodes.clear();else assembly.joints.clear();
        a::validate_composition(missing);require(!missing.can_apply,"incomplete authored assembly certificate: "+field);
    }
}

void nominal_native_witness(const a::Input& input,const a::Composition& two) {
    // Fixed known development fixture, seed605. This is real native generator
    // execution; the synthetic validator controls above cannot satisfy it.
    require(two.rounds.size()>=3,"registered reciprocal witness requires two actual negotiation rounds");
    require(occupied_changes(two.rounds[0].mosaic.result,two.rounds[1].mosaic.result)>0,
            "round1 MOSAIC must change its native masonry footprint");
    require(occupied_changes(two.rounds[1].frame.result,two.rounds[2].frame.result)>0,
            "round2 FRAME must change its own native footprint");
    const auto assembly=std::find_if(two.rounds[2].frame.constructions.begin(),two.rounds[2].frame.constructions.end(),[&](const auto& part){
        return part.parts.size()>=3&&part.assembly.instances.size()>=3&&!part.assembly.claims.empty()&&
            std::any_of(two.joints.begin(),two.joints.end(),[&](const auto& joint){return joint.slot==part.slot&&joint.connector==part.connector;});
    });
    require(assembly!=two.rounds[2].frame.constructions.end(),"round2 multi-part FRAME revision needs a qualified native foreign joint");
    auto no_input=input;no_input.options.rounds=0;const auto zero=a::assemble(no_input);audit(zero);
    auto one_input=input;one_input.options.rounds=1;const auto one=a::assemble(one_input);audit(one);
    require(!zero.rounds.empty()&&!one.rounds.empty(),"same-seed no-offer and single-round controls must be retained");
    for(const auto* control:{&zero,&one}) {
        require(control->input.frame.seed==input.frame.seed&&control->input.mosaic.seed==input.mosaic.seed,
                "witness controls preserve the exact registered seed");
        require(control->original_frame.result.cells==two.original_frame.result.cells&&
                control->rounds[0].frame.result.cells==two.rounds[0].frame.result.cells&&
                control->rounds[0].mosaic.result.cells==two.rounds[0].mosaic.result.cells,
                "round controls share exact initial native FRAME and MOSAIC geometry");
        require(control->input.frame.eligible==input.frame.eligible&&control->input.mosaic.eligible==input.mosaic.eligible&&
                control->input.shared_zone==input.shared_zone&&control->input.frame.protected_void==input.frame.protected_void&&
                control->rounds[0].frame.result.boundary.protected_geometry==two.rounds[0].frame.result.boundary.protected_geometry&&
                control->rounds[0].mosaic.result.boundary.protected_geometry==two.rounds[0].mosaic.result.boundary.protected_geometry,
                "round controls preserve territory, shared extent and native protected masks");
    }
    require(occupied_changes(zero.rounds.back().mosaic.result,two.rounds[1].mosaic.result)>0,
            "MOSAIC revision differs from the same-seed no-offer footprint");
    require(occupied_changes(one.rounds.back().frame.result,two.rounds[2].frame.result)>0,
            "reciprocal FRAME assembly differs from the same-seed single-round footprint");
}

void matched_counterfactual_regressions() {
    // The original seed605 witness changes both footprints, but its MOSAIC
    // change also occurs without offers once prior protected passages are
    // preserved. Never use an unmatched initial proposal as causal evidence.
    // Seed4099 is the genuine same-mask two-direction positive witness.
    for(const auto seed:{605ULL,4099ULL}) {
        const auto input=a::input_for(fixture("island"),profile("branching_irregular"),
                                     seed,"swarm004-matched-counterfactual-tests");
        const auto candidate=a::assemble(input);audit(candidate);
        require(candidate.rounds.size()==3&&candidate.metrics.at("both_genteks_revised")==1,
                "counterfactual fixture must retain both nominal native revisions");
        const auto& initial=candidate.rounds[0];const auto& revised=candidate.rounds[1];
        auto request=input.mosaic;request.profile.destruction=0;
        if(request.protected_void.empty())request.protected_void.assign(initial.frame.result.cells.size(),0);
        for(std::size_t i=0;i<request.protected_void.size();++i)
            request.protected_void[i]=static_cast<std::uint8_t>(request.protected_void[i]||
                (!initial.frame.result.boundary.protected_geometry.empty()&&initial.frame.result.boundary.protected_geometry[i])||
                (!initial.mosaic.result.boundary.protected_geometry.empty()&&initial.mosaic.result.boundary.protected_geometry[i]));
        a::MosaicBudget budget;
        budget.generator_remaining=input.mosaic.limits.max_work-initial.mosaic_work;
        budget.solver_remaining=input.mosaic.limits.max_solver_work-initial.solver_work;
        budget.max_bytes=input.mosaic.limits.max_bytes;budget.proposals_remaining=4;
        const auto no_offer=a::propose_mosaic_revision(request,initial.frame.result,{},input.shared_zone,
            budget,1,&initial.mosaic.result,&initial.mosaic.categories,
            input.options.optional_negotiation,input.options.native_mosaic_bearing);
        require(no_offer.status==a::MosaicRevisionStatus::Complete,
                "matched no-offer control must complete under the same remaining allowance");
        require(no_offer.request.eligible==revised.mosaic_request.eligible&&
                no_offer.request.protected_void==revised.mosaic_request.protected_void&&
                no_offer.request.context==revised.mosaic_request.context&&
                no_offer.request.neighbor_cells==revised.mosaic_request.neighbor_cells,
                "causal comparison requires exact accepted masks/context/peer cells");
        const auto mosaic_effect=occupied_changes(revised.mosaic.result,no_offer.plan.result);
        require(seed==605?mosaic_effect==0:mosaic_effect>0,
                "preserved-mask false positive and genuine offer-causal geometry must stay distinct");
        auto frozen_input=input;frozen_input.options.mosaic_adaptation=false;
        const auto frozen_peer=a::assemble(frozen_input);audit(frozen_peer);
        require(!frozen_peer.rounds.empty()&&
                frozen_peer.rounds.front().frame.result.cells==initial.frame.result.cells&&
                frozen_peer.rounds.front().mosaic.result.cells==initial.mosaic.result.cells,
                "frozen-peer counterfactual must preserve the exact initial native pair");
        for(const auto& round:frozen_peer.rounds)
            require(round.mosaic.result.cells==initial.mosaic.result.cells,
                    "frozen-peer control may not revise MOSAIC");
        require(occupied_changes(candidate.rounds.back().frame.result,frozen_peer.rounds.back().frame.result)>0,
                "FRAME revision must depend on the changed peer geometry");
        if(seed==4099) {
            require(candidate.can_apply&&candidate.status==a::CompositionStatus::Complete&&
                    !candidate.joints.empty()&&candidate.metrics.at("still_required")==0,
                    "genuine reciprocal witness must retain full native foreign closure and Apply authorization");
            auto reverse=a::assemble(input,true);audit(reverse);
            require(reverse.digest==candidate.digest&&reverse.cells==candidate.cells&&reverse.can_apply,
                    "causal positive composition must preserve reverse-evaluation determinism");
        } else require(!candidate.can_apply,
                       "nominal seed605 negative remains blocked; it is not a reciprocal success");
    }
}
}
int main(int argc,char**) try {
    const bool probe=argc>1;
    validator_authorization_regressions();
    matched_counterfactual_regressions();
    std::uint64_t both=0,joints=0,complete=0;
    bool decisive=false;
    for(const auto& id:fixture_names())for(const auto* p:{"sparse_regular","branching_irregular","dense_cohesive"}) {
        auto in=a::input_for(fixture(id),profile(p),605,"swarm004-focused-tests");
        const auto c=a::assemble(in);audit(c);
        const auto rev=a::assemble(in,true);audit(rev);
        require(c.status==rev.status&&c.cells==rev.cells&&c.digest==rev.digest&&c.rounds.size()==rev.rounds.size(),"reverse evaluation changed accepted composition");
        for(std::size_t r=0;r<c.rounds.size();++r)require(c.rounds[r].semantic_digest==rev.rounds[r].semantic_digest,"round replay differs");
        both+=c.metrics.contains("both_genteks_revised")?c.metrics.at("both_genteks_revised"):0;joints+=c.joints.size();complete+=c.can_apply;
        if(id=="island"&&std::string(p)=="branching_irregular") {nominal_native_witness(in,c);decisive=true;}
        if(probe)std::cout<<id<<'/'<<p<<" status="<<a::name(c.status)<<" apply="<<c.can_apply
            <<" rounds="<<c.rounds.size()<<" joints="<<c.joints.size()<<" both="<<(c.metrics.contains("both_genteks_revised")?c.metrics.at("both_genteks_revised"):0)
            <<" reason="<<c.reason<<'\n';
    }
    require(decisive&&both>0&&joints>0,"real registered cohort must contain reciprocal native geometry and joints");
    auto in=a::input_for(fixture("concave_intrusion"),profile("dense_cohesive"),1701,"swarm004-negative-tests");
    auto invalid=in;invalid.options.rounds=5;require(a::assemble(invalid).status==a::CompositionStatus::Invalid,"unbounded round cap admitted");
    invalid=in;invalid.shared_zone[0]=2;require(a::assemble(invalid).status==a::CompositionStatus::Invalid,"malformed shared mask admitted");
    invalid=in;invalid.mosaic.seed++;require(a::assemble(invalid).status==a::CompositionStatus::Invalid,"seed identity changed");
    invalid=in;invalid.frame.limits.max_work=2'000'001;require(a::assemble(invalid).status==a::CompositionStatus::Invalid,"resource ceiling expanded");
    invalid=in;invalid.frame.limits.max_bytes=1;require(!a::assemble(invalid).can_apply,"memory refusal applied");
    std::atomic_bool cancel=true;in.cancel=&cancel;const auto cancelled=a::assemble(in);
    require(cancelled.status==a::CompositionStatus::Cancelled&&cancelled.cells.empty(),"cancelled request leaked commit output");in.cancel=nullptr;
    for(unsigned n=0;n<=4;++n) {in.options.rounds=n;const auto c=a::assemble(in);audit(c);require(c.rounds.size()<=n+1,"round cap exceeded");}
    in.options.final_validation=false;require(!a::assemble(in).can_apply,"disabled validator created Apply authority");
    in.options.final_validation=true;in.options.rounds=2;in.options.frame_adaptation=false;
    const auto one=a::assemble(in);audit(one);for(const auto& r:one.rounds)require(r.frame_changed==0,"MOSAIC-only ablation changed FRAME");
    in.options.frame_adaptation=true;in.options.mosaic_adaptation=false;
    const auto other=a::assemble(in);audit(other);for(const auto& r:other.rounds)require(r.mosaic_changed==0,"FRAME-only ablation changed MOSAIC");
    std::cout<<"reciprocal checks="<<checks<<" both="<<both<<" joints="<<joints<<" complete="<<complete<<'\n';
    return 0;
}catch(const std::exception& e){std::cerr<<"FAIL after "<<checks<<": "<<e.what()<<'\n';return 1;}
