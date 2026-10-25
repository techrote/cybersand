// Included after World/Chunk/JobEffects definitions. This schema is independent
// of the pressure-family momentum and gas ledgers.
namespace {

static_assert(kPairInteractionRules.size() == kQuantityPairRuleSlots);
static_assert(kSpecializedInteractionRules.size() == kQuantityKernelRuleSlots);

std::uint64_t quantity_add(std::uint64_t a, std::uint64_t b) {
    if (b > std::numeric_limits<std::uint64_t>::max() - a)
        throw std::overflow_error("quantity ledger unsigned overflow");
    return a + b;
}

std::uint64_t quantity_apply(std::uint64_t value, std::int64_t delta) {
    if (delta >= 0) return quantity_add(value, static_cast<std::uint64_t>(delta));
    const auto loss = static_cast<std::uint64_t>(-(delta + 1)) + 1U;
    if (loss > value) throw std::logic_error("quantity ledger unsigned underflow");
    return value - loss;
}

void quantity_delta_add(std::int64_t& target, std::int64_t delta, bool& overflow) noexcept {
    if ((delta > 0 && target > std::numeric_limits<std::int64_t>::max() - delta) ||
        (delta < 0 && target < std::numeric_limits<std::int64_t>::min() - delta)) {
        overflow = true;
        return;
    }
    target += delta;
}

void quantity_flow_add(WaterQuantityFlow& target, const WaterQuantityFlow& delta) {
    const auto produced = quantity_add(target.produced, delta.produced);
    const auto consumed = quantity_add(target.consumed, delta.consumed);
    target = {produced, consumed};
}

std::uint16_t quantity_kernel_rule(RuleKernel kernel) noexcept {
    for (std::size_t i = 0; i < kSpecializedInteractionRules.size(); ++i)
        if (kSpecializedInteractionRules[i].kernel == kernel) return static_cast<std::uint16_t>(i);
    return kQuantityNoRule;
}

void quantity_validate_seed(const QuantityConstructionSeed& seed) {
    if (quantity_add(seed.baseline_water, seed.normalization_produced) !=
        quantity_add(seed.expected_final_water, seed.normalization_consumed))
        throw std::invalid_argument("quantity construction normalization does not close");
    if (!seed.normalization_receipt_digest &&
        (seed.normalization_produced != 0U || seed.normalization_consumed != 0U ||
         seed.baseline_water != seed.expected_final_water ||
         seed.original_setup_identity != seed.prepared_setup_identity ||
         seed.original_payload_digest != seed.prepared_payload_digest))
        throw std::invalid_argument("quantity construction has unbound normalization");
}

template<class Writer> void quantity_write(Writer& out, const QuantityLedgerSnapshot& value) {
    out.put(value.schema_version);
    out.put(value.mass_bits);
    out.put(value.baseline_water);
    out.put(value.water_visible);
    out.put(value.water_overfill);
    const auto flow = [&](const auto& items) {
        for (const auto& item : items) { out.put(item.produced); out.put(item.consumed); }
    };
    flow(value.kinds); flow(value.pair_rules);
    for (const auto count : value.pair_events) out.put(count);
    flow(value.kernel_rules);
    for (const auto count : value.material_cells) out.put(count);
    for (const auto count : value.prepared_material_cells) out.put(count);
    out.put(static_cast<std::uint8_t>(value.construction.has_value()));
    if (value.construction) {
        const auto& seed = *value.construction;
        out.put(seed.mass_bits);
        out.put(seed.baseline_water);
        out.put(seed.normalization_produced); out.put(seed.normalization_consumed);
        out.put(seed.expected_final_water);
        for (const auto* digest : {&seed.original_setup_identity, &seed.prepared_setup_identity,
                                  &seed.original_payload_digest, &seed.prepared_payload_digest})
            for (auto byte : *digest) out.put(byte);
        out.put(static_cast<std::uint8_t>(seed.normalization_receipt_digest.has_value()));
        if (seed.normalization_receipt_digest)
            for (auto byte : *seed.normalization_receipt_digest) out.put(byte);
    }
}

template<class Reader> QuantityLedgerSnapshot quantity_read(Reader& in) {
    QuantityLedgerSnapshot value;
    value.schema_version = in.template get<std::uint16_t>();
    if (value.schema_version != kQuantityLedgerSchemaVersion)
        throw std::invalid_argument("unknown quantity accounting schema");
    value.mass_bits = in.template get<std::uint8_t>();
    value.baseline_water = in.template get<std::uint64_t>();
    value.water_visible = in.template get<std::uint64_t>();
    value.water_overfill = in.template get<std::uint64_t>();
    const auto flow = [&](auto& items) {
        for (auto& item : items) {
            item.produced = in.template get<std::uint64_t>();
            item.consumed = in.template get<std::uint64_t>();
        }
    };
    flow(value.kinds); flow(value.pair_rules);
    for (auto& count : value.pair_events) count = in.template get<std::uint64_t>();
    flow(value.kernel_rules);
    for (auto& count : value.material_cells) count = in.template get<std::uint64_t>();
    for (auto& count : value.prepared_material_cells) count = in.template get<std::uint64_t>();
    const auto present = in.template get<std::uint8_t>();
    if (present > 1U) throw std::invalid_argument("invalid quantity construction shape");
    if (present != 0U) {
        QuantityConstructionSeed seed;
        seed.mass_bits = in.template get<std::uint8_t>();
        seed.baseline_water = in.template get<std::uint64_t>();
        seed.normalization_produced = in.template get<std::uint64_t>();
        seed.normalization_consumed = in.template get<std::uint64_t>();
        seed.expected_final_water = in.template get<std::uint64_t>();
        for (auto* digest : {&seed.original_setup_identity, &seed.prepared_setup_identity,
                            &seed.original_payload_digest, &seed.prepared_payload_digest})
            for (auto& byte : *digest) byte = in.template get<std::uint8_t>();
        const auto normalized = in.template get<std::uint8_t>();
        if (normalized > 1U) throw std::invalid_argument("invalid normalization digest shape");
        if (normalized != 0U) {
            QuantityDigest digest;
            for (auto& byte : digest) byte = in.template get<std::uint8_t>();
            seed.normalization_receipt_digest = digest;
        }
        quantity_validate_seed(seed);
        value.construction = seed;
    }
    return value;
}

struct QuantityHashWriter {
    std::uint64_t& hash;
    template<class Integer> void put(Integer value) { hash_integer(hash, value); }
};

} // namespace

