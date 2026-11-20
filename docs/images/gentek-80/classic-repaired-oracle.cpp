#include "cybersand/world_generation.hpp"
#include <algorithm>
#include <array>
#include <cstdint>
#include <iostream>
#include <set>
#include <stdexcept>
#include <string>
#include <vector>
using cybersand::ChunkCoord;
using cybersand::Material;
using namespace cybersand::generation;
void require(bool b,const std::string& s){if(!b)throw std::runtime_error(s);}
template<class A> void rejects(A&& a,const std::string&s){bool rejected=false;try{a();}catch(const std::exception&){rejected=true;}require(rejected,s);}
void same_cells(const ChunkResult&a,const ChunkResult&b,const std::string&s){require(a.state==ResultState::Ready&&b.state==ResultState::Ready&&a.cells==b.cells&&a.content_hash==b.content_hash,s);}
ModuleInstance instance(std::string id,std::string module,cybersand::RectI64 bounds){ModuleInstance r;r.id=std::move(id);r.module=std::move(module);r.bounds=bounds;return r;}
void classic_architectural_genteks() {
    const std::array<std::string,72> ids{"trestle","stacked_arcade","flying_buttress","sawtooth_gallery","cantilever_spine","rib_vault",
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
        "cascade_terrace","inverted_trestle","cranked_beam","barrel_arcade","buttress_crown","triptych_arcade"};
    std::set<std::vector<Material>> unique;
    std::uint64_t total=UINT64_C(14695981039346656037);
    for (const auto& id : ids) {
        Recipe recipe; recipe.schema=kArchitecturalSchemaVersion; recipe.candidate=Candidate::Strata;
        recipe.parameters.surface_y=-100; recipe.chunk_size=64; recipe.seed=271828;
        auto module=instance("classic",id,{0,0,256,256}); module.version=1;
        module.parameters={{"bay_width",96},{"floor_height",80},{"wall",3},{"door_width",10},
            {"shaft_width",0},{"automatic_doors",1},{"automatic_windows",1},
            {"wall_material",62},{"floor_material",66},{"window_material",121},{"accent_material",114}};
        recipe.modules.push_back(module);
        const auto generator=Generator::compile(recipe);
        std::vector<Material> signature; std::size_t occupied=0;
        std::uint64_t digest=UINT64_C(14695981039346656037);
        for (const auto coord : {ChunkCoord{0,0},ChunkCoord{1,0},ChunkCoord{0,1},ChunkCoord{1,1}}) {
            const auto ready=generator->generate(coord);
            require(ready.state==ResultState::Ready,id+" classic raster ready");
            for (const auto material : ready.cells) { const auto v=static_cast<std::uint16_t>(material);
                for (unsigned b=0;b<2;++b) {total=(total ^ ((v >> (8*b))&255U))*UINT64_C(1099511628211);digest=(digest ^ ((v >> (8*b))&255U))*UINT64_C(1099511628211);}}
            occupied+=static_cast<std::size_t>(std::count_if(ready.cells.begin(),ready.cells.end(),
                [](Material m){return m!=Material::Empty;}));
            signature.insert(signature.end(),ready.cells.begin(),ready.cells.end());
            auto job=generator->begin(coord); while(job->state()==ResultState::Pending)(void)job->advance(31);
            same_cells(job->result(),ready,id+" classic slicing deterministic");
        }
        require(occupied>512 && occupied<4*64*64-512,id+" has structure and negative space");
        unique.insert(std::move(signature));
        std::cout << id << " 0x" << std::hex << digest << std::dec << "\n";
        auto invalid=recipe; invalid.schema=kHierarchySchemaVersion;
        rejects([&]{(void)Generator::compile(invalid);},id+" requires schema 4");
    }
    std::cout << "COMBINED 0x" << std::hex << total << std::dec << "\n";
    require(unique.size()==ids.size(),"seventy-two classic Genteks produce distinct native geometry");
}

int main(){classic_architectural_genteks();}
