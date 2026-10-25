// LCB-001 (#200) pressure_flow_v1/reference native regressions: admission and
// refusal, gas-compartment identity on the registered acceptance geometries,
// Empty/unallocated gas survival, exact quantity, 1/4-worker parity, barriers,
// lifecycle ledgers, the versioned physical-state hash and exact persistence.
#include "cybersand/liquid_solver_policy.hpp"
#include "cybersand/sha256.hpp"
#include "cybersand/world.hpp"
#include "cybersand/liquid_run_receipt_native_capture.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <functional>
#include <iostream>
#include <limits>
#include <memory>
#include <optional>
#include <span>
#include <stdexcept>
#include <string>
#include <tuple>
#include <vector>

namespace {

using cybersand::GasCompartmentSnapshot;
using cybersand::GasRetireReason;
using cybersand::LiquidPolicyBuild;
using cybersand::LiquidPolicyRefusalCode;
using cybersand::LiquidSolverFamily;
using cybersand::LiquidSolverPolicy;
using cybersand::Material;
using cybersand::RectI64;
using cybersand::World;
using cybersand::WorldConfig;

void require(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}

constexpr std::size_t kWaterFamilyWord = 20U + 1U;  // Water is the first liquid row

std::vector<std::int32_t> pressure_request(std::optional<std::pair<int, int>> block = std::nullopt,
                                           std::int32_t variant = 0) {
    auto words = LiquidSolverPolicy::default_request();
    words[kWaterFamilyWord] = 3;
    words[kWaterFamilyWord + 1U] = variant;
    if (block) {
        const auto family_count_at = words.size() - 2U;
        words[family_count_at] = 1;
        words.insert(words.begin() + static_cast<std::ptrdiff_t>(family_count_at) + 1,
                     {3, 1, 2, block->first, block->second});
    }
    return words;
}

LiquidSolverPolicy pressure_policy(std::optional<std::pair<int, int>> block = std::nullopt) {
    const auto words = pressure_request(block);
    auto result = LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
    require(result.accepted(), "pressure policy refused: " + result.refusal.message());
    return *result.policy;
}

WorldConfig pressure_config(std::uint32_t workers = 1) {
    WorldConfig config;
    config.liquid_solver_policy = pressure_policy();
    config.worker_threads = workers;
    config.sleep_after_quiet_ticks = 3;
    return config;
}

void rect(World& world, std::int64_t x, std::int64_t y, std::int64_t w, std::int64_t h, Material m) {
    for (auto yy = y; yy < y + h; ++yy)
        for (auto xx = x; xx < x + w; ++xx) {
            if (m == Material::Water)
                require(world.set_cell_state(xx, yy, Material::Water, world.config().water_experiment_policy.maximum(), 0),
                        "Water fill");
            else if (m == Material::Empty)
                (void)world.set_cell_state(xx, yy, Material::Empty, 0, 0);
            else
                world.set(xx, yy, m);
        }
}

// Registered acceptance room: Walls y=8/y=20 and x0/x0+11, Water floor y=19,
// 10x10 = 100-cell air pocket.
void room(World& world, std::int64_t x0) {
    rect(world, x0, 8, 12, 1, Material::Wall);
    rect(world, x0, 20, 12, 1, Material::Wall);
    rect(world, x0, 8, 1, 13, Material::Wall);
    rect(world, x0 + 11, 8, 1, 13, Material::Wall);
    rect(world, x0 + 1, 19, 10, 1, Material::Water);
}

void tick(World& world, int count = 1) {
    for (int i = 0; i < count; ++i) (void)world.tick();
}

std::vector<GasCompartmentSnapshot> live(const World& world) { return world.gas_compartments(); }

const GasCompartmentSnapshot* find_anchor(const std::vector<GasCompartmentSnapshot>& list, std::int64_t x,
                                          std::int64_t y) {
    for (const auto& c : list)
        if (c.anchor_x == x && c.anchor_y == y) return &c;
    return nullptr;
}

std::uint64_t quantity(const World& world, RectI64 r) { return world.water_quantity(r); }

std::vector<std::uint8_t> with_gas_next_id(const World& world, std::uint32_t next_id) {
    require(world.pressure_flow_enabled() && world.gas_history().empty(), "gas ID codec fixture has no history");
    auto bytes = world.save_physical_state();
    // Frozen CYPS2 pressure tail: next ID, topology revision, table count,
    // 97-byte live records, history count/cursor, ten gas and five flow totals.
    const auto tail = 4U + 8U + 4U + world.gas_compartments().size() * 97U + 8U + 10U * 8U + 5U * 8U;
    require(bytes.size() > 32U + tail, "gas ID fixture contains the pressure tail");
    const auto at = bytes.size() - 32U - tail;
    std::uint32_t previous = 0;
    for (std::size_t i = 0; i < 4U; ++i) previous |= static_cast<std::uint32_t>(bytes[at + i]) << (8U * i);
    require(bytes[at - 1U] == 1U && previous == world.gas_next_id(), "gas ID tail offset matches native readback");
    for (std::size_t i = 0; i < 4U; ++i) bytes[at + i] = static_cast<std::uint8_t>(next_id >> (8U * i));
    const auto digest = cybersand::Sha256::of(std::span<const std::uint8_t>(bytes.data(), bytes.size() - 32U));
    std::copy(digest.begin(), digest.end(), bytes.end() - 32);
    return bytes;
}

WorldConfig small_gas_config() {
    auto config = pressure_config();
    config.chunk_size = 32;
    config.activity_block_size = 8;
    config.scheduling_core_size = 16;
    config.initial_chunk_reserve = 2;
    config.maximum_chunk_count = 128;
    config.active_chunk_capacity = 128;
    config.active_core_capacity = 128;
    return config;
}

void require_gas_id_exhaustion(World& world) {
    const auto completed = world.completed_tick_index();
    const auto before = world.gas_compartments();
    bool refused = false;
    try { tick(world); }
    catch (const std::runtime_error& error) {
        refused = std::string(error.what()).find("pressure gas identity capacity exhausted") != std::string::npos;
    }
    require(refused && world.has_failed() && world.completed_tick_index() == completed &&
                world.tick_index() == completed + 1U,
            "gas ID exhaustion fails explicitly and quarantines the attempted tick");
    require(world.gas_next_id() == cybersand::kVacuumLabel, "exhausted gas ID sentinel never advances or wraps");
    const auto after = world.gas_compartments();
    require(after.size() == before.size(), "failed allocation retains the prior compartment identities");
    for (std::size_t i = 0; i < after.size(); ++i)
        require(after[i].id == before[i].id && after[i].id > 0U && after[i].id < cybersand::kVacuumLabel,
                "exhaustion never installs an unresolved or reserved compartment ID");
    bool quarantined = false;
    try { tick(world); }
    catch (const std::logic_error&) { quarantined = true; }
    require(quarantined && world.completed_tick_index() == completed, "failed gas topology cannot resume");
}

// -------------------------------------------------------------------- tests

void test_gas_id_restore_bounds() {
    auto config = std::make_unique<WorldConfig>(small_gas_config());
    auto empty = std::make_unique<World>(*config);
    const auto before_hash = empty->physical_state_hash();
    for (const auto invalid : {std::uint32_t{0}, cybersand::kAtmosphereLabel}) {
        bool refused = false;
        try { (void)World::restore_physical_state(*config, with_gas_next_id(*empty, invalid)); }
        catch (const std::invalid_argument&) { refused = true; }
        require(refused, "invalid next gas ID refuses even with an empty compartment table");
    }
    for (const auto admitted : {std::uint32_t{1}, cybersand::kVacuumLabel}) {
        const auto bytes = with_gas_next_id(*empty, admitted);
        auto restored = World::restore_physical_state(*config, bytes);
        require(restored->gas_next_id() == admitted && restored->save_physical_state() == bytes,
                "valid next gas ID and exhausted sentinel restore exactly");
        tick(*restored);
        require(!restored->has_failed() && restored->gas_next_id() == admitted && restored->gas_compartments().empty(),
                "no-allocation topology can continue with an exhausted ID sentinel");
    }
    require(empty->physical_state_hash() == before_hash, "gas ID restore attempts leave the caller untouched");
}

void test_gas_id_creation_exhaustion() {
    auto config = std::make_unique<WorldConfig>(small_gas_config());
    auto prepared = std::make_unique<World>(*config);
    room(*prepared, 8);
    auto world = World::restore_physical_state(*config, with_gas_next_id(*prepared, cybersand::kVacuumLabel - 1U));
    tick(*world);
    auto compartments = world->gas_compartments();
    require(compartments.size() == 1U && compartments[0].id == cybersand::kVacuumLabel - 1U &&
                compartments[0].amount == 100U && world->gas_next_id() == cybersand::kVacuumLabel &&
                world->pressure_cell(9, 9).gas == compartments[0].id,
            "real compartment creation consumes the last valid ID without using a reserved label");
    auto restored = World::restore_physical_state(*config, world->save_physical_state());
    tick(*world);
    tick(*restored);
    require(world->physical_state_hash() == restored->physical_state_hash() && !world->has_failed(),
            "existing last-ID compartment continues exactly without allocating an identity");
    room(*world, 32);
    require_gas_id_exhaustion(*world);
}

void test_gas_id_split_exhaustion() {
    auto config = std::make_unique<WorldConfig>(small_gas_config());
    auto prepared = std::make_unique<World>(*config);
    room(*prepared, 8);
    tick(*prepared);
    const auto parent = prepared->gas_compartments().at(0).id;
    auto world = World::restore_physical_state(*config, with_gas_next_id(*prepared, cybersand::kVacuumLabel - 2U));
    rect(*world, 13, 9, 1, 10, Material::Wall);
    tick(*world);
    const auto compartments = world->gas_compartments();
    require(compartments.size() == 2U && compartments[0].id == cybersand::kVacuumLabel - 2U &&
                compartments[1].id == cybersand::kVacuumLabel - 1U &&
                compartments[0].amount + compartments[1].amount == 100U &&
                world->gas_next_id() == cybersand::kVacuumLabel && world->gas_ledger().splits == 1U,
            "real split allocates the final two valid IDs and conserves the parent gas");
    for (const auto& child : compartments)
        require(child.parent_count == 1U && child.parents[0] == parent && child.generation == 1U,
                "near-exhaustion split preserves fresh child identity and ancestry");
    rect(*world, 11, 9, 1, 10, Material::Wall);
    require_gas_id_exhaustion(*world);
}

void test_quantity_rectangle_bounds() {
    auto world = std::make_unique<World>(pressure_config());
    require(world->set_cell_state(3, 4, Material::Water, 17, 0), "quantity query fixture");
    const auto before_hash = world->physical_state_hash();
    const auto before_ledger = world->quantity_ledger();
    const auto unchanged = [&]() {
        require(world->physical_state_hash() == before_hash && world->quantity_ledger() == before_ledger,
                "quantity query changed physical state or accounting");
    };
    constexpr auto minimum = std::numeric_limits<std::int64_t>::min();
    constexpr auto maximum = std::numeric_limits<std::int64_t>::max();
    for (const auto bounds : std::array<RectI64, 4>{{
             {0, 0, -1, 1}, {0, 0, 1, -1}, {maximum, maximum, 0, -1}, {maximum, maximum, -1, 0}}}) {
        bool refused = false;
        try { (void)world->water_quantity(bounds); }
        catch (const std::invalid_argument&) { refused = true; }
        require(refused, "negative quantity query dimension must refuse");
        unchanged();
    }
    for (const auto bounds : std::array<RectI64, 4>{{
             {maximum, 0, 2, 1}, {0, maximum, 1, 2},
             {maximum - 1, 0, 3, 1}, {0, maximum - 1, 1, 3}}}) {
        bool refused = false;
        try { (void)world->water_quantity(bounds); }
        catch (const std::overflow_error&) { refused = true; }
        require(refused, "overflowing quantity query inclusive endpoint must refuse");
        unchanged();
    }
    for (const auto bounds : std::array<RectI64, 6>{{
             {maximum, maximum, 1, 1}, {minimum, minimum, 1, 1},
             {maximum - 1, maximum - 1, 2, 2}, {minimum, minimum, 2, 2},
             {maximum, maximum, 0, maximum}, {maximum, maximum, maximum, 0}}}) {
        require(world->water_quantity(bounds) == 0U, "empty extreme/zero-area quantity query");
        unchanged();
    }
    require(world->water_quantity({3, 4, 1, 1}) == 17U &&
                world->water_quantity({2, 3, 3, 3}) == 17U,
            "bounded quantity queries retain exact partial Water");
    unchanged();
}

void test_pending_event_restore_bounds() {
    auto config = std::make_unique<WorldConfig>(pressure_config());
    config->liquid_solver_policy = pressure_policy(std::pair{0, 64});
    config->chunk_size = 32;
    config->activity_block_size = 8;
    config->scheduling_core_size = 16;
    auto original = std::make_unique<World>(*config);
    constexpr std::int64_t event_x = 0x0102030405060708LL;
    constexpr std::int64_t event_y = 0x1112131415161718LL;
    require(original->queue_explosion(event_x, event_y, 1, 17), "ordinary pending event admission");
    const auto saved = original->save_physical_state();
    const auto original_hash = original->physical_state_hash();
    const auto original_ledger = original->quantity_ledger();
    std::array<std::uint8_t, 16> marker{};
    for (std::size_t i = 0; i < 8U; ++i) {
        marker[i] = static_cast<std::uint8_t>(static_cast<std::uint64_t>(event_x) >> (8U * i));
        marker[8U + i] = static_cast<std::uint8_t>(static_cast<std::uint64_t>(event_y) >> (8U * i));
    }
    const auto event = std::search(saved.begin(), saved.end() - 32, marker.begin(), marker.end());
    require(event != saved.end() - 32 &&
                std::search(event + 1, saved.end() - 32, marker.begin(), marker.end()) == saved.end() - 32,
            "pending event coordinates are uniquely located in the saved fixture");
    const auto event_offset = static_cast<std::size_t>(event - saved.begin());
    const auto edited_event = [&](std::size_t axis, std::int64_t coordinate) {
        auto bytes = saved;
        for (std::size_t i = 0; i < 8U; ++i)
            bytes[event_offset + axis * 8U + i] =
                static_cast<std::uint8_t>(static_cast<std::uint64_t>(coordinate) >> (8U * i));
        const auto digest = cybersand::Sha256::of(std::span<const std::uint8_t>(bytes.data(), bytes.size() - 32U));
        std::copy(digest.begin(), digest.end(), bytes.end() - 32);
        return bytes;
    };
    constexpr auto minimum = std::numeric_limits<std::int64_t>::min();
    constexpr auto maximum = std::numeric_limits<std::int64_t>::max();
    // Radius 1 uses the same R+2 coordinate margin at ingress and restore.
    for (const auto axis : {std::size_t{0}, std::size_t{1}}) {
        for (const auto coordinate : {minimum, minimum + 2, maximum - 2, maximum}) {
            const auto x = axis == 0U ? coordinate : event_x;
            const auto y = axis == 1U ? coordinate : event_y;
            require(!original->queue_explosion(x, y, 1, 17), "invalid event coordinate refused at ingress");
            bool refused = false;
            try { (void)World::restore_physical_state(*config, edited_event(axis, coordinate)); }
            catch (const std::invalid_argument&) { refused = true; }
            require(refused, "valid-digest pending event outside the ingress margin must refuse");
            require(original->physical_state_hash() == original_hash && original->quantity_ledger() == original_ledger,
                    "failed pending-event restore changed the caller World");
        }
        for (const auto coordinate : {minimum + 3, maximum - 3}) {
            const auto bytes = edited_event(axis, coordinate);
            auto restored = World::restore_physical_state(*config, bytes);
            require(restored->save_physical_state() == bytes,
                    "pending event at the inclusive coordinate margin restores exactly");
        }
    }
    auto continuous = std::make_unique<World>(*config);
    continuous->reserve_temperature_region({0, 0, 32, 32});
    require(continuous->set_cell_state(4, 4, Material::Water, 17, 0), "pending event partial Water fixture");
    continuous->set_temperature(4, 4, 777);
    require(continuous->queue_explosion(4, 4, 1, 17), "pending event continuation fixture");
    auto execution = std::make_unique<WorldConfig>(*config);
    execution->worker_threads = 4;
    execution->parallel_job_threshold = 1;
    auto restored = World::restore_physical_state(*execution, continuous->save_physical_state());
    require(restored->physical_state_hash() == continuous->physical_state_hash(),
            "ordinary pending event restores the exact initial state");
    for (int t = 0; t < 4; ++t) {
        tick(*continuous);
        tick(*restored);
        require(restored->physical_state_hash() == continuous->physical_state_hash() &&
                    restored->state_hash() == continuous->state_hash() &&
                    restored->quantity_ledger() == continuous->quantity_ledger(),
                "ordinary pending event preserves exact continuation and accounting across workers");
    }
    require(continuous->quantity_ledger().kinds[static_cast<std::size_t>(cybersand::QuantityKind::DeferredEvent)].consumed == 17U,
            "restored ordinary event books the actual partial Water sink once");
}

void test_pressure_admission_and_refusal() {
    const auto& running = LiquidPolicyBuild::running();
    require(running.available_families == 0x0FU && running.schemas.size() == 3U &&
            running.schemas.back().family_owner && running.schemas.back().owner == 4U &&
            running.schemas.back().version == 2U && !running.schemas.back().mandatory &&
            running.schemas.back().fields.size() == 1U &&
            running.schemas.back().fields[0].name == "damping_numerator" &&
            running.schemas.back().fields[0].minimum == 0 && running.schemas.back().fields[0].maximum == 16, "running build profile");
    const auto policy = pressure_policy();
    require(policy.assignment(3)->family == LiquidSolverFamily::PressureFlowV1, "Water applied family");
    for (std::int32_t variant : {0, 1, 2}) {
        const auto words = pressure_request(std::nullopt, variant);
        const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
        require(decoded.accepted() && decoded.policy->assignment(3)->variant ==
                    static_cast<cybersand::LiquidSolverVariant>(variant),
                "running pressure implementation preserves the exact selected variant");
    }
    // Parameter block: accepted in range, refused outside it.
    const auto with_block = pressure_policy(std::pair{0, 64});
    require(!(with_block == policy), "parameter block changes identity");
    const auto bad = pressure_request(std::pair{0, 8});
    const auto refused = LiquidSolverPolicy::decode(std::span<const std::int32_t>(bad));
    require(!refused.accepted() && refused.refusal.code == LiquidPolicyRefusalCode::MalformedPolicy,
            "atmospheric_head_rows below range refused");
    // Oil x pressure and cached Water x inertial stay refused.
    auto oil = LiquidSolverPolicy::default_request();
    oil[20U + 3U * 3U + 1U] = 3;
    require(LiquidSolverPolicy::decode(std::span<const std::int32_t>(oil)).refusal.code ==
                LiquidPolicyRefusalCode::CombinationRejected,
            "Oil x pressure rejected");
    auto inertial = LiquidSolverPolicy::default_request();
    inertial[kWaterFamilyWord] = 4;
    inertial[kWaterFamilyWord + 1U] = 1;
    require(LiquidSolverPolicy::decode(std::span<const std::int32_t>(inertial)).refusal.code ==
                LiquidPolicyRefusalCode::VariantUnsupported,
            "Water x inertial cached remains unsupported");
    World pressure(pressure_config());
    World current;
    require(pressure.pressure_flow_enabled() && !current.pressure_flow_enabled(), "family dispatch identity");
    require(pressure.pressure_flow_parameters().atmospheric_head_rows == 32 &&
                pressure.pressure_flow_parameters().gas_enabled,
            "default family parameters");
    WorldConfig gasless = pressure_config();
    gasless.liquid_solver_policy = with_block;
    World tuned(gasless);
    require(!tuned.pressure_flow_parameters().gas_enabled &&
                tuned.pressure_flow_parameters().atmospheric_head_rows == 64,
            "family block applied");
    require(!current.pressure_cell(0, 0).available && pressure.pressure_cell(0, 0).available,
            "sidecar availability");
}

void run_gas_fixture(std::uint32_t workers,
                     const std::function<void(World&)>& setup,
                     const std::function<void(World&, std::uint64_t)>& events,
                     const std::function<void(World&, std::uint64_t)>& check, std::uint64_t horizon) {
    World world(pressure_config(workers));
    world.reserve_region({0, 0, 128, 128});
    setup(world);
    for (std::uint64_t completed = 0; completed <= horizon; ++completed) {
        if (completed > 0) check(world, completed);
        events(world, completed);  // events indexed N run after completed tick N
        if (completed < horizon) tick(world);
    }
}

void test_gas_single_and_twin_pockets() {
    for (const std::uint32_t workers : {1U, 4U}) {
        std::uint32_t first_id = 0;
        run_gas_fixture(workers, [](World& w) { room(w, 8); }, [](World&, std::uint64_t) {},
            [&](World& w, std::uint64_t t) {
                const auto list = live(w);
                require(list.size() == 1U, "single pocket: one compartment at t" + std::to_string(t));
                require(list[0].amount == 100U && list[0].volume == 100U, "single pocket amount/volume 100");
                if (first_id == 0U) first_id = list[0].id;
                require(list[0].id == first_id && list[0].generation == 0U, "single pocket stable identity");
                require(list[0].anchor_x == 9 && list[0].anchor_y == 9, "single pocket anchor");
            }, 10);
        std::vector<std::uint32_t> ids;
        run_gas_fixture(workers, [](World& w) { room(w, 8); room(w, 32); }, [](World&, std::uint64_t) {},
            [&](World& w, std::uint64_t t) {
                const auto list = live(w);
                require(list.size() == 2U, "twin pockets: two compartments at t" + std::to_string(t));
                for (const auto& c : list)
                    require(c.amount == 100U && c.volume == 100U, "twin pockets keep 100 each (no cycling)");
                std::vector<std::uint32_t> now{list[0].id, list[1].id};
                require(now[0] != now[1], "twin pockets distinct identities");
                if (ids.empty()) ids = now;
                require(now == ids, "twin pocket identities are stable");
            }, 10);
    }
}

void test_gas_unequal_merge() {
    for (const std::uint32_t workers : {1U, 4U}) {
        std::uint32_t a = 0;
        std::uint32_t b = 0;
        run_gas_fixture(workers,
            [](World& w) {
                room(w, 8);
                rect(w, 19, 8, 14, 1, Material::Wall);
                rect(w, 19, 20, 14, 1, Material::Wall);
                rect(w, 32, 8, 1, 13, Material::Wall);
                rect(w, 20, 19, 12, 1, Material::Water);
            },
            [](World& w, std::uint64_t t) {
                if (t == 1) rect(w, 19, 13, 1, 1, Material::Empty);
            },
            [&](World& w, std::uint64_t t) {
                const auto list = live(w);
                if (t <= 1) {
                    require(list.size() == 2U, "merge: two pockets before the erase");
                    const auto* left = find_anchor(list, 9, 9);
                    const auto* right = find_anchor(list, 20, 9);
                    require(left && right && left->amount == 100U && right->amount == 120U,
                            "merge: 100 and 120 before the erase");
                    a = left->id;
                    b = right->id;
                    return;
                }
                require(list.size() == 1U, "merge: one pocket after the erase");
                const auto& merged = list[0];
                require(merged.amount == 220U && merged.volume == 221U, "merge sums once to 220 (221 cells)");
                require(merged.id == std::min(a, b) && merged.generation == 1U && merged.parent_count == 2U &&
                            merged.parents[0] == std::min(a, b) && merged.parents[1] == std::max(a, b),
                        "merge survivor id, generation and ancestry");
                const auto ledger = w.gas_ledger();
                require(ledger.merges == 1U && ledger.amount_live == 220U, "merge ledger");
                const auto history = w.gas_history();
                require(!history.empty() && history.back().compartment.id == std::max(a, b) &&
                            history.back().reason == GasRetireReason::Merged,
                        "merged parent retired into history");
            }, 10);
    }
}

void test_gas_compress_vent_reseal() {
    for (const std::uint32_t workers : {1U, 4U}) {
        std::uint32_t original = 0;
        std::uint32_t resealed = 0;
        std::uint64_t vents_before = 0;
        run_gas_fixture(workers,
            [](World& w) {
                room(w, 8);
                rect(w, 20, 11, 5, 1, Material::Wall);
                rect(w, 20, 13, 3, 1, Material::Wall);
                rect(w, 22, 13, 1, 4, Material::Wall);
                rect(w, 24, 11, 1, 5, Material::Wall);
                rect(w, 22, 17, 5, 1, Material::Wall);
                rect(w, 26, 9, 1, 9, Material::Wall);
            },
            [](World& w, std::uint64_t t) {
                if (t == 1) rect(w, 9, 14, 10, 5, Material::Water);
                if (t == 5) rect(w, 19, 12, 1, 1, Material::Empty);
                if (t == 9) rect(w, 23, 16, 3, 1, Material::Water);
            },
            [&](World& w, std::uint64_t t) {
                const auto list = live(w);
                const auto ledger = w.gas_ledger();
                if (t == 1) {
                    require(list.size() == 1U && list[0].volume == 100U && list[0].amount == 100U, "reseal t1");
                    original = list[0].id;
                } else if (t >= 2 && t <= 5) {
                    require(list.size() == 1U && list[0].id == original && list[0].volume == 50U &&
                                list[0].amount == 100U && list[0].generation == 0U,
                            "compression keeps id and amount at half volume");
                    require(list[0].gauge > 0, "compressed gauge is positive");
                    vents_before = ledger.vents;
                } else if (t >= 6 && t <= 9) {
                    require(list.empty(), "vented: no sealed compartment");
                    require(ledger.vents == vents_before + 1U && ledger.vented == 100U, "vent exchange ledger");
                    const auto history = w.gas_history();
                    require(!history.empty() && history.back().compartment.id == original &&
                                history.back().reason == GasRetireReason::Vented,
                            "vent recorded in history");
                } else {
                    require(list.size() == 1U && list[0].volume == 58U && list[0].amount == 58U,
                            "reseal: new 58-cell compartment at atmospheric amount");
                    require(list[0].id != original && list[0].generation == 0U, "reseal: a NEW id");
                    if (resealed == 0U) resealed = list[0].id;
                    require(list[0].id == resealed, "reseal id stable");
                    require(w.water_quantity({23, 16, 3, 1}) == 3U * 255U, "trap stays three full cells");
                }
            }, 30);
    }
}

void test_gas_split() {
    for (const std::uint32_t workers : {1U, 4U}) {
        std::uint32_t parent = 0;
        run_gas_fixture(workers,
            [](World& w) {
                room(w, 8);
                room(w, 32);
                rect(w, 20, 11, 12, 1, Material::Wall);
                rect(w, 20, 13, 3, 1, Material::Wall);
                rect(w, 22, 13, 1, 4, Material::Wall);
                rect(w, 24, 12, 1, 4, Material::Wall);
                rect(w, 22, 17, 5, 1, Material::Wall);
                rect(w, 26, 13, 1, 4, Material::Wall);
                rect(w, 26, 13, 6, 1, Material::Wall);
                rect(w, 19, 12, 1, 1, Material::Empty);
                rect(w, 32, 12, 1, 1, Material::Empty);
            },
            [](World& w, std::uint64_t t) {
                if (t == 3) rect(w, 23, 16, 3, 1, Material::Water);
            },
            [&](World& w, std::uint64_t t) {
                const auto list = live(w);
                if (t <= 3) {
                    require(list.size() == 1U && list[0].volume == 222U && list[0].amount == 222U,
                            "split: one 222-cell compartment before the trap fill");
                    parent = list[0].id;
                    return;
                }
                require(list.size() == 2U, "split: two compartments at t" + std::to_string(t));
                const auto* a = find_anchor(list, 9, 9);
                const auto* b = find_anchor(list, 33, 9);
                require(a && b, "split anchors");
                require(a->volume == 108U && b->volume == 111U, "split volumes 108/111");
                require(a->amount == 110U && b->amount == 112U, "split amounts 110/112 (remainder to lowest y,x)");
                require(a->id != parent && b->id != parent && a->id < b->id, "split: two NEW ids");
                require(a->parent_count == 1U && a->parents[0] == parent && b->parent_count == 1U &&
                            b->parents[0] == parent && a->generation == 1U,
                        "split ancestry and generation");
                require(w.gas_ledger().splits == 1U && w.gas_ledger().amount_live == 222U, "split ledger sums");
                require(w.water_quantity({23, 16, 3, 1}) == 3U * 255U, "split trap stays three full cells");
            }, 30);
    }
}

void test_gas_empty_only_and_unallocated() {
    // chunk_size 8: the pocket interior (x 9..30, y 9..30) fully contains chunks
    // (16,16)-(23,23) that nothing ever writes, so one World leaves them
    // unallocated while its twin reserves the whole region.
    const auto build = [](bool reserve) {
        WorldConfig config = pressure_config();
        config.chunk_size = 8;
        config.activity_block_size = 8;
        config.scheduling_core_size = 8;
        auto world = std::make_unique<World>(config);
        if (reserve) world->reserve_region({0, 0, 48, 48});
        rect(*world, 8, 8, 24, 1, Material::Wall);
        rect(*world, 8, 32, 24, 1, Material::Wall);
        rect(*world, 8, 8, 1, 25, Material::Wall);
        rect(*world, 31, 8, 1, 25, Material::Wall);
        rect(*world, 9, 31, 22, 1, Material::Water);
        return world;
    };
    auto sparse = build(false);
    auto dense = build(true);
    const auto before_chunks = sparse->chunk_count();
    for (int t = 0; t < 6; ++t) {
        tick(*sparse);
        tick(*dense);
        const auto a = live(*sparse);
        const auto b = live(*dense);
        require(a.size() == 1U && b.size() == 1U, "empty-only pocket tracked in both Worlds");
        require(a[0].volume == 22U * 22U && a[0].amount == a[0].volume && a[0].volume == b[0].volume &&
                    a[0].amount == b[0].amount && a[0].id == b[0].id,
                "gas independent of chunk allocation");
        require(sparse->physical_state_hash() == dense->physical_state_hash(),
                "physical-state hash independent of all-Empty chunk allocation");
    }
    require(sparse->chunk_count() > before_chunks, "sealed unallocated chunk became resident for its labels");

    // A body mask can cross a chunk with no stored cells. That chunk is not a
    // uniformly Empty gas node: the mask must separate the two air pockets in
    // both the sparse and explicitly resident representations.
    const auto masked = [](bool reserve) {
        auto config = pressure_config();
        config.chunk_size = 8;
        config.activity_block_size = 8;
        config.scheduling_core_size = 8;
        auto world = std::make_unique<World>(config);
        if (reserve) world->reserve_region({0, 0, 40, 40});
        rect(*world, 8, 8, 24, 1, Material::Wall);
        rect(*world, 8, 31, 24, 1, Material::Wall);
        rect(*world, 8, 8, 1, 24, Material::Wall);
        rect(*world, 31, 8, 1, 24, Material::Wall);
        rect(*world, 9, 30, 22, 1, Material::Water);
        world->configure_transient_obstacles({0, 0, 40, 40});
        for (std::int64_t y = 9; y < 31; ++y)
            require(world->set_transient_obstacle(20, y, 1), "sparse gas divider mask");
        return world;
    };
    sparse = masked(false);
    dense = masked(true);
    for (int t = 0; t < 3; ++t) {
        tick(*sparse);
        tick(*dense);
        const auto a = live(*sparse);
        const auto b = live(*dense);
        require(a.size() == 2U && b.size() == 2U, "sparse mask separates two gas compartments");
        require(a[0].volume == 231U && a[1].volume == 210U &&
                    a[0].amount == 231U && a[1].amount == 210U,
                "masked cells excluded from the two gas volumes and amounts");
        require(sparse->physical_state_hash() == dense->physical_state_hash(),
                "masked gas independent of all-Empty chunk allocation");
    }
}

void build_dam(World& world, std::int64_t depth) {
    rect(world, 8, 120, 112, 2, Material::Wall);
    rect(world, 8, 40, 2, 80, Material::Wall);
    rect(world, 118, 40, 2, 80, Material::Wall);
    rect(world, 40, 40, 2, 80, Material::Wall);  // gate
    rect(world, 10, 120 - depth, 30, depth, Material::Water);
}

void test_quantity_parity_and_motion() {
    World one(pressure_config(1));
    World four(pressure_config(4));
    for (World* w : {&one, &four}) {
        w->reserve_region({0, 0, 128, 128});
        build_dam(*w, 64);
    }
    const RectI64 all{0, 0, 128, 128};
    const auto initial = quantity(one, all);
    rect(one, 40, 40, 2, 80, Material::Empty);
    rect(four, 40, 40, 2, 80, Material::Empty);
    std::int64_t rightmost = 0;
    for (int t = 1; t <= 120; ++t) {
        tick(one);
        tick(four);
        require(quantity(one, all) == initial && quantity(four, all) == initial,
                "visible+overfill quantity exact at t" + std::to_string(t));
        require(one.physical_state_hash() == four.physical_state_hash() && one.state_hash() == four.state_hash(),
                "1/4-worker physical-state parity at t" + std::to_string(t));
    }
    for (std::int64_t x = 117; x >= 40; --x)
        if (one.stored_material(x, 119) == Material::Water) {
            rightmost = x;
            break;
        }
    require(rightmost >= 100, "released dam advances (front " + std::to_string(rightmost) + ")");
    bool any_flow = false;
    for (std::int64_t x = 40; x < 118 && !any_flow; ++x)
        for (std::int64_t y = 100; y < 120 && !any_flow; ++y) any_flow = one.pressure_cell(x, y).flow != 0;
    require(any_flow || rightmost >= 117, "retained velocity state is exercised");
}

void test_vented_two_limb_levels() {
    // Two limbs joined by a passage under a solid block; saturated Water
    // carries head through the passage (Current never moves here).
    const auto build = [](World& w) {
        rect(w, 8, 120, 80, 2, Material::Wall);
        rect(w, 8, 20, 2, 100, Material::Wall);
        rect(w, 86, 20, 2, 100, Material::Wall);
        rect(w, 30, 20, 36, 92, Material::Wall);  // block leaves passage y 112..119
        rect(w, 10, 40, 20, 80, Material::Water);  // left limb 80 rows
        rect(w, 66, 100, 20, 20, Material::Water); // right limb 20 rows
        rect(w, 30, 112, 36, 8, Material::Water);  // passage full
    };
    World world(pressure_config(1));
    world.reserve_region({0, 0, 128, 128});
    build(world);
    const RectI64 all{0, 0, 128, 128};
    const auto initial = quantity(world, all);
    const auto surface = [&](std::int64_t x0) {
        for (std::int64_t y = 20; y < 120; ++y)
            if (world.stored_material(x0, y) == Material::Water) return y;
        return std::int64_t{120};
    };
    const auto start = surface(75) - surface(20);
    for (int t = 0; t < 1500; ++t) tick(world);
    require(quantity(world, all) == initial, "two-limb quantity exact");
    const auto end = surface(75) - surface(20);
    require(start == 60 && end < 12, "vented limbs equalize (difference " + std::to_string(end) + " rows)");
}

void test_barriers_block_head() {
    // A one-cell wall and a body-mask column separate unequal pools: no head
    // or flux crosses either barrier, including through radius-2 sampling.
    for (const bool mask : {false, true}) {
        World world(pressure_config(1));
        world.reserve_region({0, 0, 128, 128});
        world.configure_transient_obstacles({0, 0, 128, 128});
        rect(world, 8, 100, 60, 2, Material::Wall);
        rect(world, 8, 40, 2, 60, Material::Wall);
        rect(world, 66, 40, 2, 60, Material::Wall);
        if (mask) {
            for (std::int64_t y = 40; y < 100; ++y) require(world.set_transient_obstacle(37, y, 1), "mask");
        } else {
            rect(world, 37, 40, 1, 60, Material::Wall);
        }
        rect(world, 10, 50, 27, 50, Material::Water);
        rect(world, 38, 90, 28, 10, Material::Water);
        const auto left = quantity(world, {10, 0, 27, 100});
        const auto right = quantity(world, {38, 0, 28, 100});
        std::vector<std::uint64_t> right_columns;
        for (std::int64_t x = 38; x < 66; ++x) right_columns.push_back(quantity(world, {x, 0, 1, 100}));
        for (int t = 0; t < 200; ++t) tick(world);
        require(quantity(world, {10, 0, 27, 100}) == left && quantity(world, {38, 0, 28, 100}) == right,
                std::string("head crossed a ") + (mask ? "body mask" : "one-cell wall"));
        // The flat right pool is at rest: a radius-2 sample through the barrier
        // would push its barrier-side cells and reshape it.
        for (std::int64_t x = 38; x < 66; ++x) {
            require(quantity(world, {x, 0, 1, 100}) == right_columns[static_cast<std::size_t>(x - 38)],
                    std::string("resting pool reshaped beside a ") + (mask ? "body mask" : "one-cell wall"));
            for (std::int64_t y = 90; y < 100; ++y)
                require(world.pressure_cell(x, y).flow == 0 && world.pressure_cell(x, y).overfill == 0,
                        "barrier-side pool gained flow or overfill");
        }
        if (mask) require(world.water_quantity({37, 0, 1, 100}) == 0U, "no Water under the mask column");
    }

    // A deep supported column reaches full lateral velocity immediately. Its
    // upper cells are outside the selected core, so they cannot refill a void
    // during this tick: the active bottom cell must retain one unit even when
    // its receiver is Empty and the whole-cell fast path would otherwise apply.
    for (const auto workers : {1U, 4U}) {
        auto config = pressure_config(workers);
        config.chunk_size = 8;
        config.activity_block_size = 8;
        config.scheduling_core_size = 8;
        World world(config);
        world.set_simulation_region(RectI64{0, 400, 8, 8});
        rect(world, 3, 1, 1, 400, Material::Water);
        world.set(2, 400, Material::Wall);
        rect(world, 2, 401, 3, 1, Material::Wall);
        const auto before = world.water_quantity({0, 0, 8, 408});
        tick(world);
        require(world.stored_material(3, 400) == Material::Water && world.stored_state_a(3, 400) == 1U,
                "full-speed lateral flow retains Water below the paused column");
        require(world.stored_state_a(3, 399) == 255U && world.stored_state_a(4, 400) == 254U &&
                    world.pressure_cell(4, 400).flow == cybersand::PressureFlowParameters::kFlowScale,
                "retained source preserves the paused cell and updated outgoing velocity");
        require(world.water_quantity({0, 0, 8, 408}) == before, "retained-source flux conserves exact quantity");
    }
}

void test_static_rest_and_sleep() {
    World world(pressure_config(1));
    world.reserve_region({0, 0, 128, 128});
    rect(world, 8, 100, 60, 2, Material::Wall);
    rect(world, 8, 40, 2, 60, Material::Wall);
    rect(world, 66, 40, 2, 60, Material::Wall);
    rect(world, 10, 60, 56, 40, Material::Water);
    for (int t = 0; t < 20; ++t) tick(world);
    const auto hash = world.physical_state_hash();
    const auto stats = world.tick();
    require(stats.active_blocks_after == 0U, "a closed full pool sleeps");
    for (int t = 0; t < 20; ++t) tick(world);
    for (std::int64_t y = 60; y < 100; ++y)
        for (std::int64_t x = 10; x < 66; ++x)
            require(world.pressure_cell(x, y).flow == 0 && world.pressure_cell(x, y).overfill == 0,
                    "static pool keeps zero flow and overfill");
    require(world.physical_state_hash() != hash, "tick clock still enters the physical hash");
    // Remote wake: draining a far corner wakes the sleeping bulk via head.
    rect(world, 10, 99, 1, 1, Material::Empty);
    rect(world, 9, 99, 1, 1, Material::Empty);
    world.set(8, 99, Material::Empty);
    world.set(9, 99, Material::Empty);
    const auto drained_before = world.water_quantity({0, 0, 128, 128});
    for (int t = 0; t < 30; ++t) tick(world);
    require(world.water_quantity({10, 60, 56, 40}) < drained_before, "opened outlet drains the rested pool");
}

void test_comparison_projection_rest_and_authority() {
    using cybersand::LiquidStateProjection;
    constexpr auto equivalent = LiquidStateProjection::PressureVariantEquivalenceV1;
    constexpr auto quiet = LiquidStateProjection::QuiescentPhysicalContentV1;
    auto config = pressure_config();
    config.liquid_solver_policy = pressure_policy({{0, 32}});
    World world(config);
    world.reserve_region({0, 0, 128, 128});
    rect(world, 8, 8, 3, 3, Material::Wall);
    rect(world, 9, 9, 1, 1, Material::Water);
    tick(world, 20);
    const auto full = world.physical_state_hash();
    const auto same_tick = world.liquid_comparison_hash(equivalent);
    const auto physical = world.liquid_comparison_hash(quiet);
    const auto bytes = world.save_physical_state();
    require(full != same_tick && same_tick != physical && physical != full,
            "comparison projections have separate domains");
    require(bytes == world.save_physical_state(), "projection inspection is pure");
    // Cross the byte-epoch rollover with no physical change. The complete and
    // same-tick observations retain clocks; only the declared static diagnostic
    // remains constant. This observation is not itself a future rest proof.
    for (int t = 0; t < 300; ++t) {
        const auto stats = world.tick();
        require(stats.active_blocks_after == 0U, "closed pool remains ordinarily asleep");
        require(world.liquid_comparison_hash(quiet) == physical,
                "static physical content remains constant across clock/epoch aging");
    }
    require(world.physical_state_hash() != full && world.liquid_comparison_hash(equivalent) != same_tick,
            "complete and same-tick hashes retain time");
    const auto restore = [&]() { return World::restore_physical_state(config, bytes); };
    auto other = restore();
    require(other->liquid_comparison_hash(equivalent) == same_tick &&
                other->liquid_comparison_hash(quiet) == physical,
            "exact continuation retains each comparison observation");
    other->set_temperature(9, 9, 201);
    require(other->liquid_comparison_hash(quiet) != physical, "stored temperature is physical content");
    other = restore();
    other->configure_transient_obstacles({0, 0, 128, 128});
    require(other->set_transient_obstacle(9, 9, 7), "mask installed over authoritative Water");
    require(other->liquid_comparison_hash(quiet) != physical, "mask authority remains significant");
    other = restore();
    require(other->queue_explosion(20, 20, 1), "future event admitted");
    require(other->liquid_comparison_hash(quiet) != physical, "future event obligations remain significant");
    other = restore();
    other->set_liquid_surface_adhesion_enabled(!other->liquid_surface_adhesion_enabled());
    require(other->liquid_comparison_hash(quiet) != physical, "material controls remain significant");
    bool refused = false;
    try { (void)world.liquid_comparison_hash(static_cast<LiquidStateProjection>(255)); }
    catch (const std::invalid_argument&) { refused = true; }
    require(refused, "unknown projection identities refuse");
}

void test_comparison_projection_policy_scope() {
    auto build = LiquidPolicyBuild::running();
    for (auto& variants : build.qualified_variants)
        if (variants.material == 3U && variants.family == 3U) variants.variant_mask = 7U;
    std::array<LiquidSolverPolicy, 3> policies;
    for (std::int32_t variant = 0; variant < 3; ++variant) {
        const auto request = pressure_request(std::nullopt, variant);
        const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(request), build);
        require(decoded.accepted(), "comparison contract build admits each pressure variant");
        policies[static_cast<std::size_t>(variant)] = *decoded.policy;
    }
    for (std::size_t i = 1; i < policies.size(); ++i) {
        require(policies[i].policy_hash() != policies[0].policy_hash(), "variant retains canonical identity");
        require(policies[i].pressure_variant_equivalence_hash() == policies[0].policy_hash(),
                "projection normalizes exactly the pressure variant to the reference policy");
    }
    require(LiquidSolverPolicy{}.pressure_variant_equivalence_hash() !=
                policies[0].pressure_variant_equivalence_hash(), "projection retains solver-family selection");
    require(pressure_policy({{0, 32}}).pressure_variant_equivalence_hash() !=
                pressure_policy({{0, 33}}).pressure_variant_equivalence_hash(),
            "projection retains complete effective family parameter blocks");
}

