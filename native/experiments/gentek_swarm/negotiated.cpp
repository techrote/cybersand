#include "negotiated.hpp"
#include "resilience.hpp"
#include <algorithm>
#include <array>
#include <bit>
#include <cmath>
#include <limits>
#include <set>
#include <tuple>

namespace cybersand::gentek_swarm {
namespace {
constexpr std::array<Point,4> directions{{{1,0},{0,1},{-1,0},{0,-1}}};
Point add(Point a, Point b) { return {a.x+b.x,a.y+b.y}; }
int distance(Point a, Point b) { return std::abs(a.x-b.x)+std::abs(a.y-b.y); }
bool in_rect(Point p, Rect r) { return p.x>=r.x&&p.y>=r.y&&p.x<r.x+r.w&&p.y<r.y+r.h; }
bool usable(const Result& r) { return r.status==Status::Complete||r.status==Status::Blocked; }
std::uint32_t next_id(const Result& r) {
    std::uint32_t id=1; for(const auto& i:r.instances) id=std::max(id,i.id+1); return id;
}
std::vector<Material> combine(const Fixture& f,const Result& a,const Result& b) {
    auto cells=f.context;
    for(std::size_t i=0;i<cells.size();++i) {
        if(i<a.cells.size()&&a.cells[i]!=Material::Empty) cells[i]=a.cells[i];
        if(i<b.cells.size()&&b.cells[i]!=Material::Empty) cells[i]=b.cells[i];
    }
    return cells;
}
std::uint64_t added(const Result& before,const Result& after) {
    std::uint64_t count=0;
    for(std::size_t i=0;i<after.cells.size();++i)
        count+=after.cells[i]!=Material::Empty&&(i>=before.cells.size()||before.cells[i]==Material::Empty);
    return count;
}
bool protected_at(const Result& a,const Result& b,std::size_t i) {
    return (i<a.boundary.protected_geometry.size()&&a.boundary.protected_geometry[i])||
           (i<b.boundary.protected_geometry.size()&&b.boundary.protected_geometry[i]);
}
std::vector<std::vector<Point>> routes(Point a,Point b,Point af,Point bf) {
    if(std::abs(af.x)+std::abs(af.y)!=1||std::abs(bf.x)+std::abs(bf.y)!=1) return {};
    if(distance(a,b)==1&&add(a,af)==b&&add(b,bf)==a) return {{a,b}};
    const Point sa=add(a,af),sb=add(b,bf);
    std::vector<std::vector<Point>> paths;
    for(int mode=0;mode<3;++mode) {
        std::vector<Point> path;
        const auto append=[&](Point from,Point to) {
            for(auto p:line(from,to)) if(path.empty()||p!=path.back()) path.push_back(p);
        };
        append(a,sa);
        if(mode==0) append(sa,sb);
        else { const Point corner=mode==1?Point{sb.x,sa.y}:Point{sa.x,sb.y}; append(sa,corner);append(corner,sb); }
        append(sb,b);
        if(path.size()<2||path.size()>16||std::set<Point>(path.begin(),path.end()).size()!=path.size()) continue;
        if(path[1]!=sa||path[path.size()-2]!=sb) continue;
        if(std::find(paths.begin(),paths.end(),path)==paths.end()) paths.push_back(std::move(path));
    }
    std::sort(paths.begin(),paths.end(),[](const auto& a,const auto& b){return a.size()!=b.size()?a.size()<b.size():a<b;});
    return paths;
}
std::vector<int> components(const Request& q,const std::vector<Material>& cells) {
    std::vector<int> labels(cells.size(),-1); std::vector<Point> queue; int label=0;
    for(std::size_t i=0;i<cells.size();++i) {
        if(cells[i]==Material::Empty||labels[i]>=0) continue;
        queue={{static_cast<int>(i%q.width),static_cast<int>(i/q.width)}}; labels[i]=label;
        for(std::size_t at=0;at<queue.size();++at) for(auto d:directions) {
            const auto p=add(queue[at],d); if(!inside(q,p)) continue; const auto j=index(q,p);
            if(cells[j]!=Material::Empty&&labels[j]<0) {labels[j]=label;queue.push_back(p);}
        }
        ++label;
    }
    return labels;
}
void final_join(NegotiatedResult& out,const Request& fq,const Request& mq,
                const std::vector<TransitionSlot>* admitted = nullptr,
                std::uint64_t join_work_limit = 2'000'000) {
    auto& a=out.final_frame; auto& b=out.final_mosaic;
    const auto& f=out.control.fixture;
    std::set<Point> used;
    for(const auto& slot:out.frame.slots) {
        Seam seam;seam.left_affordance=slot.id;seam.a=slot.a;
        if(admitted&&std::none_of(admitted->begin(),admitted->end(),[&](const auto& s){return s.id==slot.id;})) {
            seam.reason="not admitted: optional-offer policy omitted this slot; no shared join attempted";
            out.seams.push_back(std::move(seam));continue;
        }
        const auto response=std::find_if(out.mosaic.responses.begin(),out.mosaic.responses.end(),[&](const auto& r){return r.slot_id==slot.id;});
        if(response==out.mosaic.responses.end()||!response->satisfied) {
            seam.reason="unresolved: MOSAIC did not select a compatible material response";
            out.seams.push_back(std::move(seam));continue;
        }
        if(slot.kind==SlotKind::PassageOpening) {
            seam.reason="passage category selected; no structural bearing joint inferred";
            out.seams.push_back(std::move(seam));continue;
        }
        seam.right_affordance=response->tile;seam.b=response->contact;
        if(!usable(a)||!usable(b)||used.contains(seam.b)) {
            seam.reason="unresolved: failed plan or recipient contact already assigned";
            out.seams.push_back(std::move(seam));continue;
        }
        auto points=line(slot.a,slot.b);
        std::sort(points.begin(),points.end(),[&](Point x,Point y){return std::tuple{distance(x,seam.b),x}<std::tuple{distance(y,seam.b),y};});
        std::vector<Point> chosen;
        for(auto p:points) {
            if(used.contains(p)||!inside(fq,p)||a.cells[index(fq,p)]==Material::Empty) continue;
            for(const auto& path:routes(p,seam.b,slot.facing,response->facing)) {
                bool legal=true;
                for(auto v:path) {
                    if(out.work>=join_work_limit) {legal=false;out.metrics["shared_exhausted"]=1;break;}
                    ++out.work;
                    if(!inside(fq,v)||!in_rect(v,slot.envelope)) {legal=false;break;}
                    const auto i=index(fq,v);
                    if(!f.transition[i]||f.protected_void[i]||f.context[i]!=Material::Empty||protected_at(a,b,i)||
                       std::find(slot.clearance.begin(),slot.clearance.end(),v)!=slot.clearance.end()) {legal=false;break;}
                    if(v==p) {if(a.roles[i]==Role::Cohesion||a.roles[i]==Role::Detail)legal=false;}
                    else if(v==seam.b) {if(b.cells[i]==Material::Empty||b.roles[i]==Role::Cohesion||b.roles[i]==Role::Detail)legal=false;}
                    else if(a.cells[i]!=Material::Empty||b.cells[i]!=Material::Empty||
                            (f.side[i]==0?!allowed(fq,v):!allowed(mq,v))) legal=false;
                    if(!legal)break;
                }
                if(legal) {chosen=path;break;}
            }
            if(!chosen.empty())break;
        }
        if(chosen.empty()) {
            seam.reason="unresolved: no <=16-cell clear route with exact facing inside reserved envelope";
            out.seams.push_back(std::move(seam));continue;
        }
        Connector* connector=nullptr;
        for(auto& c:a.connectors) if(c.id==slot.connector&&c.instance==slot.instance&&c.a==slot.a&&c.b==slot.b&&c.facing==slot.facing) connector=&c;
        if(slot.required&&connector==nullptr) {
            seam.reason="unresolved: required slot lacks its exact original connector";
            out.seams.push_back(std::move(seam));continue;
        }
        const auto aid=next_id(a),bid=next_id(b);
        Instance ai{aid,"negotiated-final-join",chosen.front(),0,true,false,{},"shared minimal join after both Genteks froze; not preplanned motif geometry"};
        Instance bi{bid,"negotiated-final-join",chosen.back(),0,true,false,{},"shared minimal join after both Genteks froze; not preplanned motif geometry"};
        for(std::size_t j=1;j+1<chosen.size();++j) (f.side[index(fq,chosen[j])]==0?ai.cells:bi.cells).push_back(chosen[j]);
        if((!ai.cells.empty()&&a.instances.size()>=fq.limits.max_instances)||(!bi.cells.empty()&&b.instances.size()>=mq.limits.max_instances)) {
            seam.reason="unresolved: bounded instance capacity refuses final join";out.seams.push_back(std::move(seam));continue;
        }
        for(auto p:ai.cells)write_cell(fq,a,p,Material::SteelPlate,Role::Transition,aid);
        for(auto p:bi.cells)write_cell(mq,b,p,Material::SteelPlate,Role::Transition,bid);
        if(!ai.cells.empty())a.instances.push_back(ai);
        if(!bi.cells.empty())b.instances.push_back(bi);
        if(connector){connector->fulfilled=true;connector->state="joined-negotiated";}
        seam.a=chosen.front();seam.joined=true;seam.cells=chosen;
        seam.reason=chosen.size()==2?"direct preplanned material contact; zero shared cells":"qualified minimal final join; additional geometry counted separately";
        a.attachments.push_back({slot.instance,seam.a,seam.b,"negotiated-typed-contact","reservation and selected MOSAIC motif connected by recorded material path"});
        const auto mi=b.provenance[index(mq,seam.b)];
        b.attachments.push_back({mi,seam.b,seam.a,"negotiated-typed-contact","selected native category and real material contact"});
        ++out.metrics["joined_slots"];
        out.metrics["shared_bridge_cells"]+=chosen.size()-2;
        ++out.metrics[chosen.size()==2?"direct_contacts":"shared_bridges"];
        used.insert(seam.a);used.insert(seam.b);out.seams.push_back(std::move(seam));
    }
}
void residual_finish(NegotiatedResult& out,const Request& basis,bool enabled) {
    auto q=basis;q.gentek=Kind::Receptor;q.definition_fingerprint=definition(Kind::Receptor);
    q.neighbors={};q.neighbor_cells.clear();q.context=out.cells;
    q.profile.cohesion=std::max(q.profile.cohesion,0.7);
    q.limits.max_instances=24;q.limits.max_cohesion_patches=4;q.limits.max_cohesion_cells_per_patch=64;
    q.eligible.assign(out.cells.size(),0);q.protected_void.assign(out.cells.size(),0);
    out.finished_cells=out.cells;
    const bool valid=enabled&&usable(out.final_frame)&&out.final_mosaic.status==Status::Complete&&
        out.final_frame.unresolved_joints==0&&out.metrics["joined_slots"]>0&&out.metrics["unresolved_required_slots"]==0&&
        out.metrics["protected_violations"]==0&&out.metrics["illegal_overlaps"]==0;
    if(!valid) {
        out.residual=begin_result(q,"receptor-residual-disabled");
        out.residual.status=Status::Blocked;out.residual.termination="residual pass withheld: disabled or no fully valid negotiated structural interface";
        finish_result(q,out.residual);out.residual_request=q;return;
    }
    const auto labels=components(q,out.cells);std::vector<int> eligible_owner(out.cells.size(),-1);
    std::vector<std::uint8_t> excluded(out.cells.size(),0),residual_envelope(out.cells.size(),0);
    for(const auto& slot:out.frame.slots) {
        for(auto p:slot.clearance)if(inside(q,p))excluded[index(q,p)]=1;
        const bool joined=std::any_of(out.seams.begin(),out.seams.end(),[&](const auto& s){return s.left_affordance==slot.id&&s.joined;});
        if(joined) for(int y=slot.envelope.y;y<slot.envelope.y+slot.envelope.h;++y)
            for(int x=slot.envelope.x;x<slot.envelope.x+slot.envelope.w;++x)if(inside(q,{x,y}))residual_envelope[index(q,{x,y})]=1;
        if(!joined) for(int y=slot.envelope.y;y<slot.envelope.y+slot.envelope.h;++y)
            for(int x=slot.envelope.x;x<slot.envelope.x+slot.envelope.w;++x)if(inside(q,{x,y}))excluded[index(q,{x,y})]=1;
    }
    for(std::size_t i=0;i<out.cells.size();++i) {
        if(out.cells[i]!=Material::Empty||!q.transition[i]||!residual_envelope[i]||excluded[i]||
           protected_at(out.final_frame,out.final_mosaic,i))continue;
        const Point p{static_cast<int>(i%q.width),static_cast<int>(i/q.width)};
        int owner=-1;bool multiple=false;
        for(int dy=-2;dy<=2;++dy)for(int dx=-2;dx<=2;++dx) {
            const auto v=add(p,{dx,dy});if(std::abs(dx)+std::abs(dy)>2||!inside(q,v))continue;
            const auto label=labels[index(q,v)];if(label<0)continue;
            if(owner>=0&&owner!=label)multiple=true;
            owner=label;
        }
        if(!multiple&&owner>=0)eligible_owner[i]=owner;
    }
    // Separate frozen component catchments. New residual cells cannot create a
    // new material path between disconnected original structures, even by chains.
    for(std::size_t i=0;i<out.cells.size();++i) {
        if(eligible_owner[i]<0)continue;
        const Point p{static_cast<int>(i%q.width),static_cast<int>(i/q.width)};bool different=false;
        for(auto d:directions) {const auto v=add(p,d);if(!inside(q,v))continue;const auto j=index(q,v);
            if(eligible_owner[j]>=0&&eligible_owner[j]!=eligible_owner[i])different=true;}
        if(!different)q.eligible[i]=1;
    }
    out.residual=begin_result(q,"receptor-residual-only-v0");
    adapt_receptor(q,out.residual);
    for(auto& inst:out.residual.instances){inst.structural=false;inst.kind="residual-"+inst.kind;}
    for(std::size_t i=0;i<out.residual.cells.size();++i)if(out.residual.cells[i]!=Material::Empty){
        out.residual.roles[i]=Role::Cohesion;out.finished_cells[i]=out.residual.cells[i];++out.metrics["receptor_cells"];
    }
    out.residual.boundary.hard.clear();out.residual.boundary.soft.clear();
    out.residual.notes.push_back("SWARM-002 residual wrapper: no connector authority; original connected components remain separated.");
    finish_result(q,out.residual);out.residual_request=q;out.metrics["receptor_enabled"]=1;
}
} // namespace

const char* name(SlotKind k) noexcept {
    switch(k){case SlotKind::PointSocket:return "point_socket";case SlotKind::BearingSegment:return "bearing_segment";case SlotKind::PassageOpening:return "passage_opening";}return "invalid";
}
static NegotiatedResult prepare_case(const Fixture& f,const Profile& p,std::uint64_t seed,
                                     const std::string& source,bool reverse,bool force_hard,bool defer_control=false) {
    NegotiatedResult out;
    if(defer_control)out.control.fixture=f;
    else out.control=mesh(f,Kind::Frameweaver,Kind::Mosaic,p,seed,source,reverse);
    if(force_hard)out.offer_policy="all-hard";
    auto fq=request_for(f,Kind::Frameweaver,0,p,seed,source);
    auto mq=request_for(f,Kind::Mosaic,1,p,seed,source);
    out.frame=plan_frameweaver(fq,mq);
    for(auto& slot:out.frame.slots)if(force_hard)slot.hard=true;
    mq.neighbor_cells=out.frame.result.cells;
    mq.neighbors.protected_geometry=out.frame.result.boundary.protected_geometry;
    if(mq.neighbors.protected_geometry.empty())mq.neighbors.protected_geometry.assign(f.side.size(),0);
    for(const auto& slot:out.frame.slots)for(auto v:slot.clearance)if(inside(mq,v))mq.neighbors.protected_geometry[index(mq,v)]=1;
    out.frame_request=fq;out.mosaic_request=mq;
    return out;
}

static NegotiatedResult finish_case(NegotiatedResult out,bool reverse,bool finish,
                                    const std::vector<TransitionSlot>* admitted = nullptr,
                                    std::uint64_t join_work_limit = 2'000'000,
                                    const ResilienceOptions* resilience_options = nullptr,
                                    ResilienceTrace* resilience_trace = nullptr) {
    const auto& f=out.control.fixture;
    auto fq=out.frame_request,mq=out.mosaic_request;
    auto offers=admitted?*admitted:out.frame.slots;if(reverse)std::reverse(offers.begin(),offers.end());
    const auto solve_candidate=[&]() {
        return resilience_options?negotiate_mosaic_resilient(mq,offers,*resilience_options,*resilience_trace):negotiate_mosaic(mq,offers);
    };
    if(reverse){out.no_offers=negotiate_mosaic(mq,{});out.mosaic=solve_candidate();}
    else{out.mosaic=solve_candidate();out.no_offers=negotiate_mosaic(mq,{});}
    // The resilient donor discovers the original universe before admission.
    // Only its immutable admission decision may authorize a shared join.
    // The historical C and geometric-cap paths remain byte-for-byte unchanged.
    std::vector<TransitionSlot> resilient_authorized;
    if(resilience_trace) {
        for(const auto& offer:offers)
            if(std::find(resilience_trace->final_authorized_ids.begin(),resilience_trace->final_authorized_ids.end(),offer.id)!=resilience_trace->final_authorized_ids.end())
                resilient_authorized.push_back(offer);
        admitted=&resilient_authorized;
    }
    std::sort(out.frame.slots.begin(),out.frame.slots.end(),[](const auto& a,const auto& b){return a.id<b.id;});
    out.final_frame=out.frame.result;out.final_mosaic=out.mosaic.result;
    out.planned_cells=combine(f,out.final_frame,out.final_mosaic);
    out.no_offer_cells=combine(f,out.final_frame,out.no_offers.result);
    out.metrics["offered_slots"]=out.frame.slots.size();
    for(const auto& r:out.mosaic.responses){
        out.metrics["admitted_slots"]+=r.admitted;out.metrics["selected_compatible_slots"]+=r.satisfied;
        if(r.admitted&&r.tile<out.no_offers.categories.size()&&out.no_offers.categories[r.tile]>=0) {
            const auto cat=out.no_offers.categories[r.tile];
            const bool compatible=(r.compatible_domain&(1U<<cat))!=0&&inside(mq,r.contact)&&
                index(mq,r.contact)<out.no_offers.result.cells.size()&&out.no_offers.result.cells[index(mq,r.contact)]!=Material::Empty;
            out.metrics["already_compatible_without_offers"]+=compatible;
            out.metrics["newly_compatible_due_to_offers"]+=r.satisfied&&!compatible;
        }
    }
    for(const auto& d:out.mosaic.domains)if(!d.influences.empty()) {
        out.metrics["affected_tiles"]++;
        out.metrics["domain_changed_tiles"]+=d.original_domain!=d.modified_domain;
        if(d.selected>=0&&d.tile<out.no_offers.categories.size()&&out.no_offers.categories[d.tile]>=0&&d.selected!=out.no_offers.categories[d.tile])++out.metrics["causally_changed_tiles"];
    }
    for(std::size_t i=0;i<std::min(out.mosaic.categories.size(),out.no_offers.categories.size());++i)
        out.metrics["counterfactual_changed_tiles_total"]+=out.mosaic.categories[i]>=0&&out.no_offers.categories[i]>=0&&out.mosaic.categories[i]!=out.no_offers.categories[i];
    if(usable(out.final_frame)&&usable(out.final_mosaic))final_join(out,fq,mq,admitted,join_work_limit);
    finish_result(fq,out.final_frame);finish_result(mq,out.final_mosaic);
    if(out.final_frame.status==Status::Blocked&&out.final_frame.unresolved_joints==0&&!out.final_frame.instances.empty()) {
        out.final_frame.status=Status::Complete;out.final_frame.termination="all mandatory joints qualified after negotiated final validation";
        finish_result(fq,out.final_frame);
    }
    out.cells=combine(f,out.final_frame,out.final_mosaic);
    for(std::size_t i=0;i<f.side.size();++i) {
        const bool a=i<out.final_frame.cells.size()&&out.final_frame.cells[i]!=Material::Empty;
        const bool b=i<out.final_mosaic.cells.size()&&out.final_mosaic.cells[i]!=Material::Empty;
        out.metrics["illegal_overlaps"]+=(a&&b)||((a||b)&&f.context[i]!=Material::Empty)||(a&&f.side[i]!=0)||(b&&f.side[i]!=1);
        out.metrics["protected_violations"]+=out.cells[i]!=Material::Empty&&protected_at(out.final_frame,out.final_mosaic,i);
        out.metrics["frozen_core_changes"]+=i<out.frame.core.cells.size()&&out.frame.core.cells[i]!=Material::Empty&&out.frame.core.cells[i]!=out.final_frame.cells[i];
        out.metrics["mosaic_frozen_changes"]+=i<out.mosaic.result.cells.size()&&out.mosaic.result.cells[i]!=Material::Empty&&out.mosaic.result.cells[i]!=out.final_mosaic.cells[i];
        out.metrics["transition_occupancy"]+=f.transition[i]&&out.cells[i]!=Material::Empty;
    }
    for(const auto& slot:out.frame.slots) {
        const bool joined=std::any_of(out.seams.begin(),out.seams.end(),[&](const auto& s){return s.left_affordance==slot.id&&s.joined;});
        out.metrics["unresolved_slots"]+=!joined;out.metrics["unresolved_required_slots"]+=slot.required&&!joined;
    }
    out.metrics["unresolved_mandatory_connectors"]=out.final_frame.unresolved_joints;
    out.metrics["frame_preplanned_addition_cells"]=added(out.frame.core,out.frame.result);
    out.metrics["frame_postsolve_adaptation_cells"]=0;
    out.metrics["mosaic_postsolve_adaptation_cells"]=0;
    out.metrics["control_posthoc_cells"]=added(out.control.initial_left,out.control.left)+added(out.control.initial_right,out.control.right);
    out.metrics["control_posthoc_pieces"]=(out.control.left.instances.size()-out.control.initial_left.instances.size())+
        (out.control.right.instances.size()-out.control.initial_right.instances.size());
    out.metrics["control_bridge_cells"]=out.control.bridge_cells;
    out.metrics["control_joined_interfaces"]=out.control.bridges+out.control.typed_contacts;
    out.metrics["control_unresolved_mandatory"]=out.control.left.unresolved_joints;
    out.metrics["candidate_posthoc_cells"]=out.metrics["shared_bridge_cells"];
    out.metrics["candidate_posthoc_pieces"]=(out.final_frame.instances.size()-out.frame.result.instances.size())+
        (out.final_mosaic.instances.size()-out.mosaic.result.instances.size());
    residual_finish(out,fq,finish);
    out.metrics["shared_work"]=out.work;
    out.metrics["candidate_generator_work"]=out.frame.result.work+out.mosaic.result.work+out.work+out.residual.work;
    out.metrics["counterfactual_generator_work"]=out.no_offers.result.work;
    out.metrics["solver_attempts"]=out.mosaic.attempts.size();out.metrics["solver_total_work_available"]=1;
    for(const auto& attempt:out.mosaic.attempts) {
        out.metrics["solver_work_upper_bound"]+=attempt.work_limit;
        out.metrics["solver_known_work"]+=attempt.work;
        out.metrics["solver_total_work_available"]&=attempt.work_observed;
    }
    out.metrics["candidate_charged_work_upper_bound"]=fq.limits.max_work+mq.limits.max_work+mq.limits.max_solver_work+2'000'000+
        (out.metrics["receptor_enabled"]?out.residual_request.limits.max_work:0);
    out.metrics["finite_validation_canvas_cells"]=f.side.size();
    out.notes.push_back("Directed finite protocol: FRAMEWEAVER reserves before terminal freeze; MOSAIC consumes offers before GEN-003 compile; no simultaneous global optimization.");
    out.notes.push_back("No-offers ablation retains the exact candidate frame, peer cells, clearances, seed and vocabulary. Only the reservation input is removed.");
    out.notes.push_back("Shared joins are limited to eight reservations and <=16 cells each, including endpoints. Zero postsolve Gentek adapter passes used.");
    out.notes.push_back("Charged-work totals exclude bounded fixed-array validation, component labeling, hashing and serialization; the canvas limit separately bounds those passes. No peak allocator or total CPU-operation telemetry is claimed.");
    out.digest=mix(out.final_frame.digest^std::rotl(out.final_mosaic.digest,17)^out.residual.digest^out.work^f.digest^
                   out.frame.core.digest^out.frame.result.digest^out.mosaic.result.digest^out.no_offers.result.digest);
    const auto integer=[&](std::uint64_t value){out.digest=mix(out.digest^value);};
    const auto text=[&](const std::string& s){integer(s.size());for(unsigned char c:s)integer(c);};
    const auto point=[&](Point v){integer(static_cast<std::uint64_t>(v.x));integer(static_cast<std::uint64_t>(v.y));};
    text(out.offer_policy);
    for(const auto& [key,value]:out.metrics){text(key);integer(value);}
    integer(out.frame.slots.size());
    for(const auto& s:out.frame.slots){
        integer(s.id);integer(s.instance);integer(s.connector);integer(static_cast<unsigned>(s.kind));
        point(s.a);point(s.b);point(s.facing);point({s.envelope.x,s.envelope.y});point({s.envelope.w,s.envelope.h});
        integer(s.required);integer(s.hard);integer(std::bit_cast<std::uint64_t>(s.strength));text(s.owner);text(s.reason);
        integer(s.clearance.size());for(auto v:s.clearance)point(v);
    }
    for(const auto* plan:{&out.mosaic,&out.no_offers}){
        integer(plan->domains.size());
        for(const auto& d:plan->domains){
            integer(d.tile);point(d.origin);integer(d.original_domain);integer(d.hard_domain);integer(d.preferred_domain);integer(d.modified_domain);
            integer(d.selected+1);integer(d.preference_satisfied);integer(d.fallback);integer(d.influences.size());
            for(const auto& i:d.influences){integer(i.slot_id);integer(i.compatible_domain);integer(i.hard);integer(i.admitted);point(i.contact);text(i.reason);}
        }
        integer(plan->attempts.size());
        for(const auto& a:plan->attempts){text(a.policy);text(a.reason);integer(static_cast<unsigned>(a.status));integer(a.attempted);integer(a.work_observed);integer(a.work);integer(a.work_limit);}
        integer(plan->responses.size());
        for(const auto& r:plan->responses){integer(r.slot_id);integer(r.tile);integer(r.admitted);integer(r.satisfied);point(r.contact);point(r.facing);integer(r.compatible_domain);text(r.reason);}
    }
    for(const auto& s:out.seams){integer(s.left_affordance);integer(s.right_affordance);point(s.a);point(s.b);integer(s.joined);text(s.reason);integer(s.cells.size());for(auto v:s.cells)point(v);}
    return out;
}
NegotiatedResult negotiate(const Fixture& f,const Profile& p,std::uint64_t seed,
                           const std::string& source,bool reverse,bool force_hard,bool finish) {
    return finish_case(prepare_case(f,p,seed,source,reverse,force_hard),reverse,finish);
}

namespace {
constexpr std::uint64_t admission_shared_limit=2'000'000;
// Charge the same finite selection allowance for every policy. Eight visits
// plus 8*8 ordering comparisons cover the bounded selection and ID ordering.
constexpr std::uint64_t admission_selection_charge=max_transition_slots+max_transition_slots*max_transition_slots;

struct AdmissionHash {
    std::uint64_t value=0x41444d495353494fULL;
    void integer(std::uint64_t x) {value=mix(value^x);}
    void text(const std::string& s) {integer(s.size());for(unsigned char c:s)integer(c);}
    void point(Point p) {integer(static_cast<std::uint64_t>(p.x));integer(static_cast<std::uint64_t>(p.y));}
    template<class T> void numbers(const std::vector<T>& v) {
        integer(v.size());for(auto x:v)integer(static_cast<std::uint64_t>(x));
    }
    void boundary(const Boundary& b) {
        numbers(b.protected_geometry);numbers(b.transition);integer(b.hard.size());
        for(const auto& a:b.hard) {
            integer(a.id);integer(a.instance);point(a.a);point(a.b);point(a.facing);
            integer(static_cast<unsigned>(a.family));integer(a.required);integer(std::bit_cast<std::uint64_t>(a.strength));text(a.tag);
        }
        integer(b.soft.size());for(const auto& a:b.soft) {
            point(a.point);point(a.direction);integer(std::bit_cast<std::uint64_t>(a.strength));text(a.preference);
        }
    }
    void result(const Result& r) {
        integer(static_cast<unsigned>(r.gentek));text(r.implementation);text(r.definition_fingerprint);text(r.source_identity);
        integer(r.seed);integer(r.request_digest);integer(r.material_digest);integer(r.digest);
        integer(r.width);integer(r.height);integer(static_cast<unsigned>(r.status));text(r.termination);
        numbers(r.cells);numbers(r.roles);numbers(r.provenance);integer(r.instances.size());
        for(const auto& i:r.instances) {
            integer(i.id);text(i.kind);point(i.origin);integer(i.orientation);integer(i.structural);integer(i.damaged);
            integer(i.cells.size());for(auto p:i.cells)point(p);text(i.reason);
        }
        integer(r.connectors.size());for(const auto& c:r.connectors) {
            integer(c.id);integer(c.instance);integer(static_cast<unsigned>(c.family));point(c.a);point(c.b);point(c.facing);
            integer(c.required);integer(c.fulfilled);integer(c.counterpart);text(c.state);
        }
        integer(r.attachments.size());for(const auto& a:r.attachments) {
            integer(a.instance);point(a.point);point(a.target);text(a.kind);text(a.reason);
        }
        boundary(r.boundary);
        for(const auto* entries:{&r.metrics,&r.rejected}) {integer(entries->size());for(const auto& [k,v]:*entries){text(k);integer(v);}}
        integer(r.notes.size());for(const auto& note:r.notes)text(note);
        integer(r.work);integer(r.candidates);integer(r.solver_work);integer(static_cast<std::uint64_t>(r.backtracks));
        integer(r.protected_violations);integer(r.illegal_overlaps);integer(r.unresolved_joints);
    }
    void slot(const TransitionSlot& s) {
        integer(s.id);integer(s.instance);integer(s.connector);integer(static_cast<unsigned>(s.kind));
        point(s.a);point(s.b);point(s.facing);point({s.envelope.x,s.envelope.y});point({s.envelope.w,s.envelope.h});
        integer(s.clearance.size());for(auto p:s.clearance)point(p);
        integer(s.required);integer(s.hard);integer(std::bit_cast<std::uint64_t>(s.strength));text(s.owner);text(s.reason);
    }
    void decision(const SlotAdmission& d) {
        integer(d.slot_id);integer(d.mandatory);integer(d.selected);integer(d.witness_found);
        integer(static_cast<std::uint64_t>(d.rank));integer(static_cast<std::uint64_t>(d.nearest_forward_distance));
        point(d.witness_source);point(d.witness_peer);text(d.reason);
    }
};

bool admission_shape(const NegotiatedResult& n,std::string& reason) {
    const auto invalid=[&](const std::string& why){reason=why;return false;};
    const auto& fq=n.frame_request;const auto& mq=n.mosaic_request;const auto& f=n.control.fixture;
    if(!validate_request(fq,reason)||!validate_request(mq,reason))return false;
    const auto count=static_cast<std::size_t>(fq.width)*static_cast<std::size_t>(fq.height);
    if(fq.gentek!=Kind::Frameweaver||mq.gentek!=Kind::Mosaic||fq.width!=mq.width||fq.height!=mq.height||
       f.width!=fq.width||f.height!=fq.height||f.side.size()!=count||f.context.size()!=count||
       f.protected_void.size()!=count||f.transition.size()!=count||
       fq.context!=f.context||mq.context!=f.context||fq.protected_void!=f.protected_void||mq.protected_void!=f.protected_void||
       fq.transition!=f.transition||mq.transition!=f.transition||fq.origin!=mq.origin||
       mq.neighbor_cells!=n.frame.result.cells||n.frame.slots.size()>max_transition_slots)
        return invalid("admission requires the intact finite matched frame/peer preparation");
    for(const auto* r:{&n.frame.core,&n.frame.result}) {
        const auto size=r->cells.size();
        if((size!=count&&!(r==&n.frame.core&&size==0))||r->roles.size()!=size||r->provenance.size()!=size||
           (!r->boundary.protected_geometry.empty()&&r->boundary.protected_geometry.size()!=count)||
           (!r->boundary.transition.empty()&&r->boundary.transition.size()!=count)||
           r->instances.size()>fq.limits.max_instances||
           r->connectors.size()>static_cast<std::size_t>(fq.limits.max_instances)*fq.limits.max_connectors_per_instance||
           r->boundary.hard.size()>fq.limits.max_affordances||r->boundary.soft.size()>fq.limits.max_affordances||
           r->attachments.size()>2048||r->metrics.size()>256||r->rejected.size()>256||r->notes.size()>128)
            return invalid("invalid bounded frozen FRAMEWEAVER arrays or receipts");
        for(const auto& part:r->instances)if(part.cells.size()>count)
            return invalid("invalid bounded frozen FRAMEWEAVER footprint");
    }
    if(mq.neighbors.protected_geometry.size()!=count||n.frame.reservation_rejections.size()>1024||
       !n.mosaic.attempts.empty()||!n.mosaic.domains.empty()||!n.mosaic.categories.empty()||
       !n.no_offers.attempts.empty()||!n.seams.empty()||!n.metrics.empty()||!n.cells.empty())
        return invalid("admission preparation must precede candidate MOSAIC solving and final joins");
    std::set<std::uint32_t> ids;
    for(const auto& s:n.frame.slots) {
        const auto& b=s.envelope;
        if(s.id==0||!ids.insert(s.id).second||s.instance==0||s.connector==0||
           !inside(fq,s.a)||!inside(fq,s.b)||
           (s.kind!=SlotKind::PointSocket&&s.kind!=SlotKind::BearingSegment)||
           std::abs(static_cast<std::int64_t>(s.facing.x))+std::abs(static_cast<std::int64_t>(s.facing.y))!=1||
           (s.a.x!=s.b.x&&s.a.y!=s.b.y)||(s.b.x-s.a.x)*s.facing.x+(s.b.y-s.a.y)*s.facing.y!=0||
           distance(s.a,s.b)>32||(s.kind==SlotKind::PointSocket)!=(s.a==s.b)||
           b.x<0||b.y<0||b.w<1||b.h<1||b.w>64||b.h>64||b.x>fq.width-b.w||b.y>fq.height-b.h||
           !in_rect(s.a,b)||!in_rect(s.b,b)||s.clearance.size()>4096||s.owner!="FRAMEWEAVER"||s.reason.size()>512||
           !std::isfinite(s.strength)||s.strength<0||s.strength>1||(s.required&&!s.hard))
            return invalid("invalid frozen reservation or softened required mechanical condition");
        const auto connector=std::find_if(n.frame.result.connectors.begin(),n.frame.result.connectors.end(),[&](const auto& c){
            return c.id==s.connector&&c.instance==s.instance&&c.a==s.a&&c.b==s.b&&c.facing==s.facing&&c.required==s.required;
        });
        if(connector==n.frame.result.connectors.end())return invalid("reservation has no exact frozen mechanical connector");
        for(auto p:line(s.a,s.b))if(n.frame.result.cells[index(fq,p)]==Material::Empty||
                                   (!mq.eligible.empty()&&mq.eligible[index(mq,p)]))
            return invalid("reservation source is not immutable foreign-owned material");
        for(auto p:s.clearance)if(!inside(mq,p)||!in_rect(p,b)||
            (!mq.protected_void[index(mq,p)]&&!mq.neighbors.protected_geometry[index(mq,p)]))
            return invalid("full original reservation clearance was not preserved");
    }
    reason.clear();return true;
}

// Hash the actual frozen geometry/masks/graph rather than trusting cached result
// digests. This is a mutation guard for this one case container, not a new IR.
std::uint64_t admission_input_digest(const NegotiatedResult& n) {
    AdmissionHash h;
    for(const auto* q:{&n.frame_request,&n.mosaic_request}) {
        h.integer(begin_result(*q,"admission-input-identity").request_digest);h.text(q->definition_fingerprint);
    }
    const auto& f=n.control.fixture;
    h.text(f.id);h.integer(f.width);h.integer(f.height);h.integer(f.digest);
    h.numbers(f.side);h.numbers(f.context);h.numbers(f.protected_void);h.numbers(f.transition);
    h.result(n.frame.core);h.result(n.frame.result);h.integer(n.frame.slots.size());
    for(const auto& slot:n.frame.slots)h.slot(slot);
    h.integer(n.frame.reservation_rejections.size());for(const auto& r:n.frame.reservation_rejections)h.text(r);
    h.integer(n.control.digest);h.text(n.offer_policy);return h.value;
}
std::uint64_t admission_ranking_digest(const PreparedAdmission& p) {
    AdmissionHash h;h.integer(p.ranking_work);h.integer(p.ranking.size());
    for(const auto& row:p.ranking)h.decision(row);
    return h.value;
}
void finish_admission_digest(AdmissionResult& r) {
    auto& a=r.admission;AdmissionHash h;
    h.integer(static_cast<unsigned>(a.policy.mode));h.integer(a.policy.optional_cap);h.integer(a.policy.omitted_optional_id);
    h.integer(static_cast<unsigned>(a.status));h.text(a.reason);h.numbers(a.selected_ids);
    h.integer(a.decisions.size());for(const auto& d:a.decisions)h.decision(d);
    h.integer(a.work);h.integer(a.work_limit);h.integer(a.ranking_work);h.integer(a.selection_work);h.integer(a.join_work_limit);
    h.integer(a.structural_work_upper_bound);h.integer(a.solver_work_limit);h.integer(a.diagnostic);
    a.digest=h.value;r.digest=mix(a.digest^r.candidate.digest);
}
} // namespace

const char* name(AdmissionMode mode) noexcept {
    switch(mode) {
    case AdmissionMode::Full:return "full";
    case AdmissionMode::OptionalCap:return "optional-cap";
    case AdmissionMode::LeaveOneOut:return "leave-one-out";
    }
    return "invalid";
}

PreparedAdmission prepare_admission(const Fixture& f,const Profile& p,std::uint64_t seed,
                                    const std::string& source,bool reverse) {
    PreparedAdmission out;out.prepared=prepare_case(f,p,seed,source,reverse,false,true);
    if(!admission_shape(out.prepared,out.reason)) {out.status=Status::Invalid;return out;}
    const auto& mq=out.prepared.mosaic_request;
    for(const auto& slot:out.prepared.frame.slots) {
        ++out.ranking_work;SlotAdmission row;row.slot_id=slot.id;row.mandatory=slot.required||slot.hard;
        if(row.mandatory)row.reason="required or already-hard mechanical condition retained outside optional ranking";
        else {
            int best=std::numeric_limits<int>::max();
            // These are prospective eligible exposed cells, not solved native
            // motifs or certified contacts. The score is only a Manhattan lower
            // bound: it neither searches a path nor tests any category predicate.
            for(int y=slot.envelope.y;y<slot.envelope.y+slot.envelope.h;++y)
                for(int x=slot.envelope.x;x<slot.envelope.x+slot.envelope.w;++x) {
                    ++out.ranking_work;
                    const Point peer{x,y};
                    const Point source_point{std::clamp(x,std::min(slot.a.x,slot.b.x),std::max(slot.a.x,slot.b.x)),
                                             std::clamp(y,std::min(slot.a.y,slot.b.y),std::max(slot.a.y,slot.b.y))};
                    if(!allowed(mq,peer)||!transition_at(mq,peer)||allowed(mq,{x-slot.facing.x,y-slot.facing.y})||
                       (x-source_point.x)*slot.facing.x+(y-source_point.y)*slot.facing.y<=0)continue;
                    const auto score=distance(source_point,peer);
                    if(!row.witness_found||std::tuple{score,peer,source_point}<std::tuple{best,row.witness_peer,row.witness_source}) {
                        best=score;row.witness_found=true;row.witness_peer=peer;row.witness_source=source_point;
                    }
                }
            if(row.witness_found) {
                row.nearest_forward_distance=best;
                row.reason="Manhattan lower bound to a prospective exposed eligible peer face; no category or path feasibility tested";
            } else row.reason="no prospective exposed eligible peer face in envelope; ranked last and still consumes a cap position";
        }
        out.ranking.push_back(std::move(row));
    }
    out.ranking_work+=max_transition_slots*max_transition_slots;
    std::sort(out.ranking.begin(),out.ranking.end(),[](const auto& a,const auto& b){
        return std::tuple{!a.mandatory,!a.witness_found,a.nearest_forward_distance,a.slot_id}<
               std::tuple{!b.mandatory,!b.witness_found,b.nearest_forward_distance,b.slot_id};
    });
    int rank=0;for(auto& row:out.ranking)if(!row.mandatory)row.rank=rank++;
    out.ranking_digest=admission_ranking_digest(out);
    // Even the historical B control is generated only after this immutable
    // ranking exists; no MOSAIC solve can feed back into the ranking.
    out.prepared.control=mesh(f,Kind::Frameweaver,Kind::Mosaic,p,seed,source,reverse);
    out.input_digest=admission_input_digest(out.prepared);
    out.reason="one frozen frame and full clearance masks; optional geometry ranking fixed before candidate solving";
    return out;
}

AdmissionResult negotiate_admission(const PreparedAdmission& prepared,const AdmissionPolicy& policy,
                                    bool reverse,bool finish,std::uint64_t diagnostic_solver_ceiling) {
    AdmissionResult out;auto& a=out.admission;a.policy=policy;
    a.diagnostic=diagnostic_solver_ceiling!=0;
    const auto invalid=[&](const std::string& why) {
        a.status=Status::Invalid;a.reason=why;
        // Reject before invoking either categorical solve or shared joining.
        out.candidate.mosaic.result.status=Status::Invalid;out.candidate.mosaic.result.termination=why;
        finish_admission_digest(out);return out;
    };
    std::string reason;
    if(prepared.status!=Status::Complete||!admission_shape(prepared.prepared,reason))
        return invalid("invalid frozen admission preparation: "+(reason.empty()?prepared.reason:reason));
    if(prepared.ranking.size()!=prepared.prepared.frame.slots.size()||prepared.ranking_work>admission_shared_limit-admission_selection_charge||
       prepared.input_digest!=admission_input_digest(prepared.prepared)||prepared.ranking_digest!=admission_ranking_digest(prepared))
        return invalid("frozen admission inputs or rank-once receipts were modified");
    switch(policy.mode) {
    case AdmissionMode::Full:
        if(policy.optional_cap||policy.omitted_optional_id)return invalid("full policy cannot carry a cap or omitted ID");
        break;
    case AdmissionMode::OptionalCap:
        if(policy.optional_cap>max_transition_slots||policy.omitted_optional_id)return invalid("optional cap must be within 0..8 and carry no omitted ID");
        break;
    case AdmissionMode::LeaveOneOut: {
        if(policy.optional_cap||!policy.omitted_optional_id)return invalid("leave-one-out requires exactly one nonzero optional ID and no cap");
        const auto slot=std::find_if(prepared.prepared.frame.slots.begin(),prepared.prepared.frame.slots.end(),[&](const auto& s){return s.id==policy.omitted_optional_id;});
        if(slot==prepared.prepared.frame.slots.end()||slot->required||slot->hard)return invalid("leave-one-out may omit only an existing optional, non-hard reservation");
        break;
    }
    default:return invalid("unknown admission policy");
    }
    const auto& fq=prepared.prepared.frame_request;const auto& mq=prepared.prepared.mosaic_request;
    if(diagnostic_solver_ceiling&&(diagnostic_solver_ceiling!=2'000'000||diagnostic_solver_ceiling>mq.limits.max_solver_work))
        return invalid("the registered equal-first-budget diagnostic requires exactly 2M without increasing the primary request");
    a.solver_work_limit=diagnostic_solver_ceiling?diagnostic_solver_ceiling:mq.limits.max_solver_work;
    a.structural_work_upper_bound=fq.limits.max_work+mq.limits.max_work+mq.limits.max_solver_work+admission_shared_limit;
    a.ranking_work=prepared.ranking_work;a.selection_work=admission_selection_charge;a.work=a.ranking_work+a.selection_work;
    a.join_work_limit=admission_shared_limit-a.work;a.decisions=prepared.ranking;
    for(auto& row:a.decisions) {
        row.selected=row.mandatory||policy.mode==AdmissionMode::Full||
            (policy.mode==AdmissionMode::OptionalCap&&row.rank>=0&&static_cast<std::uint32_t>(row.rank)<policy.optional_cap)||
            (policy.mode==AdmissionMode::LeaveOneOut&&row.slot_id!=policy.omitted_optional_id);
        if(row.selected)a.selected_ids.push_back(row.slot_id);
        row.reason+=row.mandatory?"; retained hard by every policy":row.selected?"; selected by fixed policy":"; omitted by fixed policy; no solver influence or shared join authority";
    }
    std::sort(a.selected_ids.begin(),a.selected_ids.end());
    std::vector<TransitionSlot> offers;
    for(const auto& slot:prepared.prepared.frame.slots)if(std::binary_search(a.selected_ids.begin(),a.selected_ids.end(),slot.id)) {
        offers.push_back(slot);if(slot.required||slot.hard)offers.back().hard=true;
    }
    auto candidate=prepared.prepared;
    if(diagnostic_solver_ceiling)candidate.mosaic_request.limits.max_solver_work=diagnostic_solver_ceiling;
    out.candidate=finish_case(std::move(candidate),reverse,finish,&offers,a.join_work_limit);
    a.reason="fixed admission applied once; no outcome-dependent subset search, rank refill, or enlarged structural work ceiling";
    if(a.diagnostic)a.reason+="; separately labelled lower-only solver-budget diagnostic";
    finish_admission_digest(out);return out;
}

namespace {
void finish_resilience_digest(ResilienceResult& out) {
    AdmissionHash h;
    h.integer(out.candidate.digest);
    h.integer(static_cast<unsigned>(out.options.admission));
    h.integer(static_cast<unsigned>(out.options.schedule));
    h.integer(static_cast<unsigned>(out.options.fallback));
    h.integer(static_cast<unsigned>(out.options.receivers));
    h.integer(out.options.optional_capacity);
    h.integer(out.preparation_work);h.integer(out.join_work_limit);
    const auto& t=out.trace;
    h.text(t.reason);h.numbers(t.primary_selected_ids);h.numbers(t.fallback_selected_ids);
    h.numbers(t.final_authorized_ids);h.numbers(t.dropped_preference_ids);
    h.integer(t.receivers.size());
    for(const auto& r:t.receivers) {
        h.integer(r.slot_id);h.integer(r.original_tile);h.integer(r.selected_tile);
        h.point(r.original_contact);h.point(r.selected_contact);
        h.integer(r.original_compatible_domain);h.integer(r.original_supported_domain);
        h.integer(r.selected_compatible_domain);h.integer(r.selected_supported_domain);
        h.integer(r.original_admitted);h.integer(r.changed);h.integer(r.work);h.integer(r.points_examined);
        h.text(r.reason);h.integer(r.faces.size());
        for(const auto& f:r.faces) {
            h.point(f.contact);h.integer(f.tile);h.integer(f.original_domain);h.integer(f.compatible_domain);
            h.integer(f.supported_domain);h.integer(f.distance);h.integer(f.selected);
        }
    }
    const auto& a=t.admission;
    h.integer(static_cast<unsigned>(a.status));h.text(a.reason);h.integer(a.work);
    h.integer(a.optional_capacity);h.integer(a.fallback_optional_capacity);
    h.numbers(a.selected_ids);h.numbers(a.fallback_ids);h.numbers(a.original_domains);
    h.numbers(a.hard_domains);h.numbers(a.preferred_domains);h.numbers(a.fallback_domains);
    h.integer(a.decisions.size());
    for(const auto& d:a.decisions) {
        h.integer(d.slot_id);h.integer(d.tile);h.integer(d.hard);h.integer(d.geometry_admitted);
        h.integer(d.selected);h.integer(d.fallback_selected);h.integer(d.domain_changed);h.integer(d.fallback_domain_changed);
        h.integer(d.rank);h.integer(d.distance);h.point(d.contact);
        h.integer(d.compatible_domain);h.integer(d.locally_supported_domain);h.integer(d.original_domain);
        h.integer(d.hard_domain);h.integer(d.projected_domain);h.integer(d.fallback_domain);
        for(auto pool:d.neighbor_pool)h.integer(pool);
        h.integer(d.neighbor_support);h.integer(d.conflicts_with);h.text(d.disposition);h.text(d.reason);
    }
    const auto& s=t.solver;
    h.integer(s.width);h.integer(s.height);h.integer(s.seed);h.integer(s.aggregate_limit);
    h.integer(s.allocated_limit);h.integer(s.attempted_limit);h.integer(s.preparation_work);h.integer(s.fallback_used);
    h.numbers(s.category_ids);for(const auto& row:s.adjacency)for(auto mask:row)h.integer(mask);
    h.numbers(s.primary_optional_ids);h.numbers(s.fallback_optional_ids);h.integer(s.attempts.size());
    for(const auto& attempt:s.attempts) {
        const auto& record=attempt.solver;
        h.text(record.policy);h.text(record.reason);h.integer(static_cast<unsigned>(record.status));
        h.integer(record.attempted);h.integer(record.work_observed);h.integer(record.work);h.integer(record.work_limit);
        h.numbers(attempt.domains);h.numbers(attempt.optional_ids);h.numbers(attempt.categories);
        h.text(attempt.trigger);h.integer(attempt.fallback);
    }
    out.digest=h.value;
}
} // namespace

ResilienceResult negotiate_resilient(const PreparedAdmission& prepared,const ResilienceOptions& options,bool reverse) {
    ResilienceResult out;out.options=options;
    const auto invalid=[&](const std::string& why) {
        out.trace.reason=why;out.trace.admission.status=Status::Invalid;out.trace.admission.reason=why;
        out.candidate.mosaic.result.status=Status::Invalid;out.candidate.mosaic.result.termination=why;
        finish_resilience_digest(out);return out;
    };
    if(!valid_resilience_options(options))return invalid("unregistered resilience admission/schedule/receiver/capacity combination");
    std::string reason;
    if(prepared.status!=Status::Complete||!admission_shape(prepared.prepared,reason))
        return invalid("invalid frozen resilience preparation: "+(reason.empty()?prepared.reason:reason));
    if(prepared.ranking.size()!=prepared.prepared.frame.slots.size()||
       prepared.ranking_work>admission_shared_limit-admission_selection_charge||
       prepared.input_digest!=admission_input_digest(prepared.prepared)||
       prepared.ranking_digest!=admission_ranking_digest(prepared))
        return invalid("frozen resilience inputs or rank-once receipts were modified");
    out.preparation_work=prepared.ranking_work+admission_selection_charge;
    out.join_work_limit=admission_shared_limit-out.preparation_work;
    auto candidate=prepared.prepared;
    candidate.offer_policy=std::string("SWARM-003; ")+name(options.admission)+"; "+name(options.schedule)+"; "+
        name(options.fallback)+"; "+name(options.receivers);
    if(options.optional_capacity!=4)candidate.offer_policy+="; optional-capacity="+std::to_string(options.optional_capacity);
    auto offers=candidate.frame.slots;
    for(auto& slot:offers)if(slot.required||slot.hard)slot.hard=true;
    out.candidate=finish_case(std::move(candidate),reverse,false,&offers,out.join_work_limit,&options,&out.trace);
    finish_resilience_digest(out);return out;
}
} // namespace cybersand::gentek_swarm
