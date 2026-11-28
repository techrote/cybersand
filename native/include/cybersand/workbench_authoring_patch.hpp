#pragma once

#include "cybersand/material_rules.hpp"
#include "cybersand/water_normalization.hpp"
#include "cybersand/world.hpp"

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <span>
#include <stdexcept>
#include <vector>

namespace cybersand::workbench_authoring {

// Experimental finite construction patch, consumed only while preparing a
// private retained World. This code never mutates source, acquires a live cell
// pointer, changes material laws, or turns a partial write into an acceptance.
inline constexpr std::size_t kMaximumPatchCells = 262144;
struct Point {
    std::int32_t x = 0, y = 0;
    friend bool operator==(const Point&, const Point&) = default;
};
struct Cell {
    Point point;
    Material before = Material::Empty, after = Material::Empty;
};
enum class Operation : std::uint8_t { Build = 1, Remove = 2 };
struct Receipt {
    std::size_t changed = 0;
    Sha256::Digest digest{};
};

inline bool row_before(Point a, Point b) noexcept {
    return a.y < b.y || (a.y == b.y && a.x < b.x);
}

inline bool construction_material(Material material) noexcept {
    // MOSAIC's unchanged native masonry grammar also authors Stone (ID 13).
    // Its production law is Powder; admitting its exact ID claims no stability.
    return MaterialRules::is_hard_surface(material) || material == Material::Stone;
}

inline Receipt stage(const World& source, normalization::FinalSetupInput& input,
                     std::span<const Cell> patch, std::span<const Point> protected_cells,
                     Operation operation) {
    const auto& domain = input.setup.domain;
    if (source.has_failed() || domain.x != 0 || domain.y != 0 || domain.width < 256 ||
        domain.height < 256 || domain.width > 2048 || domain.height > 2048 ||
        domain.width % 64 || domain.height % 64 ||
        input.mass_bits != source.config().water_experiment_policy.mass_bits() ||
        input.ambient_temperature != source.config().ambient_temperature)
        throw std::invalid_argument("Authoring patch requires an unchanged finite retained Workbench");
    if (operation != Operation::Build && operation != Operation::Remove)
        throw std::invalid_argument("Unknown authoring patch operation");
    if (patch.empty() || patch.size() > kMaximumPatchCells ||
        protected_cells.size() > kMaximumPatchCells)
        throw std::length_error("Authoring patch exceeds its 262144-cell limit");
    const auto inside = [&](Point point) {
        return point.x >= 0 && point.y >= 0 &&
            static_cast<std::uint32_t>(point.x) < domain.width &&
            static_cast<std::uint32_t>(point.y) < domain.height;
    };
    Point previous{-1, -1};
    for (const auto point : protected_cells) {
        if (!inside(point) || !row_before(previous, point))
            throw std::invalid_argument("Protected cells must be unique, row-major and in the native canvas");
        previous = point;
    }
    previous = {-1, -1};
    std::size_t guard = 0;
    normalization::detail::CanonicalHash hash;
    hash.tag("cybersand-workbench-authoring-patch-v1");
    hash.integer(static_cast<std::uint8_t>(operation));
    hash.integer(domain.width); hash.integer(domain.height);
    hash.integer(static_cast<std::uint64_t>(patch.size()));
    for (const auto& cell : patch) {
        if (!inside(cell.point) || !row_before(previous, cell.point))
            throw std::invalid_argument("Patch cells must be unique, row-major and in the native canvas");
        previous = cell.point;
        while (guard < protected_cells.size() && row_before(protected_cells[guard], cell.point)) ++guard;
        if (guard < protected_cells.size() && protected_cells[guard] == cell.point)
            throw std::invalid_argument("Authoring patch intersects a protected passage");
        if (!valid_material(static_cast<std::uint16_t>(cell.before)) ||
            !valid_material(static_cast<std::uint16_t>(cell.after)))
            throw std::invalid_argument("Authoring patch contains an unsupported material");
        if (operation == Operation::Build &&
            (cell.before != Material::Empty || cell.after == Material::Empty ||
             !construction_material(cell.after)))
            throw std::invalid_argument("Construction may place structural material only into Empty cells");
        if (operation == Operation::Remove &&
            (cell.after != Material::Empty || cell.before == Material::Empty ||
             !construction_material(cell.before)))
            throw std::invalid_argument("Undo may remove only the exact structural material it installed");
        if (source.transient_obstacle_at(cell.point.x, cell.point.y) != 0)
            throw std::invalid_argument("Authoring patch intersects a native body mask");
        if (source.stored_material(cell.point.x, cell.point.y) != cell.before)
            throw std::invalid_argument("Authoring patch source material is stale or foreign-owned");
        hash.integer(cell.point.x); hash.integer(cell.point.y);
        hash.integer(static_cast<std::uint8_t>(cell.before));
        hash.integer(static_cast<std::uint8_t>(cell.after));
    }
    hash.integer(static_cast<std::uint64_t>(protected_cells.size()));
    for (const auto point : protected_cells) { hash.integer(point.x); hash.integer(point.y); }

    // Validate the private snapshot before constructing its successor. The
    // retained copier is canonical and keeps all nonambient Empty thermal cells.
    const auto capacity = static_cast<std::size_t>(domain.width) * domain.height;
    if (input.cells.size() > capacity)
        throw std::length_error("Retained tuple capacity exceeded");
    previous = {-1, -1};
    for (const auto& cell : input.cells) {
        if (cell.x < 0 || cell.y < 0 || cell.x >= domain.width || cell.y >= domain.height)
            throw std::invalid_argument("Retained tuple is outside the native canvas");
        const Point point{static_cast<std::int32_t>(cell.x), static_cast<std::int32_t>(cell.y)};
        if (!row_before(previous, point))
            throw std::invalid_argument("Retained tuples are not unique and row-major");
        previous = point;
    }
    std::vector<normalization::FinalSetupCell> candidate;
    candidate.reserve(std::min(capacity, input.cells.size() + patch.size()));
    std::size_t old = 0;
    for (const auto& cell : patch) {
        while (old < input.cells.size()) {
            const auto& next = input.cells[old];
            const Point point{static_cast<std::int32_t>(next.x), static_cast<std::int32_t>(next.y)};
            if (!row_before(point, cell.point)) break;
            candidate.push_back(next);
            ++old;
        }
        if (old < input.cells.size() && input.cells[old].x == cell.point.x && input.cells[old].y == cell.point.y)
            ++old;
        const auto temperature = source.stored_temperature(cell.point.x, cell.point.y);
        if (cell.after != Material::Empty || temperature != input.ambient_temperature) {
            const auto& definition = MaterialRules::descriptor(cell.after);
            candidate.push_back({cell.point.x, cell.point.y, cell.after,
                definition.initial_state_a, definition.initial_state_b, temperature});
        }
    }
    candidate.insert(candidate.end(), input.cells.begin() + static_cast<std::ptrdiff_t>(old), input.cells.end());
    if (candidate.size() > capacity) throw std::length_error("Patched tuple capacity exceeded");
    const Receipt receipt{patch.size(), hash.finish()};
    input.cells.swap(candidate); // Only private candidate values change, after every refusal point.
    return receipt;
}

} // namespace cybersand::workbench_authoring
