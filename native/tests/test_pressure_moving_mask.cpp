// Moving masks must not leave a retired gas ID in retained Empty authority.
// All pressure variants and one/four configured workers run the same schedule.
#include "cybersand/world.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <iostream>
#include <memory>
#include <span>
#include <stdexcept>
#include <string>
#include <tuple>
#include <vector>

namespace {
using namespace cybersand;

void check(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error("moving gas mask: " + message);
}

using Worlds = std::array<std::unique_ptr<World>, 6>;

Worlds worlds() {
    Worlds result;
    for (std::size_t arm = 0; arm < result.size(); ++arm) {
        auto request = LiquidSolverPolicy::default_request();
        request[21] = 3;
        request[22] = static_cast<std::int32_t>(arm % 3);
        auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(request));
        check(decoded.accepted(), "pressure assignment refused");
        auto config = std::make_unique<WorldConfig>();
        config->liquid_solver_policy = *decoded.policy;
        config->worker_threads = arm < 3 ? 1U : 4U;
        config->chunk_size = 8;
        config->activity_block_size = 8;
        config->scheduling_core_size = 8;
        config->parallel_job_threshold = 1;
        config->maximum_chunk_count = 1024;
        config->active_chunk_capacity = 1024;
        config->active_core_capacity = 1024;
        config->sleep_after_quiet_ticks = 3;
        result[arm] = std::make_unique<World>(*config);
        result[arm]->reserve_region({-8, -8, 48, 32});
        result[arm]->configure_transient_obstacles({-8, -8, 48, 32});
    }
    return result;
}

void fill(World& w, int x, int y, int width, int height, Material material) {
    for (int dy = 0; dy < height; ++dy) for (int dx = 0; dx < width; ++dx) {
        if (material == Material::Empty) (void)w.set_cell_state(x+dx,y+dy,material,0,0);
        else w.set(x+dx,y+dy,material);
    }
}

// Fifty Empty cells over ten supported full Water cells. No material writes
// occur after construction except the explicit wall opening in merge/vent.
void room(World& w, int x = 0, int y = 0) {
    fill(w,x,y,12,8,Material::Wall);
    fill(w,x+1,y+1,10,5,Material::Empty);
    fill(w,x+1,y+6,10,1,Material::Water);
}

auto key(const GasCompartmentSnapshot& c) {
    return std::tuple{c.id,c.generation,c.parents,c.parent_count,c.amount,c.volume,
                      c.anchor_x,c.anchor_y,c.created_tick,c.revision,c.gauge};
}

auto key(const GasLedger& l) {
    return std::tuple{l.created,l.absorbed,l.vented,l.collapsed,l.merges,l.splits,
                      l.creations,l.vents,l.collapses,l.amount_live};
}

auto key(const PressureFlowLedger& l) {
    return std::tuple{l.overfill_converted,l.overfill_external,l.flow_remainder,
                      l.contact_loss,l.relief_cells};
}

void equal(const World& a, const World& b) {
    check(a.liquid_comparison_hash(LiquidStateProjection::PressureVariantEquivalenceV1) ==
          b.liquid_comparison_hash(LiquidStateProjection::PressureVariantEquivalenceV1),
          "full same-tick physical projection differs");
    check(a.quantity_ledger() == b.quantity_ledger(), "exact population/source/sink ledger differs");
    check(key(a.gas_ledger()) == key(b.gas_ledger()), "gas ledger differs");
    check(key(a.pressure_flow_ledger()) == key(b.pressure_flow_ledger()), "PF ledger differs");
    check(a.gas_next_id() == b.gas_next_id() && a.gas_topology_revision() == b.gas_topology_revision(),
          "allocator or topology revision differs");
    const auto ac = a.gas_compartments(), bc = b.gas_compartments();
    check(ac.size() == bc.size(), "live table sizes differ");
    for (std::size_t i=0;i<ac.size();++i) check(key(ac[i]) == key(bc[i]), "live table field differs");
    const auto ah = a.gas_history(), bh = b.gas_history();
    check(ah.size() == bh.size(), "history sizes differ");
    for (std::size_t i=0;i<ah.size();++i)
        check(key(ah[i].compartment) == key(bh[i].compartment) && ah[i].reason == bh[i].reason &&
              ah[i].successors == bh[i].successors && ah[i].successor_count == bh[i].successor_count &&
              ah[i].tick == bh[i].tick, "history field differs");
}

