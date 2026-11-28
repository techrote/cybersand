#pragma once

#include "cybersand/object_shard_coordinator.hpp"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <memory>
#include <thread>

namespace godot {

// Standalone Lab boundary: one exclusive native owner, copied values only.
// Neither Godot RIDs nor mutable World storage cross this interface.
class CyberObjectShardLab final : public RefCounted {
    GDCLASS(CyberObjectShardLab, RefCounted)
public:
    CyberObjectShardLab();
    ~CyberObjectShardLab() override;
    [[nodiscard]] Dictionary configure(const Dictionary& configuration);
    [[nodiscard]] Dictionary reset(std::int64_t scenario, std::int64_t seed);
    [[nodiscard]] Dictionary step(const Array& poses);
    [[nodiscard]] Dictionary accept_motion(const Array& poses);
    [[nodiscard]] Dictionary edit_cell(Vector2i position, std::int64_t material,
        std::int64_t state_a, std::int64_t state_b, std::int64_t temperature);
    [[nodiscard]] Dictionary erase_shard(const Dictionary& request);
    [[nodiscard]] Dictionary ignite(Vector2i position);
    [[nodiscard]] Dictionary ignite_shard(std::int64_t id, std::int64_t generation, std::int64_t cell);
    [[nodiscard]] Dictionary prepare_next();
    [[nodiscard]] Dictionary acknowledge(const Dictionary& receipt);
    [[nodiscard]] Dictionary cancel(std::int64_t transaction);
    [[nodiscard]] Dictionary snapshot(bool include_world = true);
    [[nodiscard]] Dictionary inspect(Vector2i position) const;
    [[nodiscard]] Dictionary capabilities() const;
    [[nodiscard]] Dictionary metrics() const;

protected:
    static void _bind_methods();

private:
    friend class CyberNativeCellWorld;
    // Bound exclusively to the existing Workbench native World.
    [[nodiscard]] Dictionary attach_owner_world(cybersand::World& world,
        cybersand::object_shard::Config config);
    [[nodiscard]] Dictionary after_owner_tick();
    [[nodiscard]] Dictionary workbench_action(const Dictionary& request);
    [[nodiscard]] Dictionary workbench_batch_action(const Dictionary& request,
        cybersand::object_shard::ShardAction action);
    [[nodiscard]] Dictionary act_on_shard(const Dictionary& request,
        cybersand::object_shard::ShardAction action);
    std::thread::id owner_;
    std::unique_ptr<cybersand::object_shard::Coordinator> coordinator_;
    bool failed_{};
    String failure_;
    Dictionary reabsorption_receipt_;
    struct CarrierCache {
        cybersand::object_shard::Handle handle{};
        std::uint64_t material_revision{};
        Dictionary values;
    };
    std::array<CarrierCache, cybersand::object_shard::OwnerReadback::kBodySlots> carrier_cache_{};
    [[nodiscard]] bool owned() const noexcept;
    [[nodiscard]] Dictionary refusal(const char* reason) const;
    [[nodiscard]] Dictionary result(const cybersand::object_shard::Result& value) const;
    [[nodiscard]] Dictionary fail(const char* reason);
    [[nodiscard]] Dictionary advance_native(const Array& poses, bool semantic_step);
};

} // namespace godot
