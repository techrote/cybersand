// WAVE-WATERWALL-001 apparatus: replays an authored Workbench start (exact
// generated terrain bytes plus Water rectangle stamps) or a synthetic scene on
// the real native World and reports Water quantities, timings and PPM frames.
// Usage: wave_waterwall SCENE [key=value ...]
//   SCENE  map | reservoir | falls | basin | sealed | film | narrow | sparse
//   keys   terrain=FILE stamps=FILE ticks=N every=N frames=PREFIX crop=x,y,w,h
//          probeK=x,y,w,h dump=x,y,w,h workers=N substeps=N size=N wave=0|1
//          and Wave tuning member names (see make_world).
#include "cybersand/world.hpp"

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <map>
#include <memory>
#include <span>
#include <stdexcept>
#include <string>
#include <vector>

using namespace cybersand;

namespace {

std::map<std::string, std::string> g_args;
std::string arg(const std::string& key, const std::string& fallback) {
    const auto found = g_args.find(key);
    return found == g_args.end() ? fallback : found->second;
}
int number(const std::string& key, int fallback) {
    const auto found = g_args.find(key);
    return found == g_args.end() ? fallback : std::stoi(found->second);
}

std::unique_ptr<World> make_world(int size) {
    WorldConfig cfg;
    const auto chunks = static_cast<std::size_t>((size + cfg.chunk_size - 1) / cfg.chunk_size + 2);
    cfg.maximum_chunk_count = std::max<std::size_t>(128, chunks * chunks);
    cfg.active_chunk_capacity = cfg.maximum_chunk_count;
    cfg.initial_chunk_reserve = cfg.maximum_chunk_count;
    cfg.worker_threads = static_cast<std::uint32_t>(number("workers", 1));
    cfg.parallel_job_threshold = 2;
    cfg.wave_flow.enabled = number("wave", 1) != 0;
    cfg.wave_flow.substeps = static_cast<std::uint8_t>(number("substeps", 1));
    auto& t = cfg.wave_flow;
    t.active_rows = number("active_rows", t.active_rows);
    t.gain = number("gain", t.gain);
    t.gain_confined = number("gain_confined", t.gain_confined);
    t.stiffness = number("stiffness", t.stiffness);
    t.damp_shift = number("damp_shift", t.damp_shift);
    t.coast = number("coast", t.coast);
    t.level_shift = number("level_shift", t.level_shift);
    t.empty_pour_shift = number("empty_pour_shift", t.empty_pour_shift);
    t.flow_share_shift = number("flow_share_shift", t.flow_share_shift);
    t.adhesion_shift = number("adhesion_shift", t.adhesion_shift);
    t.spill.enabled = number("spill", 0) != 0;
    t.spill.fall = number("fall", t.spill.fall);
    t.spill.share_shift = number("share_shift", t.spill.share_shift);
    t.spill.draw = number("draw", t.spill.draw);
    t.spill.draw_head = number("draw_head", t.spill.draw_head);
    t.spill.stream = number("stream", t.spill.stream);
    t.spill.launch_min = number("launch_min", t.spill.launch_min);
    t.spill.launch_budget = number("launch_budget", t.spill.launch_budget);
    t.spill.launch_speed = number("launch_speed", t.spill.launch_speed);
    t.spill.stream_share = number("stream_share", t.spill.stream_share);
    t.spill.catch_falling = number("catch", t.spill.catch_falling);
    cfg.ballistic_water.enabled = number("ballistic", 0) != 0;
    cfg.ballistic_water.capacity = static_cast<std::uint32_t>(number("capacity", static_cast<int>(cfg.ballistic_water.capacity)));
    auto request = LiquidSolverPolicy::default_request();
    request[21] = 1;
    request[22] = 0;
    const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(request));
    if (!decoded.accepted()) throw std::runtime_error("policy refused: " + decoded.refusal.message());
    cfg.liquid_solver_policy = *decoded.policy;
    return std::make_unique<World>(cfg);
}

void rect(World& w, int x, int y, int width, int height, Material material) {
    for (int yy = y; yy < y + height; ++yy)
        for (int xx = x; xx < x + width; ++xx) w.set(xx, yy, material);
}
void frame_walls(World& w, int size) {
    rect(w, -1, -1, size + 2, 1, Material::Wall);
    rect(w, -1, size, size + 2, 1, Material::Wall);
    rect(w, -1, -1, 1, size + 2, Material::Wall);
    rect(w, size, -1, 1, size + 2, Material::Wall);
}

