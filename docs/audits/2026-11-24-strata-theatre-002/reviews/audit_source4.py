#!/usr/bin/env python3
"""Read-only, source-exact independent custody audit for Strata source4 candidate; graphical qualification is separate."""
from pathlib import Path
import datetime
import hashlib
import json
import re
import subprocess

ROOT = Path('/tmp/strata2-recovered')
OUT = Path('/tmp/strata2-a-final-review')
SOURCE = '934cc0c0eef70dad528155e9a92eebe25e2757eb'
TREE = '0c30ea3eaea61c5091c23b984837f29d7b7c828e'
PREDECESSOR = '80623d039aa49bc0c1d84a9206d89812ffa99ea6'
ACCEPTED = '00cdb02f103265b6dc5224c68283e9a0c8cb449f'
SOURCE2 = '1a124c0a47cd9f94e07b541e5c451602b8e8e0fd'

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

def digest(data):
    return hashlib.sha256(data).hexdigest()

def blob(ref, name):
    return git('show', ref + ':' + name)

def record_file(path):
    data = path.read_bytes()
    return {'path': str(path), 'bytes': len(data), 'sha256': digest(data)}

assert git('rev-parse', SOURCE + '^{tree}').decode().strip() == TREE
ancestry = json.loads((OUT/'ancestry-api-934cc0c.json').read_text())
for expected, comparison in zip((PREDECESSOR, ACCEPTED), ancestry['comparisons']):
    assert comparison['merge_base'] == expected and comparison['head'] == SOURCE
    assert comparison['status'] == 'ahead' and comparison['behind_by'] == 0
subprocess.run(['git', 'merge-base', '--is-ancestor', SOURCE2, SOURCE], cwd=ROOT, check=True)

changed = []
for line in git('diff', '--name-status', PREDECESSOR, SOURCE).decode().splitlines():
    status, path = line.split('\t')
    changed.append({'status': status, 'path': path})
protected_prefixes = ('src/', 'include/', 'native/', 'godot/native_extension/', 'godot/addons/',
                      'godot/shaders/', 'third_party/', 'docs/history/',
                      'docs/audits/2026-11-24-strata-theatre-workbench/')
protected_names = {'godot/scripts/main.gd', 'godot/scripts/simulation_worker.gd',
                   'godot/scripts/feature_launcher.gd', 'godot/scripts/depth/depth_compositor.gd',
                   'godot/scripts/depth/depth_layer_surface.gd', 'godot/scripts/depth/depth_lab.gd',
                   'godot/scripts/depth/semantic_depth_demo.gd', 'godot/scripts/depth/depth_layer_runtime.gd'}
unexpected = [row for row in changed if row['path'].startswith(protected_prefixes) or row['path'] in protected_names]
assert not unexpected, unexpected

manifests = [
 'godot/addons/cybersand_native/runtime-provenance.linux.json',
 'godot/addons/cybersand_native/runtime-provenance.json',
 'godot/addons/godot-rapier2d/runtime-provenance.linux.json',
 'godot/addons/godot-rapier2d/runtime-provenance.windows.json',
]
runtime = []
inputs = {}
input_checks = 0
for name in manifests:
    raw = blob(SOURCE, name)
    assert raw == blob(PREDECESSOR, name)
    manifest = json.loads(raw)
    for path, expected in manifest['source_inputs'].items():
        frozen = blob(SOURCE, path)
        current = (ROOT / path).read_bytes().replace(b'\r\n', b'\n')
        assert digest(frozen) == expected == digest(current), path
        assert frozen == blob(PREDECESSOR, path), path
        inputs[path] = expected
        input_checks += 1
    artifact = manifest['artifact']
    pointer = blob(SOURCE, artifact)
    assert pointer == blob(PREDECESSOR, artifact)
    match = re.fullmatch(rb'version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n', pointer)
    assert match, artifact
    assert match[1].decode() == manifest['sha256'] and int(match[2]) == manifest['size']
    current = ROOT / artifact
    materialized = current.is_file() and not current.read_bytes().startswith(b'version https://git-lfs.github.com/spec/v1\n')
    if materialized:
        actual = record_file(current)
        assert actual['sha256'] == manifest['sha256'] and actual['bytes'] == manifest['size']
    else:
        actual = None
    runtime.append({'manifest': name, 'manifest_sha256': digest(raw), 'manifest_git_blob': git('rev-parse', SOURCE+':'+name).decode().strip(),
                    'unchanged_since_predecessor': True, 'build_commit': manifest['build_commit'],
                    'source_inputs_checked': len(manifest['source_inputs']), 'artifact': artifact,
                    'sha256': manifest['sha256'], 'bytes': manifest['size'], 'lfs_pointer_matches': True,
                    'actual_local_bytes_verified': materialized, 'actual_local_file': actual,
                    'scope': 'Actual local payload bytes plus manifest/pointer' if materialized else 'Committed manifest and LFS pointer only; actual Windows package bytes pending'})
