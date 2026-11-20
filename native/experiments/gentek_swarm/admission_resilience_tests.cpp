#include "mosaic_admission.hpp"

#include <algorithm>
#include <array>
#include <functional>
#include <iostream>
#include <stdexcept>
#include <string>

using namespace cybersand::gentek_swarm;
namespace {
void require(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}
struct Case {
    Request request;
    std::uint32_t width = 1, height = 1;
    NativeAdjacency adjacency{};
    std::vector<TransitionSlot> slots;
    MosaicPlan discovered;
    Case(std::uint32_t w, std::uint32_t h, std::uint16_t domain = 3) : width(w), height(h) {
        request.gentek = Kind::Mosaic;
        request.width = static_cast<int>(16 * w); request.height = static_cast<int>(16 * h);
        for (auto& direction : adjacency) direction.fill(0xffff);
        for (std::uint32_t tile = 0; tile < w * h; ++tile) {
            DomainDecision row; row.tile = tile; row.original_domain = domain;
            row.origin = {static_cast<int>(tile % w) * 16, static_cast<int>(tile / w) * 16};
            discovered.domains.push_back(row);
        }
    }
    void offer(std::uint32_t id, std::uint32_t tile, std::uint16_t receiving,
               bool hard = false, bool admitted = true) {
        TransitionSlot slot; slot.id = id; slot.instance = slot.connector = id;
        slot.required = slot.hard = hard; slot.a = slot.b = {static_cast<int>(tile % width) * 16, 0};
        slot.facing = {1, 0}; slots.push_back(slot);
        SlotResponse response; response.slot_id = id; response.tile = tile; response.admitted = admitted;
        response.contact = {slot.a.x + 1, 0}; response.compatible_domain = receiving;
        discovered.responses.push_back(response);
    }
    NativeAdmissionReceipt run(Result* charge_receipt = nullptr, std::uint32_t capacity = 4,
                               std::uint32_t fallback_capacity = 2) const {
        Result account; const auto receipt = screen_mosaic_offers(request, account, width, height,
                                                                 adjacency, slots, discovered, capacity, fallback_capacity);
        if (charge_receipt) *charge_receipt = account;
        require(receipt.work == account.work, "admission failed to charge its exact reported work");
        require(account.work <= request.limits.max_work, "admission exceeded unchanged generator allowance");
        return receipt;
    }
    void equal_categories_only() {
        for (auto& direction : adjacency)
            for (unsigned category = 0; category < 16; ++category)
                direction[category] = static_cast<std::uint16_t>(1U << category);
    }
};
const NativeAdmissionDecision& decision(const NativeAdmissionReceipt& result, std::uint32_t id) {
    const auto found = std::find_if(result.decisions.begin(), result.decisions.end(),
                                  [&](const auto& value) { return value.slot_id == id; });
    require(found != result.decisions.end(), "offer disappeared from native disposition receipts");
    return *found;
}
void same(const NativeAdmissionReceipt& a, const NativeAdmissionReceipt& b) {
    require(a.status == b.status && a.selected_ids == b.selected_ids && a.fallback_ids == b.fallback_ids &&
            a.original_domains == b.original_domains && a.hard_domains == b.hard_domains &&
            a.preferred_domains == b.preferred_domains && a.fallback_domains == b.fallback_domains &&
            a.work == b.work && a.decisions.size() == b.decisions.size(), "native admission changed with evaluation order or irrelevant input");
    for (std::size_t i = 0; i < a.decisions.size(); ++i) {
        const auto& left = a.decisions[i]; const auto& right = b.decisions[i];
        require(left.slot_id == right.slot_id && left.tile == right.tile && left.rank == right.rank &&
                left.disposition == right.disposition && left.reason == right.reason &&
                left.selected == right.selected && left.fallback_selected == right.fallback_selected &&
                left.locally_supported_domain == right.locally_supported_domain &&
                left.neighbor_pool == right.neighbor_pool && left.neighbor_support == right.neighbor_support &&
                left.conflicts_with == right.conflicts_with && left.domain_changed == right.domain_changed,
                "native disposition changed with evaluation order or irrelevant input");
    }
}
} // namespace

