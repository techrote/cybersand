#include "swarm.hpp"
#include "cybersand/generation_spatial.hpp"
#include <algorithm>
#include <array>
#include <cmath>
#include <functional>
#include <iostream>
#include <limits>
#include <map>
#include <stdexcept>

using namespace cybersand;
using namespace cybersand::gentek_swarm;
namespace {
int passed=0,failed=0;
void require(bool value,const std::string& message){if(!value)throw std::runtime_error(message);}
void test(const std::string& name,const std::function<void()>& fn){try{fn();++passed;std::cout<<"PASS "<<name<<'\n';}catch(const std::exception& e){++failed;std::cerr<<"FAIL "<<name<<": "<<e.what()<<'\n';}}
void valid(const Request& q,const Result& r){
    require(r.status!=Status::Invalid,"invalid normal result: "+r.termination);
    require(r.protected_violations==0&&r.illegal_overlaps==0,"hard geometry violation");
    require(r.work<=q.limits.max_work&&r.candidates<=q.limits.max_candidates&&r.solver_work<=q.limits.max_solver_work,"work ceiling exceeded");
    require(r.instances.size()<=q.limits.max_instances,"instance ceiling exceeded");
    require(r.boundary.hard.size()<=q.limits.max_affordances&&r.boundary.soft.size()<=q.limits.max_affordances,"affordance ceiling exceeded");
    std::map<std::uint32_t,std::uint32_t> connector_counts;
    for(const auto& c:r.connectors)require(++connector_counts[c.instance]<=q.limits.max_connectors_per_instance,"connector per-part ceiling exceeded");
    for(std::size_t i=0;i<r.cells.size();++i){
        if(r.cells[i]==Material::Empty)continue;
        Point p{static_cast<int>(i%static_cast<std::size_t>(q.width)),static_cast<int>(i/static_cast<std::size_t>(q.width))};
        require(allowed(q,p),"output escapes admitted mask");
        require(r.provenance[i]!=0&&r.roles[i]!=Role::Empty,"occupied cell lacks provenance");
        const auto it=std::find_if(r.instances.begin(),r.instances.end(),[&](const auto& part){return part.id==r.provenance[i];});
        require(it!=r.instances.end(),"cell points to missing instance");
        if(r.roles[i]==Role::Cohesion)require(!it->structural,"cohesion falsely structural");
    }
}
constexpr std::array kinds{Kind::Frameweaver,Kind::Mosaic,Kind::Receptor};
}
int main(){
    test("fixture stability and genuinely irregular interfaces",[]{
        std::map<std::string,std::uint64_t> hashes;
        for(const auto& fn:fixture_names()){
            const auto a=fixture(fn),b=fixture(fn);require(a.digest==b.digest&&a.side==b.side&&a.context==b.context,"unstable fixture");
            require(std::count(a.side.begin(),a.side.end(),0)>0&&std::count(a.side.begin(),a.side.end(),1)>0,"missing territory");
            require(std::count(a.transition.begin(),a.transition.end(),1)>0,"no transition band");
            for(const auto& [id,d]:hashes)require(a.digest!=d,"aliased fixtures "+id);
            hashes[fn]=a.digest;
        }
        const auto corridor=fixture("protected_corridor");
        for(int x=0;x<corridor.width;++x){bool open=false;for(int y=0;y<corridor.height;++y)open=open||corridor.protected_void[static_cast<std::size_t>(y*corridor.width+x)];require(open,"protected corridor does not cross canvas");}
    });
    for(auto kind:kinds){
        test(std::string(name(kind))+" replay, hostile masks and parameter profiles",[=]{
            for(const auto& fn:fixture_names())for(auto pn:{"sparse_regular","branching_irregular","dense_cohesive"})for(int side:{0,1}){
                const auto q=request_for(fixture(fn),kind,side,profile(pn),605,"test-source");
                const auto a=generate(q),b=generate(q);valid(q,a);valid(q,b);
                require(a.digest==b.digest&&a.cells==b.cells&&a.roles==b.roles&&a.provenance==b.provenance,"nondeterministic replay "+fn+pn);
            }
        });
        test(std::string(name(kind))+" bounded failures and malformed input",[=]{
            const auto base=request_for(fixture("free"),kind,-1,profile("dense_cohesive"),605,"test-source");
            for(int mode=0;mode<4;++mode){auto q=base;if(mode==0)q.limits.max_work=0;if(mode==1)q.limits.max_candidates=0;if(mode==2)q.limits.max_instances=0;if(mode==3)q.limits.max_bytes=1024;
                const auto r=generate(q);require(r.status==Status::Exhausted,"zero capacity not explicit exhaustion");require(r.work<=q.limits.max_work,"failure spent excess work");}
            for(int mode=0;mode<5;++mode){auto q=base;if(mode==0)q.profile.irregularity=std::numeric_limits<double>::quiet_NaN();if(mode==1)q.protected_void.resize(3);if(mode==2)q.width=257;if(mode==3)q.definition_fingerprint="wrong";if(mode==4)q.context[0]=static_cast<Material>(255);
                require(generate(q).status==Status::Invalid,"malformed request not refused");}
            auto q=base;q.eligible.assign(q.eligible.size(),0);const auto blocked=generate(q);valid(q,blocked);
            require(std::all_of(blocked.cells.begin(),blocked.cells.end(),[](auto c){return c==Material::Empty;}),"occupied in empty eligible territory");
            require(blocked.status==Status::Blocked||blocked.status==Status::Unsat,"no-space result incorrectly complete");
            q=base;q.protected_void.assign(q.protected_void.size(),1);const auto protected_result=generate(q);valid(q,protected_result);
            require(std::all_of(protected_result.cells.begin(),protected_result.cells.end(),[](auto c){return c==Material::Empty;}),"protected void overwritten");
        });
        test(std::string(name(kind))+" independent destruction derivative",[=]{
            auto q=request_for(fixture("free"),kind,-1,profile("branching_irregular"),605,"test-source");const auto intact=generate(q);
            q.profile.destruction=0.65;q.profile.name="damaged_derivative";const auto damaged=generate(q);valid(q,damaged);
            require(intact.instances.size()==damaged.instances.size(),"damage changed assembly topology before removal");
            for(std::size_t i=0;i<intact.instances.size();++i)require(intact.instances[i].cells==damaged.instances[i].cells&&intact.instances[i].kind==damaged.instances[i].kind,"damage changed intact provenance");
            require(damaged.cells!=intact.cells,"damage had no effect");
            for(std::size_t i=0;i<intact.cells.size();++i)require(damaged.cells[i]==intact.cells[i]||damaged.cells[i]==Material::Empty,"damage creates geometry");
            require(damaged.metrics.at("intact_material_digest_u64")==intact.material_digest,"intact source not retained");
            for(const auto& c:damaged.connectors)if(c.state=="lost")require(!c.fulfilled,"lost support still claimed joined");
            for(const auto& a:damaged.boundary.hard){const auto owner=std::find_if(damaged.instances.begin(),damaged.instances.end(),[&](const auto& p){return p.id==a.instance;});require(owner!=damaged.instances.end()&&!owner->damaged,"damaged receptor still published");}
        });
        test(std::string(name(kind))+" fixed territory parameter expression",[=]{
            const auto f=fixture("free");auto q=request_for(f,kind,-1,profile("sparse_regular"),605,"test-source");const auto sparse=generate(q);
            q.profile=profile("branching_irregular");const auto irregular=generate(q);q.profile=profile("dense_cohesive");const auto dense=generate(q);
            require(sparse.cells!=irregular.cells&&irregular.cells!=dense.cells,"profiles collapse to same architecture");
            require(sparse.width==dense.width&&sparse.height==dense.height,"profile secretly changes canvas scale");
        });
    }
    test("GEN-003 real UNSAT differs from exhausted search",[]{
        namespace sp=cybersand::generation::spatial;sp::RegionAssignment d;d.width=2;d.height=1;d.categories={11,22};
        for(auto& direction:d.adjacency){direction[0]=2;direction[1]=1;}d.domains={1,1};
        bool unsat=false,exhausted=false;try{const auto ignored=sp::PreparedRegions::compile(d,{4'000'000,sp::kRegionSolverScratchBytes});(void)ignored;}catch(const sp::RegionAssignmentUnsatisfiable&){unsat=true;}
        try{const auto ignored=sp::PreparedRegions::compile(d,{1,sp::kRegionSolverScratchBytes});(void)ignored;}catch(const sp::RegionAssignmentExhausted&){exhausted=true;}
        require(unsat&&exhausted,"donor failure semantics collapsed");
    });
    test("RECEPTOR zero affinity removes remote context attraction",[]{
        auto q=request_for(fixture("free"),Kind::Receptor,-1,profile("dense_cohesive"),605,"test-source");q.profile.environment_affinity=0;
        for(int y=0;y<q.height;++y)for(int x=0;x<q.width;++x)q.eligible[index(q,{x,y})]=static_cast<std::uint8_t>(x>=8&&x<88&&y>=20&&y<100);
        q.activation={{40,60}};const auto a=generate(q);
        for(int y=0;y<10;++y)for(int x=180;x<190;++x)q.context[index(q,{x,y})]=Material::Stone;
        const auto b=generate(q);require(a.cells==b.cells&&a.roles==b.roles,"zero-affinity output attracted by remote solids");
        require(a.attachments.empty()&&b.attachments.empty(),"zero-affinity environmental attachment");
    });
    test("semantic digest binds exported keep-clear and transition geometry",[]{
        const auto q=request_for(fixture("free"),Kind::Frameweaver,-1,profile("sparse_regular"),605,"test-source");
        const auto original=generate(q);auto changed=original;
        changed.boundary.protected_geometry[0]=1;finish_result(q,changed);
        require(changed.digest!=original.digest&&changed.material_digest==original.material_digest,"keep-clear contract omitted from semantic digest");
        changed=original;changed.boundary.transition[0]=1;finish_result(q,changed);
        require(changed.digest!=original.digest&&changed.material_digest==original.material_digest,"transition contract omitted from semantic digest");
    });
    for(auto kind:{Kind::Frameweaver,Kind::Receptor})test(std::string(name(kind))+" cohesion cannot certify or replace structure",[=]{
        auto q=request_for(fixture("free"),kind,-1,profile("dense_cohesive"),605,"test-source");q.profile.cohesion=0;const auto bare=generate(q);
        q.profile.cohesion=0.85;const auto filled=generate(q);valid(q,filled);
        require(filled.metrics.at("cohesion_cells")>0,"cohesion probe did not exercise actual fill");
        require(filled.unresolved_joints==bare.unresolved_joints&&filled.metrics.at("fulfilled_mandatory_connectors")==bare.metrics.at("fulfilled_mandatory_connectors"),"cosmetic fill altered mechanical qualification");
        for(const auto& part:bare.instances)if(part.structural){const auto same=std::find_if(filled.instances.begin(),filled.instances.end(),[&](const auto& p){return p.id==part.id;});require(same!=filled.instances.end()&&same->structural&&same->cells==part.cells&&same->kind==part.kind,"cohesion changed structural plan");}
    });
    for(std::size_t a=0;a<kinds.size();++a)for(std::size_t b=a+1;b<kinds.size();++b){
        test(std::string(name(kinds[a]))+" x "+name(kinds[b])+" pairwise safety, frozen cores and evaluation order",[=]{
            for(const auto& fn:fixture_names())for(auto seed:{605ULL,1701ULL}){
                const auto x=mesh(fixture(fn),kinds[a],kinds[b],profile("branching_irregular"),seed,"test-source");
                const auto y=mesh(fixture(fn),kinds[a],kinds[b],profile("branching_irregular"),seed,"test-source",true);
                require(x.digest==y.digest&&x.cells==y.cells,"pair depends on evaluation order "+fn);require(x.conflicts==0&&x.protected_violations==0,"meshing hard conflict "+fn);
                valid(x.left_request,x.left);valid(x.right_request,x.right);
                for(std::size_t i=0;i<x.fixture.side.size();++i){
                    if(!x.fixture.transition[i]){require(x.left.cells[i]==x.initial_left.cells[i],"left core changed");require(x.right.cells[i]==x.initial_right.cells[i],"right core changed");}
                    if(x.fixture.protected_void[i])require(x.cells[i]==Material::Empty,"joint crosses protected corridor");
                }
                for(const auto& s:x.seams)if(s.joined){
                    require(s.cells.size()>=2,"joint has no material witness");for(auto p:s.cells){const auto i=index(x.left_request,p);require(x.cells[i]!=Material::Empty,"claimed joint missing material");require(x.left.roles[i]!=Role::Cohesion&&x.right.roles[i]!=Role::Cohesion,"joint certified by cohesion");}
                    for(auto side:{0,1}){
                        const auto& owner=side==0?x.left:x.right;const auto id=side==0?s.left_affordance:s.right_affordance;
                        const auto offer=std::find_if(owner.boundary.hard.begin(),owner.boundary.hard.end(),[&](const auto& a){return a.id==id;});require(offer!=owner.boundary.hard.end(),"joint lost source offer");
                        const auto end=side==0?s.cells.front():s.cells.back();const auto next=side==0?s.cells[1]:s.cells[s.cells.size()-2];
                        if(offer->facing!=Point{})require(Point{next.x-end.x,next.y-end.y}==offer->facing,"joint exits socket sideways");
                        if(offer->required){const auto c=std::find_if(owner.connectors.begin(),owner.connectors.end(),[&](const auto& c){return c.instance==offer->instance&&c.family==offer->family&&c.a==offer->a&&c.b==offer->b&&c.facing==offer->facing;});require(c!=owner.connectors.end()&&c->fulfilled&&c->state=="joined-foreign","joined required offer did not resolve its exact connector");}
                    }
                }
            }
        });
    }
    std::cout<<"GENTEK_TESTS passed="<<passed<<" failed="<<failed<<'\n';return failed?1:0;
}
