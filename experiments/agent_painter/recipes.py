"""Small hand-authored curriculum; seeds/paraphrases never determine the split.

The five designs per family are separate structural/compositional groups. The
fifth is reserved FINAL and excluded from training, development and galleries.
Shared primitives are intentional; this is a composition holdout, not a claim
of unseen primitive morphology. Native admission is supplied separately.
"""
from __future__ import annotations

from copy import deepcopy

SEEDS = (104729, 130363)
SPLITS = ("TRAIN", "TRAIN", "DEVELOPMENT", "DEVELOPMENT", "FINAL")


def _panel(box, detail, density=2, border=1, fasteners=True):
    return {"kind": "panel", "box": box, "detail": detail, "density": density,
            "border": border, "fasteners": fasteners}


def _program(family, components, requirements, variation=2):
    return {"version": 2, "family": family, "components": components,
            "requirements": requirements, "variation": variation}


def _greebles(panels):
    return _program("greebles", panels, {"negative_space_min_percent": 45})


def _pipes(nodes, edges, diameter=5, cycles=0):
    return _program("pipework", [{"kind": "pipe_network", "nodes": nodes,
                     "edges": edges, "diameter": diameter, "fittings": True}],
                    {"connected": True, "cycles": cycles})


def _opening(side, offset, size):
    return {"side": side, "offset": offset, "size": size}


def _room(box, openings=()):
    return {"kind": "room", "box": box, "thickness": 2, "openings": list(openings)}


def _architecture(components, route, region, clearance=5):
    return _program("architecture", components,
                    {"route": route, "clearance": clearance, "region": region})


