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


def consume_terminal_publication_once(
    terminal_lib,
    terminal_handle,
    snapshot_cls,
    query_redraw_state,
    snapshot_consumer,
) -> None:
    """Resolve one terminal publication cycle for a host-owned tick.

    Contract:
    - query redraw truth first
    - only consume a snapshot when redraw is pending
    - explicitly acknowledge the published generation after consumption
    - verify redraw state cools off before returning
    """

    redraw_state = query_redraw_state(terminal_lib, terminal_handle)
    if redraw_state.needs_redraw != 1:
        raise RuntimeError("terminal redraw_state did not report pending redraw")

    snapshot = snapshot_cls()
    if terminal_lib.zide_terminal_snapshot_acquire(terminal_handle, ctypes.byref(snapshot)) != STATUS_OK:
        raise RuntimeError("terminal snapshot failed")
    try:
        snapshot_consumer(snapshot)
    finally:
        terminal_lib.zide_terminal_snapshot_release(ctypes.byref(snapshot))

    if terminal_lib.zide_terminal_present_ack(terminal_handle, redraw_state.published_generation) != STATUS_OK:
        raise RuntimeError("terminal present_ack failed")
    redraw_state_after_ack = query_redraw_state(terminal_lib, terminal_handle)
    if redraw_state_after_ack.acknowledged_generation != redraw_state.published_generation:
        raise RuntimeError("terminal acknowledged_generation did not advance")
    if redraw_state_after_ack.needs_redraw != 0:
        raise RuntimeError("terminal redraw_state did not cool off")


def consume_terminal_metadata_once(
    terminal_lib,
    terminal_handle,
    metadata_cls,
    metadata_consumer,
) -> None:
    """Resolve one metadata acquire/release cycle for host-owned latest state.

    Contract:
    - acquire metadata through the bridge
    - let the caller consume fields while the buffer is live
    - always release before returning
    """

    metadata = metadata_cls()
    if terminal_lib.zide_terminal_metadata_acquire(terminal_handle, ctypes.byref(metadata)) != STATUS_OK:
        raise RuntimeError("terminal metadata_acquire failed")
    try:
        metadata_consumer(metadata)
    finally:
        terminal_lib.zide_terminal_metadata_release(ctypes.byref(metadata))
