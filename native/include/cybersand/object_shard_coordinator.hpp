#pragma once

#include "cybersand/object_shard.hpp"
#include "cybersand/object_shard_discovery.hpp"
#include "cybersand/world.hpp"
#include <array>
#include <memory>
#include <span>
#include <vector>

namespace cybersand::object_shard {

// One exclusive native owner, deliberately independent of Workbench/streaming.
// RIDs never enter this API; main supplies generation-bound value receipts.
struct Config {
    Bounds world_bounds{0, 0, 192, 128};
    Limits limits{};
    std::uint32_t scenario{1}; // 0 empty; 1 ordinary; 2 burning; 3 exchange; 4 three
    std::uint64_t seed{12};
    std::uint32_t discovery_budget{4096};
    std::uint32_t exposure_capacity{2048};
    std::uint32_t transfer_budget{64};
    std::uint32_t max_pause_calls{240};
    double max_translation_per_step{4.0};
    // Nominal large-body ceiling. Small-body extra rotation is constrained by
    // contact::motion_envelope's 4-cell corner arc and quarter-turn cap.
    double max_rotation_per_step{0.20};
    // Attached World displacement has a global candidate-work limit, in
    // addition to its finite radius and preallocated relocation inventory.
    std::uint32_t relocation_probe_budget{1'048'576};
};
struct PoseSample {
    Handle shard{};
    std::uint64_t body_generation{}, geometry_revision{}, pose_serial{};
    double x{}, y{}, rotation{}, vx{}, vy{}, angular_velocity{};
    bool sleeping{};
};
struct TerrainReceipt {
    std::uint32_t id{};
    std::uint64_t revision{}, digest{};
    bool operator==(const TerrainReceipt&) const = default;
};
struct TerrainChunk {
    TerrainReceipt identity{};
    std::int64_t x{}, y{};
    std::vector<Rect> rectangles;
};
enum class AckKind : std::uint8_t {
    PhysicsReserved, TerrainInstalled, BodyActivated, GeometryInstalled, BodyRetired,
    ReabsorptionFrozen, ReabsorptionComplete
};
struct Acknowledgement {
    Handle shard{};
    std::uint64_t transaction{}, body_generation{};
    std::uint64_t payload_digest{}, geometry_revision{}, mask_digest{}, shape_digest{};
    AckKind kind{AckKind::PhysicsReserved};
    std::span<const TerrainReceipt> terrain{};
};
struct Result {
    Outcome outcome{Outcome::Accepted};
    Handle shard{};
    std::uint64_t transaction{};
    Phase phase{Phase::Empty};
    const char* detail{"accepted"};
};
struct PromotionView {
    bool present{};
    Handle shard{};
    std::uint64_t transaction{}, payload_digest{}, captured_tick{};
    Phase phase{Phase::Empty};
    std::span<const TerrainReceipt> terrain{};
    Handle source_parent{};
};
struct ReabsorptionView {
    bool present{}, world_committed{};
    Handle shard{};
    std::uint64_t transaction{}, payload_digest{}, captured_tick{}, body_generation{};
    std::uint64_t geometry_revision{}, mask_digest{}, shape_digest{};
    std::span<const TerrainReceipt> terrain{};
};
struct BodyView {
    Handle shard{};
    std::uint64_t transaction{}, body_generation{};
    PoseSample pose{};
    PoseSample previous_pose{};
    std::uint64_t geometry_pending_tick{},geometry_pending_ns{};
    bool has_body{}, geometry_pending{}, pocket_open{},ingress_fenced{};
    std::uint32_t pocket_cell{};
    Handle source_parent{}; // Nonzero only for a physical island handoff.
    bool fragment_deferred{};
};
// Bounded owner-local M4 readback: copied body values, not a published World
// snapshot, borrowed storage span, RID or permission to tick. Ordinary M3
// snapshot semantics and mutable storage remain unchanged.
struct OwnerReadback {
    static constexpr std::size_t kBodySlots = 16;
    std::uint64_t session{}, world_incarnation{}, tick{};
    std::uint32_t active_count{}, copied_count{};
    bool world_available{}, paused{}, quarantined{}, promotion_pending{}, truncated{};
    std::array<BodyView, kBodySlots> bodies{};
};
struct Accounting {
    std::array<std::uint64_t, kQuantityMaterialSlots> promoted{}, ingested{}, emitted{};
    std::array<std::uint64_t, kQuantityMaterialSlots> created{}, destroyed{}, expired{}, reset_disposed{};
    std::array<std::uint64_t, kQuantityMaterialSlots> setup_created{}, authored_created{}, authored_destroyed{};
    std::array<std::int64_t, kQuantityMaterialSlots> world_tick_delta{};
    std::uint64_t reset_water_quanta{};
    std::uint64_t extinguished{}, accepted_exposures{}, consumed_exposures{}, external_ignitions{};
};
struct Metrics {
    std::uint64_t steps{}, paused_calls{}, discovered_cells{}, promotions{}, refusals{};
    std::uint64_t chemistry_cells{}, products_created{}, output_blocked{}, sand_ingested{};
    std::uint64_t exposure_overflows{}, stale_messages{}, mask_cells{}, sweep_samples{},ingress_blocked{};
    std::uint64_t composed_overlap_cells{}, composed_reuses{};
    std::uint64_t relocation_probes{}, relocation_probe_limit_hits{};
    std::uint64_t relocated_cells{}, relocated_water_cells{}, relocated_sand_cells{};
    std::uint64_t fragments{}, fragment_refusals{}, reabsorptions{};
    std::uint64_t world_ns{}, chemistry_ns{}, contact_ns{}, occupancy_ns{}, geometry_ns{}, snapshot_ns{};
    std::uint64_t discovery_ns{},terrain_ns{},exchange_ns{},relocation_ns{};
    std::uint64_t maximum_pause_ns{}, maximum_geometry_age{}, maximum_geometry_wait_ns{},maximum_product_age{};
    std::size_t coordinator_bytes{}, world_bytes{}, live_bytes{}, retained_bytes{}, peak_bytes{};
};
struct Snapshot {
    std::uint64_t session{}, world_incarnation{}, tick{};
    std::uint64_t next_transaction{};
    Bounds bounds{};
    bool paused{}, quarantined{};
    Result last_result{};
    PromotionView promotion{};
    ReabsorptionView reabsorption{};
    // Valid until the next coordinator call; the facade copies these values.
    std::span<const std::uint8_t> world_materials{};
    std::span<const TerrainChunk> terrain_chunks{};
    std::span<const Shard> shards{};
    std::span<const BodyView> bodies{};
    Accounting accounting{};
    Metrics metrics{};
    Metrics lifetime_metrics{}; // This owner instance, including its reset sessions.
    AdmissionStatus admission{};
};
enum class ExposureKind : std::uint8_t { WaterExtinction, FireIgnition };
struct Exposure {
    Handle shard{};
    std::uint32_t cell{}, incarnation{};
    std::uint64_t geometry_revision{}, pose_serial{}, first_tick{}, expiry_tick{}, sequence{};
    bool consumed{};
    ExposureKind kind{ExposureKind::WaterExtinction};
    std::int64_t source_x{}, source_y{};
};
struct TransferRequest {
    Handle shard{};
    std::uint64_t sequence{}, body_generation{}, geometry_revision{}, pose_serial{};
    std::uint32_t cell{}, incarnation{};
    std::int64_t world_x{}, world_y{};
    Payload expected{};
    std::uint64_t world_witness{};
    std::uint32_t capability_version{kCapabilityVersion};
};
struct ShardEditRequest {
    Handle shard{};
    std::uint64_t sequence{}, body_generation{}, geometry_revision{}, pose_serial{}, material_revision{};
    std::uint32_t cell{}, incarnation{};
    Payload expected{};
    std::uint32_t capability_version{kCapabilityVersion};
};
enum class ShardAction : std::uint8_t { Erase, Ignite, Inspect, Reabsorb };

class Coordinator {
public:
    explicit Coordinator(Config config = {});
    // Ordinary Workbench attachment: BORROWS the one owner-owned World without
    // constructing, stepping, resetting, or deleting it. Owner must dispose this
    // coordinator before replacing its World.
    explicit Coordinator(World& attached_world, Config config = {});
    [[nodiscard]] bool same_world_attached(const World& owner) const noexcept {
        return attached_ && world_ == &owner;
    }
    // Ordinary Worker calls after its existing exclusive World tick. The M3
    // standalone path continues to use Coordinator::step() unchanged.
    [[nodiscard]] Result begin_owner_world_tick();
    [[nodiscard]] Result after_owner_world_tick(std::span<const PoseSample> poses = {});
    // GCR owner supplies exact immutable occupancy as a copy before contact.
    // No raw World, node or RID aliases cross this API.
    [[nodiscard]] Result set_immutable_occupancy(
        std::span<const World::TransientCompositionCell> cells);
    ~Coordinator();
    Coordinator(const Coordinator&) = delete;
    Coordinator& operator=(const Coordinator&) = delete;
    [[nodiscard]] const Config& config() const noexcept { return config_; }
    [[nodiscard]] const World& world() const noexcept { return *world_; }
    // M4 failure-safe identity preflight: an exceptional reset may leave no World.
    // Never return a borrowable native pointer to an outside controller.
    [[nodiscard]] bool world_available() const noexcept { return world_ != nullptr; }
    [[nodiscard]] const Registry& registry() const noexcept { return registry_; }
    [[nodiscard]] OwnerReadback m4_owner_readback() const noexcept;
    [[nodiscard]] Result reset(std::uint32_t scenario, std::uint64_t seed);
    [[nodiscard]] Result step(std::span<const PoseSample> poses = {});
    // A real Rapier substep is admitted before another physical segment runs.
    // This applies occupancy/contact only; World and chemistry clocks do not advance.
    [[nodiscard]] Result accept_motion(std::span<const PoseSample> poses);
    [[nodiscard]] Result edit(std::int64_t x, std::int64_t y, Payload value);
    [[nodiscard]] Result ignite(std::int64_t x, std::int64_t y);
    [[nodiscard]] Result ignite_shard(Handle shard, std::uint32_t cell);
    [[nodiscard]] Result erase_shard(const ShardEditRequest& request);
    [[nodiscard]] Result act_on_shard(const ShardEditRequest& request, ShardAction action);
    // Retirement without replacing the World may not dispose any owned or
    // prepared inventory. Reset/owner destruction remains explicit disposal.
    [[nodiscard]] bool can_detach() const noexcept;
    [[nodiscard]] Result detach();
    [[nodiscard]] Result prepare_next();
    [[nodiscard]] Result acknowledge(const Acknowledgement& receipt);
    [[nodiscard]] Result cancel(std::uint64_t transaction);
    [[nodiscard]] Result ingest(const TransferRequest& request);
    [[nodiscard]] Result emit(const TransferRequest& request);
    [[nodiscard]] const Snapshot& snapshot(bool include_world = true);
    [[nodiscard]] Payload inspect_world(std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] const Metrics& metrics() const noexcept { return metrics_; }
    [[nodiscard]] Metrics lifetime_metrics() const noexcept;
    [[nodiscard]] const Accounting& accounting() const noexcept { return accounting_; }
    [[nodiscard]] std::uint64_t next_transaction() const noexcept { return next_transaction_; }
    [[nodiscard]] std::uint64_t world_witness(std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] std::uint64_t world_material_revision() const noexcept;
    [[nodiscard]] bool paused() const noexcept;

private:
    friend struct CoordinatorTestAccess;
    Coordinator(Config config, World* owner_world);
    struct Pending;
    struct Receipt;
    Config config_;
    std::uint64_t session_{1}, world_incarnation_{1}, next_transaction_{1};
    std::unique_ptr<World> owned_world_;
    World* world_ = nullptr; // borrowed only while attached_; never outlives owner
    bool attached_ = false;
    std::uint64_t last_owner_tick_{};
    bool owner_tick_admitted_{};
    std::array<std::uint64_t, kQuantityMaterialSlots> last_owner_population_{};
public:
    static constexpr std::uint16_t kFirstMutableBodyId =
        World::kMaximumTransientBodies - OwnerReadback::kBodySlots + 1;
    static constexpr int kStandaloneRelocationRadius = 8;
    static constexpr int kAttachedRelocationRadius = 64;
    static constexpr std::uint32_t kMaximumRelocationProbes = 1'048'576;
private:
    std::vector<World::TransientCompositionCell> immutable_occupancy_;
    std::vector<World::TransientCompositionCell> immutable_occupancy_backup_;
    std::vector<World::TransientCompositionCell> shard_occupancy_;
    World::TransientCompositionReceipt accepted_composition_{};
    std::uint64_t composed_material_revision_{};
    Registry registry_;
    std::unique_ptr<Pending> pending_;
    std::vector<BodyView> bodies_;
    std::vector<BodyView> body_backup_;
    std::unique_ptr<ComponentDiscovery> discovery_;
    std::vector<std::uint32_t> component_;
    AdmissionStatus admission_{};
    std::uint32_t admission_slots_{}, admission_area_{};
    std::uint64_t admission_calls_{};
    bool admission_resource_valid_{};
    std::vector<std::uint16_t> proposed_mask_;
    // Attached-only sparse traversal, bounded by the same raster capacity as
    // shard_occupancy_. The standalone Lab retains its historical allocation.
    std::vector<std::uint32_t> proposed_indices_;
    struct Relocation { std::int64_t from_x{},from_y{},to_x{},to_y{}; Payload payload{}; };
    std::vector<Relocation> relocations_;
    std::vector<std::uint8_t> reserved_destinations_;
    std::vector<std::uint8_t> ingress_exclusion_;
    std::vector<Exposure> exposures_;
    // One shared Lab contact field, never a World per shard. Low bits identify
    // the Fire carrier's pre-relocation lattice anchor for this semantic tick;
    // the high bit records its single accepted ignition opportunity.
    std::vector<std::uint32_t> fire_opportunities_;
    std::uint64_t fire_opportunity_tick_{};
    // Private derived history: Registry IDs are never reused, even on reset.
    // Public operations still validate full Handles; refresh resolves this ID
    // through the current body roster before consulting authoritative storage.
    struct PocketFence { std::uint64_t shard_id{};std::uint16_t min_x{},max_x{},row{}; };
    static_assert(sizeof(PocketFence)==16);
    std::vector<PocketFence> ingress_fences_;
    std::vector<PocketFence> ingress_fences_backup_;
    std::vector<TransferRequest> ingress_proposals_;
    std::uint64_t next_exposure_{1};
    std::vector<Receipt> receipts_;
    std::uint64_t retired_transaction_{};
    std::vector<std::uint8_t> materials_;
    std::vector<TerrainChunk> terrain_;
    std::uint64_t terrain_source_revision_{UINT64_MAX};
    std::vector<std::uint8_t> terrain_scratch_;
    Snapshot snapshot_{};
    Metrics metrics_{};
    Metrics historical_metrics_{};
    Accounting accounting_{};
    Result last_result_{};
    bool quarantined_{};
    std::uint32_t pause_calls_{};
    std::uint64_t pause_started_ns_{};

