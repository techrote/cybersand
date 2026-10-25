// Included by world.cpp only. LCB-001 (#200) pressure_flow_v1/reference.
//
// Tick structure (serial preparation, then the unchanged phased kernels):
//   begin_tick -> explosions -> prepare_pressure_tick():
//     1. resolve_gas_topology(): exact 4-connected labelling of every Empty region
//        reachable from pressure Water or from a live compartment label; identity by
//        label overlap (never by amount); merge/split/vent/create/collapse ledgers.
//     2. compute_pressure_heads(): immutable per-cell head snapshot from vertical
//        runs, gas gauges, known-density boundaries and lid interpolation; wakes
//        sleeping blocks holding an actionable head gradient (state-only rule).
//   phased kernels -> update_water_pressure() for every Water cell.
// No step reads another job's in-progress writes: kernels read the snapshot plus
// their own rule radius, exactly like the Current kernels.

namespace {

constexpr std::int32_t kUnknownHeadBase = -(std::int32_t{1} << 30);
constexpr std::int64_t kHeadClamp = std::int64_t{1} << 28;

[[nodiscard]] constexpr std::int64_t clamp_head(std::int64_t value) noexcept {
    return std::clamp(value, -kHeadClamp, kHeadClamp);
}

[[nodiscard]] constexpr bool is_unknown_head(std::int32_t value) noexcept {
    return value != std::numeric_limits<std::int32_t>::min() && value <= kUnknownHeadBase;
}

[[nodiscard]] std::uint32_t allocate_gas_compartment_id(std::uint32_t& next_id) {
    // IDs never reuse the unresolved/vacuum/atmosphere labels. kVacuumLabel is
    // the exhausted next-ID sentinel after the last valid identity is issued.
    if (next_id == 0U || next_id >= kVacuumLabel)
        throw std::runtime_error("pressure gas identity capacity exhausted");
    return next_id++;
}

// Inverse of TransportPolicy::unpack (schema v1) for persistence.
[[nodiscard]] std::vector<std::int32_t> pack_transport(const TransportPolicy& policy) {
    std::vector<std::int32_t> words;
    words.reserve(TransportPolicy::packed_size);
    words.push_back(TransportPolicy::version);
    for (const auto n : policy.horizontal) words.push_back(n);
    for (const auto n : policy.cadence) words.push_back(n);
    for (const auto& pair : policy.pairs) {
        words.push_back(pair.mixing);
        words.push_back(pair.carrying);
        words.push_back(pair.pickup);
        words.push_back(pair.packing);
        words.push_back(pair.erosion);
        words.push_back(pair.permeability);
    }
    return words;
}

}  // namespace

bool World::pressure_flow_enabled() const noexcept { return pressure_ != nullptr; }

PressureFlowParameters World::pressure_flow_parameters() const noexcept {
    return pressure_ == nullptr ? PressureFlowParameters{} : pressure_->parameters;
}

PressureCellState World::pressure_cell(std::int64_t x, std::int64_t y) const noexcept {
    PressureCellState out;
    if (pressure_ == nullptr) return out;
    out.available = true;
    const auto target = address(x, y);
    const auto* chunk = find_chunk(target.chunk);
    if (chunk == nullptr || chunk->pressure == nullptr) return out;
    const auto& state = chunk->pressure->cells[target.index];
    out.overfill = state.overfill;
    out.flow = state.flow;
    out.gas = state.gas;
    return out;
}

PressureHeadSnapshot World::prepared_pressure_head(std::int64_t x, std::int64_t y) const noexcept {
    if (pressure_ == nullptr) return {};
    const auto target = address(x, y);
    const auto* chunk = find_chunk(target.chunk);
    if (chunk == nullptr || chunk->pressure == nullptr)
        return {PressureHeadStatus::NonResident, 0};
    const auto head = chunk->pressure->head[target.index];
    if (head == PressureChunk::kNoHead) return {PressureHeadStatus::NoHead, 0};
    if (is_unknown_head(head)) return {PressureHeadStatus::Unresolved, head};
    return {PressureHeadStatus::Prepared, head};
}

std::size_t World::copy_pressure_head_chunk_coordinates(std::span<ChunkCoord> output) const noexcept {
    if (pressure_ == nullptr) return 0;
    const auto required = chunks_.size();
    if (output.size() < required) return required;
    std::size_t index = 0;
    for (const auto& [coordinate, chunk] : chunks_) {
        (void)chunk;
        output[index++] = coordinate;
    }
    return required;
}

std::vector<GasCompartmentSnapshot> World::gas_compartments() const {
    std::vector<GasCompartmentSnapshot> out;
    if (pressure_ == nullptr) return out;
    out.reserve(pressure_->compartments.size());
    for (const auto& item : pressure_->compartments) out.push_back(PressureState::snapshot(item));
    return out;
}

std::vector<GasHistoryRecord> World::gas_history() const {
    std::vector<GasHistoryRecord> out;
    if (pressure_ == nullptr) return out;
    const auto& history = pressure_->history;
    const auto count = history.size();
    out.reserve(count);
    // Oldest first: when the ring is full, history_next is the oldest slot.
    const auto start = count < PressureFlowParameters::kHistoryCapacity ? 0U : pressure_->history_next;
    for (std::size_t i = 0; i < count; ++i) out.push_back(history[(start + i) % count]);
    return out;
}

GasLedger World::gas_ledger() const noexcept { return pressure_ == nullptr ? GasLedger{} : pressure_->gas; }
std::uint64_t World::gas_topology_revision() const noexcept {
    return pressure_ == nullptr ? 0U : pressure_->topology_revision;
}
std::uint32_t World::gas_next_id() const noexcept { return pressure_ == nullptr ? 0U : pressure_->next_id; }
PressureFlowLedger World::pressure_flow_ledger() const noexcept {
    return pressure_ == nullptr ? PressureFlowLedger{} : pressure_->flow;
}
PressureFlowDiagnostics World::pressure_flow_diagnostics() const noexcept {
    return pressure_ == nullptr ? PressureFlowDiagnostics{} : pressure_->diagnostics;
}

std::uint64_t World::water_quantity(RectI64 region) const {
    if (region.width < 0 || region.height < 0) throw std::invalid_argument("region dimensions must not be negative");
    if (region.width == 0 || region.height == 0) return 0;
    const auto maximum = std::numeric_limits<std::int64_t>::max();
    if (region.x > maximum - (region.width - 1) ||
        region.y > maximum - (region.height - 1))
        throw std::overflow_error("quantity region exceeds coordinate range");
    std::uint64_t total = 0;
    // Offsets avoid forming an exclusive endpoint or incrementing a coordinate
    // past INT64_MAX when the final included cell is exactly at that boundary.
    for (std::int64_t dy = 0; dy < region.height; ++dy) {
        const auto y = region.y + dy;
        for (std::int64_t dx = 0; dx < region.width; ++dx) {
            const auto x = region.x + dx;
            const auto target = address(x, y);
            const auto* chunk = find_chunk(target.chunk);
            if (chunk == nullptr) continue;
            const auto& cell = chunk->cells[target.index];
            if (cell.material_value() != Material::Water) continue;
            total += cell.state_a_value();
            if (chunk->pressure != nullptr) total += chunk->pressure->cells[target.index].overfill;
        }
    }
    return total;
}

void World::reset_pressure_cell(Chunk& chunk, std::size_t index, Material before, Material after,
                                bool external, JobEffects* effects) noexcept {
    auto& state = chunk.pressure->cells[index];
    // Erasing an Empty cell leaves its gas identity untouched.
    if (before == Material::Empty && after == Material::Empty) return;
    if (state.overfill != 0U) {
        if (effects != nullptr) {
            effects->pf_overfill_converted += state.overfill;
        } else if (external) {
            pressure_->flow.overfill_external += state.overfill;
        } else {
            pressure_->flow.overfill_converted += state.overfill;
        }
    }
    state = {};
    if (after == Material::Empty && !external) state.gas = kVacuumLabel;
}

void World::merge_pressure_effects(const JobEffects& effects) noexcept {
    auto& flow = pressure_->flow;
    flow.overfill_converted += effects.pf_overfill_converted;
    flow.flow_remainder += effects.pf_flow_remainder;
    flow.contact_loss += effects.pf_contact_loss;
    if (effects.pressure_work != nullptr) {
        for (const auto member : {&PressureOptimizationCounters::water_material_calls,
                &PressureOptimizationCounters::water_motion_calls, &PressureOptimizationCounters::other_liquid_calls,
                &PressureOptimizationCounters::certificate_attempts, &PressureOptimizationCounters::certificate_reuses,
                &PressureOptimizationCounters::certificate_saved_calls, &PressureOptimizationCounters::certificate_declines})
            pressure_->optimization.*member += effects.pressure_work->*member;
    }
    flow.relief_cells += effects.pf_relief_cells;
}

void World::wake_activity_block(ChunkCoord coord, Chunk& chunk, std::size_t block_index) {
    auto& block = chunk.activity_blocks[block_index];
    if (block.active) return;
    record_physics(PhysicsEvent::BlockWake, Material::Empty, Material::Empty, 0, 0, nullptr);
    block.active = true;
    block.quiet_ticks = 0;
    chunk.active = true;
    ++pressure_->diagnostics.woken_blocks;
    if (settled_discovery_ != nullptr) witness_discovery_activity(coord, block_index);
}

void World::prepare_pressure_tick() {
    using Clock = std::chrono::steady_clock;
    const auto start = Clock::now();
    auto& state = *pressure_;
    state.diagnostics = {};
    auto* cache = state.cache.get();
    const auto gas_start = Clock::now();
    bool gas_ran = false;
    if (state.parameters.gas_enabled) {
        if (cache == nullptr || !cache->complete || cache->gas_dirty) {
            resolve_gas_topology();
            ++state.optimization.gas_reference_passes;
            gas_ran = true;
        } else ++state.optimization.gas_reuses;
    }
    const auto head_start = Clock::now();
    if (cache != nullptr) {
        if (cache->membership_dirty) rebuild_pressure_index();
        cache->gas_dirty = state.parameters.gas_enabled && !state.gas_fixed_point;
        cache->use_heads = false;
        if (cache->complete) {
            if (gas_ran) {
                // The motion stencil samples gas gauges directly at x+-2.
                // A remote compartment change can alter that gradient without
                // changing any lidded Water head. Revoke those assumptions
                // before kernels run, including paused/outside-interest gas.
                if (cache->dormant) cache->certificate_contents_cold=true;
                for (std::size_t i = 0; i < cache->columns.size(); ++i)
                    cache->mark(true, i, 0, config_.chunk_size - 1);
            }
            std::uint64_t estimated = 0;
            for (const auto group : cache->dirty_columns) {
                const auto& column = cache->columns[group];
                std::uint64_t count = 0;
                for (const auto word : column.dirty) count += static_cast<std::uint64_t>(std::popcount(word));
                estimated += count * (column.last - column.first) * static_cast<std::uint64_t>(config_.chunk_size);
            }
            // A changed base column may alter a complete row interpolation.
            // Reserve the full resident row closure before publishing any head.
            if (!cache->dirty_columns.empty() || !cache->dirty_rows.empty())
                estimated += static_cast<std::uint64_t>(chunks_.size()) *
                    static_cast<std::uint64_t>(config_.chunk_size) * static_cast<std::uint64_t>(config_.chunk_size);
            if (estimated <= cache->config.head_repair_cell_budget) cache->use_heads = true;
            else cache->status = PressureOptimizationStatus::ReferenceBudgetFallback;
        }
        if (!cache->use_heads) {
            ++state.optimization.reference_fallbacks;
            state.optimization.fallback_resident_cells += static_cast<std::uint64_t>(chunks_.size()) *
                static_cast<std::uint64_t>(config_.chunk_size) * static_cast<std::uint64_t>(config_.chunk_size);
            // The reference operator replaces the entire snapshot this tick.
            // Any later cache reuse starts cold; no partially repaired answer.
            const auto status = cache->status;
            cache->cold(); cache->status = status;
        }
    }
    compute_pressure_heads();
    prepare_pressure_certificates();
    if (cache != nullptr && cache->use_heads) cache->status = PressureOptimizationStatus::Ready;
    const auto end = Clock::now();
    const auto nanos = [](auto duration) {
        return static_cast<std::uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(duration).count());
    };
    state.optimization.gas_nanoseconds += nanos(head_start - gas_start);
    state.optimization.head_nanoseconds += nanos(end - head_start);
    state.optimization.preparation_nanoseconds += nanos(end - start);
}

