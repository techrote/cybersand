#include "swarm.hpp"
#include "cybersand/generation_spatial.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <limits>
#include <memory>
#include <tuple>

namespace cybersand::gentek_swarm {
namespace {
namespace spatial = cybersand::generation::spatial;
constexpr int pitch = 16;
constexpr std::array<Point, 4> directions{{{1, 0}, {0, 1}, {-1, 0}, {0, -1}}};

// Categories describe local passage compatibility, not arbitrary rigid parts.
// Exterior is an explicitly unowned/omitted logical cell, not a claim that an
// unconnected opening has a traversable neighbour. Arch halves must be paired.
enum Motif : unsigned {
    Exterior, Vault, Gallery, Shaft, Crossing, ArchLeft, ArchRight, Rib,
    Buttress, TermWest, TermEast, TermNorth, TermSouth, PortalWest, PortalEast,
    Solid, motif_count
};
constexpr std::array<const char*, motif_count> motif_names{{
    "exterior", "vault", "gallery", "shaft", "crossing", "arch_left", "arch_right",
    "rib", "buttress", "termination_west", "termination_east", "termination_north",
    "termination_south", "portal_west", "portal_east", "solid"
}};
// Bits follow GEN-003 Right, Down, Left, Up. They concern passage apertures;
// load-bearing engineering is deliberately not inferred from these bits.
constexpr std::array<unsigned, motif_count> passage_bits{{
    0, 0, 5, 10, 15, 1, 4, 0, 0, 1, 4, 5, 5, 5, 5, 0
}};
constexpr std::uint16_t bit(unsigned m) { return static_cast<std::uint16_t>(1U << m); }

struct Tile {
    int x{}, y{}, width{}, height{}, admitted{};
    bool full = false;
    unsigned edge = TermWest;
    std::array<std::array<bool, pitch>, pitch> mask{};
};

bool compatible(unsigned a, unsigned b, unsigned direction) {
    if (direction == 0 && (a == ArchLeft || b == ArchRight))
        return a == ArchLeft && b == ArchRight;
    if (direction == 2 && (a == ArchRight || b == ArchLeft))
        return a == ArchRight && b == ArchLeft;
    if (a == Exterior || b == Exterior) return true;
    return ((passage_bits[a] >> direction) & 1U) ==
           ((passage_bits[b] >> ((direction + 2U) % 4U)) & 1U);
}

bool tile_has(const Tile& t, int x, int y) {
    return x >= 0 && y >= 0 && x < t.width && y < t.height && t.mask[y][x];
}

// One contiguous row/column span containing p. A concavity is preserved: a
// motif never joins two spans by drawing across the excluded interval.
std::pair<int, int> row_span(const Tile& t, int x, int y) {
    int lo = x, hi = x;
    while (lo > 0 && tile_has(t, lo - 1, y)) --lo;
    while (hi + 1 < t.width && tile_has(t, hi + 1, y)) ++hi;
    return {lo, hi};
}
std::pair<int, int> column_span(const Tile& t, int x, int y) {
    int lo = y, hi = y;
    while (lo > 0 && tile_has(t, x, lo - 1)) --lo;
    while (hi + 1 < t.height && tile_has(t, x, hi + 1)) ++hi;
    return {lo, hi};
}

// Border pieces are constructed from admitted spans, not a cropped interior
// vault. Their stepped contour and finite returns are the actual motif shape.
bool contour_cell(const Tile& t, unsigned motif, int x, int y) {
    if (!tile_has(t, x, y)) return false;
    const auto [left, right] = row_span(t, x, y);
    const auto [top, bottom] = column_span(t, x, y);
    if (right - left < 2 || bottom - top < 2) return false;
    const bool aperture = y >= 5 && y <= 10;
    const bool west = motif == TermWest || motif == PortalWest;
    const bool east = motif == TermEast || motif == PortalEast;
    if (west || east) {
        const bool portal = motif == PortalWest || motif == PortalEast;
        const bool contour = west ? x - left < 2 : right - x < 2;
        const bool inner_return = west ? right - x < 2 : x - left < 2;
        const bool floor_or_roof = y - top < 2 || bottom - y < 2;
        // Endcaps and doorway jambs remain distinguishable at a jagged edge.
        return floor_or_roof || (contour && !(portal && aperture)) ||
               (inner_return && !aperture);
    }
    const bool contour = motif == TermNorth ? y - top < 2 : bottom - y < 2;
    const bool opposite_return = motif == TermNorth ? bottom - y < 2 : y - top < 2;
    return contour || opposite_return || ((x - left < 2 || right - x < 2) && !aperture);
}

bool interior_cell(unsigned motif, int x, int y) {
    const bool roof = y < 2, floor = y >= pitch - 2;
    const bool west = x < 2, east = x >= pitch - 2;
    const bool aperture_y = y >= 5 && y <= 10;
    const bool aperture_x = x >= 5 && x <= 10;
    const int arch_rise = 1 + std::max(0, 4 - std::min(x, pitch - 1 - x));
    switch (motif) {
    case Vault: return floor || y <= arch_rise || west || east;
    case Gallery: return roof || floor || ((west || east) && y < 4);
    case Shaft: return west || east || ((roof || floor) && !aperture_x);
    case Crossing: return ((roof || floor) && !aperture_x) || ((west || east) && !aperture_y);
    case ArchLeft: return west || floor || y <= 5 - x / 3;
    case ArchRight: return east || floor || y <= 5 - (pitch - 1 - x) / 3;
    case Rib: return west || east || roof || floor || x == 7 || x == 8;
    case Buttress: return west || east || roof || floor || x <= 2 + y / 3;
    case TermWest: return west || roof || floor || (east && !aperture_y);
    case TermEast: return east || roof || floor || (west && !aperture_y);
    case TermNorth: case TermSouth: return roof || floor || ((west || east) && !aperture_y);
    case PortalWest: case PortalEast: return roof || floor || ((west || east) && !aperture_y);
    case Solid: return true;
    default: return false;
    }
}

std::uint16_t domain_for(const Request& req, const Tile& t, int tx, int ty) {
    if (t.admitted < 9) return bit(Exterior);
    if (!t.full) {
        std::uint16_t domain = bit(t.edge);
        if (req.profile.branching > 0.2) {
            if (t.edge == TermWest) domain |= bit(PortalWest);
            if (t.edge == TermEast) domain |= bit(PortalEast);
        }
        // The foreign-facing aperture is an explicit domain choice, not an
        // arbitrary cut after rasterization. This also works for direct calls
        // with a supplied immutable neighbour boundary.
        for (const auto& a : req.neighbors.hard) {
            if (a.family != Family::Passage || a.strength <= 0) continue;
            if (a.a.y < t.y || a.a.y >= t.y + t.height) continue;
            if (t.edge == TermWest && std::abs(a.a.x - t.x) <= pitch)
                domain = bit(PortalWest);
            if (t.edge == TermEast && std::abs(a.a.x - (t.x + t.width - 1)) <= pitch)
                domain = bit(PortalEast);
        }
        return domain;
    }
    std::uint16_t domain = bit(Vault) | bit(Gallery) | bit(TermWest) | bit(TermEast);
    if (req.profile.branching > 0.35)
        domain = static_cast<std::uint16_t>(domain | bit(Shaft) | bit(Crossing));
    if (req.profile.variation > 0.3)
        domain = static_cast<std::uint16_t>(domain | bit(ArchLeft) | bit(ArchRight) | bit(Rib));
    if (req.profile.cohesion > 0.4)
        domain = static_cast<std::uint16_t>(domain | bit(Buttress) | bit(Solid));
    // Irregularity changes which macro routes are available at constant pitch.
    // Keeping two terminal alternatives avoids forcing a global full row.
    if (req.profile.irregularity < 0.2) {
        domain = bit(Vault) | bit(Gallery) | bit(TermWest) | bit(TermEast);
    } else if (unit(req.seed ^ (static_cast<std::uint64_t>(ty * 31 + tx) << 12U)) <
               req.profile.irregularity * 0.28) {
        domain = static_cast<std::uint16_t>(domain | bit(Rib) | bit(Buttress));
        domain &= static_cast<std::uint16_t>(~(bit(Shaft) | bit(Crossing)));
    }
    // A finite non-wrapped solver has no edge outside its tile. Exclude arch
    // halves that would otherwise lack their mandatory reciprocal counterpart.
    if (tx == 0) domain &= static_cast<std::uint16_t>(~bit(ArchRight));
    if ((tx + 1) * pitch >= req.width) domain &= static_cast<std::uint16_t>(~bit(ArchLeft));
    return domain;
}

bool own_protected(const Result& result, std::size_t i) {
    return i < result.boundary.protected_geometry.size() && result.boundary.protected_geometry[i] != 0;
}

void expose_boundary(const Request& req, Result& result, const Tile& t,
                     unsigned motif, std::uint32_t instance) {
    // Four representative bearing contacts per motif. The contact is on real
    // material; the neighbour may elect to join or leave it unused.
    std::uint32_t exposed = 0;
    for (unsigned d = 0; d < directions.size() && exposed < req.limits.max_connectors_per_instance; ++d) {
        Point best{};
        int best_score = std::numeric_limits<int>::max();
        bool found = false;
        for (int y = 0; y < t.height; ++y) for (int x = 0; x < t.width; ++x) {
            Point p{t.x + x, t.y + y};
            if (!inside(req, p) || result.cells[index(req, p)] == Material::Empty ||
                !transition_at(req, p)) continue;
            bool faces_outside = false;
            for (int distance = 1; distance <= 5; ++distance) {
                const Point q{p.x + directions[d].x * distance, p.y + directions[d].y * distance};
                if (!inside(req, q) || (!req.eligible.empty() && !req.eligible[index(req, q)])) {
                    faces_outside = true; break;
                }
            }
            if (!faces_outside) continue;
            const int score = std::abs(x - 8) + std::abs(y - 13);
            if (score < best_score || (score == best_score && p < best)) {
                best = p; best_score = score; found = true;
            }
        }
        if (!found || result.boundary.hard.size() >= req.limits.max_affordances) continue;
        const auto id = static_cast<std::uint32_t>(result.boundary.hard.size() + 1);
        result.boundary.hard.push_back({id, instance, best, best, directions[d], Family::Frame,
                                       false, 1.0, "masonry-bearing-contact"});
        ++exposed;
        result.boundary.soft.push_back({best, directions[d], req.profile.environment_affinity,
                                       "ledge-or-buttress"});
    }
    if (motif != PortalWest && motif != PortalEast) return;
    const Point facing = motif == PortalWest ? Point{-1, 0} : Point{1, 0};
    Point endpoint{};
    bool found = false;
    // The authored aperture is protected separately from cells. No bridge or
    // cosmetic fill may silently occupy the exposed empty doorway later.
    for (int y = 5; y <= 10 && y < t.height; ++y) for (int x = 0; x < t.width; ++x) {
        const Point p{t.x + x, t.y + y};
        if (tile_has(t, x, y) && result.cells[index(req, p)] == Material::Empty) {
            result.boundary.protected_geometry[index(req, p)] = 1;
            if (!found || (facing.x < 0 ? p.x < endpoint.x : p.x > endpoint.x)) {
                endpoint = p; found = true;
            }
        }
    }
    if (found && result.boundary.hard.size() < req.limits.max_affordances &&
        exposed < req.limits.max_connectors_per_instance) {
        const auto id = static_cast<std::uint32_t>(result.boundary.hard.size() + 1);
        result.boundary.hard.push_back({id, instance, endpoint, endpoint, facing, Family::Passage,
                                       false, 1.0, "reserved-masonry-doorway"});
    }
}

std::vector<Point> elbow(Point from, Point to, bool horizontal_first) {
    const Point corner = horizontal_first ? Point{to.x, from.y} : Point{from.x, to.y};
    auto first = line(from, corner), second = line(corner, to);
    if (!second.empty()) first.insert(first.end(), second.begin() + 1, second.end());
    return first;
}
} // namespace

Result generate_mosaic(const Request& req) {
    Result result = begin_result(req, "prepared-regions-motifs-v0");
    if (result.cells.empty() || result.status == Status::Invalid || result.status == Status::Exhausted)
        return result;
    if (result.boundary.protected_geometry.empty())
        result.boundary.protected_geometry.assign(result.cells.size(), 0);
    const int grid_width = (req.width + pitch - 1) / pitch;
    const int grid_height = (req.height + pitch - 1) / pitch;
    if (grid_width > 16 || grid_height > 16) {
        result.status = Status::Invalid;
        result.termination = "MOSAIC finite logical tile exceeds GEN-003 16x16 bound";
        return result;
    }
    spatial::RegionAssignment assignment;
    assignment.width = static_cast<std::uint32_t>(grid_width);
    assignment.height = static_cast<std::uint32_t>(grid_height);
    assignment.cell_size = pitch;
    assignment.seed = req.seed;
    assignment.origin_x = req.origin.x;
    assignment.origin_y = req.origin.y;
    for (unsigned m = 0; m < motif_count; ++m)
        assignment.categories.push_back(UINT64_C(0x4d4f534149430000) + m);
    for (unsigned d = 0; d < directions.size(); ++d)
        for (unsigned a = 0; a < motif_count; ++a)
            for (unsigned b = 0; b < motif_count; ++b)
                if (compatible(a, b, d)) assignment.adjacency[d][a] |= bit(b);

    std::vector<Tile> tiles;
    tiles.reserve(static_cast<std::size_t>(grid_width * grid_height));
    std::uint32_t nonempty_tiles = 0;
    for (int ty = 0; ty < grid_height; ++ty) for (int tx = 0; tx < grid_width; ++tx) {
        Tile tile;
        tile.x = tx * pitch; tile.y = ty * pitch;
        tile.width = std::min(pitch, req.width - tile.x);
        tile.height = std::min(pitch, req.height - tile.y);
        std::array<int, 4> exposure{};
        for (int y = 0; y < tile.height; ++y) for (int x = 0; x < tile.width; ++x) {
            if (!charge(req, result)) return result;
            const Point p{tile.x + x, tile.y + y};
            tile.mask[y][x] = allowed(req, p);
            if (!tile.mask[y][x]) continue;
            ++tile.admitted;
            for (unsigned d = 0; d < directions.size(); ++d) {
                const Point q{p.x + directions[d].x, p.y + directions[d].y};
                if (!allowed(req, q)) ++exposure[d];
            }
        }
        tile.full = tile.admitted == pitch * pitch;
        const auto exposed = static_cast<unsigned>(std::max_element(exposure.begin(), exposure.end()) - exposure.begin());
        constexpr std::array<unsigned, 4> edge_motif{{TermEast, TermSouth, TermWest, TermNorth}};
        tile.edge = edge_motif[exposed];
        if (!candidate(req, result)) return result;
        if (!charge(req, result, req.neighbors.hard.size())) return result;
        const auto domain = domain_for(req, tile, tx, ty);
        assignment.domains.push_back(domain);
        if (domain != bit(Exterior)) ++nonempty_tiles;
        tiles.push_back(tile);
    }
    if (nonempty_tiles > req.limits.max_instances) {
        result.status = Status::Exhausted;
        result.termination = "MOSAIC motif instance bound before immutable solve";
        result.rejected["motif_instance_capacity"] = nonempty_tiles;
        return result;
    }
    if (req.limits.max_bytes < spatial::kRegionSolverScratchBytes + result.cells.size() * 16U) {
        result.status = Status::Exhausted;
        result.termination = "MOSAIC declared memory cannot hold GEN-003 fixed solver scratch";
        return result;
    }
    std::shared_ptr<const spatial::PreparedRegions> prepared;
    result.metrics["solver_attempted"] = 1;
    result.metrics["solver_work_observed"] = 0;
    try {
        prepared = spatial::PreparedRegions::compile(std::move(assignment),
            {req.limits.max_solver_work, spatial::kRegionSolverScratchBytes});
    } catch (const spatial::RegionAssignmentUnsatisfiable& e) {
        result.status = Status::Unsat; result.termination = e.what();
        result.notes.push_back("No partial motif assignment is rasterized after proven UNSAT.");
        result.metrics["solver_work_upper_bound"] = req.limits.max_solver_work;
        result.notes.push_back("GEN-003 does not expose used work on UNSAT; serialized solver work is null, not zero work.");
        return result;
    } catch (const spatial::RegionAssignmentExhausted& e) {
        result.status = Status::Exhausted; result.termination = e.what();
        result.metrics["solver_work_upper_bound"] = req.limits.max_solver_work;
        result.notes.push_back("GEN-003 throws without used-work statistics on exhaustion; serialized solver work is null, not fabricated.");
        return result;
    } catch (const std::invalid_argument& e) {
        result.status = Status::Invalid; result.termination = e.what(); return result;
    }
    result.solver_work = prepared->preparation_work();
    result.metrics["solver_work_observed"] = 1;
    result.metrics["solver_definition_fingerprint"] = prepared->fingerprint();
    result.metrics["logical_tiles"] = tiles.size();
    result.metrics["solver_categories"] = motif_count;
    result.metrics["backtracking_metric_available"] = 0;
    result.backtracks = -1;
    result.notes.push_back("GEN-003 performs bounded propagation/backtracking; its public API exposes total work, not backtrack count.");
    result.notes.push_back("Motif doorway compatibility is local; this is not a global support or post-simulation stability certificate.");
    for (std::size_t tile_index = 0; tile_index < tiles.size(); ++tile_index) {
        const auto motif = static_cast<unsigned>(prepared->cells()[tile_index] - UINT64_C(0x4d4f534149430000));
        const auto& tile = tiles[tile_index];
        ++result.metrics[std::string("category_") + motif_names[motif]];
        if (motif == Exterior) continue;
        const auto id = static_cast<std::uint32_t>(result.instances.size() + 1);
        Instance instance;
        instance.id = id; instance.kind = motif_names[motif];
        instance.origin = {tile.x, tile.y};
        instance.reason = tile.full ? "GEN-003 reciprocal doorway/arch-pair assignment" :
            "GEN-003 selected contour termination/portal; admitted spans define actual geometry";
        const bool ornamented = tile.full && (motif == Vault || motif == Gallery) &&
            unit(req.seed ^ mix(tile_index) ^ UINT64_C(0x636f7262656c)) < req.profile.clutter;
        for (int y = 0; y < tile.height; ++y) for (int x = 0; x < tile.width; ++x) {
            if (!charge(req, result)) return result;
            const bool ornament = ornamented && (x == 4 || x == 11) && y >= 2 && y <= 4;
            const bool occupied = ornament || (tile.full ? interior_cell(motif, x, y) : contour_cell(tile, motif, x, y));
            if (occupied) instance.cells.push_back({tile.x + x, tile.y + y});
        }
        if (instance.cells.empty()) {
            ++result.rejected["admitted_span_too_narrow_for_motif"];
            continue;
        }
        result.instances.push_back(instance);
        if (!tile.full) ++result.metrics["contour_motifs"];
        for (const auto p : instance.cells) {
            const int x = p.x - tile.x, y = p.y - tile.y;
            const bool ornament = ornamented && !interior_cell(motif, x, y);
            const bool band = y < 2 || y >= tile.height - 2 || (x % 8 == 0 && req.profile.clutter > 0.4);
            const auto material = ornament ? Material::SteelPlate : (band ? Material::Stone : Material::RedBrick);
            const auto role = ornament ? Role::Detail : (tile.full ? Role::Structure : Role::Transition);
            if (!write_cell(req, result, p, material, role, id))
                return result;
        }
        // Conservative charge covers four finite surface scans and their
        // five-cell outward probes, including the optional aperture scan.
        if (!charge(req, result, static_cast<std::uint64_t>(tile.width * tile.height) * 25U))
            return result;
        expose_boundary(req, result, tile, motif, id);
    }
    if (result.instances.empty()) {
        result.status = Status::Blocked; result.termination = "no admitted MOSAIC motif footprint";
    } else {
        result.termination = "finite GEN-003 motif assignment completed before raster sampling";
    }
    return result;
}

void adapt_mosaic(const Request& req, Result& result) {
    if (result.status != Status::Complete || result.metrics["transition_passes"] != 0) return;
    ++result.metrics["transition_passes"];
    // This pass adds explicitly named transition pieces around immutable core
    // motifs. It cannot cut a new portal through a frozen wall. Initial portal
    // categories retain their protected apertures throughout negotiation.
    std::vector<Affordance> foreign = req.neighbors.hard;
    std::sort(foreign.begin(), foreign.end(), [](const auto& a, const auto& b) {
        return std::tie(a.a, a.family, a.id) < std::tie(b.a, b.family, b.id);
    });
    std::uint32_t additions = 0;
    for (const auto& contact : foreign) {
        if (additions >= 8 || result.instances.size() >= req.limits.max_instances) break;
        if (contact.family != Family::Frame && contact.family != Family::Surface) continue;
        if (contact.family == Family::Surface && req.profile.environment_affinity == 0) continue;
        if (std::abs(contact.facing.x) + std::abs(contact.facing.y) != 1) continue;
        if (!inside(req, contact.a) || req.neighbor_cells.empty() ||
            req.neighbor_cells[index(req, contact.a)] == Material::Empty) {
            ++result.rejected["foreign_contact_without_material"]; continue;
        }
        const Point target{contact.a.x + contact.facing.x, contact.a.y + contact.facing.y};
        if (!inside(req, target) || !allowed(req, target) || !transition_at(req, target) ||
            own_protected(result, index(req, target))) continue;
        Point anchor{};
        int best_distance = std::numeric_limits<int>::max();
        bool found = false;
        // A bounded 25x25 search of already accepted masonry, not a frontier
        // structural assembler. One small ledge/rib template then spans the gap.
        for (int dy = -12; dy <= 12; ++dy) for (int dx = -12; dx <= 12; ++dx) {
            if (!charge(req, result)) return;
            Point p{target.x + dx, target.y + dy};
            if (!inside(req, p) || !transition_at(req, p)) continue;
            const auto i = index(req, p);
            if (result.cells[i] == Material::Empty || result.roles[i] == Role::Cohesion) continue;
            const int distance = std::abs(dx) + std::abs(dy);
            if (distance == 0 || distance > 18) continue;
            if (!found || distance < best_distance || (distance == best_distance && p < anchor)) {
                anchor = p; best_distance = distance; found = true;
            }
        }
        if (!found) { ++result.rejected["foreign_contact_without_local_masonry"] ; continue; }
        std::vector<Point> chosen;
        for (int order = 0; order < 2; ++order) {
            if (!candidate(req, result)) return;
            const auto path = elbow(anchor, target, order == 0);
            bool valid = true;
            for (const auto p : path) {
                if (!charge(req, result)) return;
                if (!inside(req, p) || !transition_at(req, p) || own_protected(result, index(req, p))) {
                    valid = false; break;
                }
                if (result.cells[index(req, p)] == Material::Empty && !allowed(req, p)) {
                    valid = false; break;
                }
            }
            if (valid) { chosen = path; break; }
        }
        if (chosen.empty()) { ++result.rejected["foreign_transition_clearance_or_envelope"]; continue; }
        Instance addition;
        addition.id = static_cast<std::uint32_t>(result.instances.size() + 1);
        addition.kind = contact.facing.x != 0 ? "foreign_ledge_transition" : "foreign_pier_cap";
        addition.origin = anchor;
        addition.reason = "bounded template selected by foreign typed bearing; core and doorway clearance retained";
        for (const auto p : chosen)
            if (result.cells[index(req, p)] == Material::Empty) addition.cells.push_back(p);
        if (addition.cells.empty()) continue;
        const auto id = addition.id;
        result.instances.push_back(addition);
        for (const auto p : addition.cells)
            if (!write_cell(req, result, p, Material::ReinforcedConcrete, Role::Transition, id)) return;
        result.attachments.push_back({id, target, contact.a, "foreign-bearing-contact",
                                     "transition ledge is anchored to accepted masonry and ends adjacent to foreign material"});
        if (req.limits.max_connectors_per_instance != 0 && result.boundary.hard.size() < req.limits.max_affordances) {
            const auto port_id = static_cast<std::uint32_t>(result.boundary.hard.size() + 1);
            result.boundary.hard.push_back({port_id, id, target, target,
                {-contact.facing.x, -contact.facing.y}, Family::Frame, false, 1.0, "adapted-masonry-bearing"});
        }
        ++additions;
        ++result.metrics["foreign_transition_pieces"];
    }
}

} // namespace cybersand::gentek_swarm
