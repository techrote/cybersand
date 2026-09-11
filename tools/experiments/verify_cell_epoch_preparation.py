"""Additional same-schema hash and per-chunk clear-identity checks on retained L3 preparation."""
import argparse,gzip,json
from pathlib import Path
import cell_epoch as e

def verify(directory):
    manifest=json.loads((directory/'prepared.json').read_text())
    if manifest['source']['files']!=e.identity()['files']:raise ValueError('Prepared source changed')
    for artifact in manifest['artifacts'].values():
        if e.common.digest(artifact['exe'])!=artifact['sha256']:raise ValueError('Prepared binary changed')
    checked=[]
    for fixture in ('behavior','epoch'):
        for seed,_,_ in e.common.SEEDS:
            for variant in e.VARIANTS:
                reference=directory/f'{fixture}-{seed}-{variant}-1-0.records.gz'
                identities=directory/f'{fixture}-{seed}-{variant}-1-0.clear-chunks.csv'
                for workers,repeat in ((1,1),(4,0),(4,1)):
                    other=directory/f'{fixture}-{seed}-{variant}-{workers}-{repeat}.records.gz'
                    if e.equal_frames(reference,other,keep_hash=True)!=2049:raise ValueError('Incomplete correctness frames')
                    other_ids=directory/f'{fixture}-{seed}-{variant}-{workers}-{repeat}.clear-chunks.csv'
                    if identities.read_bytes()!=other_ids.read_bytes():raise ValueError('Nondeterministic clear identities')
                    checked.append(dict(reference=reference.name,other=other.name,raw_hash_schema_equal=True,clear_identities_equal=True))
                if seed==0:
                    for workers in (1,4):
                        other=directory/f'{fixture}-observer-off-{variant}-{workers}.records.gz'
                        if e.equal_frames(reference,other,keep_hash=True,events=False)!=2049:raise ValueError('Incomplete observer frames')
                        checked.append(dict(reference=reference.name,other=other.name,observer_hash_state_work_equal=True))
    result=dict(same_schema_and_clear_identity_pairs=60,observer_hash_state_work_pairs=8,checked=checked,verifier_sha256=e.common.digest(Path(__file__)))
    e.common.write(directory/'additional-verification.json',result)
    print('Verified60 same-schema/repeat/worker/clear-identity pairs and8 observer pairs')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);a=p.parse_args();verify(a.directory.resolve())
