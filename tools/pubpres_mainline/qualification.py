"""Run the complete accepted integration subset with the new PUBPRES build.

The historical RAMCACHE/Strata runner and semantic readers are unchanged. This
adapter replaces only their old retained-binary admission with the complete new
build receipt, and records that change as an explicit source overlay. It never
reuses a prior application result or changes a case/assertion/watchdog.
"""
from __future__ import annotations
import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from types import SimpleNamespace
import common

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT / 'tools/ci'), str(ROOT / 'tools')]
import ramcache_strata_qualification as inherited

ORIGINAL_SCHEMA = 'ramcache-strata-integration-v1'
SCHEMA = 'pubpres-mainline-cross-feature-v1'
MANIFEST = 'pubpres-mainline-qualification.json'
require, digest, write_json = common.require, common.digest, common.write_json


def generator_profiles(source: Path, project: Path) -> dict:
    """Admit canonical recipes and any legacy byte-identical in-project copies.

    Full-source packages discover examples/worldgen directly. Older source
    runners stage the same recipes under the project; that optional discovery
    root must never introduce a second, independently mutable catalogue.
    """
    names = common.git(source, 'ls-tree', '-r', '--name-only', 'HEAD', '--',
                       'examples/worldgen').decode().splitlines()
    names = sorted(name for name in names if Path(name).parent.as_posix() == 'examples/worldgen'
                   and Path(name).suffix == '.json')
    require({'examples/worldgen/gen007-deepworks.json', 'examples/worldgen/gen007-qualification.json'}
            <= set(names), 'Missing canonical generation recipes')
    canonical = {}
    for name in names:
        expected = common.git(source, 'show', 'HEAD:' + name)
        path = source / name
        require(path.is_file() and not path.is_symlink() and path.read_bytes() == expected,
                'Generation recipe differs from committed source: ' + name)
        canonical[name] = hashlib.sha256(expected).hexdigest()
    copies = {}
    for label, root in (('source', source / 'godot'), ('project', project)):
        folder = root / 'authoring/worldgen'
        if not folder.exists():
            copies[label] = {}
            continue
        require(folder.is_dir() and not folder.is_symlink(), 'Linked generation discovery root')
        actual = list(folder.rglob('*'))
        expected_names = {Path(name).name for name in names}
        require(all(path.is_file() and not path.is_symlink() and path.parent == folder for path in actual)
                and {path.name for path in actual} == expected_names,
                'Unregistered generation profile discovery population')
        copies[label] = {path.name: digest(path) for path in sorted(actual)}
        require(copies[label] == {Path(name).name: value for name, value in canonical.items()},
                'Staged generation recipes differ from canonical source')
    return {'canonical_sha256': canonical, 'optional_copies_sha256': copies}


@contextlib.contextmanager
def bind(source: Path, runtime: Path, project: Path, platform: str):
    """Bind an invocation; all inherited semantic/receipt validators are retained."""
    require(source.resolve() == ROOT.resolve(), 'Run the helper belonging to the exact source checkout')
    original_identity = inherited.custody.source_identity
    original_environment = inherited.custody.case_environment
    saved = []

    def replace(module, name, value):
        saved.append((module, name, getattr(module, name)))
        setattr(module, name, value)

    native = common.observed_runtime(source, runtime, project, platform)
    overlay_name = common.MANIFEST[platform]
    overlay_hash = native['runtime_provenance']['sha256']
    committed_hash = hashlib.sha256(common.git(source, 'show', 'HEAD:' + overlay_name)).hexdigest()
    overlay = {
        'schema': common.SCHEMA, 'path': overlay_name, 'sha256': overlay_hash,
        'original_committed_sha256': committed_hash,
        'original_build_receipt_sha256': digest(runtime / 'PUBPRES-RUNTIME.json'),
        'disposition': 'source-exact qualification overlay; not a guarded runtime publication',
        'application_binding': common.derived_manifest(source, runtime, platform)['native_input_binding'],
    }

    def identity(allow_delta=False):
        value = original_identity(True)
        # Running in the original checkout or its complete extracted Git clone
        # may have exactly the declared host manifest overlay. No other source
        # delta is excused; the complete new native closure is checked separately.
        unexpected = set(value['local_delta']) - {overlay_name}
        require(not unexpected, 'Uncommitted execution inputs: ' + ', '.join(sorted(unexpected)))
        actual = source / overlay_name
        require(digest(actual) in {committed_hash, overlay_hash}, 'Unregistered native manifest source overlay')
        value['source_inputs_sha256'][overlay_name] = overlay_hash
        helper_names = common.git(source, 'ls-tree', '-r', '--name-only', 'HEAD', '--',
                                  'tools/pubpres_mainline').decode().splitlines()
        require('tools/pubpres_mainline/qualification.py' in helper_names,
                'The executing qualification adapter must be committed source')
        for name in helper_names:
            if Path(name).suffix != '.py':
                continue
            expected = hashlib.sha256(common.git(source, 'show', 'HEAD:' + name).replace(b'\r\n', b'\n')).hexdigest()
            require(hashlib.sha256((source / name).read_bytes().replace(b'\r\n', b'\n')).hexdigest() == expected,
                    'Qualification adapter differs from committed source: ' + name)
            value['source_inputs_sha256'][name] = expected
        profiles = generator_profiles(source, project)
        value['source_inputs_sha256'].update(profiles['canonical_sha256'])
        value['generation_profiles'] = profiles
        value['source_inputs_sha256'] = dict(sorted(value['source_inputs_sha256'].items()))
        value['local_delta'] = []
        value['explicit_native_build_overlay'] = overlay
        return value

    def runtime_identity():
        require(common.observed_runtime(source, runtime, project, platform) == native,
                'Native build or loaded dependency changed during qualification')
        return native

    def retained(platform_label):
        require(platform_label == ('win32' if platform == 'windows' else 'linux'),
                'A cross-platform native result cannot substitute for this execution')
        return runtime_identity()

    def admission():
        for ancestor in (common.ACCEPTED_MAIN, common.OWNER_REFERENCE):
            common.git(source, 'merge-base', '--is-ancestor', ancestor, 'HEAD')
        production = common.git(source, 'ls-tree', '-r', '--name-only', 'HEAD', '--', 'native', 'godot').decode().splitlines()
        require(not any(re.search(r'object[_-]?shard', name, re.I) for name in production),
                'ObjectShard production source is excluded from this PUBPRES campaign')
        retained_request = inherited.validate_request(inherited.read(source / inherited.REQUEST))
        current = inherited.identity()
        return {'schema': 'pubpres-mainline-source-admission-v1', 'source_identity': current,
                'excluded_objectshard_production': True,
                'retained_feature_request_sha256': digest(source / inherited.REQUEST),
                'native_reuse': {'disposition': 'original-build-with-complete-input-equivalence', 'overlay': overlay,
                                 'native_input_count': len(native['native_source_inputs'])},
                'performance_policy': {'classic_default': True, 'optional_profile_original_target': 0.9,
                    'optional_profile_target_disposition': retained_request['optional_optics_90_percent_gate'],
                    'new_performance_benchmark_claimed': False}}

    def environment(path):
        return common.selected_environment(original_environment(path))

    try:
        replace(inherited.custody, 'source_identity', identity)
        replace(inherited.custody, 'verify_runtime_identity', runtime_identity)
        replace(inherited.custody, 'case_environment', environment)
        replace(inherited.strata, 'retained_runtime_manifest', retained)
        # Optics calls the same imported Strata2 module; assert the shared binding.
        require(inherited.optics.previous is inherited.strata, 'Optical native admission module changed')
        replace(inherited, 'admission', admission)
        replace(inherited, 'native_reuse', lambda: admission()['native_reuse'])
        yield overlay
    finally:
        for module, name, old in reversed(saved):
            setattr(module, name, old)


