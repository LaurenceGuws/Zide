import ctypes
import os
from pathlib import Path

STATUS_OK = 0


def as_bytes(ptr, length: int) -> bytes:
    if not ptr or length == 0:
        return b""
    return ctypes.string_at(ptr, length)


def set_default_logging() -> None:
    os.environ.setdefault("ZIDE_LOG", "none")


def load_cdll(path: Path):
    set_default_logging()
    return ctypes.CDLL(str(path))


def poll_terminal_then_editor_once(terminal_step, editor_step) -> None:
    """Run one host-owned pump tick with terminal-first ordering.

    This keeps the shared host contract explicit for mixed terminal/editor
    embedders: drain terminal-side output/publication first, then run the
    editor-side mutation/query work that may consume the same frame budget.
    """

    terminal_step()
    editor_step()
