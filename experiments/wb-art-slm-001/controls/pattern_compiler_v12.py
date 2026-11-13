"""EXPERIMENTAL compiler 1.2: v1.1 coral spread with rooted, connected colonies.

Opt-in and deliberately NOT native-qualified. This does not mutate frozen v1
or v1.1 source, model inference, native Art authority or production defaults.
"""
from __future__ import annotations
import hashlib
import importlib.util
import math
from pathlib import Path
import sys

BASE_COMPILER_SHA256 = 'a259392c25643109cefbfc360e491a72731e4082e58b0ae8337c5c9a8023aadb'
COMPILER_VERSION = 'wb-art-slm-001/1.2.0-rooted-coral-experimental'
BASE_PATH = Path(__file__).with_name('pattern_compiler.py')


def _rooted_fan(builder, rng, layer):
    """Use v1.1's fan layout and append a bounded same-region rooting tree.

    Each parent precedes its child, ensuring a connected acyclic skeleton.
    No connector crosses a disjoint border region or split reflection axis.
    All strokes, clipping and work budgets remain enforced by the v1 builder.
    """
    x, y, w, h = builder.region
    density = layer['density']
    count = 2 + int(density * 5)
    columns = max(1, min(count, round(math.sqrt(count * w / max(h, 1)))))
    rows = math.ceil(count / columns)
    stroke = _v1._stroke(builder, layer)
    centers = []
    for index in range(count):
        col, row = index % columns, index // columns
        cx = x + w * (col + 0.5 + rng.uniform(-0.10, 0.10)) / columns
        cy = y + h * (row + 0.62 + rng.uniform(-0.09, 0.09)) / rows
        centers.append((cx, cy))
        radius = min(w / columns * 0.54, h / rows * 0.47) * (0.80 + layer['scale'] * 0.40)
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
    # The deterministic spanning tree runs only within this v1 region.
    # Maintain the original fan's RNG stream; connectors consume no randoms.
    for index in range(1, count):
        child = centers[index]
        parent = min(centers[:index], key=lambda p: ((p[0]-child[0])**2 + (p[1]-child[1])**2))
        builder.line(child, parent, max(1, stroke))
    # Root to the *local* region bottom without bridging an intentional void.
    lowest = max(centers, key=lambda p: p[1])
    builder.line(lowest, (lowest[0], y+h-2), max(1, stroke))


def _load_isolated_v1():
    if hashlib.sha256(BASE_PATH.read_bytes()).hexdigest() != BASE_COMPILER_SHA256:
        raise RuntimeError('frozen v1 compiler SHA256 mismatch')
    spec = importlib.util.spec_from_file_location('_wb_art_slm_v12_preserved_v1', BASE_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    module._DRAW = dict(module._DRAW)
    module._DRAW['fan'] = _rooted_fan
    return module

_v1 = _load_isolated_v1()
THEMES = _v1.THEMES
MODIFIERS = _v1.MODIFIERS
CompilerError = _v1.CompilerError
make_program = _v1.make_program
validate_program = _v1.validate_program
canonical_json = _v1.canonical_json
reflected_operation = _v1.reflected_operation

def compile_with_report(program, width, height, seed, material=58, *, max_shapes=2048, max_estimated_cells=131072):
    result = _v1.compile_with_report(program,width,height,seed,material,
                                     max_shapes=max_shapes,max_estimated_cells=max_estimated_cells)
    result['compiler_version'] = COMPILER_VERSION
    result['base_compiler_sha256'] = BASE_COMPILER_SHA256
    return result

def compile_program(program,width,height,seed,material=58,*,max_shapes=2048,max_estimated_cells=131072):
    return compile_with_report(program,width,height,seed,material,max_shapes=max_shapes,
                               max_estimated_cells=max_estimated_cells)['operations']
