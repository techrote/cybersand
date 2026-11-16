#include "cybersand/world_generation.hpp"
#include "../src/generation_megablock_programme.hpp"

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
            require(material_hash(raster(*Generator::compile(input), module.bounds)) ==
                (profile == 0 ? oracle.ordinary : oracle.negative_closed),
                std::string(oracle.id) + " v" + std::to_string(oracle.version) +
                " preserves frozen parent full-map material profile " + std::to_string(profile));
        }
    }
}

void identity_and_admission() {
    const auto ids = Generator::builtin_modules();
    require(std::count(ids.begin(), ids.end(), "seeded_typology_megablock") == 1,
        "one registered Megablock identity");
    auto input = recipe();
    auto invalid = input;
    invalid.schema = kHierarchySchemaVersion;
    rejects([&] { (void)Generator::compile(invalid); }, "Megablock requires schema4");
    invalid = input;
    invalid.modules[0].version = 2;
    rejects([&] { (void)Generator::compile(invalid); }, "unimplemented module v2 is refused");
    for (const auto& [key, value] : std::map<std::string, double>{{"bay_width", 35},
            {"floor_height", 35}, {"wall", 6}, {"automatic_windows", .5},
            {"wall_material", 3}, {"unrecognized_control", 1}}) {
        invalid = input;
        invalid.modules[0].parameters[key] = value;
        rejects([&] { (void)Generator::compile(invalid); }, "invalid Megablock control refused: " + key);
    }
    // Cropped single-style zones are legal; full programme guarantees apply to
    // complete supercells, not to a promise that every arbitrary crop contains a core.
    input.modules[0].bounds = {0, 0, 128, 128};
    require(Generator::compile(input)->generate({0, 0}).state == ResultState::Ready,
        "partial supercell remains usable in an ordinary clipped style zone");
}

void chunk_order_slicing_and_signed_origins() {
    for (const RectI64 bounds : {RectI64{0, 0, 512, 512}, RectI64{-137, -211, 512, 512}}) {
        const auto input = recipe(17, bounds);
        const auto original = Generator::compile(input);
        std::vector<ChunkCoord> coordinates;
        // Include negative chunks and module boundaries in both configurations.
        for (std::int64_t y = -2; y <= 3; ++y)
            for (std::int64_t x = -2; x <= 3; ++x) coordinates.push_back({x, y});
        std::vector<ChunkResult> expected;
        for (const auto coord : coordinates) expected.push_back(original->generate(coord));
        const auto fresh = Generator::compile(input);
        for (std::size_t index = coordinates.size(); index-- > 0;)
            same_chunk(fresh->generate(coordinates[index]), expected[index],
                "fresh compilation/reversed chunk traversal/signed origin");
        for (const std::size_t budget : {1U, 7U, 31U, 4096U}) {
            // This chunk intersects the module for both origins. Tiny budgets
            // must exercise Megablock itself, not just the outside terrain.
            const auto index = static_cast<std::size_t>(std::find(coordinates.begin(),
                coordinates.end(), ChunkCoord{0, 0}) - coordinates.begin());
            auto job = original->begin(coordinates[index]);
            while (job->state() == ResultState::Pending) (void)job->advance(budget);
            same_chunk(job->result(), expected[index], "bounded work slicing");
        }
        auto partitioned_input = input;
        partitioned_input.chunk_size = 64;
        const auto partitioned = Generator::compile(partitioned_input);
        bool same_partition = true;
        for (std::size_t index = 0; index < coordinates.size(); ++index) {
            const auto coord = coordinates[index];
            for (std::int64_t py = 0; py < 2; ++py) for (std::int64_t px = 0; px < 2; ++px) {
                const auto part = partitioned->generate({coord.x * 2 + px, coord.y * 2 + py});
                require(part.state == ResultState::Ready, "64-cell partition completes");
                for (std::size_t y = 0; y < 64; ++y) for (std::size_t x = 0; x < 64; ++x) {
                    const auto reference_index = (static_cast<std::size_t>(py) * 64 + y) * 128 +
                        static_cast<std::size_t>(px) * 64 + x;
                    same_partition &= part.cells[y * 64 + x] == expected[index].cells[reference_index];
                }
            }
        }
        require(same_partition, "64/128 chunk partitions preserve every cell across signed seams");
        auto concurrent = std::async(std::launch::async, [original] { return original->generate({0, 0}); });
        (void)original->generate({1, 1});
        same_chunk(concurrent.get(), original->generate({0, 0}), "concurrent immutable sampling");
        auto cancelled = original->begin({0, 0});
        (void)cancelled->advance(13);
        cancelled->cancel();
        require(cancelled->state() == ResultState::Cancelled && cancelled->result().cells.empty(),
            "cancelled Megablock proposal exposes no partial map");
    }
    auto exhausted = recipe();
    exhausted.limits.max_operations_per_chunk = 1;
    const auto failed = Generator::compile(exhausted)->generate({0, 0});
    require(failed.state == ResultState::Failed && failed.cells.empty(),
        "Megablock obeys existing bounded native work refusal");
}

