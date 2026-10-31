"""Portable fail-closed readers for the opt-in Windows crash diagnostic."""
from __future__ import annotations
import hashlib
import json
import ntpath
from pathlib import Path
import re
import struct
from urllib.parse import urlsplit
from windows_crash_policy import CAPTURE_MS, DUMP_TIMEOUT_CONTROL_MS

SCHEMA = 'play-windows-crash-v3'
ACCESS_VIOLATION = 0xC0000005
NOT_HANDLED = 0x80010001
MAX_DUMP_BYTES = 64 * 1024 * 1024
DUMP_FORMAT = {
    'schema': 'play-windows-minidump-v2',
    'requested_flags': 0x1000,
    'allowed_output_flags': [0x1000, 0x201000],
    'max_dump_bytes': MAX_DUMP_BYTES,
    'max_exception_context_bytes': 64 * 1024,
    'unused_stream_rule': 'exact-zero-directory-slot-only',
    'disallowed_stream_types': [9],
}

def require(condition, message):
    if not condition:
        raise ValueError(message)

def sha(path: Path) -> str:
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024*1024), b''):
            value.update(block)
    return value.hexdigest()

def windows_quote(value: str) -> str:
    result='"';slashes=0
    for character in value:
        if character=='\\':slashes+=1;continue
        result+='\\'*(slashes*2+1 if character=='"' else slashes)+character;slashes=0
    return result+'\\'*(slashes*2)+'"'

def read_events(path: Path) -> list[dict]:
    def unique(pairs):
        result={}
        for key,value in pairs:
            require(key not in result,'Duplicate JSON evidence key')
            result[key]=value
        return result
    return [json.loads(line,object_pairs_hook=unique) for line in path.read_text(encoding='utf-8').splitlines() if line]

def read_json(path: Path):
    def unique(pairs):
        result={}
        for key,value in pairs:
            require(key not in result,'Duplicate JSON evidence key')
            result[key]=value
        return result
    return json.loads(path.read_text(encoding='utf-8'),object_pairs_hook=unique)

def windows_path(path: str) -> str:
    if path.startswith('\\\\?\\'):path=path[4:]
    require(ntpath.isabs(path) and bool(ntpath.splitdrive(path)[0]),'Nonabsolute Windows module path')
    return ntpath.normcase(ntpath.normpath(path))

def read_load_identities(root: Path, events: list[dict]) -> dict:
    """Read bounded required-image hashes retained at their actual load stops."""
    identities={};records=set()
    for event in events:
        if event.get('type') not in ('process','module'):continue
        path=event['image'] if event['type']=='process' else event['path']
        require(path and 'load_hash' in event,'Loaded image lacks explicit hash scope')
        capture=event['load_hash']
        if capture is None:
            identity={'hash_status':'not_requested'}
        else:
            require(capture['valid'] is True and capture['limit_ms']==CAPTURE_MS and 0<=capture['milliseconds']<=CAPTURE_MS
                    and capture['helper_pid']>0 and capture['helper_exit']==0 and capture['helper_joined'] is True
                    and capture['helper_terminated'] is False and capture['timed_out'] is False,
                    'Required load-time hash failed, exceeded its bound or lacked joined ownership')
            relative=capture['record'];require(relative not in records,'Duplicate load-time identity record')
            records.add(relative);raw=safe_file(root,relative).read_bytes()
            require(len(raw)==64,'Wrong raw load-time identity size')
            volume,file_id,size,digest=struct.unpack('<Q16sQ32s',raw)
            require(0<size<=256*1024*1024,'Invalid bounded image size')
            require(capture['original_file']=={'volume':volume,'file_id':file_id.hex(),'bytes':size}
                    and capture['file']=={'volume':volume,'file_id':file_id.hex(),'bytes':size,'sha256':digest.hex()},
                    'Hash helper did not read the debug event handle file identity')
            identity={'sha256':digest.hex(),'bytes':size}
        require(path not in identities or identities[path]==identity,'Loaded image bytes changed between events')
        identities[path]=identity
    require(len(records)<=16 and {path.name for path in root.glob('*.identity')}==records,
            'Complete load-time image hash inventory mismatch')
    return identities

