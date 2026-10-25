// LCB-001 (#200) liquid solver policy foundation regressions. The registered
// Gate C wire vectors are replayed bit for bit from the generated include.
#include "cybersand/c_api.h"
#include "cybersand/liquid_solver_policy.hpp"
#include "cybersand/material_rules.hpp"
#include "cybersand/world.hpp"

#include <array>
#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <limits>
#include <memory>
#include <optional>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <new>
#include <vector>

// Allocation fault injection for the C API, following test_generation_fields.cpp.
// Thread-local and disarmed (-1) by default: only an explicitly armed call on
// this thread sees a failure, and exactly one allocation (the Nth) fails.
namespace liquid_policy_allocation_probe {
thread_local long long fail_after = -1;
thread_local std::size_t injected = 0;
}

#if defined(__GNUC__) || defined(__clang__)
#define LIQUID_POLICY_TEST_NOINLINE __attribute__((noinline))
#else
#define LIQUID_POLICY_TEST_NOINLINE
#endif
LIQUID_POLICY_TEST_NOINLINE void* operator new(std::size_t size) {
    auto& remaining = liquid_policy_allocation_probe::fail_after;
    if (remaining == 0) {
        remaining = -1;
        ++liquid_policy_allocation_probe::injected;
        throw std::bad_alloc();
    }
    if (remaining > 0) --remaining;
    if (void* result = std::malloc(size == 0 ? 1 : size)) return result;
    throw std::bad_alloc();
}
LIQUID_POLICY_TEST_NOINLINE void operator delete(void* pointer) noexcept { std::free(pointer); }
LIQUID_POLICY_TEST_NOINLINE void operator delete(void* pointer, std::size_t) noexcept {
    ::operator delete(pointer);
}
LIQUID_POLICY_TEST_NOINLINE void* operator new[](std::size_t size) { return ::operator new(size); }
LIQUID_POLICY_TEST_NOINLINE void operator delete[](void* pointer) noexcept { ::operator delete(pointer); }
LIQUID_POLICY_TEST_NOINLINE void operator delete[](void* pointer, std::size_t) noexcept {
    ::operator delete(pointer);
}
#undef LIQUID_POLICY_TEST_NOINLINE

