#pragma once

#include "cybersand/liquid_run_receipt_native_capture.hpp"
#include "cybersand/quantity_ledger.hpp"
#include "cybersand/liquid_construction_refusal.hpp"
#include "cybersand/pressure_setup_capacity.hpp"

#include <limits>
#include <new>
#include <variant>

namespace cybersand {

// Native setup tuples are already resolved: one final tuple at each coordinate.
// A registered-definition claim stays host-unverified until #202 proves its
// compilation. This value does not expose live cells or convert a running World.
class PreparedWorld final {
public:
    const normalization::PreparedSetup& setup() const noexcept { return setup_; }
    const World& world() const noexcept { return *world_; }
    std::unique_ptr<World> take_world() noexcept { return std::move(world_); }
private:
    friend class PreparedWorldBuilder;
    PreparedWorld(std::unique_ptr<World> world, normalization::PreparedSetup setup)
        : world_(std::move(world)), setup_(std::move(setup)) {}
    std::unique_ptr<World> world_;
    normalization::PreparedSetup setup_;
};

class PreparedWorldBuilder final {
public:
    using Result = std::variant<PreparedWorld, ConstructionRefusal>;
    // Call only for a fresh finite prepared World whose complete payload and
    // initial masks lie in domain. The actual candidate is inspected after mask
    // rasterization; no caller-supplied count or refusal reason is accepted.
    static std::optional<ConstructionRefusal> validate_initial_pressure_capacity(
        const World& candidate, const setup::SetupDomain& domain) {
        const auto refused = [&](LiquidPolicyRefusalCode code, std::string detail) {
            return ConstructionRefusal::for_setup(candidate.liquid_solver_policy(),
                {code, static_cast<std::uint16_t>(Material::Water), std::move(detail)});
        };
        try {
            if (initial_pressure_capacity(candidate, domain).exceeds_capacity())
                return refused(LiquidPolicyRefusalCode::CapacityRefused,
                    "initial pressure gas compartment capacity exceeds 1024");
            return std::nullopt;
        } catch (const std::bad_alloc&) {
            return refused(LiquidPolicyRefusalCode::CapacityRefused, "initial pressure capacity allocation refused");
        } catch (const std::length_error& rejected) {
            return refused(LiquidPolicyRefusalCode::CapacityRefused, rejected.what());
        } catch (const std::invalid_argument& rejected) {
            return refused(LiquidPolicyRefusalCode::MalformedPolicy, rejected.what());
        }
    }
    static Result prepare(const WorldConfig& requested_config, const normalization::FinalSetupInput& input,
                          normalization::NormalizationOptIn opt_in,
                          normalization::PreparationLimits limits = {}) {
        const auto refused = [&](LiquidPolicyRefusalCode code, std::string detail) {
            return ConstructionRefusal::for_setup(requested_config.liquid_solver_policy,
                {code, std::uint16_t{3}, std::move(detail)});
        };
        // Apply policy admission before allocation or setup-dependent refusals.
        if (auto refusal = requested_config.liquid_solver_policy.admission_refusal())
            return ConstructionRefusal::for_setup(requested_config.liquid_solver_policy, std::move(*refusal));
        try {
            WorldConfig config = requested_config;
            config.water_experiment_policy.validate();
            if (config.backend != SimulationBackend::SerialInPlace &&
                config.backend != SimulationBackend::PhasedInPlace)
                return refused(LiquidPolicyRefusalCode::MalformedPolicy, "setup requires an implemented native backend");
            if (config.water_experiment_policy.mass_bits() != input.mass_bits ||
                config.ambient_temperature != input.ambient_temperature)
                return refused(LiquidPolicyRefusalCode::MalformedPolicy,
                              "setup precision/ambient does not match the requested World");
            if (input.cells.size() > std::min(limits.maximum_cells, normalization::kMaximumSetupCells))
                return refused(LiquidPolicyRefusalCode::CapacityRefused, "prepared tuple budget exceeded");
            // Rounding changes only quantity. Validate the original resolved
            // Water tuples before a down-round could erase an invalid lane.
            for (const auto& cell : input.cells)
                if (cell.material == Material::Water &&
                    cell.state_b > config.water_experiment_policy.coherence_ticks())
                    return refused(LiquidPolicyRefusalCode::MalformedPolicy,
                                  "setup Water coherence exceeds the requested World policy");
            const auto water = config.liquid_solver_policy.assignment(static_cast<std::uint16_t>(Material::Water));
            const bool whole = water && (water->family == LiquidSolverFamily::CellularYieldV1 ||
                                         water->family == LiquidSolverFamily::InertialCellularV1);
            auto value = normalization::PreparedSetup::prepare(input,
                whole ? normalization::WaterQuantityRegime::WholeCell : normalization::WaterQuantityRegime::Fractional,
                opt_in, limits);
            if (const auto* rejected = std::get_if<normalization::Refusal>(&value)) {
                auto code = LiquidPolicyRefusalCode::MalformedPolicy;
                switch (rejected->code) {
                    case normalization::RefusalCode::MalformedPolicy: break;
                    case normalization::RefusalCode::UnknownParameter: code = LiquidPolicyRefusalCode::UnknownParameter; break;
                    case normalization::RefusalCode::CapacityRefused: code = LiquidPolicyRefusalCode::CapacityRefused; break;
                    case normalization::RefusalCode::NormalizationRequired: code = LiquidPolicyRefusalCode::NormalizationRequired; break;
                }
                return ConstructionRefusal::for_setup(requested_config.liquid_solver_policy,
                    {code, rejected->material, rejected->detail});
            }
            auto prepared = std::get<normalization::PreparedSetup>(std::move(value));
            for (const auto& cell : prepared.final_cells())
                if (cell.material == Material::Water && cell.state_b > config.water_experiment_policy.coherence_ticks())
                    return refused(LiquidPolicyRefusalCode::MalformedPolicy,
                                  "setup Water coherence exceeds the requested World policy");

            // Constructor and all tuple/thermal writes affect an unexposed new
            // candidate. Every refusal discards it, leaving the caller's World,
            // applied receipt and session generation untouched.
            auto candidate = std::make_unique<World>(std::move(config));
            const auto& domain = prepared.domain();
            const auto halo = static_cast<std::int64_t>(std::max(candidate->config().chunk_size,
                                                               candidate->config().maximum_rule_radius));
            const auto minimum = std::numeric_limits<std::int64_t>::min();
            const auto maximum = std::numeric_limits<std::int64_t>::max();
            const auto last_x = domain.x + static_cast<std::int64_t>(domain.width - 1U);
            const auto last_y = domain.y + static_cast<std::int64_t>(domain.height - 1U);
            if (domain.x < minimum + halo || domain.y < minimum + halo ||
                last_x > maximum - halo || last_y > maximum - halo)
                return refused(LiquidPolicyRefusalCode::CapacityRefused, "setup halo exceeds native coordinate range");
            const RectI64 reservation{domain.x - halo, domain.y - halo,
                static_cast<std::int64_t>(domain.width) + 2 * halo,
                static_cast<std::int64_t>(domain.height) + 2 * halo};
            try {
                candidate->reserve_temperature_region(reservation);
            } catch (const std::runtime_error& capacity) {
                return refused(LiquidPolicyRefusalCode::CapacityRefused, capacity.what());
            }
            for (const auto& cell : prepared.final_cells()) {
                if (cell.material != Material::Empty &&
                    !candidate->set_cell_state(cell.x, cell.y, cell.material, cell.state_a, cell.state_b))
                    throw std::logic_error("validated prepared tuple was not installed");
                candidate->set_temperature(cell.x, cell.y, cell.temperature);
            }
            const auto actual = receipt::capture_native_facts(*candidate, prepared.setup_descriptor());
            if (actual.values().prepared_native_payload != prepared.native_payload_hash())
                throw std::logic_error("prepared World does not match the immutable final setup payload");
            const auto quantity = candidate->water_quantity({domain.x, domain.y, domain.width, domain.height});
            QuantityConstructionSeed seed;
            seed.mass_bits = prepared.mass_bits();
            seed.baseline_water = seed.expected_final_water = quantity;
            seed.original_setup_identity = seed.prepared_setup_identity = prepared.setup_hash();
            seed.original_payload_digest = seed.prepared_payload_digest = prepared.native_payload_hash();
            if (const auto& receipt = prepared.normalization_receipt()) {
                if (receipt->totals().water_after != quantity)
                    throw std::logic_error("normalization quantity does not match the actual prepared World");
                seed.baseline_water = receipt->totals().water_before;
                seed.normalization_produced = receipt->totals().positive_delta;
                seed.normalization_consumed = receipt->totals().negative_delta;
                seed.original_setup_identity = receipt->setup_before_hash();
                seed.original_payload_digest = receipt->payload_before_hash();
                seed.normalization_receipt_digest = receipt->receipt_hash();
            }
            candidate->initialize_quantity_ledger(seed);
            return PreparedWorld(std::move(candidate), std::move(prepared));
        } catch (const LiquidPolicyRefused& rejected) {
            return ConstructionRefusal::for_setup(requested_config.liquid_solver_policy, rejected.refusal());
        } catch (const std::bad_alloc&) {
            return refused(LiquidPolicyRefusalCode::CapacityRefused, "prepared World allocation refused");
        } catch (const std::length_error& rejected) {
            return refused(LiquidPolicyRefusalCode::CapacityRefused, rejected.what());
        } catch (const std::invalid_argument& rejected) {
            return refused(LiquidPolicyRefusalCode::MalformedPolicy, rejected.what());
        } catch (const std::logic_error& failed) {
            return ConstructionRefusal::for_native_failure(requested_config.liquid_solver_policy, failed.what());
        } catch (const std::runtime_error& failed) {
            return ConstructionRefusal::for_native_failure(requested_config.liquid_solver_policy, failed.what());
        }
    }
};
} // namespace cybersand
