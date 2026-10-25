#pragma once

#include "cybersand/demo_snapshot.hpp"
#include "cybersand/water_normalization.hpp"

namespace godot::prepared_liquid_detail {

// Decode the existing finite CYSD1 cell payload, never a live World. The host
// retains its outer level metadata separately. No new native codec is needed:
// the authored payload binds a NativeCellFixture with payload-only coverage.
inline cybersand::normalization::FinalSetupInput level_setup(
    std::span<const std::uint8_t> bytes, const cybersand::WorldConfig& config,
    std::uint64_t seed) {
    cybersand::demo::validate(bytes);
    cybersand::normalization::FinalSetupInput input;
    input.mass_bits = config.water_experiment_policy.mass_bits();
    input.ambient_temperature = config.ambient_temperature;
    input.setup.seed = seed;
    input.setup.domain = {0, 0, cybersand::demo::kWidth, cybersand::demo::kHeight};
    input.setup.definition_digest = cybersand::Sha256::of(bytes);
    // NativePayloadOnly retains all non-cell/host gaps, including the outer
    // level metadata, actor/loadout, plane clocks and subsequent user inputs.
    const auto temperature_at = [&](std::size_t offset) {
        const auto value = static_cast<std::uint16_t>(bytes[offset + 3] |
            (std::uint16_t{bytes[offset + 4]} << 8U));
        return static_cast<std::int16_t>(value <= 32767U
            ? static_cast<std::int32_t>(value) : static_cast<std::int32_t>(value) - 65536);
    };
    std::size_t count = 0;
    for (std::size_t offset = 0; offset < bytes.size(); offset += cybersand::demo::kCellBytes) {
        if (bytes[offset] == static_cast<std::uint8_t>(cybersand::Material::Empty) &&
            (bytes[offset + 1] != 0 || bytes[offset + 2] != 0))
            throw std::invalid_argument("Prepared CYSD1 Empty state lanes must be zero");
        if (bytes[offset] == static_cast<std::uint8_t>(cybersand::Material::Water) &&
            (bytes[offset + 1] > config.water_experiment_policy.maximum() ||
             bytes[offset + 2] > config.water_experiment_policy.coherence_ticks()))
            throw std::invalid_argument("Prepared CYSD1 Water state outside the selected experiment policy");
        if ((bytes[offset] != static_cast<std::uint8_t>(cybersand::Material::Empty) &&
             !(bytes[offset] == static_cast<std::uint8_t>(cybersand::Material::Water) && bytes[offset + 1] == 0)) ||
            temperature_at(offset) != config.ambient_temperature) ++count;
    }
    input.cells.reserve(count); // Exact bounded construction allocation, not tick work.
    for (std::size_t offset = 0; offset < bytes.size(); offset += cybersand::demo::kCellBytes) {
        auto material = static_cast<cybersand::Material>(bytes[offset]);
        auto a = static_cast<std::uint16_t>(bytes[offset + 1]);
        auto b = bytes[offset + 2];
        // Existing CYSD reconstruction maps zero-quantity Water to Empty.
        // Validate its original lanes first, then preserve the thermal field.
        if (material == cybersand::Material::Water && a == 0) {
            material = cybersand::Material::Empty; a = 0; b = 0;
        }
        const auto temperature = temperature_at(offset);
        if (material == cybersand::Material::Empty && temperature == config.ambient_temperature) continue;
        const auto cell = offset / cybersand::demo::kCellBytes;
        input.cells.push_back({static_cast<std::int64_t>(cell % cybersand::demo::kWidth),
            static_cast<std::int64_t>(cell / cybersand::demo::kWidth), material, a, b, temperature});
    }
    return input;
}

} // namespace godot::prepared_liquid_detail
