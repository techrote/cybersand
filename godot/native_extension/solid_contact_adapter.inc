// SOL281 value-only side channel. Called only by the exclusive native owner.
// Ordinary coupling and conservative material transactions are unchanged.
namespace solid_contact_adapter {
using Vec = cybersand::solid_contact::Vec2;
using Rect = cybersand::solid_contact::OrientedRect;
Vec add(Vec a, Vec b) { return {a.x + b.x, a.y + b.y}; }
Vec mul(Vec a, double s) { return {a.x * s, a.y * s}; }
Vec rotate(Vec a, double c, double s) { return {c * a.x - s * a.y, s * a.x + c * a.y}; }
Vector2 value(Vec p) { return {static_cast<real_t>(p.x), static_cast<real_t>(p.y)}; }
struct EdgeSpan { std::uint16_t begin{}, end{}; };
struct SpanRange { std::uint16_t offset{}, count{}; };
// Clip an actual exterior rectangle edge to the CLOSED native unit square.
// A point-only corner is measured geometrically but is not a support segment.
bool segment_in_cell(Vec a, Vec b, int x, int y, Vec& point, double& length,
                     Vec& clipped_a, Vec& clipped_b) {
    const Vec d{b.x - a.x, b.y - a.y};
    double lo = 0.0, hi = 1.0;
    const auto axis = [&](double origin, double delta, double low, double high) {
        if (std::abs(delta) < 1e-12) return origin >= low - 1e-9 && origin <= high + 1e-9;
        double u = (low - origin) / delta, v = (high - origin) / delta;
        if (u > v) std::swap(u, v);
        lo = std::max(lo, u); hi = std::min(hi, v);
        return hi >= lo;
    };
    if (!axis(a.x, d.x, x, x + 1.0) || !axis(a.y, d.y, y, y + 1.0)) return false;
    length = std::hypot(d.x, d.y) * (hi - lo);
    if (length <= 1e-7) return false;
    clipped_a = add(a, mul(d, lo));
    clipped_b = add(a, mul(d, hi));
    point = add(a, mul(d, (lo + hi) * 0.5));
    return true;
}
} // namespace solid_contact_adapter

