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

void portable_magnitude_matches_independent_reference() {
    const auto tiny = std::numeric_limits<double>::denorm_min();
    const auto normal_min = std::numeric_limits<double>::min();
    const std::array<double, 20> components{0.0, -0.0, tiny, -tiny, 3 * tiny,
        normal_min, -normal_min, std::nextafter(normal_min, 0.0), 1e-200, -1e-100,
        1e-9, -0.125, 1.0, -3.0, 4.0, 65'535.0,
        kCoordinateLimit, -kCoordinateLimit, 2 * kCoordinateLimit, -2 * kCoordinateLimit};
    // std::hypot is an independent test-only reference. Production contact
    // code intentionally avoids its build-host GLIBC_2.35 symbol dependency.
    for (double x : components) for (double y : components) {
        const auto expected = std::hypot(x, y);
        const auto actual = magnitude(x, y);
        const auto tolerance = 3 * std::numeric_limits<double>::epsilon() * expected + 2 * tiny;
        CHECK(std::isfinite(actual) && actual >= 0.0);
        CHECK(std::abs(actual - expected) <= tolerance);
        CHECK(actual == magnitude(y, x));
    }
    CHECK(magnitude(0.0, -0.0) == 0.0 && !std::signbit(magnitude(-0.0, -0.0)));
    CHECK(magnitude(tiny, 0.0) == tiny);
    CHECK(magnitude(0.0, -tiny) == tiny);
    CHECK(magnitude(tiny, tiny) != 0.0);
    CHECK(magnitude(3.0, 4.0) == 5.0);
    CHECK(magnitude(-3.0, -4.0) == 5.0);
}

void portable_magnitude_preserves_admitted_envelope_boundaries() {
    const Pose origin{};
    const auto below = std::nextafter(4.0, 0.0);
    const auto above = std::nextafter(4.0, std::numeric_limits<double>::infinity());
    CHECK(plan_sweep(origin, {below, 0, 0}, 1, 1).outcome == Outcome::Accepted);
    CHECK(plan_sweep(origin, {4, 0, 0}, 1, 1).outcome == Outcome::Accepted);
    CHECK(plan_sweep(origin, {above, 0, 0}, 1, 1).outcome == Outcome::Unsupported);
    CHECK(plan_sweep(origin, {-4, 0, 0}, 1, 1).outcome == Outcome::Accepted);
    CHECK(plan_sweep(origin, {-above, 0, 0}, 1, 1).outcome == Outcome::Unsupported);
    Envelope diagonal;
    diagonal.max_translation = 5.0; diagonal.max_corner_motion = 5.0;
    CHECK(plan_sweep(origin, {3, 4, 0}, 1, 1, diagonal).outcome == Outcome::Accepted);
    CHECK(plan_sweep(origin, {3, 4 + 1e-12, 0}, 1, 1, diagonal).outcome == Outcome::Unsupported);
    diagonal.max_samples = 9;
    CHECK(plan_sweep(origin, {4, 0, 0}, 1, 1, diagonal).outcome == Outcome::Accepted);
    CHECK(plan_sweep(origin, {above, 0, 0}, 1, 1, diagonal).outcome == Outcome::Capacity);
    Envelope rotating;
    rotating.max_corner_motion = 1.0;
    CHECK(plan_sweep(origin, {0, 0, .2}, 3, 4, rotating).outcome == Outcome::Accepted);
    CHECK(plan_sweep(origin, {0, 0, std::nextafter(.2, 0.0)}, 3, 4, rotating).outcome == Outcome::Accepted);
    CHECK(plan_sweep(origin, {0, 0, std::nextafter(.2, 1.0)}, 3, 4, rotating).outcome == Outcome::Unsupported);
    const auto tiny = std::numeric_limits<double>::denorm_min();
    const auto subnormal = plan_sweep(origin, {tiny, tiny, 0}, 1, 1);
    CHECK(subnormal.outcome == Outcome::Accepted && subnormal.translation > 0.0 && subnormal.samples == 2);
    const auto extent = plan_sweep({-kCoordinateLimit, -kCoordinateLimit, 0},
        {kCoordinateLimit, kCoordinateLimit, 0}, 65'535, 65'535);
    CHECK(extent.outcome == Outcome::Unsupported && std::isfinite(extent.translation));
}

