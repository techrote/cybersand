#!/usr/bin/env python3
"""Adverse controls for the external cold owner-command evidence reader."""
from __future__ import annotations
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import types
import unittest
from unittest import mock
import zipfile
import strata3_cold_launcher as cold


def request():
    value=json.loads((cold.ROOT/cold.REQUEST).read_text())
    value.update(armed=True,package_run_id=45721790366,package_artifact_id=123456,
        package_artifact_name='strata3-workbench-windows-evaluator-'+cold.APPLICATION+'-1',
        package_sha256='a'*64,package_bytes=100,manifest_sha256='b'*64)
    return value


def execution():
    cwd=r'D:\a\cybersand\build\Fresh owner extraction fd0830ab'
    comspec=r'C:\Windows\System32\cmd.exe'
    unix=1800000000.0;base=int((unix+11644473600)*10_000_000)
    def row(pid,parent,name,start,end):
        return {'pid':pid,'parent_pid':parent,'start_id':base+int(start*10_000_000),'image_path':name,
            'creation_filetime_100ns':base+int(start*10_000_000),'exit_filetime_100ns':base+int(end*10_000_000),
            'exited':True,'exit_code':0,'lifetime_seconds':end-start,'final_cpu_seconds':1.0}
    rows=[row(10,1,comspec,0,100),row(11,10,cold.ntpath.join(cwd,cold.CONSOLE),1,10),
          row(12,11,cold.ntpath.join(cwd,cold.GUI),2,9),
          row(13,10,cold.ntpath.join(cwd,cold.CONSOLE),11,99),row(14,13,cold.ntpath.join(cwd,cold.GUI),12,98)]
    samples=[];latest={}
    for at,selected in [(5,rows[:3]),(50,[rows[0],*rows[3:]])]:
        processes=[]
        for r in selected:
            p={k:r[k] for k in ('pid','parent_pid','start_id','image_path')}
            p.update(cpu_seconds=0.1 if at==5 else 0.2,rss_bytes=1024,os_peak_rss_bytes=1024)
            latest[(r['pid'],r['start_id'])]=p['cpu_seconds'];processes.append(p)
        samples.append({'elapsed_seconds':at,'processes':processes,'tree_rss_bytes':3072,'tree_cpu_seconds_observed':sum(latest.values())})
    resources={'schema':'strata-process-resources-v1','available':True,'scope':'observed_process_and_descendants',
        'root_pid':10,'root_start_id':base,'sample_interval_seconds':0.5,'sample_count':2,'samples':samples,
        'process_identities':[list(x) for x in sorted(latest)],'observed_cpu_seconds':sum(latest.values()),
        'peak_observed_tree_rss_bytes':3072,'observation_errors':[]}
    process={'schema':'strata3-cold-process-v1','label':'launcher','platform':'win32','pid':10,
        'executable':comspec,'cwd':cwd,'command':cold.command_line(comspec,cwd),'exit_code':0,'timed_out':False,
        'failure':None,'cleanup_errors':[],'timeout_seconds':180,'wall_seconds':100.1,'started_unix_seconds':unix,
        'resources':{k:v for k,v in resources.items() if k!='samples'}}
    admission={'source_revision':cold.APPLICATION,'workbench_script':'res://scripts/shared_workbench.gd',
        'world_generation':1,'worker_id':'-9223372036854775807','extent':[2048,2048],'strata_enabled':False}
    header='Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org\n'
    log=header+'Import completed\n'+header+'OpenGL API OpenGL ES 3.0 (ANGLE) - Compatibility - Using Device: Microsoft Basic Render Driver\n'
    log+='STRATA_WORKBENCH_LAUNCH_ADMITTED '+json.dumps(admission)+'\n'
    return process,{'schema':'strata3-cold-process-lifetimes-v1','rows':rows},resources,log