void test_lifecycle_ledgers() {
    World world(pressure_config(1));
    world.reserve_region({0, 0, 64, 64});
    // Overfill on a saturated cell: create it by relaying from a compressed column.
    rect(world, 8, 40, 20, 2, Material::Wall);
    rect(world, 8, 10, 2, 30, Material::Wall);
    rect(world, 26, 10, 2, 30, Material::Wall);
    rect(world, 10, 12, 16, 28, Material::Water);
    for (int t = 0; t < 5; ++t) tick(world);
    // Relocation carries the sidecar; erasure books external overfill.
    const auto before = world.pressure_flow_ledger();
    (void)world.set_cell_state(12, 39, Material::Water, world.config().water_experiment_policy.maximum(), 0);
    const auto after_paint = world.pressure_cell(12, 39);
    require(after_paint.overfill == 0 && after_paint.flow == 0, "paint starts at the family default");
    (void)world.set_cell_state(13, 39, Material::Empty, 0, 0);
    require(world.pressure_cell(13, 39).overfill == 0 && world.pressure_cell(13, 39).flow == 0,
            "no optional state remains on an Empty vacancy");
    require(world.pressure_flow_ledger().overfill_external >= before.overfill_external, "external ledger monotone");
    // Gas labels never sit on non-Empty cells, overfill only on saturated Water.
    for (std::int64_t y = 0; y < 64; ++y)
        for (std::int64_t x = 0; x < 64; ++x) {
            const auto state = world.pressure_cell(x, y);
            const auto material = world.stored_material(x, y);
            require(state.gas == 0U || material == Material::Empty, "gas label on a non-Empty cell");
            require(state.overfill == 0U || (material == Material::Water && world.stored_state_a(x, y) == 255U),
                    "overfill outside a saturated Water cell");
            require(state.flow == 0 || material == Material::Water, "flow outside Water");
        }
}

