# Terminal Present Transaction Plan

Purpose: define the next redesign phase for terminal presentation under the
renderer backend contract campaign.

This is architecture authority for the terminal-present redesign lane beneath
`RB-B1`.

## Why This Exists

Recent cleanup has improved ownership:

- the shared presentable seam no longer exports fake-neutral lifecycle verbs
- the top-level terminal present-path choice now routes through
  `renderer_presentable_host.zig`
- duplicated direct/retained orchestration in
  `terminal_widget_presentation_runtime.zig` is narrower than before

But the core contradiction remains:

- shared terminal UI/runtime code still expresses two concrete execution
  stories:
  - retained update + present
  - direct/snapshot reuse-update + present

That is better than before, but it is still not the contract we want.

The next step is not "pick one backend mechanic."

The next step is:

- define one shared terminal present transaction
- let different backends satisfy that transaction differently underneath

## Design Standard

The shared terminal presentation contract must describe product work, not
backend mode.

Shared code should own:

- invalidation reasons
- geometry and viewport truth
- cursor/overlay/composition invalidation inputs
- update intent
- present intent
- scheduling / reuse eligibility inputs

Backend-owned presentable code should own:

- retained-vs-direct execution mechanics
- snapshot reuse mechanics
- GPU upload / present details
- target availability and lifecycle details

The contract is only good enough when:

- shared terminal code does not branch on backend presentation shape
- backend choice changes implementation, not shared terminal architecture

## Recommended End State

Adopt one host-owned terminal present transaction with a shared plan/result
surface:

- `planTerminalPresent(...) -> TerminalPresentPlan`
- `executeTerminalPresent(plan, work) -> TerminalPresentResult`

The shared plan should encode only product-level semantics such as:

- update intent:
  - `none`
  - `partial`
  - `full`
- present intent:
  - `reuse`
  - `update_and_present`
  - `direct_present`
- viewport/source/destination geometry
- reuse eligibility
- cursor/overlay invalidation inputs
- scroll/shift intent

The shared result should encode only product-level outcomes such as:

- `presented`
- `updated`
- `reused`
- `unavailable`
- shared timing/result bookkeeping

OpenGL may satisfy that transaction through retained-target update plus final
present.

Metal may satisfy the same transaction through snapshot reuse/update plus
composition replay.

Future Vulkan/mobile work should satisfy the same contract without reopening
widget/runtime architecture.

## Contract Draft

This is the minimum field/invariant bar for `RB-B1.b`.

### `TerminalPresentPlan`

Required fields:

- `update_intent`
  - `none`
  - `partial`
  - `full`
- `present_intent`
  - `reuse`
  - `update_and_present`
  - `direct_present`
- `surface_geometry`
  - logical source size
  - visible size
  - destination origin/size
- `reuse_policy`
  - whether reuse is allowed
  - whether scroll/shift reuse is requested
  - whether cursor/overlay/composition invalidation forbids reuse
- `damage`
  - full / partial
  - partial span payload or equivalent shared damage description
- `invalidation_reasons`
  - generation / clear-generation
  - cell metrics / scale
  - cursor
  - overlay / composing
  - viewport shift

Required invariants:

- `present_intent == .reuse` implies `update_intent == .none`
- `update_intent == .partial` implies partial damage payload exists
- source/destination geometry must be expressible without backend surface types
- plan must be derivable without backend identity checks in widget/runtime code

### `TerminalPresentResult`

Required fields:

- `outcome`
  - `presented`
  - `reused`
  - `updated_and_presented`
  - `unavailable`
  - `skipped`
- `cache_state_advanced`
- `target_available`
- `timing`
  - update ms
  - background ms
  - glyph ms
  - kitty/graphics ms
- `followup`
  - whether another frame/update is required soon
  - optional reason

Required invariants:

- `outcome == .reused` implies no new content update was performed
- `cache_state_advanced == true` implies shared presentation bookkeeping is
  allowed to commit the new present state
- `outcome == .unavailable` must not silently commit presentation-ready state

## What To Emulate

External reference pressure points in one sentence:

- Ghostty pressure: one product-level frame pipeline above backend choice
- WezTerm pressure: separate build/plan from draw/present and keep scheduling
  above the backend
- Kitty pressure: explicit dirty/update thinking, strong GPU caching, and
  batch-friendly rendering discipline

Do not copy any one project directly.

Concrete pressure to carry forward:

- Ghostty:
  - one shared renderer/frame vocabulary above backend choice
  - render state passed as explicit data instead of widget/backend cross-owned
    live state
  - surface ownership and renderer-thread lifecycle treated as first-class
    infrastructure rather than widget-local policy
- WezTerm:
  - clear split between "build what should be drawn" and "issue draw/present"
  - scheduling / next-frame timing stays above backend execution
  - backend/frontend choice does not change the product-level paint pipeline
- Kitty:
  - dirty-region thinking is explicit even when final present is still full
    surface composition
  - glyph/image/cache lifetime is treated as a performance contract, not an
    incidental optimization
  - reuse and partial update are justified by explicit invalidation causes

Concrete pressure to reject:

- a broader Ghostty-style frame-pipeline rewrite as the immediate next cut:
  useful direction, too large for `RB-B1`
- Kitty's OpenGL-shaped renderer stack as a contract template:
  excellent implementation pressure, wrong neutrality shape for Zide
- any reference pattern that makes terminal presentation mode the top-level
  widget/runtime concern

## What To Reject

