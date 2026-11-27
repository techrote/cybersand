#include "cybersand/persistent_area_continuation.hpp"
#include "cybersand/render_snapshot.hpp"

#include <array>
#include <chrono>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <iterator>
#include <sstream>
#include <string>

using cybersand::Material;
using cybersand::World;
using cybersand::WorldConfig;
namespace areas=cybersand::persistent_areas;

namespace {
void require(bool value,const char* message) { if (!value) throw std::runtime_error(message); }
template<class Action> void refused(Action&& action,const char* message) {
    bool failed=false;
    try { action(); } catch (const std::exception&) { failed=true; }
    require(failed,message);
}
std::string hex64(std::uint64_t value) {
    std::ostringstream text; text<<std::hex<<std::setw(16)<<std::setfill('0')<<value; return text.str();
}
std::unique_ptr<WorldConfig> configuration(std::uint32_t workers=1) {
    auto c=std::make_unique<WorldConfig>();
    c->worker_threads=workers; c->parallel_job_threshold=1;
    c->maximum_chunk_count=128; c->active_chunk_capacity=128; c->active_core_capacity=1024;
    return c;
}
void rect(World& world,int x,int y,int width,int height,Material material) {
    for (int row=y; row<y+height; ++row) for (int column=x; column<x+width; ++column)
        world.set(column,row,material);
}
std::unique_ptr<World> fixture(std::uint32_t workers=1,int area=0) {
    auto config=configuration(workers);
    auto world=std::make_unique<World>(*config);
    world->reserve_region({0,0,512,512});
    world->set_simulation_region(cybersand::RectI64{0,0,512,512});
    rect(*world,0,500,512,8,Material::Wall);
    rect(*world,0,0,4,508,Material::Wall); rect(*world,508,0,4,508,Material::Wall);
    if (area==0) {
        // Authored static fuel, real burning counters, moving smoke and Fire.
        rect(*world,40,385,44,45,Material::Wood);
        for (int x=40; x<84; ++x)
            require(world->set_cell_state(x,385,Material::Wood,0,240),"burning fuel admission");
        rect(*world,44,377,36,8,Material::Fire);
        rect(*world,150,450,48,5,Material::Wall);
        rect(*world,154,436,40,14,Material::Oil);
        for (int x=154; x<194; ++x)
            require(world->set_cell_state(x,436,Material::Oil,0,64),"burning Oil admission");
    }
    // Real motion occupies multiple same-phase scheduling cores.
    for (int x : {280,408}) {
        rect(*world,x,80,24,25,Material::Sand);
        rect(*world,x,220,28,15,Material::Water);
    }
    if (area==2) {
        rect(*world,50,400,150,6,Material::Wood);
        rect(*world,50,300,6,100,Material::Wall);
        rect(*world,194,300,6,100,Material::Wall);
        rect(*world,50,300,150,6,Material::Wall);
    }
    world->set(51,400,Material::Empty); // destructive authored edit
    world->set(65,60,Material::Wall);   // distinct retained mark
    require(world->set_cell_state(282,225,Material::Water,17,3),"fractional Water admission");
    world->set_temperature(282,225,417);
    return world;
}
void step(World& world,std::uint32_t ticks) { for (std::uint32_t i=0;i<ticks;++i) (void)world.tick(); }
void require_same(const World& left,const World& right) {
    require(left.physical_state_hash()==right.physical_state_hash(),"full physical hash diverged");
    require(left.quantity_ledger()==right.quantity_ledger(),"native quantity ledger diverged");
    require(left.save_physical_state()==right.save_physical_state(),"canonical CYPS state diverged");
}
void write_file(const std::string& path,std::span<const std::uint8_t> bytes) {
    std::ofstream file(path,std::ios::binary|std::ios::trunc);
    file.write(reinterpret_cast<const char*>(bytes.data()),static_cast<std::streamsize>(bytes.size()));
    file.close(); require(!file.fail(),"checkpoint output failed");
}
std::vector<std::uint8_t> read_file(const std::string& path) {
    std::ifstream file(path,std::ios::binary);
    require(file.is_open(),"checkpoint input unavailable");
    return {std::istreambuf_iterator<char>(file),std::istreambuf_iterator<char>()};
}
cybersand::Sha256::Digest digest_from_hex(const std::string& value) {
    require(value.size()==64,"SHA256 argument invalid");
    cybersand::Sha256::Digest out{};
    for (std::size_t i=0;i<32;++i) out[i]=static_cast<std::uint8_t>(std::stoul(value.substr(i*2,2),nullptr,16));
    return out;
}

void continuation_and_slices(const std::string& output) {
    auto reference=fixture();
    const auto original_material=reference->content_hash();
    step(*reference,37);
    require(reference->content_hash()!=original_material,"fixture had no actual native progression");
    require(reference->queue_explosion(70,410,4),"pending native explosion admission");
    const auto saved=areas::capture(*reference);
    auto four=configuration(4);
    auto one=areas::restore(*configuration(),saved.bytes,saved.sha256,saved.completed_tick,saved.physical_hash);
    auto eight=areas::restore(*four,saved.bytes,saved.sha256,saved.completed_tick,saved.physical_hash);
    auto thirty_two=areas::restore(*four,saved.bytes,saved.sha256,saved.completed_tick,saved.physical_hash);
    require_same(*reference,*one); require_same(*reference,*eight);
    constexpr std::uint32_t total=288; // crosses the native 255-epoch wrap
    std::uint32_t maximum_workers=0;
    std::uint64_t useful_us=0;
    for (std::uint32_t i=0;i<total;++i) {
        (void)reference->tick();
        const auto result=areas::advance(*one,1,100'000);
        require(result.completed_ticks==1,"one-tick slice failed to account work");
        useful_us+=result.elapsed_microseconds;
    }
    for (auto* candidate : {eight.get(),thirty_two.get()}) {
        const auto maximum=candidate==eight.get()?8U:32U;
        std::uint32_t done=0;
        while(done<total) {
            const auto result=areas::advance(*candidate,std::min(maximum,total-done),100'000);
            require(result.completed_ticks>0 && result.completed_ticks<=maximum,"bounded slice result invalid");
            done+=result.completed_ticks; maximum_workers=std::max(maximum_workers,result.observed_workers);
        }
        require_same(*reference,*candidate);
    }
    require_same(*reference,*one);
    require(reference->stored_material(65,60)==Material::Wall,"explicit placed mark lost");
    require(reference->stored_material(51,400)==Material::Empty,"explicit Empty edit resurrected");
    require(maximum_workers>1,"configured workers did not perform actual parallel fixture work");
    std::cout<<"GEN006_NATIVE_CONTINUATION_PASS initial_tick="<<saved.completed_tick
        <<" completed_tick="<<reference->completed_tick_index()<<" slice_sizes=1,8,32 configured_workers=1,4 observed_workers="
        <<maximum_workers<<" physical="<<hex64(reference->physical_state_hash())
        <<" checkpoint_bytes="<<saved.bytes.size()<<" resident_cell_bytes="<<saved.resident_cell_bytes
        <<" native_ticks="<<total<<" native_step_us="<<useful_us<<'\n';
    if (!output.empty()) {
        write_file(output,saved.bytes);
        std::ofstream manifest(output+".json");
        manifest<<"{\"sha256\":\""<<cybersand::Sha256::hex(saved.sha256)<<"\",\"completed_tick\":"<<saved.completed_tick
            <<",\"physical_hash\":\""<<hex64(saved.physical_hash)<<"\",\"resume_ticks\":"<<total
            <<",\"expected_physical_hash\":\""<<hex64(reference->physical_state_hash())<<"\"}\n";
        manifest.close(); require(!manifest.fail(),"checkpoint receipt output failed");
    }
}

void negative_domains_and_atomicity() {
    auto retained=fixture(); step(*retained,3);
    const auto saved=areas::capture(*retained);
    const auto preserve=[&]{ require(retained->save_physical_state()==saved.bytes,"refusal mutated retained World"); };
    auto corrupted=saved.bytes; corrupted[corrupted.size()/2]^=1;
    refused([&]{ (void)areas::restore(retained->config(),corrupted,saved.sha256,saved.completed_tick,saved.physical_hash); },"corrupt bytes accepted"); preserve();
    auto truncated=saved.bytes; truncated.pop_back();
    refused([&]{ (void)areas::restore(retained->config(),truncated,cybersand::Sha256::of(truncated),saved.completed_tick,saved.physical_hash); },"truncated valid-outer-SHA accepted"); preserve();
    refused([&]{ (void)areas::restore(retained->config(),saved.bytes,saved.sha256,saved.completed_tick+1,saved.physical_hash); },"wrong tick accepted"); preserve();
    refused([&]{ (void)areas::restore(retained->config(),saved.bytes,saved.sha256,saved.completed_tick,saved.physical_hash^1); },"wrong physical hash accepted"); preserve();
    auto candidate=areas::restore(retained->config(),saved.bytes,saved.sha256,saved.completed_tick,saved.physical_hash);
    refused([&]{ (void)areas::advance(*candidate,33,100'000); },"excessive slice accepted");
    require_same(*retained,*candidate);
    candidate->configure_transient_obstacles({0,0,512,512});
    require(candidate->set_transient_obstacle(300,300,1),"mask fixture admission");
    refused([&]{ (void)areas::capture(*candidate); },"unsupported body mask admitted"); preserve();
    candidate->clear_transient_obstacles();
    candidate->set_simulation_region(cybersand::RectI64{0,0,128,128});
    refused([&]{ (void)areas::capture(*candidate); },"camera-only native area admitted"); preserve();
    auto failure_execution=configuration(); failure_execution->active_core_capacity=1;
    auto failure=areas::restore(*failure_execution,saved.bytes,saved.sha256,saved.completed_tick,saved.physical_hash);
    refused([&]{ (void)areas::advance(*failure,1,100'000); },"private capacity failure fixture did not fail");
    require(failure->has_failed(),"failed private World was not quarantined"); preserve();
    auto audition=fixture();
    cybersand::MaterialAuditionProfile profile;
    profile.profile_id="area-refusal";
    profile.density[static_cast<std::size_t>(Material::Sand)]=500;
    const auto activation=audition->apply_material_audition(
        audition->material_audition_world_id(),audition->material_audition_revision(),profile);
    require(activation.outcome==cybersand::MaterialAuditionOutcome::Applied,"audition fixture did not activate");
    refused([&]{ (void)areas::capture(*audition); },"nondefault material laws entered a CYPS2 checkpoint");
    preserve();
    auto wave=configuration(); wave->wave_flow.enabled=true;
    refused([&]{ (void)areas::restore(*wave,saved.bytes,saved.sha256,saved.completed_tick,saved.physical_hash); },"Wave execution silently accepted a CYPS2 checkpoint"); preserve();
    std::cout<<"GEN006_NATIVE_REFUSAL_ATOMICITY_PASS corrupt truncated wrong_tick wrong_hash oversized_slice body_mask partial_region private_tick_failure wave_refusal\n";
}

void coarse_skip_counterexamples() {
    auto config=configuration(); config->sleep_after_quiet_ticks=1;
    World deadline(*config);
    deadline.set_simulation_region(cybersand::RectI64{0,0,512,512});
    rect(deadline,7,7,4,3,Material::Wall);
    deadline.set(8,8,Material::Ice); deadline.set(9,8,Material::Water);
    bool sleeping_before_reaction=false;
    std::uint64_t sleeping_tick=0;
    for(int i=0;i<1024 && deadline.stored_material(9,8)==Material::Water;++i) {
        (void)deadline.tick();
        if (deadline.active_chunk_count()==0 && deadline.stored_material(9,8)==Material::Water) {
            sleeping_before_reaction=true; sleeping_tick=deadline.completed_tick_index();
            const auto before=deadline.save_physical_state();
            const auto refusal=areas::assess_coarse_advance(deadline,600);
            require(!refusal.admitted && refusal.credited_ticks==0,"unsafe coarse advancement credited debt");
            require(deadline.save_physical_state()==before,"coarse admission probe mutated the World");
        }
    }
    require(sleeping_before_reaction && deadline.stored_material(9,8)==Material::Ice,
        "deadline counterexample did not react after zero active chunks");
    World epoch(*config); epoch.set_simulation_region(cybersand::RectI64{0,0,512,512});
    epoch.set(32,32,Material::Wall); step(epoch,254);
    const auto before=epoch.save_physical_state();
    const auto quiet=epoch.liquid_comparison_hash(cybersand::LiquidStateProjection::QuiescentPhysicalContentV1);
    step(epoch,2);
    require(epoch.active_chunk_count()==0 &&
        quiet==epoch.liquid_comparison_hash(cybersand::LiquidStateProjection::QuiescentPhysicalContentV1) &&
        before!=epoch.save_physical_state(),"epoch-wrap counterexample missing");
    const auto refusal=areas::assess_coarse_advance(epoch,36'000);
    require(!refusal.admitted && refusal.credited_ticks==0,"idle hash allowed native time skipping");
    std::cout<<"GEN006_COARSE_SKIP_REFUSED_PASS sleeping_tick="<<sleeping_tick
        <<" reaction_tick="<<deadline.completed_tick_index()<<" epoch_wrap_tick="<<epoch.completed_tick_index()
        <<" requested_ticks=36000 credited_ticks=0 remaining_debt=36000\n";
}

void three_independent_areas() {
    std::array<std::unique_ptr<World>,3> worlds;
    std::array<areas::Capture,3> captures;
    std::uint64_t retained_bytes=0;
    for(int i=0;i<3;++i) {
        worlds[static_cast<std::size_t>(i)]=fixture(1,i);
        step(*worlds[static_cast<std::size_t>(i)],static_cast<std::uint32_t>(17+i*9));
        captures[static_cast<std::size_t>(i)]=areas::capture(*worlds[static_cast<std::size_t>(i)]);
        retained_bytes+=captures[static_cast<std::size_t>(i)].bytes.size();
    }
    require(captures[0].sha256!=captures[1].sha256 && captures[1].sha256!=captures[2].sha256,"area identities collided");
    for (int index : {0,1,2,0,1}) {
        const auto& saved=captures[static_cast<std::size_t>(index)];
        const auto restored=areas::restore(*configuration(),saved.bytes,saved.sha256,saved.completed_tick,saved.physical_hash);
        require_same(*worlds[static_cast<std::size_t>(index)],*restored);
    }
    std::cout<<"GEN006_NATIVE_THREE_AREAS_PASS sequence=A,B,C,A,B retained_checkpoint_bytes="<<retained_bytes<<'\n';
}

void residency_memory_and_render_lifetime() {
    auto world=fixture(4);
    world->configure_transient_obstacles({0,0,512,512},true);
    const auto cells=world->resident_cell_bytes();
    const auto owned=world->current_resident_storage_bytes();
    const auto reservation=world->current_resident_reservation_bytes();
    require(owned>cells,"native ownership metric must include scheduler/coupling storage beyond cells");
    require(reservation>=owned,"native residency growth reservation must cover current owned arrays");
    step(*world,3);
    require(world->current_resident_storage_bytes()<=reservation,"admitted native ticks exceed growth reservation");
    auto exchange=std::make_unique<cybersand::RenderSnapshotExchange>(3,128,4U*1024U*1024U);
    const auto rendered=exchange->publish(*world);
    require(rendered.status==cybersand::RenderPublishStatus::Published,"native render publication failed");
    auto lease=exchange->acquire_latest();
    require(lease && static_cast<bool>(*lease),"immutable native presentation lease unavailable");
    const auto serial=lease->serial(); const auto tick=lease->tick();
    const std::vector<std::uint8_t> retained(lease->cells().begin(),lease->cells().end());
    const auto render_bytes=exchange->resident_storage_bytes();
    require(render_bytes>=3U*4U*1024U*1024U,"render allocation metric omits fixed byte slots");
    world.reset(); exchange.reset();
    require(lease->serial()==serial && lease->tick()==tick &&
        std::equal(retained.begin(),retained.end(),lease->cells().begin(),lease->cells().end()),
        "native eviction invalidated a retained immutable presentation lease");
    lease.reset();
    std::cout<<"GEN006_NATIVE_RESIDENCY_MEMORY_PASS owned_bytes="<<owned
        <<" reservation_bytes="<<reservation<<" cell_bytes="<<cells
        <<" render_bytes="<<render_bytes<<" immutable_lease_survives_world_and_exchange_release=true"
        <<" excludes=allocator_metadata,os_thread_stacks,host_values\n";
}
}

int main(int argc,char** argv) {
    try {
        if (argc==8 && std::string(argv[1])=="--restore") {
            const auto bytes=read_file(argv[2]); auto config=configuration(4);
            auto world=areas::restore(*config,bytes,digest_from_hex(argv[3]),std::stoull(argv[4]),std::stoull(argv[5],nullptr,16));
            step(*world,static_cast<std::uint32_t>(std::stoul(argv[6])));
            require(hex64(world->physical_state_hash())==argv[7],"fresh-process resumed native state differs");
            std::cout<<"GEN006_NATIVE_FRESH_PROCESS_PASS completed_tick="<<world->completed_tick_index()
                <<" physical="<<hex64(world->physical_state_hash())<<" configured_workers=4\n";
            return 0;
        }
        continuation_and_slices(argc==2?argv[1]:"");
        negative_domains_and_atomicity(); coarse_skip_counterexamples(); three_independent_areas();
        residency_memory_and_render_lifetime();
        return 0;
    } catch (const std::exception& error) { std::cerr<<"GEN006_NATIVE_FAIL "<<error.what()<<'\n'; return 1; }
}
