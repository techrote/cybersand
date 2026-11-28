#!/usr/bin/env python3
"""External first-command qualification of one immutable Strata003 Windows ZIP.

The shipped CMD is the first Godot invocation after a fresh extraction. Static
payload verification may precede it; no editor, harness, import or cache setup
may. The original application and package bytes are never rewritten.
"""
from __future__ import annotations
import argparse
import ctypes
import hashlib
import importlib.util
import json
import math
import ntpath
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
APPLICATION = 'fd0830abcfadd9ae19162e5677943bb131223e59'
TREE = 'fd4dc12d6bfd3e13d6b4d26eede8a1171ca1b499'
REPOSITORY = 'techrote/cybersand'
REQUEST = 'tools/ci/strata3-cold-launch-request.json'
SCRIPT = 'tools/ci/strata3_cold_launcher.py'
FILES = (SCRIPT, 'tools/ci/test_strata3_cold_launcher.py', REQUEST,
         '.github/workflows/strata-theatre-003-cold-launch.yml',
         'docs/audits/2026-11-25-strata-theatre-003/cold-first-command-registration.md')
MANIFEST = 'evaluation-manifest.json'
CONSOLE = 'Godot_v4.7-stable_win64_console.exe'
GUI = 'Godot_v4.7-stable_win64.exe'
LAUNCHER = 'Open Workbench.cmd'
ARGS = '--audio-driver Dummy --rendering-method gl_compatibility --rendering-driver opengl3 --quit-after 180'
SCOPE = 'First shipped CMD on a new extraction with no prior Godot invocation. Cold import command lifetime and ordinary native Workbench admission/shutdown; no nine-scene rerun or physical GPU acceptance.'
HEX = re.compile(r'[0-9a-f]{64}')
ID = re.compile(r'-?[1-9][0-9]{0,18}')
ERRORS = re.compile(r'SCRIPT ERROR:|Parse Error:|Failed to load script|ERROR:')


def require(condition, message='Invalid cold-launch evidence'):
    if not condition: raise RuntimeError(message)


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''): h.update(chunk)
    return h.hexdigest()


def write(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2)+'\n', encoding='utf-8')


def integer(value, minimum=0):
    return type(value) is int and value >= minimum


def number(value, minimum=0):
    return type(value) in (int, float) and math.isfinite(value) and value >= minimum


def relative(name):
    require(isinstance(name, str) and name and not name.startswith('/') and '\\' not in name
            and not re.search(r'[\x00-\x1f<>:"|?*]', name), 'Unsafe portable path')
    parts = name.split('/')
    require(all(p and p not in ('.','..') and not p.endswith((' ','.'))
                and p.split('.')[0].upper() not in {'CON','PRN','AUX','NUL', *('COM'+str(i) for i in range(1,10)), *('LPT'+str(i) for i in range(1,10))}
                for p in parts), 'Unsafe or ambiguous portable path')
    return Path(*parts)


def path_in(folder, name):
    folder = Path(folder).resolve(strict=True)
    path = folder / relative(name)
    for parent in [path, *path.parents]:
        if parent == folder: break
        require(not parent.is_symlink(), 'Linked evidence path')
    require(path.resolve(strict=True).is_relative_to(folder) and path.is_file(), 'Evidence escaped its folder')
    return path


def validate_request(value, *, armed=True):
    keys = {'schema','armed','application_source','application_tree','package_run_id','package_artifact_id',
            'package_artifact_name','package_filename','package_sha256','package_bytes','manifest_sha256',
            'timeout_seconds','quit_after_callbacks'}
    require(isinstance(value,dict) and set(value)==keys and value['schema']=='strata3-cold-launch-request-v1'
            and type(value['armed']) is bool and value['application_source']==APPLICATION and value['application_tree']==TREE
            and value['timeout_seconds']==180 and value['quit_after_callbacks']==180, 'Cold request contract changed')
    package = 'CyberSand-Strata3-Workbench-Windows-'+APPLICATION[:12]+'.zip'
    require(value['package_filename']==package, 'Wrong immutable evaluator filename')
    if not value['armed']:
        require(not armed and all(value[k] is None for k in ('package_run_id','package_artifact_id','package_artifact_name',
                    'package_sha256','package_bytes','manifest_sha256')), 'Cold request is not armed with actual shipped identities')
        return value
    require(integer(value['package_run_id'],1) and integer(value['package_artifact_id'],1)
            and integer(value['package_bytes'],1) and value['package_bytes']<=2*1024**3
            and all(isinstance(value[k],str) and HEX.fullmatch(value[k]) and value[k]!='0'*64 for k in ('package_sha256','manifest_sha256'))
            and re.fullmatch('strata3-workbench-windows-evaluator-'+APPLICATION+r'-[1-9][0-9]*',str(value['package_artifact_name'])),
            'Missing exact shipped artifact/ZIP identities')
    return value


def validate_metadata(value, request):
    require(isinstance(value,dict) and value.get('id')==request['package_artifact_id']
            and value.get('name')==request['package_artifact_name'] and value.get('expired') is False
            and value.get('workflow_run',{}).get('id')==request['package_run_id']
            and value.get('workflow_run',{}).get('head_sha')==APPLICATION,
            'GitHub artifact differs from the exact application/run/request')
    return value


def git(root, *args):
    return subprocess.check_output(['git','-C',str(root),*args], timeout=60)


