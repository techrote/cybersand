// #201 P1 experimental wake summaries. Included inside the pressure regression's
// anonymous namespace after test_pressure_optimization.inc (cached_config,
// require_pressure_equivalent). Every tick of every scenario requires the
// reference, cached and dormant Worlds to agree exactly.

using WakeWorlds = std::array<std::unique_ptr<World>, 3>;

WakeWorlds wake_worlds(std::uint32_t workers, std::uint32_t sleep_after = 3, bool gas = true) {
    WakeWorlds worlds;
    for (int variant = 0; variant < 3; ++variant) {
        auto config = cached_config(variant, gas, workers);
        config.sleep_after_quiet_ticks = sleep_after;
        worlds[static_cast<std::size_t>(variant)] = std::make_unique<World>(config);
    }
    return worlds;
}

struct WakeStep { std::uint64_t reference_moved = 0, woken = 0; std::uint64_t scanned = 0, skipped = 0; };

// Ticks every World, requires same-tick equivalence and returns cached work.
WakeStep wake_tick(WakeWorlds& worlds, int ticks, const char* label) {
    WakeStep step;
    for (int t = 0; t < ticks; ++t) {
        const auto before = worlds[1]->pressure_optimization_snapshot();
        for (std::size_t i = 0; i < worlds.size(); ++i) {
            const auto stats = worlds[i]->tick();
            if (i == 0) step.reference_moved += stats.moved_cells;
        }
        require(!worlds[0]->has_failed() && !worlds[1]->has_failed() && !worlds[2]->has_failed(), label);
        // The wake scan's own decisions must be identical, tick by tick.
        const auto woken = worlds[0]->pressure_flow_diagnostics().woken_blocks;
        require(worlds[1]->pressure_flow_diagnostics().woken_blocks == woken &&
                    worlds[2]->pressure_flow_diagnostics().woken_blocks == woken,
                std::string(label) + ": identical state-only wake decisions");
        step.woken += woken;
        require_pressure_equivalent(*worlds[0], *worlds[1]);
        require_pressure_equivalent(*worlds[0], *worlds[2]);
        require(worlds[0]->water_quantity({-128, -128, 256, 256}) == worlds[1]->water_quantity({-128, -128, 256, 256}) &&
                    worlds[0]->water_quantity({-128, -128, 256, 256}) == worlds[2]->water_quantity({-128, -128, 256, 256}),
                label);
        const auto after = worlds[1]->pressure_optimization_snapshot();
        step.scanned += after.wake_segments_scanned - before.wake_segments_scanned;
        step.skipped += after.wake_segments_skipped - before.wake_segments_skipped;
    }
    return step;
}

// A pool spanning the x=0 chunk seam, open to the atmosphere above.
void wake_basin(World& world) {
    world.configure_transient_obstacles({-64, -32, 128, 64});
    rect(world, -42, 0, 2, 22, Material::Wall);
    rect(world, 40, 0, 2, 22, Material::Wall);
    rect(world, -42, 20, 84, 2, Material::Wall);
    rect(world, -40, 10, 80, 10, Material::Water);
}

