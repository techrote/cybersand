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
    require(regions.region_count() == 0 &&
            regions.last_refusal() == RegionRefusal::GenerationExhausted &&
            !regions.snapshot(stale).has_value(),
            "generation exhaustion refuses publication instead of wrapping a stale handle");

    require(put(regions, tile_key, {0, 0, 1, 1}, 3, one) == RegionOutcome::Accepted,
            "post-exhaustion input can still be observed without identity reuse");
    drain(regions);
    require(regions.region_count() == 0 &&
            regions.last_refusal() == RegionRefusal::GenerationExhausted &&
            !regions.snapshot(stale).has_value(),
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
    drain(regions);
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

void reconstruction_capacity_wait_never_publishes_a_subset() {
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
        require(used <= 1, "capacity wait respects unit primitive budget");
        require(regions.region_count() == 0,
                "insufficient all-child capacity never leaks one replacement child");
        if (used == 0 && regions.last_refusal() == RegionRefusal::RegionCapacity)
            break;
    }
    require(regions.region_count() == 0 &&
            regions.last_refusal() == RegionRefusal::RegionCapacity &&
            regions.metrics().reconstruction_waits != 0,
            "all-child publication remains explicitly blocked on stable capacity");
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
        reconstruction_capacity_wait_never_publishes_a_subset();
        unknown_reconstruction_waits_for_observation_generation();
        unvisited_source_mutation_restarts_before_publication();
        retained_ticket_fairness_survives_sustained_local_churn();
        large_reconstruction_yields_to_remote_ticket();
        refused_reconstruction_never_falls_back_to_prefix_publication();
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