def observer_identity():
    commit = git(ROOT,'rev-parse','HEAD').decode().strip()
    inputs = {}
    for name in FILES:
        data = (ROOT/name).read_bytes()
        require(data.replace(b'\r\n',b'\n')==git(ROOT,'show',commit+':'+name), 'Commit observer input first: '+name)
        inputs[name] = hashlib.sha256(data).hexdigest()
    return {'source_commit':commit,'source_tree':git(ROOT,'rev-parse','HEAD^{tree}').decode().strip(),
            'source_inputs_raw_sha256':inputs,'location':'external-to-shipped-application'}


def application_tools(root):
    root = Path(root).resolve(strict=True)
    require(git(root,'rev-parse','HEAD').decode().strip()==APPLICATION
            and git(root,'rev-parse','HEAD^{tree}').decode().strip()==TREE, 'Application verifier checkout is not immutable fd0830ab')
    sys.path.insert(0,str(root/'tools')); sys.path.insert(0,str(root/'tools/ci'))
    spec = importlib.util.spec_from_file_location('strata003_frozen_package_verifier',root/'tools/package_strata3_workbench.py')
    module = importlib.util.module_from_spec(spec)
    previous = sys.modules.get(spec.name)
    sys.modules[spec.name] = module
    try:
        spec.loader.exec_module(module)
        require(module.ROOT==root and module.optics.ROOT==root and module.compatibility.ROOT==root,
                'Application verifier imported modules from a different checkout')
        require(module.optics.identity()['source_commit']==APPLICATION, 'Frozen verifier source identity changed')
        return module
    except BaseException:
        if previous is None:
            sys.modules.pop(spec.name, None)
        else:
            sys.modules[spec.name] = previous
        raise


def inspect_archive(archive, request):
    archive = Path(archive)
    require(archive.is_file() and not archive.is_symlink() and archive.stat().st_size==request['package_bytes']
            and sha(archive)==request['package_sha256'], 'Shipped ZIP bytes changed')
    files, folded, total = {}, set(), 0
    with zipfile.ZipFile(archive) as bundle:
        require(0<len(bundle.infolist())<=50000,'Invalid bounded package inventory')
        for item in bundle.infolist():
            require(not item.is_dir() and stat.S_IFMT(item.external_attr>>16) in (0,stat.S_IFREG), 'Linked/non-file ZIP member')
            # ZipInfo.filename can truncate NUL and normalize a platform's path
            # separator. Validate the original decoded central-directory name.
            relative(item.orig_filename)
            require(item.orig_filename==item.filename,'ZIP filename was normalized or truncated')
            require(item.filename.casefold() not in folded and not item.flag_bits&1, 'Duplicate or encrypted package member')
            folded.add(item.filename.casefold()); total += item.file_size
            require(item.file_size<=1024**3 and total<=8*1024**3, 'Package exceeds registered extraction bound')
            require(not any(p in ('.godot','userdata','__pycache__') for p in PurePosixPath(item.filename).parts), 'Package already contains generated runtime state')
            h=hashlib.sha256()
            with bundle.open(item) as stream:
                for block in iter(lambda:stream.read(1024*1024),b''): h.update(block)
            files[item.filename]=h.hexdigest()
        require(MANIFEST in files and files[MANIFEST]==request['manifest_sha256'],'Package manifest identity changed')
        manifest=json.loads(bundle.read(MANIFEST))
    require(manifest.get('schema')=='strata3-workbench-evaluation-v1' and manifest.get('source_commit')==APPLICATION
            and manifest.get('source_tree')==TREE and manifest.get('draft_hold') is True
            and manifest.get('files_sha256')=={k:v for k,v in files.items() if k!=MANIFEST}, 'ZIP and complete payload manifest disagree')
    require({LAUNCHER,CONSOLE,GUI,'godot/project.godot'}<=set(files),'Missing ordinary portable entry point')
    return manifest,files


def extract_archive(archive, destination, files):
    destination=Path(destination)
    require(not destination.exists() and ' ' in str(destination),'Fresh extraction must not exist and must test a spaced path')
    destination.mkdir(parents=True)
    with zipfile.ZipFile(archive) as bundle:
        for name in files:
            path=destination/relative(name); path.parent.mkdir(parents=True,exist_ok=True)
            with bundle.open(name) as source,path.open('xb') as target: shutil.copyfileobj(source,target,1024*1024)
    require(snapshot(destination)==files,'Pristine extracted bytes differ from ZIP')
    return destination


def snapshot(folder):
    result={}
    for path in sorted(Path(folder).rglob('*')):
        require(not path.is_symlink(),'Linked extracted payload')
        if path.is_file(): result[path.relative_to(folder).as_posix()]=sha(path)
    return result


def evidence_inventory(output):
    record=output/'cold-launch.json'
    return {p.relative_to(output).as_posix():sha(p) for p in sorted(output.rglob('*')) if p.is_file() and p!=record}


def pristine_state(folder):
    return {name:(Path(folder)/name).exists() for name in ('godot/.godot','userdata')}


def command_line(comspec, folder, *, persistent=False):
    require('"' not in str(comspec)+str(folder),'Quoted execution path refused')
    # The historical ordinary command remains byte-for-byte unchanged. The
    # integrated evaluator also exercises its explicit persistent host under
    # the same held-process 180-second outer observation bound.
    launcher='Open Persistent Areas.cmd' if persistent else LAUNCHER
    arguments=ARGS.removesuffix(' --quit-after 180') if persistent else ARGS
    return '"'+str(comspec)+'" /d /s /c ""'+ntpath.join(str(folder),launcher)+'" '+arguments+'"'


