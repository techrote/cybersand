// CyberSand PF gas-capacity research probe: no changes to production code.
// Source reference: techrote/cybersand, claude/water-ballistic-hybrid,
// b624e7b740a0cfc4b8ee026200d5c273c314ea6f (2026-11-06).
//
// Standalone deterministic geometry census (NO physics):
//   g++ -std=c++20 -O2 -Wall -Wextra pf_gas_capacity_probe.cpp -o pf_geometry_probe
//   ./pf_geometry_probe all > geometry_stats.csv
//
// Real native World execution (from a matching full repository checkout):
//   Copy this file to native/bench/pf_gas_capacity_probe.cpp in a disposable checkout.
//   g++ -std=c++20 -O2 -pthread -DPF_CAPACITY_ENGINE -I native/include native/src/*.cpp native/bench/pf_gas_capacity_probe.cpp -o pf_native_probe
//   (Compile against the exact branch's supported native source list/flags if
//    its build workflow prescribes a different toolchain.)
//   ./pf_native_probe all > native_stats.csv
//
// The standalone mode is NOT a native PressureFlow execution or physics model.
// Stages simulate deliberate host edits to static geometry, not cellular ticks.
// Its exhaustive grid census is independent of the 1025 early-exit preflight.

#include <algorithm>
#include <array>
#include <cstdint>
#include <exception>
#include <iostream>
#include <limits>
#include <memory>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

#ifdef PF_CAPACITY_ENGINE
#include "cybersand/pressure_setup_capacity.hpp"
#include "cybersand/liquid_solver_policy.hpp"
#include "cybersand/world.hpp"
#endif

