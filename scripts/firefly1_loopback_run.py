#!/usr/bin/env python3
"""One fixed FireFly-1 PMA-loopback request: lanes 0--11, PRBS31, 10 s."""
import sys, time
sys.path.insert(0, '/home/cms/25G')
from cm_interface.registry import Registry
r=Registry(setup='tf', dev_path='/dev/ttyUL4'); f=r.fpgas['F1']
def rd(a): return f.read_reg(a,size=4)
def wr(a,v): f.write_reg(a,v,size=4)
if rd(0xc0)!=0x00020300 or rd(0xc4)!=0x00020300 or rd(0xc8)!=0: raise RuntimeError('identity/idle preflight failed')
if rd(0xa0)==1: raise RuntimeError('sequence 1 already present')
for a,v in ((0xa4,0x00011501),(0xa8,10000),(0xac,0),(0xb0,0xfff),(0xb4,0),(0xb8,0),(0xbc,0)):
 wr(a,v)
 if rd(a)!=v: raise RuntimeError('descriptor verify failed')
wr(0xa0,1)
for _ in range(200):
 if rd(0xc8)&15==2: print('RUN'); break
 time.sleep(.05)
else: raise RuntimeError('did not reach RUN')
time.sleep(11)
print('state=%#x response=%#x run=%#x summary=%#x'%(rd(0xc8),rd(0xf0),rd(0xf8),rd(0xfc)))