void small_fragment_motion_preserves_geometric_and_work_limits() {
    const Pose before{20,30,0};
    const auto small=motion_envelope(3,3);
    CHECK(small.max_translation==4.0 && small.max_corner_motion==8.0);
    CHECK(small.sample_spacing==0.5 && small.max_samples==32);
    // Recorded owner values and an independent real-Rapier ledge-impact
    // witness. Both exceed the old .20 ceiling while moving little material.
    for (const Pose after : {Pose{20.804,30,0.274462},Pose{20.236560643,30,0.296369716}}) {
        Envelope old;old.max_rotation=.20;
        CHECK(plan_sweep(before,after,3,3,old).outcome==Outcome::Unsupported);
        const auto sweep=plan_sweep(before,after,3,3,small);
        CHECK(sweep.outcome==Outcome::Accepted);
        CHECK(sweep.samples>=2 && sweep.samples<=17);
        CHECK(sweep.corner_motion/(sweep.samples-1)<=.5);
        // Dense independent material-corner samples between every consecutive
        // sweep sample remain within the unchanged .5-cell sampling envelope.
        for (unsigned step=0;step+1<sweep.samples;++step) {
            const auto start=frame(interpolated_pose(before,after,
                static_cast<double>(step)/(sweep.samples-1)));
            for (unsigned piece=1;piece<=40;++piece) {
                const auto current=frame(interpolated_pose(before,after,
                    (static_cast<double>(step)+piece/40.0)/(sweep.samples-1)));
                for (const Vec corner : {Vec{0,0},Vec{3,0},Vec{0,3},Vec{3,3}}) {
                    const auto a=to_world(start,corner),b=to_world(current,corner);
                    CHECK(std::hypot(a.x-b.x,a.y-b.y)<=.5+1e-12);
                }
            }
        }
    }
    CHECK(segment_rotation_limit(20)==.20);
    CHECK(motion_envelope(20,1).max_rotation==.20);
    CHECK(plan_sweep(before,{20,30,.2000001},20,1,motion_envelope(20,1)).outcome==Outcome::Unsupported);
    CHECK(plan_sweep(before,{20,30,.1},100,1,motion_envelope(100,1)).outcome==Outcome::Unsupported);
    CHECK(plan_sweep(before,{24.0000001,30,0},3,3,small).outcome==Outcome::Unsupported);
    CHECK(plan_sweep(before,{20,30,small.max_rotation+1e-6},3,3,small).outcome==Outcome::Unsupported);
    CHECK(plan_sweep(before,{20,30,6.283185307179586},1,1,motion_envelope(1,1)).outcome==Outcome::Unsupported);
    CHECK(plan_sweep(before,{20,30,std::numeric_limits<double>::infinity()},3,3,small).outcome==Outcome::Invalid);
    CHECK(segment_rotation_limit(.1)==kMaximumObservedRotation);
    CHECK(segment_rotation_limit(0)==0 && segment_rotation_limit(-1)==0);
    CHECK(segment_rotation_limit(std::numeric_limits<double>::quiet_NaN())==0);
    CHECK(segment_rotation_limit(3,.3)==0);
}

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

