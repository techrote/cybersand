#include "cybersand/world.hpp"
#include "cybersand/material_rules.hpp"
#include "cybersand/interaction_rules.hpp"
#include "cybersand/demo_snapshot.hpp"
#include "cybersand/sha256.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <iostream>
#include <span>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using namespace cybersand;
std::size_t checks = 0;
void require(bool ok, const char* message) {
    ++checks;
    if (!ok) throw std::runtime_error(std::string("paired materials: ") + message);
}
WorldConfig config(int family = 1, std::uint8_t bits = 8, std::uint32_t workers = 1) {
    WorldConfig c;
    c.chunk_size = 16;
    c.activity_block_size = 8;
    c.scheduling_core_size = 8;
    c.maximum_rule_radius = 3;
    c.worker_threads = workers;
    c.parallel_job_threshold = 1;
    c.sleep_after_quiet_ticks = 1;
    c.water_experiment_policy = WaterExperimentPolicy(bits, 12);
    if (family != 1) {
        auto words = LiquidSolverPolicy::default_request();
        words[21] = family;
        if (family == 4) {
            words[words.size() - 2U] = 1;
            words.insert(words.end() - 1, {4, 2, 1, 1});
        }
        const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
        require(decoded.accepted(), "registered liquid family admission");
        c.liquid_solver_policy = *decoded.policy;
    }
    return c;
}
void rect(World& w, int x, int y, int width, int height, Material m) {
    for (int yy = 0; yy < height; ++yy)
        for (int xx = 0; xx < width; ++xx) w.set(x + xx, y + yy, m);
}
void box(World& w, int x = 8, int y = 8) {
    rect(w, x - 3, y - 3, 7, 7, Material::Wall);
}
std::uint64_t bound(const World& w, RectI64 r) {
    std::uint64_t total = 0;
    for (auto y = r.y; y < r.y + r.height; ++y) {
        for (auto x = r.x; x < r.x + r.width; ++x) {
            const auto m = w.stored_material(x, y);
            if (m == Material::ActivatedBinder || m == Material::BinderCrust)
                total += w.stored_state_b(x, y);
        }
    }
    return total;
}
std::size_t count(const World& w, Material m, RectI64 r) {
    std::size_t total = 0;
    for (auto y = r.y; y < r.y + r.height; ++y)
        for (auto x = r.x; x < r.x + r.width; ++x)
            total += static_cast<std::size_t>(w.stored_material(x, y) == m);
    return total;
}
void tick(World& w) { (void)w.tick(); }

