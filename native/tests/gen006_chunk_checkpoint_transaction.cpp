// GEN006 selective static chunk CYPS continuation, real shared World,
// external durable disk publication and mutation/tick generation fencing.
// No mock/native reconstruction, no unsafe cross-chunk Water admission.
#include "cybersand/world.hpp"

#include <algorithm>
#include <array>
#include <cstdio>
#include <cstdint>
#include <exception>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <limits>
#include <span>
#include <stdexcept>
#include <string>
#include <vector>
#ifdef _WIN32
#include <io.h>
#else
#include <fcntl.h>
#include <unistd.h>
#endif

using namespace cybersand;
namespace fs=std::filesystem;

namespace {
void require(bool yes,const char* why) {
    if(!yes)throw std::runtime_error(why);
}
WorldConfig config(unsigned workers) {
    WorldConfig c;
    c.chunk_size=64;c.activity_block_size=16;c.scheduling_core_size=64;
    c.initial_chunk_reserve=2;c.maximum_chunk_count=2;
    c.active_chunk_capacity=32;c.active_core_capacity=32;
    c.parallel_job_threshold=1;c.worker_threads=workers;
    c.gen006_track_edit_intent=true;
    return c;
}
void persist_exactly(const fs::path& file,std::span<const std::uint8_t> bytes) {
    const fs::path stage=file.string()+".tmp";
    auto* output=std::fopen(stage.string().c_str(),"wb");
    require(output!=nullptr,"GEN006_STORAGE_STAGE_OPEN");
    require(std::fwrite(bytes.data(),1,bytes.size(),output)==bytes.size(),
            "GEN006_STORAGE_SHORT_WRITE");
    require(std::fflush(output)==0,"GEN006_STORAGE_FLUSH");
#ifdef _WIN32
    require(_commit(_fileno(output))==0,"GEN006_STORAGE_DURABLE_COMMIT");
#else
    require(fsync(fileno(output))==0,"GEN006_STORAGE_DURABLE_COMMIT");
#endif
    require(std::fclose(output)==0,"GEN006_STORAGE_CLOSE");
    require(std::rename(stage.string().c_str(),file.string().c_str())==0,
            "GEN006_STORAGE_RENAME");
#ifndef _WIN32
    const auto dir=fs::absolute(file).parent_path();
    const auto fd=open(dir.c_str(),O_RDONLY|O_DIRECTORY);
    require(fd>=0,"GEN006_STORAGE_DIR_OPEN");
    require(fsync(fd)==0,"GEN006_STORAGE_DIR_FSYNC");
    close(fd);
#endif
}
std::vector<std::uint8_t> read_exactly(const fs::path& file) {
    std::ifstream input(file,std::ios::binary|std::ios::ate);
    require(bool(input),"GEN006_STORAGE_READ_OPEN");
    const auto length=input.tellg();
    require(length>0 && length<static_cast<std::streamoff>(16*1024*1024),
            "GEN006_STORAGE_READ_LENGTH");
    input.seekg(0);
    std::vector<std::uint8_t> result(static_cast<std::size_t>(length));
    input.read(reinterpret_cast<char*>(result.data()),length);
    require(bool(input),"GEN006_STORAGE_READ_TRUNCATION");
    return result;
}
ChunkDurableAck ack_for(const ChunkCheckpoint& c,bool durable=true) {
    return {c.coord,c.generation,c.world_tick,c.sha256,durable};
}
void run(const fs::path& root,unsigned workers) {
    require(!fs::exists(root),"GEN006_TEST_FRESH_ROOT");
    fs::create_directories(root);
    const ChunkCoord edited{-16,-8},other{16,8};
    const std::int64_t x=edited.x*64,y=edited.y*64;
    auto empty=std::vector<Material>(4096,Material::Empty);
    auto wmat=empty;
    wmat[30*64+30]=Material::Wall;
    World world(config(workers));
    require(world.install_generated_chunk(edited,empty)==ChunkInstallOutcome::Installed,
            "GEN006_STATIC_FIRST_CHUNK");
    require(world.install_generated_chunk(other,wmat)==ChunkInstallOutcome::Installed,
            "GEN006_STATIC_SECOND_CHUNK");

    // Real native player edits; both a nonempty Wall and an explicit Empty
    // tombstone. Thermal and byte-register state are also source authority.
    world.set(x+8,y+8,Material::Empty); // same-value player intent
    world.set(x+30,y+30,Material::Wall);
    world.set_temperature(x+30,y+30,417);
    require(world.stored_material(x+30,y+30)==Material::Wall &&
            world.stored_temperature(x+30,y+30)==417 &&
            world.gen006_player_edit_intent_at(x+8,y+8) &&
            world.gen006_player_edit_intent_at(x+30,y+30),
            "GEN006_STATIC_AUTHORITATIVE_EDIT");

    // No active kernels/halo/sidecar may be silently frozen. A Wall edit wakes
    // activity; advance bounded real ticks until the native inactivity gate
    // is actually satisfied. No sleep/flag fabrication.
    ChunkCheckpointCapture staged{};
    std::uint32_t observed=0;
    for(int tick=0;tick<32;++tick) {
        const auto s=world.tick();
        observed=std::max(observed,s.worker_threads_observed);
        staged=world.capture_chunk_checkpoint(edited);
        if(staged.status==ChunkCheckpointStatus::Captured)break;
        require(staged.status==ChunkCheckpointStatus::PendingActivity,
                "GEN006_STATIC_UNEXPECTED_CAPTURE_REFUSAL");
    }
    require(staged.status==ChunkCheckpointStatus::Captured,
            "GEN006_STATIC_WORLD_NEVER_SETTLED");
    require(staged.checkpoint.generation>0 &&
            staged.checkpoint.bytes.size()>64*64*8,
            "GEN006_STATIC_CAPTURE_NOT_REAL");
    const auto original_hash=world.physical_state_hash();
    const auto original_bytes=world.resident_cell_bytes();
    const auto original_count=world.chunk_count();
    const auto original_tick=world.completed_tick_index();
    const auto original_gen=staged.checkpoint.generation;
    const auto cell_a=world.stored_state_a(x+30,y+30);
    const auto cell_b=world.stored_state_b(x+30,y+30);
    const auto temperature=world.stored_temperature(x+30,y+30);

    // FAIL-CLOSED: no verified storage ACK, wrong hash, missing file.
    auto no_ack=ack_for(staged.checkpoint,false);
    require(world.evict_durable_checkpoint(staged.checkpoint,no_ack)==
            ChunkCheckpointStatus::MissingDurabilityAck,
            "GEN006_UNACKNOWLEDGED_EVICTION_ACCEPTED");
    auto wrong_hash=ack_for(staged.checkpoint);
    wrong_hash.sha256[0]^=1;
    require(world.evict_durable_checkpoint(staged.checkpoint,wrong_hash)==
            ChunkCheckpointStatus::MissingDurabilityAck &&
            world.physical_state_hash()==original_hash &&
            world.resident_cell_bytes()==original_bytes,
            "GEN006_BAD_ACK_MUTATED_WORLD");

    // A concurrent same-value Empty intent must invalidate the staged
    // generation even though it changes no cell material or simulated mass.
    world.set(x+9,y+9,Material::Empty);
    require(world.evict_durable_checkpoint(staged.checkpoint,ack_for(staged.checkpoint))==
            ChunkCheckpointStatus::StaleGeneration &&
            world.chunk_count()==original_count,
            "GEN006_STALE_SAME_VALUE_EMPTY_ACK_EVICTED");

    staged=world.capture_chunk_checkpoint(edited);
    require(staged.status==ChunkCheckpointStatus::Captured &&
            staged.checkpoint.generation>original_gen,
            "GEN006_RECAPTURE_AFTER_EDIT_NOT_VERSIONED");
    // A tick between snapshot and ACK must refuse even with no cell changes:
    // the source's scheduling epoch is different from the checkpoint.
    (void)world.tick();
    require(world.evict_durable_checkpoint(staged.checkpoint,ack_for(staged.checkpoint))==
            ChunkCheckpointStatus::StaleGeneration,
            "GEN006_STALE_TICK_ACK_EVICTED");
    staged=world.capture_chunk_checkpoint(edited);
    require(staged.status==ChunkCheckpointStatus::Captured,
            "GEN006_POSTTICK_RECAPTURE_REFUSED");

    const fs::path saved=root/"chunk_x-16_y-8.g6c";
    persist_exactly(saved,staged.checkpoint.bytes); // true disk sync+rename
    auto payload=read_exactly(saved);
    require(payload==staged.checkpoint.bytes,"GEN006_STORAGE_ACK_READBACK_DRIFT");
    const auto saved_hash=world.physical_state_hash();
    const auto saved_tick=world.completed_tick_index();
    const auto saved_bytes=world.resident_cell_bytes();
    const auto acknowledged=ack_for(staged.checkpoint);
    require(world.evict_durable_checkpoint(staged.checkpoint,acknowledged)==
            ChunkCheckpointStatus::Evicted,"GEN006_DURABLE_EVICTION_REFUSED");
    require(world.chunk_count()==1 &&
            world.resident_cell_bytes()<saved_bytes &&
            world.stored_material(x+30,y+30)==Material::Empty &&
            world.stored_material(other.x*64+30,other.y*64+30)==Material::Wall,
            "GEN006_SHARED_WORLD_EVICTION_DAMAGED_OTHER_CHUNK");
    // Validate that shared quantity/physics accounting remains serializable
    // after destruction of an edited nonempty resident.
    const auto other_checkpoint=world.save_physical_state();
    require(!other_checkpoint.empty(),"GEN006_SHARED_WORLD_LEDGER_INVALID");

    auto corrupt=payload;corrupt[corrupt.size()/2]^=0x20;
    require(world.restore_chunk_checkpoint(edited,corrupt)==
            ChunkCheckpointStatus::InvalidRecord &&
            world.chunk_count()==1,
            "GEN006_CORRUPT_RESTORE_ADMITTED_OR_MUTATED");
    require(world.restore_chunk_checkpoint({-15,-8},payload)==
            ChunkCheckpointStatus::InvalidRecord &&
            world.chunk_count()==1,
            "GEN006_CROSS_COORDINATE_RESTORE_ADMITTED");

    require(world.restore_chunk_checkpoint(edited,payload)==
            ChunkCheckpointStatus::Restored,
            "GEN006_REAL_NATIVE_REHYDRATION_REFUSED");
    require(world.chunk_count()==2 &&
            world.stored_material(x+30,y+30)==Material::Wall &&
            world.stored_state_a(x+30,y+30)==cell_a &&
            world.stored_state_b(x+30,y+30)==cell_b &&
            world.stored_temperature(x+30,y+30)==temperature &&
            world.completed_tick_index()==saved_tick &&
            world.gen006_player_edit_intent_at(x+8,y+8) &&
            world.gen006_player_edit_intent_at(x+9,y+9) &&
            world.gen006_player_edit_intent_at(x+30,y+30),
            "GEN006_LOSSLESS_STATIC_CELLS_TEMPERATURE_INTENT_DRIFT");
    require(world.restore_chunk_checkpoint(edited,payload)==
            ChunkCheckpointStatus::AlreadyResident,
            "GEN006_DUPLICATE_RESTORE_ADMITTED");
    const auto restored_checkpoint=world.capture_chunk_checkpoint(edited);
    require(restored_checkpoint.status==ChunkCheckpointStatus::Captured &&
            restored_checkpoint.checkpoint.generation==staged.checkpoint.generation,
            "GEN006_LOSSLESS_GENERATION_RESTORE_DRIFT");
    const auto after_restore=world.save_physical_state();
    require(!after_restore.empty(),"GEN006_RESTORED_LEDGER_INVALID");

    // New-process native World, fresh execution clock, same immutable envelope:
    // exact Wall+temperature edited bytes are recovered without regeneration.
    World restarted(config(workers));
    require(restarted.restore_chunk_checkpoint(edited,payload)==
            ChunkCheckpointStatus::Restored &&
            restarted.stored_material(x+30,y+30)==Material::Wall &&
            restarted.stored_state_a(x+30,y+30)==cell_a &&
            restarted.stored_state_b(x+30,y+30)==cell_b &&
            restarted.stored_temperature(x+30,y+30)==temperature &&
            restarted.gen006_player_edit_intent_at(x+8,y+8) &&
            restarted.gen006_player_edit_intent_at(x+9,y+9) &&
            restarted.gen006_player_edit_intent_at(x+30,y+30),
            "GEN006_NEW_WORLD_RESTART_RESTORE_FAILED");

    // Uncheckpointed dynamic Water and adjacent resident haloes stay pinned.
    World unsupported(config(workers));
    require(unsupported.install_generated_chunk(edited,empty)==ChunkInstallOutcome::Installed,
            "GEN006_WATER_SETUP");
    require(unsupported.set_cell_state(x+20,y+20,Material::Water,17,0),
            "GEN006_WATER_EDIT_REFUSED");
    require(unsupported.capture_chunk_checkpoint(edited).status==
            ChunkCheckpointStatus::UnsupportedDomain,
            "GEN006_DYNAMIC_WATER_WAS_MISCLASSIFIED_STATIC");

    World neighbours(config(workers));
    require(neighbours.install_generated_chunk({-1,2},empty)==ChunkInstallOutcome::Installed &&
            neighbours.install_generated_chunk({0,2},empty)==ChunkInstallOutcome::Installed,
            "GEN006_HALO_SETUP");
    require(neighbours.capture_chunk_checkpoint({-1,2}).status==
            ChunkCheckpointStatus::NeighbourPinned,
            "GEN006_NEIGHBOUR_CAPACITY_RELEASED_UNSAFELY");

    std::cout<<"GEN006_LOSSLESS_STATIC_CHUNK_TRANSACTION_PASS"
             <<" configured_workers="<<workers
             <<" observed_workers="<<observed
             <<" same_shared_world=1"
             <<" wall=RESTORED"
             <<" temperature417=RESTORED"
             <<" cell_registers=RESTORED"
             <<" cell_specific_Empty_intent=RESTORED"
             <<" mutation_generation="<<staged.checkpoint.generation
             <<" durable_fsync_atomic_rename=1"
             <<" stale_edit=REFUSED stale_tick=REFUSED"
             <<" corrupt=REFUSED wrong_coordinate=REFUSED"
             <<" ledger_valid_after_release_and_restore=1"
             <<" fresh_native_world_restore=1"
             <<" Water_and_neighbour=PINNED"
             <<" preserved_other_resident=1\n";
}
}

