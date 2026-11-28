// SWARM-006 comparison harness. Build the SAME harness against frozen 004/005
// sources with explicit feature macros; unsupported treatments fail, never alias.
#include "reciprocal_io.hpp"

#include <algorithm>
#include <atomic>
#include <charconv>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <limits>
#include <optional>
#include <stdexcept>
#include <string>
#include <string_view>

using namespace cybersand::gentek_swarm;
namespace a = cybersand::gentek_swarm::assembly004;

namespace {
std::uint64_t number(std::string_view value) {
    std::uint64_t n{};
    const auto [end, error] = std::from_chars(value.data(), value.data() + value.size(), n);
    if (error != std::errc{} || end != value.data() + value.size())
        throw std::invalid_argument("invalid unsigned integer");
    return n;
}
void quoted(std::ostream& out, const std::string& value) {
    out << '"';
    for (const unsigned char c : value) {
        if (c == '"' || c == '\\') out << '\\' << c;
        else if (c == '\n') out << "\\n";
        else if (c == '\r') out << "\\r";
        else if (c == '\t') out << "\\t";
        else if (c < 32) throw std::invalid_argument("control character in identity");
        else out << c;
    }
    out << '"';
}
const char* variant() {
#if defined(GENTEK_SWARM006_RECOVERY)
    return "swarm006";
#elif defined(GENTEK_SWARM005)
    return "swarm005";
#else
    return "swarm004";
#endif
}
struct Policy {
    a::Options options;
    bool reverse = false, cancelled = false;
    std::uint64_t frame_work = 2'000'000, mosaic_work = 2'000'000, solver_work = 4'000'000;
    std::size_t memory = 16U * 1024U * 1024U;
};
Policy policy_for(std::string name, unsigned rounds) {
    Policy result;
    result.options.rounds = rounds;
    const auto delimiter = name.find('+');
    const auto treatment = name.substr(0, delimiter);
    const bool recovery = treatment == "recovery" || treatment == "recovery_without_005";
    const bool compact = treatment == "terminal_only" || treatment == "both" || treatment == "recovery";
    const bool receptor = treatment == "receptor_only" || treatment == "both" || treatment == "recovery";
    if (treatment != "off" && treatment != "terminal_only" && treatment != "receptor_only" &&
        treatment != "both" && !recovery) throw std::invalid_argument("unknown treatment");
#if defined(GENTEK_SWARM005) || defined(GENTEK_SWARM006_RECOVERY)
    result.options.compact_native_termination = compact;
    result.options.supported_native_receptors = receptor;
#else
    if (compact || receptor) throw std::invalid_argument("SWARM005 treatment unavailable in frozen SWARM004");
#endif
#if defined(GENTEK_SWARM006_RECOVERY)
    result.options.negotiated_recovery = recovery;
#else
    if (recovery) throw std::invalid_argument("SWARM006 treatment unavailable in frozen source");
#endif
    auto at = delimiter;
    while (at != std::string::npos) {
        const auto next = name.find('+', at + 1);
        const auto diagnostic = name.substr(at + 1, next == std::string::npos ? next : next - at - 1);
        if (diagnostic == "fixed") result.options.shared_ownership = false;
        else if (diagnostic == "hard_only") result.options.optional_negotiation = false;
        else if (diagnostic == "frame_frozen") result.options.frame_adaptation = false;
        else if (diagnostic == "mosaic_frozen") result.options.mosaic_adaptation = false;
        else if (diagnostic == "no_offers") {
#if defined(GENTEK_SWARM006_RECOVERY)
            if (!recovery) throw std::invalid_argument("no_offers requires SWARM006 recovery");
            result.options.recovery_offers = false;
#else
            throw std::invalid_argument("recovery no-offer control unavailable in frozen source");
#endif
        }
        else if (diagnostic == "reverse") result.reverse = true;
        else if (diagnostic == "cancel") result.cancelled = true;
        else if (diagnostic == "frame_budget") result.frame_work = 1;
        else if (diagnostic == "mosaic_budget") result.mosaic_work = 1;
        else if (diagnostic == "solver_budget") result.solver_work = 1;
        else if (diagnostic == "memory_budget") result.memory = 1024;
        else throw std::invalid_argument("unknown diagnostic");
        at = next;
    }
    return result;
}
Profile selected_profile(const std::string& name) {
    if (name == "industrial_gui") {
        auto result = a::expression_profile("industrial");
        result.clutter = 0; // current panel default; native Industrial defaults to .35
        return result;
    }
    return name == "industrial" || name == "viaduct_like" || name == "irregular_megastructure"
        ? a::expression_profile(name) : profile(name);
}
a::Input make_input(const std::string& fixture_id, const Profile& profile_value, std::uint64_t seed,
                    const std::string& source, const Policy& policy) {
    a::Input input;
    const bool fixed = fixture_id == "fixed4099";
    int width = 0, height = 0;
    if (fixture_id == "owner_left_right_192x112") { width = 192; height = 112; }
    else if (fixture_id == "owner_left_right_128x128") { width = 128; height = 128; }
    else if (fixture_id == "maximum_left_right_256x128") { width = 256; height = 128; }
    else if (fixed) { width = 128; height = 96; }
    if (!width) input = a::input_for(fixture(fixture_id), profile_value, seed, source, policy.options);
    else {
        input.options = policy.options;
        input.frame.gentek = Kind::Frameweaver;
        input.mosaic.gentek = Kind::Mosaic;
        for (auto* request : {&input.frame, &input.mosaic}) {
            request->width = width; request->height = height; request->seed = seed;
            request->source_identity = source; request->fixture = "workbench_territory";
            request->definition_fingerprint = definition(request->gentek);
            request->profile = profile_value;
            request->activation.push_back({64, 48});
            const auto count = static_cast<std::size_t>(width * height);
            request->eligible.resize(count); request->protected_void.resize(count);
            request->context.assign(count, cybersand::Material::Empty);
            request->transition.resize(count);
        }
        input.mosaic.limits.max_instances = 192;
        if (fixed) input.frame.profile.clutter = input.mosaic.profile.clutter = 0;
        input.shared_zone.resize(static_cast<std::size_t>(width * height));
        for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
            const auto index = static_cast<std::size_t>(y * width + x);
            const bool inside = x >= 4 && x < width - 4 && y >= 4 && y < height - 4;
            const bool frame = fixed ? (x >= width / 4 && x < width - width / 4 &&
                y >= height / 4 && y < height - height / 4) : x < width / 2;
            input.frame.eligible[index] = static_cast<std::uint8_t>(inside && frame);
            input.mosaic.eligible[index] = static_cast<std::uint8_t>(inside && !frame);
        }
        // Exact L1 dilation of the admitted ownership boundary. The owner
        // left/right profile reduces to x=mid-14..mid+13, matching V3 masks.
        for (int y = 4; y < height - 4; ++y) for (int x = 4; x < width - 4; ++x) {
            const auto index = static_cast<std::size_t>(y * width + x);
            bool near = false;
            for (int dy = -14; dy <= 14 && !near; ++dy) for (int dx = -14; dx <= 14; ++dx) {
                if (std::abs(dx) + std::abs(dy) > 14) continue;
                const int xx = x + dx, yy = y + dy;
                if (xx < 4 || xx >= width - 4 || yy < 4 || yy >= height - 4) continue;
                const auto other = static_cast<std::size_t>(yy * width + xx);
                if (input.frame.eligible[index] != input.frame.eligible[other]) { near = true; break; }
            }
            const auto shared = static_cast<std::uint8_t>(near);
            input.frame.transition[index] = input.mosaic.transition[index] = shared;
            input.shared_zone[index] = shared;
        }
    }
    if (!policy.options.shared_ownership) std::fill(input.shared_zone.begin(), input.shared_zone.end(), 0);
    input.frame.limits.max_work = policy.frame_work;
    input.mosaic.limits.max_work = policy.mosaic_work;
    input.mosaic.limits.max_solver_work = policy.solver_work;
    input.frame.limits.max_bytes = input.mosaic.limits.max_bytes = policy.memory;
    return input;
}
bool usable(a::CompositionStatus value) {
    return value == a::CompositionStatus::Complete || value == a::CompositionStatus::Blocked;
}
std::optional<std::uint64_t> footprint(const Result& before, const Result& after, std::size_t count) {
    if (before.cells.size() != count || after.cells.size() != count) return std::nullopt;
    std::uint64_t changed{};
    for (std::size_t i = 0; i < count; ++i)
        changed += (before.cells[i] == cybersand::Material::Empty) != (after.cells[i] == cybersand::Material::Empty);
    return changed;
}
void optional_number(std::ostream& out, std::optional<std::uint64_t> value) {
    if (value) out << *value; else out << "null";
}
#if defined(GENTEK_SWARM006_RECOVERY)
void recovery_controls(const a::Composition& candidate, const std::filesystem::path& out, std::ostream& metadata) {
    auto no_offer_input = candidate.input;
    no_offer_input.cancel = nullptr;
    no_offer_input.options.recovery_offers = false;
    const auto no_offer = a::assemble(no_offer_input);
    a::write_composition_json((out / "no-offer-native.json").string(), no_offer);
    auto frozen_input = candidate.input;
    frozen_input.cancel = nullptr;
    frozen_input.options.mosaic_adaptation = false;
    const auto frozen = a::assemble(frozen_input);
    a::write_composition_json((out / "frozen-peer-native.json").string(), frozen);
    const auto& initial = candidate.rounds.front();
    const auto same_initial = [&](const a::Composition& other) {
        return !other.rounds.empty() && other.rounds.front().frame.result.cells == initial.frame.result.cells &&
            other.rounds.front().mosaic.result.cells == initial.mosaic.result.cells &&
            other.rounds.front().mosaic_request.eligible == initial.mosaic_request.eligible &&
            other.rounds.front().mosaic_request.protected_void == initial.mosaic_request.protected_void &&
            other.rounds.front().mosaic_request.context == initial.mosaic_request.context &&
            other.rounds.front().mosaic_request.neighbor_cells == initial.mosaic_request.neighbor_cells &&
            other.rounds.front().mosaic_request.limits.max_work == initial.mosaic_request.limits.max_work &&
            other.rounds.front().mosaic_request.limits.max_solver_work == initial.mosaic_request.limits.max_solver_work;
    };
    const bool no_offer_equal = same_initial(no_offer), frozen_equal = same_initial(frozen);
    bool peer_frozen = frozen_equal;
    for (const auto& round : frozen.rounds) peer_frozen = peer_frozen && round.mosaic.result.cells == initial.mosaic.result.cells;
    const auto count = static_cast<std::size_t>(candidate.input.frame.width * candidate.input.frame.height);
    std::optional<std::uint64_t> mosaic_effect, frame_effect;
    if (no_offer_equal && usable(no_offer.status))
        mosaic_effect = footprint(candidate.rounds.back().mosaic.result, no_offer.rounds.back().mosaic.result, count);
    if (frozen_equal && peer_frozen && usable(frozen.status))
        frame_effect = footprint(candidate.rounds.back().frame.result, frozen.rounds.back().frame.result, count);
    const bool causal = mosaic_effect && *mosaic_effect > 0 && frame_effect && *frame_effect > 0;
    metadata << ",\"method\":\"same initial native plans, masks, donor grants and aggregate limits; recovery_offers=false / mosaic_adaptation=false\""
        << ",\"available\":" << (mosaic_effect && frame_effect ? "true" : "false")
        << ",\"no_offer_initial_and_grants_equal\":" << (no_offer_equal ? "true" : "false")
        << ",\"frozen_peer_initial_and_grants_equal\":" << (frozen_equal ? "true" : "false")
        << ",\"peer_remained_frozen\":" << (peer_frozen ? "true" : "false")
        << ",\"no_offer_status\":"; quoted(metadata, a::name(no_offer.status));
    metadata << ",\"frozen_peer_status\":"; quoted(metadata, a::name(frozen.status));
    metadata << ",\"mosaic_offer_causal_footprint\":"; optional_number(metadata, mosaic_effect);
    metadata << ",\"frame_offer_causal_footprint\":"; optional_number(metadata, frame_effect);
    metadata << ",\"causal_both_with_joint\":" << (causal && !candidate.joints.empty() ? "true" : "false")
        << ",\"causal_complete\":" << (causal && !candidate.joints.empty() && candidate.can_apply ? "true" : "false") << "}\n";
}
#endif
void controls(const a::Composition& candidate, const std::filesystem::path& out) {
    std::ofstream metadata(out / "controls.json");
    if (!metadata) throw std::runtime_error("cannot write control metadata");
    metadata << "{\"schema\":1,\"scope\":\"independent native counterfactual executions; work excluded from candidate allowance\"";
    if (!usable(candidate.status) || candidate.rounds.size() < 2) {
        metadata << ",\"available\":false,\"reason\":\"candidate has no usable reciprocal round\"}\n";
        return;
    }
#if defined(GENTEK_SWARM006_RECOVERY)
    if (candidate.input.options.negotiated_recovery) {
        recovery_controls(candidate, out, metadata);
        if (!metadata) throw std::runtime_error("recovery control metadata write failed");
        return;
    }
#endif
    const auto& input = candidate.input;
    const auto& initial = candidate.rounds.front();
    const auto& revised = candidate.rounds[1];
    auto request = input.mosaic;
    request.profile.destruction = 0;
    if (request.protected_void.empty()) request.protected_void.assign(initial.frame.result.cells.size(), 0);
    for (std::size_t i = 0; i < request.protected_void.size(); ++i)
        request.protected_void[i] = static_cast<std::uint8_t>(request.protected_void[i] ||
            (!initial.frame.result.boundary.protected_geometry.empty() && initial.frame.result.boundary.protected_geometry[i]) ||
            (!initial.mosaic.result.boundary.protected_geometry.empty() && initial.mosaic.result.boundary.protected_geometry[i]));
    // Preserve the actual candidate donor grants, not merely their outer maxima.
    // Fewer offers avoid wrapper work; clamp before proposal preparation so
    // that avoided work cannot silently enlarge the no-offer donor allowance.
    request.limits.max_work = revised.mosaic_request.limits.max_work;
    request.limits.max_solver_work = revised.mosaic_request.limits.max_solver_work;
    a::MosaicBudget budget;
    budget.generator_remaining = input.mosaic.limits.max_work - initial.mosaic_work;
    budget.solver_remaining = input.mosaic.limits.max_solver_work - initial.solver_work;
    budget.max_bytes = input.mosaic.limits.max_bytes; budget.proposals_remaining = 4;
    const auto shared = input.options.shared_ownership ? input.shared_zone : std::vector<std::uint8_t>(request.eligible.size(), 0);
    const auto no_offer = a::propose_mosaic_revision(request, initial.frame.result, {}, shared, budget, 1,
        &initial.mosaic.result, &initial.mosaic.categories, input.options.optional_negotiation, input.options.native_mosaic_bearing
#if defined(GENTEK_SWARM005) || defined(GENTEK_SWARM006_RECOVERY)
        , input.options.supported_native_receptors
#endif
    );
    write_result_json((out / "no-offer-native.json").string(), no_offer.request, no_offer.plan.result);
    const bool masks_equal = no_offer.request.eligible == revised.mosaic_request.eligible &&
        no_offer.request.protected_void == revised.mosaic_request.protected_void &&
        no_offer.request.context == revised.mosaic_request.context &&
        no_offer.request.neighbor_cells == revised.mosaic_request.neighbor_cells &&
        no_offer.request.neighbors.protected_geometry == revised.mosaic_request.neighbors.protected_geometry;
    const bool grants_equal = no_offer.request.limits.max_work == revised.mosaic_request.limits.max_work &&
        no_offer.request.limits.max_solver_work == revised.mosaic_request.limits.max_solver_work;
    auto frozen_input = input; frozen_input.cancel = nullptr; frozen_input.options.mosaic_adaptation = false;
    const auto frozen = a::assemble(frozen_input);
    a::write_composition_json((out / "frozen-peer-native.json").string(), frozen);
    bool initial_equal = !frozen.rounds.empty() && frozen.rounds.front().frame.result.cells == initial.frame.result.cells &&
        frozen.rounds.front().mosaic.result.cells == initial.mosaic.result.cells;
    bool peer_frozen = initial_equal;
    for (const auto& round : frozen.rounds) peer_frozen = peer_frozen && round.mosaic.result.cells == initial.mosaic.result.cells;
    const auto count = static_cast<std::size_t>(input.frame.width * input.frame.height);
    std::optional<std::uint64_t> mosaic_effect, frame_effect;
    const bool no_offer_usable = no_offer.status == a::MosaicRevisionStatus::Complete || no_offer.status == a::MosaicRevisionStatus::Blocked;
    if (masks_equal && grants_equal && revised.mosaic_accepted && no_offer_usable)
        mosaic_effect = footprint(revised.mosaic.result, no_offer.plan.result, count);
    if (initial_equal && peer_frozen && usable(frozen.status))
        frame_effect = footprint(candidate.rounds.back().frame.result, frozen.rounds.back().frame.result, count);
    metadata << ",\"available\":" << (mosaic_effect && frame_effect ? "true" : "false")
        << ",\"masks_equal\":" << (masks_equal ? "true" : "false")
        << ",\"donor_grants_equal\":" << (grants_equal ? "true" : "false")
        << ",\"initial_pair_equal\":" << (initial_equal ? "true" : "false")
        << ",\"peer_remained_frozen\":" << (peer_frozen ? "true" : "false")
        << ",\"candidate_generator_grant\":" << revised.mosaic_request.limits.max_work
        << ",\"control_generator_grant\":" << no_offer.request.limits.max_work
        << ",\"candidate_solver_grant\":" << revised.mosaic_request.limits.max_solver_work
        << ",\"control_solver_grant\":" << no_offer.request.limits.max_solver_work
        << ",\"control_wrapper_work\":" << no_offer.wrapper_work
        << ",\"control_generator_work\":" << no_offer.generator_work
        << ",\"control_solver_debit\":" << no_offer.solver_debit
        << ",\"no_offer_status\":"; quoted(metadata, a::name(no_offer.status));
    metadata << ",\"frozen_peer_status\":"; quoted(metadata, a::name(frozen.status));
    metadata << ",\"mosaic_offer_causal_footprint\":"; optional_number(metadata, mosaic_effect);
    metadata << ",\"frame_offer_causal_footprint\":"; optional_number(metadata, frame_effect);
    const bool causal = mosaic_effect && *mosaic_effect > 0 && frame_effect && *frame_effect > 0;
    metadata << ",\"causal_both_with_joint\":" << (causal && !candidate.joints.empty() ? "true" : "false")
        << ",\"causal_complete\":" << (causal && !candidate.joints.empty() && candidate.can_apply ? "true" : "false") << "}\n";
    if (!metadata) throw std::runtime_error("control metadata write failed");
}
}

