"""Private owner comparison bundles. Packaging only; never edits refs or physics."""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import urllib.request
import zipfile

BUILDS = [
    ('A', 'Earlier desktop', '3b1747a493d6ffb01661dcf4111f1b32ae89dbac',
     'Earlier preserved desktop, before the integrated Stage-3 soliding discovery work. No C1 impact or recent testbench/player-profile changes.'),
    ('B', 'Soliding infrastructure checkpoint', 'cdf0a0874d4732c41273e10d921bcd5feaac3e3c',
     'Includes the Stage-3B infrastructure through #65 and intervening changes. Ordinary gameplay still does not enable the optional discovery observer. Not a working soliding-acceleration switch.'),
    ('C', 'Body coupling checkpoint', 'abad553cbd249f9bf2a574f20517d70ad7b6074f',
     'Includes REM-002 body/material coupling reconciliation. Before C1 impact and before the recent recorder, testbench and player-profile additions.'),
    ('D', 'Impact checkpoint', 'eac6caff06d9d7f87c2e0a9598b96eb51520d4a0',
     'Includes the existing C1 lower-edge impact experiment. No new anatomy or impact design is introduced. Before the recent recorder/testbench/player-profile additions.'),
    ('E', 'Current combined desktop', '23227bc4d660b516306f111b7a7e4398208afa5d',
     'Current combined desktop: existing impact, recorder, brushes/HUD, selectable representations, profile controls and comparison fixtures. No feature is removed or retuned.'),
]
EXPECTED_GODOT = '4.7.stable.official.5b4e0cb0f'
NATIVE = 'godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll'
PROVENANCE = 'godot/addons/cybersand_native/runtime-provenance.json'
SMOKE = '''extends SceneTree

func _init() -> void:
    call_deferred("run")

func run() -> void:
    if not ClassDB.class_exists(&"CyberNativeCellWorld"):
        push_error("COMPARISON: native extension unavailable")
        quit(1)
        return
    var desktop = load("res://main.tscn").instantiate()
    root.add_child(desktop)
    var deadline: int = Time.get_ticks_msec() + 15000
    var first_tick: int = -1
    var last_tick: int = -1
    var backend: String = ""
    var workers: int = 0
    var failed: bool = false
    while Time.get_ticks_msec() < deadline:
        await create_timer(0.05).timeout
        var snapshot = desktop.get("latest_snapshot")
        if snapshot == null:
            continue
        last_tick = int(snapshot.tick_index)
        if first_tick < 0:
            first_tick = last_tick
        backend = str(snapshot.backend_name)
        workers = int(snapshot.scheduler_thread_capacity_hint)
        failed = bool(snapshot.simulation_failed)
        if failed or last_tick - first_tick >= 30:
            break
    var bridge_ok: bool = desktop.rapier_bridge.is_initialized()
    var ok: bool = (not failed and last_tick - first_tick >= 30
        and workers > 0 and bridge_ok and "native" in backend.to_lower())
    print("COMPARISON_SMOKE ", JSON.stringify({
        "ok":ok, "platform":OS.get_name(), "godot":Engine.get_version_info().string,
        "backend":backend, "effective_workers":workers, "first_tick":first_tick,
        "last_tick":last_tick, "rapier_initialized":bridge_ok,
        "performance_verdict":"not measured; headless startup only"}))
    desktop.simulation_worker.stop_worker()
    desktop.rapier_bridge.shutdown()
    desktop.queue_free()
    await process_frame
    quit(0 if ok else 1)
'''


def run(args: list[str], cwd: Path | None = None, timeout: int = 300) -> str:
    result = subprocess.run(args, cwd=cwd, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=timeout)
    text = result.stdout.decode('utf-8', errors='replace')
    if result.returncode:
        raise RuntimeError(f'Command failed ({result.returncode}): {args}\n{text[-20000:]}')
    return text


def git_bytes(repo: Path, *args: str) -> bytes:
    return subprocess.check_output(['git', '-C', str(repo), *args], timeout=120)


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def download(url: str, destination: Path) -> None:
    for attempt in range(3):
        try:
            request = urllib.request.Request(url, headers={'User-Agent':'CyberSand-private-comparison-packager'})
            with urllib.request.urlopen(request, timeout=90) as response, destination.open('wb') as f:
                shutil.copyfileobj(response, f)
            return
        except Exception:
            destination.unlink(missing_ok=True)
            if attempt == 2:
                raise
            time.sleep(2 * (attempt + 1))


