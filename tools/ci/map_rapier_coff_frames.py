from pathlib import Path
import struct,json,hashlib,argparse
parser=argparse.ArgumentParser(description='Map stripped Rapier functions to the same-release COFF archive by all non-relocated bytes.')
parser.add_argument('--archive',type=Path,required=True)
parser.add_argument('--dll',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
parser.add_argument('rvas',nargs='+',type=lambda x:int(x,0))
args=parser.parse_args()
arc=args.archive.read_bytes()
o=8;long=b'';objs=[]
while o<len(arc):
 h=arc[o:o+60];n=int(h[48:58]);name=h[:16].decode().strip();data=arc[o+60:o+60+n]
 if name=='//':long=data
 elif name.startswith('/') and name[1:].isdigit():name=long[int(name[1:]):].split(b'\0')[0].split(b'/\n')[0].decode()
 if name.endswith('.o'):objs.append((name,data))
 o+=60+n+(n%2)
dll=args.dll.read_bytes()
pe=struct.unpack_from('<I',dll,0x3c)[0];ns=struct.unpack_from('<H',dll,pe+6)[0];opt=pe+24;secs=opt+struct.unpack_from('<H',dll,pe+20)[0]
sections=[struct.unpack_from('<8sIIIIIIHHI',dll,secs+i*40) for i in range(ns)]
def raw(rva):
 for name,vs,va,size,off,*_ in sections:
  if va<=rva<va+max(vs,size):return off+rva-va
 raise ValueError(hex(rva))
prva,psize=struct.unpack_from('<II',dll,opt+112+3*8)
pdata=[struct.unpack_from('<III',dll,raw(prva)+i*12) for i in range(psize//12)]
targets=args.rvas
funcs={r:next((x for x in pdata if x[0]<=r<x[1]),None) for r in targets}
result={hex(r):{'begin':hex(f[0]),'end':hex(f[1]),'matches':[]} for r,f in funcs.items() if f}
for name,b in objs:
 big=b[:4]==b'\x00\x00\xff\xff'
 if big:count,sptr,snum=struct.unpack_from('<III',b,44);sh=56;symsize=20
 else:count=struct.unpack_from('<H',b,2)[0];sptr,snum=struct.unpack_from('<II',b,8);sh=20+struct.unpack_from('<H',b,16)[0];symsize=18
 strings=b[sptr+snum*symsize:];symnames={};i=0
 while i<snum:
  at=sptr+i*symsize;nm=b[at:at+8]
  if nm[:4]==b'\0'*4:no=struct.unpack_from('<I',nm,4)[0];nm=strings[no:strings.find(b'\0',no)]
  else:nm=nm.split(b'\0')[0]
  val=struct.unpack_from('<I',b,at+8)[0];sec=struct.unpack_from('<i' if big else '<h',b,at+12)[0]
  aux=b[at+symsize-1]
  if sec>0 and val==0 and not nm.startswith(b'.'):symnames.setdefault(sec,[]).append(nm.decode(errors='replace'))
  i+=1+aux
 for j in range(count):
  sn,vs,va,size,off,rp,lp,nrel,nline,flags=struct.unpack_from('<8sIIIIIIHHI',b,sh+j*40)
  if not sn.startswith(b'.text') or size<16:continue
  code=b[off:off+size]
  for r,f in funcs.items():
   if not f:continue
   start,end,_=f; dc=dll[raw(start):raw(start)+min(size,end-start)]
   if code[:8]!=dc[:8]:continue
   ignored=set()
   for k in range(nrel):
    ra,si,typ=struct.unpack_from('<IIH',b,rp+k*10)
    ignored.update(range(ra,ra+(8 if typ==1 else 4)))
   n=min(len(code),len(dc));mismatches=[k for k in range(n) if k not in ignored and code[k]!=dc[k]]
   if not mismatches and n>=16:
    result[hex(r)]['matches'].append({'object':name,'section':j+1,'names':symnames.get(j+1,[]),'verified_bytes':n,'relocation_bytes':len([k for k in ignored if k<n])})
args.output.write_text(json.dumps(result,indent=2))
for k,v in result.items():print(k,v['begin'],[(m['names'],m['verified_bytes']) for m in v['matches']])
