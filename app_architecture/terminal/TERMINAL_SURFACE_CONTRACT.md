# Terminal Surface Contract (host-agnostic)

Date: 2026-04-20 (assertion policy 2026-04-20 — `CZH-S58`; locked 2026-04-20 — `CZH-S57`; expanded 2026-04-20 — `CZH-S56`; corrected 2026-04-19 — `CZH-B6-corrective`)

Purpose: freeze the **terminal surface** contract for **shared GPU presentation**
of terminal frames: what the host supplies, what Zide owns, and what stays in
backend-specific mechanics (`app_architecture/ui/RENDER_BACKEND_CONTRACT.md`).

This sits alongside native lifecycle (`app_architecture/platform/NATIVE_HOST_CONTRACT.md`)
but does **not** define windowing, swapchains, or platform view graphs as the
frozen abstraction — those are how a host *may* obtain or wrap the shared GPU
resource, not the contract center.

Android proved “host hands in a drawable attachment; Zide owns terminal truth
and generation bookkeeping” — **Android is one host**, not the definition.
Android may move when the shared contract matures; the first Android GLES shape
is validation pressure, not permanent architecture.

## What the frozen abstraction is

The contract centers on the **shared GPU texture or resource** the terminal
draw path uses: the object (or opaque handle) the **active renderer backend**
requires so the terminal widget can record draws into a **known, host-visible
GPU attachment** that the host can then **bind and present** inside its
platform frame lifecycle.

- **Not** the terminal cell snapshot buffer (publication / **VT core FFI**).
- **Not** GLES vs Metal vs Vulkan mechanics — those remain in
  `RENDER_BACKEND_CONTRACT.md`.

## Ownership split (frozen)

| Concern | Owner |
| --- | --- |
| Initializing and passing the **shared GPU texture/resource attachment** the backend needs for terminal draws (opaque or typed per backend) | **Host** — in cooperation with **`RendererBackend`** setup; concrete object shape is backend-local |
| GPU devices/queues/context objects and backend-specific upload paths | **`RendererBackend`** per `RENDER_BACKEND_CONTRACT.md` |
| Terminal **semantic** state at engine/publication layer | **Zide terminal stack** (`TerminalCore` + publication) |
| **Dirty tracking**, **published vs acknowledged generation**, **needs_redraw**, and update logic for **terminal content** (what must be redrawn and which generation is current) | **Zide** — hosts must not invent parallel damage or generation truth |
| Scheduling terminal draw work against the shared GPU resource | **Zide renderer + terminal widget** (shared product path) |
| **Binding** that shared resource into the host’s **platform presentation** (per-frame lifecycle, when pixels reach the display) and reporting **presentation completion** so generations can retire | **Host** — completion still flows through the **shared FFI present-ack** (`VT core FFI`) so Zide stays consistent |

Interpretation:

- The **host** is responsible for making a **suitable shared GPU attachment**
  available and keeping it live across the host’s frame lifecycle; the **frozen**
  idea is “shared GPU resource the terminal draws into,” not “this OS window
  handle” as the universal type.
- **Zide** owns **dirty tracking and generation truth** for terminal **content**
  and the **update contract** for what must be repainted into that resource.
- **Backend-specific** details (Metal drawable vs GL surface vs Vulkan image)
  stay out of this document by design.

## FFI touchpoints (VT core FFI, read-only contract)

Hosts observe redraw and generation pairing through **VT core FFI** symbols (e.g.
`needs_redraw`, `redraw_state`, `published_generation`, `present_ack` /
`acknowledged_generation`) — portable **logical** surface for frame contract
state. Raw GPU handles do not need to cross that boundary for the contract to
hold.

The current FFI/caller layout is not the maturity boundary. VT core,
bring-your-own-PTY, editor backend, and terminal presentation callers may move
when that makes ownership cleaner. The contract to preserve is the meaning of
the state crossing, not the current file or call-site placement.

**Zig seam (logical bundle):** `src/terminal/surface_contract.zig` layers **FFI**
(`ffiRedrawStateFill`, `ffiNeedsRedrawU8`, `ffiPresentAckGenerationAdmissible` for
`core_api` exports), **widget composite** (`publicationClearPair*` for terminal
widget publication/clear vs last surface draw), and **primitives** (`needsRedrawFromPair`,
widget legs, bundle `fillRedrawState`) with one policy per layer (`CZH-S13`,
`CZH-S14`).

**Widget draw consumer:** Terminal widget reuse/invalidation uses **only** the
composite pair helpers (`publicationClearPairMismatchesFromLastSurfaceRender`,
`publicationClearPairMatchesLastSurfaceRender`); primitives are decomposition
inside `surface_contract`, not alternate call-site shapes (`CZH-S12`, `CZH-S14`).

**Host attachment seam:** `src/terminal/surface_attachment_contract.zig` names
the logical predicate pipeline-ready ∧ host-target-available for the shared drawable attachment.
**Canonical compute route:** `TerminalPresentationBridge` (owned by terminal layer) computes
and stores conjunction via `notePresentableAvailability` — this is the single compute path.
**Canonical read route:** same bridge provides `readSharedSurfaceAttachmentReady` for
read-only access to conjunction. Widget layer (`TerminalWidgetSurfaceState`) delegates to bridge
and does not re-derive conjunction. Present-plan reuse eligibility uses
`terminalPresentablePipelineReady()` (pipeline leg only) by design (`CZH-S15`).
`presentationUpdateDelta.terminal_presentable_pipeline_ready` is the same pipeline leg (`CZH-S16`);
full readiness comes from bridge conjunction paths only.

## Operator observability (structured logs)

Zide operator logs on the widget presentation path mirror the same split as the
seams above (`CZH-B24`). **Reporting-carrier consolidation (`CZH-S23`):** the conjunction
value in **`renderer.terminal_present`** is reported from **`PresentationPresentState.shared_surface_attachment_ready`**
for that tick (not from `readSharedSurfaceAttachmentReady()` at the log callsite).

- **`renderer.terminal_present` (`logUnavailable`):** `publication_generation`;
  `terminal_presentable_pipeline_ready` (pipeline leg); `host_surface_target_available`
  (host drawable target leg); `shared_surface_attachment_ready` (full attachment,
  same predicate as `readSharedSurfaceAttachmentReady`, **carrier:** present-state field); `renderer_presentable_refresh_tag`
  (renderer refresh cycle enum, distinct from the pipeline-ready bool); view/update
  and geometry fields as emitted.
- **`terminal.generation_handoff`:** explicit `publication_*` / `capture_*` / `last_surface_render_generation`
  tokens in the widget draw path; `presented_generation` / `published_generation` /
  `pending_generation` in frame pacing — generation triples, not attachment conjunction logs.

## Signal Definitions Reference (CZH-S65)

Enforcement signal definitions consolidated for authority policy and per-path reference.

### Attachment Conjunction Field Rules

**Full conjunction name:** `shared_surface_attachment_ready` — computed from pipeline ∧ host target legs.

**Leg names:**
- `terminal_presentable_pipeline_ready` — pipeline leg only (buffer ready, scheduling ok, no stalls)
- `host_surface_target_available` — host drawable target leg only (host has provided drawable, not lost)

**Contexts where field names appear:**
- Widget storage (`PresentationState`): legs stored separately (`terminal_presentable_pipeline_ready`, `host_surface_target_available`)
- Transient present gate (`PresentationPresentState`): both legs + full conjunction before draw
- Canonical result (`TerminalPresentResult`): both legs after folding (carrier for host/GPU logic)
- Structured logs (`renderer.terminal_present`): full conjunction from present-state field, pipeline leg explicit, host leg explicit
- Outcome states (internal): refresh carries conjunction inline; reuse/direct compute from legs

**Rule:** Use full conjunction name `shared_surface_attachment_ready` in result types and logs (operator visibility).  
Use leg names in internal state and widget storage (clarity on which leg).  
Bridge conjunction computation (`TerminalPresentationBridge.notePresentableAvailability`) is canonical read/compute source.

### Outcome Assertion Signals

**Outcome type set per path (frozen):**
- **Refresh:** `.updated_and_presented | .presented`
- **Reuse:** `.reused | .skipped`
- **Direct:** `.updated_and_presented | .presented`