def verify_module_bindings(events: list[dict], receipt: dict, identities: dict,
                           images: dict, runtimes: dict, result: dict, *, root: Path) -> dict:
    """Bind actual debug-event owners and loaded bytes to authenticated inputs."""
    images={windows_path(path):value for path,value in images.items()}
    runtimes={windows_path(path):value for path,value in runtimes.items()}
    command=receipt['debuggee_command']
    importing=len(command)==6 and command[1:3]==['--headless','--path'] and command[-2:]==['--editor','--quit']
    runtime_paths={path:path for path in runtimes}
    if importing:
        runtime_paths.update({ntpath.join(ntpath.dirname(path),'~'+ntpath.basename(path)):path for path in runtimes})
    expected=images|{path:runtimes[canonical] for path,canonical in runtime_paths.items()}
    named={ntpath.basename(path):path for path in expected}
    require(len(named)==len(expected),'Ambiguous expected module basename')
    processes=[event for event in events if event.get('type')=='process']
    require(processes,'No actual process image to authenticate')
    root_process=next(event for event in processes if event['root'])
    require(windows_path(root_process['image'])==windows_path(receipt['debuggee_command'][0]),'Root debuggee differs from commanded pinned executable')
    require(identities==read_load_identities(root,events),'Load-stop identity receipt mismatch')
    observed={};captured_modules={};images_seen=set();modules_by_pid={event['pid']:set() for event in processes}
    event_paths=set()
    for event in events:
        if event.get('type')=='unload':
            require(event['pid'] in observed and event['base'] in observed[event['pid']],'Unknown active module unload')
            del observed[event['pid']][event['base']]
            continue
        if event.get('type')=='capture':
            require(event['pid'] in observed,'Capture has unknown module owner')
            captured_modules[event['event_id']]=dict(observed[event['pid']])
            continue
        path=event.get('image') if event.get('type')=='process' else event.get('path') if event.get('type')=='module' else None
        if path is None:continue
        require(bool(path),'Loaded module path was unavailable')
        event_paths.add(path);key=windows_path(path)
        require(event['pid'] in modules_by_pid,'Loaded module has unknown process owner')
        active=observed.setdefault(event['pid'],{})
        require(event['base'] not in active,'Module base reused without an unload event')
        active[event['base']]=key
        if event['type']=='process':
            require(key in images,'Unexpected debuggee executable')
            images_seen.add(key)
        if ntpath.basename(key) in named:
            require(key==named[ntpath.basename(key)],'Pinned module loaded from substituted path')
        if ntpath.basename(key).lstrip('~') in {ntpath.basename(path) for path in runtimes}:
            require(key in runtime_paths,'Runtime shadow path is not admitted for this exact process command')
        if key in expected:
            require(identities.get(path)=={'sha256':expected[key]['sha256'],'bytes':expected[key]['bytes']},'Pinned executable/runtime module bytes mismatch')
            modules_by_pid[event['pid']].add(runtime_paths.get(key,key))
    require(set(identities)==event_paths,'Actual loaded-module identity inventory mismatch')
    require(images_seen==set(images),'Expected executable process was not observed')
    for process in processes:
        if images[windows_path(process['image'])].get('requires_runtime'):
            require(set(runtimes)<=modules_by_pid[process['pid']],'Actual Godot process did not load both selected native/Rapier runtimes')
    for capture in result.get('captures',[]):
        pid=capture['pid'];dump_modules=capture['identity']['modules']
        require(capture['event_id'] in captured_modules,'Dump has unknown process owner')
        active=captured_modules[capture['event_id']]
        for module in dump_modules:
            require(active.get(module['base'])==windows_path(module['path']),
                    'Minidump module is not bound to an actual load event in the faulting process')
        image=next(process for process in processes if process['pid']==pid)
        require(any(windows_path(module['path'])==windows_path(image['image']) and module['base']==image['base']
                    for module in dump_modules),'Minidump omits its actual process image')
    return {'images':sorted(images_seen),'runtime_processes':sorted(process['pid'] for process in processes
            if images[windows_path(process['image'])].get('requires_runtime')),
            'module_path_count':len(event_paths),'hashed_module_path_count':sum('sha256' in row for row in identities.values()),
            'import_shadow_paths_permitted':importing}

