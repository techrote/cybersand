#include "cybersand/workbench_authoring_patch.hpp"
#include "cybersand/prepared_world.hpp"

#include <array>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using namespace cybersand;
using namespace cybersand::workbench_authoring;
int checks = 0;
void require(bool okay, const char* message) {
    ++checks;
    if (!okay) throw std::runtime_error(message);
}
normalization::FinalSetupInput capture(const World& source, std::uint32_t side = 256) {
    normalization::FinalSetupInput input;
    input.setup.domain = {0, 0, side, side};
    input.mass_bits = source.config().water_experiment_policy.mass_bits();
    input.ambient_temperature = source.config().ambient_temperature;
    for (std::uint32_t y = 0; y < side; ++y) for (std::uint32_t x = 0; x < side; ++x) {
        const auto material = source.stored_material(x, y);
        const auto temperature = source.stored_temperature(x, y);
        if (material != Material::Empty || temperature != input.ambient_temperature)
            input.cells.push_back({x, y, material, source.stored_state_a(x, y), source.stored_state_b(x, y), temperature});
    }
    return input;
}
void refuses(World& source, normalization::FinalSetupInput input,
             const std::vector<Cell>& patch, const std::vector<Point>& guards = {},
             Operation operation = Operation::Build) {
    const auto old = input.cells;
    const auto physical = source.physical_state_hash();
    bool refused = false;
    try { (void)stage(source, input, patch, guards, operation); }
    catch (const std::exception&) { refused = true; }
    require(refused, "invalid patch must refuse");
    require(old == input.cells, "refused staging must not partially alter private tuples");
    require(physical == source.physical_state_hash(), "refused staging must not mutate native source");
}
void positive_and_exact_undo() {
    World source;
    source.reserve_region({0,0,256,256});
    source.set(2,3,Material::Concrete);
    require(source.set_cell_state(20,20,Material::Water,37,2), "fractional Water fixture");
    source.set_temperature(20,20,731);
    source.set_temperature(25,25,503);
    const auto old = capture(source);
    const auto physical = source.physical_state_hash();
    auto input = old;
    const std::vector<Cell> patch{{{8,8},Material::Empty,Material::SteelPlate},
        {{9,8},Material::Empty,Material::RustedSteel},{{25,25},Material::Empty,Material::RedBrick},
        {{26,25},Material::Empty,Material::Stone}};
    const std::array<Point,2> guards{{{4,4},{7,8}}};
    const auto receipt = stage(source,input,patch,guards,Operation::Build);
    require(receipt.changed == patch.size(), "receipt must account for each proposed cell");
    require(source.physical_state_hash() == physical, "valid private staging cannot change source");
    auto replay = old;
    require(stage(source,replay,patch,guards,Operation::Build).digest == receipt.digest &&
        replay.cells == input.cells, "identical native source and patch replay exactly");
    auto prepared = PreparedWorldBuilder::prepare(source.config(),input,
        normalization::NormalizationOptIn::None);
    require(std::holds_alternative<PreparedWorld>(prepared), "patched native tuple candidate prepares");
    auto changed = std::get<PreparedWorld>(std::move(prepared)).take_world();
    for (int y=0;y<256;++y) for (int x=0;x<256;++x) {
        auto expected = source.stored_material(x,y);
        for (const auto& cell : patch) if (cell.point == Point{x,y}) expected=cell.after;
        require(changed->stored_material(x,y)==expected, "only approved cells differ in prepared World");
        require(changed->stored_temperature(x,y)==source.stored_temperature(x,y), "thermal fields survive patch");
    }
    require(changed->stored_state_a(20,20)==37 && changed->stored_state_b(20,20)==2,
        "unrelated fractional Water survives without normalization");
    std::vector<Cell> inverse;
    for (const auto& cell : patch) inverse.push_back({cell.point,cell.after,Material::Empty});
    auto removed = capture(*changed);
    const auto inverse_receipt = stage(*changed,removed,inverse,guards,Operation::Remove);
    require(inverse_receipt.changed == patch.size() && removed.cells == old.cells,
        "exact inverse restores all native tuples including nonambient Empty");
    require(inverse_receipt.digest != receipt.digest, "direction belongs to patch identity");
}
void hostile_and_capacity() {
    World source;
    source.reserve_region({0,0,512,512});
    source.set(12,12,Material::Concrete);
    const auto input = capture(source);
    const Cell legal{{8,8},Material::Empty,Material::SteelPlate};
    refuses(source,input,{});
    refuses(source,input,{legal,legal});
    refuses(source,input,{{{9,8},Material::Empty,Material::SteelPlate},legal});
    refuses(source,input,{legal,{{12,12},Material::Empty,Material::SteelPlate}});
    refuses(source,input,{{{12,12},Material::Concrete,Material::SteelPlate}});
    refuses(source,input,{legal},{{8,8}});
    refuses(source,input,{legal},{{7,8},{7,8}});
    refuses(source,input,{legal},{{256,8}});
    refuses(source,input,{{{-1,0},Material::Empty,Material::SteelPlate}});
    refuses(source,input,{{{256,0},Material::Empty,Material::SteelPlate}});
    refuses(source,input,{{{8,8},Material::Empty,Material::Water}});
    refuses(source,input,{{{8,8},Material::Empty,Material::Sand}});
    refuses(source,input,{{{8,8},Material::Empty,Material::Smoke}});
    refuses(source,input,{{{8,8},Material::Empty,Material::Empty}});
    refuses(source,input,{{{8,8},Material::Empty,static_cast<Material>(10)}});
    refuses(source,input,{legal},{},static_cast<Operation>(9));
    refuses(source,input,{legal},{},Operation::Remove);
    refuses(source,input,{{{12,12},Material::SteelPlate,Material::Empty}},{},Operation::Remove);
    source.configure_transient_obstacles({0,0,512,512});
    require(source.set_transient_obstacle(8,8,1), "native body fixture");
    refuses(source,input,{legal});
    source.clear_transient_obstacles();
    auto malformed = input;
    malformed.cells.push_back(malformed.cells.front());
    refuses(source,malformed,{legal});
    malformed=input; malformed.setup.domain.width=2049;
    refuses(source,malformed,{legal});
    malformed=input; malformed.setup.domain.x=-1;
    refuses(source,malformed,{legal});
    malformed=input; malformed.setup.domain.height=255;
    refuses(source,malformed,{legal});
    std::vector<Cell> oversized(kMaximumPatchCells+1,legal);
    refuses(source,input,oversized);
    std::vector<Point> too_many_guards(kMaximumPatchCells+1,{0,0});
    refuses(source,input,{legal},too_many_guards);

    // The largest admitted patch is actually staged and reconstructed; this is
    // distinct from merely rejecting an over-limit vector before reading it.
    World empty;
    empty.reserve_region({0,0,512,512});
    auto large=capture(empty,512);
    std::vector<Cell> boundary;
    boundary.reserve(kMaximumPatchCells);
    for (int y=0;y<512;++y) for (int x=0;x<512;++x)
        boundary.push_back({{x,y},Material::Empty,Material::SteelPlate});
    const auto receipt=stage(empty,large,boundary,{},Operation::Build);
    require(receipt.changed==kMaximumPatchCells && large.cells.size()==kMaximumPatchCells,
        "exact maximum patch stages completely");
    require(empty.stored_material(511,511)==Material::Empty,"maximum staging has no live writes");
}
}

int main() {
    try {
        positive_and_exact_undo();
        hostile_and_capacity();
        std::cout << "WORKBENCH_AUTHORING_PATCH_NATIVE checks=" << checks << " failures=0\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "WORKBENCH_AUTHORING_PATCH_NATIVE checks=" << checks << " failures=1: " << error.what() << '\n';
        return 1;
    }
}
