#define CYBERSAND_SETTLED_REGIONS_TEST_ACCESS 1
#include "cybersand/settled_regions.hpp"

#include <array>
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <vector>

namespace {
using namespace cybersand::soliding;

void require(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}

DiscoverySignals quiet() { return {true, true, true, false, false, false}; }
constexpr DiscoveryCell sand{1, 7, 3, 220, false};
constexpr DiscoveryCell other_state{1, 8, 3, 220, false};
constexpr DiscoveryCell empty{0, 0, 0, 20, false};

RegionTileKey key(std::int64_t x, std::int64_t y, std::uint64_t incarnation = 1) {
    return {incarnation, y / 32, x / 32, y / 4, x / 4, y, x};
}

template<class Regions, std::size_t N>
RegionOutcome put(Regions& regions, RegionTileKey tile_key, DiscoveryBounds bounds,
                  std::uint64_t revision, const std::array<DiscoveryCell, N>& cells,
                  std::uint8_t sealed_edges = 0x0f, DiscoverySignals signals = quiet()) {
    return regions.upsert({tile_key, bounds, revision, 20, signals,
                           std::span<const DiscoveryCell>{cells}, sealed_edges});
}

template<class Regions>
void drain(Regions& regions, std::size_t limit = 100000) {
    std::size_t work = 0;
    while (regions.pending_components() != 0 && work < limit) {
        const auto used = regions.advance(1);
        require(used <= 1, "advance respects exact budget");
        if (used == 0) break;
        work += used;
    }
    require(work < limit, "bounded traversal terminates");
}

template<class Regions>
std::vector<SettledRegionSnapshot> snapshots(const Regions& regions, std::size_t capacity) {
    std::vector<SettledRegionSnapshot> result;
    for (std::size_t i = 0; i < capacity; ++i) {
        const auto snapshot = regions.region_at(i);
        if (snapshot.has_value()) result.push_back(*snapshot);
    }
    return result;
}

template<class Regions>
void drain_budget(Regions& regions, std::size_t budget, std::size_t limit = 100000) {
    std::size_t work = 0;
    while (regions.pending_components() != 0 && work < limit) {
        const auto used = regions.advance(budget);
        require(used <= budget, "chunked advance respects primitive budget");
        if (used == 0) break;
        work += used;
    }
    require(work < limit, "chunked bounded traversal terminates");
}

bool same_region_semantics(
    const SettledRegionSnapshot& a, const SettledRegionSnapshot& b) {
    return a.handle == b.handle && a.key == b.key &&
           a.min_x == b.min_x && a.min_y == b.min_y &&
           a.max_x == b.max_x && a.max_y == b.max_y &&
           a.area == b.area && a.tile_count == b.tile_count &&
           a.component_count == b.component_count &&
           a.dependency_tile_count == b.dependency_tile_count &&
           a.member_digest == b.member_digest &&
           a.dependency_digest == b.dependency_digest &&
           a.publication_serial == b.publication_serial &&
           a.complete == b.complete;
}

void single_tile_holes_and_exact_keys() {
    using Regions = SettledRegions<4, 16, 16, 32, 8, 64>;
    Regions regions(1);
    const std::array<DiscoveryCell, 9> ring{
        sand, sand, sand,
        sand, empty, sand,
        sand, sand, sand,
    };
    require(put(regions, key(0, 0), {0, 0, 3, 3}, 1, ring) == RegionOutcome::Accepted,
            "canonical hole tile accepted");
    require(regions.region_count() == 0, "no eager or partial publication");
    require(regions.advance(1) == 1 && regions.region_count() == 0,
            "seed probe cannot publish");
    drain(regions);
    const auto found = snapshots(regions, 8);
    require(found.size() == 1, "ring is one four-neighbour region");
    require(found[0].complete && found[0].area == 8 && found[0].component_count == 1,
            "canonical Empty is a hole, not membership");
    require(found[0].key == RegionComponentKey{1, 7, 3, 220}, "exact tuple retained");

    Regions exact(1);
    const std::array<DiscoveryCell, 2> split{sand, other_state};
    require(put(exact, key(0, 0), {0, 0, 2, 1}, 1, split) == RegionOutcome::Accepted,
            "state split accepted");
    drain(exact);
    const auto separated = snapshots(exact, 8);
    require(separated.size() == 2 && separated[0].area == 1 && separated[1].area == 1,
            "state_a difference separates adjacent components");
}

void refusal_and_revision_guards() {
    using Regions = SettledRegions<3, 4, 4, 8, 4, 16>;
    Regions regions(2);
    std::array<DiscoveryCell, 1> cell{sand};
    require(put(regions, key(0, 0, 2), {0, 0, 1, 1}, 1, cell) == RegionOutcome::Accepted,
            "initial revision accepted");
    drain(regions);
    const auto prior = snapshots(regions, 4);
    require(prior.size() == 1, "initial revision publishes before corruption probe");
    cell[0].temperature = 221;
    require(put(regions, key(0, 0, 2), {0, 0, 1, 1}, 1, cell) == RegionOutcome::Invalid &&
            regions.last_refusal() == RegionRefusal::RevisionChanged,
            "same revision cannot carry another payload");
    require(regions.halted() && !regions.snapshot(prior[0].handle).has_value() &&
            regions.advance(100) == 0,
            "same-revision corruption retires snapshots and halts consumption");
    require(put(regions, key(0, 0, 2), {0, 0, 1, 1}, 2, cell) == RegionOutcome::Refused,
            "halt requires reconstruction rather than accepting more input");

    Regions invalid(2);
    require(put(invalid, key(0, 0, 2), {0, 0, 1, 1}, 0, cell) == RegionOutcome::Invalid,
            "zero revision rejected without corrupting tracker");

    Regions noncanonical(2);
    std::array<DiscoveryCell, 1> hot_empty{DiscoveryCell{0, 0, 0, 21, false}};
    require(put(noncanonical, key(0, 0, 2), {0, 0, 1, 1}, 1, hot_empty) == RegionOutcome::Refused &&
            noncanonical.last_refusal() == RegionRefusal::NoncanonicalEmpty,
            "noncanonical Empty cannot disappear into a hole");
    require(noncanonical.region_count() == 0, "refused tile publishes nothing");

    Regions blocked(2);
    auto signals = quiet();
    signals.pending_event = true;
    require(put(blocked, key(0, 0, 2), {0, 0, 1, 1}, 1, cell, 0x0f, signals) ==
                RegionOutcome::Refused &&
            blocked.last_refusal() == RegionRefusal::SignalIncomplete,
            "pending event blocks connectivity input");
}

void unknown_registration_retires_faces_without_consuming_payload() {
    using Regions = SettledRegions<2, 1, 1, 2, 4, 4>;
    const std::array<DiscoveryCell, 1> one{sand};
    Regions regions(29);
    const auto left = key(0, 0, 29), right = key(1, 0, 29);
    require(put(regions, left, {0, 0, 1, 1}, 1, one) == RegionOutcome::Accepted,
            "known left payload accepted");
    drain(regions);
    const auto old = snapshots(regions, 4)[0].handle;
    require(regions.register_unknown(right, {1, 0, 1, 1}, 1) == RegionOutcome::Accepted,
            "new unknown neighbor registered without payload");
    require(!regions.snapshot(old).has_value(),
            "unknown neighbor registration immediately retires facing completeness");
    require(put(regions, right, {1, 0, 1, 1}, 1, one) == RegionOutcome::Accepted,
            "same revision may later receive its first complete payload");
    drain(regions);
    require(regions.region_count() == 1 && snapshots(regions, 4)[0].area == 2,
            "completed unknown neighbor rebuilds one exact region");
    require(regions.invalidate_known(0, right, 2) == RegionOutcome::Invalid &&
            regions.snapshot(snapshots(regions, 4)[0].handle).has_value(),
            "slot fast path rejects a mismatched key without retiring publication");
}

void cross_tile_seams_and_unknown_boundary() {
    using Regions = SettledRegions<4, 4, 4, 16, 8, 32>;
    const std::array<DiscoveryCell, 4> solid{sand, sand, sand, sand};
    Regions joined(3);
    require(put(joined, key(0, 0, 3), {0, 0, 2, 2}, 1, solid, 0x0d) == RegionOutcome::Accepted,
            "left seam tile accepted");
    require(put(joined, key(2, 0, 3), {2, 0, 2, 2}, 1, solid, 0x07) == RegionOutcome::Accepted,
            "right seam tile accepted");
    drain(joined);
    const auto complete = snapshots(joined, 8);
    require(complete.size() == 1 && complete[0].area == 8 && complete[0].tile_count == 2,
            "matching seam is one complete multi-tile region");
    require(joined.adjacency_count() == 1, "duplicate boundary cells yield one component edge");

    Regions unknown(3);
    require(put(unknown, key(0, 0, 3), {0, 0, 2, 2}, 1, solid, 0x0d) == RegionOutcome::Accepted,
            "open edge may be tracked");
    drain(unknown);
    require(unknown.region_count() == 0 && unknown.last_refusal() == RegionRefusal::UnknownBoundary,
            "missing coverage prevents complete publication");
}

void deterministic_insertion_and_publication() {
    using Regions = SettledRegions<4, 4, 4, 16, 8, 32>;
    const std::array<DiscoveryCell, 4> solid{sand, sand, sand, sand};
    Regions forward(4), reverse(4);
    require(put(forward, key(0, 0, 4), {0, 0, 2, 2}, 1, solid, 0x0d) == RegionOutcome::Accepted,
            "forward left accepted");
    require(put(forward, key(2, 0, 4), {2, 0, 2, 2}, 1, solid, 0x07) == RegionOutcome::Accepted,
            "forward right accepted");
    require(put(reverse, key(2, 0, 4), {2, 0, 2, 2}, 1, solid, 0x07) == RegionOutcome::Accepted,
            "reverse right accepted");
    require(put(reverse, key(0, 0, 4), {0, 0, 2, 2}, 1, solid, 0x0d) == RegionOutcome::Accepted,
            "reverse left accepted");
    drain(forward);
    drain(reverse);
    const auto a = snapshots(forward, 8), b = snapshots(reverse, 8);
    require(a.size() == 1 && b.size() == 1, "both schedules publish once");
    require(a[0].member_digest == b[0].member_digest &&
            a[0].dependency_digest == b[0].dependency_digest &&
            a[0].area == b[0].area && a[0].component_count == b[0].component_count,
            "region digest independent of tile allocation order");
}

void bridge_and_split_retire_old_handles() {
    using Regions = SettledRegions<3, 4, 4, 16, 8, 32>;
    const std::array<DiscoveryCell, 1> one{sand};
    Regions regions(5);
    require(put(regions, key(0, 0, 5), {0, 0, 1, 1}, 1, one, 0x0f) == RegionOutcome::Accepted,
            "first island accepted");
    require(put(regions, key(2, 0, 5), {2, 0, 1, 1}, 1, one, 0x0f) == RegionOutcome::Accepted,
            "second island accepted");
    drain(regions);
    const auto islands = snapshots(regions, 8);
    require(islands.size() == 2, "separate islands publish separately");
    const auto old_a = islands[0].handle, old_b = islands[1].handle;

    require(put(regions, key(1, 0, 5), {1, 0, 1, 1}, 1, one, 0x05) == RegionOutcome::Accepted,
            "new bridge accepted");
    require(!regions.snapshot(old_a).has_value() && !regions.snapshot(old_b).has_value(),
            "bridge insertion retires both facing old regions immediately");
    drain(regions);
    const auto merged = snapshots(regions, 8);
    require(merged.size() == 1 && merged[0].area == 3, "bridge republishes merged complete region");
    const auto old_merged = merged[0].handle;

    std::array<DiscoveryCell, 1> hole{empty};
    require(put(regions, key(1, 0, 5), {1, 0, 1, 1}, 2, hole, 0x05) == RegionOutcome::Accepted,
            "bridge removal accepted");
    require(!regions.snapshot(old_merged).has_value(), "split retires merged handle");
    drain(regions);
    require(regions.region_count() == 2, "split republishes two complete islands");
}

void capacity_refusal_preserves_authoritative_inputs() {
    using Regions = SettledRegions<1, 1, 1, 1, 1, 1>;
    const std::array<DiscoveryCell, 1> one{sand};
    Regions regions(6);
    require(put(regions, key(0, 0, 6), {0, 0, 1, 1}, 1, one) == RegionOutcome::Accepted,
            "capacity survivor accepted");
    require(put(regions, key(2, 0, 6), {2, 0, 1, 1}, 1, one) == RegionOutcome::Capacity,
            "tile saturation explicitly refuses newcomer");
    require(regions.tile_count() == 1, "capacity refusal retains accepted observation");
    drain(regions);
    require(regions.capacity_blocked() && regions.region_count() == 0 && regions.advance(100) == 0,
            "unrepresentable coverage disables tracking rather than asserting false completeness");
}

void bounded_capacity_never_publishes_a_prefix() {
    const std::array<DiscoveryCell, 1> one{sand};
    using FrontierLimited = SettledRegions<3, 1, 1, 4, 3, 1>;
    FrontierLimited frontier(7);
    require(put(frontier, key(0, 0, 7), {0, 0, 1, 1}, 1, one, 0x0d) == RegionOutcome::Accepted,
            "frontier left accepted");
    require(put(frontier, key(1, 0, 7), {1, 0, 1, 1}, 1, one, 0x05) == RegionOutcome::Accepted,
            "frontier middle accepted");
    require(put(frontier, key(2, 0, 7), {2, 0, 1, 1}, 1, one, 0x07) == RegionOutcome::Accepted,
            "frontier right accepted");
    drain(frontier);
    require(frontier.region_count() == 0 && frontier.last_refusal() == RegionRefusal::FrontierCapacity,
            "frontier saturation refuses the whole candidate");

    using AdjacencyLimited = SettledRegions<3, 1, 1, 1, 4, 8>;
    AdjacencyLimited adjacency(8);
    require(put(adjacency, key(0, 0, 8), {0, 0, 1, 1}, 1, one, 0x0d) == RegionOutcome::Accepted,
            "adjacency left accepted");
    require(put(adjacency, key(2, 0, 8), {2, 0, 1, 1}, 1, one, 0x07) == RegionOutcome::Accepted,
            "adjacency right accepted");
    require(put(adjacency, key(1, 0, 8), {1, 0, 1, 1}, 1, one, 0x05) == RegionOutcome::Capacity &&
            adjacency.last_refusal() == RegionRefusal::AdjacencyCapacity,
            "adjacency saturation explicitly refuses changed tile");
    require(!adjacency.halted() && adjacency.region_count() == 0,
            "local adjacency refusal neither publishes a prefix nor globally blocks tracking");

    using RegionLimited = SettledRegions<2, 1, 1, 2, 1, 4>;
    RegionLimited published(9);
    require(put(published, key(-2, 0, 9), {-2, 0, 1, 1}, 1, one) == RegionOutcome::Accepted,
            "negative island accepted");
    require(put(published, key(2, 0, 9), {2, 0, 1, 1}, 1, one) == RegionOutcome::Accepted,
            "positive island accepted");
    drain(published);
    require(published.region_count() == 1 && published.last_refusal() == RegionRefusal::RegionCapacity,
            "published-region saturation retains one whole canonical region only");
}

void mutation_during_seed_seek_restarts_canonical_selection() {
    using Regions = SettledRegions<2, 1, 1, 2, 2, 4>;
    const std::array<DiscoveryCell, 1> one{sand};
    Regions regions(10);
    require(put(regions, key(0, 0, 10), {0, 0, 1, 1}, 1, one) == RegionOutcome::Accepted,
            "first seek candidate accepted");
    require(put(regions, key(4, 0, 10), {4, 0, 1, 1}, 1, one) == RegionOutcome::Accepted,
            "remote seek candidate accepted");
    require(regions.advance(1) == 1, "seek observes first slot only");
    const std::array<DiscoveryCell, 1> hole{empty};
    require(put(regions, key(0, 0, 10), {0, 0, 1, 1}, 2, hole) == RegionOutcome::Accepted,
            "observed seed is removed during seek");
    drain(regions);
    const auto remaining = snapshots(regions, 2);
    require(remaining.size() == 1 && remaining[0].area == 1 && remaining[0].min_x == 4,
            "stale seed cannot publish and remote canonical candidate progresses");
    require(regions.metrics().builds_restarted == 1, "seek mutation is an explicit restart");
}

void negative_seams_diagonals_and_partial_work() {
    using Regions = SettledRegions<3, 1, 1, 4, 4, 8>;
    const std::array<DiscoveryCell, 1> one{sand};
    Regions seam(11);
    RegionTileKey west{11, 0, -1, 0, -1, 0, -1};
    RegionTileKey east{11, 0, 0, 0, 0, 0, 0};
    require(put(seam, west, {-1, 0, 1, 1}, 1, one, 0x0d) == RegionOutcome::Accepted,
            "negative cross-chunk side accepted");
    require(put(seam, east, {0, 0, 1, 1}, 1, one, 0x07) == RegionOutcome::Accepted,
            "nonnegative cross-chunk side accepted");
    drain(seam);
    require(seam.region_count() == 1 && snapshots(seam, 4)[0].area == 2,
            "negative-coordinate chunk seam connects by a shared face");

    Regions diagonal(11);
    require(put(diagonal, key(0, 0, 11), {0, 0, 1, 1}, 1, one) == RegionOutcome::Accepted,
            "diagonal first accepted");
    require(put(diagonal, key(1, 1, 11), {1, 1, 1, 1}, 1, one) == RegionOutcome::Accepted,
            "diagonal second accepted");
    drain(diagonal);
    require(diagonal.region_count() == 2, "diagonal touch does not connect");

    Regions interrupted(11);
    require(put(interrupted, west, {-1, 0, 1, 1}, 1, one, 0x0d) == RegionOutcome::Accepted,
            "partial west accepted");
    require(put(interrupted, east, {0, 0, 1, 1}, 1, one, 0x07) == RegionOutcome::Accepted,
            "partial east accepted");
    require(interrupted.advance(3) == 3 && interrupted.region_count() == 0,
            "partial traversal publishes nothing");
    require(interrupted.invalidate(east, 2) == RegionOutcome::Accepted,
            "dependency invalidated during traversal");
    require(interrupted.region_count() == 0 && interrupted.metrics().builds_restarted == 1,
            "partial work is cancelled, never published");
    require(put(interrupted, east, {0, 0, 1, 1}, 2, one, 0x07) == RegionOutcome::Accepted,
            "invalidated dependency can be fully replaced");
    drain(interrupted);
    require(interrupted.region_count() == 1 && snapshots(interrupted, 4)[0].area == 2,
            "fresh revisions rebuild the complete region");
}

void remote_publication_survives_local_churn() {
    using Regions = SettledRegions<2, 1, 1, 2, 4, 4>;
    const std::array<DiscoveryCell, 1> one{sand};
    Regions regions(12);
    const auto local = key(0, 0, 12), remote = key(1000, 1000, 12);
    require(put(regions, local, {0, 0, 1, 1}, 1, one) == RegionOutcome::Accepted,
            "local candidate accepted");
    require(put(regions, remote, {1000, 1000, 1, 1}, 1, one) == RegionOutcome::Accepted,
            "remote candidate accepted");
    drain(regions);
    const auto before = snapshots(regions, 4);
    require(before.size() == 2, "both distant regions published");
    const auto remote_handle = before[0].min_x == 1000 ? before[0].handle : before[1].handle;
    for (std::uint64_t revision = 2; revision != 8; ++revision) {
        require(put(regions, local, {0, 0, 1, 1}, revision, one) == RegionOutcome::Accepted,
                "local churn revision accepted");
        require(regions.snapshot(remote_handle).has_value(), "far region remains valid under local churn");
        drain(regions);
    }
}

void multi_tile_ring_and_many_tile_solid() {
    using RingRegions = SettledRegions<4, 4, 4, 16, 8, 32>;
    const std::array<DiscoveryCell, 4> top_left{sand, sand, sand, empty};
    const std::array<DiscoveryCell, 4> top_right{sand, sand, empty, sand};
    const std::array<DiscoveryCell, 4> bottom_left{sand, empty, sand, sand};
    const std::array<DiscoveryCell, 4> bottom_right{empty, sand, sand, sand};
    RingRegions ring(13);
    require(put(ring, key(0, 0, 13), {0, 0, 2, 2}, 1, top_left, 0x09) == RegionOutcome::Accepted,
            "ring northwest accepted");
    require(put(ring, key(2, 0, 13), {2, 0, 2, 2}, 1, top_right, 0x03) == RegionOutcome::Accepted,
            "ring northeast accepted");
    require(put(ring, key(0, 2, 13), {0, 2, 2, 2}, 1, bottom_left, 0x0c) == RegionOutcome::Accepted,
            "ring southwest accepted");
    require(put(ring, key(2, 2, 13), {2, 2, 2, 2}, 1, bottom_right, 0x06) == RegionOutcome::Accepted,
            "ring southeast accepted");
    drain(ring);
    const auto complete = snapshots(ring, 8);
    require(complete.size() == 1 && complete[0].area == 12 && complete[0].tile_count == 4,
            "four-tile ring preserves its central hole");

    using ManyRegions = SettledRegions<8, 1, 1, 16, 8, 16>;
    const std::array<DiscoveryCell, 1> one{sand};
    ManyRegions many(13);
    for (std::int64_t x = 0; x < 8; ++x) {
        std::uint8_t sealed = 0x05;
        if (x == 0) sealed |= 0x08;
        if (x == 7) sealed |= 0x02;
        require(put(many, key(x, 0, 13), {x, 0, 1, 1}, 1, one, sealed) == RegionOutcome::Accepted,
                "many-tile member accepted");
    }
    drain(many);
    require(many.region_count() == 1 && snapshots(many, 8)[0].area == 8 &&
            snapshots(many, 8)[0].tile_count == 8,
            "many-tile solid traverses as one bounded region");
}

void exact_key_seams_and_local_shapes() {
    using Regions = SettledRegions<2, 1, 1, 2, 4, 4>;
    const std::array<DiscoveryCell, 1> left{sand};
    std::array<DiscoveryCell, 4> variants{
        DiscoveryCell{2, 7, 3, 220, false},
        DiscoveryCell{1, 8, 3, 220, false},
        DiscoveryCell{1, 7, 4, 220, false},
        DiscoveryCell{1, 7, 3, 221, false},
    };
    for (std::size_t i = 0; i < variants.size(); ++i) {
        Regions regions(20 + i);
        const std::array<DiscoveryCell, 1> right{variants[i]};
        require(put(regions, key(0, 0, 20 + i), {0, 0, 1, 1}, 1, left, 0x0d) == RegionOutcome::Accepted,
                "exact-key left accepted");
        require(put(regions, key(1, 0, 20 + i), {1, 0, 1, 1}, 1, right, 0x07) == RegionOutcome::Accepted,
                "exact-key right accepted");
        drain(regions);
        require(regions.region_count() == 2, "material/state_a/state_b/temperature seam stays split");
    }

    using ShapeRegions = SettledRegions<1, 9, 9, 4, 2, 16>;
    ShapeRegions shape(24);
    const std::array<DiscoveryCell, 9> tee{
        sand, empty, sand,
        sand, sand, sand,
        empty, sand, empty,
    };
    require(put(shape, key(0, 0, 24), {0, 0, 3, 3}, 1, tee) == RegionOutcome::Accepted,
            "one-cell neck and T fixture accepted");
    drain(shape);
    require(shape.region_count() == 1 && snapshots(shape, 2)[0].area == 6,
            "one-cell neck and T junction remain connected without cohesion inference");
}

void unknown_middle_component_capacity_and_new_match() {
    const std::array<DiscoveryCell, 1> one{sand};
    using Regions = SettledRegions<3, 4, 4, 8, 6, 16>;
    Regions blocked(25);
    require(put(blocked, key(0, 0, 25), {0, 0, 1, 1}, 1, one, 0x0d) == RegionOutcome::Accepted,
            "blocked-middle left accepted");
    auto unavailable = quiet(); unavailable.occupied = true;
    require(put(blocked, key(1, 0, 25), {1, 0, 1, 1}, 1, one, 0x05, unavailable) == RegionOutcome::Refused,
            "occupied middle explicitly unavailable");
    require(put(blocked, key(2, 0, 25), {2, 0, 1, 1}, 1, one, 0x07) == RegionOutcome::Accepted,
            "blocked-middle right accepted");
    drain(blocked);
    require(blocked.region_count() == 0, "unknown middle prevents false complete side regions");

    using ComponentLimited = SettledRegions<1, 4, 3, 4, 2, 8>;
    ComponentLimited complex(26);
    const std::array<DiscoveryCell, 4> checker{sand, other_state, other_state, sand};
    require(put(complex, key(0, 0, 26), {0, 0, 2, 2}, 1, checker) == RegionOutcome::Capacity &&
            complex.last_refusal() == RegionRefusal::ComponentCapacity,
            "pathological local component count refuses the tile");
    require(complex.region_count() == 0 && complex.pending_components() == 0,
            "component overflow never exposes a truncated component set");

    using PairRegions = SettledRegions<2, 1, 1, 2, 4, 4>;
    PairRegions changed(27);
    const std::array<DiscoveryCell, 1> mismatch{other_state};
    require(put(changed, key(0, 0, 27), {0, 0, 1, 1}, 1, one, 0x0d) == RegionOutcome::Accepted,
            "new-match left accepted");
    require(put(changed, key(1, 0, 27), {1, 0, 1, 1}, 1, mismatch, 0x07) == RegionOutcome::Accepted,
            "new-match mismatch accepted");
    drain(changed);
    const auto separate = snapshots(changed, 4);
    require(separate.size() == 2, "known nonmatching seam publishes separate regions");
    const auto old_left = separate[0].min_x == 0 ? separate[0].handle : separate[1].handle;
    require(put(changed, key(1, 0, 27), {1, 0, 1, 1}, 2, one, 0x07) == RegionOutcome::Accepted,
            "neighbor changes to matching exact key");
    require(!changed.snapshot(old_left).has_value(), "new possible bridge retires facing neighbor region");
    drain(changed);
    require(changed.region_count() == 1 && snapshots(changed, 4)[0].area == 2,
            "matching update republishes one merged region");
}

void generation_exhaustion_never_revalidates_old_handle() {
    using Regions = SettledRegions<1, 1, 1, 1, 1, 2, 1, 2>;
    const std::array<DiscoveryCell, 1> one{sand};
    Regions regions(29);
    const auto tile_key = key(0, 0, 29);

    require(put(regions, tile_key, {0, 0, 1, 1}, 1, one) == RegionOutcome::Accepted,
            "generation fixture accepted");
    drain(regions);
    const auto first = snapshots(regions, 1);
    require(first.size() == 1 && first[0].handle.generation == 1,
            "first and only usable generation publishes");
    const auto stale = first[0].handle;

    require(put(regions, tile_key, {0, 0, 1, 1}, 2, one) == RegionOutcome::Accepted &&
            !regions.snapshot(stale).has_value() && regions.region_count() == 0,
            "revision replacement immediately retires the old generation");
    drain(regions);
    require(regions.region_count() == 0,
            "generation exhaustion cannot publish a replacement region");
    require(regions.last_refusal() == RegionRefusal::GenerationExhausted,
            "generation exhaustion reports the terminal typed refusal");
    require(!regions.snapshot(stale).has_value(),
            "generation exhaustion cannot revalidate the stale handle");

    require(put(regions, tile_key, {0, 0, 1, 1}, 3, one) == RegionOutcome::Accepted,
            "post-exhaustion input can still be observed without identity reuse");
    drain(regions);
    require(regions.region_count() == 0,
            "post-exhaustion observation cannot publish a replacement region");
    require(regions.last_refusal() == RegionRefusal::GenerationExhausted,
            "post-exhaustion observation preserves the terminal typed refusal");
    require(!regions.snapshot(stale).has_value(),
            "slot/object reuse cannot make an exhausted old handle current again");
}

void local_churn_does_not_cancel_inflight_remote_region() {
    using Regions = SettledRegions<2, 1, 1, 2, 4, 4>;
    const std::array<DiscoveryCell, 1> one{sand};
    Regions regions(28);
    const auto local = key(0, 0, 28), remote = key(1000, 1000, 28);
    require(put(regions, local, {0, 0, 1, 1}, 1, one, 0x0e) == RegionOutcome::Accepted,
            "open local candidate accepted");
    require(put(regions, remote, {1000, 1000, 1, 1}, 1, one) == RegionOutcome::Accepted,
            "sealed remote candidate accepted");
    require(regions.advance(3) == 3 && regions.last_refusal() == RegionRefusal::UnknownBoundary,
            "local unknown candidate is refused without publication");
    require(regions.advance(3) == 3, "remote traversal reaches validation");
    require(put(regions, local, {0, 0, 1, 1}, 2, one, 0x0e) == RegionOutcome::Accepted,
            "unrelated local churn accepted during remote build");
    drain(regions);
    const auto found = snapshots(regions, 4);
    require(found.size() == 1 && found[0].min_x == 1000,
            "remote complete region progresses despite unrelated local churn");
}

void dependency_capacity_is_explicit_and_atomic() {
    using Regions = SettledRegions<1, 1, 1, 1, 2, 8>;
    const std::array<DiscoveryCell, 1> one{sand};
    Regions regions(30, 1, 1, 8, 4);
    require(regions.dependency_capacity() == 4,
            "dependency capacity is an explicit bounded runtime resource");
    require(put(regions, key(0, 0, 30), {0, 0, 1, 1}, 1, one) ==
                RegionOutcome::Accepted,
            "dependency-capacity fixture payload accepted");
    drain(regions);
    require(regions.region_count() == 0 &&
            regions.last_refusal() == RegionRefusal::DependencyCapacity,
            "candidate refuses atomically when exact dependency witnesses do not fit");
    require(regions.metrics().dependency_refusals != 0,
            "dependency saturation is observable");
}

void stale_edge_generation_cannot_reconnect_an_old_component() {
    using Regions = SettledRegions<3, 1, 1, 1, 6, 16>;
    const std::array<DiscoveryCell, 1> one{sand};
    const std::array<DiscoveryCell, 1> two{
        DiscoveryCell{2, 7, 3, 220, false}};
    Regions regions(31);

    require(put(regions, key(0, 0, 31), {0, 0, 1, 1}, 1, one) ==
                RegionOutcome::Accepted &&
            put(regions, key(1, 0, 31), {1, 0, 1, 1}, 1, one) ==
                RegionOutcome::Accepted,
            "initial matching edge fixture accepted");
    drain(regions);
    const auto joined = snapshots(regions, 6);
    require(joined.size() == 1 && joined[0].area == 2 &&
            regions.adjacency_count() == 1,
            "single edge slot initially joins the matching pair");

    require(put(regions, key(1, 0, 31), {1, 0, 1, 1}, 2, two) ==
                RegionOutcome::Accepted,
            "middle tile revision retires the old edge generation");
    drain(regions);
    const auto separated = snapshots(regions, 6);
    require(separated.size() == 2,
            "mismatching replacement does not retain the stale edge");
    const auto left = separated[0].min_x == 0 ? separated[0] : separated[1];
    require(left.area == 1, "left component remains independently published");
    const auto left_handle = left.handle;

    require(put(regions, key(2, 0, 31), {2, 0, 1, 1}, 1, two) ==
                RegionOutcome::Accepted,
            "new right tile reuses the bounded edge pool");
    require(regions.snapshot(left_handle).has_value(),
            "edge-slot reuse does not retire an unrelated old-side publication");
    drain(regions);
    const auto final = snapshots(regions, 6);
    require(final.size() == 2 && regions.adjacency_count() == 1,
            "reused edge generation links only the current middle/right components");
    bool saw_left = false, saw_right_pair = false;
    for (const auto& region : final) {
        saw_left = saw_left || (region.min_x == 0 && region.max_x == 0 && region.area == 1);
        saw_right_pair = saw_right_pair ||
                         (region.min_x == 1 && region.max_x == 2 && region.area == 2);
    }
    require(saw_left && saw_right_pair,
            "stale edge generation cannot alias the reused edge slot");
    require(regions.metrics().edge_retirements != 0,
            "edge retirement is accounted through component incidence");
}

void deferred_subscriber_cleanup_is_aba_safe() {
    using Regions = SettledRegions<2, 2, 2, 8, 4, 16>;
    const std::array<DiscoveryCell, 2> full{sand, sand};
    const std::array<DiscoveryCell, 2> local_only{sand, empty};
    const std::array<DiscoveryCell, 1> neighbour{other_state};
    const std::array<DiscoveryCell, 1> neighbour_changed{
        DiscoveryCell{2, 9, 4, 221, false}};
    Regions regions(32);

    require(put(regions, key(0, 0, 32), {0, 0, 2, 1}, 1, full) ==
                RegionOutcome::Accepted &&
            put(regions, key(2, 0, 32), {2, 0, 1, 1}, 1, neighbour) ==
                RegionOutcome::Accepted,
            "ABA fixture initial tiles accepted");
    drain(regions);
    const auto initial = snapshots(regions, 4);
    require(initial.size() == 2, "ABA fixture publishes both initial regions");
    const auto old_local =
        initial[0].min_x == 0 ? initial[0] : initial[1];
    require(old_local.max_x == 1,
            "old local publication subscribes to the facing neighbour revision");

    require(put(regions, key(0, 0, 32), {0, 0, 2, 1}, 2, local_only) ==
                RegionOutcome::Accepted,
            "local revision immediately retires the old publication");
    require(!regions.snapshot(old_local.handle).has_value(),
            "logical retirement precedes deferred reverse-index cleanup");

    std::optional<SettledRegionSnapshot> replacement;
    for (std::size_t work = 0; work < 10000 && !replacement.has_value(); ++work) {
        require(regions.advance(1) <= 1, "ABA fixture keeps exact service budget");
        for (std::size_t slot = 0; slot < 4; ++slot) {
            const auto candidate = regions.region_at(slot);
            if (candidate.has_value() && candidate->min_x == 0 &&
                candidate->max_x == 0 && candidate->area == 1) {
                if (regions.cleanup_pending() != 0)
                    require(candidate->handle.slot != old_local.handle.slot,
                            "live stale references prevent early publication-slot reuse");
                replacement = candidate;
                break;
            }
        }
    }
    require(replacement.has_value(),
            "replacement publication progresses while stale reverse records are reclaimed");
    require(put(regions, key(2, 0, 32), {2, 0, 1, 1}, 2, neighbour_changed) ==
                RegionOutcome::Accepted,
            "old dependency target changes while stale subscriber records remain");
    require(regions.snapshot(replacement->handle).has_value(),
            "stale subscriber generation cannot retire a distinct replacement publication");

    std::size_t cleanup_guard = 0;
    while (regions.pending_components() != 0 && cleanup_guard++ < 100000) {
        const auto used = regions.advance(1);
        require(used <= 1, "ABA forensic drain keeps exact service budget");
        if (used != 0) continue;

        const auto cleanup = regions.test_cleanup_debug();
        const auto old_region = regions.test_region_debug(old_local.handle.slot);
        const auto replacement_region =
            regions.test_region_debug(replacement->handle.slot);
        const auto reclaim_head_region =
            cleanup.region_reclaim_head_slot !=
                    std::numeric_limits<std::uint32_t>::max()
                ? regions.test_region_debug(cleanup.region_reclaim_head_slot)
                : typename Regions::TestRegionDebug{};

        std::cerr
            << "ABA_FORENSIC"
            << " cleanup_pending_count=" << cleanup.cleanup_pending_count
            << " region_reclaim_count=" << cleanup.region_reclaim_count
            << " source_cleanup_live=" << cleanup.source_cleanup_live
            << " source_cleanup_slot=" << cleanup.source_cleanup_slot
            << " seed_cleanup_live=" << cleanup.seed_cleanup_live
            << " seed_cleanup_slot=" << cleanup.seed_cleanup_slot
            << " staged_child_cleanup_live=" << cleanup.staged_child_cleanup_live
            << " staged_child_cleanup_slot=" << cleanup.staged_child_cleanup_slot
            << " source_count=" << cleanup.source_count
            << " seed_count=" << cleanup.seed_count
            << " staged_child_count=" << cleanup.staged_child_count
            << " staged_member_count=" << cleanup.staged_member_count
            << " cleanup_head_valid=" << cleanup.cleanup_head_valid
            << " cleanup_head_slot=" << cleanup.cleanup_head_slot
            << " cleanup_head_generation=" << cleanup.cleanup_head_generation
            << " cleanup_head_active=" << cleanup.cleanup_head_active
            << " cleanup_head_cleanup_pending="
            << cleanup.cleanup_head_cleanup_pending
            << " cleanup_head_dependency_live="
            << cleanup.cleanup_head_dependency_live
            << " region_reclaim_head_slot=" << cleanup.region_reclaim_head_slot
            << "\n";

        const auto print_region = [](const char* name, const auto& region) {
            std::cerr
                << "ABA_FORENSIC_REGION " << name
                << " valid=" << region.valid
                << " reclaim_pending=" << region.reclaim_pending
                << " reclaim_enqueued=" << region.reclaim_enqueued
                << " on_free_list=" << region.on_free_list
                << " generation=" << region.generation
                << " generation_exhausted_recorded="
                << region.generation_exhausted_recorded
                << " member_count=" << region.member_count
                << " member_head_live=" << region.member_head_live
                << " subscriber_slot=" << region.subscriber_slot
                << " subscriber_generation=" << region.subscriber_generation
                << " subscriber_live=" << region.subscriber_live
                << " subscriber_active=" << region.subscriber_active
                << " subscriber_cleanup_pending="
                << region.subscriber_cleanup_pending
                << " subscriber_dependency_live="
                << region.subscriber_dependency_live
                << " preparation_ticket_live="
                << region.preparation_ticket_live
                << "\n";
        };
        print_region("old", old_region);
        print_region("replacement", replacement_region);
        if (cleanup.region_reclaim_head_slot !=
            std::numeric_limits<std::uint32_t>::max())
            print_region("reclaim_head", reclaim_head_region);
        break;
    }
    require(cleanup_guard < 100000,
            "ABA forensic drain remains bounded");

    require(!regions.halted(),
            "deferred subscriber cleanup cannot fail the observer");
    require(!regions.capacity_blocked(),
            "deferred subscriber cleanup cannot capacity-block the observer");
    require(regions.cleanup_pending() == 0,
            "bounded deferred cleanup is eventually reclaimable");
}



void reconstruction_split_is_batch_atomic_under_unit_budget() {
    using Regions = SettledRegions<1, 3, 3, 8, 3, 16>;
    const std::array<DiscoveryCell, 3> joined{sand, sand, sand};
    const std::array<DiscoveryCell, 3> split{sand, empty, sand};
    Regions regions(35);

    require(put(regions, key(0, 0, 35), {0, 0, 3, 1}, 1, joined) ==
                RegionOutcome::Accepted,
            "atomic-split initial component accepted");
    drain(regions);
    const auto before = snapshots(regions, 3);
    require(before.size() == 1 && before[0].area == 3,
            "atomic-split fixture begins as one complete region");
    const auto old = before[0].handle;

    require(put(regions, key(0, 0, 35), {0, 0, 3, 1}, 2, split) ==
                RegionOutcome::Accepted,
            "atomic-split deletion accepted");
    require(!regions.snapshot(old).has_value() && regions.region_count() == 0,
            "old region retires before replacement service");

    std::size_t guard = 0;
    while (regions.region_count() == 0 && guard++ < 10000) {
        require(regions.advance(1) <= 1,
                "atomic split consumes at most one primitive per unit budget");
    }
    require(guard < 10000, "atomic split eventually commits");
    if (regions.region_count() != 2) {
        const auto debug_snapshots = snapshots(regions, 3);
        const auto metrics = regions.metrics();
        std::cerr
            << "ATOMIC_SPLIT_FORENSIC"
            << " region_count=" << regions.region_count()
            << " snapshot_count=" << debug_snapshots.size()
            << " children_staged=" << metrics.reconstruction_children_staged
            << " hidden_preparations=" << metrics.reconstruction_hidden_preparations
            << " batches_committed=" << metrics.reconstruction_batches_committed
            << " tickets=" << metrics.reconstruction_tickets
            << " restarts=" << metrics.reconstruction_restarts
            << " waits=" << metrics.reconstruction_waits
            << " service_units=" << metrics.reconstruction_service_units;
        for (const auto& snapshot : debug_snapshots)
            std::cerr << " area=" << snapshot.area
                      << " min_x=" << snapshot.min_x
                      << " max_x=" << snapshot.max_x;
        std::cerr << "\n";
    }
    require(regions.region_count() == 2,
            "first observable replacement state contains every split child, never a prefix");
    const auto after = snapshots(regions, 3);
    require(after.size() == 2 && after[0].area == 1 && after[1].area == 1,
            "atomic split publishes both exact singleton children");
    require(regions.metrics().reconstruction_children_staged >= 2 &&
            regions.metrics().reconstruction_batches_committed != 0,
            "split staging and one batch commit are observable");
}

void alternate_path_deletion_does_not_false_split() {
    using Regions = SettledRegions<1, 9, 9, 16, 3, 32>;
    const std::array<DiscoveryCell, 9> full{
        sand, sand, sand,
        sand, sand, sand,
        sand, sand, sand,
    };
    const std::array<DiscoveryCell, 9> ring{
        sand, sand, sand,
        sand, empty, sand,
        sand, sand, sand,
    };
    Regions regions(36);
    require(put(regions, key(0, 0, 36), {0, 0, 3, 3}, 1, full) ==
                RegionOutcome::Accepted,
            "alternate-path full tile accepted");
    drain(regions);
    require(regions.region_count() == 1 && snapshots(regions, 3)[0].area == 9,
            "alternate-path fixture begins connected");

    require(put(regions, key(0, 0, 36), {0, 0, 3, 3}, 2, ring) ==
                RegionOutcome::Accepted,
            "alternate-path center deletion accepted");
    drain(regions);
    const auto after = snapshots(regions, 3);
    require(after.size() == 1 && after[0].area == 8 && after[0].complete,
            "alternate path keeps one exact replacement instead of a false split");
}

void intrinsic_region_capacity_refusal_never_publishes_a_subset() {
    using Regions = SettledRegions<1, 3, 3, 8, 1, 16>;
    const std::array<DiscoveryCell, 3> joined{sand, sand, sand};
    const std::array<DiscoveryCell, 3> split{sand, empty, sand};
    Regions regions(37);
    require(put(regions, key(0, 0, 37), {0, 0, 3, 1}, 1, joined) ==
                RegionOutcome::Accepted,
            "capacity-wait initial region accepted");
    drain(regions);
    require(regions.region_count() == 1, "capacity-wait fixture initially publishes");

    require(put(regions, key(0, 0, 37), {0, 0, 3, 1}, 2, split) ==
                RegionOutcome::Accepted,
            "capacity-wait split accepted");
    for (std::size_t work = 0; work < 10000; ++work) {
        const auto used = regions.advance(1);
        require(used <= 1, "capacity refusal respects unit primitive budget");
        require(regions.region_count() == 0,
                "insufficient all-child capacity never leaks one replacement child");
        if (used == 0 && regions.last_refusal() == RegionRefusal::RegionCapacity)
            break;
    }
    require(regions.region_count() == 0 &&
            regions.last_refusal() == RegionRefusal::RegionCapacity,
            "intrinsically unrepresentable all-child publication is explicitly refused");
    require(regions.metrics().reconstruction_waits == 0,
            "intrinsic region-capacity refusal does not hot-wait for impossible capacity");
}

void unknown_reconstruction_waits_for_observation_generation() {
    using Regions = SettledRegions<2, 1, 1, 8, 4, 16>;
    const std::array<DiscoveryCell, 1> one{sand};
    Regions regions(38);
    const auto left = key(0, 0, 38);
    const auto right = key(1, 0, 38);
    require(put(regions, left, {0, 0, 1, 1}, 1, one, 0x0d) ==
                RegionOutcome::Accepted &&
            put(regions, right, {1, 0, 1, 1}, 1, one, 0x07) ==
                RegionOutcome::Accepted,
            "unknown-wait joined fixture accepted");
    drain(regions);
    require(regions.region_count() == 1 && snapshots(regions, 4)[0].area == 2,
            "unknown-wait fixture initially joined");

    require(regions.invalidate(right, 2) == RegionOutcome::Accepted,
            "right dependency becomes explicitly unknown");
    std::size_t guard = 0;
    while (regions.last_refusal() != RegionRefusal::UnknownBoundary &&
           guard++ < 10000)
        require(regions.advance(1) <= 1, "unknown wait remains bounded");
    require(guard < 10000 && regions.region_count() == 0,
            "unknown continuation blocks exact reconstruction without speculation");
    const auto service_before = regions.metrics().reconstruction_service_units;
    for (std::size_t i = 0; i < 32; ++i)
        (void)regions.advance(1);
    require(regions.metrics().reconstruction_service_units <= service_before + 1,
            "unchanged unknown dependency does not hot-spin reconstruction");

    require(put(regions, right, {1, 0, 1, 1}, 2, one, 0x07) ==
                RegionOutcome::Accepted,
            "unknown dependency becomes ready at the same authoritative revision");
    drain(regions);
    const auto after = snapshots(regions, 4);
    require(after.size() == 1 && after[0].area == 2,
            "dependency generation advance resumes exact reconstruction");
}

void unvisited_source_mutation_restarts_before_publication() {
    using Regions = SettledRegions<3, 1, 1, 8, 6, 24>;
    const std::array<DiscoveryCell, 1> one{sand};
    const std::array<DiscoveryCell, 1> hole{empty};
    Regions regions(39);
    require(put(regions, key(0, 0, 39), {0, 0, 1, 1}, 1, one, 0x0d) ==
                RegionOutcome::Accepted &&
            put(regions, key(1, 0, 39), {1, 0, 1, 1}, 1, one, 0x05) ==
                RegionOutcome::Accepted &&
            put(regions, key(2, 0, 39), {2, 0, 1, 1}, 1, one, 0x07) ==
                RegionOutcome::Accepted,
            "unvisited-source fixture accepted");
    drain(regions);
    require(regions.region_count() == 1 && snapshots(regions, 6)[0].area == 3,
            "unvisited-source fixture initially joined");

    require(put(regions, key(0, 0, 39), {0, 0, 1, 1}, 2, hole, 0x0d) ==
                RegionOutcome::Accepted,
            "first source mutation starts reconstruction");
    require(regions.advance(1) <= 1,
            "one admission primitive executes before the unvisited mutation");
    require(put(regions, key(2, 0, 39), {2, 0, 1, 1}, 2, hole, 0x07) ==
                RegionOutcome::Accepted,
            "unvisited old member mutates during reconstruction");
    require(regions.region_count() == 0,
            "stale attempt cannot publish against mixed revisions");
    drain(regions);
    const auto after = snapshots(regions, 6);
    require(after.size() == 1 && after[0].area == 1 &&
            after[0].min_x == 1 && after[0].max_x == 1,
            "restart publishes only the exact surviving current component");
    require(regions.metrics().reconstruction_restarts != 0,
            "unvisited source mutation is recorded as a reconstruction restart");
}

void retained_ticket_fairness_survives_sustained_local_churn() {
    using Regions = SettledRegions<2, 1, 1, 8, 4, 16>;
    const std::array<DiscoveryCell, 1> one{sand};
    Regions regions(40);
    const auto local = key(0, 0, 40);
    const auto remote = key(1000, 1000, 40);
    require(put(regions, local, {0, 0, 1, 1}, 1, one) ==
                RegionOutcome::Accepted &&
            put(regions, remote, {1000, 1000, 1, 1}, 1, one) ==
                RegionOutcome::Accepted,
            "fairness fixture initial regions accepted");
    drain(regions);

    require(put(regions, local, {0, 0, 1, 1}, 2, one) ==
                RegionOutcome::Accepted &&
            put(regions, remote, {1000, 1000, 1, 1}, 2, one) ==
                RegionOutcome::Accepted,
            "two independent reconstruction tickets are admitted");

    bool remote_visible = false;
    std::uint64_t revision = 3;
    for (std::size_t step = 0; step < 4000 && !remote_visible; ++step) {
        require(regions.advance(1) <= 1, "fairness service remains primitive-bounded");
        if ((step % 7U) == 6U) {
            require(put(regions, local, {0, 0, 1, 1}, revision++, one) ==
                        RegionOutcome::Accepted,
                    "sustained local churn remains admissible");
        }
        for (const auto& snapshot : snapshots(regions, 4))
            if (snapshot.min_x == 1000 && snapshot.area == 1)
                remote_visible = true;
    }
    require(remote_visible,
            "older unrelated remote admitted work receives positive service under local churn");
    require(regions.metrics().reconstruction_restarts != 0 &&
            regions.metrics().reconstruction_service_units != 0,
            "fairness and churn are separately observable");
}


void large_reconstruction_yields_to_remote_ticket() {
    using Regions = SettledRegions<9, 1, 1, 32, 12, 64>;
    const std::array<DiscoveryCell, 1> one{sand};
    const std::array<DiscoveryCell, 1> hole{empty};
    Regions regions(42);

    for (std::int64_t x = 0; x < 8; ++x) {
        std::uint8_t sealed = 0x05;
        if (x == 0) sealed |= 0x08;
        if (x == 7) sealed |= 0x02;
        require(put(regions, key(x, 0, 42), {x, 0, 1, 1}, 1, one, sealed) ==
                    RegionOutcome::Accepted,
                "large-fairness local member accepted");
    }
    require(put(regions, key(1000, 1000, 42), {1000, 1000, 1, 1}, 1, one) ==
                RegionOutcome::Accepted,
            "large-fairness remote member accepted");
    drain(regions);
    require(regions.region_count() == 2,
            "large-fairness fixture begins with local and remote publications");

    require(put(regions, key(3, 0, 42), {3, 0, 1, 1}, 2, hole, 0x05) ==
                RegionOutcome::Accepted,
            "large local deletion starts a multi-child reconstruction");
    require(put(regions, key(1000, 1000, 42), {1000, 1000, 1, 1}, 2, one) ==
                RegionOutcome::Accepted,
            "remote stable region is independently admitted for reconstruction");

    bool remote_visible = false;
    bool local_visible_before_remote = false;
    for (std::size_t step = 0; step < 20000 && !remote_visible; ++step) {
        require(regions.advance(1) <= 1,
                "large-fairness service stays primitive-bounded");
        for (const auto& snapshot : snapshots(regions, 12)) {
            if (snapshot.min_x == 1000 && snapshot.area == 1)
                remote_visible = true;
            if (snapshot.min_x < 100 && snapshot.area != 0)
                local_visible_before_remote = true;
        }
    }
    require(remote_visible,
            "remote admitted ticket completes while a larger local ticket remains active");
    require(!local_visible_before_remote,
            "large local reconstruction cannot monopolize service through its first commit");
    require(regions.metrics().reconstruction_service_units != 0,
            "round-robin reconstruction service is observable");
}

void refused_reconstruction_never_falls_back_to_prefix_publication() {
    using Regions = SettledRegions<
        1, 3, 3, 8, 3, 16,
        std::numeric_limits<std::uint64_t>::max(), 1>;
    const std::array<DiscoveryCell, 3> joined{sand, sand, sand};
    const std::array<DiscoveryCell, 3> split{sand, empty, sand};
    Regions regions(43);

    require(put(regions, key(0, 0, 43), {0, 0, 3, 1}, 1, joined) ==
                RegionOutcome::Accepted,
            "refusal-fence initial component accepted");
    drain(regions);
    require(regions.region_count() == 1,
            "refusal-fence fixture consumes its sole publication serial");

    require(put(regions, key(0, 0, 43), {0, 0, 3, 1}, 2, split) ==
                RegionOutcome::Accepted,
            "refusal-fence split mutation accepted");
    for (std::size_t step = 0; step < 20000; ++step) {
        const auto used = regions.advance(1);
        require(used <= 1, "refusal-fence service remains primitive-bounded");
        require(regions.region_count() == 0,
                "refused all-child reconstruction never leaks a fallback child");
        if (used == 0 &&
            regions.last_refusal() == RegionRefusal::GenerationExhausted)
            break;
    }
    require(regions.region_count() == 0 &&
            regions.last_refusal() == RegionRefusal::GenerationExhausted,
            "static publication exhaustion leaves an explicit refused ticket and no prefix");
    for (std::size_t step = 0; step < 64; ++step) {
        (void)regions.advance(1);
        require(regions.region_count() == 0,
                "ordinary seed seeking stays fenced behind a refused reconstruction");
    }
}


void many_child_split_publishes_one_atomic_batch() {
    using Regions = SettledRegions<1, 9, 9, 16, 8, 32>;
    const std::array<DiscoveryCell, 9> plus{
        empty, sand, empty,
        sand,  sand, sand,
        empty, sand, empty,
    };
    const std::array<DiscoveryCell, 9> four{
        empty, sand, empty,
        sand,  empty, sand,
        empty, sand, empty,
    };
    Regions regions(44);
    require(put(regions, key(0, 0, 44), {0, 0, 3, 3}, 1, plus) ==
                RegionOutcome::Accepted,
            "many-child plus accepted");
    drain(regions);
    require(regions.region_count() == 1 && snapshots(regions, 8)[0].area == 5,
            "many-child fixture begins as one plus component");

    require(put(regions, key(0, 0, 44), {0, 0, 3, 3}, 2, four) ==
                RegionOutcome::Accepted,
            "many-child center deletion accepted");
    std::size_t guard = 0;
    while (regions.region_count() == 0 && guard++ < 20000)
        require(regions.advance(1) <= 1, "many-child split is primitive bounded");
    require(guard < 20000 && regions.region_count() == 4,
            "first visible replacement state contains all four children");
    const auto found = snapshots(regions, 8);
    require(found.size() == 4,
            "many-child split exposes exactly four complete replacements");
    for (const auto& region : found)
        require(region.area == 1 && region.complete,
                "every many-child replacement is a complete singleton");
}

void mutation_during_frontier_traversal_restarts_exactly() {
    using Regions = SettledRegions<5, 1, 1, 16, 8, 32>;
    const std::array<DiscoveryCell, 1> one{sand};
    const std::array<DiscoveryCell, 1> hole{empty};
    Regions regions(45);
    for (std::int64_t x = 0; x < 5; ++x) {
        std::uint8_t sealed = 0x05;
        if (x == 0) sealed |= 0x08;
        if (x == 4) sealed |= 0x02;
        require(put(regions, key(x, 0, 45), {x, 0, 1, 1}, 1, one, sealed) ==
                    RegionOutcome::Accepted,
                "frontier-mutation chain member accepted");
    }
    drain(regions);
    require(regions.region_count() == 1 && snapshots(regions, 8)[0].area == 5,
            "frontier-mutation fixture begins connected");

    require(put(regions, key(2, 0, 45), {2, 0, 1, 1}, 2, hole, 0x05) ==
                RegionOutcome::Accepted,
            "frontier-mutation bridge deletion accepted");
    std::size_t guard = 0;
    while (regions.metrics().reconstruction_traversal_units < 2 && guard++ < 10000)
        require(regions.advance(1) <= 1, "frontier traversal remains bounded");
    require(guard < 10000 && regions.region_count() == 0,
            "frontier traversal begins before any child publication");

    require(put(regions, key(4, 0, 45), {4, 0, 1, 1}, 2, hole, 0x07) ==
                RegionOutcome::Accepted,
            "unvisited frontier member mutates during traversal");
    drain(regions);
    const auto found = snapshots(regions, 8);
    require(found.size() == 2,
            "frontier mutation restarts to the two exact surviving components");
    bool left = false, right = false;
    for (const auto& region : found) {
        left = left || (region.min_x == 0 && region.max_x == 1 && region.area == 2);
        right = right || (region.min_x == 3 && region.max_x == 3 && region.area == 1);
    }
    require(left && right && regions.metrics().reconstruction_restarts != 0,
            "mixed-revision frontier work never publishes");
}

void mutations_before_and_during_preparation_never_leak_children() {
    const std::array<DiscoveryCell, 3> joined{sand, sand, sand};
    const std::array<DiscoveryCell, 3> split{sand, empty, sand};
    const std::array<DiscoveryCell, 3> right_only{empty, empty, sand};

    {
        using Regions = SettledRegions<1, 3, 3, 8, 4, 16>;
        Regions regions(46);
        require(put(regions, key(0, 0, 46), {0, 0, 3, 1}, 1, joined) ==
                    RegionOutcome::Accepted,
                "post-traversal fixture accepted");
        drain(regions);
        require(put(regions, key(0, 0, 46), {0, 0, 3, 1}, 2, split) ==
                    RegionOutcome::Accepted,
                "post-traversal split accepted");
        std::size_t guard = 0;
        while (regions.metrics().reconstruction_children_staged == 0 &&
               guard++ < 10000)
            require(regions.advance(1) <= 1, "post-traversal staging bounded");
        require(guard < 10000 &&
                regions.metrics().reconstruction_hidden_preparations == 0 &&
                regions.region_count() == 0,
                "a complete staged child remains externally hidden before preparation");
        require(put(regions, key(0, 0, 46), {0, 0, 3, 1}, 3, right_only) ==
                    RegionOutcome::Accepted,
                "mutation after traversal but before preparation accepted");
        drain(regions);
        const auto found = snapshots(regions, 4);
        require(found.size() == 1 && found[0].min_x == 2 && found[0].area == 1,
                "post-traversal mutation cancels stale staged topology");
    }

    {
        using Regions = SettledRegions<1, 3, 3, 8, 4, 16>;
        Regions regions(47);
        require(put(regions, key(0, 0, 47), {0, 0, 3, 1}, 1, joined) ==
                    RegionOutcome::Accepted,
                "preparation-mutation fixture accepted");
        drain(regions);
        require(put(regions, key(0, 0, 47), {0, 0, 3, 1}, 2, split) ==
                    RegionOutcome::Accepted,
                "preparation-mutation split accepted");
        std::size_t guard = 0;
        while (regions.metrics().reconstruction_hidden_preparations == 0 &&
               guard++ < 20000) {
            require(regions.advance(1) <= 1, "hidden preparation remains bounded");
            require(regions.region_count() == 0,
                    "prepared subset cannot become visible before ticket commit");
        }
        require(guard < 20000 && regions.region_count() == 0,
                "at least one hidden prepared child exists without prefix publication");
        require(put(regions, key(0, 0, 47), {0, 0, 3, 1}, 3, right_only) ==
                    RegionOutcome::Accepted,
                "mutation during staged preparation accepted");
        require(regions.region_count() == 0,
                "mutation during preparation cannot expose the hidden child");
        drain(regions);
        const auto found = snapshots(regions, 4);
        require(found.size() == 1 && found[0].min_x == 2 && found[0].area == 1 &&
                regions.metrics().reconstruction_restarts != 0,
                "prepared stale children are retired before exact replacement commit");
    }
}

void intrinsic_frontier_and_dependency_exhaustion_refuse_without_prefix() {
    {
        using Regions = SettledRegions<1, 5, 5, 8, 6, 2>;
        const std::array<DiscoveryCell, 5> joined{sand, sand, sand, sand, sand};
        const std::array<DiscoveryCell, 5> three{sand, empty, sand, empty, sand};
        Regions regions(48);
        require(put(regions, key(0, 0, 48), {0, 0, 5, 1}, 1, joined) ==
                    RegionOutcome::Accepted,
                "frontier-exhaustion initial region accepted");
        drain(regions);
        require(regions.region_count() == 1, "frontier-exhaustion initial publication exists");
        require(put(regions, key(0, 0, 48), {0, 0, 5, 1}, 2, three) ==
                    RegionOutcome::Accepted,
                "frontier-exhaustion split accepted");
        std::size_t guard = 0;
        while (guard++ < 20000) {
            const auto used = regions.advance(1);
            require(regions.region_count() == 0,
                    "frontier exhaustion cannot publish a subset");
            if (used == 0 && regions.last_refusal() == RegionRefusal::FrontierCapacity)
                break;
        }
        require(guard < 20000 &&
                regions.last_refusal() == RegionRefusal::FrontierCapacity,
                "intrinsic frontier demand is a stable typed refusal");
    }

    {
        using Regions = SettledRegions<1, 3, 3, 8, 4, 16>;
        const std::array<DiscoveryCell, 3> joined{sand, sand, sand};
        const std::array<DiscoveryCell, 3> split{sand, empty, sand};
        Regions regions(49, 1, 8, 16, 6);
        require(put(regions, key(0, 0, 49), {0, 0, 3, 1}, 1, joined) ==
                    RegionOutcome::Accepted,
                "dependency-exhaustion initial region accepted");
        drain(regions);
        require(regions.region_count() == 1,
                "dependency-exhaustion initial publication fits the bounded pool");
        require(put(regions, key(0, 0, 49), {0, 0, 3, 1}, 2, split) ==
                    RegionOutcome::Accepted,
                "dependency-exhaustion split accepted");
        std::size_t guard = 0;
        while (guard++ < 30000) {
            const auto used = regions.advance(1);
            require(regions.region_count() == 0,
                    "dependency exhaustion cannot publish a subset");
            if (used == 0 &&
                regions.last_refusal() == RegionRefusal::DependencyCapacity)
                break;
        }
        require(guard < 30000 &&
                regions.last_refusal() == RegionRefusal::DependencyCapacity,
                "intrinsic dependency demand is a stable typed refusal");
    }
}

void reclamation_pressure_is_bounded_and_eventually_drains() {
    using Regions = SettledRegions<6, 1, 1, 16, 12, 32>;
    const std::array<DiscoveryCell, 1> one{sand};
    Regions regions(50);
    for (std::int64_t x = 0; x < 6; ++x)
        require(put(regions, key(x * 100, 0, 50), {x * 100, 0, 1, 1}, 1, one) ==
                    RegionOutcome::Accepted,
                "reclamation-pressure initial region accepted");
    drain(regions);
    require(regions.region_count() == 6,
            "reclamation-pressure fixture begins with six publications");

    for (std::int64_t x = 0; x < 6; ++x)
        require(put(regions, key(x * 100, 0, 50), {x * 100, 0, 1, 1}, 2, one) ==
                    RegionOutcome::Accepted,
                "reclamation-pressure replacement admitted");

    bool saw_reconstruction = false, saw_reclamation = false;
    for (std::size_t step = 0; step < 50000 && regions.pending_components() != 0; ++step) {
        require(regions.advance(1) <= 1, "reclamation-pressure service is unit bounded");
        const auto metrics = regions.metrics();
        saw_reconstruction = saw_reconstruction || metrics.reconstruction_service_units != 0;
        saw_reclamation = saw_reclamation || metrics.reclamation_units != 0;
    }
    require(regions.region_count() == 6 &&
            saw_reconstruction && saw_reclamation,
            "cleanup receives bounded service without preventing reconstruction progress");
    drain(regions);
    require(regions.cleanup_pending() == 0 &&
            regions.metrics().reclamation_high_water != 0,
            "deferred reclamation eventually completes and records bounded pressure");
}


void region_capacity_retry_waits_for_region_generation() {
    using Regions = SettledRegions<2, 3, 3, 8, 2, 16>;
    const std::array<DiscoveryCell, 3> joined{sand, sand, sand};
    const std::array<DiscoveryCell, 3> split{sand, empty, sand};
    const std::array<DiscoveryCell, 1> one{sand};
    const std::array<DiscoveryCell, 1> hole{empty};
    Regions regions(51);

    require(put(regions, key(0, 0, 51), {0, 0, 3, 1}, 1, joined) ==
                RegionOutcome::Accepted &&
            put(regions, key(100, 0, 51), {100, 0, 1, 1}, 1, one) ==
                RegionOutcome::Accepted,
            "region-generation fixture fills both publication slots");
    drain(regions);
    require(regions.region_count() == 2, "both initial slots are visible");

    require(put(regions, key(0, 0, 51), {0, 0, 3, 1}, 2, split) ==
                RegionOutcome::Accepted,
            "two-child split starts with only one reclaimable source slot");
    std::size_t guard = 0;
    while (regions.last_refusal() != RegionRefusal::RegionCapacity &&
           guard++ < 20000)
        require(regions.advance(1) <= 1, "region-capacity wait is bounded");
    require(guard < 20000 && regions.region_count() == 1,
            "split waits without a prefix while unrelated publication occupies a slot");

    const auto service_before = regions.metrics().reconstruction_service_units;
    for (std::size_t i = 0; i < 32; ++i)
        (void)regions.advance(1);
    require(regions.metrics().reconstruction_service_units <= service_before + 1,
            "unchanged region-slot blocker does not hot-spin");

    require(put(regions, key(100, 0, 51), {100, 0, 1, 1}, 2, hole) ==
                RegionOutcome::Accepted,
            "unrelated publication is removed and its slot becomes reclaimable");
    guard = 0;
    while (regions.region_count() != 2 && guard++ < 30000)
        require(regions.advance(1) <= 1, "region-generation retry remains bounded");
    require(guard < 30000,
            "relevant region resource generation resumes the blocked split");
    const auto found = snapshots(regions, 2);
    require(found.size() == 2 && found[0].area == 1 && found[1].area == 1,
            "retry publishes the complete two-child result only after capacity exists");
}

void older_ticket_survives_later_low_key_arrivals() {
    using Regions = SettledRegions<13, 1, 1, 32, 20, 96>;
    const std::array<DiscoveryCell, 1> one{sand};
    const std::array<DiscoveryCell, 1> hole{empty};
    Regions regions(52);

    for (std::int64_t x = 0; x < 5; ++x)
        require(put(regions, key(x * 10, 0, 52), {x * 10, 0, 1, 1}, 1, one) ==
                    RegionOutcome::Accepted,
                "low-key arrival fixture accepted");
    for (std::int64_t x = 1000; x < 1008; ++x) {
        std::uint8_t sealed = 0x05;
        if (x == 1000) sealed |= 0x08;
        if (x == 1007) sealed |= 0x02;
        require(put(regions, key(x, 0, 52), {x, 0, 1, 1}, 1, one, sealed) ==
                    RegionOutcome::Accepted,
                "older high-key chain accepted");
    }
    drain(regions);
    require(regions.region_count() == 6,
            "older-ticket fixture begins with five small regions and one chain");

    require(put(regions, key(1003, 0, 52), {1003, 0, 1, 1}, 2, hole, 0x05) ==
                RegionOutcome::Accepted,
            "older retained high-key reconstruction admitted first");

    std::uint64_t local_revision = 2;
    std::size_t next_local = 0;
    bool high_key_visible = false;
    for (std::size_t step = 0; step < 50000 && !high_key_visible; ++step) {
        require(regions.advance(1) <= 1, "arrival fairness service remains bounded");
        if ((step % 3U) == 2U && next_local < 5) {
            const auto x = static_cast<std::int64_t>(next_local) * 10;
            require(put(regions, key(x, 0, 52), {x, 0, 1, 1},
                        local_revision++, one) == RegionOutcome::Accepted,
                    "later lower-key reconstruction arrival admitted");
            ++next_local;
        }
        for (const auto& region : snapshots(regions, 20))
            if (region.min_x >= 1000)
                high_key_visible = true;
    }
    require(high_key_visible,
            "later low-key arrivals cannot permanently starve the older retained ticket");
}

void reconstruction_does_not_rescan_unrelated_components() {
    using Regions = SettledRegions<9, 1, 1, 32, 16, 64>;
    const std::array<DiscoveryCell, 1> one{sand};
    const std::array<DiscoveryCell, 1> hole{empty};
    Regions regions(53);

    for (std::int64_t x = 0; x < 6; ++x)
        require(put(regions, key(x * 100, 100, 53),
                    {x * 100, 100, 1, 1}, 1, one) ==
                    RegionOutcome::Accepted,
                "locality far publication accepted");
    for (std::int64_t x = 1000; x < 1003; ++x) {
        std::uint8_t sealed = 0x05;
        if (x == 1000) sealed |= 0x08;
        if (x == 1002) sealed |= 0x02;
        require(put(regions, key(x, 0, 53), {x, 0, 1, 1}, 1, one, sealed) ==
                    RegionOutcome::Accepted,
                "locality affected chain accepted");
    }
    drain(regions);
    require(regions.region_count() == 7,
            "locality fixture begins fully published");
    const auto before = snapshots(regions, 16);
    std::optional<SettledRegionSnapshot> far_before;
    for (const auto& region : before)
        if (region.min_y == 100 && region.min_x == 500) far_before = region;
    require(far_before.has_value(), "locality far handle captured");
    const auto seed_probes_before = regions.metrics().seed_probes;

    require(put(regions, key(1001, 0, 53), {1001, 0, 1, 1}, 2, hole, 0x05) ==
                RegionOutcome::Accepted,
            "locality bridge deletion accepted");
    std::size_t guard = 0;
    while (regions.region_count() != 8 && guard++ < 30000) {
        require(regions.advance(1) <= 1, "locality reconstruction is primitive bounded");
        require(regions.snapshot(far_before->handle).has_value(),
                "stable unrelated publication remains current during local reconstruction");
    }
    require(guard < 30000,
            "affected reconstruction commits without waiting for a global seed pass");
    require(regions.metrics().seed_probes == seed_probes_before,
            "ticket reconstruction does not invoke the ordinary global component seeker");
}


void reconstruction_ticket_order_is_budget_shape_deterministic() {
    using Regions = SettledRegions<4, 1, 1, 8, 8, 24>;
    const std::array<DiscoveryCell, 1> one{sand};
    Regions unit(54), chunked(54);

    for (std::int64_t x = 0; x < 4; ++x) {
        const auto k = key(x * 100, 0, 54);
        const DiscoveryBounds bounds{x * 100, 0, 1, 1};
        require(put(unit, k, bounds, 1, one) == RegionOutcome::Accepted &&
                put(chunked, k, bounds, 1, one) == RegionOutcome::Accepted,
                "determinism initial regions accepted");
    }
    drain(unit);
    drain(chunked);

    constexpr std::array<std::int64_t, 4> order{300, 0, 200, 100};
    for (const auto x : order) {
        const auto k = key(x, 0, 54);
        const DiscoveryBounds bounds{x, 0, 1, 1};
        require(put(unit, k, bounds, 2, one) == RegionOutcome::Accepted &&
                put(chunked, k, bounds, 2, one) == RegionOutcome::Accepted,
                "determinism replacement ticket admitted");
    }

    drain_budget(unit, 1);
    drain_budget(chunked, 7);
    const auto a = snapshots(unit, 8);
    const auto b = snapshots(chunked, 8);
    if (a.size() != b.size() || a.size() != 4) {
        const auto am = unit.metrics();
        const auto bm = chunked.metrics();
        std::cerr
            << "DETERMINISM_FORENSIC"
            << " unit_count=" << a.size()
            << " chunked_count=" << b.size()
            << " unit_pending=" << unit.pending_components()
            << " chunked_pending=" << chunked.pending_components()
            << " unit_cleanup=" << unit.cleanup_pending()
            << " chunked_cleanup=" << chunked.cleanup_pending()
            << " unit_refusal=" << static_cast<unsigned>(unit.last_refusal())
            << " chunked_refusal=" << static_cast<unsigned>(chunked.last_refusal())
            << " unit_tickets=" << am.reconstruction_tickets
            << " chunked_tickets=" << bm.reconstruction_tickets
            << " unit_batches=" << am.reconstruction_batches_committed
            << " chunked_batches=" << bm.reconstruction_batches_committed
            << " unit_restarts=" << am.reconstruction_restarts
            << " chunked_restarts=" << bm.reconstruction_restarts
            << " unit_service=" << am.reconstruction_service_units
            << " chunked_service=" << bm.reconstruction_service_units
            << "\n";
        for (const auto& snapshot : a)
            std::cerr << "DETERMINISM_UNIT"
                      << " slot=" << snapshot.handle.slot
                      << " gen=" << snapshot.handle.generation
                      << " x=" << snapshot.min_x
                      << " serial=" << snapshot.publication_serial << "\n";
        for (const auto& snapshot : b)
            std::cerr << "DETERMINISM_CHUNKED"
                      << " slot=" << snapshot.handle.slot
                      << " gen=" << snapshot.handle.generation
                      << " x=" << snapshot.min_x
                      << " serial=" << snapshot.publication_serial << "\n";
    }
    require(a.size() == b.size() && a.size() == 4,
            "determinism runs publish the same region count");
    for (std::size_t i = 0; i < a.size(); ++i)
        require(same_region_semantics(a[i], b[i]),
                "ticket order and publication identity are budget-shape deterministic");
}

void reclaimed_region_slot_reuse_rejects_stale_handle() {
    using Regions = SettledRegions<1, 1, 1, 4, 1, 8>;
    const std::array<DiscoveryCell, 1> one{sand};
    Regions regions(41);
    const auto tile = key(0, 0, 41);
    require(put(regions, tile, {0, 0, 1, 1}, 1, one) ==
                RegionOutcome::Accepted,
            "slot-reuse initial region accepted");
    drain(regions);
    const auto first = snapshots(regions, 1);
    require(first.size() == 1, "slot-reuse initial region published");
    const auto stale = first[0].handle;

    require(put(regions, tile, {0, 0, 1, 1}, 2, one) ==
                RegionOutcome::Accepted,
            "slot-reuse replacement revision accepted");
    require(!regions.snapshot(stale).has_value(),
            "old generation is invalid immediately");
    drain(regions);
    const auto replacement = snapshots(regions, 1);
    require(replacement.size() == 1 &&
            replacement[0].handle.slot == stale.slot &&
            replacement[0].handle.generation != stale.generation,
            "slot is reused only after reclamation under a new generation");
    require(!regions.snapshot(stale).has_value() &&
            regions.snapshot(replacement[0].handle).has_value(),
            "stale generation cannot alias the reclaimed publication slot");
    require(regions.metrics().member_reclaims != 0 &&
            regions.metrics().reclamation_units != 0,
            "member and reclamation work are explicitly accounted");
}

void subscriber_slot_reuse_drops_stale_reverse_links() {
    using Regions = SettledRegions<3, 1, 1, 4, 6, 16>;
    const std::array<DiscoveryCell, 1> local{sand};
    const std::array<DiscoveryCell, 1> empty_cell{empty};
    const std::array<DiscoveryCell, 1> neighbour{other_state};
    const std::array<DiscoveryCell, 1> neighbour_changed{
        DiscoveryCell{1, 9, 4, 221, false}};
    Regions regions(34);

    require(put(regions, key(0, 0, 34), {0, 0, 1, 1}, 1, local, 0x0d) ==
                RegionOutcome::Accepted &&
            put(regions, key(1, 0, 34), {1, 0, 1, 1}, 1, neighbour, 0x07) ==
                RegionOutcome::Accepted,
            "subscriber-reuse fixture initial neighbours accepted");
    drain(regions);
    require(regions.region_count() == 2,
            "subscriber-reuse fixture publishes both nonmatching neighbours");

    require(put(regions, key(0, 0, 34), {0, 0, 1, 1}, 2, empty_cell, 0x0d) ==
                RegionOutcome::Accepted,
            "retiring local component makes old subscriber generations stale");
    drain(regions);
    require(regions.cleanup_pending() == 0,
            "old subscriber reverse links are reclaimed before slot reuse");

    require(put(regions, key(1000, 1000, 34), {1000, 1000, 1, 1}, 1, local) ==
                RegionOutcome::Accepted,
            "far sealed candidate accepted after subscriber reclamation");
    drain(regions);
    const auto current = snapshots(regions, 6);
    std::optional<SettledRegionSnapshot> far;
    for (const auto& candidate : current)
        if (candidate.min_x == 1000) far = candidate;
    require(far.has_value(), "far replacement publication exists");
    require(regions.metrics().subscriber_reuses != 0,
            "a generation-bearing subscriber slot was actually reused");

    require(put(regions, key(0, 0, 34), {0, 0, 1, 1}, 3, empty_cell, 0x0d) ==
                RegionOutcome::Accepted,
            "first old dependency target advances after subscriber reuse");
    require(regions.snapshot(far->handle).has_value(),
            "first stale reverse target cannot invalidate reused subscriber slot");

    require(put(regions, key(1, 0, 34), {1, 0, 1, 1}, 2, neighbour_changed, 0x07) ==
                RegionOutcome::Accepted,
            "second old dependency target advances after subscriber reuse");
    require(regions.snapshot(far->handle).has_value(),
            "second stale reverse target cannot invalidate reused subscriber slot");
    drain(regions);
    require(regions.snapshot(far->handle).has_value(),
            "reused subscriber remains generation-safe after deferred maintenance");
}

void absence_subscription_invalidates_only_actual_face_users() {
    using Regions = SettledRegions<3, 1, 1, 4, 6, 16>;
    const std::array<DiscoveryCell, 1> one{sand};
    Regions regions(33);
    const auto local = key(0, 0, 33);
    const auto far = key(1000, 1000, 33);

    require(put(regions, local, {0, 0, 1, 1}, 1, one) ==
                RegionOutcome::Accepted &&
            put(regions, far, {1000, 1000, 1, 1}, 1, one) ==
                RegionOutcome::Accepted,
            "absence-fanout fixture accepted");
    drain(regions);
    const auto before = snapshots(regions, 6);
    require(before.size() == 2, "local and far publications exist");
    const auto local_region = before[0].min_x == 0 ? before[0] : before[1];
    const auto far_region = before[0].min_x == 1000 ? before[0] : before[1];

    const auto invalidations_before = regions.metrics().subscriber_invalidations;
    require(regions.register_unknown(
                key(1, 0, 33), {1, 0, 1, 1}, 1) == RegionOutcome::Accepted,
            "new facing residency is registered unknown before payload");
    require(!regions.snapshot(local_region.handle).has_value(),
            "new-facing unknown revokes the exact local absence certificate immediately");
    require(regions.snapshot(far_region.handle).has_value(),
            "far publication is not retired by unrelated residency");
    require(regions.metrics().subscriber_invalidations > invalidations_before,
            "absence target reaches its actual reverse subscribers");
}

} // namespace