def engine(cache: Path) -> tuple[Path, dict]:
    release_file = cache / 'godot-release.json'
    download('https://api.github.com/repos/godotengine/godot-builds/releases/tags/4.7-stable', release_file)
    release = json.loads(release_file.read_text('utf-8'))
    asset = next(a for a in release['assets'] if a['name'] == 'Godot_v4.7-stable_win64.exe.zip')
    digest = asset.get('digest', '')
    if not re.fullmatch(r'sha256:[0-9a-f]{64}', digest):
        raise RuntimeError('Official Godot release lacks an SHA-256 digest; refusing unverified engine')
    archive = cache / asset['name']
    download(asset['browser_download_url'], archive)
    if sha(archive) != digest.split(':',1)[1]:
        raise RuntimeError('Godot archive checksum mismatch')
    folder = cache / 'engine'
    folder.mkdir()
    with zipfile.ZipFile(archive) as z:
        for info in z.infolist():
            target = (folder / info.filename).resolve()
            if not target.is_relative_to(folder.resolve()):
                raise RuntimeError('Unsafe engine archive path')
        z.extractall(folder)
    for name in ['LICENSE.txt', 'COPYRIGHT.txt']:
        download('https://raw.githubusercontent.com/godotengine/godot/4.7-stable/' + name, folder / name)
    consoles = list(folder.glob('*_console.exe'))
    exe = consoles[0] if consoles else next(folder.glob('*.exe'))
    version = run([str(exe), '--version']).strip()
    if version != EXPECTED_GODOT:
        raise RuntimeError('Unexpected Godot version: ' + version)
    return folder, {'version':version, 'archive_sha256':sha(archive),
                    'origin':asset['browser_download_url'], 'executable':exe.name}


def source_text(work: Path, path: str) -> str:
    file = work / path
    return file.read_text('utf-8') if file.exists() else ''


