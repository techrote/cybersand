// WAVE-WATERWALL-001 apparatus: replays an authored Workbench start (exact
// generated terrain bytes plus Water rectangle stamps) or a synthetic scene on
// the real native World and reports Water quantities, timings and PPM frames.
// Usage: wave_waterwall SCENE [key=value ...]
//   SCENE  map | ramp | flat_surge | drop_surge | uphill_surge | reservoir | falls | basin | sealed | film | narrow | sparse | tank | tank_open | blob
//   keys   terrain=FILE stamps=FILE ticks=N every=N frames=PREFIX crop=x,y,w,h
//          probeK=x,y,w,h dump=x,y,w,h workers=N substeps=N size=N wave=0|1
//          and Wave tuning member names (see make_world).
#include "cybersand/world.hpp"

#include <algorithm>
#include <array>
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
    t.floor_gain = number("floor_gain", t.floor_gain);
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
    t.spill.deep_draw = number("deep_draw", t.spill.deep_draw);
    t.spill.draw_head = number("draw_head", t.spill.draw_head);
    t.spill.stream = number("stream", t.spill.stream);
    t.spill.launch_min = number("launch_min", t.spill.launch_min);
    t.spill.launch_budget = number("launch_budget", t.spill.launch_budget);
    t.spill.launch_speed = number("launch_speed", t.spill.launch_speed);
    t.spill.stream_share = number("stream_share", t.spill.stream_share);
    t.spill.catch_falling = number("catch", t.spill.catch_falling);
    t.spill.stream_draw = number("stream_draw", t.spill.stream_draw);
    t.spill.sheet_rate = number("sheet_rate", t.spill.sheet_rate);
    t.spill.full_face = number("full_face", t.spill.full_face);
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

// Both initially suspended Water bodies on the supplied ramp end before x740.
// Small isolated splashes and single-cell films must not count as bulk arrival.
// Sample only outside the timer and count the parcels separately.
struct RampTrace {
    static constexpr int first = 140, end = 1009;
    std::vector<int> floor;
    std::vector<BallisticParcel> parcels;
    bool shape = false;
    bool bank = false;
    static constexpr int bank_x = 960, bank_y = 288, bank_width = 96, bank_height = 218;
    std::vector<std::uint8_t> visited;
    std::vector<int> queue;
    std::ofstream fin_trace;

