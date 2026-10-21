#include "cybersand/generation_planes.hpp"

#include <algorithm>
#include <bit>
#include <cmath>
#include <limits>
#include <set>
#include <stdexcept>
#include <tuple>
#include <utility>

namespace cybersand::generation {
namespace {
constexpr std::uint64_t fnv = UINT64_C(14695981039346656037);
constexpr std::uint64_t prime = UINT64_C(1099511628211);
constexpr std::uint64_t max_tick = 360'000;
void need(bool ok, const std::string& why) {
    if (!ok) throw std::invalid_argument("semantic planes: " + why);
}
void word(std::uint64_t& h, std::uint64_t v) noexcept {
    for (unsigned i = 0; i < 64; i += 8) { h ^= (v >> i) & 255; h *= prime; }
}
void text(std::uint64_t& h, const std::string& v) noexcept {
    word(h, v.size()); for (unsigned char c : v) { h ^= c; h *= prime; }
}
void rect_hash(std::uint64_t& h, RectI64 r) noexcept {
    word(h, static_cast<std::uint64_t>(r.x)); word(h, static_cast<std::uint64_t>(r.y));
    word(h, static_cast<std::uint64_t>(r.width)); word(h, static_cast<std::uint64_t>(r.height));
}
void real(std::uint64_t& h, double v) noexcept { word(h, std::bit_cast<std::uint64_t>(v == 0 ? 0.0 : v)); }
void identifier(const std::string& id) {
    need(!id.empty() && id.size() <= 64, "identifier must have 1..64 characters");
    for (char c : id) need((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.', "invalid identifier: " + id);
}
void selector(const std::string& id) { if (id != "$region") identifier(id); }
bool material_valid(Material m) noexcept { return cybersand::valid_material(static_cast<std::uint16_t>(m)); }
bool effects_material(Material m) noexcept {
    return m == Material::Empty || m == Material::Water || m == Material::Dust ||
        m == Material::Steam || m == Material::Spark || m == Material::Smoke;
}
bool plane_valid(Plane p) noexcept { return static_cast<unsigned>(p) < 4; }
std::size_t index(Plane p) { need(plane_valid(p), "unknown plane"); return static_cast<std::size_t>(p); }
bool contains(RectI64 b, std::int64_t x, std::int64_t y) noexcept {
    return x >= b.x && y >= b.y && x < b.x + b.width && y < b.y + b.height;
}
bool encloses(RectI64 a, RectI64 b) noexcept {
    return b.x >= a.x && b.y >= a.y && b.width > 0 && b.height > 0 &&
        b.width <= a.width && b.height <= a.height &&
        b.x - a.x <= a.width - b.width && b.y - a.y <= a.height - b.height;
}
bool valid_rect(RectI64 b) noexcept {
    return b.width > 0 && b.height > 0 && b.width <= 16384 && b.height <= 16384 &&
        b.x >= -kCoordinateLimit && b.y >= -kCoordinateLimit &&
        b.x <= kCoordinateLimit - b.width && b.y <= kCoordinateLimit - b.height;
}
std::uint64_t area(RectI64 b) noexcept {
    return static_cast<std::uint64_t>(b.width) * static_cast<std::uint64_t>(b.height);
}
RectI64 local_bounds(RectI64 feature, RectI64 local) {
    need(valid_rect(local) && local.x >= 0 && local.y >= 0 &&
        local.width <= feature.width && local.height <= feature.height &&
        local.x <= feature.width - local.width && local.y <= feature.height - local.height,
        "relative geometry leaves canonical feature bounds");
    local.x += feature.x; local.y += feature.y; return local;
}
bool matches(const SemanticFeature& f, const std::string& rule) noexcept {
    return rule == "$region" ? f.kind == SemanticKind::Region : f.rule_id == rule;
}
std::string record_id(const std::string& feature, const char* kind, const std::string& adapter) {
    std::string result = feature; result.append("/").append(kind).append("/").append(adapter); return result;
}
void bounded_note(const std::string& value) { need(value.size() <= 1024, "composition note exceeds 1024 bytes"); }
template<class T> void canonical_templates(std::vector<T>& items, std::size_t max) {
    need(items.size() <= max, "template count exceeds budget");
    std::sort(items.begin(), items.end(), [](const auto& a, const auto& b) { return a.id < b.id; });
    for (std::size_t i = 0; i < items.size(); ++i) {
        identifier(items[i].id); selector(items[i].rule);
        need(i == 0 || items[i - 1].id != items[i].id, "duplicate template ID: " + items[i].id);
    }
}
std::uint64_t projection_hash(const PlaneProjection& p, std::uint64_t feature_revision, std::uint64_t revision) noexcept {
    auto h = fnv; text(h, p.id); text(h, p.adapter); text(h, p.feature_id); text(h, p.geometry_ref);
    word(h, feature_revision); word(h, revision); word(h, static_cast<unsigned>(p.plane));
    word(h, static_cast<unsigned>(p.shape)); rect_hash(h, p.bounds); word(h, p.seed);
    word(h, static_cast<unsigned>(p.material)); word(h, static_cast<unsigned>(p.interior));
    word(h, p.wall_thickness); word(h, p.route_width); real(h, p.density);
    text(h, p.application); text(h, p.exclusion); word(h, p.fields_fingerprint);
    word(h, static_cast<std::uint64_t>(p.priority)); text(h, p.omission);
    for (auto v : p.points) { real(h, v.x); real(h, v.y); }
    return h;
}
std::uint64_t fixture_hash(const PlaneFixture& f, std::uint64_t feature_revision, std::uint64_t revision) noexcept {
    auto h = fnv; text(h, f.id); text(h, f.adapter); text(h, f.feature_id); text(h, f.clock);
    text(h, f.lifecycle); word(h, feature_revision); word(h, revision);
    word(h, static_cast<unsigned>(f.plane)); rect_hash(h, f.bounds);
    word(h, static_cast<unsigned>(f.material)); word(h, static_cast<unsigned>(f.mode));
    word(h, f.first_tick); word(h, f.period); word(h, f.repeat); word(h, f.cleanup_tick);
    for (auto m : f.expected_products) word(h, static_cast<unsigned>(m));
    return h;
}
std::uint64_t link_hash(const PlaneLink& l, std::uint64_t from, std::uint64_t to, std::uint64_t revision) noexcept {
    auto h = fnv; text(h, l.id); text(h, l.adapter); text(h, l.source_feature); text(h, l.target_feature);
    text(h, l.effect); text(h, l.fixture_id); text(h, l.lifecycle);
    word(h, from); word(h, to); word(h, revision); word(h, static_cast<unsigned>(l.family));
    word(h, static_cast<unsigned>(l.classification)); word(h, static_cast<unsigned>(l.source_plane));
    word(h, static_cast<unsigned>(l.target_plane)); rect_hash(h, l.bounds);
    word(h, static_cast<unsigned>(l.material)); word(h, l.radius); word(h, l.max_events_per_tick);
    return h;
}
bool projection_footprint_contains(const PlaneProjection& p, std::int64_t x, std::int64_t y) noexcept {
    if (!contains(p.bounds, x, y)) return false;
    if (!p.points.empty()) {
        const auto r = static_cast<std::int64_t>(p.route_width / 2);
        bool hit = false;
        for (std::size_t i = 1; i < p.points.size(); ++i) {
            const auto a = p.points[i - 1], b = p.points[i];
            if (x >= static_cast<std::int64_t>(std::min(a.x, b.x)) - r &&
                x <= static_cast<std::int64_t>(std::max(a.x, b.x)) + r &&
                y >= static_cast<std::int64_t>(std::min(a.y, b.y)) - r &&
                y <= static_cast<std::int64_t>(std::max(a.y, b.y)) + r) { hit = true; break; }
        }
        if (!hit) return false;
    }
    return true;
}
bool projection_contains(const PlaneProjection& p, std::int64_t x, std::int64_t y, double influence = 1) noexcept {
    if (!projection_footprint_contains(p, x, y)) return false;
    const auto density = p.density * influence;
    if (density == 1) return true;
    auto h = p.seed; word(h, static_cast<std::uint64_t>(x)); word(h, static_cast<std::uint64_t>(y));
    return static_cast<double>(h >> 32) < density * 4294967296.0;
}
Material projection_material(const PlaneProjection& p, std::int64_t x, std::int64_t y) noexcept {
    if (p.shape != ProjectionShape::Shell) return p.material;
    const auto w = static_cast<std::int64_t>(p.wall_thickness);
    const bool inner = x >= p.bounds.x + w && y >= p.bounds.y + w &&
        x < p.bounds.x + p.bounds.width - w && y < p.bounds.y + p.bounds.height - w;
    return inner ? p.interior : p.material;
}
std::uint64_t payload_hash(const std::vector<Material>& values) noexcept {
    auto h = fnv; word(h, values.size()); for (auto m : values) { h ^= static_cast<unsigned>(m); h *= prime; } return h;
}
std::uint64_t result_receipt(const PlaneResult& r) noexcept {
    auto h = fnv; word(h, r.revision); word(h, r.fingerprint); rect_hash(h, r.bounds); word(h, r.operations);
    for (auto v : r.content_hashes) word(h, v);
    word(h, r.fixture_ids.size()); for (const auto& id : r.fixture_ids) text(h, id);
    word(h, r.link_ids.size()); for (const auto& id : r.link_ids) text(h, id);
    word(h, r.actor_ids.size()); for (const auto& id : r.actor_ids) text(h, id);
    return h;
}
void discard(PlaneResult& r, ResultState state) noexcept {
    for (auto& cells : r.cells) cells.clear();
    r.fixture_ids.clear(); r.link_ids.clear(); r.actor_ids.clear();
    r.content_hashes.fill(0); r.receipt_hash = 0; r.state = state;
}
} // namespace

struct PlanePlan::Impl {
    std::shared_ptr<const Generator> generator;
    PlaneDefinition definition;
    RectI64 bounds;
    std::vector<PlaneProjection> projections;
    std::vector<PlaneFixture> fixtures;
    std::vector<PlaneLink> links;
    std::vector<PlaneActor> actors;
    std::array<std::vector<std::size_t>, 4> by_plane;
    // Fixed 64-cell bins retain canonical projection order. The index is finite,
    // preflighted against the existing prepared-memory/work bounds, and samples
    // never consult another request or allocate an index entry.
    static constexpr std::int64_t bin_size = 64;
    std::size_t bin_columns = 0, bin_rows = 0;
    std::array<std::vector<std::vector<std::size_t>>, 4> bins;
    [[nodiscard]] const std::vector<std::size_t>& candidates(Plane plane, std::int64_t x, std::int64_t y) const {
        const auto bx = static_cast<std::size_t>((x - bounds.x) / bin_size);
        const auto by = static_cast<std::size_t>((y - bounds.y) / bin_size);
        return bins[index(plane)][by * bin_columns + bx];
    }
    Material sample(Plane, std::int64_t, std::int64_t, PlaneCellProvenance*, PlaneStages*) const;
    std::vector<std::pair<int, int>> masks;
    std::array<bool, 4> masked_planes{};
    std::uint64_t fingerprint = fnv, work = 0, cost = 0, publication_work = 0;
    std::size_t bytes = 0, diagnostics = 0;

    void charge(std::uint64_t operations, std::size_t memory = 0, std::size_t diagnostic = 0) {
        const auto& l = definition.limits;
        need(operations <= l.max_operations - work, "semantic expansion work budget exhausted");
        need(memory <= l.max_prepared_bytes - bytes, "prepared memory budget exhausted");
        need(diagnostic <= l.max_diagnostic_bytes - diagnostics, "diagnostic storage budget exhausted");
        work += operations; bytes += memory; diagnostics += diagnostic;
    }
    void add_projection(PlaneProjection value, const SemanticFeature& feature) {
        need(projections.size() < definition.limits.max_projections, "projection record budget exhausted");
        if (!value.application.empty() || !value.exclusion.empty()) {
            value.fields_fingerprint = fnv;
            for (const auto& ref : {value.application, value.exclusion}) {
                const auto i = mask_index(ref);
                word(value.fields_fingerprint, i < 0 ? 0 : generator->spatial_graph().info(static_cast<std::size_t>(i)).fingerprint);
            }
        }
        value.revision = projection_hash(value, feature.revision, definition.revision);
        const auto strings = value.id.size() + value.adapter.size() + value.feature_id.size() +
            value.geometry_ref.size() + value.omission.size() + value.application.size() + value.exclusion.size();
        const auto memory = sizeof(PlaneProjection) * 2 + strings * 2 + value.points.size() * sizeof(spatial::Point) * 2;
        charge(64 + value.points.size() * 8 +
            ((!value.application.empty() || !value.exclusion.empty()) ? generator->spatial_graph().nodes().size() * 4 : 0),
            memory, memory);
        projections.push_back(std::move(value));
    }
    int mask_index(const std::string& ref) const {
        if (ref.empty()) return -1;
        need(ref.starts_with("spatial:") && ref.size() > 8 && ref.size() <= 520,
            "projection mask must name a shared spatial:<id> field");
        const auto& graph = generator->spatial_graph();
        const auto i = graph.index(ref.substr(8));
        const auto& info = graph.info(i);
        need((info.type == SpatialType::Normalized || info.type == SpatialType::Boolean) && info.unit_power == 0,
            "projection mask requires normalized/boolean input; use explicit to_mask");
        return static_cast<int>(i);
    }
    double mask_influence(std::size_t projection, const SpatialValues& values) const noexcept {
        const auto [a, e] = masks[projection];
        return (a < 0 ? 1 : values.values[static_cast<std::size_t>(a)].x) *
            (1 - (e < 0 ? 0 : values.values[static_cast<std::size_t>(e)].x));
    }
    bool endpoint(const std::string& feature, Plane plane) const noexcept {
        return std::any_of(projections.begin(), projections.end(), [&](const auto& p) {
            return p.feature_id == feature && p.plane == plane && p.shape != ProjectionShape::Omit;
        });
    }
};

std::shared_ptr<const PlanePlan> PlanePlan::compile(std::shared_ptr<const Generator> generator, PlaneDefinition d) {
    need(generator && generator->semantic_plan(), "a compiled GEN-004 semantic plan is required");
    need(d.schema == kPlaneSchemaVersion && d.revision > 0, "unsupported schema or zero revision");
    identifier(d.id);
    const auto& l = d.limits;
    need(l.max_templates > 0 && l.max_templates <= 512 && l.max_projections > 0 && l.max_projections <= 16384 &&
        l.max_fixtures <= 4096 && l.max_links <= 8192 && l.max_actors <= 8 &&
        l.max_cells_per_plane > 0 && l.max_cells_per_plane <= 4'194'304 &&
        l.max_operations > 0 && l.max_operations <= UINT64_C(4'000'000'000) &&
        l.max_prepared_bytes > 0 && l.max_prepared_bytes <= 64 * 1024 * 1024 &&
        l.max_publication_bytes > 0 && l.max_publication_bytes <= 256 * 1024 * 1024 &&
        l.max_diagnostic_bytes > 0 && l.max_diagnostic_bytes <= 16 * 1024 * 1024 &&
        l.max_events_per_tick > 0 && l.max_events_per_tick <= 256 &&
        l.max_fixture_cell_writes > 0 && l.max_fixture_cell_writes <= 67'108'864,
        "invalid limits");
    need(d.projections.size() <= l.max_templates && d.fixtures.size() <= l.max_templates - d.projections.size() &&
        d.links.size() <= l.max_templates - d.projections.size() - d.fixtures.size() &&
        d.actors.size() <= l.max_templates - d.projections.size() - d.fixtures.size() - d.links.size(), "total template budget exhausted");
    std::sort(d.policies.begin(), d.policies.end(), [](const auto& a, const auto& b) { return a.plane < b.plane; });
    for (std::size_t i = 0; i < d.policies.size(); ++i) {
        const auto& p = d.policies[i];
        need(static_cast<std::size_t>(p.plane) == i && material_valid(p.material), "missing/duplicate plane or invalid policy material");
        need(!p.base_generator || p.plane == Plane::Play, "only play may consume the base generator");
        need(p.rate <= 60 && (p.plane != Plane::Background || p.rate == 0), "background is frozen; rates must be 0..60");
        bounded_note(p.omission); need(!p.omission.empty(), "every plane declares its uncovered-space composition");
        need(p.plane != Plane::Effects || effects_material(p.material), "effects policy material is unsupported");
    }
    canonical_templates(d.projections, l.max_templates);
    canonical_templates(d.fixtures, l.max_templates);
    canonical_templates(d.links, l.max_templates);
    canonical_templates(d.actors, l.max_templates);
    auto impl = std::make_unique<Impl>(); impl->generator = std::move(generator); impl->definition = std::move(d);
    const auto& definition = impl->definition;
    const auto& plan = *impl->generator->semantic_plan();
    impl->bounds = plan.bounds();
    need(valid_rect(impl->bounds), "invalid semantic window bounds");
    need(area(impl->bounds) <= definition.limits.max_cells_per_plane, "complete semantic window exceeds per-plane cell budget");
    impl->charge(1, sizeof(Impl) + sizeof(PlaneDefinition));
    for (const auto& p : definition.policies) impl->charge(8, p.omission.size() * 2);
    for (const auto& p : definition.projections) impl->charge(16, sizeof(p) * 2 +
        (p.id.size() + p.rule.size() + p.geometry.size() + p.route_type.size() + p.omission.size() +
            p.application.size() + p.exclusion.size()) * 2);
    for (const auto& f : definition.fixtures) impl->charge(16, sizeof(f) * 2 +
        (f.id.size() + f.rule.size()) * 2 + f.expected_products.size() * sizeof(Material) * 2);
    for (const auto& k : definition.links) impl->charge(16, sizeof(k) * 2 +
        (k.id.size() + k.rule.size() + k.target_rule.size() + k.effect.size() + k.fixture.size()) * 2);
    for (const auto& a : definition.actors) impl->charge(16, sizeof(a) * 2 +
        (a.id.size() + a.rule.size() + a.model.size() + a.producer.size()) * 2);

    if (definition.policies[0].base_generator) for (const auto& feature : plan.features()) {
        // Append into known-empty storage: GCC 13's C-string replacement path
        // imports GLIBCXX_3.4.31, beyond the retained Linux runtime floor.
        PlaneProjection p; p.id = record_id(feature.id, "plane", "native-play"); p.adapter.append("native-play");
        p.feature_id = feature.id; p.geometry_ref = feature.id; p.plane = Plane::Play;
        p.shape = ProjectionShape::Native; p.bounds = feature.bounds; p.owner = feature.owner;
        p.seed = feature.seed; p.material = feature.material.value_or(Material::Empty);
        p.interior = feature.interior.value_or(Material::Empty); p.wall_thickness = feature.wall_thickness;
        p.priority = std::numeric_limits<int>::min(); impl->add_projection(std::move(p), feature);
    }
    for (const auto& t : definition.projections) {
        need(plane_valid(t.plane) && t.shape != ProjectionShape::Native &&
            parse_projection_shape(projection_shape_name(t.shape)).has_value(), "unsupported projection plane/shape");
        need(t.geometry == "feature" || t.geometry == "routes", "unsupported projection geometry");
        need(!t.material || material_valid(*t.material), "invalid projection material");
        need(!t.interior || material_valid(*t.interior), "invalid interior material");
        need(std::isfinite(t.density) && t.density >= 0 && t.density <= 1, "projection density must be finite 0..1");
        bounded_note(t.omission);
        need(t.shape != ProjectionShape::Omit || !t.omission.empty(), "omitted composition requires a reason");
        need(t.wall_thickness <= 128 && t.route_width <= 63 &&
            (t.route_width == 0 || t.route_width % 2 == 1), "invalid projection thickness/route width");
        if (t.geometry == "routes") need(t.rule == "$region" && !t.bounds &&
            (t.route_type == "passage" || t.route_type == "service" || t.route_type == "liquid") &&
            t.shape == ProjectionShape::Fill, "route projections require a region selector, route type and fill shape");
        else need(t.route_type.empty() && t.route_width == 0, "feature projection cannot contain route parameters");
        std::size_t matched = 0;
        for (const auto& feature : plan.features()) {
            impl->charge(1);
            if (!matches(feature, t.rule)) continue;
            ++matched;
            PlaneProjection p; p.id = record_id(feature.id, "plane", t.id); p.adapter = t.id;
            p.feature_id = feature.id; p.geometry_ref = feature.id; p.plane = t.plane;
            p.shape = t.shape; p.bounds = t.bounds ? local_bounds(feature.bounds, *t.bounds) : feature.bounds;
            p.owner = feature.owner; p.seed = feature.seed; text(p.seed, t.id);
            p.material = t.material.value_or(feature.material.value_or(definition.policies[index(t.plane)].material));
            p.interior = t.interior.value_or(feature.interior.value_or(Material::Empty));
            p.wall_thickness = t.wall_thickness; p.density = t.density; p.priority = t.priority; p.omission = t.omission;
            p.application = t.application; p.exclusion = t.exclusion;
            need(t.shape != ProjectionShape::Shell || (t.wall_thickness > 0 &&
                2 * t.wall_thickness < static_cast<std::uint64_t>(std::min(p.bounds.width, p.bounds.height))),
                "shell wall thickness leaves no interior");
            need(t.plane != Plane::Effects || (effects_material(p.material) && effects_material(p.interior)),
                "effects projection contains unsupported material");
            if (t.geometry == "routes") {
                std::size_t routes = 0;
                for (const auto& route : plan.routes()) {
                    impl->charge(1);
                    if (route.owner != feature.owner || route.type != t.route_type) continue;
                    ++routes; auto r = p; r.id.append("/").append(route.id);
                    r.geometry_ref = route.id; r.points = route.points;
                    r.route_width = t.route_width == 0 ? route.width : t.route_width;
                    r.material = t.material.value_or(route.material);
                    need(r.points.size() >= 2 && r.points.size() <= 256 && r.route_width > 0 && r.route_width <= 63,
                        "canonical route geometry exceeds projection bounds");
                    impl->add_projection(std::move(r), feature);
                }
                need(routes > 0, "route projection has no canonical geometry: " + t.id);
            } else impl->add_projection(std::move(p), feature);
        }
        need(matched > 0, "projection selector has no feature: " + t.rule);
    }
    std::sort(impl->projections.begin(), impl->projections.end(), [](const auto& a, const auto& b) {
        return std::tie(a.plane, a.priority, a.id) < std::tie(b.plane, b.priority, b.id);
    });
    std::set<std::string> projection_ids;
    for (std::size_t i = 0; i < impl->projections.size(); ++i) {
        const auto& p = impl->projections[i];
        need(projection_ids.insert(p.id).second, "duplicate expanded projection identity");
        impl->by_plane[index(p.plane)].push_back(i);
        const auto a = impl->mask_index(p.application), e = impl->mask_index(p.exclusion);
        impl->masks.emplace_back(a, e);
        impl->masked_planes[index(p.plane)] = impl->masked_planes[index(p.plane)] || a >= 0 || e >= 0;
    }
    impl->bin_columns = static_cast<std::size_t>((impl->bounds.width + Impl::bin_size - 1) / Impl::bin_size);
    impl->bin_rows = static_cast<std::size_t>((impl->bounds.height + Impl::bin_size - 1) / Impl::bin_size);
    const auto bin_count = impl->bin_columns * impl->bin_rows;
    impl->charge(bin_count * 4, bin_count * sizeof(std::vector<std::size_t>) * 8);
    for (auto& bins : impl->bins) bins.resize(bin_count);
    for (std::size_t i = 0; i < impl->projections.size(); ++i) {
        const auto& p = impl->projections[i];
        const auto left = static_cast<std::size_t>((p.bounds.x - impl->bounds.x) / Impl::bin_size);
        const auto top = static_cast<std::size_t>((p.bounds.y - impl->bounds.y) / Impl::bin_size);
        const auto right = static_cast<std::size_t>((p.bounds.x + p.bounds.width - 1 - impl->bounds.x) / Impl::bin_size);
        const auto bottom = static_cast<std::size_t>((p.bounds.y + p.bounds.height - 1 - impl->bounds.y) / Impl::bin_size);
        impl->charge((right-left+1)*(bottom-top+1)*(8+p.points.size()*16), (right-left+1)*(bottom-top+1)*sizeof(std::size_t)*2);
        for (auto by = top; by <= bottom; ++by) for (auto bx = left; bx <= right; ++bx) {
            if (!p.points.empty()) {
                const auto x0=impl->bounds.x+static_cast<std::int64_t>(bx)*Impl::bin_size;
                const auto y0=impl->bounds.y+static_cast<std::int64_t>(by)*Impl::bin_size;
                const auto x1=std::min(x0+Impl::bin_size,impl->bounds.x+impl->bounds.width);
                const auto y1=std::min(y0+Impl::bin_size,impl->bounds.y+impl->bounds.height);
                const auto radius=static_cast<std::int64_t>(p.route_width/2);
                bool intersects=false;
                for (std::size_t point=1;point<p.points.size();++point) {
                    const auto a=p.points[point-1], b=p.points[point];
                    if (x0<=static_cast<std::int64_t>(std::max(a.x,b.x))+radius &&
                        x1>static_cast<std::int64_t>(std::min(a.x,b.x))-radius &&
                        y0<=static_cast<std::int64_t>(std::max(a.y,b.y))+radius &&
                        y1>static_cast<std::int64_t>(std::min(a.y,b.y))-radius) {intersects=true;break;}
                }
                if (!intersects) continue;
            }
            impl->bins[index(p.plane)][by*impl->bin_columns+bx].push_back(i);
        }
    }
    // A bundle samples all four planes at one coordinate. Bound that sum in
    // each co-located bin, then choose the largest bin; separate plane maxima
    // may occur at different coordinates and need not be added. Every term is
    // non-negative, so this also conservatively bounds a single-plane stage.
    // Observed candidate counts remain separate from this logical work bound.
    for (std::size_t bin = 0; bin < bin_count; ++bin) {
        std::uint64_t work = 0;
        for (const auto& bins : impl->bins) {
            for (const auto i : bins[bin]) {
                const auto& p = impl->projections[i];
                work += p.shape == ProjectionShape::Native || p.shape == ProjectionShape::Omit ? 4 : 64 + p.points.size()*16;
            }
        }
        impl->cost = std::max(impl->cost, work);
    }
    for (bool masked : impl->masked_planes) if (masked) impl->cost += impl->generator->spatial_graph().operations_per_sample();
    // A named region always declares atmospheric and distant composition,
    // including an explicit Omit record when the intended space is empty.
    for (const auto& f : plan.features()) if (f.kind == SemanticKind::Region) {
        for (auto plane : {Plane::Effects, Plane::Background}) {
            impl->charge(impl->projections.size());
            need(std::any_of(impl->projections.begin(), impl->projections.end(), [&](const auto& p) {
                return p.feature_id == f.id && p.plane == plane;
            }), "region lacks explicit atmosphere/far composition: " + f.id);
        }
    }
    std::uint64_t fixture_writes = 0;
    const RectI64 guarded{impl->bounds.x + 1, impl->bounds.y + 1, impl->bounds.width - 2, impl->bounds.height - 2};
    for (const auto& t : definition.fixtures) {
        need(plane_valid(t.plane) && t.plane != Plane::Background, "fixtures cannot write frozen background");
        need(parse_fixture_mode(fixture_mode_name(t.mode)).has_value() && material_valid(t.material), "invalid fixture mode/material");
        need(t.plane != Plane::Effects || effects_material(t.material), "effects fixture material is unsupported");
        need(t.mode != FixtureMode::Drain || t.material == Material::Empty, "drain fixture must remove to Empty");
        need(t.mode != FixtureMode::Source || t.material != Material::Empty, "source fixture requires a reagent");
        need(t.period > 0 && t.period <= max_tick && t.repeat > 0 && t.repeat <= 10000 && t.first_tick <= max_tick,
            "invalid finite fixture schedule");
        need(t.mode != FixtureMode::Setup || (t.first_tick == 0 && t.repeat == 1), "setup fixture runs once at installation tick zero");
        need(t.mode == FixtureMode::Setup || t.first_tick > 0, "source/drain schedules start after installation");
        need(t.repeat - 1 <= (max_tick - t.first_tick) / t.period, "fixture schedule exceeds finite clock domain");
        const auto last_tick = t.first_tick + (t.repeat - 1) * t.period;
        need(t.cleanup_tick == 0 || (t.cleanup_tick > last_tick && t.cleanup_tick <= max_tick), "cleanup must follow the final feed");
        need(t.expected_products.size() <= 16, "fixture product diagnostic budget exceeded");
        for (auto m : t.expected_products) need(material_valid(m) && m != Material::Empty && m != t.material,
            "expected native product must differ from the supplied reagent and Empty");
        std::size_t matched = 0;
        for (const auto& feature : plan.features()) {
            impl->charge(1); if (!matches(feature, t.rule)) continue; ++matched;
            need(impl->fixtures.size() < definition.limits.max_fixtures, "fixture record budget exhausted");
            need(impl->endpoint(feature.id, t.plane), "fixture has no corresponding feature-plane projection");
            PlaneFixture f; f.id = record_id(feature.id, "fixture", t.id); f.adapter = t.id; f.feature_id = feature.id;
            f.plane = t.plane; f.clock.append(plane_name(t.plane)); f.bounds = local_bounds(feature.bounds, t.bounds);
            need(encloses(guarded, f.bounds), "fixture touches the plane guard");
            f.owner = feature.owner; f.material = t.material; f.mode = t.mode;
            f.first_tick = t.first_tick; f.period = t.period; f.repeat = t.repeat; f.cleanup_tick = t.cleanup_tick;
            f.expected_products = t.expected_products;
            std::sort(f.expected_products.begin(), f.expected_products.end());
            need(std::adjacent_find(f.expected_products.begin(), f.expected_products.end()) == f.expected_products.end(),
                "duplicate expected native product");
            f.revision = fixture_hash(f, feature.revision, definition.revision);
            const auto writes = area(f.bounds) * (f.repeat + (f.cleanup_tick > 0 ? 1 : 0));
            need(writes <= definition.limits.max_fixture_cell_writes - fixture_writes, "finite fixture cell-write budget exhausted");
            fixture_writes += writes;
            const auto memory = sizeof(f) * 2 + (f.id.size() + f.adapter.size() + f.feature_id.size() +
                f.clock.size() + f.lifecycle.size()) * 2 + f.expected_products.size() * 2;
            impl->charge(64 + impl->projections.size(), memory, memory); impl->fixtures.push_back(std::move(f));
        }
        need(matched > 0, "fixture selector has no feature: " + t.rule);
    }
    std::sort(impl->fixtures.begin(), impl->fixtures.end(), [](const auto& a, const auto& b) { return a.id < b.id; });
    std::uint64_t events = 0;
    for (const auto& t : definition.links) {
        need(plane_valid(t.source_plane) && plane_valid(t.target_plane) && material_valid(t.material), "invalid link endpoint plane/material");
        need(parse_link_family(link_family_name(t.family)).has_value() && parse_link_class(link_class_name(t.classification)).has_value(),
            "unsupported semantic link family/classification");
        if (!t.target_rule.empty()) selector(t.target_rule);
        if (!t.fixture.empty()) identifier(t.fixture);
        need(t.target_slot < 2048 && t.effect.size() <= 32, "link parameter budget exceeded");
        bool permitted = false;
        if (t.family == LinkFamily::Explosion) permitted = t.classification == LinkClass::Runtime &&
            t.source_plane == Plane::Play && t.target_plane == Plane::Scripted && t.effect == "blast" && t.material == Material::Fire;
        if (t.family == LinkFamily::Vent) permitted = t.target_plane == Plane::Effects &&
            ((t.classification == LinkClass::Runtime && t.source_plane == Plane::Scripted && t.effect == "burst" && effects_material(t.material)) ||
             (t.classification == LinkClass::Static && (t.source_plane == Plane::Play || t.source_plane == Plane::Scripted) &&
              (t.effect == "source" || t.effect == "drain") && !t.fixture.empty()));
        if (t.family == LinkFamily::Window) permitted = t.classification == LinkClass::Presentation &&
            t.source_plane == Plane::Play && t.target_plane == Plane::Background && t.effect == "visibility";
        if (t.family == LinkFamily::Pipe || t.family == LinkFamily::Machinery) permitted = t.classification == LinkClass::Static &&
            t.source_plane == Plane::Play && t.target_plane == Plane::Scripted && t.effect == "correspondence";
        if (t.family == LinkFamily::Waterfall) permitted = t.classification == LinkClass::Static &&
            t.source_plane == Plane::Play && t.target_plane == Plane::Effects && t.effect == "source_and_spray" && !t.fixture.empty();
        need(permitted, "unsupported semantic link classification, effect or direction: " + t.id);
        need(t.radius <= 32 && t.max_events_per_tick > 0 && t.max_events_per_tick <= 32, "link event radius/rate exceeds budget");
        need(t.family != LinkFamily::Explosion || t.radius >= 4, "blast radius must be at least four cells");
        need(t.classification == LinkClass::Runtime || t.radius == 0, "static/presentation links cannot carry runtime radius");
        std::size_t matched = 0;
        for (const auto& from : plan.features()) {
            impl->charge(1); if (!matches(from, t.rule)) continue; ++matched;
            need(impl->links.size() < definition.limits.max_links, "link record budget exhausted");
            const SemanticFeature* to = &from;
            if (!t.target_rule.empty()) {
                to = nullptr;
                auto suffix = std::string("/"); suffix.append(t.target_rule).append("/").append(std::to_string(t.target_slot));
                for (const auto& f : plan.features()) {
                    impl->charge(1);
                    if (f.owner != from.owner || !matches(f, t.target_rule) ||
                        (t.target_rule != "$region" && !f.id.ends_with(suffix))) continue;
                    need(to == nullptr, "ambiguous target feature selector"); to = &f;
                }
                need(to != nullptr, "semantic link target feature is missing");
            }
            need(impl->endpoint(from.id, t.source_plane) && impl->endpoint(to->id, t.target_plane),
                "semantic link endpoint has no corresponding plane projection");
            PlaneLink k; k.id = record_id(from.id, "link", t.id); k.adapter = t.id;
            k.source_feature = from.id; k.target_feature = to->id; k.family = t.family; k.classification = t.classification;
            k.source_plane = t.source_plane; k.target_plane = t.target_plane; k.effect = t.effect;
            k.bounds = local_bounds(to->bounds, t.bounds); k.owner = from.owner; k.material = t.material;
            k.radius = t.radius; k.max_events_per_tick = t.max_events_per_tick;
            if (t.classification == LinkClass::Runtime) {
                need(encloses(guarded, k.bounds) && k.bounds.width >= 2 * t.radius + 1 && k.bounds.height >= 2 * t.radius + 1,
                    "runtime effect zone cannot contain its bounded disc or touches guard");
                need(t.max_events_per_tick <= definition.limits.max_events_per_tick - events, "aggregate runtime event-rate budget exhausted");
                events += t.max_events_per_tick;
            }
            if (!t.fixture.empty()) {
                k.fixture_id = record_id(to->id, "fixture", t.fixture);
                const auto found = std::find_if(impl->fixtures.begin(), impl->fixtures.end(), [&](const auto& f) { return f.id == k.fixture_id; });
                need(found != impl->fixtures.end() && found->plane == t.target_plane && encloses(k.bounds, found->bounds),
                    "linked target fixture is missing, on another plane or outside effect bounds");
                need(t.family != LinkFamily::Vent || t.classification != LinkClass::Static ||
                    (t.effect == "drain" ? found->mode == FixtureMode::Drain : found->mode == FixtureMode::Source),
                    "vent effect does not match target programme");
            }
            if (t.family == LinkFamily::Waterfall) need(std::any_of(impl->fixtures.begin(), impl->fixtures.end(), [&](const auto& f) {
                return f.feature_id == from.id && f.plane == Plane::Play && f.mode == FixtureMode::Source && f.material == Material::Water;
            }), "waterfall has no corresponding play Water source");
            k.revision = link_hash(k, from.revision, to->revision, definition.revision);
            const auto memory = sizeof(k) * 2 + (k.id.size() + k.adapter.size() + k.source_feature.size() + k.target_feature.size() +
                k.effect.size() + k.fixture_id.size() + k.lifecycle.size()) * 2;
            impl->charge(64 + impl->projections.size() * 2 + impl->fixtures.size() * 2, memory, memory);
            impl->links.push_back(std::move(k));
        }
        need(matched > 0, "link selector has no feature: " + t.rule);
    }
    std::sort(impl->links.begin(), impl->links.end(), [](const auto& a, const auto& b) { return a.id < b.id; });
    for (const auto& t : definition.actors) {
        identifier(t.model);
        need(t.plane == Plane::Play && (t.producer == "policy" || t.producer == "demo"),
            "actor placement requires the existing play owner and policy/demo producer");
        std::size_t matched = 0;
        for (const auto& f : plan.features()) {
            impl->charge(1); if (!matches(f, t.rule)) continue; ++matched;
            need(impl->actors.size() < definition.limits.max_actors, "actor placement budget exhausted");
            const auto point = local_bounds(f.bounds, {t.x, t.y, 1, 1});
            need(encloses(guarded, point) && impl->endpoint(f.id, Plane::Play), "actor placement has no bounded play projection");
            PlaneActor a; a.id = record_id(f.id, "actor", t.id); a.adapter = t.id; a.feature_id = f.id;
            a.model = t.model; a.producer = t.producer; a.plane = Plane::Play;
            a.x = point.x; a.y = point.y; a.owner = f.owner;
            auto h = fnv; text(h, a.id); text(h, a.model); text(h, a.producer); text(h, a.lifecycle);
            word(h, f.revision); word(h, definition.revision); rect_hash(h, point); a.revision = h;
            const auto memory = sizeof(a) * 2 + (a.id.size() + a.adapter.size() + a.feature_id.size() +
                a.model.size() + a.producer.size() + a.lifecycle.size()) * 2;
            impl->charge(64 + impl->projections.size(), memory, memory); impl->actors.push_back(std::move(a));
        }
        need(matched > 0, "actor selector has no feature: " + t.rule);
    }
    std::sort(impl->actors.begin(), impl->actors.end(), [](const auto& a, const auto& b) { return a.id < b.id; });
    // Final registration filtering and receipt hashing are fixed request work,
    // charged even for a one-cell tile rather than hidden behind raster cost.
    impl->publication_work = 128;
    for (const auto& f : impl->fixtures) impl->publication_work += 32 + f.id.size();
    for (const auto& k : impl->links) impl->publication_work += 32 + k.id.size();
    for (const auto& a : impl->actors) impl->publication_work += 32 + a.id.size();
    // Memory includes all four copied arrays plus an equal-sized publication
    // staging allowance. Host rectangle packets have their separate stricter cap.
    const auto publication = area(impl->bounds) * sizeof(Material) * 8 + impl->diagnostics * 2;
    need(publication <= definition.limits.max_publication_bytes, "complete bundle publication memory budget exhausted");
    impl->cost += 128 + impl->generator->recipe().overrides.size() * 16;
    if (definition.policies[0].base_generator) impl->cost += impl->generator->operations_per_cell();
    if (impl->publication_work > definition.limits.max_operations ||
        impl->cost > (definition.limits.max_operations - impl->publication_work) / area(impl->bounds)) {
        std::string detail("complete bundle raster work budget exhausted: cells=");
        detail.append(std::to_string(area(impl->bounds))).append(" per_cell=").append(std::to_string(impl->cost));
        detail.append(" publication=").append(std::to_string(impl->publication_work));
        detail.append(" maximum=").append(std::to_string(definition.limits.max_operations));
        need(false, detail);
    }
    impl->charge(impl->projections.size() * sizeof(std::size_t),
        impl->projections.size() * (sizeof(std::size_t) + sizeof(std::pair<int, int>)) * 2);
    auto& h = impl->fingerprint; word(h, kPlaneAlgorithmVersion); word(h, definition.schema); text(h, definition.id);
    word(h, definition.revision); word(h, impl->generator->fingerprint()); rect_hash(h, impl->bounds);
    for (const auto& p : definition.policies) {
        word(h, static_cast<unsigned>(p.plane)); word(h, static_cast<unsigned>(p.material)); word(h, p.base_generator);
        word(h, p.rate); text(h, p.omission);
    }
    for (const auto& p : impl->projections) word(h, p.revision);
    for (const auto& f : impl->fixtures) word(h, f.revision);
    for (const auto& k : impl->links) word(h, k.revision);
    for (const auto& a : impl->actors) word(h, a.revision);
    // Limits govern admission but do not change semantic content/identity.
    return std::shared_ptr<const PlanePlan>(new PlanePlan(std::move(impl)));
}

PlanePlan::PlanePlan(std::unique_ptr<Impl> impl) : impl_(std::move(impl)) {}
PlanePlan::~PlanePlan() = default;
const PlaneDefinition& PlanePlan::definition() const noexcept { return impl_->definition; }
const Generator& PlanePlan::generator() const noexcept { return *impl_->generator; }
const std::vector<PlaneProjection>& PlanePlan::projections() const noexcept { return impl_->projections; }
const std::vector<PlaneFixture>& PlanePlan::fixtures() const noexcept { return impl_->fixtures; }
const std::vector<PlaneLink>& PlanePlan::links() const noexcept { return impl_->links; }
const std::vector<PlaneActor>& PlanePlan::actors() const noexcept { return impl_->actors; }
RectI64 PlanePlan::bounds() const noexcept { return impl_->bounds; }
std::uint64_t PlanePlan::fingerprint() const noexcept { return impl_->fingerprint; }
std::uint64_t PlanePlan::preparation_work() const noexcept { return impl_->work; }
std::uint64_t PlanePlan::operations_per_cell() const noexcept { return impl_->cost; }
GenerationIndexInfo PlanePlan::index_info() const noexcept {
    GenerationIndexInfo result;
    for(const auto& plane:impl_->bins) {
        result.bins+=plane.size();
        for(const auto& bin:plane) {
            result.entries+=bin.size(); result.maximum_candidates=std::max(result.maximum_candidates,bin.size());
        }
    }
    return result;
}
std::size_t PlanePlan::storage_bytes() const noexcept { return impl_->bytes; }
Material PlanePlan::Impl::sample(Plane plane, std::int64_t x, std::int64_t y, PlaneCellProvenance* trace, PlaneStages* stages) const {
    const auto n = index(plane); need(contains(bounds, x, y), "sample lies outside finite semantic window");
    const auto& policy = definition.policies[n];
    PlaneStages snapshots;
    snapshots.policy = policy.material; snapshots.has_source = policy.base_generator;
    SpatialValues values;
    if (masked_planes[n]) generator->spatial_graph().evaluate(x, y, values);
    auto result = policy.material;
    if (policy.base_generator) {
        if (trace) {
            trace->source = generator->explain(x, y);
            result = trace->source->material; snapshots.source = trace->source->stages;
        } else if (stages) {
            snapshots.source = generator->stages(x, y); result = snapshots.source.at(GenerationStage::Final);
        } else result = generator->sample(x, y);
    }
    snapshots.base = result;
    const auto room = [&](std::size_t count) {
        if (count < kMaxTraceEntries) return true;
        trace->truncated = true; ++trace->omitted_entries; return false;
    };
    const auto record = [&](const char* stage, const std::string& id, Material next, double influence) {
        if (trace && room(trace->contributions.size())) trace->contributions.push_back({stage, id, result, next, influence});
        result = next;
    };
    std::set<std::string> features;
    const auto add_feature = [&](const std::string& id) {
        if (features.contains(id)) return;
        if (room(features.size())) features.insert(id);
    };
    for (auto i : candidates(plane, x, y)) {
        ++snapshots.projection_checks;
        const auto& p = projections[i];
        const auto influence = mask_influence(i, values);
        const bool metadata_only = p.shape == ProjectionShape::Omit || p.shape == ProjectionShape::Native;
        const bool accepted = !metadata_only && projection_contains(p, x, y, influence);
        if (trace && contains(p.bounds, x, y)) {
            if (room(trace->decisions.size())) {
                EvaluationDecision entry;
                entry.stage = "plane_projection"; entry.id = p.id;
                entry.application = p.application; entry.exclusion = p.exclusion;
                const auto [a, e] = masks[i];
                entry.application_value = a < 0 ? 1 : values.values[static_cast<std::size_t>(a)].x;
                entry.exclusion_value = e < 0 ? 0 : values.values[static_cast<std::size_t>(e)].x;
                entry.strength = p.density; entry.influence = p.density * influence;
                auto draw_hash = p.seed; word(draw_hash, static_cast<std::uint64_t>(x)); word(draw_hash, static_cast<std::uint64_t>(y));
                entry.draw = static_cast<double>(draw_hash >> 32) / 4294967296.0;
                entry.shape = projection_footprint_contains(p, x, y) ? 1 : 0;
                entry.draw_used = !metadata_only && entry.shape != 0 && entry.influence != 1;
                entry.accepted = accepted;
                entry.detail = p.shape == ProjectionShape::Omit ? "intentional omission: " + p.omission :
                    p.shape == ProjectionShape::Native ? "base generator metadata; see source trace" :
                    accepted ? "projection applied in canonical priority/id order" : "route geometry/mask/density rejected";
                trace->decisions.push_back(std::move(entry));
            }
            if (accepted) {
                if (room(trace->projections.size())) trace->projections.push_back(p.id);
                add_feature(p.feature_id);
            }
        }
        if (accepted) record("plane_projection", p.id, projection_material(p, x, y), p.density * influence);
    }
    snapshots.projections = result;
    if (plane == Plane::Play) for (const auto& hard : generator->recipe().overrides)
        if (hard.material && contains(hard.bounds, x, y)) record("hard_override", hard.id, *hard.material, 1);
    snapshots.final = result;
    if (stages) *stages = snapshots;
    if (trace) {
        trace->stages = snapshots; trace->material = result;
        for (const auto& f : fixtures) if (f.plane == plane && contains(f.bounds, x, y)) {
            if (room(trace->fixtures.size())) trace->fixtures.push_back(f.id);
            add_feature(f.feature_id);
        }
        for (const auto& k : links) if (k.target_plane == plane && contains(k.bounds, x, y))
            if (room(trace->links.size())) trace->links.push_back(k.id);
        for (const auto& a : actors) if (a.plane == plane && a.x == x && a.y == y) {
            if (room(trace->actors.size())) trace->actors.push_back(a.id);
            add_feature(a.feature_id);
        }
        if (trace->source && !trace->source->accepted_feature_id.empty()) add_feature(trace->source->accepted_feature_id);
        trace->features.assign(features.begin(), features.end());
        auto h = fnv; word(h, fingerprint); word(h, definition.revision); word(h, n);
        word(h, static_cast<std::uint64_t>(x)); word(h, static_cast<std::uint64_t>(y)); word(h, static_cast<unsigned>(result));
        trace->proposal_hash = h;
    }
    return result;
}
Material PlanePlan::sample(Plane plane, std::int64_t x, std::int64_t y) const {
    return impl_->sample(plane, x, y, nullptr, nullptr);
}
PlaneCellProvenance PlanePlan::explain(Plane plane, std::int64_t x, std::int64_t y) const {
    PlaneCellProvenance result; result.plane = plane; result.x = x; result.y = y;
    (void)impl_->sample(plane, x, y, &result, nullptr);
    return result;
}
PlaneStages PlanePlan::stages(Plane plane, std::int64_t x, std::int64_t y) const {
    PlaneStages result;
    (void)impl_->sample(plane, x, y, nullptr, &result);
    return result;
}
std::unique_ptr<PlaneGenerationJob> PlanePlan::begin(RectI64 bounds) const {
    return std::unique_ptr<PlaneGenerationJob>(new PlaneGenerationJob(shared_from_this(), bounds));
}
PlaneResult PlanePlan::generate(RectI64 bounds) const {
    auto job = begin(bounds); (void)job->advance(static_cast<std::size_t>(area(bounds))); return job->result();
}
bool PlanePlan::accepts(const PlaneResult& r) const noexcept {
    if (r.state != ResultState::Ready || r.revision != definition().revision || r.fingerprint != fingerprint() ||
        !valid_rect(r.bounds) || !encloses(bounds(), r.bounds) || area(r.bounds) > definition().limits.max_cells_per_plane ||
        r.operations != area(r.bounds) * operations_per_cell() + impl_->publication_work || !r.error.empty()) return false;
    for (std::size_t i = 0; i < 4; ++i) {
        if (r.cells[i].size() != area(r.bounds) || r.content_hashes[i] != payload_hash(r.cells[i])) return false;
        for (auto m : r.cells[i]) if (!material_valid(m)) return false;
    }
    std::size_t cursor = 0;
    for (const auto& f : fixtures()) if (contains(r.bounds, f.bounds.x, f.bounds.y)) {
        if (cursor >= r.fixture_ids.size() || r.fixture_ids[cursor++] != f.id) return false;
    }
    if (cursor != r.fixture_ids.size()) return false;
    cursor = 0;
    for (const auto& k : links()) if (contains(r.bounds, k.bounds.x, k.bounds.y)) {
        if (cursor >= r.link_ids.size() || r.link_ids[cursor++] != k.id) return false;
    }
    if (cursor != r.link_ids.size()) return false;
    cursor = 0;
    for (const auto& a : actors()) if (contains(r.bounds, a.x, a.y)) {
        if (cursor >= r.actor_ids.size() || r.actor_ids[cursor++] != a.id) return false;
    }
    return cursor == r.actor_ids.size() && r.receipt_hash == result_receipt(r);
}

PlaneGenerationJob::PlaneGenerationJob(std::shared_ptr<const PlanePlan> plan, RectI64 bounds) : plan_(std::move(plan)) {
    need(valid_rect(bounds) && encloses(plan_->bounds(), bounds), "request rectangle leaves finite semantic window");
    result_.bounds = bounds; result_.revision = plan_->definition().revision; result_.fingerprint = plan_->fingerprint();
    const auto count = area(bounds);
    need(count <= plan_->definition().limits.max_cells_per_plane &&
        plan_->impl_->publication_work <= plan_->definition().limits.max_operations &&
        plan_->operations_per_cell() <= (plan_->definition().limits.max_operations - plan_->impl_->publication_work) / count,
        "request budget exceeded");
    for (auto& cells : result_.cells) cells.resize(static_cast<std::size_t>(count));
    result_.error.reserve(256);
}
PlaneGenerationJob::~PlaneGenerationJob() = default;
ResultState PlaneGenerationJob::advance(std::size_t budget) {
    if (result_.state != ResultState::Pending || budget == 0) return result_.state;
    const auto end = cursor_ + std::min(budget, result_.cells[0].size() - cursor_);
    try {
        const auto width = static_cast<std::size_t>(result_.bounds.width);
        while (cursor_ < end) {
            const auto x = result_.bounds.x + static_cast<std::int64_t>(cursor_ % width);
            const auto y = result_.bounds.y + static_cast<std::int64_t>(cursor_ / width);
            for (unsigned p = 0; p < 4; ++p) result_.cells[p][cursor_] = plan_->sample(static_cast<Plane>(p), x, y);
            result_.operations += plan_->operations_per_cell(); ++cursor_;
        }
        if (cursor_ == result_.cells[0].size()) {
            for (const auto& f : plan_->fixtures()) if (contains(result_.bounds, f.bounds.x, f.bounds.y)) result_.fixture_ids.push_back(f.id);
            for (const auto& k : plan_->links()) if (contains(result_.bounds, k.bounds.x, k.bounds.y)) result_.link_ids.push_back(k.id);
            for (const auto& a : plan_->actors()) if (contains(result_.bounds, a.x, a.y)) result_.actor_ids.push_back(a.id);
            for (std::size_t p = 0; p < 4; ++p) result_.content_hashes[p] = payload_hash(result_.cells[p]);
            result_.operations += plan_->impl_->publication_work;
            result_.receipt_hash = result_receipt(result_); result_.state = ResultState::Ready;
        }
    } catch (const std::exception& e) { discard(result_, ResultState::Failed); result_.error = std::string(e.what()).substr(0, 255); }
    catch (...) { discard(result_, ResultState::Failed); result_.error.clear(); result_.error.append("unknown generation failure"); }
    return result_.state;
}
void PlaneGenerationJob::cancel() noexcept { if (result_.state == ResultState::Pending) discard(result_, ResultState::Cancelled); }
ResultState PlaneGenerationJob::state() const noexcept { return result_.state; }
std::size_t PlaneGenerationJob::completed_cells() const noexcept { return cursor_; }
const PlaneResult& PlaneGenerationJob::result() const { need(result_.state != ResultState::Pending, "partial bundle is not publishable"); return result_; }

const char* plane_name(Plane value) noexcept {
    switch (value) { case Plane::Play: return "play"; case Plane::Scripted: return "scripted";
        case Plane::Effects: return "effects"; case Plane::Background: return "background"; } return "invalid";
}
std::optional<Plane> parse_plane(const std::string& name) noexcept {
    for (auto p : {Plane::Play, Plane::Scripted, Plane::Effects, Plane::Background}) if (name == plane_name(p)) return p;
    return {};
}
const char* projection_shape_name(ProjectionShape value) noexcept {
    switch (value) { case ProjectionShape::Fill: return "fill"; case ProjectionShape::Shell: return "shell";
        case ProjectionShape::Omit: return "omit"; case ProjectionShape::Native: return "native"; } return "invalid";
}
std::optional<ProjectionShape> parse_projection_shape(const std::string& name) noexcept {
    for (auto p : {ProjectionShape::Fill, ProjectionShape::Shell, ProjectionShape::Omit, ProjectionShape::Native})
        if (name == projection_shape_name(p)) return p;
    return {};
}
const char* link_family_name(LinkFamily value) noexcept {
    switch (value) { case LinkFamily::Explosion: return "explosion"; case LinkFamily::Vent: return "vent";
        case LinkFamily::Window: return "window"; case LinkFamily::Pipe: return "pipe";
        case LinkFamily::Waterfall: return "waterfall"; case LinkFamily::Machinery: return "machinery"; } return "invalid";
}
std::optional<LinkFamily> parse_link_family(const std::string& name) noexcept {
    for (auto p : {LinkFamily::Explosion, LinkFamily::Vent, LinkFamily::Window, LinkFamily::Pipe, LinkFamily::Waterfall, LinkFamily::Machinery})
        if (name == link_family_name(p)) return p;
    return {};
}
const char* link_class_name(LinkClass value) noexcept {
    switch (value) { case LinkClass::Static: return "static"; case LinkClass::Presentation: return "presentation";
        case LinkClass::Runtime: return "runtime"; } return "invalid";
}
std::optional<LinkClass> parse_link_class(const std::string& name) noexcept {
    for (auto p : {LinkClass::Static, LinkClass::Presentation, LinkClass::Runtime}) if (name == link_class_name(p)) return p;
    return {};
}
const char* fixture_mode_name(FixtureMode value) noexcept {
    switch (value) { case FixtureMode::Source: return "source"; case FixtureMode::Drain: return "drain";
        case FixtureMode::Setup: return "setup"; } return "invalid";
}
std::optional<FixtureMode> parse_fixture_mode(const std::string& name) noexcept {
    for (auto p : {FixtureMode::Source, FixtureMode::Drain, FixtureMode::Setup}) if (name == fixture_mode_name(p)) return p;
    return {};
}

} // namespace cybersand::generation
