#pragma once

#include <godot_cpp/variant/string.hpp>

namespace godot::material_baseline_file {

// Commit a fully written, closed staging file in the target's directory. An
// empty error means success; no failed call deliberately removes either entry.
// This is a filesystem commit only: it never accesses a live World.
[[nodiscard]] String replace(const String& temporary, const String& target);

} // namespace godot::material_baseline_file