namespace {
constexpr int kWidth = 2048, kHeight = 1024;
constexpr int kPitch = 32, kColumns = 64;
constexpr int kExtraUnseeded = 128;
constexpr std::uint32_t kVolumeLimit = 16384;
constexpr std::uint32_t kCurrentCapacity = 1024;
// Actual Material IDs checked against native/include/cybersand/material.hpp.
enum Mat : std::uint8_t {
    Empty = 0, Wall = 1, Sand = 2, Water = 3, Stone = 13,
    LimestoneBlock = 38, SandstoneBlock = 39, GraniteBlock = 40
};
struct Room { int x, y, w, h; std::uint8_t top; };

struct Summary {
    std::uint32_t closed_seeded = 0, closed_unseeded = 0;
    std::uint32_t vented_seeded = 0, exterior_unseeded = 0;
    std::uint64_t sealed_volume = 0;
    std::vector<std::uint32_t> sizes;
    std::array<std::uint32_t, 7> bins{}; // 1, 2-4, 5-8, 9-16, 17-64, 65-256, >256.
};

std::array<std::uint32_t, 7> histogram(const std::vector<std::uint32_t>& sizes) {
    std::array<std::uint32_t, 7> bins{};
    for (auto n : sizes) {
        const auto bucket = n == 1 ? 0 : n <= 4 ? 1 : n <= 8 ? 2 : n <= 16 ? 3 : n <= 64 ? 4 : n <= 256 ? 5 : 6;
        ++bins[static_cast<std::size_t>(bucket)];
    }
    return bins;
}

Summary census(std::span<const std::uint8_t> cells) {
    if (cells.size() != static_cast<std::size_t>(kWidth) * kHeight) throw std::invalid_argument("grid shape mismatch");
    Summary result;
    std::vector<std::uint8_t> seen(cells.size(), 0);
    std::vector<std::uint32_t> queue;
    queue.reserve(cells.size());
    for (std::uint32_t seed = 0; seed < cells.size(); ++seed) {
        if (cells[seed] != Empty || seen[seed]) continue;
        queue.clear();
        queue.push_back(seed);
        seen[seed] = 1;
        bool seeded = false, boundary = false;
        const auto visit = [&](std::uint32_t next) {
            if (cells[next] == Water) seeded = true;
            else if (cells[next] == Empty && !seen[next]) {
                seen[next] = 1;
                queue.push_back(next);
            }
        };
        for (std::size_t head = 0; head < queue.size(); ++head) {
            const auto index = queue[head];
            const auto x = index % kWidth, y = index / kWidth;
            boundary = boundary || x == 0 || x + 1U == kWidth || y == 0 || y + 1U == kHeight;
            if (x) visit(index - 1);
            if (x + 1U < kWidth) visit(index + 1);
            if (y) visit(index - kWidth);
            if (y + 1U < kHeight) visit(index + kWidth);
        }
        if (!boundary && queue.size() <= kVolumeLimit) {
            if (seeded) {
                ++result.closed_seeded;
                result.sealed_volume += queue.size();
                result.sizes.push_back(static_cast<std::uint32_t>(queue.size()));
            } else ++result.closed_unseeded;
        } else if (seeded) ++result.vented_seeded;
        else ++result.exterior_unseeded;
    }
    std::sort(result.sizes.begin(), result.sizes.end());
    result.bins = histogram(result.sizes);
    return result;
}

Room room_at(std::size_t index) {
    const auto hash = static_cast<std::uint32_t>(index * 2654435761U) ^
                      static_cast<std::uint32_t>((index + 17U) * 2246822519U);
    const int x = 9 + static_cast<int>(index % kColumns) * kPitch;
    const int y = 9 + static_cast<int>(index / kColumns) * kPitch;
    const int w = 1 + static_cast<int>(hash % 7U);
    const int h = 1 + static_cast<int>((hash >> 9U) % 7U);
    const auto top = static_cast<std::uint8_t>(index % 3U == 0 ? GraniteBlock : index % 3U == 1 ? LimestoneBlock : Wall);
    if (x + 19 >= kWidth || y + 19 >= kHeight) throw std::logic_error("room exceeds canvas");
    return {x, y, w, h, top};
}

#ifdef PF_CAPACITY_ENGINE
cybersand::WorldConfig pressure_config() {
    using namespace cybersand;
    WorldConfig config;
    config.chunk_size = 128;
    config.worker_threads = 1;
    config.maximum_chunk_count = 512;
    config.active_chunk_capacity = 512;
    config.active_core_capacity = 4096;
    auto request = LiquidSolverPolicy::default_request();
    request[21] = 3; // Water -> PressureFlowV1, same indexing as native PF capacity regression.
    request[22] = 0; // Reference variant.
    const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(request));
    if (!decoded.accepted()) throw std::runtime_error("PressureFlow policy admission refused");
    config.liquid_solver_policy = *decoded.policy;
    return config;
}
#endif

