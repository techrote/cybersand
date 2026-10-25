// LCB-002 total tick cost. Three simultaneous Worlds, one immutable executable.
// Only World::tick is inside tick timers; edits, observations, parity and JSON
// are outside every arm's interval. The Python runner owns source/tool fences.
#include "cybersand/world.hpp"

#include <algorithm>
#include <array>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <memory>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <tuple>
#include <vector>

#if defined(_WIN32)
#include <windows.h>
#include <psapi.h>
#elif defined(__unix__)
#include <sys/resource.h>
#endif

namespace {
using namespace cybersand;
using Clock = std::chrono::steady_clock;
constexpr int kCold = 8, kWarm = 48, kDisturbed = 32;
constexpr int kTicks = kCold + kWarm + kDisturbed;
constexpr std::array<std::string_view, 3> kArms{"reference", "cached", "dormant"};
constexpr std::array<std::string_view, 6> kProfiles{
    "awake-boxed-water", "ordinary-sleeping-water", "two-sealed-rooms-local-change",
    "remote-gas-and-moving-mask", "continuous-topology-churn", "explicit-capacity-budget-fallback"};
constexpr std::array<std::string_view, 4> kFallbacks{"index", "head", "member", "pair"};

#define LCB_OPT_COUNTERS(X) \
 X(water_material_calls) X(water_motion_calls) X(other_liquid_calls) \
 X(certificate_attempts) X(certificate_reuses) X(certificate_saved_calls) X(certificate_declines) \
 X(certificate_work_charged) X(certificate_work_credited) X(certificate_work_windows) X(certificate_work_suspensions) \
 X(certificate_unavailable_ticks) X(certificate_suspended_ticks) X(certificate_cold_resets) X(certificate_cold_reset_cells) X(certificate_layer_activations) \
 X(index_rebuilds) X(invalidation_rects) X(columns_recomputed) X(rows_recomputed) \
 X(base_cells_written) X(final_cells_written) X(gas_reuses) X(gas_reference_passes) \
 X(reference_fallbacks) X(fallback_resident_cells) X(certificate_invalidation_cells) \
 X(preparation_nanoseconds) X(gas_nanoseconds) X(head_nanoseconds) \
 X(gas_seed_cells) X(gas_seed_probes) X(gas_bfs_cells) X(gas_bfs_probes) X(gas_bfs_nodes) \
 X(gas_member_validations) X(gas_member_stamps) X(gas_component_reuses) X(gas_index_chunks) \
 X(gas_cache_build_cells) X(gas_cache_builds) X(gas_component_proof_checks) \
 X(gas_member_initializations) X(gas_member_builds) X(gas_invalidation_pairs) \
 X(gas_component_invalidations) X(gas_dirty_chunks_queued) X(gas_capacity_fallbacks) \
 X(gas_budget_fallbacks) X(gas_restart_fallbacks) X(gas_relabel_cells) X(gas_identity_nodes) X(gas_stamp_clear_cells)

void require(bool value, std::string_view message) {
    if (!value) throw std::runtime_error(std::string(message));
}
std::uint64_t nanos(Clock::time_point start) {
    return static_cast<std::uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(Clock::now()-start).count());
}
int integer(const char* text, int low, int high) {
    char* end=nullptr; const auto value=std::strtol(text,&end,10);
    require(end!=text && *end=='\0' && value>=low && value<=high,"integer outside registered bounds");
    return static_cast<int>(value);
}
const char* phase(int t) { return t<kCold ? "cold" : t<kCold+kWarm ? "warm" : "disturbed"; }
bool boxed(std::string_view p) { return p==kProfiles[0] || p==kProfiles[1]; }

WorldConfig config_for(std::string_view profile, std::string_view fallback, int arm, std::uint32_t workers) {
    WorldConfig config;
    config.worker_threads=workers; config.parallel_job_threshold=1;
    config.maximum_chunk_count=256; config.active_chunk_capacity=256; config.active_core_capacity=256;
    config.chunk_size=boxed(profile) ? 32 : 8;
    config.activity_block_size=config.chunk_size; config.scheduling_core_size=config.chunk_size;
    auto words=LiquidSolverPolicy::default_request();
    const auto count=static_cast<std::size_t>(words[LiquidSolverPolicy::kHeaderWords]);
    bool water=false;
    for (std::size_t i=0;i<count;++i) {
        const auto at=LiquidSolverPolicy::kHeaderWords+1U+3U*i;
        if (words[at]!=static_cast<std::int32_t>(Material::Water)) continue;
        words[at+1U]=static_cast<std::int32_t>(LiquidSolverFamily::PressureFlowV1);
        words[at+2U]=arm; water=true;
    }
    require(water,"native default envelope must contain Water");
    const auto block=LiquidSolverPolicy::kHeaderWords+1U+3U*count;
    require(words.at(block)==0 && words.at(block+1U)==0,"registered default has no parameter blocks");
    words[block]=1;
    words.insert(words.begin()+static_cast<std::ptrdiff_t>(block+1U),
        {3,LiquidPolicyBuild::kPressureBlockVersion,2,boxed(profile) ? 0 : 1,32});
    const auto decoded=LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
    require(decoded.accepted(),"registered pressure policy must be admitted without fallback");
    config.liquid_solver_policy=*decoded.policy;
    if (profile==kProfiles[5]) {
        if (fallback=="index") config.pressure_optimization.index_chunk_capacity=1;
        if (fallback=="head") config.pressure_optimization.head_repair_cell_budget=0;
        if (fallback=="member") config.pressure_optimization.gas_member_capacity=1;
        if (fallback=="pair") config.pressure_optimization.gas_invalidation_pair_budget=0;
    }
    return config;
}

