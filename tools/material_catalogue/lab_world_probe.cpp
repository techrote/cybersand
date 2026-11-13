// External test fixture: the existing World and demo constructor own mutation.
#include "catalogue.shadow.hpp"
#include "cybersand/demo_snapshot.hpp"
#include "cybersand/interaction_rules.hpp"
#include "cybersand/material_appearance.hpp"
#include "cybersand/material_rules.hpp"
#if __has_include("lab-reaction-effects.hpp")
#include "lab-reaction-effects.hpp"
#include "lab_effects_probe.hpp"
#define CYBERSAND_LAB_EFFECTS_V2 1
#endif
#include <algorithm>
#include <array>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using namespace cybersand;
namespace generated = cybersand::material_catalogue_shadow;
constexpr RectI64 kRegion{176, 64, 132, 184};
constexpr RectI64 kInterest{168, 56, 148, 200};
constexpr RectI64 kWholeWorld{0, 0, demo::kWidth, demo::kHeight};
std::uint64_t table_checks = 0;
void require(bool condition, const char* message) {
    ++table_checks;
    if (!condition) throw std::runtime_error(message);
}
std::uint32_t number(const char* value, std::uint32_t maximum) {
    const std::string text(value);
    if (text.empty() || text.find_first_not_of("0123456789") != std::string::npos)
        throw std::invalid_argument("Expected an unsigned decimal argument");
    const auto parsed = std::stoull(text);
    if (parsed > maximum) throw std::invalid_argument("Fixture argument outside bounds");
    return static_cast<std::uint32_t>(parsed);
}
std::string hash_text(std::uint64_t value) {
    std::ostringstream out;
    out << std::hex << std::setw(16) << std::setfill('0') << value;
    return out.str();
}
template<class Range> void numbers(const Range& values) {
    std::cout << '[';
    bool first = true;
    for (const auto value : values) {
        if (!first) std::cout << ',';
        std::cout << +value;
        first = false;
    }
    std::cout << ']';
}
void verify_tables() {
    require(kMaterialDefinitions.size() == 132 && generated::kMaterialDefinitions.size() == 132,
            "World fixture must retain exactly 132 allocated slots");
    require(!valid_material(10) && !valid_material(132), "Reserved/new material identity admitted");
    for (std::size_t index = 0; index < kMaterialDefinitions.size(); ++index) {
        const auto& actual = kMaterialDefinitions[index];
        const auto& row = generated::kMaterialDefinitions[index];
        require(row.id == index && actual.name == row.name &&
            static_cast<unsigned>(actual.state) == row.state && actual.density == row.density &&
            actual.rgba == row.rgba && actual.movable == row.movable && actual.valid == row.valid &&
            actual.current_rule_available == row.current_rule_available &&
            static_cast<unsigned>(actual.kernel) == row.kernel && actual.initial_state_a == row.initial_state_a &&
            actual.initial_state_b == row.initial_state_b && actual.maximum_write_radius == row.maximum_write_radius &&
            static_cast<unsigned>(actual.density_motion) == row.density_motion &&
            actual.accepts_density_exchange == row.accepts_density_exchange &&
            static_cast<unsigned>(actual.lateral_flow) == row.lateral_flow &&
            actual.viscosity_index == row.viscosity_index, "Native descriptor does not consume generated definition");
        require(static_cast<unsigned>(kVisualStateSources[index]) == generated::kVisualStateSources[index],
                "Visual-state projection edit has no admitted World consumer");
    }
    for (std::size_t index = 0; index < generated::kCapabilities.size(); ++index) {
        const auto material = static_cast<Material>(index);
        const auto& cap = generated::kCapabilities[index];
        require(MaterialRules::is_hard_surface(material) == cap.hard_surface &&
            MaterialRules::supports_granular_load(material) == cap.granular_support &&
            MaterialRules::has_pair_reactions(material) == cap.pair_participant,
            "Generated capability has no matching native consumer");
    }
    require(kPairInteractionRules.size() == generated::kPairInteractionRules.size(), "Sparse rule count changed");
    for (std::size_t index = 0; index < kPairInteractionRules.size(); ++index) {
        const auto& actual = kPairInteractionRules[index];
        const auto& row = generated::kPairInteractionRules[index];
        require(row.legacy_slot == index && actual.id == row.id && actual.channels == row.channels &&
            static_cast<unsigned>(actual.trigger) == row.trigger && static_cast<unsigned>(actual.match) == row.match &&
            static_cast<unsigned>(actual.first) == row.first && static_cast<unsigned>(actual.second) == row.second &&
            static_cast<unsigned>(actual.first_product) == row.first_product &&
            static_cast<unsigned>(actual.second_product) == row.second_product && actual.probability == row.probability &&
            actual.accounting == row.accounting && actual.revalidation_tags == row.revalidation_tags &&
            actual.version == row.version && actual.supersedes == row.supersedes && actual.tuning_pass_id == row.tuning_pass_id,
            "Native sparse rule does not consume generated definition");
        for (unsigned orientation = 0; orientation < 2; ++orientation) {
            const auto first = orientation == 0 ? actual.first : actual.second;
            const auto second = orientation == 0 ? actual.second : actual.first;
            for (unsigned roll = 0; roll < 256; ++roll) {
                const auto expected = InteractionRules::resolve_pair(first, second, static_cast<std::uint8_t>(roll));
                const auto selected = MaterialRules::pair_reaction(first, second, static_cast<std::uint8_t>(roll));
                require(selected.has_value() == expected.selected && (!selected ||
                    (selected->source_product == expected.source_product && selected->target_product == expected.target_product &&
                     selected->rule_index == expected.rule_index)), "World resolver priority/probability/product mismatch");
            }
        }
    }
}

