# Input Handling (Standards + Plan)

## Findings

- Terminals separate text input from key events. Text input is the only source for printable characters; key events are used for functional keys and protocol sequences.
- Modifiers do not change control semantics for ASCII control keys. Ctrl+Shift+C still encodes ETX (0x03) like Ctrl+C.
- Key encoding is protocol‑driven: VT/DEC sequences for special keys, optional kitty keyboard protocol for richer modifiers/event types.

References:
- Alacritty key encoding path: `reference_repos/terminals/alacritty/alacritty/src/input/keyboard.rs`
- Kitty keyboard protocol encoder: `reference_repos/terminals/kitty/kitty/key_encoding.c`

## Current Issues

- Key handling is split across app, terminal widget, and input batching; side effects (selection clearing, scroll reset) are tied to key events.
- Printable characters are synthesized from key events with modifiers, which conflicts with standard terminal behavior and IME flows.
- Modifier presses can clear selection or alter control semantics, breaking expected Ctrl/Shift combos.

## Plan (Todo)

1) Introduce an InputAction layer and routing table (global → focused → text) without behavior changes.
2) Split terminal input: text events send printable characters; key events only encode functional keys / control keys via a KeyEncoder.
3) Implement KeyEncoder following VT/DEC + optional kitty protocol flags; ignore Shift for Ctrl control characters.
4) Remove keyboard‑driven selection clearing; restrict selection clearing to explicit actions or content changes.
5) Add focused widget ownership rules (terminal/editor) and regression tests for Ctrl+Shift+C and IME text input.
