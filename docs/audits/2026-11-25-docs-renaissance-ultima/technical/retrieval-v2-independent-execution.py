from pathlib import Path
import hashlib,json,subprocess,sys,time
root=Path('/workspace/scratch/1c5fccfbe328/c-final-v2')
base=Path('/workspace/scratch/1c5fccfbe328/c-results')
out=Path('/workspace/scratch/1c5fccfbe328/ultima-a/a-results/ranking-v2-independent.json')
assert not out.exists()
sys.path.insert(0,str(root/'tools/docs'))
import knowledge_retrieval as k
import evaluate_knowledge as e
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
experiment=json.loads((base/'ranking-correction-experiment.json').read_text())
current=k.Retriever(root);history=k.Retriever(root,historical=True)
rows=[]
for suite in experiment['reports']:
 name=suite['suite']; fixture=base/'ranking-development-v1.json' if name=='development' else root/e.SUITES[name]
 assert sha(fixture)==suite['fixture_sha256']
 questions=json.loads(fixture.read_text())['questions']
 expected={r['id']:r for r in suite['rows']}
 prior={} if name=='development' else {r['id']:r for r in json.loads((base/'final-162b8097'/(name+'-proposed.json')).read_text())['results']}
 r=history if name=='historical' else current
 for q in questions:
  prediction=expected[q['id']]['methods']['coverage-scaled-field-bonus']
  result=r.query(q['query'])
  hits=result['hits']
  assert [(h['id'],h['score'],h['context_sha256']) for h in hits]==[(h['id'],h['score'],h['context_sha256']) for h in prediction['hits']],(name,q['id'])
  rank=next((h['rank'] for h in hits if h['path'] in q['canonical']),None)
  assert rank==prediction['canonical_rank']
  permitted={'historical-non-authoritative'} if name=='historical' else {'current-documentation','owner-confirmed-intent'}
  assert all(h['authority'] in permitted for h in hits)
  if prior:
   v1=expected[q['id']]['methods']['v1']['hits']
   assert [(h['id'],h['score']) for h in v1]==[(h['id'],h['score']) for h in prior[q['id']]['hits']]
  rows.append({'suite':name,'id':q['id'],'canonical_rank':rank,'context_sha256':[h['context_sha256'] for h in hits],'elapsed_seconds':result['elapsed_seconds']})
 print(name,len(questions),'PASS',flush=True)
report={'schema':1,'authority':'historical-non-authoritative','reviewer':'Specialist A','source_head':subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip(),'method':k.METHOD,'reviewed_change':'004e5cba3a1328458a24f0ada26b4d3d16d5a481','code_sha256':sha(Path(__file__)),'experiment_sha256':sha(base/'ranking-correction-experiment.json'),'preregistration_sha256':sha(base/'ranking-correction-preregistration.json'),'development_fixture_sha256':sha(base/'ranking-development-v1.json'),'current_fingerprint':current.identity['source_fingerprint'],'historical_fingerprint':history.identity['source_fingerprint'],'status':'PASS','actual_query_count':len(rows),'v1_original_public_id_score_equivalence_count':248,'actual_v2_id_score_context_prediction_equivalence_count':len(rows),'wrong_authority_count':0,'generative_model_executed':False,'heldout_used':False,'rows':rows}
out.write_text(json.dumps(report,indent=2)+'\n')
print(out,sha(out),flush=True)