void test_pressure_material_hooks() {
    // Gravity can consume the entire coherent source before the receiver is
    // written. Both a partial and complete source transfer keep its decremented
    // material coherence, exactly as transfer_water does for FreeMass.
    for (const auto mass : {5U, 255U}) {
        World world(pressure_config());
        rect(world, 2, 5, 3, 1, Material::Wall);
        for (const auto x : {2, 4}) rect(world, x, 3, 1, 2, Material::Wall);
        require(world.set_cell_state(3, 3, Material::Water, static_cast<std::uint16_t>(mass), 12),
                "coherent gravity source");
        require(world.set_cell_state(3, 4, Material::Water, 250, 0), "coherent gravity receiver");
        tick(world);
        require(world.stored_state_a(3, 4) == 255U && world.stored_state_b(3, 4) == 11U,
                "partial gravity keeps source coherence even when take empties the source");
        require(world.water_quantity({0, 0, 8, 8}) == mass + 250U, "coherent gravity quantity exact");
    }

    // A full-speed neighbour gives a coherent saturated receiver overfill.
    // Relief creates Water in the paused row above: its coherence must follow
    // the actual receiver even if that receiver ran before the incoming flux.
    auto config = pressure_config();
    config.chunk_size = 8;
    config.activity_block_size = 8;
    config.scheduling_core_size = 8;
    World world(config);
    world.set_simulation_region(RectI64{0, 400, 8, 8});
    rect(world, 3, 1, 1, 400, Material::Water);
    world.set(2, 400, Material::Wall);
    world.set(5, 400, Material::Wall);
    rect(world, 2, 401, 4, 1, Material::Wall);
    require(world.set_cell_state(4, 400, Material::Water, 255, 12), "coherent overfill receiver");
    const auto before = world.water_quantity({0, 0, 8, 408});
    for (int t = 0; t < 2 && world.stored_material(4, 399) != Material::Water; ++t) tick(world);
    require(world.stored_material(4, 399) == Material::Water && world.stored_state_b(4, 399) != 0U &&
                world.stored_state_b(4, 399) == world.stored_state_b(4, 400),
            "overfill relief into Empty keeps the source material coherence");
    require(world.water_quantity({0, 0, 8, 408}) == before, "coherent overfill relief quantity exact");

    // A resting half-cell's 96-unit surface-skin transfer is strong enough to
    // carry a grain under the registered transport hook. The grain's full
    // tuple and temperature travel through the conservative swap.
    for (const auto workers : {1U, 4U}) {
        auto carrying = pressure_config(workers);
        carrying.transport_policy.configured = true;
        auto& pair = carrying.transport_policy.pairs[3U * cybersand::TransportPolicy::materials + 2U];
        pair.carrying = 255;
        pair.pickup = 0;
        pair.packing = 0;
        pair.erosion = 1;
        World carrier(carrying);
        carrier.reserve_temperature_region({0, 0, 128, 128});
        carrier.set(23, 40, Material::Wall);
        carrier.set(23, 41, Material::Wall);
        carrier.set(25, 41, Material::Wall);
        rect(carrier, 23, 42, 3, 1, Material::Wall);
        require(carrier.set_cell_state(24, 41, Material::Sand, 17, 23), "skin carrying grain tuple");
        carrier.set_temperature(24, 41, 777);
        require(carrier.set_cell_state(24, 40, Material::Water, 128, 0), "skin carrying Water");
        tick(carrier);
        require(carrier.stored_material(25, 40) == Material::Sand && carrier.stored_state_a(25, 40) == 17U &&
                    carrier.stored_state_b(25, 40) == 23U && carrier.temperature(25, 40) == 777,
                "surface-skin flux invokes carrying with the complete grain payload");
        require(carrier.water_quantity({0, 0, 128, 128}) == 128U &&
                    carrier.stored_material(24, 41) == Material::Water &&
                    carrier.stored_state_a(24, 41) == 96U,
                "surface-skin carrying swaps actual Water quantity conservatively");
    }

    const auto moving_column = []() {
        auto config = pressure_config();
        config.chunk_size = 8;
        config.activity_block_size = 8;
        config.scheduling_core_size = 8;
        auto world = std::make_unique<World>(config);
        world->set_simulation_region(RectI64{1, 400, 8, 8});
        rect(*world, 4, 1, 1, 400, Material::Water);
        rect(*world, 2, 400, 2, 1, Material::Wall);
        rect(*world, 2, 401, 5, 1, Material::Wall);
        tick(*world);
        require(world->stored_state_a(4, 400) == 1U &&
                    world->pressure_cell(4, 400).flow == cybersand::PressureFlowParameters::kFlowScale,
                "moving column primes a non-default family state");
        return world;
    };
    // Water + ToxicSludge produces two fresh Water products. Existing Water
    // identity at one site must not retain the old solver state of its reagent.
    auto chemistry = moving_column();
    chemistry->set(3, 400, Material::ToxicSludge);
    tick(*chemistry);
    for (const auto x : {3, 4}) {
        const auto family = chemistry->pressure_cell(x, 400);
        require(chemistry->stored_material(x, 400) == Material::Water &&
                    chemistry->stored_state_a(x, 400) == 255U && family.flow == 0 && family.overfill == 0U,
                "both Water reaction products start with fresh pressure state");
    }
    // External replacement can change only a sidecar while keeping every
    // visible cell byte. Both public setters must still publish the mutation.
    for (const bool explicit_state : {false, true}) {
        auto painted = moving_column();
        (void)painted->take_dirty_chunks();
        require(painted->dirty_chunk_count() == 0U, "paint witness starts with no pending dirty chunk");
        if (explicit_state) {
            require(painted->set_cell_state(4, 400, Material::Water, 1, 0),
                    "identical visible tuple reports changed family state");
        } else {
            painted->set(4, 400, Material::Water);
        }
        require(painted->pressure_cell(4, 400).flow == 0 && painted->stored_state_a(4, 400) == 1U &&
                    painted->dirty_chunk_count() != 0U,
                "same-material paint witnesses the family-only mutation");
    }
}