struct Box { int x, y, w, h; };
std::vector<std::pair<std::string, Box>> g_probes;

void write_frame(const World& w, Box crop, const std::string& prefix, int tick) {
    char path[1024];
    std::snprintf(path, sizeof(path), "%s-t%06d.ppm", prefix.c_str(), tick);
    std::ofstream out(path, std::ios::binary);
    out << "P6\n" << crop.w << ' ' << crop.h << "\n255\n";
    std::vector<unsigned char> row(static_cast<std::size_t>(crop.w) * 3U);
    for (int y = crop.y; y < crop.y + crop.h; ++y) {
        for (int x = crop.x; x < crop.x + crop.w; ++x) {
            const auto material = w.get(x, y);
            unsigned char r = 10, g = 12, b = 20;
            if (material == Material::Water) {
                const auto mass = std::min<int>(255, w.liquid_mass(x, y));
                r = static_cast<unsigned char>(10 + mass / 10);
                g = static_cast<unsigned char>(40 + mass / 3);
                b = static_cast<unsigned char>(100 + mass * 155 / 255);
            } else if (material != Material::Empty) { r = 120; g = 112; b = 96; }
            const auto at = static_cast<std::size_t>(x - crop.x) * 3U;
            row[at] = r; row[at + 1U] = g; row[at + 2U] = b;
        }
        out.write(reinterpret_cast<const char*>(row.data()), static_cast<std::streamsize>(row.size()));
    }
    // Ballistic parcels are drawn over Empty cells, as the renderer overlays them.
    std::vector<BallisticParcel> parcels(w.ballistic_parcel_count());
    (void)w.copy_ballistic_parcels(parcels);
    for (const auto& p : parcels) {
        const auto x = static_cast<int>(p.x >> 8) - crop.x, y = static_cast<int>(p.y >> 8) - crop.y;
        if (x < 0 || y < 0 || x >= crop.w || y >= crop.h) continue;
        const auto mass = std::min<int>(255, static_cast<int>(p.quantity));
        const unsigned char pixel[3] = {static_cast<unsigned char>(10 + mass / 10), static_cast<unsigned char>(40 + mass / 3),
                                        static_cast<unsigned char>(100 + mass * 155 / 255)};
        out.seekp(static_cast<std::streamoff>(out.tellp()) - static_cast<std::streamoff>(crop.w) * 3 * (crop.h - y) + x * 3);
        out.write(reinterpret_cast<const char*>(pixel), 3);
        out.seekp(0, std::ios::end);
    }
}

Box parse_box(const std::string& text) {
    Box b{};
    if (std::sscanf(text.c_str(), "%d,%d,%d,%d", &b.x, &b.y, &b.w, &b.h) != 4) throw std::invalid_argument("box: " + text);
    return b;
}

