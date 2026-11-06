// GEN-006 #194: signed i64 native chunk-admission edge and CYPS restore control.
// EXPERIMENT ONLY. No selective eviction, actor owner, mutation journal or format admission.
#include "cybersand/world.hpp"
#include "cybersand/sha256.hpp"
#include <algorithm>
#include <cstdint>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <span>
#include <string>
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


// Signed-digest hostile-input control: integrity is necessary, not a schema gate.
// Re-sign each synthetic fault with the same canonical SHA-256 implementation
// used by the real CYPS codec. This is NOT a new storage or import format.
void signed_malformed_checkpoint_cohort(std::uint32_t workers) {
    const auto c = config(workers);
    std::vector<Material> p(static_cast<std::size_t>(kSide*kSide), Material::Empty);
    p[0] = Material::Water;
    p[1] = Material::Wall;
    World live(c);
    require(live.install_generated_chunk({-1,0},p) == ChunkInstallOutcome::Installed,
            "signed-fault native baseline admission");
    require(live.set_cell_state(-128,0,Material::Water,17,0),
            "signed-fault Water17 setup failed");
    require(live.set_cell_state(-127,0,Material::Empty,0,0),
            "signed-fault Empty tombstone setup failed");
    live.set_temperature(-128,0,417);
    const auto hash = live.physical_state_hash();
    const auto good = live.save_physical_state();
    require(good.size() > 32U && good.size() < 1024U*1024U,
            "signed-fault real CYPS checkpoint absent or too large");
    auto valid = World::restore_physical_state(c,good);
    require(valid && valid->physical_state_hash()==hash &&
            valid->stored_material(-127,0)==Material::Empty &&
            valid->stored_state_a(-128,0)==17 &&
            valid->liquid_mass(-128,0)==17 &&
            valid->stored_temperature(-128,0)==417,
            "signed-fault pristine native continuation state invalid");

    // Inspect only the established CYPS2 little-endian layout, with bounds
    // checks and asserted counts. No hard-coded cell offsets or guessed policy
    // lengths: derive those from the actual native snapshot.
    auto read = [&](std::size_t at, unsigned n) -> std::uint64_t {
        require(n<=8U && at <= good.size()-32U &&
                n <= good.size()-32U-at, "CYPS cursor exceeds native body");
        std::uint64_t result=0;
        for (unsigned i=0;i<n;++i)
            result |= static_cast<std::uint64_t>(good[at+i])<<(8U*i);
        return result;
    };
    std::size_t cursor=0;
    auto take=[&](std::size_t n)->std::size_t {
        require(cursor<=good.size()-32U && n<=good.size()-32U-cursor,
                "CYPS native envelope truncated during test discovery");
        const auto at=cursor; cursor+=n; return at;
    };
    take(8); // magic and version
    take(4*5+2+1+4+1+2+1+1+4+1+1+1); // native config through Water policy
    const auto transport_count_at=take(4);
    const auto transport_count=read(transport_count_at,4);
    require(transport_count<=TransportPolicy::packed_size,
            "test baseline contains unexpected transport length");
    take(static_cast<std::size_t>(transport_count)*4U);
    const auto envelope_count_at=take(4);
    const auto envelope_count=read(envelope_count_at,4);
    require(envelope_count<=4096U,"test baseline contains oversized policy envelope");
    take(static_cast<std::size_t>(envelope_count)*4U);
    take(8); // tick_index
    const auto completed_tick_at=take(8);
    take(1+8+1); // update epoch, hard surface revision, adhesion
    const auto interest_at=take(1);
    require(read(interest_at,1)==0U,"test baseline unexpectedly has interest region");
    const auto applied_at=take(1);
    require(read(applied_at,1)==0U,"test baseline unexpectedly has applied core range");
    const auto events_at=take(4);
    require(read(events_at,4)==0U,"test baseline unexpectedly has queued events");
    const auto chunks_at=take(4);
    require(read(chunks_at,4)==1U,"test baseline must contain exactly one native chunk");
    const auto coord_at=take(16);
    const auto flags_at=take(1);
    require((read(flags_at,1)&~1U)==0U,"test baseline contains unexpected native sidecar");
    const auto blocks_at=take(4);
    const auto block_count=read(blocks_at,4);
    require(block_count==16U,"test baseline block layout changed");
    take(static_cast<std::size_t>(block_count)*13U); // active, quiet, next deadline
    const auto first_cell_at=cursor;
    require(read(first_cell_at,2)==static_cast<std::uint16_t>(Material::Water),
            "test baseline first native cell is not Water");
    require(read(first_cell_at+2U,2)==17U,
            "test baseline first Water mass is not 17");
    require(read(first_cell_at+6U,2)==static_cast<std::uint16_t>(Material::Empty),
            "test baseline second native cell is not explicit Empty");

    auto put=[](std::vector<std::uint8_t>& bytes, std::size_t at,
                std::uint64_t value, unsigned width) {
        for (unsigned i=0;i<width;++i)
            bytes[at+i]=static_cast<std::uint8_t>(value>>(8U*i));
    };
    auto seal=[](std::vector<std::uint8_t>& bytes) {
        const auto content=std::span<const std::uint8_t>(bytes.data(),bytes.size()-32U);
        const auto digest=Sha256::of(content);
        std::copy(digest.begin(),digest.end(),bytes.end()-32);
    };
    std::uint32_t refused=0;
    auto negative=[&](const char* label, const char* expected,
                      std::vector<std::uint8_t> bytes, bool resign) {
        if(resign) seal(bytes);
        else require(bytes!=good,"unsigned corruption fixture has no mutation");
        if(resign) {
            const auto body=std::span<const std::uint8_t>(bytes.data(),bytes.size()-32U);
            const auto digest=Sha256::of(body);
            require(std::equal(digest.begin(),digest.end(),bytes.end()-32),
                    "signed malformed fixture digest is not authentic");
        }
        bool rejected=false;
        try { auto candidate=World::restore_physical_state(c,bytes); (void)candidate; }
        catch(const std::invalid_argument& e) {
            rejected=true;
            require(std::string(e.what()).find(expected)!=std::string::npos,
                    "unexpected native malformed-state refusal reason");
        }
        require(rejected,"native accepted signed invalid physical state");
        require(live.physical_state_hash()==hash &&
                    live.save_physical_state()==good &&
                    live.chunk_count()==1 &&
                    live.stored_material(-127,0)==Material::Empty &&
                    live.liquid_mass(-128,0)==17,
                "failed candidate import touched still-live authoritative native World");
        ++refused;
        std::cout << "GEN006_NATIVE_SIGNED_REFUSAL_JSON {\"workers\":"<<workers
                  <<",\"case\":\""<<label<<"\",\"expected\":\""<<expected
                  <<"\",\"digest_recomputed\":"<<(resign?"true":"false")
                  <<",\"result\":\"REFUSED\"}\n";
    };
    auto mutate=[&](const char* name, const char* expected, std::size_t at,
                    std::uint64_t value, unsigned width) {
        auto bytes=good;
        put(bytes,at,value,width);
        negative(name,expected,std::move(bytes),true);
    };
    mutate("bad_magic","bad magic",0,0,4);
    mutate("future_format","unknown format version",4,99,4);
    mutate("invalid_backend","unknown backend",30,255,1);
    mutate("unsupported_water_policy","unsupported Water semantics",44,2,1);
    mutate("oversized_policy_envelope","liquid policy envelope too large",
           envelope_count_at,4097,4);
    mutate("incomplete_tick","not a completed tick boundary",completed_tick_at,1,8);
    mutate("overcapacity_event_count","too many pending events",events_at,
           c.deferred_event_capacity+1,4);
    mutate("overcapacity_chunk_count","chunk count exceeds capacity",chunks_at,
           c.maximum_chunk_count+1,4);
    mutate("chunk_coordinate_overflow","chunk coordinate overflow",coord_at,
           std::numeric_limits<std::int64_t>::max(),8);
    mutate("unknown_chunk_flags","unknown chunk flags",flags_at,0x80U,1);
    mutate("activity_block_mismatch","activity block count mismatch",blocks_at,0,4);
    mutate("unknown_material","invalid material",first_cell_at,65535,2);
    mutate("zero_water_quantity","Water state outside the experiment policy",
           first_cell_at+2U,0,2);
    mutate("nonwater_state_overflow","byte state out of domain",
           first_cell_at+6U+2U,256,2);
    {
        auto bytes=good;
        bytes.insert(bytes.end()-32,0xff);
        negative("authenticated_trailing_bytes","trailing bytes",std::move(bytes),true);
    }
    {
        auto bytes=good; bytes[first_cell_at]^=0x80U;
        negative("tampered_digest","integrity digest mismatch",std::move(bytes),false);
    }
    {
        std::vector<std::uint8_t> bytes{0U,1U};
        // This intentionally cannot carry a digest.
        negative("short_file","payload is too short",std::move(bytes),false);
    }
    require(refused==17U,"signed malformed-state case census changed");
    std::cout << "GEN006_NATIVE_SIGNED_REFUSAL_PASS {\"workers\":"<<workers
              <<",\"cases\":"<<refused<<",\"bytes\":"<<good.size()
              <<",\"source\":\"native_World_CYPS2\",\"result\":\"PASS\"}\n";
}


