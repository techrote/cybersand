#pragma once
#include "reciprocal.hpp"

namespace cybersand::gentek_swarm::assembly004 {

// Read-only SWARM-006 history admission, required before copying, hashing or
// replaying untrusted retained metadata. Every reachable dynamic field is
// bounded before traversal; retained capacities, allocation overhead, bounded
// final-validation scratch and hashing state count against the existing 16 MiB
// envelope (or either request's lower allowance). No history is copied here.
//
// This proves only bounded representation. Native source authority, exact
// digests/debits, geometry, ownership and obligation closure are separate gates.
// On failure reason is bounded and conservative_bytes is a partial bound, or
// allowance + 1 when memory admission fails. No input field is modified.
bool admit_recovery_history(const Composition&, std::string& reason,
                            std::uint64_t& conservative_bytes);

} // namespace cybersand::gentek_swarm::assembly004