int build(World& w, const std::string& scene, int size) {
    if (scene == "map") {
        std::ifstream terrain(arg("terrain", ""), std::ios::binary);
        std::vector<unsigned char> cells(static_cast<std::size_t>(size) * static_cast<std::size_t>(size));
        terrain.read(reinterpret_cast<char*>(cells.data()), static_cast<std::streamsize>(cells.size()));
        if (terrain.gcount() != static_cast<std::streamsize>(cells.size())) throw std::runtime_error("terrain size");
        for (int y = 0; y < size; ++y)
            for (int x = 0; x < size; ++x) {
                const auto id = cells[static_cast<std::size_t>(y) * static_cast<std::size_t>(size) + static_cast<std::size_t>(x)];
                if (id != 0) w.set(x, y, static_cast<Material>(id));
            }
        std::ifstream stamps(arg("stamps", ""));
        int x, y, sw, sh, material, count = 0;
        while (stamps >> x >> y >> sw >> sh >> material) {
            rect(w, x, y, sw, sh, static_cast<Material>(material));
            ++count;
        }
        frame_walls(w, size);
        return count;
    }
    frame_walls(w, size);
    const int floor = size - 1;
    if (scene == "reservoir") {
        // Tall open-sided block of Water standing on the floor.
        rect(w, 0, floor - 160, 200, 160, Material::Water);
        g_probes = {{"source", {0, 0, 200, size}}, {"outside", {200, 0, size - 200, size}}};
    } else if (scene == "falls") {
        // Platform-edge waterfall into a receiving basin.
        rect(w, 0, 200, 220, 4, Material::Wall);
        rect(w, 0, 140, 220, 60, Material::Water);
        rect(w, 380, floor - 60, 4, 60, Material::Wall);
        g_probes = {{"platform", {0, 0, 220, 200}}, {"air", {220, 0, size - 220, floor - 60}}, {"basin", {0, floor - 60, 380, 61}},
                    {"beyond", {384, floor - 60, size - 384, 61}}};
    } else if (scene == "basin") {
        // Contained pool with a raised bump: waves, then rest.
        rect(w, 0, floor - 64, size, 64, Material::Water);
        rect(w, size / 4 - 12, floor - 70, 24, 6, Material::Water);
        g_probes = {{"mid", {size / 2 - 1, 0, 3, size}}, {"left", {0, 0, size / 2, size}}};
    } else if (scene == "sealed") {
        // Sealed reservoir: nothing can leave.
        rect(w, 100, 100, 200, 4, Material::Wall); rect(w, 100, 200, 200, 4, Material::Wall);
        rect(w, 100, 100, 4, 104, Material::Wall); rect(w, 296, 100, 4, 104, Material::Wall);
        rect(w, 104, 104, 192, 96, Material::Water);
        g_probes = {{"inside", {104, 104, 192, 96}}};
    } else if (scene == "film") {
        // Thin supported sheet on a long ledge with open ends.
        rect(w, 100, 200, 300, 4, Material::Wall);
        rect(w, 150, 198, 200, 2, Material::Water);
        g_probes = {{"ledge", {100, 0, 300, 200}}};
    } else if (scene == "narrow") {
        // Reservoir draining through a 3-cell-high slot in its side wall.
        rect(w, 200, floor - 160, 4, 160, Material::Wall);
        rect(w, 200, floor - 3, 4, 3, Material::Empty);
        rect(w, 0, floor - 150, 200, 150, Material::Water);
        g_probes = {{"source", {0, 0, 200, size}}, {"outside", {204, 0, size - 204, size}}};
    } else if (scene == "sparse") {
        // Several separated raised reservoirs over a large canvas.
        for (int k = 0; k * 400 + 300 < size; ++k)
            for (int j = 0; j * 400 + 300 < size; ++j) {
                const int ox = k * 400 + 40, oy = j * 400 + 120;
                rect(w, ox, oy + 80, 180, 4, Material::Wall);
                rect(w, ox, oy, 4, 80, Material::Wall);
                rect(w, ox + 4, oy + 20, 176, 60, Material::Water);
            }
    } else throw std::invalid_argument("unknown scene");
    return 0;
}

}  // namespace