// Independently reproduce the documented existing coordinate hash; no sampler
// geometry is copied. The private programme helper identifies lots, while every
// structural assertion below inspects the actual native material output.
std::uint64_t mix_coordinate(std::uint64_t value) {
    value += UINT64_C(0x9e3779b97f4a7c15);
    value = (value ^ (value >> 30U)) * UINT64_C(0xbf58476d1ce4e5b9);
    value = (value ^ (value >> 27U)) * UINT64_C(0x94d049bb133111eb);
    return value ^ (value >> 31U);
}
megablock::Programme programme_at(std::uint64_t seed, std::int64_t x, std::int64_t y) {
    return megablock::programme(mix_coordinate(seed ^ mix_coordinate(static_cast<std::uint64_t>(x)) ^
        std::rotl(mix_coordinate(static_cast<std::uint64_t>(y)), 27) ^ mix_coordinate(megablock::hash_lane)));
}
void material_interface_contract() {
    using T = megablock::Typology;
    std::set<T> witnessed_families;
    std::set<int> witnessed_core_columns, witnessed_bridge_bands;
    std::set<std::pair<int, int>> witnessed_core_bridge_pairs;
    // Adversarial smallest legal clearances, odd dimensions, maximum thickness
    // and largest legal lots share the same material-level contract.
    for (const auto& dimensions : {std::array<std::int64_t, 3>{96, 64, 4},
            std::array<std::int64_t, 3>{18, 18, 1}, {42, 42, 5}, {67, 51, 3}, {256, 256, 5},
            {18, 256, 1}, {256, 18, 1}}) {
        const auto bay = dimensions[0], height = dimensions[1], wall = dimensions[2];
        for (std::uint64_t seed = 0; seed < 32; ++seed) {
            auto input = recipe(seed, {-197, -151, 8 * bay, 8 * height});
            input.modules[0].parameters["bay_width"] = static_cast<double>(bay);
            input.modules[0].parameters["floor_height"] = static_cast<double>(height);
            input.modules[0].parameters["wall"] = static_cast<double>(wall);
            const auto generator = Generator::compile(input);
            for (std::int64_t my = 0; my < 2; ++my) for (std::int64_t mx = 0; mx < 2; ++mx) {
                const auto plan = programme_at(seed, mx, my);
                const auto ox = input.modules[0].bounds.x + 4 * bay * mx;
                const auto oy = input.modules[0].bounds.y + 4 * height * my;
                const auto value = [&](std::int64_t x, std::int64_t y) { return generator->sample(ox + x, oy + y); };
                std::set<T> families;
                for (int row = 0; row < 4; ++row) for (int col = 0; col < 4; ++col) {
                    const auto type = megablock::typology(plan, col, row);
                    families.insert(type);
                    witnessed_families.insert(type);
                    require((type != T::Crown || row == 0) &&
                        (type != T::Buttress || row == 3) &&
                        (type != T::Habitation || row == 1 || row == 2),
                        "programme restricts roof, support mass and glazing families to their legal bands");
                }
                witnessed_core_columns.insert(plan.core);
                witnessed_bridge_bands.insert(plan.bridge_band);
                witnessed_core_bridge_pairs.emplace(plan.core, plan.bridge_band);
                require(families.size() >= 6 && families.contains(T::Core) && families.contains(T::Atrium) &&
                    families.contains(T::Bridge) && families.contains(T::Habitation) && families.contains(T::Buttress),
                    "every complete supercell has heterogeneous support, void, bridge and habitation roles");
                bool core_continuous = true;
                for (std::int64_t y = 0; y < 4 * height; ++y)
                    core_continuous &= value(plan.core * bay + bay / 2 + wall, y) != Material::Empty;
                require(core_continuous, "actual native core rail reaches all four bands without an empty seam");
                bool empty_rectangle = true;
                const auto void_top = (3 - plan.bridge_band) * height;
                for (std::int64_t y = void_top; y < void_top + height; ++y)
                    for (std::int64_t x = plan.atrium * bay; x < (plan.atrium + 1) * bay; ++x)
                        empty_rectangle &= value(x, y) == Material::Empty;
                require(empty_rectangle, "a complete bay by floor protected atrium remains native Empty");
                bool bridge_and_landings = true;
                const auto left = std::min(plan.core, plan.support) * bay;
                const auto right = (std::max(plan.core, plan.support) + 1) * bay;
                const auto datum = plan.bridge_band * height + height / 2;
                for (std::int64_t y = datum - wall; y <= datum + wall; ++y)
                    for (std::int64_t x = left; x < right; ++x)
                        bridge_and_landings &= value(x, y) != Material::Empty;
                require(bridge_and_landings, "real bridge deck joins both real neighbour landings at every interface cell");
                bool transfer_continuous = true;
                for (std::int64_t y = 4 * height - wall; y < 4 * height; ++y)
                    for (std::int64_t x = 0; x < 4 * bay; ++x)
                        transfer_continuous &= value(x, y) != Material::Empty;
                require(transfer_continuous, "actual lower transfer slab connects all four lots");
            }
        }
    }
    require(witnessed_families.size() == 9, "declared seeds exercise all nine authored families");
    require(witnessed_core_columns.size() == 4 && witnessed_bridge_bands.size() == 2,
        "seed variation moves cores among every column and bridges between both middle levels");
    require(witnessed_core_bridge_pairs.size() == 8,
        "native material interface tests cover every core-column and bridge-level combination");
}

