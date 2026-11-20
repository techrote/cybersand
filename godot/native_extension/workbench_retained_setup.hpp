#pragma once

#include "cybersand/water_normalization.hpp"
#include "cybersand/world.hpp"
#include "cybersand/workbench_authoring_patch.hpp"

#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

#include <array>

namespace godot::prepared_liquid_detail {

inline bool workbench_same_authoring_physics(const cybersand::WorldConfig& source,
                                             const cybersand::WorldConfig& target) {
    const auto& before = source.transport_policy;
    const auto& after = target.transport_policy;
    const bool same_pairs = std::equal(before.pairs.begin(), before.pairs.end(), after.pairs.begin(),
        [](const cybersand::TransportPair& a, const cybersand::TransportPair& b) {
            return a.mixing == b.mixing && a.carrying == b.carrying && a.pickup == b.pickup &&
                a.packing == b.packing && a.erosion == b.erosion && a.permeability == b.permeability;
        });
    // Preparation copies WorldConfig before applying the explicit options below.
    // Compare those configurable lanes, never object padding or raw struct bytes.
    return source.worker_threads == target.worker_threads &&
        source.pressure_gas_compartment_capacity == target.pressure_gas_compartment_capacity &&
        source.workbench_parallel_pressure_heads == target.workbench_parallel_pressure_heads &&
        source.maximum_chunk_count == target.maximum_chunk_count &&
        source.active_chunk_capacity == target.active_chunk_capacity &&
        source.active_core_capacity == target.active_core_capacity &&
        source.scheduling_core_size == target.scheduling_core_size &&
        source.maximum_rule_radius == target.maximum_rule_radius &&
        source.water_experiment_policy == target.water_experiment_policy &&
        source.ballistic_water == target.ballistic_water && source.wave_flow == target.wave_flow &&
        source.inertial_signed_vertical == target.inertial_signed_vertical &&
        before.configured == after.configured && before.horizontal == after.horizontal &&
        before.cadence == after.cadence && same_pairs;
}

// Called by the exclusive desktop owner during preparation only. Stored lanes
// ignore transient Rapier masks. The normal prepared builder validates or
// explicitly normalizes these quantities against the requested target policy.
inline void workbench_copy_retained_cells(const cybersand::World& source,
                                          cybersand::normalization::FinalSetupInput& input) {
    const auto& domain = input.setup.domain;
    if (domain.x != 0 || domain.y != 0 || domain.width > 2048 || domain.height > 2048 ||
        input.mass_bits != source.config().water_experiment_policy.mass_bits() ||
        input.ambient_temperature != source.config().ambient_temperature)
        throw std::invalid_argument("Incompatible retained workbench extent, Water precision or ambient temperature");

    input.cells.clear();
    input.setup.kind = cybersand::setup::SetupKind::NativeCellFixture;
    input.setup.coverage = cybersand::setup::SetupCoverage::NativePayloadOnly;
    input.setup.definition_digest.reset();
    input.setup.definition_schema = 1;
    for (std::int64_t y = 0; y < domain.height; ++y) {
        for (std::int64_t x = 0; x < domain.width; ++x) {
            const auto material = source.stored_material(x, y);
            const auto temperature = source.stored_temperature(x, y);
            if (material == cybersand::Material::Empty && temperature == input.ambient_temperature) continue;
            input.cells.push_back({x, y, material, source.stored_state_a(x, y),
                                   source.stored_state_b(x, y), temperature});
        }
    }
    // The builder authenticates this finite starting-setup payload. The
    // workbench then transfers live exterior inventory into the actual reserved
    // chunks of the new owner and accounts for anything beyond those chunks.
}

// Exact-value adapter for the experimental authoring patch. Caller has exclusive
// ownership and has already chosen the existing retained preparation path. The
// generator/round ledger stays in the composition document; this receipt binds
// its claimed proposal to the exact material patch that native preparation used.
inline Dictionary workbench_stage_authoring_patch(const cybersand::World& source,
    cybersand::normalization::FinalSetupInput& input, const Dictionary& request,
    Vector2i extent, std::uint64_t generation, std::uint64_t revision) {
    using namespace cybersand::workbench_authoring;
    constexpr std::array<const char*, 10> fields{"schema", "operation", "native_generation", "revision",
        "tick", "extent", "cells", "before", "protected", "proposal_sha256"};
    if (request.size() != static_cast<std::int64_t>(fields.size()))
        throw std::invalid_argument("Authoring patch has unknown or missing fields");
    for (const auto field : fields)
        if (!request.has(field)) throw std::invalid_argument("Authoring patch is incomplete");
    for (const auto field : {"schema", "native_generation", "revision", "tick"})
        if (request[field].get_type() != Variant::INT || static_cast<std::int64_t>(request[field]) < 0)
            throw std::invalid_argument("Authoring patch requires exact nonnegative source integers");
    if (static_cast<std::int64_t>(request["schema"]) != 1 ||
        request["operation"].get_type() != Variant::STRING ||
        request["extent"].get_type() != Variant::VECTOR2I ||
        request["cells"].get_type() != Variant::PACKED_INT32_ARRAY ||
        request["before"].get_type() != Variant::PACKED_INT32_ARRAY ||
        request["protected"].get_type() != Variant::PACKED_INT32_ARRAY ||
        request["proposal_sha256"].get_type() != Variant::STRING)
        throw std::invalid_argument("Authoring patch has invalid schema or value types");
    const String operation = request["operation"];
    const String proposal = request["proposal_sha256"];
    if (operation != "build" && operation != "remove")
        throw std::invalid_argument("Authoring patch operation must be build or remove");
    if (proposal.length() != 64) throw std::invalid_argument("Authoring proposal SHA256 is malformed");
    for (std::int64_t i = 0; i < proposal.length(); ++i) {
        const auto c = proposal[i];
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')))
            throw std::invalid_argument("Authoring proposal SHA256 is malformed");
    }
    if (static_cast<Vector2i>(request["extent"]) != extent ||
        static_cast<std::uint64_t>(static_cast<std::int64_t>(request["native_generation"])) != generation ||
        static_cast<std::uint64_t>(static_cast<std::int64_t>(request["revision"])) != revision ||
        static_cast<std::uint64_t>(static_cast<std::int64_t>(request["tick"])) != source.completed_tick_index())
        throw std::invalid_argument("Authoring preview belongs to a stale native source");
    const PackedInt32Array values = request["cells"], before = request["before"], guards = request["protected"];
    if (values.is_empty() || values.size() % 3 != 0 ||
        values.size() / 3 > static_cast<std::int64_t>(kMaximumPatchCells) ||
        before.size() != values.size() / 3 || guards.size() % 2 != 0 ||
        guards.size() / 2 > static_cast<std::int64_t>(kMaximumPatchCells))
        throw std::invalid_argument("Authoring patch payload exceeds its exact-cell capacity");
    std::vector<Cell> cells;
    cells.reserve(static_cast<std::size_t>(before.size()));
    for (std::int64_t i = 0; i < before.size(); ++i) {
        const auto target = values[i * 3 + 2], original = before[i];
        if (target < 0 || target > 255 || original < 0 || original > 255)
            throw std::invalid_argument("Authoring patch material cannot be narrowed to a native ID");
        cells.push_back({{values[i * 3], values[i * 3 + 1]},
            static_cast<cybersand::Material>(original), static_cast<cybersand::Material>(target)});
    }
    std::vector<Point> protected_cells;
    protected_cells.reserve(static_cast<std::size_t>(guards.size() / 2));
    for (std::int64_t i = 0; i < guards.size(); i += 2)
        protected_cells.push_back({guards[i], guards[i + 1]});
    const auto result = stage(source, input, cells, protected_cells,
        operation == "build" ? Operation::Build : Operation::Remove);
    Dictionary receipt;
    receipt["schema"] = 1;
    receipt["operation"] = operation;
    receipt["proposal_sha256"] = proposal;
    receipt["patch_sha256"] = String(cybersand::Sha256::hex(result.digest).c_str());
    receipt["changed_cells"] = static_cast<std::int64_t>(result.changed);
    receipt["protected_cells"] = guards.size() / 2;
    receipt["source_native_generation"] = static_cast<std::int64_t>(generation);
    receipt["source_revision"] = static_cast<std::int64_t>(revision);
    receipt["source_tick"] = request["tick"];
    receipt["semantics"] = "retained-native-transaction-v1";
    return receipt;
}

} // namespace godot::prepared_liquid_detail
