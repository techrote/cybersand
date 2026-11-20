// Native material exporter for the Metabolist Spine evidence campaign.
// No second geometry implementation: all cells come from GEN-007 chunk jobs.
#include "cybersand/world_generation.hpp"

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using cybersand::Material;
using namespace cybersand::generation;

std::int64_t integer(const char* value) {
    std::size_t used = 0;
    const auto result = std::stoll(value, &used);
    if (used != std::string(value).size()) throw std::runtime_error("invalid integer argument");
    return result;
}
std::int64_t floor_div(std::int64_t value, std::int64_t divisor) {
    const auto quotient = value / divisor;
    return quotient - (value % divisor < 0 ? 1 : 0);
}
std::string hexadecimal(std::uint64_t value) {
    std::ostringstream out;
    out << std::hex << std::setw(16) << std::setfill('0') << value;
    return out.str();
}
} // namespace

int main(int argc, char** argv) {
    try {
        if (argc != 18) throw std::runtime_error(
            "usage: exporter OUTPUT MODULE VERSION SEED X Y WIDTH HEIGHT BAY FLOOR WALL DOORS WINDOWS SHELL DECK GLAZING ACCENT");
        const std::string output = argv[1], name = argv[2];
        if (name.find_first_not_of("abcdefghijklmnopqrstuvwxyz_0123456789") != std::string::npos)
            throw std::runtime_error("invalid module identifier");
        const auto x0 = integer(argv[5]), y0 = integer(argv[6]);
        const auto width = integer(argv[7]), height = integer(argv[8]);
        if (width < 1 || width > 2048 || height < 1 || height > 2048 ||
            x0 < -1000000 || x0 > 1000000 || y0 < -1000000 || y0 > 1000000)
            throw std::runtime_error("evidence extent exceeds bounded exporter limits");
        Recipe recipe;
        recipe.schema = kArchitecturalSchemaVersion;
        recipe.candidate = Candidate::Strata;
        recipe.architecture.automatic_tunnels = false;
        recipe.architecture.automatic_doors = integer(argv[12]) != 0;
        recipe.parameters.surface_y = -100;
        recipe.seed = std::stoull(argv[4]);
        recipe.chunk_size = 64;
        ModuleInstance module;
        module.id = "metabolist-showcase";
        module.module = name;
        module.version = static_cast<std::uint32_t>(integer(argv[3]));
        module.bounds = {x0, y0, width, height};
        module.parameters = {{"bay_width", static_cast<double>(integer(argv[9]))},
            {"floor_height", static_cast<double>(integer(argv[10]))},
            {"wall", static_cast<double>(integer(argv[11]))}, {"door_width", 10}, {"shaft_width", 0},
            {"automatic_doors", static_cast<double>(integer(argv[12]))},
            {"automatic_windows", static_cast<double>(integer(argv[13]))},
            {"wall_material", static_cast<double>(integer(argv[14]))},
            {"floor_material", static_cast<double>(integer(argv[15]))},
            {"window_material", static_cast<double>(integer(argv[16]))},
            {"accent_material", static_cast<double>(integer(argv[17]))},
            {"shaft_material", static_cast<double>(integer(argv[15]))}};
        recipe.modules.push_back(module);
        const auto prepare_start = std::chrono::steady_clock::now();
        const auto generator = Generator::compile(recipe);
        const auto prepare_us = std::chrono::duration_cast<std::chrono::microseconds>(
            std::chrono::steady_clock::now() - prepare_start).count();
        std::vector<std::uint8_t> cells(static_cast<std::size_t>(width * height));
        std::vector<std::string> receipts;
        std::uint64_t operations = 0;
        std::int64_t native_us = 0;
        const auto start = std::chrono::steady_clock::now();
        for (auto cy = floor_div(y0, 64); cy <= floor_div(y0 + height - 1, 64); ++cy) {
            for (auto cx = floor_div(x0, 64); cx <= floor_div(x0 + width - 1, 64); ++cx) {
                const auto began = std::chrono::steady_clock::now();
                const auto chunk = generator->generate({cx, cy});
                native_us += std::chrono::duration_cast<std::chrono::microseconds>(
                    std::chrono::steady_clock::now() - began).count();
                if (chunk.state != ResultState::Ready) throw std::runtime_error(chunk.error);
                operations += chunk.operations;
                receipts.push_back("{\"x\":" + std::to_string(cx) + ",\"y\":" + std::to_string(cy) +
                    ",\"receipt\":\"" + hexadecimal(chunk.receipt_hash) + "\"}");
                for (std::int64_t py = 0; py < 64; ++py) {
                    const auto gy = cy * 64 + py;
                    if (gy < y0 || gy >= y0 + height) continue;
                    for (std::int64_t px = 0; px < 64; ++px) {
                        const auto gx = cx * 64 + px;
                        if (gx < x0 || gx >= x0 + width) continue;
                        cells[static_cast<std::size_t>((gy - y0) * width + gx - x0)] =
                            static_cast<std::uint8_t>(chunk.cells[static_cast<std::size_t>(py * 64 + px)]);
                    }
                }
            }
        }
        const auto elapsed_us = std::chrono::duration_cast<std::chrono::microseconds>(
            std::chrono::steady_clock::now() - start).count();
        std::ofstream stream(output, std::ios::binary);
        stream.write(reinterpret_cast<const char*>(cells.data()), static_cast<std::streamsize>(cells.size()));
        if (!stream) throw std::runtime_error("could not write native material bytes");
        const auto occupied = std::count_if(cells.begin(), cells.end(), [](auto m) { return m != 0; });
        std::cout << "{\"schema\":1,\"module\":\"" << name << "\",\"module_version\":" << module.version
            << ",\"seed\":" << recipe.seed << ",\"origin\":[" << x0 << ',' << y0 << "]"
            << ",\"extent\":[" << width << ',' << height << "],\"chunk_size\":64"
            << ",\"fingerprint\":\"" << hexadecimal(generator->fingerprint()) << "\""
            << ",\"preparation_us\":" << prepare_us << ",\"native_raster_us\":" << native_us
            << ",\"raster_and_copy_us\":" << elapsed_us << ",\"logical_operations\":" << operations
            << ",\"material_bytes\":" << cells.size() << ",\"occupied_cells\":" << occupied
            << ",\"receipts\":[";
        for (std::size_t i = 0; i < receipts.size(); ++i) {
            if (i) std::cout << ',';
            std::cout << receipts[i];
        }
        std::cout << "]}\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Metabolist export failed: " << error.what() << '\n';
        return 1;
    }
}
