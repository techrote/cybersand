// Included inside the pressure regression's anonymous namespace.
WorldConfig cached_config(std::int32_t variant = 1, bool gas = true, std::uint32_t workers = 1) {
    auto config = pressure_config(workers);
    const auto request = pressure_request(std::pair{gas ? 1 : 0, 32}, variant);
    const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(request));
    require(decoded.accepted(), "cached execution request admitted");
    config.liquid_solver_policy = *decoded.policy;
    return config;
}

void require_pressure_equivalent(const World& reference, const World& cached) {
    require(reference.liquid_comparison_hash(cybersand::LiquidStateProjection::PressureVariantEquivalenceV1) ==
                cached.liquid_comparison_hash(cybersand::LiquidStateProjection::PressureVariantEquivalenceV1),
            "same-tick complete pressure projection agrees");
    const auto a = reference.gas_ledger(), b = cached.gas_ledger();
    require(std::tie(a.created,a.absorbed,a.vented,a.collapsed,a.merges,a.splits,a.creations,a.vents,a.collapses,a.amount_live) ==
            std::tie(b.created,b.absorbed,b.vented,b.collapsed,b.merges,b.splits,b.creations,b.vents,b.collapses,b.amount_live),
            "complete gas ledgers agree");
    const auto p = reference.pressure_flow_ledger(), q = cached.pressure_flow_ledger();
    require(std::tie(p.overfill_converted,p.overfill_external,p.flow_remainder,p.contact_loss,p.relief_cells) ==
            std::tie(q.overfill_converted,q.overfill_external,q.flow_remainder,q.contact_loss,q.relief_cells),
            "pressure momentum ledgers agree");
    const auto h = reference.gas_history(), k = cached.gas_history();
    require(h.size() == k.size(), "gas history lengths agree");
    for (std::size_t i=0; i<h.size(); ++i) {
        const auto& x=h[i].compartment; const auto& y=k[i].compartment;
        require(std::tie(x.id,x.generation,x.parents,x.parent_count,x.amount,x.volume,x.anchor_x,x.anchor_y,x.created_tick,x.revision,x.gauge) ==
                std::tie(y.id,y.generation,y.parents,y.parent_count,y.amount,y.volume,y.anchor_x,y.anchor_y,y.created_tick,y.revision,y.gauge) &&
                std::tie(h[i].reason,h[i].successors,h[i].successor_count,h[i].tick) ==
                std::tie(k[i].reason,k[i].successors,k[i].successor_count,k[i].tick), "full gas retirement histories agree");
    }
}

void test_pressure_optimization_identity_readback() {
    auto plain = std::make_unique<World>();
    require(!plain->pressure_optimization_identity(), "default World has no pressure optimization extension");
    plain.reset();
    cybersand::setup::SetupDescriptor setup; setup.domain = {0,0,8,8};
    for (const auto variant : {0,1,2}) {
        auto cfg = cached_config(variant);
        auto world = std::make_unique<World>(cfg);
        const auto identity = world->pressure_optimization_identity();
        const auto facts = cybersand::receipt::capture_native_facts(*world,setup);
        const auto& extensions = facts.values().solver_state_extensions;
        require(extensions.size() == 1U && extensions[0].family == 3U &&
                    extensions[0].extension_digest == identity,
                "native capture binds actual optimization identity through the existing family extension");
        if (variant == 0) {
            require(!identity && extensions[0].extension_identity_version == 0U,
                    "reference retains its existing absent optimization identity");
            continue;
        }
        // Independent Python hashlib/struct '<6Q' known answers: execution
        // version, variant and the four requested budgets after the domain.
        const auto expected = variant == 1
            ? "ff6c0ec10b50db0095e96b7d67e61494aea2b55ca618c60edcac2cf0b9aac60d"
            : "bb3da4cf065ebca4ba39363b246ec365c08f15e1d50f2bfa2d307abd4dd95964";
        require(identity && cybersand::Sha256::hex(*identity) == expected && extensions[0].extension_identity_version == 1U,
                "cached/dormant execution3 has its declared native identity encoding1");
        const auto full = world->physical_state_hash();
        std::vector<std::array<std::uint8_t,32>> observations{*identity};
        for (int field = 0; field < 4; ++field) {
            auto changed = cfg;
            switch (field) {
                case 0: --changed.pressure_optimization.index_chunk_capacity; break;
                case 1: --changed.pressure_optimization.head_repair_cell_budget; break;
                case 2: --changed.pressure_optimization.gas_member_capacity; break;
                default: --changed.pressure_optimization.gas_invalidation_pair_budget; break;
            }
            auto other = std::make_unique<World>(changed);
            const auto observed = other->pressure_optimization_identity();
            require(observed && std::find(observations.begin(),observations.end(),*observed) == observations.end(),
                    "each requested execution budget is significant to the optimization identity");
            observations.push_back(*observed);
            require(other->physical_state_hash() == full,
                    "derived execution budgets do not change authoritative physical state");
            const auto readback = cybersand::receipt::capture_native_facts(*other,setup);
            require(readback.values().solver_state_extensions[0].extension_digest == observed,
                    "receipt reads the actual changed execution configuration");
        }
    }
}

