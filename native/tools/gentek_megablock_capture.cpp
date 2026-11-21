// Qualification-only native raster/benchmark adapter. No geometry is authored here.
#include "cybersand/world_generation.hpp"
#include "../src/generation_megablock_programme.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <chrono>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using namespace cybersand::generation;
using cybersand::Material;
using Clock = std::chrono::steady_clock;

struct Options {
    std::string module = "seeded_typology_megablock", output;
    std::uint64_t seed = 0;
    int width = 512, height = 512, bay = 96, level = 64, wall = 4;
    int windows = 1, doors = 1, iterations = 0;
    std::int64_t x = 0, y = 0;
};

Options parse(int argc, char** argv) {
    Options o;
    for (int i = 1; i < argc; i += 2) {
        if (i + 1 == argc) throw std::invalid_argument("option requires a value");
        const std::string key = argv[i], value = argv[i + 1];
        if (key == "--module") o.module = value;
        else if (key == "--output") o.output = value;
        else if (key == "--seed") o.seed = std::stoull(value);
        else if (key == "--width") o.width = std::stoi(value);
        else if (key == "--height") o.height = std::stoi(value);
        else if (key == "--bay") o.bay = std::stoi(value);
        else if (key == "--level") o.level = std::stoi(value);
        else if (key == "--wall") o.wall = std::stoi(value);
        else if (key == "--windows") o.windows = std::stoi(value);
        else if (key == "--doors") o.doors = std::stoi(value);
        else if (key == "--origin-x") o.x = std::stoll(value);
        else if (key == "--origin-y") o.y = std::stoll(value);
        else if (key == "--iterations") o.iterations = std::stoi(value);
        else throw std::invalid_argument("unknown option: " + key);
    }
    if (o.width < 16 || o.height < 16 || o.width > 2048 || o.height > 2048 ||
        o.iterations < 0 || o.iterations > 25 || o.x < -1000000 || o.x > 1000000 ||
        o.y < -1000000 || o.y > 1000000)
        throw std::invalid_argument("capture dimensions, origin or iteration count exceed tool bounds");
    return o;
}

Recipe recipe(const Options& o) {
    Recipe r;
    r.schema = kArchitecturalSchemaVersion;
    r.seed = o.seed;
    r.chunk_size = 64;
    r.candidate = Candidate::DistrictGrammar;
    r.architecture.automatic_tunnels = false;
    r.architecture.automatic_doors = o.doors != 0;
    r.themes.weights = {{"industrial", 1}};
    ModuleInstance m;
    m.id = "megablock-evidence";
    m.module = o.module;
    m.version = 1;
    m.bounds = {o.x, o.y, o.width, o.height};
    m.parameters = {{"bay_width", o.bay}, {"floor_height", o.level}, {"wall", o.wall},
        {"door_width", 12}, {"shaft_width", 0}, {"automatic_windows", o.windows},
        {"automatic_doors", o.doors}, {"wall_material", 58}, {"floor_material", 62},
        {"partition_material", 58}, {"accent_material", 62}, {"window_material", 121},
        {"shaft_material", 62}};
    r.modules.push_back(m);
    return r;
}

std::int64_t floor_div(std::int64_t v, std::int64_t d) {
    return v / d - static_cast<std::int64_t>(v % d < 0);
}

std::vector<Material> raster(const std::shared_ptr<const Generator>& generator, const Options& o) {
    std::vector<Material> cells(static_cast<std::size_t>(o.width * o.height));
    for (auto cy = floor_div(o.y, 64); cy <= floor_div(o.y + o.height - 1, 64); ++cy) {
        for (auto cx = floor_div(o.x, 64); cx <= floor_div(o.x + o.width - 1, 64); ++cx) {
            const auto chunk = generator->generate({static_cast<std::int32_t>(cx), static_cast<std::int32_t>(cy)});
            if (chunk.state != ResultState::Ready) throw std::runtime_error(chunk.error);
            for (int y = 0; y < 64; ++y) {
                const auto ry = cy * 64 + y - o.y;
                if (ry < 0 || ry >= o.height) continue;
                for (int x = 0; x < 64; ++x) {
                    const auto rx = cx * 64 + x - o.x;
                    if (rx >= 0 && rx < o.width)
                        cells[static_cast<std::size_t>(ry * o.width + rx)] =
                            chunk.cells[static_cast<std::size_t>(y * 64 + x)];
                }
            }
        }
    }
    return cells;
}

struct Components {
    std::size_t count = 0, largest = 0, smallest = 0, singletons = 0;
};

