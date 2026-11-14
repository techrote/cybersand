// GEN-006 #194: experimental native owner-scope negative controls.
// No production serializer, eviction API, defaults, or physics modifications.
#include "cybersand/world.hpp"
#include <cstdint>
#include <iostream>
#include <stdexcept>

namespace {
using cybersand::World;
using cybersand::WorldConfig;
using cybersand::Material;
using cybersand::SimulationBackend;
std::uint64_t assertions=0;
void check(bool ok, const char* reason) {
    ++assertions;
    if (!ok) throw std::runtime_error(reason);
}
WorldConfig config_for(std::uint32_t workers) {
    WorldConfig cfg{};
    cfg.chunk_size=128;
    cfg.backend=SimulationBackend::PhasedInPlace;
    cfg.worker_threads=workers;
    cfg.parallel_job_threshold=1;
    cfg.initial_chunk_reserve=2;
    cfg.maximum_chunk_count=8;
    cfg.active_chunk_capacity=32;
    cfg.active_core_capacity=256;
    cfg.deferred_event_capacity=16;
    return cfg;
}
void probe(std::uint32_t workers) {
    const auto initial=assertions;
    auto cfg=config_for(workers);
    // Optional native GCR-SEL witness is enabled before the first tick.
    World original(cfg);
    original.set(-64,40,Material::Wall);
    original.enable_granular_arrival_witness(true);
    const auto bytes=original.granular_arrival_storage_bytes();
    check(bytes==128U*128U*sizeof(std::uint64_t),
          "original does not own the resident witness sidecar");
    const auto first=original.tick();
    check(first.tick==1U && original.completed_tick_index()==1U,
          "initial native tick failed");
    const auto snapshot=original.save_physical_state();
    check(snapshot.size()>40U,"native CYPS checkpoint missing");
    auto restored=World::restore_physical_state(cfg,snapshot);
    check(restored!=nullptr,"same-source CYPS restore refused");
    check(restored->completed_tick_index()==original.completed_tick_index(),
          "restored clock diverged");
    check(restored->stored_material(-64,40)==Material::Wall,
          "restored authoritative native material diverged");
    check(restored->physical_state_hash()==original.physical_state_hash(),
          "CYPS full native physical-state hash mismatched");
    check(restored->granular_arrival_storage_bytes()==0U,
          "CYPS unexpectedly restored optional arrival-witness array");
    check(original.granular_arrival_storage_bytes()==bytes,
          "export changed original arrival-witness allocation");
    bool late_refused=false;
    try {restored->enable_granular_arrival_witness(true);}
    catch (const std::logic_error&) {late_refused=true;}
    check(late_refused,"restored post-tick World unexpectedly allows witness enable");
    (void)original.tick();
    (void)restored->tick();
    check(original.completed_tick_index()==2U && restored->completed_tick_index()==2U,
          "follow-on native ticks did not finish");
    check(original.physical_state_hash()==restored->physical_state_hash(),
          "ordinary cellular continuation diverged");
    check(restored->granular_arrival_storage_bytes()==0U,
          "lost optional witness was silently reconstructed");

    // Real transient occupancy is not authoritative cellular material.
    World masked(cfg);
    masked.configure_transient_obstacles({-128,0,128,128});
    check(masked.set_transient_obstacle(-64,40,7U),"mask setup refused");
    check(masked.transient_obstacle_at(-64,40)==7U,"mask missing before save");
    check(masked.stored_material(-64,40)==Material::Empty &&
          masked.get(-64,40)==Material::Wall,
          "transient occupancy mistaken for cellular state");
    const auto mask_snapshot=masked.save_physical_state();
    auto unmasked=World::restore_physical_state(cfg,mask_snapshot);
    check(unmasked->stored_material(-64,40)==Material::Empty,
          "CYPS changed stored Empty");
    check(unmasked->transient_obstacle_at(-64,40)==0U &&
          unmasked->get(-64,40)==Material::Empty,
          "CYPS unexpectedly restored host-owned transient occupancy");
    check(masked.physical_state_hash()!=unmasked->physical_state_hash(),
          "native hash failed to discriminate missing body occupancy");

    // Digest corruption must refuse without mutating the live native World.
    auto corrupted=snapshot;
    corrupted.back()^=0x01;
    bool corrupt_refused=false;
    try { (void)World::restore_physical_state(cfg,corrupted); }
    catch (const std::invalid_argument&) {corrupt_refused=true;}
    check(corrupt_refused,"corrupt CYPS accepted");
    check(original.stored_material(-64,40)==Material::Wall &&
          original.granular_arrival_storage_bytes()==bytes,
          "failed restore mutated original World");
    std::cout<<"workers_configured="<<workers
             <<" workers_observed_first_tick="<<first.worker_threads_observed
             <<" witness_bytes_original="<<bytes
             <<" witness_bytes_restored="<<restored->granular_arrival_storage_bytes()
             <<" mask_original=7 mask_restored="<<unmasked->transient_obstacle_at(-64,40)
             <<" assertions="<<(assertions-initial)<<" result=PASS\n";
}
}
int main() {
    try {
        probe(1);
        probe(4);
        std::cout<<"GEN006_SELECTIVE_DOMAIN_REFUSAL_PASS total_assertions="<<assertions<<"\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr<<"GEN006_SELECTIVE_DOMAIN_REFUSAL_FAIL after_assertion="<<assertions
                 <<" reason="<<e.what()<<"\n";
        return 1;
    }
}