void capabilities_and_contacts() {
    std::size_t hard = 0;
    for (std::uint16_t id = 0; id < 132; ++id) {
        const bool expected = (id >= 38 && id <= 131) || id == 1 || id == 5 ||
            id == 7 || id == 9 || id == 28 || id == 31 || id == 35;
        require(MaterialRules::is_hard_surface(static_cast<Material>(id)) == expected,
                "old hard membership changed");
        hard += static_cast<std::size_t>(expected);
        const bool powder = id == 2 || id == 13 || id == 14 || id == 19 || id == 23 ||
            id == 25 || id == 26 || id == 27 || id == 29;
        require(MaterialRules::supports_granular_load(static_cast<Material>(id)) == powder,
                "old granular membership changed");
        require(chemical_parent(static_cast<Material>(id)) == static_cast<Material>(id),
                "old chemical identity changed");
    }
    require(hard == 101, "old hard population");
    for (const auto wall : {Material::StoneWall, Material::SaltWall, Material::CoalWall}) {
        require(MaterialRules::is_hard_surface(wall) && !MaterialRules::supports_granular_load(wall),
                "wall hard/non-granular capability");
        World w(config());
        w.set(8, 8, wall);
        for (int t = 0; t < 20; ++t) tick(w);
        require(w.stored_material(8, 8) == wall, "wall fell through empty space");
        for (std::uint16_t other = 0; other < 256; ++other) {
            for (const auto roll : {std::uint8_t{0}, std::uint8_t{64}, std::uint8_t{65}, std::uint8_t{255}}) {
                for (bool reverse : {false, true}) {
                    const auto source = reverse ? static_cast<Material>(other) : wall;
                    const auto target = reverse ? wall : static_cast<Material>(other);
                    const auto expected = InteractionRules::resolve_pair(
                        chemical_parent(source), chemical_parent(target), roll);
                    const auto actual = InteractionRules::resolve_pair(source, target, roll);
                    require(actual.matched == expected.matched && actual.selected == expected.selected &&
                            actual.rule_index == expected.rule_index && actual.reversed == expected.reversed,
                            "wall/parent role, threshold or precedence mismatch");
                    require(InteractionRules::may_pair(source, target) ==
                            InteractionRules::match_pair_from(InteractionRules::pair_rules(), source, target).matched,
                            "derived partner cache lost alias");
                }
            }
        }
    }
    const auto thaw = InteractionRules::resolve_pair(Material::SaltWall, Material::PackedSnow, 64);
    require(thaw.selected && thaw.source_product == Material::Brine && thaw.target_product == Material::Slush,
            "Salt wall thaw role products");
    require(!InteractionRules::resolve_pair(Material::SaltWall, Material::PackedSnow, 65).selected,
            "Salt wall thaw threshold");
    const auto dissolve = InteractionRules::resolve_pair(Material::Water, Material::SaltWall, 255);
    require(dissolve.selected && dissolve.source_product == Material::Brine && dissolve.target_product == Material::Brine,
            "Salt wall inherited dissolution");
    require(InteractionRules::has_pair_rule(Material::SaltWall), "Salt wall active compact participant");
    for (const auto m : {Material::DryBinder, Material::ActivatedBinder})
        require(!MaterialRules::is_hard_surface(m) && MaterialRules::supports_granular_load(m),
                "binder powder capability");
    require(MaterialRules::is_hard_surface(Material::BinderCrust), "crust hard capability");

    World salt(config()); box(salt);
    salt.set(8, 8, Material::SaltWall); salt.set(9, 8, Material::Water);
    for (int t = 0; t < 12 && salt.stored_material(8, 8) == Material::SaltWall; ++t) tick(salt);
    require(salt.stored_material(8, 8) == Material::Brine && salt.stored_material(9, 8) == Material::Brine,
            "Salt wall chemistry executes in native World");
}

void coal_and_acid() {
    for (const auto m : {Material::Coal, Material::CoalWall}) {
        World w(config()); box(w);
        w.set(8, 8, m); w.set(9, 8, Material::Lava);
        for (int t = 0; t < 8 && w.stored_state_b(8, 8) == 0; ++t) tick(w);
        require(w.stored_material(8, 8) == m && w.stored_state_b(8, 8) > 0,
                "Coal form is preserved on hot ignition");
        require(w.set_cell_state(9, 8, Material::Water, 255, 0), "Water extinguisher setup");
        for (int t = 0; t < 8 && w.stored_state_b(8, 8) != 0; ++t) tick(w);
        require(w.stored_material(8, 8) == m && w.stored_state_b(8, 8) == 0,
                "Coal form is preserved on extinguish");
        w.set(9, 8, Material::Wall);
        require(w.set_cell_state(8, 8, m, 0, 3), "burn state fixture");
        tick(w);
        require(w.stored_material(8, 8) == m, "Coal form is preserved during countdown");
        for (int t = 0; t < 10 && w.stored_material(8, 8) == m; ++t) tick(w);
        require(w.stored_material(8, 8) == Material::Dust, "Coal terminal Dust product");
    }
    // Enclose broad Acid with only the Stone form as its available target.
    for (const auto m : {Material::Stone, Material::StoneWall}) {
        auto acid_config = config();
        // The existing sampled broad-Acid kernel has no quiet-contact wake
        // deadline. Keep this bounded equivalence fixture live; sleep1 is
        // tested independently for the new finite-binder state machine.
        acid_config.sleep_after_quiet_ticks = 1000;
        World w(acid_config); box(w);
        w.set(8, 8, Material::Acid); w.set(9, 8, m);
        for (int t = 0; t < 240 && w.stored_material(9, 8) == m; ++t) tick(w);
        require(w.stored_material(9, 8) != m, "hard form accidentally exempted from broad Acid");
    }
    std::size_t quiet_stalls = 0;
    for (int y = 7; y <= 10; ++y) for (int x = 7; x <= 14; ++x) {
        World loose(config()); World wall(config());
        box(loose, x, y); box(wall, x, y);
        loose.set(x, y, Material::Coal); wall.set(x, y, Material::CoalWall);
        loose.set(x + 1, y, Material::Lava); wall.set(x + 1, y, Material::Lava);
        for (int t = 0; t < 16; ++t) {
            tick(loose); tick(wall);
            require(chemical_parent(wall.stored_material(x, y)) == loose.stored_material(x, y) &&
                    wall.stored_state_a(x, y) == loose.stored_state_a(x, y) &&
                    wall.stored_state_b(x, y) == loose.stored_state_b(x, y),
                    "quiet sampled Coal chemistry diverged between forms");
        }
        quiet_stalls += static_cast<std::size_t>(loose.stored_state_b(x, y) == 0);
    }
    std::cout << "PAIR_CURE old-coal-quiet1-stalls=" << quiet_stalls << "/32 (matched wall/loose)\n";
}

