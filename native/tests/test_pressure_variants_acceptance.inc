// Ordinary #201 acceptance schedules. Included after the existing pressure
// helpers; all three implementations execute the same native authority.
using AcceptanceWorlds = std::array<std::unique_ptr<World>, 3>;

using PressureHeadRosters = std::array<std::vector<cybersand::ChunkCoord>,3>;
PressureHeadRosters preallocate_head_rosters(const AcceptanceWorlds& worlds) {
    PressureHeadRosters output;
    for (std::size_t arm=0;arm<3;++arm) output[arm].resize(worlds[arm]->config().maximum_chunk_count);
    return output;
}
std::pair<std::uint64_t,std::uint64_t> compare_resident_prepared_heads(const AcceptanceWorlds& worlds, PressureHeadRosters& rosters) {
    std::array<std::size_t,3> counts{};
    for (std::size_t arm=0;arm<3;++arm) {
        const auto required=worlds[arm]->chunk_count();
        std::array<cybersand::ChunkCoord,2> short_output{{{991,997},{1009,1013}}};
        const auto sentinel=short_output;
        if (required>short_output.size()) require(worlds[arm]->copy_pressure_head_chunk_coordinates(short_output)==required && short_output==sentinel,
                "short copied roster reports full required count and writes NOTHING");
        counts[arm]=worlds[arm]->copy_pressure_head_chunk_coordinates(rosters[arm]);
        require(counts[arm]==required && counts[arm]<=rosters[arm].size(),"preallocated actual resident roster is complete");
        std::sort(rosters[arm].begin(),rosters[arm].begin()+static_cast<std::ptrdiff_t>(counts[arm]),
                [](auto a,auto b){return a.y!=b.y ? a.y<b.y : a.x<b.x;});
        require(std::adjacent_find(rosters[arm].begin(),rosters[arm].begin()+static_cast<std::ptrdiff_t>(counts[arm]))==rosters[arm].begin()+static_cast<std::ptrdiff_t>(counts[arm]),
                "successful copied roster contains no duplicate coordinate");
        require(counts[arm]==counts[0] && std::equal(rosters[0].begin(),rosters[0].begin()+static_cast<std::ptrdiff_t>(counts[0]),rosters[arm].begin()),
                "all actual resident coordinates agree across pressure variants");
    }
    std::uint64_t resident=0, prepared=0;
    const auto size=worlds[0]->config().chunk_size;
    for (std::size_t chunk=0;chunk<counts[0];++chunk) {
        const auto coordinate=rosters[0][chunk];
        for (std::int64_t dy=0;dy<size;++dy) for (std::int64_t dx=0;dx<size;++dx) {
            const auto x=coordinate.x*size+dx,y=coordinate.y*size+dy;
            const auto reference=worlds[0]->prepared_pressure_head(x,y);
            for (const auto& world:worlds) {
                const auto copied=world->prepared_pressure_head(x,y);
                require(copied==reference,"every actual resident copied head status/value agrees exactly");
                require(copied.status==cybersand::PressureHeadStatus::Prepared || copied.status==cybersand::PressureHeadStatus::NoHead,
                        "completed resident prepared field is neither missing nor unresolved");
            }
            ++resident;
            if (reference.status==cybersand::PressureHeadStatus::Prepared) ++prepared;
        }
    }
    require(resident==worlds[0]->chunk_count()*static_cast<std::uint64_t>(size)*static_cast<std::uint64_t>(size),
            "copied native roster covers EVERY resident cell, including gas-discovery allocations");
    return {resident,prepared};
}

WorldConfig acceptance_config(int variant, std::uint32_t workers, bool gas = false,
                              std::uint8_t cadence = 1) {
    auto config = cached_config(variant, gas, workers);
    config.chunk_size = 8;
    config.activity_block_size = 8;
    config.scheduling_core_size = 8;
    config.parallel_job_threshold = 1;
    config.maximum_chunk_count = 512;
    config.active_chunk_capacity = 512;
    config.active_core_capacity = 512;
    if (cadence != 1) {
        config.transport_policy.configured = true;
        config.transport_policy.cadence[3] = cadence;
    }
    return config;
}

AcceptanceWorlds acceptance_worlds(std::uint32_t workers, bool gas = false, std::uint8_t cadence = 1) {
    AcceptanceWorlds worlds;
    for (int arm = 0; arm < 3; ++arm)
        worlds[static_cast<std::size_t>(arm)] = std::make_unique<World>(acceptance_config(arm, workers, gas, cadence));
    return worlds;
}