int main(int argc, char** argv) try {
    if (argc == 2 && std::string_view(argv[1]) == "describe") {
        std::cout << "{\"schema\":1,\"harness\":\"swarm006-comparison-v1\",\"variant\":\"" << variant() << "\"}\n";
        return 0;
    }
    if ((argc != 9 && argc != 10) || std::string_view(argv[1]) != "run")
        throw std::invalid_argument("usage: swarm006_experiment run OUT SOURCE FIXTURE PROFILE SEED POLICY ROUNDS [controls]");
    const auto rounds = number(argv[8]);
    if (rounds > 4) throw std::invalid_argument("round cap must be 0..4");
    if (argc == 10 && std::string_view(argv[9]) != "controls") throw std::invalid_argument("unknown command option");
    const std::string source = argv[3];
    if (source.empty() || source.size() > 128) throw std::invalid_argument("invalid source identity");
    const auto policy = policy_for(argv[7], static_cast<unsigned>(rounds));
    auto input = make_input(argv[4], selected_profile(argv[5]), number(argv[6]), source, policy);
    std::atomic_bool cancellation{policy.cancelled}; input.cancel = &cancellation;
    const std::filesystem::path out = argv[2];
    if (std::filesystem::exists(out) || !std::filesystem::create_directory(out))
        throw std::invalid_argument("refusing existing or unavailable execution directory");
    a::Composition declaration; declaration.input = input;
    declaration.reason = "request serialization only; native assemble has not run";
    a::write_composition_json((out / "request-envelope.json").string(), declaration);
    const auto result = a::assemble(input, policy.reverse);
    a::write_composition_json((out / "response-native.json").string(), result);
    if (argc == 10) controls(result, out);
    std::cout << "{\"schema\":1,\"variant\":\"" << variant() << "\",\"status\":";
    quoted(std::cout, a::name(result.status));
    std::cout << ",\"can_apply\":" << (result.can_apply ? "true" : "false") << ",\"joints\":" << result.joints.size() << "}\n";
    return result.status == a::CompositionStatus::Invalid ? 2 : 0;
} catch (const std::exception& error) {
    std::cerr << "SWARM006_EXPERIMENT: " << error.what() << '\n';
    return 1;
}