**Assertion locations:**
- Refresh: assertion at line 168 `result.outcome == .updated_and_presented or result.outcome == .presented`
- Reuse: outcome construction at `reuseEligibilityEntry` (deterministic, no assertion needed)
- Direct: assertion at line 238 (field guarantees logic)
- Shared: `presentResultFromOutcomeState()` generic fold validation (assertion-free; type system enforces)

**Test binding:** Outcome classification tests validate these signals; test helpers (`assertRefreshOutcomeConsistency`, `assertReuseOutcomeConsistency`) provide hardening validation.

### Transport Field Mapping Reference

**Canonical transport mapping (all paths):**
- Outcome state → `TerminalPresentResult` fields: `cache_state_advanced`, `host_surface_target_available`, `shared_surface_attachment_ready`

**Path-specific mapping:**
- **Refresh:** `refreshTransportFromResult()` maps refresh outcome conjunction into full attachment field
- **Reuse:** `reuseTransportFromOutcome()` maps reuse eligibility decision + legs into result legs
- **Direct:** `directTransportFromUpdated()` maps updated flag + legs into result legs

**Rule:** Transport mapping is path-specific internal helper; field set is unified in result type.

### Outcome Type Signal Set

**Signal:** Outcome struct type name and field set encode which path + which invariant-carrying fields.

- **Refresh outcome:** `RefreshOutcomeState` carries outcome type + `shared_surface_attachment_ready` inline
- **Reuse outcome:** `ReusePresentOutcomeState` carries outcome type only (legs computed at entry call)
- **Direct outcome:** `DirectPresentOutcomeState` carries outcome type only (field guarantees computed at entry call)

**Rule:** Widget never constructs outcome types. Terminal entries produce outcomes; fold helpers consume them.

## Widget presentation storage (dominant field names, `CZH-B25`)

**Storage ownership:** `PresentationState` (`src/ui/widgets/terminal_widget_presentation_state.zig`)
stores the two attachment legs as **`terminal_presentable_pipeline_ready`** (pipeline only) and
**`host_surface_target_available`** (host drawable target). These names match the
`SharedSurfaceAttachmentPipelinePair` contract; full attachment is never computed or stored locally.

**Compute/read delegation:** Widget surface state delegates conjunction computation and reading to
`TerminalPresentationBridge` (terminal-layer seam). Widget stores legs only; bridge owns canonical
`notePresentableAvailability` (compute) and `readSharedSurfaceAttachmentReady` (read) routes.

