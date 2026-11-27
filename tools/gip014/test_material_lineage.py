"""Artificial controls for the authored-material applicability contract; no engine execution."""
from copy import deepcopy
import hashlib
import struct
import unittest

from verify_transcript import (MaterialLineageEvidence, adapter_version, independent_failures,
                               lineage_construction, lineage_source)


def receipt(generation):
    # Artificial finite header/control payload, not a native construction claim.
    raw = (struct.pack('<I',24) + b'cybersand-run-receipt-v1' + struct.pack('<HBBIQQ',1,2,1,15,generation,0)
           + b'artificial-control-payload')
    return {'kind':'applied_run','schema_version':1,'session_generation':generation,'completed_tick':0,
            'canonical_bytes':list(raw),'receipt_hash':hashlib.sha256(raw).hexdigest()}


def observation(generation, revision, tick, state, *, paused=True, witness=None):
    native={'generation':generation,'revision':revision,'tick':tick,'paused':paused,'failed':False,'busy':False}
    source={k:native[k] for k in ('generation','revision','tick')}
    if witness is None:
        if state=='authored_compatible':
            witness={'kind':'authored_construction','action':'fixture_install','source':source.copy(),
                     'receipt_hash':receipt(generation)['receipt_hash']}
        elif state=='simulation_exposed':
            witness={'kind':'native_progress','source':source.copy()}
        else:
            witness={'kind':'unobserved_generation','source':source.copy()}
    return {'adapter_version':3,'native':native,'paused':paused,'actor_ids':[],'actors':[],
            'authored_digest':'artificial-fixture','scene_identity':'artificial-fixture',
            'material_lineage':{'schema':'cybersand-goblin-material-lineage-v1','state':state,
                                'source':source,'witness':deepcopy(witness)}}


def row(index, name, before, after, args=None, construction=False):
    value={'index':index,'action':{'id':name,'args':args or {}},'before':deepcopy(before),'after':deepcopy(after),
           'status':'completed','classification':'game_observation','admission':{'accepted':True},
           'native_receipt':receipt(after['native']['generation']) if construction else {},'interval':{}}
    if name=='play':
        value['interval']={'start_tick':before['native']['tick'],'end_tick':after['native']['tick']}
    if name=='pause':
        value['interval']={'start_tick':after['native']['tick'],'end_tick':after['native']['tick'],'observed_frames':3}
    return value


def capture(observed, digest, operation):
    native={k:observed['native'][k] for k in ('generation','revision','tick','paused','failed')}
    return {'region':[0,0,512,512],'count':512*512,'material_sha256':digest,'source_matches':True,
            'source_before':native.copy(),'source_after':native.copy(),
            'admission':{'status':'queued','operation_id':operation},
            'native_receipt':{'status':'completed','kind':'capture','backend':'CyberNativeCellWorld',
                              'region':[0,0,512,512],'operation_id':operation,
                              'observed_generation':native['generation'],**{k:native[k] for k in ('generation','revision','tick')}}}


def persisted_pair(start, index, compatible):
    saved_hash='a'*64 if compatible else 'b'*64
    save=row(index,'save_layout',start,start)
    save['persistence_capture']=capture(start,saved_hash,10+index)
    save['persistence']={'read_authored_digest':'artificial-fixture','saved_native_tick':start['native']['tick'],
                         'material_sha256':saved_hash,'saved_material_lineage':deepcopy(start['material_lineage']),
                         'native_material_equality_applicable':compatible,
                         'native_material_equality_reason':'available' if compatible else
                             'simulation_exposed_lineage' if start['material_lineage']['state']=='simulation_exposed' else 'unknown_material_lineage'}
    after=observation(start['native']['generation']+1,start['native']['revision']+1,0,'authored_compatible')
    after['material_lineage']['witness']['action']='reopen_layout'
    reopen=row(index+1,'reopen_layout',start,after,construction=True)
    reopen['persistence_capture']=capture(after,'a'*64,11+index)
    reopen['persistence']={'saved_native_tick':start['native']['tick'],'saved_capture':deepcopy(save['persistence_capture']),
                           'saved_material_sha256':saved_hash,'reopened_material_sha256':'a'*64,
                           'saved_material_lineage':deepcopy(start['material_lineage']),
                           'native_material_equality_applicable':compatible,
                           'native_material_equality_reason':save['persistence']['native_material_equality_reason']}
    return [save,reopen]


