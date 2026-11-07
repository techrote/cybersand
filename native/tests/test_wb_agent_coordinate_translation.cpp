// Independent WB-AGENT-000 signed-to-finite-domain physics qualification.
// TEST-ONLY: consumes #527's frozen native fixture and unmodified native World.
// #define renames ONLY the included control entry point. This reuses its exact
// manifest parser, shapes and phase semantics, without changing their source.
#define main wb_agent_frozen_control_main
#include "test_wb_agent_sand_hopper.cpp"
#undef main

#include <array>
#include <iterator>
#include <map>
#include <tuple>

namespace {
struct Shift { int x; int y; };
struct Trace {
    std::map<int, std::vector<Cell>> sand;
    std::map<int, int> catchment;
    int initial = 0;
    int after_author = 0;
    int total = 0;
    int caught = 0;
    int protected_cells = 0;
    int agent_writes = 0;
    int first_full_catchment_tick = -1;
    std::uint64_t completed = 0;
    std::uint32_t actual_workers_max = 0;
};

constexpr std::array<int,16> kSnapshotTicks{
    0,1,2,3,4,8,12,16,20,40,60,80,120,240,360,480
};
const std::vector<Shift> kProposedTranslations=[] {
    std::vector<Shift> offsets;
    offsets.reserve(256);
    // 16x16 repeatable grid, covers 64..1024 in each world axis. Every
    // combination keeps the immutable signed fixture inside 2048-square
    // finite coordinates. Look for a genuine exact-parity mapping rather
    // than cherry-picking the nearest successful final count.
    for (int x=64;x<=1024;x+=64)
        for (int y=64;y<=1024;y+=64)
            offsets.push_back({x,y});
    return offsets;
}();

Operation shifted(Operation op, Shift s) {
    op.a += s.x;
    op.b += s.y;
    if (op.shape != "rect") op.c += s.x;
    return op;
}

std::vector<Cell> normalized_sand(const World& world, Shift s) {
    // Keep #527's EXACT whole-apparatus spill census, then subtract the
    // candidate offset. A grain leaving the original census is a failure.
    std::vector<Cell> result;
    for (int y = -24; y < 72; ++y) {
        for (int x = -96; x < 96; ++x) {
            if (world.stored_material(x + s.x,y + s.y) == Material::Sand)
                result.emplace_back(x,y);
        }
    }
    std::sort(result.begin(),result.end());
    return result;
}

int count_target(const World& world, const Operation& frozen_target, Shift s) {
    int result = 0;
    cells(frozen_target,[&](int x,int y) {
        result += world.stored_material(x+s.x,y+s.y) == Material::Sand;
    });
    return result;
}

Trace real_control(const std::vector<Operation>& immutable_recipe,
                   const std::string& variant, int workers, Shift translation) {
    WorldConfig configuration;
    configuration.worker_threads = static_cast<std::uint32_t>(workers);
    World world(configuration);
    std::set<Cell> protected_original;
    const Operation* target = nullptr;
    Trace output;

    for (const auto& original : immutable_recipe) {
        if (!applies(original,variant)) continue;
        if (original.phase == "target") {
            need(target == nullptr && original.shape == "rect", "invalid_target");
            target = &original;
        }
    }
    need(target != nullptr, "missing_frozen_target");

    for (const std::string phase : {"manual_wall","protected_wall","initial_sand"}) {
        for (const auto& original : immutable_recipe) {
            if (!applies(original,variant) || original.phase != phase) continue;
            need(original.shape == "rect","initial_requires_literal_rectangle");
            cells(original,[&](int x,int y) {
                const int px = x + translation.x;
                const int py = y + translation.y;
                need(px >= -96 + translation.x && px < 96 + translation.x &&
                     py >= -24 + translation.y && py < 72 + translation.y,
                     "placement_outside_frozen_local_domain");
                const Material material = world.stored_material(px,py);
                if (phase == "initial_sand") {
                    need(material == Material::Empty,"initial_Sand_overwrites_other_material");
                    world.set(px,py,Material::Sand);
                } else {
                    need(material != Material::Sand,"initial_wall_overwrites_Sand");
                    world.set(px,py,Material::Wall);
                    if (phase == "protected_wall")
                        protected_original.emplace(x,y);
                }
            });
        }
    }
    output.initial = static_cast<int>(normalized_sand(world,translation).size());
    need(output.initial==32,"original_initial_Sand_count_not_32");
    need(protected_original.size()==17,"frozen_protected_wall_motif_not_17");

    // Exact fixed reference authoring: Hard Wall and Empty only, zero Sand
    // manufacture, zero material-law edits. Read the authoritative cell before
    // each replacement, including the frozen outlet and overlap transitions.
    for (const std::string phase : {"agent_wall","agent_empty"}) {
        for (const auto& original : immutable_recipe) {
            if (!applies(original,variant) || original.phase != phase) continue;
            cells(original,[&](int x,int y) {
                need(!protected_original.contains({x,y}),"agent_touched_protected_wall");
                const int px=x+translation.x,py=y+translation.y;
                const Material before=world.stored_material(px,py);
                need(before!=Material::Sand,"agent_would_replace_Sand");
                if (phase=="agent_empty")
                    need(before==Material::Wall,"outlet_not_existing_wall");
                world.set(px,py,phase=="agent_wall"?Material::Wall:Material::Empty);
                ++output.agent_writes;
            });
        }
    }
    output.after_author=static_cast<int>(normalized_sand(world,translation).size());
    need(output.after_author==32,"agent_changed_Sand_quantity");

    auto sample = [&](int tick) {
        output.sand[tick]=normalized_sand(world,translation);
        output.catchment[tick]=count_target(world,*target,translation);
        need(output.sand[tick].size()==32,"Sand_escaped_frozen_census_domain");
    };
    sample(0);
    for (int tick=1;tick<=480;++tick) {
        const auto stats=world.tick();
        need(!world.has_failed(),"native_World_failed");
        need(world.completed_tick_index()==static_cast<std::uint64_t>(tick),
            "native_completed_tick_mismatch");
        output.actual_workers_max=std::max(output.actual_workers_max,stats.worker_threads_observed);
        const int caught=count_target(world,*target,translation);
        if (caught==32 && output.first_full_catchment_tick<0)
            output.first_full_catchment_tick=tick;
        if (std::find(kSnapshotTicks.begin(),kSnapshotTicks.end(),tick)!=kSnapshotTicks.end())
            sample(tick);
    }
    output.completed=world.completed_tick_index();
    output.caught=count_target(world,*target,translation);
    output.total=static_cast<int>(normalized_sand(world,translation).size());
    for (const auto& cell : protected_original) {
        need(world.stored_material(cell.first+translation.x,cell.second+translation.y)==Material::Wall,
             "protected_wall_mutated");
        ++output.protected_cells;
    }
    need(output.completed==480,"not_480_total_completed_ticks");
    need(output.protected_cells==17,"lost_protection");
    need(output.total==32,"lost_or_created_Sand");
    return output;
}

struct Comparison {
    bool valid = false;
    int equal_frames = 0;
    int equal_catchment = 0;
    int first_difference_tick = -1;
    int first_difference_cells = 0;
    bool same_first_full_tick = false;
};
Comparison compare(const Trace& baseline, const Trace& trial) {
    Comparison c;
    c.same_first_full_tick=baseline.first_full_catchment_tick==trial.first_full_catchment_tick;
    for (const auto& [tick, original] : baseline.sand) {
        const auto& shifted_sand=trial.sand.at(tick);
        if(original==shifted_sand) ++c.equal_frames;
        else if(c.first_difference_tick<0) {
            c.first_difference_tick=tick;
            std::vector<Cell> symmetric;
            std::set_symmetric_difference(original.begin(),original.end(),
                shifted_sand.begin(),shifted_sand.end(),
                std::back_inserter(symmetric));
            c.first_difference_cells=static_cast<int>(symmetric.size());
        }
        c.equal_catchment+=baseline.catchment.at(tick)==trial.catchment.at(tick);
    }
    c.valid=trial.initial==32 && trial.after_author==32 && trial.total==32 &&
        trial.caught==32 && trial.protected_cells==17 &&
        trial.agent_writes==baseline.agent_writes &&
        trial.completed==480 && c.equal_frames==static_cast<int>(kSnapshotTicks.size()) &&
        c.equal_catchment==static_cast<int>(kSnapshotTicks.size()) &&
        c.same_first_full_tick;
    return c;
}
}

