// World-owned derived pressure index. The owner builds and mutates this at
// existing phase barriers. Workers only publish their fixed JobEffects records.
struct World::PressureCache {
    static constexpr auto kMissing = std::numeric_limits<std::size_t>::max();
    struct Group {
        std::int64_t key = 0;
        std::size_t first = 0, last = 0;
        // The admitted chunk width is at most 1024. One bit per global column
        // (or row) within this sparse chunk-coordinate group.
        std::array<std::uint64_t, 16> dirty{};
        bool queued = false;
        [[nodiscard]] bool test(std::int32_t local) const noexcept {
            return (dirty[static_cast<std::size_t>(local) / 64U] &
                    (std::uint64_t{1} << (static_cast<unsigned>(local) % 64U))) != 0U;
        }
    };

    struct GasMember {
        std::uint32_t chunk_slot = 0, cell_index = 0;
    };
    struct GasComponent {
        std::uint32_t id = 0, source_region = 0;
        std::size_t first = 0, count = 0, built = 0;
        std::int64_t anchor_x = 0, anchor_y = 0;
        std::int64_t min_chunk_x = 0, max_chunk_x = 0, min_chunk_y = 0, max_chunk_y = 0;
        bool valid = true;
    };

    PressureCache(std::size_t chunks, std::size_t cell_area, bool gas_enabled, PressureOptimizationConfig settings)
        : config(settings), capacity(std::min(chunks, settings.index_chunk_capacity)) {
        column_order.reserve(capacity); row_order.reserve(capacity);
        columns.reserve(capacity); rows.reserve(capacity);
        dirty_columns.reserve(capacity); dirty_rows.reserve(capacity);
        const auto cells = chunks > std::numeric_limits<std::size_t>::max() / cell_area
            ? std::numeric_limits<std::size_t>::max() : chunks * cell_area;
        if (gas_enabled) {
            gas_member_limit = std::min(settings.gas_member_capacity, cells);
            gas_members.reserve(gas_member_limit);
            gas_components.reserve(PressureFlowParameters::kCompartmentCapacity);
            gas_dirty_chunks.reserve(capacity);
        }
    }

    [[nodiscard]] GasComponent* gas_component(std::uint32_t id) noexcept {
        const auto it = std::lower_bound(gas_components.begin(), gas_components.end(), id,
            [](const auto& component, auto value) { return component.id < value; });
        return it != gas_components.end() && it->id == id ? &*it : nullptr;
    }

    void mark(bool column, std::size_t group, std::int32_t first, std::int32_t last) noexcept {
        if (!complete || group == kMissing) return;
        auto& groups = column ? columns : rows;
        auto& queue = column ? dirty_columns : dirty_rows;
        auto& item = groups[group];
        if (!item.queued) {
            // At most one queued record per admitted group; all storage was
            // reserved at construction. Never publish a partial queue.
            if (queue.size() == queue.capacity()) { complete = false; return; }
            queue.push_back(group); item.queued = true;
        }
        for (auto local = first; local <= last; ++local)
            item.dirty[static_cast<std::size_t>(local) / 64U] |=
                std::uint64_t{1} << (static_cast<unsigned>(local) % 64U);
        status = PressureOptimizationStatus::Pending;
    }

    void reset_certificate_admission() noexcept {
        certificate_layer_enabled=false; certificate_contents_cold=true;
        certificate_window_active=false; certificate_tick_eligible=false;
        certificate_window_overflow=false;
        certificate_window_ticks=0; certificate_suspend_remaining=0;
        certificate_window_charge=0; certificate_window_credit=0;
        certificate_last_window_charge=0; certificate_last_window_credit=0;
        certificate_accounted_invalidations=0; certificate_accounted_attempts=0;
        certificate_accounted_reuses=0; certificate_accounted_saved=0;
        certificate_water_calls_begin=0; certificate_prior_water_calls=0;
    }

    void cold() noexcept {
        complete = false; membership_dirty = true; gas_dirty = true;
        use_heads = false;
        certificate_layer_enabled=false; certificate_contents_cold=true;
        certificate_tick_eligible=false;
        gas_ready = false;
        status = PressureOptimizationStatus::Cold;
    }

    PressureOptimizationConfig config;
    std::size_t capacity;
    std::vector<ChunkCoord> column_order, row_order;
    std::vector<Group> columns, rows;
    std::vector<std::size_t> dirty_columns, dirty_rows;
    PressureOptimizationCounters counters{};
    PressureOptimizationStatus status = PressureOptimizationStatus::Cold;
    std::uint64_t incarnation = 0;
    bool complete = false;
    bool membership_dirty = true;
    bool gas_dirty = true;
    bool dormant = false;
    bool certificate_layer_enabled=false, certificate_contents_cold=true;
    bool certificate_window_active=false, certificate_tick_eligible=false;
    bool certificate_window_overflow=false;
    std::uint8_t certificate_window_ticks=0, certificate_suspend_remaining=0;
    std::uint64_t certificate_window_charge=0, certificate_window_credit=0;
    std::uint64_t certificate_last_window_charge=0, certificate_last_window_credit=0;
    std::uint64_t certificate_accounted_invalidations=0, certificate_accounted_attempts=0;
    std::uint64_t certificate_accounted_reuses=0, certificate_accounted_saved=0;
    std::uint64_t certificate_water_calls_begin=0, certificate_prior_water_calls=0;
    bool use_heads = false;
    bool gas_ready = false;
    std::size_t gas_member_limit = 0;
    std::vector<GasMember> gas_members;
    std::vector<GasComponent> gas_components;
    std::vector<ChunkCoord> gas_dirty_chunks;
};
