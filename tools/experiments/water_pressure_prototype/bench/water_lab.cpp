// Scratch-only Water flow lab (extends native/bench/water_polish.cpp).
// usage: water_lab <scenario> <ticks> <workers>
//   scenario: pool | calm | cloud | rain | column | utube | basin
// env: LAB_PNG=<prefix> dumps PNG frames at LAB_FRAMES ticks (comma list)
//      LAB_QUIET=1 suppresses periodic lines
#include "cybersand/world.hpp"
#ifdef LAB_SAMPLER
#include "sampler.hpp"
#endif

#include <algorithm>
#include <cmath>
#include <array>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <numeric>
#include <sstream>
#include <string>
#include <string_view>
#include <vector>

namespace {
using namespace cybersand;

// Hidden per-cell Water mass (prototype overfill) and spare bits, when the
// prototype World exposes them; HEAD builds report zero.
template <class Wd> std::uint32_t hidden_mass(const Wd& w, std::int64_t x, std::int64_t y) {
    if constexpr (requires { w.proto_hidden_mass(x, y); }) return w.proto_hidden_mass(x, y);
    else return 0;
}
template <class Wd> std::uint64_t spare_bits(const Wd& w, std::int64_t x, std::int64_t y) {
    if constexpr (requires { w.proto_spare_bits(x, y); }) return w.proto_spare_bits(x, y);
    else return 0;
}

std::uint32_t crc_table[256];
void crc_init() {
    for (std::uint32_t n = 0; n < 256; ++n) {
        std::uint32_t c = n;
        for (int k = 0; k < 8; ++k) c = c & 1 ? 0xedb88320U ^ (c >> 1) : c >> 1;
        crc_table[n] = c;
    }
}
std::uint32_t crc(const std::uint8_t* p, std::size_t n, std::uint32_t c = 0xffffffffU) {
    for (std::size_t i = 0; i < n; ++i) c = crc_table[(c ^ p[i]) & 255] ^ (c >> 8);
    return c;
}
void be32(std::vector<std::uint8_t>& v, std::uint32_t x) {
    v.push_back(x >> 24); v.push_back(x >> 16); v.push_back(x >> 8); v.push_back(x);
}
void chunk(std::FILE* f, const char* type, const std::vector<std::uint8_t>& data) {
    std::vector<std::uint8_t> v; be32(v, static_cast<std::uint32_t>(data.size()));
    std::fwrite(v.data(), 1, 4, f);
    std::vector<std::uint8_t> body(type, type + 4); body.insert(body.end(), data.begin(), data.end());
    std::fwrite(body.data(), 1, body.size(), f);
    v.clear(); be32(v, crc(body.data(), body.size()) ^ 0xffffffffU); std::fwrite(v.data(), 1, 4, f);
}
// Uncompressed (stored-deflate) RGB PNG.
void write_png(const std::string& path, int w, int h, const std::vector<std::uint8_t>& rgb) {
    std::FILE* f = std::fopen(path.c_str(), "wb");
    if (!f) return;
    const std::uint8_t sig[8] = {137, 80, 78, 71, 13, 10, 26, 10};
    std::fwrite(sig, 1, 8, f);
    std::vector<std::uint8_t> ihdr; be32(ihdr, w); be32(ihdr, h);
    ihdr.insert(ihdr.end(), {8, 2, 0, 0, 0});
    chunk(f, "IHDR", ihdr);
    std::vector<std::uint8_t> raw;
    for (int y = 0; y < h; ++y) {
        raw.push_back(0);
        raw.insert(raw.end(), rgb.begin() + y * w * 3, rgb.begin() + (y + 1) * w * 3);
    }
    std::vector<std::uint8_t> z{0x78, 0x01};
    std::size_t pos = 0;
    while (pos < raw.size()) {
        const std::size_t n = std::min<std::size_t>(65535, raw.size() - pos);
        z.push_back(pos + n == raw.size() ? 1 : 0);
        z.push_back(n & 255); z.push_back(n >> 8); z.push_back(~n & 255); z.push_back((~n >> 8) & 255);
        z.insert(z.end(), raw.begin() + pos, raw.begin() + pos + n);
        pos += n;
    }
    std::uint32_t a = 1, b = 0;
    for (auto c : raw) { a = (a + c) % 65521; b = (b + a) % 65521; }
    be32(z, (b << 16) | a);
    chunk(f, "IDAT", z);
    chunk(f, "IEND", {});
    std::fclose(f);
}
}  // namespace

