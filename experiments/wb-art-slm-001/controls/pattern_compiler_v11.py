"""Opt-in compiler 1.1: distribute coral/fan colonies vertically.

This is a distinct compiler identity layered over immutable v1 source. It is NOT
an in-place replacement for admitted v1 corpus geometry or for the step-400
adapter's pinned inference contract. Neither file changes native Art authority.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import sys

COMPILER_VERSION = "wb-art-slm-001/1.1.0-coral-spread"
BASE_COMPILER_SHA256 = "a259392c25643109cefbfc360e491a72731e4082e58b0ae8337c5c9a8023aadb"
BASE_PATH = Path(__file__).with_name("pattern_compiler.py")


def _balanced_fan(builder, rng, layer):
    """Distribute fan colonies over a cell grid instead of a bottom baseline.

    The v1 fan placed all colonies at 72–95% height, leaving most of the upper
    field empty. Density still determines colony/branch count; narrow border
    regions get aspect-aware grids and remain independently clipped by v1.
    """
    x, y, w, h = builder.region
    density = layer["density"]
    count = 2 + int(density * 5)
    columns = max(1, min(count, round(math.sqrt(count * w / max(h, 1)))))
    rows = math.ceil(count / columns)
    stroke = _v1._stroke(builder, layer)
    for index in range(count):
        col, row = index % columns, index // columns
        cx = x + w * (col + 0.5 + rng.uniform(-0.10, 0.10)) / columns
        cy = y + h * (row + 0.62 + rng.uniform(-0.09, 0.09)) / rows
        radius = min(w / columns * 0.54, h / rows * 0.47) * (0.80 + layer["scale"] * 0.40)
        arms = 4 + int(density * 7)
        for arm in range(arms):
            angle = -math.pi * 0.92 + arm / max(1, arms - 1) * math.pi * 0.84
            length = radius * rng.uniform(0.65, 1.12)
            tip = (cx + math.cos(angle) * length, cy + math.sin(angle) * length)
            middle = (cx + math.cos(angle) * length * 0.45,
                      cy + math.sin(angle) * length * 0.65)
            builder.polyline([(cx, cy), middle, tip], stroke)
            builder.disc(tip, max(1, stroke))
            if arm % 2 == 0:
                side = (middle[0] + math.cos(angle - 0.5) * length * 0.35,
                        middle[1] + math.sin(angle - 0.5) * length * 0.35)
                builder.line(middle, side, 1)


def _load_preserved_v1():
    if hashlib.sha256(BASE_PATH.read_bytes()).hexdigest() != BASE_COMPILER_SHA256:
        raise RuntimeError("v1 compiler source differs from the frozen admitted source")
    spec = importlib.util.spec_from_file_location("_wb_art_slm_v11_preserved_v1", BASE_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    # This private module is not the ordinarily imported v1 module. Never patch
    # shared v1 module state, since corpus hashes and adapters still use it.
    module._DRAW = dict(module._DRAW)
    module._DRAW["fan"] = _balanced_fan
    return module


_v1 = _load_preserved_v1()
THEMES = _v1.THEMES
MOTIFS = _v1.MOTIFS
MODIFIERS = _v1.MODIFIERS
LAYOUTS = _v1.LAYOUTS
CompilerError = _v1.CompilerError
validate_program = _v1.validate_program
make_program = _v1.make_program
structural_signature = _v1.structural_signature
canonical_json = _v1.canonical_json
reflected_operation = _v1.reflected_operation


def compile_with_report(program, width, height, seed, material=58, *,
                        max_shapes=2048, max_estimated_cells=131072):
    result = _v1.compile_with_report(program, width, height, seed, material,
                                     max_shapes=max_shapes,
                                     max_estimated_cells=max_estimated_cells)
    # Preserve v1 substream seeds, so only programs using the fan motif change.
    # Identity is nevertheless distinct to protect native/corpus provenance.
    result["compiler_version"] = COMPILER_VERSION
    result["base_compiler_sha256"] = BASE_COMPILER_SHA256
    return result


def compile_program(program, width, height, seed, material=58, *,
                    max_shapes=2048, max_estimated_cells=131072):
    return compile_with_report(program, width, height, seed, material,
                               max_shapes=max_shapes,
                               max_estimated_cells=max_estimated_cells)["operations"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--theme", choices=THEMES)
    source.add_argument("--program", type=Path)
    parser.add_argument("--variant", type=int, default=0)
    parser.add_argument("--modifier", action="append", default=[], choices=MODIFIERS)
    parser.add_argument("--width", type=int, default=96)
    parser.add_argument("--height", type=int, default=96)
    parser.add_argument("--seed", type=int, default=17)
    parser.add_argument("--material", type=int, default=58, choices=(0, 58))
    parser.add_argument("--out", type=Path)
    parser.add_argument("--report", action="store_true")
    args = parser.parse_args()
    try:
        program = json.loads(args.program.read_text()) if args.program else make_program(args.theme, args.variant, args.modifier)
        result = compile_with_report(program, args.width, args.height, args.seed, args.material)
        data = json.dumps(result if args.report else result["operations"], indent=2, allow_nan=False) + "\n"
        if args.out:
            args.out.write_text(data)
        else:
            print(data, end="")
    except (CompilerError, json.JSONDecodeError, OSError) as exc:
        parser.exit(2, f"pattern compilation refused: {exc}\n")


if __name__ == "__main__":
    main()
