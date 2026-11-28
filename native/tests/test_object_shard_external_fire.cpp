#include "cybersand/object_shard_coordinator.hpp"
#include "cybersand/object_shard_contact.hpp"
#include "cybersand/material_lifecycle.hpp"
#include <array>
#include <cstdio>
#include <limits>
#include <vector>

namespace cybersand::object_shard {
struct CoordinatorTestAccess {
    static std::span<const Exposure> exposures(const Coordinator& c) { return c.exposures_; }
    static auto remove_relocation_capacity(Coordinator& c) {
        decltype(c.relocations_) previous;
        previous.swap(c.relocations_);
        return previous;
    }
    template<class T> static void restore_relocation_capacity(Coordinator& c, T& previous) {
        c.relocations_.swap(previous);
    }
};
}
namespace {
using namespace cybersand;
using namespace cybersand::object_shard;
std::uint64_t checks{}, failures{};
void check(bool value,const char* text,int line) {
    ++checks;
    if (!value) {++failures;std::fprintf(stderr,"FAIL %d: %s\n",line,text);}
}
#define CHECK(value) check((value),#value,__LINE__)
Config fixture_config() {Config c;c.scenario=0;c.world_bounds={0,0,96,96};return c;}
std::vector<PoseSample> poses(Coordinator& c) {
    std::vector<PoseSample> result;
    for (const auto& body:c.snapshot().bodies) if (body.has_body) {
        result.push_back(body.pose);++result.back().pose_serial;
    }
    return result;
}
Handle promote(Coordinator& c,int x=40,int y=40) {
    CHECK(c.edit(x,y,{Material::Wood,71,0,470}).outcome==Outcome::Accepted);
    Result p;
    for (int i=0;i<1024;++i) {
        p=c.prepare_next();
        if (p.outcome==Outcome::Accepted) break;
        CHECK(p.outcome==Outcome::Busy || p.outcome==Outcome::Anchored);
    }
    CHECK(p.outcome==Outcome::Accepted);
    if (p.outcome!=Outcome::Accepted) return {};
    for (const auto kind:{AckKind::PhysicsReserved,AckKind::TerrainInstalled,AckKind::BodyActivated}) {
        const auto snapshot=c.snapshot();const auto* shard=c.registry().find(p.shard);
        CHECK(shard!=nullptr);if (!shard) return {};
        const auto& g=shard->geometry();
        const Acknowledgement ack{p.shard,p.transaction,p.shard.generation,snapshot.promotion.payload_digest,
            g.revision,g.mask_digest,g.shape_digest,kind,
            kind==AckKind::TerrainInstalled ? snapshot.promotion.terrain : std::span<const TerrainReceipt>{}};
        CHECK(c.acknowledge(ack).outcome==Outcome::Accepted);
    }
    return p.shard;
}
std::uint32_t wood_cell(Coordinator& c,Handle h) {
    const auto* shard=c.registry().find(h);CHECK(shard!=nullptr);if (!shard) return 0;
    for (std::uint32_t i=0;i<shard->area();++i) if (shard->structural(i)) return i;
    CHECK(false);return 0;
}
struct Opportunity {std::uint64_t tick;int x,y;};
Opportunity opportunity(Coordinator& c,int target_x=40,int target_y=40) {
    namespace chemistry=material_lifecycle;
    for (auto tick=c.world().completed_tick_index()+2;tick<c.world().completed_tick_index()+960;++tick)
        for (const auto offset:chemistry::kNeighbours) {
            const auto x=target_x-offset.x,y=target_y-offset.y;
            if (!chemistry::lane_due(tick,x,y,120,10)) continue;
            const auto sampled=chemistry::kNeighbours[chemistry::random(tick,x,y,10)%8];
            if (sampled.x==offset.x && sampled.y==offset.y) return {tick,x,y};
        }
    CHECK(false);return {};
}
void advance_to(Coordinator& c,std::uint64_t tick) {
    while (c.world().completed_tick_index()<tick) CHECK(c.step(poses(c)).outcome==Outcome::Accepted);
}
std::size_t ignition_events(Coordinator& c) {
    std::size_t count=0;
    for (const auto& e:CoordinatorTestAccess::exposures(c)) count+=e.kind==ExposureKind::FireIgnition;
    return count;
}
void inventory_balance(Coordinator& c) {
    auto count=c.world().quantity_ledger().material_cells;
    for (const auto& shard:c.registry().shards()) if (shard.owns_inventory())
        for (std::size_t i=0;i<shard.area();++i) if (shard.occupied(i)) ++count[static_cast<std::uint8_t>(shard.payload(i).material)];
    const auto& a=c.accounting();
    for (std::size_t m=1;m<kQuantityMaterialSlots;++m) {
        const auto expected=static_cast<std::int64_t>(a.setup_created[m])+static_cast<std::int64_t>(a.authored_created[m])-
            static_cast<std::int64_t>(a.authored_destroyed[m])+a.world_tick_delta[m]+static_cast<std::int64_t>(a.created[m])-
            static_cast<std::int64_t>(a.destroyed[m])-static_cast<std::int64_t>(a.expired[m])-static_cast<std::int64_t>(a.reset_disposed[m]);
        CHECK(static_cast<std::int64_t>(count[m])==expected);
    }
}
void authentic_historical_contact_and_segment_clock() {
    Coordinator c(fixture_config());const auto h=promote(c);if (!h.id)return;
    const auto cell=wood_cell(c,h);
    const auto o=opportunity(c);
    advance_to(c,o.tick-1);
    const Payload fire{Material::Fire,32,0,650};
    CHECK(c.edit(o.x,o.y,fire).outcome==Outcome::Accepted);
    const auto captured_tick=c.world().completed_tick_index();
    const auto before_steps=c.metrics().steps;
    for (int i=0;i<8;++i) {
        CHECK(c.accept_motion(poses(c)).outcome==Outcome::Accepted);
        CHECK(c.world().completed_tick_index()==captured_tick);
        CHECK(c.metrics().steps==before_steps);
        CHECK(c.inspect_world(o.x,o.y)==fire);
        CHECK(ignition_events(c)==1);
        CHECK(c.accounting().external_ignitions==0);
    }
    // Historical non-consuming contact remains a fact after the actual World
    // Fire is removed by an ordinary authored operation; it grants no debit.
    CHECK(c.edit(o.x,o.y,{Material::Empty,0,0,650}).outcome==Outcome::Accepted);
    CHECK(c.step(poses(c)).outcome==Outcome::Accepted);
    const auto* shard=c.registry().find(h);CHECK(shard!=nullptr);if(!shard)return;
    CHECK(shard->payload(cell).material==Material::Wood);
    CHECK(shard->payload(cell).state_b==239 || shard->payload(cell).state_b==240);
    CHECK(shard->payload(cell).state_a==71 && shard->payload(cell).temperature==470);
    CHECK(c.accounting().external_ignitions==1);
    CHECK(c.accounting().consumed_exposures==1);
    CHECK(ignition_events(c)==0);
    CHECK(c.step(poses(c)).outcome==Outcome::Accepted);
    CHECK(c.accounting().external_ignitions==1);
    inventory_balance(c);
}
void no_ignition_outside_source_opportunity() {
    Coordinator c(fixture_config());const auto h=promote(c);if(!h.id)return;
    const auto cell=wood_cell(c,h);const auto tick=c.world().completed_tick_index()+1;
    int source_x=0,source_y=0;
    for (const auto offset:material_lifecycle::kNeighbours) {
        const auto x=40-offset.x,y=40-offset.y;
        if (!material_lifecycle::lane_due(tick,x,y,120,10)) {source_x=x;source_y=y;break;}
    }
    CHECK(source_x!=0);
    CHECK(c.edit(source_x,source_y,{Material::Fire,32,0,650}).outcome==Outcome::Accepted);
    CHECK(c.accept_motion(poses(c)).outcome==Outcome::Accepted);
    CHECK(ignition_events(c)==0);
    CHECK(c.step(poses(c)).outcome==Outcome::Accepted);
    CHECK(c.registry().find(h)->payload(cell).state_b==0);
    CHECK(c.accounting().external_ignitions==0);
    inventory_balance(c);
}
void stale_target_and_motion_rejection() {
    Coordinator c(fixture_config());const auto h=promote(c);if(!h.id)return;
    const auto cell=wood_cell(c,h);
    const auto o=opportunity(c);advance_to(c,o.tick-1);
    CHECK(c.edit(o.x,o.y,{Material::Fire,32,0,650}).outcome==Outcome::Accepted);
    CHECK(c.accept_motion(poses(c)).outcome==Outcome::Accepted);
    CHECK(ignition_events(c)==1);
    const auto* shard=c.registry().find(h);const auto snap=c.snapshot();
    ShardEditRequest edit;edit.shard=h;edit.sequence=c.next_transaction();
    for (const auto& body:snap.bodies) if(body.shard==h) {
        edit.body_generation=body.body_generation;edit.pose_serial=body.pose.pose_serial;
    }
    edit.geometry_revision=shard->geometry().revision;edit.material_revision=shard->material_revision();
    edit.cell=cell;edit.incarnation=shard->schedule(cell).incarnation;edit.expected=shard->payload(cell);
    CHECK(c.erase_shard(edit).outcome==Outcome::Accepted);
    CHECK(c.accept_motion(poses(c)).outcome==Outcome::Fenced);
    shard=c.registry().find(h);
    for(const auto& body:c.snapshot().bodies) if(body.shard==h) {
        const auto& g=shard->geometry();
        CHECK(c.acknowledge({h,body.transaction,body.body_generation,shard->payload_digest(),g.revision,
            g.mask_digest,g.shape_digest,AckKind::BodyRetired,{}}).outcome==Outcome::Accepted);
        break;
    }
    CHECK(c.step(poses(c)).outcome==Outcome::Accepted);
    CHECK(c.accounting().external_ignitions==0);
    inventory_balance(c);

    Coordinator moving(fixture_config());const auto moving_h=promote(moving);if(!moving_h.id)return;
    auto sample=poses(moving);const auto tick=moving.world().completed_tick_index();
    const auto original=moving.snapshot().bodies[0].pose;
    sample[0].x+=4.01;
    CHECK(moving.accept_motion(sample).outcome==Outcome::Unsupported);
    CHECK(moving.world().completed_tick_index()==tick);
    CHECK(moving.snapshot().bodies[0].pose.x==original.x);
    const auto domain=contact::motion_domain(*moving.registry().find(moving_h));
    const auto envelope=contact::motion_envelope(domain);
    CHECK(domain.valid && envelope.max_rotation>.201);
    // Keep the absolute angular refusal, now at the occupied-geometry bound.
    // A one-cell offcut's ordinary .201-radian motion is no longer corruption.
    sample=poses(moving);sample[0].rotation+=envelope.max_rotation+.001;
    CHECK(moving.accept_motion(sample).outcome==Outcome::Unsupported);
    CHECK(moving.snapshot().bodies[0].pose.rotation==original.rotation);
    CHECK(moving.snapshot().bodies[0].pose.pose_serial==original.pose_serial);
    sample=poses(moving);sample[0].rotation+=.201;
    CHECK(moving.accept_motion(sample).outcome==Outcome::Accepted);
    CHECK(moving.snapshot().bodies[0].pose.rotation==sample[0].rotation);
    CHECK(moving.snapshot().bodies[0].pose.pose_serial==sample[0].pose_serial);
    CHECK(moving.world().completed_tick_index()==tick);
    sample=poses(moving);CHECK(moving.accept_motion(sample).outcome==Outcome::Accepted);
    CHECK(moving.accept_motion(sample).outcome==Outcome::Stale);
    CHECK(moving.world().completed_tick_index()==tick);
    inventory_balance(moving);
}
void relocated_fire_is_one_source_opportunity() {
    Coordinator c(fixture_config());
    const auto first=promote(c,48,11),second=promote(c,46,12);
    if (!first.id || !second.id) return;
    advance_to(c,212);
    CHECK(c.edit(48,12,{Material::Fire,32,0,650}).outcome==Outcome::Accepted);
    CHECK(c.accept_motion(poses(c)).outcome==Outcome::Accepted);
    auto samples=poses(c);
    for (auto& sample:samples) if (sample.shard==first) sample.y+=1;
    CHECK(c.accept_motion(samples).outcome==Outcome::Accepted);
    CHECK(c.inspect_world(47,11).material==Material::Fire);
    CHECK(c.accept_motion(poses(c)).outcome==Outcome::Accepted);
    CHECK(c.world().quantity_ledger().material_cells[static_cast<std::uint8_t>(Material::Fire)]==1);
    CHECK(ignition_events(c)==1);
    CHECK(c.step(poses(c)).outcome==Outcome::Accepted);
    CHECK(c.accounting().external_ignitions==1);
    CHECK(c.registry().find(first)->payload(wood_cell(c,first)).state_b!=0);
    CHECK(c.registry().find(second)->payload(wood_cell(c,second)).state_b==0);
    inventory_balance(c);
}
void spent_external_opportunity_does_not_repeat_in_world() {
    Coordinator c(fixture_config());const auto h=promote(c,48,11);if (!h.id)return;
    advance_to(c,212);
    CHECK(c.edit(48,12,{Material::Fire,32,0,650}).outcome==Outcome::Accepted);
    CHECK(c.accept_motion(poses(c)).outcome==Outcome::Accepted);
    CHECK(ignition_events(c)==1);
    auto samples=poses(c);samples[0].x-=2;
    CHECK(c.accept_motion(samples).outcome==Outcome::Accepted);
    CHECK(c.edit(48,11,{Material::Wood,71,0,470}).outcome==Outcome::Accepted);
    CHECK(c.step(poses(c)).outcome==Outcome::Accepted);
    CHECK(c.accounting().external_ignitions==1);
    CHECK(c.registry().find(h)->payload(wood_cell(c,h)).state_b!=0);
    CHECK(c.inspect_world(48,11).state_b==0);
    // The spent-opportunity guard affects ignition only. The actual source
    // continues its ordinary Fire lifetime and transport during this tick.
    unsigned continued_fire=0, newborn_fire=0;
    for (int y=10;y<=13;++y) for (int x=46;x<=50;++x) if (c.inspect_world(x,y).material==Material::Fire) {
        const auto lifetime=c.inspect_world(x,y).state_a;
        continued_fire+=lifetime==31;
        newborn_fire+=lifetime==material_lifecycle::kWoodFireLifetime;
        CHECK(lifetime==31 || lifetime==material_lifecycle::kWoodFireLifetime);
    }
    CHECK(continued_fire==1);
    // Burning Wood may create and emit genuine Fire in the same semantic
    // tick. That newborn inventory is distinct from the continuing source.
    CHECK(newborn_fire==c.accounting().emitted[static_cast<std::uint8_t>(Material::Fire)]);
    inventory_balance(c);
    CHECK(c.reset(0,12).outcome==Outcome::Accepted);
    advance_to(c,212);
    CHECK(c.edit(48,12,{Material::Fire,32,0,650}).outcome==Outcome::Accepted);
    CHECK(c.edit(48,11,{Material::Wood,71,0,470}).outcome==Outcome::Accepted);
    CHECK(c.step().outcome==Outcome::Accepted);
    CHECK(c.inspect_world(48,11).state_b!=0); // No old-session reservation survives.
    inventory_balance(c);
}
void refused_motion_does_not_spend_fire_opportunity() {
    Coordinator c(fixture_config());
    const auto h=promote(c,48,11);
    if (!h.id) return;
    advance_to(c,212);
    const Payload fire{Material::Fire,32,0,650};
    CHECK(c.edit(48,12,fire).outcome==Outcome::Accepted);
    const auto original=c.snapshot().bodies[0].pose;
    const auto witness=c.world_witness(48,12);
    auto capacity=CoordinatorTestAccess::remove_relocation_capacity(c);
    auto proposed=poses(c);
    proposed[0].y+=1; // Captures Fire contact, then requires its relocation.
    CHECK(c.accept_motion(proposed).outcome==Outcome::Capacity);
    CHECK(c.world().completed_tick_index()==212);
    CHECK(c.snapshot().bodies[0].pose.y==original.y);
    CHECK(c.snapshot().bodies[0].pose.pose_serial==original.pose_serial);
    CHECK(c.inspect_world(48,12)==fire && c.world_witness(48,12)==witness);
    CHECK(ignition_events(c)==0 && c.accounting().accepted_exposures==0);
    CoordinatorTestAccess::restore_relocation_capacity(c,capacity);
    CHECK(c.accept_motion(poses(c)).outcome==Outcome::Accepted);
    CHECK(ignition_events(c)==1);
    CHECK(c.step(poses(c)).outcome==Outcome::Accepted);
    CHECK(c.accounting().external_ignitions==1);
    CHECK(c.registry().find(h)->payload(wood_cell(c,h)).state_b!=0);
    inventory_balance(c);
}
void water_departure_keeps_pending_fire_extinction_fact() {
    Coordinator c(fixture_config());
    const auto h=promote(c,48,11);
    if (!h.id) return;
    advance_to(c,212);
    CHECK(c.edit(48,12,{Material::Fire,32,0,650}).outcome==Outcome::Accepted);
    CHECK(c.accept_motion(poses(c)).outcome==Outcome::Accepted);
    CHECK(ignition_events(c)==1);
    CHECK(c.edit(49,11,{Material::Water,255,0,200}).outcome==Outcome::Accepted);
    CHECK(c.accept_motion(poses(c)).outcome==Outcome::Accepted);
    CHECK(CoordinatorTestAccess::exposures(c).size()==2);
    CHECK(c.edit(49,11,{Material::Empty,0,0,200}).outcome==Outcome::Accepted);
    CHECK(c.world().quantity_ledger().material_cells[static_cast<std::uint8_t>(Material::Water)]==0);
    // The no-World-Water fast path must preserve the previously accepted
    // historical fact until the same Wood incarnation's combustion lane.
    CHECK(c.accept_motion(poses(c)).outcome==Outcome::Accepted);
    CHECK(CoordinatorTestAccess::exposures(c).size()==2);
    CHECK(c.step(poses(c)).outcome==Outcome::Accepted);
    CHECK(c.accounting().external_ignitions==1 && c.accounting().extinguished==1);
    CHECK(c.registry().find(h)->payload(wood_cell(c,h)).state_b==0);
    inventory_balance(c);
}
}
int main() {
    authentic_historical_contact_and_segment_clock();
    no_ignition_outside_source_opportunity();
    stale_target_and_motion_rejection();
    relocated_fire_is_one_source_opportunity();
    spent_external_opportunity_does_not_repeat_in_world();
    refused_motion_does_not_spend_fire_opportunity();
    water_departure_keeps_pending_fire_extinction_fact();
    std::printf("%llu checks, %llu failures\n",static_cast<unsigned long long>(checks),static_cast<unsigned long long>(failures));
    return failures?1:0;
}
