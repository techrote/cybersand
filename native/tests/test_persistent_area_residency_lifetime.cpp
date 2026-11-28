#include "cybersand/world.hpp"
#include "cybersand/render_snapshot.hpp"
#include <algorithm>
#include <array>
#include <atomic>
#include <cstddef>
#include <cstdlib>
#include <cstdint>
#include <iostream>
#include <memory>
#include <new>
#include <stdexcept>
#include <vector>

// Keep ASan's native new/delete interception and redzones intact. Requested
// allocation accounting is exercised by the ordinary binary; the sanitized
// binary exercises the same production storage/lifetime APIs under ASan/UBSan.
#if defined(__has_feature)
#if __has_feature(address_sanitizer)
#define CYBERSAND_RESIDENCY_TEST_ASAN 1
#endif
#endif
#if defined(__SANITIZE_ADDRESS__)
#define CYBERSAND_RESIDENCY_TEST_ASAN 1
#endif

#if !defined(CYBERSAND_RESIDENCY_TEST_ASAN)
// Independent requested-allocation counter: excludes malloc metadata and OS
// stacks, matching the explicitly documented scope of the residency estimate.
namespace allocation_probe {
std::atomic<std::size_t> outstanding{0};
struct Header { void* base; std::size_t size; };
void* allocate(std::size_t size, std::size_t alignment) {
    alignment=std::max(alignment,alignof(Header));
    void* base=std::malloc(size+alignment+sizeof(Header));
    if (!base) throw std::bad_alloc();
    const auto start=reinterpret_cast<std::uintptr_t>(base)+sizeof(Header);
    const auto address=(start+alignment-1)&~(static_cast<std::uintptr_t>(alignment)-1);
    auto* header=reinterpret_cast<Header*>(address)-1;
    header->base=base; header->size=size;
    outstanding.fetch_add(size,std::memory_order_relaxed);
    return reinterpret_cast<void*>(address);
}
void release(void* ptr) noexcept {
    if (!ptr) return;
    auto* header=static_cast<Header*>(ptr)-1;
    outstanding.fetch_sub(header->size,std::memory_order_relaxed);
    std::free(header->base);
}
}
void* operator new(std::size_t size) { return allocation_probe::allocate(size,alignof(std::max_align_t)); }
void* operator new[](std::size_t size) { return ::operator new(size); }
void* operator new(std::size_t size,std::align_val_t alignment) { return allocation_probe::allocate(size,static_cast<std::size_t>(alignment)); }
void* operator new[](std::size_t size,std::align_val_t alignment) { return ::operator new(size,alignment); }
void operator delete(void* ptr) noexcept { allocation_probe::release(ptr); }
void operator delete[](void* ptr) noexcept { allocation_probe::release(ptr); }
void operator delete(void* ptr,std::size_t) noexcept { allocation_probe::release(ptr); }
void operator delete[](void* ptr,std::size_t) noexcept { allocation_probe::release(ptr); }
void operator delete(void* ptr,std::align_val_t) noexcept { allocation_probe::release(ptr); }
void operator delete[](void* ptr,std::align_val_t) noexcept { allocation_probe::release(ptr); }
void operator delete(void* ptr,std::size_t,std::align_val_t) noexcept { allocation_probe::release(ptr); }
void operator delete[](void* ptr,std::size_t,std::align_val_t) noexcept { allocation_probe::release(ptr); }
#endif