namespace {

using cybersand::LiquidPolicyBuild;
using cybersand::LiquidPolicyRefusalCode;
using cybersand::LiquidSolverFamily;
using cybersand::LiquidSolverPolicy;
using cybersand::LiquidSolverVariant;
using cybersand::Material;
using cybersand::Sha256;
using cybersand::World;
using cybersand::WorldConfig;

struct VectorCell {
    std::uint16_t material;
    std::uint8_t family;
};

struct VectorBuild {
    const char* name;
    const char* catalogue_digest;
    const char* capability_matrix_digest;
    std::uint8_t available_families;
    bool native;
    bool cell_qualified;
    std::vector<VectorCell> qualified_cells;
};

struct VectorField {
    const char* name;
    std::int64_t minimum;
    std::int64_t maximum;
};

struct VectorSchema {
    bool family_owner;
    std::uint16_t owner;
    std::uint16_t version;
    bool mandatory;
    std::uint8_t requires_family;
    std::vector<VectorField> fields;
};

struct VectorCase {
    const char* name;
    const char* build;
    std::vector<std::int64_t> words;
    bool accepted;
    const char* code;
    std::int32_t material;
    const char* detail;
    const char* policy_hash;
    const char* canonical_hex;
    std::vector<std::int64_t> normalized;
};

struct VectorSessionStep {
    const char* step;
    std::vector<std::int64_t> words;
    bool accepted;
    const char* code;
    const char* readback_hash;
    std::uint64_t generation;
};

#include "liquid_policy_vectors.inc"

void require(bool condition, std::string_view message) {
    if (!condition) throw std::runtime_error(std::string(message));
}

Sha256::Digest digest_from_hex(std::string_view hex) {
    require(hex.size() == 64U, "digest hex length");
    Sha256::Digest digest{};
    auto nibble = [](char c) -> std::uint8_t {
        if (c >= '0' && c <= '9') return static_cast<std::uint8_t>(c - '0');
        if (c >= 'a' && c <= 'f') return static_cast<std::uint8_t>(c - 'a' + 10);
        throw std::runtime_error("bad digest hex");
    };
    for (std::size_t i = 0; i < digest.size(); ++i)
        digest[i] = static_cast<std::uint8_t>((nibble(hex[i * 2U]) << 4U) | nibble(hex[i * 2U + 1U]));
    return digest;
}

std::string bytes_hex(std::span<const std::uint8_t> bytes) {
    static constexpr char kDigits[] = "0123456789abcdef";
    std::string out;
    for (const auto byte : bytes) {
        out.push_back(kDigits[byte >> 4U]);
        out.push_back(kDigits[byte & 0x0fU]);
    }
    return out;
}

std::vector<std::uint8_t> read_lf(const char* path) {
    std::ifstream file(path, std::ios::binary);
    require(file.good(), std::string("run tests from the repository root; missing ") + path);
    std::vector<std::uint8_t> raw((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    std::vector<std::uint8_t> out;
    out.reserve(raw.size());
    for (std::size_t i = 0; i < raw.size(); ++i)
        if (!(raw[i] == '\r' && i + 1U < raw.size() && raw[i + 1U] == '\n')) out.push_back(raw[i]);
    return out;
}

std::vector<cybersand::LiquidParameterSchema> vector_schemas() {
    std::vector<cybersand::LiquidParameterSchema> schemas;
    for (const auto& item : kVectorSchemas) {
        cybersand::LiquidParameterSchema schema;
        schema.family_owner = item.family_owner;
        schema.owner = item.owner;
        schema.version = item.version;
        schema.mandatory = item.mandatory;
        schema.requires_family = item.requires_family;
        for (const auto& field : item.fields) schema.fields.push_back({field.name, field.minimum, field.maximum});
        schemas.push_back(std::move(schema));
    }
    return schemas;
}

LiquidPolicyBuild vector_build(std::string_view name) {
    for (const auto& item : kVectorBuilds) {
        if (name != item.name) continue;
        LiquidPolicyBuild build;
        build.catalogue_digest = digest_from_hex(item.catalogue_digest);
        build.capability_matrix_digest = digest_from_hex(item.capability_matrix_digest);
        build.available_families = item.available_families;
        build.native = item.native;
        build.cell_qualified = item.cell_qualified;
        for (const auto& cell : item.qualified_cells) build.qualified_cells.emplace_back(cell.material, cell.family);
        build.schemas = vector_schemas();
        return build;
    }
    throw std::runtime_error("unknown vector build");
}

std::vector<std::int32_t> narrow(const std::vector<std::int64_t>& words) {
    std::vector<std::int32_t> out;
    for (const auto word : words) out.push_back(static_cast<std::int32_t>(word));
    return out;
}

LiquidSolverPolicy accept(std::span<const std::int32_t> words, const LiquidPolicyBuild& build,
                          std::string_view what) {
    auto result = LiquidSolverPolicy::decode(words, build);
    require(result.accepted(), std::string(what) + " refused: " + result.refusal.message());
    return *result.policy;
}

void populate_mixed_liquids(World& world) {
    for (std::int64_t x = 0; x <= 96; ++x) world.set(x, 60, Material::Wall);
    for (std::int64_t y = 0; y <= 60; ++y) {
        world.set(0, y, Material::Wall);
        world.set(96, y, Material::Wall);
        if (y >= 30) world.set(48, y, Material::Wall);
    }
    for (std::int64_t y = 10; y < 30; ++y) {
        for (std::int64_t x = 4; x < 20; ++x) world.set(x, y, Material::Water);
        for (std::int64_t x = 22; x < 30; ++x) world.set(x, y, Material::Oil);
        for (std::int64_t x = 52; x < 60; ++x) world.set(x, y, Material::Brine);
        for (std::int64_t x = 62; x < 70; ++x) world.set(x, y, Material::Sand);
        for (std::int64_t x = 72; x < 78; ++x) world.set(x, y, Material::Mercury);
    }
    for (std::int64_t x = 80; x < 88; ++x) world.set(x, 5, Material::Lava);
    for (std::int64_t x = 32; x < 40; ++x) world.set(x, 40, Material::Salt);
}

}  // namespace

void test_liquid_policy_sha256_known_answers() {
    const auto empty = Sha256::hex(Sha256::of({}));
    require(empty == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "SHA-256 empty");
    const std::string_view abc = "abc";
    require(Sha256::hex(Sha256::of({reinterpret_cast<const std::uint8_t*>(abc.data()), abc.size()})) ==
                "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
            "SHA-256 abc");
    const std::string_view two_blocks = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";
    require(Sha256::hex(Sha256::of({reinterpret_cast<const std::uint8_t*>(two_blocks.data()),
                                    two_blocks.size()})) ==
                "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
            "SHA-256 448-bit message");
    Sha256 incremental;
    const std::vector<std::uint8_t> chunk(1000U, static_cast<std::uint8_t>('a'));
    for (int i = 0; i < 1000; ++i) incremental.update(chunk);
    require(Sha256::hex(incremental.finish()) ==
                "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0",
            "SHA-256 one million a");
}

void test_liquid_policy_identity_matches_source() {
    // catalogue_digest: domain, then u32 LE path length, path, u32 LE length, LF bytes.
    Sha256 catalogue;
    const std::string_view domain{"lcb-material-catalogue-v1\0", 26};
    catalogue.update({reinterpret_cast<const std::uint8_t*>(domain.data()), domain.size()});
    for (const char* path : {"native/include/cybersand/material.hpp", "native/include/cybersand/interaction_rules.hpp"}) {
        const auto bytes = read_lf(path);
        const std::string_view name(path);
        auto put_u32 = [&](std::size_t value) {
            const std::array<std::uint8_t, 4> le{static_cast<std::uint8_t>(value), static_cast<std::uint8_t>(value >> 8U),
                                                 static_cast<std::uint8_t>(value >> 16U),
                                                 static_cast<std::uint8_t>(value >> 24U)};
            catalogue.update(le);
        };
        put_u32(name.size());
        catalogue.update({reinterpret_cast<const std::uint8_t*>(name.data()), name.size()});
        put_u32(bytes.size());
        catalogue.update(bytes);
    }
    const auto catalogue_digest = catalogue.finish();
    require(catalogue_digest == cybersand::liquid_policy_catalogue::kCatalogueDigest,
            "embedded catalogue_digest is stale; run tools/lcb/native_policy_artifacts.py");
    Sha256 capability;
    const std::string_view capability_domain{"lcb-capability-matrix-v1\0", 25};
    capability.update({reinterpret_cast<const std::uint8_t*>(capability_domain.data()), capability_domain.size()});
    capability.update(read_lf("docs/reference/liquid-solver-capability-matrix.json"));
    require(capability.finish() == cybersand::liquid_policy_catalogue::kCapabilityMatrixDigest,
            "embedded capability_matrix_digest is stale");
    require(Sha256::hex(catalogue_digest) == kVectorCurrentCatalogueDigest &&
                Sha256::hex(cybersand::liquid_policy_catalogue::kCapabilityMatrixDigest) ==
                    kVectorCurrentCapabilityDigest,
            "vector current_build_identity differs from the native build");
    const auto& running = LiquidPolicyBuild::running();
    // LCB-001 pressure reference: FreeMass, CellularYield and pressure_flow_v1
    // compiled; optional pressure family and Water CellularYield v2 schemas.
    require(running.catalogue_digest == catalogue_digest && running.native && running.schemas.size() == 3U &&
                running.schemas.front().family_owner && running.schemas.front().owner == 3U &&
                !running.schemas.front().mandatory && running.available_families == 0x0FU,
            "running build identity");
}

void test_liquid_policy_catalogue_matches_descriptors() {
    using cybersand::LateralFlowMode;
    using cybersand::MaterialRules;
    std::size_t liquids = 0;
    require(cybersand::liquid_policy_catalogue::kMaterialDescriptorCount ==
                static_cast<std::size_t>(cybersand::kLastMaterial) + 1U,
            "descriptor count");
    for (std::uint16_t id = 0; id < cybersand::liquid_policy_catalogue::kMaterialDescriptorCount; ++id) {
        if (!MaterialRules::is_valid(id)) continue;
        const auto& descriptor = MaterialRules::descriptor(static_cast<Material>(id));
        const bool liquid = descriptor.state == cybersand::MaterialState::Liquid ||
                            descriptor.lateral_flow != LateralFlowMode::None;
        const cybersand::liquid_policy_catalogue::LiquidRow* row = nullptr;
        for (const auto& item : cybersand::liquid_policy_catalogue::kLiquidRows)
            if (item.material_id == id) row = &item;
        require(liquid == (row != nullptr), "catalogue liquid set differs from MaterialRules");
        if (row == nullptr) continue;
        ++liquids;
        const auto expected = descriptor.lateral_flow == LateralFlowMode::FreeMass ? 1U : 2U;
        require(row->default_family == expected, "catalogue default family differs from LateralFlowMode");
        require(row->status[row->default_family - 1U] == cybersand::liquid_policy_catalogue::CellStatus::CurrentDefault,
                "default cell status");
    }
    require(liquids == LiquidSolverPolicy::kLiquidCount && liquids == 11U, "eleven liquid descriptors");
    const auto water = LiquidSolverPolicy{}.assignment(static_cast<std::uint16_t>(Material::Water));
    require(water && water->family == LiquidSolverFamily::FreeMassV1, "Water default is freemass_v1");
    const auto oil = LiquidSolverPolicy{}.assignment(static_cast<std::uint16_t>(Material::Oil));
    require(oil && oil->family == LiquidSolverFamily::CellularYieldV1, "Oil default is cellular_yield_v1");
}

void test_liquid_policy_wire_vectors() {
    std::size_t accepted = 0;
    std::size_t refused = 0;
    for (const auto& item : kVectorCases) {
        const auto build = vector_build(item.build);
        const auto result = LiquidSolverPolicy::decode(std::span<const std::int64_t>(item.words), build);
        const std::string name(item.name);
        require(result.accepted() == item.accepted, name + ": acceptance differs from the oracle");
        if (!item.accepted) {
            ++refused;
            require(cybersand::liquid_policy_refusal_id(result.refusal.code) == item.code, name + ": refusal code");
            require((result.refusal.material ? static_cast<std::int32_t>(*result.refusal.material) : -1) ==
                        item.material,
                    name + ": refusal material");
            require(result.refusal.detail == item.detail,
                    name + ": refusal detail '" + result.refusal.detail + "' != '" + item.detail + "'");
            continue;
        }
        ++accepted;
        const auto& policy = *result.policy;
        require(policy.policy_hash_hex() == item.policy_hash, name + ": policy_hash");
        require(bytes_hex(policy.canonical_bytes()) == item.canonical_hex, name + ": canonical bytes");
        require(policy.envelope() == narrow(item.normalized), name + ": normalized envelope");
        const auto again = policy.envelope();
        const auto reread = accept(again, build, name + " normalized");
        require(reread == policy && reread.envelope() == again, name + ": normalized round trip");
        for (const auto& assignment : policy.assignments())
            require(assignment.family != LiquidSolverFamily::MaterialDefault, name + ": code 0 applied");
        // An int32 transport of the same request decodes identically.
        const auto narrowed = narrow(item.words);
        require(LiquidSolverPolicy::decode(std::span<const std::int32_t>(narrowed), build).policy == policy,
                name + ": int32 transport");
    }
    require(accepted >= 11U && refused >= 36U && accepted + refused == kVectorCases.size(), "vector coverage");
}

void test_liquid_policy_session_transcript() {
    const auto build = vector_build("all_families_hypothetical");
    auto applied = accept(LiquidSolverPolicy::default_request(build), build, "hypothetical default");
    std::uint64_t generation = 0;
    for (const auto& step : kVectorSession) {
        const std::string name(step.step);
        if (name != "construct default") {
            const auto result = LiquidSolverPolicy::decode(std::span<const std::int64_t>(step.words), build);
            require(result.accepted() == step.accepted, name + ": acceptance");
            if (result.accepted()) {
                applied = *result.policy;
                ++generation;
            } else {
                require(cybersand::liquid_policy_refusal_id(result.refusal.code) == step.code, name + ": code");
            }
        }
        require(applied.policy_hash_hex() == step.readback_hash && generation == step.generation,
                name + ": readback after step");
    }
}

void test_liquid_policy_running_build_admits_only_defaults() {
    // Defaults, qualified Water candidates and Brine IN/reference.
    const auto request = LiquidSolverPolicy::default_request();
    const auto applied = accept(request, LiquidPolicyBuild::running(), "running default");
    require(applied == LiquidSolverPolicy{} && applied.envelope() == request, "explicit default equals implicit");
    // Request-only code 0 normalizes to the same applied identity.
    auto all_zero = request;
    for (std::size_t i = 0; i < LiquidSolverPolicy::kLiquidCount; ++i) all_zero[20U + i * 3U + 1U] = 0;
    const auto normalized = accept(all_zero, LiquidPolicyBuild::running(), "all code 0");
    require(normalized == applied, "code 0 changes identity");
    require(normalized.assignment(3)->requested_family == LiquidSolverFamily::MaterialDefault &&
                applied.assignment(3)->requested_family == LiquidSolverFamily::FreeMassV1,
            "requested family is retained for readback only");
    using Code = LiquidPolicyRefusalCode;
    using cybersand::liquid_policy_catalogue::CellStatus;
    std::size_t cells = 0;
    for (std::size_t row_index = 0; row_index < LiquidSolverPolicy::kLiquidCount; ++row_index) {
        const auto& row = cybersand::liquid_policy_catalogue::kLiquidRows[row_index];
        for (std::uint8_t family = 1; family <= 4U; ++family) {
            for (std::uint8_t variant = 0; variant < 3U; ++variant) {
                if (family == row.default_family && variant == 0U) continue;
                if ((row.material_id == 3U && (((family == 2U || family == 4U) && variant == 0U) || family == 3U)) ||
                    (row.material_id == 24U && family == 4U && variant == 0U)) {
                    // Preserve every distinct admitted Water and Brine candidate.
                    auto words = request;
                    words[20U + row_index * 3U + 1U] = family;
                    words[20U + row_index * 3U + 2U] = variant;
                    const auto admitted = accept(words, LiquidPolicyBuild::running(), "qualified native candidate");
                    require(admitted.assignment(row.material_id)->family == static_cast<LiquidSolverFamily>(family) &&
                            admitted.assignment(row.material_id)->variant == static_cast<LiquidSolverVariant>(variant),
                            "native candidate applied");
                    ++cells;
                    continue;
                }
                auto words = request;
                words[20U + row_index * 3U + 1U] = family;
                words[20U + row_index * 3U + 2U] = variant;
                const auto result = LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
                const auto status = row.status[family - 1U];
                const auto variants = row.variant_mask[family - 1U];
                Code expected = Code::FamilyUnavailable;
                if (status == CellStatus::Rejected) expected = Code::CombinationRejected;
                else if (status == CellStatus::ProposedAlternate || variants == 0U) expected = Code::NotSelectable;
                else if ((variants & (1U << variant)) == 0U) expected = Code::VariantUnsupported;
                if (row.material_id == 3U && family == 3U && expected == Code::FamilyUnavailable)
                    require(result.refusal.detail == std::string("pressure_flow_v1/") +
                                std::string(cybersand::liquid_solver_variant_id(
                                    static_cast<cybersand::LiquidSolverVariant>(variant))) +
                                " is not compiled/qualified for material 3 in this build",
                            "pressure variant refusal detail");
                require(!result.accepted() && result.refusal.code == expected &&
                            result.refusal.material == row.material_id,
                        std::string("running build admitted or misclassified ") + row.name + " family " +
                            std::to_string(family) + " variant " + std::to_string(variant));
                ++cells;
            }
        }
    }
    require(cells == LiquidSolverPolicy::kLiquidCount * 12U - LiquidSolverPolicy::kLiquidCount, "sweep size");
    // W-CY is now qualified; its separate native regression proves Water hooks
    // and Water-owned parameters rather than Paste/Slush descriptor dispatch.
    auto water_cy = request;
    water_cy[20U + 1U] = 2;
    const auto admitted = LiquidSolverPolicy::decode(std::span<const std::int32_t>(water_cy));
    require(admitted.accepted() && admitted.policy->assignment(3)->family == LiquidSolverFamily::CellularYieldV1,
            "Water whole-cell CellularYield reference must be admitted");
}

void test_liquid_policy_world_construction_and_refusal() {
    // A policy a hypothetical build would accept can never construct a World here.
    LiquidPolicyBuild contract = vector_build("all_families_hypothetical");
    contract.catalogue_digest = LiquidPolicyBuild::running().catalogue_digest;
    auto words = LiquidSolverPolicy::default_request(contract);
    words[20U + 1U] = 4; // Water -> inertial_cellular_v1
    // Default envelope ends with F=0, M=0; add the illustrative mandatory block.
    const std::size_t family_count_at = words.size() - 2U;
    words[family_count_at] = 1;
    words.insert(words.begin() + static_cast<std::ptrdiff_t>(family_count_at) + 1, {4, 1, 2, 62259, 512});
    const auto inertial = accept(words, contract, "contract Water inertial");
    require(inertial.assignment(3)->family == LiquidSolverFamily::InertialCellularV1, "contract decode");
    WorldConfig config;
    config.liquid_solver_policy = inertial;
    bool refused = false;
    try {
        World world(config);
    } catch (const cybersand::LiquidPolicyRefused& error) {
        refused = error.refusal().code == LiquidPolicyRefusalCode::UnknownParameter;
    }
    require(refused, "World reinterpreted the historical illustrative IN parameter block");
    require(inertial.admission_refusal().has_value() && !LiquidSolverPolicy{}.admission_refusal(),
            "admission check");
    World world;
    require(world.liquid_solver_policy() == LiquidSolverPolicy{}, "World default readback");
}

void test_liquid_policy_default_preserves_behavior_and_workers() {
    const auto explicit_default = accept(LiquidSolverPolicy::default_request(), LiquidPolicyBuild::running(),
                                         "explicit default");
    // These fixtures deliberately coexist. Keep their large policy tables and
    // Worlds off the test thread's ordinary 1 MiB Windows stack.
    auto implicit_config_storage = std::make_unique<WorldConfig>();
    auto& implicit_config = *implicit_config_storage;
    auto explicit_config_storage = std::make_unique<WorldConfig>();
    auto& explicit_config = *explicit_config_storage;
    explicit_config.liquid_solver_policy = explicit_default;
    auto workers_config_storage = std::make_unique<WorldConfig>(explicit_config);
    auto& workers_config = *workers_config_storage;
    workers_config.worker_threads = 4;
    auto implicit_world_storage = std::make_unique<World>(implicit_config);
    auto& implicit_world = *implicit_world_storage;
    auto explicit_world_storage = std::make_unique<World>(explicit_config);
    auto& explicit_world = *explicit_world_storage;
    auto workers_world_storage = std::make_unique<World>(workers_config);
    auto& workers_world = *workers_world_storage;
    for (World* world : {&implicit_world, &explicit_world, &workers_world}) populate_mixed_liquids(*world);
    require(implicit_world.state_hash() == explicit_world.state_hash() &&
                implicit_world.state_hash() == workers_world.state_hash(),
            "initial state differs");
    std::uint64_t moved = 0;
    for (int tick = 0; tick < 160; ++tick) {
        moved += implicit_world.tick().moved_cells;
        (void)explicit_world.tick();
        (void)workers_world.tick();
        require(implicit_world.state_hash() == explicit_world.state_hash(),
                "explicit default policy changed behavior at tick " + std::to_string(tick));
        require(implicit_world.state_hash() == workers_world.state_hash(),
                "four-worker explicit default diverged at tick " + std::to_string(tick));
        require(implicit_world.content_hash() == workers_world.content_hash(), "content hash diverged");
    }
    require(moved > 0U, "fixture exercised no motion");
    require(workers_world.liquid_solver_policy() == explicit_default &&
                workers_world.config().worker_threads == 4U,
            "worker World readback");
    // The liquid policy identity is independent of Water semantics.
    auto mass3_storage = std::make_unique<WorldConfig>();
    auto& mass3 = *mass3_storage;
    mass3.water_experiment_policy = cybersand::WaterExperimentPolicy(3U, 0U);
    auto mass3_world_storage = std::make_unique<World>(mass3);
    auto& mass3_world = *mass3_world_storage;
    require(mass3_world.liquid_solver_policy().policy_hash() == explicit_default.policy_hash(),
            "Water semantics changed the liquid policy hash");

    // These diagnostic switches change physics, so they belong to physical
    // identity and CYPS even when histogram collection itself is disabled.
    for (const bool powder_override : {false, true}) {
        auto physics_storage = std::make_unique<WorldConfig>();
        auto& physics = *physics_storage;
        physics.physics_diagnostics.disable_powder_exchange_targets = powder_override;
        physics.physics_diagnostics.mercury_viscosity = powder_override ? -1 : 0;
        auto original_storage = std::make_unique<World>(physics);
        auto& original = *original_storage;
        original.reserve_region({0, 0, 128, 128});
        for (std::int64_t x = 0; x < 128; ++x) original.set(x, 64, Material::Wall);
        for (std::int64_t y = 48; y < 64; ++y)
            for (std::int64_t x = 48; x < 80; ++x) original.set(x, y, Material::Mercury);
        auto default_physics_storage = std::make_unique<World>();
        auto& default_physics = *default_physics_storage;
        default_physics.reserve_region({0, 0, 128, 128});
        for (std::int64_t x = 0; x < 128; ++x) default_physics.set(x, 64, Material::Wall);
        for (std::int64_t y = 48; y < 64; ++y)
            for (std::int64_t x = 48; x < 80; ++x) default_physics.set(x, y, Material::Mercury);
        require(original.state_hash() == default_physics.state_hash() &&
                    original.physical_state_hash() != default_physics.physical_state_hash(),
                "physics-changing diagnostic options omitted from physical identity");
        const auto saved = original.save_physical_state();
        auto execution_storage = std::make_unique<WorldConfig>();
        auto& execution = *execution_storage;
        execution.worker_threads = 4;
        auto restored = World::restore_physical_state(execution, saved);
        require(restored->config().physics_diagnostics.disable_powder_exchange_targets == powder_override &&
                    restored->config().physics_diagnostics.mercury_viscosity ==
                        physics.physics_diagnostics.mercury_viscosity &&
                    restored->save_physical_state() == saved,
                "CYPS lost physics-changing diagnostic options");
        for (int tick = 0; tick < 20; ++tick) {
            (void)original.tick();
            (void)restored->tick();
            require(original.physical_state_hash() == restored->physical_state_hash() &&
                        original.state_hash() == restored->state_hash(),
                    "diagnostic physics continuation diverged after CYPS restore");
        }
    }

    // A valid digest does not make an inconsistent conservation ledger valid.
    auto pressure_request = LiquidSolverPolicy::default_request();
    pressure_request[21] = 3;
    auto pressure_config_storage = std::make_unique<WorldConfig>();
    auto& pressure_config = *pressure_config_storage;
    pressure_config.liquid_solver_policy =
        accept(pressure_request, LiquidPolicyBuild::running(), "pressure ledger restore");
    auto pressure_storage = std::make_unique<World>(pressure_config);
    auto& pressure = *pressure_storage;
    const auto original_bytes = pressure.save_physical_state();
    constexpr std::size_t digest_size = 32U, flow_bytes = 5U * 8U, gas_bytes = 10U * 8U;
    const auto gas_start = original_bytes.size() - digest_size - flow_bytes - gas_bytes;
    for (const bool overflow : {false, true}) {
        auto bytes = original_bytes;
        const auto put = [&bytes](std::size_t at, std::uint64_t value) {
            for (std::size_t i = 0; i < 8U; ++i)
                bytes[at + i] = static_cast<std::uint8_t>(value >> (8U * i));
        };
        put(gas_start, overflow ? std::numeric_limits<std::uint64_t>::max() : 1U); // created
        if (overflow) put(gas_start + 8U, 1U); // absorbed, would wrap the source sum to zero
        const auto digest = Sha256::of(std::span<const std::uint8_t>(bytes.data(), bytes.size() - digest_size));
        std::copy(digest.begin(), digest.end(), bytes.end() - static_cast<std::ptrdiff_t>(digest_size));
        bool refused = false;
        try {
            (void)World::restore_physical_state(WorldConfig{}, bytes);
        } catch (const std::invalid_argument&) {
            refused = true;
        }
        require(refused, "CYPS accepted an inconsistent or overflowing gas ledger");
    }
}

void test_liquid_policy_c_api_transaction() {
    const auto required = cybersand_liquid_policy_default_v1(nullptr, 0);
    require(required == LiquidSolverPolicy::default_request().size(), "C default size query");
    std::vector<std::int32_t> request(required);
    require(cybersand_liquid_policy_default_v1(request.data(), request.size() - 1U) == required &&
                request.front() == 0,
            "C default wrote with insufficient capacity");
    require(cybersand_liquid_policy_default_v1(request.data(), request.size()) == required &&
                request == LiquidSolverPolicy::default_request(),
            "C default words");
    cybersand_liquid_policy_refusal_v1 refusal{};
    refusal.struct_size = sizeof(refusal);
    std::array<std::uint8_t, 32> hash{};
    refusal.detail[0] = 'x'; // an accepted request must clear any stale detail
    require(cybersand_liquid_policy_validate_v1(request.data(), request.size(), &refusal, hash.data()) == 1 &&
                refusal.code == CYBERSAND_LIQUID_POLICY_ACCEPTED && refusal.detail[0] == '\0' &&
                hash == LiquidSolverPolicy{}.policy_hash(),
            "C validate default");

    auto config = cybersand_default_config_v2();
    cybersand_world* kept = cybersand_world_create_with_liquid_policy_v1(&config, request.data(), request.size(),
                                                                         &refusal);
    require(kept != nullptr && refusal.code == CYBERSAND_LIQUID_POLICY_ACCEPTED, "C create default");
    cybersand_world_set(kept, 4, 4, static_cast<std::uint16_t>(Material::Water));
    const auto kept_hash = cybersand_world_hash(kept);

    auto stale = request;
    stale[3] ^= 1;
    refusal = {};
    refusal.struct_size = sizeof(refusal);
    require(cybersand_world_create_with_liquid_policy_v1(&config, stale.data(), stale.size(), &refusal) == nullptr &&
                refusal.code == CYBERSAND_LIQUID_POLICY_STALE_CAPABILITY_MATRIX && refusal.material == -1 &&
                std::string_view(refusal.detail) == "catalogue_digest differs from the running build",
            "C stale refusal");
    auto oil_pressure = request;
    oil_pressure[20U + 3U * 3U + 1U] = 3; // Oil (row 3) -> pressure_flow_v1
    require(cybersand_world_create_with_liquid_policy_v1(&config, oil_pressure.data(), oil_pressure.size(),
                                                         &refusal) == nullptr &&
                refusal.code == CYBERSAND_LIQUID_POLICY_COMBINATION_REJECTED && refusal.material == 16,
            "C rejected combination");
    require(cybersand_world_create_with_liquid_policy_v1(&config, request.data(), request.size() - 1U, &refusal) ==
                    nullptr &&
                refusal.code == CYBERSAND_LIQUID_POLICY_MALFORMED_POLICY,
            "C truncated envelope");
    require(cybersand_world_create_with_liquid_policy_v1(nullptr, request.data(), request.size(), &refusal) ==
                    nullptr &&
                refusal.code == CYBERSAND_LIQUID_POLICY_CONSTRUCTION_FAILED,
            "C invalid config");
    // Refusals never touched the existing World or its readback.
    require(cybersand_world_hash(kept) == kept_hash, "refusal changed an existing World");
    std::vector<std::int32_t> readback(cybersand_world_liquid_policy_v1(kept, nullptr, 0));
    require(cybersand_world_liquid_policy_v1(kept, readback.data(), readback.size()) == readback.size() &&
                readback == request,
            "C readback words");
    std::array<std::uint8_t, 32> readback_hash{};
    require(cybersand_world_liquid_policy_hash_v1(kept, readback_hash.data()) == 1 && readback_hash == hash,
            "C readback hash");
    cybersand_world* plain = cybersand_world_create_v2(&config);
    std::array<std::uint8_t, 32> plain_hash{};
    require(plain != nullptr && cybersand_world_liquid_policy_hash_v1(plain, plain_hash.data()) == 1 &&
                plain_hash == hash && cybersand_world_hash(plain) != kept_hash,
            "independent default World");
    cybersand_liquid_policy_refusal_v1 undersized{};
    undersized.struct_size = 4;
    undersized.code = 77;
    require(cybersand_liquid_policy_validate_v1(stale.data(), stale.size(), &undersized, nullptr) == 0 &&
                undersized.code == 77,
            "undersized refusal struct written");
    require(cybersand_world_liquid_policy_v1(nullptr, nullptr, 0) == CYBERSAND_SIZE_ERROR &&
                cybersand_world_liquid_policy_hash_v1(nullptr, readback_hash.data()) == 0,
            "C null World");
    cybersand_world_destroy(plain);
    cybersand_world_destroy(kept);
}

namespace {

// Field-wise: cybersand_config_v2 has padding (after worker_threads and at the
// end), whose bytes are unspecified, so memcmp is not a valid comparison.
bool same_config(const cybersand_config_v2& a, const cybersand_config_v2& b) {
    return a.struct_size == b.struct_size && a.abi_version == b.abi_version &&
           a.chunk_size == b.chunk_size && a.sleep_after_quiet_ticks == b.sleep_after_quiet_ticks &&
           a.ambient_temperature == b.ambient_temperature && a.backend == b.backend &&
           a.reserved_0 == b.reserved_0 && a.activity_block_size == b.activity_block_size &&
           a.scheduling_core_size == b.scheduling_core_size && a.maximum_rule_radius == b.maximum_rule_radius &&
           a.worker_threads == b.worker_threads && a.initial_chunk_reserve == b.initial_chunk_reserve &&
           a.parallel_job_threshold == b.parallel_job_threshold &&
           a.active_core_capacity == b.active_core_capacity &&
           a.active_chunk_capacity == b.active_chunk_capacity && a.maximum_chunk_count == b.maximum_chunk_count &&
           a.deferred_event_capacity == b.deferred_event_capacity &&
           a.maximum_explosion_radius == b.maximum_explosion_radius;
}

// Fail the 0th, 1st, ... allocation of `call` in turn until one run completes
// without an injected failure. Returns {injected failures, allocations seen}.
template <typename Call, typename Check>
std::pair<std::size_t, std::size_t> sweep_allocation_failures(Call call, Check check_failed) {
    namespace probe = liquid_policy_allocation_probe;
    constexpr long long kLimit = 20'000;
    std::size_t failures = 0;
    for (long long nth = 0; nth < kLimit; ++nth) {
        const auto before = probe::injected;
        probe::fail_after = nth;
        auto result = call();
        probe::fail_after = -1;
        if (probe::injected == before) return {failures, static_cast<std::size_t>(nth)};
        ++failures;
        check_failed(result, nth);
    }
    throw std::runtime_error("allocation sweep did not converge");
}

}  // namespace

void test_liquid_policy_c_api_allocation_failures() {
    // Warm every lazily built static outside the armed window.
    const auto request = LiquidSolverPolicy::default_request();
    const auto expected = cybersand_default_config_v2();
    require(expected.struct_size == sizeof(cybersand_config_v2), "unarmed default config");

    // 1. Default config: an allocation failure yields the documented all-zero
    //    config, which the v2 constructor refuses; it never escapes the C ABI.
    const auto zero = cybersand_config_v2{};
    auto config_sweep = sweep_allocation_failures(
        [] { return cybersand_default_config_v2(); },
        [&](const cybersand_config_v2& result, long long nth) {
            require(same_config(result, zero),
                    "default config failure " + std::to_string(nth) + " is not all-zero");
        });
    require(config_sweep.first >= 1U, "default config performed no injectable allocation");
    require(cybersand_world_create_v2(&zero) == nullptr, "zero config constructed a World");
    const auto again = cybersand_default_config_v2();
    require(same_config(again, expected), "default config changed after failures");

    // 2. Validation: every failure is a CONSTRUCTION_FAILED refusal, never a throw.
    cybersand_liquid_policy_refusal_v1 refusal{};
    refusal.struct_size = sizeof(refusal);
    auto validate_sweep = sweep_allocation_failures(
        [&] { return cybersand_liquid_policy_validate_v1(request.data(), request.size(), &refusal, nullptr); },
        [&](int accepted, long long nth) {
            require(accepted == 0 && refusal.code == CYBERSAND_LIQUID_POLICY_CONSTRUCTION_FAILED,
                    "validate failure " + std::to_string(nth) + " was not a construction refusal");
        });
    require(validate_sweep.first >= 1U && refusal.code == CYBERSAND_LIQUID_POLICY_ACCEPTED,
            "validate sweep");

    // 3. Construction with a policy: every failure returns no World. Each call
    //    disarms before releasing what it built, so no World leaks.
    auto world_sweep = sweep_allocation_failures(
        [&] {
            cybersand_world* built =
                cybersand_world_create_with_liquid_policy_v1(&expected, request.data(), request.size(), &refusal);
            liquid_policy_allocation_probe::fail_after = -1;
            const bool constructed = built != nullptr;
            cybersand_world_destroy(built);
            return constructed;
        },
        [&](bool constructed, long long nth) {
            require(!constructed && refusal.code == CYBERSAND_LIQUID_POLICY_CONSTRUCTION_FAILED,
                    "create failure " + std::to_string(nth) + " returned a World or a policy refusal");
        });
    require(world_sweep.first >= 1U && refusal.code == CYBERSAND_LIQUID_POLICY_ACCEPTED, "create sweep");
    // Scheduling capacity scales the two contiguous activity payloads, not
    // the number of owning allocations. Sweep every failure point again at a
    // single slot: per-job owning vectors would multiply the default4096-slot
    // construction sweep quadratically and regress bounded setup work.
    auto small = expected;
    small.active_core_capacity = 1U;
    auto small_world_sweep = sweep_allocation_failures(
        [&] {
            auto* built = cybersand_world_create_with_liquid_policy_v1(
                &small, request.data(), request.size(), &refusal);
            liquid_policy_allocation_probe::fail_after = -1;
            const bool constructed = built != nullptr;
            cybersand_world_destroy(built);
            return constructed;
        },
        [&](bool constructed, long long nth) {
            require(!constructed && refusal.code == CYBERSAND_LIQUID_POLICY_CONSTRUCTION_FAILED,
                    "single-slot create failure " + std::to_string(nth) + " escaped refusal");
        });
    require(small_world_sweep.first >= 1U &&
                refusal.code == CYBERSAND_LIQUID_POLICY_ACCEPTED &&
                small_world_sweep.second == world_sweep.second,
            "scheduling slot capacity multiplied constructor allocation points");
    // A later worker startup can fail after earlier threads are waiting. Every
    // injected main-thread allocation must return a construction refusal after
    // retiring that prefix, including failures before the first thread starts.
    auto parallel = expected;
    parallel.worker_threads = 4U;
    auto parallel_world_sweep = sweep_allocation_failures(
        [&] {
            auto* built = cybersand_world_create_with_liquid_policy_v1(
                &parallel, request.data(), request.size(), &refusal);
            liquid_policy_allocation_probe::fail_after = -1;
            const bool constructed = built != nullptr;
            cybersand_world_destroy(built);
            return constructed;
        },
        [&](bool constructed, long long nth) {
            require(!constructed && refusal.code == CYBERSAND_LIQUID_POLICY_CONSTRUCTION_FAILED,
                    "four-worker create failure " + std::to_string(nth) + " escaped refusal");
        });
    require(parallel_world_sweep.second > world_sweep.second &&
                refusal.code == CYBERSAND_LIQUID_POLICY_ACCEPTED,
            "four-worker create sweep did not exercise worker startup allocations");
    // The converged run built a World; read it back under failures, then release it.
    cybersand_world* world = cybersand_world_create_with_liquid_policy_v1(&expected, request.data(),
                                                                          request.size(), &refusal);
    require(world != nullptr, "create after sweep");
    std::vector<std::int32_t> words(request.size());
    auto readback_sweep = sweep_allocation_failures(
        [&] { return cybersand_world_liquid_policy_v1(world, words.data(), words.size()); },
        [&](std::size_t result, long long nth) {
            require(result == CYBERSAND_SIZE_ERROR,
                    "readback failure " + std::to_string(nth) + " did not report CYBERSAND_SIZE_ERROR");
        });
    require(readback_sweep.first >= 1U && words == request, "readback sweep");
    cybersand_world_destroy(world);
}