void World::resolve_gas_topology(bool allow_cache) {
    using State = PressureState;
    auto& state = *pressure_;
    state.gas_fixed_point = false;
    constexpr auto kNone = State::kNone;
    const auto limit = static_cast<std::uint64_t>(PressureFlowParameters::kCompartmentVolumeLimit);
    const auto size = config_.chunk_size;
    const auto area = static_cast<std::uint64_t>(size) * static_cast<std::uint64_t>(size);

    // The non-resident BFS node shortcut is valid only for uniformly Empty
    // chunks. A transient body can occupy otherwise unallocated cells, so make
    // its chunks resident before topology reads them. This is serial tick
    // preparation; ensure_chunk retains the explicit capacity/quarantine path.
    const auto& masks = *transient_obstacles_;
    const auto mask_width = static_cast<std::size_t>(masks.region.width);
    auto& coordinates = state.sorted_coordinates;
    coordinates.clear();
    for (const auto index : masks.occupied_indices) {
        const auto x = masks.region.x + static_cast<std::int64_t>(index % mask_width);
        const auto y = masks.region.y + static_cast<std::int64_t>(index / mask_width);
        const auto coord = address(x, y).chunk;
        if (find_chunk(coord) == nullptr) {
            (void)ensure_chunk(coord);
            coordinates.push_back(coord);
            ++state.diagnostics.chunk_allocations;
        }
    }
    if (!coordinates.empty()) {
        std::sort(coordinates.begin(), coordinates.end());
        // Installing a mask before its chunk exists cannot wake that chunk.
        // Replay those missed wakes once, so sparse and resident representations
        // have the same activity state as well as the same gas topology.
        for (const auto index : masks.occupied_indices) {
            const auto x = masks.region.x + static_cast<std::int64_t>(index % mask_width);
            const auto y = masks.region.y + static_cast<std::int64_t>(index / mask_width);
            const auto at = address(x, y);
            if (std::binary_search(coordinates.begin(), coordinates.end(), at.chunk)) {
                auto& chunk = *find_chunk(at.chunk);
                const auto block = static_cast<std::size_t>(at.local_y / config_.activity_block_size) *
                                       static_cast<std::size_t>(chunk.activity_blocks_per_axis) +
                                   static_cast<std::size_t>(at.local_x / config_.activity_block_size);
                // begin_tick already retired pre-tick changed_this_tick flags;
                // replay activity without claiming a material mutation now.
                wake_activity_block(at.chunk, chunk, block);
                wake_cell_neighborhood(x, y);
            }
        }
    }

    if (allow_cache && state.cache != nullptr) {
        // A fixed-point pass may be the last gas pass before quiet reuse. Build
        // its fitting resident index now so that pass can certify discovery;
        // otherwise the later head-index rebuild would leave no member proof.
        if (state.cache->membership_dirty && chunks_.size() <= state.cache->capacity) rebuild_pressure_index();
        prepare_pressure_gas_cache();
    }
    auto* gas_cache = state.cache.get();
    const auto discovery_diagnostics = state.diagnostics;
    if (++state.pass_stamp == 0U) {
        for (auto& [coord, chunk] : chunks_) {
            (void)coord;
            if (chunk->pressure != nullptr) {
                std::fill(chunk->pressure->visit.begin(), chunk->pressure->visit.end(), 0U);
                state.optimization.gas_stamp_clear_cells += chunk->pressure->visit.size();
            }
        }
        state.pass_stamp = 1;
    }
    const auto stamp = static_cast<std::uint32_t>(state.pass_stamp) << 16U;
    state.regions.clear();
    state.overlaps.clear();
    state.nodes.clear();

    coordinates.clear();
    for (const auto& [coord, chunk] : chunks_) {
        (void)chunk;
        coordinates.push_back(coord);
    }
    std::sort(coordinates.begin(), coordinates.end(), [](const ChunkCoord& a, const ChunkCoord& b) {
        return a.y != b.y ? a.y < b.y : a.x < b.x;
    });

    const auto compartment_index = [&state](std::uint32_t id) -> std::uint32_t {
        const auto found = std::lower_bound(
            state.compartments.begin(), state.compartments.end(), id,
            [](const State::Compartment& c, std::uint32_t value) { return c.id < value; });
        if (found == state.compartments.end() || found->id != id)
            throw std::logic_error("pressure gas label refers to a retired compartment");
        return static_cast<std::uint32_t>(found - state.compartments.begin());
    };

    // Breadth-first labelling of one Empty region. A non-resident chunk is
    // uniformly Empty, so it is one node whatever its size and allocation never
    // changes the topology.
    std::size_t head = 0;
    bool stop = false;
    bool retry_requested = false;
    std::uint32_t current = 0;

    const auto touch = [&](std::uint32_t other) {
        if (!state.regions[other].atmosphere)
            throw std::logic_error("pressure gas regions are not maximal components");
        state.regions[current].atmosphere = true;
        stop = true;
    };

    // Encodes a chunk node in the queue as a cell whose x is the node index and y
    // the sentinel minimum (never a resident cell coordinate the BFS would push).
    constexpr std::int64_t kNodeMarker = std::numeric_limits<std::int64_t>::min();

    const auto visit = [&](std::int64_t x, std::int64_t y) {
        ++state.optimization.gas_bfs_probes;
        if (stop) return;
        if (state.queue.size() == state.queue.capacity())
            throw std::logic_error("pressure gas queue exceeded its reserved bound");
        if (transient_obstacle_at(x, y) != 0U) return;
        auto& region = state.regions[current];
        const auto target = address(x, y);
        auto* chunk = find_chunk(target.chunk);
        if (chunk == nullptr) {
            for (const auto& node : state.nodes) {
                if (node.coord != target.chunk) continue;
                if (node.region != current) touch(node.region);
                return;
            }
            if (state.nodes.size() >= State::kChunkNodeCapacity)
                throw std::runtime_error("pressure gas chunk-node capacity exhausted");
            ++state.optimization.gas_bfs_nodes;
            state.nodes.push_back({target.chunk, current, region.first_node});
            region.first_node = static_cast<std::uint32_t>(state.nodes.size() - 1U);
            region.volume += area;
            region.fresh_cells += area;
            const auto origin_x = target.chunk.x * size;
            const auto origin_y = target.chunk.y * size;
            if (origin_y < region.lowest_y || (origin_y == region.lowest_y && origin_x < region.lowest_x)) {
                region.lowest_x = origin_x;
                region.lowest_y = origin_y;
            }
            if (region.volume > limit) {
                region.atmosphere = true;
                stop = true;
                return;
            }
            state.queue.push_back({static_cast<std::int64_t>(state.nodes.size() - 1U), kNodeMarker});
            return;
        }
        if (chunk->cells[target.index].material_value() != Material::Empty) return;
        if (allow_cache && gas_cache != nullptr && gas_cache->gas_ready) {
            const auto* certified = gas_cache->gas_component(chunk->pressure->cells[target.index].gas);
            if (certified != nullptr && certified->valid) { retry_requested = true; stop = true; return; }
        }
        auto& mark = chunk->pressure->visit[target.index];
        if ((mark & 0xFFFF0000U) == stamp) {
            const auto other = mark & 0xFFFFU;
            if (other != current) touch(other);
            return;
        }
        mark = stamp | current;
        ++region.volume;
        ++state.diagnostics.gas_visited;
        ++state.optimization.gas_bfs_cells;
        if (y < region.lowest_y || (y == region.lowest_y && x < region.lowest_x)) {
            region.lowest_x = x;
            region.lowest_y = y;
        }
        const auto label = chunk->pressure->cells[target.index].gas;
        if (label == kAtmosphereLabel) {
            ++region.atmosphere_cells;
        } else if (label == 0U) {
            ++region.fresh_cells;
        } else if (label != kVacuumLabel) {
            const auto index = compartment_index(label);
            auto overlap = region.first_overlap;
            while (overlap != kNone && state.overlaps[overlap].compartment != index)
                overlap = state.overlaps[overlap].next;
            if (overlap == kNone) {
                if (state.overlaps.size() >= State::kOverlapCapacity)
                    throw std::runtime_error("pressure gas overlap capacity exhausted");
                state.overlaps.push_back({index, 0U, region.first_overlap});
                overlap = static_cast<std::uint32_t>(state.overlaps.size() - 1U);
                region.first_overlap = overlap;
            }
            ++state.overlaps[overlap].count;
        }
        if (region.volume > limit) {
            region.atmosphere = true;
            stop = true;
            return;
        }
        state.queue.push_back({x, y});
    };

    const auto seed_needed = [&](std::int64_t x, std::int64_t y) {
        ++state.optimization.gas_seed_probes;
        if (transient_obstacle_at(x, y) != 0U) return false;
        const auto target = address(x, y);
        const auto* chunk = find_chunk(target.chunk);
        if (chunk == nullptr) {
            return std::none_of(state.nodes.begin(), state.nodes.end(),
                                [&](const State::ChunkNode& node) { return node.coord == target.chunk; });
        }
        return chunk->cells[target.index].material_value() == Material::Empty &&
               (chunk->pressure->visit[target.index] & 0xFFFF0000U) != stamp;
    };

    const auto fill = [&](std::int64_t x, std::int64_t y) {
        if (state.regions.size() >= State::kRegionCapacity)
            throw std::runtime_error("pressure gas region capacity exhausted");
        state.regions.push_back({});
        current = static_cast<std::uint32_t>(state.regions.size() - 1U);
        state.regions[current].lowest_x = x;
        state.regions[current].lowest_y = y;
        if (allow_cache) {
            const auto reused = replay_pressure_gas_region(x, y, current, stamp, retry_requested);
            if (reused || retry_requested) return;
        }
        state.queue.clear();
        head = 0;
        stop = false;
        visit(x, y);
        while (!stop && head < state.queue.size()) {
            const auto entry = state.queue[head++];
            if (entry.y == kNodeMarker) {
                const auto& node = state.nodes[static_cast<std::size_t>(entry.x)];
                const auto origin_x = node.coord.x * size;
                const auto origin_y = node.coord.y * size;
                for (std::int32_t i = 0; i < size && !stop; ++i) {
                    visit(origin_x + i, origin_y - 1);
                    visit(origin_x - 1, origin_y + i);
                    visit(origin_x + size, origin_y + i);
                    visit(origin_x + i, origin_y + size);
                }
                continue;
            }
            visit(entry.x, entry.y - 1);
            visit(entry.x - 1, entry.y);
            visit(entry.x + 1, entry.y);
            visit(entry.x, entry.y + 1);
        }
        if (state.regions[current].atmosphere) ++state.diagnostics.atmosphere_regions;
    };

    // Seeds in a fixed order: Empty cells beside unmasked Water, and Empty cells
    // still carrying a live compartment label (so no compartment is ever skipped,
    // including one held entirely by Empty or unallocated cells).
    for (const auto coord : coordinates) {
        if (retry_requested) break;
        auto* chunk = find_chunk(coord);
        const auto origin_x = coord.x * size;
        const auto origin_y = coord.y * size;
        for (std::int32_t local_y = 0; local_y < size && !retry_requested; ++local_y) {
            for (std::int32_t local_x = 0; local_x < size && !retry_requested; ++local_x) {
                const auto index = static_cast<std::size_t>(local_y) * static_cast<std::size_t>(size) +
                                   static_cast<std::size_t>(local_x);
                ++state.optimization.gas_seed_cells;
                const auto material = chunk->cells[index].material_value();
                const auto x = origin_x + local_x;
                const auto y = origin_y + local_y;
                if (material == Material::Water) {
                    if (transient_obstacle_at(x, y) != 0U) continue;
                    const std::array<std::pair<std::int64_t, std::int64_t>, 4> around{{
                        {x, y - 1}, {x - 1, y}, {x + 1, y}, {x, y + 1}}};
                    for (const auto& [nx, ny] : around) {
                        if (seed_needed(nx, ny)) fill(nx, ny);
                        if (retry_requested) break;
                    }
                } else if (material == Material::Empty) {
                    const auto label = chunk->pressure->cells[index].gas;
                    if (label != 0U && label != kAtmosphereLabel && label != kVacuumLabel && seed_needed(x, y))
                        fill(x, y);
                }
            }
        }
    }
    if (retry_requested) {
        // No compartment/label/history reducer work has started. Discard only
        // derived discovery and run exactly one complete uncached operator.
        if (!allow_cache) throw std::logic_error("uncached gas discovery requested cache restart");
        ++state.optimization.gas_restart_fallbacks;
        if (gas_cache != nullptr) gas_cache->gas_ready = false;
        state.diagnostics = discovery_diagnostics;
        resolve_gas_topology(false);
        return;
    }
    state.diagnostics.gas_regions = state.regions.size();

    // Identity: union compartments with the regions they overlap.
    const auto compartment_count = static_cast<std::uint32_t>(state.compartments.size());
    const auto region_count = static_cast<std::uint32_t>(state.regions.size());
    state.optimization.gas_identity_nodes += static_cast<std::uint64_t>(compartment_count) + region_count;
    state.uf_parent.resize(compartment_count + region_count);
    for (std::uint32_t i = 0; i < compartment_count + region_count; ++i) state.uf_parent[i] = i;
    for (std::uint32_t r = 0; r < region_count; ++r) {
        for (auto o = state.regions[r].first_overlap; o != kNone; o = state.overlaps[o].next)
            state.uf_union(state.overlaps[o].compartment, compartment_count + r);
    }
    auto& order = state.component_order;
    order.resize(compartment_count + region_count);
    for (std::uint32_t i = 0; i < compartment_count + region_count; ++i) order[i] = i;
    std::sort(order.begin(), order.end(), [&state](std::uint32_t a, std::uint32_t b) {
        const auto ra = state.uf_find(a);
        const auto rb = state.uf_find(b);
        return ra != rb ? ra < rb : a < b;
    });

    const auto tick = tick_index_;
    const auto pressure_rows = static_cast<std::int64_t>(state.parameters.atmospheric_head_rows);
    const auto maximum = static_cast<std::int64_t>(config_.water_experiment_policy.maximum());
    const auto gauge_for = [&](std::uint64_t amount, std::uint64_t volume) -> std::int64_t {
        if (volume == 0U) return 0;
        const auto difference = static_cast<std::int64_t>(amount) - static_cast<std::int64_t>(volume);
        return std::clamp(pressure_rows * maximum * difference / static_cast<std::int64_t>(volume),
                          -PressureFlowParameters::kHeadLimit, PressureFlowParameters::kHeadLimit);
    };
    const auto check_amount = [](std::uint64_t amount) {
        if (amount > (std::uint64_t{1} << 32U))
            throw std::runtime_error("pressure gas amount exceeds the declared bound");
    };

    auto& next = state.next_compartments;
    next.clear();
    bool topology_changed = false;
    const auto new_revision = state.topology_revision + 1U;
    std::array<std::uint32_t, PressureFlowParameters::kMaximumParents> ids{};

    auto& members_c = state.member_compartments;
    auto& members_r = state.member_regions;
    std::size_t position = 0;
    while (position < order.size()) {
        const auto root = state.uf_find(order[position]);
        members_c.clear();
        members_r.clear();
        while (position < order.size() && state.uf_find(order[position]) == root) {
            const auto node = order[position++];
            if (node < compartment_count) members_c.push_back(node);
            else members_r.push_back(node - compartment_count);
        }
        if (members_r.empty()) {
            // Every cell of these compartments was filled: book to the collapse sink.
            for (const auto index : members_c) {
                const auto& old = state.compartments[index];
                state.gas.collapsed += old.amount;
                ++state.gas.collapses;
                state.record_history(old, GasRetireReason::Collapsed, {}, tick);
            }
            topology_changed = true;
            continue;
        }
        bool any_atmosphere = false;
        for (const auto r : members_r) any_atmosphere = any_atmosphere || state.regions[r].atmosphere;
        const auto create = [&](std::uint32_t r) {
            if (next.size() >= PressureFlowParameters::kCompartmentCapacity)
                throw std::runtime_error("pressure gas compartment capacity exhausted");
            auto& region = state.regions[r];
            State::Compartment made;
            made.id = allocate_gas_compartment_id(state.next_id);
            // Newly sealed gas is atmospheric; kernel-vacated cells are vacuum.
            made.amount = region.fresh_cells + region.atmosphere_cells;
            made.volume = region.volume;
            made.anchor_x = region.lowest_x;
            made.anchor_y = region.lowest_y;
            made.created_tick = tick;
            made.revision = new_revision;
            made.gauge = gauge_for(made.amount, made.volume);
            check_amount(made.amount);
            state.gas.created += made.amount;
            ++state.gas.creations;
            region.label = made.id;
            next.push_back(made);
            topology_changed = true;
        };
        if (any_atmosphere) {
            for (const auto index : members_c) {
                const auto& old = state.compartments[index];
                state.gas.vented += old.amount;
                ++state.gas.vents;
                state.record_history(old, GasRetireReason::Vented, {}, tick);
                topology_changed = true;
            }
            for (const auto r : members_r) {
                if (state.regions[r].atmosphere) state.regions[r].label = kAtmosphereLabel;
                else create(r);
            }
            continue;
        }
        if (members_c.empty()) {
            // A void opened by kernels (vacuum cells only) carries no gas: it
            // stays unlabelled vacuum rather than churning compartment ids.
            const auto& region = state.regions[members_r.front()];
            if (region.fresh_cells + region.atmosphere_cells == 0U) {
                state.regions[members_r.front()].label = kVacuumLabel;
                continue;
            }
            create(members_r.front());
            continue;
        }
        std::uint64_t absorbed = 0;
        for (const auto r : members_r) absorbed += state.regions[r].atmosphere_cells;
        std::uint64_t total = absorbed;
        std::uint32_t generation = 0;
        for (const auto index : members_c) {
            total += state.compartments[index].amount;
            generation = std::max(generation, state.compartments[index].generation);
        }
        check_amount(total);
        state.gas.absorbed += absorbed;
        if (members_r.size() == 1U) {
            auto& region = state.regions[members_r.front()];
            auto survivor = state.compartments[members_c.front()];
            const auto before = survivor;
            if (members_c.size() > 1U) {
                survivor.generation = generation + 1U;
                survivor.parent_count = static_cast<std::uint8_t>(
                    std::min(members_c.size(), survivor.parents.size()));
                survivor.parents = {};
                for (std::size_t i = 0; i < survivor.parent_count; ++i)
                    survivor.parents[i] = state.compartments[members_c[i]].id;
                for (std::size_t i = 1; i < members_c.size(); ++i) {
                    const std::array<std::uint32_t, 1> successor{survivor.id};
                    state.record_history(state.compartments[members_c[i]], GasRetireReason::Merged,
                                         successor, tick);
                }
                ++state.gas.merges;
            }
            survivor.amount = total;
            survivor.volume = region.volume;
            survivor.anchor_x = region.lowest_x;
            survivor.anchor_y = region.lowest_y;
            survivor.gauge = gauge_for(survivor.amount, survivor.volume);
            if (members_c.size() > 1U || survivor.amount != before.amount ||
                survivor.volume != before.volume || survivor.anchor_x != before.anchor_x ||
                survivor.anchor_y != before.anchor_y) {
                survivor.revision = new_revision;
                topology_changed = true;
            }
            region.label = survivor.id;
            next.push_back(survivor);
            continue;
        }
        // Split (possibly after a merge): volume-proportional floor shares; the
        // integer remainder goes to the region holding the lowest (y, x) cell.
        std::sort(members_r.begin(), members_r.end(), [&state](std::uint32_t a, std::uint32_t b) {
            const auto& ra = state.regions[a];
            const auto& rb = state.regions[b];
            return ra.lowest_y != rb.lowest_y ? ra.lowest_y < rb.lowest_y : ra.lowest_x < rb.lowest_x;
        });
        std::uint64_t volume = 0;
        for (const auto r : members_r) volume += state.regions[r].volume;
        std::uint64_t assigned = 0;
        const auto first_new = next.size();
        std::uint8_t parent_count = static_cast<std::uint8_t>(std::min(members_c.size(), ids.size()));
        for (std::size_t i = 0; i < parent_count; ++i) ids[i] = state.compartments[members_c[i]].id;
        for (const auto r : members_r) {
            if (next.size() >= PressureFlowParameters::kCompartmentCapacity)
                throw std::runtime_error("pressure gas compartment capacity exhausted");
            auto& region = state.regions[r];
            State::Compartment made;
            made.id = allocate_gas_compartment_id(state.next_id);
            made.generation = generation + 1U;
            made.parents = ids;
            made.parent_count = parent_count;
            made.amount = total * region.volume / volume;
            assigned += made.amount;
            made.volume = region.volume;
            made.anchor_x = region.lowest_x;
            made.anchor_y = region.lowest_y;
            made.created_tick = tick;
            made.revision = new_revision;
            region.label = made.id;
            next.push_back(made);
        }
        next[first_new].amount += total - assigned;
        std::array<std::uint32_t, PressureFlowParameters::kMaximumParents> successors{};
        const auto successor_count = std::min(members_r.size(), successors.size());
        for (std::size_t i = 0; i < successor_count; ++i) successors[i] = next[first_new + i].id;
        for (std::size_t i = first_new; i < next.size(); ++i) next[i].gauge = gauge_for(next[i].amount, next[i].volume);
        for (const auto index : members_c)
            state.record_history(state.compartments[index], GasRetireReason::Split,
                                 std::span<const std::uint32_t>(successors.data(), successor_count), tick);
        ++state.gas.splits;
        topology_changed = true;
    }
    std::sort(next.begin(), next.end(), [](const State::Compartment& a, const State::Compartment& b) {
        return a.id < b.id;
    });
    state.compartments.swap(next);
    if (topology_changed) state.topology_revision = new_revision;
    state.gas.amount_live = 0;
    for (const auto& item : state.compartments) state.gas.amount_live += item.amount;

    // A sealed region that includes an unallocated chunk makes it resident, so
    // every compartment cell can carry its label. Its existence is unchanged.
    for (const auto& node : state.nodes) {
        const auto label = state.regions[node.region].label;
        if (label == kAtmosphereLabel || label == 0U) continue;
        auto& chunk = ensure_chunk(node.coord);
        // An unallocated chunk is unresolved Empty: it was counted as fresh volume.
        ++state.diagnostics.chunk_allocations;
        for (auto& cell : chunk.pressure->cells) { cell.gas = label; ++state.optimization.gas_relabel_cells; }
    }
    bool labels_changed = false;
    for (const auto coord : coordinates) {
        auto* chunk = find_chunk(coord);
        auto& visits = chunk->pressure->visit;
        auto& cells = chunk->pressure->cells;
        for (std::size_t index = 0; index < cells.size(); ++index) {
            ++state.optimization.gas_relabel_cells;
            const auto mark = visits[index];
            if ((mark & 0xFFFF0000U) != stamp) {
                // Masked Empty cells do not contribute volume or overlap, but
                // can retain an old label while its compartment is retired by
                // this pass. The reducer has already assigned all of that gas
                // to successors or a vent/collapse sink. Retire only dangling
                // labels to vacuum: unresolved would create atmospheric gas,
                // and remapping to a successor would invent overlap identity.
                // Still-live labels retain their continuity under the mask.
                const auto label = cells[index].gas;
                if (label != 0U && label != kAtmosphereLabel && label != kVacuumLabel &&
                    state.find(label) == nullptr) {
                    cells[index].gas = kVacuumLabel;
                    labels_changed = true;
                }
                continue;
            }
            const auto label = state.regions[mark & 0xFFFFU].label;
            labels_changed = labels_changed || cells[index].gas != label;
            cells[index].gas = label;
        }
    }
    // Bounded atmosphere exploration can still extend its authoritative label
    // prefix after a topology edit. Unchanged Water/amount is insufficient for
    // reuse: require a complete reference pass that is a fixed point of the
    // label/table operator, including its resident-allocation footprint.
    state.gas_fixed_point = !topology_changed && !labels_changed && state.diagnostics.chunk_allocations == 0U;
    rebuild_pressure_gas_cache(stamp);
}

