#!/usr/bin/env python3
"""Synthetic reducer controls and real Git object proofs, never Windows runtime proof."""
import copy
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest import mock

import windows_crash_contract as contract
import run_windows_crash_capture as campaign

CODE=contract.ACCESS_VIOLATION

def synthetic_dump(code=CODE,tid=7,address=0x140001234,module_name='C:\\synthetic-control.exe'):
    exception_at,thread_at,module_at,context_at,stack_at,name_at=68,236,288,400,1632,1760
    module=module_name.encode('utf-16-le')
    data=bytearray(name_at+4+len(module))
    struct.pack_into('<IIIIIIQ',data,0,0x504D444D,0xA793,3,32,0,0,0x1000)
    for i,row in enumerate(((6,168,exception_at),(3,52,thread_at),(4,112,module_at))):
        struct.pack_into('<III',data,32+i*12,*row)
    struct.pack_into('<I',data,exception_at,tid)
    struct.pack_into('<I',data,exception_at+8,code)
    struct.pack_into('<Q',data,exception_at+24,address)
    struct.pack_into('<II',data,exception_at+160,1232,context_at)
    struct.pack_into('<I',data,context_at+48,0x10003F)
    for offset,value in ((248,address),(152,0x200020),(160,0x200030)):
        struct.pack_into('<Q',data,context_at+offset,value)
    struct.pack_into('<II',data,thread_at,1,tid)
    struct.pack_into('<Q',data,thread_at+4+24,0x200000)
    struct.pack_into('<II',data,thread_at+4+32,128,stack_at)
    struct.pack_into('<II',data,thread_at+4+40,1232,context_at)
    struct.pack_into('<I',data,module_at,1)
    struct.pack_into('<QI',data,module_at+4,0x140000000,0x100000)
    struct.pack_into('<I',data,module_at+4+20,name_at)
    struct.pack_into('<I',data,name_at,len(module));data[name_at+4:]=module
    raw_exception=bytearray(152)
    struct.pack_into('<I',raw_exception,0,code);struct.pack_into('<Q',raw_exception,16,address)
    return bytes(data),bytes(data[context_at:context_at+1232]),bytes(raw_exception)