void fill(World& w, std::int64_t x, std::int64_t y, int width, int height, Material material) {
    for (int dy=0;dy<height;++dy) for (int dx=0;dx<width;++dx) {
        if (material==Material::Water || material==Material::Empty)
            require(w.set_cell_state(x+dx,y+dy,material,material==Material::Water ? w.config().water_experiment_policy.maximum() : 0,0),
                    "registered fixture state write accepted");
        else w.set(x+dx,y+dy,material);
    }
}
void setup(World& w, std::string_view profile) {
    if (boxed(profile)) {
        w.reserve_region({0,0,128,128}); fill(w,0,0,128,128,Material::Wall);
        for (int by=0;by<4;++by) for (int bx=0;bx<4;++bx) {
            fill(w,bx*32+3,by*32+12,12,16,Material::Water);
            if (profile==kProfiles[0])
                require(w.set_cell_state(bx*32+24,by*32+24,Material::Oil,0,200),"isolated live Oil installed");
        }
    } else {
        w.reserve_region({0,0,88,8});
        for (const auto x : {0,64}) {
            fill(w,x,0,24,8,Material::Wall); fill(w,x+9,2,13,3,Material::Empty);
            fill(w,x+1,3,8,1,Material::Water);
        }
        w.set_simulation_region(RectI64{0,0,8,8});
        if (profile==kProfiles[3]) w.configure_transient_obstacles({0,0,88,8});
    }
}
// Return true only on a local gas edit that must reuse the other paused room.
bool edit(World& w, std::string_view profile, int t) {
    if (t<kCold+kWarm) return false;
    const int d=t-kCold-kWarm;
    if (boxed(profile)) {
        if (d%8==0) w.set(18,29,(d/8)%2==0 ? Material::Empty : Material::Wall);
        return false;
    }
    if (profile==kProfiles[4]) {
        w.set(20,1,d%2==0 ? Material::Empty : Material::Wall);
        w.set(160+8*d,16,Material::Wall); // A new bounded resident chunk every disturbed tick, no deletion trick.
        return false;
    }
    bool changed=false;
    if (d%4==0) { w.set(20,1,(d/4)%2==0 ? Material::Empty : Material::Wall); changed=true; }
    if (profile==kProfiles[3] && d%4==0) {
        w.clear_transient_obstacles();
        require(w.set_transient_obstacle(3+(d/4)%5,4,7),"moving native body mask installed");
    }
    return changed && profile==kProfiles[2];
}

