// Evidence-only dispatcher. The frozen research generators and fixtures are not
// changed here; one preregistered request is executed and retained per process.
#include "swarm.hpp"
#include <algorithm>
#include <cctype>
#include <cmath>
#include <filesystem>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>

using namespace cybersand::gentek_swarm;
namespace {
Kind parse_kind(const std::string& text) {
    if(text=="FRAMEWEAVER")return Kind::Frameweaver;
    if(text=="MOSAIC")return Kind::Mosaic;
    if(text=="RECEPTOR")return Kind::Receptor;
    throw std::invalid_argument("unknown Gentek identity");
}
std::uint64_t integer(const std::string& text) {
    if(text.empty()||text.find_first_not_of("0123456789")!=std::string::npos)
        throw std::invalid_argument("expected unsigned decimal integer");
    std::size_t used=0;const auto value=std::stoull(text,&used);
    if(used!=text.size())throw std::invalid_argument("invalid integer suffix");
    return value;
}
std::uint64_t violations(const Result& result) {
    return static_cast<std::uint64_t>(result.protected_violations)+result.illegal_overlaps;
}
}
int main(int argc,char** argv)try {
    if(argc!=16)throw std::invalid_argument(
        "usage: corpus100 OUTPUT_JSON SOURCE_HEAD CASE_ID KIND RIGHT_KIND_OR_DASH FIXTURE PROFILE SEED SIDE MAX_WORK_OR_DASH MAX_BYTES_OR_DASH MAX_INSTANCES_OR_DASH EMPTY_ELIGIBLE AFFINITY_OR_DASH REVERSE_PAIR");
    const std::filesystem::path output=argv[1];const std::string source=argv[2],case_id=argv[3];
    if(source.size()!=40||source.find_first_not_of("0123456789abcdef")!=std::string::npos)
        throw std::invalid_argument("source must be an exact forty-character commit identity");
    if(case_id.empty()||case_id.size()>96||!std::all_of(case_id.begin(),case_id.end(),[](unsigned char c){return std::isalnum(c)||c=='_'||c=='-';}))
        throw std::invalid_argument("invalid registered case ID");
    if(std::filesystem::exists(output))throw std::invalid_argument("refusing to replace retained raw evidence");
    const auto kind=parse_kind(argv[4]);const std::string right=argv[5];
    const auto f=fixture(argv[6]);const auto p=profile(argv[7]);const auto seed=integer(argv[8]);
    const std::string side_text=argv[9],work=argv[10],bytes=argv[11],instances=argv[12],empty=argv[13],affinity=argv[14],reverse=argv[15];
    if(side_text!="-1"&&side_text!="0"&&side_text!="1")throw std::invalid_argument("invalid fixture side");
    if(empty!="0"&&empty!="1")throw std::invalid_argument("invalid empty-mask flag");
    if(reverse!="0"&&reverse!="1")throw std::invalid_argument("invalid reverse-pair flag");
    std::filesystem::create_directories(output.parent_path());
    if(right!="-") {
        if(work!="-"||bytes!="-"||instances!="-"||empty!="0"||affinity!="-")
            throw std::invalid_argument("pair overrides are unsupported by the frozen mesh API");
        if(side_text!="0")throw std::invalid_argument("pair ownership starts on side zero");
        const auto result=mesh(f,kind,parse_kind(right),p,seed,source,reverse=="1");
        write_pair_json(output.string(),result);
        std::uint64_t hard=result.conflicts+result.protected_violations;
        for(const auto* control:{&result.left,&result.right,&result.initial_left,&result.initial_right,&result.clipped_left,&result.clipped_right})hard+=violations(*control);
        std::cout<<case_id<<" pair "<<name(result.left.status)<<'/'<<name(result.right.status)
                 <<" bridges="<<result.bridges<<" hard_violations="<<hard<<'\n';
        return hard?1:0;
    }
    if(reverse!="0")throw std::invalid_argument("reverse evaluation is pair-only");
    auto request=request_for(f,kind,std::stoi(side_text),p,seed,source);
    if(work!="-")request.limits.max_work=integer(work);
    if(bytes!="-") {
        const auto value=integer(bytes);
        if(value>std::numeric_limits<std::size_t>::max())throw std::invalid_argument("byte limit exceeds host size type");
        request.limits.max_bytes=static_cast<std::size_t>(value);
    }
    if(instances!="-") {
        const auto value=integer(instances);
        if(value>std::numeric_limits<std::uint32_t>::max())throw std::invalid_argument("instance limit overflows");
        request.limits.max_instances=static_cast<std::uint32_t>(value);
    }
    if(empty=="1")std::fill(request.eligible.begin(),request.eligible.end(),0);
    if(affinity!="-") {
        std::size_t used=0;const double value=std::stod(affinity,&used);
        if(used!=affinity.size()||!std::isfinite(value)||value<0||value>1)
            throw std::invalid_argument("affinity must be finite and normalized");
        request.profile.environment_affinity=value;
    }
    const auto result=generate(request);write_result_json(output.string(),request,result);
    const auto hard=violations(result);
    std::cout<<case_id<<" single "<<name(result.status)<<" material="<<hex(result.material_digest)
             <<" hard_violations="<<hard<<'\n';
    return hard?1:0;
} catch(const std::exception& error) {
    std::cerr<<"CORPUS-100 evidence dispatcher: "<<error.what()<<'\n';return 2;
}