int main(int argc, char** argv) {
    try {
        const std::string scene = argc > 1 ? argv[1] : "";
        for (int i = 2; i < argc; ++i) {
            const std::string text = argv[i];
            const auto eq = text.find('=');
            if (eq == std::string::npos) throw std::invalid_argument("expected key=value: " + text);
            g_args[text.substr(0, eq)] = text.substr(eq + 1);
        }
        const int size = number("size", scene == "map" ? 1024 : 512);
        const int ticks = number("ticks", 2000), every = number("every", 250);
        auto world = make_world(size);
        auto& w = *world;
        const int stamps = build(w, scene, size);
        for (int k = 0;; ++k) {
            const auto key = "probe" + std::to_string(k);
            if (!g_args.count(key)) break;
            g_probes.push_back({key, parse_box(g_args[key])});
        }
        const Box all{-1, -1, size + 2, size + 2};
        const Box crop = g_args.count("crop") ? parse_box(g_args["crop"]) : Box{0, 0, size, size};
        const auto frames = arg("frames", "");
        const auto before = w.water_quantity({all.x, all.y, all.w, all.h});
        std::printf("scene=%s size=%d stamps=%d workers=%d substeps=%d water_units=%llu\n", scene.c_str(), size, stamps,
                    number("workers", 1), number("substeps", 1), static_cast<unsigned long long>(before));
        std::printf("tick,total_drift,moved_units");
        for (const auto& probe : g_probes) std::printf(",%s", probe.first.c_str());
        std::printf(",solved_chunks,window_median_us,window_p95_us\n");
        std::vector<double> window, overall;
        for (int t = 0; t <= ticks; ++t) {
            if (t % every == 0) {
                const auto now = w.water_quantity({all.x, all.y, all.w, all.h}) + w.ballistic_water_snapshot().in_flight_quantity;
                const auto diag = w.wave_flow_diagnostics();
                std::printf("%d,%lld,%llu", t, static_cast<long long>(now) - static_cast<long long>(before),
                            static_cast<unsigned long long>(diag.moved_units));
                for (const auto& probe : g_probes)
                    std::printf(",%.1f", static_cast<double>(w.water_quantity({probe.second.x, probe.second.y, probe.second.w, probe.second.h})) / 255.0);
                std::sort(window.begin(), window.end());
                std::printf(",%u,%.0f,%.0f\n", diag.last_solved_chunks, window.empty() ? 0.0 : window[window.size() / 2],
                            window.empty() ? 0.0 : window[std::min(window.size() - 1, window.size() * 95 / 100)]);
                std::fflush(stdout);
                window.clear();
                if (!frames.empty()) write_frame(w, crop, frames, t);
            }
            if (t == ticks) break;
            const auto from = std::chrono::steady_clock::now();
            (void)w.tick();
            const auto us = std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now() - from).count();
            window.push_back(us);
            overall.push_back(us);
        }
        std::sort(overall.begin(), overall.end());
        const auto diag = w.wave_flow_diagnostics();
        const auto flight = w.ballistic_water_snapshot();
        std::printf("launched_parcels=%llu launched_units=%llu launch_refusals=%llu launch_deferrals=%llu launch_ns_per_tick=%.0f "
                    "live=%u max_live=%llu deposited_units=%llu deferred_deposits=%llu forced=%llu advance_last_ns=%llu\n",
                    static_cast<unsigned long long>(diag.launched_parcels), static_cast<unsigned long long>(diag.launched_units),
                    static_cast<unsigned long long>(diag.launch_refusals), static_cast<unsigned long long>(diag.launch_deferrals),
                    static_cast<double>(diag.launch_nanoseconds) / std::max<double>(1.0, static_cast<double>(diag.ticks)),
                    flight.live, static_cast<unsigned long long>(flight.ledger.maximum_live),
                    static_cast<unsigned long long>(flight.ledger.deposited_quantity),
                    static_cast<unsigned long long>(flight.ledger.deferred_deposits),
                    static_cast<unsigned long long>(flight.ledger.forced_deposits),
                    static_cast<unsigned long long>(flight.last_advance_nanoseconds));
        std::printf("overall_median_us=%.0f p95_us=%.0f max_us=%.0f storage_bytes=%llu capacity_refusals=%llu hash=%016llx\n",
                    overall.empty() ? 0.0 : overall[overall.size() / 2], overall.empty() ? 0.0 : overall[overall.size() * 95 / 100],
                    overall.empty() ? 0.0 : overall.back(),
                    static_cast<unsigned long long>(diag.storage_bytes), static_cast<unsigned long long>(diag.capacity_refusals),
                    static_cast<unsigned long long>(w.state_hash()));
        const auto dump = arg("dump", "");
        if (!dump.empty()) {
            const Box d = parse_box(dump);
            for (int y = d.y; y < d.y + d.h; ++y) {
                std::printf("%4d|", y);
                for (int x = d.x; x < d.x + d.w; ++x) {
                    const auto m = w.get(x, y);
                    if (m == Material::Water) std::printf("%4d", static_cast<int>(w.liquid_mass(x, y)));
                    else std::printf("%4s", m == Material::Empty ? "." : "#");
                }
                std::printf("\n");
            }
            if (number("dumpflux", 0) != 0)
                for (int y = d.y; y < d.y + d.h; ++y) {
                    std::printf("%4d>", y);
                    for (int x = d.x; x < d.x + d.w; ++x) std::printf("%4d", w.wave_flow_flux(x, y) / 4096);
                    std::printf("\n");
                }
        }
        return 0;
    } catch (const std::exception& e) {
        std::fprintf(stderr, "apparatus_error=%s\n", e.what());
        return 1;
    }
}