// Initial authored fixture hints only. Gas discovery can allocate outside these
// bounds; all head observations use the copied actual native resident roster.
RectI64 head_domain(std::string_view profile) {
    if (boxed(profile)) return {0,0,128,128};
    return profile==kProfiles[4] ? RectI64{0,0,416,24} : RectI64{0,0,88,8};
}
RectI64 flux_roi(std::string_view profile) {
    return boxed(profile) ? RectI64{0,0,32,128} : RectI64{0,0,8,8};
}
struct HeadCoverage {
    std::uint64_t sampled=0, resident=0, prepared=0, no_head=0, unresolved=0;
    std::int64_t prepared_head_sum=0;
    std::int32_t minimum_head=0, maximum_head=0;
};
HeadCoverage sample_heads(const World& w, std::span<const ChunkCoord> coordinates, std::span<PressureHeadSnapshot> slots) {
    HeadCoverage out;
    const auto size=static_cast<std::uint64_t>(w.config().chunk_size);
    require(coordinates.size()==w.chunk_count(),"copied native roster must cover every resident chunk");
    require(slots.size()==coordinates.size()*size*size,"head sample buffer matches actual resident roster");
    for (const auto coordinate : coordinates)
        for (std::int64_t dy=0;dy<w.config().chunk_size;++dy) for (std::int64_t dx=0;dx<w.config().chunk_size;++dx) {
        const auto head=w.prepared_pressure_head(coordinate.x*w.config().chunk_size+dx,coordinate.y*w.config().chunk_size+dy);
        slots[static_cast<std::size_t>(out.sampled++)]=head;
        require(head.status!=PressureHeadStatus::FamilyUnavailable && head.status!=PressureHeadStatus::NonResident,"copied actual resident head slot must exist");
        ++out.resident;
        if (head.status==PressureHeadStatus::Prepared) {
            if (out.prepared==0U) out.minimum_head=out.maximum_head=head.head;
            out.minimum_head=std::min(out.minimum_head,head.head); out.maximum_head=std::max(out.maximum_head,head.head);
            out.prepared_head_sum+=head.head; ++out.prepared;
        }
        if (head.status==PressureHeadStatus::NoHead) ++out.no_head;
        if (head.status==PressureHeadStatus::Unresolved) ++out.unresolved;
    }
    require(out.resident==w.chunk_count()*size*size,"actual head roster must cover EVERY resident cell, including gas discovery, paused and churn chunks");
    require(out.unresolved==0U,"completed pre-kernel head field must have no unresolved interpolation sentinel");
    return out;
}
struct HeadDifference {
    std::uint64_t status_mismatches=0, numeric_comparisons=0, nonzero_errors=0;
    std::int64_t signed_error_sum=0;
    std::uint64_t absolute_error_sum=0, max_absolute_error=0;
};
HeadDifference compare_heads(std::span<const PressureHeadSnapshot> reference, std::span<const PressureHeadSnapshot> candidate) {
    require(reference.size()==candidate.size(),"head domains must match");
    HeadDifference out;
    for (std::size_t i=0;i<reference.size();++i) {
        const auto& a=reference[i]; const auto& b=candidate[i];
        if (a.status!=b.status) { ++out.status_mismatches; continue; }
        if (a.status!=PressureHeadStatus::Prepared) continue;
        ++out.numeric_comparisons;
        const auto error=static_cast<std::int64_t>(b.head)-a.head;
        const auto absolute=static_cast<std::uint64_t>(error<0 ? -error : error);
        out.signed_error_sum+=error; out.absolute_error_sum+=absolute;
        out.max_absolute_error=std::max(out.max_absolute_error,absolute);
        if (error!=0) ++out.nonzero_errors;
    }
    require(out.status_mismatches==0U && out.nonzero_errors==0U,"prepared head status/numeric discrepancy against reference");
    return out;
}
void rect_json(RectI64 r) { std::cout<<'['<<r.x<<','<<r.y<<','<<r.width<<','<<r.height<<']'; }
void heads_json(const HeadCoverage& c, const HeadDifference& d) {
    std::cout<<"{\"sampled_cells\":"<<c.sampled<<",\"resident_cells\":"<<c.resident
        <<",\"prepared_cells\":"<<c.prepared<<",\"no_head_cells\":"<<c.no_head<<",\"unresolved_cells\":"<<c.unresolved
        <<",\"prepared_head_sum\":"<<c.prepared_head_sum<<",\"minimum_head\":"<<c.minimum_head<<",\"maximum_head\":"<<c.maximum_head
        <<",\"status_mismatches\":"<<d.status_mismatches<<",\"numeric_comparisons\":"<<d.numeric_comparisons
        <<",\"nonzero_errors\":"<<d.nonzero_errors<<",\"signed_error_sum\":"<<d.signed_error_sum
        <<",\"absolute_error_sum\":"<<d.absolute_error_sum<<",\"max_absolute_error\":"<<d.max_absolute_error<<'}';
}

