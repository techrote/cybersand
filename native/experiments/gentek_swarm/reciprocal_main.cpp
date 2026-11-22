#include "reciprocal_io.hpp"

#include <algorithm>
#include <array>
#include <charconv>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <cstdio>
#include <sstream>
#include <stdexcept>
#include <string_view>

using namespace cybersand::gentek_swarm;
using namespace cybersand::gentek_swarm::assembly004;

namespace {
constexpr std::array<const char*, 13> policies{{"no_negotiation", "legacy_vocabulary", "vocabulary_only", "flat_assembly",
    "fixed_territory", "mosaic_only", "frame_only", "reciprocal_1", "reciprocal_2",
    "reciprocal_3", "reciprocal_4", "native_bearing_off", "validation_off_diagnostic"}};
struct Record {
    std::string file, case_id, fixture, profile, policy, status, view;
    std::uint64_t seed{}, joints{}, still_required{}, work{};
    bool both_revised = false, can_apply = false;
    std::string parent_policy = "";
    std::string work_semantics = "historical generator work; see raw solver receipts";
    bool closure_evaluated = true;
};
void quoted(std::ostream& stream, const std::string& value) {
    stream << '"';
    for (const unsigned char c : value) {
        if (c == '"' || c == '\\') stream << '\\' << c;
        else if (c == '\n') stream << "\\n";
        else if (c == '\r') stream << "\\r";
        else if (c == '\t') stream << "\\t";
        else if (c < 32) throw std::invalid_argument("control character in campaign identity");
        else stream << c;
    }
    stream << '"';
}
std::uint64_t number(std::string_view value) {
    std::uint64_t result{};
    const auto [end, error] = std::from_chars(value.data(), value.data() + value.size(), result);
    if (error != std::errc{} || end != value.data() + value.size()) throw std::invalid_argument("invalid unsigned integer");
    return result;
}
std::uint64_t metric(const std::map<std::string, std::uint64_t>& metrics, const std::string& key) {
    const auto found = metrics.find(key);
    return found == metrics.end() ? 0 : found->second;
}
Options policy_options(const std::string& policy) {
    Options options;
    if (policy == "no_negotiation") {
        options.rounds = 0;
        options.frame_adaptation = options.mosaic_adaptation = false;
    } else if (policy == "vocabulary_only" || policy == "legacy_vocabulary") {
        options.rounds = 0;
        options.shared_ownership = options.frame_adaptation = options.mosaic_adaptation = false;
        options.vocabulary = policy == "vocabulary_only";
    } else if (policy == "flat_assembly") options.hierarchy = false;
    else if (policy == "fixed_territory") options.shared_ownership = false;
    else if (policy == "mosaic_only") options.frame_adaptation = false;
    else if (policy == "frame_only") options.mosaic_adaptation = false;
    else if (policy == "native_bearing_off") options.native_mosaic_bearing = false;
    else if (policy == "validation_off_diagnostic") options.final_validation = false;
    else if (policy.size() == 12 && policy.starts_with("reciprocal_") && policy.back() >= '1' && policy.back() <= '4')
        options.rounds = static_cast<unsigned>(policy.back() - '0');
    else throw std::invalid_argument("unknown registered reciprocal policy: " + policy);
    return options;
}
Profile selected_profile(const std::string& id) {
    if (id == "industrial" || id == "viaduct_like" || id == "irregular_megastructure") return expression_profile(id);
    return profile(id);
}
void fresh_file(const std::filesystem::path& path) {
    if (std::filesystem::exists(path) || std::filesystem::exists(path.string() + ".gz") ||
        std::filesystem::exists(path.string() + ".partial"))
        throw std::invalid_argument("refusing to overwrite retained evidence: " + path.string());
}
void write_campaign(const std::filesystem::path& out, const std::string& source, const std::string& lane,
                    const std::string& selected, const std::vector<std::uint64_t>& seeds,
                    const std::vector<Record>& records, const std::string& result, std::uint64_t violations,
                    std::uint64_t invalid) {
    const auto temporary = out / "campaign.json.partial";
    std::ofstream stream(temporary, std::ios::binary | std::ios::trunc);
    if (!stream) throw std::runtime_error("cannot write reciprocal campaign receipt");
    stream << "{\"schema\":1,\"programme\":\"GENTEK-SWARM-004\",\"source\":"; quoted(stream, source);
    stream << ",\"lane\":"; quoted(stream, lane);
    stream << ",\"selected_policy\":"; quoted(stream, selected);
    stream << ",\"result\":"; quoted(stream, result);
    stream << ",\"expected_cases_per_policy\":" << seeds.size() * 18U << ",\"seeds\":[";
    for (std::size_t i = 0; i < seeds.size(); ++i) { if (i) stream << ','; stream << seeds[i]; }
    stream << "],\"registered_policies\":[";
    bool first = true;
    for (const auto* policy : policies) {
        if (!selected.empty() && selected != policy && std::string_view(policy) != "no_negotiation" && std::string_view(policy) != "reciprocal_1") continue;
        if (!first) stream << ',';
        first = false;
        quoted(stream, policy);
    }
    stream << "],\"hard_violations\":" << violations << ",\"invalid_candidates\":" << invalid
           << ",\"storage_note\":\"Completed raw JSON may be losslessly compressed to the same path plus .gz by the supervising runner; storage.json binds both hashes.\""
           << ",\"records\":[";
    first = true;
    for (const auto& record : records) {
        if (!first) stream << ',';
        first = false;
        stream << "{\"file\":"; quoted(stream, record.file);
        stream << ",\"case\":"; quoted(stream, record.case_id);
        stream << ",\"fixture\":"; quoted(stream, record.fixture);
        stream << ",\"profile\":"; quoted(stream, record.profile);
        stream << ",\"policy\":"; quoted(stream, record.policy);
        stream << ",\"status\":"; quoted(stream, record.status);
        stream << ",\"view\":"; quoted(stream, record.view);
        stream << ",\"parent_policy\":"; quoted(stream, record.parent_policy);
        stream << ",\"work_semantics\":"; quoted(stream, record.work_semantics);
        stream << ",\"seed\":" << record.seed << ",\"joints\":" << record.joints
               << ",\"still_required\":" << record.still_required << ",\"work\":" << record.work
               << ",\"both_revised\":" << (record.both_revised ? "true" : "false")
               << ",\"can_apply\":" << (record.can_apply ? "true" : "false")
               << ",\"closure_evaluated\":" << (record.closure_evaluated ? "true" : "false") << '}';
    }
    stream << "]}\n";
    stream.close();
    if (!stream) throw std::runtime_error("reciprocal campaign receipt write failed");
    // This progress index is replaceable; individual source-qualified records
    // never are. Removing first also supports Windows rename semantics.
    std::filesystem::remove(out / "campaign.json");
    std::filesystem::rename(temporary, out / "campaign.json");
}
std::uint64_t control_violations(const NegotiatedResult& control) {
    std::uint64_t total = 0;
    for (const auto* key : {"protected_violations", "illegal_overlaps", "frozen_core_changes", "mosaic_frozen_changes"})
        total += metric(control.metrics, key);
    return total;
}

MosaicRevision matched_final_frame_control(const Composition& candidate) {
    const auto& final = candidate.rounds.back();
    MosaicRevision control;
    control.request = final.mosaic_request;
    control.request.neighbor_cells = final.frame.result.cells;
    control.request.neighbors = final.frame.result.boundary;
    control.request.neighbors.protected_geometry = final.mosaic_request.neighbors.protected_geometry;
    // Preserve all accepted mask/domain inputs. In particular, do not expand
    // the normalized eligibility through shared_zone a second time. Native
    // allowed() independently excludes the exact final foreign material.
    control.request.limits.max_bytes = 16U * 1024U * 1024U;
    control.request.limits.max_solver_work = 4'000'000;
    const auto count = static_cast<std::size_t>(control.request.width) * static_cast<std::size_t>(control.request.height);
    control.wrapper_work = 512U + count * 8U + final.frame.result.boundary.hard.size() * 32U;
    if (control.wrapper_work >= 2'000'000) {
        control.status = MosaicRevisionStatus::Exhausted;
        control.reason = "matched-frame control preparation exhausted its independent generator allowance";
        return control;
    }
    control.request.limits.max_work = 2'000'000 - control.wrapper_work;
    std::string reason;
    if (!validate_request(control.request, reason)) {
        control.status = MosaicRevisionStatus::Invalid;
        control.reason = "matched-frame control retained an invalid accepted request: " + reason;
        return control;
    }
    const auto options = candidate.input.options.optional_negotiation ?
        ResilienceOptions{ResilienceAdmission::CompatibilityFour, SolveSchedule::SinglePreferred,
            ResilienceFallback::NativeCore, ReceiverPolicy::RequiredOriginalNative, 8} :
        ResilienceOptions{ResilienceAdmission::CompatibilityHardOnly, SolveSchedule::SinglePreferred,
            ResilienceFallback::HardOnly, ReceiverPolicy::RequiredOriginalNative, 4};
    control.plan = negotiate_mosaic_resilient(control.request, {}, options, control.trace);
    control.generator_work = control.plan.result.work;
    for (const auto& attempt : control.plan.attempts) {
        control.solver_debit += attempt.work_observed ? attempt.work : attempt.attempted ? attempt.work_limit : 0;
        control.solver_work_observed = control.solver_work_observed && attempt.work_observed;
    }
    switch (control.plan.result.status) {
    case Status::Complete: control.status = MosaicRevisionStatus::Complete; break;
    case Status::Blocked: case Status::Damaged: control.status = MosaicRevisionStatus::Blocked; break;
    case Status::Unsat: control.status = MosaicRevisionStatus::Unsat; break;
    case Status::Exhausted: control.status = MosaicRevisionStatus::Exhausted; break;
    case Status::Invalid: control.status = MosaicRevisionStatus::Invalid; break;
    }
    control.reason = control.plan.result.termination;
    if (control.generator_work + control.wrapper_work > 2'000'000 || control.solver_debit > 4'000'000) {
        control.status = MosaicRevisionStatus::Invalid;
        control.reason = "matched-frame control exceeded its independent accounted allowance";
    }
    if (control.plan.result.cells.size() == count && final.mosaic.result.cells.size() == count) {
        for (std::size_t i = 0; i < count; ++i) {
            if (control.plan.result.cells[i] != final.mosaic.result.cells[i])
                control.geometry_changes.push_back({static_cast<std::uint32_t>(i), final.mosaic.result.cells[i],
                    control.plan.result.cells[i], final.mosaic.result.provenance[i], control.plan.result.provenance[i]});
        }
    }
    if (control.plan.categories.size() == final.mosaic.categories.size()) {
        for (std::size_t i = 0; i < control.plan.categories.size(); ++i)
            if (control.plan.categories[i] != final.mosaic.categories[i])
                control.category_changes.push_back({static_cast<std::uint32_t>(i), final.mosaic.categories[i], control.plan.categories[i]});
    }
    return control;
}

class RequestTokens {
public:
    explicit RequestTokens(const std::filesystem::path& path) {
        constexpr std::size_t maximum = 2U * 1024U * 1024U;
        if (!std::filesystem::is_regular_file(path) || std::filesystem::file_size(path) > maximum)
            throw std::invalid_argument("request must be a regular text file of at most 2MiB");
        std::ifstream file(path, std::ios::binary);
        if (!file) throw std::invalid_argument("cannot read reciprocal request file");
        std::string bytes(maximum + 1, '\0');
        file.read(bytes.data(), static_cast<std::streamsize>(bytes.size()));
        const auto read = file.gcount();
        if (read < 0 || static_cast<std::size_t>(read) > maximum || file.bad())
            throw std::invalid_argument("request changed size or failed its bounded read");
        bytes.resize(static_cast<std::size_t>(read));
        stream_.str(std::move(bytes));
    }
    std::string token() {
        std::string value;
        if (!(stream_ >> value) || value.empty() || value.size() > 96)
            throw std::invalid_argument("missing or oversized reciprocal request token");
        return value;
    }
    int integer(int minimum, int maximum) {
        const auto value = token();
        std::int64_t parsed{};
        const auto [end, error] = std::from_chars(value.data(), value.data() + value.size(), parsed);
        if (error != std::errc{} || end != value.data() + value.size() || parsed < minimum || parsed > maximum)
            throw std::invalid_argument("reciprocal integer outside its declared range");
        return static_cast<int>(parsed);
    }
    double parameter() {
        const auto value = token();
        double parsed{};
        const auto [end, error] = std::from_chars(value.data(), value.data() + value.size(), parsed);
        if (error != std::errc{} || end != value.data() + value.size() || !std::isfinite(parsed) || parsed < 0 || parsed > 1)
            throw std::invalid_argument("reciprocal parameter must be finite and normalized to 0..1");
        return parsed;
    }
    void finish() {
        std::string extra;
        if (stream_ >> extra) throw std::invalid_argument("unexpected trailing reciprocal request tokens");
    }
private:
    std::istringstream stream_;
};

Input read_request(const std::filesystem::path& path, const std::string& source) {
    if (source.empty() || source.size() > 128) throw std::invalid_argument("invalid request source identity");
    RequestTokens tokens(path);
    const auto protocol_magic = tokens.token();
    if (protocol_magic != "SWARM004" && protocol_magic != "SWARM005" && protocol_magic != "SWARM006")
        throw std::invalid_argument("unknown reciprocal request protocol or version");
    const auto protocol_version = protocol_magic == "SWARM006" ? tokens.integer(4,4) :
        protocol_magic == "SWARM005" ? tokens.integer(3, 3) : tokens.integer(1, 2);
    Input input;
    input.frame.gentek = Kind::Frameweaver;
    input.mosaic.gentek = Kind::Mosaic;
    input.frame.width = input.mosaic.width = tokens.integer(1, 256);
    input.frame.height = input.mosaic.height = tokens.integer(1, 128);
    input.frame.seed = input.mosaic.seed = number(tokens.token());
    input.frame.origin.x = input.mosaic.origin.x = tokens.integer(-1'000'000, 1'000'000);
    input.frame.origin.y = input.mosaic.origin.y = tokens.integer(-1'000'000, 1'000'000);
    input.options.rounds = static_cast<unsigned>(tokens.integer(0, 4));
    input.options.shared_extent = static_cast<unsigned>(tokens.integer(0, 13));
    input.options.orientation_preference = tokens.integer(-1, 1);
    const auto expression = tokens.token();
    if (expression != "industrial" && expression != "viaduct_like" && expression != "irregular_megastructure")
        throw std::invalid_argument("unknown Workbench structural expression profile");
    const auto parameters = [&]() {
        auto profile = expression_profile(expression);
        profile.variation = tokens.parameter();
        profile.irregularity = tokens.parameter();
        profile.clutter = tokens.parameter();
        profile.destruction = tokens.parameter();
        profile.branching = tokens.parameter();
        profile.environment_affinity = tokens.parameter();
        profile.cohesion = tokens.parameter();
        return profile;
    };
    input.frame.profile = input.mosaic.profile = parameters();
    input.options.optional_negotiation = tokens.integer(0, 1) != 0;
    // SWARM004 V1/V2 remain unchanged. New SWARM005 V3 is opt-in and
    // carries independent profiles, sharing and exact sourced closure switches.
    if (protocol_version >= 2) {
        input.mosaic.profile = parameters();
        input.options.shared_ownership = tokens.integer(0, 1) != 0;
    }
    if (protocol_version >= 3) {
        input.options.compact_native_termination = tokens.integer(0, 1) != 0;
        input.options.supported_native_receptors = tokens.integer(0, 1) != 0;
    }
    if(protocol_version==4)input.options.negotiated_recovery=tokens.integer(0,1)!=0;
    const auto activation_count = tokens.integer(0, 16);
    for (int i = 0; i < activation_count; ++i) {
        const Point point{tokens.integer(0, input.frame.width - 1), tokens.integer(0, input.frame.height - 1)};
        input.frame.activation.push_back(point);
        input.mosaic.activation.push_back(point);
    }
    const auto count = static_cast<std::size_t>(input.frame.width) * static_cast<std::size_t>(input.frame.height);
    input.frame.eligible.resize(count);
    input.mosaic.eligible.resize(count);
    input.frame.protected_void.resize(count);
    input.shared_zone.resize(count);
    input.frame.context.resize(count);
    for (std::size_t i = 0; i < count; ++i) {
        input.frame.eligible[i] = static_cast<std::uint8_t>(tokens.integer(0, 1));
        input.mosaic.eligible[i] = static_cast<std::uint8_t>(tokens.integer(0, 1));
        input.frame.protected_void[i] = static_cast<std::uint8_t>(tokens.integer(0, 1));
        input.shared_zone[i] = static_cast<std::uint8_t>(tokens.integer(0, 1));
        const auto material = tokens.integer(0, 131);
        if (material == 10) throw std::invalid_argument("reserved material ID is not a native context material");
        input.frame.context[i] = static_cast<cybersand::Material>(material);
        if (input.frame.eligible[i] && input.mosaic.eligible[i])
            throw std::invalid_argument("base FRAME/MOSAIC territories overlap");
    }
    tokens.finish();
    input.frame.source_identity = input.mosaic.source_identity = source;
    input.frame.fixture = input.mosaic.fixture = "workbench_territory";
    input.frame.definition_fingerprint = definition(Kind::Frameweaver);
    input.mosaic.definition_fingerprint = definition(Kind::Mosaic);
    input.mosaic.limits.max_instances = 192;
    input.mosaic.protected_void = input.frame.protected_void;
    input.mosaic.context = input.frame.context;
    input.frame.transition = input.mosaic.transition = input.shared_zone;
    if (!input.options.shared_ownership)
        std::fill(input.shared_zone.begin(), input.shared_zone.end(), 0);
    // assemble() independently validates the actual L1 interface extent and
    // cell claims; UI-supplied masks do not grant additional native authority.
    return input;
}
} // namespace