class ColdControls(unittest.TestCase):
    def reject(self,call):
        with self.assertRaises((RuntimeError,ValueError,KeyError)):call()

    def test_unarmed_cannot_execute(self):
        value=request();value.update(armed=False)
        for k in ('package_run_id','package_artifact_id','package_artifact_name','package_sha256','package_bytes','manifest_sha256'):value[k]=None
        self.assertEqual(cold.validate_request(value,armed=False),value)
        self.reject(lambda:cold.validate_request(value))

    def test_exact_request_source_and_watchdog(self):
        cold.validate_request(request())
        for key,value in [('application_source','0'*40),('timeout_seconds',600),('package_sha256','0'*64),('package_bytes',True),('package_filename','other.zip')]:
            item=request();item[key]=value;self.reject(lambda:cold.validate_request(item))

    def test_artifact_run_and_source(self):
        req=request();meta={'id':req['package_artifact_id'],'name':req['package_artifact_name'],'expired':False,
                            'workflow_run':{'id':req['package_run_id'],'head_sha':cold.APPLICATION}}
        cold.validate_metadata(meta,req)
        wrong=copy.deepcopy(meta);wrong['workflow_run']['head_sha']='0'*40
        self.reject(lambda:cold.validate_metadata(wrong,req))
        wrong=copy.deepcopy(meta);wrong['expired']=True
        self.reject(lambda:cold.validate_metadata(wrong,req))

    def test_portable_paths(self):
        self.assertEqual(str(cold.relative('safe/file.png')),str(Path('safe/file.png')))
        for name in ('/outside.png','C:/outside','safe\\outside','../outside','x/../y','x//y','x/CON.txt','x/file.','x/evil\x00name'):
            with self.subTest(name=name):self.reject(lambda:cold.relative(name))

    def test_symlink_ancestor_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)/'root';root.mkdir();outside=Path(tmp)/'outside';outside.mkdir();(outside/'x').write_text('x')
            try:(root/'link').symlink_to(outside,target_is_directory=True)
            except OSError:self.skipTest('Host does not permit unprivileged symlink creation')
            self.reject(lambda:cold.path_in(root,'link/x'))

    def test_nested_record_basename_is_not_ignored(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);(root/'cold-launch.json').write_text('{}')
            before=cold.evidence_inventory(root)
            (root/'nested').mkdir();(root/'nested/cold-launch.json').write_text('unregistered')
            after=cold.evidence_inventory(root)
            self.assertIn('nested/cold-launch.json',after)
            self.reject(lambda:cold.require(before==after,'Unregistered nested record'))

    def archive(self,folder,extra='extra/safe.txt'):
        path=folder/'package.zip'
        files={cold.LAUNCHER:b'command',cold.CONSOLE:b'console',cold.GUI:b'engine','godot/project.godot':b'project',extra:b'extra'}
        manifest={'schema':'strata3-workbench-evaluation-v1','source_commit':cold.APPLICATION,'source_tree':cold.TREE,
            'draft_hold':True,'files_sha256':{k:hashlib.sha256(v).hexdigest() for k,v in files.items()}}
        raw=json.dumps(manifest).encode();files[cold.MANIFEST]=raw
        with zipfile.ZipFile(path,'w') as archive:
            for name,data in files.items():archive.writestr(name,data)
        req=request();req.update(package_sha256=cold.sha(path),package_bytes=path.stat().st_size,manifest_sha256=hashlib.sha256(raw).hexdigest())
        return path,req

    def test_archive_and_exact_fresh_extraction(self):
        with tempfile.TemporaryDirectory() as tmp:
            path,req=self.archive(Path(tmp));manifest,files=cold.inspect_archive(path,req)
            destination=Path(tmp)/'fresh spaced folder';cold.extract_archive(path,destination,files)
            self.assertEqual(cold.snapshot(destination),files)
            self.reject(lambda:cold.extract_archive(path,destination,files))
            req['package_sha256']='0'*64;self.reject(lambda:cold.inspect_archive(path,req))

    def test_raw_zip_nul_rejected_before_truncation(self):
        with tempfile.TemporaryDirectory() as tmp:
            path,req=self.archive(Path(tmp),'extra/safe.txt')
            data=path.read_bytes().replace(b'extra/safe.txt',b'extra\x00safe.txt')
            path.write_bytes(data);req.update(package_sha256=cold.sha(path),package_bytes=len(data))
            with zipfile.ZipFile(path) as z:
                item=[x for x in z.infolist() if '\x00' in x.orig_filename][0]
                self.assertNotEqual(item.orig_filename,item.filename)
            self.reject(lambda:cold.inspect_archive(path,req))

    def test_raw_zip_backslash_rejected_on_all_hosts(self):
        with tempfile.TemporaryDirectory() as tmp:
            path,req=self.archive(Path(tmp),'extra/safe.txt')
            data=path.read_bytes().replace(b'extra/safe.txt',b'extra\\safe.txt')
            path.write_bytes(data);req.update(package_sha256=cold.sha(path),package_bytes=len(data))
            self.reject(lambda:cold.inspect_archive(path,req))

    def test_prepopulated_cache_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path,req=self.archive(Path(tmp),'godot/.godot/imported.bin')
            self.reject(lambda:cold.inspect_archive(path,req))

    def test_actual_ordered_tree_positive_and_cross_host_command(self):
        values=execution();result=cold.validate_execution(*values)
        self.assertEqual(result['cold_import_command_seconds'],9)
        self.assertEqual(result['ordinary_workbench_command_seconds'],88)
        self.assertIn(' /d /s /c ""D:\\a\\',values[0]['command'])

    def test_false_admission_or_error_rejected(self):
        values=execution()
        for old,new in [('[2048, 2048]','[320, 240]'),('"strata_enabled": false','"strata_enabled": true'),
                        ('"worker_id": "-9223372036854775807"','"worker_id": "0"')]:
            altered=list(copy.deepcopy(values));altered[3]=altered[3].replace(old,new)
            self.reject(lambda:cold.validate_execution(*altered))
        altered=list(values);altered[3]+='SCRIPT ERROR: hidden failure\n';self.reject(lambda:cold.validate_execution(*altered))

    def test_missing_or_live_engine_rejected(self):
        values=list(execution());values[1]['rows'].pop()
        self.reject(lambda:cold.validate_execution(*values))
        values=list(execution());values[1]['rows'][-1]['exited']=False
        self.reject(lambda:cold.validate_execution(*values))

    def test_other_runtime_or_wrong_parent_rejected(self):
        for key,value in [('image_path',r'C:\other\Godot_v4.7-stable_win64.exe'),('parent_pid',999)]:
            values=list(execution());values[1]['rows'][-1][key]=value
            self.reject(lambda:cold.validate_execution(*values))

    def test_changed_lifetime_or_overlapping_stages_rejected(self):
        values=list(execution());values[1]['rows'][1]['lifetime_seconds']+=1
        self.reject(lambda:cold.validate_execution(*values))
        values=list(execution());row=values[1]['rows'][1];row['exit_filetime_100ns']+=100000000;row['lifetime_seconds']+=10
        self.reject(lambda:cold.validate_execution(*values))

    def test_wrong_process_clock_rejected(self):
        values=list(execution());values[0]['started_unix_seconds']+=60
        self.reject(lambda:cold.validate_execution(*values))

    def test_unbounded_real_lifetime_cannot_hide_behind_short_wall(self):
        values=list(execution());root=values[1]['rows'][0]
        root['exit_filetime_100ns']+=2000000000;root['lifetime_seconds']+=200
        self.reject(lambda:cold.validate_execution(*values))

    def test_changed_resource_aggregate_rejected(self):
        values=list(execution());values[2]['samples'][0]['tree_cpu_seconds_observed']+=1
        self.reject(lambda:cold.validate_execution(*values))

    def test_wrong_command_or_timeout_rejected(self):
        for key,value in [('command','fake.exe --workbench'),('timed_out',True),('exit_code',1),('timeout_seconds',600)]:
            values=list(execution());values[0][key]=value;self.reject(lambda:cold.validate_execution(*values))

    def test_query_constructor_failure_precedes_process_creation(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp);exe=folder/'cmd.exe';exe.write_bytes(b'placeholder')
            with mock.patch.object(cold.sys,'platform','win32'),mock.patch.dict(cold.os.environ,{'ComSpec':str(exe)}),\
                 mock.patch.object(cold,'lifetime_reader',side_effect=RuntimeError('query constructor failed')),\
                 mock.patch.object(cold.subprocess,'Popen') as popen:
                self.reject(lambda:cold.execute_launcher(folder,folder/'evidence',mock.Mock()))
                popen.assert_not_called()
            receipt=json.loads((folder/'evidence/process.json').read_text())
            self.assertIn('query constructor failed',receipt['failure'])

    def test_tree_constructor_failure_cleans_owned_process_and_retains_cleanup_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp);exe=folder/'cmd.exe';exe.write_bytes(b'placeholder')
            reader=mock.Mock();reader.final_rows.return_value=[]
            process=mock.Mock(pid=123,returncode=None)
            metrics=mock.Mock();metrics.ProcessTree.side_effect=RuntimeError('tree constructor failed')
            with mock.patch.object(cold.sys,'platform','win32'),mock.patch.dict(cold.os.environ,{'ComSpec':str(exe)}),\
                 mock.patch.object(cold,'lifetime_reader',return_value=reader),\
                 mock.patch.object(cold.subprocess,'Popen',return_value=process),\
                 mock.patch.object(cold,'kill_owned_tree',side_effect=RuntimeError('cleanup failed')) as cleanup:
                self.reject(lambda:cold.execute_launcher(folder,folder/'evidence',metrics))
                cleanup.assert_called_once_with(process,reader);reader.close.assert_called_once()
            receipt=json.loads((folder/'evidence/process.json').read_text())
            self.assertIn('tree constructor failed',receipt['failure'])
            self.assertEqual(receipt['cleanup_errors'],['RuntimeError: cleanup failed'])
            self.assertTrue((folder/'evidence/resources.json').is_file())


    def test_dynamic_package_load_enters_required_source_inventory(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp).resolve()
            (root/'tools/ci').mkdir(parents=True)
            package=root/'tools/package_strata3_workbench.py'
            package.write_bytes(('\n'.join([
                'from pathlib import Path',
                'from types import SimpleNamespace',
                'ROOT=Path(__file__).resolve().parents[1]',
                'optics=SimpleNamespace(ROOT=ROOT,identity=lambda:dict(source_commit='+repr(cold.APPLICATION)+'))',
                'compatibility=SimpleNamespace(ROOT=ROOT)',
                '',
            ])).encode('utf-8'))
            metric_path=root/'tools/ci/strata_process_metrics.py'
            metric_path.write_bytes(b'# Source-inventory fixture; never runs a child process.\n')
            metric_module=types.ModuleType('strata003_cold_test_metrics')
            metric_module.__file__=str(metric_path)
            def git_read(checkout,*args):
                self.assertEqual(Path(checkout),root)
                if args==('rev-parse','HEAD'):return cold.APPLICATION.encode()
                if args==('rev-parse','HEAD^{tree}'):return cold.TREE.encode()
                if args==('show',cold.APPLICATION+':tools/package_strata3_workbench.py'):return package.read_bytes()
                if args==('show',cold.APPLICATION+':tools/ci/strata_process_metrics.py'):return metric_path.read_bytes()
                raise AssertionError('Unexpected frozen-source query: '+repr(args))
            old_path=list(cold.sys.path)
            try:
                with mock.patch.object(cold,'git',side_effect=git_read),\
                     mock.patch.dict(cold.sys.modules,{'strata003_cold_test_metrics':metric_module}):
                    loaded=cold.application_tools(root)
                    self.assertIs(cold.sys.modules['strata003_frozen_package_verifier'],loaded)
                    self.assertEqual(cold.verifier_inputs(root),{
                        'tools/package_strata3_workbench.py':cold.sha(package),
                        'tools/ci/strata_process_metrics.py':cold.sha(metric_path),
                    })
            finally:
                cold.sys.path[:]=old_path

    def test_failed_dynamic_package_load_removes_incomplete_registration(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp).resolve()
            (root/'tools').mkdir()
            (root/'tools/package_strata3_workbench.py').write_bytes(
                b"raise RuntimeError('deliberate package load failure')\n")
            def git_read(checkout,*args):
                self.assertEqual(Path(checkout),root)
                if args==('rev-parse','HEAD'):return cold.APPLICATION.encode()
                if args==('rev-parse','HEAD^{tree}'):return cold.TREE.encode()
                raise AssertionError('Unexpected frozen-source query: '+repr(args))
            old_path=list(cold.sys.path)
            try:
                with mock.patch.object(cold,'git',side_effect=git_read),mock.patch.dict(cold.sys.modules):
                    cold.sys.modules.pop('strata003_frozen_package_verifier',None)
                    with self.assertRaisesRegex(RuntimeError,'deliberate package load failure'):
                        cold.application_tools(root)
                    self.assertNotIn('strata003_frozen_package_verifier',cold.sys.modules)
            finally:
                cold.sys.path[:]=old_path


if __name__=='__main__':unittest.main()