class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)

    def fixture(self,mode='crash'):
        pid,tid=10,7;child=mode=='child-crash'
        image=getattr(self,'control_image','C:\\synthetic-control.exe')
        self.events=[{'type':'start','schema':contract.SCHEMA,'broker_pid':99,'timeout_ms':15000,
                      'command_line':contract.windows_quote(image)+' "'+mode+'"'},
                     {'type':'process','pid':pid,'tid':tid,'root':True,'image':image,'base':0x140000000}]
        if child:
            pid=11;self.events.append({'type':'process','pid':pid,'tid':tid,'root':False,'image':image,'base':0x140000000})
        chances=[] if mode in ('normal','hang') else [True] if mode=='handled' else [True,False]
        for index,chance in enumerate(chances,2):
            prefix='fault-'+str(index)
            dump,context,exception=synthetic_dump(module_name=image)
            for suffix,blob in (('dmp',dump),('context',context),('exception',exception)):
                (self.root/(prefix+'.'+suffix)).write_bytes(blob)
            self.events.extend([
                {'type':'exception','event_id':index,'pid':pid,'tid':tid,'first_chance':chance,
                 'code':CODE,'address':0x140001234,'loader_breakpoint':False,'continued_as':contract.NOT_HANDLED},
                {'type':'capture','event_id':index,'pid':pid,'tid':tid,'prefix':prefix,'capture_exit':0,
                 'capture_ms':10,'timed_out':False,'context_bytes':1232,'exception_bytes':152,
                 'helper_pid':91,'helper_joined':True,'helper_terminated':False,'helper_control':False,'capture_limit_ms':15000}])
        code=CODE if mode in ('crash','child-crash') else 124 if mode=='hang' else 0
        if mode!='hang':
            self.events.append({'type':'exit','pid':pid,'tid':tid,'code':code})
            if child:self.events.append({'type':'exit','pid':10,'tid':tid,'code':code})
        self.events.append({'type':'end','root_pid':10,'root_exit':259 if mode=='hang' else code,'effective_exit':code,
                            'timed_out':mode=='hang','errors':0,'all_processes_exited':mode!='hang',
                            'elapsed_ms':15000 if mode=='hang' else 40})
        expanded=[self.events[0]];sequence=0;pending=None
        for event in self.events[1:-1]:
            if event['type'] in ('process','exception','exit'):
                sequence+=1;event['event_id']=sequence
                pending={'type':'continued','event_id':sequence,'pid':event['pid'],'tid':event['tid'],
                         'kind':{'process':3,'exception':1,'exit':5}[event['type']],
                         'status':event.get('continued_as',0x10002)}
                expanded.append(event)
                if event['type']!='exception':expanded.append(pending);pending=None
            elif event['type']=='capture':
                event['event_id']=sequence;expanded.extend((event,pending));pending=None
        self.events=expanded+[self.events[-1]]
        self.receipt={'broker_pid':99,'timeout_ms':15000,'returncode':code,'outer_timeout':False,
                      'debuggee_command':[image,mode]}
        return contract.verify_capture(self.root,self.events,self.receipt)

    def reject(self,pattern):
        with self.assertRaisesRegex(ValueError,pattern):contract.verify_capture(self.root,self.events,self.receipt)

    def test_positive_negative_handled_child_and_deadline_controls(self):
        for mode in ('normal','handled','crash','child-crash','hang'):
            with self.subTest(mode=mode):contract.verify_control(mode,self.fixture(mode))

    def test_zero_exit_cannot_replace_actual_crash(self):
        self.fixture();self.events[-1]['effective_exit']=0;self.receipt['returncode']=0
        self.reject('Nonzero')

    def test_missing_child_exit_is_incomplete(self):
        self.fixture('child-crash');self.events=[e for e in self.events if not(e['type']=='exit' and e['pid']==11)]
        self.reject('Missing primary')

    def test_wrong_thread_in_actual_dump_refused(self):
        self.fixture();data=bytearray((self.root/'fault-2.dmp').read_bytes());struct.pack_into('<I',data,68,8)
        (self.root/'fault-2.dmp').write_bytes(data);self.reject('Faulting thread')

    def test_wrong_exception_code_in_actual_dump_refused(self):
        self.fixture();data=bytearray((self.root/'fault-2.dmp').read_bytes());struct.pack_into('<I',data,76,0xE0001234)
        (self.root/'fault-2.dmp').write_bytes(data);self.reject('Minidump exception')

    def test_exception_stack_must_be_retained(self):
        self.fixture();data=bytearray((self.root/'fault-2.dmp').read_bytes());struct.pack_into('<I',data,236+4+32,0)
        (self.root/'fault-2.dmp').write_bytes(data);self.reject('stack is absent')

    def test_fault_registers_are_crossjoined(self):
        self.fixture();data=bytearray((self.root/'fault-2.context').read_bytes());struct.pack_into('<Q',data,248,99)
        (self.root/'fault-2.context').write_bytes(data);self.reject('fault registers')

    def test_raw_exception_record_cannot_be_relabelled(self):
        self.fixture();data=bytearray((self.root/'fault-2.exception').read_bytes());struct.pack_into('<I',data,0,99)
        (self.root/'fault-2.exception').write_bytes(data);self.reject('Raw exception')

    def test_missing_second_chance_dump_is_not_pass(self):
        self.fixture();self.events=[e for e in self.events if not(e['type']=='capture' and e['event_id']==3)]
        self.reject('capture inventory')

    def test_first_chance_must_be_forwarded_to_application(self):
        self.fixture('handled');next(e for e in self.events if e['type']=='exception')['continued_as']=0x10002
        self.reject('continuation changed')

    def test_fault_cannot_be_called_loader_breakpoint(self):
        self.fixture();event=next(e for e in self.events if e['type']=='exception')
        event.update(loader_breakpoint=True,continued_as=0x10002)
        next(e for e in self.events if e['type']=='continued' and e['kind']==1)['status']=0x10002
        self.reject('disguised')

    def test_capture_deadline_is_strict(self):
        self.fixture();next(e for e in self.events if e['type']=='capture')['capture_ms']=15001
        self.reject('Failed/late')

    def test_process_deadline_is_strict(self):
        self.fixture('normal');self.events[-1]['elapsed_ms']=15001
        self.reject('Incomplete/late')

    def test_outer_kill_and_infrastructure_failure_are_not_pass(self):
        self.fixture();self.receipt['outer_timeout']=True;self.reject('outer timeout')
        self.receipt['outer_timeout']=False;self.events[-1]['errors']=1;self.reject('incomplete capture')

    def test_unknown_owner_and_missing_continuation_refused(self):
        self.fixture();next(e for e in self.events if e['type']=='exception')['pid']=777
        self.reject('Unknown/exited process')
        self.fixture();self.events=[e for e in self.events if not(e['type']=='continued' and e['kind']==1)]
        self.reject('predecessor continued')

    def test_command_cannot_change_after_process_receipt(self):
        self.fixture();self.receipt['debuggee_command'][-1]='normal'
        self.reject('command differs')

    def test_duplicate_json_keys_refused(self):
        path=self.root/'ambiguous.jsonl';path.write_text('{"type":"start","type":"end"}\n')
        with self.assertRaisesRegex(ValueError,'Duplicate JSON'):contract.read_events(path)

    def test_unjoined_helper_is_never_pass(self):
        self.fixture();next(e for e in self.events if e['type']=='capture')['helper_joined']=False
        self.reject('Failed/late')

    def test_hung_dump_writer_requires_explicit_failure_and_join(self):
        self.fixture('handled')
        capture=next(e for e in self.events if e['type']=='capture')
        capture.update(helper_control=True,capture_limit_ms=1000,timed_out=True,helper_terminated=True,
                       capture_exit=124,capture_ms=505)
        self.events[-1].update(errors=1,effective_exit=74)
        self.receipt['returncode']=74
        self.assertTrue(contract.verify_dump_timeout_control(self.events,self.receipt)['expected_diagnostic_failure'])
        capture['helper_joined']=False
        with self.assertRaisesRegex(ValueError,'terminated and joined'):contract.verify_dump_timeout_control(self.events,self.receipt)

    def test_windows_argument_quoting_preserves_literal_paths(self):
        self.assertEqual(contract.windows_quote('C:\\some path\\'), '"C:\\some path\\\\"')
        self.assertEqual(contract.windows_quote('a"b'), '"a\\"b"')

    def test_duplicate_event_and_dump_paths_refused(self):
        self.fixture();self.events.insert(-1,copy.deepcopy(next(e for e in self.events if e['type']=='exception')))
        self.reject('predecessor continued')
        self.fixture();next(e for e in self.events if e['type']=='capture')['prefix']='../escaped'
        self.reject('Unsafe')

    def test_truncated_or_duplicate_dump_stream_refused(self):
        self.fixture();data=(self.root/'fault-2.dmp').read_bytes()
        for broken in (data[:100],data[:32],b'not-a-dump'):
            with self.assertRaises(ValueError):contract.dump_identity(broken)
        broken=bytearray(data);struct.pack_into('<I',broken,44,6)
        with self.assertRaisesRegex(ValueError,'Duplicate'):contract.dump_identity(broken)

    def test_environment_removes_only_credential_bearing_values(self):
        environment={'PATH':'C:\\safe','SYSTEMROOT':'C:\\Windows','GITHUB_SHA':'a'*40,
                     'GITHUB_TOKEN':'must-not-leak','ACTIONS_RUNTIME_TOKEN':'also-secret','AWS_SECRET_ACCESS_KEY':'secret',
                     'HTTPS_PROXY':'https://name:password@proxy.invalid','HTTP_PROXY':'http://proxy.invalid',
                     'GIT_CONFIG_VALUE_0':'authorization header','RANDOM_SETTING':'safe'}
        clean,removed=contract.child_environment(environment)
        self.assertEqual(set(clean),{'PATH','SYSTEMROOT','GITHUB_SHA','HTTP_PROXY','RANDOM_SETTING'})
        self.assertEqual(set(removed),set(environment)-set(clean))
        self.assertNotIn('must-not-leak',json.dumps({'removed':removed,'clean':clean}))

    def bound_fixture(self,mode='crash'):
        result=self.fixture(mode)
        self.images={'C:\\synthetic-control.exe':{'sha256':'a'*64,'bytes':100}}
        self.identities=copy.deepcopy(self.images);self.runtimes={}
        self.result=result
        return self.bind()

    def bind(self):
        return contract.verify_module_bindings(self.events,self.receipt,self.identities,self.images,self.runtimes,self.result)

    def test_actual_process_and_dump_modules_bind_to_pinned_bytes(self):
        result=self.bound_fixture();self.assertEqual(result['images'],['c:\\synthetic-control.exe'])
        self.identities['C:\\synthetic-control.exe']['sha256']='b'*64
        with self.assertRaisesRegex(ValueError,'module bytes mismatch'):self.bind()

    def test_substituted_engine_and_unknown_process_refused(self):
        self.bound_fixture()
        next(e for e in self.events if e['type']=='process')['image']='C:\\substituted-engine.exe'
        with self.assertRaisesRegex(ValueError,'Root debuggee differs'):self.bind()
        self.bound_fixture('child-crash')
        next(e for e in self.events if e['type']=='process' and not e['root'])['image']='C:\\other.exe'
        with self.assertRaisesRegex(ValueError,'Unexpected debuggee'):self.bind()

    def test_both_runtime_modules_required_on_actual_engine_owner(self):
        self.bound_fixture('normal');self.images['C:\\synthetic-control.exe']['requires_runtime']=True
        for index,name in enumerate(('native','rapier')):
            path='C:\\runtime\\'+name+'.dll';identity={'sha256':str(index)*64,'bytes':123+index}
            self.runtimes[path]=identity;self.identities[path]=identity.copy()
            self.events.insert(-2,{'type':'module','pid':10,'base':0x150000000+index*0x100000,'path':path})
        self.assertEqual(self.bind()['runtime_processes'],[10])
        self.identities['C:\\runtime\\native.dll']['sha256']='9'*64
        with self.assertRaisesRegex(ValueError,'module bytes mismatch'):self.bind()
        self.identities['C:\\runtime\\native.dll']=self.runtimes['C:\\runtime\\native.dll'].copy()
        self.events=[e for e in self.events if e.get('path')!='C:\\runtime\\rapier.dll']
        del self.identities['C:\\runtime\\rapier.dll']
        with self.assertRaisesRegex(ValueError,'both selected'):self.bind()

    def test_substituted_module_path_refused_even_with_same_basename(self):
        self.bound_fixture('normal')
        self.runtimes={'C:\\runtime\\native.dll':{'sha256':'b'*64,'bytes':123}}
        self.events.insert(-2,{'type':'module','pid':10,'base':0x150000000,'path':'C:\\elsewhere\\native.dll'})
        self.identities['C:\\elsewhere\\native.dll']={'sha256':'b'*64,'bytes':123}
        with self.assertRaisesRegex(ValueError,'substituted path'):self.bind()

    def test_dump_cannot_use_unloaded_or_reused_module_base(self):
        self.bound_fixture()
        self.events.insert(3,{'type':'unload','pid':10,'base':0x140000000})
        with self.assertRaisesRegex(ValueError,'actual load event'):self.bind()
        self.events.insert(4,{'type':'module','pid':10,'base':0x140000000,'path':'C:\\replacement.dll'})
        self.identities['C:\\replacement.dll']={'sha256':'c'*64,'bytes':456}
        with self.assertRaisesRegex(ValueError,'actual load event'):self.bind()

    def test_unbound_or_missing_module_identity_refused(self):
        self.bound_fixture('normal');self.identities['C:\\invented.dll']={'sha256':'d'*64,'bytes':222}
        with self.assertRaisesRegex(ValueError,'identity inventory'):self.bind()
        self.bound_fixture();self.result['captures'][0]['identity']['modules'][0]['path']='C:\\fabricated.dll'
        with self.assertRaisesRegex(ValueError,'actual load event'):self.bind()

    def test_full_memory_dump_flags_refused(self):
        self.fixture();data=bytearray((self.root/'fault-2.dmp').read_bytes());struct.pack_into('<Q',data,24,0x1002)
        with self.assertRaisesRegex(ValueError,'bounded MiniDump'):contract.dump_identity(data)

    def test_exception_parameters_crossjoin_raw_record(self):
        self.fixture();data=bytearray((self.root/'fault-2.exception').read_bytes())
        struct.pack_into('<I',data,24,1);struct.pack_into('<Q',data,32,123)
        (self.root/'fault-2.exception').write_bytes(data);self.reject('flags/parameters')

class ManifestTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        (self.root/'raw.log').write_text('original evidence\n')
        campaign.write(self.root/'MANIFEST.json',{'raw.log':{'sha256':contract.sha(self.root/'raw.log'),'bytes':18}})

    def test_exact_original_manifest_passes(self):
        campaign.verify_manifest(self.root)

    def test_missing_added_or_changed_raw_evidence_refused(self):
        (self.root/'raw.log').write_text('altered evidence\n')
        with self.assertRaisesRegex(ValueError,'digest mismatch'):campaign.verify_manifest(self.root)
        (self.root/'raw.log').unlink()
        with self.assertRaisesRegex(ValueError,'inventory mismatch'):campaign.verify_manifest(self.root)
        (self.root/'invented.log').write_text('unknown')
        with self.assertRaisesRegex(ValueError,'inventory mismatch'):campaign.verify_manifest(self.root)

    def test_incomplete_campaign_is_not_an_offline_pass(self):
        campaign.write(self.root/'campaign.json',{'schema':'play-windows-crash-campaign-v1','completed':False})
        campaign.write(self.root/'MANIFEST.json',{path.name:{'sha256':contract.sha(path),'bytes':path.stat().st_size}
            for path in self.root.iterdir() if path.name!='MANIFEST.json'})
        with self.assertRaisesRegex(ValueError,'campaign is incomplete'):campaign.verify_directory(self.root,'a'*40)

