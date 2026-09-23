#!/usr/bin/env python3
"""Fixed FireFly-1 lanes-0--11 PMA-loopback operator helper."""
import argparse, hashlib, subprocess, time
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
REMOTE='cms@apollo3010-1'; CONTROL='/home/wittich/.ssh/master-cms@apollo3010-1:22'
SSH=['ssh','-F','/dev/null','-S',CONTROL,'-o','BatchMode=yes','-o','ConnectTimeout=10',REMOTE]
SCP=['scp','-F','/dev/null','-o','ControlPath='+CONTROL,'-o','BatchMode=yes']
NAME='firefly1_loopback_remote.py'; DEP='milestone3_12hour_external_soak.py'; RDIR='/tmp/firefly1-loopback-v1'
def checked(a): return subprocess.run(a,cwd=str(ROOT),check=True)
def deploy():
 checked(SSH+['mkdir -p '+RDIR]); checked(SCP+[str(ROOT/'scripts'/NAME),str(ROOT/'scripts'/DEP),REMOTE+':'+RDIR+'/'])
 out=subprocess.check_output(SSH+['cd '+RDIR+' && sha256sum '+NAME+' '+DEP],universal_newlines=True)
 for line in out.splitlines():
  h,n=line.split()[:2]
  if h!=hashlib.sha256((ROOT/'scripts'/n).read_bytes()).hexdigest(): raise RuntimeError('remote hash mismatch: '+n)
 print('FIREFLY1_LOOPBACK_DEPLOY_VERIFIED')
def run(stage):
 p=ROOT/'build'/'diagnostic_archive'/('firefly1-loopback-%s-%d.log'%(stage,int(time.time())))
 cmd='cd %s && python3 -u %s %s --cm-interface-root /home/cms/25G/cm_interface'%(RDIR,NAME,stage)
 with p.open('x') as f:
  q=subprocess.Popen(SSH+[cmd],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,universal_newlines=True)
  for line in iter(q.stdout.readline,''): print(line,end='');f.write(line);f.flush()
  if q.wait(): raise RuntimeError('stage failed; evidence '+str(p))
 print('FIREFLY1_LOOPBACK_EVIDENCE '+str(p))
def main():
 a=argparse.ArgumentParser();a.add_argument('stage',choices=('deploy','start','status','results'));x=a.parse_args()
 deploy() if x.stage=='deploy' else run(x.stage)
if __name__=='__main__': main()
