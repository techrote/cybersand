#include "cybersand/world_generation.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <cmath>
#include <limits>
#include <numeric>
#include <set>
#include <stdexcept>
#include <tuple>
#include <utility>

namespace cybersand::generation {
namespace {
constexpr std::size_t kParameterCount = 12;
constexpr std::size_t kMaxThemes = 64;
using Weights = std::array<double, kMaxThemes>;
constexpr std::uint64_t kFnv = UINT64_C(14695981039346656037);

bool valid_material(Material material) noexcept {
    return cybersand::valid_material(static_cast<std::uint16_t>(material));
}

[[noreturn]] void invalid(const std::string& message) { throw std::invalid_argument(message); }
void require(bool condition, const std::string& message) { if (!condition) invalid(message); }
void identifier(const std::string& s) {
    require(!s.empty() && s.size() <= 96, "IDs must contain 1..96 characters");
    for (const auto c : s) require((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') || c == '_' || c == '-' || c == '.', "invalid ID: " + s);
}
std::uint64_t mix(std::uint64_t v) noexcept {
    v += UINT64_C(0x9e3779b97f4a7c15);
    v = (v ^ (v >> 30U)) * UINT64_C(0xbf58476d1ce4e5b9);
    v = (v ^ (v >> 27U)) * UINT64_C(0x94d049bb133111eb);
    return v ^ (v >> 31U);
}
std::uint64_t hash_xy(std::uint64_t seed, std::int64_t x, std::int64_t y,
                      std::uint64_t lane = 0) noexcept {
    return mix(seed ^ mix(static_cast<std::uint64_t>(x)) ^
        std::rotl(mix(static_cast<std::uint64_t>(y)), 27) ^ mix(lane));
}
double unit(std::uint64_t v) noexcept { return static_cast<double>(v >> 11U) * 0x1.0p-53; }
std::int64_t floor_div(std::int64_t a, std::int64_t b) noexcept {
    const auto q = a / b;
    return q - static_cast<std::int64_t>(a % b < 0);
}
std::int64_t positive_mod(std::int64_t a, std::int64_t b) noexcept {
    auto v = a % b;
    return v < 0 ? v + b : v;
}
double smooth(double t) noexcept { return t * t * (3.0 - 2.0 * t); }
double lerp(double a, double b, double t) noexcept {
    if (t == 0.0) return a;
    if (t == 1.0) return b;
    return a + (b - a) * t;
}
double noise(std::uint64_t seed, double x, double y,
             double scale, std::uint64_t lane) noexcept {
    const auto sx = x / scale, sy = y / scale;
    const auto ix = std::floor(sx), iy = std::floor(sy);
    const auto gx = static_cast<std::int64_t>(ix), gy = static_cast<std::int64_t>(iy);
    const auto tx = smooth(sx - ix), ty = smooth(sy - iy);
    return lerp(lerp(unit(hash_xy(seed, gx, gy, lane)), unit(hash_xy(seed, gx + 1, gy, lane)), tx),
                lerp(unit(hash_xy(seed, gx, gy + 1, lane)), unit(hash_xy(seed, gx + 1, gy + 1, lane)), tx), ty);
}
void hash_word(std::uint64_t& h, std::uint64_t v) noexcept {
    for (unsigned i = 0; i < 8; ++i) { h = (h ^ (v & 255U)) * UINT64_C(1099511628211); v >>= 8U; }
}
void hash_text(std::uint64_t& h, const std::string& v) noexcept {
    hash_word(h, v.size());
    for (const unsigned char c : v) h = (h ^ c) * UINT64_C(1099511628211);
}
void hash_real(std::uint64_t& h, double v) noexcept { hash_word(h, std::bit_cast<std::uint64_t>(v == 0.0 ? 0.0 : v)); }
double& value(Parameters& p, Parameter name) {
    switch (name) {
        case Parameter::SurfaceY: return p.surface_y;
        case Parameter::Relief: return p.relief;
        case Parameter::FeatureScale: return p.feature_scale;
        case Parameter::CaveThreshold: return p.cave_threshold;
        case Parameter::StrataPeriod: return p.strata_period;
        case Parameter::Warp: return p.warp;
        case Parameter::CorridorWidth: return p.corridor_width;
        case Parameter::DistrictSize: return p.district_size;
        case Parameter::RoomSize: return p.room_size;
        case Parameter::WallThickness: return p.wall_thickness;
        case Parameter::Detail: return p.detail;
        case Parameter::FluidLevel: return p.fluid_level;
    }
    invalid("unknown parameter");
}
double value(const Parameters& p, Parameter name) { auto copy = p; return value(copy, name); }
void validate_parameter(Parameter p, double v) {
    require(std::isfinite(v), "parameter must be finite");
    double low = 0.0, high = 1.0;
    switch (p) {
        case Parameter::SurfaceY: case Parameter::FluidLevel: low = -1'000'000.0; high = 1'000'000.0; break;
        case Parameter::Relief: low = 0; high = 4096; break;
        case Parameter::FeatureScale: low = 8; high = 4096; break;
        case Parameter::CaveThreshold: case Parameter::Detail: break;
        case Parameter::StrataPeriod: low = 2; high = 1024; break;
        case Parameter::Warp: low = 0; high = 512; break;
        case Parameter::CorridorWidth: low = 2; high = 64; break;
        case Parameter::DistrictSize: low = 64; high = 2048; break;
        case Parameter::RoomSize: low = 12; high = 256; break;
        case Parameter::WallThickness: low = 1; high = 5; break;
        default: invalid("unknown parameter");
    }
    require(v >= low && v <= high, std::string("parameter out of range: ") + parameter_name(p));
}
void validate_edits(std::vector<ParameterEdit>& edits) {
    require(edits.size() <= kParameterCount, "too many parameter edits");
    std::sort(edits.begin(), edits.end(), [](const auto& a, const auto& b) { return a.parameter < b.parameter; });
    for (std::size_t i = 0; i < edits.size(); ++i) {
        validate_parameter(edits[i].parameter, edits[i].value);
        require(edits[i].parameter != Parameter::DistrictSize, "district_size is global topology; spatial edits are unsupported");
        require(i == 0 || edits[i - 1].parameter != edits[i].parameter, "duplicate parameter edit");
    }
}
void apply_edits(Parameters& p, const std::vector<ParameterEdit>& edits, double alpha = 1.0) {
    for (const auto& e : edits) value(p, e.parameter) = lerp(value(p, e.parameter), e.value, alpha);
}
bool inside(const RectI64& r, std::int64_t x, std::int64_t y) noexcept {
    return x >= r.x && y >= r.y && x < r.x + r.width && y < r.y + r.height;
}
void validate_rect(const RectI64& r) {
    require(r.width > 0 && r.height > 0 && r.width <= kCoordinateLimit && r.height <= kCoordinateLimit,
            "rectangle dimensions are invalid");
    require(r.x >= -kCoordinateLimit && r.y >= -kCoordinateLimit &&
            r.x <= kCoordinateLimit - r.width && r.y <= kCoordinateLimit - r.height,
            "rectangle outside supported coordinate range");
}
void validate_points(const std::vector<Point>& points, const Limits& limits) {
    require(!points.empty() && points.size() <= limits.max_points_per_path, "path point capacity exceeded or empty path");
    for (const auto p : points) require(std::isfinite(p.x) && std::isfinite(p.y) &&
        std::abs(p.x) <= static_cast<double>(kCoordinateLimit) &&
        std::abs(p.y) <= static_cast<double>(kCoordinateLimit), "path point outside supported coordinate range");
}
double segment_distance2(Point p, Point a, Point b) noexcept {
    const auto dx = b.x - a.x, dy = b.y - a.y;
    const auto length2 = dx * dx + dy * dy;
    const auto t = length2 > 0 ? std::clamp(((p.x - a.x) * dx + (p.y - a.y) * dy) / length2, 0.0, 1.0) : 0.0;
    const auto px = p.x - (a.x + t * dx), py = p.y - (a.y + t * dy);
    return px * px + py * py;
}
double path_distance2(Point p, const std::vector<Point>& points) noexcept {
    double result = segment_distance2(p, points.front(), points.front());
    for (std::size_t i = 1; i < points.size(); ++i)
        result = std::min(result, segment_distance2(p, points[i - 1], points[i]));
    return result;
}
double influence(const BrushStroke& brush, std::int64_t x, std::int64_t y) noexcept {
    const auto d2 = path_distance2({static_cast<double>(x), static_cast<double>(y)}, brush.points);
    if (d2 >= brush.radius * brush.radius) return 0;
    return brush.strength * std::pow(smooth(1.0 - std::sqrt(d2) / brush.radius), brush.falloff);
}
template<class T> void order_and_identify(std::vector<T>& values) {
    std::set<std::string> ids;
    for (const auto& v : values) { identifier(v.id); require(ids.insert(v.id).second, "duplicate instance ID: " + v.id); }
    std::sort(values.begin(), values.end(), [](const auto& a, const auto& b) {
        return std::tie(a.priority, a.id) < std::tie(b.priority, b.id);
    });
}
void hash_edits(std::uint64_t& h, const std::vector<ParameterEdit>& edits) {
    hash_word(h, edits.size());
    for (const auto& e : edits) { hash_word(h, static_cast<std::uint64_t>(e.parameter)); hash_real(h, e.value); }
}
void hash_rect(std::uint64_t& h, RectI64 r) {
    hash_word(h, static_cast<std::uint64_t>(r.x)); hash_word(h, static_cast<std::uint64_t>(r.y));
    hash_word(h, static_cast<std::uint64_t>(r.width)); hash_word(h, static_cast<std::uint64_t>(r.height));
}
void hash_points(std::uint64_t& h, const std::vector<Point>& points) {
    hash_word(h, points.size());
    for (const auto p : points) { hash_real(h, p.x); hash_real(h, p.y); }
}
void canonical_selection(ThemeSelection& selection) {
    require(selection.weights.size() <= kMaxThemes && selection.exclude.size() <= kMaxThemes, "theme selection capacity exceeded");
    std::sort(selection.weights.begin(), selection.weights.end(), [](const auto& a, const auto& b) { return a.id < b.id; });
    for (std::size_t i = 0; i < selection.weights.size(); ++i) {
        const auto& w = selection.weights[i]; identifier(w.id);
        require(std::isfinite(w.weight) && w.weight >= 0 && w.weight <= 1'000'000, "invalid theme weight");
        require(i == 0 || selection.weights[i - 1].id != w.id, "duplicate theme weight");
    }
    std::sort(selection.exclude.begin(), selection.exclude.end());
    require(std::adjacent_find(selection.exclude.begin(), selection.exclude.end()) == selection.exclude.end(), "duplicate theme exclusion");
}
void hash_selection(std::uint64_t& h, const ThemeSelection& selection) {
    hash_word(h, selection.weights.size());
    for (const auto& w : selection.weights) { hash_text(h, w.id); hash_real(h, w.weight); }
    hash_word(h, selection.exclude.size()); for (const auto& s : selection.exclude) hash_text(h, s);
}
std::uint64_t payload_hash(const std::vector<Material>& cells) noexcept {
    auto h = kFnv;
    for (const auto m : cells) h = (h ^ static_cast<std::uint8_t>(m)) * UINT64_C(1099511628211);
    return h;
}
std::uint64_t receipt_hash(const ChunkResult& result) noexcept {
    auto h = kFnv;
    hash_word(h, static_cast<std::uint64_t>(result.chunk.x));
    hash_word(h, static_cast<std::uint64_t>(result.chunk.y));
    hash_word(h, static_cast<std::uint64_t>(result.chunk_size));
    hash_word(h, result.revision); hash_word(h, result.fingerprint);
    hash_word(h, result.content_hash); hash_word(h, result.operations);
    hash_text(h, result.diagnostic); hash_word(h, result.diagnostics.size());
    for (const auto v : result.diagnostics) hash_word(h, std::bit_cast<std::uint32_t>(v));
    if (!result.typed_diagnostics.empty()) {
        const auto& info = result.diagnostic_info;
        hash_word(h, static_cast<unsigned>(info.type)); hash_word(h, static_cast<std::uint64_t>(info.unit_power));
        hash_real(h, info.minimum); hash_real(h, info.maximum);
        hash_real(h, info.distance_min_factor); hash_real(h, info.distance_max_factor);
        hash_word(h, info.fingerprint); hash_word(h, info.operations); hash_word(h, info.sampling_scale);
        hash_word(h, result.typed_diagnostics.size());
        for (const auto& v : result.typed_diagnostics) {
            hash_word(h, static_cast<unsigned>(v.type)); hash_real(h, v.x); hash_real(h, v.y);
            hash_word(h, static_cast<std::uint64_t>(v.category.x)); hash_word(h, static_cast<std::uint64_t>(v.category.y));
            hash_word(h, v.category.domain);
        }
    }
    if (!result.stage_cells.empty()) {
        hash_word(h, result.stage_cells.size());
        hash_word(h, payload_hash(result.stage_cells));
    }
    return h;
}
void set_diagnostic(std::string& destination, const char* message) noexcept {
    destination.clear();
    // Capacity is reserved when the job starts. Bounded push_back also avoids
    // GCC 13's string replacement cold path, preserving the Linux ABI floor.
    try {
        for (std::size_t i = 0; i < 255 && message[i] != '\0'; ++i) destination.push_back(message[i]);
    } catch (...) { destination.clear(); }
}

double module_parameter(const ModuleInstance& instance, const std::string& key, double fallback,
                        double minimum, double maximum) {
    auto it = instance.parameters.find(key);
    const auto v = it == instance.parameters.end() ? fallback : it->second;
    require(std::isfinite(v) && v >= minimum && v <= maximum && std::floor(v) == v, "invalid module parameter: " + key);
    return v;
}
void module_keys(const ModuleInstance& instance, const std::set<std::string>& allowed) {
    for (const auto& [key, v] : instance.parameters) { (void)v; require(allowed.contains(key), "unknown module parameter: " + key); }
}

class Arcology final : public FeatureSampler {
    RectI64 bounds_;
    std::int64_t bay_, floor_, wall_, shaft_;
public:
    explicit Arcology(const ModuleInstance& i) : bounds_(i.bounds) {
        module_keys(i, {"bay_width", "floor_height", "wall", "shaft_width"});
        bay_ = static_cast<std::int64_t>(module_parameter(i, "bay_width", 48, 16, 256));
        floor_ = static_cast<std::int64_t>(module_parameter(i, "floor_height", 32, 16, 256));
        wall_ = static_cast<std::int64_t>(module_parameter(i, "wall", 3, 1, 5));
        shaft_ = static_cast<std::int64_t>(module_parameter(i, "shaft_width", 10, 4, 64));
        require(bounds_.width >= 24 && bounds_.height >= 24 && shaft_ + 2 * wall_ < bounds_.width,
                "arcology bounds too small for shaft and shell");
    }
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x = c.x - bounds_.x, y = c.y - bounds_.y;
        const auto mid = bounds_.width / 2;
        const bool shaft = std::abs(x - mid) <= shaft_ / 2;
        if (y < wall_ || y >= bounds_.height - wall_) return shaft ? Material::Empty : Material::SteelPlate;
        if (x < wall_ || x >= bounds_.width - wall_) {
            const auto fy = y % floor_;
            if (fy >= floor_ - 12 && fy < floor_ - wall_) return Material::Empty;
            return fy > 6 && fy < floor_ - 14 ? Material::DarkGlass : Material::ReinforcedConcrete;
        }
        if (shaft) return Material::Empty;
        if (y % floor_ < wall_) return Material::SteelGrating;
        if (x % bay_ < wall_ && y % floor_ < floor_ - 12) return Material::IndustrialBrick;
        if (y % floor_ == wall_ && x % bay_ > bay_ / 2) return Material::NeonCyan;
        if (std::abs(x - mid) == shaft_ / 2 + 1) return Material::CableBundle;
        return Material::Empty;
    }
};

class Vault final : public FeatureSampler {
    RectI64 bounds_;
    std::int64_t pitch_, wall_, door_, nx_, ny_;
    std::vector<std::uint8_t> exits_;
public:
    Vault(const ModuleInstance& i, std::uint64_t seed) : bounds_(i.bounds) {
        module_keys(i, {"cell_size", "wall", "door_width"});
        pitch_ = static_cast<std::int64_t>(module_parameter(i, "cell_size", 32, 12, 128));
        wall_ = static_cast<std::int64_t>(module_parameter(i, "wall", 2, 1, 4));
        door_ = static_cast<std::int64_t>(module_parameter(i, "door_width", 8, 2, static_cast<double>(pitch_ - 2 * wall_)));
        require(bounds_.width % pitch_ == 0 && bounds_.height % pitch_ == 0, "vault bounds must divide cell_size");
        nx_ = bounds_.width / pitch_; ny_ = bounds_.height / pitch_;
        require(nx_ > 0 && ny_ > 0 && nx_ <= 64 && ny_ <= 64, "vault preparation exceeds 4096 rooms / 64 per axis");
        const auto count = static_cast<std::size_t>(nx_ * ny_);
        exits_.resize(count, 0);
        std::vector<bool> visited(count, false);
        std::vector<std::size_t> stack; stack.reserve(count);
        stack.push_back(0); visited[0] = true;
        constexpr std::array<std::int64_t, 4> dx{1, 0, -1, 0}, dy{0, 1, 0, -1};
        while (!stack.empty()) {
            const auto index = stack.back();
            const auto x = static_cast<std::int64_t>(index) % nx_, y = static_cast<std::int64_t>(index) / nx_;
            std::size_t next = count; unsigned direction = 0; std::uint64_t best = UINT64_MAX;
            for (unsigned d = 0; d < 4; ++d) {
                const auto xx = x + dx[d], yy = y + dy[d];
                if (xx < 0 || yy < 0 || xx >= nx_ || yy >= ny_) continue;
                const auto n = static_cast<std::size_t>(yy * nx_ + xx);
                const auto rank = hash_xy(seed, bounds_.x + x, bounds_.y + y, d + 700U);
                if (!visited[n] && (next == count || rank < best)) { next = n; best = rank; direction = d; }
            }
            if (next == count) { stack.pop_back(); continue; }
            exits_[index] |= static_cast<std::uint8_t>(1U << direction);
            exits_[next] |= static_cast<std::uint8_t>(1U << ((direction + 2U) % 4U));
            visited[next] = true; stack.push_back(next);
        }
        exits_[static_cast<std::size_t>((ny_ / 2) * nx_)] |= 4U;
        exits_[static_cast<std::size_t>((ny_ / 2) * nx_ + nx_ - 1)] |= 1U;
    }
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x = c.x - bounds_.x, y = c.y - bounds_.y;
        const auto lx = x % pitch_, ly = y % pitch_;
        const auto exits = exits_[static_cast<std::size_t>((y / pitch_) * nx_ + x / pitch_)];
        const bool horizontal_door = std::abs(ly - pitch_ / 2) < door_ / 2;
        const bool vertical_door = std::abs(lx - pitch_ / 2) < door_ / 2;
        if ((lx < wall_ && horizontal_door && (exits & 4U)) ||
            (lx >= pitch_ - wall_ && horizontal_door && (exits & 1U)) ||
            (ly < wall_ && vertical_door && (exits & 8U)) ||
            (ly >= pitch_ - wall_ && vertical_door && (exits & 2U))) return Material::Empty;
        if (lx < wall_ || ly < wall_ || lx >= pitch_ - wall_ || ly >= pitch_ - wall_) return c.palette.rock;
        if (lx == wall_ && ly == wall_) return c.palette.accent;
        return Material::Empty;
    }
};

class Aqueduct final : public FeatureSampler {
    RectI64 bounds_;
    std::int64_t span_, deck_, wall_, depth_;
public:
    explicit Aqueduct(const ModuleInstance& i) : bounds_(i.bounds) {
        module_keys(i, {"span", "deck_height", "wall", "channel_depth"});
        span_ = static_cast<std::int64_t>(module_parameter(i, "span", 64, 24, 256));
        deck_ = static_cast<std::int64_t>(module_parameter(i, "deck_height", 24, 8, 256));
        wall_ = static_cast<std::int64_t>(module_parameter(i, "wall", 3, 1, 6));
        depth_ = static_cast<std::int64_t>(module_parameter(i, "channel_depth", 6, 1, 32));
        require(depth_ < deck_ && deck_ + wall_ + 8 < bounds_.height, "aqueduct bounds too shallow for channel and arches");
    }
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x = c.x - bounds_.x, y = c.y - bounds_.y;
        if (y >= deck_ && y < deck_ + wall_) return Material::LimestoneBlock;
        if (y >= deck_ - depth_ && y < deck_) return c.palette.fluid;
        if (y < deck_) return Material::Empty;
        const auto height = static_cast<double>(bounds_.height - deck_ - wall_);
        const auto u = (static_cast<double>(x % span_) - static_cast<double>(span_) / 2.0) /
            (static_cast<double>(span_) / 2.0 - static_cast<double>(wall_));
        const auto v = static_cast<double>(bounds_.height - 1 - y) / height;
        if (u * u + v * v < 1.0) return Material::Empty;
        return Material::LimestoneBlock;
    }
};
} // namespace