Dictionary CyberNativeCellWorld::solid_detachment_contact_observation() const {
    using namespace solid_contact_adapter;
    using cybersand::solid_contact::Outcome;
    constexpr std::size_t max_probes = 8192, max_contacts = 256;
    const auto started = std::chrono::steady_clock::now();
    Dictionary result;
    result["schema"] = "cybersand.sol281.sand-contact.v1";
    result["ok"] = false; result["complete"] = false;
    std::size_t probes = 0, support_probes = 0;
    const auto finish = [&](const char* outcome) {
        result["outcome"] = outcome;
        result["geometry_probes"] = static_cast<std::int64_t>(probes);
        result["support_probes"] = static_cast<std::int64_t>(support_probes);
        result["observation_ms"] = std::chrono::duration<double, std::milli>(
            std::chrono::steady_clock::now() - started).count();
        return result;
    };
    if (!world_ || world_->has_failed()) return finish("WorldUnavailable");
    const auto solid = world_->inspect_solid_detachment();
    if (solid.phase != cybersand::soliding::SolidPhase::Active || solid.body_id == 0 ||
        solid.shape_count == 0 || solid.body_id + solid.shape_count > current_bodies_.size())
        return finish("InactiveAggregate");
    const auto first = static_cast<std::size_t>(solid.body_id);
    const auto count = solid.shape_count;
    if (!current_bodies_[first].valid) return finish("IncompleteOrIncoherentCompound");
    const auto serial = current_bodies_[first].sample_serial;
    if (serial < 0 || serial >= 1'000'000) return finish("InvalidSample");
    std::array<cybersand::soliding::SolidShape, cybersand::soliding::kSolidShapes> shapes{};
    if (world_->copy_solid_detachment_shapes(shapes) != count) return finish("IncompleteShapes");
    std::array<Rect, cybersand::World::kMaximumTransientBodies> rectangles{};
    const double angle = current_bodies_[first].rotation;
    const double c = std::cos(angle), s = std::sin(angle);
    const Vec source_com{static_cast<double>(solid.domain.x) + solid.com_x,
                         static_cast<double>(solid.domain.y) + solid.com_y};
    const Vec first_local{static_cast<double>(shapes[0].x) + shapes[0].width * 0.5 - source_com.x,
                          static_cast<double>(shapes[0].y) + shapes[0].height * 0.5 - source_com.y};
    const Vec rotated_first = rotate(first_local, c, s);
    const Vec center{current_bodies_[first].center.x - rotated_first.x,
                     current_bodies_[first].center.y - rotated_first.y};
    if (!std::isfinite(angle) || !std::isfinite(c) || !std::isfinite(s) ||
        !std::isfinite(center.x) || !std::isfinite(center.y))
        return finish("InvalidGeometry");
    for (std::size_t id = 1; id < current_bodies_.size(); ++id) {
        if (current_bodies_[id].valid && (id < first || id >= first + count))
            return finish("ForeignBody");
    }
    std::array<std::array<int, 4>, cybersand::World::kMaximumTransientBodies> ranges{};
    std::size_t required_probes = 0;
    std::size_t shape_area = 0;
    for (std::size_t i = 0; i < count; ++i) {
        const auto& body = current_bodies_[first + i];
        const auto& shape = shapes[i];
        if (shape.width == 0 || shape.height == 0 ||
            shape.width > cybersand::soliding::kSolidDomainSide ||
            shape.height > cybersand::soliding::kSolidDomainSide ||
            shape.x < 0 || shape.y < 0 || shape.x > kWorldWidth - shape.width ||
            shape.y > kWorldHeight - shape.height)
            return finish("InvalidShapes");
        shape_area += static_cast<std::size_t>(shape.width) * shape.height;
        const Vec local{static_cast<double>(shape.x) + shape.width * 0.5 - source_com.x,
                         static_cast<double>(shape.y) + shape.height * 0.5 - source_com.y};
        const auto expected = add(center, rotate(local, c, s));
        if (!body.valid || body.sample_serial != serial ||
            !std::isfinite(body.rotation) || !std::isfinite(body.center.x) ||
            !std::isfinite(body.center.y) || !std::isfinite(body.half_size.x) ||
            !std::isfinite(body.half_size.y) || !std::isfinite(body.mass) ||
            std::abs(std::remainder(body.rotation - angle, 2.0 * std::numbers::pi)) > 1e-5 ||
            std::hypot(body.center.x - expected.x, body.center.y - expected.y) > 2e-4 ||
            std::abs(body.half_size.x * 2.0 - shape.width) > 1e-6 ||
            std::abs(body.half_size.y * 2.0 - shape.height) > 1e-6 ||
            std::abs(body.mass - shape.width * shape.height) > 1e-5)
            return finish("IncompleteOrIncoherentCompound");
        // All rectangles share ONE reconstructed transform. Independently
        // rounded float32 proxy centers are admission witnesses, not separate
        // shapes that may introduce overlapping/slivered seams in the union.
        const Rect rect{expected, {shape.width * 0.5, shape.height * 0.5}, angle};
        rectangles[i] = rect;
        const double ex = std::abs(c) * rect.half_size.x + std::abs(s) * rect.half_size.y;
        const double ey = std::abs(s) * rect.half_size.x + std::abs(c) * rect.half_size.y;
        const double low_x = rect.center.x - ex - 1e-7, low_y = rect.center.y - ey - 1e-7;
        const double high_x = rect.center.x + ex + 1e-7, high_y = rect.center.y + ey + 1e-7;
        // Check doubles before conversion. A finite packed float (e.g. 1e30)
        // can still be outside int range; casting first would be undefined.
        if (!std::isfinite(low_x) || !std::isfinite(low_y) ||
            !std::isfinite(high_x) || !std::isfinite(high_y) ||
            low_x < 0.0 || low_y < 0.0 || high_x > kWorldWidth || high_y > kWorldHeight ||
            high_x < low_x || high_y < low_y)
            return finish("UnknownBoundary");
        const int x0 = static_cast<int>(std::floor(low_x));
        const int y0 = static_cast<int>(std::floor(low_y));
        const int x1 = static_cast<int>(std::ceil(high_x));
        const int y1 = static_cast<int>(std::ceil(high_y));
        required_probes += static_cast<std::size_t>((x1 - x0) * (y1 - y0));
        if (required_probes > max_probes) return finish("GeometryCapacity");
        ranges[i] = {x0, y0, x1, y1};
    }
    if (shape_area != solid.member_count || shape_area > cybersand::soliding::kSolidMembers)
        return finish("InvalidShapes");
    // Subtract sibling coverage in the exact integer source geometry BEFORE
    // rotating or clipping to cells. A clipped edge can straddle an adjoining
    // proxy's endpoint; a single midpoint must not accept its internal half or
    // discard its exterior half. Unit spans are exact because source members
    // and their lossless rectangle partition use the same integer cell grid.
    constexpr auto max_spans = 4 * cybersand::soliding::kSolidMembers;
    std::array<EdgeSpan, max_spans> spans{};
    std::array<std::array<SpanRange, 4>, cybersand::World::kMaximumTransientBodies> face_spans{};
    std::size_t span_count = 0, exterior_units = 0, internal_units = 0, internal_faces = 0;
    for (std::size_t i = 0; i < count; ++i) {
        const auto& shape = shapes[i];
        for (std::size_t face = 0; face < 4; ++face) {
            const auto units = face % 2 == 0 ? shape.width : shape.height;
            auto& range = face_spans[i][face];
            range.offset = static_cast<std::uint16_t>(span_count);
            std::uint16_t run_begin = 0;
            bool in_run = false;
            for (std::uint16_t unit = 0; unit <= units; ++unit) {
                bool exterior = unit != units;
                if (exterior) {
                    std::int64_t x = 0, y = 0;
                    if (face == 0) { x = shape.x + unit; y = shape.y - 1; }
                    else if (face == 1) { x = shape.x + shape.width; y = shape.y + unit; }
                    else if (face == 2) { x = shape.x + shape.width - 1 - unit; y = shape.y + shape.height; }
                    else { x = shape.x - 1; y = shape.y + shape.height - 1 - unit; }
                    for (std::size_t other = 0; other < count; ++other) {
                        const auto& sibling = shapes[other];
                        if (other != i && x >= sibling.x && y >= sibling.y &&
                            x < sibling.x + sibling.width && y < sibling.y + sibling.height) {
                            exterior = false;
                            break;
                        }
                    }
                    if (exterior) ++exterior_units;
                    else ++internal_units;
                }
                if (exterior && !in_run) { run_begin = unit; in_run = true; }
                if (!exterior && in_run) {
                    if (span_count == spans.size()) return finish("EdgeCapacity");
                    spans[span_count++] = {run_begin, unit};
                    ++range.count;
                    in_run = false;
                }
            }
            if (range.count == 0) ++internal_faces;
        }
    }
    if (exterior_units + internal_units > 4 * solid.member_count)
        return finish("EdgeCapacity");
    result["sample_serial"] = serial;
    result["token"] = solid_adapter::token_text(solid.token);
    result["body_generation"] = solid_adapter::decimal(solid.body_generation);
    result["tick"] = static_cast<std::int64_t>(world_->completed_tick_index());
    result["revision"] = solid_adapter::decimal(static_cast<std::uint64_t>(revision_));
    result["source_transform"] = Transform2D(static_cast<real_t>(angle), value(center));
    Array contacts, proxy_metrics;
    std::array<std::uint32_t, max_probes> occupied{};
    std::size_t occupied_count = 0, unsupported = 0, hot = 0;
    double total_area = 0.0, sand_area = 0.0, water_area = 0.0, max_depth = 0.0;
    double max_sand_depth = 0.0;
    for (std::size_t i = 0; i < count; ++i) {
        const auto& rect = rectangles[i];
        const auto& range = ranges[i];
        const double hx = rect.half_size.x, hy = rect.half_size.y;
        const std::array<Vec, 4> corners{{{-hx,-hy},{hx,-hy},{hx,hy},{-hx,hy}}};
        const std::array<Vec, 4> normals{{{0,-1},{1,0},{0,1},{-1,0}}};
        double proxy_area = 0.0, proxy_depth = 0.0;
        std::size_t proxy_cells = 0;
        for (int y = range[1]; y < range[3]; ++y) for (int x = range[0]; x < range[2]; ++x) {
            ++probes;
            if (!world_->contact_cell_available(x, y)) return finish("UnknownResidency");
            const auto material = world_->stored_material(x, y);
            if (material == cybersand::Material::Empty) continue;
            const auto intersection = cybersand::solid_contact::intersect_unit_square(rect, x, y);
            if (intersection.outcome == Outcome::Invalid) return finish("InvalidGeometry");
            if (intersection.outcome != Outcome::Overlap || intersection.area <= 1e-9) continue;
            occupied[occupied_count++] = static_cast<std::uint32_t>(y * kWorldWidth + x);
            ++proxy_cells;
            proxy_area += intersection.area; total_area += intersection.area;
            proxy_depth = std::max(proxy_depth, intersection.depth);
            max_depth = std::max(max_depth, intersection.depth);
            if (material == cybersand::Material::Water) water_area += intersection.area;
            if (material != cybersand::Material::Sand) { ++unsupported; continue; }
            sand_area += intersection.area;
            max_sand_depth = std::max(max_sand_depth, intersection.depth);
            if (world_->stored_temperature(x, y) != world_->config().ambient_temperature) { ++hot; continue; }
            // The existing support predicate reads this complete 3x3 footprint.
            // It explicitly excludes the aggregate's transient mask as support.
            for (int sy = y; sy <= y + 2; ++sy) for (int sx = x - 1; sx <= x + 1; ++sx) {
                ++support_probes;
                if (!world_->contact_cell_available(sx, sy)) return finish("UnknownSupport");
            }
            if (!world_->granular_support_at(x, y, false, false)) { ++unsupported; continue; }
            for (std::size_t face = 0; face < 4; ++face) {
                const auto& span_range = face_spans[i][face];
                const auto units = static_cast<double>(face % 2 == 0 ? shapes[i].width : shapes[i].height);
                const Vec direction{(corners[(face + 1) % 4].x - corners[face].x) / units,
                                    (corners[(face + 1) % 4].y - corners[face].y) / units};
                for (std::size_t part = 0; part < span_range.count; ++part) {
                    const auto& span = spans[span_range.offset + part];
                    const auto a = add(rect.center, rotate(add(corners[face], mul(direction, span.begin)), c, s));
                    const auto b = add(rect.center, rotate(add(corners[face], mul(direction, span.end)), c, s));
                    Vec point{}, clipped_a{}, clipped_b{}; double length = 0.0;
                    if (!segment_in_cell(a, b, x, y, point, length, clipped_a, clipped_b)) continue;
                    if (contacts.size() >= static_cast<std::int64_t>(max_contacts)) return finish("ContactCapacity");
                    Dictionary contact;
                    contact["proxy"] = static_cast<std::int64_t>(i + 1);
                    contact["face"] = static_cast<std::int64_t>(face);
                    contact["cell"] = Vector2i(x, y);
                    contact["point"] = value(point); contact["normal"] = value(rotate(normals[face], c, s));
                    contact["a"] = value(clipped_a); contact["b"] = value(clipped_b);
                    contact["depth"] = intersection.depth; contact["area"] = intersection.area;
                    contact["weight"] = length;
                    contacts.append(contact);
                }
            }
        }
        Dictionary metric;
        metric["proxy"] = static_cast<std::int64_t>(i + 1);
        metric["area"] = proxy_area; metric["max_depth"] = proxy_depth;
        metric["overlap_cells"] = static_cast<std::int64_t>(proxy_cells);
        proxy_metrics.append(metric);
    }
    std::sort(occupied.begin(), occupied.begin() + static_cast<std::ptrdiff_t>(occupied_count));
    const auto unique_end = std::unique(occupied.begin(), occupied.begin() + static_cast<std::ptrdiff_t>(occupied_count));
    result["overlap_cells"] = static_cast<std::int64_t>(unique_end - occupied.begin());
    result["overlap_area"] = total_area; result["sand_overlap_area"] = sand_area;
    result["water_overlap_area"] = water_area; result["max_penetration"] = max_depth;
    result["max_sand_penetration"] = max_sand_depth;
    result["internal_faces_refused"] = static_cast<std::int64_t>(internal_faces);
    result["internal_edge_units_refused"] = static_cast<std::int64_t>(internal_units);
    result["exterior_edge_units"] = static_cast<std::int64_t>(exterior_units);
    result["exterior_edge_spans"] = static_cast<std::int64_t>(span_count);
    result["unsupported_contacts"] = static_cast<std::int64_t>(unsupported);
    result["hot_contacts"] = static_cast<std::int64_t>(hot);
    result["contacts"] = contacts; result["proxies"] = proxy_metrics;
    result["ok"] = true; result["complete"] = true;
    return finish("Observed");
}