def normalized(path):
    return str(path).replace('\\','/').casefold()


def lifetime_reader(metrics):
    """Keep query-only handles so completed process times survive process exit."""
    from ctypes import wintypes as W
    class Reader(metrics.WindowsReader):
        def __init__(self):
            super().__init__()
            self.held={}
            self.kernel.QueryFullProcessImageNameW.argtypes=[W.HANDLE,W.DWORD,W.LPWSTR,ctypes.POINTER(W.DWORD)]
            self.kernel.QueryFullProcessImageNameW.restype=W.BOOL
            self.kernel.GetExitCodeProcess.argtypes=[W.HANDLE,ctypes.POINTER(W.DWORD)]
            self.kernel.GetExitCodeProcess.restype=W.BOOL

        def times(self, handle):
            values=[self.Time() for _ in range(4)]
            if not self.kernel.GetProcessTimes(handle,*(ctypes.byref(x) for x in values)):
                raise ctypes.WinError(ctypes.get_last_error())
            return [x.value() for x in values]

        def observe(self,row):
            result=super().observe(row)
            key=(result['pid'],result['start_id'])
            if key not in self.held:
                handle=self.kernel.OpenProcess(0x1000,False,row['pid'])  # QUERY_LIMITED_INFORMATION
                if not handle: raise ctypes.WinError(ctypes.get_last_error())
                try:
                    require(self.times(handle)[0]==result['start_id'],'PID changed before lifetime observation')
                    buffer=ctypes.create_unicode_buffer(32768);size=W.DWORD(len(buffer))
                    if not self.kernel.QueryFullProcessImageNameW(handle,0,buffer,ctypes.byref(size)):
                        raise ctypes.WinError(ctypes.get_last_error())
                    self.held[key]=(handle,dict(result,image_path=buffer.value))
                except BaseException:
                    self.kernel.CloseHandle(handle)
                    raise
            return dict(result,image_path=self.held[key][1]['image_path'])

        def final_rows(self):
            rows=[]
            for (pid,start),(handle,row) in sorted(self.held.items()):
                created,exited,kernel,user=self.times(handle)
                code=W.DWORD()
                if not self.kernel.GetExitCodeProcess(handle,ctypes.byref(code)):
                    raise ctypes.WinError(ctypes.get_last_error())
                require(created==start,'Held process identity changed')
                ended=code.value!=259
                rows.append({'pid':pid,'parent_pid':row['parent_pid'],'start_id':start,
                    'image_path':row['image_path'],'exit_code':int(code.value),'exited':ended,
                    'creation_filetime_100ns':created,'exit_filetime_100ns':exited if ended else None,
                    'lifetime_seconds':(exited-created)/10_000_000 if ended else None,
                    'final_cpu_seconds':(kernel+user)/10_000_000})
            return rows

        def close(self):
            for handle,_ in self.held.values(): self.kernel.CloseHandle(handle)
            self.held.clear()
    return Reader()


def kill_owned_tree(process,reader):
    """Only clean up this launch, never unrelated processes or a reused PID."""
    if process.poll() is None:
        subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],capture_output=True,timeout=20,check=False)
    if reader is None:
        if process.poll() is None: process.wait(timeout=10)
        return
    from ctypes import wintypes as W
    reader.kernel.TerminateProcess.argtypes=[W.HANDLE,W.UINT]
    reader.kernel.TerminateProcess.restype=W.BOOL
    for row in reader.final_rows():
        if row['exited']: continue
        handle=reader.kernel.OpenProcess(0x1000|0x0001,False,row['pid'])
        if not handle: continue
        try:
            if reader.times(handle)[0]==row['start_id']: reader.kernel.TerminateProcess(handle,124)
        finally: reader.kernel.CloseHandle(handle)
    if process.poll() is None: process.wait(timeout=10)


def persistent_readiness(text):
    # Never parse an incomplete concurrent stdout write. Only the existing
    # product marker admits a normal window close; elapsed frames do not.
    complete=text.splitlines() if text.endswith("\n") else text.splitlines()[:-1]
    lines=[line for line in complete if line.startswith('PERSISTENT_AREAS_READY ')]
    require(len(lines)<=1,'Duplicate persistent readiness marker')
    if not lines: return None
    value=json.loads(lines[0].removeprefix('PERSISTENT_AREAS_READY '))
    require(isinstance(value,dict) and set(value)=={'session','area','revision'}
            and value['area'] in ('a','b','c') and integer(value['revision'],1)
            and re.fullmatch(r'[0-9a-f]{32}',str(value['session'])) is not None,
            'Malformed persistent readiness marker')
    return {'value':value,'line_sha256':hashlib.sha256(lines[0].encode('utf-8')).hexdigest()}


