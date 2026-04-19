# CZH-861: Maturity audit + movement scope lock

Date: 2026-04-19  
Sprint: `CZH-S32`  
Batch: `CZH-B37`  
Gate target: `CZH-GATE-91`

## Executive Summary

Deep-dive audit of caller placements blocking the intended mature split between VT core FFI, BYO-PTY seam, editor backend FFI, and terminal presentation/runtime ownership.

**Key Finding:** The crossing boundary between terminal logic and renderer is managed by UI-layer widget code, creating implicit ownership. This violates the "caller placement is not architecture authority" rule from CZH-B36.

## Audit Scope & Findings

### Cross-Boundary Caller Analysis

**Terminal imports in UI/widgets layer:**
- `terminal_widget_presentation_runtime.zig`: 12 terminal imports (MAJOR crossing point)
- `terminal_widget_draw.zig`: 12 terminal imports
- `terminal_widget_presentation_state.zig`: 1 terminal import
- `terminal_widget_surface_state.zig`: 7 terminal imports

**Renderer imports in UI/widgets layer:**
- `terminal_widget_presentation_runtime.zig`: 7 renderer imports (MAJOR crossing point)
- `terminal_widget_draw.zig`: 5 renderer imports
- `terminal_widget_kitty.zig`: 4 renderer imports

### Primary Blocker: Terminal Presentation Ownership

| Item | Current Owner | Current File | Intended Owner | Blocker |
|------|---------------|--------------|----------------|---------|
| `notePresentableAvailability` | UI Widget | `terminal_widget_surface_state.zig` | Terminal layer | Widget owns terminal->renderer coordination; should be terminal-presentation seam |
| `readSharedSurfaceAttachmentReady` | UI Widget | `terminal_widget_surface_state.zig` | Terminal layer | Same: widget surface state should delegate to terminal-owned layer |
| `surface_attachment_contract` coordination | Terminal primitive | `src/terminal/surface_attachment_contract.zig` | Terminal-presentation layer | Contract is in terminal, but application logic (conjunction threading) is in UI widgets |
| `terminal_widget_presentation_runtime` orchestration | UI Widget | `src/ui/widgets/terminal_widget_presentation_runtime.zig` | Terminal-presentation boundary | This file manages terminal->renderer flow; belongs in terminal layer or explicit seam, not deep in UI |
| `TerminalPresentableRefresh` flow | UI Widget | Used in presentation_runtime | Terminal runtime layer | Refresh cycle should be terminal-owned, not widget-managed |

### Secondary Blockers: Input/Output Seams

| Item | Current Owner | Intended Move | Rationale |
|------|---------------|---------------|-----------|
| Input event mapping (mouse/key) | UI Widget | Terminal seam layer | `terminal_widget_input*.zig` converts UI events but lives in UI layer |
| Publication cache locking | Terminal core | Consider widget wrapper | `renderCacheLocked` calls from widget suggest locking strategy might have split ownership |
| Frame pacing logic | UI Widget | Terminal runtime | Timing/pacing is terminal concern but managed in widget layer |

## Concrete Movement Candidates (Ranked)

### Candidate 1: Terminal-Presentation Seam Helper (HIGH PRIORITY)

**Current state:** `notePresentableAvailability` and `readSharedSurfaceAttachmentReady` live in `terminal_widget_surface_state.zig`.

**Blocker:** Widget layer owns the canonical route for terminal attachment readiness. This embeds terminal semantics in UI.

**Proposed move:** Extract a `terminal_presentation_bridge.zig` module in `src/terminal/` that owns:
- Conjunction computation (`notePresentableAvailability` wrapper)
- Conjunction reading (`readSharedSurfaceAttachmentReady` wrapper)
- Widget surface state becomes thin storage/delegation layer

**Risk:** Widget->terminal dependency inversion (low risk; already happens through imports).

**Why S32:** CZH-B36 proved ownership assumptions can be wrong; this move makes ownership explicit.

### Candidate 2: Terminal Presentation Runtime Ownership (MEDIUM PRIORITY)

**Current state:** `terminal_widget_presentation_runtime.zig` coordinates terminal→renderer flow.

**Blocker:** Presentation orchestration (refresh cycles, outcome classification, fold logic) is terminal semantics but owned by UI layer.

**Proposed move:** Move to `src/terminal/presentation/` as:
- `terminal_presentation_runtime.zig` (core logic)
- Widget layer becomes thin facade wrapping terminal layer

**Risk:** Reverse dependency (widget calls terminal presentation); needs careful caller analysis.

**Why defer to S33:** This is larger reshaping; S32 should focus on attachment ownership first.

### Candidate 3: Input/Output Seam Consolidation (MEDIUM PRIORITY)

**Current state:** `terminal_widget_input*.zig` modules map UI events to terminal calls.

**Blocker:** Input seam belongs with BYO-PTY and session handling, not scattered in widget layer.

**Proposed move:** Consolidate input/output mapping into `src/terminal/widget_io_bridge.zig` alongside `byo_pty_host.zig`.

**Risk:** Moderate refactoring; affects multiple input handlers.

**Why defer to S33:** Depends on S32 attachment clarity first.

## Explicit "Do Not Move in S32" List

| Blocker | Reason | Defer To |
|---------|--------|----------|
| Widget draw logic (`terminal_widget_draw*.zig`) | Pure UI rendering; belongs in UI layer. No terminal ownership ambiguity. | N/A - not a mover |
| Editor widget/FFI | Independent seam; editor backend ownership is clear. | N/A - not a mover |
| Kitty graphics layer | Renderer-focused; no terminal ownership question. | N/A - not a mover |
| Publication cache architecture | Core's rendering cache strategy; moving mid-S32 risks stability. | CZH-B38 or later |
| Session loop threading | Critical runtime path; move only after attachment clarity lands. | CZH-B38 |

## Scope Lock for CZH-862..CZH-870

**S32 focus: One concrete movement (Candidate 1).**

- **CZH-862:** Authority tightening so `TerminalPresentationBridge` ownership is explicit (doc-only)
- **CZH-863/864:** Extract `notePresentableAvailability` and `readSharedSurfaceAttachmentReady` into terminal layer
- **CZH-865..870:** Validate, test, hygiene

**No ABI/export changes:** Candidate 1 is internal refactoring only.

**No compatibility path:** Single-path extraction; old widget-surface ownership removed entirely.

## Constraints from CZH-B36

✓ **Startup fix proved runtime order assumptions can be wrong when ownership is implicit:**
This audit found explicit ownership ambiguity in `notePresentableAvailability` (implicit where it's defined vs where it's semantically owned).

✓ **Caller placement is not architecture authority:**
This audit revealed `terminal_widget_presentation_runtime` and `terminal_widget_surface_state` place callers in UI layer when they should be in terminal layer.

✓ **Source comments must stay architectural:**
All movement candidates will update comments to reflect moved ownership.

## Ready for CZH-862

✓ Audit complete. Primary blocker identified (terminal-presentation boundary ownership).  
✓ Ranked movement candidate locked (Candidate 1: terminal-presentation seam).  
✓ "Do not move" list explicit.  
✓ CZH-B36 constraints validated by audit findings.  
✓ Proceeding with authority tightening (CZH-862) and concrete movement (CZH-863/864).
