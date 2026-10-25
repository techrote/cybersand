// Owner-only preparation/invalidation. No renderer-owned dirty bounds are read.
// Existing producer JobEffects rectangles are reduced at every phase barrier.

namespace {
std::uint64_t certificate_budget_add(std::uint64_t a, std::uint64_t b, bool& overflow) noexcept {
    if (a>std::numeric_limits<std::uint64_t>::max()-b) {
        overflow=true; return std::numeric_limits<std::uint64_t>::max();
    }
    return a+b;
}
std::uint64_t certificate_budget_multiply(std::uint64_t value, std::uint64_t weight, bool& overflow) noexcept {
    if (value>std::numeric_limits<std::uint64_t>::max()/weight) {
        overflow=true; return std::numeric_limits<std::uint64_t>::max();
    }
    return value*weight;
}
void certificate_counter_add(std::uint64_t& value, std::uint64_t amount) noexcept {
    bool overflow=false; value=certificate_budget_add(value,amount,overflow);
}
}

void World::account_pressure_certificate_work() noexcept {
    auto& cache=*pressure_->cache; auto& work=pressure_->optimization;
    // Source instrumentation predates this admission layer. A wrapped or
    // saturated lifetime observation is uncertainty, never free work.
    const auto uncertain=[](std::uint64_t value,std::uint64_t prior) {
        return value<prior || value==std::numeric_limits<std::uint64_t>::max();
    };
    bool overflow=uncertain(work.certificate_invalidation_cells,cache.certificate_accounted_invalidations) ||
        uncertain(work.certificate_attempts,cache.certificate_accounted_attempts) ||
        uncertain(work.certificate_reuses,cache.certificate_accounted_reuses) ||
        uncertain(work.certificate_saved_calls,cache.certificate_accounted_saved);
    const auto invalidations=work.certificate_invalidation_cells-cache.certificate_accounted_invalidations;
    const auto attempts=work.certificate_attempts-cache.certificate_accounted_attempts;
    const auto reuses=work.certificate_reuses-cache.certificate_accounted_reuses;
    const auto saved=work.certificate_saved_calls-cache.certificate_accounted_saved;
    cache.certificate_accounted_invalidations=work.certificate_invalidation_cells;
    cache.certificate_accounted_attempts=work.certificate_attempts;
    cache.certificate_accounted_reuses=work.certificate_reuses;
    cache.certificate_accounted_saved=work.certificate_saved_calls;
    auto charge=certificate_budget_multiply(invalidations,kPressureCertificateInvalidationCharge,overflow);
    charge=certificate_budget_add(charge,certificate_budget_multiply(attempts,kPressureCertificateProofCharge,overflow),overflow);
    charge=certificate_budget_add(charge,certificate_budget_multiply(reuses,kPressureCertificateReuseCharge,overflow),overflow);
    const auto credit=certificate_budget_multiply(saved,kPressureCertificateSavedCallCredit,overflow);
    certificate_counter_add(work.certificate_work_charged,charge);
    certificate_counter_add(work.certificate_work_credited,credit);
    if (cache.certificate_window_active) {
        cache.certificate_window_charge=certificate_budget_add(cache.certificate_window_charge,charge,overflow);
        cache.certificate_window_credit=certificate_budget_add(cache.certificate_window_credit,credit,overflow);
        cache.certificate_window_overflow=cache.certificate_window_overflow || overflow;
        if (cache.certificate_window_overflow) {
            // Arithmetic uncertainty can only reject a window, never admit it.
            cache.certificate_window_charge=std::numeric_limits<std::uint64_t>::max();
            cache.certificate_window_credit=0;
        }
    }
}