// Native decision witness for GEN-006: the existing "dirty" queue is a
// consumable presentation hint, NOT a durable mutation journal or save ACK.
// Two valid snapshots bracket a later explicit Empty edit across signed chunks.
// Draining every render hint leaves a newer authoritative mutation unsaved by
// the older checkpoint. No production write path or persistence format is added.
void render_dirty_not_persistent_ack_cohort(std::uint32_t workers) {
    const auto c = config(workers);
    std::vector<Material> p(static_cast<std::size_t>(kSide*kSide), Material::Empty);
    p[0] = Material::Wall;
    p[1] = Material::Wall;
    p[2] = Material::Water;
    World live(c);
    require(live.install_generated_chunk({-1,0}, p)==ChunkInstallOutcome::Installed &&
            live.install_generated_chunk({0,0}, p)==ChunkInstallOutcome::Installed,
            "render-dirty witness failed to admit signed native chunks");
    // Admission itself may dirty the presentation; consume it before editing.
    (void)live.take_dirty_chunks();
    require(live.dirty_chunk_count()==0U &&
            live.stored_material(-128,0)==Material::Wall &&
            live.stored_material(0,0)==Material::Wall,
            "render-dirty witness initial state invalid");

    require(live.set_cell_state(-128,0,Material::Empty,0,0) &&
            live.set_cell_state(2,0,Material::Water,17,0),
            "render-dirty witness first native mutation refused");
    live.set_temperature(2,0,417);
    require(live.dirty_chunk_count()==2U,
            "first signed-chunk edits did not mark both presentation regions");
    const auto earlier = live.save_physical_state();
    const auto earlier_hash = live.physical_state_hash();
    require(!earlier.empty() && earlier.size()<1024U*1024U,
            "first genuine whole-World CYPS checkpoint invalid");
    require(live.take_dirty_chunks().size()==2U &&
            live.dirty_chunk_count()==0U,
            "presentation collection did not consume both dirty hints");
    // A valid earlier snapshot is in flight; the second edit must not become
    // persistently clean merely because the renderer consumed its notification.
    require(live.set_cell_state(0,0,Material::Empty,0,0),
            "later explicit Empty tombstone refused");
    require(live.dirty_chunk_count()==1U,
            "later signed-seam edit did not mark presentation dirty");
    const auto newer = live.save_physical_state();
    const auto newer_hash = live.physical_state_hash();
    require(newer!=earlier && newer_hash!=earlier_hash,
            "later native mutation not reflected in physical checkpoint");
    require(live.take_dirty_chunks().size()==1U &&
            live.dirty_chunk_count()==0U &&
            live.stored_material(0,0)==Material::Empty,
            "render drain incorrectly equated with native mutation recovery");

    auto old_world=World::restore_physical_state(c,earlier);
    auto new_world=World::restore_physical_state(c,newer);
    require(old_world && new_world &&
            old_world->physical_state_hash()==earlier_hash &&
            new_world->physical_state_hash()==newer_hash,
            "both native revision snapshots failed independent decoder restore");
    require(old_world->stored_material(-128,0)==Material::Empty &&
            old_world->stored_material(0,0)==Material::Wall &&
            new_world->stored_material(0,0)==Material::Empty &&
            new_world->stored_material(-128,0)==Material::Empty,
            "stale native checkpoint did not demonstrably omit later Empty edit");
    require(old_world->stored_state_a(2,0)==17U &&
            new_world->stored_state_a(2,0)==17U &&
            old_world->liquid_mass(2,0)==17U &&
            new_world->liquid_mass(2,0)==17U &&
            old_world->stored_temperature(2,0)==417 &&
            new_world->stored_temperature(2,0)==417,
            "native Water/temperature continuity lost in revision control");
    require(live.chunk_count()==2U && !live.has_failed() &&
            live.physical_state_hash()==newer_hash &&
            live.save_physical_state()==newer,
            "render notification consumption modified physical authority");
    // There are intentionally zero ticks here, thus no observed pool workers.
    // Existing event and edge cohorts separately qualify real pool workers.
    std::cout << "GEN006_NATIVE_RENDER_DIRTY_NOT_SAVE_ACK_JSON {\"configured_workers\":"
              << workers << ",\"actual_pool_workers\":0,\"chunks\":2"
              << ",\"render_dirty_after_both_drains\":0"
              << ",\"earlier_checkpoint_bytes\":" << earlier.size()
              << ",\"newer_checkpoint_bytes\":" << newer.size()
              << ",\"older_restore_misses_later_empty\":true"
              << ",\"water_mass\":17,\"temperature\":417"
              << ",\"native_selective_eviction\":false,\"result\":\"PASS\"}\n";
}


