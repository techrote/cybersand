"""Opt-in SDK build ownership and evidence, isolated from ordinary/gameplay CI.

The Windows API backend is used only on the hosted x64 Windows diagnostic.
Portable tests exercise the deadline reducer separately; they are not OS proof.
"""
from __future__ import annotations

import ctypes as C
import hashlib
import json
import math
import os
from pathlib import Path
import ntpath
import re
import subprocess
import sys
import time
from windows_crash_contract import read_json
from windows_crash_policy import CLEANUP_SECONDS, OPERATION_SECONDS

SCHEMA = 'play-owned-build-v2'
MAX_PROCESSES = 32
POLL_SECONDS = .1


def sample_limit(timeout):
    """Storage headroom must not become an earlier execution watchdog."""
    need(type(timeout) in (int,float) and math.isfinite(timeout)
         and 0 < timeout <= OPERATION_SECONDS, 'Invalid owned operation watchdog')
    return math.ceil(timeout / POLL_SECONDS) + 4


MAX_SAMPLES = math.ceil(OPERATION_SECONDS / POLL_SECONDS) + 4


def need(value, reason):
    if not value:
        raise ValueError(reason)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_new(path, value):
    with path.open('xb') as stream:
        stream.write((json.dumps(value, indent=2, sort_keys=True) + '\n').encode('utf-8'))
        stream.flush()
        os.fsync(stream.fileno())


D, B, W, P, U, Q, L = C.c_uint32, C.c_int32, C.c_uint16, C.c_void_p, C.c_size_t, C.c_uint64, C.c_int64


class Security(C.Structure):
    _fields_ = [('size', D), ('descriptor', P), ('inherit', B)]


class Startup(C.Structure):
    _fields_ = [('cb', D), ('reserved', P), ('desktop', P), ('title', P),
                ('x', D), ('y', D), ('xs', D), ('ys', D), ('xc', D), ('yc', D),
                ('fill', D), ('flags', D), ('show', W), ('reserved_size', W),
                ('reserved_bytes', P), ('stdin', P), ('stdout', P), ('stderr', P)]


class StartupEx(C.Structure):
    _fields_ = [('startup', Startup), ('attributes', P)]


class ProcessInfo(C.Structure):
    _fields_ = [('process', P), ('thread', P), ('pid', D), ('tid', D)]


class Limits(C.Structure):
    _fields_ = [('process_time', L), ('job_time', L), ('flags', D),
                ('minimum_working_set', U), ('maximum_working_set', U),
                ('active_process_limit', D), ('affinity', U), ('priority', D), ('scheduling', D)]


class ExtendedLimits(C.Structure):
    _fields_ = [('basic', Limits), ('io_counters', Q * 6), ('process_memory', U),
                ('job_memory', U), ('peak_process_memory', U), ('peak_job_memory', U)]


class Accounting(C.Structure):
    _fields_ = [('user', L), ('kernel', L), ('period_user', L), ('period_kernel', L),
                ('page_faults', D), ('total', D), ('active', D), ('terminated', D)]


class ProcessIds(C.Structure):
    _fields_ = [('assigned', D), ('count', D), ('pids', U * MAX_PROCESSES)]


class FileTime(C.Structure):
    _fields_ = [('low', D), ('high', D)]


