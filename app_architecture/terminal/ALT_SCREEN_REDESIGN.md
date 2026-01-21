# Alt Screen Redesign (Proposal)

Date: 2026-01-18

Goal: make the alternate screen implementation reliable by modeling it like reference terminals (alacritty/kitty/wezterm) and removing state leakage between primary and alt screens.

Status: Implemented (2026-01-18). Per-screen state is now owned by a `Screen` struct; alt/primary are independent with full damage on switches.

## Problem Summary (current code)

- Alt screen is implemented by swapping `TerminalGrid` and some per-screen fields, but other state is shared.
- Dirtying and cached rendering are unstable on alt screen (ghosting, line duplication, redraw artifacts).
- Scrollback offset, selection, key mode stacks, and scroll regions can leak across screen swaps.

## Reference behavior

### Alacritty
- Maintains `grid` and `inactive_grid` and swaps them on alt switch.
- On entering alt the alternate grid is reset and a full damage is recorded.
- Keyboard mode stacks are swapped.

### kitty
- Keeps independent line buffers for primary/alt.
- On switch, resets cursor and optionally clears alt buffer.
- Marks everything dirty and clears selection.

### wezterm
- Uses a `ScreenOrAlt` wrapper with two `Screen`s and a boolean active flag.
- When switching, marks top physical rows dirty to invalidate caches.

## Proposed Design

### 1) Introduce `Screen` struct
Each screen owns all screen‑local state:

- `grid: TerminalGrid`
- `cursor: CursorPos`
- `saved_cursor: SavedCursor`
- `scroll_top/bottom`
- `tabstops` (new; per‑screen)
- `key_mode_stack` (per‑screen, move existing stacks into `Screen`)
- `current_attrs` (optional but safer to keep per‑screen)

### 2) TerminalSession structure

- `primary: Screen`
- `alt: Screen`
- `active: enum { primary, alt }`
- `scrollback` remains primary‑only
- `selection` disabled/cleared on alt

### 3) Switching semantics

Supported DEC modes (as today):

- `?47`   → enter alt, **no clear**, **no save cursor**
- `?1047` → enter alt, **clear**
- `?1049` → enter alt, **save cursor + clear**

Exit:

- `?47`   → leave alt, **no restore**
- `?1047` → leave alt, **no restore**
- `?1049` → leave alt, **restore cursor**

Rules:
- Enter alt: clear selection, zero scrollback offset, optional clear alt grid, reset cursor to (0,0) when `clear` is true.
- Exit alt: restore cursor only for `?1049`, do not clear primary grid.
- Always mark full damage when switching (invalidate render cache).

### 4) Dirtying / redraw strategy

- Switching screens should mark the active screen fully dirty.
- Alt screen uses no scrollback; renderer should ignore scrollback paths.
- Optionally disable cached texture while in alt to simplify correctness.

### 5) Scrollback and selection

- Only primary screen contributes to scrollback.
- Selection is cleared on alt enter and blocked during alt.

## Implementation Steps

1) Create `Screen` struct and migrate per‑screen fields from `TerminalSession`.
2) Replace `grid` + `alt_grid` with `primary` and `alt`.
3) Add `activeScreen()` / `inactiveScreen()` helpers and route code through them.
4) Re‑implement `enterAltScreen`/`exitAltScreen` using active screen switching + full damage.
5) Update snapshot to use active screen’s grid, cursor, and dirty.
6) Gate scrollback + selection to primary only.

## Tests / verification

- `nvim`, `btop`, `lazygit`, `htop`: no ghosting or line duplication after redraws.
- Enter/exit alt screen: cursor save/restore works (`?1049`).
- No scrollback pollution while in alt.
