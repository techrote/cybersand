#include "swarm.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <limits>
#include <set>
#include <tuple>

namespace cybersand::gentek_swarm {
namespace {

// FRAMEWEAVER owns this small mechanical vocabulary. These are not MOSAIC
// categories, production GrammarSockets, or a general structural IR.
struct Port {
    Point point, facing;
    bool required = false;
};
struct Part {
    std::string kind;
    Material material = Material::SteelPlate;
    std::vector<Point> cells;
    std::vector<Port> ports;
    std::vector<std::pair<Point, Point>> receptors;
};
struct Frontier { std::size_t connector; unsigned depth; };
struct Placement {
    Part part;
    Point origin;
    int rotation = 0;
    std::size_t input = 0;
    double score = -std::numeric_limits<double>::infinity();
    std::uint64_t tie{};
    std::vector<std::pair<std::size_t, std::size_t>> closures{};
};

Point add(Point a, Point b) { return {a.x + b.x, a.y + b.y}; }
Point sub(Point a, Point b) { return {a.x - b.x, a.y - b.y}; }
Point neg(Point p) { return {-p.x, -p.y}; }
Point rotate(Point p, int r) {
    switch (r & 3) {
    case 1: return {-p.y, p.x};
    case 2: return {-p.x, -p.y};
    case 3: return {p.y, -p.x};
    default: return p;
    }
}
Point transformed(Point p, const Placement& c) { return add(c.origin, rotate(p, c.rotation)); }
int distance(Point a, Point b) { return std::abs(a.x - b.x) + std::abs(a.y - b.y); }
bool near_joint(Point p, Point joint) {
    return std::abs(p.x - joint.x) <= 1 && std::abs(p.y - joint.y) <= 1;
}
void deduplicate(std::vector<Point>& points) {
    std::sort(points.begin(), points.end());
    points.erase(std::unique(points.begin(), points.end()), points.end());
}
void thick_line(std::vector<Point>& cells, Point a, Point b, int radius) {
    for (auto p : line(a, b)) {
        for (int y = -radius; y <= radius; ++y) {
            for (int x = -radius; x <= radius; ++x) cells.push_back({p.x + x, p.y + y});
        }
    }
    deduplicate(cells);
}
Part member(const std::string& kind, int length) {
    Part p;
    p.kind = kind;
    p.material = Material::SteelPlate;
    thick_line(p.cells, {0, 0}, {length, 0}, 1);
    p.ports = {{{0, 0}, {-1, 0}, true}, {{length, 0}, {1, 0}, true}};
    // Receptors are actual finite portions of the accepted member centerline.
    p.receptors.push_back({{3, 0}, {length - 3, 0}});
    return p;
}
Part junction() {
    Part p;
    p.kind = "branch_junction";
    thick_line(p.cells, {-4, 0}, {4, 0}, 1);
    thick_line(p.cells, {0, -4}, {0, 4}, 1);
    p.ports = {{{-4, 0}, {-1, 0}, false}, {{4, 0}, {1, 0}, false},
               {{0, -4}, {0, -1}, false}, {{0, 4}, {0, 1}, false}};
    return p;
}
Part cap() {
    Part p;
    p.kind = "termination_cap";
    thick_line(p.cells, {0, 0}, {2, 0}, 1);
    // A transverse end plate remains visibly different from a cropped member.
    thick_line(p.cells, {2, -2}, {2, 2}, 0);
    p.ports = {{{0, 0}, {-1, 0}, true}, {{2, 0}, {1, 0}, false}};
    return p;
}

bool reserve_instance(const Request& q, Result& r) {
    if (r.instances.size() < q.limits.max_instances) return true;
    ++r.rejected["instance_limit"];
    r.status = Status::Exhausted;
    r.termination = "instance_limit";
    return false;
}

bool secondary_capacity(const Request& q, const Result& r) {
    const auto seam_reserve = q.limits.max_instances >= 8 ? 4U : 0U;
    return r.instances.size() < q.limits.max_instances - seam_reserve;
}

bool qualify_closures(const Request& q, Result& r, Placement& c, std::size_t parent_index) {
    for (std::size_t pi = 0; pi < c.part.ports.size(); ++pi) {
        if (pi == c.input) continue;
        const auto p = transformed(c.part.ports[pi].point, c);
        const auto facing = rotate(c.part.ports[pi].facing, c.rotation);
        for (std::size_t ci = 0; ci < r.connectors.size(); ++ci) {
            if (!charge(q, r)) return false;
            const auto& socket = r.connectors[ci];
            if (ci == parent_index || socket.family != Family::Frame || socket.fulfilled) continue;
            if (socket.a == p && socket.facing == neg(facing)) {
                c.closures.push_back({pi, ci});
                break;
            }
        }
    }
    return true;
}

bool valid_placement(const Request& q, Result& r, const Placement& c,
                     const Connector* parent, bool only_transition = false) {
    std::size_t new_cells = 0;
    for (auto local : c.part.cells) {
        if (!charge(q, r)) return false;
        const auto p = transformed(local, c);
        if (!allowed(q, p) || (only_transition && !transition_at(q, p))) {
            ++r.rejected["footprint_mask_or_collision"];
            return false;
        }
        const auto i = index(q, p);
        if (r.cells[i] == Material::Empty) { ++new_cells; continue; }
        // Only the explicitly aligned input connector's 3x3 joint may share
        // existing structure. Incidental crossings do not become joints.
        bool declared_joint = parent && near_joint(p, parent->a);
        for (const auto& [port, target] : c.closures) {
            (void)port;
            declared_joint = declared_joint || near_joint(p, r.connectors[target].a);
        }
        if (!declared_joint || r.cells[i] != c.part.material || r.roles[i] == Role::Cohesion) {
            ++r.rejected["undeclared_structural_overlap"];
            return false;
        }
    }
    if (new_cells == 0) { ++r.rejected["empty_increment"] ; return false; }
    return true;
}

void add_environment_contacts(const Request& q, Result& r, std::uint32_t id,
                              const std::vector<Point>& cells) {
    // Contacts are geometric observations, never a physical load-bearing claim.
    std::set<std::pair<Point, Point>> contacts;
    constexpr std::array<Point, 4> directions{{{1, 0}, {0, 1}, {-1, 0}, {0, -1}}};
    for (auto p : cells) {
        for (auto d : directions) {
            if (!charge(q, r)) return;
            const auto t = add(p, d);
            if (inside(q, t) && !q.context.empty() && q.context[index(q, t)] != Material::Empty) {
                contacts.insert({p, t});
            }
        }
    }
    if (!contacts.empty()) {
        const auto [p, t] = *contacts.begin();
        r.attachments.push_back({id, p, t, "environment_surface_contact",
                                 "explicit adjacent immutable solid; geometry only"});
        ++r.metrics["environment_bound_placements"];
    }
}

std::vector<std::size_t> commit(const Request& q, Result& r, const Placement& c,
                              std::size_t parent_index, bool root = false) {
    std::vector<std::size_t> new_frontier;
    if (!reserve_instance(q, r)) return new_frontier;
    Instance instance;
    instance.id = static_cast<std::uint32_t>(r.instances.size() + 1);
    instance.kind = c.part.kind;
    instance.origin = c.origin;
    instance.orientation = c.rotation;
    instance.reason = root ? "deterministic root; no substrate required"
                           : "typed opposite-facing frame connector; whole footprint accepted";
    for (auto local : c.part.cells) instance.cells.push_back(transformed(local, c));
    const auto id = instance.id;
    for (auto p : instance.cells) {
        // Preserve original cell ownership at the narrowly qualified joint.
        if (r.cells[index(q, p)] != Material::Empty) continue;
        write_cell(q, r, p, c.part.material, Role::Structure, id);
    }
    r.instances.push_back(instance);
    const auto input_id = static_cast<std::uint32_t>(r.connectors.size() + c.input + 1);
    for (std::size_t i = 0; i < c.part.ports.size(); ++i) {
        const auto& p = c.part.ports[i];
        Connector socket;
        socket.id = static_cast<std::uint32_t>(r.connectors.size() + 1);
        socket.instance = id;
        socket.a = socket.b = transformed(p.point, c);
        socket.facing = rotate(p.facing, c.rotation);
        socket.required = p.required;
        const auto closure = std::find_if(c.closures.begin(), c.closures.end(),
                                         [&](const auto& pair) { return pair.first == i; });
        if (!root && i == c.input) {
            socket.required = true;
            socket.fulfilled = true;
            socket.counterpart = r.connectors[parent_index].id;
            socket.state = "joined";
        } else if (closure != c.closures.end()) {
            socket.fulfilled = true;
            socket.counterpart = r.connectors[closure->second].id;
            socket.state = "joined";
            r.connectors[closure->second].fulfilled = true;
            r.connectors[closure->second].counterpart = socket.id;
            r.connectors[closure->second].state = "joined";
            ++r.metrics["closed_frame_loops"];
        } else if (c.part.kind == "termination_cap") {
            socket.state = "terminal_plate";
        } else {
            new_frontier.push_back(r.connectors.size());
        }
        r.connectors.push_back(socket);
    }
    if (!root) {
        auto& parent = r.connectors[parent_index];
        parent.fulfilled = true;
        parent.counterpart = input_id;
        parent.state = c.part.kind == "termination_cap" ? "terminated" : "joined";
    }
    for (const auto& [a, b] : c.part.receptors) {
        Connector receptor;
        receptor.id = static_cast<std::uint32_t>(r.connectors.size() + 1);
        receptor.instance = id;
        receptor.family = Family::Brace;
        receptor.a = transformed(a, c);
        receptor.b = transformed(b, c);
        receptor.facing = rotate({0, 1}, c.rotation);
        r.connectors.push_back(receptor);
    }
    add_environment_contacts(q, r, id, instance.cells);
    ++r.metrics["accepted_" + c.part.kind];
    return new_frontier;
}

// Root ranking examines only immutable inputs; activation is a location hint.
bool plant_root(const Request& q, Result& r, std::vector<Frontier>& frontier) {
    Point desired = q.activation.empty() ? Point{q.width / 2, q.height * 2 / 3} : q.activation.front();
    long long sx = 0, sy = 0, eligible = 0;
    for (int y = 0; y < q.height; ++y) {
        for (int x = 0; x < q.width; ++x) {
            if (!charge(q, r)) return false;
            if (allowed(q, {x, y})) { sx += x; sy += y; ++eligible; }
        }
    }
    if (eligible == 0) return false;
    if (q.activation.empty()) desired = {static_cast<int>(sx / eligible), static_cast<int>(sy / eligible)};
    std::vector<std::pair<std::uint64_t, Point>> roots;
    // A stride-three candidate lattice is a bounded root search, not architecture.
    for (int y = 5; y < q.height - 5; y += 3) {
        for (int x = 5; x < q.width - 5; x += 3) {
            if (!charge(q, r)) return false;
            if (!allowed(q, {x, y})) continue;
            int affinity = 0;
            if (q.profile.environment_affinity > 0 && !q.context.empty()) {
                for (Point d : std::array<Point, 4>{{{0, 6}, {6, 0}, {0, -6}, {-6, 0}}}) {
                    const auto p = add({x, y}, d);
                    if (inside(q, p) && q.context[index(q, p)] != Material::Empty) ++affinity;
                }
            }
            const int rank = std::max(0, distance({x, y}, desired) -
                                           static_cast<int>(affinity * 24 * q.profile.environment_affinity));
            const auto tie = mix(q.seed ^ static_cast<std::uint64_t>(x + y * q.width)) & 1023;
            roots.push_back({static_cast<std::uint64_t>(rank) * 1024 + tie, {x, y}});
        }
    }
    std::sort(roots.begin(), roots.end());
    for (const auto& [rank, p] : roots) {
        (void)rank;
        if (!candidate(q, r)) return false;
        Placement root{junction(), p, 0, 0};
        if (valid_placement(q, r, root, nullptr)) {
            for (auto i : commit(q, r, root, 0, true)) frontier.push_back({i, 0});
            return !frontier.empty();
        }
    }
    return false;
}

double candidate_score(const Request& q, const Result& r, const Placement& c,
                       const Connector& host, unsigned depth) {
    const bool horizontal = host.facing.x != 0;
    const bool is_junction = c.part.kind == "branch_junction";
    const double draw = unit(mix(q.seed ^ (static_cast<std::uint64_t>(host.id) << 16)));
    const double junction_chance = 0.16 + 0.44 * q.profile.branching;
    const bool regular_bay = q.profile.irregularity < 0.2 && horizontal && depth % 3 == 1;
    const bool want_junction = regular_bay || (depth % 3 == 1 && draw < junction_chance) ||
                               (q.profile.branching > 0.7 && depth % 4 == 2 && draw < 0.5);
    double score = is_junction ? (want_junction ? 35.0 : -20.0) : (want_junction ? 0.0 : 15.0);
    if (!is_junction) {
        score += ((horizontal && c.part.kind == "beam_span") ||
                  (!horizontal && c.part.kind == "post_support")) ? 12.0 : -30.0;
        const int length = distance(c.part.ports[0].point, c.part.ports[1].point);
        const int desired = (c.part.kind == "beam_span" ? 16 : 12) +
                            (q.profile.variation > 0.4 ? (static_cast<int>((c.tie >> 10) % 3) - 1) * 4 : 0);
        score -= std::abs(length - desired) * 2.0;
    }
    score += q.profile.irregularity * (unit(c.tie) - 0.5) * 24.0;
    score += 30.0 * static_cast<double>(c.closures.size());
    // Foreign influence stays soft: it cannot relax any placement/collision rule.
    if (q.profile.environment_affinity > 0 && !q.neighbors.hard.empty()) {
        for (const auto& offer : q.neighbors.hard) {
            if (offer.family != Family::Frame && offer.family != Family::Surface) continue;
            for (std::size_t i = 0; i < c.part.ports.size(); ++i) {
                if (i == c.input) continue;
                const auto p = transformed(c.part.ports[i].point, c);
                const auto d = distance(p, offer.a);
                if (d <= 24 && transition_at(q, p)) score += (24 - d) * 0.35 * q.profile.environment_affinity;
            }
        }
    }
    (void)r;
    return score;
}

void terminate_connector(const Request& q, Result& r, std::size_t ci) {
    if (r.connectors[ci].fulfilled || r.connectors[ci].state == "terminal_plate" ||
        r.status == Status::Exhausted) return;
    const auto host = r.connectors[ci];
    Placement end{cap(), {}, 0, 0};
    for (int rotation = 0; rotation < 4; ++rotation) {
        if (rotate(end.part.ports[0].facing, rotation) != neg(host.facing)) continue;
        if (!candidate(q, r)) return;
        end.rotation = rotation;
        end.origin = host.a;
        if (valid_placement(q, r, end, &host)) {
            commit(q, r, end, ci);
            return;
        }
    }
    r.connectors[ci].state = host.required ? "unresolved" : "open";
    if (host.required) ++r.rejected["mandatory_joint_cannot_cap"];
}

bool point_on_segment(Point p, Point a, Point b) {
    const auto cross = static_cast<long long>(p.x - a.x) * (b.y - a.y) -
                       static_cast<long long>(p.y - a.y) * (b.x - a.x);
    return cross == 0 && p.x >= std::min(a.x, b.x) && p.x <= std::max(a.x, b.x) &&
           p.y >= std::min(a.y, b.y) && p.y <= std::max(a.y, b.y);
}

// Secondary braces are chosen between two independently declared segment
// receptors. A nearby occupied cell alone never qualifies as a brace endpoint.
void reinforce(const Request& q, Result& r) {
    std::vector<std::size_t> receptors;
    for (std::size_t i = 0; i < r.connectors.size(); ++i) {
        if (r.connectors[i].family == Family::Brace) receptors.push_back(i);
    }
    const unsigned budget = static_cast<unsigned>(2 + 8 * q.profile.branching + 6 * q.profile.clutter);
    unsigned accepted = 0;
    for (std::size_t a = 0; a < receptors.size() && accepted < budget; ++a) {
        for (std::size_t b = a + 1; b < receptors.size() && accepted < budget; ++b) {
            if (r.status == Status::Exhausted || !secondary_capacity(q, r)) return;
            const auto ra = r.connectors[receptors[a]], rb = r.connectors[receptors[b]];
            if (ra.instance == rb.instance) continue;
            const Point pa{(ra.a.x + ra.b.x) / 2, (ra.a.y + ra.b.y) / 2};
            const Point pb{(rb.a.x + rb.b.x) / 2, (rb.a.y + rb.b.y) / 2};
            if (!point_on_segment(pa, ra.a, ra.b) || !point_on_segment(pb, rb.a, rb.b) ||
                pa.x == pb.x || pa.y == pb.y || distance(pa, pb) < 8 || distance(pa, pb) > 30) continue;
            if (!candidate(q, r)) return;
            auto cells = line(pa, pb);
            bool valid = true;
            unsigned fresh = 0;
            for (auto p : cells) {
                if (!charge(q, r)) return;
                if (!allowed(q, p)) { valid = false; break; }
                const auto idx = index(q, p);
                if (r.cells[idx] == Material::Empty) { ++fresh; continue; }
                const bool endpoint = (distance(p, pa) <= 4 && r.provenance[idx] == ra.instance) ||
                                      (distance(p, pb) <= 4 && r.provenance[idx] == rb.instance);
                if (!endpoint || r.roles[idx] == Role::Cohesion) { valid = false; break; }
            }
            if (!valid || fresh < 4) { ++r.rejected["brace_requires_two_clear_receptors"]; continue; }
            Instance brace;
            brace.id = static_cast<std::uint32_t>(r.instances.size() + 1);
            brace.kind = "diagonal_brace";
            brace.origin = pa;
            brace.cells = cells;
            brace.reason = "two qualified point-to-segment brace attachments; clear diagonal";
            for (auto p : cells) if (r.cells[index(q, p)] == Material::Empty)
                write_cell(q, r, p, Material::WroughtIron, Role::Brace, brace.id);
            r.instances.push_back(brace);
            for (const auto& [p, target] : std::array<std::pair<Point, std::size_t>, 2>{{{pa, receptors[a]}, {pb, receptors[b]}}}) {
                Connector c;
                c.id = static_cast<std::uint32_t>(r.connectors.size() + 1);
                c.instance = brace.id;
                c.family = Family::Brace;
                c.a = c.b = p;
                c.required = c.fulfilled = true;
                c.counterpart = r.connectors[target].id;
                c.state = "joined";
                r.connectors[target].fulfilled = true;
                r.connectors[target].state = "joined";
                r.connectors.push_back(c);
            }
            ++accepted;
            ++r.metrics["accepted_diagonal_brace"];
        }
    }
}

bool unresolved_near(const Request& q, const Result& r, Point p) {
    for (const auto& c : r.connectors) {
        if (c.required && !c.fulfilled && distance(c.a, p) <= 5) return true;
    }
    for (const auto& a : q.neighbors.hard) {
        if (!a.required) continue;
        const Point nearest{std::clamp(p.x, std::min(a.a.x, a.b.x), std::max(a.a.x, a.b.x)),
                            std::clamp(p.y, std::min(a.a.y, a.b.y), std::max(a.a.y, a.b.y))};
        if (distance(p, nearest) <= 5) return true;
    }
    return false;
}

void cohesion(const Request& q, Result& r, bool only_transition) {
    if (q.profile.cohesion <= 0 || r.status == Status::Exhausted) return;
    const auto intact = r.cells;
    unsigned patches = 0;
    const auto used_patches = r.metrics["cohesion_patches"];
    if (used_patches >= q.limits.max_cohesion_patches) return;
    const unsigned patch_limit = std::min(q.limits.max_cohesion_patches - static_cast<unsigned>(used_patches),
                                         static_cast<unsigned>(1 + q.profile.cohesion * 7));
    // Fill only tiny concave gaps beside an existing mechanical junction. Each
    // envelope is fixed before a four-connected flood; no newly filled cell
    // enlarges its envelope or provides a structural receptor.
    const auto pre_fill_instances = r.instances;
    for (const auto& center_instance : pre_fill_instances) {
        if (patches >= patch_limit || !secondary_capacity(q, r)) break;
        if (center_instance.kind != "branch_junction") continue;
        const auto center = center_instance.origin;
        const int radius = 3 + static_cast<int>(q.profile.cohesion * 4);
        std::vector<Point> admissible;
        for (int dy = -radius; dy <= radius; ++dy) {
            for (int dx = -radius; dx <= radius; ++dx) {
                if (!charge(q, r)) return;
                Point p{center.x + dx, center.y + dy};
                if (!allowed(q, p) || (only_transition && !transition_at(q, p)) ||
                    r.cells[index(q, p)] != Material::Empty || unresolved_near(q, r, p)) continue;
                // A residual must sit between two perpendicular old members.
                bool left = false, right = false, up = false, down = false;
                for (int d = 1; d <= 3; ++d) {
                    for (int dir = 0; dir < 4; ++dir) {
                        const Point delta = std::array<Point, 4>{{{-d, 0}, {d, 0}, {0, -d}, {0, d}}}[dir];
                        const auto t = add(p, delta);
                        if (inside(q, t) && intact[index(q, t)] != Material::Empty) {
                            if (dir == 0) left = true;
                            if (dir == 1) right = true;
                            if (dir == 2) up = true;
                            if (dir == 3) down = true;
                        }
                    }
                }
                if ((left || right) && (up || down)) admissible.push_back(p);
            }
        }
        if (admissible.empty()) continue;
        std::set<Point> remaining(admissible.begin(), admissible.end());
        while (!remaining.empty() && patches < patch_limit && secondary_capacity(q, r)) {
            std::vector<Point> pending{*remaining.begin()}, accepted;
            remaining.erase(pending.front());
            for (std::size_t head = 0; head < pending.size() && accepted.size() < q.limits.max_cohesion_cells_per_patch; ++head) {
                if (!charge(q, r)) return;
                const auto p = pending[head];
                accepted.push_back(p);
                for (auto d : std::array<Point, 4>{{{1, 0}, {0, 1}, {-1, 0}, {0, -1}}}) {
                    const auto next = add(p, d);
                    if (remaining.erase(next)) pending.push_back(next);
                }
            }
            if (accepted.empty()) break;
            Instance fill;
            fill.id = static_cast<std::uint32_t>(r.instances.size() + 1);
            fill.kind = "nonstructural_cohesion";
            fill.origin = center;
            fill.structural = false;
            fill.cells = accepted;
            fill.reason = "bounded 4-connected residual envelope; no structural certification";
            for (auto p : accepted) write_cell(q, r, p, Material::SteelGrating, Role::Cohesion, fill.id);
            r.instances.push_back(fill);
            ++patches;
            ++r.metrics["cohesion_patches"];
        }
    }
}

void expose_boundary_contacts(const Request& q, Result& r) {
    const auto original_count = r.connectors.size();
    for (std::size_t ci = 0; ci < original_count; ++ci) {
        auto c = r.connectors[ci];
        if (c.family == Family::Frame && !c.fulfilled) {
            // Internal joints use the center of a finite weld area. Once the
            // primary plan is frozen, an open external socket uses its actual
            // exposed material face, so the first outward cell is truly free.
            Point face = c.a;
            for (int step = 0; step < 3; ++step) {
                const auto next = add(face, c.facing);
                if (!inside(q, next) || r.cells[index(q, next)] == Material::Empty ||
                    r.provenance[index(q, next)] != c.instance || r.roles[index(q, next)] == Role::Cohesion) break;
                face = next;
            }
            r.connectors[ci].a = r.connectors[ci].b = face;
            continue;
        }
        if (c.family != Family::Brace || c.a == c.b || c.state == "boundary_segment") continue;
        // Both exposed sides of the authored finite member receptor may accept
        // secondary external reinforcement. They are explicit new receptors,
        // not permission for the mesher to drill through the old member.
        for (int side : {-1, 1}) {
            const Point normal{c.facing.x * side, c.facing.y * side};
            std::vector<Point> run;
            const auto flush = [&]() {
                if (run.size() < 2) { run.clear(); return; }
                Connector external;
                external.id = static_cast<std::uint32_t>(r.connectors.size() + 1);
                external.instance = c.instance;
                external.family = Family::Brace;
                external.a = run.front(); external.b = run.back(); external.facing = normal;
                external.state = "boundary_segment";
                const auto identical = std::find_if(r.connectors.begin(), r.connectors.end(), [&](const Connector& old) {
                    return old.instance == external.instance && old.family == external.family &&
                           old.a == external.a && old.b == external.b && old.facing == external.facing;
                });
                const auto count = std::count_if(r.connectors.begin(), r.connectors.end(),
                                                [&](const Connector& old) { return old.instance == c.instance; });
                if (identical == r.connectors.end() && count < q.limits.max_connectors_per_instance)
                    r.connectors.push_back(external);
                run.clear();
            };
            for (auto center : line(c.a, c.b)) {
                const auto face = add(center, normal), air = add(face, normal);
                const bool exposed = inside(q, face) && inside(q, air) && transition_at(q, face) &&
                    r.cells[index(q, face)] != Material::Empty && r.provenance[index(q, face)] == c.instance &&
                    r.roles[index(q, face)] != Role::Cohesion && r.cells[index(q, air)] == Material::Empty &&
                    (q.context.empty() || q.context[index(q, air)] == Material::Empty);
                if (exposed) run.push_back(face); else flush();
            }
            flush();
        }
    }
}

void export_boundary(const Request& q, Result& r) {
    expose_boundary_contacts(q, r);
    r.boundary.hard.clear();
    r.boundary.soft.clear();
    r.boundary.transition = q.transition;
    r.boundary.protected_geometry = q.protected_void;
    for (const auto& c : r.connectors) {
        if (r.boundary.hard.size() >= q.limits.max_affordances) break;
        if (!inside(q, c.a) || r.cells[index(q, c.a)] == Material::Empty) continue;
        if (c.family == Family::Brace) {
            if (c.state != "boundary_segment") continue;
            if (!transition_at(q, c.a) && !transition_at(q, c.b)) continue;
            bool exposed = true;
            for (auto p : line(c.a, c.b)) {
                const auto air = add(p, c.facing);
                if (!inside(q, p) || !inside(q, air) || r.cells[index(q, p)] == Material::Empty ||
                    r.roles[index(q, p)] == Role::Cohesion || r.cells[index(q, air)] != Material::Empty) {
                    exposed = false; break;
                }
            }
            if (!exposed) continue;
            r.boundary.hard.push_back({static_cast<std::uint32_t>(r.boundary.hard.size() + 1),
                                      c.instance, c.a, c.b, c.facing, Family::Brace,
                                      false, 0.65, "qualified_member_segment"});
        } else if (c.family == Family::Frame && !c.fulfilled) {
            // Caps are reconnectable authored end plates, not fake fulfilled
            // cross-Gentek joins. The subsequent mesher must qualify a bridge.
            if (!transition_at(q, c.a)) continue;
            const auto air = add(c.a, c.facing);
            if (inside(q, air) && r.cells[index(q, air)] != Material::Empty) continue;
            r.boundary.hard.push_back({static_cast<std::uint32_t>(r.boundary.hard.size() + 1),
                                      c.instance, c.a, c.b, c.facing, Family::Frame,
                                      c.required && !c.fulfilled, 1.0, "frame_terminal"});
            r.boundary.soft.push_back({c.a, c.facing, 0.8, "compatible_frame_or_surface"});
        }
    }
}

} // namespace

Result generate_frameweaver(const Request& q) {
    auto r = begin_result(q, "frontier-growth-v0");
    if (r.status == Status::Invalid || r.status == Status::Exhausted || r.cells.empty()) return r;
    if (q.limits.max_connectors_per_instance < 4) {
        r.status = Status::Invalid;
        r.termination = "junction_requires_four_connectors";
        return r;
    }
    if (q.limits.max_frontier < 4) {
        r.status = Status::Exhausted;
        r.termination = "root_frontier_exceeds_limit";
        finish_result(q, r);
        return r;
    }
    std::vector<Frontier> frontier;
    if (!plant_root(q, r, frontier)) {
        if (r.status != Status::Exhausted) { r.status = Status::Blocked; r.termination = "no_legal_root"; }
        finish_result(q, r);
        return r;
    }
    if (frontier.size() > q.limits.max_frontier) {
        r.status = Status::Exhausted;
        r.termination = "root_frontier_exceeds_limit";
        finish_result(q, r);
        return r;
    }
    r.metrics["peak_live_frontier"] = frontier.size();
    const unsigned target = std::min(q.limits.max_instances,
                                     static_cast<unsigned>(18 + 24 * q.profile.branching));
    // Preserve space for secondary reinforcement, non-structural cohesion and
    // bounded seam extensions instead of spending every instance on frame tips.
    // This reservation does not depend on clutter/cohesion, so those later
    // stages do not silently change the primary frame when a slider changes.
    const unsigned secondary_reserve = std::min(q.limits.max_instances / 3, 24U);
    const unsigned frame_budget = q.limits.max_instances - secondary_reserve;
    std::vector<Part> vocabulary;
    for (int n : {12, 16, 20}) vocabulary.push_back(member("beam_span", n));
    for (int n : {8, 12, 16}) vocabulary.push_back(member("post_support", n));
    vocabulary.push_back(junction());
    std::size_t processed = 0;
    while (!frontier.empty() && r.status != Status::Exhausted && r.instances.size() < target) {
        // Breadth first when regular; deterministic seeded ordering perturbs
        // frontier choices at higher irregularity without changing scale.
        std::size_t pick = 0;
        if (q.profile.irregularity > 0.3)
            pick = mix(q.seed ^ (processed * 0x9e3779b97f4a7c15ULL)) % frontier.size();
        const auto current = frontier[pick];
        frontier.erase(frontier.begin() + static_cast<std::ptrdiff_t>(pick));
        ++processed;
        const auto host = r.connectors[current.connector];
        if (host.fulfilled) continue;
        if (r.instances.size() + frontier.size() + 4 >= frame_budget) break;
        Placement best;
        bool found = false;
        for (const auto& part : vocabulary) {
            for (std::size_t pi = 0; pi < part.ports.size(); ++pi) {
                for (int rotation = 0; rotation < 4; ++rotation) {
                    if (rotate(part.ports[pi].facing, rotation) != neg(host.facing)) continue;
                    if (!candidate(q, r)) break;
                    Placement c{part, sub(host.a, rotate(part.ports[pi].point, rotation)), rotation, pi};
                    c.tie = mix(q.seed ^ (static_cast<std::uint64_t>(host.id) << 32) ^
                                (static_cast<std::uint64_t>(part.cells.size()) << 9) ^ (rotation * 67 + pi));
                    if (!qualify_closures(q, r, c, current.connector)) break;
                    if (!valid_placement(q, r, c, &host)) continue;
                    if (!charge(q, r, q.neighbors.hard.size() * c.part.ports.size())) break;
                    c.score = candidate_score(q, r, c, host, current.depth);
                    if (!found || c.score > best.score || (c.score == best.score && c.tie < best.tie)) {
                        best = std::move(c); found = true;
                    }
                }
                if (r.status == Status::Exhausted) break;
            }
            if (r.status == Status::Exhausted) break;
        }
        if (r.status == Status::Exhausted) break;
        if (found) {
            for (auto ci : commit(q, r, best, current.connector)) {
                if (frontier.size() >= q.limits.max_frontier) {
                    r.status = Status::Exhausted; r.termination = "frontier_limit"; break;
                }
                frontier.push_back({ci, current.depth + 1});
                r.metrics["peak_live_frontier"] = std::max(r.metrics["peak_live_frontier"],
                                                          static_cast<std::uint64_t>(frontier.size()));
            }
        } else terminate_connector(q, r, current.connector);
    }
    // Explicit terminal pass, including nodes removed from the frontier by a
    // budget stop. A failed cap leaves a visible unresolved required joint.
    const std::size_t socket_count = r.connectors.size();
    for (std::size_t i = 0; i < socket_count && r.status != Status::Exhausted; ++i) {
        if (r.connectors[i].family == Family::Frame && !r.connectors[i].fulfilled)
            terminate_connector(q, r, i);
    }
    reinforce(q, r);
    expose_boundary_contacts(q, r);
    cohesion(q, r, false);
    export_boundary(q, r);
    r.metrics["part_vocabulary_families"] = 6;
    r.metrics["frontier_processed"] = processed;
    r.notes.push_back("Frame joints certify mechanical graph compatibility, not physical load-bearing stability.");
    r.notes.push_back("Cohesion is non-structural and excludes unresolved mandatory joints within five cells.");
    if (r.status != Status::Exhausted) {
        const auto unresolved = std::count_if(r.connectors.begin(), r.connectors.end(),
            [](const Connector& c) { return c.required && !c.fulfilled; });
        r.status = unresolved ? Status::Blocked : Status::Complete;
        r.termination = unresolved ? "terminated_with_unresolved_joints" : "bounded_frontier_terminated";
    }
    finish_result(q, r);
    return r;
}

void adapt_frameweaver(const Request& q, Result& r) {
    if (r.status == Status::Invalid || r.status == Status::Unsat || r.status == Status::Damaged ||
        r.status == Status::Exhausted) return;
    const auto offers = r.boundary.hard;
    // Up to eight new transition-local socket extensions. Nearest compatible
    // foreign offer determines direction, but never authorizes entering it.
    unsigned additions = 0;
    for (const auto& own : offers) {
        if (additions >= 8 || !secondary_capacity(q, r)) break;
        if (own.family != Family::Frame) continue;
        const Affordance* target = nullptr;
        int nearest = 33;
        for (const auto& foreign : q.neighbors.hard) {
            if (!charge(q, r)) return;
            if (foreign.family != Family::Frame && foreign.family != Family::Surface) continue;
            const auto delta = sub(foreign.a, own.a);
            if (delta.x * own.facing.x + delta.y * own.facing.y <= 0 ||
                foreign.facing.x * -delta.x + foreign.facing.y * -delta.y < 0) continue;
            const int d = distance(own.a, foreign.a);
            if (d < nearest) { nearest = d; target = &foreign; }
        }
        if (!target || q.profile.environment_affinity == 0) continue;
        Point end = own.a;
        std::vector<Point> cells;
        for (int length = 1; length <= 10; ++length) {
            if (!charge(q, r)) return;
            const Point p{own.a.x + own.facing.x * length, own.a.y + own.facing.y * length};
            if (!allowed(q, p) || !transition_at(q, p)) break;
            if (r.cells[index(q, p)] != Material::Empty) {
                ++r.rejected["transition_extension_occupied_path"];
                break;
            }
            if (distance(p, target->a) >= nearest) break;
            cells.push_back(p); end = p;
        }
        if (cells.size() < 4 || end == own.a) continue;
        if (!candidate(q, r)) return;
        Instance extension;
        extension.id = static_cast<std::uint32_t>(r.instances.size() + 1);
        extension.kind = "transition_socket_extension";
        extension.origin = own.a;
        extension.cells = cells;
        extension.reason = "foreign affordance-directed short member; own transition territory only";
        for (auto p : cells) if (r.cells[index(q, p)] == Material::Empty)
            write_cell(q, r, p, Material::SteelPlate, Role::Transition, extension.id);
        r.instances.push_back(extension);
        Connector input;
        input.id = static_cast<std::uint32_t>(r.connectors.size() + 1);
        input.instance = extension.id; input.a = input.b = own.a;
        input.facing = neg(own.facing); input.required = input.fulfilled = true;
        input.state = "joined";
        auto local_socket = std::find_if(r.connectors.begin(), r.connectors.end(), [&](const Connector& c) {
            return c.instance == own.instance && c.family == Family::Frame && c.a == own.a && !c.fulfilled;
        });
        if (local_socket != r.connectors.end()) {
            input.counterpart = local_socket->id;
            local_socket->counterpart = input.id;
            local_socket->fulfilled = true;
            local_socket->state = "joined";
        }
        r.connectors.push_back(input);
        Connector output;
        output.id = static_cast<std::uint32_t>(r.connectors.size() + 1);
        output.instance = extension.id; output.a = output.b = end; output.facing = own.facing;
        output.state = "open";
        r.connectors.push_back(output);
        r.attachments.push_back({extension.id, own.a, target->a, "foreign_soft_affinity",
                                 "aimed at foreign frame/surface; cross-boundary join remains unproven"});
        ++additions;
        ++r.metrics["transition_socket_extensions"];
    }
    cohesion(q, r, true);
    export_boundary(q, r);
    finish_result(q, r);
}

} // namespace cybersand::gentek_swarm
