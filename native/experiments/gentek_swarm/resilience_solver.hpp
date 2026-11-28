#pragma once
#include "negotiated.hpp"
#include "cybersand/generation_spatial.hpp"

#include <array>
#include <memory>

namespace cybersand::gentek_swarm {

// Reconstructed SWARM-003 wrapper. GEN-003 and its category/seed order are unchanged.
enum class SolveSchedule { Original, BalancedRecovery, PreferredHeavy, FallbackHeavy, SinglePreferred };
const char* name(SolveSchedule) noexcept;

struct ResilienceSolvePolicy {
    SolveSchedule schedule = SolveSchedule::Original;
    std::vector<std::uint16_t> fallback_domains;
    // Declared selected optional universe. Full forwarding can include a known
    // geometry-unadmitted response; actual domain influences remain explicit.
    std::vector<std::uint32_t> primary_optional_ids, fallback_optional_ids;
};
struct ResilienceAttempt {
    SolverAttempt solver;
    std::vector<std::uint16_t> domains;
    std::vector<std::uint32_t> optional_ids;
    std::vector<int> categories;
    std::string trigger;
    bool fallback = false;
};
struct ResilienceSolverTrace {
    std::uint32_t width{}, height{};
    std::uint64_t seed{}, aggregate_limit{}, allocated_limit{}, attempted_limit{}, preparation_work{};
    std::vector<std::uint64_t> category_ids;
    std::array<std::array<std::uint16_t, 16>, 4> adjacency{};
    std::vector<ResilienceAttempt> attempts;
    std::vector<std::uint32_t> primary_optional_ids, fallback_optional_ids;
    bool fallback_used = false;
};

std::shared_ptr<const generation::spatial::PreparedRegions> solve_mosaic_resilient(
    const Request&, Result& accounting, MosaicPlan&,
    const generation::spatial::RegionAssignment&, const ResilienceSolvePolicy&, ResilienceSolverTrace&);

} // namespace cybersand::gentek_swarm