    void prepare(const World& w) {
        if (g_args.contains("fin_trace")) {
            fin_trace.open(g_args.at("fin_trace"));
            if (!fin_trace) throw std::runtime_error("cannot open ramp fin trace");
            fin_trace << "tick,x,bed_y,top_bulk_y,top_stored_y,column_units,right_units,slot_rows\n";
        }
        shape = number("ramp_shape", 0) != 0;
        bank = number("ramp_bank", 0) != 0;
        if (bank) {
            visited.resize(bank_width * bank_height);
            queue.reserve(visited.size());
        }
        for (int x = first; x < end; ++x) {
            int y = 0;
            while (y < 512 && w.stored_material(x, y) != Material::Wall) ++y;
            if (y == 512) throw std::invalid_argument("missing ramp floor");
            floor.push_back(y);
        }
        parcels.resize(w.ballistic_water_snapshot().capacity);
    }
    // Each right-side inventory includes both grid and airborne Water. Its
    // change between samples is the net transport through this column's right
    // edge. Verify that the scan captured the complete grid at every sample.
    void sample_fins(const World& w, int tick, std::uint64_t initial) {
        if (!fin_trace.is_open()) return;
        constexpr int width = 1120, height = 560;
        std::array<std::uint64_t, width> landed{}, airborne{};
        std::array<int, end - first> bulk{}, top{}, slot{};
        std::array<std::array<std::uint16_t, height>, 7> nearby{};
        const auto count = w.copy_ballistic_parcels(parcels);
        std::uint64_t left = 0, total = 0;
        for (std::size_t i = 0; i < count; ++i) {
            const auto x = parcels[i].x >> 8;
            if (x < 0) left += parcels[i].quantity;
            else if (x < width) airborne[static_cast<std::size_t>(x)] += parcels[i].quantity;
            total += parcels[i].quantity;
        }
        for (int x = 0; x < width; ++x) {
            const bool probe = x >= first && x < end;
            int bed = probe ? floor[static_cast<std::size_t>(x - first)] : 0;
            int attached_top = bed, stored_top = bed;
            for (int y = height - 1; y >= 0; --y) {
                const auto q = w.liquid_mass(x, y);
                nearby[x % 7][y] = q;
                landed[static_cast<std::size_t>(x)] += q;
                if (y >= bed || q < 64) continue;
                stored_top = y;
                if (attached_top == y + 1) attached_top = y;
            }
            total += landed[static_cast<std::size_t>(x)];
            if (probe) {
                bulk[static_cast<std::size_t>(x - first)] = attached_top;
                top[static_cast<std::size_t>(x - first)] = stored_top;
            }
            // A thin, nearly empty submerged column can make the sharp edge
            // of a crest look black. Count its longest continuous run only
            // when both sides have dense, stored Water within three cells.
            const int middle = x - 3;
            if (middle >= first && middle < end) {
                const auto m = static_cast<std::size_t>(middle - first);
                int run = 0;
                for (int y = 0; y < floor[m]; ++y) {
                    const bool left_dense = std::max({nearby[(x-6)%7][y], nearby[(x-5)%7][y], nearby[(x-4)%7][y]}) >= 192;
                    const bool right_dense = std::max({nearby[(x-2)%7][y], nearby[(x-1)%7][y], nearby[x%7][y]}) >= 192;
                    run = nearby[middle%7][y] <= 32 && left_dense && right_dense ? run + 1 : 0;
                    slot[m] = std::max(slot[m], run);
                }
            }
        }
        if (total != initial) throw std::runtime_error("ramp fin window missed Water");
        for (int x = 0; x < end; ++x) {
            const auto i = static_cast<std::size_t>(x);
            left += landed[i] + airborne[i];
            if (x < first) continue;
            const auto column = static_cast<std::size_t>(x - first);
            fin_trace << tick << ',' << x << ',' << floor[column] << ',' << bulk[column] << ','
                      << top[column] << ',' << landed[i] << ',' << initial - left << ',' << slot[column] << '\n';
        }
    }
    void header() const {
        std::printf(",floor_front_2x8,floor_film_front,floor_units_400_599,floor_units_850_1008,"
                    "floor_units_900_1008,floor_units_960_1008,parcel_front,parcel_units_900_1008");
        if (shape) std::printf(",left_peak5_depth,left_curvature_rms,left_top_grid_y,"
                               "right_peak5_depth,right_curvature_rms,right_top_grid_y");
        if (bank) std::printf(",bank_connected_units,bank_rise16_units,bank_rise32_units,bank_peak_rise,"
                              "interior_surface_y,bank_excess5,bank_excess8_units,bank_excess16_units");
    }
    // A row qualifies as visible at 1/4 cell. Floor-attached depth excludes
    // detached drops; the independent top-grid probe includes them. Peak
    // depth averages five adjacent columns so a single thin jet cannot set it.
    void sample_shape(const World& w, int x0, int x1) const {
        int window[5]{}, sum = 0, peak = 0, previous = 0, previous2 = 0, top = 512;
        double curvature2 = 0;
        for (int x = x0; x <= x1; ++x) {
            const int base = floor[static_cast<std::size_t>(x - first)];
            int depth = 0;
            for (int y = base - 1; y >= 0 && w.stored_material(x, y) == Material::Water; --y)
                if (w.liquid_mass(x, y) >= 64) depth = base - y;
            for (int y = 0; y < std::min(base, top); ++y) {
                if (w.stored_material(x, y) == Material::Water && w.liquid_mass(x, y) >= 64) { top = y; break; }
            }
            const int i = x - x0;
            sum += depth - window[i % 5];
            window[i % 5] = depth;
            if (i >= 4) peak = std::max(sum, peak);
            if (i >= 2) { const double d = depth - 2 * previous + previous2; curvature2 += d * d; }
            previous2 = previous;
            previous = depth;
        }
        std::printf(",%.1f,%.3f,%d", static_cast<double>(peak) / 5,
                    std::sqrt(curvature2 / (x1 - x0 - 1)), top == 512 ? -1 : top);
    }
    void sample_bank(const World& w) {
        // The right retaining wall curves back over the basin. Its top in a
        // column need not be the basin floor. Flood Water from the known
        // trough floor at x960..1008, through a bounded four-connected window.
        // Only its far end (x >= 992) contributes to bank height or inventory.
        std::fill(visited.begin(), visited.end(), std::uint8_t{0});
        queue.clear();
        const auto enqueue = [&](int x, int y) {
            if (x < bank_x || x >= bank_x + bank_width || y < bank_y || y >= bank_y + bank_height) return;
            const int at = (y - bank_y) * bank_width + x - bank_x;
            if (visited[static_cast<std::size_t>(at)] != 0U) return;
            visited[static_cast<std::size_t>(at)] = 1;
            if (w.stored_material(x, y) == Material::Water) queue.push_back(at);
        };
        for (int x = bank_x; x < end; ++x) enqueue(x, floor[static_cast<std::size_t>(x - first)] - 1);
        std::uint64_t connected = 0, high16 = 0, high32 = 0;
        std::array<std::uint64_t, bank_height> mass_per_row{};
        std::array<int, bank_width> top;
        top.fill(485);
        int peak = 0;
        for (std::size_t i = 0; i < queue.size(); ++i) {
            const int x = bank_x + queue[i] % bank_width, y = bank_y + queue[i] / bank_width;
            const auto mass = w.liquid_mass(x, y);
            auto& surface = top[static_cast<std::size_t>(x - bank_x)];
            if (mass >= 64) surface = std::min(surface, y);
            if (x >= 992) {
                const int rise = 485 - y; // surface of the basin floor at x1008
                connected += mass;
                mass_per_row[static_cast<std::size_t>(y - bank_y)] += mass;
                if (rise >= 16) high16 += mass;
                if (rise >= 32) high32 += mass;
                if (mass >= 64) peak = std::max(peak, rise);
            }
            enqueue(x - 1, y); enqueue(x + 1, y); enqueue(x, y - 1); enqueue(x, y + 1);
        }
        std::printf(",%llu,%llu,%llu,%d", static_cast<unsigned long long>(connected),
                    static_cast<unsigned long long>(high16), static_cast<unsigned long long>(high32), peak);
        // Faster delivery raises the entire pool. Subtract its contemporaneous
        // free surface before describing local wall run-up. Use the median of
        // the interior x968..983 and a five-column peak at x992 and beyond.
        std::array<int, 16> interior;
        std::copy_n(top.begin() + (968 - bank_x), interior.size(), interior.begin());
        std::sort(interior.begin(), interior.end());
        const int reference = interior[8];
        if (reference >= 485 || connected == 0U) { std::printf(",-1,-1,0,0"); return; }
        int peak_sum = 5 * reference;
        for (int x = 992; x + 4 < bank_x + bank_width; ++x) {
            int sum = 0;
            for (int k = 0; k < 5; ++k) sum += top[static_cast<std::size_t>(x - bank_x + k)];
            peak_sum = std::min(peak_sum, sum);
        }
        std::uint64_t excess8 = 0, excess16 = 0;
        for (int y = bank_y; y <= reference - 8; ++y) {
            const auto units = mass_per_row[static_cast<std::size_t>(y - bank_y)];
            excess8 += units;
            if (y <= reference - 16) excess16 += units;
        }
        std::printf(",%d,%.1f,%llu,%llu", reference, reference - peak_sum / 5.0,
                    static_cast<unsigned long long>(excess8), static_cast<unsigned long long>(excess16));
    }
    void sample(const World& w) {
        int bulk = -1, film = -1, consecutive = 0;
        std::uint64_t slope = 0, at850 = 0, at900 = 0, at960 = 0;
        for (int x = first; x < end; ++x) {
            std::uint64_t units = 0;
            for (int y = floor[static_cast<std::size_t>(x - first)] - 1;
                 y >= 0 && w.stored_material(x, y) == Material::Water; --y) units += w.liquid_mass(x, y);
            if (x >= 400 && x < 600) slope += units;
            if (x < 740) continue;
            if (units != 0) film = x;
            consecutive = units >= 510 ? consecutive + 1 : 0;
            if (consecutive >= 8) bulk = x;
            if (x >= 850) at850 += units;
            if (x >= 900) at900 += units;
            if (x >= 960) at960 += units;
        }
        int parcel_front = -1;
        std::uint64_t airborne = 0;
        const auto count = w.copy_ballistic_parcels(parcels);
        for (std::size_t i = 0; i < count; ++i) {
            const auto x = parcels[i].x >> 8, y = parcels[i].y >> 8;
            if (x < 740 || x >= end || y < 0 || y >= floor[static_cast<std::size_t>(x - first)]) continue;
            parcel_front = std::max(parcel_front, static_cast<int>(x));
            if (x >= 900) airborne += parcels[i].quantity;
        }
        std::printf(",%d,%d,%llu,%llu,%llu,%llu,%d,%llu", bulk, film,
                    static_cast<unsigned long long>(slope), static_cast<unsigned long long>(at850),
                    static_cast<unsigned long long>(at900), static_cast<unsigned long long>(at960),
                    parcel_front, static_cast<unsigned long long>(airborne));
        if (shape) { sample_shape(w, 140, 350); sample_shape(w, 630, 740); }
        if (bank) sample_bank(w);
    }
};

