#include "cybersand/liquid_solver_policy.hpp"
#include "cybersand/world.hpp"
#include <cstdint>
#include <iostream>
#include <optional>
#include <span>
#include <vector>

using namespace cybersand;

std::vector<std::int32_t> request(std::int32_t variant) {
    auto words = LiquidSolverPolicy::default_request();
    constexpr std::size_t water = 21U;
    words[water] = 3;
    words[water + 1U] = variant;
    const auto family_count_at = words.size() - 2U;
    words[family_count_at] = 1;
    words.insert(words.begin() + static_cast<std::ptrdiff_t>(family_count_at) + 1,
                 {3, 1, 2, 1, 32});
    return words;
}
WorldConfig cfg(std::int32_t variant) {
    WorldConfig c;
    auto words=request(variant);
    auto decoded=LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
    if(!decoded.accepted()) throw std::runtime_error("policy refused");
    c.liquid_solver_policy=*decoded.policy;
    c.worker_threads=1;
    c.sleep_after_quiet_ticks=3;
    c.chunk_size=8; c.activity_block_size=8; c.scheduling_core_size=8;
    c.parallel_job_threshold=1;
    return c;
}
void rect(World& w, std::int64_t x, std::int64_t y, std::int64_t width, std::int64_t height, Material m) {
    for(auto yy=y;yy<y+height;++yy) for(auto xx=x;xx<x+width;++xx) {
        if(m==Material::Water) {
            if(!w.set_cell_state(xx,yy,Material::Water,w.config().water_experiment_policy.maximum(),0))
                throw std::runtime_error("water fill");
        } else if(m==Material::Empty) {
            (void)w.set_cell_state(xx,yy,Material::Empty,0,0);
        } else w.set(xx,yy,m);
    }
}
void rooms(World& w) {
    w.reserve_region({0,0,88,8});
    for(const auto offset:{0,64}) {
        rect(w,offset,0,24,8,Material::Wall);
        rect(w,offset+9,2,13,3,Material::Empty);
        rect(w,offset+1,3,8,1,Material::Water);
    }
    w.set_simulation_region(RectI64{0,0,8,8});
}
int main(){
    World ref(cfg(0)), opt(cfg(1));
    rooms(ref); rooms(opt);
    for(int t=0;t<12;++t) {
        auto m=(t%2)==0?Material::Empty:Material::Wall;
        ref.set(20,1,m); opt.set(20,1,m);
        (void)ref.tick(); (void)opt.tick();
        const auto same=ref.physical_state_hash()==opt.physical_state_hash();
        std::cout<<"tick="<<(t+1)<<" same="<<same
                 <<" ref_relabel="<<ref.pressure_optimization_snapshot().counters.gas_relabel_cells
                 <<" opt_relabel="<<opt.pressure_optimization_snapshot().counters.gas_relabel_cells<<"\n";
        if(!same) {
            int diffs=0;
            for(std::int64_t y=0;y<8;++y) for(std::int64_t x=0;x<88;++x) {
                const auto rm=ref.stored_material(x,y), om=opt.stored_material(x,y);
                const auto ra=ref.stored_state_a(x,y), oa=opt.stored_state_a(x,y);
                const auto rb=ref.stored_state_b(x,y), ob=opt.stored_state_b(x,y);
                const auto rp=ref.pressure_cell(x,y), op=opt.pressure_cell(x,y);
                if(rm!=om || ra!=oa || rb!=ob || rp.overfill!=op.overfill || rp.flow!=op.flow || rp.gas!=op.gas) {
                    std::cout<<"DIFF x="<<x<<" y="<<y
                             <<" mat="<<static_cast<int>(rm)<<"/"<<static_cast<int>(om)
                             <<" a="<<ra<<"/"<<oa<<" b="<<static_cast<int>(rb)<<"/"<<static_cast<int>(ob)
                             <<" over="<<rp.overfill<<"/"<<op.overfill
                             <<" flow="<<rp.flow<<"/"<<op.flow
                             <<" gas="<<rp.gas<<"/"<<op.gas<<"\n";
                    if(++diffs>=40) break;
                }
            }
            const auto a=ref.save_physical_state(), b=opt.save_physical_state();
            std::size_t first=0; while(first<a.size() && first<b.size() && a[first]==b[first]) ++first;
            std::cout<<"save_size="<<a.size()<<"/"<<b.size()<<" first_byte_diff="<<first;
            if(first<a.size()&&first<b.size()) std::cout<<" bytes="<<static_cast<unsigned>(a[first])<<"/"<<static_cast<unsigned>(b[first]);
            std::cout<<"\n";
            return 2;
        }
    }
    return 0;
}