void valid(const World& w, std::uint64_t expected_water) {
    check(!w.has_failed(), "ordinary moving-mask tick quarantined");
    check(w.water_quantity({-8,-8,48,32}) == expected_water, "closed Water quantity changed");
    const auto table = w.gas_compartments();
    std::uint64_t amount=0;
    for (const auto& c : table) amount += c.amount;
    const auto ledger = w.gas_ledger();
    check(ledger.amount_live == amount && ledger.created + ledger.absorbed ==
          ledger.vented + ledger.collapsed + ledger.amount_live, "exact gas balance does not close");
    std::vector<ChunkCoord> roster(w.chunk_count());
    check(w.copy_pressure_head_chunk_coordinates(roster) == roster.size(), "resident roster incomplete");
    const auto size = w.config().chunk_size;
    for (const auto coord : roster) for (int y=0;y<size;++y) for (int x=0;x<size;++x) {
        const auto label = w.pressure_cell(coord.x*size+x,coord.y*size+y).gas;
        if (label == 0U || label == kVacuumLabel || label == kAtmosphereLabel) continue;
        check(std::any_of(table.begin(),table.end(),[&](const auto& c){return c.id == label;}),
              "positive stored label refers to a retired compartment, including UNDER a mask");
    }
}

void ticks(Worlds& set, int count, std::uint64_t water) {
    for (int i=0;i<count;++i) {
        for (auto& w : set) (void)w->tick();
        for (const auto& w : set) { valid(*w,water); equal(*set[0],*w); }
    }
}

void roundtrip_masked(Worlds& set) {
    for (auto& w : set) {
        const auto bytes = w->save_physical_state();
        auto restored = World::restore_physical_state(w->config(), bytes);
        const auto copied = restored->save_physical_state();
        const auto first = std::mismatch(bytes.begin(),bytes.end(),copied.begin(),copied.end());
        check(copied == bytes, "masked save bytes differ at " +
              std::to_string(first.first-bytes.begin()) + " of " + std::to_string(bytes.size()) +
              "/" + std::to_string(copied.size()));
        // CYPS preserves native stored authority, not the caller's transient
        // body raster. Reinstall that caller-owned input on both arms so its
        // deliberate wake effects are also identical before comparing clocks.
        std::vector<std::tuple<int,int,std::uint16_t>> masks;
        for (int y=-8;y<24;++y) for (int x=-8;x<40;++x) {
            const auto id=w->transient_obstacle_at(x,y);
            if (id) masks.emplace_back(x,y,id);
            check(restored->transient_obstacle_at(x,y) == 0U, "CYPS unexpectedly imported host masks");
        }
        for (auto* target : {w.get(),restored.get()}) {
            target->clear_transient_obstacles();
            target->configure_transient_obstacles({-8,-8,48,32});
            for (const auto& [x,y,id] : masks)
                check(target->set_transient_obstacle(x,y,id), "caller mask reinstall refused");
        }
        check(restored->physical_state_hash() == w->physical_state_hash(),
              "masked physical hash differs after restore: " + std::to_string(w->physical_state_hash()) +
              "/" + std::to_string(restored->physical_state_hash()));
        equal(*w,*restored);
        // Keep both warm and cold-restored arms in the six-arm comparison.
        if (w->config().worker_threads == 4U) w = std::move(restored);
    }
}

bool retired(const World& w, std::uint32_t id, GasRetireReason reason) {
    const auto history = w.gas_history();
    return std::any_of(history.begin(),history.end(),[&](const auto& h) {
        return h.compartment.id == id && h.reason == reason;
    });
}

void collapse() {
    auto set = worlds();
    for (auto& w : set) room(*w);
    ticks(set,3,2550);
    const auto id = set[0]->gas_compartments().at(0).id;
    for (auto& w : set) for (int y=1;y<=5;++y) for (int x=1;x<=10;++x)
        check(w->set_transient_obstacle(x,y,1), "full pocket mask refused");
    ticks(set,1,2550);
    for (auto& w : set) {
        check(w->gas_compartments().empty() && w->gas_ledger().collapsed == 50U &&
              retired(*w,id,GasRetireReason::Collapsed), "full mask did not retire/collapse the old amount");
        check(w->pressure_cell(1,1).gas == kVacuumLabel, "collapsed masked cell is not volume-only vacuum");
    }
    roundtrip_masked(set);
    for (auto& w : set) w->clear_transient_obstacles();
    ticks(set,3,2550);
    for (auto& w : set) check(w->gas_compartments().empty() && w->gas_ledger().created == 50U,
                            "unmask recreated collapsed gas instead of reopening vacuum");
}

