#include "cybersand/object_shard_coordinator.hpp"
#include <algorithm>
#include <chrono>
#include <cstdio>
#include <vector>

// Source-compatible control/candidate fixture. Both implementations first own
// the same three one-cell shards, then see the same 400-cell detached structure.
// This measures native admission only, not Rapier or full Lab presentation.
using namespace cybersand;
using namespace cybersand::object_shard;
using Clock=std::chrono::steady_clock;
static std::uint64_t now_ns() {
    return static_cast<std::uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(Clock::now().time_since_epoch()).count());
}
static bool activate(Coordinator& coordinator,Handle handle) {
    for (const auto kind:{AckKind::PhysicsReserved,AckKind::TerrainInstalled,AckKind::BodyActivated}) {
        const auto snapshot=coordinator.snapshot();const auto* shard=coordinator.registry().find(handle);
        if (!shard) return false;
        const auto& g=shard->geometry();
        if (coordinator.acknowledge({handle,snapshot.promotion.transaction,handle.generation,snapshot.promotion.payload_digest,
                g.revision,g.mask_digest,g.shape_digest,kind,kind==AckKind::TerrainInstalled ? snapshot.promotion.terrain : std::span<const TerrainReceipt>{}}).outcome!=Outcome::Accepted)
            return false;
    }
    return true;
}
int main() {
    const auto start=now_ns();Config config;config.scenario=0;config.world_bounds={0,0,128,96};
    Coordinator coordinator(config);
    const auto constructed=now_ns();
    for (int x:{10,20,30}) {
        if (coordinator.edit(x,10,{Material::Wood,0,0,200}).outcome!=Outcome::Accepted) return 2;
        bool accepted=false;
        for (unsigned call=0;call<1024;++call) {
            const auto result=coordinator.prepare_next();
            if (result.outcome==Outcome::Accepted) {accepted=activate(coordinator,result.shard);break;}
        }
        if (!accepted) return 3;
    }
    for (int y=30;y<50;++y) for (int x=55;x<75;++x)
        if (coordinator.edit(x,y,{Material::Wood,0,0,200}).outcome!=Outcome::Accepted) return 4;
    const auto first=now_ns();(void)coordinator.prepare_next();const auto first_cost=now_ns()-first;
    for (unsigned warm=0;warm<128;++warm) (void)coordinator.prepare_next();
    const auto before=coordinator.metrics().discovered_cells;
    std::vector<std::uint64_t> samples;samples.reserve(4096);
    for (unsigned call=0;call<4096;++call) {
        const auto begin=now_ns();(void)coordinator.prepare_next();samples.push_back(now_ns()-begin);
    }
    const auto discovered=coordinator.metrics().discovered_cells-before;
    const auto snapshot=coordinator.snapshot();
    if (coordinator.registry().inventory_counts().structural!=3 ||
        coordinator.world().quantity_ledger().material_cells[static_cast<std::uint8_t>(Material::Wood)]!=400) return 5;
    std::sort(samples.begin(),samples.end());
    std::printf("{\"schema\":\"objectshard-admission-cost-v1\",\"case\":\"three-identical-owners-and-deferred-400\","
        "\"samples\":%zu,\"construction_ns\":%llu,\"first_prepare_ns\":%llu,\"p50_ns\":%llu,\"p95_ns\":%llu,"
        "\"p99_ns\":%llu,\"max_ns\":%llu,\"rediscovered_cells\":%llu,\"coordinator_bytes\":%zu,\"retained_bytes\":%zu,"
        "\"world_wood\":400,\"shard_wood\":3}\n",samples.size(),
        static_cast<unsigned long long>(constructed-start),static_cast<unsigned long long>(first_cost),
        static_cast<unsigned long long>(samples[samples.size()/2]),static_cast<unsigned long long>(samples[samples.size()*95/100]),
        static_cast<unsigned long long>(samples[samples.size()*99/100]),static_cast<unsigned long long>(samples.back()),
        static_cast<unsigned long long>(discovered),snapshot.metrics.coordinator_bytes,snapshot.metrics.retained_bytes);
    return 0;
}