struct Generator::Impl {
    Recipe recipe;
    std::vector<Theme> leaves;
    std::vector<Parameters> leaf_parameters;
    std::map<std::string, std::vector<std::size_t>> descendants;
    Weights base_weights{};
    std::vector<Weights> brush_weights;
    std::array<bool, kMaxThemes> excluded{};
    struct Prepared {
        ModuleInstance instance;
        std::shared_ptr<const FeatureSampler> sampler;
        std::uint32_t cost{};
    };
    std::vector<Prepared> modules;
    std::shared_ptr<const FieldGraph> fields;
    std::shared_ptr<const SpatialGraph> spatial;
    std::shared_ptr<const GrammarPlan> grammar;
    RouteValidation route_validation;
    struct Values {
        std::array<double, kMaxFieldNodes + kMaxSpatialNodes> values{};
        SpatialValues typed;
    };
    std::size_t mask_index(const std::string& name) const {
        if (!name.starts_with("spatial:")) return fields->index(name);
        const auto index = spatial->index(name.substr(8));
        require(spatial->info(index).type == SpatialType::Normalized,
            "material masks require normalized spatial output; add explicit to_mask: " + name);
        return kMaxFieldNodes + index;
    }
    void evaluate_fields(std::int64_t x, std::int64_t y, const FieldContext& context,
                         Values& values, SpatialScratch* scratch = nullptr) const {
        FieldValues legacy;
        fields->evaluate(x, y, context, legacy);
        std::copy_n(legacy.values.begin(), legacy.size, values.values.begin());
        spatial->evaluate(x, y, values.typed, scratch);
        for (std::size_t i = 0; i < values.typed.size; ++i)
            if (values.typed.values[i].type == SpatialType::Normalized)
                values.values[kMaxFieldNodes + i] = values.typed.values[i].x;
    }
    static constexpr auto absent = std::numeric_limits<std::size_t>::max();
    struct Mask {
        std::size_t application = absent, exclusion = absent;
        double strength = 1.0;
        double at(const Values& values) const noexcept {
            return strength * (application == absent ? 1.0 : values.values[application]) *
                (exclusion == absent ? 1.0 : 1.0 - values.values[exclusion]);
        }
    };
    struct PreparedModifier {
        Mask mask;
        Weights themes{};
        std::vector<std::size_t> mappings;
        std::size_t aggregate = absent;
        std::uint64_t salt = 0;
    };
    std::vector<PreparedModifier> modifiers;
    std::vector<Mask> semantic_masks;
    std::vector<std::size_t> semantic_aggregates;
    std::vector<Mask> module_masks;
    std::vector<std::uint64_t> module_salts;
    std::vector<std::size_t> aggregate_variations;
    std::vector<std::uint64_t> aggregate_salts;
    std::vector<std::vector<double>> aggregate_weights;
    std::uint64_t fingerprint = kFnv;
    std::uint64_t cost = 128;

    void check_routes();

    Mask compile_mask(const std::string& application, const std::string& exclusion, double strength) const {
        require(std::isfinite(strength) && strength >= 0 && strength <= 1, "mask strength must be 0..1");
        return {application.empty() ? absent : mask_index(application),
            exclusion.empty() ? absent : mask_index(exclusion), strength};
    }

