#include "cybersand/object_shard_coordinator.hpp"
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <iostream>
#include <vector>
using namespace cybersand;
using namespace cybersand::object_shard;
using Clock=std::chrono::steady_clock;
static std::uint64_t ns(Clock::time_point start) {
    return static_cast<std::uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(Clock::now()-start).count());
}
static bool activate(Coordinator& c,Handle handle) {
    for (auto kind:{AckKind::PhysicsReserved,AckKind::TerrainInstalled,AckKind::BodyActivated}) {
        const auto& s=c.snapshot();const auto* shard=c.registry().find(handle);if (!shard) return false;
        const auto& g=shard->geometry();
        if (c.acknowledge({handle,s.promotion.transaction,handle.generation,s.promotion.payload_digest,
                g.revision,g.mask_digest,g.shape_digest,kind,kind==AckKind::TerrainInstalled ? s.promotion.terrain : std::span<const TerrainReceipt>{}}).outcome!=Outcome::Accepted) return false;
    }
    return true;
}
static Result census(Coordinator& c,std::uint32_t& calls,std::uint64_t& maximum) {
    for (unsigned i=0;i<1024;++i) {
        const auto t=Clock::now();const auto r=c.prepare_next();maximum=std::max(maximum,ns(t));++calls;
        if (r.outcome==Outcome::Accepted || c.snapshot().admission.census_complete) return r;
    }
    return {Outcome::Invalid};
}
int main() {
    unsigned count;std::cin>>count;std::cout<<"{\"schema\":\"objectshard-larger-preset-native-probe-v1\",\"cases\":[";
    for (unsigned i=0;i<count;++i) {
        unsigned id,width,height,seed,cut_y,edits;std::cin>>id>>width>>height>>seed>>cut_y>>edits;
        Config config;config.scenario=0;config.world_bounds={0,0,static_cast<std::uint16_t>(width),static_cast<std::uint16_t>(height)};config.seed=seed;
        auto t=Clock::now();Coordinator c(config);const auto construction=ns(t);
        t=Clock::now();
        for (unsigned e=0;e<edits;++e) {
            int x,y,material;std::cin>>x>>y>>material;
            if (c.edit(x,y,{static_cast<Material>(material),0,0,200}).outcome!=Outcome::Accepted) return 2;
        }
        const auto authoring=ns(t);
        std::uint32_t calls=0;std::uint64_t maximum=0;
        const auto before=census(c,calls,maximum);const auto initial=c.snapshot().admission;
        if (before.outcome==Outcome::Accepted && c.cancel(before.transaction).outcome!=Outcome::Cancelled) return 3;
        unsigned cuts=0;
        for (unsigned x=0;x<width;++x) if (c.inspect_world(x,cut_y).material==Material::Wood) {
            if (c.edit(x,cut_y,{Material::Empty,0,0,200}).outcome!=Outcome::Accepted) return 4;
            ++cuts;
        }
        std::vector<std::uint32_t> promoted;std::vector<std::uint32_t> areas;
        AdmissionStatus cut{};
        for (unsigned owner=0;owner<3;++owner) {
            const auto r=census(c,calls,maximum);
            if (owner==0) cut=c.snapshot().admission;
            if (r.outcome!=Outcome::Accepted) break;
            const auto* shard=c.registry().find(r.shard);if (!shard) return 5;
            promoted.push_back(shard->counts().structural);areas.push_back(static_cast<std::uint32_t>(shard->area()));
            if (!activate(c,r.shard)) return 6;
        }
        (void)census(c,calls,maximum);const auto final=c.snapshot();
        if (i) std::cout<<',';
        std::cout<<"{\"id\":"<<id<<",\"width\":"<<width<<",\"height\":"<<height<<",\"ordinary_edits\":"<<edits
            <<",\"cut_y\":"<<cut_y<<",\"wood_cells_erased\":"<<cuts<<",\"initial_components\":"<<initial.components
            <<",\"initial_eligible\":"<<initial.eligible<<",\"cut_eligible\":"<<cut.eligible<<",\"after_promotions_deferred\":"<<final.admission.deferred
            <<",\"after_promotions_reason\":\""<<admission_reason_name(final.admission.reason)<<"\",\"promoted_cells\":[";
        for (std::size_t j=0;j<promoted.size();++j) {if(j)std::cout<<',';std::cout<<promoted[j];}
        std::cout<<"],\"promoted_bbox_areas\":[";for (std::size_t j=0;j<areas.size();++j) {if(j)std::cout<<',';std::cout<<areas[j];}
        std::cout<<"],\"discovery_calls\":"<<calls<<",\"discovery_work_peak\":"<<final.admission.work_peak
            <<",\"discovery_call_max_ns\":"<<maximum<<",\"construction_ns\":"<<construction<<",\"authoring_ns\":"<<authoring
            <<",\"reported_retained_bytes\":"<<final.metrics.retained_bytes<<",\"registry_structural\":"<<c.registry().inventory_counts().structural
            <<",\"world_wood\":"<<c.world().quantity_ledger().material_cells[static_cast<std::uint8_t>(Material::Wood)]<<'}';
    }
    std::cout<<"],\"qualification_scope\":\"Native exact production-preset edits and synthetic handoff receipts; no Rapier, GUI or Windows claim\"}\n";
}
