#include "negotiated.hpp"

#include <filesystem>
#include <iostream>
#include <stdexcept>

using namespace cybersand::gentek_swarm;

namespace {
std::uint64_t metric(const NegotiatedResult& result, const std::string& key) {
    const auto at = result.metrics.find(key);
    return at == result.metrics.end() ? 0 : at->second;
}
unsigned violations(const NegotiatedResult& result) {
    unsigned count = 0;
    for (const auto* key : {"protected_violations", "illegal_overlaps", "frozen_core_changes", "mosaic_frozen_changes"})
        count += static_cast<unsigned>(metric(result, key));
    return count;
}
void fresh_file(const std::filesystem::path& path) {
    if (std::filesystem::exists(path))
        throw std::invalid_argument("refusing to overwrite retained admission evidence: " + path.string());
}
std::uint64_t first_invoked_limit(const MosaicPlan& plan) {
    for (const auto& attempt : plan.attempts)
        if (attempt.attempted) return attempt.work_limit;
    return 0;
}
} // namespace

int main(int argc, char** argv) try {
    if (argc < 3 || argc > 4 || (argc == 4 && std::string(argv[3]) != "quick"))
        throw std::invalid_argument("usage: gentek_admission OUTPUT SOURCE [quick]");
    const std::filesystem::path out = argv[1];
    const std::string source = argv[2];
    const bool quick = argc == 4;
    std::filesystem::create_directories(out / "controls-c");
    unsigned controls = 0, variants = 0, leave_one_out = 0, diagnostics = 0, hard_violations = 0;
    for (const auto& fixture_name : fixture_names())
        for (const auto* profile_name : {"sparse_regular", "branching_irregular", "dense_cohesive"})
            for (auto seed : {605ULL, 1701ULL}) {
                if (quick && (std::string(profile_name) != "branching_irregular" || seed != 605)) continue;
                const auto f = fixture(fixture_name);
                const auto p = profile(profile_name);
                const auto stem = fixture_name + "_" + profile_name + "_" + std::to_string(seed);

                // Freeze ranking before ANY full-C or variant MOSAIC outcome.
                const auto prepared = prepare_admission(f, p, seed, source);

                // Full C remains the unchanged reference, including its optional
                // residual view. Variant comparisons use C's structural cells.
                const auto full = negotiate(f, p, seed, source);
                const auto control_path = out / "controls-c" / ("full_control_" + stem + ".json");
                fresh_file(control_path);
                write_negotiated_json(control_path.string(), full);
                ++controls;
                hard_violations += violations(full);

                // Ranking is prepared once from the frozen mechanical offers
                // and immutable masks. No candidate outcome can choose a rank.
                const auto publish = [&](const AdmissionResult& result, const std::string& suffix) {
                    if (result.admission.status == Status::Invalid)
                        throw std::runtime_error("registered admission policy rejected: " + result.admission.reason);
                    const auto path = out / ("admission_" + stem + "_" + suffix + ".json");
                    fresh_file(path);
                    write_admission_json(path.string(), result);
                    ++variants;
                    hard_violations += violations(result.candidate);
                    std::cout << path.filename().string()
                              << " selected=" << result.admission.selected_ids.size()
                              << " budget_mode=" << (result.admission.diagnostic ? "equal-first-budget-2m" : "primary")
                              << " status=" << name(result.candidate.mosaic.result.status)
                              << " joined=" << metric(result.candidate, "joined_slots")
                              << " required_unresolved=" << metric(result.candidate, "unresolved_required_slots")
                              << " posthoc=" << metric(result.candidate, "candidate_posthoc_cells")
                              << " attempt_limits=";
                    bool first = true;
                    for (const auto& attempt : result.candidate.mosaic.attempts) {
                        if (!first) std::cout << '/';
                        first = false;
                        std::cout << attempt.work_limit;
                    }
                    std::cout << '\n';
                };
                const auto emit = [&](const AdmissionPolicy& policy, const std::string& suffix) {
                    const auto result = negotiate_admission(prepared, policy, false, false);
                    publish(result, suffix);
                    // A reduced domain set can also change the donor's first
                    // attempt allocation from 2M to 4M. Keep that confound
                    // visible with this predeclared lower-budget diagnostic.
                    if (full.mosaic.result.status != Status::Complete &&
                        result.candidate.mosaic.result.status == Status::Complete &&
                        first_invoked_limit(full.mosaic) == 2'000'000 &&
                        first_invoked_limit(result.candidate.mosaic) == 4'000'000) {
                        const auto diagnostic = negotiate_admission(prepared, policy, false, false, 2'000'000);
                        publish(diagnostic, suffix + "_budget2m");
                        ++diagnostics;
                    }
                };
                for (const auto cap : {0U, 1U, 2U, 4U}) {
                    AdmissionPolicy policy;
                    policy.mode = AdmissionMode::OptionalCap;
                    policy.optional_cap = cap;
                    emit(policy, "cap" + std::to_string(cap));
                }

                // The diagnostic registration is fixed by ORIGINAL full-C
                // solver failure, never by a promising reduced-offer outcome.
                // Retain every single-optional omission in each such case.
                if (full.mosaic.result.status != Status::Complete) {
                    for (const auto& slot : full.frame.slots) {
                        if (slot.required || slot.hard) continue;
                        AdmissionPolicy policy;
                        policy.mode = AdmissionMode::LeaveOneOut;
                        policy.omitted_optional_id = slot.id;
                        emit(policy, "drop" + std::to_string(slot.id));
                        ++leave_one_out;
                    }
                }
            }
    std::cout << "ADMISSION controls=" << controls << " variants=" << variants
              << " leave_one_out=" << leave_one_out << " diagnostics=" << diagnostics
              << " hard_violations=" << hard_violations << '\n';
    return hard_violations ? 1 : 0;
} catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 2;
}