void acceptance_equal(const AcceptanceWorlds& worlds, const std::string& stage) {
    for (std::size_t arm = 1; arm < worlds.size(); ++arm) {
        try {
            require_gas_cache_equivalent(*worlds[0], *worlds[arm]);
            require(worlds[0]->quantity_ledger() == worlds[arm]->quantity_ledger(),
                    "full source/sink and population ledger agrees");
        } catch (const std::exception& error) {
            throw std::runtime_error(stage + " arm " + std::to_string(arm) + ": " + error.what());
        }
    }
}

void acceptance_tick(AcceptanceWorlds& worlds, int count, const std::string& stage) {
    for (int t = 0; t < count; ++t) {
        for (auto& world : worlds) tick(*world);
        acceptance_equal(worlds, stage + " tick " + std::to_string(t));
    }
}

// Compare logical authority between sparse/preallocated controls separately from
// same-domain complete projection parity: resident Empty chunks and scheduler
// coverage legitimately enter the complete hash.
std::vector<std::int64_t> acceptance_logical_observation(const World& world) {
    std::vector<std::int64_t> values;
    for (std::int64_t y = -56; y < 24; ++y) for (std::int64_t x = -32; x < 32; ++x) {
        const auto pressure = world.pressure_cell(x, y);
        values.insert(values.end(), {static_cast<std::int64_t>(world.stored_material(x, y)),
            world.stored_state_a(x, y), world.stored_state_b(x, y), world.temperature(x, y),
            pressure.flow, pressure.overfill, pressure.gas});
    }
    values.push_back(world.stored_state_b(1027, 1027));
    return values;
}

void test_variants_remote_hydraulic_acceptance() {
    for (const auto workers : {1U, 4U}) {
        std::vector<std::vector<std::int64_t>> sparse_trace;
        for (const bool preallocated : {false, true}) {
            auto worlds = acceptance_worlds(workers);
            for (auto& world : worlds) {
                if (preallocated) world->reserve_region({-40, -64, 80, 96});
                // The 48-cell full horizontal run crosses positive/negative
                // chunk seams. A distant source column is initially solid.
                rect(*world, -25, -49, 3, 67, Material::Wall);
                rect(*world, -25, 15, 50, 3, Material::Wall);
                rect(*world, -24, -49, 1, 65, Material::Empty);
                world->set(23, 15, Material::Empty);
                rect(*world, -24, 16, 48, 1, Material::Water);
                rect(*world, 17, 18, 3, 3, Material::Wall);
                require(world->set_cell_state(18, 19, Material::Oil, 0, 200), "awake target Oil");
                rect(*world, 1026, 1026, 3, 3, Material::Wall);
                require(world->set_cell_state(1027, 1027, Material::Oil, 0, 200), "distant active island");
                world->set_simulation_region(RectI64{8, 16, 16, 8});
            }
            std::size_t observation = 0;
            const auto checkpoint = [&] {
                const auto state = acceptance_logical_observation(*worlds[0]);
                if (!preallocated) sparse_trace.push_back(state);
                else require(state == sparse_trace.at(observation), "sparse/preallocated logical continuation agrees");
                ++observation;
            };
            acceptance_tick(worlds, 12, "certified narrow resting passage");
            require(worlds[2]->pressure_optimization_snapshot().counters.certificate_reuses > 0 &&
                        worlds[2]->pressure_cell(16, 16).flow == 0,
                    "target is full and actually uses a warm rest certificate");
            require(worlds[0]->stored_state_b(1027, 1027) == 200,
                    "distant island remains paused under narrow interest");
            checkpoint();
            // Only the remote Water source changes, 40 cells from the target.
            // It remains outside interest but contributes its complete head.
            for (auto& world : worlds) rect(*world, -24, -48, 1, 64, Material::Water);
            acceptance_tick(worlds, 4, "remote resident reservoir rises");
            bool momentum = false;
            bool full_receiver = false;
            for (int x = 8; x < 24; ++x) momentum = momentum || worlds[0]->pressure_cell(x, 16).flow != 0;
            for (int x = 8; x < 24; ++x)
                full_receiver = full_receiver || (worlds[0]->stored_state_a(x, 16) == 255U &&
                                                  worlds[0]->pressure_cell(x, 16).overfill > 0U);
            require(momentum, "remote height change produces actual same-Water momentum in the full target");
            require(full_receiver, "incoming same-material flux actually reaches a saturated target receiver");
            checkpoint();
            for (auto& world : worlds) world->set_simulation_region(std::nullopt);
            acceptance_tick(worlds, 4, "broad interest and distant re-entry");
            require(worlds[0]->stored_state_b(1027, 1027) < 200,
                    "broad interest executes mandatory work on the distant island");
            checkpoint();
            const auto before = worlds[0]->water_quantity({8, 16, 16, 1});
            for (auto& world : worlds) rect(*world, 24, 16, 7, 1, Material::Empty);
            acceptance_tick(worlds, 16, "drain opens away from the target core");
            require(worlds[0]->water_quantity({24, 16, 7, 1}) > 0 &&
                        worlds[0]->water_quantity({8, 16, 16, 1}) < before,
                    "new outlet actually drains the previously full target");
            checkpoint();
            for (auto& world : worlds) {
                rect(*world, 24, 16, 7, 1, Material::Wall);
                world->set_simulation_region(RectI64{8, 16, 16, 8});
            }
            acceptance_tick(worlds, 8, "drain closes and narrow interest returns");
            checkpoint();
        }
    }
}