class WindowsJob:
    """Create the target in an owned job, join it and retain observed exits."""
    def __init__(self):
        need(sys.platform == 'win32' and C.sizeof(P) == 8, 'Actual x64 Windows required')
        need((C.sizeof(StartupEx), C.sizeof(ExtendedLimits), C.sizeof(Accounting)) == (112,144,48), 'Windows SDK structure layout')
        self.api = C.WinDLL('kernel32', use_last_error=True)
        specs = {
            'CreateJobObjectW': ([P,C.c_wchar_p], P), 'SetInformationJobObject': ([P,D,P,D],B),
            'QueryInformationJobObject': ([P,D,P,D,P],B), 'TerminateJobObject': ([P,D],B),
            'InitializeProcThreadAttributeList': ([P,D,D,C.POINTER(U)],B),
            'UpdateProcThreadAttribute': ([P,D,U,P,U,P,P],B), 'DeleteProcThreadAttributeList': ([P],None),
            'CreateFileW': ([C.c_wchar_p,D,D,P,D,D,P],P),
            'CreateProcessW': ([C.c_wchar_p,P,P,P,B,D,P,C.c_wchar_p,P,C.POINTER(ProcessInfo)],B),
            'ResumeThread': ([P],D), 'WaitForSingleObject': ([P,D],D),
            'GetExitCodeProcess': ([P,C.POINTER(D)],B), 'CloseHandle': ([P],B),
            'OpenProcess': ([D,B,D],P), 'QueryFullProcessImageNameW': ([P,D,P,C.POINTER(D)],B),
            'GetProcessTimes': ([P,P,P,P,P],B),
        }
        for name,(arguments,result) in specs.items():
            function = getattr(self.api,name)
            function.argtypes, function.restype = arguments,result
        self.job = None
        self.handles, self.finished, self.images = {},{},{}
        self.root_pid = None
        self.creation_job_assigned = False
        self.log = None
        self.thread = self.output = self.input = None
        self.attributes = None
        self.attribute_ready = False

    def start(self, command, cwd, environment, log):
        self.log = log
        try:
            self.job = self.api.CreateJobObjectW(None,None)
            self.check(self.job,'CreateJobObjectW')
            limits = ExtendedLimits()
            limits.basic.flags = 0x2000 | 0x8  # KILL_ON_JOB_CLOSE and ACTIVE_PROCESS.
            limits.basic.active_process_limit = MAX_PROCESSES
            self.check(self.api.SetInformationJobObject(self.job,9,C.byref(limits),C.sizeof(limits)), 'SetInformationJobObject')
            security = Security(C.sizeof(Security),None,True)
            self.output = self.api.CreateFileW(str(log),0x40000000,1,C.byref(security),1,0x80,None)
            self.input = self.api.CreateFileW('NUL',0x80000000,3,C.byref(security),3,0x80,None)
            self.check(self.output and self.output != C.c_void_p(-1).value and self.input and self.input != C.c_void_p(-1).value,'CreateFileW')
            size = U()
            self.api.InitializeProcThreadAttributeList(None,2,0,C.byref(size))
            self.attributes = C.create_string_buffer(size.value)
            self.check(self.api.InitializeProcThreadAttributeList(self.attributes,2,0,C.byref(size)), 'InitializeProcThreadAttributeList')
            self.attribute_ready = True
            job_list, handle_list = (P * 1)(self.job), (P * 2)(self.input,self.output)
            self.check(self.api.UpdateProcThreadAttribute(self.attributes,0,0x2000D,job_list,C.sizeof(job_list),None,None), 'Creation-time JOB_LIST')
            self.check(self.api.UpdateProcThreadAttribute(self.attributes,0,0x20002,handle_list,C.sizeof(handle_list),None,None), 'Inherited HANDLE_LIST')
            startup = StartupEx()
            startup.startup.cb = C.sizeof(startup)
            startup.startup.flags = 0x100
            startup.startup.stdin, startup.startup.stdout, startup.startup.stderr = self.input,self.output,self.output
            startup.attributes = C.cast(self.attributes,P)
            info = ProcessInfo()
            line = subprocess.list2cmdline(command)
            need(len(line) < 32767, 'Windows command line is too long')
            for name,value in environment.items():
                need(name and ('=' not in name or re.fullmatch(r'=[A-Za-z]:',name))
                     and '\0' not in name + value, 'Invalid sanitized environment')
            block = '\0'.join(name+'='+environment[name] for name in sorted(environment,key=str.upper))+'\0\0'
            command_buffer, environment_buffer = C.create_unicode_buffer(line),C.create_unicode_buffer(block)
            flags = 0x8 | 0x4 | 0x80000 | 0x400  # DETACHED_PROCESS, SUSPENDED, EXTENDED_STARTUPINFO, UNICODE_ENVIRONMENT.
            self.check(self.api.CreateProcessW(command[0],command_buffer,None,None,True,flags,
                environment_buffer,str(cwd),C.byref(startup),C.byref(info)), 'CreateProcessW')
            self.root_pid, self.thread = info.pid,info.thread
            self.handles[info.pid] = info.process
            self.creation_job_assigned = True
            self.check(self.api.ResumeThread(self.thread) != 0xffffffff, 'ResumeThread')
            self.api.CloseHandle(self.thread)
            self.thread = None
        finally:
            if self.attribute_ready:
                self.api.DeleteProcThreadAttributeList(self.attributes)
                self.attribute_ready = False
            for name in ('input','output'):
                handle = getattr(self,name)
                if handle and handle != C.c_void_p(-1).value:
                    self.api.CloseHandle(handle)
                setattr(self,name,None)

    @staticmethod
    def check(value, operation):
        if not value:
            raise OSError(C.get_last_error(),operation)

    def snapshot(self):
        ids = ProcessIds()
        self.check(self.api.QueryInformationJobObject(self.job,3,C.byref(ids),C.sizeof(ids),None), 'Job process inventory')
        need(ids.assigned == ids.count and ids.count <= MAX_PROCESSES, 'Incomplete job process inventory')
        for pid in ids.pids[:ids.count]:
            if pid not in self.handles and pid not in self.finished:
                handle = self.api.OpenProcess(0x1000 | 0x100000,False,pid)
                # An already-exited short-lived process can vanish between the
                # job query and OpenProcess. Job accounting still covers it.
                if handle:
                    self.handles[pid] = handle
        active = []
        for pid,handle in list(self.handles.items()):
            if pid not in self.images:
                image, size = C.create_unicode_buffer(32768),D(32768)
                self.check(self.api.QueryFullProcessImageNameW(handle,0,image,C.byref(size)), 'Process image')
                need(0 < size.value < 32768, 'Truncated process image')
                self.images[pid] = image.value
            created, exited, kernel, user = FileTime(),FileTime(),FileTime(),FileTime()
            self.check(self.api.GetProcessTimes(handle,C.byref(created),C.byref(exited),C.byref(kernel),C.byref(user)), 'GetProcessTimes')
            row = {'pid':pid,'image':self.images[pid], 'created_100ns':(created.high << 32) | created.low,
                   'user_100ns':(user.high << 32) | user.low,
                   'kernel_100ns':(kernel.high << 32) | kernel.low}
            waited = self.api.WaitForSingleObject(handle,0)
            need(waited in (0,258), 'Process wait failed')
            if waited == 0:
                code = D()
                self.check(self.api.GetExitCodeProcess(handle,C.byref(code)), 'GetExitCodeProcess')
                self.finished[pid] = row | {'exit_code':code.value,'exit_observed':True}
                self.api.CloseHandle(handle)
                del self.handles[pid]
            else:
                active.append(row)
        # Release signaled process handles before the final accounting query.
        accounting = Accounting()
        self.check(self.api.QueryInformationJobObject(self.job,1,C.byref(accounting),C.sizeof(accounting),None), 'Job accounting')
        need(1 <= accounting.total <= MAX_PROCESSES, 'Bounded job population')
        return {'root_pid':self.root_pid,'active_processes':accounting.active,'total_processes':accounting.total,
                'job_user_100ns':accounting.user,'job_kernel_100ns':accounting.kernel,
                'active_observed':active,'exited_observed':list(self.finished.values()),
                'job_empty':accounting.active == 0 and not self.handles,
                'log_bytes':self.log.stat().st_size}

    def terminate(self, code):
        self.check(self.api.TerminateJobObject(self.job,code), 'TerminateJobObject')

    def close(self):
        if self.job:
            self.api.CloseHandle(self.job)  # Last-resort kill; never claimed as an observed join.
            self.job = None
        if self.thread:
            self.api.CloseHandle(self.thread)
            self.thread = None
        for handle in self.handles.values():
            self.api.CloseHandle(handle)
        self.handles.clear()


