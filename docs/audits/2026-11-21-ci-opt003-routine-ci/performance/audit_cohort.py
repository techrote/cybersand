#!/usr/bin/env python3
"""Summarize complete terminal GitHub job snapshots without equating skips with tests."""
import argparse
import datetime as dt
import json
from pathlib import Path

def instant(text):
    return dt.datetime.fromisoformat(text.replace('Z','+00:00'))

def summary(run, jobs, expected_attempt=1):
    assert type(expected_attempt) is int and expected_attempt > 0
    assert run['run_attempt'] == expected_attempt
    assert run['status'] == 'completed' and run['conclusion'] == 'success', run['id']
    assert len(jobs['jobs']) == jobs['total_count'], 'Pagination incomplete'
    rows = jobs['jobs']
    assert all(j['run_id'] == run['id'] and j['run_attempt'] == expected_attempt
               and j['head_sha'] == run['head_sha'] for j in rows), 'Job source/run/attempt differs'
    assert all(j['status'] == 'completed' for j in rows)
    assert all(j['conclusion'] in ('success','skipped') for j in rows)
    executed = [j for j in rows if j['conclusion'] == 'success']
    assert executed
    event = instant(run['created_at'])
    start = min(instant(j['started_at']) for j in executed)
    end = max(instant(j['completed_at']) for j in executed)
    jobs_out = []
    for job in executed:
        js,je = instant(job['started_at']),instant(job['completed_at'])
        assert je >= js
        jobs_out.append({'id':job['id'],'name':job['name'],'started_at':job['started_at'],
                         'completed_at':job['completed_at'],'runner_seconds':(je-js).total_seconds(),
                         'event_to_completion_seconds':(je-event).total_seconds(),
                         'runner_name':job['runner_name'],'labels':job['labels'],
                         'steps':[{'name':s['name'],'conclusion':s['conclusion'],
                                   'elapsed_seconds':(instant(s['completed_at'])-instant(s['started_at'])).total_seconds()
                                   if s.get('started_at') and s.get('completed_at') else None}
                                  for s in job['steps']]})
    functional = [j for j in executed if j['name'].startswith('Native family / ')]
    return {'run_id':run['id'],'run_attempt':run['run_attempt'],'source_sha':run['head_sha'],
            'name':run['name'],'event':run['event'],'branch':run['head_branch'],'url':run['html_url'],
            'event_at':run['created_at'],'first_job_at':start.isoformat(),'last_job_at':end.isoformat(),
            'initial_queue_seconds':(start-event).total_seconds() if expected_attempt == 1 else None,
            'event_to_first_job_seconds':(start-event).total_seconds(),
            'attempt_started_at':run.get('run_started_at'),
            'attempt_to_last_job_seconds':(end-instant(run['run_started_at'])).total_seconds() if run.get('run_started_at') else None,
            'event_to_last_job_seconds':(end-event).total_seconds(),
            'runner_minutes':sum(j['runner_seconds'] for j in jobs_out)/60,
            'first_complete_native_functional_seconds':min((instant(j['completed_at'])-event).total_seconds() for j in functional) if functional else None,
            'executed_job_count':len(executed),'conditional_skips':[{'id':j['id'],'name':j['name']} for j in rows if j['conclusion']=='skipped'],
            'jobs':jobs_out}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('directory',type=Path)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--expected-attempt',action='append',default=[],metavar='RUN_ID=ATTEMPT',
                   help='Explicitly admit a selected successful retry; default is attempt1 only.')
    p.add_argument('--prior-attempt-jobs',action='append',default=[],type=Path,
                   help='Original terminal job snapshot for a prior failed attempt; adds its real runner cost.')
    a=p.parse_args()
    runs=json.loads((a.directory/'runs.json').read_text())['workflow_runs']
    expected={}
    for value in a.expected_attempt:
        identity, attempt=map(int,value.split('='))
        assert identity not in expected and attempt > 1
        expected[identity]=attempt
    assert set(expected).issubset({r['id'] for r in runs})
    out=[summary(run,json.loads((a.directory/f"jobs-{run['id']}.json").read_text()),expected.get(run['id'],1)) for run in runs]
    assert len({x['source_sha'] for x in out})==1
    started=min(instant(x['event_at']) for x in out)
    ended=max(instant(x['last_job_at']) for x in out)
    validation_jobs=[(workflow,job) for workflow in out
                     if workflow['name'] != 'Native source-scope advisory (report only)'
                     for job in workflow['jobs']
                     if job['name'] != 'retained execution and physical timing history']
    validation_workflow,validation_job=max(validation_jobs,key=lambda pair:instant(pair[1]['completed_at']))
    validation_end=instant(validation_job['completed_at'])
    prior=[]
    seen=set()
    current={run['id']:run for run in runs}
    for path in a.prior_attempt_jobs:
        data=json.loads(path.read_text())
        assert len(data['jobs']) == data['total_count'] and data['jobs'], 'Prior attempt pagination incomplete'
        rows=data['jobs']; identity={(j['run_id'],j['run_attempt'],j['head_sha']) for j in rows}
        assert len(identity) == 1
        run_id,attempt,sha=identity.pop()
        assert run_id in current and sha == current[run_id]['head_sha'] and attempt < current[run_id]['run_attempt']
        assert (run_id,attempt) not in seen
        seen.add((run_id,attempt))
        assert all(j['status'] == 'completed' for j in rows)
        assert any(j['conclusion'] not in ('success','skipped') for j in rows), 'Prior attempt was not failed/interrupted'
        executed=[j for j in rows if j.get('runner_name') and j['conclusion'] != 'skipped']
        seconds_sum=0
        for job in executed:
            span=(instant(job['completed_at'])-instant(job['started_at'])).total_seconds()
            assert span >= 0
            seconds_sum+=span
        prior.append({'run_id':run_id,'run_attempt':attempt,'source_sha':sha,'original_job_snapshot':str(path),
                      'runner_minutes':seconds_sum/60,'executed_jobs':len(executed),
                      'conclusions':{kind:sum(j['conclusion']==kind for j in rows) for kind in sorted({j['conclusion'] for j in rows})}})
    assert seen == {(identity,attempt) for identity,latest in expected.items() for attempt in range(1,latest)}, 'Earlier retry cost is missing'
    latest_minutes=sum(x['runner_minutes'] for x in out)
    prior_minutes=sum(x['runner_minutes'] for x in prior)
    latest_count=sum(x['executed_job_count'] for x in out)
    result={'schema':'ci-opt003-independent-cohort-audit-v2','source_sha':out[0]['source_sha'],
            'event_to_last_applicable_job_seconds':(ended-started).total_seconds(),
            'event_to_last_nonadvisory_validation_job_seconds':(validation_end-started).total_seconds(),
            'last_nonadvisory_validation_job':{'id':validation_job['id'],'name':validation_job['name'],
                                               'run_id':validation_workflow['run_id'],
                                               'run_attempt':validation_workflow['run_attempt'],
                                               'completed_at':validation_job['completed_at']},
            'runner_minutes':latest_minutes+prior_minutes,'latest_attempt_runner_minutes':latest_minutes,
            'prior_failed_attempt_runner_minutes':prior_minutes,
            'executed_jobs':latest_count,'executed_jobs_including_prior_failed_attempts':latest_count+sum(x['executed_jobs'] for x in prior),
            'workflows':out,'prior_failed_attempts':prior,
            'limits':['Unweighted runner-minutes, not billed minutes.','Applicable workflow scope explicitly retained; compare identical scopes for speed claims.','Conditional skips counted separately from executed jobs.','Event time includes retry delay; successful retry window is separate.','Runner consumption includes every supplied prior failed attempt; qualified job count is latest successful attempts only.','Non-advisory validation excludes only the explicitly report-only source workflow and retained timing-history job; this does not infer GitHub branch-protection configuration.']}
    a.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='workflows'},indent=2))

if __name__=='__main__':main()
