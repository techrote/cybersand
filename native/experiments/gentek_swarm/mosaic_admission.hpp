#pragma once
#include "negotiated.hpp"

#include <array>

namespace cybersand::gentek_swarm {

// SWARM-003 research-only local screening. These are MOSAIC category masks,
// never instructions emitted by FRAMEWEAVER. No solve or assignment is read.
using NativeAdjacency = std::array<std::array<std::uint16_t, 16>, 4>;
struct NativeAdmissionDecision {
    std::uint32_t slot_id{};
    std::int32_t tile = -1;
    bool hard = false, geometry_admitted = false;
    bool selected = false, fallback_selected = false;
    bool domain_changed = false, fallback_domain_changed = false;
    int rank = -1, distance = -1;
    Point contact{};
    std::uint16_t compatible_domain{}, locally_supported_domain{};
    std::uint16_t original_domain{}, hard_domain{}, projected_domain{}, fallback_domain{};
    std::array<std::uint16_t, 4> neighbor_pool{};
    unsigned neighbor_support{};
    std::uint32_t conflicts_with{};
    std::string disposition, reason;
};
struct NativeAdmissionReceipt {
    Status status = Status::Complete;
    std::string reason;
    std::vector<std::uint32_t> selected_ids, fallback_ids;
    std::vector<NativeAdmissionDecision> decisions;
    std::vector<std::uint16_t> original_domains, hard_domains, preferred_domains, fallback_domains;
    std::uint64_t work{};
    std::uint32_t optional_capacity = 4, fallback_optional_capacity = 2;
};

// Called after all geometric/native receiving responses have been discovered,
// before any offered domain is installed or GEN-003 is invoked. The raw native
// compatible masks are not pruned: supported masks only screen/rank offers.
// Every visit and compatibility check debits the existing MOSAIC work allowance.
// The optional fallback core is fixed here, before the first solve. Defaults
// preserve the reconstructed cap-four policy; the registered continuation also
// admits capacities zero, six and eight. Zero capacity requires zero fallback.
NativeAdmissionReceipt screen_mosaic_offers(
    const Request&, Result& accounting, std::uint32_t width, std::uint32_t height,
    const NativeAdjacency&, const std::vector<TransitionSlot>&, const MosaicPlan& discovered,
    std::uint32_t optional_capacity = 4, std::uint32_t fallback_optional_capacity = 2);

} // namespace cybersand::gentek_swarm