def monitor(job, started, timeout, emit, *, clock=time.perf_counter, pause=time.sleep):
    """Bounded deadline reducer; the OS backend supplies all process facts."""
    maximum_samples = sample_limit(timeout)
    reserve = min(CLEANUP_SECONDS,timeout / 4)
    deadline, work_end = started + timeout, started + timeout - reserve
    samples, timed_out, terminated, joined, error = [],False,False,False,None
    termination_started = None
    try:
        while len(samples) < maximum_samples:
            now = clock()
            if now >= deadline:
                break
            row = job.snapshot() | {'seconds':clock()-started}
            samples.append(row)
            emit(row)
            if row['job_empty']:
                joined = True
                break
            now = clock()
            if not terminated and now >= work_end:
                timed_out = True
                termination_started = clock()-started
                job.terminate(124)
                terminated = True
            remaining = deadline-clock()
            if remaining > 0:
                pause(min(POLL_SECONDS,remaining))
        if not joined and not terminated:
            termination_started = clock()-started
            job.terminate(124)
            terminated = True
            timed_out = True
    except (OSError,ValueError) as failure:
        error = str(failure)
        if not terminated:
            try:
                termination_started = clock()-started
                job.terminate(74)
                terminated = True
            except OSError as cleanup:
                error += '; cleanup: ' + str(cleanup)
        while not joined and clock() < deadline and len(samples) < maximum_samples:
            try:
                row = job.snapshot() | {'seconds':clock()-started}
                samples.append(row)
                emit(row)
                joined = row['job_empty']
                remaining = deadline-clock()
                if not joined and remaining > 0:
                    pause(min(POLL_SECONDS,remaining))
            except (OSError,ValueError) as cleanup:
                error += '; join observation: ' + str(cleanup)
                break
    elapsed = clock()-started
    last = samples[-1] if samples else {}
    root = next((r for r in last.get('exited_observed',[]) if r['pid'] == job.root_pid),None)
    observed_exits_passed = all(r['exit_code'] == 0 for r in last.get('exited_observed',[]))
    return {'status':'passed' if joined and not timed_out and error is None and elapsed <= timeout and root and root['exit_code'] == 0 and observed_exits_passed else 'failed',
            'timeout_seconds':timeout,'cleanup_reserve_seconds':reserve,'seconds':elapsed,
            'root_pid':job.root_pid,'root_exit':root['exit_code'] if root else None,
            'job_joined':joined,'termination_requested':terminated,'timed_out':timed_out,
            'termination_started_seconds':termination_started,
            'error':error,'samples':samples,'creation_job_assigned':job.creation_job_assigned}


