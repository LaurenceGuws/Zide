# Runtime Isolation and Resource Management Research (2026-03-25)

## Purpose

Capture the research baseline for Zide's next architecture lane:

- preserving responsiveness under multi-session and multi-tab load
- preventing inactive work from degrading the active user path
- keeping runtime boundaries portable and transport-agnostic
- setting up future IDE/session growth without accepting heavy IDE failure modes

This is research input for a later architecture authority doc. It is not the
architecture authority itself.

## Research Question

Zide already has better low-level control than Electron-heavy tools, but the
current architecture still allows expensive work in one tab or subsystem to
degrade everything else:

- many busy terminal tabs reduce responsiveness across the terminal lane
- large editor buffers or expensive editor work degrade unrelated UI behavior
- future session/workspace growth will make this worse unless lifecycle,
  scheduling, and isolation become explicit architecture

The central question is:

- how should Zide structure work lanes, ownership, budgets, and lifecycle so
  it can outperform heavy IDEs on ordinary hardware while still scaling to
  richer IDE/session workflows later

## Local Zide Baseline

### Already-proven direction inside Zide

The repo already contains strong local evidence that the right direction is not
"optimize everything in place", but rather "move heavy work behind explicit
runtime boundaries and bounded scheduling":

- `docs/review/PERFORMANCE_REVIEW_1.md`
  - records the existing UI-thread/backend blocking audit
  - already prioritizes lock-scope reduction, bounded polling, async bootstrap,
    and search offload
- `src/app/terminal/terminal_frame_pacing_runtime.zig`
  - active/background poll budgeting already exists in the terminal lane
  - Zide already distinguishes active vs background polling work
- `app_architecture/RENDERER_SCENE_PUBLICATION_CONTRACT.md`
  - renderer already trends toward snapshot/publication/present-ack ownership
- `docs/research/editor/EDITOR_THREADING_COMPARISON_2026-03-19.md`
  - explicitly concludes editor highlight production should move out of the UI
    frame path and into an editor-owned runtime lane
- `app_architecture/editor/STATUS_BAR_MODE_HOST.md`
  - current file-flow direction already prefers a richer internal surface over
    an OS-dialog dependency

### Local constraint this creates

The next architecture should extend these existing choices rather than invent a
new model:

- explicit published state to the UI
- bounded active/background scheduling
- editor/runtime ownership of heavy semantic work
- native UI host kept light and responsive

## Reference Repo Findings

### Kitty

Source:

- `reference_repos/terminals/kitty/docs/performance.rst`

Relevant takeaways:

- kitty explicitly optimizes for perceived latency, smoothness, and CPU usage
  together, not raw throughput alone
- it separates child-program interaction from rendering with a dedicated thread
- it treats latency/CPU tradeoffs as explicit tunable policy, not accidental
  side effects

Why it matters for Zide:

- active-user responsiveness must be a top-level product metric
- terminal IO and rendering should not be one undifferentiated workload lane
- background work should be governed by policy knobs/budgets, not best effort

### Ghostty

Sources:

- `reference_repos/terminals/ghostty/README.md`
- `reference_repos/terminals/ghostty/src/termio/Options.zig`
- `reference_repos/terminals/ghostty/src/termio/Termio.zig`
- external: <https://mitchellh.com/writing/libghostty-is-coming>
- external: <https://ghostty.org/docs/about>

Relevant takeaways:

- Ghostty explicitly separates native app surfaces from a shared Zig core
- it uses a dedicated IO thread and a renderer mailbox/wakeup model
- `termio` is described as flexible enough to work with different backend/input
  sources, not only one concrete PTY setup
- libghostty direction reinforces a reusable core + host adapter model

Why it matters for Zide:

- transport-agnostic runtime boundaries are the right goal
- IPC should remain an adapter possibility, not the architecture itself
- core runtime logic should not depend on whether it runs in-process, threaded,
  or later behind a process boundary

### Lapce

Sources:

- `reference_repos/editors/lapce/docs/why-lapce.md`
- `reference_repos/editors/lapce/lapce-proxy/src/dispatch.rs`

Relevant takeaways:

- Lapce's own design motivation rejects putting editing latency behind a remote
  backend roundtrip
- it keeps editing local to the UI side while offloading other work through a
  proxy/plugins model
- it already uses thread-per-subsystem style execution for plugin catalog and
  terminal runtime work

Why it matters for Zide:

- the focused editing path should stay local/low-latency
- not all isolation should be remote or process-based
- the right split is "local interaction remains local, other work is isolated"

### Neovide

Source:

- `reference_repos/editors/neovide/src/main.rs`

Relevant takeaways:

- Neovide documents its architecture in execution lanes:
  - bridge
  - editor
  - renderer
  - window
- it explicitly moves redraw-event preprocessing onto an editor thread
- the window event loop is not expected to do the heaviest transformation work

Why it matters for Zide:

- the architecture should name execution lanes explicitly
- event/command/snapshot boundaries are first-class, not incidental
- the window/UI lane should consume prepared work, not perform the heavy
  semantic transform inline

### Zed

Sources:

- `reference_repos/editors/zed/docs/src/development.md`
- `reference_repos/editors/zed/docs/src/multibuffers.md`

Relevant takeaways:

- the docs expose a strong measurement culture around frame time and perf tests
- Zed's multibuffer/session-style UX raises the same class of scaling problem
  Zide will face later when session hopping becomes richer

Why it matters for Zide:

- the architecture must be paired with repeatable perf measurement, not just
  reasoning
- session/workspace UX cannot be treated as "future polish"; it must already
  fit the runtime/lifecycle model now

### Scintilla / Notepad++ lineage

Sources:

- `reference_repos/text/scintilla`
- summarized in `docs/research/editor/EDITOR_THREADING_COMPARISON_2026-03-19.md`

Relevant takeaways:

- bounded styling work and deferred continuation are engine-owned behavior
- the application is not expected to invent redraw-triggered styling policy

Why it matters for Zide:

- expensive editor progress should be owned by an editor runtime service, not by
  redraw-cache code or widget-local hacks

## Dependency / Platform Constraint Findings

### SDL

Sources:

- `reference_repos/sdlwiki_md/SDL3/CategoryRender.md`
- `reference_repos/sdlwiki_md/SDL3/SDL_GL_MakeCurrent.md`

Relevant takeaways:

- SDL render functions are main-thread constrained
- OpenGL context association via SDL is also documented as main-thread only

Why it matters for Zide:

- UI/render submission must remain main-thread authoritative
- heavy work should be isolated around the renderer, not by trying to make SDL
  rendering itself multi-threaded
- the model should be:
  - workers produce prepared state
  - main thread consumes and renders it

### Renderer/publication implications

Zide already trends toward this with scene publication and present-ack. The
dependency docs reinforce that this is the right shape:

- workers/runtime lanes prepare or publish immutable-ish state
- renderer stays authoritative for actual present
- main-thread UI remains light enough to preserve latency

## Higher-Level Web Findings

### VS Code extension-host/process model

Sources:

- <https://code.visualstudio.com/api/advanced-topics/extension-host>
- <https://code.visualstudio.com/blogs/2022/11/28/vscode-sandbox>

Relevant takeaways:

- VS Code isolates extension execution to protect startup and UI operations
- it lazily activates extensions to avoid unnecessary CPU and memory cost
- its later process model uses direct message-port communication to avoid
  burdening unrelated processes
- complex services such as terminals, file watching, search, and task execution
  were moved out of the renderer/UI process

Why it matters for Zide:

- lazy activation and lifecycle states are essential, not optional polish
- direct interaction paths should not pay for unrelated background services
- process isolation is useful when the boundary is already clean, but the real
  lesson is "UI process should not own heavy service work"

### RAIL responsiveness model

Source:

- <https://web.dev/articles/rail>

Relevant takeaways:

- user perception is context-dependent:
  - response
  - animation
  - idle
  - load
- idle/deferred work must remain interruptible by user interaction

Why it matters for Zide:

- performance policy should be framed around user-perceived latency classes
- background work must be interruptible and lower priority than active input
- frame, response, and deferred-work budgets should be explicit

## Synthesis

The strongest common pattern across the references is:

1. Keep the UI/render host authoritative for input and present.
2. Move expensive transformation/runtime work behind explicit subsystem lanes.
3. Publish commands/events/snapshots across the boundary.
4. Distinguish active vs background work explicitly.
5. Treat lifecycle and lazy activation as architecture, not optimization.

The strongest anti-pattern to avoid is:

- open tabs/sessions all behaving as if they are equally entitled to full
  runtime cost at all times

## Direction This Research Supports

This research supports a Zide architecture with:

- one native UI host responsible for:
  - input
  - focus
  - composition
  - present
  - lightweight view/session state
- subsystem runtimes responsible for:
  - terminal session IO/parse/runtime work
  - editor semantic/background work
  - future session/workspace/LSP services
- transport-agnostic boundaries:
  - direct in-process call path where appropriate
  - threaded adapter when isolation is needed
  - process adapter only if later justified
- explicit scheduling tiers:
  - focused visible
  - visible inactive
  - hidden warm
  - paused/cold
- explicit work classes:
  - frame-critical
  - interactive
  - background
  - deferred

## Open Questions For The Architecture Note

1. What should be the first runtime boundary to formalize:
   - terminal session runtime
   - editor semantic runtime
   - shared scheduler/lifecycle service

2. Should Zide introduce one shared scheduler first, or let each subsystem own
   its own budgets/lifecycle while the cross-subsystem policy remains central?

3. What state is required to resume a cooled session quickly without keeping it
   fully hot?

4. Which caches are:
   - hot and interactive
   - warm and resumable
   - safe to evict aggressively

5. Which boundaries must remain transport-agnostic from day one so later IPC
   does not require a redesign?

## Recommended Next Step

Write the authority doc:

- `app_architecture/RUNTIME_ISOLATION_AND_RESOURCE_MANAGEMENT.md`

That doc should turn this research into:

- product performance bar
- runtime classes
- lifecycle states
- scheduling/budget policy
- transport strategy
- terminal/editor/session-specific application of the model