bool is_surge(const std::string& scene) {
    return scene == "flat_surge" || scene == "uphill_surge" || scene == "drop_surge";
}
int surge_floor(int x, bool uphill) {
    // Sixteen dry columns beyond the initial block, then one riser every two
    // columns. The plateau is 16 cells above the initial free surface.
    return 160 - (uphill ? std::clamp((x - 286) / 2, 0, 48) : 0);
}

void sample_surge(const World& w, bool uphill) {
    int run = 0, left = 240, right = 271, left_film = 240, right_film = 271;
    std::uint64_t grounded = 0, beyond_left = 0, beyond_right = 0, high8 = 0, high16 = 0, high32 = 0;
    std::uint64_t travel = 0;
    for (int x = 0; x < 512; ++x) {
        const int floor = surge_floor(x, uphill);
        std::uint64_t units = 0;
        for (int y = floor - 1; y >= 0 && w.stored_material(x, y) == Material::Water; --y)
            units += w.liquid_mass(x, y);
        grounded += units;
        if (x < 240) beyond_left += units;
        if (x >= 272) beyond_right += units;
        travel += units * static_cast<unsigned>(std::max({0, 240 - x, x - 271}));
        if (floor <= 152) high8 += units;
        if (floor <= 144) high16 += units;
        if (floor <= 128) high32 += units;
        if (units > 0) {
            left_film = std::min(x, left_film);
            right_film = std::max(x, right_film);
        }
        run = units >= 255 ? run + 1 : 0;
        if (run >= 8) {
            left = std::min(left, x - 7);
            right = std::max(right, x);
        }
    }
    std::printf(",%d,%d,%d,%d,%d,%llu,%llu,%llu,%llu,%llu,%llu,%.5f",
                240 - left, right - 271, 240 - left_film, right_film - 271,
                160 - surge_floor(right, uphill), static_cast<unsigned long long>(grounded),
                static_cast<unsigned long long>(beyond_left), static_cast<unsigned long long>(beyond_right),
                static_cast<unsigned long long>(high8), static_cast<unsigned long long>(high16),
                static_cast<unsigned long long>(high32), static_cast<double>(travel) / (32 * 32 * 255));
}

