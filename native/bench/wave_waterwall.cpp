// WAVE-WATERWALL-001 apparatus: replays an authored Workbench start (exact
// generated terrain bytes plus Water rectangle stamps) or a synthetic scene on
// the real native World and reports Water quantities, timings and PPM frames.
// Usage: wave_waterwall SCENE [key=value ...]
//   SCENE  map | reservoir | falls | basin | sealed | film | narrow | sparse | tank | tank_open | blob
//   keys   terrain=FILE stamps=FILE ticks=N every=N frames=PREFIX crop=x,y,w,h
//          probeK=x,y,w,h dump=x,y,w,h workers=N substeps=N size=N wave=0|1
//          and Wave tuning member names (see make_world).
#include "cybersand/world.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <numbers>
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
    t.deep_gain = number("deep_gain", t.deep_gain);
    t.flux_smoothing = number("flux_smoothing", t.flux_smoothing);
    t.calm = number("calm", t.calm);
    t.calm_damp_shift = number("calm_damp_shift", t.calm_damp_shift);
    t.stick = number("stick", t.stick);
    t.rest_head = number("rest_head", t.rest_head);
    t.sleep_after = number("sleep_after", t.sleep_after);
    t.wake_peak = number("wake_peak", t.wake_peak);
    t.maximum_mass = number("maximum_mass", t.maximum_mass);
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
    t.spill.stream_draw = number("stream_draw", t.spill.stream_draw);
    t.spill.sheet_rate = number("sheet_rate", t.spill.sheet_rate);
    t.spill.coyote_ticks = number("coyote_ticks", t.spill.coyote_ticks);
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

// Outside the timed tick. Count every owned unit in the source box, including
// parcels still inside it. In the fall window a row is wet if it contains
// at least one grid unit. Report separately the rows touched only by parcels.
struct DischargeTrace {
    std::ofstream out;
    Box source{}, stream{};
    std::vector<BallisticParcel> parcels;
    std::vector<bool> airborne;
    std::int64_t previous{};

    void open(const World& w) {
        if (!g_args.count("hydrograph")) return;
        source = parse_box(g_args.at("source_box"));
        stream = parse_box(g_args.at("stream_box"));
        if (source.w <= 0 || source.h <= 0 || stream.w <= 0 || stream.h <= 0)
            throw std::invalid_argument("empty discharge probe");
        out.open(g_args.at("hydrograph"));
        if (!out) throw std::runtime_error("cannot open hydrograph");
        airborne.resize(static_cast<std::size_t>(stream.h));
        parcels.resize(w.ballistic_water_snapshot().capacity);
        out << "tick,source_grid_units,source_flight_units,net_out_units,grid_dry_rows,air_only_rows,max_grid_gap\n";
    }

