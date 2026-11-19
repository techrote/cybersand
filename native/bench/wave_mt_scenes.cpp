// WAVE-MT-001 behaviour scenes on the real native World.
// Usage: wave_mt_scenes SCENE FAMILY [SUBSTEPS] [FRAME_PREFIX]
//   SCENE   interfere | dam | utube | falls | body
//   FAMILY  1 FreeMass, 2 CellularYield, 3 PressureFlow(cached_dormant), 4 Inertial, 5 wave_flow_v1
// Prints quantitative probes; with FRAME_PREFIX also writes binary PPM frames.
#include "cybersand/world.hpp"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <fstream>
#include <iostream>
#include <memory>
#include <span>
#include <stdexcept>
#include <string>
#include <vector>

using namespace cybersand;

namespace {

int g_family = 5, g_substeps = 1;
std::string g_frames;

std::unique_ptr<World> make_world(int workers = 4) {
    WorldConfig cfg;
    cfg.initial_chunk_reserve = 128;
    cfg.maximum_chunk_count = 256;
    cfg.active_chunk_capacity = 256;
    cfg.worker_threads = static_cast<std::uint32_t>(workers);
    cfg.parallel_job_threshold = 2;
    if (g_family == 3) cfg.pressure_gas_compartment_capacity = 2048;
    if (g_family == 4) cfg.maximum_rule_radius = 3;
    if (g_family == 5) {
        cfg.wave_flow.enabled = true;
        cfg.wave_flow.substeps = static_cast<std::uint8_t>(g_substeps);
    }
    auto request = LiquidSolverPolicy::default_request();
    request[21] = g_family == 5 ? 1 : g_family;
    request[22] = g_family == 3 ? 2 : 0;
    const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(request));
    if (!decoded.accepted()) throw std::runtime_error("policy refused: " + decoded.refusal.message());
    cfg.liquid_solver_policy = *decoded.policy;
    return std::make_unique<World>(cfg);
}

void rect(World& w, int x, int y, int width, int height, Material material) {
    for (int yy = y; yy < y + height; ++yy)
        for (int xx = x; xx < x + width; ++xx) w.set(xx, yy, material);
}

void box(World& w, int width, int height) {
    rect(w, 0, 0, width, 1, Material::Wall);
    rect(w, 0, height - 1, width, 1, Material::Wall);
    rect(w, 0, 0, 1, height, Material::Wall);
    rect(w, width - 1, 0, 1, height, Material::Wall);
}

double column(const World& w, int x, int height) {
    return static_cast<double>(w.water_quantity({x, 0, 1, height})) / 255.0;
}

void frame(const World& w, int width, int height, const std::string& name, int tick) {
    if (g_frames.empty()) return;
    char path[512];
    std::snprintf(path, sizeof(path), "%s-%s-f%d-t%05d.ppm", g_frames.c_str(), name.c_str(), g_family, tick);
    std::ofstream out(path, std::ios::binary);
    out << "P6\n" << width << ' ' << height << "\n255\n";
    std::vector<unsigned char> row(static_cast<std::size_t>(width) * 3U);
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            const auto material = w.get(x, y);
            unsigned char r = 12, g = 14, b = 22;
            if (w.transient_obstacle_at(x, y) != 0U) { r = 230; g = 120; b = 40; }
            else if (material == Material::Water) {
                const auto mass = std::min<int>(255, w.liquid_mass(x, y));
                r = static_cast<unsigned char>(12 + mass / 8);
                g = static_cast<unsigned char>(40 + mass / 3);
                b = static_cast<unsigned char>(90 + mass * 165 / 255);
            } else if (material != Material::Empty) { r = 96; g = 92; b = 84; }
            row[static_cast<std::size_t>(x) * 3U] = r;
            row[static_cast<std::size_t>(x) * 3U + 1U] = g;
            row[static_cast<std::size_t>(x) * 3U + 2U] = b;
        }
        out.write(reinterpret_cast<const char*>(row.data()), static_cast<std::streamsize>(row.size()));
    }
}

// Two disturbances in a contained pool, measured at the midpoint. Running A,
// B, A+B, a trough and A-with-trough separately tests linear superposition:
// constructive interference doubles the single-source peak, destructive
// interference cancels it. The mean level change of each case is removed.
constexpr int kPoolW = 768, kPoolH = 160, kDepth = 64, kBump = 6, kHalf = 12;

