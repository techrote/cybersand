#pragma once

#include "reciprocal.hpp"

namespace cybersand::gentek_swarm::assembly004 {

// A separate bounded scientific rerun, never a candidate revision or World
// commit. Its arrays and failed solver receipts are retained verbatim.
void write_matched_mosaic_control_json(const std::string& path, const std::string& policy,
    const Composition& candidate, const Request& accepted_request,
    const MosaicRevision& control, std::uint64_t changed_frame_cells);

} // namespace cybersand::gentek_swarm::assembly004
