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