def run(command, cwd, environment, directory, identity, *, timeout=OPERATION_SECONDS, backend=WindowsJob):
    sample_limit(timeout)
    directory.mkdir(exist_ok=False)
    started = time.perf_counter()
    launch = {'schema':SCHEMA,'command':command,'cwd':str(cwd),'timeout_seconds':timeout,'identity':identity}
    write_new(directory/'launch.json',launch)
    job = None
    try:
        job = backend()
        job.start(command,cwd,environment,directory/'process.log')
        with (directory/'samples.jsonl').open('x',encoding='utf-8',newline='\n') as stream:
            def emit(row):
                stream.write(json.dumps(row,sort_keys=True)+'\n')
                stream.flush()
            result = monitor(job,started,timeout,emit)
    except (OSError,ValueError) as error:
        result = {'status':'failed','seconds':time.perf_counter()-started,'timeout_seconds':timeout,
                  'error':str(error),'job_joined':False,'root_pid':getattr(job,'root_pid',None),
                  'root_exit':None,'creation_job_assigned':False,'samples':[],
                  'termination_requested':False,'termination_started_seconds':None,
                  'timed_out':False,'cleanup_reserve_seconds':min(CLEANUP_SECONDS,timeout/4)}
        if job is not None and job.root_pid is not None:
            try:
                job.terminate(74)
                with (directory/'samples.jsonl').open('x',encoding='utf-8',newline='\n') as stream:
                    def emit(row):
                        stream.write(json.dumps(row,sort_keys=True)+'\n')
                        stream.flush()
                    cleanup = monitor(job,started,timeout,emit)
                result.update(cleanup,status='failed',error=str(error),termination_requested=True)
            except (OSError,ValueError) as cleanup_error:
                result['error'] += '; cleanup: ' + str(cleanup_error)
    finally:
        if job is not None:
            job.close()
    result['seconds'] = time.perf_counter()-started
    if result['seconds'] > timeout:
        result.update(status='failed',error=result['error'] or 'Owned build operation exceeded its original deadline')
    result['schema'] = SCHEMA
    result['launch_sha256'] = digest(directory/'launch.json')
    result['log_sha256'] = digest(directory/'process.log') if (directory/'process.log').exists() else None
    write_new(directory/'result.json',result)
    return result