void test_variants_communicating_basins_acceptance() {
    {
        auto current=std::make_unique<World>();
        std::array<cybersand::ChunkCoord,2> output{{{991,997},{1009,1013}}};
        const auto original=output; const auto hash=current->physical_state_hash();
        require(current->copy_pressure_head_chunk_coordinates(output)==0U && output==original &&
                    current->chunk_count()==0U && current->physical_state_hash()==hash,
                "default family returns zero roster and leaves the complete caller output/World untouched");
    }
    for (const auto workers : {1U, 4U}) for (const auto passage_height : {1, 4}) {
        auto worlds = acceptance_worlds(workers);
        for (auto& world : worlds) {
            world->reserve_region({0, 0, 48, 48});
            rect(*world, 2, 2, 36, 40, Material::Wall);
            rect(*world, 4, 3, 8, 37, Material::Empty);
            rect(*world, 28, 3, 8, 37, Material::Empty);
            rect(*world, 4, 12, 8, 28, Material::Water);
            rect(*world, 28, 28, 8, 12, Material::Water);
            rect(*world, 12, 40 - passage_height, 16, passage_height, Material::Water);
        }
        const auto quantity_before = worlds[0]->water_quantity({0, 0, 48, 48});
        // Copy every resident prepared head slot, including non-Water and
        // paused cells. This observes the last pre-kernel field, which can be
        // stale after transport; it is never a current-pressure/rest authority.
        auto head_rosters=preallocate_head_rosters(worlds);
        const auto source_hash=worlds[0]->physical_state_hash();
        (void)compare_resident_prepared_heads(worlds,head_rosters);
        require(worlds[0]->physical_state_hash()==source_hash,"copying/sorting actual roster and reading heads leaves authority unchanged");
        const RectI64 lower_limb{28, 3, 8, 37};
        std::uint64_t resident_samples = 0, prepared_samples = 0, positive_inflow_ticks = 0;
        std::int64_t maximum_net_inflow = 0;
        for (int t = 0; t < 240; ++t) {
            std::array<std::uint64_t,3> start_quantity{};
            std::array<std::array<cybersand::WaterQuantityFlow,cybersand::kQuantityKindCount>,3> start_kinds{};
            for (std::size_t arm = 0; arm < 3; ++arm) {
                start_quantity[arm] = worlds[arm]->water_quantity(lower_limb);
                start_kinds[arm] = worlds[arm]->quantity_ledger().kinds;
            }
            acceptance_tick(worlds, 1, "vented communicating basin passage " + std::to_string(passage_height));
            std::array<std::int64_t,3> net_inflow{};
            const auto [resident,prepared]=compare_resident_prepared_heads(worlds,head_rosters);
            prepared_samples+=prepared;
            for (std::size_t arm = 0; arm < 3; ++arm) {
                require(worlds[arm]->quantity_ledger().kinds == start_kinds[arm],
                        "net-boundary control has zero tick Water sources/sinks and no host Water edits");
                net_inflow[arm] = static_cast<std::int64_t>(worlds[arm]->water_quantity(lower_limb)) -
                                  static_cast<std::int64_t>(start_quantity[arm]);
            }
            require(net_inflow[0] == net_inflow[1] && net_inflow[0] == net_inflow[2],
                    "declared lower-limb net Water boundary inflow agrees each tick");
            if (net_inflow[0] > 0) ++positive_inflow_ticks;
            maximum_net_inflow = std::max(maximum_net_inflow, net_inflow[0]);
            resident_samples += resident;
        }
        require(prepared_samples > 0 && positive_inflow_ticks > 0,
                "full resident head comparisons and a real positive boundary inflow are exercised");
        std::cout << "LCB002_BASIN_DIAGNOSTICS: workers=" << workers << " passage_height=" << passage_height
                  << " resident_samples_per_arm=" << resident_samples << " prepared_samples_per_arm=" << prepared_samples
                  << " max_head_error=0 status_mismatches=0 positive_net_inflow_ticks=" << positive_inflow_ticks
                  << " maximum_net_inflow=" << maximum_net_inflow << " tick_sources=0 tick_sinks=0\n";
        // Signed ROI delta is NET boundary inflow under zero sources/sinks;
        // it does not measure gross individual face transfers or both-way flux.
        require(worlds[0]->water_quantity({0, 0, 48, 48}) == quantity_before,
                "communicating basins preserve exact visible plus overfill quantity");
        bool raised = false;
        for (int x = 28; x < 36; ++x) for (int y = 3; y < 28; ++y)
            raised = raised || worlds[0]->stored_material(x, y) == Material::Water;
        require(raised, "narrow and broad saturated passages actually transmit head into the lower limb");
    }
}

