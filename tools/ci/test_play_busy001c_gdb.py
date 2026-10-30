#!/usr/bin/env python3
"""Exercise GDB/MI diagnostic success and refusal without Godot/GDB installed."""
import pathlib
import tempfile
import textwrap

from trace_play_busy001c_gdb import capture


def main() -> None:
    with tempfile.TemporaryDirectory() as folder:
        root = pathlib.Path(folder)
        fake = root / "gdb"
        fake.write_text(textwrap.dedent("""\
            #!/usr/bin/env python3
            import sys
            for command in sys.stdin:
                token = command.split("-", 1)[0]
                if "-exec-run" in command:
                    print('104^running\\n*running,thread-id="all"', flush=True)
                elif "-exec-interrupt" in command:
                    print('105^done\\n*stopped,reason="signal-received",signal-name="SIGINT"', flush=True)
                elif "-interpreter-exec" in command:
                    print('~"synthetic stack"\\n106^done', flush=True)
                else:
                    print(f'{token}^done', flush=True)
            """), encoding="utf-8")
        fake.chmod(0o755)
        good = capture(str(fake), "/nonexistent/Godot", root / "success", 1., [])
        assert good["status"] == "captured", good
        assert good["interrupt_stopped"] and good["backtrace_completed"]
        assert good["qualification"] is False
        assert (root / "success/gdb-mi.log").read_bytes()
        bad = capture("/bin/false", "/nonexistent/Godot", root / "refusal", 1., [])
        assert bad["status"] == "refused", bad
        assert not bad["backtrace_completed"] and bad["qualification"] is False
        assert (root / "refusal/gdb-diagnostic.json").is_file()
    print("PLAY_BUSY001C_GDB_DIAGNOSTIC_TESTS passed")


if __name__ == "__main__":
    main()
