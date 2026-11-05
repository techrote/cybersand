// Included in CyberNativeCellWorld's namespace (cyber_native_cell_world.cpp).
// WCX/BW-001 adapter-owned Water spray launch law (experimental, opt-in).
//
// The native World owns every Water quantity and parcel (ballistic_water_v1).
// This host-side law only decides *when* a body's overlap displaces Water into
// flight and with which velocity, from the sampled body motion it already
// owns. It runs at the serialized coupling boundary, never in a worker.
// Launch velocity is intentionally stylized: the injected parcel momentum is
// booked natively as launch momentum, and the optional extra body reaction is
// a separate, default-zero gain so the accepted LA/RFT contact feel is kept.

namespace {

constexpr double kSprayQ = static_cast<double>(cybersand::BallisticWaterConfig::kQ);

[[nodiscard]] double spray_hash01(std::int64_t x, std::int64_t y, std::uint64_t salt) noexcept {
    std::uint64_t v = static_cast<std::uint64_t>(x) * 0x9e3779b185ebca87ULL ^
                      (static_cast<std::uint64_t>(y) + 0x632be59bd9b4e019ULL) * 0xc2b2ae3d27d4eb4fULL ^ salt;
    v ^= v >> 33U; v *= 0xff51afd7ed558ccdULL; v ^= v >> 33U; v *= 0xc4ceb9fe1a85ec53ULL; v ^= v >> 33U;
    return static_cast<double>(v >> 11U) * (1.0 / 9007199254740992.0);
}

[[nodiscard]] String spray_outcome_id(cybersand::BallisticLaunchOutcome outcome) {
    using O = cybersand::BallisticLaunchOutcome;
    switch (outcome) {
        case O::Launched: return "launched";
        case O::Disabled: return "disabled";
        case O::WorldFailed: return "world_failed";
        case O::TickInProgress: return "tick_in_progress";
        case O::InvalidRequest: return "invalid_request";
        case O::NotWater: return "not_water";
        case O::Masked: return "masked";
        case O::CapacityFull: return "capacity_full";
        case O::Pressurized: return "pressurized";
        case O::NonResident: return "non_resident";
        case O::InsufficientQuantity: return "insufficient_quantity";
    }
    return "unknown";
}

} // namespace

Dictionary CyberNativeCellWorld::water_spray_settings_dictionary(const WaterSpraySettings& s) {
    Dictionary d;
    d["enabled"] = s.enabled;
    d["launch_scale"] = s.launch_scale;
    d["threshold"] = s.threshold;
    d["upward_bias"] = s.upward_bias;
    d["spread"] = s.spread;
    d["jitter"] = s.jitter;
    d["budget"] = s.budget;
    d["reaction_gain"] = s.reaction_gain;
    d["droplet_gain"] = s.droplet_gain;
    d["submerged_lift"] = s.submerged_lift;
    d["lift_reach"] = s.lift_reach;
    d["jet_enabled"] = s.jet_enabled;
    d["jet_origin"] = s.jet_origin;
    d["jet_angle"] = s.jet_angle;
    d["jet_speed"] = s.jet_speed;
    d["jet_rate"] = s.jet_rate;
    d["jet_quantity"] = s.jet_quantity;
    d["jet_spread"] = s.jet_spread;
    d["nozzle_speed"] = s.nozzle_speed;
    return d;
}

