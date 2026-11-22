// SWARM-006 native authority/protocol regression suite. The tiny receiver unit
// below is NOT a generated architecture, holdout, or owner World reproduction.
#include "reciprocal.hpp"
#include <algorithm>
#include <atomic>
#include <functional>
#include <iostream>
#include <limits>
#include <stdexcept>

using namespace cybersand::gentek_swarm;
using cybersand::Material;
using cybersand::MaterialState;
namespace a = cybersand::gentek_swarm::assembly004;
namespace {
std::uint64_t assertions{};
void require(bool yes,const std::string& why){++assertions;if(!yes)throw std::runtime_error(why);}
std::uint64_t metric(const a::Composition& c,const std::string& key){const auto i=c.metrics.find(key);return i==c.metrics.end()?0:i->second;}
a::Input small_input(unsigned rounds=0,std::uint64_t seed=605){
    Fixture f;f.width=32;f.height=32;f.id="swarm006-protocol-unit";
    f.side.assign(1024,0);f.protected_void.assign(1024,0);f.transition.assign(1024,0);f.context.assign(1024,Material::Empty);
    for(int y=0;y<32;++y)for(int x=0;x<32;++x){const auto i=static_cast<std::size_t>(y*32+x);f.side[i]=x>=16;f.transition[i]=x>=2&&x<30;}
    a::Options options;options.rounds=rounds;options.negotiated_recovery=true;
    options.compact_native_termination=true;options.supported_native_receptors=true;
    return a::input_for(f,profile("sparse_regular"),seed,"swarm006-native-authority-unit-not-owner-world",options);
}
a::Input industrial_development_input(){
    a::Input input;input.options.negotiated_recovery=true;input.options.compact_native_termination=true;
    input.options.supported_native_receptors=true;input.options.rounds=2;
    input.frame.gentek=Kind::Frameweaver;input.mosaic.gentek=Kind::Mosaic;
    for(auto* q:{&input.frame,&input.mosaic}){
        q->width=192;q->height=112;q->seed=605;q->source_identity="swarm006-development-regression-not-owner-world";
        q->fixture="workbench_territory";q->definition_fingerprint=definition(q->gentek);q->profile=a::expression_profile("industrial");
        q->activation.push_back({64,48});q->eligible.resize(192*112);q->protected_void.resize(192*112);
        q->context.assign(192*112,Material::Empty);q->transition.resize(192*112);
    }
    input.mosaic.limits.max_instances=192;input.shared_zone.resize(192*112);
    for(int y=0;y<112;++y)for(int x=0;x<192;++x){const auto i=static_cast<std::size_t>(y*192+x);
        const bool interior=x>=4&&x<188&&y>=4&&y<108;
        input.frame.eligible[i]=static_cast<std::uint8_t>(interior&&x<96);
        input.mosaic.eligible[i]=static_cast<std::uint8_t>(interior&&x>=96);
        input.frame.transition[i]=input.mosaic.transition[i]=input.shared_zone[i]=static_cast<std::uint8_t>(interior&&x>=82&&x<=109);
    }
    return input;
}
std::size_t material_footprint_difference(const Result& a,const Result& b){
    require(a.cells.size()==b.cells.size(),"causal native planes have different sizes");std::size_t count=0;
    for(std::size_t i=0;i<a.cells.size();++i)count+=(a.cells[i]==Material::Empty)!=(b.cells[i]==Material::Empty);
    return count;
}
void within_envelope(const a::Composition& c){
    require(metric(c,"frame_work")<=c.input.frame.limits.max_work,"FRAME work exceeded its original allowance");
    require(metric(c,"mosaic_work")<=c.input.mosaic.limits.max_work,"MOSAIC work exceeded its original allowance");
    require(metric(c,"solver_work")<=c.input.mosaic.limits.max_solver_work,"solver work exceeded its original allowance");
    require(metric(c,"shared_work")<=2'000'000,"shared work exceeded its original allowance");
    require(metric(c,"total_charged_work")==metric(c,"frame_work")+metric(c,"mosaic_work")+metric(c,"solver_work")+metric(c,"shared_work"),"aggregate work receipt does not sum");
    require(c.rounds.size()<=c.input.options.rounds+1,"unbounded reciprocal round count");
    require(!c.can_apply||(c.status==a::CompositionStatus::Complete&&metric(c,"still_required")==0),"unresolved native requirements authorized Apply");
    for(const auto& r:c.rounds){require(r.recovery_attempts.size()<=520&&r.mosaic_recovery_receipts.size()<=8&&r.recovery_frontier.size()<=8,"unbounded recovery receipts");
        for(const auto& receipt:r.mosaic_recovery_receipts)require(receipt.edits.size()<=14,"unbounded native receiver motif");}
}
void copy_public_receipt(a::Composition& d,const a::Composition& s){
    // Deliberately preserves d's private capability. A coherent serialized
    // transcript transplant cannot become a legitimate native C++ copy.
    d.input=s.input;d.status=s.status;d.reason=s.reason;d.stop_reason=s.stop_reason;d.original_frame=s.original_frame;
    d.rounds=s.rounds;d.damage_derivative=s.damage_derivative;d.cells=s.cells;d.ledger=s.ledger;d.rules=s.rules;
    d.obligations=s.obligations;d.joints=s.joints;d.metrics=s.metrics;d.rejections=s.rejections;d.digest=s.digest;d.can_apply=s.can_apply;
}
void must_refuse(const a::Composition& original,const char* label,const std::function<void(a::Composition&)>& mutate){
    auto c=original;mutate(c);const auto accepted=a::validate_composition(c);
    require(!accepted&&!c.can_apply&&c.status==a::CompositionStatus::Invalid,std::string("forged receipt accepted: ")+label+" / "+c.reason);
}
struct ReceiverUnit {a::Input input;Result source;MosaicPlan mosaic;std::vector<TransitionSlot> slots;Point first{},second{};};
bool native_solid_or_stone(Material m){return m==Material::Stone||(m!=Material::Empty&&cybersand::material_definition(m).state==MaterialState::Solid);}
bool native_structure(Role role){return role==Role::Structure||role==Role::Brace||role==Role::Transition;}
void material_cache_matches(const Result& result){
    if(result.cells.empty()) {
        require(result.material_digest==0&&result.digest==0,"unexecuted failure header has a cached material/result digest");
        return;
    }
    std::uint64_t digest=14695981039346656037ULL;
    const auto append=[&](std::uint64_t value){for(unsigned byte=0;byte<8;++byte){digest^=value&255U;digest*=1099511628211ULL;value>>=8U;}};
    append(static_cast<std::uint64_t>(result.width));append(static_cast<std::uint64_t>(result.height));
    for(const auto material:result.cells)append(static_cast<unsigned>(material));
    require(result.material_digest==digest,"retained material digest differs from independently hashed native cells");
    require(result.metrics.at("occupied_cells")==static_cast<std::uint64_t>(std::count_if(result.cells.begin(),result.cells.end(),
        [](auto material){return material!=Material::Empty;})),"retained occupied-cell metric is stale");
    require(result.metrics.at("instances")==result.instances.size(),"retained authored-part count is stale");
}
void finalized_snapshot_matches(const a::MosaicRevision& revision){
    const auto& result=revision.plan.result;require(!result.cells.empty(),"expected an admitted native snapshot");
    material_cache_matches(result);auto recomputed=result;finish_result(revision.request,recomputed);
    require(recomputed.digest==result.digest&&recomputed.request_digest==result.request_digest&&recomputed.metrics==result.metrics&&
        recomputed.status==result.status&&recomputed.termination==result.termination,"failure snapshot was not completely finalized");
}
ReceiverUnit receiver_unit(){
    ReceiverUnit u;u.input=small_input(4);u.mosaic=negotiate_mosaic(u.input.mosaic,{});
    require(u.mosaic.result.status==Status::Complete||u.mosaic.result.status==Status::Blocked,"native MOSAIC unit source did not complete");
    const auto& q=u.input.mosaic;const auto& m=u.mosaic.result;std::vector<Point> contacts;
    for(int y=2;y<30;++y){const auto ci=index(q,{16,y}),bi=index(q,{17,y});
        if(!m.provenance[ci]||m.provenance[ci]!=m.provenance[bi]||!native_solid_or_stone(m.cells[ci])||!native_solid_or_stone(m.cells[bi])||
           !native_structure(m.roles[ci])||!native_structure(m.roles[bi]))continue;
        bool clear=true;for(int x=12;x<16;++x){const auto i=index(q,{x,y});if(m.cells[i]!=Material::Empty||(!m.boundary.protected_geometry.empty()&&m.boundary.protected_geometry[i]))clear=false;}
        if(clear)contacts.push_back({16,y});}
    require(contacts.size()>=2,"native MOSAIC unit has too few supported receiving faces");u.first=contacts.front();u.second=contacts.back();
    // This typed source face is explicit test apparatus, not a seeded FRAME
    // success claim. The receiving parts/categories are actual native MOSAIC.
    u.source=begin_result(u.input.frame,"swarm006/protocol-unit-structural-face");
    Instance part;part.id=1;part.kind="protocol-unit/steel-bearing-face";part.origin={12,u.first.y};part.structural=true;
    part.reason="explicit typed source for bounded native receiver API regression";
    for(int y=u.first.y;y<=u.second.y;++y){const Point p{12,y};part.cells.push_back(p);const auto i=index(u.input.frame,p);
        u.source.cells[i]=Material::SteelPlate;u.source.roles[i]=Role::Structure;u.source.provenance[i]=1;}
    u.source.instances.push_back(part);Connector connector;connector.id=1;connector.instance=1;connector.family=Family::Frame;
    connector.a={12,u.first.y};connector.b={12,u.second.y};connector.facing={1,0};connector.required=true;u.source.connectors.push_back(connector);
    TransitionSlot slot;slot.id=slot.instance=slot.connector=1;slot.a=connector.a;slot.b=connector.b;slot.facing={1,0};
    slot.kind=SlotKind::BearingSegment;slot.envelope={12,0,16,32};slot.required=slot.hard=true;slot.reason="unit frozen required interface";u.slots.push_back(slot);
    u.source.status=Status::Blocked;finish_result(u.input.frame,u.source);
    require(!u.source.protected_violations&&!u.source.illegal_overlaps,"protocol unit has invalid native source occupancy");return u;
}
a::MosaicRevision bid(ReceiverUnit& u,a::MosaicBudget& budget,unsigned round=1,const MosaicPlan* previous=nullptr,
    const std::vector<a::MosaicRecoveryReceipt>* receipts=nullptr,const std::vector<a::RecoveryCursor>* frontier=nullptr,const Result* peer=nullptr){
    static const std::vector<a::MosaicRecoveryReceipt> no_receipts;static const std::vector<a::RecoveryCursor> no_frontier;
    return a::propose_mosaic_recovery(u.input.mosaic,u.input.frame,peer?*peer:u.source,u.source,u.slots,u.input.shared_zone,
        previous?*previous:u.mosaic,receipts?*receipts:no_receipts,frontier?*frontier:no_frontier,budget,round);
}
}

