// Included inside the source-bound S1 PrecisionProbe friend class.
    static bool neutral_admit(World& world,std::int64_t x,std::int64_t y,std::uint64_t value) {
        fixture::require(!world.tick_in_progress_ && !world.tick_failed_,"invalid admission boundary");
        auto address=world.address(x,y);auto* chunk=world.find_chunk(address.chunk);
        if(!chunk)return false; // No implicit allocation/publication on refusal.
        return chunk->cells[address.index].set_neutral_extra(value);
    }
    static void canonical_endpoint(const World& world,const TickStats& stats,const std::filesystem::path& root) {
        fixture::require(!world.tick_in_progress_,"endpoint during tick");
        fixture::require(!world.settled_discovery_ && !world.transient_obstacles_,"unexported owner: discovery/transient");
        fixture::require(!std::filesystem::exists(root),"endpoint overwrite");
        std::filesystem::create_directories(root);
        std::ofstream raw(root/"cells.bin",std::ios::binary),index(root/"chunks.txt");
        for(const auto coord:coordinates(world)) {
            const auto& chunk=*world.find_chunk(coord);
            index<<coord.x<<' '<<coord.y<<' '<<chunk.cells.size()<<' '<<bool(chunk.temperatures)<<'\n';
            for(std::size_t i=0;i<chunk.cells.size();++i) {
                auto bytes=chunk.cells[i].canonical();
                raw.write(reinterpret_cast<const char*>(bytes.data()),bytes.size());
                auto t=static_cast<std::uint16_t>(chunk.temperatures?(*chunk.temperatures)[i]:world.config_.ambient_temperature);
                raw.put(static_cast<char>(t&255));raw.put(static_cast<char>(t>>8));
            }
        }
        auto semantic=snapshot(world,stats,{{20,20}});
        std::ofstream common(root/"common.bin",std::ios::binary);
        common.write(reinterpret_cast<const char*>(semantic.bytes.data()),semantic.bytes.size());
        std::ofstream owner(root/"world.txt");
        owner<<world.tick_index_<<' '<<world.completed_tick_index_<<' '<<unsigned(world.update_epoch_)<<' '
             <<world.tick_failed_<<' '<<world.tick_in_progress_<<' '<<world.flow_mixing_enabled_<<' '
             <<world.flow_carrying_enabled_<<' '<<world.liquid_surface_adhesion_enabled_<<' '
             <<world.tick_chunk_allocations_<<' '<<world.tick_temperature_field_allocations_<<' '
             <<bool(world.settled_discovery_)<<' '<<bool(world.transient_obstacles_)<<'\n';
        fixture::require(bool(raw)&&bool(index)&&bool(common)&&bool(owner),"endpoint write failure");
    }
