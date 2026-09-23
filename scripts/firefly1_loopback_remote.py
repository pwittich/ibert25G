#!/usr/bin/env python3
import argparse,time,sys
from pathlib import Path
a=argparse.ArgumentParser();a.add_argument('stage',choices=('start','status','results'));a.add_argument('--cm-interface-root',type=Path,required=True);x=a.parse_args()
sys.path.insert(0,str(x.cm_interface_root.parent));from cm_interface.registry import Registry
from milestone3_12hour_external_soak import FpgaMailbox
f=FpgaMailbox(Registry(setup='tf',dev_path='/dev/ttyUL4').fpgas['F1'])
def r(a):return f.read_u32(a)
def w(a,v):f.write_u32(a,v)
if r(0xc0)!=0x20300 or r(0xc4)!=0x20300:raise RuntimeError('version mismatch')
if x.stage=='start':
 if r(0xc8)!=0 or r(0xa0)==1:raise RuntimeError('not fresh idle sequence 1')
 for a,v in ((0xa4,0x11501),(0xa8,10000),(0xac,0),(0xb0,0xfff),(0xb4,0),(0xb8,0),(0xbc,0)):w(a,v);assert r(a)==v
 w(0xa0,1)
 for _ in range(200):
  if r(0xc8)&15==2:print('RUN');break
  time.sleep(.05)
 else:raise RuntimeError('RUN timeout')
else:
 print('state=%#x request=%#x response=%#x code=%#x run=%#x summary=%#x'%(r(0xc8),r(0xa0),r(0xf0),r(0xf4),r(0xf8),r(0xfc)))
 w(0xcc,0xfe)
 print('platform_diag='+' '.join('%08x'%r(0xd0+4*i) for i in range(8)))
