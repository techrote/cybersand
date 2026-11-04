#pragma once

// SOL364-B diagnostic geometry only. This is NOT a live native ownership
// certificate and has no RID, World mutation, worker or application entry point.
// Its finite-family NO-GO can reject a proposed live mechanism; a geometrically
// admissible result is not authority to move a body from a material-only snapshot.
#include "cybersand/solid_contact_geometry.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <span>

namespace sol364b {
using Vec = cybersand::solid_contact::Vec2;
using Rect = cybersand::solid_contact::OrientedRect;
constexpr std::size_t max_proxies = 64, max_pairs = 8192, max_directions = 8;
constexpr double maximum_distance = 4.0, maximum_step = 0.125;
constexpr std::size_t maximum_corrections = 32;
constexpr double clearance = 2e-5, area_filter = 1e-9, additional_depth = 0.25;
constexpr double direction_duplicate = 1e-10, tie_distance = 2e-5;
constexpr double repair_acceleration = 92.12;
constexpr std::uint16_t empty = 0, sand = 2;
// Explicit diagnostic missing-authority tags, not material catalogue IDs.
constexpr std::uint16_t unknown = 65535, foreign = 65534, thermal = 65533;

inline double dot(Vec a, Vec b) noexcept { return a.x * b.x + a.y * b.y; }
inline Vec subtract(Vec a, Vec b) noexcept { return {a.x-b.x, a.y-b.y}; }
inline bool finite(Vec v) noexcept { return std::isfinite(v.x) && std::isfinite(v.y); }
inline double length(Vec v) noexcept { return std::hypot(v.x, v.y); }

struct SourceShape { std::int32_t x{}, y{}, width{}, height{}; };
struct Pose { Vec origin{}, source_com{}; double angle{}; };
struct Field {
    std::int32_t x{}, y{}, width{}, height{};
    std::span<const std::uint16_t> cells{};
};
struct Interval {
    double begin{-std::numeric_limits<double>::infinity()};
    double end{std::numeric_limits<double>::infinity()};
    bool present{true};
};
struct Pair {
    std::array<double, 4> center{}, radius{};
    double source_area{}, source_depth{};
    std::int32_t x{}, y{};
    std::size_t proxy{};
    std::uint16_t material{};
    bool initial{};
};
// Caller owns fixed scratch. Keeping this outside the call stack avoids the
// Windows default stack bound; no query allocates or retains a history cache.
struct Workspace { std::array<Pair, max_pairs> pairs{}; };
struct Witness {
    bool present{};
    std::size_t proxy{};
    std::int32_t x{}, y{};
    std::uint16_t material{};
    double begin{}, end{}, depth{};
};
struct Direction {
    Vec direction{};
    const char* outcome{"NotEvaluated"};
    double required_distance{}, maximum_swept_depth{};
    std::size_t new_pairs_within_budget{};
    Witness required_by{}, first_new_pair{}, deepest_pair{};
    bool geometric_route{};
};
struct Result {
    const char* outcome{"InvalidInput"};
    std::size_t geometry_probes{}, pair_count{}, initial_pairs{}, initial_sand_pairs{};
    std::size_t excluded_initial_pairs{}, direction_count{}, geometric_routes{};
    double initial_area{}, initial_sand_area{}, initial_excluded_area{}, initial_maximum_depth{};
    std::array<Direction, max_directions> directions{};
    std::size_t selected_direction{max_directions};
    Witness first_excluded{};
};

inline std::array<Vec, 4> axes(double angle) noexcept {
    const double c = std::cos(angle), s = std::sin(angle);
    return {{{1.0,0.0},{0.0,1.0},{c,s},{-s,c}}};
}

// Exact open positive-overlap interval under constant translation. Four SAT
// axes suffice for a fixed-orientation rectangle and unit square throughout
// the continuous sweep. An empty interval is distinct from a touching instant.
inline Interval interval(const Pair& pair, const std::array<Vec, 4>& directions,
                         Vec translation, double margin = 0.0) noexcept {
    Interval result;
    for (std::size_t a = 0; a < directions.size(); ++a) {
        const double speed = dot(translation, directions[a]);
        const double radius = pair.radius[a] + margin;
        if (speed == 0.0) {
            if (std::abs(pair.center[a]) >= radius) return {0.0,0.0,false};
            continue;
        }
        double first = (pair.center[a] - radius) / speed;
        double last = (pair.center[a] + radius) / speed;
        if (first > last) std::swap(first,last);
        result.begin = std::max(result.begin, first);
        result.end = std::min(result.end, last);
        if (result.begin >= result.end) return {0.0,0.0,false};
    }
    return result;
}

inline double depth(const Pair& pair, const std::array<Vec, 4>& directions,
                    Vec translation, double distance) noexcept {
    double result = std::numeric_limits<double>::infinity();
    for (std::size_t a = 0; a < directions.size(); ++a)
        result = std::min(result, pair.radius[a] -
            std::abs(pair.center[a] - dot(translation,directions[a]) * distance));
    return std::max(0.0,result);
}

// The depth is min(r_a +/- (c_a-v_a*t)): the lower envelope of eight
// affine functions. Its maximum on a closed interval is at an endpoint or
// an intersection of two affine functions. This is a continuous check, not
// a sampled-step estimate or a conclusion from the final pose alone.
inline double maximum_depth(const Pair& pair, const std::array<Vec, 4>& directions,
                            Vec translation, double stop) noexcept {
    std::array<double, 8> constant{}, slope{};
    for (std::size_t a = 0; a < directions.size(); ++a) {
        constant[a*2] = pair.radius[a] + pair.center[a];
        constant[a*2+1] = pair.radius[a] - pair.center[a];
        slope[a*2] = -dot(translation,directions[a]);
        slope[a*2+1] = -slope[a*2];
    }
    double maximum = std::max(depth(pair,directions,translation,0.0),
                               depth(pair,directions,translation,stop));
    for (std::size_t a = 0; a < constant.size(); ++a)
        for (std::size_t b = a+1; b < constant.size(); ++b) {
            const double denominator = slope[a] - slope[b];
            if (denominator == 0.0) continue;
            const double at = (constant[b] - constant[a]) / denominator;
            if (std::isfinite(at) && at >= 0.0 && at <= stop)
                maximum = std::max(maximum,depth(pair,directions,translation,at));
        }
    return maximum;
}

inline Witness witness(const Pair& pair, Interval range = {}, double d = 0.0) noexcept {
    return {true,pair.proxy,pair.x,pair.y,pair.material,range.begin,range.end,d};
}

inline Result analyze(std::span<const SourceShape> source, Pose pose, const Field& field,
                      Workspace& work, double remaining = maximum_distance) noexcept {
    Result result;
    if (source.empty() || source.size() > max_proxies || !finite(pose.origin) ||
        !finite(pose.source_com) || !std::isfinite(pose.angle) ||
        !std::isfinite(remaining) || remaining < 0.0 || remaining > maximum_distance ||
        field.width <= 0 || field.height <= 0 || field.width > 1024 || field.height > 1024 ||
        field.x < 0 || field.y < 0 || field.x > 1024-field.width || field.y > 1024-field.height ||
        field.cells.size() != static_cast<std::size_t>(field.width)*field.height) return result;
    if (remaining == 0.0) { result.outcome="DistanceBudgetExhausted"; return result; }
    std::array<Rect,max_proxies> rectangles{};
    std::array<std::array<std::int32_t,4>,max_proxies> bounds{};
    const auto basis = axes(pose.angle);
    const auto u=basis[2], v=basis[3];
    for (std::size_t i=0;i<source.size();++i) {
        const auto& shape=source[i];
        if (shape.width <= 0 || shape.height <= 0 || shape.width > 64 || shape.height > 64 ||
            shape.x < 0 || shape.y < 0 || shape.x > 1024-shape.width || shape.y > 1024-shape.height)
            return result;
        for (std::size_t j=0;j<i;++j) {
            const auto& other=source[j];
            if (shape.x < other.x+other.width && other.x < shape.x+shape.width &&
                shape.y < other.y+other.height && other.y < shape.y+shape.height) {
                result.outcome="OverlappingSiblings"; return result;
            }
        }
        const Vec local{shape.x+0.5*shape.width-pose.source_com.x,
                        shape.y+0.5*shape.height-pose.source_com.y};
        const Rect rect{{pose.origin.x+u.x*local.x+v.x*local.y,
                          pose.origin.y+u.y*local.x+v.y*local.y},
                         {0.5*shape.width,0.5*shape.height},pose.angle};
        rectangles[i]=rect;
        const double ex=std::abs(u.x)*rect.half_size.x+std::abs(v.x)*rect.half_size.y;
        const double ey=std::abs(u.y)*rect.half_size.x+std::abs(v.y)*rect.half_size.y;
        const double x0=std::floor(rect.center.x-ex-remaining-clearance);
        const double y0=std::floor(rect.center.y-ey-remaining-clearance);
        const double x1=std::ceil(rect.center.x+ex+remaining+clearance);
        const double y1=std::ceil(rect.center.y+ey+remaining+clearance);
        if (!std::isfinite(x0) || !std::isfinite(y0) || !std::isfinite(x1) || !std::isfinite(y1) ||
            x0 < field.x || y0 < field.y || x1 > field.x+field.width || y1 > field.y+field.height) {
            result.outcome="UnknownBoundary"; return result;
        }
        const auto required=static_cast<std::size_t>(x1-x0)*static_cast<std::size_t>(y1-y0);
        if (required > max_pairs-result.geometry_probes) { result.outcome="GeometryCapacity"; return result; }
        result.geometry_probes+=required;
        bounds[i]={static_cast<std::int32_t>(x0),static_cast<std::int32_t>(y0),
                   static_cast<std::int32_t>(x1),static_cast<std::int32_t>(y1)};
    }
    for (std::size_t i=0;i<source.size();++i) {
        const auto& rect=rectangles[i];
        const auto& range=bounds[i];
        for (auto y=range[1];y<range[3];++y) for (auto x=range[0];x<range[2];++x) {
            const auto material=field.cells[static_cast<std::size_t>(y-field.y)*field.width+(x-field.x)];
            if (material == unknown) { result.outcome="UnknownResidency"; return result; }
            if (material == foreign) { result.outcome="ForeignBodyOrMask"; return result; }
            if (material == empty) continue;
            if (result.pair_count == max_pairs) { result.outcome="GeometryCapacity"; return result; }
            const auto intersection=cybersand::solid_contact::intersect_unit_square(rect,x,y);
            if (intersection.outcome==cybersand::solid_contact::Outcome::Invalid) {
                result.outcome="InvalidGeometry"; return result;
            }
            Pair& pair=work.pairs[result.pair_count++];
            pair={};
            pair.x=x;pair.y=y;pair.proxy=i;pair.material=material;
            const Vec offset{x+0.5-rect.center.x,y+0.5-rect.center.y};
            for (std::size_t a=0;a<basis.size();++a) {
                pair.center[a]=dot(offset,basis[a]);
                pair.radius[a]=rect.half_size.x*std::abs(dot(u,basis[a]))+
                    rect.half_size.y*std::abs(dot(v,basis[a]))+
                    0.5*(std::abs(basis[a].x)+std::abs(basis[a].y));
            }
            pair.source_area=intersection.area;pair.source_depth=intersection.depth;
            pair.initial=intersection.outcome==cybersand::solid_contact::Outcome::Overlap &&
                intersection.area>area_filter;
            if (pair.initial) {
                ++result.initial_pairs;
                result.initial_area+=intersection.area;
                result.initial_maximum_depth=std::max(result.initial_maximum_depth,intersection.depth);
                if (material == sand) { ++result.initial_sand_pairs;result.initial_sand_area+=intersection.area; }
                else {
                    ++result.excluded_initial_pairs;result.initial_excluded_area+=intersection.area;
                    if (!result.first_excluded.present) result.first_excluded=witness(pair,{},intersection.depth);
                }
            }
        }
    }
    if (result.initial_pairs == 0) { result.outcome="NoInitialPenetration"; return result; }
    for (const auto axis : basis) for (const double sign : {1.0,-1.0}) {
        const Vec d{axis.x*sign,axis.y*sign};
        bool duplicate=false;
        for (std::size_t j=0;j<result.direction_count;++j)
            duplicate=duplicate || length(subtract(d,result.directions[j].direction))<=direction_duplicate;
        if (!duplicate) result.directions[result.direction_count++].direction=d;
    }
    for (std::size_t i=0;i<result.direction_count;++i) {
        auto& out=result.directions[i];
        // Inflate only the separation requirement by a conservative arithmetic
        // guard (not the occupied geometry). The exact final gap is rechecked.
        // An oblique exit therefore pays epsilon/|dot(direction,exit_axis)|.
        for (std::size_t j=0;j<result.pair_count;++j) {
            const auto& pair=work.pairs[j];
            const auto expanded=interval(pair,basis,out.direction,clearance+1e-10);
            if (expanded.present && expanded.begin<=0.0 && expanded.end>0.0 &&
                expanded.end>out.required_distance) {
                out.required_distance=expanded.end;out.required_by=witness(pair,expanded);
            }
        }
        const double admitted_stop=std::min(out.required_distance,remaining);
        bool new_before_escape=false, final_gap=true;
        for (std::size_t j=0;j<result.pair_count;++j) {
            const auto& pair=work.pairs[j];
            const auto overlap=interval(pair,basis,out.direction);
            const bool new_in_budget=!pair.initial && overlap.present &&
                std::max(0.0,overlap.begin)<std::min(remaining,overlap.end);
            if (new_in_budget) {
                ++out.new_pairs_within_budget;
                if (!out.first_new_pair.present || overlap.begin<out.first_new_pair.begin)
                    out.first_new_pair=witness(pair,overlap);
            }
            if (!pair.initial && overlap.present &&
                std::max(0.0,overlap.begin)<std::min(admitted_stop,overlap.end)) new_before_escape=true;
            if (pair.initial) {
                const double worst=maximum_depth(pair,basis,out.direction,admitted_stop);
                if (worst>out.maximum_swept_depth) {
                    out.maximum_swept_depth=worst;out.deepest_pair=witness(pair,overlap,worst);
                }
            }
            if (std::isfinite(out.required_distance)) {
                double gap=-std::numeric_limits<double>::infinity();
                for (std::size_t a=0;a<basis.size();++a)
                    gap=std::max(gap,std::abs(pair.center[a]-dot(out.direction,basis[a])*out.required_distance)-pair.radius[a]);
                if (gap<clearance) final_gap=false;
            }
        }
        if (result.excluded_initial_pairs != 0) out.outcome="InitialExcludedOverlap";
        else if (!std::isfinite(out.required_distance) || out.required_distance>remaining) out.outcome="BeyondDistanceBudget";
        else if (new_before_escape) out.outcome="NewPairOnContinuousSweep";
        else if (out.maximum_swept_depth>result.initial_maximum_depth+additional_depth) out.outcome="DepthLimitOnContinuousSweep";
        else if (!final_gap) out.outcome="FinalSeparationUnproven";
        else { out.outcome="GeometryOnlyRoute";out.geometric_route=true;++result.geometric_routes; }
    }
    if (result.excluded_initial_pairs != 0) { result.outcome="InitialExcludedOverlap";return result; }
    if (result.geometric_routes == 0) { result.outcome="NoRegisteredCorridor";return result; }
    double shortest=std::numeric_limits<double>::infinity();
    for (std::size_t i=0;i<result.direction_count;++i)
        if (result.directions[i].geometric_route && result.directions[i].required_distance<shortest) {
            shortest=result.directions[i].required_distance;result.selected_direction=i;
        }
    std::size_t near_shortest=0;
    for (std::size_t i=0;i<result.direction_count;++i)
        if (result.directions[i].geometric_route &&
            result.directions[i].required_distance<=shortest+tie_distance) ++near_shortest;
    if (near_shortest!=1) { result.outcome="AmbiguousShortestCorridor";result.selected_direction=max_directions; }
    else result.outcome="GeometryOnlyUniqueCorridor";
    return result;
}

struct WorkReceipt {
    const char* outcome{"InvalidWorkInput"};
    bool admissible{};
    double distance{}, kinetic_change{}, potential_change{}, introduced_energy_spent{},
           residual_dissipation{}, remaining_distance{}, remaining_energy{};
};
// Formal proposed reservoir accounting only, not a live application function.
inline WorkReceipt account(double mass, Vec gravity, Vec correction, double before_kinetic,
                           double after_kinetic, double distance_left, double energy_left,
                           std::size_t corrections_used) noexcept {
    WorkReceipt r;
    const double energy_cap=mass*repair_acceleration*maximum_distance;
    if (!std::isfinite(mass)||mass<=0.0||!finite(gravity)||!finite(correction)||
        !std::isfinite(before_kinetic)||!std::isfinite(after_kinetic)||before_kinetic<0.0||after_kinetic<0.0||
        !std::isfinite(distance_left)||distance_left<0.0||distance_left>maximum_distance||
        !std::isfinite(energy_cap)||!std::isfinite(energy_left)||energy_left<0.0||energy_left>energy_cap)
        return r;
    r.distance=length(correction);
    if (r.distance<=0.0||r.distance>maximum_step||r.distance>distance_left||corrections_used>=maximum_corrections) {
        r.outcome="CorrectionBudgetRefused";return r;
    }
    if (length(gravity)>repair_acceleration) { r.outcome="GravityOutsideWorkContract";return r; }
    r.kinetic_change=after_kinetic-before_kinetic;
    r.potential_change=-mass*dot(gravity,correction);
    r.introduced_energy_spent=mass*repair_acceleration*r.distance;
    r.residual_dissipation=r.introduced_energy_spent-r.potential_change-r.kinetic_change;
    if (!std::isfinite(r.introduced_energy_spent)||!std::isfinite(r.potential_change)||!std::isfinite(r.residual_dissipation)) return r;
    // Thirty-two exact binary path increments may still accumulate last-bit
    // error in the non-binary energy scale. Preserve the registered absolute
    // numerical bound; this does not replenish or scale the reservoir.
    if (r.introduced_energy_spent>energy_left+1e-8) { r.outcome="EnergyBudgetExhausted";return r; }
    if (r.kinetic_change>1e-4*std::max(1.0,before_kinetic) || r.residual_dissipation < -1e-8*std::max(1.0,before_kinetic)) {
        r.outcome="UnaccountedMechanicalWork";return r;
    }
    r.remaining_distance=distance_left-r.distance;r.remaining_energy=std::max(0.0,energy_left-r.introduced_energy_spent);
    r.admissible=true;r.outcome="ProposedWorkAccounted";
    return r;
}
} // namespace sol364b
