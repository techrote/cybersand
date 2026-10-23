"""Independent schedule model: no C++ schedule or candidate imports."""
from dataclasses import replace
from oracle import encode,decode,Record

def action(index):
    group,offset=divmod(index,128)
    op=0;field=(offset//10)%5 if offset%2 else (offset//2)%5
    boundary=(0,1,254,255,256,32767,32768,65534,65535,65536,2**64-1,0xaaaa,0x5555,0xff00,0xff,0x100,0x8000,0xffff)
    v=group%35;value=boundary[v] if v<18 else 1<<(v-18)
    if offset==96:op=5;value=1<<(group%64)
    if offset in (100,101,102,103):op={100:2,101:1,102:4,103:3}[offset]
    if 104<=offset<120:op=5;value=1<<((group+offset)%64)
    return op,group%1024,(group+1)%1024,field,offset==120,value if offset not in (121,122) else value

def expected(index):
    op,left,right,field,negative,value=action(index)
    if index%128 in (121,122):op=index%128-115
    return op,left,right,field,negative,1 if negative else value

def apply(arm,left,right,a):
    op,_,_,field,negative,value=a
    if negative or op in (6,7):return False,left,right
    if op==1:return True,right,right
    if op==2:return True,right,left
    r=decode(arm,left)
    if op==0:r=replace(r,**{('material','a','b','epoch','r')[field]:value})
    if op==3:r=Record()
    if op==4:r=replace(r,epoch=0)
    if op==5:r=replace(r,unused=value)
    try:return True,encode(arm,r,raw=True),right
    except ValueError:return False,left,right