class Scene {
public:
    explicit Scene(int seeded_rooms)
        : seeded_(seeded_rooms), grid_(static_cast<std::size_t>(kWidth)*kHeight, Empty)
#ifdef PF_CAPACITY_ENGINE
          , world_(pressure_config())
#endif
    {
        if (seeded_rooms < 0 || seeded_rooms + kExtraUnseeded > kColumns * (kHeight / kPitch))
            throw std::invalid_argument("too many rooms");
        for (int i = 0; i < seeded_ + kExtraUnseeded; ++i) make_room(i, i < seeded_);
    }
    void set(int x, int y, std::uint8_t mat) {
        if (x < 0 || y < 0 || x >= kWidth || y >= kHeight) throw std::logic_error("out of canvas");
        grid_[static_cast<std::size_t>(y)*kWidth+x] = mat;
#ifdef PF_CAPACITY_ENGINE
        world_.set(x, y, static_cast<cybersand::Material>(mat));
#endif
    }
    void make_room(int i, bool water_floor) {
        const auto r = room_at(i);
        for (int dx = 0; dx < r.w+2; ++dx) {
            set(r.x+dx, r.y, r.top);
            set(r.x+dx, r.y+r.h+2, Wall);
            if (dx && dx < r.w+1) set(r.x+dx, r.y+r.h+1, water_floor ? Water : Wall);
        }
        for (int dy = 1; dy < r.h+2; ++dy) {
            set(r.x, r.y+dy, GraniteBlock);
            set(r.x+r.w+1, r.y+dy, SandstoneBlock);
        }
        // Inert/nonliquid framing is interspersed with movable Sand and Stone.
        // Only their enclosing barriers are relied on for initial topology.
        set(r.x+15, r.y+13, Wall);
        set(r.x+15, r.y+12, Sand);
        set(r.x+17, r.y+13, Wall);
        set(r.x+17, r.y+12, Stone);
    }
    void apply_stage(int stage) {
        if (stage == 2 || stage == 5) {
            const int first = stage == 2 ? 0 : 64;
            for (int k = first; k < first+64; ++k) {
                const auto r = room_at(static_cast<std::size_t>(seeded_+k));
                set(r.x+1, r.y+r.h+1, Water);
            }
        } else if (stage == 3 || stage == 4) {
            for (int i = 0; i < 96; ++i) {
                const auto r = room_at(static_cast<std::size_t>(i));
                set(r.x+1, r.y, stage == 3 ? static_cast<std::uint8_t>(Empty) : r.top);
            }
        } else if (stage == 6) {
            for (int i = 0; i < 40; ++i) {
                const auto r = room_at(static_cast<std::size_t>(i));
                for (int dy = 1; dy <= r.h; ++dy)
                    for (int dx = 1; dx <= r.w; ++dx) set(r.x+dx,r.y+dy,Wall);
            }
        }
    }
    const std::vector<std::uint8_t>& static_grid() const { return grid_; }
#ifdef PF_CAPACITY_ENGINE
    cybersand::World& native() { return world_; }
    std::vector<std::uint8_t> actual_grid() const {
        std::vector<std::uint8_t> actual(grid_.size());
        for (int y = 0; y < kHeight; ++y)
            for (int x = 0; x < kWidth; ++x)
                actual[static_cast<std::size_t>(y)*kWidth+x] = static_cast<std::uint8_t>(world_.get(x,y));
        return actual;
    }
#endif
private:
    int seeded_;
    std::vector<std::uint8_t> grid_;
#ifdef PF_CAPACITY_ENGINE
    cybersand::World world_;
#endif
};

std::uint32_t percentile(const std::vector<std::uint32_t>& sizes, std::uint32_t percent) {
    if (sizes.empty()) return 0;
    if (percent == 0U) return sizes.front();
    return sizes[std::min(sizes.size()-1U, (sizes.size()*percent+99U)/100U-1U)];
}

void row(const std::string& mode, const std::string& profile, int stage, const Summary& census_before,
         std::string native_live, std::string native_regions, std::string capacity_readback,
         std::string failed, std::string gas_closes, std::string native_volume,
         std::string native_min, std::string native_p50, std::string native_p95, std::string native_max,
         std::string native_volume_hist) {
    std::cout << mode << ',' << profile << ',' << stage << ',' << census_before.closed_seeded << ','
              << census_before.closed_unseeded << ',' << census_before.vented_seeded << ','
              << census_before.exterior_unseeded << ',' << census_before.sealed_volume << ','
              << percentile(census_before.sizes, 0) << ',' << percentile(census_before.sizes, 50) << ','
              << percentile(census_before.sizes, 95) << ',' << percentile(census_before.sizes, 100);
    for (auto v : census_before.bins) std::cout << ',' << v;
    std::cout << ',' << (census_before.closed_seeded > kCurrentCapacity ? "true" : "false")
              << ',' << native_live << ',' << native_regions << ',' << capacity_readback << ','
              << failed << ',' << gas_closes << ',' << native_volume << ',' << native_min << ','
              << native_p50 << ',' << native_p95 << ',' << native_max << ','
              << native_volume_hist << '\n';
}

