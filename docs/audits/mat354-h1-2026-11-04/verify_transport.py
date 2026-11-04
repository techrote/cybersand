#!/usr/bin/env python3
"""Authenticate all indexed H1 transports and unpack to a new mapped root.

Transport only. Original failed or incomplete qualifications remain unchanged.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys


def fact(p):
 b=p.read_bytes();return {'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()}
def check(p,expected):
 actual=fact(p)
 if actual['bytes']!=expected['bytes'] or actual['sha256']!=expected['sha256']:raise ValueError('identity mismatch: '+str(p))
def child(root,name):
 p=Path(name)
 if p.is_absolute() or '..' in p.parts:raise ValueError('unsafe relative mapping')
 return root/p


def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--index',type=Path,required=True);parser.add_argument('--codec',type=Path,required=True);parser.add_argument('--destination',type=Path,required=True)
 args=parser.parse_args();index=json.loads(args.index.read_text());root=args.index.resolve().parent
 if index['schema']!='mat354.h1.public-evidence-transport-index.v1':raise ValueError('wrong index schema')
 check(args.codec,index['codec']['file'])
 if args.destination.exists():raise ValueError('verification destination must not already exist')
 for item in index['inventories']:check(child(root,item['path']),item)
 check(child(root,index['verification_helper']['path']),index['verification_helper'])
 # Authenticate all transport shards before creating the recovery tree.
 for packet in index['packets']:
  manifest_path=child(root,packet['manifest']['path']);check(manifest_path,packet['manifest']);manifest=json.loads(manifest_path.read_text())
  for item in manifest['shards']:check(child(manifest_path.parent,item['name']),item)
 text_index=json.loads((root/'textual-source-index.json').read_text())
 for item in text_index['files']:check(child(root,item['published']['path']),item['published'])
 args.destination.mkdir(parents=True)
 files=bytes_=0
 for packet in index['packets']:
  manifest_path=child(root,packet['manifest']['path']);manifest=json.loads(manifest_path.read_text());target=child(args.destination,packet['original_relative_directory'])
  completed=subprocess.run([sys.executable,str(args.codec),'unpack',str(manifest_path),str(target)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True)
  if completed.stderr:raise ValueError('unexpected codec stderr')
  for item in manifest['files']:check(child(target,item['name']),item);files+=1;bytes_+=item['bytes']
 if files!=index['totals']['raw_files'] or bytes_!=index['totals']['raw_bytes']:raise ValueError('indexed count mismatch')
 result={'schema':'mat354.h1.transport-verification.v1','status':'ALL_TRANSPORT_MEMBERS_VERIFIED_NOT_QUALIFICATION','index_sha256':fact(args.index)['sha256'],'files':files,'bytes':bytes_,'packets':len(index['packets']),'restored_root':str(args.destination.resolve()),'original_receipts_changed':False}
 with (args.destination/'transport-verification.json').open('x') as f:json.dump(result,f,indent=2,sort_keys=True);f.write('\n')
 print(json.dumps(result))


if __name__=='__main__':main()