- shared widget/runtime branching first on backend presentation mode
- capability-query-driven lifecycle decisions in shared code
- forcing one universal backend mechanic as the contract
- vague "backend-neutral" layers that hide the real split and invite new
  backend checks later

## Gate Boundary

This redesign must keep gate boundaries explicit.

### Gate #2 work

Gate #2 is about presentable lifecycle neutrality:

- one shared terminal present transaction contract
- shared planning/invalidation/result vocabulary
- backend lifecycle shape terminates behind presentable seams

### Gate #5 work

Gate #5 is about frame/present/order ownership:

- broader frame routine ownership
- editor/sample/chrome/terminal ordering family alignment
- any cross-widget frame lifecycle unification beyond the terminal-present
  contract

Do not silently redesign the entire renderer frame routine while claiming to
only close gate #2.

## Failure Model

The redesign must make failure semantics explicit rather than burying them in
backend-specific control flow.

Required failure classes:

- target unavailable
  - presentable/retained/snapshot target missing or invalid
- reuse rejected
  - backend cannot honor requested reuse/shift even though shared code asked
- update invalidated
  - partial update request became unsafe and must escalate to full update
- geometry changed mid-transaction
  - resize / scale / viewport mismatch invalidates the plan

Required policy:

- target unavailable:
  - return `unavailable`
  - clear shared ready/reuse state as needed
  - do not pretend present succeeded
- reuse rejected:
  - may fall back to update-and-present in the same transaction if safe
  - otherwise return a non-success result that forces a fresh plan next frame
- partial update invalid:
  - must escalate to full update intentionally, not via hidden backend branch
- geometry changed mid-transaction:
  - must not commit old geometry bookkeeping as if it matched the new frame

Examples that must fit this model:

- surface loss / replacement
- resize between plan and execution
- IME/composition overlay invalidating reuse
- cursor/focus changes invalidating reuse
- backend refusing snapshot scroll/shift reuse

## Execution Plan

### `RB-B1.a` Host-owned terminal present execution seam

Status:

- delivered

Stop marker:

- top-level terminal presentation entry routes through one
  `renderer_presentable_host` execution seam

### `RB-B1.b` Shared terminal present transaction vocabulary

Purpose:

- replace ad hoc direct/retained orchestration inputs with one explicit shared
  plan/result contract

Primary code pressure:

- `src/ui/widgets/terminal_widget_presentation_runtime.zig`
- `src/ui/renderer/renderer_presentable_host.zig`
- `src/ui/renderer/presentable_contract.zig`

Acceptance criteria:

- shared `TerminalPresentPlan` and `TerminalPresentResult` types exist in
  renderer/presentable space
- plan/result types do not mention GL targets, Metal snapshots, or backend
  enums
- fast-present reuse, update intent, and present intent are expressed through
  those shared types rather than duplicated branch-local plumbing

Do not do:

- do not move backend GPU mechanics into the shared plan types
- do not widen `RendererCapabilities` to stand in for the missing contract

### `RB-B1.c` Shared planning and invalidation normalization

Purpose:

- unify the common planning layer before deeper backend execution movement

Acceptance criteria:

- fast-present eligibility is computed once
- geometry/update-plan creation is computed once
- cursor/overlay/composition invalidation inputs are prepared once
- cache-advance / presentable-ready bookkeeping is shared instead of split by
  direct/retained orchestration

Do not do:

- do not move backend-specific upload/reuse rules into shared widget code

### `RB-B1.d` Backend-owned execution against one shared transaction

Purpose:

- push concrete direct/retained execution behind backend presentable seams

Acceptance criteria:

- shared terminal runtime no longer owns separate retained/direct execution
  trees for the main transaction
- backend presentable implementations satisfy the shared plan/result contract
- GL and Metal remain behavior-equivalent to the pre-cut product semantics

Do not do:

- do not merge this into a renderer-wide frame-lifecycle rewrite

### `RB-B1.e` Re-audit gate closure

Purpose:

- decide what is truly left in gate #2 vs what is actually gate #5

Acceptance criteria:

- queue and current-state docs explicitly restate:
  - what gate #2 now covers
  - what has moved into gate #5
  - what would still block Vulkan/mobile routine backend work

## Temporary Migration Leaks

The migration does not need fake purity.

Allowed temporarily during `RB-B1.b` through `RB-B1.d`:

- direct and retained backend execution bodies both still existing behind the
  shared transaction seam
- thin adapter helpers in `terminal_widget_presentation_runtime.zig` while
  plan/result vocabulary is being introduced
- temporary shared-to-backend argument translation glue where the final backend
  execution API is not cut yet

Not allowed even temporarily:

- new backend enum checks in widget/runtime presentation code
- new GL/Metal surface/resource types in shared plan/result structures
- capability fields widened to stand in for missing transaction semantics
- silently folding frame-lifecycle redesign into the terminal-present lane

## Invariants

- shared terminal presentation entry must not branch on backend identity
- shared plan/result types must not expose backend-native surface/resource
  types
- one terminal presentation request corresponds to one host-owned execution
  transaction
- backend choice may change mechanics, not product-level presentation meaning

## Validation Expectations

At minimum for each redesign cut:

- `zig build`
- `zig build test`

And add/expand focused tests for:

- fast-present reuse invalidation on cursor/overlay/focus/composition changes
- geometry/source-destination consistency across retained/snapshot backends
- partial-update + viewport-shift correctness
- contract-shape regression checks that shared terminal presentation does not
  regain backend-shaped branching
