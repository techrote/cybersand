// Real native World dynamic-frontier qualification, opt-in and full-World only.
// This compiles the accepted source, not an invented Sand/Water rule model.
#include "cybersand/gen006_dynamic_bundle_admission.hpp"

#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <iterator>
#include <limits>
#include <memory>
#include <stdexcept>
#include <string>
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

// Explicit REAL-NATIVE selective-residency acceptance control. The live World
// owns TWO physically exchanging signed chunks and a THIRD unrelated resident.
// Public interest exclusion is not an eviction; this test must never label a
// full-World restore, clone or clear as selective native memory reclamation.
void selective_dynamic_residency_capacity_control(std::uint32_t workers) {
    auto cfg = config_for(workers);
    cfg.maximum_chunk_count = 3;
    cfg.initial_chunk_reserve = 3;
    auto live = std::make_unique<World>(cfg);
    // The oracle is independently constructed and never deserialized.
    auto uninterrupted = std::make_unique<World>(cfg);
    const std::vector<Material> empty(64U * 64U, Material::Empty);
    constexpr std::int64_t sx = -128, seam = -64;
    auto populate = [&](World& w) {
        check(w.install_generated_chunk({-2, -2}, empty) == ChunkInstallOutcome::Installed,
              "GEN006_SELECTIVE_TOP_ADMISSION");
        check(w.install_generated_chunk({-2, -1}, empty) == ChunkInstallOutcome::Installed,
              "GEN006_SELECTIVE_LOWER_ADMISSION");
        check(w.install_generated_chunk({8, 0}, empty) == ChunkInstallOutcome::Installed,
              "GEN006_SELECTIVE_UNAFFECTED_ADMISSION");
        for (std::int64_t x = 21; x < 29; ++x)
            w.set(sx + x, seam - 1, Material::Sand);
        for (std::int64_t x = 35; x < 40; ++x)
            w.set(sx + x, seam - 1, Material::Water);
        w.set(8 * 64 + 2, 2, Material::Wall);
        w.set_temperature(8 * 64 + 2, 2, 417);
    };
    populate(*live);
    populate(*uninterrupted);
    check(live->chunk_count() == 3 &&
          live->physical_state_hash() == uninterrupted->physical_state_hash() &&
          live->quantity_ledger() == uninterrupted->quantity_ledger(),
          "GEN006_SELECTIVE_INITIAL_NATIVE_ORACLE");

    std::uint32_t observed = 0;
    bool sand_crossed = false, water_crossed = false;
    unsigned seam_tick = 0;
    for (unsigned i = 0; i < 32; ++i) {
        const auto ls = live->tick();
        const auto rs = uninterrupted->tick();
        observed = std::max(observed, ls.worker_threads_observed);
        check(!live->has_failed() && !uninterrupted->has_failed() &&
              ls.tick == rs.tick &&
              live->physical_state_hash() == uninterrupted->physical_state_hash() &&
              live->quantity_ledger() == uninterrupted->quantity_ledger() &&
              live->chunk_count() == 3,
              "GEN006_SELECTIVE_NATIVE_SEAM_ORACLE_DIVERGED");
        for (std::int64_t y = seam; y < seam + 20; ++y) {
            for (std::int64_t x = 19; x < 31; ++x)
                sand_crossed |= live->stored_material(sx + x, y) == Material::Sand;
            for (std::int64_t x = 30; x < 50; ++x)
                water_crossed |= live->stored_material(sx + x, y) == Material::Water &&
                                 live->liquid_mass(sx + x, y) != 0;
        }
        if (sand_crossed && water_crossed) { seam_tick = i + 1; break; }
    }
    check(sand_crossed && water_crossed && seam_tick != 0,
          "GEN006_SELECTIVE_MOVING_SAND_WATER_NOT_PROVEN");

    // Request ONLY the two moving adjacent chunks. A complete-World stage
    // must refuse while the independent third resident remains alive.
    const FullWorldFence lease{0x481U, 0x194U, 7U, 3U};
    const std::vector<ChunkCoord> moving{{-2, -2}, {-2, -1}};
    const std::vector<BundleSeam> seam_edges{{{-2, -2}, {-2, -1}}};
    const auto original = live.get();
    const auto before_tick = live->completed_tick_index();
    const auto before_hash = live->physical_state_hash();
    const auto before_ledger = live->quantity_ledger();
    const auto before_count = live->chunk_count();
    const auto before_allocated = live->resident_cell_bytes();
    const auto before_cyps = live->save_physical_state();
    bool rejected_partial = false;
    try {
        auto disallowed = FullResidentBundleStage::capture(
            live, lease, moving, seam_edges, 4U * 1024U * 1024U);
        (void)disallowed;
    } catch (const BundleAdmissionError& e) {
        rejected_partial = e.status() == BundleAdmissionStatus::RosterCountMismatch;
    }
    check(rejected_partial && live.get() == original &&
          live->save_physical_state() == before_cyps &&
          live->chunk_count() == before_count &&
          live->resident_cell_bytes() == before_allocated &&
          live->quantity_ledger() == before_ledger &&
          live->completed_tick_index() == before_tick &&
          live->physical_state_hash() == before_hash,
          "GEN006_SELECTIVE_PARTIAL_REQUEST_CHANGED_LIVE_WORLD");

    // Even after narrowing interest to the unaffected chunk, the two moving
    // chunks retain their physical allocations and block a fourth admission.
    live->set_simulation_region(RectI64{8 * 64, 0, 64, 64});
    uninterrupted->set_simulation_region(RectI64{8 * 64, 0, 64, 64});
    (void)live->tick();
    (void)uninterrupted->tick();
    check(!live->has_failed() && !uninterrupted->has_failed() &&
          live->physical_state_hash() == uninterrupted->physical_state_hash() &&
          live->quantity_ledger() == uninterrupted->quantity_ledger(),
          "GEN006_SELECTIVE_INTEREST_NATIVE_TICK_DIVERGED");
    const auto exclusion_hash = live->physical_state_hash();
    const auto exclusion_tick = live->completed_tick_index();
    const auto exclusion_ledger = live->quantity_ledger();
    const auto exclusion_bytes = live->resident_cell_bytes();
    const auto exclusion_image = live->save_physical_state();
    const auto admission = live->install_generated_chunk({9, 0}, empty);
    check(admission == ChunkInstallOutcome::CapacityFull &&
          live->chunk_count() == before_count &&
          live->resident_cell_bytes() == before_allocated &&
          exclusion_bytes == before_allocated &&
          live->completed_tick_index() == exclusion_tick &&
          live->physical_state_hash() == exclusion_hash &&
          live->quantity_ledger() == exclusion_ledger &&
          live->save_physical_state() == exclusion_image &&
          live->stored_material(8 * 64 + 2, 2) == Material::Wall &&
          live->stored_temperature(8 * 64 + 2, 2) == 417,
          "GEN006_SELECTIVE_INTEREST_FALSE_MEMORY_RECLAIM");

    // Only global clear can reclaim these resident bytes through this public
    // World interface. This copy is discarded, never presented as a selective
    // transaction or used as the uninterrupted scientific oracle.
    auto disposable = World::restore_physical_state(cfg, exclusion_image);
    check(disposable && disposable->chunk_count() == 3 &&
          disposable->resident_cell_bytes() == before_allocated,
          "GEN006_SELECTIVE_GLOBAL_CLEAR_CONTROL_RESTORE");
    disposable->clear();
    check(disposable->chunk_count() == 0 &&
          disposable->resident_cell_bytes() == 0 &&
          live->chunk_count() == 3 &&
          live->resident_cell_bytes() == before_allocated,
          "GEN006_SELECTIVE_CLEAR_MISREPORTED_AS_PARTIAL");

    live->set_simulation_region(std::nullopt);
    uninterrupted->set_simulation_region(std::nullopt);
    for (unsigned i = 0; i < 8; ++i) {
        const auto ls = live->tick();
        const auto rs = uninterrupted->tick();
        observed = std::max(observed, ls.worker_threads_observed);
        check(!live->has_failed() && !uninterrupted->has_failed() &&
              ls.tick == rs.tick &&
              live->physical_state_hash() == uninterrupted->physical_state_hash() &&
              live->quantity_ledger() == uninterrupted->quantity_ledger() &&
              live->chunk_count() == 3 &&
              live->resident_cell_bytes() == before_allocated,
              "GEN006_SELECTIVE_POST_REFUSAL_CONTINUATION_DIVERGED");
    }
    std::cout << "GEN006_DYNAMIC_SELECTIVE_CAPACITY_HOLD_PASS"
              << " configured_workers=" << workers
              << " observed_workers_max=" << observed
              << " signed_sand_water_cross_tick=" << seam_tick
              << " selected_dynamic_chunks=2 unaffected_live_chunks=1"
              << " resident_count_before=" << before_count
              << " resident_count_after=" << live->chunk_count()
              << " allocated_cell_bytes_before=" << before_allocated
              << " allocated_cell_bytes_after=" << live->resident_cell_bytes()
              << " genuinely_selective_reclaimed_bytes=0"
              << " extra_chunk_admission=CapacityFull"
              << " global_clear_reclaimed_bytes=" << before_allocated
              << " post_refusal_real_ticks=8"
              << " selective_eviction_implemented=0" << '\n';
}