// Native GEN-006 continuation gap: a simulation tick can change true physical
// cells/Water mass distribution without a new player/host edit. A rendered
// dirty notification is consumable and does not become a durable save ACK.
// This is a whole-World negative/control only: NO production mutation journal,
// selective eviction, new schema, actor restore, or authority/policy change.
void simulation_only_persistence_gap_cohort(std::uint32_t workers) {
    const auto c = config(workers);
    const auto p = payload();
    World live(c);
    for (int i = 0; i < 8; ++i) {
        require(live.install_generated_chunk({static_cast<std::int64_t>(i-2),0},p) ==
                    ChunkInstallOutcome::Installed,
                "simulation-only setup native chunk admission failed");
    }
    constexpr std::int64_t wx = -128 + 30;
    require(live.set_cell_state(wx,30,Material::Water,17,0),
            "simulation-only Water17 initialization refused");
    auto water_in_box = [](const World& w) -> std::uint64_t {
        std::uint64_t total = 0;
        for (std::int64_t y=27; y<=33; ++y)
            for (std::int64_t x=wx-3; x<=wx+3; ++x)
                total += w.liquid_mass(x,y);
        return total;
    };
    // Fingerprint ONLY actual native cell tuples (not tick-index, render dirty,
    // cumulative counters or configuration). The prepared boxes are sealed,
    // so Water17 should remain within the interior across ordinary ticks.
    auto cell_fingerprint = [](const World& w) -> std::uint64_t {
        std::uint64_t value=14695981039346656037ULL;
        auto mix=[&](std::uint64_t x) {
            value^=x;
            value*=1099511628211ULL;
        };
        for(int chunk=-2; chunk<6; ++chunk) {
            const auto x0=static_cast<std::int64_t>(chunk)*kSide;
            for (int cy : {30,94}) for (int cx : {30,94}) {
                for (std::int64_t y=cy-3;y<=cy+3;++y) {
                    for (std::int64_t x=x0+cx-3;x<=x0+cx+3;++x) {
                        mix(static_cast<std::uint16_t>(w.stored_material(x,y)));
                        mix(w.stored_state_a(x,y));
                        mix(w.stored_state_b(x,y));
                        mix(static_cast<std::uint16_t>(w.stored_temperature(x,y)));
                    }
                }
            }
        }
        return value;
    };
    require(water_in_box(live)==17U,"native Water17 box setup quantity mismatch");
    (void)live.take_dirty_chunks();
    require(live.dirty_chunk_count()==0U,
            "simulation-only setup still has presentation notifications");
    const auto old_cells=cell_fingerprint(live);
    const auto old_snapshot=live.save_physical_state();
    require(!old_snapshot.empty() && old_snapshot.size()<4U*1024U*1024U,
            "simulation-only pre-tick CYPS snapshot absent or oversized");
    // After this point the host makes NO explicit edit. The native worker
    // scheduler alone mutates cells. Observe real participating workers.
    std::uint32_t actually_participating=0;
    for(int i=0;i<8;++i) {
        const auto stats=live.tick();
        actually_participating=std::max(actually_participating,stats.worker_threads_observed);
        require(!live.has_failed(),"simulation-only native tick failed");
    }
    const auto new_cells=cell_fingerprint(live);
    require(old_cells!=new_cells,
            "native simulation did not evolve any observed cell tuples");
    require(water_in_box(live)==17U,
            "sealed native Water17 box lost/gained quantity");
    require(actually_participating>=1U && actually_participating<=workers,
            "native simulation-only fixture missing valid actual worker witness");
    const auto render_hints=live.take_dirty_chunks();
    require(!render_hints.empty() && live.dirty_chunk_count()==0U,
            "native simulation changed cells but render notifications did not drain");
    const auto new_snapshot=live.save_physical_state();
    require(new_snapshot!=old_snapshot && new_snapshot.size()<4U*1024U*1024U,
            "native simulated changes missing from newer CYPS snapshot");
    // TEST-ONLY external persistence-owner model. A native checkpoint was
    // captured before the next eight real simulation ticks; those ticks, not
    // another player edit, create a newer revision. The native World currently
    // exposes no per-chunk persistent mutation-generation or durable ACK API.
    struct SimSaveReceipt {
        std::uint64_t session;
        std::uint64_t incarnation;
        std::uint64_t generation;
    };
    struct SimSaveOwnerFence {
        std::uint64_t session;
        std::uint64_t incarnation;
        std::uint64_t current_generation;
        std::uint64_t durable_generation;
        bool acknowledge(const SimSaveReceipt& r, bool durable_publication) {
            if (!durable_publication || r.session != session ||
                r.incarnation != incarnation ||
                r.generation != current_generation ||
                r.generation <= durable_generation) return false;
            durable_generation=r.generation;
            return true;
        }
        bool can_evict() const {
            return durable_generation == current_generation;
        }
    };
    SimSaveOwnerFence owner{73, 11, 1, 0};
    const SimSaveReceipt before_ticks{73,11,1};
    const SimSaveReceipt after_ticks{73,11,2};
    // Generation change is intentionally external, conservative and test-only:
    // its source is verified native simulation progress, not the display flag.
    owner.current_generation=2;
    require(!owner.can_evict(),
            "simulator mutation incorrectly eligible for eviction before ACK");

    auto old_world=World::restore_physical_state(c,old_snapshot);
    auto current_world=World::restore_physical_state(c,new_snapshot);
    require(old_world && current_world &&
            cell_fingerprint(*old_world)==old_cells &&
            cell_fingerprint(*current_world)==new_cells &&
            old_world->completed_tick_index()==0U &&
            current_world->completed_tick_index()==8U,
            "simulator-produced cell changes were not distinguished by native restart");
    require(live.dirty_chunk_count()==0U &&
            cell_fingerprint(live)==new_cells &&
            water_in_box(*current_world)==17U,
            "consuming render hints unexpectedly changed physical Water authority");
    // Negative control: a completion-only boolean would mark the owner clean
    // using the *older* checkpoint, even though real later cell tuples differ.
    bool unsafe_completion_only_clean=false;
    unsafe_completion_only_clean=true; // simulated successful older save
    require(unsafe_completion_only_clean && old_cells!=new_cells &&
            cell_fingerprint(*old_world)!=cell_fingerprint(live),
            "stale native checkpoint did not demonstrate unsafe naive completion");
    require(!owner.acknowledge(before_ticks,true) && !owner.can_evict(),
            "late pre-simulation save cleared newer native mutation generation");
    require(!owner.acknowledge(after_ticks,false) && !owner.can_evict(),
            "failed publication falsely acknowledged current native state");
    require(!owner.acknowledge({73,11,3},true) && !owner.can_evict(),
            "future generation falsely acknowledged");
    require(!owner.acknowledge({72,11,2},true) && !owner.can_evict(),
            "older world session falsely acknowledged");
    require(!owner.acknowledge({73,12,2},true) && !owner.can_evict(),
            "different chunk incarnation falsely acknowledged");
    require(owner.acknowledge(after_ticks,true) && owner.can_evict(),
            "current test-only native snapshot publication receipt refused");
    require(!owner.acknowledge(after_ticks,true),
            "duplicate completed save was not idempotently refused");
    std::uint32_t restored_observed=0;
    for(int i=0;i<3;++i) {
        const auto a=live.tick(), b=current_world->tick();
        restored_observed=std::max(restored_observed,b.worker_threads_observed);
        require(!live.has_failed() && !current_world->has_failed() &&
                live.completed_tick_index()==current_world->completed_tick_index() &&
                live.physical_state_hash()==current_world->physical_state_hash(),
                "simulation-only native post-restart fixed-tick continuation diverged");
    }
    require(restored_observed>=1U && restored_observed<=workers,
            "restored native World missing valid worker witness");
    // Three subsequent ACTUAL native ticks supersede the previously accepted
    // snapshot. Even without player input, the last ACK must not authorize a
    // stale eviction. A new native checkpoint is restored as a positive control.
    const auto post_resume_snapshot=live.save_physical_state();
    auto post_resume_restore=World::restore_physical_state(c,post_resume_snapshot);
    require(!post_resume_snapshot.empty() &&
            post_resume_snapshot!=new_snapshot &&
            post_resume_restore &&
            post_resume_restore->completed_tick_index()==11U &&
            post_resume_restore->physical_state_hash()==live.physical_state_hash(),
            "post-ACK native simulation revision did not round-trip");
    owner.current_generation=3;
    require(!owner.can_evict() &&
            !owner.acknowledge(after_ticks,true),
            "late earlier ACK re-admitted eviction after continued native ticks");
    require(owner.acknowledge({73,11,3},true) && owner.can_evict(),
            "latest test-only durable receipt control failed");
    std::cout << "GEN006_NATIVE_SIMULATION_ONLY_NOT_SAVE_ACK_JSON {\"configured_workers\":"
              << workers << ",\"observed_workers\":" << actually_participating
              << ",\"restored_observed_workers\":" << restored_observed
              << ",\"native_chunks\":8,\"simulation_ticks_before_save\":8"
              << ",\"continuation_ticks\":3,\"water_mass\":17"
              << ",\"render_hints_consumed\":" << render_hints.size()
              << ",\"render_dirty_after_drain\":0"
              << ",\"cell_tuples_changed\":true"
              << ",\"old_snapshot_bytes\":" << old_snapshot.size()
              << ",\"new_snapshot_bytes\":" << new_snapshot.size()
              << ",\"post_resume_snapshot_bytes\":" << post_resume_snapshot.size()
              << ",\"old_inflight_ack_refused\":true"
              << ",\"publication_failure_refused\":true"
              << ",\"session_incarnation_gen_fenced\":true"
              << ",\"post_ack_simulation_invalidates_eviction\":true"
              << ",\"save_owner_model\":\"TEST_ONLY\""
              << ",\"selective_eviction\":false,\"result\":\"PASS\"}\n";
}