    void sample(const World& w, int tick) {
        if (!out.is_open()) return;
        const auto stored = static_cast<std::int64_t>(w.water_quantity({source.x, source.y, source.w, source.h}));
        std::int64_t flight = 0;
        std::fill(airborne.begin(), airborne.end(), false);
        const auto count = w.copy_ballistic_parcels(parcels);
        for (std::size_t i = 0; i < count; ++i) {
            const auto& p = parcels[i];
            const auto x = p.x >> 8, y = p.y >> 8;
            if (x >= source.x && x < source.x + source.w && y >= source.y && y < source.y + source.h)
                flight += p.quantity;
            if (x >= stream.x && x < stream.x + stream.w && y >= stream.y && y < stream.y + stream.h)
                airborne[static_cast<std::size_t>(y - stream.y)] = true;
        }
        int dry = 0, air_only = 0, gap = 0, max_gap = 0;
        for (int row = 0; row < stream.h; ++row) {
            bool wet = false;
            for (int x = stream.x; x < stream.x + stream.w && !wet; ++x)
                wet = w.get(x, stream.y + row) == Material::Water;
            if (wet) { gap = 0; continue; }
            ++dry;
            if (airborne[static_cast<std::size_t>(row)]) ++air_only;
            max_gap = std::max(max_gap, ++gap);
        }
        const auto total = stored + flight;
        out << tick << ',' << stored << ',' << flight << ',' << (tick ? previous - total : 0)
            << ',' << dry << ',' << air_only << ',' << max_gap << '\n';
        previous = total;
    }
};

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
    } else if (scene == "tank" || scene == "tank_open" || scene == "blob") {
        if (size < 128) throw std::invalid_argument("tank/blob fixtures require size >= 128");
        if (scene == "blob") {
            rect(w, 0, 56, size, 1, Material::Wall);
            rect(w, 58, 46, 12, 6, Material::Water);
        } else {
            rect(w, 16, 16, 1, 41, Material::Wall);
            const int lip = scene == "tank_open" ? 44 : 16;
            rect(w, 81, lip, 1, 57 - lip, Material::Wall);
            rect(w, 16, 56, 66, 1, Material::Wall);
            rect(w, 16, 80, 98, 1, Material::Wall);
            rect(w, 113, 56, 1, 25, Material::Wall);
            rect(w, 17, 45, 64, 11, Material::Water);
            rect(w, 17, 39, 32, 6, Material::Water);
        }
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

// The signed first cosine mode measures the long wave independently of
// shorter ripples. Equivalent cell depth includes fractional surface cells.
void sample_profile(const World& w, bool blob, int width) {
    const int first = blob ? 0 : 17;
    const int count = blob ? width : 64;
    double previous2 = 0, previous1 = 0, curvature2 = 0, first_mode = 0;
    int left = -1, right = -1;
    for (int k = 0; k < count; ++k) {
        const int x = first + k;
        const auto units = w.water_quantity({x, 0, 1, 56});
        const double h = static_cast<double>(units) / 255.0;
        if (units >= 32) { if (left < 0) left = x; right = x; }
        first_mode += h * std::cos(std::numbers::pi * (k + 0.5) / count);
        if (k >= 2) {
            const double curvature = h - 2 * previous1 + previous2;
            curvature2 += curvature * curvature;
        }
        previous2 = previous1;
        previous1 = h;
    }
    std::printf(",%.7f,%.7f,%d,%d", first_mode * 2 / count, std::sqrt(curvature2 / (count - 2)), left, right);
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
        const bool profile = scene == "tank" || scene == "tank_open" || scene == "blob";
        if (profile) std::printf(",long_mode_cells,curvature_rms_cells,front_left_32,front_right_32");
        std::printf(",solved_chunks,window_median_us,window_p95_us\n");
        DischargeTrace discharge;
        discharge.open(w);
        std::vector<double> window, overall;
        for (int t = 0; t <= ticks; ++t) {
            discharge.sample(w, t);
            if (t % every == 0) {
                const auto now = w.water_quantity({all.x, all.y, all.w, all.h}) + w.ballistic_water_snapshot().in_flight_quantity;
                const auto diag = w.wave_flow_diagnostics();
                std::printf("%d,%lld,%llu", t, static_cast<long long>(now) - static_cast<long long>(before),
                            static_cast<unsigned long long>(diag.moved_units));
                for (const auto& probe : g_probes)
                    std::printf(",%.1f", static_cast<double>(w.water_quantity({probe.second.x, probe.second.y, probe.second.w, probe.second.h})) / 255.0);
                if (profile) sample_profile(w, scene == "blob", size);
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
                    "launch_capacity_skips=%llu live=%u max_live=%llu deposited_units=%llu deferred_deposits=%llu forced=%llu advance_last_ns=%llu\n",
                    static_cast<unsigned long long>(diag.launched_parcels), static_cast<unsigned long long>(diag.launched_units),
                    static_cast<unsigned long long>(diag.launch_refusals), static_cast<unsigned long long>(diag.launch_deferrals),
                    static_cast<double>(diag.launch_nanoseconds) / std::max<double>(1.0, static_cast<double>(diag.ticks)),
                    static_cast<unsigned long long>(diag.launch_capacity_skips), flight.live, static_cast<unsigned long long>(flight.ledger.maximum_live),
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
