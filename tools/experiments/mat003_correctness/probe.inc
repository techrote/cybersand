// Included only in the generated PrecisionProbe friend class.
    template<class... T> static void row(std::ostream& out,const std::string& key,T... values) {
        out<<key;((out<<' '<<+values),...);out<<'\n';
    }
    static bool neutral_admit(World& world,std::int64_t x,std::int64_t y,std::uint64_t value) {
        if(world.tick_in_progress_||world.tick_failed_)return false;
        auto address=world.address(x,y);auto* chunk=world.find_chunk(address.chunk);
        return chunk && chunk->cells[address.index].set_neutral_extra(value);
    }
    static void seed(World& world) {
        const auto initialize=[&](std::int64_t x,std::int64_t y,std::uint16_t r,std::uint64_t u,std::uint16_t a) {
            auto address=world.address(x,y);auto& cell=world.find_chunk(address.chunk)->cells[address.index];
            auto value=cell.read();value.r=mat003_world::Cell::supports_r?r:0;
            constexpr auto width=mat003_world::Cell::unused_width();
            if constexpr(width<64)value.u=u&((std::uint64_t{1}<<width)-1);else value.u=u;
            value.a=a;fixture::require(cell.write_raw(value),"raw fixture seed refused");
        };
        initialize(3,3,0x81a5,~std::uint64_t{0},0);
        initialize(7,7,0x8000,0,0x8001);
        initialize(8,7,0x00ff,0,0xffff);initialize(9,7,0xff00,0,0x8000);
        initialize(10,7,0x5555,0,0x7fff);initialize(11,7,0xaaaa,0,0x0100); // labelled raw nonzero Empty/high state
        initialize(20,20,0x0100,0,255);
        initialize(40,40,0xff00,0,world.config_.water_experiment_policy.maximum());
        world.set_temperature(7,7,-1234);world.set_temperature(8,7,-32768);world.set_temperature(9,7,32767);
    }
    static bool admit(World& world,std::int64_t x,std::int64_t y,std::uint64_t schema,std::int64_t m,std::int64_t a,std::int64_t b,std::int64_t r) {
        if(schema!=1||world.tick_failed_||world.tick_in_progress_||m<0||m>65535||a<0||a>65535||b<0||b>255||r<0||r>65535)return false;
        if(!valid_material(static_cast<std::uint16_t>(m)))return false;
        const auto material=static_cast<Material>(m);
        if((material==Material::Water && (a==0||a>world.config_.water_experiment_policy.maximum()||b>world.config_.water_experiment_policy.coherence_ticks()))||(material!=Material::Water&&a>255))return false;
        if(!mat003_world::Cell::supports_r&&r)return false;
        const auto address=world.address(x,y);auto* chunk=world.find_chunk(address.chunk);
        if(!chunk||!chunk->temperatures)return false; // capacity/sidecar preflight, no hidden allocation
        (void)world.set_cell_state(x,y,material,static_cast<std::uint16_t>(a),static_cast<std::uint8_t>(b));
        auto value=chunk->cells[address.index].read();value.r=r;value.u=0;
        fixture::require(chunk->cells[address.index].write_raw(value),"prevalidated record publication failed");return true;
    }
    static auto raw_at(const World& world,std::int64_t x,std::int64_t y){auto a=world.address(x,y);return world.find_chunk(a.chunk)->cells[a.index].canonical();}
    static void seed_unused(World& world,std::int64_t x,std::int64_t y) {
        auto a=world.address(x,y);auto& cell=world.find_chunk(a.chunk)->cells[a.index];
        const mat003_world::Cell::Base before=cell;
        auto value=cell.read();constexpr unsigned width=mat003_world::Cell::unused_width();
        if constexpr(width<64)value.u=(std::uint64_t{1}<<width)-1;else value.u=~std::uint64_t{0};
        fixture::require(cell.write_raw(value),"raw unused seed refused");
        mat003_correctness::trace(4,static_cast<const mat003_world::Cell::Base&>(cell),static_cast<const mat003_world::Cell::Base*>(nullptr),before,value.u,true);
    }
    static void registry(const World& world,const std::filesystem::path& path) {
        std::ofstream out(path);
        for(auto coord:coordinates(world)){const auto& c=*world.find_chunk(coord);row(out,std::to_string(coord.x)+":"+std::to_string(coord.y),c.cells.size(),reinterpret_cast<std::uintptr_t>(c.cells.data()));}
        fixture::require(bool(out),"registry write failure");
    }
    static void tick_receipt(const World& world,const TickStats& stats,std::ostream& out) {
        std::uint64_t water=0,sand=0;
        for(const auto& [coord,p]:world.chunks_)for(const auto& c:p->cells){
            (void)coord;if(c.material_value()==Material::Water)water+=c.state_a_value();
            if(c.material_value()==Material::Sand)++sand;
        }
        const auto d=mat003_world::dispatch_observations();
        out<<world.completed_tick_index_<<' '<<unsigned(world.update_epoch_)<<' '<<stats.visited_cells<<' '<<stats.moved_cells<<' '<<stats.scheduled_cores;
        for(auto v:stats.phase_jobs)out<<' '<<v;
        out<<' '<<stats.chunk_allocations<<' '<<stats.temperature_field_allocations<<' '<<stats.deferred_events
           <<' '<<water<<' '<<sand<<' '<<d.calls<<' '<<d.dispatched_tasks<<' '<<d.worker_tasks<<' '<<mat003_world::clear_count<<' '<<mat003_world::clear_cells<<'\n';
    }
    static void canonical_endpoint(const World& world,const TickStats& stats,const std::filesystem::path& root,bool metadata_only=false) {
        fixture::require(!world.tick_in_progress_,"endpoint during tick");
        fixture::require(!world.settled_discovery_,"unexported discovery owner");
        fixture::require(!std::filesystem::exists(root),"endpoint overwrite");
        std::filesystem::create_directories(root);
        std::ofstream raw(root/"cells.bin",std::ios::binary),index(root/"chunks.txt"),meta(root/"metadata.txt");
        row(meta,"layout",sizeof(World::Chunk::Cell),alignof(World::Chunk::Cell),sizeof(mat003_world::Cell::Storage),alignof(mat003_world::Cell::Storage),MAT003_CAPACITY==128?offsetof(mat003_correctness::Dual,high):0);
        row(meta,"schema",1,MAT003_CAPACITY,MAT003_EPOCH_BITS,sizeof(World::Chunk::Cell),alignof(World::Chunk::Cell));
        row(meta,"clock",world.tick_index_,world.completed_tick_index_,unsigned(world.update_epoch_),world.tick_failed_,world.tick_in_progress_);
        row(meta,"flags",world.flow_mixing_enabled_,world.flow_carrying_enabled_,world.liquid_surface_adhesion_enabled_);
        row(meta,"allocations",world.tick_chunk_allocations_,world.tick_temperature_field_allocations_,world.hard_surface_revision_);
        const auto& c=world.config_;
        row(meta,"config",c.chunk_size,c.sleep_after_quiet_ticks,c.ambient_temperature,c.initial_chunk_reserve,static_cast<unsigned>(c.backend),c.activity_block_size,c.scheduling_core_size,c.maximum_rule_radius,c.worker_threads,c.parallel_job_threshold,c.active_core_capacity,c.active_chunk_capacity,c.maximum_chunk_count,c.deferred_event_capacity,c.maximum_explosion_radius,c.settled_discovery_enabled,c.settled_discovery_tile_capacity,c.settled_discovery_tick_budget,c.settled_region_connectivity_enabled,c.settled_region_tick_budget);
        row(meta,"physics_config",c.physics_diagnostics.enabled,c.physics_diagnostics.disable_powder_exchange_targets,c.physics_diagnostics.mercury_viscosity);
        row(meta,"interaction",c.interaction_policy.version,c.interaction_policy.downward_support_cells,c.interaction_policy.side_support_cells,c.interaction_policy.mercury_exchange_period);
        row(meta,"water_policy",c.water_experiment_policy.version(),c.water_experiment_policy.mass_bits(),c.water_experiment_policy.coherence_ticks(),static_cast<unsigned>(c.water_experiment_policy.rest_policy()),c.water_experiment_policy.maximum(),c.water_experiment_policy.film(),c.water_experiment_policy.tolerance());
        meta<<"transport "<<c.transport_policy.configured;
        for(auto v:c.transport_policy.horizontal)meta<<' '<<unsigned(v);
        for(auto v:c.transport_policy.cadence)meta<<' '<<unsigned(v);
        for(const auto& p:c.transport_policy.pairs)meta<<' '<<unsigned(p.mixing)<<' '<<unsigned(p.carrying)<<' '<<unsigned(p.pickup)<<' '<<unsigned(p.packing)<<' '<<unsigned(p.erosion)<<' '<<unsigned(p.permeability);
        meta<<'\n';
        for(const auto coord:coordinates(world)) {
            const auto& chunk=*world.find_chunk(coord);const auto key=std::to_string(coord.x)+":"+std::to_string(coord.y);
            index<<coord.x<<' '<<coord.y<<' '<<chunk.cells.size()<<' '<<bool(chunk.temperatures)<<' '<<reinterpret_cast<std::uintptr_t>(chunk.cells.data())<<'\n';
            if(!metadata_only)for(std::size_t i=0;i<chunk.cells.size();++i) {
                auto bytes=chunk.cells[i].canonical();raw.write(reinterpret_cast<const char*>(bytes.data()),bytes.size());
                auto t=static_cast<std::uint16_t>(chunk.temperatures?(*chunk.temperatures)[i]:c.ambient_temperature);
                raw.put(static_cast<char>(t&255));raw.put(static_cast<char>(t>>8));
            }
            row(meta,"chunk:"+key,chunk.activity_blocks_per_axis,chunk.non_empty_cell_count,chunk.active,chunk.changed_this_tick,chunk.quiet_ticks,chunk.dirty,chunk.dirty_min_x,chunk.dirty_min_y,chunk.dirty_max_x,chunk.dirty_max_y,chunk.activity_blocks.size());
            for(std::size_t i=0;i<chunk.activity_blocks.size();++i){const auto& b=chunk.activity_blocks[i];row(meta,"block:"+key+":"+std::to_string(i),b.next_interaction_tick,b.quiet_ticks,b.active,b.changed_this_tick);}
        }
        const auto region=[&](const char* key,const auto& r){if(r)row(meta,key,1,r->min_x,r->min_y,r->max_x,r->max_y);else row(meta,key,0);};
        if(world.simulation_region_){const auto& r=*world.simulation_region_;row(meta,"interest",1,r.x,r.y,r.width,r.height);}else row(meta,"interest",0);
        region("selected",world.selected_core_region_);region("applied",world.applied_core_region_);
        row(meta,"explosions",world.pending_explosions_.size());
        for(std::size_t i=0;i<world.pending_explosions_.size();++i){const auto& e=world.pending_explosions_[i];row(meta,"explosion:"+std::to_string(i),e.x,e.y,e.radius,e.collapse_strength);}
        row(meta,"scratch",world.active_chunk_scratch_.size(),world.active_chunk_scratch_.capacity(),world.active_core_scratch_.size(),world.active_core_scratch_.capacity(),bool(world.parallel_));
        if(world.parallel_)row(meta,"parallel",world.parallel_->results.size(),world.parallel_->results.capacity(),world.parallel_->physics.size(),world.parallel_->phase_job_indices.size(),world.parallel_->phase_job_indices.capacity(),bool(world.parallel_->pool));
        const auto d=mat003_world::dispatch_observations();row(meta,"dispatch",d.calls,d.dispatched_tasks,d.worker_tasks);
        row(meta,"stats",stats.tick,stats.visited_cells,stats.moved_cells,stats.active_chunks_before,stats.active_chunks_after,stats.active_blocks_after,stats.dirty_chunks,stats.scheduled_cores,stats.chunk_allocations,stats.temperature_field_allocations,stats.deferred_events);
        meta<<"phases";for(auto v:stats.phase_jobs)meta<<' '<<v;meta<<'\n';
        row(meta,"support",world.granular_support_at(20,20,false,false),world.granular_support_at(20,20,true,false));
        if(metadata_only)row(meta,"admission_temperature",world.temperature(7,7),world.temperature(20,20));
        row(meta,"clears",mat003_world::clear_count,mat003_world::clear_cells);
        row(meta,"discovery",bool(world.settled_discovery_));
        fixture::require(bool(world.transient_obstacles_),"missing transient owner");
        const auto& t=*world.transient_obstacles_;
        row(meta,"transient",1,t.region.x,t.region.y,t.region.width,t.region.height,t.body_ids.size(),t.occupied_indices.size());
        fixture::require(t.region.width==0&&t.region.height==0&&t.body_ids.empty()&&t.occupied_indices.empty(),"fixture has transient occupancy");
        for(std::size_t i=0;i<t.contacts.size();++i){row(meta,"contact:"+std::to_string(i),t.contacts[i].load(),t.impulse_x[i].load(),t.impulse_y[i].load());fixture::require(t.contacts[i]==0&&t.impulse_x[i]==0&&t.impulse_y[i]==0,"unexpected body contact");}
        row(meta,"physics",bool(world.physics_totals_));
        if(world.physics_totals_){row(meta,"ledger",world.physics_totals_->used,world.physics_totals_->overflow);fixture::require(world.physics_totals_->overflow==0,"ledger overflow");for(std::size_t i=0;i<world.physics_totals_->entries.size();++i){const auto& e=world.physics_totals_->entries[i];if(e.key)row(meta,"event:"+std::to_string(e.key),e.count);}}
        fixture::require(bool(raw)&&bool(index)&&bool(meta),"endpoint write failure");
    }
