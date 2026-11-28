"""Build and independently read the complete PUBPRES mainline Windows evaluator.

Full source compatibility history and portable authoring tools use the accepted
#794 implementations. New native bytes have an explicit, independently replayed
build overlay; the original committed manifest and every source blob remain
recoverable in the clean embedded Git database. No runtime publication is implied.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import zipfile
import common

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT / 'tools/ci'), str(ROOT / 'tools')]
import ramcache_strata_lab_package as lab
from package_wave_flow_candidate import omit_regenerated_imports, REGENERATED_RAPIER_IMPORTS
from package_explore001_candidate import verify_vc_runtime
import qualification

spec = importlib.util.spec_from_file_location('pubpres_original_windows_packager', ROOT / 'tools/pubpres_playability_windows/package_windows.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
require, digest, write_json = common.require, common.digest, common.write_json
MANIFEST = 'PUBPRES-MAINLINE-EVALUATOR.json'
SCHEMA = 'pubpres-mainline-windows-evaluator-v1'
MAX_EXPANDED = 4 * 1024**3
MAX_MEMBER = 1024**3
MAX_FILES = 100000
SCENES = ('ordinary', 'wave512', 'wave1024', 'wave2048', 'mixed2048', 'persistent')
COMMANDS = {'Open Workbench.cmd': 'ordinary', 'Open Wave 512.cmd': 'wave512', 'Open Wave 1024.cmd': 'wave1024',
            'Open Wave 2048.cmd': 'wave2048', 'Open Mixed 2048.cmd': 'mixed2048', 'Open Persistent Areas.cmd': 'persistent'}


def safe(name):
    require(isinstance(name, str) and name and len(name) <= 1024, 'Invalid archive path')
    path = PurePosixPath(name)
    require(not path.is_absolute() and path.as_posix() == name and
            all(part not in ('', '.', '..') for part in name.split('/')), 'Noncanonical archive path')
    for part in path.parts:
        require(not re.search(r'[<>:"|?*\\\x00-\x1f]', part) and not part.endswith(('.', ' '))
                and not re.fullmatch(r'(?i)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?', part),
                'Windows-incompatible archive path')
    return path


def file_map(root):
    result = {}
    for path in root.rglob('*'):
        require(not path.is_symlink(), 'Evaluator contains a symbolic link')
        if path.is_file():
            name = path.relative_to(root).as_posix()
            if name in (MANIFEST, MANIFEST + '.sha256'):
                continue
            safe(name)
            result[name] = digest(path)
    require(len(result) <= MAX_FILES and len(result) == len({k.casefold() for k in result}),
            'Excessive or case-ambiguous evaluator inventory')
    return dict(sorted(result.items()))


def command(scene=None, *, verify=False, collect=False):
    require(scene in SCENES or scene is None, 'Unknown owner scene')
    action = 'verify' if verify else 'collect' if collect else 'open'
    extra = '' if scene is None else ' --scene ' + scene
    return ('@echo off\r\nsetlocal\r\n'
            'set "PYTHONHOME="\r\nset "PYTHONPATH="\r\nset "PYTHONNOUSERSITE=1"\r\n'
            '"%~dp0dependencies\\python\\python.exe" "%~dp0source\\tools\\pubpres_mainline\\launcher.py" '
            + action + ' --package "%~dp0."' + extra + ' %*\r\n'
            'set "result=%errorlevel%"\r\n'
            'if not "%result%"=="0" if /i not "%~1"=="--hosted-smoke" pause\r\n'
            'exit /b %result%\r\n').encode('ascii')


def read_manifest(package):
    value = json.loads((package / MANIFEST).read_bytes())
    require(value.get('schema') == SCHEMA and value.get('mission') == common.MISSION
            and value.get('physical_owner_evaluated') is False and value.get('merge_authorized') is False,
            'Unknown evaluator or altered acceptance disposition')
    require((package / (MANIFEST + '.sha256')).read_text(encoding='ascii') ==
            digest(package / MANIFEST) + '  ' + MANIFEST + '\n', 'Manifest checksum differs')
    require(common.HEX40.fullmatch(value.get('source_commit', '')) and common.HEX40.fullmatch(value.get('source_tree', '')),
            'Missing exact application identity')
    require(value.get('accepted_main') == common.ACCEPTED_MAIN and value.get('owner_reference') == common.OWNER_REFERENCE
            and value.get('selectors') == common.SELECTORS and value.get('render_thread') == 'safe',
            'Changed accepted source role or selected architecture')
    return value


def verify_source(package, record, *, connected_history=True):
    """Verify original Git source plus exactly two declared build-overlay files."""
    source = package / 'source'
    declared = record['source_repository']
    expected = {'source_commit': record['source_commit'], 'source_tree': record['source_tree']}
    require(common.source_identity(source) == expected and declared.get('source_commit') == expected['source_commit']
            and declared.get('source_tree') == expected['source_tree'] and declared.get('schema') == 'ramcache-strata-lab-source-v1',
            'Embedded source HEAD/tree differs')
    gitdir = source / '.git'
    require(gitdir.is_dir() and not gitdir.is_symlink() and not (gitdir / 'hooks').exists(), 'Source Git database is not portable')
    require((gitdir / 'HEAD').read_bytes() == (record['source_commit'] + '\n').encode('ascii')
            and (gitdir / lab.PORTABLE_SOURCE_REF).read_bytes() == (record['source_commit'] + '\n').encode('ascii'),
            'Missing portable loose source anchor')
    for name in ('objects/info/alternates', 'objects/info/http-alternates', 'shallow', 'info/grafts'):
        require(not (gitdir / name).exists(), 'External or replaced source history')
    require(not lab.git(source, 'remote').strip() and not lab.git(source, 'for-each-ref', 'refs/replace').strip(),
            'Portable source has remotes or replaced history')
    allowed = {'core.repositoryformatversion', 'core.filemode', 'core.bare', 'core.logallrefupdates',
               'core.autocrlf', 'core.longpaths', 'core.ignorecase', 'core.symlinks'}
    for entry in lab.git(source, 'config', '--local', '--null', '--list').split(b'\0'):
        if entry:
            require(entry.split(b'\n', 1)[0].decode().lower() in allowed, 'Unreviewed portable Git configuration')
    history = declared.get('source_history', {})
    require(history.get('scope') == lab.HISTORY_SCOPE and history.get('source_commit') == record['source_commit']
            and common.HEX64.fullmatch(history.get('bundle_sha256', '')) and history.get('bundle_bytes', 0) > 0,
            'Missing complete compatibility-history receipt')
    original = lab.inventory(source)
    require(original == declared.get('original_files'), 'Original source inventory differs from Git')
    omitted = record.get('omitted_regenerated_imports', {})
    require(set(omitted) <= set(REGENERATED_RAPIER_IMPORTS)
            and all(omitted[k] == REGENERATED_RAPIER_IMPORTS[k] for k in omitted), 'Unreviewed source omission')
    runtime = package / 'provenance/windows'
    native = common.observed_runtime(source, runtime, source / 'godot', 'windows')
    require(native == record.get('runtime'), 'Evaluator runtime observation changed')
    overrides = {common.NATIVE['windows'], common.MANIFEST['windows']}
    materialized = record.get('materialized_dependencies', {})
    require(set(materialized) == {common.RAPIER['windows'], 'godot/tools/gentek_reciprocal.exe'},
            'Unreviewed materialized dependency inventory')
    for name, oid in original.items():
        path = source / name
        if name in omitted:
            require(hashlib.sha256(lab.git(source, 'cat-file', 'blob', oid)).hexdigest() == omitted[name]
                    and path.with_suffix('').is_file(), 'Regenerated import lost its exact original/source image')
            continue
        require(path.is_file() and not path.is_symlink(), 'Missing or linked committed source: ' + name)
        if name in overrides:
            continue  # Complete new build/input/binary/manifest custody was replayed above.
        if name in materialized:
            pointer = lab.LFS_POINTER.fullmatch(lab.git(source, 'cat-file', 'blob', oid))
            require(pointer is not None, 'Materialized dependency has no canonical LFS pointer')
            identity = {'sha256': pointer[1].decode(), 'size': int(pointer[2])}
            require(materialized[name] == identity and path.stat().st_size == identity['size']
                    and digest(path) == identity['sha256'], 'Changed materialized dependency')
        else:
            require(lab.blob_oid(path) == oid, 'Changed committed source: ' + name)
    if connected_history:
        require(not lab.git(source, 'fsck', '--connectivity-only', '--no-reflogs', '--unreachable').strip(),
                'Source history is incomplete or contains unrelated unreachable objects')
        for target in set(lab.git(source, 'for-each-ref', '--format=%(objectname)').decode().split()):
            lab.git(source, 'merge-base', '--is-ancestor', target, 'HEAD')
    return {'tracked_files': len(original), 'explicit_build_overlays': sorted(overrides),
            'source_commit': record['source_commit'], 'source_tree': record['source_tree']}


def verify(package: Path, *, pristine=True, execute_tools=False):
    package = package.resolve(strict=True)
    record = read_manifest(package)
    expected = record.get('files_sha256', {})
    require(expected and len(expected) == record.get('file_count') and len(expected) <= MAX_FILES,
            'Missing or excessive evaluator inventory')
    for name, wanted in expected.items():
        safe(name)
        path = package / name
        require(path.is_file() and not path.is_symlink() and digest(path) == wanted, 'Changed evaluator payload: ' + name)
    if pristine:
        require(file_map(package) == expected, 'Unexpected pristine evaluator files')
    require(sum((package / name).stat().st_size for name in expected) == record['expanded_bytes'] <= MAX_EXPANDED,
            'Evaluator expanded-size identity changed')
    engine = record['engine']
    require(engine['version'] == base.GODOT_VERSION and engine['archive_sha512'] == base.GODOT_SHA512,
            'Changed official engine selection')
    for role, name in (('gui', base.GUI), ('console', base.CONSOLE)):
        require(engine[role] == {'path': name, 'sha256': base.GODOT_EXECUTABLE_SHA256[name]}
                and digest(package / name) == engine[role]['sha256'], 'Changed official engine bytes')
        base.pe_x64(package / name)
    for name, scene in COMMANDS.items():
        require((package / name).read_bytes() == command(scene), 'Changed owner launcher')
    require((package / 'Verify Evaluator.cmd').read_bytes() == command(verify=True)
            and (package / 'Collect Results.cmd').read_bytes() == command(collect=True), 'Changed verifier or collector')
    lab.verify_dependencies(package / 'dependencies', record['offline_authoring'], execute=execute_tools)
    verify_source(package, record)
    return record


def build(args):
    require(os.name == 'nt', 'Build the complete evaluator on Windows')
    source = args.source.resolve()
    require(source == ROOT.resolve(), 'Use the packager from the exact source')
    identity = common.source_identity(source)
    for parent in (common.ACCEPTED_MAIN, common.OWNER_REFERENCE):
        common.git(source, 'merge-base', '--is-ancestor', parent, identity['source_commit'])
    native_record, _ = common.runtime_record(source, args.runtime, 'windows')
    output, archive = args.output.resolve(), args.archive.resolve()
    require(not output.exists() and not archive.exists() and not output.is_relative_to(source)
            and not archive.is_relative_to(output), 'Choose fresh external payload/archive destinations')
    modes = {}
    for folder in args.qualification:
        value = qualification.verify(source, args.runtime.resolve(), args.project.resolve(), folder.resolve(), 'windows')
        require(value['mode'] in ('ramcache', 'strata', 'shared') and value['mode'] not in modes,
                'Unexpected or duplicate source gate')
        modes[value['mode']] = {'record': value, 'record_sha256': digest(folder / qualification.MANIFEST)}
    require(set(modes) == {'ramcache', 'strata', 'shared'}, 'All three resulting-source Windows feature gates are required')
    output.mkdir(parents=True)
    repository = lab.stage_source(source, identity['source_commit'], output / 'source')
    runtime = output / 'provenance/windows'
    runtime.parent.mkdir()
    shutil.copytree(args.runtime, runtime)
    common.install_runtime(output / 'source', runtime, output / 'source/godot', 'windows')
    materialized = {}
    for name in (common.RAPIER['windows'], 'godot/tools/gentek_reciprocal.exe'):
        pointer = lab.LFS_POINTER.fullmatch(common.git(source, 'show', 'HEAD:' + name))
        require(pointer is not None, 'Dependency is not a canonical LFS pointer')
        expected = {'sha256': pointer[1].decode(), 'size': int(pointer[2])}
        require(digest(source / name) == expected['sha256'] and (source / name).stat().st_size == expected['size'],
                'Source dependency is not materialized from its exact pointer')
        shutil.copyfile(source / name, output / 'source' / name)
        materialized[name] = expected
    omitted = omit_regenerated_imports(output / 'source')
    tools = lab.stage_dependencies(output / 'dependencies', python_root=args.python_root, git_root=args.git_root,
                                  compiler_root=args.compiler_root)
    engine = base.stage_dependencies(output, args.godot_zip, args.vc_runtime, args.notices)
    # Keep the VC runtime beside the native DLL as well as the actual engine.
    shutil.copyfile(output / 'vcruntime140.dll', output / 'source/godot/addons/cybersand_native/bin/vcruntime140.dll')
    for name, scene in COMMANDS.items():
        (output / name).write_bytes(command(scene))
    (output / 'Verify Evaluator.cmd').write_bytes(command(verify=True))
    (output / 'Collect Results.cmd').write_bytes(command(collect=True))
    (output / 'READ-ME.md').write_text(owner_guide(identity), encoding='utf-8')
    gates = output / 'qualification'
    gates.mkdir()
    for mode, entry in modes.items():
        write_json(gates / (mode + '.json'), entry)
    record = {'schema': SCHEMA, 'mission': common.MISSION, **identity,
              'accepted_main': common.ACCEPTED_MAIN, 'owner_reference': common.OWNER_REFERENCE,
              'runtime': common.observed_runtime(output / 'source', runtime, output / 'source/godot', 'windows'),
              'engine': engine, 'source_repository': repository, 'materialized_dependencies': materialized,
              'omitted_regenerated_imports': omitted, 'offline_authoring': tools,
              'selectors': common.SELECTORS, 'render_thread': 'safe', 'source_gate_modes': sorted(modes),
              'source_gate_records_sha256': {mode: digest(gates / (mode + '.json')) for mode in modes},
              'extracted_package_qualification': 'pending independent execution',
              'physical_owner_evaluated': False, 'merge_authorized': False,
              'native_publication': 'Build overlay only; guarded production publication is a separate required gate.'}
    record['files_sha256'] = file_map(output)
    record['file_count'] = len(record['files_sha256'])
    record['expanded_bytes'] = sum((output / name).stat().st_size for name in record['files_sha256'])
    require(record['expanded_bytes'] <= MAX_EXPANDED, 'Complete evaluator exceeds the registered 4GiB expanded bound')
    write_json(output / MANIFEST, record)
    (output / (MANIFEST + '.sha256')).write_text(digest(output / MANIFEST) + '  ' + MANIFEST + '\n', encoding='ascii')
    verify(output, execute_tools=True)
    archive.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive, 'x', zipfile.ZIP_DEFLATED, compresslevel=6, allowZip64=True) as bundle:
        for name in sorted([*record['files_sha256'], MANIFEST, MANIFEST + '.sha256']):
            bundle.write(output / name, name)
    with zipfile.ZipFile(archive) as bundle:
        require(bundle.testzip() is None, 'Final archive CRC failed')
    receipt = {'schema': SCHEMA, **identity, 'archive_sha256': digest(archive), 'archive_bytes': archive.stat().st_size,
               'expanded_bytes': record['expanded_bytes'], 'manifest_sha256': digest(output / MANIFEST),
               'physical_owner_evaluated': False, 'extracted_package_qualification': 'pending independent execution'}
    write_json(Path(str(archive) + '.json'), receipt)
    Path(str(archive) + '.sha256').write_text(receipt['archive_sha256'] + '  ' + archive.name + '\n', encoding='ascii')
    print(json.dumps(receipt), flush=True)
    return receipt


def owner_guide(identity):
    return f'''# CyberSand PUBPRES Workbench — Draft/HOLD

Application: `{identity['source_commit']}`  
Tree: `{identity['source_tree']}`

Extract the downloaded Actions archive, then extract the Windows ZIP inside.
Keep all extracted files together. Open **Open Workbench.cmd** or **Open Wave
512.cmd**. Python, Git, C++, Godot, native simulation, Rapier and authoring tools
are included. No compilation or separate installation is needed to play.

Start with the Needle, enable Thruster fire and Play. Compare Follow and free
camera, initial and warmed spawn, repeated respawn, running material edits,
mouse picking and Water/Fire contact. Try **Open Mixed 2048.cmd** for a larger
ordinary scene. Save start, close normally, reopen the same scene launcher and
Load start. The stable local profile is shared by these launchers.

**Open Persistent Areas.cmd** exercises the accepted RAM cache host. Layered
Strata is supported in ordinary Workbench; the persistent host deliberately
refuses it because its save format contains one Play World. Return through the
launcher to ordinary Workbench for Strata authoring and optical controls.

**Collect Results.cmd** exports bounded gameplay segments and launch logs to a
local ZIP. Close the game first for the final writer flush. This command never
uploads anything. Authored starts and private Art conversations are not included.
**Verify Evaluator.cmd** checks the complete shipped payload.

Stock Safe, Full two-slot material publication, Water composition and all-worker
native completion remain selected. Hosted software rendering does not establish
physical TITAN RTX performance. This newly reconciled application still needs
owner evaluation and explicit authorization before mainline promotion.
'''


def extract(archive, destination, expected_sha256):
    require(common.HEX64.fullmatch(expected_sha256 or '') and digest(archive) == expected_sha256,
            'Use the independently acquired exact archive SHA-256')
    require(not destination.exists(), 'Extract only into a fresh directory')
    with zipfile.ZipFile(archive) as bundle:
        entries = bundle.infolist()
        require(0 < len(entries) <= MAX_FILES, 'Invalid archive entry count')
        names, total = set(), 0
        for item in entries:
            name = safe(item.filename).as_posix()
            require(not item.is_dir() and name.casefold() not in names and not (item.flag_bits & 1),
                    'Duplicate, encrypted or directory archive entry')
            mode = (item.external_attr >> 16) & 0o170000
            require(mode in (0, stat.S_IFREG) and item.file_size <= MAX_MEMBER, 'Linked or excessive archive member')
            names.add(name.casefold())
            total += item.file_size
        require(total <= MAX_EXPANDED and bundle.testzip() is None, 'Archive bounds or CRC failed')
        destination.mkdir(parents=True)
        for item in entries:
            target = destination / safe(item.filename)
            target.parent.mkdir(parents=True, exist_ok=True)
            with bundle.open(item) as src, target.open('xb') as dst:
                shutil.copyfileobj(src, dst, 1024 * 1024)
    return verify(destination, execute_tools=os.name == 'nt')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    build_parser = sub.add_parser('build')
    for name in ('source', 'runtime', 'godot-zip', 'vc-runtime', 'notices', 'output', 'archive'):
        build_parser.add_argument('--' + name, type=Path, required=True)
    build_parser.add_argument('--project', type=Path)
    build_parser.add_argument('--qualification', type=Path, action='append', required=True)
    build_parser.add_argument('--python-root', type=Path, default=Path(sys.base_prefix))
    build_parser.add_argument('--git-root', type=Path, default=Path(r'C:\Program Files\Git'))
    build_parser.add_argument('--compiler-root', type=Path, default=Path(r'C:\mingw64'))
    check = sub.add_parser('verify')
    check.add_argument('--package', type=Path, required=True)
    check.add_argument('--after-launch', action='store_true')
    unpack = sub.add_parser('extract')
    unpack.add_argument('--archive', type=Path, required=True)
    unpack.add_argument('--destination', type=Path, required=True)
    unpack.add_argument('--sha256', required=True)
    args = parser.parse_args()
    if args.command == 'build':
        if args.project is None:
            args.project = args.source / 'godot'
        build(args)
    elif args.command == 'extract':
        result = extract(args.archive, args.destination, args.sha256)
        print(json.dumps({'status': 'passed', 'source': result['source_commit']}))
    else:
        result = verify(args.package, pristine=not args.after_launch, execute_tools=os.name == 'nt')
        print(json.dumps({'status': 'passed', 'source': result['source_commit'], 'files': result['file_count']}))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
