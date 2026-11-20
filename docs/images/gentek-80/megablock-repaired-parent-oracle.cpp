#include "cybersand/world_generation.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <cstdint>
#include <future>
#include <iostream>
#include <map>
#include <set>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace {
using cybersand::ChunkCoord;
using cybersand::Material;
using cybersand::RectI64;
using namespace cybersand::generation;
std::uint64_t assertions = 0;
void require(bool condition, const std::string& message) {
    ++assertions;
    if (!condition) throw std::runtime_error(message);
}
template<class Action> void rejects(Action&& action, const std::string& message) {
    bool failed = false;
    try { action(); } catch (const std::exception&) { failed = true; }
    require(failed, message);
}
using Map = std::vector<Material>;
Map raster(const Generator& generator, RectI64 bounds) {
    Map result;
    result.reserve(static_cast<std::size_t>(bounds.width * bounds.height));
    for (std::int64_t y = bounds.y; y < bounds.y + bounds.height; ++y)
        for (std::int64_t x = bounds.x; x < bounds.x + bounds.width; ++x)
            result.push_back(generator.sample(x, y));
    return result;
}
std::uint64_t material_hash(const Map& materials) {
    // Portable FNV-1a-64 over row-major little-endian uint16 material IDs.
    std::uint64_t hash = UINT64_C(14695981039346656037);
    for (const auto material : materials) {
        const auto id = static_cast<std::uint16_t>(material);
        hash = (hash ^ (id & 255U)) * UINT64_C(1099511628211);
        hash = (hash ^ (id >> 8U)) * UINT64_C(1099511628211);
    }
    return hash;
}
std::size_t occupied(const Map& materials) {
    return static_cast<std::size_t>(std::count_if(materials.begin(), materials.end(),
        [](Material value) { return value != Material::Empty; }));
}
Recipe recipe(std::uint64_t seed = 0, RectI64 bounds = {0, 0, 512, 512}) {
    Recipe result;
    result.schema = kArchitecturalSchemaVersion;
    result.candidate = Candidate::Strata;
    result.architecture.automatic_tunnels = false;
    result.parameters.surface_y = -100;
    result.seed = seed;
    result.chunk_size = 128;
    ModuleInstance module;
    module.id = "megablock";
    module.module = "seeded_typology_megablock";
    module.version = 1;
    module.bounds = bounds;
    module.parameters = {{"bay_width", 96}, {"floor_height", 64}, {"wall", 4},
        {"door_width", 10}, {"shaft_width", 0}, {"automatic_doors", 1},
        {"automatic_windows", 1}, {"wall_material", 62}, {"floor_material", 66},
        {"window_material", 121}, {"accent_material", 114}, {"shaft_material", 58}};
    result.modules.push_back(module);
    return result;
}
void same_chunk(const ChunkResult& actual, const ChunkResult& expected, const std::string& label) {
    require(actual.state == ResultState::Ready && expected.state == ResultState::Ready,
        label + ": complete result");
    require(actual.chunk == expected.chunk && actual.chunk_size == expected.chunk_size &&
        actual.cells == expected.cells && actual.content_hash == expected.content_hash &&
        actual.receipt_hash == expected.receipt_hash, label + ": exact cells and receipts");
}

