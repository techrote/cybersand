#pragma once

// Included after the normal prepared constructor. A continuation first
// validates that complete authored source through the ordinary constructor,
// then replaces ONLY its private candidate with the exact CYPS continuation.
namespace godot {
namespace persistent_area_detail {

inline bool hex(const String& value, std::int64_t length) {
    if (value.length() != length) return false;
    for (std::int64_t i=0; i<length; ++i) {
        const auto c=value[i];
        if (!((c>='0' && c<='9') || (c>='a' && c<='f'))) return false;
    }
    return true;
}
inline bool identifier(const String& value) {
    if (value.is_empty() || value.length()>128) return false;
    for (std::int64_t i=0; i<value.length(); ++i) {
        const auto c=value[i];
        if (!((c>='a'&&c<='z') || (c>='A'&&c<='Z') || (c>='0'&&c<='9') ||
              c=='-' || c=='_' || c=='.' || c==':')) return false;
    }
    return true;
}
inline cybersand::Sha256::Digest digest_value(const String& value) {
    if (!hex(value,64)) throw std::invalid_argument("Persistent area SHA256 shape invalid");
    const auto bytes=value.hex_decode();
    cybersand::Sha256::Digest result{};
    std::copy(bytes.ptr(),bytes.ptr()+32,result.begin());
    return result;
}
inline String physics_profile(const cybersand::WorldConfig& c) {
    cybersand::setup::encoding::Writer out;
    out.text("cybersand-persistent-area-physical-profile-v1");
    out.integer(c.chunk_size); out.integer(c.activity_block_size); out.integer(c.scheduling_core_size);
    out.integer(c.maximum_rule_radius); out.integer(c.sleep_after_quiet_ticks); out.integer(c.ambient_temperature);
    out.integer(static_cast<std::uint8_t>(c.backend)); out.integer(c.maximum_explosion_radius);
    out.integer(static_cast<std::uint8_t>(c.physics_diagnostics.disable_powder_exchange_targets));
    out.integer(c.physics_diagnostics.mercury_viscosity);
    out.integer(c.interaction_policy.downward_support_cells); out.integer(c.interaction_policy.side_support_cells);
    out.integer(c.interaction_policy.mercury_exchange_period);
    out.integer(c.water_experiment_policy.mass_bits()); out.integer(c.water_experiment_policy.coherence_ticks());
    out.integer(static_cast<std::uint8_t>(c.water_experiment_policy.rest_policy()));
    out.digest(cybersand::receipt::detail::transport_identity(c.transport_policy));
    out.digest(c.liquid_solver_policy.policy_hash());
    out.integer(c.pressure_gas_compartment_capacity);
    return prepared_liquid_detail::digest(cybersand::Sha256::of(out.bytes));
}
inline Dictionary execution(const cybersand::WorldConfig& c) {
    Dictionary out;
    out["worker_threads"]=static_cast<std::int64_t>(c.worker_threads);
    out["chunk_size"]=c.chunk_size; out["activity_block_size"]=c.activity_block_size;
    out["scheduling_core_size"]=c.scheduling_core_size; out["maximum_rule_radius"]=c.maximum_rule_radius;
    out["initial_chunk_reserve"]=static_cast<std::int64_t>(c.initial_chunk_reserve);
    out["parallel_job_threshold"]=static_cast<std::int64_t>(c.parallel_job_threshold);
    out["active_core_capacity"]=static_cast<std::int64_t>(c.active_core_capacity);
    out["active_chunk_capacity"]=static_cast<std::int64_t>(c.active_chunk_capacity);
    out["maximum_chunk_count"]=static_cast<std::int64_t>(c.maximum_chunk_count);
    out["deferred_event_capacity"]=static_cast<std::int64_t>(c.deferred_event_capacity);
    out["maximum_explosion_radius"]=c.maximum_explosion_radius;
    out["backend"]="phased_in_place";
    return out;
}
inline void validate_execution_claim(const Dictionary& claim, const cybersand::WorldConfig& actual) {
    const auto expected=execution(actual);
    if (claim.size()!=expected.size()) throw std::invalid_argument("Persistent area execution schema mismatch");
    const auto keys=expected.keys();
    for (std::int64_t i=0; i<keys.size(); ++i) {
        const String key=keys[i];
        if (!claim.has(key) || claim[key].get_type()!=expected[key].get_type())
            throw std::invalid_argument("Persistent area execution field type mismatch");
        // Worker count is an explicitly selectable execution setting. Its
        // configured value is recorded, not falsely serialized by CYPS.
        if (key=="worker_threads") {
            const auto workers=static_cast<std::int64_t>(claim[key]);
            if (workers<1 || workers>32) throw std::invalid_argument("Persistent area worker count invalid");
        } else if (claim[key]!=expected[key])
            throw std::invalid_argument("Persistent area execution profile is incompatible");
    }
}
inline void validate_identity(const Dictionary& identity) {
    if (identity.size()!=4 || identity.get("generation",Variant()).get_type()!=Variant::INT ||
        static_cast<std::int64_t>(identity["generation"])<1)
        throw std::invalid_argument("Persistent area continuation identity requires a positive generation");
    for (const char* key : {"session_id","area_id","operation_id"})
        if (identity.get(key,Variant()).get_type()!=Variant::STRING || !identifier(identity[key]))
            throw std::invalid_argument("Persistent area continuation identity is malformed");
}
inline void validate_capsule_shape(const Dictionary& capsule) {
    if (capsule.size()!=15) throw std::invalid_argument("Persistent area capsule schema has missing or unknown fields");
    for (const char* key : {"schema","physical_hash_version","format_version","completed_tick",
                           "native_chunks","native_resident_cell_bytes"})
        if (capsule.get(key,Variant()).get_type()!=Variant::INT)
            throw std::invalid_argument("Persistent area capsule integer field invalid");
    for (const char* key : {"sha256","policy_sha256","authored_source_sha256","physics_profile_sha256"})
        if (capsule.get(key,Variant()).get_type()!=Variant::STRING || !hex(capsule[key],64))
            throw std::invalid_argument("Persistent area capsule digest field invalid");
    if (capsule.get("physical_hash",Variant()).get_type()!=Variant::STRING || !hex(capsule["physical_hash"],16) ||
        capsule.get("bytes",Variant()).get_type()!=Variant::PACKED_BYTE_ARRAY ||
        capsule.get("extent",Variant()).get_type()!=Variant::VECTOR2I ||
        capsule.get("execution",Variant()).get_type()!=Variant::DICTIONARY ||
        capsule.get("host_settings",Variant()).get_type()!=Variant::DICTIONARY ||
        static_cast<std::int64_t>(capsule["schema"])!=1 ||
        static_cast<std::int64_t>(capsule["format_version"])!=2 ||
        static_cast<std::int64_t>(capsule["physical_hash_version"])!=2 ||
        static_cast<std::int64_t>(capsule["completed_tick"])<0 ||
        static_cast<std::int64_t>(capsule["native_chunks"])<0 ||
        static_cast<std::int64_t>(capsule["native_chunks"])>128 ||
        static_cast<std::int64_t>(capsule["native_resident_cell_bytes"])<0 ||
        static_cast<Vector2i>(capsule["extent"])!=Vector2i(512,512))
        throw std::invalid_argument("Persistent area capsule version, state identity or extent invalid");
}
} // namespace persistent_area_detail

inline void CyberDemoBridge::validate_continuation_dependencies(const CyberNativeCellWorld& adapter) {
    if (adapter.spray_.enabled || adapter.spray_.jet_enabled)
        throw std::invalid_argument("Persistent area transition is pinned by Water spray");
    for (const auto& body : adapter.current_bodies_) if (body.valid)
        throw std::invalid_argument("Persistent area transition is pinned by a live body");
    for (const auto& body : adapter.previous_bodies_) if (body.valid)
        throw std::invalid_argument("Persistent area transition is pinned by a previous body sample");
    if (adapter.workbench_)
        for (const auto& owner : adapter.workbench_->sample.owners) if (owner.instance!=0)
            throw std::invalid_argument("Persistent area transition is pinned by a live Workbench owner");
    if (adapter.world_)
        for (std::int32_t y=0; y<adapter.extent_.y; ++y)
            for (std::int32_t x=0; x<adapter.extent_.x; ++x)
                if (adapter.world_->transient_obstacle_at(x,y)!=0)
                    throw std::invalid_argument("Persistent area transition is pinned by a retained transient body mask");
}
inline void CyberDemoBridge::validate_continuation_host(const CyberNativeCellWorld& adapter) {
    if (!adapter.world_ || !adapter.workbench_ || adapter.extent_!=Vector2i(512,512) ||
        adapter.cadence_lod_enabled_)
        throw std::invalid_argument("Persistent areas require actor-free 512x512 Workbench, full simulation and disabled cadence");
    validate_continuation_dependencies(adapter);
    cybersand::persistent_areas::validate_domain(*adapter.world_);
}

inline Dictionary CyberDemoBridge::continuation_capsule(const cybersand::World& world,
    const cybersand::setup::SetupDescriptor& setup, const String& response, bool window) {
    if (!setup.definition_digest) throw std::invalid_argument("Persistent area authored source identity unavailable");
    const auto captured=cybersand::persistent_areas::capture(world);
    if (captured.completed_tick>static_cast<std::uint64_t>(INT64_MAX))
        throw std::length_error("Persistent area native tick does not fit the host game-time range");
    PackedByteArray bytes;
    if (bytes.resize(static_cast<std::int64_t>(captured.bytes.size()))!=OK) throw std::bad_alloc();
    std::copy(captured.bytes.begin(),captured.bytes.end(),bytes.ptrw());
    Dictionary settings;
    settings["response"]=response;
    settings["simulation_window_enabled"]=window; settings["cadence_lod_enabled"]=false;
    settings["liquid_surface_adhesion_enabled"]=world.liquid_surface_adhesion_enabled();
    settings["region"]=PackedInt32Array{0,0,512,512};
    Dictionary out;
    out["schema"]=1; out["bytes"]=bytes;
    out["sha256"]=prepared_liquid_detail::digest(captured.sha256);
    out["physical_hash"]=String::num_uint64(captured.physical_hash,16).lpad(16,"0");
    out["physical_hash_version"]=2; out["format_version"]=2;
    out["completed_tick"]=static_cast<std::int64_t>(captured.completed_tick);
    out["extent"]=Vector2i(512,512);
    out["policy_sha256"]=prepared_liquid_detail::digest(world.liquid_solver_policy().policy_hash());
    out["physics_profile_sha256"]=persistent_area_detail::physics_profile(world.config());
    out["authored_source_sha256"]=prepared_liquid_detail::digest(*setup.definition_digest);
    out["execution"]=persistent_area_detail::execution(world.config()); out["host_settings"]=settings;
    out["native_chunks"]=static_cast<std::int64_t>(captured.chunks);
    out["native_resident_cell_bytes"]=static_cast<std::int64_t>(captured.resident_cell_bytes);
    return out;
}

inline Dictionary CyberDemoBridge::capture_workbench_continuation(const Ref<CyberNativeCellWorld>& adapter) {
    error_=String();
    try {
        if (adapter.is_null()) throw std::invalid_argument("Persistent area World absent");
        validate_continuation_host(*adapter.ptr());
        return continuation_capsule(*adapter->world_,adapter->applied_liquid_setup_,adapter->workbench_->response,
            adapter->simulation_window_enabled_);
    } catch (const std::exception& error) { error_=String(error.what()); return {}; }
}

inline void CyberDemoBridge::refresh_continuation_receipt(CyberNativeCellWorld& adapter) {
    auto& pending=*adapter.pending_liquid_world_;
    if (!pending.continuation || !pending.workbench)
        throw std::invalid_argument("Preparation is not a persistent-area continuation");
    const auto capsule=continuation_capsule(*pending.world,pending.setup,pending.workbench->response,pending.window);
    const auto facts=std::make_unique<cybersand::receipt::NativeFacts>(
        cybersand::receipt::capture_native_facts(*pending.world,pending.setup));
    cybersand::setup::encoding::Writer encoded;
    encoded.text("cybersand-workbench-continuation-receipt-v1"); encoded.integer(std::uint16_t{1});
    encoded.integer(adapter.liquid_policy_session_generation_+1);
    cybersand::receipt::detail::native_facts(encoded,*facts);
    cybersand::setup::encode_setup_descriptor(encoded,pending.setup);
    encoded.digest(persistent_area_detail::digest_value(capsule["sha256"]));
    encoded.digest(persistent_area_detail::digest_value(pending.source_checkpoint_sha256));
    encoded.digest(persistent_area_detail::digest_value(pending.source_construction_receipt["receipt_hash"]));
    encoded.integer(pending.source_checkpoint_tick);
    for (const char* key : {"session_id","area_id","operation_id"}) {
        const String value=pending.continuation_identity[key];
        encoded.text(value.utf8().get_data());
    }
    encoded.integer(static_cast<std::uint64_t>(static_cast<std::int64_t>(pending.continuation_identity["generation"])));
    encoded.text(pending.workbench->response.utf8().get_data());
    encoded.integer(static_cast<std::uint8_t>(pending.window)); encoded.integer(std::uint8_t{0}); // cadence disabled
    Dictionary receipt;
    PackedByteArray bytes;
    if (bytes.resize(static_cast<std::int64_t>(encoded.bytes.size()))!=OK) throw std::bad_alloc();
    std::copy(encoded.bytes.begin(),encoded.bytes.end(),bytes.ptrw());
    receipt["kind"]="workbench_continuation"; receipt["schema_version"]=1;
    receipt["canonical_bytes"]=bytes;
    receipt["receipt_hash"]=prepared_liquid_detail::digest(cybersand::Sha256::of(encoded.bytes));
    receipt["qualifications"]=15; receipt["eligible_for_full_matched_evidence"]=false;
    receipt["session_generation"]=static_cast<std::int64_t>(adapter.liquid_policy_session_generation_+1);
    receipt["source_construction_receipt"]=pending.source_construction_receipt.duplicate(true);
    receipt["source_checkpoint_sha256"]=pending.source_checkpoint_sha256;
    receipt["checkpoint_sha256"]=capsule["sha256"];
    receipt["continuation_identity"]=pending.continuation_identity.duplicate(true);
    receipt["authored_source_sha256"]=capsule["authored_source_sha256"];
    receipt["physical_state_hash"]=capsule["physical_hash"];
    receipt["physical_state_hash_version"]=2; receipt["physical_state_format_version"]=2;
    receipt["completed_tick"]=capsule["completed_tick"];
    receipt["source_completed_tick"]=static_cast<std::int64_t>(pending.source_checkpoint_tick);
    receipt["advanced_native_ticks"]=static_cast<std::int64_t>(pending.world->completed_tick_index()-pending.source_checkpoint_tick);
    receipt["policy_hash"]=capsule["policy_sha256"];
    receipt["worker_threads"]=static_cast<std::int64_t>(pending.world->config().worker_threads);
    receipt["maximum_rule_radius"]=2; receipt["workbench_extent"]=pending.extent;
    receipt["workbench_response"]=pending.workbench->response;
    receipt["workbench_initial_sample_sha256"]=pending.workbench_initial_digest;
    receipt["initial_body_state_sha256"]=pending.initial_body_digest; receipt["initial_body_count"]=0;
    receipt["region"]=PackedInt32Array{0,0,512,512};
    receipt["run_intent"]="controlled"; receipt["pacing"]="fixed_steps";
    receipt["simulation_window_enabled"]=pending.window; receipt["cadence_lod_enabled"]=false;
    receipt["liquid_surface_adhesion_enabled"]=pending.world->liquid_surface_adhesion_enabled();
    pending.continuation_capsule=capsule;
    pending.receipt=receipt;
    pending.continuation_dirty=false;
}

inline std::int64_t CyberDemoBridge::prepare_workbench_continuation(
    const Ref<CyberNativeCellWorld>& adapter, const PackedInt32Array& rectangles,
    const PackedInt32Array& profile, const PackedInt32Array& policy, const PackedInt32Array& water_fills,
    const PackedInt32Array& liquid_policy, const Dictionary& options) {
    error_=String(); last_liquid_policy_refusal_.clear();
    if (adapter.is_valid()) adapter->pending_liquid_world_.reset();
    try {
        if (adapter.is_null() || !adapter->world_ || adapter->world_->has_failed())
            throw std::invalid_argument("Healthy retained World required for area restoration");
        validate_continuation_dependencies(*adapter.ptr());
        if (options.get("workbench_continuation",Variant()).get_type()!=Variant::DICTIONARY ||
            options.get("workbench_continuation_identity",Variant()).get_type()!=Variant::DICTIONARY)
            throw std::invalid_argument("Persistent area preparation requires a capsule and explicit identity");
        const Dictionary capsule=options["workbench_continuation"];
        const Dictionary identity=options["workbench_continuation_identity"];
        persistent_area_detail::validate_capsule_shape(capsule);
        persistent_area_detail::validate_identity(identity);
        if (adapter->applied_liquid_construction_receipt_.get("kind",String())==Variant("workbench_continuation")) {
            const Dictionary previous=adapter->applied_liquid_construction_receipt_["continuation_identity"];
            if (previous.get("operation_id",String())==identity["operation_id"])
                throw std::invalid_argument("Persistent area operation identity was already committed");
        }
        if (options.get("workbench_extent",Variant()).get_type()!=Variant::VECTOR2I ||
            static_cast<Vector2i>(options["workbench_extent"])!=Vector2i(512,512) ||
            options.get("simulation_window_enabled",true).get_type()!=Variant::BOOL ||
            options.get("cadence_lod_enabled",true)!=Variant(false) ||
            options.has("workbench_generated") || options.has("workbench_material_baseline") ||
            static_cast<bool>(options.get("workbench_retain_cells",false)) ||
            static_cast<bool>(options.get("workbench_convert_liquid_inventory",false)) ||
            !String(options.get("normalization",String())).is_empty())
            throw std::invalid_argument("Persistent continuation requires an exclusive full-canvas source with no material conversion");
        if (capsule["authored_source_sha256"]!=options.get("definition_hash",String()))
            throw std::invalid_argument("Persistent area authored source identity differs from the validated definition");
        const Dictionary host=capsule["host_settings"];
        if (host.size()!=5 || host.get("response",Variant()).get_type()!=Variant::STRING ||
            host.get("simulation_window_enabled",Variant()).get_type()!=Variant::BOOL ||
            host["simulation_window_enabled"]!=options.get("simulation_window_enabled",true) ||
            host.get("cadence_lod_enabled",true)!=Variant(false) ||
            host.get("liquid_surface_adhesion_enabled",Variant()).get_type()!=Variant::BOOL ||
            host.get("region",Variant()).get_type()!=Variant::PACKED_INT32_ARRAY ||
            host["region"]!=Variant(PackedInt32Array{0,0,512,512}) ||
            host["response"]!=options.get("workbench_response",String()) ||
            host["liquid_surface_adhesion_enabled"]!=options.get("liquid_surface_adhesion_enabled",true))
            throw std::invalid_argument("Persistent area saved host settings are incompatible");
        Dictionary source_options=options.duplicate(true);
        source_options.erase("workbench_continuation"); source_options.erase("workbench_continuation_identity");
        // Real source validation is retained. This original constructed World
        // remains private and is never mistaken for the saved dynamic state.
        const auto token=prepare_liquid_candidate(adapter,rectangles,profile,policy,water_fills,liquid_policy,source_options,nullptr);
        if (token<=0) return 0;
        auto& pending=*adapter->pending_liquid_world_;
        if (!pending.workbench || pending.initial_body_input.size()!=0 || adapter->spray_.enabled || adapter->spray_.jet_enabled)
            throw std::invalid_argument("Persistent area continuation refuses live bodies or Water spray");
        for (const auto& owner : pending.workbench->sample.owners) if (owner.instance!=0)
            throw std::invalid_argument("Persistent area target has an unsupported live actor");
        cybersand::persistent_areas::validate_domain(*pending.world);
        persistent_area_detail::validate_execution_claim(capsule["execution"],pending.world->config());
        if (capsule["physics_profile_sha256"]!=Variant(persistent_area_detail::physics_profile(pending.world->config())))
            throw std::invalid_argument("Persistent area physical profile differs from the validated source");
        const PackedByteArray payload=capsule["bytes"];
        const String physical=capsule["physical_hash"];
        const auto physical_bytes=physical.hex_decode();
        std::uint64_t physical_value=0;
        for (std::int64_t i=0; i<physical_bytes.size(); ++i) physical_value=(physical_value<<8U)|physical_bytes[i];
        auto restored=cybersand::persistent_areas::restore(pending.world->config(),
            {payload.ptr(),static_cast<std::size_t>(payload.size())},persistent_area_detail::digest_value(capsule["sha256"]),
            static_cast<std::uint64_t>(static_cast<std::int64_t>(capsule["completed_tick"])),physical_value);
        if (capsule["physics_profile_sha256"]!=Variant(persistent_area_detail::physics_profile(restored->config())) ||
            capsule["policy_sha256"]!=Variant(prepared_liquid_detail::digest(restored->liquid_solver_policy().policy_hash())) ||
            restored->liquid_surface_adhesion_enabled()!=static_cast<bool>(host["liquid_surface_adhesion_enabled"]) ||
            static_cast<std::int64_t>(restored->chunk_count())!=static_cast<std::int64_t>(capsule["native_chunks"]))
            throw std::invalid_argument("Persistent area native readback differs from the saved capsule");
        // Only nonpersistent empty coupling is reconstructed. Region, applied
        // core range, clocks, cells, events and solver state remain untouched.
        restored->configure_transient_obstacles({0,0,512,512},true);
        restored->enable_transient_granular_wrenches(true);
        // Arrival witnesses are a host-body dependency, deliberately absent
        // from CYPS. This domain has no bodies and admits none after activation;
        // leave the witness disabled instead of bypassing its tick-zero-only
        // construction contract on a restored nonzero native clock.
        if (restored->physical_state_hash()!=physical_value)
            throw std::logic_error("Rebuilding empty host coupling changed native physical authority");
        pending.source_construction_receipt=pending.receipt.duplicate(true);
        pending.source_checkpoint_sha256=capsule["sha256"];
        pending.source_checkpoint_tick=restored->completed_tick_index();
        pending.world.swap(restored);
        ++adapter->resident_native_restorations_;
        pending.continuation_identity=identity.duplicate(true);
        pending.continuation=true; pending.continuation_dirty=true;
        pending.window=host["simulation_window_enabled"]; pending.cadence=false; pending.origin={0,0}; pending.size={512,512};
        pending.adhesion=pending.world->liquid_surface_adhesion_enabled();
        refresh_continuation_receipt(*adapter.ptr());
        return token;
    } catch (const std::exception& error) {
        if (adapter.is_valid()) adapter->pending_liquid_world_.reset();
        error_=String("Persistent area preparation refused; retained World preserved: ")+String(error.what());
        return 0;
    }
}

inline Dictionary CyberDemoBridge::capture_prepared_workbench_continuation(
    const Ref<CyberNativeCellWorld>& adapter,std::int64_t token) {
    error_=String();
    try {
        if (adapter.is_null() || token<=0 || !adapter->pending_liquid_world_ ||
            adapter->pending_liquid_world_->token!=static_cast<std::uint64_t>(token) ||
            !adapter->pending_liquid_world_->continuation)
            throw std::invalid_argument("Persistent area preparation token is absent or retired");
        if (adapter->pending_liquid_world_->continuation_dirty) refresh_continuation_receipt(*adapter.ptr());
        return adapter->pending_liquid_world_->continuation_capsule.duplicate(true);
    } catch (const std::exception& error) { error_=String(error.what()); return {}; }
}

inline Dictionary CyberDemoBridge::advance_workbench_continuation(const Ref<CyberNativeCellWorld>& adapter,
    std::int64_t token,std::int64_t maximum_ticks,std::int64_t maximum_microseconds) {
    error_=String();
    Dictionary out;
    try {
        if (adapter.is_null() || token<=0 || !adapter->pending_liquid_world_ ||
            adapter->pending_liquid_world_->token!=static_cast<std::uint64_t>(token) ||
            !adapter->pending_liquid_world_->continuation)
            throw std::invalid_argument("Persistent area preparation token is absent or retired");
        if (maximum_ticks<1 || maximum_ticks>32 || maximum_microseconds<1 || maximum_microseconds>100'000)
            throw std::invalid_argument("Persistent catch-up requires 1..32 ticks and 1..100000 microseconds per slice");
        auto& pending=*adapter->pending_liquid_world_;
        const auto result=cybersand::persistent_areas::advance(*pending.world,
            static_cast<std::uint32_t>(maximum_ticks),static_cast<std::uint64_t>(maximum_microseconds));
        pending.continuation_dirty=true;
        out["ok"]=true; out["token"]=token; out["completed_ticks"]=static_cast<std::int64_t>(result.completed_ticks);
        out["completed_tick"]=static_cast<std::int64_t>(result.completed_tick);
        out["current_tick"]=static_cast<std::int64_t>(result.completed_tick);
        out["physical_hash"]=String::num_uint64(pending.world->physical_state_hash(),16).lpad(16,"0");
        out["elapsed_us"]=static_cast<std::int64_t>(result.elapsed_microseconds);
        out["observed_workers"]=static_cast<std::int64_t>(result.observed_workers);
        out["visited_cells"]=static_cast<std::int64_t>(result.visited_cells);
        out["moved_cells"]=static_cast<std::int64_t>(result.moved_cells);
        return out;
    } catch (const std::exception& error) {
        // A partly failed private tick is never committed or exposed as a new
        // durable state. Invalid budgets also retire only the matching token.
        if (adapter.is_valid() && adapter->pending_liquid_world_ && token>0 &&
            adapter->pending_liquid_world_->token==static_cast<std::uint64_t>(token))
            adapter->pending_liquid_world_.reset();
        error_=String(error.what()); out["ok"]=false; out["error"]=error_; out["completed_ticks"]=0;
        return out;
    }
}

inline Dictionary CyberDemoBridge::assess_workbench_coarse_advance(const Ref<CyberNativeCellWorld>& adapter,
    std::int64_t requested_ticks) {
    error_=String();
    Dictionary out;
    try {
        if (adapter.is_null() || requested_ticks<1) throw std::invalid_argument("Positive coarse advance request required");
        validate_continuation_host(*adapter.ptr());
        const auto result=cybersand::persistent_areas::assess_coarse_advance(*adapter->world_,static_cast<std::uint64_t>(requested_ticks));
        out["admitted"]=result.admitted; out["credited_ticks"]=static_cast<std::int64_t>(result.credited_ticks);
        out["requested_ticks"]=requested_ticks; out["remaining_debt_ticks"]=requested_ticks;
        out["reason"]=String(result.reason); out["fallback"]="bounded_exact_native_steps";
    } catch (const std::exception& error) { error_=String(error.what()); out["error"]=error_; out["admitted"]=false; out["credited_ticks"]=0; }
    return out;
}
} // namespace godot
