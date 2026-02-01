# Input Handling (Standards + Plan)

## Findings

- Terminals separate text input from key events. Text input is the only source for printable characters; key events are used for functional keys and protocol sequences.
- Modifiers do not change control semantics for ASCII control keys. Ctrl+Shift+C still encodes ETX (0x03) like Ctrl+C.
- Key encoding is protocol‑driven: VT/DEC sequences for special keys, optional kitty keyboard protocol for richer modifiers/event types.
- SDL3 text input is opt‑in; `SDL_StartTextInput` must be called or no `SDL_EVENT_TEXT_INPUT` / `SDL_EVENT_TEXT_EDITING` events arrive.
- SDL3 distinguishes scancode (physical key) vs keycode (symbol); use scancode for physical bindings and keycode for symbolic actions.

References:
- Alacritty key encoding path: `reference_repos/terminals/alacritty/alacritty/src/input/keyboard.rs`
- Kitty keyboard protocol encoder: `reference_repos/terminals/kitty/kitty/key_encoding.c`
- SDL3 keyboard practice guide: `reference_repos/sdlwiki_md/SDL3/BestKeyboardPractices.md`
- SDL3 key/text events: `reference_repos/sdlwiki_md/SDL3/SDL_KeyboardEvent.md`, `reference_repos/sdlwiki_md/SDL3/SDL_TextInputEvent.md`, `reference_repos/sdlwiki_md/SDL3/SDL_TextEditingEvent.md`
- SDL3 text input APIs: `reference_repos/sdlwiki_md/SDL3/SDL_StartTextInput.md`, `reference_repos/sdlwiki_md/SDL3/SDL_StopTextInput.md`, `reference_repos/sdlwiki_md/SDL3/SDL_SetTextInputArea.md`

## Current Issues

- Key handling is split across app, terminal widget, and input batching; side effects (selection clearing, scroll reset) are tied to key events.
- Printable characters are synthesized from key events with modifiers, which conflicts with standard terminal behavior and IME flows.
- Modifier presses can clear selection or alter control semantics, breaking expected Ctrl/Shift combos.

## Keybinds (Lua)

- Keybinds live in `assets/config/init.lua` and user overrides in `~/.config/zide/init.lua` or `./.zide.lua`.
- Bindings are keycode‑based and use `shared_types.input.Key` enum names (e.g. `equal`, `kp_add`, `grave`).
- Modifiers are `ctrl`, `shift`, `alt`, `super` and are matched exactly.
- Use `["repeat"] = true` in Lua to enable key repeat for a binding.
- Editor bindings now include copy/cut/paste (Ctrl+C/X/V) and route via the input router.

## Plan (Todo)

1) Introduce an InputAction layer and routing table (global → focused → text) without behavior changes.
2) Split terminal input: text events send printable characters; key events only encode functional keys / control keys via a KeyEncoder.
3) Implement KeyEncoder following VT/DEC + optional kitty protocol flags; ignore Shift for Ctrl control characters.
4) Remove keyboard‑driven selection clearing; restrict selection clearing to explicit actions or content changes.
5) Add focused widget ownership rules (terminal/editor) and regression tests for Ctrl+Shift+C and IME text input.

## Recent Changes

- Terminal now avoids synthesizing printable chars from key events; printable input comes from text events.
- Ctrl/Alt modifiers no longer change control semantics based on Shift in terminal input.
- Selection is no longer cleared by keyboard input; copy/paste combos suppress terminal key events.
- InputRouter now detects Ctrl+Shift+C/V actions and routes them to focused terminal copy/paste.
- Terminal key encoding lives in `src/terminal/input/key_encoder.zig` (including key_mode flag helpers).
- Added terminal input encoding tests and editor clipboard selection tests (`src/terminal_input_encoding_tests.zig`, `src/editor_clipboard_tests.zig`).