void World::prepare_pressure_certificates() noexcept {
    if (pressure_==nullptr || pressure_->cache==nullptr || !pressure_->cache->dormant) return;
    auto& cache=*pressure_->cache; auto& work=pressure_->optimization;
    const auto begin_window=[&] {
        cache.certificate_window_active=true; cache.certificate_window_overflow=false;
        cache.certificate_window_ticks=0; cache.certificate_window_charge=0; cache.certificate_window_credit=0;
    };
    // A continuing admitted layer owns maintenance between completed windows.
    if (!cache.certificate_window_active && cache.certificate_layer_enabled) begin_window();
    account_pressure_certificate_work();
    cache.certificate_water_calls_begin=work.water_material_calls;
    cache.certificate_tick_eligible=false;
    if (!cache.complete || !cache.use_heads) {
        cache.certificate_layer_enabled=false; cache.certificate_contents_cold=true;
        certificate_counter_add(work.certificate_unavailable_ticks,1); return;
    }
    if (cache.certificate_suspend_remaining!=0U) {
        --cache.certificate_suspend_remaining;
        cache.certificate_layer_enabled=false; cache.certificate_contents_cold=true;
        certificate_counter_add(work.certificate_suspended_ticks,1); return;
    }
    // Sleeping is already cheap. An off/cold layer requires an actual prior
    // Water-material visit: the first newly woken tick always runs ordinary.
    if ((!cache.certificate_layer_enabled || cache.certificate_contents_cold) && cache.certificate_prior_water_calls==0U) {
        cache.certificate_layer_enabled=false; return;
    }
    if (!cache.certificate_window_active) begin_window();
    if (!cache.certificate_layer_enabled) certificate_counter_add(work.certificate_layer_activations,1);
    cache.certificate_layer_enabled=true; cache.certificate_tick_eligible=true;
    if (cache.certificate_contents_cold) {
        // Only admission may touch all certificate storage. Every byte is
        // charged before a worker can observe any old Valid tag.
        std::uint64_t cells=0;
        for (auto& [coord,chunk] : chunks_) {
            (void)coord; auto& certificates=chunk->pressure->rest_certificate;
            std::fill(certificates.begin(),certificates.end(),PressureChunk::kCertificateWarmup);
            bool overflow=false; cells=certificate_budget_add(cells,certificates.size(),overflow);
            if (overflow) cache.certificate_window_overflow=true;
        }
        certificate_counter_add(work.certificate_invalidation_cells,cells);
        certificate_counter_add(work.certificate_cold_reset_cells,cells);
        certificate_counter_add(work.certificate_cold_resets,1);
        cache.certificate_contents_cold=false;
    }
}

void World::finish_pressure_certificate_tick() noexcept {
    if (pressure_==nullptr || pressure_->cache==nullptr || !pressure_->cache->dormant) return;
    auto& cache=*pressure_->cache; auto& work=pressure_->optimization;
    // Called only after a successful whole tick and every worker reduction.
    cache.certificate_prior_water_calls=work.water_material_calls-cache.certificate_water_calls_begin;
    account_pressure_certificate_work();
    if (!cache.certificate_tick_eligible || !cache.certificate_layer_enabled) return;
    if (++cache.certificate_window_ticks<kPressureCertificateTrialTicks) return;
    cache.certificate_last_window_charge=cache.certificate_window_charge;
    cache.certificate_last_window_credit=cache.certificate_window_credit;
    certificate_counter_add(work.certificate_work_windows,1);
    cache.certificate_window_active=false;
    if (cache.certificate_window_overflow || cache.certificate_window_charge>cache.certificate_window_credit) {
        cache.certificate_layer_enabled=false; cache.certificate_contents_cold=true;
        cache.certificate_suspend_remaining=kPressureCertificateSuspensionTicks;
        certificate_counter_add(work.certificate_work_suspensions,1);
    }
}