int main(int argc, char** argv) try {
    if (argc < 2) throw std::invalid_argument("usage: gentek_reciprocal campaign OUTPUT SOURCE known|holdout [SELECTED] | single OUTPUT SOURCE FIXTURE PROFILE SEED ROUNDS POLICY | request INPUT OUTPUT SOURCE");
    const std::string mode = argv[1];
    if (mode == "request") {
        if (argc != 5) throw std::invalid_argument("request requires INPUT OUTPUT SOURCE");
        fresh_file(argv[3]);
        const auto input = read_request(argv[2], argv[4]);
        const auto result = assemble(input);
        write_composition_json(argv[3], result);
        std::printf("RECIPROCAL_REQUEST status=%s joints=%zu apply=%d\n", name(result.status),
                    result.joints.size(), static_cast<int>(result.can_apply));
        return result.status == CompositionStatus::Invalid ? 1 : 0;
    }
    if (mode == "single") {
        if (argc != 9) throw std::invalid_argument("single requires OUTPUT SOURCE FIXTURE PROFILE SEED ROUNDS POLICY");
        const std::filesystem::path out = argv[2];
        fresh_file(out);
        auto options = policy_options(argv[8]);
        const auto rounds = number(argv[7]);
        if (rounds > 4) throw std::invalid_argument("round cap must be 0..4");
        options.rounds = static_cast<unsigned>(rounds);
        const auto result = assemble(input_for(fixture(argv[4]), selected_profile(argv[5]), number(argv[6]), argv[3], options));
        write_composition_json(out.string(), result);
        std::printf("RECIPROCAL_SINGLE status=%s rounds=%zu joints=%zu apply=%d\n", name(result.status),
                    result.rounds.size(), result.joints.size(), static_cast<int>(result.can_apply));
        return result.status == CompositionStatus::Invalid ? 1 : 0;
    }
    if (mode != "campaign" || argc < 5 || argc > 6) throw std::invalid_argument("campaign requires OUTPUT SOURCE known|holdout [SELECTED]");
    const std::filesystem::path out = argv[2];
    const std::string source = argv[3], lane = argv[4], selected = argc == 6 ? argv[5] : "";
    if (source.empty() || source.size() > 128) throw std::invalid_argument("invalid source identity");
    if (lane != "known" && lane != "holdout") throw std::invalid_argument("unknown reciprocal campaign lane");
    if (lane == "holdout" && (selected.empty() || selected == "validation_off_diagnostic"))
        throw std::invalid_argument("holdout requires exactly one frozen admissible selected policy");
    if (!selected.empty()) (void)policy_options(selected);
    if (std::filesystem::exists(out) && (!std::filesystem::is_directory(out) || !std::filesystem::is_empty(out)))
        throw std::invalid_argument("use a fresh empty campaign output directory");
    std::filesystem::create_directories(out / "controls");
    const std::vector<std::uint64_t> seeds = lane == "known" ?
        std::vector<std::uint64_t>{605, 1701, 2718, 4099, 8191, 12289} : std::vector<std::uint64_t>{19457, 32771};
    std::vector<Record> records;
    std::uint64_t violations = 0, invalid = 0;
    write_campaign(out, source, lane, selected, seeds, records, "RUNNING", violations, invalid);
    for (const auto& fixture_name : fixture_names())
        for (const auto* profile_name : {"sparse_regular", "branching_irregular", "dense_cohesive"})
            for (const auto seed : seeds) {
                const auto f = fixture(fixture_name);
                const auto p = profile(profile_name);
                const auto stem = fixture_name + "_" + profile_name + "_" + std::to_string(seed);
                const auto prepared = prepare_admission(f, p, seed, source);
                const auto c = negotiate(f, p, seed, source);
                const auto c_file = "controls/C_" + stem + ".json";
                fresh_file(out / c_file);
                write_negotiated_json((out / c_file).string(), c);
                violations += control_violations(c);
                records.push_back({c_file, stem, fixture_name, profile_name, "A", name(c.control.clipped_right.status), "control.clipped_cells", seed,
                    0, c.control.clipped_left.unresolved_joints, c.control.clipped_left.work + c.control.clipped_right.work});
                records.push_back({c_file, stem, fixture_name, profile_name, "B", name(c.control.right.status), "control.cells", seed,
                    c.control.bridges + c.control.typed_contacts, c.control.left.unresolved_joints, c.control.work});
                records.back().work_semantics = "historical shared mesher work only; native generator/solver work retained in raw arrays";
                records.push_back({c_file, stem, fixture_name, profile_name, "C", name(c.mosaic.result.status), "cells", seed,
                    metric(c.metrics, "joined_slots"), metric(c.metrics, "unresolved_mandatory_connectors"), metric(c.metrics, "candidate_generator_work")});
                AdmissionPolicy cap;
                cap.mode = AdmissionMode::OptionalCap; cap.optional_cap = 4;
                const auto cap4 = negotiate_admission(prepared, cap, false, false);
                const auto cap_file = "controls/cap4_" + stem + ".json";
                fresh_file(out / cap_file);
                write_admission_json((out / cap_file).string(), cap4);
                violations += control_violations(cap4.candidate);
                records.push_back({cap_file, stem, fixture_name, profile_name, "cap4", name(cap4.candidate.mosaic.result.status), "candidate.cells", seed,
                    metric(cap4.candidate.metrics, "joined_slots"), metric(cap4.candidate.metrics, "unresolved_mandatory_connectors"),
                    metric(cap4.candidate.metrics, "candidate_generator_work")});
                for (const bool hard_only : {false, true}) {
                    const ResilienceOptions options = hard_only ?
                        ResilienceOptions{ResilienceAdmission::CompatibilityHardOnly, SolveSchedule::SinglePreferred,
                            ResilienceFallback::HardOnly, ReceiverPolicy::RequiredOriginalNative, 4} :
                        ResilienceOptions{ResilienceAdmission::CompatibilityFour, SolveSchedule::SinglePreferred,
                            ResilienceFallback::NativeCore, ReceiverPolicy::RequiredOriginalNative, 8};
                    const auto result = negotiate_resilient(prepared, options);
                    const auto policy = hard_only ? "E8_hard_only" : "E8";
                    const auto file = "controls/" + std::string(policy) + '_' + stem + ".json";
                    fresh_file(out / file);
                    write_resilience_json((out / file).string(), result);
                    violations += control_violations(result.candidate);
                    records.push_back({file, stem, fixture_name, profile_name, policy, name(result.candidate.mosaic.result.status), "candidate.cells", seed,
                        metric(result.candidate.metrics, "joined_slots"), metric(result.candidate.metrics, "unresolved_mandatory_connectors"),
                        metric(result.candidate.metrics, "candidate_generator_work")});
                }
                for (const auto* policy : policies) {
                    if (!selected.empty() && selected != policy && std::string_view(policy) != "no_negotiation" && std::string_view(policy) != "reciprocal_1") continue;
                    const auto result = assemble(input_for(f, p, seed, source, policy_options(policy)));
                    const auto file = "reciprocal_" + stem + '_' + policy + ".json";
                    fresh_file(out / file);
                    write_composition_json((out / file).string(), result);
                    violations += metric(result.metrics, "hard_violations");
                    invalid += result.status == CompositionStatus::Invalid;
                    records.push_back({file, stem, fixture_name, profile_name, policy, name(result.status), "cells", seed,
                        result.joints.size(), metric(result.metrics, "still_required"), metric(result.metrics, "total_charged_work"),
                        metric(result.metrics, "both_genteks_revised") != 0, result.can_apply});
                    records.back().work_semantics = "aggregate charged candidate FRAME/MOSAIC/solver/shared work; excludes controls";
                    records.back().closure_evaluated = result.metrics.contains("still_required");
                    if (!result.rounds.empty()) {
                        const auto& first_frame = result.rounds.front().frame.result.cells;
                        const auto& final_frame = result.rounds.back().frame.result.cells;
                        std::uint64_t changed_frame_cells = 0;
                        if (first_frame.size() == final_frame.size())
                            for (std::size_t i = 0; i < first_frame.size(); ++i) changed_frame_cells += first_frame[i] != final_frame[i];
                        if (changed_frame_cells) {
                            const auto control = matched_final_frame_control(result);
                            const auto control_file = "controls/final_frame_no_offer_" + stem + '_' + policy + ".json";
                            fresh_file(out / control_file);
                            write_matched_mosaic_control_json((out / control_file).string(), policy, result,
                                result.rounds.back().mosaic_request, control, changed_frame_cells);
                            invalid += control.status == MosaicRevisionStatus::Invalid;
                            records.push_back({control_file, stem, fixture_name, profile_name,
                                "matched_final_frame__" + std::string(policy), name(control.status), "cells", seed,
                                0, 0, control.wrapper_work + control.generator_work + control.solver_debit, false, false});
                            records.back().parent_policy = policy;
                            records.back().closure_evaluated = false;
                            records.back().work_semantics = "separate control-only generator+solver debit; not candidate work; closure not evaluated";
                        }
                    }
                    std::printf("%s status=%s joints=%zu both=%llu apply=%d\n", file.c_str(), name(result.status),
                                result.joints.size(), static_cast<unsigned long long>(metric(result.metrics, "both_genteks_revised")),
                                static_cast<int>(result.can_apply));
                    std::fflush(stdout);
                }
                write_campaign(out, source, lane, selected, seeds, records, "RUNNING", violations, invalid);
            }
    write_campaign(out, source, lane, selected, seeds, records, violations || invalid ? "FAIL" : "PASS", violations, invalid);
    std::printf("RECIPROCAL lane=%s records=%zu hard_violations=%llu invalid=%llu\n", lane.c_str(), records.size(),
                static_cast<unsigned long long>(violations), static_cast<unsigned long long>(invalid));
    return violations || invalid ? 1 : 0;
} catch (const std::exception& error) {
    std::fprintf(stderr, "%s\n", error.what());
    return 2;
}