def close_persistent_window(folder,reader,ready,observed_unix):
    """Post normal WM_CLOSE only to the live, held packaged engine's window."""
    from ctypes import wintypes as W
    engine=normalized(ntpath.join(str(folder),GUI))
    live=[row for row in reader.final_rows() if not row['exited'] and normalized(row['image_path'])==engine]
    require(len(live)<=1,'Ambiguous live packaged Godot engine')
    if not live: return None
    target=live[0]
    user=ctypes.WinDLL('user32',use_last_error=True)
    callback_type=ctypes.WINFUNCTYPE(W.BOOL,W.HWND,W.LPARAM)
    for name,args,result in (
        ('EnumWindows',[callback_type,W.LPARAM],W.BOOL),
        ('GetWindowThreadProcessId',[W.HWND,ctypes.POINTER(W.DWORD)],W.DWORD),
        ('IsWindowVisible',[W.HWND],W.BOOL),
        ('PostMessageW',[W.HWND,W.UINT,W.WPARAM,W.LPARAM],W.BOOL)):
        function=getattr(user,name);function.argtypes=args;function.restype=result
    windows=[];errors=[]
    @callback_type
    def observe(hwnd,_):
        try:
            owner=W.DWORD()
            if user.GetWindowThreadProcessId(hwnd,ctypes.byref(owner)) and owner.value==target['pid'] and user.IsWindowVisible(hwnd):
                windows.append(int(hwnd))
            return True
        except BaseException as error:
            errors.append(error);return False
    completed=user.EnumWindows(observe,0)
    if errors: raise errors[0]
    if not completed: raise ctypes.WinError(ctypes.get_last_error())
    require(len(windows)<=1,'Ambiguous visible window for persistent Godot engine')
    if not windows: return None
    hwnd=windows[0]
    # Re-read the held process and HWND owner immediately before the only
    # mutating UI operation. An exited/reused/unowned target is never closed.
    current=[row for row in reader.final_rows() if row['pid']==target['pid'] and row['start_id']==target['start_id']]
    require(len(current)==1 and not current[0]['exited'] and normalized(current[0]['image_path'])==engine,
            'Persistent engine exited before normal window close')
    owner=W.DWORD()
    require(user.GetWindowThreadProcessId(hwnd,ctypes.byref(owner)) and owner.value==target['pid']
            and user.IsWindowVisible(hwnd),'Persistent window ownership changed before close')
    posted_unix=time.time()
    if not user.PostMessageW(hwnd,0x0010,0,0): raise ctypes.WinError(ctypes.get_last_error())
    return {'schema':'ramcache-strata-persistent-close-v1','readiness':ready['value'],
            'readiness_line_sha256':ready['line_sha256'],'ready_observed_unix_seconds':observed_unix,
            'message':'WM_CLOSE','message_id':0x0010,'hwnd':hwnd,'pid':target['pid'],
            'start_id':target['start_id'],'image_path':target['image_path'],
            'window_owner_pid':int(owner.value),'visible':True,'posted':True,
            'posted_unix_seconds':posted_unix}


def execute_launcher(folder,output,metrics,*,persistent=False):
    require(sys.platform=='win32','Actual cold launch requires Windows')
    output.mkdir(parents=True,exist_ok=False)
    comspec=os.environ.get('ComSpec',r'C:\Windows\System32\cmd.exe')
    require(Path(comspec).is_file(),'Missing ordinary Windows CMD executable')
    command=command_line(comspec,folder,persistent=persistent)
    env=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1')
    began=time.monotonic();started_unix=time.time()
    process=None;reader=None;tree=None;timed_out=False;failure=None;cleanup_errors=[]
    close_record=None;ready_observed=None
    try:
        with (output/'process.log').open('wb') as log:
            # Construct query APIs before creating a child. A failed observer
            # constructor must never leave an unobserved owner CMD running.
            reader=lifetime_reader(metrics)
            # A string with an explicit executable preserves CMD /s quote semantics.
            # shell=True is deliberately not used and the owner CMD bytes are untouched.
            process=subprocess.Popen(command,executable=comspec,cwd=folder,env=env,
                                     stdout=log,stderr=subprocess.STDOUT,shell=False)
            tree=metrics.ProcessTree(process.pid,began);tree.reader=reader
            while True:
                tree.sample()
                if process.poll() is not None: break
                if time.monotonic()-began>=180:
                    timed_out=True;kill_owned_tree(process,reader);break
                if persistent and close_record is None:
                    ready=persistent_readiness((output/'process.log').read_text(encoding='utf-8',errors='replace'))
                    if ready is not None:
                        if ready_observed is None: ready_observed=time.time()
                        close_record=close_persistent_window(folder,reader,ready,ready_observed)
                time.sleep(min(metrics.SAMPLE_SECONDS,max(0.001,180-(time.monotonic()-began))))
            process.wait(timeout=10)
            tree.sample()
    except BaseException as error:
        failure=type(error).__name__+': '+str(error)
        if process is not None:
            try: kill_owned_tree(process,reader)
            except BaseException as cleanup: cleanup_errors.append(type(cleanup).__name__+': '+str(cleanup))
    finally:
        duration=time.monotonic()-began
        resources={};rows=[]
        try:
            if tree is not None: resources=tree.receipt()
        except BaseException as error: cleanup_errors.append('Resource receipt: '+str(error))
        try:
            if reader is not None: rows=reader.final_rows()
        except BaseException as error: cleanup_errors.append('Process lifetimes: '+str(error))
        finally:
            if reader is not None:
                try: reader.close()
                except BaseException as error: cleanup_errors.append('Handle closure: '+str(error))
        if cleanup_errors and failure is None: failure='Observer cleanup/receipt failure'
        write(output/'resources.json',resources)
        write(output/'lifetimes.json',{'schema':'strata3-cold-process-lifetimes-v1','rows':rows,
            'semantics':'Creation/exit times from held query-only Win32 process handles. Console stage lifetime includes startup, work and teardown; it is not pure import CPU time.'})
        receipt={'schema':'strata3-cold-process-v1','label':'launcher','command':command,'executable':comspec,
            'cwd':str(folder),'pid':process.pid if process else None,'platform':sys.platform,
            'exit_code':process.returncode if process else None,'timed_out':timed_out,'failure':failure,'cleanup_errors':cleanup_errors,
            'started_unix_seconds':started_unix,'wall_seconds':duration,'timeout_seconds':180,
            'log_sha256':sha(output/'process.log') if (output/'process.log').exists() else None,
            'resources_sha256':sha(output/'resources.json'),'lifetimes_sha256':sha(output/'lifetimes.json'),
            'resources':{k:v for k,v in resources.items() if k!='samples'}}
        if persistent: receipt['persistent_close']=close_record
        write(output/'process.json',receipt)
    require(failure is None and not timed_out and receipt['exit_code']==0,'Cold shipped command failed or exceeded 180 seconds')
    return receipt