void World::rebuild_pressure_index() {
    auto& cache = *pressure_->cache;
    cache.gas_ready = false;
    cache.certificate_contents_cold=true; cache.certificate_layer_enabled=false;
    cache.gas_dirty_chunks.clear();
    for (auto& [coord, chunk] : chunks_) {
        (void)coord;
        chunk->pressure->gas_dirty_queued = false;
        ++pressure_->optimization.gas_index_chunks;
    }
    if (chunks_.size() > cache.capacity) {
        cache.complete = false;
        cache.status = PressureOptimizationStatus::ReferenceCapacityFallback;
        return;
    }
    cache.column_order.clear(); cache.row_order.clear();
    cache.columns.clear(); cache.rows.clear();
    cache.dirty_columns.clear(); cache.dirty_rows.clear();
    for (const auto& [coord, chunk] : chunks_) {
        cache.column_order.push_back(coord);
    }
    std::sort(cache.column_order.begin(), cache.column_order.end(), [](auto a, auto b) {
        return a.x != b.x ? a.x < b.x : a.y < b.y;
    });
    cache.row_order.assign(cache.column_order.begin(), cache.column_order.end());
    std::sort(cache.row_order.begin(), cache.row_order.end(), [](auto a, auto b) {
        return a.y != b.y ? a.y < b.y : a.x < b.x;
    });
    const auto build = [&](bool column) {
        auto& order = column ? cache.column_order : cache.row_order;
        auto& groups = column ? cache.columns : cache.rows;
        std::size_t first = 0;
        while (first < order.size()) {
            const auto key = column ? order[first].x : order[first].y;
            auto last = first + 1U;
            while (last < order.size() && (column ? order[last].x : order[last].y) == key) ++last;
            PressureCache::Group group;
            group.key = key; group.first = first; group.last = last;
            const auto id = groups.size();
            groups.push_back(group);
            for (auto i = first; i < last; ++i) {
                auto& part = *find_chunk(order[i])->pressure;
                (column ? part.column_group : part.row_group) = id;
            }
            first = last;
        }
    };
    build(true); build(false);
    for (std::size_t i = 0; i < cache.column_order.size(); ++i) {
        find_chunk(cache.column_order[i])->pressure->gas_chunk_slot = i < std::numeric_limits<std::uint32_t>::max()
            ? static_cast<std::uint32_t>(i) : std::numeric_limits<std::uint32_t>::max();
        ++pressure_->optimization.gas_index_chunks;
    }
    cache.complete = true; cache.membership_dirty = false;
    if (++cache.incarnation == 0U) ++cache.incarnation;
    for (std::size_t i = 0; i < cache.columns.size(); ++i) cache.mark(true, i, 0, config_.chunk_size - 1);
    for (std::size_t i = 0; i < cache.rows.size(); ++i) cache.mark(false, i, 0, config_.chunk_size - 1);
    ++pressure_->optimization.index_rebuilds;
}

void World::invalidate_pressure_certificates(ChunkCoord coord, std::int32_t min_x, std::int32_t min_y,
                                            std::int32_t max_x, std::int32_t max_y) {
    if (pressure_ == nullptr || pressure_->cache == nullptr || !pressure_->cache->dormant) return;
    auto& cache=*pressure_->cache;
    if (!cache.certificate_layer_enabled || cache.certificate_contents_cold || !cache.complete || !cache.use_heads) {
        cache.certificate_contents_cold=true;
        return;
    }
    const auto size = config_.chunk_size;
    // Every certified no-op reads at most two cells from its owner. The chunk
    // size is at least eight, so the touched old/new union spans at most 3x3
    // chunks. Serial reduction makes this independent of worker interleaving.
    for (std::int32_t dy = -1; dy <= 1; ++dy) {
        const auto first_y = std::max(0, min_y - 2 - dy * size);
        const auto last_y = std::min(size - 1, max_y + 2 - dy * size);
        if (first_y > last_y) continue;
        for (std::int32_t dx = -1; dx <= 1; ++dx) {
            const auto first_x = std::max(0, min_x - 2 - dx * size);
            const auto last_x = std::min(size - 1, max_x + 2 - dx * size);
            if (first_x > last_x) continue;
            auto* chunk = find_chunk({coord.x + dx, coord.y + dy});
            if (chunk == nullptr) continue;
            auto& certificates = chunk->pressure->rest_certificate;
            for (auto y = first_y; y <= last_y; ++y) {
                const auto start = static_cast<std::size_t>(y) * static_cast<std::size_t>(size);
                std::fill(certificates.begin() + static_cast<std::ptrdiff_t>(start + static_cast<std::size_t>(first_x)),
                          certificates.begin() + static_cast<std::ptrdiff_t>(start + static_cast<std::size_t>(last_x) + 1U), PressureChunk::kCertificateWarmup);
                pressure_->optimization.certificate_invalidation_cells+=static_cast<std::uint64_t>(last_x-first_x+1);
            }
        }
    }
}

