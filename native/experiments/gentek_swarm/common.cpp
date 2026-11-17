#include "swarm.hpp"
#include <algorithm>
#include <array>
#include <bit>
#include <cmath>
#include <iomanip>
#include <limits>
#include <sstream>
#include <stdexcept>

#ifndef GENTEK_DEFINITION_SHA256
#define GENTEK_DEFINITION_SHA256 "untracked-manual-build"
#endif

namespace cybersand::gentek_swarm {
namespace {
constexpr std::uint64_t offset = 14695981039346656037ULL, prime = 1099511628211ULL;
void h(std::uint64_t& v, std::uint64_t n) {
    for (int i = 0; i < 8; ++i) { v ^= n & 255U; v *= prime; n >>= 8U; }
}
void h(std::uint64_t& v, const std::string& s) {
    h(v, s.size()); for (const auto c : s) { v ^= static_cast<unsigned char>(c); v *= prime; }
}
void h(std::uint64_t& v, Point p) { h(v, static_cast<std::uint64_t>(p.x)); h(v, static_cast<std::uint64_t>(p.y)); }
void h(std::uint64_t& v, const Affordance& a) {
    h(v,a.id);h(v,a.instance);h(v,a.a);h(v,a.b);h(v,a.facing);h(v,static_cast<unsigned>(a.family));
    h(v,a.required);h(v,std::bit_cast<std::uint64_t>(a.strength));h(v,a.tag);
}
std::uint64_t request_hash(const Request& r) {
    std::uint64_t d=offset;
    h(d,static_cast<unsigned>(r.gentek));h(d,r.version);h(d,definition(r.gentek));h(d,r.source_identity);
    h(d,r.seed);h(d,r.fixture);h(d,static_cast<std::uint64_t>(r.width));h(d,static_cast<std::uint64_t>(r.height));h(d,r.origin);
    for(const auto* v:{&r.eligible,&r.protected_void,&r.transition,&r.neighbors.protected_geometry,&r.neighbors.transition}) {
        h(d,v->size());for(auto x:*v)h(d,x);
    }
    for(const auto* v:{&r.context,&r.neighbor_cells}){h(d,v->size());for(auto x:*v)h(d,static_cast<unsigned>(x));}
    h(d,r.activation.size());for(auto p:r.activation)h(d,p);
    h(d,r.neighbors.hard.size());for(const auto& a:r.neighbors.hard)h(d,a);
    h(d,r.neighbors.soft.size());for(const auto& a:r.neighbors.soft){h(d,a.point);h(d,a.direction);h(d,std::bit_cast<std::uint64_t>(a.strength));h(d,a.preference);}
    h(d,r.profile.name);
    for(auto x:{r.profile.variation,r.profile.irregularity,r.profile.clutter,r.profile.destruction,
                r.profile.branching,r.profile.environment_affinity,r.profile.cohesion})h(d,std::bit_cast<std::uint64_t>(x));
    const auto& l=r.limits;
    for(std::uint64_t n:{l.max_instances,l.max_frontier,l.max_candidates,l.max_connectors_per_instance,
                         l.max_affordances,l.max_cohesion_patches,l.max_cohesion_cells_per_patch})h(d,n);
    h(d,l.max_work);h(d,l.max_solver_work);h(d,l.max_bytes);return d;
}
}
const char* name(Kind k) noexcept {
    switch(k){case Kind::Frameweaver:return "FRAMEWEAVER";case Kind::Mosaic:return "MOSAIC";case Kind::Receptor:return "RECEPTOR";}return "INVALID";
}
const char* name(Status s) noexcept {
    switch(s){case Status::Complete:return "complete";case Status::Blocked:return "blocked";case Status::Exhausted:return "exhausted";
    case Status::Unsat:return "unsat";case Status::Invalid:return "invalid";case Status::Damaged:return "damaged";}return "invalid";
}
const char* name(Family f) noexcept {
    switch(f){case Family::Frame:return "frame";case Family::Brace:return "brace";case Family::Surface:return "surface";case Family::Passage:return "passage";}return "invalid";
}
std::string definition(Kind k) {
    // Algorithm identity plus a content fingerprint of the compiled research
    // definition inputs. The execution manifest separately records exact Git SHA.
    switch(k){case Kind::Frameweaver:return "frameweaver.frontier-growth-v0." GENTEK_DEFINITION_SHA256;
    case Kind::Mosaic:return "mosaic.prepared-regions-v0." GENTEK_DEFINITION_SHA256;
    case Kind::Receptor:return "receptor.surface-field-v0." GENTEK_DEFINITION_SHA256;}return "invalid";
}
std::uint64_t mix(std::uint64_t v) noexcept {
    v+=0x9e3779b97f4a7c15ULL;v=(v^(v>>30U))*0xbf58476d1ce4e5b9ULL;
    v=(v^(v>>27U))*0x94d049bb133111ebULL;return v^(v>>31U);
}
double unit(std::uint64_t v) noexcept {return static_cast<double>(mix(v)>>11U)*0x1.0p-53;}
std::string hex(std::uint64_t v){std::ostringstream o;o<<std::hex<<std::setw(16)<<std::setfill('0')<<v;return o.str();}
bool inside(const Request& r,Point p) noexcept{return p.x>=0&&p.y>=0&&p.x<r.width&&p.y<r.height;}
std::size_t index(const Request& r,Point p) noexcept{return static_cast<std::size_t>(p.y)*static_cast<std::size_t>(r.width)+static_cast<std::size_t>(p.x);}
bool allowed(const Request& r,Point p) noexcept {
    if(!inside(r,p))return false;
    const auto i=index(r,p);
    return (r.eligible.empty()||r.eligible[i])&&(r.protected_void.empty()||!r.protected_void[i])&&
        (r.context.empty()||r.context[i]==Material::Empty)&&(r.neighbor_cells.empty()||r.neighbor_cells[i]==Material::Empty)&&
        (r.neighbors.protected_geometry.empty()||!r.neighbors.protected_geometry[i]);
}
bool transition_at(const Request& r,Point p) noexcept{return inside(r,p)&&!r.transition.empty()&&r.transition[index(r,p)]!=0;}
bool validate_request(const Request& r,std::string& reason) {
    auto fail=[&](const std::string& s){reason=s;return false;};
    if(r.width<1||r.height<1||r.width>256||r.height>128)return fail("territory must be within 256x128");
    if(r.gentek!=Kind::Frameweaver&&r.gentek!=Kind::Mosaic&&r.gentek!=Kind::Receptor)return fail("unknown Gentek");
    if(r.version!=0)return fail("only explicit experimental version 0 is admitted");
    if(!r.definition_fingerprint.empty()&&r.definition_fingerprint!=definition(r.gentek))return fail("definition fingerprint mismatch");
    if(r.source_identity.size()>128||r.fixture.size()>96||r.profile.name.size()>96)return fail("identity too long");
    if(std::abs(static_cast<std::int64_t>(r.origin.x))>1'000'000||std::abs(static_cast<std::int64_t>(r.origin.y))>1'000'000)return fail("origin outside research bound");
    const auto n=static_cast<std::size_t>(r.width)*static_cast<std::size_t>(r.height);
    for(const auto* v:{&r.eligible,&r.protected_void,&r.transition,&r.neighbors.protected_geometry,&r.neighbors.transition}) {
        if(!v->empty()&&v->size()!=n)return fail("mask length mismatch");
        if(std::any_of(v->begin(),v->end(),[](auto x){return x>1;}))return fail("mask must be binary");
    }
    for(const auto* v:{&r.context,&r.neighbor_cells}){
        if(!v->empty()&&v->size()!=n)return fail("material mask length mismatch");
        if(std::any_of(v->begin(),v->end(),[](auto m){return static_cast<unsigned>(m)>131U||static_cast<unsigned>(m)==10U;}))return fail("invalid existing material ID");
    }
    for(auto x:{r.profile.variation,r.profile.irregularity,r.profile.clutter,r.profile.destruction,
                r.profile.branching,r.profile.environment_affinity,r.profile.cohesion})
        if(!std::isfinite(x)||x<0||x>1)return fail("parameter must be finite and normalized");
    const auto& l=r.limits;
    if(l.max_instances>256||l.max_frontier>512||l.max_candidates>65536||l.max_connectors_per_instance>8||
       l.max_affordances>256||l.max_cohesion_patches>8||l.max_cohesion_cells_per_patch>512||
       l.max_work>64'000'000||l.max_solver_work>64'000'000||l.max_bytes>64*1024*1024)return fail("limit exceeds research ceiling");
    if(r.activation.size()>16)return fail("too many activation points");
    for(auto p:r.activation)if(!inside(r,p))return fail("activation outside finite territory");
    if(r.neighbors.hard.size()>l.max_affordances||r.neighbors.soft.size()>l.max_affordances)return fail("too many foreign affordances");
    for(const auto& a:r.neighbors.hard){
        if(!inside(r,a.a)||!inside(r,a.b)||std::abs(static_cast<std::int64_t>(a.facing.x))>1||std::abs(static_cast<std::int64_t>(a.facing.y))>1||
           !std::isfinite(a.strength)||a.strength<0||a.strength>1||a.tag.size()>96||static_cast<unsigned>(a.family)>3)return fail("invalid foreign hard affordance");
    }
    for(const auto& a:r.neighbors.soft)if(!inside(r,a.point)||!std::isfinite(a.strength)||a.strength<0||a.strength>1||
        std::abs(static_cast<std::int64_t>(a.direction.x))>1||std::abs(static_cast<std::int64_t>(a.direction.y))>1||a.preference.size()>96)return fail("invalid foreign soft affordance");
    // Conservative accounting covers input/output masks, fields, queued points,
    // bounded footprints/receipts and GEN-003's fixed 256KiB scratch. Reject before planning.
    const auto memory_bound=n*96+l.max_instances*8192ULL+512*1024ULL;
    if(memory_bound>l.max_bytes)return fail("capacity: conservative memory bound exceeds max_bytes");
    reason.clear();return true;
}
Result begin_result(const Request& r,const std::string& implementation) {
    Result o;o.gentek=r.gentek;o.implementation=implementation;o.definition_fingerprint=definition(r.gentek);
    o.source_identity=r.source_identity;o.seed=r.seed;o.width=r.width;o.height=r.height;
    std::string reason;
    if(!validate_request(r,reason)){o.status=reason.starts_with("capacity:")?Status::Exhausted:Status::Invalid;o.termination=reason;return o;}
    o.request_digest=request_hash(r);
    const auto n=static_cast<std::size_t>(r.width)*static_cast<std::size_t>(r.height);
    o.cells.assign(n,Material::Empty);o.roles.assign(n,Role::Empty);o.provenance.assign(n,0);
    o.boundary.protected_geometry=r.protected_void;o.boundary.transition=r.transition;
    o.metrics["conservative_memory_bound_bytes"]=n*96+r.limits.max_instances*8192ULL+512*1024ULL;
    if(r.limits.max_instances==0||r.limits.max_work==0||r.limits.max_candidates==0){o.status=Status::Exhausted;o.termination="zero planning capacity";}
    return o;
}
bool charge(const Request& r,Result& o,std::uint64_t amount) {
    if(o.status==Status::Invalid||o.status==Status::Exhausted)return false;
    if(o.work>r.limits.max_work||amount>r.limits.max_work-o.work){o.status=Status::Exhausted;o.termination="work budget exhausted";return false;}
    o.work+=amount;return true;
}
bool candidate(const Request& r,Result& o) {
    if(o.candidates>=r.limits.max_candidates){o.status=Status::Exhausted;o.termination="candidate budget exhausted";return false;}
    if(!charge(r,o))return false;
    ++o.candidates;return true;
}
bool write_cell(const Request& r,Result& o,Point p,Material m,Role role,std::uint32_t instance,bool join) {
    if(!allowed(r,p)||m==Material::Empty||static_cast<unsigned>(m)>131U||static_cast<unsigned>(m)==10U)return false;
    const auto i=index(r,p);
    if(i>=o.cells.size())return false;
    if(o.cells[i]!=Material::Empty)return join&&o.cells[i]==m&&o.roles[i]!=Role::Cohesion;
    o.cells[i]=m;o.roles[i]=role;o.provenance[i]=instance;return true;
}
std::vector<Point> line(Point a,Point b) {
    if(std::abs(static_cast<std::int64_t>(a.x)-b.x)>512||std::abs(static_cast<std::int64_t>(a.y)-b.y)>512)
        throw std::invalid_argument("line outside finite research geometry");
    std::vector<Point> points;points.push_back(a);
    const int dx=std::abs(b.x-a.x),dy=std::abs(b.y-a.y),sx=a.x<b.x?1:-1,sy=a.y<b.y?1:-1;
    int ix=0,iy=0;
    while(ix<dx||iy<dy){
        if(ix<dx&&(iy==dy||(1+2*ix)*dy<=(1+2*iy)*dx)){a.x+=sx;++ix;}
        else{a.y+=sy;++iy;}
        points.push_back(a);
    }return points;
}
void finish_result(const Request& r,Result& o) {
    if(o.cells.empty())return;
    const auto n=o.cells.size();
    o.protected_violations=0;o.illegal_overlaps=0;o.unresolved_joints=0;
    std::uint64_t occupied=0,eligible=0,cohesion=0,transition=0,structure=0;
    for(std::size_t i=0;i<n;++i){
        const Point p{static_cast<int>(i%static_cast<std::size_t>(r.width)),static_cast<int>(i/static_cast<std::size_t>(r.width))};
        eligible+=static_cast<unsigned>(allowed(r,p));
        if(o.cells[i]==Material::Empty)continue;
        ++occupied;
        if((!r.protected_void.empty()&&r.protected_void[i])||(!r.neighbors.protected_geometry.empty()&&r.neighbors.protected_geometry[i]))++o.protected_violations;
        if(!allowed(r,p))++o.illegal_overlaps;
        cohesion+=static_cast<unsigned>(o.roles[i]==Role::Cohesion);
        structure+=static_cast<unsigned>(o.roles[i]==Role::Structure||o.roles[i]==Role::Brace||o.roles[i]==Role::Transition);
        transition+=static_cast<unsigned>(transition_at(r,p));
    }
    std::vector<std::uint8_t> seen(n,0);std::vector<std::size_t> queue;queue.reserve(n);std::uint64_t components=0;
    for(std::size_t i=0;i<n;++i){
        if(seen[i]||o.cells[i]==Material::Empty)continue;
        ++components;queue.clear();queue.push_back(i);seen[i]=1;
        for(std::size_t at=0;at<queue.size();++at){const auto j=queue[at];
            const Point p{static_cast<int>(j%static_cast<std::size_t>(r.width)),static_cast<int>(j/static_cast<std::size_t>(r.width))};
            for(auto d:std::array<Point,4>{{{1,0},{-1,0},{0,1},{0,-1}}}){Point q{p.x+d.x,p.y+d.y};if(!inside(r,q))continue;const auto k=index(r,q);
                if(!seen[k]&&o.cells[k]!=Material::Empty){seen[k]=1;queue.push_back(k);}}
        }
    }
    std::uint64_t mandatory=0,fulfilled=0,optional=0,optional_used=0;
    for(const auto& c:o.connectors){if(c.required){++mandatory;if(c.fulfilled)++fulfilled;else ++o.unresolved_joints;}
        else{++optional;if(c.fulfilled)++optional_used;}}
    o.metrics["occupied_cells"]=occupied;o.metrics["eligible_cells"]=eligible;o.metrics["empty_eligible_cells"]=eligible>=occupied?eligible-occupied:0;
    o.metrics["connected_material_components"]=components;o.metrics["structural_cells"]=structure;o.metrics["cohesion_cells"]=cohesion;
    o.metrics["transition_cells"]=transition;o.metrics["instances"]=o.instances.size();o.metrics["mandatory_connectors"]=mandatory;
    o.metrics["fulfilled_mandatory_connectors"]=fulfilled;o.metrics["optional_connectors"]=optional;o.metrics["fulfilled_optional_connectors"]=optional_used;
    o.metrics["environment_attachments"]=std::count_if(o.attachments.begin(),o.attachments.end(),[](const auto& a){return !a.kind.starts_with("lost-")&&a.kind.find("environment")!=std::string::npos;});
    if(o.protected_violations||o.illegal_overlaps){o.status=Status::Invalid;o.termination="final geometry validation failed";}
    if(o.instances.size()>r.limits.max_instances||o.boundary.hard.size()>r.limits.max_affordances||o.boundary.soft.size()>r.limits.max_affordances||
       o.work>r.limits.max_work||o.candidates>r.limits.max_candidates||o.solver_work>r.limits.max_solver_work){o.status=Status::Invalid;o.termination="implementation exceeded declared limit";}
    o.material_digest=offset;h(o.material_digest,static_cast<std::uint64_t>(r.width));h(o.material_digest,static_cast<std::uint64_t>(r.height));
    for(auto m:o.cells)h(o.material_digest,static_cast<unsigned>(m));
    o.request_digest=request_hash(r);o.digest=offset;h(o.digest,o.request_digest);h(o.digest,o.material_digest);h(o.digest,o.implementation);
    h(o.digest,static_cast<unsigned>(o.status));h(o.digest,o.termination);h(o.digest,o.work);h(o.digest,o.candidates);h(o.digest,o.solver_work);
    for(std::size_t i=0;i<n;++i){h(o.digest,static_cast<unsigned>(o.roles[i]));h(o.digest,o.provenance[i]);}
    for(const auto& p:o.instances){h(o.digest,p.id);h(o.digest,p.kind);h(o.digest,p.origin);h(o.digest,static_cast<std::uint64_t>(p.orientation));h(o.digest,p.structural);h(o.digest,p.damaged);h(o.digest,p.reason);for(auto c:p.cells)h(o.digest,c);}
    for(const auto& c:o.connectors){h(o.digest,c.id);h(o.digest,c.instance);h(o.digest,static_cast<unsigned>(c.family));h(o.digest,c.a);h(o.digest,c.b);h(o.digest,c.facing);h(o.digest,c.required);h(o.digest,c.fulfilled);h(o.digest,c.counterpart);h(o.digest,c.state);}
    for(const auto& a:o.attachments){h(o.digest,a.instance);h(o.digest,a.point);h(o.digest,a.target);h(o.digest,a.kind);h(o.digest,a.reason);}
    for(const auto& a:o.boundary.hard)h(o.digest,a);
    for(const auto& a:o.boundary.soft){h(o.digest,a.point);h(o.digest,a.direction);h(o.digest,std::bit_cast<std::uint64_t>(a.strength));h(o.digest,a.preference);}
    for(const auto* mask:{&o.boundary.protected_geometry,&o.boundary.transition}){h(o.digest,mask->size());for(auto value:*mask)h(o.digest,value);}
    h(o.digest,static_cast<std::uint64_t>(o.backtracks));
    for(const auto& [k,v]:o.metrics){h(o.digest,k);h(o.digest,v);}for(const auto& [k,v]:o.rejected){h(o.digest,k);h(o.digest,v);}for(const auto& note:o.notes)h(o.digest,note);
}
void apply_damage(const Request& r,Result& o) {
    if(r.profile.destruction<=0||o.cells.empty()||o.status==Status::Invalid||o.status==Status::Unsat)return;
    const auto intact=o.material_digest;std::uint64_t removed=0;
    // Seeded finite clusters create contiguous loss independent of generation controls.
    for(std::size_t i=0;i<o.cells.size();++i){if(o.cells[i]==Material::Empty)continue;
        const auto x=i%static_cast<std::size_t>(r.width),y=i/static_cast<std::size_t>(r.width);
        if(unit(r.seed^mix((x/5)+131*(y/5))^0xd4a6eULL)<r.profile.destruction*0.5){o.cells[i]=Material::Empty;o.roles[i]=Role::Empty;o.provenance[i]=0;++removed;}
    }
    for(auto& p:o.instances){p.damaged=std::any_of(p.cells.begin(),p.cells.end(),[&](Point q){return !inside(r,q)||o.cells[index(r,q)]==Material::Empty;});}
    for(auto& c:o.connectors){
        const auto owner=std::find_if(o.instances.begin(),o.instances.end(),[&](const auto& p){return p.id==c.instance;});
        if((owner!=o.instances.end()&&owner->damaged)||!inside(r,c.a)||o.cells[index(r,c.a)]==Material::Empty){c.fulfilled=false;c.state="lost";}
    }
    for(auto& c:o.connectors)if(c.counterpart){const auto other=std::find_if(o.connectors.begin(),o.connectors.end(),[&](const auto& d){return d.id==c.counterpart;});
        if(other!=o.connectors.end()&&other->state=="lost"){c.fulfilled=false;c.state="lost";}}
    const auto damaged_owner=[&](std::uint32_t id){const auto p=std::find_if(o.instances.begin(),o.instances.end(),[&](const auto& part){return part.id==id;});return p==o.instances.end()||p->damaged;};
    o.boundary.hard.erase(std::remove_if(o.boundary.hard.begin(),o.boundary.hard.end(),[&](const auto& a){return damaged_owner(a.instance)||!inside(r,a.a)||!inside(r,a.b)||o.cells[index(r,a.a)]==Material::Empty||o.cells[index(r,a.b)]==Material::Empty;}),o.boundary.hard.end());
    for(auto& a:o.attachments)if(damaged_owner(a.instance)){a.kind="lost-"+a.kind;a.reason="damage revoked attachment; intact receipt: "+a.reason;++o.metrics["damage_lost_attachments"];}
    o.metrics["intact_material_digest_u64"]=intact;o.metrics["damage_removed_cells"]=removed;
    o.notes.emplace_back("Damage is a separate post-assembly derivative; support validity is revoked on affected instances.");
    if(o.status!=Status::Exhausted){o.status=Status::Damaged;o.termination="independent damage derivative; inspect lost joints";}
}
Profile profile(const std::string& n) {
    Profile p;p.name=n;
    if(n=="sparse_regular"){p.variation=0.15;p.irregularity=0.05;p.clutter=0.05;p.branching=0.15;p.environment_affinity=0.25;p.cohesion=0;}
    else if(n=="branching_irregular"){}
    else if(n=="dense_cohesive"){p.variation=0.65;p.irregularity=0.45;p.clutter=0.8;p.branching=0.8;p.environment_affinity=1;p.cohesion=0.85;}
    else if(n=="damaged_derivative"){p=profile("branching_irregular");p.name=n;p.destruction=0.65;}
    else throw std::invalid_argument("unknown shared profile");
    return p;
}
Result generate(const Request& r) {
    Result o;
    switch(r.gentek){case Kind::Frameweaver:o=generate_frameweaver(r);break;case Kind::Mosaic:o=generate_mosaic(r);break;case Kind::Receptor:o=generate_receptor(r);break;default:return begin_result(r,"invalid");}
    finish_result(r,o);apply_damage(r,o);finish_result(r,o);return o;
}
} // namespace cybersand::gentek_swarm