using CostWorlds=std::array<std::unique_ptr<World>,3>;
CostWorlds cost_worlds(std::uint32_t workers, bool full, bool awake=true, int fallback=0, bool spare=false) {
    CostWorlds worlds;
    for (int arm=0;arm<3;++arm) {
        auto cfg=cached_config(arm,false,workers);
        cfg.chunk_size=8; cfg.activity_block_size=8; cfg.scheduling_core_size=8;
        cfg.parallel_job_threshold=1; cfg.initial_chunk_reserve=8;
        cfg.maximum_chunk_count=64; cfg.active_chunk_capacity=64; cfg.active_core_capacity=64;
        if (fallback==1) cfg.pressure_optimization.index_chunk_capacity=1;
        if (fallback==2) cfg.pressure_optimization.head_repair_cell_budget=0;
        auto world=std::make_unique<World>(cfg);
        for (const auto offset:{0,16,32,48}) {
            world->reserve_region({offset,0,8,8}); rect(*world,offset,0,8,8,Material::Wall);
            if (full) rect(*world,offset+2,4,4,2,Material::Water);
            else require(world->set_cell_state(offset+3,5,Material::Water,128,0),"stationary partial Water cost control");
            // Same activity block, beyond Water's radius-two certificate reads.
            if (awake) require(world->set_cell_state(offset+6,1,Material::Oil,0,200),"independent awake Oil control");
        }
        if (spare) for (int i=0;i<8;++i) {
            world->reserve_region({128+i*16,0,8,8}); rect(*world,128+i*16,0,8,8,Material::Wall);
        }
        worlds[static_cast<std::size_t>(arm)]=std::move(world);
    }
    return worlds;
}
std::uint64_t cost_tick(CostWorlds& worlds) {
    std::uint64_t jobs=0;
    for (auto& world:worlds) {
        const auto stats=world->tick();
        for (const auto count:stats.phase_jobs) jobs=std::max(jobs,count);
    }
    for (std::size_t arm=1;arm<3;++arm) require_pressure_equivalent(*worlds[0],*worlds[arm]);
    const auto cached=worlds[1]->pressure_optimization_snapshot();
    require(cached.certificate_buffer_capacity_bytes==0U && cached.counters.certificate_invalidation_cells==0U &&
                cached.counters.certificate_attempts==0U && cached.counters.certificate_saved_calls==0U,
            "cached1 never allocates or stamps unused motion certificates");
    return jobs;
}
void cost_require_worker_parity(const CostWorlds& one,const CostWorlds& four) {
    for (std::size_t arm=0;arm<3;++arm)
        require(one[arm]->physical_state_hash()==four[arm]->physical_state_hash(),"execution-budget admission preserves exact actual1/4-configured-worker continuation");
}
void test_cost_fallbacks_and_zero_saving() {
    for (const auto workers:{1U,4U}) for (const auto fallback:{1,2}) {
        auto worlds=cost_worlds(workers,true,true,fallback);
        for (int t=0;t<12;++t) {
            for (auto& world:worlds) world->set(6,2,t%2 ? Material::Wall : Material::Empty);
            (void)cost_tick(worlds);
            const auto observed=worlds[2]->pressure_optimization_snapshot();
            require(!observed.certificate_layer_enabled && observed.certificate_contents_cold &&
                        observed.counters.certificate_cold_resets==0U && observed.counters.certificate_invalidation_cells==0U &&
                        observed.counters.certificate_attempts==0U && observed.counters.certificate_saved_calls==0U &&
                        observed.counters.certificate_unavailable_ticks==static_cast<std::uint64_t>(t+1),
                    "unusable index/head fallback bypasses every certificate reset, stamp, proof and skip");
        }
    }
    auto one=cost_worlds(1,false),four=cost_worlds(4,false);
    for (int t=0;t<9;++t) {
        for (auto* cohort:{&one,&four}) for (auto& world:*cohort)
            for (const auto offset:{0,16,32,48}) world->set(offset+3,1,t%2 ? Material::Wall : Material::Empty);
        (void)cost_tick(one);(void)cost_tick(four);cost_require_worker_parity(one,four);
    }
    const auto denied=four[2]->pressure_optimization_snapshot();
    require(denied.counters.certificate_work_windows==1U && denied.counters.certificate_work_suspensions==1U &&
                denied.certificate_suspend_remaining==32U && !denied.certificate_layer_enabled && denied.certificate_contents_cold &&
                denied.certificate_last_window_charge>0U && denied.certificate_last_window_credit==0U &&
                denied.counters.certificate_saved_calls==0U && denied.counters.certificate_attempts>0U,
            "actual no-saving topology churn pays a bounded trial then suspends the entire certificate layer");
    require(denied.counters.certificate_work_charged==denied.counters.certificate_invalidation_cells+
                40U*denied.counters.certificate_attempts+denied.counters.certificate_reuses &&
                denied.counters.certificate_work_credited==8U*denied.counters.certificate_saved_calls &&
                denied.counters.certificate_cold_reset_cells>0U,
            "declared independent 1/40/1 charge and8 saved-call credit include the actual cold reset");
}
void test_cost_heavy_maintenance_and_reactivation() {
    auto one=cost_worlds(1,true,true,0,true),four=cost_worlds(4,true,true,0,true);
    for (int t=0;t<9;++t) {
        for (auto* cohort:{&one,&four}) for (auto& world:*cohort)
            for(int i=0;i<8;++i) world->set(131+i*16,2,t%2 ? Material::Wall : Material::Empty);
        (void)cost_tick(one);(void)cost_tick(four);cost_require_worker_parity(one,four);
    }
    const auto denied=four[2]->pressure_optimization_snapshot();
    require(denied.counters.certificate_saved_calls>0U && denied.certificate_last_window_credit>0U &&
                denied.certificate_last_window_charge>denied.certificate_last_window_credit &&
                denied.counters.certificate_work_suspensions==1U && denied.certificate_suspend_remaining==32U,
            "small real savings cannot admit expensive resident reset and continuing unrelated maintenance");
    const auto before=denied.counters;
    for (int t=0;t<32;++t) {
        for (auto* cohort:{&one,&four}) for (auto& world:*cohort)
            for(int i=0;i<8;++i) world->set(131+i*16,2,t%2 ? Material::Wall : Material::Empty);
        // Change previously certified authority while all certificate stamps are off.
        if(t==7) for (auto* cohort:{&one,&four}) for(auto& world:*cohort)
            require(world->set_cell_state(2,4,Material::Water,128,0),"suspended formerly certified Water changed");
        (void)cost_tick(one);(void)cost_tick(four);cost_require_worker_parity(one,four);
        const auto now=four[2]->pressure_optimization_snapshot();
        require(!now.certificate_layer_enabled && now.certificate_contents_cold &&
                    now.certificate_suspend_remaining==static_cast<std::uint8_t>(31-t) &&
                    now.counters.certificate_invalidation_cells==before.certificate_invalidation_cells &&
                    now.counters.certificate_cold_resets==before.certificate_cold_resets &&
                    now.counters.certificate_attempts==before.certificate_attempts &&
                    now.counters.certificate_saved_calls==before.certificate_saved_calls,
                "all32 usable-head suspension ticks run ordinary motion with zero certificate maintenance or stale reads");
    }
    (void)cost_tick(one);(void)cost_tick(four);cost_require_worker_parity(one,four);
    const auto cold=four[2]->pressure_optimization_snapshot();
    require(cold.certificate_layer_enabled && !cold.certificate_contents_cold && cold.certificate_window_ticks==1U &&
                cold.counters.certificate_cold_resets==before.certificate_cold_resets+1U &&
                cold.counters.certificate_cold_reset_cells>before.certificate_cold_reset_cells &&
                cold.counters.certificate_saved_calls==before.certificate_saved_calls &&
                cold.counters.certificate_attempts==before.certificate_attempts,
            "reactivation charges one full cold reset before any old valid byte can skip its warmup visit");
}
CostWorlds cost_dense_awake_worlds(std::uint32_t workers) {
    CostWorlds worlds;
    for(int arm=0;arm<3;++arm) {
        auto cfg=cached_config(arm,false,workers);
        cfg.chunk_size=32;cfg.activity_block_size=32;cfg.scheduling_core_size=32;
        cfg.parallel_job_threshold=1;cfg.initial_chunk_reserve=8;
        cfg.maximum_chunk_count=32;cfg.active_chunk_capacity=32;cfg.active_core_capacity=32;
        auto world=std::make_unique<World>(cfg);
        for(const auto offset:{0,64,128,192}) {
            world->reserve_region({offset,0,32,32});rect(*world,offset,0,32,32,Material::Wall);
            rect(*world,offset+3,5,26,24,Material::Water);
            require(world->set_cell_state(offset+29,2,Material::Oil,0,200),"dense independently awake admission control");
        }
        worlds[static_cast<std::size_t>(arm)]=std::move(world);
    }
    return worlds;
}
void test_cost_positive_and_sleep() {
    auto one=cost_dense_awake_worlds(1),four=cost_dense_awake_worlds(4);
    std::uint64_t max_jobs=0;
    for(int t=0;t<64;++t) { (void)cost_tick(one);max_jobs=std::max(max_jobs,cost_tick(four));cost_require_worker_parity(one,four); }
    const auto warm=four[2]->pressure_optimization_snapshot();
    std::cout<<"LCB002_CERTIFICATE_COST_POSITIVE jobs="<<max_jobs<<" enabled="<<warm.certificate_layer_enabled<<" suspend="<<warm.counters.certificate_work_suspensions<<" saved="<<warm.counters.certificate_saved_calls<<" reuse="<<warm.counters.certificate_reuses<<" charge="<<warm.certificate_last_window_charge<<" credit="<<warm.certificate_last_window_credit<<" resets="<<warm.counters.certificate_cold_resets<<" invalid="<<warm.counters.certificate_invalidation_cells<<" attempts="<<warm.counters.certificate_attempts<<" coldcells="<<warm.counters.certificate_cold_reset_cells<<" chunks="<<four[2]->chunk_count()<<" water="<<warm.counters.water_material_calls<<"\n";
    require(max_jobs>=4U && warm.certificate_layer_enabled && warm.counters.certificate_work_suspensions==0U &&
                warm.counters.certificate_saved_calls>1000U && warm.counters.certificate_reuses>0U &&
                warm.certificate_last_window_charge<=warm.certificate_last_window_credit && warm.counters.certificate_cold_resets==1U &&
                warm.counters.water_motion_calls<four[0]->pressure_optimization_snapshot().counters.water_motion_calls/2U,
            "genuine four-job dispatch and unchanged dense awake stencils amortize the conservative work budget");
    auto sleep=cost_worlds(4,true,false);for(int t=0;t<16;++t)(void)cost_tick(sleep);
    const auto quiet=sleep[2]->pressure_optimization_snapshot().counters;
    for(int t=0;t<80;++t) {
        for(auto& world:sleep) require(world->tick().visited_cells==0U,"ordinary sleeping control has actual zero Water visits");
        for(std::size_t arm=1;arm<3;++arm)require_pressure_equivalent(*sleep[0],*sleep[arm]);
    }
    const auto rested=sleep[2]->pressure_optimization_snapshot().counters;
    require(rested.certificate_invalidation_cells==quiet.certificate_invalidation_cells && rested.certificate_cold_resets==quiet.certificate_cold_resets &&
                rested.certificate_attempts==quiet.certificate_attempts && rested.water_material_calls==quiet.water_material_calls,
            "off/cold ordinary sleep never periodically resets full resident storage or probes zero-visit work");
    for(auto& world:sleep) for(const auto offset:{0,16,32,48})
        require(world->set_cell_state(offset+6,1,Material::Oil,0,200),"new real Oil wake after suspension");
    (void)cost_tick(sleep);const auto first=sleep[2]->pressure_optimization_snapshot();
    require(first.counters.water_material_calls>rested.water_material_calls && first.counters.certificate_cold_resets==rested.certificate_cold_resets &&
                first.counters.certificate_saved_calls==rested.certificate_saved_calls,
            "first newly woken Water tick runs ordinary before any reactivation reset");
    (void)cost_tick(sleep);const auto next=sleep[2]->pressure_optimization_snapshot();
    require(next.counters.certificate_cold_resets==rested.certificate_cold_resets+1U && next.counters.certificate_saved_calls==rested.certificate_saved_calls,
            "actual prior Water work admits one charged cold reset and ordinary warmup");
}
void test_dormant_cost_admission() {
    static_assert(sizeof(cybersand::PressureKernelWork)==56U);
    test_cost_fallbacks_and_zero_saving();
    test_cost_heavy_maintenance_and_reactivation();
    test_cost_positive_and_sleep();
}

