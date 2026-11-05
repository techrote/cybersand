#!/usr/bin/env python3
"""Independent lossless node/batch accounting; never supplies physical authority."""
import math
import struct

if not __debug__:
    raise RuntimeError('Trace audit requires assertion checks')

# Frozen copied-value audit tolerances, not clearance thresholds or tuned gates.
SCALAR_TOL=1e-12
QUANTITY_TOL=1e-10

def close(actual,expected,tol=SCALAR_TOL):
    assert math.isfinite(actual) and math.isfinite(expected) and abs(actual-expected)<=tol, (actual,expected,tol)

def vector(actual,expected,tol=SCALAR_TOL):
    assert len(actual)==len(expected)
    for a,b in zip(actual,expected):close(a,b,tol)

def integer(value,maximum=4294967295):
    assert type(value) in (int,float) and math.isfinite(value) and 0<=value<=maximum and int(value)==value
    return int(value)

def unpack(capture,key,width):
    displayed=capture[key];encoded=capture[key+'le']
    assert isinstance(displayed,list) and len(displayed)==width and isinstance(encoded,str) and len(encoded)==16*width
    raw=bytes.fromhex(encoded);assert len(raw)==8*width
    values=list(struct.unpack('<'+str(width)+'d',raw))
    # Godot JSON decimals are display only. Existing live scalar tolerance is
    # used solely to detect a mismatched display/bits envelope.
    for a,b in zip(displayed,values):
        assert math.isfinite(a) and math.isfinite(b) and math.isclose(a,b,rel_tol=1e-12,abs_tol=1e-9)
    return values

def chunks(values,width):
    assert len(values)%width==0
    return [values[i:i+width] for i in range(0,len(values),width)]

def clamp(value,low,high):
    # Preserve an in-range signed zero, as std::clamp does.
    return low if value<low else high if high<value else value

def energy(body,velocity,omega):
    return .5*body[5]*(velocity[0]*velocity[0]+velocity[1]*velocity[1])+.5*body[6]*omega*omega

