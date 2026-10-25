// Affected-region discovery must preserve the single reference identity pass.
WorldConfig gas_cache_config(int variant, std::uint32_t workers = 1) {
    auto config = cached_config(variant, true, workers);
    config.chunk_size = 8; config.activity_block_size = 8; config.scheduling_core_size = 8;
    config.parallel_job_threshold = 1;
    return config;
}

void gas_cache_rooms(World& world, std::int64_t x, std::int64_t y) {
    world.reserve_region({x, y, 88, 8});
    for (const auto offset : {0, 64}) {
        rect(world, x + offset, y, 24, 8, Material::Wall);
        rect(world, x + offset + 9, y + 2, 13, 3, Material::Empty);
        rect(world, x + offset + 1, y + 3, 8, 1, Material::Water);
    }
    // Gas authority remains global even when both the outlet and other room pause.
    world.set_simulation_region(RectI64{x, y, 8, 8});
}

void require_gas_cache_equivalent(const World& reference, const World& candidate) {
    require_pressure_equivalent(reference, candidate);
    require(reference.gas_next_id() == candidate.gas_next_id() &&
                reference.gas_topology_revision() == candidate.gas_topology_revision(),
            "global gas allocator and topology revision agree");
    const auto a = reference.gas_compartments(), b = candidate.gas_compartments();
    require(a.size() == b.size(), "complete live gas table sizes agree");
    for (std::size_t i = 0; i < a.size(); ++i)
        require(std::tie(a[i].id,a[i].generation,a[i].parents,a[i].parent_count,a[i].amount,a[i].volume,
                         a[i].anchor_x,a[i].anchor_y,a[i].created_tick,a[i].revision,a[i].gauge) ==
                    std::tie(b[i].id,b[i].generation,b[i].parents,b[i].parent_count,b[i].amount,b[i].volume,
                         b[i].anchor_x,b[i].anchor_y,b[i].created_tick,b[i].revision,b[i].gauge),
                "every live gas identity, mass, geometry and pressure field agrees");
}

void test_affected_gas_components() {
    for (const auto workers : {1U, 4U}) for (const auto ox : {0, -24}) {
        const auto oy = ox == 0 ? 0 : -8;
        World reference(gas_cache_config(0,workers)), cached(gas_cache_config(1,workers)),
              dormant(gas_cache_config(2,workers));
        for (auto* world : {&reference,&cached,&dormant}) gas_cache_rooms(*world,ox,oy);
        const auto advance = [&](int count) {
            for (int t = 0; t < count; ++t) {
                tick(reference); tick(cached); tick(dormant);
                require_gas_cache_equivalent(reference,cached); require_gas_cache_equivalent(reference,dormant);
            }
        };
        advance(4);
        if (cached.pressure_optimization_snapshot().gas_valid_components != 2U) {
            const auto s=cached.pressure_optimization_snapshot();
            std::cerr << "gas warm components=" << s.gas_components << " valid=" << s.gas_valid_components
                      << " members=" << s.gas_members << " builds=" << s.counters.gas_cache_builds
                      << " passes=" << s.counters.gas_reference_passes << " fallbacks=" << s.counters.gas_capacity_fallbacks
                      << " pending=" << s.gas_pending << " indexed=" << s.indexed_chunks << '\n';
            for (const auto& c : cached.gas_compartments()) std::cerr << "id=" << c.id << " volume=" << c.volume
                      << " anchor=" << c.anchor_x << ',' << c.anchor_y << '\n';
        }
        require(cached.pressure_optimization_snapshot().gas_valid_components == 2U,
                "two fully resident sealed components are certified after the reference fixed point");
        const auto edit = [&](const auto& change, bool reuse = true) {
            const auto c = cached.pressure_optimization_snapshot().counters;
            const auto d = dormant.pressure_optimization_snapshot().counters;
            for (auto* world : {&reference,&cached,&dormant}) change(*world);
            advance(1);
            if (reuse) {
                require(cached.pressure_optimization_snapshot().counters.gas_component_reuses > c.gas_component_reuses &&
                            dormant.pressure_optimization_snapshot().counters.gas_component_reuses > d.gas_component_reuses,
                        "unchanged paused room actually replays its BFS on another room's repair tick");
            }
        };
        const auto before_expand=cached.pressure_optimization_snapshot().counters;
        edit([&](World& w) { w.set(ox+20,oy+1,Material::Empty); });
        require(cached.pressure_optimization_snapshot().counters.gas_bfs_cells > before_expand.gas_bfs_cells,
                "the expanded room still executes the reference BFS");
        require(reference.pressure_cell(ox+7,oy+3).flow == 3,
                "remote gauge change invalidates stationary motion through a paused outlet");
        edit([&](World& w) { w.set(ox+20,oy+1,Material::Wall); });
        // Ordinary set clears this old positive label before classification.
        require(cached.pressure_cell(ox+20,oy+4).gas > 0U, "label-erasure control starts labelled");
        edit([&](World& w) { w.set(ox+20,oy+4,Material::Wall); });
        edit([&](World& w) { w.set(ox+20,oy+4,Material::Empty); });
        edit([&](World& w) { rect(w,ox+15,oy+2,1,3,Material::Wall); }); // Split global identity.
        edit([&](World& w) { rect(w,ox+15,oy+2,1,3,Material::Empty); }); // Merge in original order.
        edit([&](World& w) { rect(w,ox+9,oy+2,13,3,Material::Wall); }); // Last member removed.
        edit([&](World& w) { rect(w,ox+9,oy+2,13,3,Material::Empty); });
        edit([&](World& w) { rect(w,ox+1,oy+3,8,1,Material::Wall); }); // Empty-only gas remains seeded.
        edit([&](World& w) { rect(w,ox+1,oy+3,8,1,Material::Water); });
        edit([&](World& w) { rect(w,ox+20,oy,1,2,Material::Empty); }); // Atmospheric prefix stays BFS.
        edit([&](World& w) { rect(w,ox+20,oy,1,2,Material::Wall); });
        advance(2);
        const auto before = cached.pressure_optimization_snapshot();
        require(before.counters.gas_seed_cells > 0U && before.counters.gas_relabel_cells > 0U &&
                    before.counters.gas_member_stamps > 0U && before.counters.gas_member_validations > 0U &&
                    before.counters.gas_invalidation_pairs > 0U && before.counters.gas_cache_build_cells > 0U,
                "global census, relabel, member replay, classification and cache construction are charged");
        require(before.gas_capacity_bytes >= before.gas_member_capacity * 8U &&
                    before.derived_capacity_bytes > before.gas_capacity_bytes && sizeof(cybersand::PressureKernelWork) == 56U,
                "declared gas memory includes real member capacity while worker counters stay narrow");
        // Body masks invalidate the whole certificate; no component-reuse claim is made for this cold path.
        for (auto* w : {&reference,&cached,&dormant}) w->configure_transient_obstacles({ox,oy,88,8});
        edit([&](World& w) { require(w.set_transient_obstacle(ox+20,oy+3,9), "gas body mask accepted"); },false);
        edit([](World& w) { w.clear_transient_obstacles(); },false);
        advance(2);
        auto restored = World::restore_physical_state(gas_cache_config(1,workers),cached.save_physical_state());
        require(restored->pressure_optimization_snapshot().gas_members == 0U,
                "restore retains authority and starts with a cold nonserialized member index");
        for (int t=0;t<4;++t) {
            tick(cached); tick(*restored);
            require(cached.physical_state_hash() == restored->physical_state_hash(),
                    "warm and cold gas-cache continuations agree exactly");
            require_gas_cache_equivalent(cached,*restored);
        }
    }
}