class OfflineCompositionTests(unittest.TestCase):
    """Compose synthetic records; real Git/native provenance has separate controls."""
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        self.head='a'*40;self.canonical={}
        report=self.report={'schema':'play-windows-crash-campaign-v1','completed':True,'errors':[],'fixture_attempts':1,
            'original_failed_run':41175131563,'original_failed_source':campaign.BASE,'original_failure_still_blocking':True,
            'paths':{'source':'C:\\source','output':'C:\\evidence'},'source':{'commit':self.head,'tree':'b'*40,'inputs':{}},
            'runtime':{},'controls':{},'tools':{},'build':{'builds':[]},'assertion_footer_present':True,
            'status':'no_process_failure_observed',
            'engine':{'version':campaign.windows.GODOT_VERSION,'archive_sha512':campaign.windows.GODOT_SHA512,
                      'archive_bytes':campaign.ENGINE_ARCHIVE_BYTES,'executables':campaign.ENGINE_FILES}}
        (self.root/'tools').mkdir();(self.root/'version.log').write_text(campaign.windows.GODOT_VERSION+'\n')
        for role,name,extension in (('broker','windows_crash_debugger','cpp'),('control','windows_crash_control','c')):
            binary=self.root/'tools'/f'{name}.exe';binary.write_bytes(b'MZsynthetic-'+role.encode())
            source_path=f'tools/play/{name}.{extension}';self.canonical[source_path]=b'synthetic source\n'
            tool={'path':'C:\\evidence\\tools\\'+name+'.exe','sha256':contract.sha(binary),'bytes':binary.stat().st_size}
            report['tools'][role]=tool
            report['build']['builds'].append({'source':source_path,'returncode':0,'seconds':1,
                'source_sha256':hashlib.sha256(self.canonical[source_path]).hexdigest(),
                'binary_sha256':tool['sha256'],'binary_bytes':tool['bytes']})
        campaign.write(self.root/'tools/build.json',report['build'])
        for path in (campaign.windows.NATIVE,campaign.windows.RAPIER):
            report['source']['inputs'][path]={'working_sha256':'d'*64,'working_bytes':1234}
        for name in (*('control-'+mode for mode in campaign.CONTROL_MODES),'control-dump-writer-timeout','import',campaign.FIXTURE):
            self.case(name)
        campaign.seal(self.root,report)
        patch=mock.patch.object(campaign,'verify_source_pack',return_value=self.canonical);patch.start();self.addCleanup(patch.stop)
        patch=mock.patch.object(campaign,'runtime_proof');patch.start();self.addCleanup(patch.stop)

    def case(self,name):
        directory=self.root/name;directory.mkdir();control=name.startswith('control-');mode=name.removeprefix('control-')
        case=CaptureTests();case.root=directory;case.control_image=self.report['tools']['control']['path']
        case.fixture('handled' if mode=='dump-writer-timeout' else mode if control else 'normal')
        events=case.events;receipt=case.receipt;images,runtimes=campaign.bindings(self.report,controls=control)
        limit=500 if mode=='hang' else 15000 if control else 240000 if name=='import' else 180000
        receipt['timeout_ms']=events[0]['timeout_ms']=limit
        if mode=='hang':events[-1]['elapsed_ms']=limit
        if mode=='dump-writer-timeout':
            receipt['debuggee_command'][-1]='crash';receipt['returncode']=74
            capture=next(event for event in events if event['type']=='capture')
            capture.update(helper_control=True,capture_limit_ms=1000,timed_out=True,helper_terminated=True,
                           capture_exit=124,capture_ms=505)
            events=[event for event in events if event['type']!='exit' and not(event['type']=='continued' and event['kind']==5)]
            events[-1].update(errors=1,effective_exit=74,root_exit=259,all_processes_exited=False)
        if not control:
            console='C:\\evidence\\engine\\Godot_v4.7-stable_win64_console.exe'
            gui='C:\\evidence\\engine\\Godot_v4.7-stable_win64.exe'
            receipt['debuggee_command']=[console,'--headless','--path','C:\\source\\godot',
                *(['--editor','--quit'] if name=='import' else ['--script','res://tests/'+campaign.FIXTURE+'.gd'])]
            process=next(event for event in events if event['type']=='process');process['image']=console
            rows=[process,{'type':'process','pid':11,'tid':8,'root':False,'image':gui,'base':0x150000000},
                  *({'type':'module','pid':11,'tid':8,'path':path,'base':0x160000000+index*0x100000}
                    for index,path in enumerate(runtimes)),
                  {'type':'exit','pid':11,'tid':8,'code':0},{'type':'exit','pid':10,'tid':7,'code':0}]
            events=[events[0]]
            for sequence,event in enumerate(rows,1):
                event['event_id']=sequence;events.append(event)
                events.append({'type':'continued','event_id':sequence,'pid':event['pid'],'tid':event['tid'],
                               'kind':{'process':3,'module':6,'exit':5}[event['type']],'status':0x10002})
            events.append(case.events[-1])
        events[0]['command_line']=' '.join(contract.windows_quote(arg) for arg in receipt['debuggee_command'])
        receipt['broker_command']=[self.report['tools']['broker']['path'],'--output','C:\\evidence\\'+name,
                                   '--timeout-ms',str(limit),'--',*receipt['debuggee_command']]
        identities={path:{'sha256':identity['sha256'],'bytes':identity['bytes']} for path,identity in (images|runtimes).items()}
        result=contract.verify_dump_timeout_control(events,receipt) if mode=='dump-writer-timeout' else contract.verify_capture(directory,events,receipt)
        result['module_bindings']=contract.verify_module_bindings(events,receipt,identities,images,runtimes,result)
        (directory/'events.jsonl').write_text(''.join(json.dumps(event)+'\n' for event in events))
        campaign.write(directory/'process.json',receipt);campaign.write(directory/'module-identities.json',identities)
        campaign.write(directory/'verified.json',result)
        log=('CRASH_CONTROL_READY\n'*(2 if mode=='child-crash' else 1)+('CRASH_CONTROL_HANDLED\n' if mode=='handled' else '')) if control else ''
        if name==campaign.FIXTURE:log='LIQUID_DESKTOP_DEFAULT_HOST: 86 assertions; 0 failures\n'
        (directory/'engine.log').write_text(log)
        if control:self.report['controls'][mode]=result
        else:self.report['import' if name=='import' else 'fixture']=result

    def test_full_offline_composition_reads_every_original_case(self):
        self.assertEqual(campaign.verify_directory(self.root,self.head)['status'],'no_process_failure_observed')

    def test_resealed_wrong_actual_fixture_command_is_refused(self):
        path=self.root/campaign.FIXTURE/'process.json';receipt=contract.read_json(path);receipt['debuggee_command'][-1]='res://tests/neutral_only.gd'
        campaign.write(path,receipt);campaign.seal(self.root,self.report)
        with self.assertRaisesRegex(ValueError,'prescribed attempt'):campaign.verify_directory(self.root,self.head)

    def test_resealed_missing_nonzero_control_is_refused(self):
        del self.report['controls']['crash'];campaign.seal(self.root,self.report)
        with self.assertRaisesRegex(ValueError,'control inventory'):campaign.verify_directory(self.root,self.head)

    def test_resealed_substituted_native_module_is_refused(self):
        path=self.root/campaign.FIXTURE/'module-identities.json';identities=contract.read_json(path)
        native=next(key for key in identities if 'cybersand_native.windows' in key);identities[native]['sha256']='f'*64
        campaign.write(path,identities);campaign.seal(self.root,self.report)
        with self.assertRaisesRegex(ValueError,'module bytes mismatch'):campaign.verify_directory(self.root,self.head)

    def test_assertion_footer_cannot_overwrite_actual_process_failure(self):
        directory=self.root/campaign.FIXTURE;receipt=contract.read_json(directory/'process.json')
        events=contract.read_events(directory/'events.jsonl');receipt['returncode']=CODE
        for event in events:
            if event['type']=='exit':event['code']=CODE
        events[-1].update(root_exit=CODE,effective_exit=CODE)
        result=contract.verify_capture(directory,events,receipt)
        result['module_bindings']=contract.verify_module_bindings(events,receipt,
            contract.read_json(directory/'module-identities.json'),*campaign.bindings(self.report),result)
        campaign.write(directory/'process.json',receipt);campaign.write(directory/'verified.json',result)
        (directory/'events.jsonl').write_text(''.join(json.dumps(event)+'\n' for event in events))
        self.report['fixture']=result;campaign.seal(self.root,self.report)
        with self.assertRaisesRegex(ValueError,'nonzero process result'):campaign.verify_directory(self.root,self.head)
        self.report['status']='observed_process_failure';campaign.seal(self.root,self.report)
        self.assertEqual(campaign.verify_directory(self.root,self.head)['effective_exit'],CODE)

class SourcePackTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        base=Path(self.temp.name);self.root=base/'repo';self.root.mkdir();self.output=base/'evidence';self.output.mkdir()
        campaign.git(self.root,'init','-q');campaign.git(self.root,'config','user.name','Synthetic source control')
        campaign.git(self.root,'config','user.email','source@example.invalid')
        campaign.git(self.root,'config','core.autocrlf','false');campaign.git(self.root,'config','core.eol','lf')
        (self.root/'sample.py').write_text('print("synthetic")\n')
        (self.root/'unselected.txt').write_text('not executable scope\n')
        campaign.git(self.root,'add','.');campaign.git(self.root,'commit','-qm','synthetic source proof')
        self.head=campaign.git(self.root,'rev-parse','HEAD').decode().strip()
        for name,value in (('ROOT',self.root),('BASE',self.head),('SCOPES',('sample.py',))):
            patch=mock.patch.object(campaign,name,value);patch.start();self.addCleanup(patch.stop)
        self.source=campaign.source_archive(self.output,self.head)

    def test_real_git_pack_authenticates_commit_tree_and_complete_scope(self):
        campaign.verify_source_pack(self.output,self.source,self.head)
        self.assertEqual(set(self.source['inputs']),{'sample.py'})

    def test_missing_selected_source_refused(self):
        self.source['inputs'].clear()
        with self.assertRaisesRegex(ValueError,'Complete scoped'):campaign.verify_source_pack(self.output,self.source,self.head)

    def test_wrong_tree_or_source_digest_refused(self):
        changed=copy.deepcopy(self.source);changed['tree']='f'*40
        with self.assertRaisesRegex(ValueError,'tree proof'):campaign.verify_source_pack(self.output,changed,self.head)
        changed=copy.deepcopy(self.source);changed['inputs']['sample.py']['canonical_sha256']='0'*64
        with self.assertRaisesRegex(ValueError,'blob proof'):campaign.verify_source_pack(self.output,changed,self.head)

    def test_modified_archive_or_working_source_refused(self):
        original=(self.output/'source.pack').read_bytes();(self.output/'source.pack').write_bytes(original[:-1])
        with self.assertRaisesRegex(ValueError,'pack identity'):campaign.verify_source_pack(self.output,self.source,self.head)
        (self.root/'sample.py').write_text('modified\n')
        with self.assertRaisesRegex(ValueError,'Executed input changed'):campaign.source_unchanged(self.source)

if __name__=='__main__':
    unittest.main(verbosity=2)
