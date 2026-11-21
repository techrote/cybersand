#include "assembly.hpp"

#include <algorithm>
#include <array>
#include <limits>
#include <map>
#include <new>
#include <set>
#include <tuple>

namespace cybersand::gentek_swarm::assembly004 {
namespace {
constexpr std::array<Point, 4> directions{{{1, 0}, {0, 1}, {-1, 0}, {0, -1}}};
constexpr std::size_t max_symbols = 64, max_part_cells = 4096, max_sockets = 8;
bool cardinal(Point p) { return (p.x == 0 && (p.y == -1 || p.y == 1)) ||
                                  (p.y == 0 && (p.x == -1 || p.x == 1)); }
bool valid_role(Role role) { return role >= Role::Structure && role <= Role::Transition; }
bool valid_family(Family f) { return f >= Family::Frame && f <= Family::Passage; }
bool valid_obligation(Obligation o) { return o >= Obligation::Optional && o <= Obligation::ForeignRequired; }
bool add_checked(Point a, Point b, Point& out) {
    const auto x = static_cast<std::int64_t>(a.x) + b.x;
    const auto y = static_cast<std::int64_t>(a.y) + b.y;
    if (x < std::numeric_limits<int>::min() || x > std::numeric_limits<int>::max() ||
        y < std::numeric_limits<int>::min() || y > std::numeric_limits<int>::max()) return false;
    out = {static_cast<int>(x), static_cast<int>(y)}; return true;
}
std::uint64_t sort_charge(std::size_t n) {
    std::uint64_t levels = 1;
    for (std::size_t m = n; m > 1; m = (m + 1) / 2) ++levels;
    return static_cast<std::uint64_t>(n) * (levels + 1);
}
bool on_segment(Point p, Point a, Point b) {
    if (a.x != b.x && a.y != b.y) return false;
    return p.x >= std::min(a.x, b.x) && p.x <= std::max(a.x, b.x) &&
           p.y >= std::min(a.y, b.y) && p.y <= std::max(a.y, b.y);
}
std::uint64_t segment_size(Point a, Point b) {
    const auto dx = static_cast<std::int64_t>(a.x) - b.x;
    const auto dy = static_cast<std::int64_t>(a.y) - b.y;
    return static_cast<std::uint64_t>(dx < 0 ? -dx : dx) +
           static_cast<std::uint64_t>(dy < 0 ? -dy : dy) + 1;
}
template<class Function> void segment_points(Point a, Point b, Function fn) {
    const Point step{(b.x > a.x) - (b.x < a.x), (b.y > a.y) - (b.y < a.y)};
    for (;;) { fn(a); if (a == b) break; a.x += step.x; a.y += step.y; }
}
struct ChildResult { std::vector<PlacedSocket> sockets; };

class Expander {
public:
    Expander(const Grammar& grammar, Budget& ledger, std::uint32_t round, std::uint32_t revision)
        : g(grammar), budget(ledger) { out.owner = g.owner; out.round = round; out.revision = revision; }

    ExpandedAssembly run(Symbol symbol, Transform transform) {
        if (admit() && validate_definitions()) {
            ChildResult root;
            if (node(symbol, transform, 0, 0, 0, root) && canonical_claims() && contiguous()) {
                out.sockets = std::move(root.sockets);
                std::uint64_t digest_work = out.claims.size() * 12ULL + out.nodes.size() * 20ULL +
                    out.sockets.size() * 20ULL + out.joints.size() * 12ULL + g.identity.size();
                for (const auto& c : out.claims) digest_work += c.rule.size();
                for (const auto& n : out.nodes) digest_work += n.rule.size();
                for (const auto& j : out.joints) digest_work += j.cells.size() * 2ULL;
                for (const auto& r : out.rejections) digest_work += r.reason.size() + 2ULL;
                if (foreign_exports_retained() && charge(digest_work)) {
                    out.outcome = Outcome::Complete;
                    out.reason = "bounded native footprint contiguous; declared structural attachments qualified";
                    out.digest = digest();
                    return std::move(out);
                }
            }
        }
        // All-or-nothing proposal. Every failed operation remains charged.
        out.nodes.clear(); out.instances.clear(); out.claims.clear();
        out.sockets.clear(); out.joints.clear(); out.digest = 0;
        return std::move(out);
    }
private:
    const Grammar& g;
    Budget& budget;
    ExpandedAssembly out;
    std::map<std::uint32_t, const PartSpec*> parts;
    std::map<std::uint32_t, const AssemblySpec*> assemblies;
    std::set<std::uint32_t> active;
    std::vector<Claim> raw;
    std::uint32_t live_frontier{};
    bool failed{};