void test_physical_hash_and_persistence() {
    const auto build = [](World& w) {
        rect(w, 8, 120, 80, 2, Material::Wall);
        rect(w, 8, 20, 2, 100, Material::Wall);
        rect(w, 86, 20, 2, 100, Material::Wall);
        rect(w, 30, 20, 36, 92, Material::Wall);
        rect(w, 10, 40, 20, 80, Material::Water);
        rect(w, 66, 100, 20, 20, Material::Water);
        rect(w, 30, 112, 36, 8, Material::Water);
        room(w, 90);  // a sealed pocket enters the persisted gas table
    };
    World continuous(pressure_config(1));
    continuous.reserve_region({0, 0, 128, 128});
    build(continuous);
    tick(continuous, 40);
    const auto saved = continuous.save_physical_state();
    WorldConfig execution;
    execution.worker_threads = 4;
    auto restored = World::restore_physical_state(execution, saved);
    require(restored->physical_state_hash() == continuous.physical_state_hash(), "restore reproduces the hash");
    require(restored->gas_compartments().size() == continuous.gas_compartments().size(), "gas table restored");
    require(restored->save_physical_state() == saved, "save is canonical");
    for (int t = 0; t < 60; ++t) {
        tick(continuous);
        tick(*restored);
        require(restored->physical_state_hash() == continuous.physical_state_hash() &&
                    restored->state_hash() == continuous.state_hash(),
                "exact continuation after restore (4 workers) at +" + std::to_string(t + 1));
    }
    // Corruption, truncation and unknown versions refuse before any World exists.
    auto corrupt = saved;
    corrupt[corrupt.size() / 2] ^= 0x01U;
    const auto refuses = [&](const std::vector<std::uint8_t>& bytes) {
        try {
            (void)World::restore_physical_state(WorldConfig{}, bytes);
        } catch (const std::invalid_argument&) {
            return true;
        }
        return false;
    };
    require(refuses(corrupt), "corrupted payload refused");
    require(refuses({saved.begin(), saved.begin() + static_cast<std::ptrdiff_t>(saved.size() / 3)}),
            "truncated payload refused");
    require(refuses({}), "empty payload refused");
    // A default (FreeMass) World saves and restores too, without a pressure section.
    World plain;
    plain.reserve_region({0, 0, 64, 64});
    rect(plain, 10, 10, 5, 5, Material::Water);
    tick(plain, 3);
    auto plain_restored = World::restore_physical_state(WorldConfig{}, plain.save_physical_state());
    require(!plain_restored->pressure_flow_enabled() &&
                plain_restored->physical_state_hash() == plain.physical_state_hash(),
            "default World persistence");
    // A gas-only difference (one compartment's amount and its closing ledger,
    // with identical cells) changes the physical hash and the restored gauge.
    World a(pressure_config(1));
    a.reserve_region({0, 0, 64, 64});
    room(a, 8);
    tick(a, 3);
    require(a.gas_compartments().size() == 1U && a.gas_history().empty(), "one pocket, no history");
    auto bytes = a.save_physical_state();
    constexpr std::size_t kDigest = 32U, kTail = 8U + 10U * 8U + 5U * 8U, kRecord = 4U + 4U + 1U + 32U + 7U * 8U;
    const auto record = bytes.size() - kDigest - kTail - kRecord;
    const auto tail = bytes.size() - kDigest - kTail;
    const auto bump = [&bytes](std::size_t at) {
        std::uint64_t value = 0;
        for (std::size_t i = 0; i < 8U; ++i) value |= static_cast<std::uint64_t>(bytes[at + i]) << (8U * i);
        ++value;
        for (std::size_t i = 0; i < 8U; ++i) bytes[at + i] = static_cast<std::uint8_t>(value >> (8U * i));
    };
    bump(record + 41U);  // amount
    bump(tail + 8U);  // ledger created: keep the modified gas ledger conserving
    bump(tail + 8U + 9U * 8U);  // ledger amount_live
    const auto digest = cybersand::Sha256::of(std::span<const std::uint8_t>(bytes.data(), bytes.size() - kDigest));
    std::copy(digest.begin(), digest.end(), bytes.end() - static_cast<std::ptrdiff_t>(kDigest));
    auto edited = World::restore_physical_state(WorldConfig{}, bytes);
    require(edited->gas_compartments()[0].amount == a.gas_compartments()[0].amount + 1U,
            "edited payload restored with the changed amount");
    require(edited->physical_state_hash() != a.physical_state_hash(), "gas-only change alters the physical hash");
    require(edited->content_hash() == a.content_hash(), "cells unchanged by the gas-only edit");
}