auto compartment_key(const GasCompartmentSnapshot& c) {
    return std::tie(c.id,c.generation,c.parents,c.parent_count,c.amount,c.volume,c.anchor_x,c.anchor_y,c.created_tick,c.revision,c.gauge);
}
struct Observation {
    std::uint64_t projection=0, quantity=0, revision=0, roi_quantity=0;
    std::uint32_t next=0;
    QuantityLedgerSnapshot quantities;
    GasLedger gas;
    PressureFlowLedger flow;
    PressureFlowDiagnostics diagnostics;
    std::vector<GasCompartmentSnapshot> compartments;
    std::vector<GasHistoryRecord> history;
    std::uint64_t contacts=0;
    std::int64_t impulse_x=0, impulse_y=0;
};
Observation observe(const World& w, RectI64 roi) {
    Observation o;
    require(!w.has_failed(),"World must remain usable");
    o.projection=w.liquid_comparison_hash(LiquidStateProjection::PressureVariantEquivalenceV1);
    o.quantities=w.quantity_ledger(); o.gas=w.gas_ledger(); o.flow=w.pressure_flow_ledger();
    o.diagnostics=w.pressure_flow_diagnostics();
    o.compartments=w.gas_compartments(); o.history=w.gas_history();
    o.next=w.gas_next_id(); o.revision=w.gas_topology_revision();
    o.quantity=w.water_quantity({0,0,128,128}); o.roi_quantity=w.water_quantity(roi);
    require(o.quantity==o.quantities.water_visible+o.quantities.water_overfill,"fixture query and complete stored quantity ledger agree");
    o.contacts=w.transient_contact_count(7); o.impulse_x=w.transient_contact_impulse_x(7); o.impulse_y=w.transient_contact_impulse_y(7);
    return o;
}
void equivalent(const Observation& a, const Observation& b) {
    require(a.projection==b.projection,"same-tick pressure-variant projection mismatch");
    require(a.quantity==b.quantity && a.quantities==b.quantities,"complete quantity ledger mismatch");
    require(a.roi_quantity==b.roi_quantity,"declared ROI quantity mismatch");
    require(a.next==b.next && a.revision==b.revision,"global gas allocator/revision mismatch");
    require(std::tie(a.gas.created,a.gas.absorbed,a.gas.vented,a.gas.collapsed,a.gas.merges,a.gas.splits,a.gas.creations,a.gas.vents,a.gas.collapses,a.gas.amount_live)==
            std::tie(b.gas.created,b.gas.absorbed,b.gas.vented,b.gas.collapsed,b.gas.merges,b.gas.splits,b.gas.creations,b.gas.vents,b.gas.collapses,b.gas.amount_live),"gas ledger mismatch");
    require(std::tie(a.flow.overfill_converted,a.flow.overfill_external,a.flow.flow_remainder,a.flow.contact_loss,a.flow.relief_cells)==
            std::tie(b.flow.overfill_converted,b.flow.overfill_external,b.flow.flow_remainder,b.flow.contact_loss,b.flow.relief_cells),"PF ledger mismatch");
    require(a.compartments.size()==b.compartments.size() && a.history.size()==b.history.size(),"gas table/history sizes mismatch");
    for (std::size_t i=0;i<a.compartments.size();++i) require(compartment_key(a.compartments[i])==compartment_key(b.compartments[i]),"gas compartment field mismatch");
    for (std::size_t i=0;i<a.history.size();++i) {
        const auto& x=a.history[i]; const auto& y=b.history[i];
        require(compartment_key(x.compartment)==compartment_key(y.compartment) &&
            std::tie(x.reason,x.successors,x.successor_count,x.tick)==std::tie(y.reason,y.successors,y.successor_count,y.tick),"gas history field mismatch");
    }
    require(std::tie(a.contacts,a.impulse_x,a.impulse_y)==std::tie(b.contacts,b.impulse_x,b.impulse_y),"native body contacts/signed impulses mismatch");
}

void counters_json(const PressureOptimizationCounters& old, const PressureOptimizationCounters& now) {
    bool first=true; std::cout<<'{';
#define EMIT_COUNTER(name) if (!first) std::cout<<','; first=false; std::cout<<'"'<<#name<<"\":"<<now.name-old.name;
    LCB_OPT_COUNTERS(EMIT_COUNTER)
#undef EMIT_COUNTER
    std::cout<<'}';
}
void snapshot_json(const World& w, const PressureOptimizationSnapshot& s) {
    std::cout<<"{\"status\":"<<static_cast<int>(s.status)<<",\"gas_pending\":"<<(s.gas_pending ? "true" : "false")
        <<",\"resident_chunks\":"<<w.chunk_count()<<",\"resident_cell_bytes\":"<<w.resident_cell_bytes()
        <<",\"common_counter_bytes\":"<<s.common_counter_bytes<<",\"worker_counter_capacity_bytes\":"<<s.worker_counter_capacity_bytes
        <<",\"derived_capacity_bytes\":"<<s.derived_capacity_bytes<<",\"gas_capacity_bytes\":"<<s.gas_capacity_bytes
        <<",\"indexed_chunks\":"<<s.indexed_chunks<<",\"gas_components\":"<<s.gas_components<<",\"gas_valid_components\":"<<s.gas_valid_components
        <<",\"index_incarnation\":"<<s.index_incarnation<<",\"column_groups\":"<<s.column_groups<<",\"row_groups\":"<<s.row_groups
        <<",\"dirty_column_groups\":"<<s.dirty_column_groups<<",\"dirty_row_groups\":"<<s.dirty_row_groups<<",\"gas_dirty_chunks\":"<<s.gas_dirty_chunks
        <<",\"gas_members\":"<<s.gas_members<<",\"gas_member_capacity\":"<<s.gas_member_capacity
        <<",\"index_chunk_capacity\":"<<s.index_chunk_capacity<<",\"head_repair_cell_budget\":"<<s.head_repair_cell_budget
        <<",\"gas_invalidation_pair_budget\":"<<s.gas_invalidation_pair_budget
        <<",\"certificate_buffer_capacity_bytes\":"<<s.certificate_buffer_capacity_bytes
        <<",\"certificate_layer_enabled\":"<<(s.certificate_layer_enabled ? "true" : "false")
        <<",\"certificate_contents_cold\":"<<(s.certificate_contents_cold ? "true" : "false")
        <<",\"certificate_window_ticks\":"<<static_cast<unsigned>(s.certificate_window_ticks)
        <<",\"certificate_suspend_remaining\":"<<static_cast<unsigned>(s.certificate_suspend_remaining)
        <<",\"certificate_window_charge\":"<<s.certificate_window_charge<<",\"certificate_window_credit\":"<<s.certificate_window_credit
        <<",\"certificate_last_window_charge\":"<<s.certificate_last_window_charge<<",\"certificate_last_window_credit\":"<<s.certificate_last_window_credit<<'}';
}
std::uint64_t peak_rss_bytes() {
#if defined(_WIN32)
    PROCESS_MEMORY_COUNTERS info{}; info.cb=sizeof(info);
    return GetProcessMemoryInfo(GetCurrentProcess(),&info,sizeof(info)) ? static_cast<std::uint64_t>(info.PeakWorkingSetSize) : 0;
#elif defined(__unix__)
    rusage info{}; if (getrusage(RUSAGE_SELF,&info)!=0) return 0;
#if defined(__APPLE__)
    return static_cast<std::uint64_t>(info.ru_maxrss);
#else
    return static_cast<std::uint64_t>(info.ru_maxrss)*1024U;
#endif
#else
    return 0;
#endif
}

