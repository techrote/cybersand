"""Process-only controls; --real additionally probes actual private X11 access.

Fake display readiness is never graphical evidence. The real probe verifies
server/authentication/lifecycle only, not Godot or GPU material rendering.
"""
import ctypes
import ctypes.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import unittest

from owned_xvfb import authority_bytes, run
from process_owner import OwnedProcess


FAKE = """import os,sys,time
fd=int(sys.argv[sys.argv.index('-displayfd')+1])
os.write(fd,b'91\\n');os.close(fd)
time.sleep(60)
"""


@unittest.skipUnless(sys.platform == "linux", "Linux process/display-owner contract")
class DisplayOwnerTests(unittest.TestCase):
    def invoke(self, root, body, fake=FAKE):
        server = root / "fake-display.py"
        server.write_text(fake)
        return run([sys.executable, "-c", body], root / "display.json",
                   server_command=[sys.executable, str(server)])

    def test_actual_libxau_can_select_private_wildcard_cookie(self):
        library = ctypes.util.find_library("Xau")
        if not library:
            self.skipTest("libXau is unavailable; real Xvfb qualification remains required")
        class Auth(ctypes.Structure):
            _fields_ = [("family",ctypes.c_ushort), ("address_length",ctypes.c_ushort), ("address",ctypes.c_void_p),
                        ("number_length",ctypes.c_ushort), ("number",ctypes.c_void_p),
                        ("name_length",ctypes.c_ushort), ("name",ctypes.c_void_p),
                        ("data_length",ctypes.c_ushort), ("data",ctypes.c_void_p)]
        xau = ctypes.CDLL(library)
        xau.XauGetAuthByAddr.argtypes = [ctypes.c_ushort,ctypes.c_ushort,ctypes.c_char_p,
                                      ctypes.c_ushort,ctypes.c_char_p,ctypes.c_ushort,ctypes.c_char_p]
        xau.XauGetAuthByAddr.restype = ctypes.POINTER(Auth)
        xau.XauDisposeAuth.argtypes = [ctypes.POINTER(Auth)]
        old = os.environ.get("XAUTHORITY")
        try:
            with tempfile.TemporaryDirectory() as folder:
                path = Path(folder) / "auth"
                cookie = bytes(range(16))
                path.write_bytes(authority_bytes(cookie))
                os.environ["XAUTHORITY"] = str(path)
                auth = xau.XauGetAuthByAddr(256, 4, b"host", 2, b"91", 18, b"MIT-MAGIC-COOKIE-1")
                self.assertTrue(auth)
                try:
                    self.assertEqual(ctypes.string_at(auth.contents.data,auth.contents.data_length),cookie)
                finally:
                    xau.XauDisposeAuth(auth)
        finally:
            if old is None: os.environ.pop("XAUTHORITY",None)
            else: os.environ["XAUTHORITY"] = old

    def test_success_joins_exact_display_and_preserves_application_environment(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            code = self.invoke(root, "import os;assert os.environ['DISPLAY']==':91';assert os.path.isfile(os.environ['XAUTHORITY'])")
            self.assertEqual(code,0)
            receipt = json.loads((root / "display.json").read_text())
            self.assertTrue(receipt["server_reaped"])
            self.assertFalse(receipt["forced_server_kill"])
            self.assertTrue(receipt["server_alive_before_requested_shutdown"])
            self.assertFalse(Path('/proc',str(receipt['server_pid'])).exists())

    def test_failed_application_keeps_its_exit_code_and_joins_display(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.assertEqual(self.invoke(root,"raise SystemExit(7)"),7)
            self.assertTrue(json.loads((root / "display.json").read_text())["server_reaped"])

    def test_application_orphan_still_refuses(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            body = "import subprocess,sys;subprocess.Popen([sys.executable,'-c','import time;time.sleep(60)'],start_new_session=True)"
            self.assertEqual(self.invoke(root,body),125)
            self.assertTrue(json.loads((root / "display.json").read_text())["server_reaped"])

    def test_failed_display_never_launches_application(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); marker = root / "app-started"
            with self.assertRaises(RuntimeError):
                self.invoke(root,"from pathlib import Path;Path("+repr(str(marker))+").touch()", "raise SystemExit(9)")
            self.assertFalse(marker.exists())
            self.assertTrue(json.loads((root / "display.json").read_text())["server_reaped"])

    def test_display_shutdown_failure_refuses_completed_application(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            fake="import signal;signal.signal(signal.SIGTERM,lambda *_:sys.exit(7))\n"+FAKE
            self.assertEqual(self.invoke(root,"pass",fake),125)
            receipt=json.loads((root/'display.json').read_text())
            self.assertEqual(receipt['server_returncode'],7)
            self.assertEqual(receipt['application_returncode'],0)
            self.assertTrue(receipt['server_tree_closed'])
            self.assertEqual(receipt['failure'],'Unexpected display-server lifecycle')

    def test_display_orphan_is_refused_and_retired(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); marker = root / "display-child"
            child = "import os,time;from pathlib import Path;Path("+repr(str(marker))+").write_text(str(os.getpid()));time.sleep(60)"
            fake = ("import subprocess,sys,time;from pathlib import Path;subprocess.Popen("
                    + repr([sys.executable,"-c",child])+",start_new_session=True)\n"
                    +"while not Path("+repr(str(marker))+").exists():time.sleep(.01)\n"+FAKE)
            self.assertEqual(self.invoke(root,"pass",fake),125)
            receipt=json.loads((root/'display.json').read_text())
            self.assertTrue(receipt['server_tree_closed'])
            self.assertTrue(receipt['unexpected_server_members'])
            self.assertFalse(Path('/proc',marker.read_text()).exists())

    def test_outer_owner_sees_no_normal_exit_descendants(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); server = root / "fake-display.py"; server.write_text(FAKE)
            code = ("from pathlib import Path;from owned_xvfb import run;import sys;raise SystemExit(run("
                    + repr([sys.executable,"-c","pass"]) + ",Path("+repr(str(root/'display.json'))+"),server_command="
                    + repr([sys.executable,str(server)])+"))")
            with OwnedProcess([sys.executable,"-c",code],cwd=Path(__file__).parent) as owner:
                self.assertEqual(owner.process.wait(timeout=10),0)
                self.assertFalse(owner.close())

    def test_sigterm_retires_application_and_display(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); server = root / "fake-display.py"; server.write_text(FAKE)
            marker = root / "started"
            body = "import os,time;from pathlib import Path;Path("+repr(str(marker))+").write_text(str(os.getpid()));time.sleep(60)"
            code = ("from pathlib import Path;from owned_xvfb import run;import sys;run("
                    + repr([sys.executable,"-c",body]) + ",Path("+repr(str(root/'display.json'))+"),server_command="
                    + repr([sys.executable,str(server)])+")")
            with OwnedProcess([sys.executable,"-c",code],cwd=Path(__file__).parent,stdout=subprocess.DEVNULL,stderr=subprocess.STDOUT) as owner:
                import time
                deadline=time.monotonic()+5
                while not marker.exists() and time.monotonic()<deadline: time.sleep(.01)
                self.assertTrue(marker.exists())
                os.kill(owner.process.pid,signal.SIGTERM)
                self.assertNotEqual(owner.process.wait(timeout=10),0)
                self.assertFalse(owner.close())
            receipt=json.loads((root/'display.json').read_text())
            self.assertIn('ProcessCancelled',receipt['failure'])
            self.assertTrue(receipt['server_reaped'])
            self.assertFalse(Path('/proc',marker.read_text()).exists())

    def test_sigterm_during_display_shutdown_retires_entire_server_tree(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);marker=root/'shutting-down';server=root/'fake-display.py'
            server.write_text("import signal;from pathlib import Path\n"
                +"signal.signal(signal.SIGTERM,lambda *_:Path("+repr(str(marker))+").touch())\n"+FAKE)
            code=("from pathlib import Path;from owned_xvfb import run;import sys;run("
                  +repr([sys.executable,'-c','pass'])+",Path("+repr(str(root/'display.json'))+"),server_command="
                  +repr([sys.executable,str(server)])+")")
            with OwnedProcess([sys.executable,'-c',code],cwd=Path(__file__).parent,stdout=subprocess.DEVNULL,stderr=subprocess.STDOUT) as owner:
                import time
                deadline=time.monotonic()+5
                while not marker.exists() and time.monotonic()<deadline:time.sleep(.01)
                self.assertTrue(marker.exists())
                os.kill(owner.process.pid,signal.SIGTERM)
                self.assertNotEqual(owner.process.wait(timeout=10),0)
                self.assertFalse(owner.close())
            receipt=json.loads((root/'display.json').read_text())
            self.assertIn('ProcessCancelled',receipt['failure'])
            self.assertTrue(receipt['server_tree_closed'])
            self.assertTrue(receipt['server_reaped'])
            self.assertFalse(Path('/proc',str(receipt['server_pid'])).exists())


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--real":
        client = ("import ctypes; x=ctypes.CDLL('libX11.so.6');"
                  "x.XOpenDisplay.argtypes=[ctypes.c_char_p];x.XOpenDisplay.restype=ctypes.c_void_p;"
                  "x.XCloseDisplay.argtypes=[ctypes.c_void_p];display=x.XOpenDisplay(None);"
                  "assert display,'Private X11 authentication failed';x.XCloseDisplay(display)")
        raise SystemExit(run([sys.executable,"-c",client],Path(sys.argv[2])))
    unittest.main()
