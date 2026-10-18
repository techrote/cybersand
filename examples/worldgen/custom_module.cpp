#include "cybersand/world_generation.hpp"

#include <cmath>
#include <iostream>
#include <stdexcept>

// Compile with native/src/world_generation.cpp; no Godot or World instance.
// This is a native host registration example, not runtime-loaded binary code.
namespace gen = cybersand::generation;
using cybersand::Material;

class ServiceRibs final : public gen::FeatureSampler {
    cybersand::RectI64 bounds_;
    std::int64_t pitch_;
public:
    ServiceRibs(cybersand::RectI64 bounds, std::int64_t pitch) : bounds_(bounds), pitch_(pitch) {}
    std::optional<Material> sample(const gen::ModuleContext& context, Material previous) const override {
        const auto x = context.x - bounds_.x, y = context.y - bounds_.y;
        if (y % pitch_ == 0 && x % pitch_ < pitch_ - 5) return Material::SteelGrating;
        if (x % pitch_ == 0 && previous != Material::Empty) return Material::CopperPipe;
        return std::nullopt;
    }
};

int main() {
    auto registry = gen::ModuleRegistry::builtins();
    registry.add({"service_ribs", 1, 12, [](const gen::ModuleInstance& instance, std::uint64_t) {
        if (instance.parameters.size() > 1 ||
            (!instance.parameters.empty() && !instance.parameters.contains("pitch")))
            throw std::invalid_argument("service_ribs accepts only pitch");
        const auto pitch = instance.parameters.contains("pitch") ? instance.parameters.at("pitch") : 24.0;
        if (!std::isfinite(pitch) || std::floor(pitch) != pitch || pitch < 12 || pitch > 128)
            throw std::invalid_argument("service_ribs pitch must be an integer in 12..128");
        return std::make_shared<ServiceRibs>(instance.bounds, static_cast<std::int64_t>(pitch));
    }});
    gen::Recipe recipe;
    recipe.candidate = gen::Candidate::DistrictGrammar;
    recipe.themes.weights = {{"industrial", 1}};
    recipe.modules.push_back({"ribs", "service_ribs", 1, {-256, -256, 512, 512}, {{"pitch", 24}}, {}, 0});
    const auto generator = gen::Generator::compile(recipe, registry);
    const auto result = generator->generate({0, 0});
    if (!generator->accepts(result)) throw std::runtime_error("custom module failed: " + result.error);
    std::cout << "service_ribs material proposal: " << result.cells.size()
              << " cells, receipt " << std::hex << result.receipt_hash << '\n';
}
