#include "swarm.hpp"
#include <array>
#include <filesystem>
#include <iostream>
#include <stdexcept>

using namespace cybersand::gentek_swarm;
int main(int argc,char** argv)try{
    if(argc<3||argc>4)throw std::invalid_argument("usage: gentek_swarm OUTPUT_DIRECTORY EXACT_SOURCE_ID [quick]");
    const std::filesystem::path out=argv[1];const std::string source=argv[2];const bool quick=argc==4;
    std::filesystem::create_directories(out);
    const std::array kinds{Kind::Frameweaver,Kind::Mosaic,Kind::Receptor};
    const std::array profiles{"sparse_regular","branching_irregular","dense_cohesive","damaged_derivative"};
    const std::array solo_fixtures{"free","concave_intrusion","protected_corridor","foreign_solid"};
    std::uint32_t single_count=0,pair_count=0;std::uint64_t bridges=0,violations=0;
    for(auto kind:kinds)for(auto fn:solo_fixtures)for(auto pn:profiles){
        if(quick&&(std::string(fn)!="free"||std::string(pn)=="damaged_derivative"))continue;
        const auto f=fixture(fn);auto r=request_for(f,kind,std::string(fn)=="free"?-1:0,profile(pn),605,source);
        const auto result=generate(r);const auto file="single_"+std::string(name(kind))+"_"+fn+"_"+pn+".json";
        write_result_json((out/file).string(),r,result);++single_count;violations+=result.protected_violations+result.illegal_overlaps;
        std::cout<<file<<" "<<name(result.status)<<" cells="<<result.metrics.at("occupied_cells")<<" instances="<<result.instances.size()<<'\n';
    }
    for(auto kind:kinds)for(int affinity:{0,1}){
        auto r=request_for(fixture("foreign_solid"),kind,0,profile("dense_cohesive"),605,source);r.profile.environment_affinity=affinity;r.profile.name=affinity?"affinity_high":"affinity_zero";
        const auto result=generate(r);write_result_json((out/("single_"+std::string(name(kind))+"_foreign_solid_"+r.profile.name+".json")).string(),r,result);++single_count;
    }
    for(std::size_t a=0;a<kinds.size();++a)for(std::size_t b=a+1;b<kinds.size();++b)for(const auto& fn:fixture_names())
        for(auto pn:{"sparse_regular","branching_irregular","dense_cohesive"})for(auto seed:{605ULL,1701ULL}){
            if(quick&&(std::string(pn)!="branching_irregular"||seed!=605))continue;
            const auto result=mesh(fixture(fn),kinds[a],kinds[b],profile(pn),seed,source);
            const auto file="pair_"+std::string(name(kinds[a]))+"_"+name(kinds[b])+"_"+fn+"_"+pn+"_"+std::to_string(seed)+".json";
            write_pair_json((out/file).string(),result);++pair_count;bridges+=result.bridges;violations+=result.conflicts+result.protected_violations+result.left.illegal_overlaps+result.right.illegal_overlaps;
            std::cout<<file<<" bridges="<<result.bridges<<" unresolved="<<result.unresolved_seams<<" status="<<name(result.left.status)<<'/'<<name(result.right.status)<<'\n';
        }
    for(auto kind:kinds)for(const std::string failure:{"no_eligible_space","work_exhausted","memory_exhausted"}){
        auto r=request_for(fixture("free"),kind,-1,profile("branching_irregular"),605,source);r.fixture=failure;
        if(failure=="no_eligible_space")r.eligible.assign(r.eligible.size(),0);
        if(failure=="work_exhausted")r.limits.max_work=1;
        if(failure=="memory_exhausted")r.limits.max_bytes=1024;
        const auto result=generate(r);write_result_json((out/("failure_"+std::string(name(kind))+"_"+failure+".json")).string(),r,result);++single_count;
    }
    std::cout<<"EVIDENCE singles="<<single_count<<" pairs="<<pair_count<<" bridges="<<bridges<<" hard_violations="<<violations<<'\n';
    return violations?1:0;
}catch(const std::exception& e){std::cerr<<"GENTEK research error: "<<e.what()<<'\n';return 2;}
