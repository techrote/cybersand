#include "cybersand/world.hpp"

#include <algorithm>
#include <array>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <deque>
#include <iomanip>
#include <iostream>
#include <limits>
#include <numeric>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

using namespace cybersand;

namespace {

struct Fixture {
    std::string id;
    int max_x = 0;
    int max_y = 0;
    int floor_y = 0;
};

struct Scan {
    std::uint64_t quantity = 0;
    std::uint64_t occupied = 0;
    std::uint64_t partial = 0;
    std::int64_t com_x_num = 0;
    int min_wet_x = 0;
    int max_wet_x = 0;
    std::uint64_t downstream = 0;
    std::uint64_t left = 0;
    std::uint64_t right = 0;
    std::uint64_t wall_gap = 0;
    std::uint64_t wall_gap_max_run = 0;
    std::uint64_t components = 0;
    std::uint64_t small_components = 0;
    std::vector<std::uint64_t> columns;
};

struct Transform {
    int shift_x = 0;
    int shift_y = 0;
    int max_x = 0;
    bool mirror = false;

    [[nodiscard]] std::int64_t x(int local) const noexcept {
        return static_cast<std::int64_t>(shift_x + (mirror ? max_x - local : local));
    }
    [[nodiscard]] std::int64_t y(int local) const noexcept {
        return static_cast<std::int64_t>(shift_y + local);
    }
};

Fixture fixture_meta(std::string_view id) {
    if (id == "r8" || id == "r24" || id == "r40") return {std::string(id), 159, 79, 72};
    if (id == "cp16") return {std::string(id), 127, 79, 72};
    if (id == "ut96_48") return {std::string(id), 127, 119, 116};
    if (id == "cn") return {std::string(id), 143, 79, 72};
    if (id == "fd") return {std::string(id), 127, 95, 88};
    if (id == "cs") return {std::string(id), 127, 95, 88};
    if (id == "ls") return {std::string(id), 127, 111, 104};
    throw std::invalid_argument("unknown fixture");
}

std::array<std::uint64_t, 18> event_totals(const World& world) {
    std::array<std::uint64_t, 18> result{};
    const auto* totals = world.physics_diagnostics();
    if (totals == nullptr) return result;
    if (totals->overflow != 0) throw std::runtime_error("physics histogram overflow");
    for (const auto& entry : totals->entries) {
        if (entry.key == 0) continue;
        const auto kind = static_cast<std::size_t>(entry.key >> 24U);
        if (kind < result.size()) result[kind] += entry.count;
    }
    return result;
}

void print_u64_array(const std::vector<std::uint64_t>& values) {
    std::cout << '[';
    for (std::size_t i = 0; i < values.size(); ++i) {
        if (i) std::cout << ',';
        std::cout << values[i];
    }
    std::cout << ']';
}

void print_events(const std::array<std::uint64_t, 18>& values) {
    std::cout << '[';
    for (std::size_t i = 0; i < values.size(); ++i) {
        if (i) std::cout << ',';
        std::cout << values[i];
    }
    std::cout << ']';
}

}  // namespace