    void initialize_world();
    void initialize_attached_world(World& owner);
    void author_scenario(std::uint32_t scenario);
    [[nodiscard]] Result finish(Result result) noexcept;
    [[nodiscard]] bool resident(std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] bool immutable_occupied(std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] BodyView* body(Handle handle) noexcept;
    [[nodiscard]] const BodyView* body(Handle handle) const noexcept;
    void preserve_material_point_velocity(Handle handle, MassProperties previous) noexcept;
    [[nodiscard]] Outcome capture_component(std::uint32_t root);
    [[nodiscard]] Outcome capture_fragment(Handle parent);
    [[nodiscard]] Outcome prepare_reabsorption(const ShardEditRequest& request);
    [[nodiscard]] bool validate_reabsorption() const noexcept;
    [[nodiscard]] Outcome commit_reabsorption();
    [[nodiscard]] Result acknowledge_reabsorption(const Acknowledgement& receipt);
    [[nodiscard]] bool pending_conflict(Bounds bounds) const noexcept;
    void refresh_admission(std::uint32_t work);
    [[nodiscard]] bool validate_prepared() const noexcept;
    [[nodiscard]] Outcome commit_prepared();
    void rebuild_terrain();
    [[nodiscard]] Outcome apply_poses(std::span<const PoseSample> poses);
    [[nodiscard]] Outcome rebuild_mask(bool capture_contact);
    [[nodiscard]] Outcome capture_water(Shard& shard, const BodyView& body);
    [[nodiscard]] Outcome capture_fire_ignition(Shard& shard, const BodyView& body);
    [[nodiscard]] std::uint32_t& fire_opportunity(std::int64_t x, std::int64_t y) noexcept;
    [[nodiscard]] Outcome reconcile_overlap();
    void automatic_ingress(bool transfer = true);
    void refresh_ingress_fences();
    [[nodiscard]] bool pocket_fenced(Handle shard,std::uint32_t cell) const noexcept;
    [[nodiscard]] Outcome fence_invalid_entry(Handle shard,std::uint32_t cell);
    void advance_chemistry();
    void advance_products_and_exchange();
    void record_transition(Payload before, Payload after, bool expiry = false) noexcept;
    [[nodiscard]] Result remember(Result result, std::uint64_t fingerprint) noexcept;
    [[nodiscard]] const Receipt* prior(std::uint64_t sequence) const noexcept;
    [[nodiscard]] Result quarantine(Handle shard, const char* detail) noexcept;
};

} // namespace cybersand::object_shard
