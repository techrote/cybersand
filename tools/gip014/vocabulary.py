"""Independent finite goblin-002 evidence vocabulary; no game dispatch authority."""
from __future__ import annotations

import math

MAX_ACTIONS = 1024
FIXTURES = ("material_playground", "actor_workshop", "construction", "liquid_channel", "save_reopen",
            "history_edges", "boundary_lab", "alchemy", "mixed_stress", "conservation_cell")
POLICIES = ("CONTROL", "WANDERER", "BUILDER", "TINKERER", "CURIOSITY", "RANDOM", "STATEFUL", "NOVELTY",
            "COVERAGE_HUNTER", "DISASTER_ARTIST", "BOUNDARY_GOBLIN", "HISTORY_GOBLIN", "MATERIAL_ALCHEMIST",
            "ACTOR_ENTHUSIAST", "IMPATIENT_SWITCHER", "OBSESSIVE_REPRODUCER")
MATERIALS = (0, 2, 3, 7, 8, 9, 12, 13, 14, 16, 19, 23, 25, 26, 27, 28, 29, 58)
MODELS = ("kestrel", "reference_barrel", "runner", "crawler", "monowheel", "stuntbuggy")
TOOLS = ("Brush", "Eraser", "Line", "Rectangle", "Outline", "Select", "Fill", "Paste")
NEW_EMPTY = {"preview_cancel", "camera_focus", "actor_remove", "actor_capture_spawn", "actor_release",
             "actor_hand_back", "restore_start", "source_burst"}
NEW_ARGUMENTS = {
    "select_tool": {"tool"}, "brush_radius": {"radius"},
    "stroke": {"x0", "y0", "x1", "y1", "radius"}, "live_stroke": {"x0", "y0", "x1", "y1", "radius"},
    "preview_begin": {"x0", "y0", "x1", "y1"}, "interrupt_stroke": {"x0", "y0", "x1", "y1"},
    "camera_pan": {"dx", "dy"}, "camera_zoom": {"direction"}, "camera_mode": {"mode"},
    "actor_move": {"x", "y"}, "actor_save_spawn": {"x", "y"}, "actor_replace": {"model"},
    "actor_control": {"actor_id", "producer", "enabled"}, "actor_equipment": {"actor_id", "usable_index"},
    "actor_actuate": {"port", "ticks"}, "actor_trigger": {"button", "ticks"},
    "response_mode": {"mode"}, "actor_settings": {"field", "value"}, "source_place": {"x", "y"},
    "source_stream": {"enabled"}, "replace_fixture": {"fixture"},
    **{name: set() for name in NEW_EMPTY},
}


def integral(value) -> bool:
    return type(value) is int or (type(value) is float and math.isfinite(value) and value.is_integer())


def bound(value, low, high) -> bool:
    return integral(value) and low <= value <= high


def real_bound(value, low, high) -> bool:
    return type(value) in (int, float) and math.isfinite(value) and low <= value <= high


def expanded_action_valid(name: str, args: dict) -> bool:
    """Independent mirror of the public typed adapter contract, including types."""
    if name not in NEW_ARGUMENTS or set(args) != NEW_ARGUMENTS[name]:
        return False
    if name in NEW_EMPTY:
        return True
    if name == "select_tool":
        return args["tool"] in TOOLS
    if name == "brush_radius":
        return bound(args["radius"], 0, 4)
    if name in {"stroke", "live_stroke", "preview_begin", "interrupt_stroke"}:
        points = all(bound(args[k], 8, 503) for k in ("x0", "y0", "x1", "y1"))
        return points and abs(args["x0"] - args["x1"]) <= 32 and abs(args["y0"] - args["y1"]) <= 32 and ("radius" not in args or bound(args["radius"], 0, 4))
    if name == "camera_pan":
        return bound(args["dx"], -128, 128) and bound(args["dy"], -128, 128)
    if name == "camera_zoom":
        return integral(args["direction"]) and args["direction"] in (-1, 1)
    if name == "camera_mode":
        return args["mode"] in ("free", "follow", "overview")
    if name in {"actor_move", "actor_save_spawn"}:
        return bound(args["x"], 32, 448) and bound(args["y"], 32, 224)
    if name == "actor_replace":
        return args["model"] in MODELS
    if name == "actor_control":
        return bound(args["actor_id"], 1, 64) and args["producer"] in ("human", "scripted", "passive") and type(args["enabled"]) is bool
    if name == "actor_equipment":
        return bound(args["actor_id"], 1, 64) and bound(args["usable_index"], -1, 31)
    if name == "actor_actuate":
        return args["port"] in ("q", "e", "boost", "primary", "secondary", "reel_in", "reel_out") and bound(args["ticks"], 1, 16)
    if name == "actor_trigger":
        return args["button"] in ("trigger", "alternate", "drop", "attach") and bound(args["ticks"], 1, 16)
    if name == "response_mode":
        return args["mode"] in ("LA-SELECTIVE", "LA", "LA-EVENT-OFF", "RFT")
    if name == "actor_settings":
        return (args["field"] == "budget" and real_bound(args["value"], 5, 40)) or (args["field"] in ("mass_multiplier", "inertia_multiplier") and real_bound(args["value"], 0.5, 2.0))
    if name == "source_place":
        return bound(args["x"], 8, 480) and bound(args["y"], 8, 224)
    if name == "source_stream":
        return type(args["enabled"]) is bool
    if name == "replace_fixture":
        return args["fixture"] in FIXTURES
    return False
