// WB-AGENT-002 (#527): preregistered native Sand-hopper CONTROL, not an agent/tool test.
// Reads the immutable v1 recipe; performs real cybersand::World ticks and stores
// negative as well as positive results. No Godot, mocked World, API or physics edits.
#include "cybersand/world.hpp"

#include <algorithm>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <set>
#include <sstream>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace {
using cybersand::Material;
using cybersand::World;
using cybersand::WorldConfig;
constexpr int kTotalTicks = 480;
constexpr int kExpectedSand = 32;
using Cell = std::pair<int,int>;

struct Operation {
    std::string variant, phase, shape;
    int a = 0, b = 0, c = 0, d = 0;
};

void need(bool condition, const std::string& reason) {
    if (!condition) throw std::runtime_error(reason);
}

std::vector<Operation> read_recipe(const std::string& path) {
    std::ifstream stream(path);
    need(bool(stream), "fixture_file_missing");
    std::vector<Operation> result;
    std::string line;
    for (int number = 1; std::getline(stream,line); ++number) {
        if (line.empty() || line[0] == '#') continue;
        std::istringstream fields(line);
        Operation op;
        std::string excess;
        need(bool(fields >> op.variant >> op.phase >> op.shape
                         >> op.a >> op.b >> op.c >> op.d) &&
             !(fields >> excess), "malformed_fixture_line_" + std::to_string(number));
        need(op.variant == "both" || op.variant == "normal" || op.variant == "revised",
             "unknown_fixture_variant");
        need(op.phase == "manual_wall" || op.phase == "protected_wall" ||
             op.phase == "initial_sand" || op.phase == "agent_wall" ||
             op.phase == "agent_empty" || op.phase == "target", "unknown_fixture_phase");
        need(op.shape == "rect" || op.shape == "wedge_right" ||
             op.shape == "wedge_left", "unknown_fixture_shape");
        need(op.d > 0 && op.d <= 128, "invalid_fixture_height");
        result.push_back(op);
    }
    need(!result.empty(), "empty_fixture");
    return result;
}

template<class Fn>
void cells(const Operation& op, Fn&& visit) {
    if (op.shape == "rect") {
        need(op.c > 0 && op.c <= 128, "invalid_fixture_width");
        for (int y = op.b; y < op.b + op.d; ++y)
            for (int x = op.a; x < op.a + op.c; ++x) visit(x,y);
    } else if (op.shape == "wedge_right") {
        for (int row = 0; row < op.d; ++row)
            for (int x = op.a; x <= op.c + row; ++x) visit(x, op.b+row);
    } else {
        for (int row = 0; row < op.d; ++row)
            for (int x = op.c-row; x <= op.a; ++x) visit(x, op.b+row);
    }
}

bool applies(const Operation& op, const std::string& variant) {
    return op.variant == "both" || op.variant == variant;
}

int sand_count(const World& world) {
    int count = 0;
    // This domain contains the entire declared apparatus with substantial
    // spill margin. Escape is an acceptance failure, not clipped as success.
    for (int y = -24; y < 72; ++y)
        for (int x = -96; x < 96; ++x)
            count += (world.stored_material(x,y) == Material::Sand ? 1 : 0);
    return count;
}

int target_count(const World& world, const Operation& target) {
    int count = 0;
    cells(target,[&](int x,int y) {
        count += (world.stored_material(x,y) == Material::Sand ? 1 : 0);
    });
    return count;
}

struct Report { int caught = 0, initial = 0, after_author = 0, total = 0;
                int protected_cells = 0, agent_writes = 0;
                std::uint32_t max_workers = 0;
                std::uint64_t completed = 0; };