int build(World& w, const std::string& scene, int size) {
    if (scene == "ramp") {
        if (size != 2048) throw std::invalid_argument("the supplied ramp has extent 2048 x 2048");
        const int halo = w.config().chunk_size;
        w.reserve_temperature_region({-halo, -halo, size + 2 * halo, size + 2 * halo});
        std::ifstream stamps(arg("stamps", ""));
        int count = 0, x, y, sw, sh, material;
        while (stamps >> x >> y >> sw >> sh >> material) {
            if (x < 0 || y < 0 || sw <= 0 || sh <= 0 || sw > size || sh > size || x > size - sw || y > size - sh ||
                (material != static_cast<int>(Material::Water) && material != static_cast<int>(Material::Wall)))
                throw std::invalid_argument("invalid ramp edit");
            rect(w, x, y, sw, sh, static_cast<Material>(material));
            ++count;
        }
        if (count != 635 || !stamps.eof() || w.water_quantity({0, 0, size, size}) != 9773895U)
            throw std::invalid_argument("ramp setup differs from the supplied recipe");
        // The prepared Workbench selects a full-canvas region when windowing
        // is disabled. Empty resident halo cells are outside that selection.
        w.set_simulation_region(RectI64{0, 0, size, size});
        return count;
    }
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
    if (is_surge(scene)) {
        if (size != 512) throw std::invalid_argument("surge controls require size=512");
        const bool uphill = scene == "uphill_surge";
        for (int x = 0; x < size; ++x) {
            const auto y = surge_floor(x, uphill);
            // Solid-fill to the base closes the one-cell diagonal step corners.
            rect(w, x, y, 1, 161 - y, Material::Wall);
        }
        // A 32-cell gap survives multiple rounds at the maximum fall of eight.
        rect(w, 240, scene == "drop_surge" ? 96 : 128, 32, 32, Material::Water);
    } else if (scene == "reservoir") {
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
            const int depth = number("tank_depth", 11), step = number("tank_step", 6);
            if (depth < 1 || depth > 38 || step < 1 || step > 39 - depth)
                throw std::invalid_argument("tank_depth and tank_step must be positive and fit below the 40-row wall");
            rect(w, 16, 16, 1, 41, Material::Wall);
            const int lip = scene == "tank_open" ? 55 - depth : 16;
            rect(w, 81, lip, 1, 57 - lip, Material::Wall);
            rect(w, 16, 56, 66, 1, Material::Wall);
            rect(w, 16, 80, 98, 1, Material::Wall);
            rect(w, 113, 56, 1, 25, Material::Wall);
            rect(w, 17, 56 - depth, 64, depth, Material::Water);
            rect(w, 17, 56 - depth - step, 32, step, Material::Water);
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
void sample_profile(const World& w, bool blob, int width, bool tank_shape) {
    std::array<double, 65> cumulative_depth{};
    const int first = blob ? 0 : 17;
    const int count = blob ? width : 64;
    double previous2 = 0, previous1 = 0, curvature2 = 0, first_mode = 0;
    int left = -1, right = -1;
    for (int k = 0; k < count; ++k) {
        const int x = first + k;
        const auto units = w.water_quantity({x, 0, 1, 56});
        const double h = static_cast<double>(units) / 255.0;
        if (tank_shape) {
            const auto n = static_cast<std::size_t>(k);
            cumulative_depth[n + 1] = cumulative_depth[n] + h;
        }
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
    if (tank_shape) {
        // An eight-column mean measures a broad crest without crediting a
        // single-cell spike. The slope compares adjacent eight-column means.
        constexpr std::size_t window = 8;
        const auto mean = [&](std::size_t x) { return (cumulative_depth[x + window] - cumulative_depth[x]) / window; };
        double low = mean(0), high = low, slope = 0;
        for (std::size_t x = 0; x + window <= 64; ++x) {
            const double h = mean(x);
            low = std::min(low, h);
            high = std::max(high, h);
            if (x >= window) slope = std::max(slope, std::abs(h - mean(x - window)) / window);
        }
        std::printf(",%.7f,%.7f", high - low, slope);
    }
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
        const int size = number("size", scene == "ramp" ? 2048 : scene == "map" ? 1024 : 512);
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
        const bool surge = is_surge(scene);
        if (surge) std::printf(",left_bulk_distance,right_bulk_distance,left_film_distance,right_film_distance,"
                               "bulk_floor_rise,grounded_units,left_spread_units,right_spread_units,"
                               "rise8_units,rise16_units,rise32_units,mass_weighted_outward_cells");
        RampTrace ramp;
        if (scene == "ramp") { ramp.prepare(w); ramp.header(); }
        const bool tank_shape = (scene == "tank" || scene == "tank_open") && number("tank_shape", 0) != 0;
        if (profile) std::printf(",long_mode_cells,curvature_rms_cells,front_left_32,front_right_32");
        if (tank_shape) std::printf(",broad_range_cells,broad_slope_cells_per_cell");
        std::printf(",solved_chunks,window_median_us,window_p95_us\n");
        DischargeTrace discharge;
        discharge.open(w);
        const int fin_every = number("fin_every", 4);
        if (fin_every < 1) throw std::invalid_argument("fin_every must be positive");
        std::vector<double> window, overall;
        for (int t = 0; t <= ticks; ++t) {
            discharge.sample(w, t);
            if (t % fin_every == 0) ramp.sample_fins(w, t, before);
            if (t % every == 0) {
                const auto now = w.water_quantity({all.x, all.y, all.w, all.h}) + w.ballistic_water_snapshot().in_flight_quantity;
                const auto diag = w.wave_flow_diagnostics();
                std::printf("%d,%lld,%llu", t, static_cast<long long>(now) - static_cast<long long>(before),
                            static_cast<unsigned long long>(diag.moved_units));
                for (const auto& probe : g_probes)
                    std::printf(",%.1f", static_cast<double>(w.water_quantity({probe.second.x, probe.second.y, probe.second.w, probe.second.h})) / 255.0);
                if (scene == "ramp") ramp.sample(w);
                if (surge) sample_surge(w, scene == "uphill_surge");
                if (profile) sample_profile(w, scene == "blob", size, tank_shape);
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