    bool fail(Outcome outcome, std::string reason, std::uint32_t symbol = 0, std::uint32_t slot = 0) {
        if (failed) return false;
        failed = true;
        out.outcome = outcome; out.reason = reason;
        out.rejections.push_back({symbol, slot, std::move(reason)}); return false;
    }
    bool charge(std::uint64_t n = 1) {
        if (failed) return false;
        if (budget.cancel && budget.cancel->load(std::memory_order_relaxed))
            return fail(Outcome::Cancelled, "cancelled before bounded grammar operation");
        if (budget.work > budget.limits.max_work || n > budget.limits.max_work - budget.work)
            return fail(Outcome::Exhausted, "aggregate grammar work allowance exhausted");
        budget.work += n; return true;
    }
    bool memory(std::size_t bytes) {
        if (budget.bytes > budget.limits.max_bytes || bytes > budget.limits.max_bytes - budget.bytes)
            return fail(Outcome::Exhausted, "conservative aggregate grammar storage allowance exhausted");
        budget.bytes += bytes; return true;
    }
    bool admit() {
        if (!charge()) return false;
        const auto& l = budget.limits;
        if (l.max_depth > 6 || l.max_nodes > 64 || l.max_instances > 64 || l.max_frontier > 256 ||
            l.max_candidates > 8192 || l.max_proposals > 10 || l.max_work > 2'000'000 ||
            l.max_bytes > 16 * 1024 * 1024)
            return fail(Outcome::Invalid, "grammar limits exceed registered SWARM-004 ceilings");
        if (budget.nodes > l.max_nodes || budget.instances > l.max_instances ||
            budget.candidates > l.max_candidates || budget.proposals > l.max_proposals)
            return fail(Outcome::Invalid, "caller supplied an overdrawn grammar ledger");
        if ((g.owner != Owner::Frameweaver && g.owner != Owner::Mosaic) || g.identity.empty() ||
            g.identity.size() > 128 || g.parts.empty() || g.parts.size() > max_symbols ||
            g.assemblies.size() > max_symbols - g.parts.size())
            return fail(Outcome::Invalid, "invalid owner, identity or bounded symbol table");
        return memory(4096 + g.identity.size() + (g.parts.size() + g.assemblies.size()) * 512);
    }
    bool cells_contiguous(const std::set<Point>& cells) {
        if (cells.empty()) return false;
        std::set<Point> seen;
        std::vector<Point> frontier{*cells.begin()}; seen.insert(frontier[0]);
        for (std::size_t i = 0; i < frontier.size(); ++i) {
            for (auto d : directions) {
                if (!charge(4)) return false;
                Point p;
                if (!add_checked(frontier[i], d, p)) continue;
                if (cells.contains(p) && seen.insert(p).second) frontier.push_back(p);
            }
        }
        return seen.size() == cells.size();
    }
    bool validate_definitions() {
        std::set<std::uint32_t> ids;
        for (const auto& p : g.parts) {
            if (!charge()) return false;
            if (!p.id || !ids.insert(p.id).second || p.name.empty() || p.name.size() > 128 ||
                p.rule.empty() || p.rule.size() > 256 || p.cells.empty() || p.cells.size() > max_part_cells ||
                p.sockets.size() > max_sockets)
                return fail(Outcome::Invalid, "invalid or duplicate part definition", p.id);
            if (!charge(p.name.size() + p.rule.size()) ||
                !memory(512 + p.name.size() + p.rule.size() + p.cells.size() * 256 + p.sockets.size() * 256)) return false;
            std::set<Point> cells;
            for (const auto& cell : p.cells) {
                if (!charge(8)) return false;
                if (!valid_material(static_cast<std::uint16_t>(cell.material)) || cell.material == Material::Empty ||
                    !valid_role(cell.role) || !cells.insert(cell.point).second)
                    return fail(Outcome::Invalid, "empty/invalid material, role or duplicate local part cell", p.id);
            }
            if (!cells_contiguous(cells)) {
                if (out.outcome == Outcome::Exhausted || out.outcome == Outcome::Cancelled) return false;
                return fail(Outcome::Invalid, "part footprint is not four-connected", p.id);
            }
            std::set<std::uint32_t> sockets;
            for (const auto& s : p.sockets) {
                if (!charge()) return false;
                if (!s.id || !sockets.insert(s.id).second || !cardinal(s.facing) ||
                    !valid_family(s.family) || !valid_obligation(s.obligation) ||
                    (s.a.x != s.b.x && s.a.y != s.b.y) || segment_size(s.a, s.b) > max_part_cells)
                    return fail(Outcome::Invalid, "invalid socket identity, segment, type or facing", p.id);
                bool valid = true;
                segment_points(s.a, s.b, [&](Point point) {
                    if (!charge(4)) { valid = false; return; }
                    if (s.family == Family::Passage ? cells.contains(point) : !cells.contains(point)) valid = false;
                });
                if (!valid) {
                    if (out.outcome == Outcome::Exhausted || out.outcome == Outcome::Cancelled) return false;
                    return fail(Outcome::Invalid, "socket has no declared native material or passage witness", p.id);
                }
            }
            parts.emplace(p.id, &p);
        }
        for (const auto& a : g.assemblies) {
            if (!charge()) return false;
            if (!a.id || !ids.insert(a.id).second || a.name.empty() || a.name.size() > 128 ||
                a.rule.empty() || a.rule.size() > 256 || a.children.empty() ||
                a.children.size() > 64 || a.attachments.size() > 128 || a.sockets.size() > max_sockets)
                return fail(Outcome::Invalid, "invalid or duplicate assembly definition", a.id);
            if (!charge(a.name.size() + a.rule.size()) ||
                !memory(1024 + a.rule.size() + a.name.size() + a.children.size() * 256 +
                        a.attachments.size() * 256 + a.sockets.size() * 256)) return false;
            std::set<std::uint32_t> slots, exports;
            for (const auto& child : a.children) {
                if (!charge()) return false;
                if (!child.slot || !slots.insert(child.slot).second || child.transform.quarter_turns > 3)
                    return fail(Outcome::Invalid, "invalid or duplicate assembly child slot/transform", a.id, child.slot);
            }
            for (const auto& e : a.sockets) {
                if (!charge()) return false;
                if (!e.id || !exports.insert(e.id).second || !slots.contains(e.child_slot))
                    return fail(Outcome::Invalid, "invalid or duplicate root socket export", a.id, e.child_slot);
            }
            for (const auto& edge : a.attachments) {
                if (!charge()) return false;
                if (!slots.contains(edge.child_a) || !slots.contains(edge.child_b) || edge.child_a == edge.child_b)
                    return fail(Outcome::Invalid, "attachment references absent or identical children", a.id);
            }
            assemblies.emplace(a.id, &a);
        }
        for (const auto& [id, a] : assemblies) for (const auto& c : a->children) {
            if (!charge()) return false;
            if (c.symbol.assembly ? !assemblies.contains(c.symbol.id) : !parts.contains(c.symbol.id))
                return fail(Outcome::Invalid, "assembly references an absent or mistyped symbol", id, c.slot);
        }
        return true;
    }
    bool node(Symbol symbol, Transform transform, std::uint32_t depth,
              std::uint32_t parent, std::uint32_t slot, ChildResult& result) {
        if (!charge()) return false;
        if (transform.quarter_turns > 3) return fail(Outcome::Invalid, "invalid root transform", symbol.id, slot);
        if (depth > budget.limits.max_depth) return fail(Outcome::Exhausted, "recursive grammar depth limit", symbol.id, slot);
        if (budget.nodes >= budget.limits.max_nodes || budget.candidates >= budget.limits.max_candidates)
            return fail(Outcome::Exhausted, "aggregate grammar node/candidate allowance", symbol.id, slot);
        ++budget.nodes; ++budget.candidates;
        const auto node_id = static_cast<std::uint32_t>(out.nodes.size() + 1);
        if (!memory(4096)) return false;
        if (!symbol.assembly) {
            const auto it = parts.find(symbol.id);
            if (it == parts.end()) return fail(Outcome::Invalid, "unknown part root", symbol.id, slot);
            if (budget.instances >= budget.limits.max_instances)
                return fail(Outcome::Exhausted, "aggregate grammar instance allowance", symbol.id, slot);
            ++budget.instances;
            const auto& p = *it->second;
            const auto instance = static_cast<std::uint32_t>(out.instances.size() + 1);
            out.nodes.push_back({node_id, parent, symbol.id, depth, slot, false, p.rule, transform});
            PlacedPart placed{instance, parent, p.id, depth, p.name, p.rule, transform, {}, node_id};
            if (!charge(sort_charge(p.cells.size()) + sort_charge(p.sockets.size())) ||
                !memory(p.cells.size() * (sizeof(Claim) + p.rule.size() + 160) + p.sockets.size() * 256)) return false;
            for (const auto& cell : p.cells) {
                if (!charge(4)) return false;
                Point world;
                if (!transform_point(cell.point, transform, world))
                    return fail(Outcome::Invalid, "part world coordinate overflow", p.id, slot);
                raw.push_back({world, cell.material, cell.role, g.owner, instance, p.id, out.round, out.revision, p.rule});
                ++out.declared_cells;
            }
            for (const auto& socket : p.sockets) {
                if (!charge(12)) return false;
                PlacedSocket s{socket.id, instance, socket.id, {}, {}, {}, socket.family, socket.obligation};
                if (!transform_point(socket.a, transform, s.a) || !transform_point(socket.b, transform, s.b) ||
                    !transform_point(socket.facing, {{0, 0}, transform.quarter_turns}, s.facing))
                    return fail(Outcome::Invalid, "socket world coordinate overflow", p.id, slot);
                placed.sockets.push_back(s);
            }
            std::sort(placed.sockets.begin(), placed.sockets.end(), [](const auto& a, const auto& b) { return a.id < b.id; });
            result.sockets = placed.sockets;
            out.instances.push_back(std::move(placed)); return true;
        }
        const auto it = assemblies.find(symbol.id);
        if (it == assemblies.end()) return fail(Outcome::Invalid, "unknown assembly root", symbol.id, slot);
        if (!active.insert(symbol.id).second) return fail(Outcome::Invalid, "recursive grammar cycle/reentry", symbol.id, slot);
        const auto& a = *it->second;
        out.nodes.push_back({node_id, parent, symbol.id, depth, slot, true, a.rule, transform});
        if (a.children.size() > budget.limits.max_frontier - std::min(live_frontier, budget.limits.max_frontier))
            return fail(Outcome::Exhausted, "recursive grammar live frontier allowance", a.id, slot);
        live_frontier += static_cast<std::uint32_t>(a.children.size());
        budget.peak_frontier = std::max(budget.peak_frontier, live_frontier);
        if (!charge(sort_charge(a.children.size()) + sort_charge(a.attachments.size()) + sort_charge(a.sockets.size()))) return false;
        auto children = a.children;
        std::sort(children.begin(), children.end(), [](const auto& x, const auto& y) { return x.slot < y.slot; });
        std::map<std::uint32_t, ChildResult> outputs;
        for (const auto& child : children) {
            --live_frontier;
            Transform world;
            if (!compose(transform, child.transform, world)) return fail(Outcome::Invalid, "nested transform overflow", a.id, child.slot);
            if (!node(child.symbol, world, depth + 1, node_id, child.slot, outputs[child.slot])) return false;
        }
        auto edges = a.attachments;
        std::sort(edges.begin(), edges.end(), [](const auto& x, const auto& y) {
            return std::tuple{x.child_a, x.socket_a, x.child_b, x.socket_b, x.required} <
                   std::tuple{y.child_a, y.socket_a, y.child_b, y.socket_b, y.required};
        });
        for (const auto& edge : edges) {
            const auto* x = socket(outputs[edge.child_a].sockets, edge.socket_a);
            const auto* y = socket(outputs[edge.child_b].sockets, edge.socket_b);
            if (!x || !y) return fail(Outcome::Invalid, "attachment references absent child socket", a.id);
            if (!join(*x, *y, edge.required, a.id)) return false;
        }
        auto exports = a.sockets;
        std::sort(exports.begin(), exports.end(), [](const auto& x, const auto& y) { return x.id < y.id; });
        for (const auto& e : exports) {
            if (!charge()) return false;
            const auto* s = socket(outputs[e.child_slot].sockets, e.socket);
            if (!s) return fail(Outcome::Invalid, "export references absent child socket", a.id, e.child_slot);
            auto exported = *s; exported.id = e.id; result.sockets.push_back(exported);
        }
        active.erase(symbol.id); return true;
    }
    static const PlacedSocket* socket(const std::vector<PlacedSocket>& sockets, std::uint32_t id) {
        const auto it = std::find_if(sockets.begin(), sockets.end(), [=](const auto& s) { return s.id == id; });
        return it == sockets.end() ? nullptr : &*it;
    }
    bool join(const PlacedSocket& a, const PlacedSocket& b, bool required, std::uint32_t symbol) {
        if (!charge(8)) return false;
        const bool compatible = a.family == b.family && a.family != Family::Passage &&
            a.facing.x == -b.facing.x && a.facing.y == -b.facing.y && a.instance != b.instance &&
            a.obligation != Obligation::ForeignRequired && b.obligation != Obligation::ForeignRequired;
        if (!memory(256 + static_cast<std::size_t>(segment_size(a.a, a.b)) * 64)) return false;
        Joint joint{a.instance, a.source_socket, b.instance, b.source_socket, a.family, {}};
        if (compatible) {
            bool ok = true;
            segment_points(a.a, a.b, [&](Point p) {
                if (!charge(6)) { ok = false; return; }
                Point next;
                if (on_segment(p, b.a, b.b)) joint.cells.push_back(p);
                else if (add_checked(p, a.facing, next) && on_segment(next, b.a, b.b)) {
                    joint.cells.push_back(p); joint.cells.push_back(next);
                }
            });
            if (!ok) return false;
        }
        if (!compatible || joint.cells.empty()) {
            if (required) return fail(Outcome::Invalid, "required typed attachment lacks exact facing/native socket witness", symbol);
            if (!memory(256)) return false;
            out.rejections.push_back({symbol, 0, "optional attachment rejected: incompatible type/facing/obligation or disjoint sockets"});
            return true;
        }
        if (!charge(sort_charge(joint.cells.size()))) return false;
        std::sort(joint.cells.begin(), joint.cells.end());
        joint.cells.erase(std::unique(joint.cells.begin(), joint.cells.end()), joint.cells.end());
        out.joints.push_back(std::move(joint)); return true;
    }
    bool canonical_claims() {
        if (!charge(sort_charge(raw.size())) || !memory(raw.size() * (sizeof(Claim) + 416))) return false;
        std::sort(raw.begin(), raw.end(), [](const auto& a, const auto& b) {
            return std::tuple{a.point, a.instance, a.spec} < std::tuple{b.point, b.instance, b.spec};
        });
        for (std::size_t start = 0; start < raw.size();) {
            std::size_t end = start + 1;
            while (end < raw.size() && raw[end].point == raw[start].point) ++end;
            if (!charge(static_cast<std::uint64_t>(end - start))) return false;
            std::set<std::uint32_t> reached{raw[start].instance};
            for (std::size_t i = start + 1; i < end; ++i) {
                if (raw[i].material != raw[start].material || raw[i].role == Role::Cohesion || raw[i].role == Role::Detail ||
                    raw[start].role == Role::Cohesion || raw[start].role == Role::Detail)
                    return fail(Outcome::Invalid, "ambiguous or nonstructural material overlap in assembly");
            }
            bool changed = true;
            while (changed && reached.size() < end - start) {
                changed = false;
                for (const auto& joint : out.joints) {
                    if (!charge(4 + joint.cells.size())) return false;
                    if (!std::binary_search(joint.cells.begin(), joint.cells.end(), raw[start].point)) continue;
                    const auto present = [&](std::uint32_t id) {
                        return std::any_of(raw.begin() + static_cast<std::ptrdiff_t>(start),
                            raw.begin() + static_cast<std::ptrdiff_t>(end), [=](const auto& c) { return c.instance == id; });
                    };
                    if (!present(joint.instance_a) || !present(joint.instance_b)) continue;
                    if (reached.contains(joint.instance_a)) changed |= reached.insert(joint.instance_b).second;
                    if (reached.contains(joint.instance_b)) changed |= reached.insert(joint.instance_a).second;
                }
            }
            if (reached.size() != end - start)
                return fail(Outcome::Invalid, "undeclared material overlap outside exact authored joint");
            out.claims.push_back(raw[start]);
            out.shared_joint_cells += end - start - 1;
            start = end;
        }
        return !out.claims.empty() || fail(Outcome::Invalid, "empty expanded native footprint");
    }
    bool contiguous() {
        std::set<Point> cells;
        for (const auto& c : out.claims) { if (!charge(4)) return false; cells.insert(c.point); }
        if (!cells_contiguous(cells)) {
            if (out.outcome == Outcome::Exhausted || out.outcome == Outcome::Cancelled) return false;
            return fail(Outcome::Invalid, "assembled native footprint is disconnected");
        }
        return true;
    }
    bool foreign_exports_retained() {
        for (const auto& part : out.instances) for (const auto& s : part.sockets) {
            if (!charge(1 + out.sockets.size())) return false;
            if (s.obligation == Obligation::ForeignRequired &&
                std::none_of(out.sockets.begin(), out.sockets.end(), [&](const auto& e) {
                    return e.instance == s.instance && e.source_socket == s.source_socket &&
                           e.obligation == Obligation::ForeignRequired;
                })) return fail(Outcome::Invalid, "assembly hid an unresolved foreign-required socket", part.spec);
        }
        return true;
    }
    std::uint64_t digest() const {
        std::uint64_t hash = UINT64_C(1469598103934665603);
        const auto value = [&](std::uint64_t v) { for (unsigned i = 0; i < 8; ++i) { hash ^= v & 255; hash *= UINT64_C(1099511628211); v >>= 8; } };
        const auto string = [&](const std::string& s) { value(s.size()); for (auto c : s) { hash ^= static_cast<unsigned char>(c); hash *= UINT64_C(1099511628211); } };
        const auto point = [&](Point p) { value(static_cast<std::uint64_t>(static_cast<std::int64_t>(p.x))); value(static_cast<std::uint64_t>(static_cast<std::int64_t>(p.y))); };
        string(g.identity); value(static_cast<unsigned>(out.owner)); value(out.round); value(out.revision);
        for (const auto& n : out.nodes) { value(n.id); value(n.parent); value(n.spec); value(n.depth); value(n.child_slot); value(n.assembly); string(n.rule); point(n.transform.translation); value(n.transform.quarter_turns); }
        for (const auto& c : out.claims) { point(c.point); value(static_cast<unsigned>(c.material)); value(static_cast<unsigned>(c.role)); value(c.instance); value(c.spec); string(c.rule); }
        for (const auto& s : out.sockets) { value(s.id); value(s.instance); value(s.source_socket); point(s.a); point(s.b); point(s.facing); value(static_cast<unsigned>(s.family)); value(static_cast<unsigned>(s.obligation)); }
        for (const auto& j : out.joints) { value(j.instance_a); value(j.socket_a); value(j.instance_b); value(j.socket_b); value(static_cast<unsigned>(j.family)); for (auto p : j.cells) point(p); }
        for (const auto& r : out.rejections) { value(r.symbol); value(r.child_slot); string(r.reason); }
        value(out.declared_cells); value(out.shared_joint_cells); return hash;
    }
};

SocketSpec socket_spec(std::uint32_t id, Point p, Point facing, Obligation obligation = Obligation::Optional) {
    return {id, p, p, facing, Family::Frame, obligation};
}
void line_cells(PartSpec& p, Point a, Point b) {
    // Small authored coordinates only. A four-connected staircase, no raster alias gaps.
    const int dx = b.x - a.x, dy = b.y - a.y;
    const int count = std::max(std::abs(dx), std::abs(dy));
    const auto add = [&](Point v) {
        if (std::none_of(p.cells.begin(), p.cells.end(), [&](const auto& c) { return c.point == v; }))
            p.cells.push_back({v, Material::SteelPlate, Role::Structure});
    };
    add(a);
    for (int i = 1; i <= count; ++i) {
        const Point target{a.x + dx * i / count, a.y + dy * i / count};
        Point previous = p.cells.back().point;
        while (previous.x != target.x) { previous.x += (target.x > previous.x) ? 1 : -1; add(previous); }
        while (previous.y != target.y) { previous.y += (target.y > previous.y) ? 1 : -1; add(previous); }
    }
}
PartSpec beam(std::uint32_t id, unsigned length, const std::string& label, bool foreign) {
    PartSpec p{id, label, "FRAMEWEAVER/parts/v1/" + label, {}, {}};
    const int n = static_cast<int>(length);
    line_cells(p, {0, 0}, {n, 0});
    p.sockets = {socket_spec(1, {0, 0}, {-1, 0}, Obligation::LocalTerminable),
                 socket_spec(2, {n, 0}, {1, 0}, foreign ? Obligation::ForeignRequired : Obligation::Optional)};
    return p;
}
} // namespace

const char* name(Owner value) noexcept { return value == Owner::Frameweaver ? "FRAMEWEAVER" : value == Owner::Mosaic ? "MOSAIC" : "INVALID"; }
const char* name(Obligation value) noexcept {
    switch (value) { case Obligation::Optional: return "optional"; case Obligation::LocalTerminable: return "local_terminable"; case Obligation::ForeignRequired: return "foreign_required"; }
    return "invalid";
}
const char* name(Outcome value) noexcept {
    switch (value) { case Outcome::Complete: return "complete"; case Outcome::Invalid: return "invalid"; case Outcome::Exhausted: return "exhausted"; case Outcome::Cancelled: return "cancelled"; }
    return "invalid";
}
bool transform_point(Point p, Transform transform, Point& world) noexcept {
    if (transform.quarter_turns > 3) return false;
    std::int64_t x = p.x, y = p.y;
    switch (transform.quarter_turns) {
    case 1: { const auto t = x; x = -y; y = t; break; }
    case 2: x = -x; y = -y; break;
    case 3: { const auto t = x; x = y; y = -t; break; }
    default: break;
    }
    x += transform.translation.x; y += transform.translation.y;
    if (x < std::numeric_limits<int>::min() || x > std::numeric_limits<int>::max() ||
        y < std::numeric_limits<int>::min() || y > std::numeric_limits<int>::max()) return false;
    world = {static_cast<int>(x), static_cast<int>(y)}; return true;
}
bool compose(Transform parent, Transform local, Transform& world) noexcept {
    if (parent.quarter_turns > 3 || local.quarter_turns > 3 ||
        !transform_point(local.translation, parent, world.translation)) return false;
    world.quarter_turns = (parent.quarter_turns + local.quarter_turns) % 4; return true;
}
bool begin_proposal(Budget& budget) noexcept {
    if ((budget.cancel && budget.cancel->load(std::memory_order_relaxed)) ||
        budget.limits.max_proposals > 10 || budget.proposals >= budget.limits.max_proposals ||
        budget.work >= budget.limits.max_work) return false;
    ++budget.proposals; ++budget.work; return true;
}
ExpandedAssembly expand(const Grammar& grammar, Symbol root, Transform transform,
                        std::uint32_t round, std::uint32_t revision, Budget& budget) {
    try { return Expander(grammar, budget, round, revision).run(root, transform); }
    catch (const std::bad_alloc&) {
        ExpandedAssembly out; out.outcome = Outcome::Exhausted; out.owner = grammar.owner;
        out.round = round; out.revision = revision; out.reason = "allocator refused admitted grammar storage"; return out;
    }
}
Grammar frame_grammar(unsigned span, unsigned rise, Family input_family) {
    Grammar g;
    g.identity = "gentek_swarm_004_frame_parts_v1";
    if (span < 1 || span > 24 || rise < 1 || rise > 16 ||
        (input_family!=Family::Frame&&input_family!=Family::Brace)) return g;
    const int x = static_cast<int>(span), y = static_cast<int>(rise);
    auto cap_part = beam(cap, 2, "local_cap", false);
    line_cells(cap_part, {2, -2}, {2, 2});
    PartSpec plate_part{plate, "flush_plate", "FRAMEWEAVER/parts/v1/flush_plate", {}, {}};
    line_cells(plate_part, {0, -3}, {0, 3});
    plate_part.sockets = {socket_spec(1, {0, 0}, {-1, 0}, Obligation::LocalTerminable),
                          socket_spec(2, {0, 0}, {1, 0}, Obligation::ForeignRequired),
                          {3, {0, -2}, {0, 2}, {1, 0}, Family::Brace, Obligation::Optional}};
    auto member_part = beam(member, span, "straight_member", true);
    member_part.sockets.push_back(socket_spec(3, {0, 0}, {0, -1}));
    member_part.sockets.push_back(socket_spec(4, {x, 0}, {-1, 0}));
    if (span > 2) member_part.sockets.push_back({5, {1, 0}, {x - 1, 0}, {0, 1}, Family::Brace, Obligation::Optional});
    PartSpec elbow_part{elbow, "offset_elbow", "FRAMEWEAVER/parts/v1/offset_elbow", {}, {}};
    line_cells(elbow_part, {0, 0}, {x, 0}); line_cells(elbow_part, {x, 0}, {x, y});
    elbow_part.sockets = {socket_spec(1, {0, 0}, {-1, 0}, Obligation::LocalTerminable),
                          socket_spec(2, {x, y}, {0, 1}, Obligation::ForeignRequired)};
    PartSpec brace_part{brace, "triangular_diagonal", "FRAMEWEAVER/parts/v1/triangular_diagonal", {}, {}};
    // Leave the top support toward +x and enter the chord toward +y. This
    // prevents a steep staircase from sharing undeclared post/chord cells.
    line_cells(brace_part, {0, 0}, {1, 0});
    line_cells(brace_part, {1, 0}, {x, y - 1});
    line_cells(brace_part, {x, y - 1}, {x, y});
    brace_part.sockets = {socket_spec(1, {0, 0}, {0, 1}), socket_spec(2, {x, y}, {1, 0})};
    PartSpec junction_part{junction, "four_way_junction", "FRAMEWEAVER/parts/v1/four_way_junction", {}, {}};
    line_cells(junction_part, {-3, 0}, {3, 0}); line_cells(junction_part, {0, -3}, {0, 3});
    junction_part.sockets = {socket_spec(1, {-3, 0}, {-1, 0}), socket_spec(2, {3, 0}, {1, 0}),
                             socket_spec(3, {0, -3}, {0, -1}), socket_spec(4, {0, 3}, {0, 1})};
    g.parts = {std::move(cap_part), std::move(plate_part), std::move(member_part), std::move(elbow_part),
               std::move(brace_part), std::move(junction_part), beam(upright, rise, "truss_post", false),
               beam(bracket_arm, span, "bracket_arm", false)};
    auto ending=g.parts[1];
    ending.id=termination_plate;ending.name="local_flush_ending";
    ending.rule="FRAMEWEAVER/parts/v1/local_flush_ending";
    ending.sockets[1].obligation=Obligation::LocalTerminable;
    g.parts.push_back(std::move(ending));
    if(input_family==Family::Brace) {
        g.identity="gentek_swarm_004_frame_bearing_adapter_v1";
        for(auto& p:g.parts)if(p.id==member||p.id==bracket_arm) {
            p.sockets[0].family=Family::Brace;p.rule+="/brace-bearing-input";
        }
    }
    AssemblySpec truss_part{truss, "triangular_truss", "FRAMEWEAVER/assemblies/v1/triangular_truss",
        {{1, {member, false}, {}}, {2, {upright, false}, {{0, 0}, 3}}, {3, {brace, false}, {{0, -y}, 0}}},
        {{1, 3, 2, 1, true}, {2, 2, 3, 1, true}, {1, 4, 3, 2, true}}, {{1, 1, 1}, {2, 1, 2}}};
    AssemblySpec bracket_part{bracket, "bearing_bracket", "FRAMEWEAVER/assemblies/v1/bearing_bracket",
        {{1, {bracket_arm, false}, {}}, {2, {plate, false}, {{x, 0}, 0}}},
        {{1, 2, 2, 1, true}}, {{1, 1, 1}, {2, 2, 2}, {3, 2, 3}}};
    AssemblySpec nested{nested_truss, "nested_truss", "FRAMEWEAVER/assemblies/v1/nested_truss",
        {{1, {truss, true}, {}}}, {}, {{1, 1, 1}, {2, 1, 2}}};
    g.assemblies = {std::move(truss_part), std::move(bracket_part), std::move(nested)};
    return g;
}

Grammar bearing_grammar(unsigned span, unsigned rise, Family input_family, int handedness) {
    Grammar g;
    g.identity = "gentek_swarm_004_backward_bearing_v1";
    if (span < 2 || span > 12 || rise < 2 || rise > 8 ||
        (handedness != -1 && handedness != 1) ||
        (input_family != Family::Frame && input_family != Family::Brace)) return g;
    const int x = static_cast<int>(span), y = static_cast<int>(rise);
    const std::string side = handedness < 0 ? "upper" : "lower";
    PartSpec face{bearing_face, "backward_bearing_face", "FRAMEWEAVER/parts/v1/backward_bearing_face/" + side, {}, {}};
    line_cells(face, {0, 0}, {0, handedness * y});
    face.sockets = {socket_spec(1, {0, 0}, {-1, 0}, Obligation::LocalTerminable),
                    socket_spec(2, {0, 0}, {1, 0}, Obligation::ForeignRequired),
                    socket_spec(3, {0, handedness * y}, {-1, 0}),
                    socket_spec(4, {0, 0}, {-1, 0})};
    face.sockets[0].family = input_family;
    if (input_family == Family::Brace) face.rule += "/brace-bearing-input";

    PartSpec seat{bearing_seat, "backward_bearing_seat", "FRAMEWEAVER/parts/v1/backward_bearing_seat/" + side, {}, {}};
    line_cells(seat, {0, 0}, {x, 0});
    // An inset point weld leaves a one-cell seat return. Canonical ownership
    // then gives all three parts genuine new material even at the 2x2 scale.
    seat.sockets = {socket_spec(1, {1, 0}, {0, handedness}),
                    socket_spec(2, {x, 0}, {1, 0})};

    PartSpec diagonal{bearing_diagonal, "backward_bearing_diagonal",
                      "FRAMEWEAVER/parts/v1/backward_bearing_diagonal/" + side, {}, {}};
    line_cells(diagonal, {1, 0}, {1, 1});
    line_cells(diagonal, {1, 1}, {x - 1, y - 1});
    line_cells(diagonal, {x - 1, y - 1}, {x - 1, y});
    line_cells(diagonal, {x - 1, y}, {x, y});
    for (auto& cell : diagonal.cells) cell.point.y *= -handedness;
    diagonal.sockets = {socket_spec(1, {1, 0}, {0, -handedness}),
                        socket_spec(2, {x, -handedness * y}, {1, 0})};

    g.parts = {std::move(face), std::move(seat), std::move(diagonal)};
    g.assemblies = {{backward_bearing, "backward_bearing", "FRAMEWEAVER/assemblies/v1/backward_bearing/" + side,
        {{1, {bearing_face, false}, {}},
         {2, {bearing_diagonal, false}, {{-x, handedness * y}, 0}},
         {3, {bearing_seat, false}, {{-x, handedness * y}, 0}}},
        {{1, 3, 3, 2, true}, {3, 1, 2, 1, true}, {1, 4, 2, 2, true}},
        {{1, 1, 1}, {2, 1, 2}}}};
    return g;
}

} // namespace cybersand::gentek_swarm::assembly004
