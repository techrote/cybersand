#include "swarm.hpp"
#include <algorithm>
#include <array>
#include <limits>
#include <stdexcept>

namespace cybersand::gentek_swarm {
std::vector<std::string> fixture_names() {
    return {"stepped_diagonal","concave_intrusion","protected_corridor","foreign_solid","island","narrow_neck"};
}
Fixture fixture(const std::string& id) {
    const auto names=fixture_names();
    if(id!="free"&&std::find(names.begin(),names.end(),id)==names.end())throw std::invalid_argument("unknown fixture");
    Fixture f;f.id=id;
    const auto n=static_cast<std::size_t>(f.width*f.height);
    f.side.resize(n);f.protected_void.assign(n,0);f.transition.assign(n,0);f.context.assign(n,Material::Empty);
    for(int y=0;y<f.height;++y)for(int x=0;x<f.width;++x){
        const auto i=static_cast<std::size_t>(y*f.width+x);
        int frontier=60+(y/11)*7+((y/19)%2)*5;
        if(id=="concave_intrusion"||id=="foreign_solid")frontier=(y>=27&&y<=86)?48+std::abs(y-56)/2:123;
        if(id=="protected_corridor")frontier=72+(y/13)*7;
        bool left=x<frontier;
        if(id=="island")left=(x-96)*(x-96)/4+(y-56)*(y-56)<27*27;
        if(id=="narrow_neck")left=x<67||(x<137&&std::abs(y-56)<7)||(x<154&&x>126&&std::abs(y-56)<28);
        if(id=="free")left=true;
        f.side[i]=static_cast<std::uint8_t>(left?0:1);
        if(id=="protected_corridor") {
            const int cy=51+(x/24%3)*3;
            if(std::abs(y-cy)<=5)f.protected_void[i]=1;
        }
        if(id=="foreign_solid") {
            const int ridge=29+(x-54)/5;
            if((x>=54&&x<=145&&y>=ridge&&y<ridge+4)||(x>=113&&x<=118&&y>=32&&y<=96))f.context[i]=Material::Stone;
        }
    }
    // Finite Manhattan dilation of the actual ownership interface, not a straight stripe.
    std::vector<int> distance(n,std::numeric_limits<int>::max());std::vector<std::size_t> queue;queue.reserve(n);
    constexpr std::array<Point,4> dirs{{{1,0},{-1,0},{0,1},{0,-1}}};
    for(int y=0;y<f.height;++y)for(int x=0;x<f.width;++x){const auto i=static_cast<std::size_t>(y*f.width+x);
        for(auto d:dirs){const int xx=x+d.x,yy=y+d.y;if(xx<0||xx>=f.width||yy<0||yy>=f.height)continue;
            if(f.side[i]!=f.side[static_cast<std::size_t>(yy*f.width+xx)]){distance[i]=0;queue.push_back(i);break;}}
    }
    for(std::size_t at=0;at<queue.size();++at){const auto i=queue[at];if(distance[i]>=13)continue;
        const int x=static_cast<int>(i%static_cast<std::size_t>(f.width)),y=static_cast<int>(i/static_cast<std::size_t>(f.width));
        for(auto d:dirs){const int xx=x+d.x,yy=y+d.y;if(xx<0||xx>=f.width||yy<0||yy>=f.height)continue;
            const auto j=static_cast<std::size_t>(yy*f.width+xx);if(distance[j]>distance[i]+1){distance[j]=distance[i]+1;queue.push_back(j);}}
    }
    f.digest=mix(static_cast<std::uint64_t>(f.width*65536+f.height));
    for(std::size_t i=0;i<n;++i){f.transition[i]=static_cast<std::uint8_t>(distance[i]<=13);
        f.digest=mix(f.digest^mix(i)^f.side[i]^(static_cast<std::uint64_t>(f.protected_void[i])<<8U)^
                     (static_cast<std::uint64_t>(f.context[i])<<16U)^(static_cast<std::uint64_t>(f.transition[i])<<24U));}
    return f;
}
Request request_for(const Fixture& f,Kind k,int side,const Profile& p,std::uint64_t seed,const std::string& source) {
    Request r;r.gentek=k;r.fixture=f.id;r.seed=seed;r.source_identity=source;r.width=f.width;r.height=f.height;
    r.origin={-96,-56};r.profile=p;r.definition_fingerprint=definition(k);
    r.protected_void=f.protected_void;r.transition=f.transition;r.context=f.context;
    if(k==Kind::Mosaic)r.limits.max_instances=192; // fixed-pitch motifs, not 64 mechanical parts
    r.eligible.resize(f.side.size());
    for(int y=0;y<f.height;++y)for(int x=0;x<f.width;++x){const auto i=static_cast<std::size_t>(y*f.width+x);
        r.eligible[i]=static_cast<std::uint8_t>((side<0||f.side[i]==side)&&x>=3&&x<f.width-3&&y>=3&&y<f.height-3);}
    const Point desired{side==1?f.width*3/4:f.width/4,f.height/2};Point best=desired;int best_distance=std::numeric_limits<int>::max();
    for(int y=0;y<f.height;++y)for(int x=0;x<f.width;++x){Point q{x,y};if(!allowed(r,q))continue;
        const int distance=std::abs(x-desired.x)+std::abs(y-desired.y);
        if(distance<best_distance){best=q;best_distance=distance;}}
    r.activation.push_back(best);return r;
}
} // namespace cybersand::gentek_swarm
