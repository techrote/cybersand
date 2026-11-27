// GEN-006 #194: independent exact-main native negative control for semantic bundle admission.
// Diagnostic only. No streaming, atomic installation, serializer, or physics changes.
#include "cybersand/world.hpp"

#include <algorithm>
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <vector>

namespace {
using cybersand::ChunkCoord;
using cybersand::ChunkInstallOutcome;
using cybersand::Material;
using cybersand::SimulationBackend;
using cybersand::World;
using cybersand::WorldConfig;

constexpr std::int32_t kSide = 128;
constexpr ChunkCoord kWest{-1, 0};
constexpr ChunkCoord kEast{0, 0};
std::uint64_t checks = 0;

void require(bool condition, const char* detail) {
    ++checks;
    if (!condition) throw std::runtime_error(detail);
}
WorldConfig make_config(std::uint32_t workers, std::size_t capacity = 4) {
    WorldConfig config{};
    config.chunk_size = kSide;
    config.backend = SimulationBackend::PhasedInPlace;
    config.worker_threads = workers;
    config.parallel_job_threshold = 1;
    config.initial_chunk_reserve = capacity;
    config.maximum_chunk_count = capacity;
    config.active_chunk_capacity = 32;
    config.active_core_capacity = 256;
    return config;
}
std::vector<Material> seam_half(bool west) {
    std::vector<Material> cells(static_cast<std::size_t>(kSide) * kSide, Material::Empty);
    // A genuinely connected two-chunk semantic feature across the signed x=-1/0 seam.
    cells[static_cast<std::size_t>(64) * kSide + (west ? kSide - 1 : 0)] = Material::Wall;
    return cells;
}
void run(std::uint32_t workers) {
    const auto config = make_config(workers);
    const auto west = seam_half(true);
    const auto east = seam_half(false);

    // Occupied-and-explicitly-Empty is not the same authority as absent.
    World absent(config);
    World occupied(config);
    occupied.reserve_region({0, 0, 1, 1});
    require(absent.stored_material(0, 64) == Material::Empty &&
                occupied.stored_material(0, 64) == Material::Empty,
            "Empty readback did not match absent/resident distinction control");
    require(absent.chunk_count() == 0 && occupied.chunk_count() == 1,
            "resident-Empty source condition not constructed");
    require(absent.install_generated_chunk(kEast, east) == ChunkInstallOutcome::Installed,
            "an absent chunk should admit the same right-hand proposal");
    require(occupied.install_generated_chunk(kEast, east) ==
                ChunkInstallOutcome::AlreadyResident,
            "resident Empty was inappropriately replaceable");

    // First semantic half commits; second refuses. The native API is deliberately
    // single-chunk. This is a model of an UNSAFE host admission strategy, not a
    // newly discovered defect in the World installer.
    require(occupied.install_generated_chunk(kWest, west) == ChunkInstallOutcome::Installed,
            "first semantic half did not commit");
    require(occupied.install_generated_chunk(kEast, east) ==
                ChunkInstallOutcome::AlreadyResident,
            "already-resident second half was not refused");
    require(occupied.chunk_count() == 2 &&
                occupied.stored_material(-1, 64) == Material::Wall &&
                occupied.stored_material(0, 64) == Material::Empty,
            "partial native semantic bundle not reproduced");

    // Reversing the caller's order avoids that partial commit only if the host
    // stops on first refusal; neither order is a valid bundle atomicity contract.
    World reverse(config);
    reverse.reserve_region({0, 0, 1, 1});
    require(reverse.install_generated_chunk(kEast, east) ==
                ChunkInstallOutcome::AlreadyResident,
            "reverse-order first refusal disappeared");
    require(reverse.chunk_count() == 1 &&
                reverse.stored_material(-1, 64) == Material::Empty,
            "reverse-order refusal unexpectedly installed a half");

    // A resident-budget failure has the same irreversible first-half effect.
    World capacity(make_config(workers, 1));
    require(capacity.install_generated_chunk(kWest, west) ==
                ChunkInstallOutcome::Installed, "capacity control first chunk refused");
    require(capacity.install_generated_chunk(kEast, east) ==
                ChunkInstallOutcome::CapacityFull, "capacity refusal not reproduced");
    require(capacity.chunk_count() == 1 &&
                capacity.stored_material(-1, 64) == Material::Wall &&
                capacity.stored_material(0, 64) == Material::Empty,
            "capacity control did not retain partial semantic feature");

    // Even individually validated payloads cannot retroactively undo earlier
    // chunks after an invalid later proposal.
    World malformed(config);
    auto bad = east;
    bad[0] = static_cast<Material>(0xffffU);
    require(malformed.install_generated_chunk(kWest, west) ==
                ChunkInstallOutcome::Installed, "malformed test first half refused");
    require(malformed.install_generated_chunk(kEast, bad) ==
                ChunkInstallOutcome::InvalidPayload, "later invalid material not refused");
    require(malformed.chunk_count() == 1 &&
                malformed.stored_material(-1, 64) == Material::Wall,
            "malformed later payload mutated previously accepted half");

    // Positive native control: with both absent and enough capacity, both halves
    // install normally; there is NO test-only production bundle API or mutation.
    World good(config);
    World matched(config);
    for (World* world : {&good, &matched}) {
        require(world->install_generated_chunk(kWest, west) ==
                    ChunkInstallOutcome::Installed, "positive West installation refused");
        require(world->install_generated_chunk(kEast, east) ==
                    ChunkInstallOutcome::Installed, "positive East installation refused");
        require(world->stored_material(-1, 64) == Material::Wall &&
                    world->stored_material(0, 64) == Material::Wall,
                "positive semantic seam incomplete");
    }
    std::uint32_t participating = 0;
    for (int t = 0; t < 3; ++t) {
        const auto a = good.tick();
        const auto b = matched.tick();
        participating = std::max(participating, a.worker_threads_observed);
        require(!good.has_failed() && !matched.has_failed(),
                "native tick quarantined a world");
        require(a.tick == b.tick &&
                    good.physical_state_hash() == matched.physical_state_hash() &&
                    good.quantity_ledger() == matched.quantity_ledger(),
                "positive native follow-on control diverged");
    }
    std::cout << "GEN006_BUNDLE_NATIVE configured_workers=" << workers
              << " observed_max_workers=" << participating
              << " signed_seam=-1/0 resident_empty_refused=1"
              << " partial_resident_refusal=1 partial_capacity_refusal=1"
              << " partial_invalid_payload=1 positive_both_installed=1"
              << " continuation_ticks=3 result=PASS checks_so_far=" << checks << '\n';
}
} // namespace

int main() {
    try {
        run(1);
        run(4);
        std::cout << "GEN006_BUNDLE_NATIVE_PASS checks=" << checks << '\n';
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "GEN006_BUNDLE_NATIVE_FAIL checks=" << checks
                  << " detail=" << error.what() << '\n';
        return 1;
    }
}
