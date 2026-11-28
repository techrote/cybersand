#include "resilience.hpp"

#include <array>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

using namespace cybersand::gentek_swarm;

namespace {
struct RegisteredPolicy { const char* id; ResilienceOptions options; };
const std::array<RegisteredPolicy, 12> policies{{
    {"full_balanced", {ResilienceAdmission::Full, SolveSchedule::BalancedRecovery, ResilienceFallback::HardOnly}},
    {"full_preferred_heavy", {ResilienceAdmission::Full, SolveSchedule::PreferredHeavy, ResilienceFallback::HardOnly}},
    {"full_fallback_heavy", {ResilienceAdmission::Full, SolveSchedule::FallbackHeavy, ResilienceFallback::HardOnly}},
    {"full_single", {ResilienceAdmission::Full, SolveSchedule::SinglePreferred, ResilienceFallback::HardOnly}},
    {"native_original", {ResilienceAdmission::CompatibilityFour, SolveSchedule::Original, ResilienceFallback::HardOnly}},
    {"native_balanced", {ResilienceAdmission::CompatibilityFour, SolveSchedule::BalancedRecovery, ResilienceFallback::NativeCore}},
    {"native_preferred_heavy", {ResilienceAdmission::CompatibilityFour, SolveSchedule::PreferredHeavy, ResilienceFallback::NativeCore}},
    {"native_fallback_heavy", {ResilienceAdmission::CompatibilityFour, SolveSchedule::FallbackHeavy, ResilienceFallback::NativeCore}},
    {"native_single", {ResilienceAdmission::CompatibilityFour, SolveSchedule::SinglePreferred, ResilienceFallback::NativeCore}},
    {"native_receiver_single", {ResilienceAdmission::CompatibilityFour, SolveSchedule::SinglePreferred, ResilienceFallback::NativeCore, ReceiverPolicy::RequiredOriginalNative}},
    {"native_receiver_six", {ResilienceAdmission::CompatibilityFour, SolveSchedule::SinglePreferred, ResilienceFallback::NativeCore, ReceiverPolicy::RequiredOriginalNative, 6}},
    {"native_receiver_eight", {ResilienceAdmission::CompatibilityFour, SolveSchedule::SinglePreferred, ResilienceFallback::NativeCore, ReceiverPolicy::RequiredOriginalNative, 8}},
}};
const std::array<RegisteredPolicy, 1> diagnostics{{
    {"native_receiver_hard_only", {ResilienceAdmission::CompatibilityHardOnly, SolveSchedule::SinglePreferred, ResilienceFallback::HardOnly, ReceiverPolicy::RequiredOriginalNative}},
}};
struct Record {
    std::string file, case_id, fixture, profile, policy, status;
    std::uint64_t seed{};
};
bool capacity_candidate(const std::string& id) {
    return id == "native_receiver_single" || id == "native_receiver_six" || id == "native_receiver_eight";
}
bool enabled(const RegisteredPolicy& policy, const std::string& lane, const std::string& selected) {
    return lane == "primary" || (lane == "regression" && capacity_candidate(policy.id)) ||
           (lane == "validation" && selected == policy.id);
}
std::array<std::uint64_t, 2> lane_seeds(const std::string& lane) {
    if (lane == "primary") return {605, 1701};
    if (lane == "regression") return {2718, 4099};
    return {8191, 12289};
}
void quoted(std::ostream& stream, const std::string& text) {
    stream << '"';
    for (const unsigned char c : text) {
        if (c == '"' || c == '\\') stream << '\\' << c;
        else if (c == '\n') stream << "\\n";
        else if (c == '\r') stream << "\\r";
        else if (c == '\t') stream << "\\t";
        else if (c < 32) throw std::invalid_argument("control character in campaign identity");
        else stream << c;
    }
    stream << '"';
}
void fresh_file(const std::filesystem::path& path) {
    if (std::filesystem::exists(path))
        throw std::invalid_argument("refusing to overwrite retained evidence: " + path.string());
}
std::uint64_t metric(const NegotiatedResult& n, const std::string& key) {
    const auto item = n.metrics.find(key);
    return item == n.metrics.end() ? 0 : item->second;
}
unsigned violations(const NegotiatedResult& n) {
    unsigned count = 0;
    for (const auto* key : {"protected_violations", "illegal_overlaps", "frozen_core_changes", "mosaic_frozen_changes"})
        count += static_cast<unsigned>(metric(n, key));
    return count;
}
void campaign(const std::filesystem::path& out, const std::string& source,
              const std::string& lane, const std::string& selected,
              const std::vector<Record>& records, const std::string& status,
              unsigned unsafe, unsigned invalid) {
    std::ofstream stream(out / "campaign.json", std::ios::binary);
    if (!stream) throw std::runtime_error("cannot create campaign receipt");
    stream << "{\"schema\":2,\"programme\":\"GENTEK-SWARM-003-CONTINUATION\",\"source\":";
    quoted(stream, source); stream << ",\"lane\":"; quoted(stream, lane);
    stream << ",\"result\":"; quoted(stream, status);
    stream << ",\"selected_policy\":"; quoted(stream, selected);
    const auto seeds = lane_seeds(lane);
    stream << ",\"expected_cases_per_policy\":36,\"seeds\":[" << seeds[0] << ',' << seeds[1] << ']'
           << ",\"hard_violations\":" << unsafe << ",\"invalid_candidates\":" << invalid
           << ",\"registered_policies\":[";
    bool first = true;
    for (const auto& policy : policies) {
        if (!enabled(policy, lane, selected)) continue;
        if (!first) stream << ',';
        first = false;
        stream << "{\"id\":"; quoted(stream, policy.id);
        stream << ",\"admission\":"; quoted(stream, name(policy.options.admission));
        stream << ",\"schedule\":"; quoted(stream, name(policy.options.schedule));
        stream << ",\"fallback\":"; quoted(stream, name(policy.options.fallback));
        stream << ",\"receivers\":"; quoted(stream, name(policy.options.receivers));
        stream << ",\"optional_capacity\":" << policy.options.optional_capacity;
        stream << '}';
    }
    stream << "],\"diagnostic_policies\":["; first = true;
    for (const auto& policy : diagnostics) {
        if (!first) stream << ',';
        first = false;
        stream << "{\"id\":"; quoted(stream, policy.id);
        stream << ",\"admission\":"; quoted(stream, name(policy.options.admission));
        stream << ",\"schedule\":"; quoted(stream, name(policy.options.schedule));
        stream << ",\"fallback\":"; quoted(stream, name(policy.options.fallback));
        stream << ",\"receivers\":"; quoted(stream, name(policy.options.receivers));
        stream << ",\"optional_capacity\":" << policy.options.optional_capacity;
        stream << '}';
    }
    stream << "],\"records\":["; first = true;
    for (const auto& record : records) {
        if (!first) stream << ',';
        first = false;
        stream << "{\"file\":"; quoted(stream, record.file);
        stream << ",\"case\":"; quoted(stream, record.case_id);
        stream << ",\"fixture\":"; quoted(stream, record.fixture);
        stream << ",\"profile\":"; quoted(stream, record.profile);
        stream << ",\"seed\":" << record.seed << ",\"policy\":"; quoted(stream, record.policy);
        stream << ",\"mosaic_status\":"; quoted(stream, record.status); stream << '}';
    }
    stream << "]}\n";
    if (!stream) throw std::runtime_error("campaign receipt write failed");
}
} // namespace

