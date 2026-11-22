#pragma once

#include "cybersand/object_shard.hpp"
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
    double max_rotation_per_step{0.20};
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
    PhysicsReserved, TerrainInstalled, BodyActivated, GeometryInstalled, BodyRetired
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
};
struct BodyView {
    Handle shard{};
    std::uint64_t transaction{}, body_generation{};
    PoseSample pose{};
    PoseSample previous_pose{};
    std::uint64_t geometry_pending_tick{},geometry_pending_ns{};
    bool has_body{}, geometry_pending{}, pocket_open{},ingress_fenced{};
    std::uint32_t pocket_cell{};
};
struct Accounting {
    std::array<std::uint64_t, kQuantityMaterialSlots> promoted{}, ingested{}, emitted{};
    std::array<std::uint64_t, kQuantityMaterialSlots> created{}, destroyed{}, expired{}, reset_disposed{};
    std::array<std::uint64_t, kQuantityMaterialSlots> setup_created{}, authored_created{}, authored_destroyed{};
    std::array<std::int64_t, kQuantityMaterialSlots> world_tick_delta{};
    std::uint64_t reset_water_quanta{};
    std::uint64_t extinguished{}, accepted_exposures{}, consumed_exposures{};
};
struct Metrics {
    std::uint64_t steps{}, paused_calls{}, discovered_cells{}, promotions{}, refusals{};
    std::uint64_t chemistry_cells{}, products_created{}, output_blocked{}, sand_ingested{};
    std::uint64_t exposure_overflows{}, stale_messages{}, mask_cells{}, sweep_samples{},ingress_blocked{};
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
    // Valid until the next coordinator call; the facade copies these values.
    std::span<const std::uint8_t> world_materials{};
    std::span<const TerrainChunk> terrain_chunks{};
    std::span<const Shard> shards{};
    std::span<const BodyView> bodies{};
    Accounting accounting{};
    Metrics metrics{};
};
struct Exposure {
    Handle shard{};
    std::uint32_t cell{}, incarnation{};
    std::uint64_t geometry_revision{}, pose_serial{}, first_tick{}, expiry_tick{}, sequence{};
    bool consumed{};
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

class Coordinator {
public:
    explicit Coordinator(Config config = {});
    ~Coordinator();
    Coordinator(const Coordinator&) = delete;
    Coordinator& operator=(const Coordinator&) = delete;
    [[nodiscard]] const Config& config() const noexcept { return config_; }
    [[nodiscard]] const World& world() const noexcept { return *world_; }
    [[nodiscard]] const Registry& registry() const noexcept { return registry_; }
    [[nodiscard]] Result reset(std::uint32_t scenario, std::uint64_t seed);
    [[nodiscard]] Result step(std::span<const PoseSample> poses = {});
    [[nodiscard]] Result edit(std::int64_t x, std::int64_t y, Payload value);
    [[nodiscard]] Result ignite(std::int64_t x, std::int64_t y);
    [[nodiscard]] Result ignite_shard(Handle shard, std::uint32_t cell);
    [[nodiscard]] Result prepare_next();
    [[nodiscard]] Result acknowledge(const Acknowledgement& receipt);
    [[nodiscard]] Result cancel(std::uint64_t transaction);
    [[nodiscard]] Result ingest(const TransferRequest& request);
    [[nodiscard]] Result emit(const TransferRequest& request);
    [[nodiscard]] const Snapshot& snapshot();
    [[nodiscard]] Payload inspect_world(std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] const Metrics& metrics() const noexcept { return metrics_; }
    [[nodiscard]] const Accounting& accounting() const noexcept { return accounting_; }
    [[nodiscard]] std::uint64_t next_transaction() const noexcept { return next_transaction_; }
    [[nodiscard]] std::uint64_t world_witness(std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] bool paused() const noexcept;

private:
    friend struct CoordinatorTestAccess;
    struct Pending;
    struct Receipt;
    Config config_;
    std::uint64_t session_{1}, world_incarnation_{1}, next_transaction_{1};
    std::unique_ptr<World> world_;
    Registry registry_;
    std::unique_ptr<Pending> pending_;
    std::vector<BodyView> bodies_;
    std::vector<BodyView> body_backup_;
    std::vector<std::uint32_t> discovery_queue_, component_, seen_;
    std::vector<std::uint8_t> discovery_skip_;
    std::uint32_t discovery_serial_{1};
    std::uint32_t discovery_remaining_{};
    std::vector<std::uint16_t> proposed_mask_;
    struct Relocation { std::int64_t from_x{},from_y{},to_x{},to_y{}; Payload payload{}; };
    std::vector<Relocation> relocations_;
    std::vector<std::uint8_t> reserved_destinations_;
    std::vector<std::uint8_t> ingress_exclusion_;
    std::vector<Exposure> exposures_;
    struct PocketFence { Handle shard{};std::uint16_t min_x{},max_x{},row{}; };
    std::vector<PocketFence> ingress_fences_;
    std::vector<TransferRequest> ingress_proposals_;
    std::uint64_t next_exposure_{1};
    std::vector<Receipt> receipts_;
    std::uint64_t retired_transaction_{};
    std::vector<std::uint8_t> materials_;
    std::vector<TerrainChunk> terrain_;
    std::vector<std::uint8_t> terrain_scratch_;
    Snapshot snapshot_{};
    Metrics metrics_{};
    Accounting accounting_{};
    Result last_result_{};
    bool quarantined_{};
    std::uint32_t pause_calls_{};
    std::uint64_t pause_started_ns_{};

    void initialize_world();
    void author_scenario(std::uint32_t scenario);
    [[nodiscard]] Result finish(Result result) noexcept;
    [[nodiscard]] bool resident(std::int64_t x, std::int64_t y) const noexcept;
    [[nodiscard]] BodyView* body(Handle handle) noexcept;
    [[nodiscard]] const BodyView* body(Handle handle) const noexcept;
    [[nodiscard]] Outcome capture_component(std::int64_t x, std::int64_t y);
    [[nodiscard]] bool validate_prepared() const noexcept;
    [[nodiscard]] Outcome commit_prepared();
    void rebuild_terrain();
    [[nodiscard]] Outcome apply_poses(std::span<const PoseSample> poses);
    [[nodiscard]] Outcome rebuild_mask(bool capture_contact);
    [[nodiscard]] Outcome capture_water(Shard& shard, const BodyView& body);
    [[nodiscard]] Outcome reconcile_overlap();
    void automatic_ingress();
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
