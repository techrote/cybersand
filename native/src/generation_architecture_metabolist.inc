// GENTEK-SHOWCASE-METABOLIST-001: one service spine, six private attachment
// families and deliberate vacancies. This is immutable geometry, not assembly.
class MetabolistSpine final : public FeatureSampler {
    ArchitectureForm p_;
    std::uint64_t seed_;
    std::int64_t pitch_, core_, datum_;
    struct Slot { unsigned family; std::int64_t reach; };

    // BAND / ATTACHMENT SLOT. One whole band in six stays empty on both sides;
    // other vacancies and families are selected once per logical attachment.
    Slot slot(std::int64_t column, std::int64_t band, bool right) const noexcept {
        const auto h = hash_xy(seed_, column, band, right ? 2113 : 2111);
        if (positive_mod(band + static_cast<std::int64_t>(seed_ % 6U), 6) == 5)
            return {0, 0};
        const auto family = static_cast<unsigned>(h % 7U);
        const auto requested = family == 1 ? 2 * p_.bay / 3 :
            p_.bay * (54 + static_cast<std::int64_t>((h >> 16) % 25U)) / 64;
        return {family, std::min(requested, pitch_ / 2 - core_ - 3 * p_.wall)};
    }

    // BRIDGE. Both endpoints use this same boundary identity. A bridge is
    // admitted only between occupied slots; its extent starts at their decks.
    bool bridge(std::int64_t left_column, std::int64_t band) const noexcept {
        return slot(left_column, band, true).family != 0 &&
            slot(left_column + 1, band, false).family != 0 &&
            hash_xy(seed_, left_column, band, 2117) % 6U == 0;
    }

    // A bounded integer segment test, with endpoints included. No raster loop.
    bool rib(std::int64_t x, std::int64_t y, std::int64_t ax, std::int64_t ay,
             std::int64_t bx, std::int64_t by) const noexcept {
        if (x < std::min(ax, bx) - p_.wall || x > std::max(ax, bx) + p_.wall ||
            y < std::min(ay, by) - p_.wall || y > std::max(ay, by) + p_.wall) return false;
        return std::abs((x - ax) * (by - ay) - (y - ay) * (bx - ax)) <=
            p_.wall * std::max(std::abs(bx - ax), std::abs(by - ay));
    }

    // POD TYPE. Every family has a deliberate root and a common outer datum.
    // Family 5 transfers its weight to the upper boom through two hangers.
    Material attachment(const Slot& s, std::int64_t d, std::int64_t y) const noexcept {
        if (s.family == 0 || d < 0 || d > s.reach) return Material::Empty;
        const auto w = p_.wall, deck = datum_, high = p_.level / 6;
        const auto bottom = deck + w, nose = s.reach;
        const bool floor = std::abs(y - deck) <= w;
        if (s.family != 5 && floor) return p_.deck;
        // CANTILEVER ROOT: compact haunch below the deck, attached to the core.
        if (s.family != 5 && d <= p_.bay / 3 && y > deck &&
            y <= deck + std::max<std::int64_t>(0, p_.level / 7 - d * p_.level / (3 * p_.bay)))
            return p_.shell;
        if (s.family == 3) { // Open service platform with a visible knee brace.
            if (rib(d, y, 0, deck + p_.level / 5, nose, deck)) return p_.accent;
            return Material::Empty;
        }
        if (s.family == 6) { // Open outrigger, distinct from an enclosed pod.
            if (rib(d, y, 0, high, nose, deck) ||
                (d < w && y >= high && y <= deck)) return p_.accent;
            return Material::Empty;
        }
        if (s.family == 5) { // Hanging module, with no unsupported inner shelf.
            const auto start = nose / 3, top = p_.level / 2;
            if (std::abs(y - high) <= w) return p_.deck;
            if ((std::abs(d - start) <= w || d >= nose - w) && y >= high && y <= top)
                return p_.spine;
            if (d < start || y < top || y > bottom) return Material::Empty;
            if (floor || std::abs(y - top) <= w) return p_.deck;
            if (d <= start + w || d >= nose - w) return p_.shell;
            if (p_.windows && d > start + w && d < nose - w &&
                y > top + w && y < deck - w) return p_.glazing;
            return Material::Empty;
        }
        // Compact pod, tall open frame, or a stepped glazed habitat.
        const auto top = s.family == 1 ? p_.level / 2 : high;
        const auto step = p_.level / 3;
        const auto roof = s.family == 4 && d > nose / 2 ? step : top;
        if (y < roof || y > bottom) return Material::Empty;
        if (std::abs(y - roof) <= w) return p_.deck;
        if (s.family == 4 && std::abs(d - nose / 2) <= w && y <= step) return p_.shell;
        const bool outer = d >= nose - w;
        if (outer && p_.doors && y >= deck - p_.door && y < deck - w)
            return Material::Empty;
        if (outer) return p_.shell;
        if (s.family == 2) {
            if (std::abs(d - nose / 2) <= w && y >= top && y < deck) return p_.spine;
            if (std::abs(y - (top + deck) / 2) <= w) return p_.accent;
            return Material::Empty;
        }
        if (p_.windows && d > 0 && d < nose - w &&
            y > roof + w && y < deck - w) return p_.glazing;
        return Material::Empty;
    }

public:
    MetabolistSpine(const ModuleInstance& i, std::uint64_t seed)
        : p_(i), seed_(seed), pitch_(3 * p_.bay),
          core_(std::max(3 * p_.wall + 2, p_.bay / 7)), datum_(3 * p_.level / 4) {
        require(p_.bay >= 6 * p_.wall + 24 && p_.level >= 6 * p_.wall + 28,
            "metabolist_spine needs room/floor clearance for distinct rooted attachments");
    }
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x = c.x - p_.bounds.x, y = c.y - p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        // Anchor the first spine one base bay into the map. Nearest-core
        // territories keep complete attachments on both sides of each spine.
        const auto phased_x = x + pitch_ / 2 - p_.bay;
        const auto column = floor_div(phased_x, pitch_), band = floor_div(y, p_.level);
        const auto local = positive_mod(phased_x, pitch_) - pitch_ / 2;
        const auto fy = positive_mod(y, p_.level), distance = std::abs(local);
        // SPINE: broad continuous rails, narrow service slot and common datums.
        // Slot cuts never sever the two load-bearing rails.
        if (distance <= core_) {
            if (distance <= p_.wall && std::abs(fy - datum_) > p_.wall && fy > p_.wall)
                return Material::Empty;
            if (std::abs(fy - datum_) <= p_.wall) return p_.deck;
            return distance >= core_ - p_.wall ? p_.spine : p_.shell;
        }
        const bool right = local > 0;
        const auto selected = slot(column, band, right);
        const auto d = distance - core_;
        const auto material = attachment(selected, d, fy);
        if (material != Material::Empty) return material;
        // A shared boundary bridge spans only the gap between actual pod decks.
        const auto left_column = right ? column : column - 1;
        if (d >= selected.reach && std::abs(fy - datum_) <= p_.wall &&
            bridge(left_column, band)) return p_.deck;
        return Material::Empty;
    }
};
