// Schema-4-only architectural geometry samplers, not palette variations.
// All parameters are prepared once. Sampling is constant-time, per-cell,
// deterministic and independent of chunk traversal and mutable World state.
struct ArchitectureForm {
    RectI64 bounds;
    std::int64_t bay, level, wall, door, shaft;
    bool doors, windows;
    Material shell, deck, glazing, accent, spine;
    explicit ArchitectureForm(const ModuleInstance& i) : bounds(i.bounds) {
        module_keys(i, {"bay_width", "floor_height", "wall", "shaft_width", "door_width",
            "automatic_doors", "automatic_windows", "wall_material", "floor_material",
            "partition_material", "accent_material", "window_material", "shaft_material"});
        bay = static_cast<std::int64_t>(module_parameter(i, "bay_width", 64, 16, 256));
        level = static_cast<std::int64_t>(module_parameter(i, "floor_height", 48, 16, 256));
        wall = static_cast<std::int64_t>(module_parameter(i, "wall", 3, 1, 5));
        door = static_cast<std::int64_t>(module_parameter(i, "door_width", 10, 2, 64));
        shaft = static_cast<std::int64_t>(module_parameter(i, "shaft_width", 0, 0, 64));
        doors = module_parameter(i, "automatic_doors", 1, 0, 1) != 0;
        windows = module_parameter(i, "automatic_windows", 1, 0, 1) != 0;
        require(bay > 2 * wall + 2 && level > 2 * wall + 2 &&
                door <= bay - 2 * wall && door <= level - 2 * wall,
            "architectural module needs bay/floor clearance for walls and apertures");
        require(shaft == 0 || shaft >= 4, "architectural shaft must be 0 or at least 4 cells");
        require(bounds.width >= bay && bounds.height >= level && shaft + 2 * wall < bounds.width,
            "architectural module bounds must fit bay, floor, shaft and shell");
        shell = structural_module_material(i, "wall_material", Material::ReinforcedConcrete);
        deck = structural_module_material(i, "floor_material", Material::SteelGrating);
        glazing = structural_module_material(i, "window_material", Material::FrostedGlass);
        accent = structural_module_material(i, "accent_material", Material::CeramicTile);
        spine = structural_module_material(i, "shaft_material", Material::SteelPlate);
        (void)structural_module_material(i, "partition_material", shell);
    }
    bool in_shaft(std::int64_t x) const noexcept {
        return shaft > 0 && x >= bounds.width / 2 - shaft / 2 &&
            x < bounds.width / 2 - shaft / 2 + shaft;
    }
};

// 1. TerracedHabitat: genuinely stepped upper-level setbacks and staggered bays.
class TerracedHabitat final : public FeatureSampler {
    ArchitectureForm p_;
    std::uint64_t seed_;
public:
    TerracedHabitat(const ModuleInstance& i, std::uint64_t seed) : p_(i), seed_(seed) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x = c.x - p_.bounds.x, y = c.y - p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto level = y / p_.level;
        const auto levels = (p_.bounds.height + p_.level - 1) / p_.level;
        const auto step = std::max<std::int64_t>(2, p_.level / 5);
        const auto inset = std::min(p_.bounds.width / 4, (levels - 1 - level) * step);
        if (x < inset || x >= p_.bounds.width - inset) return Material::Empty;
        const auto inner_x = x - inset, fy = y % p_.level;
        const bool outer = inner_x < p_.wall || x >= p_.bounds.width - inset - p_.wall;
        if (fy < p_.wall) return p_.deck;
        const auto offset = static_cast<std::int64_t>(hash_xy(seed_, level, 0, 901) %
            static_cast<std::uint64_t>(std::max<std::int64_t>(1, p_.bay / 3)));
        const bool partition = (inner_x + offset) % p_.bay < p_.wall;
        if (partition && !outer && p_.doors && fy >= p_.level - p_.wall - p_.door &&
            fy < p_.level - p_.wall) return Material::Empty;
        if (outer && p_.windows && fy >= p_.wall + 3 &&
            fy < p_.level - p_.wall - 3) return p_.glazing;
        if (outer || partition) return p_.shell;
        if (inner_x < p_.wall + 2 || x >= p_.bounds.width - inset - p_.wall - 2)
            return p_.accent;
        return Material::Empty;
    }
};

// 2. HexHive: staggered flat-topped six-sided chambers with vertical ports.
class HexHive final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit HexHive(const ModuleInstance& i) : p_(i) {
        require(p_.bay >= 2 * p_.wall + 12 && p_.level >= 2 * p_.wall + 12,
            "hex_hive requires twelve cells of chamber clearance");
    }
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x = c.x - p_.bounds.x, y = c.y - p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        if (x < p_.wall || x >= p_.bounds.width - p_.wall ||
            y < p_.wall || y >= p_.bounds.height - p_.wall) return p_.shell;
        const auto column = x / p_.bay;
        const auto rx = p_.bay / 2 - p_.wall, ry = p_.level / 2 - p_.wall;
        for (auto col = column - 1; col <= column + 1; ++col) {
            const auto cx = col * p_.bay + p_.bay / 2;
            const auto stagger = positive_mod(col, 2) * (p_.level / 2);
            const auto row = floor_div(y - stagger, p_.level);
            const auto cy = row * p_.level + stagger + p_.level / 2;
            const auto dx = std::abs(x - cx), dy = std::abs(y - cy);
            const bool hexagon = dx <= rx && dy <= ry &&
                (dx <= rx / 2 || 2 * dy * rx <= 4 * ry * (rx - dx));
            if (hexagon) return Material::Empty;
            if (p_.doors && dx < p_.door / 2 && dy < p_.level / 2 + p_.wall)
                return Material::Empty;
            if (p_.windows && dx < rx / 2 && dy >= ry && dy <= ry + p_.wall + 1)
                return p_.glazing;
        }
        return x % p_.bay < p_.wall ? p_.accent : p_.shell;
    }
};

// 3. ViaductArcade: curved quadratic soffits, supporting piers and decks.
class ViaductArcade final : public FeatureSampler {
    ArchitectureForm p_;
    std::uint64_t seed_;
public:
    ViaductArcade(const ModuleInstance& i, std::uint64_t seed) : p_(i), seed_(seed) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x = c.x - p_.bounds.x, y = c.y - p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx = x % p_.bay, fy = y % p_.level;
        if (fy < p_.wall) return p_.deck;
        const auto dx = std::abs(bx - p_.bay / 2);
        const auto radius = p_.bay / 2 - p_.wall;
        const auto rise = static_cast<std::int64_t>(
            hash_xy(seed_, x / p_.bay, y / p_.level, 713) % 3U);
        const auto roof = p_.wall + rise +
            (p_.level - p_.wall - rise) * dx * dx / (radius * radius);
        if (dx < radius && fy >= roof) return Material::Empty;
        if (p_.doors && (bx < p_.wall || bx >= p_.bay - p_.wall) &&
            fy >= p_.level - p_.door - p_.wall && fy < p_.level - p_.wall)
            return Material::Empty;
        if (p_.windows && fy > p_.wall + 2 && fy < roof - 2 &&
            dx > radius / 2 && dx < radius) return p_.glazing;
        if (fy == p_.wall && dx < radius) return p_.accent;
        return p_.shell;
    }
};
