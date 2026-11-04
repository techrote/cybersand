#!/usr/bin/env python3
"""Close independent source/artifact/owner review without project imports or writes.

This reads retained artifacts and pinned Git objects. It does not run a candidate,
change Git state, retry CI, invoke the publisher, or confer physical admission.
"""
from pathlib import Path
import ast
import datetime
import gzip
import hashlib
import importlib.util
import json
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parent
ARTIFACTS = ROOT / 'artifacts'
REPOSITORY = ROOT.parent.parent / 'physics-lane'
SOURCE = '9597abd76c01e4a940ff3ea26ff01fca43bf55a6'
TREE = '11e986214f056f3f39631bb0331b3cd4930c3d1c'
LOCAL = '2f0ea3bdba5b7aef2fddef7d3a70f7e8d21adab9'
RUN = 41848472642


def read(path):
    return json.loads(path.read_bytes())


def identity(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        while data := stream.read(1024 * 1024):
            digest.update(data)
    return {'path': str(path), 'bytes': path.stat().st_size, 'sha256': digest.hexdigest()}


def git_bytes(path):
    return subprocess.check_output(['git', 'show', LOCAL + ':' + path], cwd=REPOSITORY)


def command_receipt(path):
    record = read(path)
    assert record['schema'] == 'execution-command-v1'
    assert record['status'] == 'passed' and record['returncode'] == 0
    assert record['complete'] and record['natural_completion'] and not record['timed_out']
    source = record['source']
    assert source['commit'] == SOURCE and source['tree'] == TREE
    assert source['run_id'] == str(RUN) and source['run_attempt'] == '1'
    assert record['log'] == 'command.log'
    log = identity(path.parent / 'command.log')
    assert log['sha256'] == record['log_sha256']
    return {'receipt': identity(path), 'log': log, 'record': record, 'verdict': 'PASS'}


def main():
    spec = importlib.util.spec_from_file_location('independent_hosted', ROOT / 'review_hosted_receipts.py')
    reviewer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(reviewer)
    completed_path = ROOT / 'observations/2026-11-04T14-53-05-473Z.json'
    completed = read(completed_path)
    data = {row['resource']: row['data'] for row in completed['results']}
    run, jobs, branch = data['run'], data['jobs']['jobs'], data['branch']
    assert run['id'] == RUN and run['head_sha'] == SOURCE and run['run_attempt'] == 1
    assert run['status'] == 'completed' and run['conclusion'] == 'failure'
    assert len(jobs) == 12 and sum(row['conclusion'] == 'success' for row in jobs) == 11
    publisher = next(row for row in jobs if row['id'] == 126648851948)
    assert publisher['conclusion'] == 'failure'
    assert next(row for row in publisher['steps'] if row['number'] == 5)['conclusion'] == 'failure'
    assert branch['object']['sha'] == SOURCE
    metadata_path = ROOT / 'observations/2026-11-04T14-50-16-083Z.json'
    metadata = next(row['data']['artifacts'] for row in read(metadata_path)['results'] if row['resource'] == 'artifacts')
    archive_receipts = []
    assert len(metadata) == 14
    for item in metadata:
        archive = ARTIFACTS / (item['name'] + '.zip')
        found = identity(archive)
        assert found['bytes'] == item['size_in_bytes']
        assert found['sha256'] == item['digest'].removeprefix('sha256:')
        assert item['workflow_run']['id'] == RUN and item['workflow_run']['head_sha'] == SOURCE
        with zipfile.ZipFile(archive) as bundle:
            members = [{'name': row.filename, 'bytes': row.file_size, 'compressed_bytes': row.compress_size}
                       for row in bundle.infolist() if not row.is_dir()]
        archive_receipts.append({'id': item['id'], 'name': item['name'],
            'github_digest': item['digest'], 'archive': found, 'members': members,
            'workflow_run': item['workflow_run'], 'verdict': 'DIGEST_AND_SIZE_VERIFIED'})
    linux = ARTIFACTS / 'sol281-build-linux-41848472642-1'
    source_archive = identity(linux / 'source.tar.gz')
    checksum_path = linux / 'source.tar.gz.sha256'
    checksum = checksum_path.read_text().split()
    assert len(checksum) == 2 and checksum[0] == source_archive['sha256']
    assert Path(checksum[1]).name == 'source.tar.gz'
    with gzip.open(linux / 'source.tar.gz', 'rb') as stream:
        prefix = stream.read(1024)
    archive_commit = subprocess.run(['git', 'get-tar-commit-id'], input=prefix,
        capture_output=True, check=True).stdout.decode().strip()
    assert archive_commit == SOURCE
    publisher_source = git_bytes('tools/sol281/publish_runtime.py')
    node = ast.parse(publisher_source)
    value = next(row.value for row in node.body if isinstance(row, ast.Assign)
                 and any(isinstance(x, ast.Name) and x.id == 'MAX_FILE_BYTES' for x in row.targets))
    assert ast.dump(value) == ast.dump(ast.parse('128 * 1024 * 1024', mode='eval').body)
    cap = 128 * 1024 * 1024
    assert source_archive['bytes'] > cap
    log_path = ROOT / 'publisher-126648851948.log'
    log_text = log_path.read_text()
    error_line = next(line for line in log_text.splitlines()
        if 'SOL281 runtime publication refused: Artifact exceeds bounded file capacity' in line)
    assert 'Ran 13 tests' in log_text
    build_commands = []
    for target in ('linux', 'windows'):
        build = ARTIFACTS / ('sol281-build-' + target + '-41848472642-1')
        for command in ('prepare', 'bindings', 'extension', 'native-regressions' if target == 'linux' else 'compiler'):
            build_commands.append({'target': target, 'label': command,
                **command_receipt(build / command / 'receipt.json')})
    linux_outer = command_receipt(ARTIFACTS / 'sol364b-diagnostic-linux-41848472642-1/linux-command/receipt.json')
    msvc = ARTIFACTS / 'sol281-msvc-41848472642-1'
    msvc_record = read(msvc / 'receipt.json')
    assert msvc_record['schema'] == 'cybersand.sol281.msvc-command.v1'
    assert msvc_record['source'] == {'sha': SOURCE, 'tree': TREE}
    assert msvc_record['platform'] == 'Windows' and msvc_record['cohort'] == 'mechanism'
    assert msvc_record['run_id'] == str(RUN) and msvc_record['run_attempt'] == '1'
    assert msvc_record['status'] == 'passed' and msvc_record['returncode'] == 0
    assert msvc_record['natural_completion'] and not msvc_record['timed_out']
    msvc_logs = {}
    for filename, key in (('command.log', 'log_sha256'), ('command.stderr.log', 'stderr_sha256')):
        msvc_logs[filename] = identity(msvc / filename)
        assert msvc_logs[filename]['sha256'] == msvc_record[key].lower()
    before, after = read(msvc / 'before.json'), read(msvc / 'after.json')
    assert before['source'] == after['source'] == {'sha': SOURCE, 'tree': TREE}
    assert before['inputs'] == after['inputs'] and before['checkout_inputs'] == after['checkout_inputs']
    assert after['before_manifest_sha256'] == identity(msvc / 'before.json')['sha256']
    source_checks = {kind: reviewer.source_map_check(REPOSITORY, before[kind], {}, checkout=kind == 'checkout_inputs')
                     for kind in ('inputs', 'checkout_inputs')}
    markers = {'solid_detachment': ('SOL-DETACH-001 A1 native precursor: 9 groups, 19338 checks passed.', 9, 19338),
               'conservative_displacement': ('CONSERVATIVE-DISPLACEMENT native: 6 groups, 281 checks passed.', 6, 281),
               'solid_contact_geometry': ('SOL281_CONTACT_GEOMETRY 6 groups / 6817 checks passed', 6, 6817)}
    native_results = []
    gcc_log = (linux / 'native-regressions/command.log').read_text()
    binaries = read(msvc / 'binary-identities.json')
    assert set(binaries) == set(markers)
    for name, (marker, groups, checks) in markers.items():
        path = msvc / ('run-' + name + '.log')
        assert path.read_text().count(marker) == 1
        assert gcc_log.count(marker) == 2
        native_results.append({'name': name, 'groups': groups, 'checks': checks,
            'windows_original_log': identity(path), 'windows_compilation_log': identity(msvc / ('compile-' + name + '.log')),
            'windows_binary_identity_reported_by_actual_host': binaries[name],
            'windows_binary_independently_rehashed': False,
            'linux_final_marker_count': 2, 'linux_scope': 'optimized and sanitizer commands in original GCC log'})
    final_path = ROOT / 'independent_hosted_review_final.json'
    final = read(final_path)
    assert final['errors'] == [] and final['source'] == SOURCE and final['tree'] == TREE
    assert final['cpu_matrix']['passed_groups'] == 24 and final['live_process_records'] == 74
    complete_path = ARTIFACTS / 'sol281-qualified-41848472642-1/qualification.json'
    complete = read(complete_path)
    assert complete['status'] == 'passed' and complete['errors'] == []
    assert complete['source'] == {'sha': SOURCE, 'tree': TREE}
    assert len(complete['cohorts']) == 8
    for item in complete['cohorts']:
        host = next(row for row in final['host_receipts'] if
            (row['platform'], row['cohort']) == (item['platform'], item['cohort']))
        assert item['report_sha256'] == host['receipt']['sha256']
        assert item['runtime'] == host['runtime'] and item['cases'] == host['records']
    windows_diag = next(row for row in final['diagnostics'] if row['platform'] == 'Windows')
    assert '19.44.35229 for x64' in windows_diag['compiler_version']['stderr'] + windows_diag['compiler_version']['stdout']
    result = {'schema': 'cybersand.sol364b.independent-hosted-closure.v1',
        'reviewed_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'review_program': identity(Path(__file__)), 'source': SOURCE, 'tree': TREE,
        'run': {'id': RUN, 'attempt': 1, 'status': 'completed', 'conclusion': 'failure',
                'observation': identity(completed_path), 'observed_at_utc': completed['utc'],
                'successful_jobs': 11, 'failed_jobs': 1, 'jobs': jobs,
                'remote_branch_at_observation': branch['object']['sha'], 'publication_child_observed': False},
        'artifact_metadata_observation': identity(metadata_path), 'artifacts': archive_receipts,
        'build_commands': build_commands, 'linux_diagnostic_outer_owner': linux_outer,
        'actual_windows_msvc': {'verdict': 'PASS', 'receipt': identity(msvc / 'receipt.json'),
            'record': msvc_record, 'logs': msvc_logs, 'before': identity(msvc / 'before.json'),
            'after': identity(msvc / 'after.json'), 'source_verification': source_checks,
            'binary_identity_receipt': identity(msvc / 'binary-identities.json'),
            'native_results': native_results, 'diagnostic_compiler': windows_diag['compiler_version'],
            'scope': 'Actual Windows MSVC execution, distinct from LLVM-Mingw native DLL cross-build. Executables absent from uploaded receipt artifact; their hashes are host-reported.'},
        'publisher_failure': {'verdict': 'FAIL_CAPACITY_CONTRACT', 'job_id': publisher['id'],
            'step': 5, 'error_line': error_line, 'log': identity(log_path),
            'log_encoding_scope': 'Connector-decoded original job log; saved with LF normalization, not an original log ZIP hash.',
            'source_archive': source_archive, 'source_archive_recorded_commit': archive_commit,
            'checksum_receipt': identity(checksum_path), 'maximum_file_bytes': cap,
            'excess_bytes': source_archive['bytes'] - cap,
            'source_contract': {'path': 'tools/sol281/publish_runtime.py',
                'sha256': hashlib.sha256(publisher_source).hexdigest(),
                'constant_line': 36, 'files_in_bound_line': 127, 'verify_build_entry_line': 148},
            'publisher_unit_tests': {'count': 13, 'status': 'PASS'},
            'publication_receipt_created': False, 'runtime_provenance_refreshed': False,
            'repair_retry_or_capacity_change_performed': False},
        'final_independent_reduction': identity(final_path),
        'complete_execution_qualification': identity(complete_path),
        'gate_outcomes': {'source_and_build_custody': 'PASS', 'eight_actual_host_cohorts': 'PASS',
            'all_24_cpu_groups': 'PASS', 'all_84_sustained_clearance_cases': 'FAIL',
            'depth_bounds': 'FAIL_64_OF_84', 'asynchronous_final_overlap': 'FAIL_36_OF_36_CANDIDATE_CASES',
            'bounded_corridor_diagnostic': 'PASS_NO_GO_FINDING_ONLY',
            'actual_windows_msvc': 'PASS', 'linux_gcc_address_and_undefined_sanitizers': 'PASS',
            'leak_sanitizer': 'UNAVAILABLE_NOT_EXERCISED', 'runtime_publication': 'FAIL',
            'integration_admission': 'NO_GO_NOT_AUTHORIZED'},
        'preservation': {'provisional_receipt': identity(ROOT / 'independent_hosted_review_provisional.json'),
            'prior_local_default_leak_sanitizer_and_outer_owner_failures': 'Retained unchanged in original source review receipts; fresh hosted success does not relabel prior attempts.',
            'historical_source_957_reports': 'Unchanged historical controls; diagnostic replay does not replace live physical evidence.',
            'scope': 'All validations are read-only. No candidate test rerun, CI retry, publisher retry, branch write, mutation, limit widening, or acceptance promotion.'}}
    output = ROOT / 'independent_hosted_closure.json'
    with output.open('x') as stream:
        json.dump(result, stream, indent=2, sort_keys=True, allow_nan=False)
        stream.write('\n')
    print(json.dumps({'output': identity(output), 'artifacts_verified': len(archive_receipts),
        'build_command_receipts_verified': len(build_commands), 'actual_msvc': 'PASS',
        'publisher': 'FAIL_CAPACITY_CONTRACT', 'integration': 'NO_GO'}, indent=2))


if __name__ == '__main__':
    main()
