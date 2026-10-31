// Pure oracle qualification on newly constructed, copied Worlds only. This is
// semantic tuple/temperature validation: public setters cannot import arbitrary
// captured carrier epochs/spare bits. relocate_stored_cell intentionally resets
// scheduling epochs; exact captured-bit conservation is tested by Python copies.
#include "cybersand/world.hpp"
#include "cybersand/material_rules.hpp"
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <set>
#include <stdexcept>
#include <string>
#include <tuple>
#include <utility>
#include <vector>

namespace {
using Point = std::pair<std::int64_t, std::int64_t>;
struct CopiedCell {
    Point point;
    std::uint16_t material = 0, state_a = 0;
    std::uint8_t state_b = 0;
    std::int16_t temperature = 200;
    std::uint16_t body = 0;
};
struct Case {
    std::string id, policy = "forward";
    int cap = 4;
    double normal_x = 1, normal_y = 0;
    std::vector<CopiedCell> cells;
    std::vector<Point> path;
};
using Parcel = std::tuple<std::uint16_t, std::uint16_t, std::uint8_t, std::int16_t>;
using Snapshot = std::vector<std::tuple<Point, Parcel, std::uint16_t>>;
void require(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}
Parcel parcel(const cybersand::World& world, Point point) {
    return {static_cast<std::uint16_t>(world.stored_material(point.first, point.second)),
            world.stored_state_a(point.first, point.second), world.stored_state_b(point.first, point.second),
            world.stored_temperature(point.first, point.second)};
}
Snapshot snapshot(const cybersand::World& world, const Case& test) {
    Snapshot out;
    for (const auto& cell : test.cells)
        out.emplace_back(cell.point, parcel(world, cell.point),
            world.transient_obstacle_at(cell.point.first, cell.point.second));
    return out;
}
std::vector<Parcel> parcels(const Snapshot& state) {
    std::vector<Parcel> out;
    for (const auto& [point, value, mask] : state) {
        (void)point; (void)mask;
        if (std::get<0>(value) != 0) out.push_back(value);
    }
    std::sort(out.begin(), out.end());
    return out;
}
std::uint64_t water_quantity(const Snapshot& state) {
    std::uint64_t out = 0;
    for (const auto& [point, value, mask] : state) {
        (void)point; (void)mask;
        if (std::get<0>(value) == static_cast<std::uint16_t>(cybersand::Material::Water))
            out += std::get<1>(value);
    }
    return out;
}
std::size_t overlaps(const Snapshot& state) {
    return static_cast<std::size_t>(std::count_if(state.begin(), state.end(), [](const auto& item) {
        return std::get<0>(std::get<1>(item)) != 0 && std::get<2>(item) != 0;
    }));
}
std::string validate(const cybersand::World& world, const Case& test, const std::set<Point>& copied,
                     const cybersand::RectI64& domain) {
    if (test.cap < 1 || test.cap > 4 || test.path.size() < 2 || test.path.size() > static_cast<std::size_t>(test.cap + 1))
        return "chain_cap";
    if (test.policy != "forward" && test.policy != "forward_lateral") return "policy";
    if (!std::isfinite(test.normal_x) || !std::isfinite(test.normal_y) ||
        std::hypot(test.normal_x, test.normal_y) < .5) return "normal";
    std::set<Point> visited;
    for (std::size_t i = 0; i < test.path.size(); ++i) {
        const auto p = test.path[i];
        if (!copied.contains(p)) return "outside_copy";
        // Full captured rectangle includes a diagnostic-only one-cell ring.
        // A legal oracle chain remains in its production-neighbourhood interior.
        if (p.first <= domain.x || p.first >= domain.x + domain.width - 1 ||
            p.second <= domain.y || p.second >= domain.y + domain.height - 1) return "diagnostic_outer_ring";
        if (!visited.insert(p).second) return "overlapping_path";
        const auto material = world.stored_material(p.first, p.second);
        const auto body = world.transient_obstacle_at(p.first, p.second);
        if (i == 0) {
            if (body == 0) return "source_not_overlapping";
        } else {
            if (body != 0) return "masked_destination";
            const auto previous = test.path[i - 1];
            const auto dx = p.first - previous.first, dy = p.second - previous.second;
            if (std::abs(dx) + std::abs(dy) != 1) return "not_four_connected";
            const auto dot = static_cast<double>(dx) * test.normal_x + static_cast<double>(dy) * test.normal_y;
            if (test.policy == "forward" ? dot <= 0 : dot < 0) return "rear_or_disallowed_lateral_hop";
        }
        if (i + 1 == test.path.size()) {
            if (material != cybersand::Material::Empty) return "no_terminal_void";
        } else {
            if (cybersand::MaterialRules::is_hard_surface(material)) return "hard_barrier";
            if (material == cybersand::Material::Empty || !cybersand::MaterialRules::descriptor(material).movable)
                return "nonmovable_parcel";
        }
    }
    return {};
}

void run_case(const Case& test, bool expected_legal) {
    require(!test.cells.empty(), test.id + ": empty copied state");
    auto left = test.cells[0].point.first, right = left;
    auto top = test.cells[0].point.second, bottom = top;
    std::set<Point> copied;
    for (const auto& cell : test.cells) {
        require(copied.insert(cell.point).second, test.id + ": duplicate imported coordinate");
        left = std::min(left, cell.point.first); right = std::max(right, cell.point.first);
        top = std::min(top, cell.point.second); bottom = std::max(bottom, cell.point.second);
    }
    require(right - left < 128 && bottom - top < 128, test.id + ": oversized copied domain");
    require(static_cast<std::size_t>((right - left + 1) * (bottom - top + 1)) == copied.size(),
            test.id + ": copied rectangle has holes");
    cybersand::WorldConfig config;
    config.initial_chunk_reserve = 4;
    config.maximum_chunk_count = 16;
    cybersand::World world(config);
    const cybersand::RectI64 domain{left, top, right - left + 1, bottom - top + 1};
    world.reserve_region(domain);
    world.reserve_temperature_region(domain);
    world.configure_transient_obstacles(domain);
    for (const auto& cell : test.cells) {
        require(cybersand::valid_material(cell.material), test.id + ": invalid imported material");
        // The setter returns false for an already-equal value as well as a
        // refusal. Compare copied state, rather than treating a no-op as failure.
        (void)world.set_cell_state(cell.point.first, cell.point.second,
            static_cast<cybersand::Material>(cell.material), cell.state_a, cell.state_b);
        world.set_temperature(cell.point.first, cell.point.second, cell.temperature);
        require(parcel(world, cell.point) == Parcel{cell.material,cell.state_a,cell.state_b,cell.temperature},
                test.id + ": semantic tuple import refused");
    }
    for (const auto& cell : test.cells)
        if (cell.body != 0)
            require(world.set_transient_obstacle(cell.point.first, cell.point.second, cell.body), test.id + ": mask import refused");
    const auto before = snapshot(world, test);
    const auto rejection = validate(world, test, copied, domain);
    require(expected_legal == rejection.empty(), test.id + ": unexpected validator outcome: " + rejection);
    if (!rejection.empty()) {
        require(before == snapshot(world, test), test.id + ": refusal mutated copied World");
        return;
    }
    std::vector<Parcel> expected;
    for (std::size_t i = 0; i + 1 < test.path.size(); ++i) expected.push_back(parcel(world, test.path[i]));
    for (std::size_t i = test.path.size() - 1; i > 0; --i)
        require(world.relocate_stored_cell(test.path[i - 1].first, test.path[i - 1].second,
                                           test.path[i].first, test.path[i].second), test.id + ": legal relocation refused");
    const auto after = snapshot(world, test);
    require(parcels(before) == parcels(after), test.id + ": semantic tuple/temperature conservation failed");
    require(water_quantity(before) == water_quantity(after), test.id + ": Water quantity conservation failed");
    require(overlaps(before) == overlaps(after) + 1, test.id + ": overlap count did not fall by exactly one");
    require(world.stored_material(test.path[0].first, test.path[0].second) == cybersand::Material::Empty,
            test.id + ": source still occupied");
    for (std::size_t i = 1; i < test.path.size(); ++i) {
        require(parcel(world, test.path[i]) == expected[i - 1], test.id + ": parcel sequence changed");
        require(world.transient_obstacle_at(test.path[i].first, test.path[i].second) == 0,
                test.id + ": new body overlap");
    }
    for (std::size_t i = 0; i < before.size(); ++i)
        require(std::get<2>(before[i]) == std::get<2>(after[i]), test.id + ": body masks mutated");
}

Case control(std::string id, int chain_length, bool water = false, bool mixed = false) {
    Case test;
    test.id = std::move(id); test.cap = chain_length;
    for (std::int64_t y = 20; y < 28; ++y)
        for (std::int64_t x = 20; x < 32; ++x) test.cells.push_back({{x,y},0,0,0,200,0});
    const std::array<cybersand::Material,4> materials{cybersand::Material::Sand,cybersand::Material::Water,
                                                   cybersand::Material::Smoke,cybersand::Material::Lava};
    for (int i = 0; i < chain_length; ++i) {
        const Point point{24 + i,24};
        auto& cell = test.cells[static_cast<std::size_t>((point.second - 20) * 12 + point.first - 20)];
        cell.material = static_cast<std::uint16_t>(mixed ? materials[static_cast<std::size_t>(i)] :
                           water ? cybersand::Material::Water : cybersand::Material::Sand);
        cell.state_a = static_cast<std::uint16_t>(17 + i * 13);
        cell.state_b = static_cast<std::uint8_t>(3 + i);
        cell.temperature = static_cast<std::int16_t>(-100 + i * 307);
        cell.body = i == 0 ? 1 : 0;
        test.path.push_back(point);
    }
    test.path.emplace_back(24 + chain_length,24);
    return test;
}
CopiedCell& at(Case& test, Point point) {
    const auto it = std::find_if(test.cells.begin(),test.cells.end(),[point](const auto& cell) { return cell.point == point; });
    require(it != test.cells.end(), "control coordinate missing");
    return *it;
}

std::size_t controls() {
    std::size_t count = 0;
    for (int length = 1; length <= 4; ++length) {
        run_case(control("Sand" + std::to_string(length), length), true); ++count;
        run_case(control("Water" + std::to_string(length), length, true), true); ++count;
    }
    run_case(control("mixed",4,false,true),true); ++count;
    auto test = control("hard",2); at(test,{25,24}).material = static_cast<std::uint16_t>(cybersand::Material::Wall);
    run_case(test,false); ++count;
    test = control("foreign",2); at(test,{25,24}).body = 2; run_case(test,false); ++count;
    test = control("own_mask",1); at(test,{25,24}).body = 1; run_case(test,false); ++count;
    test = control("no_void",1); at(test,{25,24}).material = static_cast<std::uint16_t>(cybersand::Material::Sand);
    run_case(test,false); ++count;
    test = control("beyond_cap",3); test.cap = 2; run_case(test,false); ++count;
    test = control("rear_only",1); test.normal_x = -1; run_case(test,false); ++count;
    test = control("lateral_excluded",1); test.normal_x = 0; test.normal_y = 1; run_case(test,false); ++count;
    test.policy = "forward_lateral"; test.id = "lateral_permitted"; run_case(test,true); ++count;
    test = control("overlapping_path",2); test.path.back() = test.path.front(); run_case(test,false); ++count;
    test = control("not_adjacent",1); test.path.back().first += 1; run_case(test,false); ++count;
    test = control("invalid_normal",1); test.normal_x = 0; run_case(test,false); ++count;
    test = control("outer_ring",1);
    // Retain the destination reference: assignment temporarily copies the old
    // coordinate, so looking it up again before restoring its key cannot work.
    auto& ring_source = at(test,{30,24});
    ring_source = at(test,{24,24}); ring_source.point = {30,24};
    at(test,{24,24}) = {{24,24},0,0,0,200,0};
    test.path = {{30,24},{31,24}}; run_case(test,false); ++count;
    return count;
}

std::vector<Case> load(const char* path) {
    std::ifstream in(path);
    std::string magic;
    std::size_t count = 0;
    require(bool(in >> magic >> count) && magic == "EJECTION_CHAINS_V1" && count <= 10000, "invalid chain file header");
    std::vector<Case> out;
    for (std::size_t i = 0; i < count; ++i) {
        std::string marker;
        Case test;
        std::size_t cells = 0, points = 0;
        require(bool(in >> marker >> test.id >> test.policy >> test.cap >> cells >> points >> test.normal_x >> test.normal_y) &&
                marker == "CASE" && cells > 0 && cells <= 16384 && points >= 2 && points <= 5, "invalid case framing");
        for (std::size_t j = 0; j < cells; ++j) {
            CopiedCell cell;
            int material = 0, state_a = 0, state_b = 0, temperature = 0, body = 0;
            require(bool(in >> cell.point.first >> cell.point.second >> material >> state_a >> state_b >> temperature >> body), "truncated cells");
            require(cell.point.first >= -128 && cell.point.first <= 1151 &&
                    cell.point.second >= -128 && cell.point.second <= 1151, "copied coordinate outside adapter envelope");
            require(material >= 0 && material <= 65535 && state_a >= 0 && state_a <= 65535 && state_b >= 0 && state_b <= 255 &&
                    temperature >= -32768 && temperature <= 32767 && body >= 0 && body <= 64, "cell value outside domain");
            cell.material = static_cast<std::uint16_t>(material); cell.state_a = static_cast<std::uint16_t>(state_a);
            cell.state_b = static_cast<std::uint8_t>(state_b); cell.temperature = static_cast<std::int16_t>(temperature);
            cell.body = static_cast<std::uint16_t>(body); test.cells.push_back(cell);
        }
        for (std::size_t j = 0; j < points; ++j) {
            Point point;
            require(bool(in >> point.first >> point.second), "truncated path");
            test.path.push_back(point);
        }
        out.push_back(std::move(test));
    }
    std::string extra;
    require(!(in >> extra), "unexpected trailing chain file content");
    return out;
}
} // namespace

int main(int argc, char** argv) {
    try {
        require(argc <= 2, "usage: test_ejection_chain_world [EJECTION_CHAINS_V1-file]");
        const auto self_controls = controls();
        const auto cases = argc == 2 ? load(argv[1]) : std::vector<Case>{};
        for (const auto& test : cases) run_case(test,true);
        std::cout << "{\"self_controls\":" << self_controls << ",\"imported_legal_chains\":" << cases.size()
                  << ",\"conservation_failures\":0,\"barrier_violations\":0,\"overlap_reduction_failures\":0,"
                     "\"qualification\":\"copied World semantic tuple/temperature/Water quantity; raw epoch/spare import excluded\"}\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "ejection copied World validation failed: " << error.what() << '\n';
        return 1;
    }
}