def validate_log(text):
    require(not ERRORS.search(text),'Application/import log contains an engine/script error')
    headers=[line for line in text.splitlines() if line.startswith('Godot Engine v')]
    require(headers==['Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org']*2,
            'CMD did not run both pinned importer and ordinary application')
    devices=[line for line in text.splitlines() if line.startswith('OpenGL API ')]
    require(len(devices)==1 and ' - Compatibility - Using Device: ' in devices[0],
            'No unique ordinary graphical Compatibility backend')
    markers=[line[len('STRATA_WORKBENCH_LAUNCH_ADMITTED '):] for line in text.splitlines()
             if line.startswith('STRATA_WORKBENCH_LAUNCH_ADMITTED ')]
    require(len(markers)==1,'Missing or duplicate ordinary Workbench admission')
    value=json.loads(markers[0])
    require(set(value)=={'source_revision','workbench_script','world_generation','worker_id','extent','strata_enabled'}
            and value['source_revision']==APPLICATION and value['workbench_script']=='res://scripts/shared_workbench.gd'
            and integer(value['world_generation'],1) and isinstance(value['worker_id'],str)
            and ID.fullmatch(value['worker_id']) and value['extent']==[2048,2048] and value['strata_enabled'] is False,
            'CMD did not admit the ordinary native 2048-square Strata-disabled Workbench')
    return {'admission':value,'rendering_backend':devices[0],'godot_headers':headers}


def validate_resources(raw,process,lifetimes):
    require(raw.get('schema')=='strata-process-resources-v1' and raw.get('available') is True
            and raw.get('root_pid')==process['pid'] and raw.get('sample_interval_seconds')==0.5
            and {k:v for k,v in raw.items() if k!='samples'}==process['resources'],'Wrong process-resource receipt')
    samples=raw.get('samples');latest={};peak=0;elapsed=-1
    require(isinstance(samples,list) and 2<=len(samples)<=363 and raw.get('sample_count')==len(samples),'Missing or unbounded process observations')
    lives={(r['pid'],r['start_id']):r for r in lifetimes}
    for sample in samples:
        at=sample.get('elapsed_seconds')
        require(number(at) and at>=elapsed and at<=process['wall_seconds']+1,'Resource clock outside actual launch')
        elapsed=at;rss=0;keys=set()
        rows=sample.get('processes')
        require(isinstance(rows,list) and len(rows)<=128,'Unbounded process sample')
        for row in rows:
            key=(row.get('pid'),row.get('start_id'))
            require(integer(key[0],1) and integer(key[1],1) and key in lives and key not in keys
                    and integer(row.get('rss_bytes')) and number(row.get('cpu_seconds'))
                    and normalized(row.get('image_path',''))==normalized(lives[key]['image_path'])
                    and row['cpu_seconds']>=latest.get(key,0),'Unbound/regressing process observation')
            keys.add(key);latest[key]=row['cpu_seconds'];rss+=row['rss_bytes']
        require(sample.get('tree_rss_bytes')==rss and math.isclose(sample.get('tree_cpu_seconds_observed',-1),sum(latest.values()),rel_tol=1e-9,abs_tol=1e-9),
                'Resource sample aggregate differs from original rows')
        peak=max(peak,rss)
    require(raw.get('process_identities')==[list(key) for key in sorted(latest)] and set(latest)==set(lives)
            and raw.get('peak_observed_tree_rss_bytes')==peak and peak>0
            and math.isclose(raw.get('observed_cpu_seconds',-1),sum(latest.values()),rel_tol=1e-9,abs_tol=1e-9),
            'Resource aggregate or retained lifetime population differs')
    require(all(lives[key]['final_cpu_seconds']+1e-6>=cpu for key,cpu in latest.items()),'Final process CPU regressed')


