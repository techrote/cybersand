"""Independent actual extracted Windows execution; no source-gate result reuse."""
from __future__ import annotations
import argparse
import json
import math
import ntpath
import os
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile
import common
import package as evaluator
import qualification

sys.path[:0] = [str(evaluator.ROOT / 'tools/ci'), str(evaluator.ROOT / 'tools')]
import strata3_cold_launcher as cold
import package_ramcache_strata as accepted

require, digest, write_json = common.require, common.digest, common.write_json
SCHEMA = 'pubpres-mainline-extracted-evaluator-v1'


def launcher_observation(location, package, manifest, *, persistent=False):
    """Read the unchanged query-only observer with this launcher's explicit tree."""
    process = json.loads((location / 'process.json').read_bytes())
    for name, key in (('process.log', 'log_sha256'), ('resources.json', 'resources_sha256'), ('lifetimes.json', 'lifetimes_sha256')):
        require(digest(location / name) == process.get(key), 'Changed original Win32 observation: ' + name)
    require(process.get('schema') == 'strata3-cold-process-v1' and process.get('platform') == 'win32'
            and process.get('exit_code') == 0 and process.get('timed_out') is False
            and process.get('failure') is None and process.get('cleanup_errors') == []
            and process.get('timeout_seconds') == 180 and 0 < process.get('wall_seconds', 0) <= 190
            and cold.normalized(process.get('cwd')) == cold.normalized(package)
            and process.get('command') == cold.command_line(process['executable'], process['cwd'], persistent=persistent),
            'Actual shipped CMD failed or changed its registered bounded command')
    lifetimes = json.loads((location / 'lifetimes.json').read_bytes())
    rows = lifetimes.get('rows', [])
    require(lifetimes.get('schema') == 'strata3-cold-process-lifetimes-v1' and 6 <= len(rows) <= 512,
            'Incomplete owned CMD/Python/engine population')
    seen = set()
    for row in rows:
        key = (row.get('pid'), row.get('start_id'))
        require(key not in seen and cold.integer(key[0], 1) and cold.integer(key[1], 1)
                and row.get('exited') is True and row.get('exit_code') == 0
                and row.get('creation_filetime_100ns') == key[1]
                and cold.integer(row.get('exit_filetime_100ns'), key[1] + 1)
                and cold.number(row.get('final_cpu_seconds'))
                and math.isclose(row.get('lifetime_seconds', -1),
                    (row['exit_filetime_100ns'] - key[1]) / 10_000_000, abs_tol=1e-9),
                'Missing or failed held-handle child lifetime')
        seen.add(key)
    roots = [row for row in rows if row['pid'] == process['pid']]
    require(len(roots) == 1 and cold.normalized(roots[0]['image_path']) == cold.normalized(process['executable']),
            'The observed root is not the actual owner CMD')
    root = roots[0]
    for row in rows:
        if row is root:
            continue
        parents = [p for p in rows if p['pid'] == row['parent_pid']
                   and p['start_id'] <= row['start_id'] < p['exit_filetime_100ns']]
        require(len(parents) == 1 and root['start_id'] <= row['start_id']
                < row['exit_filetime_100ns'] <= root['exit_filetime_100ns'], 'A child escaped the exact launched process tree')
    python_path = package / 'dependencies/python/python.exe'
    pythons = [row for row in rows if row['parent_pid'] == root['pid']
               and cold.normalized(row['image_path']) == cold.normalized(python_path)]
    require(len(pythons) == 1, 'Owner CMD did not execute exactly its bundled Python launcher')
    python = pythons[0]
    consoles = sorted((row for row in rows if cold.normalized(row['image_path']) == cold.normalized(package / cold.CONSOLE)),
                      key=lambda row: row['start_id'])
    require(len(consoles) == 2 and all(row['parent_pid'] == python['pid'] for row in consoles)
            and consoles[0]['exit_filetime_100ns'] <= consoles[1]['start_id'],
            'Bundled Python did not run importer then application through the two shipped consoles')
    engines = []
    for console in consoles:
        matches = [row for row in rows if row['parent_pid'] == console['pid']
                   and cold.normalized(row['image_path']) == cold.normalized(package / cold.GUI)]
        require(len(matches) == 1, 'A console did not launch its exact shipped GUI engine')
        engines += matches
    resources = json.loads((location / 'resources.json').read_bytes())
    cold.validate_resources(resources, process, rows)
    log = (location / 'process.log').read_text(encoding='utf-8')
    result = accepted.validate_launcher_log(log, manifest['source_commit'], persistent=persistent)
    if persistent:
        close = process.get('persistent_close', {})
        ready = cold.persistent_readiness(log)
        engine = engines[1]
        require(close.get('schema') == 'ramcache-strata-persistent-close-v1'
                and close.get('message') == 'WM_CLOSE' and close.get('message_id') == 0x0010
                and close.get('visible') is True and close.get('posted') is True
                and close.get('pid') == close.get('window_owner_pid') == engine['pid']
                and close.get('start_id') == engine['start_id']
                and cold.normalized(close.get('image_path')) == cold.normalized(engine['image_path'])
                and close.get('readiness') == ready['value'] == result['admission']
                and close.get('readiness_line_sha256') == ready['line_sha256'],
                'Persistent shortcut did not close its exact live admitted window normally')
        result['normal_window_close'] = close
    else:
        markers = [line.removeprefix('PUBPRES_PLAYABILITY_OWNER_READY ') for line in log.splitlines()
                   if line.startswith('PUBPRES_PLAYABILITY_OWNER_READY ')]
        require(len(markers) == 1, 'Missing unique ordinary PUBPRES startup observer')
        ready = json.loads(markers[0])
        require(ready.get('schema') == 'pubpres-recovery-owner-start-v1' and ready.get('ready') is True
                and ready.get('source_commit') == manifest['source_commit'] and ready.get('scene') == 'ordinary'
                and ready.get('engine_sha256') == manifest['engine']['gui']['sha256']
                and ready.get('native_sha256') == manifest['runtime']['cybersand_runtime']['sha256']
                and ready.get('rapier_sha256') == manifest['runtime']['rapier_runtime']['sha256']
                and ready.get('main_sha256') == manifest['files_sha256']['source/godot/scripts/main.gd']
                and ready.get('observer_sha256') == manifest['files_sha256']['source/tools/pubpres_recovery_windows/owner_start.gd']
                and ready.get('render_thread_inline') is True and ready.get('process_id') == engines[1]['pid']
                and ready.get('physical_acceptance') == 'HOLD', 'Ordinary startup source/runtime/renderer readback differs')
        recovery = ready.get('recovery', {})
        require(recovery.get('water_enabled') is True and recovery.get('water_requested') == '1'
                and recovery.get('actual_submission_enabled') is False and recovery.get('actual_submission_requested') == '0'
                and recovery.get('render_lookahead_requested') == '0'
                and recovery.get('task_completion_requested') == '0'
                and ready.get('flight_pacing_requested') == '1' and ready.get('flight_pacing_enabled') is True
                and ready.get('empty_effects_requested') == '1' and ready.get('empty_effects_enabled') is True
                and ready.get('coupling_clock_requested') == '1' and ready.get('coupling_clock_enabled') is True,
                'Actual startup did not retain all selected PUBPRES controls')
        result['pubpres_startup'] = ready
    result.update(engine_process_ids=[row['pid'] for row in engines], portable_python_pid=python['pid'],
                  importer_seconds=consoles[0]['lifetime_seconds'], application_seconds=consoles[1]['lifetime_seconds'])
    return result