    std::pair<unsigned, std::size_t> diagnostic(const std::string& name) const {
        if (name.empty()) return {0, 0};
        if (name.starts_with("stage:")) {
            const auto stage = parse_generation_stage(name.substr(6));
            require(stage.has_value(), "unknown generation stage: " + name);
            return {5, static_cast<std::size_t>(*stage)};
        }
        if (name.starts_with("spatial:")) return {4, spatial->index(name.substr(8))};
        if (name.starts_with("field:")) return {1, fields->index(name.substr(6))};
        if (name.starts_with("modifier:")) {
            for (std::size_t i = 0; i < recipe.modifiers.size(); ++i)
                if (recipe.modifiers[i].id == name.substr(9)) return {2, i};
        }
        if (name.starts_with("module:")) {
            for (std::size_t i = 0; i < modules.size(); ++i)
                if (modules[i].instance.id == name.substr(7)) return {3, i};
        }
        invalid("unknown generation diagnostic: " + name);
    }

    Weights resolve(const ThemeSelection& selection) const {
        Weights result{}; auto banned = excluded;
        for (const auto& name : selection.exclude) {
            auto it = descendants.find(name); require(it != descendants.end(), "unknown excluded theme: " + name);
            for (const auto index : it->second) banned[index] = true;
        }
        for (const auto& w : selection.weights) {
            const auto it = descendants.find(w.id); require(it != descendants.end(), "unknown theme: " + w.id);
            const auto count = std::count_if(it->second.begin(), it->second.end(), [&](auto i) { return !banned[i]; });
            if (count == 0) continue;
            for (const auto index : it->second) if (!banned[index]) result[index] += w.weight / static_cast<double>(count);
        }
        const auto sum = std::accumulate(result.begin(), result.end(), 0.0);
        require(sum > 0 && std::isfinite(sum), "theme selection has no eligible positive weight");
        for (auto& weight : result) weight /= sum;
        return result;
    }

    Weights weights(std::int64_t x, std::int64_t y) const {
        auto result = base_weights;
        for (std::size_t b = 0; b < recipe.strokes.size(); ++b) {
            const auto& brush = recipe.strokes[b];
            if (brush.themes.weights.empty()) continue;
            const auto alpha = influence(brush, x, y);
            if (alpha == 0) continue;
            for (std::size_t i = 0; i < leaves.size(); ++i) result[i] = lerp(result[i], brush_weights[b][i], alpha);
        }
        return result;
    }

    bool network(std::int64_t x, std::int64_t y, double width) const noexcept {
        // Macro topology is fixed for the recipe. Both sides of each macro edge
        // derive exactly the same port from the edge's canonical coordinates.
        const auto span = static_cast<std::int64_t>(recipe.parameters.district_size);
        const auto mx = floor_div(x, span), my = floor_div(y, span);
        const auto ox = mx * span, oy = my * span;
        const auto offset = [&](std::int64_t a, std::int64_t b, std::uint64_t lane) {
            return span / 4 + static_cast<std::int64_t>(hash_xy(recipe.seed, a, b, lane) % static_cast<std::uint64_t>(span / 2));
        };
        const Point p{static_cast<double>(x - ox), static_cast<double>(y - oy)};
        const Point centre{static_cast<double>(offset(mx, my, 100)), static_cast<double>(offset(mx, my, 101))};
        const std::array<Point, 4> ports{{
            {0, static_cast<double>(offset(mx, my, 102))},
            {static_cast<double>(span), static_cast<double>(offset(mx + 1, my, 102))},
            {static_cast<double>(offset(mx, my, 103)), 0},
            {static_cast<double>(offset(mx, my + 1, 103)), static_cast<double>(span)}
        }};
        for (const auto port : ports) if (segment_distance2(p, centre, port) <= width * width / 4.0) return true;
        return false;
    }

    Material strata(std::int64_t x, std::int64_t y, const Parameters& p, const Palette& palette) const noexcept {
        const auto scale = p.feature_scale;
        const auto dx = static_cast<double>(x), dy = static_cast<double>(y);
        const auto wx = dx + (noise(recipe.seed, dx, dy, scale * 2, 30) - 0.5) * p.warp;
        const auto wy = dy + (noise(recipe.seed, dx, dy, scale * 2, 31) - 0.5) * p.warp;
        const auto surface = p.surface_y + (noise(recipe.seed, dx, 0, scale * 2, 1) - 0.5) * p.relief * 2.0;
        if (static_cast<double>(y) < surface) return Material::Empty;
        const auto depth = static_cast<double>(y) - surface;
        const auto cave = noise(recipe.seed, wx, wy, scale, 2) * 0.75 +
            noise(recipe.seed, wx, wy, std::max(4.0, scale / 3), 3) * 0.25;
        if (depth > 8.0 && cave > p.cave_threshold) {
            return static_cast<double>(y) > p.fluid_level && cave > p.cave_threshold + 0.08 ? palette.fluid : Material::Empty;
        }
        if (depth < 5.0) return palette.surface;
        const auto layer = wy - std::floor(wy / p.strata_period) * p.strata_period;
        if (layer < 2 && noise(recipe.seed, wx, wy, std::max(4.0, scale / 2), 4) < p.detail) return palette.accent;
        return palette.rock;
    }

    Material district(std::int64_t x, std::int64_t y, const Parameters& p, const Palette& palette) const noexcept {
        const auto pitch = static_cast<std::int64_t>(p.room_size);
        const auto wall = static_cast<std::int64_t>(p.wall_thickness);
        const auto lx = positive_mod(x, pitch), ly = positive_mod(y, pitch);
        const auto door_half = std::max<std::int64_t>(2, pitch / 8);
        const bool vx = lx < wall || lx >= pitch - wall;
        const bool hy = ly < wall || ly >= pitch - wall;
        if (vx && std::abs(ly - pitch / 2) >= door_half) return palette.rock;
        if (hy && std::abs(lx - pitch / 2) >= door_half) return palette.surface;
        if ((lx == wall || ly == wall) && unit(hash_xy(recipe.seed, floor_div(x, pitch), floor_div(y, pitch), 60)) < p.detail)
            return palette.accent;
        return Material::Empty;
    }

    Parameters parameters_at(const Weights& w, std::int64_t x, std::int64_t y) const {
        auto p = recipe.parameters;
        const auto first = static_cast<std::size_t>(std::find_if(w.begin(), w.end(), [](double v) { return v > 0; }) - w.begin());
        for (std::size_t parameter = 0; parameter < kParameterCount; ++parameter) {
            const auto key = static_cast<Parameter>(parameter);
            const auto reference = value(leaf_parameters[first], key);
            double delta = 0, low = reference, high = reference;
            for (std::size_t i = 0; i < leaves.size(); ++i) if (w[i] > 0) {
                const auto v = value(leaf_parameters[i], key);
                delta += w[i] * (v - reference); low = std::min(low, v); high = std::max(high, v);
            }
            // Shared defaults remain bit-exact, including integer lower bounds.
            value(p, key) = std::clamp(reference + delta, low, high);
        }
        for (const auto& brush : recipe.strokes) apply_edits(p, brush.parameters, influence(brush, x, y));
        return p;
    }

    Candidate hard_parameters(Parameters& p, std::int64_t x, std::int64_t y) const {
        auto candidate = recipe.candidate;
        for (const auto& hard : recipe.overrides) if (inside(hard.bounds, x, y)) {
            apply_edits(p, hard.parameters);
            if (hard.candidate) candidate = *hard.candidate;
        }
        return candidate;
    }

    const Palette& palette_at(const Weights& w, std::int64_t x, std::int64_t y) const noexcept {
        // A uniform hash per warped patch gives coherent discrete palettes,
        // without misinterpreting value noise's centre-heavy distribution as a
        // uniform probability. Weights are regional preferences, not quotas.
        const auto palette_scale = std::max(8.0, recipe.parameters.feature_scale / 2);
        const auto dx = static_cast<double>(x), dy = static_cast<double>(y);
        const auto px = dx + (noise(recipe.seed, dx, dy, palette_scale * 2, 52) - 0.5) * palette_scale;
        const auto py = dy + (noise(recipe.seed, dx, dy, palette_scale * 2, 53) - 0.5) * palette_scale;
        auto selector = unit(hash_xy(recipe.seed, static_cast<std::int64_t>(std::floor(px / palette_scale)),
            static_cast<std::int64_t>(std::floor(py / palette_scale)), 55));
        std::size_t selected = 0;
        for (std::size_t i = 0; i < leaves.size(); ++i) if (w[i] > 0) {
            selected = i; selector -= w[i]; if (selector < 0) break;
        }
        return leaves[selected].palette;
    }

    double surface_at(double x, const Parameters& p) const noexcept {
        return p.surface_y + (noise(recipe.seed, x, 0, p.feature_scale * 2, 1) - 0.5) * p.relief * 2.0;
    }

    FieldContext field_context(std::int64_t x, std::int64_t y, const Parameters& p,
                               Candidate candidate, Material material) const {
        const auto state = material_definition(material).state;
        const auto dx = static_cast<double>(x);
        const auto surface = surface_at(dx, p);
        const auto neighbor_surface = [&](std::int64_t nx) {
            auto neighbor = parameters_at(weights(nx, y), nx, y);
            (void)hard_parameters(neighbor, nx, y);
            return surface_at(static_cast<double>(nx), neighbor);
        };
        const auto left = x == -kCoordinateLimit ? surface : neighbor_surface(x - 1);
        const auto right = x == kCoordinateLimit - 1 ? surface : neighbor_surface(x + 1);
        const auto spacing = x == -kCoordinateLimit || x == kCoordinateLimit - 1 ? 1.0 : 2.0;
        return {material == Material::Empty ? 0.0 : 1.0,
            state == MaterialState::Solid ? 1.0 : 0.0,
            state == MaterialState::Liquid ? 1.0 : 0.0,
            static_cast<double>(y) - surface,
            std::abs(right - left) / spacing,
            candidate != Candidate::Strata && network(x, y, p.corridor_width) ? 1.0 : 0.0,
            static_cast<std::uint16_t>(material)};
    }

    static bool matches(const Modifier& m, const FieldContext& c) noexcept {
        switch (m.context) {
            case ContextPredicate::Any: return true;
            case ContextPredicate::Empty: return c.occupied == 0;
            case ContextPredicate::Occupied: return c.occupied != 0;
            case ContextPredicate::Solid: return c.solid != 0;
            case ContextPredicate::Fluid: return c.fluid != 0;
            case ContextPredicate::Material: return c.material == static_cast<std::uint16_t>(*m.context_material);
        }
        return false;
    }

    static double shape(const Modifier& m, std::int64_t x, std::int64_t y) noexcept {
        if (m.bounds && !inside(*m.bounds, x, y)) return 0;
        if (m.points.empty()) return 1;
        const auto distance = std::sqrt(path_distance2({static_cast<double>(x), static_cast<double>(y)}, m.points));
        if (distance >= m.radius) return 0;
        return std::pow(smooth(1.0 - distance / m.radius), m.falloff);
    }

    Material aggregate_at(std::size_t index, std::int64_t x, std::int64_t y, const Values& values) const noexcept {
        const auto& a = recipe.aggregates[index];
        auto selector = aggregate_variations[index] == absent ?
            unit(hash_xy(recipe.seed ^ aggregate_salts[index], floor_div(x, a.grain_size), floor_div(y, a.grain_size), 880)) :
            values.values[aggregate_variations[index]];
        Material selected = a.components.back().material;
        for (std::size_t i = 0; i < a.components.size(); ++i) {
            selected = a.components[i].material; selector -= aggregate_weights[index][i];
            if (selector < 0) break;
        }
        return selected;
    }