using Cell = std::array<std::int32_t, 4>;
struct Snapshot {
    std::uint64_t tick = 0, active_chunks = 0, water = 0, target_below = 0;
    std::string content_hash, state_hash, physical_hash, policy_hash;
    QuantityLedgerSnapshot ledger;
    std::array<std::uint64_t, 132> region_counts{}, sum_y{};
    std::vector<Cell> cells;
};
Snapshot capture(const World& world, Material target) {
    Snapshot out;
    out.tick = world.completed_tick_index();
    out.active_chunks = world.active_chunk_count();
    out.content_hash = hash_text(world.content_hash());
    out.state_hash = hash_text(world.state_hash());
    out.physical_hash = hash_text(world.physical_state_hash());
    out.policy_hash = world.liquid_solver_policy().policy_hash_hex();
    out.ledger = world.quantity_ledger();
    out.water = world.water_quantity(kWholeWorld);
    out.cells.reserve(static_cast<std::size_t>(kRegion.width * kRegion.height));
    for (auto y = kRegion.y; y < kRegion.y + kRegion.height; ++y) {
        for (auto x = kRegion.x; x < kRegion.x + kRegion.width; ++x) {
            const auto material = world.stored_material(x, y);
            const auto id = static_cast<std::size_t>(material);
            require(id < 132 && id != 10, "World stored an unallocated or reserved material");
            ++out.region_counts[id];
            out.sum_y[id] += static_cast<std::uint64_t>(y);
            if (material == target && y >= 192) ++out.target_below;
            out.cells.push_back({static_cast<std::int32_t>(id), world.stored_state_a(x, y),
                world.stored_state_b(x, y), world.stored_temperature(x, y)});
        }
    }
    return out;
}
bool same_physical_state(const Snapshot& first, const Snapshot& second) {
    return first.tick == second.tick && first.content_hash == second.content_hash &&
        first.physical_hash == second.physical_hash &&
        first.ledger == second.ledger && first.cells == second.cells && first.water == second.water;
}
bool same_state(const Snapshot& first, const Snapshot& second) {
    return same_physical_state(first, second) && first.state_hash == second.state_hash;
}
bool quantity_balanced(const Snapshot& value) {
    std::uint64_t produced = 0, consumed = 0;
    for (const auto flow : value.ledger.kinds) { produced += flow.produced; consumed += flow.consumed; }
    return value.water == value.ledger.water_visible + value.ledger.water_overfill + value.ledger.water_ballistic &&
        value.ledger.baseline_water + produced >= consumed &&
        value.water == value.ledger.baseline_water + produced - consumed;
}

