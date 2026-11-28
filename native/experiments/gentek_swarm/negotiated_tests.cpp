#include "negotiated.hpp"
#include <algorithm>
#include <array>
#include <iostream>
#include <set>
#include <stdexcept>
using namespace cybersand::gentek_swarm;
namespace {
void require(bool condition,const std::string& message){if(!condition)throw std::runtime_error(message);}
std::uint64_t metric(const NegotiatedResult& n,const std::string& k){const auto it=n.metrics.find(k);return it==n.metrics.end()?0:it->second;}
void safety(const NegotiatedResult& n) {
    require(n.frame.slots.size()<=max_transition_slots,"slot cap");
    for(const auto* k:{"protected_violations","illegal_overlaps","frozen_core_changes","mosaic_frozen_changes"})require(metric(n,k)==0,k);
    require(n.work<=2'000'000,"shared work bound");
    std::uint64_t limits=0;
    for(const auto& attempt:n.mosaic.attempts){limits+=attempt.work_limit;require(!attempt.work_observed||attempt.work<=attempt.work_limit,"attempt work");}
    require(limits<=n.mosaic_request.limits.max_solver_work,"aggregate solve ceiling");
    for(const auto& d:n.mosaic.domains)if(d.selected>=0)require((d.modified_domain&(1U<<d.selected))!=0,"selected outside effective domain");
    std::set<std::uint32_t> ids;
    for(const auto& slot:n.frame.slots){
        require(ids.insert(slot.id).second,"duplicate slot id");
        require(std::abs(slot.facing.x)+std::abs(slot.facing.y)==1,"noncardinal slot");
        for(auto p:line(slot.a,slot.b))require(inside(n.frame_request,p)&&n.frame.result.cells[index(n.frame_request,p)]!=cybersand::Material::Empty,"slot lacks actual frame material");
    }
    for(const auto& seam:n.seams)if(seam.joined){
        require(seam.cells.size()>=2&&seam.cells.size()<=16,"join length");
        require(seam.cells.front()==seam.a&&seam.cells.back()==seam.b,"join endpoints");
        const auto slot=std::find_if(n.frame.slots.begin(),n.frame.slots.end(),[&](const auto& s){return s.id==seam.left_affordance;});
        require(slot!=n.frame.slots.end(),"join slot absent");
        const auto response=std::find_if(n.mosaic.responses.begin(),n.mosaic.responses.end(),[&](const auto& r){return r.slot_id==slot->id;});
        require(response!=n.mosaic.responses.end()&&response->satisfied,"join response absent");
        require(Point{seam.cells[1].x-seam.a.x,seam.cells[1].y-seam.a.y}==slot->facing,"frame exit direction");
        const auto pen=seam.cells[seam.cells.size()-2];
        require(Point{pen.x-seam.b.x,pen.y-seam.b.y}==response->facing,"mosaic entry direction");
        for(std::size_t j=0;j<seam.cells.size();++j){
            const auto p=seam.cells[j];require(inside(n.frame_request,p),"out of bounds path");
            const auto i=index(n.frame_request,p);require(n.cells[i]!=cybersand::Material::Empty,"missing material path");
            require(n.control.fixture.transition[i]&&!n.control.fixture.protected_void[i],"illegal path mask");
            if(j)require(std::abs(p.x-seam.cells[j-1].x)+std::abs(p.y-seam.cells[j-1].y)==1,"noncardinal path");
        }
    }
    for(std::size_t i=0;i<n.cells.size();++i)if(n.cells[i]!=cybersand::Material::Empty)require(n.finished_cells[i]==n.cells[i],"RECEPTOR rewrote C");
    require(n.residual.connectors.empty(),"RECEPTOR acquired connector authority");
    for(const auto& i:n.residual.instances)require(!i.structural,"residual claimed structural support");
    require(n.residual.boundary.hard.empty(),"residual exported structural joints");
}
}
int main() {
    unsigned passed=0,failed=0;
    const auto test=[&](const char* name,const auto& fn){try{fn();++passed;std::cout<<"PASS "<<name<<'\n';}catch(const std::exception& e){++failed;std::cerr<<"FAIL "<<name<<": "<<e.what()<<'\n';}};
    test("six hostile fixtures, three profiles, two seeds, default and all-hard",[]{
        unsigned changed=0,joined=0;
        for(const auto& f:fixture_names())for(auto p:{"sparse_regular","branching_irregular","dense_cohesive"})for(auto seed:{605ULL,1701ULL})for(bool hard:{false,true}){
            const auto n=negotiate(fixture(f),profile(p),seed,"tests",false,hard);safety(n);
            changed+=metric(n,"causally_changed_tiles");joined+=metric(n,"joined_slots");
        }
        require(changed>0,"no causal category changes in entire experiment");require(joined>0,"no actual negotiated joins");
    });
    test("deterministic replay and reversed reservation/evaluation order",[]{
        for(const auto& f:fixture_names()){
            const auto a=negotiate(fixture(f),profile("branching_irregular"),605,"replay");
            const auto b=negotiate(fixture(f),profile("branching_irregular"),605,"replay");
            const auto c=negotiate(fixture(f),profile("branching_irregular"),605,"replay",true);
            require(a.digest==b.digest&&a.cells==b.cells&&a.finished_cells==b.finished_cells,"replay changed");
            require(a.digest==c.digest&&a.cells==c.cells&&a.mosaic.categories==c.mosaic.categories,"reverse changed");
        }
    });
    test("no-offer ablation has unmodified domains and legacy native output",[]{
        for(const auto& f:fixture_names()){
            const auto n=negotiate(fixture(f),profile("branching_irregular"),605,"ablation");
            const auto legacy=generate(n.mosaic_request);
            require(legacy.cells==n.no_offers.result.cells,"no-offer vocabulary drift");
            for(const auto& d:n.no_offers.domains)require(d.influences.empty()&&d.original_domain==d.modified_domain,"no-offer domain changed");
        }
    });
    test("RECEPTOR disabled leaves identical structural candidate",[]{
        for(const auto& f:fixture_names()){
            const auto a=negotiate(fixture(f),profile("dense_cohesive"),1701,"residual");
            const auto b=negotiate(fixture(f),profile("dense_cohesive"),1701,"residual",false,false,false);
            require(a.cells==b.cells&&a.final_frame.digest==b.final_frame.digest&&a.final_mosaic.digest==b.final_mosaic.digest,"residual influenced structure");
            require(b.cells==b.finished_cells,"disabled residual wrote cells");
        }
    });
    test("hard geometrically impossible offer is explicit UNSAT",[]{
        auto q=request_for(fixture("stepped_diagonal"),Kind::Mosaic,1,profile("branching_irregular"),605,"hard-negative");
        q.neighbor_cells.assign(q.eligible.size(),cybersand::Material::Empty);q.neighbor_cells[index(q,{10,10})]=cybersand::Material::SteelPlate;
        TransitionSlot s;s.id=1;s.instance=1;s.connector=1;s.a=s.b={10,10};s.facing={1,0};s.envelope={9,9,3,3};s.hard=true;
        const auto n=negotiate_mosaic(q,{s});require(n.result.status==Status::Unsat,"hard incompatible offer not UNSAT");
        require(std::none_of(n.result.cells.begin(),n.result.cells.end(),[](auto m){return m!=cybersand::Material::Empty;}),"UNSAT rasterized geometry");
    });
    test("GEN-003 bounded work exhaustion remains distinct",[]{
        auto q=request_for(fixture("stepped_diagonal"),Kind::Mosaic,1,profile("branching_irregular"),605,"budget");q.limits.max_solver_work=1;
        const auto n=negotiate_mosaic(q,{});require(n.result.status==Status::Exhausted,"budget not exhausted");
        require(std::none_of(n.result.cells.begin(),n.result.cells.end(),[](auto m){return m!=cybersand::Material::Empty;}),"exhaustion rasterized geometry");
    });
    test("slot capacity rejects oversized input",[]{
        auto q=request_for(fixture("stepped_diagonal"),Kind::Mosaic,1,profile("branching_irregular"),605,"capacity");
        std::vector<TransitionSlot> slots(max_transition_slots+1);for(std::size_t i=0;i<slots.size();++i){slots[i].id=i+1;slots[i].a=slots[i].b={50,50};slots[i].facing={1,0};slots[i].envelope={50,50,3,3};}
        const auto n=negotiate_mosaic(q,slots);require(n.result.status==Status::Invalid||n.result.status==Status::Exhausted,"excess slots accepted");
    });
    test("FRAMEWEAVER low capacity and invalid geometry are bounded",[]{
        for(auto budget:{0ULL,1ULL,100ULL}){
            auto a=request_for(fixture("island"),Kind::Frameweaver,0,profile("branching_irregular"),605,"frame-budget");
            auto b=request_for(fixture("island"),Kind::Mosaic,1,a.profile,605,"frame-budget");a.limits.max_work=budget;
            const auto n=plan_frameweaver(a,b);require(n.result.work<=budget,"frame work bound");require(n.slots.size()<=8,"frame slot bound");
        }
    });
    std::cout<<"NEGOTIATED TESTS "<<passed<<" passed, "<<failed<<" failed\n";return failed?1:0;
}