def tape(exposed=False, restore=False):
    first=observation(3,3,0,'authored_compatible')
    initialization={'ok':True,'observation':deepcopy(first),'native_receipt':receipt(3)}
    rows=[];current=first
    if exposed:
        played=observation(3,19,16,'simulation_exposed',paused=False)
        rows.append(row(0,'play',current,played,{'ticks':16}));current=played
        paused=deepcopy(current);paused['paused']=paused['native']['paused']=True
        rows.append(row(1,'pause',current,paused));current=paused
        retained=observation(4,20,0,'simulation_exposed',witness=current['material_lineage']['witness'])
        rows.append(row(2,'response_mode',current,retained,{'mode':'LA-EVENT-OFF'},True));current=retained
    if restore:
        restored=observation(current['native']['generation']+1,current['native']['revision']+1,0,'authored_compatible')
        restored['material_lineage']['witness']['action']='restore_start'
        rows.append(row(len(rows),'restore_start',current,restored,construction=True));current=restored
    rows.extend(persisted_pair(current,len(rows),not exposed or restore))
    return {'initialization':initialization,'steps':rows}


class MaterialLineageControls(unittest.TestCase):
    def failures(self, value):
        return {item['id'] for item in independent_failures(value)}

    def test_fresh_authored_comparison_stays_mandatory(self):
        value=tape()
        self.assertEqual(independent_failures(value),[])
        value['steps'][-1]['persistence_capture']['material_sha256']='f'*64
        value['steps'][-1]['persistence']['reopened_material_sha256']='f'*64
        self.assertIn('authored_reopen_materials',self.failures(value))

    def test_observed_exposure_survives_retaining_tick_zero(self):
        value=tape(exposed=True)
        self.assertEqual(independent_failures(value),[])
        self.assertEqual(value['steps'][2]['after']['native']['tick'],0)
        for entry in value['steps'][-2:]:
            entry['persistence']['native_material_equality_applicable']=True
            entry['persistence']['native_material_equality_reason']='available'
        failed=self.failures(value)
        self.assertTrue({'save_material_applicability','reopen_material_applicability','authored_reopen_materials'} <= failed)

    def test_fresh_restore_reestablishes_positive_equality(self):
        value=tape(exposed=True,restore=True)
        self.assertEqual(independent_failures(value),[])
        value['steps'][-2]['persistence']['native_material_equality_applicable']=False
        value['steps'][-2]['persistence']['native_material_equality_reason']='simulation_exposed_lineage'
        self.assertIn('save_material_applicability',self.failures(value))

    def test_reset_selected_is_retaining_not_fresh(self):
        value=tape(exposed=True)
        trace=MaterialLineageEvidence(value['initialization']);failures=[]
        def check(entry,name,ok,kind='gameplay'):
            if not ok:failures.append(name)
        for entry in value['steps'][:3]:trace.record(entry,check)
        before=value['steps'][2]['after']
        after=observation(5,21,0,'simulation_exposed',witness=before['material_lineage']['witness'])
        entry=row(3,'actor_reset',before,after,construction=True)
        trace.record(entry,check)
        self.assertEqual(failures,[]);self.assertEqual(trace.state,'simulation_exposed')
        forged=deepcopy(entry);forged['after']=observation(5,21,0,'authored_compatible')
        forged['after']['material_lineage']['witness']['action']='actor_reset'
        trace=MaterialLineageEvidence(value['initialization'])
        for prior in value['steps'][:3]:trace.record(prior,check)
        trace.record(forged,check)
        self.assertIn('material_lineage_after',failures)

    def test_outer_generation_relabel_does_not_rebind_hashed_receipt(self):
        observed=observation(4,4,0,'authored_compatible');old=receipt(3)
        self.assertFalse(lineage_construction(old,observed))
        old['session_generation']=4
        self.assertFalse(lineage_construction(old,observed))
        self.assertTrue(lineage_construction(receipt(4),observed))
        for offset,value in ((0,23),(28,2),(36,5),(44,1)):
            bad=receipt(4);bad['canonical_bytes'][offset]=value
            bad['receipt_hash']=hashlib.sha256(bytes(bad['canonical_bytes'])).hexdigest()
            self.assertFalse(lineage_construction(bad,observed))
        bad=receipt(4);bad['completed_tick']=False
        self.assertFalse(lineage_construction(bad,observed))

    def test_exposure_witness_is_the_last_observed_positive_source(self):
        value=tape(exposed=True)
        self.assertEqual(independent_failures(value),[])
        for entry in value['steps']:
            for side in ('before','after'):
                claim=entry[side]['material_lineage']
                if claim['state']=='simulation_exposed':
                    claim['witness']['source']={'generation':1,'revision':999999,'tick':999999}
            saved=entry.get('persistence',{}).get('saved_material_lineage',{})
            if saved.get('state')=='simulation_exposed':
                saved['witness']['source']={'generation':1,'revision':999999,'tick':999999}
        self.assertIn('material_lineage_after',self.failures(value))
        value=tape(exposed=True)
        value['steps'][2]['after']['material_lineage']['witness']['source']['tick']=1
        self.assertIn('material_lineage_after',self.failures(value))

    def test_missing_initialization_cannot_trust_a_producer_fresh_claim(self):
        value=tape();value['initialization']={}
        self.assertTrue({'material_lineage_before','save_material_applicability'} <= self.failures(value))

    def test_unknown_running_gap_cannot_manufacture_authored_state(self):
        first=observation(3,3,0,'authored_compatible')
        trace=MaterialLineageEvidence({'ok':True,'observation':first,'native_receipt':receipt(3)})
        running=deepcopy(first);running['paused']=running['native']['paused']=False
        trace.observe(running);self.assertEqual(trace.state,'unknown')
        after=observation(4,4,0,'unknown',witness={'kind':'unproven_retained_lineage','source':{'generation':4,'revision':4,'tick':0}})
        running['material_lineage']={'schema':'cybersand-goblin-material-lineage-v1','state':'unknown',
                                     'source':lineage_source(running),'witness':{'kind':'unobserved_running','source':lineage_source(running)}}
        failures=[]
        trace.record(row(0,'response_mode',running,after,{'mode':'LA-EVENT-OFF'},True),
                     lambda entry,name,ok,kind: failures.append(name) if not ok else None)
        self.assertEqual(trace.state,'unknown');self.assertEqual(failures,[])

    def test_stale_or_missing_lineage_and_capture_custody_reject(self):
        for field in ('saved_material_lineage','persistence_capture'):
            value=tape();value['steps'][0].pop(field,None)
            if field=='saved_material_lineage':del value['steps'][0]['persistence'][field]
            self.assertTrue(self.failures(value))
        value=tape(exposed=True)
        value['steps'][-1]['persistence']['saved_material_lineage']['source']['generation']+=1
        self.assertIn('reopen_saved_material_lineage',self.failures(value))
        value=tape();value['steps'][0]['after']['material_lineage']['source']['tick']=1
        self.assertIn('material_lineage_after',self.failures(value))

    def test_partial_fresh_replacement_does_not_establish_compatibility(self):
        before=observation(3,3,0,'authored_compatible')
        trace=MaterialLineageEvidence({'ok':True,'observation':before,'native_receipt':receipt(3)})
        after=observation(4,4,0,'unknown',witness={'kind':'unacknowledged_replacement','source':{'generation':4,'revision':4,'tick':0}})
        entry=row(0,'restore_start',before,after,construction=True);entry['status']='partial'
        failed=[];trace.record(entry,lambda r,n,ok,k: failed.append(n) if not ok else None)
        self.assertEqual(trace.state,'unknown');self.assertEqual(failed,[])

    def test_observation_versions_are_finite_and_legacy_numeric_compatible(self):
        self.assertEqual(adapter_version({}),1)
        for value in (1,2,3,1.0,2.0,3.0):self.assertEqual(adapter_version({'adapter_version':value}),int(value))
        for value in (True,False,0,-1,4,3.5,None,float('nan'),float('inf'),10**1000):
            self.assertEqual(adapter_version({'adapter_version':value}),0)
        legacy=tape(exposed=True)
        for entry in legacy['steps']:
            entry['before']['adapter_version']=entry['after']['adapter_version']=2
            if entry['action']['id'] in ('save_layout','reopen_layout'):
                entry['persistence']['native_material_equality_applicable']=True
                entry['persistence']['native_material_equality_reason']='available'
        # Preserve the historical false oracle and its original failure.
        self.assertEqual(self.failures(legacy),{'authored_reopen_materials'})


if __name__=='__main__':unittest.main()