def child_environment(environment: dict[str,str]) -> tuple[dict[str,str], list[str]]:
    """Remove credential-bearing names, preserving ordinary OS/toolchain inputs."""
    exact = {'GITHUB_TOKEN','GH_TOKEN','SYSTEM_ACCESSTOKEN','AWS_ACCESS_KEY_ID',
             'AWS_SECRET_ACCESS_KEY','AWS_SESSION_TOKEN','AZURE_CLIENT_SECRET',
             'GOOGLE_APPLICATION_CREDENTIALS','VSS_NUGET_EXTERNAL_FEED_ENDPOINTS',
             'GIT_CONFIG_PARAMETERS','GIT_CONFIG_COUNT'}
    clean = {}; removed = []
    for name,value in environment.items():
        upper = name.upper()
        secret = upper in exact or re.search(r'(^|_)(TOKEN|PASSWORD|PASSWD|SECRET|CREDENTIALS|PRIVATE_KEY|ACCESS_KEY|API_KEY|AUTHORIZATION)(_|$)',upper)
        secret = secret or upper.startswith(('GIT_CONFIG_KEY_','GIT_CONFIG_VALUE_'))
        if upper in {'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY'}:
            try:
                parsed = urlsplit(value)
                secret = secret or parsed.username is not None or parsed.password is not None
            except ValueError:
                secret = True
        if secret: removed.append(name)
        else: clean[name] = value
    return clean, sorted(removed)

def safe_file(root: Path, relative: str) -> Path:
    path = Path(relative)
    require(not path.is_absolute() and path.parts and all(p not in ('..','.') for p in path.parts)
            and '\\' not in relative and ':' not in relative, 'Unsafe diagnostic artifact path')
    result = root/path
    require(result.is_file() and not result.is_symlink(), 'Missing/linked diagnostic artifact: '+relative)
    return result

def dump_identity(data: bytes) -> dict:
    """Read actual MINIDUMP streams without relying on the broker's JSON claim."""
    require(32 <= len(data) <= MAX_DUMP_BYTES and data[:4] == b'MDMP', 'Invalid/big minidump')
    dump_flags=struct.unpack_from('<Q',data,24)[0]
    # DbgHelp on the retained hosted control added the documented AVX register
    # context bit. No full-memory, private-memory, trace or unknown bit is allowed.
    require(dump_flags in DUMP_FORMAT['allowed_output_flags'],
            'Dump flags differ from bounded MiniDumpNormal/ThreadInfo contract')
    count, directory = struct.unpack_from('<II',data,8)
    require(1 <= count <= 128 and directory+12*count <= len(data), 'Invalid minidump stream directory')
    streams = {};unused_stream_slots=0
    for index in range(count):
        kind,size,offset = struct.unpack_from('<III',data,directory+12*index)
        if kind==0:
            require(size==offset==0, 'Nonempty unused minidump directory slot')
            unused_stream_slots+=1
            continue
        require(kind not in DUMP_FORMAT['disallowed_stream_types'],
                'Full-memory minidump stream violates bounded dump contract')
        require(kind not in streams and offset+size <= len(data), 'Duplicate/truncated minidump stream')
        streams[kind] = (size,offset)
    require(all(k in streams for k in (3,4,6)), 'Minidump lacks threads/modules/exception')
    size,offset = streams[6]
    require(size >= 168, 'Truncated exception stream')
    tid,code = struct.unpack_from('<I',data,offset)[0],struct.unpack_from('<I',data,offset+8)[0]
    address = struct.unpack_from('<Q',data,offset+24)[0]
    context_size,context_at = struct.unpack_from('<II',data,offset+160)
    require(1232 <= context_size <= DUMP_FORMAT['max_exception_context_bytes']
            and context_at+context_size <= len(data), 'Missing/oversized exception thread context')
    flags = struct.unpack_from('<I',data,context_at+48)[0]
    require(flags & 0x100000 == 0x100000, 'Exception context is not x86_64')
    rip,rsp,rbp = (struct.unpack_from('<Q',data,context_at+x)[0] for x in (248,152,160))
    thread_size,thread_at = streams[3]
    threads = struct.unpack_from('<I',data,thread_at)[0]
    require(1 <= threads <= 1024 and 4+threads*48 <= thread_size, 'Invalid minidump thread inventory')
    matches = []
    for i in range(threads):
        row = thread_at+4+i*48
        if struct.unpack_from('<I',data,row)[0] == tid:
            stack_start = struct.unpack_from('<Q',data,row+24)[0]
            stack_size,stack_at = struct.unpack_from('<II',data,row+32)
            require(stack_size > 0 and stack_at+stack_size <= len(data), 'Faulting thread stack is absent')
            require(stack_start<=rsp<stack_start+stack_size,'Stopped stack pointer is outside retained fault stack')
            matches.append({'start':stack_start,'bytes':stack_size})
    require(len(matches) == 1, 'Faulting thread not unique in dump')
    module_size,module_at = streams[4]
    modules = struct.unpack_from('<I',data,module_at)[0]
    require(1 <= modules <= 2048 and 4+modules*108 <= module_size, 'Invalid minidump module inventory')
    module_rows = []
    for i in range(modules):
        row = module_at+4+i*108
        base,length = struct.unpack_from('<QI',data,row)
        name_at = struct.unpack_from('<I',data,row+20)[0]
        require(name_at+4 <= len(data), 'Missing module name')
        name_size = struct.unpack_from('<I',data,name_at)[0]
        require(name_size <= 65536 and not name_size%2 and name_at+4+name_size <= len(data), 'Invalid module name')
        name = data[name_at+4:name_at+4+name_size].decode('utf-16-le')
        module_rows.append({'base':base,'bytes':length,'path':name})
    parameters=struct.unpack_from('<I',data,offset+32)[0]
    require(parameters<=15,'Invalid exception parameter count')
    return {'dump_format_schema':DUMP_FORMAT['schema'],'dump_flags':dump_flags,
            'exception_context_bytes':context_size,'unused_stream_slots':unused_stream_slots,
            'stream_types':sorted(streams),
            'thread_id':tid,'code':code,'address':address,'rip':rip,'rsp':rsp,'rbp':rbp,
            'flags':struct.unpack_from('<I',data,offset+12)[0],
            'nested_record':struct.unpack_from('<Q',data,offset+16)[0],
            'parameters':list(struct.unpack_from('<'+'Q'*parameters,data,offset+40)),
            'fault_stack':matches[0],'thread_count':threads,'modules':module_rows}