void World::compute_pressure_heads() {
    auto& state = *pressure_;
    const auto size = config_.chunk_size;
    const auto maximum = static_cast<std::int64_t>(config_.water_experiment_policy.maximum());
    constexpr auto kNoHead = PressureChunk::kNoHead;

    auto* cache = state.cache.get();
    const bool cached = cache != nullptr && cache->use_heads;
    auto& coordinates = cached ? cache->column_order : state.sorted_coordinates;
    if (!cached) {
        coordinates.clear();
        for (const auto& [coord, chunk] : chunks_) {
            (void)chunk;
            coordinates.push_back(coord);
        }
        std::sort(coordinates.begin(), coordinates.end(), [](const ChunkCoord& a, const ChunkCoord& b) {
            return a.x != b.x ? a.x < b.x : a.y < b.y;
        });
    }
    const auto put_base = [&](Chunk& chunk, std::size_t index, std::int32_t value) {
        ++state.optimization.base_cells_written;
        if (!cached) { chunk.pressure->head[index] = value; return; }
        auto& old = chunk.pressure->base_head[index];
        if (old != value) {
            old = value;
            const auto row = static_cast<std::int32_t>(index / static_cast<std::size_t>(size));
            cache->mark(false, chunk.pressure->row_group, row, row);
        }
    };
    const auto put_final = [&](Chunk& chunk, std::size_t index, std::int32_t value) {
        ++state.optimization.final_cells_written;
        auto& old = chunk.pressure->head[index];
        if (cached && old != value) {
            const auto local_x = static_cast<std::int32_t>(index % static_cast<std::size_t>(size));
            const auto local_y = static_cast<std::int32_t>(index / static_cast<std::size_t>(size));
            invalidate_pressure_certificates(chunk.pressure->coordinate, local_x, local_y, local_x, local_y);
        }
        old = value;
    };

    const auto cell_quantity = [](const Chunk& chunk, std::size_t index) -> std::int64_t {
        return static_cast<std::int64_t>(chunk.cells[index].state_a_value()) +
               static_cast<std::int64_t>(chunk.pressure->cells[index].overfill);
    };
    // The pressure above a run whose top cell is (x, y): gas gauge for Empty,
    // accumulated known-density liquid weight, or nullopt for a lid.
    const auto top_pressure = [&](std::int64_t x, std::int64_t y) -> std::optional<std::int64_t> {
        std::int64_t weight = 0;
        for (std::int64_t cy = y - 1;; --cy) {
            if (transient_obstacle_at(x, cy) != 0U) return std::nullopt;
            const auto target = address(x, cy);
            const auto* chunk = find_chunk(target.chunk);
            if (chunk == nullptr) return weight;
            const auto material = chunk->cells[target.index].material_value();
            if (material == Material::Empty)
                return weight + state.gauge_of_label(chunk->pressure->cells[target.index].gas);
            const auto& definition = MaterialRules::descriptor(material);
            if (definition.state != MaterialState::Liquid) return std::nullopt;
            weight += material == Material::Water
                ? cell_quantity(*chunk, target.index)
                : static_cast<std::int64_t>(definition.density) * maximum / 1000;
            if (weight > kHeadClamp) return kHeadClamp;
        }
    };

    std::size_t begin = 0;
    std::size_t column_task = 0;
    while (cached ? column_task < cache->dirty_columns.size() : begin < coordinates.size()) {
        auto end = begin;
        std::size_t group = 0;
        if (cached) {
            group = cache->dirty_columns[column_task++];
            begin = cache->columns[group].first;
            end = cache->columns[group].last;
        } else {
            while (end < coordinates.size() && coordinates[end].x == coordinates[begin].x) ++end;
        }
        for (std::int32_t local_x = 0; local_x < size; ++local_x) {
            if (cached && !cache->columns[group].test(local_x)) continue;
            ++state.optimization.columns_recomputed;
            const auto x = coordinates[begin].x * size + local_x;
            // Walk the chunk column; runs never bridge an unallocated chunk.
            bool open = false;
            std::size_t run_chunk = 0;
            std::int32_t run_local = 0;
            std::int64_t run_top = 0;
            std::int64_t total = 0;
            std::optional<std::int64_t> top;
            const auto close_run = [&](std::size_t floor_chunk, std::int32_t floor_local, std::int64_t floor_y,
                                       bool supported) {
                auto chunk_position = run_chunk;
                auto local = run_local;
                for (std::int64_t y = run_top; y <= floor_y; ++y) {
                    auto& chunk = *find_chunk(coordinates[chunk_position]);
                    const auto index = static_cast<std::size_t>(local) * static_cast<std::size_t>(size) +
                                       static_cast<std::size_t>(local_x);
                    std::int64_t value = 0;
                    if (!supported) {
                        value = cell_quantity(chunk, index) + top.value_or(0);
                        put_base(chunk, index, static_cast<std::int32_t>(clamp_head(value)));
                    } else {
                        const auto compacted = std::max<std::int64_t>(0, total - (floor_y - y) * maximum);
                        if (top.has_value()) {
                            put_base(chunk, index, static_cast<std::int32_t>(clamp_head(*top + compacted)));
                        } else {
                            put_base(chunk, index, static_cast<std::int32_t>(
                                kUnknownHeadBase - std::min(compacted, kHeadClamp)));
                            ++state.diagnostics.unknown_heads;
                        }
                    }
                    ++state.diagnostics.head_cells;
                    if (++local == size) {
                        local = 0;
                        ++chunk_position;
                    }
                }
                (void)floor_chunk;
                (void)floor_local;
                open = false;
            };
            for (auto position = begin; position < end; ++position) {
                const auto coord = coordinates[position];
                if (open && position > begin && coordinates[position - 1].y + 1 != coord.y) {
                    // The run's floor sits above an unallocated (Empty) chunk.
                    close_run(position - 1, size - 1, coordinates[position - 1].y * size + size - 1, false);
                }
                auto& chunk = *find_chunk(coord);
                for (std::int32_t local_y = 0; local_y < size; ++local_y) {
                    const auto y = coord.y * size + local_y;
                    const auto index = static_cast<std::size_t>(local_y) * static_cast<std::size_t>(size) +
                                       static_cast<std::size_t>(local_x);
                    const auto material = chunk.cells[index].material_value();
                    const bool water = material == Material::Water && transient_obstacle_at(x, y) == 0U;
                    if (water) {
                        if (!open) {
                            open = true;
                            run_chunk = position;
                            run_local = local_y;
                            run_top = y;
                            total = 0;
                            top = top_pressure(x, y);
                        }
                        total += cell_quantity(chunk, index);
                        continue;
                    }
                    put_base(chunk, index, kNoHead);
                    if (open) {
                        const bool supported = !(material == Material::Empty && transient_obstacle_at(x, y) == 0U);
                        close_run(position, local_y, y - 1, supported);
                    }
                }
            }
            if (open) {
                const auto last = coordinates[end - 1];
                close_run(end - 1, size - 1, last.y * size + size - 1, false);
            }
        }
        if (cached) { cache->columns[group].dirty = {}; cache->columns[group].queued = false; }
        begin = end;
    }
    if (cached) cache->dirty_columns.clear();

    // Row pass: resolve lidded heads within contiguous Water row segments, then
    // wake sleeping blocks whose cells have an actionable gradient.
    auto& row_coordinates = cached ? cache->row_order : coordinates;
    if (!cached) std::sort(row_coordinates.begin(), row_coordinates.end(), [](const ChunkCoord& a, const ChunkCoord& b) {
        return a.y != b.y ? a.y < b.y : a.x < b.x;
    });
    const auto start_band = std::max<std::int64_t>(1, (PressureFlowParameters::kStartDeadBand255 * maximum + 127) / 255);
    begin = 0;
    while (begin < row_coordinates.size()) {
        auto end = begin;
        while (end < row_coordinates.size() && row_coordinates[end].y == row_coordinates[begin].y) ++end;
        const auto group = cached ? find_chunk(row_coordinates[begin])->pressure->row_group : 0U;
        for (std::int32_t local_y = 0; local_y < size; ++local_y) {
            const auto y = row_coordinates[begin].y * size + local_y;
            if (!cached || cache->rows[group].test(local_y)) {
            ++state.optimization.rows_recomputed;
            // Segment state.
            struct Known {
                bool valid = false;
                std::int64_t x = 0;
                std::int64_t value = 0;
            };
            Known left;
            bool segment_open = false;
            std::int64_t pending_from = 0;  // first unresolved x after `left`
            bool pending = false;
            const auto resolve = [&](std::int64_t from, std::int64_t to, Known right) {
                for (std::int64_t x = from; x <= to; ++x) {
                    const auto target = address(x, y);
                    auto& chunk = *find_chunk(target.chunk);
                    const auto base = cached ? chunk.pressure->base_head[target.index]
                                             : chunk.pressure->head[target.index];
                    if (!is_unknown_head(base)) continue;
                    const auto compacted = static_cast<std::int64_t>(kUnknownHeadBase) - base;
                    std::int64_t value = compacted;
                    if (left.valid && right.valid) {
                        value = left.value + (right.value - left.value) * (x - left.x) / (right.x - left.x);
                    } else if (left.valid) {
                        value = left.value;
                    } else if (right.valid) {
                        value = right.value;
                    }
                    put_final(chunk, target.index, static_cast<std::int32_t>(clamp_head(value)));
                }
            };
            std::int64_t previous_x = 0;
            bool have_previous = false;
            for (auto position = begin; position < end; ++position) {
                const auto coord = row_coordinates[position];
                if (have_previous && previous_x + 1 != coord.x * size && segment_open) {
                    if (pending) resolve(pending_from, previous_x, {});
                    segment_open = false;
                    pending = false;
                    left = {};
                }
                auto& chunk = *find_chunk(coord);
                for (std::int32_t local_x = 0; local_x < size; ++local_x) {
                    const auto x = coord.x * size + local_x;
                    const auto index = static_cast<std::size_t>(local_y) * static_cast<std::size_t>(size) +
                                       static_cast<std::size_t>(local_x);
                    const auto value = cached ? chunk.pressure->base_head[index] : chunk.pressure->head[index];
                    if (cached && !is_unknown_head(value)) put_final(chunk, index, value);
                    previous_x = x;
                    have_previous = true;
                    if (value == kNoHead) {
                        if (segment_open && pending) resolve(pending_from, x - 1, {});
                        segment_open = false;
                        pending = false;
                        left = {};
                        continue;
                    }
                    if (!segment_open) {
                        segment_open = true;
                        left = {};
                        pending = false;
                    }
                    if (is_unknown_head(value)) {
                        if (!pending) {
                            pending = true;
                            pending_from = x;
                        }
                        continue;
                    }
                    if (pending) {
                        resolve(pending_from, x - 1, {true, x, value});
                        pending = false;
                    }
                    left = {true, x, value};
                }
            }
            if (segment_open && pending) resolve(pending_from, previous_x, {});

            }
            // Actionable-gradient wake for cells in sleeping blocks (same stencil
            // and start dead band as the kernel).
            for (auto position = begin; position < end; ++position) {
                const auto coord = row_coordinates[position];
                auto& chunk = *find_chunk(coord);
                const auto block_y = local_y / config_.activity_block_size;
                for (std::int32_t block_x = 0; block_x < chunk.activity_blocks_per_axis; ++block_x) {
                    const auto block_index = static_cast<std::size_t>(block_y) *
                                                 static_cast<std::size_t>(chunk.activity_blocks_per_axis) +
                                             static_cast<std::size_t>(block_x);
                    if (chunk.activity_blocks[block_index].active) continue;
                    const auto first = block_x * config_.activity_block_size;
                    const auto last = std::min(first + config_.activity_block_size, size);
                    for (std::int32_t local_x = first; local_x < last; ++local_x) {
                        const auto index = static_cast<std::size_t>(local_y) * static_cast<std::size_t>(size) +
                                           static_cast<std::size_t>(local_x);
                        const auto own = chunk.pressure->head[index];
                        if (own == kNoHead) continue;
                        const auto x = coord.x * size + local_x;
                        const auto& sidecar = chunk.pressure->cells[index];
                        bool actionable = sidecar.flow != 0 || sidecar.overfill != 0;
                        if (!actionable) {
                            const auto sample = [&](std::int64_t nx) -> std::optional<std::int64_t> {
                                if (transient_obstacle_at(nx, y) != 0U) return std::nullopt;
                                const auto target = address(nx, y);
                                const auto* other = find_chunk(target.chunk);
                                if (other == nullptr) return 0;
                                const auto material = other->cells[target.index].material_value();
                                if (material == Material::Empty)
                                    return state.gauge_of_label(other->pressure->cells[target.index].gas);
                                if (material != Material::Water) return std::nullopt;
                                const auto h = other->pressure->head[target.index];
                                return h == kNoHead ? 0 : static_cast<std::int64_t>(h);
                            };
                            const auto own_value = static_cast<std::int64_t>(own);
                            const auto l1 = sample(x - 1);
                            const auto l2 = l1 ? sample(x - 2) : std::nullopt;
                            const auto r1 = sample(x + 1);
                            const auto r2 = r1 ? sample(x + 2) : std::nullopt;
                            const auto a = l1.value_or(own_value);
                            const auto b = l2.value_or(a);
                            const auto c = r1.value_or(own_value);
                            const auto d = r2.value_or(c);
                            const auto gradient = (b + a - c - d) / 2;
                            actionable = gradient > start_band || gradient < -start_band;
                        }
                        if (actionable) {
                            wake_activity_block(coord, chunk, block_index);
                            break;
                        }
                    }
                }
            }
        }
        if (cached) { cache->rows[group].dirty = {}; cache->rows[group].queued = false; }
        begin = end;
    }
    if (cached) cache->dirty_rows.clear();
}

