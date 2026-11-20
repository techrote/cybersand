// Native material exporter for the Interlaced Viaduct evidence campaign.
// No second geometry implementation: all cells come from GEN-007 chunk jobs.
#define CYBERSAND_INTERLACED_DIAGNOSTICS
#include "../../native/src/world_generation.cpp"

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
std::int64_t export_floor_div(std::int64_t value, std::int64_t divisor) {
    const auto quotient = value / divisor;
    return quotient - (value % divisor < 0 ? 1 : 0);
}
std::string hexadecimal(std::uint64_t value) {
    std::ostringstream out;
    out << std::hex << std::setw(16) << std::setfill('0') << value;
    return out.str();
}
void diagnostic_checks() {
    ModuleInstance instance;
    instance.id="interlaced-layer-test"; instance.module="interlaced_viaduct"; instance.version=1;
    instance.bounds={0,0,512,512};
    instance.parameters={{"bay_width",80},{"floor_height",64},{"wall",3},{"door_width",10},
        {"shaft_width",0},{"automatic_doors",1},{"automatic_windows",1},
        {"wall_material",98},{"floor_material",65},{"window_material",121},{"accent_material",65},{"shaft_material",65}};
    const Parameters parameters{}; const Palette colours{};
    std::set<std::uint64_t> signatures, crossings;
    std::uint64_t assertions=0, primary_min=UINT64_MAX, secondary_min=UINT64_MAX, added_max=0;
    auto check=[&](bool good,const char* message) { ++assertions; if(!good) throw std::runtime_error(message); };
    for (std::uint64_t seed=0;seed<32;++seed) {
        cybersand::generation::InterlacedViaduct sampler(instance,seed);
        auto translated=instance; translated.bounds.x=-517; translated.bounds.y=-263;
        cybersand::generation::InterlacedViaduct shifted(translated,seed);
        std::uint64_t primary=0,secondary=0,added=0,empty=0,hash=14695981039346656037ULL,joint_hash=hash;
        for (std::int64_t y=0;y<384;++y) for(std::int64_t x=0;x<480;++x) {
            const ModuleContext c{x,y,seed,parameters,colours};
            const auto a=sampler.diagnostic_sample(c,1),b=sampler.diagnostic_sample(c,2),both=sampler.diagnostic_sample(c,3);
            const bool aa=a!=Material::Empty,bb=b!=Material::Empty,cc=both!=Material::Empty;
            primary+=static_cast<std::uint64_t>(aa&&!bb&&cc);
            secondary+=static_cast<std::uint64_t>(bb&&!aa&&cc);
            added+=static_cast<std::uint64_t>(!aa&&!bb&&cc);
            empty+=static_cast<std::uint64_t>(!cc);
            hash=(hash^static_cast<std::uint16_t>(both))*1099511628211ULL;
            if (aa&&bb) joint_hash=(joint_hash^static_cast<std::uint64_t>(x+480*y)^static_cast<std::uint16_t>(both))*1099511628211ULL;
            if ((x%17)==0 && (y%13)==0) {
                const ModuleContext moved{x-517,y-263,seed,parameters,colours};
                check(shifted.diagnostic_sample(moved,3)==both,"signed origin changes relative phase");
                check(sampler.sample(c,Material::Empty).value()==both,"production and diagnostic combined diverge");
            }
            if(x%240>80 && x%240<160 && y%192>176)
                check(!cc,"major lower central void was filled");
        }
        check(primary>4000,"primary system contributes too little independent geometry");
        check(secondary>4000,"secondary system contributes too little independent geometry");
        check(added<480*384/20,"crossing collars are unbounded");
        check(empty>480*384/2,"negative space collapsed below one half");
        primary_min=std::min(primary_min,primary);secondary_min=std::min(secondary_min,secondary);added_max=std::max(added_max,added);
        signatures.insert(hash);crossings.insert(joint_hash);
    }
    check(added_max>0,"no collar programme produced additional crossing geometry");
    check(signatures.size()==32,"seed programmes did not vary the composition");
    check(crossings.size()>12,"seed programmes did not vary crossings");
    std::cout<<"{\"status\":\"pass\",\"seeds\":32,\"assertions\":"<<assertions
        <<",\"unique_compositions\":"<<signatures.size()<<",\"unique_crossing_programmes\":"<<crossings.size()
        <<",\"min_primary_only_cells\":"<<primary_min<<",\"min_secondary_only_cells\":"<<secondary_min
        <<",\"max_added_crossing_cells\":"<<added_max<<"}\n";
}
} // namespace

int main(int argc, char** argv) {
    try {
        if (argc == 2 && std::string(argv[1]) == "--check-layers") { diagnostic_checks(); return 0; }
        if (argc != 19) throw std::runtime_error(
            "usage: exporter OUTPUT MODULE VERSION SEED X Y WIDTH HEIGHT BAY FLOOR WALL DOORS WINDOWS SHELL DECK GLAZING ACCENT LAYERS");
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
        module.id = "interlaced-showcase";
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
        const auto layers = static_cast<unsigned>(integer(argv[18]));
        if (layers < 1 || layers > 3) throw std::runtime_error("layers must be 1, 2 or 3");
        const auto prepare_start = std::chrono::steady_clock::now();
        const auto generator = Generator::compile(recipe);
        const auto prepare_us = std::chrono::duration_cast<std::chrono::microseconds>(
            std::chrono::steady_clock::now() - prepare_start).count();
        std::vector<std::uint8_t> cells(static_cast<std::size_t>(width * height));
        std::vector<std::string> receipts;
        std::uint64_t operations = 0;
        std::int64_t native_us = 0;
        const auto start = std::chrono::steady_clock::now();
        for (auto cy = export_floor_div(y0, 64); cy <= export_floor_div(y0 + height - 1, 64); ++cy) {
            for (auto cx = export_floor_div(x0, 64); cx <= export_floor_div(x0 + width - 1, 64); ++cx) {
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
        if (layers != 3) {
            if (name != "interlaced_viaduct") throw std::runtime_error("diagnostic layers only apply to Interlaced Viaduct");
            cybersand::generation::InterlacedViaduct sampler(module, recipe.seed);
            for (std::int64_t y = 0; y < height; ++y) for (std::int64_t x = 0; x < width; ++x) {
                const Palette palette{};
                ModuleContext context{x0 + x, y0 + y, recipe.seed, recipe.parameters, palette};
                cells[static_cast<std::size_t>(y * width + x)] =
                    static_cast<std::uint8_t>(sampler.diagnostic_sample(context, layers));
            }
            receipts.clear(); // Diagnostic ablations are source-layer probes, not GEN-007 chunk receipts.
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
        std::cerr << "Interlaced export failed: " << error.what() << '\n';
        return 1;
    }
}
