// GEN-006: actual shared-World dynamic-neighbour/static-selective bridge.
// Compiled against the immutable #512 source as a READ-ONLY dependency.
// Proves only STATIC Wall/Empty selective reclamation while real Sand/Water
// remain live in adjacent native residents. Dynamic bundle release stays HOLD.
#include "cybersand/world.hpp"

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <stdexcept>
#include <string>
#include <vector>
#ifdef _WIN32
#include <io.h>
#else
#include <fcntl.h>
#include <unistd.h>
#endif

namespace fs = std::filesystem;
using namespace cybersand;
namespace {
void demand(bool yes, const char* reason) {
    if (!yes) throw std::runtime_error(reason);
}
WorldConfig config(std::uint32_t workers) {
    WorldConfig cfg;
    cfg.chunk_size=64;
    cfg.activity_block_size=16;
    cfg.scheduling_core_size=64;
    cfg.initial_chunk_reserve=3;
    cfg.maximum_chunk_count=3;
    cfg.active_chunk_capacity=256;
    cfg.active_core_capacity=256;
    cfg.worker_threads=workers;
    cfg.parallel_job_threshold=1;
    cfg.gen006_track_edit_intent=true;
    return cfg;
}
void durable_write(const fs::path& file, const std::vector<std::uint8_t>& bytes) {
    fs::create_directories(file.parent_path());
    const auto temporary=file.string()+".tmp";
    auto* stream=std::fopen(temporary.c_str(),"wb");
    demand(stream!=nullptr,"GEN006_BRIDGE_FILE_OPEN");
    demand(std::fwrite(bytes.data(),1,bytes.size(),stream)==bytes.size(),
           "GEN006_BRIDGE_FILE_SHORT_WRITE");
    demand(std::fflush(stream)==0,"GEN006_BRIDGE_FILE_FLUSH");
#ifdef _WIN32
    demand(_commit(_fileno(stream))==0,"GEN006_BRIDGE_FILE_SYNC");
#else
    demand(fsync(fileno(stream))==0,"GEN006_BRIDGE_FILE_SYNC");
#endif
    demand(std::fclose(stream)==0,"GEN006_BRIDGE_FILE_CLOSE");
    demand(std::rename(temporary.c_str(),file.string().c_str())==0,
           "GEN006_BRIDGE_FILE_RENAME");
#ifndef _WIN32
    const auto parent=fs::absolute(file).parent_path();
    const int fd=open(parent.c_str(),O_RDONLY|O_DIRECTORY);
    demand(fd>=0,"GEN006_BRIDGE_DIRECTORY_OPEN");
    demand(fsync(fd)==0,"GEN006_BRIDGE_DIRECTORY_SYNC");
    demand(close(fd)==0,"GEN006_BRIDGE_DIRECTORY_CLOSE");
#endif
}
std::vector<std::uint8_t> read_exact(const fs::path& file) {
    std::ifstream input(file,std::ios::binary);
    demand(static_cast<bool>(input),"GEN006_BRIDGE_READ_OPEN");
    std::vector<std::uint8_t> bytes(
        (std::istreambuf_iterator<char>(input)),std::istreambuf_iterator<char>());
    demand(!bytes.empty() && bytes.size()<16U*1024U*1024U,
           "GEN006_BRIDGE_READ_SIZE");
    return bytes;
}
ChunkDurableAck ack(const ChunkCheckpoint& c,bool durable=true) {
    return {c.coord,c.generation,c.world_tick,c.sha256,durable,
            c.admission_incarnation};
}
void populate(World& w) {
    const std::vector<Material> empty(64U*64U,Material::Empty);
    demand(w.install_generated_chunk({-2,-2},empty)==ChunkInstallOutcome::Installed,
           "GEN006_BRIDGE_TOP_INSTALL");
    demand(w.install_generated_chunk({-2,-1},empty)==ChunkInstallOutcome::Installed,
           "GEN006_BRIDGE_BOTTOM_INSTALL");
    demand(w.install_generated_chunk({8,0},empty)==ChunkInstallOutcome::Installed,
           "GEN006_BRIDGE_STATIC_INSTALL");
    for (std::int64_t x=21;x<29;++x)
        w.set(-128+x,-65,Material::Sand);
    for (std::int64_t x=35;x<40;++x)
        w.set(-128+x,-65,Material::Water);
    w.set(514,2,Material::Wall);
    w.set_temperature(514,2,417);
    w.set(520,4,Material::Empty); // Same-value player intent is authoritative.
}
void parity(const World& a,const World& b,const char* failure) {
    if(a.physical_state_hash()!=b.physical_state_hash() ||
       a.content_hash()!=b.content_hash() ||
       a.state_hash()!=b.state_hash() ||
       a.quantity_ledger()!=b.quantity_ledger() ||
       a.completed_tick_index()!=b.completed_tick_index() ||
       a.chunk_count()!=b.chunk_count() ||
       a.resident_cell_bytes()!=b.resident_cell_bytes()) {
        std::cerr<<"GEN006_BRIDGE_PARITY_DIAGNOSTIC a_physical="
                 <<a.physical_state_hash()<<" b_physical="<<b.physical_state_hash()
                 <<" a_tick="<<a.completed_tick_index()
                 <<" b_tick="<<b.completed_tick_index()
                 <<" a_bytes="<<a.resident_cell_bytes()
                 <<" b_bytes="<<b.resident_cell_bytes()<<"\n";
        demand(false,failure);
    }
}
void run(const fs::path& file,std::uint32_t workers) {
    World live(config(workers)),control(config(workers));
    populate(live);
    populate(control);
    parity(live,control,"GEN006_BRIDGE_INITIAL_PARITY");
    bool sand_crossed=false,water_crossed=false;
    std::uint32_t observed=0;
    ChunkCheckpointCapture captured{};
    for (unsigned i=0;i<64;++i) {
        const auto a=live.tick(),b=control.tick();
        observed=std::max(observed,a.worker_threads_observed);
        demand(a.tick==b.tick && !live.has_failed() && !control.has_failed(),
               "GEN006_BRIDGE_NATIVE_TICK_FAILED");
        parity(live,control,"GEN006_BRIDGE_PRE_CAPTURE_PARITY");
        for (std::int64_t y=-64;y<-44;++y) {
            for (std::int64_t x=19;x<31;++x)
                sand_crossed|=live.stored_material(-128+x,y)==Material::Sand;
            for (std::int64_t x=30;x<50;++x)
                water_crossed|=live.stored_material(-128+x,y)==Material::Water &&
                                live.liquid_mass(-128+x,y)!=0;
        }
        captured=live.capture_chunk_checkpoint({8,0});
        if(captured.status==ChunkCheckpointStatus::Captured)break;
        demand(captured.status==ChunkCheckpointStatus::PendingActivity,
               "GEN006_BRIDGE_STATIC_CAPTURE_INVALID");
    }
    demand(sand_crossed && water_crossed,
           "GEN006_BRIDGE_DYNAMIC_SEAM_NOT_OBSERVED");
    demand(captured.status==ChunkCheckpointStatus::Captured,
           "GEN006_BRIDGE_STATIC_CAPTURE_NEVER_SETTLED");
    demand(live.chunk_count()==3 && live.resident_cell_bytes()>0 &&
           live.gen006_player_edit_intent_at(520,4) &&
           live.stored_temperature(514,2)==417,
           "GEN006_BRIDGE_STATIC_RECORD_INCOMPLETE");

    // Dynamic pair MUST remain pinned. Do not claim dynamic selectivity.
    const auto dynamic_status=live.capture_chunk_checkpoint({-2,-2}).status;
    demand(dynamic_status==ChunkCheckpointStatus::NeighbourPinned ||
           dynamic_status==ChunkCheckpointStatus::UnsupportedDomain ||
           dynamic_status==ChunkCheckpointStatus::PendingActivity,
           "GEN006_BRIDGE_DYNAMIC_NOT_PINNED");

    const auto before=live.save_physical_state();
    const auto count=live.chunk_count();
    const auto bytes=live.resident_cell_bytes();
    demand(live.evict_durable_checkpoint(captured.checkpoint,
                                        ack(captured.checkpoint,false))==
           ChunkCheckpointStatus::MissingDurabilityAck &&
           live.save_physical_state()==before,
           "GEN006_BRIDGE_UNDURABLE_EVICTION");
    auto incorrect=ack(captured.checkpoint);
    ++incorrect.admission_incarnation;
    demand(live.evict_durable_checkpoint(captured.checkpoint,incorrect)==
           ChunkCheckpointStatus::MissingDurabilityAck &&
           live.save_physical_state()==before,
           "GEN006_BRIDGE_FORGED_INCARCATION");

    // A valid, *actually published* checkpoint can become stale while a
    // different native resident is advancing. Keep the old file on disk as
    // a realistic late durable ACK: no render-dirty or unchanged static
    // material shortcut may override the source completed-tick fence.
    const auto inflight=captured.checkpoint;
    const fs::path stale_file=file.string()+".stale.g6c";
    durable_write(stale_file,inflight.bytes);
    demand(read_exact(stale_file)==inflight.bytes,
           "GEN006_BRIDGE_INFLIGHT_OLD_DISK_READBACK");
    for(unsigned i=0;i<2;++i) {
        const auto a=live.tick(),b=control.tick();
        observed=std::max(observed,a.worker_threads_observed);
        demand(a.tick==b.tick && !live.has_failed() && !control.has_failed(),
               "GEN006_BRIDGE_INFLIGHT_NATIVE_TICK_FAILED");
        parity(live,control,"GEN006_BRIDGE_INFLIGHT_CONTROL_DIVERGED");
    }
    const auto advanced_state=live.save_physical_state();
    demand(live.completed_tick_index()>inflight.world_tick &&
           live.evict_durable_checkpoint(inflight,ack(inflight))==
               ChunkCheckpointStatus::StaleGeneration &&
           live.chunk_count()==count && live.resident_cell_bytes()==bytes &&
           live.save_physical_state()==advanced_state,
           "GEN006_BRIDGE_LATE_DURABLE_ACK_EVICTED_LIVE_RESIDENT");

    // Recapture and publish an exact new source-tick identity. Only this
    // current acknowledged generation may reclaim the static resident,
    // leaving the genuinely moving two-resident Sand/Water seam untouched.
    auto refreshed=live.capture_chunk_checkpoint({8,0});
    demand(refreshed.status==ChunkCheckpointStatus::Captured &&
           refreshed.checkpoint.world_tick==live.completed_tick_index() &&
           refreshed.checkpoint.world_tick>inflight.world_tick &&
           refreshed.checkpoint.admission_incarnation==
               inflight.admission_incarnation,
           "GEN006_BRIDGE_INFLIGHT_REFRESH_NOT_CURRENT");
    captured=std::move(refreshed);
    durable_write(file,captured.checkpoint.bytes);
    const auto readback=read_exact(file);
    demand(readback==captured.checkpoint.bytes,
           "GEN006_BRIDGE_DURABLE_READBACK");
    demand(live.evict_durable_checkpoint(captured.checkpoint,
                                        ack(captured.checkpoint))==
           ChunkCheckpointStatus::Evicted,
           "GEN006_BRIDGE_REAL_STATIC_EVICT_FAILED");
    const auto remaining_count=live.chunk_count();
    const auto remaining_bytes=live.resident_cell_bytes();
    demand(remaining_count==2 && remaining_count+1==count &&
           remaining_bytes<bytes,
           "GEN006_BRIDGE_STATIC_MEMORY_NOT_RECLAIMED");
    demand(live.stored_material(514,2)==Material::Empty &&
           !live.has_failed(),
           "GEN006_BRIDGE_STATIC_REMAINED_RESIDENT");
    // Keep the genuine Sand/Water pair simulating in the SAME native World
    // during selective release.  This closes the older fixture's no-tick gap:
    // neither the native owner nor the neighboring dynamic seam is replaced.
    // The independent control retains all three chunks for each matching tick.
    const auto before_absent = live.save_physical_state();
    auto damaged = readback;
    damaged[damaged.size()/2] ^= 1U;
    demand(live.restore_chunk_checkpoint({8,0},damaged)==
               ChunkCheckpointStatus::InvalidRecord &&
           live.restore_chunk_checkpoint({9,0},readback)==
               ChunkCheckpointStatus::InvalidRecord &&
           live.save_physical_state()==before_absent,
           "GEN006_BRIDGE_ABSENT_RESTORE_NEGATIVES_CHANGED_WORLD");
    const auto absent_tick_start=live.completed_tick_index();
    std::uint32_t absent_worker_observed=0;
    for (int i=0;i<8;++i) {
        const auto a=live.tick(),b=control.tick();
        observed=std::max(observed,a.worker_threads_observed);
        absent_worker_observed=std::max(absent_worker_observed,a.worker_threads_observed);
        demand(a.tick==b.tick && !live.has_failed() && !control.has_failed(),
               "GEN006_BRIDGE_ABSENT_DYNAMIC_TICK_FAILED");
        demand(live.chunk_count()==remaining_count &&
               live.resident_cell_bytes()==remaining_bytes &&
               live.stored_material(514,2)==Material::Empty,
               "GEN006_BRIDGE_ABSENT_RELEASE_NOT_PRESERVED");
        // Native seam Sand/Water must remain source-matched to the continuously
        // simulated 3-resident oracle; no whole-World pointer substitution.
        for (std::int64_t y=-65;y<-40;++y)
            for (std::int64_t x=-128+18;x<-128+52;++x) {
                demand(live.stored_material(x,y)==control.stored_material(x,y) &&
                       live.liquid_mass(x,y)==control.liquid_mass(x,y) &&
                       live.stored_temperature(x,y)==control.stored_temperature(x,y),
                       "GEN006_BRIDGE_ABSENT_SEAM_DIVERGENCE");
            }
    }
    demand(live.completed_tick_index()==absent_tick_start+8 &&
           absent_worker_observed>0,
           "GEN006_BRIDGE_ABSENT_NO_NATIVE_TICK");
    // Preserve the two ACTIVE native dynamic residents while the distant
    // static G6KC1 owner is absent. Unlike the old static-only cold process
    // control, this image is of the genuine in-place, partially evicted World
    // AFTER it has continued eight real Sand/Water ticks without its third
    // resident. A second process must reconstitute that owner without a
    // full-three-resident image or a mocked chunk lifecycle.
    const auto absent_active_image = live.save_physical_state();
    demand(live.chunk_count() == 2 && live.resident_cell_bytes() == remaining_bytes,
           "GEN006_BRIDGE_ACTIVE_CHECKPOINT_NOT_SELECTIVE");
    durable_write(fs::path(file.string()+".active.cyps"), absent_active_image);
    demand(read_exact(fs::path(file.string()+".active.cyps")) == absent_active_image,
           "GEN006_BRIDGE_ACTIVE_CHECKPOINT_READBACK");

    // Restore only the independently saved static resident, never swap World.
    demand(live.restore_chunk_checkpoint({8,0},readback)==
           ChunkCheckpointStatus::Restored &&
           live.chunk_count()==count &&
           live.resident_cell_bytes()==bytes,
           "GEN006_BRIDGE_STATIC_RESTORE_FAILED");
    demand(live.evict_durable_checkpoint(captured.checkpoint,
                                        ack(captured.checkpoint))==
           ChunkCheckpointStatus::StaleGeneration &&
           live.chunk_count()==count,
           "GEN006_BRIDGE_STALE_ACK_DELETED_NEW_INCARNATION");
    demand(live.gen006_player_edit_intent_at(520,4) &&
           live.stored_temperature(514,2)==417 &&
           live.stored_material(514,2)==Material::Wall,
           "GEN006_BRIDGE_STATIC_INTENT_OR_TEMP_LOSS");
    parity(live,control,"GEN006_BRIDGE_POST_STATIC_RESTORE_PARITY");
    for (int i=0;i<8;++i) {
        const auto a=live.tick(),b=control.tick();
        observed=std::max(observed,a.worker_threads_observed);
        demand(a.tick==b.tick && !live.has_failed() && !control.has_failed(),
               "GEN006_BRIDGE_POST_RESTORE_TICK_FAILED");
        parity(live,control,"GEN006_BRIDGE_POST_RESTORE_PARITY");
    }
    std::cout<<"GEN006_BRIDGE_SHARED_WORLD_STATIC_WITH_LIVE_DYNAMIC_PASS"
             <<" configured_workers="<<workers
             <<" observed_workers_max="<<observed
             <<" sand_and_water_cross_seam=1"
             <<" selected_dynamic_eviction=REFUSED"\n             <<" stale_inflight_durable_ack=REFUSED"
             <<" selective_static_count="<<count<<"->"<<remaining_count<<"->"<<live.chunk_count()
             <<" selective_static_bytes="<<bytes<<"->"<<remaining_bytes<<"->"<<live.resident_cell_bytes()
             <<" static_bytes_reclaimed="<<(bytes-remaining_bytes)
             <<" absent_dynamic_ticks=8"
             <<" absent_observed_workers_max="<<absent_worker_observed
             <<" post_restore_ticks=8"
             <<" final_native_tick="<<live.completed_tick_index()
             <<" final_physical="<<live.physical_state_hash()<<"\n";
}
void reopen(const fs::path& file,std::uint32_t workers) {
    World restored(config(workers));
    const auto original=read_exact(file);
    demand(restored.restore_chunk_checkpoint({8,0},original)==
           ChunkCheckpointStatus::Restored &&
           restored.chunk_count()==1 &&
           restored.stored_material(514,2)==Material::Wall &&
           restored.stored_temperature(514,2)==417 &&
           restored.gen006_player_edit_intent_at(520,4),
           "GEN006_BRIDGE_INDEPENDENT_PROCESS_STATIC_READBACK");
    const auto before=restored.save_physical_state();
    auto bad=original;
    bad[bad.size()/2]^=1;
    demand(restored.restore_chunk_checkpoint({9,0},bad)==
           ChunkCheckpointStatus::InvalidRecord &&
           restored.save_physical_state()==before,
           "GEN006_BRIDGE_CORRUPT_RECORD_ADMITTED");
    std::cout<<"GEN006_BRIDGE_COLD_STATIC_READBACK_PASS configured_workers="
             <<workers<<" resident_chunks="<<restored.chunk_count()
             <<" water_dynamic_bundle_cold_recovery=NOT_PROVEN\n";
}

void resume_partial(const fs::path& file,std::uint32_t workers) {
    // This is a new OS process. No original native World object survives.
    // Its authoritative two moving chunks were saved WHILE the static chunk
    // was selectively absent and Sand/Water simulation had continued.
    const auto active=read_exact(fs::path(file.string()+".active.cyps"));
    const auto static_record=read_exact(file);
    auto invalid=active;
    invalid.back() ^= 1U;
    // The genuine CYPS decoder rejects a corrupt integrity digest by
    // throwing; a null candidate is also refusal. Neither may be mistaken
    // for a failure of the positive two-resident cold continuation.
    bool corrupt_rejected=false;
    try {
        auto corrupt=World::restore_physical_state(config(workers),invalid);
        corrupt_rejected=!corrupt;
    } catch(const std::exception&) {
        corrupt_rejected=true;
    }
    demand(corrupt_rejected,"GEN006_BRIDGE_COLD_CORRUPT_DYNAMIC_CYPS_ADMITTED");
    auto resumed=World::restore_physical_state(config(workers),active);
    demand(resumed && !resumed->has_failed() &&
           resumed->chunk_count()==2 &&
           resumed->save_physical_state()==active,
           "GEN006_BRIDGE_COLD_PARTIAL_DYNAMIC_READBACK");
    const auto dynamic_bytes=resumed->resident_cell_bytes();
    demand(dynamic_bytes>0 && dynamic_bytes<107264 &&
           resumed->stored_material(514,2)==Material::Empty,
           "GEN006_BRIDGE_COLD_STATIC_NOT_ABSENT");

    // Independent scientific oracle is CONSTRUCTED FROM INITIAL MATERIALS,
    // never deserialized from either the staged or saved World.
    World reference(config(workers));
    populate(reference);
    const auto resume_tick=resumed->completed_tick_index();
    demand(resume_tick>=8 && resume_tick<=72,
           "GEN006_BRIDGE_COLD_SOURCE_TICK_OUTSIDE_BOUNDS");
    std::uint32_t observed=0;
    for(std::uint64_t i=0;i<resume_tick;++i) {
        const auto t=reference.tick();
        observed=std::max(observed,t.worker_threads_observed);
        demand(!reference.has_failed(),"GEN006_BRIDGE_COLD_ORACLE_TICK_FAILED");
    }
    auto match_moving=[&](const char* failure) {
        for(std::int64_t y=-128;y<0;++y)
            for(std::int64_t x=-128;x<-64;++x)
                demand(resumed->stored_material(x,y)==reference.stored_material(x,y) &&
                       resumed->liquid_mass(x,y)==reference.liquid_mass(x,y) &&
                       resumed->stored_temperature(x,y)==reference.stored_temperature(x,y),
                       failure);
    };
    match_moving("GEN006_BRIDGE_COLD_MATERIAL_SEAM_MISMATCH");

    // Additional, genuinely executed native dynamics while STILL partially
    // resident after process-cold restoration; then re-admit the static record
    // into the SAME two-resident native World, not a full-World pointer swap.
    for(unsigned i=0;i<4;++i) {
        const auto a=resumed->tick(),b=reference.tick();
        observed=std::max(observed,a.worker_threads_observed);
        demand(a.tick==b.tick && !resumed->has_failed() && !reference.has_failed() &&
               resumed->chunk_count()==2 &&
               resumed->resident_cell_bytes()==dynamic_bytes,
               "GEN006_BRIDGE_COLD_ABSENT_TICK_FAILED");
        match_moving("GEN006_BRIDGE_COLD_ABSENT_SEAM_DIVERGENCE");
    }
    const auto before=resumed->save_physical_state();
    demand(resumed->restore_chunk_checkpoint({9,0},static_record)==
               ChunkCheckpointStatus::InvalidRecord &&
           resumed->save_physical_state()==before,
           "GEN006_BRIDGE_COLD_WRONG_STATIC_CHUNK_ADMITTED");
    demand(resumed->restore_chunk_checkpoint({8,0},static_record)==
               ChunkCheckpointStatus::Restored &&
           resumed->chunk_count()==3 &&
           resumed->resident_cell_bytes()==107264,
           "GEN006_BRIDGE_COLD_PARTIAL_READMISSION_FAILED");
    parity(*resumed,reference,"GEN006_BRIDGE_COLD_REJOIN_DIVERGED");
    for(unsigned i=0;i<8;++i) {
        const auto a=resumed->tick(),b=reference.tick();
        observed=std::max(observed,a.worker_threads_observed);
        demand(a.tick==b.tick && !resumed->has_failed() && !reference.has_failed(),
               "GEN006_BRIDGE_COLD_CONTINUED_TICK_FAILED");
        parity(*resumed,reference,"GEN006_BRIDGE_COLD_CONTINUATION_DIVERGED");
    }
    std::cout<<"GEN006_BRIDGE_COLD_PARTIAL_DYNAMIC_REJOIN_PASS"
             <<" configured_workers="<<workers
             <<" observed_workers_max="<<observed
             <<" cold_source_tick="<<resume_tick
             <<" active_residents=2"
             <<" active_resident_bytes="<<dynamic_bytes
             <<" resumed_absent_ticks=4"
             <<" rejoined_residents="<<resumed->chunk_count()
             <<" post_readmission_ticks=8"
             <<" final_native_tick="<<resumed->completed_tick_index()
             <<" final_physical="<<resumed->physical_state_hash()
             <<" moving_bundle_selective_eviction=NOT_PROVEN\n";
}
}
int main(int argc,char** argv) {
    try {
        if(argc!=3 && argc!=4)
            throw std::invalid_argument("usage: bridge <file> <workers> [--reopen]");
        const auto workers=static_cast<std::uint32_t>(std::stoul(argv[2]));
        demand(workers==1 || workers==4,"GEN006_BRIDGE_BAD_WORKER_ARGUMENT");
        if(argc==4) {
            const std::string mode=argv[3];
            demand(mode=="--reopen" || mode=="--resume-partial",
                   "GEN006_BRIDGE_BAD_MODE");
            if(mode=="--reopen") reopen(argv[1],workers);
            else resume_partial(argv[1],workers);
        } else run(argv[1],workers);
        return 0;
    } catch(const std::exception& e) {
        std::cerr<<"GEN006_BRIDGE_FAILURE "<<e.what()<<"\n";
        return 1;
    }
}