Components components(const std::vector<Material>& cells, int width, int height, bool occupied) {
    Components result;
    std::vector<bool> seen(cells.size(), false);
    std::vector<std::size_t> queue;
    queue.reserve(cells.size());
    for (std::size_t at = 0; at < cells.size(); ++at) {
        if (seen[at] || ((cells[at] != Material::Empty) != occupied)) continue;
        queue.clear(); queue.push_back(at); seen[at] = true;
        for (std::size_t head = 0; head < queue.size(); ++head) {
            const auto p = queue[head];
            const auto x = p % static_cast<std::size_t>(width), y = p / static_cast<std::size_t>(width);
            const auto offer = [&](std::size_t n) {
                if (!seen[n] && ((cells[n] != Material::Empty) == occupied)) {
                    seen[n] = true; queue.push_back(n);
                }
            };
            if (x > 0) offer(p - 1);
            if (x + 1 < static_cast<std::size_t>(width)) offer(p + 1);
            if (y > 0) offer(p - static_cast<std::size_t>(width));
            if (y + 1 < static_cast<std::size_t>(height)) offer(p + static_cast<std::size_t>(width));
        }
        ++result.count;
        result.largest = std::max(result.largest, queue.size());
        if (result.smallest == 0 || queue.size() < result.smallest) result.smallest = queue.size();
        if (queue.size() == 1) ++result.singletons;
    }
    return result;
}

struct EmptyRectangle { int x = 0, y = 0, width = 0, height = 0, area = 0; };
EmptyRectangle largest_empty_rectangle(const std::vector<Material>& cells, int width, int height) {
    EmptyRectangle best;
    std::vector<int> heights(static_cast<std::size_t>(width + 1), 0), stack;
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            auto& h = heights[static_cast<std::size_t>(x)];
            h = cells[static_cast<std::size_t>(y * width + x)] == Material::Empty ? h + 1 : 0;
        }
        stack.clear();
        for (int x = 0; x <= width; ++x) {
            while (!stack.empty() && heights[static_cast<std::size_t>(stack.back())] > heights[static_cast<std::size_t>(x)]) {
                const int h = heights[static_cast<std::size_t>(stack.back())]; stack.pop_back();
                const int left = stack.empty() ? 0 : stack.back() + 1;
                const int w = x - left;
                if (w * h > best.area) best = {left, y - h + 1, w, h, w * h};
            }
            stack.push_back(x);
        }
    }
    return best;
}

double elapsed_ms(Clock::time_point start) {
    return std::chrono::duration<double, std::milli>(Clock::now() - start).count();
}

template<class F> std::vector<double> timed(int n, F&& action, std::uint64_t& checksum) {
    std::vector<double> samples;
    for (int i = 0; i < n; ++i) {
        const auto start = Clock::now();
        checksum += action();
        samples.push_back(elapsed_ms(start));
    }
    return samples;
}

void print_times(const std::vector<double>& samples) {
    std::cout << '[';
    for (std::size_t i = 0; i < samples.size(); ++i) std::cout << (i ? "," : "") << samples[i];
    std::cout << ']';
}

// Generic hash_xy reproduced from world_generation.cpp. Typology decisions are
// read from the exact private production helper, not inferred from pixels.
std::uint64_t mix(std::uint64_t v) {
    v += UINT64_C(0x9e3779b97f4a7c15);
    v = (v ^ (v >> 30U)) * UINT64_C(0xbf58476d1ce4e5b9);
    v = (v ^ (v >> 27U)) * UINT64_C(0x94d049bb133111eb);
    return v ^ (v >> 31U);
}

void print_programmes(const Options& o) {
    if (o.module != "seeded_typology_megablock") return;
    std::array<bool, 9> families{};
    std::array<int, 9> lots{};
    bool first = true;
    std::cout << ",\"programmes\":[";
    for (int my = 0; my * 4 * o.level < o.height; ++my) {
        for (int mx = 0; mx * 4 * o.bay < o.width; ++mx) {
            const auto h = mix(o.seed ^ mix(static_cast<std::uint64_t>(mx)) ^
                std::rotl(mix(static_cast<std::uint64_t>(my)), 27) ^ mix(megablock::hash_lane));
            const auto p = megablock::programme(h);
            std::cout << (first ? "" : ",") << "{\"supercell\":[" << mx << ',' << my
                << "],\"core_column\":" << p.core << ",\"atrium_column\":" << p.atrium
                << ",\"support_column\":" << p.support << ",\"spare_column\":" << p.spare
                << ",\"bridge_band\":" << p.bridge_band << ",\"complete_in_capture\":"
                << ((mx + 1) * 4 * o.bay <= o.width && (my + 1) * 4 * o.level <= o.height ? "true" : "false")
                << ",\"protected_void\":{\"x\":" << o.x + mx*4*o.bay+p.atrium*o.bay
                << ",\"y\":" << o.y + my*4*o.level+(3-p.bridge_band)*o.level
                << ",\"width\":" << o.bay << ",\"height\":" << o.level
                << "},\"bands_top_to_bottom\":[";
            first = false;
            for (int band = 0; band < 4; ++band) {
                std::cout << (band ? ",[" : "[");
                for (int col = 0; col < 4; ++col) {
                    const auto t = megablock::typology(p, col, band);
                    std::cout << (col ? ",\"" : "\"") << megablock::name(t) << '"';
                    if ((mx*4+col)*o.bay < o.width && (my*4+band)*o.level < o.height) {
                        families[static_cast<std::size_t>(t)] = true;
                        ++lots[static_cast<std::size_t>(t)];
                    }
                }
                std::cout << ']';
            }
            std::cout << "]}";
        }
    }
    std::cout << "],\"typology_families\":" << std::count(families.begin(), families.end(), true)
        << ",\"typology_lots_in_capture\":{";
    for (std::size_t i = 0; i < lots.size(); ++i)
        std::cout << (i ? ",\"" : "\"") << megablock::name(static_cast<megablock::Typology>(i)) << "\":" << lots[i];
    std::cout << "},\"programme_diagnostic_source\":\"private production helper generation_megablock_programme.hpp\"";
}
} // namespace

