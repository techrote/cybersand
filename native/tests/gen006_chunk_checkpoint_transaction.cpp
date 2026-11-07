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
    return {c.coord,c.generation,c.world_tick,c.sha256,durable,c.admission_incarnation};
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
            restored_checkpoint.checkpoint.generation==staged.checkpoint.generation &&
            restored_checkpoint.checkpoint.bytes==staged.checkpoint.bytes &&
            restored_checkpoint.checkpoint.sha256==staged.checkpoint.sha256,
            "GEN006_LOSSLESS_BYTE_FOR_BYTE_ROUNDTRIP_DRIFT");
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
             <<" exact_checkpoint_bytes=IDENTICAL"
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

void sand_boundary_refusal_test(unsigned workers) {
    // The real granular Sand rule can claim additional native boundary
    // chunks even inside a visual Wall perimeter. A one-chunk checkpoint
    // MUST refuse rather than erase the newly owned neighbour/halo.
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
    bool has_native_neighbour=false;
    std::uint64_t requested_tick=0;
    for(int t=0;t<96;++t) {
        const auto before_hash=w.physical_state_hash();
        const auto before_bytes=w.resident_cell_bytes();
        const auto before_count=w.chunk_count();
        auto capture=w.capture_chunk_checkpoint(sand_coord);
        require(w.physical_state_hash()==before_hash &&
                w.resident_cell_bytes()==before_bytes &&
                w.chunk_count()==before_count,
                "GEN006_SAND_CAPTURE_REFUSAL_MUTATED_WORLD");
        require(capture.status!=ChunkCheckpointStatus::Captured,
                "GEN006_DYNAMIC_SAND_UNSAFE_CHECKPOINT_ACCEPTED");
        if(capture.status==ChunkCheckpointStatus::NeighbourPinned) {
            has_native_neighbour=true;
            requested_tick=w.completed_tick_index();
            break;
        }
        require(capture.status==ChunkCheckpointStatus::UnsupportedDomain ||
                capture.status==ChunkCheckpointStatus::PendingActivity,
                "GEN006_UNEXPECTED_DYNAMIC_SAND_REFUSAL");
        (void)w.tick();
    }
    require(has_native_neighbour && w.chunk_count()==2 &&
            !w.has_failed(),"GEN006_REAL_SAND_NEIGHBOUR_RACE_NOT_REPRODUCED");
    std::cout<<"GEN006_DYNAMIC_SAND_HALO_REFUSAL_PASS"
             <<" configured_workers="<<workers
             <<" native_tick="<<requested_tick
             <<" resident_chunks=2"
             <<" boundary_owner=PINNED"
             <<" checkpoint=REFUSED"
             <<" native_state=UNCHANGED_ON_REFUSAL\n";
}

// Executed by the matching Python fixture, which alters both signed chunk
// coordinates in a genuine G6KC1 record and recomputes its valid SHA-256.
// The native World, not the Python reference model, decides admissibility.
void verify_signed_extent_record(const fs::path& path, unsigned workers,
                                 ChunkCoord coordinate, bool admissible) {
    const auto record=read_exactly(path);
    World world(config(workers));
    const auto before_hash=world.physical_state_hash();
    const auto before_bytes=world.resident_cell_bytes();
    const auto before_count=world.chunk_count();
    const auto result=world.restore_chunk_checkpoint(coordinate,record);
    if(admissible) {
        require(result==ChunkCheckpointStatus::Restored &&
                world.chunk_count()==before_count+1 &&
                world.resident_cell_bytes()>before_bytes,
                "GEN006_SIGNED_SAFE_ENDPOINT_REFUSED");
        // A new native World has a fresh completed tick. Do not demand
        // byte-identical checkpoint timestamps across independent processes.
        const auto x=coordinate.x*static_cast<std::int64_t>(world.config().chunk_size);
        const auto y=coordinate.y*static_cast<std::int64_t>(world.config().chunk_size);
        const auto recaptured=world.capture_chunk_checkpoint(coordinate);
        require(recaptured.status==ChunkCheckpointStatus::Captured &&
                world.stored_material(x+30,y+30)==Material::Wall &&
                world.stored_temperature(x+30,y+30)==417 &&
                world.gen006_player_edit_intent_at(x+8,y+8),
                "GEN006_SIGNED_SAFE_ENDPOINT_STATE_OR_INTENT_DRIFT");
    } else {
        require(result==ChunkCheckpointStatus::InvalidRecord &&
                world.chunk_count()==before_count &&
                world.resident_cell_bytes()==before_bytes &&
                world.physical_state_hash()==before_hash,
                "GEN006_HASHED_OVERFLOW_RECORD_ADMITTED_OR_MUTATED");
    }
    std::cout<<"GEN006_SIGNED_EXTENT_NATIVE_PASS"
             <<" configured_workers="<<workers
             <<" x="<<coordinate.x<<" y="<<coordinate.y
             <<" admissible="<<admissible
             <<" actual_result="<<static_cast<int>(result)
             <<" atomic="<<(admissible ? "RESTORED" : "REFUSED")<<"\n";
}

