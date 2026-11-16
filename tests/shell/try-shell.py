"""Check preview editing through Kitty's terminal engine, without a GUI.

Run: python3 tests/shell/try-shell.py [--launcher /nix/store/.../bin/try-shell]
Requires Kitty; the default invocation builds and runs the current flake's app.
"""

import argparse
import fcntl
import os
from pathlib import Path
import pty
import re
import select
import struct
import subprocess
import sys
import tempfile
import time

try:
    import kitty.fast_data_types as kitty
    from kitty.constants import terminfo_dir
except ModuleNotFoundError:
    code = (
        "import runpy, sys; "
        f"sys.argv = {sys.argv!r}; "
        f"runpy.run_path({str(Path(__file__).resolve())!r}, run_name='__main__')"
    )
    os.execvp("kitty", ["kitty", "+runpy", code])


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--launcher")
parser.add_argument(
    "--terminfo-variable", choices=("TERMINFO", "TERMINFO_DIRS"), default="TERMINFO"
)
args = parser.parse_args()
repo = Path(__file__).resolve().parents[2]
command = (
    [args.launcher]
    if args.launcher
    else ["nix", "run", f"path:{repo}#try-shell"]
)


class Callbacks:
    def __getattr__(self, name):
        return lambda *args: None


def control_terminal():
    os.setsid()
    fcntl.ioctl(0, 0x540E, 0)  # TIOCSCTTY


with tempfile.TemporaryDirectory(prefix="try-shell-test-") as temporary:
    probe = Path(temporary) / "probe.zsh"
    probe.write_text(
        "_test_buffer() { print -rn -- $'\\036'\"$KEYMAP:$CURSOR:$BUFFER\"$'\\037'; zle redisplay; }\n"
        "zle -N _test_buffer\n"
        "bindkey -M viins '^X^T' _test_buffer\n"
        "bindkey -M vicmd '^X^T' _test_buffer\n"
    )
    master, slave = pty.openpty()
    fcntl.ioctl(slave, 0x5414, struct.pack("HHHH", 30, 100, 0, 0))  # TIOCSWINSZ
    screen = kitty.Screen(Callbacks(), 30, 100, 100)
    transcript = bytearray()
    pending = b""
    environment = dict(os.environ, TERM="xterm-kitty")
    for variable in ("TERMINFO", "TERMINFO_DIRS"):
        environment.pop(variable, None)
    environment[args.terminfo_variable] = terminfo_dir
    process = subprocess.Popen(
        command,
        cwd=repo,
        env=environment,
        stdin=slave,
        stdout=slave,
        stderr=slave,
        preexec_fn=control_terminal,
        close_fds=True,
    )
    os.close(slave)

    def drain(seconds=0.1):
        global pending
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            ready, _, _ = select.select(
                [master], [], [], max(0, deadline - time.monotonic())
            )
            if not ready:
                continue
            try:
                data = os.read(master, 65536)
            except OSError:
                return
            if not data:
                return
            transcript.extend(data)
            remaining = data
            while remaining:
                buffer = screen.test_create_write_buffer()
                written = screen.test_commit_write_buffer(remaining, buffer)
                remaining = remaining[written:]
                screen.test_parse_written_data()
            pending += data
            while b"\x1b[6n" in pending:
                _, pending = pending.split(b"\x1b[6n", 1)
                os.write(master, f"\x1b[{screen.cursor.y + 1};{screen.cursor.x + 1}R".encode())
            pending = pending[-16:]

    def key(code, text="", mods=0):
        encoded = kitty.encode_key_for_tty(
            key=code,
            text=text,
            mods=mods,
            action=kitty.GLFW_PRESS,
            key_encoding_flags=screen.current_key_encoding_flags(),
            cursor_key_mode=screen.cursor_key_mode,
        )
        os.write(master, encoded.encode())
        drain()

    def type_text(text):
        # These fixtures contain only ordinary ASCII, avoiding paste semantics.
        for character in text:
            key(ord(character), text=character)

    def records():
        return re.findall(rb"\x1e(.*?)\x1f", transcript, re.S)

    def check_editing(name, actions, expected, mode, cursor):
        key(ord("c"), mods=kitty.GLFW_MOD_CONTROL)
        for action in actions:
            if isinstance(action, str):
                type_text(action)
            else:
                key(action)
        row = str(screen.line(screen.cursor.y))
        visible = re.split("[❯❮] ", row, maxsplit=1)[-1].rstrip()
        before = len(records())
        key(ord("x"), mods=kitty.GLFW_MOD_CONTROL)
        key(ord("t"), mods=kitty.GLFW_MOD_CONTROL)
        fresh = records()[before:]
        if fresh:
            actual_mode, actual_cursor, actual_buffer = fresh[-1].decode().split(":", 2)
        else:
            actual_mode, actual_cursor, actual_buffer = "missing", "-1", "missing"
        # `main` is the normal alias of viins, as configured by the shell.
        actual_mode = "viins" if actual_mode == "main" else actual_mode
        ok = (
            visible == expected
            and actual_buffer == expected
            and actual_mode == mode
            and int(actual_cursor) == cursor
        )
        print(f"{'PASS' if ok else 'FAIL'} {name}", flush=True)
        if not ok:
            print(
                f"  visible={visible!r}, buffer={actual_buffer!r}, "
                f"mode={actual_mode}, cursor={actual_cursor}; expected "
                f"{expected!r}, {mode}, {cursor}",
                flush=True,
            )
        return ok

    try:
        deadline = time.monotonic() + 180
        while b"Type 'exit' to leave." not in transcript:
            drain(0.1)
            if process.poll() is not None or time.monotonic() > deadline:
                raise RuntimeError("Preview did not start: " + transcript[-2000:].decode(errors="replace"))
        # Wait for the first prompt after completion-cache initialization.
        while b"\x1b]133;B" not in transcript:
            drain(0.1)
            if process.poll() is not None or time.monotonic() > deadline:
                raise RuntimeError("Preview prompt did not appear")
        drain(0.2)
        type_text(f"source {probe}")
        key(kitty.GLFW_FKEY_ENTER)
        results = [
            check_editing("Backspace redraw", ["abc", kitty.GLFW_FKEY_BACKSPACE], "ab", "viins", 2),
            check_editing("Esc and normal deletion redraw", ["abc", kitty.GLFW_FKEY_ESCAPE, "x"], "ab", "vicmd", 1),
            check_editing("Home and insertion redraw", ["abc", kitty.GLFW_FKEY_HOME, "X"], "Xabc", "viins", 1),
        ]
        key(ord("c"), mods=kitty.GLFW_MOD_CONTROL)
        type_text("exit")
        key(kitty.GLFW_FKEY_ENTER)
        process.wait(timeout=5)
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        os.close(master)

print(f"{sum(results)}/{len(results)} passed")
sys.exit(0 if all(results) else 1)
