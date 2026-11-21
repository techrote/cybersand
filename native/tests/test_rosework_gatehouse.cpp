#include "cybersand/world_generation.hpp"

#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <queue>
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

Recipe recipe(const std::string& id = "rosework_gatehouse", int bay = 128, int floor = 80,
              int wall = 3, std::uint64_t seed = 271828,
              RectI64 bounds = {-512, -480, 4096, 3840}) {
    Recipe result;
    result.schema = kArchitecturalSchemaVersion;
    result.candidate = Candidate::Strata;
    result.parameters.surface_y = -100;
    result.chunk_size = 64;
    result.seed = seed;
    result.architecture.automatic_tunnels = false;
    ModuleInstance module;
    module.id = "rosework-qualification";
    module.module = id;
    module.version = id == "arcade" ? 2U : 1U;
    module.bounds = bounds;
    module.parameters = {{"bay_width",bay},{"floor_height",floor},{"wall",wall},
        {"door_width",10},{"shaft_width",0},{"automatic_doors",1},{"automatic_windows",1},
        {"wall_material",100},{"floor_material",119},{"window_material",55},{"accent_material",119}};
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
            // The public maximum 256-cell chunk needs a correspondingly explicit
            // work budget for this twelve-lens sampler; no limit is bypassed.
            partition.limits.max_operations_per_chunk = 1000000000;
            const auto alternate = Generator::compile(partition);
            // Multiple sizes cover the same global +/-256 square, including
            // unaligned bay/supercell seams; 8-cell checks target the seams.
            const int range = size == 8 ? 2 : 256 / size;
            for (int cy = -range; cy < range; ++cy)
                for (int cx = -range; cx < range; ++cx) {
                    const auto result = alternate->generate({cx,cy});
                    check(result.state == ResultState::Ready, "partition completes: "+result.error);
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
    gate("module_local_geometry_is_translation_equivariant", [&] {
        auto first=recipe("rosework_gatehouse",128,80,3,271828,{0,0,1024,1024});
        auto shifted=first;
        shifted.modules[0].bounds={-397,-301,1024,1024};
        check(raster(Generator::compile(first),{0,0,1024,1024}) ==
              raster(Generator::compile(shifted),{-397,-301,1024,1024}),
              "negative unaligned module origin preserves every module-relative cell");
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
    gate("thirty_two_seed_programmes_and_negative_space", [&] {
        std::set<std::vector<Material>> signatures;
        for (std::uint64_t seed=1;seed<=32;++seed) {
            const auto cells=raster(Generator::compile(recipe("rosework_gatehouse",128,80,3,seed,{0,0,1024,512})),{0,0,1024,512});
            const auto mass=occupied(cells);
            check(mass>cells.size()/8 && mass<cells.size()*65/100,
                "all 32 seeds contain substantial architecture and at least 35% negative space");
            signatures.insert(cells);
        }
        check(signatures.size()>=16,"macro choices vary over at least sixteen of the 32 fixed-parameter outputs");
        measurements.emplace_back("unique_seed_maps",static_cast<double>(signatures.size()));
    });
    gate("wall_room_and_floor_controls", [&] {
        const auto render=[](int bay,int floor,int wall) {
            return raster(Generator::compile(recipe("rosework_gatehouse",bay,floor,wall,271828,{0,0,1024,1024})),{0,0,1024,1024});
        };
        const auto thin=render(128,80,1),heavy=render(128,80,5);
        check(occupied(heavy)>occupied(thin)*11/10,"thicker walls materially increase mass");
        check(render(80,80,3)!=render(160,80,3),"room size changes gatehouse and radial diameter");
        check(render(128,56,3)!=render(128,112,3),"floor height changes tower/rose elevation");
        measurements.emplace_back("thin_occupied_cells",static_cast<double>(occupied(thin)));
        measurements.emplace_back("heavy_occupied_cells",static_cast<double>(occupied(heavy)));
    });
    gate("glazing_toggle_only_affects_petal_infill", [&] {
        auto open_recipe=recipe("rosework_gatehouse",128,80,3,271828,{0,0,1024,1024});
        auto clear_recipe=open_recipe; clear_recipe.modules[0].parameters["automatic_windows"]=0;
        const auto open=raster(Generator::compile(open_recipe),{0,0,1024,1024});
        const auto clear=raster(Generator::compile(clear_recipe),{0,0,1024,1024});
        std::size_t glass=0,differences=0;
        for (std::size_t i=0;i<open.size();++i) {
            if (open[i]==Material::StainedGlass) ++glass;
            if (open[i]!=clear[i]) {
                ++differences;
                check(open[i]==Material::StainedGlass && clear[i]==Material::Empty,
                    "windows affect only empty-versus-glazed petal cells");
            }
        }
        check(glass>1000 && differences==glass,"all meaningful glazing disappears when disabled");
        check(std::count(clear.begin(),clear.end(),Material::StainedGlass)==0,"no glass remains with windows off");
        measurements.emplace_back("glazing_cells",static_cast<double>(glass));
    });
    gate("side_door_toggle_preserves_permanent_major_portal", [&] {
        auto open_recipe=recipe("rosework_gatehouse",128,80,3,271828,{0,0,512,512});
        auto shut_recipe=open_recipe; shut_recipe.modules[0].parameters["automatic_doors"]=0;
        const auto open=raster(Generator::compile(open_recipe),{0,0,512,512});
        const auto shut=raster(Generator::compile(shut_recipe),{0,0,512,512});
        std::size_t changed=0;
        for (std::size_t i=0;i<open.size();++i) if (open[i]!=shut[i]) {
            ++changed; check(open[i]==Material::Empty && shut[i]!=Material::Empty,"side doors close without changing other cells");
        }
        check(changed>500,"side portals are meaningful apertures");
        for (std::size_t y=310;y<470;++y) for (std::size_t x=240;x<272;++x)
            check(open[y*512+x]==Material::Empty && shut[y*512+x]==Material::Empty,"main gate never closes with doors off");
    });
    gate("schema_version_clearance_and_material_refusal", [&] {
        auto invalid=recipe(); invalid.modules[0].version=2;
        rejects([&]{(void)Generator::compile(invalid);},"rosework v2 is not admitted");
        invalid=recipe(); invalid.schema=kHierarchySchemaVersion;
        rejects([&]{(void)Generator::compile(invalid);},"rosework requires schema 4");
        invalid=recipe(); invalid.modules[0].parameters["wall_material"]=3;
        rejects([&]{(void)Generator::compile(invalid);},"moving structural material rejected");
        invalid=recipe(); invalid.modules[0].parameters["bay_width"]=32;
        rejects([&]{(void)Generator::compile(invalid);},"too-small radial diameter clearly refused");
        invalid=recipe(); invalid.modules[0].parameters["floor_height"]=24;
        rejects([&]{(void)Generator::compile(invalid);},"too-short tower/rose clearance clearly refused");
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
    constexpr std::array<const char*,4> ids{"pointed_arcade","drum_vault","arcade","rosework_gatehouse"};
    std::uint64_t checksum=0;
    std::cout << "{\"benchmark\":\"ordinary-native-generate\",\"warm_trials\":7,"
        "\"warmup_trials\":1,\"trial_order\":\"rotating-module-order\","
        "\"configuration\":{\"seed\":271828,\"bay_width\":128,\"floor_height\":80,"
        "\"wall\":3,\"chunk_size\":64,\"schema\":4,\"wall_material\":100,"
        "\"floor_material\":119,\"window_material\":55,\"accent_material\":119},"
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
    std::set<int> observed_counts;
    std::size_t total_petals=0;
    for (std::uint64_t seed=1;seed<=32;++seed) {
        auto configured=recipe("rosework_gatehouse",128,80,3,seed,{0,0,1024,1024});
        configured.modules[0].parameters["automatic_windows"]=0;
        const auto generator=Generator::compile(configured);
        const auto cell=[&](int x,int y){return generator->sample(x,y);};
        gate("closed_radial_bands_seed_"+std::to_string(seed),[&] {
            for (const int radius : {21,106,128}) {
                for (int y=-radius-1;y<=radius+1;++y) for (int x=-radius-1;x<=radius+1;++x) {
                    const int squared=x*x+y*y;
                    if (squared>=(radius-1)*(radius-1) && squared<=(radius+1)*(radius+1))
                        check(cell(256+x,160+y)!=Material::Empty,"closed circular band survives the integer grid and chunk seams");
                }
            }
        });
        gate("spokes_reach_rings_seed_"+std::to_string(seed),[&] {
            // Independently walk a circle between main and outer rings. Count
            // contiguous occupied angular runs, then trace each ray inward.
            constexpr int steps=1440;
            std::array<bool,steps> trace{};
            for (int i=0;i<steps;++i) {
                const auto angle=6.283185307179586*static_cast<double>(i)/steps;
                const auto x=static_cast<int>(std::lround(std::cos(angle)*115.0));
                const auto y=static_cast<int>(std::lround(std::sin(angle)*115.0));
                trace[static_cast<std::size_t>(i)]=cell(256+x,160+y)!=Material::Empty;
            }
            int count=0;
            for (int i=0;i<steps;++i) if (trace[static_cast<std::size_t>(i)] && !trace[static_cast<std::size_t>((i+steps-1)%steps)]) ++count;
            check(count==6 || count==8 || count==12,"native circular cross-section contains an approved spoke count");
            observed_counts.insert(count);
            for (int n=0;n<count;++n) {
                const auto angle=6.283185307179586*static_cast<double>(n)/count;
                for (int r=23;r<128;++r) {
                    const auto x=static_cast<int>(std::lround(std::cos(angle)*r));
                    const auto y=static_cast<int>(std::lround(std::sin(angle)*r));
                    check(cell(256+x,160+y)!=Material::Empty,"every spoke joins hub through main ring to outer ring");
                }
            }
        });
        gate("connected_tracery_seed_"+std::to_string(seed),[&] {
            constexpr int side=267,origin=133;
            std::vector<unsigned char> solid(static_cast<std::size_t>(side*side)),visited(solid.size());
            std::size_t total=0;
            for (int y=-origin;y<=origin;++y) for (int x=-origin;x<=origin;++x) {
                const auto index=static_cast<std::size_t>((y+origin)*side+x+origin);
                if (x*x+y*y<=origin*origin && cell(256+x,160+y)!=Material::Empty) {
                    solid[index]=1; ++total;
                }
            }
            std::vector<std::size_t> queue{static_cast<std::size_t>(origin*side+origin+128)};
            visited[queue.front()]=1;
            for (std::size_t at=0;at<queue.size();++at) {
                const auto x=static_cast<int>(queue[at]%side),y=static_cast<int>(queue[at]/side);
                for (int oy=-1;oy<=1;++oy) for (int ox=-1;ox<=1;++ox) {
                    const int nx=x+ox,ny=y+oy;
                    if (nx<0 || ny<0 || nx>=side || ny>=side) continue;
                    const auto next=static_cast<std::size_t>(ny*side+nx);
                    if (solid[next] && !visited[next]) { visited[next]=1; queue.push_back(next); }
                }
            }
            check(queue.size()==total,"every petal outline, ray and ring belongs to one eight-connected native structure");
        });
        gate("petal_voids_and_structural_roots_seed_"+std::to_string(seed),[&] {
            std::size_t empty=0,inner=0;
            for (int y=-105;y<=105;++y) for (int x=-105;x<=105;++x) {
                if (x*x+y*y<24*24 || x*x+y*y>104*104) continue;
                ++inner; if (cell(256+x,160+y)==Material::Empty) ++empty;
            }
            check(empty>inner*65/100,"petal field retains at least 65 percent real empty cells with glazing off");
            total_petals+=empty;
            for (int x=92;x<=128;++x) check(cell(x,160)!=Material::Empty,"left ring has an unbroken transfer to tower");
            for (int x=384;x<=420;++x) check(cell(x,160)!=Material::Empty,"right ring has an unbroken transfer to tower");
            for (int y=305;y<470;++y) check(cell(256,y)==Material::Empty,"the large gate opens directly below the rose");
            check(cell(256,288)!=Material::Empty && cell(256,292)!=Material::Empty && cell(256,296)!=Material::Empty,
                "rose bottom and gate crown share actual native material support");
        });
    }
    check(observed_counts==std::set<int>{6,8,12},"all three approved spoke counts appear in the 32-seed survey");
    measurements.emplace_back("approved_spoke_programmes",static_cast<double>(observed_counts.size()));
    measurements.emplace_back("petal_field_empty_cells_over_32_seeds",static_cast<double>(total_petals));
}

void viaduct_snapshot(const std::string& path) {
    std::ofstream out(path,std::ios::binary);
    out << "VIADUCT-V1-V2-LE16-v1\n";
    for (unsigned version : {1U,2U}) for (std::uint64_t seed : {7,271828,2026}) {
        auto configured=recipe("arcade",96,80,3,seed,{-256,-256,768,768});
        configured.modules[0].version=version;
        const auto generator=Generator::compile(configured);
        little_word(out,generator->fingerprint(),8);
        for (const auto coord : {ChunkCoord{-2,-1},ChunkCoord{-1,0},ChunkCoord{0,0},ChunkCoord{3,2}}) {
            const auto result=generator->generate(coord);
            check(result.state==ResultState::Ready,"Viaduct comparison completes");
            little_word(out,result.content_hash,8); little_word(out,result.receipt_hash,8);
            for (const auto material:result.cells) little_word(out,static_cast<std::uint16_t>(material),2);
        }
    }
    check(static_cast<bool>(out),"complete Viaduct snapshot written");
    std::cout << "{\"status\":\"pass\",\"versions\":[1,2],\"material_cells\":98304}\n";
}
} // namespace

int main(int argc, char** argv) {
    try {
        std::cout << std::setprecision(9);
        if (argc==3 && std::string(argv[1])=="--viaduct") { viaduct_snapshot(argv[2]); return 0; }
        if (argc==3 && std::string(argv[1])=="--legacy") { legacy_snapshot(argv[2]); return 0; }
        if (argc==2 && std::string(argv[1])=="--benchmark") { benchmark(); return 0; }
        if (argc!=1) throw std::invalid_argument("usage: test_rosework_gatehouse [--legacy PATH | --viaduct PATH | --benchmark]");
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
        std::cerr << "Rosework qualification failed after " << assertions << " checks: " << error.what() << '\n';
        return 1;
    }
}