void World::invalidate_pressure_input(ChunkCoord coord, std::int32_t min_x, std::int32_t min_y,
                                      std::int32_t max_x, std::int32_t max_y, bool gas) {
    if (pressure_ == nullptr || pressure_->cache == nullptr) return;
    auto& cache = *pressure_->cache;
    ++pressure_->optimization.invalidation_rects;
    cache.gas_dirty = cache.gas_dirty || gas;
    auto* chunk = find_chunk(coord);
    if (chunk == nullptr) { cache.cold(); return; }
    if (gas && pressure_->parameters.gas_enabled && !chunk->pressure->gas_dirty_queued) {
        if (cache.gas_dirty_chunks.size() == cache.gas_dirty_chunks.capacity()) {
            cache.gas_ready = false;
            ++pressure_->optimization.gas_capacity_fallbacks;
        } else {
            cache.gas_dirty_chunks.push_back(coord);
            chunk->pressure->gas_dirty_queued = true;
            ++pressure_->optimization.gas_dirty_chunks_queued;
        }
    }
    cache.mark(true, chunk->pressure->column_group, min_x, max_x);
    invalidate_pressure_certificates(coord, min_x, min_y, max_x, max_y);
}

PressureOptimizationSnapshot World::pressure_optimization_snapshot() const {
    PressureOptimizationSnapshot out;
    if (pressure_ == nullptr) return out;
    out.counters = pressure_->optimization;
    out.common_counter_bytes = sizeof(pressure_->optimization);
    out.worker_counter_capacity_bytes = pressure_->job_optimization.capacity() * sizeof(PressureKernelWork);
    if (pressure_->cache == nullptr) return out;
    const auto& cache = *pressure_->cache;
    out.status = cache.status; out.cached = true; out.dormant = cache.dormant;
    out.gas_pending = cache.gas_dirty; out.index_incarnation = cache.incarnation;
    out.certificate_layer_enabled=cache.certificate_layer_enabled;
    out.certificate_contents_cold=cache.dormant && cache.certificate_contents_cold;
    out.certificate_window_ticks=cache.certificate_window_ticks;
    out.certificate_suspend_remaining=cache.certificate_suspend_remaining;
    out.certificate_window_charge=cache.certificate_window_charge;
    out.certificate_window_credit=cache.certificate_window_credit;
    out.certificate_last_window_charge=cache.certificate_last_window_charge;
    out.certificate_last_window_credit=cache.certificate_last_window_credit;
    out.indexed_chunks = cache.column_order.size(); out.column_groups = cache.columns.size();
    out.row_groups = cache.rows.size(); out.dirty_column_groups = cache.dirty_columns.size();
    out.dirty_row_groups = cache.dirty_rows.size(); out.index_chunk_capacity = cache.capacity;
    out.head_repair_cell_budget = cache.config.head_repair_cell_budget;
    out.gas_components = cache.gas_components.size();
    for (const auto& component : cache.gas_components) out.gas_valid_components += component.valid ? 1U : 0U;
    out.gas_members = cache.gas_members.size(); out.gas_member_capacity = cache.gas_members.capacity();
    out.gas_dirty_chunks = cache.gas_dirty_chunks.size();
    out.gas_invalidation_pair_budget = cache.config.gas_invalidation_pair_budget;
    out.gas_capacity_bytes = cache.gas_members.capacity() * sizeof(PressureCache::GasMember) +
        cache.gas_components.capacity() * sizeof(PressureCache::GasComponent) +
        cache.gas_dirty_chunks.capacity() * sizeof(ChunkCoord);
    out.derived_capacity_bytes = sizeof(PressureCache) +
        (cache.column_order.capacity() + cache.row_order.capacity()) * sizeof(ChunkCoord) +
        (cache.columns.capacity() + cache.rows.capacity()) * sizeof(PressureCache::Group) +
        (cache.dirty_columns.capacity() + cache.dirty_rows.capacity()) * sizeof(std::size_t) + out.gas_capacity_bytes;
    for (const auto& [coord, chunk] : chunks_) {
        (void)coord;
        out.derived_capacity_bytes += sizeof(chunk->pressure->gas_chunk_slot) + sizeof(chunk->pressure->gas_dirty_queued);
        out.derived_capacity_bytes += chunk->pressure->base_head.capacity() * sizeof(std::int32_t) +
                                     chunk->pressure->rest_certificate.capacity();
        out.certificate_buffer_capacity_bytes+=chunk->pressure->rest_certificate.capacity();
    }
    return out;
}

