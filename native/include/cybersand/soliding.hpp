#pragma once
// Issue12 opt-in observer. Construct once per World/registered patch. No worker calls.
#include "cybersand/world.hpp"
#include "cybersand/material_rules.hpp"
#include <algorithm>
#include <array>
#include <stdexcept>
#include <limits>

namespace cybersand::soliding {
inline constexpr std::size_t max_cells = 1024, max_members = 256, max_components = 16, max_shapes = 64;
struct Member { std::int16_t x=0,y=0; friend bool operator==(const Member&,const Member&)=default; };
struct Shape { std::int16_t x=0,y=0,w=0,h=0; };
struct Candidate {
    std::uint32_t id=0;
    std::uint64_t revision=0;
    Material material=Material::Empty;
    std::uint32_t area=0, rest_ticks=0, supported=0, exposed=0;
    std::int16_t min_x=32,min_y=32,max_x=0,max_y=0;
    bool clipped=false, capacity=false, cohesive=false;
    std::array<Member,max_members> members{};
    std::array<Shape,max_shapes> shapes{};
    std::size_t shape_count=0;
    [[nodiscard]] double occupancy() const noexcept {
        return area ? double(area)/double((max_x-min_x+1)*(max_y-min_y+1)) : 0.;
    }
    [[nodiscard]] bool eligible(unsigned rest=120,double packing=.9,unsigned minimum=16) const noexcept {
        return cohesive && !clipped && !capacity && supported>0 && area>=minimum &&
               rest_ticks>=rest && occupancy()>=packing;
    }
};
struct Metrics {
    std::uint64_t observations=0,witness_cells=0,geometry_cells=0,rebuilds=0,invalidations=0,births=0;
    std::uint64_t excluded=0,gaps=0,failed=0,saturations=0,topology_changes=0,support_changes=0;
    std::size_t component_high_water=0,member_high_water=0,shape_high_water=0;
};
class Observer {
    struct Sample {
        std::uint64_t revision=0;
        std::uint16_t a=0,body=0;
        std::int16_t temperature=0;
        Material material=Material::Empty;
        std::uint8_t b=0;
        bool active=false,changed=false,included=false;
        friend bool operator==(const Sample&,const Sample&)=default;
    };
    RectI64 patch_;
    std::array<Sample,36*36> previous_{};
    std::array<std::uint16_t,max_cells> labels_{};
    std::array<std::uint16_t,max_cells> queue_{};
    std::array<Candidate,max_components> candidates_{};
    std::uint64_t generation_=0,last_tick_=0,revision_=0,mask_revision_=0;
    std::size_t count_=0;
    bool initialized_=false;
    Metrics metrics_{};
public:
    explicit Observer(RectI64 patch):patch_(patch) {
        if(patch.width<1||patch.height<1||patch.width>32||patch.height>32 ||
           patch.x < -1'000'000'000 || patch.y < -1'000'000'000 ||
           patch.x > 1'000'000'000 || patch.y > 1'000'000'000)
            throw std::invalid_argument("soliding patch outside registered bounds");
    }
    [[nodiscard]] RectI64 patch() const noexcept{return patch_;}
    [[nodiscard]] const Metrics& metrics()const noexcept{return metrics_;}
    [[nodiscard]] std::span<const Candidate> candidates()const noexcept{return {candidates_.data(),count_};}
    void observe(const World& world) {
        ++metrics_.observations;
        const auto tick=world.completed_tick_index();
        const bool generation_changed=generation_!=world.observation_generation();
        const bool gap=initialized_ && (generation_changed || (tick!=last_tick_ && tick!=last_tick_+1));
        bool changed=!initialized_||generation_changed||mask_revision_!=world.observation_mask_revision();
        bool included=true, activity=false, occupied=world.observation_mask_revision()==UINT64_MAX;
        const int stride=static_cast<int>(patch_.width)+4;
        for(int y=-2;y<patch_.height+2;++y)for(int x=-2;x<patch_.width+2;++x){
            const auto wx=patch_.x+x,wy=patch_.y+y;
            const auto o=world.observation_at(wx,wy);
            const Sample s{o.revision,world.stored_state_a(wx,wy),world.transient_obstacle_at(wx,wy),
                world.temperature(wx,wy),world.stored_material(wx,wy),world.stored_state_b(wx,wy),
                o.active,o.changed,o.included};
            const auto i=static_cast<std::size_t>((y+2)*stride+x+2);
            changed=changed||!(s==previous_[i]);previous_[i]=s;
            included=included&&s.included;activity=activity||s.changed;occupied=occupied||s.body!=0;
            ++metrics_.witness_cells;
        }
        if(gap)++metrics_.gaps;
        if(!included)++metrics_.excluded;
        if(world.has_failed())++metrics_.failed;
        const bool reset=changed||gap||!included||activity||occupied||world.has_failed();
        if(reset){
            for(auto& c:candidates_)if(c.rest_ticks){++metrics_.invalidations;c.rest_ticks=0;}
        }
        if(changed)rebuild(world);
        if(!reset&&tick==last_tick_+1&&initialized_)
            for(std::size_t i=0;i<count_;++i)if(candidates_[i].rest_ticks<UINT32_MAX)++candidates_[i].rest_ticks;
        generation_=world.observation_generation();mask_revision_=world.observation_mask_revision();last_tick_=tick;initialized_=true;
    }
private:
    void rebuild(const World& world){
        ++metrics_.rebuilds;
        if(revision_!=UINT64_MAX)++revision_;
        const auto old=candidates_;const auto old_count=count_;
        labels_.fill(0);count_=0;
        const int w=static_cast<int>(patch_.width),h=static_cast<int>(patch_.height),stride=w+4;
        auto mat=[&](int x,int y){return previous_[static_cast<std::size_t>((y+2)*stride+x+2)].material;};
        std::size_t component_total=0;
        for(int y=0;y<h;++y)for(int x=0;x<w;++x){
            ++metrics_.geometry_cells;
            const auto seed=static_cast<std::size_t>(y*w+x);
            if(labels_[seed]||mat(x,y)==Material::Empty)continue;
            ++component_total;
            Candidate c;c.id=static_cast<std::uint32_t>(seed+1);c.revision=revision_;c.material=mat(x,y);
            c.cohesive=c.material==Material::Wall||c.material==Material::RedBrick;
            std::size_t head=0,tail=1;queue_[0]=static_cast<std::uint16_t>(seed);labels_[seed]=static_cast<std::uint16_t>(component_total);
            while(head<tail){
                const int p=queue_[head++],px=p%w,py=p/w;
                if(c.area<max_members)c.members[c.area]={static_cast<std::int16_t>(px),static_cast<std::int16_t>(py)};
                ++c.area;c.min_x=std::min(c.min_x,static_cast<std::int16_t>(px));c.max_x=std::max(c.max_x,static_cast<std::int16_t>(px));
                c.min_y=std::min(c.min_y,static_cast<std::int16_t>(py));c.max_y=std::max(c.max_y,static_cast<std::int16_t>(py));
                c.clipped=c.clipped||px==0||py==0||px==w-1||py==h-1;
                constexpr int dx[]={-1,1,0,0},dy[]={0,0,-1,1};
                for(int d=0;d<4;++d){const int nx=px+dx[d],ny=py+dy[d];
                    if(nx<0||ny<0||nx>=w||ny>=h||mat(nx,ny)!=c.material)continue;
                    const auto ni=static_cast<std::size_t>(ny*w+nx);
                    if(!labels_[ni]){labels_[ni]=static_cast<std::uint16_t>(component_total);queue_[tail++]=static_cast<std::uint16_t>(ni);}
                }
                if(mat(px,py+1)!=c.material){++c.exposed;const auto wx=patch_.x+px,wy=patch_.y+py+1;
                    if(MaterialRules::is_hard_surface(world.stored_material(wx,wy))||world.granular_support_at(wx,wy,false,false))++c.supported;}
            }
            c.capacity=c.area>max_members||revision_==UINT64_MAX;
            // Exact same-material row runs, vertically merged only for identical extents.
            if(!c.capacity)for(int py=0;py<h;++py)for(int px=0;px<w;){
                if(labels_[static_cast<std::size_t>(py*w+px)]!=component_total){++px;continue;}
                const int left=px;
                while(px<w&&labels_[static_cast<std::size_t>(py*w+px)]==component_total)++px;
                bool merged=false;
                for(std::size_t j=0;j<c.shape_count;++j){auto& r=c.shapes[j];
                    if(r.x==left&&r.w==px-left&&r.y+r.h==py){++r.h;merged=true;break;}}
                if(!merged){if(c.shape_count==max_shapes){c.capacity=true;break;}
                    c.shapes[c.shape_count++]={static_cast<std::int16_t>(left),static_cast<std::int16_t>(py),static_cast<std::int16_t>(px-left),1};}
            }
            metrics_.member_high_water=std::max(metrics_.member_high_water,static_cast<std::size_t>(c.area));
            metrics_.shape_high_water=std::max(metrics_.shape_high_water,c.shape_count);
            if(c.capacity)++metrics_.saturations;
            if(count_<max_components)candidates_[count_++]=c;
            else ++metrics_.saturations;
        }
        metrics_.component_high_water=std::max(metrics_.component_high_water,component_total);
        // Never publish a selected subset of an over-capacity patch as admissible.
        if(component_total>max_components)for(std::size_t i=0;i<count_;++i)candidates_[i].capacity=true;
        bool topology=old_count!=count_;
        for(std::size_t i=0;i<count_;++i){const auto& c=candidates_[i];
            const Candidate* prior=nullptr;
            for(std::size_t j=0;j<old_count;++j)if(old[j].id==c.id){prior=&old[j];break;}
            if(!prior){++metrics_.births;topology=true;continue;}
            if(prior->area!=c.area||prior->material!=c.material||prior->clipped!=c.clipped)topology=true;
            if(!c.capacity&&!prior->capacity&&prior->members!=c.members)topology=true;
            if(prior->supported!=c.supported)++metrics_.support_changes;
        }
        if(topology)++metrics_.topology_changes;
    }
};
} // namespace cybersand::soliding