bool World::update_water_pressure(std::int64_t x, std::int64_t y, JobEffects* effects) {
    record_physics(PhysicsEvent::WaterUpdate, Material::Water, Material::Empty, 0, 0, effects);
    auto& work = effects != nullptr && effects->pressure_work != nullptr
        ? *effects->pressure_work : pressure_->optimization;
    ++work.water_material_calls;
    if (pressure_->cache != nullptr && pressure_->cache->dormant &&
        pressure_->cache->complete && pressure_->cache->use_heads && pressure_->cache->certificate_layer_enabled &&
        !pressure_->cache->certificate_contents_cold && pressure_motion_is_noop(x, y, effects)) {
        ++work.certificate_saved_calls;
        return false;
    }
    ++work.water_motion_calls;
    const auto maximum = static_cast<std::int64_t>(config_.water_experiment_policy.maximum());
    const auto overfill_limit = maximum;
    bool changed = false;
    const auto direction = deterministic_direction(x, y);

    // Witness a direct authoritative write exactly as transfer_water does.
    const auto witness = [this, effects](Chunk& chunk, const Address& at, std::int64_t non_empty_delta,
                                         std::int64_t wx, std::int64_t wy) {
        if (effects != nullptr) {
            effects->record(at, non_empty_delta);
            effects->pressure_gas_changed = effects->pressure_gas_changed || non_empty_delta != 0;
            if (settled_discovery_ != nullptr)
                effects->record_discovery_mutation(at, config_.activity_block_size);
        } else {
            invalidate_pressure_input(at.chunk, at.local_x, at.local_y,
                                      at.local_x, at.local_y, non_empty_delta != 0);
            chunk.non_empty_cell_count = static_cast<std::size_t>(
                static_cast<std::int64_t>(chunk.non_empty_cell_count) + non_empty_delta);
            chunk.changed_this_tick = true;
            mark_cell_dirty(chunk, at.local_x, at.local_y);
            wake_cell_neighborhood(wx, wy);
            dirty_discovery_cell(wx, wy, soliding::ProducerReason::DirectMutation);
        }
    };
    struct Ref {
        Chunk* chunk = nullptr;
        Address at{};
    };
    const auto ref = [this, effects](std::int64_t rx, std::int64_t ry) -> Ref {
        Ref out;
        out.at = address(rx, ry);
        out.chunk = find_chunk(out.at.chunk);
        if (out.chunk == nullptr && effects != nullptr) effects->overflow = true;
        return out;
    };
    const auto quantity = [](const Ref& r) -> std::int64_t {
        return static_cast<std::int64_t>(r.chunk->cells[r.at.index].state_a_value()) +
               static_cast<std::int64_t>(r.chunk->pressure->cells[r.at.index].overfill);
    };
    // Remove `amount` from a Water cell, overfill first (overfill > 0 implies a
    // saturated cell). An emptied source becomes vacuum Empty.
    const auto take = [&](const Ref& r, std::int64_t amount, std::int64_t wx, std::int64_t wy) {
        auto& cell = r.chunk->cells[r.at.index];
        auto& side = r.chunk->pressure->cells[r.at.index];
        const auto from_overfill = std::min<std::int64_t>(amount, side.overfill);
        const auto old_visible = cell.state_a_value();
        const auto old_overfill = side.overfill;
        side.overfill = static_cast<std::uint16_t>(side.overfill - from_overfill);
        const auto remaining = static_cast<std::int64_t>(cell.state_a_value()) - (amount - from_overfill);
        record_quantity_transition(Material::Water, old_visible, old_overfill,
            remaining <= 0 ? Material::Empty : Material::Water,
            static_cast<std::uint16_t>(std::max<std::int64_t>(0, remaining)), side.overfill,
            effects, {}, false);
        if (remaining <= 0) {
            cell = Chunk::Cell::for_material(Material::Empty);
            side = {};
            side.gas = kVacuumLabel;
            cell.set_epoch(update_epoch_);
            witness(*r.chunk, r.at, -1, wx, wy);
            return;
        }
        cell.set_state_a(static_cast<std::uint16_t>(remaining));
        cell.set_epoch(update_epoch_);
        witness(*r.chunk, r.at, 0, wx, wy);
    };
    // Add `amount` to a Water (or Empty -> new Water) cell: visible first, then overfill.
    const auto give = [&](const Ref& r, std::int64_t amount, std::int16_t incoming_flow,
                          std::uint8_t incoming_coherence, bool mark_epoch,
                          std::int64_t wx, std::int64_t wy) {
        auto& cell = r.chunk->cells[r.at.index];
        auto& side = r.chunk->pressure->cells[r.at.index];
        const auto old_material = cell.material_value();
        const auto old_visible = cell.state_a_value();
        const auto old_overfill = side.overfill;
        std::int64_t delta = 0;
        std::int64_t before = 0;
        if (cell.material_value() == Material::Empty) {
            cell = Chunk::Cell::for_material(Material::Water);
            cell.set_state_a(0);
            cell.set_state_b(0);
            side = {};
            delta = 1;
        } else {
            before = static_cast<std::int64_t>(cell.state_a_value()) + side.overfill;
        }
        const auto visible = std::min<std::int64_t>(amount, maximum - cell.state_a_value());
        cell.set_state_a(static_cast<std::uint16_t>(cell.state_a_value() + visible));
        cell.set_state_b(std::max(cell.state_b_value(), incoming_coherence));
        side.overfill = static_cast<std::uint16_t>(side.overfill + (amount - visible));
        record_quantity_transition(old_material, old_visible, old_overfill, Material::Water,
            cell.state_a_value(), side.overfill, effects, {}, false);
        // Mass-weighted velocity merge; the truncation remainder is booked.
        const auto numerator = before * side.flow + amount * incoming_flow;
        const auto after = before + amount;
        const auto merged = numerator / after;
        side.flow = static_cast<std::int16_t>(merged);
        const auto remainder = numerator - merged * after;
        if (effects != nullptr) effects->pf_flow_remainder += remainder;
        else pressure_->flow.flow_remainder += remainder;
        if (mark_epoch) cell.set_epoch(update_epoch_);
        witness(*r.chunk, r.at, delta, wx, wy);
    };

    // Stage 2: material pre-motion (coherence countdown), as FreeMass.
    const auto coherence_delay = state_b(x, y);
    if (coherence_delay != 0U) {
        changed = write_cell(x, y, Material::Water, state_a(x, y),
                             static_cast<std::uint8_t>(coherence_delay - 1U), effects);
    }

    // Stage 3a: gravity. Falling into Water fills visible capacity only; a whole
    // tuple move or density swap carries the sidecar through move_cell.
    const auto fall = [&](std::int64_t tx, std::int64_t ty) {
        if (stored_material(x, y) != Material::Water) return false;
        if (transient_obstacle_at(tx, ty) == 0U && stored_material(tx, ty) == Material::Water) {
            const auto source = ref(x, y);
            const auto destination = ref(tx, ty);
            if (source.chunk == nullptr || destination.chunk == nullptr) return false;
            const auto capacity = maximum - destination.chunk->cells[destination.at.index].state_a_value();
            const auto amount = std::min<std::int64_t>(capacity, quantity(source));
            if (amount <= 0) return false;
            record_physics(PhysicsEvent::WaterTransfer, Material::Water, Material::Water,
                           tx - x, ty - y, effects, static_cast<std::uint64_t>(amount));
            const auto flow = source.chunk->pressure->cells[source.at.index].flow;
            const auto coherence = source.chunk->cells[source.at.index].state_b_value();
            take(source, amount, x, y);
            give(destination, amount, flow, coherence, true, tx, ty);
            mix_after_motion(Material::Water, x, y, tx, ty, static_cast<std::uint16_t>(amount), effects);
            changed = true;
            return true;
        }
        const auto moved = try_move(Material::Water, x, y, tx, ty, true, effects);
        changed = changed || moved;
        return moved;
    };
    (void)fall(x, y + 1);
    if (stored_material(x, y) != Material::Water) return changed;
    (void)fall(x + direction, y + 1);
    if (stored_material(x, y) != Material::Water) return changed;
    (void)fall(x - direction, y + 1);
    if (stored_material(x, y) != Material::Water) return changed;

    auto self = ref(x, y);
    if (self.chunk == nullptr) return changed;
    auto* self_side = &self.chunk->pressure->cells[self.at.index];

    // Stage 3b: bounded overfill relief and relay. Overfill rises into
    // unsaturated Water or Empty above, relays up a saturated column toward less
    // overfill, and spreads sideways only under a lid.
    if (self_side->overfill != 0U) {
        const auto above_masked = transient_obstacle_at(x, y - 1) != 0U;
        const auto above = above_masked ? Material::Wall : stored_material(x, y - 1);
        std::int64_t o = self_side->overfill;
        if (above == Material::Empty) {
            const auto target = ref(x, y - 1);
            if (target.chunk != nullptr) {
                const auto amount = std::min(o, maximum);
                record_quantity_transition(Material::Water, self.chunk->cells[self.at.index].state_a_value(),
                        self_side->overfill, Material::Water, self.chunk->cells[self.at.index].state_a_value(),
                        static_cast<std::uint16_t>(o - amount), effects, {}, false);
                    self_side->overfill = static_cast<std::uint16_t>(o - amount);
                give(target, amount, self_side->flow, self.chunk->cells[self.at.index].state_b_value(), true, x, y - 1);
                mix_after_motion(Material::Water, x, y, x, y - 1, static_cast<std::uint16_t>(amount), effects);
                if (effects != nullptr) ++effects->pf_relief_cells;
                else ++pressure_->flow.relief_cells;
                witness(*self.chunk, self.at, 0, x, y);
                changed = true;
            }
        } else if (above == Material::Water) {
            const auto target = ref(x, y - 1);
            if (target.chunk != nullptr) {
                const auto visible = target.chunk->cells[target.at.index].state_a_value();
                const auto other = static_cast<std::int64_t>(target.chunk->pressure->cells[target.at.index].overfill);
                std::int64_t amount = 0;
                // A saturated column transmits overfill whole (incompressible
                // relay); the receiver is not epoch-marked, so a bottom-up scan
                // carries it to the free surface within one tick.
                if (visible < maximum) amount = std::min(o, maximum - visible);
                else amount = std::min(o, overfill_limit - other);
                if (amount > 0) {
                    record_quantity_transition(Material::Water, self.chunk->cells[self.at.index].state_a_value(),
                        self_side->overfill, Material::Water, self.chunk->cells[self.at.index].state_a_value(),
                        static_cast<std::uint16_t>(o - amount), effects, {}, false);
                    self_side->overfill = static_cast<std::uint16_t>(o - amount);
                    give(target, amount, self_side->flow, self.chunk->cells[self.at.index].state_b_value(), false, x, y - 1);
                    mix_after_motion(Material::Water, x, y, x, y - 1, static_cast<std::uint16_t>(amount), effects);
                    witness(*self.chunk, self.at, 0, x, y);
                    changed = true;
                }
            }
        } else {
            std::optional<std::int64_t> best;
            std::int64_t best_score = 0;
            for (const auto side : {direction, -direction}) {
                const auto nx = x + side;
                if (transient_obstacle_at(nx, y) != 0U || stored_material(nx, y) != Material::Water) continue;
                const auto target = ref(nx, y);
                if (target.chunk == nullptr) continue;
                const auto visible = target.chunk->cells[target.at.index].state_a_value();
                const auto other = static_cast<std::int64_t>(target.chunk->pressure->cells[target.at.index].overfill);
                const auto score = visible < maximum ? -(maximum - visible) : other;
                if (!best || score < best_score) {
                    best = nx;
                    best_score = score;
                }
            }
            if (best) {
                const auto target = ref(*best, y);
                const auto visible = target.chunk->cells[target.at.index].state_a_value();
                const auto other = static_cast<std::int64_t>(target.chunk->pressure->cells[target.at.index].overfill);
                std::int64_t amount = 0;
                if (visible < maximum) amount = std::min(o, maximum - visible);
                else if (o - other >= 2) amount = std::min((o - other) / 2, overfill_limit - other);
                if (amount > 0) {
                    record_quantity_transition(Material::Water, self.chunk->cells[self.at.index].state_a_value(),
                        self_side->overfill, Material::Water, self.chunk->cells[self.at.index].state_a_value(),
                        static_cast<std::uint16_t>(o - amount), effects, {}, false);
                    self_side->overfill = static_cast<std::uint16_t>(o - amount);
                    give(target, amount, self_side->flow, self.chunk->cells[self.at.index].state_b_value(), false, *best, y);
                    mix_after_motion(Material::Water, x, y, *best, y, static_cast<std::uint16_t>(amount), effects);
                    witness(*self.chunk, self.at, 0, x, y);
                    changed = true;
                }
            }
        }
    }

    auto flow = static_cast<std::int64_t>(self_side->flow);
    const auto store = [&](bool keep_active) {
        if (self_side->flow != static_cast<std::int16_t>(flow)) {
            self_side->flow = static_cast<std::int16_t>(flow);
            witness(*self.chunk, self.at, 0, x, y);
            changed = true;
        }
        if (keep_active || flow != 0 || self_side->overfill != 0U) keep_cell_active(x, y, effects);
        return changed;
    };

    // The adhesion film holds only a resting thin cell (W-PF declaration): a
    // moving sheet keeps its momentum.
    const auto support = get(x, y + 1);
    if (liquid_surface_adhesion_enabled_ && flow == 0 &&
        self.chunk->cells[self.at.index].state_a_value() <= config_.water_experiment_policy.film() &&
        support != Material::Empty && support != Material::Water) {
        return store(false);
    }
    // Coherent emission suppresses lateral motion while it counts down.
    if (coherence_delay != 0U) return store(false);
    if (!lateral_due(Material::Water, x, y, effects)) return store(false);

    // Stage 3c: velocity from the immutable head snapshot. Samples never cross a
    // wall, foreign liquid or body mask: x+-2 requires both faces open.
    const auto gradient = pressure_lateral_gradient(x, y);
    const auto band = std::max<std::int64_t>(1, ((flow == 0 ? PressureFlowParameters::kStartDeadBand255
                                                             : PressureFlowParameters::kMovingDeadBand255) *
                                                     maximum + 127) / 255);
    if (gradient > band || gradient < -band) {
        const auto scale = maximum * PressureFlowParameters::kAccelDenominator;
        const auto numerator = gradient * PressureFlowParameters::kAccelNumerator;
        auto delta = numerator / scale;
        const auto remainder = numerator - delta * scale;
        const auto roll = static_cast<std::int64_t>(deterministic_random(x, y, 230U));
        if ((remainder < 0 ? -remainder : remainder) * 256 > roll * scale) delta += remainder < 0 ? -1 : 1;
        flow += delta;
    }
    if (flow != 0) {
        const auto magnitude = flow < 0 ? -flow : flow;
        const auto loss_numerator = magnitude * (256 - PressureFlowParameters::kRetain);
        auto loss = loss_numerator / 256;
        if (loss_numerator % 256 > static_cast<std::int64_t>(deterministic_random(x, y, 231U))) ++loss;
        // Constant (Coulomb) friction guarantees that slow sloshing comes to rest.
        loss = std::min(magnitude, loss + PressureFlowParameters::kFriction);
        flow += flow < 0 ? loss : -loss;
        flow = std::clamp<std::int64_t>(flow, -PressureFlowParameters::kFlowScale, PressureFlowParameters::kFlowScale);
    }
    if (flow == 0) {
        // Surface skin: a resting top-of-run cell relaxes sub-row steps with the
        // FreeMass 3/4 rule and tolerance, so bulk static friction never leaves
        // terraced resting surfaces. Saturated cells and overfill never move here.
        const auto above = transient_obstacle_at(x, y - 1) != 0U ? Material::Wall : stored_material(x, y - 1);
        if (above != Material::Water) {
            const auto level_with = [&](std::int64_t nx) {
                if (stored_material(x, y) != Material::Water) return;
                if (transient_obstacle_at(nx, y) != 0U) return;
                const auto neighbour = stored_material(nx, y);
                if (neighbour != Material::Empty && neighbour != Material::Water) return;
                const auto source = ref(x, y);
                const auto target = ref(nx, y);
                if (source.chunk == nullptr || target.chunk == nullptr) return;
                const auto source_mass = static_cast<std::int64_t>(source.chunk->cells[source.at.index].state_a_value());
                const auto target_mass = neighbour == Material::Water
                    ? static_cast<std::int64_t>(target.chunk->cells[target.at.index].state_a_value()) : 0;
                if (source_mass <= target_mass + config_.water_experiment_policy.tolerance()) return;
                const auto amount = std::min(static_cast<std::int64_t>(MaterialRules::apply_lateral_viscosity(
                                                 Material::Water,
                                                 static_cast<std::uint16_t>((source_mass - target_mass) * 3 / 4))),
                                             maximum - target_mass);
                if (amount <= 0) return;
                record_physics(PhysicsEvent::WaterTransfer, Material::Water, neighbour, nx - x, 0, effects,
                               static_cast<std::uint64_t>(amount));
                const auto coherence = source.chunk->cells[source.at.index].state_b_value();
                take(source, amount, x, y);
                give(target, amount, 0, coherence, neighbour == Material::Empty, nx, y);
                mix_after_motion(Material::Water, x, y, nx, y, static_cast<std::uint16_t>(amount), effects);
                changed = true;
            };
            level_with(x + direction);
            if (!config_.transport_policy.configured || config_.transport_policy.horizontal[3] == 2)
                level_with(x - direction);
            if (stored_material(x, y) != Material::Water) return changed;
        }
        return store(false);
    }

    // Stage 3d: flux along the updated velocity. The outgoing quantity carries
    // this tick's velocity (never the stale stored value).
    const auto step = flow > 0 ? 1 : -1;
    const auto tx = x + step;
    if (const auto body = transient_obstacle_at(tx, y); body != 0U) {
        record_physics(PhysicsEvent::BodyContact, Material::Water, Material::Empty, step, 0, effects);
        record_transient_contact(body, Material::Water, step, 0);
        if (effects != nullptr) effects->pf_contact_loss += static_cast<std::uint64_t>(flow < 0 ? -flow : flow);
        else pressure_->flow.contact_loss += static_cast<std::uint64_t>(flow < 0 ? -flow : flow);
        flow = 0;
        return store(true);
    }
    const auto target_material = stored_material(tx, y);
    if (target_material != Material::Empty && target_material != Material::Water) {
        if (effects != nullptr) effects->pf_contact_loss += static_cast<std::uint64_t>(flow < 0 ? -flow : flow);
        else pressure_->flow.contact_loss += static_cast<std::uint64_t>(flow < 0 ? -flow : flow);
        flow = 0;
        return store(true);
    }
    const auto target = ref(tx, y);
    if (target.chunk == nullptr) return store(true);
    const auto available = quantity(self);
    const bool retain_source = stored_material(x, y - 1) == Material::Water &&
                               transient_obstacle_at(x, y - 1) == 0U;
    const auto magnitude = flow < 0 ? -flow : flow;
    const auto want_numerator = magnitude * available;
    auto want = want_numerator / PressureFlowParameters::kFlowScale;
    if ((want_numerator % PressureFlowParameters::kFlowScale) * 256 >
        static_cast<std::int64_t>(deterministic_random(x, y, 232U)) * PressureFlowParameters::kFlowScale) ++want;
    if (want <= 0) return store(true);
    std::int64_t amount = 0;
    if (target_material == Material::Empty) {
        amount = std::min({want, available, maximum});
        if (amount == available && self_side->overfill == 0U && !retain_source) {
            // Whole-cell move: the tuple and its sidecar travel together.
            self_side->flow = static_cast<std::int16_t>(flow);
            const auto moved_mass = self.chunk->cells[self.at.index].state_a_value();
            move_cell(x, y, tx, y, false, effects);
            record_physics(PhysicsEvent::WaterTransfer, Material::Water, Material::Empty, step, 0, effects,
                           static_cast<std::uint64_t>(amount));
            mix_after_motion(Material::Water, x, y, tx, y, moved_mass, effects);
            return true;
        }
    } else {
        const auto& destination = target.chunk->cells[target.at.index];
        const auto capacity = (maximum - destination.state_a_value()) +
                              (overfill_limit - target.chunk->pressure->cells[target.at.index].overfill);
        amount = std::min({want, available, capacity});
    }
    // Water under Water never opens an interior void laterally: it keeps one
    // unit and gravity refills it from above (bottom-up, this same tick).
    if (amount >= available && retain_source)
        amount = available - 1;
    if (amount <= 0) return store(true);
    record_physics(PhysicsEvent::WaterTransfer, Material::Water, target_material, step, 0, effects,
                   static_cast<std::uint64_t>(amount));
    const auto outgoing = static_cast<std::int16_t>(flow);
    const auto outgoing_coherence = self.chunk->cells[self.at.index].state_b_value();
    const bool emptied = amount >= available;
    if (!emptied) self_side->flow = outgoing;
    take(self, amount, x, y);
    give(target, amount, outgoing, outgoing_coherence, target_material == Material::Empty, tx, y);
    mix_after_motion(Material::Water, x, y, tx, y, static_cast<std::uint16_t>(std::min<std::int64_t>(amount, 65535)),
                     effects);
    if (emptied) return true;
    keep_cell_active(x, y, effects);
    return true;
}

