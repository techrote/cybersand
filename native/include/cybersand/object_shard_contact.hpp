#pragma once

#include "cybersand/object_shard.hpp"
#include <algorithm>
#include <bit>
#include <cmath>
#include <cstdint>
#include <limits>

// Geometry-only admission helpers. They neither read nor mutate World. The
// coordinator binds accepted results to exact poses, inventories and receipts.
namespace cybersand::object_shard::contact {

inline constexpr double kEpsilon = 1e-9;
inline constexpr double kCoordinateLimit = 1'000'000.0;

// Two-component magnitude for already validated finite contact coordinates.
// Scaling preserves tiny/subnormal axes that would disappear when squared.
// Components here are bounded by twice kCoordinateLimit (or uint16 extents),
// so the final product cannot overflow. Use sqrt to preserve the Linux GLIBC
// 2.34 runtime floor: the build host's std::hypot imports GLIBC_2.35.
[[nodiscard]] inline double magnitude(double x, double y) noexcept {
    const double scale = std::max(std::abs(x), std::abs(y));
    if (scale == 0.0) return 0.0;
    x /= scale;
    y /= scale;
    return scale * std::sqrt(x * x + y * y);
}

struct Vec { double x{}, y{}; };
struct Pose { double x{}, y{}, angle{}; };
struct Frame {
    Pose pose{};
    double cosine{1.0}, sine{};
    bool valid{};
};
struct Aabb { double min_x{}, min_y{}, max_x{}, max_y{}; };
struct MotionDomain {
    Vec reference{}; // Stable material-local centre of mass for this geometry.
    double radius{}; // All occupied carriers and their bounded contact ring.
    double rotation_radius{}; // Active span diagonal preserves the large-body angular ceiling.
    bool valid{};
};
struct GridRange {
    std::int64_t min_x{}, min_y{}, max_x{}, max_y{}; // Inclusive candidate cells.
    bool valid{};
};
struct Envelope {
    double max_translation{4.0};
    double max_rotation{0.25};
    double max_corner_motion{8.0};
    double sample_spacing{0.5};
    std::uint16_t max_samples{32};
};

// The fixed large-body angular ceiling is not a useful displacement bound for
// a low-inertia offcut. Permit additional rotation only while the conservative
// reference-to-farthest-corner arc remains <= 4 cells, and never beyond a quarter
// turn. Translation, total corner travel, sample spacing and work capacity are
// unchanged. Four cells is the existing total corner allowance minus the
// existing translation allowance (8 - 4), not a larger total motion budget.
// A radius >= 4/nominal_rotation retains the original angular limit.
// This is an explicit coordinator contract; callers of plan_sweep with their
// own Envelope retain that envelope's exact absolute angular ceiling.
inline constexpr double kSmallBodyRotationArc = Envelope{}.max_corner_motion - Envelope{}.max_translation;
inline constexpr double kMaximumObservedRotation = 1.57079632679489661923;
[[nodiscard]] inline double segment_rotation_limit(double radius,
        double nominal_rotation = 0.20) noexcept {
    if (!std::isfinite(radius) || radius <= 0.0 || !std::isfinite(nominal_rotation) ||
        nominal_rotation <= 0.0 || nominal_rotation > 0.25) return 0.0;
    return std::min(kMaximumObservedRotation,
        std::max(nominal_rotation, kSmallBodyRotationArc / radius));
}
[[nodiscard]] inline Envelope motion_envelope(std::uint16_t width, std::uint16_t height,
        double max_translation = 4.0, double nominal_rotation = 0.20) noexcept {
    Envelope result;
    result.max_translation = max_translation;
    result.max_rotation = segment_rotation_limit(magnitude(static_cast<double>(width),
        static_cast<double>(height)), nominal_rotation);
    return result;
}
[[nodiscard]] inline Envelope motion_envelope(MotionDomain domain,
        double max_translation = 4.0, double nominal_rotation = 0.20) noexcept {
    Envelope result;
    result.max_translation = max_translation;
    result.max_rotation = domain.valid ? segment_rotation_limit(domain.rotation_radius, nominal_rotation) : 0.0;
    return result;
}

[[nodiscard]] inline MotionDomain motion_domain(const Shard& shard) noexcept {
    const auto bounds=shard.bounds();
    const auto& mass=shard.geometry().mass;
    if (!bounds.width || !bounds.height || !std::isfinite(mass.mass) || mass.mass<=0 ||
        !std::isfinite(mass.com_x) || !std::isfinite(mass.com_y) ||
        mass.com_x<0 || mass.com_y<0 || mass.com_x>bounds.width || mass.com_y>bounds.height) return {};
    std::size_t min_x=bounds.width,min_y=bounds.height,max_x=0,max_y=0;
    bool occupied=false;
    const auto mask=shard.occupied_mask();
    for (std::size_t word=0;word<mask.size();++word) {
        auto bits=mask[word];
        while (bits) {
            const auto index=word*64+static_cast<std::size_t>(std::countr_zero(bits));
            bits&=bits-1;
            if (index>=shard.area()) return {};
            const auto x=index%bounds.width,y=index/bounds.width;
            min_x=std::min(min_x,x);min_y=std::min(min_y,y);
            max_x=std::max(max_x,x);max_y=std::max(max_y,y);occupied=true;
        }
    }
    if (!occupied) return {};
    // Water ports include the one-cell Moore ring; Sand apertures are inside
    // this same enclosure. Include Product and Cargo carriers, not only the
    // current rigid rectangle cover, without treating abandoned Empty storage
    // as physical material. Native local indices and capture origin stay fixed.
    const auto low_x=static_cast<double>(min_x ? min_x-1 : 0);
    const auto low_y=static_cast<double>(min_y ? min_y-1 : 0);
    const auto high_x=static_cast<double>(std::min<std::size_t>(bounds.width,max_x+2));
    const auto high_y=static_cast<double>(std::min<std::size_t>(bounds.height,max_y+2));
    const auto dx=std::max(std::abs(low_x-mass.com_x),std::abs(high_x-mass.com_x));
    const auto dy=std::max(std::abs(low_y-mass.com_y),std::abs(high_y-mass.com_y));
    const auto radius=magnitude(dx,dy);
    return {{mass.com_x,mass.com_y},radius,magnitude(high_x-low_x,high_y-low_y),
        std::isfinite(radius) && radius>0};
}
struct Sweep {
    Outcome outcome{Outcome::Invalid};
    std::uint16_t samples{}; // Includes both endpoints; never less than two.
    double corner_motion{}, translation{}, rotation{};
};
struct PocketOpening {
    Outcome outcome{Outcome::DestinationUnavailable};
    std::uint16_t min_x{}, max_x{}, row{}; // Clear floor span [min_x, max_x), width 1–3.
};
struct PocketWitness {
    Outcome outcome{Outcome::DestinationUnavailable};
    std::size_t slot{};
    std::uint32_t incarnation{};
    std::uint64_t material_revision{}, geometry_revision{};
    Vec local_center{}, aperture_world{};
    std::uint16_t sweep_samples{};
    bool already_inside{};
};

[[nodiscard]] inline bool finite(Vec value) noexcept {
    return std::isfinite(value.x) && std::isfinite(value.y) &&
        std::abs(value.x) <= kCoordinateLimit && std::abs(value.y) <= kCoordinateLimit;
}
[[nodiscard]] inline Frame frame(Pose pose) noexcept {
    const bool valid = finite({pose.x, pose.y}) && std::isfinite(pose.angle) &&
        std::abs(pose.angle) <= kCoordinateLimit;
    return {pose, valid ? std::cos(pose.angle) : 1.0,
        valid ? std::sin(pose.angle) : 0.0, valid};
}
[[nodiscard]] inline Vec to_world(const Frame& value, Vec local) noexcept {
    return {value.pose.x + value.cosine * local.x - value.sine * local.y,
        value.pose.y + value.sine * local.x + value.cosine * local.y};
}
[[nodiscard]] inline Vec to_local(const Frame& value, Vec world) noexcept {
    const auto dx = world.x - value.pose.x, dy = world.y - value.pose.y;
    return {value.cosine * dx + value.sine * dy, -value.sine * dx + value.cosine * dy};
}
[[nodiscard]] inline Pose interpolated_pose(Pose before, Pose after, double fraction,
        Vec reference = {}) noexcept {
    if (fraction<=0) return before;
    if (fraction>=1) return after;
    const auto first=to_world(frame(before),reference),last=to_world(frame(after),reference);
    const auto angle=before.angle+(after.angle-before.angle)*fraction;
    const auto cosine=std::cos(angle),sine=std::sin(angle);
    // Interpolate one physical reference, then recover the unchanged lattice
    // pose. Interpolating a remote storage origin would make erased Empty
    // columns create a fictitious bowed material trajectory during rotation.
    return {first.x+(last.x-first.x)*fraction-cosine*reference.x+sine*reference.y,
        first.y+(last.y-first.y)*fraction-sine*reference.x-cosine*reference.y,angle};
}
[[nodiscard]] inline Aabb transformed_cell_aabb(const Frame& value,
        std::uint16_t x, std::uint16_t y) noexcept {
    const auto center = to_world(value, {static_cast<double>(x) + 0.5,
        static_cast<double>(y) + 0.5});
    const auto half = 0.5 * (std::abs(value.cosine) + std::abs(value.sine));
    return {center.x - half, center.y - half, center.x + half, center.y + half};
}
[[nodiscard]] inline Aabb transformed_bounds(const Frame& value,
        std::uint16_t width, std::uint16_t height) noexcept {
    const auto center = to_world(value, {width * 0.5, height * 0.5});
    const auto half_x = 0.5 * (std::abs(value.cosine) * width + std::abs(value.sine) * height);
    const auto half_y = 0.5 * (std::abs(value.sine) * width + std::abs(value.cosine) * height);
    return {center.x - half_x, center.y - half_y, center.x + half_x, center.y + half_y};
}
[[nodiscard]] inline GridRange grid_candidates(Aabb bounds) noexcept {
    if (!finite({bounds.min_x, bounds.min_y}) || !finite({bounds.max_x, bounds.max_y}) ||
        bounds.max_x < bounds.min_x || bounds.max_y < bounds.min_y) return {};
    return {static_cast<std::int64_t>(std::floor(bounds.min_x)),
        static_cast<std::int64_t>(std::floor(bounds.min_y)),
        static_cast<std::int64_t>(std::floor(bounds.max_x)),
        static_cast<std::int64_t>(std::floor(bounds.max_y)), true};
}

// Exact four-axis SAT for the rotated local unit square against a World unit
// square. Positive-area overlap and touching are deliberately separate modes.
[[nodiscard]] inline bool cell_overlap(const Frame& value, std::uint16_t local_x,
        std::uint16_t local_y, std::int64_t world_x, std::int64_t world_y,
        bool include_touch = false) noexcept {
    if (!value.valid || std::abs(static_cast<double>(world_x)) > kCoordinateLimit ||
        std::abs(static_cast<double>(world_y)) > kCoordinateLimit) return false;
    const auto center = to_world(value, {local_x + 0.5, local_y + 0.5});
    const auto dx = static_cast<double>(world_x) + 0.5 - center.x;
    const auto dy = static_cast<double>(world_y) + 0.5 - center.y;
    const auto radius = 0.5 + 0.5 * (std::abs(value.cosine) + std::abs(value.sine));
    const auto limit = include_touch ? radius + kEpsilon : radius - kEpsilon;
    return std::abs(dx) < limit && std::abs(dy) < limit &&
        std::abs(dx * value.cosine + dy * value.sine) < limit &&
        std::abs(-dx * value.sine + dy * value.cosine) < limit;
}

[[nodiscard]] inline Sweep plan_sweep(Pose before, Pose after, MotionDomain domain,
        Envelope envelope = {}) noexcept {
    if (!frame(before).valid || !frame(after).valid || !domain.valid || !finite(domain.reference) ||
        !std::isfinite(domain.radius) || domain.radius<=0 ||
        !std::isfinite(envelope.max_translation) || !std::isfinite(envelope.max_rotation) ||
        !std::isfinite(envelope.max_corner_motion) || !std::isfinite(envelope.sample_spacing) ||
        envelope.max_translation < 0.0 || envelope.max_rotation < 0.0 ||
        envelope.max_corner_motion < 0.0 || envelope.sample_spacing <= 0.0 ||
        envelope.max_samples < 2 || envelope.max_samples > 128) return {};
    const auto first=to_world(frame(before),domain.reference),last=to_world(frame(after),domain.reference);
    if (!finite(first) || !finite(last)) return {};
    const auto translation = magnitude(last.x-first.x,last.y-first.y);
    // Use the actual supplied angular interval. Do not alias an unobserved
    // complete revolution into zero motion by taking angle modulo 2*pi.
    const auto rotation = std::abs(after.angle - before.angle);
    const auto corner_motion = translation + domain.radius * rotation;
    if (translation > envelope.max_translation || rotation > envelope.max_rotation ||
        corner_motion > envelope.max_corner_motion)
        return {Outcome::Unsupported, 0, corner_motion, translation, rotation};
    const auto steps = std::max(1.0, std::ceil(corner_motion / envelope.sample_spacing));
    if (steps + 1.0 > envelope.max_samples)
        return {Outcome::Capacity, 0, corner_motion, translation, rotation};
    return {Outcome::Accepted, static_cast<std::uint16_t>(steps + 1.0),
        corner_motion, translation, rotation};
}
[[nodiscard]] inline Sweep plan_sweep(Pose before, Pose after, std::uint16_t width,
        std::uint16_t height, Envelope envelope = {}) noexcept {
    const auto radius=magnitude(static_cast<double>(width),static_cast<double>(height));
    return plan_sweep(before,after,MotionDomain{{},radius,radius,width!=0 && height!=0},envelope);
}

namespace detail {
[[nodiscard]] inline bool inside_opening(Vec point, PocketOpening opening) noexcept {
    return point.x > static_cast<double>(opening.min_x) + kEpsilon &&
        point.x < static_cast<double>(opening.max_x) - kEpsilon &&
        point.y > static_cast<double>(opening.row) + kEpsilon &&
        point.y < static_cast<double>(opening.row + 1) - kEpsilon;
}
[[nodiscard]] inline bool segment_hits_box(Vec first, Vec last, Aabb box) noexcept {
    double entry = 0.0, exit = 1.0;
    const auto slab = [&](double start, double delta, double low, double high) {
        if (std::abs(delta) <= kEpsilon) return start >= low && start <= high;
        auto a = (low - start) / delta, b = (high - start) / delta;
        if (a > b) std::swap(a, b);
        entry = std::max(entry, a); exit = std::min(exit, b);
        return entry <= exit;
    };
    return slab(first.x, last.x - first.x, box.min_x, box.max_x) &&
        slab(first.y, last.y - first.y, box.min_y, box.max_y);
}
[[nodiscard]] inline bool clear_segment(const Shard& shard, Vec first, Vec last,
        double padding) noexcept {
    const auto bounds = shard.bounds();
    const auto first_x = std::max(0, static_cast<int>(std::floor(std::min(first.x, last.x) - padding)));
    const auto first_y = std::max(0, static_cast<int>(std::floor(std::min(first.y, last.y) - padding)));
    const auto last_x = std::min(static_cast<int>(bounds.width) - 1,
        static_cast<int>(std::floor(std::max(first.x, last.x) + padding)));
    const auto last_y = std::min(static_cast<int>(bounds.height) - 1,
        static_cast<int>(std::floor(std::max(first.y, last.y) + padding)));
    for (int y = first_y; y <= last_y; ++y) for (int x = first_x; x <= last_x; ++x) {
        const auto index = static_cast<std::size_t>(y) * bounds.width + static_cast<std::size_t>(x);
        if (!shard.structural(index) && shard.role(index) != Role::Cargo) continue;
        if (segment_hits_box(first, last, {x - padding, y - padding, x + 1.0 + padding, y + 1.0 + padding}))
            return false;
    }
    return true;
}
} // namespace detail

// Geometry query only, not an inventory reservation. A clear one-to-three-cell
// floor span has structural side retainers and a complete floor, with an open
// local-up column above every slot. Existing cargo/products close the opening
// by default. The geometry-only query ignores nonstructural occupancy so the
// coordinator can protect the entire aperture from mechanical relocation even
// while a carrier is full; it never grants material-transfer admission.
[[nodiscard]] inline PocketOpening pocket_opening(const Shard& shard,
        std::size_t local_index, bool require_available = true) noexcept {
    PocketOpening result;
    if (local_index >= shard.area()) { result.outcome = Outcome::Invalid; return result; }
    const auto bounds = shard.bounds();
    const auto y = local_index / bounds.width;
    const auto x = local_index % bounds.width;
    const auto closed = [&](std::size_t index) noexcept {
        return shard.structural(index) || (require_available && shard.occupied(index));
    };
    if (closed(local_index) || x == 0 || x + 1 >= bounds.width || y + 1 >= bounds.height)
        return result;
    auto left = x, right = x + 1;
    while (left > 0 && !shard.structural(y * bounds.width + left - 1)) {
        if (right - left == 3 || closed(y * bounds.width + left - 1)) return result;
        --left;
    }
    while (right < bounds.width && !shard.structural(y * bounds.width + right)) {
        if (right - left == 3 || closed(y * bounds.width + right)) return result;
        ++right;
    }
    if (left == 0 || right == bounds.width) return result;
    for (auto column = left; column < right; ++column) {
        if (!shard.structural((y + 1) * bounds.width + column)) return result;
        for (std::size_t above = 0; above <= y; ++above)
            if (closed(above * bounds.width + column)) return result;
    }
    return {Outcome::Accepted, static_cast<std::uint16_t>(left),
        static_cast<std::uint16_t>(right), static_cast<std::uint16_t>(y)};
}

// World Sand's centre must lie inside a real open pocket; its local slot is the
// sole destination carrier. A wider aperture tolerates ordinary rotated raster
// clearance without accepting trajectories through a side or retaining floor.
[[nodiscard]] inline PocketWitness sand_pocket_witness(const Shard& shard,
        Pose before, Pose after, Vec world_sand_center, Envelope envelope = {},
        MotionDomain domain = {}) noexcept {
    PocketWitness result;
    if (!finite(world_sand_center)) { result.outcome = Outcome::Invalid; return result; }
    if (shard.phase() != Phase::Active || shard.geometry_dirty() ||
        shard.applied_physics_revision() != shard.geometry().revision) {
        result.outcome = Outcome::Stale; return result;
    }
    const auto bounds = shard.bounds();
    // Legacy explicit geometry callers keep their exact origin-based model;
    // the coordinator supplies its material/COM domain consistently.
    if (!domain.valid) {
        const auto radius=magnitude(bounds.width,bounds.height);
        domain={{},radius,radius,true};
    }
    const auto sweep = plan_sweep(before, after, domain, envelope);
    if (sweep.outcome != Outcome::Accepted) { result.outcome = sweep.outcome; return result; }
    const auto current = frame(after);
    const auto center = to_local(current, world_sand_center);
    if (center.x <= 1.0 || center.y <= 0.0 || center.x >= bounds.width - 1.0 ||
        center.y >= bounds.height - 1.0) return result;
    const auto x = static_cast<std::size_t>(std::floor(center.x));
    const auto y = static_cast<std::size_t>(std::floor(center.y));
    const auto index = y * bounds.width + x;
    const auto opening = pocket_opening(shard, index);
    if (opening.outcome != Outcome::Accepted || !detail::inside_opening(center, opening)) return result;
    const auto old_local = to_local(frame(before), world_sand_center);
    const bool already_inside = detail::inside_opening(old_local, opening);
    // A newly enclosing body must carry its opening over the grain. Entering
    // through a side or the retaining bottom is never accepted as ingestion.
    if (!already_inside && old_local.y > static_cast<double>(y) + kEpsilon) return result;

    const auto angle_delta = after.angle - before.angle;
    const auto steps = static_cast<double>(sweep.samples - 1);
    const auto first_reference=to_world(frame(before),domain.reference);
    const auto last_reference=to_world(frame(after),domain.reference);
    const auto radius = std::max(magnitude(world_sand_center.x-first_reference.x,world_sand_center.y-first_reference.y),
        magnitude(world_sand_center.x-last_reference.x,world_sand_center.y-last_reference.y));
    // For q(t)=R(-angle(t))*(grain-reference_world(t))+reference_local, the second derivative norm is
    // bounded by a²*radius+2*|a|*translation. The /8*steps² interpolation bound
    // expands each tested chord, covering the curved local trajectory between
    // samples rather than merely checking a few unobstructed sample points.
    const auto chord_error = (angle_delta * angle_delta * radius +
        2.0 * std::abs(angle_delta) * sweep.translation) / (8.0 * steps * steps);
    bool crossed_aperture = already_inside;
    auto previous = old_local;
    for (std::uint16_t sample = 1; sample < sweep.samples; ++sample) {
        const auto pose = interpolated_pose(before, after, static_cast<double>(sample) / steps,domain.reference);
        const auto next = to_local(frame(pose), world_sand_center);
        if (!detail::clear_segment(shard, previous, next, chord_error + kEpsilon)) return result;
        if (!crossed_aperture && previous.y <= static_cast<double>(y) && next.y > static_cast<double>(y)) {
            const auto crossing = previous.x + (next.x - previous.x) *
                ((static_cast<double>(y) - previous.y) / (next.y - previous.y));
            if (crossing <= static_cast<double>(opening.min_x) + chord_error + kEpsilon ||
                crossing >= static_cast<double>(opening.max_x) - chord_error - kEpsilon) return result;
            crossed_aperture = true;
        }
        previous = next;
    }
    if (!crossed_aperture) return result;
    result.outcome = Outcome::Accepted;
    result.slot = index;
    result.incarnation = shard.schedule(index).incarnation;
    result.material_revision = shard.material_revision();
    result.geometry_revision = shard.geometry().revision;
    result.local_center = center;
    result.aperture_world = to_world(current, {(opening.min_x + opening.max_x) * 0.5, static_cast<double>(y)});
    result.sweep_samples = sweep.samples;
    result.already_inside = already_inside;
    return result;
}

} // namespace cybersand::object_shard::contact
