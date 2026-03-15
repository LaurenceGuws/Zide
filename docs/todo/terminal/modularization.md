# Terminal Modularization Plan

Date: 2026-01-24

Status note, 2026-03-15:

- This file is now mostly a historical extraction ledger plus safety rules.
- The broad modularization lane is no longer the main terminal blocker.
- Active structural work should default to
  [vt_core_rearchitecture.md](/home/home/personal/zide/docs/todo/terminal/vt_core_rearchitecture.md),
  not this file.

Goal: split the terminal implementation into clear layers with a stable API surface, while preserving behavior and minimizing regressions.

Current follow-up:

- The extraction/modularization lane is no longer the main blocker by itself.
- The next terminal architecture lane is tracked in `docs/todo/terminal/vt_core_rearchitecture.md`.
- See `docs/review/TERMINAL_CORE_ARCHITECTURE_REVIEW_2026-03-10.md` for the Ghostty-informed re-rank of remaining architectural blockers.

## Scope
- Terminal core + protocol handling + screen model + snapshot API.
- Keep UI rendering in `src/ui/widgets/terminal_widget.zig` and renderer/font code in `src/ui/`.
- Preserve all current features (OSC/CSI/DCS, kitty graphics, scrollback, selection, input).

## Non-goals (for this phase)
- Major behavior changes.
- New protocol features or large refactors of renderer/font code.

## Constraints
- Test-first migration (add terminal tests before moving code).
- No feature removal; changes must be traceable to current behavior.
- Keep hot paths allocation-free and branch-light (per `DESIGN.md`).

## Target Layer Split (mapping to `app_architecture/terminal/DESIGN.md`)
1) UI Integration: `src/ui/widgets/terminal_widget.zig` (renderer + input mapping).
2) Snapshot API: `src/terminal/core/snapshot.zig` (immutable per-frame data).
3) PTY + IO: `src/terminal/io/*.zig` + optional `src/terminal/core/pty_driver.zig`.
4) VT Parser: `src/terminal/parser/*.zig` (byte stream to actions).
5) Screen Model: `src/terminal/model/*` (grid + scrollback + selection).
6) Protocol Handlers:
   - `src/terminal/protocol/csi.zig`
   - `src/terminal/protocol/osc.zig`
   - `src/terminal/protocol/dcs_apc.zig`
7) Kitty Graphics: `src/terminal/kitty/graphics.zig`
8) Input Encoding: `src/terminal/input/key_encoder.zig` + `src/terminal/input/key_encoding.zig` (CSI u/kitty mapping)

## Stable API Surface (public)
`TerminalSession` should expose only:
- lifecycle: `init`, `deinit`, `start`, `poll`, `resize`, `setCellSize`
- input: `sendKey`, `sendKeypad`, `sendChar`, `sendText`, `reportMouseEvent`
- state: `snapshot`, `selectionState`, `clearSelection`
- queries: `currentCwd`, `takeOscClipboard`, `hyperlinkUri`, `isAlive`
- locks: `lock`, `unlock`

`TerminalSnapshot` contract:
- Borrowed slices, valid until next snapshot.
- No per-frame allocations during render.

## Contract-First API Spec
Add `app_architecture/terminal/TERMINAL_API.md` with a per-API contract table:
- ownership/lifetime of returned data
- allocation behavior
- thread/concurrency expectations
- invariants (cursor bounds, scrollback rules, alt-screen rules)
- error semantics (error sets, when failures can occur)
- tests that cover the contract

## Feature Inventory (code-derived)
Before refactor, generate a feature list directly from current code:
- OSC/CSI/DCS/APC coverage from handler switch statements
- key encoding + modifier rules from input encoder
- kitty graphics actions supported (store/place/delete/clear)
Capture this list in `app_architecture/terminal/FEATURE_INVENTORY.md`.

## Test-First Safety Net
Approved fixture list (authoritative; 19 total):
- VT replay fixtures (18):
  - cursor_moves_basic
  - erase_line_and_display
  - insert_delete_chars
  - scroll_region_basic
  - sgr_16_256_truecolor
  - sgr_reverse_and_reset
  - alt_screen_enter_exit
  - scrollback_push
  - osc_title_bel
  - osc_cwd_st
  - osc_8_hyperlink_bel
  - osc_52_clipboard_bel
  - utf8_wide_and_combining
  - selection_basic_flow (harness API hooks)
  - kitty_store_place_delete
  - gping_redraw
  - nvim_overlay
  - vttest_wraparound
