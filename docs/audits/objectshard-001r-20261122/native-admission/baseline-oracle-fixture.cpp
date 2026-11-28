#include "cybersand/object_shard_coordinator.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdio>
#include <deque>
#include <vector>

// Independent reference: a fresh row-major World image, a deque flood fill and
// a separate visited bitmap. It does not read the production discovery cache,
// mutation journal, masks, candidate labels or rectangle decomposition.
namespace {
using namespace cybersand;
using namespace cybersand::object_shard;
std::uint64_t checks{}, failures{};
void check(bool pass, const char* expression, int line) {
    ++checks;
    if (!pass) { ++failures; std::fprintf(stderr, "FAIL %d: %s\n", line, expression); }
}
#define CHECK(value) check((value), #value, __LINE__)
struct ReferenceComponent {
    Material material{};
    std::vector<std::uint32_t> cells;
    bool anchored{}, unknown_boundary{};
};
std::vector<ReferenceComponent> reference_components(const Coordinator& coordinator) {
    const auto bounds = coordinator.config().world_bounds;
    std::vector<Material> image(bounds.area());
    std::vector<bool> visited(image.size());
    for (std::size_t index = 0; index < image.size(); ++index)
        image[index] = coordinator.inspect_world(bounds.x + static_cast<std::int64_t>(index % bounds.width),
            bounds.y + static_cast<std::int64_t>(index / bounds.width)).material;
    std::vector<ReferenceComponent> result;
    for (std::uint32_t root = 0; root < image.size(); ++root) {
        if (visited[root] || (image[root] != Material::Wood && image[root] != Material::RedBrick)) continue;
        ReferenceComponent component;
        component.material = image[root];
        std::deque<std::uint32_t> frontier{root};
        visited[root] = true;
        while (!frontier.empty()) {
            const auto at = frontier.front(); frontier.pop_front();
            component.cells.push_back(at);
            const auto x = static_cast<int>(at % bounds.width), y = static_cast<int>(at / bounds.width);
            for (const auto& [dx, dy] : std::array<std::pair<int, int>, 4>{{{0,-1},{1,0},{0,1},{-1,0}}}) {
                const auto nx = x + dx, ny = y + dy;
                if (nx < 0 || ny < 0 || nx >= bounds.width || ny >= bounds.height) {
                    component.unknown_boundary = true; continue;
                }
                const auto neighbour = static_cast<std::uint32_t>(ny * bounds.width + nx);
                component.anchored = component.anchored || image[neighbour] == Material::Wall;
                if (image[neighbour] == component.material && !visited[neighbour]) {
                    visited[neighbour] = true; frontier.push_back(neighbour);
                }
            }
        }
        std::sort(component.cells.begin(), component.cells.end());
        result.push_back(std::move(component));
    }
    return result;
}
Config config() {
    Config result; result.scenario = 0; result.world_bounds = {0, 0, 128, 96}; return result;
}
void rectangle(Coordinator& coordinator, int x, int y, int width, int height,
               Material material = Material::Wood) {
    for (int row = 0; row < height; ++row) for (int column = 0; column < width; ++column)
        CHECK(coordinator.edit(x + column, y + row, {material, 0, 0, 200}).outcome == Outcome::Accepted);
}
Result await_preparation(Coordinator& coordinator, unsigned limit = 4096) {
    Result result;
    for (unsigned attempt = 0; attempt < limit; ++attempt) {
        result = coordinator.prepare_next();
        if (result.outcome == Outcome::Accepted) return result;
        if (result.outcome != Outcome::Busy && result.outcome != Outcome::Anchored && result.outcome != Outcome::Capacity)
            return result;
    }
    return result;
}
bool activate(Coordinator& coordinator, Handle handle) {
    for (const auto kind : {AckKind::PhysicsReserved, AckKind::TerrainInstalled, AckKind::BodyActivated}) {
        const auto snapshot = coordinator.snapshot();
        const auto* shard = coordinator.registry().find(handle);
        if (!shard) return false;
        const auto& geometry = shard->geometry();
        Acknowledgement receipt{handle, snapshot.promotion.transaction, handle.generation,
            snapshot.promotion.payload_digest, geometry.revision, geometry.mask_digest, geometry.shape_digest,
            kind, kind == AckKind::TerrainInstalled ? snapshot.promotion.terrain : std::span<const TerrainReceipt>{}};
        if (coordinator.acknowledge(receipt).outcome != Outcome::Accepted) return false;
    }
    return true;
}
void simultaneous_fragments_prefer_large_structure() {
    Coordinator coordinator(config());
    rectangle(coordinator, 8, 8, 1, 1);
    rectangle(coordinator, 18, 8, 2, 2);
    rectangle(coordinator, 28, 8, 3, 3);
    rectangle(coordinator, 55, 30, 20, 20);
    const auto oracle = reference_components(coordinator);
    CHECK(oracle.size() == 4);
    CHECK(std::count_if(oracle.begin(), oracle.end(), [](const auto& c) { return !c.anchored && !c.unknown_boundary; }) == 4);
    std::vector<std::uint32_t> admitted;
    for (unsigned slot = 0; slot < 3; ++slot) {
        const auto prepared = await_preparation(coordinator);
        CHECK(prepared.outcome == Outcome::Accepted);
        if (prepared.outcome != Outcome::Accepted) break;
        const auto* shard = coordinator.registry().find(prepared.shard);
        admitted.push_back(shard->counts().structural);
        CHECK(activate(coordinator, prepared.shard));
    }
    std::printf("Admission ordering: [%u,%u,%u], expected first=400\n",
        admitted.size() > 0 ? admitted[0] : 0, admitted.size() > 1 ? admitted[1] : 0,
        admitted.size() > 2 ? admitted[2] : 0);
    CHECK(admitted.size() == 3 && admitted.front() == 400);
    const auto remaining = reference_components(coordinator);
    CHECK(std::none_of(remaining.begin(), remaining.end(), [](const auto& c) { return c.cells.size() == 400; }));
    for (unsigned attempt = 0; attempt < 128; ++attempt) (void)coordinator.prepare_next();
    const auto before = coordinator.metrics().discovered_cells;
    for (unsigned attempt = 0; attempt < 128; ++attempt) (void)coordinator.prepare_next();
    const auto repeated = coordinator.metrics().discovered_cells - before;
    std::printf("Unchanged full-slot rediscovery over 128 calls: %llu cells\n", static_cast<unsigned long long>(repeated));
    CHECK(repeated == 0);
}
void discovery_budget_is_resumable() {
    auto settings = config(); settings.discovery_budget = 32;
    Coordinator coordinator(settings);
    rectangle(coordinator, 30, 25, 20, 20);
    const auto prepared = await_preparation(coordinator, 2048);
    std::printf("400-cell component with 32-work budget: %s (%s)\n", outcome_name(prepared.outcome), prepared.detail);
    CHECK(prepared.outcome == Outcome::Accepted);
    if (prepared.outcome == Outcome::Accepted) {
        CHECK(coordinator.registry().find(prepared.shard)->counts().structural == 400);
        CHECK(activate(coordinator, prepared.shard));
    }
}
}
int main() {
    simultaneous_fragments_prefer_large_structure();
    discovery_budget_is_resumable();
    std::printf("ObjectShard admission: %llu checks, %llu failures\n",
        static_cast<unsigned long long>(checks), static_cast<unsigned long long>(failures));
    return failures == 0 ? 0 : 1;
}