int main() {
    unsigned passed = 0;
    const auto test = [&](const std::string& name, const std::function<void()>& body) {
        body(); ++passed; std::cout << "PASS " << name << '\n';
    };
    try {
        test("fixed capacity, flexibility rank and preselected fallback", [] {
            Case value(6, 1);
            for (unsigned id = 1; id <= 6; ++id) value.offer(id, id - 1, id == 3 ? 3 : 1);
            const auto result = value.run();
            require(result.status == Status::Complete && result.selected_ids.size() == 4 && result.fallback_ids.size() == 2,
                    "fixed preferred/fallback capacities were not applied");
            require(decision(result, 3).rank == 0 && decision(result, 3).selected && decision(result, 3).fallback_selected,
                    "native two-choice opportunity did not rank before single choices");
            require(result.decisions.size() == 6, "capacity silently removed offer receipt");
        });
        test("all hard offers retained outside optional capacity", [] {
            Case value(8, 1);
            for (unsigned id = 1; id <= 8; ++id) value.offer(id, id - 1, 3, id <= 2);
            const auto result = value.run();
            require(result.selected_ids.size() == 6 && result.fallback_ids.size() == 4, "hard offers consumed optional capacity");
            for (unsigned id : {1U, 2U}) require(decision(result, id).selected && decision(result, id).fallback_selected,
                                               "required offer dropped from preferred or fallback");
        });
        test("required without native face is explicit hard failure", [] {
            Case value(1, 1); value.offer(1, 0, 0, true, false);
            const auto result = value.run();
            require(result.status == Status::Unsat && result.selected_ids == std::vector<std::uint32_t>{1} &&
                    result.fallback_ids == result.selected_ids && decision(result, 1).disposition == "required-impossible",
                    "required failure was dropped or softened");
        });
        test("conflicting required native domains stay UNSAT", [] {
            Case value(1, 1); value.offer(1, 0, 1, true); value.offer(2, 0, 2, true);
            const auto result = value.run();
            require(result.status == Status::Unsat && result.hard_domains[0] == 0 && result.selected_ids.size() == 2,
                    "mandatory categorical contradiction was concealed");
        });
        test("unsupported optional is rejected without global UNSAT claim", [] {
            Case value(2, 1, 2); value.equal_categories_only(); value.offer(1, 0, 1);
            const auto result = value.run();
            require(result.status == Status::Complete && result.selected_ids.empty() &&
                    decision(result, 1).disposition == "optional-locally-incompatible",
                    "local optional impossibility became a false global failure");
        });
        test("redundant offers preserve explicit join authority and consume capacity", [] {
            Case value(1, 1); for (unsigned id = 1; id <= 5; ++id) value.offer(id, 0, 3);
            const auto result = value.run();
            require(result.selected_ids.size() == 4 && result.fallback_ids.size() == 2, "redundancy bypassed fixed capacity");
            for (unsigned id = 1; id <= 4; ++id)
                require(decision(result, id).disposition == "optional-redundant-admitted" && !decision(result, id).domain_changed,
                        "already-compatible category counted as new influence or lost join authority");
            require(!decision(result, 5).selected, "fifth redundant offer exceeded capacity");
        });
        test("same tile competition retains stronger opportunity", [] {
            Case value(1, 1); value.offer(1, 0, 1); value.offer(2, 0, 2);
            const auto result = value.run();
            require(result.selected_ids == std::vector<std::uint32_t>{1} &&
                    decision(result, 2).disposition == "optional-competing" && decision(result, 2).conflicts_with == 1,
                    "same-tile receiving competition was not inspectable");
        });
        test("mutually enabling neighbors survive optimistic screening", [] {
            Case value(2, 1, 1); value.equal_categories_only(); value.offer(1, 0, 2); value.offer(2, 1, 2);
            const auto result = value.run();
            require(result.selected_ids.size() == 2 && result.preferred_domains == std::vector<std::uint16_t>{2, 2},
                    "native expansions were rejected against obsolete unoffered neighbor domains");
        });
        test("optional policy cannot loosen required domain", [] {
            Case value(1, 1); value.offer(1, 0, 1, true); value.offer(2, 0, 2);
            const auto result = value.run();
            require(result.selected_ids == std::vector<std::uint32_t>{1} && result.hard_domains[0] == 1 &&
                    result.preferred_domains[0] == 1 && result.fallback_domains[0] == 1,
                    "optional policy relaxed a hard receiving obligation");
        });
        test("native raw receiving masks remain unchanged after screening", [] {
            Case value(2, 1, 2); value.equal_categories_only(); value.offer(1, 0, 3);
            const auto result = value.run();
            require(decision(result, 1).locally_supported_domain == 2 && decision(result, 1).compatible_domain == 3 &&
                    result.preferred_domains[0] == 3, "local screen silently replaced native receiving semantics");
            require(value.discovered.responses[0].compatible_domain == 3 && value.discovered.domains[0].original_domain == 2,
                    "screen mutated its immutable discovery input");
        });
        test("generator work is bounded on exhaustion", [] {
            Case value(2, 1); value.offer(1, 0, 3); value.request.limits.max_work = 80;
            Result accounting; const auto result = value.run(&accounting);
            require(result.status == Status::Exhausted && accounting.status == Status::Exhausted && result.work <= 80,
                    "native screening ignored unchanged generator work cap");
        });
        test("malformed identities, dimensions and domains fail before solve", [] {
            Case value(1, 1); value.offer(1, 0, 3); value.offer(1, 0, 3);
            require(value.run().status == Status::Invalid, "duplicate mechanical identity accepted");
            value.slots.pop_back(); value.discovered.responses.pop_back(); value.discovered.responses[0].slot_id = 9;
            require(value.run().status == Status::Invalid, "unknown receiving response accepted");
            value.discovered.responses[0].slot_id = 1; value.discovered.responses[0].tile = 7;
            require(value.run().status == Status::Invalid, "out-of-range tile accepted");
            value.discovered.responses[0].tile = 0; value.discovered.domains[0].original_domain = 0;
            require(value.run().status == Status::Invalid, "empty original domain accepted");
            Case oversize(17, 1); require(oversize.run().status == Status::Invalid, "GEN-003 grid ceiling bypassed");
        });
        test("offer and response evaluation order invariance", [] {
            Case value(4, 2); for (unsigned id = 1; id <= 8; ++id) value.offer(id, id - 1, id % 2 ? 3 : 1, id == 8);
            const auto reference = value.run();
            std::reverse(value.slots.begin(), value.slots.end()); std::reverse(value.discovered.responses.begin(), value.discovered.responses.end());
            same(reference, value.run());
            std::rotate(value.slots.begin(), value.slots.begin() + 3, value.slots.end());
            std::rotate(value.discovered.responses.begin(), value.discovered.responses.begin() + 1, value.discovered.responses.end());
            same(reference, value.run());
        });
        test("no fixture name or seed dependent lookup", [] {
            Case value(4, 2); for (unsigned id = 1; id <= 8; ++id) value.offer(id, id - 1, id % 2 ? 3 : 1);
            const auto reference = value.run();
            value.request.fixture = "unseen-arbitrary-fixture"; value.request.seed = 0xfedcba9876543210ULL;
            value.request.profile.name = "different-label-only"; same(reference, value.run());
        });
        test("finite cardinal screen does not wrap grid edges", [] {
            Case value(2, 1, 2); value.equal_categories_only(); value.offer(1, 1, 2);
            const auto result = value.run(); const auto& row = decision(result, 1);
            require(row.selected && row.neighbor_pool == std::array<std::uint16_t, 4>{0, 0, 2, 0},
                    "native screen wrapped across a grid edge");
        });
        test("both cardinal adjacency directions are respected", [] {
            Case value(2, 1, 2); value.offer(1, 0, 1); value.adjacency[2][1] = 0;
            const auto result = value.run(); require(!decision(result, 1).selected, "one-way adjacency was mistaken for reciprocal support");
        });
        test("required flag alone still retains mechanical obligation", [] {
            Case value(1, 1); value.offer(1, 0, 1, true); value.slots[0].hard = false;
            const auto result = value.run(); require(decision(result, 1).hard && decision(result, 1).selected &&
                                                   result.hard_domains[0] == 1, "required flag silently softened by local policy");
        });
        test("defaulted capacity API preserves explicit cap-four policy", [] {
            Case value(4, 2); for (unsigned id = 1; id <= 8; ++id) value.offer(id, id - 1, id % 2 ? 3 : 1, id == 8);
            Result accounting;
            const auto implicit = screen_mosaic_offers(value.request, accounting, value.width, value.height,
                                                       value.adjacency, value.slots, value.discovered);
            same(implicit, value.run(nullptr, 4, 2));
            require(implicit.optional_capacity == 4 && implicit.fallback_optional_capacity == 2,
                    "default API changed historical capacity limits");
        });
        test("registered zero four six eight capacities retain bounded opportunities", [] {
            Case value(4, 2); for (unsigned id = 1; id <= 8; ++id) value.offer(id, id - 1, 1);
            std::vector<std::uint32_t> previous;
            for (unsigned capacity : {0U, 4U, 6U, 8U}) {
                const auto result = value.run(nullptr, capacity, capacity == 0 ? 0 : 2);
                require(result.status == Status::Complete && result.selected_ids.size() == capacity &&
                        result.fallback_ids.size() == (capacity == 0 ? 0U : 2U) && result.decisions.size() == 8,
                        "registered capacity did not retain its bounded optional count and receipts");
                require(std::includes(result.selected_ids.begin(), result.selected_ids.end(), previous.begin(), previous.end()),
                        "larger capacity replaced an earlier accepted opportunity");
                previous = result.selected_ids;
                if (capacity == 0) require(result.preferred_domains == result.hard_domains &&
                                           result.fallback_domains == result.hard_domains,
                                           "zero-capacity diagnostic retained an optional domain influence");
            }
        });
        test("every registered capacity preserves mandatory slots outside optional allowance", [] {
            Case value(4, 2); for (unsigned id = 1; id <= 8; ++id) value.offer(id, id - 1, 1, id <= 2);
            for (unsigned capacity : {0U, 4U, 6U, 8U}) {
                const auto result = value.run(nullptr, capacity, capacity == 0 ? 0 : 2);
                require(result.selected_ids.size() == 2U + std::min(capacity, 6U),
                        "hard offers consumed optional capacity or total reservation bound changed");
                for (unsigned id : {1U, 2U}) require(decision(result, id).selected && decision(result, id).fallback_selected,
                                                   "registered capacity removed mandatory authority");
                require(result.hard_domains[0] == 1 && result.hard_domains[1] == 1,
                        "registered capacity weakened hard categorical masks");
            }
        });
        test("extra capacity never overrides local competition", [] {
            Case value(1, 1); value.offer(1, 0, 1); value.offer(2, 0, 2);
            for (unsigned capacity : {4U, 6U, 8U}) {
                const auto result = value.run(nullptr, capacity, 2);
                require(result.selected_ids == std::vector<std::uint32_t>{1} &&
                        decision(result, 2).disposition == "optional-competing" && decision(result, 2).conflicts_with == 1,
                        "larger optional capacity forced incompatible receiving domains");
            }
        });
        test("capacity changes preserve native rankings and raw receiving vocabulary", [] {
            Case value(4, 2); for (unsigned id = 1; id <= 8; ++id) value.offer(id, id - 1, id % 2 ? 3 : 1);
            const auto reference = value.run();
            for (unsigned capacity : {0U, 6U, 8U}) {
                const auto result = value.run(nullptr, capacity, capacity == 0 ? 0 : 2);
                require(result.original_domains == reference.original_domains && result.hard_domains == reference.hard_domains,
                        "capacity changed original or required native domains");
                for (unsigned id = 1; id <= 8; ++id) {
                    const auto& old = decision(reference, id); const auto& current = decision(result, id);
                    require(old.rank == current.rank && old.compatible_domain == current.compatible_domain &&
                            old.locally_supported_domain == current.locally_supported_domain &&
                            old.neighbor_pool == current.neighbor_pool && old.neighbor_support == current.neighbor_support,
                            "capacity changed the registered pre-solve native ranking");
                }
            }
        });
        test("unregistered capacities fail without categorical work", [] {
            Case value(1, 1); value.offer(1, 0, 1, true);
            for (unsigned capacity : {1U, 2U, 3U, 5U, 7U, 9U, 0xffffffffU}) {
                const auto result = value.run(nullptr, capacity, 0);
                require(result.status == Status::Invalid && result.work == 0, "unregistered capacity entered admission");
            }
            for (const auto pair : {std::array<unsigned, 2>{0, 2}, {4, 1}, {4, 3}, {8, 9}}) {
                const auto result = value.run(nullptr, pair[0], pair[1]);
                require(result.status == Status::Invalid && result.work == 0, "invalid fallback capacity entered admission");
            }
        });
        test("every registered capacity obeys unchanged preparation work ceiling", [] {
            Case value(4, 2); for (unsigned id = 1; id <= 8; ++id) value.offer(id, id - 1, 3, id <= 2);
            for (unsigned capacity : {0U, 4U, 6U, 8U}) {
                const auto complete = value.run(nullptr, capacity, capacity == 0 ? 0 : 2);
                require(complete.status == Status::Complete && complete.work > 0, "registered capacity unexpectedly failed");
                const auto original_limit = value.request.limits.max_work;
                value.request.limits.max_work = complete.work - 1;
                Result accounting; const auto bounded = value.run(&accounting, capacity, capacity == 0 ? 0 : 2);
                require(bounded.status == Status::Exhausted && accounting.status == Status::Exhausted &&
                        bounded.work <= value.request.limits.max_work,
                        "registered capacity crossed declared preparation ceiling");
                value.request.limits.max_work = original_limit;
            }
        });
        std::cout << passed << "/" << passed << " native admission resilience groups passed\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "FAIL after " << passed << " groups: " << error.what() << '\n'; return 1;
    }
}
