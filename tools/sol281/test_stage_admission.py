"""Adversarial changes to real stage evidence must fail independent admission."""
import copy,json,sys
from pathlib import Path
import reduce_structure_stages as s

def main():
    d=json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'));s.episode(d)
    index=next(i for i,r in enumerate(d['steps']) if r['ordinary_stage']['observed'] and r['ordinary_stage']['receipt']['accepted'] and r['ordinary_correction_applications_delta'])
    row=d['steps'][index];previous=d['steps'][index-1]['after_step'] if index else None;bad=[]
    def reject(name,change):
        r=copy.deepcopy(row);change(r)
        try:s.step(r,d,previous)
        except (AssertionError,KeyError,ValueError):bad.append(name);return
        raise AssertionError('Adverse evidence accepted: '+name)
    reject('missing_midpoint_call',lambda r:r.update(ordinary_stage_calls=0))
    reject('extra_rapier_step',lambda r:r['ordinary_stage']['state'].update(manual_step=index+1))
    reject('foreign_owner',lambda r:r['ordinary_stage']['state'].update(body_rid=d['body_rid']+1))
    reject('wrong_midpoint_com',lambda r:r['ordinary_stage']['state'].update(local_com=[.5,.5]))
    reject('wrong_epoch',lambda r:r['ordinary_stage'].update(owner_epoch=987))
    reject('wrong_native_tick',lambda r:r['ordinary_stage'].update(native_tick=-1))
    reject('mutating_ordinary_refusal',lambda r:r['ordinary_stage']['receipt'].update(accepted=False))
    reject('wrong_impulse_count',lambda r:r['ordinary_stage']['receipt'].update(impulse_applications=99))
    reject('omitted_native_values',lambda r:r['ordinary_stage'].update(native_results_bits=''))
    reject('mutating_refused_sand',lambda r:r.update(response_is_new=False,after_application=r['after_step']))
    reject('unexpected_preordinary_motion',lambda r:r['before'].update(bits=r['after_step']['bits']))
    print(json.dumps(dict(valid_report='PASS',rejected_mutations=bad,checks=len(bad)+1)))
if __name__=='__main__':main()