int main() {
    try {
        single_tile_holes_and_exact_keys();
        refusal_and_revision_guards();
        unknown_registration_retires_faces_without_consuming_payload();
        cross_tile_seams_and_unknown_boundary();
        deterministic_insertion_and_publication();
        bridge_and_split_retire_old_handles();
        capacity_refusal_preserves_authoritative_inputs();
        bounded_capacity_never_publishes_a_prefix();
        mutation_during_seed_seek_restarts_canonical_selection();
        negative_seams_diagonals_and_partial_work();
        remote_publication_survives_local_churn();
        multi_tile_ring_and_many_tile_solid();
        exact_key_seams_and_local_shapes();
        unknown_middle_component_capacity_and_new_match();
        generation_exhaustion_never_revalidates_old_handle();
        local_churn_does_not_cancel_inflight_remote_region();
        dependency_capacity_is_explicit_and_atomic();
        stale_edge_generation_cannot_reconnect_an_old_component();
        deferred_subscriber_cleanup_is_aba_safe();
        reconstruction_split_is_batch_atomic_under_unit_budget();
        alternate_path_deletion_does_not_false_split();
        intrinsic_region_capacity_refusal_never_publishes_a_subset();
        unknown_reconstruction_waits_for_observation_generation();
        unvisited_source_mutation_restarts_before_publication();
        retained_ticket_fairness_survives_sustained_local_churn();
        large_reconstruction_yields_to_remote_ticket();
        refused_reconstruction_never_falls_back_to_prefix_publication();
        many_child_split_publishes_one_atomic_batch();
        mutation_during_frontier_traversal_restarts_exactly();
        mutations_before_and_during_preparation_never_leak_children();
        intrinsic_frontier_and_dependency_exhaustion_refuse_without_prefix();
        reclamation_pressure_is_bounded_and_eventually_drains();
        region_capacity_retry_waits_for_region_generation();
        older_ticket_survives_later_low_key_arrivals();
        reconstruction_does_not_rescan_unrelated_components();
        reconstruction_ticket_order_is_budget_shape_deterministic();
        reclaimed_region_slot_reuse_rejects_stale_handle();
        subscriber_slot_reuse_drops_stale_reverse_links();
        absence_subscription_invalidates_only_actual_face_users();
        std::cout << "settled region tests passed\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "settled region test failure: " << error.what() << '\n';
        return 1;
    }
}