// ---------------------------------------------------------------- hashing

std::uint64_t World::physical_state_hash() const {
    return physical_state_hash_impl(std::nullopt);
}

std::uint64_t World::liquid_comparison_hash(LiquidStateProjection projection) const {
    if (liquid_state_projection_domain(projection).empty())
        throw std::invalid_argument("unknown liquid state projection");
    return physical_state_hash_impl(projection);
}

std::uint64_t World::physical_state_hash_impl(std::optional<LiquidStateProjection> projection) const {
    const bool quiescent = projection == LiquidStateProjection::QuiescentPhysicalContentV1;
    std::uint64_t hash = 1469598103934665603ULL;
    if (projection) {
        for (const char c : liquid_state_projection_domain(*projection))
            hash_byte(hash, static_cast<std::uint8_t>(c));
        hash_byte(hash, 0U);
    }
    for (const char c : std::string_view{"cybersand-physical-state"}) hash_byte(hash, static_cast<std::uint8_t>(c));
    hash_integer(hash, physical_state_hash_version());
    QuantityHashWriter quantity_hash{hash};
    if (quiescent) {
        // Keep the original construction binding, baseline and exact present
        // populations/quantity. Exclude only cumulative source/sink counters.
        auto observed = quantity_;
        observed.kinds = {};
        observed.pair_rules = {};
        observed.pair_events = {};
        observed.kernel_rules = {};
        quantity_write(quantity_hash, observed);
    } else {
        quantity_write(quantity_hash, quantity_);
        hash_integer(hash, tick_index_);
        hash_integer(hash, completed_tick_index_);
    }
    hash_integer(hash, static_cast<std::uint8_t>(tick_failed_));
    if (!quiescent) hash_integer(hash, update_epoch_);
    for (const auto& region : {selected_core_region_, applied_core_region_}) {
        hash_integer(hash, static_cast<std::uint8_t>(region.has_value()));
        if (region) {
            hash_integer(hash, region->min_x);
            hash_integer(hash, region->min_y);
            hash_integer(hash, region->max_x);
            hash_integer(hash, region->max_y);
        }
    }
    hash_integer(hash, config_.chunk_size);
    hash_integer(hash, static_cast<std::uint8_t>(config_.backend));
    hash_integer(hash, config_.sleep_after_quiet_ticks);
    hash_integer(hash, config_.ambient_temperature);
    hash_integer(hash, config_.activity_block_size);
    hash_integer(hash, config_.scheduling_core_size);
    hash_integer(hash, config_.maximum_rule_radius);
    hash_integer(hash, config_.maximum_explosion_radius);
    hash_integer(hash, static_cast<std::uint8_t>(config_.physics_diagnostics.disable_powder_exchange_targets));
    hash_integer(hash, config_.physics_diagnostics.mercury_viscosity);
    hash_integer(hash, config_.interaction_policy.downward_support_cells);
    hash_integer(hash, config_.interaction_policy.side_support_cells);
    hash_integer(hash, config_.interaction_policy.mercury_exchange_period);
    hash_integer(hash, config_.water_experiment_policy.version());
    hash_integer(hash, config_.water_experiment_policy.mass_bits());
    hash_integer(hash, config_.water_experiment_policy.coherence_ticks());
    hash_integer(hash, static_cast<std::uint8_t>(config_.water_experiment_policy.rest_policy()));
    hash_integer(hash, static_cast<std::uint8_t>(config_.transport_policy.configured));
    if (config_.transport_policy.configured) {
        for (auto n : config_.transport_policy.horizontal) hash_integer(hash, n);
        for (auto n : config_.transport_policy.cadence) hash_integer(hash, n);
        for (const auto& p : config_.transport_policy.pairs) {
            hash_integer(hash, p.mixing); hash_integer(hash, p.carrying); hash_integer(hash, p.pickup);
            hash_integer(hash, p.packing); hash_integer(hash, p.erosion); hash_integer(hash, p.permeability);
        }
    }
    hash_integer(hash, static_cast<std::uint8_t>(liquid_surface_adhesion_enabled_));
    const auto policy_identity = projection
        ? config_.liquid_solver_policy.pressure_variant_equivalence_hash()
        : config_.liquid_solver_policy.policy_hash();
    for (const auto byte : policy_identity) hash_byte(hash, byte);
    if (inertial_enabled_) {
        for (const auto byte:inertial_extension_identity(inertial_parameters_)) hash_byte(hash,byte);
    }
    hash_integer(hash, static_cast<std::uint8_t>(pressure_ != nullptr));
    if (pressure_ != nullptr) {
        hash_integer(hash, PressureFlowParameters::kVersion);
        hash_integer(hash, static_cast<std::uint8_t>(pressure_->parameters.gas_enabled));
        hash_integer(hash, pressure_->parameters.atmospheric_head_rows);
    }
    hash_integer(hash, static_cast<std::uint64_t>(pending_explosions_.size()));
    for (const auto& event : pending_explosions_) {
        hash_integer(hash, event.x);
        hash_integer(hash, event.y);
        hash_integer(hash, event.radius);
        hash_integer(hash, event.collapse_strength);
    }
    const auto& masks = *transient_obstacles_;
    std::vector<std::size_t> occupied(masks.occupied_indices.begin(), masks.occupied_indices.end());
    std::sort(occupied.begin(), occupied.end());
    occupied.erase(std::unique(occupied.begin(), occupied.end()), occupied.end());
    hash_integer(hash, static_cast<std::uint64_t>(occupied.size()));
    if (!occupied.empty()) {
        hash_integer(hash, masks.region.x);
        hash_integer(hash, masks.region.y);
        hash_integer(hash, masks.region.width);
        for (const auto index : occupied) {
            hash_integer(hash, static_cast<std::uint64_t>(index));
            hash_integer(hash, masks.body_ids[index]);
        }
    }
    std::vector<ChunkCoord> coordinates;
    coordinates.reserve(chunks_.size());
    for (const auto& [coord, chunk] : chunks_) {
        (void)chunk;
        coordinates.push_back(coord);
    }
    std::sort(coordinates.begin(), coordinates.end());
    for (const auto coord : coordinates) {
        const auto* chunk = find_chunk(coord);
        // Only non-default content enters the hash, so an allocated all-Empty,
        // inactive chunk is indistinguishable from an unallocated one.
        for (std::size_t index = 0; index < chunk->activity_blocks.size(); ++index) {
            const auto& block = chunk->activity_blocks[index];
            if ((quiescent || !block.active) && block.next_interaction_tick == 0U) continue;
            hash_integer(hash, coord.x);
            hash_integer(hash, coord.y);
            hash_integer(hash, static_cast<std::uint64_t>(index));
            if (!quiescent) {
                hash_integer(hash, static_cast<std::uint8_t>(block.active));
                hash_integer(hash, block.active ? block.quiet_ticks : 0U);
            }
            hash_integer(hash, block.next_interaction_tick);
        }
        for (std::size_t index = 0; index < chunk->cells.size(); ++index) {
            const auto& cell = chunk->cells[index];
            const auto temperature = chunk->temperatures == nullptr ? config_.ambient_temperature
                                                                     : (*chunk->temperatures)[index];
            const PressureChunk::Cell side = chunk->pressure == nullptr ? PressureChunk::Cell{}
                                                                        : chunk->pressure->cells[index];
            const InertialSlot motion = chunk->inertial == nullptr ? InertialSlot{} : (*chunk->inertial)[index];
            const auto material = cell.material_value();
            if (material == Material::Empty && temperature == config_.ambient_temperature && side.gas == 0U &&
                motion.vx == 0 && motion.vy == 0 && motion.ax == 0 && motion.ay == 0)
                continue;
            hash_integer(hash, coord.x * config_.chunk_size +
                                   static_cast<std::int64_t>(index % static_cast<std::size_t>(config_.chunk_size)));
            hash_integer(hash, coord.y * config_.chunk_size +
                                   static_cast<std::int64_t>(index / static_cast<std::size_t>(config_.chunk_size)));
            hash_integer(hash, static_cast<std::uint16_t>(material));
            hash_integer(hash, cell.state_a_value());
            hash_integer(hash, cell.state_b_value());
            if (!quiescent)
                hash_integer(hash, material == Material::Empty ? std::uint8_t{0} : cell.epoch_value());
            hash_integer(hash, temperature);
            hash_integer(hash, side.overfill);
            hash_integer(hash, side.flow);
            hash_integer(hash, side.gas);
            if (inertial_enabled_) {
                hash_integer(hash,motion.vx); hash_integer(hash,motion.vy);
                hash_integer(hash,motion.ax); hash_integer(hash,motion.ay);
            }
        }
    }
    if (pressure_ != nullptr) {
        hash_integer(hash, pressure_->next_id);
        hash_integer(hash, pressure_->topology_revision);
        hash_integer(hash, static_cast<std::uint64_t>(pressure_->compartments.size()));
        for (const auto& c : pressure_->compartments) {
            hash_integer(hash, c.id);
            hash_integer(hash, c.generation);
            hash_integer(hash, c.parent_count);
            for (std::size_t i = 0; i < c.parent_count; ++i) hash_integer(hash, c.parents[i]);
            hash_integer(hash, c.amount);
            hash_integer(hash, c.volume);
            hash_integer(hash, c.anchor_x);
            hash_integer(hash, c.anchor_y);
            hash_integer(hash, c.created_tick);
            hash_integer(hash, c.revision);
            hash_integer(hash, c.gauge);
        }
    }
    return hash;
}

