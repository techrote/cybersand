#pragma once

#include "cybersand/world.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <string>
#include <utility>

// Public-World tests: deliberately do not use the production phase helper as
// the accounting oracle. The same cases can run against the pre-repair source.
namespace cybersand::mat002_tests {

inline void check(bool value, const std::string& message) {
    if (!value) throw std::runtime_error(message);
}

inline WorldConfig config(std::uint8_t bits = 8) {
    WorldConfig c;
    c.initial_chunk_reserve = 8;
    c.maximum_chunk_count = 128;
    c.active_chunk_capacity = 128;
    c.active_core_capacity = 512;
    c.parallel_job_threshold = 1;
    c.water_experiment_policy = WaterExperimentPolicy(bits, 12);
    return c;
}

inline std::uint8_t payload(std::uint16_t q, std::uint16_t maximum) {
    return q == maximum ? std::uint8_t{0} : static_cast<std::uint8_t>(q);
}

inline std::uint64_t inventory(const World& w, std::int64_t x, std::int64_t y) {
    const auto material = w.stored_material(x, y);
    if (material == Material::Water) return w.stored_state_a(x, y);
    if (material != Material::Steam && material != Material::Ice) return 0;
    const auto quantity = w.stored_state_b(x, y);
    return quantity == 0 ? w.config().water_experiment_policy.maximum() : quantity;
}

inline std::uint64_t pair_inventory(const World& w, std::int64_t x = 8,
                                    std::int64_t y = 8) {
    return inventory(w, x, y) + inventory(w, x + 1, y);
}

inline void box(World& w, std::int64_t x, std::int64_t y, Material a, Material b) {
    w.reserve_region({x - 4, y - 4, 16, 16});
    for (auto yy = y - 1; yy <= y + 1; ++yy)
        for (auto xx = x - 1; xx <= x + 2; ++xx) w.set(xx, yy, Material::Wall);
    w.set(x, y, a);
    w.set(x + 1, y, b);
}

inline void water(World& w, std::int64_t x, std::int64_t y, std::uint16_t q) {
    (void)w.set_cell_state(x, y, Material::Water, q, 0);
    check(w.stored_material(x, y) == Material::Water && w.stored_state_a(x, y) == q,
          "Water setup lost the exact lattice quantity");
}

inline void tick_prepared(World& w) {
    const auto stats = w.tick();
    check(stats.chunk_allocations == 0 && stats.temperature_field_allocations == 0,
          "phase operation allocated unprepared World storage");
}

inline void await_steam(World& w, std::int64_t x, std::int64_t y) {
    for (unsigned i = 0; i < 32 && w.stored_material(x, y) != Material::Steam; ++i)
        tick_prepared(w);
    check(w.stored_material(x, y) == Material::Steam, "persistent Water contact did not evaporate");
}

inline void evaporation_inventory() {
    for (std::uint8_t bits = 3; bits <= 8; ++bits) {
        const auto maximum = static_cast<std::uint16_t>((1U << bits) - 1U);
        for (const std::uint16_t q : {std::uint16_t{1}, static_cast<std::uint16_t>(maximum / 2U),
                                      static_cast<std::uint16_t>(maximum - 1U), maximum}) {
            for (const auto hot : {Material::Lava, Material::MoltenGlass, Material::Fire, Material::Sodium}) {
                for (const bool reverse : {false, true}) {
                    World w(config(bits));
                    box(w, 8, 8, reverse ? Material::Water : hot, reverse ? hot : Material::Water);
                    const std::int64_t wx = reverse ? 8 : 9, hx = reverse ? 9 : 8;
                    water(w, wx, 8, q);
                    await_steam(w, wx, 8);
                    check(pair_inventory(w) == q, "evaporation invented Water inventory: bits=" +
                          std::to_string(bits) + " q=" + std::to_string(q) +
                          " hot=" + std::to_string(static_cast<unsigned>(hot)));
                    if (hot == Material::Lava || hot == Material::MoltenGlass) {
                        const auto solid = hot == Material::Lava ? Material::Stone : Material::Glass;
                        check(w.stored_material(hx, 8) == (q == maximum ? solid : hot),
                              "partial coolant instantly solidified a whole hot cell");
                        if (q < maximum)
                            check(w.stored_state_b(hx, 8) == q, "quench progress did not equal coolant inventory");
                    }
                }
            }
        }
    }
}

inline void repeated_phase_cycles() {
    for (const std::uint8_t bits : {std::uint8_t{3}, std::uint8_t{8}}) {
        const auto maximum = static_cast<std::uint16_t>((1U << bits) - 1U);
        for (const auto q : {std::uint16_t{1}, static_cast<std::uint16_t>(maximum - 1U), maximum}) {
            World w(config(bits));
            box(w, 8, 8, Material::Wall, Material::Water);
            water(w, 9, 8, q);
            for (unsigned cycle = 0; cycle < 4; ++cycle) {
                w.set(8, 8, Material::Fire); // Explicit energy source, never a Water source.
                await_steam(w, 9, 8);
                check(pair_inventory(w) == q, "evaporation changed inventory in repeated cycle");
                w.set(8, 8, Material::Wall);
                for (unsigned t = 0; t < 256 && w.stored_material(9, 8) != Material::Water; ++t) {
                    tick_prepared(w);
                    check(pair_inventory(w) == q, "Steam lifetime/motion discarded phase quantity");
                }
                check(w.stored_material(9, 8) == Material::Water && w.stored_state_a(9, 8) == q,
                      "Steam condensation refilled a partial parcel");
            }
        }
    }
}

inline void ice_phase_inventory() {
    for (std::uint8_t bits = 3; bits <= 8; ++bits) {
        const auto maximum = static_cast<std::uint16_t>((1U << bits) - 1U);
        World w(config(bits));
        box(w, 8, 8, Material::Ice, Material::Water);
        water(w, 9, 8, 1);
        for (unsigned t = 0; t < 512 && w.stored_material(9, 8) != Material::Ice; ++t) {
            tick_prepared(w);
            check(pair_inventory(w) == static_cast<std::uint64_t>(maximum) + 1U,
                  "freezing changed the combined Ice/Water inventory");
        }
        check(w.stored_material(9, 8) == Material::Ice && inventory(w, 9, 8) == 1U,
              "partial Water did not freeze with retained quantity");
        w.set(8, 8, Material::Lava); // Remove the seed Ice; introduce a named hot source.
        for (unsigned t = 0; t < 64 && w.stored_material(9, 8) == Material::Ice; ++t) tick_prepared(w);
        check(w.stored_material(9, 8) != Material::Ice && inventory(w, 9, 8) == 1U,
              "hot melting recreated full Water from partial Ice");

        World contact(config(bits));
        box(contact, 8, 8, Material::Ice, Material::Steam);
        (void)contact.set_cell_state(8, 8, Material::Ice, 0, 2);
        (void)contact.set_cell_state(9, 8, Material::Steam, 255, 3);
        for (unsigned t = 0; t < 320; ++t) {
            tick_prepared(contact);
            check(pair_inventory(contact) == 5U, "Steam/Ice contact reset a preserved participant");
        }
        check(contact.stored_material(9, 8) != Material::Steam,
              "Steam/Ice fixture did not exercise condensation");
    }
}

inline void cumulative_quench() {
    for (std::uint8_t bits = 3; bits <= 8; ++bits) {
        const auto maximum = static_cast<std::uint16_t>((1U << bits) - 1U);
        for (const auto hot : {Material::Lava, Material::MoltenGlass}) {
            for (const bool overshoot : {false, true}) {
                World w(config(bits));
                box(w, 8, 8, hot, Material::Wall);
                std::uint64_t injected = 0, removed_vapour = 0;
                const std::array<std::uint16_t, 2> doses = overshoot
                    ? std::array<std::uint16_t, 2>{static_cast<std::uint16_t>(maximum / 2U + 1U),
                                                   static_cast<std::uint16_t>(maximum / 2U + 1U)}
                    : std::array<std::uint16_t, 2>{static_cast<std::uint16_t>(maximum - 1U), 1};
                for (const auto dose : doses) {
                    water(w, 9, 8, dose);
                    injected += dose;
                    await_steam(w, 9, 8);
                    check(inventory(w, 9, 8) == dose && removed_vapour + inventory(w, 9, 8) == injected,
                          "quench lost or created its contacting Water parcel");
                    const auto solid = hot == Material::Lava ? Material::Stone : Material::Glass;
                    check(w.stored_material(8, 8) == (injected < maximum ? hot : solid),
                          "quench completion ignored cumulative coolant quantity");
                    if (injected < maximum)
                        check(w.stored_state_b(8, 8) == injected, "cumulative cooling credit was lost");
                    removed_vapour += inventory(w, 9, 8);
                    w.set(9, 8, Material::Wall); // Explicitly account for removed vapour before next dose.
                }
                check(removed_vapour == injected, "quench source/sink ledger does not close");
                w.clear();
                box(w, 8, 8, hot, Material::Wall);
                check(w.stored_state_b(8, 8) == 0U, "clear retained stale quench progress");
            }
        }
    }
}

inline void payload_movement_and_same_material_updates() {
    const auto c = config();
    for (const auto material : {Material::Steam, Material::Lava, Material::MoltenGlass}) {
        World w(c);
        w.reserve_temperature_region({0, 0, 128, 128});
        (void)w.set_cell_state(8, 8, material, material == Material::Lava ? 0U : 100U, 17);
        w.set_temperature(8, 8, 777);
        tick_prepared(w);
        const auto y = material == Material::Steam ? 7 : 9;
        check(w.stored_material(8, y) == material && w.stored_state_b(8, y) == 17U &&
                  w.temperature(8, y) == 777,
              "motion/lifetime discarded compact quantity or quench progress");
        check(w.relocate_stored_cell(8, y, 10, y) && w.stored_state_b(10, y) == 17U,
              "serialized body relocation discarded phase state");
    }
    World lava(c);
    box(lava, 8, 8, Material::Lava, Material::Glass);
    (void)lava.set_cell_state(8, 8, Material::Lava, 0, 17);
    for (unsigned t = 0; t < 16 && lava.stored_material(9, 8) == Material::Glass; ++t) tick_prepared(lava);
    check(lava.stored_material(9, 8) == Material::MoltenGlass && lava.stored_state_b(8, 8) == 17U,
          "melting Glass reset the unchanged Lava participant's quench progress");

    auto awake = c;
    awake.sleep_after_quiet_ticks = 32;
    World cooling(awake);
    box(cooling, 8, 8, Material::MoltenGlass, Material::Wall);
    (void)cooling.set_cell_state(8, 8, Material::MoltenGlass, 10, 17);
    for (unsigned t = 0; t < 8; ++t) tick_prepared(cooling);
    check(cooling.stored_state_a(8, 8) < 10U && cooling.stored_state_b(8, 8) == 17U,
          "MoltenGlass cooling countdown discarded Water-quench progress");

    World purify(c);
    box(purify, 8, 8, Material::Water, Material::ToxicSludge);
    water(purify, 8, 8, 7);
    for (unsigned t = 0; t < 16 && purify.stored_material(9, 8) == Material::ToxicSludge; ++t)
        tick_prepared(purify);
    check(pair_inventory(purify) == 262U,
          "Sludge conversion refilled the unchanged partial Water participant");
}

inline void charged_metal_evaporation() {
    World w(config());
    w.reserve_region({0, 0, 128, 128});
    for (int y = 6; y <= 10; ++y) for (int x = 6; x <= 10; ++x)
        w.set(x, y, Material::Wall);
    for (int y = 7; y <= 9; ++y) for (int x = 7; x <= 9; ++x)
        water(w, x, y, 17);
    (void)w.set_cell_state(8, 8, Material::Metal, 0, 24);
    bool boiled = false;
    for (unsigned t = 0; t < 32; ++t) {
        tick_prepared(w);
        std::uint64_t sum = 0;
        for (int y = 7; y <= 9; ++y) for (int x = 7; x <= 9; ++x) {
            sum += inventory(w, x, y);
            boiled = boiled || w.stored_material(x, y) == Material::Steam;
        }
        check(sum == 8U * 17U, "charged Metal invented aqueous inventory while boiling Water");
    }
    check(boiled, "charged-Metal positive control never produced Steam");
}

inline void masks_pause_and_reentry() {
    for (const std::int64_t masked_x : {8, 9}) {
        World w(config());
        box(w, 8, 8, Material::Lava, Material::Water);
        water(w, 9, 8, 7);
        w.configure_transient_obstacles({0, 0, 32, 32});
        check(w.set_transient_obstacle(masked_x, 8, 1), "mask setup failed");
        (void)w.take_dirty_chunks();
        const auto before = w.content_hash();
        for (unsigned t = 0; t < 64; ++t) tick_prepared(w);
        check(w.content_hash() == before && w.take_dirty_chunks().empty(),
              "quantity-aware reaction crossed a mask or created spurious dirtiness");
        w.clear_transient_obstacles();
        check(w.take_dirty_chunks().empty(), "unmasking dirtied material presentation");
        await_steam(w, 9, 8);
        check(pair_inventory(w) == 7U && w.stored_material(8, 8) == Material::Lava &&
                  w.stored_state_b(8, 8) == 7U, "unmasking lost the retained quantity/quench opportunity");
    }
    World paused(config());
    box(paused, 8, 8, Material::Ice, Material::Water);
    water(paused, 9, 8, 7);
    tick_prepared(paused);
    paused.set_simulation_region(RectI64{512, 512, 64, 64});
    const auto before = paused.content_hash();
    for (unsigned t = 0; t < 64; ++t) tick_prepared(paused);
    check(paused.content_hash() == before, "phase inventory advanced in excluded interest");
    paused.set_simulation_region(RectI64{0, 0, 64, 64});
    for (unsigned t = 0; t < 512 && paused.stored_material(9, 8) != Material::Ice; ++t) tick_prepared(paused);
    check(paused.stored_material(9, 8) == Material::Ice && pair_inventory(paused) == 262U,
          "re-entry lost pending partial freeze or its inventory");
}

inline void seams_workers_and_observer() {
    auto one_config = config();
    auto four_config = one_config;
    four_config.worker_threads = 4;
    four_config.settled_discovery_enabled = true;
    World one(one_config), four(four_config);
    constexpr std::array<std::pair<std::int64_t, std::int64_t>, 8> locations{{
        {-129, 8}, {-1, 8}, {63, 8}, {127, 8}, {8, 136}, {136, 136}, {264, 136}, {392, 136}}};
    for (auto* w : {&one, &four}) {
        w->reserve_region({-256, -128, 896, 512});
        for (std::size_t i = 0; i < locations.size(); ++i) {
            const auto [x, y] = locations[i];
            box(*w, x, y, i < 4 ? Material::Ice : Material::Lava, Material::Water);
            water(*w, x + 1, y, 17);
        }
    }
    bool parallel = false;
    for (unsigned t = 0; t < 160; ++t) {
        tick_prepared(one);
        const auto stats = four.tick();
        check(stats.chunk_allocations == 0 && stats.temperature_field_allocations == 0,
              "parallel phase fixture allocated after preparation");
        parallel = parallel || *std::max_element(stats.phase_jobs.begin(), stats.phase_jobs.end()) >= 4U;
        (void)four.advance_settled_discovery(64);
        check(one.state_hash() == four.state_hash(), "phase state diverged across 1/4 workers or observation");
        check(four.settled_discovery_halted() == soliding::DiscoveryHalt::None,
              "phase-state observation halted discovery");
        for (std::size_t i = 0; i < locations.size(); ++i) {
            const auto [x, y] = locations[i];
            check(pair_inventory(one, x, y) == (i < 4 ? 272U : 17U),
                  "phase quantity changed at a signed/core/chunk seam");
        }
    }
    check(parallel, "worker fixture did not dispatch real same-phase jobs");
}

inline void legacy_and_invalid_payloads() {
    for (std::uint8_t bits = 3; bits <= 8; ++bits) {
        const auto maximum = static_cast<std::uint16_t>((1U << bits) - 1U);
        World legacy(config(bits));
        box(legacy, 8, 8, Material::Steam, Material::Wall);
        (void)legacy.set_cell_state(8, 8, Material::Steam, 1, 0);
        tick_prepared(legacy);
        check(legacy.stored_material(8, 8) == Material::Water && legacy.stored_state_a(8, 8) == maximum,
              "legacy/painted Steam no longer means one full Water cell");
        for (const auto hot : {Material::Lava, Material::MoltenGlass}) {
            World w(config(bits));
            const auto hash = w.state_hash();
            bool rejected = false;
            try { (void)w.set_cell_state(8, 8, hot, 0, static_cast<std::uint8_t>(maximum)); }
            catch (const std::invalid_argument&) { rejected = true; }
            check(rejected && w.state_hash() == hash, "out-of-domain quench progress was accepted or mutated state");
        }
        if (bits < 8) for (const auto phase : {Material::Steam, Material::Ice}) {
            World w(config(bits));
            const auto hash = w.state_hash();
            bool rejected = false;
            try { (void)w.set_cell_state(8, 8, phase, 0, static_cast<std::uint8_t>(maximum + 1U)); }
            catch (const std::invalid_argument&) { rejected = true; }
            check(rejected && w.state_hash() == hash, "oversized phase inventory was accepted or mutated state");
        }
    }
}

inline constexpr std::array<std::pair<const char*, void (*)()>, 9> cases{{
    {"evaporation inventory", evaporation_inventory},
    {"repeated phase cycles", repeated_phase_cycles},
    {"Ice phase inventory", ice_phase_inventory},
    {"cumulative quench", cumulative_quench},
    {"payload movement and unchanged participants", payload_movement_and_same_material_updates},
    {"charged Metal evaporation", charged_metal_evaporation},
    {"masks, pause and re-entry", masks_pause_and_reentry},
    {"seams, actual workers and observer", seams_workers_and_observer},
    {"legacy and invalid payloads", legacy_and_invalid_payloads},
}};

inline bool run_all() {
    unsigned failures = 0;
    for (const auto& [name, test] : cases) {
        try { test(); std::cout << "[pass] MAT-002 " << name << '\n'; }
        catch (const std::exception& e) {
            ++failures;
            std::cout << "[fail] MAT-002 " << name << ": " << e.what() << '\n';
        }
    }
    return failures == 0;
}

} // namespace cybersand::mat002_tests
