// Included by world.cpp only. LCB-001 (#200) pressure_flow_v1/reference World-owned
// state: the gas-compartment table, exact ledgers and the fixed-capacity scratch
// used by the serial tick preparation. Everything is allocated at construction;
// tick preparation never grows a container (capacity exhaustion throws and the
// World quarantines, like the other bounded World capacities).

namespace {

[[nodiscard]] PressureFlowParameters pressure_parameters_from(const LiquidSolverPolicy& policy) {
    PressureFlowParameters parameters;
    for (const auto& block : policy.family_blocks()) {
        if (block.owner != static_cast<std::uint16_t>(LiquidSolverFamily::PressureFlowV1) ||
            block.version != LiquidPolicyBuild::kPressureBlockVersion || block.values.size() != 2U) continue;
        parameters.gas_enabled = block.values[0] != 0;
        parameters.atmospheric_head_rows = block.values[1];
    }
    return parameters;
}

[[nodiscard]] bool policy_selects_pressure(const LiquidSolverPolicy& policy) {
    const auto water = policy.assignment(static_cast<std::uint16_t>(Material::Water));
    return water.has_value() && water->family == LiquidSolverFamily::PressureFlowV1;
}

}  // namespace

struct World::PressureState {
    std::unique_ptr<PressureCache> cache;
    PressureOptimizationCounters optimization;
    std::vector<PressureKernelWork> job_optimization;
    bool gas_fixed_point = false;
    struct Compartment {
        std::uint32_t id = 0;
        std::uint32_t generation = 0;
        std::array<std::uint32_t, PressureFlowParameters::kMaximumParents> parents{};
        std::uint8_t parent_count = 0;
        std::uint64_t amount = 0;
        std::uint64_t volume = 0;
        std::int64_t anchor_x = 0;
        std::int64_t anchor_y = 0;
        std::uint64_t created_tick = 0;
        std::uint64_t revision = 0;
        std::int64_t gauge = 0;
    };
    struct Cell {
        std::int64_t x = 0;
        std::int64_t y = 0;
    };
    struct Region {
        std::uint64_t volume = 0;
        std::uint64_t atmosphere_cells = 0;  // cells labelled atmosphere before this pass
        std::uint64_t fresh_cells = 0;       // unresolved (label 0) cells: atmospheric if newly sealed
        std::int64_t lowest_x = 0;
        std::int64_t lowest_y = 0;
        bool atmosphere = false;
        std::uint32_t first_overlap = kNone;
        std::uint32_t first_node = kNone;    // non-resident chunk nodes of this region
        std::uint32_t label = 0;             // resolved label for the relabel pass
    };
    struct Overlap {
        std::uint32_t compartment = 0;  // index into compartments at pass start
        std::uint64_t count = 0;
        std::uint32_t next = kNone;
    };
    struct ChunkNode {
        ChunkCoord coord{};
        std::uint32_t region = 0;
        std::uint32_t next = kNone;
    };
    static constexpr std::uint32_t kNone = std::numeric_limits<std::uint32_t>::max();
    static constexpr std::size_t kRegionCapacity = 65535;
    static constexpr std::size_t kOverlapCapacity = 8192;
    static constexpr std::size_t kChunkNodeCapacity = 1024;

    explicit PressureState(PressureFlowParameters value) : parameters(value) {
        compartments.reserve(PressureFlowParameters::kCompartmentCapacity);
        next_compartments.reserve(PressureFlowParameters::kCompartmentCapacity);
        history.reserve(PressureFlowParameters::kHistoryCapacity);
        // One entry per visited resident cell or chunk node; a fill stops once its
        // volume exceeds the limit, so this bound is never exceeded.
        queue.reserve(PressureFlowParameters::kCompartmentVolumeLimit + kChunkNodeCapacity + 4U);
        regions.reserve(kRegionCapacity);
        overlaps.reserve(kOverlapCapacity);
        nodes.reserve(kChunkNodeCapacity);
        uf_parent.reserve(PressureFlowParameters::kCompartmentCapacity + kRegionCapacity);
        component_order.reserve(PressureFlowParameters::kCompartmentCapacity + kRegionCapacity);
        member_compartments.reserve(PressureFlowParameters::kCompartmentCapacity);
        member_regions.reserve(kRegionCapacity);
        sorted_coordinates.reserve(4096);
    }