    Material sample(std::int64_t x, std::int64_t y, unsigned diagnostic_kind = 0,
                    std::size_t diagnostic_index = 0, float* diagnostic_value = nullptr,
                    SpatialValue* typed_value = nullptr, SpatialScratch* scratch = nullptr,
                    CellProvenance* trace = nullptr, GenerationStages* stages = nullptr) const {
        auto w = weights(x, y);
        auto p = parameters_at(w, x, y);
        auto candidate = hard_parameters(p, x, y);
        const auto* palette = &palette_at(w, x, y);
        Material result = candidate == Candidate::DistrictGrammar ? district(x, y, p, *palette) : strata(x, y, p, *palette);
        const auto room = [&](std::size_t count) {
            if (count < kMaxTraceEntries) return true;
            trace->truncated = true; ++trace->omitted_entries; return false;
        };
        const auto decision = [&](EvaluationDecision value) {
            if (trace && room(trace->decisions.size())) trace->decisions.push_back(std::move(value));
        };
        const auto record = [&](const char* stage, const std::string& id, Material next, double influence = 1.0) {
            if (trace && room(trace->contributions.size())) trace->contributions.push_back({stage, id, result, next, influence});
            result = next;
        };
        const auto snapshot = [&](GenerationStage stage) {
            if (stages) stages->materials[static_cast<std::size_t>(stage)] = result;
            if (trace) trace->stages.materials[static_cast<std::size_t>(stage)] = result;
        };
        if (trace) {
            trace->initial_material = result; trace->initial_candidate = candidate;
            trace->initial_parameters = p;
            trace->contributions.push_back({"candidate", candidate_name(candidate), Material::Empty, result, 1});
        }
        snapshot(GenerationStage::Candidate);
        if (trace) {
            // Append to fresh trace strings: GCC 13 can lower C-string assignment
            // to the newer libstdc++ overlap helper, above our Linux ABI floor.
            for (const auto& brush : recipe.strokes) {
                EvaluationDecision entry; entry.stage.append("brush_guidance"); entry.id = brush.id;
                entry.influence = influence(brush, x, y); entry.accepted = entry.influence > 0;
                entry.strength = brush.strength; entry.detail.append(entry.accepted ?
                    "initial theme/parameter guidance in canonical priority order" : "outside bounded brush influence");
                decision(std::move(entry));
            }
            for (const auto& hard : recipe.overrides) if (inside(hard.bounds, x, y)) {
                EvaluationDecision entry; entry.stage.append("hard_parameter_precedence"); entry.id = hard.id; entry.accepted = true;
                entry.detail.append("candidate/parameters take precedence before initial and guided candidates; material override is last");
                decision(std::move(entry));
            }
        }
        Values values;
        const auto aggregate = [&](std::size_t index, const std::string& source) {
            const auto selected = aggregate_at(index, x, y, values);
            if (trace && room(trace->aggregates.size())) {
                const auto& authored = recipe.aggregates[index];
                AggregateSelection receipt;
                receipt.id = authored.id; receipt.source = source; receipt.material = selected;
                receipt.selector = aggregate_variations[index] == absent ?
                    unit(hash_xy(recipe.seed ^ aggregate_salts[index], floor_div(x, authored.grain_size), floor_div(y, authored.grain_size), 880)) :
                    values.values[aggregate_variations[index]];
                for (std::size_t c = 0; c < authored.components.size(); ++c)
                    receipt.components.push_back({authored.components[c].material, aggregate_weights[index][c]});
                trace->aggregates.push_back(std::move(receipt));
            }
            return selected;
        };
        std::array<double, 64> alpha{};
        bool changed_themes = false, changed_parameters = false;
        // One immutable analytic terrain proposal defines all context. No module,
        // earlier modifier, neighbor chunk or final override feeds this snapshot.
        if (!recipe.fields.empty() || !recipe.spatial.empty() || !recipe.modifiers.empty()) {
            const auto base_context = field_context(x, y, p, candidate, result);
            if (trace) { trace->context = base_context; trace->context_evaluated = true; }
            evaluate_fields(x, y, base_context, values, scratch);
            for (std::size_t i = 0; i < recipe.modifiers.size(); ++i) {
                const auto& m = recipe.modifiers[i];
                const bool context_passed = matches(m, base_context);
                const auto footprint = shape(m, x, y);
                alpha[i] = context_passed ? modifiers[i].mask.at(values) * footprint : 0;
                if (trace) {
                    const auto& mask = modifiers[i].mask;
                    EvaluationDecision entry;
                    entry.stage.append("modifier_mask"); entry.id = m.id;
                    entry.application = m.application; entry.exclusion = m.exclusion;
                    entry.application_value = mask.application == absent ? 1 : values.values[mask.application];
                    entry.exclusion_value = mask.exclusion == absent ? 0 : values.values[mask.exclusion];
                    entry.strength = mask.strength; entry.shape = footprint;
                    entry.predicate.append(context_predicate_name(m.context)); entry.context_passed = context_passed;
                    entry.influence = alpha[i]; entry.accepted = alpha[i] > 0;
                    entry.detail.append(!context_passed ? "initial candidate context rejected" : footprint == 0 ?
                        "outside modifier footprint" : alpha[i] == 0 ? "application/exclusion mask rejected" : "guidance influence evaluated");
                    decision(std::move(entry));
                }
                if (alpha[i] == 0) continue;
                if (!m.themes.weights.empty()) {
                    for (std::size_t leaf = 0; leaf < leaves.size(); ++leaf)
                        w[leaf] = lerp(w[leaf], modifiers[i].themes[leaf], alpha[i]);
                    changed_themes = true;
                }
                changed_parameters = changed_parameters || !m.parameters.empty() || !m.mappings.empty();
            }
            if (changed_themes) p = parameters_at(w, x, y);
            if (changed_parameters || changed_themes) {
                for (std::size_t i = 0; i < recipe.modifiers.size(); ++i) {
                    if (alpha[i] == 0) continue;
                    const auto& m = recipe.modifiers[i];
                    apply_edits(p, m.parameters, alpha[i]);
                    for (std::size_t j = 0; j < m.mappings.size(); ++j) {
                        const auto& mapping = m.mappings[j];
                        const auto target = lerp(mapping.low, mapping.high, values.values[modifiers[i].mappings[j]]);
                        value(p, mapping.parameter) = lerp(value(p, mapping.parameter), target, alpha[i]);
                    }
                }
                candidate = hard_parameters(p, x, y);
                palette = &palette_at(w, x, y);
                record("guided_candidate", candidate_name(candidate),
                    candidate == Candidate::DistrictGrammar ? district(x, y, p, *palette) : strata(x, y, p, *palette));
            }
        }
        snapshot(GenerationStage::GuidedCandidate);
        if (trace) {
            trace->effective_candidate = candidate; trace->effective_parameters = p;
            for (std::size_t i = 0; i < recipe.fields.size(); ++i)
                trace->scalar_fields.emplace_back(recipe.fields[i].id, values.values[i]);
            for (std::size_t i = 0; i < spatial->nodes().size(); ++i)
                trace->typed_fields.emplace_back(spatial->nodes()[i].id, values.typed.values[i]);
        }
        if (grammar) {
            struct SemanticMaskContext {
                const Impl* generator;
                const Values* values;
                std::int64_t x, y;
                CellProvenance* trace;
            };
            const SemanticMaskContext mask_context{this, &values, x, y, trace};
            const auto proposal = grammar->proposal(x, y,
                [](std::size_t index, const SemanticFeature& feature, const void* context_ptr) {
                    const auto& context = *static_cast<const SemanticMaskContext*>(context_ptr);
                    const auto& compiled = context.generator->semantic_masks[index];
                    const auto mask = compiled.at(*context.values);
                    const auto draw = unit(hash_xy(feature.seed, context.x, context.y, 883));
                    const auto accepted = mask > 0 && (mask == 1 || draw < mask);
                    if (context.trace) {
                        if (context.trace->decisions.size() < kMaxTraceEntries) {
                            EvaluationDecision entry;
                            entry.stage.append("semantic_mask"); entry.id = feature.id;
                            entry.application = feature.application; entry.exclusion = feature.exclusion;
                            entry.application_value = compiled.application == absent ? 1 : context.values->values[compiled.application];
                            entry.exclusion_value = compiled.exclusion == absent ? 0 : context.values->values[compiled.exclusion];
                            entry.influence = mask; entry.draw = draw; entry.draw_used = mask > 0 && mask < 1;
                            entry.accepted = accepted; entry.detail.append(accepted ? "eligible structural alternative; later precedence may replace" : "semantic mask/deterministic draw rejected");
                            context.trace->decisions.push_back(std::move(entry));
                        } else { context.trace->truncated = true; ++context.trace->omitted_entries; }
                    }
                    return accepted;
                }, &mask_context);
            if (trace) {
                // The producing ancestry is the accepted proposal, not a deeper
                // geometric scope that may have been excluded by its masks.
                if (proposal.feature) {
                    trace->accepted_feature_id = proposal.feature->id;
                    trace->ancestry = grammar->ancestry(proposal.feature->id);
                }
                // Recorded compile-time decisions include rejected alternatives in
                // the same canonical region, marked as such in the adapter.
                const auto region = spatial::RegionId{floor_div(x, grammar->definition().region_size), floor_div(y, grammar->definition().region_size)};
                std::string region_id;
                for (const auto& feature : grammar->features()) if (feature.kind == SemanticKind::Region && feature.owner == region) { region_id = feature.id; break; }
                for (const auto& receipt : grammar->receipts())
                    if ((!region_id.empty() && receipt.feature_id.starts_with(region_id + "/")) ||
                        std::find(trace->ancestry.begin(), trace->ancestry.end(), receipt.feature_id) != trace->ancestry.end()) {
                        if (room(trace->constraints.size())) trace->constraints.push_back(receipt);
                    }
            }
            if (proposal.feature) {
                const auto index = static_cast<std::size_t>(proposal.feature - grammar->features().data());
                const auto mask = semantic_masks[index].at(values);
                if (!proposal.interior && semantic_aggregates[index] != absent)
                    record("semantic_aggregate", proposal.feature->id,
                        aggregate(semantic_aggregates[index], proposal.feature->id), mask);
                else if (proposal.material) record("semantic_feature", proposal.feature->id, *proposal.material, mask);
            } else if (proposal.material) {
                record("semantic_structure", proposal.route ? proposal.route->id : "grammar", *proposal.material);
            }
        }
        snapshot(GenerationStage::Grammar);
        if (typed_value) *typed_value = values.typed.values[diagnostic_index];
        if (diagnostic_value) {
            *diagnostic_value = diagnostic_kind == 1 ? static_cast<float>(values.values[diagnostic_index]) :
                diagnostic_kind == 2 ? static_cast<float>(alpha[diagnostic_index]) : 0.0F;
        }
        const ModuleContext context{x, y, recipe.seed, p, *palette};
        for (std::size_t i = 0; i < modules.size(); ++i) {
            const auto& module = modules[i];
            const auto mask = inside(module.instance.bounds, x, y) ? module_masks[i].at(values) : 0;
            if (diagnostic_value && diagnostic_kind == 3 && diagnostic_index == i) *diagnostic_value = static_cast<float>(mask);
            const auto draw = unit(hash_xy(recipe.seed ^ module_salts[i], x, y, 881));
            const bool eligible = mask > 0 && (mask == 1 || draw < mask);
            if (trace) {
                EvaluationDecision entry;
                const auto& compiled = module_masks[i];
                entry.stage.append("module_mask"); entry.id = module.instance.id;
                entry.application = module.instance.application; entry.exclusion = module.instance.exclusion;
                entry.application_value = compiled.application == absent ? 1 : values.values[compiled.application];
                entry.exclusion_value = compiled.exclusion == absent ? 0 : values.values[compiled.exclusion];
                entry.strength = compiled.strength; entry.shape = inside(module.instance.bounds, x, y) ? 1 : 0;
                entry.influence = mask; entry.draw = draw; entry.draw_used = mask > 0 && mask < 1; entry.accepted = eligible;
                entry.detail.append(eligible ? "prepared native module invoked" : "module bounds/mask/draw rejected");
                decision(std::move(entry));
            }
            if (eligible) {
                const auto changed = module.sampler->sample(context, result);
                if (changed) {
                    if (!valid_material(*changed)) throw std::runtime_error("module returned invalid material: " + module.instance.id);
                    record("module", module.instance.id, *changed, mask);
                }
            }
        }
        for (std::size_t i = 0; i < recipe.modifiers.size(); ++i) {
            const auto& m = recipe.modifiers[i];
            if (!m.material && m.aggregate.empty()) continue;
            const auto draw = unit(hash_xy(recipe.seed ^ modifiers[i].salt, x, y, 882));
            const bool accepted = alpha[i] > 0 && (alpha[i] == 1 || draw < alpha[i]);
            if (trace) {
                EvaluationDecision entry; entry.stage.append("modifier_material"); entry.id = m.id;
                entry.influence = alpha[i]; entry.draw = draw; entry.draw_used = alpha[i] > 0 && alpha[i] < 1;
                entry.accepted = accepted; entry.detail.append(accepted ? "ordered material replacement" : "mask/deterministic draw rejected");
                decision(std::move(entry));
            }
            if (!accepted) continue;
            record("modifier", m.id, m.material ? *m.material : aggregate(modifiers[i].aggregate, m.id), alpha[i]);
        }
        snapshot(GenerationStage::Modifiers);
        // Network/paths reserve connective space after structural modules. A hard
        // authored override below is the explicit way to block that connection.
        if (candidate != Candidate::Strata && network(x, y, p.corridor_width)) record("candidate_route", "macro-network", Material::Empty);
        for (const auto& path : recipe.paths)
            if (path_distance2({static_cast<double>(x), static_cast<double>(y)}, path.points) <= path.width * path.width / 4.0)
                record("guide_path", path.id, path.material);
        if (grammar) if (const auto* route = grammar->route_at(x, y)) record("semantic_route", route->id, route->material);
        snapshot(GenerationStage::Connectivity);
        for (const auto& hard : recipe.overrides) if (hard.material && inside(hard.bounds, x, y)) record("hard_override", hard.id, *hard.material);
        snapshot(GenerationStage::Final);
        if (trace) trace->material = result;
        return result;
    }
};

