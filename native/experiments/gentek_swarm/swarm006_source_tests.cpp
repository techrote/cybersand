// SWARM-006 source opportunity regressions. These do not claim full foreign
// closure: MOSAIC bidding, reciprocal revisions and final validation are separate.
#include "reciprocal.hpp"
#include <algorithm>
#include <functional>
#include <iostream>
#include <stdexcept>

using namespace cybersand::gentek_swarm;
using cybersand::Material;
namespace a = cybersand::gentek_swarm::assembly004;
namespace {
std::uint64_t assertions{};
void require(bool okay, const char* description) {
    ++assertions;
    if (!okay) throw std::runtime_error(description);
}
a::Input sample(const char* id, const char* style = "industrial") {
    return a::input_for(fixture(id), a::expression_profile(style), 605,
        "swarm006-source-opportunity-development");
}
std::uint64_t metric(const Result& r, const std::string& key) {
    const auto it = r.metrics.find(key);
    return it == r.metrics.end() ? 0 : it->second;
}
std::uint64_t rejected(const Result& r, const std::string& key) {
    const auto it = r.rejected.find(key);
    return it == r.rejected.end() ? 0 : it->second;
}
void valid_source(const a::Input& in, const FramePlan& plan) {
    const auto& r = plan.result;
    require(r.status != Status::Invalid, "valid source inputs were rejected as malformed");
    require(r.work <= in.frame.limits.max_work, "source work exceeded comparison allowance");
    require(r.candidates <= in.frame.limits.max_candidates, "source candidate allowance exceeded");
    require(metric(r, "conservative_memory_bound_bytes") <= in.frame.limits.max_bytes,
        "source memory admission exceeded comparison allowance");
    require(plan.source_feasibility.size() <= in.frame.limits.max_instances,
        "source receipts escaped finite native part count");
    require(r.protected_violations == 0 && r.illegal_overlaps == 0,
        "source opportunities wrote into protected or foreign material");
    for (const auto& proof : plan.source_feasibility) {
        require(proof.connector > 0 && proof.connector <= r.connectors.size(), "source receipt has no connector");
        const auto& connector = r.connectors[proof.connector - 1];
        require(connector.instance == proof.instance && connector.required,
            "source receipt lost its original required connector identity");
        require(proof.local_termination_possible != proof.foreign_opportunity,
            "source receipt conflated local termination and foreign opportunity");
        require(proof.work > 0, "source opportunity was not charged");
        if (proof.foreign_opportunity) {
            require(proof.receiver_categories != 0 && proof.backing ==
                Point{proof.contact.x + proof.facing.x, proof.contact.y + proof.facing.y},
                "foreign opportunity lacks a native category and exact backing");
            const auto dx = proof.contact.x - proof.face.x, dy = proof.contact.y - proof.face.y;
            require(dx * proof.facing.y == dy * proof.facing.x &&
                dx * proof.facing.x + dy * proof.facing.y > 0 &&
                std::abs(dx) + std::abs(dy) <= 14, "foreign opportunity is outside its facing span");
        }
    }
}
}