struct Run {
    WorldConfig applied;
    Snapshot initial, final, restored;
    TickStats last;
    std::uint64_t visited = 0, moved = 0;
    std::uint32_t observed_workers = 0;
    std::size_t persistence_bytes = 0;
    bool checkpoint_equal = true;
    bool checkpoint_legacy_hash_equal = true;
};
WorldConfig configuration(std::uint32_t workers) {
    WorldConfig config;
    config.worker_threads = workers;
    config.parallel_job_threshold = 1;
    config.active_core_capacity = 512;
    config.active_chunk_capacity = 64;
    config.maximum_chunk_count = 64;
    return config;
}
void advance(World& world, std::uint32_t end, Run* counters = nullptr) {
    while (world.completed_tick_index() < end) {
        // MicroScenarioHost.before_tick dispatches at completed tick 12.
        if (world.completed_tick_index() == 12) {
            for (std::int32_t y = 140; y < 143; ++y)
                for (std::int32_t x = 214; x < 270; ++x) world.set(x, y, Material::Empty);
        }
        const auto stats = world.tick();
        if (counters) {
            counters->visited += stats.visited_cells;
            counters->moved += stats.moved_cells;
            counters->observed_workers = std::max(counters->observed_workers, stats.worker_threads_observed);
            counters->last = stats;
        }
    }
    require(!world.has_failed() && world.completed_tick_index() == end, "World did not complete bounded ticks");
}
Run run(Material first, Material second, Material target, std::uint32_t seed,
        std::uint32_t ticks, std::uint32_t workers, bool persistence) {
    const auto config = configuration(workers);
    // Existing Lab/MicroScenario enclosed bay geometry. Default full Water is
    // equivalent to normalized mass=255, coherence=0 in the accepted fixture.
    const std::array<std::int32_t, 35> rectangles{
        176,64,4,184,1, 304,64,4,184,1, 176,244,132,4,1, 176,64,132,4,1,
        214,140,56,3,1, 224 + static_cast<std::int32_t>(seed % 5),128,32,12,static_cast<std::int32_t>(first),
        180,192,124,52,static_cast<std::int32_t>(second)};
    auto world = demo::construct(config, rectangles);
    world->set_simulation_region(kInterest);
    Run out;
    out.applied = world->config();
    out.initial = capture(*world, target);
    advance(*world, ticks / 2, &out);
    std::unique_ptr<World> restored;
    if (persistence) {
        const auto saved = world->save_physical_state();
        out.persistence_bytes = saved.size();
        restored = World::restore_physical_state(config, saved);
        const auto original_checkpoint = capture(*world, target);
        const auto restored_checkpoint = capture(*restored, target);
        // Native CYPS restore normalizes chunk.quiet_ticks from activity-block
        // flags. That bookkeeping is included in historical state_hash(), but
        // excluded by the owner's versioned complete physical_state_hash().
        // Every stored cell, state byte, quantity and future deadline remains
        // exact; a normalization observation is never hidden as a skipped test.
        out.checkpoint_equal = same_physical_state(original_checkpoint, restored_checkpoint);
        out.checkpoint_legacy_hash_equal = original_checkpoint.state_hash == restored_checkpoint.state_hash;
    }
    advance(*world, ticks, &out);
    out.final = capture(*world, target);
    if (restored) {
        advance(*restored, ticks);
        out.restored = capture(*restored, target);
    }
    return out;
}
void emit_grid(const Snapshot& value) {
    std::cout << "{\"encoding\":\"row-major-rle-v1\",\"rect\":[176,64,132,184],"
        "\"channels\":[\"length\",\"material\",\"state_a\",\"state_b\",\"temperature\"],\"runs\":[";
    bool first = true;
    for (std::size_t index = 0; index < value.cells.size();) {
        auto end = index + 1;
        while (end < value.cells.size() && value.cells[end] == value.cells[index]) ++end;
        if (!first) std::cout << ',';
        std::cout << '[' << end - index;
        for (const auto field : value.cells[index]) std::cout << ',' << field;
        std::cout << ']';
        first = false;
        index = end;
    }
    std::cout << "]}";
}
void emit_configuration(const WorldConfig& config) {
    std::cout << "{\"chunk_size\":" << config.chunk_size << ",\"sleep_after_quiet_ticks\":" << config.sleep_after_quiet_ticks
        << ",\"ambient_temperature\":" << config.ambient_temperature << ",\"backend\":" << static_cast<unsigned>(config.backend)
        << ",\"activity_block_size\":" << config.activity_block_size << ",\"scheduling_core_size\":" << config.scheduling_core_size
        << ",\"maximum_rule_radius\":" << config.maximum_rule_radius << ",\"worker_threads\":" << config.worker_threads
        << ",\"parallel_job_threshold\":" << config.parallel_job_threshold << ",\"active_core_capacity\":" << config.active_core_capacity
        << ",\"active_chunk_capacity\":" << config.active_chunk_capacity << ",\"maximum_chunk_count\":" << config.maximum_chunk_count
        << ",\"transport_configured\":" << config.transport_policy.configured
        << ",\"pressure_gas_compartment_capacity\":" << config.pressure_gas_compartment_capacity
        << ",\"simulation_region\":[168,56,148,200],\"world_extent\":[0,0,1024,1024]}";
}
void emit_snapshot(const Snapshot& value, bool include_grid) {
    std::cout << "{\"completed_ticks\":" << value.tick << ",\"active_chunks\":" << value.active_chunks
        << ",\"content_hash\":\"" << value.content_hash << "\",\"state_hash\":\"" << value.state_hash
        << "\",\"physical_state_hash\":\"" << value.physical_hash << "\",\"liquid_policy_hash\":\"" << value.policy_hash
        << "\",\"water_quantity\":" << value.water << ",\"target_below_reservoir\":" << value.target_below
        << ",\"material_cells\":";
    numbers(value.ledger.material_cells);
    std::cout << ",\"region_counts\":"; numbers(value.region_counts);
    std::cout << ",\"region_sum_y\":"; numbers(value.sum_y);
    std::cout << ",\"quantity_ledger\":{\"schema_version\":" << value.ledger.schema_version
        << ",\"mass_bits\":" << +value.ledger.mass_bits << ",\"baseline_water\":" << value.ledger.baseline_water
        << ",\"water_visible\":" << value.ledger.water_visible << ",\"water_overfill\":" << value.ledger.water_overfill
        << ",\"water_ballistic\":" << value.ledger.water_ballistic << ",\"balanced\":" << quantity_balanced(value)
        << ",\"kinds_produced_consumed\":[";
    for (std::size_t i = 0; i < value.ledger.kinds.size(); ++i) {
        if (i) std::cout << ',';
        std::cout << '[' << value.ledger.kinds[i].produced << ',' << value.ledger.kinds[i].consumed << ']';
    }
    std::cout << "],\"pair_events\":"; numbers(value.ledger.pair_events);
    std::cout << ",\"pair_produced_consumed\":[";
    for (std::size_t i = 0; i < value.ledger.pair_rules.size(); ++i) {
        if (i) std::cout << ',';
        std::cout << '[' << value.ledger.pair_rules[i].produced << ',' << value.ledger.pair_rules[i].consumed << ']';
    }
    std::cout << "]}";
    if (include_grid) { std::cout << ",\"grid\":"; emit_grid(value); }
    std::cout << '}';
}
void emit_endpoint_effects() {
#ifdef CYBERSAND_LAB_EFFECTS_V2
    using namespace cybersand::material_lab_effects;
    const auto emit_endpoint = [](const Endpoint& endpoint) {
        const char* name = endpoint.kind == Kind::ReplaceWithDefaults ? "replace_with_defaults" :
            endpoint.kind == Kind::KeepExisting ? "keep_existing" : "set_state";
        std::cout << "{\"kind\":\"" << name << "\",\"state_b\":" << +endpoint.state_b << '}';
    };
    std::cout << "{\"version\":2,\"extended_slots\":[";
    bool first = true;
    for (std::size_t slot = 0; slot < kPairs.size(); ++slot) {
        if (!is_extended(slot)) continue;
        if (!first) std::cout << ',';
        first = false;
        std::cout << "{\"slot\":" << slot << ",\"first\":";
        emit_endpoint(kPairs[slot].first);
        std::cout << ",\"second\":";
        emit_endpoint(kPairs[slot].second);
        std::cout << '}';
    }
    std::cout << "]}";
#else
    std::cout << "{\"version\":1,\"extended_slots\":[]}";
#endif
}
} // namespace

