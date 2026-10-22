// Scratch-only: floating body mask on a pool (same crude box as the sandbox),
// checking exact mass, contact impulses and that the box floats/settles.
#include "cybersand/world.hpp"
#include <algorithm>
#include <cmath>
#include <cstdio>
using namespace cybersand;
template <class Wd> std::uint32_t hidden(const Wd& w, std::int64_t x, std::int64_t y) {
    if constexpr (requires { w.proto_hidden_mass(x, y); }) return w.proto_hidden_mass(x, y);
    else return 0;
}
int main() {
    constexpr int W = 384, H = 256, B = 16;
    World world{};
    world.reserve_region({-128, -128, W + 256, H + 256});
    world.configure_transient_obstacles({0, 0, W, H});
    for (int x = 0; x < W; ++x) { world.set(x, H - 1, Material::Wall); world.set(x, 0, Material::Wall); }
    for (int y = 0; y < H; ++y) { world.set(0, y, Material::Wall); world.set(W - 1, y, Material::Wall); }
    for (int y = H - 97; y < H - 1; ++y) for (int x = 1; x < W - 1; ++x) world.set(x, y, Material::Water);
    for (int y = 40; y < 80; ++y) for (int x = 120; x < 200; ++x) world.set(x, y, Material::Water);
    const auto mass = [&] {
        std::uint64_t m = 0;
        for (int y = 0; y < H; ++y) for (int x = 0; x < W; ++x)
            if (world.stored_material(x, y) == Material::Water) m += world.stored_state_a(x, y) + hidden(world, x, y);
        return m;
    };
    const auto m0 = mass();
    double bx = 260, by = 100, vx = 0, vy = 0;
    long long contacts = 0, sum_fx = 0;
    for (int t = 1; t <= 1500; ++t) {
        const int x0 = int(std::lround(bx)), y0 = int(std::lround(by));
        int sub = 0;
        for (int r = 0; r < B; ++r)
            sub += world.stored_material(x0 - 1, y0 + r) == Material::Water || world.stored_material(x0 + B, y0 + r) == Material::Water;
        const double fx = double(world.transient_contact_impulse_x(1)), fy = double(world.transient_contact_impulse_y(1));
        contacts += world.transient_contact_count(1); sum_fx += (long long)fx;
        vy += 0.05 - 0.1 * sub / B; vx += fx * 2e-6; vx *= 0.97; vy *= sub ? 0.9 : 0.995;
        bx = std::clamp(bx + vx, 1.0, double(W - 1 - B)); by = std::clamp(by + vy, 1.0, double(H - 1 - B));
        const int nx = int(std::lround(bx)), ny = int(std::lround(by));
        world.clear_transient_obstacles();
        for (int y = ny; y < ny + B; ++y) for (int x = nx; x < nx + B; ++x) {
            if (world.stored_material(x, y) == Material::Water)
                for (int up = ny - 1; up > 0; --up)
                    if (world.stored_material(x, up) == Material::Empty) { (void)world.relocate_stored_cell(x, y, x, up); break; }
            (void)world.set_transient_obstacle(x, y, 1);
        }
        const auto stats = world.tick();
        if (t % 150 == 0)
            std::printf("t=%4d box=(%.1f,%.1f) v=(%.2f,%.2f) submerged=%d contacts=%lld fx_sum=%lld blocks=%llu mass_delta=%lld\n", t, bx, by,
                        vx, vy, sub, contacts, sum_fx, (unsigned long long)stats.active_blocks_after, (long long)mass() - (long long)m0);
    }
}