// ---------------------------------------------------------------- persistence

namespace {

class StateWriter {
public:
    template <typename Integer>
    void put(Integer value) {
        using Unsigned = std::make_unsigned_t<Integer>;
        auto bits = static_cast<Unsigned>(value);
        for (std::size_t i = 0; i < sizeof(Integer); ++i) {
            bytes.push_back(static_cast<std::uint8_t>(bits & static_cast<Unsigned>(0xFFU)));
            bits = static_cast<Unsigned>(bits >> 8U);
        }
    }
    std::vector<std::uint8_t> bytes;
};

class StateReader {
public:
    explicit StateReader(std::span<const std::uint8_t> data) : data_(data) {}
    template <typename Integer>
    [[nodiscard]] Integer get() {
        using Unsigned = std::make_unsigned_t<Integer>;
        if (data_.size() - position_ < sizeof(Integer))
            throw std::invalid_argument("physical state payload is truncated");
        Unsigned bits = 0;
        for (std::size_t i = 0; i < sizeof(Integer); ++i)
            bits = static_cast<Unsigned>(bits | (static_cast<Unsigned>(data_[position_ + i]) << (8U * i)));
        position_ += sizeof(Integer);
        return static_cast<Integer>(bits);
    }
    [[nodiscard]] bool done() const noexcept { return position_ == data_.size(); }

private:
    std::span<const std::uint8_t> data_;
    std::size_t position_ = 0;
};

constexpr std::uint32_t kPhysicalStateMagic = 0x53505943U;  // "CYPS"

void refuse_state(const char* detail) {
    throw std::invalid_argument(liquid_policy_detail::concat("physical state refused: ", detail));
}

}  // namespace

