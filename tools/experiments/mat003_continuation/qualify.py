"""Frozen-input untimed collector. No new benchmark/timing execution path."""
from __future__ import annotations
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import time
import overlay

ROOT = Path(__file__).resolve().parents[3]
HERE = Path('tools/experiments/mat003_continuation')
S1 = overlay.S1
COMMON = ['native/src/material_rules.cpp', 'native/src/scheduler_geometry.cpp', 'native/src/settled_world_discovery.cpp']
BASE = '2b2a1dd64f16dc46d5e812b757de73f47df0fb2b'


def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def dump(p, v):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(v, indent=2, sort_keys=True) + '\n', encoding='utf-8')


def compress_streams(root):
    for p in root.rglob('*.bin'):
        p.with_suffix(p.suffix+'.gz').write_bytes(gzip.compress(p.read_bytes(),mtime=0))
        p.unlink()


def seal_generated(work):
    dump(work/'generated-source-seal.json', {p.relative_to(work).as_posix():digest(p)
         for p in sorted(work.rglob('*')) if p.is_file() and p.name!='generated-source-seal.json'})


PROBE = r'''
    static std::uint64_t prepare_clear(World& world, std::uint64_t target) {
        fixture::require(!world.tick_in_progress_ && !world.tick_failed_, "invalid preparation boundary");
        const auto previous = world.update_epoch_;
        fixture::require(target != 0, "zero target epoch");
        std::uint64_t count = 0;
        for (auto& [coord, chunk] : world.chunks_) {
            (void)coord;
            for (auto& cell : chunk->cells) {
                const bool current = cell.epoch_value() == previous;
                // The natural E8 event keeps EVERY raw stamp unchanged.
                if (target != previous) cell.set_epoch(static_cast<Epoch>(current ? target : 0));
                fixture::require((cell.epoch_value() == static_cast<Epoch>(target)) == current,
                                 "preparation changed current-stamp predicate");
                if (target != previous)
                    fixture::require(cell.epoch_value() == (current ? target : 0), "exact prepared stamp mismatch");
                ++count;
            }
        }
        world.update_epoch_ = static_cast<Epoch>(target);
        return count;
    }
};
} // namespace cybersand
'''


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--track', choices=['s2p', 'wclear', 'c128'], required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--compiler', default='g++-13')
    ap.add_argument('--local-toolchain-diagnostic', action='store_true')
    args = ap.parse_args()
    out = args.output.resolve()
    if out.exists():
        raise SystemExit('append-only output already exists')
    out.mkdir(parents=True)
    started = time.monotonic() # Collector budget only; never World timing.
    report = dict(status='incomplete', track=args.track, formal_timing_admitted=False,
                  source_head=subprocess.check_output(['git','rev-parse','HEAD'], cwd=ROOT, text=True).strip(),
                  commands=[], cases=[], builds=[], errors=[], source_sha256={})
    flags = json.loads((ROOT / HERE / 's2p-registration.json').read_text())['flags']
    compiler = shutil.which(args.compiler)
    if not compiler:
        raise SystemExit('compiler not found')
    env = os.environ.copy()
    env['PATH'] = str(Path(compiler).parent) + os.pathsep + env['PATH']

    def run(argv, label, timeout):
        if time.monotonic() - started > 3600:
            raise ValueError('qualification wall budget exceeded')
        row = dict(argv=list(map(str, argv)), label=label, timeout=timeout, exit_code=None)
        report['commands'].append(row)
        for suffix in ('stdout','stderr'):
            (out / (label + '.' + suffix)).parent.mkdir(parents=True, exist_ok=True)
        with (out / (label + '.stdout')).open('wb') as stdout, (out / (label + '.stderr')).open('wb') as stderr:
            try:
                row['exit_code'] = subprocess.run(row['argv'], cwd=ROOT, env=env, stdout=stdout, stderr=stderr, timeout=timeout).returncode
            except subprocess.TimeoutExpired:
                row['timed_out'] = True
        dump(out / 'progress.json', report)
        if row['exit_code'] != 0:
            raise ValueError('failed command: ' + label)
        return (out / (label + '.stdout')).read_text()

    try:
        version = run([compiler, '--version'], 'compiler', 10)
        report['compiler_version'] = version
        report['compiler_sha256'] = digest(Path(compiler))
        report['platform'] = platform.platform()
        report['qualified_toolchain'] = platform.system() == 'Linux' and '13.3.0' in version
        if not args.local_toolchain_diagnostic and not report['qualified_toolchain']:
            raise ValueError('requires Linux GCC 13.3.0; local diagnostic cannot admit anything')
        # Seal all source inputs before builds. Check accepted inputs against Git,
        # not just another mutable working-tree manifest.
        source = out / 'source'
        s1reg = json.loads((ROOT / S1 / 'world_registration.json').read_text())
        files = set(s1reg['baseline_control_sha256'])
        for folder in [S1, HERE, Path('tools/experiments/mat003_s2a')]:
            files.update(p.relative_to(ROOT).as_posix() for p in (ROOT / folder).iterdir()
                         if p.is_file() and p.suffix in ('.py','.cpp','.hpp','.json'))
        for name in sorted(files):
            p = source / name
            p.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, p)
            report['source_sha256'][name] = digest(p)
            if not name.startswith(HERE.as_posix() + '/'):
                original = subprocess.check_output(['git','show',BASE + ':' + name], cwd=ROOT)
                if hashlib.sha256(original).hexdigest() != digest(p):
                    raise ValueError('accepted input changed: ' + name)
        dump(out / 'source-seal.json', report['source_sha256'])
        common = []
        for name in COMMON:
            obj = out / 'objects' / (Path(name).stem + '.o')
            obj.parent.mkdir(parents=True, exist_ok=True)
            run([compiler,*flags,'-I'+str(source/'native/include'),'-c',source/name,'-o',obj], 'common/'+obj.stem,180)
            common.append(obj)
        if args.track == 's2p':
            arms = [('word',8,0),('packed',8,1),('packed',8,2),('aligned',8,1),('aligned',8,2),('split',8,1),('split',8,2),
                    ('memcpy',8,1),('memcpy',8,2),('memcpy',16,1),('memcpy',16,2)]
        elif args.track == 'c128':
            arms = [(r,e,2) for r in ['u128','dual64'] for e in [8,16]]
        else:
            arms = [('aligned',e,2) for e in [8,16,24,32]]
        for rep,bits,extra in arms:
            identifier = f'{rep}-e{bits}-x{extra}'
            print('untimed qualification:', args.track, identifier, flush=True)
            work = out / 'overlays' / identifier
            receipt = overlay.prepare(source, work, rep, bits, extra)
            macros = receipt['compile_definitions']
            includes = ['-I'+str(work/'native/include'),'-I'+str(work/S1)]
            binary = out/'bin'/(identifier + ('.exe' if os.name == 'nt' else ''))
            binary.parent.mkdir(parents=True, exist_ok=True)
            assembly = out/'assembly'/identifier
            assembly.mkdir(parents=True)
            if args.track != 'wclear':
                # Extern wrappers expose exact compiler choices for isolated
                # access, update, copy and swap alongside the full World TU.
                wrapper = assembly/'access.cpp'
                wrapper.write_text('''#include "world_adapter.hpp"
using C=mat003_world::Cell;
extern "C" unsigned get_material(const C* c) { return unsigned(c->material_value()); }
extern "C" void set_a(C* c, unsigned v) { c->set_state_a(v); }
extern "C" unsigned get_a(const C* c) { return c->state_a_value(); }
extern "C" unsigned get_epoch(const C* c) { return c->epoch_value(); }
extern "C" void clear_epoch(C* c) { c->set_epoch(0); }
extern "C" void copy_cell(C* a, const C* b) { *a=*b; }
extern "C" void swap_cell(C* a, C* b) { const auto t=*a; *a=*b; *b=t; }
''')
                if rep in ('u128','dual64'):
                    with wrapper.open('a') as f:
                        f.write('extern "C" void raw_cross_lane16(C* c, unsigned v) { mat003_continuation::raw_cross16(c->storage, static_cast<std::uint16_t>(v)); }\n')
                def compile_assembly():
                    run([compiler,*flags,*macros,'-DMAT003_TWIN_OBSERVERS=0',*includes,'-S',wrapper,'-o',assembly/'access.s'], 'asm/'+identifier,180)
                    run([compiler,*flags,*macros,'-DMAT003_TWIN_OBSERVERS=0',*includes,'-S',work/'native/src/world.cpp','-o',assembly/'world.s'], 'world-asm/'+identifier,180)
                if rep not in ('memcpy','u128','dual64','word'):
                    seal_generated(work)
                    compile_assembly()
                    continue # Reuse accepted control correctness; no repeat campaign.
                fixture = work/S1/'test_world.cpp'
                if rep in ('u128','dual64'):
                    text = fixture.read_text().replace('64 + 8 * MAT003_EXTRA_BYTES','128')
                    text = text.replace('"aligned", "split"', '"'+rep+'", "split"')
                    # Full high64 receives neutral patterns in the World owner,
                    # not only low16 through the inherited S1 observation API.
                    text = text.replace('mat003_world::set_extra(chunk->cells[a.index], value);',
                        'chunk->cells[a.index].storage.upper(value ? (0xa581234567890000ULL | value) : 0);')
                    text = text.replace('return mat003_world::get_extra(chunk->cells[a.index]);',
                        '''const auto high = chunk->cells[a.index].storage.upper();
        const auto low = mat003_world::get_extra(chunk->cells[a.index]);
        fixture::require(high == 0 || high == (0xa581234567890000ULL | low), "full high64 World payload lost");
        return low;''')
                    text = text.replace('mat003_world::set_extra(cell, tail);',
                        'cell.storage.upper(0xa581234567890000ULL | tail);')
                    text = text.replace('fixture::require(mat003_world::get_extra(cell) == expected, "forced clear changed AoS payload");',
                        'fixture::require(cell.storage.upper() == (0xa581234567890000ULL | expected), "forced clear changed full high64");')
                    fixture.write_text(text)
                seal_generated(work)
                compile_assembly()
                run([compiler,*flags,*macros,'-DMAT003_TWIN_OBSERVERS=1',*includes,fixture,*common,'-o',binary], 'compile/'+identifier,180)
                report['builds'].append(dict(id=identifier,binary=str(binary.relative_to(out)),sha256=digest(binary),observer=1))
                dump(out/'binary-seal.json',report['builds'])
                case = out/'cases'/identifier
                run([binary,'--output',case], 'execute/'+identifier,300)
                report['cases'].append(dict(id=identifier,result=json.loads((case/'result.json').read_text())))
                compress_streams(case)
            else:
                # Correctness twin counts actual clear entries and validates
                # all stamps before any event/simulation can restamp cells.
                adapter = work/S1/'world_adapter.hpp'
                adapter.write_text(adapter.read_text().replace('namespace mat003_world {',
                    'namespace mat003_world {\ninline std::uint64_t observed_clears=0, observed_clear_cells=0;'))
                world_source = work/'native/src/world.cpp'
                old = '        update_epoch_ = 1;\n    }\n    stats.tick = tick_index_;'
                new = '''#if MAT003_TWIN_OBSERVERS
        ++mat003_world::observed_clears;
        for (const auto& [coord, chunk] : chunks_) {
            (void)coord;
            for (const auto& cell : chunk->cells) {
                if (cell.epoch_value() != 0) throw std::runtime_error("clear observer found nonzero stamp");
                ++mat003_world::observed_clear_cells;
            }
        }
#endif
        update_epoch_ = 1;
    }
    stats.tick = tick_index_;'''
                if world_source.read_text().count(old) != 1:
                    raise ValueError('clear observer anchor drift')
                world_source.write_text(world_source.read_text().replace(old,new))
                prefix = (source/S1/'test_world.cpp').read_text().split('    static void fill_forced(World& world) {')[0]
                prefix = prefix.replace('static_assert(sizeof(Epoch) * 8 == MAT003_EPOCH_BITS);',
                                        'static_assert(sizeof(Epoch) * 8 == (MAT003_EPOCH_BITS == 24 ? 32 : MAT003_EPOCH_BITS));')
                (work/S1/'probe.hpp').write_text(prefix + PROBE)
                seal_generated(work)
                for observer in [0,1]:
                    twin = binary.with_name(identifier+'-o'+str(observer)+('.exe' if os.name == 'nt' else ''))
                    run([compiler,*flags,*macros,'-DMAT003_TWIN_OBSERVERS='+str(observer),*includes,source/HERE/'wclear.cpp',*common,'-o',twin], 'compile/'+twin.name,180)
                    report['builds'].append(dict(id=twin.name,binary=str(twin.relative_to(out)),sha256=digest(twin),observer=observer))
                    dump(out/'binary-seal.json',report['builds'])
                    for side in [512,1024,2048]:
                        for scene in ['sleep-excluded','active-window-excluded']:
                            for workers in [1,4]:
                                for mode in ['ordinary','event']:
                                    name=f'{identifier}-o{observer}-{side}-{scene}-w{workers}-{mode}'
                                    result = run([twin,str(side),str(workers),scene,mode,out/'cases'/name], 'execute/'+name,300)
                                    row=json.loads(result)
                                    row.update(id=name,scene=scene,observer=observer)
                                    report['cases'].append(row)
                                    compress_streams(out/'cases'/name)
                    # New feasible-width natural restoration validation. E8 and
                    # E16 both naturally clear at completed tick 65,536. Wider
                    # arms use explicitly prepared events at the same clock.
                    for mode in ['ordinary','event']:
                        name=f'{identifier}-o{observer}-128-sleep-excluded-w1-{mode}-natural16'
                        result=run([twin,'128','1','sleep-excluded',mode,out/'cases'/name,'65535'], 'execute/'+name,300)
                        row=json.loads(result)
                        row.update(id=name,scene='sleep-excluded',observer=observer)
                        report['cases'].append(row)
                        compress_streams(out/'cases'/name)
            # Snapshot all generated inputs/patches to bind modified fixtures too.
            # Seal was written before the fixture compile and remains immutable.
        # Independent full high-lane storage/byte-map model, also under UBSan.
        if args.track in ('s2p','c128','wclear'):
            storage=out/'bin'/('storage.exe' if os.name == 'nt' else 'storage')
            inc=['-I'+str(source/'native/include'),'-I'+str(source/S1),'-I'+str(source/HERE)]
            run([compiler,*flags,*inc,source/HERE/'storage.cpp','-o',storage], 'compile/storage',180)
            run([storage],'execute/storage',60)
            if report['qualified_toolchain']:
                sanitized=out/'bin'/'storage-ubsan'
                run([compiler,*flags,'-fsanitize=undefined','-fno-sanitize-recover=all',*inc,source/HERE/'storage.cpp','-o',sanitized],'compile/storage-ubsan',180)
                run([sanitized],'execute/storage-ubsan',60)
        report['status']='collected-not-admitted'
    except Exception as error:
        report['errors'].append(str(error))
    finally:
        # Lossless deterministic compression retains complete semantic streams.
        compress_streams(out)
        dump(out/'run.json',report)
        dump(out/'files.json',{p.relative_to(out).as_posix():digest(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='files.json'})
    if report['errors']:
        raise SystemExit('; '.join(report['errors']))


if __name__ == '__main__':
    main()
