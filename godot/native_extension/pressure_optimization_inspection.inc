// Read-only copied values for the exclusive adapter owner. These observations
// never grant rest authority or expose mutable World/cache storage.
namespace {
String pressure_optimization_unsigned(std::uint64_t value) {
    return String(std::to_string(value).c_str());
}
}

String CyberNativeCellWorld::get_liquid_comparison_hash(std::int64_t projection_id) const {
    if (world_ == nullptr || (projection_id != 1 && projection_id != 2)) return {};
    const auto projection = static_cast<cybersand::LiquidStateProjection>(projection_id);
    char text[17];
    std::snprintf(text, sizeof(text), "%016llx",
                  static_cast<unsigned long long>(world_->liquid_comparison_hash(projection)));
    return String(text);
}

Dictionary CyberNativeCellWorld::inspect_pressure_optimization() const {
    Dictionary out;
    out["schema_version"] = 1;
    out["available"] = world_ != nullptr && world_->pressure_flow_enabled();
    out["unsigned_encoding"] = "decimal_string";
    out["execution_version"] = static_cast<std::int64_t>(cybersand::kPressureOptimizationExecutionVersion);
    out["certificate_warmup_visits"] = static_cast<std::int64_t>(cybersand::kPressureCertificateWarmupVisits);
    out["certificate_backoff_visits"] = static_cast<std::int64_t>(cybersand::kPressureCertificateBackoffVisits);
    if (world_ == nullptr) return out;
    const auto snapshot = world_->pressure_optimization_snapshot();
    out["cached"] = snapshot.cached;
    out["dormant"] = snapshot.dormant;
    out["gas_pending"] = snapshot.gas_pending;
    out["status_code"] = static_cast<std::int64_t>(snapshot.status);
    constexpr std::array<const char*,6> statuses{
        "disabled", "cold", "pending", "ready", "reference_capacity_fallback", "reference_budget_fallback"};
    const auto status = static_cast<std::size_t>(snapshot.status);
    out["status"] = status < statuses.size() ? statuses[status] : "unknown";
    const auto identity = world_->pressure_optimization_identity();
    out["extension_identity_version"] = identity ? 1 : 0;
    out["extension_identity_sha256"] = identity ? String(cybersand::Sha256::hex(*identity).c_str()) : String();
    Dictionary admission;
    admission["model"] = "certificate_work_credits_v1";
    admission["enabled"] = snapshot.certificate_layer_enabled;
    admission["contents_cold"] = snapshot.certificate_contents_cold;
    admission["window_ticks"] = static_cast<std::int64_t>(snapshot.certificate_window_ticks);
    admission["suspend_remaining"] = static_cast<std::int64_t>(snapshot.certificate_suspend_remaining);
    admission["trial_ticks"] = static_cast<std::int64_t>(cybersand::kPressureCertificateTrialTicks);
    admission["suspension_ticks"] = static_cast<std::int64_t>(cybersand::kPressureCertificateSuspensionTicks);
    admission["invalidation_charge"] = pressure_optimization_unsigned(cybersand::kPressureCertificateInvalidationCharge);
    admission["proof_charge"] = pressure_optimization_unsigned(cybersand::kPressureCertificateProofCharge);
    admission["reuse_charge"] = pressure_optimization_unsigned(cybersand::kPressureCertificateReuseCharge);
    admission["saved_call_credit"] = pressure_optimization_unsigned(cybersand::kPressureCertificateSavedCallCredit);
    admission["window_charge"] = pressure_optimization_unsigned(snapshot.certificate_window_charge);
    admission["window_credit"] = pressure_optimization_unsigned(snapshot.certificate_window_credit);
    admission["last_window_charge"] = pressure_optimization_unsigned(snapshot.certificate_last_window_charge);
    admission["last_window_credit"] = pressure_optimization_unsigned(snapshot.certificate_last_window_credit);
    out["certificate_admission"] = admission;
    const auto& requested = world_->config().pressure_optimization;
    Dictionary config;
    config["index_chunk_capacity"] = pressure_optimization_unsigned(requested.index_chunk_capacity);
    config["head_repair_cell_budget"] = pressure_optimization_unsigned(requested.head_repair_cell_budget);
    config["gas_member_capacity"] = pressure_optimization_unsigned(requested.gas_member_capacity);
    config["gas_invalidation_pair_budget"] = pressure_optimization_unsigned(requested.gas_invalidation_pair_budget);
    out["requested_config"] = config;
    Dictionary observed;
#define CYBERSAND_PRESSURE_OBSERVE(field) observed[#field] = pressure_optimization_unsigned(snapshot.field)
    CYBERSAND_PRESSURE_OBSERVE(index_incarnation);
    CYBERSAND_PRESSURE_OBSERVE(indexed_chunks);
    CYBERSAND_PRESSURE_OBSERVE(column_groups);
    CYBERSAND_PRESSURE_OBSERVE(row_groups);
    CYBERSAND_PRESSURE_OBSERVE(dirty_column_groups);
    CYBERSAND_PRESSURE_OBSERVE(dirty_row_groups);
    CYBERSAND_PRESSURE_OBSERVE(index_chunk_capacity);
    CYBERSAND_PRESSURE_OBSERVE(head_repair_cell_budget);
    CYBERSAND_PRESSURE_OBSERVE(derived_capacity_bytes);
    CYBERSAND_PRESSURE_OBSERVE(worker_counter_capacity_bytes);
    CYBERSAND_PRESSURE_OBSERVE(common_counter_bytes);
    CYBERSAND_PRESSURE_OBSERVE(certificate_buffer_capacity_bytes);
    CYBERSAND_PRESSURE_OBSERVE(gas_components);
    CYBERSAND_PRESSURE_OBSERVE(gas_valid_components);
    CYBERSAND_PRESSURE_OBSERVE(gas_members);
    CYBERSAND_PRESSURE_OBSERVE(gas_member_capacity);
    CYBERSAND_PRESSURE_OBSERVE(gas_dirty_chunks);
    CYBERSAND_PRESSURE_OBSERVE(gas_capacity_bytes);
    CYBERSAND_PRESSURE_OBSERVE(gas_invalidation_pair_budget);
#undef CYBERSAND_PRESSURE_OBSERVE
    out["observed"] = observed;
    const auto& c = snapshot.counters;
    Dictionary counters;
#define CYBERSAND_PRESSURE_COUNT(field) counters[#field] = pressure_optimization_unsigned(c.field)
    CYBERSAND_PRESSURE_COUNT(water_material_calls);
    CYBERSAND_PRESSURE_COUNT(water_motion_calls);
    CYBERSAND_PRESSURE_COUNT(other_liquid_calls);
    CYBERSAND_PRESSURE_COUNT(certificate_attempts);
    CYBERSAND_PRESSURE_COUNT(certificate_reuses);
    CYBERSAND_PRESSURE_COUNT(certificate_saved_calls);
    CYBERSAND_PRESSURE_COUNT(certificate_declines);
    CYBERSAND_PRESSURE_COUNT(certificate_work_charged);
    CYBERSAND_PRESSURE_COUNT(certificate_work_credited);
    CYBERSAND_PRESSURE_COUNT(certificate_work_windows);
    CYBERSAND_PRESSURE_COUNT(certificate_work_suspensions);
    CYBERSAND_PRESSURE_COUNT(certificate_unavailable_ticks);
    CYBERSAND_PRESSURE_COUNT(certificate_suspended_ticks);
    CYBERSAND_PRESSURE_COUNT(certificate_cold_resets);
    CYBERSAND_PRESSURE_COUNT(certificate_cold_reset_cells);
    CYBERSAND_PRESSURE_COUNT(certificate_layer_activations);
    CYBERSAND_PRESSURE_COUNT(index_rebuilds);
    CYBERSAND_PRESSURE_COUNT(invalidation_rects);
    CYBERSAND_PRESSURE_COUNT(columns_recomputed);
    CYBERSAND_PRESSURE_COUNT(rows_recomputed);
    CYBERSAND_PRESSURE_COUNT(base_cells_written);
    CYBERSAND_PRESSURE_COUNT(final_cells_written);
    CYBERSAND_PRESSURE_COUNT(gas_reuses);
    CYBERSAND_PRESSURE_COUNT(gas_reference_passes);
    CYBERSAND_PRESSURE_COUNT(reference_fallbacks);
    CYBERSAND_PRESSURE_COUNT(fallback_resident_cells);
    CYBERSAND_PRESSURE_COUNT(certificate_invalidation_cells);
    CYBERSAND_PRESSURE_COUNT(preparation_nanoseconds);
    CYBERSAND_PRESSURE_COUNT(gas_nanoseconds);
    CYBERSAND_PRESSURE_COUNT(head_nanoseconds);
    CYBERSAND_PRESSURE_COUNT(gas_seed_cells);
    CYBERSAND_PRESSURE_COUNT(gas_seed_probes);
    CYBERSAND_PRESSURE_COUNT(gas_bfs_cells);
    CYBERSAND_PRESSURE_COUNT(gas_bfs_probes);
    CYBERSAND_PRESSURE_COUNT(gas_bfs_nodes);
    CYBERSAND_PRESSURE_COUNT(gas_member_validations);
    CYBERSAND_PRESSURE_COUNT(gas_member_stamps);
    CYBERSAND_PRESSURE_COUNT(gas_component_reuses);
    CYBERSAND_PRESSURE_COUNT(gas_index_chunks);
    CYBERSAND_PRESSURE_COUNT(gas_cache_build_cells);
    CYBERSAND_PRESSURE_COUNT(gas_cache_builds);
    CYBERSAND_PRESSURE_COUNT(gas_component_proof_checks);
    CYBERSAND_PRESSURE_COUNT(gas_member_initializations);
    CYBERSAND_PRESSURE_COUNT(gas_member_builds);
    CYBERSAND_PRESSURE_COUNT(gas_invalidation_pairs);
    CYBERSAND_PRESSURE_COUNT(gas_component_invalidations);
    CYBERSAND_PRESSURE_COUNT(gas_dirty_chunks_queued);
    CYBERSAND_PRESSURE_COUNT(gas_capacity_fallbacks);
    CYBERSAND_PRESSURE_COUNT(gas_budget_fallbacks);
    CYBERSAND_PRESSURE_COUNT(gas_restart_fallbacks);
    CYBERSAND_PRESSURE_COUNT(gas_relabel_cells);
    CYBERSAND_PRESSURE_COUNT(gas_identity_nodes);
    CYBERSAND_PRESSURE_COUNT(gas_stamp_clear_cells);
#undef CYBERSAND_PRESSURE_COUNT
    out["counters"] = counters;
    return out;
}