int main(int argc, char** argv) try {
    if (argc < 4 || argc > 5)
        throw std::invalid_argument("usage: gentek_resilience OUTPUT SOURCE primary|regression | OUTPUT SOURCE validation POLICY");
    const std::filesystem::path out = argv[1];
    const std::string source = argv[2], lane = argv[3], selected = argc == 5 ? argv[4] : "";
    if ((lane != "primary" && lane != "regression" && lane != "validation") ||
        (lane != "validation" && argc != 4) || (lane == "validation" && argc != 5))
        throw std::invalid_argument("invalid campaign lane or missing frozen validation policy");
    if (lane == "validation" && !capacity_candidate(selected))
        throw std::invalid_argument("validation policy is not one of the three registered capacity candidates");
    if (std::filesystem::exists(out) &&
        (!std::filesystem::is_directory(out) || !std::filesystem::is_empty(out)))
        throw std::invalid_argument("use a fresh empty output directory");
    std::filesystem::create_directories(out / "controls");
    std::vector<Record> records;
    unsigned unsafe = 0, invalid = 0;
    campaign(out, source, lane, selected, records, "RUNNING", unsafe, invalid);
    const auto seeds = lane_seeds(lane);
    for (const auto& fixture_name : fixture_names())
        for (const auto* profile_name : {"sparse_regular", "branching_irregular", "dense_cohesive"})
            for (const auto seed : seeds) {
                const auto f = fixture(fixture_name);
                const auto p = profile(profile_name);
                const auto stem = fixture_name + "_" + profile_name + "_" + std::to_string(seed);
                // Every decision uses this one mechanical/mask preparation.
                // It precedes the controls; no control outcome feeds policy.
                const auto prepared = prepare_admission(f, p, seed, source);
                const auto full = negotiate(f, p, seed, source);
                const auto full_name = "controls/full_control_" + stem + ".json";
                fresh_file(out / full_name);
                write_negotiated_json((out / full_name).string(), full);
                records.push_back({full_name, stem, fixture_name, profile_name, "C", name(full.mosaic.result.status), seed});
                unsafe += violations(full);
                for (const auto cap : {0U, 1U, 2U, 4U}) {
                    if (lane != "primary" && (cap == 1 || cap == 2)) continue;
                    AdmissionPolicy policy;
                    policy.mode = AdmissionMode::OptionalCap;
                    policy.optional_cap = cap;
                    const auto control = negotiate_admission(prepared, policy, false, false);
                    const auto id = "cap" + std::to_string(cap);
                    const auto file = "controls/admission_" + stem + "_" + id + ".json";
                    fresh_file(out / file);
                    write_admission_json((out / file).string(), control);
                    records.push_back({file, stem, fixture_name, profile_name, id, name(control.candidate.mosaic.result.status), seed});
                    unsafe += violations(control.candidate);
                }
                const auto run_policy = [&](const RegisteredPolicy& policy) {
                    const auto result = negotiate_resilient(prepared, policy.options);
                    const auto file = "resilience_" + stem + "_" + policy.id + ".json";
                    fresh_file(out / file);
                    write_resilience_json((out / file).string(), result);
                    records.push_back({file, stem, fixture_name, profile_name, policy.id,
                                       name(result.candidate.mosaic.result.status), seed});
                    unsafe += violations(result.candidate);
                    invalid += result.candidate.mosaic.result.status == Status::Invalid;
                    std::cout << file << " status=" << name(result.candidate.mosaic.result.status)
                              << " joints=" << metric(result.candidate, "joined_slots")
                              << " posthoc=" << metric(result.candidate, "candidate_posthoc_cells")
                              << " mandatory_unresolved=" << metric(result.candidate, "unresolved_mandatory_connectors")
                              << " allocated=" << result.trace.solver.allocated_limit
                              << " fallback=" << result.trace.solver.fallback_used << '\n';
                };
                for (const auto& policy : policies) {
                    if (!enabled(policy, lane, selected)) continue;
                    run_policy(policy);
                }
                for (const auto& policy : diagnostics) run_policy(policy);
                campaign(out, source, lane, selected, records, "RUNNING", unsafe, invalid);
            }
    campaign(out, source, lane, selected, records, unsafe || invalid ? "FAIL" : "PASS", unsafe, invalid);
    std::cout << "RESILIENCE lane=" << lane << " records=" << records.size()
              << " hard_violations=" << unsafe << " invalid=" << invalid << '\n';
    return unsafe || invalid ? 1 : 0;
} catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 2;
}