Dictionary CyberNativeCellWorld::set_water_spray(const Dictionary& request) {
    Dictionary result;
    auto next = spray_;
    String refusal;
    const auto number = [&](const char* key, double& field, double low, double high) {
        if (!request.has(key)) return;
        const Variant v = request[key];
        if (v.get_type() != Variant::FLOAT && v.get_type() != Variant::INT) { refusal = String(key) + " must be a number"; return; }
        const double value = v;
        if (!std::isfinite(value) || value < low || value > high) {
            refusal = String(key) + " outside " + String::num(low) + ".." + String::num(high);
            return;
        }
        field = value;
    };
    const auto integer = [&](const char* key, std::int64_t& field, std::int64_t low, std::int64_t high) {
        if (!request.has(key)) return;
        const Variant v = request[key];
        if (v.get_type() != Variant::INT) { refusal = String(key) + " must be an integer"; return; }
        const std::int64_t value = v;
        if (value < low || value > high) { refusal = String(key) + " outside its admitted range"; return; }
        field = value;
    };
    const auto boolean = [&](const char* key, bool& field) {
        if (!request.has(key)) return;
        if (request[key].get_type() != Variant::BOOL) { refusal = String(key) + " must be a boolean"; return; }
        field = request[key];
    };
    boolean("enabled", next.enabled);
    number("launch_scale", next.launch_scale, 0.0, 8.0);
    number("threshold", next.threshold, 0.0, 6.0);
    number("upward_bias", next.upward_bias, 0.0, 1.0);
    number("spread", next.spread, 0.0, 2.0);
    number("jitter", next.jitter, 0.0, 1.0);
    integer("budget", next.budget, 0, 512);
    number("reaction_gain", next.reaction_gain, 0.0, 4.0);
    number("droplet_gain", next.droplet_gain, 0.0, 1e-4);
    boolean("submerged_lift", next.submerged_lift);
    integer("lift_reach", next.lift_reach, 1, 96);
    boolean("jet_enabled", next.jet_enabled);
    if (request.has("jet_origin")) {
        if (request["jet_origin"].get_type() != Variant::VECTOR2I) refusal = "jet_origin must be a Vector2i";
        else next.jet_origin = request["jet_origin"];
    }
    number("jet_angle", next.jet_angle, -180.0, 180.0);
    number("jet_speed", next.jet_speed, 0.0, 6.0);
    integer("jet_rate", next.jet_rate, 0, 16);
    integer("jet_quantity", next.jet_quantity, 1, 255);
    number("jet_spread", next.jet_spread, 0.0, 45.0);
    number("nozzle_speed", next.nozzle_speed, 0.0, 6.0);
    for (const auto& key : request.keys()) {
        if (!water_spray_settings_dictionary(next).has(key)) refusal = "unknown spray setting " + String(key);
    }
    const bool ballistic = world_ != nullptr && world_->ballistic_water_enabled();
    if (refusal.is_empty() && (next.enabled || next.jet_enabled) && !ballistic)
        refusal = "ballistic Water is not enabled in this World (rebuild with ballistic mode)";
    result["accepted"] = refusal.is_empty();
    result["refusal"] = refusal;
    if (refusal.is_empty()) spray_ = next;
    result["applied"] = water_spray_settings_dictionary(spray_);
    return result;
}

