import argparse,copy,hashlib,importlib.util,json,pathlib,sys,tempfile
parser=argparse.ArgumentParser(description="Independently replay actual pending-material picking and challenge consistent corruptions")
for name in ("reader-root","positive","negative","output"):parser.add_argument("--"+name,type=pathlib.Path,required=True)
args=parser.parse_args()
root=args.reader_root.resolve();reader=root/'tools/pubpres_final_recovery/run_qualification.py';sys.path.insert(0,str(reader.parent));spec=importlib.util.spec_from_file_location('independent_atomic_reader',reader);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
base=args.positive.resolve();s=json.loads((base/'SUMMARY.json').read_text());name='test_workbench_presentation_submission';folder=base/(name+'-slots2');receipt=json.loads((folder/'receipt.json').read_text());text=(folder/'stdout.log').read_text();kwargs={'engine_sha':s['engine_sha256'],'expected_inline':True,'expected_lookahead':0,'expected_atomic':True}
r=module.supplemental_result(name,text,folder,s['source'],base/'project',**kwargs)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();report={'schema':'pubpres-independent-accepted-material-picking-review-v1','source':s['source']['source_commit'],'tree':s['source']['source_tree'],'engine_sha256':s['engine_sha256'],'receipt_sha256':sha(folder/'receipt.json'),'reader_sha256':sha(reader),'checks':r['terminal']['checks'],'positive':True,'adversaries':[],'scope':'Independent actual graphical receipt replay and corruption refusals; no new GPU execution or performance claim.'}
mutations={
 'old_actor_not_selected':lambda p:p.__setitem__('selected_id',0),
 'not_actual_sand':lambda p:p.__setitem__('uploaded_material_id',3),
 'no_new_uploaded_revision':lambda p:p.__setitem__('uploaded_revision',p['previous_uploaded_revision']),
 'no_new_uploaded_serial':lambda p:p.__setitem__('uploaded_serial',p['previous_uploaded_serial']),
 'pixels_changed_while_held':lambda p:p.__setitem__('held_sha256','0'*64),
 'mapping_advanced_while_held':lambda p:p.__setitem__('mapping_unchanged',False),
 'premature_draw':lambda p:p.__setitem__('pre_draw_delta',1),
 'premature_submission':lambda p:p.__setitem__('submission_delta',1),
 'fabricated_physical_credit':lambda p:p.__setitem__('step_after',p['step_before']+1),
 'missing_actual_next_draw':lambda p:p.__setitem__('next_submission_delta',0),
 'next_material_not_adopted':lambda p:p.__setitem__('next_material_revision',p['submitted_revision']),
 'missing_world_refusal':lambda p:p['refusal_controls'].pop(),
 'duplicate_world_refusal':lambda p:p['refusal_controls'].__setitem__(2,copy.deepcopy(p['refusal_controls'][1])),
 'foreign_world_selected':lambda p:p['refusal_controls'][1].__setitem__('selected_id',1),
}
with tempfile.TemporaryDirectory(prefix='pubpres-atomic-picking-review-') as td:
 f=pathlib.Path(td)/'receipt.json'
 for case,mutate in mutations.items():
  d=copy.deepcopy(receipt);mutate(d['unsubmitted_material_picking']);f.write_text(json.dumps(d))
  try:module.supplemental_result(name,text,folder,s['source'],base/'project',receipt_path=f,**kwargs)
  except (ValueError,KeyError) as exc:report['adversaries'].append({'case':case,'rejected':True,'reason':str(exc)})
  else:raise AssertionError('Bad atomic material mapping accepted: '+case)
negative=args.negative.resolve();n=json.loads((negative/'SUMMARY.json').read_text());nf=negative/(name+'-slots2');nr=json.loads((nf/'receipt.json').read_text())
try:module.supplemental_result(name,(nf/'stdout.log').read_text(),nf,n['source'],negative/'project',**kwargs)
except ValueError as exc:report['retained_negative']={'source':n['source']['source_commit'],'receipt_sha256':sha(nf/'receipt.json'),'checks':nr['checks'],'failures':nr['failures'],'refused':True,'reason':str(exc)}
else:raise AssertionError('Original real negative accepted')
output=args.output.resolve();output.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'source':report['source'],'checks':report['checks'],'refusals':len(report['adversaries']),'retained_negative':report['retained_negative']},indent=2))