void test_cached_incremental_heads() {
    World reference(cached_config(0, false)), cached(cached_config(1, false));
    for (auto* world : {&reference, &cached}) {
        world->reserve_region({0, 0, 128, 128});
        rect(*world, 8, 8, 40, 1, Material::Wall);
        rect(*world, 8, 40, 40, 1, Material::Wall);
        rect(*world, 8, 8, 1, 33, Material::Wall);
        rect(*world, 47, 8, 1, 33, Material::Wall);
        rect(*world, 9, 20, 38, 20, Material::Water);
    }
    for (int t=0; t<280; ++t) {
        tick(reference); tick(cached); require_pressure_equivalent(reference, cached);
        (void)cached.take_dirty_chunks(); // Render consumption cannot invalidate physics.
    }
    const auto initial = cached.pressure_optimization_snapshot();
    require(initial.status == cybersand::PressureOptimizationStatus::Ready && initial.cached && !initial.dormant,
            "complete derived head snapshot is ready");
    require(initial.counters.base_cells_written < reference.pressure_optimization_snapshot().counters.base_cells_written / 4U,
            "quiet cached maintenance actually avoids reference column writes");
    for (auto* world : {&reference, &cached}) {
        world->set(8, 39, Material::Empty); world->set(9, 39, Material::Empty);
    }
    for (int t=0; t<60; ++t) { tick(reference); tick(cached); require_pressure_equivalent(reference, cached); }
    const auto bytes = cached.save_physical_state();
    auto restored = World::restore_physical_state(cached_config(1, false, 4), bytes);
    require(restored->pressure_optimization_snapshot().status == cybersand::PressureOptimizationStatus::Cold,
            "continuation cold-rebuilds derived state");
    for (int t=0; t<12; ++t) {
        tick(cached); tick(*restored);
        require(cached.physical_state_hash() == restored->physical_state_hash(), "warm/cold exact four-worker continuation");
    }
}

