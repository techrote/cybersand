"""Authenticate an existing evaluator before independent extracted execution.

The application and its original validators remain at their recorded source;
this driver cannot inherit an extracted pass from the package build.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
REQUEST = '.github/pubpres-extracted-run.json'
BRANCH = 'codex/pubpres-playability-final-001-20261124'
ALLOWED = {REQUEST, '.github/workflows/pubpres-mainline.yml',
           '.github/workflows/pubpres-extracted-recovery.yml',
           'tools/pubpres_mainline/reextract.py',
           'tools/pubpres_mainline/test_reextract.py',
           'tools/pubpres_mainline/extracted_linker_audit.py',
           'tools/pubpres_mainline/test_extracted_linker_audit.py',
           'docs/audits/pubpres-delivery-recovery-20261128/extraction-handoff-recovery.json'}


def need(condition, message):
    if not condition:
        raise ValueError(message)


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args], timeout=120).decode().strip()


def read_request():
    request = json.loads((ROOT / REQUEST).read_bytes())
    need(request['schema'] == 'pubpres-independent-extraction-request-v1'
         and request['physical_acceptance'] == 'HOLD'
         and request['promotion'] == 'DRAFT_ONLY', 'Unknown extraction request or promotion status')
    need(subprocess.check_output(['git', '-C', str(ROOT), 'show', 'HEAD:' + REQUEST])
         == (ROOT / REQUEST).read_bytes(), 'Uncommitted extraction request')
    need(not git(ROOT, 'status', '--porcelain', '--untracked-files=no'), 'Dirty driver inputs')
    git(ROOT, 'merge-base', '--is-ancestor', request['application_commit'], 'HEAD')
    changed = set(git(ROOT, 'diff', '--name-only', request['application_commit'], 'HEAD').splitlines())
    need(changed and changed <= ALLOWED, 'Driver changed application or unregistered execution inputs')
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        need(os.environ['GITHUB_REPOSITORY'] == 'techrote/cybersand'
             and os.environ['GITHUB_EVENT_NAME'] == 'push'
             and os.environ['GITHUB_REF'] == 'refs/heads/' + BRANCH
             and os.environ['GITHUB_SHA'] == git(ROOT, 'rev-parse', 'HEAD'), 'Foreign extraction driver')
    return request


def validate_metadata(request, run, artifact, jobs):
    need(run['id'] == request['run_id'] and run['run_attempt'] == request['run_attempt']
         and run['head_sha'] == request['application_commit']
         and run['head_branch'] == BRANCH and run['event'] == 'push'
         and run['path'] == '.github/workflows/pubpres-mainline.yml', 'Foreign package campaign')
    need(artifact['id'] == request['artifact_id'] and artifact['name'] == request['artifact_name']
         and artifact['expired'] is False and artifact['size_in_bytes'] == request['outer_bytes']
         and artifact['digest'] == 'sha256:' + request['outer_sha256']
         and artifact['workflow_run']['id'] == request['run_id']
         and artifact['workflow_run']['head_sha'] == request['application_commit'], 'Foreign artifact metadata')
    focuses = ('frozen', 'water', 'members', 'held-placement', 'mainline', 'native-owner',
               'selected-water', 'selected-members', 'selected-held-placement')
    required = {'admission', 'source-gates', 'Complete source-exact Windows evaluator'}
    required |= {'qualification-' + p + '-' + f for p in ('linux', 'windows') for f in focuses}
    required |= {'features-' + p + '-' + m for p in ('linux', 'windows') for m in ('ramcache', 'strata', 'shared')}
    need(len(required) == 27 and jobs['total_count'] <= 100, 'Changed package gate population')
    admitted = {}
    for name in sorted(required):
        rows = [j for j in jobs['jobs'] if j['name'] == name]
        need(len(rows) == 1 and rows[0]['status'] == 'completed' and rows[0]['conclusion'] == 'success',
             'Original resulting-source gate did not pass: ' + name)
        admitted[name] = rows[0]['id']
    return admitted


def admit(app: Path, output: Path):
    request = read_request()
    need(git(app, 'rev-parse', 'HEAD') == request['application_commit']
         and git(app, 'rev-parse', 'HEAD^{tree}') == request['application_tree']
         and not git(app, 'status', '--porcelain', '--untracked-files=no'), 'Application checkout differs')
    headers = {'Authorization': 'Bearer ' + os.environ['GH_TOKEN'], 'Accept': 'application/vnd.github+json',
               'X-GitHub-Api-Version': '2022-11-28'}
    def api(path):
        req = urllib.request.Request('https://api.github.com/repos/techrote/cybersand/' + path, headers=headers)
        with urllib.request.urlopen(req, timeout=60) as response:
            raw = response.read(4 * 1024 * 1024 + 1)
        need(len(raw) <= 4 * 1024 * 1024, 'Oversized metadata response')
        return json.loads(raw)
    run = api('actions/runs/' + str(request['run_id']))
    artifact = api('actions/artifacts/' + str(request['artifact_id']))
    jobs = api('actions/runs/' + str(request['run_id']) + '/attempts/' + str(request['run_attempt']) + '/jobs?per_page=100')
    admitted = validate_metadata(request, run, artifact, jobs)
    record = {'schema': 'pubpres-independent-extraction-admission-v1', 'request': request,
              'application_commit': request['application_commit'], 'application_tree': request['application_tree'],
              'driver_commit': git(ROOT, 'rev-parse', 'HEAD'), 'driver_tree': git(ROOT, 'rev-parse', 'HEAD^{tree}'),
              'original_gates': admitted, 'artifact_metadata': artifact,
              'original_run_conclusion': run['conclusion'], 'extracted_execution_status': 'not yet executed'}
    output.write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')


def archive_admission(folder: Path):
    request = read_request()
    archives = list(folder.glob('*.zip'))
    need(len(archives) == 1, 'Missing or ambiguous delivered inner ZIP')
    archive = archives[0]
    with archive.open('rb') as stream:
        actual = hashlib.file_digest(stream, 'sha256').hexdigest()
    need(actual == request['inner_sha256'] and archive.stat().st_size == request['inner_bytes'], 'Inner ZIP differs')
    with zipfile.ZipFile(archive) as bundle:
        raw = bundle.read('PUBPRES-MAINLINE-EVALUATOR.json')
    need(hashlib.sha256(raw).hexdigest() == request['manifest_sha256'], 'Package manifest differs')
    manifest = json.loads(raw)
    need(manifest['source_commit'] == request['application_commit']
         and manifest['source_tree'] == request['application_tree']
         and manifest['physical_owner_evaluated'] is False and manifest['merge_authorized'] is False,
         'Archive source or disposition differs')
    with open(os.environ['GITHUB_ENV'], 'a', encoding='utf-8') as stream:
        stream.write('INDEPENDENT_INNER_ARCHIVE=' + str(archive.resolve()) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('metadata', 'archive'))
    parser.add_argument('--app', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--folder', type=Path)
    args = parser.parse_args()
    if args.mode == 'metadata':
        admit(args.app.resolve(), args.output.resolve())
    else:
        archive_admission(args.folder.resolve())


if __name__ == '__main__':
    main()