int main(int argc, char** argv) {
    if (argc != 4) return 2;
    crc_init();
    const std::string_view scenario = argv[1];
    const int ticks = std::stoi(argv[2]);
    WorldConfig config{};
    config.worker_threads = static_cast<std::uint32_t>(std::stoi(argv[3]));
    if (const char* t = std::getenv("LAB_THRESH")) config.parallel_job_threshold = static_cast<std::size_t>(std::atoi(t));
    if (const char* c = std::getenv("LAB_CORE")) config.scheduling_core_size = std::atoi(c);
    if (const char* q = std::getenv("LAB_QUIETTICKS")) config.sleep_after_quiet_ticks = static_cast<std::uint32_t>(std::atoi(q));
    World world(config);
    const std::int64_t width = 384, height = 256;
    world.reserve_region({-128, -128, width + 256, height + 256});
    for (std::int64_t x = 0; x < width; ++x) world.set(x, height - 1, Material::Wall);
    for (std::int64_t y = 0; y < height; ++y) {
        world.set(0, y, Material::Wall);
        world.set(width - 1, y, Material::Wall);
    }
    const auto fill = [&](std::int64_t x0, std::int64_t y0, std::int64_t x1, std::int64_t y1, Material m) {
        for (std::int64_t y = y0; y < y1; ++y)
            for (std::int64_t x = x0; x < x1; ++x) world.set(x, y, m);
    };
    std::int64_t skip0 = -1, skip1 = -1;  // columns excluded from the spread metric
    if (scenario == "calm" || scenario == "pool") fill(1, height - 97, width - 1, height - 1, Material::Water);
    if (scenario == "pool") fill(120, 40, 200, 80, Material::Water);
    // Same slab drop inside a fully closed box (top wall): the whole sky is
    // trapped air, which must not freeze the waves.
    if (scenario == "sealed") {
        fill(0, 0, width, 1, Material::Wall);
        fill(1, height - 97, width - 1, height - 1, Material::Water);
        fill(120, 40, 200, 80, Material::Water);
    }
    if (scenario == "cloud") {
        for (std::int64_t y = 4; y < 100; ++y)
            for (std::int64_t x = 40; x < width - 40; ++x)
                if (((x * 7919 + y * 104729) % 100) < 35) world.set(x, y, Material::Water);
    }
    if (scenario == "rain") {
        for (std::int64_t y = 4; y < 200; ++y)
            for (std::int64_t x = 2; x < width - 2; ++x)
                if (((x * 7919 + y * 104729) % 1000) < 15) world.set(x, y, Material::Water);
    }
    // Standing column released at t=0 on a dry floor.
    if (scenario == "column") fill(172, 20, 212, height - 1, Material::Water);
    // U-tube: divider wall with a bottom gap; left arm high, right arm low.
    if (scenario == "utube") {
        fill(180, 40, 200, height - 30, Material::Wall);
        fill(1, 40, 180, height - 1, Material::Water);
        fill(200, 200, width - 1, height - 1, Material::Water);
        fill(180, height - 30, 200, height - 1, Material::Water);
        skip0 = 180; skip1 = 200;
    }
    // Diving bell: inverted cup in a pool, air trapped inside (level 60 rows
    // below the outside surface). Real air holds the inside level.
    if (scenario == "bell") {
        fill(1, 140, width - 1, height - 1, Material::Water);
        fill(220, 60, 300, 64, Material::Wall);
        fill(220, 64, 224, 210, Material::Wall);
        fill(296, 64, 300, 210, Material::Wall);
        fill(224, 64, 296, 200, Material::Empty);
        skip0 = 220; skip1 = 300;
    }
    // Sealed chamber fed from below by a high reservoir (the owner's sketch):
    // water may enter only by compressing the trapped air.
    if (scenario == "chamber") {
        fill(1, 40, 200, height - 1, Material::Water);
        fill(200, 40, 204, height - 40, Material::Wall);
        fill(204, 100, width - 1, 104, Material::Wall);
        fill(204, height - 40, width - 1, height - 1, Material::Water);
        skip0 = 200; skip1 = width;
    }
    // Owner's sketch: closed box, pool, thin vertical/slanted strokes and
    // overhang hooks dipping into the surface, an arch and a bowl with a boulder.
    if (scenario == "strokes") {
        fill(0, 0, width, 1, Material::Wall);
        fill(1, 181, width - 1, height - 1, Material::Water);
        const auto stroke = [&](std::int64_t x0, std::int64_t y0, std::int64_t x1, std::int64_t y1) {
            for (int i = 0; i <= 100; ++i)
                world.set(x0 + (x1 - x0) * i / 100, y0 + (y1 - y0) * i / 100, Material::Wall);
        };
        stroke(110, 140, 112, 175); stroke(110, 140, 106, 138);
        stroke(126, 150, 126, 176); stroke(140, 154, 139, 176);
        stroke(218, 165, 212, 186); stroke(262, 168, 256, 184); stroke(310, 160, 300, 183);
        for (std::int64_t a = 0; a < 180; ++a) {
            const double t = 3.14159 * a / 179.0;
            const auto cx = 230 + static_cast<std::int64_t>(80 * std::cos(t)), cy = 160 - static_cast<std::int64_t>(60 * std::sin(t));
            fill(cx - 4, cy - 4, cx + 4, cy + 4, Material::Wall);
        }
        // bowl with a boulder, filled to just below the rim
        for (std::int64_t a = 0; a < 180; ++a) {
            const double t = 3.14159 * a / 179.0;
            const auto cx = 100 + static_cast<std::int64_t>(70 * std::cos(t)), cy = 40 + static_cast<std::int64_t>(40 * std::sin(t));
            fill(cx - 6, cy - 6, cx + 6, cy + 6, Material::Wall);
        }
        for (std::int64_t y = 30; y < 74; ++y) for (std::int64_t x = 36; x < 166; ++x)
            if (world.stored_material(x, y) == Material::Empty && (x - 100) * (x - 100) * 1600 + (y - 40) * (y - 40) * 4900 < 1600 * 4900 * 3 / 4 && y > 42)
                world.set(x, y, Material::Water);
        for (std::int64_t y = 36; y < 56; ++y) for (std::int64_t x = 70; x < 90; ++x)
            if ((x - 80) * (x - 80) + (y - 46) * (y - 46) < 100) world.set(x, y, Material::Wall);
        skip0 = 0; skip1 = width;  // spread metric off; use roughness below
    }
    // Owner's sketch: an air cavity carved out under a deep pool (with a
    // boulder at its top) collapses; shows scan stripes and seam lines.
    if (scenario == "cavity") {
        fill(0, 0, width, 1, Material::Wall);
        fill(1, 80, width - 1, height - 1, Material::Water);
        fill(70, 180, 260, 250, Material::Empty);
        fill(140, 150, 190, 180, Material::Empty);
        for (std::int64_t y = 140; y < 165; ++y) for (std::int64_t x = 150; x < 190; ++x)
            if ((x - 170) * (x - 170) + (y - 162) * (y - 162) < 400) world.set(x, y, Material::Wall);
        skip0 = 0; skip1 = width;
    }
    // Owner's case: basin ~3/4 full with a dropped slab (deep, mostly idle).
    if (scenario == "deep") {
        fill(0, 0, width, 1, Material::Wall);
        fill(1, 70, width - 1, height - 1, Material::Water);
        fill(100, 10, 180, 50, Material::Water);
    }
    // Owner's dome: a thick arch whose legs dip into a closed-box pool with
    // air trapped under it; a slab drop elsewhere keeps the pool active.
    if (scenario == "dome") {
        if (!std::getenv("LAB_DOME_OPEN")) fill(0, 0, width, 1, Material::Wall);
        fill(1, 115, width - 1, height - 1, Material::Water);
        for (std::int64_t a = 0; a <= 360; ++a) {
            const double t = 3.14159 * a / 360.0;
            const auto cx = 230 + static_cast<std::int64_t>(70 * std::cos(t)), cy = 175 - static_cast<std::int64_t>(70 * std::sin(t));
            fill(cx - 4, cy - 4, cx + 4, cy + 4, Material::Wall);
        }
        fill(225, 140, 236, 150, Material::Wall);  // hang a little ballast so the top is solid
        for (std::int64_t y = 110; y < 165; ++y) for (std::int64_t x = 166; x < 296; ++x)
            if (world.stored_material(x, y) == Material::Water && (x - 230) * (x - 230) + (y - 175) * (y - 175) < 62 * 62) world.set(x, y, Material::Empty);
        if (!std::getenv("LAB_DOME_NOSLAB")) fill(30, 20, 90, 60, Material::Water);
        skip0 = 0; skip1 = width;
    }
    // Shallow basin with a central mound (no deep pool beneath).
    if (scenario == "basin") {
        fill(1, height - 13, width - 1, height - 1, Material::Water);
        fill(150, height - 73, 234, height - 13, Material::Water);
    }

    const std::int64_t px0 = 1, pw = width - 2, ph = height - 1;
    std::vector<std::uint32_t> previous;
    std::uint32_t max_over = 0;
    std::uint64_t changed = 0;
    const auto sample = [&]() {
        std::vector<std::uint32_t> now(static_cast<std::size_t>(pw * ph));
        for (std::int64_t y = 0; y < ph; ++y)
            for (std::int64_t x = 0; x < pw; ++x)
                now[static_cast<std::size_t>(y * pw + x)] =
                    static_cast<std::uint32_t>(world.stored_material(px0 + x, y)) << 16U |
                    world.stored_state_a(px0 + x, y);
        changed = 0;
        for (std::int64_t y = 0; y < ph; ++y)
            for (std::int64_t x = 0; x < pw; ++x) {
                const auto o = hidden_mass(world, px0 + x, y);
                if (o > max_over) max_over = o;
            }
        if (!previous.empty())
            for (std::size_t i = 0; i < now.size(); ++i) {
                if (now[i] == previous[i]) continue;
                ++changed;
                static const int dump_tick = std::getenv("LAB_DUMP") ? std::atoi(std::getenv("LAB_DUMP")) : -1;
                if (static_cast<int>(world.tick_index()) == dump_tick && changed <= 100000) {
                    const auto cx = px0 + static_cast<std::int64_t>(i) % pw, cy = static_cast<std::int64_t>(i) / pw;
                    const auto bits = spare_bits(world, cx, cy);
                    std::printf("  cell %lld,%lld %u:%u -> %u:%u f=%d o=%d\n", static_cast<long long>(cx),
                                static_cast<long long>(cy), previous[i] >> 16U, previous[i] & 0xffffU, now[i] >> 16U,
                                now[i] & 0xffffU, static_cast<int>(static_cast<std::int8_t>((bits >> 40) & 255)),
                                static_cast<int>((bits >> 48) & 255));
                }
            }
        previous = std::move(now);
    };
    const auto total_mass = [&]() {
        std::uint64_t mass = 0;
        for (std::int64_t y = -2; y < height + 2; ++y)
            for (std::int64_t x = -2; x < width + 2; ++x)
                mass += world.liquid_mass(x, y) + hidden_mass(world, x, y);
        return mass;
    };
    const auto column_mass = [&](std::int64_t x) {
        std::uint64_t column = 0;
        for (std::int64_t y = 0; y < height - 1; ++y)
            column += world.liquid_mass(x, y) + hidden_mass(world, x, y);
        return column;
    };
    const auto full_hash = [&]() {
        std::uint64_t h = 1469598103934665603ULL;
        const auto mix = [&](std::uint64_t v) { h = (h ^ v) * 1099511628211ULL; };
        for (std::int64_t y = 0; y < height; ++y)
            for (std::int64_t x = 0; x < width; ++x) {
                mix(static_cast<std::uint64_t>(world.stored_material(x, y)));
                mix(world.stored_state_a(x, y));
                mix(world.stored_state_b(x, y));
                mix(spare_bits(world, x, y));
            }
        return h;
    };

    std::vector<int> frames;
    if (const char* f = std::getenv("LAB_FRAMES")) {
        std::stringstream ss(f); std::string tok;
        while (std::getline(ss, tok, ',')) frames.push_back(std::stoi(tok));
    }
    const char* png = std::getenv("LAB_PNG");
    const bool quiet = std::getenv("LAB_QUIET") != nullptr;
    // Presentation-only smoothing (LAB_SMOOTH=1): interior fill (water with
    // water above draws full), temporal max/average with the previous tick and
    // a vertical [1 2 1] filter. Changes no simulation state.
    std::vector<int> prev_mass(static_cast<std::size_t>(width * height), 0), cur_mass(prev_mass.size(), 0);
    const bool smooth = std::getenv("LAB_SMOOTH") != nullptr;
    const auto present = [&](std::vector<int>& out) {
        for (std::int64_t y = 0; y < height; ++y)
            for (std::int64_t x = 0; x < width; ++x) {
                const auto i = static_cast<std::size_t>(y * width + x);
                int m = world.stored_material(x, y) == Material::Water ? std::min<int>(world.liquid_mass(x, y), 255) : 0;
                if (m > 0 && y > 0 && world.stored_material(x, y - 1) == Material::Water) m = 255;
                out[i] = m;
            }
    };
    const auto dump = [&](int tick) {
        std::vector<int> shown(static_cast<std::size_t>(width * height));
        present(cur_mass);
        for (std::size_t i = 0; i < shown.size(); ++i)
            shown[i] = (cur_mass[i] == 255 || prev_mass[i] == 255) && cur_mass[i] && prev_mass[i] ? 255 : (cur_mass[i] + prev_mass[i]) / 2;
        std::vector<int> filtered(shown);
        for (std::int64_t y = 1; y + 1 < height; ++y)
            for (std::int64_t x = 0; x < width; ++x) {
                const auto i = static_cast<std::size_t>(y * width + x);
                if (world.stored_material(x, y) != Material::Water && world.stored_material(x, y) != Material::Empty) continue;
                filtered[i] = (shown[i - width] + 2 * shown[i] + shown[i + width]) / 4;
            }
        std::vector<std::uint8_t> rgb(static_cast<std::size_t>(width * height * 3));
        for (std::int64_t y = 0; y < height; ++y)
            for (std::int64_t x = 0; x < width; ++x) {
                const auto m = world.stored_material(x, y);
                std::array<int, 3> c{10, 12, 18};
                const int smoothed = filtered[static_cast<std::size_t>(y * width + x)];
                if (smooth && (m == Material::Water || m == Material::Empty) && smoothed > 24) {
                    const int a = 60 + smoothed * 195 / 255;
                    c = {20 * a / 255 + 10, 110 * a / 255 + 12, 220 * a / 255 + 18};
                } else if (smooth && m == Material::Empty) {
                } else if (m == Material::Water) {
                    const int mass = std::min<int>(world.liquid_mass(x, y), 255);
                    const int a = 60 + mass * 195 / 255;
                    c = {20 * a / 255 + 10, 110 * a / 255 + 12, 220 * a / 255 + 18};
                    if (hidden_mass(world, x, y)) c = {230, 120, 40};
                } else if (m == Material::Wall) c = {82, 91, 106};
                auto* p = &rgb[static_cast<std::size_t>((y * width + x) * 3)];
                p[0] = c[0]; p[1] = c[1]; p[2] = c[2];
            }
        write_png(std::string(png) + "_" + std::to_string(tick) + ".png", static_cast<int>(width),
                  static_cast<int>(height), rgb);
    };

    const auto initial_mass = total_mass();
#ifdef LAB_SAMPLER
    Sampler sampler;
    const bool sampling = std::getenv("LAB_SAMPLE") != nullptr;
    if (sampling) sampler.start();
#endif
    sample();
    std::vector<double> times;
    int sleep_tick = 0, level_tick = 0;
    double spread = 0.0;
    std::uint64_t late_changed = 0, late_ticks = 0, late_active = 0, block_ticks = 0;
    for (int tick = 1; tick <= ticks; ++tick) {
        const auto start = std::chrono::steady_clock::now();
        const auto stats = world.tick();
        times.push_back(std::chrono::duration<double, std::micro>(
                            std::chrono::steady_clock::now() - start).count());
        block_ticks += stats.active_blocks_after;
        if (!sleep_tick && stats.active_blocks_after == 0) sleep_tick = tick;
        if (sleep_tick && stats.active_blocks_after != 0) sleep_tick = 0;
        static const bool lab_fast = std::getenv("LAB_FAST") != nullptr;
        if (!lab_fast) sample();
        if (tick > ticks * 3 / 4) {
            late_changed += changed;
            late_active += stats.active_blocks_after;
            ++late_ticks;
        }
        std::uint64_t lo = ~std::uint64_t{0}, hi = 0;
        for (std::int64_t x = 1; x < width - 1 && !lab_fast; ++x) {
            if (x >= skip0 && x < skip1) continue;
            const auto column = column_mass(x);
            lo = std::min(lo, column); hi = std::max(hi, column);
        }
        spread = static_cast<double>(hi - lo) / 255.0;
        if (!level_tick && spread <= 1.0) level_tick = tick;
        if (level_tick && spread > 1.0) level_tick = 0;
        if (png && std::find(frames.begin(), frames.end(), tick) != frames.end()) dump(tick);
        if (png && smooth && std::find(frames.begin(), frames.end(), tick + 1) != frames.end()) present(prev_mass);
        if (const char* rowenv = std::getenv("LAB_ROW"); rowenv && std::find(frames.begin(), frames.end(), tick) != frames.end()) {
            const std::int64_t ry = std::atoi(rowenv);
            std::printf("  row %lld t=%d flow/over:", static_cast<long long>(ry), tick);
            for (std::int64_t x = 20; x < width - 1; x += 12) {
                const auto bits = spare_bits(world, x, ry);
                std::printf(" %d/%d", static_cast<int>(static_cast<std::int8_t>((bits >> 40) & 255)),
                            static_cast<int>((bits >> 48) & 255));
            }
            std::printf("\n");
        }
        if (std::getenv("LAB_KEEP") && tick == ticks) {
            for (std::int64_t y = 0; y < height; ++y)
                for (std::int64_t x = 0; x < width; ++x) {
                    if (world.stored_material(x, y) != Material::Water) continue;
                    const auto bits = spare_bits(world, x, y);
                    const int f = static_cast<std::int8_t>((bits >> 40) & 255), o = static_cast<int>((bits >> 48) & 255);
                    if (f || o) std::printf("  keep %lld,%lld m=%u f=%d o=%d\n", (long long)x, (long long)y, world.liquid_mass(x, y), f, o);
                }
        }
        static const int lab_every = std::getenv("LAB_EVERY") ? std::atoi(std::getenv("LAB_EVERY")) : 0;
        if (!quiet && tick % (lab_every > 0 ? lab_every : ticks / 10 == 0 ? 1 : ticks / 10) == 0) {
            std::printf("  t=%5d spread=%7.2f us=%8.0f visited=%6llu blocks=%4llu changed=%6llu", tick, spread, times.back(),
                        static_cast<unsigned long long>(stats.visited_cells),
                        static_cast<unsigned long long>(stats.active_blocks_after),
                        static_cast<unsigned long long>(changed));
            if (scenario == "strokes") {
                std::int64_t lo = 1 << 30, hi = 0;
                for (std::int64_t x = 100; x < 340; ++x) {
                    std::int64_t col = 0;
                    for (std::int64_t y = 150; y < height - 1; ++y) col += world.liquid_mass(x, y);
                    lo = std::min(lo, col); hi = std::max(hi, col);
                }
                std::printf(" pool_roughness=%.2f", static_cast<double>(hi - lo) / 255.0);
            }
            if (scenario == "bell" || scenario == "chamber" || scenario == "dome") {
                const std::int64_t cx = scenario == "bell" ? 260 : scenario == "dome" ? 210 : 300;
                std::int64_t top = height;
                for (std::int64_t y = scenario == "bell" ? 64 : scenario == "dome" ? 112 : 104; y < height - 1 && top == height; ++y)
                    if (world.liquid_mass(cx, y) > 128) top = y;
                std::printf(" inside_surface_row=%lld", static_cast<long long>(top));
            }
            if (scenario == "utube")
                std::printf(" L-R=%7.2f", (static_cast<double>(column_mass(90)) - static_cast<double>(column_mass(290))) / 255.0);
            std::printf("\n");
        }
        if (scenario == "column" && (tick == 15 || tick == 30 || tick == 60 || tick == 120 || tick == 240)) {
            // Front extent per height band: base surging out ahead of the top
            // means the right edge at the floor row exceeds that higher up.
            std::printf("  shape t=%d:", tick);
            for (std::int64_t y : {height - 2, height - 6, height - 20, height - 60, height - 120}) {
                std::int64_t right = 0;
                for (std::int64_t x = 192; x < width - 1; ++x) if (world.liquid_mass(x, y)) right = x;
                std::printf(" y%lld:+%lld", static_cast<long long>(height - 1 - y), static_cast<long long>(right - 211));
            }
            std::int64_t top = height;
            for (std::int64_t y = 0; y < height - 1 && top == height; ++y)
                if (world.liquid_mass(192, y)) top = y;
            std::printf(" centre_h=%lld\n", static_cast<long long>(height - 1 - top));
        }
    }
#ifdef LAB_SAMPLER
    if (sampling) sampler.finish();
#endif
    const auto final_mass = total_mass();
    const auto total = std::accumulate(times.begin(), times.end(), 0.0);
    auto sorted = times;
    std::sort(sorted.begin(), sorted.end());
    std::printf("{\"scenario\":\"%s\",\"workers\":%s,\"mass0\":%llu,\"mass\":%llu,\"ms_per_tick\":%.3f,"
                "\"p50_us\":%.0f,\"p95_us\":%.0f,\"block_ticks\":%llu,\"level_tick\":%d,\"sleep_tick\":%d,"
                "\"max_over\":%u,\"final_spread\":%.2f,\"late_changed\":%.1f,\"late_blocks\":%.1f,\"hash\":\"%016llx\"}\n",
                argv[1], argv[3], static_cast<unsigned long long>(initial_mass),
                static_cast<unsigned long long>(final_mass), total / 1000.0 / ticks,
                sorted[sorted.size() / 2], sorted[sorted.size() * 95 / 100],
                static_cast<unsigned long long>(block_ticks), level_tick, sleep_tick, max_over, spread,
                late_ticks ? static_cast<double>(late_changed) / late_ticks : 0.0,
                late_ticks ? static_cast<double>(late_active) / late_ticks : 0.0,
                static_cast<unsigned long long>(full_hash()));
}