void World::reset_quantity_ledger() noexcept {
    quantity_ = {};
    quantity_.mass_bits = config_.water_experiment_policy.mass_bits();
}

QuantityLedgerSnapshot World::quantity_ledger() const {
    require_healthy();
    if (tick_in_progress_) throw std::logic_error("cannot read quantity ledger during tick");
    validate_quantity_ledger(false);
    return quantity_;
}

void World::initialize_quantity_ledger(const QuantityConstructionSeed& seed) {
    require_healthy();
    if (tick_in_progress_ || tick_index_ != 0U || completed_tick_index_ != 0U ||
        !pending_explosions_.empty() || quantity_.construction)
        throw std::logic_error("quantity construction initialization requires a fresh t0 candidate");
    quantity_validate_seed(seed);
    validate_quantity_ledger(true);
    if (seed.mass_bits != quantity_.mass_bits ||
        seed.expected_final_water != quantity_add(quantity_.water_visible, quantity_.water_overfill))
        throw std::invalid_argument("quantity construction does not match actual World");
    auto initialized = quantity_;
    initialized.baseline_water = seed.baseline_water;
    initialized.kinds = {};
    initialized.pair_rules = {};
    initialized.pair_events = {};
    initialized.kernel_rules = {};
    initialized.prepared_material_cells = quantity_.material_cells;
    initialized.kinds[static_cast<std::size_t>(QuantityKind::SetupNormalization)] =
        {seed.normalization_produced, seed.normalization_consumed};
    initialized.construction = seed;
    quantity_ = initialized;
}

