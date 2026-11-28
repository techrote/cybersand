#include "negotiated.hpp"

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
struct SourceReservation {
    std::uint32_t connector{};
    bool foreign = false;
    std::vector<Point> cells;
};
struct SourceReservations {
    std::vector<SourceReservation> entries;
    std::vector<std::uint32_t> owners;
};
struct SourceTrial {
    std::size_t port{};
    SourceFeasibilityDecision receipt;
    std::vector<Point> reserved;
};
struct Placement {
    Part part;
    Point origin;
    int rotation = 0;
    std::size_t input = 0;
    double score = -std::numeric_limits<double>::infinity();
    std::uint64_t tie{};
    std::vector<std::pair<std::size_t, std::size_t>> closures{};
    std::vector<SourceTrial> source_trials{};
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

// Genuine source-time mechanical alternative: a small welded steel corner
// cap. Its input is the real required parent socket, and commit() records a
// reciprocal local joint with a separate native part; it is never a post hoc
// waiver of an already-frozen foreign-required obligation.
Part compact_terminal() {
    Part p;
    p.kind = "swarm005/compact_native_terminal";
    p.material = Material::SteelPlate;
    p.cells = {{0,0},{1,0},{1,-1},{1,1}};
    p.ports = {{{0,0},{-1,0},true},{{1,0},{1,0},false}};
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

bool secondary_capacity_with_source(const Request& q, Result& r, const SourceReservations* reservations) {
    if (!reservations) return secondary_capacity(q, r);
    if (!charge(q, r, reservations->entries.size())) return false;
    const auto pending = static_cast<std::size_t>(std::count_if(reservations->entries.begin(), reservations->entries.end(),
        [&](const auto& item) { return !item.foreign && item.connector && item.connector <= r.connectors.size() &&
            !r.connectors[item.connector - 1].fulfilled; }));
    const auto seam_reserve = q.limits.max_instances >= 8 ? 4U : 0U;
    return r.instances.size() + pending < q.limits.max_instances - seam_reserve;
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

// A prospective required output is not admitted if it would immediately
// face a disallowed finite territory edge with no space for a genuine native
// cap and no facing peer territory. This is source-time choice of PARTS,
// before any original required ledger freezes. It never retypes or removes
// a connector from an accepted part.
bool preflight_required_exits(const Request& own, const Request* peer, Result& r, const Placement& candidate) {
    const auto& ports=candidate.part.ports;
    for(std::size_t i=0;i<ports.size();++i) {
        if(i==candidate.input || !ports[i].required ||
           std::any_of(candidate.closures.begin(),candidate.closures.end(),
               [&](const auto& pair){return pair.first==i;}))continue;
        const auto root=transformed(ports[i].point,candidate);
        const auto facing=rotate(ports[i].facing,candidate.rotation);
        bool can_cap=true;
        for(int distance=1;distance<=2;++distance) {
            const Point p{root.x+distance*facing.x,root.y+distance*facing.y};
            if(!charge(own,r))return false;
            if(!allowed(own,p)){can_cap=false;break;}
        }
        if(can_cap)continue;
        bool near_peer=false;
        if(peer)for(int distance=1;distance<=15;++distance) {
            const Point p{root.x+distance*facing.x,root.y+distance*facing.y};
            if(!charge(own,r))return false;
            if(!inside(own,p))break;
            if(allowed(*peer,p)){near_peer=true;break;}
            if(!allowed(own,p))break;
        }
        if(!near_peer) {++r.rejected["swarm005_unserviceable_required_exit_preflight"];return false;}
    }
    return true;
}

bool shared_allowed(const Request& own, const Request& peer, Point p,
                    const SourceFeasibilityOptions& options) {
    if (!options.shared_zone || !inside(own, p)) return false;
    const auto i = index(own, p);
    if ((*options.shared_zone)[i] == 0 || !transition_at(own, p)) return false;
    for (const auto* q : {&own, &peer}) {
        if ((!q->protected_void.empty() && q->protected_void[i]) ||
            (!q->context.empty() && q->context[i] != Material::Empty) ||
            (!q->neighbor_cells.empty() && q->neighbor_cells[i] != Material::Empty) ||
            (!q->neighbors.protected_geometry.empty() && q->neighbors.protected_geometry[i])) return false;
    }
    return true;
}

// Provisional exits keep the exact clear native cap or source-to-receiver
// opportunity footprint until their connector is extended/closed. An unrelated
// later source branch may not make its earlier feasibility witness impossible.
bool reservation_clear(const Request& q, Result& r, Point p,
    const SourceReservations* reservations, std::uint32_t consuming = 0,
    const Placement* joining = nullptr) {
    if (!reservations) return true;
    if (!charge(q, r) || !inside(q, p)) return false;
    const auto connector = reservations->owners[index(q, p)];
    if (connector == consuming || connector == 0 ||
        (connector <= r.connectors.size() && r.connectors[connector - 1].fulfilled)) return true;
    if (joining) {
        if (!charge(q, r, joining->closures.size())) return false;
        if (std::any_of(joining->closures.begin(), joining->closures.end(),
            [&](const auto& closure) { return r.connectors[closure.second].id == connector; })) return true;
    }
    return false;
}

bool preflight_native_required_exits(const Request& own, const Request& peer, Result& r,
    Placement& prospective, const Connector& host, bool compact,
    const SourceFeasibilityOptions& options, const SourceReservations& reservations) {
    if (!options.enabled) return true;
    std::vector<Point> occupied;
    occupied.reserve(prospective.part.cells.size());
    for (const auto p : prospective.part.cells) {
        if (!charge(own, r)) return false;
        occupied.push_back(transformed(p, prospective));
    }
    // Existing authored footprints are at most 81 cells; a conservative fixed
    // sort allowance covers comparisons without a second unbounded raster.
    if (!charge(own, r, occupied.size() * 8U)) return false;
    std::sort(occupied.begin(), occupied.end());
    const auto planned = [&](Point p) { return std::binary_search(occupied.begin(), occupied.end(), p); };
    for (std::size_t port = 0; port < prospective.part.ports.size(); ++port) {
        if (port == prospective.input || !prospective.part.ports[port].required ||
            std::any_of(prospective.closures.begin(), prospective.closures.end(),
                [&](const auto& closure) { return closure.first == port; })) continue;
        const auto started = r.work;
        SourceTrial trial;
        trial.port = port;
        auto& receipt = trial.receipt;
        receipt.part = prospective.part.kind;
        receipt.source = transformed(prospective.part.ports[port].point, prospective);
        receipt.face = receipt.source;
        receipt.facing = rotate(prospective.part.ports[port].facing, prospective.rotation);
        ++r.metrics["swarm006_source_exit_candidates"];
        if (std::abs(receipt.facing.x) + std::abs(receipt.facing.y) != 1 ||
            prospective.part.material == Material::Empty ||
            material_definition(prospective.part.material).state != MaterialState::Solid ||
            prospective.part.ports.size() + prospective.part.receptors.size() > own.limits.max_connectors_per_instance) {
            ++r.rejected["swarm006_source_facing_family_or_material"];
            return false;
        }
        for (unsigned step = 0; step < 3; ++step) {
            if (!charge(own, r, 8)) return false;
            const auto next = add(receipt.face, receipt.facing);
            if (!planned(next)) break;
            receipt.face = next;
        }
        // Enumerate the exact same authored terminal shapes used by the source
        // generator. A pair of free centerline cells is not a cap certificate.
        const bool terminal_capacity = r.instances.size() + 2 <= own.limits.max_instances &&
            r.candidates < own.limits.max_candidates && own.limits.max_connectors_per_instance >= 2;
        if (terminal_capacity) {
            std::vector<Part> endings{cap()};
            if (compact) endings.push_back(compact_terminal());
            for (const auto& ending : endings) {
                if (!candidate(own, r)) return false;
                unsigned orientation = 0;
                while (orientation < 4 && rotate({1, 0}, static_cast<int>(orientation)) != receipt.facing) ++orientation;
                bool legal = true;
                std::vector<Point> fresh;
                for (const auto local : ending.cells) {
                    if (!charge(own, r, 8)) return false;
                    const auto p = add(receipt.source, rotate(local, static_cast<int>(orientation)));
                    if (!allowed(own, p)) { legal = false; break; }
                    const auto i = index(own, p);
                    if (planned(p) || r.cells[i] != Material::Empty) {
                        if (!near_joint(p, receipt.source) ||
                            (!planned(p) && (r.cells[i] != Material::SteelPlate || r.roles[i] == Role::Cohesion))) {
                            legal = false; break;
                        }
                    } else {
                        if (!reservation_clear(own, r, p, &reservations, host.id, &prospective)) { legal = false; break; }
                        fresh.push_back(p);
                    }
                }
                if (r.status == Status::Exhausted) return false;
                if (!legal || fresh.empty()) continue;
                // Reserve future material write and terminal candidate capacity
                // geometrically; actual work remains charged when it executes.
                receipt.local_termination_possible = true;
                receipt.reason = "source-time exact native " + ending.kind + " footprint remains available";
                trial.reserved = std::move(fresh);
                break;
            }
        }
        if (!receipt.local_termination_possible) {
            if (!terminal_capacity) ++r.rejected["swarm006_source_terminal_capacity"];
            if (!charge(own, r, reservations.entries.size())) return false;
            const auto pending = std::count_if(reservations.entries.begin(), reservations.entries.end(), [&](const auto& v) {
                return v.foreign && v.connector != host.id && v.connector && v.connector <= r.connectors.size() &&
                    !r.connectors[v.connector - 1].fulfilled && r.connectors[v.connector - 1].required;
            });
            bool reachable = false, backing = false, native_category = false;
            const bool foreign_capacity = pending < static_cast<std::ptrdiff_t>(max_transition_slots) &&
                pending < static_cast<std::ptrdiff_t>(own.limits.max_affordances) && peer.limits.max_instances &&
                peer.limits.max_affordances && peer.limits.max_connectors_per_instance &&
                peer.limits.max_work >= 1024 && peer.limits.max_solver_work;
            if (foreign_capacity) {
                Point cached_origin{-1, -1};
                MosaicSourceTile tile;
                std::vector<Point> clear_path;
                for (int distance = 1; distance <= 14; ++distance) {
                    if (!candidate(own, r) || !charge(own, r, 24)) return false;
                    const Point contact{receipt.face.x + distance * receipt.facing.x,
                                        receipt.face.y + distance * receipt.facing.y};
                    const Point rear = add(contact, receipt.facing);
                    if (!inside(own, contact) || !transition_at(own, contact)) break;
                    const auto ci = index(own, contact);
                    if (planned(contact) || r.cells[ci] != Material::Empty ||
                        !reservation_clear(own, r, contact, &reservations, host.id, &prospective)) break;
                    const bool shared = shared_allowed(own, peer, contact, options);
                    if (allowed(peer, contact) || shared) {
                        reachable = true;
                        const bool rear_allowed = inside(own, rear) && (allowed(peer, rear) || shared_allowed(own, peer, rear, options));
                        if (rear_allowed && r.cells[index(own, rear)] == Material::Empty && !planned(rear) &&
                            reservation_clear(own, r, rear, &reservations, host.id, &prospective)) {
                            backing = true;
                            const Point origin{(contact.x / 16) * 16, (contact.y / 16) * 16};
                            if (origin != cached_origin) {
                                tile = {}; tile.origin = origin;
                                tile.width = std::min(16, own.width - origin.x);
                                tile.height = std::min(16, own.height - origin.y);
                                for (int y = 0; y < tile.height; ++y) for (int x = 0; x < tile.width; ++x) {
                                    if (!charge(own, r, 12)) return false;
                                    const Point p{origin.x + x, origin.y + y};
                                    tile.admitted[static_cast<std::size_t>(y * 16 + x)] =
                                        (allowed(peer, p) || shared_allowed(own, peer, p, options)) &&
                                        r.cells[index(own, p)] == Material::Empty && !planned(p) &&
                                        reservation_clear(own, r, p, &reservations, host.id, &prospective);
                                }
                                if (r.status == Status::Exhausted) return false;
                                cached_origin = origin;
                            }
                            const auto probe = probe_mosaic_source_receiver(tile, contact, receipt.facing,
                                own.limits.max_work - r.work);
                            if (probe.exhausted) {
                                r.status = Status::Exhausted; r.termination = "source native category probe work allowance";
                                return false;
                            }
                            if (!charge(own, r, probe.work)) return false;
                            if (probe.valid && probe.categories) {
                                native_category = true;
                                receipt.foreign_opportunity = true;
                                receipt.receiver_categories = probe.categories;
                                receipt.contact = contact; receipt.backing = rear;
                                receipt.reason = "source-time authored native MOSAIC receiver opportunity; bid, assignment and joint remain unproved";
                                trial.reserved = clear_path;
                                trial.reserved.push_back(contact); trial.reserved.push_back(rear);
                                break;
                            }
                        }
                    }
                    // Any eventual FRAME path must stay within its own or
                    // explicitly shared mask, not merely traverse peer land.
                    if (!allowed(own, contact) && !shared) break;
                    clear_path.push_back(contact);
                }
            }
            if (!receipt.foreign_opportunity) {
                ++r.rejected[!foreign_capacity ?
                    "swarm006_source_reservation_capacity" : !reachable ?
                    "swarm006_source_unreachable_receiver_territory" : !backing ?
                    "swarm006_source_missing_native_backing" : !native_category ?
                    "swarm006_source_missing_mosaic_category" : "swarm006_source_unconstructible_span"];
                ++r.rejected["swarm006_source_part_refused_before_freeze"];
                return false;
            }
        }
        receipt.work = r.work - started;
        prospective.source_trials.push_back(std::move(trial));
    }
    return true;
}

bool valid_placement(const Request& q, Result& r, const Placement& c,
                     const Connector* parent, bool only_transition = false,
                     const SourceReservations* reservations = nullptr) {
    std::size_t new_cells = 0;
    for (auto local : c.part.cells) {
        if (!charge(q, r)) return false;
        const auto p = transformed(local, c);
        if (!allowed(q, p) || (only_transition && !transition_at(q, p))) {
            ++r.rejected["footprint_mask_or_collision"];
            return false;
        }
        if (!reservation_clear(q, r, p, reservations, parent ? parent->id : 0, &c)) {
            ++r.rejected["swarm006_source_competing_reservation"];
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

void terminate_connector(const Request& q, Result& r, std::size_t ci, bool compact_native_termination,
                         const SourceReservations* reservations = nullptr) {
    if (r.connectors[ci].fulfilled || r.connectors[ci].state == "terminal_plate" ||
        r.status == Status::Exhausted) return;
    const auto host = r.connectors[ci];
    Placement end{cap(), {}, 0, 0};
    for (int rotation = 0; rotation < 4; ++rotation) {
        if (rotate(end.part.ports[0].facing, rotation) != neg(host.facing)) continue;
        if (!candidate(q, r)) return;
        end.rotation = rotation;
        end.origin = host.a;
        if (valid_placement(q, r, end, &host, false, reservations)) {
            commit(q, r, end, ci);
            return;
        }
    }
    if (compact_native_termination && host.required) {
        Placement tiny{compact_terminal(), {}, 0, 0};
        for (int rotation = 0; rotation < 4; ++rotation) {
            if (rotate(tiny.part.ports[0].facing, rotation) != neg(host.facing)) continue;
            if (!candidate(q, r)) return;
            tiny.rotation = rotation;
            tiny.origin = host.a;
            if (!valid_placement(q,r,tiny,&host,false,reservations)) continue;
            const auto before = r.instances.size();
            commit(q,r,tiny,ci);
            if (r.instances.size() == before) return;
            r.instances.back().reason = "swarm005/source-authored native compact weld; full material path and reciprocal input socket";
            ++r.metrics["swarm005_source_compact_terminations"];
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
void reinforce(const Request& q, Result& r, const SourceReservations* reservations = nullptr) {
    std::vector<std::size_t> receptors;
    for (std::size_t i = 0; i < r.connectors.size(); ++i) {
        if (r.connectors[i].family == Family::Brace) receptors.push_back(i);
    }
    const unsigned budget = static_cast<unsigned>(2 + 8 * q.profile.branching + 6 * q.profile.clutter);
    unsigned accepted = 0;
    for (std::size_t a = 0; a < receptors.size() && accepted < budget; ++a) {
        for (std::size_t b = a + 1; b < receptors.size() && accepted < budget; ++b) {
            if (r.status == Status::Exhausted || !secondary_capacity_with_source(q, r, reservations)) return;
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
                if (!reservation_clear(q, r, p, reservations)) { valid = false; break; }
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

void cohesion(const Request& q, Result& r, bool only_transition,
              const SourceReservations* reservations = nullptr) {
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
        if (patches >= patch_limit || !secondary_capacity_with_source(q, r, reservations)) break;
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
                if (!reservation_clear(q, r, p, reservations)) continue;
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
        while (!remaining.empty() && patches < patch_limit && secondary_capacity_with_source(q, r, reservations)) {
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

void export_boundary(const Request& q, Result& r, bool required_first = false) {
    expose_boundary_contacts(q, r);
    r.boundary.hard.clear();
    r.boundary.soft.clear();
    r.boundary.transition = q.transition;
    r.boundary.protected_geometry = q.protected_void;
    std::vector<const Connector*> ordered;
    if (required_first) {
        if (!charge(q, r, r.connectors.size() * 16ULL)) return;
        ordered.reserve(r.connectors.size());
        for (const auto& c : r.connectors) ordered.push_back(&c);
        std::stable_sort(ordered.begin(), ordered.end(), [](const auto* x, const auto* y) {
            return std::tuple{!(x->required && !x->fulfilled), x->id} <
                   std::tuple{!(y->required && !y->fulfilled), y->id};
        });
    }
    for (std::size_t ci = 0; ci < r.connectors.size(); ++ci) {
        const auto& c = required_first ? *ordered[ci] : r.connectors[ci];
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

// This ray answers only whether a mechanical end can face the other fixed
// territory. It knows nothing about MOSAIC's pitch, categories or choices.
int peer_distance(const Request& own, const Request& peer, Result& r,
                  Point start, Point facing, std::uint32_t instance) {
    if (std::abs(facing.x) + std::abs(facing.y) != 1 || !transition_at(own, start)) return -1;
    for (int step = 1; step <= 14; ++step) {
        if (!charge(own, r)) return -1;
        const Point p{start.x + facing.x * step, start.y + facing.y * step};
        if (!inside(own, p) || !transition_at(own, p)) return -1;
        const auto i = index(own, p);
        if ((!own.protected_void.empty() && own.protected_void[i]) ||
            (!peer.protected_void.empty() && peer.protected_void[i]) ||
            (!own.context.empty() && own.context[i] != Material::Empty)) return -1;
        if (r.cells[i] != Material::Empty) {
            if (r.provenance[i] == instance && r.roles[i] != Role::Cohesion) continue;
            return -1;
        }
        if (allowed(peer, p)) return step;
        if (!allowed(own, p)) return -1;
    }
    return -1;
}

Part receiving_terminal(int reach) {
    Part p;
    p.kind = reach == 0 ? "flush_terminal_plate" : "reserved_receiving_bracket";
    if (reach > 0) thick_line(p.cells, {0, 0}, {reach, 0}, 1);
    else thick_line(p.cells, {0, 0}, {0, 0}, 1);
    // An actual transverse end plate, connected by a short thick neck. This
    // is a finite authored mechanical shape, never a mask-fitting blob.
    const int face = reach > 0 ? reach + 1 : 0;
    thick_line(p.cells, {face, -3}, {face, 3}, 0);
    p.ports = {{{0, 0}, {-1, 0}, true}, {{face, 0}, {1, 0}, false}};
    return p;
}

void terminate_reserved(const Request& own, const Request& peer, Result& r, std::size_t ci, bool compact_native_termination,
                        const SourceReservations* reservations = nullptr) {
    if (r.status == Status::Exhausted || r.connectors[ci].fulfilled ||
        r.connectors[ci].state == "terminal_plate") return;
    const auto host = r.connectors[ci];
    const int gap = peer_distance(own, peer, r, host.a, host.facing, host.instance);
    // Longest legal member first; peer location bounds reach, not foreign form.
    // Six explicitly enumerated lengths, the old narrow cap, then a flush plate.
    for (int reach : {10, 8, 6, 4, 2, 1, -1, 0}) {
        if (reach > 0 && (gap < 1 || reach + 1 >= gap)) continue;
        for (int rotation = 0; rotation < 4; ++rotation) {
            if (rotate({1, 0}, rotation) != host.facing) continue;
            if (!candidate(own, r) || !secondary_capacity(own, r)) return;
            Placement ending{reach == -1 ? cap() : receiving_terminal(reach), host.a, rotation, 0};
            if (!valid_placement(own, r, ending, &host, true, reservations)) continue;
            const auto old_count = r.connectors.size();
            const auto old_instances = r.instances.size();
            commit(own, r, ending, ci);
            if (r.instances.size() == old_instances) return;
            auto& part = r.instances.back();
            part.reason = "preplanned peer-facing termination: authored short member and transverse plate; no foreign category knowledge";
            r.connectors[ci].state = "terminated";
            for (std::size_t j = old_count; j < r.connectors.size(); ++j)
                if (!r.connectors[j].fulfilled) r.connectors[j].state = "terminal_plate";
            // Its plate exports a real, finite bearing segment in addition to
            // the point socket. It is optional: the cap itself terminates the
            // old member through the recorded required input counterpart.
            const Point normal = host.facing, tangent{-normal.y, normal.x};
            const Point face = transformed(ending.part.ports[1].point, ending);
            if (reach != -1 && own.limits.max_connectors_per_instance >= 3) {
                Connector bearing;
                bearing.id = static_cast<std::uint32_t>(r.connectors.size() + 1);
                bearing.instance = part.id; bearing.family = Family::Brace;
                bearing.a = {face.x - 2 * tangent.x, face.y - 2 * tangent.y};
                bearing.b = {face.x + 2 * tangent.x, face.y + 2 * tangent.y};
                bearing.facing = normal; bearing.state = "boundary_segment";
                r.connectors.push_back(bearing);
            }
            ++r.metrics["preplanned_terminal_pieces"];
            for (auto p : part.cells)
                if (r.provenance[index(own, p)] == part.id) ++r.metrics["preplanned_terminal_cells"];
            return;
        }
    }
    if (compact_native_termination && host.required) {
        Placement tiny{compact_terminal(),host.a,0,0};
        for (int rotation = 0; rotation < 4; ++rotation) {
            if (rotate(tiny.part.ports[0].facing, rotation) != neg(host.facing)) continue;
            if (!candidate(own,r) || !secondary_capacity(own,r)) return;
            tiny.rotation = rotation;
            if (!valid_placement(own,r,tiny,&host,true,reservations)) continue;
            const auto old_count=r.instances.size();
            commit(own,r,tiny,ci);
            if(r.instances.size()==old_count)return;
            r.instances.back().reason="swarm005/source-authored native transition weld; not a waived foreign-required socket";
            ++r.metrics["swarm005_source_compact_terminations"];
            return;
        }
    }
    r.connectors[ci].state = host.required ? "unresolved" : "open";
    ++r.rejected[host.required ? "required_reserved_terminal_has_no_legal_authored_piece" :
                                 "optional_reserved_terminal_remains_open"];
}

std::uint32_t reservation_id(const Connector& c) {
    // Packing bounded geometry (256x128, cardinal facing and point/segment
    // role) gives a stable identifier without dependence on evaluation order.
    const unsigned facing = c.facing.x == 1 ? 0 : c.facing.y == 1 ? 1 : c.facing.x == -1 ? 2 : 3;
    const auto span = static_cast<unsigned>(distance(c.a, c.b));
    const auto reversed = static_cast<unsigned>(c.b.x < c.a.x || c.b.y < c.a.y);
    return 1U + static_cast<unsigned>(c.a.x) + (static_cast<unsigned>(c.a.y) << 8U) +
           (facing << 15U) + (span << 17U) + (reversed << 26U);
}

void reserve_slots(const Request& own, const Request& peer, Result& r, FramePlan& plan) {
    struct Offer { Connector connector; int priority{}, distance{}; };
    std::vector<Offer> offers;
    for (const auto& c : r.connectors) {
        if (!charge(own, r)) return;
        if (c.fulfilled || (c.family != Family::Frame && c.state != "boundary_segment")) continue;
        if (!inside(own, c.a) || !inside(own, c.b) || r.cells[index(own, c.a)] == Material::Empty ||
            r.cells[index(own, c.b)] == Material::Empty) continue;
        // Restrict to explicitly exported exposed material faces. A buried
        // centerline receptor is not a transition reservation.
        if (!charge(own, r, r.boundary.hard.size())) return;
        const auto exposed = std::find_if(r.boundary.hard.begin(), r.boundary.hard.end(), [&](const auto& a) {
            return a.instance == c.instance && a.family == c.family && a.a == c.a && a.b == c.b && a.facing == c.facing;
        });
        if (exposed == r.boundary.hard.end()) continue;
        int nearest = 15;
        for (auto p : line(c.a, c.b)) {
            const int d = peer_distance(own, peer, r, p, c.facing, c.instance);
            if (d > 0) nearest = std::min(nearest, d);
        }
        if (r.status == Status::Exhausted) return;
        if (nearest > 14) continue;
        const auto part = std::find_if(r.instances.begin(), r.instances.end(), [&](const auto& i) { return i.id == c.instance; });
        const bool authored_terminal = part != r.instances.end() &&
            (part->kind == "reserved_receiving_bracket" || part->kind == "flush_terminal_plate");
        const int priority = c.required ? 0 : authored_terminal ? 1 : c.family == Family::Frame ? 2 : 3;
        offers.push_back({c, priority, nearest});
    }
    std::sort(offers.begin(), offers.end(), [](const auto& a, const auto& b) {
        // For an authored plate prefer its bearing segment to the same plate's
        // point offer. Independent members are kept spatially separate below.
        return std::tuple{a.priority, a.distance, a.connector.a == a.connector.b,
                          a.connector.a, a.connector.b, a.connector.facing} <
               std::tuple{b.priority, b.distance, b.connector.a == b.connector.b,
                          b.connector.a, b.connector.b, b.connector.facing};
    });
    std::set<std::uint32_t> used_instances, used_ids;
    for (const auto& offer : offers) {
        if (plan.slots.size() >= max_transition_slots) {
            plan.reservation_rejections.push_back("finite slot capacity: remaining mechanical opportunities not advertised");
            break;
        }
        if (!charge(own, r)) return;
        const auto& c = offer.connector;
        if (used_instances.contains(c.instance)) continue;
        TransitionSlot slot;
        slot.id = reservation_id(c); slot.instance = c.instance; slot.connector = c.id;
        if (!used_ids.insert(slot.id).second) {
            plan.reservation_rejections.push_back("duplicate geometric reservation identifier rejected");
            continue;
        }
        slot.kind = c.a == c.b ? SlotKind::PointSocket : SlotKind::BearingSegment;
        slot.a = c.a; slot.b = c.b; slot.facing = c.facing;
        slot.required = c.required; slot.hard = c.required;
        slot.strength = c.required ? 1.0 : c.family == Family::Frame ? 0.85 : 0.65;
        const Point far_a{c.a.x + 14 * c.facing.x, c.a.y + 14 * c.facing.y};
        const Point far_b{c.b.x + 14 * c.facing.x, c.b.y + 14 * c.facing.y};
        const int margin_x = c.facing.x == 0 ? 3 : 0, margin_y = c.facing.y == 0 ? 3 : 0;
        const int left = std::max(0, std::min({c.a.x, c.b.x, far_a.x, far_b.x}) - margin_x);
        const int top = std::max(0, std::min({c.a.y, c.b.y, far_a.y, far_b.y}) - margin_y);
        const int right = std::min(own.width - 1, std::max({c.a.x, c.b.x, far_a.x, far_b.x}) + margin_x);
        const int bottom = std::min(own.height - 1, std::max({c.a.y, c.b.y, far_a.y, far_b.y}) + margin_y);
        slot.envelope = {left, top, right - left + 1, bottom - top + 1};
        for (int y = top; y <= bottom; ++y) for (int x = left; x <= right; ++x) {
            if (!charge(own, r)) return;
            const auto i = index(own, {x, y});
            if ((!own.protected_void.empty() && own.protected_void[i]) ||
                (!peer.protected_void.empty() && peer.protected_void[i])) slot.clearance.push_back({x, y});
        }
        slot.reason = c.required ? "unresolved required mechanical socket; native masonry must admit a real receiving face or retain explicit failure" :
            c.a == c.b ? "optional terminated mechanical end; recipient chooses its own closed receiving architecture" :
                        "optional exposed finite member/terminal-plate bearing segment; recipient chooses masonry form";
        plan.slots.push_back(std::move(slot)); used_instances.insert(c.instance);
    }
    std::sort(plan.slots.begin(), plan.slots.end(), [](const auto& a, const auto& b) { return a.id < b.id; });
    r.metrics["reserved_transition_slots"] = plan.slots.size();
}

} // namespace

static Result generate_frameweaver_plan(const Request& q, const Request* peer, FramePlan* plan, bool compact_native_termination,
    const SourceFeasibilityOptions* feasibility = nullptr) {
    auto r = begin_result(q, plan ? "reserved-frontier-growth-v1" : "frontier-growth-v0");
    const bool source_feasibility = feasibility && feasibility->enabled && plan && peer;
    if (source_feasibility) r.implementation += "+swarm006-native-source-opportunities-v1";
    if (plan && compact_native_termination) r.implementation += "+swarm005-native-source-feasibility-v1";
    if (r.status == Status::Invalid || r.status == Status::Exhausted || r.cells.empty()) return r;
    if (plan) {
        // Additional immutable core snapshot and finite slot receipts are part
        // of admission, not a hidden unlimited second representation.
        const auto memory = r.cells.size() * 160ULL + q.limits.max_instances * 16384ULL + 1024 * 1024ULL +
            (source_feasibility ? r.cells.size() * 4ULL + q.limits.max_instances * 1024ULL + 16384ULL : 0ULL);
        r.metrics["conservative_memory_bound_bytes"] = memory;
        if (memory > q.limits.max_bytes) {
            r.status = Status::Exhausted; r.termination = "reserved plan and immutable core exceed declared memory";
            return r;
        }
    }
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
    SourceReservations source_reservations;
    const auto* reservations = source_feasibility ? &source_reservations : nullptr;
    if (source_feasibility) {
        if (!charge(q, r, r.cells.size())) { finish_result(q, r); return r; }
        source_reservations.owners.assign(r.cells.size(), 0);
    }
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
                    if (compact_native_termination && !source_feasibility && !preflight_required_exits(q, peer, r, c)) continue;
                    if (!valid_placement(q, r, c, &host, false, reservations)) continue;
                    if (source_feasibility) {
                        const auto before = r.work;
                        const bool feasible = preflight_native_required_exits(q, *peer, r, c, host,
                            compact_native_termination, *feasibility, source_reservations);
                        r.metrics["swarm006_source_feasibility_work"] += r.work - before;
                        if (!feasible) continue;
                    }
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
            const auto old_connectors = r.connectors.size();
            const auto old_instances = r.instances.size();
            const auto new_frontier = commit(q, r, best, current.connector);
            if (source_feasibility && r.instances.size() != old_instances) {
                if (!charge(q, r, source_reservations.entries.size())) break;
                // Filled source connectors are semantically retired by their
                // exact ID. Stale map entries are harmless and reusable because
                // reservation_clear reads that immutable connector state.
                source_reservations.entries.erase(std::remove_if(source_reservations.entries.begin(), source_reservations.entries.end(),
                    [&](const auto& reservation) { return r.connectors[reservation.connector - 1].fulfilled; }), source_reservations.entries.end());
                for (const auto& trial : best.source_trials) {
                    auto receipt = trial.receipt;
                    receipt.connector = static_cast<std::uint32_t>(old_connectors + trial.port + 1);
                    receipt.instance = static_cast<std::uint32_t>(r.instances.size());
                    plan->source_feasibility.push_back(receipt);
                    if (!charge(q, r, trial.reserved.size())) break;
                    source_reservations.entries.push_back({receipt.connector, receipt.foreign_opportunity, trial.reserved});
                    for (const auto p : trial.reserved) source_reservations.owners[index(q, p)] = receipt.connector;
                    ++r.metrics[receipt.foreign_opportunity ? "swarm006_source_foreign_opportunities" :
                        "swarm006_source_local_opportunities"];
                }
                r.metrics["swarm006_source_peak_reservations"] = std::max(r.metrics["swarm006_source_peak_reservations"],
                    static_cast<std::uint64_t>(source_reservations.entries.size()));
            }
            for (auto ci : new_frontier) {
                if (frontier.size() >= q.limits.max_frontier) {
                    r.status = Status::Exhausted; r.termination = "frontier_limit"; break;
                }
                frontier.push_back({ci, current.depth + 1});
                r.metrics["peak_live_frontier"] = std::max(r.metrics["peak_live_frontier"],
                                                          static_cast<std::uint64_t>(frontier.size()));
            }
        } else if (plan && peer_distance(q, *peer, r, host.a, host.facing, host.instance) > 0) {
            r.connectors[current.connector].state = "reserved_pending";
        } else terminate_connector(q, r, current.connector, compact_native_termination, reservations);
    }
    // Explicit terminal pass, including nodes removed from the frontier by a
    // budget stop. A failed cap leaves a visible unresolved required joint.
    const std::size_t socket_count = r.connectors.size();
    for (std::size_t i = 0; i < socket_count && r.status != Status::Exhausted; ++i) {
        if (r.connectors[i].family == Family::Frame && !r.connectors[i].fulfilled) {
            if (plan && peer_distance(q, *peer, r, r.connectors[i].a, r.connectors[i].facing,
                                      r.connectors[i].instance) > 0) continue;
            terminate_connector(q, r, i, compact_native_termination, reservations);
        }
    }
    reinforce(q, r, reservations);
    if (plan) {
        // All macrostructure and nonstructural additions precede this freeze.
        // Only transition-local authored terminal pieces may be added below.
        cohesion(q, r, false, reservations);
        plan->core = r;
        finish_result(q, plan->core);
        for (std::size_t i = 0; i < socket_count && r.status != Status::Exhausted; ++i)
            if (r.connectors[i].family == Family::Frame && !r.connectors[i].fulfilled)
                terminate_reserved(q, *peer, r, i, compact_native_termination, reservations);
    } else {
        expose_boundary_contacts(q, r);
        cohesion(q, r, false);
    }
    export_boundary(q, r, source_feasibility);
    if (plan && r.status != Status::Exhausted) reserve_slots(q, *peer, r, *plan);
    r.metrics["part_vocabulary_families"] = plan ? 8 : 6;
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

Result generate_frameweaver(const Request& q) {
    return generate_frameweaver_plan(q, nullptr, nullptr, false);
}

FramePlan plan_frameweaver(const Request& own, const Request& peer, bool compact_native_termination,
                          const SourceFeasibilityOptions& feasibility) {
    FramePlan plan;
    std::string reason;
    if (!validate_request(own, reason)) {
        plan.result = begin_result(own, "reserved-frontier-growth-v1");
        return plan;
    }
    if (own.gentek != Kind::Frameweaver || !validate_request(peer, reason) ||
        own.width != peer.width || own.height != peer.height || own.origin != peer.origin ||
        own.context != peer.context || own.protected_void != peer.protected_void || own.transition != peer.transition) {
        plan.result = begin_result(own, "reserved-frontier-growth-v1");
        plan.result.status = Status::Invalid;
        plan.result.termination = "invalid or mismatched fixed peer territory: " + reason;
        return plan;
    }
    for (int y = 0; y < own.height; ++y) for (int x = 0; x < own.width; ++x) {
        if (allowed(own, {x, y}) && allowed(peer, {x, y})) {
            plan.result = begin_result(own, "reserved-frontier-growth-v1");
            plan.result.status = Status::Invalid;
            plan.result.termination = "fixed FRAMEWEAVER and peer territories overlap";
            return plan;
        }
    }
    if (own.profile.destruction != 0) {
        plan.result = begin_result(own, "reserved-frontier-growth-v1");
        plan.result.status = Status::Invalid;
        plan.result.termination = "SWARM-002 reservations require an intact plan; damage is a separate derivative";
        return plan;
    }
    if (feasibility.enabled) {
        bool valid = peer.gentek == Kind::Mosaic && own.limits.max_work <= 2'000'000 &&
            peer.limits.max_work <= 2'000'000 && peer.limits.max_solver_work <= 4'000'000 &&
            own.limits.max_candidates <= 8192 && peer.limits.max_candidates <= 8192 &&
            own.limits.max_instances <= 64 && peer.limits.max_instances <= 192 &&
            own.limits.max_bytes <= 16U * 1024U * 1024U && peer.limits.max_bytes <= 16U * 1024U * 1024U;
        if (feasibility.shared_zone) {
            const auto& mask = *feasibility.shared_zone;
            const auto count = static_cast<std::size_t>(own.width) * static_cast<std::size_t>(own.height);
            valid = valid && mask.size() == count;
            if (valid) for (std::size_t i = 0; i < count; ++i) {
                const Point p{static_cast<int>(i % own.width), static_cast<int>(i / own.width)};
                const bool territory = (own.eligible.empty() || own.eligible[i]) ||
                    (peer.eligible.empty() || peer.eligible[i]);
                if (mask[i] > 1 || (mask[i] && (!transition_at(own, p) || !territory))) { valid = false; break; }
            }
        }
        if (!valid) {
            plan.result = begin_result(own, "swarm006-native-source-opportunities-v1");
            plan.result.status = Status::Invalid;
            plan.result.termination = "invalid SWARM006 source opportunity mask, peer or comparison bounds";
            return plan;
        }
    }
    plan.result = generate_frameweaver_plan(own, &peer, &plan, compact_native_termination,
        feasibility.enabled ? &feasibility : nullptr);
    if (plan.result.status == Status::Exhausted) {
        plan.slots.clear();
        plan.reservation_rejections.push_back("exhaustion prevents publication of a complete reserved plan");
    }
    finish_result(own, plan.result);
    return plan;
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
            const auto mat = r.cells[index(q, p)];
            if (mat != Material::Empty && distance(p, own.a) > 3) break;
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

namespace cybersand::gentek_swarm {
FramePlan plan_frameweaver(const Request& own, const Request& peer, bool compact_native_termination) {
    return plan_frameweaver(own, peer, compact_native_termination, {});
}
FramePlan plan_frameweaver(const Request& own, const Request& peer) {
    return plan_frameweaver(own, peer, false);
}
}
