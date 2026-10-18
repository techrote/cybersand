"""One-shot MAT-002 source patch; removed after the reviewed source is committed.

All replacements require exact frozen-source matches. No networking, credentials,
branch manipulation, runtime publication or test-result interpretation occurs here.
"""
from pathlib import Path
import re


def replace(path: str, old: str, new: str, count: int = 1) -> None:
    p = Path(path)
    text = p.read_text()
    actual = text.count(old)
    if actual != count:
        raise RuntimeError(f'{path}: expected {count} exact matches, found {actual}: {old[:100]!r}')
    p.write_text(text.replace(old, new))


world = 'native/src/world.cpp'
header = 'native/include/cybersand/world.hpp'
replace(header,
'''    [[nodiscard]] std::uint16_t state_a(std::int64_t x, std::int64_t y) const noexcept;''',
'''    // Water-lattice inventory across Water/Steam/Ice. Steam/Ice b=0 is
    // legacy/full inventory; it is not an empty parcel.
    [[nodiscard]] std::uint16_t phase_water_quantity(std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] std::uint8_t phase_quantity_state(std::uint16_t quantity) const noexcept;
    [[nodiscard]] std::uint16_t state_a(std::int64_t x, std::int64_t y) const noexcept;''')

replace(world,
'''bool World::rule_is_active(Material material, std::uint16_t state_a_value,''',
'''std::uint16_t World::phase_water_quantity(std::int64_t x, std::int64_t y) const noexcept {
    const auto material = get(x, y);
    if (material == Material::Water) return state_a(x, y);
    if (material != Material::Steam && material != Material::Ice) return 0;
    const auto quantity = state_b(x, y);
    return quantity == 0U ? config_.water_experiment_policy.maximum() : quantity;
}

std::uint8_t World::phase_quantity_state(std::uint16_t quantity) const noexcept {
    // Keep old full-cell initialization and traces canonical. Callers supply a
    // nonzero, validated quantity; actual zero inventory is Material::Empty.
    return quantity == config_.water_experiment_policy.maximum()
        ? std::uint8_t{0} : static_cast<std::uint8_t>(quantity);
}

bool World::rule_is_active(Material material, std::uint16_t state_a_value,''')

replace(world,
'''    if (material != Material::Empty && transient_obstacle_at(x, y) != 0U) return false;
    const auto target = address(x, y);''',
'''    if ((material == Material::Steam || material == Material::Ice) &&
        state_b_value > config_.water_experiment_policy.maximum()) {
        throw std::logic_error("internal phase quantity outside Water policy");
    }
    if ((material == Material::Lava || material == Material::MoltenGlass) &&
        state_b_value >= config_.water_experiment_policy.maximum()) {
        throw std::logic_error("internal quench progress outside Water policy");
    }
    if (material != Material::Empty && transient_obstacle_at(x, y) != 0U) return false;
    const auto target = address(x, y);''')

replace(world,
'''    if (material != Material::Water && state_a_value > 255)
        throw std::invalid_argument("non-Water byte state out of domain");''',
'''    if (material != Material::Water && state_a_value > 255)
        throw std::invalid_argument("non-Water byte state out of domain");
    if ((material == Material::Steam || material == Material::Ice) &&
        state_b_value > config_.water_experiment_policy.maximum())
        throw std::invalid_argument("phase quantity outside Water policy");
    if ((material == Material::Lava || material == Material::MoltenGlass) &&
        state_b_value >= config_.water_experiment_policy.maximum())
        throw std::invalid_argument("quench progress outside Water policy");''')

