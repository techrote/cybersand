// Real native World dynamic-frontier qualification, opt-in and full-World only.
// This compiles the accepted source, not an invented Sand/Water rule model.
#include "cybersand/gen006_dynamic_full_world_stage.hpp"

#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <vector>

namespace {
using namespace cybersand;
using namespace cybersand::gen006;

void check(bool yes, const char* failure) {
    if (!yes) throw std::runtime_error(failure);
}

WorldConfig config_for(std::uint32_t workers) {
    WorldConfig config;
    config.chunk_size = 64;
    config.activity_block_size = 16;
    config.scheduling_core_size = 64;
    config.initial_chunk_reserve = 4;
    config.maximum_chunk_count = 64;
    config.active_chunk_capacity = 256;
    config.active_core_capacity = 256;
    config.worker_threads = workers;
    config.parallel_job_threshold = 1;
    return config;
}

void actual_dynamic_frontier(std::uint32_t workers) {
    const auto cfg = config_for(workers);
    auto live = std::make_unique<World>(cfg);
    // The control is a separately constructed, genuinely uninterrupted native
    // World. It is NEVER created by CYPS restore: that would make a matched
    // restore-vs-restore comparison insensitive to lost scheduler sidecars.
    auto reference = std::make_unique<World>(cfg);
    // The seam is between signed storage chunks {-2,-2} and {-2,-1}.
    constexpr std::int64_t base_x = -128;
    constexpr std::int64_t seam_y = -64;
    const std::vector<Material> empty(64U * 64U, Material::Empty);
    auto populate = [&](World& world) {
        check(world.install_generated_chunk({-2, -2}, empty) == ChunkInstallOutcome::Installed,
              "GEN006_DYNAMIC_TOP_INSTALL");
        check(world.install_generated_chunk({-2, -1}, empty) == ChunkInstallOutcome::Installed,
              "GEN006_DYNAMIC_BOTTOM_INSTALL");

        // Native moving Sand and Water start one cell above the SAME signed
        // seam, but in non-overlapping X ranges. Both must physically cross.
        for (std::int64_t x = 21; x < 29; ++x)
            world.set(base_x + x, seam_y - 1, Material::Sand);
        for (std::int64_t x = 35; x < 40; ++x)
            world.set(base_x + x, seam_y - 1, Material::Water);

        // A separate sealed Water17 + temperature417 cell retains fractional
        // state and thermal authority during the same dynamic continuation.
        const std::int64_t wx = base_x + 48, wy = seam_y - 29;
        for (std::int64_t x = wx - 2; x <= wx + 2; ++x)
            world.set(x, wy + 1, Material::Wall);
        for (std::int64_t y = wy - 1; y <= wy; ++y) {
            world.set(wx - 2, y, Material::Wall);
            world.set(wx + 2, y, Material::Wall);
        }
        check(world.set_cell_state(wx, wy, Material::Water, 17, 0),
              "GEN006_DYNAMIC_WATER17_SET");
        world.set_temperature(wx, wy, 417);
        check(world.stored_temperature(wx, wy) == 417 &&
              world.liquid_mass(wx, wy) == 17,
              "GEN006_DYNAMIC_INITIAL_THERMAL");
    };
    populate(*live);
    populate(*reference);
    check(live->physical_state_hash() == reference->physical_state_hash() &&
          live->quantity_ledger() == reference->quantity_ledger(),
          "GEN006_DYNAMIC_DISTINCT_OWNER_START_MISMATCH");

    bool crossed_sand = false, crossed_water = false;
    std::uint32_t observed = 0;
    unsigned cross_tick = 0;
    for (unsigned i = 0; i < 32; ++i) {
        const auto stats = live->tick();
        const auto control_stats = reference->tick();
        check(!live->has_failed() && !reference->has_failed(),
              "GEN006_DYNAMIC_NATIVE_TICK_FAILED");
        check(stats.tick == control_stats.tick &&
              live->physical_state_hash() == reference->physical_state_hash() &&
              live->quantity_ledger() == reference->quantity_ledger(),
              "GEN006_DYNAMIC_PRESTAGE_CONTROL_DIVERGED");
        observed = std::max(observed, stats.worker_threads_observed);
        for (std::int64_t y = seam_y; y < seam_y + 20; ++y) {
            for (std::int64_t x = 19; x < 31; ++x)
                if (live->stored_material(base_x + x, y) == Material::Sand)
                    crossed_sand = true;
            for (std::int64_t x = 30; x < 50; ++x)
                if (live->stored_material(base_x + x, y) == Material::Water &&
                    live->liquid_mass(base_x + x, y) != 0)
                    crossed_water = true;
        }
        if (crossed_sand && crossed_water) {
            cross_tick = i + 1;
            break;
        }
    }
    check(crossed_sand, "GEN006_DYNAMIC_REAL_SAND_SEAM_NOT_CROSSED");
    check(crossed_water, "GEN006_DYNAMIC_REAL_WATER_SEAM_NOT_CROSSED");
    check(live->chunk_count() >= 2, "GEN006_DYNAMIC_NOT_MULTI_CHUNK");
    check(!live->has_failed(), "GEN006_DYNAMIC_UNHEALTHY_OWNER");

    constexpr std::size_t kBoundedBytes = 4U * 1024U * 1024U;
    const FullWorldFence a{0x1234U, 0x5678U, 101U, 1U};
    auto staged = FullWorldContinuationStage::capture(live, a, kBoundedBytes);
    const std::vector<std::uint8_t> verified(staged.bytes().begin(), staged.bytes().end());
    const auto original_ptr = live.get();
    const auto before_hash = live->physical_state_hash();
    const auto before_tick = live->completed_tick_index();
    const auto before_quantity = live->quantity_ledger();
    const auto before_cells = live->resident_cell_bytes();

    auto bad_bytes = verified;
    bad_bytes.back() ^= 1U;
    check(staged.commit(live, a, bad_bytes) == FullWorldCommitStatus::UnverifiedCopy &&
          live.get() == original_ptr, "GEN006_DYNAMIC_BAD_VERIFICATION_DESTROYED_OWNER");
    const FullWorldFence wrong_recipe{a.session, a.recipe + 1U, a.incarnation, a.generation};
    check(staged.commit(live, wrong_recipe, verified) == FullWorldCommitStatus::StaleFence &&
          live.get() == original_ptr, "GEN006_DYNAMIC_WRONG_RECIPE_DESTROYED_OWNER");
    const FullWorldFence wrong_incarnation{a.session, a.recipe, a.incarnation + 1U, a.generation};
    check(staged.commit(live, wrong_incarnation, verified) == FullWorldCommitStatus::StaleFence &&
          live.get() == original_ptr, "GEN006_DYNAMIC_WRONG_INCAR_DESTROYED_OWNER");
    const FullWorldFence wrong_session{a.session + 1U, a.recipe, a.incarnation, a.generation};
    check(staged.commit(live, wrong_session, verified) == FullWorldCommitStatus::StaleFence &&
          live.get() == original_ptr, "GEN006_DYNAMIC_WRONG_SESSION_DESTROYED_OWNER");
    const FullWorldFence wrong_generation{a.session, a.recipe, a.incarnation, a.generation + 1U};
    check(staged.commit(live, wrong_generation, verified) == FullWorldCommitStatus::StaleFence &&
          live.get() == original_ptr, "GEN006_DYNAMIC_WRONG_GENERATION_DESTROYED_OWNER");
    check(live->physical_state_hash() == before_hash &&
          live->completed_tick_index() == before_tick &&
          live->quantity_ledger() == before_quantity &&
          live->resident_cell_bytes() == before_cells,
          "GEN006_DYNAMIC_REFUSAL_MUTATED_STATE");

    // The private World is a genuinely deserialized native physical state.
    // Replacing the owner after an exact verified-copy witness is one pointer
    // swap, not a sequence of partially committed per-chunk insertions.
    // Compare the private restore to the independently running original,
    // not to a second copy restored through the same serializer.
    check(reference->physical_state_hash() == before_hash &&
          reference->completed_tick_index() == before_tick &&
          reference->quantity_ledger() == before_quantity,
          "GEN006_DYNAMIC_UNINTERRUPTED_BASELINE");
    check(staged.commit(live, a, verified) == FullWorldCommitStatus::Committed,
          "GEN006_DYNAMIC_COMMIT_REFUSED");
    check(staged.commit(live, a, verified) == FullWorldCommitStatus::AlreadyCommitted,
          "GEN006_DYNAMIC_REPLAY_NOT_REFUSED");
    check(live->physical_state_hash() == before_hash &&
          live->completed_tick_index() == before_tick &&
          live->quantity_ledger() == before_quantity,
          "GEN006_DYNAMIC_RESTORE_CHANGED_AUTHORITY");
    for (unsigned i = 0; i < 8; ++i) {
        const auto lhs = live->tick();
        const auto rhs = reference->tick();
        observed = std::max(observed, lhs.worker_threads_observed);
        check(!live->has_failed() && !reference->has_failed() &&
              lhs.tick == rhs.tick &&
              live->completed_tick_index() == reference->completed_tick_index() &&
              live->physical_state_hash() == reference->physical_state_hash() &&
              live->quantity_ledger() == reference->quantity_ledger(),
              "GEN006_DYNAMIC_CONTINUATION_DIVERGED");
    }
    std::cout << "GEN006_DYNAMIC_FULL_WORLD_CONTINUATION_PASS configured_workers="
              << workers << " observed_workers_max=" << observed
              << " signed_sand_water_seam_cross_tick=" << cross_tick
              << " control=independently_uninterrupted"
              << " chunks=" << live->chunk_count()
              << " snapshot_bytes=" << verified.size()
              << " continued_ticks=8"
              << " final_native_tick=" << live->completed_tick_index()
              << " final_physical=" << live->physical_state_hash()
              << " final_water=" << live->quantity_ledger().water_visible << '\n';

    // Stale stage must not swap an owner changed by native tick. A separate
    // pointer-identity check rejects an equal-content new residency (ABA).
    const FullWorldFence b{a.session, a.recipe, a.incarnation + 1U, a.generation + 1U};
    auto stale = FullWorldContinuationStage::capture(live, b, kBoundedBytes);
    const std::vector<std::uint8_t> old(stale.bytes().begin(), stale.bytes().end());
    (void)live->tick();
    const auto changed = live->physical_state_hash();
    check(stale.commit(live, b, old) == FullWorldCommitStatus::StaleSource &&
          live->physical_state_hash() == changed, "GEN006_DYNAMIC_TICK_STALE_ACCEPTED");
    auto stale_owner = FullWorldContinuationStage::capture(live, b, kBoundedBytes);
    const std::vector<std::uint8_t> old_owner(stale_owner.bytes().begin(), stale_owner.bytes().end());
    live = World::restore_physical_state(cfg, old_owner);
    const auto replacement = live.get();
    check(stale_owner.commit(live, b, old_owner) == FullWorldCommitStatus::StaleOwner &&
          live.get() == replacement, "GEN006_DYNAMIC_ABA_OWNER_ACCEPTED");
}
} // namespace

int main(int argc, char** argv) {
    try {
        check(argc == 2, "usage: gen006-dynamic-continuation 1|4");
        const auto workers = static_cast<std::uint32_t>(std::stoul(argv[1]));
        check(workers == 1U || workers == 4U, "GEN006_DYNAMIC_WORKERS_MUST_BE_1_OR_4");
        actual_dynamic_frontier(workers);
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "GEN006_DYNAMIC_FULL_WORLD_CONTINUATION_FAIL " << error.what() << '\n';
        return 1;
    }
}
