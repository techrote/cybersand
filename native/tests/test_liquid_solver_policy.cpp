// LCB-001 (#200) liquid solver policy foundation regressions. The registered
// Gate C wire vectors are replayed bit for bit from the generated include.
#include "cybersand/c_api.h"
#include "cybersand/liquid_solver_policy.hpp"
#include "cybersand/material_rules.hpp"
#include "cybersand/world.hpp"

#include <array>
#include <cstdint>
#include <fstream>
#include <iterator>
#include <optional>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

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
    require(running.catalogue_digest == catalogue_digest && running.native && running.schemas.empty() &&
                running.available_families == 0x03U,
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
                require(!result.accepted() && result.refusal.code == expected &&
                            result.refusal.material == row.material_id,
                        std::string("running build admitted or misclassified ") + row.name + " family " +
                            std::to_string(family) + " variant " + std::to_string(variant));
                ++cells;
            }
        }
    }
    require(cells == LiquidSolverPolicy::kLiquidCount * 12U - LiquidSolverPolicy::kLiquidCount, "sweep size");
    // Water x cellular_yield_v1 is matrix-selectable and the family is compiled,
    // but no Water route exists: refused, never silently run as yielding Paste/Slush.
    auto water_cy = request;
    water_cy[20U + 1U] = 2;
    const auto refused = LiquidSolverPolicy::decode(std::span<const std::int32_t>(water_cy));
    require(!refused.accepted() && refused.refusal.code == Code::FamilyUnavailable &&
                refused.refusal.detail == "cellular_yield_v1 is not qualified for material 3 in this build",
            "Water whole-cell CellularYield must be refused");
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
        refused = error.refusal().code == LiquidPolicyRefusalCode::FamilyUnavailable &&
                  error.refusal().material == std::optional<std::uint16_t>{std::uint16_t{3}};
    }
    require(refused, "World constructed with an unavailable family");
    require(inertial.admission_refusal().has_value() && !LiquidSolverPolicy{}.admission_refusal(),
            "admission check");
    World world;
    require(world.liquid_solver_policy() == LiquidSolverPolicy{}, "World default readback");
}

void test_liquid_policy_default_preserves_behavior_and_workers() {
    const auto explicit_default = accept(LiquidSolverPolicy::default_request(), LiquidPolicyBuild::running(),
                                         "explicit default");
    WorldConfig implicit_config;
    WorldConfig explicit_config;
    explicit_config.liquid_solver_policy = explicit_default;
    WorldConfig workers_config = explicit_config;
    workers_config.worker_threads = 4;
    World implicit_world(implicit_config);
    World explicit_world(explicit_config);
    World workers_world(workers_config);
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
    WorldConfig mass3;
    mass3.water_experiment_policy = cybersand::WaterExperimentPolicy(3U, 0U);
    World mass3_world(mass3);
    require(mass3_world.liquid_solver_policy().policy_hash() == explicit_default.policy_hash(),
            "Water semantics changed the liquid policy hash");
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
