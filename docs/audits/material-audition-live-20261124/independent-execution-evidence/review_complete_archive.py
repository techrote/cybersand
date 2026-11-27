import hashlib
import json
import sys
import time
import zipfile
from pathlib import Path, PurePosixPath

root = Path('/workspace/scratch/1f637294a480/cybersand')
base = Path('/workspace/scratch/1f637294a480')
archive = Path('/tmp/cybersand-mat-audition-delivery-5f73b0ae/CyberSand-Material-Audition-Windows.zip')
evidence = base / 'evidence/hosted-source3-windows/evidence/relocated-package'
candidate = base / 'evidence/hosted-source3-windows-build/candidate'
sys.path[:0] = [str(root / 'tools'), str(root / 'tools/ci')]
import package_material_audition_candidate as p
q = p.qualification
begin = time.monotonic()
stat = archive.stat()
digest = q.sha(archive)
assert stat.st_size == 754138787 and digest == 'cb4c67025fb1de64b3f647d70873421cf9be601372fccd2a915791222d94bb96'
c = json.loads((candidate / q.MANIFEST).read_text())
with zipfile.ZipFile(archive) as z:
    entries = z.infolist()
    names = [entry.filename for entry in entries]
    assert len(names) == len(set(names))
    for entry in entries:
        name = PurePosixPath(entry.filename)
        assert not name.is_absolute() and '..' not in name.parts and '\\' not in entry.filename
        assert (entry.external_attr >> 16) & 0o170000 != 0o120000
    raw = z.read(p.MANIFEST)
    m = json.loads(raw)
    assert hashlib.sha256(raw).hexdigest() == '93a3cd71302d7c7202ca8f93d13bb7fae609b461794773c641b6d5b958f09e7c'
    assert m['source_commit'] == c['source_commit'] and m['source_tree'] == c['source_tree'] and m['native_sha256'] == c['native_sha256']
    assert m['human_acceptance'] == 'OWNER-PENDING' and m['default_profile_active'] is True and m['canonical_defaults_changed'] is False
    payload = {entry.filename for entry in entries if not entry.is_dir() and entry.filename != p.MANIFEST}
    assert payload == set(m['files_sha256'])
    for index, name in enumerate(sorted(payload), 1):
        with z.open(name) as stream:
            actual = hashlib.file_digest(stream, 'sha256').hexdigest()
        assert actual == m['files_sha256'][name], name
        if index % 5000 == 0:
            print('verified payload files', index, flush=True)
    assert z.read('Open Workbench.cmd') == p.launcher(c['source_commit'])
    assert z.read('Open Materials Lab.cmd') == p.launcher(c['source_commit'], laboratory=True)
    assert hashlib.sha256(z.read('qualification/candidate/' + q.MANIFEST)).hexdigest() == q.sha(candidate / q.MANIFEST)
    for name, expected in c['execution_inputs'].items():
        content = z.read('source/' + name)
        if Path(name).suffix in q.TEXT_SUFFIXES or Path(name).name in q.TEXT_FILENAMES:
            content = content.replace(b'\r\n', b'\n')
        assert hashlib.sha256(content).hexdigest() == expected, name
    engine = m['files_sha256']['Godot_v4.7-stable_win64_console.exe']
    assert engine == 'd8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c'
    assert m['files_sha256']['source/' + q.RUNTIMES['windows']] == c['native_sha256']
    assert m['files_sha256']['qualification/candidate/' + Path(q.RUNTIMES['windows']).name] == c['native_sha256']
    readme = z.read('README.txt')
    assert hashlib.sha256(readme).hexdigest() == 'c9ca0ab02c121a6b3b9b0fd218a867e21135ec4a8dccb6531bddf6d096f37216'
    assert c['source_commit'].encode() in readme and c['native_sha256'].encode() in readme
    readable = b' '.join(readme.split())
    assert b'Revert configuration' in readable and b'Use active as draft' in readable
    p.verify_extracted_execution(evidence, c, archive, candidate_digest=q.sha(candidate / q.MANIFEST), godot_digest=engine)
    final = archive.stat()
    assert (final.st_ino, final.st_size, final.st_mtime_ns) == (stat.st_ino, stat.st_size, stat.st_mtime_ns)
    out = {
        'schema': 'cybersand.material-audition.independent-complete-archive-review',
        'schema_version': 1, 'status': 'passed',
        'source_commit': c['source_commit'], 'source_tree': c['source_tree'], 'source_run_id': 45465121123,
        'archive': {'file': archive.name, 'bytes': stat.st_size, 'sha256': digest},
        'archive_entries': len(entries), 'uncompressed_bytes': sum(entry.file_size for entry in entries),
        'manifested_payload_files_checked': len(payload), 'all_payload_sha256_match': True,
        'execution_inputs_checked': len(c['execution_inputs']), 'native_inputs_checked': len(c['native_inputs']),
        'package_manifest_sha256': hashlib.sha256(raw).hexdigest(), 'native_sha256': c['native_sha256'],
        'engine_console_sha256': engine, 'candidate_manifest_sha256': q.sha(candidate / q.MANIFEST),
        'readme_sha256': hashlib.sha256(readme).hexdigest(), 'readme_bytes': len(readme),
        'both_shipped_launchers_match_qualified_source': True,
        'original_extracted_execution_validator_passed': True,
        'package_execution_sha256': q.sha(evidence / 'package-execution.json'),
        'native_windows_execution_previously_verified': True,
        'no_full_extraction_or_execution_repeated': True,
        'reviewer_script_sha256': q.sha(Path(__file__)),
        'first_review_attempt': {
            'result': 'stopped at an additional README literal phrase assertion after all payload and source hashes passed',
            'reason': 'The immutable README wraps Revert and configuration across CRLF; no exact-byte single-line phrase exists.',
            'correction': 'Normalize whitespace only for the semantic phrase assertion. Original README bytes/SHA, archive bytes/SHA, all payload hashes and production execution validators remain unchanged.'
        },
        'elapsed_seconds': round(time.monotonic() - begin, 3),
        'physical_owner_acceptance': 'OWNER-PENDING', 'disposition': 'Draft/HOLD'
    }
    q.write(base / 'evidence/reviews/independent-complete-archive-review.json', out)
    print(json.dumps(out, indent=2), flush=True)
