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
            ? "5cb90321b69b062f7d6c9d9f6f7b71d8cfb7dd5ad99194f250c85e875da571e9"
            : "ea3815aa533f0ae0960e76772108b70dd6589eb4fa6e3770421ef894deeb6ec0";
        require(identity && cybersand::Sha256::hex(*identity) == expected && extensions[0].extension_identity_version == 1U,
                "cached/dormant execution2 has its declared native identity encoding1");
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

void test_dormant_cost_admission() {
    std::array<std::unique_ptr<World>,3> worlds;
    for (int arm=0; arm<3; ++arm) {
        auto world=std::make_unique<World>(cached_config(arm,false));
        world->reserve_region({0,0,128,128});
        rect(*world,1,1,14,14,Material::Wall);
        require(world->set_cell_state(3,11,Material::Water,128,0), "partial stationary cost control");
        require(world->set_cell_state(11,12,Material::Oil,0,200), "independent awake-block lifecycle");
        worlds[static_cast<std::size_t>(arm)]=std::move(world);
    }
    for (int t=0;t<48;++t) {
        const auto before=worlds[2]->pressure_optimization_snapshot().counters;
        for (auto& world:worlds) tick(*world);
        for (std::size_t arm=1;arm<3;++arm) require_pressure_equivalent(*worlds[0],*worlds[arm]);
        const auto after=worlds[2]->pressure_optimization_snapshot().counters;
        if (t==0) require(after.certificate_attempts==before.certificate_attempts &&
                             after.water_motion_calls>before.water_motion_calls,
                         "cold certificate defers proof and executes ordinary motion");
    }
    const auto denied=worlds[2]->pressure_optimization_snapshot().counters;
    require(denied.certificate_attempts>0U && denied.certificate_attempts<=6U &&
                denied.certificate_declines>=40U && denied.certificate_saved_calls==0U &&
                denied.water_motion_calls==denied.water_material_calls && denied.water_material_calls>=40U,
            "failed proofs have bounded visit-based retry cost while all ordinary work continues");
    for (auto& world:worlds) require(world->set_cell_state(3,11,Material::Water,64,0), "changed proof input");
    for (auto& world:worlds) tick(*world);
    for (std::size_t arm=1;arm<3;++arm) require_pressure_equivalent(*worlds[0],*worlds[arm]);
    require(worlds[2]->pressure_optimization_snapshot().counters.certificate_attempts==denied.certificate_attempts,
            "changed inputs revoke the old state and require an ordinary warmup visit");

    auto warm=std::make_unique<World>(cached_config(2,false));
    warm->reserve_region({0,0,128,128});
    rect(*warm,1,1,14,14,Material::Wall); rect(*warm,3,11,4,2,Material::Water);
    require(warm->set_cell_state(11,12,Material::Oil,0,200), "warm positive independent lifecycle");
    tick(*warm,16);
    require(warm->pressure_optimization_snapshot().counters.certificate_reuses>0U,
            "positive unchanged input still amortizes proof through genuine reuse");
    auto restored=World::restore_physical_state(cached_config(2,false),warm->save_physical_state());
    tick(*warm); tick(*restored);
    require(warm->physical_state_hash()==restored->physical_state_hash() &&
                restored->pressure_optimization_snapshot().counters.certificate_attempts==0U &&
                restored->pressure_optimization_snapshot().counters.certificate_saved_calls==0U,
            "restored derived certificates start cold and cannot interpret countdown bytes as valid");
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
            tick(reference); tick(cached); tick(dormant);
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
        require(c.certificate_saved_calls==0U && d.certificate_saved_calls>500U &&
                d.certificate_reuses>0U && d.water_motion_calls<r.water_motion_calls/2U,
                "positive certificate removes actual pressure motion beyond ordinary block sleep");
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

