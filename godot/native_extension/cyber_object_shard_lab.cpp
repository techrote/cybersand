#include "cyber_object_shard_lab.hpp"
#include "cybersand/object_shard_contact.hpp"
#include "cybersand/material_appearance.hpp"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <godot_cpp/variant/rect2i.hpp>
#include <charconv>
#include <cmath>
#include <limits>
#include <stdexcept>
#include <string>

namespace godot {
namespace os = cybersand::object_shard;
namespace {

String number(std::uint64_t value) { return String::utf8(std::to_string(value).c_str()); }

bool unsigned_value(const Variant& value, std::uint64_t& result) {
    if (value.get_type() == Variant::INT) {
        const std::int64_t integer = value;
        if (integer < 0) return false;
        result = static_cast<std::uint64_t>(integer);
        return true;
    }
    if (value.get_type() != Variant::STRING) return false;
    const CharString text = static_cast<String>(value).utf8();
    const char* first = text.get_data();
    const char* end = first + text.length();
    const auto parsed = std::from_chars(first, end, result);
    return parsed.ec == std::errc{} && parsed.ptr == end && first != end;
}

bool field(const Dictionary& row, const char* key, std::uint64_t& result) {
    return row.has(key) && unsigned_value(row[key], result);
}

bool identity(const Dictionary& row, os::Handle& handle) {
    return field(row, "session", handle.session) && field(row, "id", handle.id) &&
        field(row, "generation", handle.generation);
}

Dictionary payload(os::Payload cell) {
    Dictionary row;
    row["material"] = static_cast<std::int64_t>(cell.material);
    row["state_a"] = cell.state_a;
    row["state_b"] = cell.state_b;
    row["temperature"] = cell.temperature;
    row["material_name"] = String::utf8(cybersand::material_definition(cell.material).name.data());
    return row;
}

void rgba(PackedByteArray& output, std::size_t index, os::Payload cell, bool transparent_empty) {
    const auto& color = cybersand::material_definition(cell.material).rgba;
    auto* bytes = output.ptrw() + index * 4;
    for (std::size_t component = 0; component < 4; ++component) bytes[component] = color[component];
    if (transparent_empty && cell.material == cybersand::Material::Empty) bytes[3] = 0;
    // This only visualizes the actual native burn countdown; no decorative
    // particle or unowned material is created by the presentation adapter.
    if (cell.material == cybersand::Material::Wood && cell.state_b != 0) {
        bytes[0] = 192; bytes[1] = 82; bytes[2] = 35;
    }
}

Dictionary metrics_value(const os::Metrics& value) {
    Dictionary result;
#define COPY_METRIC(name) result[#name] = static_cast<std::int64_t>(value.name)
    COPY_METRIC(steps); COPY_METRIC(paused_calls); COPY_METRIC(discovered_cells);
    COPY_METRIC(promotions); COPY_METRIC(refusals); COPY_METRIC(chemistry_cells);
    COPY_METRIC(products_created); COPY_METRIC(output_blocked); COPY_METRIC(sand_ingested);
    COPY_METRIC(exposure_overflows); COPY_METRIC(stale_messages); COPY_METRIC(mask_cells);
    COPY_METRIC(ingress_blocked);
    COPY_METRIC(composed_overlap_cells); COPY_METRIC(composed_reuses); COPY_METRIC(fragments); COPY_METRIC(fragment_refusals); COPY_METRIC(reabsorptions);
    COPY_METRIC(relocation_probes); COPY_METRIC(relocation_probe_limit_hits);
    COPY_METRIC(relocated_cells); COPY_METRIC(relocated_water_cells); COPY_METRIC(relocated_sand_cells);
    COPY_METRIC(sweep_samples); COPY_METRIC(world_ns); COPY_METRIC(chemistry_ns);
    COPY_METRIC(contact_ns); COPY_METRIC(occupancy_ns); COPY_METRIC(geometry_ns);
    COPY_METRIC(discovery_ns); COPY_METRIC(terrain_ns); COPY_METRIC(exchange_ns); COPY_METRIC(relocation_ns);
    COPY_METRIC(snapshot_ns); COPY_METRIC(maximum_pause_ns); COPY_METRIC(maximum_geometry_age);
    COPY_METRIC(maximum_geometry_wait_ns);
    COPY_METRIC(maximum_product_age); COPY_METRIC(coordinator_bytes); COPY_METRIC(world_bytes);
    COPY_METRIC(live_bytes); COPY_METRIC(retained_bytes); COPY_METRIC(peak_bytes);
#undef COPY_METRIC
    result["occupancy_timing_scope"] = "Inclusive of contact capture and conservative overlap relocation; do not sum nested counters";
    result["memory_scope"] = "Accounted native storage lower bound; excludes World non-cell metadata, allocator overhead, Godot and Rapier";
    return result;
}

Dictionary terrain_identity(const os::TerrainReceipt& value) {
    Dictionary result;
    result["id"] = value.id;
    result["revision"] = static_cast<std::int64_t>(value.revision);
    result["digest"] = number(value.digest);
    return result;
}

Dictionary admission_value(const os::AdmissionStatus& value) {
    Dictionary result;
    result["census_complete"] = value.census_complete;
    result["reason"] = os::admission_reason_name(value.reason);
#define ADMISSION_COUNT(name) result[#name] = static_cast<std::int64_t>(value.name)
    ADMISSION_COUNT(pending_mutations); ADMISSION_COUNT(pending_seeds); ADMISSION_COUNT(frontier_cells);
    ADMISSION_COUNT(components); ADMISSION_COUNT(eligible); ADMISSION_COUNT(deferred);
    ADMISSION_COUNT(anchored); ADMISSION_COUNT(unknown_boundary); ADMISSION_COUNT(refused_geometry);
    ADMISSION_COUNT(slots_used); ADMISSION_COUNT(slot_limit); ADMISSION_COUNT(active_bodies);
    ADMISSION_COUNT(largest_cells); ADMISSION_COUNT(work_last); ADMISSION_COUNT(work_peak);
    ADMISSION_COUNT(completed_components); ADMISSION_COUNT(invalidations);
    ADMISSION_COUNT(interrupted_searches); ADMISSION_COUNT(cached_capacity_calls);
#undef ADMISSION_COUNT
    Array candidates;
    for (std::size_t i = 0; i < value.candidate_count && i < value.candidates.size(); ++i) {
        const auto& candidate = value.candidates[i];
        Dictionary row;
        row["x"] = candidate.x; row["y"] = candidate.y;
        row["cells"] = candidate.cells; row["bbox_area"] = candidate.bbox_area;
        row["age"] = static_cast<std::int64_t>(candidate.age);
        row["reason"] = os::admission_reason_name(candidate.reason);
        candidates.push_back(row);
    }
    result["candidates"] = candidates;
    result["age_scope"] = "completed admissions waited, independent of frame rate";
    return result;
}

} // namespace

CyberObjectShardLab::CyberObjectShardLab() : owner_(std::this_thread::get_id()) {}
CyberObjectShardLab::~CyberObjectShardLab() = default;

bool CyberObjectShardLab::owned() const noexcept {
    return owner_ == std::this_thread::get_id() && coordinator_ && !failed_;
}

Dictionary CyberObjectShardLab::refusal(const char* reason) const {
    Dictionary value;
    value["ok"] = false;
    value["outcome"] = reason;
    value["quarantined"] = failed_;
    value["detail"] = failed_ ? failure_ : String(reason);
    return value;
}

Dictionary CyberObjectShardLab::fail(const char* reason) {
    failed_ = true;
    failure_ = reason;
    return refusal("Quarantined");
}

Dictionary CyberObjectShardLab::result(const os::Result& value) const {
    Dictionary row;
    row["ok"] = value.outcome == os::Outcome::Accepted;
    row["outcome"] = os::outcome_name(value.outcome);
    row["detail"] = value.detail;
    row["session"] = static_cast<std::int64_t>(value.shard.session);
    row["id"] = static_cast<std::int64_t>(value.shard.id);
    row["generation"] = static_cast<std::int64_t>(value.shard.generation);
    row["transaction"] = static_cast<std::int64_t>(value.transaction);
    row["phase"] = os::phase_name(value.phase);
    return row;
}

Dictionary CyberObjectShardLab::configure(const Dictionary& configuration) {
    if (owner_ != std::this_thread::get_id()) return refusal("ExclusiveOwnerRequired");
    if (coordinator_) return refusal("AlreadyConfiguredUseReset");
    try {
        os::Config config;
        const Variant scenario_value = configuration.get("scenario", 1);
        const Variant seed_value = configuration.get("seed", 12);
        if (scenario_value.get_type() != Variant::INT || seed_value.get_type() != Variant::INT)
            return refusal("InvalidConfiguration");
        const auto scenario = static_cast<std::int64_t>(scenario_value);
        const auto seed = static_cast<std::int64_t>(seed_value);
        const Variant transfer_limit = configuration.get("transfer_budget", 64);
        if (transfer_limit.get_type() != Variant::INT) return refusal("InvalidConfiguration");
        const auto transfer_budget = static_cast<std::int64_t>(transfer_limit);
        const Variant width_value = configuration.get("width", 192);
        const Variant height_value = configuration.get("height", 128);
        if (width_value.get_type() != Variant::INT || height_value.get_type() != Variant::INT)
            return refusal("InvalidConfiguration");
        const auto width = static_cast<std::int64_t>(width_value);
        const auto height = static_cast<std::int64_t>(height_value);
        if (width < 64 || width > 512 || height < 64 || height > 512 || width * height > 262144)
            return refusal("InvalidConfiguration");
        if (scenario < 0 || scenario > 6 || seed < 0) return refusal("InvalidConfiguration");
        if (transfer_budget < 0 || transfer_budget > 64) return refusal("InvalidConfiguration");
        config.scenario = static_cast<std::uint32_t>(scenario);
        config.seed = static_cast<std::uint64_t>(seed);
        config.transfer_budget = static_cast<std::uint32_t>(transfer_budget);
        config.world_bounds.width = static_cast<std::uint16_t>(width);
        config.world_bounds.height = static_cast<std::uint16_t>(height);
        coordinator_ = std::make_unique<os::Coordinator>(config);
        return snapshot();
    } catch (const std::exception& error) { return fail(error.what()); }
}

Dictionary CyberObjectShardLab::attach_owner_world(cybersand::World& world, os::Config config) {
    if (owner_ != std::this_thread::get_id()) return refusal("ExclusiveOwnerRequired");
    if (coordinator_) return refusal("AlreadyConfiguredUseReset");
    try {
        coordinator_ = std::make_unique<os::Coordinator>(world, config);
        const auto proof = coordinator_->m4_owner_readback();
        Dictionary receipt;
        receipt["ok"] = coordinator_->same_world_attached(world) && proof.world_available;
        receipt["outcome"] = receipt["ok"] ? "AttachedSameWorld" : "AttachmentRefused";
        receipt["session"] = static_cast<std::int64_t>(proof.session);
        receipt["world_incarnation"] = static_cast<std::int64_t>(proof.world_incarnation);
        receipt["tick"] = static_cast<std::int64_t>(proof.tick);
        return receipt;
    } catch (const std::exception& error) { return fail(error.what()); }
}

Dictionary CyberObjectShardLab::after_owner_tick() {
    if (!owned() || !coordinator_->same_world_attached(coordinator_->world()))
        return refusal("SameWorldOwnerRequired");
    return result(coordinator_->after_owner_world_tick());
}

Dictionary CyberObjectShardLab::reset(std::int64_t scenario, std::int64_t seed) {
    if (owner_ != std::this_thread::get_id() || !coordinator_) return refusal("ExclusiveOwnerRequired");
    if (scenario < 0 || scenario > 6 || seed < 0) return refusal("InvalidConfiguration");
    try {
        const auto outcome = coordinator_->reset(static_cast<std::uint32_t>(scenario), static_cast<std::uint64_t>(seed));
        if (outcome.outcome == os::Outcome::Accepted) { failed_ = false; failure_ = String(); }
        return result(outcome);
    } catch (const std::exception& error) { return fail(error.what()); }
}

Dictionary CyberObjectShardLab::step(const Array& poses) {
    return advance_native(poses, true);
}

Dictionary CyberObjectShardLab::accept_motion(const Array& poses) {
    return advance_native(poses, false);
}

Dictionary CyberObjectShardLab::advance_native(const Array& poses, bool semantic_step) {
    if (!owned()) return refusal("Fenced");
    if (poses.size() > static_cast<std::int64_t>(coordinator_->config().limits.max_shards) ||
        poses.size() > static_cast<std::int64_t>(os::OwnerReadback::kBodySlots)) return refusal("PoseCapacity");
    std::array<os::PoseSample, os::OwnerReadback::kBodySlots> copied{};
    for (std::int64_t index = 0; index < poses.size(); ++index) {
        if (poses[index].get_type() != Variant::DICTIONARY) return refusal("InvalidPose");
        const Dictionary row = poses[index];
        auto& pose = copied[static_cast<std::size_t>(index)];
        if (!identity(row, pose.shard) || !field(row, "body_generation", pose.body_generation) ||
            !field(row, "geometry_revision", pose.geometry_revision) || !field(row, "pose_serial", pose.pose_serial))
            return refusal("InvalidPoseIdentity");
        for (const auto* key : {"x", "y", "rotation", "vx", "vy", "angular_velocity"}) {
            if (!row.has(key)) return refusal("InvalidPose");
            const auto type = row[key].get_type();
            if (type != Variant::FLOAT && type != Variant::INT) return refusal("InvalidPose");
        }
        if (!row.has("sleeping") || row["sleeping"].get_type() != Variant::BOOL)
            return refusal("InvalidPose");
        pose.x = row.get("x", 0.0); pose.y = row.get("y", 0.0); pose.rotation = row.get("rotation", 0.0);
        pose.vx = row.get("vx", 0.0); pose.vy = row.get("vy", 0.0);
        pose.angular_velocity = row.get("angular_velocity", 0.0); pose.sleeping = row.get("sleeping", false);
        if (!std::isfinite(pose.x) || !std::isfinite(pose.y) || !std::isfinite(pose.rotation) ||
            !std::isfinite(pose.vx) || !std::isfinite(pose.vy) || !std::isfinite(pose.angular_velocity)) return refusal("InvalidPose");
    }
    try {
        const auto samples = std::span(copied.data(), static_cast<std::size_t>(poses.size()));
        const auto applied = semantic_step ? coordinator_->step(samples) : coordinator_->accept_motion(samples);
        Dictionary receipt = result(applied);
        if (!semantic_step) {
            receipt["applied"] = applied.outcome == os::Outcome::Accepted;
            receipt["semantic_tick"] = static_cast<std::int64_t>(coordinator_->world().completed_tick_index());
            Array identities;
            if (applied.outcome == os::Outcome::Accepted) for (const auto& pose : samples) {
                Dictionary identity;
                identity["session"] = static_cast<std::int64_t>(pose.shard.session);
                identity["id"] = static_cast<std::int64_t>(pose.shard.id);
                identity["generation"] = static_cast<std::int64_t>(pose.shard.generation);
                identity["body_generation"] = static_cast<std::int64_t>(pose.body_generation);
                identity["geometry_revision"] = static_cast<std::int64_t>(pose.geometry_revision);
                identity["pose_serial"] = static_cast<std::int64_t>(pose.pose_serial);
                identities.push_back(identity);
            }
            receipt["accepted_pose_serials"] = identities;
        }
        return receipt;
    }
    catch (const std::exception& error) { return fail(error.what()); }
}

Dictionary CyberObjectShardLab::edit_cell(Vector2i position, std::int64_t material,
    std::int64_t state_a, std::int64_t state_b, std::int64_t temperature) {
    if (!owned()) return refusal("Fenced");
    if (material < 0 || material >= static_cast<std::int64_t>(cybersand::kMaterialDefinitions.size()) ||
        state_a < 0 || state_a > 65535 || state_b < 0 || state_b > 255 ||
        temperature < -32768 || temperature > 32767) return refusal("InvalidPayload");
    const auto kind = static_cast<cybersand::Material>(material);
    if (!cybersand::material_definition(kind).valid) return refusal("UnsupportedMaterial");
    try { return result(coordinator_->edit(position.x, position.y, {kind,
        static_cast<std::uint16_t>(state_a), static_cast<std::uint8_t>(state_b), static_cast<std::int16_t>(temperature)})); }
    catch (const std::exception& error) { return fail(error.what()); }
}

Dictionary CyberObjectShardLab::ignite(Vector2i position) {
    if (!owned()) return refusal("Fenced");
    try { return result(coordinator_->ignite(position.x, position.y)); }
    catch (const std::exception& error) { return fail(error.what()); }
}

Dictionary CyberObjectShardLab::erase_shard(const Dictionary& request) {
    return act_on_shard(request,os::ShardAction::Erase);
}

Dictionary CyberObjectShardLab::act_on_shard(const Dictionary& request,os::ShardAction action) {
    if (!owned()) return refusal("Fenced");
    os::ShardEditRequest copied;
    std::uint64_t cell{}, incarnation{}, capability{};
    if (!identity(request, copied.shard) || !field(request, "sequence", copied.sequence) ||
        !field(request, "body_generation", copied.body_generation) ||
        !field(request, "geometry_revision", copied.geometry_revision) ||
        !field(request, "pose_serial", copied.pose_serial) ||
        !field(request, "material_revision", copied.material_revision) ||
        !field(request, "cell", cell) || !field(request, "incarnation", incarnation) ||
        !field(request, "capability_version", capability) ||
        cell > std::numeric_limits<std::uint32_t>::max() ||
        incarnation > std::numeric_limits<std::uint32_t>::max() ||
        capability > std::numeric_limits<std::uint32_t>::max()) return refusal("InvalidShardEditIdentity");
    const Variant expected_value = request.get("expected", Variant());
    if (expected_value.get_type() != Variant::DICTIONARY) return refusal("InvalidPayload");
    const Dictionary expected = expected_value;
    for (const auto* key : {"material", "state_a", "state_b", "temperature"})
        if (!expected.has(key) || expected[key].get_type() != Variant::INT) return refusal("InvalidPayload");
    const auto material = static_cast<std::int64_t>(expected["material"]);
    const auto state_a = static_cast<std::int64_t>(expected["state_a"]);
    const auto state_b = static_cast<std::int64_t>(expected["state_b"]);
    const auto temperature = static_cast<std::int64_t>(expected["temperature"]);
    if (material < 0 || material >= static_cast<std::int64_t>(cybersand::kMaterialDefinitions.size()) ||
        state_a < 0 || state_a > 65535 || state_b < 0 || state_b > 255 ||
        temperature < -32768 || temperature > 32767 ||
        !cybersand::material_definition(static_cast<cybersand::Material>(material)).valid)
        return refusal("InvalidPayload");
    copied.cell = static_cast<std::uint32_t>(cell);
    copied.incarnation = static_cast<std::uint32_t>(incarnation);
    copied.capability_version = static_cast<std::uint32_t>(capability);
    copied.expected = {static_cast<cybersand::Material>(material), static_cast<std::uint16_t>(state_a),
        static_cast<std::uint8_t>(state_b), static_cast<std::int16_t>(temperature)};
    try {
        auto receipt=result(coordinator_->act_on_shard(copied,action));
        const auto* shard=coordinator_->registry().find(copied.shard);
        if (shard) {
            receipt["material_revision"]=static_cast<std::int64_t>(shard->material_revision());
            receipt["geometry_revision"]=static_cast<std::int64_t>(shard->geometry().revision);
            receipt["applied_physics_revision"]=static_cast<std::int64_t>(shard->applied_physics_revision());
            receipt["incarnation"]=copied.cell<shard->area() ? shard->schedule(copied.cell).incarnation : 0;
            const auto readback=coordinator_->m4_owner_readback();
            for (std::size_t i=0;i<readback.copied_count;++i) if (readback.bodies[i].shard==copied.shard) {
                receipt["pose_serial"]=static_cast<std::int64_t>(readback.bodies[i].pose.pose_serial);
                receipt["body_generation"]=static_cast<std::int64_t>(readback.bodies[i].body_generation);
                break;
            }
        }
        receipt["owner"]=static_cast<std::int64_t>(copied.shard.id);
        receipt["cell"]=copied.cell;
        return receipt;
    }
    catch (const std::exception& error) { return fail(error.what()); }
}

Dictionary CyberObjectShardLab::workbench_action(const Dictionary& request) {
    if (!owned()) return refusal("Fenced");
    const auto proof=coordinator_->m4_owner_readback();
    std::uint64_t session{},incarnation{};
    if (!field(request,"shard_session",session) || session!=proof.session ||
        !field(request,"world_incarnation",incarnation) || incarnation!=proof.world_incarnation)
        return refusal("Retired");
    const Variant value=request.get("target",Variant());
    if (value.get_type()!=Variant::DICTIONARY) return refusal("InvalidPayload");
    const Dictionary target=value;
    const String operation=request.get("operation","");
    os::ShardAction action;
    if (operation=="erase") action=os::ShardAction::Erase;
    else if (operation=="ignite") action=os::ShardAction::Ignite;
    else if (operation=="inspect") action=os::ShardAction::Inspect;
    else if (operation=="reabsorb") action=os::ShardAction::Reabsorb;
    else return refusal("UnsupportedAction");
    Dictionary exact=target.duplicate(true);
    exact["session"]=static_cast<std::int64_t>(session);
    exact["id"]=target.get("owner",0);
    exact["sequence"]=static_cast<std::int64_t>(coordinator_->next_transaction());
    exact["capability_version"]=os::kCapabilityVersion;
    Dictionary receipt=act_on_shard(exact,action);
    receipt["accepted"]=receipt.get("ok",false);
    receipt["same_world"]=true;
    receipt["source_target"]=target.duplicate(true);
    receipt["transaction_id"]=receipt.get("transaction",0);
    if (action==os::ShardAction::Inspect) receipt["receipt_id"]=receipt.get("transaction",0);
    for (const auto* key:{"session","world_generation","transport_generation","owner_epoch",
        "shard_session","world_incarnation","action_id","port_generation","operation","position"})
        receipt[key]=request.get(key,Variant());
    if (action==os::ShardAction::Reabsorb) {
        receipt["staged"]=receipt.get("ok",false);receipt["applied"]=false;
        if (static_cast<bool>(receipt.get("ok",false))) reabsorption_receipt_=receipt.duplicate(true);
    }
    return receipt;
}

Dictionary CyberObjectShardLab::ignite_shard(std::int64_t id, std::int64_t generation, std::int64_t cell) {
    if (!owned() || id <= 0 || generation <= 0 || cell < 0 || cell > 65535) return refusal("InvalidShardCell");
    try { return result(coordinator_->ignite_shard({coordinator_->registry().session(),
        static_cast<std::uint64_t>(id), static_cast<std::uint64_t>(generation)}, static_cast<std::uint32_t>(cell))); }
    catch (const std::exception& error) { return fail(error.what()); }
}

Dictionary CyberObjectShardLab::prepare_next() {
    if (!owned()) return refusal("Fenced");
    try { return result(coordinator_->prepare_next()); }
    catch (const std::exception& error) { return fail(error.what()); }
}

Dictionary CyberObjectShardLab::acknowledge(const Dictionary& receipt) {
    if (!owned()) return refusal("Fenced");
    os::Acknowledgement ack;
    const String phase = receipt.get("kind", "");
    if (phase == "PhysicsReserved") ack.kind = os::AckKind::PhysicsReserved;
    else if (phase == "TerrainInstalled") ack.kind = os::AckKind::TerrainInstalled;
    else if (phase == "BodyActivated") ack.kind = os::AckKind::BodyActivated;
    else if (phase == "GeometryInstalled") ack.kind = os::AckKind::GeometryInstalled;
    else if (phase == "BodyRetired") ack.kind = os::AckKind::BodyRetired;
    else if (phase == "ReabsorptionFrozen") ack.kind = os::AckKind::ReabsorptionFrozen;
    else if (phase == "ReabsorptionComplete") ack.kind = os::AckKind::ReabsorptionComplete;
    else return refusal("UnsupportedAcknowledgement");
    if (!identity(receipt, ack.shard) || !field(receipt, "transaction", ack.transaction) ||
        !field(receipt, "body_generation", ack.body_generation) || !field(receipt, "payload_digest", ack.payload_digest) ||
        !field(receipt, "geometry_revision", ack.geometry_revision) || !field(receipt, "mask_digest", ack.mask_digest) ||
        !field(receipt, "shape_digest", ack.shape_digest)) return refusal("InvalidAcknowledgementIdentity");
    const Array rows = receipt.get("chunks", Array());
    if (rows.size() > 256) return refusal("TerrainReceiptCapacity");
    std::array<os::TerrainReceipt, 256> terrain{};
    for (std::int64_t index = 0; index < rows.size(); ++index) {
        if (rows[index].get_type() != Variant::DICTIONARY) return refusal("InvalidTerrainReceipt");
        const Dictionary row = rows[index];
        auto& value = terrain[static_cast<std::size_t>(index)];
        std::uint64_t id{};
        if (!field(row, "id", id) || id > std::numeric_limits<std::uint32_t>::max() ||
            !field(row, "revision", value.revision) || !field(row, "digest", value.digest)) return refusal("InvalidTerrainReceipt");
        value.id = static_cast<std::uint32_t>(id);
    }
    ack.terrain = std::span(terrain.data(), static_cast<std::size_t>(rows.size()));
    try {
        auto receipt=result(coordinator_->acknowledge(ack));
        if ((ack.kind==os::AckKind::ReabsorptionFrozen || ack.kind==os::AckKind::ReabsorptionComplete) &&
            static_cast<std::int64_t>(reabsorption_receipt_.get("transaction_id",0))==static_cast<std::int64_t>(ack.transaction)) {
            for (const auto* key:{"source_target","session","world_generation","transport_generation","owner_epoch",
                "shard_session","world_incarnation","action_id","port_generation","operation","position"})
                receipt[key]=reabsorption_receipt_.get(key,Variant());
            receipt["same_world"]=true;receipt["transaction_id"]=static_cast<std::int64_t>(ack.transaction);
            receipt["applied"]=ack.kind==os::AckKind::ReabsorptionComplete && static_cast<bool>(receipt.get("ok",false));
            receipt["world_committed"]=static_cast<bool>(receipt.get("ok",false));
            if (static_cast<bool>(receipt["applied"])) {
                receipt["retired_inventory_cells"]=0;
                PackedInt64Array quantities;
                for (const auto value:coordinator_->world().quantity_ledger().material_cells)
                    quantities.push_back(static_cast<std::int64_t>(value));
                receipt["world_material_counts"]=quantities;
            }
        }
        return receipt;
    }
    catch (const std::exception& error) { return fail(error.what()); }
}

Dictionary CyberObjectShardLab::cancel(std::int64_t transaction) {
    if (!owned() || transaction < 0) return refusal("InvalidTransaction");
    try { return result(coordinator_->cancel(static_cast<std::uint64_t>(transaction))); }
    catch (const std::exception& error) { return fail(error.what()); }
}

Dictionary CyberObjectShardLab::snapshot(bool include_world) {
    if (!owned()) return refusal("Fenced");
    try {
        const auto& source = coordinator_->snapshot(include_world);
        Dictionary output;
        output["ok"] = !source.quarantined;
        output["session"] = static_cast<std::int64_t>(source.session);
        output["world_incarnation"] = static_cast<std::int64_t>(source.world_incarnation);
        output["tick"] = static_cast<std::int64_t>(source.tick);
        output["next_transaction"] = static_cast<std::int64_t>(source.next_transaction);
        output["width"] = source.bounds.width; output["height"] = source.bounds.height;
        output["paused"] = source.paused; output["quarantined"] = source.quarantined;
        output["last_result"] = result(source.last_result);
        output["admission"] = admission_value(source.admission);
        PackedByteArray materials, pixels;
        materials.resize(source.world_materials.size()); pixels.resize(source.world_materials.size() * 4);
        for (std::size_t index = 0; index < source.world_materials.size(); ++index) {
            materials.ptrw()[index] = source.world_materials[index];
            rgba(pixels, index, coordinator_->inspect_world(source.bounds.x + static_cast<std::int64_t>(index % source.bounds.width),
                source.bounds.y + static_cast<std::int64_t>(index / source.bounds.width)), false);
        }
        output["world_materials"] = materials; output["world_rgba"] = pixels;
        output["world_pixels_included"] = include_world;
        PackedInt64Array world_counts;
        for (const auto count:coordinator_->world().quantity_ledger().material_cells)
            world_counts.push_back(static_cast<std::int64_t>(count));
        output["world_material_counts"]=world_counts;
        Array chunks;
        for (const auto& chunk : source.terrain_chunks) {
            Dictionary row = terrain_identity(chunk.identity);
            row["session"] = static_cast<std::int64_t>(source.session);
            PackedInt32Array rectangles;
            for (const auto& rect : chunk.rectangles) {
                rectangles.push_back(static_cast<std::int32_t>(chunk.x + rect.x));
                rectangles.push_back(static_cast<std::int32_t>(chunk.y + rect.y));
                rectangles.push_back(rect.width); rectangles.push_back(rect.height);
            }
            row["rectangles"] = rectangles;
            chunks.push_back(row);
        }
        output["terrain_chunks"] = chunks;
        Dictionary promotion;
        promotion["present"] = source.promotion.present;
        if (source.promotion.present) {
            promotion["id"] = static_cast<std::int64_t>(source.promotion.shard.id);
            promotion["transaction"] = static_cast<std::int64_t>(source.promotion.transaction);
            promotion["payload_digest"] = number(source.promotion.payload_digest);
            promotion["phase"] = os::phase_name(source.promotion.phase);
            promotion["captured_tick"] = static_cast<std::int64_t>(source.promotion.captured_tick);
            promotion["fragment"] = source.promotion.source_parent.id != 0;
            promotion["source_parent_id"] = static_cast<std::int64_t>(source.promotion.source_parent.id);
            Array expected;
            for (const auto& chunk : source.promotion.terrain) expected.push_back(terrain_identity(chunk));
            promotion["chunks"] = expected;
        }
        output["promotion"] = promotion;
        Dictionary reabsorption;
        reabsorption["present"]=source.reabsorption.present;
        if (source.reabsorption.present) {
            const auto& staged=source.reabsorption;
            reabsorption["session"]=static_cast<std::int64_t>(staged.shard.session);
            reabsorption["id"]=static_cast<std::int64_t>(staged.shard.id);
            reabsorption["generation"]=static_cast<std::int64_t>(staged.shard.generation);
            reabsorption["body_generation"]=static_cast<std::int64_t>(staged.body_generation);
            reabsorption["transaction"]=static_cast<std::int64_t>(staged.transaction);
            reabsorption["captured_tick"]=static_cast<std::int64_t>(staged.captured_tick);
            reabsorption["payload_digest"]=number(staged.payload_digest);
            reabsorption["geometry_revision"]=static_cast<std::int64_t>(staged.geometry_revision);
            reabsorption["mask_digest"]=number(staged.mask_digest);reabsorption["shape_digest"]=number(staged.shape_digest);
            reabsorption["phase"]=staged.world_committed ? "WorldCommitted" : "Prepared";
            reabsorption["source_target"]=reabsorption_receipt_.get("source_target",Dictionary());
            Array expected;for (const auto& chunk:staged.terrain) expected.push_back(terrain_identity(chunk));
            reabsorption["chunks"]=expected;
        }
        output["reabsorption"]=reabsorption;
        Array shards;
        if (source.shards.size()>carrier_cache_.size()) return fail("CarrierSnapshotCapacity");
        std::size_t slot=0;
        for (const auto& shard : source.shards) {
            auto& cached=carrier_cache_[slot++];
            if (shard.phase() == os::Phase::Empty || shard.phase() == os::Phase::Retired) continue;
            const auto handle = shard.handle();
            const os::BodyView* body = nullptr;
            for (const auto& candidate : source.bodies) if (candidate.shard == handle) { body = &candidate; break; }
            const auto bounds = shard.bounds();
            const auto& geometry = shard.geometry();
            Dictionary row;
            row["session"] = static_cast<std::int64_t>(handle.session);
            row["id"] = static_cast<std::int64_t>(handle.id); row["generation"] = static_cast<std::int64_t>(handle.generation);
            row["transaction"] = static_cast<std::int64_t>(body ? body->transaction : source.promotion.transaction);
            row["lifecycle"] = os::phase_name(shard.phase()); row["owns_inventory"] = shard.owns_inventory();
            row["origin_x"] = bounds.x; row["origin_y"] = bounds.y;
            row["width"] = bounds.width; row["height"] = bounds.height;
            row["body_generation"] = static_cast<std::int64_t>(body && body->body_generation ? body->body_generation : handle.generation);
            row["pose_serial"] = static_cast<std::int64_t>(body ? body->pose.pose_serial : 0);
            // A draining domain keeps its last physical release anchor after
            // its RID retires. Capture coordinates never regain pose authority.
            row["position_x"] = body ? body->pose.x : static_cast<double>(bounds.x);
            row["position_y"] = body ? body->pose.y : static_cast<double>(bounds.y);
            row["rotation"] = body ? body->pose.rotation : 0.0;
            row["vx"] = body ? body->pose.vx : 0.0;
            row["vy"] = body ? body->pose.vy : 0.0;
            row["angular_velocity"] = body ? body->pose.angular_velocity : 0.0;
            row["sleeping"] = body && body->pose.sleeping;
            row["fragment"] = body && body->source_parent.id != 0;
            row["fragment_deferred"] = body && body->fragment_deferred;
            row["source_parent_id"] = static_cast<std::int64_t>(body ? body->source_parent.id : 0);
            row["has_body"] = body && body->has_body;
            row["geometry_pending"] = body && body->geometry_pending;
            row["ingress_fenced"] = body && body->ingress_fenced;
            row["material_revision"] = static_cast<std::int64_t>(shard.material_revision());
            row["topology_revision"] = static_cast<std::int64_t>(shard.topology_revision());
            row["geometry_revision"] = static_cast<std::int64_t>(geometry.revision);
            row["applied_physics_revision"] = static_cast<std::int64_t>(shard.applied_physics_revision());
            row["payload_digest"] = number(shard.payload_digest());
            row["geometry_digest"] = number(geometry.shape_digest);
            row["mask_digest"] = number(geometry.mask_digest); row["shape_digest"] = number(geometry.shape_digest);
            row["mass"] = geometry.mass.mass; row["com_x"] = geometry.mass.com_x; row["com_y"] = geometry.mass.com_y;
            row["inertia"] = geometry.mass.inertia; row["split_pending"] = geometry.split_pending;
            row["islands"] = geometry.islands;
            const auto counts = shard.counts();
            row["structural"] = counts.structural; row["products"] = counts.products; row["cargo"] = counts.cargo;
            if (body && body->pocket_open) {
                const auto opening = os::contact::pocket_opening(shard, body->pocket_cell);
                if (opening.outcome == os::Outcome::Accepted)
                    row["pocket"] = Rect2i(opening.min_x, opening.row, opening.max_x - opening.min_x, 1);
            }
            PackedInt32Array rectangles;
            for (const auto& rect : geometry.shapes) {
                rectangles.push_back(rect.x); rectangles.push_back(rect.y);
                rectangles.push_back(rect.width); rectangles.push_back(rect.height);
            }
            row["rectangles"] = rectangles;
            if (cached.handle!=handle || cached.material_revision!=shard.material_revision()) {
            PackedInt32Array states_a, states_b, temperature, roles, incarnations;
            PackedByteArray cell_materials, cell_pixels, render_cells;
            cell_materials.resize(shard.area()); cell_pixels.resize(shard.area() * 4);
            render_cells.resize(shard.area() * 2);
            for (std::size_t index = 0; index < shard.area(); ++index) {
                const auto cell = shard.payload(index);
                cell_materials.ptrw()[index] = static_cast<std::uint8_t>(cell.material);
                // The ordinary palette consumes material + projected visual
                // condition. Reuse that read-only contract for owned cells;
                // raw state_a is not a universal condition channel.
                render_cells.ptrw()[index * 2] = static_cast<std::uint8_t>(cell.material);
                render_cells.ptrw()[index * 2 + 1] = cybersand::project_visual_state(
                    cell.material, cell.state_a, cell.state_b,
                    coordinator_->world().config().water_experiment_policy);
                states_a.push_back(cell.state_a); states_b.push_back(cell.state_b);
                temperature.push_back(cell.temperature); roles.push_back(static_cast<std::int32_t>(shard.role(index)));
                incarnations.push_back(static_cast<std::int32_t>(shard.schedule(index).incarnation));
                rgba(cell_pixels, index, cell, true);
            }
            Dictionary carriers;
            carriers["materials"] = cell_materials; carriers["rgba"] = cell_pixels;
            carriers["render_cells"] = render_cells;
            carriers["states_a"] = states_a; carriers["states_b"] = states_b; carriers["temperature"] = temperature;
            carriers["roles"] = roles; carriers["incarnations"] = incarnations;
            cached={handle,shard.material_revision(),carriers};
            }
            // Godot's packed values are copy-on-write. A later caller mutation
            // cannot alter the native cache or another published observation.
            row.merge(cached.values);
            shards.push_back(row);
        }
        output["shards"] = shards;
        Dictionary accounting;
#define COPY_COUNTS(name) { PackedInt64Array counts; for (auto value : source.accounting.name) counts.push_back(static_cast<std::int64_t>(value)); accounting[#name] = counts; }
        COPY_COUNTS(promoted); COPY_COUNTS(ingested); COPY_COUNTS(emitted);
        COPY_COUNTS(created); COPY_COUNTS(destroyed); COPY_COUNTS(expired); COPY_COUNTS(reset_disposed);
        COPY_COUNTS(setup_created); COPY_COUNTS(authored_created); COPY_COUNTS(authored_destroyed); COPY_COUNTS(world_tick_delta);
#undef COPY_COUNTS
        accounting["reset_water_quanta"] = static_cast<std::int64_t>(source.accounting.reset_water_quanta);
        accounting["extinguished"] = static_cast<std::int64_t>(source.accounting.extinguished);
        accounting["accepted_exposures"] = static_cast<std::int64_t>(source.accounting.accepted_exposures);
        accounting["consumed_exposures"] = static_cast<std::int64_t>(source.accounting.consumed_exposures);
        accounting["external_ignitions"] = static_cast<std::int64_t>(source.accounting.external_ignitions);
        accounting["scope"] = "Lifetime ownership ledger, including explicit reset disposal; not session-only totals";
        output["accounting"] = accounting; output["metrics"] = metrics_value(source.metrics);
        output["metrics_scope"] = "Current session counters and maxima, reset at native reset";
        output["lifetime_metrics"] = metrics_value(source.lifetime_metrics);
        output["lifetime_metrics_scope"] = "This native owner instance including reset sessions; canvas replacement creates a new owner";
        return output;
    } catch (const std::exception& error) { return fail(error.what()); }
}

Dictionary CyberObjectShardLab::inspect(Vector2i position) const {
    if (!owned()) return refusal("Fenced");
    Dictionary row = payload(coordinator_->inspect_world(position.x, position.y));
    row["ok"] = true; row["position"] = position; row["owner"] = "World";
    return row;
}

Dictionary CyberObjectShardLab::metrics() const {
    if (!owned()) return refusal("Fenced");
    return metrics_value(coordinator_->metrics());
}

Dictionary CyberObjectShardLab::capabilities() const {
    Dictionary value;
    value["version"] = os::kCapabilityVersion;
    value["implemented_milestone"] = 2;
    value["qualification"] = "M2 experimental source; exact platform/package receipts are separate from capability advertisement";
    value["surface_contact"] = true;
    value["surface_contact_scope"] = "Historical non-consuming Water extinction; selected World Fire ignition opportunity bound to the same Wood incarnation";
    value["reaction"] = true;
    value["selected_lifecycle"] = "Wood combustion; retained Fire to Smoke; Smoke expiry; no internal transport";
    Dictionary rules;
    rules["int.kernel.combustible.burn.v1"] = "Wood only: burn cadence, Water extinction, consumption and real Fire production";
    rules["int.kernel.fire.ignite-smoke.v1"] = "Selected local ignition and Fire expiry; movement stays World-owned after delivery";
    value["selected_rule_ids"] = rules;
    value["mutable_geometry"] = true;
    value["emission"] = true;
    value["emission_scope"] = "Exact Fire/Smoke product transfer; retained cargo release while draining";
    value["ingestion"] = true;
    value["ingestion_scope"] = "Baseline whole-cell Sand through a validated open lodging aperture; cargo never forms structural bonds";
    value["cargo_mass_policy"] = "Retained Sand contributes mass, COM and inertia but does not add a rigid shape";
    value["whole_cell_quantity"] = true;
    value["fractional_quantity"] = false; value["momentum_state_transfer"] = false;
    value["solver_sidecar_transfer"] = false; value["internal_transport"] = false;
    value["persistence_restore"] = false; value["fracture"] = false;
    value["max_bodies"] = 3; value["max_shapes_per_body"] = 256;
    value["transfer_budget_per_tick"] = owner_ == std::this_thread::get_id() && coordinator_
        ? coordinator_->config().transfer_budget : 64;
    value["motion_envelope"] = "Each actual physics segment: at most 4 cells translation, 0.20 radians rotation and 8 cells corner travel; at most 16 segments per semantic step; unresolved complete rotations hold the Lab";
    value["world_solver"] = "Explicit isolated SerialInPlace baseline; production Water defaults unchanged";
    return value;
}

void CyberObjectShardLab::_bind_methods() {
    ClassDB::bind_method(D_METHOD("configure", "configuration"), &CyberObjectShardLab::configure);
    ClassDB::bind_method(D_METHOD("reset", "scenario", "seed"), &CyberObjectShardLab::reset);
    ClassDB::bind_method(D_METHOD("step", "poses"), &CyberObjectShardLab::step);
    ClassDB::bind_method(D_METHOD("accept_motion", "poses"), &CyberObjectShardLab::accept_motion);
    ClassDB::bind_method(D_METHOD("edit_cell", "position", "material", "state_a", "state_b", "temperature"), &CyberObjectShardLab::edit_cell);
    ClassDB::bind_method(D_METHOD("erase_shard", "request"), &CyberObjectShardLab::erase_shard);
    ClassDB::bind_method(D_METHOD("ignite", "position"), &CyberObjectShardLab::ignite);
    ClassDB::bind_method(D_METHOD("ignite_shard", "id", "generation", "cell"), &CyberObjectShardLab::ignite_shard);
    ClassDB::bind_method(D_METHOD("prepare_next"), &CyberObjectShardLab::prepare_next);
    ClassDB::bind_method(D_METHOD("acknowledge", "receipt"), &CyberObjectShardLab::acknowledge);
    ClassDB::bind_method(D_METHOD("cancel", "transaction"), &CyberObjectShardLab::cancel);
    ClassDB::bind_method(D_METHOD("snapshot", "include_world"), &CyberObjectShardLab::snapshot, DEFVAL(true));
    ClassDB::bind_method(D_METHOD("inspect", "position"), &CyberObjectShardLab::inspect);
    ClassDB::bind_method(D_METHOD("capabilities"), &CyberObjectShardLab::capabilities);
    ClassDB::bind_method(D_METHOD("metrics"), &CyberObjectShardLab::metrics);
}

} // namespace godot
