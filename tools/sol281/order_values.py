"""Pure planner ordering comparison from authenticated parent reports."""
import argparse,json,os,shutil
from pathlib import Path
import order_common as o
import structure_cut as p
def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('--run',required=True);args=parser.parse_args();assert Path(args.run).name==args.run
    identity=o.identity();o.resource();folder=o.OUT/args.run;assert not folder.exists();folder.mkdir();inputs=folder/'inputs';inputs.mkdir();source_path,source=o.parent_receipt();sessions=[];raw=[]
    for host,h in source['hosts'].items():
        for command in h['commands']:
            if 'report' not in command or command['name']=='mass-init':continue
            entry=command['report'];path=o.PARENT/entry['path'].replace('\\','/');assert command['clean'] and command['report_complete'] and o.sha(path)==entry['sha256']
            data=json.loads(path.read_text(encoding='utf-8'))
            if data['surroundings']!='packed_sand':continue
            assert not data['failures'] and len(data['steps'])==360
            name=f"{host}-{data['structure']}-w{data['workers']}-on{int(data['sand_response'])}";steps=[]
            for row in data['steps']:
                mid=row['ordinary_stage'];s1=mid['state'] if mid['observed'] else row['before'];s3=row['after_step'];receipt=mid.get('receipt',{});obs=row['contact_observation'];response=row['response']
                steps.append(dict(step=row['step'],s1=s1['bits'],s3=s3['bits'],local_com=s1['local_com'],gravity=s1['gravity'],dt=s1['fixed_delta'],ld=s1['linear_damp'],ad=s1['angular_damp'],observation=obs,
                    invoked=mid['observed'],ordinary_accepted=receipt.get('accepted',False),snapshot=mid.get('snapshot_serial',-1),tick=mid.get('native_tick',-1),epoch=mid.get('owner_epoch',-1),revision=mid.get('world_revision',''),token=data['prepared']['token'],generation=s1['generation'],sample=receipt.get('sample_serial',-1),capture_usec=mid.get('capture_usec',0),current=s1['sample_serial'],post_current=s3['sample_serial'],
                    recorded_new=data['sand_response'] and row['response_is_new'],recorded_outcome=response.get('outcome'),recorded_impulse=response.get('total_impulse'),recorded_torque=response.get('torque_impulse')))
            p.write(inputs/(name+'.json'),dict(id=name,centres=data['proxy_centres'],sizes=data['proxy_sizes'],steps=steps));sessions.append(name+'.json');raw.append(dict(session=name,report=entry))
    assert len(sessions)==16;p.write(inputs/'manifest.json',dict(registration='SOL-CONTACT-ORDER-VALUES-001',sessions=sessions))
    planner=(o.ROOT/'godot/scripts/solid_contact_response.gd').read_bytes();assert planner.replace(b'\r\n',b'\n')==p.git('show',o.PARENT_SHA+':godot/scripts/solid_contact_response.gd')
    receipt=dict(identity=identity,parent_receipt_sha256=o.sha(source_path),raw=raw,inputs={x.name:o.sha(x) for x in inputs.iterdir()},hosts={},scope='Pure values only; no nativeWorld/Rapier/body or live authority; alternative shadow leases and original timestamps retained.')
    for host in ['windows','linux']:
        target=folder/host;project=target/'project';project.mkdir(parents=True);rows=[]
        (project/'project.godot').write_bytes(b'config_version=5\n[application]\nconfig/name="SOL contact order values"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        (project/'planner.gd').write_bytes(planner);shutil.copyfile(o.ROOT/'tools/sol281/order_values_probe.gd',project/'probe.gd')
        engine=p.ENGINES[host];pin=source['hosts'][host]['engine']
        if host=='windows':assert o.sha(engine.replace('_console.exe','.exe'))==pin['sha256'] and o.sha(engine)==pin['launcher_sha256']
        else:
            r=p.command('engine-hash',['wsl.exe','-d','Ubuntu-24.04','--','sha256sum',engine],target);rows.append(r);assert r['clean'] and (o.ROOT/r['log']).read_text(encoding='utf-8').split()[0]==pin['sha256']
        output=target/'results.json';argv=[engine,'--headless','--audio-driver','Dummy','--path',str(project) if host=='windows' else p.wsl(project),'--script','res://probe.gd'];env=dict(os.environ,SOL_ORDER_INPUT=str(inputs),SOL_ORDER_OUTPUT=str(output))
        if host=='linux':argv=['wsl.exe','-d','Ubuntu-24.04','--','env','SOL_ORDER_INPUT='+p.wsl(inputs),'SOL_ORDER_OUTPUT='+p.wsl(output),*argv]
        rows.append(p.command('values',argv,target,env,timeout=900));receipt['hosts'][host]=dict(commands=rows,engine=pin,project_inputs={x.name:o.sha(x) for x in project.iterdir() if x.is_file()},report=dict(path=str(output.relative_to(o.ROOT)),sha256=o.sha(output)) if output.exists() else None);p.write(folder/'receipt.json',receipt)
    assert identity==o.identity();receipt['post_source_equality']=True;receipt['resource']=o.resource();p.write(folder/'receipt.json',receipt)
    return int(not all(c['clean'] for h in receipt['hosts'].values() for c in h['commands']))
if __name__=='__main__':raise SystemExit(main())
