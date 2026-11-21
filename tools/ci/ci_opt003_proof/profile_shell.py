#!/usr/bin/env python3
"""Proof-only transparent compiler/shell timing; never reuses compilation/results."""
from __future__ import annotations
import hashlib,json,os,resource,signal,subprocess,sys,time,uuid
from pathlib import Path


def write(path, value):
    temp=path.with_suffix('.tmp')
    temp.write_text(json.dumps(value,sort_keys=True,indent=2)+'\n',encoding='utf-8')
    temp.replace(path)


def main():
    kind='shell' if Path(sys.argv[0]).name=='profile_shell.py' else 'compiler'
    program='/bin/sh' if kind=='shell' else os.environ['CI_OPT003_CXX']
    log=Path(os.environ['CI_OPT003_PROFILE_DIR'])
    log.mkdir(parents=True,exist_ok=True)
    identity=uuid.uuid4().hex
    record=log/(identity+'.json')
    started=time.time_ns(); mono=time.monotonic_ns()
    data={'schema':'cybersand-ci-opt003-command-v1','id':identity,'kind':kind,
          'cwd':os.getcwd(),'argv':[program,*sys.argv[1:]],'pid':os.getpid(),
          'start_time_ns':started,'status':'started'}
    write(record,data)
    process=None; received=[]
    def forward(sig,frame):
        received.append(sig)
        if process is not None and process.poll() is None:
            process.send_signal(sig)
    for sig in (signal.SIGINT,signal.SIGTERM,signal.SIGHUP):
        signal.signal(sig,forward)
    try:
        process=subprocess.Popen(data['argv'])
        result=process.wait()
        if received and result==0:
            result=-received[0]
        data.update(status='passed' if result==0 else 'failed',returncode=result)
    except BaseException as error:
        data.update(status='failed',returncode=125,error=repr(error))
        result=125
        if process is not None and process.poll() is None:
            process.terminate()
            try: process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill();process.wait()
    finally:
        use=resource.getrusage(resource.RUSAGE_CHILDREN)
        data.update(end_time_ns=time.time_ns(),elapsed_seconds=(time.monotonic_ns()-mono)/1e9,
                    child_user_seconds=use.ru_utime,child_system_seconds=use.ru_stime,
                    max_child_rss_kib=use.ru_maxrss,signals=received)
        write(record,data)
    if result<0:
        signal.signal(-result,signal.SIG_DFL)
        os.kill(os.getpid(),-result)
    return result

if __name__=='__main__':
    raise SystemExit(main())