// Full finite-plan verification uses the same final sampler as chunk jobs.
// All scratch and work are preflighted before sampling or publishing a plan.
void Generator::Impl::check_routes() {
    const auto bounds = grammar->bounds();
    const auto& limits = grammar->definition().limits;
    const auto width = static_cast<std::size_t>(bounds.width);
    const auto height = static_cast<std::size_t>(bounds.height);
    require(width > 0 && height > 0 && width <= limits.max_raster_cells / height,
        "semantic final-raster cell budget exhausted");
    const auto area = width * height;
    const auto prefix_area = (width + 1) * (height + 1);
    auto bytes = area * (sizeof(Material) + sizeof(std::uint8_t) + sizeof(std::uint32_t)) +
        prefix_area * sizeof(std::uint32_t);
    // Retained inspection outcomes coexist with raster scratch while checked.
    // Include IDs and the bounded override names in their string allowance.
    for (const auto& route : grammar->routes()) if (route.required)
        bytes += sizeof(RouteOutcome) + route.id.size() + 256 + recipe.overrides.size() * 96;
    std::size_t support_count = 0;
    for (const auto& feature : grammar->features()) {
        const auto& c = feature.constraints;
        const auto count = static_cast<std::size_t>(c.floor) + static_cast<std::size_t>(c.ceiling) + static_cast<std::size_t>(c.wall);
        support_count += count;
        bytes += count * (sizeof(SupportOutcome) + feature.id.size() + 256);
    }
    require(grammar->storage_bytes() <= limits.max_prepared_bytes &&
        bytes <= limits.max_prepared_bytes - grammar->storage_bytes(),
        "semantic final-raster scratch memory budget exhausted");
    require(cost + 96 <= limits.max_raster_operations / area,
        "semantic final-raster operation budget exhausted");
    std::uint64_t work = static_cast<std::uint64_t>(area) * (cost + 96);
    for (const auto& route : grammar->routes()) if (route.required) {
        require(route.material == Material::Empty, "required traversal route must emit Empty");
        for (std::size_t p = 1; p < route.points.size(); ++p) {
            const auto a = route.points[p - 1], b = route.points[p];
            require(std::floor(a.x) == a.x && std::floor(a.y) == a.y && std::floor(b.x) == b.x && std::floor(b.y) == b.y &&
                (a.x == b.x || a.y == b.y), "traversal route must have integer rectilinear geometry");
            const auto centres = static_cast<std::uint64_t>(std::abs(a.x - b.x) + std::abs(a.y - b.y)) + 1;
            require(centres <= (limits.max_raster_operations - work) / 16,
                "semantic route verification operation budget exhausted");
            work += centres * 16;
        }
    }
    for (const auto& feature : grammar->features()) {
        const auto& c = feature.constraints;
        const auto contacts = static_cast<std::uint64_t>(feature.bounds.width) *
            (static_cast<std::uint64_t>(c.floor) + static_cast<std::uint64_t>(c.ceiling)) +
            static_cast<std::uint64_t>(feature.bounds.height) * (c.wall ? 2U : 0U);
        require(contacts <= (limits.max_raster_operations - work) / 16,
            "semantic support verification operation budget exhausted");
        work += contacts * 16;
    }
    std::vector<Material> cells(area);
    std::vector<std::uint32_t> prefix(prefix_area, 0);
    SpatialScratch scratch;
    for (std::size_t y = 0; y < height; ++y) {
        std::uint32_t row = 0;
        for (std::size_t x = 0; x < width; ++x) {
            const auto material = sample(bounds.x + static_cast<std::int64_t>(x),
                bounds.y + static_cast<std::int64_t>(y), 0, 0, nullptr, nullptr, &scratch);
            cells[y * width + x] = material;
            row += material == Material::Empty ? 0U : 1U;
            prefix[(y + 1) * (width + 1) + x + 1] = prefix[y * (width + 1) + x + 1] + row;
        }
    }
    const auto radius = static_cast<std::int64_t>(grammar->definition().clearance / 2);
    std::vector<std::uint8_t> clear(area, 0);
    for (std::size_t y = 0; y < height; ++y) for (std::size_t x = 0; x < width; ++x) {
        const auto x0 = static_cast<std::size_t>(std::max<std::int64_t>(0, static_cast<std::int64_t>(x) - radius));
        const auto y0 = static_cast<std::size_t>(std::max<std::int64_t>(0, static_cast<std::int64_t>(y) - radius));
        const auto x1 = static_cast<std::size_t>(std::min<std::int64_t>(bounds.width, static_cast<std::int64_t>(x) + radius + 1));
        const auto y1 = static_cast<std::size_t>(std::min<std::int64_t>(bounds.height, static_cast<std::int64_t>(y) + radius + 1));
        const auto obstacles = prefix[y1 * (width + 1) + x1] + prefix[y0 * (width + 1) + x0] -
            prefix[y1 * (width + 1) + x0] - prefix[y0 * (width + 1) + x1];
        clear[y * width + x] = obstacles == 0 ? 1 : 0;
    }
    const auto each_centre = [&](const SemanticRoute& route, const auto& callback) {
        for (std::size_t p = 1; p < route.points.size(); ++p) {
            auto x = static_cast<std::int64_t>(route.points[p - 1].x);
            auto y = static_cast<std::int64_t>(route.points[p - 1].y);
            const auto end_x = static_cast<std::int64_t>(route.points[p].x);
            const auto end_y = static_cast<std::int64_t>(route.points[p].y);
            const auto dx = (end_x > x) - (end_x < x), dy = (end_y > y) - (end_y < y);
            for (;;) {
                if (inside(bounds, x, y)) callback(x, y, static_cast<std::size_t>(y - bounds.y) * width + static_cast<std::size_t>(x - bounds.x));
                if (x == end_x && y == end_y) break;
                x += dx; y += dy;
            }
        }
    };
    // The profile is a floating square with four-neighbour movement. This
    // qualifies raster clearance/connectivity, never a controller or gravity.
    std::vector<std::uint32_t> queue;
    queue.reserve(area);
    for (const auto& route : grammar->routes()) if (route.required && queue.empty())
        each_centre(route, [&](auto, auto, std::size_t index) {
            if (queue.empty() && clear[index] == 1) { clear[index] = 2; queue.push_back(static_cast<std::uint32_t>(index)); }
        });
    const auto enqueue = [&](std::size_t index) {
        if (clear[index] == 1) { clear[index] = 2; queue.push_back(static_cast<std::uint32_t>(index)); }
    };
    for (std::size_t cursor = 0; cursor < queue.size(); ++cursor) {
        const auto index = static_cast<std::size_t>(queue[cursor]);
        if (index % width > 0) enqueue(index - 1);
        if (index % width + 1 < width) enqueue(index + 1);
        if (index >= width) enqueue(index - width);
        if (index + width < area) enqueue(index + width);
    }
    RouteValidation result;
    result.clearance = grammar->definition().clearance;
    result.cells = area; result.operations = work;
    result.routes.reserve(static_cast<std::size_t>(std::count_if(grammar->routes().begin(), grammar->routes().end(),
        [](const auto& route) { return route.required; })));
    result.supports.reserve(support_count);
    for (const auto& route : grammar->routes()) if (route.required) {
        RouteOutcome outcome;
        outcome.id = route.id;
        each_centre(route, [&](std::int64_t x, std::int64_t y, std::size_t index) {
            ++outcome.checked_centres;
            if (clear[index] == 2) return;
            if (outcome.blocked_centres++ != 0) return;
            outcome.first_block_x = x; outcome.first_block_y = y;
            // Construct then move: GCC 13's pointer assignment may import the
            // newer libstdc++ overlap helper even for these disjoint literals.
            outcome.detail = std::string(clear[index] == 0 ? "final raster blocks declared square clearance" : "final raster disconnects this route from the required network");
            for (const auto& hard : recipe.overrides) if (hard.material && *hard.material != Material::Empty &&
                x + radius >= hard.bounds.x && x - radius < hard.bounds.x + hard.bounds.width &&
                y + radius >= hard.bounds.y && y - radius < hard.bounds.y + hard.bounds.height)
            {
                outcome.detail.append("; final hard override: ");
                outcome.detail.append(hard.id);
            }
        });
        outcome.passed = outcome.checked_centres > 0 && outcome.blocked_centres == 0;
        if (outcome.passed) outcome.detail = std::string("final Empty-cell square clearance and four-neighbour connectivity verified");
        result.passed = result.passed && outcome.passed;
        result.routes.push_back(std::move(outcome));
    }
    for (const auto& feature : grammar->features()) {
        const auto& c = feature.constraints;
        const auto b = feature.bounds;
        const auto check_support = [&](const char* constraint, bool horizontal, bool floor) {
            SupportOutcome outcome;
            outcome.feature_id = feature.id; outcome.constraint = std::string(constraint);
            const auto contact = [&](std::int64_t x, std::int64_t y) {
                ++outcome.checked_cells;
                if (inside(bounds, x, y)) {
                    const auto index = static_cast<std::size_t>(y - bounds.y) * width + static_cast<std::size_t>(x - bounds.x);
                    if (material_definition(cells[index]).state == MaterialState::Solid) return;
                }
                if (outcome.missing_cells++ == 0) { outcome.first_missing_x = x; outcome.first_missing_y = y; }
            };
            if (horizontal) {
                const auto y = floor ? b.y + b.height : b.y - 1;
                for (auto x = b.x; x < b.x + b.width; ++x) contact(x, y);
            } else {
                for (auto y = b.y; y < b.y + b.height; ++y) { contact(b.x - 1, y); contact(b.x + b.width, y); }
            }
            outcome.passed = outcome.checked_cells > outcome.missing_cells;
            outcome.detail = std::string(outcome.passed ? "final raster retains static solid contact on the declared side" :
                "final raster removed all static solid contact on the declared side; inspect final material contributions");
            result.supports_passed = result.supports_passed && outcome.passed;
            result.supports.push_back(std::move(outcome));
        };
        if (c.floor) check_support("floor", true, true);
        if (c.ceiling) check_support("ceiling", true, false);
        if (c.wall) check_support("wall", false, false);
    }
    route_validation = std::move(result);
}

void ModuleRegistry::add(ModuleFactory factory) {
    identifier(factory.id);
    require(factory.version > 0 && factory.operations_per_cell > 0 && factory.operations_per_cell <= 1'000'000 &&
        static_cast<bool>(factory.prepare), "invalid module factory");
    require(factories_.size() < 128, "module registry capacity exceeded");
    for (const auto& f : factories_) require(f.id != factory.id || f.version != factory.version, "duplicate module factory/version");
    factories_.push_back(std::move(factory));
}
const ModuleFactory& ModuleRegistry::find(const std::string& id, std::uint32_t version) const {
    for (const auto& factory : factories_) if (factory.id == id && factory.version == version) return factory;
    invalid("unknown module/version: " + id);
}
ModuleRegistry ModuleRegistry::builtins() {
    ModuleRegistry r;
    r.add({"arcology", 1, 32, [](const auto& i, auto) { return std::make_shared<Arcology>(i); }});
    r.add({"vault", 1, 24, [](const auto& i, auto seed) { return std::make_shared<Vault>(i, seed); }});
    r.add({"aqueduct", 1, 24, [](const auto& i, auto) { return std::make_shared<Aqueduct>(i); }});
    return r;
}