void test_variants_rotating_mask_acceptance() {
    for (const auto workers : {1U, 4U}) {
        auto worlds = acceptance_worlds(workers, true);
        for (auto& world : worlds) {
            gas_cache_rooms(*world, -24, -8);
            require(world->set_cell_state(-22, -3, Material::Oil, 0, 200), "unrelated Oil lifecycle");
            world->configure_transient_obstacles({-24, -8, 88, 8});
        }
        acceptance_tick(worlds, 8, "mask control warmup");
        const auto quantity_before = worlds[0]->water_quantity({-24, -8, 88, 8});
        std::uint64_t contacts = 0;
        auto head_rosters=preallocate_head_rosters(worlds);
        for (int t = 0; t < 24; ++t) {
            for (auto& world : worlds) {
                world->clear_transient_obstacles();
                // Horizontal/vertical raster orientations, followed by a
                // translated orientation, cross Water/Empty and chunk seams.
                const auto cx = -17 + (t / 8);
                for (int d = -1; d <= 1; ++d) {
                    const auto x = (t % 2) ? cx : cx + d;
                    const auto y = (t % 2) ? -5 + d : -5;
                    require(world->set_transient_obstacle(x, y, 9), "rotating current native mask accepted");
                }
            }
            acceptance_tick(worlds, 1, "moving/rotating native masks");
            (void)compare_resident_prepared_heads(worlds,head_rosters);
            contacts += worlds[0]->transient_contact_count(9);
            for (std::size_t arm = 1; arm < 3; ++arm)
                require(worlds[0]->transient_contact_count(9) == worlds[arm]->transient_contact_count(9) &&
                            worlds[0]->transient_contact_impulse_x(9) == worlds[arm]->transient_contact_impulse_x(9) &&
                            worlds[0]->transient_contact_impulse_y(9) == worlds[arm]->transient_contact_impulse_y(9),
                        "current mask contacts and both signed impulses agree");
            require(worlds[0]->water_quantity({-24, -8, 88, 8}) == quantity_before,
                    "mask routing preserves resident Water quantity including masked cells");
        }
        require(contacts > 0, "rotating mask fixture actually produces native contacts");
        for (auto& world : worlds) world->clear_transient_obstacles();
        acceptance_tick(worlds, 8, "moving mask removed");
        // Native mask raster behavior is covered here. Host body displacement
        // and actual rotating Rapier ownership require the host/platform lane.
    }
}

