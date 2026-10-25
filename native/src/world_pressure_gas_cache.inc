// Derived owner-only BFS summaries. The global reference seed census, identity
// reducer and relabel operator remain authoritative and keep their exact order.
void World::prepare_pressure_gas_cache() {
    if (pressure_->cache == nullptr) return;
    auto& cache = *pressure_->cache;
    auto& work = pressure_->optimization;
    if (!cache.complete || cache.membership_dirty) cache.gas_ready = false;
    if (cache.gas_ready && !cache.gas_dirty_chunks.empty() &&
        cache.gas_components.size() > cache.config.gas_invalidation_pair_budget / cache.gas_dirty_chunks.size()) {
        cache.gas_ready = false;
        ++work.gas_budget_fallbacks;
    }
    if (cache.gas_ready) {
        for (auto& component : cache.gas_components) {
            if (!component.valid) continue;
            ++work.gas_component_proof_checks;
            bool dirty = pressure_->find(component.id) == nullptr;
            const auto low = [](std::int64_t v) { return v == std::numeric_limits<std::int64_t>::min() ? v : v - 1; };
            const auto high = [](std::int64_t v) { return v == std::numeric_limits<std::int64_t>::max() ? v : v + 1; };
            for (const auto changed : cache.gas_dirty_chunks) {
                ++work.gas_invalidation_pairs;
                dirty = dirty || (changed.x >= low(component.min_chunk_x) && changed.x <= high(component.max_chunk_x) &&
                                  changed.y >= low(component.min_chunk_y) && changed.y <= high(component.max_chunk_y));
            }
            if (dirty) { component.valid = false; ++work.gas_component_invalidations; }
        }
    }
    for (const auto changed : cache.gas_dirty_chunks)
        if (auto* chunk = find_chunk(changed)) chunk->pressure->gas_dirty_queued = false;
    cache.gas_dirty_chunks.clear();
}

bool World::replay_pressure_gas_region(std::int64_t x, std::int64_t y,
                                      std::uint32_t current, std::uint32_t stamp, bool& retry_requested) {
    auto* cache = pressure_->cache.get();
    if (cache == nullptr || !cache->gas_ready) return false;
    const auto at = address(x, y);
    const auto* seed_chunk = find_chunk(at.chunk);
    if (seed_chunk == nullptr) return false;
    const auto label = seed_chunk->pressure->cells[at.index].gas;
    auto* component = cache->gas_component(label);
    if (component == nullptr || !component->valid) return false;
    const auto stale = [&] { retry_requested = true; return false; };
    ++pressure_->optimization.gas_component_proof_checks;
    const auto* old = pressure_->find(label);
    if (old == nullptr || old->volume != component->count || old->anchor_x != component->anchor_x ||
        old->anchor_y != component->anchor_y || component->count == 0U ||
        component->first > cache->gas_members.size() || component->count > cache->gas_members.size() - component->first)
        return stale();
    bool contains_seed = false;
    const auto size = static_cast<std::size_t>(config_.chunk_size);
    // Validate the complete recorded member range before stamping any member.
    for (std::size_t i = 0; i < component->count; ++i) {
        ++pressure_->optimization.gas_member_validations;
        const auto member = cache->gas_members[component->first + i];
        if (member.chunk_slot >= cache->column_order.size()) return stale();
        const auto coord = cache->column_order[member.chunk_slot];
        const auto* chunk = find_chunk(coord);
        if (chunk == nullptr || chunk->pressure->gas_chunk_slot != member.chunk_slot ||
            member.cell_index >= chunk->cells.size()) return stale();
        const auto mx = coord.x * config_.chunk_size + static_cast<std::int64_t>(member.cell_index % size);
        const auto my = coord.y * config_.chunk_size + static_cast<std::int64_t>(member.cell_index / size);
        if (chunk->cells[member.cell_index].material_value() != Material::Empty ||
            chunk->pressure->cells[member.cell_index].gas != label || transient_obstacle_at(mx, my) != 0U ||
            (chunk->pressure->visit[member.cell_index] & 0xFFFF0000U) == stamp)
            return stale();
        contains_seed = contains_seed || (coord == at.chunk && member.cell_index == at.index);
    }
    if (!contains_seed) return stale();
    if (pressure_->overlaps.size() >= PressureState::kOverlapCapacity)
        throw std::runtime_error("pressure gas overlap capacity exhausted");
    auto& region = pressure_->regions[current];
    region.volume = component->count;
    region.lowest_x = component->anchor_x; region.lowest_y = component->anchor_y;
    region.first_overlap = static_cast<std::uint32_t>(pressure_->overlaps.size());
    pressure_->overlaps.push_back({static_cast<std::uint32_t>(old - pressure_->compartments.data()),
                                  component->count, PressureState::kNone});
    for (std::size_t i = 0; i < component->count; ++i) {
        const auto member = cache->gas_members[component->first + i];
        find_chunk(cache->column_order[member.chunk_slot])->pressure->visit[member.cell_index] = stamp | current;
        ++pressure_->optimization.gas_member_stamps;
    }
    pressure_->diagnostics.gas_visited += component->count;
    ++pressure_->optimization.gas_component_reuses;
    return true;
}

