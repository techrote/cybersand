#include "cybersand/water_normalization.hpp"

#include <iostream>
#include <sstream>
#include <stdexcept>
#include <type_traits>

using namespace cybersand;
using namespace cybersand::normalization;
namespace {
std::uint64_t assertions = 0;
void require(bool condition, const std::string& detail) {
    ++assertions;
    if (!condition) throw std::runtime_error(detail);
}
FinalSetupCell water(std::int64_t x, std::int64_t y, std::uint16_t mass,
                     std::uint8_t coherence = 0, std::int16_t temperature = 200) {
    return {x, y, Material::Water, mass, coherence, temperature};
}
Sha256::Digest digest_for(std::initializer_list<std::uint8_t> bytes) {
    return Sha256::of({bytes.begin(), bytes.size()});
}
FinalSetupInput fixture(std::uint8_t bits, std::uint64_t seed, std::vector<FinalSetupCell> cells,
                        std::int16_t ambient = 200, SetupDomain domain = {0,0,1024,1024},
                        std::optional<Sha256::Digest> definition = std::nullopt) {
    FinalSetupInput result;
    result.mass_bits = bits;
    result.setup.seed = seed;
    result.setup.domain = domain;
    result.setup.definition_digest = definition;
    result.cells = std::move(cells);
    result.ambient_temperature = ambient;
    return result;
}
PreparedSetup accepted(const FinalSetupInput& input,
                       WaterQuantityRegime regime = WaterQuantityRegime::WholeCell,
                       NormalizationOptIn opt_in = NormalizationOptIn::WaterNormalizeV1) {
    auto result = PreparedSetup::prepare(input, regime, opt_in);
    if (auto* refusal = std::get_if<Refusal>(&result))
        throw std::runtime_error(std::string(refusal_id(refusal->code)) + ": " + refusal->detail);
    return std::get<PreparedSetup>(std::move(result));
}
void refused(const FinalSetupInput& input, RefusalCode code,
             WaterQuantityRegime regime = WaterQuantityRegime::WholeCell,
             NormalizationOptIn opt_in = NormalizationOptIn::WaterNormalizeV1,
             PreparationLimits limits = {}) {
    const auto result = PreparedSetup::prepare(input, regime, opt_in, limits);
    const auto* refusal = std::get_if<Refusal>(&result);
    require(refusal != nullptr && refusal->code == code, "incorrect or missing refusal");
}
void exact_thresholds_and_all_precisions() {
    for (std::uint8_t bits = 3; bits <= 8; ++bits) {
        const auto maximum = static_cast<std::uint16_t>((1U << bits) - 1U);
        const auto threshold = static_cast<std::uint16_t>(1U << (bits - 1U));
        for (std::uint16_t mass = 1; mass <= maximum; ++mass) {
            auto input = fixture(bits, 7, {water(0, 0, mass, 12)});
            const auto original = input.cells;
            const auto prepared = accepted(input);
            const bool round_up = mass >= threshold; // independent power-of-two threshold oracle
            require(prepared.final_cells().size() == (round_up ? 1U : 0U), "precision threshold");
            if (round_up) {
                const auto& cell = prepared.final_cells()[0];
                require(cell.material == Material::Water && cell.state_a == maximum &&
                            cell.state_b == 12 && cell.temperature == 200,
                        "full-cell output or nonquantity state changed");
            }
            require(input.cells == original, "preparation mutated caller input");
            const auto& receipt = *prepared.normalization_receipt();
            const auto& totals = receipt.totals();
            const auto after = round_up ? maximum : 0;
            require(totals.water_before == mass && totals.water_after == static_cast<std::uint64_t>(after),
                    "before/after quantities");
            require(totals.net_delta == after - mass, "signed delta");
            require(totals.cells_unchanged == (mass == maximum ? 1U : 0U) &&
                        totals.cells_up == (round_up && mass != maximum ? 1U : 0U) &&
                        totals.cells_down == (!round_up ? 1U : 0U), "cell classifications");
            require(totals.water_before + totals.positive_delta == totals.water_after + totals.negative_delta,
                    "exact setup-only ledger closure");
            require(receipt.seed_before() == 7 && receipt.seed_after() == 7 && receipt.mass_bits() == bits,
                    "receipt loses precision/seed");
        }
    }
    for (const auto [bits, down, up] : {std::array<int,3>{8,127,128}, std::array<int,3>{3,3,4}}) {
        auto input = fixture(static_cast<std::uint8_t>(bits), 0,
                              {water(5, 5, static_cast<std::uint16_t>(down)),
                               water(6, 5, static_cast<std::uint16_t>(up))});
        const auto prepared = accepted(input);
        require(prepared.final_cells().size() == 1 && prepared.final_cells()[0].x == 6,
                "registered 127/128 or 3/4 threshold");
        require(prepared.normalization_receipt()->totals().net_delta == 0, "threshold pair is net zero");
    }
}
void refusals_and_no_live_conversion() {
    auto input = fixture(8, 0, {water(0, 0, 128)});
    refused(input, RefusalCode::NormalizationRequired, WaterQuantityRegime::WholeCell, NormalizationOptIn::None);
    const auto fractional = accepted(input, WaterQuantityRegime::Fractional, NormalizationOptIn::None);
    require(fractional.final_cells()[0].state_a == 128 && !fractional.normalization_receipt(),
            "fractional family changed without request");
    const auto normalized_comparator = accepted(input, WaterQuantityRegime::Fractional);
    const auto normalized_whole = accepted(input, WaterQuantityRegime::WholeCell);
    require(normalized_comparator.setup_hash() == normalized_whole.setup_hash() &&
                normalized_comparator.normalization_receipt()->receipt_hash() ==
                    normalized_whole.normalization_receipt()->receipt_hash(),
            "explicit normalization differs between matched comparator arms");
    refused(input, RefusalCode::UnknownParameter, static_cast<WaterQuantityRegime>(2));
    refused(input, RefusalCode::UnknownParameter, WaterQuantityRegime::WholeCell, static_cast<NormalizationOptIn>(2));
    input.cells[0].state_a = 255;
    const auto already_full = accepted(input, WaterQuantityRegime::WholeCell, NormalizationOptIn::None);
    require(already_full.final_cells()[0].state_a == 255 && !already_full.normalization_receipt(),
            "full setup requires no conversion");
    const auto explicit_full = accepted(input);
    require(explicit_full.normalization_receipt()->totals() == NormalizationTotals{0,0,1,0,0,0,255,255},
            "explicit no-op receipt");
    require(explicit_full.normalization_receipt()->setup_before_hash() == explicit_full.setup_hash(),
            "no-op setup hash changed");
    input.mass_bits = 2; refused(input, RefusalCode::MalformedPolicy);
    input.mass_bits = 9; refused(input, RefusalCode::MalformedPolicy);
    input.mass_bits = 8;
    input.cells[0].state_a = 0; refused(input, RefusalCode::MalformedPolicy);
    input.cells[0].state_a = 256; refused(input, RefusalCode::MalformedPolicy);
    input.cells[0].state_a = 255;
    input.cells[0].state_b = 13; refused(input, RefusalCode::MalformedPolicy);
    input.cells[0].state_b = 0;
    input.cells[0].material = static_cast<Material>(10); refused(input, RefusalCode::MalformedPolicy);
    input.cells[0].material = Material::Empty; refused(input, RefusalCode::MalformedPolicy);
    input.cells[0].material = Material::Oil;
    input.cells[0].state_a = 256; refused(input, RefusalCode::MalformedPolicy);
    input.cells = {water(1,1,127), water(1,1,128)};
    refused(input, RefusalCode::MalformedPolicy); // unresolved overlaps cannot enter native normalization
    input.cells = {water(1,1,128)};
    refused(input, RefusalCode::CapacityRefused, WaterQuantityRegime::WholeCell,
            NormalizationOptIn::WaterNormalizeV1, {0});
    refused(input, RefusalCode::CapacityRefused, WaterQuantityRegime::WholeCell,
            NormalizationOptIn::WaterNormalizeV1, {kMaximumSetupCells + 1});
    input.cells.clear();
    const auto empty = accepted(input);
    require(empty.final_cells().empty() && empty.normalization_receipt()->totals() == NormalizationTotals{},
            "empty setup with explicit opt-in");
    input.setup.domain.width = 0; refused(input, RefusalCode::MalformedPolicy);
    input.setup.domain.width = 1025; refused(input, RefusalCode::MalformedPolicy);
    input.setup.domain.width = 2; input.setup.domain.x = std::numeric_limits<std::int64_t>::max();
    refused(input, RefusalCode::MalformedPolicy);
    input.setup.domain = {0,0,1024,1024}; input.cells = {water(-1,0,128)};
    refused(input, RefusalCode::MalformedPolicy);
    input.cells = {water(1024,0,128)};
    refused(input, RefusalCode::MalformedPolicy);
    input.cells.clear(); input.setup.gaps = 0;
    refused(input, RefusalCode::MalformedPolicy);
    input.setup.gaps = 64;
    refused(input, RefusalCode::MalformedPolicy);
    input.setup.gaps = 63; input.setup.definition_schema = 2;
    refused(input, RefusalCode::MalformedPolicy);
    input.setup.definition_schema = 1;
    input.setup.coverage = setup::SetupCoverage::RegisteredDefinitionAndPayload;
    refused(input, RefusalCode::MalformedPolicy);
    input.setup.definition_digest = digest_for({1});
    input.setup.gaps = setup::kKnownSetupGaps & ~setup::HostCollectionUnverified;
    refused(input, RefusalCode::MalformedPolicy);
    input.setup.gaps = setup::kKnownSetupGaps;
    const auto registered = accepted(input);
    require((registered.setup_descriptor().gaps & setup::HostCollectionUnverified) != 0U,
            "definition digest supplied false native compilation proof");
    input.setup.kind = setup::SetupKind::MicroScenario;
    input.setup.definition_schema = 2;
    input.setup.coverage = setup::SetupCoverage::NativePayloadOnly;
    input.setup.gaps &= ~setup::HostCollectionUnverified;
    refused(input, RefusalCode::MalformedPolicy);
    input.setup = setup::SetupDescriptor{};
    input.setup.domain = {0,0,1024,1024};
    input.setup.gaps = setup::Schedule;
    refused(input, RefusalCode::MalformedPolicy);
}
void final_overlay_order_and_identity() {
    auto input = fixture(8, 1234,
        {water(20,3,128), {0,-1,Material::Oil,0,10,-250}, water(-2,3,127), water(0,0,255)},
        200,{-2,-1,23,5},digest_for({'s','e','t','u','p',0,255}));
    const auto prepared = accepted(input);
    require(prepared.final_cells().size() == 3 && prepared.final_cells()[0].material == Material::Oil &&
                prepared.final_cells()[1].y == 0 && prepared.final_cells()[2].x == 20,
            "row-major ordering or foreign material preservation");
    require(prepared.normalization_receipt()->totals() == NormalizationTotals{1,1,1,127,127,0,510,510},
            "aggregate ledger");
    std::reverse(input.cells.begin(), input.cells.end());
    const auto permuted = accepted(input);
    require(prepared.setup_hash() == permuted.setup_hash() &&
                prepared.normalization_receipt()->receipt_hash() == permuted.normalization_receipt()->receipt_hash(),
            "input order changes canonical identities");
    auto changed = input;
    ++changed.setup.seed;
    require(accepted(changed).setup_hash() != prepared.setup_hash(), "seed omitted from setup hash");
    require(accepted(changed).native_payload_hash() == prepared.native_payload_hash(), "seed leaked into native payload digest");
    changed = input; changed.setup.definition_digest = digest_for({1});
    require(accepted(changed).setup_hash() != prepared.setup_hash() &&
                accepted(changed).native_payload_hash() == prepared.native_payload_hash(),
            "definition binding omitted from setup hash or polluted payload digest");
    changed = input;
    for (auto& cell : changed.cells) if (cell.material == Material::Oil) ++cell.temperature;
    require(accepted(changed).setup_hash() != prepared.setup_hash(), "foreign temperature omitted from identity");
    // Caller-resolved overlap is just one final tuple. A down-round must erase
    // it even if an earlier caller record was Wall/full Water at that location.
    auto final_overlay = fixture(8, 0, {water(4,7,127)});
    require(accepted(final_overlay).final_cells().empty(), "down-round preserved underlying rectangle material");
    final_overlay.cells[0].state_a = 128;
    require(accepted(final_overlay).final_cells()[0].state_a == 255, "final overlaid mass not used");
    auto reinput = fixture(prepared.mass_bits(), prepared.seed(),
        std::vector<FinalSetupCell>(prepared.final_cells().begin(), prepared.final_cells().end()),
        prepared.ambient_temperature(), prepared.domain(), prepared.setup_descriptor().definition_digest);
    reinput.setup = prepared.setup_descriptor();
    const auto reapplied = accepted(reinput);
    require(reapplied.setup_hash() == prepared.setup_hash(), "normalized setup is not idempotent");
    require(reapplied.normalization_receipt()->totals().cells_unchanged == 2 &&
                reapplied.normalization_receipt()->totals().net_delta == 0,
            "idempotence receipt did not classify full Water");
    require(reapplied.normalization_receipt()->receipt_hash() != prepared.normalization_receipt()->receipt_hash(),
            "distinct conversion histories share a receipt hash");
    changed = input; ++changed.ambient_temperature;
    require(accepted(changed).setup_hash() != prepared.setup_hash(), "ambient omitted from setup identity");
    changed = input; ++changed.setup.domain.width;
    require(accepted(changed).setup_hash() != prepared.setup_hash(), "domain omitted from setup identity");
}
void empty_thermal_fields() {
    auto original = fixture(8, 0, {water(0,0,127,12,-123)});
    const auto normalized = accepted(original);
    require(normalized.final_cells().size() == 1 &&
                normalized.final_cells()[0] == FinalSetupCell{0,0,Material::Empty,0,0,-123},
            "down-round destroyed the nonambient thermal field or retained Water state lanes");
    const auto& totals = normalized.normalization_receipt()->totals();
    require(totals.cells_down == 1 && totals.water_after == 0 && totals.net_delta == -127,
            "thermal Empty counted as Water");
    auto explicit_empty = fixture(8,0,{{0,0,Material::Empty,0,0,-123}});
    require(accepted(explicit_empty).setup_hash() == normalized.setup_hash(),
            "thermal Empty canonical identity differs by construction path");
    explicit_empty.cells[0].temperature = 200;
    const auto default_empty = accepted(explicit_empty);
    require(default_empty.final_cells().empty() && default_empty.setup_hash() == accepted(FinalSetupInput{}).setup_hash(),
            "explicit ambient Empty did not canonicalize to absence");
    require(default_empty.setup_hash() != normalized.setup_hash(), "Empty thermal field missing from hash");
    original.ambient_temperature = std::numeric_limits<std::int16_t>::min();
    original.cells[0].temperature = original.ambient_temperature;
    require(accepted(original).final_cells().empty(), "INT16_MIN ambient rejected or not canonical");
    original.ambient_temperature = std::numeric_limits<std::int16_t>::max();
    original.cells[0].temperature = original.ambient_temperature;
    require(accepted(original).final_cells().empty(), "INT16_MAX ambient rejected or not canonical");
}
void arithmetic_and_signed_extremes() {
    auto value = std::numeric_limits<std::uint64_t>::max();
    require(!detail::add_u64(value, 1) && value == std::numeric_limits<std::uint64_t>::max(), "u64 overflow changed total");
    require(detail::add_u64(value, 0), "u64 zero increment failed");
    value = 0;
    require(detail::add_u64(value, std::numeric_limits<std::uint64_t>::max()), "u64 boundary rejected");
    std::int64_t result = 17;
    const auto sign = std::uint64_t{1} << 63U;
    require(!detail::signed_difference(sign, 0, result) && result == 17, "positive signed overflow");
    require(detail::signed_difference(0, sign, result) && result == std::numeric_limits<std::int64_t>::min(),
            "INT64_MIN boundary");
    result = 17;
    require(!detail::signed_difference(0, sign + 1, result) && result == 17, "negative signed overflow");
    require(detail::signed_difference(std::numeric_limits<std::uint64_t>::max(),
                                     std::numeric_limits<std::uint64_t>::max(), result) && result == 0,
            "large cancelling deltas");
    auto extremes = fixture(8, std::numeric_limits<std::uint64_t>::max(),
        {water(std::numeric_limits<std::int64_t>::max(),std::numeric_limits<std::int64_t>::min(),128),
         water(std::numeric_limits<std::int64_t>::max()-1,std::numeric_limits<std::int64_t>::min(),127)});
    extremes.setup.domain = {std::numeric_limits<std::int64_t>::max()-1,std::numeric_limits<std::int64_t>::min(),2,1};
    const auto prepared = accepted(extremes);
    require(prepared.final_cells().size() == 1 &&
                prepared.final_cells()[0].x == std::numeric_limits<std::int64_t>::max(),
            "coordinate comparison or serialization overflow");
}
void emit_vector(std::string_view name, const FinalSetupInput& input) {
    const auto prepared = accepted(input);
    const auto& receipt = *prepared.normalization_receipt();
    const auto& t = receipt.totals();
    std::ostringstream encoded;
    encoded << name << '|' << Sha256::hex(receipt.payload_before_hash()) << '|'
              << Sha256::hex(receipt.payload_after_hash()) << '|' << Sha256::hex(receipt.setup_before_hash()) << '|'
              << Sha256::hex(receipt.setup_after_hash()) << '|' << Sha256::hex(receipt.receipt_hash()) << '|'
              << t.cells_up << ',' << t.cells_down << ',' << t.cells_unchanged << ','
              << t.positive_delta << ',' << t.negative_delta << ',' << t.net_delta << ','
              << t.water_before << ',' << t.water_after;
    static constexpr std::pair<std::string_view,std::string_view> expected[] = {
#include "water_normalization_vectors.inc"
    };
    const auto found = std::find_if(std::begin(expected),std::end(expected),
        [name](const auto& value){return value.first==name;});
    require(found!=std::end(expected),"unregistered canonical vector");
    require(encoded.str()==found->second,"native normalization bytes disagree with independent frozen vector");
}
void emit_vectors() {
    emit_vector("mass8-pair", fixture(8,42,{water(0,0,127),water(1,0,128)},200,{0,0,1024,1024},digest_for({'v',0,255})));
    emit_vector("mass3-pair", fixture(3,7,{water(-5,9,3,12,-123),water(0,-1,4)},200,{-5,-1,6,11}));
    emit_vector("positive", fixture(8,0,{water(0,0,128),water(1,0,254),water(2,0,255)}));
    emit_vector("negative", fixture(8,0,{water(0,0,1),water(1,0,127)}));
    emit_vector("empty", fixture(8,0,{}));
    emit_vector("foreign", fixture(8,1234,
        {water(20,3,128),{0,-1,Material::Oil,0,10,-250},water(-2,3,127),water(0,0,255)},200,{-2,-1,23,5},
        digest_for({'s','e','t','u','p',0,255})));
    auto registered = fixture(8,99,{water(0,0,128)},200,{0,0,8,8},digest_for({'m','i','c','r','o'}));
    registered.setup.kind=setup::SetupKind::MicroScenario;
    registered.setup.definition_schema=2;
    registered.setup.coverage=setup::SetupCoverage::RegisteredDefinitionAndPayload;
    emit_vector("registered-unverified",registered);
    emit_vector("extremes", fixture(8,std::numeric_limits<std::uint64_t>::max(),
        {water(std::numeric_limits<std::int64_t>::max(),std::numeric_limits<std::int64_t>::min(),128),
         water(std::numeric_limits<std::int64_t>::max()-1,std::numeric_limits<std::int64_t>::min(),127)},
         200,{std::numeric_limits<std::int64_t>::max()-1,std::numeric_limits<std::int64_t>::min(),2,1}));
}
} // namespace

static_assert(std::is_same_v<decltype(std::declval<const PreparedSetup&>().final_cells()),
                             std::span<const FinalSetupCell>>);
static_assert(std::is_same_v<decltype(std::declval<const Receipt&>().totals()), const NormalizationTotals&>);

void test_water_normalization_rounding() { exact_thresholds_and_all_precisions(); }
void test_water_normalization_refusals() { refusals_and_no_live_conversion(); }
void test_water_normalization_final_identity() { final_overlay_order_and_identity(); }
void test_water_normalization_thermal() { empty_thermal_fields(); }
void test_water_normalization_arithmetic() { arithmetic_and_signed_extremes(); }
void test_water_normalization_canonical_vectors() { emit_vectors(); }
