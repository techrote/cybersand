#include "cybersand/generation_typed_fields.hpp"
#include "cybersand/generation_numeric.hpp"

#include <algorithm>
#include <bit>
#include <cmath>
#include <functional>
#include <limits>
#include <numbers>
#include <set>
#include <stdexcept>
#include <utility>

namespace cybersand::generation {
namespace {
constexpr double C = spatial::kSampleCoordinateLimit;
constexpr double B = 1e100;
constexpr std::uint64_t FNV = UINT64_C(14695981039346656037);
constexpr FieldParameterSpec circle[]{{"x", 0, -C, C}, {"y", 0, -C, C}, {"radius", 64, 0.0001, 1'000'000}};
constexpr FieldParameterSpec box[]{
    {"x", 0, -C, C}, {"y", 0, -C, C}, {"width", 128, 0.0001, 1'000'000}, {"height", 128, 0.0001, 1'000'000}};
constexpr FieldParameterSpec noise[]{{"scale", 64, 1, 1'048'576}, {"salt", 0, 0, 4294967295.0, true}};
constexpr FieldParameterSpec mask[]{{"low", 0, -B, B}, {"high", 1, -B, B}};
constexpr FieldParameterSpec transform[]{
    {"tx", 0, -1'000'000, 1'000'000}, {"ty", 0, -1'000'000, 1'000'000}, {"angle", 0, -1000, 1000},
    {"sx", 1, -10000, 10000},         {"sy", 1, -10000, 10000},         {"shear_x", 0, -100, 100},
    {"shear_y", 0, -100, 100},        {"origin_x", 0, -C, C},           {"origin_y", 0, -C, C}};
constexpr FieldParameterSpec polar[]{{"origin_x", 0, -C, C},
                                     {"origin_y", 0, -C, C},
                                     {"radial_scale", 1, 0.0001, 1'000'000},
                                     {"angular_scale", 1, 0.0001, 1'000'000},
                                     {"min_radius", 0.0001, 0.0001, 1'000'000}};
constexpr FieldParameterSpec repeat[]{{"period_x", 64, 0.0001, 1'000'000},
                                      {"period_y", 64, 0.0001, 1'000'000},
                                      {"origin_x", 0, -C, C},
                                      {"origin_y", 0, -C, C}};
constexpr FieldParameterSpec warp[]{{"max_displacement", 32, 0, 4096}};
constexpr FieldParameterSpec derivative[]{{"spacing", 1, 1, 64}};
constexpr FieldParameterSpec peano[]{{"order", 4, 1, 12, true},
                                     {"cell_size", 1, 1, 4096, true},
                                     {"origin_x", 0, -C, C},
                                     {"origin_y", 0, -C, C}};
constexpr FieldParameterSpec lattice[]{
    {"spacing", 64, 1, 1'048'576}, {"jitter", 1, 0, 1}, {"salt", 0, 0, 4294967295.0, true}};
constexpr FieldParameterSpec poisson[]{{"spacing", 64, 1, 1'048'576},
                                       {"jitter", 1, 0, 1},
                                       {"salt", 0, 0, 4294967295.0, true},
                                       {"radius", 32, 0.0001, 2'097'152},
                                       {"search_cells", 2, 1, 4, true}};
constexpr SpatialKindSpec kinds[]{{SpatialKind::Constant, "constant", 0, {}},
                                  {SpatialKind::Parameter, "parameter", 0, {}},
                                  {SpatialKind::Identity, "identity", 1, {}},
                                  {SpatialKind::Position, "position", 0, {}},
                                  {SpatialKind::CoordinateX, "coordinate_x", 0, {}},
                                  {SpatialKind::CoordinateY, "coordinate_y", 0, {}},
                                  {SpatialKind::CircleDistance, "circle_distance", 0, circle},
                                  {SpatialKind::BoxDistance, "box_distance", 0, box},
                                  {SpatialKind::Noise, "noise", 0, noise},
                                  {SpatialKind::Add, "add", 2, {}},
                                  {SpatialKind::Subtract, "subtract", 2, {}},
                                  {SpatialKind::Multiply, "multiply", 2, {}},
                                  {SpatialKind::Minimum, "minimum", 2, {}},
                                  {SpatialKind::Maximum, "maximum", 2, {}},
                                  {SpatialKind::Mix, "mix", 3, {}},
                                  {SpatialKind::ToMask, "to_mask", 1, mask},
                                  {SpatialKind::ComposeVector, "compose_vector", 2, {}},
                                  {SpatialKind::ComponentX, "component_x", 1, {}},
                                  {SpatialKind::ComponentY, "component_y", 1, {}},
                                  {SpatialKind::Length, "length", 1, {}},
                                  {SpatialKind::UnitVector, "unit_vector", 1, {}},
                                  {SpatialKind::Dot, "dot", 2, {}},
                                  {SpatialKind::Equal, "equal", 2, {}},
                                  {SpatialKind::Less, "less", 2, {}},
                                  {SpatialKind::Select, "select", 3, {}},
                                  {SpatialKind::Transform, "transform", 1, transform},
                                  {SpatialKind::TransformVector, "transform_vector", 1, transform},
                                  {SpatialKind::Polar, "polar", 1, polar},
                                  {SpatialKind::LogPolar, "log_polar", 1, polar},
                                  {SpatialKind::Repeat, "repeat", 1, repeat},
                                  {SpatialKind::Mirror, "mirror", 1, repeat},
                                  {SpatialKind::Warp, "warp", 2, warp},
                                  {SpatialKind::Gradient, "gradient", 1, derivative},
                                  {SpatialKind::Slope, "slope", 1, derivative},
                                  {SpatialKind::Aspect, "aspect", 1, derivative},
                                  {SpatialKind::Divergence, "divergence", 1, derivative},
                                  {SpatialKind::Curl, "curl", 1, derivative},
                                  {SpatialKind::Ridge, "ridge", 1, derivative},
                                  {SpatialKind::Valley, "valley", 1, derivative},
                                  {SpatialKind::LocalMinimum, "local_minimum", 1, derivative},
                                  {SpatialKind::LocalMaximum, "local_maximum", 1, derivative},
                                  {SpatialKind::Curvature, "curvature", 1, derivative},
                                  {SpatialKind::Peano, "peano", 0, peano},
                                  {SpatialKind::VoronoiRegion, "voronoi_region", 0, lattice},
                                  {SpatialKind::VoronoiDistance, "voronoi_distance", 0, lattice},
                                  {SpatialKind::VoronoiBoundary, "voronoi_boundary", 0, lattice},
                                  {SpatialKind::DelaunayDegree, "delaunay_degree", 0, lattice},
                                  {SpatialKind::PoissonDistance, "poisson_distance", 0, poisson},
                                  {SpatialKind::PoissonRegion, "poisson_region", 0, poisson},
                                  {SpatialKind::PoissonFound, "poisson_found", 0, poisson},
                                  {SpatialKind::GeometryDistance, "geometry_distance", 0, {}},
                                  {SpatialKind::AssignedRegion, "assigned_region", 0, {}},
                                  {SpatialKind::CategoryIs, "category_is", 1, {}}};
constexpr const char *type_names[]{"normalized", "scalar",   "signed_distance", "distance",
                                   "vector2",    "category", "boolean"};
void need(bool ok, const char *message) {
    if (!ok)
        throw std::invalid_argument(std::string("spatial: ") + message);
}
void need(bool ok, const std::string &message) {
    if (!ok)
        throw std::invalid_argument("spatial: " + message);
}
void id(const std::string &name) {
    need(!name.empty() && name.size() <= 64, "local ID must have 1..64 characters");
    for (char c : name)
        need((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' ||
                 c == '-',
             "invalid local ID (dot is reserved for namespaces): " + name);
}
void word(std::uint64_t &h, std::uint64_t v) noexcept {
    for (unsigned i = 0; i < 8; ++i) {
        h ^= (v >> (8 * i)) & 255U;
        h *= UINT64_C(1099511628211);
    }
}
void text_hash(std::uint64_t &h, const std::string &s) noexcept {
    word(h, s.size());
    for (unsigned char c : s) {
        h ^= c;
        h *= UINT64_C(1099511628211);
    }
}
std::uint64_t bits(double x) noexcept {
    return std::bit_cast<std::uint64_t>(x == 0 ? 0.0 : x);
}
std::uint64_t mixed(std::uint64_t v) noexcept {
    v += UINT64_C(0x9e3779b97f4a7c15);
    v = (v ^ (v >> 30)) * UINT64_C(0xbf58476d1ce4e5b9);
    v = (v ^ (v >> 27)) * UINT64_C(0x94d049bb133111eb);
    return v ^ (v >> 31);
}
void value_hash(std::uint64_t &h, const SpatialValue &v) {
    word(h, static_cast<unsigned>(v.type));
    word(h, bits(v.x));
    word(h, bits(v.y));
    word(h, static_cast<std::uint64_t>(v.category.x));
    word(h, static_cast<std::uint64_t>(v.category.y));
    word(h, v.category.domain);
}
bool scalar(SpatialType t) noexcept {
    return t == SpatialType::Scalar || t == SpatialType::Normalized || t == SpatialType::Distance ||
           t == SpatialType::SignedDistance;
}
bool continuous(SpatialType t) noexcept {
    return scalar(t) || t == SpatialType::Vector2;
}
void valid_value(const SpatialValue &v) {
    need(static_cast<unsigned>(v.type) < std::size(type_names), "unknown value type");
    need(std::isfinite(v.x) && std::isfinite(v.y) && std::abs(v.x) <= B && std::abs(v.y) <= B,
         "nonfinite/out-of-range typed value");
    if (v.type == SpatialType::Normalized)
        need(v.x >= 0 && v.x <= 1, "normalized value outside [0,1]");
    if (v.type == SpatialType::Boolean)
        need(v.x == 0 || v.x == 1, "boolean value must be exactly zero or one");
    if (v.type == SpatialType::Distance)
        need(v.x >= 0, "distance must be nonnegative");
    if (v.type != SpatialType::Vector2)
        need(v.y == 0, "non-vector value has a y component");
    if (v.type == SpatialType::Category)
        need(v.x == 0, "category must not be encoded as a floating-point value");
    else
        need(v.category == SpatialCategory{}, "non-category value has a category payload");
}
SpatialValue number(SpatialType type, double x, double y = 0) noexcept {
    SpatialValue v;
    v.type = type;
    v.x = x == 0 ? 0 : x;
    v.y = y == 0 ? 0 : y;
    return v;
}
double lerp(double a, double b, double t) noexcept {
    return t == 0 ? a : (t == 1 ? b : a + (b - a) * t);
}
void sample_coordinate(double x, double y) {
    if (!std::isfinite(x) || !std::isfinite(y) || std::abs(x) > C || std::abs(y) > C)
        throw std::out_of_range("spatial sampling footprint exceeds +/-2^44 cells");
}
std::uint64_t add_cost(std::uint64_t a, std::uint64_t b, std::uint64_t limit, const char *reason) {
    need(a <= limit && b <= limit - a, reason);
    return a + b;
}

struct Expanded {
    std::vector<SpatialNode> nodes;
    std::map<std::string, std::uint64_t> seeds;
    std::map<std::string, std::map<std::string, std::int32_t>> binding_units;
};
struct Expansion {
    const SpatialDefinition &def;
    std::uint64_t seed;
    std::size_t capacity;
    std::uint64_t &preparation;
    std::uint64_t preparation_limit;
    mutable std::size_t expansion_calls = 0;
    std::map<std::string, const SpatialSubgraph *> templates;
    Expansion(const SpatialDefinition &d, std::uint64_t s, std::size_t cap, std::uint64_t &work,
              std::uint64_t max_work)
        : def(d), seed(s), capacity(cap), preparation(work), preparation_limit(max_work) {
        need(def.subgraphs.size() <= 16 && def.instances.size() <= 16, "too many subgraphs or instances");
        for (const auto &t : def.subgraphs) {
            id(t.id);
            need(templates.emplace(t.id, &t).second, "duplicate subgraph ID: " + t.id);
        }
    }
    void append(Expanded &out, SpatialNode node, const std::string &prefix) const {
        need(out.nodes.size() < capacity, "expanded node capacity exceeded");
        preparation =
            add_cost(preparation, 8192, preparation_limit, "expanded node preparation work exhausted");
        std::uint64_t h = seed;
        text_hash(h, prefix);
        out.seeds[node.id] = h;
        out.nodes.push_back(std::move(node));
    }
    void instance(Expanded &out, const SpatialInstance &inst, const std::string &prefix,
                  const std::map<std::string, SpatialValue> &enclosing, std::vector<std::string> &stack,
                  bool validation) const {
        need(++expansion_calls <= 1024, "subgraph instance expansion capacity exceeded");
        preparation = add_cost(preparation, 512, preparation_limit, "subgraph expansion work exhausted");
        need(inst.bindings.size() + inst.parameter_bindings.size() <= 16, "too many parameter bindings");
        id(inst.id);
        auto it = templates.find(inst.subgraph);
        need(it != templates.end(), "unknown subgraph: " + inst.subgraph);
        need(stack.size() < 8, "subgraph expansion depth exceeded");
        need(std::find(stack.begin(), stack.end(), inst.subgraph) == stack.end(),
             "recursive subgraph: " + inst.subgraph);
        stack.push_back(inst.subgraph);
        const auto &t = *it->second;
        const auto path = prefix + inst.id + ".";
        need(t.parameters.size() <= 16 && t.nodes.size() <= capacity && t.instances.size() <= 16 &&
                 t.outputs.size() <= 16,
             "subgraph declaration capacity exceeded");
        auto bound = inst.bindings;
        need(bound.size() + inst.parameter_bindings.size() <= 16, "too many parameter bindings");
        for (const auto &[key, outer] : inst.parameter_bindings) {
            need(!bound.contains(key), "duplicate literal/reference parameter binding");
            auto p = enclosing.find(outer);
            need(p != enclosing.end() || validation, "unknown enclosing parameter: " + outer);
            if (p != enclosing.end())
                bound[key] = p->second;
        }
        std::map<std::string, const SpatialParameter *> declarations;
        for (const auto &p : t.parameters) {
            id(p.id);
            need(declarations.emplace(p.id, &p).second, "duplicate subgraph parameter");
            need(static_cast<unsigned>(p.type) < std::size(type_names), "invalid parameter type");
            need(p.unit_power >= -8 && p.unit_power <= 8, "invalid parameter units");
            need((p.type != SpatialType::Normalized && p.type != SpatialType::Boolean &&
                  p.type != SpatialType::Category) ||
                     p.unit_power == 0,
                 "dimensionless parameter has nonzero units");
            if (p.default_value) {
                valid_value(*p.default_value);
                need(p.default_value->type == p.type, "parameter default type mismatch");
            }
            auto b = bound.find(p.id);
            if (b == bound.end() && p.default_value)
                bound[p.id] = *p.default_value;
            else
                need(b != bound.end() || validation, "missing binding: " + path + p.id);
        }
        for (const auto &[key, v] : bound) {
            auto p = declarations.find(key);
            need(p != declarations.end(), "unknown parameter binding: " + key);
            valid_value(v);
            need(v.type == p->second->type, "parameter binding type mismatch: " + key);
        }
        std::set<std::string> locals;
        for (auto n : t.nodes) {
            id(n.id);
            need(locals.insert(n.id).second, "namespace collision: " + path + n.id);
            n.id = path + n.id;
            for (auto &input : n.inputs)
                input = path + input;
            if (n.kind == SpatialKind::Parameter) {
                need(n.value == SpatialValue{} && n.unit_power == 0 && n.inputs.empty() &&
                         n.parameters.empty() && n.parameter_bindings.empty(),
                     "parameter node contains ignored declarations");
                auto p = declarations.find(n.reference);
                need(p != declarations.end(), "unknown parameter node reference: " + n.reference);
                auto b = bound.find(n.reference);
                n.kind = SpatialKind::Constant;
                n.value = b == bound.end() ? SpatialValue{p->second->type} : b->second;
                n.unit_power = p->second->unit_power;
                n.reference.clear();
            }
            for (const auto &[key, param] : n.parameter_bindings) {
                auto p = declarations.find(param);
                need(p != declarations.end() && scalar(p->second->type),
                     "numeric parameter binding needs scalar parameter");
                need(!n.parameters.contains(key), "numeric binding collides with literal parameter");
                out.binding_units[n.id][key] = p->second->unit_power;
                auto b = bound.find(param);
                if (b != bound.end())
                    n.parameters[key] = b->second.x;
                else {
                    const auto &spec = spatial_kind_spec(n.kind);
                    auto ps = std::find_if(spec.parameters.begin(), spec.parameters.end(),
                                           [&](const auto &v) { return key == v.name; });
                    need(ps != spec.parameters.end(), "unknown bound numeric parameter: " + key);
                    n.parameters[key] = ps->default_value;
                }
            }
            n.parameter_bindings.clear();
            append(out, std::move(n), path);
        }
        for (const auto &child : t.instances) {
            need(locals.insert(child.id).second, "instance/node namespace collision");
            for (const auto &[key, param] : child.parameter_bindings) {
                need(declarations.contains(param), "unknown outer parameter binding");
                auto child_template = templates.find(child.subgraph);
                need(child_template != templates.end(), "unknown nested subgraph");
                auto child_param = std::find_if(child_template->second->parameters.begin(),
                                                child_template->second->parameters.end(),
                                                [&](const auto &cp) { return cp.id == key; });
                need(child_param != child_template->second->parameters.end(), "unknown nested parameter");
                need(child_param->type == declarations.at(param)->type &&
                         child_param->unit_power == declarations.at(param)->unit_power,
                     "forwarded parameter type/units mismatch");
            }
            instance(out, child, path, bound, stack, validation);
        }
        for (const auto &[name, target] : t.outputs) {
            id(name);
            need(!target.empty(), "empty subgraph output");
            const auto full = path + name;
            const auto source = path + target;
            if (full == source) {
                need(std::any_of(out.nodes.begin(), out.nodes.end(),
                                 [&](const auto &output) { return output.id == source; }),
                     "missing subgraph output: " + source);
                continue;
            }
            need(!locals.contains(name), "output namespace collision: " + full);
            SpatialNode alias;
            alias.id = full;
            alias.kind = SpatialKind::Identity;
            alias.inputs = {source};
            append(out, std::move(alias), path);
        }
        stack.pop_back();
    }
    Expanded actual() const {
        Expanded out;
        std::set<std::string> used;
        for (auto n : def.nodes) {
            id(n.id);
            need(used.insert(n.id).second, "duplicate spatial node ID");
            need(n.parameter_bindings.empty(), "top-level node cannot reference subgraph parameters");
            append(out, std::move(n), "");
        }
        std::vector<std::string> stack;
        for (const auto &inst : def.instances) {
            need(used.insert(inst.id).second, "instance/node namespace collision");
            need(inst.parameter_bindings.empty(), "top-level instance cannot reference enclosing parameters");
            instance(out, inst, "", {}, stack, false);
        }
        return out;
    }
};
struct Instruction {
    SpatialKind kind{};
    std::array<std::size_t, 3> inputs{};
    std::array<double, 10> p{};
    std::array<double, 4> matrix{}, inverse{};
    SpatialValue value{};
    SpatialInfo info{};
    std::uint64_t seed{}, domain{};
    std::size_t object{};
};
} // namespace

const char *spatial_type_name(SpatialType t) noexcept {
    const auto i = static_cast<std::size_t>(t);
    return i < std::size(type_names) ? type_names[i] : "unknown";
}
std::optional<SpatialType> parse_spatial_type(const std::string &s) noexcept {
    for (std::size_t i = 0; i < std::size(type_names); ++i)
        if (s == type_names[i])
            return static_cast<SpatialType>(i);
    return {};
}
std::span<const SpatialKindSpec> spatial_kind_specs() noexcept {
    return kinds;
}
const SpatialKindSpec &spatial_kind_spec(SpatialKind k) {
    const auto i = static_cast<std::size_t>(k);
    need(i < std::size(kinds) && kinds[i].kind == k, "unknown operator kind");
    return kinds[i];
}
std::optional<SpatialKind> parse_spatial_kind(const std::string &s) noexcept {
    for (const auto &k : kinds)
        if (s == k.name)
            return k.kind;
    return {};
}

struct SpatialGraph::Impl {
    std::vector<SpatialNode> nodes;
    std::vector<Instruction> instructions;
    std::vector<std::shared_ptr<const spatial::PreparedGeometry>> geometries;
    std::vector<std::shared_ptr<const spatial::PreparedRegions>> assignments;
    SpatialLimits limits;
    std::uint64_t fingerprint = FNV, cost{}, preparation{};
    std::size_t storage{};
    void compile_nodes(Expanded expanded);
    SpatialValue evaluate(std::size_t index, double x, double y, SpatialScratch *scratch) const;
    SpatialValue raw(std::size_t index, double x, double y, SpatialScratch *scratch) const;
};

void SpatialGraph::Impl::compile_nodes(Expanded expanded) {
    nodes = std::move(expanded.nodes);
    std::sort(nodes.begin(), nodes.end(), [](const auto &a, const auto &b) { return a.id < b.id; });
    need(nodes.size() <= limits.max_nodes, "expanded node count exceeds configured limit");
    instructions.resize(nodes.size());
    const auto resolve = [&](const std::string &name) {
        auto it = std::lower_bound(nodes.begin(), nodes.end(), name,
                                   [](const auto &n, const auto &v) { return n.id < v; });
        need(it != nodes.end() && it->id == name, "unknown node dependency: " + name);
        return static_cast<std::size_t>(it - nodes.begin());
    };
    for (std::size_t i = 0; i < nodes.size(); ++i) {
        auto &n = nodes[i];
        auto &op = instructions[i];
        need(i == 0 || nodes[i - 1].id != n.id, "namespace collision: " + n.id);
        need(n.id.size() <= 512, "expanded namespace too long");
        const auto &spec = spatial_kind_spec(n.kind);
        op.kind = n.kind;
        op.seed = expanded.seeds.at(n.id);
        need(n.inputs.size() == spec.input_count, "wrong input arity: " + n.id);
        for (std::size_t j = 0; j < n.inputs.size(); ++j)
            op.inputs[j] = resolve(n.inputs[j]);
        need(n.sampling_scale == 1 || n.sampling_scale == 4 || n.sampling_scale == 16 ||
                 n.sampling_scale == 64,
             "sampling_scale must be 1,4,16,64: " + n.id);
        op.info.sampling_scale = n.sampling_scale;
        need(n.parameter_bindings.empty(), "unexpanded parameter binding");
        need(n.unit_power >= -8 && n.unit_power <= 8, "unit power outside -8..8");
        need(n.kind == SpatialKind::Constant || n.unit_power == 0,
             "unit_power is inferred except for constants");
        need(n.parameters.size() <= spec.parameters.size(), "unknown/excess parameters: " + n.id);
        for (const auto &[key, v] : n.parameters) {
            (void)v;
            need(std::any_of(spec.parameters.begin(), spec.parameters.end(),
                             [&](const auto &p) { return key == p.name; }),
                 "unknown parameter: " + n.id + "." + key);
        }
        for (std::size_t j = 0; j < spec.parameters.size(); ++j) {
            const auto &p = spec.parameters[j];
            auto [it, inserted] = n.parameters.try_emplace(p.name, p.default_value);
            (void)inserted;
            double v = it->second;
            need(std::isfinite(v) && v >= p.minimum && v <= p.maximum && (!p.integer || std::floor(v) == v),
                 "parameter outside domain: " + n.id + "." + p.name);
            if (v == 0)
                v = 0;
            it->second = v;
            op.p[j] = v;
        }
        need(n.kind != SpatialKind::Parameter, "parameter node outside a subgraph");
        need(n.kind == SpatialKind::GeometryDistance || n.kind == SpatialKind::AssignedRegion ||
                 n.reference.empty(),
             "unexpected immutable-input reference: " + n.id);
        if (n.kind == SpatialKind::Constant) {
            valid_value(n.value);
            need(n.value.type != SpatialType::SignedDistance && n.value.type != SpatialType::Distance,
                 "distance constants are not distance functions; use scalar with cell units");
            need((n.value.type != SpatialType::Normalized && n.value.type != SpatialType::Category &&
                  n.value.type != SpatialType::Boolean) ||
                     n.unit_power == 0,
                 "dimensionless type has nonzero units");
            op.value = n.value;
        } else if (n.kind == SpatialKind::CategoryIs) {
            valid_value(n.value);
            need(n.value.type == SpatialType::Category, "category_is requires an exact category literal");
            op.value = n.value;
        } else
            need(n.value == SpatialValue{}, "non-constant operator has ignored value payload: " + n.id);
        if (n.kind == SpatialKind::GeometryDistance) {
            auto it = std::find_if(geometries.begin(), geometries.end(),
                                   [&](const auto &g) { return g->geometry().id == n.reference; });
            need(it != geometries.end(), "missing geometry: " + n.reference);
            op.object = static_cast<std::size_t>(it - geometries.begin());
        }
        if (n.kind == SpatialKind::AssignedRegion) {
            auto it = std::find_if(assignments.begin(), assignments.end(), [&](const auto &g) {
                return g->definition().categories.size() > 0 && g->definition().categories.size() <= 16;
            });
            (void)it; /* object is assigned by reference map below */
        }
    }
    // Assignment IDs are supplied through a private reference-index table in
    // the canonical node parameters by compile(), before this phase.
    std::array<unsigned char, kMaxSpatialNodes> state{};
    std::array<std::size_t, kMaxSpatialNodes> depth{};
    std::function<void(std::size_t)> visit = [&](std::size_t i) {
        need(state[i] != 1, "cyclic spatial graph at " + nodes[i].id);
        if (state[i] == 2)
            return;
        state[i] = 1;
        auto &op = instructions[i];
        auto &info = op.info;
        const auto &n = nodes[i];
        const auto &spec = spatial_kind_spec(n.kind);
        std::size_t d = 1;
        for (std::size_t j = 0; j < spec.input_count; ++j) {
            visit(op.inputs[j]);
            d = std::max(d, depth[op.inputs[j]] + 1);
        }
        need(d <= limits.max_depth, "spatial dependency depth exceeded: " + n.id);
        depth[i] = d;
        auto in = [&](std::size_t j) -> const SpatialInfo & { return instructions[op.inputs[j]].info; };
        auto same_units = [&]() {
            need(in(0).unit_power == in(1).unit_power, "incompatible input units: " + n.id);
        };
        auto numeric = [&](std::size_t j) { need(scalar(in(j).type), "scalar input required: " + n.id); };
        info.type = SpatialType::Scalar;
        info.minimum = -B;
        info.maximum = B;
        std::uint64_t own = 32;
        std::array<std::uint64_t, 3> multipliers{1, 1, 1};
        switch (n.kind) {
        case SpatialKind::Constant:
            info.type = n.value.type;
            info.unit_power = n.unit_power;
            info.minimum = std::min(n.value.x, n.value.y);
            info.maximum = std::max(n.value.x, n.value.y);
            if (n.value.type != SpatialType::Vector2)
                info.minimum = info.maximum = n.value.x;
            break;
        case SpatialKind::Identity:
            info = in(0);
            break;
        case SpatialKind::Position:
            info.type = SpatialType::Vector2;
            [[fallthrough]];
        case SpatialKind::CoordinateX:
        case SpatialKind::CoordinateY:
            info.unit_power = 1;
            info.minimum = -C;
            info.maximum = C;
            break;
        case SpatialKind::CircleDistance:
        case SpatialKind::BoxDistance:
            info.type = SpatialType::SignedDistance;
            info.unit_power = 1;
            info.minimum = -1'000'000;
            info.maximum = 4 * C;
            info.distance_min_factor = info.distance_max_factor = 1;
            own = 64;
            break;
        case SpatialKind::Noise:
            info.type = SpatialType::Normalized;
            info.minimum = 0;
            info.maximum = 1;
            own = 256;
            break;
        case SpatialKind::Add:
        case SpatialKind::Subtract:
        case SpatialKind::Minimum:
        case SpatialKind::Maximum: {
            same_units();
            need((scalar(in(0).type) && scalar(in(1).type)) ||
                     (in(0).type == SpatialType::Vector2 && in(1).type == SpatialType::Vector2),
                 "arithmetic input types incompatible: " + n.id);
            info.type = in(0).type == SpatialType::Vector2 ? SpatialType::Vector2 : SpatialType::Scalar;
            info.unit_power = in(0).unit_power;
            if (n.kind == SpatialKind::Add) {
                info.minimum = in(0).minimum + in(1).minimum;
                info.maximum = in(0).maximum + in(1).maximum;
            } else if (n.kind == SpatialKind::Subtract) {
                info.minimum = in(0).minimum - in(1).maximum;
                info.maximum = in(0).maximum - in(1).minimum;
            } else {
                info.minimum = std::min(in(0).minimum, in(1).minimum);
                info.maximum = std::max(in(0).maximum, in(1).maximum);
                if (in(0).type == SpatialType::Normalized && in(1).type == SpatialType::Normalized)
                    info.type = SpatialType::Normalized;
            }
            break;
        }
        case SpatialKind::Multiply: {
            need((scalar(in(0).type) && continuous(in(1).type)) ||
                     (scalar(in(1).type) && continuous(in(0).type)),
                 "multiply needs scalar and scalar/vector: " + n.id);
            info.type = in(0).type == SpatialType::Vector2 || in(1).type == SpatialType::Vector2
                            ? SpatialType::Vector2
                            : SpatialType::Scalar;
            info.unit_power = in(0).unit_power + in(1).unit_power;
            const std::array<double, 4> products{in(0).minimum * in(1).minimum, in(0).minimum * in(1).maximum,
                                                 in(0).maximum * in(1).minimum,
                                                 in(0).maximum * in(1).maximum};
            info.minimum = *std::min_element(products.begin(), products.end());
            info.maximum = *std::max_element(products.begin(), products.end());
            if (in(0).type == SpatialType::Normalized && in(1).type == SpatialType::Normalized)
                info.type = SpatialType::Normalized;
            break;
        }
        case SpatialKind::Mix:
            same_units();
            need(in(0).type == in(1).type && continuous(in(0).type) && in(2).type == SpatialType::Normalized,
                 "mix needs matching continuous values and normalized weight");
            info = in(0);
            if (info.type == SpatialType::SignedDistance || info.type == SpatialType::Distance)
                info.type = SpatialType::Scalar;
            info.minimum = std::min(in(0).minimum, in(1).minimum);
            info.maximum = std::max(in(0).maximum, in(1).maximum);
            info.distance_min_factor = info.distance_max_factor = 0;
            break;
        case SpatialKind::ToMask:
            need(scalar(in(0).type) || in(0).type == SpatialType::Boolean, "to_mask needs scalar or boolean");
            need(op.p[0] < op.p[1], "to_mask low must be below high");
            info.type = SpatialType::Normalized;
            info.minimum = 0;
            info.maximum = 1;
            break;
        case SpatialKind::ComposeVector:
            numeric(0);
            numeric(1);
            same_units();
            info.type = SpatialType::Vector2;
            info.unit_power = in(0).unit_power;
            info.minimum = std::min(in(0).minimum, in(1).minimum);
            info.maximum = std::max(in(0).maximum, in(1).maximum);
            break;
        case SpatialKind::ComponentX:
        case SpatialKind::ComponentY:
        case SpatialKind::Length:
        case SpatialKind::UnitVector:
            need(in(0).type == SpatialType::Vector2, "vector input required");
            info = in(0);
            info.type = SpatialType::Scalar;
            if (n.kind == SpatialKind::Length) {
                info.minimum = 0;
                info.maximum = detail::magnitude(std::max(std::abs(in(0).minimum), std::abs(in(0).maximum)),
                                          std::max(std::abs(in(0).minimum), std::abs(in(0).maximum)));
            }
            if (n.kind == SpatialKind::UnitVector) {
                info.type = SpatialType::Vector2;
                info.unit_power = 0;
                info.minimum = -1;
                info.maximum = 1;
            }
            break;
        case SpatialKind::Dot:
            need(in(0).type == SpatialType::Vector2 && in(1).type == SpatialType::Vector2,
                 "dot needs vectors");
            info.unit_power = in(0).unit_power + in(1).unit_power;
            info.maximum = 2 * std::max(std::abs(in(0).minimum), std::abs(in(0).maximum)) *
                           std::max(std::abs(in(1).minimum), std::abs(in(1).maximum));
            info.minimum = -info.maximum;
            break;
        case SpatialKind::Equal:
            same_units();
            need(in(0).type == in(1).type, "equal requires identical types");
            info.type = SpatialType::Boolean;
            info.minimum = 0;
            info.maximum = 1;
            break;
        case SpatialKind::CategoryIs:
            need(in(0).type == SpatialType::Category, "category_is requires category input");
            info.type = SpatialType::Boolean;
            info.minimum = 0;
            info.maximum = 1;
            break;
        case SpatialKind::Less:
            numeric(0);
            numeric(1);
            same_units();
            info.type = SpatialType::Boolean;
            info.minimum = 0;
            info.maximum = 1;
            break;
        case SpatialKind::Select:
            need(in(0).type == SpatialType::Boolean && in(1).type == in(2).type &&
                     in(1).unit_power == in(2).unit_power,
                 "select needs boolean and matching branches");
            info = in(1);
            info.minimum = std::min(in(1).minimum, in(2).minimum);
            info.maximum = std::max(in(1).maximum, in(2).maximum);
            if (info.type == SpatialType::SignedDistance)
                info.type = SpatialType::Scalar;
            info.distance_min_factor = info.distance_max_factor = 0;
            break;
        case SpatialKind::Transform:
        case SpatialKind::TransformVector: {
            info = in(0);
            const auto &p = op.p;
            need(std::abs(p[3]) >= 0.0001 && std::abs(p[4]) >= 0.0001, "singular scale");
            const double co = std::cos(p[2]), si = std::sin(p[2]);
            op.matrix = {(co - si * p[6]) * p[3], (co * p[5] - si) * p[4], (si + co * p[6]) * p[3],
                         (si * p[5] + co) * p[4]};
            const auto &m = op.matrix;
            const double det = m[0] * m[3] - m[1] * m[2];
            need(std::isfinite(det) && std::abs(det) >= 1e-8, "singular/ill-conditioned shear transform");
            op.inverse = {m[3] / det, -m[1] / det, -m[2] / det, m[0] / det};
            if (n.kind == SpatialKind::TransformVector) {
                need(info.type == SpatialType::Vector2, "transform_vector needs vector");
                double bound = std::max(std::abs(info.minimum), std::abs(info.maximum)) *
                               std::max(std::abs(m[0]) + std::abs(m[1]), std::abs(m[2]) + std::abs(m[3]));
                info.minimum = -bound;
                info.maximum = bound;
            } else if (info.type == SpatialType::SignedDistance || info.type == SpatialType::Distance) {
                const double trace = m[0] * m[0] + m[1] * m[1] + m[2] * m[2] + m[3] * m[3];
                double hi = std::sqrt((trace + std::sqrt(std::max(0.0, trace * trace - 4 * det * det))) / 2);
                double lo = std::abs(det) / hi;
                info.distance_min_factor = lo;
                info.distance_max_factor = hi;
                if (p[5] == 0 && p[6] == 0 && std::abs(p[3]) == std::abs(p[4])) {
                    info.minimum *= std::abs(p[3]);
                    info.maximum *= std::abs(p[3]);
                    info.distance_min_factor = info.distance_max_factor = 1;
                } else
                    info.type = SpatialType::Scalar;
            }
            if (n.kind == SpatialKind::Transform && in(0).type == SpatialType::Scalar) {
                info.distance_min_factor = 0;
                info.distance_max_factor = 0;
            }
            own = 128;
            break;
        }
        case SpatialKind::Polar:
        case SpatialKind::LogPolar:
        case SpatialKind::Repeat:
        case SpatialKind::Mirror:
        case SpatialKind::Warp:
            info = in(0);
            if (info.type == SpatialType::SignedDistance || info.type == SpatialType::Distance)
                info.type = SpatialType::Scalar;
            info.distance_min_factor = info.distance_max_factor = 0;
            if (n.kind == SpatialKind::Warp)
                need(in(1).type == SpatialType::Vector2 && in(1).unit_power == 1,
                     "warp displacement requires vector with cell units");
            own = 128;
            break;
        case SpatialKind::Gradient:
        case SpatialKind::Slope:
        case SpatialKind::Aspect:
        case SpatialKind::Divergence:
        case SpatialKind::Curl:
        case SpatialKind::Ridge:
        case SpatialKind::Valley:
        case SpatialKind::LocalMinimum:
        case SpatialKind::LocalMaximum:
        case SpatialKind::Curvature: {
            const bool vector = n.kind == SpatialKind::Divergence || n.kind == SpatialKind::Curl;
            need(vector ? in(0).type == SpatialType::Vector2 : scalar(in(0).type),
                 "invalid derivative input type");
            info.unit_power = in(0).unit_power - 1;
            const double bound = 2 * std::max(std::abs(in(0).minimum), std::abs(in(0).maximum)) / op.p[0];
            info.minimum = -bound;
            info.maximum = bound;
            multipliers[0] = 4;
            own = 96;
            if (n.kind == SpatialKind::Gradient)
                info.type = SpatialType::Vector2;
            if (n.kind == SpatialKind::Slope) {
                info.minimum = 0;
                info.maximum = std::sqrt(2.0) * bound;
            }
            if (n.kind == SpatialKind::Aspect) {
                info.unit_power = 0;
                info.minimum = -std::numbers::pi;
                info.maximum = std::numbers::pi;
            }
            if (n.kind == SpatialKind::Ridge || n.kind == SpatialKind::Valley) {
                info.unit_power = in(0).unit_power - 2;
                info.minimum = 0;
                info.maximum = 4 * bound / op.p[0];
                multipliers[0] = 5;
            }
            if (n.kind == SpatialKind::LocalMinimum || n.kind == SpatialKind::LocalMaximum) {
                info.type = SpatialType::Boolean;
                info.unit_power = 0;
                info.minimum = 0;
                info.maximum = 1;
                multipliers[0] = 5;
            }
            if (n.kind == SpatialKind::Curvature) {
                info.unit_power = -1;
                info.minimum = -B;
                info.maximum = B;
                multipliers[0] = 9;
                own = 160;
            }
            break;
        }
        case SpatialKind::Peano:
            info.type = SpatialType::Normalized;
            info.minimum = 0;
            info.maximum = 1;
            own = spatial::peano_work_bound(static_cast<std::uint32_t>(op.p[0]));
            break;
        case SpatialKind::VoronoiRegion:
        case SpatialKind::VoronoiDistance:
        case SpatialKind::VoronoiBoundary:
        case SpatialKind::DelaunayDegree: {
            spatial::LatticeSpec ls{op.seed, static_cast<std::uint64_t>(op.p[2]), op.p[0], op.p[1]};
            spatial::validate(ls);
            info.type = n.kind == SpatialKind::VoronoiRegion ? SpatialType::Category : SpatialType::Distance;
            info.unit_power = info.type == SpatialType::Category ? 0 : 1;
            info.minimum = 0;
            info.maximum = std::sqrt(2.0) * op.p[0];
            own = spatial::kNearestSeedWork;
            if (n.kind == SpatialKind::VoronoiBoundary)
                own = spatial::kVoronoiBoundaryWork;
            if (n.kind == SpatialKind::DelaunayDegree) {
                own = spatial::kDelaunayWork;
                info.type = SpatialType::Scalar;
                info.unit_power = 0;
                info.maximum = 48;
            }
            break;
        }
        case SpatialKind::PoissonDistance:
        case SpatialKind::PoissonRegion:
        case SpatialKind::PoissonFound: {
            spatial::PoissonSpec ps{{op.seed, static_cast<std::uint64_t>(op.p[2]), op.p[0], op.p[1]},
                                    op.p[3],
                                    static_cast<std::uint32_t>(op.p[4])};
            spatial::validate(ps);
            info.type =
                n.kind == SpatialKind::PoissonRegion
                    ? SpatialType::Category
                    : (n.kind == SpatialKind::PoissonFound ? SpatialType::Boolean : SpatialType::Distance);
            info.unit_power = info.type == SpatialType::Distance ? 1 : 0;
            info.minimum = 0;
            info.maximum = info.type == SpatialType::Distance ? op.p[0] * op.p[4] : 1;
            own = spatial::poisson_work_bound(ps);
            break;
        }
        case SpatialKind::GeometryDistance:
            info.type = SpatialType::Distance;
            info.unit_power = 1;
            info.minimum = 0;
            info.maximum = 4 * C;
            own = geometries[op.object]->work_bound();
            break;
        case SpatialKind::AssignedRegion:
            info.type = SpatialType::Category;
            info.minimum = 0;
            info.maximum = 0;
            own = spatial::PreparedRegions::sample_work_bound();
            break;
        case SpatialKind::Parameter:
            break;
        }
        if (const auto units = expanded.binding_units.find(n.id); units != expanded.binding_units.end()) {
            for (const auto &[key, power] : units->second) {
                int expected = 0;
                if (key == "low" || key == "high")
                    expected = in(0).unit_power;
                else if (key == "x" || key == "y" || key == "radius" || key == "width" || key == "height" ||
                         key == "scale" || key == "spacing" || key == "tx" || key == "ty" ||
                         key == "origin_x" || key == "origin_y" || key == "radial_scale" ||
                         key == "min_radius" || key == "period_x" || key == "period_y" ||
                         key == "cell_size" || key == "max_displacement")
                    expected = 1;
                need(power == expected,
                     "numeric parameter binding has incompatible units: " + n.id + "." + key);
            }
        }
        info.sampling_scale = n.sampling_scale;
        need(info.unit_power >= -8 && info.unit_power <= 8, "derived units exceed allowed exponent");
        need(std::isfinite(info.minimum) && std::isfinite(info.maximum) && info.minimum >= -B &&
                 info.maximum <= B,
             "declared numeric bound exceeds +/-1e100: " + n.id);
        std::uint64_t node_cost = own;
        for (std::size_t j = 0; j < spec.input_count; ++j) {
            for (std::uint64_t k = 0; k < multipliers[j]; ++k)
                node_cost = add_cost(node_cost, in(j).operations, limits.max_operations_per_sample,
                                     "recursive sampling work exhausted");
        }
        if (n.sampling_scale > 1) {
            const auto repeats = continuous(info.type) ? 4U : 1U;
            need(node_cost <= limits.max_operations_per_sample / repeats, "coarse resampling work exhausted");
            node_cost = add_cost(node_cost * repeats, 64, limits.max_operations_per_sample,
                                 "coarse resampling work exhausted");
            if (info.type == SpatialType::SignedDistance || info.type == SpatialType::Distance) {
                info.type = SpatialType::Scalar;
                info.distance_min_factor = info.distance_max_factor = 0;
            }
        }
        info.operations = node_cost;
        std::uint64_t h = FNV;
        word(h, kSpatialAlgorithmVersion);
        text_hash(h, n.id);
        word(h, static_cast<unsigned>(n.kind));
        word(h, n.sampling_scale);
        word(h, static_cast<std::uint64_t>(n.unit_power));
        value_hash(h, n.value);
        text_hash(h, n.reference);
        word(h, op.seed);
        for (const auto &[key, v] : n.parameters) {
            text_hash(h, key);
            word(h, bits(v));
        }
        for (std::size_t j = 0; j < spec.input_count; ++j)
            word(h, in(j).fingerprint);
        if (n.kind == SpatialKind::GeometryDistance)
            word(h, geometries[op.object]->fingerprint());
        info.fingerprint = h;
        op.domain = h;
        state[i] = 2;
    };
    for (std::size_t i = 0; i < nodes.size(); ++i)
        visit(i);
    cost = 0;
    fingerprint = FNV;
    word(fingerprint, kSpatialAlgorithmVersion);
    for (const auto &op : instructions) {
        cost = add_cost(cost, op.info.operations, limits.max_operations_per_sample,
                        "total declared sampling work exhausted");
        word(fingerprint, op.info.fingerprint);
    }
    word(fingerprint, limits.max_nodes);
    word(fingerprint, limits.max_depth);
    word(fingerprint, limits.max_operations_per_sample);
}

SpatialValue SpatialGraph::Impl::raw(std::size_t index, double x, double y, SpatialScratch *scratch) const {
    sample_coordinate(x, y);
    const auto &op = instructions[index];
    const auto &p = op.p;
    auto at = [&](std::size_t i, double xx, double yy) { return evaluate(op.inputs[i], xx, yy, scratch); };
    auto input = [&](std::size_t i) { return at(i, x, y); };
    const auto output = [&](double a, double b = 0) { return number(op.info.type, a, b); };
    switch (op.kind) {
    case SpatialKind::Constant:
        return op.value;
    case SpatialKind::Identity:
        return input(0);
    case SpatialKind::Position:
        return output(x, y);
    case SpatialKind::CoordinateX:
        return output(x);
    case SpatialKind::CoordinateY:
        return output(y);
    case SpatialKind::CircleDistance:
        return output(detail::magnitude(x - p[0], y - p[1]) - p[2]);
    case SpatialKind::BoxDistance: {
        double qx = std::abs(x - p[0]) - p[2] / 2, qy = std::abs(y - p[1]) - p[3] / 2;
        return output(detail::magnitude(std::max(qx, 0.0), std::max(qy, 0.0)) + std::min(std::max(qx, qy), 0.0));
    }
    case SpatialKind::Noise: {
        double xx = x / p[0], yy = y / p[0], fx = std::floor(xx), fy = std::floor(yy);
        auto ix = static_cast<std::int64_t>(fx), iy = static_cast<std::int64_t>(fy);
        double u = xx - fx, v = yy - fy;
        u = u * u * u * (u * (6 * u - 15) + 10);
        v = v * v * v * (v * (6 * v - 15) + 10);
        auto corner = [&](std::int64_t a, std::int64_t b) {
            auto h = mixed(op.seed ^ mixed(static_cast<std::uint64_t>(a)) ^
                           std::rotl(mixed(static_cast<std::uint64_t>(b)), 27) ^
                           mixed(static_cast<std::uint64_t>(p[1])));
            return static_cast<double>(h >> 11) * 0x1.0p-53;
        };
        return output(lerp(lerp(corner(ix, iy), corner(ix + 1, iy), u),
                           lerp(corner(ix, iy + 1), corner(ix + 1, iy + 1), u), v));
    }
    case SpatialKind::Add:
    case SpatialKind::Subtract:
    case SpatialKind::Minimum:
    case SpatialKind::Maximum: {
        auto a = input(0), b = input(1);
        auto combine = [&](double u, double v) {
            if (op.kind == SpatialKind::Add)
                return u + v;
            if (op.kind == SpatialKind::Subtract)
                return u - v;
            if (op.kind == SpatialKind::Minimum)
                return std::min(u, v);
            return std::max(u, v);
        };
        return output(combine(a.x, b.x), op.info.type == SpatialType::Vector2 ? combine(a.y, b.y) : 0);
    }
    case SpatialKind::Multiply: {
        auto a = input(0), b = input(1);
        if (a.type == SpatialType::Vector2)
            return output(a.x * b.x, a.y * b.x);
        if (b.type == SpatialType::Vector2)
            return output(a.x * b.x, a.x * b.y);
        return output(a.x * b.x);
    }
    case SpatialKind::Mix: {
        auto a = input(0), b = input(1);
        double t = input(2).x;
        return output(lerp(a.x, b.x, t), op.info.type == SpatialType::Vector2 ? lerp(a.y, b.y, t) : 0);
    }
    case SpatialKind::ToMask: {
        auto a = input(0);
        return output(a.type == SpatialType::Boolean ? a.x
                                                     : std::clamp((a.x - p[0]) / (p[1] - p[0]), 0.0, 1.0));
    }
    case SpatialKind::ComposeVector:
        return output(input(0).x, input(1).x);
    case SpatialKind::ComponentX:
        return output(input(0).x);
    case SpatialKind::ComponentY:
        return output(input(0).y);
    case SpatialKind::Length: {
        auto a = input(0);
        return output(detail::magnitude(a.x, a.y));
    }
    case SpatialKind::UnitVector: {
        auto a = input(0);
        const double scale = std::max(std::abs(a.x), std::abs(a.y));
        if (scale == 0)
            return output(0, 0);
        // Normalize in the scaled domain: a subnormal vector's rounded
        // magnitude can lose enough precision to produce a non-unit result.
        a.x /= scale;
        a.y /= scale;
        double length = detail::magnitude(a.x, a.y);
        return output(a.x / length, a.y / length);
    }
    case SpatialKind::Dot: {
        auto a = input(0), b = input(1);
        return output(a.x * b.x + a.y * b.y);
    }
    case SpatialKind::Equal:
        return output(input(0) == input(1) ? 1 : 0);
    case SpatialKind::CategoryIs: {
        auto v = input(0).category;
        return output(v.x == op.value.category.x && v.y == op.value.category.y &&
                              (op.value.category.domain == 0 || v.domain == op.value.category.domain)
                          ? 1
                          : 0);
    }
    case SpatialKind::Less:
        return output(input(0).x < input(1).x ? 1 : 0);
    case SpatialKind::Select: {
        auto a = input(0).x == 1 ? input(1) : input(2);
        a.type = op.info.type;
        return a;
    }
    case SpatialKind::Transform: {
        double dx = x - p[7] - p[0], dy = y - p[8] - p[1];
        auto v = at(0, p[7] + op.inverse[0] * dx + op.inverse[1] * dy,
                    p[8] + op.inverse[2] * dx + op.inverse[3] * dy);
        if ((instructions[op.inputs[0]].info.type == SpatialType::SignedDistance ||
             instructions[op.inputs[0]].info.type == SpatialType::Distance) &&
            p[5] == 0 && p[6] == 0 && std::abs(p[3]) == std::abs(p[4]))
            v.x *= std::abs(p[3]);
        v.type = op.info.type;
        return v;
    }
    case SpatialKind::TransformVector: {
        auto v = input(0);
        return output(op.matrix[0] * v.x + op.matrix[1] * v.y, op.matrix[2] * v.x + op.matrix[3] * v.y);
    }
    case SpatialKind::Polar:
    case SpatialKind::LogPolar: {
        double dx = x - p[0], dy = y - p[1], r = detail::magnitude(dx, dy);
        double theta = r == 0 ? 0 : std::atan2(dy, dx);
        double u = op.kind == SpatialKind::LogPolar ? std::log(std::max(r, p[4]) / p[2]) : r / p[2];
        auto v = at(0, u, theta / p[3]);
        v.type = op.info.type;
        return v;
    }
    case SpatialKind::Repeat:
    case SpatialKind::Mirror: {
        auto fold = [&](double v, double period, double origin) {
            v -= origin;
            const double extent = op.kind == SpatialKind::Repeat ? period : 2 * period;
            v = std::fmod(v, extent);
            if (v < 0)
                v += extent;
            if (v >= extent)
                v = 0;
            return op.kind == SpatialKind::Repeat || v <= period ? v : extent - v;
        };
        auto v = at(0, fold(x, p[0], p[2]), fold(y, p[1], p[3]));
        v.type = op.info.type;
        return v;
    }
    case SpatialKind::Warp: {
        auto displacement = input(1);
        double length = detail::magnitude(displacement.x, displacement.y);
        double scale = length > p[0] && length > 0 ? p[0] / length : 1;
        auto v = at(0, x + displacement.x * scale, y + displacement.y * scale);
        v.type = op.info.type;
        return v;
    }
    case SpatialKind::Gradient:
    case SpatialKind::Slope:
    case SpatialKind::Aspect:
    case SpatialKind::Divergence:
    case SpatialKind::Curl:
    case SpatialKind::Ridge:
    case SpatialKind::Valley:
    case SpatialKind::LocalMinimum:
    case SpatialKind::LocalMaximum:
    case SpatialKind::Curvature: {
        const double h = p[0];
        auto l = at(0, x - h, y), r = at(0, x + h, y), u = at(0, x, y - h), d = at(0, x, y + h);
        const double gx = (r.x - l.x) / (2 * h), gy = (d.x - u.x) / (2 * h);
        if (op.kind == SpatialKind::Gradient)
            return output(gx, gy);
        if (op.kind == SpatialKind::Slope)
            return output(detail::magnitude(gx, gy));
        if (op.kind == SpatialKind::Aspect)
            return output(gx == 0 && gy == 0 ? 0 : std::atan2(gy, gx));
        if (op.kind == SpatialKind::Divergence)
            return output(gx + (d.y - u.y) / (2 * h));
        if (op.kind == SpatialKind::Curl)
            return output((r.y - l.y) / (2 * h) - gy);
        const auto c = input(0).x;
        if (op.kind == SpatialKind::LocalMinimum)
            return output(c < l.x && c < r.x && c < u.x && c < d.x ? 1 : 0);
        if (op.kind == SpatialKind::LocalMaximum)
            return output(c > l.x && c > r.x && c > u.x && c > d.x ? 1 : 0);
        double fxx = (r.x - 2 * c + l.x) / (h * h), fyy = (d.x - 2 * c + u.x) / (h * h);
        if (op.kind == SpatialKind::Ridge)
            return output(std::max(0.0, -fxx - fyy));
        if (op.kind == SpatialKind::Valley)
            return output(std::max(0.0, fxx + fyy));
        double g = detail::magnitude(gx, gy);
        if (g == 0)
            return output(0);
        double fxy =
            (at(0, x + h, y + h).x - at(0, x + h, y - h).x - at(0, x - h, y + h).x + at(0, x - h, y - h).x) /
            (4 * h * h);
        const double nx = gx / g, ny = gy / g;
        return output((fxx * ny * ny - 2 * fxy * nx * ny + fyy * nx * nx) / g);
    }
    case SpatialKind::Peano: {
        const auto order = static_cast<std::uint32_t>(p[0]);
        const auto address =
            spatial::peano_address_unchecked(x, y, order, static_cast<std::uint32_t>(p[1]), p[2], p[3]);
        const auto side = spatial::peano_side(order);
        return output(static_cast<double>(address.index) /
                      static_cast<double>(static_cast<std::uint64_t>(side) * side - 1));
    }
    case SpatialKind::VoronoiRegion:
    case SpatialKind::VoronoiDistance:
    case SpatialKind::VoronoiBoundary:
    case SpatialKind::DelaunayDegree: {
        spatial::LatticeSpec spec{op.seed, static_cast<std::uint64_t>(p[2]), p[0], p[1]};
        if (op.kind == SpatialKind::VoronoiBoundary)
            return output(spatial::voronoi_boundary_unchecked(spec, {x, y}));
        if (op.kind == SpatialKind::DelaunayDegree)
            return output(static_cast<double>(spatial::delaunay_unchecked(spec, {x, y}).size));
        auto nearest = spatial::nearest_seed_unchecked(spec, {x, y});
        if (op.kind == SpatialKind::VoronoiDistance)
            return output(nearest.distance);
        auto v = output(0);
        v.category = {nearest.id.x, nearest.id.y, op.domain};
        return v;
    }
    case SpatialKind::PoissonDistance:
    case SpatialKind::PoissonRegion:
    case SpatialKind::PoissonFound: {
        spatial::PoissonSpec spec{
            {op.seed, static_cast<std::uint64_t>(p[2]), p[0], p[1]}, p[3], static_cast<std::uint32_t>(p[4])};
        auto nearest = spatial::poisson_unchecked(spec, {x, y});
        if (op.kind == SpatialKind::PoissonDistance)
            return output(nearest.distance);
        if (op.kind == SpatialKind::PoissonFound)
            return output(nearest.found ? 1 : 0);
        auto v = output(0);
        if (nearest.found)
            v.category = {nearest.nearest.id.x, nearest.nearest.id.y, op.domain};
        return v;
    }
    case SpatialKind::GeometryDistance:
        return output(geometries[op.object]->distance({x, y}));
    case SpatialKind::AssignedRegion: {
        auto v = output(0);
        v.category.x = std::bit_cast<std::int64_t>(assignments[op.object]->sample({x, y}));
        v.category.domain = op.domain;
        return v;
    }
    case SpatialKind::Parameter:
        break;
    }
    throw std::logic_error("uncompiled spatial operator");
}
SpatialValue SpatialGraph::Impl::evaluate(std::size_t index, double x, double y,
                                          SpatialScratch *scratch) const {
    sample_coordinate(x, y);
    const auto &info = instructions[index].info;
    SpatialScratch::Entry *entry = nullptr;
    if (scratch) {
        auto hash = mixed(info.fingerprint ^ mixed(bits(x)) ^ std::rotl(mixed(bits(y)), 17));
        entry = &scratch->cache[hash % kSpatialCacheSlots];
        if (entry->valid && entry->fingerprint == info.fingerprint && entry->x == bits(x) &&
            entry->y == bits(y)) {
            ++scratch->hits;
            return entry->value;
        }
        ++scratch->misses;
    }
    SpatialValue v;
    const auto scale = info.sampling_scale;
    if (scale == 1)
        v = raw(index, x, y, scratch);
    else {
        double s = static_cast<double>(scale);
        double ax = std::floor(x / s) * s, ay = std::floor(y / s) * s, fx = (x - ax) / s, fy = (y - ay) / s;
        if (!continuous(info.type))
            v = raw(index, fx <= 0.5 ? ax : ax + s, fy <= 0.5 ? ay : ay + s, scratch);
        else {
            const auto a = raw(index, ax, ay, scratch), b = raw(index, ax + s, ay, scratch),
                       c = raw(index, ax, ay + s, scratch), d = raw(index, ax + s, ay + s, scratch);
            v = number(info.type, lerp(lerp(a.x, b.x, fx), lerp(c.x, d.x, fx), fy),
                       info.type == SpatialType::Vector2 ? lerp(lerp(a.y, b.y, fx), lerp(c.y, d.y, fx), fy)
                                                         : 0);
        }
    }
    v.type = info.type;
    if (v.x == 0)
        v.x = 0;
    if (v.y == 0)
        v.y = 0;
    if (!std::isfinite(v.x) || !std::isfinite(v.y) || std::abs(v.x) > B || std::abs(v.y) > B)
        throw std::runtime_error("spatial evaluation exceeded finite numeric bounds");
    if (info.type == SpatialType::Normalized && (v.x < 0 || v.x > 1))
        throw std::runtime_error("spatial normalized output outside [0,1]");
    // A recursive dependency may replace this direct-mapped slot. Write the
    // complete key and value only after successful evaluation.
    if (entry)
        *entry = {info.fingerprint, bits(x), bits(y), v, true};
    return v;
}

std::shared_ptr<const SpatialGraph> SpatialGraph::compile(SpatialDefinition definition, std::uint64_t seed,
                                                          SpatialLimits limits) {
    need(limits.max_nodes >= 1 && limits.max_nodes <= kMaxSpatialNodes && limits.max_depth >= 1 &&
             limits.max_depth <= 16,
         "invalid spatial node/depth limits");
    need(limits.max_operations_per_sample >= 1 && limits.max_operations_per_sample <= 1'000'000 &&
             limits.max_preparation_operations >= 1 && limits.max_preparation_operations <= 16'000'000 &&
             limits.max_preparation_bytes >= 1 && limits.max_preparation_bytes <= 16 * 1024 * 1024,
         "invalid spatial work/memory limits");
    need(definition.nodes.size() <= limits.max_nodes && definition.subgraphs.size() <= 16 &&
             definition.instances.size() <= 16 && definition.geometries.size() <= 16 &&
             definition.assignments.size() <= 16,
         "spatial declaration capacity exceeded");
    auto impl = std::make_unique<Impl>();
    impl->limits = limits;
    // Conservative allocation/validation ledger is admitted before copies,
    // expansion, geometry storage or solver scratch are constructed.
    std::size_t bytes = sizeof(Impl) +
                        limits.max_nodes * (sizeof(SpatialNode) + sizeof(Instruction) + 3 * 8192) +
                        sizeof(SpatialScratch);
    std::uint64_t prep = 1024;
    std::set<std::string> input_names;
    const auto account_instances = [&](const auto &instances) {
        for (const auto &inst : instances) {
            id(inst.id);
            id(inst.subgraph);
            need(inst.bindings.size() + inst.parameter_bindings.size() <= 16,
                 "instance binding capacity exceeded");
            for (const auto &[key, v] : inst.bindings) {
                id(key);
                valid_value(v);
            }
            for (const auto &[key, v] : inst.parameter_bindings) {
                id(key);
                id(v);
            }
        }
    };
    account_instances(definition.instances);
    const auto account_nodes = [&](const auto &nodes) {
        for (const auto &n : nodes) {
            need(n.inputs.size() <= 3 && n.parameters.size() <= 10 && n.parameter_bindings.size() <= 10,
                 "node declaration capacity exceeded");
            need(n.id.size() <= 64 && n.reference.size() <= 512, "oversize node identifiers");
            for (const auto &s : n.inputs)
                need(s.size() <= 512, "oversize input path");
            for (const auto &[key, v] : n.parameters) {
                (void)v;
                id(key);
            }
            for (const auto &[key, v] : n.parameter_bindings) {
                id(key);
                id(v);
            }
            bytes += 8192;
            prep = add_cost(prep, 256, limits.max_preparation_operations, "preparation work exhausted");
        }
    };
    account_nodes(definition.nodes);
    for (const auto &t : definition.subgraphs) {
        need(t.nodes.size() <= limits.max_nodes && t.parameters.size() <= 16 && t.instances.size() <= 16 &&
                 t.outputs.size() <= 16,
             "subgraph capacity exceeded");
        for (const auto &p : t.parameters) {
            id(p.id);
            need(static_cast<unsigned>(p.type) < std::size(type_names), "invalid parameter type");
            if (p.default_value)
                valid_value(*p.default_value);
        }
        account_nodes(t.nodes);
        account_instances(t.instances);
        for (const auto &[key, v] : t.outputs) {
            id(key);
            need(v.size() <= 512, "subgraph output path too long");
        }
        bytes += 16384;
        prep = add_cost(prep, 512, limits.max_preparation_operations, "preparation work exhausted");
    }
    for (const auto &g : definition.geometries) {
        need(g.points.size() <= spatial::kMaxGeometryPoints, "geometry point capacity exceeded");
        id(g.id);
        need(input_names.insert(g.id).second, "duplicate immutable input ID");
        spatial::validate(spatial::Geometry{g.id, g.points, g.closed});
        bytes += sizeof(spatial::PreparedGeometry) + g.points.size() * sizeof(spatial::Point) * 2 + 1024;
        prep = add_cost(prep, 256 + g.points.size() * 64, limits.max_preparation_operations,
                        "geometry preparation work exhausted");
    }
    for (const auto &a : definition.assignments) {
        id(a.id);
        need(input_names.insert(a.id).second, "duplicate immutable input ID");
        spatial::validate(a.specification, a.limits);
        bytes += spatial::kRegionSolverScratchBytes + 16384;
        prep = add_cost(prep, a.limits.max_work, limits.max_preparation_operations,
                        "solver preparation work exhausted");
    }
    need(bytes <= limits.max_preparation_bytes, "spatial preparation memory exhausted");
    impl->storage = bytes;
    impl->preparation = prep;
    auto by_id = [](const auto &a, const auto &b) { return a.id < b.id; };
    std::sort(definition.geometries.begin(), definition.geometries.end(), by_id);
    std::sort(definition.assignments.begin(), definition.assignments.end(), by_id);
    std::sort(definition.subgraphs.begin(), definition.subgraphs.end(), by_id);
    for (auto &g : definition.geometries)
        impl->geometries.push_back(spatial::PreparedGeometry::compile({g.id, g.points, g.closed}));
    for (auto &a : definition.assignments) {
        auto spec = a.specification;
        std::uint64_t h = seed;
        text_hash(h, a.id);
        spec.seed = mixed(h ^ spec.seed);
        impl->assignments.push_back(spatial::PreparedRegions::compile(std::move(spec), a.limits));
    }
    // Compile each template even when unused, with its real defaults and valid
    // placeholders for required parameters. Instantiation subsequently validates
    // every actual value against all operator domains.
    Expansion expand(definition, seed, limits.max_nodes, impl->preparation,
                     limits.max_preparation_operations);
    std::uint64_t declarations = FNV;
    auto bind_assignments = [&](Impl &graph) {
        for (std::size_t i = 0; i < graph.nodes.size(); ++i)
            if (graph.nodes[i].kind == SpatialKind::AssignedRegion) {
                auto it = std::lower_bound(definition.assignments.begin(), definition.assignments.end(),
                                           graph.nodes[i].reference,
                                           [](const auto &a, const auto &s) { return a.id < s; });
                need(it != definition.assignments.end() && it->id == graph.nodes[i].reference,
                     "missing region assignment: " + graph.nodes[i].reference);
                graph.instructions[i].object = static_cast<std::size_t>(it - definition.assignments.begin());
            }
    };
    for (const auto &t : definition.subgraphs) {
        Expanded check;
        std::vector<std::string> stack;
        SpatialInstance test;
        test.id = "declaration";
        test.subgraph = t.id;
        expand.instance(check, test, "", {}, stack, true);
        Impl validator;
        validator.limits = limits;
        validator.geometries = impl->geometries;
        validator.assignments = impl->assignments;
        validator.compile_nodes(std::move(check));
        bind_assignments(validator);
        text_hash(declarations, t.id);
        word(declarations, validator.fingerprint);
        auto params = t.parameters;
        std::sort(params.begin(), params.end(), by_id);
        for (const auto &p : params) {
            text_hash(declarations, p.id);
            word(declarations, static_cast<unsigned>(p.type));
            word(declarations, static_cast<std::uint64_t>(p.unit_power));
            word(declarations, p.default_value.has_value());
            if (p.default_value)
                value_hash(declarations, *p.default_value);
        }
    }
    impl->compile_nodes(expand.actual());
    bind_assignments(*impl);
    // Assignment geometry and category identity must invalidate dependent cache
    // entries (and only their descendants), including unused declaration changes
    // in the whole graph identity. Rebind in topological order.
    std::array<bool, kMaxSpatialNodes> done{};
    std::function<void(std::size_t)> identify = [&](std::size_t i) {
        if (done[i])
            return;
        auto &op = impl->instructions[i];
        auto h = op.info.fingerprint;
        const auto &n = impl->nodes[i];
        for (std::size_t j = 0; j < n.inputs.size(); ++j) {
            identify(op.inputs[j]);
            word(h, impl->instructions[op.inputs[j]].info.fingerprint);
        }
        if (op.kind == SpatialKind::AssignedRegion)
            word(h, impl->assignments[op.object]->fingerprint());
        op.info.fingerprint = h;
        op.domain = h == 0 ? 1 : h;
        done[i] = true;
    };
    for (std::size_t i = 0; i < impl->nodes.size(); ++i)
        identify(i);
    word(impl->fingerprint, declarations);
    for (const auto &op : impl->instructions)
        word(impl->fingerprint, op.info.fingerprint);
    for (const auto &g : impl->geometries)
        word(impl->fingerprint, g->fingerprint());
    for (const auto &a : impl->assignments)
        word(impl->fingerprint, a->fingerprint());
    word(impl->fingerprint, limits.max_preparation_operations);
    word(impl->fingerprint, limits.max_preparation_bytes);
    word(impl->fingerprint, impl->preparation);
    word(impl->fingerprint, bytes);
    return std::shared_ptr<const SpatialGraph>(new SpatialGraph(std::move(impl)));
}
SpatialGraph::SpatialGraph(std::unique_ptr<Impl> impl) : impl_(std::move(impl)) {}
SpatialGraph::~SpatialGraph() = default;
const std::vector<SpatialNode> &SpatialGraph::nodes() const noexcept {
    return impl_->nodes;
}
const SpatialInfo &SpatialGraph::info(std::size_t i) const {
    need(i < impl_->instructions.size(), "invalid node index");
    return impl_->instructions[i].info;
}
std::size_t SpatialGraph::index(const std::string &id) const {
    auto it = std::lower_bound(impl_->nodes.begin(), impl_->nodes.end(), id,
                               [](const auto &n, const auto &v) { return n.id < v; });
    if (it == impl_->nodes.end() || it->id != id)
        need(false, "unknown spatial output: " + id);
    return static_cast<std::size_t>(it - impl_->nodes.begin());
}
std::uint64_t SpatialGraph::fingerprint() const noexcept {
    return impl_->fingerprint;
}
std::uint64_t SpatialGraph::operations_per_sample() const noexcept {
    return impl_->cost;
}
std::uint64_t SpatialGraph::preparation_operations() const noexcept {
    return impl_->preparation;
}
std::size_t SpatialGraph::preparation_bytes() const noexcept {
    return impl_->storage;
}
void SpatialGraph::evaluate(std::int64_t x, std::int64_t y, SpatialValues &output,
                            SpatialScratch *scratch) const {
    need(x >= -kFieldCoordinateLimit && x < kFieldCoordinateLimit && y >= -kFieldCoordinateLimit &&
             y < kFieldCoordinateLimit,
         "world coordinate outside [-2^40,2^40)");
    SpatialValues next;
    next.size = impl_->nodes.size();
    for (std::size_t i = 0; i < next.size; ++i)
        next.values[i] = impl_->evaluate(i, static_cast<double>(x), static_cast<double>(y), scratch);
    output = next;
}
SpatialValue SpatialGraph::sample(const std::string &id, std::int64_t x, std::int64_t y,
                                  SpatialScratch *scratch) const {
    const auto i = index(id);
    need(x >= -kFieldCoordinateLimit && x < kFieldCoordinateLimit && y >= -kFieldCoordinateLimit &&
             y < kFieldCoordinateLimit,
         "world coordinate outside [-2^40,2^40)");
    return impl_->evaluate(i, static_cast<double>(x), static_cast<double>(y), scratch);
}
} // namespace cybersand::generation