void World::rebuild_pressure_gas_cache(std::uint32_t stamp) {
    auto* cache = pressure_->cache.get();
    if (cache == nullptr || !pressure_->gas_fixed_point || !cache->complete || cache->membership_dirty) return;
    cache->gas_ready = false;
    cache->gas_components.clear(); cache->gas_members.clear();
    auto& work = pressure_->optimization;
    const auto fail = [&] {
        cache->gas_components.clear(); cache->gas_members.clear();
        ++work.gas_capacity_fallbacks;
    };
    if (cache->column_order.size() >= std::numeric_limits<std::uint32_t>::max()) { fail(); return; }
    std::size_t total = 0;
    for (std::size_t r = 0; r < pressure_->regions.size(); ++r) {
        ++work.gas_component_proof_checks;
        const auto& region = pressure_->regions[r];
        if (region.atmosphere || region.first_node != PressureState::kNone || region.fresh_cells != 0U ||
            region.atmosphere_cells != 0U || region.label == 0U || region.label >= kVacuumLabel ||
            region.volume == 0U || region.volume > PressureFlowParameters::kCompartmentVolumeLimit ||
            region.first_overlap == PressureState::kNone) continue;
        const auto& overlap = pressure_->overlaps[region.first_overlap];
        if (overlap.next != PressureState::kNone || overlap.count != region.volume ||
            overlap.compartment >= pressure_->next_compartments.size() ||
            pressure_->next_compartments[overlap.compartment].id != region.label) continue;
        const auto* live = pressure_->find(region.label);
        if (live == nullptr || live->volume != region.volume || live->anchor_x != region.lowest_x ||
            live->anchor_y != region.lowest_y) continue;
        if (cache->gas_components.size() >= PressureFlowParameters::kCompartmentCapacity ||
            region.volume > cache->gas_member_limit - total) { fail(); return; }
        PressureCache::GasComponent component;
        component.id = region.label; component.source_region = static_cast<std::uint32_t>(r);
        component.count = static_cast<std::size_t>(region.volume);
        component.anchor_x = region.lowest_x; component.anchor_y = region.lowest_y;
        total += component.count;
        cache->gas_components.push_back(component);
    }
    std::sort(cache->gas_components.begin(), cache->gas_components.end(), [](const auto& a, const auto& b) { return a.id < b.id; });
    std::size_t offset = 0;
    for (std::size_t i = 0; i < cache->gas_components.size(); ++i) {
        auto& component = cache->gas_components[i];
        if (i != 0U && cache->gas_components[i - 1U].id == component.id) { fail(); return; }
        component.first = offset; offset += component.count;
    }
    cache->gas_members.resize(total);
    work.gas_member_initializations += total;
    for (std::size_t slot = 0; slot < cache->column_order.size(); ++slot) {
        const auto coord = cache->column_order[slot]; const auto* chunk = find_chunk(coord);
        if (chunk == nullptr || chunk->pressure->gas_chunk_slot != slot) { fail(); return; }
        for (std::size_t i = 0; i < chunk->cells.size(); ++i) {
            ++work.gas_cache_build_cells;
            const auto mark = chunk->pressure->visit[i];
            if ((mark & 0xFFFF0000U) != stamp) continue;
            auto* component = cache->gas_component(chunk->pressure->cells[i].gas);
            if (component == nullptr) continue;
            if (chunk->cells[i].material_value() != Material::Empty || (mark & 0xFFFFU) != component->source_region ||
                component->built == component->count) { fail(); return; }
            if (component->built == 0U) {
                component->min_chunk_x = component->max_chunk_x = coord.x;
                component->min_chunk_y = component->max_chunk_y = coord.y;
            } else {
                component->min_chunk_x = std::min(component->min_chunk_x, coord.x);
                component->max_chunk_x = std::max(component->max_chunk_x, coord.x);
                component->min_chunk_y = std::min(component->min_chunk_y, coord.y);
                component->max_chunk_y = std::max(component->max_chunk_y, coord.y);
            }
            cache->gas_members[component->first + component->built++] =
                {static_cast<std::uint32_t>(slot), static_cast<std::uint32_t>(i)};
            ++work.gas_member_builds;
        }
    }
    for (const auto& component : cache->gas_components)
        if (component.built != component.count) { fail(); return; }
    cache->gas_ready = true;
    ++work.gas_cache_builds;
}