int main(int argc, char** argv) {
    try {
        const auto o = parse(argc, argv);
        const auto r = recipe(o);
        const auto started = Clock::now();
        const auto generator = Generator::compile(r);
        const double prepare_ms = elapsed_ms(started);
        const auto raster_started = Clock::now();
        const auto cells = raster(generator, o);
        const double raster_ms = elapsed_ms(raster_started);
        const auto solid = components(cells, o.width, o.height, true);
        const auto empty = components(cells, o.width, o.height, false);
        const auto rectangle = largest_empty_rectangle(cells, o.width, o.height);
        const auto occupied = static_cast<std::size_t>(std::count_if(cells.begin(), cells.end(),
            [](Material m) { return m != Material::Empty; }));
        std::uint64_t checksum = 0;
        std::vector<double> sampler_times, generator_times;
        if (o.iterations > 0) {
            const auto registry = ModuleRegistry::builtins();
            const auto sampler = registry.find(o.module, 1).prepare(r.modules.front(), o.seed);
            const Parameters parameters;
            const Palette palette;
            for (int y = 0; y < o.height; ++y)
                for (int x = 0; x < o.width; ++x)
                    if (sampler->sample({o.x+x,o.y+y,o.seed,parameters,palette}, Material::Empty) !=
                        cells[static_cast<std::size_t>(y * o.width + x)])
                        throw std::runtime_error("direct sampler differs from native chunk output");
            sampler_times = timed(o.iterations, [&]() {
                std::uint64_t sum = 0;
                for (int y = 0; y < o.height; ++y)
                    for (int x = 0; x < o.width; ++x)
                        sum += static_cast<std::uint64_t>(*sampler->sample(
                            {o.x+x,o.y+y,o.seed,parameters,palette}, Material::Empty));
                return sum;
            }, checksum);
            generator_times = timed(o.iterations, [&]() {
                const auto sample = raster(generator, o);
                std::uint64_t sum = 0;
                for (const auto m : sample) sum += static_cast<std::uint64_t>(m);
                return sum;
            }, checksum);
        }
        if (!o.output.empty()) {
            std::ofstream file(o.output, std::ios::binary);
            if (!file) throw std::runtime_error("cannot write raster");
            for (const auto m : cells) {
                const auto v = static_cast<std::uint16_t>(m);
                const char bytes[2]{static_cast<char>(v & 255), static_cast<char>(v >> 8)};
                file.write(bytes, 2);
            }
            if (!file) throw std::runtime_error("incomplete raster write");
        }
        std::cout << std::setprecision(10) << "{\"schema\":1,\"module\":\"" << o.module
            << "\",\"version\":1,\"seed\":" << o.seed << ",\"width\":" << o.width
            << ",\"height\":" << o.height << ",\"origin\":[" << o.x << ',' << o.y
            << "],\"bay_width\":" << o.bay << ",\"floor_height\":" << o.level
            << ",\"wall\":" << o.wall << ",\"windows\":" << o.windows << ",\"doors\":" << o.doors
            << ",\"occupied_cells\":" << occupied << ",\"occupied_ratio\":"
            << static_cast<double>(occupied) / static_cast<double>(cells.size())
            << ",\"solid_components4\":" << solid.count << ",\"largest_solid_component\":" << solid.largest
            << ",\"smallest_solid_component\":" << solid.smallest << ",\"isolated_single_cells\":" << solid.singletons
            << ",\"void_components4\":" << empty.count << ",\"largest_void_component\":" << empty.largest
            << ",\"largest_empty_rectangle\":{\"x\":" << rectangle.x << ",\"y\":" << rectangle.y
            << ",\"width\":" << rectangle.width << ",\"height\":" << rectangle.height << ",\"area\":" << rectangle.area
            << "},\"generator_fingerprint\":\"" << std::hex << generator->fingerprint() << std::dec
            << "\",\"operations_per_cell\":" << generator->operations_per_cell()
            << ",\"preparation_ms\":" << prepare_ms << ",\"native_raster_ms\":" << raster_ms
            << ",\"direct_sampler_ms\":";
        print_times(sampler_times);
        std::cout << ",\"generator_raster_ms\":"; print_times(generator_times);
        std::cout << ",\"benchmark_checksum\":" << checksum;
        print_programmes(o);
        std::cout << "}\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "gentek_megablock_capture: " << error.what() << '\n';
        return 1;
    }
}