_RECIPES = {
    "greebles": [
        ("service_cluster", "Greebles: build a large vent panel with a smaller inset, staggered plating below and a narrow ribbed module. Keep clear gaps and corner fasteners.",
         _greebles([_panel([7, 9, 48, 42], "vent", 3), _panel([62, 9, 26, 28], "inset"),
                     _panel([7, 59, 63, 27], "plates", 2), _panel([77, 49, 14, 38], "ribs", 2)])),
        ("switchboard_stack", "Greebles: compose one tall grille beside a vertical stack of three differently sized plates, vents and inset controls; preserve nonuniform empty gaps.",
         _greebles([_panel([8, 8, 28, 77], "grille", 3, 2), _panel([44, 8, 43, 24], "plates", 2),
                     _panel([44, 40, 43, 18], "vent", 2), _panel([44, 66, 43, 20], "inset", 2)])),
        ("open_center_modules", "Greebles: arrange four distinct machine modules around a deliberately empty center. Use different panel sizes, vent directions, inset detail and fasteners.",
         _greebles([_panel([8, 8, 29, 24], "vent", 2), _panel([51, 8, 35, 32], "inset", 3),
                     _panel([8, 59, 34, 29], "grille", 2), _panel([53, 65, 33, 23], "plates", 2)])),
        ("spine_assembly", "Greebles: make a narrow ribbed central spine with four unequal machinery panels on either side. Keep two vertical service gaps and avoid repeated tile stamps.",
         _greebles([_panel([40, 8, 17, 78], "ribs", 2), _panel([8, 9, 24, 29], "vent", 2),
                     _panel([8, 49, 24, 37], "inset", 2), _panel([65, 8, 22, 44], "grille", 3),
                     _panel([65, 61, 22, 25], "plates", 2)])),
        ("staggered_cassettes", "Greebles: create three staggered cassettes of different sizes, with inset, grille and plating details, plus a separated ventilation panel.",
         _greebles([_panel([7, 7, 37, 26], "inset"), _panel([52, 21, 35, 30], "grille", 3),
                     _panel([13, 53, 37, 34], "plates", 3), _panel([59, 61, 28, 26], "vent", 2)])),
    ],
    "pipework": [
        ("two_elbow_route", "Pipework: draw one continuous five-cell-wide pipe from the upper left, around two right-angle elbows, to the lower right. Add collars; exactly two open ends and no branches.",
         _pipes([[12, 20], [52, 20], [52, 75], [84, 75]], [[0, 1], [1, 2], [2, 3]])),
        ("tee_distribution", "Pipework: make a connected T distributor with a horizontal trunk and one upward branch. Keep all three arms five cells wide, three open ends, one explicit junction and fitted collars.",
         _pipes([[12, 48], [48, 48], [84, 48], [48, 14]], [[0, 1], [1, 2], [1, 3]])),
        ("three_branch_manifold", "Pipework: construct a horizontal manifold with three upward branches at unequal heights. Use a consistent three-cell pipe width, explicit T junctions, five endpoints and no loops or accidental crossings.",
         _pipes([[10, 72], [28, 72], [48, 72], [68, 72], [86, 72], [28, 18], [48, 32], [68, 18]],
                [[0, 1], [1, 2], [2, 3], [3, 4], [1, 5], [2, 6], [3, 7]], 3)),
        ("closed_loop_with_tap", "Pipework: make one closed rectangular three-cell-wide loop with a single left-facing tap joined at an explicit T fitting. Preserve the empty interior, one endpoint and one true loop.",
         _pipes([[20, 24], [72, 24], [72, 72], [20, 72], [20, 48], [7, 48]],
                [[0, 1], [1, 2], [2, 3], [3, 4], [4, 0], [4, 5]], 3, 1)),
        ("double_loop_bridge", "Pipework: form two joined rectangular loops sharing one central pipe. All segments are five cells wide, both junctions are explicit, no endpoints remain, and both loop interiors stay open.",
         _pipes([[16, 24], [48, 24], [80, 24], [16, 72], [48, 72], [80, 72]],
                [[0, 1], [1, 2], [2, 5], [5, 4], [4, 3], [3, 0], [1, 4]], 5, 2)),
    ],
    "architecture": [
        ("paired_doorway_rooms", "Architecture: in strict flat 2D side elevation, build two adjacent rooms with level floors and a shared ground-level doorway. Connect left and right interior anchors with at least five cells of square clearance.",
         _architecture([_room([8, 24, 40, 60], [_opening("right", 44, 14)]),
                        _room([46, 24, 40, 60], [_opening("left", 44, 14)])],
                       [[20, 74], [74, 74]], [10, 26, 74, 56])),
        ("stair_and_landing_hall", "Architecture: draw a side-elevation hall containing six ascending steps and a raised landing. Leave a five-cell-clear free-space connection from the low left anchor to the upper right; all walls remain vertical and floors horizontal.",
         _architecture([_room([7, 13, 82, 73], [_opening("left", 55, 16), _opening("right", 55, 16)]),
                        {"kind": "stairs", "box": [29, 57, 36, 27], "steps": 6, "rise": "right"},
                        {"kind": "platform", "box": [65, 54, 20, 3]}],
                       [[17, 76], [77, 45]], [9, 15, 78, 69])),
        ("stacked_rooms_and_shaft", "Architecture: build two stacked chambers in flat side view, connected by a broad opening through the shared floor. Add a supported lower platform and preserve a five-cell-clear route through the shaft between the room anchors.",
         _architecture([_room([10, 8, 76, 38], [_opening("bottom", 30, 16)]),
                        _room([10, 44, 76, 44], [_opening("top", 30, 16)]),
                        {"kind": "platform", "box": [12, 66, 25, 3]},
                        {"kind": "support", "box": [20, 69, 3, 17]}],
                       [[24, 28], [70, 70]], [12, 10, 72, 76])),
        ("bridge_between_towers", "Architecture: compose two narrow side-elevation towers with facing doorways and an elevated enclosed bridge. Support the bridge from below, retain the large lower voids, and keep five cells of clear passage between tower anchors.",
         _architecture([_room([6, 18, 26, 68], [_opening("right", 10, 18)]),
                        _room([64, 18, 26, 68], [_opening("left", 10, 18)]),
                        {"kind": "platform", "box": [30, 44, 36, 3]},
                        {"kind": "floor", "box": [30, 26, 36, 2]},
                        {"kind": "support", "box": [44, 47, 4, 38]},
                        {"kind": "floor", "box": [7, 84, 82, 2]}],
                       [[18, 37], [78, 37]], [8, 20, 80, 64])),
        ("three_bay_arcade", "Architecture: arrange three adjacent side-elevation chambers with aligned ground-floor doors and a supported shelf in the first bay. Preserve a continuous five-cell-clear interior connection across all three bays.",
         _architecture([_room([6, 28, 30, 58], [_opening("right", 40, 16)]),
                        _room([34, 28, 30, 58], [_opening("left", 40, 16), _opening("right", 40, 16)]),
                        _room([62, 28, 28, 58], [_opening("left", 40, 16)]),
                        {"kind": "platform", "box": [9, 48, 14, 2]},
                        {"kind": "support", "box": [16, 50, 3, 16]}],
                       [[18, 76], [78, 76]], [8, 30, 80, 54])),
    ],
}


def all_recipes(include_final: bool = True) -> list[dict]:
    result = []
    for family, entries in _RECIPES.items():
        for index, (name, prompt, program) in enumerate(entries):
            split = SPLITS[index]
            if split == "FINAL" and not include_final:
                continue
            result.append({"group_id": f"{family}/{name}/v1", "structural_group": f"{family}/{name}/v1",
                           "family": family, "design": name, "split": split,
                           "prompt": prompt, "program": deepcopy(program)})
    return result
