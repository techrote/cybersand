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
        local_churn_does_not_cancel_inflight_remote_region();
        std::cout << "settled region tests passed\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "settled region test failure: " << error.what() << '\n';
        return 1;
    }
}