def validate_execution(process,raw_lifetimes,resources,log):
    require(process.get('schema')=='strata3-cold-process-v1' and process.get('label')=='launcher'
            and process.get('platform')=='win32' and integer(process.get('pid'),1)
            and process.get('exit_code')==0 and process.get('timed_out') is False and process.get('failure') is None
            and process.get('cleanup_errors')==[]
            and process.get('timeout_seconds')==180 and number(process.get('wall_seconds'),0.001)
            and process['wall_seconds']<=190 and ' ' in process.get('cwd','')
            and ntpath.basename(process.get('executable','')).lower()=='cmd.exe'
            and process.get('command')==command_line(process['executable'],process['cwd']),
            'Wrong, failed or unbounded actual owner CMD execution')
    require(raw_lifetimes.get('schema')=='strata3-cold-process-lifetimes-v1','Wrong lifetime schema')
    rows=raw_lifetimes.get('rows');require(isinstance(rows,list) and 5<=len(rows)<=128,'Missing complete CMD/Godot process population')
    identities=set()
    for row in rows:
        key=(row.get('pid'),row.get('start_id'))
        require(integer(key[0],1) and integer(key[1],1) and key not in identities and row.get('exited') is True
                and row.get('exit_code')==0 and row.get('creation_filetime_100ns')==key[1]
                and integer(row.get('exit_filetime_100ns'),key[1]+1) and number(row.get('final_cpu_seconds'))
                and number(row.get('lifetime_seconds'),0.000001)
                and math.isclose(row['lifetime_seconds'],(row['exit_filetime_100ns']-key[1])/10_000_000,abs_tol=1e-9),
                'Process still live, failed or lacks actual held-handle timing')
        identities.add(key)
    roots=[r for r in rows if r['pid']==process['pid']]
    require(len(roots)==1 and normalized(roots[0]['image_path'])==normalized(process['executable']),'Actual CMD identity missing')
    root=roots[0]
    require(number(process.get('started_unix_seconds'),1) and abs(root['start_id']/10_000_000-11644473600-process['started_unix_seconds'])<=5
            and root['lifetime_seconds']<=process['wall_seconds']+1,'Process FILETIME is outside actual launch clock')
    consoles=sorted((r for r in rows if normalized(r['image_path'])==normalized(ntpath.join(process['cwd'],CONSOLE))),key=lambda r:r['start_id'])
    require(len(consoles)==2 and all(r['parent_pid']==root['pid'] for r in consoles)
            and root['start_id']<=consoles[0]['start_id']<consoles[0]['exit_filetime_100ns']<=consoles[1]['start_id']
            <consoles[1]['exit_filetime_100ns']<=root['exit_filetime_100ns'],
            'Cold importer and ordinary Workbench are not two ordered shipped console stages')
    engines=[r for r in rows if normalized(r['image_path'])==normalized(ntpath.join(process['cwd'],GUI))]
    require(len(engines)>=2,'Bundled engine children were not observed')
    for console in consoles:
        children=[r for r in engines if r['parent_pid']==console['pid']]
        require(len(children)==1 and console['start_id']<=children[0]['start_id']
                <children[0]['exit_filetime_100ns']<=console['exit_filetime_100ns'],
                'Shipped console stage lacks its actual engine identity and lifetime')
    for row in rows:
        if row is root: continue
        parents=[p for p in rows if p['pid']==row['parent_pid'] and p['start_id']<=row['start_id']<=p['exit_filetime_100ns']]
        require(len(parents)==1 and root['start_id']<=row['start_id']<row['exit_filetime_100ns']<=root['exit_filetime_100ns'],
                'Observed process is not contained in this actual launcher tree')
    validate_resources(resources,process,rows)
    observation=validate_log(log)
    observation.update({'cold_import_command_seconds':consoles[0]['lifetime_seconds'],
        'ordinary_workbench_command_seconds':consoles[1]['lifetime_seconds'],
        'cmd_process_seconds':root['lifetime_seconds'],
        'console_process_ids':[r['pid'] for r in consoles],
        'engine_process_ids':[r['pid'] for r in engines],
        'observed_process_tree_cpu_seconds':resources['observed_cpu_seconds'],
        'peak_observed_process_tree_rss_bytes':resources['peak_observed_tree_rss_bytes']})
    return observation


def retained_sources(output,identity):
    for name,digest in identity['source_inputs_raw_sha256'].items():
        target=output/'observer'/relative(name);target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(ROOT/name,target)
        require(sha(target)==digest,'Observer source copy changed')


def prepare(output):
    request=validate_request(json.loads((ROOT/REQUEST).read_text(encoding='utf-8')))
    identity=observer_identity()
    require(not output.exists(),'Refusing to reuse cold qualification output')
    token=os.environ.get('GH_TOKEN','')
    require(token,'Artifact metadata authentication is required')
    query=urllib.request.Request('https://api.github.com/repos/'+REPOSITORY+'/actions/artifacts/'+str(request['package_artifact_id']),
        headers={'Authorization':'Bearer '+token,'Accept':'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28',
                 'User-Agent':'CyberSand-Strata003-cold-observer'})
    with urllib.request.urlopen(query,timeout=60) as response: data=response.read(1024*1024+1)
    require(len(data)<=1024*1024,'Oversized artifact metadata')
    metadata=validate_metadata(json.loads(data),request)
    output.mkdir(parents=True)
    shutil.copyfile(ROOT/REQUEST,output/'request.json')
    (output/'artifact-metadata.json').write_bytes(data)
    write(output/'observer-identity.json',identity);retained_sources(output,identity)
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'],'a',encoding='utf-8') as target:
            target.write('artifact_id='+str(request['package_artifact_id'])+'\nrun_id='+str(request['package_run_id'])+'\n')
    return {'prepared':True,'artifact_id':metadata['id'],'application_source':APPLICATION,'observer':identity['source_commit']}


def verifier_inputs(application_root):
    result={}
    for module in list(sys.modules.values()):
        filename=getattr(module,'__file__',None)
        if not filename: continue
        path=Path(filename).resolve()
        if path.suffix!='.py' or not path.is_relative_to(application_root): continue
        name=path.relative_to(application_root).as_posix()
        require(path.read_bytes().replace(b'\r\n',b'\n')==git(application_root,'show',APPLICATION+':'+name),
                'Frozen verifier module changed: '+name)
        result[name]=sha(path)
    require('tools/package_strata3_workbench.py' in result and 'tools/ci/strata_process_metrics.py' in result,
            'Missing frozen verifier/process observer custody')
    return result