std::optional<std::array<std::uint8_t,32>> World::pressure_optimization_identity() const noexcept {
    if (pressure_==nullptr || pressure_->cache==nullptr) return std::nullopt;
    const auto& cache=*pressure_->cache;
    Sha256 hash;
    constexpr char domain[]="cybersand-pressure-optimization-v1-identity-v1";
    hash.update({reinterpret_cast<const std::uint8_t*>(domain),sizeof(domain)-1U});
    for (const std::uint64_t value : {kPressureOptimizationExecutionVersion,std::uint64_t{cache.dormant ? 2U : 1U},
            static_cast<std::uint64_t>(cache.config.index_chunk_capacity),cache.config.head_repair_cell_budget,
            static_cast<std::uint64_t>(cache.config.gas_member_capacity),cache.config.gas_invalidation_pair_budget}) {
        std::array<std::uint8_t,8> bytes{};
        for (unsigned i=0;i<8;++i) bytes[i]=static_cast<std::uint8_t>(value>>(8U*i));
        hash.update(bytes);
    }
    return hash.finish();
}

std::int64_t World::pressure_lateral_gradient(std::int64_t x, std::int64_t y) const {
    const auto at = address(x,y);
    const auto& self = *find_chunk(at.chunk);
    const auto stiffness = static_cast<std::int64_t>(config_.water_experiment_policy.maximum()) *
        PressureFlowParameters::kOverfillStiffnessRows;
    const auto head = self.pressure->head[at.index];
    const auto own = (head == PressureChunk::kNoHead
        ? static_cast<std::int64_t>(self.cells[at.index].state_a_value()) + self.pressure->cells[at.index].overfill
        : static_cast<std::int64_t>(head)) + stiffness * self.pressure->cells[at.index].overfill;
    const auto sample = [&](std::int64_t nx) -> std::optional<std::int64_t> {
        if (transient_obstacle_at(nx,y) != 0U) return std::nullopt;
        const auto target = address(nx,y); const auto* chunk = find_chunk(target.chunk);
        if (chunk == nullptr) return 0;
        const auto material = chunk->cells[target.index].material_value();
        if (material == Material::Empty) return pressure_->gauge_of_label(chunk->pressure->cells[target.index].gas);
        if (material != Material::Water) return std::nullopt;
        const auto h = chunk->pressure->head[target.index];
        const auto compression = stiffness * chunk->pressure->cells[target.index].overfill;
        return (h == PressureChunk::kNoHead
            ? static_cast<std::int64_t>(chunk->cells[target.index].state_a_value()) + chunk->pressure->cells[target.index].overfill
            : static_cast<std::int64_t>(h)) + compression;
    };
    const auto l1=sample(x-1), l2=l1 ? sample(x-2) : std::nullopt;
    const auto r1=sample(x+1), r2=r1 ? sample(x+2) : std::nullopt;
    const auto a=l1.value_or(own), b=l2.value_or(a), c=r1.value_or(own), d=r2.value_or(c);
    return (b+a-c-d)/2;
}

