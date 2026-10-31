// Independent extraction benchmark. Use the repository's existing -O3/-flto
// release flags or -O0/-g3 debug flags, with CYBERSAND_RENDER_COPY_EXPERIMENT.
// No worker retries, ACKs, adapter marshaling, or texture uploads are involved.
#include "cybersand/world.hpp"

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

#ifndef CYBERSAND_RENDER_COPY_EXPERIMENT
#error Stage-C benchmark requires CYBERSAND_RENDER_COPY_EXPERIMENT
#endif

namespace {
using namespace cybersand;
using Clock = std::chrono::steady_clock;

void populate(World& world, bool dense) {
    std::vector<Material> chunk(128U * 128U);
    for (std::int64_t cy = 0; cy < 8; ++cy) {
        for (std::int64_t cx = 0; cx < 8; ++cx) {
            if (!dense && (cx + cy * 3) % 7 != 0) continue;
            for (std::size_t index = 0; index < chunk.size(); ++index) {
                const auto id = static_cast<std::uint16_t>((index * 17U +
                    static_cast<std::size_t>(cx + cy * 8)) % kMaterialDefinitions.size());
                chunk[index] = valid_material(id) ? static_cast<Material>(id) : Material::Wall;
            }
            if (world.install_generated_chunk({cx, cy}, chunk) != ChunkInstallOutcome::Installed)
                throw std::runtime_error("fixture chunk installation refused");
        }
    }
}

void metrics_json(const RenderCopyExperimentMetrics& metric) {
    std::cout << "{\"cells\":" << metric.cells
        << ",\"address_calculations\":" << metric.address_calculations
        << ",\"chunk_lookups\":" << metric.chunk_lookups
        << ",\"absent_chunk_lookups\":" << metric.absent_chunk_lookups
        << ",\"absent_cells\":" << metric.absent_cells
        << ",\"material_reads\":" << metric.material_reads
        << ",\"state_reads\":" << metric.state_reads
        << ",\"visual_projections\":" << metric.visual_projections
        << ",\"counted_elapsed_ns\":" << metric.elapsed_ns << '}';
}

std::uint64_t percentile(const std::vector<std::uint64_t>& sorted, std::size_t numerator) {
    return sorted[(sorted.size() * numerator + 99U) / 100U - 1U];
}

void times_json(const std::vector<std::uint64_t>& samples, std::uint64_t cells) {
    const auto median = percentile(samples, 50);
    std::cout << "{\"p50_ns\":" << median
        << ",\"p95_ns\":" << percentile(samples, 95)
        << ",\"max_ns\":" << samples.back()
        << ",\"p50_cells_per_second\":" << static_cast<double>(cells) * 1.0e9 / static_cast<double>(median)
        << ",\"samples_ns\":[";
    for (std::size_t index = 0; index < samples.size(); ++index) {
        if (index) std::cout << ',';
        std::cout << samples[index];
    }
    std::cout << "]}";
}

void benchmark(const World& world, const char* density, const char* name, RectI64 region,
               std::size_t samples) {
    const auto stride = static_cast<std::size_t>(region.width) * 2U;
    const auto size = stride * static_cast<std::size_t>(region.height);
    std::vector<std::uint8_t> original(size), run(size);
    const auto before = world.physical_state_hash();
    const auto dirty_before = world.dirty_chunk_count();
    const auto revision_before = world.hard_surface_revision();
    const auto chunks_before = world.chunk_count();
    for (int warmup = 0; warmup < 3; ++warmup) {
        world.copy_render_cells(region, original, stride);
        world.copy_render_cells_by_run(region, run, stride);
    }
    std::vector<std::uint64_t> original_ns, run_ns;
    for (std::size_t index = 0; index < samples; ++index) {
        const auto copy = [&](bool by_run) {
            const auto started = Clock::now();
            if (by_run) world.copy_render_cells_by_run(region, run, stride);
            else world.copy_render_cells(region, original, stride);
            const auto elapsed = static_cast<std::uint64_t>(
                std::chrono::duration_cast<std::chrono::nanoseconds>(Clock::now() - started).count());
            (by_run ? run_ns : original_ns).push_back(elapsed);
        };
        // Alternate order in one process to reduce order/cache bias. These are
        // paired warm extraction distributions, not independent process runs.
        copy(index % 2U != 0U); copy(index % 2U == 0U);
        if (original != run) throw std::runtime_error("differential mismatch in benchmark");
    }
    RenderCopyExperimentMetrics original_metrics, run_metrics;
    world.profile_render_cells_original(region, original, stride, original_metrics);
    world.copy_render_cells_by_run(region, run, stride, &run_metrics);
    if (original != run || before != world.physical_state_hash() ||
        dirty_before != world.dirty_chunk_count() || revision_before != world.hard_surface_revision() ||
        chunks_before != world.chunk_count()) throw std::runtime_error("copy mutated World or differed");
    std::sort(original_ns.begin(), original_ns.end()); std::sort(run_ns.begin(), run_ns.end());
    std::cout << "{\"schema\":\"render-copy-isolation-v1\",\"density\":\"" << density
        << "\",\"case\":\"" << name << "\",\"region\":[" << region.x << ',' << region.y << ','
        << region.width << ',' << region.height << "],\"samples\":" << samples
        << ",\"byte_exact\":true,\"world_unchanged\":true,\"original\":";
    times_json(original_ns, original_metrics.cells);
    std::cout << ",\"by_run\":"; times_json(run_ns, run_metrics.cells);
    std::cout << ",\"p50_speedup\":" << static_cast<double>(percentile(original_ns, 50)) /
        static_cast<double>(percentile(run_ns, 50)) << ",\"original_structural\":";
    metrics_json(original_metrics); std::cout << ",\"run_structural\":";
    metrics_json(run_metrics); std::cout << "}\n";
}
}

int main(int argc, char** argv) {
    try {
        std::size_t samples = 31;
        if (argc > 2) throw std::invalid_argument("usage: render_copy_isolation [samples 3..1000]");
        if (argc == 2) {
            std::size_t consumed = 0;
            const auto parsed = std::stoul(argv[1], &consumed);
            if (consumed != std::string(argv[1]).size() || parsed < 3 || parsed > 1000)
                throw std::invalid_argument("sample count must be 3..1000");
            samples = parsed;
        }
        for (const bool dense : {false, true}) {
            World world; populate(world, dense);
            const auto* density = dense ? "dense" : "sparse";
            benchmark(world, density, "full_frame", {0, 0, 1024, 1024}, samples);
            benchmark(world, density, "dirty_small", {119, 127, 32, 24}, samples);
            benchmark(world, density, "dirty_large", {64, 80, 384, 256}, samples);
            benchmark(world, density, "negative_offset", {-33, -17, 256, 192}, samples);
        }
        World absent;
        benchmark(absent, "absent", "full_frame", {0, 0, 1024, 1024}, samples);
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "RENDER_COPY_ISOLATION_ERROR: " << error.what() << '\n';
        return 1;
    }
}