void verify_separate_native_process(const fs::path& root,unsigned workers) {
    // CI invokes this mode through a NEW operating-system process, after the
    // previous command published the file with fsync/atomic rename and exited.
    const auto bytes=read_exactly(root/"chunk_x-16_y-8.g6c");
    World fresh(config(workers));
    const ChunkCoord wanted{-16,-8};
    const auto x=wanted.x*64,y=wanted.y*64;
    require(fresh.restore_chunk_checkpoint(wanted,bytes)==
            ChunkCheckpointStatus::Restored,"GEN006_NEW_PROCESS_RESTORE_REFUSED");
    require(fresh.chunk_count()==1 &&
            fresh.stored_material(x+30,y+30)==Material::Wall &&
            fresh.stored_temperature(x+30,y+30)==417 &&
            fresh.gen006_player_edit_intent_at(x+8,y+8) &&
            fresh.gen006_player_edit_intent_at(x+9,y+9) &&
            fresh.gen006_player_edit_intent_at(x+30,y+30),
            "GEN006_CROSS_PROCESS_LOSSLESS_STATE_OR_INTENT_DRIFT");
    require(!fresh.save_physical_state().empty(),
            "GEN006_CROSS_PROCESS_QUANTITY_LEDGER_INVALID");
    std::cout<<"GEN006_CHUNK_RESTART_PROCESS_PASS"
             <<" configured_workers="<<workers
             <<" disk_source=G6KC1"
             <<" actual_new_os_process=1"
             <<" wall_temp417=RESTORED"
             <<" exact_Empty_tombstones=RESTORED"
             <<" source_authority=SHA256_VERIFIED\n";
}