Report run_control(const std::vector<Operation>& recipe, const std::string& variant,
                   int workers) {
    WorldConfig config;
    config.worker_threads = static_cast<std::uint32_t>(workers);
    // Keep the Current default backend/solver/physics, no transient bodies.
    World world(config);
    Report report;
    std::set<Cell> protection;
    const Operation* target = nullptr;

    // The pre-agent authored start. Every Sand cell is authored manually here,
    // and NO agent-controlled step may create Sand or replace any occupied Sand.
    for (const std::string& phase : {"manual_wall","protected_wall","initial_sand"}) {
        for (const auto& op : recipe) {
            if (!applies(op,variant) || op.phase != phase) continue;
            need(op.shape == "rect", "authored_start_requires_literal_rectangles");
            cells(op,[&](int x,int y) {
                need(x >= -96 && x < 96 && y >= -24 && y < 72,
                     "authored_start_out_of_bounds");
                if (phase == "initial_sand") {
                    need(world.stored_material(x,y) == Material::Empty,
                         "initial_Sand_collides_with_wall");
                    world.set(x,y,Material::Sand);
                } else {
                    need(world.stored_material(x,y) != Material::Sand,
                         "author_start_overwrites_Sand");
                    world.set(x,y,Material::Wall);
                    if (phase == "protected_wall") protection.insert({x,y});
                }
            });
        }
    }
    report.initial = sand_count(world);
    need(report.initial == kExpectedSand, "not_exactly_32_native_initial_Sand");
    need(!protection.empty(), "missing_protected_wall_motif");

    // Reference construction is permitted Hard Wall / Empty only. Every
    // individual cell is checked against actual authoritative native storage.
    for (const std::string& phase : {"agent_wall","agent_empty"}) {
        for (const auto& op : recipe) {
            if (!applies(op,variant) || op.phase != phase) continue;
            cells(op,[&](int x,int y) {
                need(x >= -96 && x < 96 && y >= -24 && y < 72,
                     "agent_edit_out_of_bounds");
                need(protection.count({x,y}) == 0, "agent_touches_protected_motif");
                need(world.stored_material(x,y) != Material::Sand,
                     "agent_edit_would_replace_native_Sand");
                if (phase == "agent_empty")
                    need(world.stored_material(x,y) == Material::Wall,
                         "opening_is_not_existing_Hard_Wall");
                world.set(x,y,phase == "agent_wall" ? Material::Wall : Material::Empty);
                ++report.agent_writes;
            });
        }
    }
    report.after_author = sand_count(world);
    need(report.after_author == kExpectedSand, "agent_manufactured_or_erased_Sand");
    for (const auto& op : recipe) {
        if (!applies(op,variant) || op.phase != "target") continue;
        need(target == nullptr && op.shape == "rect", "multiple_or_nonrect_catchments");
        target = &op;
    }
    need(target != nullptr, "missing_target");

    // Real World::tick() calls only. The 480 steps are the frozen TOTAL
    // allowance, not a 120-step-per-call loophole for repeated experiments.
    for (int tick = 1; tick <= kTotalTicks; ++tick) {
        const auto stats = world.tick();
        need(!world.has_failed(), "native_World_failed");
        need(world.completed_tick_index() == static_cast<std::uint64_t>(tick),
             "not_exactly_one_native_completed_tick");
        report.max_workers = std::max(report.max_workers,stats.worker_threads_observed);
        if (tick % 40 == 0) {
            std::cout << "SAMPLE variant=" << variant << " configured_workers=" << workers
                      << " tick=" << tick << " catchment=" << target_count(world,*target)
                      << " total=" << sand_count(world) << '\n';
        }
    }
    report.completed = world.completed_tick_index();
    report.caught = target_count(world,*target);
    report.total = sand_count(world);
    for (const auto& pos : protection) {
        need(world.stored_material(pos.first,pos.second) == Material::Wall,
             "protected_wall_changed");
        ++report.protected_cells;
    }
    return report;
}
}

int main(int argc, char** argv) {
    const std::string path = argc == 2 ? argv[1] :
        "native/tests/fixtures/wb_agent_sand_hopper_v1.tsv";
    if (argc > 2) { std::cerr << "usage: test_wb_agent_sand_hopper [fixture.tsv]\n"; return 2; }
    try {
        const auto recipe = read_recipe(path);
        int failures = 0;
        for (const auto& variant : {"normal","revised"}) for (const int workers : {1,4}) {
            try {
                const auto result = run_control(recipe,variant,workers);
                const bool positive = result.initial == 32 && result.after_author == 32 &&
                    result.total == 32 && result.caught == 32 && result.completed == kTotalTicks;
                std::cout << "RESULT variant=" << variant << " configured_workers=" << workers
                          << " total_budget=" << kTotalTicks << " completed=" << result.completed
                          << " initial=" << result.initial
                          << " after_author=" << result.after_author
                          << " total=" << result.total << " catchment=" << result.caught
                          << " protected=" << result.protected_cells
                          << " agent_wall_empty_writes=" << result.agent_writes
                          << " actual_worker_max=" << result.max_workers
                          << " outcome=" << (positive ? "PASS" : "HOLD") << '\n';
                failures += !positive;
            } catch (const std::exception& e) {
                std::cout << "RESULT variant=" << variant
                          << " configured_workers=" << workers
                          << " total_budget=" << kTotalTicks
                          << " outcome=HOLD reason=" << e.what() << '\n';
                ++failures;
            }
        }
        std::cout << "WB_AGENT_527_NATIVE_CONTROL failures=" << failures << '\n';
        return failures ? 1 : 0;
    } catch (const std::exception& e) {
        std::cerr << "WB_AGENT_527_NATIVE_CONTROL setup_failure=" << e.what() << '\n';
        return 2;
    }
}