void World::record_quantity_transition(Material before, std::uint16_t before_visible,
    std::uint16_t before_overfill, Material after, std::uint16_t after_visible,
    std::uint16_t after_overfill, JobEffects* effects, QuantityCause cause,
    bool source_sink, bool reaction_product) {
    const auto old_visible = before == Material::Water ? before_visible : std::uint16_t{0};
    const auto new_visible = after == Material::Water ? after_visible : std::uint16_t{0};
    const auto old_overfill = before == Material::Water ? before_overfill : std::uint16_t{0};
    const auto new_overfill = after == Material::Water ? after_overfill : std::uint16_t{0};
    const auto old_quantity = static_cast<std::uint64_t>(old_visible) + old_overfill;
    const auto new_quantity = static_cast<std::uint64_t>(new_visible) + new_overfill;
    WaterQuantityFlow flow;
    if (source_sink) {
        if (reaction_product) flow = {new_quantity, old_quantity};
        else if (new_quantity >= old_quantity) flow.produced = new_quantity - old_quantity;
        else flow.consumed = old_quantity - new_quantity;
    }
    if (effects == nullptr) {
        // A serial write touches two quantities, at most two populations and
        // one cause/rule. Check those candidates before committing any of them;
        // do not initialize job scratch or copy/scan the full ledger per cell.
        const auto visible = quantity_apply(quantity_.water_visible,
            static_cast<std::int64_t>(new_visible) - old_visible);
        const auto overfill = quantity_apply(quantity_.water_overfill,
            static_cast<std::int64_t>(new_overfill) - old_overfill);
        const bool remove_cell = before != after && before != Material::Empty;
        const bool add_cell = before != after && after != Material::Empty;
        const auto before_slot = static_cast<std::uint8_t>(before);
        const auto after_slot = static_cast<std::uint8_t>(after);
        const auto before_count = remove_cell
            ? quantity_apply(quantity_.material_cells[before_slot], -1) : 0U;
        const auto after_count = add_cell
            ? quantity_add(quantity_.material_cells[after_slot], 1) : 0U;
        const bool has_flow = flow.produced != 0U || flow.consumed != 0U;
        auto kind = kQuantityKindCount;
        WaterQuantityFlow next_kind;
        WaterQuantityFlow next_rule;
        WaterQuantityFlow* rule = nullptr;
        if (has_flow) {
            kind = static_cast<std::size_t>(cause.kind);
            if (kind >= kQuantityKindCount || cause.kind == QuantityKind::SetupNormalization)
                throw std::logic_error("invalid runtime quantity cause");
            next_kind = quantity_.kinds[kind];
            quantity_flow_add(next_kind, flow);
            if (cause.kind == QuantityKind::PairReaction) {
                if (cause.rule >= quantity_.pair_rules.size())
                    throw std::logic_error("invalid quantity pair rule");
                rule = &quantity_.pair_rules[cause.rule];
            } else if (cause.kind == QuantityKind::KernelConversion) {
                if (cause.rule >= quantity_.kernel_rules.size())
                    throw std::logic_error("unclassified Water conversion");
                rule = &quantity_.kernel_rules[cause.rule];
            }
            if (rule != nullptr) {
                next_rule = *rule;
                quantity_flow_add(next_rule, flow);
            }
        }
        if (has_flow || visible != quantity_.water_visible || overfill != quantity_.water_overfill) {
            // Preserve the full merge's lifetime-total bounds even when each
            // category separately fits. Paired transport may temporarily open
            // conservation, so only representability is checked here.
            auto produced = quantity_.baseline_water;
            auto consumed = quantity_add(visible, overfill);
            for (std::size_t i = 0; i < quantity_.kinds.size(); ++i) {
                const auto& candidate = i == kind ? next_kind : quantity_.kinds[i];
                produced = quantity_add(produced, candidate.produced);
                consumed = quantity_add(consumed, candidate.consumed);
            }
        }
        quantity_.water_visible = visible;
        quantity_.water_overfill = overfill;
        if (remove_cell) quantity_.material_cells[before_slot] = before_count;
        if (add_cell) quantity_.material_cells[after_slot] = after_count;
        if (has_flow) quantity_.kinds[kind] = next_kind;
        if (rule != nullptr) *rule = next_rule;
        return;
    }
    auto& delta = effects->quantity;
    quantity_delta_add(delta.visible, static_cast<std::int64_t>(new_visible) - old_visible, delta.overflow);
    quantity_delta_add(delta.overfill, static_cast<std::int64_t>(new_overfill) - old_overfill, delta.overflow);
    if (before != after) {
        if (before != Material::Empty)
            quantity_delta_add(delta.material_cells[static_cast<std::uint8_t>(before)], -1, delta.overflow);
        if (after != Material::Empty)
            quantity_delta_add(delta.material_cells[static_cast<std::uint8_t>(after)], 1, delta.overflow);
    }
    try {
        if (flow.produced != 0U || flow.consumed != 0U) {
            const auto kind = static_cast<std::size_t>(cause.kind);
            if (kind >= kQuantityKindCount || cause.kind == QuantityKind::SetupNormalization)
                throw std::logic_error("invalid runtime quantity cause");
            quantity_flow_add(delta.kinds[kind], flow);
            if (cause.kind == QuantityKind::PairReaction) {
                if (cause.rule >= delta.pair_rules.size()) throw std::logic_error("invalid quantity pair rule");
                quantity_flow_add(delta.pair_rules[cause.rule], flow);
            } else if (cause.kind == QuantityKind::KernelConversion) {
                if (cause.rule >= delta.kernel_rules.size()) throw std::logic_error("unclassified Water conversion");
                quantity_flow_add(delta.kernel_rules[cause.rule], flow);
            }
        }
    } catch (const std::overflow_error&) { delta.overflow = true; }
}