- Encoder unit test (1):
  - csi_u_encoder_bytes

Separation is enforced:
- VT replay tests
- harness API tests (selection)
- encoder unit tests (CSI-u)

## Baseline Fixture Capture (golden tests)
Add a replay harness to:
- feed a `.vt` fixture
- emit a deterministic snapshot string (grid + cursor + attrs + scrollback summary)
- store baseline goldens from current implementation before moving code

Approved replay harness outline is the design source of truth:
- snapshot string must encode title/cwd/clipboard/hyperlink tagging state
- grid encoding must be deterministic (blank cells, attrs encoding, wide-char handling, scrollback view)

## Layer Enforcement
Define explicit layer rules (e.g., UI → core → model/parser/io).
Add a lightweight build-time check to block forbidden imports or deep coupling.
Layer check implemented via `zig build check-terminal-imports` (see `tools/terminal_import_check.zig`).
Document allowed import directions before any refactor work begins.

## Migration Steps (incremental, each builds + tests)
1) Implement replay harness (per approved outline; no refactor).
2) Capture baseline golden fixtures from current implementation.
3) Generate `FEATURE_INVENTORY.md` derived from code.
4) Finalize `TERMINAL_API.md` with contracts tied to fixtures/tests.
5) Extract snapshot types into `core/snapshot.zig` (pure move + re-export).
6) Extract protocol handlers (CSI/OSC/DCS/APC) into `terminal/protocol`.
7) Extract kitty graphics into `terminal/kitty/graphics.zig`.
8) Move screen ops into `model/screen_ops.zig` or expand `model/screen.zig`.
9) Move selection state/extraction into `model/selection.zig`.
10) Reduce `terminal/core/terminal.zig` to a thin orchestrator.

