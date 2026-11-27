"""Read two original final-source shards from the published Linux evidence ZIP.

Usage: python review_blocked_route_timing.py /path/to/artifact.zip /path/to/receipt.json
This performs no physical execution and does not load the aggregate episode file.
"""
from pathlib import Path
import hashlib
import json
import sys
import zipfile

SOURCE = 'a7250e15495667b2fcf564cbed1eaa8dea217c45'
OUTER_SHA = 'eac23768f3b18dc95a35554328f700daa8a81fa9920bab39fa7148aca1958e30'
archive_path, output_path = map(Path, sys.argv[1:])
checks = []


def check(condition, label):
    if not condition:
        raise AssertionError(label)
    checks.append(label)


def sha(data):
    return hashlib.sha256(data).hexdigest()


check(sha(archive_path.read_bytes()) == OUTER_SHA, 'original published Linux artifact SHA256')
results = []
with zipfile.ZipFile(archive_path) as archive:
    custody_hash = sha(archive.read('episodes-full/custody.json'))
    for seed in (605, 1701):
        case_id = f'adverse-blocked_route-runner-s{seed}-t30-n1-stateful'
        prefix = f'episodes-full/shards/{case_id}/attempt-001/'
        report_bytes = archive.read(prefix + 'report.json')
        report = json.loads(report_bytes)
        console_bytes = archive.read(prefix + 'console.log')
        execution_bytes = archive.read(prefix + 'execution.json')
        execution = json.loads(execution_bytes)
        check(execution['returncode'] == 0 and execution['source_revision'] == SOURCE, case_id + ': original successful source-bound execution')
        check(execution['report_sha256'] == sha(report_bytes) and execution['console_sha256'] == sha(console_bytes) and execution['custody_sha256'] == custody_hash, case_id + ': report, console and original full-custody hashes')
        check(report['complete'] and not report['failures'] and len(report['campaigns']) == 1 and report['source_identity']['source_revision'] == SOURCE, case_id + ': complete original report')
        terminal = [line[len('AMBIENT2_EPISODES '):] for line in console_bytes.decode().splitlines() if line.startswith('AMBIENT2_EPISODES ')]
        check(len(terminal) == 1, case_id + ': exactly one completion terminal')
        terminal = json.loads(terminal[0])
        check(terminal['complete'] and not terminal['failures'] and terminal['case_id'] == case_id and terminal['source_revision'] == SOURCE and terminal['checks'] == report['checks'] == 7513, case_id + ': terminal/report agreement')
        campaign = report['campaigns'][0]
        check(campaign['id'] == case_id and campaign['native_ticks'] == campaign['physical_ticks'] == 1800 and len(campaign['episodes']) == 1, case_id + ': exact original physical case')
        intervention = campaign['events']
        check(len(intervention) == 1 and intervention[0]['kind'] == 'block_familiar_route_with_native_stone' and intervention[0]['tick'] == 900, case_id + ': actual recorded intervention at tick900')
        episode = campaign['episodes'][0]
        memory = episode['final_memory']
        check(memory['enabled'] and memory['available'] and memory['failure_events'] == 5 and memory['forgotten'] == 0 and memory['evictions'] == 0 and len(memory['obstructions']) == 1, case_id + ': five retained failure events without forgetting or eviction')
        obstruction = memory['obstructions'][0]
        check(obstruction['attempts'] == 5 and abs(obstruction['last_seen'] - 12.6) < 1e-9, case_id + ': all five recorded failures precede15s wall')
        trace = episode['trace']
        check(len(trace) == 300 and all(abs(row['seconds'] - i/10) < 1e-9 for i, row in enumerate(trace)), case_id + ': exact300-sample10Hz trace')
        selected = [i for i, row in enumerate(trace) if row['selection'] == 'withdraw_obstruction']
        check(len(selected) == 91, case_id + ':9.1selected withdrawal seconds')
        runs = []
        for i in selected:
            if runs and runs[-1][1] == i:
                runs[-1][1] = i+1
            else:
                runs.append([i,i+1])
        windows = [[a/10,b/10] for a,b in runs]
        results.append({'case_id':case_id,'seed':seed,'report_sha256':sha(report_bytes),'execution_sha256':sha(execution_bytes),'console_sha256':sha(console_bytes),'intervention_tick':900,'intervention_seconds':15.0,'retained_failure_events':memory['failure_events'],'retained_obstruction':obstruction,'selected_withdrawal_windows_seconds':windows,'withdrawal_seconds':len(selected)/10,'withdrawal_before_intervention_seconds':sum(i<150 for i in selected)/10,'withdrawal_after_intervention_seconds':sum(i>=150 for i in selected)/10})

receipt = {'pass':True,'checks':len(checks),'check_descriptions':checks,'frozen_application_source':SOURCE,'original_artifact_id':14990266435,'original_artifact_sha256':OUTER_SHA,'reviewer_source_sha256':sha(Path(__file__).read_bytes()),'original_full_custody_sha256':custody_hash,'cases':results,'interpretation':'Both final-source stateful blocked-route episodes retained five failures last recorded at12.6s, before the15s native wall intervention. Selected withdrawals after15s reuse this earlier record. The matched memory ablation demonstrates utility of memory in the changing fixture; it does not demonstrate learning the newly painted wall.','scope':'Independent original-data readback only. Two already-counted primary case identities; no new physical execution or episode count. Samples define half-open0.1s selected-intention intervals; primary traces do not identify individual failure-event timestamps or goal instances.'}
output_path.parent.mkdir(parents=True,exist_ok=True)
output_path.write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({'pass':True,'checks':len(checks),'cases':results},indent=2))