    void reset() noexcept {
        if (cache != nullptr) {
            cache->cold();
            cache->reset_certificate_admission();
            cache->gas_dirty_chunks.clear();
            cache->gas_components.clear();
            cache->gas_members.clear();
        }
        optimization = {};
        gas_fixed_point = false;
        compartments.clear();
        next_compartments.clear();
        history.clear();
        history_next = 0;
        next_id = 1;
        topology_revision = 0;
        gas = {};
        flow = {};
        diagnostics = {};
        pass_stamp = 0;
    }

    void record_history(const Compartment& compartment, GasRetireReason reason,
                        std::span<const std::uint32_t> successors, std::uint64_t tick) noexcept {
        GasHistoryRecord record;
        record.compartment = snapshot(compartment);
        record.reason = reason;
        record.successor_count = static_cast<std::uint8_t>(
            std::min(successors.size(), record.successors.size()));
        for (std::size_t i = 0; i < record.successor_count; ++i) record.successors[i] = successors[i];
        record.tick = tick;
        if (history.size() < PressureFlowParameters::kHistoryCapacity) {
            history.push_back(record);
        } else {
            history[history_next] = record;
        }
        history_next = (history_next + 1U) % PressureFlowParameters::kHistoryCapacity;
    }

    [[nodiscard]] static GasCompartmentSnapshot snapshot(const Compartment& c) noexcept {
        GasCompartmentSnapshot out;
        out.id = c.id;
        out.generation = c.generation;
        out.parents = c.parents;
        out.parent_count = c.parent_count;
        out.amount = c.amount;
        out.volume = c.volume;
        out.anchor_x = c.anchor_x;
        out.anchor_y = c.anchor_y;
        out.created_tick = c.created_tick;
        out.revision = c.revision;
        out.gauge = c.gauge;
        return out;
    }

    [[nodiscard]] const Compartment* find(std::uint32_t id) const noexcept {
        const auto found = std::lower_bound(
            compartments.begin(), compartments.end(), id,
            [](const Compartment& c, std::uint32_t value) { return c.id < value; });
        return found != compartments.end() && found->id == id ? &*found : nullptr;
    }

    [[nodiscard]] std::int64_t gauge_of_label(std::uint32_t label) const noexcept {
        if (label == 0U || label == kAtmosphereLabel || label == kVacuumLabel || !parameters.gas_enabled) return 0;
        const auto* found = find(label);
        return found == nullptr ? 0 : found->gauge;
    }

    std::uint32_t uf_find(std::uint32_t node) noexcept {
        while (uf_parent[node] != node) {
            uf_parent[node] = uf_parent[uf_parent[node]];
            node = uf_parent[node];
        }
        return node;
    }
    void uf_union(std::uint32_t a, std::uint32_t b) noexcept {
        a = uf_find(a);
        b = uf_find(b);
        if (a == b) return;
        if (b < a) std::swap(a, b);
        uf_parent[b] = a;
    }

    PressureFlowParameters parameters;
    std::vector<Compartment> compartments;  // sorted by id, ids never reused
    std::vector<Compartment> next_compartments;
    std::vector<GasHistoryRecord> history;
    std::size_t history_next = 0;
    std::uint32_t next_id = 1;
    std::uint64_t topology_revision = 0;
    GasLedger gas{};
    PressureFlowLedger flow{};
    PressureFlowDiagnostics diagnostics{};
    std::uint16_t pass_stamp = 0;

    // Fixed-capacity scratch for the serial tick preparation.
    std::vector<Cell> queue;
    std::vector<Region> regions;
    std::vector<Overlap> overlaps;
    std::vector<ChunkNode> nodes;
    std::vector<std::uint32_t> uf_parent;
    std::vector<std::uint32_t> component_order;
    std::vector<std::uint32_t> member_compartments;
    std::vector<std::uint32_t> member_regions;
    std::vector<ChunkCoord> sorted_coordinates;
};