Progress:
- Completed step 5 (snapshot types + encoding extracted into `terminal/core/snapshot.zig`).
- Completed step 6 (protocol handlers extracted into `terminal/protocol`).
- Completed step 7 (kitty graphics extracted into `terminal/kitty/graphics.zig`).
- Completed step 8 (screen ops expanded in `terminal/model/screen.zig`).
- Completed step 9 (selection types/state in `terminal/model/selection.zig`).
- Completed step 10 (terminal core now a thin orchestrator; screen helpers consolidated under `terminal/model/screen/` with facade).
- Scrollback push ordering aligned with Ghostty/Kitty; `scrollback_push` golden updated.
- Completed step 3 (feature inventory captured in `app_architecture/terminal/FEATURE_INVENTORY.md`).
- Migration step: extracted terminal render cache to `src/terminal/core/render_cache.zig` (no behavior change).
- Migration step: extracted palette + dynamic color handling to `src/terminal/protocol/palette.zig` (no behavior change).
- Migration step: extracted OSC semantic prompt + user-var handling to `src/terminal/protocol/osc_semantic.zig` (no behavior change).
- Migration step: extracted OSC clipboard handling to `src/terminal/protocol/osc_clipboard.zig` (no behavior change).
- Migration step: extracted OSC CWD normalization + decode helpers to `src/terminal/protocol/osc_cwd.zig` and `src/terminal/protocol/osc_util.zig` (no behavior change).
- Migration step: extracted OSC hyperlink handling to `src/terminal/protocol/osc_hyperlink.zig` (no behavior change).
- Migration step: extracted OSC title handling to `src/terminal/protocol/osc_title.zig` (no behavior change).
- Migration step: extracted mouse reporting helpers to `src/terminal/input/mouse_report.zig` (no behavior change).
- Migration step: extracted key encoding helpers to `src/terminal/input/key_encoding.zig` (no behavior change).
- Migration step: extracted keypad mappings to `src/terminal/input/keypad.zig` (no behavior change).
- Migration step: extracted PTY start/poll to `src/terminal/core/pty_io.zig` (no behavior change).
- Migration step: extracted I/O thread helpers to `src/terminal/core/io_threads.zig` (no behavior change).
- Migration step: extracted view cache pipeline to `src/terminal/core/view_cache.zig` (no behavior change).
- Migration step: extracted resize + reflow logic to `src/terminal/core/resize_reflow.zig` (no behavior change).
- Migration step: extracted scrolling helpers to `src/terminal/core/scrolling.zig` (no behavior change).
- Migration step: extracted selection helpers to `src/terminal/core/selection.zig` (no behavior change).
- Migration step: extracted control handlers to `src/terminal/core/control_handlers.zig` (no behavior change).
- Migration step: extracted parser glue to `src/terminal/core/parser_hooks.zig` (no behavior change).
- Migration step: extracted input mode helpers to `src/terminal/core/input_modes.zig` (no behavior change).
- Migration step: extracted hyperlink table helpers to `src/terminal/core/hyperlink_table.zig` (no behavior change).
- Migration step: extracted reset/save/restore helpers to `src/terminal/core/state_reset.zig` (no behavior change).
- Migration step: extracted scrollback accessors to `src/terminal/core/scrollback_view.zig` (no behavior change).
- Migration step: extracted session metadata/hyperlink/clipboard/close-confirm query helpers to `src/terminal/core/session_queries.zig` (no behavior change).
- Migration step: extracted generation/backlog/presentation feedback helpers to `src/terminal/core/session_publication.zig` (no behavior change).
- Migration step: extracted scrollback/text-export/scroll-offset content helpers to `src/terminal/core/session_content.zig` (no behavior change).
- Migration step: extracted selection passthrough helpers to `src/terminal/core/session_selection.zig` (no behavior change).
- Migration step: extracted key/char/text/mouse/focus/color-scheme input helpers to `src/terminal/core/session_input.zig` (no behavior change).
- Migration step: extracted input-state query, mouse-reporting, and OSC 5522 paste helpers to `src/terminal/core/session_interaction.zig` (no behavior change).
- Migration step: extracted snapshot/render-cache/sync-updates damage-retirement helpers to `src/terminal/core/session_rendering.zig` (no behavior change).
- Migration step: extracted parser/control/screen-edit/alt-screen/DECRQSS protocol helpers to `src/terminal/core/session_protocol.zig` (no behavior change).
- Migration step: extracted palette/theme/column-mode/cell-size config helpers to `src/terminal/core/session_config.zig` (no behavior change).
- Migration step: extracted PTY startup/poll/child-exit/write-lock/resize runtime helpers to `src/terminal/core/session_runtime.zig` (no behavior change).
- Migration step: moved `TerminalSession` regression coverage out of `src/terminal/core/terminal_session.zig` into `src/terminal/core/terminal_session_tests.zig`, so the runtime owner no longer carries nearly 1k lines of test-only session/render/selection coverage inline.
- Migration step: extracted the `Screen` edit/erase/scroll mutation block into `src/terminal/model/screen/edit_ops.zig`, leaving `screen.zig` with the same public API but delegating the heavy edit/scroll owner into a focused submodule.
- Migration step: extracted `Screen` cursor/margin/tab/newline navigation into `src/terminal/model/screen/navigation_ops.zig`, leaving `screen.zig` with the same public API but delegating cursor movement and margin policy into a focused submodule.
- Migration step: extracted `Screen` codepoint/ascii/write-prep handling into `src/terminal/model/screen/write_ops.zig`, leaving `screen.zig` with the same public API but delegating the remaining write-path owner into a focused submodule.
- Migration step: extracted CSI reply/query helpers into `src/terminal/protocol/csi_reply.zig`, so `csi.zig` no longer owns the writer/query contexts plus DA/DSR/window-op reply formatting inline.
- Migration step: extracted CSI mode-query snapshot/state handling into `src/terminal/protocol/csi_mode_query.zig`, so `csi.zig` no longer owns DECRQM snapshot capture and mode-state lookup inline.
- Migration step: extracted CSI simple/special execution helpers into `src/terminal/protocol/csi_exec.zig`, so `csi.zig` no longer owns cursor/edit/scroll/tab and special control execution inline.
- Migration step: extracted CSI `SM`/`RM` mode mutation policy into `src/terminal/protocol/csi_mode_mutation.zig`, so `csi.zig` no longer owns the DEC/private/input mode mutation implementation inline.
- Migration step: extracted CSI SGR and DECSTR style/reset handling into `src/terminal/protocol/csi_style_reset.zig`, so `csi.zig` no longer owns style-attribute mutation and soft-reset implementation inline.
- Migration step: removed the stale duplicate DECRQSS SGR formatting helpers from `src/terminal/core/terminal_session.zig`, leaving `src/terminal/core/session_protocol.zig` as the single owner of DECRQSS reply assembly.
- Migration step: moved `TerminalSession` teardown into `src/terminal/core/session_runtime.zig`, so `terminal_session.zig` no longer owns PTY/thread shutdown and broad resource destruction inline.
- Follow-up (2026-03-10): moved terminal widget presentation capture/finish handshake behind backend-owned methods in `src/terminal/core/session_rendering.zig` / `terminal_session.zig`, so `terminal_widget.zig` no longer assembles published-cache copy timing and completion feedback inline.
- Follow-up (2026-03-10): moved system clipboard paste fallback policy behind backend-owned `pasteSystemClipboard(...)` in `src/terminal/core/session_clipboard.zig`, so `terminal_widget.zig` no longer owns scrollback reset, OSC 5522 fallback, bracketed framing, or ESC/Ctrl-C filtering behavior.
- Follow-up (2026-03-10): moved middle-click selection paste fallback behind backend-owned `pasteSelectionClipboard(...)` in `src/terminal/core/session_clipboard.zig`, so `terminal_widget_input.zig` no longer duplicates OSC 5522 / bracketed / plain-text paste policy.
- Follow-up (2026-03-10): moved scrollback-view collapse-on-input policy behind backend-owned `resetToLiveBottomForInputLocked(...)` in `src/terminal/core/scrollback_view.zig`, so `terminal_widget_input.zig` no longer owns the actual live-bottom reset rule.
- Follow-up (2026-03-10): deduplicated terminal scrollbar ratio mapping through shared UI helper `common.scrollbarTrackRatio(...)`, so draw and input no longer carry separate offset-to-thumb formulas.
- Follow-up (2026-03-09): expanded `app_architecture/terminal/TERMINAL_API.md` with an explicit boundary contract for runtime/protocol/model/publication/widget ownership.
- Follow-up (2026-03-09): removed the file-global visible-terminal poll input-activity hint; terminal input pressure is now passed explicitly into `poll_visible_terminal_sessions_runtime.handle(...)`.
- Follow-up (2026-03-09): moved terminal idle/pacing bookkeeping out of `frame_render_idle_runtime` file globals and into `AppState` so scheduler state is instance-owned.
- Follow-up (2026-03-09): removed the stale snapshot-based hover/open widget path so terminal hover/open now has one authoritative visible-cache seam.
- Follow-up (2026-03-09): removed the dead `TerminalSession.markDirty()` / `Screen.markDirtyAll()` escape-hatch APIs and their dedicated full-dirty reasons.
- Follow-up (2026-03-09): removed additional dead leftovers from the old snapshot/open seam (`TerminalSession.clearDirty()` and the unused snapshot row helper in `terminal_widget_open.zig`).
- Follow-up (2026-03-09): removed the dead unbounded `TerminalWorkspace.pollAll()` API so workspace polling surface now matches the budgeted scheduler design.
- Follow-up (2026-03-09): extracted workspace polling/fairness implementation into `src/terminal/core/workspace_polling.zig` so `workspace.zig` moves closer to tab/session ownership rather than scheduling policy.
- Follow-up (2026-03-09): removed the now-dead public `TerminalWorkspace.pollBudgeted(...)` surface after `pollForFrame(...)` became the workspace-owned polling contract used by app runtime.
- Follow-up (2026-03-09): removed the public `TerminalWorkspace.PollBudget` type after poll budgets became an internal workspace-polling detail instead of part of the live runtime contract.
- Follow-up (2026-03-09): added explicit read-only workspace generation/data queries so app runtime pacing code can avoid raw session-pointer access when it only needs polling/publication state.
- Follow-up (2026-03-09): added explicit workspace cwd/close-confirm query helpers and rewired read-only app callers off `sessionAt(...)` / `activeSession()` where they only needed derived state.
- Follow-up (2026-03-09): extracted terminal frame pacing/latency/generation observation into `src/app/terminal_frame_pacing_runtime.zig` so `frame_render_idle_runtime.zig` acts as a coordinator instead of embedding terminal scheduler policy inline.
- Follow-up (2026-03-09): grouped terminal frame pacing bookkeeping into `AppState.terminal_frame_pacing` so runtime scheduler state stops leaking across the top-level app state as unrelated scalar fields.
- Follow-up (2026-03-09): removed the dead frame-pacing `pressure_since` timestamp after the runtime extraction confirmed it was no longer read by any scheduler path.
- Follow-up (2026-03-09): extracted visible-terminal poll budget/pressure/publication detection into `src/app/terminal_poll_runtime.zig` so `poll_visible_terminal_sessions_runtime.zig` stops embedding terminal polling policy inline.
- Follow-up (2026-03-09): moved concrete per-frame workspace poll budgets behind `TerminalWorkspace.pollForFrame(...)` so app runtime no longer owns those fairness constants directly.
- Follow-up (2026-03-09): introduced `TerminalSession.acknowledgePresentedGeneration(...)` so widget draw no longer manually composes presented-generation publication with dirty-retirement calls.
- Follow-up (2026-03-09): moved sync-updates dirty-retirement choice behind `TerminalSession.acknowledgePresentedGeneration(...)` so widget draw no longer supplies that policy bit either.
- Follow-up (2026-03-09): removed the old paired generation-guarded dirty-clear APIs from the public session surface and collapsed them into one backend-owned retirement helper behind `acknowledgePresentedGeneration(...)`.
- Follow-up (2026-03-09): routed common input-mode snapshot updates through explicit `input_modes` setters so CSI mode toggles no longer open-code field mutation plus `updateInputSnapshot()` at each call site.
- Follow-up (2026-03-09): extracted DECSTR input-mode reset into `input_modes.resetInputModes(...)` so soft reset stops duplicating snapshot-owned field resets inline.
- Follow-up (2026-03-09): routed alt-screen transitions through `setActiveScreenMode(...)` so active-screen publication and snapshot refresh stop being open-coded in enter/exit paths.
- Follow-up (2026-03-10): typed OSC 5522 clipboard write boundaries behind `WriterFacade` so reply/status/data emission no longer depends on implicit `anytype` PTY write seams.
- Follow-up (2026-03-10): typed CSI reply emission behind `CsiWriter` (`DA`/`DSR`/`DECRQM`/window op/color-scheme replies) while keeping compatibility wrappers at the public helper surface.
- Follow-up (2026-03-10): moved terminal selection row/word/range semantics into `src/terminal/model/selection_semantics.zig` and routed widget click/drag/scrollbar selection behavior through backend-owned helpers in `src/terminal/core/selection.zig`.
- Follow-up (2026-03-10): removed terminal-only scrollbar drag state from generic app runtime state and moved that ownership onto `TerminalWidget`, shrinking the app/widget glue surface.
- Follow-up (2026-03-10): extracted explicit terminal poll and sleep policy structs plus unit coverage in `src/app/terminal_poll_runtime.zig` and `src/app/terminal_frame_pacing_runtime.zig` so runtime scheduling constants stop living as anonymous inline heuristics.
- Follow-up (2026-03-10): typed the top-level parser dispatch seam in `src/terminal/core/parser_hooks.zig` behind an explicit session facade, so `TerminalSession` no longer calls parser hook entrypoints through raw `anytype` generics.
- Follow-up (2026-03-10): removed the dead public `TerminalSession.parseKittyGraphics(...)` bounce and rewired `src/terminal/protocol/dcs_apc.zig` to target the kitty graphics parser module directly, reducing one more protocol-to-session indirection seam.
- Follow-up (2026-03-10): typed the VT parser callback contract in `src/terminal/parser/parser.zig` behind `Parser.SessionFacade`, and rewired terminal-session, PTY polling, IO-thread parsing, and test debug feed paths to use that explicit parser/session boundary.
- Follow-up (2026-03-10): extracted CSI query/reply dispatch (`DSR`, `DA`, bounded window ops, `DECRQM`) behind a typed `QueryContext` plus dedicated helpers in `src/terminal/protocol/csi.zig`, shrinking the inline PTY/query logic inside the monolithic CSI handler.
- Follow-up (2026-03-10): extracted CSI `SM`/`RM` mode mutation policy behind an explicit `ModeMutationContext` in `src/terminal/protocol/csi.zig`, so DEC/private/input mode toggles no longer stay open-coded inside the main CSI switch.
- Follow-up (2026-03-10): extracted CSI `DECRQM` mode snapshot capture behind `ModeQueryContext` in `src/terminal/protocol/csi.zig`, so query-time mode-state capture no longer open-codes the full session/screen field read set inside the main CSI switch.
- Follow-up (2026-03-10): extracted the simple CSI execution family behind `SimpleCsiContext` in `src/terminal/protocol/csi.zig`, so cursor movement, tabbing, erase/edit, scroll-region, save/restore cursor, and cursor-style handling no longer stay repeated inline across the monolithic CSI switch.
- Follow-up (2026-03-10): extracted the remaining simple special-case CSI branch family behind `SpecialCsiContext` in `src/terminal/protocol/csi.zig`, so `SCP`/`DECSLRM`, cursor restore and key-mode control (`CSI u` variants), `DECSCUSR`, and tab-clear handling no longer stay open-coded in the top-level switch.
- Follow-up (2026-03-10): extracted the CSI reply/control branch family behind `ReplyCsiContext` in `src/terminal/protocol/csi.zig`, so `DSR`, `DA`, bounded window ops, `DECRQM`, and `DECSTR` lock/dispatch policy no longer stay orchestrated inline in the top-level switch.
- Follow-up (2026-03-10): extracted parser text-write execution in `src/terminal/core/parser_hooks.zig` behind an explicit `TextWriteContext`, so codepoint/ascii write paths no longer reach through raw session state for charset, hyperlink, wrap, and insert behavior.
- Follow-up (2026-03-10): extracted CSI cursor/grid reply reads behind `ScreenQueryContext` in `src/terminal/protocol/csi.zig`, so `DSR` and bounded window-op replies no longer depend on implicit raw screen shapes inside the reply helpers.
- Follow-up (2026-03-10): collapsed `src/terminal/protocol/osc.zig` into a typed composite facade over the split OSC submodules, so the top-level OSC router no longer adds another opaque trampoline layer on top of title/palette/hyperlink/cwd/clipboard/semantic handlers.
- Follow-up (2026-03-10): collapsed `src/terminal/protocol/osc_title.zig`, `osc_hyperlink.zig`, `osc_util.zig`, and `osc_semantic.zig` from opaque callback facades into direct typed state holders, so those OSC helper modules no longer stack another generic adapter layer on top of already-structured parser state.
- Follow-up (2026-03-10): collapsed `src/terminal/protocol/osc_clipboard.zig`, `palette.zig`, and the tiny `osc_cwd.zig -> osc_util.zig` bounce toward direct typed state holders, so OSC 52, palette/dynamic-color, and cwd normalization logic no longer carry wide opaque callback facades for simple owned state reads.
- Follow-up (2026-03-10): extracted the terminal widget keyboard/text dispatch block into `src/ui/widgets/terminal_widget_keyboard.zig`, so `terminal_widget_input.zig` no longer embeds the large key/text alternate-metadata and send-path orchestration block inline.
- Follow-up (2026-03-10): extracted the locked pointer/selection/scrollback block into `src/ui/widgets/terminal_widget_pointer.zig`, so `terminal_widget_input.zig` no longer embeds scrollbar drag, selection gesture, middle-click paste, or wheel-scroll orchestration inline.
- Follow-up (2026-03-10): extracted the terminal mouse-reporting block into `src/ui/widgets/terminal_widget_mouse_reporting.zig`, so `terminal_widget_input.zig` now acts as a top-level coordinator over keyboard, pointer, hover/open, and mouse-report paths instead of embedding the remaining terminal mouse protocol send loop inline.
- Follow-up (2026-03-10): split the kitty graphics query (`a=q`) execution path out of `parseKittyGraphics(...)` into dedicated helpers in `src/terminal/kitty/graphics.zig`, separating query payload load/inflate/build-probe/reply policy from the main store/place/delete flow.
- Follow-up (2026-03-10): split the kitty upload/store path (`a=t`/`a=T`) out of `parseKittyGraphics(...)` into dedicated helpers in `src/terminal/kitty/graphics.zig`, separating upload-id resolution, decode/accumulate, final build/store, and optional placement/reply policy from top-level dispatch.
- Follow-up (2026-03-10): split kitty placement/delete execution policy out of the top-level graphics flow in `src/terminal/kitty/graphics.zig`, including dedicated helpers for placement requests and the major delete selector families (`all`, id-based, point, z, range, row, column).
- Follow-up (2026-03-10): consolidated kitty image lifecycle teardown in `src/terminal/kitty/graphics.zig` so `evict`, `delete`, and image replacement now share explicit helpers for dropping placements, partial upload state, and stored image bytes instead of open-coding those destructive paths in multiple places.
- Follow-up (2026-03-10): consolidated kitty payload transport/build logic behind an internal `KittyTransport` boundary in `src/terminal/kitty/graphics.zig`, so query/upload paths now share one authoritative implementation for payload load, file/shm transport, inflate, partial accumulation, expected-size checks, and image build.
- Follow-up (2026-03-10): extracted kitty shared state/types into `src/terminal/kitty/common.zig` and payload transport/build into `src/terminal/kitty/transport.zig`, so `graphics.zig` no longer owns the shared kitty data model plus transport/build implementation in one file.
- Follow-up (2026-03-10): extracted kitty placement mutation/query/scroll/placement execution into `src/terminal/kitty/placement_ops.zig`, so `graphics.zig` no longer embeds the placement graph helper implementation alongside protocol/storage code.
- Follow-up (2026-03-10): extracted kitty byte-store replacement/eviction/clear/deinit lifecycle into `src/terminal/kitty/storage_ops.zig`, so `graphics.zig` no longer embeds the storage lifecycle implementation alongside protocol/delete logic.
- Follow-up (2026-03-10): extracted kitty protocol parse/control/reply and delete-selector orchestration into `src/terminal/kitty/protocol_ops.zig`, so `graphics.zig` is now a thin facade/re-export layer plus tests rather than the kitty backend implementation blob.
- Follow-up (2026-03-10): extracted kitty placement-graph mutation/query/dirty logic behind an internal `KittyPlacementOps` boundary in `src/terminal/kitty/graphics.zig`, so placement lookup, dirty marking, image-placement teardown, and effective cursor-span calculation no longer stay duplicated across store/place/delete paths.
- Follow-up (2026-03-10): extracted kitty image storage/eviction/clear ownership behind an internal `KittyStorageOps` boundary in `src/terminal/kitty/graphics.zig`, so byte-store replacement, capacity eviction, partial cleanup, and clear-all flows no longer stay interleaved with placement and top-level parser dispatch code.
- Follow-up (2026-03-10): extracted kitty top-level parse/control/reply policy behind an internal `KittyProtocolOps` boundary in `src/terminal/kitty/graphics.zig`, so command parsing, validation, query/upload reply policy, and dispatch no longer stay smeared across the module-level entry helpers.