void static_continuation_test(const fs::path& root,unsigned workers) {
    // Compare the same native World source, same exact edits and same clock:
    // one World never evicts, the other loses and restores native ownership.
    auto cfg=config(workers);
    cfg.maximum_chunk_count=3;
    cfg.initial_chunk_reserve=3;
    const ChunkCoord edited{-16,-8}, independent{16,8}, neighbour{-15,-8};
    const std::int64_t x=edited.x*64,y=edited.y*64;
    std::vector<Material> empty(4096,Material::Empty);
    auto walls=empty;
    walls[30*64+30]=Material::Wall;
    World uninterrupted(cfg), recovered(cfg);
    for(World* w:{&uninterrupted,&recovered}) {
        require(w->install_generated_chunk(edited,empty)==ChunkInstallOutcome::Installed &&
                w->install_generated_chunk(independent,walls)==ChunkInstallOutcome::Installed,
                "GEN006_CONTINUATION_SETUP");
        w->set(x+8,y+8,Material::Empty);
        w->set(x+30,y+30,Material::Wall);
        w->set_temperature(x+30,y+30,417);
        w->set(x+9,y+9,Material::Empty);
    }
    auto parity=[&](const char* why) {
        if(uninterrupted.physical_state_hash()!=recovered.physical_state_hash() ||
           uninterrupted.content_hash()!=recovered.content_hash() ||
           uninterrupted.state_hash()!=recovered.state_hash() ||
           uninterrupted.quantity_ledger()!=recovered.quantity_ledger() ||
           uninterrupted.completed_tick_index()!=recovered.completed_tick_index() ||
           uninterrupted.chunk_count()!=recovered.chunk_count() ||
           uninterrupted.resident_cell_bytes()!=recovered.resident_cell_bytes()) {
            std::cerr<<"GEN006_CONTINUATION_PARITY_DIAGNOSTIC"
                     <<" control_physical="<<uninterrupted.physical_state_hash()
                     <<" restored_physical="<<recovered.physical_state_hash()
                     <<" control_content="<<uninterrupted.content_hash()
                     <<" restored_content="<<recovered.content_hash()
                     <<" control_tick="<<uninterrupted.completed_tick_index()
                     <<" restored_tick="<<recovered.completed_tick_index()
                     <<" control_cells="<<uninterrupted.resident_cell_bytes()
                     <<" restored_cells="<<recovered.resident_cell_bytes()<<"\n";
            require(false,why);
        }
    };
    parity("GEN006_CONTINUATION_INITIAL_PARITY");
    ChunkCheckpointCapture captured{};
    std::uint32_t observed_control=0,observed_recovered=0;
    for(int attempt=0;attempt<32;++attempt) {
        auto a=uninterrupted.tick(),b=recovered.tick();
        observed_control=std::max(observed_control,a.worker_threads_observed);
        observed_recovered=std::max(observed_recovered,b.worker_threads_observed);
        parity("GEN006_CONTINUATION_PRE_EVICTION_PARITY");
        captured=recovered.capture_chunk_checkpoint(edited);
        if(captured.status==ChunkCheckpointStatus::Captured)break;
        require(captured.status==ChunkCheckpointStatus::PendingActivity,
                "GEN006_CONTINUATION_UNEXPECTED_REFUSAL");
    }
    require(captured.status==ChunkCheckpointStatus::Captured,
            "GEN006_CONTINUATION_CAPTURE_UNSETTLED");
    const auto original_bytes=captured.checkpoint.bytes;
    const auto original_incarnation=captured.checkpoint.admission_incarnation;
    persist_exactly(root/"continuation.g6c",original_bytes);
    require(read_exactly(root/"continuation.g6c")==original_bytes,
            "GEN006_CONTINUATION_DURABLE_READBACK");
    const auto prior_cells=recovered.resident_cell_bytes();
    const auto prior_count=recovered.chunk_count();
    require(recovered.evict_durable_checkpoint(
                captured.checkpoint,ack_for(captured.checkpoint))==
                ChunkCheckpointStatus::Evicted &&
            recovered.resident_cell_bytes()<prior_cells &&
            recovered.chunk_count()+1==prior_count,
            "GEN006_CONTINUATION_CAPACITY_NOT_RECLAIMED");
    require(recovered.restore_chunk_checkpoint(edited,original_bytes)==
            ChunkCheckpointStatus::Restored &&
            recovered.resident_cell_bytes()==prior_cells &&
            recovered.chunk_count()==prior_count,
            "GEN006_CONTINUATION_RESTORE_CAPACITY_DRIFT");
    const auto recheck=recovered.capture_chunk_checkpoint(edited);
    require(recheck.status==ChunkCheckpointStatus::Captured &&
            recheck.checkpoint.bytes==original_bytes &&
            recheck.checkpoint.admission_incarnation>original_incarnation &&
            recovered.gen006_player_edit_intent_at(x+8,y+8) &&
            recovered.gen006_player_edit_intent_at(x+9,y+9) &&
            recovered.stored_temperature(x+30,y+30)==417,
            "GEN006_CONTINUATION_SAVED_STATE_DRIFT");
    parity("GEN006_CONTINUATION_POST_RESTORE_PARITY");

    // Admit a formerly absent adjacent signed chunk in BOTH Worlds, then
    // execute genuine native neighbour scheduling/reads for four ticks.
    require(uninterrupted.install_generated_chunk(neighbour,empty)==
                ChunkInstallOutcome::Installed &&
            recovered.install_generated_chunk(neighbour,empty)==
                ChunkInstallOutcome::Installed,
            "GEN006_CONTINUATION_NEIGHBOUR_ADMISSION");
    parity("GEN006_CONTINUATION_NEIGHBOUR_PARITY");
    for(int tick=0;tick<4;++tick) {
        const auto a=uninterrupted.tick(),b=recovered.tick();
        observed_control=std::max(observed_control,a.worker_threads_observed);
        observed_recovered=std::max(observed_recovered,b.worker_threads_observed);
        parity("GEN006_CONTINUATION_TICK_PARITY");
        require(recovered.stored_material(x+30,y+30)==Material::Wall &&
                recovered.stored_temperature(x+30,y+30)==417 &&
                recovered.gen006_player_edit_intent_at(x+8,y+8) &&
                recovered.gen006_player_edit_intent_at(x+9,y+9),
                "GEN006_CONTINUATION_EDIT_INTENT_DRIFT");
    }
    std::cout<<"GEN006_STATIC_CONTINUATION_PASS"
             <<" configured_workers="<<workers
             <<" observed_control="<<observed_control
             <<" observed_recovered="<<observed_recovered
             <<" fixed_ticks=4 neighbour_admission=1"
             <<" physical_content_ledger_clock_equal=1"
             <<" native_bytes_reclaimed=1 empty_intent=1 temperature417=1\n";
}


int main(int argc,char** argv) {
    try {
        const bool extent=argc==7 && std::string(argv[1])=="--extent";
        const bool reopen=argc==4 && std::string(argv[1])=="--reopen";
        require(extent || reopen || argc==3,
                "usage: gen006-chunk-transaction ROOT 1|4 OR --reopen ROOT 1|4 OR --extent RECORD 1|4 X Y 0|1");
        const auto workers=static_cast<unsigned>(std::stoul(argv[extent?3:reopen?3:2]));
        require(workers==1||workers==4,"GEN006_INVALID_WORKERS");
        if(extent) {
            const auto x=static_cast<std::int64_t>(std::stoll(argv[4]));
            const auto y=static_cast<std::int64_t>(std::stoll(argv[5]));
            const auto admit=std::string(argv[6])=="1";
            require(admit || std::string(argv[6])=="0","GEN006_INVALID_EXTENT_EXPECTATION");
            verify_signed_extent_record(argv[2],workers,{x,y},admit);
        } else if (reopen) verify_separate_native_process(argv[2],workers);
        else {
            run(argv[1],workers);
            sand_boundary_refusal_test(workers);
            static_continuation_test(argv[1],workers);
        }
        return 0;
    } catch(const std::exception& ex) {
        std::cerr<<"GEN006_LOSSLESS_STATIC_CHUNK_TRANSACTION_FAIL "<<ex.what()<<'\n';
        return 1;
    }
}
