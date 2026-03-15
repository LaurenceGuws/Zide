# Windows Implementation TODO

## Scope

Track Windows platform work for build and run parity first, then quality and native integrations.

## Priorities

- Keep diffs small and reviewable.
- Preserve end-to-end Windows build and run smoke coverage.
- Fill abstraction gaps in renderer backend, PTY, font fallback, and signal handling.
- Fix doc drift as soon as code and docs diverge.

## Entry Points

- `build.zig`
- `src/platform/*`
- `src/ui/renderer.zig`
- `src/ui/renderer/backends/*`
- `src/terminal/io/pty_windows.zig`
- `src/ui/terminal_font.zig`

## Baseline

- [x] Build produces a runnable `zig-out/bin/zide.exe` when vcpkg dependencies are installed, and the build copies required DLLs beside the executable.
- [x] Windows ConPTY can spawn `cmd.exe` and pass a smoke test.

## Phases

### Phase 0 Docs and Baseline

- [x] `W0-01` Create the Windows implementation tracker
- [x] `W0-02` Fix doc drift so terminal design no longer claims ConPTY is a stub

### Phase 1 Terminal PTY Parity

- [x] `W1-01` Implement PTY lifecycle parity and wire `TerminalSession.isAlive()`
- [x] `W1-02` Honor configured shell path and command line on Windows ConPTY
- [x] `W1-03` Add graceful shutdown and exit-status plumbing for Windows ConPTY

### Phase 2 Renderer Backend

- [x] `W2-01` Wire `-Drenderer-backend` to real backend selection or fail cleanly
- [x] `W2-02` Decide WGL vs SDL-managed GL
  Current decision: SDL-managed GL remains the only selectable backend; WGL/EGL stay as non-selectable placeholders.
- [ ] `W2-03` Run a Windows renderer smoke test
  Manual validation still needed: `zig build run -- --mode terminal` on Windows, including input, DPI, and present-loop stability.

### Phase 3 Font Fallback

- [x] `W3-01` Implement Windows system font fallback
  DirectWrite-based fallback resolution is in place, with a fast path through well-known `%WINDIR%\\Fonts` entries.

### Phase 4 Process Signals

- [x] `W4-01` Implement Windows Ctrl+C and close handling

### Phase 5 Tooling

- [x] `W5-01` Make bootstrap and grammar-pack flows work on Windows
  Grammar update can use `bash` when available; bootstrap also has a PowerShell path.

### Phase 6 Quality of Life

- [x] `W6-01` Add native Windows file dialogs

### Phase 7 Policy Cleanup

- [x] `W7-01` Mark Windows CI work obsolete
  Project policy is local/manual validation only.