int main(int argc, char** argv) {
    if (argc != 2) {
        std::cerr << "usage: test_wb_agent_coordinate_translation frozen-v2.tsv\n";
        return 2;
    }
    try {
        const auto recipe=read_recipe(argv[1]);
        std::map<std::pair<std::string,int>,Trace> originals;
        for(const std::string variant : {"normal","revised"}) {
            for(const int workers : {1,4}) {
                auto original=real_control(recipe,variant,workers,Shift{0,0});
                need(original.caught==32 && original.first_full_catchment_tick>0,
                     "frozen_original_reference_not_positive");
                std::cout<<"BASELINE variant="<<variant<<" workers="<<workers
                         <<" caught="<<original.caught
                         <<" first_full_tick="<<original.first_full_catchment_tick
                         <<" total_ticks="<<original.completed
                         <<" agent_writes="<<original.agent_writes
                         <<" protected="<<original.protected_cells
                         <<" observed_workers="<<original.actual_workers_max<<'\n';
                originals.emplace(std::make_pair(variant,workers),std::move(original));
            }
        }
        int fully_equivalent_offsets=0;
        for(const Shift shift : kProposedTranslations) {
            bool offset_equal=true;
            bool all_final_catchments=true;
            for(const std::string variant : {"normal","revised"}) {
                for(const int workers : {1,4}) {
                    auto trial=real_control(recipe,variant,workers,shift);
                    const auto& baseline=originals.at({variant,workers});
                    const auto comparison=compare(baseline,trial);
                    offset_equal &= comparison.valid;
                    all_final_catchments &= trial.caught==32;
                    std::cout<<"TRIAL variant="<<variant<<" workers="<<workers
                             <<" shift_x="<<shift.x<<" shift_y="<<shift.y
                             <<" caught="<<trial.caught
                             <<" first_full_tick="<<trial.first_full_catchment_tick
                             <<" baseline_first_full_tick="<<baseline.first_full_catchment_tick
                             <<" exact_frames="<<comparison.equal_frames<<"/"<<kSnapshotTicks.size()
                             <<" matched_catchment_samples="<<comparison.equal_catchment<<"/"<<kSnapshotTicks.size()
                             <<" first_difference_tick="<<comparison.first_difference_tick
                             <<" first_difference_cells="<<comparison.first_difference_cells
                             <<" protected="<<trial.protected_cells
                             <<" writes="<<trial.agent_writes
                             <<" translated_finite_domain="<<((shift.x>=35 && shift.y>=3 && shift.x+35<2048 && shift.y+41<2048)?"yes":"no")
                             <<" exact_physics="<<(comparison.valid?"PASS":"HOLD")
                             <<'\n';
                }
            }
            fully_equivalent_offsets+=offset_equal;
            std::cout<<"OFFSET_SUMMARY shift_x="<<shift.x<<" shift_y="<<shift.y
                     <<" all_four_exact="<<(offset_equal?"PASS":"HOLD")
                     <<" all_four_final_32="<<(all_final_catchments?"PASS":"HOLD")<<'\n';
        }
        std::cout<<"WB_AGENT_TRANSLATION_PARITY fully_equivalent_offsets="
                 <<fully_equivalent_offsets<<"/"<<kProposedTranslations.size()
                 <<" comparison=original_native_World_vs_finite_positive_shift"
                 <<" frozen_fixture_unchanged=true\n";
        // This is an *experiment*, not a production assertion. Native execution
        // must complete even when no translation is physically equivalent, so
        // the factual result and original negatives remain in CI artifacts.
        // Consumer acceptance MUST check fully_equivalent_offsets > 0.
        return 0;
    } catch(const std::exception& ex) {
        std::cerr<<"WB_AGENT_TRANSLATION_PARITY fatal="<<ex.what()<<'\n';
        return 1;
    }
}