int run(std::string_view profile, std::string_view fallback, std::uint32_t workers, int replicate) {
    std::array<std::unique_ptr<World>,3> worlds;
    std::array<std::uint64_t,3> constructor_ns{}, setup_ns{};
    for (int position=0;position<3;++position) {
        const auto arm=static_cast<std::size_t>((replicate+position)%3);
        const auto config=config_for(profile,fallback,static_cast<int>(arm),workers);
        auto start=Clock::now(); worlds[arm]=std::make_unique<World>(config); constructor_ns[arm]=nanos(start);
        start=Clock::now(); setup(*worlds[arm],profile); setup_ns[arm]=nanos(start);
    }
    const auto domain=head_domain(profile), roi=flux_roi(profile);
    std::array<std::vector<PressureHeadSnapshot>,3> head_samples;
    std::array<std::vector<ChunkCoord>,3> chunk_coordinates;
    // Complete maximum admitted storage is fixed before all tick timers.
    // Reference gas discovery can allocate outside the authored fixture hint.
    for (std::size_t arm=0;arm<3;++arm) {
        const auto& cfg=worlds[arm]->config();
        const auto area=static_cast<std::size_t>(cfg.chunk_size)*static_cast<std::size_t>(cfg.chunk_size);
        require(cfg.maximum_chunk_count<=std::numeric_limits<std::size_t>::max()/area,"registered head observation capacity is representable");
        chunk_coordinates[arm].resize(cfg.maximum_chunk_count);
        head_samples[arm].resize(cfg.maximum_chunk_count*area);
    }
    std::cout<<"{\"event\":\"header\",\"schema\":\"lcb002-total-cost-v2\",\"execution\":"<<kPressureOptimizationExecutionVersion<<",\"profile\":\""<<profile
        <<"\",\"fallback\":\""<<fallback<<"\",\"workers\":"<<workers<<",\"replicate\":"<<replicate
        <<",\"phase_ticks\":["<<kCold<<','<<kWarm<<','<<kDisturbed<<"],\"sizeof_world\":"<<sizeof(World)
        <<",\"sizeof_world_config\":"<<sizeof(WorldConfig)<<",\"chunk_size\":"<<worlds[0]->config().chunk_size
        <<",\"sizeof_pressure_head_snapshot\":"<<sizeof(PressureHeadSnapshot)
        <<",\"apparatus_head_buffer_capacity_bytes\":"<<(head_samples[0].capacity()+head_samples[1].capacity()+head_samples[2].capacity())*sizeof(PressureHeadSnapshot)
        <<",\"apparatus_chunk_roster_capacity_bytes\":"<<(chunk_coordinates[0].capacity()+chunk_coordinates[1].capacity()+chunk_coordinates[2].capacity())*sizeof(ChunkCoord)
        <<",\"head_scope\":\"last pre-kernel prepared slot; may be stale after transport or writes; not current authority; all actual resident chunks copied/sorted/sampled outside timers; errors in Water mass units\""
        <<",\"flux_scope\":\"ROI end minus start at zero tick Water sources/sinks and zero host Water edits; inferred NET boundary inflow only, not gross or per-face transport\""
        <<",\"certificate_work_model\":{\"id\":\"certificate_work_credits_v1\",\"trial_ticks\":"<<static_cast<unsigned>(kPressureCertificateTrialTicks)
        <<",\"suspension_ticks\":"<<static_cast<unsigned>(kPressureCertificateSuspensionTicks)
        <<",\"warmup_visits\":"<<static_cast<unsigned>(kPressureCertificateWarmupVisits)
        <<",\"backoff_visits\":"<<static_cast<unsigned>(kPressureCertificateBackoffVisits)
        <<",\"invalidation_charge\":"<<kPressureCertificateInvalidationCharge<<",\"proof_charge\":"<<kPressureCertificateProofCharge
        <<",\"reuse_charge\":"<<kPressureCertificateReuseCharge<<",\"saved_call_credit\":"<<kPressureCertificateSavedCallCredit<<'}'
        <<",\"head_coverage\":\"copied_sorted_native_resident_chunk_roster\""
        <<",\"head_sample_domain_hint\":"; rect_json(domain); std::cout<<",\"boundary_flux_roi\":"; rect_json(roi); std::cout
        <<",\"participant_scope\":\"maximum distinct pool threads claiming at least one task in any dispatch of this tick; serial reports1 only with jobs\""
        <<",\"counter_scope\":\"since preceding tick snapshot, including separately timed host edits and their producer invalidation\""
        <<",\"memory_scope\":\"process peak includes all three simultaneous Worlds, three pools when configured, parity observations, apparatus and allocator; declared fields are not a complete World footprint\"}\n";
    std::array<PressureOptimizationSnapshot,3> previous{}, warm_start{}, warm_end{};
    std::array<std::uint64_t,3> observed{}, disturbed_contacts{};
    std::array<bool,3> slept{};
    for (std::size_t arm=0;arm<3;++arm) {
        previous[arm]=worlds[arm]->pressure_optimization_snapshot();
        std::cout<<"{\"event\":\"setup\",\"arm\":\""<<kArms[arm]<<"\",\"constructor_ns\":"<<constructor_ns[arm]
            <<",\"setup_ns\":"<<setup_ns[arm]<<",\"policy_hash\":\""<<worlds[arm]->liquid_solver_policy().policy_hash_hex()<<"\",\"optimization_identity\":";
        const auto identity=worlds[arm]->pressure_optimization_identity();
        if (identity) std::cout<<'"'<<Sha256::hex(*identity)<<'"'; else std::cout<<"null";
        const auto& budgets=worlds[arm]->config().pressure_optimization;
        std::cout<<",\"requested_budgets\":["<<budgets.index_chunk_capacity<<','<<budgets.head_repair_cell_budget<<','
            <<budgets.gas_member_capacity<<','<<budgets.gas_invalidation_pair_budget<<"],\"memory\":";
        snapshot_json(*worlds[arm],previous[arm]); std::cout<<"}\n";
    }
    for (int t=0;t<kTicks;++t) {
        bool require_bfs_reuse=false;
        std::array<std::uint64_t,3> edit_ns{}, tick_ns{}, roi_before_tick{};
        std::array<std::array<WaterQuantityFlow,kQuantityKindCount>,3> water_kinds_before_tick{};
        std::array<TickStats,3> stats{};
        if (t==kCold) warm_start=previous;
        for (std::size_t arm=0;arm<3;++arm) {
            const auto before_edit=worlds[arm]->quantity_ledger().kinds[static_cast<std::size_t>(QuantityKind::ExternalEdit)];
            const auto before_edit_roi=worlds[arm]->water_quantity(roi);
            const auto start=Clock::now(); const auto changed=edit(*worlds[arm],profile,t); edit_ns[arm]=nanos(start);
            const auto after_edit=worlds[arm]->quantity_ledger();
            require(before_edit==after_edit.kinds[static_cast<std::size_t>(QuantityKind::ExternalEdit)],"registered host edits must produce/consume no Water, including inside the ROI");
            roi_before_tick[arm]=worlds[arm]->water_quantity(roi);
            require(before_edit_roi==roi_before_tick[arm],"host edits must preserve ROI Water");
            water_kinds_before_tick[arm]=after_edit.kinds;
            require_bfs_reuse=require_bfs_reuse || changed;
        }
        for (int position=0;position<3;++position) {
            const auto arm=static_cast<std::size_t>((replicate+t+position)%3);
            const auto start=Clock::now(); stats[arm]=worlds[arm]->tick(); tick_ns[arm]=nanos(start);
        }
        // Every World is observed exactly once, after all three tick timers.
        std::array<Observation,3> observations;
        std::array<HeadCoverage,3> head_coverage{};
        std::array<HeadDifference,3> head_difference{};
        std::array<std::size_t,3> resident_counts{}, sampled_counts{};
        for (int position=0;position<3;++position) {
            const auto arm=static_cast<std::size_t>((replicate+t+position)%3);
            observations[arm]=observe(*worlds[arm],roi);
            resident_counts[arm]=worlds[arm]->copy_pressure_head_chunk_coordinates(chunk_coordinates[arm]);
            require(resident_counts[arm]==worlds[arm]->chunk_count() && resident_counts[arm]<=chunk_coordinates[arm].size(),"preallocated native roster observation must be complete");
            const auto first=chunk_coordinates[arm].begin(), last=first+static_cast<std::ptrdiff_t>(resident_counts[arm]);
            std::sort(first,last,[](auto a,auto b){return a.y!=b.y ? a.y<b.y : a.x<b.x;});
            require(std::adjacent_find(first,last)==last,"copied actual resident roster must contain no duplicates");
            sampled_counts[arm]=resident_counts[arm]*static_cast<std::size_t>(worlds[arm]->config().chunk_size)*static_cast<std::size_t>(worlds[arm]->config().chunk_size);
            head_coverage[arm]=sample_heads(*worlds[arm],std::span<const ChunkCoord>(chunk_coordinates[arm]).first(resident_counts[arm]),std::span<PressureHeadSnapshot>(head_samples[arm]).first(sampled_counts[arm]));
            require(observations[arm].quantities.kinds==water_kinds_before_tick[arm],"net boundary measurement requires zero tick Water sources AND sinks of every kind");
        }
        equivalent(observations[0],observations[1]); equivalent(observations[0],observations[2]);
        for (std::size_t arm=0;arm<3;++arm) {
            require(resident_counts[arm]==resident_counts[0] && std::equal(chunk_coordinates[0].begin(),chunk_coordinates[0].begin()+static_cast<std::ptrdiff_t>(resident_counts[0]),chunk_coordinates[arm].begin()),"actual resident chunk rosters must agree across pressure variants");
            head_difference[arm]=compare_heads(std::span<const PressureHeadSnapshot>(head_samples[0]).first(sampled_counts[0]),std::span<const PressureHeadSnapshot>(head_samples[arm]).first(sampled_counts[arm]));
        }
        for (std::size_t arm=0;arm<3;++arm) {
            const auto now=worlds[arm]->pressure_optimization_snapshot();
            if (require_bfs_reuse && arm!=0U)
                require(now.counters.gas_component_reuses>previous[arm].counters.gas_component_reuses,"unchanged paused room must reuse discovery on actual repair tick");
            observed[arm]=std::max(observed[arm],static_cast<std::uint64_t>(stats[arm].worker_threads_observed));
            if (t>=kCold+kWarm) disturbed_contacts[arm]+=observations[arm].contacts;
            if (t>=kCold && t<kCold+kWarm && stats[arm].visited_cells==0U) slept[arm]=true;
            std::cout<<"{\"event\":\"tick\",\"arm\":\""<<kArms[arm]<<"\",\"tick\":"<<t+1<<",\"phase\":\""<<phase(t)
                <<"\",\"order_position\":"<<(static_cast<int>(arm)-replicate-t+3*kTicks)%3
                <<",\"edit_ns\":"<<edit_ns[arm]<<",\"tick_ns\":"<<tick_ns[arm]
                <<",\"projection\":\""<<observations[arm].projection<<"\",\"quantity\":"<<observations[arm].quantity
                <<",\"gas_next_id\":"<<observations[arm].next<<",\"gas_revision\":"<<observations[arm].revision
                <<",\"gas_compartments\":"<<observations[arm].compartments.size()<<",\"gas_history\":"<<observations[arm].history.size()
                <<",\"body_contacts\":"<<observations[arm].contacts<<",\"body_impulse_x\":"<<observations[arm].impulse_x
                <<",\"body_impulse_y\":"<<observations[arm].impulse_y<<",\"visited_cells\":"<<stats[arm].visited_cells
                <<",\"moved_cells\":"<<stats[arm].moved_cells<<",\"active_blocks_after\":"<<stats[arm].active_blocks_after
                <<",\"active_chunks_before\":"<<stats[arm].active_chunks_before<<",\"active_chunks_after\":"<<stats[arm].active_chunks_after
                <<",\"dirty_chunks\":"<<stats[arm].dirty_chunks<<",\"deferred_events\":"<<stats[arm].deferred_events
                <<",\"scheduled_cores\":"<<stats[arm].scheduled_cores<<",\"worker_threads_observed\":"<<stats[arm].worker_threads_observed
                <<",\"chunk_allocations\":"<<stats[arm].chunk_allocations<<",\"temperature_field_allocations\":"<<stats[arm].temperature_field_allocations
                <<",\"phase_jobs\":[";
            for (std::size_t i=0;i<stats[arm].phase_jobs.size();++i) { if(i)std::cout<<',';std::cout<<stats[arm].phase_jobs[i]; }
            const auto& diagnostic=observations[arm].diagnostics;
            std::cout<<"],\"pressure_diagnostics\":{\"head_cells\":"<<diagnostic.head_cells<<",\"unknown_heads\":"<<diagnostic.unknown_heads
                <<",\"gas_visited\":"<<diagnostic.gas_visited<<",\"gas_regions\":"<<diagnostic.gas_regions
                <<",\"atmosphere_regions\":"<<diagnostic.atmosphere_regions<<",\"chunk_allocations\":"<<diagnostic.chunk_allocations
                <<",\"woken_blocks\":"<<diagnostic.woken_blocks<<"},\"counter_delta\":"; counters_json(previous[arm].counters,now.counters);
            const auto net_inflow=static_cast<std::int64_t>(observations[arm].roi_quantity)-static_cast<std::int64_t>(roi_before_tick[arm]);
            std::cout<<",\"prepared_head\":"; heads_json(head_coverage[arm],head_difference[arm]);
            std::cout<<",\"boundary_water\":{\"start_quantity\":"<<roi_before_tick[arm]<<",\"end_quantity\":"<<observations[arm].roi_quantity
                <<",\"host_produced\":0,\"host_consumed\":0,\"tick_produced\":0,\"tick_consumed\":0,\"net_inflow\":"<<net_inflow<<",\"balance_residual\":0}";
            std::cout<<",\"memory\":"; snapshot_json(*worlds[arm],now); std::cout<<"}\n";
            previous[arm]=now;
        }
        if (t==kCold+kWarm-1) warm_end=previous;
    }
    if (profile==kProfiles[0]) {
        require(warm_end[2].counters.certificate_saved_calls>warm_start[2].counters.certificate_saved_calls,
                "positive awake fixture must actually save motion calls during warm measurement");
        for (std::size_t arm=0;arm<3;++arm) {
            require(warm_end[arm].counters.other_liquid_calls>warm_start[arm].counters.other_liquid_calls,
                    "mandatory other-liquid stages must continue in awake blocks");
            require(worlds[arm]->stored_material(24,24)==Material::Oil && worlds[arm]->stored_state_b(24,24)<200U,
                    "actual isolated Oil lifecycle must advance");
        }
    }
    if (profile==kProfiles[1]) for (const auto arm_slept : slept)
        require(arm_slept,"each arm of the ordinary sleeping negative must reach a zero-visit warm tick");
    if (profile==kProfiles[3]) require(disturbed_contacts[0]>0U,"moving-mask profile must generate real native body contacts");
    if (profile==kProfiles[4]) require(previous[1].counters.index_rebuilds>2U,"membership churn must actually rebuild the derived index");
    if (profile==kProfiles[5]) for (std::size_t arm=1;arm<3;++arm) {
        const auto& c=previous[arm].counters;
        if (fallback=="index" || fallback=="head") require(c.reference_fallbacks>0U,"head/index capacity fallback must execute");
        if (fallback=="member") require(c.gas_capacity_fallbacks>0U,"member capacity fallback must execute");
        if (fallback=="pair") require(c.gas_budget_fallbacks>0U,"pair budget fallback must execute");
    }
    for (std::size_t arm=0;arm<3;++arm) require(observed[arm]>0U,"a claimed worker configuration must observe actual jobs");
    std::cout<<"{\"event\":\"complete\",\"valid\":true,\"peak_rss_bytes\":"<<peak_rss_bytes()<<",\"max_observed_participants\":["
        <<observed[0]<<','<<observed[1]<<','<<observed[2]<<"],\"parity_ticks\":"<<kTicks<<"}\n";
    return 0;
}
} // namespace

int main(int argc, char** argv) {
    try {
        require(argc==4 || argc==5,"usage: lcb_pressure_optimization PROFILE WORKERS REPLICATE [index|head|member|pair]");
        const std::string_view profile=argv[1], fallback=argc==5 ? argv[4] : "none";
        require(std::find(kProfiles.begin(),kProfiles.end(),profile)!=kProfiles.end(),"unknown registered profile");
        const auto workers=integer(argv[2],1,4); require(workers==1 || workers==4,"registered workers are 1 or 4");
        const auto replicate=integer(argv[3],0,4);
        require((profile==kProfiles[5] && std::find(kFallbacks.begin(),kFallbacks.end(),fallback)!=kFallbacks.end()) ||
                (profile!=kProfiles[5] && fallback=="none"),"fallback subcase must match profile");
        return run(profile,fallback,static_cast<std::uint32_t>(workers),replicate);
    } catch (const std::exception& e) {
        std::cerr<<"LCB-002 total-cost apparatus refused: "<<e.what()<<'\n'; return 1;
    }
}
