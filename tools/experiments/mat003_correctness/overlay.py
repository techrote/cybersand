"""Append-only source generation only; never builds or runs the generated World."""
import sys
sys.dont_write_bytecode=True
import hashlib
import importlib.util
import json
import shutil
from pathlib import Path
HERE=Path('tools/experiments/mat003_correctness')
S1=Path('tools/experiments/mat003_prepass')

def prepare(source, output, arm_id):
    source,output=Path(source).resolve(),Path(output).resolve()
    names={'K64':64,'K72':72,'K80':80,'D128':128}
    prefix,epoch=arm_id.split('-E');capacity=names[prefix];bits=int(epoch)
    if bits not in (8,16):raise ValueError('unreviewed epoch')
    spec=importlib.util.spec_from_file_location('frozen_s1_overlay',source/S1/'world_overlay.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    reg=json.loads((source/S1/'world_registration.json').read_text(encoding='utf-8-sig'))
    representation='word' if capacity==64 else 'packed'
    extra=0 if capacity==64 else (1 if capacity==72 else 2)
    arm=next(a for a in reg['arms'] if a['representation']==representation and a['epoch_bits']==bits and a['neutral_extra_bits']==extra*8)
    receipt=module.prepare_overlay(source,output,arm)
    shutil.copyfile(source/HERE/'world_adapter.hpp',output/S1/'world_adapter.hpp')
    shutil.copyfile(source/HERE/'maps.hpp',output/S1/'maps.hpp')
    shutil.copyfile(source/HERE/'trace.hpp',output/S1/'trace.hpp')
    shutil.copyfile(source/HERE/'resource.hpp',output/S1/'resource.hpp')
    receipt['compile_definitions']=[m if not m.startswith('-DMAT003_WORLD_SOURCE=') else '-DMAT003_WORLD_SOURCE='+chr(34)+(output/'native/src/world.cpp').as_posix()+chr(34) for m in receipt['compile_definitions']]
    receipt['compile_definitions'] += [f'-DMAT003_CAPACITY={capacity}']
    world=output/'native/src/world.cpp'
    text=world.read_text(encoding='utf-8')
    text=module._replace(text,'const auto neighbour = [this, x, y](std::size_t index) {','const auto neighbour = [x, y](std::size_t index) {','remove unused neighbour capture in generated copy only',receipt['patches'],'native/src/world.cpp')
    old='    if (update_epoch_ == 0) {'
    text=module._replace(text,old,old+'\n        ++mat003_world::clear_count;\n        for (const auto& [key, owner] : chunks_) { (void)key; mat003_world::clear_cells += owner->cells.size(); }','clear traversal observer',receipt['patches'],'native/src/world.cpp')
    world.write_text(text,encoding='utf-8')
    prepare_probe(source,output)
    receipt['reviewed_arm']=arm_id
    receipt['files_after_all_edits']={p.relative_to(output).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(output.rglob('*')) if p.is_file()}
    (output/'reviewed-overlay.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    return receipt

def prepare_probe(source, output):
    """Source-bound friend observer plus reviewed extensions; no compilation."""
    source,output=Path(source),Path(output)
    fixture=(source/S1/'test_world.cpp').read_text(encoding='utf-8-sig')
    marker='    static void fill_forced(World& world) {'
    if fixture.count(marker)!=1:raise ValueError('S1 probe prefix drift')
    prefix=fixture.split(marker)[0]
    continuation=source/'tools/experiments/mat003_continuation/qualify.py'
    spec=importlib.util.spec_from_file_location('frozen_continuation',continuation)
    # Parse the literal rather than importing collector code or executing it.
    import ast
    tree=ast.parse(continuation.read_text(encoding='utf-8-sig'))
    rebase=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='PROBE' for t in n.targets))
    extension=(source/HERE/'probe.inc').read_text(encoding='utf-8-sig')
    (output/S1/'probe.hpp').write_text(prefix+extension+rebase,encoding='utf-8')
    shutil.copyfile(source/HERE/'world.cpp',output/S1/'reviewed_world.cpp')
    shutil.copyfile(source/HERE/'lifecycle.hpp',output/S1/'lifecycle.hpp')
