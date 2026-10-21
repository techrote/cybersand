#pragma once

#include "cybersand/world_generation.hpp"
#include "cybersand/generation_planes.hpp"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/rect2i.hpp>

#include <memory>

namespace godot {

// One serialized owner, independent of World and Rapier. Returned Dictionaries
// contain copied values. No mutable generator or cell storage crosses the API.
class CyberWorldGenerator final : public RefCounted {
    GDCLASS(CyberWorldGenerator, RefCounted)
public:
    CyberWorldGenerator();
    ~CyberWorldGenerator() override;

    [[nodiscard]] Dictionary configure(const Dictionary& recipe);
    [[nodiscard]] Dictionary get_configuration() const;
    [[nodiscard]] Dictionary get_catalogue() const;
    [[nodiscard]] Dictionary get_semantic_plan() const;
    [[nodiscard]] Dictionary validate_routes() const;
    [[nodiscard]] Dictionary inspect_cell(Vector2i position) const;
    [[nodiscard]] Dictionary get_plane_plan() const;
    [[nodiscard]] Dictionary generate_plane_bundle() const;
    [[nodiscard]] Dictionary generate_plane_region(Rect2i bounds) const;
    [[nodiscard]] Dictionary begin_plane_region(Rect2i bounds);
    [[nodiscard]] Dictionary advance_plane_region(std::int64_t cell_budget);
    [[nodiscard]] Dictionary cancel_plane_region();
    [[nodiscard]] Dictionary inspect_plane_cell(const String& plane, Vector2i position) const;
    [[nodiscard]] Dictionary generate_chunk(Vector2i coord, const String& diagnostic = String()) const;
    [[nodiscard]] Dictionary begin_chunk(Vector2i coord, const String& diagnostic = String());
    [[nodiscard]] Dictionary advance(std::int64_t cell_budget);

protected:
    static void _bind_methods();

private:
    std::shared_ptr<const cybersand::generation::Generator> generator_;
    std::unique_ptr<cybersand::generation::GenerationJob> job_;
    std::shared_ptr<const cybersand::generation::PlanePlan> plane_plan_;
    std::unique_ptr<cybersand::generation::PlaneGenerationJob> plane_job_;
    Dictionary configuration_;
    std::uint64_t revision_ = 0;
    cybersand::ChunkCoord job_chunk_{};

    [[nodiscard]] Dictionary metadata(cybersand::ChunkCoord coord) const;
    [[nodiscard]] Dictionary job_status() const;
    [[nodiscard]] Dictionary copy_result(const cybersand::generation::ChunkResult& result) const;
    [[nodiscard]] Dictionary copy_plane_result(const cybersand::generation::PlaneResult& result, bool complete) const;
};

} // namespace godot