void test_cached_gas_and_fallback() {
    for (int mode=0; mode<3; ++mode) {
        auto candidate = cached_config(1, true);
        if (mode==1) candidate.pressure_optimization.index_chunk_capacity=1;
        if (mode==2) candidate.pressure_optimization.head_repair_cell_budget=0;
        World reference(cached_config(0, true)), cached(candidate);
        for (auto* world : {&reference, &cached}) {
            world->reserve_region({0, 0, 256, 128});
            room(*world,0); room(*world,24);
            world->configure_transient_obstacles({0,0,256,128});
        }
        for (int t=0; t<24; ++t) {
            for (auto* world : {&reference, &cached}) {
                if (t==4) world->set(5,8,Material::Empty);
                if (t==7) world->set(5,8,Material::Wall);
                if (t==10) rect(*world,1,19,10,1,Material::Empty);
                if (t==13) require(world->set_transient_obstacle(29,12,7), "new body mask installed");
                if (t==16) world->clear_transient_obstacles();
                if (t==18) require(world->queue_explosion(34,14,2), "future disturbance accepted");
            }
            tick(reference); tick(cached);
            try { require_pressure_equivalent(reference,cached); }
            catch (const std::exception& error) {
                std::cerr << "reference/cached content " << reference.content_hash() << "/" << cached.content_hash()
                          << " state " << reference.state_hash() << "/" << cached.state_hash() << '\n';
                for (const auto* world : {&reference, &cached}) {
                    std::cerr << "gas table";
                    for (const auto& item : world->gas_compartments())
                        std::cerr << " [" << item.id << ",v=" << item.volume << ",a=" << item.amount
                                  << ",rev=" << item.revision << ",h=" << item.gauge << "]";
                    std::cerr << '\n';
                }
                int shown=0;
                for (int y=0;y<128 && shown<12;++y) for(int x=0;x<256 && shown<12;++x) {
                    const auto a=reference.pressure_cell(x,y),b=cached.pressure_cell(x,y);
                    if (a.gas!=b.gas || a.flow!=b.flow || a.overfill!=b.overfill) {
                        std::cerr << "side " << x << "," << y << " gas=" << a.gas << "/" << b.gas
                                  << " flow=" << a.flow << "/" << b.flow << " over=" << a.overfill << "/" << b.overfill << '\n';
                        ++shown;
                    }
                }
                throw std::runtime_error("gas/fallback mode " + std::to_string(mode) + " at tick " +
                    std::to_string(t) + ": " + error.what());
            }
        }
        const auto observed=cached.pressure_optimization_snapshot();
        if (mode==0) require(observed.counters.gas_reuses>0 && observed.counters.gas_reference_passes>0,
                            "gas reuse and topology invalidation both execute");
        else require(observed.counters.reference_fallbacks>0 && observed.counters.fallback_resident_cells>0,
                     "capacity/budget fallback is complete, exact and charged");
    }
}

