#include "mosaic_admission.hpp"

#include <algorithm>
#include <bit>
#include <limits>
#include <numeric>
#include <set>
#include <tuple>

namespace cybersand::gentek_swarm {
namespace {
constexpr std::array<Point, 4> cardinal{{{1, 0}, {0, 1}, {-1, 0}, {0, -1}}};
constexpr std::uint16_t category_bit(unsigned category) {
    return static_cast<std::uint16_t>(1U << category);
}

class LocalScreen {
public:
    LocalScreen(const Request& request, Result& result, std::uint32_t width,
                std::uint32_t height, const NativeAdjacency& adjacency)
        : request_(request), result_(result), width_(width), height_(height), adjacency_(adjacency) {}

    bool spend(std::uint64_t amount = 1) { return charge(request_, result_, amount); }
    int neighbor(std::size_t tile, unsigned direction) const {
        const int x = static_cast<int>(tile % width_) + cardinal[direction].x;
        const int y = static_cast<int>(tile / width_) + cardinal[direction].y;
        if (x < 0 || y < 0 || x >= static_cast<int>(width_) || y >= static_cast<int>(height_)) return -1;
        return y * static_cast<int>(width_) + x;
    }

    // One local star only. No iterative propagation, assignment, backtracking,
    // or category reordering. Both native directed adjacencies must support a
    // pair, as in GEN-003's unchanged cardinal constraints.
    bool support(std::size_t tile, std::uint16_t domain,
                 const std::vector<std::uint16_t>& pools, std::uint16_t& supported,
                 unsigned& score, std::array<std::uint16_t, 4>* seen = nullptr) {
        supported = 0; score = 0;
        for (unsigned direction = 0; direction < cardinal.size(); ++direction) {
            if (!spend()) return false;
            const int other = neighbor(tile, direction);
            if (seen) (*seen)[direction] = other < 0 ? 0 : pools[static_cast<std::size_t>(other)];
        }
        for (unsigned a = 0; a < 16; ++a) {
            if (!spend()) return false;
            if (!(domain & category_bit(a))) continue;
            bool valid = true;
            unsigned category_support = 0;
            for (unsigned direction = 0; direction < cardinal.size(); ++direction) {
                const int other = neighbor(tile, direction);
                if (other < 0) continue;
                bool pair_found = false;
                for (unsigned b = 0; b < 16; ++b) {
                    if (!spend()) return false;
                    if ((pools[static_cast<std::size_t>(other)] & category_bit(b)) &&
                        (adjacency_[direction][a] & category_bit(b)) &&
                        (adjacency_[(direction + 2U) % 4U][b] & category_bit(a))) {
                        pair_found = true; ++category_support;
                    }
                }
                valid = valid && pair_found;
            }
            if (valid) { supported |= category_bit(a); score += category_support; }
        }
        return true;
    }

private:
    const Request& request_;
    Result& result_;
    std::uint32_t width_, height_;
    const NativeAdjacency& adjacency_;
};
} // namespace

NativeAdmissionReceipt screen_mosaic_offers(
    const Request& request, Result& accounting, std::uint32_t width, std::uint32_t height,
    const NativeAdjacency& adjacency, const std::vector<TransitionSlot>& slots,
    const MosaicPlan& discovered, std::uint32_t optional_capacity,
    std::uint32_t fallback_optional_capacity) {
    NativeAdmissionReceipt out;
    out.optional_capacity = optional_capacity;
    out.fallback_optional_capacity = fallback_optional_capacity;
    const auto initial_work = accounting.work;
    const auto finish = [&](Status status, const std::string& reason) {
        out.status = status; out.reason = reason; out.work = accounting.work - initial_work;
        std::sort(out.selected_ids.begin(), out.selected_ids.end());
        std::sort(out.fallback_ids.begin(), out.fallback_ids.end());
        return out;
    };
    if ((optional_capacity != 0 && optional_capacity != 4 && optional_capacity != 6 && optional_capacity != 8) ||
        (fallback_optional_capacity != 0 && fallback_optional_capacity != 2) ||
        fallback_optional_capacity > optional_capacity)
        return finish(Status::Invalid, "local admission requires registered optional capacity 0/4/6/8 and fallback capacity 0 or 2 no greater than it");
    if (width == 0 || height == 0 || width > 16 || height > 16 ||
        slots.size() > max_transition_slots || discovered.responses.size() != slots.size() ||
        discovered.domains.size() != static_cast<std::size_t>(width) * height)
        return finish(Status::Invalid, "local admission requires at most eight responses and an intact 16x16 native domain grid");
    LocalScreen screen(request, accounting, width, height, adjacency);
    const auto exhausted = [&]() {
        return finish(Status::Exhausted, "MOSAIC local admission exhausted the unchanged generator work allowance; no solve authorized");
    };
    std::set<std::uint32_t> slot_ids, response_ids;
    for (const auto& slot : slots) {
        if (!screen.spend()) return exhausted();
        if (slot.id == 0 || !slot_ids.insert(slot.id).second)
            return finish(Status::Invalid, "local admission requires unique nonzero mechanical offer identities");
    }
    for (const auto& response : discovered.responses) {
        if (!screen.spend()) return exhausted();
        if (!slot_ids.contains(response.slot_id) || !response_ids.insert(response.slot_id).second ||
            (response.admitted && (response.tile >= discovered.domains.size() || response.compatible_domain == 0)))
            return finish(Status::Invalid, "local admission response identity, native domain or tile is invalid");
    }
    for (std::size_t tile = 0; tile < discovered.domains.size(); ++tile) {
        if (!screen.spend()) return exhausted();
        const auto& domain = discovered.domains[tile];
        if (domain.tile != tile || domain.original_domain == 0)
            return finish(Status::Invalid, "local admission requires ordered nonempty original native domains");
        out.original_domains.push_back(domain.original_domain);
    }
    if (!screen.spend(out.original_domains.size())) return exhausted();
    out.hard_domains = out.original_domains;
    std::vector<bool> hard_tile(out.original_domains.size(), false);
    // Canonical identity order also makes receipts independent of caller offer
    // order. No fixture name, generator seed, or successful historical outcome
    // is consulted by this policy.
    std::vector<const TransitionSlot*> ordered;
    for (const auto& slot : slots) {
        if (!screen.spend()) return exhausted();
        ordered.push_back(&slot);
    }
    if (!screen.spend(max_transition_slots * max_transition_slots)) return exhausted();
    std::sort(ordered.begin(), ordered.end(), [](const auto* a, const auto* b) { return a->id < b->id; });
    bool impossible_hard = false;
    for (const auto* slot_pointer : ordered) {
        const auto& slot = *slot_pointer;
        if (!screen.spend(max_transition_slots)) return exhausted();
        const auto found = std::find_if(discovered.responses.begin(), discovered.responses.end(),
                                       [&](const auto& value) { return value.slot_id == slot.id; });
        NativeAdmissionDecision decision;
        decision.slot_id = slot.id; decision.hard = slot.required || slot.hard;
        decision.geometry_admitted = found->admitted; decision.contact = found->contact;
        decision.compatible_domain = found->compatible_domain;
        if (found->admitted) {
            decision.tile = static_cast<std::int32_t>(found->tile);
            decision.original_domain = out.original_domains[found->tile];
            const int nearest_x = std::clamp(found->contact.x, std::min(slot.a.x, slot.b.x), std::max(slot.a.x, slot.b.x));
            const int nearest_y = std::clamp(found->contact.y, std::min(slot.a.y, slot.b.y), std::max(slot.a.y, slot.b.y));
            const auto dx = static_cast<std::int64_t>(found->contact.x) - nearest_x;
            const auto dy = static_cast<std::int64_t>(found->contact.y) - nearest_y;
            const auto distance = (dx < 0 ? -dx : dx) + (dy < 0 ? -dy : dy);
            if (distance > std::numeric_limits<int>::max())
                return finish(Status::Invalid, "local admission contact distance is outside finite geometry");
            decision.distance = static_cast<int>(distance);
        }
        if (decision.hard) {
            // A required obligation retains authority even when impossible;
            // a caller must stop on this explicit hard failure, not omit it.
            decision.selected = decision.fallback_selected = true;
            out.selected_ids.push_back(slot.id); out.fallback_ids.push_back(slot.id);
            if (!found->admitted) {
                impossible_hard = true;
                decision.disposition = "required-impossible";
                decision.reason = "required mechanical offer has no authored native receiving face";
            } else {
                const auto tile = found->tile;
                if (!hard_tile[tile]) out.hard_domains[tile] = found->compatible_domain;
                else out.hard_domains[tile] &= found->compatible_domain;
                hard_tile[tile] = true;
                decision.disposition = "required-admitted";
                decision.reason = "hard mechanical obligation retained in every attempted domain set";
            }
        } else {
            decision.disposition = "optional-pending";
            decision.reason = "native local screen pending; no solve result has been observed";
        }
        out.decisions.push_back(std::move(decision));
    }
    for (auto& decision : out.decisions) {
        if (!screen.spend()) return exhausted();
        if (decision.tile < 0) continue;
        decision.hard_domain = out.hard_domains[static_cast<std::size_t>(decision.tile)];
        if (decision.hard && decision.hard_domain == 0) {
            impossible_hard = true;
            decision.disposition = "required-impossible";
            decision.reason = "native receiving masks of required offers have an empty intersection";
        }
    }
    if (!screen.spend(2U * out.hard_domains.size())) return exhausted();
    out.preferred_domains = out.fallback_domains = out.hard_domains;
    if (impossible_hard)
        return finish(Status::Unsat, "required native receiving obligation is impossible before optional admission");

    if (!screen.spend(out.hard_domains.size())) return exhausted();
    auto optimistic = out.hard_domains;
    for (const auto& decision : out.decisions) {
        if (!screen.spend()) return exhausted();
        if (!decision.hard && decision.geometry_admitted && !hard_tile[static_cast<std::size_t>(decision.tile)])
            optimistic[static_cast<std::size_t>(decision.tile)] |= decision.compatible_domain;
    }
    for (auto& decision : out.decisions) {
        if (!screen.spend()) return exhausted();
        if (decision.hard) continue;
        if (!decision.geometry_admitted) {
            decision.disposition = "optional-locally-incompatible";
            decision.reason = "no native material face with the required thickness/contact geometry";
            continue;
        }
        const auto tile = static_cast<std::size_t>(decision.tile);
        const auto possible = hard_tile[tile] ? static_cast<std::uint16_t>(decision.compatible_domain & out.hard_domains[tile])
                                              : decision.compatible_domain;
        if (!screen.support(tile, possible, optimistic, decision.locally_supported_domain,
                            decision.neighbor_support, &decision.neighbor_pool)) return exhausted();
        if (decision.locally_supported_domain == 0) {
            decision.disposition = "optional-locally-incompatible";
            decision.reason = "no receiving category has cardinal support even in the optimistic native neighborhood";
        }
    }
    std::vector<std::size_t> ranking;
    for (std::size_t i = 0; i < out.decisions.size(); ++i) {
        if (!screen.spend()) return exhausted();
        if (!out.decisions[i].hard) ranking.push_back(i);
    }
    if (!screen.spend(max_transition_slots * max_transition_slots)) return exhausted();
    std::sort(ranking.begin(), ranking.end(), [&](auto a, auto b) {
        const auto& left = out.decisions[a]; const auto& right = out.decisions[b];
        return std::tuple{-std::popcount(left.locally_supported_domain), -static_cast<int>(left.neighbor_support),
                          left.distance < 0 ? std::numeric_limits<int>::max() : left.distance, left.slot_id} <
               std::tuple{-std::popcount(right.locally_supported_domain), -static_cast<int>(right.neighbor_support),
                          right.distance < 0 ? std::numeric_limits<int>::max() : right.distance, right.slot_id};
    });
    if (!screen.spend(hard_tile.size() + optimistic.size())) return exhausted();
    auto constrained = hard_tile;
    auto selected_pool = optimistic;
    unsigned accepted = 0;
    for (std::size_t rank = 0; rank < ranking.size(); ++rank) {
        if (!screen.spend()) return exhausted();
        auto& decision = out.decisions[ranking[rank]];
        decision.rank = static_cast<int>(rank);
        if (!decision.locally_supported_domain) continue;
        if (accepted == out.optional_capacity) {
            decision.disposition = "optional-not-selected-within-capacity";
            decision.reason = out.optional_capacity == 4
                ? "four higher-ranked optional offers already admitted; no solve-dependent refill"
                : out.optional_capacity == 0
                    ? "zero optional capacity diagnostic; all required obligations retained"
                    : std::to_string(out.optional_capacity) + " higher-ranked optional offers already admitted; no solve-dependent refill";
            continue;
        }
        const auto tile = static_cast<std::size_t>(decision.tile);
        const auto before = out.preferred_domains[tile];
        const auto proposed = constrained[tile] ? static_cast<std::uint16_t>(before & decision.compatible_domain)
                                               : decision.compatible_domain;
        if (!screen.spend(selected_pool.size())) return exhausted();
        auto trial = selected_pool;
        trial[tile] = proposed;
        std::uint16_t supported = 0;
        unsigned unused_score = 0;
        bool valid = proposed != 0;
        if (valid && !screen.support(tile, proposed, trial, supported, unused_score)) return exhausted();
        valid = valid && supported != 0;
        std::size_t conflict_tile = tile;
        for (unsigned direction = 0; direction < cardinal.size() && valid; ++direction) {
            if (!screen.spend()) return exhausted();
            const int adjacent = screen.neighbor(tile, direction);
            if (adjacent < 0 || !constrained[static_cast<std::size_t>(adjacent)]) continue;
            const auto other = static_cast<std::size_t>(adjacent);
            if (!screen.support(other, trial[other], trial, supported, unused_score)) return exhausted();
            if (supported == 0) { valid = false; conflict_tile = other; }
        }
        if (!valid) {
            decision.disposition = "optional-competing";
            decision.reason = "receiving domain conflicts locally with an earlier native or required opportunity";
            for (const auto& existing : out.decisions) {
                if (!screen.spend()) return exhausted();
                if (existing.selected && existing.tile >= 0 &&
                    static_cast<std::size_t>(existing.tile) == conflict_tile) {
                    decision.conflicts_with = existing.slot_id; break;
                }
            }
            continue;
        }
        decision.selected = true; decision.domain_changed = proposed != before;
        decision.projected_domain = proposed;
        decision.disposition = decision.domain_changed ? "optional-admitted" : "optional-redundant-admitted";
        decision.reason = decision.domain_changed
            ? "native receiving opportunity passed finite local screening and changes the selected tile domain"
            : "same native domain already admitted; explicit join authority retained and one optional capacity position consumed";
        out.selected_ids.push_back(decision.slot_id);
        out.preferred_domains[tile] = proposed;
        constrained[tile] = true; selected_pool[tile] = proposed;
        ++accepted;
        if (accepted <= out.fallback_optional_capacity) {
            decision.fallback_selected = true; out.fallback_ids.push_back(decision.slot_id);
        }
    }
    if (!screen.spend(hard_tile.size())) return exhausted();
    auto fallback_constrained = hard_tile;
    for (const auto index : ranking) {
        if (!screen.spend()) return exhausted();
        auto& decision = out.decisions[index];
        if (!decision.fallback_selected) continue;
        const auto tile = static_cast<std::size_t>(decision.tile);
        const auto before = out.fallback_domains[tile];
        out.fallback_domains[tile] = fallback_constrained[tile]
            ? static_cast<std::uint16_t>(before & decision.compatible_domain) : decision.compatible_domain;
        fallback_constrained[tile] = true;
        decision.fallback_domain_changed = before != out.fallback_domains[tile];
    }
    for (auto& decision : out.decisions) {
        if (!screen.spend()) return exhausted();
        if (decision.tile < 0) continue;
        const auto tile = static_cast<std::size_t>(decision.tile);
        decision.projected_domain = out.preferred_domains[tile];
        decision.fallback_domain = out.fallback_domains[tile];
    }
    const std::string reason = optional_capacity == 4 && fallback_optional_capacity == 2
        ? "native flexibility/support/distance/ID order; four optional offers, fixed top-two fallback; one-hop screening is not a global satisfiability proof"
        : "native flexibility/support/distance/ID order; optional capacity " + std::to_string(optional_capacity) +
          ", fixed fallback capacity " + std::to_string(fallback_optional_capacity) +
          "; one-hop screening is not a global satisfiability proof";
    return finish(Status::Complete, reason);
}
} // namespace cybersand::gentek_swarm