struct Components { std::size_t count = 0, largest = 0, interior_singletons = 0; };
Components solid_components(const Map& map, std::size_t width, std::size_t height) {
    std::vector<bool> visited(map.size(), false);
    std::vector<std::size_t> pending;
    Components result;
    for (std::size_t start = 0; start < map.size(); ++start) {
        if (visited[start] || map[start] == Material::Empty) continue;
        ++result.count;
        pending.clear();
        pending.push_back(start);
        visited[start] = true;
        bool touches_edge = false;
        for (std::size_t cursor = 0; cursor < pending.size(); ++cursor) {
            const auto index = pending[cursor], x = index % width, y = index / width;
            touches_edge |= x == 0 || y == 0 || x + 1 == width || y + 1 == height;
            const auto visit = [&](std::size_t neighbour) {
                if (!visited[neighbour] && map[neighbour] != Material::Empty) {
                    visited[neighbour] = true;
                    pending.push_back(neighbour);
                }
            };
            if (x > 0) visit(index - 1);
            if (x + 1 < width) visit(index + 1);
            if (y > 0) visit(index - width);
            if (y + 1 < height) visit(index + width);
        }
        result.largest = std::max(result.largest, pending.size());
        if (pending.size() == 1 && !touches_edge) ++result.interior_singletons;
    }
    return result;
}
void material_connectivity_extremes() {
    // Unlike arbitrary display crops, every cell of a complete supercell is
    // expected to join its lower transfer slab. Four-neighbour flood filling is
    // independent of typology labels and catches one-cell diagonal contacts,
    // floating rails and detached cantilevers at the most stretched dimensions.
    for (const auto& dimensions : {std::array<std::int64_t, 3>{18, 256, 1},
            std::array<std::int64_t, 3>{256, 18, 1}, {18, 18, 1}, {24, 24, 2},
            {30, 30, 3}, {36, 36, 4}, {42, 42, 5}}) {
        const auto bay = dimensions[0], height = dimensions[1], wall = dimensions[2];
        for (std::uint64_t seed = 0; seed < 32; ++seed) {
            auto input = recipe(seed, {-137, -83, 4 * bay, 4 * height});
            input.modules[0].parameters["bay_width"] = static_cast<double>(bay);
            input.modules[0].parameters["floor_height"] = static_cast<double>(height);
            input.modules[0].parameters["wall"] = static_cast<double>(wall);
            const auto map = raster(*Generator::compile(input), input.modules[0].bounds);
            const auto components = solid_components(map, static_cast<std::size_t>(4 * bay),
                static_cast<std::size_t>(4 * height));
            require(components.count == 1,
                "complete supercell forms one face-connected material structure at seed " +
                std::to_string(seed) + ", bay " + std::to_string(bay) + ", floor " +
                std::to_string(height) + ", wall " + std::to_string(wall) +
                "; components=" + std::to_string(components.count));
        }
    }
}
void seed_survey_and_control_response() {
    std::set<std::uint64_t> distinct;
    // Declared before visual selection: contiguous seeds 0..31, identical inputs.
    for (std::uint64_t seed = 0; seed < 32; ++seed) {
        const auto input = recipe(seed);
        const auto map = raster(*Generator::compile(input), input.modules[0].bounds);
        const auto count = occupied(map);
        require(count > map.size() * 8 / 100 && count < map.size() * 75 / 100,
            "seed " + std::to_string(seed) + " preserves substantial structure and negative space");
        distinct.insert(material_hash(map));
        const auto components = solid_components(map, 512, 512);
        require(components.interior_singletons == 0,
            "seed " + std::to_string(seed) + " has no isolated one-cell fragment");
        if (seed < 8) {
            require(raster(*Generator::compile(input), input.modules[0].bounds) == map,
                "each of eight representative seeds repeats its full material map");
            auto closed = input;
            closed.modules[0].parameters["automatic_windows"] = 0;
            const auto no_windows = raster(*Generator::compile(closed), closed.modules[0].bounds);
            bool glazing_only = true;
            std::size_t window_changes = 0;
            for (std::size_t index = 0; index < map.size(); ++index) if (map[index] != no_windows[index]) {
                ++window_changes;
                glazing_only &= map[index] == Material::FrostedGlass && no_windows[index] != Material::Empty;
            }
            require(window_changes > 0 && glazing_only &&
                std::count(no_windows.begin(), no_windows.end(), Material::FrostedGlass) == 0,
                "windows toggle changes only real glazing to structural material");
            closed = input;
            closed.modules[0].parameters["automatic_doors"] = 0;
            const auto no_doors = raster(*Generator::compile(closed), closed.modules[0].bounds);
            bool aperture_only = true;
            std::size_t door_changes = 0;
            for (std::size_t index = 0; index < map.size(); ++index) if (map[index] != no_doors[index]) {
                ++door_changes;
                aperture_only &= map[index] == Material::Empty && no_doors[index] != Material::Empty;
            }
            require(door_changes > 0 && aperture_only,
                "doors toggle opens/closes genuine apertures independently of windows");
        }
    }
    require(distinct.size() >= 8, "32 declared seeds provide at least eight distinct full material hashes");
    const auto base = recipe(7);
    const auto base_map = raster(*Generator::compile(base), base.modules[0].bounds);
    for (const auto& [key, value] : std::map<std::string, double>{{"bay_width", 64}, {"floor_height", 96}}) {
        auto changed = base;
        changed.modules[0].parameters[key] = value;
        const auto map = raster(*Generator::compile(changed), changed.modules[0].bounds);
        require(material_hash(map) != material_hash(base_map), key + " changes topology/material map");
    }
    auto thin = base, heavy = base;
    thin.modules[0].parameters["wall"] = 1;
    heavy.modules[0].parameters["wall"] = 5;
    const auto thin_map = raster(*Generator::compile(thin), thin.modules[0].bounds);
    const auto heavy_map = raster(*Generator::compile(heavy), heavy.modules[0].bounds);
    require(occupied(heavy_map) > occupied(thin_map), "wall thickness increases structural occupancy");
    std::cout << "Megablock seed survey: " << distinct.size() << "/32 distinct full maps\n";
}
} // namespace

int main() {
    try {
        unchanged_parent_materials();
        identity_and_admission();
        chunk_order_slicing_and_signed_origins();
        material_interface_contract();
        material_connectivity_extremes();
        seed_survey_and_control_response();
        std::cout << "PASS Seeded Typology Megablock: " << assertions
            << " assertions; 148 frozen parent material maps; 32 declared seeds\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "FAIL Seeded Typology Megablock: " << error.what() << '\n';
        return 1;
    }
}
