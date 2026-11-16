#include "negotiated.hpp"
#include "cybersand/generation_spatial.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <limits>
#include <memory>
#include <set>
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
// The candidate's receiving buttress is authored in MOSAIC's own contour
// coordinates. It is never parameterised by a foreign endpoint or raster patch.
// Legacy contour_cell remains untouched for the SWARM-001 control.
bool negotiated_cell(const Tile& t, unsigned motif, int x, int y) {
    if (!tile_has(t, x, y)) return false;
    if (t.full) return interior_cell(motif, x, y);
    if (motif != Buttress) return contour_cell(t, motif, x, y);
    if (!tile_has(t, x, y)) return false;
    const auto [left, right] = row_span(t, x, y);
    const auto [top, bottom] = column_span(t, x, y);
    if (right - left < 2 || bottom - top < 2) return false;
    // A closed stepped receiving pier, with a bounded tapered return and base.
    // A concavity stays split because every extent comes from its admitted span.
    const int taper = 2 + (y - top) / 4;
    if (t.edge == TermWest) return x - left <= taper || bottom - y < 2 || y - top < 2;
    if (t.edge == TermEast) return right - x <= taper || bottom - y < 2 || y - top < 2;
    if (t.edge == TermNorth) return y - top <= 2 + (x - left) / 4 || right - x < 2 || x - left < 2;
    return bottom - y <= 2 + (x - left) / 4 || right - x < 2 || x - left < 2;
}

bool envelope_has(const TransitionSlot& slot, Point p) {
    return p.x >= slot.envelope.x && p.y >= slot.envelope.y &&
           p.x < slot.envelope.x + slot.envelope.w &&
           p.y < slot.envelope.y + slot.envelope.h;
}
Point segment_nearest(const TransitionSlot& slot, Point p) {
    return {std::clamp(p.x, std::min(slot.a.x, slot.b.x), std::max(slot.a.x, slot.b.x)),
            std::clamp(p.y, std::min(slot.a.y, slot.b.y), std::max(slot.a.y, slot.b.y))};
}

bool validate_slots(const Request& req, Result& result, const std::vector<TransitionSlot>& slots) {
    const auto invalid = [&](const std::string& why) {
        result.status = Status::Invalid; result.termination = why; return false;
    };
    if (slots.size() > max_transition_slots) return invalid("negotiation exceeds eight finite transition slots");
    std::set<std::uint32_t> ids;
    for (const auto& slot : slots) {
        if (!charge(req, result)) return false;
        const auto& box = slot.envelope;
        if (slot.kind == SlotKind::PassageOpening)
            return invalid("PassageOpening reservation semantics are unsupported in SWARM-002; only material bearings are qualified");
        if (!ids.insert(slot.id).second || slot.id == 0 || slot.instance == 0 || slot.connector == 0 ||
            !inside(req, slot.a) || !inside(req, slot.b) ||
            static_cast<unsigned>(slot.kind) > static_cast<unsigned>(SlotKind::PassageOpening) ||
            std::abs(static_cast<std::int64_t>(slot.facing.x)) + std::abs(static_cast<std::int64_t>(slot.facing.y)) != 1 ||
            (slot.a.x != slot.b.x && slot.a.y != slot.b.y) ||
            (slot.b.x - slot.a.x) * slot.facing.x + (slot.b.y - slot.a.y) * slot.facing.y != 0 ||
            (slot.kind == SlotKind::BearingSegment && slot.a == slot.b) ||
            std::abs(slot.a.x - slot.b.x) + std::abs(slot.a.y - slot.b.y) > 32 ||
            (slot.kind == SlotKind::PointSocket && slot.a != slot.b) ||
            box.x < 0 || box.y < 0 || box.w < 1 || box.h < 1 || box.w > 64 || box.h > 64 ||
            box.x > req.width - box.w || box.y > req.height - box.h ||
            !envelope_has(slot, slot.a) || !envelope_has(slot, slot.b) ||
            !std::isfinite(slot.strength) || slot.strength < 0 || slot.strength > 1 ||
            slot.owner != "FRAMEWEAVER" || slot.reason.size() > 512 || slot.clearance.size() > 4096)
            return invalid("invalid finite FRAMEWEAVER transition reservation");
        // The caller additionally binds these nonzero owner/connector identities
        // to FramePlan's graph. This boundary can validate the immutable material
        // witness, but cannot invent or certify a foreign mechanical graph.
        for (const auto p : line(slot.a, slot.b)) {
            if (!charge(req, result)) return false;
            const auto i = index(req, p);
            if (req.neighbor_cells.empty() || req.neighbor_cells[i] == Material::Empty ||
                (!req.eligible.empty() && req.eligible[i]))
                return invalid("reservation source segment lacks foreign-owned immutable material");
        }
        for (const auto p : slot.clearance) {
            if (!charge(req, result)) return false;
            if (!inside(req, p) || !envelope_has(slot, p))
                return invalid("reservation clearance outside declared finite envelope");
            const auto i = index(req, p);
            if ((req.protected_void.empty() || !req.protected_void[i]) &&
                (req.neighbors.protected_geometry.empty() || !req.neighbors.protected_geometry[i]))
                return invalid("reservation clearance must also be present in canonical protected mask");
        }
    }
    return true;
}