void World::record_quantity_pair_event(std::uint16_t rule, JobEffects* effects) {
    if (rule >= kQuantityPairRuleSlots) throw std::logic_error("invalid quantity pair rule");
    if (effects == nullptr) quantity_.pair_events[rule] = quantity_add(quantity_.pair_events[rule], 1);
    else if (effects->quantity.pair_events[rule] == std::numeric_limits<std::uint64_t>::max())
        effects->quantity.overflow = true;
    else ++effects->quantity.pair_events[rule];
}

void World::preflight_generated_quantity(std::span<const Material> materials) {
    JobEffects check;
    for (const auto material : materials)
        if (material != Material::Empty)
            record_quantity_transition(Material::Empty, 0, 0, material,
                material == Material::Water ? config_.water_experiment_policy.maximum() : std::uint16_t{0},
                0, &check, {QuantityKind::GeneratedChunk, kQuantityNoRule});
    merge_quantity_effects(check, false);
}

void World::preflight_absent_quantity(Material material, std::uint16_t visible,
                                     QuantityCause cause) {
    JobEffects check;
    record_quantity_transition(Material::Empty, 0, 0, material, visible, 0, &check, cause);
    merge_quantity_effects(check, false);
}

void World::merge_quantity_effects(const JobEffects& effects, bool commit) {
    const auto& delta = effects.quantity;
    if (delta.overflow) throw std::overflow_error("quantity job accounting overflow");
    // Preflight on a bounded value copy: external refusal cannot partially book.
    auto next = quantity_;
    next.water_visible = quantity_apply(next.water_visible, delta.visible);
    next.water_overfill = quantity_apply(next.water_overfill, delta.overfill);
    for (std::size_t i = 0; i < next.material_cells.size(); ++i)
        next.material_cells[i] = quantity_apply(next.material_cells[i], delta.material_cells[i]);
    for (std::size_t i = 0; i < next.kinds.size(); ++i) quantity_flow_add(next.kinds[i], delta.kinds[i]);
    for (std::size_t i = 0; i < next.pair_rules.size(); ++i) {
        quantity_flow_add(next.pair_rules[i], delta.pair_rules[i]);
        next.pair_events[i] = quantity_add(next.pair_events[i], delta.pair_events[i]);
    }
    for (std::size_t i = 0; i < next.kernel_rules.size(); ++i)
        quantity_flow_add(next.kernel_rules[i], delta.kernel_rules[i]);
    // Lifetime source/sink totals must remain representable even when every
    // individual category still fits. Conservation may be temporarily open
    // inside a paired transport, so equality is checked only at boundaries.
    auto produced = next.baseline_water;
    auto consumed = quantity_add(next.water_visible, next.water_overfill);
    for (const auto& flow : next.kinds) {
        produced = quantity_add(produced, flow.produced);
        consumed = quantity_add(consumed, flow.consumed);
    }
    if (commit) quantity_ = next;
}