def verify(source, runtime, project, output, platform):
    record = json.loads((output / MANIFEST).read_bytes())
    require(record.get('schema') == SCHEMA and record.get('mission') == common.MISSION
            and record.get('status') == 'passed' and record.get('physical_owner_evaluated') is False,
            'Missing or unsuccessful mainline cross-feature record')
    require(record.get('source') == common.source_identity(source)
            and record.get('platform') == platform and record.get('selectors') == common.SELECTORS,
            'Mainline record belongs to another source, platform or architecture')
    require(record.get('original_report_sha256') == digest(output / 'original/integration.json'),
            'Inherited original report changed')
    with bind(source, runtime, project, platform) as overlay:
        report = inherited.verify(output / 'original')
        require(record.get('explicit_native_build_overlay') == overlay
                and record.get('mode') == report['mode']
                and record.get('cases') == sorted(inherited.expected_labels(report['mode']))
                and record.get('all_original_semantic_readers_replayed') is True,
                'Mainline scope differs from actually verified case population')
    return record


def run(args):
    source, runtime, project, output = args.source.resolve(), args.runtime.resolve(), args.project.resolve(), args.output.resolve()
    require(not output.exists(), 'Preserve prior qualification evidence; use a fresh output')
    require(not output.is_relative_to(source) and not output.is_relative_to(project),
            'Keep original evidence outside the source and project')
    common.install_runtime(source, runtime, project, common.platform_name())
    output.mkdir(parents=True)
    record = {'schema': SCHEMA, 'mission': common.MISSION, 'source': common.source_identity(source),
              'mode': args.mode, 'platform': common.platform_name(), 'status': 'running',
              'selectors': common.SELECTORS, 'physical_owner_evaluated': False,
              'scope': 'Complete accepted integration subset on current source and rebuilt native runtime; broad release and physical gates remain separate.'}
    code = 1
    try:
        with bind(source, runtime, project, common.platform_name()) as overlay:
            record['explicit_native_build_overlay'] = overlay
            code = inherited.run(SimpleNamespace(output=output / 'original', mode=args.mode,
                project=project, godot=args.engine.resolve()))
            if code == 0:
                inherited.verify(output / 'original')
                record.update(status='passed', cases=sorted(inherited.expected_labels(args.mode)),
                    all_original_semantic_readers_replayed=True)
            else:
                record['status'] = 'failed'
    except Exception as error:
        record.update(status='failed', error=str(error))
        code = 1
    finally:
        if (output / 'original/integration.json').is_file():
            record['original_report_sha256'] = digest(output / 'original/integration.json')
        write_json(output / MANIFEST, record)
    if code == 0:
        verify(source, runtime, project, output, common.platform_name())
    print(json.dumps({key: record.get(key) for key in ('status', 'source', 'mode', 'platform')}), flush=True)
    return code


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('run', 'verify'))
    parser.add_argument('--source', type=Path, default=ROOT)
    parser.add_argument('--runtime', type=Path, required=True)
    parser.add_argument('--project', type=Path)
    parser.add_argument('--engine', type=Path)
    parser.add_argument('--mode', choices=inherited.RUN_MODES)
    parser.add_argument('--platform', choices=('linux', 'windows'))
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.project is None:
        args.project = args.source / 'godot'
    if args.command == 'run':
        require(args.engine is not None and args.mode is not None, 'Supply engine and registered mode')
        return run(args)
    result = verify(args.source.resolve(), args.runtime.resolve(), args.project.resolve(), args.output.resolve(),
                    args.platform or common.platform_name())
    print(json.dumps({'status': 'passed', 'source': result['source'], 'mode': result['mode']}))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