def package(repo: Path, staging: Path, output: Path, engine_dir: Path, engine_id: dict,
            spec: tuple[str,str,str,str], prior: str | None) -> dict:
    letter, title, revision, description = spec
    work = staging / ('source-' + letter)
    print('Preparing', letter, revision, flush=True)
    run(['git', '-c', 'core.autocrlf=false', 'worktree', 'add', '--detach', str(work), revision], repo)
    run(['git', 'lfs', 'pull', '--include=godot/addons/**/*.dll', '--exclude='], work, 600)
    provenance = json.loads((work / PROVENANCE).read_text('utf-8'))
    dll = work / NATIVE
    if sha(dll) != provenance['sha256'] or dll.stat().st_size != int(provenance['size']):
        raise RuntimeError(letter + ': retained Windows runtime does not match its provenance')
    inputs = provenance.get('source_inputs', {})
    if not inputs:
        raise RuntimeError(letter + ': missing native source-input receipt')
    mismatches = []
    for name, expected in inputs.items():
        raw = git_bytes(repo, 'show', revision + ':' + name)
        if hashlib.sha256(raw).hexdigest() != expected:
            mismatches.append(name)
    if mismatches:
        raise RuntimeError(letter + ': runtime/source mismatch: ' + ', '.join(mismatches))
    bundle = output / ('CyberSand-' + letter)
    bundle.mkdir(parents=True)
    project = bundle / 'project'
    # Keep source/assets and Windows runtimes. Never ship Git credentials or
    # other-platform LFS pointers. Runtime source and native DLL stay matched.
    for file in sorted((work / 'godot').rglob('*')):
        if not file.is_file():
            continue
        rel = file.relative_to(work / 'godot')
        if '.godot' in rel.parts or file.suffix.lower() in {'.so','.wasm','.dylib','.a','.lib','.pdb'}:
            continue
        if file.is_symlink():
            raise RuntimeError('Unexpected project symlink: ' + str(rel))
        data = file.read_bytes()
        if data.startswith(b'version https://git-lfs.github.com/spec/v1'):
            raise RuntimeError(letter + ': unresolved packaged LFS payload: ' + str(rel))
        target = project / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    config_path = project / 'project.godot'
    config = config_path.read_text('utf-8')
    config, count = re.subn(r'^config/name=.*$', 'config/name="CyberSand ' + letter + ' - ' + title + '"', config, count=1, flags=re.M)
    if count != 1:
        raise RuntimeError('Project title location missing')
    config = config.replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="CyberSandComparisons/20260926/' + letter + '"', 1)
    config_path.write_text(config, encoding='utf-8', newline='\n')
    shutil.copytree(engine_dir, bundle / 'engine')
    for name in ['LICENSE_STATUS.md', 'THIRD_PARTY_NOTICES.md', 'README.md']:
        if (work / name).exists():
            shutil.copy2(work / name, bundle / ('SOURCE-' + name))
    for name in ['third_party', 'licenses']:
        if (work / name).is_dir():
            for file in (work / name).rglob('*'):
                if file.is_file() and file.suffix.lower() in {'.json','.md','.txt'}:
                    dest = bundle / 'source-notices' / file.relative_to(work)
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(file, dest)
    main = source_text(work, 'godot/scripts/main.gd')
    worker = source_text(work, 'godot/scripts/simulation_worker.gd')
    native = source_text(work, 'godot/native_extension/cyber_native_cell_world.cpp')
    header = source_text(work, 'native/include/cybersand/world.hpp')
    facts = {
        'C1_impact_implemented':'character_disturb_granular' in native,
        'recorder_implemented':(work/'godot/scripts/gameplay_recorder.gd').exists(),
        'profile_controls_implemented':(work/'godot/scripts/player_environment_profiles.gd').exists(),
        'representation_selection_implemented':(work/'godot/scripts/player_representation.gd').exists(),
        'settled_discovery_infrastructure_present':'settled_discovery_enabled' in header,
        'discovery_default': 'off' if 'bool settled_discovery_enabled = false' in header else 'not present / inspect source',
        'published_interval_source':re.findall(r'const DEFAULT_RENDER_SNAPSHOT_INTERVAL_USEC[^\n]*',worker),
        'render_default_source':re.findall(r'var render_snapshot_hz[^\n]*',main),
        'defaults':'All simulation, rendering, UI and control defaults remain those of this revision.',
    }
    evidence = bundle / 'evidence'
    evidence.mkdir()
    if prior:
        (evidence/'changes-from-previous-build.txt').write_bytes(git_bytes(repo, 'diff', '--stat', prior, revision))
        (evidence/'complete-source-diff.patch').write_bytes(git_bytes(repo, 'diff', '--no-ext-diff', '--no-color', prior, revision))
    smoke_path = project / 'comparison_smoke.gd'
    smoke_path.write_text(SMOKE, encoding='utf-8')
    exe = bundle/'engine'/engine_id['executable']
    imported = run([str(exe), '--headless', '--path', str(project), '--editor', '--import'], timeout=180)
    (evidence/'windows-import.log').write_text(imported, encoding='utf-8')
    if 'SCRIPT ERROR:' in imported or 'Parse Error:' in imported:
        raise RuntimeError(letter + ': import script error; see evidence log')
    smoke = run([str(exe), '--headless', '--path', str(project), '--script', 'res://comparison_smoke.gd'], timeout=45)
    (evidence/'windows-startup-smoke.log').write_text(smoke, encoding='utf-8')
    print(smoke[-3000:], flush=True)
    reports = [json.loads(line.split('COMPARISON_SMOKE ',1)[1]) for line in smoke.splitlines() if 'COMPARISON_SMOKE ' in line]
    if len(reports) != 1 or not reports[0]['ok'] or 'SCRIPT ERROR:' in smoke:
        raise RuntimeError(letter + ': missing/passing startup receipt')
    shutil.move(str(smoke_path), str(evidence/'startup-smoke-script.gd.txt'))
    for folder in ['editor', 'shader_cache']:
        shutil.rmtree(project/'.godot'/folder, ignore_errors=True)
    gui_exes = [p for p in (bundle/'engine').glob('*.exe') if not p.name.endswith('_console.exe')]
    gui_exe = gui_exes[0] if gui_exes else exe
    launcher = ('@echo off\r\nsetlocal\r\ncd /d "%~dp0"\r\n'
                'set "CYBERSAND_SOURCE_REVISION=' + revision + '"\r\n'
                'echo CyberSand comparison ' + letter + ' - ' + title + '\r\n'
                'echo Source: ' + revision + '\r\n'
                'if not exist "logs" mkdir "logs"\r\n'
                '"%~dp0engine\\' + gui_exe.name + '" --path "%~dp0project" --log-file "%~dp0logs\\latest.log"\r\n'
                'if errorlevel 1 (echo Launch failed. See logs\\latest.log & pause)\r\nendlocal\r\n')
    (bundle/'RUN.cmd').write_text(launcher, encoding='utf-8', newline='')
    readme = (f'CYBERSAND COMPARISON {letter} - {title}\n\n{description}\n\n'
              'Extract this entire bundle and double-click RUN.cmd. No compilation, Git checkout, Web export or separate Godot installation is required.\n'
              'Do not overlay it onto your working checkout. Each letter has a separate user-data directory.\n\n'
              'These are cumulative preserved checkpoints, NOT isolated single-variable feature switches. Full diffs and active-feature facts are supplied.\n'
              'No variant is labelled good, preferred, accepted or a replacement for main. You decide what is useful.\n'
              'The actor rectangle is a generic placeholder; this pack adds no anatomy or new contact semantics. Existing impact code remains in D and E.\n'
              'Water defaults and laboratory policies are preserved, not a new Water model. Soliding discovery machinery is not completed runtime acceleration.\n'
              'Different revisions retain different render-publication defaults and UI. Those differences are intentional and disclosed in manifest.json.\n\n'
              'The included Windows headless import/startup receipt is NOT a GPU/performance/gameplay acceptance result.\n'
              f'Source revision: {revision}\nNative runtime SHA256: {sha(dll)}\n')
    (bundle/'READ-ME.txt').write_text(readme, encoding='utf-8')
    manifest = {'variant':letter,'title':title,'description':description,'source_revision':revision,
                'source_tree':git_bytes(repo,'rev-parse',revision+'^{tree}').decode().strip(),
                'engine':engine_id,'native_runtime':provenance,'native_source_inputs_verified':len(inputs),
                'features':facts,'windows_headless_smoke':reports[0],
                'packaging_changes':['Project window title and isolated user-data path only; no gameplay scripts modified.',
                    'Windows-only dependency selection; generated resource imports; launcher and evidence files.'],
                'owner_decisions':'No retention, modification or deletion decision taken.'}
    (bundle/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    with (bundle/'SHA256SUMS.txt').open('w',encoding='utf-8',newline='\n') as out:
        for file in sorted(bundle.rglob('*')):
            if file.is_file() and file.name != 'SHA256SUMS.txt':
                out.write(sha(file)+'  '+file.relative_to(bundle).as_posix()+'\n')
    print('COMPARISON_PACKAGE', json.dumps({'variant':letter,'source':revision,'native_sha256':sha(dll),'features':facts,'smoke':reports[0]}),flush=True)
    return manifest


def main() -> None:
    if sys.platform != 'win32':
        raise RuntimeError('This packaging task requires a real Windows runner for its smoke receipts')
    repo = Path.cwd().resolve()
    staging = Path(os.environ['RUNNER_TEMP'])/'cybersand-five-comparisons'
    staging.mkdir()
    output = repo/'comparison-output'
    output.mkdir()
    cache = staging/'cache'
    cache.mkdir()
    run(['git','lfs','install','--local'], repo)
    engine_dir, engine_id = engine(cache)
    results = []
    failures = []
    prior = None
    for spec in BUILDS:
        try:
            results.append(package(repo, staging, output, engine_dir, engine_id, spec, prior))
        except Exception as error:
            failures.append({'variant':spec[0],'error':str(error)})
            print('PACKAGE_FAILED', spec[0], str(error), flush=True)
            # Never publish a half-built folder as a playable bundle.
            partial = output/('CyberSand-'+spec[0])
            if partial.exists():
                partial.rename(output/('FAILED-'+spec[0]))
        prior = spec[2]
    index = {'packager_revision':os.environ.get('GITHUB_SHA'),'engine':engine_id,'results':results,'failures':failures}
    (output/'build-report.json').write_text(json.dumps(index,indent=2)+'\n',encoding='utf-8')
    summary = ['# Five owner comparison bundles', '', 'No changes to main or feature-retention decisions.', '']
    summary.extend(f"- {x['variant']}: {x['title']} / {x['source_revision']} / Windows startup passed" for x in results)
    summary.extend(f"- FAILED {x['variant']}: {x['error']}" for x in failures)
    Path(os.environ['GITHUB_STEP_SUMMARY']).write_text('\n'.join(summary)+'\n',encoding='utf-8')
    if failures:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
