// SOL passive-support candidate: fixed input controls for one normal-axis mechanism.
// Compile independently: g++ -std=c++20 -O2 -Wall -Wextra -Werror -pedantic
//     -I native/include tools/experiments/sol_active_normal_weight.cpp -o /tmp/sol-active-normal
// This is a synthetic value-only test, NOT a Godot/Rapier World qualification.
#include "cybersand/granular_contact_response.hpp"
#include <array>
#include <cmath>
#include <iostream>
#include <span>
#include <stdexcept>

using namespace cybersand::gcr;

namespace {
void check(bool ok, const char* description) {
    if (!ok) throw std::runtime_error(description);
}
bool near(double x, double y) { return std::isfinite(x) && std::abs(x-y)<1e-12; }

Result run(Vec velocity, Vec first_normal, Vec second_normal,
           bool normalize, double available=20) {
    Bin first{}, second{};
    first.add({0,0},first_normal,{0,0});
    second.add({0,0},second_normal,{0,0});
    std::array<const Bin*,2> bins{&first,&second};
    CompoundWorkspace workspace{};
    Body body{};
    body.velocity=velocity;
    body.mass=1;
    body.inertia=1;
    body.mu=0;
    return solve_compound(body,
        std::span<const Bin* const>{bins.data(),bins.size()},
        workspace,available,1,20,normalize);
}
} // namespace

int main() {
    try {
        // One approaching upward-bearing normal and an unrelated perpendicular
        // normal: the old four weighted passes leave (1 - 1/2)^4 velocity.
        const auto old=run({0,1},{0,-1},{1,0},false);
        const auto candidate=run({0,1},{0,-1},{1,0},true);
        check(near(old.impulse.y,-0.9375) && near(old.energy_after,0.5*0.0625*0.0625),
              "unchanged historical weighted residual");
        check(near(candidate.impulse.y,-1) && near(candidate.energy_after,0),
              "candidate should arrest sole opposing normal without adding energy");
        check(!old.passive_rejected && !candidate.passive_rejected,
              "both proposals must pass the original energy refusal");

        // Two simultaneously opposing contacts already account for all sample
        // weight and must retain the original impulse, not double it.
        const auto double_old=run({0,1},{0,-1},{0,-1},false);
        const auto double_new=run({0,1},{0,-1},{0,-1},true);
        check(near(double_old.impulse.y,-1) && near(double_new.impulse.y,-1),
              "two opposing contacts retain the same total impulse");

        // An unforced separating body may stay separated; no fabricated pull.
        const auto departing_old=run({0,-1},{0,-1},{1,0},false);
        const auto departing_new=run({0,-1},{0,-1},{1,0},true);
        check(near(departing_old.impulse.y,0) && near(departing_new.impulse.y,0),
              "separating velocity generates no normal impulse");

        // Budget 0.1 splits across the two bins. Normalizing eligibility
        // must not bypass per-bin capacities or perform positional correction.
        const auto budget_old=run({0,1},{0,-1},{1,0},false,0.1);
        const auto budget_new=run({0,1},{0,-1},{1,0},true,0.1);
        check(near(budget_old.impulse.y,-0.05) && near(budget_new.impulse.y,-0.05),
              "per-bin capacity remains authoritative");
        check(budget_new.normal_cap_hits>0, "explicit capacity refusal retained");

        // Deterministic recomputation cannot retain stale workspace impulses.
        const auto repeated=run({0,1},{0,-1},{1,0},true);
        check(near(repeated.impulse.y,candidate.impulse.y) &&
              near(repeated.energy_after,candidate.energy_after),
              "repeat is source/value deterministic");
        std::cout << "SOL_ACTIVE_NORMAL controls=5 failures=0"
                     " old_residual=0.0625 candidate_residual=0\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "SOL_ACTIVE_NORMAL failure: " << e.what() << '\n';
        return 1;
    }
}
