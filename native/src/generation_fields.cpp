#include "cybersand/generation_fields.hpp"
#include "cybersand/material.hpp"

#include <algorithm>
#include <bit>
#include <cmath>
#include <limits>
#include <stdexcept>
#include <utility>

// Original implementation of finite square subdivision, integer interleaving,
// hashed lattice interpolation and bounded nearest-feature sampling. No external
// source code, permutation table, library or code license is imported.
// Mathematical references:
// D. Hilbert (1891), https://doi.org/10.1007/BF01199431
// K. Perlin (2002), https://cs.nyu.edu/~perlin/noise/ (quintic interpolation)
// B. Chan/M. McCool (2004), "Worley Cellular Textures in Sh", SIGGRAPH poster
// (jittered feature lattice); this implementation searches an explicit 5x5
// stencil and returns normalized F1 or F2-F1, not exact Voronoi-edge distance.

namespace cybersand::generation {
namespace {

constexpr double kCoordinate = static_cast<double>(kFieldCoordinateLimit);
constexpr double kInvSqrtTwo = 0.70710678118654752440;
constexpr std::uint64_t kFnvOffset = UINT64_C(14695981039346656037);
constexpr std::uint64_t kFnvPrime = UINT64_C(1099511628211);
constexpr std::size_t kNoDependency = kMaxFieldNodes;

constexpr FieldParameterSpec kConstant[]{{"value", 0, 0, 1}};
constexpr FieldParameterSpec kNoise[]{
    {"scale", 64, 1, 1'048'576}, {"salt", 0, 0, 4'294'967'295.0, true},
    {"origin_x", 0, -kCoordinate, kCoordinate},
    {"origin_y", 0, -kCoordinate, kCoordinate}, {"warp", 32, 0, 4096}
};
constexpr FieldParameterSpec kFractal[]{
    {"scale", 128, 1, 1'048'576}, {"salt", 0, 0, 4'294'967'295.0, true},
    {"origin_x", 0, -kCoordinate, kCoordinate},
    {"origin_y", 0, -kCoordinate, kCoordinate}, {"warp", 32, 0, 4096},
    {"octaves", 4, 1, 6, true}, {"lacunarity", 2, 1, 4}, {"gain", 0.5, 0, 1}
};
constexpr FieldParameterSpec kCellular[]{
    {"scale", 64, 1, 1'048'576}, {"salt", 0, 0, 4'294'967'295.0, true},
    {"origin_x", 0, -kCoordinate, kCoordinate},
    {"origin_y", 0, -kCoordinate, kCoordinate}, {"warp", 32, 0, 4096},
    {"jitter", 1, 0, 1}
};
constexpr FieldParameterSpec kCurve[]{
    {"order", 8, 1, 20, true}, {"cell_size", 1, 1, 4096, true},
    {"origin_x", 0, -kCoordinate, kCoordinate, true},
    {"origin_y", 0, -kCoordinate, kCoordinate, true}
};
constexpr FieldParameterSpec kCircle[]{
    {"x", 0, -kCoordinate, kCoordinate}, {"y", 0, -kCoordinate, kCoordinate},
    {"radius", 64, 1, 1'000'000}, {"feather", 0, 0, 1'000'000}
};
constexpr FieldParameterSpec kBox[]{
    {"x", 0, -kCoordinate, kCoordinate}, {"y", 0, -kCoordinate, kCoordinate},
    {"width", 128, 1, 1'000'000}, {"height", 128, 1, 1'000'000},
    {"feather", 0, 0, 500'000}
};
constexpr FieldParameterSpec kBand[]{
    {"low", 0.25, 0, 1}, {"high", 0.75, 0, 1}, {"feather", 0, 0, 0.5}
};
constexpr FieldParameterSpec kRemap[]{{"low", 0, 0, 1}, {"high", 1, 0, 1}};
constexpr FieldParameterSpec kContext[]{
    {"low", 0, -kCoordinate, kCoordinate}, {"high", 1, -kCoordinate, kCoordinate}
};
constexpr FieldParameterSpec kMaterial[]{
    {"material", 0, 0, static_cast<double>(kMaterialDefinitions.size() - 1), true}
};
constexpr std::array<FieldKindSpec, 22> kKinds{{
    {FieldKind::Constant, "constant", 0, false, false, kConstant},
    {FieldKind::ValueNoise, "value_noise", 0, true, false, kNoise},
    {FieldKind::GradientNoise, "gradient_noise", 0, true, false, kNoise},
    {FieldKind::Fbm, "fbm", 0, true, false, kFractal},
    {FieldKind::Ridged, "ridged", 0, true, false, kFractal},
    {FieldKind::CellularDistance, "cellular_distance", 0, true, false, kCellular},
    {FieldKind::CellularGap, "cellular_gap", 0, true, false, kCellular},
    {FieldKind::Hilbert, "hilbert", 0, false, false, kCurve},
    {FieldKind::Morton, "morton", 0, false, false, kCurve},
    {FieldKind::Circle, "circle", 0, false, false, kCircle},
    {FieldKind::Box, "box", 0, false, false, kBox},
    {FieldKind::Band, "band", 1, false, false, kBand},
    {FieldKind::Remap, "remap", 1, false, false, kRemap},
    {FieldKind::Invert, "invert", 1, false, false, {}},
    {FieldKind::Add, "add", 2, false, false, {}},
    {FieldKind::Multiply, "multiply", 2, false, false, {}},
    {FieldKind::Minimum, "minimum", 2, false, false, {}},
    {FieldKind::Maximum, "maximum", 2, false, false, {}},
    {FieldKind::Mix, "mix", 3, false, false, {}},
    {FieldKind::Smoothstep, "smoothstep", 1, false, false, kRemap},
    {FieldKind::Context, "context", 0, false, true, kContext},
    {FieldKind::Material, "material", 0, false, false, kMaterial}
}};
constexpr std::array<const char*, 6> kContexts{
    "occupied", "solid", "fluid", "depth", "slope", "route"
};

[[noreturn]] void invalid(const char* message) { throw std::invalid_argument(message); }
void require(bool condition, const char* message) { if (!condition) invalid(message); }

void identifier(const std::string& id) {
    require(!id.empty() && id.size() <= 96, "field ID must have 1..96 characters");
    for (const auto c : id) require((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') || c == '_' || c == '-' || c == '.', "invalid field ID");
}

void coordinate(std::int64_t value) {
    require(value >= -kFieldCoordinateLimit && value < kFieldCoordinateLimit,
            "field coordinate is outside [-2^40,2^40)");
}

std::int64_t floor_div(std::int64_t value, std::int64_t divisor) noexcept {
    return value / divisor - static_cast<std::int64_t>(value % divisor < 0);
}

void validate_curve(FieldKind kind, std::uint32_t order) {
    require(kind == FieldKind::Hilbert || kind == FieldKind::Morton, "not a curve field kind");
    require(order >= 1 && order <= 20, "curve order must be 1..20");
}

// At each level identify the quadrant in path order, then express the remaining
// lower coordinate bits in that quadrant's orientation. A full-square reflection
// keeps every operation unsigned and in range, even for the final quadrant.
std::uint64_t encode_curve(FieldKind kind, std::uint32_t order,
                           std::uint32_t x, std::uint32_t y) noexcept {
    std::uint64_t result = 0;
    if (kind == FieldKind::Morton) {
        for (std::uint32_t bit = 0; bit < order; ++bit) {
            result |= static_cast<std::uint64_t>((x >> bit) & 1U) << (2U * bit);
            result |= static_cast<std::uint64_t>((y >> bit) & 1U) << (2U * bit + 1U);
        }
        return result;
    }
    const auto maximum = (UINT32_C(1) << order) - 1U;
    for (auto mask = UINT32_C(1) << (order - 1U); mask != 0; mask >>= 1U) {
        const auto right = static_cast<std::uint32_t>((x & mask) != 0);
        const auto upper = static_cast<std::uint32_t>((y & mask) != 0);
        const auto quadrant = right != 0 ? 3U - upper : upper;
        result = (result << 2U) | quadrant;
        if (upper == 0) {
            if (right != 0) { x = maximum - x; y = maximum - y; }
            std::swap(x, y);
        }
    }
    return result;
}

CurveAddress address_curve(FieldKind kind, std::int64_t x, std::int64_t y,
                            std::uint32_t order, std::int64_t cell_size,
                            std::int64_t origin_x, std::int64_t origin_y) noexcept {
    const auto side = INT64_C(1) << order;
    // The admitted subtraction is at most 2^41, and side*cell_size at most
    // 2^32. No signed shift, narrow intermediate product or truncating division.
    const auto gx = floor_div(x - origin_x, cell_size);
    const auto gy = floor_div(y - origin_y, cell_size);
    CurveAddress result;
    result.tile_x = floor_div(gx, side); result.tile_y = floor_div(gy, side);
    result.local_x = static_cast<std::uint32_t>(gx - result.tile_x * side);
    result.local_y = static_cast<std::uint32_t>(gy - result.tile_y * side);
    result.index = encode_curve(kind, order, result.local_x, result.local_y);
    return result;
}

std::uint64_t mix_bits(std::uint64_t v) noexcept {
    v += UINT64_C(0x9e3779b97f4a7c15);
    v = (v ^ (v >> 30U)) * UINT64_C(0xbf58476d1ce4e5b9);
    v = (v ^ (v >> 27U)) * UINT64_C(0x94d049bb133111eb);
    return v ^ (v >> 31U);
}

std::uint64_t lattice_hash(std::uint64_t seed, std::int64_t x, std::int64_t y,
                           std::uint64_t salt) noexcept {
    return mix_bits(seed ^ mix_bits(static_cast<std::uint64_t>(x)) ^
        std::rotl(mix_bits(static_cast<std::uint64_t>(y)), 27) ^ mix_bits(salt));
}

double unit(std::uint64_t bits) noexcept { return static_cast<double>(bits >> 11U) * 0x1.0p-53; }
double saturate(double v) noexcept { return std::clamp(v, 0.0, 1.0); }
double smooth(double t) noexcept { t = saturate(t); return t * t * (3.0 - 2.0 * t); }
double fade(double t) noexcept { return t * t * t * (10.0 + t * (6.0 * t - 15.0)); }
double interpolate(double a, double b, double t) noexcept {
    if (t == 0) return a;
    if (t == 1) return b;
    return a + (b - a) * t;
}

double gradient_dot(std::uint64_t hash, double x, double y) noexcept {
    constexpr std::array<std::array<double, 2>, 8> directions{{
        {{1, 0}}, {{0, 1}}, {{-1, 0}}, {{0, -1}},
        {{kInvSqrtTwo, kInvSqrtTwo}}, {{-kInvSqrtTwo, kInvSqrtTwo}},
        {{-kInvSqrtTwo, -kInvSqrtTwo}}, {{kInvSqrtTwo, -kInvSqrtTwo}}
    }};
    const auto& direction = directions[hash & 7U];
    return direction[0] * x + direction[1] * y;
}

double lattice_noise(std::uint64_t seed, double x, double y, std::uint64_t salt,
                      bool gradient) noexcept {
    const auto floor_x = std::floor(x), floor_y = std::floor(y);
    const auto ix = static_cast<std::int64_t>(floor_x), iy = static_cast<std::int64_t>(floor_y);
    const auto fx = x - floor_x, fy = y - floor_y;
    std::array<double, 4> corners{};
    for (std::int64_t cy = 0; cy < 2; ++cy) for (std::int64_t cx = 0; cx < 2; ++cx) {
        const auto hash = lattice_hash(seed, ix + cx, iy + cy, salt);
        corners[static_cast<std::size_t>(cy * 2 + cx)] = gradient ?
            gradient_dot(hash, fx - static_cast<double>(cx), fy - static_cast<double>(cy)) : unit(hash);
    }
    const auto tx = fade(fx), ty = fade(fy);
    const auto v = interpolate(interpolate(corners[0], corners[1], tx),
                               interpolate(corners[2], corners[3], tx), ty);
    // Unit-length gradients have corner dot products within +/-sqrt(2).
    // This conservative normalization does not assert a uniform distribution.
    return saturate(gradient ? 0.5 + v * (0.5 * kInvSqrtTwo) : v);
}

double cellular_noise(std::uint64_t seed, double x, double y, std::uint64_t salt,
                       double jitter, bool gap) noexcept {
    const auto floor_x = std::floor(x), floor_y = std::floor(y);
    const auto ix = static_cast<std::int64_t>(floor_x), iy = static_cast<std::int64_t>(floor_y);
    const auto fx = x - floor_x, fy = y - floor_y;
    auto nearest = std::numeric_limits<double>::infinity();
    auto second = nearest;
    // One point is confined to every unit cell. The containing point is within
    // sqrt(2), and a point in the closer x-neighbor is within sqrt(3.25)<2.
    // Every point outside this 5x5 stencil is at least 2 away. Thus both nearest
    // distances are exact for this declared lattice, including jitter==1.
    for (std::int64_t oy = -2; oy <= 2; ++oy) for (std::int64_t ox = -2; ox <= 2; ++ox) {
        const auto hash = lattice_hash(seed, ix + ox, iy + oy, salt);
        const auto px = static_cast<double>(ox) + 0.5 + jitter * (unit(hash) - 0.5);
        const auto py = static_cast<double>(oy) + 0.5 + jitter *
            (unit(mix_bits(hash ^ UINT64_C(0x541ef827af7d1501))) - 0.5);
        const auto dx = px - fx, dy = py - fy;
        const auto distance = dx * dx + dy * dy;
        if (distance < nearest) { second = nearest; nearest = distance; }
        else if (distance < second) second = distance;
    }
    const auto first_distance = std::sqrt(nearest);
    return saturate((gap ? std::sqrt(second) - first_distance : first_distance) * kInvSqrtTwo);
}

void hash_word(std::uint64_t& h, std::uint64_t value) noexcept {
    for (unsigned byte = 0; byte < 8; ++byte) { h = (h ^ (value & 255U)) * kFnvPrime; value >>= 8U; }
}
void hash_text(std::uint64_t& h, const std::string& value) noexcept {
    hash_word(h, value.size());
    for (const unsigned char c : value) h = (h ^ c) * kFnvPrime;
}

bool unit_context(double value) noexcept { return std::isfinite(value) && value >= 0 && value <= 1; }

void validate_context(const FieldContext& context) {
    require(unit_context(context.occupied) && unit_context(context.solid) &&
            unit_context(context.fluid) && unit_context(context.route),
            "field occupancy, solid, fluid and route context must be in [0,1]");
    require(std::isfinite(context.depth) && std::abs(context.depth) <= 2 * kCoordinate &&
            std::isfinite(context.slope) && context.slope >= 0 && context.slope <= 2 * kCoordinate,
            "field depth or slope context is outside its finite domain");
    require(valid_material(context.material), "field context contains an invalid material");
}

double context_value(const FieldContext& c, std::size_t index) noexcept {
    switch (index) {
        case 0: return c.occupied;
        case 1: return c.solid;
        case 2: return c.fluid;
        case 3: return c.depth;
        case 4: return c.slope;
        case 5: return c.route;
        default: return 0; // unreachable after compilation
    }
}

struct Instruction {
    FieldKind kind{};
    std::array<std::size_t, 3> inputs{};
    std::array<std::size_t, 5> dependencies{};
    std::size_t dependency_count{};
    std::size_t warp_x = kNoDependency, warp_y = kNoDependency;
    std::size_t context{};
    std::array<double, 8> parameters{};
};

std::uint64_t instruction_cost(const Instruction& instruction) noexcept {
    const auto& p = instruction.parameters;
    std::uint64_t cost = 8;
    switch (instruction.kind) {
        case FieldKind::ValueNoise: cost = 128; break;
        case FieldKind::GradientNoise: cost = 160; break;
        case FieldKind::Fbm: cost = 32 + 160 * static_cast<std::uint64_t>(p[5]); break;
        case FieldKind::Ridged: cost = 32 + 168 * static_cast<std::uint64_t>(p[5]); break;
        case FieldKind::CellularDistance: case FieldKind::CellularGap: cost = 1432; break;
        case FieldKind::Hilbert: case FieldKind::Morton: cost = 32 + 16 * static_cast<std::uint64_t>(p[0]); break;
        case FieldKind::Circle: cost = 48; break;
        case FieldKind::Box: cost = 40; break;
        case FieldKind::Band: cost = 24; break;
        case FieldKind::Remap: case FieldKind::Smoothstep: case FieldKind::Context: cost = 16; break;
        default: break;
    }
    if (instruction.warp_x != kNoDependency) cost += 8;
    if (instruction.warp_y != kNoDependency) cost += 8;
    return cost;
}

double evaluate_instruction(const Instruction& instruction, std::uint64_t seed,
                              std::int64_t x, std::int64_t y, const FieldContext& context,
                              const FieldValues& fields) noexcept {
    const auto& p = instruction.parameters;
    const auto input = [&](std::size_t index) { return fields.values[instruction.inputs[index]]; };
    if (instruction.kind >= FieldKind::ValueNoise && instruction.kind <= FieldKind::CellularGap) {
        auto dx = static_cast<double>(x) - p[2], dy = static_cast<double>(y) - p[3];
        if (instruction.warp_x != kNoDependency) dx += p[4] * (2 * fields.values[instruction.warp_x] - 1);
        if (instruction.warp_y != kNoDependency) dy += p[4] * (2 * fields.values[instruction.warp_y] - 1);
        dx /= p[0]; dy /= p[0];
        const auto salt = static_cast<std::uint64_t>(p[1]);
        if (instruction.kind == FieldKind::ValueNoise) return lattice_noise(seed, dx, dy, salt, false);
        if (instruction.kind == FieldKind::GradientNoise) return lattice_noise(seed, dx, dy, salt, true);
        if (instruction.kind == FieldKind::CellularDistance || instruction.kind == FieldKind::CellularGap)
            return cellular_noise(seed, dx, dy, salt, p[5], instruction.kind == FieldKind::CellularGap);
        double sum = 0, total_weight = 0, weight = 1;
        const auto octaves = static_cast<std::uint32_t>(p[5]);
        for (std::uint32_t octave = 0; octave < octaves; ++octave) {
            auto v = lattice_noise(seed, dx, dy, salt + UINT64_C(0x9e3779b97f4a7c15) * octave, true);
            if (instruction.kind == FieldKind::Ridged) v = 1 - std::abs(2 * v - 1);
            sum += weight * v; total_weight += weight;
            weight *= p[7]; dx *= p[6]; dy *= p[6];
        }
        return saturate(sum / total_weight);
    }
    switch (instruction.kind) {
        case FieldKind::Constant: return p[0];
        case FieldKind::Hilbert: case FieldKind::Morton: {
            const auto order = static_cast<std::uint32_t>(p[0]);
            const auto address = address_curve(instruction.kind, x, y, order,
                static_cast<std::int64_t>(p[1]), static_cast<std::int64_t>(p[2]), static_cast<std::int64_t>(p[3]));
            return static_cast<double>(address.index) /
                static_cast<double>((UINT64_C(1) << (2U * order)) - 1U);
        }
        case FieldKind::Circle: {
            const auto dx = static_cast<double>(x) - p[0], dy = static_cast<double>(y) - p[1];
            const auto distance = std::sqrt(dx * dx + dy * dy);
            if (distance >= p[2]) return 0;
            return p[3] == 0 ? 1 : smooth((p[2] - distance) / p[3]);
        }
        case FieldKind::Box: {
            const auto dx = static_cast<double>(x) - p[0], dy = static_cast<double>(y) - p[1];
            if (dx < 0 || dx >= p[2] || dy < 0 || dy >= p[3]) return 0;
            return p[4] == 0 ? 1 : smooth(std::min({dx, dy, p[2] - dx, p[3] - dy}) / p[4]);
        }
        case FieldKind::Band: {
            const auto v = input(0);
            if (v < p[0] || v > p[1]) return 0;
            return p[2] == 0 ? 1 : smooth(std::min(v - p[0], p[1] - v) / p[2]);
        }
        case FieldKind::Remap: return saturate((input(0) - p[0]) / (p[1] - p[0]));
        case FieldKind::Invert: return 1 - input(0);
        case FieldKind::Add: return saturate(input(0) + input(1));
        case FieldKind::Multiply: return input(0) * input(1);
        case FieldKind::Minimum: return std::min(input(0), input(1));
        case FieldKind::Maximum: return std::max(input(0), input(1));
        case FieldKind::Mix: return interpolate(input(0), input(1), input(2));
        case FieldKind::Smoothstep: return smooth((input(0) - p[0]) / (p[1] - p[0]));
        case FieldKind::Context: return saturate((context_value(context, instruction.context) - p[0]) / (p[1] - p[0]));
        case FieldKind::Material: return context.material == static_cast<std::uint16_t>(p[0]) ? 1 : 0;
        default: return 0; // noise cases above; unknown kinds cannot compile
    }
}

} // namespace

std::span<const FieldKindSpec> field_kind_specs() noexcept { return kKinds; }
const FieldKindSpec& field_kind_spec(FieldKind kind) {
    const auto index = static_cast<std::size_t>(kind);
    require(index < kKinds.size() && kKinds[index].kind == kind, "unknown field kind");
    return kKinds[index];
}
const char* field_kind_name(FieldKind kind) noexcept {
    const auto index = static_cast<std::size_t>(kind);
    return index < kKinds.size() ? kKinds[index].name : "unknown";
}
std::optional<FieldKind> parse_field_kind(const std::string& name) noexcept {
    for (const auto& spec : kKinds) if (name == spec.name) return spec.kind;
    return std::nullopt;
}
std::span<const char* const> field_context_names() noexcept { return kContexts; }

std::uint64_t curve_index(FieldKind kind, std::uint32_t order, std::uint32_t x, std::uint32_t y) {
    validate_curve(kind, order);
    const auto side = UINT32_C(1) << order;
    require(x < side && y < side, "curve coordinate is outside its tile");
    return encode_curve(kind, order, x, y);
}

CurvePoint curve_point(FieldKind kind, std::uint32_t order, std::uint64_t index) {
    validate_curve(kind, order);
    require(index < (UINT64_C(1) << (2U * order)), "curve index is outside its tile");
    CurvePoint point;
    if (kind == FieldKind::Morton) {
        for (std::uint32_t bit = 0; bit < order; ++bit) {
            point.x |= static_cast<std::uint32_t>((index >> (2U * bit)) & 1U) << bit;
            point.y |= static_cast<std::uint32_t>((index >> (2U * bit + 1U)) & 1U) << bit;
        }
        return point;
    }
    // Construct oriented child squares from the innermost base-four digit.
    for (std::uint32_t level = 0; level < order; ++level) {
        const auto side = UINT32_C(1) << level;
        const auto quadrant = static_cast<std::uint32_t>(index & 3U);
        if (quadrant == 0 || quadrant == 3) {
            if (quadrant == 3) { point.x = side - 1U - point.x; point.y = side - 1U - point.y; }
            std::swap(point.x, point.y);
        }
        if (quadrant >= 2) point.x += side;
        if (quadrant == 1 || quadrant == 2) point.y += side;
        index >>= 2U;
    }
    return point;
}

CurveAddress curve_address(FieldKind kind, std::int64_t x, std::int64_t y,
                            std::uint32_t order, std::int64_t cell_size,
                            std::int64_t origin_x, std::int64_t origin_y) {
    validate_curve(kind, order); coordinate(x); coordinate(y);
    require(cell_size >= 1 && cell_size <= 4096, "curve cell_size must be 1..4096");
    require(origin_x >= -kFieldCoordinateLimit && origin_x <= kFieldCoordinateLimit &&
            origin_y >= -kFieldCoordinateLimit && origin_y <= kFieldCoordinateLimit,
            "curve origin is outside its admitted domain");
    return address_curve(kind, x, y, order, cell_size, origin_x, origin_y);
}

struct FieldGraph::Impl {
    std::vector<FieldNode> nodes;
    std::vector<Instruction> instructions;
    std::vector<std::size_t> order;
    std::uint64_t seed{};
    std::uint64_t fingerprint = kFnvOffset;
    std::uint64_t cost{};
};

std::shared_ptr<const FieldGraph> FieldGraph::compile(std::vector<FieldNode> nodes,
                                                     std::uint64_t seed, FieldLimits limits) {
    require(limits.max_nodes <= kMaxFieldNodes && limits.max_depth >= 1 &&
            limits.max_depth <= kMaxFieldDepth && limits.max_operations_per_sample >= 1 &&
            limits.max_operations_per_sample <= kMaxFieldOperations, "invalid field limits");
    require(nodes.size() <= limits.max_nodes, "field node capacity exceeded");
    std::sort(nodes.begin(), nodes.end(), [](const auto& a, const auto& b) { return a.id < b.id; });
    auto impl = std::make_unique<Impl>();
    impl->seed = seed; impl->instructions.resize(nodes.size()); impl->order.reserve(nodes.size());
    for (std::size_t n = 0; n < nodes.size(); ++n) {
        auto& node = nodes[n]; identifier(node.id);
        require(n == 0 || nodes[n - 1].id != node.id, "duplicate field ID");
        const auto& spec = field_kind_spec(node.kind);
        require(node.inputs.size() == spec.input_count, "incorrect field input arity");
        require(spec.supports_warp || (node.warp_x.empty() && node.warp_y.empty()), "this field kind does not accept warp inputs");
        require(spec.requires_context || node.context.empty(), "this field kind does not accept a context channel");
        auto& instruction = impl->instructions[n]; instruction.kind = node.kind;
        if (spec.requires_context) {
            const auto found = std::find(kContexts.begin(), kContexts.end(), node.context);
            require(found != kContexts.end(), "unknown field context channel");
            instruction.context = static_cast<std::size_t>(found - kContexts.begin());
        }
        require(node.parameters.size() <= spec.parameters.size(), "unknown or excessive field parameters");
        for (const auto& [name, value] : node.parameters) {
            (void)value;
            require(std::any_of(spec.parameters.begin(), spec.parameters.end(), [&](const auto& parameter) {
                return name == parameter.name;
            }), "unknown field parameter");
        }
        for (std::size_t p = 0; p < spec.parameters.size(); ++p) {
            const auto& parameter = spec.parameters[p];
            auto [it, inserted] = node.parameters.try_emplace(parameter.name, parameter.default_value);
            (void)inserted;
            auto& value = it->second;
            require(std::isfinite(value) && value >= parameter.minimum && value <= parameter.maximum &&
                    (!parameter.integer || std::floor(value) == value), "field parameter is outside its domain");
            if (value == 0) value = 0; // canonicalize negative zero
            instruction.parameters[p] = value;
        }
        const auto& p = instruction.parameters;
        if (node.kind == FieldKind::Circle) require(p[3] <= p[2], "circle feather exceeds radius");
        if (node.kind == FieldKind::Box) require(p[4] <= std::min(p[2], p[3]) * 0.5, "box feather exceeds half its smaller dimension");
        if (node.kind == FieldKind::Band || node.kind == FieldKind::Remap || node.kind == FieldKind::Smoothstep || node.kind == FieldKind::Context)
            require(p[0] < p[1], "field low must be smaller than high");
        if (node.kind == FieldKind::Band) require(p[2] <= (p[1] - p[0]) * 0.5, "band feather exceeds half its interval");
        if (node.kind == FieldKind::Material) require(valid_material(static_cast<std::uint16_t>(p[0])), "invalid field material ID");
    }
    const auto resolve = [&](const std::string& id) {
        identifier(id);
        const auto found = std::lower_bound(nodes.begin(), nodes.end(), id,
            [](const auto& node, const auto& name) { return node.id < name; });
        require(found != nodes.end() && found->id == id, "unknown field dependency");
        return static_cast<std::size_t>(found - nodes.begin());
    };
    for (std::size_t n = 0; n < nodes.size(); ++n) {
        auto& instruction = impl->instructions[n];
        const auto dependency = [&](const std::string& id) {
            const auto index = resolve(id);
            require(index != n, "self field dependency");
            instruction.dependencies[instruction.dependency_count++] = index;
            return index;
        };
        for (std::size_t i = 0; i < nodes[n].inputs.size(); ++i) instruction.inputs[i] = dependency(nodes[n].inputs[i]);
        if (!nodes[n].warp_x.empty()) instruction.warp_x = dependency(nodes[n].warp_x);
        if (!nodes[n].warp_y.empty()) instruction.warp_y = dependency(nodes[n].warp_y);
        const auto cost = instruction_cost(instruction);
        require(cost <= limits.max_operations_per_sample - impl->cost, "field operation capacity exceeded");
        impl->cost += cost;
    }
    std::array<bool, kMaxFieldNodes> emitted{};
    std::array<std::size_t, kMaxFieldNodes> depths{};
    while (impl->order.size() < nodes.size()) {
        auto next = nodes.size();
        for (std::size_t n = 0; n < nodes.size(); ++n) {
            if (emitted[n]) continue;
            const auto& instruction = impl->instructions[n];
            bool ready = true;
            for (std::size_t d = 0; d < instruction.dependency_count; ++d)
                ready = ready && emitted[instruction.dependencies[d]];
            if (ready) { next = n; break; }
        }
        require(next != nodes.size(), "cyclic field dependencies");
        const auto& instruction = impl->instructions[next];
        auto depth = std::size_t{1};
        for (std::size_t d = 0; d < instruction.dependency_count; ++d)
            depth = std::max(depth, depths[instruction.dependencies[d]] + 1);
        require(depth <= limits.max_depth, "field dependency depth exceeded");
        depths[next] = depth; emitted[next] = true; impl->order.push_back(next);
    }
    auto& h = impl->fingerprint;
    hash_word(h, kFieldAlgorithmVersion); hash_word(h, seed); hash_word(h, nodes.size());
    for (const auto& node : nodes) {
        hash_text(h, node.id); hash_word(h, static_cast<std::uint64_t>(node.kind));
        hash_word(h, node.inputs.size()); for (const auto& input : node.inputs) hash_text(h, input);
        hash_text(h, node.warp_x); hash_text(h, node.warp_y); hash_text(h, node.context);
        hash_word(h, node.parameters.size());
        for (const auto& [name, value] : node.parameters) {
            hash_text(h, name); hash_word(h, std::bit_cast<std::uint64_t>(value));
        }
    }
    hash_word(h, limits.max_nodes); hash_word(h, limits.max_depth);
    hash_word(h, limits.max_operations_per_sample); hash_word(h, impl->cost);
    impl->nodes = std::move(nodes);
    return std::shared_ptr<const FieldGraph>(new FieldGraph(std::move(impl)));
}

FieldGraph::FieldGraph(std::unique_ptr<Impl> impl) : impl_(std::move(impl)) {}
FieldGraph::~FieldGraph() = default;
const std::vector<FieldNode>& FieldGraph::nodes() const noexcept { return impl_->nodes; }
std::size_t FieldGraph::index(const std::string& id) const {
    const auto found = std::lower_bound(impl_->nodes.begin(), impl_->nodes.end(), id,
        [](const auto& node, const auto& name) { return node.id < name; });
    require(found != impl_->nodes.end() && found->id == id, "unknown field output ID");
    return static_cast<std::size_t>(found - impl_->nodes.begin());
}
std::uint64_t FieldGraph::fingerprint() const noexcept { return impl_->fingerprint; }
std::uint64_t FieldGraph::operations_per_sample() const noexcept { return impl_->cost; }
void FieldGraph::evaluate(std::int64_t x, std::int64_t y, const FieldContext& context,
                          FieldValues& output) const {
    coordinate(x); coordinate(y); validate_context(context);
    FieldValues result; result.size = impl_->nodes.size();
    for (const auto index : impl_->order) {
        const auto value = evaluate_instruction(impl_->instructions[index], impl_->seed, x, y, context, result);
        if (!std::isfinite(value)) throw std::runtime_error("field evaluation produced a non-finite value");
        result.values[index] = saturate(value);
    }
    output = result;
}

} // namespace cybersand::generation
