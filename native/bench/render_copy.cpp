// Paired extraction-only benchmark. Production calls have no diagnostic flags
// or alternate implementation. The literal current-main oracle is test-only.
#include "../tests/render_copy_reference.hpp"

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using namespace cybersand;
using Clock = std::chrono::steady_clock;

void populate(World& world, bool dense) {
    std::vector<Material> chunk(128U * 128U);
    for (std::int64_t cy = 0; cy < 8; ++cy) for (std::int64_t cx = 0; cx < 8; ++cx) {
        if (!dense && (cx + cy * 3) % 7 != 0) continue;
        for (std::size_t index = 0; index < chunk.size(); ++index) {
            const auto id = static_cast<std::uint16_t>((index * 17U +
                static_cast<std::size_t>(cx + cy * 8)) % kMaterialDefinitions.size());
            chunk[index] = valid_material(id) ? static_cast<Material>(id) : Material::Wall;
        }
        if (world.install_generated_chunk({cx, cy}, chunk) != ChunkInstallOutcome::Installed)
            throw std::runtime_error("benchmark fixture chunk installation refused");
    }
}

std::uint64_t percentile(const std::vector<std::uint64_t>& sorted, std::size_t numerator) {
    return sorted[(sorted.size() * numerator + 99U) / 100U - 1U];
}

void times_json(const std::vector<std::uint64_t>& samples) {
    auto sorted = samples;
    std::sort(sorted.begin(), sorted.end());
    std::cout << "{\"p50_ns\":" << percentile(sorted, 50)
        << ",\"p95_ns\":" << percentile(sorted, 95)
        << ",\"p99_ns\":" << percentile(sorted, 99)
        << ",\"max_ns\":" << sorted.back() << ",\"samples_ns\":[";
    for (std::size_t index = 0; index < samples.size(); ++index) {
        if (index) std::cout << ',';
        std::cout << samples[index];
    }
    std::cout << "]}";
}

void benchmark(const World& world, const char* density, const char* name,
               RectI64 region, std::size_t samples, const std::string& implementation) {
    const auto stride = static_cast<std::size_t>(region.width) * 2U;
    const auto size = stride * static_cast<std::size_t>(region.height);
    std::vector<std::uint8_t> reference(size), run(size);
    const auto before = world.save_physical_state();
    const auto physical = world.physical_state_hash();
    const auto dirty = world.dirty_chunk_count();
    const auto revision = world.hard_surface_revision();
    const auto chunks = world.chunk_count();
    for (int warmup = 0; warmup < 3; ++warmup) {
        render_copy_reference::copy(world, region, reference, stride);
        world.copy_render_cells(region, run, stride);
    }
    std::vector<std::uint64_t> reference_ns, run_ns;
    reference_ns.reserve(samples); run_ns.reserve(samples);
    for (std::size_t index = 0; index < samples; ++index) {
        const auto measure = [&](bool by_run) {
            const auto started = Clock::now();
            if (by_run) world.copy_render_cells(region, run, stride);
            else render_copy_reference::copy(world, region, reference, stride);
            const auto elapsed = static_cast<std::uint64_t>(
                std::chrono::duration_cast<std::chrono::nanoseconds>(Clock::now() - started).count());
            (by_run ? run_ns : reference_ns).push_back(elapsed);
        };
        // Paired warm measurements with alternating order. Fresh processes are
        // distinct repetitions; this does not pretend each sample is a process.
        measure(index % 2U != 0U); measure(index % 2U == 0U);
        if (reference != run) throw std::runtime_error("benchmark differential mismatch");
    }
    if (before != world.save_physical_state() || physical != world.physical_state_hash() ||
        dirty != world.dirty_chunk_count() || revision != world.hard_surface_revision() ||
        chunks != world.chunk_count()) throw std::runtime_error("benchmark extraction mutated World");
    const auto cells = static_cast<std::uint64_t>(region.width) * static_cast<std::uint64_t>(region.height);
    const auto runs = render_copy_reference::row_runs(region, world.config().chunk_size);
    // The label describes which source was compiled; it does not select an
    // implementation. Build this executable with frozen-main world.cpp for
    // control, and with the candidate world.cpp for R, using identical flags.
    const auto production_lookups = implementation == "R" ? runs : cells * 3U;
    std::cout << "{\"schema\":\"render-copy-production-v1\",\"implementation\":\"" << implementation
        << "\",\"density\":\"" << density
        << "\",\"case\":\"" << name << "\",\"region\":[" << region.x << ',' << region.y << ','
        << region.width << ',' << region.height << "],\"samples\":" << samples
        << ",\"warmups\":3,\"byte_exact\":true,\"world_unchanged\":true,\"reference\":";
    times_json(reference_ns);
    std::cout << ",\"production\":"; times_json(run_ns);
    std::cout << ",\"structural_kind\":\"derived_from_source_and_geometry_not_observed\""
        << ",\"reference_addresses\":" << cells * 3U
        << ",\"reference_chunk_lookups\":" << cells * 3U
        << ",\"production_addresses\":" << production_lookups
        << ",\"production_chunk_lookups\":" << production_lookups
        << ",\"production_contiguous_runs\":" << (implementation == "R" ? runs : 0U) << "}\n";
}
}  // namespace

int main(int argc, char** argv) {
    try {
        std::size_t samples = 41;
        std::string implementation = "R";
        bool samples_supplied = false;
        for (int argument = 1; argument < argc; ++argument) {
            const std::string value(argv[argument]);
            if (value == "--implementation") {
                if (++argument >= argc) throw std::invalid_argument("--implementation requires control or R");
                implementation = argv[argument];
                if (implementation != "control" && implementation != "R")
                    throw std::invalid_argument("implementation label must be control or R");
                continue;
            }
            if (samples_supplied) throw std::invalid_argument("usage: render_copy [samples 30..1000] [--implementation control|R]");
            std::size_t consumed = 0;
            const auto parsed = std::stoul(value, &consumed);
            if (consumed != value.size() || parsed < 30 || parsed > 1000)
                throw std::invalid_argument("sample count must be 30..1000");
            samples = parsed;
            samples_supplied = true;
        }
        for (const bool dense : {false, true}) {
            World world; populate(world, dense);
            const auto* density = dense ? "dense" : "sparse";
            benchmark(world, density, "full_frame", {0, 0, 1024, 1024}, samples, implementation);
            benchmark(world, density, "partial_small", {119, 127, 32, 24}, samples, implementation);
            benchmark(world, density, "partial_large", {64, 80, 384, 256}, samples, implementation);
            benchmark(world, density, "negative_offset", {-33, -17, 256, 192}, samples, implementation);
        }
        World absent;
        benchmark(absent, "absent", "full_frame", {0, 0, 1024, 1024}, samples, implementation);
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "RENDER_COPY_BENCHMARK_ERROR: " << error.what() << '\n';
        return 1;
    }
}