replace(world,
'''            const auto& source_definition =
                MaterialRules::descriptor(reaction->source_product);
            const auto& target_definition =
                MaterialRules::descriptor(reaction->target_product);
            const auto source_state_a = reaction->source_product == Material::Water
                ? config_.water_experiment_policy.maximum()
                : static_cast<std::uint16_t>(source_definition.initial_state_a);
            const auto target_state_a = reaction->target_product == Material::Water
                ? config_.water_experiment_policy.maximum()
                : static_cast<std::uint16_t>(target_definition.initial_state_a);
            bool changed = write_cell(
                target_x, target_y, reaction->target_product,
                target_state_a, target_definition.initial_state_b,
                effects);
            changed = write_cell(
                          x, y, reaction->source_product,
                          source_state_a,
                          source_definition.initial_state_b, effects) ||
                      changed;
            return changed;''',
'''            struct ProductState {
                Material material;
                std::uint16_t a;
                std::uint8_t b;
            };
            const auto product_state = [this](Material before, Material product,
                                               std::int64_t px, std::int64_t py) {
                const auto& definition = MaterialRules::descriptor(product);
                ProductState result{product,
                    product == Material::Water ? config_.water_experiment_policy.maximum()
                                               : static_cast<std::uint16_t>(definition.initial_state_a),
                    definition.initial_state_b};
                if (before == product &&
                    (before == Material::Water || before == Material::Ice || before == Material::Lava)) {
                    // A preserved participant is not a fresh full-cell source.
                    result.a = state_a(px, py);
                    result.b = state_b(px, py);
                } else if (before == Material::Water && product == Material::Steam) {
                    result.b = phase_quantity_state(phase_water_quantity(px, py));
                } else if (before == Material::Steam && product == Material::Water) {
                    result.a = phase_water_quantity(px, py);
                }
                return result;
            };
            // Capture both original participants before either write. Reading
            // the second inventory after the first conversion would lose roles.
            auto source_product = product_state(material, reaction->source_product, x, y);
            auto target_product = product_state(target, reaction->target_product, target_x, target_y);
            const auto is_quenchable = [](Material candidate) {
                return candidate == Material::Lava || candidate == Material::MoltenGlass;
            };
            const auto quench = [this](Material hot, std::int64_t hx, std::int64_t hy,
                                       std::uint16_t coolant, ProductState& output) {
                const auto progress = static_cast<std::uint16_t>(state_b(hx, hy) + coolant);
                if (progress < config_.water_experiment_policy.maximum()) {
                    output = {hot, state_a(hx, hy), static_cast<std::uint8_t>(progress)};
                }
                // At threshold retain the authored whole-cell solid product.
                // All contacting Water becomes quantity-bearing Steam. Excess
                // coolant is retained in that parcel, not deleted. This is a
                // game-scale contact budget, not a physical latent-heat solver.
            };
            if (material == Material::Water && is_quenchable(target)) {
                quench(target, target_x, target_y, phase_water_quantity(x, y), target_product);
            } else if (target == Material::Water && is_quenchable(material)) {
                quench(material, x, y, phase_water_quantity(target_x, target_y), source_product);
            }
            bool changed = write_cell(target_x, target_y, target_product.material,
                                      target_product.a, target_product.b, effects);
            changed = write_cell(x, y, source_product.material,
                                 source_product.a, source_product.b, effects) || changed;
            return changed;''')

replace(world,
'''        case RuleKernel::Steam: {
            const auto lifetime = state_a(x, y);
            if (lifetime <= 1U) {
                return write_cell(x, y, Material::Water,
                                  config_.water_experiment_policy.maximum(), 0, effects);
            }
            bool changed = write_cell(x, y, Material::Steam,
                                      static_cast<std::uint8_t>(lifetime - 1U), 0,
                                      effects);''',
'''        case RuleKernel::Steam: {
            const auto lifetime = state_a(x, y);
            if (lifetime <= 1U) {
                return write_cell(x, y, Material::Water,
                                  phase_water_quantity(x, y), 0, effects);
            }
            bool changed = write_cell(x, y, Material::Steam,
                                      static_cast<std::uint8_t>(lifetime - 1U), state_b(x, y),
                                      effects);''')

replace(world,
'''                    changed = write_cell(target_x, target_y, Material::Steam, 90, 0,
                                         effects) ||''',
'''                    changed = write_cell(target_x, target_y, Material::Steam, 90,
                                         phase_quantity_state(phase_water_quantity(target_x, target_y)),
                                         effects) ||''')
replace(world,
'''                    changed = write_cell(x, y, Material::MoltenGlass, cooling, 0,
                                         effects);''',
'''                    changed = write_cell(x, y, Material::MoltenGlass, cooling, state_b(x, y),
                                         effects);''')
replace(world,
'''                    changed = write_cell(sample_x, sample_y, Material::Water,
                                         config_.water_experiment_policy.maximum(), 0, effects);''',
'''                    changed = write_cell(sample_x, sample_y, Material::Water,
                                         phase_water_quantity(sample_x, sample_y), 0, effects);''')
replace(world,
'''        case RuleKernel::Ice: {
            if (!thermal_change_due) return false;
            if (find_neighbour([](Material candidate, auto, auto) {
                    return is_hot(candidate);
                })) {
                return write_cell(x, y, Material::Water,
                                  config_.water_experiment_policy.maximum(), 0, effects);
            }''',
'''        case RuleKernel::Ice: {
            if (!thermal_change_due) return false;
            if (find_neighbour([](Material candidate, auto, auto) {
                    return is_hot(candidate);
                })) {
                return write_cell(x, y, Material::Water,
                                  phase_water_quantity(x, y), 0, effects);
            }''')
replace(world,
'''            return write_cell(target_x, target_y, Material::Ice, 0, 0, effects);''',
'''            return write_cell(target_x, target_y, Material::Ice, 0,
                              phase_quantity_state(phase_water_quantity(target_x, target_y)), effects);''')

