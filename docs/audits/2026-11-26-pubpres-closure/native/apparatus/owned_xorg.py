#!/usr/bin/env python3
"""Own one local TCP-only Xorg dummy server and its exact child application."""
import hashlib,json,os,secrets,signal,socket,struct,subprocess,sys,tempfile,time
from pathlib import Path
sys.path.insert(0,'/workspace/scratch/9cef565acfec/native-comparison-b695/tools/pubpres_playability_build')
from process_owner import OwnedProcess,bounded_process

dest=Path(os.environ['PUBPRES_DISPLAY_RECEIPT'])
dest.parent.mkdir(parents=True,exist_ok=True)
assert not dest.exists()
record={'schema':'pubpres-owned-xorg-development-v1','wrapper_pid':os.getpid(),
 'scope':'Actual Linux dummy/llvmpipe correctness; not physical hardware acceptance',
 'authorization':'private MIT-MAGIC-COOKIE-1; TCP localhost client; UNIX disabled'}
code=125
with tempfile.TemporaryDirectory(prefix='pubpres-xorg-') as tmp:
 p=Path(tmp)
 conf=p/'xorg.conf'
 conf.write_text('''Section "ServerFlags"
 Option "AutoAddDevices" "false"
 Option "AutoEnableDevices" "false"
 Option "AllowMouseOpenFail" "true"
EndSection
Section "Device"
 Identifier "Dummy"
 Driver "dummy"
 VideoRam 256000
EndSection
Section "Monitor"
 Identifier "Monitor"
 HorizSync 5.0-1000.0
 VertRefresh 5.0-200.0
 Modeline "1920x1080" 148.5 1920 2008 2052 2200 1080 1084 1089 1125
EndSection
Section "Screen"
 Identifier "Screen"
 Device "Dummy"
 Monitor "Monitor"
 DefaultDepth 24
 SubSection "Display"
  Depth 24
  Modes "1920x1080"
 EndSubSection
EndSection
Section "ServerLayout"
 Identifier "Layout"
 Screen "Screen"
EndSection
''')
 auth=p/'authority'; fields=(b'',b'',b'MIT-MAGIC-COOKIE-1',secrets.token_bytes(16))
 auth.write_bytes(struct.pack('>H',65535)+b''.join(struct.pack('>H',len(v))+v for v in fields));auth.chmod(0o600)
 for candidate in range(171,240):
  try:
   s=socket.socket();s.bind(('127.0.0.1',6000+candidate));s.close();display=candidate;break
  except OSError: s.close()
 else: raise RuntimeError('No free local Xorg port')
 command=['/usr/bin/Xorg',':'+str(display),'-config',str(conf),'-logfile',str(dest.with_suffix('.xorg.log')),
  '-noreset','-listen','tcp','-nolisten','unix','-auth',str(auth)]
 record.update(server_command=command,configuration_sha256=hashlib.sha256(conf.read_bytes()).hexdigest(),
  server_executable_sha256=hashlib.sha256(Path('/usr/bin/Xorg').read_bytes()).hexdigest(),display='127.0.0.1:'+str(display))
 owner=OwnedProcess(command,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 server=owner.process;record['server_pid']=server.pid
 try:
  deadline=time.monotonic()+20
  while True:
   if server.poll() is not None: raise RuntimeError('Xorg exited before readiness: '+str(server.returncode))
   try:
    s=socket.create_connection(('127.0.0.1',6000+display),timeout=.1);s.close();break
   except OSError:
    if time.monotonic()>deadline: raise TimeoutError('Xorg readiness timeout')
    time.sleep(.05)
  env=dict(os.environ,DISPLAY=record['display'],XAUTHORITY=str(auth),DBUS_SESSION_BUS_ADDRESS='unix:path='+str(p/'unavailable-bus'),
   LIBGL_ALWAYS_SOFTWARE='1')
  code,timed=bounded_process(sys.argv[1:],env=env,timeout=600)
  record.update(application_returncode=code,application_timeout=timed)
 finally:
  record['server_alive_before_requested_shutdown']=server.poll() is None
  if server.poll() is None: server.terminate()
  try: server.wait(timeout=15)
  except subprocess.TimeoutExpired: server.kill();server.wait(timeout=15);record['forced_server_kill']=True
  record.update(unexpected_server_members=owner.close(),server_reaped=server.poll() is not None,server_returncode=server.returncode)
  record['terminal_ownership_verified'] = bool(
   record.get('server_alive_before_requested_shutdown') is True
   and record.get('server_reaped') is True
   and record.get('unexpected_server_members') is False
   and record.get('forced_server_kill',False) is False
   and record.get('server_returncode') in (0,-15)
   and record.get('application_returncode') == 0
   and record.get('application_timeout') is False)
  if not record['terminal_ownership_verified'] and code == 0: code=125
  record['returncode']=code
  dest.write_text(json.dumps(record,indent=2)+'\n')
sys.exit(code)