bool World::pressure_motion_is_noop(std::int64_t x, std::int64_t y, JobEffects* effects) {
    auto& work = effects != nullptr && effects->pressure_work != nullptr
        ? *effects->pressure_work : pressure_->optimization;
    const auto at=address(x,y); auto& chunk=*find_chunk(at.chunk);
    auto& certificate=chunk.pressure->rest_certificate[at.index];
    // Owner obligations are checked even for a warm local certificate. They
    // are not all represented by a neighboring authoritative cell edit.
    if (!pending_explosions_.empty() ||
        (config_.transport_policy.configured && config_.transport_policy.cadence_for(3U)!=1U)) {
        certificate=PressureChunk::kCertificateWarmup;
        ++work.certificate_declines;
        return false;
    }
    bool touched=false;
    if (effects != nullptr) {
        for (std::size_t i=0;i<effects->chunk_count;++i) {
            const auto& edit=effects->chunks[i];
            if (edit.chunk.x<at.chunk.x-1 || edit.chunk.x>at.chunk.x+1 ||
                edit.chunk.y<at.chunk.y-1 || edit.chunk.y>at.chunk.y+1) continue;
            const auto dx=(edit.chunk.x-at.chunk.x)*config_.chunk_size;
            const auto dy=(edit.chunk.y-at.chunk.y)*config_.chunk_size;
            if (dx+edit.minimum_x<=at.local_x+2 && dx+edit.maximum_x>=at.local_x-2 &&
                dy+edit.minimum_y<=at.local_y+2 && dy+edit.maximum_y>=at.local_y-2) { touched=true; break; }
        }
    }
    if (touched) {
        certificate=PressureChunk::kCertificateWarmup;
        ++work.certificate_declines;
        return false;
    }
    if (certificate == PressureChunk::kCertificateValid) { ++work.certificate_reuses; return true; }
    if (certificate >= PressureChunk::kCertificateWarmup) {
        // Only the exact Valid tag can skip motion. Countdown values cannot
        // become Valid: the last deferred visit transitions directly to cold0.
        --certificate;
        if (certificate == PressureChunk::kCertificateValid) certificate=0U;
        ++work.certificate_declines;
        return false;
    }
    ++work.certificate_attempts;
    const auto prove = [&] {
        const auto& cell=chunk.cells[at.index]; const auto& side=chunk.pressure->cells[at.index];
        const auto maximum=config_.water_experiment_policy.maximum();
        if (cell.material_value()!=Material::Water || cell.state_a_value()!=maximum || cell.state_b_value()!=0U ||
            side.flow!=0 || side.overfill!=0U || chunk.pressure->head[at.index]==PressureChunk::kNoHead ||
            !pending_explosions_.empty()) return false;
        // Later cadence paths publish future deadlines even when motion fails.
        // The initial certificate declines those paths instead of erasing work.
        if (config_.transport_policy.configured && config_.transport_policy.cadence_for(3U)!=1U) return false;
        // Failed gravity/diagonal probes report actual body contacts. Keep those
        // probes whenever a current or newly approached mask is in the stencil.
        for (std::int32_t dy=-2;dy<=2;++dy) for(std::int32_t dx=-2;dx<=2;++dx)
            if (transient_obstacle_at(x+dx,y+dy)!=0U) return false;
        const auto blocked = [&](std::int64_t tx, std::int64_t ty) {
            const auto material=stored_material(tx,ty);
            if (MaterialRules::is_hard_surface(material)) return true;
            if (material!=Material::Water) return false;
            return stored_state_a(tx,ty)==maximum;
        };
        if (!blocked(x,y+1) || !blocked(x-1,y+1) || !blocked(x+1,y+1) ||
            !blocked(x-1,y) || !blocked(x+1,y)) return false;
        const auto gradient=pressure_lateral_gradient(x,y);
        const auto band=std::max<std::int64_t>(1,
            (PressureFlowParameters::kStartDeadBand255*static_cast<std::int64_t>(maximum)+127)/255);
        return gradient>=-band && gradient<=band;
    };
    const bool allowed=prove();
    certificate=allowed ? PressureChunk::kCertificateValid : PressureChunk::kCertificateBackoff;
    if (!allowed) ++work.certificate_declines;
    return allowed;
}
