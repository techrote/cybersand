// #292 regression: extreme signed-coordinate material/RGBA copy, C ABI, pads.
// Run each case in a separate process under UBSan's halt_on_error=1.
// This file is additive to native/tests and does not change physics/defaults.
#include "cybersand/world.hpp"
#include "cybersand/c_api.h"
#include "cybersand/material_rules.hpp"
#include <algorithm>
#include <array>
#include <cstdint>
#include <exception>
#include <functional>
#include <iostream>
#include <limits>
#include <memory>
#include <span>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace {
using cybersand::World;
using cybersand::Material;
using cybersand::RectI64;
constexpr std::int64_t kMax=std::numeric_limits<std::int64_t>::max();
constexpr std::int64_t kMin=std::numeric_limits<std::int64_t>::min();
constexpr std::uint8_t kGuard=0xAB;

void need(bool passed, const std::string& reason) {
    if (!passed) throw std::runtime_error(reason);
}
template<class Fn>
void expect_overflow(Fn&& call,const std::string& scenario) {
    bool refused=false;
    try { call(); }
    catch(const std::overflow_error&) { refused=true; }
    need(refused, scenario+": an impossible signed endpoint did not throw overflow_error");
}
template<class T,std::size_t N>
void untouched(const std::array<T,N>& data,const std::string& context) {
    need(std::all_of(data.begin(),data.end(),[](T x){return x==static_cast<T>(kGuard);}),
         context+": copy wrote destination bytes before refusing");
}
auto make_c_world() {
    using Pointer=std::unique_ptr<cybersand_world,decltype(&cybersand_world_destroy)>;
    Pointer world(cybersand_world_create(cybersand_config{16,3,200}),&cybersand_world_destroy);
    need(world!=nullptr,"C API create failed");
    return world;
}
void run(const std::string& mode) {
    World world;
    if (mode=="material-max1" || mode=="material-ymax1") {
        std::array<std::uint8_t,2> bytes{kGuard,kGuard};
        const RectI64 rect=mode=="material-max1" ? RectI64{kMax,0,1,1} :
                              RectI64{0,kMax,1,1};
        world.copy_material_cells(rect,bytes,2);
        need(bytes[0]==0 && bytes[1]==kGuard,"valid final included material cell / padding");
    } else if (mode=="material-max2" || mode=="material-ymax2") {
        std::array<std::uint8_t,4> bytes;bytes.fill(kGuard);
        const RectI64 rect=mode=="material-max2" ? RectI64{kMax,0,2,1} :
                              RectI64{0,kMax,1,2};
        expect_overflow([&]{world.copy_material_cells(rect,bytes,2);},mode);
        untouched(bytes,mode);
    } else if (mode=="rgba-max1" || mode=="rgba-ymax1") {
        std::array<std::uint8_t,8> bytes;bytes.fill(kGuard);
        std::array<std::uint8_t,4> empty{};
        world.copy_rgba({0,0,1,1},empty,4);
        const RectI64 rect=mode=="rgba-max1"?RectI64{kMax,0,1,1} :
                              RectI64{0,kMax,1,1};
        world.copy_rgba(rect,bytes,8);
        need(std::equal(empty.begin(),empty.end(),bytes.begin()),
             "valid last included RGBA copy must be same Empty descriptor");
        need(std::all_of(bytes.begin()+4,bytes.end(),
                         [](std::uint8_t v){return v==kGuard;}),
             "RGBA copy modified the stride/padding");
    } else if (mode=="rgba-max2" || mode=="rgba-ymax2") {
        std::array<std::uint8_t,16> bytes;bytes.fill(kGuard);
        const RectI64 rect=mode=="rgba-max2"?RectI64{kMax,0,2,1} :
                              RectI64{0,kMax,1,2};
        expect_overflow([&]{world.copy_rgba(rect,bytes,8);},mode);
        untouched(bytes,mode);
    } else if (mode=="cabi-max1" || mode=="cabi-ymax1" ||
               mode=="cabi-max2" || mode=="cabi-ymax2") {
        auto owner=make_c_world();
        std::array<std::uint8_t,16> bytes;bytes.fill(kGuard);
        const bool invalid=mode=="cabi-max2" || mode=="cabi-ymax2";
        const auto x=(mode=="cabi-max1" || mode=="cabi-max2") ? kMax : 0;
        const auto y=(mode=="cabi-ymax1" || mode=="cabi-ymax2") ? kMax : 0;
        const auto width=mode=="cabi-max2"?2:1;
        const auto height=mode=="cabi-ymax2"?2:1;
        const int ok=cybersand_world_copy_rgba(owner.get(),x,y,width,height,
                                               bytes.data(),bytes.size(),8);
        need(ok==(invalid?0:1),"C ABI return code mismatched extreme region admission");
        if (invalid) untouched(bytes,mode);
        else need(bytes[4]==kGuard,"C ABI valid copy touched row padding");
    } else if(mode=="min2") {
        // INT64_MIN is legal; a valid last included coordinate must not
        // overflow or clip while indexing negative chunks.
        std::array<std::uint8_t,6> mat;mat.fill(kGuard);
        std::array<std::uint8_t,20> rgba;rgba.fill(kGuard);
        world.copy_material_cells({kMin,kMin,2,2},mat,3);
        world.copy_rgba({kMin,kMin,2,2},rgba,12);
        need(mat[0]==0 && mat[1]==0 && mat[2]==kGuard &&
             mat[3]==0 && mat[4]==0 && mat[5]==kGuard,
             "INT64_MIN material copy or padding mismatch");
        need(rgba[8]==kGuard && rgba[9]==kGuard && rgba[10]==kGuard &&
             rgba[11]==kGuard, "INT64_MIN RGBA padding modified");
    } else if(mode=="zero") {
        std::array<std::uint8_t,8> bytes;bytes.fill(kGuard);
        world.copy_material_cells({kMax,kMax,0,2},bytes,0);
        world.copy_material_cells({kMax,kMax,2,0},bytes,2);
        world.copy_rgba({kMax,kMax,0,2},bytes,0);
        world.copy_rgba({kMax,kMax,2,0},bytes,8);
        untouched(bytes,mode);
        auto owner=make_c_world();
        need(cybersand_world_copy_rgba(owner.get(),kMax,kMax,0,2,
             bytes.data(),bytes.size(),0)==1,"C API zero width must succeed");
        need(cybersand_world_copy_rgba(owner.get(),kMax,kMax,2,0,
             bytes.data(),bytes.size(),8)==1,"C API zero height must succeed");
        untouched(bytes,mode);
    } else if(mode=="pad-and-projection") {
        world.set(0,0,Material::Sand);
        world.set(1,1,Material::Water);
        std::array<std::uint8_t,6> mat;mat.fill(kGuard);
        std::array<std::uint8_t,12> cells;cells.fill(kGuard);
        std::array<std::uint8_t,20> rgba;rgba.fill(kGuard);
        world.copy_material_cells({0,0,2,2},mat,3);
        world.copy_render_cells({0,0,2,2},cells,6);
        world.copy_rgba({0,0,2,2},rgba,12);
        need(mat[0]==static_cast<std::uint8_t>(Material::Sand),
             "Sand native material byte missing");
        for(int y=0;y<2;++y)for(int x=0;x<2;++x)
            need(mat[static_cast<std::size_t>(y*3+x)]==
                 cells[static_cast<std::size_t>(y*6+x*2)],
                 "display projection diverges from canonical 2-byte render cells");
        need(mat[2]==kGuard && mat[5]==kGuard &&
             cells[4]==kGuard && cells[5]==kGuard &&
             cells[10]==kGuard && cells[11]==kGuard &&
             rgba[8]==kGuard && rgba[9]==kGuard &&
             rgba[10]==kGuard && rgba[11]==kGuard,
             "padding overwritten by ordinary copy");
        const auto colour=cybersand::MaterialRules::descriptor(Material::Sand).rgba;
        need(std::equal(colour.begin(),colour.end(),rgba.begin()),
             "RGBA palette for resident Sand changed");
    } else if(mode=="negative-extent") {
        std::array<std::uint8_t,8> bytes;bytes.fill(kGuard);
        bool refused1=false,refused2=false;
        try { world.copy_material_cells({0,0,-1,1},bytes,2); }
        catch(const std::invalid_argument&){refused1=true;}
        try { world.copy_rgba({0,0,1,-1},bytes,4); }
        catch(const std::invalid_argument&){refused2=true;}
        need(refused1 && refused2,"negative copy extent must refuse");
        untouched(bytes,mode);
    } else if(mode=="render-control") {
        std::array<std::uint8_t,4> bytes;bytes.fill(kGuard);
        world.copy_render_cells({kMax,0,1,1},bytes,4);
        need(bytes[0]==0 && bytes[1]==0 && bytes[2]==kGuard && bytes[3]==kGuard,
             "existing render control at last signed coordinate failed");
        bytes.fill(kGuard);
        expect_overflow([&]{world.copy_render_cells({kMax,0,2,1},bytes,4);},mode);
        untouched(bytes,mode);
    } else throw std::invalid_argument("unknown fixture: "+mode);
}

} // namespace

int main(int argc,char** argv) {
    if(argc!=2){std::cerr<<"expected one test case\n";return 2;}
    try {
        run(argv[1]);
        std::cout<<"COPY_EXTREME_PASS case="<<argv[1]<<"\n";
        return 0;
    } catch(const std::exception& e) {
        std::cerr<<"COPY_EXTREME_FAIL case="<<argv[1]<<" reason="<<e.what()<<"\n";
        return 1;
    }
}
