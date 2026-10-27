// Included inside namespace godot. This value-only facade is intentionally
// diagnostic-only until reactive aggregate coupling and application admission
// are qualified. It never constructs or touches a live Godot/Rapier object.
namespace solid_adapter {
using namespace cybersand::soliding;
String decimal(std::uint64_t n) { return String(std::to_string(n).c_str()); }
String token_text(SolidToken token) {
    return decimal(token.incarnation) + ":" + decimal(token.sequence);
}
bool integer(const Dictionary& input, const char* key, std::int64_t low,
             std::int64_t high, std::int64_t& output) {
    if (!input.has(key) || Variant(input[key]).get_type() != Variant::INT) return false;
    output = static_cast<std::int64_t>(input[key]);
    return output >= low && output <= high;
}
bool text_matches(const Dictionary& input, const char* key, const String& expected) {
    return input.has(key) && Variant(input[key]).get_type() == Variant::STRING &&
        String(input[key]) == expected;
}
bool bounds(const Dictionary& input, const char* key, SolidBounds& output,
            std::int32_t side_limit) {
    if (!input.has(key) || Variant(input[key]).get_type() != Variant::RECT2I) return false;
    const Rect2i value = input[key];
    if (value.position.x < 0 || value.position.y < 0 || value.size.x <= 0 || value.size.y <= 0 ||
        value.size.x > side_limit || value.size.y > side_limit ||
        value.position.x > 1024 - value.size.x || value.position.y > 1024 - value.size.y) return false;
    output = {value.position.x, value.position.y,
        static_cast<std::uint16_t>(value.size.x), static_cast<std::uint16_t>(value.size.y)};
    return true;
}
Dictionary reply(const cybersand::World* world, SolidOutcome outcome, bool payload) {
    static const char* outcomes[] = {"Accepted", "Disabled", "Busy", "Invalid", "Anchored",
        "UnknownBoundary", "NotResident", "Excluded", "Ineligible", "Thermal", "Occupied",
        "PendingEvent", "MemberCapacity", "ShapeCapacity", "Stale", "GenerationExhausted",
        "WorldFailed", "Quarantined"};
    Dictionary result;
    result["schema"] = "cybersand.solid-detachment.diagnostic.v1";
    result["ok"] = outcome == SolidOutcome::Accepted;
    result["outcome"] = outcomes[static_cast<std::size_t>(outcome)];
    if (world == nullptr) return result;
    const auto s = world->inspect_solid_detachment();
    result["phase"] = static_cast<std::int64_t>(s.phase);
    result["token"] = token_text(s.token);
    result["fenced"] = world->solid_detachment_fenced();
    result["source_tick"] = decimal(s.source_tick);
    result["world_tick"] = decimal(world->completed_tick_index());
    result["source_revision"] = decimal(s.source_terrain_revision);
    result["commit_revision"] = decimal(s.committed_terrain_revision);
    result["terrain_revision"] = decimal(world->hard_surface_revision());
    result["payload_digest"] = decimal(s.payload_digest);
    result["shape_digest"] = decimal(s.shape_digest);
    result["member_count"] = static_cast<std::int64_t>(s.member_count);
    result["shape_count"] = static_cast<std::int64_t>(s.shape_count);
    result["aggregate_owned"] = static_cast<std::int64_t>(s.aggregate_owned_count);
    result["body_id"] = static_cast<std::int64_t>(s.body_id);
    result["body_generation"] = decimal(s.body_generation);
    result["mass"] = s.mass;
    result["inertia"] = s.inertia;
    result["center"] = Vector2(static_cast<real_t>(static_cast<double>(s.domain.x) + s.com_x),
        static_cast<real_t>(static_cast<double>(s.domain.y) + s.com_y));
    result["storage_bytes"] = static_cast<std::int64_t>(world->solid_detachment_storage_bytes());
    if (payload && s.member_count != 0) {
        std::array<SolidMember, kSolidMembers> members{};
        std::array<SolidShape, kSolidShapes> shapes{};
        (void)world->copy_solid_detachment_members(members);
        (void)world->copy_solid_detachment_shapes(shapes);
        PackedInt32Array pixels, rectangles;
        pixels.resize(static_cast<std::int64_t>(s.member_count * 6));
        rectangles.resize(static_cast<std::int64_t>(s.shape_count * 4));
        std::size_t still_native = 0;
        for (std::size_t i = 0; i < s.member_count; ++i) {
            const auto& m = members[i];
            const auto p = static_cast<std::int64_t>(i * 6);
            pixels.set(p, static_cast<std::int32_t>(m.x));
            pixels.set(p + 1, static_cast<std::int32_t>(m.y));
            pixels.set(p + 2, static_cast<std::int32_t>(m.material));
            pixels.set(p + 3, m.state_a); pixels.set(p + 4, m.state_b); pixels.set(p + 5, m.temperature);
            if (world->stored_material(m.x, m.y) == m.material &&
                world->stored_state_a(m.x, m.y) == m.state_a &&
                world->stored_state_b(m.x, m.y) == m.state_b &&
                world->stored_temperature(m.x, m.y) == m.temperature) ++still_native;
        }
        for (std::size_t i = 0; i < s.shape_count; ++i) {
            const auto& r = shapes[i]; const auto p = static_cast<std::int64_t>(i * 4);
            rectangles.set(p, static_cast<std::int32_t>(r.x));
            rectangles.set(p + 1, static_cast<std::int32_t>(r.y));
            rectangles.set(p + 2, r.width); rectangles.set(p + 3, r.height);
        }
        result["members"] = pixels;
        result["rectangles"] = rectangles;
        result["native_source_members"] = static_cast<std::int64_t>(still_native);
    }
    return result;
}
} // namespace solid_adapter

