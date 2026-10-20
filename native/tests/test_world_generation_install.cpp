#include "cybersand/world.hpp"

#include <array>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <vector>

namespace cybersand {
// The existing native test friend verifies the explicit between-ticks guard
// without calling a non-thread-safe World concurrently or manufacturing a race.
class PrecisionProbe {
public:
    static void set_tick_in_progress(World& world, bool active) {
        world.tick_in_progress_ = active;
    }
};
}

namespace {
using namespace cybersand;

void require(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}

WorldConfig small_config() {
    WorldConfig config;
    config.chunk_size = 16;
    config.activity_block_size = 8;
    config.scheduling_core_size = 16;
    config.initial_chunk_reserve = 4;
    config.maximum_chunk_count = 32;
    return config;
}

std::vector<Material> payload(Material material = Material::Empty) {
    return std::vector<Material>(16U * 16U, material);
}

void installation_matches_existing_world_semantics() {
    auto config = small_config();
    config.water_experiment_policy = WaterExperimentPolicy{5, 4};
    config.settled_discovery_enabled = true;
    config.settled_discovery_tile_capacity = 128;
    World generated(config), reference(config);
    auto cells = payload();
    cells[0] = Material::GraniteBlock;
    cells[1] = Material::Water;
    cells[2] = Material::Fire;
    cells[3] = Material::Sand;
    cells[255] = Material::NeonCyan;
    const ChunkCoord coord{-1, 1};
    require(generated.install_generated_chunk(coord, cells) == ChunkInstallOutcome::Installed,
            "new signed-coordinate chunk must install");
    reference.reserve_region({-16, 16, 16, 16});
    for (std::size_t index = 0; index < cells.size(); ++index) {
        reference.set(-16 + static_cast<std::int64_t>(index % 16),
                      16 + static_cast<std::int64_t>(index / 16), cells[index]);
    }
    require(generated.content_hash() == reference.content_hash(),
            "generation must preserve ordinary material/state initialization");
    require(generated.liquid_mass(-15, 16) == 31,
            "generated Water must use the destination's configured mass precision");
    require(generated.stored_state_a(-14, 16) == material_definition(Material::Fire).initial_state_a,
            "generated reactive materials must keep existing lifetime defaults");
    require(generated.hard_surface_revision() == reference.hard_surface_revision(),
            "generation must publish hard-surface changes");
    require(generated.active_chunk_count() == reference.active_chunk_count() &&
            generated.dirty_chunk_count() == reference.dirty_chunk_count(),
            "generation must preserve activity and render dirty ownership");
    require(generated.settled_discovery_tile_count() == reference.settled_discovery_tile_count(),
            "generation must register discovery on the authoritative chunk");
    require(generated.settled_discovery_halted() == soliding::DiscoveryHalt::None,
            "normal chunk installation must not invalidate discovery");
    const auto dirty = generated.take_dirty_chunks();
    require(dirty.size() == 1 && dirty[0].chunk == coord &&
            dirty[0].local_rect.x == 0 && dirty[0].local_rect.y == 0 &&
            dirty[0].local_rect.width == 16 && dirty[0].local_rect.height == 16,
            "generated render bounds must include both payload corners");
}

void resident_chunks_are_never_repopulated() {
    World world(small_config());
    auto empty = payload();
    auto walls = payload(Material::GraniteBlock);
    require(world.install_generated_chunk({0, 0}, empty) == ChunkInstallOutcome::Installed,
            "an all-empty result must still claim its destination chunk");
    require(world.chunk_count() == 1, "all-empty generation must record residence");
    require(world.install_generated_chunk({0, 0}, walls) == ChunkInstallOutcome::AlreadyResident,
            "an empty generated chunk must not be regenerated");
    world.reserve_region({16, 0, 16, 16});
    require(world.install_generated_chunk({1, 0}, walls) == ChunkInstallOutcome::AlreadyResident,
            "pre-reserved chunks are owned even when empty");
    world.set(32, 0, Material::Water);
    world.set(32, 0, Material::Empty);
    require(world.install_generated_chunk({2, 0}, walls) == ChunkInstallOutcome::AlreadyResident,
            "edit-then-clear must not create a regeneration hole");
    require(world.stored_material(32, 0) == Material::Empty,
            "refusal must preserve player-erased material");
}

void malformed_payloads_have_no_partial_effect() {
    World world(small_config());
    world.set(-1, -1, Material::Copper);
    const auto before = world.state_hash();
    const auto count = world.chunk_count();
    auto cells = payload(Material::GraniteBlock);
    // 10 is reserved; kMaterialDefinitions.size() is the first ID past the catalogue.
    for (const auto invalid : {10, static_cast<int>(cybersand::kMaterialDefinitions.size()), 255}) {
        cells.back() = static_cast<Material>(invalid);
        require(world.install_generated_chunk({0, 0}, cells) == ChunkInstallOutcome::InvalidPayload,
                "invalid final material must reject the complete chunk");
        require(world.state_hash() == before && world.chunk_count() == count,
                "invalid tail must not write a valid prefix or allocate the destination");
    }
    cells = payload();
    cells.pop_back();
    require(world.install_generated_chunk({0, 0}, cells) == ChunkInstallOutcome::InvalidPayload,
            "short payload must fail");
    cells.push_back(Material::Empty);
    cells.push_back(Material::Empty);
    require(world.install_generated_chunk({0, 0}, cells) == ChunkInstallOutcome::InvalidPayload,
            "oversized payload must fail");
    require(world.install_generated_chunk({0, 0}, {}) == ChunkInstallOutcome::InvalidPayload,
            "missing payload must fail");
    require(world.state_hash() == before && world.chunk_count() == count,
            "shape refusals must preserve existing authority");
}

void body_occupancy_rejects_even_empty_generated_cells() {
    World world(small_config());
    world.configure_transient_obstacles({0, 0, 16, 16});
    require(world.set_transient_obstacle(15, 15, 1), "body-mask fixture must be populated");
    auto cells = payload(Material::Sand);
    cells.back() = Material::Empty;
    require(world.install_generated_chunk({0, 0}, cells) == ChunkInstallOutcome::TransientOccupancy,
            "generation must not claim even an empty cell under a live body");
    require(world.chunk_count() == 0 && world.stored_material(0, 0) == Material::Empty,
            "body-mask conflict must not install a material prefix");
    world.clear_transient_obstacles();
    require(world.install_generated_chunk({0, 0}, cells) == ChunkInstallOutcome::Installed,
            "cleared body-mask obstruction should permit an absent chunk");
}

void capacity_refusal_preserves_other_chunks() {
    auto config = small_config();
    config.initial_chunk_reserve = 1;
    config.maximum_chunk_count = 1;
    World world(config);
    const auto cells = payload(Material::GraniteBlock);
    require(world.install_generated_chunk({0, 0}, cells) == ChunkInstallOutcome::Installed,
            "first capacity slot must be usable");
    const auto before = world.state_hash();
    require(world.install_generated_chunk({1, 0}, cells) == ChunkInstallOutcome::CapacityFull,
            "storage pressure must be an explicit generation refusal");
    require(world.state_hash() == before && world.chunk_count() == 1,
            "capacity refusal must neither evict nor change the existing chunk");
}

void coordinates_refuse_overflow_and_protect_kernel_reach() {
    World world(small_config());
    const auto cells = payload();
    constexpr auto maximum = std::numeric_limits<std::int64_t>::max();
    constexpr auto minimum = std::numeric_limits<std::int64_t>::min();
    for (const auto coord : std::array<ChunkCoord, 6>{{
             {maximum, 0}, {minimum, 0}, {0, maximum}, {0, minimum},
             {maximum / 16, 0}, {minimum / 16, 0}}}) {
        require(world.install_generated_chunk(coord, cells) == ChunkInstallOutcome::CoordinateOverflow,
                "wrapped multiplication or an unsafe rule endpoint must be rejected");
    }
    require(world.chunk_count() == 0, "invalid coordinates must not alias resident chunks");
    require(world.install_generated_chunk({-1, -1}, cells) == ChunkInstallOutcome::Installed,
            "ordinary negative floor-divided coordinates must remain valid");
    world.configure_transient_obstacles({-64, -64, 16, 16});
    require(world.transient_obstacle_at(maximum - 32, maximum - 32) == 0,
            "distant chunk query must not overflow subtraction from a negative mask origin");
    require(!world.set_transient_obstacle(maximum - 32, maximum - 32, 1),
            "distant mask write must refuse without overflow or aliasing");
    auto distant = payload();
    distant[0] = Material::GraniteBlock;
    require(world.install_generated_chunk({maximum / 16 - 2, 0}, distant) == ChunkInstallOutcome::Installed,
            "valid distant generation must not overflow existing mask checks");
}

void failed_and_in_tick_worlds_refuse_installation() {
    auto config = small_config();
    config.backend = SimulationBackend::SerialInPlace;
    config.active_chunk_capacity = 1;
    World world(config);
    const auto cells = payload(Material::GraniteBlock);
    world.set(1, 1, Material::Sand);
    world.set(17, 1, Material::Sand);
    bool threw = false;
    try { (void)world.tick(); } catch (const std::runtime_error&) { threw = true; }
    require(threw && world.has_failed(), "capacity fixture must quarantine the World");
    const auto before = world.state_hash();
    require(world.install_generated_chunk({2, 0}, cells) == ChunkInstallOutcome::WorldFailed,
            "generation must not revive a failed World");
    require(world.state_hash() == before, "failed-World refusal must preserve diagnostics");
    world.clear();
    PrecisionProbe::set_tick_in_progress(world, true);
    const auto outcome = world.install_generated_chunk({0, 0}, cells);
    PrecisionProbe::set_tick_in_progress(world, false);
    require(outcome == ChunkInstallOutcome::TickInProgress && world.chunk_count() == 0,
            "generation must not mutate storage during a tick");
    require(world.install_generated_chunk({0, 0}, cells) == ChunkInstallOutcome::Installed,
            "an explicitly cleared World accepts new owner-validated generation");
}

void installed_chunks_join_existing_simulation() {
    World generated(small_config()), reference(small_config());
    auto cells = payload();
    for (std::size_t x = 0; x < 16; ++x) cells[15U * 16U + x] = Material::GraniteBlock;
    cells[4U * 16U + 8U] = Material::Sand;
    require(generated.install_generated_chunk({0, 0}, cells) == ChunkInstallOutcome::Installed,
            "playable generated fixture must install");
    reference.reserve_region({0, 0, 16, 16});
    for (std::size_t index = 0; index < cells.size(); ++index)
        reference.set(static_cast<std::int64_t>(index % 16),
                      static_cast<std::int64_t>(index / 16), cells[index]);
    for (int tick = 0; tick < 20; ++tick) {
        (void)generated.tick();
        (void)reference.tick();
        require(generated.content_hash() == reference.content_hash(),
                "generated authoritative cells must follow existing native rules exactly");
    }
    require(generated.stored_material(8, 14) == Material::Sand,
            "generated active Sand must fall onto the generated floor");
}
}

int main() {
    try {
        installation_matches_existing_world_semantics();
        resident_chunks_are_never_repopulated();
        malformed_payloads_have_no_partial_effect();
        body_occupancy_rejects_even_empty_generated_cells();
        capacity_refusal_preserves_other_chunks();
        coordinates_refuse_overflow_and_protect_kernel_reach();
        failed_and_in_tick_worlds_refuse_installation();
        installed_chunks_join_existing_simulation();
        std::cout << "PASS world generation installation: initialization, signed coordinates, residence, "
                     "atomic refusal, masks, capacity, quarantine, owner boundary and simulation\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "FAIL world generation installation: " << error.what() << '\n';
        return 1;
    }
}
