"""Additional receipted edits to generated S1 copies. Accepted files unchanged."""
import importlib.util
import json
from pathlib import Path
import shutil

S1 = Path('tools/experiments/mat003_prepass')
HERE = Path('tools/experiments/mat003_continuation')


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def prepare(source, output, representation, bits, extra=2):
    original = module(source / S1 / 'world_overlay.py', 'accepted_overlay')
    s2a = module(source / 'tools/experiments/mat003_s2a/apparatus.py', 'accepted_s2a')
    reg = json.loads((source / S1 / 'world_registration.json').read_text())
    base_repr = 'packed' if representation == 'memcpy' else (
        'aligned' if representation in ('u128', 'dual64') or bits > 16 else representation)
    base_bits = min(bits, 16)
    arm = next(a for a in reg['arms'] if a['representation'] == base_repr and
               a['epoch_bits'] == base_bits and a['neutral_extra_bits'] == extra * 8)
    receipt = original.prepare_overlay(source, output, arm)
    shutil.copyfile(source / HERE / 'candidates.hpp', output / S1 / 'candidates.hpp')
    patches = receipt['patches']

    def edit(relative, old, new, label):
        path = output / relative
        path.write_text(original._replace(path.read_text(), old, new, label, patches, str(relative)), encoding='utf-8')

    adapter = S1 / 'world_adapter.hpp'
    edit(adapter, '#include "carriers.hpp"', '#include "carriers.hpp"\n#include "candidates.hpp"', 'include continuation candidates')
    if representation == 'memcpy':
        edit(adapter, 'using Representation = mat003::Packed<MAT003_EXTRA_BYTES>;',
             'using Representation = mat003_continuation::MemcpyPacked<MAT003_EXTRA_BYTES>;', 'select memcpy')
    if representation in ('u128', 'dual64'):
        edit(adapter, 'using Representation = mat003::Aligned<MAT003_EXTRA_BYTES>;',
             'using Representation = mat003_continuation::' + ('U128' if representation == 'u128' else 'Dual64') + ';', 'select C128')
    if bits > 16:
        edit(adapter, 'using Epoch = std::conditional_t<epoch_bits == 8, std::uint8_t, std::uint16_t>;',
             'using Epoch = std::uint32_t;', 'wide counter and accessor')
        edit(adapter, 'static_assert(epoch_bits == 8 || epoch_bits == 16);',
             'static_assert(epoch_bits == 24 || epoch_bits == 32);', 'wide width gate')
        # Replace both inheritance and Base alias.
        for old in ('struct EngineCell : mat003::Cell<Representation, epoch_bits> {',
                    '    using Base = mat003::Cell<Representation, epoch_bits>;'):
            edit(adapter, old, old.replace('mat003::Cell', 'mat003_continuation::WideCell'), 'wide field mapping')
        edit(Path('native/src/world.cpp'),
             '    update_epoch_ = static_cast<mat003_world::Epoch>(update_epoch_ + 1U);',
             '    update_epoch_ = static_cast<mat003_world::Epoch>((std::uint64_t{update_epoch_} + 1U) & mat003_world::EngineCell::epoch_limit);',
             'explicit E24/E32 modulo without signed overflow')
    receipt['observer_patch'] = s2a.patch_observer_off(output)
    macros = receipt['compile_definitions']
    macros = [m for m in macros if not m.startswith('-DMAT003_EPOCH_BITS=')]
    macros = [m for m in macros if not m.startswith('-DMAT003_ARM_ID=')]
    capacity = 128 if representation in ('u128','dual64') else 64 + extra * 8
    macros.append(f'-DMAT003_ARM_ID="C{capacity}-E{bits}-{representation}"')
    macros.append('-DMAT003_EPOCH_BITS=' + str(bits))
    receipt.update(continuation_representation=representation, continuation_epoch_bits=bits,
                   compile_definitions=macros)
    (output / 'continuation-overlay.json').write_text(json.dumps(receipt, indent=2) + '\n')
    return receipt