def verify(directory, command, identity, *, cwd):
    """Reconcile retained command identity, original samples and observed exit."""
    launch = read_json(directory/'launch.json')
    result = read_json(directory/'result.json')
    need(launch['schema'] == result['schema'] == SCHEMA and launch['command'] == command and launch['identity'] == identity, 'Owned build launch identity')
    need(ntpath.normcase(ntpath.normpath(launch['cwd'])) == ntpath.normcase(ntpath.normpath(cwd)), 'Owned build working directory')
    need(result['launch_sha256'] == digest(directory/'launch.json') and result['log_sha256'] == digest(directory/'process.log'), 'Owned build original digest')
    samples = [json.loads(line) for line in (directory/'samples.jsonl').read_text().splitlines()]
    need(samples == result['samples'] and 1 <= len(samples) <= sample_limit(result['timeout_seconds']), 'Owned build sample inventory')
    need(launch['timeout_seconds'] == result['timeout_seconds'] and 0 <= result['seconds'] <= result['timeout_seconds'], 'Owned build operation deadline')
    need(result['creation_job_assigned'] is True and result['job_joined'] is True and result['error'] is None, 'Owned build ownership/cleanup incomplete')
    previous = (-1,0,0,0,0)
    exited, images, creation_times = {},{},{}
    for row in samples:
        current = (row['seconds'],row['total_processes'],row['job_user_100ns'],row['job_kernel_100ns'],row['log_bytes'])
        need(all(a <= b for a,b in zip(previous,current)) and 0 <= current[0] <= result['seconds'], 'Owned build progress regressed')
        previous = current
        need(row['root_pid'] == result['root_pid'] and 0 <= row['active_processes'] <= row['total_processes'] <= MAX_PROCESSES and row['total_processes'] >= 1, 'Owned build process accounting')
        for process in row['active_observed'] + row['exited_observed']:
            pid = process['pid']
            need(pid > 0 and (pid not in images or images[pid] == process['image']), 'Owned build process identity changed')
            need(process['created_100ns'] > 0 and (pid not in creation_times or creation_times[pid] == process['created_100ns']), 'Owned build PID creation identity changed')
            need(process['user_100ns'] >= 0 and process['kernel_100ns'] >= 0, 'Invalid process CPU time')
            images[pid] = process['image']
            creation_times[pid] = process['created_100ns']
        for process in row['exited_observed']:
            need(process['exit_observed'] is True and (process['pid'] not in exited or exited[process['pid']] == process), 'Owned build observed exit changed')
            exited[process['pid']] = process
        need(all(r['pid'] not in exited for r in row['active_observed']), 'Owned build exited process became active')
    last = samples[-1]
    need(last['job_empty'] is True and last['active_processes'] == 0 and not last['active_observed'], 'Owned build missing final job join')
    need(result['root_pid'] in exited and result['root_exit'] == exited[result['root_pid']]['exit_code'], 'Owned build root exit mismatch')
    need(ntpath.normcase(ntpath.normpath(images[result['root_pid']])) == ntpath.normcase(ntpath.normpath(command[0])), 'Owned build actual executable differs')
    need(result['cleanup_reserve_seconds'] == min(CLEANUP_SECONDS,result['timeout_seconds']/4), 'Owned build cleanup reserve changed')
    if result['timed_out']:
        need(result['termination_requested'] is True and result['termination_started_seconds'] is not None
             and result['timeout_seconds']-result['cleanup_reserve_seconds'] <= result['termination_started_seconds'] <= result['seconds'], 'Owned build timeout/termination ordering')
    else:
        need(result['termination_requested'] is False and result['termination_started_seconds'] is None, 'Unexpected build termination')
    passed = result['root_exit'] == 0 and all(r['exit_code'] == 0 for r in exited.values()) and not result['timed_out'] and not result['termination_requested']
    need(result['status'] == ('passed' if passed else 'failed'), 'Owned build false pass')
    return result