def verify(output,archive):
    output=output.resolve(strict=True)
    record=json.loads(path_in(output,'cold-launch.json').read_text(encoding='utf-8'))
    require(record.get('schema')=='strata3-cold-first-command-v1' and record.get('completed') is True
            and record.get('failures')==[] and record.get('scope')==SCOPE
            and record.get('application_source')==APPLICATION and record.get('application_tree')==TREE,
            'Incomplete or differently scoped cold-command evidence')
    request=validate_request(json.loads(path_in(output,'request.json').read_text(encoding='utf-8')))
    require(request==validate_request(json.loads((ROOT/REQUEST).read_text(encoding='utf-8'))),'Observer request differs from retained request')
    validate_metadata(json.loads(path_in(output,'artifact-metadata.json').read_text(encoding='utf-8')),request)
    identity=observer_identity()
    require(record.get('observer')==identity and json.loads(path_in(output,'observer-identity.json').read_text(encoding='utf-8'))==identity,
            'External observer source identity differs')
    for name,digest in identity['source_inputs_raw_sha256'].items():
        require(sha(path_in(output,'observer/'+name))==digest,'Retained observer source changed')
    manifest,files=inspect_archive(archive,request)
    require(sha(path_in(output,MANIFEST))==request['manifest_sha256'] and record.get('package')=={
        'artifact_id':request['package_artifact_id'],'run_id':request['package_run_id'],
        'filename':request['package_filename'],'bytes':request['package_bytes'],'sha256':request['package_sha256'],
        'manifest_sha256':request['manifest_sha256']},'Wrong retained shipped package identity')
    ledger=json.loads(path_in(output,'payload.json').read_text(encoding='utf-8'))
    require(ledger.get('schema')=='strata3-cold-payload-v1' and ledger.get('archive')==files
            and ledger.get('before')==files and ledger.get('after_original_files')==files
            and ledger.get('pristine_before_launch')=={'godot/.godot':False,'userdata':False}
            and ledger.get('runtime_state_after')=={'godot/.godot':True,'userdata':True},
            'Cold cache boundary or original payload preservation failed')
    generated=ledger.get('generated_files_sha256')
    require(isinstance(generated,dict) and generated and len(generated)<=50000,'Missing bounded generated-state inventory')
    for name,digest in generated.items():
        relative(name)
        source_uid=name.endswith('.uid') and name[:-4] in files and name[:-4].endswith(('.gd','.gdshader'))
        source_import=name.endswith('.import') and name[:-7] in files and name[:-7].lower().endswith(('.png','.svg','.jpg','.jpeg','.webp','.ttf','.otf','.wav','.ogg','.mp3'))
        require(name not in files and (name.startswith('godot/.godot/') or name.startswith('userdata/') or source_uid or source_import)
                and isinstance(digest,str) and HEX.fullmatch(digest),'Unexpected generated file outside portable runtime state')
    expected_events=['archive_verified','fresh_extracted','pristine_verifier_passed','launcher_started','launcher_finished',
                     'payload_unchanged','post_verifier_passed']
    events=record.get('events')
    require(isinstance(events,list) and [x.get('event') for x in events]==expected_events
            and all(number(x.get('elapsed_seconds')) for x in events)
            and all(a['elapsed_seconds']<=b['elapsed_seconds'] for a,b in zip(events,events[1:])),
            'Cold launch/verification ordering changed')
    require(record.get('prior_godot_invocations')==0 and record.get('static_pristine_verifier')=='passed'
            and record.get('static_post_verifier')=='passed'
            and record.get('application_verifier_inputs_before')==record.get('application_verifier_inputs_after')
            and isinstance(record.get('application_verifier_inputs_before'),dict)
            and {'tools/package_strata3_workbench.py','tools/ci/strata_process_metrics.py'}<=set(record['application_verifier_inputs_before']),
            'Frozen verifier changed or cold boundary was not retained')
    for name,digest in record['application_verifier_inputs_before'].items():
        relative(name)
        require(hashlib.sha256(git(ROOT,'show',APPLICATION+':'+name)).hexdigest()==digest,'Verifier is not exact frozen application source')
    process=json.loads(path_in(output,'launcher/process.json').read_text(encoding='utf-8'))
    require(sha(path_in(output,'launcher/process.log'))==process.get('log_sha256')
            and sha(path_in(output,'launcher/resources.json'))==process.get('resources_sha256')
            and sha(path_in(output,'launcher/lifetimes.json'))==process.get('lifetimes_sha256'),
            'Original launcher log/resource/lifetime receipts changed')
    observation=validate_execution(process,json.loads(path_in(output,'launcher/lifetimes.json').read_text(encoding='utf-8')),
        json.loads(path_in(output,'launcher/resources.json').read_text(encoding='utf-8')),
        path_in(output,'launcher/process.log').read_text(encoding='utf-8',errors='strict'))
    require(record.get('observation')==observation and record.get('extraction_path')==process['cwd']
            and normalized(process['cwd']).endswith('/fresh owner extraction fd0830ab'),
            'Derived observation or fresh spaced extraction identity differs')
    require(record.get('runtime_sha256')=={name:files[name] for name in (CONSOLE,GUI)}
            and record.get('launcher_sha256')==files[LAUNCHER],'Actual portable executable identity differs')
    actual=evidence_inventory(output)
    require(record.get('files_sha256')==actual,'Cold evidence has missing, altered or unregistered original files')
    for name in actual: path_in(output,name)
    return {'schema':'strata3-cold-first-command-verification-v1','verified':True,'application_source':APPLICATION,
        'observer_source':identity['source_commit'],'package_sha256':request['package_sha256'],'observation':observation,
        'scope':SCOPE}