// GEN-006: test-only same-value edit-intent/rebase ambiguity, NOT a codec.
// Native physical state can reproduce values but not why a player placed Wall.
void recipe_intent_ambiguity_cohort(std::uint32_t workers) {
    const auto c=config(workers);
    std::vector<Material> baseline(static_cast<std::size_t>(kSide*kSide),Material::Empty);
    baseline[static_cast<std::size_t>(20*kSide)] = Material::Wall;
    baseline[static_cast<std::size_t>(20*kSide+127)] = Material::Wall;
    baseline[static_cast<std::size_t>(48*kSide+48)] = Material::Water;
    World untouched(c), edited(c);
    for (auto coord : {ChunkCoord{-1,0},ChunkCoord{0,0}}) {
        require(untouched.install_generated_chunk(coord,baseline)==ChunkInstallOutcome::Installed,
                "untouched native generator baseline refused");
        require(edited.install_generated_chunk(coord,baseline)==ChunkInstallOutcome::Installed,
                "edited native generator baseline refused");
    }
    require(edited.set_cell_state(0,20,Material::Empty,0,0) &&
            edited.set_cell_state(0,20,Material::Wall,0,0),
            "real native erase then same-value Wall placement failed");
    for (World* w : {&untouched,&edited}) {
        require(w->set_cell_state(-1,20,Material::Empty,0,0) &&
                w->set_cell_state(48,48,Material::Water,17,0),
                "signed Empty or native Water17 modification failed");
        w->set_temperature(48,48,417);
        require(w->stored_material(-1,20)==Material::Empty &&
                w->stored_material(0,20)==Material::Wall &&
                w->liquid_mass(48,48)==17 &&
                w->stored_temperature(48,48)==417,
                "native material/state/temperature readback mismatch");
    }
    // The real native material-state content hash cannot distinguish untouched
    // Wall from a deliberate erase-and-replace Wall.
    require(untouched.content_hash()==edited.content_hash(),
            "final native cell content should agree despite distinct edit history");
    const auto plain_bytes=untouched.save_physical_state();
    const auto edited_bytes=edited.save_physical_state();
    require(!plain_bytes.empty() && !edited_bytes.empty() &&
            plain_bytes.size()<1024*1024 && edited_bytes.size()<1024*1024,
            "real native checkpoint length unavailable or unbounded");
    auto plain=World::restore_physical_state(c,plain_bytes);
    auto changed=World::restore_physical_state(c,edited_bytes);
    require(plain && changed && plain->physical_state_hash()==untouched.physical_state_hash() &&
            changed->physical_state_hash()==edited.physical_state_hash(),
            "native distinct histories failed CYPS roundtrip");
    require(plain->content_hash()==changed->content_hash() &&
            changed->stored_material(0,20)==Material::Wall &&
            changed->stored_material(-1,20)==Material::Empty &&
            changed->stored_state_a(48,48)==17 &&
            changed->stored_temperature(48,48)==417,
            "restored signed Water/Empty values differ or fail");
    constexpr auto new_baseline=Material::Sand;
    const auto naive=[](Material old_value,Material revision,Material live) {
        return live==old_value?revision:live;
    };
    const auto intent_fenced=[](Material old_value,Material revision,Material live,
                                bool external_explicit_edit) {
        return external_explicit_edit||live!=old_value?live:revision;
    };
    require(naive(Material::Wall,new_baseline,changed->stored_material(0,20))==
            new_baseline,"value-only rebase negative control absent");
    require(intent_fenced(Material::Wall,new_baseline,plain->stored_material(0,20),false)==
            new_baseline && intent_fenced(Material::Wall,new_baseline,
            changed->stored_material(0,20),true)==Material::Wall &&
            intent_fenced(Material::Wall,new_baseline,
            changed->stored_material(-1,20),true)==Material::Empty,
            "test-only owner edit-intent fence failed");
    require(changed->install_generated_chunk({0,0},baseline)==
            ChunkInstallOutcome::AlreadyResident,
            "native fresh-only installer allowed rebase of resident");
    std::cout<<"GEN006_RECIPE_INTENT_AMBIGUITY_JSON {\"configured_workers\":"
             <<workers<<",\"actual_workers\":0,\"signed_chunks\":2"
             <<",\"equal_native_content\":true,\"same_value_edit_intent_in_content\":false"
             <<",\"explicit_empty\":true,\"water_quantity\":17,\"temperature\":417"
             <<",\"native_plain_bytes\":"<<plain_bytes.size()
             <<",\"native_edited_bytes\":"<<edited_bytes.size()
             <<",\"intent_receipt\":\"TEST_ONLY\",\"production_rebase\":false"
             <<",\"result\":\"PASS\"}\n";
}