int main(int argc, char** argv) {
    try {
        if (argc != 7) throw std::invalid_argument("target first second seed ticks workers");
        const auto target = static_cast<Material>(number(argv[1], 131));
        const auto first = static_cast<Material>(number(argv[2], 131));
        const auto second = static_cast<Material>(number(argv[3], 131));
        const auto seed = number(argv[4], 0x7FFFFFFFU), ticks = number(argv[5], 600), workers = number(argv[6], 4);
        require(valid_material(static_cast<std::uint16_t>(target)) && target != Material::Empty &&
            valid_material(static_cast<std::uint16_t>(first)) && valid_material(static_cast<std::uint16_t>(second)) &&
            (target == first || target == second) && ticks > 0 && (workers == 1 || workers == 4), "Fixture inputs refused");
        verify_tables();
#ifdef CYBERSAND_LAB_EFFECTS_V2
        const auto effect_contract_checks = cybersand::material_lab_effects_probe::verify();
#else
        const std::string effect_contract_checks = "{\"executed\":false,\"reason\":\"legacy backend\"}";
#endif
        const auto primary = run(first, second, target, seed, ticks, workers, true);
        const auto repeated = run(first, second, target, seed, ticks, workers, false);
        const auto alternate = run(first, second, target, seed, ticks, workers == 1 ? 4U : 1U, false);
        const bool repeat_ok = same_state(primary.final, repeated.final);
        const bool workers_ok = same_state(primary.final, alternate.final);
        const bool persistence_ok = primary.checkpoint_equal && same_physical_state(primary.final, primary.restored);
        const bool quantity_ok = quantity_balanced(primary.initial) && quantity_balanced(primary.final) &&
            quantity_balanced(primary.restored) && quantity_balanced(repeated.final) && quantity_balanced(alternate.final);
        const auto& descriptor = MaterialRules::descriptor(target);
        std::cout << std::boolalpha << "{\"ok\":" << (repeat_ok && workers_ok && persistence_ok && quantity_ok)
            << ",\"runtime_active\":false,\"backend\":\"isolated_native_world_v1\",\"world_simulation\":true,\"table_checks\":" << table_checks
            << ",\"checks\":{\"deterministic_repeat\":" << repeat_ok << ",\"worker_1_4_equal\":" << workers_ok
            << ",\"persistence_checkpoint\":" << primary.checkpoint_equal << ",\"persistence_replay\":" << persistence_ok
            << ",\"quantity_balanced\":" << quantity_ok << "},\"persistence_bytes\":" << primary.persistence_bytes
            << ",\"persistence_checkpoint_legacy_hash_equal\":" << primary.checkpoint_legacy_hash_equal
            << ",\"persistence_comparison\":\"Exact physical_state_hash, content, stored cells, state, quantity and ticks; native restore normalizes legacy chunk.quiet_ticks bookkeeping\""
            << ",\"requested_workers\":" << workers << ",\"observed_workers\":" << primary.observed_workers
            << ",\"worker_1_observed\":" << (workers == 1 ? primary.observed_workers : alternate.observed_workers)
            << ",\"worker_4_observed\":" << (workers == 4 ? primary.observed_workers : alternate.observed_workers)
            << ",\"visited_cells\":" << primary.visited << ",\"moved_cells\":" << primary.moved
            << ",\"last_tick\":{\"visited_cells\":" << primary.last.visited_cells << ",\"moved_cells\":" << primary.last.moved_cells
            << ",\"active_chunks_after\":" << primary.last.active_chunks_after << ",\"active_blocks_after\":" << primary.last.active_blocks_after
            << ",\"scheduled_cores\":" << primary.last.scheduled_cores << "},\"descriptor_readback\":{\"id\":" << static_cast<unsigned>(target)
            << ",\"density\":" << descriptor.density << ",\"viscosity_index\":" << +descriptor.viscosity_index
            << ",\"kernel\":" << static_cast<unsigned>(descriptor.kernel) << ",\"rgba\":";
        numbers(descriptor.rgba);
        std::cout << "},\"configuration\":"; emit_configuration(primary.applied);
        std::cout << ",\"endpoint_effects\":"; emit_endpoint_effects();
        std::cout << ",\"effect_contract_checks\":" << effect_contract_checks;
        std::cout << ",\"palette_rgba\":[";
        for (std::size_t i = 0; i < kMaterialDefinitions.size(); ++i) { if (i) std::cout << ','; numbers(kMaterialDefinitions[i].rgba); }
        std::cout << "],\"initial\":"; emit_snapshot(primary.initial, true);
        std::cout << ",\"final\":"; emit_snapshot(primary.final, true);
        std::cout << ",\"repeat\":"; emit_snapshot(repeated.final, false);
        std::cout << ",\"worker_1\":"; emit_snapshot(workers == 1 ? primary.final : alternate.final, false);
        std::cout << ",\"worker_4\":"; emit_snapshot(workers == 4 ? primary.final : alternate.final, false);
        std::cout << ",\"restored\":"; emit_snapshot(primary.restored, false);
        std::cout << "}\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Isolated native World test refused: " << error.what() << '\n';
        return 2;
    }
}
