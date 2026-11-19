// Source-neutral default-Water comparison apparatus. Compile this same file
// against both source trees; it uses only their shared public World interface.
// Usage: wave_default_off_pair SIZE SCENE WORKERS WARM TICKS
// SCENE: dam | sparse | idle. Only complete World::tick() calls are timed.
#include "cybersand/world.hpp"

#include <algorithm>
#include <array>
#include <charconv>
#include <chrono>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <limits>
#include <locale>
#include <memory>
#include <optional>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>
#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#include <psapi.h>
#else
#include <sys/resource.h>
#endif

using namespace cybersand;

namespace {

int integer(std::string_view text) {
    int value = 0;
    const auto result = std::from_chars(text.data(), text.data() + text.size(), value);
    if (result.ec != std::errc{} || result.ptr != text.data() + text.size())
        throw std::invalid_argument("arguments must be complete decimal integers");
    return value;
}

std::uint64_t checked_add(std::uint64_t a, std::uint64_t b) {
    if (b > std::numeric_limits<std::uint64_t>::max() - a)
        throw std::runtime_error("quantity or measurement counter overflow");
    return a + b;
}

std::uint64_t peak_rss_bytes() {
#ifdef _WIN32
    PROCESS_MEMORY_COUNTERS counters{};
    if (!GetProcessMemoryInfo(GetCurrentProcess(), &counters, sizeof(counters)))
        throw std::runtime_error("GetProcessMemoryInfo failed");
    return static_cast<std::uint64_t>(counters.PeakWorkingSetSize);
#else
    rusage usage{};
    if (getrusage(RUSAGE_SELF, &usage) != 0 || usage.ru_maxrss < 0)
        throw std::runtime_error("getrusage failed");
    return static_cast<std::uint64_t>(usage.ru_maxrss) * 1024ULL;
#endif
}

void rect(World& world, int x, int y, int width, int height, Material material) {
    for (int yy = y; yy < y + height; ++yy)
        for (int xx = x; xx < x + width; ++xx) world.set(xx, yy, material);
}

void build_scene(World& world, const std::string& scene, int n) {
    rect(world, 0, 0, n, 1, Material::Wall);
    rect(world, 0, n - 1, n, 1, Material::Wall);
    rect(world, 0, 0, 1, n, Material::Wall);
    rect(world, n - 1, 0, 1, n, Material::Wall);
    if (scene == "dam") {
        rect(world, 1, n / 4, n / 3, n - 1 - n / 4, Material::Water);
    } else if (scene == "idle") {
        rect(world, 1, n - 1 - (n * 2) / 5, n - 2, (n * 2) / 5, Material::Water);
    } else if (scene == "sparse") {
        for (int by = 96; by + 40 < n; by += 128) {
            for (int bx = 32; bx + 72 < n; bx += 128) {
                rect(world, bx, by + 32, 64, 1, Material::Wall);
                rect(world, bx, by, 1, 32, Material::Wall);
                rect(world, bx + 63, by, 1, 32, Material::Wall);
                rect(world, bx + 8, by - 24, 12, 40, Material::Water);
            }
        }
    }
}

struct Checkpoint {
    std::uint64_t tick = 0;
    std::uint64_t completed_tick = 0;
    std::uint64_t state_hash = 0;
    std::uint32_t physical_hash_version = 0;
    std::uint64_t physical_hash = 0;
    std::uint64_t water_quantity = 0;
    std::size_t chunks = 0;
    std::size_t resident_cell_bytes = 0;
    QuantityLedgerSnapshot ledger{};
};

Checkpoint checkpoint(const World& world, RectI64 region, std::uint64_t expected_tick) {
    Checkpoint point;
    point.tick = world.tick_index();
    point.completed_tick = world.completed_tick_index();
    if (point.tick != expected_tick || point.completed_tick != expected_tick)
        throw std::runtime_error("world did not complete every requested tick");
    point.state_hash = world.state_hash();
    point.physical_hash_version = world.physical_state_hash_version();
    point.physical_hash = world.physical_state_hash();
    point.water_quantity = world.water_quantity(region);
    point.chunks = world.chunk_count();
    point.resident_cell_bytes = world.resident_cell_bytes();
    point.ledger = world.quantity_ledger();
    std::uint64_t produced = 0, consumed = 0;
    for (const auto& flow : point.ledger.kinds) {
        produced = checked_add(produced, flow.produced);
        consumed = checked_add(consumed, flow.consumed);
    }
    const auto accounted = checked_add(point.ledger.baseline_water, produced);
    const auto present = checked_add(checked_add(point.ledger.water_visible,
                                               point.ledger.water_overfill),
                                    point.ledger.water_ballistic);
    if (accounted < consumed || accounted - consumed != point.water_quantity ||
        present != point.water_quantity)
        throw std::runtime_error("independent Water scan disagrees with exact quantity ledger");
    return point;
}

void require_conserved(const Checkpoint& start, const Checkpoint& point) {
    // These closed Water/Wall scenes have no sources or sinks after setup.
    // Comparing booked causes prevents equal-and-opposite hidden edits from
    // passing merely because their final net quantity happens to be zero.
    const auto& a = start.ledger;
    const auto& b = point.ledger;
    if (point.water_quantity != start.water_quantity || a.schema_version != b.schema_version ||
        a.mass_bits != b.mass_bits || a.baseline_water != b.baseline_water ||
        a.kinds != b.kinds || a.pair_rules != b.pair_rules || a.pair_events != b.pair_events ||
        a.kernel_rules != b.kernel_rules || a.prepared_material_cells != b.prepared_material_cells ||
        a.construction != b.construction)
        throw std::runtime_error("closed-scene Water quantity or source/sink accounting changed");
}

std::string hash_hex(std::uint64_t value) {
    std::ostringstream out;
    out << std::hex << std::setfill('0') << std::setw(16) << value;
    return out.str();
}

std::string digest_hex(const QuantityDigest& digest) {
    constexpr char digits[] = "0123456789abcdef";
    std::string result;
    result.reserve(digest.size() * 2);
    for (const auto value : digest) {
        result.push_back(digits[value >> 4]);
        result.push_back(digits[value & 15]);
    }
    return result;
}

template <typename Values>
void write_numbers(std::ostream& out, const Values& values) {
    out << '[';
    bool comma = false;
    for (const auto value : values) {
        if (comma) out << ',';
        out << static_cast<std::uint64_t>(value);
        comma = true;
    }
    out << ']';
}

template <std::size_t N>
void write_flows(std::ostream& out, const std::array<WaterQuantityFlow, N>& flows) {
    out << '[';
    for (std::size_t i = 0; i < flows.size(); ++i) {
        if (i != 0) out << ',';
        out << "{\"produced\":" << flows[i].produced << ",\"consumed\":" << flows[i].consumed << '}';
    }
    out << ']';
}

void write_construction(std::ostream& out, const std::optional<QuantityConstructionSeed>& seed) {
    if (!seed) {
        out << "null";
        return;
    }
    out << "{\"mass_bits\":" << static_cast<unsigned>(seed->mass_bits)
        << ",\"baseline_water\":" << seed->baseline_water
        << ",\"normalization_produced\":" << seed->normalization_produced
        << ",\"normalization_consumed\":" << seed->normalization_consumed
        << ",\"expected_final_water\":" << seed->expected_final_water
        << ",\"original_setup_identity\":\"" << digest_hex(seed->original_setup_identity)
        << "\",\"prepared_setup_identity\":\"" << digest_hex(seed->prepared_setup_identity)
        << "\",\"original_payload_digest\":\"" << digest_hex(seed->original_payload_digest)
        << "\",\"prepared_payload_digest\":\"" << digest_hex(seed->prepared_payload_digest)
        << "\",\"normalization_receipt_digest\":";
    if (seed->normalization_receipt_digest) out << '"' << digest_hex(*seed->normalization_receipt_digest) << '"';
    else out << "null";
    out << '}';
}

void write_ledger(std::ostream& out, const QuantityLedgerSnapshot& ledger) {
    out << "{\"schema_version\":" << ledger.schema_version
        << ",\"mass_bits\":" << static_cast<unsigned>(ledger.mass_bits)
        << ",\"baseline_water\":" << ledger.baseline_water
        << ",\"water_visible\":" << ledger.water_visible
        << ",\"water_overfill\":" << ledger.water_overfill
        << ",\"water_ballistic\":" << ledger.water_ballistic << ",\"kinds\":";
    write_flows(out, ledger.kinds);
    out << ",\"pair_rules\":";
    write_flows(out, ledger.pair_rules);
    out << ",\"pair_events\":";
    write_numbers(out, ledger.pair_events);
    out << ",\"kernel_rules\":";
    write_flows(out, ledger.kernel_rules);
    out << ",\"material_cells\":";
    write_numbers(out, ledger.material_cells);
    out << ",\"prepared_material_cells\":";
    write_numbers(out, ledger.prepared_material_cells);
    out << ",\"construction\":";
    write_construction(out, ledger.construction);
    out << '}';
}

void write_checkpoint(std::ostream& out, const Checkpoint& point) {
    out << "{\"tick\":" << point.tick << ",\"completed_tick\":" << point.completed_tick
        << ",\"state_hash\":\"" << hash_hex(point.state_hash)
        << "\",\"physical_hash_version\":" << point.physical_hash_version
        << ",\"physical_hash\":\"" << hash_hex(point.physical_hash)
        << "\",\"water_quantity\":" << point.water_quantity
        << ",\"chunks\":" << point.chunks << ",\"resident_cell_bytes\":" << point.resident_cell_bytes
        << ",\"quantity_ledger\":";
    write_ledger(out, point.ledger);
    out << '}';
}

std::uint64_t percentile(const std::vector<std::uint64_t>& sorted, std::size_t p) {
    return sorted[(sorted.size() * p + 99U) / 100U - 1U];
}

int run(int argc, char** argv) {
    if (argc != 6)
        throw std::invalid_argument("usage: wave_default_off_pair SIZE SCENE WORKERS WARM TICKS");
    const int n = integer(argv[1]);
    const std::string scene = argv[2];
    const int workers = integer(argv[3]), warm = integer(argv[4]), ticks = integer(argv[5]);
    if (n < 128 || n > 2048 || workers < 1 || workers > 6 || warm < 0 || warm > 100000 ||
        ticks < 1 || ticks > 100000 || (scene != "dam" && scene != "sparse" && scene != "idle"))
        throw std::invalid_argument("invalid size, scene, worker count or measurement window");

    WorldConfig config;
    config.initial_chunk_reserve = 320;
    config.maximum_chunk_count = 512;
    config.active_chunk_capacity = 512;
    config.active_core_capacity = 4096;
    config.worker_threads = static_cast<std::uint32_t>(workers);
    config.parallel_job_threshold = 2;
    config.backend = SimulationBackend::PhasedInPlace;
    // Deliberately do not assign a solver or enable any experimental feature.
    auto world = std::make_unique<World>(config);
    const auto assignment = world->liquid_solver_policy().assignment(static_cast<std::uint16_t>(Material::Water));
    if (!assignment || assignment->family != LiquidSolverFamily::FreeMassV1 ||
        assignment->variant != LiquidSolverVariant::Reference)
        throw std::runtime_error("default Water is not FreeMassV1/reference");
    build_scene(*world, scene, n);
    const RectI64 region{0, 0, n, n};
    const auto start = checkpoint(*world, region, 0);
    for (int i = 0; i < warm; ++i) (void)world->tick();
    const auto warmed = checkpoint(*world, region, static_cast<std::uint64_t>(warm));
    require_conserved(start, warmed);

    std::vector<std::uint64_t> samples;
    samples.reserve(static_cast<std::size_t>(ticks));
    std::uint64_t total_ns = 0, visited = 0, moved = 0, cores = 0, blocks = 0;
    std::uint32_t observed = 0;
    for (int i = 0; i < ticks; ++i) {
        const auto before = std::chrono::steady_clock::now();
        const auto stats = world->tick();
        const auto elapsed = std::chrono::duration_cast<std::chrono::nanoseconds>(
            std::chrono::steady_clock::now() - before).count();
        if (elapsed <= 0) throw std::runtime_error("steady clock returned a nonpositive tick duration");
        const auto ns = static_cast<std::uint64_t>(elapsed);
        samples.push_back(ns);
        total_ns = checked_add(total_ns, ns);
        visited = checked_add(visited, stats.visited_cells);
        moved = checked_add(moved, stats.moved_cells);
        cores = checked_add(cores, stats.scheduled_cores);
        blocks = checked_add(blocks, stats.active_blocks_after);
        observed = std::max(observed, stats.worker_threads_observed);
    }
    const auto final = checkpoint(*world, region, static_cast<std::uint64_t>(warm + ticks));
    require_conserved(start, final);
    if (observed > static_cast<std::uint32_t>(workers) || total_ns == 0)
        throw std::runtime_error("invalid worker participation or elapsed time");
    // Queries, hashes, sorting and JSON construction stay outside every timer.
    const auto rss = peak_rss_bytes();
    auto sorted = samples;
    std::sort(sorted.begin(), sorted.end());
    std::ostringstream out;
    out.imbue(std::locale::classic());
    out << std::setprecision(17)
        << "{\"schema\":\"wave-default-off-pair-v1\",\"size\":" << n
        << ",\"scene\":\"" << scene << "\",\"workers_requested\":" << workers
        << ",\"workers_configured\":" << world->config().worker_threads
        << ",\"warm_ticks\":" << warm << ",\"measured_ticks\":" << ticks
        << ",\"water_family\":" << static_cast<unsigned>(assignment->family)
        << ",\"water_variant\":" << static_cast<unsigned>(assignment->variant)
        << ",\"policy_hash\":\"" << world->liquid_solver_policy().policy_hash_hex()
        << "\",\"workers_observed\":" << observed
        << ",\"visited_cells_total\":" << visited << ",\"moved_cells_total\":" << moved
        << ",\"scheduled_cores_total\":" << cores << ",\"active_blocks_total\":" << blocks
        << ",\"peak_rss_bytes\":" << rss
        << ",\"timing\":{\"tick_p50_ns\":" << percentile(sorted, 50)
        << ",\"tick_p95_ns\":" << percentile(sorted, 95)
        << ",\"tick_p99_ns\":" << percentile(sorted, 99)
        << ",\"tick_max_ns\":" << sorted.back()
        << ",\"tick_mean_ns\":" << static_cast<double>(total_ns) / static_cast<double>(ticks)
        << ",\"native_ticks_per_s\":" << static_cast<double>(ticks) * 1.0e9 / static_cast<double>(total_ns)
        << ",\"tick_ns\":";
    write_numbers(out, samples);
    out << "},\"checkpoints\":{\"start\":";
    write_checkpoint(out, start);
    out << ",\"warm\":";
    write_checkpoint(out, warmed);
    out << ",\"final\":";
    write_checkpoint(out, final);
    out << "},\"conserved\":true}\n";
    std::cout << out.str();
    return 0;
}

} // namespace

int main(int argc, char** argv) {
    try {
        return run(argc, argv);
    } catch (const std::exception& error) {
        std::cerr << "apparatus_error=" << error.what() << '\n';
        return 1;
    }
}