// GEN-006: a durable ACK cannot use *cell-content equality* as its version.
// Test-only ACK owner receipt. Source is the actual native World/CYPS decoder.
// Two genuine changes can return the authoritative tuples to their original
// values while the intervening player intent/dirty generations still matter.
void same_content_save_ack_aba_cohort(std::uint32_t workers) {
    const auto c=config(workers);
    std::vector<Material> initial(static_cast<std::size_t>(kSide*kSide),Material::Empty);
    initial[static_cast<std::size_t>(20*kSide)] = Material::Wall;
    initial[static_cast<std::size_t>(20*kSide+127)] = Material::Wall;
    initial[static_cast<std::size_t>(48*kSide+48)] = Material::Water;
    World live(c);
    for (auto coord : {ChunkCoord{-1,0}, ChunkCoord{0,0}}) {
        require(live.install_generated_chunk(coord,initial)==ChunkInstallOutcome::Installed,
                "content ABA native signed-chunk admission refused");
    }
    require(live.set_cell_state(-1,20,Material::Empty,0,0) &&
            live.set_cell_state(48,48,Material::Water,17,0),
            "content ABA signed Empty / Water17 setup refused");
    live.set_temperature(48,48,417);
    require(live.stored_material(-1,20)==Material::Empty &&
            live.stored_material(0,20)==Material::Wall &&
            live.liquid_mass(48,48)==17 && live.stored_temperature(48,48)==417,
            "content ABA authoritative setup mismatch");

    const auto first_content=live.content_hash();
    const auto first_bytes=live.save_physical_state();
    require(!first_bytes.empty() && first_bytes.size()<1024*1024,
            "content ABA first native CYPS checkpoint missing or unbounded");

    // An asynchronous capture of generation 1 is in flight while the exclusive
    // owner performs two actual native value transitions in the same session.
    require(live.set_cell_state(0,20,Material::Empty,0,0) &&
            live.set_cell_state(48,48,Material::Water,19,0),
            "content ABA intermediate native edits refused");
    const auto middle_content=live.content_hash();
    require(middle_content!=first_content &&
            live.stored_material(0,20)==Material::Empty &&
            live.liquid_mass(48,48)==19,
            "content ABA intermediate native state did not differ");
    require(live.set_cell_state(0,20,Material::Wall,0,0) &&
            live.set_cell_state(48,48,Material::Water,17,0),
            "content ABA restoration edits refused");
    const auto final_content=live.content_hash();
    require(final_content==first_content &&
            live.stored_material(-1,20)==Material::Empty &&
            live.stored_material(0,20)==Material::Wall &&
            live.liquid_mass(48,48)==17 &&
            live.stored_temperature(48,48)==417,
            "real native content did not complete signed Empty/Water17 ABA cycle");

    const auto final_bytes=live.save_physical_state();
    require(!final_bytes.empty() && final_bytes.size()<1024*1024,
            "content ABA final native CYPS checkpoint missing or unbounded");
    auto old_restore=World::restore_physical_state(c,first_bytes);
    auto final_restore=World::restore_physical_state(c,final_bytes);
    require(old_restore && final_restore &&
            old_restore->content_hash()==first_content &&
            final_restore->content_hash()==final_content &&
            old_restore->content_hash()==final_restore->content_hash(),
            "native CYPS decoding broke the equal-content ABA witness");
    // Unsafe negative control: a content digest or comparison alone has no way
    // to notice the intervening owner mutations or preserve their provenance.
    const bool unsafe_content_only_ack =
        old_restore->content_hash()==final_restore->content_hash();
    require(unsafe_content_only_ack,
            "content-only stale ACK negative control unexpectedly refused");

    struct Receipt {
        std::uint64_t session;
        std::uint64_t incarnation;
        std::uint64_t mutation_generation;
    };
    constexpr Receipt stale{91,7,1}, current{91,7,3};
    const auto can_ack=[](Receipt saved, Receipt now, bool root_published,
                          bool previously_acknowledged) {
        return root_published && !previously_acknowledged &&
               saved.session==now.session &&
               saved.incarnation==now.incarnation &&
               saved.mutation_generation==now.mutation_generation;
    };
    require(!can_ack(stale,current,true,false),
            "old generation ACK was accepted after content returned to same digest");
    require(!can_ack({90,7,3},current,true,false) &&
            !can_ack({91,8,3},current,true,false) &&
            !can_ack({91,7,4},current,true,false),
            "session/incarnation/generation fence allowed wrong ACK");
    require(!can_ack(current,current,false,false),
            "failed durable-root publication falsely enabled ACK");
    require(can_ack(current,current,true,false) &&
            !can_ack(current,current,true,true),
            "test-only exact-generation ACK or duplicate refusal failed");
    require(!can_ack(current,{91,7,4},true,false),
            "new native owner mutation failed to invalidate previous ACK");

    std::cout<<"GEN006_NATIVE_CONTENT_ACK_ABA_JSON {\"configured_workers\":"
             <<workers<<",\"actual_workers\":0,\"signed_chunks\":2"
             <<",\"same_content_after_two_edits\":true"
             <<",\"intermediate_differs\":true"
             <<",\"explicit_empty\":true,\"water_quantity\":17,\"temperature\":417"
             <<",\"first_native_bytes\":"<<first_bytes.size()
             <<",\"final_native_bytes\":"<<final_bytes.size()
             <<",\"stale_content_only_ack_unsafe\":true"
             <<",\"test_only_generation_fence_refuses_stale\":true"
             <<",\"production_durable_ack\":false,\"selective_eviction\":false"
             <<",\"result\":\"PASS\"}\n";
}


}
int main() {
    try {
        cohort(1);
        cohort(4);
        signed_malformed_checkpoint_cohort(1);
        signed_malformed_checkpoint_cohort(4);
        render_dirty_not_persistent_ack_cohort(1);
        render_dirty_not_persistent_ack_cohort(4);
        simulation_only_persistence_gap_cohort(1);
        simulation_only_persistence_gap_cohort(4);
        recipe_intent_ambiguity_cohort(1);
        recipe_intent_ambiguity_cohort(4);
        same_content_save_ack_aba_cohort(1);
        same_content_save_ack_aba_cohort(4);
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