void test_dormant_motion_and_body_obligations() {
    for (const auto workers : {1U, 4U}) {
        World reference(cached_config(0,false,workers));
        World cached(cached_config(1,false,workers));
        World dormant(cached_config(2,false,workers));
        for (auto* world : {&reference,&cached,&dormant}) {
            world->reserve_region({0,0,128,128});
            rect(*world,1,1,14,14,Material::Wall);
            rect(*world,3,11,4,2,Material::Water);
            require(world->set_cell_state(11,12,Material::Oil,0,200), "independent Oil lifecycle fixture");
            world->configure_transient_obstacles({0,0,128,128});
        }
        for (int t=0;t<160;++t) {
            if (t==80) for (auto* world : {&reference,&cached,&dormant})
                require(world->set_transient_obstacle(3,13,7), "mask approaches warm stationary Water");
            if (t==96) for (auto* world : {&reference,&cached,&dormant}) world->clear_transient_obstacles();
            const auto before=dormant.pressure_optimization_snapshot();
            tick(reference); tick(cached); tick(dormant);
            if (before.certificate_suspend_remaining!=0U) {
                const auto after=dormant.pressure_optimization_snapshot();
                require(!after.certificate_layer_enabled && after.certificate_contents_cold &&
                            after.counters.certificate_invalidation_cells==before.counters.certificate_invalidation_cells &&
                            after.counters.certificate_attempts==before.counters.certificate_attempts &&
                            after.counters.certificate_saved_calls==before.counters.certificate_saved_calls,
                        "maintenance-heavy body control performs no certificate stamps, proofs or stale skips while suspended");
            }
            require_pressure_equivalent(reference,cached);
            require_pressure_equivalent(reference,dormant);
            require(reference.transient_contact_count(7)==dormant.transient_contact_count(7) &&
                    reference.transient_contact_impulse_x(7)==dormant.transient_contact_impulse_x(7) &&
                    reference.transient_contact_impulse_y(7)==dormant.transient_contact_impulse_y(7),
                    "failed stationary body contacts and both signed impulses remain exact");
            if (t>=80 && t<96) require(reference.transient_contact_count(7)>0,
                "stationary failed gravity actually reports a body contact");
        }
        const auto r=reference.pressure_optimization_snapshot().counters;
        const auto c=cached.pressure_optimization_snapshot().counters;
        const auto d=dormant.pressure_optimization_snapshot().counters;
        require(r.water_material_calls==c.water_material_calls && r.water_material_calls==d.water_material_calls &&
                r.other_liquid_calls==c.other_liquid_calls && r.other_liquid_calls==d.other_liquid_calls &&
                d.other_liquid_calls>=100U && reference.stored_state_b(11,12)<200U,
                "mandatory material stages and actual Oil lifecycle continue in the shared awake block");
        const auto admission=dormant.pressure_optimization_snapshot();
        std::cout<<"LCB002_BODY_COST_NEGATIVE workers="<<workers<<" saved="<<d.certificate_saved_calls<<" reuse="<<d.certificate_reuses<<" refmotion="<<r.water_motion_calls<<" motion="<<d.water_motion_calls<<" attempts="<<d.certificate_attempts<<" charge="<<admission.certificate_last_window_charge<<" credit="<<admission.certificate_last_window_credit<<" reset="<<d.certificate_cold_resets<<" suspended="<<d.certificate_work_suspensions<<"\n";
        require(c.certificate_saved_calls==0U && d.certificate_saved_calls>0U && d.certificate_reuses>0U &&
                    d.water_motion_calls+d.certificate_saved_calls==r.water_motion_calls,
                "bounded body-control trials remove actual motion calls and preserve every remaining ordinary call");
        require(admission.certificate_last_window_charge>admission.certificate_last_window_credit &&
                    d.certificate_work_windows>0U && d.certificate_work_suspensions>0U && d.certificate_suspended_ticks>0U &&
                    !admission.certificate_layer_enabled && admission.certificate_contents_cold,
                "sparse body-control savings cannot admit its larger resident maintenance cost; the whole layer suspends");
    }
}