// Geometry witnesses are evaluated from the same authored category predicates
// later used to rasterise. A compatible bit is not a claim about an imagined
// contact, nor does a bearing imply a traversable doorway.
std::uint16_t receiving_categories(const Tile& tile, const TransitionSlot& slot, Point p) {
    const unsigned edge = slot.facing.x > 0 ? TermWest : slot.facing.x < 0 ? TermEast :
                          slot.facing.y > 0 ? TermNorth : TermSouth;
    std::uint16_t candidates = static_cast<std::uint16_t>(bit(edge) | bit(Buttress));
    const int x = p.x - tile.x, y = p.y - tile.y;
    std::uint16_t admitted = 0;
    for (unsigned motif = 0; motif < motif_count; ++motif) {
        if (!(candidates & bit(motif))) continue;
        if (!negotiated_cell(tile, motif, x, y) ||
            !negotiated_cell(tile, motif, x + slot.facing.x, y + slot.facing.y) ||
            negotiated_cell(tile, motif, x - slot.facing.x, y - slot.facing.y)) continue;
        if (slot.kind == SlotKind::BearingSegment) {
            const Point tangent{-slot.facing.y, slot.facing.x};
            if (!negotiated_cell(tile, motif, x + tangent.x, y + tangent.y) ||
                !negotiated_cell(tile, motif, x - tangent.x, y - tangent.y)) continue;
        }
        admitted |= bit(motif);
    }
    return admitted;
}

