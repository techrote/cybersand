"""Control observations; exclude only explicit arm/admission identity labels."""
import hashlib
import json
from pathlib import Path

from compare_gcr_admission_r2 import projection, diff, digest

ROOT=Path(__file__).resolve().parents[2]


def main():
    folder=ROOT/'build/admission-controls';campaign=json.loads((folder/'campaign.json').read_text(encoding='utf-8'));lookup={(c['case'],c['arm']):c for c in campaign['captures']};records=[]
    for case in ['hard','water','empty']:
        reports={arm:json.loads((folder/lookup[case,arm]['raw']).read_text(encoding='utf-8'))for arm in ['Y1','GCR','GCR-A1']}
        a,b=projection(reports['GCR']),projection(reports['GCR-A1']);a.pop('candidate');b.pop('candidate')
        for value in [a,b]:
            for row in value['rows']:row.get('support',{}).pop('candidate',None)
        maximum=max(abs(x['out'][i]-y['out'][i])for x,y in zip(reports['Y1']['rows'],reports['GCR-A1']['rows'])for i in range(6))
        ledgers=[r['gcr']for r in reports['GCR-A1']['rows']]
        records.append({'case':case,'R2_A1_selected_core_exact':a==b,'first_difference':diff(a,b),
                        'R2_selected_core_sha256':digest(a),'A1_selected_core_sha256':digest(b),
                        'Y1_A1_max_abs_pose_linear_angular_velocity_difference':maximum,
                        'maximum_A1_new_normal':max(abs(g['normal_accepted'])for g in ledgers),
                        'maximum_A1_new_tangent':max(abs(g['tangent_accepted'])for g in ledgers),
                        'maximum_A1_event_budget_cost':max(abs(g['event_budget_cost'])for g in ledgers),
                        'raw_sha256':{arm:lookup[case,arm]['raw_sha256']for arm in reports}})
    output={'schema':1,'source':campaign['identity']['source'],'protocol_sha256':campaign['identity']['protocol_sha256'],
            'scope':'Actual controlled material/pose/application observations, not full cell state. Projection retains existing physical fields and removes only declared clocks/sample/session/snapshot/arm/admission metadata.',
            'additional_arm_metadata_excluded':['report.candidate','rows.support.candidate'],
            'projection_script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'records':records}
    (ROOT/'build/admission-controls-comparison.json').write_text(json.dumps(output,indent=2),encoding='utf-8')
    print('controls',len(records),'R2/A1 selected core exact',all(r['R2_A1_selected_core_exact']for r in records),'max Y1/A1 physical difference',max(r['Y1_A1_max_abs_pose_linear_angular_velocity_difference']for r in records))


if __name__=='__main__':main()