Handle pocket(Registry& registry, unsigned opening_width = 1) {
    Handle handle;
    const auto width = static_cast<std::uint16_t>(opening_width + 6);
    CHECK(registry.prepare({-3, -4, width, 7}, 10, handle) == Outcome::Accepted);
    auto* shard = registry.find(handle);
    for (const auto x : {2U, 3U + opening_width})
        CHECK(shard->set_cell(static_cast<std::size_t>(3 * width + x), {Material::Wood, 0, 0, 200},
            Role::Structural, 10) == Outcome::Accepted);
    for (unsigned x = 2; x <= 3 + opening_width; ++x)
        CHECK(shard->set_cell(static_cast<std::size_t>(4 * width + x), {Material::Wood, 0, 0, 200},
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

void bounded_wide_aperture_and_rotated_world_carriers() {
    Registry registry;
    const auto handle = pocket(registry, 3);
    auto* shard = registry.find(handle);
    const Pose pose{10, 20, 0};
    for (std::size_t x = 3; x <= 5; ++x) {
        const auto opening = pocket_opening(*shard, 3 * 9 + x);
        CHECK(opening.outcome == Outcome::Accepted && opening.min_x == 3 && opening.max_x == 6 && opening.row == 3);
        const auto witness = sand_pocket_witness(*shard, pose, pose, {10 + x + .5, 23.5});
        CHECK(witness.outcome == Outcome::Accepted && witness.slot == 3 * 9 + x);
        CHECK(witness.aperture_world.x == 14.5 && witness.aperture_world.y == 23.0);
    }
    // Internal local-cell boundaries are deterministic slots, not artificial
    // side walls. A point on the outer opening boundary remains inadmissible.
    CHECK(sand_pocket_witness(*shard, pose, pose, {14.0, 23.5}).outcome == Outcome::Accepted);
    CHECK(sand_pocket_witness(*shard, pose, pose, {13.0, 23.5}).outcome == Outcome::DestinationUnavailable);
    CHECK(sand_pocket_witness(*shard, {11, 20, 0}, pose, {14.5, 23.5}).outcome == Outcome::Accepted);
    const auto diagonal_top = sand_pocket_witness(*shard, {12, 21, 0}, pose, {15.5, 23.5});
    CHECK(diagonal_top.outcome == Outcome::Accepted && !diagonal_top.already_inside && diagonal_top.slot == 32);
    CHECK(sand_pocket_witness(*shard, {13, 20, 0}, pose, {14.5, 23.5}).outcome == Outcome::DestinationUnavailable);
    CHECK(sand_pocket_witness(*shard, {7, 20, 0}, pose, {14.5, 23.5}).outcome == Outcome::DestinationUnavailable);
    CHECK(sand_pocket_witness(*shard, {10, 19, 0}, pose, {14.5, 23.5}).outcome == Outcome::DestinationUnavailable);
    CHECK(sand_pocket_witness(*shard, {11.4, 21, 0}, pose, {13.2, 23.8}).outcome == Outcome::DestinationUnavailable);

    // This is the actual World raster constraint that exposed the one-cell
    // channel: an admitted carrier must have no positive-area structural
    // overlap. Check real half-integer World centres, not only synthetic local
    // points. Keep the floor at a declared clear raster height; this does not
    // promise ingress at every subcell floor placement. The independent
    // polygon oracle validates every clear carrier.
    for (double angle : {-0.10, -0.01, 0.01, 0.10}) {
        const Pose tilted{10.13, 20.13 - 4.5 * std::sin(angle), angle};
        const auto value = frame(tilted);
        unsigned clear_carriers = 0;
        for (int wy = 21; wy <= 25; ++wy) for (int wx = 11; wx <= 17; ++wx) {
            const auto witness = sand_pocket_witness(*shard, tilted, tilted, {wx + .5, wy + .5});
            if (witness.outcome != Outcome::Accepted) continue;
            bool blocked = false;
            for (std::size_t at = 0; at < shard->area(); ++at) if (shard->structural(at))
                blocked = blocked || clipped_area(value, static_cast<int>(at % 9), static_cast<int>(at / 9), wx, wy) > 1e-10;
            if (blocked) continue;
            ++clear_carriers;
            CHECK(pocket_opening(*shard, witness.slot).outcome == Outcome::Accepted);
            CHECK(witness.already_inside);
        }
        CHECK(clear_carriers != 0);
    }
    const auto broad = pocket(registry, 4);
    CHECK(pocket_opening(*registry.find(broad), 3 * 10 + 4).outcome == Outcome::DestinationUnavailable);
    CHECK(pocket_opening(*shard, shard->area()).outcome == Outcome::Invalid);
    // One missing floor segment invalidates the complete pocket, even when the
    // selected slot itself still has support.
    CHECK(shard->set_cell(4 * 9 + 3, {Material::Empty, 0, 0, 200}, Role::Empty, 11) == Outcome::Accepted);
    CHECK(pocket_opening(*shard, 3 * 9 + 5).outcome == Outcome::DestinationUnavailable);
    CHECK(shard->set_cell(4 * 9 + 3, {Material::Wood, 0, 0, 200}, Role::Structural, 11) == Outcome::Accepted);
    CHECK(shard->set_cell(1 * 9 + 3, {Material::Fire, 32, 0, 200}, Role::Product, 11) == Outcome::Accepted);
    CHECK(pocket_opening(*shard, 3 * 9 + 5).outcome == Outcome::DestinationUnavailable);
    // Mechanical relocation must still see the physical aperture while it
    // contains real products/cargo. This geometry-only result cannot authorize
    // transfer into the occupied carrier or through an occupied column.
    CHECK(shard->set_cell(3 * 9 + 4, {Material::Sand, 1234, 7, 410}, Role::Cargo, 11) == Outcome::Accepted);
    for (std::size_t x = 3; x <= 5; ++x) {
        CHECK(pocket_opening(*shard, 3 * 9 + x).outcome == Outcome::DestinationUnavailable);
        const auto geometry_only = pocket_opening(*shard, 3 * 9 + x, false);
        CHECK(geometry_only.outcome == Outcome::Accepted && geometry_only.min_x == 3 &&
            geometry_only.max_x == 6 && geometry_only.row == 3);
    }
    CHECK(pocket_opening(*shard, 3 * 9 + 2, false).outcome == Outcome::DestinationUnavailable);
    CHECK(pocket_opening(*shard, shard->area(), false).outcome == Outcome::Invalid);
    CHECK(pocket_opening(*registry.find(broad), 3 * 10 + 4, false).outcome == Outcome::DestinationUnavailable);
    CHECK(shard->set_cell(0 * 9 + 5, {Material::Wood, 0, 0, 200}, Role::Structural, 12) == Outcome::Accepted);
    CHECK(pocket_opening(*shard, 3 * 9 + 4, false).outcome == Outcome::DestinationUnavailable);
    CHECK(shard->set_cell(0 * 9 + 5, {Material::Empty, 0, 0, 200}, Role::Empty, 12) == Outcome::Accepted);
    CHECK(shard->set_cell(4 * 9 + 3, {Material::Empty, 0, 0, 200}, Role::Empty, 12) == Outcome::Accepted);
    CHECK(pocket_opening(*shard, 3 * 9 + 4, false).outcome == Outcome::DestinationUnavailable);
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
    portable_magnitude_matches_independent_reference();
    portable_magnitude_preserves_admitted_envelope_boundaries();
    small_fragment_motion_preserves_geometric_and_work_limits();
    sat_matches_polygon_oracle();
    aperture_and_motion_contract();
    bounded_wide_aperture_and_rotated_world_carriers();
    curved_trajectory_has_no_hidden_wall_crossing();
    std::printf("ObjectShard contact: %llu checks, %llu failures\n",
        static_cast<unsigned long long>(checks), static_cast<unsigned long long>(failures));
    return failures == 0 ? 0 : 1;
}
