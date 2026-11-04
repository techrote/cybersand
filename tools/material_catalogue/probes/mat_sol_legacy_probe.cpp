// Independent MAT/SOL investigation apparatus. No production import/cutover.
// Compile this same file against accepted main and a separately pinned SOL tree.
// JSONL observations are compared by the caller; no candidate expected hashes
// are embedded here. Exact persistence bytes include native sidecar/ledger data.
#include "cybersand/world.hpp"
#include "cybersand/material_rules.hpp"
#include "cybersand/sha256.hpp"
#include <algorithm>
#include <array>
#include <cstdint>
#include <iostream>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>

using namespace cybersand;
namespace {
void require(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}
WorldConfig configuration(unsigned workers, unsigned family) {
    WorldConfig c;
    c.worker_threads = workers;
    c.parallel_job_threshold = 1;
    c.maximum_chunk_count = 64;
    c.active_chunk_capacity = 64;
    c.active_core_capacity = 512;
    if (family != 0) {
        auto words = LiquidSolverPolicy::default_request();
        words[21] = static_cast<std::int32_t>(family);
        if (family == 4) {
            words[39] = 4; // Brine row 6 in the frozen liquid request.
            c.maximum_rule_radius = InertialParameters::kExecutionRadius;
        }
        const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
        require(decoded.accepted(), "registered liquid policy must be accepted");
        c.liquid_solver_policy = *decoded.policy;
    }
    return c;
}
void configure_mode(World& world, std::string_view mode) {
#ifdef MAT_SOL_EXTENSION
    if (mode != "disabled") {
        const auto outcome = world.configure_solid_detachment();
        const bool excluded = world.pressure_flow_enabled() || world.inertial_enabled();
        require(outcome == (excluded ? soliding::SolidOutcome::Ineligible
                                    : soliding::SolidOutcome::Accepted),
                "idle SOL configuration must preserve constructor-sidecar exclusions");
        if (!excluded && mode == "invalid") {
            const soliding::SolidRequest bad{{0, 0, 0, 0}, {0, 0, 1, 1}, 0, 0};
            require(world.prepare_solid_detachment(bad) == soliding::SolidOutcome::Invalid,
                    "malformed domain must refuse");
            require(!world.solid_detachment_fenced(), "rejected preparation must remain unfenced");
        }
    }
#endif
    if (mode == "reset") world.clear();
}
void enclosure(World& world, std::int64_t x, std::int64_t y, Material material) {
    for (int i = 0; i < 12; ++i) {
        world.set(x + i, y, Material::Wall);
        world.set(x + i, y + 11, Material::Wall);
        world.set(x, y + i, Material::Wall);
        world.set(x + 11, y + i, Material::Wall);
    }
    world.set(x + 4, y + 3, material);
    world.set(x + 5, y + 3, material);
    world.set_temperature(x + 4, y + 3, 240);
    world.set(x + 5, y + 8, Material::Sand);
    world.set(x + 6, y + 8, Material::Water);
    world.set(x + 7, y + 8, Material::Salt);
}
void emit(World& world, std::string_view name, unsigned sample, unsigned observed) {
    const auto bytes = world.save_physical_state();
    const auto hash = world.physical_state_hash();
    const auto same_tick = world.liquid_comparison_hash(LiquidStateProjection::PressureVariantEquivalenceV1);
    const auto quiescent = world.liquid_comparison_hash(LiquidStateProjection::QuiescentPhysicalContentV1);
    const auto restored = World::restore_physical_state(world.config(), bytes);
    require(restored->save_physical_state() == bytes, "saved bytes must round-trip exactly");
    // The registered fixture's single transient body mask belongs to the host:
    // physical hashes include it, while CYPS deliberately does not serialize it.
    // Preserve both hashes and this distinction rather than calling the native
    // save an exact restoration of external host-owned state.
    const bool host_mask = world.transient_obstacle_at(11, 11) != 0;
    const auto restored_hash = restored->physical_state_hash();
    if (!host_mask) require(restored_hash == hash, "unmasked restored physical hash must match");
    std::cout << "{\"case\":\"" << name << "\",\"sample\":" << sample
              << ",\"tick\":" << world.tick_index()
              << ",\"content_hash\":" << world.content_hash()
              << ",\"state_hash\":" << world.state_hash()
              << ",\"physical_hash\":" << hash
              << ",\"same_tick_hash\":" << same_tick
              << ",\"quiescent_hash\":" << quiescent
              << ",\"restored_physical_hash\":" << restored_hash
              << ",\"external_host_mask\":" << (host_mask ? "true" : "false")
              << ",\"save_sha256\":\"" << Sha256::hex(Sha256::of(bytes))
              << "\",\"save_bytes\":" << bytes.size()
              << ",\"water_quantity\":" << world.water_quantity({0, 0, 512, 256})
              << ",\"active_chunks\":" << world.active_chunk_count()
              << ",\"chunks\":" << world.chunk_count()
              << ",\"terrain_revision\":" << world.hard_surface_revision()
              << ",\"workers_observed\":" << observed << "}\n";
}
void material_cases(unsigned workers, std::string_view mode) {
    for (unsigned id = 0; id <= static_cast<unsigned>(kLastMaterial); ++id) {
        if (!valid_material(static_cast<std::uint16_t>(id))) continue;
        World world(configuration(workers, 0));
        configure_mode(world, mode);
        world.reserve_region({0, 0, 128, 128});
        const auto material = static_cast<Material>(id);
        enclosure(world, 4, 4, material);
        enclosure(world, 64, 64, material); // crosses a scheduling-core offset.
        const auto name = "material-" + std::to_string(id);
        emit(world, name, 0, 0);
        unsigned observed = 0;
        for (unsigned step = 1; step <= 12; ++step) {
            observed = std::max(observed, world.tick().worker_threads_observed);
            if (step == 3 || step == 12) emit(world, name, step, observed);
        }
    }
}
void liquid_cases(unsigned workers, std::string_view mode) {
    for (const unsigned family : {0U, 2U, 3U, 4U}) {
        World world(configuration(workers, family));
        configure_mode(world, mode);
        world.reserve_region({0, 0, 512, 256});
        for (int y = 0; y < 4; ++y) for (int x = 0; x < 8; ++x) {
            const auto material = x % 3 == 0 ? Material::Water : x % 3 == 1 ? Material::Brine : Material::Oil;
            enclosure(world, 6 + x * 64, 6 + y * 64, material);
        }
        world.configure_transient_obstacles({0, 0, 512, 256});
        require(world.set_transient_obstacle(11, 11, 1), "mask setup");
        const auto name = "liquid-family-" + std::to_string(family);
        emit(world, name, 0, 0);
        unsigned observed = 0;
        for (unsigned step = 1; step <= 20; ++step) {
            if (step == 7) world.set_simulation_region(RectI64{0, 0, 256, 256});
            if (step == 10) world.set_simulation_region(std::nullopt);
            if (step == 13) world.clear_transient_obstacles();
            observed = std::max(observed, world.tick().worker_threads_observed);
            if (step == 6 || step == 9 || step == 12 || step == 20) emit(world, name, step, observed);
        }
    }
}
} // namespace
int main(int argc, char** argv) {
    try {
        if (argc != 3) throw std::runtime_error("usage: probe WORKERS disabled|idle|invalid|reset");
        const auto workers = static_cast<unsigned>(std::stoul(argv[1]));
        const std::string_view mode(argv[2]);
        require(workers == 1 || workers == 4, "workers must be 1 or 4");
        require(mode == "disabled" || mode == "idle" || mode == "invalid" || mode == "reset", "unknown mode");
        material_cases(workers, mode);
        liquid_cases(workers, mode);
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "mat-sol legacy probe: " << e.what() << '\n';
        return 1;
    }
}
