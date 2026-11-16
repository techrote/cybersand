// GENTEK-SHOWCASE-INTERLOCK-001: complementary masses around a shared void.
// World-space supercells are immutable; bounds clip rather than rephase them.
class InterlockBrutalism final : public FeatureSampler {
    ArchitectureForm p_;
    std::uint64_t seed_;
    struct Programme {
        std::int64_t left, right, bridge_band;
        bool reverse;
        std::uint64_t code;
    };
    Programme programme(std::int64_t column, std::int64_t row) const noexcept {
        const auto code = hash_xy(seed_, column, row, 1907);
        return {2 * p_.bay / 3 + p_.wall * 2 + static_cast<std::int64_t>(code % 3U) * p_.wall,
            p_.bay / 3 + p_.wall * 2,
            (code & 8U) ? 3 + static_cast<std::int64_t>((code >> 4) & 1U) : -1,
            (code & 32U) != 0, code};
    }
public:
    InterlockBrutalism(const ModuleInstance& i, std::uint64_t seed) : p_(i), seed_(seed) {
        require(p_.bay >= 32 && p_.level >= 32,
            "interlock_brutalism needs bay and floor height of at least 32 cells");
    }
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        if (p_.in_shaft(c.x - p_.bounds.x)) return Material::Empty;
        // SUPERCELL: six floors make paired, missing and double-height bands.
        const auto width = 4 * p_.bay, height = 6 * p_.level;
        const auto column = floor_div(c.x, width), row = floor_div(c.y, height);
        const auto plan = programme(column, row);
        const auto u = positive_mod(c.x, width), y = positive_mod(c.y, height);
        const auto x = plan.reverse ? width - 1 - u : u;
        const auto band = y / p_.level, fy = y % p_.level;
        const auto w = p_.wall, left = plan.left, right = width - plan.right;
        const auto slot = (band + static_cast<std::int64_t>((plan.code >> 6) & 1U)) % 6;
        const bool left_on = slot == 0 || slot == 1 || slot == 3 || slot == 4;
        const bool right_on = slot == 0 || slot == 2 || slot == 3 || slot == 4;
        const auto left_y = p_.level / 3;
        const auto right_y = 3 * p_.level / 4;
        const auto left_end = 2 * p_.bay + (slot == 1 ? p_.bay / 2 : p_.bay / 6);
        const auto right_end = 2 * p_.bay - (slot == 2 ? p_.bay / 2 : p_.bay / 5);
        const auto mass = 2 * w + p_.level / 16;
        const auto recess_height = std::max<std::int64_t>(6, p_.level / 4);

        // LEFT CORE / RIGHT CORE: broad recessed concrete versus a narrow mast.
        // A fixed outer backbone survives apertures; floors root into the core.
        if (x < left || x >= right) {
            const bool is_left = x < left;
            const auto inner = is_left ? x : width - 1 - x;
            const auto core_width = is_left ? left : plan.right;
            if (inner < 2 * w || inner >= core_width - w) return p_.shell;
            if (fy < w || fy >= p_.level - w) return p_.deck;
            if (p_.doors && fy > p_.level - p_.door - w &&
                inner >= core_width / 2) return Material::Empty;
            if (is_left && inner > core_width / 2 && inner < core_width - 2 * w &&
                fy > p_.level / 4 && fy < 3 * p_.level / 4)
                return p_.windows && slot == 1 ? p_.glazing : Material::Empty;
            if (!is_left && inner > 2 * w && inner < core_width - 2 * w)
                return Material::Empty;
            return p_.shell;
        }

        // BRIDGE RULE: at most one full connection in a six-floor programme.
        // Its clear chamber above/below is retained; a bridge is not a pathfinding claim.
        const bool bridge = band == plan.bridge_band;
        const auto bridge_y = p_.level / 2;
        if (bridge && fy >= bridge_y && fy < bridge_y + 2 * w) return p_.deck;
        if (bridge && fy >= bridge_y + 2 * w && fy < bridge_y + 4 * w &&
            (x < left + p_.bay / 3 || x > right - p_.bay / 3)) return p_.accent;

        // LEFT PROJECTION: grouped deep fingers with open upper recesses.
        if (left_on && x <= left_end) {
            if (fy >= left_y && fy < left_y + mass) return p_.deck;
            if (x >= left_end - w && fy >= left_y - recess_height && fy < left_y)
                return p_.shell;
            if (slot == 1 && fy >= left_y - recess_height &&
                fy < left_y - recess_height + w) return p_.shell;
            if (slot == 1 && p_.windows && x >= left && x < left_end - w &&
                fy >= left_y - recess_height + w && fy < left_y) return p_.glazing;
            // Solid root haunch: a closed-form triangular support, never a floating shelf.
            const auto run = p_.bay / 2, depth = p_.level / 5;
            if (x < left + run && fy >= left_y + mass &&
                (fy - left_y - mass) * run + (x - left) * depth <= run * depth)
                return p_.shell;
        }

        // RIGHT PROJECTION: offset thin beams and bounded suspended returns.
        if (right_on && x >= right_end) {
            if (fy >= right_y && fy < right_y + w + p_.level / 20) return p_.deck;
            if (slot == 3 && x < right_end + w && fy > right_y &&
                fy < p_.level - w) return p_.accent;
            if (slot == 3 && fy >= p_.level - 2 * w && fy < p_.level - w &&
                x < right_end + p_.bay / 3) return p_.deck;
            const auto run = p_.bay / 2, depth = p_.level / 5;
            if (x > right - run && fy < right_y &&
                (right_y - fy) * run + (right - x) * depth <= run * depth)
                return p_.shell;
        }

        // VOID ENVELOPE: all other cells stay empty. The two offset programmes
        // overlap in horizontal reach while their fingers occupy different levels.
        return Material::Empty;
    }
};