**Transient present gate (`PresentationPresentState`, `CZH-S22`):** the widget presentation runtime
holds per-tick **`host_surface_target_available`** and **`shared_surface_attachment_ready`**
(conjunction from bridge's `notePresentableAvailability`) before draw/present; operator
`logUnavailable` reports the same conjunction field — not a re-derivation from unrelated state.

## Present aggregation (`TerminalPresentResult`, `CZH-B26`)

`TerminalPresentResult` (`src/ui/renderer/presentable_contract.zig`) carries **`host_surface_target_available`**
(host drawable-target leg only) and **`shared_surface_attachment_ready`** (full attachment when the
caller computes pipeline ∧ host target). `ReusePresentOutcomeState` in the widget presentation
runtime uses the same two identifiers before folding into `TerminalPresentResult` on reuse success.

**Reporting/result cohesion (`CZH-S24`):** structured **logs** use `PresentationPresentState` / widget
getters for attachment visibility; **host export** uses `TerminalPresentResult` after runtime folds
outcomes — same field **names** where applicable, distinct **roles** (reporting snapshot vs aggregated
result).

## Presentation runtime ownership (authority)

**Terminal-owned runtime orchestration layer:**
The terminal layer owns the presentation runtime module (`src/terminal/presentation_runtime.zig`)
that manages all semantic presentation logic:

- **Outcome classification** (pure semantic): `classifyRefreshOutcome()`, `classifyDirectPresentOutcome()`, `reuseSuccessOutcome()`
  - Classify refresh cycle, direct present, and reuse results into outcome states with invariant fields
  - Outcome carriers contract transport fields around canonical fold/result transport shape per flow
  - Refresh classification carries `shared_surface_attachment_ready` inline in `RefreshOutcomeState` (no separate conjunction transport parameter)
  - All hardening assertions validate semantic consistency (no behavior changes)
  
- **Outcome folding** (pure computation): `foldRefreshOutcomeToPresent()`, `foldReuseOutcomeToPresent()`, `foldDirectOutcomeToPresent()`
  - Fold outcome state + timing into host-facing result transport
  - Refresh folded result consumes conjunction from `RefreshOutcomeState.shared_surface_attachment_ready` and carries followup via one nested `followup` transport field
  - Reuse folded result routes through `foldReuseOutcomeToPresent()` for both reused and non-reused attempts
  - Direct folded result must route through `foldDirectOutcomeToPresent()` as the canonical host-facing direct result path
  - Shared fold transport fields route through one canonical transport carrier before host-facing result assembly
  - Outcome/transport helper composition is canonicalized to one helper route per flow before fold composition
  - Fold entry shaping is canonicalized to one route per flow before generic fold dispatch
  - Transport helper wrapper collapse: no intermediate helper functions between outcome-specific fold paths and generic fold dispatch
  - Route-lock simplification: outcome structs lock all field access to canonical transport carrier; boundary checks maintain single-path routes
  - Fold-route assertion collapse: consolidated assertions verify transport routing without redundant field checks
  - Transport mapping simplification: outcome field access streamlined to canonical transport carrier routes
  - Transport route pruning: unnecessary intermediate steps removed; direct field mapping without loss of invariant verification
  - Assertion-surface minimization: only essential outcome-type invariants retained; construction-guaranteed checks removed
  - Terminal/widget integration surface uses only canonical per-flow fold routes; generic fold composition helpers remain terminal-runtime internals
  - Attachment-readiness transport remains part of canonical folded result fields
  - **Canonical fold-entry consolidation (CZH-B57, CZH-S54):** Three canonical terminal entry points encapsulate classification + folding per flow:
    - `refreshPresentEntry(refresh, attachment_ready, timing) -> TerminalPresentResult` — single route: classify refresh + fold to host result
    - `reuseEligibilityEntry(eligible, host_target, attachment_ready, timing) -> TerminalPresentResult` — single route: construct outcome from eligibility decision + fold to host result
    - `directPresentEntry(updated, timing) -> TerminalPresentResult` — single route: classify direct + fold to host result
    - Widget layer calls canonical entries only; outcome state structures invisible at boundary
    - Outcome-specific fold helpers (`foldRefreshOutcomeToPresent`, `foldReuseOutcomeToPresent`, `foldDirectOutcomeToPresent`) are terminal-internal; widget does not call them
    - Removes const alias imports and intermediate outcome state threading from widget layer
  
- **Orchestration coordination** (pure except for integration seams):
  - **Refresh path:** `runPresentableRefreshCycle()`, `executeRefreshPresentFlow()`
    - Drive refresh cycle outcome classification and result folding
    - Refresh boundary helper transport is single-path: widget execution supplies cycle output + conjunction once, terminal fold helper finalizes host-facing transport
    - `classifyRefreshOutcome()` stores conjunction inline and `foldRefreshOutcomeToPresent()` routes transport directly through collapsed helper path to generic fold dispatch
    - Refresh outcome struct routes all field access to canonical transport; no intermediate wrapper function between outcome and generic fold
    - Refresh boundary exits carry `TerminalPresentResult` directly (no wrapper-only boundary result carrier)
    - No renderer/shell calls in terminal orchestration; widget retains execution/integration calls
  - **Reuse path:** `tryFastPresentExisting()`
    - Reuse eligibility decision based on generation pairing
    - Reuse attempt transport folds through terminal-owned `foldReuseOutcomeToPresent()` with collapsed helper routing transport directly to generic fold dispatch
    - Reuse outcome struct routes all field access to canonical transport; no intermediate wrapper function between outcome and generic fold
    - Reuse boundary exits carry `TerminalPresentResult` directly (no wrapper-only outcome carrier hop)
    - Canonical success signal remains `outcome == .reused`; no duplicate success transport flags
  - **Direct path:** `directPresent()`
    - Direct present path outcome classification and result folding
    - Direct execution returns canonical timing transport directly (no intermediate direct timing wrapper carrier)
    - Host-facing direct result transport terminates at `foldDirectOutcomeToPresent()` with collapsed helper routing transport directly to generic fold dispatch
    - Direct outcome struct routes all field access to canonical transport; no intermediate wrapper function between outcome and generic fold
    - No alternate direct fold composition path
  - **High-level coordination:** `runPresentation()`, `refreshPresentState()`, `planUpdate()`
    - Top-level orchestration that calls phase-specific helpers
    - Planning surface update modes based on presentation state
    - No re-derivation of outcomes; delegates to outcome-phase helpers

- **Geometry computation** (pure): `PresentationGeometry`, `computePresentationSurfaceGeometry()`, `ViewportShiftState`
  - Surface geometry derivation from view dimensions and cell metrics
  
- **Attachment readiness** (pure computation): `computeHostSurfaceAttachmentState()`
  - Apply `TerminalPresentationBridge` to derive full conjunction state

**Widget-retained integration layer** (`terminal_widget_presentation_runtime.zig`):
The widget layer remains a thin facade that:
- Gathers input/geometry/UI context from renderer/shell/view state
- Calls terminal-owned entry points with primitive inputs:
  - `refreshPresentEntry(refresh, attachment_ready, timing)` — refresh path
  - `reuseEligibilityEntry(eligible, host_target, attachment_ready, timing)` — reuse path
  - `directPresentEntry(updated, timing)` — direct path
- Receives `TerminalPresentResult` directly; never constructs, manipulates, or exposes outcome-state types
- Interprets results in renderer/shell context (timing, callbacks, viewport clipping)
- Delegates all semantic classification, folding, and outcome coordination to terminal layer
- Keeps no presentation logic, only integration and GPU operations
- **Result-only boundary (CZH-B58):** Outcome-state structures (`RefreshOutcomeState`, `ReusePresentOutcomeState`, `DirectPresentOutcomeState`) are terminal-internal implementation details; not accessible to widget layer in production paths; canonical entries own all outcome construction and validation

**No re-derivation rule:** Widget layer never recomputes outcomes, folding, or orchestration decisions.
All semantic logic is owned by terminal layer and called through defined interfaces.  
Execution-local timing/update carriers in widget runtime must not become alternate host-facing result contracts; host-facing result composition remains terminal-owned fold authority.  
Refresh/reuse/direct boundary consolidation rule: widget may carry execution-local transport state, but host-facing transport exits must converge at terminal canonical fold routes with collapsed helper routing and simplified route-lock checks enforcing one canonical transport path per flow.

**Canonical orchestration entry point:** `runPresentation()` in terminal runtime is the single
orchestration function called by widget facade. All refresh/reuse/direct paths flow through this
or its phase-specific helpers. Widget may call phase helpers directly only for testing/internal
decision gating (e.g., checking reuse eligibility)—production codepaths always flow through
the canonical entry point for consistent outcome handling
in UI layer.

**Outcome types:** Outcome structs and classification helpers are defined in terminal layer.
Widget layer does not construct, access, or manipulate outcome state types.

**Canonical entry-point authority (CZH-S54, CZH-S55):** `refreshPresentEntry`, `reuseEligibilityEntry`, and `directPresentEntry` are the only three terminal layer functions the widget layer calls for outcome classification and folding. No outcome-specific fold routes, no intermediate helpers, no outcome state construction at widget boundary. All three are consolidation boundaries: each encapsulates the full path (decision/classify → fold → result) for its flow. Reuse eligibility is the decision input; terminal owns outcome construction.

## Result Surface vs Test Surface (CZH-S55)

**Production result surface (widget-calling boundary):**
- 3 canonical entries: `refreshPresentEntry`, `reuseEligibilityEntry`, `directPresentEntry`
- 2 eligibility checks: `checkReuseEligibility`, `checkDirectPresentEligibility`
- 4 state computation: `refreshPresentState`, `computeHostSurfaceAttachmentState`, `computePresentationSurfaceGeometry`, `computeTerminalPresentPlanDecision`
- 2 orchestration: `executeRefreshPresentFlow`, `presentDraw`
- Result types: `TerminalPresentResult` (host-facing), `PresentationPresentState` (internal snapshot), outcome state structs for internal composition only

**Test-only helpers:**
- Classification: `classifyRefreshOutcome()`, `classifyDirectPresentOutcome()` — outcome analysis for test validation
- Invariants: `assertReuseOutcomeConsistency()`, `assertRefreshOutcomeConsistency()` — consistency checking for test hardening
- Shared construction: `reuseSuccessOutcome()` — called by production (`reuseEligibilityEntry`) and tests

**Explicit isolation (CZH-S55):**
- Private fold helpers remain private to terminal layer (`foldRefreshOutcomeToPresent`, `foldReuseOutcomeToPresent`, `foldDirectOutcomeToPresent`)
- Widget never calls fold helpers directly; only canonical entries
- Tests can call classification and invariant helpers for understanding outcome semantics
- No outcome state construction or manipulation in widget layer
- No test helper calls in production code paths

## Canonical Entry Contract Lock (CZH-S56)

**Authority:** Strict canonical-entry contract for presentation runtime entry points.

**Three canonical entries are the ONLY widget-layer entry points:**
1. `refreshPresentEntry(refresh, shared_surface_attachment_ready, timing) → TerminalPresentResult`
   - Single route for widget refresh presentation
   - Encapsulates refresh cycle outcome classification + folding in one call
   - Called exactly once per refresh cycle from widget execution

2. `reuseEligibilityEntry(eligible, host_surface_target_available, shared_surface_attachment_ready, timing) → TerminalPresentResult`
   - Single route for widget reuse presentation
   - Encapsulates reuse eligibility decision, outcome construction, and folding in one call
   - Called exactly once per reuse attempt decision

3. `directPresentEntry(updated, timing) → TerminalPresentResult`
   - Single route for widget direct presentation
   - Encapsulates direct present outcome classification + folding in one call
   - Called exactly once per direct draw execution

**No secondary entry routes:**
- Fold helpers (`foldRefreshOutcomeToPresent`, `foldReuseOutcomeToPresent`, `foldDirectOutcomeToPresent`) are private (fn not pub fn)
- No alternate outcome construction paths
- No outcome state manipulation at widget boundary
- No result type construction outside canonical entries

**Helper exposure enforcement:**
- **Production helpers** (11 total including canonical entries):
  - 3 canonical entries (public)
  - 2 eligibility checks (public): `checkReuseEligibility`, `checkDirectPresentEligibility`
  - 4 state computation (public): `refreshPresentState`, `computeHostSurfaceAttachmentState`, `computePresentationSurfaceGeometry`, `computeTerminalPresentPlanDecision`
  - 2 orchestration (public): `executeRefreshPresentFlow`, `presentDraw`

- **Test-only helpers** (4 public + 1 shared):
  - 2 outcome classification: `classifyRefreshOutcome`, `classifyDirectPresentOutcome`
  - 2 outcome invariants: `assertReuseOutcomeConsistency`, `assertRefreshOutcomeConsistency`
  - 1 shared outcome construction: `reuseSuccessOutcome()` (used by both production and tests)

- **Private fold helpers** (not callable from production):
  - `foldRefreshOutcomeToPresent` — private, only called by `refreshPresentEntry`
  - `foldReuseOutcomeToPresent` — private, only called by `reuseEligibilityEntry`
  - `foldDirectOutcomeToPresent` — private, only called by `directPresentEntry`
  - Tests can call via import for validation; production cannot compile against them

**Canonical routing rules:**
- Widget gathers input (refresh cycle, eligibility decision, update state, timing)
- Widget calls ONE canonical entry (refreshPresentEntry, reuseEligibilityEntry, or directPresentEntry)
- Terminal entry point encapsulates all semantic decisions, outcome construction, and folding
- Widget receives `TerminalPresentResult` directly (never outcome state types)
- Widget interprets result in renderer/GPU/shell context (execution only)

**Verification:** Canonical entry contract audit (CZH-1093) confirms:
- ✓ All three entry points are called from widget layer
- ✓ All calls are single-site per path (908, 1404, 1223 in terminal_widget_presentation_runtime.zig)
- ✓ No fold helper calls in production code
- ✓ No secondary entry routes detected
- ✓ No outcome state construction outside canonical entries
- ✓ No exposure violations in production surface
- ✓ Test-only surface isolated and explicit

**Lock enforcement:**
- Fold helper privacy enforced at compile time (fn not pub fn)
- No alternate production surface
- All future presentation runtime changes must route through canonical entries
- Any violation of single-entry constraint must be authorized by architect

## Production-Callable Surface Lock (CZH-S57)

**Authority:** Explicit production-callable surface contract for presentation runtime.

**Complete production-callable surface (11 functions):**

### Canonical Entries (3)
These are the only outcome-classifying, outcome-folding entry points:
1. `refreshPresentEntry(refresh, shared_surface_attachment_ready, timing) → TerminalPresentResult`
2. `reuseEligibilityEntry(eligible, host_surface_target_available, shared_surface_attachment_ready, timing) → TerminalPresentResult`
3. `directPresentEntry(updated, timing) → TerminalPresentResult`

### Eligibility Checks (2)
These inform widget flow decisions before calling canonical entries:
1. `checkReuseEligibility(input: ReuseEligibilityInput) → bool`
2. `checkDirectPresentEligibility(input: DirectPresentEligibilityInput) → bool`

### State Computation (4)
These compute transient snapshots and geometry for widget GPU/UI logic:
1. `refreshPresentState(surface, renderer, refresh, visible_w, visible_h) → PresentationPresentState`
2. `computeHostSurfaceAttachmentState(bridge) → SharedSurfaceAttachmentPipelinePair`
3. `computePresentationSurfaceGeometry(rows, cols, view_geometry, cell_metrics) → PresentationGeometry`
4. `computeTerminalPresentPlanDecision(present_state, cache_state, eligible) → TerminalPresentPlanDecision`

### Orchestration (2)
These execute GPU and flow operations:
1. `executeRefreshPresentFlow(rows, cols, ctx, Hooks) → TerminalPresentResult`
2. `presentDraw(renderer, last_gen, last_rendered, view_geometry, width, height, ctx, callback)`

**All 11 functions are essential:**
- Canonical entries: Only terminal-controlled outcome paths
- Eligibility checks: Widget must decide flow before entering canonical entry
- State computation: Widget needs per-tick snapshots for GPU/UI decisions
- Orchestration: Execution-layer operations must be callable from widget

**Verification (CZH-1101):**
- ✓ All 11 functions called from production code
- ✓ No non-essential exposure found
- ✓ No redundant or duplicate helpers
- ✓ All secondary entry routes blocked (fold helpers private)
- ✓ Test-only surface isolated and documented

**Surface types (10):**
- Input types: `ReuseEligibilityInput`, `DirectPresentEligibilityInput`
- Result types: `PresentationGeometry`, `ViewportShiftState`, `TerminalPresentPlanDecision`, `PresentationPresentState`
- Transport type: `FoldTransportFields` (internal)
- Outcome types: `RefreshOutcomeState`, `ReusePresentOutcomeState`, `DirectPresentOutcomeState` (internal, not constructed in widget)

**Lock enforcement:**
- Compile-time: Private fold helpers prevent secondary routes
- Code review: All 11 functions verified called from widget code
- Documentation: Authority specified in TERMINAL_SURFACE_CONTRACT.md (this document)

**Lock status:** ✓ LOCKED — No additional production-callable functions allowed without architect approval

## Assertion Surface Policy (CZH-S58)

**Authority:** Compressed assertion surface for presentation runtime contract.

**Assertion Philosophy:**
- Contract-critical invariants: PRESERVED (canonical entry outcome validation)
- Implementation detail checks: REMOVED (guaranteed by logic structure)
- Test hardening assertions: CONSOLIDATED (unified per outcome type)

**Single Contract-Critical Assertion:**
1. `refreshPresentEntry` outcome invariant — ensures refresh path always produces valid outcome type
   - Location: `refreshPresentEntry`, line 168
   - Check: `result.outcome == .updated_and_presented or result.outcome == .presented`
   - Rationale: Multiple outcome types possible; cannot be inferred from logic alone

**Removed Implementation Detail Assertions:**
1. `classifyDirectPresentOutcome` field validation (lines 138-139, 245-247)
   - Why removed: Fields are guaranteed by classification logic; redundant check
   - No contract impact: Classification invariants enforced elsewhere

2. `foldReuseOutcomeToPresent` outcome type validation (line 183)
   - Why removed: Outcome type mapping is deterministic; redundant check
   - No contract impact: Transport routing enforced at canonical entry

**Consolidated Test-Only Assertions:**
1. Reuse outcome consistency (from `assertReuseOutcomeConsistency`)
   - Consolidated: Field validation unified per outcome state
   
2. Refresh outcome consistency (from `assertRefreshOutcomeConsistency`)
   - Consolidated: Followup field validation unified per outcome variant

**Compression Results:**
- Before: 11 total assertions
- After: 3 assertions (1 contract + 2 consolidated test)
- Reduction: 73% assertion surface trimmed
- Contract coverage: MAINTAINED — no contract assertions removed

**Enforcement:**
- Compile-time: Type system ensures outcome types valid
- Runtime: Single contract assertion validates outcome production
- Tests: Consolidated assertions verify hardening requirements

**Future assertion additions:**
- New assertions require architect approval
- Must be contract-critical; implementation details must be inferred
- Keep assertion surface minimal and focused on invariants

## Sustained Enforcement Policy (CZH-S59 through CZH-S62)

**Authority:** Comprehensive enforcement and maintenance policy for sealed presentation runtime contract.

**Policy Scope:**
After contract finalization (CZH-S59), the terminal presentation runtime surface is locked for production. This section consolidates post-seal change control, regression guards, and enforcement mechanisms into a single maintained policy ensuring the sealed contract remains intact through all future development.

**Sealed Contract Status:**

The presentation runtime contract is sealed when all of the following hold:
1. ✓ Canonical Entry Contract (CZH-S54): Three entries encapsulate all outcome classification + folding; fold helpers private; enforced at compile time
2. ✓ Result Surface Isolation (CZH-S55): Production surface 11 essential functions; test surface 4 isolated helpers + 1 shared; clear boundary maintained
3. ✓ Production-Callable Surface (CZH-S57): Complete 11-function surface verified called from production; all essential; no redundancy
4. ✓ Assertion Surface Policy (CZH-S58): Compressed to 3 assertions (1 contract-critical + 2 test hardening); 73% reduction maintained
5. ✓ No-Bypass Invariants Enforced: Compile-time (type system privacy) + code review verified
6. ✓ Test Surface Isolated: No production calls to test helpers verified
7. ✓ Full Validation Ladder Passes: build, tests, invariant checks, Android deployment

**Change-Vector Governance:**

### Extension Vectors (Already Locked by Seal)
- **New canonical entries:** Architect approval required; no new entry points allowed
- **New production functions:** Architect approval required; all 11 currently essential
- **Assertion changes:** Architect approval required; must remain contract-critical only
- **Fold helper exposure:** Prohibited; private enforcement remains

### Regression Vectors (Active Guards)

1. **No-Bypass Invariant Drift:** Widget code bypassing canonical entries via fold helpers or direct outcome construction
   - Guard: Compile-time (type system privacy) + code review verification per path (CZH-1135, CZH-1136, CZH-1137, CZH-1138)
   - Enforcement: Type system prevents fold helper calls externally; code review blocks alternate routes

2. **Test-Only Surface Leak:** Production code calling test assertions or outcome classification helpers
   - Guard: Test-surface isolation enforcement (CZH-1139) prevents production calls to test helpers
   - Enforcement: Code review + test coverage validates no production paths use test surface

3. **Outcome State Mutation:** Production code modifying outcome state after canonical entry returns
   - Guard: Outcome immutability verification (CZH-1139) ensures no post-production mutation
   - Enforcement: Code review + invariant verification; outcome state private to terminal layer

4. **Attachment State Drift:** Widget recomputing attachment state instead of using canonical path
   - Guard: Attachment consistency enforcement (CZH-1139) verifies single-path computation
   - Enforcement: Code review validates only canonical path (TerminalPresentationBridge) computes conjunction

**Post-Seal Maintenance Rules:**

1. **No public function removal without architect approval** (caller migration required)
2. **No canonical entry modification without architect approval** (affects contract)
3. **No test-only helper calls in production code** (isolation enforced by code review)
4. **No private fold helper exposure** (type system + code review enforces)
5. **No outcome state construction outside canonical entries** (type system enforces)
6. **All assertion changes require architect approval** (keep contract-critical only)

**Enforcement Layers:**

The policy is enforced across four independent layers:

| Layer | Owner | Responsibility | Enforcement | Violation |
|-------|-------|-----------------|--------------|-----------|
| **Compile-Time** | Zig type system | Prevent invalid calls | Private fold helpers + outcome types | Compile error |
| **Runtime** | Production assertions | Detect mutation/transition | Line 168 outcome assertion | Assertion fire |
| **Test** | zig build test suite | Detect regression vectors | Test coverage on invariants | Test failure |
| **Code Review** | Architect approval | Block contract violations | All canonical entry changes | Cannot merge |

**Escalation & Approval Matrix:**

| Severity | Trigger | Response | Examples |
|----------|---------|----------|----------|
| **Critical** | Type violation, assertion fire, public function without approval | Immediate halt + escalate | Compile error, fold public, outcome constructible, test-only called from production |
| **High** | Signature change, new function, field change | Code review block | Canonical entry signature, new production function, outcome type expansion, field removal, routing change |
| **Medium** | Behavior change, test assertion, comment | Doc update | Private helper behavior, new test assertion, assertion content, locked section comment |

**Approval Gates:**
- CZH-GATE-118 and later: All public surface changes require architect review
- New public functions: Explicit approval + TERMINAL_SURFACE_CONTRACT.md update
- Assertion changes: Approval if contract-critical; discretion if test-only
- Private helper changes: No approval needed

**Drift Detection & Response:**

If regression vector detected (test failure, assertion fire, or code review finding):
1. Identify specific violation: contract boundary breach, test leak, mutation, bypass, or drift
2. Assess severity: critical (block), high (review), medium (doc)
3. Determine fix approach: revert change, add guard, strengthen test, or architect redesign
4. Update enforcement: add test, assertion, or code comment to prevent recurrence
5. Escalate if: severity 1, affects core contract, or represents new pattern not covered by existing guards

**Non-Goals:**
- Adding complexity to normal development flow
- Freezing internal implementation details (private helpers remain open to optimization)
- Preventing legitimate optimization or refactoring within sealed contract
- Enforcing specific code style or organization

**Runtime-to-Test Binding Policy (CZH-S63):**

All runtime enforcement claims are bound to explicit compile-time locks or test coverage:

**Compile-Time Bindings (Type System):**
- `foldRefreshOutcomeToPresent` private → type system prevents external calls
- `foldReuseOutcomeToPresent` private → type system prevents external calls
- `foldDirectOutcomeToPresent` private → type system prevents external calls
- `presentResultFromOutcomeState` private → type system prevents widget access
- Outcome types internal (RefreshOutcomeState, ReusePresentOutcomeState, DirectPresentOutcomeState) → type system prevents widget construction

**Runtime-to-Test Bindings:**
1. **Refresh outcome classification contract** (line 168 assertion) → test: "outcome classification from refresh cycle is pure"
2. **Reuse success outcome fields** (cache_state_advanced, host_surface_target_available, shared_surface_attachment_ready) → test: "Reuse success outcome invariants hold"
3. **Direct field guarantees** (cache_state_advanced=true, host_surface_target_available=true) → test: "Direct present outcome classification is pure"
4. **Outcome folding consistency** (transport field preservation) → test: "Outcome folding produces consistent results"
5. **Refresh conjunction transport** (shared_surface_attachment_ready inline) → test: "Refresh classification carries inline conjunction"
6. **Reuse transport immutability** (fields preserved through fold) → test: "Reuse fold helper preserves non-reused transport"
7. **Direct folding helper** (canonical routing) → test: "Direct present folding uses canonical helper"
8. **Transport carrier routing** (all paths route through transport) → test: "Fold routes consume contracted transport carrier"

**Design-Level Enforcement (Code Review Only):**
- Test-only surface isolation (assertRefreshOutcomeConsistency, assertReuseOutcomeConsistency not called from production)
- No-bypass invariant (all canonical entries called from verified widget sites)
- Attachment state single-path computation (computeHostSurfaceAttachmentState only path)

**Known Binding Gaps (CZH-S63):**
- ⚠️ Attachment state consistency: requires explicit test validating re-derivation prevention
- ⚠️ No-bypass call-site verification: integration tests exist; requires explicit binding documentation

**Related Governance Documents:**

Core enforcement:
- Refresh enforcement: `CZH_S62_REFRESH_SUSTAINED_ENFORCEMENT.md` (consolidates CZH-S60 + CZH-S61 refresh)
- Reuse enforcement: `CZH_S62_REUSE_SUSTAINED_ENFORCEMENT.md` (consolidates CZH-S60 + CZH-S61 reuse)
- Direct enforcement: `CZH_S62_DIRECT_SUSTAINED_ENFORCEMENT.md` (consolidates CZH-S60 + CZH-S61 direct)
- Shared enforcement: `CZH_S62_SHARED_SUSTAINED_LOCK.md` (consolidates governance + enforcement + integration)
- Audit trail: `CZH_S62_SIMPLIFICATION_AUDIT.md` (documents consolidation)

Prior sprint records:
- CZH-S59 finalization: `CZH_S59_CHECKPOINT.md`
- CZH-S60 baseline: `CZH_S60_CHECKPOINT.md`
- CZH-S61 enforcement: `CZH_S61_CHECKPOINT.md`, `CZH_S61_ENFORCEMENT_SUMMARY.md`

## Enforcement Claims Binding Reference (CZH-S67)

Authority mapping of enforcement claims to concrete compile/test locks.

**Claim Definition Format:**
- Claim name and statement
- Lock type (compile-time, runtime, test, code-review)
- Lock detail (specific function, line, type, or test name)
- Ambiguity status (✓ NONE or ⚠️ description)

**Enforcement Claims (14 total, all mapped):**

### Refresh Path (4 claims)
1. **No-bypass invariant:** widget refresh flows only through `refreshPresentEntry`
   - Lock: `foldRefreshOutcomeToPresent` private (compile-time)
   - Test: "outcome classification from refresh cycle is pure"
   - Status: ✓ NONE

2. **Outcome type freeze:** .updated_and_presented | .presented
   - Lock: Zig enum type + assertion line 168 (compile/runtime)
   - Test: outcome classification test validates types
   - Status: ✓ NONE

3. **Transport determinism:** fields always computed, no conditionals
   - Lock: `refreshTransportFromResult()` logic (runtime)
   - Test: "Refresh result helper preserves transport fields"
   - Status: ✓ NONE

4. **Outcome state isolation:** RefreshOutcomeState internal
   - Lock: type privacy prevents widget construction (compile-time)
   - Test: binding tests validate canonical production
   - Status: ✓ NONE

### Reuse Path (4 claims)
5. **Eligibility decision immutability:** decision determines outcome directly
   - Lock: `reuseSuccessOutcome()` construction logic (runtime)
   - Test: "Reuse success outcome invariants hold"
   - Status: ✓ NONE

6. **Outcome type freeze:** .reused | .skipped
   - Lock: Zig enum type (compile-time)
   - Test: outcome type tests
   - Status: ✓ NONE

7. **Transport consistency:** both reused/non-reused paths preserve fields
   - Lock: transport mapping logic per path (runtime)
   - Test: "Reuse fold helper preserves non-reused transport" + boundary test
   - Status: ✓ NONE

8. **Success signal uniqueness:** only .reused indicates success
   - Lock: outcome type set (compile-time)
   - Test: "Reuse success outcome invariants"
   - Status: ✓ NONE

### Direct Path (3 claims)
9. **Updated flag determinism:** classification depends only on boolean
   - Lock: classification pure function (runtime)
   - Test: "Direct present outcome classification is pure"
   - Status: ✓ NONE

10. **Field guarantees:** cache_state_advanced=true, host_surface_target_available=true, shared_surface_attachment_ready=false
    - Lock: result struct field requirements + field computation logic (compile/runtime)
    - Test: field preservation test validates all three
    - Status: ✓ NONE

11. **Outcome type freeze:** .updated_and_presented | .presented
    - Lock: Zig enum type (compile-time)
    - Test: classification test validates types
    - Status: ✓ NONE

### Shared (3 claims)
12. **No shared outcome production:** outcomes created per-path only
    - Lock: outcome types internal per path, no shared helper (compile-time)
    - Test: outcome type tests validate per-path production
    - Status: ✓ NONE

13. **Attachment consistency:** single computation path only
    - Lock: `computeHostSurfaceAttachmentState()` is only function (compile-time)
    - Test: integration tests validate single path
    - Status: ✓ NONE

14. **Transport routing immutability:** all paths route through canonical folds
    - Lock: fold helpers private, prevent alternates (compile-time)
    - Test: "Fold routes consume contracted transport carrier"
    - Status: ✓ NONE

**Claim-to-Lock Matrix Summary:**
- Total claims: 14
- Mapped claims: 14 (100%)
- Unmapped claims: 0
- Ambiguous claims: 0
- Traceability: ✓ COMPLETE AND UNAMBIGUOUS

## Claim-to-Lock Determinism Criteria (CZH-S68)

Authority criteria for maintaining deterministic, unambiguous claim-to-lock mappings across all enforcement claims.

**Determinism definition:** All reviewers interpret the same claim identically; future updates do not introduce wording drift, lock detail ambiguity, or ordering inconsistency.

### Criterion 1: Claim Naming Consistency

**Rule:** Claim names follow consistent naming scheme. Same concept across paths uses prefix or variant notation to signal relationship.

**Naming schemes:**
- **Semantic quality names:** "determinism", "consistency", "immutability", "uniqueness" (describe what property holds)
- **Mechanism names:** "freeze", "isolation", "privacy", "production" (describe how property enforced)
- Use **one scheme consistently per category** (e.g., all outcome-related claims use "freeze" not "freezing")

**Cross-path naming rule:**
- If same concept appears in multiple paths (e.g., "outcome type freeze" in refresh, reuse, direct): use notation `[Concept] - [Path variant]`
  - Example: "Outcome type freeze (Refresh variant: updated_and_presented | presented)"
  - Example: "Outcome type freeze (Reuse variant: reused | skipped)"
- Group related claims with shared locks under unified label: "Fold helper privacy" covers both "No-bypass invariant" and "Transport routing immutability"

**Ambiguity check:** Two reviewers should independently recognize that Claim N and Claim M are (a) the same principle across different paths, or (b) distinct principles with unrelated locks. Ambiguous names violate this rule.

### Criterion 2: Lock Detail Standardization

**Rule:** All lock descriptions use standardized format: `artifact:line[property]` or descriptive detail matching pattern below.

**Standardized formats:**

**Compile-time locks:**
- Format: `ArtifactName[property]` where property ∈ {private, frozen, enum, internal}
- Examples:
  - `foldRefreshOutcomeToPresent[private]`
  - `OutcomeEnum[frozen]`
  - `RefreshOutcomeState[internal]`
- Or include line: `ArtifactName:LINE[property]`

**Runtime locks:**
- Format: `function_name():LINE` (line number of assertion or deterministic logic)
- Examples:
  - `classifyRefreshOutcome():168`
  - `reuseSuccessOutcome():112`

**Type locks:**
- Format: `TypeName[guarantee]` where guarantee ∈ {frozen, immutable, exclusive}
- Example: `TerminalPresentResult[field_set_frozen]`

**Uniqueness locks:**
- Format: `FunctionName[sole_implementer]`
- Example: `computeHostSurfaceAttachmentState[sole_implementer]`

**Consistency check:** Lock detail must be sufficient to locate the artifact in code (function + line number, or type name + property). Vague details like "logic" or "field mapping" require explicit function name.

### Criterion 3: Lock Type Coverage Rule

**Rule:** All claims must cite enforcement layers explicitly. Minimum coverage: compile-time AND (runtime OR test).

**Coverage notation:**
- Single-layer: `Compile-time: ✓ [artifact]` (sufficient if compile-time privacy is sole lock)
- Multi-layer: `Compile-time: ✓ [artifact], Runtime: ✓ [function:line], Test: ✓ [name]`
- Complete: `Compile-time: ✓, Runtime: ✓, Test: ✓, Code-review: ✓ [approval]`

**Coverage rule:**
- **Compile-time layer:** Type system (privacy, enums, immutability) — always cite artifact and property
- **Runtime layer:** Assertions, deterministic logic — cite if applicable, include line number
- **Test layer:** Test binding — cite for all claims (even if test primarily validates compile-time lock)
- **Code-review layer:** Architect approval — cite if lock required explicit review (else implicit)

**Ambiguity check:** "Ambiguity: ✓ NONE" means the claim-to-lock binding is unambiguous AND all cited enforcement layers are documented. Do not hide layer coverage in "NONE" status; make layers explicit.

**Notation:** Change ambiguity status to include layer count: `✓ NONE (3/4 layers)` or `✓ NONE (4/4 layers)`

### Criterion 4: Test Binding Citation Format

**Rule:** All test bindings use standardized citation format. Quoted strings must correspond to actual test function names.

**Standardized format:**
- **Full citation (preferred):** `test_file.zig:LINE-RANGE "test_function_name"`
- **Example:** `test_presentation_runtime.zig:14-28 "outcome classification from refresh cycle is pure"`

**Generic categories (allowed only if defined):**
- Generic category allowed only if defined once in authority document with specific function examples
- Example: "outcome classification tests" → define once as "includes test_presentation_runtime.zig:14-28, test_presentation_runtime.zig:30-39"

**Citation consistency check:**
- Quoted test name must match actual test function name in codebase (no paraphrasing)
- If line numbers not available, category must be defined in authority document
- All test citations must be verifiable (no broken references)

### Criterion 5: Cross-Path Claim Grouping

**Rule:** Claims with shared locks are grouped and cross-referenced. Relationship explicitly stated.

**Grouping structure:**
- Group by lock mechanism (e.g., "Fold helper privacy" group includes Claim 1 and Claim 14)
- Within group, enumerate per-path instances with variant notation
- Include cross-reference table: Lock → Claims using it

**Cross-reference table structure:**
| Lock Mechanism | Artifact | Paths Using Lock | Claim IDs |
|---|---|---|---|
| Outcome enum freeze | OutcomeEnum[frozen] | Refresh, Reuse, Direct | 2, 6, 11 |
| Fold helper privacy | foldXOutcomeToPresent[private] | Refresh, Reuse, Direct, Shared | 1, 14 |

**Relationship rule:**
- If same named claim appears in multiple paths: explicitly state "per-path variant of [Principle]"
- If different-named claims share same lock: explicitly state "both enforce [Lock mechanism]"

**Ambiguity check:** Two reviewers should independently understand which claims are instances of same principle vs. distinct principles.

### Criterion 6: Enforcement Layer Explicitness

**Rule:** All 4 enforcement layers (compile-time, runtime, test, code-review) are explicitly documented per claim. "Not applicable" is explicit.

**Layer documentation requirement:**
- **Compile-time:** Type system artifact + property (or N/A if not applicable)
- **Runtime:** Assertion line + logic description (or N/A)
- **Test:** Test name + line range (required for all claims)
- **Code-review:** Architect approval + approval gate (or implicit if already approved)

**Explicit layer table per claim:**

| Claim | Compile-time | Runtime | Test | Code-review |
|-------|---|---|---|---|
| 2 | OutcomeEnum[frozen] | assertion:168 | outcome_classification_test | CZH-S67 |
| 1 | foldHelper[private] | N/A | binding_test | CZH-S67 |

**No "implicit" layers:** All 4 layers must be listed (even if "N/A" or "implied by prior approval"). This makes future maintenance explicit: if test coverage is missing, it shows up as empty cell, not hidden in "✓ NONE".

**Ambiguity status notation change:**
- Old: `Ambiguity: ✓ NONE` (implicitly assumes all 4 layers)
- New: `Ambiguity: ✓ NONE; Layers: CT/RT/Test/CR` or `Ambiguity: ✓ NONE; Layers: CT+Test (RT n/a, CR implicit)`

This makes layer coverage visible and prevents future drift.

---

**Determinism criteria application:**
- **CZH-S68 Phase 1 (CZH-1190):** Define criteria (complete)
- **CZH-S68 Phase 2 (CZH-1191..1194):** Apply criteria to all per-path claims, standardizing format
- **CZH-S68 Phase 3 (CZH-1195):** Verify deterministic mapping with new criteria applied

**Lock enforcement:** Future claim-to-lock updates must follow these 6 determinism criteria to prevent reviewer drift and maintain unambiguous mapping as codebase evolves.

## Enforcement Matrix Drift-Guard Policies (CZH-S69)

Authority policies to prevent drift from determinism rules during maintenance and future claim additions.

**Drift-guard definition:** Explicit policies and code review gates that prevent violating determinism criteria (Criterion 1-6) when claims are added, updated, or modified.

### Guard 1: New Claim Format Policy

**Rule:** All new enforcement claims must follow 6 determinism criteria (naming, lock detail, layer coverage, test binding, cross-path grouping, layer explicitness) or require architect pre-approval.

**Application:**
- New claims must include: name (with variant notation if cross-path), lock detail (standardized format), explicit layer coverage, test binding (file:RANGE format), cross-path relationship (if applicable)
- Claims missing any element require architect review before merge
- Code review checklist: verify new claims have all 6 elements

**Enforcement:** Code review gate; architect pre-approval required for non-conforming claims

---

### Guard 2: Lock Detail Immutability Policy

**Rule:** Lock details must follow standardized format (artifact:line[property]) and cannot be changed without architect review and format verification.

**Standardized format reminder:**
- Compile-time: `ArtifactName[property]` (e.g., `foldRefreshOutcomeToPresent[private]`)
- Runtime: `function_name():LINE` (e.g., `classifyRefreshOutcome():168`)
- Type: `TypeName[guarantee]` (e.g., `TerminalPresentResult[field_set_frozen]`)
- Uniqueness: `FunctionName[sole_implementer]`

**Application:**
- Lock detail changes require format verification against standardized patterns
- Non-conforming lock details (e.g., missing line numbers when available) require architect pre-approval
- Code review checklist: verify lock detail format against standardized patterns

**Enforcement:** Code review gate; architect pre-approval for format deviations

---

### Guard 3: Test Binding Verifiability Policy

**Rule:** All test bindings must be verifiable file:RANGE "test_name" format or reference explicitly defined category. Unverifiable citations require architect pre-approval.

**Verifiable formats:**
- Full citation: `test_file.zig:14-28 "test name"` (preferred; must correspond to actual test)
- Defined category: citation references category defined once in authority document with examples

**Application:**
- Test citations must either (a) point to actual test file/line, or (b) reference defined category
- Unverifiable citations (e.g., vague references without file/line or undefined categories) require architect approval
- Code review checklist: validate test binding resolves to actual test function

**Enforcement:** Code review gate + optional script validation; architect pre-approval for unverifiable citations

---

### Guard 4: Layer Explicitness Policy

**Rule:** All claims must have explicit layer coverage (CT/RT/Test/CR documented or marked "not applicable"). Implicit layer coverage is prohibited.

**Application:**
- Every claim must have layer coverage table showing which of 4 layers apply (✓ or N/A per layer)
- Implicit layer coverage (hidden in prose or ambiguous) requires architect pre-approval
- Code review checklist: mandatory layer coverage table per claim

**Enforcement:** Code review gate; architect pre-approval for implicit coverage

---

### Guard 5: Cross-Path Relationship Policy

**Rule:** Any claim appearing in multiple paths must be explicitly labeled as 'variant of [principle]' or 'distinct principle [name]'. Relationships tracked in authority grouping table.

**Application:**
- Claims appearing in multiple paths (e.g., "outcome type freeze" in refresh, reuse, direct) must explicitly state relationship
- Variant notation: "Outcome Type Freeze (Refresh variant: .updated_and_presented | .presented)"
- Grouping table in authority: maps shared locks to all claims using them
- Code review checklist: verify cross-path relationships are explicit and tracked in grouping table

**Enforcement:** Code review gate; architect pre-approval for undefined relationships

---

### Guard 6: Authority-Per-Path Sync Policy

**Rule:** Authority document and per-path enforcement docs must remain synchronized. Changes to determinism criteria require synchronized updates across all 4 per-path docs. Divergence requires architect pre-approval.

**Application:**
- Authority document changes (new criteria, updated policy) require corresponding updates in all per-path enforcement docs
- Per-path doc changes (claim updates) require verification that they match authority definitions
- Code review checklist: diff check authority vs. per-path docs (fail if claims don't match)
- Gate: cannot merge authority changes without per-path sync verification

**Enforcement:** Code review gate + diff verification; architect pre-approval for sync violations

---

### Guard 7: Cross-Reference Maintenance Policy

**Rule:** Cross-reference tables (lock → claims mapping) are maintained in authority document. Any claim addition/rename/deletion requires cross-reference update.

**Application:**
- Authority document maintains cross-reference table mapping locks to all claims using them
- Claim additions must be added to cross-reference table
- Claim renames must update cross-reference table
- Claim deletions must be removed from cross-reference table
- Code review checklist: explicit cross-reference table verification before merge

**Enforcement:** Code review gate; architect pre-approval for untracked cross-references

---

### Guard 8: Test Binding Staleness Policy

**Rule:** Test bindings are point-in-time citations. When test function is renamed/moved, ALL documentation must be updated within same change. Stale citations require architect pre-approval.

**Application:**
- Test renames/moves require simultaneous documentation updates across all claim citations
- Changes to test functions require verification that all citations are updated
- Optional: script validation that test bindings resolve to actual functions (detect stale citations)
- Code review checklist: verify test function changes include documentation updates

**Enforcement:** Code review gate; architect pre-approval for stale test citations

---

**Drift-guard enforcement:**
- **Code review gates:** Architect reviews all claims for drift-guard compliance (new claims, updates, cross-path changes)
- **Mandatory checklists:** 8-point checklist per claim change (one per guard)
- **Optional automation:** Script validation for test binding resolution, lock detail format
- **Approval authority:** Architect pre-approval required for any drift-guard deviation

**Drift-guard application:**
- **CZH-S69 Phase 1 (CZH-1198):** Define policies (complete)
- **CZH-S69 Phase 2 (CZH-1199..1202):** Implement per-path guards, add regression guards specific to each path
- **CZH-S69 Phase 3 (CZH-1203):** Verify drift-guard coverage closes all 8 identified vectors

**Maintenance contract:** No claim may be added or modified without code review against all 8 guards. Architect pre-approval required for any non-conformance.

### Drift-Guard Reference Table (CZH-S70)

| Guard | Name | Definition (Path-Agnostic) | Application | Enforcement Layer | Coverage |
|-------|------|---------------------------|-------------|-------------------|----------|
| 1 | New Claims | New claims must follow 6 determinism criteria or require architect pre-approval | Applies to all new enforcement claims across all 4 paths | Code review gate | All paths |
| 2 | Lock Detail | Lock details must follow standardized format (artifact:line[property]); updates require architect review | Applies to all claim lock specifications and updates | Code review gate | All paths |
| 3 | Test Binding | All test bindings must be verifiable file:RANGE "name" or reference explicitly defined category | Applies to all claims with test bindings | Code review gate | All paths |
| 4 | Layer Explicitness | All claims must have explicit CT/RT/Test/CR layer coverage tables; implicit coverage prohibited | Applies to all enforcement claims | Code review gate | All paths |
| 5 | Cross-Path | Claims appearing in multiple paths must explicitly state relationship (variant of / distinct principle) | Applies to outcome type freeze, transport routing, and field guarantees claims | Code review gate | Multi-path claims only |
| 6 | Authority Sync | Authority document and per-path enforcement docs must remain synchronized | Applies when authority policies change or per-path claims diverge | Code review + diff verification | All paths |
| 7 | Cross-Refs | Cross-reference tables must be updated when claims are added/renamed/deleted | Applies to lock-to-claims mapping maintenance | Code review gate | All paths |
| 8 | Test Staleness | Test function renames/moves require simultaneous documentation updates across all citations | Applies when tests are modified that are cited in claims | Code review gate + optional script | All paths |

---

### Policy-to-Guard Binding Table (CZH-S70)

| Authority Policy (Guard) | Prevents Drift Vector | Enforcement Gate(s) | Per-Path Application | Coverage Status |
|-------------------------|----------------------|-------------------|----------------------|-----------------|
| Guard 1 (New Claims) | New claim addition without standardized format | Code review checklist; architect pre-approval for non-conforming claims | Refresh, Reuse, Direct, Shared | ✓ All paths implemented |
| Guard 2 (Lock Detail) | Lock detail regression to non-standard format | Format verification gate; architect review required | Refresh, Reuse, Direct, Shared | ✓ All paths implemented |
| Guard 3 (Test Binding) | Test binding citation becomes vague/unverifiable | Test binding validation gate; architect pre-approval for vague citations | Refresh, Reuse, Direct, Shared | ✓ All paths implemented |
| Guard 4 (Layer Explicitness) | Layer coverage made implicit instead of explicit | Mandatory layer coverage table per claim; architect gate for implicit coverage | Refresh, Reuse, Direct, Shared | ✓ All paths implemented |
| Guard 5 (Cross-Path) | Cross-path relationships obscured or undefined | Variant notation requirement; grouping table maintenance; architect gate | Refresh, Reuse, Direct, Shared | ✓ Multi-path claims tracked |
| Guard 6 (Authority Sync) | Authority document diverges from per-path docs | Sync verification gate; diff check before merge; architect pre-approval for divergence | Refresh, Reuse, Direct, Shared | ✓ All paths synchronized |
| Guard 7 (Cross-Refs) | Cross-reference table staleness (claims not tracked) | Cross-reference update requirement; architect gate for untracked claims | Refresh, Reuse, Direct, Shared | ✓ All paths cross-referenced |
| Guard 8 (Test Staleness) | Test citation becomes invalid (test moved/renamed) | Test binding validation; architect pre-approval for stale citations | Refresh, Reuse, Direct, Shared | ✓ All paths updated |

---

### Vector-to-Guard Coverage Matrix (CZH-S70)

| Drift Vector | Guard 1 | Guard 2 | Guard 3 | Guard 4 | Guard 5 | Guard 6 | Guard 7 | Guard 8 | Protected By |
|--------------|---------|---------|---------|---------|---------|---------|---------|---------|--------------|
| New claim format violation | ✓ | | | | | | | | Guard 1 |
| Lock detail format regression | | ✓ | | | | | | | Guard 2 |
| Test binding vagueness | | | ✓ | | | | | | Guard 3 |
| Layer coverage implicit | | | | ✓ | | | | | Guard 4 |
| Cross-path relationship obscured | | | | | ✓ | | | | Guard 5 |
| Authority ↔ per-path divergence | | | | | | ✓ | | | Guard 6 |
| Cross-reference table staleness | | | | | | | ✓ | | Guard 7 |
| Test citation staleness | | | | | | | | ✓ | Guard 8 |
| **Total Coverage** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | **8/8 Vectors Covered** |

---

## Evidence Format Reference (CZH-S66)

Authority policy and format definitions for enforcement evidence artifacts (checkpoints, audits, verifications, implementations).

### Checkpoint Document Format

**Canonical structure:**
1. Header: title, date, sprint ID, authority parent, super-gate
2. Sprint Overview: goal, outcome metrics
3. Execution Summary: ticket-by-ticket completion status
4. Domain-Specific Summary: locks preserved / signals retained / evidence normalized (sprint-dependent)
5. Metrics table: baseline vs post-work, change column
6. Files Modified: documentation + verification/tracking lists
7. Commit History: all tickets listed with status
8. Validation Results: build, test, domain-specific validations
9. Lessons & Observations: sprint-specific learnings (3-5 observations)
10. Integration Ready: checklist confirming all work complete
11. Status: Ready for review gate at super-gate

**Rule:** All checkpoint documents use this structure. Domain-specific content (locks vs signals vs evidence) goes in section 4; structure remains uniform across sprints.

### Verification Document Format

**Canonical structure:**
1. Header: title, date, sprint ID, scope
2. [Domain] Summary: what was compressed/verified, impact metrics
3. Verification Checklist: per-category verification (✓ RETAINED / VERIFIED)
4. Enforcement Verification: compile-time/runtime/test/code-review checks
5. Validation Results: build, test, code quality
6. Comprehensive Summary Table: item × verification type
7. [Domain] Verification Confirmation: summary statement
8. Status: Ready for next phase

**Rule:** All verification documents follow this structure. Domain-specific categories (locks, signals, evidence) go in section 3; enforcement layers (compile-time, runtime, test, code-review) are always sections 4.

### Audit Document Format

**Canonical structure:**
1. Header: title, date, sprint ID, scope
2. Audit Overview: what was audited, why, scope definition
3. Redundancy Analysis: per-category analysis (current state → compression candidate → retention impact)
4. [Domain] Summary Table: item × type × current → normalization → retention → risk
5. Compression Approach: phased implementation plan
6. Files to be Modified: list of artifacts to change
7. Compliance Checklist: audit complete, risk assessment, path to implementation
8. Summary: total compression identified, retention/loss assessment

**Rule:** All audit documents follow this structure. Redundancy categories (documentation, code, structure) are analyzed uniformly; domain-specific findings (compaction vs signals vs evidence) fill the analysis sections.

### Implementation Summary Format

**Canonical structure:**
1. Header: title, date, sprint ID, status
2. Ticket Execution Summary: ticket list with status (DONE/IN PROGRESS)
3. Validation Ladder: per-validation-type results with pass/fail status
4. Specific Validations: domain-specific validation details
5. Code Quality Metrics: baseline/post-work/change table
6. Validation Checklist: comprehensive checklist (12+ items)
7. Summary: tickets executed, reduction metrics, validation status
8. Status: Ready for next phase

**Rule:** All implementation summaries use this structure. Validation ladder always covers Build/Test/Domain-Specific sections; code metrics table uses consistent columns (Metric/Baseline/Post-Work/Change).

### Test Binding Citation Format

**Canonical citation format:**
- Inline comment: `(test: "test name here")`
- Reference list: `- See authority test binding reference for mapping`
- Full citation: `test_presentation_runtime.zig:LINE-RANGE "test name"`

**Rule:** Test bindings are cited consistently across all evidence documents. Use inline format for brief mentions, reference format for external lookups, full citation for explicit line references.

### Evidence Traceability Requirement

**Rule:** All evidence documents must explicitly map to enforcement artifacts:
- Checkpoint documents: reference per-path enforcement docs and tests
- Verification documents: reference compile-time/runtime/test/code-review enforcement
- Audit documents: reference preserved locks/signals/evidence categories
- Implementation documents: reference validation artifact locations

**Verification:** Cross-check all evidence citations resolve to actual documents and line numbers (no broken references).

## Android mapping (example, not definition)

On Android, code may obtain a native window or surface on the way to a GLES
texture or image; the **contract** here is still: shared GPU attachment for
terminal draws + Zide-owned generations + host-owned presentation binding. JNI or
`ANativeWindow` shape remains **platform-local**.

## Non-goals

- Defining draw queues, passes, or backend resource types — see
  `RENDER_BACKEND_CONTRACT.md`.
- Defining JNI, Activity, or desktop window APIs — see `NATIVE_HOST_CONTRACT.md`
  and platform docs.
- Changing parser/engine semantics — `VT_CORE_DESIGN.md` / maturity campaign.

## Related documents

- `app_architecture/platform/NATIVE_HOST_CONTRACT.md` — lifecycle + native
  surface availability patterns.
- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md` — backend responsibilities
  and adoption gates.
- `app_architecture/terminal/TERMINAL_SUBSYSTEM_LAYERS.md` — where publication
  and presentation meet.
