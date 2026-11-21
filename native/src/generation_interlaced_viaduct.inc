// GENTEK-SHOWCASE-INTERLACED-001: two systems share one immutable supercell.
// This is a private classic sampler, not a composition or structural solver.
class InterlacedViaduct final : public FeatureSampler {
    ArchitectureForm p_;
    std::uint64_t seed_;
    std::int64_t width_, height_, pier_, radius_, top_, apex_, foot_;

    struct Programme {
        std::int64_t phase, gallery, gap;
        bool left_shared, right_shared;
    };
    Programme programme(std::int64_t column, std::int64_t row) const noexcept {
        const auto h = hash_xy(seed_, column, row, 1817);
        return { (static_cast<std::int64_t>(h % 3U) - 1) * (p_.bay / 8),
            5 * height_ / 6 + static_cast<std::int64_t>((h >> 3U) & 1U) * (height_ / 24),
            ((h >> 6U) & 3U) == 0 ? p_.bay / 5 : 0,
            (h & 16U) != 0, (h & 32U) != 0 };
    }
    std::int64_t primary_curve(std::int64_t distance) const noexcept {
        const auto d = std::min(std::abs(distance), radius_);
        return apex_ + (foot_ - apex_) * d * d / (radius_ * radius_);
    }
    std::int64_t secondary_curve(std::int64_t distance) const noexcept {
        const auto d = std::min(std::abs(distance), radius_);
        return 3 * height_ / 4 - (height_ / 3) * d * d / (radius_ * radius_);
    }
    // Layer selection exists for the native evidence harness only. Production
    // always calls this with both systems; no recipe parameter exposes it.
    Material compose(const ModuleContext& c, unsigned systems) const noexcept {
        const auto x = c.x - p_.bounds.x, y = c.y - p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx = positive_mod(x, width_), fy = positive_mod(y, height_);
        const auto plan = programme(floor_div(x, width_), floor_div(y, height_));
        const auto dx = bx - width_ / 2, sx = dx - plan.phase;
        const auto a = primary_curve(dx), b = secondary_curve(sx);
        const auto mass = 2 * p_.wall;
        const bool primary = (systems & 1U) != 0, secondary = (systems & 2U) != 0;

        // PRIMARY FRAME: monumental deck, continuous boundary piers and a
        // thick normal arch. Dilation in both axes keeps steep ribs connected.
        const bool near_a = fy >= primary_curve(std::max<std::int64_t>(0, std::abs(dx) - mass)) - mass &&
            fy <= primary_curve(std::abs(dx) + mass) + mass;
        const bool at_pier = bx < pier_ || bx >= width_ - pier_;
        const bool pier_portal = p_.doors && std::min(bx, width_ - bx) < p_.door / 2 &&
            fy >= height_ - p_.door - mass && fy < height_ - mass;
        const bool main_deck = std::abs(fy - top_) <= mass;
        const bool spandrel = std::abs(dx) > radius_ - p_.bay / 8 && fy > top_ && fy < a;
        const bool a_solid = !pier_portal && (near_a || at_pier || main_deck || spandrel);
        Material a_material = main_deck ? p_.deck : p_.shell;
        // Glazing is limited to pierhead transfer chambers, never the arch rib.
        if (spandrel && !at_pier && !near_a && fy > top_ + mass + 2 && fy < a - mass - 2 &&
            bx > pier_ + 2 && bx < width_ - pier_ - 2)
            a_material = p_.windows ? p_.glazing : p_.shell;

        // SECONDARY FRAME: opposing sagging rib with its own shifted centre.
        // Its ends deliberately terminate inside the primary boundary piers.
        const bool near_b = fy >= secondary_curve(std::abs(sx) + p_.wall) - p_.wall &&
            fy <= secondary_curve(std::max<std::int64_t>(0, std::abs(sx) - p_.wall)) + p_.wall;
        const auto left = p_.bay / 2 + plan.gap, right = width_ - p_.bay / 2;
        const bool gallery = bx >= left && bx <= right && std::abs(fy - plan.gallery) <= p_.wall;
        const auto hanger_x = bx < width_ / 2 ? p_.bay : 2 * p_.bay;
        const auto hanger_root = secondary_curve(hanger_x - width_ / 2 - plan.phase);
        const bool hanger = std::abs(bx - hanger_x) <= p_.wall &&
            fy >= hanger_root && fy <= plan.gallery;
        const bool b_solid = near_b || gallery || hanger;
        Material b_material = gallery ? p_.deck : p_.accent;

        // INTERLACE: one shared load-transfer hub at each genuine crossing.
        // The programme chooses a reinforced plate or a hollow collar. The
        // collar's four reserved pockets surround the two continuous members;
        // it never fills the lens-shaped void between the opposing arches.
        const auto separation = std::abs(a - b);
        const auto joint_distance = std::abs(fy - a) + std::abs(fy - b);
        const bool shared = dx < 0 ? plan.left_shared : plan.right_shared;
        if (primary && secondary && !at_pier && separation <= 8 * p_.wall + 2) {
            if (shared && joint_distance <= 4 * p_.wall + 2) return p_.spine;
            if (!shared && joint_distance >= 6 * p_.wall && joint_distance <= 8 * p_.wall + 2)
                return p_.spine;
            if (near_a && near_b) return p_.spine;
        }

        // VOID ENVELOPE: no spandrel infill below the two arch members. At a
        // pier termination primary masonry has precedence; elsewhere the rusted
        // secondary remains readable rather than disappearing in a broad slab.
        if (primary && a_solid && (at_pier || main_deck)) return a_material;
        if (secondary && b_solid) return b_material;
        if (primary && a_solid) return a_material;
        return Material::Empty;
    }
public:
    InterlacedViaduct(const ModuleInstance& instance, std::uint64_t seed)
        : p_(instance), seed_(seed), width_(3 * p_.bay), height_(3 * p_.level),
          pier_(2 * p_.wall + p_.door / 2 + 2), radius_(width_ / 2 - pier_),
          top_(height_ / 8), apex_(height_ / 4), foot_(height_ - 2 * p_.wall - 2) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        return compose(c, 3U);
    }
#ifdef CYBERSAND_INTERLACED_DIAGNOSTICS
    Material diagnostic_sample(const ModuleContext& c, unsigned systems) const noexcept {
        return compose(c, systems);
    }
#endif
};
