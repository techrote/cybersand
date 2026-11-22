#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <memory>

namespace godot {

// Desktop-only persistence primitive. It owns one OS profile lock and no World.
// All I/O is bounded, same-directory, and serialized. The GDScript area store
// supplies schema/identity checks and the manifest-last transaction protocol.
class CyberPersistentAreaStorage final : public RefCounted {
    GDCLASS(CyberPersistentAreaStorage, RefCounted)
    struct Impl;
    std::unique_ptr<Impl> impl_;
protected:
    static void _bind_methods();
public:
    CyberPersistentAreaStorage();
    ~CyberPersistentAreaStorage() override;
    Dictionary acquire(const String& profile_directory);
    void close_profile();
    Dictionary read_file(const String& name, int64_t maximum_bytes);
    Dictionary write_new(const String& name, const PackedByteArray& bytes);
    Dictionary publish(const String& stage, const String& target, const String& expected_target_sha256, const String& expected_stage_sha256);
    Dictionary remove_file(const String& name);
    Dictionary list_files();
    // Per-owner application-attributed filesystem calls/bytes. These include
    // kernel-cache hits and integrity readback, not physical-device I/O.
    Dictionary telemetry();
};

} // namespace godot
