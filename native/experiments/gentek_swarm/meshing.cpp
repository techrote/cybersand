#include "swarm.hpp"
#include <algorithm>
#include <array>
#include <bit>
#include <limits>
#include <set>
#include <tuple>

namespace cybersand::gentek_swarm {
namespace {
bool compatible(Family a,Family b) {
    if(a==Family::Passage||b==Family::Passage)return false;
    if(a==Family::Brace&&b==Family::Brace)return false;
    return a==Family::Frame||b==Family::Frame||a==Family::Surface||b==Family::Surface;
}
std::vector<Material> combine(const Fixture& f,const Result& a,const Result& b,std::uint32_t* conflicts=nullptr) {
    auto cells=f.context;
    for(std::size_t i=0;i<cells.size();++i){
        const auto x=i<a.cells.size()?a.cells[i]:Material::Empty,y=i<b.cells.size()?b.cells[i]:Material::Empty;
        if(conflicts&&((x!=Material::Empty&&y!=Material::Empty)||((x!=Material::Empty||y!=Material::Empty)&&cells[i]!=Material::Empty)))++*conflicts;
        if(x!=Material::Empty)cells[i]=x;
        if(y!=Material::Empty)cells[i]=y;
    }return cells;
}
Result clipped(Request r,const Fixture& f,int side) {
    const auto owned=r.eligible;
    for(int y=0;y<r.height;++y)for(int x=0;x<r.width;++x)r.eligible[index(r,{x,y})]=static_cast<std::uint8_t>(x>=3&&x<r.width-3&&y>=3&&y<r.height-3);
    r.transition.assign(r.transition.size(),0);
    auto o=generate(r);std::uint64_t removed=0;
    for(std::size_t i=0;i<o.cells.size();++i)if(!owned[i]&&o.cells[i]!=Material::Empty){o.cells[i]=Material::Empty;o.roles[i]=Role::Empty;o.provenance[i]=0;++removed;}
    for(auto& c:o.connectors)if(!inside(r,c.a)||!inside(r,c.b)||o.cells[index(r,c.a)]==Material::Empty||o.cells[index(r,c.b)]==Material::Empty){c.fulfilled=false;c.state="clipped";}
    o.boundary.hard.erase(std::remove_if(o.boundary.hard.begin(),o.boundary.hard.end(),[&](const auto& a){return !inside(r,a.a)||!inside(r,a.b)||f.side[index(r,a.a)]!=side||f.side[index(r,a.b)]!=side;}),o.boundary.hard.end());
    r.eligible=owned;r.transition=f.transition;o.metrics["clipped_removed_cells"]=removed;
    o.notes.emplace_back("CONTROL: independent full-territory assembly, then clipped to ownership; severed joins remain exposed.");
    finish_result(r,o);return o;
}
std::vector<Point> samples(const Affordance& a) {
    // At most 257 integer samples on one bounded finite segment.
    auto p=line(a.a,a.b);if(p.size()>257)p.resize(257);return p;
}
void adapt(const Request& r,Result& o) {
    if(o.status==Status::Invalid||o.status==Status::Unsat||o.status==Status::Exhausted)return;
    switch(r.gentek){case Kind::Frameweaver:adapt_frameweaver(r,o);break;case Kind::Mosaic:adapt_mosaic(r,o);break;case Kind::Receptor:adapt_receptor(r,o);break;}
}
bool structural_endpoint(const Request& r,const Result& o,Point p) {
    if(!inside(r,p))return false;
    const auto i=index(r,p);
    return i<o.cells.size()&&o.cells[i]!=Material::Empty&&o.roles[i]!=Role::Cohesion&&o.roles[i]!=Role::Detail;
}
void fulfill(Result& o,const Affordance& a,Point own,Point target) {
    // Offer and internal connector IDs are independent namespaces. Resolve only
    // a unique exact source geometry; never discharge an arbitrary same-ID joint.
    Connector* match=nullptr;unsigned count=0;
    for(auto& c:o.connectors)if(c.instance==a.instance&&c.family==a.family&&c.a==a.a&&c.b==a.b&&c.facing==a.facing){match=&c;++count;}
    if(count==1){match->fulfilled=true;match->state="joined-foreign";}
    o.attachments.push_back({a.instance,own,target,"foreign-typed-joint","validated material path between explicit compatible hard affordances"});
}
std::vector<std::vector<Point>> routes(Point a,Point b,Point af,Point bf) {
    const auto cardinal=[](Point d){return std::abs(d.x)+std::abs(d.y)==1;};
    if((af!=Point{}&&!cardinal(af))||(bf!=Point{}&&!cardinal(bf)))return {};
    if(std::abs(a.x-b.x)+std::abs(a.y-b.y)==1&&
       (af==Point{}||af==Point{b.x-a.x,b.y-a.y})&&
       (bf==Point{}||bf==Point{a.x-b.x,a.y-b.y}))return {{a,b}};
    const Point sa{a.x+af.x,a.y+af.y},sb{b.x+bf.x,b.y+bf.y};
    std::vector<std::vector<Point>> paths;
    for(int mode=0;mode<3;++mode){
        std::vector<Point> path;
        auto append=[&](Point from,Point to){for(auto p:line(from,to))if(path.empty()||p!=path.back())path.push_back(p);};
        append(a,sa);
        if(mode==0)append(sa,sb);
        else{const Point elbow=mode==1?Point{sb.x,sa.y}:Point{sa.x,sb.y};append(sa,elbow);append(elbow,sb);}
        append(sb,b);
        const std::set<Point> unique(path.begin(),path.end());
        if(unique.size()!=path.size()||path.size()>32||path.size()<2)continue;
        if(cardinal(af)&&Point{path[1].x-a.x,path[1].y-a.y}!=af)continue;
        if(cardinal(bf)&&Point{path[path.size()-2].x-b.x,path[path.size()-2].y-b.y}!=bf)continue;
        if(std::find(paths.begin(),paths.end(),path)==paths.end())paths.push_back(std::move(path));
    }return paths;
}
std::uint32_t next_id(const Result& r){std::uint32_t n=1;for(const auto& p:r.instances)n=std::max(n,p.id+1);return n;}
}
PairResult mesh(const Fixture& f,Kind ka,Kind kb,const Profile& p,std::uint64_t seed,const std::string& source,bool reverse) {
    PairResult out;out.fixture=f;out.left_request=request_for(f,ka,0,p,seed,source);out.right_request=request_for(f,kb,1,p,seed,source);
    // Fixed side ownership is declared in the fixture. Evaluation order has no authority.
    if(reverse){out.right=generate(out.right_request);out.left=generate(out.left_request);}
    else{out.left=generate(out.left_request);out.right=generate(out.right_request);}
    out.initial_left=out.left;out.initial_right=out.right;out.initial_cells=combine(f,out.left,out.right);
    out.clipped_left=clipped(out.left_request,f,0);out.clipped_right=clipped(out.right_request,f,1);
    out.clipped_cells=combine(f,out.clipped_left,out.clipped_right);
    auto lr=out.left_request,rr=out.right_request;
    lr.neighbors=out.initial_right.boundary;lr.neighbor_cells=out.initial_right.cells;
    rr.neighbors=out.initial_left.boundary;rr.neighbor_cells=out.initial_left.cells;
    if(reverse){adapt(rr,out.right);adapt(lr,out.left);}else{adapt(lr,out.left);adapt(rr,out.right);}
    // Freeze check: adapters may add only in their transition territory; never remove/rewrite core or any existing cell.
    for(std::size_t i=0;i<f.side.size();++i)for(auto pair:{std::pair<const Result*,Result*>{&out.initial_left,&out.left},{&out.initial_right,&out.right}}){
        if(pair.first->cells.empty()||pair.second->cells.empty())continue;
        if((!f.transition[i]||pair.first->cells[i]!=Material::Empty)&&pair.first->cells[i]!=pair.second->cells[i]){++out.conflicts;pair.second->status=Status::Invalid;pair.second->termination="adapter altered immutable core/accepted cell";}
    }
    struct Choice{std::size_t a{},b{};Point p{},q{};int distance{};};std::vector<Choice> choices;
    const auto& ah=out.left.boundary.hard;const auto& bh=out.right.boundary.hard;
    // Strict, separate shared negotiation ceiling: <=8192 offer-pair candidates,
    // <=2m segment comparisons and <=12 installed short joints. Exhaustion is retained.
    std::uint64_t candidate_count=0;bool exhausted=false;
    const auto shared_charge=[&](){if(out.work>=2'000'000){exhausted=true;return false;}++out.work;return true;};
    for(std::size_t a=0;a<ah.size()&&!exhausted;++a)for(std::size_t b=0;b<bh.size();++b){
        if(candidate_count>=8192){exhausted=true;break;}++candidate_count;
        if(!shared_charge())break;
        if(!compatible(ah[a].family,bh[b].family))continue;
        const auto ap=samples(ah[a]),bp=samples(bh[b]);Choice best{a,b,{},{},std::numeric_limits<int>::max()};
        for(auto u:ap){if(!transition_at(lr,u)||!structural_endpoint(lr,out.left,u))continue;
            for(auto v:bp){if(!shared_charge())break;if(!transition_at(rr,v)||!structural_endpoint(rr,out.right,v))continue;
                const int d=std::abs(u.x-v.x)+std::abs(u.y-v.y);if(d<1||d>26||d>=best.distance)continue;
                if(ah[a].facing.x*(v.x-u.x)+ah[a].facing.y*(v.y-u.y)<0||bh[b].facing.x*(u.x-v.x)+bh[b].facing.y*(u.y-v.y)<0)continue;
                best={a,b,u,v,d};}if(exhausted)break;}
        if(best.distance!=std::numeric_limits<int>::max())choices.push_back(best);
        if(exhausted)break;
    }
    std::sort(choices.begin(),choices.end(),[](const auto& a,const auto& b){return std::tie(a.distance,a.p,a.q,a.a,a.b)<std::tie(b.distance,b.p,b.q,b.a,b.b);});
    std::set<std::size_t> used_a,used_b;std::set<Point> used_points;
    for(const auto& c:choices){
        if(out.bridges+out.typed_contacts>=12||exhausted)break;
        if(used_a.contains(c.a)||used_b.contains(c.b)||used_points.contains(c.p)||used_points.contains(c.q))continue;
        Seam seam;seam.left_affordance=ah[c.a].id;seam.right_affordance=bh[c.b].id;seam.a=c.p;seam.b=c.q;
        if(out.left.instances.size()>=lr.limits.max_instances||out.right.instances.size()>=rr.limits.max_instances){seam.reason="instance capacity refuses joint";out.seams.push_back(seam);continue;}
        std::vector<Point> path;bool valid=false;
        for(auto proposed:routes(c.p,c.q,ah[c.a].facing,bh[c.b].facing)){
          bool admissible=true;
          for(auto q:proposed){if(!shared_charge()){admissible=false;break;}const auto i=index(lr,q);
            if(!inside(lr,q)){admissible=false;seam.reason="socket stub outside canvas";break;}
            if(!f.transition[i]||f.protected_void[i]||f.context[i]!=Material::Empty||
               (!out.left.boundary.protected_geometry.empty()&&out.left.boundary.protected_geometry[i])||
               (!out.right.boundary.protected_geometry.empty()&&out.right.boundary.protected_geometry[i])){admissible=false;seam.reason="protected/context/transition envelope rejects joint";break;}
            if(q!=c.p&&q!=c.q&&(out.left.cells[i]!=Material::Empty||out.right.cells[i]!=Material::Empty)){admissible=false;seam.reason="occupied path refuses implicit overlap";break;}
            if((f.side[i]==0&&!allowed(lr,q))||(f.side[i]==1&&!allowed(rr,q))){admissible=false;seam.reason="ownership or foreign protected geometry rejects joint";break;}
          }
          if(admissible){path=std::move(proposed);valid=true;break;}
          if(exhausted)break;
        }
        if(seam.reason.empty()&&!valid)seam.reason="no simple route respects exact socket facing";
        if(!valid){out.seams.push_back(std::move(seam));continue;}
        const auto aid=next_id(out.left),bid=next_id(out.right);
        Instance ai{aid,"typed-seam-joint",c.p,0,true,false,{},"canonical short bridge between two explicit hard affordances"};
        Instance bi{bid,"typed-seam-joint",c.q,0,true,false,{},"canonical short bridge between two explicit hard affordances"};
        const auto material=(ka==Kind::Frameweaver||kb==Kind::Frameweaver)?Material::SteelPlate:Material::IndustrialBrick;
        for(auto q:path){const auto i=index(lr,q);if(q==c.p||q==c.q)continue;
            if(f.side[i]==0){write_cell(lr,out.left,q,material,Role::Transition,aid);ai.cells.push_back(q);}
            else{write_cell(rr,out.right,q,material,Role::Transition,bid);bi.cells.push_back(q);}}
        if(!ai.cells.empty())out.left.instances.push_back(std::move(ai));
        if(!bi.cells.empty())out.right.instances.push_back(std::move(bi));
        fulfill(out.left,ah[c.a],c.p,c.q);fulfill(out.right,bh[c.b],c.q,c.p);
        seam.joined=true;seam.reason=path.size()>2?"new bridge: typed endpoints + exact socket exit/entry + clear bounded path":"adjacent typed contact: compatibility witness, zero new geometry";
        if(path.size()>2){++out.bridges;out.bridge_cells+=static_cast<std::uint32_t>(path.size()-2);}else ++out.typed_contacts;
        seam.cells=std::move(path);
        out.seams.push_back(std::move(seam));used_a.insert(c.a);used_b.insert(c.b);used_points.insert(c.p);used_points.insert(c.q);
    }
    if(exhausted){Seam s;s.reason="shared negotiation budget exhausted; unexamined possibilities remain unresolved";out.seams.push_back(s);}
    // Each unused transition hard offer is an explicit residual, even if optional.
    for(std::size_t i=0;i<ah.size();++i)if(!used_a.contains(i)&&transition_at(lr,ah[i].a))++out.unresolved_seams;
    for(std::size_t i=0;i<bh.size();++i)if(!used_b.contains(i)&&transition_at(rr,bh[i].a))++out.unresolved_seams;
    out.left.metrics["shared_negotiation_candidates"]=candidate_count;out.right.metrics["shared_negotiation_candidates"]=candidate_count;
    out.left.metrics["shared_negotiation_exhausted"]=exhausted;out.right.metrics["shared_negotiation_exhausted"]=exhausted;
    out.left.metrics["foreign_bridges"]=out.bridges;out.right.metrics["foreign_bridges"]=out.bridges;
    out.left.metrics["foreign_adjacent_contacts"]=out.typed_contacts;out.right.metrics["foreign_adjacent_contacts"]=out.typed_contacts;
    out.left.metrics["foreign_bridge_cells"]=out.bridge_cells;out.right.metrics["foreign_bridge_cells"]=out.bridge_cells;
    finish_result(lr,out.left);finish_result(rr,out.right);out.left_request=std::move(lr);out.right_request=std::move(rr);
    out.cells=combine(f,out.left,out.right,&out.conflicts);
    for(std::size_t i=0;i<out.cells.size();++i)if(f.protected_void[i]&&out.cells[i]!=Material::Empty)++out.protected_violations;
    out.digest=mix(out.left.digest^std::rotl(out.right.digest,17)^f.digest^out.work^out.bridges^out.unresolved_seams^mix(out.typed_contacts)^mix(out.bridge_cells));
    return out;
}
} // namespace cybersand::gentek_swarm
