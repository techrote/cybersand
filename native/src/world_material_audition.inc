// MAT-AUDITION-LIVE-001. Included after World's private storage definitions.
// This module owns scene-local configuration, never canonical material bytes.
namespace {

std::atomic<std::uint64_t> next_material_audition_world_id{1};

std::uint64_t allocate_material_audition_world_id() {
    auto current = next_material_audition_world_id.load(std::memory_order_relaxed);
    for (;;) {
        if (current == 0 || current == std::numeric_limits<std::uint64_t>::max())
            throw std::overflow_error("material audition World identity space exhausted");
        if (next_material_audition_world_id.compare_exchange_weak(
                current, current + 1U, std::memory_order_relaxed)) return current;
    }
}

std::uint64_t material_audition_default_behavior_hash() noexcept {
    static const auto identity = [] {
        std::uint64_t hash = 1469598103934665603ULL;
        for (const char c : std::string_view{"cybersand.material-audition.behavior.v1"})
            hash_byte(hash, static_cast<std::uint8_t>(c));
        for (const auto& definition : kMaterialDefinitions) hash_integer(hash, definition.density);
        for (const auto& definition : kMaterialDefinitions) hash_integer(hash, definition.viscosity_index);
        for (const auto& rule : kPairInteractionRules) hash_integer(hash, rule.probability);
        return hash;
    }();
    return identity;
}

std::uint64_t material_audition_hash(const MaterialAuditionState& state) noexcept {
    std::uint64_t hash = 1469598103934665603ULL;
    for (const char c : std::string_view{"cybersand.material-audition.behavior.v1"})
        hash_byte(hash, static_cast<std::uint8_t>(c));
    for (const auto value : state.density) hash_integer(hash, value);
    for (const auto value : state.viscosity) hash_integer(hash, value);
    for (const auto value : state.probability_threshold) hash_integer(hash, value);
    return hash;
}

bool valid_material_audition_id(std::string_view name) noexcept {
    if (name.empty() || name.size() > MaterialAuditionProfile::kMaximumProfileIdBytes) return false;
    for (const auto c : name) {
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
              (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.')) return false;
    }
    return true;
}

std::int64_t material_audition_cell_coordinate(
    std::int64_t chunk, std::int32_t width, std::size_t local) noexcept {
    // A partially addressable extreme chunk can have a mathematical origin
    // outside int64 even though an authored cell within it is representable.
    // Unsigned reconstruction avoids an overflowing signed intermediate.
    const auto bits = static_cast<std::uint64_t>(chunk) * static_cast<std::uint64_t>(width) +
                      static_cast<std::uint64_t>(local);
    return std::bit_cast<std::int64_t>(bits);
}

}  // namespace

MaterialAuditionProfile World::material_audition_profile() const {
    return material_audition_ == nullptr ? MaterialAuditionProfile{} : material_audition_->profile;
}

std::uint64_t World::material_audition_behavior_hash() const noexcept {
    return material_audition_ == nullptr ? material_audition_default_behavior_hash()
                                          : material_audition_->behavior_hash;
}

std::uint16_t World::material_audition_effective_density(Material material) const noexcept {
    const auto id = static_cast<std::size_t>(material);
    return material_audition_ != nullptr && id < material_audition_->density.size()
        ? material_audition_->density[id] : MaterialRules::descriptor(material).density;
}

std::uint8_t World::material_audition_effective_viscosity(Material material) const noexcept {
    // Preserve the pre-existing immutable diagnostic owner; a conflicting
    // scene-local Mercury viscosity request is refused during admission below.
    if (material == Material::Mercury && config_.physics_diagnostics.mercury_viscosity >= 0)
        return static_cast<std::uint8_t>(config_.physics_diagnostics.mercury_viscosity);
    const auto id = static_cast<std::size_t>(material);
    return material_audition_ != nullptr && id < material_audition_->viscosity.size()
        ? material_audition_->viscosity[id] : MaterialRules::descriptor(material).viscosity_index;
}

std::uint8_t World::material_audition_effective_probability(std::size_t slot) const noexcept {
    if (slot >= kPairInteractionRules.size()) return 0;
    return material_audition_ == nullptr ? kPairInteractionRules[slot].probability
                                          : material_audition_->probability_threshold[slot];
}

bool World::material_audition_probability_available(std::size_t slot) const noexcept {
    if (slot >= kPairInteractionRules.size()) return false;
    const auto can_initiate = [this](Material material) {
        const auto& definition = MaterialRules::descriptor(material);
        return definition.valid && definition.current_rule_available && definition.kernel != RuleKernel::None &&
               !(material == Material::Water && wave_ != nullptr);
    };
    const auto& rule = kPairInteractionRules[slot];
    // Actual contact still requires active state, an eligible temporal lane and
    // visible unmasked neighbours. This only establishes that a consumer can
    // exist in the current World. Wave Water plus an inert solid has none.
    return can_initiate(rule.first) || can_initiate(rule.second);
}

bool World::material_audition_can_density_exchange(
    Material source, Material target, std::int64_t vertical_delta) const noexcept {
    if (material_audition_ == nullptr || !material_audition_->density_changed)
        return MaterialRules::can_density_exchange(source, target, vertical_delta);
    if (vertical_delta == 0) return false;
    const auto& source_definition = MaterialRules::descriptor(source);
    const auto& target_definition = MaterialRules::descriptor(target);
    // These are the retained canonical admission laws, with only the two
    // numeric comparison values routed through the World-owned overlay.
    if (source_definition.state == MaterialState::Powder &&
        target_definition.state == MaterialState::Powder) return false;
    if (source == Material::Oil && target_definition.state == MaterialState::Powder) return false;
    if (!source_definition.valid || !target_definition.valid ||
        !target_definition.current_rule_available || !target_definition.accepts_density_exchange)
        return false;
    if (vertical_delta > 0)
        return source_definition.density_motion == DensityMotion::Down &&
               material_audition_effective_density(source) > material_audition_effective_density(target);
    return source_definition.density_motion == DensityMotion::Up &&
           material_audition_effective_density(source) < material_audition_effective_density(target);
}

std::optional<PairReactionResult> World::material_audition_pair_reaction(
    Material source, Material target, std::uint8_t probability_roll) const noexcept {
    if (material_audition_ == nullptr || !material_audition_->reactions_changed)
        return MaterialRules::pair_reaction(source, target, probability_roll);
    // Zero is still 1/256, so every authored rule can be discovered at roll0.
    // The existing cached first match remains the role/product authority.
    const auto authored = MaterialRules::pair_reaction(source, target, 0U);
    if (!authored || probability_roll > material_audition_->probability_threshold[authored->rule_index])
        return std::nullopt;
    return authored;
}

MaterialAuditionResult World::apply_material_audition(
    std::uint64_t expected_world_id, std::uint64_t expected_revision,
    const MaterialAuditionProfile& profile) noexcept {
    MaterialAuditionResult result;
    result.world_id = material_audition_world_id_.value;
    result.prior_revision = material_audition_revision_;
    result.revision = material_audition_revision_;
    result.behavior_hash = material_audition_behavior_hash();
    const auto refuse = [&](MaterialAuditionOutcome outcome, std::string_view reason,
                            std::string_view field = {}, std::int32_t index = -1) {
        result.outcome = outcome;
        result.reason = reason;
        result.field = field;
        result.index = index;
        return result;
    };
    if (expected_world_id == 0 || expected_world_id != material_audition_world_id_.value)
        return refuse(MaterialAuditionOutcome::WorldMismatch, "World identity changed or retired");
    if (expected_revision != material_audition_revision_)
        return refuse(MaterialAuditionOutcome::StaleRevision, "configuration revision changed");
    if (tick_failed_) return refuse(MaterialAuditionOutcome::WorldFailed, "World is quarantined");
    if (tick_in_progress_)
        return refuse(MaterialAuditionOutcome::TickInProgress, "configuration requires a serialized tick boundary");
    if (material_audition_revision_ == std::numeric_limits<std::uint64_t>::max())
        return refuse(MaterialAuditionOutcome::RevisionExhausted, "configuration revision space exhausted");
    if (profile.schema_version != MaterialAuditionProfile::kSchemaVersion)
        return refuse(MaterialAuditionOutcome::InvalidProfile, "unsupported material profile schema", "schema_version");
    if (!valid_material_audition_id(profile.profile_id))
        return refuse(MaterialAuditionOutcome::InvalidProfile, "profile_id must be 1..64 ASCII letters, digits, dot, hyphen or underscore", "profile_id");

    for (std::size_t id = 0; id < kMaterialDefinitions.size(); ++id) {
        const auto material = static_cast<Material>(id);
        if (profile.density[id] != -1) {
            if (!material_audition_supports_density(material))
                return refuse(MaterialAuditionOutcome::UnsupportedProperty, "material has no admitted directional density-exchange consumer", "density", static_cast<std::int32_t>(id));
            if (profile.density[id] < 1 || profile.density[id] > 65535)
                return refuse(MaterialAuditionOutcome::InvalidValue, "density must be an integer in 1..65535", "density", static_cast<std::int32_t>(id));
        }
        if (profile.viscosity[id] != -1) {
            if (!material_audition_supports_viscosity(material))
                return refuse(MaterialAuditionOutcome::UnsupportedProperty, "descriptor viscosity is not consumed by an admitted generic liquid kernel", "viscosity", static_cast<std::int32_t>(id));
            if (material == Material::Mercury && config_.physics_diagnostics.mercury_viscosity >= 0)
                return refuse(MaterialAuditionOutcome::UnsupportedProperty, "immutable Mercury diagnostic viscosity owns this consumer", "viscosity", static_cast<std::int32_t>(id));
            if (inertial_materials_[id])
                return refuse(MaterialAuditionOutcome::UnsupportedProperty, "inertial solver owns this material's motion", "viscosity", static_cast<std::int32_t>(id));
            if (profile.viscosity[id] < 0 || profile.viscosity[id] > 255)
                return refuse(MaterialAuditionOutcome::InvalidValue, "viscosity must be an integer in 0..255", "viscosity", static_cast<std::int32_t>(id));
        }
    }
    for (std::size_t slot = 0; slot < kPairInteractionRules.size(); ++slot) {
        if (profile.probability_threshold[slot] != -1 && !material_audition_probability_available(slot))
            return refuse(MaterialAuditionOutcome::UnsupportedProperty,
                "neither endpoint has an executable compact-pair initiator in this World", "probability_threshold", static_cast<std::int32_t>(slot));
        if (profile.probability_threshold[slot] < -1 || profile.probability_threshold[slot] > 255)
            return refuse(MaterialAuditionOutcome::InvalidValue, "probability threshold must be an integer in 0..255; zero means 1/256", "probability_threshold", static_cast<std::int32_t>(slot));
    }

    try {
        auto candidate = std::make_unique<MaterialAuditionState>();
        candidate->profile = profile;
        std::array<bool, 256> affected{};
        bool behavior_changed = false;
        for (std::size_t id = 0; id < kMaterialDefinitions.size(); ++id) {
            const auto material = static_cast<Material>(id);
            const auto& definition = kMaterialDefinitions[id];
            candidate->density[id] = profile.density[id] == -1 ? definition.density
                : static_cast<std::uint16_t>(profile.density[id]);
            candidate->viscosity[id] = profile.viscosity[id] == -1 ? definition.viscosity_index
                : static_cast<std::uint8_t>(profile.viscosity[id]);
            candidate->density_changed |= candidate->density[id] != definition.density;
            candidate->viscosity_changed |= candidate->viscosity[id] != definition.viscosity_index;
            // The Mercury diagnostic is separately immutable. Compare stored
            // descriptor overlays here so a diagnostic default is a no-op.
            const auto old_viscosity = material_audition_ == nullptr ? definition.viscosity_index
                                                                   : material_audition_->viscosity[id];
            affected[id] = candidate->density[id] != material_audition_effective_density(material) ||
                           candidate->viscosity[id] != old_viscosity;
            behavior_changed |= affected[id];
        }
        for (std::size_t slot = 0; slot < kPairInteractionRules.size(); ++slot) {
            const auto& rule = kPairInteractionRules[slot];
            candidate->probability_threshold[slot] = profile.probability_threshold[slot] == -1 ? rule.probability
                : static_cast<std::uint8_t>(profile.probability_threshold[slot]);
            candidate->reactions_changed |= candidate->probability_threshold[slot] != rule.probability;
            if (candidate->probability_threshold[slot] != material_audition_effective_probability(slot)) {
                affected[static_cast<std::uint8_t>(rule.first)] = true;
                affected[static_cast<std::uint8_t>(rule.second)] = true;
                behavior_changed = true;
            }
        }
        candidate->behavior_hash = material_audition_hash(*candidate);
        if (behavior_changed) {
            std::uint64_t scan_cells = 0;
            for (const auto& [coord, chunk] : chunks_) {
                (void)coord;
                if (chunk->non_empty_cell_count == 0) continue;
                if (chunk->cells.size() > MaterialAuditionProfile::kMaximumWakeScanCells - scan_cells)
                    return refuse(MaterialAuditionOutcome::CapacityExceeded,
                        "resident nonempty chunks exceed the 16 Mi-cell audition scan capacity");
                scan_cells += static_cast<std::uint64_t>(chunk->cells.size());
            }
            result.scanned_cells = scan_cells;
        }

        // All refusing/allocation paths have completed. Publish one immutable
        // table snapshot, then wake only affected cells' existing activity blocks
        // and boundary neighbours. No cells, clocks, renderer or solver law are
        // replaced. No dirty rectangle is manufactured for a parameter change.
        material_audition_.swap(candidate);
        ++material_audition_revision_;
        if (behavior_changed) {
            std::uint64_t inactive_before = 0;
            for (const auto& [coord, chunk] : chunks_) {
                (void)coord;
                for (const auto& block : chunk->activity_blocks) inactive_before += !block.active;
            }
            for (const auto& [coord, chunk] : chunks_) {
                if (chunk->non_empty_cell_count == 0) continue;
                const auto width = static_cast<std::size_t>(config_.chunk_size);
                // Chunk origins admitted by set/reserve/install are representable.
                for (std::size_t at = 0; at < chunk->cells.size(); ++at) {
                    if (!affected[static_cast<std::uint8_t>(chunk->cells[at].material_value())]) continue;
                    const auto x = material_audition_cell_coordinate(coord.x, config_.chunk_size, at % width);
                    const auto y = material_audition_cell_coordinate(coord.y, config_.chunk_size, at / width);
                    keep_cell_active(x, y, nullptr);
                    wake_cell_neighborhood(x, y);
                }
            }
            std::uint64_t inactive_after = 0;
            for (const auto& [coord, chunk] : chunks_) {
                (void)coord;
                for (const auto& block : chunk->activity_blocks) inactive_after += !block.active;
            }
            result.woken_blocks = inactive_before - inactive_after;
        }
        result.outcome = MaterialAuditionOutcome::Applied;
        result.reason = behavior_changed ? "scene-local configuration activated; simulation consequences retained"
                                         : "equivalent configuration recorded; no simulation wake required";
        result.revision = material_audition_revision_;
        result.behavior_hash = material_audition_behavior_hash();
        return result;
    } catch (const std::bad_alloc&) {
        return refuse(MaterialAuditionOutcome::AllocationFailed, "configuration allocation failed before activation");
    }
}
