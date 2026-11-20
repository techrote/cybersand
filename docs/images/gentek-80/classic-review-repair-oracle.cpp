// Independent black-box capture driver for the six reviewed CLASSIC repairs.
// Compile this identical file against isolated repaired-#624 and candidate
// native inputs. It contains no geometry formulas or candidate implementation.
#include "cybersand/world_generation.hpp"

#include <array>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>

using cybersand::ChunkCoord;
using cybersand::Material;
using cybersand::RectI64;
using namespace cybersand::generation;

constexpr std::array<const char*, 72> classic_ids{
    "trestle","stacked_arcade","flying_buttress","sawtooth_gallery","cantilever_spine","rib_vault",
    "nested_arcade","suspended_deck","bowstring_truss","diamond_truss","portal_frame","ladder_bridge",
    "stepped_aqueduct","split_pier","cable_gallery","clerestory_hall","mushroom_deck","zigzag_bridge",
    "scalloped_vault","lattice_tower","offset_arcade","bridgehouse","forked_gantry","buttress_wall",
    "fan_truss","pratt_truss","vierendeel_frame","suspension_pylon","harp_bridge","double_cantilever",
    "stepped_buttress","colonnade","basilica","crenellated_bridge","pointed_arcade","inverted_arch",
    "hourglass_pier","tripod_frame","chevron_hall","hanging_arcade","shelf_stack","staggered_balcony",
    "monopod_tower","wedge_gallery","crown_bridge","zigzag_pier","drum_vault","pyramidal_frame",
    "warren_truss","kingpost_frame","queenpost_frame","lenticular_bridge","radial_stay_bridge","twin_mast_bridge",
    "a_frame_hall","butterfly_hall","ziggurat_arcade","corbel_arcade","chain_vault","ring_pier",
    "folded_plate_hall","space_frame","crossbeam_stack","yoke_bridge","lantern_tower","spine_arcade",
    "cascade_terrace","inverted_trestle","cranked_beam","barrel_arcade","buttress_crown","triptych_arcade"
};

Recipe configured(const std::string& id, int bay, int floor, int wall,
                  std::uint64_t seed, RectI64 bounds, bool windows = true) {
    Recipe result;
    result.schema = kArchitecturalSchemaVersion;
    result.candidate = Candidate::Strata;
    result.parameters.surface_y = -100;
    result.chunk_size = 64;
    result.seed = seed;
    result.architecture.automatic_tunnels = false;
    ModuleInstance module;
    module.id = "gentek80-review-oracle";
    module.module = id;
    module.version = 1;
    module.bounds = bounds;
    module.parameters = {{"bay_width",bay},{"floor_height",floor},{"wall",wall},
        {"door_width",10},{"shaft_width",0},{"automatic_doors",windows ? 1 : 0},
        {"automatic_windows",windows ? 1 : 0},
        {"wall_material",58},{"floor_material",62},{"window_material",121},{"accent_material",65}};
    result.modules.push_back(std::move(module));
    return result;
}

void little_word(std::ostream& out, std::uint64_t value, unsigned width) {
    for (unsigned i = 0; i < width; ++i) {
        out.put(static_cast<char>(value & 255U));
        value >>= 8U;
    }
}