bool CyberNativeCellWorld::solid_detachment_fenced() const {
    return world_ != nullptr && world_->solid_detachment_fenced();
}

Dictionary CyberNativeCellWorld::solid_detachment_command(const Dictionary& command) {
    using namespace cybersand::soliding;
    using namespace solid_adapter;
    if (world_ == nullptr || world_->has_failed()) return reply(world_.get(), SolidOutcome::WorldFailed, false);
    if (!diagnostic_fixture_) return reply(world_.get(), SolidOutcome::Ineligible, false);
    if (!command.has("action") || Variant(command["action"]).get_type() != Variant::STRING)
        return reply(world_.get(), SolidOutcome::Invalid, false);
    const String action = command["action"];
    const bool include_payload = action == "prepare" || action == "cut_prepare" || action == "inspect";
    auto outcome = SolidOutcome::Invalid;
    bool cut_applied = false;
    try {
        const auto s = world_->inspect_solid_detachment();
        if (action == "configure") {
            std::int64_t members = 0, shapes = 0;
            if (integer(command, "members", 1, kSolidMembers, members) &&
                integer(command, "shapes", 1, kSolidShapes, shapes))
                outcome = world_->configure_solid_detachment({static_cast<std::size_t>(members), static_cast<std::size_t>(shapes)});
        } else if (action == "prepare" || action == "cut_prepare") {
            SolidRequest request;
            SolidBounds cut;
            if (bounds(command, "domain", request.domain, 64) && bounds(command, "anchors", request.anchors, 1024) &&
                command.has("seed") && Variant(command["seed"]).get_type() == Variant::VECTOR2I &&
                (action != "cut_prepare" || bounds(command, "cut", cut, 16))) {
                const Vector2i seed = command["seed"];
                request.seed_x = seed.x; request.seed_y = seed.y;
                if (action == "cut_prepare") {
                    if (s.phase != SolidPhase::Idle) return reply(world_.get(), SolidOutcome::Busy, false);
                    // An explicit ordinary edit precedes observation. A refused
                    // observation does not undo the owner's intentional cut.
                    cut_applied = diagnostic_fill_rect(Vector2i(static_cast<std::int32_t>(cut.x), static_cast<std::int32_t>(cut.y)),
                        Vector2i(cut.width, cut.height), static_cast<std::int64_t>(cybersand::Material::Empty), 0);
                    if (!cut_applied) return reply(world_.get(), SolidOutcome::Invalid, false);
                }
                outcome = world_->prepare_solid_detachment(request);
            }
        } else if (action == "inspect") {
            outcome = SolidOutcome::Accepted;
        } else if (!text_matches(command, "token", token_text(s.token))) {
            outcome = SolidOutcome::Stale;
        } else if (action == "acknowledge") {
            std::int64_t id = 0, generation = 0, count = 0;
            if (integer(command, "body_id", 1, 64, id) && integer(command, "body_generation", 1, INT64_MAX, generation) &&
                integer(command, "shape_count", 1, kSolidShapes, count) &&
                text_matches(command, "payload_digest", decimal(s.payload_digest)) &&
                text_matches(command, "shape_digest", decimal(s.shape_digest)))
                outcome = world_->acknowledge_solid_detachment({s.token, static_cast<std::uint16_t>(id),
                    static_cast<std::uint64_t>(generation), s.payload_digest, s.shape_digest, static_cast<std::size_t>(count)});
        } else if (action == "commit") {
            outcome = world_->commit_solid_detachment(s.token);
        } else if (action == "cancel") {
            outcome = world_->cancel_solid_detachment(s.token);
        } else if (action == "rollback") {
            outcome = world_->rollback_solid_detachment(token);
        } else if (action == "finalize" || action == "finish_rollback") {
            std::int64_t id = 0, generation = 0, epoch = 0;
            if (integer(command, "body_id", 1, 64, id) && integer(command, "body_generation", 1, INT64_MAX, generation) &&
                integer(command, "physics_epoch", 1, INT64_MAX, epoch) &&
                text_matches(command, "terrain_revision", decimal(s.committed_terrain_revision))) {
                const SolidCollisionReceipt receipt{s.token, static_cast<std::uint16_t>(id),
                    static_cast<std::uint64_t>(generation), s.committed_terrain_revision, static_cast<std::uint64_t>(epoch)};
                outcome = action == "finalize" ? world_->finalize_solid_detachment(receipt)
                    : world_->complete_solid_rollback(receipt);
            }
        }
        if (outcome == SolidOutcome::Accepted && (action == "commit" || action == "rollback")) {
            ++revision_;
            render_snapshot_full_refresh_required_ = true;
        }
    } catch (const std::exception& error) {
        auto result = reply(world_.get(), world_->has_failed() ? SolidOutcome::Quarantined : SolidOutcome::Invalid, false);
        result["error"] = String(error.what());
        return result;
    }
    auto result = reply(world_.get(), outcome, include_payload);
    result["cut_applied"] = cut_applied;
    return result;
}
