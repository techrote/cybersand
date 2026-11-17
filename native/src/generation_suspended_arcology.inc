// GENTEK-SHOWCASE-SUSPENDED-001: one carrier owns a hanging city below it.
// Absolute-coordinate, bounded geometric programmes; no structural-physics claim.
class SuspendedArcology final : public FeatureSampler {
    ArchitectureForm p_;
    std::uint64_t seed_;
    struct District {
        std::int64_t type, roof, floor;
        bool occupied, core;
    };
    District district(std::uint64_t code, std::int64_t panel) const noexcept {
        const auto core = 1 + static_cast<std::int64_t>(code % 4U);
        const auto choice = hash_xy(code, panel, 0, 1933);
        const bool occupied = panel != (core + 3) % 6 && (panel == core || panel == core + 1 || panel == (core + 2) % 6 || (choice % 3U) == 0);
        const auto type = 1 + static_cast<std::int64_t>((choice >> 3) % 5U);
        const auto floor = 9 * p_.level / 2 + ((code & 16U) ? p_.level / 2 : 0);
        const auto depth = type == 2 || type == 5 ? 2 * p_.level :
            (type == 4 ? p_.level / 2 : 3 * p_.level / 2);
        return {type, floor - depth, floor, occupied, panel == core};
    }
public:
    SuspendedArcology(const ModuleInstance& i, std::uint64_t seed) : p_(i), seed_(seed) {
        require(p_.bay >= 32 && p_.level >= 32,
            "suspended_arcology needs bay and floor height of at least 32 cells");
    }
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        if (p_.in_shaft(c.x - p_.bounds.x)) return Material::Empty;
        // SUPERCELL: six carrier panels and a seven-floor vertical hierarchy.
        const auto width = 6 * p_.bay, height = 7 * p_.level;
        const auto column = floor_div(c.x, width), row = floor_div(c.y, height);
        const auto x = positive_mod(c.x, width), y = positive_mod(c.y, height);
        const auto code = hash_xy(seed_, column, row, 1927);
        const auto panel = x / p_.bay, bx = x % p_.bay, w = p_.wall;
        const auto upper = p_.level / 2, lower = 3 * p_.level / 2;
        const auto chosen = district(code, panel);
        const auto margin = p_.bay / 8, end = p_.bay - margin;
        const auto hanger_left = p_.bay / 4, hanger_right = 3 * p_.bay / 4;

        // UPPER CARRIER: heavy paired chords, vertical nodes, alternating web.
        if (y >= upper && y <= lower) {
            if (y < upper + 2 * w || y > lower - 3 * w) return p_.deck;
            if (bx < 2 * w || bx >= p_.bay - 2 * w) return p_.shell;
            const auto rise = lower - upper, sy = y - upper;
            const auto dx = (panel & 1) ? p_.bay - 1 - bx : bx;
            if (std::abs(dx * rise - sy * p_.bay) <= w * std::max(rise, p_.bay))
                return p_.accent;
            return Material::Empty;
        }

        // UPPER CROWN: a single plant/tower, always based on the top chord.
        const auto tower = static_cast<std::int64_t>((code >> 6) % 6U);
        if (panel == tower && y < upper && bx >= margin && bx <= end) {
            const auto roof = (code & 64U) ? 2 * w : p_.level / 5;
            if (y >= roof && (y < roof + w || bx < margin + w || bx > end - w))
                return p_.shell;
            if (p_.windows && y >= roof + 2 * w && bx > margin + 2 * w &&
                bx < end - 2 * w) return p_.glazing;
        }

        // EMPTY SLOTS never acquire their own hangers or unsupported districts.
        if (y <= lower || !chosen.occupied) return Material::Empty;

        // VERTICAL CORE: a broad service mast ties one district to the carrier.
        const auto core_half = std::max<std::int64_t>(2 * w + 1, p_.bay / 8);
        if (chosen.core && std::abs(bx - p_.bay / 2) <= core_half && y <= chosen.floor) {
            const auto dx = std::abs(bx - p_.bay / 2);
            if (dx >= core_half - w || positive_mod(y, p_.level / 2) < w)
                return dx >= core_half - w ? p_.shell : p_.deck;
            if (p_.windows && dx < core_half - w && y < chosen.roof)
                return p_.glazing;
        }

        // HANGERS: both roots touch the lower chord and both reach a real roof.
        if ((std::abs(bx - hanger_left) < w || std::abs(bx - hanger_right) < w) &&
            y <= chosen.roof + w) return p_.accent;

        // BRIDGE: only the selected core and its guaranteed occupied neighbour.
        // Both floors share the same datum; empty panels cannot receive a bridge.
        const auto core = 1 + static_cast<std::int64_t>(code % 4U);
        const bool bridge = (panel == core || panel == core + 1);
        if (bridge && y >= chosen.floor && y < chosen.floor + w &&
            ((panel == core && bx >= end) || (panel == core + 1 && bx <= margin)))
            return p_.deck;

        // SUSPENDED MASS: five families use common endpoints and distinct silhouettes.
        if (bx < margin || bx > end || y < chosen.roof || y > chosen.floor + w)
            return Material::Empty;
        const auto inner_y = y - chosen.roof, depth = chosen.floor - chosen.roof;
        if (inner_y < w || y >= chosen.floor) return p_.deck;
        // Stepped habitats narrow their upper volume but retain a full carrier roof.
        const auto facade_end = chosen.type == 1 && inner_y < depth / 2 ? end - p_.bay / 5 : end;
        if (bx > facade_end) return Material::Empty;
        const bool side = bx < margin + w || bx > facade_end - w;
        if (chosen.type == 1 && std::abs(inner_y - depth / 2) < w) return p_.deck;
        const bool doorway = p_.doors && y > chosen.floor - p_.door &&
            bx >= p_.bay / 2 - p_.door / 2 && bx < p_.bay / 2 + p_.door / 2;
        if (chosen.type == 5) {
            // Narrow service strip, with a rooted lateral floor and hanger roof.
            if (std::abs(bx - p_.bay / 2) > p_.bay / 5) return Material::Empty;
            if (std::abs(bx - p_.bay / 2) >= p_.bay / 5 - w) return p_.shell;
        } else if (side) return p_.shell;
        if (chosen.type == 3) {
            if (std::abs((bx - margin) * depth - inner_y * (end - margin)) <=
                w * std::max(depth, end - margin)) return p_.accent;
            return Material::Empty;
        }
        if (chosen.type == 2 && positive_mod(inner_y, p_.level / 2) < w) return p_.deck;
        if (doorway) return Material::Empty;
        if (chosen.type == 4 && inner_y > w) return Material::Empty;
        // Mullions retain precedence: glazing only fills empty framed apertures.
        if (std::abs(bx - p_.bay / 2) < w) return p_.shell;
        if (p_.windows && bx >= margin + w && bx <= facade_end - w &&
            inner_y >= w && y < chosen.floor) return p_.glazing;
        return Material::Empty;
    }
};
