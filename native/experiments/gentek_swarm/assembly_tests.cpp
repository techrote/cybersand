#include "assembly.hpp"

#include <algorithm>
#include <atomic>
#include <iostream>
#include <limits>
#include <set>
#include <stdexcept>

using namespace cybersand;
using namespace cybersand::gentek_swarm;
namespace a4 = cybersand::gentek_swarm::assembly004;

namespace {
std::uint64_t checks{};
void check(bool condition, const std::string& message) {
    ++checks;
    if (!condition) throw std::runtime_error(message);
}
a4::ExpandedAssembly expansion(const a4::Grammar& grammar, a4::Symbol root,
                              a4::Budget& budget, a4::Transform transform = {}) {
    return a4::expand(grammar, root, transform, 2, 1, budget);
}
void atomic_failure(const a4::ExpandedAssembly& result, a4::Outcome outcome, const std::string& label) {
    check(result.outcome == outcome, label + ": outcome=" + a4::name(result.outcome) + " " + result.reason);
    check(result.claims.empty() && result.instances.empty() && result.nodes.empty() &&
          result.sockets.empty() && result.joints.empty() && result.digest == 0,
          label + ": failed grammar exposed partial proposed geometry");
    check(!result.reason.empty(), label + ": missing failure receipt");
}
a4::AssemblySpec& assembly(a4::Grammar& grammar, std::uint32_t id) {
    return *std::find_if(grammar.assemblies.begin(), grammar.assemblies.end(), [=](const auto& a) { return a.id == id; });
}
a4::PartSpec& part(a4::Grammar& grammar, std::uint32_t id) {
    return *std::find_if(grammar.parts.begin(), grammar.parts.end(), [=](const auto& p) { return p.id == id; });
}
void transforms() {
    const Point p{-5, 7};
    const std::array<Point, 4> expected{{{-15, -13}, {-17, -25}, {-5, -27}, {-3, -15}}};
    for (unsigned rotation = 0; rotation < 4; ++rotation) {
        Point result;
        check(a4::transform_point(p, {{-10, -20}, rotation}, result) && result == expected[rotation], "signed quarter-turn transform");
        for (unsigned local_rotation = 0; local_rotation < 4; ++local_rotation) {
            a4::Transform combined;
            const a4::Transform parent{{-10, 20}, rotation}, local{{11, -13}, local_rotation};
            Point step, indirect, direct;
            check(a4::compose(parent, local, combined) && a4::transform_point(p, local, step) &&
                  a4::transform_point(step, parent, indirect) && a4::transform_point(p, combined, direct) &&
                  indirect == direct, "nested transform equals explicit local-then-world evaluation");
        }
    }
    Point result;
    check(!a4::transform_point({1, 0}, {{std::numeric_limits<int>::max(), 0}, 0}, result), "positive overflow rejected");
    check(!a4::transform_point({std::numeric_limits<int>::min(), 0}, {{0, 0}, 2}, result), "negation overflow rejected");
    check(a4::transform_point({std::numeric_limits<int>::min(), 0}, {{std::numeric_limits<int>::min(), 0}, 2}, result) &&
          result == Point{0, 0}, "wide intermediate transform permits representable result");
    check(!a4::transform_point({0, 0}, {{0, 0}, 4}, result), "invalid orientation is not normalized");
}
void authored_parts() {
    const std::array<std::pair<unsigned, unsigned>, 6> sizes{{{1, 1}, {1, 16}, {24, 1}, {24, 16}, {8, 6}, {4, 4}}};
    for (const auto& [span, rise] : sizes) {
        const auto grammar = a4::frame_grammar(span, rise);
        for (const auto& p : grammar.parts) {
            a4::Budget budget;
            const auto result = expansion(grammar, {p.id, false}, budget);
            check(result.outcome == a4::Outcome::Complete, "authored part " + p.name + ": " + result.reason);
            check(result.claims.size() == p.cells.size(), "leaf footprint retains all native cells");
        }
        for (const auto root : {a4::truss, a4::bracket, a4::nested_truss}) {
            for (unsigned rotation = 0; rotation < 4; ++rotation) {
                a4::Budget budget;
                const a4::Transform transform{{-100, 37}, rotation};
                const auto result = expansion(grammar, {root, true}, budget, transform);
                check(result.outcome == a4::Outcome::Complete, "authored assembly " + std::to_string(root) + " " +
                      std::to_string(span) + "/" + std::to_string(rise) + ": " + result.reason);
                check(result.instances.size() >= 2, "assemblies contain multiple physical parts");
                check(result.declared_cells == result.claims.size() + result.shared_joint_cells, "every declared material cell accounted");
                check(!result.joints.empty(), "real authored attachment receipts retained");
                std::set<Point> points;
                for (const auto& claim : result.claims) {
                    check(points.insert(claim.point).second, "one canonical owner per material cell");
                    check(claim.owner == a4::Owner::Frameweaver && claim.material == Material::SteelPlate &&
                          !claim.rule.empty() && claim.instance > 0 && claim.round == 2 && claim.revision == 1,
                          "exact native material and source revision provenance");
                }
                Point input, output, west, east;
                check(a4::transform_point({0, 0}, transform, input) &&
                      a4::transform_point({static_cast<int>(span), 0}, transform, output) &&
                      a4::transform_point({-1, 0}, {{0, 0}, rotation}, west) &&
                      a4::transform_point({1, 0}, {{0, 0}, rotation}, east), "socket transforms admitted");
                check(result.sockets[0].id == 1 && result.sockets[0].a == input && result.sockets[0].facing == west,
                      "all assemblies expose exact host weld");
                check(result.sockets[1].id == 2 && result.sockets[1].a == output && result.sockets[1].facing == east &&
                      result.sockets[1].obligation == a4::Obligation::ForeignRequired,
                      "all assemblies preserve exact foreign-required endpoint");
                check(budget.proposals == 0, "part trials do not consume Gentek revision slots");
            }
        }
    }
    auto grammar = a4::frame_grammar(8, 6);
    a4::Budget original_budget, reordered_budget;
    const auto original = expansion(grammar, {a4::nested_truss, true}, original_budget);
    std::reverse(grammar.parts.begin(), grammar.parts.end());
    std::reverse(grammar.assemblies.begin(), grammar.assemblies.end());
    for (auto& p : grammar.parts) { std::reverse(p.cells.begin(), p.cells.end()); std::reverse(p.sockets.begin(), p.sockets.end()); }
    for (auto& a : grammar.assemblies) {
        std::reverse(a.children.begin(), a.children.end()); std::reverse(a.attachments.begin(), a.attachments.end());
        std::reverse(a.sockets.begin(), a.sockets.end());
    }
    const auto reordered = expansion(grammar, {a4::nested_truss, true}, reordered_budget);
    check(reordered.outcome == a4::Outcome::Complete && original.digest == reordered.digest,
          "declaration, child and attachment ordering cannot choose geometry/provenance");
    check(original_budget.work == reordered_budget.work && original_budget.bytes == reordered_budget.bytes,
          "reverse-order replay preserves accounted work and storage");
}
void invalid_inputs() {
    const auto reject = [](a4::Grammar grammar, const std::string& label, a4::Symbol root = {a4::truss, true}) {
        a4::Budget budget;
        atomic_failure(expansion(grammar, root, budget), a4::Outcome::Invalid, label);
    };
    auto grammar = a4::frame_grammar(); grammar.parts.push_back(grammar.parts.front()); reject(grammar, "duplicate symbol");
    grammar = a4::frame_grammar(); grammar.assemblies[0].id = grammar.parts[0].id; reject(grammar, "cross-kind duplicate symbol");
    grammar = a4::frame_grammar(); grammar.parts[0].cells.push_back(grammar.parts[0].cells.front()); reject(grammar, "duplicate footprint cell");
    for (auto invalid_material : {Material::Empty, static_cast<Material>(10), static_cast<Material>(255)}) {
        grammar = a4::frame_grammar(); grammar.parts[0].cells[0].material = invalid_material; reject(grammar, "illegal material id");
    }
    grammar = a4::frame_grammar(); grammar.parts[0].cells[0].role = Role::Empty; reject(grammar, "empty role on solid cell");
    grammar = a4::frame_grammar(); grammar.parts[0].cells.push_back({{999, 999}, Material::SteelPlate, Role::Structure}); reject(grammar, "disconnected leaf");
    grammar = a4::frame_grammar(); grammar.parts[0].sockets[0].facing = {1, 1}; reject(grammar, "diagonal socket facing");
    grammar = a4::frame_grammar(); grammar.parts[0].sockets[0].a = {-20, -20}; reject(grammar, "socket lacks material");
    grammar = a4::frame_grammar(); grammar.parts[0].sockets[0].b = {2, 2}; reject(grammar, "diagonal socket segment");
    grammar = a4::frame_grammar(); assembly(grammar, a4::truss).children[0].transform.quarter_turns = 9; reject(grammar, "invalid child orientation");
    grammar = a4::frame_grammar(); assembly(grammar, a4::truss).children[0].symbol.id = 999; reject(grammar, "unknown child symbol");
    grammar = a4::frame_grammar(); assembly(grammar, a4::truss).sockets.pop_back(); reject(grammar, "foreign obligation hidden by assembly");
    grammar = a4::frame_grammar(); assembly(grammar, a4::truss).attachments[2].socket_a = 2; reject(grammar, "foreign obligation consumed as local weld");
    grammar = a4::frame_grammar(); assembly(grammar, a4::truss).attachments.clear(); reject(grammar, "undeclared joint overlap");
    grammar = a4::frame_grammar(); part(grammar, a4::brace).sockets[1].facing = {-1, 0}; reject(grammar, "same-facing mechanical joint");
    grammar = a4::frame_grammar(); part(grammar, a4::brace).sockets[1].family = Family::Brace; reject(grammar, "incompatible mechanical type");
    grammar = a4::frame_grammar(); part(grammar, a4::brace).cells[0].material = Material::RedBrick; reject(grammar, "conflicting native material at weld");
    grammar = a4::frame_grammar(); assembly(grammar, a4::truss).children[2].transform.translation.x += 100; reject(grammar, "nonlocal required attachment");
    reject(a4::frame_grammar(0, 5), "invalid factory dimensions");
    reject(a4::frame_grammar(), "unknown root", {999, false});
    grammar = a4::frame_grammar(); grammar.owner = static_cast<a4::Owner>(0); reject(grammar, "unowned grammar");
    grammar = a4::frame_grammar(); auto& nested = assembly(grammar, a4::nested_truss);
    nested.children[0].symbol = {a4::nested_truss, true}; reject(grammar, "direct recursive cycle", {a4::nested_truss, true});
    grammar = a4::frame_grammar(); assembly(grammar, a4::nested_truss).children[0].symbol = {a4::truss, true};
    assembly(grammar, a4::truss).children[0].symbol = {a4::nested_truss, true}; reject(grammar, "indirect recursive cycle", {a4::nested_truss, true});
    a4::Budget budget;
    atomic_failure(expansion(a4::frame_grammar(), {a4::member, false}, budget,
                   {{std::numeric_limits<int>::max(), 0}, 0}), a4::Outcome::Invalid, "world transform overflow");
}
void limits_and_cancel() {
    const auto grammar = a4::frame_grammar();
    const auto exhausted = [&](a4::Limits limits, const std::string& label) {
        a4::Budget budget; budget.limits = limits;
        atomic_failure(expansion(grammar, {a4::nested_truss, true}, budget), a4::Outcome::Exhausted, label);
        check(budget.work <= limits.max_work && budget.bytes <= limits.max_bytes &&
              budget.instances <= limits.max_instances && budget.nodes <= limits.max_nodes &&
              budget.candidates <= limits.max_candidates, label + ": ledger never exceeds bounds");
    };
    a4::Limits limits; limits.max_work = 1; exhausted(limits, "work limit");
    limits = {}; limits.max_bytes = 1; exhausted(limits, "storage limit");
    limits = {}; limits.max_nodes = 2; exhausted(limits, "node limit");
    limits = {}; limits.max_instances = 2; exhausted(limits, "instance limit");
    limits = {}; limits.max_frontier = 2; exhausted(limits, "live frontier limit");
    limits = {}; limits.max_candidates = 0; exhausted(limits, "candidate limit");
    limits = {}; limits.max_depth = 1; exhausted(limits, "depth limit");
    a4::Budget invalid; invalid.limits.max_depth = 7;
    atomic_failure(expansion(grammar, {a4::truss, true}, invalid), a4::Outcome::Invalid, "silent ceiling expansion rejected");
    std::atomic_bool cancel{true}; a4::Budget cancelled; cancelled.cancel = &cancel;
    atomic_failure(expansion(grammar, {a4::truss, true}, cancelled), a4::Outcome::Cancelled, "cancel before work");
    check(cancelled.work == 0 && cancelled.bytes == 0, "pre-cancelled proposal performs no allocations/work");
    check(!a4::begin_proposal(cancelled), "cancelled Gentek proposal rejected");
    a4::Budget proposals;
    for (unsigned i = 0; i < 10; ++i) check(a4::begin_proposal(proposals), "registered Gentek proposal admitted");
    const auto previous_work = proposals.work;
    check(!a4::begin_proposal(proposals) && proposals.proposals == 10 && proposals.work == previous_work,
          "initial pair plus four reciprocal pairs is exact ten-proposal ceiling");
    a4::Budget trials;
    const auto first = expansion(grammar, {a4::truss, true}, trials);
    check(first.outcome == a4::Outcome::Complete, "first candidate");
    const auto charged_work = trials.work; const auto charged_bytes = trials.bytes; const auto charged_candidates = trials.candidates;
    trials.nodes = trials.instances = 0; // caller discarded the spatially rejected candidate
    const auto second = expansion(grammar, {a4::bracket, true}, trials);
    check(second.outcome == a4::Outcome::Complete && trials.work > charged_work && trials.bytes > charged_bytes &&
          trials.candidates > charged_candidates, "discarding candidate restores live capacity only; all work persists");
}
void finite_recursion() {
    auto grammar = a4::frame_grammar();
    for (std::uint32_t id = 200; id <= 206; ++id) {
        const a4::Symbol child = id == 206 ? a4::Symbol{a4::member, false} : a4::Symbol{id + 1, true};
        grammar.assemblies.push_back({id, "bounded_wrapper", "FRAMEWEAVER/test/wrapper", {{1, child, {}}}, {}, {{1, 1, 1}, {2, 1, 2}}});
    }
    a4::Budget too_deep;
    atomic_failure(expansion(grammar, {200, true}, too_deep), a4::Outcome::Exhausted, "depth seven chain");
    a4::Budget bounded;
    const auto result = expansion(grammar, {201, true}, bounded);
    check(result.outcome == a4::Outcome::Complete && result.nodes.size() == 7 && result.instances.size() == 1,
          "depth six chain expands through finite authored hierarchy");
}
void optional_constraints() {
    a4::Grammar grammar;
    grammar.parts = {{1, "pixel", "test/local_pixel", {{{0, 0}, Material::SteelPlate, Role::Structure}},
                      {{1, {0, 0}, {0, 0}, {-1, 0}, Family::Frame, a4::Obligation::Optional}}}};
    grammar.assemblies = {{10, "adjacent_pieces", "test/optional_joint", {{1, {1, false}, {}},
                           {2, {1, false}, {{1, 0}, 0}}}, {{1, 1, 2, 1, false}}, {}}};
    a4::Budget optional_budget;
    const auto optional = expansion(grammar, {10, true}, optional_budget);
    check(optional.outcome == a4::Outcome::Complete && optional.claims.size() == 2 &&
          optional.rejections.size() == 1 && optional.joints.empty(),
          "optional incompatibility is retained and adjacent material is never a fake typed joint");
    grammar.assemblies[0].attachments[0].required = true;
    a4::Budget hard_budget;
    atomic_failure(expansion(grammar, {10, true}, hard_budget), a4::Outcome::Invalid, "same constraint required");
}
void backward_bearings() {
    for (unsigned span = 2; span <= 12; ++span) for (unsigned rise = 2; rise <= 8; ++rise) {
        for (const auto family : {Family::Frame, Family::Brace}) for (int handedness : {-1, 1}) {
            const auto grammar = a4::bearing_grammar(span, rise, family, handedness);
            std::set<Point> reference;
            for (unsigned rotation = 0; rotation < 4; ++rotation) {
                a4::Budget budget;
                const a4::Transform transform{{-41, 23}, rotation};
                const auto result = expansion(grammar, {a4::backward_bearing, true}, budget, transform);
                check(result.outcome == a4::Outcome::Complete, "backward bearing: " + result.reason);
                check(result.instances.size() == 3 && result.joints.size() == 3,
                      "backward bearing is three real parts with three required typed joints");
                check(result.sockets.size() == 2 && result.sockets[0].id == 1 && result.sockets[1].id == 2,
                      "backward bearing has exactly the two declared interface exports");
                Point west, east;
                check(a4::transform_point({-1, 0}, {{0, 0}, rotation}, west) &&
                      a4::transform_point({1, 0}, {{0, 0}, rotation}, east), "bearing socket rotation");
                const auto& input = result.sockets[0]; const auto& output = result.sockets[1];
                check(input.a == transform.translation && input.b == input.a && input.facing == west &&
                      input.family == family && input.obligation == a4::Obligation::LocalTerminable,
                      "bearing input preserves requested mechanical family and local obligation");
                check(output.a == transform.translation && output.b == output.a && output.facing == east &&
                      output.family == Family::Frame && output.obligation == a4::Obligation::ForeignRequired,
                      "zero-offset bearing does not convert a foreign obligation into a local cap");
                std::set<Point> local_cells;
                std::map<std::uint32_t, unsigned> fresh_by_part;
                for (const auto& claim : result.claims) {
                    Point local;
                    const Point relative{claim.point.x - transform.translation.x, claim.point.y - transform.translation.y};
                    check(a4::transform_point(relative, {{0, 0}, (4 - rotation) % 4}, local), "inverse bearing transform");
                    check(local_cells.insert(local).second && local.x <= 0 && local.x >= -static_cast<int>(span) &&
                          handedness * local.y >= 0 && handedness * local.y <= static_cast<int>(rise),
                          "bearing stays wholly behind the foreign face within its declared footprint");
                    check(claim.material == Material::SteelPlate && claim.role == Role::Structure &&
                          claim.owner == a4::Owner::Frameweaver && !claim.rule.empty(), "bearing native structural provenance");
                    if (span == 2 && rise == 2) {
                        const bool existing_host = std::abs(local.y) <= 1;
                        if (existing_host) check(std::abs(local.x) + std::abs(local.y) <= 2,
                                                 "default bearing requires no wider host weld permission");
                        else ++fresh_by_part[claim.instance];
                    }
                }
                if (span == 2 && rise == 2)
                    check(fresh_by_part.size() == 3, "each default bearing part contributes new native material outside a three-cell host");
                if (rotation == 0) reference = local_cells;
                else check(reference == local_cells, "bearing rotations preserve exact local material geometry");
                check(result.declared_cells == result.claims.size() + result.shared_joint_cells && result.shared_joint_cells == 3,
                      "all three bearing weld cells and every native cell are accounted");
            }
        }
    }
    auto grammar = a4::bearing_grammar(4, 3, Family::Brace, 1);
    a4::Budget before_budget, after_budget;
    const auto before = expansion(grammar, {a4::backward_bearing, true}, before_budget);
    std::reverse(grammar.parts.begin(), grammar.parts.end());
    for (auto& p : grammar.parts) { std::reverse(p.cells.begin(), p.cells.end()); std::reverse(p.sockets.begin(), p.sockets.end()); }
    auto& a = grammar.assemblies.front();
    std::reverse(a.children.begin(), a.children.end()); std::reverse(a.attachments.begin(), a.attachments.end());
    std::reverse(a.sockets.begin(), a.sockets.end());
    const auto after = expansion(grammar, {a4::backward_bearing, true}, after_budget);
    check(after.outcome == a4::Outcome::Complete && before.digest == after.digest && before_budget.work == after_budget.work,
          "backward bearing is invariant to reversed definition/evaluation order");
    for (auto invalid : {a4::bearing_grammar(1, 2), a4::bearing_grammar(13, 2), a4::bearing_grammar(2, 1),
                         a4::bearing_grammar(2, 9), a4::bearing_grammar(2, 2, Family::Surface),
                         a4::bearing_grammar(2, 2, Family::Frame, 0), a4::bearing_grammar(2, 2, Family::Frame, 2)}) {
        a4::Budget budget;
        atomic_failure(expansion(invalid, {a4::backward_bearing, true}, budget), a4::Outcome::Invalid,
                       "backward bearing rejects unregistered dimensions/type/handedness");
    }
    const auto inherited = a4::frame_grammar(4, 3, Family::Brace);
    a4::Budget inherited_budget;
    const auto ending = expansion(inherited, {a4::termination_plate, false}, inherited_budget);
    check(ending.outcome == a4::Outcome::Complete && std::none_of(ending.sockets.begin(), ending.sockets.end(),
          [](const auto& s) { return s.obligation == a4::Obligation::ForeignRequired; }),
          "existing local termination plate remains independently terminable");
    a4::Budget inherited_truss_budget;
    const auto inherited_truss = expansion(inherited, {a4::nested_truss, true}, inherited_truss_budget);
    check(inherited_truss.outcome == a4::Outcome::Complete && inherited_truss.sockets[0].family == Family::Brace,
          "existing FRAME Brace-input adapter preserved");
}
} // namespace

int main() {
    try {
        transforms(); authored_parts(); invalid_inputs(); limits_and_cancel(); finite_recursion(); optional_constraints(); backward_bearings();
        std::cout << "SWARM004_ASSEMBLY: PASS checks=" << checks << '\n'; return 0;
    } catch (const std::exception& error) {
        std::cerr << "SWARM004_ASSEMBLY: FAIL checks=" << checks << " " << error.what() << '\n'; return 1;
    }
}
