// GEN006 support-only native regression: stale durable ACK must not erase a new
// residency of the same signed chunk with byte-identical G6KC1 contents.
// Uses actual CyberSand World and a real durable filesystem publication.
#include "cybersand/world.hpp"
#include <algorithm>
#include <cstdio>
#include <cstdint>
#include <exception>
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

using namespace cybersand;
namespace fs = std::filesystem;
namespace {
void require(bool value, const char* message) {
    if (!value) throw std::runtime_error(message);
}
WorldConfig config(unsigned workers) {
    WorldConfig cfg;
    cfg.chunk_size = 64;
    cfg.activity_block_size = 16;
    cfg.scheduling_core_size = 64;
    cfg.initial_chunk_reserve = 2;
    cfg.maximum_chunk_count = 2;
    cfg.active_chunk_capacity = 32;
    cfg.active_core_capacity = 32;
    cfg.parallel_job_threshold = 1;
    cfg.worker_threads = workers;
    cfg.gen006_track_edit_intent = true;
    return cfg;
}
void durable_publish(const fs::path& file, const std::vector<std::uint8_t>& bytes) {
    const fs::path staging = file.string() + ".tmp";
    FILE* out = std::fopen(staging.string().c_str(), "wb");
    require(out != nullptr, "ABA_STAGE_OPEN");
    require(std::fwrite(bytes.data(), 1, bytes.size(), out) == bytes.size(),
            "ABA_STAGE_WRITE");
    require(std::fflush(out) == 0, "ABA_STAGE_FLUSH");
#ifdef _WIN32
    require(_commit(_fileno(out)) == 0, "ABA_STAGE_COMMIT");
#else
    require(fsync(fileno(out)) == 0, "ABA_STAGE_FSYNC");
#endif
    require(std::fclose(out) == 0, "ABA_STAGE_CLOSE");
    require(std::rename(staging.string().c_str(), file.string().c_str()) == 0,
            "ABA_ATOMIC_RENAME");
#ifndef _WIN32
    const auto dir = fs::absolute(file).parent_path();
    const int fd = open(dir.c_str(), O_RDONLY | O_DIRECTORY);
    require(fd >= 0, "ABA_DIR_OPEN");
    require(fsync(fd) == 0, "ABA_DIR_FSYNC");
    require(close(fd) == 0, "ABA_DIR_CLOSE");
#endif
    std::ifstream input(file, std::ios::binary);
    require(bool(input), "ABA_READBACK_OPEN");
    const std::vector<std::uint8_t> restored(
        std::istreambuf_iterator<char>(input), std::istreambuf_iterator<char>{});
    require(restored == bytes, "ABA_READBACK_MISMATCH");
}
int run(const fs::path& root, unsigned workers) {
    fs::create_directories(root);
    const ChunkCoord coord{-16, -8}, independent{16, 8};
    const std::int64_t x = coord.x * 64, y = coord.y * 64;
    const std::vector<Material> empty(4096, Material::Empty);
    World world(config(workers));
    require(world.install_generated_chunk(coord, empty) ==
            ChunkInstallOutcome::Installed, "ABA_PRIMARY_ADMISSION");
    require(world.install_generated_chunk(independent, empty) ==
            ChunkInstallOutcome::Installed, "ABA_SECONDARY_ADMISSION");
    world.set(x + 8, y + 8, Material::Empty); // no-op Empty intent matters
    world.set(x + 30, y + 30, Material::Wall);
    world.set_temperature(x + 30, y + 30, 417);
    require(world.gen006_player_edit_intent_at(x + 8, y + 8) &&
            world.stored_temperature(x + 30, y + 30) == 417, "ABA_EDIT_SETUP");

    ChunkCheckpointCapture first{};
    for (int t = 0; t < 32; ++t) {
        (void)world.tick(); // native scheduler must settle honestly
        first = world.capture_chunk_checkpoint(coord);
        if (first.status == ChunkCheckpointStatus::Captured) break;
        require(first.status == ChunkCheckpointStatus::PendingActivity,
                "ABA_CAPTURE_UNEXPECTED_REFUSAL");
    }
    require(first.status == ChunkCheckpointStatus::Captured, "ABA_NEVER_SETTLED");
    durable_publish(root / "residency-A.g6c", first.checkpoint.bytes);
    const ChunkDurableAck old_ack {
        first.checkpoint.coord, first.checkpoint.generation,
        first.checkpoint.world_tick, first.checkpoint.sha256, true,
        first.checkpoint.admission_incarnation
    };
    require(world.evict_durable_checkpoint(first.checkpoint, old_ack) ==
            ChunkCheckpointStatus::Evicted, "ABA_A_DURABLE_EVICTION");
    require(world.chunk_count() == 1, "ABA_A_NOT_REMOVED");

    // A new native Chunk is installed at the exact same coordinate, reusing
    // identical saved bytes. The old ACK must not authorize deleting B.
    require(world.restore_chunk_checkpoint(coord, first.checkpoint.bytes) ==
            ChunkCheckpointStatus::Restored, "ABA_B_REAL_RESTORATION");
    const auto second = world.capture_chunk_checkpoint(coord);
    require(second.status == ChunkCheckpointStatus::Captured &&
            second.checkpoint.bytes == first.checkpoint.bytes &&
            second.checkpoint.sha256 == first.checkpoint.sha256,
            "ABA_EQUAL_BYTES_CONTROL_FAILED");
    require(first.checkpoint.admission_incarnation > 0 &&
            second.checkpoint.admission_incarnation >
                first.checkpoint.admission_incarnation,
            "ABA_RESTORED_INCARCATION_MUST_ADVANCE");
    const auto before_hash = world.physical_state_hash();
    const auto before_state_hash = world.state_hash();
    const auto before_ledger = world.quantity_ledger();
    const auto before_bytes = world.resident_cell_bytes();
    const auto before_tick = world.completed_tick_index();
    const auto stale_outcome = world.evict_durable_checkpoint(first.checkpoint, old_ack);
    if (stale_outcome == ChunkCheckpointStatus::Evicted) {
        std::cerr << "GEN006_RESIDENCY_ABA_VULNERABLE"
                  << " configured_workers=" << workers
                  << " signed_chunk=(-16,-8)"
                  << " old_ack_replayed_on_new_residency=1"
                  << " native_chunk_B_destroyed=1"
                  << " original_G6KC1_bytes_identical=1\n";
        return 2;
    }
    require(world.chunk_count() == 2 &&
            world.resident_cell_bytes() == before_bytes &&
            world.physical_state_hash() == before_hash &&
            world.state_hash() == before_state_hash &&
            world.quantity_ledger() == before_ledger &&
            world.completed_tick_index() == before_tick &&
            world.stored_material(x + 30, y + 30) == Material::Wall &&
            world.stored_temperature(x + 30, y + 30) == 417 &&
            world.gen006_player_edit_intent_at(x + 8, y + 8),
            "ABA_STALE_REFUSAL_MUTATED_B");
    // Refusing the stale A must not disable legitimate eviction of B.
    const ChunkDurableAck fresh_ack {
        second.checkpoint.coord, second.checkpoint.generation,
        second.checkpoint.world_tick, second.checkpoint.sha256, true,
        second.checkpoint.admission_incarnation
    };
    durable_publish(root / "residency-B.g6c", second.checkpoint.bytes);
    require(world.evict_durable_checkpoint(second.checkpoint, fresh_ack) ==
            ChunkCheckpointStatus::Evicted, "ABA_FRESH_B_EVICTION_REFUSED");
    // World::clear must not recycle native admission identity.
    world.clear();
    require(world.chunk_count() == 0, "ABA_CLEAR_DID_NOT_FREE_WORLD");
    require(world.install_generated_chunk(coord, empty) ==
            ChunkInstallOutcome::Installed, "ABA_C_POST_CLEAR_ADMISSION");
    world.set(x + 8, y + 8, Material::Empty);
    world.set(x + 30, y + 30, Material::Wall);
    world.set_temperature(x + 30, y + 30, 417);
    ChunkCheckpointCapture third{};
    for (int t = 0; t < 32; ++t) {
        (void)world.tick();
        third = world.capture_chunk_checkpoint(coord);
        if (third.status == ChunkCheckpointStatus::Captured) break;
        require(third.status == ChunkCheckpointStatus::PendingActivity,
                "ABA_POST_CLEAR_CAPTURE_UNEXPECTED_REFUSAL");
    }
    require(third.status == ChunkCheckpointStatus::Captured &&
            third.checkpoint.admission_incarnation >
                second.checkpoint.admission_incarnation,
            "ABA_POST_CLEAR_INCARCATION_RECYCLED");
    const auto c_hash = world.physical_state_hash();
    const auto c_state = world.state_hash();
    const auto c_ledger = world.quantity_ledger();
    const auto c_bytes = world.resident_cell_bytes();
    const auto c_tick = world.completed_tick_index();
    require(world.evict_durable_checkpoint(second.checkpoint, fresh_ack) !=
                ChunkCheckpointStatus::Evicted &&
            world.evict_durable_checkpoint(third.checkpoint, fresh_ack) ==
                ChunkCheckpointStatus::MissingDurabilityAck &&
            world.chunk_count() == 1 &&
            world.physical_state_hash() == c_hash &&
            world.state_hash() == c_state &&
            world.quantity_ledger() == c_ledger &&
            world.resident_cell_bytes() == c_bytes &&
            world.completed_tick_index() == c_tick &&
            world.stored_material(x + 30, y + 30) == Material::Wall &&
            world.stored_temperature(x + 30, y + 30) == 417 &&
            world.gen006_player_edit_intent_at(x + 8, y + 8),
            "ABA_STALE_B_ACK_OR_CLEAR_MUTATED_C");
    durable_publish(root / "residency-C.g6c", third.checkpoint.bytes);
    const ChunkDurableAck fresh_c_ack {
        third.checkpoint.coord, third.checkpoint.generation,
        third.checkpoint.world_tick, third.checkpoint.sha256, true,
        third.checkpoint.admission_incarnation
    };
    require(world.evict_durable_checkpoint(third.checkpoint, fresh_c_ack) ==
            ChunkCheckpointStatus::Evicted && world.chunk_count() == 0,
            "ABA_FRESH_C_ACK_OR_CLEAR_EVICTION_REFUSED");
    std::cout << "GEN006_CLEAR_C_INCARCATION_PASS"
              << " stale_B_after_clear_refused=1"
              << " fresh_C_ack_accepted=1\n";
    std::cout << "GEN006_RESIDENCY_ABA_FENCE_PASS"
              << " configured_workers=" << workers
              << " signed_chunk=(-16,-8)"
              << " exact_bytes_equal=1 old_ack_refused=1"
              << " native_B_preserved=1 fresh_B_ack_accepted=1\n";
    return 0;
}
}
int main(int argc, char** argv) {
    try {
        require(argc == 3, "usage: gen006-aba-test STORAGE_ROOT 1|4");
        const auto workers = static_cast<unsigned>(std::stoul(argv[2]));
        require(workers == 1 || workers == 4, "ABA_WORKERS");
        return run(argv[1], workers);
    } catch (const std::exception& error) {
        std::cerr << "GEN006_RESIDENCY_ABA_FIXTURE_FAIL " << error.what() << '\n';
        return 1;
    }
}