void World::validate_quantity_ledger(bool scan_authority) const {
    if (quantity_.schema_version != kQuantityLedgerSchemaVersion ||
        quantity_.mass_bits != config_.water_experiment_policy.mass_bits())
        throw std::invalid_argument("quantity accounting identity mismatch");
    std::uint64_t produced = quantity_.baseline_water;
    std::uint64_t consumed = quantity_add(quantity_.water_visible, quantity_.water_overfill);
    for (const auto& flow : quantity_.kinds) {
        produced = quantity_add(produced, flow.produced);
        consumed = quantity_add(consumed, flow.consumed);
    }
    if (produced != consumed) throw std::invalid_argument("Water quantity ledger does not close");
    for (const auto kind : {QuantityKind::PairReaction, QuantityKind::KernelConversion}) {
        WaterQuantityFlow total;
        if (kind == QuantityKind::PairReaction)
            for (const auto& flow : quantity_.pair_rules) quantity_flow_add(total, flow);
        else for (const auto& flow : quantity_.kernel_rules) quantity_flow_add(total, flow);
        if (total != quantity_.kinds[static_cast<std::size_t>(kind)])
            throw std::invalid_argument("quantity rule totals do not match kind");
    }
    if (quantity_.kinds[static_cast<std::size_t>(QuantityKind::GeneratedChunk)].consumed != 0U ||
        quantity_.kinds[static_cast<std::size_t>(QuantityKind::DeferredEvent)].produced != 0U)
        throw std::invalid_argument("quantity kind has an impossible Water role");
    const auto maximum = static_cast<std::uint64_t>(config_.water_experiment_policy.maximum());
    for (std::size_t i = 0; i < kSpecializedInteractionRules.size(); ++i) {
        const auto kernel = kSpecializedInteractionRules[i].kernel;
        const bool produces = kernel == RuleKernel::Steam || kernel == RuleKernel::Lava ||
            kernel == RuleKernel::Ice || kernel == RuleKernel::Cloner || kernel == RuleKernel::Rocket;
        const bool consumes = kernel == RuleKernel::Metal || kernel == RuleKernel::Ice ||
            kernel == RuleKernel::Acid || kernel == RuleKernel::Plant;
        const auto& flow = quantity_.kernel_rules[i];
        if ((!produces && flow.produced != 0U) || (!consumes && flow.consumed != 0U) ||
            flow.produced % maximum != 0U)
            throw std::invalid_argument("quantity kernel has an impossible Water role or quantum");
    }
    for (std::size_t i = 0; i < kPairInteractionRules.size(); ++i) {
        const auto& rule = kPairInteractionRules[i];
        const auto inputs = static_cast<std::uint64_t>(rule.first == Material::Water) +
                            static_cast<std::uint64_t>(rule.second == Material::Water);
        const auto outputs = static_cast<std::uint64_t>(rule.first_product == Material::Water) +
                             static_cast<std::uint64_t>(rule.second_product == Material::Water);
        const auto events = quantity_.pair_events[i];
        const auto output_each = outputs * maximum;
        if (output_each != 0U && events > std::numeric_limits<std::uint64_t>::max() / output_each)
            throw std::invalid_argument("quantity reaction product count overflow");
        if (quantity_.pair_rules[i].produced != events * output_each)
            throw std::invalid_argument("quantity reaction product total inconsistent");
        if (inputs == 0U) {
            if (quantity_.pair_rules[i].consumed != 0U)
                throw std::invalid_argument("quantity reaction consumed absent Water");
        } else {
            if (events > std::numeric_limits<std::uint64_t>::max() / inputs ||
                quantity_.pair_rules[i].consumed < events * inputs)
                throw std::invalid_argument("quantity reaction input total inconsistent");
            const auto input_bound = inputs * maximum * 2U;
            if (events <= std::numeric_limits<std::uint64_t>::max() / input_bound &&
                quantity_.pair_rules[i].consumed > events * input_bound)
                throw std::invalid_argument("quantity reaction input exceeds cell bound");
        }
    }
    if (quantity_.construction) {
        const auto& seed = *quantity_.construction;
        quantity_validate_seed(seed);
        if (seed.mass_bits != quantity_.mass_bits || seed.baseline_water != quantity_.baseline_water ||
            quantity_.kinds[0] != WaterQuantityFlow{seed.normalization_produced, seed.normalization_consumed})
            throw std::invalid_argument("quantity construction binding mismatch");
        const auto prepared_water = quantity_.prepared_material_cells[static_cast<std::uint8_t>(Material::Water)];
        if (prepared_water > std::numeric_limits<std::uint64_t>::max() / maximum ||
            seed.expected_final_water < prepared_water || seed.expected_final_water > prepared_water * maximum ||
            ((seed.normalization_receipt_digest || whole_cell_water_enabled()) &&
             seed.expected_final_water != prepared_water * maximum))
            throw std::invalid_argument("quantity prepared Water population does not match initial mass");
    } else if (quantity_.baseline_water != 0U || quantity_.kinds[0] != WaterQuantityFlow{}) {
        throw std::invalid_argument("unbound quantity construction baseline");
    }
    auto cell_bound = static_cast<std::uint64_t>(config_.chunk_size) *
                      static_cast<std::uint64_t>(config_.chunk_size);
    if (config_.maximum_chunk_count > std::numeric_limits<std::uint64_t>::max() / cell_bound)
        throw std::invalid_argument("quantity cell capacity exceeds integer domain");
    cell_bound *= config_.maximum_chunk_count;
    std::uint64_t prepared_cells = 0;
    for (const auto count : quantity_.prepared_material_cells)
        prepared_cells = quantity_add(prepared_cells, count);
    if (prepared_cells > cell_bound || (!quantity_.construction && prepared_cells != 0U))
        throw std::invalid_argument("quantity prepared cell count out of bounds");
    for (std::size_t i = 0; i < quantity_.material_cells.size(); ++i)
        if ((i == 0U || !valid_material(static_cast<std::uint16_t>(i))) &&
            (quantity_.material_cells[i] != 0U || quantity_.prepared_material_cells[i] != 0U))
            throw std::invalid_argument("invalid material population slot");
    if (!scan_authority) return;
    std::uint64_t visible = 0, overfill = 0;
    std::array<std::uint64_t, kQuantityMaterialSlots> cells{};
    for (const auto& [coord, chunk] : chunks_) {
        (void)coord;
        for (std::size_t i = 0; i < chunk->cells.size(); ++i) {
            const auto material = chunk->cells[i].material_value();
            if (material != Material::Empty) ++cells[static_cast<std::uint8_t>(material)];
            if (material != Material::Water) continue;
            visible = quantity_add(visible, chunk->cells[i].state_a_value());
            if (chunk->pressure != nullptr) overfill = quantity_add(overfill, chunk->pressure->cells[i].overfill);
        }
    }
    if (visible != quantity_.water_visible || overfill != quantity_.water_overfill || cells != quantity_.material_cells)
        throw std::invalid_argument("quantity accounting differs from stored authority");
}