int main(){
    unsigned passed{},failed{};
    const auto test=[&](const char* label,const std::function<void()>& run){try{run();++passed;std::cout<<"PASS "<<label<<'\n';}
        catch(const std::exception& e){++failed;std::cerr<<"FAIL "<<label<<": "<<e.what()<<'\n';}};
    test("previously blocked corridor closes two frozen SWARM006 source requirements",[]{
        a::Options options;options.rounds=2;options.compact_native_termination=true;options.supported_native_receptors=true;
        auto input=a::input_for(fixture("protected_corridor"),profile("sparse_regular"),605,"swarm006-corridor-regression-not-owner-world",options);
        const auto baseline=a::assemble(input);within_envelope(baseline);
        require(!baseline.can_apply&&metric(baseline,"original_required")==2&&metric(baseline,"original_still_required")==1,
            "frozen SWARM005 developmental negative changed");
        input.options.negotiated_recovery=true;const auto recovered=a::assemble(input);within_envelope(recovered);
        require(recovered.can_apply&&metric(recovered,"original_required")==2&&metric(recovered,"foreign_joined_required")==2&&
            metric(recovered,"still_required")==0&&recovered.joints.size()==4,"required foreign closure was not genuinely Apply-authorized: "+recovered.reason);
        for(const auto& obligation:recovered.obligations)if(obligation.origin=="original_frame")require(obligation.foreign_joined,"original required obligation disappeared");
        // SWARM005 and SWARM006 can choose different prospective source parts.
        // Identity is frozen WITHIN each run. These controls isolate the exact
        // same SWARM006 original obligations, not merely the same count.
        for(bool freeze_peer:{false,true}){
            auto control_input=input;if(freeze_peer)control_input.options.mosaic_adaptation=false;else control_input.options.recovery_offers=false;
            const auto control=a::assemble(control_input);within_envelope(control);
            require(control.original_frame.result.digest==recovered.original_frame.result.digest&&
                control.original_frame.result.cells==recovered.original_frame.result.cells&&
                control.original_frame.result.provenance==recovered.original_frame.result.provenance,"matched corridor changed frozen source plan");
            require(!control.can_apply&&control.joints.empty()&&metric(control,"original_required")==2&&metric(control,"still_required")==2,
                "matched corridor control did not retain the exact unsatisfied foreign requirements");
        }
    });
    test("synthetic Industrial positive has offer-causal native footprint changes from both Genteks",[]{
        const auto input=industrial_development_input();const auto candidate=a::assemble(input);within_envelope(candidate);
        auto no_offer_input=input;no_offer_input.options.recovery_offers=false;const auto no_offer=a::assemble(no_offer_input);within_envelope(no_offer);
        auto frozen_input=input;frozen_input.options.mosaic_adaptation=false;const auto frozen=a::assemble(frozen_input);within_envelope(frozen);
        require(candidate.can_apply&&candidate.joints.size()>0&&metric(candidate,"still_required")==0,"Industrial native closure failed: "+candidate.reason);
        require(no_offer.status==a::CompositionStatus::Complete||no_offer.status==a::CompositionStatus::Blocked,"matched no-offer control unavailable");
        require(frozen.status==a::CompositionStatus::Complete||frozen.status==a::CompositionStatus::Blocked,"matched frozen-peer control unavailable");
        for(const auto* control:{&no_offer,&frozen}){
            require(candidate.rounds.front().frame.result.cells==control->rounds.front().frame.result.cells&&
                candidate.rounds.front().frame.result.provenance==control->rounds.front().frame.result.provenance&&
                candidate.rounds.front().mosaic.result.cells==control->rounds.front().mosaic.result.cells&&
                candidate.rounds.front().mosaic.result.provenance==control->rounds.front().mosaic.result.provenance&&
                candidate.rounds.front().mosaic.categories==control->rounds.front().mosaic.categories,
                "causal comparison changed initial native plans");
            require(candidate.rounds.front().frame_work==control->rounds.front().frame_work&&
                candidate.rounds.front().mosaic_work==control->rounds.front().mosaic_work&&
                candidate.rounds.front().solver_work==control->rounds.front().solver_work,"causal comparison changed initial grants");
        }
        require(frozen.rounds.back().mosaic.result.cells==frozen.rounds.front().mosaic.result.cells,"frozen peer changed native material");
        require(material_footprint_difference(candidate.rounds.back().mosaic.result,no_offer.rounds.back().mosaic.result)>0,
            "MOSAIC has no offer-causal occupied footprint effect");
        require(material_footprint_difference(candidate.rounds.back().frame.result,frozen.rounds.back().frame.result)>0,
            "FRAME has no offer-causal occupied footprint effect");
    });
    test("generated authority permits pristine charged revalidation",[]{
        const auto original=a::assemble(small_input());within_envelope(original);
        require(original.can_apply&&original.status==a::CompositionStatus::Complete,"generated custody control must authorize Apply: "+original.reason);
        auto pristine=original;require(a::validate_composition(pristine)&&pristine.can_apply,"pristine authority failed: "+pristine.reason);
        require(pristine.cells==original.cells,"revalidation changed native materials");
        require(metric(pristine,"shared_work")>metric(original,"shared_work"),"revalidation was uncharged");within_envelope(pristine);
    });
    test("forged geometry ownership source work history and digests fail closed",[]{
        const auto original=a::assemble(small_input());require(original.can_apply,"tamper control not independently Apply-authorized: "+original.reason);
        must_refuse(original,"native work",[](auto& c){c.rounds.front().frame.result.work+=123;});
        must_refuse(original,"native solver work",[](auto& c){c.rounds.front().mosaic.result.solver_work+=17;});
        must_refuse(original,"retained proposal",[](auto& c){c.rounds.front().proposed_frame.cells[0]=Material::LimestoneBlock;});
        must_refuse(original,"owner",[](auto& c){c.rounds.front().frame.result.provenance[0]=1;});
        must_refuse(original,"role",[](auto& c){c.rounds.front().frame.result.roles[0]=Role::Brace;});
        must_refuse(original,"original core",[](auto& c){c.original_frame.core.cells[0]=Material::SteelPlate;});
        must_refuse(original,"history text",[](auto& c){c.rounds.front().reason+="; forged";});
        must_refuse(original,"final explanation",[](auto& c){c.reason="fabricated validation explanation";});
        must_refuse(original,"history ordinal",[](auto& c){c.rounds.front().number=1;});
        must_refuse(original,"material digest",[](auto& c){c.rounds.front().mosaic.result.material_digest^=123;});
        must_refuse(original,"geometry digest",[](auto& c){c.rounds.front().geometry_digest^=123;});
        must_refuse(original,"semantic digest",[](auto& c){c.rounds.front().semantic_digest^=123;});
        must_refuse(original,"false causal summary",[](auto& c){c.metrics["both_genteks_revised"]=1;c.metrics["frame_footprint_changed_rounds"]=2;});
        must_refuse(original,"refunded work",[](auto& c){for(const auto* k:{"frame_work","mosaic_work","solver_work","shared_work","total_charged_work"})c.metrics[k]=0;});
        must_refuse(original,"missing debit",[](auto& c){c.metrics.erase("solver_work");});
        must_refuse(original,"20MiB note",[](auto& c){c.rounds.front().mosaic.result.notes.emplace_back(20U*1024U*1024U,'x');});
        must_refuse(original,"control byte collision",[](auto& c){c.rounds.front().reason.push_back('\0');});
        must_refuse(original,"source identity",[](auto& c){c.input.frame.source_identity+="-another-world";c.input.mosaic.source_identity=c.input.frame.source_identity;});
        must_refuse(original,"original connector",[](auto& c){require(!c.original_frame.result.connectors.empty(),"native source has no connector");
            c.original_frame.result.connectors.front().required=!c.original_frame.result.connectors.front().required;});
        must_refuse(original,"receiver port",[](auto& c){Affordance p;p.id=255;p.instance=1;p.a=p.b={16,8};p.facing={-1,0};
            p.tag="swarm006/source-slot=1;connector=1";c.rounds.front().mosaic.result.boundary.hard.push_back(p);});
        must_refuse(original,"frontier",[](auto& c){c.rounds.front().recovery_frontier.push_back({1,100,0,true});});
        must_refuse(original,"opt-in downgrade",[](auto& c){c.input.options.negotiated_recovery=false;});
        must_refuse(original,"stop reason",[](auto& c){c.stop_reason="fabricated_full_closure";});
        must_refuse(original,"coherent public digest",[](auto& c){c.rounds.front().mosaic.result.material_digest^=7;
            c.rounds.front().geometry_digest=mix(c.rounds.front().frame.result.material_digest)^mix(c.rounds.front().mosaic.result.material_digest);});
    });
    test("public receipts and transplanted histories cannot mint native authority",[]{
        const auto original=a::assemble(small_input()),other=a::assemble(small_input(0,607));
        require(original.can_apply&&other.can_apply,"both transplant controls need genuine native authorization");
        a::Composition untrusted;copy_public_receipt(untrusted,original);
        require(!a::validate_composition(untrusted)&&!untrusted.can_apply&&untrusted.status==a::CompositionStatus::Invalid,"public JSON fields minted native authority");
        auto transplant=original;copy_public_receipt(transplant,other);
        require(!a::validate_composition(transplant)&&!transplant.can_apply&&transplant.status==a::CompositionStatus::Invalid,"seed/source authority transplant succeeded");
    });
    test("pending unjoined reservation survives until counteroffer advances the frontier",[]{
        auto u=receiver_unit();const auto source=u.source;a::MosaicBudget budget;const auto first=bid(u,budget);
        require(first.status==a::MosaicRevisionStatus::Complete&&first.recovery_receipts.size()==1,"first native bearing not reserved: "+first.reason);
        require(first.recovery_receipts.front().contact==u.first,"first native alternative order changed");
        const auto pending=bid(u,budget,2,&first.plan,&first.recovery_receipts,&first.recovery_frontier);
        require(pending.status==a::MosaicRevisionStatus::Complete&&pending.recovery_receipts==first.recovery_receipts,"bid did not live through a complete immutable FRAME reply");
        require(!pending.recovery_frontier_exhausted,"pending unjoined reservation falsely exhausted its authorized frontier");
        const auto counter=bid(u,budget,3,&pending.plan,&pending.recovery_receipts,&pending.recovery_frontier);
        require(counter.status==a::MosaicRevisionStatus::Complete&&counter.recovery_receipts.size()==1,"later real native bearing not reserved: "+counter.reason);
        require(std::any_of(counter.recovery_attempts.begin(),counter.recovery_attempts.end(),[](const auto& r){return r.phase=="counteroffer"&&r.outcome=="withdrawn"&&r.work>0;}),
            "failed choice disappeared without a charged withdrawal receipt");
        require(counter.recovery_receipts.front().contact==u.second&&counter.recovery_receipts.front().candidate>first.recovery_receipts.front().candidate,
            "receiver repeated first bid instead of advancing to another finite interface point");
        require(counter.recovery_work>0&&budget.generator_remaining<2'000'000&&budget.solver_remaining==4'000'000,"native receiver search was free or spent an unreported categorical solve");
        require(u.source.cells==source.cells&&u.source.provenance==source.provenance&&u.source.connectors.front().required&&!u.source.connectors.front().fulfilled,
            "MOSAIC changed or falsely fulfilled a frozen source obligation");
        const auto& receipt=counter.recovery_receipts.front();const auto port=std::find_if(counter.plan.result.boundary.hard.begin(),counter.plan.result.boundary.hard.end(),
            [&](const auto& p){return p.id==receipt.port_id;});
        require(port!=counter.plan.result.boundary.hard.end()&&port->instance==receipt.receiving_instance&&port->tag=="swarm006/source-slot=1;connector=1"&&
            port->family==Family::Frame&&port->facing==Point{-1,0},"reservation lost exact source binding, typed family, facing or receiver owner");
    });
    test("public recovery rejects malformed geometry and unbounded metadata",[]{
        const auto original=receiver_unit();
        const auto reject=[&](const char* label,const std::function<void(ReceiverUnit&)>& mutate){auto u=original;mutate(u);a::MosaicBudget budget;const auto r=bid(u,budget);
            require(r.status==a::MosaicRevisionStatus::Invalid&&r.recovery_receipts.empty(),std::string("malformed input admitted: ")+label+" / "+r.reason);};
        reject("INT_MIN facing",[](auto& u){u.slots[0].facing.x=std::numeric_limits<int>::min();});
        reject("overflowing envelope",[](auto& u){u.slots[0].envelope.x=std::numeric_limits<int>::max();u.slots[0].envelope.w=20;});
        reject("NaN strength",[](auto& u){u.slots[0].strength=std::numeric_limits<double>::quiet_NaN();});
        reject("diagonal facing",[](auto& u){u.slots[0].facing={1,1};});
        reject("slot capacity",[](auto& u){u.slots.resize(9,u.slots.front());});
        reject("clearance capacity",[](auto& u){u.slots[0].clearance.resize(4097);});
        reject("slot reason",[](auto& u){u.slots[0].reason.assign(4096,'x');});
        reject("missing source mask",[](auto& u){u.input.frame.eligible.clear();});
        reject("short shared mask",[](auto& u){u.input.shared_zone.resize(1);});
        reject("invalid shared value",[](auto& u){u.input.shared_zone[0]=2;});
        reject("invalid material",[](auto& u){u.source.cells[0]=static_cast<Material>(10);});
        reject("outside footprint",[](auto& u){u.source.instances[0].cells.push_back({-1,0});});
        reject("undefined owner",[](auto& u){u.source.provenance[index(u.input.frame,u.slots[0].a)]=255;});
        reject("invalid category",[](auto& u){u.mosaic.categories[0]=65535;});
        reject("oversized transition plane",[](auto& u){u.mosaic.result.boundary.transition.resize(1025);});
        reject("nonbinary transition plane",[](auto& u){u.mosaic.result.boundary.transition.assign(1024,2);});
        reject("20MiB note",[](auto& u){u.source.notes.emplace_back(20U*1024U*1024U,'x');});
        reject("20MiB connector state",[](auto& u){u.source.connectors[0].state.assign(20U*1024U*1024U,'x');});
        reject("20MiB definition",[](auto& u){u.source.definition_fingerprint.assign(20U*1024U*1024U,'x');});
        reject("20MiB preference",[](auto& u){SoftAffordance p;p.point={12,8};p.preference.assign(20U*1024U*1024U,'x');u.source.boundary.soft.push_back(p);});
    });
    test("incoming receipt and frontier payloads are bounded before proposal copies",[]{
        auto u=receiver_unit();a::MosaicBudget full;const auto first=bid(u,full);
        require(first.status==a::MosaicRevisionStatus::Complete&&!first.recovery_receipts.empty(),"receipt bound control failed");
        auto receipts=first.recovery_receipts;receipts[0].edits.resize(400'000);
        a::MosaicBudget huge;require(bid(u,huge,2,&first.plan,&receipts,&first.recovery_frontier).status==a::MosaicRevisionStatus::Invalid,
            "oversized edits copied before the finite native receipt bound");
        receipts=first.recovery_receipts;receipts[0].slot=999;
        a::MosaicBudget unrelated;require(bid(u,unrelated,2,&first.plan,&receipts,&first.recovery_frontier).status==a::MosaicRevisionStatus::Invalid,
            "unrelated incoming receipt exceeded the source reservation capacity");
        auto frontier=first.recovery_frontier;frontier.push_back(frontier.front());
        a::MosaicBudget duplicate;require(bid(u,duplicate,2,&first.plan,&first.recovery_receipts,&frontier).status==a::MosaicRevisionStatus::Invalid,
            "duplicate incoming cursor exceeded the source frontier capacity");
    });
    test("one provisional native receiver cannot borrow another reservation's Stone conversion",[]{
        // Explicit dependency unit, never a generated architecture or success
        // claim. A and B have disjoint corbels but would share one native host.
        auto input=small_input(4);Result source=begin_result(input.frame,"swarm006/dependency-unit-frame");
        std::vector<TransitionSlot> slots;
        for(unsigned id=1;id<=2;++id){const Point root=id==1?Point{8,10}:Point{14,8};const Point facing=id==1?Point{1,0}:Point{0,1};
            Instance p;p.id=id;p.kind="protocol-unit/steel-face";p.origin=root;p.cells={root};source.instances.push_back(p);
            const auto i=index(input.frame,root);source.cells[i]=Material::SteelPlate;source.roles[i]=Role::Structure;source.provenance[i]=id;
            Connector c;c.id=c.instance=id;c.a=c.b=root;c.facing=facing;c.required=true;source.connectors.push_back(c);
            TransitionSlot s;s.id=s.instance=s.connector=id;s.a=s.b=root;s.facing=facing;s.envelope={0,0,32,32};s.required=s.hard=true;slots.push_back(s);
        }
        finish_result(input.frame,source);
        MosaicPlan plan;auto expanded=input.mosaic;
        for(std::size_t i=0;i<expanded.eligible.size();++i)expanded.eligible[i]=static_cast<std::uint8_t>(expanded.eligible[i]||input.shared_zone[i]);
        plan.result=begin_result(expanded,"swarm006/dependency-unit-masonry");plan.categories.assign(4,1);
        Instance host;host.id=1;host.kind=mosaic_category_name(1);host.origin={12,10};host.cells={{12,10},{12,11}};
        plan.result.instances.push_back(host);
        for(auto p:host.cells){const auto i=index(expanded,p);plan.result.cells[i]=Material::Stone;plan.result.roles[i]=Role::Structure;plan.result.provenance[i]=1;}
        finish_result(expanded,plan.result);
        const std::vector<a::RecoveryCursor> frontier{{1,14,source.material_digest,false},{2,15,source.material_digest,false}};
        a::MosaicBudget budget;const auto r=a::propose_mosaic_recovery(input.mosaic,input.frame,source,source,slots,input.shared_zone,plan,{},frontier,budget,1);
        require(r.status==a::MosaicRevisionStatus::Complete,"dependency unit did not finish its bounded search: "+r.reason);
        require(std::any_of(r.recovery_receipts.begin(),r.recovery_receipts.end(),[](const auto& x){return x.slot==1&&x.contact==Point{10,10}&&x.host==Point{12,10};}),
            "A did not create the declared native host conversion");
        require(std::none_of(r.recovery_receipts.begin(),r.recovery_receipts.end(),[](const auto& x){return x.slot==2&&x.contact==Point{14,10}&&x.host==Point{12,10};}),
            "B borrowed A's provisional host conversion and could become unsupported after withdrawal");
        require(std::any_of(r.recovery_attempts.begin(),r.recovery_attempts.end(),[](const auto& x){return x.slot==2&&x.ordinal==15&&
            x.outcome=="rejected"&&x.reason=="competing_territorial_claim: provisional native backing dependency";}),
            "shared host dependency lacks a charged conflict receipt");
    });
    test("competing native offers retain distinct source-bound receiving reservations",[]{
        auto u=receiver_unit();auto connector=u.source.connectors.front();connector.id=2;u.source.connectors.push_back(connector);
        auto slot=u.slots.front();slot.id=slot.connector=2;u.slots.push_back(slot);finish_result(u.input.frame,u.source);
        a::MosaicBudget budget;const auto result=bid(u,budget);
        require(result.status==a::MosaicRevisionStatus::Complete&&result.recovery_receipts.size()==2,
            "competing native sources did not receive separate finite interface reservations");
        require(result.recovery_receipts[0].contact!=result.recovery_receipts[1].contact&&
            result.recovery_receipts[0].port_id!=result.recovery_receipts[1].port_id,"competing source claims shared a single native socket");
        require(std::any_of(result.recovery_attempts.begin(),result.recovery_attempts.end(),[](const auto& r){
            return r.outcome=="rejected"&&r.reason.starts_with("competing_territorial_claim");}),"competing claim produced no explicit failed alternative");
        for(const auto& receipt:result.recovery_receipts){const auto port=std::find_if(result.plan.result.boundary.hard.begin(),result.plan.result.boundary.hard.end(),
            [&](const auto& p){return p.id==receipt.port_id;});
            require(port!=result.plan.result.boundary.hard.end()&&receipt.slot==receipt.connector&&
                port->tag=="swarm006/source-slot="+std::to_string(receipt.slot)+";connector="+std::to_string(receipt.connector),
                "reservation consumed a different source's connector identity");}
        for(const auto& source:u.source.connectors)require(source.required&&!source.fulfilled,"reservation was falsely reported as a fulfilled foreign obligation");
    });
    test("receiver finalization admission preserves exact successful debit and refuses before an unfunded edit",[]{
        auto u=receiver_unit();a::MosaicBudget measured;const auto complete=bid(u,measured);
        require(complete.status==a::MosaicRevisionStatus::Complete&&complete.recovery_receipts.size()==1,"finalization control did not reserve a receiver");
        finalized_snapshot_matches(complete);
        a::MosaicBudget exact;exact.generator_remaining=complete.recovery_work;const auto admitted=bid(u,exact);
        require(admitted.status==a::MosaicRevisionStatus::Complete&&exact.generator_remaining==0&&
            admitted.recovery_work==complete.recovery_work&&admitted.plan.result.cells==complete.plan.result.cells,
            "finalization reserve increased the existing successful work debit");
        a::MosaicBudget short_by_one;short_by_one.generator_remaining=complete.recovery_work-1;
        const auto grant=short_by_one.generator_remaining;const auto refused=bid(u,short_by_one);
        require(refused.status==a::MosaicRevisionStatus::Exhausted&&refused.plan.result.status==Status::Exhausted&&
            refused.plan.result.cells.empty()&&refused.recovery_receipts.empty()&&refused.recovery_raster_work==0,
            "unfunded finalization retained a changed or Complete native proposal");
        require(refused.recovery_work==complete.recovery_work-complete.recovery_raster_work&&
            grant-short_by_one.generator_remaining==refused.recovery_work,"pre-mutation refusal hid or refunded charged search work");
        require(!refused.recovery_attempts.empty()&&refused.recovery_attempts.back().outcome=="rejected"&&
            refused.recovery_attempts.back().reason=="budget_exhaustion: native receiver snapshot finalization",
            "unfunded receiver candidate lost its charged rejection receipt");
        material_cache_matches(refused.plan.result);
    });
    test("a funded provisional receiver retains truthful cached evidence when later search exhausts",[]{
        auto u=receiver_unit();auto connector=u.source.connectors.front();connector.id=2;u.source.connectors.push_back(connector);
        auto slot=u.slots.front();slot.id=slot.connector=2;u.slots.push_back(slot);finish_result(u.input.frame,u.source);
        const auto original_cells=u.mosaic.result.cells;const auto original_digest=u.mosaic.result.digest;
        a::MosaicBudget measured;const auto complete=bid(u,measured);
        require(complete.status==a::MosaicRevisionStatus::Complete&&complete.recovery_receipts.size()==2&&
            complete.recovery_receipts.front().variant==0,"two-receiver accounting control unavailable");
        auto wrapper=complete.recovery_work-complete.recovery_raster_work;
        for(const auto& attempt:complete.recovery_attempts)wrapper-=attempt.work;
        std::uint64_t prefix=0;std::size_t first_reserved=0;
        for(;first_reserved<complete.recovery_attempts.size();++first_reserved){prefix+=complete.recovery_attempts[first_reserved].work;
            if(complete.recovery_attempts[first_reserved].outcome=="reserved")break;}
        require(first_reserved+1<complete.recovery_attempts.size(),"two-receiver control has no later search debit");
        const auto raster=u.mosaic.result.cells.size()*12ULL+u.mosaic.result.instances.size()*64ULL+
            (u.mosaic.result.boundary.hard.size()+1U)*32ULL;
        a::MosaicBudget limited;limited.generator_remaining=wrapper+prefix+raster+complete.recovery_attempts[first_reserved+1].work-1;
        const auto grant=limited.generator_remaining;const auto refused=bid(u,limited);
        require(refused.status==a::MosaicRevisionStatus::Exhausted&&refused.plan.result.status==Status::Exhausted&&
            refused.recovery_receipts.size()==1&&refused.recovery_attempts.size()==first_reserved+1,
            "late refusal lost its actual provisional receiver or retained nested Complete");
        require(refused.recovery_raster_work==raster&&refused.recovery_work==wrapper+prefix+raster&&
            grant-limited.generator_remaining==refused.recovery_work,"failed snapshot finalization was unfunded, doubled or refunded");
        finalized_snapshot_matches(refused);
        require(u.mosaic.result.cells==original_cells&&u.mosaic.result.digest==original_digest,"failed provisional snapshot changed the caller's accepted plan");
    });
    test("withdrawn provisional geometry is finalized under the reserved allowance on exhaustion",[]{
        auto u=receiver_unit();a::MosaicBudget initial;const auto first=bid(u,initial);
        require(first.status==a::MosaicRevisionStatus::Complete&&first.recovery_receipts.size()==1,"withdrawal control unavailable");
        const auto retained_cells=first.plan.result.cells;const auto retained_digest=first.plan.result.digest;
        a::MosaicBudget measured;const auto third=bid(u,measured,3,&first.plan,&first.recovery_receipts,&first.recovery_frontier);
        require(third.status==a::MosaicRevisionStatus::Complete&&third.recovery_attempts.size()>1&&
            third.recovery_attempts.front().outcome=="withdrawn","withdrawal control has no subsequent candidate search");
        auto wrapper=third.recovery_work-third.recovery_raster_work;
        for(const auto& attempt:third.recovery_attempts)wrapper-=attempt.work;
        const auto raster=u.mosaic.result.cells.size()*12ULL+u.mosaic.result.instances.size()*64ULL+u.mosaic.result.boundary.hard.size()*32ULL;
        const auto withdrawn=third.recovery_attempts.front().work;
        const auto preceding_raster=first.plan.result.cells.size()*12ULL+first.plan.result.instances.size()*64ULL+
            first.plan.result.boundary.hard.size()*32ULL;
        a::MosaicBudget unadmitted;unadmitted.generator_remaining=wrapper+withdrawn+preceding_raster-1;
        const auto unadmitted_grant=unadmitted.generator_remaining;
        const auto empty=bid(u,unadmitted,3,&first.plan,&first.recovery_receipts,&first.recovery_frontier);
        require(empty.status==a::MosaicRevisionStatus::Exhausted&&empty.plan.result.status==Status::Exhausted&&
            empty.plan.result.cells.empty()&&empty.recovery_receipts.empty()&&empty.recovery_raster_work==0,
            "empty refused withdrawal copied receiver receipts for absent proposal geometry");
        require(empty.recovery_attempts.size()==1&&empty.recovery_attempts.front().phase=="counteroffer"&&
            empty.recovery_attempts.front().outcome=="rejected"&&empty.recovery_attempts.front().work==withdrawn&&
            empty.recovery_work==wrapper+withdrawn&&unadmitted_grant-unadmitted.generator_remaining==empty.recovery_work,
            "unfunded withdrawal lost its charged attempt when clearing copied receiver receipts");
        a::MosaicBudget limited;limited.generator_remaining=wrapper+withdrawn+raster+third.recovery_attempts[1].work-1;
        const auto grant=limited.generator_remaining;
        const auto refused=bid(u,limited,3,&first.plan,&first.recovery_receipts,&first.recovery_frontier);
        require(refused.status==a::MosaicRevisionStatus::Exhausted&&refused.plan.result.status==Status::Exhausted&&
            refused.recovery_receipts.empty()&&refused.recovery_attempts.size()==1&&refused.recovery_attempts.front().outcome=="withdrawn"&&
            refused.plan.result.cells==u.mosaic.result.cells,"withdrawal refusal lost actual edited geometry or retained nested Complete");
        require(refused.recovery_raster_work==raster&&refused.recovery_work==wrapper+withdrawn+raster&&
            grant-limited.generator_remaining==refused.recovery_work,"withdrawal finalization did not retain its exact paid work");
        finalized_snapshot_matches(refused);
        require(first.plan.result.cells==retained_cells&&first.plan.result.digest==retained_digest,"failed withdrawal changed the immutable accepted prior snapshot");
    });
    test("four revealed HOLDOUT001 rejected histories remain fail closed with consistent native snapshots",[]{
        // Exact revealed cases from issue704 comments7062552183/7062877115.
        // These are successor robustness regressions, never an unseen holdout.
        for(const auto seed:{1997581108ULL,1376230570ULL})for(const auto rounds:{3U,4U}) {
            auto p=a::expression_profile("industrial");p.clutter=0; // exact industrial_gui harness profile
            a::Options options;options.rounds=rounds;options.negotiated_recovery=true;
            options.compact_native_termination=true;options.supported_native_receptors=true;
            const auto input=a::input_for(fixture("foreign_solid"),p,seed,"swarm006-revealed-history-successor-regression",options);
            const auto candidate=a::assemble(input);within_envelope(candidate);
            require(candidate.status==a::CompositionStatus::Exhausted&&!candidate.can_apply&&candidate.cells.empty()&&candidate.joints.empty(),
                "revealed failed-history case was promoted into authorized geometry");
            require(candidate.rounds.size()==4,"revealed failure no longer retains its three attempted reciprocal rounds");
            const auto& failed=candidate.rounds.back();const auto& prior=candidate.rounds[candidate.rounds.size()-2];
            require(!failed.frame_accepted&&!failed.mosaic_accepted&&failed.mosaic.result.cells==prior.mosaic.result.cells&&
                failed.mosaic.result.digest==prior.mosaic.result.digest&&failed.frame.result.digest==prior.frame.result.digest,
                "failed reciprocal proposal replaced or relabeled a selected prior native plan");
            require(failed.proposed_mosaic.status==Status::Exhausted&&failed.proposed_mosaic.termination.starts_with("budget_exhaustion:"),
                "rejected receiver still claims nested completion");
            require(!failed.proposed_mosaic.cells.empty()||failed.mosaic_recovery_receipts.empty(),
                "empty rejected proposal claims receiving parts that only exist in a prior snapshot");
            for(const auto& round:candidate.rounds){material_cache_matches(round.mosaic.result);material_cache_matches(round.proposed_mosaic);}
            const auto reverse=a::assemble(input,true);within_envelope(reverse);
            require(reverse.status==candidate.status&&reverse.can_apply==candidate.can_apply&&reverse.metrics==candidate.metrics&&
                reverse.rounds.size()==candidate.rounds.size()&&reverse.rounds.back().proposed_mosaic.cells==failed.proposed_mosaic.cells&&
                reverse.rounds.back().proposed_mosaic.digest==failed.proposed_mosaic.digest&&
                reverse.rounds.back().recovery_attempts==failed.recovery_attempts,"revealed failure repair depends on invocation order");
        }
    });
    test("cancellation and resource refusals preserve immutable native inputs",[]{
        auto u=receiver_unit();const auto source=u.source.cells,masonry=u.mosaic.result.cells;
        std::atomic_bool cancelled=true;a::MosaicBudget stop;stop.cancelled=&cancelled;const auto stopped=bid(u,stop);
        require(stopped.status==a::MosaicRevisionStatus::Cancelled&&stopped.recovery_receipts.empty()&&stop.generator_remaining==2'000'000,
            "cancelled receiver manufactured output or spent work");
        require(stopped.plan.result.status==Status::Exhausted&&stopped.plan.result.cells.empty()&&stopped.plan.result.termination=="cancellation",
            "unexecuted cancellation retained nested Complete");
        a::MosaicBudget tiny;tiny.generator_remaining=1;const auto unfunded=bid(u,tiny);
        require(unfunded.status==a::MosaicRevisionStatus::Exhausted&&unfunded.recovery_receipts.empty()&&tiny.generator_remaining==1,
            "unfunded search ran before work admission");
        a::MosaicBudget memory;memory.max_bytes=1024;require(bid(u,memory).status==a::MosaicRevisionStatus::Exhausted,"native recovery exceeded memory allowance");
        a::MosaicBudget proposals;proposals.proposals_remaining=0;require(bid(u,proposals).status==a::MosaicRevisionStatus::Exhausted,"native recovery exceeded proposal allowance");
        a::MosaicBudget raised;raised.generator_remaining=2'000'001;require(bid(u,raised).status==a::MosaicRevisionStatus::Invalid,"native recovery raised the original work ceiling");
        a::MosaicBudget measured;const auto complete=bid(u,measured);
        require(complete.status==a::MosaicRevisionStatus::Complete,"reference wrapper measurement failed");
        auto wrapper=complete.recovery_work-complete.recovery_raster_work;
        for(const auto& candidate:complete.recovery_attempts)wrapper-=candidate.work;
        const auto attempt=1024ULL+u.mosaic.result.instances.size()*4ULL+u.mosaic.result.boundary.hard.size()*2ULL;
        a::MosaicBudget partial;partial.generator_remaining=wrapper+attempt*2-1;const auto grant=partial.generator_remaining;
        const auto failed=bid(u,partial);
        require(failed.status==a::MosaicRevisionStatus::Exhausted&&failed.recovery_attempts.size()==1&&failed.recovery_attempts.front().outcome=="rejected"&&
            failed.recovery_work==wrapper+attempt&&grant-partial.generator_remaining==failed.recovery_work,
            "failed candidate debit was refunded or omitted from exhaustion evidence");
        require(u.source.cells==source&&u.mosaic.result.cells==masonry,"failed receiver changed caller-owned native input");
        auto input=small_input(4);input.cancel=&cancelled;const auto c=a::assemble(input);
        require(c.status==a::CompositionStatus::Cancelled&&!c.can_apply&&c.cells.empty(),"cancelled native composition authorized Apply");
    });
    test("protected native paths produce bounded negative receiver evidence",[]{
        auto u=receiver_unit();
        for(const auto p:{Point{13,u.first.y},Point{13,u.second.y}}){const auto i=index(u.input.mosaic,p);
            u.input.mosaic.protected_void[i]=u.input.frame.protected_void[i]=1;}
        const auto before=u.mosaic.result.cells;const auto protection=u.input.mosaic.protected_void;a::MosaicBudget budget;const auto blocked=bid(u,budget);
        require(blocked.status==a::MosaicRevisionStatus::Complete&&blocked.recovery_receipts.empty()&&blocked.recovery_attempts.size()==64,
            "protected-span unit should retain64 failed native bids and no invented receiver");
        require(!blocked.recovery_frontier_exhausted&&blocked.recovery_frontier.size()==1&&blocked.recovery_frontier.front().next==64,
            "bounded negative search lost its remaining authorized alternatives");
        require(std::all_of(blocked.recovery_attempts.begin(),blocked.recovery_attempts.end(),[](const auto& r){return r.outcome=="rejected"&&r.work>0&&!r.reason.empty();}),
            "negative attempts lost diagnostic reasons or debits");
        require(blocked.plan.result.cells==before&&u.mosaic.result.cells==before&&u.input.mosaic.protected_void==protection,
            "failed receiver negotiation filled protected negative space or changed live caller state");
    });
    test("OFF preserves seed4099 qualified native control and reverse invocation",[]{
        auto input=a::input_for(fixture("island"),profile("branching_irregular"),4099,"swarm006-off-known-positive-control");
        input.options.negotiated_recovery=false;const auto original=a::assemble(input);within_envelope(original);
        require(original.can_apply&&original.status==a::CompositionStatus::Complete&&!original.joints.empty()&&metric(original,"still_required")==0,
            "original reciprocal positive was lost with recovery OFF");
        input.options.recovery_offers=false;const auto disabled=a::assemble(input,true);
        require(disabled.can_apply&&disabled.digest==original.digest&&disabled.cells==original.cells&&disabled.metrics==original.metrics,
            "disabled recovery control or reverse evaluation changed native behavior");
    });
    test("round caps and matched controls retain exact initial native source",[]{
        for(unsigned rounds=0;rounds<=4;++rounds){auto input=small_input(rounds);const auto candidate=a::assemble(input);within_envelope(candidate);
            const auto reversed=a::assemble(input,true);within_envelope(reversed);
            require(candidate.status==reversed.status&&candidate.can_apply==reversed.can_apply&&candidate.digest==reversed.digest&&
                candidate.cells==reversed.cells&&candidate.metrics==reversed.metrics,"recovery differs under reverse proposal evaluation");
            auto no_offers=input;no_offers.options.recovery_offers=false;const auto control=a::assemble(no_offers);within_envelope(control);
            auto frozen_peer=input;frozen_peer.options.mosaic_adaptation=false;const auto frozen=a::assemble(frozen_peer);within_envelope(frozen);
            require(!candidate.rounds.empty()&&!control.rounds.empty()&&!frozen.rounds.empty(),"controls lost initial source history");
            for(const auto* compared:{&control,&frozen})require(compared->original_frame.result.cells==candidate.original_frame.result.cells&&
                compared->rounds.front().frame.result.cells==candidate.rounds.front().frame.result.cells&&
                compared->rounds.front().mosaic.result.cells==candidate.rounds.front().mosaic.result.cells&&
                compared->input.frame.eligible==candidate.input.frame.eligible&&compared->input.mosaic.eligible==candidate.input.mosaic.eligible&&compared->input.shared_zone==candidate.input.shared_zone,
                "matched controls changed original native geometry or authorized territory");
            for(const auto& r:frozen.rounds)require(r.mosaic.result.cells==frozen.rounds.front().mosaic.result.cells,"frozen peer revised native masonry");
            for(const auto& r:control.rounds)require(r.mosaic_recovery_receipts.empty(),"no-offer control published source-bound receivers");
        }
    });
    test("maximum dimensions and adversarial protected geometry stay bounded",[]{
        auto input=small_input(4);constexpr int width=256,height=128;constexpr std::size_t n=width*height;
        for(auto* q:{&input.frame,&input.mosaic}){q->width=width;q->height=height;q->activation.clear();q->eligible.assign(n,0);q->transition.assign(n,0);
            q->protected_void.assign(n,0);q->context.assign(n,Material::Empty);q->neighbor_cells.clear();q->neighbors={};}
        input.shared_zone.assign(n,0);
        for(int y=0;y<height;++y)for(int x=0;x<width;++x){const auto i=static_cast<std::size_t>(y*width+x);
            input.frame.eligible[i]=x<128;input.mosaic.eligible[i]=x>=128;const auto band=static_cast<std::uint8_t>(x>=115&&x<=140);
            input.frame.transition[i]=input.mosaic.transition[i]=input.shared_zone[i]=band;
            input.frame.protected_void[i]=input.mosaic.protected_void[i]=static_cast<std::uint8_t>((x%17==0&&y%5<3)||y==63);
            if(y>20&&y<100&&x%29==0)input.frame.context[i]=input.mosaic.context[i]=Material::LimestoneBlock;}
        const auto context=input.frame.context;const auto protected_cells=input.frame.protected_void;const auto c=a::assemble(input);within_envelope(c);
        require(input.frame.context==context&&input.mosaic.context==context&&input.frame.protected_void==protected_cells,"adversarial search mutated immutable context");
        if(metric(c,"conservative_memory_bound_bytes")>16U*1024U*1024U)require(c.status==a::CompositionStatus::Exhausted&&!c.can_apply&&c.rounds.empty(),
            "over-limit history was allocated or authorized instead of refused before generation");
    });
    std::cout<<"SWARM006 recovery: "<<passed<<" groups passed, "<<failed<<" failed; "<<assertions<<" assertions\n";
    return failed?1:0;
}
