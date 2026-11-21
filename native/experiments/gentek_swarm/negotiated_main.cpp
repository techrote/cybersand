#include "negotiated.hpp"
#include <filesystem>
#include <iostream>
#include <stdexcept>
using namespace cybersand::gentek_swarm;
int main(int argc,char** argv)try {
    if(argc<3||argc>4)throw std::invalid_argument("usage: gentek_negotiated OUTPUT SOURCE [quick]");
    const std::filesystem::path out=argv[1];const std::string source=argv[2];const bool quick=argc==4;
    std::filesystem::create_directories(out);
    unsigned count=0,violations=0;
    for(const auto& f:fixture_names())for(const auto* p:{"sparse_regular","branching_irregular","dense_cohesive"})
        for(auto seed:{605ULL,1701ULL})for(bool hard:{false,true}) {
            if(quick&&(std::string(p)!="branching_irregular"||seed!=605||hard))continue;
            auto n=negotiate(fixture(f),profile(p),seed,source,false,hard);
            const auto file="negotiated_"+f+"_"+p+"_"+std::to_string(seed)+(hard?"_hard":"_mixed")+".json";
            write_negotiated_json((out/file).string(),n);++count;
            violations+=n.metrics["protected_violations"]+n.metrics["illegal_overlaps"]+n.metrics["frozen_core_changes"]+n.metrics["mosaic_frozen_changes"];
            std::cout<<file<<" slots="<<n.frame.slots.size()<<" admitted="<<n.metrics["admitted_slots"]<<" causal_tiles="<<n.metrics["causally_changed_tiles"]
                     <<" joined="<<n.metrics["joined_slots"]<<" posthoc="<<n.metrics["control_posthoc_cells"]<<"->"<<n.metrics["candidate_posthoc_cells"]
                     <<" status="<<name(n.mosaic.result.status)<<'\n';
        }
    std::cout<<"NEGOTIATED cases="<<count<<" hard_violations="<<violations<<'\n';return violations?1:0;
}catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 2;}