bool impose_reservations(const Request& req, Result& result, const std::vector<Tile>& tiles,
                         spatial::RegionAssignment& assignment, const std::vector<TransitionSlot>& slots,
                         MosaicPlan& plan, bool& soft_intervention) {
    plan.categories.assign(tiles.size(), -1);
    plan.domains.reserve(tiles.size());
    for (std::size_t i = 0; i < tiles.size(); ++i) {
        DomainDecision d;
        d.tile = static_cast<std::uint32_t>(i); d.origin = {tiles[i].x, tiles[i].y};
        d.original_domain = d.preferred_domain = d.modified_domain = d.hard_domain = assignment.domains[i];
        plan.domains.push_back(d);
    }
    auto ordered = slots;
    std::sort(ordered.begin(), ordered.end(), [](const auto& a, const auto& b) {
        return std::tie(a.a, a.b, a.facing, a.id) < std::tie(b.a, b.b, b.facing, b.id);
    });
    bool impossible_hard = false;
    for (const auto& slot : ordered) {
        SlotResponse response; response.slot_id = slot.id;
        response.facing = {-slot.facing.x, -slot.facing.y};
        response.reason = "no admitted receiving face in finite slot envelope";
        int best = std::numeric_limits<int>::max();
        for (int y = slot.envelope.y; y < slot.envelope.y + slot.envelope.h; ++y) {
            for (int x = slot.envelope.x; x < slot.envelope.x + slot.envelope.w; ++x) {
                if (!charge(req, result, 40)) return false;
                const Point p{x, y}, source = segment_nearest(slot, p);
                const Point outward{x - slot.facing.x, y - slot.facing.y};
                if (!allowed(req, p) || !transition_at(req, p) || allowed(req, outward) ||
                    (x - source.x) * slot.facing.x + (y - source.y) * slot.facing.y <= 0) continue;
                if (slot.strength == 0 && !slot.hard) continue;
                if (req.neighbor_cells.empty() || req.neighbor_cells[index(req, source)] == Material::Empty) continue;
                const auto tile_index = static_cast<std::size_t>(y / pitch) * assignment.width + static_cast<unsigned>(x / pitch);
                if (assignment.domains[tile_index] == bit(Exterior)) continue;
                const auto categories = receiving_categories(tiles[tile_index], slot, p);
                if (!categories) continue;
                const int score = std::abs(x - source.x) + std::abs(y - source.y);
                if (score < best || (score == best && p < response.contact)) {
                    best = score; response.contact = p;
                    response.tile = static_cast<std::uint32_t>(tile_index);
                    response.compatible_domain = categories; response.admitted = true;
                }
            }
        }
        if (response.admitted) {
            response.reason = "MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness";
            DomainInfluence influence;
            influence.slot_id = slot.id; influence.compatible_domain = response.compatible_domain;
            influence.hard = slot.hard; influence.admitted = true;
            influence.contact = response.contact; influence.reason = response.reason;
            plan.domains[response.tile].influences.push_back(influence);
        } else {
            ++result.rejected["reservation_without_admissible_motif"];
            impossible_hard = impossible_hard || slot.hard;
        }
        plan.responses.push_back(response);
    }
    for (auto& d : plan.domains) {
        auto hard_pool = d.original_domain, preferred_pool = d.original_domain;
        for (const auto& influence : d.influences) {
            preferred_pool |= influence.compatible_domain;
            if (influence.hard) hard_pool |= influence.compatible_domain;
        }
        d.hard_domain = hard_pool; d.preferred_domain = preferred_pool;
        for (const auto& influence : d.influences) {
            d.preferred_domain &= influence.compatible_domain;
            if (influence.hard) d.hard_domain &= influence.compatible_domain;
        }
        impossible_hard = impossible_hard || d.hard_domain == 0;
        soft_intervention = soft_intervention || d.hard_domain != d.preferred_domain;
        d.modified_domain = d.preferred_domain;
        assignment.domains[d.tile] = d.modified_domain;
    }
    if (impossible_hard) {
        result.status = Status::Unsat;
        result.termination = "hard reservation has no receiving motif or has an empty categorical intersection";
        plan.attempts.push_back({"hard-domain-conflict", result.termination, Status::Unsat, false, true, 0, 0});
        result.metrics["solver_attempted"] = 0; result.metrics["solver_work_observed"] = 1;
        result.metrics["hard_negotiation_unsat"] = 1;
        return false;
    }
    return true;
}
} // namespace