void dose_matrix() {
    constexpr RectI64 bounds{0, 0, 64, 64};
    for (int family : {1, 2, 3, 4}) for (std::uint8_t bits : {std::uint8_t{3}, std::uint8_t{8}}) {
        for (auto workers : {1U, 4U}) for (int doses : {1, 2}) {
            World w(config(family, bits, workers));
            const auto q = w.config().water_experiment_policy.maximum();
            for (int i = 0; i < 3; ++i) {
                const int x = 8 + i * 16;
                box(w, x, 8); w.set(x, 8, Material::DryBinder);
                if (i < doses) w.set(x + 1, 8, Material::Water);
            }
            const auto supply = static_cast<std::uint64_t>(q) * static_cast<std::uint64_t>(doses);
            const auto revision = w.hard_surface_revision();
            for (int t = 0; t < 360; ++t) {
                tick(w);
                require(w.water_quantity(bounds) + bound(w, bounds) == supply,
                        "free plus bound Water must close at every tick");
                require(count(w, Material::ActivatedBinder, bounds) + count(w, Material::BinderCrust, bounds) <=
                        static_cast<std::size_t>(doses), "finite dose cannot propagate activation");
            }
            require(count(w, Material::BinderCrust, bounds) == static_cast<std::size_t>(doses) &&
                    count(w, Material::DryBinder, bounds) == static_cast<std::size_t>(3 - doses),
                    "dose population after finite countdown");
            const auto ledger = w.quantity_ledger();
            require(ledger.schema_version == 2 && ledger.kernel_rules.size() == 20 &&
                    ledger.kernel_rules[19].consumed == supply && ledger.kernel_rules[19].produced == 0,
                    "new provenance slot accounts consumed free Water");
            require(w.hard_surface_revision() > revision, "curing invalidates hard terrain");
            if (family == 3) require(w.pressure_cell(9, 8).overfill == 0, "pressure sidecar retired");
            if (family == 4) {
                const auto side = w.inertial_cell(9, 8);
                require(side.vx == 0 && side.vy == 0 && side.ax == 0 && side.ay == 0, "IN sidecar retired");
            }
        }
    }
}