void execute_profile(const std::string& name, int n) {
    Scene scene(n);
    for (int stage = 0; stage <= 6; ++stage) {
        if (stage) scene.apply_stage(stage);
#ifdef PF_CAPACITY_ENGINE
        auto before = census(scene.actual_grid());
        auto& world = scene.native();
        std::string preflight = "NA", live="NA", regions="NA", failure="false", closes="NA";
        std::string gas_volume="NA", gas_min="NA", gas_p50="NA", gas_p95="NA", gas_max="NA", gas_hist="NA";
        if (stage == 0) {
            const auto found = cybersand::initial_pressure_capacity(world,{0,0,kWidth,kHeight},2048U);
            preflight = std::to_string(found.compartments);
            row("engine_pre_tick",name,stage,before,live,regions,preflight,failure,closes,
                gas_volume,gas_min,gas_p50,gas_p95,gas_max,gas_hist);
            continue;
        }
        try { (void)world.tick(); }
        catch (const std::exception& e) {
            failure = world.has_failed() ? "true" : "unexpected_error";
            std::cerr << "World tick " << stage << " refused for " << name << ": " << e.what() << '\n';
            row("engine_pre_tick",name,stage,before,live,regions,preflight,failure,closes,
                gas_volume,gas_min,gas_p50,gas_p95,gas_max,gas_hist);
            break; // Must not retry or continue an already-failed World.
        }
        const auto actual = world.gas_compartments();
        live = std::to_string(actual.size());
        std::vector<std::uint32_t> volumes;
        std::uint64_t total_volume = 0;
        for (const auto& gas : actual) {
            total_volume += gas.volume;
            volumes.push_back(static_cast<std::uint32_t>(gas.volume));
        }
        std::sort(volumes.begin(), volumes.end());
        gas_volume = std::to_string(total_volume);
        gas_min = std::to_string(percentile(volumes, 0));
        gas_p50 = std::to_string(percentile(volumes, 50));
        gas_p95 = std::to_string(percentile(volumes, 95));
        gas_max = std::to_string(percentile(volumes, 100));
        const auto bins = histogram(volumes);
        gas_hist = std::to_string(bins[0]);
        for (std::size_t i = 1; i < bins.size(); ++i)
            gas_hist += "|" + std::to_string(bins[i]);
        regions = std::to_string(world.pressure_flow_diagnostics().gas_regions);
        const auto ledger = world.gas_ledger();
        closes = ledger.amount_live + ledger.vented + ledger.collapsed == ledger.created + ledger.absorbed ? "true" : "false";
        row("engine_pre_tick",name,stage,before,live,regions,preflight,failure,closes,
                gas_volume,gas_min,gas_p50,gas_p95,gas_max,gas_hist);
#else
        auto before = census(scene.static_grid());
        row("geometry_only",name,stage,before,"NA","NA","NA","NA","NA","NA","NA","NA","NA","NA","NA");
#endif
    }
}
} // namespace

int main(int argc, char** argv) {
    try {
        std::cout << "mode,profile,stage,seeded_closed,unseeded_closed,vented_seeded,unseeded_exterior,"
                     "sealed_volume,min,p50,p95,max,vol1,vol2to4,vol5to8,vol9to16,vol17to64,vol65to256,volover256,"
                     "geometry_exceeds_1024,native_live,gas_regions,native_initial_preflight_count,native_failed,gas_ledger_closes,"
                     "native_volume,native_min,native_p50,native_p95,native_max,native_volume_hist_1_2to4_5to8_9to16_17to64_65to256_gt256\n";
        const std::string mode = argc >= 2 ? argv[1] : "all";
        if (mode == "near" || mode == "all") execute_profile("near",960);
        if (mode == "boundary" || mode == "all") execute_profile("boundary",1024);
        if (mode == "excess" || mode == "all") execute_profile("excess",1280);
        if (mode != "near" && mode != "boundary" && mode != "excess" && mode != "all")
            throw std::invalid_argument("profiles: near, boundary, excess, all");
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "probe error: " << e.what() << '\n';
        return 1;
    }
}