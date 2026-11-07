// GEN-006 native per-chunk checkpoint: explicitly scoped static cellular domain.
// The include follows world_pressure.inc for StateWriter/StateReader and Sha256.
namespace {
constexpr std::uint32_t kGen006ChunkMagic = 0x434b3647U; // "G6KC"
constexpr std::uint32_t kGen006ChunkVersion = 1U;
constexpr std::size_t kGen006MaxBytes = 16U * 1024U * 1024U;


} // namespace

bool World::gen006_player_edit_intent_at(std::int64_t x,std::int64_t y) const noexcept {
    if(!config_.gen006_track_edit_intent)return false;
    const auto at=address(x,y);
    const auto* chunk=find_chunk(at.chunk);
    return chunk && chunk->gen006_edit_intent.size()==(chunk->cells.size()+7U)/8U &&
        (chunk->gen006_edit_intent[at.index/8U] &
         static_cast<std::uint8_t>(1U<<(at.index%8U)))!=0U;
}

ChunkCheckpointCapture World::capture_chunk_checkpoint(ChunkCoord coord) const {
    ChunkCheckpointCapture result{};
    if (tick_failed_) { result.status = ChunkCheckpointStatus::WorldFailed; return result; }
    if (tick_in_progress_) { result.status = ChunkCheckpointStatus::TickInProgress; return result; }
    const auto* chunk = find_chunk(coord);
    if (!chunk) { result.status = ChunkCheckpointStatus::NotResident; return result; }
    // Global sidecars and external-host coupling cannot be carried through
    // a one-chunk local checkpoint. Refuse before examining the payload.
    if (pressure_ || inertial_enabled_ || granular_arrival_enabled_ ||
        settled_discovery_ || physics_totals_ || config_.ballistic_water.enabled ||
        !ballistic_parcels_.empty() || !pending_explosions_.empty() ||
        transient_occupancy_capacity() != 0 || quantity_.construction) {
        result.status = ChunkCheckpointStatus::UnsupportedDomain; return result;
    }
    if (coord.x == std::numeric_limits<std::int64_t>::min() ||
        coord.x == std::numeric_limits<std::int64_t>::max() ||
        coord.y == std::numeric_limits<std::int64_t>::min() ||
        coord.y == std::numeric_limits<std::int64_t>::max()) {
        result.status = ChunkCheckpointStatus::NeighbourPinned; return result;
    }
    for (std::int64_t y=-1; y<=1; ++y)
        for (std::int64_t x=-1; x<=1; ++x)
            if ((x || y) && find_chunk({coord.x+x,coord.y+y})) {
                result.status = ChunkCheckpointStatus::NeighbourPinned; return result;
            }
    // A moving or reactive material is an unsupported *physical* domain,
    // regardless of its present scheduling activity.
    for (const auto& c:chunk->cells) {
        const auto material=c.material_value();
        if (material != Material::Empty && material != Material::Wall) {
            result.status = ChunkCheckpointStatus::UnsupportedDomain; return result;
        }
    }
    if (!config_.gen006_track_edit_intent || chunk->pristine_generated_empty ||
        chunk->gen006_edit_intent.size() != (chunk->cells.size()+7U)/8U) {
        result.status = ChunkCheckpointStatus::UnsupportedDomain; return result;
    }
    if (chunk->pressure || chunk->inertial || chunk->granular_arrivals ||
        chunk->active || chunk->changed_this_tick ||
        chunk->mutation_generation == std::numeric_limits<std::uint64_t>::max()) {
        result.status = ChunkCheckpointStatus::PendingActivity; return result;
    }
    for (const auto& block : chunk->activity_blocks) {
        if (block.active || block.changed_this_tick || block.next_interaction_tick) {
            result.status = ChunkCheckpointStatus::PendingActivity; return result;
        }
    }
    if (chunk->dirty && (chunk->dirty_min_x < 0 || chunk->dirty_min_y < 0 ||
        chunk->dirty_max_x >= config_.chunk_size || chunk->dirty_max_y >= config_.chunk_size ||
        chunk->dirty_min_x > chunk->dirty_max_x ||
        chunk->dirty_min_y > chunk->dirty_max_y)) {
        result.status = ChunkCheckpointStatus::UnsupportedDomain; return result;
    }
    StateWriter out;
    out.put(kGen006ChunkMagic);
    out.put(kGen006ChunkVersion);
    out.put(coord.x);out.put(coord.y);
    out.put(config_.chunk_size);out.put(config_.activity_block_size);
    out.put(static_cast<std::uint8_t>(config_.backend));
    out.put(config_.ambient_temperature);
    out.put(chunk->mutation_generation);
    out.put(completed_tick_index_);
    out.put(chunk->quiet_ticks);
    out.put(static_cast<std::uint8_t>(chunk->dirty));
    for (const auto field : {chunk->dirty_min_x,chunk->dirty_min_y,
                             chunk->dirty_max_x,chunk->dirty_max_y}) out.put(field);
    for (const auto word:chunk->hard_surface_dirty_tiles)out.put(word);
    out.put(static_cast<std::uint32_t>(chunk->activity_blocks.size()));
    for (const auto& block:chunk->activity_blocks) {
        out.put(block.quiet_ticks);
    }
    out.put(static_cast<std::uint32_t>(chunk->cells.size()));
    for(const auto& cell:chunk->cells)out.put(cell.bits);
    out.put(static_cast<std::uint8_t>(chunk->temperatures != nullptr));
    if (chunk->temperatures)
        for (const auto value:*chunk->temperatures)out.put(value);
    out.put(static_cast<std::uint32_t>(chunk->gen006_edit_intent.size()));
    for(const auto bit:chunk->gen006_edit_intent)out.put(bit);
    if (out.bytes.size() > kGen006MaxBytes - 32U) {
        result.status = ChunkCheckpointStatus::UnsupportedDomain;return result;
    }
    const auto digest=Sha256::of(out.bytes);
    out.bytes.insert(out.bytes.end(),digest.begin(),digest.end());
    result.status=ChunkCheckpointStatus::Captured;
    result.checkpoint.coord=coord;
    result.checkpoint.generation=chunk->mutation_generation;
    result.checkpoint.world_tick=completed_tick_index_;
    result.checkpoint.sha256=digest;
    result.checkpoint.bytes=std::move(out.bytes);
    return result;
}

