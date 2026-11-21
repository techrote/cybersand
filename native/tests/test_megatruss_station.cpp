#include "cybersand/world_generation.hpp"

#include <algorithm>
#include <array>
#include <chrono>
#include <cstdint>
#include <fstream>
#include <future>
#include <iomanip>
#include <iostream>
#include <limits>
#include <memory>
#include <numeric>
#include <set>
#include <stdexcept>
#include <string>
#include <vector>

// Independent black-box qualification of the ordinary GEN-007 native API.
// Geometry assertions below inspect emitted materials, not a second sampler.
namespace {
using cybersand::ChunkCoord;
using cybersand::Material;
using cybersand::RectI64;
using namespace cybersand::generation;
using Prepared = std::shared_ptr<const Generator>;
std::uint64_t assertions = 0;
std::vector<std::string> gates;
std::vector<std::pair<std::string,double>> measurements;

void check(bool value, const std::string& message) {
    ++assertions;
    if (!value) throw std::runtime_error(message);
}
template<class Function> void gate(const std::string& name, Function body) {
    body();
    gates.push_back(name);
}
template<class Function> void rejects(Function body, const std::string& message) {
    bool rejected = false;
    try { body(); } catch (const std::invalid_argument&) { rejected = true; }
    check(rejected, message);
}

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

Recipe recipe(const std::string& id = "megatruss_station", int bay = 64, int floor = 96,
              int wall = 3, std::uint64_t seed = 271828,
              RectI64 bounds = {-2048, -2048, 4096, 4096}) {
    Recipe result;
    result.schema = kArchitecturalSchemaVersion;
    result.candidate = Candidate::Strata;
    result.parameters.surface_y = -100;
    result.chunk_size = 64;
    result.seed = seed;
    result.architecture.automatic_tunnels = false;
    ModuleInstance module;
    module.id = "megatruss-qualification";
    module.module = id;
    module.version = id == "arcade" ? 2U : 1U;
    module.bounds = bounds;
    module.parameters = {{"bay_width",bay},{"floor_height",floor},{"wall",wall},
        {"door_width",10},{"shaft_width",0},{"automatic_doors",1},{"automatic_windows",1},
        {"wall_material",58},{"floor_material",62},{"window_material",121},{"accent_material",65}};
    result.modules.push_back(std::move(module));
    return result;
}

std::vector<Material> raster(const Prepared& generator, RectI64 bounds) {
    std::vector<Material> cells;
    cells.reserve(static_cast<std::size_t>(bounds.width * bounds.height));
    for (std::int64_t y = bounds.y; y < bounds.y + bounds.height; ++y)
        for (std::int64_t x = bounds.x; x < bounds.x + bounds.width; ++x)
            cells.push_back(generator->sample(x, y));
    return cells;
}

std::size_t occupied(const std::vector<Material>& cells) {
    return static_cast<std::size_t>(std::count_if(cells.begin(), cells.end(),
        [](Material material) { return material != Material::Empty; }));
}

void same(const ChunkResult& actual, const ChunkResult& expected, const std::string& label) {
    check(actual.state == ResultState::Ready && expected.state == ResultState::Ready,
        label + ": complete results");
    check(actual.chunk == expected.chunk && actual.chunk_size == expected.chunk_size &&
        actual.cells == expected.cells && actual.content_hash == expected.content_hash &&
        actual.receipt_hash == expected.receipt_hash, label + ": exact materials and receipts");
}

void deterministic_contracts() {
    const auto configured = recipe();
    const auto generator = Generator::compile(configured);
    std::vector<ChunkCoord> chunks;
    std::vector<ChunkResult> reference;
    // 1,024 x 640 includes signed supercells and both sides of x = +/-64.
    for (std::int64_t y = -4; y < 6; ++y)
        for (std::int64_t x = -6; x < 10; ++x) {
            chunks.push_back({x,y});
            reference.push_back(generator->generate(chunks.back()));
            check(reference.back().state == ResultState::Ready, "reference chunk ready");
        }
    gate("same_seed_and_reverse_chunk_order", [&] {
        const auto fresh = Generator::compile(configured);
        for (std::size_t i = chunks.size(); i-- > 0;)
            same(fresh->generate(chunks[i]), reference[i], "fresh reversed request");
    });
    gate("work_slicing_and_zero_budget", [&] {
        for (const auto budget : {std::size_t{1}, std::size_t{7}, std::size_t{31},
                std::size_t{257}, std::size_t{4096}}) {
            for (const auto coordinate : {ChunkCoord{-2,-1}, ChunkCoord{-1,0},
                    ChunkCoord{0,0}, ChunkCoord{1,0}, ChunkCoord{5,1}, ChunkCoord{6,2}}) {
                const auto expected = generator->generate(coordinate);
                auto job = generator->begin(coordinate);
                check(job->advance(0) == ResultState::Pending && job->completed_cells() == 0,
                    "zero budget does not advance or publish");
                while (job->state() == ResultState::Pending) (void)job->advance(budget);
                same(job->result(), expected, "sliced request");
            }
        }
    });
    gate("chunk_partition_and_signed_coordinates", [&] {
        for (const int size : {8,32,64,128,256}) {
            auto partition = configured;
            partition.chunk_size = size;
            const auto alternate = Generator::compile(partition);
            // Multiple sizes cover the same global +/-256 square, including
            // unaligned bay/supercell seams; 8-cell checks target the seams.
            const int range = size == 8 ? 2 : 256 / size;
            for (int cy = -range; cy < range; ++cy)
                for (int cx = -range; cx < range; ++cx) {
                    const auto result = alternate->generate({cx,cy});
                    check(result.state == ResultState::Ready, "partition completes");
                    bool identical = true;
                    for (int y = 0; y < size; ++y)
                        for (int x = 0; x < size; ++x)
                            identical = identical && result.cells[static_cast<std::size_t>(y*size+x)] ==
                                generator->sample(static_cast<std::int64_t>(cx)*size+x,
                                                  static_cast<std::int64_t>(cy)*size+y);
                    check(identical, "native sample equals every partitioned cell");
                }
        }
    });
    gate("bounds_do_not_rephase_station", [&] {
        auto clipped = configured;
        clipped.modules[0].bounds = {-397,-301,1137,817};
        const auto moved_bounds = Generator::compile(clipped);
        check(raster(generator, {-384,-288,1024,768}) ==
              raster(moved_bounds, {-384,-288,1024,768}),
              "identical global cells despite a non-bay-aligned style rectangle");
    });
    gate("parallel_requests_and_cancellation", [&] {
        auto concurrent = std::async(std::launch::async, [generator] { return generator->generate({-1,0}); });
        (void)generator->generate({5,2});
        same(concurrent.get(), generator->generate({-1,0}), "parallel requests");
        auto cancelled = generator->begin({0,0});
        (void)cancelled->advance(17);
        cancelled->cancel();
        check(cancelled->state() == ResultState::Cancelled && cancelled->result().cells.empty() &&
            cancelled->result().receipt_hash == 0, "cancelled work publishes no partial cells");
        auto insufficient = configured;
        insufficient.limits.max_operations_per_chunk = 1;
        const auto failed = Generator::compile(insufficient)->begin({0,0});
        check(failed->state() == ResultState::Failed && failed->completed_cells() == 0 &&
            failed->result().cells.empty(), "logical work budget refuses before raster publication");
    });
    gate("large_signed_coordinate_stability", [&] {
        for (const std::int64_t sign : {-1,1}) {
            const auto origin = sign * (INT64_C(1) << 35);
            auto distant = configured;
            distant.modules[0].bounds = {origin-512,origin-512,1024,1024};
            const auto far = Generator::compile(distant);
            const auto result = far->generate({origin/64,origin/64});
            check(result.state == ResultState::Ready, "distant signed chunk completes");
            bool identical = true;
            for (int y=0; y<64; ++y) for (int x=0; x<64; ++x)
                identical = identical && result.cells[static_cast<std::size_t>(y*64+x)] ==
                    far->sample(origin+x,origin+y);
            check(identical, "distant signed absolute sample identity");
        }
    });
}

void controls_and_seed_programmes() {
    gate("six_seed_programmes_and_negative_space", [&] {
        std::set<std::vector<Material>> signatures;
        for (const std::uint64_t seed : {1,7,42,123,2026,271828}) {
            const auto cells = raster(Generator::compile(recipe("megatruss_station",64,96,3,seed)),
                                      {-384,-288,1152,864});
            const auto mass = occupied(cells);
            check(mass > cells.size()/12 && mass < cells.size()*55/100,
                "every representative seed retains structure and over 45% empty cells");
            signatures.insert(cells);
        }
        check(signatures.size() == 6, "all six fixed-parameter seeds have distinct exact native outputs");
    });
    gate("wall_thickness_controls_mass", [&] {
        const auto thin = raster(Generator::compile(recipe("megatruss_station",64,96,1)), {0,0,768,576});
        const auto thick = raster(Generator::compile(recipe("megatruss_station",64,96,5)), {0,0,768,576});
        check(occupied(thick) > occupied(thin)*3/2, "heavy members materially increase structural mass");
    });
    gate("glazing_toggle_is_local_material_substitution", [&] {
        const auto open_recipe = recipe();
        auto closed_recipe = open_recipe;
        closed_recipe.modules[0].parameters["automatic_windows"] = 0;
        const auto open = raster(Generator::compile(open_recipe), {-384,-288,1152,864});
        const auto closed = raster(Generator::compile(closed_recipe), {-384,-288,1152,864});
        std::size_t glass=0, differences=0;
        bool clean=true;
        for (std::size_t i=0; i<open.size(); ++i) {
            if (open[i] == Material::FrostedGlass) ++glass;
            if (open[i] != closed[i]) {
                ++differences;
                clean = clean && open[i] == Material::FrostedGlass &&
                    closed[i] == Material::ReinforcedConcrete;
            }
        }
        check(glass > 100 && differences == glass && clean,
            "windows-off replaces every glazing cell with shell and changes nothing else");
        check(std::count(closed.begin(), closed.end(), Material::FrostedGlass) == 0,
            "windows-off leaves no glazing");
    });
    gate("portals_toggle_without_rephasing_structure", [&] {
        auto open_recipe = recipe();
        auto shut_recipe = open_recipe;
        shut_recipe.modules[0].parameters["automatic_doors"] = 0;
        const auto open = raster(Generator::compile(open_recipe), {-384,-288,1152,864});
        const auto shut = raster(Generator::compile(shut_recipe), {-384,-288,1152,864});
        std::size_t changed=0;
        bool clean=true;
        for (std::size_t i=0; i<open.size(); ++i) if (open[i] != shut[i]) {
            ++changed;
            clean = clean && open[i] == Material::Empty && shut[i] != Material::Empty;
        }
        check(changed > 100 && clean, "portals-off closes meaningful openings without changing other cells");
    });
    gate("invalid_recipe_and_version_refusal", [&] {
        auto invalid = recipe();
        invalid.modules[0].version = 2;
        rejects([&] { (void)Generator::compile(invalid); }, "only explicit megatruss v1 is admitted");
        invalid = recipe(); invalid.schema = kHierarchySchemaVersion;
        rejects([&] { (void)Generator::compile(invalid); }, "megatruss requires schema 4");
        invalid = recipe(); invalid.modules[0].parameters["wall_material"] = 3;
        rejects([&] { (void)Generator::compile(invalid); }, "moving material is rejected as structural wall");
    });
}

void geometric_hierarchy();

void little_word(std::ostream& out, std::uint64_t value, unsigned width) {
    for (unsigned i=0; i<width; ++i) {
        out.put(static_cast<char>(value & 255U));
        value >>= 8U;
    }
}

void legacy_snapshot(const std::string& path) {
    std::ofstream out(path, std::ios::binary);
    if (!out) throw std::runtime_error("cannot create legacy snapshot");
    out << "CLASSIC72-LE16-v1\n";
    constexpr std::array<int,3> bays{64,96,128}, floors{48,80,96}, walls{2,3,5};
    constexpr std::array<std::uint64_t,3> seeds{7,271828,2026};
    constexpr std::array coordinates{ChunkCoord{-2,-1},ChunkCoord{-1,0},ChunkCoord{0,0},ChunkCoord{3,2}};
    for (const auto id : classic_ids) for (std::size_t fixture=0; fixture<3; ++fixture) {
        auto configured=recipe(id,bays[fixture],floors[fixture],walls[fixture],seeds[fixture],
                               {-256,-256,768,768});
        if (fixture==2) {
            configured.modules[0].parameters["automatic_doors"]=0;
            configured.modules[0].parameters["automatic_windows"]=0;
        }
        const auto generator=Generator::compile(configured);
        little_word(out,generator->fingerprint(),8);
        for (const auto coordinate : coordinates) {
            const auto result=generator->generate(coordinate);
            check(result.state==ResultState::Ready,"legacy comparison fixture completes");
            little_word(out,result.content_hash,8);
            little_word(out,result.receipt_hash,8);
            for (const auto material : result.cells)
                little_word(out,static_cast<std::uint16_t>(material),2);
        }
    }
    check(static_cast<bool>(out),"complete legacy snapshot was written");
    std::cout << "{\"status\":\"pass\",\"modules\":72,\"configurations_per_module\":3,"
                 "\"chunks_per_configuration\":4,\"material_cells\":3538944,"
                 "\"fingerprints_and_receipts_included\":true}\n";
}

void benchmark() {
    using Clock=std::chrono::steady_clock;
    constexpr std::array<const char*,4> ids{"trestle","space_frame","arcade","megatruss_station"};
    std::uint64_t checksum=0;
    std::cout << "{\"benchmark\":\"ordinary-native-generate\",\"warm_trials\":7,"
        "\"warmup_trials\":1,\"trial_order\":\"rotating-module-order\","
        "\"configuration\":{\"seed\":271828,\"bay_width\":64,\"floor_height\":96,"
        "\"wall\":3,\"chunk_size\":64,\"schema\":4,\"wall_material\":58,"
        "\"floor_material\":62,\"window_material\":121,\"accent_material\":65},"
        "\"timed_scope\":\"complete native chunk generation, allocation and content hashing; preparation excluded\","
        "\"results\":[";
    bool comma=false;
    for (const int extent : {512,1024}) {
        std::array<Prepared,4> generators;
        std::array<std::vector<double>,4> times;
        for (std::size_t i=0; i<ids.size(); ++i) generators[i]=Generator::compile(recipe(ids[i]));
        for (std::size_t trial=0; trial<8; ++trial) for (std::size_t turn=0; turn<ids.size(); ++turn) {
            const auto i=(turn+trial)%ids.size(); // rotate first/last trial position
            const auto start=Clock::now();
            for (int y=0; y<extent/64; ++y) for (int x=0; x<extent/64; ++x) {
                const auto result=generators[i]->generate({x,y});
                if (result.state!=ResultState::Ready) throw std::runtime_error("benchmark generation refused");
                checksum = (checksum ^ result.content_hash) * UINT64_C(1099511628211);
            }
            const double elapsed=std::chrono::duration<double,std::milli>(Clock::now()-start).count();
            if (trial>0) times[i].push_back(elapsed);
        }
        for (std::size_t i=0; i<ids.size(); ++i) {
            auto sorted=times[i]; std::sort(sorted.begin(),sorted.end());
            if (comma) std::cout << ',';
            comma=true;
            std::cout << "{\"module\":\"" << ids[i] << "\",\"extent\":" << extent
                << ",\"median_ms\":" << sorted[3] << ",\"min_ms\":" << sorted.front()
                << ",\"max_ms\":" << sorted.back() << ",\"logical_operations_per_cell\":"
                << generators[i]->operations_per_cell() << ",\"trials_ms\":[";
            for (std::size_t j=0; j<times[i].size(); ++j) std::cout << (j?",":"") << times[i][j];
            std::cout << "]}";
        }
    }
    std::cout << "],\"checksum\":" << checksum << "}\n";
}

void geometric_hierarchy() {
    constexpr std::int64_t bay=64, level=96, span=6*bay, height=3*level;
    constexpr std::int64_t top=level/2, bottom=3*level/2, main_deck=5*level/2, wall=3;
    const auto generator=Generator::compile(recipe());
    gate("primary_chords_main_decks_and_transfer_cores", [&] {
        for (const auto seed : {1,7,42,123,2026,271828}) {
            const auto station=Generator::compile(recipe("megatruss_station",64,96,3,
                                                        static_cast<std::uint64_t>(seed)));
            // The same uninterrupted structural datums cross x=-64,+64,
            // 128,192,256,320 and full supercell seams at -384,0,384,768.
            for (const std::int64_t row : {-1,0,1}) for (const auto y : {top,bottom,main_deck}) {
                bool continuous=true;
                for (std::int64_t x=-span; x<=2*span; ++x)
                    continuous=continuous && station->sample(x,row*height+y)!=Material::Empty;
                check(continuous,"full six-bay chord/deck crosses every chunk and supercell boundary");
            }
            for (const std::int64_t column : {-1,0,1,2}) {
                bool continuous=true;
                for (std::int64_t y=-height; y<2*height; ++y)
                    continuous=continuous && station->sample(column*span,y)!=Material::Empty;
                check(continuous,"transfer core extends continuously through all vertical bands");
            }
        }
    });
    gate("three_bay_primary_diagonal_continuity", [&] {
        for (const std::int64_t column : {-1,0,1}) for (const std::int64_t row : {-1,0,1}) {
            bool continuous=true;
            for (std::int64_t x=0; x<=3*bay; ++x) {
                const auto y=top+x*level/(3*bay);
                continuous=continuous && generator->sample(column*span+x,row*height+y)!=Material::Empty;
                continuous=continuous && generator->sample(column*span+span-x,row*height+y)!=Material::Empty;
            }
            check(continuous,"both 192-cell primary diagonals retain material through signed chunk seams");
        }
    });
    gate("protected_station_hall_rectangle", [&] {
        std::int64_t narrowest=span;
        constexpr auto hall_height=main_deck-wall-(bottom+2*wall+1);
        for (const auto seed : {1,7,42,123,2026,271828}) {
            const auto station=Generator::compile(recipe("megatruss_station",64,96,3,
                                                        static_cast<std::uint64_t>(seed)));
            for (const std::int64_t column : {-1,0,1}) {
                std::int64_t run=0,longest=0;
                for (std::int64_t x=0; x<span; ++x) {
                    bool empty=true;
                    for (auto y=bottom+2*wall+1; y<main_deck-wall; ++y)
                        empty=empty && station->sample(column*span+x,y)==Material::Empty;
                    run=empty?run+1:0;
                    longest=std::max(longest,run);
                }
                check(longest>=2*bay,"emitted station contains at least one unobstructed 128x86 hall");
                narrowest=std::min(narrowest,longest);
            }
        }
        measurements.emplace_back("minimum_clear_hall_width",static_cast<double>(narrowest));
        measurements.emplace_back("clear_hall_height",static_cast<double>(hall_height));
    });
    gate("three_spatial_frequencies_and_member_mass", [&] {
        // Measure actual emitted cross-sections at isolated members. The
        // primary diagonal is below the secondary network at this column.
        const auto px=bay+bay/8, py=top+px*level/(3*bay);
        std::int64_t primary_width=1;
        for (auto y=py-1; generator->sample(px,y)==Material::RustedSteel; --y) ++primary_width;
        for (auto y=py+1; generator->sample(px,y)==Material::RustedSteel; ++y) ++primary_width;
        const auto sx=bay+bay/4, sy=top+level/8;
        std::int64_t secondary_width=1;
        for (auto x=sx-1; generator->sample(x,sy)==Material::RustedSteel; --x) ++secondary_width;
        for (auto x=sx+1; generator->sample(x,sy)==Material::RustedSteel; ++x) ++secondary_width;
        check(primary_width>=9 && secondary_width<=4 && primary_width>=3*secondary_width,
            "primary member cross-section is materially heavier than secondary upright");
        for (std::int64_t panel=0; panel<4; ++panel)
            check(generator->sample(bay+panel*(bay/4),sy)==Material::RustedSteel,
                "four emitted secondary posts retain 16-cell pitch inside one 64-cell bay");
        check(generator->sample(2*bay+bay/4,sy)==Material::Empty,
            "central base bays intentionally omit the secondary mesh");
        measurements.emplace_back("supercell_repeat_width",static_cast<double>(span));
        measurements.emplace_back("base_bay_width",static_cast<double>(bay));
        measurements.emplace_back("secondary_panel_pitch",static_cast<double>(bay/4));
        measurements.emplace_back("primary_diagonal_horizontal_run",static_cast<double>(3*bay));
        measurements.emplace_back("primary_member_measured_cells",static_cast<double>(primary_width));
        measurements.emplace_back("secondary_member_measured_cells",static_cast<double>(secondary_width));
    });
    gate("crossed_secondary_even_and_odd_panels", [&] {
        bool saw_crossed=false, saw_warren=false;
        for (std::uint64_t seed=1; seed<=32; ++seed) {
            const auto station=Generator::compile(recipe("megatruss_station",64,96,3,seed));
            // At these points neither primary mega-diagonal/chord nor core
            // can contribute. Probe both arms of adjacent 16-cell panels.
            const bool even_primary=station->sample(69,56)==Material::RustedSteel;
            const bool odd_primary=station->sample(85,64)==Material::RustedSteel;
            const bool even_second=station->sample(69,64)==Material::RustedSteel;
            const bool odd_second=station->sample(85,56)==Material::RustedSteel;
            check(even_primary && odd_primary,"alternating Warren arms exist in both panel parities");
            check(even_second==odd_second,"X programme adds the complementary arm to every panel parity");
            saw_crossed=saw_crossed||even_second;
            saw_warren=saw_warren||!even_second;
        }
        check(saw_crossed && saw_warren,"seed programme selects both Warren and fully crossed networks");
    });
    gate("room_size_moves_macro_support_interval", [&] {
        for (const int width : {48,64,96,128}) {
            const auto station=Generator::compile(recipe("megatruss_station",width));
            bool seam=true, false_seam=false;
            for (std::int64_t y=0; y<height; ++y) {
                seam=seam && station->sample(6*width,y)!=Material::Empty;
                false_seam=false_seam || station->sample(3*width/2,y)==Material::Empty;
            }
            check(seam && false_seam,"room size sets a six-bay macro support period, not one enlarged bay");
        }
        check(raster(Generator::compile(recipe("megatruss_station",48)),{0,0,768,576}) !=
              raster(Generator::compile(recipe("megatruss_station",96)),{0,0,768,576}),
              "room size changes exact macro geometry");
    });
    gate("floor_height_moves_chords_and_deck_hierarchy", [&] {
        for (const int floor : {64,80,96,128}) {
            const auto station=Generator::compile(recipe("megatruss_station",64,floor));
            for (const auto y : {floor/2,3*floor/2,5*floor/2}) {
                bool datum=true;
                for (std::int64_t x=0; x<span; ++x) datum=datum && station->sample(x,y)!=Material::Empty;
                check(datum,"floor height moves each complete primary chord and main deck datum");
            }
        }
        check(raster(Generator::compile(recipe("megatruss_station",64,64)),{0,0,768,576}) !=
              raster(Generator::compile(recipe("megatruss_station",64,128)),{0,0,768,576}),
              "floor height changes exact vertical hierarchy");
        measurements.emplace_back("supercell_height",static_cast<double>(height));
        measurements.emplace_back("upper_chord_y",static_cast<double>(top));
        measurements.emplace_back("lower_chord_y",static_cast<double>(bottom));
        measurements.emplace_back("main_transit_deck_y",static_cast<double>(main_deck));
    });
}
} // namespace

int main(int argc, char** argv) {
    try {
        std::cout << std::setprecision(9);
        if (argc==3 && std::string(argv[1])=="--legacy") { legacy_snapshot(argv[2]); return 0; }
        if (argc==2 && std::string(argv[1])=="--benchmark") { benchmark(); return 0; }
        if (argc!=1) throw std::invalid_argument("usage: test_megatruss_station [--legacy PATH | --benchmark]");
        deterministic_contracts();
        controls_and_seed_programmes();
        geometric_hierarchy();
        std::cout << "{\"status\":\"pass\",\"assertions\":" << assertions << ",\"gates\":[";
        for (std::size_t i=0; i<gates.size(); ++i) std::cout << (i?",":"") << '"' << gates[i] << '"';
        std::cout << "],\"measurements\":{";
        for (std::size_t i=0; i<measurements.size(); ++i)
            std::cout << (i?",":"") << '"' << measurements[i].first << "\":" << measurements[i].second;
        std::cout << "}}\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Megatruss qualification failed after " << assertions << " checks: " << error.what() << '\n';
        return 1;
    }
}
