// SCRIPT-HOTPATH-001: standalone Godot-independent native kernel qualification.
// Build: c++ -std=c++20 -O2 -Wall -Wextra -Werror -I native/include
//         native/tests/test_paint_fill_planner.cpp -o /tmp/test_paint_fill_planner
#include "cybersand/paint_fill_planner.hpp"

#include <cassert>
#include <cstdint>
#include <iostream>
#include <queue>
#include <random>
#include <vector>

using cybersand::paint_fill::Outcome;
using cybersand::paint_fill::plan;

int main() {
    constexpr int width = 512;
    const std::vector<std::int32_t> whole(width * width, 2);
    const auto full = plan(256, 256, 0, 0, width, width, whole.data(),
                           whole.size(), width, width, 262144);
    assert(full.outcome == Outcome::accepted);
    assert(full.indices.size() == 262144);
    assert(full.indices.front() == 0 && full.indices.back() == 262143);
    const auto full_overflow = plan(256, 256, 0, 0, width, width, whole.data(),
                                    whole.size(), width, width, 262143);
    assert(full_overflow.outcome == Outcome::budget_exceeded);
    assert(full_overflow.indices.empty());

    std::vector<std::int32_t> confined(128 * 128, 1);
    for (int y = 32; y < 96; ++y)
        for (int x = 32; x < 96; ++x) confined[y * 128 + x] = 2;
    auto bounded = plan(64, 64, 0, 0, 128, 128, confined.data(), confined.size(),
                        width, width, 4096);
    assert(bounded.outcome == Outcome::accepted && bounded.indices.size() == 4096);
    assert(bounded.indices.front() == 32 * 128 + 32);
    assert(bounded.indices.back() == 95 * 128 + 95);
    bounded = plan(64, 64, 0, 0, 128, 128, confined.data(), confined.size(),
                    width, width, 4095);
    assert(bounded.outcome == Outcome::budget_exceeded && bounded.indices.empty());

    const auto cropped = plan(64, 64, 32, 32, 128, 128, confined.data(), confined.size(),
                              width, width, 4096);
    assert(cropped.outcome == Outcome::accepted); // Component does not touch crop.
    const std::vector<std::int32_t> edge(64 * 64, 2);
    const auto unknown = plan(64, 64, 32, 32, 64, 64, edge.data(), edge.size(),
                              width, width, 4096);
    assert(unknown.outcome == Outcome::unread_edge && unknown.indices.empty());
    assert(unknown.first_unread_edge[0] != '\0');
    assert(unknown.min_x == 32 && unknown.min_y == 32);
    assert(unknown.max_x == 95 && unknown.max_y == 95);

    auto corrupt = confined;
    corrupt.back() = 10;
    assert(plan(64, 64, 0, 0, 128, 128, corrupt.data(), corrupt.size(),
                width, width, 4096).outcome == Outcome::invalid_material);
    assert(plan(64, 64, 0, 0, 128, 128, confined.data(), confined.size(),
                width, width, 0).outcome == Outcome::invalid_limit);
    assert(plan(64, 64, 0, 0, 128, 128, confined.data(), confined.size(),
                500, width, 4096).outcome == Outcome::invalid_extent);
    assert(plan(64, 64, 0, 0, 128, 128, confined.data(), confined.size() - 1,
                width, width, 4096).outcome == Outcome::size_mismatch);
    assert(plan(999, 999, 0, 0, 128, 128, confined.data(), confined.size(),
                width, width, 4096).outcome == Outcome::seed_outside);

    // Independent 4-neighbour BFS oracle, restricted to full-canvas samples
    // (no unread crop), for deterministically seeded randomized materials.
    std::mt19937 rng(20261120);
    for (int iteration = 0; iteration < 24; ++iteration) {
        std::vector<std::int32_t> materials(width * width);
        for (auto& m : materials) m = static_cast<std::int32_t>(rng() % 5);
        const int sx = static_cast<int>(rng() % width);
        const int sy = static_cast<int>(rng() % width);
        const auto actual = plan(sx, sy, 0, 0, width, width, materials.data(),
                                 materials.size(), width, width, 262144);
        assert(actual.outcome == Outcome::accepted);
        std::vector<std::uint8_t> visited(materials.size(), 0);
        std::queue<int> q;
        std::vector<int> indices;
        const int target = materials[sy * width + sx];
        q.push(sy * width + sx);
        visited[sy * width + sx] = 1;
        while (!q.empty()) {
            const int index = q.front();
            q.pop();
            indices.push_back(index);
            const int x = index % width;
            const int y = index / width;
            const int nx[] = {x - 1, x + 1, x, x};
            const int ny[] = {y, y, y - 1, y + 1};
            for (int dir = 0; dir < 4; ++dir) {
                if (nx[dir] < 0 || nx[dir] >= width ||
                    ny[dir] < 0 || ny[dir] >= width) continue;
                const int next = ny[dir] * width + nx[dir];
                if (!visited[next] && materials[next] == target) {
                    visited[next] = 1;
                    q.push(next);
                }
            }
        }
        std::sort(indices.begin(), indices.end());
        assert(indices.size() == actual.indices.size());
        for (std::size_t i = 0; i < indices.size(); ++i)
            assert(indices[i] == actual.indices[i]);
    }
    std::cout << "SCRIPT_HOTPATH_NATIVE_TEST PASS\n";
}