void test_gas_component_capacity_fallbacks() {
    for (int mode=0;mode<4;++mode) {
        auto config=gas_cache_config(1);
        if (mode==0) config.pressure_optimization.index_chunk_capacity=1;
        if (mode==1) config.pressure_optimization.gas_member_capacity=1;
        if (mode==2) config.pressure_optimization.gas_invalidation_pair_budget=0;
        if (mode==3) config.pressure_optimization.gas_member_capacity=78;
        World reference(gas_cache_config(0)), cached(config);
        for (auto* w : {&reference,&cached}) gas_cache_rooms(*w,0,0);
        for (int t=0;t<4;++t) { tick(reference); tick(cached); require_gas_cache_equivalent(reference,cached); }
        const auto before=cached.pressure_optimization_snapshot();
        for (auto* w : {&reference,&cached}) w->set(20,1,Material::Empty);
        for (int t=0;t<3;++t) { tick(reference); tick(cached); require_gas_cache_equivalent(reference,cached); }
        const auto after=cached.pressure_optimization_snapshot();
        require(after.gas_member_capacity == before.gas_member_capacity && after.gas_capacity_bytes == before.gas_capacity_bytes,
                "fallback never grows the declared member storage at tick time");
        if (mode==0) require(after.counters.reference_fallbacks>0U && after.counters.gas_component_reuses==0U,
                "incomplete resident index uses the complete reference operator");
        if (mode==1) require(after.counters.gas_capacity_fallbacks>0U && after.counters.gas_component_reuses==0U,
                "incomplete member representation declines reuse and preserves authority");
        if (mode==2) require(before.gas_valid_components==2U && after.counters.gas_budget_fallbacks>0U &&
                after.counters.gas_component_reuses==before.counters.gas_component_reuses,
                "dirty-component pair budget selects one complete reference discovery");
        if (mode==3) require(before.gas_members==78U && after.counters.gas_component_reuses>before.counters.gas_component_reuses &&
                after.counters.gas_capacity_fallbacks>before.counters.gas_capacity_fallbacks && after.gas_members==0U,
                "a fitting old summary is reused, then an oversized new fixed point explicitly declines caching");
    }
}

void test_gas_component_worker_parity() {
    World reference(gas_cache_config(0)), serial(gas_cache_config(1)), parallel(gas_cache_config(1,4));
    for (auto* w : {&reference,&serial,&parallel}) {
        gas_cache_rooms(*w,0,0); gas_cache_rooms(*w,128,0);
        w->set_simulation_region(std::nullopt);
    }
    bool dispatched=false;
    for (int t=0;t<16;++t) {
        if (t==5) for (auto* w : {&reference,&serial,&parallel}) w->set(20,1,Material::Empty);
        if (t==9) for (auto* w : {&reference,&serial,&parallel}) w->set(20,1,Material::Wall);
        tick(reference); tick(serial); const auto stats=parallel.tick();
        dispatched=dispatched || *std::max_element(stats.phase_jobs.begin(),stats.phase_jobs.end())>=4U;
        require_gas_cache_equivalent(reference,serial); require_gas_cache_equivalent(reference,parallel);
        require(serial.physical_state_hash()==parallel.physical_state_hash(),
                "one-worker and four-worker-configured material producers preserve complete gas authority");
    }
    require(dispatched && parallel.pressure_optimization_snapshot().counters.gas_dirty_chunks_queued>0U,
            "four-worker pool dispatch and producer invalidation are exercised");
}