def verify_capture(root: Path, events: list[dict], receipt: dict) -> dict:
    require(events and events[0].get('type') == 'start' and events[0].get('schema') == SCHEMA,
            'Missing exact diagnostic start')
    require(events[-1].get('type') == 'end' and sum(e.get('type')=='end' for e in events)==1,
            'Missing/duplicate diagnostic end')
    start,end = events[0],events[-1]
    require(start['timeout_ms'] == receipt['timeout_ms'] and start['broker_pid'] == receipt['broker_pid'], 'Broker receipt mismatch')
    require(start['command_line']==' '.join(windows_quote(a) for a in receipt['debuggee_command']), 'Debuggee command differs from process receipt')
    require(end['effective_exit'] == receipt['returncode'] and receipt.get('outer_timeout') is False, 'Broker exit/outer timeout mismatch')
    require(end['errors'] == 0, 'Diagnostic broker reported incomplete capture')
    require(not any(e.get('type')=='error' for e in events), 'Diagnostic event error')
    processes = [e for e in events if e.get('type')=='process']
    require(processes and len({e['pid'] for e in processes})==len(processes), 'Missing/duplicate debuggee identity')
    pids = {e['pid'] for e in processes}
    require(sum(e['root'] for e in processes)==1 and next(e['pid'] for e in processes if e['root'])==end['root_pid'], 'Wrong debuggee root')
    require(all(e.get('image') for e in processes), 'Debuggee executable identity is missing')
    active=set();pending=None;last_event=0
    kinds={'process':3,'module':6,'unload':7,'exception':1,'exit':5}
    for event in events[1:-1]:
        kind=event.get('type')
        require(kind in {*kinds,'capture','continued'},'Unknown debug-event record')
        if kind in kinds:
            require(pending is None and event['event_id']>last_event,'Debug event arrived before its predecessor continued')
            if kind=='process':
                require(event['pid'] not in active,'Duplicate live debuggee');active.add(event['pid'])
            require(event['pid'] in active,'Unknown/exited process owns debug event')
            pending=event
        elif kind=='capture':
            require(pending is not None and pending['type']=='exception' and event['event_id']==pending['event_id']
                    and event['pid']==pending['pid'] and event['tid']==pending['tid'],'Dump is not between its stopped event and continuation')
        else:
            require(event['pid'] in active and event['event_id']>last_event and 1<=event['kind']<=9,'Unknown process/event continuation')
            if pending is not None:
                require(event['event_id']==pending['event_id'] and event['pid']==pending['pid'] and event['tid']==pending['tid']
                        and event['kind']==kinds[pending['type']], 'Continuation does not close the recorded event')
                require(event['status']==(pending['continued_as'] if pending['type']=='exception' else 0x10002),'Actual continuation changed exception disposition')
                if pending['type']=='exit':active.remove(event['pid'])
                pending=None
            else:
                require(event['kind'] not in kinds.values() and event['status']==0x10002,'Missing primary debug event before continuation')
            last_event=event['event_id']
    require(pending is None and (end['timed_out'] or not active),'Missing event continuation/process closure')
    exits = [e for e in events if e.get('type')=='exit']
    require(len({e['pid'] for e in exits})==len(exits) and all(e['pid'] in pids for e in exits), 'Invalid exit inventory')
    if end['timed_out']:
        require(end['effective_exit']==124 and end['elapsed_ms']>=start['timeout_ms'], 'Timeout relabelled as success')
    else:
        require(end['all_processes_exited'] and {e['pid'] for e in exits}==pids and end['elapsed_ms']<=start['timeout_ms'], 'Incomplete/late process exit inventory')
        root_exit = next(e['code'] for e in exits if e['pid']==end['root_pid'])
        nonzero = [e['code'] for e in exits if e['code']]
        require(end['root_exit']==root_exit and end['effective_exit']==(nonzero[0] if nonzero else root_exit), 'Nonzero child/root exit swallowed')
    exceptions = [e for e in events if e.get('type')=='exception']
    require(len({e['event_id'] for e in exceptions})==len(exceptions), 'Duplicate exception event')
    for event in exceptions:
        require(event['pid'] in pids and event['tid']>0 and event['continued_as']==(0x10002 if event['loader_breakpoint'] else NOT_HANDLED), 'Exception handling was swallowed/rewritten')
        require(not event['loader_breakpoint'] or event['first_chance'] and event['code']==0x80000003, 'Fault disguised as loader breakpoint')
    required = [e for e in exceptions if not e['loader_breakpoint'] and (e['code']==ACCESS_VIOLATION or not e['first_chance'])]
    captures = [e for e in events if e.get('type')=='capture']
    require(len(captures)<=8 and sorted(e['event_id'] for e in captures)==sorted(e['event_id'] for e in required), 'Exception capture inventory incomplete/duplicated')
    summaries=[]
    for capture in captures:
        event=next(e for e in required if e['event_id']==capture['event_id'])
        require(capture['pid']==event['pid'] and capture['tid']==event['tid'] and capture['capture_exit']==0
                and not capture['timed_out'] and 0<=capture['capture_ms']<=CAPTURE_MS and capture['capture_limit_ms']==CAPTURE_MS
                and capture['helper_pid']>0 and capture['helper_joined'] and not capture['helper_terminated']
                and not capture['helper_control'], 'Failed/late/wrong-owner dump capture')
        prefix=capture['prefix']
        context=safe_file(root,prefix+'.context').read_bytes()
        exception=safe_file(root,prefix+'.exception').read_bytes()
        require(len(context)==capture['context_bytes']==1232 and len(exception)==capture['exception_bytes']==152, 'Raw SDK context/exception size mismatch')
        require(struct.unpack_from('<I',exception)[0]==event['code'] and struct.unpack_from('<Q',exception,16)[0]==event['address'], 'Raw exception disagrees with event')
        registers={field:struct.unpack_from('<Q',context,offset)[0] for field,offset in (('rip',248),('rsp',152),('rbp',160))}
        dump=safe_file(root,prefix+'.dmp')
        identity=dump_identity(dump.read_bytes())
        require(identity['thread_id']==event['tid'] and identity['code']==event['code'] and identity['address']==event['address'], 'Minidump exception does not match actual event')
        count=struct.unpack_from('<I',exception,24)[0]
        require(count<=15 and identity['flags']==struct.unpack_from('<I',exception,4)[0]
                and identity['nested_record']==0 and identity['parameters']==list(struct.unpack_from('<'+'Q'*count,exception,32)),
                'Minidump exception flags/parameters differ from retained original record')
        require(all(identity[k]==registers[k] for k in ('rip','rsp','rbp')), 'Minidump fault registers do not match stopped thread')
        summaries.append({'event_id':event['event_id'],'pid':event['pid'],'first_chance':event['first_chance'],
                          'dump':dump.name,'sha256':sha(dump),'bytes':dump.stat().st_size,'identity':identity})
    return {'processes':processes,'exits':exits,'captures':summaries,'timed_out':end['timed_out'],
            'effective_exit':end['effective_exit'],'elapsed_ms':end['elapsed_ms']}

