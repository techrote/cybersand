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
             <<" selected_dynamic_eviction=REFUSED"
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
}
int main(int argc,char** argv) {
    try {
        if(argc!=3 && argc!=4)
            throw std::invalid_argument("usage: bridge <file> <workers> [--reopen]");
        const auto workers=static_cast<std::uint32_t>(std::stoul(argv[2]));
        demand(workers==1 || workers==4,"GEN006_BRIDGE_BAD_WORKER_ARGUMENT");
        if(argc==4) {
            demand(std::string(argv[3])=="--reopen","GEN006_BRIDGE_BAD_MODE");
            reopen(argv[1],workers);
        } else run(argv[1],workers);
        return 0;
    } catch(const std::exception& e) {
        std::cerr<<"GEN006_BRIDGE_FAILURE "<<e.what()<<"\n";
        return 1;
    }
}