void finite_negative_controls() {
    constexpr RectI64 bounds{0, 0, 32, 32};
    for (const auto neighbor : {Material::Empty, Material::Concrete, Material::BinderCrust, Material::ActivatedBinder}) {
        World w(config()); box(w);
        w.set(8, 8, Material::DryBinder); w.set(9, 8, neighbor);
        if (neighbor == Material::ActivatedBinder)
            require(w.set_cell_state(9, 8, neighbor, 120, 255), "activated neighbor fixture");
        for (int t = 0; t < 360; ++t) tick(w);
        require(count(w, Material::DryBinder, bounds) >= 1, "neighbor alone must not activate dry binder");
        require(count(w, Material::BinderCrust, bounds) ==
                    static_cast<std::size_t>(neighbor == Material::BinderCrust || neighbor == Material::ActivatedBinder),
                "no-agent negative front must stop");
    }
    World zero(config()); box(zero); zero.set(8, 8, Material::ActivatedBinder);
    tick(zero);
    require(zero.stored_material(8, 8) == Material::DryBinder, "zero-bound authored activation cannot cure");
    World removed(config()); box(removed);
    removed.set(8, 8, Material::DryBinder); removed.set(9, 8, Material::Water);
    require(removed.set_cell_state(9, 8, Material::Empty, 0, 0), "remove supplied agent before tick");
    for (int t = 0; t < 360; ++t) tick(removed);
    require(removed.stored_material(8, 8) == Material::DryBinder && bound(removed, bounds) == 0,
            "removed agent cannot activate later");
    World partial(config()); box(partial);
    partial.set(8, 8, Material::DryBinder);
    require(partial.set_cell_state(9, 8, Material::Water, 254, 12), "partial Water fixture");
    for (int t = 0; t < 20; ++t) tick(partial);
    require(partial.stored_material(8, 8) == Material::DryBinder && partial.water_quantity(bounds) == 254,
            "partial Water refusal is unchanged");

    for (bool mask_dry : {false, true}) {
        World w(config()); box(w); w.set(8, 8, Material::DryBinder); w.set(9, 8, Material::Water);
        w.configure_transient_obstacles(bounds);
        require(w.set_transient_obstacle(mask_dry ? 8 : 9, 8, 1), "transient mask fixture");
        for (int t = 0; t < 20; ++t) tick(w);
        require(w.stored_material(8, 8) == Material::DryBinder &&
                w.quantity_ledger().water_visible == 255 && bound(w, bounds) == 0,
                "masked source/agent cannot react or disappear");
        w.clear_transient_obstacles();
        for (int t = 0; t < 360; ++t) tick(w);
        require(w.stored_material(8, 8) == Material::BinderCrust && bound(w, bounds) == 255,
                "mask release wakes admitted contact");
    }
    World moving(config()); rect(moving, 3, 15, 16, 1, Material::Wall);
    require(moving.set_cell_state(8, 4, Material::ActivatedBinder, 180, 255), "moving activated grain");
    for (int t = 0; t < 180; ++t) tick(moving);
    require(count(moving, Material::BinderCrust, bounds) == 1 && bound(moving, bounds) == 255,
            "moving grain preserves bound quantity/countdown");
}

void storage_edges_and_overfill() {
    for (auto workers : {1U, 4U}) for (int shift : {-16, 0}) {
        World w(config(1, 8, workers));
        const int x = 15 + shift;
        box(w, x, 15); w.set(x, 15, Material::DryBinder); w.set(x + 1, 15, Material::Water);
        const auto chunks = w.chunk_count();
        for (int t = 0; t < 360; ++t) tick(w);
        require(w.stored_material(x, 15) == Material::BinderCrust &&
                w.stored_state_b(x, 15) == 255 && w.chunk_count() == chunks,
                "chunk/core/negative-coordinate activation needs no tick allocation");
    }
    auto capped = config(); capped.maximum_chunk_count = 1;
    capped.initial_chunk_reserve = 1;
    World capacity(capped); box(capacity);
    capacity.set(8, 8, Material::DryBinder); capacity.set(9, 8, Material::Water);
    for (int t = 0; t < 360; ++t) tick(capacity);
    require(capacity.chunk_count() == 1 && capacity.stored_material(8, 8) == Material::BinderCrust,
            "full storage capacity still uses existing local slots only");

    // Establish real pressure overfill while the upper receiver is Empty, then
    // author a supported side-adjacent dry grain without touching the receiver.
    auto pc = config(3); pc.chunk_size = 8;
    World pressure(pc);
    pressure.set_simulation_region(RectI64{0, 400, 8, 8});
    rect(pressure, 3, 1, 1, 400, Material::Water);
    pressure.set(2, 400, Material::Wall); pressure.set(5, 400, Material::Wall);
    rect(pressure, 2, 401, 4, 1, Material::Wall);
    require(pressure.set_cell_state(4, 400, Material::Water, 255, 12), "pressure receiver fixture");
    for (int t = 0; t < 6 && pressure.pressure_cell(4, 400).overfill == 0; ++t) tick(pressure);
    require(pressure.pressure_cell(4, 400).overfill > 0, "actual pressure overfill acquired");
    const auto quantity = pressure.water_quantity({0, 0, 8, 408});
    pressure.set(4, 399, Material::Wall);
    pressure.set(5, 400, Material::DryBinder);
    pressure.set(5, 399, Material::Wall);
    pressure.set(6, 401, Material::Wall);
    pressure.configure_transient_obstacles({0, 396, 8, 12});
    // Close the receiver's left relay while retaining every stored quantity.
    require(pressure.set_transient_obstacle(3, 400, 1), "mask receiver relay");
    pressure.set_simulation_region(RectI64{0, 392, 8, 16});
    tick(pressure);
    require(pressure.stored_material(5, 400) == Material::DryBinder &&
            pressure.stored_state_b(5, 400) == 0 && pressure.pressure_cell(4, 400).overfill > 0 &&
            pressure.water_quantity({0, 0, 8, 408}) == quantity,
            "overfilled Water refuses activation without quantity loss");
}

