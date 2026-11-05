// SOL-PASSIVE-VALUES-001: synthetic copied values, unchanged production header.
#include "cybersand/granular_contact_response.hpp"
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

namespace g = cybersand::gcr;
struct Case {
    std::string id;
    g::Body body;
    double available=20, scale=1, budget=20;
    std::vector<g::Bin> bins;
    bool null_bin=false;
    std::vector<const g::Bin*> pointers() const {
        if(null_bin) return {nullptr};
        std::vector<const g::Bin*> result;
        for(const auto& bin:bins) result.push_back(&bin);
        return result;
    }
};
static void vector_json(std::ostream& out,g::Vec v) { out<<'['<<v.x<<','<<v.y<<']'; }
static std::string encode(const Case& c,const g::Result& r,const g::CompoundWorkspace& w) {
    std::ostringstream out; out<<std::setprecision(17)<<std::boolalpha;
    out<<"{\"body\":{\"velocity\":";vector_json(out,c.body.velocity);
    out<<",\"com\":";vector_json(out,c.body.com);
    out<<",\"omega\":"<<c.body.omega<<",\"mass\":"<<c.body.mass<<",\"inertia\":"<<c.body.inertia<<",\"mu\":"<<c.body.mu<<"},\"available\":"<<c.available<<",\"capacity_scale\":"<<c.scale<<",\"base_budget\":"<<c.budget;
    out<<",\"null_bin\":"<<c.null_bin<<",\"input_bins\":[";
    for(std::size_t i=0;i<c.bins.size();++i) {
        const auto& b=c.bins[i];if(i)out<<',';
        out<<"{\"count\":"<<b.count<<",\"material_mask\":"<<b.material_mask<<",\"state_b_min\":"<<unsigned(b.state_b_min)<<",\"state_b_max\":"<<unsigned(b.state_b_max)<<",\"position_sum\":";vector_json(out,b.position_sum);
        out<<",\"normal\":";vector_json(out,b.normal);
        out<<",\"maximum_radius\":"<<b.maximum_radius<<",\"tangent_mean\":"<<b.tangent_mean<<",\"tangent_m2\":"<<b.tangent_m2<<",\"tangent_min\":"<<b.tangent_min<<",\"tangent_max\":"<<b.tangent_max<<'}';
    }
    out<<"],\"result\":{\"impulse\":";vector_json(out,r.impulse);
    out<<",\"normal_impulse\":";vector_json(out,r.normal_impulse);
    out<<",\"tangent_impulse\":";vector_json(out,r.tangent_impulse);
    out<<",\"raw_impulse\":";vector_json(out,r.raw_impulse);
    out<<",\"torque\":"<<r.torque<<",\"raw_torque\":"<<r.raw_torque<<",\"normal\":"<<r.normal<<",\"tangent\":"<<r.tangent<<",\"raw_normal\":"<<r.raw_normal<<",\"raw_tangent\":"<<r.raw_tangent<<",\"capacity\":"<<r.capacity<<",\"energy_before\":"<<r.energy_before<<",\"energy_after\":"<<r.energy_after<<",\"scale\":"<<r.scale<<",\"max_radius\":"<<r.max_radius;
    out<<",\"bins\":"<<r.bins<<",\"nodes\":"<<r.nodes<<",\"quadrature_clamps\":"<<r.quadrature_clamps<<",\"updates\":"<<r.updates<<",\"normal_cap_hits\":"<<r.normal_cap_hits<<",\"tangent_cap_hits\":"<<r.tangent_cap_hits<<",\"passive_rejected\":"<<r.passive_rejected<<"},\"nodes\":[";
    for(std::size_t i=0;i<r.nodes;++i) {
        const auto& n=w.contacts[i];if(i)out<<',';
        out<<"{\"position\":";vector_json(out,n.position);
        out<<",\"normal\":";vector_json(out,n.normal);
        out<<",\"weight\":"<<n.weight<<",\"capacity\":"<<n.capacity<<",\"jn\":"<<n.jn<<",\"jt\":"<<n.jt<<'}';
    }
    return out.str()+"]}";
}
int main(int argc,char** argv) {
    if(argc!=2) return 2;
    std::ifstream file(argv[1]);if(!file)return 3;
    std::vector<Case> cases;
    std::string line;
    while(std::getline(file,line)) {
        std::istringstream input(line);Case c;std::size_t bins=0;unsigned count=0,support=0,mode=0;
        g::Vec point,normal,support_normal;
        if(!(input>>c.id>>c.body.velocity.x>>c.body.velocity.y>>c.body.omega>>c.body.mass>>c.body.inertia>>c.body.mu>>c.available>>c.scale>>c.budget>>bins>>count>>point.x>>point.y>>normal.x>>normal.y>>support>>support_normal.x>>support_normal.y>>mode))return 4;
        if(bins>513 || count>1024 || support>1024 || mode>2)return 5;
        c.null_bin=mode==2;
        if(!c.null_bin)for(std::size_t i=0;i<bins;++i) {
            g::Bin bin;
            if(mode==1) {bin.add({0,-1},normal,c.body.com);bin.add({0,1},normal,c.body.com);}
            else for(unsigned j=0;j<count;++j)bin.add(point,normal,c.body.com);
            c.bins.push_back(bin);
        }
        if(support) {g::Bin bin;for(unsigned j=0;j<support;++j)bin.add({0,0},support_normal,c.body.com);c.bins.push_back(bin);}
        cases.push_back(c);
    }
    if(cases.size()!=25)return 6;
    const auto poison=std::find_if(cases.begin(),cases.end(),[](const Case& c){return c.id=="max-two-nodes";});
    if(poison==cases.end())return 7;
    std::cout<<"{\"registration\":\"SOL-PASSIVE-VALUES-001\",\"cases\":[";
    bool first=true;std::size_t equal=0;
    for(const auto& c:cases) {
        const auto pointers=c.pointers();g::CompoundWorkspace fresh{},second{},reused{};
        const auto result=g::solve_compound(c.body,pointers,fresh,c.available,c.scale,c.budget);
        const auto one=encode(c,result,fresh);
        const auto two=encode(c,g::solve_compound(c.body,pointers,second,c.available,c.scale,c.budget),second);
        const auto prior=poison->pointers();g::solve_compound(poison->body,prior,reused,poison->available,poison->scale,poison->budget);
        const auto three=encode(c,g::solve_compound(c.body,pointers,reused,c.available,c.scale,c.budget),reused);
        const bool same=one==two && one==three;equal+=same?1U:0U;
        if(!first)std::cout<<',';
        first=false;
        std::cout<<"{\"id\":\""<<c.id<<"\",\"replays_equal\":"<<(same?"true":"false")<<",\"observation\":"<<one<<'}';
    }
    std::cout<<"],\"replay_equal_cases\":"<<equal<<"}\n";
    return equal==cases.size()?0:8;
}
