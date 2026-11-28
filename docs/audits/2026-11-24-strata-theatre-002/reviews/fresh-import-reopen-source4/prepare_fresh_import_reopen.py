from pathlib import Path
import json, struct, hashlib, shutil, datetime, subprocess

OUT = Path('/tmp/strata2-a-final-review/fresh-import-reopen-source4')
OUT.mkdir(exist_ok=True)
assert not (OUT/'oracle.json').exists()
SAVE = Path('/home/agent/.local/share/godot/app_userdata/Cyber Sand Reference Sandbox/workbench/setup-strata2-native-import-history.json')
WRITER = Path('/tmp/strata2-evidence/source4-local-final/workflow.json')
PROCESSES = WRITER.with_name('processes.json')
ROOT = Path('/tmp/strata2-recovered')
SOURCE = '934cc0c0eef70dad528155e9a92eebe25e2757eb'
TREE = '0c30ea3eaea61c5091c23b984837f29d7b7c828e'
sha = lambda value: hashlib.sha256(value).hexdigest()
git = lambda *flags: subprocess.check_output(['git', *flags], cwd=ROOT)
original = SAVE.read_bytes(); stat = SAVE.stat()
assert sha(original) == 'eea04ef7ec9e20ff4df6680e02bdd2d303a237a4c78a38c733075cc79b856027'
version, manifest_length, payload_length = struct.unpack_from('<III', original, 8)
assert original[:8] == b'CYSSTRAT' and version == 2 and payload_length == 0
assert len(original) == 52 + manifest_length and hashlib.sha256(original[52:]).digest() == original[20:52]
manifest = json.loads(original[52:])
writer = json.loads(WRITER.read_text()); processes = json.loads(PROCESSES.read_text())
assert writer['completed'] and writer['checks'] == 431 and writer['failures'] == []
assert manifest['scene']['authoring'] == writer['provenance']
assert manifest['scene']['atmosphere'] == writer['layered_construction']['settings']['atmosphere']
assert 0 <= WRITER.stat().st_mtime - stat.st_mtime < 1
assert git('rev-parse', SOURCE + '^{tree}').decode().strip() == TREE
assert set(processes['identity']['delta']) == set(git('diff', '--name-only', processes['identity']['base'], SOURCE).decode().splitlines())
for name, expected in processes['identity']['delta'].items():
    assert git('rev-parse', SOURCE + ':' + name).decode().strip() == expected
width, height = manifest['scene']['extent']; assert (width, height) == (512, 512)

def reconstruct(stamps):
    cells = bytearray(width * height * 2)
    for stamp in stamps:
        assert all(type(value) in (int, float) and int(value) == value for value in stamp)
        values = list(map(int, stamp))
        if len(values) == 5:
            x, y, w, h, material = values
            assert 0 <= x < x + w <= width and 0 <= y < y + h <= height
            row = struct.pack('<H', material) * w
            for yy in range(y, y + h):
                cells[(yy * width + x) * 2:(yy * width + x + w) * 2] = row
        else:
            assert len(values) == 4
            x, y, radius, material = values
            for yy in range(max(0, y-radius), min(height, y+radius+1)):
                for xx in range(max(0, x-radius), min(width, x+radius+1)):
                    if (xx-x)**2 + (yy-y)**2 <= radius**2:
                        struct.pack_into('<H', cells, (yy*width+xx)*2, material)
    return cells

native = {'play': reconstruct(manifest['starting_setup']['edits'])}
for plane in manifest['scene']['planes']:
    if plane['id'] != 'play':
        native[plane['id']] = reconstruct(plane['rectangles'])
hashes = {name: sha(bytes(data)) for name, data in native.items()}
assert hashes['play'] == writer['play_hash_imported']
assert {key: value for key, value in hashes.items() if key != 'play'} == writer['layered_construction']['native_hashes']
probes = [[120,80,58], [123,83,0], [126,81,131], [121,81,0]]
for x, y, material in probes:
    assert struct.unpack_from('<H', native['play'], (y*width+x)*2)[0] == material
xdg = OUT/'xdg'
destination = xdg/'godot/app_userdata/Cyber Sand Reference Sandbox/workbench'/SAVE.name
destination.parent.mkdir(parents=True)
shutil.copy2(SAVE, destination)
assert sha(destination.read_bytes()) == sha(original)
save_record = {'path': str(SAVE), 'bytes': len(original), 'sha256': sha(original), 'mtime_ns': stat.st_mtime_ns,
               'mtime_utc': datetime.datetime.fromtimestamp(stat.st_mtime, datetime.timezone.utc).isoformat()}
oracle = {'schema': 'strata2-retained-save-independent-replay-oracle-v1', 'source_commit': SOURCE, 'source_tree': TREE,
          'save_name': 'strata2-native-import-history', 'save_sha256': sha(original), 'original_save': save_record,
          'writer_report_sha256': sha(WRITER.read_bytes()), 'writer_processes_sha256': sha(PROCESSES.read_bytes()),
          'writer_process_id': writer['process_id'], 'writer_source_field': writer['source_revision'],
          'writer_binding': processes['identity'], 'writer_owner_session': writer['native_owner_stats']['session_id'],
          'writer_provenance': writer['provenance'], 'provenance_records': len(writer['provenance']['records']),
          'writer_play_hash_imported': writer['play_hash_imported'], 'writer_decorative_hashes': writer['layered_construction']['native_hashes'],
          'native_hashes': hashes, 'play_probes': probes, 'document': manifest['scene'], 'saved_setup': manifest['starting_setup'],
          'binding_limit': 'Writer report source_revision is empty. Original wrapper base plus five exact blobs equals source934. The save is retrospectively bound by exact17-record provenance, unique historical owner, four native hashes, settings and mtime; the writer did not record save SHA at execution.',
          'scope': 'Independent Python replay of all four ordered authored native layouts from unchanged checksum-validated CYSSTRAT bytes, before one fresh headless ordinary Workbench loader.'}
(OUT/'oracle.json').write_text(json.dumps(oracle, indent=2, sort_keys=True)+'\n')
(OUT/'original-save-copy.cysstrat').write_bytes(original)
(OUT/'writer-workflow.json').write_bytes(WRITER.read_bytes())
(OUT/'writer-processes.json').write_bytes(PROCESSES.read_bytes())
(OUT/'preparation-negative.json').write_text(json.dumps({'phase':'oracle preparation before any Godot process', 'original_error':'AssertionError: expected writer report checks430', 'diagnosis':'Original console summary counts430 before finish(); full report includes successful teardown as check431.', 'resolution':'Assert actual complete original report431; no writer rerun or change.'}, indent=2)+'\n')
print(json.dumps({'oracle': str(OUT/'oracle.json'), 'isolated_xdg': str(xdg), 'native_hashes': hashes, 'provenance_records': len(writer['provenance']['records'])}))