void legacy(const std::filesystem::path& path, bool rosework = false) {
    std::ofstream out(path, std::ios::binary);
    if (!out) throw std::runtime_error("cannot create legacy snapshot");
    out << "CLASSIC72-LE16-v1\n";
    constexpr std::array<int, 3> bays{64,96,128}, floors{48,80,96}, walls{2,3,5};
    constexpr std::array<std::uint64_t, 3> seeds{7,271828,2026};
    constexpr std::array coordinates{ChunkCoord{-2,-1},ChunkCoord{-1,0},ChunkCoord{0,0},ChunkCoord{3,2}};
    for (std::size_t module = 0; module < classic_ids.size() + 2; ++module) {
        const std::string id = module < classic_ids.size() ? classic_ids[module] : "arcade";
        const auto version = module < classic_ids.size() ? 1U : static_cast<unsigned>(module - classic_ids.size() + 1);
        for (std::size_t profile = 0; profile < 3; ++profile) {
            auto recipe = configured(id, bays[profile], floors[profile], walls[profile], seeds[profile],
                                     {-256,-256,768,768}, profile != 2);
            recipe.modules[0].version = version;
            if (rosework) {
                recipe.modules[0].parameters["wall_material"] = 100;
                recipe.modules[0].parameters["floor_material"] = 119;
                recipe.modules[0].parameters["window_material"] = 55;
                recipe.modules[0].parameters["accent_material"] = 119;
            }
            const auto generator = Generator::compile(recipe);
            little_word(out, generator->fingerprint(), 8);
            for (const auto coordinate : coordinates) {
                const auto chunk = generator->generate(coordinate);
                if (chunk.state != ResultState::Ready) throw std::runtime_error("legacy chunk refused");
                little_word(out, chunk.content_hash, 8);
                little_word(out, chunk.receipt_hash, 8);
                for (const auto material : chunk.cells)
                    little_word(out, static_cast<std::uint16_t>(material), 2);
            }
        }
    }
    if (!out) throw std::runtime_error("legacy snapshot incomplete");
}

void contacts(const std::filesystem::path& directory) {
    std::filesystem::create_directory(directory);
    constexpr std::array<const char*, 6> ids{
        "ring_pier", "tripod_frame", "cascade_terrace", "scalloped_vault", "suspended_deck", "buttress_wall"};
    struct Dimensions { int bay, floor, wall; };
    constexpr std::array<Dimensions, 8> sizes{{
        {64,48,2}, {96,80,3}, {128,96,5}, {192,32,1},
        {32,128,1}, {16,16,1}, {256,16,1}, {16,256,1}}};
    std::cout << "[\n";
    bool comma = false;
    for (const auto id : ids) for (std::size_t size = 0; size < sizes.size(); ++size)
        for (const bool negative : {false, true}) for (const bool windows : {false, true}) {
            const auto d = sizes[size];
            const std::int64_t ox = negative ? -197 : 137, oy = negative ? -151 : 211;
            const RectI64 bounds{ox,oy,2*d.bay,2*d.floor};
            const auto recipe = configured(id,d.bay,d.floor,d.wall,negative ? 7U : 271828U,bounds,windows);
            const auto generator = Generator::compile(recipe);
            const std::string name = std::string(id) + "-" + std::to_string(size) + "-" +
                (negative ? "negative" : "positive") + "-" + (windows ? "open" : "closed") + ".le16";
            std::ofstream out(directory / name, std::ios::binary);
            for (std::int64_t y = bounds.y; y < bounds.y + bounds.height; ++y)
                for (std::int64_t x = bounds.x; x < bounds.x + bounds.width; ++x)
                    little_word(out, static_cast<std::uint16_t>(generator->sample(x,y)), 2);
            if (!out) throw std::runtime_error("contact snapshot incomplete");
            if (comma) std::cout << ",\n";
            comma = true;
            std::cout << "{\"file\":\"" << name << "\",\"module\":\"" << id << "\",\"bay\":" << d.bay
                      << ",\"floor\":" << d.floor << ",\"wall\":" << d.wall << ",\"origin_x\":" << ox
                      << ",\"origin_y\":" << oy << ",\"windows\":" << (windows ? "true" : "false")
                      << ",\"width\":" << bounds.width << ",\"height\":" << bounds.height << "}";
        }
    std::cout << "\n]\n";
}

int main(int argc, char** argv) {
    try {
        if (argc != 3) throw std::invalid_argument("usage: review-oracle --legacy FILE | --legacy-rosework FILE | --contacts DIRECTORY");
        if (std::string(argv[1]) == "--legacy") legacy(argv[2]);
        else if (std::string(argv[1]) == "--legacy-rosework") legacy(argv[2], true);
        else if (std::string(argv[1]) == "--contacts") contacts(argv[2]);
        else throw std::invalid_argument("unknown capture mode");
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