void sand_continuation_test(unsigned workers) {
    // Real moving Sand settles within a sealed Wall perimeter. Only the
    // inactive, no-future-deadline state is exportable; pre-settlement motion
    // must never be captured. Compare native cell tuples against an
    // uninterrupted whole-World CYPS reference after import.
    auto cfg=config(workers);
    cfg.maximum_chunk_count=2;
    const ChunkCoord sand_coord{-30,16};
    auto cells=std::vector<Material>(4096,Material::Empty);
    for(int n=0;n<64;++n) {
        cells[static_cast<std::size_t>(n)]=Material::Wall;
        cells[63U*64U+static_cast<std::size_t>(n)]=Material::Wall;
        cells[static_cast<std::size_t>(n)*64U]=Material::Wall;
        cells[static_cast<std::size_t>(n)*64U+63U]=Material::Wall;
    }
    cells[10*64+30]=Material::Sand;
    cells[11*64+30]=Material::Sand;
    World w(cfg);
    require(w.install_generated_chunk(sand_coord,cells)==ChunkInstallOutcome::Installed,
            "GEN006_SEALED_SAND_ADMISSION");
    ChunkCheckpointCapture packet{};
    bool observed_dynamic_refusal=false;
    for(int t=0;t<192;++t) {
        packet=w.capture_chunk_checkpoint(sand_coord);
        if(packet.status==ChunkCheckpointStatus::PendingActivity)
            observed_dynamic_refusal=true;
        if(packet.status==ChunkCheckpointStatus::Captured)break;
        require(packet.status==ChunkCheckpointStatus::PendingActivity,
                "GEN006_UNEXPECTED_SAND_PRESETTLEMENT_REFUSAL");
        (void)w.tick();
    }
    require(observed_dynamic_refusal,"GEN006_NO_SAND_MOVEMENT_REFUSAL");
    require(packet.status==ChunkCheckpointStatus::Captured,
            "GEN006_SEALED_SAND_DID_NOT_SETTLE");
    auto reference=World::restore_physical_state(cfg,w.save_physical_state());
    require(reference && !reference->has_failed(),
            "GEN006_SAND_UNINTERRUPTED_REFERENCE");
    const auto origin=packet.checkpoint.coord;
    const auto digest_before=packet.checkpoint.sha256;
    const auto ack=ack_for(packet.checkpoint);
    require(w.evict_durable_checkpoint(packet.checkpoint,ack)==ChunkCheckpointStatus::Evicted,
            "GEN006_QUIESCENT_SAND_RELEASE_REFUSED");
    (void)w.tick();
    (void)reference->tick();
    require(w.restore_chunk_checkpoint(origin,packet.checkpoint.bytes)==
            ChunkCheckpointStatus::Restored,
            "GEN006_QUIESCENT_SAND_REHYDRATION_REFUSED");
    for(int t=0;t<3;++t) {
        (void)w.tick();
        (void)reference->tick();
    }
    for(int y=0;y<64;++y)for(int x=0;x<64;++x) {
        const auto xx=origin.x*64+x, yy=origin.y*64+y;
        require(w.stored_material(xx,yy)==reference->stored_material(xx,yy) &&
                w.stored_state_a(xx,yy)==reference->stored_state_a(xx,yy) &&
                w.stored_state_b(xx,yy)==reference->stored_state_b(xx,yy) &&
                w.stored_temperature(xx,yy)==reference->stored_temperature(xx,yy),
                "GEN006_SEALED_SAND_CONTINUATION_DIVERGED");
    }
    require(w.quantity_ledger().material_cells==reference->quantity_ledger().material_cells,
            "GEN006_SAND_QUANTITY_COUNT_DIVERGED");
    std::cout<<"GEN006_SEALED_SAND_CHECKPOINT_CONTINUATION_PASS"
             <<" configured_workers="<<workers
             <<" motion_refused_until_quiescent=1"
             <<" full_wall_boundary=1"
             <<" SHA256="<<int(digest_before[0])
             <<" resumed_native_cells=4096"
             <<" continuation_ticks=3\n";
}

int main(int argc,char** argv) {
    try {
        require(argc==3,"usage: gen006-chunk-transaction ROOT 1|4");
        const auto workers=static_cast<unsigned>(std::stoul(argv[2]));
        require(workers==1||workers==4,"GEN006_INVALID_WORKERS");
        run(argv[1],workers);
        sand_continuation_test(workers);
        return 0;
    } catch(const std::exception& ex) {
        std::cerr<<"GEN006_LOSSLESS_STATIC_CHUNK_TRANSACTION_FAIL "<<ex.what()<<'\n';
        return 1;
    }
}