void test_variants_obligation_reconstruction_acceptance() {
    for (const auto workers : {1U, 4U}) for (const auto cadence : {std::uint8_t{1}, std::uint8_t{4}}) {
        auto worlds = acceptance_worlds(workers, false, cadence);
        for (auto& world : worlds) {
            rect(*world, 1, 1, 14, 14, Material::Wall);
            rect(*world, 3, 11, 4, 2, Material::Water);
            require(world->set_cell_state(11, 12, Material::Oil, 0, 200), "mandatory independent Oil");
        }
        acceptance_tick(worlds, 12, "obligation warmup");
        const auto warm = worlds[2]->pressure_optimization_snapshot().counters;
        if (cadence == 1) require(warm.certificate_reuses > 0, "reconstruction begins from reused certificates");
        else require(warm.certificate_saved_calls == 0 && warm.certificate_declines > 0,
                     "non-default cadence explicitly declines motion certificates");
        for (auto& world : worlds) {
            world->set(2, 12, Material::ToxicSludge);
            world->set_temperature(4, 12, 777);
            require(world->set_cell_state(10, 4, Material::Steam, 1, 0), "due Steam-to-Water conversion");
        }
        acceptance_tick(worlds, 2, "pair chemistry, temperature and kernel conversion");
        const auto ledger = worlds[0]->quantity_ledger();
        require(ledger.kinds[static_cast<std::size_t>(cybersand::QuantityKind::PairReaction)].produced > 0 &&
                    ledger.kinds[static_cast<std::size_t>(cybersand::QuantityKind::KernelConversion)].produced > 0,
                "mandatory reaction and phase conversion actually execute beside certified Water");
        for (auto& world : worlds) require(world->queue_explosion(5, 12, 1), "pending native event queued");
        AcceptanceWorlds restored;
        for (int arm = 0; arm < 3; ++arm) {
            const auto i = static_cast<std::size_t>(arm);
            restored[i] = World::restore_physical_state(acceptance_config(arm, workers, false, cadence),
                                                       worlds[i]->save_physical_state());
            if (arm != 0) require(restored[i]->pressure_optimization_snapshot().status ==
                                    cybersand::PressureOptimizationStatus::Cold,
                                "scene reconstruction never restores certificate authority");
        }
        for (int t = 0; t < 12; ++t) {
            acceptance_tick(worlds, 1, "warm pending-event continuation");
            acceptance_tick(restored, 1, "cold pending-event continuation");
            for (std::size_t arm = 0; arm < 3; ++arm)
                require(worlds[arm]->physical_state_hash() == restored[arm]->physical_state_hash() &&
                            worlds[arm]->quantity_ledger() == restored[arm]->quantity_ledger(),
                        "warm and reconstructed native event/chemistry continuation agrees exactly");
        }
        require(worlds[0]->quantity_ledger().kinds[static_cast<std::size_t>(cybersand::QuantityKind::DeferredEvent)].consumed > 0 &&
                    worlds[0]->stored_state_b(11, 12) < 200,
                "event sink and unrelated material lifecycle remain live");
    }
}

void test_variants_isolated_vent_acceptance() {
    for (const auto workers : {1U, 4U}) {
        auto worlds = acceptance_worlds(workers, true);
        for (auto& world : worlds) {
            rect(*world, 0, 0, 32, 8, Material::Wall);
            rect(*world, 1, 1, 5, 2, Material::Empty);
            rect(*world, 26, 1, 5, 2, Material::Empty);
            rect(*world, 3, 3, 1, 3, Material::Water);
            rect(*world, 28, 3, 1, 3, Material::Water);
            rect(*world, 3, 6, 26, 1, Material::Water);
            require(world->set_cell_state(10, 3, Material::Oil, 0, 200), "vent target remains awake");
            world->set_simulation_region(RectI64{8, 0, 16, 8});
        }
        acceptance_tick(worlds, 2, "equal isolated pocket creation");
        require(worlds[0]->gas_compartments().size() == 2U, "vent fixture begins with two independent sealed pockets");
        // Compress both pockets equally, leaving two Empty cells over each
        // paused Water column. Equal endpoint pressures leave the full target
        // at rest while storing a real pressure difference from atmosphere.
        for (auto& world : worlds) {
            for (int x = 1; x <= 5; ++x) if (x != 3) rect(*world, x, 1, 1, 2, Material::Wall);
            for (int x = 26; x <= 30; ++x) if (x != 28) rect(*world, x, 1, 1, 2, Material::Wall);
        }
        acceptance_tick(worlds, 12, "equal sealed compression and certified target");
        const auto pockets = worlds[0]->gas_compartments();
        require(pockets.size() == 2U && pockets[0].gauge > 0 && pockets[0].gauge == pockets[1].gauge &&
                    worlds[2]->pressure_optimization_snapshot().counters.certificate_reuses > 0 &&
                    worlds[2]->pressure_cell(12, 6).flow == 0,
                "equal positive gas pressures leave a genuinely certified full target at rest");
        const auto before = worlds[0]->gas_ledger();
        for (auto& world : worlds) world->set(3, 0, Material::Empty);
        acceptance_tick(worlds, 4, "one isolated remote vent opens");
        bool target_flow = false;
        for (int x = 8; x < 24; ++x) target_flow = target_flow || worlds[0]->pressure_cell(x, 6).flow != 0;
        require(worlds[0]->gas_ledger().vents > before.vents && target_flow,
                "isolated vent retirement actually wakes the full core without any target material edit");
    }
}
