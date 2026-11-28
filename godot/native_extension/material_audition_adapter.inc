// Included inside namespace godot. Configuration serialization is deliberately
// cold. Native tick workers consume fixed numeric arrays, never Dictionaries.
namespace material_audition_wire {

String text(std::string_view value) {
    return String::utf8(value.data(),static_cast<int64_t>(value.size()));
}

Dictionary refused(const String& error, const String& code = "invalid_request") {
    Dictionary out;
    out["ok"] = false; out["accepted"] = false; out["status"] = "refused";
    out["error"] = error; out["code"] = code;
    return out;
}

bool keys(const Dictionary& value, std::initializer_list<const char*> admitted) {
    for (const Variant& key : value.keys()) {
        if (key.get_type() != Variant::STRING) return false;
        const String name = key;
        bool found = false;
        for (const char* expected : admitted) if (name == expected) found = true;
        if (!found) return false;
    }
    return true;
}

bool integer(const Variant& input, std::int64_t low, std::int64_t high, std::int64_t& output) {
    if (input.get_type() == Variant::INT) {
        output = static_cast<std::int64_t>(input);
        return output >= low && output <= high;
    }
    // Godot JSON represents numbers as doubles. Refuse fractions, nonfinite
    // values and narrowing overflow; boolean is never accepted as a number.
    if (input.get_type() != Variant::FLOAT) return false;
    const double value = input;
    if (!std::isfinite(value) || value < static_cast<double>(low) ||
        value > static_cast<double>(high) || std::floor(value) != value) return false;
    output = static_cast<std::int64_t>(value);
    return true;
}

bool world_identity(const Variant& input, std::uint64_t& value) {
    if (input.get_type() != Variant::STRING) return false;
    const CharString bytes = static_cast<String>(input).utf8();
    if (bytes.length() == 0 || bytes.length() > 20) return false;
    const char* first = bytes.get_data();
    const auto result = std::from_chars(first,first+bytes.length(),value);
    return result.ec == std::errc{} && result.ptr == first+bytes.length() && value != 0;
}

Dictionary encode_profile(const cybersand::MaterialAuditionProfile& profile) {
    Dictionary out;
    out["schema_version"] = static_cast<int64_t>(profile.schema_version);
    out["profile_id"] = text(profile.profile_id);
    Array materials, reactions;
    for (std::size_t i = 0; i < profile.density.size(); ++i) {
        if (profile.density[i] < 0 && profile.viscosity[i] < 0) continue;
        Dictionary row; row["material_id"] = static_cast<int64_t>(i);
        if (profile.density[i] >= 0) row["density"] = profile.density[i];
        if (profile.viscosity[i] >= 0) row["viscosity"] = profile.viscosity[i];
        materials.append(row);
    }
    for (std::size_t i = 0; i < profile.probability_threshold.size(); ++i) {
        if (profile.probability_threshold[i] < 0) continue;
        Dictionary row; row["slot"] = static_cast<int64_t>(i);
        row["probability_threshold"] = profile.probability_threshold[i]; reactions.append(row);
    }
    out["materials"] = materials; out["reactions"] = reactions;
    return out;
}

String decode_profile(const Dictionary& input, cybersand::MaterialAuditionProfile& profile) {
    if (input.size() != 4 || !keys(input,{"schema_version","profile_id","materials","reactions"}))
        return "Profile must contain schema_version, profile_id, materials and reactions only.";
    int64_t value = 0;
    if (!integer(input.get("schema_version",Variant()),1,1,value)) return "Unsupported profile schema_version.";
    if (input.get("profile_id",Variant()).get_type() != Variant::STRING) return "Profile identity must be a string.";
    const CharString name = static_cast<String>(input["profile_id"]).utf8();
    if (name.length() == 0 || name.length() > 64) return "Profile identity must contain 1–64 ASCII characters.";
    // These bytes are independent of the destination. Construct then swap so
    // GCC 13 does not import the newer overlapping-string replacement helper;
    // retain the accepted GLIBCXX_3.4.30 runtime floor.
    std::string decoded_id(name.get_data(),static_cast<std::size_t>(name.length()));
    profile.profile_id.swap(decoded_id);
    if (input.get("materials",Variant()).get_type() != Variant::ARRAY ||
        input.get("reactions",Variant()).get_type() != Variant::ARRAY) return "Change lists must be arrays.";
    const Array materials = input["materials"], reactions = input["reactions"];
    if (materials.size() > static_cast<int64_t>(profile.density.size()) ||
        reactions.size() > static_cast<int64_t>(profile.probability_threshold.size())) return "Profile exceeds catalogue capacity.";
    std::array<bool,cybersand::kMaterialDefinitions.size()> seen_material{};
    for (const Variant& item : materials) {
        if (item.get_type() != Variant::DICTIONARY) return "Material change must be an object.";
        const Dictionary row = item;
        if (row.size() < 2 || !keys(row,{"material_id","density","viscosity"})) return "Unsupported material property or empty change.";
        if (!integer(row.get("material_id",Variant()),0,static_cast<int64_t>(profile.density.size()-1),value)) return "Invalid material identity.";
        const auto id = static_cast<std::size_t>(value);
        if (seen_material[id]) return "Duplicate material identity.";
        seen_material[id] = true;
        if (row.has("density")) {
            if (!integer(row["density"],1,65535,value)) return "Density must be an integer in 1..65535.";
            profile.density[id] = static_cast<std::int32_t>(value);
        }
        if (row.has("viscosity")) {
            if (!integer(row["viscosity"],0,255,value)) return "Viscosity must be an integer in 0..255.";
            profile.viscosity[id] = static_cast<std::int32_t>(value);
        }
    }
    std::array<bool,cybersand::kPairInteractionRules.size()> seen_reaction{};
    for (const Variant& item : reactions) {
        if (item.get_type() != Variant::DICTIONARY) return "Reaction change must be an object.";
        const Dictionary row = item;
        if (row.size() != 2 || !keys(row,{"slot","probability_threshold"})) return "Only existing reaction slot/probability_threshold are admitted.";
        if (!integer(row.get("slot",Variant()),0,static_cast<int64_t>(profile.probability_threshold.size()-1),value)) return "Invalid reaction slot.";
        const auto slot = static_cast<std::size_t>(value);
        if (seen_reaction[slot]) return "Duplicate reaction slot.";
        seen_reaction[slot] = true;
        if (!integer(row.get("probability_threshold",Variant()),0,255,value)) return "Reaction threshold must be an integer in 0..255; zero still admits 1/256 rolls.";
        profile.probability_threshold[slot] = static_cast<std::int32_t>(value);
    }
    return "";
}

Dictionary property(std::size_t id, const char* name, Variant declared, Variant effective,
                    const char* change_class, const char* consumer, const char* applicability,
                    int64_t minimum = 0, int64_t maximum = 0) {
    Dictionary row;
    row["kind"] = "material"; row["material_id"] = static_cast<int64_t>(id);
    row["material_name"] = text(cybersand::kMaterialDefinitions[id].name);
    row["property"] = name; row["declared"] = declared; row["effective"] = effective;
    row["change_class"] = change_class; row["consumer"] = consumer;
    row["applicability"] = applicability; row["minimum"] = minimum; row["maximum"] = maximum;
    return row;
}

String compatibility() {
    // A semantic admission fingerprint, not an exact source/build claim. The
    // profile envelope additionally binds the observed native artifact SHA256.
    std::uint64_t hash = 1469598103934665603ULL;
    const auto add = [&hash](std::uint64_t value) {
        for (int i=0;i<8;++i) { hash ^= static_cast<std::uint8_t>(value); hash *= 1099511628211ULL; value >>= 8; }
    };
    add(1);
    for (std::size_t id=0; id<cybersand::kMaterialDefinitions.size(); ++id) {
        const auto& d = cybersand::kMaterialDefinitions[id];
        add(id); add(d.valid); add(d.density); add(d.viscosity_index);
        add(static_cast<std::uint8_t>(d.kernel)); add(d.accepts_density_exchange);
        add(static_cast<std::uint8_t>(d.density_motion));
    }
    for (const auto& r : cybersand::kPairInteractionRules) {
        add(static_cast<std::uint8_t>(r.first)); add(static_cast<std::uint8_t>(r.second));
        add(static_cast<std::uint8_t>(r.first_product)); add(static_cast<std::uint8_t>(r.second_product));
        add(r.probability); add(static_cast<std::uint8_t>(r.match));
    }
    return "material-audition-v1:" + String::num_uint64(hash,16).lpad(16,"0");
}

} // namespace material_audition_wire

