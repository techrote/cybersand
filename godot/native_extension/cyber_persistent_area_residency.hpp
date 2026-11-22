#pragma once

#include <cassert>

// GEN-006 RAMCACHE. All methods are exclusive-owner operations. A resident
// record never exposes World storage, a C++ pointer, or a second active adapter.
// Authoring/clock/durability authority is intentionally owned by the host; these
// receipts prove only the retained native allocation and its completed boundary.
namespace godot {
namespace persistent_residency_detail {
inline void identity(const Dictionary& value) {
    if (value.size()!=5) throw std::invalid_argument("Resident identity schema mismatch");
    for (const char* key : {"session_id","area_id","incarnation"})
        if (value.get(key,Variant()).get_type()!=Variant::STRING || !persistent_area_detail::identifier(value[key]))
            throw std::invalid_argument("Resident area identity is malformed");
    for (const char* key : {"runtime_sha256","authored_source_sha256"})
        if (value.get(key,Variant()).get_type()!=Variant::STRING || !persistent_area_detail::hex(value[key],64))
            throw std::invalid_argument("Resident source/runtime identity is malformed");
}
inline Dictionary failure(const char* detail) {
    Dictionary out; out["ok"]=false; out["error"]=String(detail); return out;
}
inline void positive(const Dictionary& value,const char* key,bool zero=false) {
    if (value.get(key,Variant()).get_type()!=Variant::INT || static_cast<std::int64_t>(value[key])<(zero?0:1))
        throw std::invalid_argument("Resident fence has an invalid integer field");
}
} // namespace persistent_residency_detail

inline CyberNativeCellWorld::ResidentArea& CyberDemoBridge::resident_find(
    CyberNativeCellWorld& adapter,std::uint64_t handle) {
    for (const auto& entry:adapter.resident_areas_)
        if (entry->handle==handle && handle!=0) return *entry;
    throw std::invalid_argument("Resident handle is absent or retired");
}

inline Dictionary CyberDemoBridge::resident_receipt(CyberNativeCellWorld& adapter,
    CyberNativeCellWorld::ResidentArea& area) {
    const bool active=area.handle==adapter.active_resident_handle_;
    const auto* world=active?adapter.world_.get():(area.payload?area.payload->world.get():nullptr);
    const auto* exchange=active?adapter.render_exchange_.get():(area.payload?area.payload->exchange.get():nullptr);
    if (!world || (active && area.payload) || (!active && !area.payload))
        throw std::logic_error("Resident native ownership is inconsistent");
    if (active) {
        if (area.active_construction_generation!=adapter.liquid_policy_session_generation_ ||
            !adapter.applied_liquid_setup_.definition_digest ||
            prepared_liquid_detail::digest(*adapter.applied_liquid_setup_.definition_digest)!=
                static_cast<String>(area.identity["authored_source_sha256"]))
            throw std::invalid_argument("Resident active construction identity was replaced");
        area.mutation=adapter.revision_;
    }
    Dictionary out;
    out["schema"]=1; out["handle"]=static_cast<std::int64_t>(area.handle);
    out["identity"]=area.identity.duplicate(true);
    out["resident_generation"]=static_cast<std::int64_t>(area.generation);
    out["mutation_generation"]=static_cast<std::int64_t>(area.mutation);
    out["completed_tick"]=static_cast<std::int64_t>(world->completed_tick_index());
    out["physics_profile_sha256"]=area.physics_profile;
    out["native_bytes"]=static_cast<std::int64_t>(world->current_resident_storage_bytes()+
        (exchange?exchange->resident_storage_bytes():0)+sizeof(CyberNativeCellWorld::PendingLiquidWorld)+
        sizeof(CyberNativeCellWorld::ResidentArea)+sizeof(CyberNativeCellWorld::Workbench));
    out["native_reservation_bytes"]=static_cast<std::int64_t>(world->current_resident_reservation_bytes()+
        (exchange?exchange->resident_storage_bytes():0)+sizeof(CyberNativeCellWorld::PendingLiquidWorld)+
        sizeof(CyberNativeCellWorld::ResidentArea)+sizeof(CyberNativeCellWorld::Workbench));
    out["native_chunks"]=static_cast<std::int64_t>(world->chunk_count());
    out["worker_threads"]=static_cast<std::int64_t>(world->config().worker_threads);
    out["active"]=active; out["failed"]=world->has_failed();
    return out;
}

inline CyberNativeCellWorld::ResidentArea& CyberDemoBridge::resident_validate(
    CyberNativeCellWorld& adapter,const Dictionary& claim,bool allow_quarantined) {
    using persistent_residency_detail::positive;
    if (claim.get("schema",Variant())!=Variant(1) || claim.get("identity",Variant()).get_type()!=Variant::DICTIONARY ||
        claim.get("active",Variant()).get_type()!=Variant::BOOL)
        throw std::invalid_argument("Resident receipt schema mismatch");
    positive(claim,"handle"); positive(claim,"resident_generation");
    positive(claim,"mutation_generation",true); positive(claim,"completed_tick",true);
    persistent_residency_detail::identity(claim["identity"]);
    auto& entry=resident_find(adapter,static_cast<std::uint64_t>(static_cast<std::int64_t>(claim["handle"])));
    const auto actual=resident_receipt(adapter,entry);
    for (const char* key : {"identity","resident_generation","mutation_generation","completed_tick",
                           "physics_profile_sha256","active"})
        if (!claim.has(key) || claim[key]!=actual[key])
            throw std::invalid_argument("Resident receipt is stale or belongs to another area incarnation");
    if (static_cast<bool>(actual["failed"]) && !allow_quarantined)
        throw std::invalid_argument("Resident World is quarantined");
    return entry;
}

inline std::unique_ptr<CyberNativeCellWorld::PendingLiquidWorld>
CyberDemoBridge::resident_stage_departure(CyberNativeCellWorld& adapter) {
    if (adapter.active_resident_handle_==0) return {};
    auto& active=resident_find(adapter,adapter.active_resident_handle_);
    (void)resident_receipt(adapter,active);
    if (active.payload || !adapter.world_ || adapter.world_->has_failed() ||
        adapter.world_->tick_index()!=adapter.world_->completed_tick_index() || !adapter.workbench_ ||
        adapter.extent_!=Vector2i(512,512) || adapter.cadence_lod_enabled_ ||
        active.physics_profile!=persistent_area_detail::physics_profile(adapter.world_->config()))
        throw std::invalid_argument("Resident departure is outside its admitted native domain");
    const auto region=adapter.world_->simulation_region();
    if (!region || region->x!=0 || region->y!=0 || region->width!=512 || region->height!=512)
        throw std::invalid_argument("Resident departure requires the full admitted region");
    validate_continuation_dependencies(adapter);
    auto staged=std::make_unique<CyberNativeCellWorld::PendingLiquidWorld>();
    staged->extent=adapter.extent_;
    staged->origin=adapter.last_view_origin_; staged->size=adapter.last_view_size_;
    staged->window=adapter.simulation_window_enabled_; staged->cadence=adapter.cadence_lod_enabled_;
    staged->adhesion=adapter.liquid_surface_adhesion_enabled_;
    staged->retained_revision=adapter.revision_;
    // The dependency guard scans occupancy, but departure performs no full
    // physical-state hash, encoded checkpoint, World copy or reconstruction.
    return staged;
}

inline void CyberDemoBridge::resident_take_active(CyberNativeCellWorld& adapter,
    std::unique_ptr<CyberNativeCellWorld::PendingLiquidWorld> staged) noexcept {
    if (!staged) return;
    CyberNativeCellWorld::ResidentArea* source=nullptr;
    for (const auto& entry:adapter.resident_areas_)
        if (entry->handle==adapter.active_resident_handle_) source=entry.get();
    // Staging established this exact record while the exclusive owner held it.
    assert(source && !source->payload);
    staged->world.swap(adapter.world_);
    staged->exchange.swap(adapter.render_exchange_);
    staged->workbench.swap(adapter.workbench_);
    std::swap(staged->setup,adapter.applied_liquid_setup_);
    std::swap(staged->receipt,adapter.applied_liquid_construction_receipt_);
    source->mutation=adapter.revision_;
    ++source->generation;
    source->payload=std::move(staged);
    adapter.active_resident_handle_=0;
}

inline void CyberDemoBridge::resident_install(CyberNativeCellWorld& adapter,
    CyberNativeCellWorld::ResidentArea& target) noexcept {
    auto& payload=*target.payload;
    adapter.world_.swap(payload.world); adapter.render_exchange_.swap(payload.exchange);
    adapter.workbench_.swap(payload.workbench);
    std::swap(adapter.applied_liquid_setup_,payload.setup);
    std::swap(adapter.applied_liquid_construction_receipt_,payload.receipt);
    adapter.extent_=payload.extent;
    adapter.simulation_window_enabled_=payload.window; adapter.cadence_lod_enabled_=payload.cadence;
    adapter.liquid_surface_adhesion_enabled_=payload.adhesion;
    adapter.last_view_origin_=payload.origin; adapter.last_view_size_=payload.size;
    adapter.last_horizontal_buffer_=adapter.last_vertical_buffer_=0;
    adapter.worker_threads_=adapter.world_->config().worker_threads;
    adapter.default_demo_recipe_active_=false;
    adapter.current_bodies_={}; adapter.previous_bodies_={}; adapter.clear_observations();
    adapter.raster_indices_.clear(); adapter.last_stats_={};
    adapter.spray_tick_={}; adapter.spray_total_={}; adapter.spray_budget_used_.fill(0); adapter.spray_jet_phase_=0;
    adapter.simulation_time_ms_=0; adapter.tick_failure_count_=0; adapter.last_tick_error_=String();
    adapter.render_cells_revision_=adapter.hard_surface_rectangles_revision_=adapter.hard_surface_chunk_rectangles_revision_=UINT64_MAX;
    adapter.hard_surface_cache_valid_=false; adapter.hard_surface_cache_world_=nullptr;
    adapter.render_snapshot_full_refresh_required_=true;
    adapter.liquid_construction_attempt_.clear();
    adapter.revision_=std::max(adapter.revision_,target.mutation)+1;
    ++adapter.hard_surface_revision_; ++adapter.liquid_policy_session_generation_;
    ++target.generation; target.mutation=adapter.revision_;
    target.active_construction_generation=adapter.liquid_policy_session_generation_;
    adapter.active_resident_handle_=target.handle;
    target.payload.reset(); // Moved-from bundle; no native World is destroyed.
}

inline Dictionary CyberDemoBridge::resident_admit(const Ref<CyberNativeCellWorld>& adapter,
    const Dictionary& identity) {
    error_=String();
    try {
        if (adapter.is_null()) throw std::invalid_argument("Resident adapter is absent");
        persistent_residency_detail::identity(identity);
        if (adapter->active_resident_handle_) {
            auto& active=resident_find(*adapter.ptr(),adapter->active_resident_handle_);
            if (active.identity!=identity) throw std::invalid_argument("Active resident identity cannot be rebound");
            Dictionary out; out["ok"]=true; out["receipt"]=resident_receipt(*adapter.ptr(),active); return out;
        }
        if (adapter->pending_liquid_world_) throw std::invalid_argument("Finish the native preparation before residency admission");
        validate_continuation_host(*adapter.ptr());
        if (!adapter->applied_liquid_setup_.definition_digest ||
            prepared_liquid_detail::digest(*adapter->applied_liquid_setup_.definition_digest)!=
                static_cast<String>(identity["authored_source_sha256"]))
            throw std::invalid_argument("Resident authored identity differs from the validated native source");
        for (const auto& entry:adapter->resident_areas_) {
            if (entry->identity["session_id"]!=identity["session_id"] || entry->identity["runtime_sha256"]!=identity["runtime_sha256"])
                throw std::invalid_argument("Resident cache session/runtime cannot be mixed");
            if (entry->identity["area_id"]==identity["area_id"])
                throw std::invalid_argument("A newer resident copy of this area already exists");
        }
        if (adapter->resident_areas_.size()>=64 || adapter->next_resident_handle_>=static_cast<std::uint64_t>(INT64_MAX))
            throw std::length_error("Resident native handle capacity exhausted");
        auto entry=std::make_unique<CyberNativeCellWorld::ResidentArea>();
        entry->identity=identity.duplicate(true);
        entry->handle=adapter->next_resident_handle_+1;
        entry->mutation=adapter->revision_;
        entry->physics_profile=persistent_area_detail::physics_profile(adapter->world_->config());
        entry->active_construction_generation=adapter->liquid_policy_session_generation_;
        adapter->resident_areas_.push_back(std::move(entry));
        adapter->active_resident_handle_=++adapter->next_resident_handle_;
        ++adapter->resident_admissions_;
        Dictionary out; out["ok"]=true;
        out["receipt"]=resident_receipt(*adapter.ptr(),*adapter->resident_areas_.back()); return out;
    } catch (const std::exception& error) { error_=String(error.what()); return persistent_residency_detail::failure(error.what()); }
}

inline Dictionary CyberDemoBridge::resident_status(const Ref<CyberNativeCellWorld>& adapter) {
    error_=String();
    try {
        if (adapter.is_null()) throw std::invalid_argument("Resident adapter is absent");
        Dictionary out,counts; Array entries,inactive; std::int64_t bytes=0;
        out["active"]=Dictionary();
        for (const auto& entry:adapter->resident_areas_) {
            auto receipt=resident_receipt(*adapter.ptr(),*entry);
            bytes+=static_cast<std::int64_t>(receipt["native_bytes"]);
            if (static_cast<bool>(receipt["active"])) out["active"]=receipt;
            else inactive.push_back(receipt);
            entries.push_back(receipt);
        }
        counts["hot_activations"]=static_cast<std::int64_t>(adapter->resident_hot_activations_);
        counts["captures"]=static_cast<std::int64_t>(adapter->resident_captures_);
        counts["private_ticks"]=static_cast<std::int64_t>(adapter->resident_steps_);
        counts["admissions"]=static_cast<std::int64_t>(adapter->resident_admissions_);
        counts["releases"]=static_cast<std::int64_t>(adapter->resident_releases_);
        counts["imports"]=static_cast<std::int64_t>(adapter->resident_imports_);
        counts["source_constructions"]=static_cast<std::int64_t>(adapter->resident_source_constructions_);
        counts["native_restorations"]=static_cast<std::int64_t>(adapter->resident_native_restorations_);
        out["ok"]=true; out["entries"]=entries; out["inactive"]=inactive;
        out["native_bytes"]=bytes; out["counters"]=counts;
        out["memory_scope"]="owned_current_native_and_render_capacity_estimate_excludes_allocator_metadata_thread_stacks_and_host_values";
        return out;
    } catch (const std::exception& error) { error_=String(error.what()); return persistent_residency_detail::failure(error.what()); }
}

inline Dictionary CyberDemoBridge::resident_activate(const Ref<CyberNativeCellWorld>& adapter,
    const Dictionary& target_claim,const Dictionary& active_claim,const String& operation_id) {
    error_=String();
    try {
        if (adapter.is_null() || !persistent_area_detail::identifier(operation_id))
            throw std::invalid_argument("Resident activation requires an adapter and operation identity");
        if (adapter->pending_liquid_world_ || adapter->resident_last_operation_==operation_id)
            throw std::invalid_argument("Resident activation conflicts with a preparation or repeated operation");
        auto& target=resident_validate(*adapter.ptr(),target_claim);
        auto& source=resident_validate(*adapter.ptr(),active_claim);
        if (target.handle==source.handle || target.handle==adapter->active_resident_handle_ ||
            source.handle!=adapter->active_resident_handle_ || !target.payload)
            throw std::invalid_argument("Resident activation requires one inactive target and the active source");
        if (target.identity["session_id"]!=source.identity["session_id"] ||
            target.identity["runtime_sha256"]!=source.identity["runtime_sha256"])
            throw std::invalid_argument("Resident activation crosses session/runtime authority");
        auto staged=resident_stage_departure(*adapter.ptr());
        Dictionary next_source=resident_receipt(*adapter.ptr(),source);
        Dictionary next_target=resident_receipt(*adapter.ptr(),target);
        next_source["active"]=false;
        next_source["resident_generation"]=static_cast<std::int64_t>(source.generation+1);
        next_target["active"]=true;
        next_target["resident_generation"]=static_cast<std::int64_t>(target.generation+1);
        next_target["mutation_generation"]=static_cast<std::int64_t>(std::max(adapter->revision_,target.mutation)+1);
        Dictionary out; out["ok"]=true; out["operation_id"]=operation_id;
        out["source_receipt"]=next_source; out["target_receipt"]=next_target;
        out["native_deserializations"]=0; out["source_constructions"]=0; out["checkpoint_captures"]=0;
        String committed_operation=operation_id;
        // All validation and allocation precedes the unique-owner transfer.
        resident_take_active(*adapter.ptr(),std::move(staged));
        resident_install(*adapter.ptr(),target);
        std::swap(adapter->resident_last_operation_,committed_operation);
        ++adapter->resident_hot_activations_;
        return out;
    } catch (const std::exception& error) { error_=String(error.what()); return persistent_residency_detail::failure(error.what()); }
}

inline Dictionary CyberDemoBridge::resident_capture(const Ref<CyberNativeCellWorld>& adapter,const Dictionary& claim) {
    error_=String();
    try {
        if (adapter.is_null()) throw std::invalid_argument("Resident adapter is absent");
        auto& entry=resident_validate(*adapter.ptr(),claim);
        Dictionary capsule;
        if (entry.handle==adapter->active_resident_handle_) {
            validate_continuation_host(*adapter.ptr());
            capsule=continuation_capsule(*adapter->world_,adapter->applied_liquid_setup_,adapter->workbench_->response,
                adapter->simulation_window_enabled_);
        } else {
            auto& saved=*entry.payload;
            capsule=continuation_capsule(*saved.world,saved.setup,saved.workbench->response,saved.window);
        }
        ++adapter->resident_captures_;
        Dictionary out; out["ok"]=true; out["capsule"]=capsule;
        out["receipt"]=resident_receipt(*adapter.ptr(),entry); return out;
    } catch (const std::exception& error) { error_=String(error.what()); return persistent_residency_detail::failure(error.what()); }
}

inline Dictionary CyberDemoBridge::resident_advance(const Ref<CyberNativeCellWorld>& adapter,
    const Dictionary& claim,std::int64_t maximum_ticks,std::int64_t maximum_microseconds) {
    error_=String();
    try {
        if (adapter.is_null()) throw std::invalid_argument("Resident adapter is absent");
        auto& entry=resident_validate(*adapter.ptr(),claim);
        if (entry.handle==adapter->active_resident_handle_ || !entry.payload)
            throw std::invalid_argument("Private residency stepping cannot mutate the active gameplay World");
        if (maximum_ticks<1 || maximum_ticks>32 || maximum_microseconds<1 || maximum_microseconds>100000)
            throw std::invalid_argument("Resident native stepping exceeds the bounded slice");
        const auto result=cybersand::persistent_areas::advance(*entry.payload->world,
            static_cast<std::uint32_t>(maximum_ticks),static_cast<std::uint64_t>(maximum_microseconds));
        entry.mutation+=result.completed_ticks; adapter->resident_steps_+=result.completed_ticks;
        Dictionary out; out["ok"]=true; out["completed_ticks"]=static_cast<std::int64_t>(result.completed_ticks);
        out["completed_tick"]=static_cast<std::int64_t>(result.completed_tick);
        out["elapsed_us"]=static_cast<std::int64_t>(result.elapsed_microseconds);
        out["observed_workers"]=static_cast<std::int64_t>(result.observed_workers);
        out["visited_cells"]=static_cast<std::int64_t>(result.visited_cells);
        out["moved_cells"]=static_cast<std::int64_t>(result.moved_cells);
        out["receipt"]=resident_receipt(*adapter.ptr(),entry); return out;
    } catch (const std::exception& error) { error_=String(error.what()); return persistent_residency_detail::failure(error.what()); }
}

inline Dictionary CyberDemoBridge::resident_release(const Ref<CyberNativeCellWorld>& adapter,const Dictionary& claim) {
    error_=String();
    try {
        if (adapter.is_null()) throw std::invalid_argument("Resident adapter is absent");
        // A failed private World cannot be resumed/captured, but its current
        // fenced handle can be released after the host chooses durable recovery.
        auto& entry=resident_validate(*adapter.ptr(),claim,true);
        if (entry.handle==adapter->active_resident_handle_) throw std::invalid_argument("Active native area is pinned");
        const auto handle=entry.handle;
        for (auto it=adapter->resident_areas_.begin();it!=adapter->resident_areas_.end();++it)
            if ((*it)->handle==handle) { adapter->resident_areas_.erase(it); break; }
        ++adapter->resident_releases_;
        Dictionary out; out["ok"]=true; out["released"]=static_cast<std::int64_t>(handle); return out;
    } catch (const std::exception& error) { error_=String(error.what()); return persistent_residency_detail::failure(error.what()); }
}

inline Dictionary CyberDemoBridge::resident_clear_active(const Ref<CyberNativeCellWorld>& adapter,const Dictionary& claim) {
    error_=String();
    try {
        if (adapter.is_null()) throw std::invalid_argument("Resident adapter is absent");
        auto& entry=resident_validate(*adapter.ptr(),claim);
        if (entry.handle!=adapter->active_resident_handle_ || entry.payload)
            throw std::invalid_argument("Only an active binding may be cleared without releasing a World");
        const auto handle=entry.handle;
        for (auto it=adapter->resident_areas_.begin();it!=adapter->resident_areas_.end();++it)
            if ((*it)->handle==handle) { adapter->resident_areas_.erase(it); break; }
        adapter->active_resident_handle_=0;
        Dictionary out; out["ok"]=true; out["cleared"]=static_cast<std::int64_t>(handle); return out;
    } catch (const std::exception& error) { error_=String(error.what()); return persistent_residency_detail::failure(error.what()); }
}

inline Dictionary CyberDemoBridge::resident_import(const Ref<CyberNativeCellWorld>& adapter,
    const Ref<CyberNativeCellWorld>& candidate,const Dictionary& claim) {
    error_=String();
    try {
        if (adapter.is_null() || candidate.is_null() || adapter==candidate ||
            adapter->active_resident_handle_==0 || adapter->pending_liquid_world_ ||
            candidate->pending_liquid_world_ || candidate->resident_areas_.size()!=1)
            throw std::invalid_argument("Resident import requires a private completed candidate and an admitted active owner");
        auto& source=resident_validate(*candidate.ptr(),claim);
        auto& active=resident_find(*adapter.ptr(),adapter->active_resident_handle_);
        (void)resident_receipt(*adapter.ptr(),active);
        if (source.handle!=candidate->active_resident_handle_ || source.payload ||
            active.identity["session_id"]!=source.identity["session_id"] ||
            active.identity["runtime_sha256"]!=source.identity["runtime_sha256"])
            throw std::invalid_argument("Resident import has incompatible native ownership/session/runtime");
        for (const auto& existing:adapter->resident_areas_)
            if (existing->identity["area_id"]==source.identity["area_id"])
                throw std::invalid_argument("Resident import cannot supersede an existing area incarnation");
        if (adapter->resident_areas_.size()>=64 || adapter->next_resident_handle_>=static_cast<std::uint64_t>(INT64_MAX))
            throw std::length_error("Resident import exceeds native handle capacity");
        auto staged=resident_stage_departure(*candidate.ptr());
        auto entry=std::make_unique<CyberNativeCellWorld::ResidentArea>();
        entry->identity=source.identity.duplicate(true); entry->physics_profile=source.physics_profile;
        entry->handle=adapter->next_resident_handle_+1; entry->mutation=source.mutation;
        Dictionary imported=resident_receipt(*candidate.ptr(),source);
        imported["handle"]=static_cast<std::int64_t>(entry->handle);
        imported["resident_generation"]=static_cast<std::int64_t>(entry->generation);
        imported["active"]=false;
        Dictionary out; out["ok"]=true; out["receipt"]=imported; out["candidate_consumed"]=true;
        out["native_deserializations_at_import"]=0;
        adapter->resident_areas_.reserve(adapter->resident_areas_.size()+1);
        // No shared live owner crosses this point. Only the joined candidate's
        // unique bundle is moved. Neither World is copied or deserialized.
        resident_take_active(*candidate.ptr(),std::move(staged));
        entry->payload=std::move(source.payload);
        adapter->resident_areas_.push_back(std::move(entry));
        ++adapter->next_resident_handle_; ++adapter->resident_imports_;
        adapter->resident_source_constructions_+=candidate->resident_source_constructions_;
        adapter->resident_native_restorations_+=candidate->resident_native_restorations_;
        candidate->resident_areas_.clear();
        return out;
    } catch (const std::exception& error) { error_=String(error.what()); return persistent_residency_detail::failure(error.what()); }
}
} // namespace godot
