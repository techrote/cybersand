// LCB-002 #201 scale-matched PressureFlow idle-cost discrimination.
//
// The registered LCB-002 total-cost apparatus is reused byte-for-byte as a
// translation unit: its same-tick pressure-variant equivalence, counter, memory
// snapshot, prepared-head comparison and peak-RSS routines are unchanged. That
// apparatus cannot reproduce the #370 quiet-pool discrepancy: its fixtures are
// 128x128 (chunk 32) or 88x8 (chunk 8) Worlds, its phases are fixed at 8/48/32
// with mandatory edits, and it has no FreeMass context arm. This driver adds
// only the #370 host geometry (prepared 1024x1024 domain, chunk 128, host
// capacities), longer cold/settle/quiet/tail windows and a FreeMass context
// World that is never a same-law parity target.
//
// Only World::tick is inside tick timers. Edits, observations, parity and JSON
// are outside every arm's interval. The Python runner owns source/tool fences.
#define main lcb002_total_cost_main
#include "lcb_pressure_optimization.cpp"
#undef main

#include "cybersand/material_rules.hpp"
#include "cybersand/prepared_world.hpp"
#include "cybersand/water_normalization.hpp"

namespace lcb201 {
using namespace cybersand;

constexpr int kCold = 8, kSettle = 56, kQuiet = 96, kTail = 96;
constexpr int kTicks = kCold + kSettle + kQuiet + kTail;
constexpr std::int64_t kSide = 1024;
constexpr RectI64 kDomain{0, 0, kSide, kSide};
constexpr RectI64 kInterest{16, 16, 992, 272};
constexpr std::uint16_t kBody = 7;
constexpr std::array<std::string_view, 4> kArms{"reference", "cached", "dormant", "freemass"};
constexpr std::array<std::string_view, 5> kProfiles{
    "pool-vented", "pool-sealed", "pool-sealed-remote-gas", "pool-vented-moving-mask", "pool-vented-boundary-churn"};
// Water head samples are copied outside timers on these 1-based ticks.
constexpr std::array<int, 9> kHeadTicks{1, 8, 32, 64, 96, 128, 160, 208, 256};

const char* phase(int t) {
    return t < kCold ? "cold" : t < kCold + kSettle ? "settle" : t < kCold + kSettle + kQuiet ? "quiet" : "tail";
}
bool sealed(std::string_view p) { return p == kProfiles[1] || p == kProfiles[2]; }

LiquidSolverPolicy policy_for(std::size_t arm) {
    auto words = LiquidSolverPolicy::default_request();
    if (arm < 3U) {
        const auto count = static_cast<std::size_t>(words[LiquidSolverPolicy::kHeaderWords]);
        bool water = false;
        for (std::size_t i = 0; i < count; ++i) {
            const auto at = LiquidSolverPolicy::kHeaderWords + 1U + 3U * i;
            if (words[at] != static_cast<std::int32_t>(Material::Water)) continue;
            words[at + 1U] = static_cast<std::int32_t>(LiquidSolverFamily::PressureFlowV1);
            words[at + 2U] = static_cast<std::int32_t>(arm);
            water = true;
        }
        require(water, "native default envelope must contain Water");
    }
    const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
    require(decoded.accepted(), "registered Water policy must be admitted without fallback");
    return *decoded.policy;
}

// cyber_native_cell_world diagnostic_reset/constructor capacities, then the
// prepared-liquid overrides (cyber_prepared_liquid_world.hpp) for a controlled
// schema-2 MicroScenario: fixture transport (Baseline, configured), Water
// policy 8/12, explicit rule radius 2, default interaction, diagnostics on.
WorldConfig host_config(std::size_t arm, std::uint32_t workers) {
    WorldConfig config;
    config.worker_threads = workers;
    config.backend = SimulationBackend::PhasedInPlace;
    config.initial_chunk_reserve = 64;
    config.maximum_chunk_count = 128;
    config.active_core_capacity = 1024;
    config.active_chunk_capacity = 128;
    config.parallel_job_threshold = 2;
    TransportPolicy transport;  // Baseline equals defaults for every present material.
    transport.configured = true;
    config.transport_policy = transport;
    config.water_experiment_policy = WaterExperimentPolicy(8, 12);
    config.liquid_solver_policy = policy_for(arm);
    config.maximum_rule_radius = 2;
    config.interaction_policy = {};
    config.physics_diagnostics = {};
    config.physics_diagnostics.enabled = true;
    return config;
}

// lcb.rest.deep-quiet-pool.v1 rectangles and fill, rasterized in fixture order.
normalization::FinalSetupInput setup_input(std::string_view profile, const WorldConfig& config) {
    struct Tuple { Material material = Material::Empty; std::uint16_t a = 0; std::uint8_t b = 0; };
    std::vector<Tuple> map(static_cast<std::size_t>(kSide * kSide));
    std::vector<std::array<std::int32_t, 4>> walls{
        {0, 0, 1024, 1}, {0, 0, 1, 1024}, {1023, 0, 1, 1024}, {0, 1023, 1024, 1},
        {32, 256, 960, 8}, {32, 64, 8, 192}, {984, 64, 8, 192}};
    // Sealed variants add a one-cell lid: headspace 944x8 = 7,552 cells, below
    // the 16,384-cell compartment limit, so it is a positive-ID compartment.
    if (sealed(profile)) walls.push_back({32, 87, 960, 1});
    const auto& wall = MaterialRules::descriptor(Material::Wall);
    for (const auto& r : walls)
        for (auto y = r[1]; y < r[1] + r[3]; ++y) for (auto x = r[0]; x < r[0] + r[2]; ++x)
            map[static_cast<std::size_t>(y * kSide + x)] = {Material::Wall, wall.initial_state_a, wall.initial_state_b};
    const auto mass = static_cast<std::uint16_t>((2U * 255U * config.water_experiment_policy.maximum() + 255U) / 510U);
    for (std::int64_t y = 96; y < 256; ++y) for (std::int64_t x = 40; x < 984; ++x)
        map[static_cast<std::size_t>(y * kSide + x)] = {Material::Water, mass, 0};
    normalization::FinalSetupInput input;
    input.mass_bits = config.water_experiment_policy.mass_bits();
    input.ambient_temperature = config.ambient_temperature;
    input.setup.kind = setup::SetupKind::MicroScenario;
    input.setup.definition_schema = 2;
    input.setup.definition_digest.emplace();
    // Vented: the registered #370 definition hash. Derived variants bind a
    // distinct label digest; neither claims a native definition compiler.
    const auto label = Sha256::of(std::span<const std::uint8_t>(
        reinterpret_cast<const std::uint8_t*>(profile.data()), profile.size()));
    std::copy(label.begin(), label.end(), input.setup.definition_digest->begin());
    input.setup.seed = 0;
    input.setup.domain = {0, 0, static_cast<std::uint64_t>(kSide), static_cast<std::uint64_t>(kSide)};
    input.setup.coverage = setup::SetupCoverage::RegisteredDefinitionAndPayload;
    input.setup.gaps = setup::kKnownSetupGaps;
    for (std::int64_t y = 0; y < kSide; ++y) for (std::int64_t x = 0; x < kSide; ++x) {
        const auto& cell = map[static_cast<std::size_t>(y * kSide + x)];
        if (cell.material != Material::Empty)
            input.cells.push_back({x, y, cell.material, cell.a, cell.b, config.ambient_temperature});
    }
    return input;
}

std::unique_ptr<World> prepare(std::string_view profile, std::size_t arm, std::uint32_t workers) {
    const auto config = host_config(arm, workers);
    auto result = PreparedWorldBuilder::prepare(config, setup_input(profile, config),
        normalization::NormalizationOptIn::WaterNormalizeV1);
    if (const auto* refused = std::get_if<ConstructionRefusal>(&result))
        throw std::runtime_error("prepared World refused: " + (refused->policy_refusal() ? refused->policy_refusal()->detail : std::string(refused->failure_detail())));
    auto world = std::get<PreparedWorld>(result).take_world();
    world->configure_transient_obstacles(kDomain);
    world->set_simulation_region(kInterest);
    world->set_liquid_surface_adhesion_enabled(true);
    return world;
}

// Tail-phase disturbances only. Every edit is Water-neutral by construction.
void edit(World& w, std::string_view profile, int t) {
    const int tail = kCold + kSettle + kQuiet;
    if (t < tail) return;
    const int d = t - tail;
    if (profile == kProfiles[2]) {
        // Changed reservoir geometry inside the sealed headspace (volume/gauge),
        // plus a bounded remote vent/reseal of the lid far from most columns.
        if (d % 8 == 0) w.set(700, 90, (d / 8) % 2 == 0 ? Material::Wall : Material::Empty);
        if (d % 32 == 16) w.set(500, 87, (d / 32) % 2 == 0 ? Material::Empty : Material::Wall);
    } else if (profile == kProfiles[3]) {
        // An 8x8 native body mask crossing the vented surface, half submerged.
        if (d % 4 == 0) {
            w.clear_transient_obstacles();
            const auto x0 = 60 + 8 * (d / 4);
            for (std::int64_t y = 92; y < 100; ++y) for (std::int64_t x = x0; x < x0 + 8; ++x)
                require(w.set_transient_obstacle(x, y, kBody), "moving native body mask installed");
        }
    } else if (profile == kProfiles[4]) {
        // Repeated boundary/head change: a lid cell over one surface column.
        w.set(41, 95, d % 2 == 0 ? Material::Wall : Material::Empty);
    }
}

Observation observe_domain(const World& w) {
    Observation o;
    require(!w.has_failed(), "World must remain usable");
    o.projection = w.liquid_comparison_hash(LiquidStateProjection::PressureVariantEquivalenceV1);
    o.quantities = w.quantity_ledger(); o.gas = w.gas_ledger(); o.flow = w.pressure_flow_ledger();
    o.diagnostics = w.pressure_flow_diagnostics();
    o.compartments = w.gas_compartments(); o.history = w.gas_history();
    o.next = w.gas_next_id(); o.revision = w.gas_topology_revision();
    o.quantity = w.water_quantity(kDomain); o.roi_quantity = w.water_quantity(kInterest);
    require(o.quantity == o.quantities.water_visible + o.quantities.water_overfill,
            "domain query and complete stored quantity ledger agree");
    o.contacts = w.transient_contact_count(kBody);
    o.impulse_x = w.transient_contact_impulse_x(kBody); o.impulse_y = w.transient_contact_impulse_y(kBody);
    return o;
}

int run(std::string_view profile, std::uint32_t workers, int replicate) {
    constexpr std::size_t N = kArms.size();
    std::array<std::unique_ptr<World>, N> worlds;
    std::array<std::uint64_t, N> prepare_ns{};
    for (std::size_t position = 0; position < N; ++position) {
        const auto arm = (static_cast<std::size_t>(replicate) + position) % N;
        const auto start = Clock::now(); worlds[arm] = prepare(profile, arm, workers); prepare_ns[arm] = nanos(start);
    }
    for (std::size_t arm = 0; arm < N; ++arm) {
        const auto assignment = worlds[arm]->liquid_solver_policy().assignment(static_cast<std::uint16_t>(Material::Water));
        require(assignment.has_value(), "Water assignment readback");
        require(arm < 3U ? assignment->family == LiquidSolverFamily::PressureFlowV1 &&
                               static_cast<std::size_t>(assignment->variant) == arm
                         : assignment->family == LiquidSolverFamily::FreeMassV1,
                "applied Water family/variant equals the request");
        require(worlds[arm]->water_quantity(kDomain) == 38'515'200U, "registered initial Water quantity");
        if (arm < 3U) {
            const auto p = worlds[arm]->pressure_flow_parameters();
            require(p.gas_enabled && p.atmospheric_head_rows == 32, "default pressure parameters");
        }
    }
    std::array<std::vector<PressureHeadSnapshot>, 3> head_samples;
    std::array<std::vector<ChunkCoord>, 3> chunk_coordinates;
    for (std::size_t arm = 0; arm < 3; ++arm) {
        const auto& cfg = worlds[arm]->config();
        const auto area = static_cast<std::size_t>(cfg.chunk_size) * static_cast<std::size_t>(cfg.chunk_size);
        chunk_coordinates[arm].resize(cfg.maximum_chunk_count);
        head_samples[arm].resize(cfg.maximum_chunk_count * area);
    }
    std::cout << "{\"event\":\"header\",\"schema\":\"lcb201-idle-cost-v1\",\"execution\":" << kPressureOptimizationExecutionVersion
        << ",\"profile\":\"" << profile << "\",\"workers\":" << workers << ",\"replicate\":" << replicate
        << ",\"phase_ticks\":[" << kCold << ',' << kSettle << ',' << kQuiet << ',' << kTail << "],\"chunk_size\":"
        << worlds[0]->config().chunk_size << ",\"maximum_chunk_count\":" << worlds[0]->config().maximum_chunk_count
        << ",\"parallel_job_threshold\":" << worlds[0]->config().parallel_job_threshold
        << ",\"maximum_rule_radius\":" << worlds[0]->config().maximum_rule_radius
        << ",\"domain\":"; rect_json(kDomain); std::cout << ",\"interest\":"; rect_json(kInterest);
    std::cout << ",\"head_ticks\":["; for (std::size_t i = 0; i < kHeadTicks.size(); ++i) std::cout << (i ? "," : "") << kHeadTicks[i];
    std::cout << "],\"arms\":[\"reference\",\"cached\",\"dormant\",\"freemass\"],\"parity_scope\":\"reference/cached/dormant same-tick projection, complete quantity ledger, gas table/history/ledger, PF ledger and body contacts every tick; complete resident prepared heads on head_ticks; FreeMass is cost context only\""
        << ",\"participant_scope\":\"maximum distinct pool threads claiming at least one task in any dispatch of this tick\""
        << ",\"memory_scope\":\"process peak includes four simultaneous Worlds and pools; declared fields are partial\"}\n";
    std::array<PressureOptimizationSnapshot, N> previous{};
    std::array<std::uint64_t, N> observed{};
    std::uint64_t tail_contacts = 0;
    for (std::size_t arm = 0; arm < N; ++arm) {
        previous[arm] = worlds[arm]->pressure_optimization_snapshot();
        std::cout << "{\"event\":\"setup\",\"arm\":\"" << kArms[arm] << "\",\"prepare_ns\":" << prepare_ns[arm]
            << ",\"policy_hash\":\"" << worlds[arm]->liquid_solver_policy().policy_hash_hex() << "\",\"optimization_identity\":";
        const auto identity = worlds[arm]->pressure_optimization_identity();
        if (identity) std::cout << '"' << Sha256::hex(*identity) << '"'; else std::cout << "null";
        std::cout << ",\"resident_chunks\":" << worlds[arm]->chunk_count() << ",\"resident_cell_bytes\":" << worlds[arm]->resident_cell_bytes()
            << ",\"water_quantity\":" << worlds[arm]->water_quantity(kDomain) << ",\"memory\":";
        snapshot_json(*worlds[arm], previous[arm]); std::cout << "}\n";
    }
    for (int t = 0; t < kTicks; ++t) {
        std::array<std::uint64_t, N> edit_ns{}, tick_ns{};
        std::array<TickStats, N> stats{};
        std::array<std::array<WaterQuantityFlow, kQuantityKindCount>, N> kinds{};
        for (std::size_t arm = 0; arm < N; ++arm) {
            const auto before = worlds[arm]->quantity_ledger().kinds[static_cast<std::size_t>(QuantityKind::ExternalEdit)];
            const auto start = Clock::now(); edit(*worlds[arm], profile, t); edit_ns[arm] = nanos(start);
            const auto after = worlds[arm]->quantity_ledger();
            require(before == after.kinds[static_cast<std::size_t>(QuantityKind::ExternalEdit)], "registered edits produce/consume no Water");
            kinds[arm] = after.kinds;
        }
        for (std::size_t position = 0; position < N; ++position) {
            const auto arm = (static_cast<std::size_t>(replicate) + static_cast<std::size_t>(t) + position) % N;
            const auto start = Clock::now(); stats[arm] = worlds[arm]->tick(); tick_ns[arm] = nanos(start);
        }
        std::array<Observation, N> observations;
        for (std::size_t arm = 0; arm < N; ++arm) {
            observations[arm] = observe_domain(*worlds[arm]);
            require(observations[arm].quantity == 38'515'200U, "complete stored Water equals the registered quantity");
            require(observations[arm].quantities.kinds == kinds[arm], "zero tick Water sources and sinks of every kind");
        }
        equivalent(observations[0], observations[1]); equivalent(observations[0], observations[2]);
        const bool heads = std::find(kHeadTicks.begin(), kHeadTicks.end(), t + 1) != kHeadTicks.end();
        std::array<HeadCoverage, 3> coverage{};
        std::array<HeadDifference, 3> difference{};
        if (heads) {
            std::array<std::size_t, 3> resident{}, sampled{};
            for (std::size_t arm = 0; arm < 3; ++arm) {
                resident[arm] = worlds[arm]->copy_pressure_head_chunk_coordinates(chunk_coordinates[arm]);
                require(resident[arm] == worlds[arm]->chunk_count(), "complete copied resident roster");
                const auto first = chunk_coordinates[arm].begin(), last = first + static_cast<std::ptrdiff_t>(resident[arm]);
                std::sort(first, last, [](auto a, auto b) { return a.y != b.y ? a.y < b.y : a.x < b.x; });
                sampled[arm] = resident[arm] * static_cast<std::size_t>(worlds[arm]->config().chunk_size) *
                               static_cast<std::size_t>(worlds[arm]->config().chunk_size);
                coverage[arm] = sample_heads(*worlds[arm], std::span<const ChunkCoord>(chunk_coordinates[arm]).first(resident[arm]),
                                             std::span<PressureHeadSnapshot>(head_samples[arm]).first(sampled[arm]));
            }
            for (std::size_t arm = 0; arm < 3; ++arm) {
                require(resident[arm] == resident[0] && std::equal(chunk_coordinates[0].begin(),
                        chunk_coordinates[0].begin() + static_cast<std::ptrdiff_t>(resident[0]), chunk_coordinates[arm].begin()),
                        "resident rosters agree across pressure variants");
                difference[arm] = compare_heads(std::span<const PressureHeadSnapshot>(head_samples[0]).first(sampled[0]),
                                                std::span<const PressureHeadSnapshot>(head_samples[arm]).first(sampled[arm]));
            }
        }
        if (t >= kCold + kSettle + kQuiet) tail_contacts += observations[0].contacts;
        for (std::size_t arm = 0; arm < N; ++arm) {
            const auto now = worlds[arm]->pressure_optimization_snapshot();
            observed[arm] = std::max(observed[arm], static_cast<std::uint64_t>(stats[arm].worker_threads_observed));
            std::cout << "{\"event\":\"tick\",\"arm\":\"" << kArms[arm] << "\",\"tick\":" << t + 1 << ",\"phase\":\"" << phase(t)
                << "\",\"order_position\":" << (arm + 4U * static_cast<std::size_t>(kTicks) - static_cast<std::size_t>(replicate) - static_cast<std::size_t>(t)) % N
                << ",\"edit_ns\":" << edit_ns[arm] << ",\"tick_ns\":" << tick_ns[arm]
                << ",\"projection\":\"" << observations[arm].projection << "\",\"quantity\":" << observations[arm].quantity
                << ",\"overfill\":" << observations[arm].quantities.water_overfill
                << ",\"gas_next_id\":" << observations[arm].next << ",\"gas_revision\":" << observations[arm].revision
                << ",\"gas_compartments\":" << observations[arm].compartments.size() << ",\"gas_history\":" << observations[arm].history.size()
                << ",\"body_contacts\":" << observations[arm].contacts << ",\"visited_cells\":" << stats[arm].visited_cells
                << ",\"moved_cells\":" << stats[arm].moved_cells << ",\"active_blocks_after\":" << stats[arm].active_blocks_after
                << ",\"active_chunks_before\":" << stats[arm].active_chunks_before << ",\"active_chunks_after\":" << stats[arm].active_chunks_after
                << ",\"dirty_chunks\":" << stats[arm].dirty_chunks << ",\"scheduled_cores\":" << stats[arm].scheduled_cores
                << ",\"worker_threads_observed\":" << stats[arm].worker_threads_observed
                << ",\"chunk_allocations\":" << stats[arm].chunk_allocations << ",\"temperature_field_allocations\":" << stats[arm].temperature_field_allocations
                << ",\"phase_jobs\":[";
            for (std::size_t i = 0; i < stats[arm].phase_jobs.size(); ++i) { if (i) std::cout << ','; std::cout << stats[arm].phase_jobs[i]; }
            const auto& diagnostic = observations[arm].diagnostics;
            std::cout << "],\"pressure_diagnostics\":{\"head_cells\":" << diagnostic.head_cells << ",\"unknown_heads\":" << diagnostic.unknown_heads
                << ",\"gas_visited\":" << diagnostic.gas_visited << ",\"gas_regions\":" << diagnostic.gas_regions
                << ",\"atmosphere_regions\":" << diagnostic.atmosphere_regions << ",\"chunk_allocations\":" << diagnostic.chunk_allocations
                << ",\"woken_blocks\":" << diagnostic.woken_blocks << "},\"counter_delta\":"; counters_json(previous[arm].counters, now.counters);
            if (heads && arm < 3U) { std::cout << ",\"prepared_head\":"; heads_json(coverage[arm], difference[arm]); }
            std::cout << ",\"memory\":"; snapshot_json(*worlds[arm], now); std::cout << "}\n";
            previous[arm] = now;
        }
    }
    if (profile == kProfiles[3]) require(tail_contacts > 0U, "moving-mask profile must generate real native body contacts");
    if (profile == kProfiles[2] || profile == kProfiles[4])
        require(previous[1].counters.gas_reference_passes > 0U && previous[0].counters.gas_reference_passes == static_cast<std::uint64_t>(kTicks),
                "forced gas/boundary profiles execute reference gas passes");
    for (std::size_t arm = 0; arm < N; ++arm) require(observed[arm] > 0U, "a claimed worker configuration must observe actual jobs");
    std::cout << "{\"event\":\"complete\",\"valid\":true,\"peak_rss_bytes\":" << peak_rss_bytes() << ",\"max_observed_participants\":["
        << observed[0] << ',' << observed[1] << ',' << observed[2] << ',' << observed[3] << "],\"parity_ticks\":" << kTicks << "}\n";
    return 0;
}
} // namespace lcb201

int main(int argc, char** argv) {
    try {
        require(argc == 4, "usage: lcb201_pressure_idle_cost PROFILE WORKERS REPLICATE");
        const std::string_view profile = argv[1];
        require(std::find(lcb201::kProfiles.begin(), lcb201::kProfiles.end(), profile) != lcb201::kProfiles.end(),
                        "unknown registered profile");
        const auto workers = integer(argv[2], 1, 4);
        require(workers == 1 || workers == 4, "registered workers are 1 or 4");
        const auto replicate = integer(argv[3], 0, 3);
        return lcb201::run(profile, static_cast<std::uint32_t>(workers), replicate);
    } catch (const std::exception& e) {
        std::cerr << "LCB-201 idle-cost apparatus refused: " << e.what() << '\n'; return 1;
    }
}