Dictionary CyberNativeCellWorld::get_material_audition_state() const try {
    using namespace material_audition_wire;
    if (!world_) return refused("Native World unavailable.","world_unavailable");
    if (has_failed()) return refused("Native World is quarantined.","world_failed");
    Dictionary out;
    out["ok"] = true; out["status"] = "active";
    out["world_id"] = String::num_uint64(world_->material_audition_world_id());
    out["revision"] = static_cast<int64_t>(world_->material_audition_revision());
    out["observed_tick"] = static_cast<int64_t>(world_->completed_tick_index());
    out["profile"] = encode_profile(world_->material_audition_profile());
    out["changes_behavior"] = world_->material_audition_changes_behavior();
    out["behavior_hash"] = String::num_uint64(world_->material_audition_behavior_hash(),16).lpad(16,"0");
    out["native_compatibility"] = compatibility();
    out["physical_state_hash_version"] = static_cast<int64_t>(world_->physical_state_hash_version());
    out["physical_state_format_version"] = static_cast<int64_t>(world_->physical_state_format_version());
    out["scope"] = "Current native World only; configuration changes preserve its cells, tick and actors. Reverting configuration does not reverse simulation consequences.";
    Array capabilities;
    for (std::size_t id=0; id<cybersand::kMaterialDefinitions.size(); ++id) {
        const auto& d = cybersand::kMaterialDefinitions[id];
        if (!d.valid || id == 0) continue;
        const auto material = static_cast<cybersand::Material>(id);
        const bool density = cybersand::material_audition_supports_density(material);
        const bool viscosity = world_->material_audition_viscosity_available(material);
        capabilities.append(property(id,"density",d.density,world_->material_audition_effective_density(material),
            density ? "live" : "isolated","World::try_move directional density exchange",
            density ? "Directional cell exchange only; excludes Rapier mass, collision impulse and solver-specific pressure/wave/inertial density laws."
                    : "This material does not participate in the admitted directional density-exchange consumer.",1,65535));
        capabilities.append(property(id,"viscosity",d.viscosity_index,world_->material_audition_effective_viscosity(material),
            viscosity ? "live" : "unsupported","World generic yielding-liquid movement",
            viscosity ? "Generic YieldingLiquid, Cement or MoltenGlass movement; thermal state and specialised kernels are unchanged. Diagnostic Mercury override conflicts are refused."
                      : "The active kernel/solver or a diagnostic owner bypasses descriptor viscosity. Water and inertial families have separate policies.",0,255));
        capabilities.append(property(id,"physical_state",static_cast<int64_t>(d.state),static_cast<int64_t>(d.state),
            "restart","Material definition and native kernel dispatch","Identity/state/kernel migration requires separate source validation and reconstruction; no live control."));
        capabilities.append(property(id,"hard_surface",cybersand::MaterialRules::is_hard_surface(material),cybersand::MaterialRules::is_hard_surface(material),
            "unsupported","Generated material capability map and collider ownership","Collision and ObjectShard ownership are outside this scene-local profile."));
        capabilities.append(property(id,"name",text(d.name),text(d.name),"metadata","Catalogue display label","A label has no direct simulation effect; stable material identity is unchanged."));
    }
    for (std::size_t slot=0; slot<cybersand::kPairInteractionRules.size(); ++slot) {
        const auto& rule = cybersand::kPairInteractionRules[slot];
        Dictionary row;
        row["kind"] = "reaction"; row["slot"] = static_cast<int64_t>(slot); row["rule_id"] = text(rule.id);
        row["property"] = "probability_threshold"; row["declared"] = rule.probability;
        row["effective"] = world_->material_audition_effective_probability(slot);
        row["minimum"] = 0; row["maximum"] = 255;
        row["change_class"] = world_->material_audition_probability_available(slot) ? "live" : "isolated";
        row["first"] = static_cast<int64_t>(rule.first); row["second"] = static_cast<int64_t>(rule.second);
        row["first_product"] = static_cast<int64_t>(rule.first_product); row["second_product"] = static_cast<int64_t>(rule.second_product);
        row["match"] = static_cast<int64_t>(rule.match);
        row["consumer"] = "World compact-pair resolver; existing four-tick contact lane";
        row["applicability"] = world_->material_audition_probability_available(slot)
            ? "Eligible scheduled native contacts only. Inclusive roll <= threshold: (threshold+1)/256; zero is not disabled. Endpoint roles, products, effects and first-match order remain canonical. This readback does not witness an executed reaction."
            : "Neither endpoint can initiate this compact reaction under the active solver. Use isolated comparison with an admitted family; no current-scene probability edit is accepted.";
        row["effects"] = "Canonical existing World endpoint effects; products and state/quantity semantics are not editable.";
        capabilities.append(row);
    }
    out["capabilities"] = capabilities;
    return out;
} catch (const std::exception& error) {
    return material_audition_wire::refused(String("Material readback failed: ")+error.what(),"readback_failed");
} catch (...) {
    return material_audition_wire::refused("Material readback failed.","readback_failed");
}

