// Scratch-only large-scene scaling probe.
// usage: large_scene <width> <height> <ticks> <workers> <threshold> <core> <mode>
//   mode: active  - pool over the full width with a dense falling cloud (everything moving)
//         sparse  - fully settled pool world with one small splash (mostly asleep)
#include "cybersand/world.hpp"
#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>
using namespace cybersand;
int main(int argc, char** argv) {
    if (argc != 8) return 2;
    const std::int64_t W = std::atoll(argv[1]), H = std::atoll(argv[2]);
    const int ticks = std::atoi(argv[3]);
    WorldConfig c{};
    c.worker_threads = static_cast<std::uint32_t>(std::atoi(argv[4]));
    c.parallel_job_threshold = static_cast<std::size_t>(std::atoi(argv[5]));
    c.scheduling_core_size = std::atoi(argv[6]);
    c.active_core_capacity = 1 << 16;
    c.active_chunk_capacity = 1 << 14;
    const std::string mode = argv[7];
    World w(c);
    w.reserve_region({-128, -128, W + 256, H + 256});
    for (std::int64_t x = 0; x < W; ++x) w.set(x, H - 1, Material::Wall);
    for (std::int64_t y = 0; y < H; ++y) { w.set(0, y, Material::Wall); w.set(W - 1, y, Material::Wall); }
    for (std::int64_t y = H - H / 3; y < H - 1; ++y) for (std::int64_t x = 1; x < W - 1; ++x) w.set(x, y, Material::Water);
    if (mode == "active") {
        for (std::int64_t y = 4; y < H / 3; ++y) for (std::int64_t x = 2; x < W - 2; ++x)
            if (((x * 7919 + y * 104729) % 100) < 30) w.set(x, y, Material::Water);
    }
    // let the initial placement settle/sleep for the sparse case
    if (mode == "sparse") { for (int i = 0; i < 10; ++i) (void)w.tick(); for (std::int64_t y = 20; y < 60; ++y) for (std::int64_t x = W / 2; x < W / 2 + 40; ++x) w.set(x, y, Material::Water); }
    std::vector<double> t;
    std::uint64_t cores = 0, blocks = 0;
    for (int i = 0; i < ticks; ++i) {
        const auto a = std::chrono::steady_clock::now();
        const auto s = w.tick();
        t.push_back(std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - a).count());
        cores += s.scheduled_cores; blocks += s.active_blocks_after;
    }
    double sum = 0; for (double v : t) sum += v;
    std::sort(t.begin(), t.end());
    std::printf("%lldx%lld %s workers=%s thr=%s core=%s ms=%.2f p50=%.2f cores/tick=%.0f blocks/tick=%.0f chunks=%zu hash=%016llx\n",
                (long long)W, (long long)H, mode.c_str(), argv[4], argv[5], argv[6], sum / ticks, t[t.size() / 2],
                double(cores) / ticks, double(blocks) / ticks, w.chunk_count(), (unsigned long long)w.content_hash());
}
