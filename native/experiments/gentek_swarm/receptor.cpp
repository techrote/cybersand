#include "swarm.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <limits>
#include <numeric>
#include <tuple>
#include <utility>

namespace cybersand::gentek_swarm {
namespace {

constexpr std::array<Point, 4> kDirections{{{1, 0}, {0, 1}, {-1, 0}, {0, -1}}};
constexpr Material kShell = Material::ReinforcedConcrete;
constexpr Material kRib = Material::SteelPipe;
constexpr Material kCohesion = Material::LimePlaster;

Point plus(Point a, Point b) { return {a.x + b.x, a.y + b.y}; }
Point minus(Point a, Point b) { return {a.x - b.x, a.y - b.y}; }
int manhattan(Point a, Point b) { return std::abs(a.x - b.x) + std::abs(a.y - b.y); }
int sign(int v) { return (v > 0) - (v < 0); }
std::uint64_t point_key(const Request& q, Point p, std::uint64_t salt) {
    return mix(q.seed ^ salt ^ (std::uint64_t(std::uint32_t(p.x)) << 32) ^
               std::uint32_t(p.y));
}
bool empty_at(const Request& q, const Result& r, Point p, bool transition_only) {
    return allowed(q, p) && (!transition_only || transition_at(q, p)) &&
           r.cells[index(q, p)] == Material::Empty;
}
bool material_at(const Request& q, const Result& r, Point p) {
    if (!inside(q, p)) return false;
    const auto i = index(q, p);
    return r.cells[i] != Material::Empty || (q.profile.environment_affinity > 0.0 &&
           ((!q.context.empty() && q.context[i] != Material::Empty) ||
            (!q.neighbor_cells.empty() && q.neighbor_cells[i] != Material::Empty)));
}
bool close_to_required(const Request& q, Point p) {
    for (const auto& a : q.neighbors.hard) {
        if (!a.required) continue;
        const int x = std::clamp(p.x, std::min(a.a.x, a.b.x), std::max(a.a.x, a.b.x));
        const int y = std::clamp(p.y, std::min(a.a.y, a.b.y), std::max(a.a.y, a.b.y));
        if (manhattan(p, {x, y}) <= 2) return true;
    }
    return false;
}

// Distances are exact finite four-neighbour mask distances, not Euclidean SDFs.
// Row-major source admission and fixed neighbour order resolve every tie.
// The field is discarded before return; no live-world or mutable input access.
struct Field {
    std::vector<int> distance, source;
    std::size_t source_count{};
    bool complete = true;
};
Field make_field(const Request& q, Result& r) {
    const auto n = std::size_t(q.width) * q.height;
    Field field;
    field.distance.assign(n, q.width + q.height + 1);
    field.source.assign(n, -1);
    std::vector<int> queue;
    queue.reserve(n);
    for (std::size_t i = 0; i < n; ++i) {
        if (!charge(q, r)) { field.complete = false; return field; }
        if ((q.context.empty() || q.context[i] == Material::Empty) &&
            (q.neighbor_cells.empty() || q.neighbor_cells[i] == Material::Empty)) continue;
        field.distance[i] = 0;
        field.source[i] = int(i);
        queue.push_back(int(i));
    }
    field.source_count = queue.size();
    r.metrics["field_sources"] += field.source_count;
    for (std::size_t head = 0; head < queue.size(); ++head) {
        const int i = queue[head];
        const Point p{i % q.width, i / q.width};
        ++r.metrics["field_queue_pops"];
        for (const auto d : kDirections) {
            if (!charge(q, r)) { field.complete = false; return field; }
            const auto next = plus(p, d);
            if (!inside(q, next)) continue;
            const auto ni = index(q, next);
            if (field.source[ni] != -1) continue;
            field.distance[ni] = field.distance[std::size_t(i)] + 1;
            field.source[ni] = field.source[std::size_t(i)];
            queue.push_back(int(ni));
        }
    }
    r.metrics["field_queued_cells"] += queue.size();
    return field;
}

Point source_point(const Request& q, const Field& field, Point p) {
    const int s = field.source[index(q, p)];
    return s < 0 ? p : Point{s % q.width, s / q.width};
}

// A complete growth event is planned first and then committed. It is not a
// reusable part with sockets: its shape comes from the sampled field or seed.
bool commit_growth(const Request& q, Result& r, std::vector<Point> points,
                   const std::string& kind, const std::string& reason,
                   Material material, Role role, bool structural,
                   bool transition_only) {
    std::sort(points.begin(), points.end());
    points.erase(std::unique(points.begin(), points.end()), points.end());
    if (points.size() < (structural ? 3u : 1u)) {
        ++r.rejected["growth_too_short"];
        return false;
    }
    if (r.instances.size() >= q.limits.max_instances) {
        ++r.rejected["instance_limit"];
        return false;
    }
    for (const auto p : points) {
        if (!charge(q, r)) return false;
        if (!empty_at(q, r, p, transition_only)) {
            ++r.rejected["planned_growth_collision"];
            return false;
        }
    }
    const auto id = std::uint32_t(r.instances.size() + 1);
    Instance instance;
    instance.id = id;
    instance.kind = kind;
    Point lo = points.front(), hi = lo;
    for (const auto p : points) {
        lo.x = std::min(lo.x, p.x); lo.y = std::min(lo.y, p.y);
        hi.x = std::max(hi.x, p.x); hi.y = std::max(hi.y, p.y);
    }
    instance.origin = {(lo.x + hi.x) / 2, (lo.y + hi.y) / 2};
    instance.orientation = hi.y - lo.y > hi.x - lo.x ? 1 : 0;
    instance.structural = structural;
    instance.cells = points;
    instance.reason = reason;
    r.instances.push_back(std::move(instance));
    for (const auto p : points) {
        // Validity and work were admitted for the entire immutable footprint.
        write_cell(q, r, p, material, role, id);
    }
    ++r.metrics[structural ? "growth_events" : "cohesion_patches"];
    return true;
}

std::vector<Point> contour_patch(const Request& q, Result& r, const Field& field,
                                 Point root, bool transition_only) {
    const int radius = 8 + int(6 * q.profile.variation);
    const int width = q.profile.clutter > 0.55 ? 2 : 1;
    const int target = field.distance[index(q, root)];
    const auto local_cap = std::min<std::size_t>(128, q.limits.max_frontier);
    if (local_cap < 3) {
        r.status = Status::Exhausted;
        r.termination = "local growth frontier capacity exhausted";
        return {};
    }
    std::vector<Point> queue{root};
    std::vector<std::uint8_t> seen(std::size_t(q.width) * q.height);
    seen[index(q, root)] = 1;
    // A local isodistance band is an irregular surface shell. Flooding is
    // bounded by a small envelope and at most 128 accepted shell cells.
    for (std::size_t head = 0; head < queue.size() && queue.size() < local_cap; ++head) {
        for (const auto d : kDirections) {
            if (!candidate(q, r)) return {};
            const auto p = plus(queue[head], d);
            if (!inside(q, p) || manhattan(p, root) > radius) continue;
            const auto i = index(q, p);
            if (seen[i] || !empty_at(q, r, p, transition_only)) continue;
            const int delta = field.distance[i] - target;
            if (delta < 0 || delta > width) continue;
            // The irregularity channel introduces sparse edge notches; roots
            // and the closest surface contour remain intact.
            if (delta && unit(point_key(q, p, 0x93a611)) < q.profile.irregularity * 0.2)
                continue;
            seen[i] = 1;
            queue.push_back(p);
            if (queue.size() == local_cap) break;
        }
    }
    return queue;
}

void grow_surface_rib(const Request& q, Result& r, const Field& field, Point root,
                      bool transition_only, std::uint32_t parent) {
    const auto source = source_point(q, field, root);
    auto normal = minus(root, source);
    if (std::abs(normal.x) >= std::abs(normal.y)) normal = {sign(normal.x), 0};
    else normal = {0, sign(normal.y)};
    if (!normal.x && !normal.y) return;
    const auto tangent = Point{-normal.y, normal.x};
    const int length = 4 + int(10 * q.profile.branching);
    std::vector<Point> cells;
    Point p = root;
    for (int step = 0; step < length; ++step) {
        if (!candidate(q, r)) return;
        p = plus(p, normal);
        if (!empty_at(q, r, p, transition_only)) break;
        cells.push_back(p);
        if (step > 1 && step % 4 == 0 && q.profile.irregularity > 0.45) {
            const auto bend = plus(p, tangent);
            if (empty_at(q, r, bend, transition_only)) {
                cells.push_back(bend);
                p = bend;
            }
        }
    }
    if (commit_growth(q, r, std::move(cells), "normal-buttress",
                      "bounded outward growth along the immutable nearest-surface normal",
                      kRib, transition_only ? Role::Transition : Role::Brace, true,
                      transition_only)) {
        r.attachments.push_back({std::uint32_t(r.instances.size()),
                                 plus(root, normal), root,
                                 "local-growth", "rib grows from surface shell " + std::to_string(parent)});
        ++r.metrics["normal_ribs"];
    }
}

void surface_growth(const Request& q, Result& r, const Field& field, bool transition_only,
                    std::size_t event_limit) {
    if (!field.source_count || !field.complete) return;
    std::vector<Point> sites;
    for (int y = 0; y < q.height; ++y) for (int x = 0; x < q.width; ++x) {
        if (!charge(q, r)) return;
        const Point p{x, y};
        if (field.distance[index(q, p)] == 1 && empty_at(q, r, p, transition_only))
            sites.push_back(p);
    }
    std::sort(sites.begin(), sites.end(), [&](Point a, Point b) {
        return std::tuple{point_key(q, a, 0x717ee11), a} <
               std::tuple{point_key(q, b, 0x717ee11), b};
    });
    std::vector<Point> admitted;
    const auto starting_instances = r.instances.size();
    for (const auto site : sites) {
        if (r.instances.size() - starting_instances >= event_limit ||
            r.instances.size() >= q.limits.max_instances || r.status == Status::Exhausted) break;
        if (!candidate(q, r)) break;
        if (!empty_at(q, r, site, transition_only)) continue;
        if (std::any_of(admitted.begin(), admitted.end(), [&](Point p) {
                return manhattan(p, site) < 13;
            })) continue;
        if (unit(point_key(q, site, 0x5311aff1)) > q.profile.environment_affinity) continue;
        const auto points = contour_patch(q, r, field, site, transition_only);
        if (r.status == Status::Exhausted) break;
        if (!commit_growth(q, r, points, "surface-shell",
                           "connected local isodistance contour of immutable existing material",
                           kShell, transition_only ? Role::Transition : Role::Structure,
                           true, transition_only)) continue;
        admitted.push_back(site);
        const auto id = std::uint32_t(r.instances.size());
        const auto target = source_point(q, field, site);
        const bool foreign = !q.neighbor_cells.empty() &&
                             q.neighbor_cells[index(q, target)] != Material::Empty;
        r.attachments.push_back({id, site, target, foreign ? "foreign-surface" : "environment-surface",
                                 "direct adjacent cell contact; not a certified mechanical frame joint"});
        ++r.metrics["environment_bound_growth"];
        if (foreign) ++r.metrics["foreign_surface_contacts"];
        if (q.profile.branching > 0.15 && r.instances.size() - starting_instances < event_limit) {
            // Find an exposed outer shell cell nearest this source root.
            const auto normal = minus(site, target);
            Point tip = site;
            for (int k = 0; k < 3; ++k) {
                const auto next = plus(tip, normal);
                if (!inside(q, next) || r.cells[index(q, next)] == Material::Empty) break;
                tip = next;
            }
            grow_surface_rib(q, r, field, tip, transition_only, id);
        }
    }
}

std::vector<Point> intrinsic_shell(const Request& q, Point center, std::uint64_t key) {
    // Integer parabolic level-set extraction gives an autonomous shell seed.
    // It deliberately knows nothing about context. A collision rejects the
    // event; it never reorients or attracts the affinity-zero architecture.
    const int rx = 7 + int((key >> 8) % 4);
    const int ry = 5 + int((key >> 16) % 4);
    const int skew = int(q.profile.irregularity * 3) * ((key & 1) ? 1 : -1);
    std::vector<Point> cells;
    Point previous{};
    for (int dx = -rx; dx <= rx; ++dx) {
        const int y = center.y - ry + (dx * dx * ry) / (rx * rx) +
                      (skew * (dx + rx)) / (2 * rx);
        const Point p{center.x + dx, y};
        if (dx == -rx) cells.push_back(p);
        else {
            const auto segment = line(previous, p);
            cells.insert(cells.end(), segment.begin(), segment.end());
        }
        previous = p;
    }
    const int leg = 3 + int(q.profile.branching * 5);
    for (const int side : {-1, 1}) {
        const int y = center.y + (side == 1 ? skew : 0);
        const auto leg_cells = line({center.x + side * rx, y},
                                    {center.x + side * rx, y + leg});
        cells.insert(cells.end(), leg_cells.begin(), leg_cells.end());
    }
    if (q.profile.branching > 0.55) {
        // Independent interior radial rib changes topology, not shell scale.
        const int dx = (key & 2) ? rx / 2 : -rx / 2;
        const int y = center.y - ry + (dx * dx * ry) / (rx * rx) +
                      (skew * (dx + rx)) / (2 * rx);
        const auto rib = line({center.x + dx, y}, {center.x + dx - skew, center.y + leg / 2});
        cells.insert(cells.end(), rib.begin(), rib.end());
    }
    return cells;
}

void intrinsic_growth(const Request& q, Result& r, std::size_t target_instances) {
    std::vector<Point> sites;
    const int spacing_x = 26;
    const int spacing_y = 24;
    for (int y = 13; y < q.height - 8; y += spacing_y)
        for (int x = 13; x < q.width - 10; x += spacing_x) sites.push_back({x, y});
    std::sort(sites.begin(), sites.end(), [&](Point a, Point b) {
        return std::tuple{point_key(q, a, 0x10ca1), a} <
               std::tuple{point_key(q, b, 0x10ca1), b};
    });
    for (auto center : sites) {
        if (r.instances.size() >= target_instances) break;
        if (r.instances.size() >= q.limits.max_instances) {
            r.status = Status::Exhausted;
            r.termination = "growth instance capacity exhausted";
            break;
        }
        if (!candidate(q, r)) return;
        const auto key = point_key(q, center, 0x51ee11);
        center.x += int(q.profile.irregularity * (int(key % 9) - 4));
        center.y += int(q.profile.irregularity * (int((key >> 8) % 7) - 3));
        auto shell = intrinsic_shell(q, center, key);
        commit_growth(q, r, std::move(shell), "intrinsic-shell",
                      "seeded integer level-set shell; context is only a collision fact",
                      kShell, Role::Structure, true, false);
        if (r.status == Status::Exhausted) return;
    }
}

void residual_cohesion(const Request& q, Result& r, bool transition_only) {
    if (q.profile.cohesion <= 0.0 || r.status == Status::Exhausted || r.instances.empty() ||
        q.limits.max_cohesion_patches == 0 || q.limits.max_cohesion_cells_per_patch == 0) return;
    const auto n = std::size_t(q.width) * q.height;
    std::vector<std::uint8_t> residual(n), seen(n);
    const int reach = 2 + int(3 * q.profile.cohesion);
    // Freeze the residual domain before growing a patch. Newly placed fill
    // never causes another cell to become eligible, so there is no flood creep.
    for (int y = 0; y < q.height; ++y) for (int x = 0; x < q.width; ++x) {
        if (!charge(q, r, std::uint64_t(1 + 4 * reach))) return;
        const Point p{x, y};
        if (!empty_at(q, r, p, transition_only) || close_to_required(q, p)) continue;
        std::array<bool, 4> contact{};
        int immediate = 0;
        for (std::size_t d = 0; d < kDirections.size(); ++d) {
            auto s = p;
            for (int step = 1; step <= reach; ++step) {
                s = plus(s, kDirections[d]);
                if (!inside(q, s)) break;
                if ((!q.protected_void.empty() && q.protected_void[index(q, s)]) ||
                    (!q.neighbors.protected_geometry.empty() && q.neighbors.protected_geometry[index(q, s)])) break;
                if (material_at(q, r, s)) {
                    contact[d] = true;
                    if (step == 1) ++immediate;
                    break;
                }
            }
        }
        const bool slot = (contact[0] && contact[2]) || (contact[1] && contact[3]);
        const bool concavity = immediate >= 2;
        if ((slot || concavity) && immediate &&
            unit(point_key(q, p, 0xc011e51)) < 0.35 + 0.65 * q.profile.cohesion)
            residual[index(q, p)] = 1;
    }
    std::uint32_t patches = std::uint32_t(r.metrics["cohesion_patches"]);
    for (std::size_t i = 0; i < n && patches < q.limits.max_cohesion_patches; ++i) {
        if (!residual[i] || seen[i]) continue;
        if (!candidate(q, r)) return;
        const Point seed{int(i % q.width), int(i / q.width)};
        const int radius = 3 + int(q.profile.cohesion * 4);
        std::vector<Point> queue{seed};
        seen[i] = 1;
        for (std::size_t head = 0; head < queue.size(); ++head) {
            if (queue.size() >= q.limits.max_cohesion_cells_per_patch) break;
            for (const auto d : kDirections) {
                if (!charge(q, r)) return;
                const auto p = plus(queue[head], d);
                if (!inside(q, p) || manhattan(p, seed) > radius) continue;
                const auto pi = index(q, p);
                if (!residual[pi] || seen[pi]) continue;
                seen[pi] = 1;
                queue.push_back(p);
                if (queue.size() == q.limits.max_cohesion_cells_per_patch) break;
            }
        }
        if (commit_growth(q, r, queue, "residual-cohesion",
                          "non-structural frozen concavity/slot fill in a bounded local envelope",
                          kCohesion, Role::Cohesion, false, transition_only)) {
            ++patches;
            r.metrics["cohesion_fill_cells"] += queue.size();
        }
        if (r.status == Status::Exhausted) return;
    }
}

void export_surfaces(const Request& q, Result& r) {
    r.boundary.hard.clear();
    r.boundary.soft.clear();
    for (const auto& inst : r.instances) {
        if (!inst.structural) continue;
        std::vector<Point> points;
        for (const auto p : inst.cells)
            if (inside(q, p) && transition_at(q, p) && r.cells[index(q, p)] != Material::Empty &&
                r.roles[index(q, p)] != Role::Cohesion) points.push_back(p);
        if (points.empty()) continue;
        std::sort(points.begin(), points.end(), [](Point a, Point b) {
            return std::tie(a.y, a.x) < std::tie(b.y, b.x);
        });
        // Export at most two actual contiguous horizontal runs, never a
        // bounding-box segment crossing a hole or decorative cohesion.
        std::size_t exported = 0;
        for (std::size_t j = 0; j < points.size() && exported < 2;) {
            const auto start = points[j];
            auto end = start;
            std::size_t k = j + 1;
            while (k < points.size() && points[k].y == end.y && points[k].x == end.x + 1) {
                end = points[k++];
            }
            j = k;
            if (r.boundary.hard.size() >= q.limits.max_affordances) break;
            Point facing{};
            for (const auto d : kDirections) {
                const auto p = plus(start, d);
                if (inside(q, p) && !q.eligible.empty() && !q.eligible[index(q, p)]) { facing = d; break; }
            }
            const auto id = std::uint32_t(r.boundary.hard.size() + 1);
            r.boundary.hard.push_back({id, inst.id, start, end, facing, Family::Surface,
                                       false, 0.7, "receptor.actual-surface"});
            r.boundary.soft.push_back({start, facing, q.profile.cohesion,
                                       "surface-adjacent non-structural cohesion"});
            ++exported;
        }
    }
    r.metrics["surface_affordances"] = r.boundary.hard.size();
}

} // namespace

Result generate_receptor(const Request& q) {
    auto r = begin_result(q, "environment-morphology-v0");
    if (r.status == Status::Invalid || r.status == Status::Exhausted) return r;
    r.notes.push_back("Finite cell-distance shells and normal ribs; surface contact is not mechanical support certification.");
    const auto target = std::size_t(5 + 14 * q.profile.branching + 7 * q.profile.clutter);
    if (q.profile.environment_affinity > 0.0) {
        const auto field = make_field(q, r);
        if (field.complete) {
            const auto bound = std::size_t(std::ceil(double(target) * q.profile.environment_affinity));
            surface_growth(q, r, field, false, bound);
            if (!field.source_count) r.notes.push_back("No immutable solid sources: intrinsic shell fallback.");
        }
    } else {
        r.notes.push_back("Zero environment affinity: no context field or context-directed seed/normal selection.");
    }
    if (r.status != Status::Exhausted) intrinsic_growth(q, r, target);
    residual_cohesion(q, r, false);
    export_surfaces(q, r);
    if (r.instances.empty() && r.status == Status::Complete) {
        r.status = Status::Blocked;
        r.termination = "no admissible field growth or intrinsic shell";
    }
    finish_result(q, r);
    return r;
}

void adapt_receptor(const Request& q, Result& r) {
    if (r.status == Status::Invalid || r.status == Status::Unsat || r.status == Status::Exhausted) return;
    const auto before = r.instances.size();
    if (q.profile.environment_affinity > 0.0) {
        const auto field = make_field(q, r);
        if (field.complete) surface_growth(q, r, field, true, 12);
    }
    residual_cohesion(q, r, true);
    export_surfaces(q, r);
    r.metrics["transition_growth_events"] += r.instances.size() - before;
    if (r.status == Status::Blocked && r.instances.size() > before) {
        r.status = Status::Complete;
        r.termination = "transition-local surface growth completed";
    }
    r.notes.push_back("One transition-only adaptation pass against the frozen foreign cell snapshot; no core replacement.");
    finish_result(q, r);
}

} // namespace cybersand::gentek_swarm