void test_pressure_wake_summary_quiet_and_invalidation() {
    // Gas-disabled Worlds run no gas pass, so producer-edit and final-head
    // invalidation are the only protection there (no global reset masks them).
    for (const bool gas : {true, false})
    for (const auto workers : {1U, 4U}) {
        auto worlds = wake_worlds(workers, 3U, gas);
        for (auto& world : worlds) wake_basin(*world);
        (void)wake_tick(worlds, 24, "basin settles identically");
        const auto quiet = wake_tick(worlds, 8, "quiet basin stays identical");
        require(quiet.reference_moved == 0U, "the registered basin is actually at rest");
        require(quiet.skipped > 0U && quiet.scanned == 0U,
                "cached quiet ticks skip every sleeping segment and scan none");
        require(worlds[1]->pressure_optimization_snapshot().wake_clean_cells > 0U &&
                    worlds[2]->pressure_optimization_snapshot().wake_clean_cells > 0U,
                "cached and dormant both hold clean summaries");
        require(worlds[0]->pressure_optimization_snapshot().wake_segments_skipped == 0U,
                "reference never elides its wake scan");

        // A host edit two cells right of the seam must clear summaries across it.
        const auto clean_before_edit = worlds[1]->pressure_optimization_snapshot().wake_clean_cells;
        for (auto& world : worlds) world->set(2, 10, Material::Empty);
        require(worlds[1]->pressure_optimization_snapshot().wake_clean_cells < clean_before_edit,
                "a host edit two cells from the seam clears summaries immediately");
        // The edit changes non-empty occupancy. With gas enabled the next tick
        // runs a gas pass, whose reset forces every sleeping segment to rescan
        // (lateral x+-2 gauges may change anywhere); without gas it does not.
        const auto quiet_segments = quiet.skipped / 8U;
        const auto next = wake_tick(worlds, 1, "seam edit tick continues identically");
        require(gas ? next.scanned * 2U > quiet_segments : next.scanned * 2U < quiet_segments,
                "a gas pass resets all summaries; a gas-free edit clears only its stencil");
        (void)wake_tick(worlds, 5, "seam edit continues identically");
        (void)wake_tick(worlds, 24, "basin resettles identically");

        // A native body mask at x+-2 of sleeping Water, then removed.
        const auto clean_before_mask = worlds[1]->pressure_optimization_snapshot().wake_clean_cells;
        require(clean_before_mask > 0U, "the resettled basin holds clean summaries again");
        for (auto& world : worlds) require(world->set_transient_obstacle(-2, 14, 7), "mask installed");
        require(worlds[1]->pressure_optimization_snapshot().wake_clean_cells < clean_before_mask,
                "a mask installed across the seam clears summaries immediately");
        (void)wake_tick(worlds, 6, "masked basin continues identically");
        for (auto& world : worlds) world->clear_transient_obstacles();
        (void)wake_tick(worlds, 24, "unmasked basin continues identically");
    }
}

// The LCB-001 static-rest pool geometry, shifted across the x=0 chunk seam.
void wake_drain_pool(World& world) {
    rect(world, -30, 100, 60, 2, Material::Wall);
    rect(world, -30, 40, 2, 60, Material::Wall);
    rect(world, 28, 40, 2, 60, Material::Wall);
    rect(world, -28, 60, 56, 40, Material::Water);
}

void test_pressure_wake_summary_remote_head_wake() {
    for (const bool gas : {true, false})
    for (const auto workers : {1U, 4U}) {
        auto worlds = wake_worlds(workers, 3U, gas);
        for (auto& world : worlds) wake_drain_pool(*world);
        (void)wake_tick(worlds, 24, "closed pool settles identically");
        const auto rest = wake_tick(worlds, 8, "closed pool rests identically");
        require(rest.reference_moved == 0U && rest.skipped > 0U && rest.scanned == 0U && rest.woken == 0U,
                "the sleeping pool is clean and skipped before the remote change");
        // Lower one surface column at x=1 by two cells. Its whole column head
        // drops by twice the cell maximum, beyond the start band, so sleeping
        // blocks 32+ rows below (and across the seam at x-2) wake only through
        // the state-only scan; the edit itself wakes just its neighbourhood.
        for (auto& world : worlds) {
            require(world->set_cell_state(1, 60, Material::Empty, 0, 0) &&
                        world->set_cell_state(1, 61, Material::Empty, 0, 0), "surface column lowered");
        }
        const auto drain = wake_tick(worlds, 40, "remote head change continues identically");
        require(drain.reference_moved > 0U, "the lowered column actually moves Water");
        require(drain.scanned > 0U, "changed final heads force ordinary scans");
        require(drain.woken > 0U, "the state-only scan actually wakes sleeping blocks");
    }
}

void test_pressure_wake_summary_single_quiet_tick_guard() {
    auto worlds = wake_worlds(1U, 1U);
    for (auto& world : worlds) wake_basin(*world);
    (void)wake_tick(worlds, 32, "single-quiet-tick basin continues identically");
    require(worlds[1]->pressure_optimization_snapshot().wake_segments_skipped == 0U &&
                worlds[2]->pressure_optimization_snapshot().wake_segments_skipped == 0U,
            "elision is disabled when a block can sleep in the tick it was updated");
}
