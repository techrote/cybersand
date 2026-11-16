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

Recipe recipe(const std::string& id = "interlock_brutalism", int bay = 64, int floor = 64,
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
    gate("bounds_do_not_rephase_showcase", [&] {
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
    gate("32_seed_programmes_and_negative_space", [&] {
        std::set<std::vector<Material>> signatures;
        for (std::uint64_t seed=0; seed<32; ++seed) {
            const auto cells = raster(Generator::compile(recipe("interlock_brutalism",64,64,3,seed)), {0,0,512,512});
            const auto mass=occupied(cells);
            check(mass>cells.size()/20 && mass<cells.size()*65/100,
                "each seed has architecture and at least 35 percent empty cells");
            signatures.insert(cells);
        }
        check(signatures.size()==32,"all 32 consecutive seeds produce distinct native material maps");
    });
    gate("dimensions_and_structural_mass", [&] {
        auto thin_recipe=recipe("interlock_brutalism",64,64,1), heavy_recipe=recipe("interlock_brutalism",64,64,5);
        thin_recipe.modules[0].parameters["automatic_windows"]=0;
        heavy_recipe.modules[0].parameters["automatic_windows"]=0;
        const auto thin=raster(Generator::compile(thin_recipe),{0,0,512,512});
        const auto heavy=raster(Generator::compile(heavy_recipe),{0,0,512,512});
        check(occupied(heavy)>occupied(thin)*6/5,"wall thickness materially increases structural mass");
        const auto ordinary=raster(Generator::compile(recipe()),{0,0,512,512});
        for (const auto& dimensions: {std::pair{48,64},std::pair{96,64},std::pair{64,48},std::pair{64,96}}) {
            const auto changed=raster(Generator::compile(recipe("interlock_brutalism",dimensions.first,dimensions.second)),{0,0,512,512});
            std::size_t difference=0;
            for(std::size_t i=0;i<changed.size();++i) difference+=changed[i]!=ordinary[i]?1U:0U;
            check(difference>10000,"room/floor controls change substantial geometry");
        }
    });
    gate("glazing_toggle_preserves_structure", [&] {
        auto opened=recipe(), disabled=opened;
        disabled.modules[0].parameters["automatic_windows"]=0;
        const auto on=raster(Generator::compile(opened),{0,0,1024,1024});
        const auto off=raster(Generator::compile(disabled),{0,0,1024,1024});
        std::size_t differences=0; bool clean=true;
        for(std::size_t i=0;i<on.size();++i) if(on[i]!=off[i]) {
            ++differences; clean=clean && on[i]==Material::FrostedGlass && off[i]==Material::Empty;
        }
        check(differences>100 && clean,"windows only fill existing apertures with glass");
        check(std::count(off.begin(),off.end(),Material::FrostedGlass)==0,"off means no residual glass");
    });
    gate("door_controls_are_local_openings", [&] {
        auto opened=recipe(), disabled=opened;
        disabled.modules[0].parameters["automatic_doors"]=0;
        const auto on=raster(Generator::compile(opened),{0,0,1024,1024});
        const auto off=raster(Generator::compile(disabled),{0,0,1024,1024});
        std::size_t differences=0; bool clean=true;
        for(std::size_t i=0;i<on.size();++i) if(on[i]!=off[i]) {
            ++differences; clean=clean && on[i]==Material::Empty && off[i]!=Material::Empty;
        }
        check(differences>100 && clean,"doors change meaningful openings and no other cells");
    });
    gate("schema_version_and_minimum_clearance", [&] {
        auto invalid=recipe(); invalid.modules[0].version=2;
        rejects([&]{(void)Generator::compile(invalid);},"v1 is the only admitted identity");
        invalid=recipe(); invalid.schema=kHierarchySchemaVersion;
        rejects([&]{(void)Generator::compile(invalid);},"schema4 required");
        invalid=recipe(); invalid.modules[0].parameters["bay_width"]=31;
        rejects([&]{(void)Generator::compile(invalid);},"small rooms refused with clearance reason");
        invalid=recipe(); invalid.modules[0].parameters["floor_height"]=31;
        rejects([&]{(void)Generator::compile(invalid);},"short floors refused with clearance reason");
    });
}

// Flood fills inspect real native output. They never redraw expected geometry.
std::vector<unsigned char> reachable(const std::vector<Material>& cells, int width, int height,
                                     const std::vector<std::size_t>& starts, bool empty) {
    std::vector<unsigned char> seen(cells.size()); std::vector<std::size_t> work;
    for(const auto i:starts) if((cells[i]==Material::Empty)==empty && !seen[i]) {seen[i]=1;work.push_back(i);}
    for(std::size_t k=0;k<work.size();++k) {
        const auto i=work[k]; const int x=static_cast<int>(i%static_cast<std::size_t>(width));
        const int y=static_cast<int>(i/static_cast<std::size_t>(width));
        for(int dy=-1;dy<=1;++dy) for(int dx=-1;dx<=1;++dx) {
            if((dx==0 && dy==0) || (empty && dx!=0 && dy!=0)) continue;
            const int nx=x+dx,ny=y+dy;
            if(nx<0||ny<0||nx>=width||ny>=height) continue;
            const auto n=static_cast<std::size_t>(ny*width+nx);
            if(!seen[n] && (cells[n]==Material::Empty)==empty) {seen[n]=1;work.push_back(n);}
        }
    }
    return seen;
}
void little_word(std::ostream& out, std::uint64_t value, unsigned width) {
    for (unsigned i=0; i<width; ++i) {
        out.put(static_cast<char>(value & 255U));
        value >>= 8U;
    }
}

void legacy_snapshot(const std::string& path) {
    std::ofstream out(path, std::ios::binary);
    if (!out) throw std::runtime_error("cannot create legacy snapshot");
    out << "CLASSIC74-LE16-v1\n";
    std::vector<std::string> legacy_ids(classic_ids.begin(),classic_ids.end());
    legacy_ids.push_back("arcade"); legacy_ids.push_back("arcade");
    constexpr std::array<int,3> bays{64,96,128}, floors{48,80,96}, walls{2,3,5};
    constexpr std::array<std::uint64_t,3> seeds{7,271828,2026};
    constexpr std::array coordinates{ChunkCoord{-2,-1},ChunkCoord{-1,0},ChunkCoord{0,0},ChunkCoord{3,2}};
    for (std::size_t module_index=0;module_index<legacy_ids.size();++module_index) for (std::size_t fixture=0; fixture<3; ++fixture) {
        auto configured=recipe(legacy_ids[module_index],bays[fixture],floors[fixture],walls[fixture],seeds[fixture],
                               {-256,-256,768,768});
        if(module_index==72) configured.modules[0].version=1;
        if(module_index==73) configured.modules[0].version=2;
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
    std::cout << "{\"status\":\"pass\",\"modules\":74,\"configurations_per_module\":3,"
                 "\"chunks_per_configuration\":4,\"material_cells\":3637248,"
                 "\"fingerprints_and_receipts_included\":true}\n";
}

void benchmark() {
    using Clock=std::chrono::steady_clock;
    constexpr std::array<const char*,4> ids{"cantilever_spine","double_cantilever","shelf_stack","interlock_brutalism"};
    std::uint64_t checksum=0;
    std::cout << "{\"benchmark\":\"ordinary-native-generate\",\"warm_trials\":7,"
        "\"warmup_trials\":1,\"trial_order\":\"rotating-module-order\","
        "\"configuration\":{\"seed\":271828,\"bay_width\":64,\"floor_height\":64,"
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
    gate("admitted_parameter_corner_support", [&] {
        for(const auto& size: {std::pair{32,32},std::pair{33,65},std::pair{65,33},std::pair{80,72}})
        for(std::uint64_t seed=0;seed<4;++seed) {
            const int width=4*size.first,height=6*size.second;
            auto r=recipe("interlock_brutalism",size.first,size.second,5,seed);
            r.modules[0].parameters["automatic_windows"]=0;
            const auto cells=raster(Generator::compile(r),{0,0,width,height});
            std::vector<std::size_t> roots;
            for(int y=0;y<height;++y){roots.push_back(static_cast<std::size_t>(y*width));roots.push_back(static_cast<std::size_t>(y*width+width-1));}
            const auto supported=reachable(cells,width,height,roots,false);
            bool all=true;for(std::size_t i=0;i<cells.size();++i)all=all&&(cells[i]==Material::Empty||supported[i]);
            check(all,"minimum/odd/heavy geometry retains real material support paths");
            check(occupied(cells)>cells.size()/20&&occupied(cells)<cells.size()*4/5,"parameter corners keep structure and void");
        }
    });
    gate("rooted_projections_and_bounded_bridge_programmes", [&] {
        int verified_bridges=0;
        for(std::uint64_t seed=0;seed<32;++seed) for(const int wall:{1,5}) {
            const int width=256,height=384;
            auto r=recipe("interlock_brutalism",64,64,wall,seed);
            r.modules[0].parameters["automatic_windows"]=0;
            const auto cells=raster(Generator::compile(r),{0,0,width,height});
            std::vector<std::size_t> roots;
            for(int y=0;y<height;++y){roots.push_back(static_cast<std::size_t>(y*width));roots.push_back(static_cast<std::size_t>(y*width+width-1));}
            const auto supported=reachable(cells,width,height,roots,false);
            bool all=true;for(std::size_t i=0;i<cells.size();++i)all=all&&(cells[i]==Material::Empty||supported[i]);
            check(all,"every solid projection has an eight-connected material root in a core");
            std::size_t empty=0;int sealed=0;
            for(int y=0;y<height;++y){bool full=true;for(int x=48;x<208;++x){const bool air=cells[static_cast<std::size_t>(y*width+x)]==Material::Empty;empty+=air?1U:0U;full=full&&!air;}sealed+=full?1:0;}
            check(empty>static_cast<std::size_t>(160*height/2),"central void retains more than half empty cells at thin/heavy settings");
            check(sealed<=2*wall,"no more than one narrow shared bridge seals a chamber row");
            // A connected open region must span at least two floors, including heavy settings.
            bool substantial_region=false;std::vector<unsigned char> visited(cells.size());
            for(int y=0;y<height;++y)for(int x=48;x<208;++x){const auto i=static_cast<std::size_t>(y*width+x);if(visited[i]||cells[i]!=Material::Empty)continue;
                const auto region=reachable(cells,width,height,{i},true);int lo=height,hi=0;std::size_t count=0;
                for(std::size_t n=0;n<region.size();++n)if(region[n]){visited[n]=1;++count;const int ry=static_cast<int>(n/static_cast<std::size_t>(width));lo=std::min(lo,ry);hi=std::max(hi,ry);}
                substantial_region=substantial_region || (hi-lo+1>=128 && count>static_cast<std::size_t>(width*height/5));
            }
            check(substantial_region,"one connected chamber satisfies both the two-floor span and substantial area");
            // Identify inner full-height core columns from emitted cells, without
            // asking the private seed programme where it placed either core.
            int left_edge=0,right_edge=width-1;
            for(int x=0;x<width;++x) if(x<64 || x>=192) {
                bool continuous=true;
                for(int y=0;y<height;++y)continuous=continuous && cells[static_cast<std::size_t>(y*width+x)]!=Material::Empty;
                if(continuous && x<64)left_edge=x;
                if(continuous && x>=192)right_edge=std::min(right_edge,x);
            }
            int selected=0;
            for(const int band:{3,4}) {
                const int y0=band*64+32;
                // These two probes lie beyond either single cantilever's reach.
                const bool connection=cells[static_cast<std::size_t>(y0*width+80)]!=Material::Empty &&
                    cells[static_cast<std::size_t>(y0*width+176)]!=Material::Empty;
                if(!connection)continue;
                ++selected;++verified_bridges;bool joined=true;
                for(int y=y0;y<y0+2*wall;++y)for(int x=left_edge;x<=right_edge;++x)
                    joined=joined && cells[static_cast<std::size_t>(y*width+x)]!=Material::Empty;
                check(joined,"selected bridge has uninterrupted material to both independently detected core endpoints");
            }
            check(selected<=1,"at most one complete bridge programme per chamber");
        }
        check(verified_bridges>=8,"endpoint qualification exercised many bridge-bearing seeds at both thicknesses");
        measurements.emplace_back("bridge_programmes_verified",verified_bridges);
    });
}

} // namespace

int main(int argc, char** argv) {
    try {
        std::cout << std::setprecision(9);
        if (argc==3 && std::string(argv[1])=="--legacy") { legacy_snapshot(argv[2]); return 0; }
        if (argc==2 && std::string(argv[1])=="--benchmark") { benchmark(); return 0; }
        if (argc!=1) throw std::invalid_argument("usage: test_interlock_brutalism [--legacy PATH | --benchmark]");
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
        std::cerr << "Interlock Brutalism qualification failed after " << assertions << " checks: " << error.what() << '\n';
        return 1;
    }
}
