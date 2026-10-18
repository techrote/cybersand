#pragma once

#include "cybersand/world_generation.hpp"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2i.hpp>

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
    [[nodiscard]] Dictionary generate_chunk(Vector2i coord, const String& diagnostic = String()) const;
    [[nodiscard]] Dictionary begin_chunk(Vector2i coord, const String& diagnostic = String());
    [[nodiscard]] Dictionary advance(std::int64_t cell_budget);

protected:
    static void _bind_methods();

private:
    std::shared_ptr<const cybersand::generation::Generator> generator_;
    std::unique_ptr<cybersand::generation::GenerationJob> job_;
    Dictionary configuration_;
    std::uint64_t revision_ = 0;
    cybersand::ChunkCoord job_chunk_{};

    [[nodiscard]] Dictionary metadata(cybersand::ChunkCoord coord) const;
    [[nodiscard]] Dictionary job_status() const;
    [[nodiscard]] Dictionary copy_result(const cybersand::generation::ChunkResult& result) const;
};

} // namespace godot