assert input_checks == 218 and len(inputs) == 109
engine = record_file(Path('/workspace/scratch/051e78157ffb/runtime/godot-4.7/Godot_v4.7-stable_linux.x86_64'))
assert engine['sha256'] == 'f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75'
engine['version'] = subprocess.check_output([engine['path'], '--version'], text=True).strip()
assert engine['version'] == '4.7.stable.official.5b4e0cb0f'

reviewed_paths = [
 'godot/scripts/depth/workbench_strata_authoring_panel.gd', 'godot/tests/test_strata2_authoring_ui.gd',
 'godot/scripts/shared_workbench.gd', 'godot/scripts/workbench_paint_editor_controller.gd',
 'godot/scripts/depth/workbench_strata_controller.gd', 'godot/scripts/depth/workbench_layer_document.gd',
 'godot/scripts/depth/workbench_layer_owner.gd', 'godot/scripts/depth/workbench_strata_presentation.gd',
 'godot/scripts/depth/strata_atmosphere.gd', 'godot/scripts/depth/strata_construction_session.gd',
 'godot/scripts/depth/workbench_strata_authoring.gd', 'godot/tests/test_strata_construction_session.gd',
 'godot/tests/test_strata2_workflow.gd', 'godot/tools/qualify_workbench_strata.gd',
 'godot/tools/qualify_workbench_strata2.gd', 'tools/ci/qualify_strata2_workbench.py',
 'tools/ci/test_strata2_qualification.py', 'tools/package_strata2_workbench.py']
reviewed = {}
for path in reviewed_paths:
    raw = blob(SOURCE, path)
    assert raw == (ROOT / path).read_bytes().replace(b'\r\n', b'\n'), path
    reviewed[path] = {'git_blob': git('rev-parse', SOURCE+':'+path).decode().strip(), 'sha256': digest(raw)}

receipt = {'schema': 'strata2-independent-source-runtime-custody-v2',
 'status': 'source-and-local-linux-custody-passed-windows-payload-pending',
 'recorded_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'source_commit': SOURCE, 'source_tree': TREE, 'predecessor_archive': PREDECESSOR, 'accepted_main': ACCEPTED,
 'source2': SOURCE2, 'ancestors_verified': [ACCEPTED, PREDECESSOR, SOURCE2],
 'ancestry_evidence': ancestry,
 'changed_paths_count': len(changed), 'changed_paths': changed,
 'protected_prefixes': list(protected_prefixes), 'protected_names': sorted(protected_names),
 'protected_source_or_evidence_changes': unexpected,
 'source_inputs_per_manifest_checks': input_checks, 'unique_input_files': len(inputs), 'source_inputs_sha256': inputs,
 'runtime': runtime, 'official_linux_engine': engine, 'reviewed_sources': reviewed,
 'default_off_source_review': {
   'ordinary_startup_strata_is_uninstantiated': True,
   'explicit_open_or_layered_load_creates_controller_only': True,
   'three_decorative_worlds_created_only_by_candidate_prepare': True,
   'native_decorative_clocks': 'static/paused/0Hz',
   'unchanged_surfaces': 'frozen material time, UPDATE_DISABLED except explicit admitted bake',
   'atmosphere_initial_process': False,
   'no_new_play_world_actor_or_camera_authority': True,
   'limit': 'Source control-flow inspection; disable after activation may retain resources. Not a cold-start RSS measurement.'},
 'qualification_scope': 'This audit hashes source, manifests, pointers and locally materialized Linux runtime bytes. It performs no native scene test, package execution, GPU measurement or physical owner acceptance. Actual final downloaded Windows payload and extracted execution remain separate gates.'}
assert not (OUT/'source-runtime-custody-934cc0c.json').exists(), 'Preserve original custody receipt'
(OUT/'source-runtime-custody-934cc0c.json').write_text(json.dumps(receipt, indent=2, sort_keys=True)+'\n')
print(json.dumps({'status': receipt['status'], 'source':SOURCE, 'tree':TREE, 'changed_paths':len(changed),
 'source_checks':input_checks, 'unique_inputs':len(inputs), 'actual_runtime_bytes':[(x['artifact'],x['actual_local_bytes_verified']) for x in runtime],
 'engine':engine['sha256'], 'output':str(OUT/'source-runtime-custody-934cc0c.json')}))