std::vector<std::uint8_t> World::save_physical_state() const {
    require_healthy();
    if (tick_in_progress_) throw std::logic_error("cannot save during a world tick");
    if (settled_discovery_ != nullptr)
        throw std::invalid_argument("physical state persistence does not support settled discovery");
    validate_quantity_ledger(true);
    validate_inertial_ledger();
    StateWriter out;
    out.put(kPhysicalStateMagic);
    out.put(physical_state_format_version());
    // Physics configuration.
    out.put(config_.chunk_size);
    out.put(config_.activity_block_size);
    out.put(config_.scheduling_core_size);
    out.put(config_.maximum_rule_radius);
    out.put(config_.sleep_after_quiet_ticks);
    out.put(config_.ambient_temperature);
    out.put(static_cast<std::uint8_t>(config_.backend));
    out.put(config_.maximum_explosion_radius);
    out.put(static_cast<std::uint8_t>(config_.physics_diagnostics.disable_powder_exchange_targets));
    out.put(config_.physics_diagnostics.mercury_viscosity);
    out.put(config_.interaction_policy.downward_support_cells);
    out.put(config_.interaction_policy.side_support_cells);
    out.put(config_.interaction_policy.mercury_exchange_period);
    out.put(config_.water_experiment_policy.mass_bits());
    out.put(config_.water_experiment_policy.coherence_ticks());
    out.put(static_cast<std::uint8_t>(config_.water_experiment_policy.rest_policy()));
    const auto transport = config_.transport_policy.configured ? pack_transport(config_.transport_policy)
                                                               : std::vector<std::int32_t>{};
    out.put(static_cast<std::uint32_t>(transport.size()));
    for (const auto word : transport) out.put(word);
    const auto envelope = config_.liquid_solver_policy.envelope();
    out.put(static_cast<std::uint32_t>(envelope.size()));
    for (const auto word : envelope) out.put(word);
    if (inertial_enabled_) {
        out.put(InertialParameters::kVersion);
        for (const auto byte:inertial_extension_identity(inertial_parameters_)) out.put(byte);
    }
    // Clock, interest and events.
    out.put(tick_index_);
    out.put(completed_tick_index_);
    out.put(update_epoch_);
    out.put(hard_surface_revision_);
    out.put(static_cast<std::uint8_t>(liquid_surface_adhesion_enabled_));
    out.put(static_cast<std::uint8_t>(simulation_region_.has_value()));
    if (simulation_region_) {
        out.put(simulation_region_->x);
        out.put(simulation_region_->y);
        out.put(simulation_region_->width);
        out.put(simulation_region_->height);
    }
    out.put(static_cast<std::uint8_t>(applied_core_region_.has_value()));
    if (applied_core_region_) {
        out.put(applied_core_region_->min_x);
        out.put(applied_core_region_->min_y);
        out.put(applied_core_region_->max_x);
        out.put(applied_core_region_->max_y);
    }
    out.put(static_cast<std::uint32_t>(pending_explosions_.size()));
    for (const auto& event : pending_explosions_) {
        out.put(event.x);
        out.put(event.y);
        out.put(event.radius);
        out.put(event.collapse_strength);
    }
    // Chunks in canonical order.
    std::vector<ChunkCoord> coordinates;
    coordinates.reserve(chunks_.size());
    for (const auto& [coord, chunk] : chunks_) {
        (void)chunk;
        coordinates.push_back(coord);
    }
    std::sort(coordinates.begin(), coordinates.end());
    out.put(static_cast<std::uint32_t>(coordinates.size()));
    for (const auto coord : coordinates) {
        const auto& chunk = *find_chunk(coord);
        out.put(coord.x);
        out.put(coord.y);
        const std::uint8_t flags = static_cast<std::uint8_t>((chunk.temperatures != nullptr ? 1U : 0U) |
                                                             (chunk.pressure != nullptr ? 2U : 0U) |
                                                             (chunk.inertial != nullptr ? 4U : 0U));
        out.put(flags);
        out.put(static_cast<std::uint32_t>(chunk.activity_blocks.size()));
        for (const auto& block : chunk.activity_blocks) {
            out.put(static_cast<std::uint8_t>(block.active));
            out.put(block.quiet_ticks);
            out.put(block.next_interaction_tick);
        }
        for (const auto& cell : chunk.cells) {
            out.put(static_cast<std::uint16_t>(cell.material_value()));
            out.put(cell.state_a_value());
            out.put(cell.state_b_value());
            out.put(cell.epoch_value());
        }
        if (chunk.temperatures != nullptr)
            for (const auto value : *chunk.temperatures) out.put(value);
        if (chunk.pressure != nullptr) {
            for (const auto& side : chunk.pressure->cells) {
                out.put(side.overfill);
                out.put(side.flow);
                out.put(side.gas);
            }
        }
        if (chunk.inertial != nullptr) for (const auto& s:*chunk.inertial) {
            out.put(s.vx); out.put(s.vy); out.put(s.ax); out.put(s.ay);
        }
    }
    quantity_write(out, quantity_);
    out.put(static_cast<std::uint8_t>(pressure_ != nullptr));
    if (pressure_ != nullptr) {
        const auto& state = *pressure_;
        out.put(state.next_id);
        out.put(state.topology_revision);
        out.put(static_cast<std::uint32_t>(state.compartments.size()));
        const auto put_compartment = [&out](const GasCompartmentSnapshot& c) {
            out.put(c.id);
            out.put(c.generation);
            out.put(c.parent_count);
            for (const auto parent : c.parents) out.put(parent);
            out.put(c.amount);
            out.put(c.volume);
            out.put(c.anchor_x);
            out.put(c.anchor_y);
            out.put(c.created_tick);
            out.put(c.revision);
            out.put(c.gauge);
        };
        for (const auto& c : state.compartments) put_compartment(PressureState::snapshot(c));
        out.put(static_cast<std::uint32_t>(state.history.size()));
        out.put(static_cast<std::uint32_t>(state.history_next));
        for (const auto& record : state.history) {
            put_compartment(record.compartment);
            out.put(static_cast<std::uint8_t>(record.reason));
            out.put(record.successor_count);
            for (const auto successor : record.successors) out.put(successor);
            out.put(record.tick);
        }
        const auto& gas = state.gas;
        for (const auto value : {gas.created, gas.absorbed, gas.vented, gas.collapsed, gas.merges, gas.splits,
                                 gas.creations, gas.vents, gas.collapses, gas.amount_live})
            out.put(value);
        out.put(state.flow.overfill_converted);
        out.put(state.flow.overfill_external);
        out.put(state.flow.flow_remainder);
        out.put(state.flow.contact_loss);
        out.put(state.flow.relief_cells);
    }
    if (inertial_enabled_) {
        const auto& s=inertial_ledger_;
        for (const auto v:{s.gravity_y,s.impulse_x,s.impulse_y,s.loss,s.support,s.remainder,
                          s.retired_x,s.retired_y,s.external_x,s.external_y,s.external_speed}) out.put(v);
        for (const auto v:{s.updates,s.unit_moves,s.density_swaps,s.contacts,s.rests,s.velocity_retired,s.maximum_read_reach,s.maximum_write_reach}) out.put(v);
    }
    const auto digest = Sha256::of(out.bytes);
    out.bytes.insert(out.bytes.end(), digest.begin(), digest.end());
    return std::move(out.bytes);
}

