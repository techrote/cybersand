#include "cybersand/object_shard_contact.hpp"

#include <array>
#include <cmath>
#include <cstdio>
#include <limits>

namespace {
using namespace cybersand;
using namespace cybersand::object_shard;
using namespace cybersand::object_shard::contact;
std::uint64_t checks{}, failures{};
void check(bool pass, const char* description, int line) {
    ++checks;
    if (!pass) { ++failures; std::fprintf(stderr, "FAIL %d: %s\n", line, description); }
}
#define CHECK(expression) check((expression), #expression, __LINE__)

// Independent Sutherland-Hodgman polygon clipping oracle. It uses vertices and
// area, rather than the tested SAT centre/projection implementation.
double clipped_area(Frame value, int local_x, int local_y, int world_x, int world_y) {
    std::array<Vec, 16> polygon{}, output{};
    polygon[0] = to_world(value, {static_cast<double>(local_x), static_cast<double>(local_y)});
    polygon[1] = to_world(value, {local_x + 1.0, static_cast<double>(local_y)});
    polygon[2] = to_world(value, {local_x + 1.0, local_y + 1.0});
    polygon[3] = to_world(value, {static_cast<double>(local_x), local_y + 1.0});
    std::size_t count = 4;
    for (int edge = 0; edge < 4 && count != 0; ++edge) {
        const bool vertical = edge < 2;
        const bool lower = edge % 2 == 0;
        const double bound = vertical ? world_x + (lower ? 0.0 : 1.0) : world_y + (lower ? 0.0 : 1.0);
        const auto component = [vertical](Vec point) { return vertical ? point.x : point.y; };
        const auto inside = [&](Vec point) { return lower ? component(point) >= bound : component(point) <= bound; };
        std::size_t used = 0;
        Vec previous = polygon[count - 1];
        for (std::size_t i = 0; i < count; ++i) {
            const Vec current = polygon[i];
            if (inside(previous) != inside(current)) {
                const auto t = (bound - component(previous)) / (component(current) - component(previous));
                output[used++] = {previous.x + (current.x - previous.x) * t,
                    previous.y + (current.y - previous.y) * t};
            }
            if (inside(current)) output[used++] = current;
            previous = current;
        }
        polygon = output; count = used;
    }
    double twice_area = 0.0;
    for (std::size_t i = 0; i < count; ++i) {
        const auto& a = polygon[i]; const auto& b = polygon[(i + 1) % count];
        twice_area += a.x * b.y - a.y * b.x;
    }
    return std::abs(twice_area) * 0.5;
}

void sat_matches_polygon_oracle() {
    constexpr std::array<double, 8> angles{0.0, 0.17, 0.51, 0.7853981633974483,
        1.5707963267948966, 2.37, 3.141592653589793, -2.73};
    for (double angle : angles) for (int local_y = 0; local_y < 3; ++local_y)
        for (int local_x = 0; local_x < 3; ++local_x) {
            const auto value = frame({-1.213, 2.397, angle});
            const auto aabb = transformed_cell_aabb(value, static_cast<std::uint16_t>(local_x),
                static_cast<std::uint16_t>(local_y));
            const auto candidates = grid_candidates(aabb);
            CHECK(candidates.valid);
            for (int world_y = -3; world_y < 9; ++world_y) for (int world_x = -8; world_x < 6; ++world_x) {
                const auto area = clipped_area(value, local_x, local_y, world_x, world_y);
                CHECK(cell_overlap(value, static_cast<std::uint16_t>(local_x),
                    static_cast<std::uint16_t>(local_y), world_x, world_y) == (area > 1e-10));
                if (area > 1e-10)
                    CHECK(world_x >= candidates.min_x && world_x <= candidates.max_x &&
                        world_y >= candidates.min_y && world_y <= candidates.max_y);
            }
            const auto original = Vec{local_x + 0.123, local_y + 0.987};
            const auto roundtrip = to_local(value, to_world(value, original));
            CHECK(std::abs(roundtrip.x - original.x) < 1e-12);
            CHECK(std::abs(roundtrip.y - original.y) < 1e-12);
        }
    CHECK(cell_overlap(frame({0, 0, 0}), 0, 0, 0, 0));
    CHECK(!cell_overlap(frame({0, 0, 0}), 0, 0, 1, 0));
    CHECK(cell_overlap(frame({0, 0, 0}), 0, 0, 1, 0, true));
    CHECK(!cell_overlap(frame({0, 0, 0}), 0, 0, 2, 0, true));
    CHECK(!cell_overlap(frame({std::numeric_limits<double>::quiet_NaN(), 0, 0}), 0, 0, 0, 0));
}

Handle pocket(Registry& registry) {
    Handle handle;
    CHECK(registry.prepare({-3, -4, 7, 7}, 10, handle) == Outcome::Accepted);
    auto* shard = registry.find(handle);
    for (const auto index : {3 * 7 + 2, 3 * 7 + 4, 4 * 7 + 2, 4 * 7 + 3, 4 * 7 + 4})
        CHECK(shard->set_cell(static_cast<std::size_t>(index), {Material::Wood, 0, 0, 200},
            Role::Structural, 10) == Outcome::Accepted);
    CHECK(registry.finish_preparation(handle) == Outcome::Accepted);
    CHECK(registry.reserve_physics(handle) == Outcome::Accepted);
    CHECK(registry.commit(handle) == Outcome::Accepted);
    CHECK(registry.advance(handle, Phase::CommittedInactive, Phase::TerrainInstalled) == Outcome::Accepted);
    CHECK(registry.advance(handle, Phase::TerrainInstalled, Phase::MaskApplied) == Outcome::Accepted);
    CHECK(registry.advance(handle, Phase::MaskApplied, Phase::ReadyToActivate) == Outcome::Accepted);
    const auto& geometry = shard->geometry();
    CHECK(shard->acknowledge_geometry(geometry.revision, geometry.mask_digest, geometry.shape_digest) == Outcome::Accepted);
    CHECK(registry.advance(handle, Phase::ReadyToActivate, Phase::Active) == Outcome::Accepted);
    return handle;
}

void aperture_and_motion_contract() {
    Registry registry;
    const auto handle = pocket(registry);
    auto* shard = registry.find(handle);
    const Pose pose{10, 20, 0};
    const Vec grain{13.5, 23.5};
    const auto still = sand_pocket_witness(*shard, pose, pose, grain);
    CHECK(still.outcome == Outcome::Accepted && still.already_inside);
    CHECK(still.slot == 24);
    CHECK(still.incarnation == shard->schedule(24).incarnation);
    CHECK(still.geometry_revision == shard->geometry().revision);
    CHECK(still.aperture_world.x == 13.5 && still.aperture_world.y == 23.0);
    const auto top = sand_pocket_witness(*shard, {10, 21, 0}, pose, grain);
    CHECK(top.outcome == Outcome::Accepted && !top.already_inside);
    CHECK(sand_pocket_witness(*shard, {10, 23, 0}, pose, grain).outcome == Outcome::Accepted);
    CHECK(sand_pocket_witness(*shard, {11, 20, 0}, pose, grain).outcome == Outcome::DestinationUnavailable);
    CHECK(sand_pocket_witness(*shard, {9, 20, 0}, pose, grain).outcome == Outcome::DestinationUnavailable);
    CHECK(sand_pocket_witness(*shard, {10, 19, 0}, pose, grain).outcome == Outcome::DestinationUnavailable);
    // This diagonal starts above, but crosses the side wall instead of the
    // aperture. Merely finding a grain inside the final pocket is insufficient.
    CHECK(sand_pocket_witness(*shard, {9, 21, 0}, pose, grain).outcome == Outcome::DestinationUnavailable);
    CHECK(sand_pocket_witness(*shard, pose, pose, {12.5, 23.5}).outcome == Outcome::DestinationUnavailable);
    CHECK(sand_pocket_witness(*shard, pose, pose, {13.0, 23.5}).outcome == Outcome::DestinationUnavailable);
    CHECK(sand_pocket_witness(*shard, {10, 30, 0}, pose, grain).outcome == Outcome::Unsupported);
    Envelope sparse; sparse.max_samples = 2; sparse.sample_spacing = 0.1;
    CHECK(sand_pocket_witness(*shard, {10, 21, 0}, pose, grain, sparse).outcome == Outcome::Capacity);
    CHECK(plan_sweep(pose, {10, 20, 6.283185307179586}, 7, 7).outcome == Outcome::Unsupported);
    CHECK(plan_sweep(pose, {10, 20, std::numeric_limits<double>::infinity()}, 7, 7).outcome == Outcome::Invalid);

    // The capture volume rotates with the body. Opening direction is local-up,
    // while the coordinator leaves all World transport laws world-oriented.
    for (double angle : {0.23, 0.8, 1.5707963267948966, -1.4}) {
        const Pose tilted{30, -10, angle};
        const auto current = frame(tilted);
        const auto sand = to_world(current, {3.5, 3.5});
        CHECK(sand_pocket_witness(*shard, tilted, tilted, sand).outcome == Outcome::Accepted);
        const auto old_origin = to_world(current, {0, 1});
        CHECK(sand_pocket_witness(*shard, {old_origin.x, old_origin.y, angle}, tilted, sand).outcome == Outcome::Accepted);
        const auto side_origin = to_world(current, {1, 0});
        CHECK(sand_pocket_witness(*shard, {side_origin.x, side_origin.y, angle}, tilted, sand).outcome == Outcome::DestinationUnavailable);
    }
    CHECK(shard->set_cell(10, {Material::Wood, 0, 0, 200}, Role::Structural, 11) == Outcome::Accepted);
    CHECK(sand_pocket_witness(*shard, pose, pose, grain).outcome == Outcome::Stale);
    CHECK(registry.rebuild_geometry(handle, 11) == Outcome::Accepted);
    CHECK(sand_pocket_witness(*shard, pose, pose, grain).outcome == Outcome::Stale);
    const auto& geometry = shard->geometry();
    CHECK(shard->acknowledge_geometry(geometry.revision, geometry.mask_digest, geometry.shape_digest) == Outcome::Accepted);
    CHECK(sand_pocket_witness(*shard, pose, pose, grain).outcome == Outcome::DestinationUnavailable); // Lid blocks the open column.
}

void curved_trajectory_has_no_hidden_wall_crossing() {
    Registry registry;
    const auto handle = pocket(registry);
    const auto* shard = registry.find(handle);
    std::uint32_t admitted = 0;
    // A targeted numerical cross-check of the conservative curved-segment
    // bound: every admitted trajectory is independently sampled densely.
    for (int n = 0; n < 32; ++n) {
        const double angle = (n - 16) * 0.006;
        const Pose after{10, 20, angle};
        const auto grain = to_world(frame(after), {3.5, 3.5});
        const Vec old_local{3.5 + (n % 4 - 1.5) * 0.1, 2.5 + (n % 3) * 0.3};
        const Pose before{grain.x - old_local.x, grain.y - old_local.y, 0};
        const auto witness = sand_pocket_witness(*shard, before, after, grain);
        if (witness.outcome != Outcome::Accepted) continue;
        ++admitted;
        for (int sample = 0; sample <= 1'000; ++sample) {
            const auto point = to_local(frame(interpolated_pose(before, after, sample / 1000.0)), grain);
            if (point.x < 0 || point.y < 0 || point.x >= 7 || point.y >= 7) continue;
            const auto index = static_cast<std::size_t>(std::floor(point.y)) * 7 +
                static_cast<std::size_t>(std::floor(point.x));
            CHECK(!shard->structural(index));
        }
    }
    CHECK(admitted >= 16);
}
} // namespace

int main() {
    sat_matches_polygon_oracle();
    aperture_and_motion_contract();
    curved_trajectory_has_no_hidden_wall_crossing();
    std::printf("ObjectShard contact: %llu checks, %llu failures\n",
        static_cast<unsigned long long>(checks), static_cast<unsigned long long>(failures));
    return failures == 0 ? 0 : 1;
}
