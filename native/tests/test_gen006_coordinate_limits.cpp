// GEN-006 #194: signed i64 native chunk-admission edge and CYPS restore control.
// EXPERIMENT ONLY. No selective eviction, actor owner, mutation journal or format admission.
#include "cybersand/world.hpp"
#include <algorithm>
#include <cstdint>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <vector>

namespace {
using namespace cybersand;
constexpr std::int64_t kSide = 128;
std::uint64_t checks = 0;
void require(bool yes, const char* why) {
    ++checks;
    if (!yes) throw std::runtime_error(why);
}
WorldConfig config(std::uint32_t workers) {
    WorldConfig c{};
    c.chunk_size = static_cast<std::int32_t>(kSide);
    c.backend = SimulationBackend::PhasedInPlace;
    c.worker_threads = workers;
    c.parallel_job_threshold = 1;
    c.initial_chunk_reserve = 12;
    c.maximum_chunk_count = 12;
    c.active_chunk_capacity = 128;
    c.active_core_capacity = 2048;
    c.deferred_event_capacity = 128;
    return c;
}
std::vector<Material> payload() {
    std::vector<Material> p(static_cast<std::size_t>(kSide*kSide), Material::Empty);
    for (int cy : {30, 94}) for (int cx : {30, 94}) {
        for (int x = cx-4; x <= cx+4; ++x) {
            p[static_cast<std::size_t>((cy+4)*kSide+x)] = Material::Wall;
            p[static_cast<std::size_t>((cy-4)*kSide+x)] = Material::Wall;
        }
        for (int y = cy-4; y <= cy+4; ++y) {
            p[static_cast<std::size_t>(y*kSide+cx-4)] = Material::Wall;
            p[static_cast<std::size_t>(y*kSide+cx+4)] = Material::Wall;
        }
        p[static_cast<std::size_t>(cy*kSide+cx)] = Material::Water;
    }
    return p;
}
void cohort(std::uint32_t workers) {
    const auto c = config(workers);
    const auto p = payload();
    // Ordinary signed chunks establish an independent native worker control.
    // The extreme-coordinate cohort now also performs real phased ticks.
    World running(c);
    for (int i=0; i<8; ++i) {
        require(running.install_generated_chunk({static_cast<std::int64_t>(i*2-2),0},p)
                    == ChunkInstallOutcome::Installed, "native worker fixture admission");
    }
    std::uint32_t observed=0;
    for (int i=0; i<2; ++i) {
        const auto stats=running.tick();
        require(!running.has_failed(), "worker control tick quarantined");
        observed=std::max(observed,stats.worker_threads_observed);
    }
    require(observed>=1 && observed<=workers, "impossible worker observation");

    // With 128-cell chunks and a two-cell rule halo, the extreme quotient
    // is NOT a legal origin even though the multiplication itself fits i64.
    constexpr auto min=std::numeric_limits<std::int64_t>::min();
    constexpr auto max=std::numeric_limits<std::int64_t>::max();
    const auto qmin=min/kSide, qmax=max/kSide;
    const auto valid_lo=qmin+1, valid_hi=qmax-1;
    World edges(c);
    const ChunkCoord legal[] = {
        {valid_lo,0}, {valid_hi,0}, {0,valid_lo}, {0,valid_hi},
        {-1,0}, {0,0}
    };
    for (auto cc:legal) {
        require(edges.install_generated_chunk(cc,p)==ChunkInstallOutcome::Installed,
                "near-limit or signed-seam native admission failed");
    }
    require(edges.chunk_count()==6, "unexpected legal chunk count");
    const auto original_count=edges.chunk_count();
    const auto original_hash=edges.physical_state_hash();
    const ChunkCoord impossible[] = {
        {qmin,0}, {qmax,0}, {0,qmin}, {0,qmax},
        {min,0}, {max,0}, {0,min}, {0,max}
    };
    for (auto cc:impossible) {
        require(edges.install_generated_chunk(cc,p)==ChunkInstallOutcome::CoordinateOverflow,
                "unrepresentable coordinate was not refused");
        require(edges.chunk_count()==original_count &&
                edges.physical_state_hash()==original_hash,
                "rejected coordinate modified native authority");
    }
    // The admitted edge cell origin remains representable with an active rule halo.
    const auto xlo=valid_lo*kSide+30, xhi=valid_hi*kSide+30;
    const auto ylo=valid_lo*kSide+30, yhi=valid_hi*kSide+30;
    require(edges.stored_material(xlo,30)==Material::Water &&
            edges.stored_material(xhi,30)==Material::Water &&
            edges.stored_material(30,ylo)==Material::Water &&
            edges.stored_material(30,yhi)==Material::Water,
            "signed extreme floor-address alias or lookup mismatch");
    // Explicit material erasure survives a current-state snapshot. This is NOT
    // proof of an edit-intent tombstone or future baseline-reconciliation safety.
    require(edges.stored_material(valid_lo*kSide+26,34)==Material::Wall,
            "edge Wall target missing");
    require(edges.set_cell_state(valid_lo*kSide+26,34,Material::Empty,0,0),
            "edge native Empty mutation failed");
    require(edges.set_cell_state(xhi,30,Material::Water,17,0),
            "edge native Water17 mutation failed");
    edges.set_temperature(xlo,30,417);
    require(edges.stored_temperature(xlo,30)==417 &&
            edges.stored_state_a(xhi,30)==17 && edges.liquid_mass(xhi,30)==17,
            "native optional temperature or Water tuple missing");
    const auto before=edges.physical_state_hash();
    const auto bytes=edges.save_physical_state();
    require(!bytes.empty() && bytes.size() < 16*1024*1024,
            "edge native whole-World checkpoint absent/unbounded");
    auto restored=World::restore_physical_state(c,bytes);
    require(restored && restored->chunk_count()==6 &&
            restored->physical_state_hash()==before, "edge snapshot roundtrip mismatch");
    require(restored->stored_material(valid_lo*kSide+26,34)==Material::Empty &&
            restored->stored_state_a(xhi,30)==17 && restored->liquid_mass(xhi,30)==17 &&
            restored->stored_temperature(xlo,30)==417 &&
            restored->stored_material(30,yhi)==Material::Water,
            "edge native post-restart fields/alias mismatch");
    // Reject a second attempt on any already-resident chunk, including its
    // Empty cells, without disturbing the restored authoritative checkpoint.
    require(restored->install_generated_chunk({valid_lo,0},p)==
            ChunkInstallOutcome::AlreadyResident, "resident edge replacement accepted");
    require(restored->physical_state_hash()==before, "resident refusal mutated state");
    // Separate from admission: exercise the actual phased native scheduler at
    // the representable i64 boundaries, then compare independently executed
    // original/restored Worlds after every successful fixed tick. This does not
    // implement an eviction/reload transaction or certify historical imports.
    std::uint32_t edge_tick_workers = 0;
    std::uint32_t restored_tick_workers = 0;
    for (int step=0; step<3; ++step) {
        const auto a = edges.tick();
        const auto b = restored->tick();
        edge_tick_workers = std::max(edge_tick_workers, a.worker_threads_observed);
        restored_tick_workers = std::max(restored_tick_workers, b.worker_threads_observed);
        require(!edges.has_failed() && !restored->has_failed(),
                "extreme-coordinate native tick quarantined");
        require(edges.completed_tick_index()==restored->completed_tick_index(),
                "extreme-coordinate original/restored clock drift");
        require(edges.physical_state_hash()==restored->physical_state_hash(),
                "extreme-coordinate fixed-tick physical state diverged");
        require(edges.chunk_count()==6 && restored->chunk_count()==6,
                "extreme-coordinate tick unexpectedly changed residency");
    }
    require(edge_tick_workers>=1 && edge_tick_workers<=workers &&
            restored_tick_workers>=1 && restored_tick_workers<=workers,
            "extreme-coordinate tick did not observe valid native worker participation");
    const auto continuation_hash=edges.physical_state_hash();
    const auto continuation_checkpoint=edges.save_physical_state();
    require(!continuation_checkpoint.empty() &&
            continuation_checkpoint.size()<16*1024*1024,
            "extreme-coordinate post-tick checkpoint absent/unbounded");
    auto resumed=World::restore_physical_state(c,continuation_checkpoint);
    require(resumed && resumed->physical_state_hash()==continuation_hash &&
            resumed->completed_tick_index()==edges.completed_tick_index(),
            "extreme-coordinate post-tick native checkpoint restore mismatch");
    std::cout << "GEN006_NATIVE_COORD_LIMIT_JSON {\"configured_workers\":"<<workers
              <<",\"actual_observed_workers\":"<<observed
              <<",\"resident_edge_chunks\":6,\"rejected_coordinates\":8"
              <<",\"min_accepted_chunk\":"<<valid_lo
              <<",\"max_accepted_chunk\":"<<valid_hi
              <<",\"checkpoint_bytes\":"<<bytes.size()
              <<",\"extreme_tick_workers\":"<<edge_tick_workers
              <<",\"restored_tick_workers\":"<<restored_tick_workers
              <<",\"continuation_checkpoint_bytes\":"<<continuation_checkpoint.size()
              <<",\"continuation_at_extreme\":\"three_native_ticks\""
              <<",\"result\":\"PASS\"}\n";
}

// Cross-seam queued-event continuation under an excluded native interest
// region. Current interest filtering pauses ordinary rules; explicit owner
// events still commit. Preserve this exact distinction across CYPS restart.
// This is WHOLE-WORLD restore, not per-chunk eviction or saved edit intent.
void pending_event_region_cohort(std::uint32_t workers, bool remote_parallel) {
    const auto c = config(workers);
    const auto p = payload();
    World original(c);
    for (int i = 0; i < 8; ++i) {
        require(original.install_generated_chunk(
                    {static_cast<std::int64_t>(i-2), 0}, p) ==
                    ChunkInstallOutcome::Installed,
                "cross-seam native setup admission refused");
    }
    // The event blast spans the signed chunk seam x=-1/0. It must not be
    // silently treated as a discardable generated resident region.
    for (std::int64_t y = 36; y <= 44; ++y) {
        for (std::int64_t x = -4; x <= 3; ++x) {
            original.set(x, y, Material::Wall);
        }
    }
    require(original.stored_material(-1, 40) == Material::Wall &&
                original.stored_material(0, 40) == Material::Wall,
            "cross-seam explosion setup lacks native walls");
    // Two distinct native execution controls: the original one-core distant
    // region, and a multi-core distant region spanning separate resident chunks.
    // In both cases the signed seam x=-1/0 remains outside scheduled work;
    // a queued owner event must still run once while unrelated cells are active.
    const RectI64 far_region = remote_parallel
        ? RectI64{128, 0, 640, 128} : RectI64{256, 0, 64, 64};
    original.set_simulation_region(far_region);
    const auto before_event = original.physical_state_hash();
    require(original.queue_explosion(-1, 40, 2, 255),
            "signed-seam queued native explosion refused");
    const auto queued_hash = original.physical_state_hash();
    require(queued_hash != before_event,
            "pending native event omitted from physical checkpoint identity");
    const auto checkpoint = original.save_physical_state();
    require(!checkpoint.empty() && checkpoint.size() < 16*1024*1024,
            "cross-seam native checkpoint absent or oversized");
    auto restored = World::restore_physical_state(c, checkpoint);
    require(restored && restored->chunk_count() == 8 &&
                restored->physical_state_hash() == queued_hash &&
                restored->completed_tick_index() == original.completed_tick_index(),
            "pending-event/restored-interest native state mismatch");
    require(restored->save_physical_state() == checkpoint,
            "pending-event CYPS roundtrip changed canonical bytes");

    const auto a = original.tick();
    const auto b = restored->tick();
    require(!original.has_failed() && !restored->has_failed(),
            "cross-seam event execution quarantined native World");
    require(a.deferred_events == 1 && b.deferred_events == 1,
            "pending event was lost or not executed once after restore");
    require(original.stored_material(-1, 40) == Material::Fire &&
                original.stored_material(0, 40) == Material::Empty,
            "excluded-region external event did not update signed seam");
    require(original.physical_state_hash() == restored->physical_state_hash(),
            "cross-seam event original/restored native hash mismatch");

    std::uint32_t observed_original = a.worker_threads_observed;
    std::uint32_t observed_restored = b.worker_threads_observed;
    std::uint32_t far_original = a.worker_threads_observed;
    std::uint32_t far_restored = b.worker_threads_observed;
    for (int step=0; step<5; ++step) {
        if (step==0 || step==3) {
            const auto region = step==0
                ? RectI64{-64, 0, 128, 128} : far_region;
            original.set_simulation_region(region);
            restored->set_simulation_region(region);
        }
        const auto x=original.tick(), y=restored->tick();
        observed_original=std::max(observed_original,x.worker_threads_observed);
        observed_restored=std::max(observed_restored,y.worker_threads_observed);
        if (step >= 3) {
            far_original = std::max(far_original, x.worker_threads_observed);
            far_restored = std::max(far_restored, y.worker_threads_observed);
        }
        require(x.deferred_events==0 && y.deferred_events==0,
                "previously executed native event replayed");
        require(!original.has_failed() && !restored->has_failed() &&
                    original.completed_tick_index()==restored->completed_tick_index() &&
                    original.physical_state_hash()==restored->physical_state_hash(),
                "native pause/re-entry event continuation diverged");
    }
    const auto final_bytes=original.save_physical_state();
    auto next=World::restore_physical_state(c,final_bytes);
    require(next && next->physical_state_hash()==original.physical_state_hash(),
            "post-reentry native continuation checkpoint invalid");
    require(observed_original<=workers && observed_restored<=workers &&
                far_original<=workers && far_restored<=workers,
            "invalid reported native worker participation");
    // This assertion is deliberately workload-specific. Configuring four
    // workers does not prove they participated; the distributed remote cells
    // must produce multiple actual observed native pool-worker identities.
    if (remote_parallel && workers == 4) {
        require(far_original >= 2 && far_restored >= 2,
                "four configured workers never shared distant native work");
    }
    std::cout << "GEN006_NATIVE_EVENT_REGION_JSON {\"configured_workers\":" << workers
              << ",\"observed_original\":" << observed_original
              << ",\"observed_restored\":" << observed_restored
              << ",\"remote_parallel\":" << (remote_parallel ? "true" : "false")
              << ",\"far_original_workers\":" << far_original
              << ",\"far_restored_workers\":" << far_restored
              << ",\"chunks\":8,\"pending_events\":1,\"executed_events\":1"
              << ",\"continuation_ticks\":6,\"interest_reentries\":1"
              << ",\"signed_chunk_seam\":true,\"checkpoint_bytes\":" << checkpoint.size()
              << ",\"result\":\"PASS\"}\n";
}

}
int main() {
    try {
        cohort(1);
        cohort(4);
        pending_event_region_cohort(1, false);
        pending_event_region_cohort(4, false);
        pending_event_region_cohort(1, true);
        pending_event_region_cohort(4, true);
        std::cout<<"GEN006_NATIVE_COORD_LIMIT_PASS assertions="<<checks<<"\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr<<"GEN006_NATIVE_COORD_LIMIT_FAIL assertions="<<checks
                 <<" error="<<e.what()<<"\n";
        return 1;
    }
}
