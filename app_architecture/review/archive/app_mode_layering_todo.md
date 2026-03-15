# App Mode Layering Rollout Record

## Scope

Historical tracker for the completed app-mode layering extraction. The work split app mode orchestration into shared contracts, backend implementations, and a thin IDE composition layer while preserving runtime `--mode` behavior.

## Constraints Used During Rollout

- No editor or terminal feature changes.
- No FFI ABI expansion.
- No renderer architecture redesign.
- Gates had to pass after each extraction slice.

## Layering Model

- Shared public layer: `src/app/modes/shared/` for contracts, action DTOs, and host-agnostic lifecycle/routing interfaces.
- Backend layer: `src/app/modes/backend/` for concrete editor and terminal mode implementations.
- IDE layer: `src/app/modes/ide/` for thin composition and IDE-only policy.

## Regression Gates Used

- Automated: `zig build test`, `zig build check-terminal-imports`, `zig build check-app-imports`, `zig build check-input-imports`, `zig build check-editor-imports`
- Replay: `zig build test-terminal-replay -- --all`
- Manual smokes: `zig build run`, `zig build run -- --mode terminal`, `zig build run -- --mode editor`, `zig build run -- --mode ide`
- Bundle helpers added during rollout: `zig build mode-gates`, `zig build mode-gates-fast`, `zig build mode-smokes-manual`, `tools/mode_gates.sh`

## Milestones

### MODE-00 Architecture and Contracts

- [x] `MODE-00-01` Add shared mode contract interfaces and action DTOs
- [x] `MODE-00-02` Document mode-layer boundaries and import constraints
- [x] `MODE-00-03` Extend import checks with mode-layer-specific rules

### MODE-01 Backend Extraction

- [x] `MODE-01-01` Extract terminal mode backend implementation
  Completed through terminal tab/action routing, close-confirm flow, adapter sync, parity diagnostics, and progressive removal of `main.zig` callback and wrapper ownership.
- [x] `MODE-01-02` Extract editor mode backend implementation
  Completed through editor tab/action routing and adapter sync via backend/shared contracts.

### MODE-02 IDE Composition Layer

- [x] `MODE-02-01` Add a thin IDE host composition wrapper
- [x] `MODE-02-02` Move residual mode-switching logic out of `main.zig`
  Completed with mode routing, layout policy, action gating, and mouse routing moved under `app/modes/ide`.

### MODE-03 Build-Time Focused Binaries

- [x] `MODE-03-01` Add separate executable roots for terminal, editor, and full IDE
  Completed with focused entry roots, compile-time effective-mode resolution, focused startup/run-loop specialization, and binary-size reporting/checks.
- [x] `MODE-03-02` Add run/install steps for focused binaries
  Completed as part of the focused-binary build and gate workflow.

## Outcome

- [x] `src/main.zig` was reduced to a thin bootstrap and process-entry surface.
- [x] Shared, backend, and IDE mode layers became explicit and enforceable.
- [x] Focused binaries gained dedicated entry roots and size guardrails.
- [x] The tracker is complete and retained only as historical rollout evidence.

