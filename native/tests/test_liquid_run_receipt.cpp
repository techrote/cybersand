#include "cybersand/prepared_world.hpp"
#include <filesystem>
#include <cstdlib>
#include <type_traits>
#include <fstream>
#include <iostream>
#include <stdexcept>
using namespace cybersand;
using namespace cybersand::receipt;
using namespace cybersand::setup;
static_assert(!std::is_constructible_v<NativeFacts, NativeFactValues>, "setup data must not construct native facts");
namespace {
std::size_t assertions = 0;
void expect(bool ok, const char* message) { ++assertions; if (!ok) throw std::runtime_error(message); }
template<class Call> void refuses(Call call) {
    bool refused = false; try { call(); } catch (const std::invalid_argument&) { refused = true; }
    expect(refused, "invalid receipt value admitted");
}
template<class Value> auto boxed(Value&& value) { return std::make_unique<std::decay_t<Value>>(std::forward<Value>(value)); }
SetupDescriptor descriptor() { SetupDescriptor d; d.seed = 7; d.domain = {0,0,8,8}; return d; }
void save(const std::filesystem::path& directory, const char* name, const ReceiptEncoding& r,
          const NativeFacts& facts) {
    static constexpr std::pair<std::string_view,std::string_view> expected[] = {
#include "liquid_run_receipt_vectors.inc"
    };
    const auto found=std::find_if(std::begin(expected),std::end(expected),
        [name](const auto& value){return value.first==name;});
    expect(found!=std::end(expected),"unregistered independent receipt vector");
    expect(Sha256::hex(r.receipt_hash())==found->second,"native receipt differs from independent frozen byte oracle");
    if (directory.empty()) return;
    const auto path = directory / (std::string(name) + ".bin");
    std::ofstream out(path, std::ios::binary);
    out.write(reinterpret_cast<const char*>(r.canonical_bytes().data()), static_cast<std::streamsize>(r.canonical_bytes().size()));
    expect(out.good(), "vector write failed");
    std::cout << name << " " << Sha256::hex(r.receipt_hash()) << " physical=" << facts.values().physical_hash
              << " payload=" << Sha256::hex(facts.values().prepared_native_payload) << "\n";
}

void prepared_world_transactions() {
    normalization::FinalSetupInput input;
    input.setup=descriptor();
    input.cells={{1,1,Material::Water,127,0,777},{2,1,Material::Water,128,0,333},
                 {3,1,Material::Sand,17,23,444},{2,2,Material::Empty,0,0,555}};
    auto config_owner=std::make_unique<WorldConfig>();
    auto& config=*config_owner;
    auto words=LiquidSolverPolicy::default_request(); words[21]=2;
    const auto admitted=LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
    expect(admitted.accepted(),"whole-cell Water prerequisite refused");
    config.liquid_solver_policy=*admitted.policy;
    auto live=std::make_unique<World>();
    live->set(4,4,Material::Oil);
    const auto retained_hash=live->physical_state_hash();
    const auto refused=PreparedWorldBuilder::prepare(config,input,normalization::NormalizationOptIn::None);
    expect(std::holds_alternative<ConstructionRefusal>(refused),"partial whole-cell setup silently admitted");
    const auto& reason=std::get<ConstructionRefusal>(refused);
    expect(reason.policy_refusal() && reason.policy_refusal()->code==LiquidPolicyRefusalCode::NormalizationRequired &&
           reason.request_scope()==ConstructionRequestScope::NormalizedPolicyEnvelope,
           "whole-cell normalization refusal or request scope was lost");
    expect(live->physical_state_hash()==retained_hash,"candidate refusal changed live authority");

    auto candidate_owner=boxed(PreparedWorldBuilder::prepare(config,input,normalization::NormalizationOptIn::WaterNormalizeV1));
    expect(std::holds_alternative<PreparedWorld>(*candidate_owner),"explicit normalization did not construct");
    const auto& candidate=std::get<PreparedWorld>(*candidate_owner);
    const auto& world=candidate.world();
    expect(world.water_cellular_yield_enabled() && world.stored_material(1,1)==Material::Empty &&
           world.stored_temperature(1,1)==777 && world.stored_material(2,1)==Material::Water &&
           world.stored_state_a(2,1)==255 && world.stored_temperature(2,1)==333,
           "prepared Water rounding lost full quantity or down-rounded Empty temperature");
    expect(world.stored_material(3,1)==Material::Sand && world.stored_state_a(3,1)==17 &&
           world.stored_state_b(3,1)==23 && world.stored_temperature(3,1)==444 &&
           world.stored_material(2,2)==Material::Empty && world.stored_temperature(2,2)==555,
           "normalization changed a foreign tuple or authoritative Empty thermal state");
    const auto ledger=world.quantity_ledger();
    const auto& norm=ledger.kinds[static_cast<std::size_t>(QuantityKind::SetupNormalization)];
    expect(ledger.baseline_water==255 && ledger.water_visible==255 && ledger.water_overfill==0 &&
           norm.produced==127 && norm.consumed==127 && ledger.construction &&
           ledger.construction->normalization_receipt_digest==candidate.setup().normalization_receipt()->receipt_hash(),
           "setup normalization was not booked once with exact gross counters and digest");
    const auto saved=world.save_physical_state();
    const auto restored=World::restore_physical_state(config,saved);
    expect(restored->quantity_ledger()==ledger && restored->physical_state_hash()==world.physical_state_hash(),
           "prepared construction ledger/digest did not survive exact continuation");

    auto comparator_config_owner=std::make_unique<WorldConfig>();
    const auto comparator_owner=boxed(PreparedWorldBuilder::prepare(*comparator_config_owner,input,
        normalization::NormalizationOptIn::WaterNormalizeV1));
    expect(std::holds_alternative<PreparedWorld>(*comparator_owner) &&
           std::get<PreparedWorld>(*comparator_owner).setup().native_payload_hash()==candidate.setup().native_payload_hash() &&
           std::get<PreparedWorld>(*comparator_owner).world().quantity_ledger().kinds==ledger.kinds,
           "FreeMass comparator did not receive the same explicit normalized setup and delta");

    auto invalid_coherence_owner=std::make_unique<WorldConfig>(config);
    invalid_coherence_owner->water_experiment_policy=WaterExperimentPolicy(8,0);
    auto invalid=input; invalid.cells[0].state_b=12; // this cell down-rounds to Empty
    const auto bad_lane=PreparedWorldBuilder::prepare(*invalid_coherence_owner,invalid,
        normalization::NormalizationOptIn::WaterNormalizeV1);
    expect(std::holds_alternative<ConstructionRefusal>(bad_lane) &&
           std::get<ConstructionRefusal>(bad_lane).policy_refusal()->code==LiquidPolicyRefusalCode::MalformedPolicy,
           "down-round hid a coherence lane outside the actual selected policy");
    auto capacity_owner=std::make_unique<WorldConfig>(config);
    capacity_owner->maximum_chunk_count=1; capacity_owner->initial_chunk_reserve=1;
    const auto small=PreparedWorldBuilder::prepare(*capacity_owner,input,normalization::NormalizationOptIn::WaterNormalizeV1);
    expect(std::holds_alternative<ConstructionRefusal>(small) &&
           std::get<ConstructionRefusal>(small).outcome_kind()==ConstructionOutcomeKind::PolicyOrSetupRefused &&
           std::get<ConstructionRefusal>(small).policy_refusal()->code==LiquidPolicyRefusalCode::CapacityRefused,
           "bounded preparation capacity was mislabeled or silently exceeded");
    for(const auto backend : {SimulationBackend::Buffered,static_cast<SimulationBackend>(255)}) {
        auto unsupported_owner=std::make_unique<WorldConfig>(config); unsupported_owner->backend=backend;
        const auto unsupported=PreparedWorldBuilder::prepare(*unsupported_owner,input,
            normalization::NormalizationOptIn::WaterNormalizeV1);
        expect(std::holds_alternative<ConstructionRefusal>(unsupported) &&
               std::get<ConstructionRefusal>(unsupported).policy_refusal()->code==LiquidPolicyRefusalCode::MalformedPolicy,
               "unimplemented backend was admitted as a prepared candidate");
    }
    expect(live->physical_state_hash()==retained_hash,"prepared candidate work changed retained live World");
}
}
void test_liquid_run_receipt_native_identity() {
    assertions = 0;
    const auto* destination = std::getenv("CYBERSAND_LCB_RECEIPT_VECTOR_OUTPUT");
    const std::filesystem::path output(destination ? destination : "");
    if (!output.empty()) std::filesystem::create_directories(output);
    const auto setup = descriptor(); auto empty_owner = std::make_unique<World>(); auto& empty = *empty_owner; const auto native_owner = boxed(capture_native_facts(empty, setup)); const auto& native = *native_owner;
    const auto request = LiquidSolverPolicy::default_request();
    const auto apply = [&](const NativeFacts& n, RunIntent mode, const HostExecution& execution,
                           const ProvenanceClaims& claims) {
        return build_applied_run_receipt(n, setup, request, mode, PlaneActivity::Active, execution, claims, 1);
    };
    const auto base = apply(native, RunIntent::Controlled, {}, {});
    save(output, "controlled_native_scope", base, native);
    expect(base.qualifications() == 15 && !base.eligible_for_full_matched_evidence(), "missing proofs were upgraded");
    const auto exploratory = apply(native, RunIntent::Exploratory, {}, {});
    save(output, "exploratory", exploratory, native);
    expect(exploratory.receipt_hash() != base.receipt_hash(), "intent omitted");
    ProvenanceClaims claims;
    claims.source = SourceClaim{std::string(40, '1'), std::string(40, '2'), std::nullopt};
    RuntimeClaim runtime; runtime.artifact_sha256.fill(0x33); runtime.platform=Platform::Windows;
    runtime.architecture=Architecture::X86_64; runtime.engine="4.7.stable.official.5b4e0cb0f";
    claims.runtime = runtime;
    const auto claimed = apply(native, RunIntent::Controlled, {}, claims);
    save(output, "caller_claims", claimed, native);
    expect(!claimed.eligible_for_full_matched_evidence() && claimed.qualifications() == base.qualifications(),
           "shaped caller claims became verified provenance");
    refuses([&] { (void)parse_claim_origin("host_verified_manifest"); });
    claims.source->origin=static_cast<ClaimOrigin>(2);
    refuses([&] { (void)apply(native, RunIntent::Controlled, {}, claims); });
    claims.source->origin=ClaimOrigin::CallerClaim;
    claims.runtime->origin=static_cast<ClaimOrigin>(2);
    refuses([&] { (void)apply(native, RunIntent::Controlled, {}, claims); });
    claims.runtime->origin=ClaimOrigin::CallerClaim;
    claims.source->commit = "not-a-source-identity";
    refuses([&] { (void)apply(native, RunIntent::Controlled, {}, claims); });
    claims = {}; claims.runtime = runtime; claims.runtime->architecture=Architecture::Wasm32;
    refuses([&] { (void)apply(native, RunIntent::Controlled, {}, claims); });
    auto unknown = setup; unknown.definition_schema = 99;
    refuses([&] { (void)prepared_setup_identity(unknown, native.values().prepared_native_payload); });
    unknown = setup; unknown.coverage=SetupCoverage::RegisteredDefinitionAndPayload; unknown.definition_digest.reset();
    refuses([&] { (void)capture_native_facts(empty, unknown); });
    auto execution=HostExecution{}; execution.tick_rate_denominator=0;
    refuses([&] { (void)apply(native, RunIntent::Controlled, execution, {}); });
    auto selected_owner = std::make_unique<World>(); auto& selected = *selected_owner; selected.set_simulation_region(RectI64{0,0,8,8});
    const auto selected_native_owner=boxed(capture_native_facts(selected,setup)); const auto& selected_native=*selected_native_owner;
    execution={};execution.simulation_window_enabled=true;
    const auto window=apply(selected_native,RunIntent::Controlled,execution,{});
    save(output,"selected_region",window,selected_native);
    expect(window.receipt_hash() != base.receipt_hash(),"selected region omitted");
    auto pressure_request=request;pressure_request[21]=3;
    const auto pressure_policy=LiquidSolverPolicy::decode(std::span<const std::int32_t>(pressure_request));
    expect(pressure_policy.accepted(),"pressure extension fixture refused");
    auto pressure_config_owner = std::make_unique<WorldConfig>(); auto& pressure_config = *pressure_config_owner;pressure_config.liquid_solver_policy=*pressure_policy.policy;
    auto pressure_owner = std::make_unique<World>(pressure_config); auto& pressure = *pressure_owner;const auto pressure_native_owner=boxed(capture_native_facts(pressure,setup)); const auto& pressure_native=*pressure_native_owner;
    expect(pressure_native.values().solver_state_extensions.size()==1 &&
        pressure_native.values().solver_state_extensions[0].family==3 &&
        pressure_native.values().solver_state_extensions[0].state_contract_version==1,
        "native pressure state contract extension missing");
    const auto pressure_receipt=build_applied_run_receipt(pressure_native,setup,pressure_request,RunIntent::Controlled,
        PlaneActivity::Active,{}, {},1);
    save(output,"pressure_state_extension",pressure_receipt,pressure_native);
    normalization::FinalSetupInput input; input.setup=setup;
    input.cells={{1,1,Material::Water,127,0,200},{2,1,Material::Water,128,0,200}};
    const auto result=normalization::PreparedSetup::prepare(input,normalization::WaterQuantityRegime::WholeCell,
        normalization::NormalizationOptIn::WaterNormalizeV1);
    expect(std::holds_alternative<normalization::PreparedSetup>(result),"normalization setup refused");
    const auto& prepared=std::get<normalization::PreparedSetup>(result);
    auto normalized_result_owner=boxed(PreparedWorldBuilder::prepare(WorldConfig{},input,
        normalization::NormalizationOptIn::WaterNormalizeV1));
    expect(std::holds_alternative<PreparedWorld>(*normalized_result_owner),"normalized World construction refused");
    const auto& normalized=std::get<PreparedWorld>(*normalized_result_owner).world();
    const auto normalized_native_owner=boxed(capture_native_facts(normalized,setup)); const auto& normalized_native=*normalized_native_owner;
    const auto normalized_receipt=build_applied_run_receipt(normalized_native,setup,request,RunIntent::Controlled,
        PlaneActivity::Active,{}, {},1,prepared.normalization_receipt());
    save(output,"normalized_bound",normalized_receipt,normalized_native);
    refuses([&] { (void)build_applied_run_receipt(native,setup,request,RunIntent::Controlled,
        PlaneActivity::Active,{}, {},1,prepared.normalization_receipt()); });
    auto changed_seed=setup;changed_seed.seed=8;
    const auto seed_native_owner=boxed(capture_native_facts(normalized,changed_seed)); const auto& seed_native=*seed_native_owner;
    refuses([&] { (void)build_applied_run_receipt(seed_native,changed_seed,request,RunIntent::Controlled,
        PlaneActivity::Active,{}, {},1,prepared.normalization_receipt()); });
    auto forged_input=input;
    forged_input.cells[1].state_a=129; // same after cells, a different before delta
    const auto forged=normalization::PreparedSetup::prepare(forged_input,normalization::WaterQuantityRegime::Fractional,
        normalization::NormalizationOptIn::WaterNormalizeV1);
    const auto& forged_setup=std::get<normalization::PreparedSetup>(forged);
    expect(forged_setup.native_payload_hash()==prepared.native_payload_hash(),
           "normalization misbinding negative control must share the after payload");
    refuses([&] { (void)build_applied_run_receipt(normalized_native,setup,request,RunIntent::Controlled,
        PlaneActivity::Active,{}, {},1,forged_setup.normalization_receipt()); });
    refuses([&] { (void)build_applied_run_receipt(normalized_native,setup,request,RunIntent::Controlled,
        PlaneActivity::Active,{}, {},1); });
    auto bad_request=request;bad_request[21]=4;bad_request[22]=1;
    const auto decoded=LiquidSolverPolicy::decode(std::span<const std::int32_t>(bad_request));
    expect(!decoded.accepted(),"unsupported IN cached variant unexpectedly admitted");
    const auto issued = validate_liquid_policy_request(bad_request);
    expect(issued.has_value(),"actual native refusal was not issued");
    expect(!validate_liquid_policy_request(request),"accepted policy fabricated a native refusal");
    const auto attempt=build_construction_attempt_receipt(native,native,*issued,5,5);
    save(output,"refused_attempt",attempt,native);
    refuses([&] { (void)build_construction_attempt_receipt(native,native,*issued,5,6); });
    refuses([&] { (void)build_construction_attempt_receipt(native,selected_native,*issued,5,5); });
    const auto changed_seed_empty_owner=boxed(capture_native_facts(empty,changed_seed)); const auto& changed_seed_empty=*changed_seed_empty_owner;
    refuses([&] { (void)build_construction_attempt_receipt(native,changed_seed_empty,*issued,5,5); });
    refuses([&] { (void)build_applied_run_receipt(native,setup,bad_request,RunIntent::Controlled,
        PlaneActivity::Active,{}, {},1); });
    auto advanced_owner = std::make_unique<World>(); auto& advanced = *advanced_owner; (void)advanced.tick(); const auto advanced_native_owner=boxed(capture_native_facts(advanced,setup)); const auto& advanced_native=*advanced_native_owner;
    refuses([&] { (void)apply(advanced_native,RunIntent::Controlled,{},{}); });
    auto masked_owner = std::make_unique<World>(); auto& masked = *masked_owner;masked.configure_transient_obstacles({0,0,8,8});(void)masked.set_transient_obstacle(0,0,1);
    masked.set(0,0,Material::Water); // blocked paint cannot change masked authority
    masked.clear_transient_obstacles();
    masked.set(0,0,Material::Water);
    masked.set_temperature(0,0,777);
    const auto thermal_before_owner = boxed(capture_native_facts(masked,setup)); const auto& thermal_before = *thermal_before_owner;
    (void)masked.set_transient_obstacle(0,0,1);
    const auto thermal_masked_owner = boxed(capture_native_facts(masked,setup)); const auto& thermal_masked = *thermal_masked_owner;
    expect(masked.temperature(0,0) == masked.config().ambient_temperature &&
           masked.stored_temperature(0,0) == 777 &&
           thermal_masked.values().prepared_native_payload == thermal_before.values().prepared_native_payload,
           "native receipt readback lost authoritative thermal state under a body mask");
    expect(selected_native.values().selected_cores.has_value() &&
           !selected_native.values().applied_cores.has_value(),
           "selected/applied tick-zero coverage was collapsed");
    (void)selected.tick();
    const auto latched_owner = boxed(capture_native_facts(selected,setup)); const auto& latched = *latched_owner;
    expect(latched.values().selected_cores == latched.values().applied_cores,
           "applied core readback did not latch at native tick entry");
    refuses([&] { (void)apply(latched,RunIntent::Controlled,{},{}); });
    const auto again = apply(native,RunIntent::Controlled,{},{});
    expect(std::equal(base.canonical_bytes().begin(),base.canonical_bytes().end(),
                      again.canonical_bytes().begin(),again.canonical_bytes().end()),
           "failed attempts changed the applied receipt");
    prepared_world_transactions();
    std::cout << assertions << " receipt assertions passed; host fields remain explicitly qualified\n";
}