int main(int argc, char** argv) {
    try {
        if (argc != 9) {
            std::cerr << "fixture shift_x shift_y mirror workers observer horizon mode\n";
            return 2;
        }
        const Fixture fixture = fixture_meta(argv[1]);
        const int shift_x = std::stoi(argv[2]);
        const int shift_y = std::stoi(argv[3]);
        const bool mirror = std::stoi(argv[4]) != 0;
        const unsigned workers = static_cast<unsigned>(std::stoul(argv[5]));
        const bool observer = std::stoi(argv[6]) != 0;
        const int horizon = std::stoi(argv[7]);
        const std::string mode = argv[8];
        if (workers == 0 || horizon < 1 ||
            (mode != "trace" && mode != "verify" && mode != "timing")) {
            throw std::invalid_argument("invalid argument");
        }

        Transform tr{shift_x, shift_y, fixture.max_x, mirror};
        WorldConfig config;
        config.worker_threads = workers;
        config.parallel_job_threshold = 1;
        config.maximum_chunk_count = 128;
        config.active_chunk_capacity = 128;
        config.active_core_capacity = 1024;
        config.physics_diagnostics.enabled = observer;
        config.water_experiment_policy = WaterExperimentPolicy{8U, 12U};

        World world(config);
        const RectI64 region{
            static_cast<std::int64_t>(shift_x - 192),
            static_cast<std::int64_t>(shift_y - 192),
            static_cast<std::int64_t>(fixture.max_x + 385),
            static_cast<std::int64_t>(fixture.max_y + 385)};
        world.reserve_region(region);
        world.set_simulation_region(region);

        const auto put = [&](int x, int y, Material m) { world.set(tr.x(x), tr.y(y), m); };
        const auto water = [&](int x, int y) {
            if (!world.set_cell_state(tr.x(x), tr.y(y), Material::Water, 255U, 0U))
                throw std::runtime_error("failed Water construction");
        };
        const auto wall_h = [&](int x0, int x1, int y) {
            for (int x = x0; x <= x1; ++x) put(x, y, Material::Wall);
        };
        const auto wall_v = [&](int x, int y0, int y1) {
            for (int y = y0; y <= y1; ++y) put(x, y, Material::Wall);
        };
        const auto fill_rect = [&](int x0, int x1, int y0, int y1) {
            for (int y = y0; y <= y1; ++y)
                for (int x = x0; x <= x1; ++x) water(x, y);
        };

        if (fixture.id == "r8" || fixture.id == "r24" || fixture.id == "r40") {
            wall_h(0, 159, 72); wall_v(0, 0, 72); wall_v(159, 0, 72);
            for (int y = 24; y <= 67; ++y) put(48, y, Material::Wall);
            const int depth = fixture.id == "r8" ? 8 : fixture.id == "r24" ? 24 : 40;
            fill_rect(4, 47, 72 - depth, 71);
        } else if (fixture.id == "cp16") {
            wall_h(0, 127, 72); wall_v(0, 0, 72); wall_v(127, 0, 72);
            for (int y = 24; y <= 67; ++y) put(64, y, Material::Wall);
            fill_rect(8, 55, 40, 71);
            fill_rect(72, 119, 56, 71);
        } else if (fixture.id == "ut96_48") {
            wall_h(35, 92, 116);
            wall_v(35, 19, 115); wall_v(44, 19, 106);
            wall_v(83, 19, 106); wall_v(92, 19, 115);
            wall_h(44, 83, 107);
            fill_rect(36, 91, 108, 115);
            fill_rect(36, 43, 20, 107);
            fill_rect(84, 91, 68, 107);
        } else if (fixture.id == "cn") {
            wall_h(0, 143, 72); wall_v(0, 0, 72); wall_v(143, 0, 72);
            wall_h(64, 79, 66);
            wall_h(64, 79, 72);
            wall_v(64, 24, 65);
            wall_v(79, 24, 65);
            fill_rect(4, 63, 40, 71);
        } else if (fixture.id == "fd") {
            wall_h(0, 127, 88); wall_v(0, 0, 88); wall_v(127, 0, 88);
            wall_v(32, 24, 87);
            fill_rect(8, 31, 32, 87);
        } else if (fixture.id == "cs") {
            wall_h(0, 127, 88); wall_v(0, 0, 88); wall_v(127, 0, 88);
            fill_rect(40, 79, 40, 87);
        } else if (fixture.id == "ls") {
            wall_h(0, 127, 104); wall_v(0, 0, 104); wall_v(127, 0, 104);
            wall_h(0, 63, 56);
            fill_rect(40, 63, 32, 55);
        }

        bool wall_contact_seen = false;
        auto scan = [&](bool components) {
            Scan s;
            s.columns.assign(static_cast<std::size_t>(fixture.max_x + 1), 0U);
            std::vector<unsigned char> wet(static_cast<std::size_t>((fixture.max_x + 1) * (fixture.max_y + 1)), 0U);
            bool any = false;
            s.min_wet_x = fixture.max_x + 1;
            s.max_wet_x = -1;
            for (int y = 0; y <= fixture.max_y; ++y) {
                for (int x = 0; x <= fixture.max_x; ++x) {
                    const auto mass = static_cast<std::uint64_t>(world.liquid_mass(tr.x(x), tr.y(y)));
                    if (!mass) continue;
                    any = true;
                    s.quantity += mass;
                    ++s.occupied;
                    if (mass < 255U) ++s.partial;
                    s.columns[static_cast<std::size_t>(x)] += mass;
                    s.com_x_num += static_cast<std::int64_t>(mass) * x;
                    s.min_wet_x = std::min(s.min_wet_x, x);
                    s.max_wet_x = std::max(s.max_wet_x, x);
                    wet[static_cast<std::size_t>(y * (fixture.max_x + 1) + x)] = 1U;
                    if ((fixture.id == "r8" || fixture.id == "r24" || fixture.id == "r40") && x >= 49 && x <= 155) s.downstream += mass;
                    if (fixture.id == "cn" && x >= 80 && x <= 139) s.downstream += mass;
                    if (fixture.id == "fd" && x >= 33 && x <= 123) s.downstream += mass;
                    if (fixture.id == "ls" && x >= 64 && x <= 123 && y >= 57) s.downstream += mass;
                    if (fixture.id == "cp16") {
                        if (x >= 8 && x <= 55) s.left += mass;
                        if (x >= 72 && x <= 119) s.right += mass;
                    }
                    if (fixture.id == "ut96_48") {
                        if (x >= 36 && x <= 43) s.left += mass;
                        if (x >= 84 && x <= 91) s.right += mass;
                    }
                }
            }
            if (!any) { s.min_wet_x = 0; s.max_wet_x = 0; }

            if (fixture.id == "fd") {
                int top = fixture.max_y + 1;
                bool contact = false;
                for (int y = 0; y <= 87; ++y) {
                    for (int x = 122; x <= 126; ++x) {
                        if (world.liquid_mass(tr.x(x), tr.y(y)) != 0U) top = std::min(top, y);
                    }
                    if (world.liquid_mass(tr.x(126), tr.y(y)) != 0U) contact = true;
                }
                wall_contact_seen = wall_contact_seen || contact;
                if (wall_contact_seen && top <= 87) {
                    std::uint64_t run = 0;
                    for (int y = top; y <= 87; ++y) {
                        if (world.liquid_mass(tr.x(126), tr.y(y)) == 0U &&
                            world.get(tr.x(126), tr.y(y)) == Material::Empty) {
                            ++s.wall_gap;
                            ++run;
                            s.wall_gap_max_run = std::max(s.wall_gap_max_run, run);
                        } else {
                            run = 0;
                        }
                    }
                }
            }

            if (components) {
                std::vector<unsigned char> seen(wet.size(), 0U);
                constexpr int dx[4] = {1, -1, 0, 0};
                constexpr int dy[4] = {0, 0, 1, -1};
                for (int y = 0; y <= fixture.max_y; ++y) {
                    for (int x = 0; x <= fixture.max_x; ++x) {
                        const auto start = static_cast<std::size_t>(y * (fixture.max_x + 1) + x);
                        if (!wet[start] || seen[start]) continue;
                        ++s.components;
                        std::uint64_t count = 0;
                        std::deque<std::pair<int,int>> q;
                        q.push_back({x,y}); seen[start] = 1U;
                        while (!q.empty()) {
                            const auto [cx,cy] = q.front(); q.pop_front(); ++count;
                            for (int k = 0; k < 4; ++k) {
                                const int nx = cx + dx[k], ny = cy + dy[k];
                                if (nx < 0 || ny < 0 || nx > fixture.max_x || ny > fixture.max_y) continue;
                                const auto idx = static_cast<std::size_t>(ny * (fixture.max_x + 1) + nx);
                                if (wet[idx] && !seen[idx]) { seen[idx] = 1U; q.push_back({nx,ny}); }
                            }
                        }
                        if (count <= 16U) ++s.small_components;
                    }
                }
            }
            return s;
        };

        const Scan initial = scan(mode == "trace" && fixture.id == "ls");
        const std::uint64_t initial_quantity = initial.quantity;
        if (initial_quantity == 0U) throw std::runtime_error("empty fixture");

        std::cout << "{\"metadata\":true,\"fixture\":\"" << fixture.id
                  << "\",\"shift_x\":" << shift_x << ",\"shift_y\":" << shift_y
                  << ",\"mirror\":" << (mirror ? 1 : 0) << ",\"workers\":" << workers
                  << ",\"observer\":" << (observer ? 1 : 0) << ",\"horizon\":" << horizon
                  << ",\"mode\":\"" << mode << "\",\"mass_max\":255,\"initial_quantity\":"
                  << initial_quantity << "}\n";

        const std::array<int, 12> checkpoints{0,1,10,30,60,120,240,480,900,1200,1800,horizon};
        const auto is_checkpoint = [&](int tick) {
            return std::find(checkpoints.begin(), checkpoints.end(), tick) != checkpoints.end();
        };

        auto emit = [&](int tick, const TickStats* stats, double tick_us, bool full) {
            Scan s = scan(full && mode == "trace" && fixture.id == "ls");
            if (s.quantity != initial_quantity)
                throw std::runtime_error("Water conservation failure");
            std::cout << "{\"tick\":" << tick
                      << ",\"quantity\":" << s.quantity;
            if (mode != "trace" || is_checkpoint(tick)) {
                std::cout << ",\"content\":\"" << std::hex << world.content_hash() << std::dec << "\"";
            }
            std::cout << ",\"occupied\":" << s.occupied
                      << ",\"partial\":" << s.partial
                      << ",\"com_x_num\":" << s.com_x_num
                      << ",\"min_wet_x\":" << s.min_wet_x
                      << ",\"max_wet_x\":" << s.max_wet_x
                      << ",\"downstream\":" << s.downstream
                      << ",\"left\":" << s.left
                      << ",\"right\":" << s.right
                      << ",\"wall_gap\":" << s.wall_gap
                      << ",\"wall_gap_max_run\":" << s.wall_gap_max_run
                      << ",\"components\":" << s.components
                      << ",\"small_components\":" << s.small_components;
            if (stats != nullptr) {
                std::cout << ",\"visited\":" << stats->visited_cells
                          << ",\"moved\":" << stats->moved_cells
                          << ",\"active_blocks\":" << stats->active_blocks_after
                          << ",\"scheduled_cores\":" << stats->scheduled_cores;
            }
            if (tick_us >= 0.0) std::cout << ",\"tick_us\":" << std::fixed << std::setprecision(3) << tick_us;
            if (observer && (mode != "trace" || is_checkpoint(tick))) {
                std::cout << ",\"events\":";
                print_events(event_totals(world));
            }
            if (full) { std::cout << ",\"columns\":"; print_u64_array(s.columns); }
            std::cout << "}\n";
        };

        if (mode != "timing") emit(0, nullptr, -1.0, mode == "trace");
        std::vector<double> timings;
        timings.reserve(static_cast<std::size_t>(horizon));

        for (int tick = 1; tick <= horizon; ++tick) {
            if (fixture.id == "fd" && tick == 1) {
                for (int y = 40; y <= 87; ++y) put(32, y, Material::Empty);
            }
            const auto start = mode == "timing"
                ? std::chrono::steady_clock::now()
                : std::chrono::steady_clock::time_point{};
            const TickStats stats = world.tick();
            const double elapsed = mode == "timing"
                ? std::chrono::duration<double, std::micro>(
                    std::chrono::steady_clock::now() - start).count()
                : -1.0;
            if (stats.chunk_allocations != 0U || stats.temperature_field_allocations != 0U)
                throw std::runtime_error("unprepared allocation");
            if (mode == "timing") {
                if (tick > 120) timings.push_back(elapsed);
                if (is_checkpoint(tick)) emit(tick, &stats, elapsed, false);
            } else if (mode == "trace") {
                emit(tick, &stats, elapsed, true);
            } else if (is_checkpoint(tick)) {
                emit(tick, &stats, elapsed, false);
            }
        }

        const Scan final = scan(false);
        if (final.quantity != initial_quantity) throw std::runtime_error("final Water conservation failure");
        std::cout << "{\"result\":true,\"fixture\":\"" << fixture.id
                  << "\",\"quantity\":" << final.quantity
                  << ",\"content\":\"" << std::hex << world.content_hash() << std::dec << "\"";
        if (!timings.empty()) {
            std::sort(timings.begin(), timings.end());
            const auto at = [&](double q) {
                const auto index = static_cast<std::size_t>(q * static_cast<double>(timings.size() - 1));
                return timings[index];
            };
            const double total = std::accumulate(timings.begin(), timings.end(), 0.0);
            std::cout << ",\"total_us\":" << std::fixed << std::setprecision(3) << total
                      << ",\"p50_us\":" << at(0.50)
                      << ",\"p95_us\":" << at(0.95)
                      << ",\"p99_us\":" << at(0.99)
                      << ",\"max_us\":" << timings.back();
        }
        if (observer) { std::cout << ",\"events\":"; print_events(event_totals(world)); }
        std::cout << "}\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr << e.what() << '\n';
        return 1;
    }
}