std::unique_ptr<World> World::restore_physical_state(const WorldConfig& execution, std::span<const std::uint8_t> bytes) {
    if (bytes.size() < 8U + 32U) refuse_state("payload is too short");
    const auto body = bytes.first(bytes.size() - 32U);
    const auto digest = Sha256::of(body);
    if (!std::equal(digest.begin(), digest.end(), bytes.end() - 32)) refuse_state("integrity digest mismatch");
    StateReader in(body);
    if (in.get<std::uint32_t>() != kPhysicalStateMagic) refuse_state("bad magic");
    const auto format=in.get<std::uint32_t>();
    if (format != 2U && format != 3U) refuse_state("unknown format version");
    // WorldConfig contains the fixed transport catalogue. Keep preparation's
    // copy off the caller/decoder stack (notably MSVC debug's 1 MiB default).
    auto config_owner = std::make_unique<WorldConfig>(execution);
    auto& config = *config_owner;
    config.chunk_size = in.get<std::int32_t>();
    config.activity_block_size = in.get<std::int32_t>();
    config.scheduling_core_size = in.get<std::int32_t>();
    config.maximum_rule_radius = in.get<std::int32_t>();
    config.sleep_after_quiet_ticks = in.get<std::uint32_t>();
    config.ambient_temperature = in.get<std::int16_t>();
    const auto backend = in.get<std::uint8_t>();
    if (backend > static_cast<std::uint8_t>(SimulationBackend::PhasedInPlace)) refuse_state("unknown backend");
    config.backend = static_cast<SimulationBackend>(backend);
    config.maximum_explosion_radius = in.get<std::int32_t>();
    const auto disable_powder_exchange = in.get<std::uint8_t>();
    if (disable_powder_exchange > 1U) refuse_state("invalid powder exchange option");
    config.physics_diagnostics.disable_powder_exchange_targets = disable_powder_exchange != 0U;
    config.physics_diagnostics.mercury_viscosity = in.get<std::int16_t>();
    config.interaction_policy.downward_support_cells = in.get<decltype(config.interaction_policy.downward_support_cells)>();
    config.interaction_policy.side_support_cells = in.get<decltype(config.interaction_policy.side_support_cells)>();
    config.interaction_policy.mercury_exchange_period = in.get<decltype(config.interaction_policy.mercury_exchange_period)>();
    const auto mass_bits = in.get<std::uint8_t>();
    const auto coherence = in.get<std::uint8_t>();
    const auto rest = in.get<std::uint8_t>();
    if (mass_bits < 3U || mass_bits > 8U || coherence > 12U ||
        rest != static_cast<std::uint8_t>(WaterRestPolicy::CurrentNormalizedV1))
        refuse_state("unsupported Water semantics");
    config.water_experiment_policy = WaterExperimentPolicy(mass_bits, coherence, WaterRestPolicy::CurrentNormalizedV1);
    const auto transport_words = in.get<std::uint32_t>();
    if (transport_words != 0U && transport_words != TransportPolicy::packed_size)
        refuse_state("transport profile length");
    std::vector<std::int32_t> transport(transport_words);
    for (auto& word : transport) word = in.get<std::int32_t>();
    config.transport_policy = transport.empty() ? TransportPolicy{} : TransportPolicy::unpack(transport);
    const auto envelope_words = in.get<std::uint32_t>();
    if (envelope_words > 4096U) refuse_state("liquid policy envelope too large");
    std::vector<std::int32_t> envelope(envelope_words);
    for (auto& word : envelope) word = in.get<std::int32_t>();
    auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(envelope));
    if (!decoded.accepted()) throw LiquidPolicyRefused(decoded.refusal);
    config.liquid_solver_policy = *decoded.policy;
    const bool has_inertial=std::any_of(config.liquid_solver_policy.assignments().begin(),
        config.liquid_solver_policy.assignments().end(),[](const auto& a) {
            return a.family==LiquidSolverFamily::InertialCellularV1;
        });
    if (has_inertial != (format==3U)) refuse_state("IN requires its explicit CYPS3 format");
    if (has_inertial) {
        if (in.get<std::uint16_t>() != InertialParameters::kVersion) refuse_state("unknown IN state contract");
        for (const auto expected:inertial_extension_identity(inertial_parameters_for_policy(config.liquid_solver_policy)))
            if (in.get<std::uint8_t>() != expected) refuse_state("unknown IN parameter/state identity");
    }
    config.settled_discovery_enabled = false;
    config.settled_region_connectivity_enabled = false;
    auto world = std::make_unique<World>(config);
    auto& w = *world;
    const auto maximum_water = w.config_.water_experiment_policy.maximum();
    const auto coherence_limit = w.config_.water_experiment_policy.coherence_ticks();

    w.tick_index_ = in.get<std::uint64_t>();
    w.completed_tick_index_ = in.get<std::uint64_t>();
    if (w.completed_tick_index_ != w.tick_index_) refuse_state("not a completed tick boundary");
    w.update_epoch_ = in.get<std::uint8_t>();
    w.hard_surface_revision_ = in.get<std::uint64_t>();
    w.liquid_surface_adhesion_enabled_ = in.get<std::uint8_t>() != 0U;
    if (in.get<std::uint8_t>() != 0U) {
        RectI64 region;
        region.x = in.get<std::int64_t>();
        region.y = in.get<std::int64_t>();
        region.width = in.get<std::int64_t>();
        region.height = in.get<std::int64_t>();
        w.set_simulation_region(region);
    }
    if (in.get<std::uint8_t>() != 0U) {
        CoreRange applied{};
        applied.min_x = in.get<std::int64_t>();
        applied.min_y = in.get<std::int64_t>();
        applied.max_x = in.get<std::int64_t>();
        applied.max_y = in.get<std::int64_t>();
        w.applied_core_region_ = applied;
    }
    const auto events = in.get<std::uint32_t>();
    if (events > w.config_.deferred_event_capacity) refuse_state("too many pending events");
    for (std::uint32_t i = 0; i < events; ++i) {
        ExplosionCommand event;
        event.x = in.get<std::int64_t>();
        event.y = in.get<std::int64_t>();
        event.radius = in.get<std::int32_t>();
        event.collapse_strength = in.get<std::uint8_t>();
        // Discovery is disabled for this unexposed candidate. Reuse ingress's
        // exact radius/capacity/R+2 coordinate checks before admitting the event.
        if (!w.queue_explosion(event.x, event.y, event.radius, event.collapse_strength))
            refuse_state("bad pending event");
    }
    const auto chunk_count = in.get<std::uint32_t>();
    if (chunk_count > w.config_.maximum_chunk_count) refuse_state("chunk count exceeds capacity");
    const auto size = static_cast<std::int64_t>(w.config_.chunk_size);
    const auto blocks_per_axis = (w.config_.chunk_size + w.config_.activity_block_size - 1) / w.config_.activity_block_size;
    std::vector<std::pair<std::uint32_t, std::uint64_t>> labelled;  // compartment id, cells
    for (std::uint32_t c = 0; c < chunk_count; ++c) {
        ChunkCoord coord;
        coord.x = in.get<std::int64_t>();
        coord.y = in.get<std::int64_t>();
        constexpr auto lo = std::numeric_limits<std::int64_t>::min();
        constexpr auto hi = std::numeric_limits<std::int64_t>::max();
        if (coord.x < lo / size || coord.y < lo / size || coord.x > hi / size || coord.y > hi / size)
            refuse_state("chunk coordinate overflow");
        if (w.find_chunk(coord) != nullptr) refuse_state("duplicate chunk");
        const auto flags = in.get<std::uint8_t>();
        if ((flags & ~(format==3U ? 7U:3U)) != 0U) refuse_state("unknown chunk flags");
        if (((flags & 4U)!=0U)!=w.inertial_enabled_) refuse_state("IN sidecar presence mismatch");
        if (((flags & 2U) != 0U) != (w.pressure_ != nullptr)) refuse_state("pressure sidecar presence mismatch");
        auto& chunk = w.ensure_chunk(coord);
        if (in.get<std::uint32_t>() != static_cast<std::uint32_t>(blocks_per_axis * blocks_per_axis))
            refuse_state("activity block count mismatch");
        bool any_active = false;
        for (auto& block : chunk.activity_blocks) {
            block.active = in.get<std::uint8_t>() != 0U;
            block.quiet_ticks = in.get<std::uint32_t>();
            block.next_interaction_tick = in.get<std::uint64_t>();
            any_active = any_active || block.active;
        }
        chunk.active = any_active;
        chunk.quiet_ticks = any_active ? 0U : w.config_.sleep_after_quiet_ticks;
        std::size_t non_empty = 0;
        for (auto& cell : chunk.cells) {
            const auto material = in.get<std::uint16_t>();
            const auto a = in.get<std::uint16_t>();
            const auto b = in.get<std::uint8_t>();
            const auto epoch = in.get<std::uint8_t>();
            if (!valid_material(material)) refuse_state("invalid material");
            const auto value = static_cast<Material>(material);
            if (value == Material::Water && (a == 0U || a > maximum_water || b > coherence_limit))
                refuse_state("Water state outside the experiment policy");
            if (value == Material::Water && w.whole_cell_water_enabled() && a != maximum_water)
                refuse_state("whole-cell Water requires maximum() quantity");
            if (value != Material::Water && a > 255U) refuse_state("byte state out of domain");
            cell = Chunk::Cell::for_material(value);
            cell.set_state_a(a);
            cell.set_state_b(b);
            if (cell.state_b_value() != b) refuse_state("state_b outside the material domain");
            cell.set_epoch(epoch);
            if (value != Material::Empty) ++non_empty;
        }
        chunk.non_empty_cell_count = non_empty;
        if ((flags & 1U) != 0U) {
            w.ensure_temperature_field(chunk);
            for (auto& value : *chunk.temperatures) value = in.get<std::int16_t>();
        }
        if ((flags & 2U) != 0U) {
            for (std::size_t index = 0; index < chunk.pressure->cells.size(); ++index) {
                auto& side = chunk.pressure->cells[index];
                side.overfill = in.get<std::uint16_t>();
                side.flow = in.get<std::int16_t>();
                side.gas = in.get<std::uint32_t>();
                const auto& cell = chunk.cells[index];
                const auto material = cell.material_value();
                if (side.overfill != 0U && (material != Material::Water || cell.state_a_value() != maximum_water ||
                                            side.overfill > maximum_water))
                    refuse_state("overfill outside its invariant");
                if (side.flow != 0 && (material != Material::Water ||
                                       side.flow > PressureFlowParameters::kFlowScale ||
                                       side.flow < -PressureFlowParameters::kFlowScale))
                    refuse_state("flow outside its invariant");
                if (side.gas != 0U && material != Material::Empty) refuse_state("gas label on a non-Empty cell");
                if (side.gas != 0U && side.gas != kAtmosphereLabel && side.gas != kVacuumLabel) {
                    if (labelled.empty() || labelled.back().first != side.gas) {
                        auto found = std::find_if(labelled.begin(), labelled.end(),
                                                  [&](const auto& item) { return item.first == side.gas; });
                        if (found == labelled.end()) labelled.emplace_back(side.gas, 1U);
                        else ++found->second;
                    } else {
                        ++labelled.back().second;
                    }
                }
            }
        }
        if ((flags&4U)!=0U) for (std::size_t i=0;i<chunk.inertial->size();++i) {
            auto& s=(*chunk.inertial)[i];
            s.vx=in.get<std::int16_t>(); s.vy=in.get<std::int16_t>();
            s.ax=in.get<std::int8_t>(); s.ay=in.get<std::int8_t>();
            if ((s.vx || s.vy || s.ax || s.ay) && !w.inertial_family(chunk.cells[i].material_value()))
                refuse_state("IN motion on another family");
            if (s.vx < -InertialParameters::kVmax || s.vx > InertialParameters::kVmax ||
                s.vy < 0 || s.vy > InertialParameters::kVmax ||
                std::abs(s.ax)>=InertialParameters::kQ || std::abs(s.ay)>=InertialParameters::kQ)
                refuse_state("IN motion outside its declared domain");
        }
        chunk.dirty = true;
        chunk.dirty_min_x = 0;
        chunk.dirty_min_y = 0;
        chunk.dirty_max_x = w.config_.chunk_size - 1;
        chunk.dirty_max_y = w.config_.chunk_size - 1;
    }
    try { w.quantity_ = quantity_read(in); }
    catch (const std::exception&) { refuse_state("invalid quantity ledger encoding"); }
    const bool has_pressure = in.get<std::uint8_t>() != 0U;
    if (has_pressure != (w.pressure_ != nullptr)) refuse_state("pressure section presence mismatch");
    if (has_pressure) {
        auto& state = *w.pressure_;
        state.next_id = in.get<std::uint32_t>();
        if (state.next_id == 0U || state.next_id > kVacuumLabel)
            refuse_state("next compartment id outside its allocated/exhausted domain");
        state.topology_revision = in.get<std::uint64_t>();
        const auto get_compartment = [&in]() {
            GasCompartmentSnapshot c;
            c.id = in.get<std::uint32_t>();
            c.generation = in.get<std::uint32_t>();
            c.parent_count = in.get<std::uint8_t>();
            for (auto& parent : c.parents) parent = in.get<std::uint32_t>();
            c.amount = in.get<std::uint64_t>();
            c.volume = in.get<std::uint64_t>();
            c.anchor_x = in.get<std::int64_t>();
            c.anchor_y = in.get<std::int64_t>();
            c.created_tick = in.get<std::uint64_t>();
            c.revision = in.get<std::uint64_t>();
            c.gauge = in.get<std::int64_t>();
            if (c.parent_count > c.parents.size()) refuse_state("too many compartment parents");
            return c;
        };
        const auto count = in.get<std::uint32_t>();
        if (count > PressureFlowParameters::kCompartmentCapacity) refuse_state("compartment count exceeds capacity");
        std::uint64_t live = 0;
        for (std::uint32_t i = 0; i < count; ++i) {
            const auto c = get_compartment();
            if (c.id == 0U || c.id >= state.next_id || c.id >= kVacuumLabel ||
                (!state.compartments.empty() && state.compartments.back().id >= c.id))
                refuse_state("compartment ids are not unique, ascending and allocated");
            // volume is the value resolved at the last tick entry; kernels may
            // have moved labelled cells since, so it is not re-derived here.
            if (c.volume == 0U || c.volume > PressureFlowParameters::kCompartmentVolumeLimit)
                refuse_state("compartment volume out of bound");
            if (c.amount > (std::uint64_t{1} << 32U)) refuse_state("compartment amount out of bound");
            PressureState::Compartment made;
            made.id = c.id;
            made.generation = c.generation;
            made.parents = c.parents;
            made.parent_count = c.parent_count;
            made.amount = c.amount;
            made.volume = c.volume;
            made.anchor_x = c.anchor_x;
            made.anchor_y = c.anchor_y;
            made.created_tick = c.created_tick;
            made.revision = c.revision;
            made.gauge = c.gauge;
            live += c.amount;
            state.compartments.push_back(made);
        }
        for (const auto& [id, cells] : labelled) {
            (void)cells;
            if (state.find(id) == nullptr) refuse_state("gas label without a live compartment");
        }
        const auto history = in.get<std::uint32_t>();
        const auto history_next = in.get<std::uint32_t>();
        if (history > PressureFlowParameters::kHistoryCapacity ||
            history_next >= PressureFlowParameters::kHistoryCapacity)
            refuse_state("gas history out of bound");
        for (std::uint32_t i = 0; i < history; ++i) {
            GasHistoryRecord record;
            record.compartment = get_compartment();
            const auto reason = in.get<std::uint8_t>();
            if (reason < 1U || reason > 4U) refuse_state("unknown gas retire reason");
            record.reason = static_cast<GasRetireReason>(reason);
            record.successor_count = in.get<std::uint8_t>();
            if (record.successor_count > record.successors.size()) refuse_state("too many successors");
            for (auto& successor : record.successors) successor = in.get<std::uint32_t>();
            record.tick = in.get<std::uint64_t>();
            state.history.push_back(record);
        }
        state.history_next = history_next;
        auto& gas = state.gas;
        for (auto* value : {&gas.created, &gas.absorbed, &gas.vented, &gas.collapsed, &gas.merges, &gas.splits,
                            &gas.creations, &gas.vents, &gas.collapses, &gas.amount_live})
            *value = in.get<std::uint64_t>();
        const auto maximum = std::numeric_limits<std::uint64_t>::max();
        if (gas.amount_live != live || gas.absorbed > maximum - gas.created ||
            gas.vented > maximum - gas.amount_live ||
            gas.collapsed > maximum - (gas.amount_live + gas.vented) ||
            gas.amount_live + gas.vented + gas.collapsed != gas.created + gas.absorbed)
            refuse_state("gas ledger does not close");
        state.flow.overfill_converted = in.get<std::uint64_t>();
        state.flow.overfill_external = in.get<std::uint64_t>();
        state.flow.flow_remainder = in.get<std::int64_t>();
        state.flow.contact_loss = in.get<std::uint64_t>();
        state.flow.relief_cells = in.get<std::uint64_t>();
    } else if (!labelled.empty()) {
        refuse_state("gas labels without a pressure family");
    }
    if (format==3U) {
        auto& s=w.inertial_ledger_;
        for (auto* v:{&s.gravity_y,&s.impulse_x,&s.impulse_y,&s.loss,&s.support,&s.remainder,
                     &s.retired_x,&s.retired_y,&s.external_x,&s.external_y,&s.external_speed}) *v=in.get<std::int64_t>();
        for (auto* v:{&s.updates,&s.unit_moves,&s.density_swaps,&s.contacts,&s.rests,&s.velocity_retired,&s.maximum_read_reach,&s.maximum_write_reach})
            *v=in.get<std::uint64_t>();
        if (s.gravity_y<0 || s.loss<0 || s.support<0 || s.support>s.loss ||
            s.maximum_read_reach>3U || s.maximum_write_reach>2U)
            refuse_state("IN ledger outside its declared domain");
    }
    if (!in.done()) refuse_state("trailing bytes");
    try { w.validate_inertial_ledger(); }
    catch (const std::exception&) { refuse_state("invalid IN ledger"); }
    try { w.validate_quantity_ledger(true); }
    catch (const std::exception&) { refuse_state("invalid quantity ledger"); }
    return world;
}