rules_path = Path('native/include/cybersand/interaction_rules.hpp')
rules = rules_path.read_text()
rules = rules.replace('kInteractionProfileVersion = 1U;', 'kInteractionProfileVersion = 2U;')
changed_pairs = {
    'int.pair.lava-water.quench.v1': 'retain Water inventory in Steam; solidify Lava only after one full-cell equivalent of cumulative coolant',
    'int.pair.fire-water.extinguish.v1': 'extinguish Fire; retain the Water parcel quantity in Steam',
    'int.pair.water-sodium.react.v1': 'retain Water quantity in Steam; Sodium-to-Fire remains an explicit chemical conversion',
    'int.pair.water-toxic-sludge.purify.v1': 'preserve unchanged Water state; Sludge contributes one explicit full-cell Water source',
    'int.pair.steam-ice.condense.v1': 'retain Steam quantity on condensation; preserve the existing Ice quantity',
    'int.pair.water-molten-glass.quench.v1': 'retain Water inventory in Steam; solidify MoltenGlass after one full-cell equivalent of cumulative coolant',
    'int.pair.lava-glass.melt.v1': 'preserve Lava state and quench progress; convert Glass to initialized MoltenGlass',
}
changed_kernels = {
    'int.kernel.steam.condense.v1': 'lifetime expiry converts Steam to Water with retained aqueous quantity',
    'int.kernel.metal.charge.v1': 'base-Metal charge propagation; Water-to-Steam retains the original Water quantity',
    'int.kernel.molten-glass.cool.v1': 'hot-neighbour cooling reset and Glass conversion; countdown preserves Water-quench progress',
    'int.kernel.lava.contact.v1': 'sampled Ice melting retains aqueous quantity; neighbour ignition and movement unchanged',
    'int.kernel.ice.phase.v1': 'hot melting and sampled freezing retain aqueous quantity',
}
for old_id, description in (changed_pairs | changed_kernels).items():
    pattern = r'    \{"' + re.escape(old_id) + r'",.*?\},'
    found = list(re.finditer(pattern, rules, flags=re.S))
    if len(found) != 1:
        raise RuntimeError(f'Expected one catalogue entry for {old_id}, got {len(found)}')
    match = found[0]
    old_entry = match.group(0)
    new_id = old_id[:-1] + '2'
    new_entry = old_entry.replace('"' + old_id + '"', '"' + new_id + '"', 1)
    # The final string preceding revalidation tags is the rule accounting or
    # represented-semantics field. Other string-valued fields remain untouched.
    strings = list(re.finditer(r'"[^"\n]*"', new_entry))
    last = strings[-1]
    new_entry = new_entry[:last.start()] + '"' + description + '"' + new_entry[last.end():]
    new_entry = new_entry[:-2] + ', 2U, "' + old_id + '", "int.pass.mat002-phase-quantity"},'
    rules = rules[:match.start()] + new_entry + rules[match.end():]
old_pass = '''inline constexpr std::array<InteractionTuningPassDefinition, 1> kInteractionTuningPasses{{
    {"int.pass.current-oracle", 1U, "", "characterized-baseline", "none"},
}};'''
new_pass = '''inline constexpr std::array<InteractionTuningPassDefinition, 2> kInteractionTuningPasses{{
    {"int.pass.current-oracle", 1U, "", "characterized-baseline", "none"},
    {"int.pass.mat002-phase-quantity", 1U, "int.pass.current-oracle", "bounded-software-candidate",
     "Water/Steam/Ice quantity; Lava/MoltenGlass coolant budget; retained unchanged participant state"},
}};'''
if rules.count(old_pass) != 1:
    raise RuntimeError('Tuning-pass baseline changed')
rules = rules.replace(old_pass, new_pass)
rules = rules.replace('"int.pair.*.v1",\n     "all 14 compact pair rules are characterized against the frozen Current oracle"',
                      '"int.pair.*",\n     "14 full-contact product/probability recipes retain the frozen oracle; MAT-002 versions conditional quantity execution"')
rules = rules.replace('"int.kernel.*.v1",', '"int.kernel.*",')
rules_path.write_text(rules)

replace('native/tests/test_world.cpp',
        '#include "cybersand/world.hpp"',
        '#include "cybersand/world.hpp"\n#include "phase_quantity_tests.hpp"')
replace('native/tests/test_world.cpp',
        'cybersand::kInteractionProfileVersion == 1U,',
        'cybersand::kInteractionProfileVersion == 2U,')
replace('native/tests/test_world.cpp',
        'InteractionRules::tuning_passes().size() == 1U,',
        'InteractionRules::tuning_passes().size() == 2U,')
replace('native/tests/test_world.cpp',
'''    const Test tests[] = {
''',
'''    const Test tests[] = {
        {"MAT-002 phase quantities and quench budget", +[] {
            require(cybersand::mat002_tests::run_all(), "MAT-002 phase quantity group failed");
        }},
''')
replace('Makefile',
        'TEST_SOURCES := native/tests/test_world.cpp',
        'TEST_SOURCES := native/tests/test_world.cpp\nTEST_HEADERS := native/tests/phase_quantity_tests.hpp')
replace('Makefile',
        '$(TEST_SOURCES) | $(BUILD_DIR)',
        '$(TEST_SOURCES) $(TEST_HEADERS) | $(BUILD_DIR)', 3)
print('Applied MAT-002 quantity/state changes and retained native regression integration.')