Dictionary CyberNativeCellWorld::get_water_spray() const {
    Dictionary d;
    d["settings"] = water_spray_settings_dictionary(spray_);
    if (world_ == nullptr) return d;
    const auto snapshot = world_->ballistic_water_snapshot();
    d["ballistic_enabled"] = snapshot.enabled;
    d["inertial_signed"] = world_->inertial_parameters().signed_vertical;
    d["live"] = static_cast<std::int64_t>(snapshot.live);
    d["capacity"] = static_cast<std::int64_t>(snapshot.capacity);
    d["in_flight_quantity"] = static_cast<std::int64_t>(snapshot.in_flight_quantity);
    // Exact closed-system readback: grid + in-flight Water against the source/sink ledger.
    if (!world_->has_failed()) {
        const auto q = world_->quantity_ledger();
        std::uint64_t produced = q.baseline_water, consumed = 0;
        for (const auto& flow : q.kinds) { produced += flow.produced; consumed += flow.consumed; }
        Dictionary water;
        water["visible"] = static_cast<std::int64_t>(q.water_visible);
        water["overfill"] = static_cast<std::int64_t>(q.water_overfill);
        water["ballistic"] = static_cast<std::int64_t>(q.water_ballistic);
        water["total"] = static_cast<std::int64_t>(q.water_visible + q.water_overfill + q.water_ballistic);
        water["expected"] = static_cast<std::int64_t>(produced - consumed);
        d["water"] = water;
    }
    d["native_tick_ms"] = simulation_time_ms_;
    // Bounded presentation/telemetry summary of the live parcels (cells, cells/tick).
    if (snapshot.live != 0U) {
        std::vector<cybersand::BallisticParcel> parcels(std::min<std::size_t>(snapshot.live, 8'192));
        const auto live = std::min(world_->copy_ballistic_parcels(parcels), parcels.size());
        double top = 1e18, bottom = -1e18, left = 1e18, right = -1e18, speed = 0, peak = 0;
        std::int64_t rising = 0;
        for (std::size_t i = 0; i < live; ++i) {
            const auto& p = parcels[i];
            const double x = static_cast<double>(p.x) / kSprayQ, y = static_cast<double>(p.y) / kSprayQ;
            top = std::min(top, y); bottom = std::max(bottom, y); left = std::min(left, x); right = std::max(right, x);
            const double v = std::sqrt(static_cast<double>(p.vx) * p.vx + static_cast<double>(p.vy) * p.vy) / kSprayQ;
            speed += v; peak = std::max(peak, v);
            if (p.vy < 0) ++rising;
        }
        Dictionary summary;
        summary["top_row"] = top; summary["bottom_row"] = bottom; summary["left"] = left; summary["right"] = right;
        summary["mean_speed"] = live ? speed / static_cast<double>(live) : 0.0; summary["peak_speed"] = peak;
        summary["rising"] = rising; summary["sampled"] = static_cast<std::int64_t>(live);
        d["parcels"] = summary;
    }
    const auto& l = snapshot.ledger;
    Dictionary ledger;
    ledger["launched_parcels"] = static_cast<std::int64_t>(l.launched_parcels);
    ledger["launched_quantity"] = static_cast<std::int64_t>(l.launched_quantity);
    ledger["injected_parcels"] = static_cast<std::int64_t>(l.injected_parcels);
    ledger["injected_quantity"] = static_cast<std::int64_t>(l.injected_quantity);
    ledger["deposited_parcels"] = static_cast<std::int64_t>(l.deposited_parcels);
    ledger["deposited_quantity"] = static_cast<std::int64_t>(l.deposited_quantity);
    ledger["deferred_deposits"] = static_cast<std::int64_t>(l.deferred_deposits);
    ledger["refused_launches"] = static_cast<std::int64_t>(l.refused_launches);
    ledger["forced_deposits"] = static_cast<std::int64_t>(l.forced_deposits);
    ledger["terrain_contacts"] = static_cast<std::int64_t>(l.terrain_contacts);
    ledger["body_contacts"] = static_cast<std::int64_t>(l.body_contacts);
    ledger["surface_entries"] = static_cast<std::int64_t>(l.surface_entries);
    ledger["ceiling_contacts"] = static_cast<std::int64_t>(l.ceiling_contacts);
    ledger["maximum_live"] = static_cast<std::int64_t>(l.maximum_live);
    d["ledger"] = ledger;
    Dictionary tick;
    tick["launched"] = spray_tick_.launched;
    tick["lifted"] = spray_tick_.lifted;
    tick["budget_hits"] = spray_tick_.budget_hits;
    tick["refused"] = spray_tick_.refused;
    tick["jet"] = spray_tick_.jet;
    tick["jet_refused"] = spray_tick_.jet_refused;
    d["last_coupling"] = tick;
    Dictionary total;
    total["launched"] = spray_total_.launched;
    total["lifted"] = spray_total_.lifted;
    total["budget_hits"] = spray_total_.budget_hits;
    total["refused"] = spray_total_.refused;
    total["jet"] = spray_total_.jet;
    total["jet_refused"] = spray_total_.jet_refused;
    d["totals"] = total;
    return d;
}

PackedFloat64Array CyberNativeCellWorld::inspect_ballistic_parcels(std::int64_t maximum) const {
    PackedFloat64Array out;
    if (world_ == nullptr || maximum <= 0) return out;
    std::vector<cybersand::BallisticParcel> parcels(static_cast<std::size_t>(std::min<std::int64_t>(maximum, 65'536)));
    const auto live = std::min(world_->copy_ballistic_parcels(parcels), parcels.size());
    out.resize(static_cast<std::int64_t>(live * 5U));
    for (std::size_t i = 0; i < live; ++i) {
        const auto& p = parcels[i];
        out.set(static_cast<std::int64_t>(i * 5U), static_cast<double>(p.x) / kSprayQ);
        out.set(static_cast<std::int64_t>(i * 5U + 1U), static_cast<double>(p.y) / kSprayQ);
        out.set(static_cast<std::int64_t>(i * 5U + 2U), static_cast<double>(p.vx) / kSprayQ);
        out.set(static_cast<std::int64_t>(i * 5U + 3U), static_cast<double>(p.vy) / kSprayQ);
        out.set(static_cast<std::int64_t>(i * 5U + 4U), static_cast<double>(p.quantity));
    }
    return out;
}

String CyberNativeCellWorld::inject_water_parcel(Vector2 position, Vector2 velocity, std::int64_t quantity) {
    if (world_ == nullptr) return "world_failed";
    if (!position.is_finite() || !velocity.is_finite() || quantity < 1 || quantity > 255) return "invalid_request";
    const auto maximum = static_cast<std::int64_t>(world_->config().water_experiment_policy.maximum());
    const auto q = world_->whole_cell_water_enabled() ? maximum : std::min(quantity, maximum);
    const auto cap = static_cast<double>(world_->config().ballistic_water.max_speed_q);
    const auto vx = std::clamp(static_cast<double>(velocity.x) * kSprayQ, -cap, cap);
    const auto vy = std::clamp(static_cast<double>(velocity.y) * kSprayQ, -cap, cap);
    const auto result = world_->inject_ballistic_water(
        static_cast<std::int64_t>(std::floor(static_cast<double>(position.x) * kSprayQ)),
        static_cast<std::int64_t>(std::floor(static_cast<double>(position.y) * kSprayQ)),
        static_cast<std::int32_t>(vx), static_cast<std::int32_t>(vy), static_cast<std::uint32_t>(q));
    if (result.outcome == cybersand::BallisticLaunchOutcome::Launched) ++revision_;
    return spray_outcome_id(result.outcome);
}

void CyberNativeCellWorld::water_spray_before_tick() {
    if (world_ == nullptr || world_->has_failed() || !world_->ballistic_water_enabled() || !spray_.jet_enabled)
        return;
    const auto maximum = static_cast<std::int64_t>(world_->config().water_experiment_policy.maximum());
    const auto quantity = world_->whole_cell_water_enabled() ? maximum : std::min(spray_.jet_quantity, maximum);
    const auto cap = static_cast<double>(world_->config().ballistic_water.max_speed_q);
    for (std::int64_t i = 0; i < spray_.jet_rate; ++i) {
        const auto phase = spray_jet_phase_++;
        const double u = spray_hash01(i, static_cast<std::int64_t>(phase), 0x51e7ULL) * 2.0 - 1.0;
        const double w = spray_hash01(static_cast<std::int64_t>(phase), i, 0xa11cULL) * 2.0 - 1.0;
        const double angle = (spray_.jet_angle + u * spray_.jet_spread) * std::numbers::pi / 180.0;
        const double speed = spray_.jet_speed * (1.0 + 0.08 * w) * kSprayQ;
        const auto vx = std::clamp(std::cos(angle) * speed, -cap, cap);
        const auto vy = std::clamp(std::sin(angle) * speed, -cap, cap);
        const auto x = static_cast<std::int64_t>(spray_.jet_origin.x) * cybersand::BallisticWaterConfig::kQ +
                       static_cast<std::int64_t>(64 + 128 * spray_hash01(i, static_cast<std::int64_t>(phase), 7ULL));
        const auto y = static_cast<std::int64_t>(spray_.jet_origin.y) * cybersand::BallisticWaterConfig::kQ + 128;
        const auto r = world_->inject_ballistic_water(x, y, static_cast<std::int32_t>(vx), static_cast<std::int32_t>(vy),
                                                      static_cast<std::uint32_t>(quantity));
        if (r.outcome == cybersand::BallisticLaunchOutcome::Launched) { ++spray_tick_.jet; ++spray_total_.jet; ++revision_; }
        else { ++spray_tick_.jet_refused; ++spray_total_.jet_refused; }
    }
}

// Spawn for a launched overlap cell: an Empty, unmasked cell reached by
// leaving the body sideways (away from its centre line) and then rising
// through the body's own mask and Water. Hard terrain, other bodies and
// foreign materials stop the search: Water never tunnels to the surface.
Vector2i CyberNativeCellWorld::find_spray_lift_spawn(std::int32_t x, std::int32_t y, std::uint16_t body_id,
                                                     std::int32_t lateral) const {
    const auto passable = [&](std::int32_t cx, std::int32_t cy, bool& empty) {
        empty = false;
        if (!in_bounds(cx, cy)) return false;
        const auto mask = world_->transient_obstacle_at(cx, cy);
        if (mask != 0U && mask != body_id) return false;
        const auto material = world_->stored_material(cx, cy);
        if (mask == 0U && material == cybersand::Material::Empty) { empty = true; return true; }
        return material == cybersand::Material::Water || (mask == body_id && material == cybersand::Material::Empty);
    };
    std::int32_t cx = x;
    bool empty = false;
    // Leave the body's own footprint sideways first (bounded by the body size).
    for (std::int32_t step = 0; step < 40 && world_->transient_obstacle_at(cx, y) == body_id; ++step) {
        if (!passable(cx + lateral, y, empty)) break;
        cx += lateral;
        if (empty) return {cx, y};
    }
    for (std::int32_t rise = 1; rise <= spray_.lift_reach; ++rise) {
        if (!passable(cx, y - rise, empty)) return {-1, -1};
        if (empty) return {cx, y - rise};
    }
    return {-1, -1};
}

bool CyberNativeCellWorld::try_water_spray(const BodyState& body, std::uint16_t body_id, std::int32_t x, std::int32_t y,
                                           Vector2 outward, Vector2i target) {
    if (!spray_.enabled || world_ == nullptr || !world_->ballistic_water_enabled()) return false;
    if (spray_budget_used_[body_id] >= spray_.budget) {
        ++spray_tick_.budget_hits;
        ++spray_total_.budget_hits;
        return false;
    }
    const double dt = body.dt > 0.0 ? body.dt : 1.0 / 60.0;
    // Velocity of the body surface at this cell (rigid motion), in cells per tick.
    const Vector2 pivot = workbench_ ? body.com : body.center;
    const double rx = x + 0.5 - static_cast<double>(pivot.x), ry = y + 0.5 - static_cast<double>(pivot.y);
    const double px = (static_cast<double>(body.velocity.x) - body.angular_velocity * ry) * dt;
    const double py = (static_cast<double>(body.velocity.y) + body.angular_velocity * rx) * dt;
    const double push = px * static_cast<double>(outward.x) + py * static_cast<double>(outward.y);
    const bool fast = push >= spray_.threshold;
    const bool submerged = target.x < 0;
    if (!fast && !(submerged && spray_.submerged_lift)) return false;
    const std::int32_t lateral = (x + 0.5 >= static_cast<double>(body.center.x)) ? 1 : -1;
    Vector2i spawn = target;
    if (submerged || fast) {
        // Fast pushes and submerged overlaps rise to the free surface beside
        // the body; an ordinary nearby target is kept for trailing cells.
        const auto lifted = find_spray_lift_spawn(x, y, body_id, lateral);
        if (lifted.x >= 0) spawn = lifted;
    }
    if (spawn.x < 0) return false;
    double vx = 0.0, vy = 0.0;
    const double h1 = spray_hash01(x, y, world_->tick_index() * 0x9e37ULL) * 2.0 - 1.0;
    const double h2 = spray_hash01(y, x, world_->tick_index() * 0x7f4aULL + 3ULL) * 2.0 - 1.0;
    if (fast) {
        const double bias = spray_.upward_bias;
        double dx = static_cast<double>(outward.x) * (1.0 - bias) + lateral * spray_.spread * bias;
        double dy = static_cast<double>(outward.y) * (1.0 - bias) - bias;
        const double angle = h1 * spray_.jitter * 0.6;
        const double c = std::cos(angle), s = std::sin(angle);
        const double rx2 = dx * c - dy * s, ry2 = dx * s + dy * c;
        const double length = std::max(1e-9, std::sqrt(rx2 * rx2 + ry2 * ry2));
        const double speed = spray_.launch_scale * push * (1.0 + 0.5 * spray_.jitter * h2);
        vx = rx2 / length * speed + px * 0.25;
        vy = ry2 / length * speed;
    } else {
        // Slow submerged displacement: a gentle pop onto the surface (level rise).
        vx = lateral * 0.15;
        vy = -0.35;
    }
    const auto cap = static_cast<double>(world_->config().ballistic_water.max_speed_q);
    const auto qx = static_cast<std::int32_t>(std::clamp(vx * kSprayQ, -cap, cap));
    const auto qy = static_cast<std::int32_t>(std::clamp(vy * kSprayQ, -cap, cap));
    const auto result = world_->launch_ballistic_water(x, y,
        static_cast<std::int64_t>(spawn.x) * cybersand::BallisticWaterConfig::kQ + 128,
        static_cast<std::int64_t>(spawn.y) * cybersand::BallisticWaterConfig::kQ + 128,
        qx, qy, body_id);
    if (result.outcome != cybersand::BallisticLaunchOutcome::Launched) {
        ++spray_tick_.refused;
        ++spray_total_.refused;
        return false;
    }
    ++spray_budget_used_[body_id];
    if (fast) { ++spray_tick_.launched; ++spray_total_.launched; }
    else { ++spray_tick_.lifted; ++spray_total_.lifted; }
    if (spray_.reaction_gain > 0.0) {
        // Optional stylized reaction: the body pays for the launched momentum.
        const double share = static_cast<double>(result.quantity) /
                             static_cast<double>(world_->config().water_experiment_policy.maximum());
        record_impulse(body_id, Vector2(static_cast<real_t>(-vx / dt * share * spray_.reaction_gain * 0.01),
                                        static_cast<real_t>(-vy / dt * share * spray_.reaction_gain * 0.01)));
    }
    return true;
}

Vector2 CyberNativeCellWorld::spray_droplet_impulse(std::uint16_t body_id) const {
    if (world_ == nullptr || spray_.droplet_gain <= 0.0) return {};
    return {static_cast<real_t>(static_cast<double>(world_->transient_ballistic_impulse_x(body_id)) * spray_.droplet_gain),
            static_cast<real_t>(static_cast<double>(world_->transient_ballistic_impulse_y(body_id)) * spray_.droplet_gain)};
}
