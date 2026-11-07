// #201 moving-camera coverage. A selected-region change alone must neither
// alter any variant's physical result nor force the cached arms back through
// a cold gas pass, index rebuild or reference fallback. Included after the
// acceptance helpers in test_lcb_pressure.cpp.
void test_pressure_moving_region_exact_and_warm() {
    for (const auto workers : {1U, 4U}) {
        for (const bool gas : {false, true}) {
            auto worlds = acceptance_worlds(workers, gas);
            for (auto& world : worlds) {
                world->reserve_region({-32, -40, 96, 72});
                rect(*world, -32, 24, 96, 2, Material::Wall);            // floor across chunk seams
                rect(*world, -32, -40, 2, 64, Material::Wall);
                rect(*world, 62, -40, 2, 64, Material::Wall);
                rect(*world, -30, 12, 92, 12, Material::Water);           // vented pool
                rect(*world, 20, -30, 30, 2, Material::Wall);             // sealed gas room lid
                rect(*world, 20, -30, 2, 20, Material::Wall);
                rect(*world, 48, -30, 2, 20, Material::Wall);
                rect(*world, 20, -12, 30, 2, Material::Wall);
                rect(*world, 22, -18, 26, 6, Material::Water);
                rect(*world, -20, -20, 10, 6, Material::Water);           // a falling slab keeps flow alive
                world->set_simulation_region(RectI64{-30, -40, 40, 64});
            }
            acceptance_tick(worlds, 24, "settle under fixed interest");
            std::array<cybersand::PressureOptimizationCounters, 3> before{};
            for (std::size_t arm = 0; arm < 3; ++arm) before[arm] = worlds[arm]->pressure_optimization_snapshot().counters;
            // Camera-like motion: every step crosses or straddles an 8-cell core seam.
            std::int64_t x = -30;
            int direction = 1;
            for (int t = 0; t < 48; ++t) {
                x += direction * 5;
                if (x > 30) { x = 30; direction = -1; }
                if (x < -30) { x = -30; direction = 1; }
                for (auto& world : worlds) world->set_simulation_region(RectI64{x, -40, 40, 64});
                acceptance_tick(worlds, 1, "moving camera step " + std::to_string(t));
            }
            // Pure coverage shrink/expand and unbounded re-entry.
            for (auto& world : worlds) world->set_simulation_region(RectI64{0, 0, 8, 8});
            acceptance_tick(worlds, 4, "shrunk coverage");
            for (auto& world : worlds) world->set_simulation_region(std::nullopt);
            acceptance_tick(worlds, 4, "unbounded re-entry");
            for (std::size_t arm = 1; arm < 3; ++arm) {
                const auto after = worlds[arm]->pressure_optimization_snapshot().counters;
                require(after.index_rebuilds == before[arm].index_rebuilds,
                        "region motion alone rebuilt the pressure index");
                require(after.reference_fallbacks == before[arm].reference_fallbacks,
                        "region motion alone forced a reference head fallback");
                if (!gas) require(after.gas_reference_passes == before[arm].gas_reference_passes,
                                  "region motion alone forced a gas reference pass");
            }
        }
    }
}

// #201: World::find_chunk's per-thread cache must never return a pointer from
// replaced map contents (clear, rehash, a destroyed World at the same address,
// or interleaved lookups in two Worlds on one thread).
void test_chunk_lookup_cache_invalidation() {
    World a;
    World b;
    a.set(5, 5, Material::Sand);
    b.set(5, 5, Material::Water);
    for (int i = 0; i < 4; ++i) {
        require(a.get(5, 5) == Material::Sand && b.get(5, 5) == Material::Water,
                "interleaved Worlds share a cached chunk");
    }
    a.reserve_region({-512, -512, 2048, 2048});  // forces rehash and many insertions
    require(a.get(5, 5) == Material::Sand && a.get(-300, -300) == Material::Empty, "rehash invalidated a lookup");
    a.clear();
    require(a.get(5, 5) == Material::Empty, "clear() left a cached chunk visible");
    a.set(5, 5, Material::Stone);
    require(a.get(5, 5) == Material::Stone, "re-inserted chunk not observed");
    for (int round = 0; round < 8; ++round) {
        auto owner = std::make_unique<World>();
        owner->set(1, 1, round % 2 == 0 ? Material::Sand : Material::Water);
        require(owner->get(1, 1) == (round % 2 == 0 ? Material::Sand : Material::Water),
                "a World at a reused address saw a destroyed World's chunk");
        require(owner->get(400, 400) == Material::Empty, "absent chunk lookup changed");
    }
    World moved = std::move(b);
    require(moved.get(5, 5) == Material::Water, "move lost the chunk map");
}


// Direct move-assignment regression: populated destination TLS entry, an
// interleaved second World, deterministic same-address reuse and worker ticks.
void test_chunk_lookup_cache_direct_move_assignment() {
    for (auto workers : {1U, 4U}) {
        WorldConfig cfg{};
        cfg.worker_threads = workers;
        cfg.parallel_job_threshold = 1;
        cfg.maximum_chunk_count = 128;
        cfg.active_chunk_capacity = 128;
        cfg.active_core_capacity = 2048;
        World destination(cfg), source(cfg), reference(cfg), other(cfg);
        for (int x = -48; x < 48; ++x) {
            source.set(x, 40, Material::Wall); reference.set(x, 40, Material::Wall);
            if (x % 3 == 0) {
                source.set(x, -20, Material::Sand);
                reference.set(x, -20, Material::Sand);
            }
        }
        other.set(1, 1, Material::Water);
        destination.set(1, 1, Material::Stone);
        require(destination.get(1, 1) == Material::Stone &&
                other.get(1, 1) == Material::Water, "TLS move setup failed");
        const auto original = source.physical_state_hash();
        destination = std::move(source);
        require(destination.physical_state_hash() == original &&
                destination.get(1, 1) == Material::Empty &&
                destination.get(0, -20) == Material::Sand &&
                other.get(1, 1) == Material::Water,
                "move assignment retained a stale destination chunk");
        for (int t = 0; t < 8; ++t) {
            const auto d = destination.tick(), e = reference.tick();
            require(d.tick == e.tick &&
                    destination.content_hash() == reference.content_hash() &&
                    destination.physical_state_hash() == reference.physical_state_hash(),
                    "move-assigned World diverged during worker ticks");
        }
        alignas(World) std::byte bytes[sizeof(World)];
        auto* before = std::construct_at(reinterpret_cast<World*>(bytes), cfg);
        before->set(2, 2, Material::Sand);
        require(before->get(2, 2) == Material::Sand, "address reuse setup failed");
        std::destroy_at(before);
        auto* after = std::construct_at(reinterpret_cast<World*>(bytes), cfg);
        require(after->get(2, 2) == Material::Empty, "same-address stale chunk");
        after->set(2, 2, Material::Water);
        require(after->get(2, 2) == Material::Water, "same-address new chunk invisible");
        std::destroy_at(after);
    }
}
