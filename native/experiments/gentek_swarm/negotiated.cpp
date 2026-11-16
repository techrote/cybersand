#include "negotiated.hpp"
#include <algorithm>
#include <array>
#include <bit>
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
void final_join(NegotiatedResult& out,const Request& fq,const Request& mq) {
    auto& a=out.final_frame; auto& b=out.final_mosaic;
    const auto& f=out.control.fixture;
    std::set<Point> used;
    for(const auto& slot:out.frame.slots) {
        Seam seam;seam.left_affordance=slot.id;seam.a=slot.a;
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
                    if(out.work>=2'000'000) {legal=false;out.metrics["shared_exhausted"]=1;break;}
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
NegotiatedResult negotiate(const Fixture& f,const Profile& p,std::uint64_t seed,
                           const std::string& source,bool reverse,bool force_hard,bool finish) {
    NegotiatedResult out;out.control=mesh(f,Kind::Frameweaver,Kind::Mosaic,p,seed,source,reverse);
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
    auto offers=out.frame.slots;if(reverse)std::reverse(offers.begin(),offers.end());
    if(reverse){out.no_offers=negotiate_mosaic(mq,{});out.mosaic=negotiate_mosaic(mq,offers);}
    else{out.mosaic=negotiate_mosaic(mq,offers);out.no_offers=negotiate_mosaic(mq,{});}
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
    if(usable(out.final_frame)&&usable(out.final_mosaic))final_join(out,fq,mq);
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
} // namespace cybersand::gentek_swarm
