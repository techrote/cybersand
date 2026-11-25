"""Independent derived-only reduction of the failed first 3a Windows campaign."""
import hashlib
import json
import pathlib
import re
import subprocess
import zipfile

ROOT = pathlib.Path('/tmp/art-3a-windows-attempt1-custody')
REPO = pathlib.Path('/tmp/art-collaborative-002-source-v2')
SOURCE = '3a0ec3659f23d8e997e6721aa754d5a8ebe48512'
TREE = '99394ad1133b4796efa0b95eb31dfa5c7bdbbaaf'


def sha(value):
    return hashlib.sha256(value).hexdigest()


archive = ROOT / 'evidence-artifact.zip'
assert archive.stat().st_size == 4393990
assert sha(archive.read_bytes()) == '195829a172f0fb91f7b92cad1efe6618e33daf397c2df52b7d9cbdd23d4a1f94'
observations = []
for label, source, path, expected_progress, expected_failures in [
    ('e536_prior', 'e536d128f85e948223b25e13931a7a801faf956d', '/tmp/art-e536-windows-custody/evidence-artifact.zip', 1693, 0),
    ('bcc_prior', 'bcc92927ce3894a16d5544923cfbf7b1d0339fda', '/tmp/art-bcc-windows-custody/evidence-artifact.zip', 1363, 0),
    ('3a_attempt1', SOURCE, str(archive), 2187, 1),
]:
    with zipfile.ZipFile(path) as z:
        assert z.testzip() is None
        stdout = z.read('art-native-displayed.stdout.log')
        stderr = z.read('art-native-displayed.stderr.log')
        text = '\n'.join(stdout.decode('utf-8').splitlines())
        progress = [int(v) for v in re.findall(r'^ART_FIRST_PROGRESS_MS ([0-9]+)$', text, re.M)]
        results = [json.loads(value) for value in re.findall(r'^ART_STAGE1_RESULT (.+)$', text, re.M)]
        assert progress == [expected_progress] and len(results) == 1
        result = results[0]
        assert result['checks'] == 151 and result['failures'] == expected_failures
        assert 'ART_CHECK sparse polygon publishes an early native receipt true' in text
        assert 'ART_CHECK first sparse pixels reach the display image true' in text
        predicate_value = 'false' if expected_failures else 'true'
        assert 'ART_CHECK sparse polygon makes visible progress before raster completes ' + predicate_value in text
        observations.append({'label': label, 'source_commit': source, 'first_progress_ms': progress[0],
                             'result': result, 'stdout_sha256': sha(stdout), 'stdout_bytes': len(stdout),
                             'stderr_sha256': sha(stderr), 'stderr_bytes': len(stderr),
                             'early_native_receipt_observed': True, 'first_displayed_native_pixel_observed': True,
                             'active_at_combined_assertion_separately_recorded': False})
source_files = {}
for path in ['godot/tests/test_art_batch_native.gd', 'godot/scripts/art_batch_plan.gd',
             'godot/scripts/art_batch_executor.gd', '.github/workflows/art-session-logging.yml']:
    hashes = {}
    for label, source in [('bcc', 'bcc92927ce3894a16d5544923cfbf7b1d0339fda'), ('3a', SOURCE)]:
        hashes[label] = sha(subprocess.check_output(['git', 'show', source + ':' + path], cwd=REPO))
    assert len(set(hashes.values())) == 1
    source_files[path] = hashes
test = subprocess.check_output(['git', 'show', SOURCE + ':godot/tests/test_art_batch_native.gd'], cwd=REPO).decode()
assert 'check(art.active and first_progress_ms<2000,' in test
report = {
    'schema': 'art-independent-retained-native-progress-failure-v1',
    'source_commit': SOURCE, 'source_tree': TREE,
    'run_id': 45553413100, 'windows_job_id': 138999860117,
    'run_url': 'https://github.com/techrote/cybersand/actions/runs/45553413100',
    'original_evidence': {'artifact_id': 14995049040, 'bytes': archive.stat().st_size,
                          'sha256': sha(archive.read_bytes()), 'crc_passed': True,
                          'url': 'https://github.com/techrote/cybersand/actions/runs/45553413100/artifacts/14995049040'},
    'api_decoded_job_log': {'bytes': (ROOT / 'workflow-job-decoded.log').stat().st_size,
                            'sha256': sha((ROOT / 'workflow-job-decoded.log').read_bytes())},
    'campaign_outcome': {'source_decision': 'passed', 'linux': 'passed', 'windows': 'failed',
                         'failure_step': 'Import and execute fresh user-data Workbench tests',
                         'new_nine_case_windows_suite': 'skipped', 'package': 'skipped',
                         'pristine_extracted_launch': 'skipped', 'new_evaluator_exists': False},
    'predicate': 'art.active and first_progress_ms < 2000',
    'observed_failure': 'First progress 2187 ms independently violates the strict 2000 ms bound. The active boolean at the combined assertion was not separately printed.',
    'observations': observations,
    'runtime_test_workflow_byte_identity_bcc_to_3a': source_files,
    'interpretation': 'A retained actual displayed performance failure. Separate hosted prior passes do not establish a cause, a correction, or a reproducibility rate. No predicate, timeout, test, application or native implementation was changed or waived by this review.',
    'publication_scope': 'Derived identities, counters and conclusions only. Raw downloads and decoded logs remain local; the original Actions artifact is the linked source of truth.',
}
(ROOT / 'independent-first-attempt-review.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
print(json.dumps(report, indent=2))