ChunkCheckpointStatus World::evict_durable_checkpoint(
    const ChunkCheckpoint& staged,const ChunkDurableAck& ack) {
    if (!ack.durable || ack.coord != staged.coord ||
        ack.generation != staged.generation ||
        ack.source_tick != staged.world_tick || ack.sha256 != staged.sha256)
        return ChunkCheckpointStatus::MissingDurabilityAck;
    if (tick_failed_)return ChunkCheckpointStatus::WorldFailed;
    if (tick_in_progress_)return ChunkCheckpointStatus::TickInProgress;
    const auto it=chunks_.find(staged.coord);
    if(it==chunks_.end())return ChunkCheckpointStatus::NotResident;
    if(it->second->mutation_generation != staged.generation ||
       completed_tick_index_ != staged.world_tick)
        return ChunkCheckpointStatus::StaleGeneration;
    // A second complete capture also detects source changes which a native
    // generation counter might not otherwise cover (e.g. external metadata).
    auto current=capture_chunk_checkpoint(staged.coord);
    if (current.status != ChunkCheckpointStatus::Captured)
        return current.status;
    if (staged.bytes != current.checkpoint.bytes ||
        staged.sha256 != current.checkpoint.sha256)
        return ChunkCheckpointStatus::StaleGeneration;
    const auto& chunk=*it->second;
    // For this strict Wall/Empty domain, quantity is wholly material counts,
    // with zero Water transfer and no construction ledger.
    const auto wall_count=static_cast<std::uint64_t>(chunk.non_empty_cell_count);
    const auto index=static_cast<std::uint8_t>(Material::Wall);
    if (wall_count > quantity_.material_cells[index])
        return ChunkCheckpointStatus::UnsupportedDomain;
    // From here on: no allocation or throws. Acknowledged checkpoint exists
    // outside World before its last native copy is destroyed.
    const auto dx=static_cast<std::uint64_t>(staged.coord.x-chunk_directory_x_);
    const auto dy=static_cast<std::uint64_t>(staged.coord.y-chunk_directory_y_);
    if(dx < static_cast<std::uint64_t>(chunk_directory_width_) &&
       dy < static_cast<std::uint64_t>(chunk_directory_height_)) {
        chunk_directory_[static_cast<std::size_t>(
            dy*static_cast<std::uint64_t>(chunk_directory_width_)+dx)]=nullptr;
    }
    quantity_.material_cells[index]-=wall_count;
    chunks_.erase(it);
    ++hard_surface_revision_;
    hard_surface_full_refresh_required_=true;
    return ChunkCheckpointStatus::Evicted;
}