std::vector<double> probe_series(int sign_a, int sign_b, int ticks, const char* label) {
    auto w = make_world();
    box(*w, kPoolW, kPoolH);
    const int surface = kPoolH - 1 - kDepth;
    rect(*w, 1, surface, kPoolW - 2, kDepth, Material::Water);
    // Let the undisturbed pool reach its own rest state first.
    for (int t = 0; t < 120; ++t) (void)w->tick();
    const auto disturb = [&](int cx, int sign) {
        if (sign > 0) rect(*w, cx - kHalf, surface - kBump, kHalf * 2, kBump, Material::Water);
        if (sign < 0) rect(*w, cx - kHalf, surface, kHalf * 2, kBump, Material::Empty);
    };
    disturb(kPoolW / 4, sign_a);
    disturb(kPoolW * 3 / 4, sign_b);
    const auto before = w->water_quantity({0, 0, kPoolW, kPoolH});
    std::vector<double> series;
    for (int t = 0; t < ticks; ++t) {
        if (label != nullptr && (t % 100 == 0)) frame(*w, kPoolW, kPoolH, label, t);
        (void)w->tick();
        // Average three columns to suppress single-cell quantisation.
        series.push_back((column(*w, kPoolW / 2 - 1, kPoolH) + column(*w, kPoolW / 2, kPoolH) +
                          column(*w, kPoolW / 2 + 1, kPoolH)) / 3.0 - kDepth);
    }
    if (w->water_quantity({0, 0, kPoolW, kPoolH}) != before) std::puts("CONSERVATION FAILURE");
    return series;
}

int interfere() {
    const int ticks = 900 / g_substeps + 100;
    const auto a = probe_series(+1, 0, ticks, nullptr);
    const auto b = probe_series(0, +1, ticks, nullptr);
    const auto both = probe_series(+1, +1, ticks, "interfere");
    const auto trough = probe_series(0, -1, ticks, nullptr);
    const auto anti = probe_series(+1, -1, ticks, "cancel");
    const double per_column = static_cast<double>(kBump * 2 * kHalf) / (kPoolW - 2);
    const auto centred = [](std::vector<double> s, double mean) { for (auto& v : s) v -= mean; return s; };
    const auto ca = centred(a, per_column), cb = centred(b, per_column), cboth = centred(both, 2 * per_column);
    const auto ctrough = centred(trough, -per_column), canti = centred(anti, 0.0);
    const auto peak = [](const std::vector<double>& s, int from, int to) {
        double best = 0; int at = 0;
        for (int t = from; t < to; ++t) if (std::fabs(s[static_cast<std::size_t>(t)]) > std::fabs(best)) { best = s[static_cast<std::size_t>(t)]; at = t; }
        return std::pair<double, int>{best, at};
    };
    const auto [pa, ta] = peak(ca, 0, ticks);
    const int from = std::max(0, ta - 120), to = std::min(ticks, ta + 120);
    const auto pb = peak(cb, from, to).first, pboth = peak(cboth, from, to).first;
    const auto ptrough = peak(ctrough, from, to).first, panti = peak(canti, from, to).first;
    double superposition = 0, cancellation = 0, signal = 0;
    for (int t = 0; t < ticks; ++t) {
        const auto k = static_cast<std::size_t>(t);
        superposition += std::pow(cboth[k] - (ca[k] + cb[k]), 2);
        cancellation += std::pow(canti[k] - (ca[k] + ctrough[k]), 2);
        signal += std::pow(ca[k] + cb[k], 2);
    }
    std::printf("family=%d substeps=%d first_arrival_tick=%d speed_cells_per_tick=%.3f\n", g_family, g_substeps, ta,
                static_cast<double>(kPoolW / 4) / std::max(1, ta));
    std::printf("peak_A=%.3f peak_B=%.3f peak_A+B=%.3f constructive_ratio=%.2f\n", pa, pb, pboth, pa == 0 ? 0 : pboth / pa);
    std::printf("peak_trough=%.3f peak_A_with_trough=%.3f destructive_ratio=%.2f\n", ptrough, panti,
                pa == 0 ? 0 : std::fabs(panti) / std::fabs(pa));
    std::printf("superposition_error=%.3f cancellation_error=%.3f (rms residual / rms signal)\n",
                signal == 0 ? 0 : std::sqrt(superposition / signal), signal == 0 ? 0 : std::sqrt(cancellation / signal));
    return 0;
}

int dam() {
    const int n = 512;
    auto w = make_world();
    box(*w, n, n);
    rect(*w, 1, n / 4, n / 3, n - 1 - n / 4, Material::Water);
    const auto before = w->water_quantity({0, 0, n, n});
    std::puts("tick,front_x,reservoir_level,far_level,quantity_drift");
    for (int t = 0; t <= 3000; ++t) {
        if (t % 250 == 0) {
            int front = 0;
            for (int x = n - 2; x > 0; --x) if (column(*w, x, n) > 0) { front = x; break; }
            std::printf("%d,%d,%.2f,%.2f,%lld\n", t, front, column(*w, 8, n), column(*w, n - 9, n),
                        static_cast<long long>(w->water_quantity({0, 0, n, n})) - static_cast<long long>(before));
        }
        if (t % 150 == 0 && t <= 1500) frame(*w, n, n, "dam", t);
        (void)w->tick();
    }
    std::printf("conserved=%d\n", w->water_quantity({0, 0, n, n}) == before ? 1 : 0);
    return 0;
}

