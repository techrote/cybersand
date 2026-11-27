// Compile against either evaluated checkout to time the same six-worker Oil brush.
#include <array>
#include <chrono>
#include <cstdio>

#define main wave_spill_regression_main
#include "native/tests/test_wave_spill.cpp"
#undef main

int main() {
    constexpr int width = 384, height = 160, surface = 64, radius = 24;
    World world(oil_tank_config(6));
    box(world, width + 2, height);
    rect(world, 1, surface, width, height - 1 - surface, Material::Water);
    for (int dy = -radius; dy <= radius; ++dy) {
        for (int dx = -radius; dx <= radius; ++dx) {
            if (dx * dx + dy * dy <= radius * radius)
                world.set(width / 2 + dx, surface + dy, Material::Oil);
        }
    }
    using Clock = std::chrono::steady_clock;
    std::array<double, 900> times{};
    for (auto& elapsed : times) {
        const auto start = Clock::now();
        (void)world.tick();
        elapsed = std::chrono::duration<double, std::micro>(Clock::now() - start).count();
    }
    std::sort(times.begin(), times.end());
    const auto ledger = world.quantity_ledger();
    std::printf("ticks=900 median_us=%.1f p95_us=%.1f oil=%llu water=%llu hash=%016llx\n",
        (times[449] + times[450]) / 2, times[854],
        static_cast<unsigned long long>(ledger.material_cells[static_cast<std::size_t>(Material::Oil)]),
        static_cast<unsigned long long>(ledger.water_visible + ledger.water_overfill + ledger.water_ballistic),
        static_cast<unsigned long long>(world.physical_state_hash()));
}