## Regression Checklist (keep in sync)
- OSC coverage: 0/2/7/8/10/11/12/19/52 + XTGETTCAP.
- SGR: 16/256/truecolor + bold/reverse.
- CSI: cursor, erase, insert/delete, scroll region, DA/DSR.
- Alt screen state + scrollback rules.
- Kitty graphics (payload decode as currently implemented, placements, delete actions).
- Key input: CSI u/kitty flags + modifier handling.

## Refactor Rules (hard)
- Extraction-only until tests and goldens pass.
- No behavior changes during file moves; any semantic change requires a separate, test-driven step.
- Keep diffs small and reviewable; do not move multiple subsystems at once.
- Extraction-only constraint: no renaming of public symbols, no logic changes, no behavior-motivated simplifications, no "while we're here" cleanups.

## Decisions Locked
- Approved fixture list (19 total) is authoritative.
- Replay harness snapshot format is fixed by the approved outline.
- Tests + goldens gate all refactors.
- Extraction-only means no renames, no cleanup, no behavior changes.

## Historical Progress Archive

The detailed hotspot reviews, the strict cleanup queue, and the 2026-03-09
sequencing ledger were moved out of this active queue to keep it readable.

See:

- `docs/review/archive/terminal/MODULARIZATION_PROGRESS_2026-03-09.md`