def run(application_root,downloads,output):
    require(sys.platform=='win32','Execute the actual owner command only on Windows')
    require(output.is_dir() and not (output/'cold-launch.json').exists(),'Run requires a new prepared artifact request')
    request=validate_request(json.loads(path_in(output,'request.json').read_text(encoding='utf-8')))
    require(request==validate_request(json.loads((ROOT/REQUEST).read_text(encoding='utf-8'))),'Prepared immutable request changed')
    validate_metadata(json.loads(path_in(output,'artifact-metadata.json').read_text(encoding='utf-8')),request)
    identity=observer_identity()
    require(json.loads(path_in(output,'observer-identity.json').read_text(encoding='utf-8'))==identity,'Prepared observer changed')
    root=application_root.resolve(strict=True)
    record={'schema':'strata3-cold-first-command-v1','completed':False,'failures':[],'scope':SCOPE,
        'application_source':APPLICATION,'application_tree':TREE,'observer':identity,'prior_godot_invocations':0,
        'package':{'artifact_id':request['package_artifact_id'],'run_id':request['package_run_id'],
            'filename':request['package_filename'],'bytes':request['package_bytes'],'sha256':request['package_sha256'],
            'manifest_sha256':request['manifest_sha256']},'events':[]}
    began=time.monotonic()
    def event(name): record['events'].append({'event':name,'elapsed_seconds':time.monotonic()-began})
    archive=downloads/request['package_filename']
    try:
        manifest,files=inspect_archive(archive,request);event('archive_verified')
        folder=extract_archive(archive,output.parent/'Fresh owner extraction fd0830ab',files);event('fresh_extracted')
        record['extraction_path']=str(folder)
        shutil.copyfile(folder/MANIFEST,output/MANIFEST)
        require(pristine_state(folder)=={'godot/.godot':False,'userdata':False},'Fresh extraction contains prior runtime state')
        verifier=application_tools(root)
        import strata_process_metrics as metrics
        record['application_verifier_inputs_before']=verifier_inputs(root)
        require(verifier.verify(folder,pristine=True)==manifest,'Static frozen pristine package verification disagrees')
        record['static_pristine_verifier']='passed';event('pristine_verifier_passed')
        before=snapshot(folder)
        require(before==files and pristine_state(folder)=={'godot/.godot':False,'userdata':False},
                'Static verification changed the cold package')
        event('launcher_started')
        process=execute_launcher(folder,output/'launcher',metrics)
        event('launcher_finished')
        record['observation']=validate_execution(process,json.loads((output/'launcher/lifetimes.json').read_text()),
            json.loads((output/'launcher/resources.json').read_text()),(output/'launcher/process.log').read_text(encoding='utf-8'))
        after=snapshot(folder)
        require(all(after.get(name)==digest for name,digest in files.items()),'CMD changed original shipped payload')
        write(output/'payload.json',{'schema':'strata3-cold-payload-v1','archive':files,'before':before,
            'after_original_files':{name:after[name] for name in files},
            'pristine_before_launch':{'godot/.godot':False,'userdata':False},'runtime_state_after':pristine_state(folder),
            'generated_files_sha256':{name:digest for name,digest in after.items() if name not in files}})
        event('payload_unchanged')
        require(verifier.verify(folder)==manifest,'Static post-launch frozen package verification disagrees')
        record['static_post_verifier']='passed';event('post_verifier_passed')
        record['application_verifier_inputs_after']=verifier_inputs(root)
        record['runtime_sha256']={name:files[name] for name in (CONSOLE,GUI)}
        record['launcher_sha256']=files[LAUNCHER]
        record['completed']=True
    except BaseException as error:
        record['failures'].append(type(error).__name__+': '+str(error))
    finally:
        record['files_sha256']=evidence_inventory(output)
        write(output/'cold-launch.json',record)
    require(record['completed'] and not record['failures'],'Cold first-command qualification rejected: '+str(record['failures']))
    try:
        return verify(output,archive)
    except BaseException as error:
        record['completed']=False
        record['failures'].append('Final strict reader: '+type(error).__name__+': '+str(error))
        write(output/'cold-launch.json',record)
        raise


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    commands=parser.add_subparsers(dest='command',required=True)
    prepare_parser=commands.add_parser('prepare');prepare_parser.add_argument('--output',type=Path,required=True)
    run_parser=commands.add_parser('run')
    for name in ('application-root','downloads','output'): run_parser.add_argument('--'+name,type=Path,required=True)
    verify_parser=commands.add_parser('verify');verify_parser.add_argument('--output',type=Path,required=True)
    verify_parser.add_argument('--package-archive',type=Path,required=True)
    args=parser.parse_args()
    if args.command=='prepare': value=prepare(args.output.resolve())
    elif args.command=='run': value=run(args.application_root,args.downloads.resolve(strict=True),args.output.resolve(strict=True))
    else: value=verify(args.output,args.package_archive)
    print(json.dumps(value,sort_keys=True))


if __name__=='__main__': main()
