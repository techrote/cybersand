#include "cybersand/ejection_search.hpp"
#include <array>
#include <cassert>
#include <iostream>
#include <random>
#include <tuple>
#include <vector>

namespace {
using namespace cybersand::ejection;
using Grid = std::array<Cell, 32 * 32>;
using Trace = std::vector<std::tuple<int, int, Reason>>;
Cell read(const Grid& grid, Point p) {
    return p.x < 0 || p.y < 0 || p.x >= 32 || p.y >= 32 ? Cell{} : grid[std::size_t(p.y * 32 + p.x)];
}
// Literal pre-extraction algorithm; it deliberately does not call path_reason.
template<class Candidate>
Point historical(const Grid& grid, Point source, int first, Candidate candidate, Trace& trace) {
    for (int distance = first; distance <= first + 8; ++distance) {
        for (int probe = 0; probe < 9; ++probe) {
            const auto magnitude = (probe + 1) / 2;
            const int offset = probe == 0 ? 0 : ((probe & 1) ? magnitude : -magnitude);
            const auto p = candidate(distance, offset);
            const auto cell = read(grid, p);
            Reason reason = Reason::Accepted;
            if (!cell.in_bounds) reason = Reason::Bounds;
            else if (cell.body != 0) reason = cell.body == 1 ? Reason::SourceBody : Reason::ForeignBody;
            else if (!cell.empty) reason = Reason::NonEmpty;
            else {
                const int dx = p.x - source.x, dy = p.y - source.y;
                const int samples = std::max(std::abs(dx), std::abs(dy)) * 2;
                for (int sample = 1; sample < samples; ++sample) {
                    const Point step{source.x + int(std::floor(double(dx * sample) / samples + 0.5)),
                                     source.y + int(std::floor(double(dy * sample) / samples + 0.5))};
                    const auto through = read(grid, step);
                    if (!through.in_bounds) { reason = Reason::PathBounds; break; }
                    if (through.body != 0 && through.body != 1) { reason = Reason::PathForeign; break; }
                    if (through.hard) { reason = Reason::PathHard; break; }
                }
            }
            trace.emplace_back(p.x, p.y, reason);
            if (reason == Reason::Accepted) return p;
        }
    }
    return {};
}
}

int main() {
    Grid grid{};
    for (auto& c : grid) c = {true, true, false, 0};
    const auto at = [&](int x, int y) -> Cell& { return grid[std::size_t(y * 32 + x)]; };
    // Production paths permit movable material and own-body masks.
    at(16, 17) = {true, false, false, 1};
    assert(path_reason({16,16}, {16,19}, 1, [&](Point p) { return read(grid,p); }) == Reason::Accepted);
    at(16, 17).hard = true;
    assert(path_reason({16,16}, {16,19}, 1, [&](Point p) { return read(grid,p); }) == Reason::PathHard);
    at(16, 17) = {true, false, false, 2};
    assert(path_reason({16,16}, {16,19}, 1, [&](Point p) { return read(grid,p); }) == Reason::PathForeign);
    // Every candidate's order and exact rejection reason agree with the old
    // implementation across boundaries, rotated normals and both body classes.
    std::mt19937 random(283);
    for (int fixture = 0; fixture < 4096; ++fixture) {
        for (auto& c : grid) {
            const auto value = random() % 12;
            c = {true, value < 4, value == 4, static_cast<std::uint16_t>(value == 5 ? 1 : value == 6 ? 2 : 0)};
        }
        const auto before = grid;
        const Point source{static_cast<int>(random() % 32), static_cast<int>(random() % 32)};
        const float angle = static_cast<float>(random() % 10000) / 1000.0F;
        const float nx = std::cos(angle), ny = std::sin(angle);
        const int first = static_cast<int>(random() % 8) + 1;
        const auto candidate = [source,nx,ny](int distance, int offset) {
            const float x = (static_cast<float>(source.x) + 0.5F + nx * static_cast<float>(distance)) - ny * static_cast<float>(offset);
            const float y = (static_cast<float>(source.y) + 0.5F + ny * static_cast<float>(distance)) + nx * static_cast<float>(offset);
            return Point{int(std::floor(x)), int(std::floor(y))};
        };
        Trace extracted, original;
        const auto result = search(source, 1, first, [&](Point p) { return read(grid,p); }, candidate,
            [&](Point p, Reason reason) { extracted.emplace_back(p.x,p.y,reason); });
        const auto expected = historical(grid, source, first, candidate, original);
        assert(result.x == expected.x && result.y == expected.y && extracted == original);
        assert(extracted.size() <= 81);
        for (std::size_t i = 0; i < grid.size(); ++i)
            assert(grid[i].in_bounds == before[i].in_bounds && grid[i].empty == before[i].empty &&
                   grid[i].hard == before[i].hard && grid[i].body == before[i].body);
    }
    std::cout << "ejection search: 4096 literal differential cases and barrier controls passed\n";
}