int utube() {
    const int width = 200, height = 200;
    auto w = make_world();
    box(*w, width, height);
    rect(*w, 60, 1, 80, height - 5, Material::Wall);
    rect(*w, 1, 40, 59, height - 41, Material::Water);
    rect(*w, 60, height - 4, 80, 3, Material::Water);
    rect(*w, 140, 150, width - 141, height - 151, Material::Water);
    const auto before = w->water_quantity({0, 0, width, height});
    std::puts("tick,left_level,right_level");
    for (int t = 0; t <= 6000; ++t) {
        if (t % 500 == 0) std::printf("%d,%.2f,%.2f\n", t, column(*w, 30, height), column(*w, 170, height));
        if (t % 1000 == 0) frame(*w, width, height, "utube", t);
        (void)w->tick();
    }
    std::printf("conserved=%d\n", w->water_quantity({0, 0, width, height}) == before ? 1 : 0);
    return 0;
}

int falls() {
    // A raised basin overflows a ledge into a lower pool while a source refills it.
    const int width = 384, height = 256;
    auto w = make_world();
    box(*w, width, height);
    rect(*w, 1, 90, 150, 2, Material::Wall);
    rect(*w, 150, 70, 2, 22, Material::Wall);
    rect(*w, 1, 60, 149, 30, Material::Water);
    rect(*w, 152, height - 31, width - 153, 30, Material::Water);
    std::puts("tick,basin_cells,lower_level_near,lower_level_far");
    for (int t = 0; t <= 1200; ++t) {
        if (t < 600 && t % 2 == 0) rect(*w, 20, 30, 6, 2, Material::Water);
        if (t % 100 == 0)
            std::printf("%d,%.0f,%.2f,%.2f\n", t, static_cast<double>(w->water_quantity({1, 1, 149, 89})) / 255.0,
                        column(*w, 170, height), column(*w, width - 20, height));
        if (t % 100 == 0) frame(*w, width, height, "falls", t);
        (void)w->tick();
    }
    return 0;
}

int body() {
    // A rectangular body mask sinks through a pool and is then lifted out.
    const int width = 256, height = 192;
    auto w = make_world();
    box(*w, width, height);
    rect(*w, 1, height - 81, width - 2, 80, Material::Water);
    w->configure_transient_obstacles({0, 0, width, height});
    const auto before = w->water_quantity({0, 0, width, height});
    std::puts("tick,body_y,contacts,impulse_x,impulse_y,level_left,level_right,water_under_mask");
    for (int t = 0; t <= 600; ++t) {
        const int by = t < 300 ? 60 + t / 3 : 160 - (t - 300) / 2;
        w->clear_transient_obstacles();
        w->clear_transient_contact_observations();
        std::uint64_t under = 0;
        for (int y = by; y < by + 12; ++y)
            for (int x = 110; x < 146; ++x) {
                if (w->liquid_mass(x, y) != 0U) ++under;
                (void)w->set_transient_obstacle(x, y, 1);
            }
        (void)w->tick();
        if (t % 50 == 0)
            std::printf("%d,%d,%llu,%lld,%lld,%.2f,%.2f,%llu\n", t, by,
                        static_cast<unsigned long long>(w->transient_contact_count(1)),
                        static_cast<long long>(w->transient_contact_impulse_x(1)),
                        static_cast<long long>(w->transient_contact_impulse_y(1)), column(*w, 40, height),
                        column(*w, width - 40, height), static_cast<unsigned long long>(under));
        if (t % 100 == 0) frame(*w, width, height, "body", t);
    }
    std::printf("conserved=%d\n", w->water_quantity({0, 0, width, height}) == before ? 1 : 0);
    return 0;
}

}  // namespace

int main(int argc, char** argv) {
    try {
        const std::string scene = argc > 1 ? argv[1] : "";
        if (argc > 2) g_family = std::stoi(argv[2]);
        if (argc > 3) g_substeps = std::stoi(argv[3]);
        if (argc > 4) g_frames = argv[4];
        if (scene == "interfere") return interfere();
        if (scene == "dam") return dam();
        if (scene == "utube") return utube();
        if (scene == "falls") return falls();
        if (scene == "body") return body();
        std::cerr << "usage: SCENE(interfere|dam|utube|falls|body) FAMILY [SUBSTEPS] [FRAME_PREFIX]\n";
        return 2;
    } catch (const std::exception& e) {
        std::cerr << "apparatus_error=" << e.what() << "\n";
        return 1;
    }
}
