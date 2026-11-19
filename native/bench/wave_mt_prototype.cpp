// WAVE-MT-001 standalone kernel testbed (no World dependency).
//
// Candidate C, "column-head flux": conserved fractional mass per cell, a
// retained signed flux on every vertical cell face, and a per-column sweep that
// applies gravity, pushes overfill upward and derives one hydrostatic head per
// vertical liquid run. No pressure solve, flood fill, gas or global state.
//
// Ablation ("relax"): the same kernel with no retained flux (pure relaxation),
// i.e. a direct-array FreeMass-style law. It isolates what momentum buys.
//
//   wave_mt_prototype interfere [retain|relax]
//   wave_mt_prototype utube
//   wave_mt_prototype dam SIZE
//   wave_mt_prototype perf SIZE WORKERS TICKS [retain|relax]
#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <functional>
#include <string>
#include <thread>
#include <vector>

namespace {

using i32 = std::int32_t;
using i64 = std::int64_t;

constexpr i32 kMax = 256;        // one full cell, q8
constexpr i32 kFluxShift = 12;   // flux sub-units per mass unit
constexpr i32 kActive = 32;      // rows below a run's surface that carry head-driven flux
constexpr i32 kGain0 = 32;       // constant gravity: 1/128 cell per row of head per tick^2 (c <= 1/2)
constexpr i32 kGainConfined = 4; // sealed runs accelerate 8x slower so their overfill can be 8x stiffer
constexpr i32 kCoast = 16;       // mass units a face may carry per tick on inertia alone
constexpr i32 kFilm = 24;        // residual film on a dry floor
constexpr i32 kStiffness = 256;  // rows of head per full cell of overfill, per active row of a sealed run
constexpr i32 kStrip = 64;       // columns owned by one task

int g_foot = 1 << 30;  // rows of a liquid cliff allowed to pour, counted from its foot
int g_coast = kCoast, g_share = 0;

struct Params {
    bool retain = true;
    i32 damp_shift = 7;
};

struct Grid {
    int w = 0, h = 0;
    std::vector<std::uint8_t> solid, was_full;
    std::vector<i32> m, f, head;
    std::vector<std::uint16_t> gain;
    Grid(int width, int height)
        : w(width), h(height), solid(static_cast<std::size_t>(width) * height, 0), was_full(solid.size(), 0),
          m(solid.size(), 0), f(solid.size(), 0), head(solid.size(), 0), gain(solid.size(), kGain0) {}
    [[nodiscard]] std::size_t at(int x, int y) const { return static_cast<std::size_t>(y) * w + x; }
    void box() {
        for (int x = 0; x < w; ++x) solid[at(x, 0)] = solid[at(x, h - 1)] = 1;
        for (int y = 0; y < h; ++y) solid[at(0, y)] = solid[at(w - 1, y)] = 1;
    }
    void fill(int x0, int y0, int x1, int y1, i32 mass) {
        for (int y = y0; y < y1; ++y)
            for (int x = x0; x < x1; ++x) m[at(x, y)] = mass;
    }
    void wall(int x0, int y0, int x1, int y1) {
        for (int y = y0; y < y1; ++y)
            for (int x = x0; x < x1; ++x) { solid[at(x, y)] = 1; m[at(x, y)] = 0; }
    }
    [[nodiscard]] i64 total() const {
        i64 sum = 0;
        for (const auto v : m) sum += v;
        return sum;
    }
    [[nodiscard]] i64 column(int x) const {
        i64 sum = 0;
        for (int y = 0; y < h; ++y) sum += m[at(x, y)];
        return sum;
    }
};

// Column pass: gravity, overfill-up, run heads. Owns columns [x0,x1).
void column_pass(Grid& g, int x0, int x1) {
    const int w = g.w, h = g.h;
    for (int x = x0; x < x1; ++x) {
        // Settle, bottom-up. `dst` is the lowest cell that may still receive.
        // A chain of thick cells is hydrostatically connected: deficits left by
        // lateral outflow are refilled from above without a distance limit, so
        // a run never splits. Only cells that were full after the previous settle
        // transmit support: loose liquid above anything else falls one cell per tick. Excess is carried upward to the surface,
        // or stays as confined overfill under a solid ceiling.
        int dst = -1;
        bool chain = false;
        i32 carry = 0;
        for (int y = h - 1; y >= 0; --y) {
            const auto i = g.at(x, y);
            if (g.solid[i]) {
                if (carry != 0) { g.m[i + static_cast<std::size_t>(w)] += carry; carry = 0; }
                dst = -1; chain = false;
                continue;
            }
            g.m[i] += carry;
            carry = 0;
            if (g.m[i] <= 0) { dst = y; chain = false; continue; }
            const i32 before = g.m[i];
            if (dst > y && !chain) dst = y + 1;
            while (dst > y && g.m[i] > 0) {
                const auto d = g.at(x, dst);
                const i32 room = kMax - g.m[d];
                if (room <= 0) { --dst; continue; }
                const i32 t = std::min(g.m[i], room);
                g.m[d] += t;
                g.m[i] -= t;
            }
            if (g.m[i] > kMax) { carry = g.m[i] - kMax; g.m[i] = kMax; }
            if (g.m[i] == 0) g.f[i] = 0;
            (void)before;
            chain = g.was_full[i] != 0;
            if (dst <= y || g.m[g.at(x, dst)] >= kMax) dst = g.m[i] < kMax ? y : -1;
        }
        if (carry != 0) g.m[g.at(x, 0)] += carry;
        // Heads, top-down. The head of a wet cell is its floor elevation plus
        // the weight of the contiguous liquid at and above it. A unit moved
        // sideways at a row then changes potential energy by exactly the head
        // difference, for any stack of full, thin or falling cells, so the
        // retained flux cannot gain energy from a mis-stated surface.
        i32 weight = 0;
        int index = 0;
        bool confined = false;
        for (int y = 0; y < h; ++y) {
            const auto i = g.at(x, y);
            if (g.solid[i]) { weight = 0; index = 0; continue; }
            const i32 base = (h - 1 - y) * kMax;
            const i32 mass = g.m[i];
            if (mass <= 0) {
                g.head[i] = base; g.gain[i] = kGain0; g.was_full[i] = 0;
                weight = 0; index = 0;
                continue;
            }
            if (index == 0) {
                confined = mass > kMax || (mass == kMax && y > 0 && g.solid[g.at(x, y - 1)]);
                if (mass > kMax) {
                    // Sealed overfill is stiff: scale by the rows that can respond.
                    int rows = 1;
                    while (rows < kActive && y + rows < h && !g.solid[g.at(x, y + rows)] && g.m[g.at(x, y + rows)] > 0) ++rows;
                    weight = (mass - kMax) * (kStiffness / rows - 1);
                }
            }
            // Only a full cell carries what rests on it. Anything inserted below a
            // thin cell fills that cell instead of lifting the liquid above, and
            // a falling curtain of thin cells exerts no pressure.
            weight = mass + (mass >= kMax ? weight : 0);
            g.head[i] = base + weight;
            g.was_full[i] = mass >= kMax;
            g.gain[i] = static_cast<std::uint16_t>(index >= kActive ? 0 : confined ? kGainConfined : kGain0);
            ++index;
        }
    }
}

// Flux pass: new retained flux on the right face of every owned cell.
void flux_pass(Grid& g, const Params& p, int x0, int x1) {
    const int w = g.w, h = g.h;
    // Rows of a liquid|empty face counted upward from the foot of each exposed
    // stretch. Only the lowest kActive rows of a tall liquid cliff (and the top
    // kActive rows of its run) pour: an unbounded number of pouring rows would
    // move more than a column per tick and overshoot into a checkerboard.
    int exposed[kStrip] = {};
    for (int y = h - 2; y >= 1; --y) {
        for (int x = x0; x < x1 && x < w - 1; ++x) {
            const auto i = g.at(x, y);
            const i32 a = g.m[i], b = g.m[i + 1];
            if ((a <= 0 && b <= 0) || g.solid[i] || g.solid[i + 1]) { g.f[i] = 0; exposed[x - x0] = 0; continue; }
            const i32 dh = g.head[i] - g.head[i + 1];
            i32 ga = g.gain[i], gb = g.gain[i + 1];
            if (a <= 0 || b <= 0) {
                const bool foot = ++exposed[x - x0] <= g_foot;
                if (a <= 0) ga = foot ? gb == kGainConfined ? gb : kGain0 : 0;
                else gb = foot ? ga == kGainConfined ? ga : kGain0 : 0;
            } else {
                exposed[x - x0] = 0;
            }
            const i32 gain = (ga == kGainConfined || gb == kGainConfined) ? kGainConfined : std::max(ga, gb);
            // A face outside every active band keeps no momentum: coasting flux
            // with no restoring force would pump energy into the surface.
            if (gain == 0) { g.f[i] = 0; continue; }
            i64 fn = p.retain ? static_cast<i64>(g.f[i]) - (g.f[i] >> p.damp_shift) : 0;
            fn += static_cast<i64>(dh) * gain * (p.retain ? 1 : 2);
            const bool right = fn > 0;
            const i32 source = right ? a : b;
            const auto destination = right ? i + 1 : i;
            i32 available = source;
            if (g.m[destination] <= 0 && g.solid[destination + static_cast<std::size_t>(w)]) available -= kFilm;
            // Inertia is bounded: a face may coast at most kCoast units per tick
            // against or beyond its head difference. Larger transfers are
            // limited to the share that would level the two columns if every
            // active row moved at once, so bulk flow relaxes without overshoot
            // while small-amplitude flow keeps its momentum and makes waves.
            const i32 downhill = (dh > 0) == right ? std::abs(dh) >> 9 : 0;  // explicit-diffusion bound
            // Pouring into an empty cell is one-directional and self-limiting.
            available = g.m[destination] <= 0 ? available >> 2 : std::min(available >> 1, std::max(g_coast, downhill >> g_share));
            const i64 cap = available <= 0 ? 0 : static_cast<i64>(available) << kFluxShift;
            if (right) fn = std::min(fn, cap); else fn = std::max(fn, -cap);
            g.f[i] = static_cast<i32>(fn);
        }
    }
}

// Whole mass units moved through a face this tick. The sub-unit part of the
// flux is resolved by a stateless per-face, per-tick dither, so the expected
// transfer equals the flux exactly and identical rows do not move in lockstep.
inline i32 transfer(i32 flux, int x, int y, std::uint32_t tick) {
    std::uint32_t k = static_cast<std::uint32_t>(x) * 73856093U ^ static_cast<std::uint32_t>(y) * 19349663U ^ tick * 83492791U;
    k ^= k >> 15; k *= 0x2C1B3C6DU; k ^= k >> 12;
    return (flux + static_cast<i32>(k & 4095U)) >> kFluxShift;
}

// Apply pass: exact conservative transfer; both sides evaluate the same face function.
void apply_pass(Grid& g, int x0, int x1, std::uint32_t tick) {
    const int h = g.h;
    for (int y = 1; y < h - 1; ++y) {
        for (int x = std::max(x0, 1); x < x1; ++x) {
            const auto i = g.at(x, y);
            if (g.solid[i]) continue;
            g.m[i] += transfer(g.f[i - 1], x - 1, y, tick) - transfer(g.f[i], x, y, tick);
        }
    }
}

// Minimal persistent strip pool: disjoint column ownership, three barriers a tick.
class Pool {
public:
    explicit Pool(int workers) : workers_(std::max(1, workers)) {}
    template <typename Function>
    void run(int strips, Function&& function) {
        if (workers_ == 1) { for (int s = 0; s < strips; ++s) function(s); return; }
        std::atomic<int> next{0};
        std::vector<std::thread> threads;
        const auto body = [&] { for (int s; (s = next.fetch_add(1)) < strips;) function(s); };
        for (int t = 1; t < workers_; ++t) threads.emplace_back(body);
        body();
        for (auto& thread : threads) thread.join();
    }
private:
    int workers_;
};

bool g_trace = false;
double energy_of(const Grid& g, double* kinetic) {
    double pe = 0, ke = 0;
    for (int x = 1; x < g.w - 1; ++x) { const double hx = static_cast<double>(g.column(x)) / kMax; pe += hx * hx / 2; }
    for (const auto v : g.f) { const double q = static_cast<double>(v) / 4096 / kMax; ke += q * q * 64; }
    *kinetic = ke;
    return pe;
}
std::uint32_t g_tick = 0;
int g_every = 400, g_x0 = 4, g_dx = 21;

void step(Grid& g, const Params& p, Pool& pool) {
    const auto tick = ++g_tick;
    const int strips = (g.w + kStrip - 1) / kStrip;
    const auto range = [&](int s) { return std::pair<int, int>{s * kStrip, std::min(g.w, (s + 1) * kStrip)}; };
    double k0 = 0, k1 = 0, k2 = 0, k3 = 0, p0 = 0, p1 = 0, p2 = 0, p3 = 0;
    if (g_trace) p0 = energy_of(g, &k0);
    pool.run(strips, [&](int s) { const auto [a, b] = range(s); column_pass(g, a, b); });
    if (g_trace) p1 = energy_of(g, &k1);
    pool.run(strips, [&](int s) { const auto [a, b] = range(s); flux_pass(g, p, a, b); });
    if (g_trace) p2 = energy_of(g, &k2);
    pool.run(strips, [&](int s) { const auto [a, b] = range(s); apply_pass(g, a, b, tick); });
    if (g_trace) { p3 = energy_of(g, &k3); std::printf("tick %u: column dPE=%.1f dKE=%.1f | flux dKE=%.1f | apply dPE=%.1f | total %.1f -> %.1f\n", tick, p1 - p0, k1 - k0, k2 - k1, p3 - p2, p0 + k0, p3 + k3); }
}

// --- Scenarios ---------------------------------------------------------------

constexpr int kPoolW = 768, kPoolH = 160, kDepth = 64, kBump = 6, kHalf = 12;

std::vector<double> probe_series(const Params& p, int sign_a, int sign_b, int probe_x, int ticks) {
    Grid g(kPoolW, kPoolH);
    g.box();
    const int surface = kPoolH - 1 - kDepth;
    g.fill(1, surface, kPoolW - 1, kPoolH - 1, kMax);
    const auto disturb = [&](int cx, int sign) {
        if (sign > 0) g.fill(cx - kHalf, surface - kBump, cx + kHalf, surface, kMax);
        if (sign < 0) g.fill(cx - kHalf, surface, cx + kHalf, surface + kBump, 0);
    };
    disturb(kPoolW / 4, sign_a);
    disturb(kPoolW * 3 / 4, sign_b);
    const i64 before = g.total();
    Pool pool(1);
    std::vector<double> series;
    for (int t = 0; t < ticks; ++t) {
        step(g, p, pool);
        series.push_back(static_cast<double>(g.column(probe_x)) / kMax - kDepth);
    }
    if (g.total() != before) std::printf("CONSERVATION FAILURE %lld -> %lld\n", static_cast<long long>(before), static_cast<long long>(g.total()));
    return series;
}

int interfere(const Params& p) {
    const int ticks = 900, mid = kPoolW / 2;
    const auto a = probe_series(p, +1, 0, mid, ticks);
    const auto b = probe_series(p, 0, +1, mid, ticks);
    const auto both = probe_series(p, +1, +1, mid, ticks);
    const auto anti = probe_series(p, +1, -1, mid, ticks);
    const auto trough = probe_series(p, 0, -1, mid, ticks);
    // Mean level differs per case (water added/removed); remove it per series.
    const auto centred = [](std::vector<double> s, double mean) { for (auto& v : s) v -= mean; return s; };
    const double per_column = static_cast<double>(kBump * 2 * kHalf) / (kPoolW - 2);
    const auto ca = centred(a, per_column), cb = centred(b, per_column), cboth = centred(both, 2 * per_column);
    const auto canti = centred(anti, 0.0), ctrough = centred(trough, -per_column);
    const auto peak = [](const std::vector<double>& s, int from, int to) {
        double best = 0; int at = 0;
        for (int t = from; t < to; ++t) if (std::fabs(s[t]) > std::fabs(best)) { best = s[t]; at = t; }
        return std::pair<double, int>{best, at};
    };
    // First arrival window: before any wall reflection returns to the midpoint.
    const auto [pa, ta] = peak(ca, 0, ticks);
    const int from = std::max(0, ta - 120), to = std::min(ticks, ta + 120);
    const auto pb = peak(cb, from, to).first, pboth = peak(cboth, from, to).first;
    const auto panti = peak(canti, from, to).first, ptrough = peak(ctrough, from, to).first;
    double superposition = 0, cancellation = 0, energy = 0;
    for (int t = 0; t < ticks; ++t) {
        superposition += std::pow(cboth[t] - (ca[t] + cb[t]), 2);
        cancellation += std::pow(canti[t] - (ca[t] + ctrough[t]), 2);
        energy += std::pow(ca[t] + cb[t], 2);
    }
    std::printf("mode=%s first_arrival_tick=%d speed_cells_per_tick=%.3f\n", p.retain ? "retain" : "relax", ta,
                static_cast<double>(kPoolW / 4) / std::max(1, ta));
    std::printf("peak_A=%.3f peak_B=%.3f peak_A+B=%.3f (constructive ratio %.2f)\n", pa, pb, pboth, pboth / pa);
    std::printf("peak_trough=%.3f peak_A-B=%.3f (destructive ratio %.2f)\n", ptrough, panti, std::fabs(panti) / std::fabs(pa));
    std::printf("superposition_rms_error/rms_signal=%.3f antisymmetric=%.3f\n", std::sqrt(superposition / energy),
                std::sqrt(cancellation / energy));
    std::FILE* out = std::fopen("wave_interference_series.csv", "w");
    if (out != nullptr) {
        std::fprintf(out, "tick,A,B,A_plus_B,trough,A_minus_B\n");
        for (int t = 0; t < ticks; ++t)
            std::fprintf(out, "%d,%.4f,%.4f,%.4f,%.4f,%.4f\n", t, ca[t], cb[t], cboth[t], ctrough[t], canti[t]);
        std::fclose(out);
    }
    return 0;
}

int profile(int depth) {
    const int h = depth + 32;
    Grid g(96, h);
    g.box();
    g.fill(1, h - 1 - depth, 95, h - 1, kMax);
    g.fill(40, h - 5 - depth, 56, h - 1 - depth, kMax);
    Params p;
    Pool pool(1);
    for (int t = 0; t <= 40; ++t) {
        if (t % 4 == 0) {
            std::printf("%3d:", t);
            for (int x = 30; x < 66; x += 2) std::printf(" %5.2f", static_cast<double>(g.column(x)) / kMax - depth);
            std::printf("\n");
        }
        step(g, p, pool);
        if (t < 3) {
            for (int y = h - 9 - depth; y < h - 1; y += (y < h + 2 - depth ? 1 : 20)) {
                std::printf("  t%d y%2d:", t, y);
                for (int x = 52; x < 60; ++x) std::printf(" m%4d h%6d f%6d |", g.m[g.at(x, y)], g.head[g.at(x, y)], g.f[g.at(x, y)]);
                std::printf("\n");
            }
        }
    }
    return 0;
}

int energy(int depth, int bump, int width) {
    const int h = depth + 64, w = 512;
    Grid g(w, h);
    g.box();
    g.fill(1, h - 1 - depth, w - 1, h - 1, kMax);
    g.fill(200, h - 1 - depth - bump, 200 + width, h - 1 - depth, kMax);
    Params p;
    Pool pool(1);
    for (int t = 0; t <= 4000; ++t) {
        if (t % g_every == 0) {
            double mean = 0, var = 0, lo = 1e9, hi = -1e9;
            for (int x = 1; x < w - 1; ++x) mean += static_cast<double>(g.column(x)) / kMax;
            mean /= (w - 2);
            for (int x = 1; x < w - 1; ++x) {
                const double v = static_cast<double>(g.column(x)) / kMax - mean;
                var += v * v; lo = std::min(lo, v); hi = std::max(hi, v);
            }
            std::printf("t=%4d rms=%.4f min=%.3f max=%.3f\n", t, std::sqrt(var / (w - 2)), lo, hi);
        }
        step(g, p, pool);
        if (t >= 3000 && t < 3006) {
            std::printf("h:");
            for (int x = 100; x < 124; ++x) std::printf(" %6.2f", static_cast<double>(g.column(x)) / kMax - depth);
            std::printf(" |f:");
            for (int x = 100; x < 124; ++x) { i64 q = 0; for (int y = 0; y < h; ++y) q += g.f[g.at(x, y)]; std::printf(" %6.2f", static_cast<double>(q) / 4096 / kMax); }
            std::puts("");
        }
    }
    return 0;
}

int utube() {
    // Two open arms joined by a sealed 3-row passage under a solid block.
    const int w = 200, h = 200;
    Grid g(w, h);
    g.box();
    g.wall(60, 1, 140, h - 4);         // central block; passage = rows h-4..h-2
    g.fill(1, 40, 60, h - 1, kMax);    // tall left arm
    g.fill(60, h - 4, 140, h - 1, kMax);
    g.fill(140, 150, w - 1, h - 1, kMax); // short right arm
    const i64 before = g.total();
    Params p;
    Pool pool(1);
    const auto level = [&](int x) { return static_cast<double>(g.column(x)) / kMax; };
    std::printf("tick,left_level,right_level,passage_overfill_cells\n");
    for (int t = 0; t <= 6000; ++t) {
        if (t % 500 == 0) {
            i64 over = 0;
            for (int x = 60; x < 140; ++x) over += g.column(x) - 3 * kMax;
            std::printf("%d,%.2f,%.2f,%.2f\n", t, level(30), level(170), static_cast<double>(over) / kMax);
        }
        step(g, p, pool);
    }
    std::printf("conserved=%d\n", g.total() == before ? 1 : 0);
    return 0;
}

int dam(int n) {
    Grid g(n, n);
    g.box();
    g.fill(1, n / 4, n / 3, n - 1, kMax);
    const i64 before = g.total();
    Params p;
    Pool pool(1);
    std::printf("tick,front_x,left_level,right_level\n");
    for (int t = 0; t <= 3000; ++t) {
        if (t % 250 == 0) {
            int front = 0;
            for (int x = n - 2; x > 0; --x) if (g.column(x) > 0) { front = x; break; }
            std::printf("%d,%d,%.2f,%.2f\n", t, front, static_cast<double>(g.column(8)) / kMax,
                        static_cast<double>(g.column(n - 9)) / kMax);
        }
        if (g_every != 400 && t % g_every == 0 && t <= g_every * 24) {
            std::printf("%4d:", t);
            for (int x = g_x0; x < n && x < g_x0 + 26 * g_dx; x += g_dx) std::printf(" %4.0f", static_cast<double>(g.column(x)) / kMax);
            std::puts("");
        }
        step(g, p, pool);
    }
    std::printf("conserved=%d\n", g.total() == before ? 1 : 0);
    return 0;
}

int perf(int n, int workers, int ticks, const Params& p) {
    Grid g(n, n);
    g.box();
    g.fill(1, n - 1 - (n * 2) / 5, n - 1, n - 1, kMax);
    const int surface = n - 1 - (n * 2) / 5;
    Pool pool(workers);
    std::vector<double> samples;
    const i64 before = g.total() + 2LL * 32 * 24 * kMax * ((ticks + 89) / 90);
    for (int t = 0; t < ticks; ++t) {
        if (t % 90 == 0) {
            g.fill(n / 4 - 16, surface - 48, n / 4 + 16, surface - 24, kMax);
            g.fill(n * 3 / 4 - 16, surface - 48, n * 3 / 4 + 16, surface - 24, kMax);
        }
        const auto start = std::chrono::steady_clock::now();
        step(g, p, pool);
        samples.push_back(std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count());
    }
    std::sort(samples.begin(), samples.end());
    i64 wet = 0;
    for (const auto v : g.m) wet += v > 0;
    std::printf("size=%d workers=%d mode=%s wet_cells=%lld p50_ms=%.3f p95_ms=%.3f max_ms=%.3f ns_per_wet_cell=%.2f conserved=%d\n",
                n, workers, p.retain ? "retain" : "relax", static_cast<long long>(wet), samples[samples.size() / 2],
                samples[samples.size() * 95 / 100], samples.back(),
                samples[samples.size() / 2] * 1.0e6 / static_cast<double>(wet), g.total() == before ? 1 : 0);
    return 0;
}

}  // namespace

