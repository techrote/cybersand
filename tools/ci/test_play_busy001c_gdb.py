#!/usr/bin/env python3
"""Exercise GDB/MI diagnostic success and refusal without Godot/GDB installed."""
import pathlib
import tempfile
import textwrap

from trace_play_busy001c_gdb import _inferior_exit_kind, capture


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

        # GDB may remain alive after its Godot inferior exits normally.
        # No interrupt stack exists, but it is not an interrupt refusal.
        finished = root / "gdb_finished"
        finished.write_text(textwrap.dedent("""\
            #!/usr/bin/env python3
            import sys
            for command in sys.stdin:
                token = command.split("-", 1)[0]
                if "-exec-run" in command:
                    print('104^running\\n=thread-group-exited,id="i1",exit-code="0"\\n*stopped,reason="exited-normally"', flush=True)
                elif "-exec-interrupt" in command:
                    raise SystemExit(9)
                else:
                    print(f'{token}^done', flush=True)
            """), encoding="utf-8")
        finished.chmod(0o755)
        early_exit = capture(str(finished), "/nonexistent/Godot",
                             root / "normal-exit", 1., [])
        assert early_exit["status"] == "refused", early_exit
        assert early_exit["inferior_exit"] == "normal", early_exit
        assert early_exit["reason"] == "inferior_exited_normal_before_interrupt", early_exit
        assert not early_exit["interrupt_stopped"] and not early_exit["backtrace_completed"]
        assert early_exit["qualification"] is False
        assert _inferior_exit_kind(b'*stopped,reason="exited",exit-code="02"\\n') == "abnormal"
        assert _inferior_exit_kind(b'*stopped,reason="signal-received"\\n') is None
    print("PLAY_BUSY001C_GDB_DIAGNOSTIC_TESTS passed")


if __name__ == "__main__":
    main()