std::vector<Theme> Generator::builtin_themes() {
    return {
        {"world", {}, false, {}, {}}, {"natural", {"world"}, false, {}, {}}, {"built", {"world"}, false, {}, {}},
        {"dry_cavern", {"natural"}, true, {Material::SandstoneBlock, Material::Sand, Material::TerracottaTile, Material::Water}, {}},
        {"wet_cavern", {"natural"}, true, {Material::LimestoneBlock, Material::MossyCobblestone, Material::Copper, Material::Water}, {}},
        {"basalt", {"natural"}, true, {Material::GraniteBlock, Material::Slate, Material::NeonAmber, Material::Lava}, {}},
        {"industrial", {"built"}, true, {Material::ReinforcedConcrete, Material::SteelPlate, Material::NeonCyan, Material::Oil}, {}},
        {"ruins", {"built"}, true, {Material::IndustrialBrick, Material::Cobblestone, Material::RustedSteel, Material::Water}, {}},
        {"garden", {"natural", "built"}, true, {Material::LimestoneBlock, Material::PackedEarth, Material::Plant, Material::Water}, {}}
    };
}
std::vector<std::string> Generator::builtin_modules() { return {"arcology", "vault", "aqueduct"}; }

std::shared_ptr<const Generator> Generator::compile(Recipe recipe, const ModuleRegistry& registry) {
    require((recipe.schema == kSchemaVersion || recipe.schema == kTypedSchemaVersion || recipe.schema == kHierarchySchemaVersion) && recipe.revision > 0, "unsupported schema or zero revision");
    require(recipe.schema >= kTypedSchemaVersion || recipe.spatial.empty(), "typed spatial fields require schema 2 or 3");
    require(recipe.schema == kHierarchySchemaVersion || recipe.grammar.empty(), "semantic hierarchy requires schema 3");
    require(recipe.chunk_size >= 8 && recipe.chunk_size <= 256, "generation chunk_size must be 8..256");
    require(parse_candidate(candidate_name(recipe.candidate)).has_value(), "invalid candidate");
    for (std::size_t i = 0; i < kParameterCount; ++i) validate_parameter(static_cast<Parameter>(i), value(recipe.parameters, static_cast<Parameter>(i)));
    require(std::floor(recipe.parameters.district_size) == recipe.parameters.district_size, "district_size must be an integer");
    const auto& limits = recipe.limits;
    require(limits.max_themes > 0 && limits.max_themes <= 64 && limits.max_strokes <= 64 &&
        limits.max_points_per_path > 0 && limits.max_points_per_path <= 128 && limits.max_paths <= 64 &&
        limits.max_overrides <= 64 && limits.max_modules <= 32 &&
        limits.max_fields > 0 && limits.max_fields <= 64 && limits.max_aggregates > 0 &&
        limits.max_aggregates <= 32 && limits.max_modifiers > 0 && limits.max_modifiers <= 64 && limits.max_operations_per_chunk > 0 &&
        limits.max_operations_per_chunk <= UINT64_C(1'000'000'000), "invalid generation limits");
    if (recipe.catalogue.empty()) recipe.catalogue = builtin_themes();
    require(recipe.catalogue.size() <= limits.max_themes && recipe.strokes.size() <= limits.max_strokes &&
        recipe.paths.size() <= limits.max_paths && recipe.overrides.size() <= limits.max_overrides &&
        recipe.modules.size() <= limits.max_modules && recipe.fields.size() <= limits.max_fields &&
        recipe.aggregates.size() <= limits.max_aggregates && recipe.modifiers.size() <= limits.max_modifiers, "recipe capacity exceeded");
    auto impl = std::make_unique<Impl>();
    impl->fields = FieldGraph::compile(recipe.fields, recipe.seed, {limits.max_fields, kMaxFieldDepth, kMaxFieldOperations});
    recipe.fields = impl->fields->nodes();
    auto prepared_spatial = recipe.spatial;
    if (!recipe.grammar.empty()) {
        impl->grammar = GrammarPlan::compile(recipe.grammar, recipe.seed);
        // Semantic exports are prepared inputs, not authored recipe entries.
        // Keeping them out of the retained recipe makes recompilation exact.
        for (auto geometry : impl->grammar->geometry_inputs()) prepared_spatial.geometries.push_back(std::move(geometry));
        impl->cost += impl->grammar->operations_per_sample();
    }
    impl->spatial = SpatialGraph::compile(std::move(prepared_spatial), recipe.seed, recipe.spatial_limits);
    impl->cost += impl->spatial->operations_per_sample();
    impl->cost += impl->fields->operations_per_sample();
    if (!recipe.fields.empty() || !recipe.spatial.empty() || !recipe.modifiers.empty()) impl->cost += 384;
    std::sort(recipe.aggregates.begin(), recipe.aggregates.end(), [](const auto& a, const auto& b) { return a.id < b.id; });
    std::map<std::string, std::size_t> aggregate_index;
    for (auto& aggregate : recipe.aggregates) {
        identifier(aggregate.id);
        require(aggregate_index.emplace(aggregate.id, aggregate_index.size()).second, "duplicate aggregate ID: " + aggregate.id);
        require(aggregate.grain_size >= 1 && aggregate.grain_size <= 4096 &&
            !aggregate.components.empty() && aggregate.components.size() <= 16, "invalid aggregate grain size or component capacity");
        std::sort(aggregate.components.begin(), aggregate.components.end(), [](const auto& a, const auto& b) { return a.material < b.material; });
        double total = 0;
        for (std::size_t i = 0; i < aggregate.components.size(); ++i) {
            const auto& c = aggregate.components[i];
            require(valid_material(c.material) && std::isfinite(c.weight) && c.weight > 0 && c.weight <= 1'000'000,
                "invalid aggregate component");
            require(i == 0 || aggregate.components[i - 1].material != c.material, "duplicate aggregate material");
            total += c.weight;
        }
        std::vector<double> normalized;
        normalized.reserve(aggregate.components.size());
        for (const auto& c : aggregate.components) {
            const auto weight = c.weight / total;
            require(weight > 0, "aggregate component weight underflows when normalized");
            normalized.push_back(weight);
        }
        impl->aggregate_weights.push_back(std::move(normalized));
        impl->aggregate_variations.push_back(aggregate.variation.empty() ? Impl::absent : impl->mask_index(aggregate.variation));
        auto salt = kFnv; hash_text(salt, aggregate.id); impl->aggregate_salts.push_back(salt);
        impl->cost += 24 + aggregate.components.size() * 4;
    }
    // Validate authored external bindings even when a rule is unreachable or
    // its explicit placement fallback omitted every feature in this window.
    if (impl->grammar) for (const auto& rule : impl->grammar->definition().rules) {
        (void)impl->compile_mask(rule.application, rule.exclusion, 1);
        if (rule.aggregate.empty()) continue;
        const auto found = aggregate_index.find(rule.aggregate);
        require(found != aggregate_index.end(), "unknown semantic aggregate: " + rule.aggregate);
        for (const auto& component : recipe.aggregates[found->second].components)
            require(rule.allowed_materials.empty() || std::find(rule.allowed_materials.begin(), rule.allowed_materials.end(), component.material) != rule.allowed_materials.end(),
                "semantic aggregate violates allowed materials: " + rule.id);
    }
    if (impl->grammar) for (const auto& feature : impl->grammar->features()) {
        impl->semantic_masks.push_back(impl->compile_mask(feature.application, feature.exclusion, 1));
        auto aggregate = Impl::absent;
        if (!feature.aggregate.empty()) {
            const auto found = aggregate_index.find(feature.aggregate);
            require(found != aggregate_index.end(), "unknown semantic aggregate: " + feature.aggregate);
            aggregate = found->second;
            for (const auto& component : recipe.aggregates[aggregate].components)
                require(feature.allowed_materials.empty() || std::find(feature.allowed_materials.begin(), feature.allowed_materials.end(), component.material) != feature.allowed_materials.end(),
                    "semantic aggregate violates allowed materials: " + feature.id);
        }
        impl->semantic_aggregates.push_back(aggregate);
    }
    std::sort(recipe.catalogue.begin(), recipe.catalogue.end(), [](const auto& a, const auto& b) { return a.id < b.id; });
    std::map<std::string, std::size_t> theme_index;
    for (std::size_t i = 0; i < recipe.catalogue.size(); ++i) {
        auto& t = recipe.catalogue[i]; identifier(t.id);
        require(theme_index.emplace(t.id, i).second, "duplicate theme ID: " + t.id);
        require(t.parents.size() <= kMaxThemes, "theme parent capacity exceeded");
        std::sort(t.parents.begin(), t.parents.end());
        require(std::adjacent_find(t.parents.begin(), t.parents.end()) == t.parents.end(), "duplicate parent");
        validate_edits(t.parameters);
        for (const auto m : {t.palette.rock, t.palette.surface, t.palette.accent, t.palette.fluid}) require(valid_material(m), "invalid palette material");
    }
    std::vector<int> visit(recipe.catalogue.size(), 0);
    std::vector<std::vector<std::size_t>> ancestors(recipe.catalogue.size());
    std::function<void(std::size_t)> walk = [&](std::size_t index) {
        require(visit[index] != 1, "cyclic theme hierarchy"); if (visit[index] == 2) return;
        visit[index] = 1;
        for (const auto& parent : recipe.catalogue[index].parents) {
            const auto it = theme_index.find(parent); require(it != theme_index.end(), "unknown parent: " + parent);
            walk(it->second);
            for (const auto a : ancestors[it->second]) if (std::find(ancestors[index].begin(), ancestors[index].end(), a) == ancestors[index].end()) ancestors[index].push_back(a);
        }
        ancestors[index].push_back(index); visit[index] = 2;
    };
    for (std::size_t i = 0; i < recipe.catalogue.size(); ++i) { walk(i); impl->descendants.emplace(recipe.catalogue[i].id, std::vector<std::size_t>{}); }
    for (std::size_t i = 0; i < recipe.catalogue.size(); ++i) if (recipe.catalogue[i].concrete) {
        auto params = recipe.parameters;
        for (const auto a : ancestors[i]) apply_edits(params, recipe.catalogue[a].parameters);
        const auto index = impl->leaves.size();
        impl->leaves.push_back(recipe.catalogue[i]); impl->leaf_parameters.push_back(params);
        for (const auto a : ancestors[i]) impl->descendants.at(recipe.catalogue[a].id).push_back(index);
    }
    require(!impl->leaves.empty(), "theme catalogue has no concrete themes");
    canonical_selection(recipe.themes);
    for (const auto& name : recipe.themes.exclude) {
        const auto it = impl->descendants.find(name); require(it != impl->descendants.end(), "unknown excluded theme: " + name);
        for (const auto i : it->second) impl->excluded[i] = true;
    }
    impl->base_weights = impl->resolve(recipe.themes);
    order_and_identify(recipe.strokes); order_and_identify(recipe.paths);
    order_and_identify(recipe.overrides); order_and_identify(recipe.modules);
    order_and_identify(recipe.modifiers);
    for (auto& b : recipe.strokes) {
        validate_points(b.points, limits); validate_edits(b.parameters); canonical_selection(b.themes);
        require(std::isfinite(b.radius) && b.radius >= 1 && b.radius <= 1'000'000 &&
            std::isfinite(b.strength) && b.strength >= 0 && b.strength <= 1 &&
            std::isfinite(b.falloff) && b.falloff >= 0.1 && b.falloff <= 8, "invalid brush controls");
        require(!b.themes.weights.empty() || b.themes.exclude.empty(), "parameter-only brush cannot carry theme exclusions");
        impl->brush_weights.push_back(b.themes.weights.empty() ? Weights{} : impl->resolve(b.themes));
        impl->cost += 128 + b.points.size() * 24 + b.parameters.size() * 8 + impl->leaves.size() * 4;
    }
    for (const auto& path : recipe.paths) {
        validate_points(path.points, limits);
        require(std::isfinite(path.width) && path.width >= 1 && path.width <= 4096 && valid_material(path.material), "invalid guide path");
        impl->cost += path.points.size() * 16;
    }
    for (auto& hard : recipe.overrides) {
        validate_rect(hard.bounds); validate_edits(hard.parameters);
        require(!hard.material || valid_material(*hard.material), "invalid override material");
        require(!hard.candidate || parse_candidate(candidate_name(*hard.candidate)).has_value(), "invalid override candidate");
        require(hard.material || hard.candidate || !hard.parameters.empty(), "empty hard override");
        impl->cost += 16 + hard.parameters.size() * 4;
    }
    bool has_guidance = false;
    for (auto& m : recipe.modifiers) {
        require(!(m.bounds && !m.points.empty()), "modifier bounds and points are exclusive");
        if (m.bounds) validate_rect(*m.bounds);
        if (!m.points.empty()) validate_points(m.points, limits);
        require(std::isfinite(m.radius) && m.radius >= 1 && m.radius <= 1'000'000 &&
            std::isfinite(m.falloff) && m.falloff >= 0.1 && m.falloff <= 8, "invalid modifier brush geometry");
        require(parse_context_predicate(context_predicate_name(m.context)).has_value(), "invalid modifier context");
        require((m.context == ContextPredicate::Material) == m.context_material.has_value(), "material context requires exactly one context_material");
        require(!m.context_material || valid_material(*m.context_material), "invalid modifier context material");
        require(!m.material || valid_material(*m.material), "invalid modifier material");
        require(!m.material || m.aggregate.empty(), "modifier material and aggregate are exclusive");
        require(m.material || !m.aggregate.empty() || !m.parameters.empty() || !m.themes.weights.empty() || !m.mappings.empty(), "empty modifier");
        validate_edits(m.parameters); canonical_selection(m.themes);
        require(!m.themes.weights.empty() || m.themes.exclude.empty(), "modifier theme exclusions require a selection");
        require(m.mappings.size() <= kParameterCount, "modifier mapping capacity exceeded");
        Impl::PreparedModifier prepared;
        prepared.mask = impl->compile_mask(m.application, m.exclusion, m.strength);
        if (!m.themes.weights.empty()) prepared.themes = impl->resolve(m.themes);
        if (!m.aggregate.empty()) {
            const auto found = aggregate_index.find(m.aggregate);
            require(found != aggregate_index.end(), "unknown aggregate: " + m.aggregate); prepared.aggregate = found->second;
        }
        prepared.salt = kFnv; hash_text(prepared.salt, m.id);
        std::sort(m.mappings.begin(), m.mappings.end(), [](const auto& a, const auto& b) { return a.parameter < b.parameter; });
        for (std::size_t i = 0; i < m.mappings.size(); ++i) {
            const auto& mapping = m.mappings[i];
            validate_parameter(mapping.parameter, mapping.low); validate_parameter(mapping.parameter, mapping.high);
            require(mapping.parameter != Parameter::DistrictSize, "district_size cannot be spatially mapped");
            require(i == 0 || m.mappings[i - 1].parameter != mapping.parameter, "duplicate modifier mapping");
            require(std::none_of(m.parameters.begin(), m.parameters.end(), [&](const auto& e) { return e.parameter == mapping.parameter; }),
                "modifier parameter cannot have both a target and a mapping");
            prepared.mappings.push_back(impl->mask_index(mapping.field));
        }
        impl->modifiers.push_back(std::move(prepared));
        has_guidance = has_guidance || !m.themes.weights.empty() || !m.parameters.empty() || !m.mappings.empty();
        impl->cost += 96 + m.points.size() * 24 + m.parameters.size() * 8 + m.mappings.size() * 12 + impl->leaves.size() * 4;
    }
    if (has_guidance) {
        impl->cost += 128 + impl->leaves.size() * kParameterCount * 4;
        for (const auto& b : recipe.strokes) impl->cost += 128 + b.points.size() * 24 + b.parameters.size() * 8;
    }
    std::set<std::string> module_ids, emitted;
    for (const auto& m : recipe.modules) module_ids.insert(m.id);
    for (auto& m : recipe.modules) {
        identifier(m.module); validate_rect(m.bounds);
        (void)impl->compile_mask(m.application, m.exclusion, m.strength);
        require(m.parameters.size() <= 32 && m.after.size() <= limits.max_modules, "module argument capacity exceeded");
        for (const auto& [name, v] : m.parameters) { identifier(name); require(std::isfinite(v), "non-finite module parameter"); }
        std::sort(m.after.begin(), m.after.end());
        require(std::adjacent_find(m.after.begin(), m.after.end()) == m.after.end(), "duplicate module dependency");
        for (const auto& dep : m.after) require(dep != m.id && module_ids.contains(dep), "missing or self module dependency");
    }
    while (emitted.size() < recipe.modules.size()) {
        const ModuleInstance* next = nullptr;
        for (const auto& m : recipe.modules) if (!emitted.contains(m.id) &&
            std::all_of(m.after.begin(), m.after.end(), [&](const auto& dep) { return emitted.contains(dep); })) { next = &m; break; }
        require(next != nullptr, "cyclic module dependencies");
        const auto& f = registry.find(next->module, next->version);
        auto prepared = f.prepare(*next, recipe.seed);
        require(static_cast<bool>(prepared), "module preparation returned no sampler");
        impl->modules.push_back({*next, std::move(prepared), f.operations_per_cell});
        impl->module_masks.push_back(impl->compile_mask(next->application, next->exclusion, next->strength));
        auto salt = kFnv; hash_text(salt, next->id); impl->module_salts.push_back(salt);
        impl->cost += f.operations_per_cell + 8; emitted.insert(next->id);
    }
    impl->cost += impl->leaves.size() * kParameterCount * 4;
    if (!recipe.fields.empty() || !recipe.spatial.empty() || !recipe.modifiers.empty()) {
        // The surface-slope context samples two neighboring immutable parameter
        // proposals, never another field graph or mutable/generated cell.
        std::uint64_t neighbor_cost = 64 + impl->leaves.size() * kParameterCount * 4;
        for (const auto& b : recipe.strokes)
            neighbor_cost += 128 + b.points.size() * 24 + b.parameters.size() * 8 + impl->leaves.size() * 4;
        for (const auto& hard : recipe.overrides) neighbor_cost += 16 + hard.parameters.size() * 4;
        impl->cost += neighbor_cost * 2;
    }
    auto& h = impl->fingerprint;
    hash_word(h, recipe.schema == kHierarchySchemaVersion ? kHierarchyAlgorithmVersion : recipe.schema == kTypedSchemaVersion ? kTypedAlgorithmVersion : kAlgorithmVersion); hash_word(h, recipe.schema); hash_word(h, recipe.seed);
    hash_word(h, recipe.revision); hash_word(h, static_cast<std::uint64_t>(recipe.chunk_size)); hash_word(h, static_cast<std::uint64_t>(recipe.candidate));
    for (std::size_t i = 0; i < kParameterCount; ++i) hash_real(h, value(recipe.parameters, static_cast<Parameter>(i)));
    hash_word(h, recipe.catalogue.size());
    for (const auto& t : recipe.catalogue) {
        hash_text(h, t.id); hash_word(h, t.concrete); hash_word(h, t.parents.size()); for (const auto& parent : t.parents) hash_text(h, parent);
        for (const auto m : {t.palette.rock, t.palette.surface, t.palette.accent, t.palette.fluid}) hash_word(h, static_cast<std::uint64_t>(m));
        hash_edits(h, t.parameters);
    }
    hash_selection(h, recipe.themes); hash_word(h, recipe.strokes.size());
    for (const auto& b : recipe.strokes) {
        hash_text(h, b.id); hash_word(h, static_cast<std::uint64_t>(b.priority)); hash_points(h, b.points);
        hash_real(h, b.radius); hash_real(h, b.strength); hash_real(h, b.falloff); hash_selection(h, b.themes); hash_edits(h, b.parameters);
    }
    hash_word(h, recipe.paths.size());
    for (const auto& p : recipe.paths) {
        hash_text(h, p.id); hash_word(h, static_cast<std::uint64_t>(p.priority)); hash_points(h, p.points);
        hash_real(h, p.width); hash_word(h, static_cast<std::uint64_t>(p.material));
    }
    hash_word(h, recipe.overrides.size());
    for (const auto& o : recipe.overrides) {
        hash_text(h, o.id); hash_word(h, static_cast<std::uint64_t>(o.priority)); hash_rect(h, o.bounds);
        hash_word(h, o.material ? static_cast<std::uint64_t>(*o.material) + 1 : 0);
        hash_word(h, o.candidate ? static_cast<std::uint64_t>(*o.candidate) + 1 : 0); hash_edits(h, o.parameters);
    }
    hash_word(h, impl->modules.size());
    for (const auto& m : impl->modules) {
        hash_text(h, m.instance.id); hash_text(h, m.instance.module); hash_word(h, m.instance.version); hash_word(h, m.cost);
        hash_word(h, static_cast<std::uint64_t>(m.instance.priority)); hash_rect(h, m.instance.bounds);
        hash_word(h, m.instance.parameters.size());
        for (const auto& [name, v] : m.instance.parameters) { hash_text(h, name); hash_real(h, v); }
        hash_word(h, m.instance.after.size()); for (const auto& name : m.instance.after) hash_text(h, name);
        hash_text(h, m.instance.application); hash_text(h, m.instance.exclusion); hash_real(h, m.instance.strength);
    }
    hash_word(h, impl->fields->fingerprint());
    hash_word(h, recipe.aggregates.size());
    for (const auto& a : recipe.aggregates) {
        hash_text(h, a.id); hash_word(h, static_cast<std::uint64_t>(a.grain_size)); hash_text(h, a.variation);
        hash_word(h, a.components.size());
        for (const auto& c : a.components) { hash_word(h, static_cast<std::uint64_t>(c.material)); hash_real(h, c.weight); }
    }
    hash_word(h, recipe.modifiers.size());
    for (const auto& m : recipe.modifiers) {
        hash_text(h, m.id); hash_word(h, static_cast<std::uint64_t>(m.priority));
        hash_word(h, m.bounds.has_value()); if (m.bounds) hash_rect(h, *m.bounds);
        hash_points(h, m.points); hash_real(h, m.radius); hash_real(h, m.falloff); hash_real(h, m.strength);
        hash_text(h, m.application); hash_text(h, m.exclusion); hash_word(h, static_cast<std::uint64_t>(m.context));
        hash_word(h, m.context_material ? static_cast<std::uint64_t>(*m.context_material) + 1 : 0);
        hash_selection(h, m.themes); hash_edits(h, m.parameters); hash_word(h, m.mappings.size());
        for (const auto& map : m.mappings) {
            hash_word(h, static_cast<std::uint64_t>(map.parameter)); hash_text(h, map.field);
            hash_real(h, map.low); hash_real(h, map.high);
        }
        hash_word(h, m.material ? static_cast<std::uint64_t>(*m.material) + 1 : 0); hash_text(h, m.aggregate);
    }
    for (const auto v : {limits.max_themes, limits.max_strokes, limits.max_points_per_path, limits.max_paths,
            limits.max_overrides, limits.max_modules, limits.max_fields, limits.max_aggregates, limits.max_modifiers}) hash_word(h, v);
    hash_word(h, limits.max_operations_per_chunk);
    if (recipe.schema >= kTypedSchemaVersion) hash_word(h, impl->spatial->fingerprint());
    if (impl->grammar) hash_word(h, impl->grammar->fingerprint());
    impl->recipe = std::move(recipe);
    if (impl->grammar) impl->check_routes();
    return std::shared_ptr<const Generator>(new Generator(std::move(impl)));
}

Generator::Generator(std::unique_ptr<Impl> impl) : impl_(std::move(impl)) {}
Generator::~Generator() = default;
const Recipe& Generator::recipe() const noexcept { return impl_->recipe; }
const SpatialGraph& Generator::spatial_graph() const noexcept { return *impl_->spatial; }
const GrammarPlan* Generator::semantic_plan() const noexcept { return impl_->grammar.get(); }
const RouteValidation& Generator::validate_routes() const noexcept { return impl_->route_validation; }
CellProvenance Generator::explain(std::int64_t x, std::int64_t y) const {
    require(x >= -kCoordinateLimit && x < kCoordinateLimit && y >= -kCoordinateLimit && y < kCoordinateLimit, "sample coordinate out of range");
    CellProvenance result;
    result.x = x; result.y = y;
    result.revision = recipe().revision; result.fingerprint = fingerprint(); result.logical_cost = operations_per_cell();
    (void)impl_->sample(x, y, 0, 0, nullptr, nullptr, nullptr, &result);
    auto hash = kFnv; hash_word(hash, result.revision); hash_word(hash, result.fingerprint);
    hash_word(hash, static_cast<std::uint64_t>(x)); hash_word(hash, static_cast<std::uint64_t>(y));
    hash_word(hash, static_cast<unsigned>(result.material));
    result.proposal_hash = hash;
    return result;
}
GenerationStages Generator::stages(std::int64_t x, std::int64_t y) const {
    require(x >= -kCoordinateLimit && x < kCoordinateLimit && y >= -kCoordinateLimit && y < kCoordinateLimit, "sample coordinate out of range");
    GenerationStages result;
    (void)impl_->sample(x, y, 0, 0, nullptr, nullptr, nullptr, nullptr, &result);
    return result;
}
std::uint64_t Generator::fingerprint() const noexcept { return impl_->fingerprint; }
std::uint64_t Generator::operations_per_cell() const noexcept { return impl_->cost; }
std::vector<ThemeWeight> Generator::theme_weights_at(std::int64_t x, std::int64_t y) const {
    require(x >= -kCoordinateLimit && x < kCoordinateLimit && y >= -kCoordinateLimit && y < kCoordinateLimit, "sample coordinate out of range");
    auto weights = impl_->weights(x, y); std::vector<ThemeWeight> result;
    if (!recipe().modifiers.empty()) {
        auto p = impl_->parameters_at(weights, x, y);
        const auto candidate = impl_->hard_parameters(p, x, y);
        const auto& palette = impl_->palette_at(weights, x, y);
        const auto base = candidate == Candidate::DistrictGrammar ? impl_->district(x, y, p, palette) : impl_->strata(x, y, p, palette);
        const auto context = impl_->field_context(x, y, p, candidate, base);
        Impl::Values values; impl_->evaluate_fields(x, y, context, values);
        for (std::size_t i = 0; i < recipe().modifiers.size(); ++i) {
            const auto& m = recipe().modifiers[i];
            if (m.themes.weights.empty() || !Impl::matches(m, context)) continue;
            const auto alpha = impl_->modifiers[i].mask.at(values) * Impl::shape(m, x, y);
            for (std::size_t leaf = 0; leaf < impl_->leaves.size(); ++leaf)
                weights[leaf] = lerp(weights[leaf], impl_->modifiers[i].themes[leaf], alpha);
        }
    }
    for (std::size_t i = 0; i < impl_->leaves.size(); ++i) if (weights[i] > 0) result.push_back({impl_->leaves[i].id, weights[i]});
    return result;
}
Material Generator::sample(std::int64_t x, std::int64_t y) const {
    require(x >= -kCoordinateLimit && x < kCoordinateLimit && y >= -kCoordinateLimit && y < kCoordinateLimit, "sample coordinate out of range");
    return impl_->sample(x, y);
}
std::unique_ptr<GenerationJob> Generator::begin(ChunkCoord chunk, const std::string& diagnostic) const {
    return std::unique_ptr<GenerationJob>(new GenerationJob(shared_from_this(), chunk, diagnostic));
}
ChunkResult Generator::generate(ChunkCoord chunk, const std::string& diagnostic) const {
    auto job = begin(chunk, diagnostic); (void)job->advance(static_cast<std::size_t>(recipe().chunk_size) * static_cast<std::size_t>(recipe().chunk_size));
    return job->result();
}
bool Generator::accepts(const ChunkResult& result) const noexcept {
    const auto size = recipe().chunk_size;
    const auto min_chunk = -(kCoordinateLimit / size), max_chunk = (kCoordinateLimit - size) / size;
    if (result.state != ResultState::Ready || result.revision != recipe().revision || result.fingerprint != fingerprint() ||
        result.chunk_size != size || result.cells.size() != static_cast<std::size_t>(size) * static_cast<std::size_t>(size) ||
        result.chunk.x < min_chunk || result.chunk.x > max_chunk || result.chunk.y < min_chunk || result.chunk.y > max_chunk) return false;
    for (const auto m : result.cells) if (!valid_material(m)) return false;
    try {
        const auto selected = impl_->diagnostic(result.diagnostic);
        if (selected.first == 5) {
            if (!result.diagnostics.empty() || !result.typed_diagnostics.empty() ||
                !(result.diagnostic_info == SpatialInfo{}) || result.stage_cells.size() != result.cells.size()) return false;
            for (const auto material : result.stage_cells) if (!valid_material(material)) return false;
        } else if (!result.stage_cells.empty()) return false;
        else if (selected.first == 4) {
            if (!result.diagnostics.empty() || result.typed_diagnostics.size() != result.cells.size() ||
                !(result.diagnostic_info == impl_->spatial->info(selected.second))) return false;
            for (const auto& v : result.typed_diagnostics) {
                if (v.type != result.diagnostic_info.type || !std::isfinite(v.x) || !std::isfinite(v.y)) return false;
                if (v.type != SpatialType::Category && !(v.category == SpatialCategory{})) return false;
                if (v.type == SpatialType::Category && (v.x != 0 || v.y != 0)) return false;
                if (v.type != SpatialType::Vector2 && v.y != 0) return false;
                if (v.type == SpatialType::Normalized && (v.x < 0 || v.x > 1)) return false;
                if (v.type == SpatialType::Boolean && v.x != 0 && v.x != 1) return false;
                if (v.type == SpatialType::Distance && v.x < 0) return false;
            }
        } else {
            if (!result.typed_diagnostics.empty() || !(result.diagnostic_info == SpatialInfo{})) return false;
            if (result.diagnostic.empty() ? !result.diagnostics.empty() : result.diagnostics.size() != result.cells.size()) return false;
        }
    } catch (...) { return false; }
    for (const auto v : result.diagnostics) if (!std::isfinite(v) || v < 0 || v > 1) return false;
    return result.content_hash == payload_hash(result.cells) && result.receipt_hash == receipt_hash(result);
}

GenerationJob::GenerationJob(std::shared_ptr<const Generator> generator, ChunkCoord chunk, const std::string& diagnostic) : generator_(std::move(generator)) {
    const auto selected = generator_->impl_->diagnostic(diagnostic);
    diagnostic_kind_ = selected.first; diagnostic_index_ = selected.second;
    const auto size = generator_->recipe().chunk_size;
    const auto min_chunk = -(kCoordinateLimit / size), max_chunk = (kCoordinateLimit - size) / size;
    require(chunk.x >= min_chunk && chunk.y >= min_chunk && chunk.x <= max_chunk && chunk.y <= max_chunk, "chunk coordinate outside supported range");
    origin_x_ = chunk.x * size; origin_y_ = chunk.y * size;
    result_.chunk = chunk; result_.chunk_size = size; result_.revision = generator_->recipe().revision;
    result_.fingerprint = generator_->fingerprint();
    result_.diagnostic = diagnostic;
    result_.error.reserve(256);
    const auto area = static_cast<std::size_t>(size) * static_cast<std::size_t>(size);
    const auto cost = generator_->impl_->cost + (diagnostic_kind_ == 0 ? 0 : diagnostic_kind_ == 4 ? 16 : 4);
    if (generator_->recipe().schema >= kTypedSchemaVersion && cost > generator_->recipe().limits.max_operations_per_chunk / area) {
        result_.state = ResultState::Failed;
        set_diagnostic(result_.error, "generation logical operation budget exhausted during preflight");
        return;
    }
    result_.cells.resize(area);
    if (diagnostic_kind_ == 5) result_.stage_cells.resize(area);
    else if (diagnostic_kind_ == 4) {
        result_.diagnostic_info = generator_->impl_->spatial->info(diagnostic_index_);
        result_.typed_diagnostics.resize(area);
    } else if (diagnostic_kind_ != 0) result_.diagnostics.resize(area);
}
GenerationJob::~GenerationJob() = default;
ResultState GenerationJob::advance(std::size_t cell_budget) {
    if (result_.state != ResultState::Pending || cell_budget == 0) return result_.state;
    const auto end = cursor_ + std::min(cell_budget, result_.cells.size() - cursor_);
    try {
        while (cursor_ < end) {
            const auto cost = generator_->impl_->cost + (diagnostic_kind_ == 0 ? 0 : diagnostic_kind_ == 4 ? 16 : 4);
            if (cost > generator_->recipe().limits.max_operations_per_chunk - result_.operations) throw std::runtime_error("generation logical operation budget exhausted");
            result_.operations += cost;
            const auto size = static_cast<std::size_t>(result_.chunk_size);
            GenerationStages stages;
            result_.cells[cursor_] = generator_->impl_->sample(origin_x_ + static_cast<std::int64_t>(cursor_ % size),
                origin_y_ + static_cast<std::int64_t>(cursor_ / size), diagnostic_kind_, diagnostic_index_,
                diagnostic_kind_ == 0 || diagnostic_kind_ == 4 || diagnostic_kind_ == 5 ? nullptr : &result_.diagnostics[cursor_],
                diagnostic_kind_ == 4 ? &result_.typed_diagnostics[cursor_] : nullptr, &spatial_scratch_, nullptr,
                diagnostic_kind_ == 5 ? &stages : nullptr);
            if (diagnostic_kind_ == 5) result_.stage_cells[cursor_] = stages.materials[diagnostic_index_];
            ++cursor_;
        }
        if (cursor_ == result_.cells.size()) {
            result_.content_hash = payload_hash(result_.cells); result_.receipt_hash = receipt_hash(result_); result_.state = ResultState::Ready;
        }
    } catch (const std::exception& error) {
        result_.state = ResultState::Failed; result_.cells.clear(); result_.diagnostics.clear(); result_.typed_diagnostics.clear(); result_.stage_cells.clear(); result_.diagnostic_info = {}; result_.content_hash = 0; result_.receipt_hash = 0;
        set_diagnostic(result_.error, error.what());
    } catch (...) {
        result_.state = ResultState::Failed; result_.cells.clear(); result_.diagnostics.clear(); result_.typed_diagnostics.clear(); result_.stage_cells.clear(); result_.diagnostic_info = {}; result_.content_hash = 0; result_.receipt_hash = 0;
        set_diagnostic(result_.error, "module threw an unknown exception");
    }
    return result_.state;
}
void GenerationJob::cancel() noexcept {
    if (result_.state == ResultState::Pending) { result_.state = ResultState::Cancelled; result_.cells.clear(); result_.diagnostics.clear(); result_.typed_diagnostics.clear(); result_.stage_cells.clear(); result_.diagnostic_info = {}; result_.content_hash = 0; result_.receipt_hash = 0; }
}
ResultState GenerationJob::state() const noexcept { return result_.state; }
std::size_t GenerationJob::completed_cells() const noexcept { return cursor_; }
const ChunkResult& GenerationJob::result() const {
    if (result_.state == ResultState::Pending) throw std::logic_error("pending generation has no published payload");
    return result_;
}
const char* generation_stage_name(GenerationStage stage) noexcept {
    constexpr std::array names{"candidate", "guided_candidate", "grammar", "modifiers", "connectivity", "final"};
    const auto index = static_cast<std::size_t>(stage); return index < names.size() ? names[index] : "invalid";
}
std::optional<GenerationStage> parse_generation_stage(const std::string& name) noexcept {
    for (std::size_t i = 0; i < kGenerationStageCount; ++i)
        if (name == generation_stage_name(static_cast<GenerationStage>(i))) return static_cast<GenerationStage>(i);
    return std::nullopt;
}
const char* candidate_name(Candidate c) noexcept {
    switch (c) { case Candidate::Strata: return "strata"; case Candidate::FlowNetwork: return "flow_network"; case Candidate::DistrictGrammar: return "district_grammar"; }
    return "invalid";
}
std::optional<Candidate> parse_candidate(const std::string& name) noexcept {
    for (unsigned i = 0; i < 3; ++i) if (name == candidate_name(static_cast<Candidate>(i))) return static_cast<Candidate>(i);
    return std::nullopt;
}
const char* parameter_name(Parameter p) noexcept {
    constexpr std::array names{"surface_y", "relief", "feature_scale", "cave_threshold", "strata_period", "warp", "corridor_width", "district_size", "room_size", "wall_thickness", "detail", "fluid_level"};
    const auto index = static_cast<std::size_t>(p); return index < names.size() ? names[index] : "invalid";
}
std::optional<Parameter> parse_parameter(const std::string& name) noexcept {
    for (unsigned i = 0; i < kParameterCount; ++i) if (name == parameter_name(static_cast<Parameter>(i))) return static_cast<Parameter>(i);
    return std::nullopt;
}
const char* context_predicate_name(ContextPredicate predicate) noexcept {
    constexpr std::array names{"any", "empty", "occupied", "solid", "fluid", "material"};
    const auto index = static_cast<std::size_t>(predicate); return index < names.size() ? names[index] : "invalid";
}
std::optional<ContextPredicate> parse_context_predicate(const std::string& name) noexcept {
    for (unsigned i = 0; i < 6; ++i) if (name == context_predicate_name(static_cast<ContextPredicate>(i))) return static_cast<ContextPredicate>(i);
    return std::nullopt;
}
} // namespace cybersand::generation
