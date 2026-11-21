#include "reciprocal.hpp"

#include <array>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <map>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

using namespace cybersand::gentek_swarm;
using cybersand::Material;
namespace a = cybersand::gentek_swarm::assembly004;

namespace {
constexpr std::array<const char*, 13> policies{{"no_negotiation", "legacy_vocabulary", "vocabulary_only",
    "flat_assembly", "fixed_territory", "mosaic_only", "frame_only", "reciprocal_1", "reciprocal_2",
    "reciprocal_3", "reciprocal_4", "native_bearing_off", "validation_off_diagnostic"}};

void require(bool value, const char* reason) { if (!value) throw std::runtime_error(reason); }

a::Options options_for(const std::string& policy) {
    a::Options options;
    if (policy == "no_negotiation") {
        options.rounds = 0; options.frame_adaptation = options.mosaic_adaptation = false;
    } else if (policy == "legacy_vocabulary" || policy == "vocabulary_only") {
        options.rounds = 0; options.shared_ownership = options.frame_adaptation = options.mosaic_adaptation = false;
        options.vocabulary = policy == "vocabulary_only";
    } else if (policy == "flat_assembly") options.hierarchy = false;
    else if (policy == "fixed_territory") options.shared_ownership = false;
    else if (policy == "mosaic_only") options.frame_adaptation = false;
    else if (policy == "frame_only") options.mosaic_adaptation = false;
    else if (policy == "native_bearing_off") options.native_mosaic_bearing = false;
    else if (policy == "validation_off_diagnostic") options.final_validation = false;
    else if (policy.size() == 12 && policy.starts_with("reciprocal_") && policy.back() >= '1' && policy.back() <= '4')
        options.rounds = static_cast<unsigned>(policy.back() - '0');
    else throw std::invalid_argument("unregistered policy");
    return options;
}

std::optional<std::uint64_t> footprint(const Result& before, const Result& after, std::size_t count) {
    if (before.cells.size() != count || after.cells.size() != count) return std::nullopt;
    std::uint64_t changed = 0;
    for (std::size_t i = 0; i < count; ++i)
        changed += (before.cells[i] == Material::Empty) != (after.cells[i] == Material::Empty);
    return changed;
}

void optional_number(std::ostream& out, const std::optional<std::uint64_t>& value) {
    if (value) out << *value; else out << "null";
}

struct Row {
    std::string policy, fixture, profile, stem, no_offer_status, frozen_peer_status;
    std::uint64_t seed{}, joints{};
    bool apply{}, causal{};
    std::optional<std::uint64_t> mosaic_effect, frame_effect;
};
using Counts = std::map<std::string, std::map<std::string, std::uint64_t>>;

void save(const std::filesystem::path& out, const std::string& source, const std::string& lane,
          const char* status, const Counts& totals, const std::vector<Row>& rows,
          const std::vector<std::string>& files) {
    {
        std::ofstream index(out / "campaign.json.partial");
        index << "{\"result\":\"" << status << "\",\"records\":[";
        for (std::size_t i = 0; i < files.size(); ++i) {
            if (i) index << ',';
            index << "{\"file\":\"" << files[i] << "\"}";
        }
        index << "]}\n"; index.close(); require(bool(index), "causal raw index write failed");
        std::filesystem::remove(out / "campaign.json");
        std::filesystem::rename(out / "campaign.json.partial", out / "campaign.json");
    }
    std::ofstream stream(out / "causal_summary.json.partial");
    stream << "{\"schema\":1,\"programme\":\"GENTEK-SWARM-004\",\"source\":\"" << source
           << "\",\"lane\":\"" << lane << "\",\"result\":\"" << status
           << "\",\"scope\":\"Independent counterfactual work; excluded from candidate budgets. Matched round-one masks/peer/remaining budget without offered slots; same initial pair with MOSAIC frozen through the coordinator.\",\"policy_totals\":{";
    bool first = true;
    for (const auto& [policy, counts] : totals) {
        if (!first) stream << ',';
        first = false; stream << '"' << policy << "\":{";
        bool first_count = true;
        for (const auto& [name, value] : counts) {
            if (!first_count) stream << ',';
            first_count = false; stream << '"' << name << "\":" << value;
        }
        stream << '}';
    }
    stream << "},\"records\":[";
    first = true;
    for (const auto& row : rows) {
        if (!first) stream << ',';
        first = false;
        stream << "{\"policy\":\"" << row.policy << "\",\"fixture\":\"" << row.fixture
               << "\",\"profile\":\"" << row.profile << "\",\"seed\":" << row.seed
               << ",\"joints\":" << row.joints << ",\"can_apply\":" << (row.apply ? "true" : "false")
               << ",\"no_offer_status\":\"" << row.no_offer_status << "\",\"frozen_peer_status\":\"" << row.frozen_peer_status
               << "\",\"mosaic_offer_footprint_effect\":";
        optional_number(stream, row.mosaic_effect);
        stream << ",\"frame_peer_revision_footprint_effect\":"; optional_number(stream, row.frame_effect);
        stream << ",\"causal_both\":" << (row.causal ? "true" : "false")
               << ",\"candidate\":\"" << row.stem << "_candidate.json\",\"no_offer\":\"" << row.stem
               << "_no_offer.json\",\"frozen_peer\":\"" << row.stem << "_frozen_peer.json\"}";
    }
    stream << "]}\n"; stream.close(); require(bool(stream), "causal summary write failed");
    std::filesystem::remove(out / "causal_summary.json");
    std::filesystem::rename(out / "causal_summary.json.partial", out / "causal_summary.json");
}
}