using namespace cybersand;
static int checks = 0;
static void require(bool ok, const char* detail) {
    ++checks;
    if (!ok) throw std::runtime_error(detail);
}
static std::unique_ptr<WorldConfig> configuration(std::size_t cores = 1024) {
    auto c = std::make_unique<WorldConfig>();
    c->worker_threads = 4;
    c->parallel_job_threshold = 1;
    c->maximum_chunk_count = 128;
    c->active_chunk_capacity = 128;
    c->active_core_capacity = cores;
    return c;
}
static std::vector<std::uint8_t> bytes(const RenderSnapshotLease& lease) {
    return {lease.cells().begin(),lease.cells().end()};
}
static void memory_growth(std::uint32_t workers) {
    auto c = configuration();
    c->worker_threads = workers;
#if !defined(CYBERSAND_RESIDENCY_TEST_ASAN)
    const auto allocation_baseline=allocation_probe::outstanding.load(std::memory_order_relaxed);
#endif
    auto world = std::make_unique<World>(*c);
    world->set_simulation_region(RectI64{0,0,512,512});
    world->configure_transient_obstacles({0,0,512,512},true);
    const auto before = world->current_resident_storage_bytes();
    const auto reserved = world->current_resident_reservation_bytes();
    world->enable_granular_arrival_witness(true);
    world->reserve_region({0,0,16*128,8*128});
    for (int y=0;y<8;++y) for (int x=0;x<16;++x) {
        world->set(x*128,y*128,Material::Wall);
        world->set_temperature(x*128,y*128,1000);
    }
    require(world->chunk_count()==128,"full admitted chunk capacity was not constructed");
    require(world->granular_arrival_storage_bytes()==128U*128U*128U*sizeof(std::uint64_t),
            "optional arrival arrays were not actually allocated");
    const auto after = world->current_resident_storage_bytes();
#if !defined(CYBERSAND_RESIDENCY_TEST_ASAN)
    const auto requested=allocation_probe::outstanding.load(std::memory_order_relaxed)-allocation_baseline;
#endif
    require(after>before,"memory probe did not allocate genuine native storage");
    require(after<=reserved,"full native growth exceeds the initial reported reservation");
#if !defined(CYBERSAND_RESIDENCY_TEST_ASAN)
    require(requested<=reserved,"independently counted allocations exceed the initial native reservation");
#endif
    std::cout<<"INDEPENDENT_MEMORY_GROWTH workers="<<workers<<" before="<<before<<" reserved="<<reserved
             <<" estimate_all_128_chunks="<<after;
#if !defined(CYBERSAND_RESIDENCY_TEST_ASAN)
    std::cout<<" independent_requested_allocation="<<requested<<" spare="<<reserved-requested;
#else
    std::cout<<" allocation_counter=disabled_preserving_asan_interception";
#endif
    std::cout<<'\n';
}
static void backpressure_lifetime() {
    auto c = configuration();
    auto world = std::make_unique<World>(*c);
    world->reserve_region({0,0,512,512});
    world->set_simulation_region(RectI64{0,0,512,512});
    auto exchange = std::make_unique<RenderSnapshotExchange>(3,128,1024*1024);
    std::array<RenderSnapshotLease,3> leases;
    std::array<std::vector<std::uint8_t>,3> retained;
    std::array<std::uint64_t,3> serials{};
    for (int i=0;i<3;++i) {
        world->set(64+i*130,64,static_cast<Material>(i+1));
        const auto p = exchange->publish(*world);
        require(p.status==RenderPublishStatus::Published,"fresh slot publication failed");
        auto lease = exchange->acquire_latest();
        require(lease.has_value(),"fresh publication lease absent");
        leases[static_cast<std::size_t>(i)] = std::move(*lease);
        retained[static_cast<std::size_t>(i)] = bytes(leases[static_cast<std::size_t>(i)]);
        serials[static_cast<std::size_t>(i)] = p.snapshot_serial;
    }
    world->set(80,80,Material::Fire);
    require(exchange->publish(*world).status==RenderPublishStatus::Backpressure,
            "all three retained leases must prevent overwrite");
    for (int i=0;i<3;++i) require(bytes(leases[static_cast<std::size_t>(i)])==retained[static_cast<std::size_t>(i)],
                                 "backpressure changed a retained slot");
    leases[1].reset();
    require(exchange->publish(*world).status==RenderPublishStatus::Published,
            "released slot did not become available");
    require(bytes(leases[0])==retained[0] && bytes(leases[2])==retained[2],
            "slot reuse mutated another retained slot");
    world.reset();
    exchange.reset();
    for (int i : {0,2}) {
        require(leases[static_cast<std::size_t>(i)].serial()==serials[static_cast<std::size_t>(i)],
                "retirement changed retained serial");
        require(bytes(leases[static_cast<std::size_t>(i)])==retained[static_cast<std::size_t>(i)],
                "World/exchange destruction invalidated retained bytes");
    }
    std::cout<<"INDEPENDENT_LEASE_BACKPRESSURE_AND_EVICTION passed\n";
}
static void failure_lifetime() {
    auto c = configuration(1);
    auto world = std::make_unique<World>(*c);
    world->reserve_region({0,0,512,512});
    world->set_simulation_region(RectI64{0,0,512,512});
    world->set(64,64,Material::Sand);
    world->set(320,320,Material::Sand);
    auto exchange = std::make_unique<RenderSnapshotExchange>(3,128,1024*1024);
    require(exchange->publish(*world).status==RenderPublishStatus::Published,"pre-failure render publication failed");
    auto lease = exchange->acquire_latest();
    require(lease.has_value(),"pre-failure lease absent");
    const auto retained = bytes(*lease);
    const auto serial = lease->serial();
    bool threw = false;
    try { (void)world->tick(); } catch (const std::exception&) { threw = true; }
    require(threw && world->has_failed(),"bounded active-core fault did not quarantine the actual World");
    threw = false;
    try { (void)exchange->publish(*world); } catch (const std::exception&) { threw = true; }
    require(threw,"failed World published a fresh render generation");
    require(exchange->latest_serial()==serial,"failed publication advanced renderer identity");
    world.reset();
    exchange.reset();
    require(bytes(*lease)==retained && lease->serial()==serial,"failed-World eviction invalidated the good retained lease");
    std::cout<<"INDEPENDENT_FAILED_WORLD_LEASE_RETIREMENT passed\n";
}
int main() {
    try {
        for (const auto workers : {1U,4U,32U}) memory_growth(workers);
        backpressure_lifetime();
        failure_lifetime();
        std::cout<<"GEN006_INDEPENDENT_NATIVE_LIFETIME checks="<<checks<<" failures=0\n";
        return 0;
    } catch(const std::exception& error) {
        std::cerr<<"GEN006_INDEPENDENT_NATIVE_LIFETIME_FAILURE checks="<<checks<<" detail="<<error.what()<<'\n';
        return 1;
    }
}