static Result generate_mosaic_impl(const Request& req, const std::vector<TransitionSlot>* slots,
                                  MosaicPlan* plan) {
    Result result = begin_result(req, plan ? "prepared-regions-negotiated-v1" : "prepared-regions-motifs-v0");
    if (result.cells.empty() || result.status == Status::Invalid || result.status == Status::Exhausted)
        return result;
    if (plan && (!slots || !validate_slots(req, result, *slots))) return result;
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
    bool soft_intervention = false;
    if (plan && !impose_reservations(req, result, tiles, assignment, *slots, *plan, soft_intervention))
        return result;
    std::shared_ptr<const spatial::PreparedRegions> prepared;
    if (plan) {
        result.metrics["solver_attempted"] = 0;
        result.metrics["solver_work_observed"] = 1;
        const auto solve = [&](const std::string& policy, std::uint64_t limit) {
            SolverAttempt attempt; attempt.policy = policy; attempt.work_limit = limit;
            if (std::any_of(assignment.domains.begin(), assignment.domains.end(), [](auto domain) { return domain == 0; })) {
                attempt.status = Status::Unsat; attempt.work_observed = true;
                attempt.reason = "explicit empty preferred-domain intersection; GEN-003 not invoked";
            } else if (limit == 0) {
                attempt.status = Status::Exhausted; attempt.work_observed = true;
                attempt.reason = "no remaining categorical work budget";
            } else {
                attempt.attempted = true; ++result.metrics["solver_attempted"];
                result.metrics["solver_work_upper_bound"] += limit;
                try {
                    prepared = spatial::PreparedRegions::compile(assignment, {limit, spatial::kRegionSolverScratchBytes});
                    attempt.status = Status::Complete; attempt.work_observed = true;
                    attempt.work = prepared->preparation_work();
                    attempt.reason = "unchanged GEN-003 propagation/backtracking completed";
                } catch (const spatial::RegionAssignmentUnsatisfiable& e) {
                    attempt.status = Status::Unsat; attempt.reason = e.what();
                } catch (const spatial::RegionAssignmentExhausted& e) {
                    attempt.status = Status::Exhausted; attempt.reason = e.what();
                } catch (const std::invalid_argument& e) {
                    attempt.status = Status::Invalid; attempt.reason = e.what();
                }
            }
            result.solver_work += attempt.work;
            result.metrics["solver_work_observed"] &= static_cast<std::uint64_t>(attempt.work_observed);
            plan->attempts.push_back(attempt);
            return attempt.status;
        };
        const auto first_budget = soft_intervention ? req.limits.max_solver_work / 2 : req.limits.max_solver_work;
        auto status = solve(soft_intervention ? "preferred-domains" : "hard-or-unoffered-domains", first_budget);
        if (status == Status::Unsat && soft_intervention) {
            for (auto& d : plan->domains) {
                d.fallback = true; d.modified_domain = d.hard_domain;
                assignment.domains[d.tile] = d.modified_domain;
            }
            ++result.metrics["soft_preference_unsat_fallback"];
            status = solve("hard-only-fallback-after-proven-unsat", req.limits.max_solver_work - first_budget);
        }
        if (status != Status::Complete) {
            result.status = status; result.termination = plan->attempts.back().reason;
            if (status == Status::Unsat) result.metrics["hard_negotiation_unsat"] =
                static_cast<std::uint64_t>(std::any_of(slots->begin(), slots->end(), [](const auto& slot) { return slot.hard; }));
            result.notes.push_back("No partial categorical assignment is rasterised; exhaustion is unknown, not UNSAT.");
            return result;
        }
        result.metrics["solver_successful_attempt_work"] = prepared->preparation_work();
        result.notes.push_back("Soft preference is domain restriction with at most one hard-only retry after proven UNSAT, not category weighting.");
        result.notes.push_back("Per-attempt receipts preserve unavailable failed-solver work; configured attempt ceilings sum to the request ceiling.");
    } else {
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
    }
    result.metrics["solver_definition_fingerprint"] = prepared->fingerprint();
    result.metrics["logical_tiles"] = tiles.size();
    result.metrics["solver_categories"] = motif_count;
    result.metrics["backtracking_metric_available"] = 0;
    result.backtracks = -1;
    result.notes.push_back("GEN-003 performs bounded propagation/backtracking; its public API exposes total work, not backtrack count.");
    result.notes.push_back("Motif doorway compatibility is local; this is not a global support or post-simulation stability certificate.");
    if (plan) {
        // Retain the complete solved assignment even if the separately bounded
        // raster stage later exhausts its own generator work budget.
        for (std::size_t i = 0; i < tiles.size(); ++i) {
            const auto motif = static_cast<unsigned>(prepared->cells()[i] - UINT64_C(0x4d4f534149430000));
            plan->categories[i] = static_cast<int>(motif);
            auto& decision = plan->domains[i];
            decision.selected = static_cast<int>(motif);
            decision.preference_satisfied = !decision.influences.empty() &&
                std::all_of(decision.influences.begin(), decision.influences.end(),
                            [&](const auto& influence) { return (influence.compatible_domain & bit(motif)) != 0; });
        }
    }
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
        if (plan && !plan->domains[tile_index].influences.empty()) {
            instance.reason += "; precompile FRAMEWEAVER reservation IDs";
            for (const auto& influence : plan->domains[tile_index].influences)
                instance.reason += " " + std::to_string(influence.slot_id);
        }
        const bool ornamented = tile.full && (motif == Vault || motif == Gallery) &&
            unit(req.seed ^ mix(tile_index) ^ UINT64_C(0x636f7262656c)) < req.profile.clutter;
        for (int y = 0; y < tile.height; ++y) for (int x = 0; x < tile.width; ++x) {
            if (!charge(req, result)) return result;
            const bool ornament = ornamented && (x == 4 || x == 11) && y >= 2 && y <= 4;
            const bool occupied = ornament || (plan ? negotiated_cell(tile, motif, x, y) :
                (tile.full ? interior_cell(motif, x, y) : contour_cell(tile, motif, x, y)));
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
    if (plan) result.metrics["rasterisation_completed"] = 1;
    if (result.instances.empty()) {
        result.status = Status::Blocked; result.termination = "no admitted MOSAIC motif footprint";
    } else {
        result.termination = "finite GEN-003 motif assignment completed before raster sampling";
    }
    return result;
}

Result generate_mosaic(const Request& req) {
    return generate_mosaic_impl(req, nullptr, nullptr);
}

const char* mosaic_category_name(unsigned motif) noexcept {
    return motif < motif_count ? motif_names[motif] : "unselected";
}

MosaicPlan negotiate_mosaic(const Request& req, const std::vector<TransitionSlot>& slots) {
    MosaicPlan plan;
    if (req.gentek != Kind::Mosaic) {
        plan.result = begin_result(req, "prepared-regions-negotiated-v1");
        plan.result.status = Status::Invalid;
        plan.result.termination = "negotiated MOSAIC requires a MOSAIC request";
        return plan;
    }
    plan.result = generate_mosaic_impl(req, &slots, &plan);
    auto& result = plan.result;
    finish_result(req, result);
    apply_damage(req, result);
    // Material witnesses are rechecked after full rasterisation (and any explicit
    // damage derivative), so a category choice alone cannot claim a real joint.
    for (auto& response : plan.responses) {
        if (!response.admitted || response.tile >= plan.categories.size() || plan.categories[response.tile] < 0) continue;
        const auto slot = std::find_if(slots.begin(), slots.end(), [&](const auto& value) { return value.id == response.slot_id; });
        if (slot == slots.end()) continue;
        const auto selected = static_cast<unsigned>(plan.categories[response.tile]);
        const Point outward{response.contact.x + response.facing.x, response.contact.y + response.facing.y};
        const bool in_result = inside(req, response.contact) && index(req, response.contact) < result.cells.size();
        const bool material = in_result && result.cells[index(req, response.contact)] != Material::Empty;
        const bool exposed = !inside(req, outward) || result.cells[index(req, outward)] == Material::Empty;
        response.satisfied = (response.compatible_domain & bit(selected)) != 0 && material && exposed;
        if (!response.satisfied) response.reason += "; selected assignment did not satisfy this preference or damage revoked its contact";
        if (!response.satisfied) continue;
        const auto owner = result.provenance[index(req, response.contact)];
        const auto count = std::count_if(result.boundary.hard.begin(), result.boundary.hard.end(),
                                        [&](const auto& a) { return a.instance == owner; });
        const auto duplicate = std::find_if(result.boundary.hard.begin(), result.boundary.hard.end(), [&](const auto& a) {
            return a.a == response.contact && a.b == response.contact && a.facing == response.facing && a.family == Family::Frame;
        });
        if (duplicate == result.boundary.hard.end() && result.boundary.hard.size() < req.limits.max_affordances &&
            count < req.limits.max_connectors_per_instance) {
            result.boundary.hard.push_back({static_cast<std::uint32_t>(result.boundary.hard.size() + 1), owner,
                response.contact, response.contact, response.facing, Family::Frame, false, 1.0,
                "preplanned-masonry-bearing"});
        }
    }
    result.metrics["negotiated_slots_offered"] = slots.size();
    result.metrics["negotiated_slots_admitted"] = std::count_if(plan.responses.begin(), plan.responses.end(),
        [](const auto& response) { return response.admitted; });
    result.metrics["negotiated_slots_satisfied"] = std::count_if(plan.responses.begin(), plan.responses.end(),
        [](const auto& response) { return response.satisfied; });
    result.metrics["negotiated_domains_changed"] = std::count_if(plan.domains.begin(), plan.domains.end(),
        [](const auto& d) { return d.modified_domain != d.original_domain; });
    finish_result(req, result);
    return plan;
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