int main(int argc, char** argv) try {
    if (argc < 4 || argc > 5)
        throw std::invalid_argument("usage: audit_reciprocal_causality OUTPUT SOURCE known|holdout [SELECTED]");
    const std::filesystem::path out = argv[1];
    const std::string source = argv[2], lane = argv[3], selected = argc == 5 ? argv[4] : "";
    require(!source.empty() && source.find_first_not_of("0123456789abcdef+dirty-.") == std::string::npos,
            "source identity has invalid characters");
    require(lane == "known" || lane == "holdout", "invalid causal lane");
    require(lane != "holdout" || (!selected.empty() && selected != "validation_off_diagnostic"),
            "holdout causal audit requires the frozen selected policy");
    if (!selected.empty()) (void)options_for(selected);
    require(!std::filesystem::exists(out) || (std::filesystem::is_directory(out) && std::filesystem::is_empty(out)),
            "fresh causal evidence directory required");
    std::filesystem::create_directories(out);
    const std::vector<std::uint64_t> seeds = lane == "known" ?
        std::vector<std::uint64_t>{605,1701,2718,4099,8191,12289} : std::vector<std::uint64_t>{19457,32771};
    Counts totals; std::vector<Row> rows; std::vector<std::string> files;
    save(out, source, lane, "RUNNING", totals, rows, files);
    for (const auto* policy_value : policies) {
        const std::string policy = policy_value;
        if (!selected.empty() && selected != policy && policy != "no_negotiation" && policy != "reciprocal_1") continue;
        for (const auto& fixture_name : fixture_names())
            for (const auto* profile_name : {"sparse_regular","branching_irregular","dense_cohesive"})
                for (const auto seed : seeds) {
                    const auto input = a::input_for(fixture(fixture_name), profile(profile_name), seed, source, options_for(policy));
                    const auto candidate = a::assemble(input);
                    auto& counts = totals[policy]; ++counts["cases"];
                    require(candidate.status != a::CompositionStatus::Invalid, "invalid candidate during causal replay");
                    if (candidate.rounds.size() < 3 || !candidate.metrics.contains("both_genteks_revised") ||
                        !candidate.metrics.at("both_genteks_revised")) continue;
                    ++counts["nominal_both"]; counts["nominal_complete"] += candidate.can_apply;
                    const auto& initial = candidate.rounds[0]; const auto& revised = candidate.rounds[1];
                    auto request = input.mosaic; request.profile.destruction = 0;
                    if (request.protected_void.empty()) request.protected_void.assign(initial.frame.result.cells.size(), 0);
                    for (std::size_t i = 0; i < request.protected_void.size(); ++i)
                        request.protected_void[i] = static_cast<std::uint8_t>(request.protected_void[i] ||
                            (!initial.frame.result.boundary.protected_geometry.empty() && initial.frame.result.boundary.protected_geometry[i]) ||
                            (!initial.mosaic.result.boundary.protected_geometry.empty() && initial.mosaic.result.boundary.protected_geometry[i]));
                    a::MosaicBudget budget;
                    budget.generator_remaining = input.mosaic.limits.max_work - initial.mosaic_work;
                    budget.solver_remaining = input.mosaic.limits.max_solver_work - initial.solver_work;
                    budget.max_bytes = input.mosaic.limits.max_bytes; budget.proposals_remaining = 4;
                    const auto shared = input.options.shared_ownership ? input.shared_zone : std::vector<std::uint8_t>(request.eligible.size(), 0);
                    const auto no_offer = a::propose_mosaic_revision(request, initial.frame.result, {}, shared, budget, 1,
                        &initial.mosaic.result, &initial.mosaic.categories, input.options.optional_negotiation, input.options.native_mosaic_bearing);
                    const bool mosaic_control_available = no_offer.status == a::MosaicRevisionStatus::Complete ||
                        no_offer.status == a::MosaicRevisionStatus::Blocked;
                    if (mosaic_control_available)
                        require(no_offer.request.eligible == revised.mosaic_request.eligible &&
                                no_offer.request.protected_void == revised.mosaic_request.protected_void &&
                                no_offer.request.context == revised.mosaic_request.context &&
                                no_offer.request.neighbor_cells == revised.mosaic_request.neighbor_cells,
                                "no-offer control changed accepted masks/context/peer geometry");
                    auto frozen_input = input; frozen_input.options.mosaic_adaptation = false;
                    const auto frozen = a::assemble(frozen_input);
                    require(!frozen.rounds.empty() && frozen.rounds.front().frame.result.cells == initial.frame.result.cells &&
                            frozen.rounds.front().mosaic.result.cells == initial.mosaic.result.cells,
                            "frozen-peer control changed initial geometry");
                    for (const auto& round : frozen.rounds)
                        require(round.mosaic.result.cells == initial.mosaic.result.cells, "frozen-peer control revised MOSAIC");
                    const auto count = static_cast<std::size_t>(input.frame.width) * input.frame.height;
                    Row row; row.policy = policy; row.fixture = fixture_name; row.profile = profile_name; row.seed = seed;
                    row.stem = policy + '_' + fixture_name + '_' + profile_name + '_' + std::to_string(seed);
                    row.joints = candidate.joints.size(); row.apply = candidate.can_apply;
                    row.no_offer_status = a::name(no_offer.status); row.frozen_peer_status = a::name(frozen.status);
                    // A failed control may retain a full-sized partial array.
                    // Such arrays are evidence of the refusal, not a usable
                    // counterfactual for a positive causal claim.
                    if (mosaic_control_available)
                        row.mosaic_effect = footprint(revised.mosaic.result, no_offer.plan.result, count);
                    if (frozen.status == a::CompositionStatus::Complete || frozen.status == a::CompositionStatus::Blocked)
                        row.frame_effect = footprint(candidate.rounds.back().frame.result, frozen.rounds.back().frame.result, count);
                    row.causal = row.mosaic_effect && *row.mosaic_effect > 0 && row.frame_effect && *row.frame_effect > 0;
                    counts["controls_unavailable"] += !row.mosaic_effect || !row.frame_effect;
                    counts["causal_both"] += row.causal;
                    counts["causal_both_with_joint"] += row.causal && row.joints > 0;
                    counts["causal_complete"] += row.causal && row.apply;
                    counts["noncausal_complete"] += row.mosaic_effect && row.frame_effect && !row.causal && row.apply;
                    counts["causality_unknown_complete"] += (!row.mosaic_effect || !row.frame_effect) && row.apply;
                    const auto candidate_file = row.stem + "_candidate.json";
                    const auto no_offer_file = row.stem + "_no_offer.json";
                    const auto frozen_file = row.stem + "_frozen_peer.json";
                    a::write_composition_json((out / candidate_file).string(), candidate);
                    write_result_json((out / no_offer_file).string(), no_offer.request, no_offer.plan.result);
                    a::write_composition_json((out / frozen_file).string(), frozen);
                    files.insert(files.end(), {candidate_file, no_offer_file, frozen_file}); rows.push_back(row);
                    save(out, source, lane, "RUNNING", totals, rows, files);
                }
    }
    save(out, source, lane, "PASS", totals, rows, files);
    std::cout << "RECIPROCAL_CAUSAL PASS lane=" << lane << " nominal_controls=" << rows.size() << '\n';
    return 0;
} catch (const std::exception& error) {
    std::cerr << error.what() << '\n'; return 1;
}