void rim_depth_and_freshness() {
    constexpr int top = 16;
    constexpr RectI64 bounds{0, 0, 64, 64};
    for (int family : {1, 2}) {
        World w(config(family, 8, 4));
        rect(w, 7, 14, 1, 27, Material::Wall);
        rect(w, 40, 14, 1, 27, Material::Wall);
        rect(w, 7, 40, 34, 1, Material::Wall);
        rect(w, 8, top, 32, 24, Material::DryBinder);
        for (int t = 0; t < 20; ++t) tick(w);
        require(count(w, Material::DryBinder, bounds) == 768, "registered packed dry population");
        rect(w, 16, top - 1, 16, 1, Material::Water);
        for (int t = 0; t < 360; ++t) {
            tick(w);
            require(w.water_quantity(bounds) + bound(w, bounds) == 16U * 255U,
                    "rim free plus bound quantity");
            require(count(w, Material::DryBinder, bounds) + count(w, Material::ActivatedBinder, bounds) +
                    count(w, Material::BinderCrust, bounds) == 768,
                    "rim binder parcel population");
        }
        int deepest = -1;
        std::size_t crusts = 0;
        for (int y = 0; y < 64; ++y) for (int x = 0; x < 64; ++x) {
            if (w.stored_material(x, y) != Material::BinderCrust) continue;
            ++crusts; deepest = std::max(deepest, y - top);
        }
        std::cout << "PAIR_CURE rim family=" << family << " crusts=" << crusts << " deepest=" << deepest << "\n";
        require(crusts >= 8, "surface gate requires substantive non-vacuous curing");
        require(deepest >= 0 && deepest <= 2, "activated parcels sank through dry bed instead of forming rim");
        if (family == 2) require(crusts == 16, "whole-cell dose population closes exactly");
    }
    World fresh(config());
    rect(fresh, 48, 104, 32, 1, Material::Wall);
    for (int y = 100; y < 104; ++y) for (int x = 48; x < 80; ++x)
        require(fresh.set_cell_state(x, y, Material::ActivatedBinder, 180, 255), "valid activated support fixture");
    tick(fresh);
    require(!fresh.granular_support_at(64, 100), "changing cure state must obey existing sample freshness");
    for (int t = 0; t < 180; ++t) tick(fresh);
    require(fresh.stored_material(64, 100) == Material::BinderCrust &&
            !fresh.granular_support_at(64, 100) && MaterialRules::is_hard_surface(Material::BinderCrust) &&
            !MaterialRules::supports_granular_load(Material::BinderCrust),
            "completed cure enters hard terrain rather than bypassing granular freshness");
}

