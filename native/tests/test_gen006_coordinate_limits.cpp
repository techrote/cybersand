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
    // Real native workers execute only on ordinary signed resident chunks.
    // Extremely distant chunks are separately tested at a tick-free owner boundary.
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
    std::cout << "GEN006_NATIVE_COORD_LIMIT_JSON {\"configured_workers\":"<<workers
              <<",\"actual_observed_workers\":"<<observed
              <<",\"resident_edge_chunks\":6,\"rejected_coordinates\":8"
              <<",\"min_accepted_chunk\":"<<valid_lo
              <<",\"max_accepted_chunk\":"<<valid_hi
              <<",\"checkpoint_bytes\":"<<bytes.size()
              <<",\"continuation_at_extreme\":\"not_tested\""
              <<",\"result\":\"PASS\"}\n";
}
}
int main() {
    try {
        cohort(1);
        cohort(4);
        std::cout<<"GEN006_NATIVE_COORD_LIMIT_PASS assertions="<<checks<<"\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr<<"GEN006_NATIVE_COORD_LIMIT_FAIL assertions="<<checks
                 <<" error="<<e.what()<<"\n";
        return 1;
    }
}