def audit(capture,row=None):
    assert capture['schema']=='gcr-node-trace-001' and capture['export_complete']
    assert capture['status']==capture['kernel_status']
    assert capture['normal_policy'] in ('original','active-normal-001')
    assert capture['node_limit']==64 and capture['storage_bytes']==55872
    total=integer(capture['total_nodes'],1024);count=integer(capture['captured_nodes'],64)
    dropped=integer(capture['dropped_nodes'],1024);batch_count=integer(capture['batch_count'],8)
    assert count==min(total,64) and dropped==total-count
    status=capture['status']
    if status in ('NOT_EXECUTED','INPUT_REFUSED'):
        assert not capture['complete'] and total==count==dropped==batch_count==0
        return dict(status=status,full_closure=False,nodes=0,captured=0)
    assert status==('INCOMPLETE_NODE_CAP' if dropped else 'COMPLETE') and capture['complete']==(dropped==0)
    assert batch_count==8
    complete=not dropped
    body=unpack(capture,'body_f64',8);available,scale,budget=unpack(capture,'solve_f64',3)
    result=unpack(capture,'result_f64',19);nodes=chunks(unpack(capture,'nodes_f64',6*count),6)
    batches=chunks(unpack(capture,'batches_f64',64),8)
    steps=chunks(unpack(capture,'steps_f64',88*count),11)
    metadata=chunks(capture['node_meta_f64'],5);batch_meta=chunks(capture['batch_meta_f64'],7)
    flags=[integer(x,127) for x in capture['flags_f64']]
    counts=[integer(x) for x in capture['result_counts']]
    assert len(metadata)==count and len(batch_meta)==8 and len(flags)==8*count and len(counts)==7
    assert all(len(m)==5 and all(integer(v)==v for v in m) for m in metadata)
    assert all(len(m)==7 and all(integer(v)==v for v in m) for m in batch_meta)
    assert counts[1]==total and counts[3]==8*total and counts[6] in (0,1)
    assert body[5]>0 and body[6]>0 and body[7]>=0 and 1<=scale<=4096 and 5<=budget<=80
    samples=integer(capture['samples'],9007199254740991);input_bins=integer(capture['input_bins'],512)
    capacity=min(clamp(available,0.,budget*scale),2.*samples*scale);close(result[14],capacity,QUANTITY_TOL)
    groups=[]
    for index,(node,meta) in enumerate(zip(nodes,metadata)):
        bin_index,source_count,ordinal,quadrature,clipped=map(int,meta)
        assert bin_index<input_bins and source_count>0 and quadrature in (1,2) and ordinal<quadrature and clipped in (0,1)
        if not groups or bin_index!=groups[-1][0]:
            assert ordinal==0 and (not groups or bin_index>groups[-1][0])
            groups.append([bin_index,source_count,quadrature,clipped,1])
        else:
            group=groups[-1];assert ordinal==group[4] and [source_count,quadrature,clipped]==group[1:4];group[4]+=1
        close(node[2]*node[2]+node[3]*node[3],1.)
        source_weight=source_count/samples
        close(node[4],source_weight if quadrature==1 else source_weight*.5)
        close(node[5],capacity*source_weight if quadrature==1 else capacity*source_weight*.5,QUANTITY_TOL)
        assert math.hypot(node[0]-body[2],node[1]-body[3])<=result[18]+SCALAR_TOL
    if complete:
        assert all(g[2]==g[4] for g in groups) and sum(g[1] for g in groups)==samples
        assert len(groups)==counts[0] and sum(g[3] for g in groups)==counts[2]
    elif groups:
        assert all(g[2]==g[4] for g in groups[:-1])
    previous_v=body[:2];previous_w=body[4];jn=[0.]*count;jt=[0.]*count
    raw_normal=raw_tangent=0.;normal_hits=tangent_hits=0;normal_unwinds=tangent_unwinds=0
    maximum_batch_energy_increase=0.
    for batch_index,(batch,meta) in enumerate(zip(batches,batch_meta)):
        pass_index,axis,diagnostic_count,policy_count,normal_delta,tangent_delta,mask_valid=map(int,meta)
        assert pass_index==batch_index//2 and axis==batch_index%2
        vector(batch[:2],previous_v);close(batch[2],previous_w)
        policy_mask=not axis and capture['normal_policy']=='active-normal-001'
        assert bool(mask_valid)==policy_mask and diagnostic_count<=total and policy_count<=total
        if not policy_mask:assert policy_count==0 and batch[7]==0
        if axis:assert diagnostic_count==0 and batch[6]==0
        computed_v=batch[:2].copy();computed_w=batch[2];active_count=0;active_weight=0.;nh=th=0
        for index,node in enumerate(nodes):
            data=steps[batch_index*count+index];flag=flags[batch_index*count+index]
            before_n,before_t,after_n,after_t,speed,requested,weight,target,next_value,delta,limit=data
            assert before_n==jn[index] and before_t==jt[index]
            rx,ry=node[0]-body[2],node[1]-body[3];nx,ny=node[2:4]
            dx,dy=(-ny,nx) if axis else (nx,ny)
            arm=rx*dy-ry*dx
            predicted_speed=(batch[0]-batch[2]*ry)*dx+(batch[1]+batch[2]*rx)*dy
            predicted_request=-predicted_speed/(1./body[5]+arm*arm/body[6])
            close(speed,predicted_speed);close(requested,predicted_request)
            active=not axis and (speed<0 or before_n>0)
            if active:active_count+=1;active_weight+=node[4]
            expected_weight=node[4]
            if policy_mask and policy_count!=total:expected_weight=node[4]/batch[7] if active and batch[7]>0 else 0.
            close(weight,expected_weight)
            expected_limit=body[7]*before_n if axis else node[5]
            expected_target=(before_t if axis else before_n)+requested*expected_weight
            expected_next=clamp(expected_target,-expected_limit if axis else 0.,expected_limit)
            close(limit,expected_limit);close(target,expected_target);close(next_value,expected_next)
            close(delta,expected_next-(before_t if axis else before_n))
            expected_flags=(0 if axis else 1|(2 if active else 0))|(4|(8 if active else 0) if policy_mask else 0)
            cap_hit=abs(target)>limit if axis else target>limit
            if cap_hit:expected_flags|=16
            if not axis and next_value<before_n:expected_flags|=32;normal_unwinds+=1
            if axis and abs(next_value)<abs(before_t):expected_flags|=64;tangent_unwinds+=1
            assert flag==expected_flags
            if axis:
                assert after_n==before_n and after_t==next_value;th+=cap_hit;raw_tangent+=abs(requested)
            else:
                assert after_t==before_t and after_n==next_value;nh+=cap_hit;raw_normal+=max(0.,requested)
            jn[index],jt[index]=after_n,after_t
            computed_v[0]+=dx*(delta/body[5]);computed_v[1]+=dy*(delta/body[5]);computed_w+=arm*delta/body[6]
        if complete:
            assert active_count==diagnostic_count;close(active_weight,batch[6])
            if policy_mask:assert active_count==policy_count;close(active_weight,batch[7])
            assert (nh,th)==(normal_delta,tangent_delta)
            vector(computed_v,batch[3:5]);close(computed_w,batch[5])
        else:
            assert active_count<=diagnostic_count and nh<=normal_delta and th<=tangent_delta
        normal_hits+=normal_delta;tangent_hits+=tangent_delta
        maximum_batch_energy_increase=max(maximum_batch_energy_increase,energy(body,batch[3:5],batch[5])-energy(body,batch[:2],batch[2]))
        previous_v=batch[3:5];previous_w=batch[5]
    assert normal_hits==counts[4] and tangent_hits==counts[5]
    if complete:
        impulse=[0.,0.];normal_impulse=[0.,0.];tangent_impulse=[0.,0.];torque=normal=tangent=0.
        for index,node in enumerate(nodes):
            nx,ny=node[2:4];jx=nx*jn[index]-ny*jt[index];jy=ny*jn[index]+nx*jt[index]
            impulse[0]+=jx;impulse[1]+=jy;normal_impulse[0]+=nx*jn[index];normal_impulse[1]+=ny*jn[index]
            tangent_impulse[0]+=-ny*jt[index];tangent_impulse[1]+=nx*jt[index]
            torque+=(node[0]-body[2])*jy-(node[1]-body[3])*jx;normal+=jn[index];tangent+=abs(jt[index])
        vector(result[6:8],impulse);close(result[9],torque);close(result[12],raw_normal,QUANTITY_TOL);close(result[13],raw_tangent,QUANTITY_TOL)
        raw_energy=energy(body,[body[0]+impulse[0]*(1./body[5]),body[1]+impulse[1]*(1./body[5])],body[4]+torque/body[6])
    else:raw_energy=struct.unpack('<d',bytes.fromhex(capture['raw_energy_f64le']))[0]
    encoded_energy=capture['raw_energy_f64le'];assert len(encoded_energy)==16
    close(raw_energy,struct.unpack('<d',bytes.fromhex(encoded_energy))[0],QUANTITY_TOL)
    close(capture['raw_energy_after'],raw_energy,QUANTITY_TOL)
    before=energy(body,body[:2],body[4]);close(result[15],before,QUANTITY_TOL)
    rejected=raw_energy>before+1e-6*max(1.,before)
    assert bool(counts[6])==rejected and result[17]==(0 if rejected else 1)
    if rejected:
        assert result[:6]==[0.]*6 and result[8]==result[10]==result[11]==0.;close(result[16],before,QUANTITY_TOL)
    else:
        assert result[0:2]==result[6:8] and result[8]==result[9];close(result[16],raw_energy,QUANTITY_TOL)
        if complete:vector(result[2:4],normal_impulse);vector(result[4:6],tangent_impulse);close(result[10],normal);close(result[11],tangent)
    if row is not None:
        assert (capture['owner_id'],capture['instance_id'],capture['generation'],capture['sample'])==(row['id'],row['instance_id'],row['generation'],row['sample'])
        assert row['normal_policy']==capture['normal_policy'] and row['nodes']==total
        for actual,expected in zip(row['passive_state_f64'],body):assert math.isclose(actual,expected,rel_tol=1e-12,abs_tol=1e-9)
        for key,values in [('passive_raw_wrench_f64',result[6:8]+[result[9]]),('passive_accepted_wrench_f64',result[:2]+[result[8]])]:
            assert len(row[key])==3
            for a,b in zip(row[key],values):assert math.isclose(a,b,rel_tol=1e-12,abs_tol=1e-9)
    return dict(status=status,full_closure=complete,nodes=total,captured=count,dropped=dropped,raw_energy=raw_energy,accepted_energy=result[16],
        normal_unwinds=normal_unwinds,tangent_unwinds=tangent_unwinds,maximum_batch_energy_increase=maximum_batch_energy_increase,
        node_input_bits=capture['body_f64le']+capture['solve_f64le']+capture['nodes_f64le'],result_bits=capture['result_f64le'])