int main() {
    unsigned passed{}, failed{};
    const auto test = [&](const char* label, const std::function<void()>& run) {
        try { run(); ++passed; std::cout << "PASS " << label << '\n'; }
        catch (const std::exception& e) { ++failed; std::cerr << "FAIL " << label << ": " << e.what() << '\n'; }
    };
    test("disabled source policy preserves frozen native geometry, work and receipts", [] {
        auto in = sample("narrow_neck");
        for (const bool compact : {false, true}) {
            const auto frozen = plan_frameweaver(in.frame, in.mosaic, compact);
            const auto disabled = plan_frameweaver(in.frame, in.mosaic, compact, {false, &in.shared_zone});
            require(frozen.result.digest == disabled.result.digest && frozen.result.cells == disabled.result.cells &&
                frozen.result.provenance == disabled.result.provenance && frozen.result.work == disabled.result.work &&
                frozen.result.candidates == disabled.result.candidates && frozen.result.rejected == disabled.result.rejected &&
                frozen.result.metrics == disabled.result.metrics && frozen.result.status == disabled.result.status,
                "disabled opportunity policy changed a frozen native source");
            require(disabled.source_feasibility.empty(), "disabled policy emitted new source receipts");
        }
    });
    test("native receiver probe reuses authored closed category and rejects an empty interior", [] {
        MosaicSourceTile tile; tile.origin = {16, 16}; tile.admitted.fill(1);
        const auto face = probe_mosaic_source_receiver(tile, {16, 24}, {1, 0}, 1024);
        require(face.valid && !face.exhausted && face.work == 1024 && face.categories == (1U << 9U),
            "native west termination face was not recognized");
        const auto interior = probe_mosaic_source_receiver(tile, {23, 24}, {1, 0}, 1024);
        require(interior.valid && interior.categories == 0 && interior.work == 1024,
            "unbacked interior was mistaken for an authored native receiver");
        tile.admitted.fill(0); tile.admitted[8 * 16] = tile.admitted[8 * 16 + 1] = 1;
        const auto pair = probe_mosaic_source_receiver(tile, {16, 24}, {1, 0}, 1024);
        require(pair.valid && pair.categories == 0,
            "two empty territory cells were mistaken for a constructible native motif");
    });
    test("probe rejects corrupted geometry and refuses unfunded work", [] {
        MosaicSourceTile tile; tile.origin = {16, 16}; tile.admitted.fill(1);
        const auto unfunded = probe_mosaic_source_receiver(tile, {16, 24}, {1, 0}, 1023);
        require(unfunded.exhausted && !unfunded.valid && !unfunded.categories && unfunded.work == 0,
            "unfunded native category query escaped its work ceiling");
        require(!probe_mosaic_source_receiver(tile, {16, 24}, {1, 1}, 1024).valid,
            "non-cardinal source facing was accepted");
        tile.origin.x = 17;
        require(!probe_mosaic_source_receiver(tile, {17, 24}, {1, 0}, 1024).valid,
            "non-native tile alignment was accepted");
        tile.origin.x = 16; tile.admitted[3] = 2;
        require(!probe_mosaic_source_receiver(tile, {16, 24}, {1, 0}, 1024).valid,
            "non-binary hypothetical mask was accepted");
    });
    test("exact source terminals avoid infeasible original exits without claiming foreign joins", [] {
        const auto in = sample("narrow_neck");
        const auto baseline = plan_frameweaver(in.frame, in.mosaic, true);
        const auto candidate = plan_frameweaver(in.frame, in.mosaic, true, {true, &in.shared_zone});
        valid_source(in, candidate);
        require(baseline.result.unresolved_joints > 0 && candidate.result.unresolved_joints == 0,
            "source preflight failed to avoid the selected impossible exits");
        require(rejected(candidate.result, "swarm006_source_part_refused_before_freeze") > 0,
            "no real prospective structural alternative was refused");
        require(metric(candidate.result, "swarm006_source_foreign_opportunities") == 0,
            "local source repair was falsely reported as foreign closure");
        require(candidate.result.instances.size() > 20 && metric(candidate.result, "accepted_diagonal_brace") > 0,
            "source repair collapsed the architecture into a generic trivial shape");
    });
    test("plausible native foreign exits survive unchanged for reciprocal negotiation", [] {
        const auto in = sample("island", "irregular_megastructure");
        const auto baseline = plan_frameweaver(in.frame, in.mosaic, true);
        const auto candidate = plan_frameweaver(in.frame, in.mosaic, true, {true, &in.shared_zone});
        valid_source(in, candidate);
        require(baseline.result.cells == candidate.result.cells && baseline.result.unresolved_joints == 2 &&
            candidate.result.unresolved_joints == 2 && candidate.result.status == Status::Blocked,
            "real original foreign requirements were retrospectively removed or fulfilled");
        require(metric(candidate.result, "swarm006_source_foreign_opportunities") == 2,
            "native source did not retain the two qualified category opportunities");
        const auto again = plan_frameweaver(in.frame, in.mosaic, true, {true, &in.shared_zone});
        require(candidate.result.digest == again.result.digest && candidate.result.work == again.result.work &&
            candidate.result.candidates == again.result.candidates &&
            candidate.source_feasibility.size() == again.source_feasibility.size(),
            "source candidate ordering or charged accounting is nondeterministic");
    });
    test("protected corridors and occupied context remain immutable", [] {
        for (const auto id : {"protected_corridor", "foreign_solid"}) {
            const auto in = sample(id);
            const auto candidate = plan_frameweaver(in.frame, in.mosaic, true, {true, &in.shared_zone});
            valid_source(in, candidate);
            require(candidate.result.status != Status::Exhausted, "development source exceeded equal work envelope");
            for (std::size_t i = 0; i < candidate.result.cells.size(); ++i)
                if (in.frame.protected_void[i] || in.frame.context[i] != Material::Empty)
                    require(candidate.result.cells[i] == Material::Empty, "source wrote a protected/context cell");
        }
    });
    test("resource exhaustion and malformed shared masks fail closed", [] {
        auto in = sample("island");
        in.frame.limits.max_work = 100;
        const auto exhausted = plan_frameweaver(in.frame, in.mosaic, true, {true, &in.shared_zone});
        require(exhausted.result.status == Status::Exhausted && exhausted.result.work <= 100 &&
            exhausted.slots.empty(), "unfunded source published a complete reservation plan");
        in = sample("island"); in.shared_zone.resize(1);
        const auto malformed = plan_frameweaver(in.frame, in.mosaic, true, {true, &in.shared_zone});
        require(malformed.result.status == Status::Invalid && malformed.source_feasibility.empty(),
            "malformed shared mask gained native source authority");
        in = sample("island"); in.frame.limits.max_work = 2'000'001;
        require(plan_frameweaver(in.frame, in.mosaic, true, {true, &in.shared_zone}).result.status == Status::Invalid,
            "source policy silently increased the comparison work envelope");
    });
    test("maximum native dimensions with adversarial obstacles retain finite allowances", [] {
        Fixture f;
        f.id = "swarm006-source-adversarial-development"; f.width = 256; f.height = 128;
        const auto count = static_cast<std::size_t>(f.width * f.height);
        f.side.resize(count); f.transition.resize(count); f.protected_void.resize(count);
        f.context.assign(count, Material::Empty);
        for (int y = 0; y < f.height; ++y) for (int x = 0; x < f.width; ++x) {
            const auto i = static_cast<std::size_t>(y * f.width + x);
            f.side[i] = x < 128 ? 0 : 1;
            f.transition[i] = x >= 114 && x <= 141;
            f.protected_void[i] = (x % 19 == 0 && y % 7 < 4) || (y == 96 && x > 80 && x < 180);
            if (x % 31 == 0 && y > 20 && y < 88) f.context[i] = Material::LimestoneBlock;
        }
        auto in = a::input_for(f, a::expression_profile("irregular_megastructure"), 605,
            "swarm006-max-source-development");
        const auto candidate = plan_frameweaver(in.frame, in.mosaic, true, {true, &in.shared_zone});
        valid_source(in, candidate);
        in.frame.limits.max_candidates = 32;
        const auto exhausted = plan_frameweaver(in.frame, in.mosaic, true, {true, &in.shared_zone});
        require(exhausted.result.status == Status::Exhausted && exhausted.result.candidates <= 32 &&
            exhausted.result.work <= in.frame.limits.max_work && exhausted.slots.empty(),
            "maximum-size candidate exhaustion published a partial accepted plan");
    });
    std::cout << "SWARM006_SOURCE_OPPORTUNITIES: " << (failed ? "FAIL" : "PASS") << " tests=" << passed << '/'
              << passed + failed << " assertions=" << assertions << '\n';
    return failed ? 1 : 0;
}