Dictionary CyberNativeCellWorld::apply_material_audition(const Dictionary& request) {
    bool activated = false;
    std::uint64_t activated_world = 0, activated_revision = 0;
    try {
    using namespace material_audition_wire;
    if (!world_) return refused("Native World unavailable.","world_unavailable");
    if (request.size() != 3 || !keys(request,{"world_id","expected_revision","profile"}))
        return refused("Request needs world_id, expected_revision and profile only.");
    std::uint64_t world_id = 0;
    if (!world_identity(request.get("world_id",Variant()),world_id)) return refused("Invalid native World identity.");
    const Variant revision = request.get("expected_revision",Variant());
    if (revision.get_type() != Variant::INT || static_cast<int64_t>(revision) < 0)
        return refused("Expected revision must be a nonnegative integer.");
    if (request.get("profile",Variant()).get_type() != Variant::DICTIONARY) return refused("Profile must be an object.");
    cybersand::MaterialAuditionProfile profile;
    if (const String error = decode_profile(request["profile"],profile); !error.is_empty()) return refused(error);
    // Prepare the successful profile copy before publication. If a later
    // receipt allocation nevertheless fails, distinguish committed state from
    // admission refusal; the worker then obtains authoritative fresh readback.
    const Dictionary proposed_profile = encode_profile(profile);
    const auto before_tick = world_->completed_tick_index();
    const auto result = world_->apply_material_audition(world_id,static_cast<std::uint64_t>(static_cast<int64_t>(revision)),profile);
    activated = result.applied();
    activated_world = result.world_id;
    activated_revision = result.revision;
    Dictionary out;
    out["ok"] = result.applied(); out["accepted"] = result.applied();
    out["status"] = result.applied() ? "active" : "refused";
    out["error"] = result.applied() ? String() : text(result.reason);
    out["code"] = static_cast<int64_t>(result.outcome);
    out["field"] = text(result.field); out["index"] = result.index;
    out["world_id"] = String::num_uint64(result.world_id);
    out["prior_revision"] = static_cast<int64_t>(result.prior_revision);
    out["revision"] = static_cast<int64_t>(result.revision);
    out["behavior_hash"] = String::num_uint64(result.behavior_hash,16).lpad(16,"0");
    out["woken_blocks"] = static_cast<int64_t>(result.woken_blocks);
    out["scanned_cells"] = static_cast<int64_t>(result.scanned_cells);
    out["tick_before"] = static_cast<int64_t>(before_tick);
    out["tick_after"] = static_cast<int64_t>(world_->completed_tick_index());
    out["profile"] = activated ? proposed_profile : encode_profile(world_->material_audition_profile());
    return out;
    } catch (...) {
        auto out = material_audition_wire::refused(activated
            ? "Native configuration activated, but receipt construction failed. Refresh active values before further changes."
            : "Material admission failed before activation.",
            activated ? "active_readback_failed" : "admission_failed");
        if (activated) {
            out["accepted"] = true; out["status"] = "active_readback_failed";
            out["world_id"] = String::num_uint64(activated_world);
            out["revision"] = static_cast<int64_t>(activated_revision);
        }
        return out;
    }
}