def invoke_cmd(package, name, arguments, *, output, environment, timeout=300):
    comspec = os.environ.get('ComSpec', r'C:\Windows\System32\cmd.exe')
    # CMD /s needs this explicit double outer quote; argv list quoting is not an
    # equivalent Windows command parser, especially in paths with parentheses.
    command = '"' + comspec + '" /d /s /c ""' + str(package / name) + '" ' + arguments + '"'
    with output.open('wb') as log:
        result = subprocess.run(command, executable=comspec, cwd=package, env=environment,
                                stdout=log, stderr=subprocess.STDOUT, timeout=timeout, shell=False)
    require(result.returncode == 0, 'Actual shipped command failed: ' + name)
    return {'command': command, 'exit_code': result.returncode, 'log_sha256': digest(output)}


def run(args):
    require(sys.platform == 'win32', 'Extracted-package execution requires actual Windows')
    package, output = args.installation.resolve(), args.output.resolve()
    require(not output.exists() and not package.exists() and not output.is_relative_to(package),
            'Preserve previous runs and use independent fresh installation/evidence directories')
    # One actual filesystem path jointly exercises spaces, parentheses, Unicode
    # and nested extraction; no source/test rewrite occurs after extraction.
    require(' ' in str(package) and '(' in str(package) and ')' in str(package)
            and any(ord(character) > 127 for character in str(package)) and len(package.parts) >= 4,
            'Use a nested installation path containing spaces, parentheses and Unicode')
    output.mkdir(parents=True)
    manifest = evaluator.extract(args.archive.resolve(), package, args.sha256)
    result = {'schema': SCHEMA, 'status': 'running', 'source_commit': manifest['source_commit'],
              'source_tree': manifest['source_tree'], 'physical_owner_evaluated': False, 'merge_authorized': False,
              'archive': {'sha256': digest(args.archive), 'bytes': args.archive.stat().st_size},
              'installation': str(package), 'manifest_sha256': digest(package / evaluator.MANIFEST)}
    write_json(output / 'extracted-verification.json', result)
    try:
        # Static checks above execute Git/Python/compiler --version only. The
        # shipped owner CMD is deliberately the first actual Godot invocation.
        cold.execute_launcher(package, output / 'cold-launch', qualification.inherited.metrics)
        result['cold_cmd_was_first_engine_invocation'] = True
        result['cold_launch'] = launcher_observation(output / 'cold-launch', package, manifest)
        write_json(output / 'cold-launch-verification.json', result['cold_launch'])
        shortcuts = []
        for phase in ('first', 'reopen'):
            location = output / ('persistent-shortcut-' + phase)
            cold.execute_launcher(package, location, qualification.inherited.metrics, persistent=True)
            observation = launcher_observation(location, package, manifest, persistent=True)
            profiles = list((package / 'userdata/roaming').glob('Godot/app_userdata/*/persistent-areas/three-areas-v1/current.cypm'))
            require(len(profiles) == 1, 'Persistent launcher did not use its one package-local durable profile')
            shutil.copytree(profiles[0].parent, location / 'original-profile')
            observation['profile'] = accepted.read_persistent_profile(location / 'original-profile',
                manifest['runtime']['cybersand_runtime']['sha256'])
            require(observation['admission']['session'] == observation['profile']['session_id']
                    and observation['admission']['area'] == observation['profile']['active_area'],
                    'Readiness and actually saved profile identify different areas')
            shortcuts.append(observation)
        require(shortcuts[0]['profile']['session_id'] == shortcuts[1]['profile']['session_id']
                and set(shortcuts[0]['engine_process_ids']).isdisjoint(shortcuts[1]['engine_process_ids']),
                'Fresh persistent process did not reopen the same saved profile')
        write_json(output / 'persistent-shortcut-verification.json', shortcuts)
        env = common.selected_environment(evaluator.lab.dependency_environment(package))
        env.update(PYTHONDONTWRITEBYTECODE='1', PYTHONUTF8='1')
        source = package / 'source'
        python = package / 'dependencies/python/python.exe'
        runtime = package / 'provenance/windows'
        result['extracted_modes'] = {}
        for mode in ('ramcache', 'strata', 'lab'):
            command = [str(python), '-B', str(source / 'tools/pubpres_mainline/qualification.py'), 'run',
                       '--source', str(source), '--runtime', str(runtime), '--project', str(source / 'godot'),
                       '--engine', str(package / cold.CONSOLE), '--mode', mode, '--output', str(output / mode)]
            with (output / (mode + '-runner.log')).open('wb') as log:
                process = subprocess.run(command, cwd=source, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=5400)
            require(process.returncode == 0, 'Actual extracted ' + mode + ' execution failed')
            record = json.loads((output / mode / qualification.MANIFEST).read_bytes())
            require(record.get('source') == {'source_commit': manifest['source_commit'], 'source_tree': manifest['source_tree']}
                    and record.get('status') == 'passed' and record.get('mode') == mode and record.get('platform') == 'windows',
                    'Extracted source gate belongs to another application or did not pass')
            result['extracted_modes'][mode] = {'record_sha256': digest(output / mode / qualification.MANIFEST), 'command': command}
        # Reuse the accepted portable native-compiler receipt reader without its
        # frozen source runner. The original Lab marker and independently built
        # exact source snapshot must match the actual shipped C++ executable.
        lab_receipt = qualification.inherited.validate_marker(
            (output / 'lab/original/material-lab-author/process.log').read_text(encoding='utf-8'), 'MAT_WB_EVIDENCE ')['candidate_world_receipt']
        snapshot_cmd = [str(python), '-I', '-c',
            'import json,sys;sys.path.insert(0,sys.argv[1]);import world_candidate;print(json.dumps(world_candidate._source_snapshot()[0],sort_keys=True))',
            str(source / 'tools/material_catalogue')]
        snapshot = subprocess.run(snapshot_cmd, cwd=source, env=env, capture_output=True, check=True, timeout=60)
        require(not snapshot.stderr, 'Portable source snapshot emitted diagnostics')
        (output / 'portable-lab-source-snapshot.json').write_bytes(snapshot.stdout)
        accepted.validate_portable_compiler(lab_receipt, str(package), manifest['offline_authoring'],
                                           manifest['source_commit'], json.loads(snapshot.stdout))
        result['offline_authoring'] = {'status': 'passed', 'source_snapshot_sha256': digest(output / 'portable-lab-source-snapshot.json'),
                                      'source_snapshot_command': snapshot_cmd, 'compiler': manifest['offline_authoring']['tools']['compiler']}
        powershell = Path(os.environ.get('SystemRoot', r'C:\Windows')) / 'System32/WindowsPowerShell/v1.0/powershell.exe'
        command = [str(powershell), '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
                   str(source / 'tools/ci/check_windows_package_modules.ps1'), '-Package', str(package),
                   '-Evidence', str(output / 'runtime-modules.json'), '-Manifest', evaluator.MANIFEST, '-ProjectRelative', 'source/godot']
        with (output / 'runtime-modules-observer.log').open('wb') as log:
            subprocess.run(command, env=accepted.windows_powershell_environment(env), stdout=log,
                           stderr=subprocess.STDOUT, check=True, timeout=180)
        modules = json.loads((output / 'runtime-modules.json').read_bytes())
        require(modules.get('status') == 'passed' and modules.get('source_commit') == manifest['source_commit'],
                'Actual extracted engine did not load its shipped native/Rapier/VC DLLs')
        result['runtime_modules'] = {'receipt_sha256': digest(output / 'runtime-modules.json'), 'command': command}
        collector = output / 'owner-results.zip'
        result['collector'] = invoke_cmd(package, 'Collect Results.cmd', '--output "' + str(collector) + '"',
                                         output=output / 'collector-command.log', environment=env)
        with zipfile.ZipFile(collector) as archive:
            require(archive.testzip() is None, 'Diagnostic export CRC failed')
            collected = json.loads(archive.read('COLLECTION.json'))
            require(collected.get('source_commit') == manifest['source_commit'] and collected.get('uploads_performed') is False
                    and any(name.endswith('.jsonl') for name in collected.get('files', {})),
                    'Collector did not export actual owner gameplay diagnostics')
        result['collector']['archive_sha256'] = digest(collector)
        result['verifier'] = invoke_cmd(package, 'Verify Evaluator.cmd', '', output=output / 'verifier-command.log', environment=env)
        evaluator.verify(package, pristine=False, execute_tools=True)
        result.update(status='passed', payload_after_execution='all original payload and committed source bytes verified',
                      scope='Actual shipped launch, native/physical initialization, durable area reopening, extracted RAMCACHE/Strata/Lab execution, offline native authoring, DLL resolution and local diagnostic export. Hosted graphics; no physical NVIDIA acceptance.')
    except BaseException as error:
        result.update(status='failed', error=type(error).__name__ + ': ' + str(error))
        raise
    finally:
        write_json(output / 'extracted-verification.json', result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('archive', 'installation', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--sha256', required=True)
    result = run(parser.parse_args())
    print(json.dumps({'status': result['status'], 'source_commit': result['source_commit'], 'archive': result['archive']}))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