void test_dormant_remote_gas_dependency() {
    auto make_config=[](int variant) {
        auto config=cached_config(variant,true);
        config.chunk_size=8; config.activity_block_size=8; config.scheduling_core_size=8;
        return config;
    };
    World reference(make_config(0)),cached(make_config(1)),dormant(make_config(2));
    for (auto* world : {&reference,&cached,&dormant}) {
        world->reserve_region({0,0,24,8});
        rect(*world,0,0,24,8,Material::Wall);
        rect(*world,9,2,13,3,Material::Empty);
        rect(*world,1,3,8,1,Material::Water);
        world->set_simulation_region(RectI64{0,0,8,8}); // Outlet Water is paused, still authoritative.
    }
    for (int t=0;t<4;++t) {
        tick(reference); tick(cached); tick(dormant);
        require_pressure_equivalent(reference,cached); require_pressure_equivalent(reference,dormant);
    }
    const auto prior=dormant.pressure_optimization_snapshot().counters;
    require(prior.certificate_saved_calls>0U && dormant.pressure_cell(7,3).flow==0,
            "remote gas test starts from an actually reused stationary certificate");
    for (auto* world : {&reference,&cached,&dormant}) world->set(20,1,Material::Empty);
    tick(reference); tick(cached); tick(dormant);
    require(reference.gas_compartments().at(0).gauge<0 && reference.pressure_cell(7,3).flow!=0,
            "remote sealed volume edit creates a real pressure gradient through a paused outlet");
    require_pressure_equivalent(reference,cached);
    require_pressure_equivalent(reference,dormant);
}