void actual_dynamic_frontier(std::uint32_t workers, const std::string& output_path) {
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
    // Complete native resident-set bundle: true moving Water and Sand are
    // already present at both sides of this signed seam. Negative contracts
    // must fail without altering any aspect of the live native World.
    const std::vector<ChunkCoord> full_roster{{-2, -2}, {-2, -1}};
    const std::vector<BundleSeam> full_seams{{{-2, -2}, {-2, -1}}};
    const auto refusal_pointer = live.get();
    const auto refusal_hash = live->physical_state_hash();
    const auto refusal_tick = live->completed_tick_index();
    const auto refusal_ledger = live->quantity_ledger();
    const auto refusal_count = live->chunk_count();
    const auto refusal_bytes = live->resident_cell_bytes();
    auto refuse_bundle = [&](std::vector<ChunkCoord> roster,
                             std::vector<BundleSeam> seams,
                             BundleAdmissionStatus expected, const char* reason) {
        bool refused = false;
        try {
            auto bad = FullResidentBundleStage::capture(
                live, a, roster, seams, kBoundedBytes);
            (void)bad;
        } catch (const BundleAdmissionError& error) {
            refused = (error.status() == expected);
        }
        check(refused && live.get() == refusal_pointer &&
              live->physical_state_hash() == refusal_hash &&
              live->completed_tick_index() == refusal_tick &&
              live->quantity_ledger() == refusal_ledger &&
              live->chunk_count() == refusal_count &&
              live->resident_cell_bytes() == refusal_bytes, reason);
    };
    refuse_bundle({{-2, -2}}, {}, BundleAdmissionStatus::EmptyOrOversizedRoster,
                  "GEN006_DYNAMIC_PARTIAL_BUNDLE_ACCEPTED");
    refuse_bundle({{-2, -2}, {-2, -2}}, full_seams,
                  BundleAdmissionStatus::DuplicateChunk,
                  "GEN006_DYNAMIC_DUPLICATE_BUNDLE_ACCEPTED");
    refuse_bundle(full_roster, {}, BundleAdmissionStatus::UncoveredInternalSeam,
                  "GEN006_DYNAMIC_MISSING_SEAM_ACCEPTED");
    refuse_bundle(full_roster, {{{-2, -2}, {-2, 0}}},
                  BundleAdmissionStatus::InvalidSeam,
                  "GEN006_DYNAMIC_INVALID_SEAM_ACCEPTED");
    refuse_bundle(full_roster, {full_seams[0], full_seams[0]},
                  BundleAdmissionStatus::DuplicateSeam,
                  "GEN006_DYNAMIC_DUPLICATE_SEAM_ACCEPTED");
    refuse_bundle({{-2, -2}, {-2, 0}}, {},
                  BundleAdmissionStatus::MissingResident,
                  "GEN006_DYNAMIC_PHANTOM_RESIDENT_ACCEPTED");
    refuse_bundle({{-2, -2}, {std::numeric_limits<std::int64_t>::max(), -1}}, {},
                  BundleAdmissionStatus::InvalidCoordinate,
                  "GEN006_DYNAMIC_OVERFLOW_RESIDENT_ACCEPTED");
    // MIN and MAX must not become neighbours via modular uint64 subtraction.
    // Reject the bogus *seam itself*, before reaching coordinate admission.
    const auto coordinate_min = std::numeric_limits<std::int64_t>::min();
    const auto coordinate_max = std::numeric_limits<std::int64_t>::max();
    refuse_bundle({{coordinate_min, 0}, {coordinate_max, 0}},
                  {{{coordinate_min, 0}, {coordinate_max, 0}}},
                  BundleAdmissionStatus::InvalidSeam,
                  "GEN006_DYNAMIC_SIGNED_WRAP_SEAM_ACCEPTED");

    auto staged = FullResidentBundleStage::capture(
        live, a, full_roster, full_seams, kBoundedBytes);
    check(staged.residents().size() == live->chunk_count() &&
          staged.internal_seams().size() == 1,
          "GEN006_DYNAMIC_BUNDLE_COVERAGE_INCOMPLETE");
    std::cout << "GEN006_DYNAMIC_COMPLETE_RESIDENT_BUNDLE_PASS"
              << " configured_workers=" << workers
              << " real_residents=" << staged.residents().size()
              << " internal_seams=" << staged.internal_seams().size()
              << " partial_refused=1 duplicate_refused=1"
              << " uncovered_seam_refused=1 phantom_refused=1"
              << " invalid_signed_coordinate_refused=1"
              << " scope=FULL_WORLD_ONLY" << std::endl;
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


    // Real native Sand/Water edits spanning both signed residents are staged
    // atomically in the private bundle. This is a NON-DURABLE owner-side input
    // candidate; source CYPS and edited intent require a separate storage ACK.
    const FullWorldFence edit_fence{a.session, a.recipe, a.incarnation + 1U, a.generation + 1U};
    auto edit_stage = FullResidentBundleStage::capture(
        live, edit_fence, full_roster, full_seams, kBoundedBytes);
    const std::vector<BundleMaterialEdit> edits{
        {{-2, -2}, 12, 15, Material::Water},
        {{-2, -1}, 18, 11, Material::Sand},
    };
    auto invalid_batch = [&](std::vector<BundleMaterialEdit> attempt,
                             BundleAdmissionStatus reason, const char* name) {
        bool refused = false;
        try { edit_stage.stage_material_edits(attempt); }
        catch (const BundleAdmissionError& error) { refused = error.status() == reason; }
        check(refused && live->physical_state_hash() == reference->physical_state_hash() &&
              live->quantity_ledger() == reference->quantity_ledger(), name);
    };
    invalid_batch({edits[0], edits[0]}, BundleAdmissionStatus::DuplicateEdit,
                  "GEN006_DYNAMIC_DUPLICATE_EDIT_ACCEPTED");
    invalid_batch({{{-2, 1}, 2, 3, Material::Sand}},
                  BundleAdmissionStatus::EditOutsideResident,
                  "GEN006_DYNAMIC_OUTSIDE_EDIT_ACCEPTED");
    invalid_batch({{{-2, -2}, 64, 3, Material::Water}},
                  BundleAdmissionStatus::InvalidEditBatch,
                  "GEN006_DYNAMIC_BAD_LOCAL_EDIT_ACCEPTED");
    const auto edit_original = live.get();
    const auto edit_base_hash = live->physical_state_hash();
    edit_stage.stage_material_edits(edits);
    check(live.get() == edit_original && live->physical_state_hash() == edit_base_hash,
          "GEN006_DYNAMIC_EDIT_STAGE_MUTATED_LIVE");
    const std::vector<std::uint8_t> edit_base(
        edit_stage.bytes().begin(), edit_stage.bytes().end());
    check(edit_stage.commit(live, edit_fence, edit_base) ==
              FullWorldCommitStatus::UnverifiedCopy &&
          live.get() == edit_original,
          "GEN006_DYNAMIC_EDIT_MISSING_WITNESS_ACCEPTED");
    auto wrong_edits = edits;
    wrong_edits[0].material = Material::Sand;
    check(edit_stage.commit(live, edit_fence, edit_base, wrong_edits) ==
              FullWorldCommitStatus::UnverifiedCopy &&
          live.get() == edit_original,
          "GEN006_DYNAMIC_EDIT_WRONG_WITNESS_ACCEPTED");
    reference->set(-128 + 12, -128 + 15, Material::Water);
    reference->set(-128 + 18, -64 + 11, Material::Sand);
    check(edit_stage.commit(live, edit_fence, edit_base, edit_stage.staged_edits()) ==
              FullWorldCommitStatus::Committed &&
          live->physical_state_hash() == reference->physical_state_hash() &&
          live->quantity_ledger() == reference->quantity_ledger(),
          "GEN006_DYNAMIC_BATCH_COMMIT_DIVERGED");
    for (unsigned i = 0; i < 8; ++i) {
        const auto lhs = live->tick();
        const auto rhs = reference->tick();
        observed = std::max(observed, lhs.worker_threads_observed);
        check(!live->has_failed() && !reference->has_failed() &&
              lhs.tick == rhs.tick &&
              live->physical_state_hash() == reference->physical_state_hash() &&
              live->quantity_ledger() == reference->quantity_ledger(),
              "GEN006_DYNAMIC_BATCH_CONTINUATION_DIVERGED");
    }
    std::cout << "GEN006_DYNAMIC_ATOMIC_CROSS_SEAM_EDIT_PASS"
              << " configured_workers=" << workers
              << " edited_residents=2 edits=" << edit_stage.staged_edits().size()
              << " continued_ticks=8 scope=FULL_WORLD_NON_DURABLE"
              << " observed_workers_max=" << observed << '\n';


    // Real speculative native continuation: edit BOTH signed residents,
    // advance private Sand/Water physics for six actual ticks, and compare
    // the one-swap publication with a never-restored live control. The
    // original resident World must remain byte-for-byte unchanged until
    // the exact base+edits+tick receipt is presented.
    const FullWorldFence preview_fence{
        a.session, a.recipe, a.incarnation + 2U, a.generation + 2U};
    auto preview = FullResidentBundleStage::capture(
        live, preview_fence, full_roster, full_seams, kBoundedBytes);
    const std::vector<BundleMaterialEdit> preview_edits{
        {{-2, -2}, 4, 10, Material::Sand},
        {{-2, -1}, 5, 30, Material::Water},
    };
    const auto preview_original = live.get();
    const auto preview_original_bytes = live->save_physical_state();
    const auto preview_original_hash = live->physical_state_hash();
    const auto preview_original_tick = live->completed_tick_index();
    const auto preview_original_ledger = live->quantity_ledger();
    const auto preview_original_memory = live->resident_cell_bytes();
    preview.stage_material_edits(preview_edits);
    auto reject_ticks = [&](std::uint32_t count, BundleAdmissionStatus status) {
        bool rejected = false;
        try { (void)preview.stage_native_ticks(count); }
        catch (const BundleAdmissionError& e) { rejected = e.status() == status; }
        check(rejected, "GEN006_DYNAMIC_BAD_TICK_BUDGET_ACCEPTED");
    };
    reject_ticks(0, BundleAdmissionStatus::InvalidTickBatch);
    reject_ticks(FullResidentBundleStage::kMaximumStagedTicks + 1U,
                 BundleAdmissionStatus::InvalidTickBatch);
    const auto tick_receipt = preview.stage_native_ticks(6);
    check(tick_receipt.ticks == 6U &&
          tick_receipt.completed_tick == preview_original_tick + 6U &&
          tick_receipt.resident_chunks == full_roster.size(),
          "GEN006_DYNAMIC_PRIVATE_TICK_RECEIPT_INVALID");
    reject_ticks(1, BundleAdmissionStatus::TicksAlreadyStaged);
    bool rejected_late_edit = false;
    try { preview.stage_material_edits(preview_edits); }
    catch (const BundleAdmissionError& e) {
        rejected_late_edit = e.status() == BundleAdmissionStatus::EditsAfterTickBatch;
    }
    check(rejected_late_edit, "GEN006_DYNAMIC_LATE_EDIT_ACCEPTED");
    const std::vector<std::uint8_t> preview_base(
        preview.bytes().begin(), preview.bytes().end());
    check(preview_base == preview_original_bytes &&
          live.get() == preview_original &&
          live->save_physical_state() == preview_original_bytes &&
          live->physical_state_hash() == preview_original_hash &&
          live->completed_tick_index() == preview_original_tick &&
          live->quantity_ledger() == preview_original_ledger &&
          live->resident_cell_bytes() == preview_original_memory,
          "GEN006_DYNAMIC_PRIVATE_TICKS_MUTATED_LIVE");
    check(preview.commit(live, preview_fence, preview_base) ==
              FullWorldCommitStatus::UnverifiedCopy &&
          preview.commit(live, preview_fence, preview_base, preview.staged_edits()) ==
              FullWorldCommitStatus::UnverifiedCopy,
          "GEN006_DYNAMIC_LEGACY_COMMIT_PUBLISHED_UNWITNESSED_TICKS");
    auto wrong_receipt = tick_receipt;
    ++wrong_receipt.completed_tick;
    check(preview.commit(live, preview_fence, preview_base,
                         preview.staged_edits(), wrong_receipt) ==
              FullWorldCommitStatus::UnverifiedCopy,
          "GEN006_DYNAMIC_WRONG_TICK_RECEIPT_ACCEPTED");
    auto wrong_preview_edits = preview_edits;
    wrong_preview_edits[0].material = Material::Water;
    check(preview.commit(live, preview_fence, preview_base,
                         wrong_preview_edits, tick_receipt) ==
              FullWorldCommitStatus::UnverifiedCopy,
          "GEN006_DYNAMIC_WRONG_PREVIEW_EDIT_WITNESS_ACCEPTED");
    check(preview.commit(live, wrong_recipe, preview_base,
                         preview.staged_edits(), tick_receipt) ==
              FullWorldCommitStatus::StaleFence &&
          live.get() == preview_original &&
          live->save_physical_state() == preview_original_bytes,
          "GEN006_DYNAMIC_PREVIEW_REFUSAL_MUTATED_LIVE");

    reference->set(-128 + 4, -128 + 10, Material::Sand);
    reference->set(-128 + 5, -64 + 30, Material::Water);
    for (unsigned i = 0; i < tick_receipt.ticks; ++i) {
        const auto stats = reference->tick();
        observed = std::max(observed, stats.worker_threads_observed);
        check(!reference->has_failed(),
              "GEN006_DYNAMIC_PREVIEW_REFERENCE_TICK_FAILED");
    }
    check(tick_receipt.completed_tick == reference->completed_tick_index() &&
          tick_receipt.physical_hash == reference->physical_state_hash() &&
          tick_receipt.quantity == reference->quantity_ledger() &&
          tick_receipt.resident_chunks == reference->chunk_count() &&
          tick_receipt.resident_cell_bytes == reference->resident_cell_bytes(),
          "GEN006_DYNAMIC_PREVIEW_RECEIPT_NOT_UNINTERRUPTED");
    // Real POST preview state: file write, readback, independently restored
    // World, and an exact post-state receipt before atomic owner publication.
    bool premature_refused = false;
    {
        auto early = FullResidentBundleStage::capture(
            live, preview_fence, full_roster, full_seams, kBoundedBytes);
        try { (void)early.seal_publication(kBoundedBytes); }
        catch (const BundleAdmissionError& e) {
            premature_refused = e.status() == BundleAdmissionStatus::PublicationRequiresTicks;
        }
    }
    check(premature_refused, "GEN006_PREMATURE_PUBLICATION_ACCEPTED");
    bool oversize_refused = false;
    try { (void)preview.seal_publication(1U); }
    catch (const BundleAdmissionError& e) {
        oversize_refused = e.status() == BundleAdmissionStatus::PublicationSnapshotOversized;
    }
    check(oversize_refused && live->save_physical_state() == preview_original_bytes,
          "GEN006_PUBLICATION_SIZE_REFUSAL_MUTATED_LIVE");
    const auto post_receipt = preview.seal_publication(kBoundedBytes);
    check(post_receipt.source_fence == preview_fence &&
          post_receipt.source_tick == preview_original_tick &&
          post_receipt.source_physical_hash == preview_original_hash &&
          post_receipt.completed_tick == tick_receipt.completed_tick &&
          post_receipt.physical_hash == reference->physical_state_hash() &&
          post_receipt.quantity == reference->quantity_ledger() &&
          post_receipt.edit_count == preview_edits.size() &&
          post_receipt.preview_ticks == 6 &&
          post_receipt.resident_chunks == full_roster.size(),
          "GEN006_POSTSTATE_RECEIPT_PARITY_FAILED");
    bool reseal_refused = false;
    try { (void)preview.seal_publication(kBoundedBytes); }
    catch (const BundleAdmissionError& e) {
        reseal_refused = e.status() == BundleAdmissionStatus::PublicationAlreadySealed;
    }
    check(reseal_refused, "GEN006_DUPLICATE_PUBLICATION_SEAL_ACCEPTED");
    const std::vector<std::uint8_t> post(preview.publication_bytes().begin(),
                                          preview.publication_bytes().end());
    {
        std::ofstream out(output_path, std::ios::binary | std::ios::trunc);
        check(static_cast<bool>(out), "GEN006_POST_FILE_OPEN_FAILED");
        out.write(reinterpret_cast<const char*>(post.data()),
                  static_cast<std::streamsize>(post.size()));
        out.flush();
        check(static_cast<bool>(out), "GEN006_POST_FILE_WRITE_FAILED");
    }
    std::ifstream input(output_path, std::ios::binary);
    check(static_cast<bool>(input), "GEN006_POST_READBACK_OPEN_FAILED");
    const std::vector<std::uint8_t> reread(
        (std::istreambuf_iterator<char>(input)), std::istreambuf_iterator<char>());
    check(reread == post && reread.size() == post_receipt.snapshot_bytes,
          "GEN006_POST_READBACK_MISMATCH");
    auto cold = World::restore_physical_state(cfg, reread);
    check(cold && !cold->has_failed() &&
          cold->save_physical_state() == reread &&
          cold->physical_state_hash() == post_receipt.physical_hash &&
          cold->quantity_ledger() == post_receipt.quantity &&
          cold->completed_tick_index() == post_receipt.completed_tick,
          "GEN006_POST_CYPS_COLD_PARITY_FAILED");
    auto wrong_post = reread;
    wrong_post.back() ^= 1U;
    auto wrong_receipt_post = post_receipt;
    ++wrong_receipt_post.completed_tick;
    check(preview.commit(live, preview_fence, preview_base,
                         preview.staged_edits(), tick_receipt) ==
              FullWorldCommitStatus::UnverifiedCopy &&
          preview.commit_published(live, preview_fence, preview_base,
                                   preview.staged_edits(), tick_receipt,
                                   wrong_post, post_receipt) ==
              FullWorldCommitStatus::UnverifiedCopy &&
          preview.commit_published(live, preview_fence, preview_base,
                                   preview.staged_edits(), tick_receipt,
                                   reread, wrong_receipt_post) ==
              FullWorldCommitStatus::UnverifiedCopy &&
          preview.commit_published(live, wrong_recipe, preview_base,
                                   preview.staged_edits(), tick_receipt,
                                   reread, post_receipt) ==
              FullWorldCommitStatus::StaleFence &&
          live.get() == preview_original &&
          live->save_physical_state() == preview_original_bytes,
          "GEN006_POST_NEGATIVE_MUTATED_LIVE");
    check(preview.commit_published(live, preview_fence, preview_base,
                                   preview.staged_edits(), tick_receipt,
                                   reread, post_receipt) ==
              FullWorldCommitStatus::Committed &&
          preview.commit_published(live, preview_fence, preview_base,
                                   preview.staged_edits(), tick_receipt,
                                   reread, post_receipt) ==
              FullWorldCommitStatus::AlreadyCommitted &&
          live->completed_tick_index() == reference->completed_tick_index() &&
          live->physical_state_hash() == reference->physical_state_hash() &&
          live->quantity_ledger() == reference->quantity_ledger(),
          "GEN006_POST_COMMIT_DIVERGED");
    for (unsigned i = 0; i < 8; ++i) {
        const auto lhs = live->tick();
        const auto rhs = reference->tick();
        observed = std::max(observed, lhs.worker_threads_observed);
        check(!live->has_failed() && !reference->has_failed() &&
              lhs.tick == rhs.tick &&
              live->physical_state_hash() == reference->physical_state_hash() &&
              live->quantity_ledger() == reference->quantity_ledger() &&
              live->completed_tick_index() == reference->completed_tick_index(),
              "GEN006_DYNAMIC_PRIVATE_TICK_CONTINUATION_DIVERGED");
    }
    std::cout << "GEN006_DYNAMIC_PUBLICATION_EXPECTED"
              << " configured_workers=" << workers
              << " published_tick=" << post_receipt.completed_tick
              << " published_physical=" << post_receipt.physical_hash
              << " final_tick=" << live->completed_tick_index()
              << " final_physical=" << live->physical_state_hash()
              << " final_water=" << live->quantity_ledger().water_visible
              << " resident_chunks=" << live->chunk_count()
              << " snapshot_bytes=" << reread.size()
              << " scope=FULL_WORLD_READBACK_NOT_DURABLE" << '\n';
    std::cout << "GEN006_DYNAMIC_PRIVATE_NATIVE_TICKS_PASS"
              << " configured_workers=" << workers
              << " native_preview_ticks=" << tick_receipt.ticks
              << " observed_preview_workers=" << tick_receipt.observed_workers_max
              << " post_commit_ticks=8"
              << " residents=" << live->chunk_count()
              << " final_native_tick=" << live->completed_tick_index()
              << " scope=FULL_WORLD_NON_DURABLE" << '\n';

    // A complete *chronological* native replay: editing Water/Sand in TWO
    // signed residents, advancing real physics, editing those residents AGAIN,
    // advancing real physics, then publishing ONE full-World candidate. The
    // reference is an independent, never-restored World with direct inputs.
    // This exercises real between-tick edit timing, not an edit-list shuffle.
    const FullWorldFence replay_fence{
        a.session, a.recipe, a.incarnation + 3U, a.generation + 3U};
    auto replay = FullResidentBundleStage::capture(
        live, replay_fence, full_roster, full_seams, kBoundedBytes);
    const auto replay_original = live.get();
    const auto replay_base = live->save_physical_state();
    const auto replay_base_hash = live->physical_state_hash();
    const auto replay_base_tick = live->completed_tick_index();
    const auto replay_base_ledger = live->quantity_ledger();
    const auto replay_base_memory = live->resident_cell_bytes();
    const std::vector<BundleReplayStep> script{
        BundleReplayStep::material_edit({{-2, -2}, 3, 18, Material::Water}),
        BundleReplayStep::material_edit({{-2, -1}, 4, 22, Material::Sand}),
        BundleReplayStep::native_ticks(2),
        // Same exact cell is valid AGAIN after a native tick epoch.
        BundleReplayStep::material_edit({{-2, -2}, 3, 18, Material::Empty}),
        BundleReplayStep::material_edit({{-2, -1}, 6, 23, Material::Water}),
        BundleReplayStep::native_ticks(3),
        BundleReplayStep::material_edit({{-2, -2}, 9, 21, Material::Sand}),
        BundleReplayStep::native_ticks(1),
    };
    auto refuse_script = [&](std::vector<BundleReplayStep> candidate,
                             BundleAdmissionStatus status, const char* message) {
        bool refused = false;
        try { (void)replay.stage_replay_script(candidate); }
        catch (const BundleAdmissionError& e) { refused = e.status() == status; }
        check(refused && live.get() == replay_original &&
              live->save_physical_state() == replay_base &&
              live->physical_state_hash() == replay_base_hash &&
              live->completed_tick_index() == replay_base_tick &&
              live->quantity_ledger() == replay_base_ledger &&
              live->resident_cell_bytes() == replay_base_memory, message);
    };
    refuse_script({}, BundleAdmissionStatus::InvalidReplayScript,
                  "GEN006_REPLAY_EMPTY_ACCEPTED");
    refuse_script({BundleReplayStep::material_edit({{-2, -2}, 1, 1, Material::Water}),
                   BundleReplayStep::native_ticks(0),
                   BundleReplayStep::native_ticks(1)},
                  BundleAdmissionStatus::InvalidReplayScript,
                  "GEN006_REPLAY_ZERO_TICKS_ACCEPTED");
    refuse_script({BundleReplayStep::material_edit({{-2, -2}, 1, 1, Material::Water}),
                   BundleReplayStep::material_edit({{-2, -2}, 1, 1, Material::Sand}),
                   BundleReplayStep::native_ticks(1)},
                  BundleAdmissionStatus::DuplicateEdit,
                  "GEN006_REPLAY_SAME_EPOCH_DUPLICATE_ACCEPTED");
    refuse_script({BundleReplayStep::material_edit({{-2, 0}, 1, 1, Material::Water}),
                   BundleReplayStep::native_ticks(1),
                   BundleReplayStep::material_edit({{-2, -2}, 1, 2, Material::Sand})},
                  BundleAdmissionStatus::EditOutsideResident,
                  "GEN006_REPLAY_NONRESIDENT_EDIT_ACCEPTED");
    refuse_script({BundleReplayStep::material_edit({{-2, -2}, 1, 1, Material::Water}),
                   BundleReplayStep::native_ticks(16),
                   BundleReplayStep::native_ticks(1)},
                  BundleAdmissionStatus::InvalidReplayScript,
                  "GEN006_REPLAY_OVER_BUDGET_ACCEPTED");

    const auto script_receipt = replay.stage_replay_script(script);
    check(script_receipt.steps == script.size() &&
          script_receipt.edits == 5 && script_receipt.ticks == 6 &&
          script_receipt.completed_tick == replay_base_tick + 6 &&
          script_receipt.resident_chunks == full_roster.size() &&
          replay.replay_script().size() == script.size() &&
          live.get() == replay_original &&
          live->save_physical_state() == replay_base &&
          live->physical_state_hash() == replay_base_hash &&
          live->completed_tick_index() == replay_base_tick &&
          live->quantity_ledger() == replay_base_ledger &&
          live->resident_cell_bytes() == replay_base_memory,
          "GEN006_REPLAY_PRIVATE_STAGE_MUTATED_LIVE");
    refuse_script(script, BundleAdmissionStatus::ReplayAlreadyStaged,
                  "GEN006_REPLAY_DOUBLE_STAGE_ACCEPTED");
    bool legacy_refused = false;
    try { replay.stage_material_edits({}); }
    catch (const BundleAdmissionError& e) {
        legacy_refused = e.status() == BundleAdmissionStatus::ReplayConflictsWithLegacy;
    }
    check(legacy_refused, "GEN006_REPLAY_LEGACY_INPUT_MIX_ACCEPTED");

    // Independent direct application: never run this test's stage_script()
    // on the control, and never construct it from the replay's CYPS output.
    reference->set(-128 + 3, -128 + 18, Material::Water);
    reference->set(-128 + 4, -64 + 22, Material::Sand);
    for (unsigned i = 0; i < 2; ++i) (void)reference->tick();
    reference->set(-128 + 3, -128 + 18, Material::Empty);
    reference->set(-128 + 6, -64 + 23, Material::Water);
    for (unsigned i = 0; i < 3; ++i) (void)reference->tick();
    reference->set(-128 + 9, -128 + 21, Material::Sand);
    (void)reference->tick();
    check(!reference->has_failed() &&
          script_receipt.completed_tick == reference->completed_tick_index() &&
          script_receipt.physical_hash == reference->physical_state_hash() &&
          script_receipt.quantity == reference->quantity_ledger() &&
          script_receipt.resident_cell_bytes == reference->resident_cell_bytes(),
          "GEN006_REPLAY_NOT_EQUAL_TO_UNINTERRUPTED_NATIVE");

    const auto replay_post_receipt = replay.seal_publication(kBoundedBytes);
    check(replay_post_receipt.replay_steps == script.size() &&
          replay_post_receipt.edit_count == 5 &&
          replay_post_receipt.preview_ticks == 6 &&
          replay_post_receipt.physical_hash == reference->physical_state_hash() &&
          replay_post_receipt.quantity == reference->quantity_ledger(),
          "GEN006_REPLAY_SEALED_RECEIPT_INCORRECT");
    const std::vector<std::uint8_t> replay_post(
        replay.publication_bytes().begin(), replay.publication_bytes().end());
    const auto replay_path = output_path + ".replay";
    {
        std::ofstream output(replay_path, std::ios::binary | std::ios::trunc);
        check(static_cast<bool>(output), "GEN006_REPLAY_FILE_OPEN_FAILED");
        output.write(reinterpret_cast<const char*>(replay_post.data()),
                     static_cast<std::streamsize>(replay_post.size()));
        output.flush();
        check(static_cast<bool>(output), "GEN006_REPLAY_FILE_WRITE_FAILED");
    }
    std::ifstream reread_stream(replay_path, std::ios::binary);
    check(static_cast<bool>(reread_stream), "GEN006_REPLAY_REREAD_FAILED");
    const std::vector<std::uint8_t> replay_reread(
        (std::istreambuf_iterator<char>(reread_stream)), std::istreambuf_iterator<char>());
    check(replay_reread == replay_post, "GEN006_REPLAY_READBACK_DIFFERENT");
    auto replay_cold = World::restore_physical_state(cfg, replay_reread);
    check(replay_cold && !replay_cold->has_failed() &&
          replay_cold->save_physical_state() == replay_reread &&
          replay_cold->physical_state_hash() == reference->physical_state_hash() &&
          replay_cold->quantity_ledger() == reference->quantity_ledger() &&
          replay_cold->completed_tick_index() == reference->completed_tick_index(),
          "GEN006_REPLAY_COLD_NATIVE_NOT_EQUAL");
    auto altered_script = script;
    altered_script[0].edit.material = Material::Sand;
    auto altered_receipt = script_receipt;
    ++altered_receipt.completed_tick;
    auto altered_post = replay_reread;
    altered_post.back() ^= 1U;
    check(replay.commit(live, replay_fence, replay_base) ==
              FullWorldCommitStatus::UnverifiedCopy &&
          replay.commit_published(live, replay_fence, replay_base, {},
                                  BundleTickReceipt{}, replay_reread,
                                  replay_post_receipt) ==
              FullWorldCommitStatus::UnverifiedCopy &&
          replay.commit_replay_published(live, replay_fence, replay_base,
                                         altered_script, script_receipt,
                                         replay_reread, replay_post_receipt) ==
              FullWorldCommitStatus::UnverifiedCopy &&
          replay.commit_replay_published(live, replay_fence, replay_base,
                                         script, altered_receipt,
                                         replay_reread, replay_post_receipt) ==
              FullWorldCommitStatus::UnverifiedCopy &&
          replay.commit_replay_published(live, replay_fence, replay_base,
                                         script, script_receipt,
                                         altered_post, replay_post_receipt) ==
              FullWorldCommitStatus::UnverifiedCopy &&
          replay.commit_replay_published(live, wrong_recipe, replay_base,
                                         script, script_receipt,
                                         replay_reread, replay_post_receipt) ==
              FullWorldCommitStatus::StaleFence &&
          live.get() == replay_original &&
          live->save_physical_state() == replay_base &&
          live->physical_state_hash() == replay_base_hash &&
          live->completed_tick_index() == replay_base_tick &&
          live->quantity_ledger() == replay_base_ledger &&
          live->resident_cell_bytes() == replay_base_memory,
          "GEN006_REPLAY_REFUSAL_MUTATED_LIVE");
    check(replay.commit_replay_published(live, replay_fence, replay_base,
                                         script, script_receipt,
                                         replay_reread, replay_post_receipt) ==
              FullWorldCommitStatus::Committed &&
          replay.commit_replay_published(live, replay_fence, replay_base,
                                         script, script_receipt,
                                         replay_reread, replay_post_receipt) ==
              FullWorldCommitStatus::AlreadyCommitted &&
          live->physical_state_hash() == reference->physical_state_hash() &&
          live->quantity_ledger() == reference->quantity_ledger() &&
          live->completed_tick_index() == reference->completed_tick_index(),
          "GEN006_REPLAY_ATOMIC_COMMIT_NOT_UNINTERRUPTED");
    for (unsigned i = 0; i < 8; ++i) {
        const auto l = live->tick();
        const auto c = reference->tick();
        observed = std::max(observed, l.worker_threads_observed);
        check(!live->has_failed() && !reference->has_failed() &&
              l.tick == c.tick &&
              live->physical_state_hash() == reference->physical_state_hash() &&
              live->quantity_ledger() == reference->quantity_ledger() &&
              live->completed_tick_index() == reference->completed_tick_index() &&
              live->resident_cell_bytes() == reference->resident_cell_bytes(),
              "GEN006_REPLAY_EIGHT_TICK_CONTINUATION_DIVERGED");
    }
    std::cout << "GEN006_DYNAMIC_ORDERED_REPLAY_PASS"
              << " configured_workers=" << workers
              << " replay_steps=" << script.size()
              << " alternating_edit_phases=3"
              << " material_edits=" << script_receipt.edits
              << " private_ticks=" << script_receipt.ticks
              << " independently_uninterrupted=1"
              << " post_commit_ticks=8"
              << " observed_workers_max=" << observed
              << " scope=FULL_WORLD_NON_DURABLE" << '\n';
    std::cout << "GEN006_DYNAMIC_REPLAY_EXPECTED"
              << " configured_workers=" << workers
              << " published_tick=" << replay_post_receipt.completed_tick
              << " published_physical=" << replay_post_receipt.physical_hash
              << " final_tick=" << live->completed_tick_index()
              << " final_physical=" << live->physical_state_hash()
              << " final_water=" << live->quantity_ledger().water_visible
              << " resident_chunks=" << live->chunk_count()
              << " snapshot_bytes=" << replay_reread.size()
              << " scope=FULL_WORLD_READBACK_NOT_DURABLE" << '\n';

    // Stale stage must not swap an owner changed by native tick. A separate
    // pointer-identity check rejects an equal-content new residency (ABA).
    const FullWorldFence b{a.session, a.recipe, a.incarnation + 4U, a.generation + 4U};
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
// A genuinely separate process consumes the post-edit/post-tick CYPS file.
void cold_process(std::uint32_t workers, const std::string& path,
                  std::uint64_t staged_tick, std::uint64_t staged_hash,
                  std::uint64_t final_tick, std::uint64_t final_hash,
                  std::uint64_t final_water, std::size_t resident_count) {
    std::ifstream input(path, std::ios::binary);
    check(static_cast<bool>(input), "GEN006_COLD_OPEN_FAILED");
    const std::vector<std::uint8_t> bytes(
        (std::istreambuf_iterator<char>(input)), std::istreambuf_iterator<char>());
    check(!bytes.empty(), "GEN006_COLD_BYTES_EMPTY");
    auto world = World::restore_physical_state(config_for(workers), bytes);
    check(world && !world->has_failed() &&
          world->save_physical_state() == bytes &&
          world->completed_tick_index() == staged_tick &&
          world->physical_state_hash() == staged_hash &&
          world->chunk_count() == resident_count,
          "GEN006_COLD_IDENTITY_INVALID");
    std::uint32_t observed = 0;
    for (unsigned i = 0; i < 8; ++i) {
        const auto s = world->tick();
        observed = std::max(observed, s.worker_threads_observed);
        check(!world->has_failed(), "GEN006_COLD_TICK_FAILED");
    }
    check(world->completed_tick_index() == final_tick &&
          world->physical_state_hash() == final_hash &&
          world->quantity_ledger().water_visible == final_water &&
          world->chunk_count() == resident_count,
          "GEN006_COLD_CONTINUATION_DIVERGED");
    std::cout << "GEN006_DYNAMIC_COLD_PROCESS_CONTINUATION_PASS"
              << " configured_workers=" << workers
              << " readback_bytes=" << bytes.size()
              << " observed_workers_max=" << observed
              << " continued_ticks=8 scope=FULL_WORLD_ONLY" << '\n';
}
} // namespace

int main(int argc, char** argv) {
    try {
        if (argc == 10 && std::string(argv[1]) == "--cold-restore") {
            const auto workers = static_cast<std::uint32_t>(std::stoul(argv[2]));
            check(workers == 1U || workers == 4U, "GEN006_COLD_WORKERS");
            cold_process(workers, argv[3], std::stoull(argv[4]),
                         std::stoull(argv[5]), std::stoull(argv[6]),
                         std::stoull(argv[7]), std::stoull(argv[8]),
                         static_cast<std::size_t>(std::stoull(argv[9])));
            return 0;
        }
        check(argc == 3, "usage: gen006-dynamic-continuation 1|4 POSTFILE");
        const auto workers = static_cast<std::uint32_t>(std::stoul(argv[1]));
        check(workers == 1U || workers == 4U, "GEN006_DYNAMIC_WORKERS_MUST_BE_1_OR_4");
        selective_dynamic_residency_capacity_control(workers);
        actual_dynamic_frontier(workers, argv[2]);
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "GEN006_DYNAMIC_FULL_WORLD_CONTINUATION_FAIL " << error.what() << '\n';
        return 1;
    }
}