def verify_dump_timeout_control(events: list[dict], receipt: dict) -> dict:
    """Only the deliberately hung dump writer may use this failure reader."""
    captures=[e for e in events if e.get('type')=='capture']
    require(len(captures)==1 and events[0]['schema']==SCHEMA and events[-1]['type']=='end', 'Missing hung-writer control receipt')
    capture=captures[0];end=events[-1]
    start=events[0]
    require(start['broker_pid']==receipt['broker_pid'] and start['timeout_ms']==receipt['timeout_ms']==DUMP_TIMEOUT_CONTROL_MS
            and start['command_line']==' '.join(windows_quote(value) for value in receipt['debuggee_command']),
            'Hung-writer process/source command receipt mismatch')
    require(capture['helper_control'] and capture['capture_limit_ms']==1000 and capture['timed_out']
            and capture['helper_pid']>0 and capture['helper_joined'] and capture['helper_terminated']
            and capture['capture_exit']==124 and 0<capture['capture_ms']<=1000, 'Hung writer was not terminated and joined within its control bound')
    require(end['errors']==1 and end['effective_exit']==receipt['returncode']==74 and not receipt['outer_timeout'],
            'Hung writer was incorrectly reported as successful execution')
    exception=[e for e in events if e.get('type')=='exception' and e['event_id']==capture['event_id']]
    continued=[e for e in events if e.get('type')=='continued' and e['event_id']==capture['event_id']]
    require(len(exception)==len(continued)==1 and exception[0]['code']==ACCESS_VIOLATION and exception[0]['first_chance']
            and exception[0]['pid']==capture['pid']==continued[0]['pid']
            and exception[0]['tid']==capture['tid']==continued[0]['tid']
            and exception[0]['continued_as']==continued[0]['status']==NOT_HANDLED
            and events.index(exception[0])<events.index(capture)<events.index(continued[0]),
            'Hung-writer control did not forward the intended fault')
    return {'expected_diagnostic_failure':True,'helper_pid':capture['helper_pid'],'helper_joined':True,
            'helper_terminated':True,'capture_ms':capture['capture_ms'],'effective_exit':74}

