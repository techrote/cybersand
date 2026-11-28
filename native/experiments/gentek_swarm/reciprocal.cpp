#include "reciprocal.hpp"
#include "reciprocal_io.hpp"
#include "recovery_admission.hpp"
#include <algorithm>
#include <array>
#include <cmath>
#include <deque>
#include <limits>
#include <numeric>
#include <set>
#include <tuple>

namespace cybersand::gentek_swarm::assembly004 {
// Only assemble() can attach a freshly minted authority to a Composition.
// Public copies retain it immutably; edits cannot reseal their own transcript.
// This authenticates native observations, not material correctness: the final
// grammar, ownership, continuous-path and obligation proofs still run below.
class NativeRunAuthority final {
    friend Composition assemble(const Input&, bool);
    friend bool validate_composition(Composition&);
    CustodyDigest transcript;
    std::map<std::string,std::uint64_t> reported_metrics;
    std::string reported_stop, reported_reason;
    const std::atomic_bool* cancellation_token;
    NativeRunAuthority(CustodyDigest value,const Composition& c):transcript(value),reported_metrics(c.metrics),reported_stop(c.stop_reason),reported_reason(c.reason),cancellation_token(c.input.cancel){}
};
namespace {
constexpr std::array<Point,4> dirs{{{1,0},{0,1},{-1,0},{0,-1}}};
Point plus(Point a, Point b) { return {a.x+b.x,a.y+b.y}; }
Point minus(Point a, Point b) { return {a.x-b.x,a.y-b.y}; }
Point neg(Point a) { return {-a.x,-a.y}; }
int dist(Point a, Point b) { return std::abs(a.x-b.x)+std::abs(a.y-b.y); }
bool cardinal(Point d) { return std::abs(static_cast<std::int64_t>(d.x))+std::abs(static_cast<std::int64_t>(d.y))==1; }
bool usable(const Result& r) { return r.status==Status::Complete || r.status==Status::Blocked || r.status==Status::Damaged; }
bool cancelled(const Input& in) { return in.cancel && in.cancel->load(std::memory_order_relaxed); }
bool structural(Role r) { return r==Role::Structure || r==Role::Brace || r==Role::Transition; }
bool native_bearing(Material m,Role r) { return structural(r)&&m!=Material::Empty&&material_definition(m).state==MaterialState::Solid; }
std::uint64_t derivative_work(const Result& r) {
    std::uint64_t work=r.cells.size()*16ULL+r.connectors.size()*(r.instances.size()*3ULL+32ULL)+
        r.boundary.hard.size()*(r.instances.size()+32ULL)+r.attachments.size()*(r.instances.size()+32ULL);
    for(const auto& p:r.instances)work+=p.cells.size()*3ULL+p.kind.size()+p.reason.size()+32ULL;
    return work;
}
bool mask_at(const std::vector<std::uint8_t>& v,std::size_t i) { return !v.empty() && v[i]!=0; }
unsigned rotation(Point d) { return d.x==1?0U:d.y==1?1U:d.x==-1?2U:3U; }
bool frame_charge(Budget& b,std::uint64_t work) {
    if(b.work>b.limits.max_work||work>b.limits.max_work-b.work)return false;
    b.work+=work;return !(b.cancel&&b.cancel->load(std::memory_order_relaxed));
}
bool charge_shared(Composition& c,std::uint64_t n=1) {
    auto& work=c.metrics["shared_work"];
    if(work>2'000'000 || n>2'000'000-work) return false;
    work+=n; return true;
}
std::uint64_t total_work(const Composition& c) {
    std::uint64_t total=0;
    for(const auto* key:{"frame_work","mosaic_work","solver_work","shared_work"}) {
        const auto found=c.metrics.find(key);const auto value=found==c.metrics.end()?0:found->second;
        if(value>std::numeric_limits<std::uint64_t>::max()-total)return std::numeric_limits<std::uint64_t>::max();
        total+=value;
    }
    return total;
}
bool in_box(Point p,Rect b) { return p.x>=b.x && p.y>=b.y && p.x<b.x+b.w && p.y<b.y+b.h; }
std::vector<int> interface_distance(const Input& input) {
    const auto& f=input.frame;const auto& m=input.mosaic;const auto n=f.eligible.size();
    std::vector<int> distance(n,999);std::deque<std::size_t> frontier;
    for(std::size_t i=0;i<n;++i)if(f.eligible[i]||m.eligible[i]) {
        const Point p{static_cast<int>(i%f.width),static_cast<int>(i/f.width)};
        for(auto d:dirs){const auto v=plus(p,d);if(!inside(f,v))continue;const auto j=index(f,v);
            if((f.eligible[i]&&m.eligible[j])||(m.eligible[i]&&f.eligible[j])){distance[i]=0;frontier.push_back(i);break;}}
    }
    while(!frontier.empty()) {
        const auto i=frontier.front();frontier.pop_front();if(distance[i]>=static_cast<int>(input.options.shared_extent))continue;
        const Point p{static_cast<int>(i%f.width),static_cast<int>(i/f.width)};
        for(auto d:dirs){const auto v=plus(p,d);if(!inside(f,v))continue;const auto j=index(f,v);
            if((f.eligible[j]||m.eligible[j])&&distance[j]>distance[i]+1){distance[j]=distance[i]+1;frontier.push_back(j);}}
    }
    return distance;
}
bool paired_input_valid(const Input& input,std::string& why) {
    if(!validate_request(input.frame,why)||!validate_request(input.mosaic,why))return false;
    const auto& f=input.frame;const auto& m=input.mosaic;const auto n=static_cast<std::size_t>(f.width)*static_cast<std::size_t>(f.height);
    if(f.gentek!=Kind::Frameweaver||m.gentek!=Kind::Mosaic||f.width!=m.width||f.height!=m.height||f.origin!=m.origin||
       f.seed!=m.seed||f.source_identity!=m.source_identity||f.context!=m.context||f.protected_void!=m.protected_void||f.transition!=m.transition||
       f.eligible.size()!=n||m.eligible.size()!=n||input.shared_zone.size()!=n||
       input.options.rounds>4||input.options.shared_extent>13||input.options.orientation_preference < -1||input.options.orientation_preference>1||
       f.limits.max_instances>64||m.limits.max_instances>192||f.limits.max_frontier>256||m.limits.max_frontier>256||
       f.limits.max_work>2'000'000||m.limits.max_work>2'000'000||m.limits.max_solver_work>4'000'000||
       f.limits.max_candidates>8192||m.limits.max_candidates>8192||f.limits.max_bytes>16U*1024U*1024U||m.limits.max_bytes>16U*1024U*1024U) {
        why="mismatched source, territory or registered resource limit";return false;
    }
    for(std::size_t i=0;i<n;++i)if((f.eligible[i]&&m.eligible[i])||input.shared_zone[i]>1||
       (input.shared_zone[i]&&(!mask_at(f.transition,i)||!input.options.shared_ownership||input.options.shared_extent==0))) {
        why="overlapping exclusive territory or shared zone outside finite band";return false;
    }
    const auto distance=interface_distance(input);
    for(std::size_t i=0;i<n;++i)if(input.shared_zone[i]&&(!(f.eligible[i]||m.eligible[i])||distance[i]>static_cast<int>(input.options.shared_extent))) {
        why="shared cell exceeds bounded real territory interface";return false;
    }
    why.clear();return true;
}
bool same_port(const Affordance& a,const Affordance& b) {
    return a.id==b.id&&a.instance==b.instance&&a.a==b.a&&a.b==b.b&&a.facing==b.facing&&
        a.family==b.family&&a.required==b.required&&a.strength==b.strength&&a.tag==b.tag;
}
bool same_connections(const Result& a,const Result& b) {
    if(a.connectors.size()!=b.connectors.size()||a.attachments.size()!=b.attachments.size())return false;
    for(std::size_t i=0;i<a.connectors.size();++i){const auto& x=a.connectors[i];const auto& y=b.connectors[i];
        if(x.id!=y.id||x.instance!=y.instance||x.family!=y.family||x.a!=y.a||x.b!=y.b||x.facing!=y.facing||
           x.required!=y.required||x.fulfilled!=y.fulfilled||x.counterpart!=y.counterpart||x.state!=y.state)return false;}
    for(std::size_t i=0;i<a.attachments.size();++i){const auto& x=a.attachments[i];const auto& y=b.attachments[i];
        if(x.instance!=y.instance||x.point!=y.point||x.target!=y.target||x.kind!=y.kind||x.reason!=y.reason)return false;}
    return true;
}
bool same_native_input(const Result& a,const Result& b) {
    if(a.status!=b.status||a.width!=b.width||a.height!=b.height||a.seed!=b.seed||a.source_identity!=b.source_identity||
       a.cells!=b.cells||a.roles!=b.roles||a.provenance!=b.provenance||
       a.boundary.protected_geometry!=b.boundary.protected_geometry||a.boundary.transition!=b.boundary.transition||
       a.boundary.hard.size()!=b.boundary.hard.size()||a.boundary.soft.size()!=b.boundary.soft.size()||a.instances.size()!=b.instances.size())return false;
    for(std::size_t k=0;k<a.boundary.hard.size();++k)if(!same_port(a.boundary.hard[k],b.boundary.hard[k]))return false;
    for(std::size_t k=0;k<a.boundary.soft.size();++k){const auto& x=a.boundary.soft[k];const auto& y=b.boundary.soft[k];
        if(x.point!=y.point||x.direction!=y.direction||x.strength!=y.strength||x.preference!=y.preference)return false;}
    for(std::size_t k=0;k<a.instances.size();++k){const auto& x=a.instances[k];const auto& y=b.instances[k];
        if(x.id!=y.id||x.kind!=y.kind||x.origin!=y.origin||x.orientation!=y.orientation||x.structural!=y.structural||x.damaged!=y.damaged||x.cells!=y.cells||x.reason!=y.reason)return false;}
    return true;
}
bool same_slots(const std::vector<TransitionSlot>& a,const std::vector<TransitionSlot>& b) {
    if(a.size()!=b.size())return false;
    for(std::size_t k=0;k<a.size();++k){const auto& x=a[k];const auto& y=b[k];
        if(x.id!=y.id||x.instance!=y.instance||x.connector!=y.connector||x.a!=y.a||x.b!=y.b||x.facing!=y.facing||
           x.kind!=y.kind||x.required!=y.required||x.hard!=y.hard||x.strength!=y.strength||x.clearance!=y.clearance||
           x.envelope.x!=y.envelope.x||x.envelope.y!=y.envelope.y||x.envelope.w!=y.envelope.w||x.envelope.h!=y.envelope.h||x.owner!=y.owner)return false;}
    return true;
}
std::uint64_t changed(const Result& a,const Result& b) {
    if(a.cells.size()!=b.cells.size()) return std::max(a.cells.size(),b.cells.size());
    std::uint64_t n=0; for(std::size_t i=0;i<a.cells.size();++i)n+=a.cells[i]!=b.cells[i]; return n;
}
std::uint64_t footprint_changed(const Result& a,const Result& b) {
    if(a.cells.size()!=b.cells.size())return std::max(a.cells.size(),b.cells.size());
    std::uint64_t n=0;for(std::size_t i=0;i<a.cells.size();++i)n+=(a.cells[i]==Material::Empty)!=(b.cells[i]==Material::Empty);return n;
}
bool same_mosaic_observation(const MosaicPlan& a,const MosaicPlan& b) {
    if(!same_native_input(a.result,b.result)||a.categories!=b.categories||a.responses.size()!=b.responses.size())return false;
    for(std::size_t i=0;i<a.responses.size();++i) {
        const auto& x=a.responses[i];const auto& y=b.responses[i];
        if(x.slot_id!=y.slot_id||x.tile!=y.tile||x.admitted!=y.admitted||x.satisfied!=y.satisfied||
           x.contact!=y.contact||x.facing!=y.facing||x.compatible_domain!=y.compatible_domain)return false;
    }
    return true;
}
bool same_socket(const PlacedSocket& a,const PlacedSocket& b) {
    return a.id==b.id&&a.instance==b.instance&&a.source_socket==b.source_socket&&a.a==b.a&&a.b==b.b&&
        a.facing==b.facing&&a.family==b.family&&a.obligation==b.obligation;
}
bool same_assembly(const ExpandedAssembly& a,const ExpandedAssembly& b) {
    if(a.outcome!=b.outcome||a.owner!=b.owner||a.nodes.size()!=b.nodes.size()||a.instances.size()!=b.instances.size()||a.claims.size()!=b.claims.size()||
       a.declared_cells!=b.declared_cells||a.shared_joint_cells!=b.shared_joint_cells||
       a.sockets.size()!=b.sockets.size()||a.joints.size()!=b.joints.size())return false;
    for(std::size_t i=0;i<a.nodes.size();++i){const auto& x=a.nodes[i];const auto& y=b.nodes[i];
        if(x.id!=y.id||x.parent!=y.parent||x.spec!=y.spec||x.depth!=y.depth||x.child_slot!=y.child_slot||x.assembly!=y.assembly||
           x.rule!=y.rule||x.transform.translation!=y.transform.translation||x.transform.quarter_turns!=y.transform.quarter_turns)return false;}
    for(std::size_t i=0;i<a.claims.size();++i){const auto& x=a.claims[i];const auto& y=b.claims[i];
        if(x.point!=y.point||x.material!=y.material||x.role!=y.role||x.owner!=y.owner||x.instance!=y.instance||x.spec!=y.spec||x.rule!=y.rule)return false;}
    for(std::size_t i=0;i<a.instances.size();++i){const auto& x=a.instances[i];const auto& y=b.instances[i];
        if(x.instance!=y.instance||x.parent!=y.parent||x.spec!=y.spec||x.depth!=y.depth||x.name!=y.name||x.rule!=y.rule||
           x.node!=y.node||x.transform.translation!=y.transform.translation||x.transform.quarter_turns!=y.transform.quarter_turns||x.sockets.size()!=y.sockets.size())return false;
        for(std::size_t j=0;j<x.sockets.size();++j)if(!same_socket(x.sockets[j],y.sockets[j]))return false;}
    for(std::size_t i=0;i<a.sockets.size();++i)if(!same_socket(a.sockets[i],b.sockets[i]))return false;
    for(std::size_t i=0;i<a.joints.size();++i){const auto& x=a.joints[i];const auto& y=b.joints[i];
        if(x.instance_a!=y.instance_a||x.socket_a!=y.socket_a||x.instance_b!=y.instance_b||x.socket_b!=y.socket_b||x.family!=y.family||x.cells!=y.cells)return false;}
    return true;
}
bool certify_owned_parts(Composition& c,const Construction& part,const Result& material) {
    const auto& q=c.input.frame;const auto& assembly=part.assembly;
    const auto refuse=[&](const std::string& why){c.status=CompositionStatus::Invalid;c.reason=why;return false;};
    std::array<const Instance*,257> native_parts{};
    for(const auto& p:material.instances)native_parts[p.id]=&p;
    if(part.base_instance==0||part.base_instance>256||!native_parts[part.base_instance]||part.parts.empty()||part.parts.size()>64)
        return refuse("assembly lacks its original host or newly owning parts");
    for(const auto& claim:assembly.claims) {
        if(!charge_shared(c)){c.status=CompositionStatus::Exhausted;c.reason="claim provenance certificate allowance";return false;}
        if(!inside(q,claim.point))return refuse("authored claim outside finite canvas");
        const auto i=index(q,claim.point);const auto owner=material.provenance[i];
        if(material.cells[i]!=claim.material||!structural(material.roles[i]))return refuse("authored claim differs from installed native material");
        if(owner==part.base_instance) {
            if(dist(claim.point,part.root)>2||c.original_frame.result.cells[i]!=claim.material||
               c.original_frame.result.provenance[i]!=part.base_instance)return refuse("assembly claims an unproven original host weld");
        }else if(material.roles[i]!=claim.role||std::find(part.parts.begin(),part.parts.end(),owner)==part.parts.end())
            return refuse("authored claim lacks its exact native owner and role");
    }
    std::set<std::uint32_t> actual_parts,reused_components;
    for(const auto& component:assembly.instances) {
        std::uint32_t native_owner=0;std::vector<Point> footprint;
        for(const auto& claim:assembly.claims)if(claim.instance==component.instance) {
            if(!charge_shared(c)){c.status=CompositionStatus::Exhausted;c.reason="part provenance certificate allowance";return false;}
            footprint.push_back(claim.point);const auto owner=material.provenance[index(q,claim.point)];
            if(owner!=part.base_instance) {
                if(native_owner&&native_owner!=owner)return refuse("authored component has ambiguous native ownership");
                native_owner=owner;
            }
        }
        if(!native_owner){reused_components.insert(component.instance);continue;}
        const auto* native_part=native_parts[native_owner];
        if(!native_part||!actual_parts.insert(native_owner).second||native_part->kind!="swarm004/"+component.name||
           native_part->reason!=component.rule||native_part->origin!=component.transform.translation||
           native_part->orientation!=static_cast<int>(component.transform.quarter_turns)||!native_part->structural||native_part->cells!=footprint)
            return refuse("installed native part differs from its authored component");
    }
    if(actual_parts.size()!=part.parts.size()||actual_parts!=std::set<std::uint32_t>(part.parts.begin(),part.parts.end())||
       reused_components.size()!=part.reused_host_components.size()||reused_components!=std::set<std::uint32_t>(part.reused_host_components.begin(),part.reused_host_components.end()))
        return refuse("assembly native owner and host reuse mapping differs from its certificate");
    return true;
}
bool certify_assembly(Composition& c,const Construction& part,unsigned round,const Result& material) {
    const auto& assembly=part.assembly;
    const auto refuse=[&](const std::string& why){c.status=CompositionStatus::Invalid;c.reason=why;return false;};
    if(assembly.nodes.empty()||assembly.instances.empty()||assembly.claims.empty()||assembly.sockets.empty()||
       assembly.round>round||assembly.revision>round||!inside(c.input.frame,part.root)||!cardinal(part.facing))return refuse("incomplete authored assembly certificate");
    const bool bearing=part.authored_symbol.assembly&&part.authored_symbol.id==backward_bearing;
    const bool extending=(part.authored_symbol.assembly&&(part.authored_symbol.id==nested_truss||part.authored_symbol.id==bracket))||
        (!part.authored_symbol.assembly&&part.authored_symbol.id==member);
    if(!bearing&&!extending)return refuse("unknown authored assembly certificate");
    Budget budget;budget.cancel=c.input.cancel;budget.limits.max_work=2'000'000-c.metrics["shared_work"];
    const auto grammar=bearing?bearing_grammar(part.span,part.rise,part.input_family,part.handedness):frame_grammar(part.span,part.rise,part.input_family);
    const auto certificate=expand(grammar,part.authored_symbol,{part.root,rotation(part.facing)},assembly.round,assembly.revision,budget);
    if(!charge_shared(c,budget.work)||certificate.outcome==Outcome::Exhausted){c.status=CompositionStatus::Exhausted;c.reason="authored assembly certificate allowance";return false;}
    c.metrics["assembly_validation_work"]+=budget.work;
    if(certificate.outcome!=Outcome::Complete||certificate.digest!=assembly.digest||!same_assembly(certificate,assembly))return refuse("authored assembly differs from its compiled grammar certificate");
    for(const auto& claim:assembly.claims)if(claim.round!=assembly.round||claim.revision!=assembly.revision)return refuse("claim revision differs from its authored assembly certificate");
    return certify_owned_parts(c,part,material);
}
bool same_architecture(const Round& a,const Round& b) {
    if(!same_native_input(a.frame.result,b.frame.result)||!same_mosaic_observation(a.mosaic,b.mosaic)||
       !same_slots(a.frame.slots,b.frame.slots)||a.frame.constructions.size()!=b.frame.constructions.size())return false;
    if(!same_connections(a.frame.result,b.frame.result)||!same_connections(a.mosaic.result,b.mosaic.result))return false;
    for(std::size_t i=0;i<a.frame.constructions.size();++i){const auto& x=a.frame.constructions[i];const auto& y=b.frame.constructions[i];
        if(x.slot!=y.slot||x.connector!=y.connector||x.base_instance!=y.base_instance||x.root!=y.root||x.face!=y.face||
           x.facing!=y.facing||x.parts!=y.parts||x.reused_host_components!=y.reused_host_components||x.rule!=y.rule||
           x.authored_symbol.id!=y.authored_symbol.id||x.authored_symbol.assembly!=y.authored_symbol.assembly||x.span!=y.span||x.rise!=y.rise||
           x.handedness!=y.handedness||x.input_family!=y.input_family||!same_assembly(x.assembly,y.assembly))return false;}
    return true;
}
std::uint64_t semantic(const Round& r) {
    std::uint64_t h=mix(r.frame.result.material_digest)^mix(r.mosaic.result.material_digest);
    // Revision number, accounting and explanatory text are not semantic state.
    for(const auto* result:{&r.frame.result,&r.mosaic.result}) {
        for(const auto& a:result->boundary.hard) {
            h=mix(h^a.instance^static_cast<unsigned>(a.family));
            for(int v:{a.a.x,a.a.y,a.b.x,a.b.y,a.facing.x,a.facing.y})h=mix(h^static_cast<std::uint64_t>(v));
            h=mix(h^a.required);
        }
        for(auto p:result->boundary.protected_geometry)h=mix(h^p);
    }
    for(const auto& s:r.frame.slots) {
        h=mix(h^s.id^s.connector^s.required);
        for(int v:{s.a.x,s.a.y,s.b.x,s.b.y,s.facing.x,s.facing.y})h=mix(h^static_cast<std::uint64_t>(v));
    }
    for(int k:r.mosaic.categories)h=mix(h^static_cast<std::uint64_t>(k+1));
    if(!r.recovery_frontier.empty()||!r.mosaic_recovery_receipts.empty()) {
        // Recovery's semantic state includes the authorized alternative cursor
        // and pending-reply phase. Repeating pixels while advancing either is
        // not an oscillation or a fixed point. OFF fingerprints stay unchanged.
        h=mix(h^0x535741524d303036ULL^r.recovery_frontier_exhausted);
        for(const auto& cursor:r.recovery_frontier){h=mix(h^cursor.slot);h=mix(h^cursor.next);h=mix(h^cursor.observation);h=mix(h^cursor.exhausted);}
        for(const auto& receipt:r.mosaic_recovery_receipts){h=mix(h^receipt.slot);h=mix(h^receipt.connector);h=mix(h^receipt.candidate);
            h=mix(h^(r.number<receipt.round+2?receipt.round+2-r.number:0));}
    }
    return h;
}
std::vector<std::uint8_t> protected_union(const Input& in,const Result& f,const Result& m) {
    auto p=in.frame.protected_void;
    if(p.empty())p.assign(f.cells.size(),0);
    for(std::size_t i=0;i<p.size();++i) p[i]=static_cast<std::uint8_t>(p[i] ||
        mask_at(f.boundary.protected_geometry,i) || mask_at(m.boundary.protected_geometry,i));
    return p;
}
bool legal_pair(const Input& in,const Result& f,const Result& m,std::string& reason,
                const std::vector<std::uint8_t>* preserved=nullptr) {
    const auto n=static_cast<std::size_t>(in.frame.width)*static_cast<std::size_t>(in.frame.height);
    if(!usable(f)||!usable(m)||f.cells.size()!=n||m.cells.size()!=n ||
       f.roles.size()!=n||m.roles.size()!=n||f.provenance.size()!=n||m.provenance.size()!=n) {
        reason="incomplete native proposal";return false;
    }
    for(const auto* result:{&f,&m})for(const auto* mask:{&result->boundary.protected_geometry,&result->boundary.transition})
        if(!mask->empty()&&(mask->size()!=n||std::any_of(mask->begin(),mask->end(),[](auto v){return v>1;}))){reason="malformed proposal mask";return false;}
    if(f.gentek!=Kind::Frameweaver||m.gentek!=Kind::Mosaic||f.seed!=in.frame.seed||m.seed!=in.mosaic.seed||
       f.source_identity!=in.frame.source_identity||m.source_identity!=in.mosaic.source_identity||
       f.width!=in.frame.width||f.height!=in.frame.height||m.width!=in.mosaic.width||m.height!=in.mosaic.height||
       f.instances.size()>in.frame.limits.max_instances||m.instances.size()>in.mosaic.limits.max_instances||
       f.boundary.hard.size()>256||m.boundary.hard.size()>256){reason="proposal identity or capacity violation";return false;}
    std::set<std::uint32_t> fi,mi;
    std::vector<std::uint8_t> justified_frame(n,0),justified_mosaic(n,0);
    for(unsigned owner=0;owner<2;++owner) {
        const auto& result=owner==0?f:m;auto& ids=owner==0?fi:mi;auto& justified=owner==0?justified_frame:justified_mosaic;
        std::size_t footprint_cells=0;
        for(const auto& p:result.instances) {
            if(p.id==0||p.id>256||p.kind.empty()||p.kind.size()>128||p.reason.size()>1024||
               std::abs(static_cast<std::int64_t>(p.origin.x))>512||std::abs(static_cast<std::int64_t>(p.origin.y))>512||
               !ids.insert(p.id).second||p.cells.size()>n||footprint_cells>n*8ULL-p.cells.size()) {
                reason="invalid or unbounded named part footprint";return false;
            }
            footprint_cells+=p.cells.size();
            for(auto point:p.cells) {
                if(!inside(in.frame,point)){reason="named part outside finite canvas";return false;}
                const auto i=index(in.frame,point);if(result.provenance[i]==p.id)justified[i]=1;
            }
        }
    }
    for(std::size_t i=0;i<n;++i) {
        const bool a=f.cells[i]!=Material::Empty,b=m.cells[i]!=Material::Empty;
        if((!a&&(f.roles[i]!=Role::Empty||f.provenance[i]!=0))||(!b&&(m.roles[i]!=Role::Empty||m.provenance[i]!=0))) {
            reason="empty native cell retains a structural claim";return false;
        }
        if(!a&&!b)continue;
        if(a&&b){reason="competing shared-zone cell claims";return false;}
        if((!in.frame.context.empty()&&in.frame.context[i]!=Material::Empty) ||
           mask_at(in.frame.protected_void,i) || mask_at(f.boundary.protected_geometry,i) ||
           mask_at(m.boundary.protected_geometry,i) || (preserved&&mask_at(*preserved,i))) {
            reason="immutable material or protected passage conflict";return false;
        }
        const auto& q=a?in.frame:in.mosaic;
        if(!q.eligible.empty()&&!q.eligible[i] && (!in.options.shared_ownership||!mask_at(in.shared_zone,i))) {
            reason="claim outside own territory and shared zone";return false;
        }
        const auto material=a?f.cells[i]:m.cells[i];
        if(static_cast<unsigned>(material)>131U||static_cast<unsigned>(material)==10U) {
            reason="invalid native material";return false;
        }
        const auto role=a?f.roles[i]:m.roles[i];
        if(role==Role::Empty||static_cast<unsigned>(role)>static_cast<unsigned>(Role::Transition)||
           (material_definition(material).state!=MaterialState::Solid&&!(b&&material==Material::Stone))||!(a?justified_frame:justified_mosaic)[i]) {
            reason="native material lacks an authored construction material, valid role or exact owning footprint";return false;
        }
        if(!(a?fi:mi).contains(a?f.provenance[i]:m.provenance[i])) {
            reason="material without a named owning part";return false;
        }
    }
    reason.clear();return true;
}
Rect envelope(const Request& q,Point a,Point b,Point facing) {
    const auto far=plus(a,{facing.x*14,facing.y*14});
    const int mx=facing.x==0?3:0,my=facing.y==0?3:0;
    const int x=std::max(0,std::min({a.x,b.x,far.x})-mx);
    const int y=std::max(0,std::min({a.y,b.y,far.y})-my);
    const int xx=std::min(q.width-1,std::max({a.x,b.x,far.x})+mx);
    const int yy=std::min(q.height-1,std::max({a.y,b.y,far.y})+my);
    return {x,y,xx-x+1,yy-y+1};
}
std::vector<TransitionSlot> source_slots(const Input& in,const FramePlan& initial,
                                        std::vector<std::string>& rejected) {
    auto slots=initial.slots;
    if(!in.options.vocabulary)return slots;
    const auto& q=in.frame;const auto& r=initial.result;
    for(const auto& c:r.connectors) {
        if(!c.required||c.fulfilled||c.family!=Family::Frame||!inside(q,c.a)||
           !transition_at(q,c.a)||r.cells[index(q,c.a)]==Material::Empty)continue;
        if(std::any_of(slots.begin(),slots.end(),[&](const auto& s){return s.connector==c.id;}))continue;
        const auto outward=plus(c.a,c.facing);
        if(!cardinal(c.facing)||!inside(q,outward)||
           r.cells[index(q,outward)]!=Material::Empty||!structural(r.roles[index(q,c.a)]))continue;
        bool reaches=false;
        for(int step=1;step<=14;++step) {
            const Point p{c.a.x+step*c.facing.x,c.a.y+step*c.facing.y};
            if(!inside(q,p)||!transition_at(q,p)||mask_at(q.protected_void,index(q,p))||
               (!q.context.empty()&&q.context[index(q,p)]!=Material::Empty))break;
            if((!in.mosaic.eligible.empty()&&in.mosaic.eligible[index(q,p)])||
               (in.options.shared_ownership&&mask_at(in.shared_zone,index(q,p)))){reaches=true;break;}
        }
        if(!reaches)continue;
        TransitionSlot s;
        s.id=0x40000000U+c.id;s.instance=c.instance;s.connector=c.id;
        s.kind=c.a==c.b?SlotKind::PointSocket:SlotKind::BearingSegment;
        s.a=c.a;s.b=c.b;s.facing=c.facing;s.required=s.hard=true;s.strength=1;
        s.envelope=envelope(q,s.a,s.b,s.facing);
        s.reason="SWARM004 original unresolved source: real exposed mechanical face; obligation remains foreign-required";
        for(int y=s.envelope.y;y<s.envelope.y+s.envelope.h;++y)
            for(int x=s.envelope.x;x<s.envelope.x+s.envelope.w;++x)
                if(mask_at(q.protected_void,index(q,{x,y})))s.clearance.push_back({x,y});
        slots.push_back(s);
    }
    std::stable_sort(slots.begin(),slots.end(),[](const auto& a,const auto& b){
        return std::tuple{!a.required,a.id}<std::tuple{!b.required,b.id};
    });
    if(slots.size()>max_transition_slots) {
        rejected.push_back("eight total reservation capacity: additional source obligations retained without slots");
        slots.resize(max_transition_slots);
    }
    std::sort(slots.begin(),slots.end(),[](const auto& a,const auto& b){return a.id<b.id;});
    return slots;
}
bool expansion_fits(const Input& in,const Result& existing,const Result* peer,
                    const ExpandedAssembly& a,Point host,std::uint32_t host_instance,
                    const std::vector<std::uint8_t>& protected_cells,const std::set<std::uint32_t>* retired=nullptr) {
    if(a.outcome!=Outcome::Complete||a.claims.empty())return false;
    bool new_material=false,attached=false;
    for(const auto& claim:a.claims) {
        const auto p=claim.point;
        if(!inside(in.frame,p))return false;
        const auto i=index(in.frame,p);
        if(mask_at(protected_cells,i)||mask_at(in.frame.protected_void,i)||
           (!in.frame.context.empty()&&in.frame.context[i]!=Material::Empty)||
           (peer && (!peer->cells.empty()&&peer->cells[i]!=Material::Empty)))return false;
        if(!in.frame.eligible.empty()&&!in.frame.eligible[i]&&
           (!in.options.shared_ownership||!mask_at(in.shared_zone,i)))return false;
        if(existing.cells[i]!=Material::Empty&&!(retired&&retired->contains(existing.provenance[i]))) {
            if(existing.provenance[i]!=host_instance||dist(p,host)>2||
               !structural(existing.roles[i])||existing.cells[i]!=claim.material)return false;
            if(p==host)attached=true;
        } else new_material=true;
    }
    return attached&&new_material;
}
std::vector<std::uint32_t> install_expansion(Result& out,const ExpandedAssembly& assembly,std::vector<std::uint32_t>* reused=nullptr) {
    std::uint32_t next=1;
    for(const auto& p:out.instances)next=std::max(next,p.id+1);
    std::map<std::uint32_t,std::uint32_t> ids;
    std::vector<std::uint32_t> installed;
    for(const auto& p:assembly.instances) {
        const bool owns_new=std::any_of(assembly.claims.begin(),assembly.claims.end(),[&](const auto& c){
            return c.instance==p.instance&&out.cells[static_cast<std::size_t>(c.point.y)*static_cast<std::size_t>(out.width)+static_cast<std::size_t>(c.point.x)]==Material::Empty;});
        if(!owns_new){if(reused)reused->push_back(p.instance);continue;}
        ids[p.instance]=next;
        Instance instance;
        instance.id=next++;instance.kind="swarm004/"+p.name;
        instance.reason=p.rule;instance.origin=p.transform.translation;
        instance.orientation=static_cast<int>(p.transform.quarter_turns);instance.structural=true;
        for(const auto& c:assembly.claims)if(c.instance==p.instance)instance.cells.push_back(c.point);
        if(!instance.cells.empty()){installed.push_back(instance.id);out.instances.push_back(std::move(instance));}
    }
    for(const auto& c:assembly.claims) {
        const auto i=static_cast<std::size_t>(c.point.y)*static_cast<std::size_t>(out.width)+static_cast<std::size_t>(c.point.x);
        if(out.cells[i]!=Material::Empty)continue; // canonical existing host owns the weld
        out.cells[i]=c.material;out.roles[i]=c.role;out.provenance[i]=ids.at(c.instance);
    }
    return installed;
}
void finalize_frame(const Input& in,FrameRevision& frame) {
    auto q=in.frame;
    for(std::size_t i=0;i<q.eligible.size();++i)if(in.options.shared_ownership&&mask_at(in.shared_zone,i))q.eligible[i]=1;
    frame.result.implementation=composition_identity;
    finish_result(q,frame.result);
}
FrameRevision initial_frame(const Input& in,const FramePlan& original,Budget& budget) {
    FrameRevision out;out.result=original.result;
    if(!frame_charge(budget,original.result.cells.size()*2ULL+original.result.connectors.size()*32ULL)) {
        out.result.status=Status::Exhausted;out.result.termination="source slot/accounting work";return out;
    }
    out.slots=source_slots(in,original,out.rejections);
    if(!in.options.vocabulary)return out;
    const auto saved_connectors=out.result.connectors;
    for(const auto& c:saved_connectors) {
        if(c.fulfilled||c.family!=Family::Frame||!inside(in.frame,c.a)||
           out.result.instances.size()>=in.frame.limits.max_instances)continue;
        const auto nodes=budget.nodes,instances=budget.instances;
        auto g=frame_grammar(1,2);
        const auto a=expand(g,{termination_plate,false},{c.a,rotation(c.facing)},0,0,budget);
        if(!frame_charge(budget,a.claims.size()*(a.instances.size()+5ULL)+a.sockets.size()*4ULL)) {
            out.result.status=Status::Exhausted;out.result.termination="termination footprint accounting";return out;
        }
        if(expansion_fits(in,out.result,nullptr,a,c.a,c.instance,in.frame.protected_void)) {
            install_expansion(out.result,a);++out.local_terminations;
            // Do not mutate c.required/c.fulfilled or its foreign identity.
        } else {budget.nodes=nodes;budget.instances=instances;}
        if(a.outcome==Outcome::Exhausted||a.outcome==Outcome::Cancelled)break;
    }
    if(out.local_terminations) {
        if(!frame_charge(budget,out.result.cells.size()*12ULL)){out.result.status=Status::Exhausted;out.result.termination="termination raster accounting";return out;}
        finalize_frame(in,out);
    }
    return out;
}
struct Receiver { Point root{},contact{},normal{};std::uint32_t part{},port{}; };
struct Retirement {std::set<std::uint32_t> ids;bool admitted=false,exhausted=false;};
Retirement replaceable_endings(const Result& base,Point root,std::uint32_t needed,std::uint32_t limit,Budget& budget) {
    Retirement plan;
    if(!frame_charge(budget,base.instances.size()*8ULL)){plan.exhausted=true;return plan;}
    std::vector<std::pair<int,std::uint32_t>> endings;
    for(const auto& p:base.instances)if(p.kind=="swarm004/local_flush_ending")endings.push_back({dist(p.origin,root),p.id});
    std::sort(endings.begin(),endings.end());
    for(const auto& [distance,id]:endings) {
        if(distance==0||base.instances.size()-plan.ids.size()+needed>limit)plan.ids.insert(id);
    }
    plan.admitted=base.instances.size()-plan.ids.size()+needed<=limit;return plan;
}
bool retire_endings(Result& result,const Retirement& plan,Budget& budget) {
    for(const auto& p:result.instances)if(plan.ids.contains(p.id)) {
        if(!frame_charge(budget,p.cells.size()))return false;
        for(auto point:p.cells) {
            const auto i=static_cast<std::size_t>(point.y)*static_cast<std::size_t>(result.width)+static_cast<std::size_t>(point.x);
            if(result.provenance[i]==p.id){result.cells[i]=Material::Empty;result.roles[i]=Role::Empty;result.provenance[i]=0;}
        }
    }
    std::erase_if(result.instances,[&](const auto& p){return plan.ids.contains(p.id);});return true;
}
std::vector<Receiver> receivers(const Input& in,const TransitionSlot& slot,const MosaicPlan& mosaic,Budget& budget) {
    std::vector<Receiver> found;
    const auto& m=mosaic.result;
    for(const auto& port:m.boundary.hard) {
        if(port.family!=Family::Frame||port.facing!=neg(slot.facing))continue;
        if(port.tag.starts_with("swarm006/")&&port.tag!=("swarm006/source-slot="+std::to_string(slot.id)+";connector="+std::to_string(slot.connector)))continue;
        for(auto p:line(port.a,port.b))for(auto root:line(slot.a,slot.b)) {
            if(!frame_charge(budget,1))return {};
            const auto d=minus(p,root);
            const int forward=d.x*slot.facing.x+d.y*slot.facing.y;
            const int sideways=d.x*slot.facing.y-d.y*slot.facing.x;
            if(forward<1||forward>15||sideways!=0||!in_box(p,slot.envelope)||!inside(in.frame,p))continue;
            const auto i=index(in.frame,p);
            const auto behind=plus(p,slot.facing),air=minus(p,slot.facing);
            if(!native_bearing(m.cells[i],m.roles[i])||m.provenance[i]!=port.instance||
               !inside(in.frame,behind)||!native_bearing(m.cells[index(in.frame,behind)],m.roles[index(in.frame,behind)])||
               (inside(in.frame,air)&&m.cells[index(in.frame,air)]!=Material::Empty))continue;
            found.push_back({root,p,port.facing,port.instance,port.id});
        }
    }
    std::sort(found.begin(),found.end(),[](const auto& a,const auto& b){
        return std::tuple{dist(a.root,a.contact),a.root,a.contact,a.part,a.port}<
               std::tuple{dist(b.root,b.contact),b.root,b.contact,b.part,b.port};
    });
    found.erase(std::unique(found.begin(),found.end(),[](const auto& a,const auto& b){return a.root==b.root&&a.contact==b.contact;}),found.end());
    if(!frame_charge(budget,found.size()*12ULL))return {};
    return found;
}
FrameRevision revise_frame(const Input& in,const FrameRevision& baseline,const MosaicPlan& peer,
                           const std::vector<std::uint8_t>& protected_cells,unsigned round,Budget& budget) {
    FrameRevision out=baseline;
    budget.nodes=budget.instances=static_cast<std::uint32_t>(baseline.result.instances.size());
    if(!begin_proposal(budget)) {out.result.status=Status::Exhausted;return out;}
    for(auto& slot:out.slots) {
        if(!slot.required&&!in.options.optional_negotiation)continue;
        if(in.options.orientation_preference>=0&&!slot.required&&
           (in.options.orientation_preference==0?slot.facing.x==0:slot.facing.y==0))continue;
        bool accepted=false;
        for(const auto& target:receivers(in,slot,peer,budget)) {
            const int span=dist(target.root,target.contact)-1;
            if(span>14)continue;
            const auto source=std::find_if(baseline.result.connectors.begin(),baseline.result.connectors.end(),[&](const auto& c){return c.id==slot.connector;});
            if(source==baseline.result.connectors.end())continue;
            // A direct contact only calls for the receiving bearing after
            // MOSAIC has authored an exact response to this source reservation.
            const bool receiving_response=std::any_of(peer.responses.begin(),peer.responses.end(),[&](const auto& response){
                return response.slot_id==slot.id&&response.admitted&&response.satisfied&&response.contact==target.contact;});
            if(span==0&&(!receiving_response||!in.options.hierarchy)){accepted=true;break;}
            struct Choice {Symbol symbol;int handedness;std::uint32_t nodes;unsigned size;};
            std::vector<Choice> choices;
            if(span==0) {
                const auto size=2U+static_cast<unsigned>(4*in.frame.profile.variation);
                choices={{{backward_bearing,true},-1,4,size},{{backward_bearing,true},1,4,size}};
                if(size>2){choices.push_back({{backward_bearing,true},-1,4,2});choices.push_back({{backward_bearing,true},1,4,2});}
            }
            else {
                if(in.options.hierarchy)choices={{{nested_truss,true},0,5,0},{{bracket,true},0,3,0}};
                choices.push_back({{member,false},0,1,0});
            }
            for(const auto choice:choices) {
                const auto symbol=choice.symbol;
                const auto nodes=budget.nodes,instances=budget.instances;
                const auto prior_nodes=std::accumulate(out.constructions.begin(),out.constructions.end(),std::uint32_t{},[](auto total,const auto& c){
                    return total+static_cast<std::uint32_t>(c.assembly.nodes.size()-c.parts.size());});
                const auto retirement=replaceable_endings(out.result,target.root,choice.nodes+prior_nodes,in.frame.limits.max_instances,budget);
                if(retirement.exhausted){out.result.status=Status::Exhausted;out.result.termination="own ending selection allowance";return out;}
                if(!retirement.admitted)continue;
                budget.instances=static_cast<std::uint32_t>(out.result.instances.size()-retirement.ids.size());budget.nodes=budget.instances+prior_nodes;
                const auto g=span==0?bearing_grammar(choice.size,choice.size,source->family,choice.handedness):
                    frame_grammar(static_cast<unsigned>(span),static_cast<unsigned>(std::clamp(span/2,2,6)),source->family);
                auto a=expand(g,symbol,{target.root,rotation(slot.facing)},round,round,budget);
                if(a.outcome==Outcome::Cancelled){out.result.status=Status::Exhausted;out.result.termination="cancelled";return out;}
                if(a.outcome==Outcome::Exhausted){out.rejections.push_back(a.reason);budget.nodes=nodes;budget.instances=instances;
                    if(a.reason.find("work")!=std::string::npos||a.reason.find("storage")!=std::string::npos||a.reason.find("candidate")!=std::string::npos){out.result.status=Status::Exhausted;out.result.termination=a.reason;return out;}continue;}
                if(!frame_charge(budget,a.claims.size()*(a.instances.size()+5ULL)+a.sockets.size()*4ULL)) {
                    out.result.status=Status::Exhausted;out.result.termination="assembly placement account exhausted";return out;
                }
                const auto endpoint=minus(target.contact,slot.facing);
                const bool exported=std::any_of(a.sockets.begin(),a.sockets.end(),[&](const auto& s){return s.a==endpoint&&s.facing==slot.facing;});
                if(!exported||out.result.instances.size()-retirement.ids.size()+a.instances.size()>in.frame.limits.max_instances||
                   !expansion_fits(in,out.result,&peer.result,a,target.root,slot.instance,protected_cells,&retirement.ids)) {
                    budget.nodes=nodes;budget.instances=instances;continue;
                }
                if(!retire_endings(out.result,retirement,budget)){out.result.status=Status::Exhausted;out.result.termination="own ending retirement allowance";return out;}
                std::vector<std::uint32_t> reused;
                const auto ids=install_expansion(out.result,a,&reused);
                Construction made;made.slot=slot.id;made.connector=slot.connector;made.base_instance=slot.instance;
                made.root=target.root;made.face=endpoint;made.facing=slot.facing;made.parts=ids;
                made.rule=span==0?"FRAME/confirmed-masonry-backward-bearing":symbol.assembly?"FRAME/receiving-hierarchical-truss":"FRAME/receiving-authored-member";
                made.assembly=a;
                made.reused_host_components=std::move(reused);
                made.authored_symbol=symbol;made.span=span==0?choice.size:static_cast<unsigned>(span);
                made.rise=span==0?choice.size:static_cast<unsigned>(std::clamp(span/2,2,6));
                made.handedness=choice.handedness;made.input_family=source->family;
                out.constructions.push_back(made);
                slot.a=slot.b=endpoint;slot.kind=SlotKind::PointSocket;
                slot.instance=out.result.provenance[index(in.frame,endpoint)];
                slot.envelope=envelope(in.frame,slot.a,slot.b,slot.facing);slot.clearance.clear();
                for(int y=slot.envelope.y;y<slot.envelope.y+slot.envelope.h;++y)
                    for(int x=slot.envelope.x;x<slot.envelope.x+slot.envelope.w;++x)
                        if(mask_at(in.frame.protected_void,index(in.frame,{x,y})))slot.clearance.push_back({x,y});
                slot.reason="FRAME revised its own provisional assembly against immutable native MOSAIC receptor; original obligation retained";
                accepted=true;break;
            }
            if(accepted)break;
        }
        if(!accepted)out.rejections.push_back("slot "+std::to_string(slot.id)+": no legal authored assembly and native receiver within current capacity");
    }
    if(!out.constructions.empty()) {
        out.local_terminations=static_cast<std::uint32_t>(std::count_if(out.result.instances.begin(),out.result.instances.end(),[](const auto& p){return p.kind=="swarm004/local_flush_ending";}));
        if(!frame_charge(budget,out.result.cells.size()*12ULL)){out.result.status=Status::Exhausted;out.result.termination="FRAME raster work exhausted";return out;}
        finalize_frame(in,out);
    }
    return out;
}
bool material_path(Composition& c,const Result& f,Point start,Point end,std::vector<Point>& path) {
    const auto& q=c.input.frame;
    if(!inside(q,start)||!inside(q,end)||f.cells[index(q,start)]==Material::Empty||f.cells[index(q,end)]==Material::Empty)return false;
    const auto n=f.cells.size();std::vector<int> parent(n,-1),depth(n,-1);
    std::deque<Point> queue;queue.push_back(start);depth[index(q,start)]=0;
    while(!queue.empty()) {
        const auto p=queue.front();queue.pop_front();
        if(!charge_shared(c))return false;
        if(p==end) {
            auto at=index(q,end);
            while(true){path.push_back({static_cast<int>(at%q.width),static_cast<int>(at/q.width)});if(at==index(q,start))break;at=static_cast<std::size_t>(parent[at]);}
            std::reverse(path.begin(),path.end());return true;
        }
        if(depth[index(q,p)]>=30)continue;
        for(auto d:dirs) {
            const auto v=plus(p,d);if(!inside(q,v))continue;const auto i=index(q,v);
            if(depth[i]>=0||!native_bearing(f.cells[i],f.roles[i]))continue;
            depth[i]=depth[index(q,p)]+1;parent[i]=static_cast<int>(index(q,p));queue.push_back(v);
        }
    }
    return false;
}

bool certify_recovery_history(Composition& c) {
    const auto refuse=[&](const std::string& why){c.status=CompositionStatus::Invalid;c.reason="SWARM006 native certificate: "+why;return false;};
    const auto& in=c.input;const auto& source=c.original_frame.result;
    if(!in.options.negotiated_recovery) {
        for(const auto& r:c.rounds) {
            if(!r.recovery_attempts.empty()||!r.mosaic_recovery_receipts.empty()||!r.recovery_frontier.empty()||r.recovery_work)
                return refuse("recovery receipts without opt-in authority");
            for(const auto& port:r.mosaic.result.boundary.hard)if(port.tag.starts_with("swarm006/"))return refuse("unreceipted recovery port");
        }
        return true;
    }
    // Search observations are authenticated by the opaque native run authority,
    // not by trusting public JSON or spending another categorical solve. This
    // independent certificate proves each accepted finite masonry part against
    // its actual original host, exact typed source, native cells and ownership.
    const auto cost=8192ULL+c.rounds.size()*4096ULL;
    if(!charge_shared(c,cost)){c.status=CompositionStatus::Exhausted;c.reason="budget_exhaustion: native receiver certificates";return false;}
    c.metrics["recovery_validation_work"]+=cost;
    std::uint64_t attempts=0,work=0,frame_revised=0,mosaic_revised=0;
    for(std::size_t ordinal=0;ordinal<c.rounds.size();++ordinal) {
        const auto& round=c.rounds[ordinal];const auto& m=round.mosaic.result;
        if(round.mosaic.categories!=c.rounds.front().mosaic.categories)return refuse("recovery changed the native categorical assignment");
        if(ordinal==0&&(!round.recovery_attempts.empty()||!round.mosaic_recovery_receipts.empty()||!round.recovery_frontier.empty()||round.recovery_work))
            return refuse("initial source already contains negotiated geometry");
        frame_revised+=round.frame_footprint_changed>0;mosaic_revised+=round.mosaic_footprint_changed>0;
        attempts+=round.recovery_attempts.size();work+=round.recovery_work;
        const auto tagged=std::count_if(m.boundary.hard.begin(),m.boundary.hard.end(),[](const auto& p){return p.tag.starts_with("swarm006/");});
        if(static_cast<std::size_t>(tagged)!=round.mosaic_recovery_receipts.size())return refuse("unreceipted native receiving port");
        std::set<std::uint32_t> ports,slots;std::set<Point> contacts;
        for(const auto& r:round.mosaic_recovery_receipts) {
            if(!r.round||r.round>ordinal||!ports.insert(r.port_id).second||!slots.insert(r.slot).second||!contacts.insert(r.contact).second)
                return refuse("duplicate or future receiving reservation");
            const auto& prior=c.rounds[r.round-1].mosaic.result;
            const auto slot=std::find_if(c.rounds.front().frame.slots.begin(),c.rounds.front().frame.slots.end(),[&](const auto& x){return x.id==r.slot&&x.connector==r.connector;});
            const auto connector=std::find_if(source.connectors.begin(),source.connectors.end(),[&](const auto& x){return x.id==r.connector&&x.instance==r.source_instance;});
            if(slot==c.rounds.front().frame.slots.end()||connector==source.connectors.end()||!cardinal(slot->facing)||
               connector->fulfilled||connector->family!=r.source_family||connector->facing!=slot->facing||
               r.source_digest!=source.material_digest||r.prior_digest!=prior.material_digest)
                return refuse("source connector, authored family or source-time identity changed");
            const auto roots=line(connector->a,connector->b);const int distance=dist(r.root,r.contact);
            if(std::find(roots.begin(),roots.end(),r.root)==roots.end()||distance<1||distance>14||
               r.contact!=Point{r.root.x+distance*slot->facing.x,r.root.y+distance*slot->facing.y}||
               r.backing!=plus(r.contact,slot->facing)||!in_box(r.contact,slot->envelope)||
               !inside(in.frame,r.root)||!inside(in.frame,r.contact)||!inside(in.frame,r.backing)||!inside(in.frame,r.host)||
               source.provenance[index(in.frame,r.root)]!=r.source_instance||
               !native_bearing(source.cells[index(in.frame,r.root)],source.roles[index(in.frame,r.root)]))
                return refuse("receiver is outside the finite original source interface");
            const auto family=distance==1?connector->family:Family::Frame;
            const auto port=std::find_if(m.boundary.hard.begin(),m.boundary.hard.end(),[&](const auto& x){return x.id==r.port_id;});
            if(port==m.boundary.hard.end()||port->instance!=r.receiving_instance||port->a!=r.contact||port->b!=r.contact||
               port->facing!=neg(slot->facing)||port->family!=family||r.receiving_family!=family||port->required||port->strength!=slot->strength||
               port->tag!=("swarm006/source-slot="+std::to_string(r.slot)+";connector="+std::to_string(r.connector)))
                return refuse("typed receptor is not bound to the exact source obligation");
            const auto owner=std::find_if(m.instances.begin(),m.instances.end(),[&](const auto& x){return x.id==r.receiving_instance;});
            const auto host=std::find_if(prior.instances.begin(),prior.instances.end(),[&](const auto& x){return x.id==r.host_instance;});
            if(owner==m.instances.end()||host==prior.instances.end()||host->kind.starts_with("swarm006/"))return refuse("missing original native host");
            const auto tile=static_cast<std::size_t>(r.host.y/16)*static_cast<std::size_t>((in.mosaic.width+15)/16)+static_cast<std::size_t>(r.host.x/16);
            if(tile>=round.mosaic.categories.size()||round.mosaic.categories[tile]<0||host->kind!=mosaic_category_name(static_cast<unsigned>(round.mosaic.categories[tile])))
                return refuse("native host does not match its immutable masonry category");
            std::vector<Point> expected;
            if(r.variant) {
                const Point tangent{-slot->facing.y,slot->facing.x};
                const auto axis=r.variant==1?slot->facing:r.variant==2?tangent:neg(tangent);
                const auto cross=r.variant==1?tangent:slot->facing;
                if(r.variant>3||(r.length!=2&&r.length!=4&&r.length!=6)||r.axis!=axis||r.cross!=cross||
                   r.host!=Point{r.contact.x+static_cast<int>(r.length)*axis.x,r.contact.y+static_cast<int>(r.length)*axis.y}||
                   owner->kind!="swarm006/supported_masonry_corbel"||owner->origin!=r.contact||
                   owner->orientation!=static_cast<int>(rotation(axis))||!owner->structural||owner->damaged||
                   owner->reason!="MOSAIC/source-bound-solid-corbel-v1;host="+std::to_string(r.host_instance)+";length="+std::to_string(r.length))
                    return refuse("receiver differs from its finite authored corbel");
                for(unsigned a=0;a<r.length;++a)for(unsigned b=0;b<2;++b)
                    expected.push_back({r.contact.x+static_cast<int>(a)*axis.x+static_cast<int>(b)*cross.x,
                                        r.contact.y+static_cast<int>(a)*axis.y+static_cast<int>(b)*cross.y});
                if(owner->cells!=expected)return refuse("invented native corbel footprint");
            }else if(r.length||r.axis!=Point{}||r.cross!=Point{}||r.host!=r.contact||r.receiving_instance!=r.host_instance)
                return refuse("existing bearing receipt invented geometry");
            const auto host2=r.variant?plus(r.host,r.cross):r.backing;
            for(const auto p:{r.host,host2}) {
                if(!inside(in.mosaic,p)||std::find(host->cells.begin(),host->cells.end(),p)==host->cells.end())return refuse("authored host footprint missing backing");
                const auto i=index(in.mosaic,p);
                if(prior.provenance[i]!=r.host_instance||!structural(prior.roles[i])||
                   (prior.cells[i]!=Material::Stone&&!native_bearing(prior.cells[i],prior.roles[i])))return refuse("host was not real native structure");
                if(m.provenance[i]!=r.host_instance||!native_bearing(m.cells[i],m.roles[i]))
                    return refuse("native corbel host lost its current solid backing");
            }
            for(const auto p:{r.contact,r.backing}) {
                const auto i=index(in.mosaic,p);
                if(std::find(owner->cells.begin(),owner->cells.end(),p)==owner->cells.end()||m.provenance[i]!=r.receiving_instance||!native_bearing(m.cells[i],m.roles[i]))
                    return refuse("receiver lacks exact native solid contact and backing");
            }
            std::set<Point> edits;
            for(const auto& e:r.edits) {
                if(!inside(in.mosaic,e.point)||!edits.insert(e.point).second)return refuse("duplicate receiver edit");
                const auto i=index(in.mosaic,e.point);
                if(prior.cells[i]!=e.before||prior.roles[i]!=e.before_role||prior.provenance[i]!=e.before_owner||
                   m.cells[i]!=e.after||m.roles[i]!=e.after_role||m.provenance[i]!=e.after_owner||e.after!=Material::LimestoneBlock)
                    return refuse("native receiver edit/history/owner mismatch");
                const bool new_cell=std::find(expected.begin(),expected.end(),e.point)!=expected.end();
                if(new_cell) {if(e.before!=Material::Empty||e.before_owner||e.after_owner!=r.receiving_instance||e.after_role!=Role::Structure)
                    return refuse("corbel collision or invented material path");}
                else if((e.point!=r.host&&e.point!=host2)||e.before!=Material::Stone||e.before_owner!=r.host_instance||
                        e.after_owner!=r.host_instance||e.before_role!=e.after_role)return refuse("unauthored native material variant");
            }
            for(const auto p:expected)if(!edits.contains(p))return refuse("missing corbel cell receipt");
        }
    }
    if(c.metrics["recovery_attempts"]!=attempts||c.metrics["recovery_work"]!=work||
       c.metrics["frame_footprint_changed_rounds"]!=frame_revised||c.metrics["mosaic_footprint_changed_rounds"]!=mosaic_revised||
       c.metrics["both_genteks_revised"]!=static_cast<unsigned>(frame_revised>0&&mosaic_revised>0))return refuse("false scientific summary");
    return true;
}
void fill_ledger(Composition& c) {
    const auto& last=c.rounds.back();const auto n=last.frame.result.cells.size();
    const auto& final_frame=c.damage_derivative?c.damage_derivative->frame:last.frame;
    const auto& final_mosaic=c.damage_derivative?c.damage_derivative->mosaic:last.mosaic;
    c.cells=c.input.frame.context;if(c.cells.empty())c.cells.assign(n,Material::Empty);
    c.ledger.resize(n);c.rules={"empty","immutable-environment"};
    std::map<std::pair<unsigned,std::uint32_t>,std::uint32_t> rule_ids;
    using RuleLookup=std::array<std::array<std::uint64_t,257>,2>;
    std::vector<RuleLookup> history_rules(c.rounds.size());
    for(std::size_t ri=0;ri<c.rounds.size();++ri)for(unsigned owner=0;owner<2;++owner) {
        const auto& r=owner==0?c.rounds[ri].frame.result:c.rounds[ri].mosaic.result;
        for(const auto& p:r.instances) {
            std::uint64_t h=mix(p.id);
            for(unsigned char ch:p.kind)h=mix(h^ch);
            for(unsigned char ch:p.reason)h=mix(h^ch);
            history_rules[ri][owner][p.id]=h;
        }
    }
    for(const auto owner:{1U,2U}) {
        const auto& r=owner==1?final_frame.result:final_mosaic.result;
        for(const auto& p:r.instances) {
            const auto rule=(owner==1?"FRAME/":"MOSAIC/")+p.kind+"/"+p.reason;
            auto it=std::find(c.rules.begin(),c.rules.end(),rule);
            if(it==c.rules.end()){c.rules.push_back(rule);it=c.rules.end()-1;}
            rule_ids[{owner,p.id}]=static_cast<std::uint32_t>(it-c.rules.begin());
        }
    }
    for(std::size_t i=0;i<n;++i) {
        auto& ledger=c.ledger[i];
        if(c.cells[i]!=Material::Empty){ledger.owner=3;ledger.rule=1;continue;}
        const unsigned owner=final_frame.result.cells[i]!=Material::Empty?1:final_mosaic.result.cells[i]!=Material::Empty?2:0;
        if(!owner)continue;
        const auto& r=owner==1?final_frame.result:final_mosaic.result;
        c.cells[i]=r.cells[i];ledger.owner=static_cast<std::uint8_t>(owner);ledger.instance=r.provenance[i];
        ledger.rule=rule_ids.at({owner,ledger.instance});bool first=true;
        std::tuple<unsigned,Material,std::uint32_t,std::uint64_t> previous{0,Material::Empty,0,0};
        for(std::size_t ri=0;ri<c.rounds.size();++ri) {
            const auto& round=c.rounds[ri];
            const unsigned round_owner=round.frame.result.cells[i]!=Material::Empty?1:round.mosaic.result.cells[i]!=Material::Empty?2:0;
            const auto& a=round_owner==1?round.frame.result:round.mosaic.result;
            const auto value=a.cells[i];
            const auto rule=round_owner?history_rules[ri][round_owner-1][a.provenance[i]]:0;
            const auto state=std::tuple{round_owner,value,a.provenance[i],rule};
            if(state!=previous){ledger.revision_mask|=static_cast<std::uint8_t>(1U<<round.number);ledger.last_round=static_cast<std::uint8_t>(round.number);}
            if(value!=Material::Empty&&first){ledger.first_round=static_cast<std::uint8_t>(round.number);first=false;}
            previous=state;
        }
    }
}
} // namespace

const char* name(CompositionStatus s) noexcept {
    switch(s){case CompositionStatus::Complete:return "complete";case CompositionStatus::Blocked:return "blocked";
    case CompositionStatus::Unsat:return "unsat";case CompositionStatus::Exhausted:return "exhausted";
    case CompositionStatus::Invalid:return "invalid";case CompositionStatus::Cancelled:return "cancelled";
    case CompositionStatus::Oscillation:return "oscillation";}return "invalid";
}
Profile expression_profile(const std::string& id) {
    Profile p;
    if(id=="industrial") {p=profile("dense_cohesive");p.clutter=.35;p.cohesion=.15;p.irregularity=.15;p.branching=.75;}
    else if(id=="viaduct_like") {p=profile("sparse_regular");p.branching=.55;p.variation=.65;p.cohesion=.35;p.clutter=.15;}
    else if(id=="irregular_megastructure") {p=profile("branching_irregular");p.irregularity=.95;p.branching=1;p.cohesion=.2;}
    else return profile(id);
    p.name=id;p.destruction=0;return p;
}
Input input_for(const Fixture& f,const Profile& p,std::uint64_t seed,const std::string& source,Options options) {
    Input in;in.frame=request_for(f,Kind::Frameweaver,0,p,seed,source);in.mosaic=request_for(f,Kind::Mosaic,1,p,seed,source);
    in.shared_zone=f.transition;in.options=options;
    for(std::size_t i=0;i<in.shared_zone.size();++i)if(!in.frame.eligible[i]&&!in.mosaic.eligible[i])in.shared_zone[i]=0;
    if(!options.shared_ownership||options.shared_extent==0)std::fill(in.shared_zone.begin(),in.shared_zone.end(),0);
    else {
        const auto distance=interface_distance(in);
        for(std::size_t i=0;i<in.shared_zone.size();++i)in.shared_zone[i]=static_cast<std::uint8_t>(in.shared_zone[i]&&distance[i]<=static_cast<int>(options.shared_extent));
    }
    return in;
}

Composition assemble(const Input& input,bool reverse) {
    Composition out;
    // Even malformed inputs get a bounded truthful identity header. Full masks
    // are copied only after shape/identity validation, never from an unbounded
    // hostile vector. This is not a material output or a proposal allocation.
    const auto header=[](const Request& from,Request& to){
        to.gentek=from.gentek;to.version=from.version;to.seed=from.seed;to.width=from.width;to.height=from.height;to.origin=from.origin;to.limits=from.limits;
        to.source_identity=from.source_identity.substr(0,128);to.fixture=from.fixture.substr(0,96);to.definition_fingerprint=from.definition_fingerprint.substr(0,128);
        to.profile.name=from.profile.name.substr(0,96);to.profile.variation=from.profile.variation;to.profile.irregularity=from.profile.irregularity;
        to.profile.clutter=from.profile.clutter;to.profile.destruction=from.profile.destruction;to.profile.branching=from.profile.branching;
        to.profile.environment_affinity=from.profile.environment_affinity;to.profile.cohesion=from.profile.cohesion;
    };
    header(input.frame,out.input.frame);header(input.mosaic,out.input.mosaic);out.input.options=input.options;
    out.metrics["input_header_only"]=1;
    auto fail=[&](CompositionStatus s,const std::string& why){
        out.metrics["frame_work"]=std::max(out.metrics["frame_work"],out.original_frame.result.work);
        out.metrics["total_charged_work"]=total_work(out);
        out.status=s;out.reason=why;out.can_apply=false;out.cells.clear();out.ledger.clear();
        if(input.options.negotiated_recovery) {
            if(s==CompositionStatus::Exhausted)out.stop_reason="budget_exhaustion";
            else if(s==CompositionStatus::Cancelled)out.stop_reason="cancellation";
            else if(s==CompositionStatus::Unsat)out.stop_reason="proven_infeasibility";
            else if(s==CompositionStatus::Invalid)out.stop_reason="invalid_native_proposal";
        }
        return out;
    };
    std::string why;
    if(!paired_input_valid(input,why))return fail(why.starts_with("capacity:")?CompositionStatus::Exhausted:CompositionStatus::Invalid,why);
    out.input=input;out.metrics["input_header_only"]=0;
    const auto& f=input.frame;const auto& m=input.mosaic;
    const auto n=static_cast<std::size_t>(f.width)*static_cast<std::size_t>(f.height);
    out.metrics["shared_work"]=n*8ULL;
    const auto derivative_bytes=(f.profile.destruction>0||m.profile.destruction>0)?64ULL:0ULL;
    const auto bytes=n*(256ULL+input.options.rounds*64ULL+derivative_bytes)+(64ULL+192ULL)*16384ULL+512ULL*1024ULL+
        (input.options.negotiated_recovery?768ULL*1024ULL:0ULL);
    out.metrics["conservative_memory_bound_bytes"]=bytes;
    if(bytes>std::min(f.limits.max_bytes,m.limits.max_bytes))return fail(CompositionStatus::Exhausted,"aggregate proposal/snapshot memory admission");
    if(cancelled(input))return fail(CompositionStatus::Cancelled,"cancelled before generation");
    // Intact proposals first. Damage is an independent final derivative.
    auto intact=input;intact.frame.profile.destruction=intact.mosaic.profile.destruction=0;
    out.original_frame=input.options.negotiated_recovery?
        plan_frameweaver(intact.frame,intact.mosaic,input.options.compact_native_termination,
            {true,input.options.shared_ownership?&input.shared_zone:nullptr}):
        plan_frameweaver(intact.frame,intact.mosaic,input.options.compact_native_termination);
    if(!usable(out.original_frame.result))return fail(out.original_frame.result.status==Status::Exhausted?CompositionStatus::Exhausted:CompositionStatus::Invalid,out.original_frame.result.termination);
    Budget budget;budget.cancel=input.cancel;budget.limits.max_work=f.limits.max_work;
    budget.limits.max_instances=f.limits.max_instances;budget.limits.max_candidates=f.limits.max_candidates;
    budget.work=out.original_frame.result.work;budget.candidates=static_cast<std::uint32_t>(out.original_frame.result.candidates);
    budget.nodes=budget.instances=static_cast<std::uint32_t>(out.original_frame.result.instances.size());
    if(!begin_proposal(budget))return fail(CompositionStatus::Exhausted,"initial FRAME proposal allowance");
    const auto base=initial_frame(intact,out.original_frame,budget);
    if(!usable(base.result)){out.metrics["frame_work"]=budget.work;return fail(CompositionStatus::Exhausted,base.result.termination);}
    MosaicBudget mb;mb.generator_remaining=m.limits.max_work;mb.solver_remaining=m.limits.max_solver_work;
    mb.max_bytes=m.limits.max_bytes;mb.cancelled=input.cancel;
    const auto shared=input.options.shared_ownership?input.shared_zone:std::vector<std::uint8_t>(n,0);
    auto initial=propose_mosaic_revision(intact.mosaic,base.result,{},shared,mb,0,nullptr,nullptr,input.options.optional_negotiation,input.options.native_mosaic_bearing,input.options.supported_native_receptors);
    auto sync_work=[&](){out.metrics["frame_work"]=budget.work;out.metrics["mosaic_work"]=m.limits.max_work-mb.generator_remaining;
        out.metrics["solver_work"]=m.limits.max_solver_work-mb.solver_remaining;out.metrics["frame_candidates"]=budget.candidates;
        out.metrics["total_charged_work"]=out.metrics["frame_work"]+out.metrics["mosaic_work"]+out.metrics["solver_work"]+out.metrics["shared_work"];};
    Round first;first.frame=base;first.mosaic=initial.plan;first.reason="independent own rules; same-mask no-offer initial proposal";
    first.mosaic_request=initial.request;
    first.proposed_frame=base.result;first.proposed_mosaic=initial.plan.result;first.mosaic_trace=initial.trace;
    first.mosaic_proposal_reason=initial.reason;first.mosaic_proposal_work=initial.generator_work+initial.wrapper_work;
    first.mosaic_proposal_solver_debit=initial.solver_debit;
    first.mosaic_bearing_replacements=initial.bearing_replacements;first.mosaic_bearing_rejections=initial.bearing_rejections;first.mosaic_bearing_work=initial.bearing_work;
    first.mosaic_supported_receptors=initial.supported_receptors;first.mosaic_supported_receptor_work=initial.supported_receptor_work;
    first.frame_work=budget.work;first.mosaic_work=m.limits.max_work-mb.generator_remaining;first.solver_work=m.limits.max_solver_work-mb.solver_remaining;
    if(initial.status!=MosaicRevisionStatus::Complete&&initial.status!=MosaicRevisionStatus::Blocked) {
        first.frame_accepted=first.mosaic_accepted=false;out.rounds.push_back(first);sync_work();
        return fail(initial.status==MosaicRevisionStatus::Cancelled?CompositionStatus::Cancelled:
            initial.status==MosaicRevisionStatus::Unsat?CompositionStatus::Unsat:
            initial.status==MosaicRevisionStatus::Exhausted?CompositionStatus::Exhausted:CompositionStatus::Invalid,initial.reason);
    }
    if(!legal_pair(input,first.frame.result,first.mosaic.result,why)) {
        first.frame_accepted=first.mosaic_accepted=false;out.rounds.push_back(first);sync_work();return fail(CompositionStatus::Invalid,why);
    }
    first.geometry_digest=mix(first.frame.result.material_digest)^mix(first.mosaic.result.material_digest);
    first.semantic_digest=semantic(first);out.rounds.push_back(first);
    // Preserve every initial protected passage, including authored generator
    // apertures. Architectural revision never trades a promised void for cells.
    const auto protected_cells=protected_union(input,first.frame.result,first.mosaic.result);
    unsigned mosaic_cache_observation=0,mosaic_cache_result=0,frame_cache_observation=0,frame_cache_result=0;
    std::vector<TransitionSlot> mosaic_cache_slots;bool has_frame_cache=false;
    out.stop_reason=input.options.rounds==0?"no_negotiation_control":"round_cap";
    for(unsigned r=1;r<=input.options.rounds;++r) {
        if(cancelled(input))return fail(CompositionStatus::Cancelled,"cancelled between immutable proposal rounds");
        const auto& old=out.rounds.back();FrameRevision next_frame=old.frame;MosaicRevision next_mosaic;
        next_mosaic.plan=old.mosaic;next_mosaic.status=MosaicRevisionStatus::Complete;
        if(!charge_shared(out,n*8ULL+8192ULL)){sync_work();return fail(CompositionStatus::Exhausted,"immutable input comparison allowance");}
        bool reused_frame=false,reused_mosaic=false;
        auto make_frame=[&](){if(input.options.frame_adaptation){
            if(has_frame_cache&&same_mosaic_observation(old.mosaic,out.rounds[frame_cache_observation].mosaic)) {
                next_frame=out.rounds[frame_cache_result].frame;reused_frame=true;
            }else {
                auto current_protected=protected_union(input,old.frame.result,old.mosaic.result);
                for(std::size_t i=0;i<n;++i)current_protected[i]=static_cast<std::uint8_t>(current_protected[i]||protected_cells[i]);
                next_frame=revise_frame(intact,base,old.mosaic,current_protected,r,budget);
            }}};
        auto make_mosaic=[&](){if(input.options.mosaic_adaptation){auto request=intact.mosaic;
            request.protected_void=protected_cells;
            if(input.options.negotiated_recovery) {
                next_mosaic=propose_mosaic_recovery(request,intact.frame,old.frame.result,out.original_frame.result,
                    input.options.recovery_offers?base.slots:std::vector<TransitionSlot>{},shared,old.mosaic,
                    old.mosaic_recovery_receipts,old.recovery_frontier,mb,r,input.options.optional_negotiation);
            }else if(mosaic_cache_result>0&&same_slots(old.frame.slots,mosaic_cache_slots)&&
               same_native_input(old.frame.result,out.rounds[mosaic_cache_observation].frame.result)) {
                next_mosaic.plan=out.rounds[mosaic_cache_result].mosaic;next_mosaic.request=out.rounds[mosaic_cache_result].mosaic_request;
                next_mosaic.bearing_replacements=out.rounds[mosaic_cache_result].mosaic_bearing_replacements;
                next_mosaic.bearing_rejections=out.rounds[mosaic_cache_result].mosaic_bearing_rejections;
                next_mosaic.supported_receptors=out.rounds[mosaic_cache_result].mosaic_supported_receptors;
                next_mosaic.supported_receptor_work=out.rounds[mosaic_cache_result].mosaic_supported_receptor_work;
                next_mosaic.reason="reused identical immutable input; original successful solve retained";reused_mosaic=true;
            }else next_mosaic=propose_mosaic_revision(request,old.frame.result,old.frame.slots,shared,mb,r,
                &old.mosaic.result,&old.mosaic.categories,input.options.optional_negotiation,input.options.native_mosaic_bearing,input.options.supported_native_receptors);}};
        if(reverse){make_mosaic();make_frame();}else{make_frame();make_mosaic();}
        Round next;next.number=r;next.frame=std::move(next_frame);next.mosaic=std::move(next_mosaic.plan);
        next.mosaic_request=input.options.mosaic_adaptation?next_mosaic.request:old.mosaic_request;
        next.proposed_frame=next.frame.result;next.proposed_mosaic=next.mosaic.result;
        next.mosaic_trace=next_mosaic.trace;next.mosaic_proposal_reason=next_mosaic.reason;
        next.mosaic_proposal_work=next_mosaic.generator_work+next_mosaic.wrapper_work;
        next.mosaic_proposal_solver_debit=next_mosaic.solver_debit;
        next.mosaic_bearing_replacements=next_mosaic.bearing_replacements;next.mosaic_bearing_rejections=next_mosaic.bearing_rejections;
        next.mosaic_bearing_work=next_mosaic.bearing_work;
        next.mosaic_supported_receptors=next_mosaic.supported_receptors;
        next.mosaic_supported_receptor_work=next_mosaic.supported_receptor_work;
        if(input.options.negotiated_recovery) {
            next.recovery_attempts=next_mosaic.recovery_attempts;
            next.mosaic_recovery_receipts=next_mosaic.recovery_receipts;
            next.recovery_frontier=next_mosaic.recovery_frontier;
            next.recovery_work=next_mosaic.recovery_work;
            next.recovery_frontier_exhausted=next_mosaic.recovery_frontier_exhausted;
        }
        next.mosaic_reused=reused_mosaic;next.frame_reused=reused_frame;
        next.mosaic_reuse_round=mosaic_cache_result;next.frame_reuse_round=frame_cache_result;
        if(cancelled(input)||next_mosaic.status==MosaicRevisionStatus::Cancelled||
           next_mosaic.status==MosaicRevisionStatus::Exhausted||next.frame.result.status==Status::Exhausted) {
            next.frame=old.frame;next.mosaic=old.mosaic;next.mosaic_request=old.mosaic_request;next.frame_accepted=next.mosaic_accepted=false;
            next.reason=next_mosaic.reason;next.frame_work=budget.work;next.mosaic_work=m.limits.max_work-mb.generator_remaining;
            next.solver_work=m.limits.max_solver_work-mb.solver_remaining;next.shared_work=out.metrics["shared_work"];
            out.rounds.push_back(std::move(next));sync_work();
            return fail(cancelled(input)||next_mosaic.status==MosaicRevisionStatus::Cancelled?CompositionStatus::Cancelled:CompositionStatus::Exhausted,
                "proposal refused: "+next_mosaic.reason);
        }
        if(!charge_shared(out,n*9ULL)){sync_work();return fail(CompositionStatus::Exhausted,"shared claim-validation budget exhausted");}
        if(!legal_pair(input,next.frame.result,next.mosaic.result,why,&protected_cells)) {
            next.reason="simultaneous proposal rejected: "+why;
            // Canonical FRAME-first arbitration; invocation order is irrelevant.
            if(legal_pair(input,next.frame.result,old.mosaic.result,why,&protected_cells)) {
                next.mosaic=old.mosaic;next.mosaic_request=old.mosaic_request;next.mosaic_accepted=false;next.reason+="; retain complete previous MOSAIC";
            } else if(legal_pair(input,old.frame.result,next.mosaic.result,why,&protected_cells)) {
                next.frame=old.frame;next.frame_accepted=false;next.reason+="; retain complete previous FRAME";
            } else {next.frame=old.frame;next.mosaic=old.mosaic;next.mosaic_request=old.mosaic_request;next.frame_accepted=next.mosaic_accepted=false;next.reason+="; atomic rollback of both proposals";}
        } else next.reason="both immutable own proposals accepted under canonical complete-footprint claims";
        if(!next.mosaic_accepted)next.mosaic_supported_receptors=old.mosaic_supported_receptors;
        if(!next.mosaic_accepted&&input.options.negotiated_recovery) {
            next.mosaic_recovery_receipts=old.mosaic_recovery_receipts;
            // Failed bids and the advanced frontier remain observable; material
            // and accepted reservations roll back atomically to the prior state.
        }
        if(next_mosaic.status==MosaicRevisionStatus::Unsat){out.rejections.push_back("round "+std::to_string(r)+": categorical UNSAT; previous masonry retained");out.metrics["categorical_unsat_rounds"]++;}
        if(next_mosaic.status==MosaicRevisionStatus::Invalid){out.rejections.push_back("round "+std::to_string(r)+": invalid MOSAIC proposal: "+next_mosaic.reason);out.metrics["invalid_proposal_rounds"]++;}
        next.frame_changed=changed(old.frame.result,next.frame.result);next.mosaic_changed=changed(old.mosaic.result,next.mosaic.result);
        next.frame_footprint_changed=footprint_changed(old.frame.result,next.frame.result);next.mosaic_footprint_changed=footprint_changed(old.mosaic.result,next.mosaic.result);
        for(std::size_t k=0;k<old.mosaic.categories.size()&&k<next.mosaic.categories.size();++k)next.category_changed+=old.mosaic.categories[k]!=next.mosaic.categories[k];
        next.frame_work=budget.work;next.mosaic_work=m.limits.max_work-mb.generator_remaining;next.solver_work=m.limits.max_solver_work-mb.solver_remaining;next.shared_work=out.metrics["shared_work"];
        next.geometry_digest=mix(next.frame.result.material_digest)^mix(next.mosaic.result.material_digest);
        next.semantic_digest=semantic(next);const auto digest=next.semantic_digest;
        bool fixed=false,oscillation=false;
        // A growing authorized frontier already rules out convergence; avoid
        // an otherwise unused full equality scan and its associated debit.
        if(!input.options.negotiated_recovery||next.recovery_frontier_exhausted)
        for(std::size_t previous=0;previous<out.rounds.size();++previous)if(digest==out.rounds[previous].semantic_digest) {
            if(!charge_shared(out,n*6ULL+8192ULL)){sync_work();return fail(CompositionStatus::Exhausted,"exact architectural equality allowance");}
            if(same_architecture(next,out.rounds[previous])){fixed=previous+1==out.rounds.size();oscillation=!fixed;break;}
        }
        if(!reused_mosaic&&input.options.mosaic_adaptation&&next.mosaic_accepted&&next_mosaic.status==MosaicRevisionStatus::Complete) {
            mosaic_cache_observation=static_cast<unsigned>(out.rounds.size()-1);mosaic_cache_result=static_cast<unsigned>(out.rounds.size());mosaic_cache_slots=old.frame.slots;
        }
        if(!reused_frame&&input.options.frame_adaptation&&next.frame_accepted) {
            frame_cache_observation=static_cast<unsigned>(out.rounds.size()-1);frame_cache_result=static_cast<unsigned>(out.rounds.size());has_frame_cache=true;
        }
        out.rounds.push_back(std::move(next));sync_work();
        if(fixed&&(!input.options.negotiated_recovery||out.rounds.back().recovery_frontier_exhausted)){
            out.stop_reason=input.options.negotiated_recovery?
                (out.rounds.back().recovery_frontier.empty()?"semantic_fixed_point":"candidate_frontier_exhausted"):"fixed_point";break;}
        if(input.options.negotiated_recovery&&oscillation&&!out.rounds.back().recovery_frontier_exhausted)oscillation=false;
        if(oscillation){out.stop_reason="oscillation";return fail(CompositionStatus::Oscillation,"repeated earlier semantic geometry state; no commit");}
    }
    out.metrics["frame_work"]=budget.work;out.metrics["mosaic_work"]=m.limits.max_work-mb.generator_remaining;
    out.metrics["solver_work"]=m.limits.max_solver_work-mb.solver_remaining;
    out.metrics["frame_candidates"]=budget.candidates;
    out.metrics["frame_changed_rounds"]=0;out.metrics["mosaic_changed_rounds"]=0;
    for(const auto& r:out.rounds){out.metrics["frame_changed_rounds"]+=r.frame_changed>0;out.metrics["mosaic_changed_rounds"]+=r.mosaic_changed>0;
        out.metrics["frame_footprint_changed_rounds"]+=r.frame_footprint_changed>0;out.metrics["mosaic_footprint_changed_rounds"]+=r.mosaic_footprint_changed>0;}
    out.metrics["both_genteks_revised"]=out.metrics["frame_footprint_changed_rounds"]>0&&out.metrics["mosaic_footprint_changed_rounds"]>0;
    if(input.options.negotiated_recovery)for(const auto& round:out.rounds) {
        out.metrics["recovery_work"]+=round.recovery_work;
        out.metrics["recovery_attempts"]+=round.recovery_attempts.size();
        for(const auto& attempt:round.recovery_attempts)out.metrics["recovery_"+attempt.outcome]++;
    }
    if(f.profile.destruction>0||m.profile.destruction>0) {
        const auto& last=out.rounds.back();auto fq=f,mq=last.mosaic_request;
        fq.profile.destruction=f.profile.destruction;mq.profile.destruction=m.profile.destruction;
        for(std::size_t i=0;i<n;++i)if(input.options.shared_ownership&&input.shared_zone[i]){fq.eligible[i]=1;mq.eligible[i]=1;}
        const auto fw=derivative_work(last.frame.result),mw=derivative_work(last.mosaic.result);
        if(!frame_charge(budget,fw)||mw>mb.generator_remaining){sync_work();return fail(CompositionStatus::Exhausted,"separate destruction derivative exceeds existing generator allowance");}
        mb.generator_remaining-=mw;
        DamageDerivative derivative;derivative.frame=last.frame;derivative.mosaic=last.mosaic;
        derivative.reason="separate seeded removal derivative; intact negotiated snapshots and causal receipts retained";
        derivative.work=fw+mw;
        apply_damage(fq,derivative.frame.result);apply_damage(mq,derivative.mosaic.result);
        finish_result(fq,derivative.frame.result);finish_result(mq,derivative.mosaic.result);
        derivative.frame_changed=changed(last.frame.result,derivative.frame.result);derivative.mosaic_changed=changed(last.mosaic.result,derivative.mosaic.result);
        derivative.frame_footprint_changed=footprint_changed(last.frame.result,derivative.frame.result);
        derivative.mosaic_footprint_changed=footprint_changed(last.mosaic.result,derivative.mosaic.result);
        out.damage_derivative=std::move(derivative);sync_work();
        out.metrics["destruction_applied"]=1;
    }
    out.status=CompositionStatus::Blocked;
    if(input.options.negotiated_recovery)for(const auto* owner:{"frame","mosaic","solver"})
        out.metrics[std::string("proposal_")+owner+"_work"]=out.metrics[std::string(owner)+"_work"];
    if(input.options.negotiated_recovery) {
        // Native custody is a capability of this in-process run, never a public
        // receipt which a JSON reader or caller can recompute to gain authority.
        const auto admission_work=8192ULL+n*(out.rounds.size()+1ULL);
        if(!charge_shared(out,admission_work))return fail(CompositionStatus::Exhausted,"budget_exhaustion: native custody admission");
        out.metrics["custody_admission_work"]+=admission_work;
        out.metrics["custody_policy_version"]=1;
        std::uint64_t bytes=0;
        if(!admit_recovery_history(out,why,bytes))return fail(CompositionStatus::Invalid,"native custody admission: "+why);
        out.metrics["custody_memory_bound_bytes"]=bytes;
        const auto before=out.metrics["shared_work"];
        try {
            const auto transcript=fingerprint_native_custody(out,out.metrics["shared_work"],2'000'000);
            out.metrics["custody_mint_work"]=out.metrics["shared_work"]-before;
            out.metrics["total_charged_work"]=total_work(out);
            out.native_authority_=std::shared_ptr<const NativeRunAuthority>(new NativeRunAuthority(transcript,out));
        }catch(const std::exception&) {
            out.metrics["custody_mint_work"]=out.metrics["shared_work"]-before;
            return fail(cancelled(input)?CompositionStatus::Cancelled:CompositionStatus::Exhausted,
                cancelled(input)?"cancellation: native custody mint":"budget_exhaustion: native custody mint");
        }
    }
    if(!validate_composition(out)) {
        if(input.options.negotiated_recovery&&out.status==CompositionStatus::Exhausted)out.stop_reason="budget_exhaustion";
        if(out.native_authority_)out.native_authority_=std::shared_ptr<const NativeRunAuthority>(new NativeRunAuthority(out.native_authority_->transcript,out));
        return out;
    }
    if(input.options.negotiated_recovery&&out.can_apply)out.stop_reason="successful_full_closure";
    if(input.options.final_validation){out.reason=out.can_apply?"complete native composition with qualified obligations":"native proposal retained; unresolved hard obligations prevent Apply";}
    else {out.can_apply=false;out.reason="validator-disabled diagnostic, never eligible for Apply";}
    if(out.native_authority_)out.native_authority_=std::shared_ptr<const NativeRunAuthority>(new NativeRunAuthority(out.native_authority_->transcript,out));
    return out;
}

bool validate_composition(Composition& c) {
    c.can_apply=false;
    // Check the private origin even if a caller clears the public experiment
    // option; downgrade, authority transplant and refunded counters fail closed.
    if(c.native_authority_||c.input.options.negotiated_recovery) {
        if(!c.native_authority_||!c.input.options.negotiated_recovery||
           c.metrics!=c.native_authority_->reported_metrics||c.stop_reason!=c.native_authority_->reported_stop||c.reason!=c.native_authority_->reported_reason||
           c.input.cancel!=c.native_authority_->cancellation_token) {
            c.status=CompositionStatus::Invalid;c.reason="SWARM006 custody: absent native authority, changed mode, work or scientific receipts";return false;
        }
    }
    if(!c.native_authority_){c.joints.clear();c.obligations.clear();c.cells.clear();c.ledger.clear();}
    if(c.input.options.negotiated_recovery&&c.metrics.contains("total_charged_work")&&c.metrics.at("total_charged_work")!=total_work(c)) {
        c.status=CompositionStatus::Invalid;c.reason="SWARM006 transcript: inconsistent aggregate work receipt";return false;
    }
    auto& total=c.metrics["total_charged_work"];
    bool custody_verified=false;
    struct WorkReceipt {Composition& composition;std::uint64_t& total;bool& verified;
        ~WorkReceipt(){total=total_work(composition);
            if(verified&&composition.native_authority_)composition.native_authority_=std::shared_ptr<const NativeRunAuthority>(
                new NativeRunAuthority(composition.native_authority_->transcript,composition));}
    } receipt{c,total,custody_verified};
    for(const auto* key:{"new_assembly_required","candidate_native_contacts","unchecked_candidate_contacts","rejected_joint_source_bindings"})c.metrics[key]=0;
    if(c.rounds.empty()||c.rounds.size()>5){c.status=CompositionStatus::Invalid;c.reason="missing or unbounded accepted revision history";return false;}
    if(cancelled(c.input)||c.status==CompositionStatus::Cancelled){c.status=CompositionStatus::Cancelled;c.reason="cancelled before final authorization";return false;}
    if(c.status==CompositionStatus::Invalid||c.status==CompositionStatus::Exhausted||c.status==CompositionStatus::Unsat||c.status==CompositionStatus::Oscillation)return false;
    std::string input_reason;
    if(!paired_input_valid(c.input,input_reason)) {
        c.status=CompositionStatus::Invalid;c.reason="malformed final input: "+input_reason;return false;
    }
    const auto& fq=c.input.frame;const auto count=static_cast<std::size_t>(fq.width)*static_cast<std::size_t>(fq.height);
    if(c.native_authority_) {
        const auto admission_work=8192ULL+count*(c.rounds.size()+1ULL);
        if(!charge_shared(c,admission_work)){c.status=CompositionStatus::Exhausted;c.reason="budget_exhaustion: custody verification admission";return false;}
        c.metrics["custody_admission_work"]+=admission_work;
        std::uint64_t bytes=0;
        if(!admit_recovery_history(c,input_reason,bytes)) {c.status=CompositionStatus::Invalid;c.reason="SWARM006 custody admission: "+input_reason;return false;}
        const auto before=c.metrics["shared_work"];
        try {
            const auto fingerprint=fingerprint_native_custody(c,c.metrics["shared_work"],2'000'000);
            c.metrics["custody_verification_work"]+=c.metrics["shared_work"]-before;
            if(fingerprint!=c.native_authority_->transcript){c.status=CompositionStatus::Invalid;c.reason="SWARM006 custody: mutated native source, proposal or history";return false;}
            custody_verified=true;
            c.joints.clear();c.obligations.clear();c.cells.clear();c.ledger.clear();
        }catch(const std::exception&) {
            c.metrics["custody_verification_work"]+=c.metrics["shared_work"]-before;
            c.status=cancelled(c.input)?CompositionStatus::Cancelled:CompositionStatus::Exhausted;
            c.reason=cancelled(c.input)?"cancellation: native custody verification":"budget_exhaustion: native custody verification";return false;
        }
    }
    for(const auto& round:c.rounds)for(const auto* result:{&round.frame.result,&round.mosaic.result}) {
        if(result->cells.size()!=count||result->roles.size()!=count||result->provenance.size()!=count) {
            c.status=CompositionStatus::Invalid;c.reason="malformed accepted revision snapshot";return false;
        }
        for(const auto* mask:{&result->boundary.protected_geometry,&result->boundary.transition})
            if(!mask->empty()&&(mask->size()!=count||std::any_of(mask->begin(),mask->end(),[](auto v){return v>1;}))) {
                c.status=CompositionStatus::Invalid;c.reason="malformed historical protected/transition mask";return false;
            }
    }
    for(std::size_t ordinal=0;ordinal<c.rounds.size();++ordinal) {
        const auto& round=c.rounds[ordinal];
        if(round.number!=ordinal||round.number>c.input.options.rounds){c.status=CompositionStatus::Invalid;c.reason="invalid revision ordinal";return false;}
        for(const auto* result:{&round.frame.result,&round.mosaic.result}) {
            for(const auto& part:result->instances)if(part.id==0||part.id>256){c.status=CompositionStatus::Invalid;c.reason="invalid historical part identity";return false;}
            for(auto id:result->provenance)if(id>256){c.status=CompositionStatus::Invalid;c.reason="invalid historical cell identity";return false;}
        }
    }
    if(!certify_recovery_history(c))return false;
    // SWARM-005: every opt-in supported receptor is a replayable native fact,
    // never an unverified interface annotation. Validate all retained rounds,
    // not just a favourable final proposal, against their actual immutable
    // preceding FRAME source and the accepted MOSAIC native motif footprint.
    for(std::size_t ordinal=0;ordinal<c.rounds.size();++ordinal) {
        const auto& round=c.rounds[ordinal];
        const auto& receptors=round.mosaic_supported_receptors;
        std::size_t tagged=0;
        for(const auto& port:round.mosaic.result.boundary.hard)
            tagged+=port.tag.starts_with("swarm005/source-slot=");
        const auto reject=[&](const std::string& why) {
            c.status=CompositionStatus::Invalid;
            c.reason="unqualified SWARM005 source-bound native receptor: "+why;
            ++c.metrics["rejected_joint_source_bindings"];
            return false;
        };
        if(tagged!=receptors.size()||receptors.size()>8||
           (tagged!=0&&(!c.input.options.supported_native_receptors||ordinal==0)))
            return reject("incorrect round, opt-in authority, count or missing receipt");
        if(receptors.empty())continue;
        if(!charge_shared(c,receptors.size()*(count/8+256ULL))) {
            c.status=CompositionStatus::Exhausted;c.reason="source-bound receptor audit budget";return false;
        }
        const auto& prior=c.rounds[ordinal-1].frame;
        const auto& masonry=round.mosaic.result;
        const auto& mrequest=round.mosaic_request;
        if(mrequest.width!=fq.width||mrequest.height!=fq.height||
           mrequest.source_identity!=fq.source_identity||mrequest.seed!=fq.seed)return reject("mismatched native request identity");
        std::set<std::uint32_t> seen_ports;
        std::set<Point> seen_contacts;
        for(const auto& witness:receptors) {
            if(!seen_ports.insert(witness.port_id).second||!seen_contacts.insert(witness.contact).second)
                return reject("duplicate published receiver");
            const auto it=std::find_if(prior.slots.begin(),prior.slots.end(),[&](const auto& slot){
                return slot.id==witness.slot&&slot.connector==witness.connector&&
                       slot.instance==witness.source_instance&&slot.required&&slot.hard&&slot.owner=="FRAMEWEAVER";
            });
            if(it==prior.slots.end())return reject("no original pre-declared source slot");
            const auto source=std::find_if(prior.result.connectors.begin(),prior.result.connectors.end(),
                [&](const Connector& conn){return conn.id==witness.connector&&conn.instance==witness.source_instance&&
                    conn.required&&!conn.fulfilled&&conn.family==Family::Frame&&conn.facing==it->facing;});
            const auto reserved_roots=line(it->a,it->b);
            const auto real_roots=source==prior.result.connectors.end()?std::vector<Point>{}:line(source->a,source->b);
            if(std::find(reserved_roots.begin(),reserved_roots.end(),witness.root)==reserved_roots.end()||
               std::find(real_roots.begin(),real_roots.end(),witness.root)==real_roots.end())return reject("source slot/root declaration mismatch");
            const Point towards=it->facing;
            const Point contact=witness.contact,backing=witness.backing,root=witness.root;
            const int distance=dist(root,contact);
            if(source==prior.result.connectors.end())return reject("root is not on the original required source");
            if(witness.facing!=neg(towards)||distance<1||distance>14||
               contact!=Point{root.x+distance*towards.x,root.y+distance*towards.y}||
               backing!=plus(contact,towards)||!in_box(contact,it->envelope)||
               !inside(fq,root)||!inside(fq,contact)||!inside(fq,backing))return reject("face, reach, alignment or reservation envelope drift");
            const auto port=std::find_if(masonry.boundary.hard.begin(),masonry.boundary.hard.end(),[&](const Affordance& a){
                return a.id==witness.port_id&&a.instance==witness.receiving_instance&&a.a==contact&&a.b==contact&&
                    a.facing==witness.facing&&a.family==Family::Frame&&!a.required&&
                    a.tag==("swarm005/source-slot="+std::to_string(witness.slot)+";connector="+std::to_string(witness.connector));
            });
            if(port==masonry.boundary.hard.end())return reject("no exact source-tagged MOSAIC structural port");
            const auto src=index(fq,root),a=index(fq,contact),b=index(fq,backing);
            if(prior.result.provenance[src]!=witness.source_instance||
               !native_bearing(prior.result.cells[src],prior.result.roles[src])||
               !allowed(mrequest,contact)||!allowed(mrequest,backing)||
               !native_bearing(masonry.cells[a],masonry.roles[a])||!native_bearing(masonry.cells[b],masonry.roles[b])||
               masonry.provenance[a]!=witness.receiving_instance||masonry.provenance[b]!=witness.receiving_instance||
               witness.receiving_instance==0)return reject("unsupported native material, protection, occupancy or ownership");
            const auto owner=std::find_if(masonry.instances.begin(),masonry.instances.end(),[&](const Instance& x){
                return x.id==witness.receiving_instance;});
            if(owner==masonry.instances.end()||
               std::find(owner->cells.begin(),owner->cells.end(),contact)==owner->cells.end()||
               std::find(owner->cells.begin(),owner->cells.end(),backing)==owner->cells.end())
                return reject("no native owning part backing the receptor");
            for(int step=1;step<distance;++step) {
                Point p{root.x+step*towards.x,root.y+step*towards.y};
                if(!inside(fq,p)||!allowed(mrequest,p)||masonry.cells[index(fq,p)]!=Material::Empty)
                    return reject("occupied, forbidden or out-of-bounds clearance to receptor");
            }
        }
    }
    auto& last=c.rounds.back();std::string why;
    auto& final_frame=c.damage_derivative?c.damage_derivative->frame:last.frame;
    auto& final_mosaic=c.damage_derivative?c.damage_derivative->mosaic:last.mosaic;
    if(final_frame.slots.size()>8||final_frame.constructions.size()>8){c.status=CompositionStatus::Invalid;c.reason="final slot/assembly capacity";return false;}
    if(!charge_shared(c,count*(8ULL+c.rounds.size()*2ULL)+8192ULL)){c.status=CompositionStatus::Exhausted;c.reason="final validation allowance";return false;}
    const auto preserved=protected_union(c.input,c.rounds.front().frame.result,c.rounds.front().mosaic.result);
    for(const auto& round:c.rounds)if(!legal_pair(c.input,round.frame.result,round.mosaic.result,why,&preserved)) {
        c.status=CompositionStatus::Invalid;c.reason="invalid accepted history: "+why;return false;
    }
    Result empty_mosaic;empty_mosaic.width=fq.width;empty_mosaic.height=fq.height;empty_mosaic.status=Status::Complete;
    empty_mosaic.gentek=Kind::Mosaic;empty_mosaic.seed=fq.seed;empty_mosaic.source_identity=fq.source_identity;
    empty_mosaic.cells.assign(count,Material::Empty);empty_mosaic.roles.assign(count,Role::Empty);empty_mosaic.provenance.assign(count,0);
    if(!legal_pair(c.input,c.original_frame.result,empty_mosaic,why)) {
        c.status=CompositionStatus::Invalid;c.reason="invalid original source: "+why;return false;
    }
    for(const auto& round:c.rounds) {
        if(round.frame.slots.size()>8||round.frame.constructions.size()>8){c.status=CompositionStatus::Invalid;c.reason="historical slot/assembly capacity";return false;}
        std::set<std::uint32_t> constructed_slots;
        for(const auto& part:round.frame.constructions) {
            const auto slot=std::find_if(round.frame.slots.begin(),round.frame.slots.end(),[&](const auto& s){return s.id==part.slot;});
            if(slot==round.frame.slots.end()||!constructed_slots.insert(part.slot).second||(!slot->required&&!c.input.options.optional_negotiation)) {
                c.status=CompositionStatus::Invalid;c.reason="orphan, repeated or unauthorized assembly proposal";return false;
            }
            if(!certify_assembly(c,part,round.number,round.frame.result))return false;
        }
    }
    if(c.damage_derivative) {
        if(c.input.frame.profile.destruction<=0&&c.input.mosaic.profile.destruction<=0) {
            c.status=CompositionStatus::Invalid;c.reason="undeclared destruction derivative";return false;
        }
        const auto& damage=*c.damage_derivative;
        const auto cost=count*4ULL+last.frame.result.connectors.size()*(last.frame.result.instances.size()*3ULL+32ULL)+
            last.mosaic.result.boundary.hard.size()*(last.mosaic.result.instances.size()+32ULL);
        if(!charge_shared(c,cost)){c.status=CompositionStatus::Exhausted;c.reason="seeded derivative proof allowance";return false;}
        auto expected_frame=last.frame.result,expected_mosaic=last.mosaic.result;
        apply_damage(c.input.frame,expected_frame);apply_damage(c.input.mosaic,expected_mosaic);
        if(!same_native_input(expected_frame,damage.frame.result)||!same_native_input(expected_mosaic,damage.mosaic.result)||
           !same_connections(expected_frame,damage.frame.result)||!same_connections(expected_mosaic,damage.mosaic.result)||
           !same_slots(last.frame.slots,damage.frame.slots)||damage.frame.constructions.size()!=last.frame.constructions.size()||
           damage.mosaic.categories!=last.mosaic.categories||
           damage.frame_changed!=changed(last.frame.result,damage.frame.result)||damage.mosaic_changed!=changed(last.mosaic.result,damage.mosaic.result)||
           damage.frame_footprint_changed!=footprint_changed(last.frame.result,damage.frame.result)||
           damage.mosaic_footprint_changed!=footprint_changed(last.mosaic.result,damage.mosaic.result)) {
            c.status=CompositionStatus::Invalid;c.reason="destruction derivative differs from its declared native seeded removal";return false;
        }
        for(std::size_t i=0;i<last.frame.constructions.size();++i) {
            if(!same_assembly(last.frame.constructions[i].assembly,damage.frame.constructions[i].assembly)) {
                c.status=CompositionStatus::Invalid;c.reason="destruction changed an intact authored assembly receipt";return false;
            }
            if(!certify_assembly(c,damage.frame.constructions[i],last.number,last.frame.result))return false;
        }
    }
    if(!legal_pair(c.input,final_frame.result,final_mosaic.result,why)) {
        c.status=CompositionStatus::Invalid;c.reason=why;c.metrics["hard_violations"]++;return false;
    }
    const auto& f=final_frame.result;const auto& m=final_mosaic.result;const auto& q=c.input.frame;
    std::array<const Instance*,257> final_parts{};
    for(const auto& part:f.instances)final_parts[part.id]=&part;
    std::set<Point> used_sources,used_targets;std::set<std::uint32_t> joined_connectors;
    for(const auto& slot:final_frame.slots) {
        if(!slot.required&&!c.input.options.optional_negotiation)continue;
        const auto constructed=std::find_if(final_frame.constructions.begin(),final_frame.constructions.end(),[&](const auto& p){return p.slot==slot.id;});
        const auto root=constructed==final_frame.constructions.end()?slot.a:constructed->root;
        const auto original=std::find_if(c.original_frame.result.connectors.begin(),c.original_frame.result.connectors.end(),
            [&](const auto& p){return p.id==slot.connector;});
        const auto invalid_binding=[&](){c.metrics["rejected_joint_source_bindings"]++;};
        if(original==c.original_frame.result.connectors.end()||!inside(q,root)||
           !inside(q,original->a)||!inside(q,original->b)||(original->a.x!=original->b.x&&original->a.y!=original->b.y)||dist(original->a,original->b)>32||
           !inside(q,slot.a)||!inside(q,slot.b)||!cardinal(slot.facing)||
           (slot.a.x!=slot.b.x&&slot.a.y!=slot.b.y)||dist(slot.a,slot.b)>32||
           original->facing!=slot.facing||slot.required!=original->required||
           c.original_frame.result.cells.size()!=f.cells.size()||c.original_frame.result.provenance.size()!=f.cells.size()) {
            invalid_binding();continue;
        }
        const auto source_points=line(original->a,original->b);
        if(std::find(source_points.begin(),source_points.end(),root)==source_points.end()||
           c.original_frame.result.cells[index(q,root)]==Material::Empty||
           c.original_frame.result.provenance[index(q,root)]!=original->instance) {invalid_binding();continue;}
        if(constructed==final_frame.constructions.end()) {
            if(slot.instance!=original->instance||slot.a!=original->a||slot.b!=original->b){invalid_binding();continue;}
        }else{
            const auto& part=*constructed;const auto& assembly=part.assembly;
            if(assembly.nodes.empty()||assembly.instances.empty()||assembly.claims.empty()||assembly.sockets.empty()||
               assembly.round>last.number||assembly.revision>last.number||part.input_family!=original->family) {invalid_binding();continue;}
            const bool input_socket=std::any_of(assembly.sockets.begin(),assembly.sockets.end(),[&](const auto& s){
                return s.a==root&&s.b==root&&s.facing==neg(original->facing)&&s.family==original->family&&s.obligation==Obligation::LocalTerminable;});
            const bool output_socket=std::any_of(assembly.sockets.begin(),assembly.sockets.end(),[&](const auto& s){
                return s.a==slot.a&&s.b==slot.b&&s.facing==slot.facing&&s.family==Family::Frame&&s.obligation==Obligation::ForeignRequired;});
            bool exports_retained=true;
            for(const auto& component:assembly.instances)for(const auto& socket:component.sockets)if(socket.obligation==Obligation::ForeignRequired&&
                std::none_of(assembly.sockets.begin(),assembly.sockets.end(),[&](const auto& exported){
                    return socket.instance==exported.instance&&socket.source_socket==exported.source_socket&&
                        socket.a==exported.a&&socket.b==exported.b&&socket.facing==exported.facing&&socket.family==exported.family&&
                        exported.obligation==Obligation::ForeignRequired;}))exports_retained=false;
            if(part.base_instance!=original->instance||part.connector!=original->id||part.facing!=original->facing||
               part.face!=slot.a||assembly.outcome!=Outcome::Complete||assembly.owner!=Owner::Frameweaver||
               !input_socket||!output_socket||!exports_retained||part.parts.empty()||part.parts.size()>64){invalid_binding();continue;}
            bool claims=true;
            for(const auto& claim:assembly.claims) {
                if(!charge_shared(c)||!inside(q,claim.point)){claims=false;break;}
                const auto i=index(q,claim.point);
                if(f.cells[i]!=claim.material||!structural(f.roles[i])||
                   (f.provenance[i]!=original->instance&&std::find(part.parts.begin(),part.parts.end(),f.provenance[i])==part.parts.end())){claims=false;break;}
            }
            if(!claims){invalid_binding();continue;}
            std::set<std::uint32_t> actual_parts,reused_components;
            for(const auto& component:assembly.instances) {
                std::uint32_t native_owner=0;std::vector<Point> footprint;
                for(const auto& claim:assembly.claims)if(claim.instance==component.instance) {
                    if(!charge_shared(c)){c.status=CompositionStatus::Exhausted;c.reason="part provenance certificate allowance";return false;}
                    footprint.push_back(claim.point);const auto owner=f.provenance[index(q,claim.point)];
                    if(owner!=original->instance) {
                        if(native_owner&&native_owner!=owner){claims=false;break;}
                        native_owner=owner;
                    }
                }
                if(!claims)break;
                if(!native_owner){reused_components.insert(component.instance);continue;}
                const auto* native_part=final_parts[native_owner];
                if(!native_part||!actual_parts.insert(native_owner).second||native_part->kind!="swarm004/"+component.name||
                   native_part->reason!=component.rule||native_part->origin!=component.transform.translation||
                   native_part->orientation!=static_cast<int>(component.transform.quarter_turns)||!native_part->structural||native_part->cells!=footprint) {claims=false;break;}
            }
            if(!claims||actual_parts.size()!=part.parts.size()||actual_parts!=std::set<std::uint32_t>(part.parts.begin(),part.parts.end())||
               reused_components.size()!=part.reused_host_components.size()||reused_components!=std::set<std::uint32_t>(part.reused_host_components.begin(),part.reused_host_components.end())) {
                invalid_binding();continue;
            }
        }
        bool found=false;
        for(const auto& port:m.boundary.hard) {
            if(!charge_shared(c)){c.status=CompositionStatus::Exhausted;c.reason="final receptor work allowance";return false;}
            if(found)break;
            const auto expected_family=constructed==final_frame.constructions.end()?original->family:Family::Frame;
            if((expected_family!=Family::Frame&&expected_family!=Family::Brace)||port.family!=expected_family||port.facing!=neg(slot.facing))continue;
            if(port.tag.starts_with("swarm006/")&&std::none_of(last.mosaic_recovery_receipts.begin(),last.mosaic_recovery_receipts.end(),[&](const auto& r){
                return r.port_id==port.id&&r.slot==slot.id&&r.connector==slot.connector&&r.source_instance==original->instance&&
                       r.receiving_instance==port.instance&&r.contact==port.a&&r.receiving_family==expected_family;
            }))continue; // a valid port for another source is not a claimed match
            if(!inside(q,port.a)||!inside(q,port.b)||(port.a.x!=port.b.x&&port.a.y!=port.b.y)||dist(port.a,port.b)>32)continue;
            for(auto face:line(slot.a,slot.b)) {
                if(found)break;
                const auto contact=plus(face,slot.facing);
                const auto port_points=line(port.a,port.b);
                if(!inside(q,face)||!inside(q,contact)||used_sources.contains(face)||used_targets.contains(contact)||
                   std::find(port_points.begin(),port_points.end(),contact)==port_points.end())continue;
                const auto a=index(q,face),b=index(q,contact);const auto behind=plus(contact,slot.facing);
                if(!native_bearing(f.cells[a],f.roles[a])||!native_bearing(m.cells[b],m.roles[b])||
                   m.provenance[b]!=port.instance||!inside(q,behind)||m.cells[index(q,behind)]==Material::Empty||
                   !structural(m.roles[index(q,behind)])||material_definition(m.cells[index(q,behind)]).state!=MaterialState::Solid)continue;
                std::vector<Point> path;
                c.metrics["candidate_native_contacts"]++;
                if(!c.input.options.final_validation){c.metrics["unchecked_candidate_contacts"]++;continue;}
                if(!material_path(c,f,root,face,path))continue;
                path.push_back(contact);
                JointWitness joint; joint.connector=slot.connector;joint.slot=slot.id;joint.root=root;
                joint.frame_face=face;joint.masonry_face=contact;joint.normal=slot.facing;
                joint.family=expected_family;
                joint.frame_instance=f.provenance[a];joint.mosaic_instance=port.instance;joint.path=std::move(path);
                c.joints.push_back(std::move(joint));used_sources.insert(face);used_targets.insert(contact);
                joined_connectors.insert(slot.connector);found=true;
            }
        }
    }
    std::uint64_t unresolved=0;
    for(const auto& original:c.original_frame.result.connectors) {
        if(!original.required||original.fulfilled)continue;
        ObligationReceipt r;r.connector=original.id;r.instance=original.instance;r.original=original.a;r.facing=original.facing;
        const auto slot=std::find_if(final_frame.slots.begin(),final_frame.slots.end(),[&](const auto& s){return s.connector==original.id;});
        if(slot!=final_frame.slots.end())r.slot=slot->id;
        r.foreign_joined=joined_connectors.contains(original.id);
        if(r.foreign_joined){r.state="FOREIGN_JOINED";r.reason="unique typed native receptor and material path";}
        else {
            ++unresolved;r.reason=r.slot?"reserved source lacks a qualified final material path":"original source has no constructible reserved receiver";
            if(c.input.options.negotiated_recovery) {
                r.reason=r.slot?"no_qualifying_continuous_material_path":"unreachable_receiver_territory_or_reservation_capacity";
                for(const auto& round:c.rounds)for(const auto& attempt:round.recovery_attempts)if(attempt.connector==original.id)r.reason=attempt.reason;
                if(std::any_of(last.mosaic_recovery_receipts.begin(),last.mosaic_recovery_receipts.end(),[&](const auto& bid){return bid.connector==original.id;}))
                    r.reason="native_receiver_reserved_but_no_qualifying_continuous_material_path";
            }
        }
        // A local engineered ending is reported separately and cannot change state.
        for(const auto& part:final_frame.result.instances)if(part.kind=="swarm004/local_flush_ending"&&part.origin==original.a)r.local_terminated=true;
        c.obligations.push_back(std::move(r));
    }
    c.metrics["original_required"]=c.obligations.size();c.metrics["still_required"]=unresolved;
    c.metrics["original_still_required"]=unresolved;
    c.metrics["foreign_joined_required"]=c.obligations.size()-unresolved;
    std::uint32_t new_id=0x80000000U;
    for(const auto& construction:final_frame.constructions)for(const auto& socket:construction.assembly.sockets) {
        if(socket.obligation!=Obligation::ForeignRequired)continue;
        ObligationReceipt receipt;receipt.origin="new_assembly";receipt.connector=++new_id;
        receipt.slot=construction.slot;receipt.original=socket.a;receipt.facing=socket.facing;
        receipt.instance=inside(q,socket.a)?f.provenance[index(q,socket.a)]:0;
        receipt.foreign_joined=std::any_of(c.joints.begin(),c.joints.end(),[&](const auto& j){
            return j.slot==construction.slot&&j.frame_face==socket.a&&j.normal==socket.facing&&j.frame_instance==receipt.instance;});
        receipt.state=receipt.foreign_joined?"FOREIGN_JOINED":"STILL_REQUIRED";
        receipt.reason=receipt.foreign_joined?"new authored assembly hard output has its exact foreign witness":"new authored assembly foreign-required output remains unresolved";
        if(!receipt.foreign_joined)++unresolved;
        c.obligations.push_back(std::move(receipt));c.metrics["new_assembly_required"]++;
    }
    c.metrics["damage_lost_required"]=0;
    if(c.damage_derivative)for(const auto& original:c.original_frame.result.connectors)if(original.required&&original.fulfilled) {
        const auto found=std::find_if(f.connectors.begin(),f.connectors.end(),[&](const auto& socket){return socket.id==original.id&&socket.fulfilled;});
        if(found==f.connectors.end()) {
            ObligationReceipt lost;lost.connector=original.id;lost.instance=original.instance;lost.original=original.a;lost.facing=original.facing;
            lost.origin="damage_lost_internal";lost.reason="separate destruction revoked a previously qualified original required joint";
            c.obligations.push_back(std::move(lost));++unresolved;c.metrics["damage_lost_required"]++;
        }
    }
    if(c.input.options.negotiated_recovery) {
        // Best among the closure proofs actually attempted, not an assertion
        // that every earlier geometric prefix was separately qualified.
        c.metrics["closure_proof_rounds"]=1;c.metrics["best_proven_closure_round"]=last.number;
        c.metrics["best_proven_qualified_joints"]=c.joints.size();c.metrics["best_proven_remaining_requirements"]=unresolved;
        const auto compact=c.original_frame.result.metrics.find("swarm005_source_compact_terminations");
        c.metrics["source_time_compact_terminations"]=compact==c.original_frame.result.metrics.end()?0:compact->second;
        c.metrics["source_feasibility_opportunities"]=c.original_frame.source_feasibility.size();
    }
    c.metrics["still_required"]=unresolved;c.metrics["qualified_joints"]=c.joints.size();
    c.metrics["local_terminations"]=final_frame.local_terminations;c.metrics["coordinator_created_cells"]=0;
    c.metrics["total_charged_work"]=c.metrics["frame_work"]+c.metrics["mosaic_work"]+c.metrics["solver_work"]+c.metrics["shared_work"];
    if(c.metrics["total_charged_work"]>10'000'000){c.status=CompositionStatus::Exhausted;c.reason="aggregate work ceiling";return false;}
    if(!charge_shared(c,c.input.frame.width*static_cast<std::uint64_t>(c.input.frame.height)*(c.rounds.size()+4ULL))) {
        c.status=CompositionStatus::Exhausted;c.reason="final provenance ledger allowance";return false;
    }
    fill_ledger(c);c.digest=mix(last.semantic_digest^c.input.frame.seed);
    for(std::size_t i=0;i<c.cells.size();++i)c.digest=mix(c.digest^i^static_cast<unsigned>(c.cells[i])^(static_cast<std::uint64_t>(c.ledger[i].owner)<<16U));
    if(cancelled(c.input)){c.status=CompositionStatus::Cancelled;c.reason="cancelled at commit authorization";c.cells.clear();c.ledger.clear();return false;}
    c.metrics["total_charged_work"]=c.metrics["frame_work"]+c.metrics["mosaic_work"]+c.metrics["solver_work"]+c.metrics["shared_work"];
    c.can_apply=c.input.options.final_validation&&unresolved==0&&c.metrics["invalid_proposal_rounds"]==0&&
        c.metrics["rejected_joint_source_bindings"]==0&&c.status!=CompositionStatus::Exhausted;
    c.status=c.can_apply?CompositionStatus::Complete:CompositionStatus::Blocked;
    return true;
}
} // namespace cybersand::gentek_swarm::assembly004
