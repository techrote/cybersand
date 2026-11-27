// Additive integration replay of the already revealed #698 matrix. This is an
// external qualification driver, never a new policy or a Workbench transport.
#include "reciprocal_io.hpp"

#include <algorithm>
#include <charconv>
#include <iostream>
#include <stdexcept>
#include <string>

using namespace cybersand::gentek_swarm;
namespace a = cybersand::gentek_swarm::assembly004;

int main(int argc, char** argv) try {
    if (argc != 6) throw std::invalid_argument("expected FIXTURE PROFILE SEED POLICY OUTPUT");
    const std::string policy = argv[4], seed_text = argv[3];
    std::uint64_t seed{};
    const auto parsed = std::from_chars(seed_text.data(), seed_text.data() + seed_text.size(), seed);
    if (parsed.ec != std::errc{} || parsed.ptr != seed_text.data() + seed_text.size())
        throw std::invalid_argument("invalid seed");
    a::Options options;
    if (policy == "off_off") {}
    else if (policy == "compact_only") options.compact_native_termination = true;
    else if (policy == "receptor_only") options.supported_native_receptors = true;
    else {
        options.compact_native_termination = options.supported_native_receptors = true;
        if (policy == "both") {}
        else if (policy == "both_round1") options.rounds = 1;
        else if (policy == "both_round0") options.rounds = 0;
        else if (policy == "both_frame_frozen") options.frame_adaptation = false;
        else if (policy == "both_mosaic_frozen") options.mosaic_adaptation = false;
        else if (policy == "both_hard_only") options.optional_negotiation = false;
        else if (policy == "both_fixed_territory") options.shared_ownership = false;
        else throw std::invalid_argument("unknown registered policy");
    }
    // Preserve the original input identity. The new source, driver and executed
    // binary are independently bound by replay_known_controls.py's manifest.
    const auto input = a::input_for(fixture(argv[1]), a::expression_profile(argv[2]), seed,
                                    "swarm005-unseen-holdout-v1", options);
    const auto c = a::assemble(input);
    a::write_composition_json(argv[5], c);
    const bool evaluated = c.metrics.contains("still_required");
    const bool complete = c.status == a::CompositionStatus::Complete && evaluated &&
        c.metrics.at("still_required") == 0;
    if (c.can_apply != complete || (c.can_apply && std::any_of(c.obligations.begin(), c.obligations.end(),
            [](const auto& obligation) { return obligation.state == "STILL_REQUIRED"; })))
        throw std::runtime_error("invalid Apply invariant; full output retained");
    if (c.status == a::CompositionStatus::Invalid)
        throw std::runtime_error("invalid composition; full output retained");
    std::cout << a::name(c.status) << " apply=" << c.can_apply << '\n';
    return 0;
} catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 2;
}
