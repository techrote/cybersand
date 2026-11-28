#include "reciprocal_mosaic.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <set>
#include <stdexcept>
#include <tuple>

namespace cybersand::gentek_swarm::assembly004 {
namespace {
Point add(Point a,Point b){return {a.x+b.x,a.y+b.y};}
Point mul(Point a,int s){return {a.x*s,a.y*s};}
Point neg(Point a){return {-a.x,-a.y};}
bool structural(Role r){return r==Role::Structure||r==Role::Brace||r==Role::Transition;}
bool bearing_material(Material m){return m==Material::Stone||(m!=Material::Empty&&material_definition(m).state==MaterialState::Solid);}
bool solid(Material m){return m!=Material::Empty&&material_definition(m).state==MaterialState::Solid;}
bool mask(const std::vector<std::uint8_t>& v,std::size_t i){return !v.empty()&&v[i]!=0;}
bool in_box(Point p,Rect r){return p.x>=r.x&&p.y>=r.y&&p.x<r.x+r.w&&p.y<r.y+r.h;}
bool usable(const Result& r){return r.status==Status::Complete||r.status==Status::Blocked;}
unsigned rotation(Point d){return d.x==1?0U:d.y==1?1U:d.x==-1?2U:3U;}
std::string tag(const MosaicRecoveryReceipt& r){return "swarm006/source-slot="+std::to_string(r.slot)+";connector="+std::to_string(r.connector);}

struct Candidate {Point root{},contact{},axis{},cross{};unsigned length{},variant{};};
std::vector<Candidate> catalogue(const TransitionSlot& slot) {
    // A fixed, authored catalogue, not a seed search or data-dependent budget.
    // Two endpoints at most; the complete original face stays in the receipt.
    std::vector<Point> roots{slot.a};if(slot.b!=slot.a)roots.push_back(slot.b);
    std::vector<Candidate> candidates;
    const Point tangent{-slot.facing.y,slot.facing.x};
    for(const auto root:roots)for(unsigned distance=1;distance<=14;++distance)
        candidates.push_back({root,add(root,mul(slot.facing,static_cast<int>(distance))),{}, {},0,0});
    for(const auto length:{2U,4U,6U})for(const auto root:roots)for(unsigned distance=2;distance<=14;++distance) {
        const auto contact=add(root,mul(slot.facing,static_cast<int>(distance)));
        for(unsigned variant=1;variant<=3;++variant) {
            const auto axis=variant==1?slot.facing:variant==2?tangent:neg(tangent);
            const auto cross=variant==1?tangent:slot.facing;
            candidates.push_back({root,contact,axis,cross,length,variant});
        }
    }
    return candidates;
}

bool currently_joined(const Request& q,const Result& peer,const MosaicRecoveryReceipt& receipt) {
    const auto face=add(receipt.contact,receipt.backing==receipt.contact?Point{}:neg(Point{
        receipt.backing.x-receipt.contact.x,receipt.backing.y-receipt.contact.y}));
    if(!inside(q,face)||!inside(q,receipt.root))return false;
    // This is only a reservation-retention predicate. The authoritative BFS,
    // typed grammar and original-obligation validator still prove the joint.
    const Point d{receipt.backing.x-receipt.contact.x,receipt.backing.y-receipt.contact.y};
    const int length=std::abs(face.x-receipt.root.x)+std::abs(face.y-receipt.root.y);
    if(length>14||face!=add(receipt.root,mul(d,length)))return false;
    for(int k=0;k<=length;++k) {
        const auto i=index(q,add(receipt.root,mul(d,k)));
        if(!solid(peer.cells[i])||!structural(peer.roles[i]))return false;
    }
    return true;
}
}

MosaicRevision propose_mosaic_recovery(const Request& base,const Request& frame_request,
    const Result& peer,const Result& original_source,const std::vector<TransitionSlot>& original_slots,
    const std::vector<std::uint8_t>& shared_zone,const MosaicPlan& previous,
    const std::vector<MosaicRecoveryReceipt>& receipts,const std::vector<RecoveryCursor>& frontier,
    MosaicBudget& budget,unsigned round,bool optional_negotiation) {
    MosaicRevision out;out.round=round;
    // A provisional edit must remain reportable even if the next search debit
    // fails. Keep its finalization allowance unavailable to search, without
    // charging work until finalization actually runs. This uses the existing
    // raster cost and generator ceiling; no spent candidate work is refunded.
    std::uint64_t finalization_reserve=0;
    const auto finalization_cost=[&](std::size_t instances,std::size_t ports){
        return out.plan.result.cells.size()*12ULL+instances*64ULL+ports*32ULL;
    };
    const auto finalize_snapshot=[&](){
        auto& result=out.plan.result;
        const auto cost=finalization_cost(result.instances.size(),result.boundary.hard.size());
        if(cost>finalization_reserve||cost>budget.generator_remaining)
            throw std::logic_error("unfunded native recovery snapshot finalization");
        budget.generator_remaining-=cost;out.wrapper_work+=cost;out.recovery_work+=cost;
        out.recovery_raster_work=cost;finalization_reserve=0;
        // Already admitted cleanup must also run after cancellation. It never
        // authorizes this failed proposal or resumes the candidate search.
        finish_result(out.request,result);
    };
    const auto fail=[&](MosaicRevisionStatus status,const std::string& why){
        out.status=status;out.reason=why;
        if(!finalization_reserve) {
            // No provisional mutation was admitted. The selected prior plan is
            // retained by the coordinator; do not publish its Complete cache as
            // though it described an executed, refused receiver proposal.
            out.plan={};out.plan.result.gentek=Kind::Mosaic;
            // These receipts describe the proposal's receiving parts. With no
            // proposal plane they cannot be copied forward as geometry claims;
            // the accepted prior snapshot still owns its original receipts.
            out.recovery_receipts.clear();
        }
        auto& result=out.plan.result;
        result.status=status==MosaicRevisionStatus::Exhausted||status==MosaicRevisionStatus::Cancelled?
            Status::Exhausted:status==MosaicRevisionStatus::Unsat?Status::Unsat:Status::Invalid;
        result.termination=why;
        if(finalization_reserve)finalize_snapshot();
    };
    const auto cancelled=[&](){return budget.cancelled&&budget.cancelled->load(std::memory_order_relaxed);};
    const auto debit=[&](std::uint64_t work) {
        if(cancelled()){fail(MosaicRevisionStatus::Cancelled,"cancellation");return false;}
        if(work>budget.generator_remaining||finalization_reserve>budget.generator_remaining-work){
            fail(MosaicRevisionStatus::Exhausted,"budget_exhaustion: native receiver search");return false;}
        budget.generator_remaining-=work;out.wrapper_work+=work;out.recovery_work+=work;return true;
    };
    const auto reserve_finalization=[&](std::size_t instances,std::size_t ports){
        if(cancelled()){fail(MosaicRevisionStatus::Cancelled,"cancellation");return false;}
        const auto cost=finalization_cost(instances,ports);
        if(cost>budget.generator_remaining){
            fail(MosaicRevisionStatus::Exhausted,"budget_exhaustion: native receiver snapshot finalization");return false;}
        finalization_reserve=std::max<std::uint64_t>(finalization_reserve,cost);
        out.plan.result.implementation="gentek_swarm_006_mosaic_native_recovery_v1";
        return true;
    };
    std::string why;
    if(!validate_request(base,why)||!validate_request(frame_request,why)||base.gentek!=Kind::Mosaic||
       frame_request.gentek!=Kind::Frameweaver||base.width!=frame_request.width||base.height!=frame_request.height||
       base.seed!=frame_request.seed||base.source_identity!=frame_request.source_identity||round<1||round>4||
       budget.generator_remaining>2'000'000||budget.solver_remaining>4'000'000||budget.max_bytes>16U*1024U*1024U||
       original_slots.size()>8||receipts.size()>8||frontier.size()>8) {
        fail(MosaicRevisionStatus::Invalid,"invalid bounded recovery input: "+why);return out;
    }
    const auto n=static_cast<std::size_t>(base.width)*static_cast<std::size_t>(base.height);
    // Reserve before traversing native footprints or rich metadata. Ordinary
    // generated inputs retain the established wrapper debit; unusually dense
    // public inputs pay the larger measured admission bound, including failures.
    std::uint64_t input_work=n*4ULL+8192ULL;
    for(const auto* result:{&peer,&original_source,&previous.result}) {
        if(result->instances.size()>256||result->connectors.size()>2048||result->attachments.size()>2048||
           result->boundary.hard.size()>256||result->boundary.soft.size()>256||result->notes.size()>64||
           result->metrics.size()>256||result->rejected.size()>256) {
            fail(MosaicRevisionStatus::Invalid,"unbounded native input before admission");return out;
        }
        std::size_t points=0;
        for(const auto& part:result->instances){
            if(part.cells.size()>n||points>n*8ULL-part.cells.size()){
                fail(MosaicRevisionStatus::Invalid,"unbounded native footprint before admission");return out;}
            points+=part.cells.size();
        }
        input_work+=points+result->instances.size()*64ULL+result->connectors.size()*16ULL+
            result->attachments.size()*32ULL+(result->boundary.hard.size()+result->boundary.soft.size())*16ULL+
            (result->notes.size()+result->metrics.size()+result->rejected.size())*128ULL;
    }
    const auto wrapper_work=std::max<std::uint64_t>(input_work,n*8ULL+8192ULL+original_slots.size()*2048ULL);
    if(!debit(wrapper_work))return out;
    for(const auto* result:{&peer,&original_source,&previous.result}) {
        if(result->cells.size()!=n||result->roles.size()!=n||result->provenance.size()!=n||!usable(*result)||
           result->width!=base.width||result->height!=base.height||result->seed!=base.seed||
           result->source_identity!=base.source_identity||result->instances.size()>256||result->boundary.hard.size()>256||
           result->gentek!=(result==&previous.result?Kind::Mosaic:Kind::Frameweaver)||
           result->connectors.size()>2048||result->attachments.size()>2048||result->boundary.soft.size()>256||
           result->notes.size()>64||result->metrics.size()>256||result->rejected.size()>256||
           result->implementation.size()>128||result->definition_fingerprint.size()>128||result->source_identity.size()>256||result->termination.size()>2048||
           (!result->boundary.protected_geometry.empty()&&result->boundary.protected_geometry.size()!=n)||
           (!result->boundary.transition.empty()&&result->boundary.transition.size()!=n)) {
            fail(MosaicRevisionStatus::Invalid,"incomplete or mismatched native recovery planes");return out;
        }
        std::size_t total_footprints=0;std::set<std::uint32_t> ids;
        for(const auto& part:result->instances) {
            if(part.id==0||part.id>256||!ids.insert(part.id).second||part.kind.size()>128||part.reason.size()>1024||
               part.cells.size()>n||total_footprints>n*8ULL-part.cells.size()||
               (result==&previous.result&&part.cells.size()>256)) {
                fail(MosaicRevisionStatus::Invalid,"unbounded or invalid native part history");return out;
            }
            total_footprints+=part.cells.size();
            for(const auto p:part.cells)if(!inside(base,p)){fail(MosaicRevisionStatus::Invalid,"native part footprint outside canvas");return out;}
        }
        for(std::size_t i=0;i<n;++i)if(static_cast<unsigned>(result->cells[i])>131U||static_cast<unsigned>(result->cells[i])==10U||
            static_cast<unsigned>(result->roles[i])>static_cast<unsigned>(Role::Transition)||result->provenance[i]>256||
            (result->cells[i]!=Material::Empty&&!ids.contains(result->provenance[i]))||
            (!result->boundary.protected_geometry.empty()&&result->boundary.protected_geometry[i]>1)||
            (!result->boundary.transition.empty()&&result->boundary.transition[i]>1)) {
            fail(MosaicRevisionStatus::Invalid,"invalid native material, role or owner history");return out;
        }
        for(const auto& port:result->boundary.hard)if(!inside(base,port.a)||!inside(base,port.b)||port.tag.size()>96||
            static_cast<unsigned>(port.family)>static_cast<unsigned>(Family::Passage)||!std::isfinite(port.strength)||
            port.strength<0||port.strength>1||std::abs(static_cast<std::int64_t>(port.facing.x))+std::abs(static_cast<std::int64_t>(port.facing.y))>1) {
            fail(MosaicRevisionStatus::Invalid,"invalid typed native boundary history");return out;
        }
        for(const auto& note:result->notes)if(note.size()>4096){fail(MosaicRevisionStatus::Invalid,"unbounded native history note");return out;}
        for(const auto& connector:result->connectors)if(connector.state.size()>128||
            !inside(base,connector.a)||!inside(base,connector.b)||static_cast<unsigned>(connector.family)>static_cast<unsigned>(Family::Passage)||
            std::abs(static_cast<std::int64_t>(connector.facing.x))+std::abs(static_cast<std::int64_t>(connector.facing.y))>1){
            fail(MosaicRevisionStatus::Invalid,"invalid native connector metadata");return out;}
        for(const auto& attachment:result->attachments)if(attachment.kind.size()>128||attachment.reason.size()>2048||
            !inside(base,attachment.point)||!inside(base,attachment.target)){
            fail(MosaicRevisionStatus::Invalid,"invalid native attachment metadata");return out;}
        for(const auto& preference:result->boundary.soft)if(preference.preference.size()>96||!inside(base,preference.point)||
            !std::isfinite(preference.strength)||preference.strength<0||preference.strength>1||
            std::abs(static_cast<std::int64_t>(preference.direction.x))+std::abs(static_cast<std::int64_t>(preference.direction.y))>1){
            fail(MosaicRevisionStatus::Invalid,"invalid native architectural preference metadata");return out;}
        for(const auto& [key,value]:result->metrics){(void)value;if(key.size()>128){fail(MosaicRevisionStatus::Invalid,"unbounded native metric name");return out;}}
        for(const auto& [key,value]:result->rejected){(void)value;if(key.size()>128){fail(MosaicRevisionStatus::Invalid,"unbounded native rejection name");return out;}}
    }
    if(base.eligible.size()!=n||frame_request.eligible.size()!=n||shared_zone.size()!=n||
       previous.categories.size()!=static_cast<std::size_t>((base.width+15)/16)*static_cast<std::size_t>((base.height+15)/16)||
       std::any_of(shared_zone.begin(),shared_zone.end(),[](auto x){return x>1;})) {
        fail(MosaicRevisionStatus::Invalid,"malformed recovery shared/category planes");return out;
    }
    for(const auto category:previous.categories)if(category<0||category>15){fail(MosaicRevisionStatus::Invalid,"invalid native category identity");return out;}
    for(const auto& slot:original_slots)if(slot.clearance.size()>4096||slot.reason.size()>2048||slot.owner!="FRAMEWEAVER"||
        !std::isfinite(slot.strength)||slot.strength<=0||slot.strength>1||!inside(base,slot.a)||!inside(base,slot.b)||
        std::abs(static_cast<std::int64_t>(slot.facing.x))+std::abs(static_cast<std::int64_t>(slot.facing.y))!=1||
        slot.envelope.x<0||slot.envelope.y<0||slot.envelope.w<0||slot.envelope.h<0||
        static_cast<std::int64_t>(slot.envelope.x)+slot.envelope.w>base.width||
        static_cast<std::int64_t>(slot.envelope.y)+slot.envelope.h>base.height||
        static_cast<unsigned>(slot.kind)>static_cast<unsigned>(SlotKind::PassageOpening)) {
        fail(MosaicRevisionStatus::Invalid,"malformed bounded source reservation");return out;
    }
    std::set<std::uint32_t> source_ids,receipt_slots,receipt_ports,cursor_slots;
    std::set<Point> receipt_contacts,prior_edits;
    for(const auto& slot:original_slots)if(!source_ids.insert(slot.id).second){
        fail(MosaicRevisionStatus::Invalid,"duplicate original source slot");return out;}
    for(const auto& cursor:frontier){
        const auto slot=std::find_if(original_slots.begin(),original_slots.end(),[&](const auto& s){return s.id==cursor.slot;});
        if(slot==original_slots.end()||!cursor_slots.insert(cursor.slot).second||cursor.observation!=original_source.material_digest){
            fail(MosaicRevisionStatus::Invalid,"unknown or repeated source frontier");return out;}
        const auto size=(slot->a==slot->b?1U:2U)*131U;
        if(cursor.next>size||cursor.exhausted!=(cursor.next==size)){
            fail(MosaicRevisionStatus::Invalid,"inconsistent finite alternative frontier");return out;}
    }
    // All incoming histories are bounded and bound to real source identities
    // BEFORE copying their vectors or considering any additional reservation.
    for(const auto& receipt:receipts){
        const auto slot=std::find_if(original_slots.begin(),original_slots.end(),[&](const auto& s){return s.id==receipt.slot&&s.connector==receipt.connector;});
        const auto dx=static_cast<std::int64_t>(receipt.backing.x)-receipt.contact.x;
        const auto dy=static_cast<std::int64_t>(receipt.backing.y)-receipt.contact.y;
        if(slot==original_slots.end()||!receipt_slots.insert(receipt.slot).second||!receipt_ports.insert(receipt.port_id).second||
           !receipt_contacts.insert(receipt.contact).second||receipt.edits.size()>14||!receipt.round||receipt.round>=round||
           receipt.source_instance!=slot->instance||receipt.source_digest!=original_source.material_digest||
           !inside(base,receipt.root)||!inside(base,receipt.contact)||!inside(base,receipt.backing)||!inside(base,receipt.host)||
           std::abs(dx)+std::abs(dy)!=1||dx!=slot->facing.x||dy!=slot->facing.y||receipt.variant>3||receipt.length>6||
           !receipt.receiving_instance||receipt.receiving_instance>256||!receipt.host_instance||receipt.host_instance>256||!receipt.port_id||
           static_cast<unsigned>(receipt.source_family)>static_cast<unsigned>(Family::Brace)||
           static_cast<unsigned>(receipt.receiving_family)>static_cast<unsigned>(Family::Brace)){
            fail(MosaicRevisionStatus::Invalid,"malformed or unrelated preceding recovery receipt");return out;}
        for(const auto& edit:receipt.edits){
            if(!inside(base,edit.point)||!prior_edits.insert(edit.point).second||static_cast<unsigned>(edit.before)>131U||
               static_cast<unsigned>(edit.before)==10U||edit.after!=Material::LimestoneBlock||edit.before_owner>256||
               !edit.after_owner||edit.after_owner>256||static_cast<unsigned>(edit.before_role)>static_cast<unsigned>(Role::Transition)||
               !structural(edit.after_role)){
                fail(MosaicRevisionStatus::Invalid,"malformed or competing preceding native edit");return out;}
            const auto i=index(base,edit.point);
            if(previous.result.cells[i]!=edit.after||previous.result.roles[i]!=edit.after_role||previous.result.provenance[i]!=edit.after_owner){
                fail(MosaicRevisionStatus::Invalid,"preceding native edit differs from actual masonry");return out;}
        }
    }
    if(previous.domains.size()>128||previous.responses.size()>8||previous.attempts.size()>16) {
        fail(MosaicRevisionStatus::Invalid,"unbounded categorical history");return out;
    }
    for(const auto& domain:previous.domains) {
        if(domain.influences.size()>8){fail(MosaicRevisionStatus::Invalid,"unbounded category influences");return out;}
        for(const auto& influence:domain.influences)if(influence.reason.size()>1024){fail(MosaicRevisionStatus::Invalid,"unbounded category reason");return out;}
    }
    for(const auto& response:previous.responses)if(response.reason.size()>1024){fail(MosaicRevisionStatus::Invalid,"unbounded response reason");return out;}
    for(const auto& attempt:previous.attempts)if(attempt.reason.size()>2048||attempt.policy.size()>128){fail(MosaicRevisionStatus::Invalid,"unbounded solver history");return out;}
    // Admit retained allocations as well as field lengths before the first
    // proposal copy. Public callers cannot hide arbitrarily large capacities.
    std::uint64_t retained=n*32ULL+131072ULL;
    const auto memory=[&](std::uint64_t count,std::uint64_t size){
        if(retained>budget.max_bytes||count>(budget.max_bytes-retained)/size)return false;
        retained+=count*size;return true;};
    const auto text_memory=[&](const std::string& value){return memory(value.capacity()+1,1);};
    const auto result_memory=[&](const Result& r){
        if(!memory(r.cells.capacity(),sizeof(Material))||!memory(r.roles.capacity(),sizeof(Role))||
           !memory(r.provenance.capacity(),sizeof(std::uint32_t))||!memory(r.instances.capacity(),sizeof(Instance))||
           !memory(r.connectors.capacity(),sizeof(Connector))||!memory(r.attachments.capacity(),sizeof(Attachment))||
           !memory(r.boundary.hard.capacity(),sizeof(Affordance))||!memory(r.boundary.soft.capacity(),sizeof(SoftAffordance))||
           !memory(r.boundary.transition.capacity()+r.boundary.protected_geometry.capacity(),1)||
           !memory(r.notes.capacity(),sizeof(std::string))||!memory(r.metrics.size()+r.rejected.size(),128)||
           !text_memory(r.implementation)||!text_memory(r.definition_fingerprint)||!text_memory(r.source_identity)||!text_memory(r.termination))return false;
        for(const auto& p:r.instances)if(!memory(p.cells.capacity(),sizeof(Point))||!text_memory(p.kind)||!text_memory(p.reason))return false;
        for(const auto& x:r.connectors)if(!text_memory(x.state))return false;
        for(const auto& x:r.attachments)if(!text_memory(x.kind)||!text_memory(x.reason))return false;
        for(const auto& x:r.boundary.hard)if(!text_memory(x.tag))return false;
        for(const auto& x:r.boundary.soft)if(!text_memory(x.preference))return false;
        for(const auto& x:r.notes)if(!text_memory(x))return false;
        for(const auto& [key,value]:r.metrics){(void)value;if(!text_memory(key))return false;}
        for(const auto& [key,value]:r.rejected){(void)value;if(!text_memory(key))return false;}
        return true;
    };
    bool admitted=result_memory(peer)&&result_memory(original_source)&&result_memory(previous.result)&&result_memory(previous.result);
    admitted=admitted&&memory(previous.domains.capacity(),sizeof(DomainDecision))&&memory(previous.categories.capacity(),sizeof(int))&&
        memory(previous.responses.capacity(),sizeof(SlotResponse))&&memory(previous.attempts.capacity(),sizeof(SolverAttempt))&&
        memory(original_slots.capacity(),sizeof(TransitionSlot))&&memory(receipts.capacity(),sizeof(MosaicRecoveryReceipt))&&
        memory(frontier.capacity(),sizeof(RecoveryCursor));
    for(const auto& d:previous.domains){admitted=admitted&&memory(d.influences.capacity(),sizeof(DomainInfluence));
        for(const auto& x:d.influences)admitted=admitted&&text_memory(x.reason);}
    for(const auto& x:previous.responses)admitted=admitted&&text_memory(x.reason);
    for(const auto& x:previous.attempts)admitted=admitted&&text_memory(x.policy)&&text_memory(x.reason);
    for(const auto& x:original_slots)admitted=admitted&&memory(x.clearance.capacity(),sizeof(Point))&&text_memory(x.owner)&&text_memory(x.reason);
    for(const auto& x:receipts)admitted=admitted&&memory(x.edits.capacity(),sizeof(RecoveryEdit));
    if(!admitted){fail(MosaicRevisionStatus::Exhausted,"budget_exhaustion: retained native recovery metadata");return out;}
    out.memory_bound=std::max<std::uint64_t>(retained,n*160ULL+2U*1024U*1024U);
    if(out.memory_bound>budget.max_bytes||budget.proposals_remaining==0) {
        fail(MosaicRevisionStatus::Exhausted,"budget_exhaustion: recovery memory or proposal capacity");return out;
    }
    --budget.proposals_remaining;
    // Copying, mask construction, all source/part scans and final comparisons
    // are prepaid. Failed bids retain their additional work charges below.
    out.request=base;out.request.neighbor_cells=peer.cells;out.request.neighbors=peer.boundary;
    out.request.neighbors.protected_geometry.assign(n,0);out.request.eligible.assign(n,0);
    for(std::size_t i=0;i<n;++i) {
        const bool blocked=mask(base.protected_void,i)||mask(base.neighbors.protected_geometry,i)||
            mask(peer.boundary.protected_geometry,i)||mask(previous.result.boundary.protected_geometry,i);
        out.request.neighbors.protected_geometry[i]=static_cast<std::uint8_t>(blocked);
        out.request.eligible[i]=static_cast<std::uint8_t>((base.eligible[i]||shared_zone[i])&&!blocked&&
            peer.cells[i]==Material::Empty&&(base.context.empty()||base.context[i]==Material::Empty));
    }
    out.plan=previous;out.plan.attempts.clear(); // no categorical solver invocation in this protocol
    out.recovery_receipts=receipts;out.recovery_frontier=frontier;
    out.peer_material_digest=peer.material_digest;out.previous_material_digest=previous.result.material_digest;
    out.status=MosaicRevisionStatus::Complete;out.reason="bounded native receiver negotiation";
    auto& m=out.plan.result;
    bool modified=false;
    std::set<std::uint32_t> existing_slots;
    // A bid lives through one full FRAME reply. Only an unjoined provisional
    // bid may be withdrawn; every former receipt remains in the prior snapshot.
    for(auto it=out.recovery_receipts.begin();it!=out.recovery_receipts.end();) {
        const auto dx=static_cast<std::int64_t>(it->backing.x)-it->contact.x;
        const auto dy=static_cast<std::int64_t>(it->backing.y)-it->contact.y;
        if(it->edits.size()>14||!inside(base,it->contact)||!inside(base,it->root)||!inside(base,it->backing)||
           !inside(base,it->host)||std::abs(dx)+std::abs(dy)!=1||it->round>=round||
           it->variant>3||it->length>6||it->receiving_instance==0||it->receiving_instance>256||
           it->host_instance==0||it->host_instance>256||it->port_id==0) {
            fail(MosaicRevisionStatus::Invalid,"malformed preceding recovery receipt");return out;
        }
        std::set<Point> edited_points;
        for(const auto& edit:it->edits) {
            if(!inside(base,edit.point)||!edited_points.insert(edit.point).second||
               static_cast<unsigned>(edit.before)>131U||static_cast<unsigned>(edit.before)==10U||
               edit.after!=Material::LimestoneBlock||edit.before_owner>256||edit.after_owner==0||edit.after_owner>256||
               static_cast<unsigned>(edit.before_role)>static_cast<unsigned>(Role::Transition)||!structural(edit.after_role)) {
                fail(MosaicRevisionStatus::Invalid,"invalid retained material/ownership edit receipt");return out;
            }
            const auto i=index(base,edit.point);
            if(m.cells[i]!=edit.after||m.roles[i]!=edit.after_role||m.provenance[i]!=edit.after_owner) {
                fail(MosaicRevisionStatus::Invalid,"retained receiver edit differs from native material");return out;
            }
        }
        if(round>=it->round+2&&!currently_joined(frame_request,peer,*it)) {
            if(!debit(512+it->edits.size()*16ULL))return out;
            // Capture the attempted withdrawal before refusal can clear the
            // copied proposal receipts and invalidate their iterator.
            RecoveryAttempt attempt;attempt.slot=it->slot;attempt.connector=it->connector;attempt.ordinal=it->candidate;
            attempt.round=round;attempt.root=it->root;attempt.contact=it->contact;attempt.phase="counteroffer";
            attempt.work=512+it->edits.size()*16ULL;
            // Retain the pre-withdrawal bound until every edit and ownership
            // record has been removed, so an interrupted rollback is covered.
            if(!reserve_finalization(m.instances.size(),m.boundary.hard.size())) {
                attempt.outcome="rejected";attempt.reason=out.reason;
                out.recovery_attempts.push_back(attempt);return out;
            }
            for(const auto& edit:it->edits) {
                if(!inside(base,edit.point)){fail(MosaicRevisionStatus::Invalid,"recovery rollback outside canvas");return out;}
                const auto i=index(base,edit.point);
                if(m.cells[i]!=edit.after||m.provenance[i]!=edit.after_owner||m.roles[i]!=edit.after_role) {
                    fail(MosaicRevisionStatus::Invalid,"competing claim on provisional recovery reservation");return out;
                }
                m.cells[i]=edit.before;m.roles[i]=edit.before_role;m.provenance[i]=edit.before_owner;
            }
            std::erase_if(m.boundary.hard,[&](const auto& p){return p.id==it->port_id;});
            if(it->variant)std::erase_if(m.instances,[&](const auto& p){return p.id==it->receiving_instance;});
            // This releases only unused admission capacity, never debited work.
            finalization_reserve=finalization_cost(m.instances.size(),m.boundary.hard.size());
            attempt.outcome="withdrawn";attempt.reason="unconstructible_frame_span: complete reply produced no physical contact";
            out.recovery_attempts.push_back(attempt);
            it=out.recovery_receipts.erase(it);modified=true;
        } else {existing_slots.insert(it->slot);++it;}
    }
    auto ordered=original_slots;
    std::set<Point> reserved_edits;
    for(const auto& receipt:out.recovery_receipts)for(const auto& edit:receipt.edits)reserved_edits.insert(edit.point);
    std::stable_sort(ordered.begin(),ordered.end(),[](const auto& a,const auto& b){return std::tuple{!a.required,a.id}<std::tuple{!b.required,b.id};});
    out.recovery_frontier_exhausted=true;
    // A reserved socket is a pending architectural choice. It cannot exhaust
    // the alternative frontier before FRAME has replied and the subsequent
    // immutable round can withdraw it and advance the cursor.
    for(const auto& receipt:out.recovery_receipts)if(!currently_joined(frame_request,peer,receipt)) {
        const auto cursor=std::find_if(out.recovery_frontier.begin(),out.recovery_frontier.end(),[&](const auto& x){return x.slot==receipt.slot;});
        if(cursor==out.recovery_frontier.end()||!cursor->exhausted)out.recovery_frontier_exhausted=false;
    }
    for(const auto& slot:ordered) {
        if((!slot.required&&!optional_negotiation)||existing_slots.contains(slot.id))continue;
        if(slot.owner!="FRAMEWEAVER"||slot.strength<=0||slot.strength>1||
           !inside(base,slot.a)||!inside(base,slot.b)||std::abs(static_cast<std::int64_t>(slot.facing.x))+std::abs(static_cast<std::int64_t>(slot.facing.y))!=1||
           (slot.a.x!=slot.b.x&&slot.a.y!=slot.b.y)||
           std::abs(slot.a.x-slot.b.x)+std::abs(slot.a.y-slot.b.y)>32) {
            fail(MosaicRevisionStatus::Invalid,"incorrect_facing_or_family: malformed source reservation");return out;
        }
        const auto source=std::find_if(original_source.connectors.begin(),original_source.connectors.end(),[&](const auto& c){
            return c.id==slot.connector&&c.instance==slot.instance&&c.a==slot.a&&c.b==slot.b&&
                c.facing==slot.facing&&c.required==slot.required&&!c.fulfilled&&(c.family==Family::Frame||c.family==Family::Brace);});
        if(source==original_source.connectors.end())continue;
        auto cursor=std::find_if(out.recovery_frontier.begin(),out.recovery_frontier.end(),[&](const auto& p){return p.slot==slot.id;});
        if(cursor==out.recovery_frontier.end()){out.recovery_frontier.push_back({slot.id,0,original_source.material_digest,false});cursor=out.recovery_frontier.end()-1;}
        const auto candidates=catalogue(slot);
        if(cursor->next>candidates.size()){fail(MosaicRevisionStatus::Invalid,"invalid candidate frontier cursor");return out;}
        bool accepted=false;unsigned examined=0;
        for(;cursor->next<candidates.size()&&examined<64;++cursor->next,++examined) {
            const auto ordinal=cursor->next;const auto& candidate=candidates[ordinal];
            const auto cost=1024ULL+candidate.length*64ULL+m.instances.size()*4ULL+m.boundary.hard.size()*2ULL;
            if(!debit(cost))return out;
            RecoveryAttempt attempt;attempt.slot=slot.id;attempt.connector=source->id;attempt.source_instance=source->instance;
            attempt.ordinal=ordinal;attempt.round=round;attempt.root=candidate.root;attempt.contact=candidate.contact;
            attempt.axis=candidate.axis;attempt.length=candidate.length;attempt.variant=candidate.variant;attempt.work=cost;
            attempt.outcome="rejected";
            const auto reject=[&](const char* reason){attempt.reason=reason;out.recovery_attempts.push_back(attempt);};
            const auto contact=candidate.contact,backing=add(contact,slot.facing);
            const auto ri=index(base,candidate.root);
            if(!solid(original_source.cells[ri])||!structural(original_source.roles[ri])||original_source.provenance[ri]!=source->instance) {
                reject("missing_native_structural_backing: source");continue;
            }
            if(!in_box(contact,slot.envelope)||!allowed(out.request,contact)||!allowed(out.request,backing)) {
                reject("unreachable_receiver_territory_or_protected_context_collision");continue;
            }
            bool path=true;
            const auto distance=std::abs(contact.x-candidate.root.x)+std::abs(contact.y-candidate.root.y);
            for(int step=1;step<distance;++step) {
                const auto p=add(candidate.root,mul(slot.facing,step));const auto i=index(base,p);
                if((!frame_request.eligible[i]&&!shared_zone[i])||mask(out.request.neighbors.protected_geometry,i)||
                   mask(frame_request.protected_void,i)||(!base.context.empty()&&base.context[i]!=Material::Empty)||
                   m.cells[i]!=Material::Empty||peer.cells[i]!=Material::Empty){path=false;break;}
            }
            if(!path){reject("unconstructible_frame_span: occupancy, ownership or protected path");continue;}
            if(std::any_of(out.recovery_receipts.begin(),out.recovery_receipts.end(),[&](const auto& r){return r.contact==contact;})) {
                reject("competing_territorial_claim: reserved contact");continue;
            }
            const auto ci=index(base,contact),bi=index(base,backing);
            MosaicRecoveryReceipt receipt;receipt.slot=slot.id;receipt.connector=source->id;receipt.source_instance=source->instance;
            receipt.round=round;receipt.candidate=ordinal;receipt.root=candidate.root;receipt.contact=contact;receipt.backing=backing;
            receipt.axis=candidate.axis;receipt.cross=candidate.cross;receipt.length=candidate.length;receipt.variant=candidate.variant;
            receipt.source_family=source->family;receipt.receiving_family=distance==1?source->family:Family::Frame;
            receipt.source_digest=original_source.material_digest;receipt.prior_digest=previous.result.material_digest;receipt.work=cost;
            std::vector<Point> footprint;Point host=contact;std::uint32_t host_id=0;
            if(candidate.variant==0) {
                host_id=m.provenance[ci];
                if(!host_id||m.provenance[bi]!=host_id||!structural(m.roles[ci])||!structural(m.roles[bi])||
                   !bearing_material(m.cells[ci])||!bearing_material(m.cells[bi])) {
                    reject("missing_native_structural_backing: no same-owner contact/backing");continue;
                }
            }else {
                host=add(contact,mul(candidate.axis,static_cast<int>(candidate.length)));
                const auto host2=add(host,candidate.cross);
                if(!inside(base,host)||!inside(base,host2)||!allowed(out.request,host)||!allowed(out.request,host2)) {
                    reject("protected_space_or_existing_context_collision: receiver host");continue;
                }
                const auto hi=index(base,host),hj=index(base,host2);host_id=m.provenance[hi];
                if(!host_id||m.provenance[hj]!=host_id||!structural(m.roles[hi])||!structural(m.roles[hj])||
                   !bearing_material(m.cells[hi])||!bearing_material(m.cells[hj])) {
                    reject("missing_native_structural_backing: no native corbel host");continue;
                }
                bool clear=true;
                for(unsigned a=0;a<candidate.length;++a)for(unsigned b=0;b<2;++b) {
                    const auto p=add(add(contact,mul(candidate.axis,static_cast<int>(a))),mul(candidate.cross,static_cast<int>(b)));
                    if(!allowed(out.request,p)||m.cells[index(base,p)]!=Material::Empty){clear=false;break;}
                    footprint.push_back(p);
                }
                if(!clear){reject("protected_space_or_existing_context_collision: authored receiver footprint");continue;}
                if(std::find(footprint.begin(),footprint.end(),backing)==footprint.end()) {
                    reject("incompatible_material_or_authored_part: missing backing in finite motif");continue;
                }
            }
            const auto host_part=std::find_if(m.instances.begin(),m.instances.end(),[&](const auto& p){return p.id==host_id;});
            const auto second_host=candidate.variant?add(host,candidate.cross):backing;
            if(reserved_edits.contains(host)||reserved_edits.contains(second_host)){
                reject("competing_territorial_claim: provisional native backing dependency");continue;
            }
            if(host_part==m.instances.end()||host_part->kind.starts_with("swarm006/")||
               std::find(host_part->cells.begin(),host_part->cells.end(),host)==host_part->cells.end()||
               std::find(host_part->cells.begin(),host_part->cells.end(),second_host)==host_part->cells.end()) {
                reject("missing_mosaic_category_or_receptor_feasibility: unauthored host");continue;
            }
            const auto tile=static_cast<std::size_t>(host.y/16)*static_cast<std::size_t>((base.width+15)/16)+static_cast<std::size_t>(host.x/16);
            if(tile>=out.plan.categories.size()||out.plan.categories[tile]<0||
               host_part->kind!=mosaic_category_name(static_cast<unsigned>(out.plan.categories[tile]))) {
                reject("missing_mosaic_category_or_receptor_feasibility: category/host mismatch");continue;
            }
            const auto existing_ports=std::count_if(m.boundary.hard.begin(),m.boundary.hard.end(),[&](const auto& p){return p.instance==host_id;});
            if(base.limits.max_connectors_per_instance==0||m.boundary.hard.size()>=std::min<std::size_t>(256,base.limits.max_affordances)||
               (!candidate.variant&&static_cast<std::size_t>(existing_ports)>=base.limits.max_connectors_per_instance)||
               (candidate.variant&&m.instances.size()>=base.limits.max_instances)) {
                reject("insufficient_connector_or_reservation_capacity");continue;
            }
            std::uint32_t owner=host_id,next_port=0;
            for(const auto& p:m.boundary.hard)next_port=std::max(next_port,p.id);
            if(candidate.variant) {owner=0;for(const auto& p:m.instances)owner=std::max(owner,p.id);++owner;}
            if(owner>256||next_port==UINT32_MAX){reject("insufficient_connector_or_reservation_capacity");continue;}
            receipt.host=host;receipt.host_instance=host_id;receipt.receiving_instance=owner;receipt.port_id=next_port+1;
            const auto edit=[&](Point p,Material material,Role role,std::uint32_t id){
                const auto i=index(base,p);if(m.cells[i]!=material||m.roles[i]!=role||m.provenance[i]!=id)
                    receipt.edits.push_back({p,m.cells[i],material,m.roles[i],role,m.provenance[i],id});};
            if(candidate.variant) {
                for(const auto p:footprint)edit(p,Material::LimestoneBlock,Role::Structure,owner);
                for(const auto p:{host,add(host,candidate.cross)})if(m.cells[index(base,p)]==Material::Stone)
                    edit(p,Material::LimestoneBlock,m.roles[index(base,p)],host_id);
            }else for(const auto p:{contact,backing})if(m.cells[index(base,p)]==Material::Stone)
                edit(p,Material::LimestoneBlock,m.roles[index(base,p)],host_id);
            const bool competing=std::any_of(receipt.edits.begin(),receipt.edits.end(),[&](const auto& e){return reserved_edits.contains(e.point);});
            if(competing){reject("competing_territorial_claim: overlapping provisional reservation");continue;}
            if(!reserve_finalization(m.instances.size()+(candidate.variant?1U:0U),m.boundary.hard.size()+1U)) {
                attempt.reason=out.reason;out.recovery_attempts.push_back(attempt);return out;
            }
            for(const auto& e:receipt.edits){const auto i=index(base,e.point);m.cells[i]=e.after;m.roles[i]=e.after_role;m.provenance[i]=e.after_owner;}
            for(const auto& e:receipt.edits)reserved_edits.insert(e.point);
            if(candidate.variant) {
                Instance part;part.id=owner;part.kind="swarm006/supported_masonry_corbel";part.origin=contact;
                part.orientation=static_cast<int>(rotation(candidate.axis));part.structural=true;part.cells=footprint;
                part.reason="MOSAIC/source-bound-solid-corbel-v1;host="+std::to_string(host_id)+";length="+std::to_string(candidate.length);
                m.instances.push_back(std::move(part));
            }
            m.boundary.hard.push_back({receipt.port_id,owner,contact,contact,neg(slot.facing),receipt.receiving_family,false,slot.strength,tag(receipt)});
            out.recovery_receipts.push_back(receipt);existing_slots.insert(slot.id);
            attempt.host_instance=host_id;attempt.outcome="reserved";attempt.reason="native_receiver_reserved_pending_frame_and_joint_proof";
            out.recovery_attempts.push_back(attempt);++cursor->next;accepted=true;modified=true;break;
        }
        cursor->exhausted=cursor->next==candidates.size();
        if(!accepted&&!cursor->exhausted)out.recovery_frontier_exhausted=false;
    }
    if(modified) {
        if(cancelled()){fail(MosaicRevisionStatus::Cancelled,"cancellation");return out;}
        // The generator's aggregate allowance is owned by MosaicBudget. The
        // retained base's work remains unchanged; recovery work has its own
        // explicit receipt and is never presented as a free categorical solve.
        finalize_snapshot();
        if(!usable(m)) {
            // Finalization already produced this invalid snapshot and its exact
            // digest. Do not run or charge a second failure finalization.
            out.status=MosaicRevisionStatus::Invalid;out.reason="native recovery finalization: "+m.termination;return out;
        }
    }
    for(std::size_t i=0;i<n;++i)if(previous.result.cells[i]!=m.cells[i])
        out.geometry_changes.push_back({static_cast<std::uint32_t>(i),previous.result.cells[i],m.cells[i],previous.result.provenance[i],m.provenance[i]});
    out.reason=out.recovery_frontier_exhausted?"candidate_frontier_exhausted_or_reserved":"alternative_frontier_remaining";
    return out;
}
} // namespace cybersand::gentek_swarm::assembly004