void split() {
    auto set = worlds();
    for (auto& w : set) room(*w,-4,-4);
    ticks(set,3,2550);
    const auto id = set[0]->gas_compartments().at(0).id;
    for (auto& w : set) for (int y=-3;y<=1;++y)
        check(w->set_transient_obstacle(2,y,1), "split divider mask refused");
    ticks(set,1,2550);
    for (auto& w : set) check(w->gas_compartments().size() == 2U &&
            retired(*w,id,GasRetireReason::Split) && w->pressure_cell(2,-3).gas == kVacuumLabel,
            "split retained its retired parent on masked divider");
    roundtrip_masked(set);
    for (auto& w : set) w->clear_transient_obstacles();
    std::uint64_t prepared_volume=0;
    for (int y=-3;y<=2;++y) for (int x=-3;x<=6;++x)
        prepared_volume += set[0]->stored_material(x,y) == Material::Empty;
    ticks(set,1,2550);
    for (auto& w : set) check(w->gas_compartments().size() == 1U &&
            w->gas_compartments()[0].volume == prepared_volume && w->gas_compartments()[0].amount == 50U &&
            w->gas_ledger().created == 50U, "unmasked split did not merge exact retained amount/volume: count=" +
            std::to_string(w->gas_compartments().size()) + " volume=" + std::to_string(w->gas_compartments().at(0).volume) +
            " amount=" + std::to_string(w->gas_compartments().at(0).amount) + " created=" + std::to_string(w->gas_ledger().created));
    // Later Water relief can change Empty volume; it must retain exact amount
    // and match every reference table/ledger field, rather than freeze geometry.
    ticks(set,2,2550);
    for (auto& w : set) check(w->gas_compartments().size() == 1U &&
            w->gas_compartments()[0].amount == 50U && w->gas_ledger().created == 50U,
            "split continuation changed retained gas amount or created gas");
}

void merge() {
    auto set = worlds();
    for (auto& w : set) {
        room(*w); room(*w,11,0);
    }
    ticks(set,3,5100);
    const auto old = set[0]->gas_compartments();
    check(old.size() == 2U, "two initial pockets missing");
    const auto survivor=old[0].id, removed=old[1].id;
    for (auto& w : set) {
        check(w->set_transient_obstacle(13,2,1), "merge retained-cell mask refused");
        fill(*w,11,2,1,1,Material::Empty);
    }
    ticks(set,1,5100);
    for (auto& w : set) check(w->gas_compartments().size() == 1U &&
            w->gas_compartments()[0].id == survivor && retired(*w,removed,GasRetireReason::Merged) &&
            w->pressure_cell(13,2).gas == kVacuumLabel, "merge left a retired non-survivor under mask");
    roundtrip_masked(set);
    const auto created=set[0]->gas_ledger().created;
    for (auto& w : set) w->clear_transient_obstacles();
    ticks(set,3,5100);
    for (auto& w : set) check(w->gas_compartments()[0].id == survivor &&
            w->gas_ledger().created == created, "unmask changed the merge survivor or created gas");
}

void vent() {
    auto set = worlds();
    for (auto& w : set) room(*w);
    ticks(set,3,2550);
    const auto id=set[0]->gas_compartments()[0].id;
    for (auto& w : set) {
        check(w->set_transient_obstacle(8,2,1), "vent retained-cell mask refused");
        fill(*w,2,0,1,1,Material::Empty);
    }
    ticks(set,1,2550);
    for (auto& w : set) check(w->gas_compartments().empty() && retired(*w,id,GasRetireReason::Vented) &&
            w->gas_ledger().vented == 50U && w->pressure_cell(8,2).gas == kVacuumLabel,
            "vent did not clear its retired masked label and book the old amount");
    roundtrip_masked(set);
    for (auto& w : set) w->clear_transient_obstacles();
    ticks(set,2,2550);
    for (auto& w : set) check(w->gas_compartments().empty() && w->gas_ledger().created == 50U,
                            "unmask after vent created a spurious sealed amount");
}

void live_continuity() {
    auto set = worlds();
    for (auto& w : set) room(*w);
    ticks(set,3,2550);
    const auto id=set[0]->gas_compartments()[0].id;
    for (auto& w : set) check(w->set_transient_obstacle(8,2,1), "live retained-cell mask refused");
    ticks(set,1,2550);
    for (auto& w : set) check(w->gas_compartments().size() == 1U &&
            w->gas_compartments()[0].id == id && w->gas_compartments()[0].volume == 49U &&
            w->gas_compartments()[0].amount == 50U && w->pressure_cell(8,2).gas == id &&
            w->gas_history().empty(), "a STILL LIVE masked ID was cleared or retired");
    roundtrip_masked(set);
    for (auto& w : set) w->clear_transient_obstacles();
    ticks(set,3,2550);
    for (auto& w : set) check(w->gas_compartments()[0].id == id &&
            w->gas_compartments()[0].volume == 50U && w->gas_compartments()[0].amount == 50U &&
            w->gas_history().empty(), "unmask lost live identity/amount continuity");
}
}  // namespace

void test_pressure_moving_mask_retired_labels() {
    collapse(); split(); merge(); vent(); live_continuity();
    std::cout << "MOVING_GAS_MASK: collapse/split/merge/vent/live; PF0/1/2; configured1/4; masked restore; exact parity\n";
}
