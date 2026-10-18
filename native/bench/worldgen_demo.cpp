#include "cybersand/world_generation.hpp"

#include <charconv>
#include <chrono>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

// Native, exact-material preview. This is generation evidence, not a rendered
// Godot screenshot or simulation/physics/performance qualification.
namespace {
using namespace cybersand;
using namespace cybersand::generation;

Recipe example(Candidate candidate, std::uint64_t seed) {
    Recipe recipe;
    recipe.seed = seed;
    recipe.candidate = candidate;
    recipe.themes.weights = {{"natural", 2.0}, {"built", 1.0}};
    recipe.themes.exclude = {"basalt"};
    recipe.parameters.surface_y = 40;
    recipe.parameters.fluid_level = 300;
    recipe.parameters.cave_threshold = 0.57;
    recipe.parameters.district_size = 192;
    BrushStroke brush;
    brush.id = "garden-transition";
    brush.points = {{-220, 100}, {-64, 240}, {240, 330}};
    brush.radius = 96;
    brush.strength = 0.85;
    brush.themes.weights = {{"garden", 1.0}};
    brush.parameters = {{Parameter::Relief, 24}, {Parameter::CaveThreshold, 0.50}};
    recipe.strokes.push_back(brush);
    recipe.paths.push_back({"main-passage", {{-256, 240}, {-32, 220}, {150, 200}, {256, 236}}, 9, Material::Empty, 1});
    recipe.modules.push_back({"service-tower", "arcology", 1, {-208, 72, 144, 192}, {}, {}, 0});
    recipe.modules.push_back({"vault-complex", "vault", 1, {48, 256, 192, 128}, {}, {}, 0});
    recipe.modules.push_back({"water-crossing", "aqueduct", 1, {-48, 96, 288, 96}, {}, {}, 0});
    HardOverride override;
    override.id = "fixed-bulkhead";
    override.bounds = {-240, 290, 12, 64};
    override.material = Material::SteelPlate;
    override.priority = 100;
    recipe.overrides.push_back(override);
    return recipe;
}

std::uint64_t seed_value(const std::string& text) {
    std::uint64_t value{};
    const auto parsed = std::from_chars(text.data(), text.data() + text.size(), value);
    if (parsed.ec != std::errc{} || parsed.ptr != text.data() + text.size()) throw std::invalid_argument("invalid seed");
    return value;
}
}

int main(int argc, char** argv) {
    try {
        std::string output = "worldgen-preview.ppm";
        std::uint64_t seed = 314159;
        bool plain = false;
        for (int i = 1; i < argc; ++i) {
            const std::string arg = argv[i];
            if (arg == "--plain") plain = true;
            else if (arg == "--output" && i + 1 < argc) output = argv[++i];
            else if (arg == "--seed" && i + 1 < argc) seed = seed_value(argv[++i]);
            else throw std::invalid_argument("usage: worldgen_demo [--output file.ppm] [--seed uint64] [--plain]");
        }
        constexpr int panel_width = 512, panel_height = 384, gap = 8, width = panel_width * 3 + gap * 2;
        std::vector<unsigned char> pixels(static_cast<std::size_t>(width * panel_height * 3), 8);
        const auto start = std::chrono::steady_clock::now();
        std::cout << "{\"schema\":1,\"seed\":" << seed << ",\"origin\":[-256,0],\"extent\":[512,384],\"candidates\":[";
        for (unsigned c = 0; c < 3; ++c) {
            auto recipe = example(static_cast<Candidate>(c), seed);
            if (plain) { recipe.strokes.clear(); recipe.paths.clear(); recipe.modules.clear(); recipe.overrides.clear(); }
            const auto generator = Generator::compile(recipe);
            std::uint64_t operations = 0;
            for (int cy = 0; cy < 3; ++cy) for (int cx = -2; cx < 2; ++cx) {
                const auto chunk = generator->generate({cx, cy});
                if (!generator->accepts(chunk)) throw std::runtime_error("preview generation failed: " + chunk.error);
                operations += chunk.operations;
                for (int y = 0; y < 128; ++y) for (int x = 0; x < 128; ++x) {
                    const auto material = chunk.cells[static_cast<std::size_t>(y * 128 + x)];
                    const auto& rgba = kMaterialDefinitions[static_cast<std::size_t>(material)].rgba;
                    const auto px = c * static_cast<unsigned>(panel_width + gap) + static_cast<unsigned>((cx + 2) * 128 + x);
                    const auto py = static_cast<unsigned>(cy * 128 + y);
                    const auto target = static_cast<std::size_t>((py * width + px) * 3);
                    for (unsigned channel = 0; channel < 3; ++channel) pixels[target + channel] = rgba[channel];
                }
            }
            if (c != 0) std::cout << ',';
            std::cout << "{\"id\":\"" << candidate_name(recipe.candidate) << "\",\"fingerprint\":\"" << std::hex << generator->fingerprint()
                << std::dec << "\",\"chunks\":12,\"logical_operations\":" << operations << '}';
        }
        std::ofstream file(output, std::ios::binary);
        if (!file) throw std::runtime_error("cannot open output");
        file << "P6\n" << width << ' ' << panel_height << "\n255\n";
        file.write(reinterpret_cast<const char*>(pixels.data()), static_cast<std::streamsize>(pixels.size()));
        file.close();
        if (!file) throw std::runtime_error("cannot finish output");
        const auto elapsed = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
        std::cout << "],\"elapsed_ms\":" << elapsed << ",\"measurement\":\"illustrative local wall time, not a performance gate\"}\n";
        return 0;
    } catch (const std::exception& e) { std::cerr << "worldgen_demo: " << e.what() << '\n'; return 1; }
}