struct LegacyOracle {
    const char* id;
    std::uint32_t version;
    std::uint64_t ordinary, negative_closed;
};
// Captured by a separate native executable compiled from git-archive of
// 615828b28337f85e4663e03ba479616db4ddf764, BEFORE Megablock implementation.
// Both profiles cover all 256x256 cells, not three lucky pixel witnesses.
// Profile 0: seed271828, origin(0,0), bay96/floor80, windows+doors ON.
// Profile 1: seed7, origin(-197,-151), bay64/floor48, windows+doors OFF.
constexpr std::array<LegacyOracle, 74> legacy{{
{"trestle", 1, UINT64_C(0xb9ec14b0225fb3f9), UINT64_C(0xed9d03e112099d65)},
{"stacked_arcade", 1, UINT64_C(0x5028e7468b0f2703), UINT64_C(0x29781e117a747325)},
{"flying_buttress", 1, UINT64_C(0xf9c92515f8dcc1f9), UINT64_C(0x8101f49cbc8874e5)},
{"sawtooth_gallery", 1, UINT64_C(0x37b25a487cefd2ed), UINT64_C(0xc1e4333c7ad04da5)},
{"cantilever_spine", 1, UINT64_C(0x4fe00ab47f425de7), UINT64_C(0x9696c2f0625681e5)},
{"rib_vault", 1, UINT64_C(0x131072f0f5b2843c), UINT64_C(0x68d1dbdcee2d3225)},
{"nested_arcade", 1, UINT64_C(0x487c16e1e1276e9b), UINT64_C(0xea44dcaf5abf2725)},
{"suspended_deck", 1, UINT64_C(0x2995e7ad66e73c99), UINT64_C(0x9326b68dbd596b25)},
{"bowstring_truss", 1, UINT64_C(0x4d68f507e6739ce9), UINT64_C(0x145b08dbf81a1d25)},
{"diamond_truss", 1, UINT64_C(0xc4639ce6b2acd589), UINT64_C(0x2c75181934569125)},
{"portal_frame", 1, UINT64_C(0xb2702e224a83197), UINT64_C(0xb8987b1266f5f725)},
{"ladder_bridge", 1, UINT64_C(0xc2894dbac4b090a5), UINT64_C(0xb0ef453a35c54d25)},
{"stepped_aqueduct", 1, UINT64_C(0xf5b5b606e45374b5), UINT64_C(0x7c4d305644dd96a5)},
{"split_pier", 1, UINT64_C(0xc20a7ff0a47857f5), UINT64_C(0x48c0d29d9d8cde25)},
{"cable_gallery", 1, UINT64_C(0x5b72110bb93c3c87), UINT64_C(0xc0b5d8b8c3af3325)},
{"clerestory_hall", 1, UINT64_C(0xcfa8b2073a9bd0d), UINT64_C(0x950dd4c7e71a7325)},
{"mushroom_deck", 1, UINT64_C(0x59f463471c8b28c5), UINT64_C(0x2f81457df1fa4f25)},
{"zigzag_bridge", 1, UINT64_C(0x95b7b333831f941b), UINT64_C(0x220c7f6480f81aa5)},
{"scalloped_vault", 1, UINT64_C(0xb06f3b35106152a5), UINT64_C(0xf99be3082cb6c3a5)},
{"lattice_tower", 1, UINT64_C(0x96072ab8404e8ec7), UINT64_C(0x1e50d1751ee0b225)},
{"offset_arcade", 1, UINT64_C(0xa70145fc1c2a4584), UINT64_C(0xcc79b7a268d8f25)},
{"bridgehouse", 1, UINT64_C(0x1df504616d17277d), UINT64_C(0x829c7d93d6d51825)},
{"forked_gantry", 1, UINT64_C(0x1090c844d29d0507), UINT64_C(0xd907d4dfb1ae1425)},
{"buttress_wall", 1, UINT64_C(0x7d3a65d1716549fe), UINT64_C(0xd08f98d68ae780a5)},
{"fan_truss", 1, UINT64_C(0xbfc47be0c62a1b17), UINT64_C(0x63525c3b7ee23725)},
{"pratt_truss", 1, UINT64_C(0xdf350706c287ba39), UINT64_C(0x7d25e067a3404925)},
{"vierendeel_frame", 1, UINT64_C(0x5d0672eb2b00fea5), UINT64_C(0xdf5805d274d51b25)},
{"suspension_pylon", 1, UINT64_C(0xc9ebe7b37168ef89), UINT64_C(0x57e04b8c9cc47325)},
{"harp_bridge", 1, UINT64_C(0xb907e8a162c4fd4b), UINT64_C(0xca1cabb2ccc60525)},
{"double_cantilever", 1, UINT64_C(0x4a44da8792a30785), UINT64_C(0x707256a7d517b325)},
{"stepped_buttress", 1, UINT64_C(0xab92aa62b65a16a9), UINT64_C(0x34813c6080388a25)},
{"colonnade", 1, UINT64_C(0x80d1df61319d08a5), UINT64_C(0x3c70cd0a2fa46f25)},
{"basilica", 1, UINT64_C(0xcdd7f7f8804e2093), UINT64_C(0x2bafe6b3545a13a5)},
{"crenellated_bridge", 1, UINT64_C(0x471c16ca5c071625), UINT64_C(0xf2499758a99e7c25)},
{"pointed_arcade", 1, UINT64_C(0x6ef8cc3c6ac99055), UINT64_C(0xad8645975939c325)},
{"inverted_arch", 1, UINT64_C(0x63e368f42cdec557), UINT64_C(0x11061449a14cb325)},
{"hourglass_pier", 1, UINT64_C(0x1c151445b47eb229), UINT64_C(0x5b6fe8e51bda7125)},
{"tripod_frame", 1, UINT64_C(0xdc0b09a4f8e5d0a7), UINT64_C(0x926bed71a08aad25)},
{"chevron_hall", 1, UINT64_C(0xe5293f18d453c32b), UINT64_C(0xb0dbd678f8f3b6a5)},
{"hanging_arcade", 1, UINT64_C(0x7c1aca226f354d25), UINT64_C(0xdf51e212094ae325)},
{"shelf_stack", 1, UINT64_C(0xc5daf00c6da81e27), UINT64_C(0xe8fd075fc1b843a5)},
{"staggered_balcony", 1, UINT64_C(0xf65765a04bcfc1e5), UINT64_C(0x891500cad734b925)},
{"monopod_tower", 1, UINT64_C(0xd61f8b0d27b06b7), UINT64_C(0xb50954fdda8f2325)},
{"wedge_gallery", 1, UINT64_C(0x9752f0d3f88744fb), UINT64_C(0xb8d51667f65c48e5)},
{"crown_bridge", 1, UINT64_C(0x14fac8e0613b946b), UINT64_C(0xa19c6b0aa2959225)},
{"zigzag_pier", 1, UINT64_C(0x75419822317fb205), UINT64_C(0xe2c041932cb3f25)},
{"drum_vault", 1, UINT64_C(0x6ba7d048ec9e80f9), UINT64_C(0x996037605a21da5)},
{"pyramidal_frame", 1, UINT64_C(0x60b3f7003136b795), UINT64_C(0x4572f431441b4325)},
{"warren_truss", 1, UINT64_C(0x292f6478af094d45), UINT64_C(0xf5664039bee09b25)},
{"kingpost_frame", 1, UINT64_C(0x498338252c915169), UINT64_C(0x316bf163f8144125)},
{"queenpost_frame", 1, UINT64_C(0xc9cb666f7bd8a25), UINT64_C(0xf1605bfada499d65)},
{"lenticular_bridge", 1, UINT64_C(0x3f0a47ac15c3f64b), UINT64_C(0x8bac475d41c1db25)},
{"radial_stay_bridge", 1, UINT64_C(0xfd695adf17277a3b), UINT64_C(0xd5b973ac8f218a5)},
{"twin_mast_bridge", 1, UINT64_C(0xc4ea84ff4aa885fb), UINT64_C(0x4daf801ff6ab4525)},
{"a_frame_hall", 1, UINT64_C(0x80db7c15a0fc6f45), UINT64_C(0xe1974263f8632125)},
{"butterfly_hall", 1, UINT64_C(0xf8764f5e25e481c5), UINT64_C(0xe028f8b213d1f7a5)},
{"ziggurat_arcade", 1, UINT64_C(0x983b79828be9eb99), UINT64_C(0x9f2e5557fe64825)},
{"corbel_arcade", 1, UINT64_C(0x7e2b5400d060bd27), UINT64_C(0xe861d7d5b95e7725)},
{"chain_vault", 1, UINT64_C(0xd3e394f46f3d8267), UINT64_C(0xbc160d7c99efe525)},
{"ring_pier", 1, UINT64_C(0x3d8cb6479b221735), UINT64_C(0x2e82db621d81fc25)},
{"folded_plate_hall", 1, UINT64_C(0x8184ae554d6ab1f5), UINT64_C(0x45f1e48239d5bd25)},
{"space_frame", 1, UINT64_C(0xa6a89d6cdeee1b25), UINT64_C(0xf58172cff85d125)},
{"crossbeam_stack", 1, UINT64_C(0xbde1119d0e668c97), UINT64_C(0x919b2a7f181ec225)},
{"yoke_bridge", 1, UINT64_C(0x52cce924096baddb), UINT64_C(0xcb1d69ae0a1e4325)},
{"lantern_tower", 1, UINT64_C(0xd58e5a78c9a7dab5), UINT64_C(0x91bfe251f2206d25)},
{"spine_arcade", 1, UINT64_C(0x8a07559cf2cced25), UINT64_C(0xf282cfa234205025)},
{"cascade_terrace", 1, UINT64_C(0x6f7fa789fe3fa365), UINT64_C(0xe5ee8e279f2c0825)},
{"inverted_trestle", 1, UINT64_C(0x9ad0cd0743777257), UINT64_C(0xd36f3491a6620725)},
{"cranked_beam", 1, UINT64_C(0x66bae88b5202bbb), UINT64_C(0xb57d0e84c4dcc065)},
{"barrel_arcade", 1, UINT64_C(0x8a205f323f4884d5), UINT64_C(0xbcc91ac4432a1b25)},
{"buttress_crown", 1, UINT64_C(0xfeb49da32bf8aa09), UINT64_C(0x8558bc4529bf94a5)},
{"triptych_arcade", 1, UINT64_C(0xb9532be2a9ef1b25), UINT64_C(0x4a2b36ddfe9d9965)},
{"arcade", 1, UINT64_C(0x5067d96b7ab90538), UINT64_C(0xe5efafadaea84d9b)},
{"arcade", 2, UINT64_C(0x44fb644f24b4d5a8), UINT64_C(0xe5efafadaea84d9b)},
}};
void unchanged_parent_materials() {
    for (const auto& oracle : legacy) {
        for (int profile = 0; profile < 2; ++profile) {
            auto input = recipe(profile == 0 ? 271828 : 7);
            input.chunk_size = 64;
            auto& module = input.modules[0];
            module.id = "classic";
            module.module = oracle.id;
            module.version = oracle.version;
            module.bounds = profile == 0 ? RectI64{0, 0, 256, 256} : RectI64{-197, -151, 256, 256};
            module.parameters["bay_width"] = profile == 0 ? 96 : 64;
            module.parameters["floor_height"] = profile == 0 ? 80 : 48;
            module.parameters["wall"] = 3;
            module.parameters["automatic_doors"] = profile == 0 ? 1 : 0;
            module.parameters["automatic_windows"] = profile == 0 ? 1 : 0;
            module.parameters.erase("shaft_material");
            const auto actual = material_hash(raster(*Generator::compile(input), module.bounds));
            const auto historical = profile == 0 ? oracle.ordinary : oracle.negative_closed;
            std::cout << oracle.id << ":" << oracle.version << ":" << profile << " 0x" << std::hex << actual << " 0x" << historical << std::dec << "\n";
        }
    }
}

}
int main(){unchanged_parent_materials();}