def verify_control(mode: str, result: dict) -> None:
    captures=result['captures']; exits=result['exits']
    if mode=='normal':
        require(result['effective_exit']==0 and not captures and len(exits)==1, 'Positive control did not exit normally')
    elif mode=='handled':
        require(result['effective_exit']==0 and len(captures)==1 and captures[0]['first_chance']
                and captures[0]['identity']['code']==ACCESS_VIOLATION, 'Handled first-chance control was swallowed/terminated')
    elif mode in ('crash','child-crash'):
        require(result['effective_exit']==ACCESS_VIOLATION and len(captures)==2
                and [c['first_chance'] for c in captures]==[True,False]
                and captures[0]['pid']==captures[1]['pid']
                and all(c['identity']['code']==ACCESS_VIOLATION for c in captures), 'Negative control lacks intended unhandled access violation')
        require(len(exits)==(2 if mode=='child-crash' else 1), 'Descendant control process inventory mismatch')
        if mode=='child-crash':
            root=next(p['pid'] for p in result['processes'] if p['root'])
            require(captures[0]['pid']!=root, 'Child crash incorrectly attributed to launcher')
    elif mode=='hang':
        require(result['timed_out'] and result['effective_exit']==124 and not captures, 'Deadline control did not fail for its intended reason')
    else: raise ValueError('Unknown crash control')