#include "test_pressure_optimization.inc"
#include "test_pressure_gas_cache.inc"
#include "test_pressure_variants_acceptance.inc"

void test_default_policy_untouched() {
    // A default World never allocates or runs pressure state, and its historic
    // hashes are those of Current (protected by the existing golden tests).
    World current;
    current.reserve_region({0, 0, 128, 128});
    build_dam(current, 64);
    rect(current, 40, 40, 2, 80, Material::Empty);
    tick(current, 30);
    require(!current.pressure_flow_enabled() && current.gas_compartments().empty() &&
                current.gas_ledger().creations == 0U,
            "default policy has no pressure state");
}

}  // namespace

void test_lcb_pressure_admission() { test_pressure_admission_and_refusal(); }
void test_lcb_pressure_gas_id_restore_bounds() { test_gas_id_restore_bounds(); }
void test_lcb_pressure_gas_id_creation_exhaustion() { test_gas_id_creation_exhaustion(); }
void test_lcb_pressure_gas_id_split_exhaustion() { test_gas_id_split_exhaustion(); }
void test_lcb_pressure_quantity_bounds() { test_quantity_rectangle_bounds(); }
void test_lcb_pressure_event_restore_bounds() { test_pending_event_restore_bounds(); }
void test_lcb_pressure_gas_pockets() { test_gas_single_and_twin_pockets(); }
void test_lcb_pressure_gas_merge() { test_gas_unequal_merge(); }
void test_lcb_pressure_gas_vent_reseal() { test_gas_compress_vent_reseal(); }
void test_lcb_pressure_gas_split() { test_gas_split(); }
void test_lcb_pressure_gas_empty_only() { test_gas_empty_only_and_unallocated(); }
void test_lcb_pressure_quantity_parity() { test_quantity_parity_and_motion(); }
void test_lcb_pressure_two_limb() { test_vented_two_limb_levels(); }
void test_lcb_pressure_barriers() { test_barriers_block_head(); }
void test_lcb_pressure_static_rest() { test_static_rest_and_sleep(); }
void test_lcb_pressure_lifecycle() { test_lifecycle_ledgers(); test_pressure_material_hooks(); }
void test_lcb_pressure_persistence() { test_physical_hash_and_persistence(); }
void test_lcb_pressure_default_untouched() { test_default_policy_untouched(); }
void test_lcb_pressure_comparison_rest() { test_comparison_projection_rest_and_authority(); }
void test_lcb_pressure_comparison_policy() { test_comparison_projection_policy_scope(); }
void test_lcb_pressure_cached_heads() { test_cached_incremental_heads(); }
void test_lcb_pressure_cached_gas() { test_cached_gas_and_fallback(); }
void test_lcb_pressure_affected_gas() { test_affected_gas_components(); test_gas_component_worker_parity(); }
void test_lcb_pressure_gas_cache_capacity() { test_gas_component_capacity_fallbacks(); }
void test_lcb_pressure_dormant_obligations() {
    test_dormant_motion_and_body_obligations();
    test_dormant_remote_gas_dependency();
}

void test_lcb_pressure_optimization_identity() { test_pressure_optimization_identity_readback(); }
void test_lcb_pressure_cost_admission() { test_dormant_cost_admission(); }
void test_lcb_pressure_variants_remote_acceptance() { test_variants_remote_hydraulic_acceptance(); }
void test_lcb_pressure_variants_mask_acceptance() { test_variants_rotating_mask_acceptance(); }
void test_lcb_pressure_variants_obligation_acceptance() { test_variants_obligation_reconstruction_acceptance(); }
void test_lcb_pressure_variants_basins_acceptance() { test_variants_communicating_basins_acceptance(); }
void test_lcb_pressure_variants_vent_acceptance() { test_variants_isolated_vent_acceptance(); }
