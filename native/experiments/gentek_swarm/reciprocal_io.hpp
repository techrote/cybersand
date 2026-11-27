#pragma once

#include "reciprocal.hpp"
#include "custody_hash.hpp"

namespace cybersand::gentek_swarm::assembly004 {

// Binary-array canonical encoding v1 of every immutable native input/proposal
// field. Streaming only; no temporary JSON, World write or authority creation.
CustodyDigest fingerprint_native_custody(const Composition&, std::uint64_t& charged,
    std::uint64_t ceiling);

// A separate bounded scientific rerun, never a candidate revision or World
// commit. Its arrays and failed solver receipts are retained verbatim.
void write_matched_mosaic_control_json(const std::string& path, const std::string& policy,
    const Composition& candidate, const Request& accepted_request,
    const MosaicRevision& control, std::uint64_t changed_frame_cells);

} // namespace cybersand::gentek_swarm::assembly004