void persistence() {
    World w(config()); box(w); w.set(8, 8, Material::DryBinder); w.set(9, 8, Material::Water);
    for (int t = 0; t < 30; ++t) tick(w);
    require(w.stored_material(8, 8) == Material::ActivatedBinder && w.stored_state_b(8, 8) == 255,
            "mid-cure persistence fixture");
    const auto physical = w.save_physical_state();
    auto restored = World::restore_physical_state(w.config(), physical);
    require(restored->physical_state_hash() == w.physical_state_hash(), "complete physical roundtrip");
    for (int t = 0; t < 180; ++t) { tick(w); tick(*restored); }
    require(restored->stored_material(8, 8) == Material::BinderCrust &&
            restored->stored_state_b(8, 8) == 255 && restored->physical_state_hash() == w.physical_state_hash(),
            "restored cure continuation is exact");

    // This nonpressure/non-IN fixture has no construction seed: its final
    // typed ledger is followed by one false pressure flag and the SHA256.
    // Locate that exact wire boundary, not a potentially repeated byte prefix.
    constexpr std::size_t ledger_bytes = 2U + 1U + 3U * 8U +
        kQuantityKindCount * 16U + kQuantityPairRuleSlots * 16U +
        kQuantityPairRuleSlots * 8U + kQuantityKernelRuleSlots * 16U +
        kQuantityMaterialSlots * 8U * 2U + 1U;
    auto corrupt = w.save_physical_state();
    require(corrupt.size() > ledger_bytes + 33U && corrupt[corrupt.size() - 33U] == 0,
            "nonpressure quantity wire suffix");
    const auto offset = corrupt.size() - 33U - ledger_bytes;
    require(corrupt[offset] == 2 && corrupt[offset + 1U] == 0 && corrupt[offset + 2U] == 8,
            "quantity schema boundary located");
    corrupt[offset] = 1;
    const auto digest = Sha256::of(std::span<const std::uint8_t>(corrupt).first(corrupt.size() - 32U));
    std::copy(digest.begin(), digest.end(), corrupt.end() - 32);
    bool refused = false;
    try { (void)World::restore_physical_state(w.config(), corrupt); }
    catch (const std::invalid_argument& e) {
        refused = std::string(e.what()).find("invalid quantity ledger encoding") != std::string::npos;
        if (!refused) std::cout << "PAIR_CURE unexpected schema refusal=" << e.what() << "\n";
    }
    require(refused, "old quantity schema explicitly rejects instead of shifting fields");

    auto level = demo::empty_level(config());
    require(level->set_cell_state(8, 8, Material::ActivatedBinder, 73, 255), "level activated state");
    level->set_temperature(8, 8, -321);
    level->set(9, 8, Material::CoalWall);
    std::vector<std::uint8_t> bytes(demo::kPayloadBytes);
    demo::copy_level(*level, bytes);
    auto loaded = demo::reconstruct(config(), bytes);
    require(loaded->stored_material(8, 8) == Material::ActivatedBinder && loaded->stored_state_a(8, 8) == 73 &&
            loaded->stored_state_b(8, 8) == 255 && loaded->stored_temperature(8, 8) == -321 &&
            loaded->stored_material(9, 8) == Material::CoalWall, "CYSD1 material/activation/bound/temperature roundtrip");
}

} // namespace

void run_paired_material_tests() {
    std::cout << std::unitbuf << "PAIR_CURE phase=contacts\n";
    capabilities_and_contacts();
    std::cout << "PAIR_CURE phase=coal-acid\n";
    coal_and_acid();
    std::cout << "PAIR_CURE phase=doses\n";
    dose_matrix();
    std::cout << "PAIR_CURE phase=negatives\n";
    finite_negative_controls();
    std::cout << "PAIR_CURE phase=boundaries\n";
    storage_edges_and_overfill();
    std::cout << "PAIR_CURE phase=rim-depth\n";
    rim_depth_and_freshness();
    std::cout << "PAIR_CURE phase=persistence\n";
    persistence();
    std::cout << "PAIR_CURE_001 checks=" << checks << " failures=0\n";
}