ChunkCheckpointStatus World::restore_chunk_checkpoint(
    ChunkCoord expected,std::span<const std::uint8_t> bytes) {
    if(tick_failed_)return ChunkCheckpointStatus::WorldFailed;
    if(tick_in_progress_)return ChunkCheckpointStatus::TickInProgress;
    if(find_chunk(expected))return ChunkCheckpointStatus::AlreadyResident;
    if(chunks_.size()>=config_.maximum_chunk_count)return ChunkCheckpointStatus::CapacityFull;
    if(bytes.size()<32U+64U || bytes.size()>kGen006MaxBytes)
        return ChunkCheckpointStatus::InvalidRecord;
    const auto body=bytes.first(bytes.size()-32U);
    const auto digest=Sha256::of(body);
    if(!std::equal(digest.begin(),digest.end(),bytes.end()-32))return ChunkCheckpointStatus::InvalidRecord;
    // Preparation is entirely private; all lengths/domains/identity checked
    // before any native map, accounting or rendering state is changed.
    try {
        StateReader in(body);
        if(in.get<std::uint32_t>()!=kGen006ChunkMagic ||
           in.get<std::uint32_t>()!=kGen006ChunkVersion)
            return ChunkCheckpointStatus::InvalidRecord;
        const ChunkCoord saved{in.get<std::int64_t>(),in.get<std::int64_t>()};
        if(saved!=expected)return ChunkCheckpointStatus::InvalidRecord;
        if(in.get<std::int32_t>()!=config_.chunk_size ||
           in.get<std::int32_t>()!=config_.activity_block_size ||
           in.get<std::uint8_t>()!=static_cast<std::uint8_t>(config_.backend) ||
           in.get<std::int16_t>()!=config_.ambient_temperature)
            return ChunkCheckpointStatus::InvalidRecord;
        const auto generation=in.get<std::uint64_t>();
        const auto saved_tick=in.get<std::uint64_t>();
        // This domain has no active scheduling deadline or dynamic cell.
        // The source tick is a provenance/fence receipt, not elapsed-time
        // catch-up: an otherwise empty fresh World may import the static
        // checkpoint after a full process restart.
        if(generation==std::numeric_limits<std::uint64_t>::max())
            return ChunkCheckpointStatus::InvalidRecord;
        (void)saved_tick;
        auto candidate=std::make_unique<Chunk>(config_.chunk_size,config_.activity_block_size);
        candidate->mutation_generation=generation;
        candidate->pristine_generated_empty=false; // historic origin is unknown
        candidate->quiet_ticks=in.get<std::uint32_t>();
        const auto dirty=in.get<std::uint8_t>();
        if(dirty>1U)return ChunkCheckpointStatus::InvalidRecord;
        candidate->dirty=dirty!=0;
        candidate->dirty_min_x=in.get<std::int32_t>();
        candidate->dirty_min_y=in.get<std::int32_t>();
        candidate->dirty_max_x=in.get<std::int32_t>();
        candidate->dirty_max_y=in.get<std::int32_t>();
        if(candidate->dirty &&
           (candidate->dirty_min_x<0 ||candidate->dirty_min_y<0 ||
            candidate->dirty_max_x>=config_.chunk_size ||
            candidate->dirty_max_y>=config_.chunk_size ||
            candidate->dirty_min_x>candidate->dirty_max_x ||
            candidate->dirty_min_y>candidate->dirty_max_y))
            return ChunkCheckpointStatus::InvalidRecord;
        for(auto& word:candidate->hard_surface_dirty_tiles)word=in.get<std::uint64_t>();
        if(in.get<std::uint32_t>()!=candidate->activity_blocks.size())
            return ChunkCheckpointStatus::InvalidRecord;
        for(auto& block:candidate->activity_blocks)block.quiet_ticks=in.get<std::uint32_t>();
        if(in.get<std::uint32_t>()!=candidate->cells.size())
            return ChunkCheckpointStatus::InvalidRecord;
        std::uint64_t wall_count=0;
        for(auto& cell:candidate->cells) {
            cell.bits=in.get<std::uint64_t>();
            if(cell.material_value()!=Material::Empty && cell.material_value()!=Material::Wall)
                return ChunkCheckpointStatus::InvalidRecord;
            if(cell.material_value()==Material::Wall)++wall_count;
        }
        candidate->non_empty_cell_count=static_cast<std::size_t>(wall_count);
        const auto temp=in.get<std::uint8_t>();
        if(temp>1U)return ChunkCheckpointStatus::InvalidRecord;
        if(temp) {
            candidate->temperatures=std::make_unique<std::vector<std::int16_t>>();
            candidate->temperatures->resize(candidate->cells.size());
            for(auto& value:*candidate->temperatures)value=in.get<std::int16_t>();
        }
        if (!config_.gen006_track_edit_intent)
            return ChunkCheckpointStatus::UnsupportedDomain;
        if(in.get<std::uint32_t>()!=(candidate->cells.size()+7U)/8U)
            return ChunkCheckpointStatus::InvalidRecord;
        candidate->gen006_edit_intent.resize((candidate->cells.size()+7U)/8U);
        for(auto& value:candidate->gen006_edit_intent)value=in.get<std::uint8_t>();
        if(!in.done())return ChunkCheckpointStatus::InvalidRecord;
        // Same no-neighbour/no-owner restrictions as preparation.
        if(expected.x==std::numeric_limits<std::int64_t>::min() ||
           expected.x==std::numeric_limits<std::int64_t>::max() ||
           expected.y==std::numeric_limits<std::int64_t>::min() ||
           expected.y==std::numeric_limits<std::int64_t>::max())
            return ChunkCheckpointStatus::NeighbourPinned;
        for(std::int64_t y=-1;y<=1;++y)
            for(std::int64_t x=-1;x<=1;++x)
                if((x||y)&&find_chunk({expected.x+x,expected.y+y}))
                    return ChunkCheckpointStatus::NeighbourPinned;
        if(pressure_ || inertial_enabled_ || granular_arrival_enabled_ ||
           settled_discovery_ || physics_totals_ || config_.ballistic_water.enabled ||
           !ballistic_parcels_.empty() || !pending_explosions_.empty() ||
           transient_occupancy_capacity()!=0 || quantity_.construction)
            return ChunkCheckpointStatus::UnsupportedDomain;
        const auto index=static_cast<std::uint8_t>(Material::Wall);
        if(wall_count>std::numeric_limits<std::uint64_t>::max()-quantity_.material_cells[index])
            return ChunkCheckpointStatus::UnsupportedDomain;
        // Allocation must finish before publishing the restored chunk.
        chunks_.reserve(chunks_.size()+1);
        auto [it,inserted]=chunks_.try_emplace(expected,std::move(candidate));
        if(!inserted)return ChunkCheckpointStatus::AlreadyResident;
        quantity_.material_cells[index]+=wall_count;
        const auto dx=static_cast<std::uint64_t>(expected.x-chunk_directory_x_);
        const auto dy=static_cast<std::uint64_t>(expected.y-chunk_directory_y_);
        if(dx < static_cast<std::uint64_t>(chunk_directory_width_) &&
           dy < static_cast<std::uint64_t>(chunk_directory_height_))
            chunk_directory_[static_cast<std::size_t>(
                dy*static_cast<std::uint64_t>(chunk_directory_width_)+dx)]=it->second.get();
        ++hard_surface_revision_;
        hard_surface_full_refresh_required_=true;
        return ChunkCheckpointStatus::Restored;
    } catch(const std::bad_alloc&) {
        return ChunkCheckpointStatus::AllocationFailed;
    } catch(const std::exception&) {
        return ChunkCheckpointStatus::InvalidRecord;
    }
}
