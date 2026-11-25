#!/usr/bin/env python3
"""Reduce the preserved Windows threshold failure and ledger-only repeat delta.

No application rerun and no raw archive publication. The boolean active operand
is deliberately left unknown because the original log did not print it.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import zipfile

HERE = Path(__file__).resolve().parent
REPO = Path('/tmp/art-c-delivery-doc')
ARCHIVE = Path('/tmp/art-3a-windows-attempt1-custody/evidence-artifact.zip')
BEFORE = 'bcc92927ce3894a16d5544923cfbf7b1d0339fda'
SOURCE = '3a0ec3659f23d8e997e6721aa754d5a8ebe48512'
TREE = '99394ad1133b4796efa0b95eb31dfa5c7bdbbaaf'
LEDGER = 'docs/audits/2026-11-25-art-workbench-collaborative-002/README.md'
checks = 0
failures = []


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def check(value, label):
    global checks
    checks += 1
    if not value:
        failures.append(label)


def git(*argv):
    return subprocess.check_output(['git', '-C', str(REPO), *argv])


def main():
    inputs = json.loads((HERE / 'delivery-negative-inputs.json').read_text())
    artifact = inputs['artifact']
    repeat = inputs['repeat']
    raw = ARCHIVE.read_bytes()
    check(len(raw) == artifact['bytes'] == 4393990 and sha(raw) == artifact['sha256'], 'immutable failed original archive')
    check(artifact['source'] == SOURCE and artifact['campaign'] == 45553413100 and artifact['id'] == 14995049040, 'refreshed original Actions source identity')
    outputs = {}
    with zipfile.ZipFile(ARCHIVE) as z:
        names = z.namelist()
        check(len(names) == len(set(names)) == 530 and z.testzip() is None, 'all original member CRCs')
        for mode, file, expected_progress, expected_checks, expected_failures in [
            ('headless', 'test_art_batch_native.stdout.log', 55, 148, 0),
            ('displayed', 'art-native-displayed.stdout.log', 2187, 151, 1),
        ]:
            raw_log = z.read(file)
            lines = raw_log.decode().splitlines()
            rows = [s for s in lines if s.startswith('ART_CHECK ')]
            bad = [s for s in rows if s.endswith(' false')]
            timing = [int(s.removeprefix('ART_FIRST_PROGRESS_MS ')) for s in lines if s.startswith('ART_FIRST_PROGRESS_MS ')]
            result = [json.loads(s.removeprefix('ART_STAGE1_RESULT ')) for s in lines if s.startswith('ART_STAGE1_RESULT ')]
            check(len(result) == 1 and result[0]['checks'] == len(rows) == expected_checks, mode + ' terminal assertion count')
            check(result[0]['failures'] == len(bad) == expected_failures, mode + ' exact failure count')
            check(timing == [expected_progress], mode + ' unmodified original timing')
            check('ART_CHECK sparse polygon publishes an early native receipt true' in rows, mode + ' actual receipt assertion')
            check('ART_CHECK first sparse pixels reach the display image true' in rows, mode + ' image material pixel assertion')
            check(result[0]['last_native_backend'] == 'CyberNativeCellWorld', mode + ' actual native backend')
            if mode == 'displayed':
                check(bad == ['ART_CHECK sparse polygon makes visible progress before raster completes false'], 'only failing displayed assertion')
                check(expected_progress >= 2000, 'timing independently violates strict threshold')
            outputs[mode] = {'original_log': file, 'bytes': len(raw_log), 'sha256': sha(raw_log), 'original_assertions': len(rows), 'original_failures': len(bad), 'first_progress_ms': timing[0], 'native_backend': result[0]['last_native_backend'], 'early_native_receipt_assertion': True, 'image_pixel_assertion': True, 'active_operand_separately_reported': False, 'active_operand_value': None}
        error = z.read('art-native-displayed.stderr.log')
        check(b'ERROR: sparse polygon makes visible progress before raster completes' in error, 'matching original error log')
        check(not any(s.startswith('art-collaborative-headless/') or s.startswith('art-collaborative-displayed/') for s in names), 'new collaborative native campaign absent from failed archive')
        session = z.read('test_art_session_log.stdout.log')
        session_checks = [s for s in session.decode().splitlines() if s.startswith('ART_SESSION_CHECK ')]
        check(len(session_checks) == 35 and all(s.endswith(' true') for s in session_checks), 'accepted session foundation individually passed')
    src_paths = ['godot/tests/test_art_batch_native.gd', 'godot/scripts/art_batch_plan.gd', 'godot/scripts/art_batch_executor.gd', '.github/workflows/art-session-logging.yml']
    identities = {}
    for path in src_paths:
        old = git('show', BEFORE + ':' + path)
        new = git('show', SOURCE + ':' + path)
        check(old == new, 'bcc-to3a unchanged ' + path)
        identities[path] = sha(new)
    fixture = git('show', SOURCE + ':godot/tests/test_art_batch_native.gd').decode()
    check('check(art.active and first_progress_ms<2000,' in fixture, 'exact strict predicate unchanged')
    check('func cell(x: int,y: int) -> int: return main.image.get_pixel(x,y).r8' in fixture, 'pixel assertion is image-plane readback, not physical monitor timing')
    bcc_delta = git('diff', '--name-only', BEFORE, SOURCE).decode().splitlines()
    check(set(bcc_delta) == {'docs/operations/art-workbench-collaborative-evaluation.md', 'tools/package_art_collaborative.py', 'tools/ci/test_art_collaborative_packaging.py'}, 'intentional guide/package/package-test delta')
    check(repeat['parents'] == [SOURCE] and repeat['commit'] == 'd503d824aac4128968f7dfba5dccd540c3c07b59' and repeat['tree'] == '464c60288d5461d61578b000ae68ac029cffb5bd', 'canonical repeat commit metadata')
    changes = git('diff', '--name-only', SOURCE, repeat['tree']).decode().splitlines()
    check(changes == [LEDGER], 'repeat changes only ledger')
    prior_ledger = git('show', SOURCE + ':' + LEDGER)
    next_ledger = git('show', repeat['tree'] + ':' + LEDGER)
    check(next_ledger.startswith(prior_ledger) and len(next_ledger) - len(prior_ledger) == 2822, 'strictly append-only ledger negative')
    check(b'**2187**' in next_ledger[len(prior_ledger):] and b'**less-than-2000 ms**' in next_ledger[len(prior_ledger):], 'ledger retains original failure and gate')
    result = {'schema': 'art-delivery-negative-independent-review-v1', 'passed': not failures, 'checks': checks, 'failures': failures, 'artifact': artifact, 'original_archive_members_crc_checked': 530, 'source': SOURCE, 'source_tree': TREE, 'observations': outputs, 'displayed_stderr_sha256': sha(error), 'session_foundation': {'checks': 35, 'failures': 0, 'log_sha256': sha(session)}, 'unchanged_source_sha256': identities, 'bcc_to_3a_delta': bcc_delta, 'repeat': {**repeat, 'only_changed_path': LEDGER, 'append_only_bytes': len(next_ledger) - len(prior_ledger), 'prior_ledger_sha256': sha(prior_ledger), 'repeat_ledger_sha256': sha(next_ledger), 'application_native_test_workflow_guide_packager_bytes_unchanged_from_3a': True}, 'historical_ledger_wording_clarification': 'The 3a paragraph uses tests broadly. Precisely: application/Godot native fixtures and workflows are unchanged from bcc, while packaging tests were intentionally extended. The d503 descendant changes no test at all.', 'review_script_sha256': sha(Path(__file__).read_bytes()), 'limits': ['The strict first-progress timing bound failed; later geometry success does not change that outcome.', 'The original active operand is unprinted and unknown; a failed conjunction is not evidence of either active value.', 'Timer includes raster/executor/native publication and polling until the CPU image material value appears; it is not an isolated native-worker or physical-display latency measure.', 'No causal attribution to provider, native code, renderer, OS scheduling or host contention follows from this record.', 'Headless and displayed observations are different conditions; neither is substituted for the other.', 'The failed Windows attempt did not reach the nine new groups or packaging; the independent 3a Linux result remains separate.', 'The proposed fresh full repeat has no inferred outcome and must retain the original failure.', 'Derived data only; no original archive, log, image or audit is reuploaded.']}
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if not failures else 1)


if __name__ == '__main__':
    main()