int main(int argc, char** argv) {
    const std::string mode = argc > 1 ? argv[1] : "";
    Params p;
    const auto last = std::string(argv[argc - 1]);
    if (last == "relax") p.retain = false;
    if (mode == "interfere") return interfere(p);
    if (mode == "utube") return utube();
    if (mode == "energy" && argc > 5) g_every = std::atoi(argv[5]);
    if (mode == "energy" && argc > 6) g_trace = true;
    if (mode == "energy") return energy(std::atoi(argv[2]), std::atoi(argv[3]), std::atoi(argv[4]));
    if (mode == "profile") return profile(argc > 2 ? std::atoi(argv[2]) : 16);
    if (mode == "dam" && argc > 3) g_every = std::atoi(argv[3]);
    if (mode == "dam" && argc > 6) g_foot = std::atoi(argv[6]);
    if (mode == "dam" && argc > 7) g_coast = std::atoi(argv[7]);
    if (mode == "dam" && argc > 5) { g_x0 = std::atoi(argv[4]); g_dx = std::atoi(argv[5]); }
    if (mode == "dam" && argc > 2) return dam(std::atoi(argv[2]));
    if (mode == "perf" && argc > 4) return perf(std::atoi(argv[2]), std::atoi(argv[3]), std::atoi(argv[4]), p);
    std::fprintf(stderr, "usage: interfere [retain|relax] | utube | dam SIZE | perf SIZE WORKERS TICKS [retain|relax]\n");
    return 2;
}
